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
#import "Beat4Kick.hpp"
#import "Beat4BeatGate.hpp"

namespace {
constexpr AUParameterAddress kLevel = 0;
constexpr AUParameterAddress kEnabled = 1;
constexpr double kTempoMin = 20;
constexpr double kTempoMax = 240;
static NSString *const kSongStoreKey = @"beat4.songs.v1";
struct State {
    std::atomic<uint64_t> sequence{0}, tick{0}, callbacks{0};
    std::atomic<double> beat{0}, bpm{0}, samplePosition{0}, bufferSeconds{0.005};
    std::atomic<int> numerator{4}, denominator{4}, mode{0};
    std::atomic<bool> transportValid{false}, musicalValid{false}, moving{false}, transportChanged{false};
    std::atomic<int> currentPG{-1};
    std::array<std::atomic<int>,128> notes;
    std::array<std::atomic<double>,128> tempos;
    std::atomic<float> kickLevel{0.60f};
    std::atomic<bool> kickEnabled{false}; // OFF at first boot: no surprising audio.
    std::atomic<int> pendingTempoPG{-1}, pendingMMC{0};
    std::atomic<bool> midiOutputConfigured{false};
    State() {for(int i=0;i<128;++i){notes[i].store(-1);tempos[i].store(0);}}
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
    int numerator, denominator, mode;
    bool transportValid, musicalValid, moving, transportChanged;
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
    AUHostTransportStateBlock _cachedTransport;
    AUHostMusicalContextBlock _cachedMusical;
    AUMIDIOutputEventBlock _cachedMIDIOutput;
    NSMutableDictionary<NSString*,NSDictionary*> *_songCache; // UI thread only
}
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
    _cachedTransport=[self.transportStateBlock copy];
    _cachedMusical=[self.musicalContextBlock copy];
    _cachedMIDIOutput=[self.MIDIOutputEventBlock copy];
    _hostHooks->transport.store((__bridge void *)_cachedTransport,std::memory_order_release);
    _hostHooks->musical.store((__bridge void *)_cachedMusical,std::memory_order_release);
    _hostHooks->midiOut.store((__bridge void *)_cachedMIDIOutput,std::memory_order_release);
    _state->midiOutputConfigured.store(_cachedMIDIOutput != nil);
    return YES;
}
- (void)deallocateRenderResources {
    _hostHooks->transport.store(nullptr,std::memory_order_release);
    _hostHooks->musical.store(nullptr,std::memory_order_release);
    _hostHooks->midiOut.store(nullptr,std::memory_order_release);
    [super deallocateRenderResources];
    _cachedTransport=nil; _cachedMusical=nil; _cachedMIDIOutput=nil;
    _state->midiOutputConfigured.store(false);
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
                if(e->parameter.parameterAddress==kLevel)
                    s->kickLevel.store(std::fmax(0.f,std::fmin(1.f,e->parameter.value)));
                else if(e->parameter.parameterAddress==kEnabled)
                    s->kickEnabled.store(e->parameter.value>=.5f);
                continue;
            }
            if(e->head.eventType!=AURenderEventMIDI || e->MIDI.length<2)continue;
            int pg=-1;
            if(beat4::isCircuitProgramChange(e->MIDI.data[0],e->MIDI.data[1],pg)){
                s->currentPG.store(pg,std::memory_order_release);
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
            const int cmd=s->pendingMMC.exchange(0,std::memory_order_acq_rel);
            if(cmd==0x01||cmd==0x02||cmd==0x05||cmd==0x09){
                uint8_t message[6]={0xF0,0x7F,0x7F,0x06,static_cast<uint8_t>(cmd),0xF7};
                midiOut(sampleTime,0,6,message);
            }
        }
        AUHostTransportStateFlags flags=(AUHostTransportStateFlags)0;
        double sample=0;
        const bool transportOK=transport!=nil && transport(&flags,&sample,nullptr,nullptr);
        double tempo=0,beatsPerBar=4,beat=0;
        NSInteger denominator=4;
        const bool musicalOK=musical!=nil && musical(&tempo,&beatsPerBar,&denominator,&beat,nullptr,nullptr);
        const bool moving=transportOK && (flags & AUHostTransportStateMoving);
        const bool changed=transportOK && (flags & AUHostTransportStateChanged);
        const auto mode=memory->observe({transportOK,musicalOK,moving,changed,beat,sample});
        const bool canPlay=moving && musicalOK && sampleRate>0 && std::isfinite(beat) &&
                std::isfinite(tempo) && tempo>0 && beatsPerBar==4 && denominator==4;
        const bool on=s->kickEnabled.load(std::memory_order_relaxed);
        const double level=static_cast<double>(s->kickLevel.load(std::memory_order_relaxed));
        int pg=s->currentPG.load(std::memory_order_relaxed);
        int pitch=beat4::validProgram(pg)?s->notes[pg].load(std::memory_order_relaxed):-1;
        const double subHz=beat4::subFrequency(pitch);
        if(!canPlay || !on)voice->reset();
        // The gate preserves the last triggered quarter-note across render buffers.
        // Visuals and sound use the same host musical position, with no free-running clock.
        gate->prepare(beat,tempo,sampleRate,frameCount,canPlay);
        for(AVAudioFrameCount i=0;i<frameCount;++i){
            double v=0;
            if(canPlay && on){
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
        s->callbacks.fetch_add(1,std::memory_order_relaxed);
        s->sequence.fetch_add(1,std::memory_order_release);
        return noErr;
    };
}
- (NSDictionary<NSString*,NSNumber*>*)transportSnapshot {
    const Snapshot s=load(*_state);
    mach_timebase_info_data_t info{};mach_timebase_info(&info);
    const uint64_t now=mach_absolute_time();
    const double age=(s.tick>0 && now>=s.tick && info.denom!=0)
        ? (double)(now-s.tick)*info.numer/info.denom/1e9:1e6;
    const bool fresh=s.callbacks>0 && age<.25;
    const bool synced=fresh && s.transportValid && s.musicalValid && std::isfinite(s.bpm) && s.bpm>0;
    const double projected=synced?beat4::displayBeat(s.beat,s.bpm,s.moving,age,s.bufferSeconds):s.beat;
    const auto d=beat4::project(projected,s.samplePosition,s.moving);
    return @{@"hasRender":@(fresh),@"synced":@(synced),@"moving":@(s.moving),
             @"mode":@(s.mode),@"active":@(d.cell),@"fraction":@(d.fractional),
             @"bpm":@(s.bpm),@"bar":@(d.bar),@"numerator":@(s.numerator),
             @"denominator":@(s.denominator),@"pg":@(_state->currentPG.load()),
             @"kickEnabled":@(_state->kickEnabled.load()),@"kickLevel":@(_state->kickLevel.load()),
             @"midiOut":@(_state->midiOutputConfigured.load())};
}
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
- (void)requestMMC:(uint8_t)command { _state->pendingMMC.store(command); }
@end
