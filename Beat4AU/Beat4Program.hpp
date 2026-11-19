#pragma once
#include <array>
#include <cmath>
#include <algorithm>
#include "Beat4Songs.hpp"
namespace beat4 {
struct ProgramMemory {
 std::array<int,64> queue{}, mode{}, steps{}, rampBars{};
 std::array<double,64> bpm{};
 int globalMode=0;
 ProgramMemory(){ mode.fill(-1); steps.fill(16); rampBars.fill(-1); }
};
// beat and barStart use AU musical-context quarter-note units.
struct HostPosition { bool valid=false, moving=false; double beat=0, barStart=0, barLength=4, bpm=0; };
struct ProgramAction { int activated=-1; bool sendPC=false; double tempo=0; };
inline bool shouldEmitTempo(ProgramAction a,double last) noexcept {
 const int value=tempoPitchBend14(a.tempo);
 return value>=0 && (a.activated>=0 || value!=tempoPitchBend14(last));
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
 void cancel() noexcept {selected=-1;uncertain=false;ramp=false;outputBlocked=false;}
 ProgramAction request(int pc,bool local,bool queued,const HostPosition& h,const ProgramMemory& m,bool force=false) noexcept {
  if(pc<0 || pc>=64)return {};
  const bool confirmation=!local&&!queued;
  const bool duplicateConfirmation=confirmation&&pc==active;
  if(pc==active&&(local||queued)&&!force&&h.moving){
   selected=-1;uncertain=false;outputBlocked=false;return {};
  }
  selected=-1;uncertain=false;outputBlocked=false;
  pendingLocal=local;
  // PC 0..63 reports hardware activation even if host callbacks are temporarily missing.
  if(confirmation){
   if(duplicateConfirmation){estimated=false;return {pc,false,0};}
   return activate(pc,false,h,m);
  }
  if(valid(h)){
   ensureCycle(h);
   if(!h.moving)return activate(pc,local,h,m);
  }
  selected=pc;
  if(!valid(h)){uncertain=true;cycleKnown=false;wasMoving=false;return {};}
  schedule(h,m);lastBeat=h.beat;haveBeat=true;
  return {};
 }
 ProgramAction advance(const HostPosition& h,const ProgramMemory& m) noexcept {
  if(!valid(h)){
   ramp=false;if(selected>=0)uncertain=true;haveBeat=false;cycleKnown=false;wasMoving=false;return {};
  }
  if(!h.moving){
   selected=-1;uncertain=false;ramp=false;outputBlocked=false;cycleKnown=false;wasMoving=false;
   lastBeat=h.beat;haveBeat=true;return {};
  }
  ensureCycle(h);
  if(haveBeat&&h.beat<lastBeat-1e-7){
   cycleOrigin=h.barStart;cycleKnown=true;
   ramp=false;if(selected>=0&&!outputBlocked)schedule(h,m);
  }
  lastBeat=h.beat;haveBeat=true;
  if(selected>=0&&uncertain&&!outputBlocked){
   schedule(h,m);
  }
  if(selected>=0&&!uncertain&&h.beat>=due){
   const double boundary=due;
   auto a=activate(selected,pendingLocal,h,m);cycleOrigin=boundary;cycleKnown=true;estimated=true;return a;
  }
  return {-1,false,tempoAt(h.beat)};
 }
 ProgramAction applyTempo(const HostPosition& h,const ProgramMemory& m,int bars) noexcept {
  if(!valid(h)||active<0)return {};
  return {-1,false,beginTempo(h,m.bpm[active],bars)};
 }
 void stopTempo() noexcept {ramp=false;}
private:
 bool pendingLocal=false,haveBeat=false,ramp=false,outputBlocked=false,cycleKnown=false,wasMoving=false;
 double cycleOrigin=0,due=0,lastBeat=0,rampStart=0,rampLength=0,startBPM=0,targetBPM=0;
 static bool valid(const HostPosition& h) noexcept {
  return h.valid&&std::isfinite(h.beat)&&std::isfinite(h.barStart)&&
   std::isfinite(h.barLength)&&h.barLength>0&&std::isfinite(h.bpm)&&h.bpm>0;
 }
 void ensureCycle(const HostPosition& h) noexcept {
  if(h.moving){
   if(!wasMoving||!cycleKnown){cycleOrigin=h.barStart;cycleKnown=true;}
   if(haveBeat&&h.beat<lastBeat-1e-7){cycleOrigin=h.barStart;cycleKnown=true;ramp=false;}
   wasMoving=true;
  } else {wasMoving=false;cycleKnown=false;}
 }
 void schedule(const HostPosition& h,const ProgramMemory& m) noexcept {
  const bool twoBars=active>=0&&m.steps[active]==32;
  if(twoBars){
   const double length=2*h.barLength;
   const double origin=cycleKnown?cycleOrigin:h.barStart;
   due=origin+(std::floor((h.beat-origin)/length)+1)*length;
  } else {
   due=h.barStart+(std::floor((h.beat-h.barStart)/h.barLength)+1)*h.barLength;
  }
  uncertain=false;
 }
 double beginTempo(const HostPosition& h,double target,int bars) noexcept {
  ramp=false;
  if(bars<0||tempoPitchBend14(target)<0)return 0;
  if(!h.moving||bars==0)return target;
  startBPM=h.bpm;targetBPM=target;rampStart=h.beat;
  rampLength=bars*h.barLength;ramp=true;
  return startBPM;
 }
 double tempoAt(double beat) noexcept {
  if(!ramp)return 0;
  const double f=std::clamp((beat-rampStart)/rampLength,0.0,1.0);
  const double eased=f*f*(6-8*f+3*f*f);
  const double value=f>=1?targetBPM:startBPM+(targetBPM-startBPM)*eased;
  if(f>=1)ramp=false;
  return value;
 }
 ProgramAction activate(int pc,bool local,const HostPosition& h,const ProgramMemory& m) noexcept {
  const bool changed=active!=pc;
  active=pc;selected=-1;uncertain=false;estimated=local;
  ProgramAction a{pc,local,valid(h)?beginTempo(h,m.bpm[pc],m.rampBars[pc]):0};
  if(!valid(h)){ramp=false;haveBeat=false;cycleKnown=false;wasMoving=false;return a;}
  if(!h.moving){ramp=false;cycleKnown=false;wasMoving=false;}
  else if(changed||!cycleKnown){cycleOrigin=h.beat;cycleKnown=true;wasMoving=true;}
  return a;
 }
};
}
