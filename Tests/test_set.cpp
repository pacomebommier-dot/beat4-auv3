#include "../Beat4AU/Beat4Set.hpp"
#include <cassert>
#include <iostream>
using namespace beat4;
int main(){
 ProgramMemory m; m.bpm[3]=117; HostPosition h{true,false,0,0,4,128};
 SetEngine s; s.assign(1,3);s.assign(3,7);s.assign(5,3);s.assign(6,9);s.enable(true,h);
 auto a=s.play(h,m);assert(a.activated==3 && a.tempo==117 && s.cursor==1);
 h.moving=true;h.beat=1;s.advance(h,m);
 s.play(h,m);assert(s.program.selected==7 && s.cursor==1 && s.queuedPosition==3);
 s.play(h,m);assert(s.program.selected==3 && s.queuedPosition==5);
 s.request(15,RequestOrigin::External,-1,h,m);assert(s.cursor==1 && s.queuedPosition==-1);
 s.play(h,m);assert(s.program.selected==7 && s.queuedPosition==3);
 h.beat=3.99;assert(s.advance(h,m).activated<0 && s.program.active==3);
 h.beat=4;h.barStart=4;a=s.advance(h,m);assert(a.activated==7 && s.cursor==3);
 s.pad(5,h,m);assert(s.cursor==5 && s.program.active==7);
 s.play(h,m);assert(s.queuedPosition==6);s.play(h,m);assert(s.queuedPosition==6);
 s.reset();assert(s.program.selected==9);s.play(h,m);assert(s.queuedPosition==6);
 h.beat=8;h.barStart=8;s.advance(h,m);assert(s.cursor==6);
 s.play(h,m);assert(s.queuedPosition==6); // terminal no loop
 h.beat=12;h.barStart=12;s.advance(h,m);s.reset();s.play(h,m);assert(s.queuedPosition==1);
 s.stop();assert(s.program.selected==-1 && s.cursor==6);
 h.beat=16;h.barStart=16;assert(s.advance(h,m).activated<0);
 s.assign(6,-1);s.play(h,m);assert(s.queuedPosition==1); // erased terminal
 s.pad(3,h,m);s.assign(3,-1);assert(s.cursor==3 && s.program.selected==7);
 s.enable(false,h);assert(s.program.selected==7); // OFF preserves queue
 s.advance({true,true,20,20,4,128},m);assert(s.program.active==7);
 for(int i=0;i<8;++i){s.assign(i,-1);}assert(!s.on);
 // STOPPED repeated recall must still apply stored tempo.
 ProgramEngine p;p.request(3,true,false,{true,false,0,0,4,128},m);
 assert(p.request(3,true,false,{true,false,0,0,4,128},m).tempo==117);
 PressRelease gesture;
 assert(gesture.event(true,0)==Gesture::None);
 assert(gesture.event(false,.2)==Gesture::Short);
 assert(gesture.event(false,.3)==Gesture::None);
 assert(gesture.event(true,1)==Gesture::None);
 assert(gesture.event(false,1.6)==Gesture::Long);
 assert(gesture.event(true,2)==Gesture::None);gesture.cancel();
 assert(gesture.event(false,3)==Gesture::None);
 std::cout<<"SET cursor, duplicates, queue replacement, terminal/reset, gesture PASS\n";
}
