#include "../Beat4AU/Beat4Program.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace beat4;
int main(){
 for(int mode=0;mode<3;++mode){
  ProgramMemory m;m.globalMode=mode;m.bpm[7]=140;
  ProgramEngine e;HostPosition h{true,false,0,0,4,128};
  assert(e.request(7,false,false,h,m).tempo==140);
  h.moving=true;h.beat=1;e.request(7,false,false,h,m);
  h.beat=2;auto a=e.advance(h,m);
  assert(mode==0?a.tempo==0:mode==1?std::abs(a.tempo-128.375)<1e-9:a.tempo==134);
  h.moving=false;assert(e.advance(h,m).tempo==0);
  h.moving=true;h.beat=4;assert(e.advance(h,m).tempo==0);
 }
 ProgramMemory m;m.bpm[0]=135;m.mode[0]=1;m.globalMode=0;
 ProgramEngine e;HostPosition h{true,true,0,0,4,128};e.request(0,false,false,h,m);
 h.beat=12;m.globalMode=2;m.mode[0]=0;assert(e.advance(h,m).tempo==130.625);
 h.bpm=131;m.bpm[1]=140;m.mode[1]=2;e.request(1,false,false,h,m);
 h.beat=13;assert(e.advance(h,m).tempo==135.5);
 h.beat=14;assert(e.advance(h,m).tempo==140);
 e.request(2,false,false,h,m);h.beat=30;assert(e.advance(h,m).tempo==0); // absent memory cancels
 assert(m.bpm[0]==135 && m.bpm[1]==140 && m.globalMode==2);
 ProgramEngine bar;HostPosition held{true,false,0,0,4,128};bar.request(0,false,false,held,m);
 h={true,true,4,4,4,128};bar.advance(h,m);bar.request(3,true,false,h,m);
 assert(bar.advance(h,m).activated<0);h.beat=7.99;assert(bar.advance(h,m).activated<0);
 h.beat=8;assert(bar.advance(h,m).activated==3);
 // Full rising/falling ramps: at most one CC per integer BPM, exact endpoint.
 for(int mode:{1,2})for(bool rising:{false,true}){
  ProgramMemory memory;memory.globalMode=mode;memory.bpm[0]=rising?170:50;
  HostPosition host{true,true,0,0,4,rising?50.:170.};
  ProgramEngine engine;engine.request(0,false,false,host,memory);
  double last=0;int count=0,previous=-1;
  for(int step=0;step<=4000;++step){
   host.beat=step*(mode==1?32.:2.)/4000;
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
 std::cout<<"R10 V08 modes, interruption, strict next BAR PASS\n";
}
