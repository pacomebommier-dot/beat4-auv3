#pragma once
#include "Beat4Program.hpp"
#include <cstring>
namespace beat4 {
struct RelaySettings {bool enabled=false;int bars=1,fade=1;};
inline uint32_t packRelaySettings(RelaySettings s) noexcept {
 return (s.enabled?1u:0u)|(uint32_t(std::clamp(s.bars,1,15)-1)<<1)|(uint32_t(std::clamp(s.fade,1,24)-1)<<5);
}
inline RelaySettings unpackRelaySettings(uint32_t n) noexcept {
 return {bool(n&1),std::min(15,1+int((n>>1)&15)),std::min(24,1+int((n>>5)&31))};
}
struct RelayPacket {
 int kind=1,program=-1,previous=-1;uint32_t serial=0;RelaySettings settings;
 bool valid=false,moving=false,phaseKnown=false;
 double beat=0,origin=0,effectiveBeat=0,barLength=4,bpm=0;
};
struct RelayMIDI {std::array<uint8_t,80> bytes{};int length=0;};
inline RelayMIDI relayMessage(const RelayPacket& p) noexcept {
 RelayMIDI m;auto put=[&](uint8_t b){m.bytes[m.length++]=b;};
 for(uint8_t b:{uint8_t(0xf0),uint8_t(0x7d),uint8_t('B'),uint8_t('4'),uint8_t('R'),uint8_t(2)})put(b);
 put(uint8_t(p.kind));for(int i=0;i<4;++i)put((p.serial>>(7*i))&127);
 put(uint8_t(p.program+1));put(uint8_t(p.previous+1));
 put((p.valid?1:0)|(p.moving?2:0)|(p.phaseKnown?4:0)|(p.settings.enabled?8:0));
 put(uint8_t(p.settings.bars));put(uint8_t(p.settings.fade));
 for(double value:{p.beat,p.origin,p.effectiveBeat,p.barLength,p.bpm}){
  if(!std::isfinite(value))value=0;
  uint64_t bits=0;std::memcpy(&bits,&value,8);
  for(int i=0;i<10;++i)put(uint8_t((bits>>(7*i))&127));
 }
 put(0xf7);return m;
}
inline RelayPacket decodeRelayMessage(const RelayMIDI& m) noexcept {
 RelayPacket p;if(m.length!=67||m.bytes[0]!=0xf0||m.bytes[1]!=0x7d||m.bytes[2]!='B'||m.bytes[3]!='4'||m.bytes[4]!='R'||m.bytes[5]!=2||m.bytes[66]!=0xf7){p.kind=0;return p;}
 for(int i=1;i<66;++i)if(m.bytes[i]>127){p.kind=0;return p;}
 int n=6;p.kind=m.bytes[n++];for(int i=0;i<4;++i)p.serial|=uint32_t(m.bytes[n++])<<(7*i);
 p.program=int(m.bytes[n++])-1;p.previous=int(m.bytes[n++])-1;
 const int flags=m.bytes[n++];p.valid=flags&1;p.moving=flags&2;p.phaseKnown=flags&4;
 p.settings.enabled=flags&8;p.settings.bars=m.bytes[n++];p.settings.fade=m.bytes[n++];
 for(double* value:{&p.beat,&p.origin,&p.effectiveBeat,&p.barLength,&p.bpm}){
  if(m.bytes[n+9]>1){p.kind=0;return p;}
  uint64_t bits=0;for(int i=0;i<10;++i)bits|=uint64_t(m.bytes[n++])<<(7*i);
  std::memcpy(value,&bits,8);
 }
 if(p.kind<1||p.kind>3||p.program< -1||p.program>63||p.previous< -1||p.previous>63||flags>15||p.settings.bars<1||p.settings.bars>15||p.settings.fade<1||p.settings.fade>24||
    (p.kind>=2&&(p.program<0||p.previous<0))||(p.kind==3&&p.settings.enabled)||
    !std::isfinite(p.beat)||!std::isfinite(p.origin)||!std::isfinite(p.effectiveBeat)||!std::isfinite(p.barLength)||!std::isfinite(p.bpm)||
    (p.valid&&(p.barLength<=0||p.bpm<=0)))p.kind=0;
 return p;
}
inline double relayEventBeat(double beat,double bpm,double sampleRate,int64_t offset,uint32_t frames) noexcept {
 if(!std::isfinite(beat)||!std::isfinite(bpm)||!std::isfinite(sampleRate)||bpm<=0||sampleRate<=0||offset<0||uint64_t(offset)>=frames)return beat;
 return beat+double(offset)*bpm/(60*sampleRate);
}
// Render-thread owner: fixed storage, at most one output attempt per buffer.
struct RelayDelivery {
 RelayPacket held{};bool occupied=false,haveBeat=false;int attempts=0;double age=0,lastBeat=0;
 uint64_t canceled=0,dropped=0;
 bool pending() const noexcept {return occupied;}
 void offer(const RelayPacket& p) noexcept {
  const bool superseded=occupied;held=p;occupied=true;attempts=0;age=0;
  if(superseded){held.kind=3;held.settings.enabled=false;held.phaseKnown=false;++canceled;}
 }
 template<class Send> void flush(const HostPosition& h,double seconds,Send&& send) noexcept {
  const bool rewind=haveBeat&&h.valid&&h.beat<lastBeat-1e-7;
  haveBeat=h.valid;if(h.valid)lastBeat=h.beat;
  if(!occupied)return;
  age+=std::isfinite(seconds)?std::max(0.,seconds):0;
  if(held.kind==2&&(!h.valid||!h.moving||rewind||age>.1||attempts>=3)){
   held.kind=3;held.settings.enabled=false;held.phaseKnown=false;held.valid=h.valid;held.moving=h.moving;held.beat=h.beat;
   attempts=0;age=0;++canceled;
  }
  ++attempts;
  if(send(held)){occupied=false;return;}
  if(held.kind==3&&attempts>=3){occupied=false;++dropped;}
 }
};
struct RelayClock {
 int active=-1;double origin=0,lastBeat=0;bool phaseKnown=false,wasMoving=false,haveBeat=false;uint32_t serial=0;
 void start(int pc,double at,bool known) noexcept {active=pc;origin=at;phaseKnown=known;}
 void observe(const HostPosition& h) noexcept {
  if(!h.valid||!h.moving){phaseKnown=false;wasMoving=false;haveBeat=false;return;}
  if(!wasMoving||(haveBeat&&h.beat<lastBeat-1e-7)){origin=h.barStart;phaseKnown=active>=0;}
  lastBeat=h.beat;haveBeat=true;wasMoving=true;
 }
 RelayPacket snapshot(RelaySettings s,const HostPosition& h) noexcept {
  RelayPacket p;p.serial=(++serial)&0xfffffff;p.program=active;p.settings=s;
  p.valid=h.valid;p.moving=h.moving;p.phaseKnown=phaseKnown;p.beat=h.beat;p.origin=origin;
  p.effectiveBeat=h.beat;p.barLength=h.barLength;p.bpm=h.bpm;return p;
 }
 RelayPacket transition(int next,double boundary,RelaySettings outgoing,const HostPosition& h) noexcept {
  auto p=snapshot(outgoing,h);p.kind=2;p.previous=active;p.program=next;p.effectiveBeat=boundary;
  start(next,boundary,h.valid&&h.moving);return p;
 }
};
}
