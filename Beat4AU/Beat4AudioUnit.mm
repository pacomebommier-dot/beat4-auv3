#import "Beat4AudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import <mach/mach_time.h>
#import <atomic>
#import <cmath>
#import <memory>
#import <cstdint>
#import <cstring>
#import <array>
#import "Beat4Math.hpp"
#import "Beat4Transport.hpp"
#import "Beat4Songs.hpp"
#import "Beat4Program.hpp"
#import "Beat4Journal.hpp"
#import "Beat4Store.h"
#import "Beat4Kick.hpp"
#import "Beat4BeatGate.hpp"
#import "Beat4AudioGain.hpp"

namespace {
constexpr AUParameterAddress kLevel = 0;
constexpr AUParameterAddress kEnabled = 1;
struct State {
    std::atomic<uint64_t> sequence{0}, tick{0}, callbacks{0}, revision{1};
    std::atomic<double> sampleRate{48000};
    std::atomic<int> localStop{0}, transportStatus{0};
    std::atomic<uint64_t> invalidTimestamps{0};
    std::atomic<double> beat{0}, bpm{0}, samplePosition{0}, bufferSeconds{0.005};
    std::atomic<int> numerator{4}, denominator{4}, mode{0};
    std::atomic<bool> transportValid{false}, musicalValid{false}, moving{false}, transportChanged{false};
    std::atomic<int> currentPG{-1};
    std::array<std::atomic<int>,128> notes;
    std::array<std::atomic<double>,128> tempos;
    std::atomic<float> kickLevel{0.60f};
    std::atomic<bool> kickEnabled{false}; // OFF at first boot: no surprising audio.
    std::array<std::atomic<int>,128> queues, pcModes;
    std::atomic<int> globalMode{0}, localPC{-1}, selectedPC{-1}, transportRequest{-1};
    std::atomic<bool> uncertain{false},estimated{false};
    beat4::TransportPulse transportPulse;
    beat4::Journal journal;
    beat4::ProgramEngine engine; // render thread owns this state
    beat4::ProgramMemory memories;
    double lastTempoSent=0;
    std::atomic<bool> midiOutputConfigured{false};
    State() {for(int i=0;i<128;++i){notes[i].store(-1);tempos[i].store(0);queues[i].store(0);pcModes[i].store(-1);}}
};
// Stable, realtime-readable callback slots. Host callbacks are installed during
// allocateRenderResources, which can occur after internalRenderBlock is queried.
struct HostHooks {
    std::atomic<void *> transport{nullptr};
    std::atomic<void *> musical{nullptr};
    std::atomic<void *> midiOut{nullptr};
};
struct Snapshot {
    uint64_t tick, callbacks;
    double beat, bpm, samplePosition, bufferSeconds;
    int numerator, denominator, mode, pg, selected;
    bool uncertain,estimated;
    bool transportValid, musicalValid, moving, transportChanged;
};
Snapshot load(const State& s) noexcept {
    Snapshot result{};
    for(;;){
        const auto a=s.sequence.load(std::memory_order_acquire);
        if(a&1) continue;
        result={s.tick.load(std::memory_order_relaxed), s.callbacks.load(std::memory_order_relaxed),
                s.beat.load(std::memory_order_relaxed), s.bpm.load(std::memory_order_relaxed),
                s.samplePosition.load(std::memory_order_relaxed), s.bufferSeconds.load(std::memory_order_relaxed),
                s.numerator.load(std::memory_order_relaxed), s.denominator.load(std::memory_order_relaxed),
                s.mode.load(std::memory_order_relaxed), s.currentPG.load(),s.selectedPC.load(),s.uncertain.load(),s.estimated.load(), s.transportValid.load(std::memory_order_relaxed),
                s.musicalValid.load(std::memory_order_relaxed), s.moving.load(std::memory_order_relaxed),
                s.transportChanged.load(std::memory_order_relaxed)};
        const auto b=s.sequence.load(std::memory_order_acquire);
        if(a==b && !(b&1)) break;
    }
    return result;
}
}
@interface Beat4AudioUnit () {
    AUAudioUnitBus *_output;
    AUAudioUnitBusArray *_outputs;
    AUAudioUnitBusArray *_inputs;
    AUParameterTree *_params;
    AUParameter *_levelParameter;
    AUParameter *_enabledParameter;
    std::shared_ptr<State> _state;
    std::shared_ptr<HostHooks> _hostHooks;
    std::shared_ptr<beat4::HostMemory> _hostMemory;
    std::shared_ptr<beat4::KickVoice> _kickVoice;
    std::shared_ptr<beat4::BeatGate> _beatGate;
    std::shared_ptr<beat4::AudioGain> _audioGain;
    NSMutableArray *_hostCallbackKeepalive;
    AUHostTransportStateBlock _cachedTransport;
    AUHostMusicalContextBlock _cachedMusical;
    AUMIDIOutputEventBlock _cachedMIDIOutput;
    NSMutableDictionary<NSString*,NSDictionary*> *_songCache; // UI thread only
}
- (void)refreshHostCallbacks:(BOOL)replace;
@end

