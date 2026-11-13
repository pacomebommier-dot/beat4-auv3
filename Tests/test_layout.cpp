#include "../Beat4AU/Beat4Layout.hpp"
#include <cassert>
#include <iostream>
using beat4::Layout;
using beat4::Rect;
static bool inside(Rect r,int w,int h){return r.x>=0 && r.y>=0 && r.w>=0 && r.h>=0 && r.x+r.w<=w+.01 && r.y+r.h<=h+.01;}
int main(){
  assert(beat4::nextPage(2,1)==0 && beat4::nextPage(0,-1)==2);
  for (auto [w,h] : {std::pair{320,200},{390,240},{375,270},{390,844},{430,932},
                    {720,400},{667,375},{700,400},{1024,768},{1194,834}}) {
    Layout l=beat4::layoutFor(w,h);
    for(Rect r : {l.logo,l.bars,l.kick,l.subValue,l.levelSlider,l.bpm,l.song,l.play,l.pause,l.stop}) {
      if (!inside(r,w,h)) {std::cerr<<"Layout overflow "<<w<<"x"<<h<<": "<<r.x<<","<<r.y<<","<<r.w<<","<<r.h<<"\n"; return 1;}
    }
    for(int i=0;i<32;++i){auto p=beat4::programPad(l.bars,i);assert(inside(p,w,h));assert(p.w>0 && p.h>0);}
    assert(l.queue.y+l.queue.h<=l.bpm.y);
    assert(l.toggle.x+l.toggle.w<=w-l.logo.x+.01);
    assert(l.toggle.x>w*.7);
    assert(l.bars.h>=24 && l.bars.w>=100);
    assert(l.bars.y+l.bars.h <= l.kick.y);
    assert(l.kick.y+l.kick.h < l.bpm.y+4);
  }
  std::cout<<"Responsive layout PASS: 10 iPhone/iPad sizes, visible bars and controls\n";
}
