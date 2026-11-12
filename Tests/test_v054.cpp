#include "../Beat4AU/Beat4SafetyMIDI.hpp"
#include "../Beat4AU/Beat4Lights.hpp"
#include "../Beat4AU/Beat4AudioGain.hpp"
#include "../Beat4AU/Beat4Kick.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
int main(){
    // Separate, learnable commands even at rest; no CC PAUSE or MMC duplicate.
    auto start=beat4::safetyCC(2), stop=beat4::safetyCC(1), pause=beat4::safetyCC(9);
    assert(start==110 && stop==111 && pause==-1);
    assert(beat4::useMMC(9,true) && !beat4::useMMC(2,true) && beat4::useMMC(2,false));
    beat4::SafetyPulse pulse;
    pulse.request(2);
    auto e=pulse.next();assert(e.cc==110 && e.value==127);
    // A rapid STOP must not lose START's release.
    pulse.request(1);e=pulse.next();assert(e.cc==110 && e.value==0);
    e=pulse.next();assert(e.cc==111 && e.value==127);
    e=pulse.next();assert(e.cc==111 && e.value==0);
    assert(pulse.next().cc==-1);
    pulse.request(9);assert(pulse.next().cc==-1);

    beat4::Lights lights;
    lights.update(3.5,true,true,false,0);
    assert(lights.energy(3)>0 && lights.energy(2)==0); // no phantom previous at first PLAY
    const double active=lights.energy(3);
    lights.update(3.5,false,true,false,0); // PAUSE holds actual energy
    lights.update(3.5,false,true,false,.15);
    assert(std::abs(lights.energy(3)-active)<1e-9);
    lights.update(3.5,false,true,true,0); // explicit STOP during PAUSE
    assert(std::abs(lights.energy(3)-active)<1e-9);
    lights.update(0,false,true,true,.15);
    assert(lights.energy(3)>0 && lights.energy(3)<active && lights.animating());
    lights.update(0,false,true,true,.15);
    assert(lights.energy(3)==0 && !lights.animating());
    lights.update(0,true,true,false,0);
    assert(lights.energy(3)==0); // wait its turn after STOP
    lights.update(.9,true,true,false,.1);
    lights.update(1.0,true,true,false,.1);
    assert(lights.energy(0)==1); // normal continuous handoff
    lights.update(1.25,true,true,false,.1);
    const double held=lights.energy(1), tail=lights.energy(0);
    lights.update(1.25,false,true,false,0);
    lights.update(1.25,false,true,false,.15);
    assert(lights.energy(1)==held && lights.energy(0)>0 && lights.energy(0)<tail);
    lights.update(1.25,false,true,false,.15);
    assert(lights.energy(0)==0 && lights.energy(1)==held);
    lights.update(1.25,true,true,false,0);
    assert(lights.energy(0)==0); // no ghost on resume

    for(double sr:{44100.,48000.,96000.}){
        beat4::AudioGain gain;
        double previous=0;
        for(int i=0;i<int(sr*.04);++i){
            const double v=gain.next(true,1,sr);
            assert(std::isfinite(v)&&v>=0&&v<=1);
            assert(std::abs(v-previous)<=.003); previous=v;
        }
        assert(std::abs(previous-1)<1e-8);
        double first=gain.next(false,1,sr);
        assert(first>0 && first<previous); // no hard cut
        for(int i=0;i<int(sr*.02);++i)gain.next(false,1,sr);
        assert(gain.silent());
        gain.reset();
        for(int i=0;i<int(sr*.1);++i){
            const double level=(i/31)%2?1:0;
            double v=gain.next(true,level,sr);
            assert(std::isfinite(v)&&v>=0&&v<=1);
        }
        beat4::KickVoice voice; voice.trigger();
        double last=0;
        for(int i=0;i<int(sr*.8);++i){
            double v=voice.process(sr,43.6535);
            if(i>int(sr*.745))assert(std::abs(v-last)<.002);
            last=v;
        }
        assert(std::abs(last)<1e-8);
        voice.trigger();for(int i=0;i<int(sr*.12);++i)last=voice.process(sr,43.6535);
        voice.trigger();double next=voice.process(sr,43.6535);
        assert(std::abs(next-last)<.02); // retrigger must not zero a ringing tail
    }
    std::cout<<"V054 PASS: CC pulses, LED stop/pause/restart, sample gain ramps, kick seams\n";
}
