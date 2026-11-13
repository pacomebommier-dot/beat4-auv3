#include "../Beat4AU/Beat4Lights.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
int main(){
 for(double bpm:{20.,60.,120.,180.,240.}){
  const double secondsPerBeat=60/bpm;
  assert(std::abs(secondsPerBeat*.02-(1.2/bpm))<1e-12);
  assert(std::abs(secondsPerBeat*.58-(34.8/bpm))<1e-12);
  // Cubic smoothstep, as used by the approved browser prototype.
  for(int i=0;i<=1000;++i){const double f=i/1000.;const double x=std::min(f/.58,1.);const double want=1-x*x*(3-2*x);assert(std::abs(beat4::barBrightness(0,0,f)-want)<1e-12);}
  beat4::Lights stop;stop.update(.1,true,true,false,0,bpm);
  const double energy=stop.energy(0);assert(energy>0);
  stop.update(0,false,true,true,0,bpm);assert(stop.energy(0)==energy);
  stop.update(0,false,true,true,secondsPerBeat*.05,bpm);
  assert(std::abs(stop.energy(0)-energy*.5)<1e-12);
  stop.update(0,false,true,true,secondsPerBeat*.05,bpm);
  assert(stop.energy(0)==0&&!stop.animating());
  stop.update(0,true,true,false,0,bpm);assert(stop.energy(0)==1&&stop.energy(3)==0);
  beat4::Lights pause;pause.update(.1,true,true,false,0,bpm);
  const double held=pause.energy(0);pause.update(.1,false,true,false,0,bpm);
  pause.update(.1,false,true,false,secondsPerBeat,bpm);assert(pause.energy(0)==held);
  // Pause in the following bar's short anticipation: that bar fades in 10%.
  pause.update(.99,true,true,false,0,bpm);const double anticipation=pause.energy(1);assert(anticipation>0);
  pause.update(.99,false,true,false,0,bpm);pause.update(.99,false,true,false,secondsPerBeat*.05,bpm);
  assert(std::abs(pause.energy(1)-anticipation*.5)<1e-12);
  pause.update(.99,false,true,false,secondsPerBeat*.05,bpm);assert(pause.energy(1)==0);
  // Callback loss retains the last valid tempo for the short fade.
  beat4::Lights loss;loss.update(.1,true,true,false,0,bpm);const double saved=loss.energy(0);
  loss.update(.1,false,false,false,0,0);loss.update(.1,false,false,false,secondsPerBeat*.05,NAN);
  assert(std::abs(loss.energy(0)-saved*.5)<1e-12);
  loss.update(.1,false,false,false,secondsPerBeat*.05,0);assert(loss.energy(0)==0);
 }
 std::cout<<"V056 PASS: exact prototype curve, proportional BPM timing, 10% STOP/PAUSE fade, callback loss\n";
}
