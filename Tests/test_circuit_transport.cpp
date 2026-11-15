#include "../Beat4AU/Beat4Songs.hpp"
#include <cassert>
#include <iostream>
int main() {
 using namespace beat4;
 TransportPulse p;
 p.observe(true,false);
 // Single-byte Circuit Start becomes an explicit AUM START, never a toggle.
 p.receive(250);
 auto m=p.next();assert(m.length==3 && m.cable==0 && m.bytes[0]==0xBF && m.bytes[1]==110 && m.bytes[2]==127);
 p.receive(250);assert(p.next().bytes[2]==0);assert(p.next().length==0);
 p.observe(true,true);
 // Host feedback and a repeated/echoed Start must not generate another press.
 p.receive(250);p.receive(248);p.receive(254);assert(p.next().length==0);
 p.receive(252);m=p.next();assert(m.bytes[1]==111 && m.bytes[2]==127);
 p.receive(252);assert(p.next().bytes[2]==0);assert(p.next().length==0);
 p.observe(true,false);p.receive(252);assert(p.next().length==0);
 // Local button continues to toggle, including while acknowledgement is pending.
 p.request(false);assert(p.next().bytes[1]==110);
 p.request(false);assert(p.next().bytes[2]==0);
 m=p.next();assert(m.bytes[1]==111 && m.bytes[2]==127);
 assert(p.next().bytes[2]==0);
 p.observe(true,false);assert(p.next().length==0);
 // Continue is an explicit play; clock/common/channel messages do nothing.
 p.receive(251);assert(p.next().bytes[1]==110);assert(p.next().bytes[2]==0);
 p.observe(true,true);
 for(int status:{248,249,253,254,255,0xCF,0xBF})p.receive(static_cast<uint8_t>(status));
 assert(p.next().length==0);
 // Missing host observations cannot invent a stop or re-arm an echoed command.
 p.receive(252);assert(p.next().bytes[1]==111);assert(p.next().bytes[2]==0);
 p.observe(false,false);p.receive(252);assert(p.next().length==0);
 p.observe(true,false);
 // STOP requested before START is acknowledged must survive the old stopped
 // reading while its press waits behind the START release.
 TransportPulse rapid;
 rapid.observe(true,false);rapid.receive(250);assert(rapid.next().bytes[1]==110);
 rapid.receive(252);rapid.observe(true,false);
 assert(rapid.next().bytes[2]==0);
 rapid.observe(true,false);
 m=rapid.next();assert(m.length==3 && m.bytes[1]==111 && m.bytes[2]==127);
 std::cout<<"Circuit realtime transport and feedback suppression PASS\n";
}
