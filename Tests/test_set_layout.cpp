#include "../Beat4AU/Beat4Layout.hpp"
#include <cassert>
#include <cmath>
int main(){
 for(auto size:{beat4::Rect{0,0,720,400},beat4::Rect{0,0,667,375},beat4::Rect{0,0,1024,768},beat4::Rect{0,0,2160,1200},beat4::Rect{0,0,390,844}}){
  auto l=beat4::layoutFor(size.w,size.h);
  for(int i=0;i<8;++i){auto p=beat4::setPad(l,i);
   assert(p.h>=l.hostSize && p.y>=l.host.y && p.y+p.h<=l.host.y+l.host.h);
   assert(p.x>=l.viewTitle.x+l.viewTitle.w && p.x+p.w<=size.w);
   if(i)assert(p.x>=beat4::setPad(l,i-1).x+beat4::setPad(l,i-1).w);
  }
  assert(std::abs((l.save.y+l.save.h/2)-(l.pcMode.y+l.pcMode.h/2))<.01);
  if(!l.portrait)assert(std::abs(l.toggle.y+l.toggle.h/2-(l.song.y+l.song.h/2))<.01);
 }
}
