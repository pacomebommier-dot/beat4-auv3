#include "../Beat4AU/Beat4BeatGate.hpp"
#include <cassert>
#include <cmath>
#include <vector>
#include <algorithm>
#include <iostream>
using beat4::BeatGate;

int main() {
    BeatGate gate;
    constexpr double sr = 48000, bpm = 120;
    constexpr int frames = 257;
    std::vector<int> events;
    for (int offset = 0; offset < 72000; offset += frames) {
        const int count = std::min(frames, 72000-offset);
        gate.prepare((double)offset/24000, bpm, sr, count, true);
        for(int i=0;i<count;++i) if(gate.atSample(i)) events.push_back(offset+i);
    }
    assert((events == std::vector<int>{0,24000,48000}));
    // Repeated render callbacks presenting exactly the same beat must NOT retrigger.
    gate.reset();
    for(int b=0;b<100;++b) {
        gate.prepare(0,120,48000,128,true);
        for(int i=0;i<128;++i) if(gate.atSample(i)) events.push_back(100000 + b*128+i);
    }
    assert(events.size()==4);
    // Pause and mid-beat resume: do not make an artificial click at buffer start.
    gate.prepare(2.4,120,48000,128,false);
    gate.prepare(2.4,120,48000,128,true);
    for(int i=0;i<128;++i) assert(!gate.atSample(i));
    // Rewind to zero followed by transport PLAY: first beat triggers once.
    gate.prepare(0,120,48000,256,true);
    int hits=0;
    for(int i=0;i<256;++i) hits += gate.atSample(i);
    assert(hits==1);
    // Distinct sample rates, non-power-of-two buffers and noninteger beat lengths.
    for(double rate : {44100.0,48000.0,96000.0}){
      for(int size : {128,256,511}){
        gate.reset();
        int seen=0;
        constexpr double speed=127.0;
        const int total=(int)(rate*60/speed*4.8);
        for(int offset=0;offset<total;offset+=size){
          const int count=std::min(size,total-offset);
          gate.prepare(offset*speed/(60*rate),speed,rate,count,true);
          for(int i=0;i<count;++i){
            if(gate.atSample(i)){
              const double phase=(offset+i)*speed/(60*rate);
              assert(std::abs(phase-std::round(phase))<speed/(60*rate)+1e-8);
              ++seen;
            }
          }
        }
        assert(seen==5);
      }
    }
    // Empty, invalid and nonplaying buffers must be safe.
    gate.prepare(NAN,120,48000,128,true);
    for(int i=0;i<128;++i) assert(!gate.atSample(i));
    gate.prepare(0,120,48000,128,true);
    assert(gate.atSample(0));
    std::cout << "Beat gate PASS: 3 true beats / 72000 samples, no per-buffer kicks, hold/resume, rewind\n";
}
