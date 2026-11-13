#pragma once
#include <array>
#include <cmath>
#include <algorithm>
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
class ProgramEngine {
public:
 int active=-1, selected=-1;
 bool uncertain=false;
 ProgramAction request(int pc,bool local,bool queued,const HostPosition& h,const ProgramMemory& m) noexcept {
  if(pc<0 || pc>=64) return {};
  selected=-1; uncertain=false;
  // Immediate incoming PC is evidence of the sender's project change, not a local queue request.
  if(h.valid && (!h.moving || (!local && !queued))) return activate(pc,local,h,m);
  selected=pc; pendingLocal=local;
  if(!h.valid || (!local && queued)){ uncertain=true; return {}; }
  const int q=active>=0?m.queue[active]:0;
  if(q>0){
   if(!phaseKnown){uncertain=true;return {};}
   due=anchor+(std::floor((h.beat-anchor)/q)+1)*q;
  } else due=h.barStart+(std::floor((h.beat-h.barStart)/h.barLength)+1)*h.barLength;
  lastBeat=h.beat; haveBeat=true;
  return {};
 }
 ProgramAction advance(const HostPosition& h,const ProgramMemory& m) noexcept {
  if(!h.valid || !std::isfinite(h.beat) || !std::isfinite(h.bpm) || h.barLength<=0){
   ramp=false; phaseKnown=false; if(selected>=0)uncertain=true; haveBeat=false; return {};
  }
  if(!h.moving){
   selected=-1; uncertain=false; ramp=false; phaseKnown=false; wasMoving=false;
   lastBeat=h.beat; haveBeat=true; return {};
  }
  if(!wasMoving && active>=0 && selected<0){anchor=h.beat;phaseKnown=true;}
  wasMoving=true;
  if(haveBeat && h.beat<lastBeat-1e-7){ramp=false;phaseKnown=false;if(selected>=0)uncertain=true;}
  lastBeat=h.beat;haveBeat=true;
  if(selected>=0 && !uncertain && h.beat>=due) return activate(selected,pendingLocal,h,m);
  ProgramAction a;
  if(ramp){
   const double f=std::clamp((h.beat-rampStart)/rampLength,0.0,1.0);
   a.tempo=startBPM+(targetBPM-startBPM)*f;
   if(f>=1)ramp=false;
  }
  return a;
 }
private:
 bool phaseKnown=false,pendingLocal=false,wasMoving=false,haveBeat=false,ramp=false;
 double anchor=0,due=0,lastBeat=0,rampStart=0,rampLength=0,startBPM=0,targetBPM=0;
 ProgramAction activate(int pc,bool local,const HostPosition& h,const ProgramMemory& m) noexcept {
  active=pc;selected=-1;uncertain=false;anchor=h.beat;phaseKnown=h.valid;wasMoving=h.moving;
  ramp=false;
  ProgramAction a{pc,local,0};
  const double target=m.bpm[pc];
  if(!std::isfinite(target)||target<20||target>240)return a;
  const int mode=m.mode[pc]>=0?m.mode[pc]:m.globalMode;
  if(!h.moving)a.tempo=target;
  else if(mode==1 || mode==2){
   ramp=true;rampStart=h.beat;rampLength=mode==1?8*h.barLength:2;
   startBPM=h.bpm;targetBPM=target;
  }
  return a;
 }
};
}
