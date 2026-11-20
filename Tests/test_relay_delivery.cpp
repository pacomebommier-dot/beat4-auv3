#include "../Beat4AU/Beat4Relay.hpp"
#include <cassert>
#include <cstdio>
int main(){using namespace beat4;
 HostPosition h{true,true,4,4,4,120};RelayClock clock;clock.start(0,0,true);
 const auto packet=clock.transition(1,4,{true,5,2},h);
 RelayDelivery delivery;delivery.offer(packet);int calls=0;
 const auto first=relayMessage(packet);
 delivery.flush(h,.005,[&](const RelayPacket& p){++calls;assert(p.serial==packet.serial&&p.settings.bars==5&&p.previous==0);return false;});
 assert(delivery.pending()&&calls==1);
 delivery.flush(h,.005,[&](const RelayPacket& p){++calls;auto retry=relayMessage(p);assert(retry.bytes==first.bytes);return true;});
 assert(!delivery.pending()&&calls==2);
 delivery.offer(packet);for(int n=0;n<3;++n)delivery.flush(h,.005,[](const RelayPacket& p){assert(p.kind==2);return false;});
 assert(delivery.pending());
 delivery.flush(h,.005,[](const RelayPacket& p){assert(p.kind==3&&!p.settings.enabled);return true;});assert(!delivery.pending());
 delivery.offer(packet);delivery.flush(h,.2,[](const RelayPacket& p){assert(p.kind==3);return true;});
 delivery.offer(packet);h.moving=false;delivery.flush(h,.005,[](const RelayPacket& p){assert(p.kind==3);return true;});
 h.moving=true;delivery.offer(packet);delivery.offer(packet);delivery.flush(h,.005,[](const RelayPacket& p){assert(p.kind==3);return true;});
 delivery.offer(packet);for(int n=0;n<6;++n)delivery.flush(h,.005,[](const RelayPacket&){return false;});assert(!delivery.pending()&&delivery.dropped==1);
 assert(std::abs(relayEventBeat(4,120,48000,64,128)-(4+64./24000))<1e-10);
 assert(relayEventBeat(4,120,48000,-1,128)==4);
 assert(relayEventBeat(4,120,48000,128,128)==4);
 delivery.offer(packet);delivery.flush(h,.005,[](const RelayPacket&){return false;});h.beat=1;h.barStart=0;
 delivery.flush(h,.005,[](const RelayPacket& p){assert(p.kind==3);return true;});
 auto bad=relayMessage(packet);bad.bytes[15]=25;assert(decodeRelayMessage(bad).kind==0);
 bad=relayMessage(packet);bad.bytes[25]=127;assert(decodeRelayMessage(bad).kind==0);
 puts("RELAY delivery: retained payload/id, bounded retries, STOP/expiry/supersession fallback, drop bound and MIDI offsets PASS");
}
