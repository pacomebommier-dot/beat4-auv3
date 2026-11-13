#include "../Beat4AU/Beat4Program.hpp"
#include <cassert>
#include <iostream>
using namespace beat4;
int main(){
 ProgramEngine e; ProgramMemory m;
 HostPosition h{true,false,0,0,4,128};
 auto r=e.request(7,false,false,h,m); assert(e.active==7 && r.activated==7 && !r.sendPC);
 h={true,true,1,0,4,128}; e.advance(h,m);
 r=e.request(39,true,false,h,m); assert(e.active==7 && e.selected==39 && r.activated<0);
 h.beat=3; assert(e.advance(h,m).activated<0);
 h.beat=4; r=e.advance(h,m); assert(r.activated==39 && r.sendPC && e.selected<0);
 m.queue[39]=8; m.queue[7]=16;
 h.beat=5; e.request(7,true,false,h,m); h.beat=8; assert(e.advance(h,m).activated<0);
 h.beat=12; assert(e.advance(h,m).activated==7);
 h.beat=13; e.request(1,true,false,h,m); e.request(2,true,false,h,m);
 h.moving=false; assert(e.advance(h,m).activated<0 && e.selected<0 && e.active==7);
 h.moving=true; h.beat=32; assert(e.advance(h,m).activated<0);
 e.request(3,false,true,h,m); h.beat=64; assert(e.advance(h,m).activated<0 && e.uncertain);
 r=e.request(3,false,false,h,m); assert(r.activated==3 && !r.sendPC);
 m.bpm[4]=140; m.mode[4]=2; h.bpm=131; h.beat=65;
 e.request(4,false,false,h,m); h.beat=66; r=e.advance(h,m); assert(r.tempo>135 && r.tempo<136);
 m.globalMode=0; h.beat=67; assert(e.advance(h,m).tempo==140);
 h.moving=false; m.bpm[5]=150; assert(e.request(5,false,false,h,m).tempo==150);
 h.moving=true; m.mode[4]=1; e.request(4,false,false,h,m); h.moving=false;
 assert(e.advance(h,m).tempo==0); h.moving=true; h.beat=100; assert(e.advance(h,m).tempo==0);
 h.valid=false; e.request(6,true,false,h,m); assert(e.selected==6 && e.uncertain);
 h.valid=true; h.beat=104; assert(e.advance(h,m).activated<0);
 ProgramEngine order; HostPosition held{true,false,0,0,4,128};
 order.request(0,false,false,held,m);HostPosition boundary{true,true,1,0,4,128};
 order.advance(boundary,m);order.request(1,true,false,boundary,m);boundary.beat=4;boundary.barStart=4;
 auto actions=order.renderStep(boundary,m,2);assert(actions[0].activated<0 && actions[1].activated<0 && order.selected==2 && order.active==0);
 ProgramEngine drift;ProgramMemory cycles;cycles.queue[0]=8;cycles.queue[1]=8;
 drift.request(0,false,false,held,cycles);boundary.beat=0;boundary.barStart=0;drift.advance(boundary,cycles);
 boundary.beat=7;drift.request(1,true,false,boundary,cycles);boundary.beat=8.1;drift.advance(boundary,cycles);
 boundary.beat=9;drift.request(0,true,false,boundary,cycles);boundary.beat=16;
 assert(drift.advance(boundary,cycles).activated==0);
 assert(shouldEmitTempo({5,false,140},140));assert(!shouldEmitTempo({-1,false,140},140));
 std::cout<<"R10 PC/queue/tempo state machine PASS\n";
}
