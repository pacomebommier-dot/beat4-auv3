#include <cassert>
#include "../Beat4AU/Beat4Set.hpp"
int main(){
 using namespace beat4;
 assert(tempoPitchBend14(20)==0&&tempoPitchBend14(240)==16383&&tempoPitchBend14(241)<0);
 SetEngine set;set.assign(9,1);assert(set.first()==9);
 ProgramMemory m;m.bpm[1]=240;m.rampBars[1]=4;
 HostPosition h{true,true,0,0,4,120};
 auto a=set.program.request(1,true,false,h,m);assert(a.tempo==0);
 h.beat=4;a=set.program.advance(h,m);assert(a.activated==1&&a.tempo==120);
 h.beat=5;a=set.program.advance(h,m);assert(a.tempo>120&&a.tempo<127.5);
 h.beat=19;a=set.program.advance(h,m);assert(a.tempo>239&&a.tempo<240);
 h.beat=20;assert(set.program.advance(h,m).tempo==240);
 m.rampBars[2]=0;m.bpm[2]=180;h.beat=21;set.program.request(2,true,false,h,m);
 h.beat=24;a=set.program.advance(h,m);assert(a.activated==2&&a.tempo==180);
}
