#include "../Beat4AU/Beat4Songs.hpp"
#include "../Beat4AU/Beat4Kick.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
int main(){
    using namespace beat4;
    std::array<Song,128> songs{};
    songs[6] = {"DARK ROOM",128,5};
    songs[7] = {"HYPNOTIC",124,7};
    assert(songs[6].subNote==5 && songs[7].subNote==7);
    assert(songs[6].bpm==128 && songs[7].bpm==124);
    assert(songs[8].bpm==0 && songs[8].subNote==-1);
    int pg=-1;
    assert(isCircuitProgramChange(0xCF,6,pg) && pg==6);
    assert(isCircuitProgramChange(0xCF,70,pg) && pg==70);
    assert(!isCircuitProgramChange(0xC0,6,pg));
    assert(std::abs(subFrequency(5)-43.6535)<0.01);
    assert(std::abs(subFrequency(7)-48.9994)<0.01);
    assert(pitchBend14(20)==0 && pitchBend14(240)==16383);
    assert(std::abs(pitchBend14(130)-8192)<=1);
    assert(pitchBend14(0)==-1);
    assert(pitchBend14(241)==-1);
    assert(pulseBrightness(0.0)==0);
    assert(pulseBrightness(0.3)>.99);
    assert(pulseBrightness(0.50)==0);
    KickVoice k; k.trigger();
    double peak=0;
    for(int i=0;i<24000;++i) {double s=k.process(48000.0,subFrequency(5)); assert(std::isfinite(s)); assert(std::abs(s)<1.0); peak=std::max(peak,std::abs(s));}
    assert(peak>0.15);
    KickVoice f;KickVoice g;f.trigger();g.trigger();
    // First millisecond must be effectively the same regardless of sub note.
    double maxTransientDifference=0;
    for(int i=0;i<48;++i) {
      maxTransientDifference=std::max(maxTransientDifference,
        std::abs(f.process(48000,subFrequency(5))-g.process(48000,subFrequency(7))));
    }
    assert(maxTransientDifference<0.02);
    std::cout<<"Songs, PG channel, tempo encoding, sub tuning and kick: PASS\n";
}
