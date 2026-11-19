#include "../Beat4AU/Beat4Set.hpp"
#include <cassert>
#include <iostream>
using namespace beat4;
int main(){
 ProgramMemory m;HostPosition stop{true,false,0,0,4,128},run{true,true,1,0,4,128};
 SetEngine s;s.assign(0,3);s.assign(5,7);s.on=true;s.pad(0,stop,m);s.pad(5,run,m);
 std::array<int,kSetCount> slots{{-1,9,-1,12,-1,-1,-1,-1,-1,-1}};
 s.configure(slots,true,1,true);
 assert(s.cursor==1&&s.on&&s.program.active==3&&s.program.selected==7);
 assert(s.queuedPosition==-1&&s.activePosition==-1);
 s.advance({true,true,4,4,4,128},m);assert(s.program.active==7&&s.cursor==1);
 s.play({true,true,5,4,4,128},m);assert(s.program.selected==9&&s.queuedPosition==1);
 s.configure(slots,false,3,false);assert(!s.on&&s.cursor==3);
 s.configure(slots,true,6,true);assert(s.cursor==6); // cleared current pad is a legitimate traversal position
 s.configure(slots,true,99,true);assert(s.cursor==1);
 slots.fill(-1);s.configure(slots,true,-1,true);assert(s.cursor==-1&&!s.on&&!s.restartTerminal);
 std::cout<<"SET config: queue preservation, occurrence detachment, sparse cursor and OFF PASS\n";
}
