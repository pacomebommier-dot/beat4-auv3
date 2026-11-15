#include "../Beat4AU/Beat4Program.hpp"
#include <cassert>
#include <iostream>
int main(){
 using namespace beat4;ProgramEngine e;ProgramMemory m;
 HostPosition h{true,false,0,0,4,128};e.request(0,false,false,h,m);
 h.moving=true;h.beat=1;e.advance(h,m);e.request(1,false,true,h,m);
 h.beat=4;h.barStart=4;auto a=e.advance(h,m);
 assert(a.activated==1&&!a.sendPC&&e.estimated&&e.selected<0);
 a=e.request(1,false,false,h,m);assert(!a.sendPC&&!e.estimated);
 h.beat=9;e.request(2,false,true,h,m);e.request(3,false,true,h,m);
 h.beat=16;h.barStart=16;a=e.advance(h,m);assert(a.activated==3&&!a.sendPC);
 e.request(4,false,true,h,m);h.beat=20;h.barStart=20;assert(e.advance(h,m).activated==4);
 h.beat=25;e.request(5,false,true,h,m);h.moving=false;e.advance(h,m);
 h.moving=true;h.beat=28;h.barStart=28;assert(e.advance(h,m).activated<0&&e.selected<0);
 m.queue[4]=8;h.beat=29;e.request(6,false,true,h,m);h.beat=36;h.barStart=36;
 assert(e.advance(h,m).activated==6&&!e.uncertain);
 std::cout<<"Circuit queued PC destination default and legacy recovery PASS\n";
}
