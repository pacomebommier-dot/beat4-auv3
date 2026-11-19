#include "../Beat4AU/Beat4Program.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace beat4;
static HostPosition host(double beat,bool moving=true){return {true,moving,beat,std::floor(beat/4)*4,4,128};}
static void start(ProgramEngine& e,ProgramMemory& m,int pc=0){e.request(pc,false,false,host(0,false),m);e.advance(host(0),m);}
int main(){
 // Defaults ignore every legacy mode/queue value and wait exactly next bar.
 for(int legacy:{-1,0,1,2}){
  ProgramMemory m;m.globalMode=2;m.mode[0]=legacy;m.queue[0]=64;
  ProgramEngine e;start(e,m);e.request(1,true,false,host(1),m);
  assert(e.advance(host(3.99),m).activated<0);
  auto a=e.advance(host(4),m);assert(a.activated==1&&a.sendPC);
 }
 // Only ACTIVE length controls waiting, including selection in second bar of32.
 for(double at:{1.,5.,7.99}){
  ProgramMemory m;m.steps[0]=32;m.steps[1]=16;ProgramEngine e;start(e,m);
  e.request(1,false,true,host(at),m);assert(e.advance(host(7.999),m).activated<0);
  auto a=e.advance(host(8),m);assert(a.activated==1&&!a.sendPC&&!e.uncertain);
 }
 {ProgramMemory m;m.steps[1]=32;ProgramEngine e;start(e,m);
  e.request(1,true,false,host(1),m);assert(e.advance(host(4),m).activated==1);
  // B began at beat4, so its32-step boundary is12, not global beat8.
  e.request(2,true,false,host(5),m);assert(e.advance(host(8),m).activated<0);
  assert(e.advance(host(12),m).activated==2);
 }
 {ProgramMemory m;m.steps[0]=32;m.steps[1]=32;ProgramEngine e;start(e,m);
  e.request(1,true,false,host(1),m);assert(e.advance(host(8.1),m).activated==1);
  // Late render must not accumulate phase drift from8 to8.1.
  e.request(2,true,false,host(9),m);assert(e.advance(host(16),m).activated==2);
 }
 {ProgramMemory m;m.steps[0]=32;ProgramEngine e;start(e,m);
  e.request(0,false,false,host(5),m); // Same active confirmation must preserve origin0.
  e.request(1,true,false,host(6),m);assert(e.advance(host(8),m).activated==1);
 }
 // Tempo is independent of outgoing cycle duration and survives activation.
 {ProgramMemory m;m.bpm[1]=148;m.rampBars[1]=2;ProgramEngine e;start(e,m);
  e.request(1,true,false,host(1),m);auto a=e.advance(host(3),m);assert(a.tempo==0);
  a=e.advance(host(4),m);assert(a.activated==1&&a.tempo==128);
  assert(std::abs(e.advance(host(12),m).tempo-148)<1e-7);
 }
 // Missing host then recovery, seek, and failed MIDI output cannot deadlock/retry.
 {ProgramMemory m;m.steps[0]=32;ProgramEngine e;start(e,m);
  auto h=host(5);h.valid=false;e.request(1,false,true,h,m);assert(e.uncertain);
  e.advance(host(5),m);assert(!e.uncertain);assert(e.advance(host(12),m).activated==1);
 }
 {ProgramMemory m;m.steps[0]=32;ProgramEngine e;start(e,m);
  e.request(1,true,false,host(9),m);e.outputFailed(0,1);e.advance(host(1),m);
  assert(e.advance(host(8),m).activated<0&&e.uncertain&&e.active==0);
 }
 // A request in the same render callback as a backward seek must reanchor first.
 {ProgramMemory m;m.steps[0]=32;ProgramEngine e;start(e,m);
  e.advance(host(9),m);e.request(1,true,false,host(5),m);
  assert(e.advance(host(8),m).activated<0);
  assert(e.advance(host(12),m).activated==1);
 }
 std::cout<<"Active16/32 cycle ownership, phase, confirmation and ramp PASS\n";
}
