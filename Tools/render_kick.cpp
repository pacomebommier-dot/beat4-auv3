// Portable demonstration of the exact Beat4Kick voice and host-beat gate.
// Usage: c++ -std=c++17 -O2 Tools/render_kick.cpp -o /tmp/render_beat4 && /tmp/render_beat4 output.wav
#include "../Beat4AU/Beat4Kick.hpp"
#include "../Beat4AU/Beat4BeatGate.hpp"
#include "../Beat4AU/Beat4Songs.hpp"
#include <fstream>
#include <cmath>
#include <algorithm>
#include <cstdint>
#include <iostream>
static void write16(std::ofstream &f,uint16_t v){ char b[]={char(v&255),char(v>>8)};f.write(b,2); }
static void write32(std::ofstream &f,uint32_t v){write16(f,v&65535);write16(f,v>>16);}
int main(int argc,char**argv){
 if(argc!=2){std::cerr<<"output path required\n";return 1;}
 constexpr int sampleRate=48000;
 constexpr double tempo=128.0;
 constexpr int frames=256;
 const int n=4*sampleRate*60/tempo + sampleRate/2;
 std::ofstream f(argv[1],std::ios::binary);
 if(!f){std::cerr<<"file open failed\n";return 2;}
 f.write("RIFF",4);write32(f,36+n*4);f.write("WAVEfmt ",8);write32(f,16);
 write16(f,1);write16(f,2);write32(f,sampleRate);write32(f,sampleRate*4);write16(f,4);write16(f,16);
 f.write("data",4);write32(f,n*4);
 beat4::BeatGate clock;
 beat4::KickVoice voice;
 double peak=0;
 int triggers=0;
 for(int offset=0;offset<n;offset+=frames){
   const int count=std::min(frames,n-offset);
   const double beat=offset*tempo/(60*sampleRate);
   clock.prepare(beat,tempo,sampleRate,count,true);
   for(int i=0;i<count;++i){
      if(clock.atSample(i) && offset+i < 4*sampleRate*60/tempo){voice.trigger();++triggers;}
      const double v=voice.process(sampleRate,beat4::subFrequency(5))*0.80;
      peak=std::max(peak,std::abs(v));
      const int16_t v16=static_cast<int16_t>(std::round(std::clamp(v,-1.0,1.0)*32767.0));
      write16(f,static_cast<uint16_t>(v16));write16(f,static_cast<uint16_t>(v16));
   }
 }
 std::cout<<"BEAT4 kick preview (F1, 128 BPM, 4 beats): "<<triggers<<" attacks; peak "<<peak<<"\n";
 return triggers==4 && peak<0.95 ? 0:3;
}
