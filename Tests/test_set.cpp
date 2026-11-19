#include "../Beat4AU/Beat4Set.hpp"
#include <cassert>
#include <iostream>
using namespace beat4;
int main(){
 ProgramMemory m; m.bpm[3]=117;m.rampBars[3]=4; HostPosition h{true,false,0,0,4,128};
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
 assert(s.program.selected==9);s.play(h,m);assert(s.queuedPosition==6);
 h.beat=8;h.barStart=8;s.advance(h,m);assert(s.cursor==6);
 s.play(h,m);assert(s.queuedPosition==-1); // terminal no loop
 h.beat=12;h.barStart=12;s.advance(h,m);s.reset();s.play(h,m);assert(s.queuedPosition==1);
 s.stop();assert(s.program.selected==-1 && s.cursor==1);
 h.beat=16;h.barStart=16;assert(s.advance(h,m).activated<0);
 s.assign(6,-1);s.play(h,m);assert(s.queuedPosition==3); // resumes after reset cursor
 s.pad(3,h,m);s.assign(3,-1);assert(s.cursor==3 && s.program.selected==7);
 s.enable(false,h);assert(s.program.selected==7); // OFF preserves queue
 s.advance({true,true,20,20,4,128},m);assert(s.program.active==7);
 for(int i=0;i<kSetCount;++i){s.assign(i,-1);}assert(!s.on);
 // External recall does not erase the reached terminal for RESET.
 SetEngine resetAfterExternal;resetAfterExternal.assign(0,3);resetAfterExternal.assign(6,7);resetAfterExternal.on=true;
 resetAfterExternal.pad(6,{true,false,0,0,4,128},m);
 resetAfterExternal.request(9,RequestOrigin::External,-1,{true,false,0,0,4,128},m);
 resetAfterExternal.reset();resetAfterExternal.play(h,m);assert(resetAfterExternal.queuedPosition==0);
 // Page selection retains historical cancellation when selecting ACTIVE.
 SetEngine page;page.program.active=3;page.request(6,RequestOrigin::Page,-1,h,m);
 page.request(3,RequestOrigin::Page,-1,h,m);assert(page.program.selected==-1);
 // Failed SET output keeps effective cursor and pending occurrence separate.
 SetEngine failed;failed.assign(0,3);failed.assign(1,7);failed.on=true;
 failed.play({true,false,0,0,4,128},m);
 failed.play(h,m);auto failedAction=failed.advance({true,true,20,20,4,128},m);
 failed.outputFailed(3,failedAction.activated);
 assert(failed.cursor==0&&failed.program.active==3&&failed.program.selected==7&&failed.queuedPosition==1);
 // STOPPED repeated recall must still apply stored tempo.
 ProgramEngine p;p.request(3,true,false,{true,false,0,0,4,128},m);
 assert(p.request(3,true,false,{true,false,0,0,4,128},m).tempo==117);
 bool pressed=false;
 assert(xonePlayEvent(0x9E,12,127,pressed)&&pressed);
 assert(xonePlayEvent(0x9E,12,0,pressed)&&!pressed);
 assert(xonePlayEvent(0x8E,12,64,pressed)&&!pressed);
 assert(!xonePlayEvent(0x9D,12,127,pressed));
 assert(!xonePlayEvent(0xBE,12,127,pressed));
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
