#include "../Beat4AU/Beat4Program.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace beat4;
static bool near(double a,double b){return std::abs(a-b)<1e-7;}
int main(){
 for(int global=0;global<3;++global){
  ProgramMemory m;m.globalMode=global;m.queue[0]=32;m.queue[1]=64;
  ProgramEngine e;HostPosition h{true,false,0,0,4,128};e.request(0,false,false,h,m);
  h.moving=true;h.beat=1;e.advance(h,m);e.request(1,false,true,h,m);
  h.beat=4;h.barStart=4;assert(e.advance(h,m).activated<0);
  h.beat=8;h.barStart=8;auto a=e.advance(h,m);assert(a.activated==1&&!a.sendPC&&!e.uncertain);
 }
 for(int mode=0;mode<3;++mode){
  ProgramMemory m;m.mode[0]=1;m.mode[1]=mode;
  ProgramEngine e;HostPosition h{true,false,0,0,4,128};e.request(0,false,false,h,m);
  h.moving=true;h.beat=1;e.advance(h,m);auto a=e.request(1,true,false,h,m);
  if(mode==0){assert(a.activated==1&&a.sendPC);continue;}
  double due=mode==1?16:4;h.beat=due-.01;assert(e.advance(h,m).activated<0);
  h.beat=due;a=e.advance(h,m);assert(a.activated==1&&a.sendPC);
 }
 // Large ramp starts while queued and survives the activation, with no jump.
 ProgramMemory m;m.bpm[1]=148;m.mode[1]=2;
 ProgramEngine e;HostPosition h{true,false,0,0,4,128};e.request(0,false,false,h,m);
 h.moving=true;h.beat=1;e.advance(h,m);e.request(1,true,false,h,m);
 h.beat=3;assert(near(e.advance(h,m).tempo,133));
 h.beat=4;auto a=e.advance(h,m);assert(a.activated==1&&near(a.tempo,135.5));
 h.beat=9;assert(near(e.advance(h,m).tempo,148));
 // Immediate confirmation neither restarts a ramp nor echoes a PC.
 ProgramEngine c;h={true,true,1,0,4,128};c.request(1,false,true,h,m);
 h.beat=3;a=c.request(1,false,false,h,m);assert(a.activated==1&&!a.sendPC&&near(a.tempo,133));
 h.beat=5;assert(near(c.advance(h,m).tempo,138));
 // Threshold, immediate mode, falling tempo, and non-4/4 host bars.
 for(double target:{118.,138.,117.,139.}){
  ProgramMemory mm;mm.mode[1]=0;mm.bpm[1]=target;ProgramEngine x;
  h={true,true,1,0,3,128};a=x.request(1,true,false,h,mm);assert(a.activated==1);
  const double duration=std::abs(target-128)>10?6:3;
  h.beat=1+duration/2;assert(near(x.advance(h,mm).tempo,(128+target)/2));
  h.beat=1+duration;assert(near(x.advance(h,mm).tempo,target));
 }
 // Recovery schedules from valid host timeline; new selection supersedes old.
 ProgramEngine recovery;h={false,true,0,0,4,128};recovery.request(1,false,true,h,m);assert(recovery.uncertain);
 h={true,true,1,0,4,128};recovery.advance(h,m);assert(!recovery.uncertain);
 h.beat=4;assert(recovery.advance(h,m).activated==1);
 ProgramEngine latest;h={true,false,0,0,4,128};latest.request(0,false,false,h,m);
 h.moving=true;h.beat=1;latest.request(1,true,false,h,m);latest.request(2,true,false,h,m);
 h.beat=4;assert(latest.advance(h,m).activated<0);h.beat=8;assert(latest.advance(h,m).activated==2);
 // STOP cancels queue and ramp, selecting ACTIVE cancels pending, seek recovers.
 h.beat=9;latest.request(1,true,false,h,m);latest.request(2,true,false,h,m);h.beat=10;
 assert(latest.selected<0&&latest.advance(h,m).tempo==0);
 latest.request(1,true,false,h,m);h.moving=false;latest.advance(h,m);h.moving=true;h.beat=20;
 assert(latest.advance(h,m).activated<0&&latest.selected<0);
 latest.request(1,true,false,h,m);h.beat=1;h.barStart=0;latest.advance(h,m);h.beat=4;
 assert(latest.advance(h,m).activated==1);
 // A real Circuit confirmation remains authoritative even without host callbacks.
 ProgramEngine confirmed;HostPosition missing{false,false,0,0,4,0};
 auto confirmedAction=confirmed.request(7,false,false,missing,m);
 assert(confirmedAction.activated==7&&!confirmedAction.sendPC&&confirmed.active==7&&confirmed.selected<0);
 missing={true,false,0,0,4,128};confirmed.advance(missing,m);assert(confirmed.active==7);
 // Backward seek reschedules pending activation but cancels the old tempo transition.
 ProgramEngine seek;h={true,false,0,0,4,128};seek.request(0,false,false,h,m);
 h={true,true,9,8,4,128};seek.request(1,true,false,h,m);h.beat=10;seek.advance(h,m);
 h.beat=1;h.barStart=0;assert(seek.advance(h,m).tempo==0);
 h.beat=2;assert(seek.advance(h,m).tempo==0);
 // A failed output remains blocked across a seek; never retry a stale PC silently.
 ProgramEngine failure;h={true,false,0,0,4,128};failure.request(0,false,false,h,m);
 h={true,true,9,8,4,128};failure.request(1,true,false,h,m);failure.outputFailed(0,1);
 h.beat=1;h.barStart=0;failure.advance(h,m);h.beat=8;
 assert(failure.advance(h,m).activated<0&&failure.uncertain&&failure.active==0);
 std::cout<<"0.5.12 destination queues, selection ramps, confirmation and recovery PASS\n";
}
