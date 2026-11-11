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
#import "Beat4MMC.hpp"
#import "Beat4Songs.hpp"
#import "Beat4Kick.hpp"
#import "Beat4BeatGate.hpp"

namespace {
constexpr AUParameterAddress kLevel = 0;
constexpr AUParameterAddress kEnabled = 1;
constexpr double kTempoMin = 20;
constexpr double kTempoMax = 240;
static NSString *const kSongStoreKey = @"beat4.songs.v1";
struct State {
    std::atomic<uint64_t> sequence{0}, tick{0}, callbacks{0}, displayRevision{1};
    std::atomic<double> beat{0}, bpm{0}, samplePosition{0}, bufferSeconds{0.005};
    std::atomic<int> numerator{4}, denominator{4}, mode{0};
    std::atomic<bool> transportValid{false}, musicalValid{false}, moving{false}, transportChanged{false};
    std::atomic<int> currentPG{-1};
    std::array<std::atomic<int>,128> notes;
    std::array<std::atomic<double>,128> tempos;
    std::atomic<float> kickLevel{0.60f};
    std::atomic<bool> kickEnabled{false}; // OFF at first boot: no surprising audio.
    std::atomic<int> pendingTempoPG{-1}, mmcLastAttempt{0}, mmcLastStatus{0};
    std::atomic<int> mmcLastAcknowledged{0};
    std::atomic<uint64_t> mmcDelivery{0};
    std::atomic<uint32_t> mmcNextGeneration{0};
    std::atomic<uint64_t> mmcRequested{0}, mmcAttempts{0};
    std::atomic<bool> midiOutputConfigured{false};
    std::atomic<bool> transportCallbackPresent{false}, musicalCallbackPresent{false};
    std::atomic<bool> transportReturned{false}, musicalReturned{false};
    State() {for(int i=0;i<128;++i){notes[i].store(-1);tempos[i].store(0);}}
};
// Stable, realtime-readable callback slots. The UI thread refreshes these as the
// host installs callbacks; retained blocks keep published pointers valid.
struct HostHooks {
    std::atomic<void *> transport{nullptr};
    std::atomic<void *> musical{nullptr};
    std::atomic<void *> midiOut{nullptr};
};
struct Snapshot {
    uint64_t tick, callbacks;
    double beat, bpm, samplePosition, bufferSeconds;
    int numerator, denominator, mode;
    bool transportValid, musicalValid, moving, transportChanged;
    bool transportCallbackPresent, musicalCallbackPresent, transportReturned, musicalReturned;
    uint64_t mmcRequested, mmcAttempts;
    uint64_t mmcDelivery;
    int mmcLastAttempt, mmcLastStatus, mmcLastAcknowledged;
    bool midiOutputConfigured;
};
Snapshot load(const State& s) noexcept {
    Snapshot result{};
    for(int attempt=0;attempt<4;++attempt){
        const auto a=s.sequence.load(std::memory_order_acquire);
        if(a&1) continue;
        result={s.tick.load(std::memory_order_relaxed), s.callbacks.load(std::memory_order_relaxed),
                s.beat.load(std::memory_order_relaxed), s.bpm.load(std::memory_order_relaxed),
                s.samplePosition.load(std::memory_order_relaxed), s.bufferSeconds.load(std::memory_order_relaxed),
                s.numerator.load(std::memory_order_relaxed), s.denominator.load(std::memory_order_relaxed),
                s.mode.load(std::memory_order_relaxed), s.transportValid.load(std::memory_order_relaxed),
                s.musicalValid.load(std::memory_order_relaxed), s.moving.load(std::memory_order_relaxed),
                s.transportChanged.load(std::memory_order_relaxed),
                s.transportCallbackPresent.load(std::memory_order_relaxed),
                s.musicalCallbackPresent.load(std::memory_order_relaxed),
                s.transportReturned.load(std::memory_order_relaxed),
                s.musicalReturned.load(std::memory_order_relaxed),
                s.mmcRequested.load(std::memory_order_relaxed), s.mmcAttempts.load(std::memory_order_relaxed),
                s.mmcDelivery.load(std::memory_order_relaxed), s.mmcLastAttempt.load(std::memory_order_relaxed),
                s.mmcLastStatus.load(std::memory_order_relaxed),
                s.mmcLastAcknowledged.load(std::memory_order_relaxed),
                s.midiOutputConfigured.load(std::memory_order_relaxed)};
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
    AUHostTransportStateBlock _cachedTransport;
    AUHostMusicalContextBlock _cachedMusical;
    AUMIDIOutputEventBlock _cachedMIDIOutput;
    NSMutableArray * _hostCallbackKeepalive;
    NSMutableDictionary<NSString*,NSDictionary*> *_songCache; // UI thread only
}
- (void)refreshHostCallbacksReplacingExisting:(BOOL)replace requestStarted:(BOOL)requestStarted;
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
        if(parameter.address==kLevel)s->kickLevel.store(std::fmax(0.f,std::fmin(1.f,value)));
        else if(parameter.address==kEnabled)s->kickEnabled.store(value>=.5f);
    };
    _params.implementorValueProvider=^AUValue(AUParameter *parameter){
        return parameter.address==kLevel?s->kickLevel.load():(s->kickEnabled.load()?1.f:0.f);
    };
    _songCache=[NSMutableDictionary new];
    NSDictionary *saved=[[NSUserDefaults standardUserDefaults] dictionaryForKey:(NSString*)kSongStoreKey];
    [saved enumerateKeysAndObjectsUsingBlock:^(id key,id obj,BOOL *stop){
        (void)stop;
        int pg=[key intValue];
        if(!beat4::validProgram(pg) || ![obj isKindOfClass:NSDictionary.class])return;
        NSDictionary *entry=(NSDictionary*)obj;
        NSString* title=[entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"UNKNOWN";
        double bpm=[entry[@"bpm"] doubleValue];
        NSInteger note=entry[@"sub"] ? [entry[@"sub"] integerValue] : -1;
        _songCache[key]=@{@"title":title, @"bpm":@(beat4::validBPM(bpm)?bpm:0),
                         @"sub":@(beat4::validSub((int)note)?note:-1)};
        s->tempos[pg].store(beat4::validBPM(bpm)?bpm:0);
        s->notes[pg].store(beat4::validSub((int)note)?(int)note:-1);
    }];
    return self;
}
- (AUParameterTree *)parameterTree {return _params;}
- (AUAudioUnitBusArray *)inputBusses {return _inputs;}
- (AUAudioUnitBusArray *)outputBusses {return _outputs;}
- (NSArray<NSString *> *)MIDIOutputNames {return @[@"AUM Control"];}
- (NSInteger)virtualMIDICableCount {return 1;}
- (BOOL)allocateRenderResourcesAndReturnError:(NSError * _Nullable __autoreleasing *)outError {
    if(![super allocateRenderResourcesAndReturnError:outError])return NO;
    [self refreshHostCallbacksReplacingExisting:YES requestStarted:NO];
    return YES;
}
- (void)deallocateRenderResources {
    @synchronized(self){
        _cachedTransport=nil;
        _cachedMusical=nil;
        _cachedMIDIOutput=nil;
        _hostHooks->transport.store(nullptr,std::memory_order_release);
        _hostHooks->musical.store(nullptr,std::memory_order_release);
        _hostHooks->midiOut.store(nullptr,std::memory_order_release);
    }
    [super deallocateRenderResources];
    _state->transportCallbackPresent.store(false,std::memory_order_relaxed);
    _state->musicalCallbackPresent.store(false,std::memory_order_relaxed);
    _state->midiOutputConfigured.store(false,std::memory_order_relaxed);
    _state->displayRevision.fetch_add(1,std::memory_order_release);
}
- (void)refreshHostCallbacksReplacingExisting:(BOOL)replace requestStarted:(BOOL)requestStarted {
    @synchronized(self){
        const bool missing=!_cachedTransport || !_cachedMusical || !_cachedMIDIOutput;
        if(!beat4::hostCallbacksMustRefresh(replace,requestStarted,missing))return;
        AUHostTransportStateBlock transport=(replace || !_cachedTransport)
            ? [self.transportStateBlock copy] : _cachedTransport;
        AUHostMusicalContextBlock musical=(replace || !_cachedMusical)
            ? [self.musicalContextBlock copy] : _cachedMusical;
        AUMIDIOutputEventBlock midi=(replace || !_cachedMIDIOutput)
            ? [self.MIDIOutputEventBlock copy] : _cachedMIDIOutput;
        const bool changed=transport!=_cachedTransport || musical!=_cachedMusical ||
                           midi!=_cachedMIDIOutput;
        if(transport && transport!=_cachedTransport)[_hostCallbackKeepalive addObject:transport];
        if(musical && musical!=_cachedMusical)[_hostCallbackKeepalive addObject:musical];
        if(midi && midi!=_cachedMIDIOutput)[_hostCallbackKeepalive addObject:midi];
        _cachedTransport=transport;
        _cachedMusical=musical;
        _cachedMIDIOutput=midi;
        _hostHooks->transport.store((__bridge void *)transport,std::memory_order_release);
        _hostHooks->musical.store((__bridge void *)musical,std::memory_order_release);
        _hostHooks->midiOut.store((__bridge void *)midi,std::memory_order_release);
        _state->transportCallbackPresent.store(transport!=nil,std::memory_order_relaxed);
        _state->musicalCallbackPresent.store(musical!=nil,std::memory_order_relaxed);
        _state->midiOutputConfigured.store(midi!=nil,std::memory_order_relaxed);
        if(changed || replace)_state->displayRevision.fetch_add(1,std::memory_order_release);
    }
}
- (AUInternalRenderBlock)internalRenderBlock {
    const std::shared_ptr<State> shared=_state;
    const std::shared_ptr<beat4::HostMemory> memory=_hostMemory;
    const std::shared_ptr<beat4::KickVoice> voice=_kickVoice;
    const std::shared_ptr<beat4::BeatGate> gate=_beatGate;
    const std::shared_ptr<HostHooks> hooks=_hostHooks;
    const double sampleRate=_output.format.sampleRate;
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags,
         const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, NSInteger outputBusNumber,
         AudioBufferList *outputData, const AURenderEvent *events, AURenderPullInputBlock pullInput) {
        (void)actionFlags;(void)outputBusNumber;(void)pullInput;
        State *s=shared.get();
        // Resolve callbacks when rendering, not when the host first queries the
        // block. The backing blocks remain retained in the AU while allocated.
        const AUHostTransportStateBlock transport=(__bridge AUHostTransportStateBlock)hooks->transport.load(std::memory_order_acquire);
        const AUHostMusicalContextBlock musical=(__bridge AUHostMusicalContextBlock)hooks->musical.load(std::memory_order_acquire);
        const AUMIDIOutputEventBlock midiOut=(__bridge AUMIDIOutputEventBlock)hooks->midiOut.load(std::memory_order_acquire);
        const auto sampleTime=(timestamp && (timestamp->mFlags & kAudioTimeStampSampleTimeValid))
            ? static_cast<AUEventSampleTime>(timestamp->mSampleTime) : AUEventSampleTimeImmediate;
        for(const AURenderEvent *e=events;e!=nullptr;e=e->head.next){
            if(e->head.eventType==AURenderEventParameter || e->head.eventType==AURenderEventParameterRamp){
                // AUM may schedule automation/MIDI Learn as realtime parameter events,
                // bypassing the UI-side AUParameter value observer.
                if(e->parameter.parameterAddress==kLevel){
                    const float value=std::fmax(0.f,std::fmin(1.f,e->parameter.value));
                    if(s->kickLevel.exchange(value)!=value)s->displayRevision.fetch_add(1,std::memory_order_relaxed);
                }else if(e->parameter.parameterAddress==kEnabled){
                    const bool value=e->parameter.value>=.5f;
                    if(s->kickEnabled.exchange(value)!=value)s->displayRevision.fetch_add(1,std::memory_order_relaxed);
                }
                continue;
            }
            if(e->head.eventType!=AURenderEventMIDI || e->MIDI.length<2)continue;
            int pg=-1;
            if(beat4::isCircuitProgramChange(e->MIDI.data[0],e->MIDI.data[1],pg)){
                if(s->currentPG.exchange(pg,std::memory_order_acq_rel)!=pg)
                    s->displayRevision.fetch_add(1,std::memory_order_relaxed);
                s->pendingTempoPG.store(pg,std::memory_order_release);
            }
        }
        if(midiOut){
            const int pg=s->pendingTempoPG.exchange(-1,std::memory_order_acq_rel);
            if(beat4::validProgram(pg) && pg==s->currentPG.load(std::memory_order_acquire)){
                const double wanted=s->tempos[pg].load(std::memory_order_relaxed);
                const int encoded=beat4::pitchBend14(wanted,kTempoMin,kTempoMax);
                if(encoded>=0){
                    // Channel 15 PB (0xEE). Route this MIDI output to AUM's own MIDI Control.
                    uint8_t bytes[3]={0xEE,static_cast<uint8_t>(encoded&0x7F),
                                             static_cast<uint8_t>((encoded>>7)&0x7F)};
                    midiOut(sampleTime,0,3,bytes);
                }
            }
        }
        AUHostTransportStateFlags flags=(AUHostTransportStateFlags)0;
        double sample=0;
        const bool transportReturned=transport!=nil && transport(&flags,&sample,nullptr,nullptr);
        double tempo=0,beatsPerBar=4,beat=0;
        NSInteger denominator=4;
        const bool musicalReturned=musical!=nil && musical(&tempo,&beatsPerBar,&denominator,&beat,nullptr,nullptr);
        const bool transportOK=beat4::validTransportReading(transport!=nil,transportReturned,sample);
        const bool musicalOK=beat4::validMusicalReading(musical!=nil,musicalReturned,tempo,
                                                         beatsPerBar,(int)denominator,beat);
        const bool moving=transportOK && (flags & AUHostTransportStateMoving);
        const bool changed=transportOK && (flags & AUHostTransportStateChanged);
        const bool atOrigin=transportOK && musicalOK && std::abs(beat)<.005 && std::abs(sample)<1024.0;
        uint64_t mmcWord=s->mmcDelivery.load(std::memory_order_acquire);
        const int mmcCommand=beat4::mmcDeliveryCommand(mmcWord);
        if(beat4::validMMCCommand(mmcCommand)){
            const bool goalReached=beat4::mmcGoalReached(mmcCommand,moving,atOrigin);
            const auto decision=beat4::mmcRenderDecision(mmcWord,goalReached,midiOut!=nil,frameCount);
            if(decision.nextWord!=mmcWord){
                if(!s->mmcDelivery.compare_exchange_strong(mmcWord,decision.nextWord,
                                                            std::memory_order_acq_rel))goto mmc_done;
                mmcWord=decision.nextWord;
            }
            if(decision.action==beat4::MMCAction::Acknowledge){
                s->mmcLastAcknowledged.store(mmcCommand,std::memory_order_relaxed);
                s->displayRevision.fetch_add(1,std::memory_order_relaxed);
            }else if(decision.action==beat4::MMCAction::FailNoAck){
                s->mmcLastAcknowledged.store(0,std::memory_order_relaxed);
                s->displayRevision.fetch_add(1,std::memory_order_relaxed);
            }else if(decision.action==beat4::MMCAction::Send){
                // A tap may replace the request between buffers. Verify its
                // generation immediately before emitting the realtime event.
                if(s->mmcDelivery.load(std::memory_order_acquire)!=mmcWord)goto mmc_done;
                uint8_t message[6]={0xF0,0x7F,0x7F,0x06,static_cast<uint8_t>(mmcCommand),0xF7};
                const AUAudioUnitStatus status=midiOut(sampleTime,0,6,message);
                const auto afterSend=beat4::mmcAfterSend(mmcWord,(int)status,sampleRate);
                if(s->mmcDelivery.compare_exchange_strong(mmcWord,afterSend,std::memory_order_acq_rel)){
                    s->mmcLastAttempt.store(mmcCommand,std::memory_order_relaxed);
                    s->mmcLastStatus.store((int)status,std::memory_order_relaxed);
                    s->mmcLastAcknowledged.store(0,std::memory_order_relaxed);
                    s->mmcAttempts.fetch_add(1,std::memory_order_relaxed);
                    s->displayRevision.fetch_add(1,std::memory_order_relaxed);
                }
            }
        }
mmc_done:
        const auto mode=memory->observe({transportOK,musicalOK,moving,changed,beat,sample});
        const bool firstRender=s->callbacks.load(std::memory_order_relaxed)==0;
        const bool visibleChanged=firstRender || s->moving.load(std::memory_order_relaxed)!=moving ||
            s->transportValid.load(std::memory_order_relaxed)!=transportOK ||
            s->musicalValid.load(std::memory_order_relaxed)!=musicalOK ||
            s->transportReturned.load(std::memory_order_relaxed)!=transportReturned ||
            s->musicalReturned.load(std::memory_order_relaxed)!=musicalReturned ||
            s->mode.load(std::memory_order_relaxed)!=(int)mode ||
            s->numerator.load(std::memory_order_relaxed)!=(int)beatsPerBar ||
            s->denominator.load(std::memory_order_relaxed)!=(int)denominator ||
            std::abs(s->bpm.load(std::memory_order_relaxed)-tempo)>.001;
        const bool canPlay=moving && musicalOK && sampleRate>0 && std::isfinite(beat) &&
                std::isfinite(tempo) && tempo>0 && beatsPerBar==4 && denominator==4;
        const bool on=s->kickEnabled.load(std::memory_order_relaxed);
        const double level=static_cast<double>(s->kickLevel.load(std::memory_order_relaxed));
        int pg=s->currentPG.load(std::memory_order_relaxed);
        int pitch=beat4::validProgram(pg)?s->notes[pg].load(std::memory_order_relaxed):-1;
        const double subHz=beat4::subFrequency(pitch);
        // The gate preserves the last triggered quarter-note across render buffers.
        // Visuals and sound use the same host musical position, with no free-running clock.
        gate->prepare(beat,tempo,sampleRate,frameCount,canPlay&&on);
        if(!canPlay || !on){
            voice->reset();
            if(actionFlags)*actionFlags|=kAudioUnitRenderAction_OutputIsSilence;
            if(outputData){
                for(UInt32 b=0;b<outputData->mNumberBuffers;++b){
                    AudioBuffer &buf=outputData->mBuffers[b];
                    if(buf.mData){
                        const std::size_t bytes=beat4::audioBytesForFrames(frameCount,buf.mNumberChannels,buf.mDataByteSize);
                        std::memset(buf.mData,0,bytes);
                    }
                }
            }
        }else for(AVAudioFrameCount i=0;i<frameCount;++i){
            double v=0;
            {
                if(gate->atSample(i))voice->trigger();
                v=voice->process(sampleRate,subHz)*level*0.70;
            }
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
        s->sequence.fetch_add(1,std::memory_order_acq_rel);
        s->tick.store(mach_absolute_time(),std::memory_order_relaxed);
        s->beat.store(beat,std::memory_order_relaxed);
        s->bpm.store(tempo,std::memory_order_relaxed);
        s->samplePosition.store(sample,std::memory_order_relaxed);
        s->bufferSeconds.store(sampleRate>0?frameCount/sampleRate:0,std::memory_order_relaxed);
        s->numerator.store((int)beatsPerBar,std::memory_order_relaxed);
        s->denominator.store((int)denominator,std::memory_order_relaxed);
        s->moving.store(moving,std::memory_order_relaxed);
        s->mode.store((int)mode,std::memory_order_relaxed);
        s->transportChanged.store(changed,std::memory_order_relaxed);
        s->transportValid.store(transportOK,std::memory_order_relaxed);
        s->musicalValid.store(musicalOK,std::memory_order_relaxed);
        s->transportReturned.store(transportReturned,std::memory_order_relaxed);
        s->musicalReturned.store(musicalReturned,std::memory_order_relaxed);
        s->callbacks.fetch_add(1,std::memory_order_relaxed);
        if(visibleChanged)s->displayRevision.fetch_add(1,std::memory_order_relaxed);
        s->sequence.fetch_add(1,std::memory_order_release);
        return noErr;
    };
}
- (NSDictionary<NSString*,NSNumber*>*)transportSnapshot {
    if(!_cachedTransport || !_cachedMusical || !_cachedMIDIOutput)
        [self refreshHostCallbacksReplacingExisting:NO requestStarted:NO];
    const Snapshot s=load(*_state);
    mach_timebase_info_data_t info{};mach_timebase_info(&info);
    const uint64_t now=mach_absolute_time();
    const double age=(s.tick>0 && now>=s.tick && info.denom!=0)
        ? (double)(now-s.tick)*info.numer/info.denom/1e9:1e6;
    const bool fresh=s.callbacks>0 && age<.25;
    const bool synced=fresh && s.transportValid && s.musicalValid;
    const double projected=synced?beat4::displayBeat(s.beat,s.bpm,s.moving,age,s.bufferSeconds):s.beat;
    const auto d=beat4::project(projected,s.samplePosition,s.moving);
    return @{@"hasRender":@(fresh),@"synced":@(synced),@"moving":@(s.moving),
             @"renderCallbacks":@(s.callbacks),@"renderAge":@(age),
             @"transportCallback":@(s.transportCallbackPresent),@"transportReturned":@(s.transportReturned),
             @"musicalCallback":@(s.musicalCallbackPresent),@"musicalReturned":@(s.musicalReturned),
             @"mode":@(s.mode),@"active":@(d.cell),@"fraction":@(d.fractional),
             @"bpm":@(s.bpm),@"beat":@(s.beat),@"bar":@(d.bar),@"numerator":@(s.numerator),
             @"denominator":@(s.denominator),@"pg":@(_state->currentPG.load()),
             @"kickEnabled":@(_state->kickEnabled.load()),@"kickLevel":@(_state->kickLevel.load()),
             @"midiOut":@(s.midiOutputConfigured),@"mmcRequested":@(s.mmcRequested),
             @"mmcPending":@(beat4::mmcDeliveryCommand(s.mmcDelivery)),@"mmcAttempts":@(s.mmcAttempts),
             @"mmcRequestAttempts":@(beat4::mmcDeliveryAttempts(s.mmcDelivery)),
             @"mmcLastAttempt":@(s.mmcLastAttempt),@"mmcLastStatus":@(s.mmcLastStatus),
             @"mmcAcknowledged":@(s.mmcLastAcknowledged),
             @"mmcFailed":@(beat4::mmcDeliveryFailed(s.mmcDelivery))};
}
- (uint64_t)displayRevision {return _state->displayRevision.load(std::memory_order_acquire);}
- (NSInteger)currentProgram {return _state->currentPG.load();}
- (NSDictionary<NSString*,id>*)currentSong {
    NSInteger pg=[self currentProgram];
    if(!beat4::validProgram((int)pg))return @{@"title":@"UNKNOWN",@"bpm":@0,@"sub":@(-1)};
    return _songCache[[NSString stringWithFormat:@"%ld",(long)pg]] ?: @{@"title":@"UNKNOWN",@"bpm":@0,@"sub":@(-1)};
}
- (void)persistSong:(NSDictionary*)song program:(NSInteger)pg {
    if(!beat4::validProgram((int)pg))return;
    NSString *key=[NSString stringWithFormat:@"%ld",(long)pg];
    _songCache[key]=song;
    [[NSUserDefaults standardUserDefaults] setObject:[_songCache copy] forKey:(NSString*)kSongStoreKey];
    double bpm=[song[@"bpm"] doubleValue];
    NSInteger note=[song[@"sub"] integerValue];
    _state->tempos[pg].store(beat4::validBPM(bpm)?bpm:0);
    _state->notes[pg].store(beat4::validSub((int)note)?(int)note:-1);
    if(beat4::validBPM(bpm) && pg==[self currentProgram])_state->pendingTempoPG.store((int)pg);
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
    // The BPM recall uses the same host MIDI output as MMC. Refresh it before
    // arming the realtime pitch-bend event in case AUM reallocated the route.
    [self refreshHostCallbacksReplacingExisting:YES requestStarted:NO];
    NSMutableDictionary *entry=[[self currentSong] mutableCopy];entry[@"bpm"]=@(bpm);
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
- (void)requestMMC:(uint8_t)command {
    if(!beat4::validMMCCommand(command))return;
    [self refreshHostCallbacksReplacingExisting:YES requestStarted:YES];
    _state->mmcRequested.fetch_add(1,std::memory_order_relaxed);
    _state->mmcLastAcknowledged.store(0,std::memory_order_relaxed);
    const uint32_t generation=(_state->mmcNextGeneration.fetch_add(1,std::memory_order_relaxed)+1)&0x7fffffffU;
    _state->mmcDelivery.store(beat4::mmcPackDelivery(generation,command,0,0,false),
                              std::memory_order_release);
    _state->displayRevision.fetch_add(1,std::memory_order_release);
}
@end
