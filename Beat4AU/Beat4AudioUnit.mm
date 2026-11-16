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
#import "Beat4Set.hpp"
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
    std::atomic<uint64_t> receivedStart{0},receivedStop{0},sentTransport{0};
    std::atomic<int> lastRealtime{-1},awaitingTransport{-1};
    std::atomic<uint64_t> invalidTimestamps{0};
    std::atomic<double> beat{0}, bpm{0}, samplePosition{0}, bufferSeconds{0.005};
    std::atomic<int> numerator{4}, denominator{4}, mode{0};
    std::atomic<bool> transportValid{false}, musicalValid{false}, moving{false}, transportChanged{false};
    std::atomic<int> currentPG{-1};
    std::array<std::atomic<int>,128> notes;
    std::array<std::atomic<double>,128> tempos;
    std::atomic<float> kickLevel{0.60f};
    std::atomic<bool> kickEnabled{false}; // OFF at first boot: no surprising audio.
    std::array<std::atomic<int>,128> queues, cycleSteps;
    std::atomic<int> draftSteps{16}, localPC{-1}, selectedPC{-1}, transportRequest{-1};
    std::atomic<bool> uncertain{false},estimated{false};
    beat4::TransportPulse transportPulse;
    beat4::Journal journal;
    beat4::SetEngine set;
    beat4::ProgramEngine& engine=set.program; // render thread only
    struct Command {int kind=0,index=0,value=0;};
    std::array<Command,256> commands{};
    std::atomic<unsigned> readCommand{0},writeCommand{0};
    std::atomic<uint64_t> setPublished{0};
    std::atomic<int> setActive{-1},setQueued{-1},setReached{-1};
    beat4::PressRelease xone;
    double gestureClock=0;
    bool enqueue(int kind,int index=0,int value=0) noexcept {
        const unsigned w=writeCommand.load(),next=(w+1)%commands.size();
        if(next==readCommand.load(std::memory_order_acquire))return false;
        commands[w]={kind,index,value};writeCommand.store(next,std::memory_order_release);return true;
    }
    uint64_t packedSet() const noexcept {
        uint64_t bits=0;for(int i=0;i<8;++i)bits|=uint64_t(set.slots[i]+1)<<(7*i);
        return bits|(uint64_t(set.cursor+1)<<56)|(uint64_t(set.on)<<60)|(uint64_t(set.restartTerminal)<<61);
    }
    beat4::ProgramMemory memories;
    double lastTempoSent=0;
    std::atomic<bool> midiOutputConfigured{false};
    State() {for(int i=0;i<128;++i){notes[i].store(-1);tempos[i].store(0);queues[i].store(0);cycleSteps[i].store(16);}}
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
    int cycleSteps;
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
                s.transportChanged.load(std::memory_order_relaxed),s.draftSteps.load(std::memory_order_relaxed)};
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
    dispatch_source_t _setPersistenceTimer;
    uint64_t _lastPersistedSet;
    int _lastPersistedReached;
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
    s->draftSteps.store(16);
    [_songCache enumerateKeysAndObjectsUsingBlock:^(NSString *key,NSDictionary *entry,BOOL *stop){
        (void)stop;const int pc=key.intValue;
        s->tempos[pc].store([entry[@"bpm"] doubleValue]);
        s->notes[pc].store([entry[@"sub"] intValue]);
        s->queues[pc].store([entry[@"queue"] intValue]);
        s->cycleSteps[pc].store([entry[@"steps"] intValue]==32?32:16);
    }];
    NSDictionary *savedSet=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"beat4.set.v1"];
    NSArray *slots=savedSet[@"slots"];
    if([slots isKindOfClass:NSArray.class] && slots.count==8){
        for(int i=0;i<8;++i){const int pc=(int)beat4::storedNumber(slots[i],-1);s->set.assign(i,pc);}
        int cursor=(int)beat4::storedNumber(savedSet[@"cursor"],-1);
        s->set.cursor=cursor>=0&&cursor<8?cursor:-1;
        s->set.reachedPosition=(int)beat4::storedNumber(savedSet[@"reachedPosition"],-1);
        if(s->set.reachedPosition<0||s->set.reachedPosition>=8)s->set.reachedPosition=-1;
        s->set.on=beat4::storedNumber(savedSet[@"on"])!=0&&s->set.first()>=0;
        s->set.restartTerminal=beat4::storedNumber(savedSet[@"restart"])!=0;
    }
    s->setPublished.store(s->packedSet());_lastPersistedSet=s->packedSet();
    s->setReached.store(s->set.reachedPosition);_lastPersistedReached=s->set.reachedPosition;
    __weak Beat4AudioUnit *weakSelf=self;
    _setPersistenceTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(_setPersistenceTimer,dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),250*NSEC_PER_MSEC,10*NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_setPersistenceTimer,^{[weakSelf persistSetSnapshot];});
    dispatch_resume(_setPersistenceTimer);
    return self;
}
- (void)dealloc {if(_setPersistenceTimer)dispatch_source_cancel(_setPersistenceTimer);}
- (void)persistSetSnapshot {
    const uint64_t bits=_state->setPublished.load();
    const int reached=_state->setReached.load();
    if(bits==_lastPersistedSet&&reached==_lastPersistedReached)return;
    NSDictionary *snapshot=[self setSnapshot];
    [NSUserDefaults.standardUserDefaults setObject:snapshot forKey:@"beat4.set.v1"];
    _lastPersistedSet=bits;_lastPersistedReached=reached;
}
// Host installation is independent of editor visibility. Publish only off render.
- (void)setTransportStateBlock:(AUHostTransportStateBlock)block {
    [super setTransportStateBlock:block];[self refreshHostCallbacks:YES];
}
- (void)setMusicalContextBlock:(AUHostMusicalContextBlock)block {
    [super setMusicalContextBlock:block];[self refreshHostCallbacks:YES];
}
- (void)setMIDIOutputEventBlock:(AUMIDIOutputEventBlock)block {
    [super setMIDIOutputEventBlock:block];[self refreshHostCallbacks:YES];
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
    _state->set.queuedPosition=-1;_state->set.origin=beat4::RequestOrigin::None;
    _state->xone.cancel();
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
        s->transportPulse.observe(transportOK,moving);
        const bool changed=transportOK && (flags & AUHostTransportStateChanged);
        const auto mode=memory->observe({transportOK,musicalOK,moving,changed,beat,sample});
        const bool positionOK=transportOK && musicalOK && std::isfinite(beat) &&
            std::isfinite(barStart) && std::isfinite(tempo) && tempo>0 && beatsPerBar>0 && denominator>0;
        const double barLength=beatsPerBar*4.0/denominator;
        const beat4::HostPosition position{positionOK,moving,beat,barStart,barLength,tempo};
        for(int i=0;i<64;++i){
            s->memories.bpm[i]=s->tempos[i].load();
            s->memories.queue[i]=s->queues[i].load();
            s->memories.steps[i]=s->cycleSteps[i].load();
        }
        int previousActive=s->engine.active;
        auto apply=[&](beat4::ProgramAction a){
            if(a.sendPC){
                if(!midiOut){s->journal.write(6,a.activated,1,beat);s->set.outputFailed(previousActive,a.activated);return false;}
                // Immediate PC at our boundary, avoiding a second native Circuit queue.
                auto message=beat4::circuitMessage(a.activated);
                const auto status=midiOut(sampleTime,message.cable,message.length,message.bytes.data());
                s->journal.write(status==noErr?4:6,a.activated,1,beat);
                if(status!=noErr){s->set.outputFailed(previousActive,a.activated);return false;}
            }
            if(a.activated>=0){s->journal.write(3,a.activated,a.sendPC?1:0,beat);previousActive=a.activated;}
            if(midiOut && beat4::shouldEmitTempo(a,s->lastTempoSent)){
                auto message=beat4::tempoMessage(a.tempo);
                if(message.length){
                    const auto status=midiOut(sampleTime,message.cable,message.length,message.bytes.data());
                    if(status==noErr)s->lastTempoSent=a.tempo;
                    else {s->journal.write(6,s->engine.active,2,beat);return false;}
                }
            }
            if(!midiOut && beat4::shouldEmitTempo(a,s->lastTempoSent))return false;
            return true;
        };
        auto playGesture=[&](bool longPress){
            if(!s->set.on){s->transportPulse.request(moving);return;}
            if(longPress){s->set.stop();s->transportPulse.receive(0xFC);return;}
            const bool delivered=apply(s->set.play(position,s->memories));
            if(delivered && !moving && s->engine.selected<0)s->transportPulse.receive(0xFA);
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
            if(e->head.eventType!=AURenderEventMIDI || e->MIDI.length<1)continue;
            s->journal.write(10,e->MIDI.data[0],e->MIDI.length>1?e->MIDI.data[1]:-1,e->MIDI.length>2?e->MIDI.data[2]:-1);
            // Realtime transport is one byte, without a MIDI channel. Never
            // forward clock or raw transport to Circuit Projects: AUM owns it.
            if(e->MIDI.length==1){
                const auto status=e->MIDI.data[0];
                if(status==0xFA || status==0xFB || status==0xFC){
                    s->lastRealtime.store(status);
                    if(status==0xFC)s->receivedStop.fetch_add(1);else s->receivedStart.fetch_add(1);
                    s->journal.write(8,status,0,beat);
                }
                s->transportPulse.receive(e->MIDI.data[0]);
                continue;
            }
            bool xonePressed=false;
            const bool xoneNote=e->MIDI.length==3 && beat4::xonePlayEvent(e->MIDI.data[0],e->MIDI.data[1],e->MIDI.data[2],xonePressed);
            // Also accept the established BEAT4 CC control mapping. The XONE
            // must arrive as raw note12, not Mozaic's old immediate toggle.
            if(xoneNote || (e->MIDI.length==3 && e->MIDI.data[0]==0xBF && e->MIDI.data[1]==110)){
                double eventClock=s->gestureClock;
                if(validTime && e->head.eventSampleTime>=sampleTime)
                    eventClock+=(e->head.eventSampleTime-sampleTime)/sampleRate;
                const auto gesture=s->xone.event(xoneNote?xonePressed:e->MIDI.data[2]>0,eventClock);
                if(gesture!=beat4::Gesture::None)playGesture(gesture==beat4::Gesture::Long);
                continue;
            }
            int raw=-1;
            if(beat4::isCircuitProgramChange(e->MIDI.data[0],e->MIDI.data[1],raw)){
                s->journal.write(1,raw,0,beat);
                // In1 retains Circuit's existing confirmation protocol. In2 is
                // for independent controllers requesting a quantized recall.
                if(e->MIDI.cable==1)apply(s->set.request(raw%64,beat4::RequestOrigin::External,-1,position,s->memories));
                else if(raw>=64)apply(s->set.request(raw%64,beat4::RequestOrigin::CircuitQueued,-1,position,s->memories));
                else apply(s->set.confirm(raw,position,s->memories));
            }
        }
        previousActive=s->engine.active;
        const int local=s->localPC.exchange(-1);
        if(local>=0)s->journal.write(2,local,1,beat);
        if(local>=0)apply(s->set.request(local,beat4::RequestOrigin::Page,-1,position,s->memories));
        // Preserve FIFO order, including RESET followed by PLAY in one buffer.
        // RESET alone first executes any queue due exactly at this boundary.
        unsigned r=s->readCommand.load();
        const unsigned w=s->writeCommand.load(std::memory_order_acquire);
        while(r!=w){
            const auto command=s->commands[r];
            if(command.kind==1)s->set.enable(command.value!=0,position);
            else if(command.kind==2)s->set.assign(command.index,command.value);
            else if(command.kind==3)apply(s->set.pad(command.index,position,s->memories));
            else if(command.kind==4)playGesture(command.value!=0);
            else if(command.kind==5){apply(s->set.advance(position,s->memories));s->set.reset();}
            r=(r+1)%s->commands.size();
        }
        s->readCommand.store(r,std::memory_order_release);
        apply(s->set.advance(position,s->memories));
        s->gestureClock+=sampleRate>0?frameCount/sampleRate:0;

        if(s->engine.selected!=s->selectedPC.load() || s->engine.uncertain!=s->uncertain.load())
            s->journal.write(s->engine.uncertain?5:7,s->engine.selected,local>=0?1:0,beat);
        const int request=s->transportRequest.exchange(-1);
        if(request>=0)playGesture(false);
        s->setReached.store(s->set.reachedPosition);s->setActive.store(s->set.activePosition);s->setQueued.store(s->set.queuedPosition);
        const auto packed=s->packedSet();
        if(packed!=s->setPublished.exchange(packed))s->revision.fetch_add(1);
        if(midiOut){
            const auto message=s->transportPulse.next();
            if(message.length){
                const auto status=midiOut(sampleTime,message.cable,message.length,message.bytes.data());
                s->transportStatus.store(status);
                if(status==noErr && message.bytes[2]==127){
                    s->sentTransport.fetch_add(1);
                    s->journal.write(9,message.bytes[1],3,beat);
                }
                if(status!=noErr)s->journal.write(6,s->engine.active,3,beat);
                if(status==noErr && message.bytes[2]==127)s->localStop.store(message.bytes[1]==111);
            }
        }
        s->awaitingTransport.store(s->transportPulse.awaitingTarget());
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
        if(s->currentPG.load()!=s->engine.active)
            s->draftSteps.store(s->engine.active>=0?s->cycleSteps[s->engine.active].load():16);
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
             @"cycleSteps":@(s.cycleSteps),@"displayBeat":@(projected),
             @"localStop":@(_state->localStop.load()),@"transportStatus":@(_state->transportStatus.load()),
             @"receivedStart":@(_state->receivedStart.load()),@"receivedStop":@(_state->receivedStop.load()),
             @"sentTransport":@(_state->sentTransport.load()),@"lastRealtime":@(_state->lastRealtime.load()),
             @"awaitingTransport":@(_state->awaitingTransport.load()),
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
    _state->cycleSteps[pg].store([song[@"steps"] intValue]==32?32:16);
}
- (void)saveSongTitle:(NSString*)title {
    NSInteger pg=[self currentProgram];if(!beat4::validProgram((int)pg))return;
    NSMutableDictionary *entry=[[self currentSong] mutableCopy];
    NSString *clean=[[title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    entry[@"title"]=clean.length?clean:@"UNKNOWN";
    [self persistSong:entry program:pg];
}
- (void)saveSongBPM:(double)bpm { [self saveSongBPM:bpm program:[self currentProgram]]; }
- (void)saveSongBPM:(double)bpm program:(NSInteger)pg {
    if(pg<0 || pg>=64 || !beat4::validBPM(bpm))return;
    NSMutableDictionary *entry=[[self songForProgram:pg] mutableCopy];
    entry[@"bpm"]=@(std::round(bpm));[self persistSong:entry program:pg];
}
- (void)saveSongSubNote:(NSInteger)note {
    NSInteger pg=[self currentProgram];
    if(!beat4::validProgram((int)pg)||!beat4::validSub((int)note))return;
    NSMutableDictionary *entry=[[self currentSong] mutableCopy];entry[@"sub"]=@(note);
    [self persistSong:entry program:pg];
}
- (void)setKickLevel:(float)level {float clamped=std::fmax(0.f,std::fmin(1.f,level));_state->kickLevel.store(clamped);_levelParameter.value=clamped;}
- (void)setKickEnabled:(BOOL)enabled {_state->kickEnabled.store(enabled);_enabledParameter.value=enabled?1:0;}
- (void)requestTransportToggle { [self refreshHostCallbacks:YES];_state->enqueue(4); }
- (NSDictionary*)setSnapshot {
    const uint64_t bits=_state->setPublished.load();NSMutableArray *slots=[NSMutableArray new];
    for(int i=0;i<8;++i)[slots addObject:@((int)((bits>>(7*i))&127)-1)];
    return @{@"slots":slots,@"cursor":@((int)((bits>>56)&15)-1),@"on":@((bits>>60)&1),@"restart":@((bits>>61)&1),@"reachedPosition":@(_state->setReached.load()),@"activePosition":@(_state->setActive.load()),@"queuedPosition":@(_state->setQueued.load())};
}
- (void)setEnabled:(BOOL)enabled {_state->enqueue(1,0,enabled);}
- (void)assignSetPosition:(NSInteger)index program:(NSInteger)pc {
    if(index>=0&&index<8&&pc>=-1&&pc<64)_state->enqueue(2,(int)index,(int)pc);
}
- (void)selectSetPosition:(NSInteger)index {if(index>=0&&index<8)_state->enqueue(3,(int)index);}
- (void)requestPlayGestureLong:(BOOL)isLong {_state->enqueue(4,0,isLong);}
- (void)resetSetCache {_state->enqueue(5);}
- (void)selectProgram:(NSInteger)pc {if(pc>=0 && pc<64)_state->localPC.store((int)pc);}
- (void)setCycleSteps:(NSInteger)steps {
    if(steps!=16 && steps!=32)return;
    _state->draftSteps.store((int)steps);
}
- (void)saveCurrentCycle {
    const auto snapshot=load(*_state);
    [self saveCycleSteps:snapshot.cycleSteps program:snapshot.pg];
}
- (void)saveCycleSteps:(NSInteger)steps program:(NSInteger)pc {
    if(pc<0 || pc>=64 || (steps!=16 && steps!=32))return;
    NSMutableDictionary *entry=[[self songForProgram:pc] mutableCopy];
    entry[@"steps"]=@(steps);[self persistSong:entry program:pc];
    if(pc==[self currentProgram])_state->draftSteps.store((int)steps);
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
