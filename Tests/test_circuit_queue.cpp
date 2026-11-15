#include "../Beat4AU/Beat4Program.hpp"
#include <cassert>
#include <iostream>
int main(){
 using namespace beat4;
 ProgramEngine e;ProgramMemory m;
 HostPosition h{true,false,0,0,4,128};
 e.request(0,false,false,h,m);
 h.moving=true;e.advance(h,m);
 h.beat=1;
 auto a=e.request(1,false,true,h,m);
 assert(a.activated<0 && e.active==0 && e.selected==1);
 h.beat=3.99;assert(e.advance(h,m).activated<0);
 h.beat=4;h.barStart=4;a=e.advance(h,m);
 assert(a.activated==1 && !a.sendPC && e.active==1 && e.selected<0);
 assert(e.estimated); // AUM boundary estimate, not a hardware acknowledgement
 // An immediate confirmation from Circuit clears that estimate, without echo.
 a=e.request(1,false,false,h,m);assert(!a.sendPC && !e.estimated);
 // Two requests before the boundary: only the latest is activated.
 h.beat=5;e.request(2,false,true,h,m);e.request(3,false,true,h,m);
 h.beat=8;h.barStart=8;a=e.advance(h,m);
 assert(a.activated==3 && !a.sendPC && e.selected<0);
 // At an exact bar, a fresh queued request waits for a future boundary.
 e.request(4,false,true,h,m);assert(e.advance(h,m).activated<0);
 h.beat=12;h.barStart=12;assert(e.advance(h,m).activated==4);
 // STOP clears a pending queued request; it cannot reappear on restart.
 h.beat=13;e.request(5,false,true,h,m);h.moving=false;e.advance(h,m);
 h.moving=true;h.beat=16;h.barStart=16;
 assert(e.advance(h,m).activated<0 && e.selected<0 && e.active==4);
 // A custom external cycle retains the documented phase safeguard.
 m.queue[4]=8;h.beat=17;e.request(6,false,true,h,m);h.beat=24;
 assert(e.advance(h,m).activated<0 && e.uncertain);
 std::cout<<"Circuit queued PC default next bar PASS\n";
}
