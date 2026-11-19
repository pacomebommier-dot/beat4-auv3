#include "../Beat4AU/Beat4Set.hpp"
#include <cassert>
#include <iostream>
using namespace beat4;
int main(){
 ProgramMemory m;
 int cases=0;
 for(int mask=0;mask<(1<<kSetCount);++mask)for(int position=-1;position<kSetCount;++position)
 for(bool on:{false,true})for(bool moving:{false,true}){
  HostPosition h{true,moving,1,0,4,128};
  SetEngine s;
  for(int i=0;i<kSetCount;++i)if(mask&(1<<i))s.assign(i,i%3);
  s.on=on&&mask;s.cursor=position;s.reachedPosition=position;s.program.active=12;
  const auto slots=s.slots;const bool enabled=s.on;
  s.reset();
  assert(s.cursor==s.first());assert(s.slots==slots&&s.on==enabled);
  assert(s.program.active==12&&s.program.selected==-1);
  s.reset();assert(s.cursor==s.first()); // idempotent
  if(s.on){auto a=s.play(h,m);assert(moving?s.queuedPosition==s.first():a.activated==slots[s.first()]);}
  ++cases;
 }
 // An already queued SONG still executes, without undoing the reset cursor.
 for(bool on:{false,true}){
  SetEngine s;s.assign(1,3);s.assign(4,7);s.assign(6,9);s.on=on;
  s.pad(4,{true,false,0,0,4,128},m);
  HostPosition h{true,true,1,0,4,128};s.pad(6,h,m);
  auto slots=s.slots;const auto origin=s.origin;
  s.reset();
  assert(s.cursor==1&&s.program.active==7&&s.activePosition==4);
  assert(s.program.selected==9&&s.queuedPosition==6&&s.origin==origin&&s.slots==slots);
  s.advance({true,true,4,4,4,128},m);
  assert(s.program.active==9&&s.activePosition==6&&s.cursor==1);
  if(on){s.play({true,true,5,4,4,128},m);assert(s.program.selected==3&&s.queuedPosition==1);}
 }
 // PLAY explicitly replaces an existing queue with the first filled pad.
 SetEngine s;s.assign(2,3);s.assign(5,7);s.on=true;
 HostPosition h{true,true,1,0,4,128};s.pad(5,h,m);s.reset();s.play(h,m);
 assert(s.cursor==2&&s.program.selected==3&&s.queuedPosition==2);
 // An explicit pad selection after RESET resumes from that occurrence.
 s.reset();s.pad(5,h,m);s.play(h,m);assert(s.queuedPosition==5);
 std::cout<<"SET RESET PASS: "<<cases<<" sparse/on/off/moving/stopped cases, queue preservation and next PLAY\n";
}
