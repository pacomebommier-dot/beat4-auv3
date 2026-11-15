#pragma once
#include <array>
#include <cmath>
#include <algorithm>
#include "Beat4Songs.hpp"
namespace beat4 {
struct ProgramMemory {
 std::array<int,64> queue{}, mode{};
 std::array<double,64> bpm{};
 int globalMode=0;
 ProgramMemory(){ mode.fill(-1); }
};
// beat and barStart use AU musical-context quarter-note units.
struct HostPosition { bool valid=false, moving=false; double beat=0, barStart=0, barLength=4, bpm=0; };
struct ProgramAction { int activated=-1; bool sendPC=false; double tempo=0; };
inline bool shouldEmitTempo(ProgramAction a,double last) noexcept {
 const int value=tempoCC7(a.tempo);
 return value>=0 && (a.activated>=0 || value!=tempoCC7(last));
}
class ProgramEngine {
public:
 int active=-1, selected=-1;
 bool uncertain=false,estimated=false;
 void outputFailed(int previous,int requested) noexcept {
  active=previous;selected=requested;uncertain=true;ramp=false;outputBlocked=true;
 }
 std::array<ProgramAction,2> renderStep(const HostPosition& h,const ProgramMemory& m,int local=-1) noexcept {
  ProgramAction a;if(local>=0)a=request(local,true,false,h,m);
  return {a,advance(h,m)};
 }
 ProgramAction request(int pc,bool local,bool queued,const HostPosition& h,const ProgramMemory& m) noexcept {
  if(pc<0 || pc>=64)return {};
  const bool confirmation=!local&&!queued;
  const bool preserveRamp=confirmation&&(pc==selected||pc==active);
  if(pc==active&&(local||queued)){
   selected=-1;uncertain=false;ramp=false;outputBlocked=false;return {};
  }
  selected=-1;uncertain=false;outputBlocked=false;
  pendingLocal=local;
  if(!preserveRamp)ramp=false;
  // PC 0..63 reports hardware activation even if host callbacks are temporarily missing.
  if(confirmation){
   if(valid(h)&&!preserveRamp)beginTempo(pc,h,m);
   return activate(pc,false,h,m);
  }
  if(valid(h)){
   if(!preserveRamp)beginTempo(pc,h,m);
   if(!h.moving||m.mode[pc]==0)return activate(pc,local,h,m);
  }
  selected=pc;
  if(!valid(h)){uncertain=true;return {};}
  schedule(h,m);lastBeat=h.beat;haveBeat=true;
  return {-1,false,tempoAt(h.beat)};
 }
 ProgramAction advance(const HostPosition& h,const ProgramMemory& m) noexcept {
  if(!valid(h)){
   ramp=false;if(selected>=0)uncertain=true;haveBeat=false;return {};
  }
  if(!h.moving){
   selected=-1;uncertain=false;ramp=false;outputBlocked=false;
   lastBeat=h.beat;haveBeat=true;return {};
  }
  if(haveBeat&&h.beat<lastBeat-1e-7){
   ramp=false;if(selected>=0&&!outputBlocked)schedule(h,m);
  }
  lastBeat=h.beat;haveBeat=true;
  if(selected>=0&&uncertain&&!outputBlocked){
   beginTempo(selected,h,m);schedule(h,m);
  }
  if(selected>=0&&!uncertain&&h.beat>=due){
   auto a=activate(selected,pendingLocal,h,m);estimated=true;return a;
  }
  return {-1,false,tempoAt(h.beat)};
 }
private:
 bool pendingLocal=false,haveBeat=false,ramp=false,outputBlocked=false;
 double due=0,lastBeat=0,rampStart=0,rampLength=0,startBPM=0,targetBPM=0;
 static bool valid(const HostPosition& h) noexcept {
  return h.valid&&std::isfinite(h.beat)&&std::isfinite(h.barStart)&&
   std::isfinite(h.barLength)&&h.barLength>0&&std::isfinite(h.bpm)&&h.bpm>0;
 }
 void schedule(const HostPosition& h,const ProgramMemory& m) noexcept {
  const int mode=m.mode[selected];
  const int boundaries=mode==1?4:mode==2?1:mode==0?0:2;
  const double next=h.barStart+(std::floor((h.beat-h.barStart)/h.barLength)+1)*h.barLength;
  due=boundaries==0?h.beat:next+(boundaries-1)*h.barLength;
  uncertain=false;
 }
 void beginTempo(int pc,const HostPosition& h,const ProgramMemory& m) noexcept {
  ramp=false;const double target=m.bpm[pc];
  if(!h.moving||!validBPM(target))return;
  startBPM=h.bpm;targetBPM=target;rampStart=h.beat;
  rampLength=(std::abs(target-startBPM)>10?2:1)*h.barLength;ramp=true;
 }
 double tempoAt(double beat) noexcept {
  if(!ramp)return 0;
  const double f=std::clamp((beat-rampStart)/rampLength,0.0,1.0);
  const double value=startBPM+(targetBPM-startBPM)*f;
  if(f>=1)ramp=false;
  return value;
 }
 ProgramAction activate(int pc,bool local,const HostPosition& h,const ProgramMemory& m) noexcept {
  active=pc;selected=-1;uncertain=false;estimated=local;
  ProgramAction a{pc,local,valid(h)?tempoAt(h.beat):0};
  if(!valid(h)){ramp=false;haveBeat=false;return a;}
  if(!h.moving){ramp=false;if(validBPM(m.bpm[pc]))a.tempo=m.bpm[pc];}
  return a;
 }
};
}
