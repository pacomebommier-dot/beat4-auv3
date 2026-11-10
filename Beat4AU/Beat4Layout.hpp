#pragma once
// Portable layout geometry for the same single-page AUv3 view on iPhone/iPad.
#include <algorithm>
#include <cmath>
namespace beat4 {
struct Rect {double x=0,y=0,w=0,h=0;};
struct Layout {
    Rect logo, host, pg, bars, kick, subLabel, subValue, levelLabel, levelSlider;
    Rect song, bpm, play, pause, stop;
    bool transportsInHeader = false;
};
inline Layout layoutFor(double W, double H) noexcept {
    Layout l{};
    if (!std::isfinite(W) || !std::isfinite(H) || W <= 0 || H <= 0) return l;
    const bool narrow = W < 520;
    const bool compact = H < 310;
    const double pad = std::clamp(W*0.044,12.0,38.0);
    const double headerY = compact ? 7.0 : std::max(12.0,H*0.028);
    l.logo = {pad,headerY,narrow?W*.40:W*.30,28};
    l.host = compact ? Rect{W*.48,headerY+6,W*.17,15} : Rect{W*.65,headerY+6,W*.15,18};
    l.transportsInHeader=compact;
    if(compact){
        const double buttonWidth=std::clamp(W*.065,23.0,33.0);
        const double dx=std::clamp(W*.032,8.0,16.0);
        const double x=W-pad-(buttonWidth*3+dx*2);
        l.play={x,headerY,buttonWidth,30};
        l.pause={x+buttonWidth+dx,headerY,buttonWidth,30};
        l.stop={x+(buttonWidth+dx)*2,headerY,buttonWidth,30};
    } else {
        l.pg={W*.84,headerY+6,W*.16-pad,18};
    }
    const double barsY=compact?43.0:std::max(60.0,H*.145);
    const double reserve=compact?97.0:(narrow?150.0:143.0);
    const double barsH=std::max(24.0,std::min(H*.66,H-barsY-reserve));
    const double barSide=std::max(10.0,W*.069);
    l.bars={pad+barSide,barsY,W-2*(pad+barSide),barsH};
    const double toolsY=barsY+barsH+(compact?7:14);
    const double toolsH=compact?25.0:34.0;
    const double kickW = narrow ? 53.0 : 70.0;
    const double noteW = narrow ? 50.0 : 65.0;
    const double gap = narrow ? 8.0 : 13.0;
    const double noteX=pad+kickW+gap+35.0;
    const double levelX=noteX+noteW+gap+42.0;
    l.kick={pad,toolsY,kickW,toolsH};
    l.subLabel={pad+kickW+gap,toolsY+2,34,18};
    l.subValue={noteX,toolsY,noteW,toolsH};
    l.levelLabel={noteX+noteW+gap,toolsY+2,40,18};
    l.levelSlider={levelX,toolsY+3,std::max(20.0,W-pad-levelX),toolsH-6};
    const double footerY=toolsY+(compact?31.0:55.0);
    if(compact){
        l.pg={pad,footerY-14,70,13};
        l.bpm={pad,footerY, W*.35,30};
        l.song={W*.45,footerY,W*.55-pad,30};
    } else if(narrow){
        l.bpm={pad,footerY,W*.40,34};
        l.song={W*.46,footerY,W*.54-pad,34};
        const double ty=footerY+36;
        const double btn=34, step=53;
        l.play={pad,ty,btn,32};
        l.pause={pad+step,ty,btn,32};
        l.stop={pad+2*step,ty,btn,32};
    } else {
        l.bpm={pad,footerY,W*.28,36};
        l.song={W*.34,footerY,W*.39,36};
        const double ty=footerY;
        const double btn=35, step=47;
        const double x=W-pad-3*step;
        l.play={x,ty,btn,36};
        l.pause={x+step,ty,btn,36};
        l.stop={x+2*step,ty,btn,36};
    }
    return l;
}
}