@implementation Beat4AudioUnit
- (instancetype)initWithComponentDescription:(AudioComponentDescription)desc
                                  options:(AudioComponentInstantiationOptions)options
                                    error:(NSError * _Nullable __autoreleasing *)outError {
    self=[super initWithComponentDescription:desc options:options error:outError];
    if(!self)return nil;
    _state=std::make_shared<State>();
    _hostHooks=std::make_shared<HostHooks>();
    _hostMemory=std::make_shared<beat4::HostMemory>();
    _kickVoice=std::make_shared<beat4::KickVoice>();
    _beatGate=std::make_shared<beat4::BeatGate>();
    _audioGain=std::make_shared<beat4::AudioGain>();
    _hostCallbackKeepalive=[NSMutableArray new];
    AVAudioFormat* format=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    _output=[[AUAudioUnitBus alloc]initWithFormat:format error:outError];
    if(!_output)return nil;
    _outputs=[[AUAudioUnitBusArray alloc]initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[_output]];
    _inputs=[[AUAudioUnitBusArray alloc]initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses:@[]];
    self.maximumFramesToRender=4096;
    _levelParameter=[AUParameterTree createParameterWithIdentifier:@"kickLevel" name:@"Kick Level"
        address:kLevel min:0 max:1 unit:kAudioUnitParameterUnit_LinearGain unitName:nil
        flags:kAudioUnitParameterFlag_IsReadable|kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    _enabledParameter=[AUParameterTree createParameterWithIdentifier:@"kickEnabled" name:@"Kick ON/OFF"
        address:kEnabled min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags:kAudioUnitParameterFlag_IsReadable|kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    _params=[AUParameterTree createTreeWithChildren:@[_levelParameter,_enabledParameter]];
    std::shared_ptr<State> s=_state;
    _params.implementorValueObserver=^(AUParameter *parameter,AUValue value){
        if(parameter.address==kLevel){s->kickLevel.store(std::fmax(0.f,std::fmin(1.f,value)));s->revision.fetch_add(1);}
        else if(parameter.address==kEnabled){s->kickEnabled.store(value>=.5f);s->revision.fetch_add(1);}
    };
    _params.implementorValueProvider=^AUValue(AUParameter *parameter){
        return parameter.address==kLevel?s->kickLevel.load():(s->kickEnabled.load()?1.f:0.f);
    };
    _songCache=beat4::loadSongStore(NSUserDefaults.standardUserDefaults);
    s->globalMode.store(std::clamp((int)[NSUserDefaults.standardUserDefaults integerForKey:@"beat4.globalMode"],0,2));
    [_songCache enumerateKeysAndObjectsUsingBlock:^(NSString *key,NSDictionary *entry,BOOL *stop){
        (void)stop;const int pc=key.intValue;
        s->tempos[pc].store([entry[@"bpm"] doubleValue]);
        s->notes[pc].store([entry[@"sub"] intValue]);
        s->queues[pc].store([entry[@"queue"] intValue]);
        s->pcModes[pc].store([entry[@"pcMode"] intValue]);
    }];
    return self;
}
- (AUParameterTree *)parameterTree {return _params;}
- (AUAudioUnitBusArray *)inputBusses {return _inputs;}
- (AUAudioUnitBusArray *)outputBusses {return _outputs;}
- (NSArray<NSString *> *)MIDIOutputNames {return @[@"AUM Control", @"Circuit Projects"];}
- (NSInteger)virtualMIDICableCount {return 2;}
- (BOOL)allocateRenderResourcesAndReturnError:(NSError * _Nullable __autoreleasing *)outError {
    if(![super allocateRenderResourcesAndReturnError:outError])return NO;
    _state->sampleRate.store(_output.format.sampleRate);
    _hostMemory->reset();_kickVoice->reset();_beatGate->reset();_audioGain->reset();
    // Preserve the observed project, but invalidate pending phase and ramp on reallocation.
    const int active=_state->engine.active;
    _state->engine=beat4::ProgramEngine{};_state->engine.active=active;
    _state->transportPulse=beat4::TransportPulse{};_state->lastTempoSent=0;
    _state->callbacks.store(0);_state->tick.store(0);_state->selectedPC.store(-1);
    _state->uncertain.store(false);_state->localStop.store(0);
    [self refreshHostCallbacks:YES];
    return YES;
}
- (void)refreshHostCallbacks:(BOOL)replace {
    if(!self.renderResourcesAllocated)return;
    @synchronized(self){
        AUHostTransportStateBlock transport=_cachedTransport;
        AUHostMusicalContextBlock musical=_cachedMusical;
        AUMIDIOutputEventBlock midi=_cachedMIDIOutput;
        if(replace || !transport)transport=[self.transportStateBlock copy];
        if(replace || !musical)musical=[self.musicalContextBlock copy];
        if(replace || !midi)midi=[self.MIDIOutputEventBlock copy];
        if(transport && transport!=_cachedTransport)[_hostCallbackKeepalive addObject:transport];
        if(musical && musical!=_cachedMusical)[_hostCallbackKeepalive addObject:musical];
        if(midi && midi!=_cachedMIDIOutput)[_hostCallbackKeepalive addObject:midi];
        _cachedTransport=transport;_cachedMusical=musical;_cachedMIDIOutput=midi;
        _hostHooks->transport.store((__bridge void*)transport,std::memory_order_release);
        _hostHooks->musical.store((__bridge void*)musical,std::memory_order_release);
        _hostHooks->midiOut.store((__bridge void*)midi,std::memory_order_release);
        _state->midiOutputConfigured.store(midi!=nil);
    }
}
- (void)deallocateRenderResources {
    _hostHooks->transport.store(nullptr,std::memory_order_release);
    _hostHooks->musical.store(nullptr,std::memory_order_release);
    _hostHooks->midiOut.store(nullptr,std::memory_order_release);
    [super deallocateRenderResources];
    _cachedTransport=nil;_cachedMusical=nil;_cachedMIDIOutput=nil;
    [_hostCallbackKeepalive removeAllObjects];
    _state->midiOutputConfigured.store(false);_state->revision.fetch_add(1);
}
- (AUInternalRenderBlock)internalRenderBlock {
    const std::shared_ptr<State> shared=_state;
    const std::shared_ptr<beat4::HostMemory> memory=_hostMemory;
    const std::shared_ptr<beat4::KickVoice> voice=_kickVoice;
    const std::shared_ptr<beat4::BeatGate> gate=_beatGate;
    const std::shared_ptr<HostHooks> hooks=_hostHooks;
    const auto gain=_audioGain;
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags,
         const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, NSInteger outputBusNumber,
         AudioBufferList *outputData, const AURenderEvent *events, AURenderPullInputBlock pullInput) {
        (void)outputBusNumber;(void)pullInput;
        State *s=shared.get();
        const double sampleRate=s->sampleRate.load();
        // Resolve callbacks when rendering, not when the host first queries the
        // block. The backing blocks remain retained in the AU while allocated.
        const AUHostTransportStateBlock transport=(__bridge AUHostTransportStateBlock)hooks->transport.load(std::memory_order_acquire);
        const AUHostMusicalContextBlock musical=(__bridge AUHostMusicalContextBlock)hooks->musical.load(std::memory_order_acquire);
        const AUMIDIOutputEventBlock midiOut=(__bridge AUMIDIOutputEventBlock)hooks->midiOut.load(std::memory_order_acquire);
        const bool validTime=timestamp && (timestamp->mFlags & kAudioTimeStampSampleTimeValid) &&
            std::isfinite(timestamp->mSampleTime) && std::abs(timestamp->mSampleTime)<9e15;
        if(!validTime)s->invalidTimestamps.fetch_add(1);
        const auto sampleTime=validTime?static_cast<AUEventSampleTime>(timestamp->mSampleTime):AUEventSampleTimeImmediate;
        AUHostTransportStateFlags flags=(AUHostTransportStateFlags)0;
        double sample=0;
        const bool transportReturned=transport!=nil && transport(&flags,&sample,nullptr,nullptr);
        const bool transportOK=transportReturned && std::isfinite(sample);
        double tempo=0,beatsPerBar=4,beat=0,barStart=0;
        NSInteger denominator=4;
        const bool musicalReturned=musical!=nil && musical(&tempo,&beatsPerBar,&denominator,&beat,nullptr,&barStart);
        const bool musicalOK=musicalReturned && std::isfinite(tempo) && tempo>0 &&
            std::isfinite(beat) && std::abs(beat)<1e10 && std::isfinite(beatsPerBar) &&
            beatsPerBar>0 && beatsPerBar<=128 && denominator>0 && denominator<=128;
        const bool moving=transportOK && (flags & AUHostTransportStateMoving);
        const bool changed=transportOK && (flags & AUHostTransportStateChanged);
        const auto mode=memory->observe({transportOK,musicalOK,moving,changed,beat,sample});
        const bool positionOK=transportOK && musicalOK && std::isfinite(beat) &&
            std::isfinite(barStart) && std::isfinite(tempo) && tempo>0 && beatsPerBar>0 && denominator>0;
        const double barLength=beatsPerBar*4.0/denominator;
        const beat4::HostPosition position{positionOK,moving,beat,barStart,barLength,tempo};
        for(int i=0;i<64;++i){
            s->memories.bpm[i]=s->tempos[i].load();
            s->memories.queue[i]=s->queues[i].load();
            s->memories.mode[i]=s->pcModes[i].load();
        }
        s->memories.globalMode=std::clamp(s->globalMode.load(),0,2);
        int previousActive=s->engine.active;
        auto apply=[&](beat4::ProgramAction a){
            if(a.sendPC){
                if(!midiOut){s->journal.write(6,a.activated,1,beat);s->engine.outputFailed(previousActive,a.activated);return;}
                // Immediate PC at our boundary, avoiding a second native Circuit queue.
                auto message=beat4::circuitMessage(a.activated);
                const auto status=midiOut(sampleTime,message.cable,message.length,message.bytes.data());
                s->journal.write(status==noErr?4:6,a.activated,1,beat);
                if(status!=noErr){s->engine.outputFailed(previousActive,a.activated);return;}
            }
            if(a.activated>=0)s->journal.write(3,a.activated,a.sendPC?1:0,beat);
            if(midiOut && beat4::shouldEmitTempo(a,s->lastTempoSent)){
                auto message=beat4::tempoMessage(a.tempo);
                if(message.length){
                    const auto status=midiOut(sampleTime,message.cable,message.length,message.bytes.data());
                    if(status==noErr)s->lastTempoSent=a.tempo;else s->journal.write(6,s->engine.active,2,beat);
                }
            }
        };
        for(const AURenderEvent *e=events;e!=nullptr;e=e->head.next){
            if(e->head.eventType==AURenderEventParameter || e->head.eventType==AURenderEventParameterRamp){
                // AUM may schedule automation/MIDI Learn as realtime parameter events,
                // bypassing the UI-side AUParameter value observer.
                if(e->parameter.parameterAddress==kLevel)
                    {s->kickLevel.store(std::fmax(0.f,std::fmin(1.f,e->parameter.value)));s->revision.fetch_add(1);}
                else if(e->parameter.parameterAddress==kEnabled)
                    {s->kickEnabled.store(e->parameter.value>=.5f);s->revision.fetch_add(1);}
                continue;
            }
            if(e->head.eventType!=AURenderEventMIDI || e->MIDI.length<2)continue;
            int raw=-1;
            if(beat4::isCircuitProgramChange(e->MIDI.data[0],e->MIDI.data[1],raw)){
                s->journal.write(1,raw,0,beat);
                apply(s->engine.request(raw%64,false,raw>=64,position,s->memories));
            }
        }
        previousActive=s->engine.active;
        const int local=s->localPC.exchange(-1);
        if(local>=0)s->journal.write(2,local,1,beat);
        for(auto a:s->engine.renderStep(position,s->memories,local))apply(a);
        if(s->engine.selected!=s->selectedPC.load() || s->engine.uncertain!=s->uncertain.load())
            s->journal.write(s->engine.uncertain?5:7,s->engine.selected,local>=0?1:0,beat);
        const int request=s->transportRequest.exchange(-1);
        if(request>=0)s->transportPulse.request(moving);
        if(midiOut){
            const auto message=s->transportPulse.next();
            if(message.length){
                const auto status=midiOut(sampleTime,message.cable,message.length,message.bytes.data());
                s->transportStatus.store(status);
                if(status!=noErr)s->journal.write(6,s->engine.active,3,beat);
                if(status==noErr && message.bytes[2]==127)s->localStop.store(message.bytes[1]==111);
            }
        }
        if(moving && !s->moving.load())s->localStop.store(0);
        const bool canPlay=moving && musicalOK && sampleRate>0 && std::isfinite(beat) &&
                std::isfinite(tempo) && tempo>0 && beatsPerBar==4 && denominator==4;
        const bool on=s->kickEnabled.load(std::memory_order_relaxed);
        const double level=static_cast<double>(s->kickLevel.load(std::memory_order_relaxed));
        int pg=s->engine.active;
        int pitch=beat4::validProgram(pg)?s->notes[pg].load(std::memory_order_relaxed):-1;
        const double subHz=beat4::subFrequency(pitch);

        // The gate preserves the last triggered quarter-note across render buffers.
        // Visuals and sound use the same host musical position, with no free-running clock.
        gate->prepare(beat,tempo,sampleRate,frameCount,canPlay&&on);
        if(actionFlags)*actionFlags &= ~kAudioUnitRenderAction_OutputIsSilence;
        for(AVAudioFrameCount i=0;i<frameCount;++i){
            const bool playing=canPlay&&on;
            if(playing && gate->atSample(i))voice->trigger();
            const double v=voice->process(sampleRate,subHz)*gain->next(playing,level,sampleRate)*0.70;
            if(!playing && gain->silent())voice->reset();
            if(outputData){
                if(outputData->mNumberBuffers>=2){
                    for(UInt32 b=0;b<2;++b){
                        AudioBuffer &buf=outputData->mBuffers[b];
                        if(buf.mData)reinterpret_cast<float*>(buf.mData)[i]=(float)v;
                    }
                }else if(outputData->mNumberBuffers==1 && outputData->mBuffers[0].mData){
                    AudioBuffer &buf=outputData->mBuffers[0];
                    if(buf.mNumberChannels==2){
                        float *dst=reinterpret_cast<float*>(buf.mData);
                        dst[2*i]=(float)v; dst[2*i+1]=(float)v;
                    }else reinterpret_cast<float*>(buf.mData)[i]=(float)v;
                }
            }
        }
        const bool visibleChanged=s->currentPG.load()!=s->engine.active ||
            s->selectedPC.load()!=s->engine.selected || s->uncertain.load()!=s->engine.uncertain ||
            s->estimated.load()!=s->engine.estimated || s->moving.load()!=moving ||
            s->mode.load()!=(int)mode || s->transportValid.load()!=transportOK ||
            s->musicalValid.load()!=musicalOK || s->bpm.load()!=tempo;
        if(visibleChanged)s->revision.fetch_add(1);
        s->sequence.fetch_add(1,std::memory_order_acq_rel);
        s->currentPG.store(s->engine.active);
        s->selectedPC.store(s->engine.selected);
        s->uncertain.store(s->engine.uncertain);
        s->estimated.store(s->engine.estimated);
        s->tick.store(mach_absolute_time(),std::memory_order_relaxed);
        s->beat.store(beat,std::memory_order_relaxed);
        s->bpm.store(tempo,std::memory_order_relaxed);
        s->samplePosition.store(sample,std::memory_order_relaxed);
        s->bufferSeconds.store(sampleRate>0?frameCount/sampleRate:0,std::memory_order_relaxed);
        s->numerator.store(musicalOK?(int)beatsPerBar:4,std::memory_order_relaxed);
        s->denominator.store(musicalOK?(int)denominator:4,std::memory_order_relaxed);
        s->moving.store(moving,std::memory_order_relaxed);
        s->mode.store((int)mode,std::memory_order_relaxed);
        s->transportChanged.store(changed,std::memory_order_relaxed);
        s->transportValid.store(transportOK,std::memory_order_relaxed);
        s->musicalValid.store(musicalOK,std::memory_order_relaxed);
        s->callbacks.fetch_add(1,std::memory_order_relaxed);
        s->sequence.fetch_add(1,std::memory_order_release);
        return noErr;
    };
}
- (uint64_t)displayRevision {return _state->revision.load();}
- (NSDictionary<NSString*,NSNumber*>*)transportSnapshot {
    [self refreshHostCallbacks:NO];
    const Snapshot s=load(*_state);
    mach_timebase_info_data_t info{};mach_timebase_info(&info);
    const uint64_t now=mach_absolute_time();
    const double age=(s.tick>0 && now>=s.tick && info.denom!=0)
        ? (double)(now-s.tick)*info.numer/info.denom/1e9:1e6;
    const bool fresh=s.callbacks>0 && age<.25;
    const bool synced=fresh && s.transportValid && s.musicalValid && std::isfinite(s.bpm) && s.bpm>0;
    const double projected=synced?beat4::displayBeat(s.beat,s.bpm,s.moving,age,s.bufferSeconds):s.beat;
    const double safeBeat=std::isfinite(projected) && std::abs(projected)<1e10?projected:0;
    const auto d=beat4::project(safeBeat,s.samplePosition,s.moving);
    return @{@"hasRender":@(fresh),@"synced":@(synced),@"moving":@(s.moving),
             @"mode":@(s.mode),@"active":@(d.cell),@"fraction":@(d.fractional),
             @"bpm":@(s.bpm),@"bar":@(d.bar),@"numerator":@(s.numerator),
             @"denominator":@(s.denominator),@"pg":@(s.pg),
             @"kickEnabled":@(_state->kickEnabled.load()),@"kickLevel":@(_state->kickLevel.load()),
             @"midiOut":@(_state->midiOutputConfigured.load()),
             @"selectedPC":@(s.selected),@"uncertain":@(s.uncertain),@"estimated":@(s.estimated),
             @"globalMode":@(_state->globalMode.load()),@"displayBeat":@(projected),
             @"localStop":@(_state->localStop.load()),@"transportStatus":@(_state->transportStatus.load()),
             @"invalidTimestamps":@(_state->invalidTimestamps.load()),@"renderAge":@(age),@"renderSampleRate":@(_state->sampleRate.load()),
             @"transportCallback":@(_cachedTransport!=nil),@"musicalCallback":@(_cachedMusical!=nil),
             @"transportValid":@(s.transportValid),@"musicalValid":@(s.musicalValid)};
}
- (NSArray*)diagnosticLog {
    NSMutableArray *result=[NSMutableArray new];
    for(const auto& r:_state->journal.read())[result addObject:@{@"event":@(r.event),@"pc":@(r.pc),@"origin":@(r.origin),@"beat":@(r.beat)}];
    return result;
}
- (NSInteger)currentProgram {return load(*_state).pg;}
- (NSDictionary<NSString*,id>*)currentSong {
    NSInteger pg=[self currentProgram];
    if(!beat4::validProgram((int)pg))return @{@"title":@"UNKNOWN",@"bpm":@0,@"sub":@(-1)};
    return _songCache[[NSString stringWithFormat:@"%ld",(long)pg]] ?: @{@"title":@"UNKNOWN",@"bpm":@0,@"sub":@(-1)};
}
- (void)persistSong:(NSDictionary*)song program:(NSInteger)pg {
    if(!beat4::validProgram((int)pg))return;
    NSString *key=[NSString stringWithFormat:@"%ld",(long)pg];
    _songCache[key]=song;_state->revision.fetch_add(1);
    beat4::writeSongStore(NSUserDefaults.standardUserDefaults,[_songCache copy]);
    double bpm=[song[@"bpm"] doubleValue];
    NSInteger note=[song[@"sub"] integerValue];
    _state->tempos[pg].store(beat4::storedBPM(bpm));
    _state->notes[pg].store(beat4::validSub((int)note)?(int)note:-1);
    _state->queues[pg].store([song[@"queue"] intValue]);
    _state->pcModes[pg].store(song[@"pcMode"]?[song[@"pcMode"] intValue]:-1);
}
- (void)saveSongTitle:(NSString*)title {
    NSInteger pg=[self currentProgram];if(!beat4::validProgram((int)pg))return;
    NSMutableDictionary *entry=[[self currentSong] mutableCopy];
    NSString *clean=[[title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    entry[@"title"]=clean.length?clean:@"UNKNOWN";
    [self persistSong:entry program:pg];
}
- (void)saveSongBPM:(double)bpm {
    NSInteger pg=[self currentProgram];
    if(!beat4::validProgram((int)pg)||!beat4::validBPM(bpm))return;
    NSMutableDictionary *entry=[[self currentSong] mutableCopy];entry[@"bpm"]=@(std::round(bpm));
    [self persistSong:entry program:pg];
}
- (void)saveSongSubNote:(NSInteger)note {
    NSInteger pg=[self currentProgram];
    if(!beat4::validProgram((int)pg)||!beat4::validSub((int)note))return;
    NSMutableDictionary *entry=[[self currentSong] mutableCopy];entry[@"sub"]=@(note);
    [self persistSong:entry program:pg];
}
- (void)setKickLevel:(float)level {float clamped=std::fmax(0.f,std::fmin(1.f,level));_state->kickLevel.store(clamped);_levelParameter.value=clamped;}
- (void)setKickEnabled:(BOOL)enabled {_state->kickEnabled.store(enabled);_enabledParameter.value=enabled?1:0;}
- (void)requestTransportToggle { [self refreshHostCallbacks:YES];_state->transportRequest.store(1); }
- (void)selectProgram:(NSInteger)pc {if(pc>=0 && pc<64)_state->localPC.store((int)pc);}
- (void)setGlobalMode:(NSInteger)mode {
    if(mode<0 || mode>2)return;
    _state->globalMode.store((int)mode);
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:@"beat4.globalMode"];
}
- (void)saveCurrentMode {
    NSInteger pc=[self currentProgram];if(pc<0 || pc>=64)return;
    NSMutableDictionary *entry=[[self currentSong] mutableCopy];
    entry[@"pcMode"]=@(_state->globalMode.load());[self persistSong:entry program:pc];
}
- (NSDictionary*)songForProgram:(NSInteger)pc {
    return _songCache[[NSString stringWithFormat:@"%ld",(long)pc]] ?: @{@"title":@"UNKNOWN",@"bpm":@0,@"sub":@(-1)};
}
- (void)saveQueue:(NSInteger)beats program:(NSInteger)pc {
    if(pc<0 || pc>=64 || beats<0 || beats>65536)return;
    NSMutableDictionary *entry=[[self songForProgram:pc] mutableCopy];
    entry[@"queue"]=@(beats);[self persistSong:entry program:pc];
}
@end
