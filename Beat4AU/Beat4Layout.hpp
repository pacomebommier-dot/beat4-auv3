#pragma once
#include <algorithm>
#include <cmath>
namespace beat4 {
struct Rect {double x=0,y=0,w=0,h=0;};
inline Rect hitRect(Rect r,double minimum=44) noexcept {
 const double w=std::max(minimum,r.w),h=std::max(minimum,r.h);
 return {r.x-(w-r.w)/2,r.y-(h-r.h)/2,w,h};
}
inline int nextPage(int page,int direction) noexcept {return (page+direction+3)%3;}
inline Rect programPad(Rect a,int i) noexcept {
 const double gap=4,w=(a.w-7*gap)/8,h=(a.h-3*gap)/4;
 return {a.x+(i%8)*(w+gap),a.y+(i/8)*(h+gap),w,h};
}
struct Layout {
 Rect logo,version,status,host,pg,bars,kick,subLabel,subValue,levelLabel,levelSlider;
 Rect song,bpm,play,pause,stop,queue,modeLabel,modeControl,save,pcMode,toggle;
 bool transportsInHeader=false,portrait=false;
 double scale=1,barWidth=0,barGap=0,corner=0,logoSize=0,versionSize=0,hostSize=0;
 double kickSize=0,subSize=0,noteSize=0,levelSize=0,bpmSize=0,songSize=0,modeSize=0;
};
// Geometry transcribed from the approved R02 SVG (user V2 reference),
// with later R10 states and QUEUE confined to the existing header / PC pages.
inline Layout layoutFor(double W,double H) noexcept {
 Layout l{};if(!std::isfinite(W)||!std::isfinite(H)||W<=0||H<=0)return l;
 const double m=W*.045;
 l.portrait=H>W*1.08;
 l.transportsInHeader=!l.portrait&&(W<800||H<340);
 const bool compact=l.transportsInHeader;
 const double sx=W/(l.portrait?390:compact?667:2160);
 const double sy=H/(l.portrait?844:compact?375:1200);
 const double s=l.portrait?std::min(sx,std::max(.85,sy)):std::min(sx,sy);l.scale=s;
 auto text=[](double x,double baseline,double w,double font){return Rect{x,baseline-font,w,font*1.25};};
 if(l.portrait){
  l.logoSize=33*s;l.versionSize=13*s;l.hostSize=14*s;
  l.logo=text(m,47*sy,175*sx,l.logoSize);l.version=text(m+178*sx,46*sy,65*sx,l.versionSize);
  l.status=text(m,76*sy,W-2*m,13*s);l.host=text(m,111*sy,W-2*m,l.hostSize);
  l.barGap=19*sx;l.barWidth=std::min((W-2*m-3*l.barGap)/4,82*sx);
  l.bars={(W-4*l.barWidth-3*l.barGap)/2,144*sy,4*l.barWidth+3*l.barGap,338*sy};l.corner=16*s*.7;
  l.kickSize=17*s;l.subSize=12*s;l.noteSize=18*s;l.levelSize=13*s;
  l.kick=text(m,529*sy,70*sx,l.kickSize);l.subLabel=text(W*.27,529*sy,38*sx,l.subSize);
  l.subValue=text(W*.39,529*sy,65*sx,l.noteSize);l.levelLabel=text(m,564*sy,70*sx,l.levelSize);
  l.levelSlider={W*.24,557*sy-15*s,W*.69,30*s};
  l.bpmSize=42*s;l.songSize=34*s;l.bpm=text(m,638*sy,W-2*m,l.bpmSize);
  l.toggle={m,659*sy,30*sx,32*sy};l.song=text(m+43*sx,691*sy,W-2*m-43*sx,l.songSize);
  l.modeSize=15*s;l.modeLabel=text(m,750*sy,113*sx,l.modeSize);
  l.modeControl={m+118*sx,727*sy,174*sx,31*sy};l.save=text(m,792*sy,70*sx,16*s);
  l.pcMode=text(m+89*sx,792*sy,W-2*m-89*sx,13*s);
 }else{
  l.logoSize=(compact?26:60)*s;l.versionSize=(compact?11:25)*s;l.hostSize=(compact?12:24)*s;
  l.logo=text(m,(compact?37:100)*sy,(compact?130:265)*sx,l.logoSize);
  l.version=text(m+(compact?133:270)*sx,(compact?36:98)*sy,(compact?60:150)*sx,l.versionSize);
  l.status=text(m,(compact?55:144)*sy,W-2*m,(compact?12:24)*s);
  l.host=text(W*.56,(compact?34:96)*sy,W*.395,l.hostSize);
  l.barWidth=compact?72*sx:W*.103;l.barGap=compact?78*sx:W*.211-l.barWidth;
  const double total=4*l.barWidth+3*l.barGap;
  l.bars={(compact?W*.5:W*.4975)-total/2,(compact?68:179)*sy,total,(compact?177:579)*sy};
  l.corner=compact?std::min(16*s,11*s):std::max(2.,16*s);
  const double bottom=(compact?273:870)*sy;
  l.kickSize=(compact?17:42)*s;l.subSize=(compact?12:27)*s;l.noteSize=(compact?18:41)*s;l.levelSize=(compact?12:28)*s;
  l.kick={m,bottom-l.kickSize,(compact?65:200)*sx,l.kickSize};
  l.subLabel={W*(compact?.156:.159),bottom-l.subSize,(compact?40:95)*sx,l.subSize};
  l.subValue={W*(compact?.225:.208),bottom-l.noteSize,(compact?55:150)*sx,l.noteSize};
  l.levelLabel={W*(compact?.31:.315),bottom-l.levelSize,(compact?65:145)*sx,l.levelSize};
  const double start=W*(compact?.412:.384),end=W*(compact?.934:.936);
  l.levelSlider={start,bottom-(compact?6:14)*s-15*s,end-start,30*s};
  l.bpmSize=(compact?32:86)*s;l.songSize=(compact?34:99)*s;
  l.bpm=text(m,(compact?329:1052)*sy,W*.29,l.bpmSize);
  l.toggle={W*(compact?.338:.318)- (compact?0:15*s),(compact?310:998)*sy,30*s,32*s};
  l.song=text(W*(compact?.385:.365),(compact?332:1060)*sy,W*(compact?.57:.59),l.songSize);
  l.modeSize=(compact?12:22)*s;
  l.modeLabel=text(m,(compact?362:1127)*sy,(compact?103:146)*sx,l.modeSize);
  l.modeControl={m+(compact?105:148)*sx,(compact?347:1107)*sy,(compact?126:156)*sx,(compact?19:28)*sy};
  l.save=text(m+(compact?248:336)*sx,(compact?362:1127)*sy,(compact?50:110)*sx,(compact?12:24)*s);
  l.pcMode=text(m+(compact?305:463)*sx,(compact?362:1127)*sy,W-m-(m+(compact?305:463)*sx),(compact?11:20)*s);
 }
 l.pg=l.status;
 l.queue={m,l.bars.y+l.bars.h+2,W-2*m,std::max(12.,12*s)};
 l.play=l.pause=l.stop=l.toggle;
 return l;
}
}
