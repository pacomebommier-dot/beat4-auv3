#pragma once
#include "Beat4Layout.hpp"
namespace beat4 {
inline Layout relayLayoutFor(double W,double H) noexcept {
 auto l=layoutFor(W,H);const double m=W*.045;
 auto text=[](double x,double baseline,double w,double f){return Rect{x,baseline-f,w,f*1.25};};
 l.bpmSize=l.portrait?std::min(W*.108,H*.075):std::min(W*.04,H*.085);
 l.songSize=l.portrait?std::min(W*.087,H*.06):std::min(W*.046,H*.09);
 if(!l.portrait){l.bpm=text(m,H*.877,W*.27,l.bpmSize);l.song=text(W*.365,H*.883,W-m-W*.365,l.songSize);l.toggle={W*.318,l.song.y+(l.song.h-32*l.scale)/2,std::max(24.,std::min(40.,W*.035)),32*l.scale};}
 else{l.bpm.h=l.bpmSize*1.25;l.song.h=l.songSize*1.25;}
 const double font=std::clamp(W*.014,12.,22.),setWidth=std::ceil(7*.62*font+12),edit=28,right=W-m;
 const double y=l.song.y+(l.song.h-28)/2;
 l.setToggle={right-setWidth-edit-8,y,setWidth,28};l.setEditor={right-edit,y,edit,28};l.song.w=std::max(0.,l.setToggle.x-12-l.song.x);
 return l;
}
struct RelayControls {Rect queue,steps,ramp,bars,save,relay,loop,fadeLabel,fade;double font=12;};
inline RelayControls relayControlsFor(double W,double H) noexcept {
 const auto l=relayLayoutFor(W,H);RelayControls r;const double m=W*.045,f=std::clamp(W*.0125,12.,18.);
 r.font=f;const double core=20.8*f,extra=15.55*f,gap=1.85*f;const bool wrap=core+gap+extra>W-2*m;
 const double row=1.7*f;double y=l.modeControl.y;
 y=std::min(y,H-8-(wrap?2*row+.8*f:row));
 double x=m;r.queue={x,y,3.65*f,row};x+=4.3*f;r.steps={x,y,5*f,row};x+=6.3*f;
 r.ramp={x,y,3.85*f,row};x+=3.85*f;r.bars={x,y+.1*f,2.7*f,1.5*f};x+=3.55*f;r.save={x,y,2.8*f,row};
 x=wrap?m:x+2.8*f+gap;if(wrap)y+=row+.8*f;
 r.relay={x,y,3.7*f,row};x+=4.55*f;r.loop={x,y+.1*f,2.7*f,1.5*f};x+=3.55*f;
 r.fadeLabel={x,y,3.7*f,row};x+=4.55*f;r.fade={x,y+.1*f,2.7*f,1.5*f};return r;
}
}
