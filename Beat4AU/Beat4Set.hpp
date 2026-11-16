#pragma once
#include "Beat4Program.hpp"
namespace beat4 {
// XONE K2 documented integration: physical channel15 (index14), note12.
// NoteOff and NoteOn velocity0 both terminate the held gesture.
inline bool xonePlayEvent(uint8_t status,uint8_t note,uint8_t velocity,bool& pressed) noexcept {
 if(note!=12 || (status!=0x9E&&status!=0x8E))return false;
 pressed=status==0x9E&&velocity>0;return true;
}
enum class RequestOrigin { None, Set, Page, External, CircuitQueued };
enum class Gesture { None, Short, Long };
// Technical default matches UIKit's existing long-press recognizer (0.5s).
struct PressRelease {
 static constexpr double longSeconds=.5;
 bool down=false;double start=0;
 Gesture event(bool pressed,double seconds) noexcept {
  if(pressed){if(!down){down=true;start=seconds;}return Gesture::None;}
  if(!down)return Gesture::None;
  down=false;return seconds-start>=longSeconds?Gesture::Long:Gesture::Short;
 }
 void cancel() noexcept {down=false;}
};
// Render-thread owner. No secondary queue: ProgramEngine.selected is authoritative.
struct SetEngine {
 ProgramEngine program;
 std::array<int,8> slots{{-1,-1,-1,-1,-1,-1,-1,-1}};
 bool on=false,restartTerminal=false;
 int cursor=-1,activePosition=-1,queuedPosition=-1,reachedPosition=-1;
 RequestOrigin origin=RequestOrigin::None;
 int beforeCursor=-1,beforeActive=-1,beforeQueued=-1,beforeReached=-1;
 RequestOrigin beforeOrigin=RequestOrigin::None;
 int first() const noexcept {for(int i=0;i<8;++i)if(slots[i]>=0)return i;return -1;}
 int last() const noexcept {for(int i=7;i>=0;--i)if(slots[i]>=0)return i;return -1;}
 void assign(int index,int pc) noexcept {
  if(index<0||index>=8||pc< -1||pc>=64)return;
  slots[index]=pc;if(first()<0)on=false;
 }
 void enable(bool value,const HostPosition& h) noexcept {
  if(value&&!on&&cursor<0&&h.moving)
   for(int i=0;i<8;++i)if(slots[i]>=0&&slots[i]==program.active){cursor=i;activePosition=i;reachedPosition=i;break;}
  on=value&&first()>=0;
 }
 ProgramAction request(int pc,RequestOrigin source,int index,const HostPosition& h,const ProgramMemory& m) noexcept {
  if(pc<0||pc>=64)return {};
  origin=source;queuedPosition=source==RequestOrigin::Set?index:-1;
  auto a=program.request(pc,source!=RequestOrigin::CircuitQueued,source==RequestOrigin::CircuitQueued,h,m,source==RequestOrigin::Set);
  executed(a);return a;
 }
 ProgramAction pad(int index,const HostPosition& h,const ProgramMemory& m) noexcept {
  if(index<0||index>=8||slots[index]<0)return {};
  cursor=index;restartTerminal=false;
  return request(slots[index],RequestOrigin::Set,index,h,m);
 }
 ProgramAction play(const HostPosition& h,const ProgramMemory& m) noexcept {
  if(!on||first()<0)return {};
  int base=program.selected>=0&&origin==RequestOrigin::Set?queuedPosition:cursor;
  int next=-1;
  if(base<0 || restartTerminal || (base>=last()&&(base>=8||slots[base]<0)))next=first();
  else {for(int i=base+1;i<8;++i)if(slots[i]>=0){next=i;break;}if(next<0)next=last();}
  restartTerminal=false;
  return request(slots[next],RequestOrigin::Set,next,h,m);
 }
 void executed(ProgramAction a) noexcept {
  if(a.activated<0)return;
  beforeCursor=cursor;beforeActive=activePosition;beforeQueued=queuedPosition;beforeOrigin=origin;beforeReached=reachedPosition;
  activePosition=origin==RequestOrigin::Set?queuedPosition:-1;
  if(activePosition>=0){if(!restartTerminal)cursor=activePosition;reachedPosition=activePosition;}
  queuedPosition=-1;origin=RequestOrigin::None;
 }
 ProgramAction advance(const HostPosition& h,const ProgramMemory& m) noexcept {
  auto a=program.advance(h,m);executed(a);
  if(program.selected<0){queuedPosition=-1;origin=RequestOrigin::None;}
  return a;
 }
 // A Circuit 0..63 PC is a hardware confirmation, not an unexecuted request.
 ProgramAction confirm(int pc,const HostPosition& h,const ProgramMemory& m) noexcept {
  const bool matching=program.selected==pc;
  if(!matching){origin=RequestOrigin::External;queuedPosition=-1;}
  auto a=program.request(pc,false,false,h,m);executed(a);return a;
 }
 void outputFailed(int previous,int requested) noexcept {
  reachedPosition=beforeReached;cursor=beforeCursor;activePosition=beforeActive;queuedPosition=beforeQueued;origin=beforeOrigin;
  program.outputFailed(previous,requested);
 }
 void stop() noexcept {program.cancel();queuedPosition=-1;origin=RequestOrigin::None;}
 // Legacy persisted name: restartTerminal now means restart at the first filled
 // occurrence after any RESET, not just after reaching the terminal pad.
 void reset() noexcept {cursor=first();restartTerminal=cursor>=0;}
};
}
