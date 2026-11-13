#include "../Beat4AU/Beat4Songs.hpp"
#include <cassert>
#include <limits>
#include <iostream>
int main(){
 using namespace beat4;
 auto pc=circuitMessage(39);assert(pc.cable==1 && pc.length==2 && pc.bytes[0]==0xCF && pc.bytes[1]==39);
 auto tempo=tempoMessage(130);assert(tempo.cable==0 && tempo.length==3 && tempo.bytes[0]==0xEE);
 assert((tempo.bytes[1]+128*tempo.bytes[2])==pitchBend14(130));
 assert(circuitMessage(64).length==0 && tempoMessage(0).length==0);
 assert(storedQueue(8)==8 && storedQueue(-1)==0 && storedQueue(65537)==0);
 assert(storedMode(2)==2 && storedMode(3)==-1);
 assert(storedBPM(128.6)==129 && storedBPM(std::numeric_limits<double>::quiet_NaN())==0);
 TransportPulse transport;
 assert(transport.next().length==0);
 transport.request(true);auto stop=transport.next();assert(stop.cable==0 && stop.bytes[0]==0xBF && stop.bytes[1]==111 && stop.bytes[2]==127);
 transport.request(false);auto release=transport.next();assert(release.bytes[1]==111 && release.bytes[2]==0);
 auto play=transport.next();assert(play.bytes[1]==110 && play.bytes[2]==127);
 assert(transport.next().bytes[2]==0 && transport.next().length==0);
 std::cout<<"R10 MIDI bytes/cables and stored memory validation PASS\n";
}
