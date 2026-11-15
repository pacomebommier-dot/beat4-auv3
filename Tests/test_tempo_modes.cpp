#include "../Beat4AU/Beat4Program.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace beat4;
int main(){
 for(int mode=0;mode<3;++mode){
  ProgramMemory m;m.globalMode=mode;m.bpm[7]=140;
  ProgramEngine e;HostPosition h{true,false,0,0,4,128};assert(e.request(7,false,false,h,m).tempo==140);
  h.moving=true;h.beat=1;e.request(6,false,false,h,m);e.request(7,false,false,h,m);
  h.beat=2;assert(std::abs(e.advance(h,m).tempo-129.5)<1e-9);
  h.moving=false;assert(e.advance(h,m).tempo==0);h.moving=true;h.beat=4;assert(e.advance(h,m).tempo==0);
 }
 // Full rising/falling ramps: at most one CC per integer BPM, exact endpoint.
 for(int mode:{0,1,2})for(bool rising:{false,true}){
  ProgramMemory memory;memory.globalMode=mode;memory.bpm[0]=rising?170:50;
  HostPosition host{true,true,0,0,4,rising?50.:170.};
  ProgramEngine engine;engine.request(0,false,false,host,memory);
  double last=0;int count=0,previous=-1;
  for(int step=0;step<=4000;++step){
   host.beat=step*8./4000;
   auto action=engine.advance(host,memory);
   if(shouldEmitTempo(action,last)){
    auto message=tempoMessage(action.tempo);assert(message.length==3);
    const int decoded=50+message.bytes[2];
    assert(std::abs(decoded-action.tempo)<=0.5);
    if(previous>=0)assert(rising?decoded==previous+1:decoded==previous-1);
    previous=decoded;last=action.tempo;++count;
   }
  }
  assert(count==121 && previous==(rising?170:50));
  host.beat+=1;assert(engine.advance(host,memory).tempo==0);
 }
 std::cout<<"Mode-independent rising/falling tempo ramps and STOP PASS\n";
}
