#include "../Beat4AU/Beat4Program.hpp"
#include <cassert>
#include <iostream>
using namespace beat4;
int main(){
 ProgramEngine e;ProgramMemory m;HostPosition h{true,false,0,0,4,128};
 auto r=e.request(7,false,false,h,m);assert(e.active==7&&r.activated==7&&!r.sendPC);
 h={true,true,1,0,4,128};e.advance(h,m);e.request(39,true,false,h,m);
 h.beat=4;assert(e.advance(h,m).activated<0);
 h.beat=8;r=e.advance(h,m);assert(r.activated==39&&r.sendPC&&e.selected<0);
 h.valid=false;e.request(6,true,false,h,m);assert(e.selected==6&&e.uncertain);
 h.valid=true;h.beat=9;h.barStart=8;e.advance(h,m);h.beat=16;assert(e.advance(h,m).activated==6);
 ProgramEngine order;HostPosition held{true,false,0,0,4,128};order.request(0,false,false,held,m);
 HostPosition boundary{true,true,1,0,4,128};order.advance(boundary,m);order.request(1,true,false,boundary,m);
 boundary.beat=8;boundary.barStart=8;auto actions=order.renderStep(boundary,m,2);
 assert(actions[0].activated<0&&actions[1].activated<0&&order.selected==2&&order.active==0);
 assert(shouldEmitTempo({5,false,140},140));assert(!shouldEmitTempo({-1,false,140},140));
 assert(!shouldEmitTempo({-1,false,128.4},128.1)); // same transmitted integer, no CC flood
 assert(shouldEmitTempo({-1,false,128.5},128.4));
 assert(shouldEmitTempo({-1,false,128.49},128.5)); // descending ramp
 assert(shouldEmitTempo({5,false,128.1},128.4)); // new PC reasserts even the same CC
 assert(!shouldEmitTempo({5,false,240},128)); // outside the AUM mapping: no wrong tempo
 assert(!shouldEmitTempo({-1,false,0},128));
 ProgramEngine same;HostPosition stopped{true,false,0,0,4,128};same.request(7,false,false,stopped,m);
 stopped.moving=true;same.request(8,true,false,stopped,m);same.request(7,true,false,stopped,m);
 assert(same.active==7&&same.selected==-1);
 order.outputFailed(0,2);assert(order.active==0&&order.selected==2&&order.uncertain);
 boundary.beat=100;assert(order.advance(boundary,m).activated<0); // no endless automatic PC retries
 std::cout<<"PC state, host recovery, output failure and tempo dedup PASS\n";
}
