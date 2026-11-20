#include "../Beat4AU/Beat4Relay.hpp"
#include <cassert>
#include <cmath>
#include <cstdio>
#include "../Beat4AU/Beat4RelayLayout.hpp"
int main(){
 using namespace beat4;
 for(int bars=1;bars<=15;++bars)for(int fade=1;fade<=24;++fade){
  const auto s=unpackRelaySettings(packRelaySettings({true,bars,fade}));
  assert(s.enabled&&s.bars==bars&&s.fade==fade);
 }
 assert(!unpackRelaySettings(0).enabled);
 assert(unpackRelaySettings(0).bars==1&&unpackRelaySettings(0).fade==1);
 ProgramMemory m;HostPosition h{true,true,0,0,4,120};ProgramEngine engine;
 auto a=engine.request(0,false,false,h,m);assert(a.newCycle&&a.activationBeat==0);
 h.beat=1;engine.request(1,true,false,h,m);h.beat=3.9;assert(engine.advance(h,m).activated<0);
 h.beat=4.01;h.barStart=4;a=engine.advance(h,m);assert(a.newCycle&&a.activated==1&&a.activationBeat==4);
 a=engine.request(1,false,false,h,m);assert(!a.newCycle); // hardware echo cannot restart RELAY
 RelayClock clock;clock.start(0,0,true);auto packet=clock.transition(1,4,{true,5,2},h);
 assert(clock.active==1&&clock.origin==4&&packet.kind==2&&packet.previous==0&&packet.program==1);
 assert(packet.settings.enabled&&packet.settings.bars==5&&packet.settings.fade==2&&packet.origin==0);
 auto midi=relayMessage(packet);assert(midi.length>50&&midi.bytes[0]==0xf0&&midi.bytes[1]==0x7d&&midi.bytes[midi.length-1]==0xf7);
 for(int i=1;i<midi.length-1;++i)assert(midi.bytes[i]<128);
 const auto decoded=decodeRelayMessage(midi);assert(decoded.kind==2&&decoded.previous==0&&decoded.program==1);
 assert(decoded.effectiveBeat==4&&decoded.origin==0&&decoded.settings.bars==5&&decoded.settings.fade==2);
 h.moving=false;clock.observe(h);assert(!clock.phaseKnown);
 h.moving=true;h.beat=8;h.barStart=8;clock.observe(h);assert(clock.phaseKnown&&clock.origin==8);
 h.beat=2;h.barStart=0;clock.observe(h);assert(clock.origin==0);
 for(int width=320;width<=1600;++width)for(double height:{375.,600.,768.,1024.}){
  const auto layout=relayLayoutFor(width,height);const auto row=relayControlsFor(width,height);
  assert(layout.song.w>0&&layout.song.x+layout.song.w<layout.setToggle.x);
  assert(row.fade.x+row.fade.w<=width-width*.045+.1&&row.fade.y+row.fade.h<=height);
 }
 h.moving=false;a=engine.request(2,true,false,h,m);assert(a.newCycle&&a.activated==2&&!h.moving);
 puts("RELAY settings, QUEUE boundary, echo suppression, transport and MIDI roundtrip PASS");
}
