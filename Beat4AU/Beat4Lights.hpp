#pragma once
#include "Beat4Display.hpp"
#include <array>
namespace beat4 {
class Lights {
public:
    void update(double beat,bool moving,bool synced,bool stop,double dt,double bpm=120.0) noexcept {
        dt=std::isfinite(dt)?std::clamp(dt,0.,1.):0;
        if(synced && std::isfinite(bpm) && bpm>0)lastBPM_=bpm;
        const bool play=moving&&synced&&std::isfinite(beat)&&std::abs(beat)<1e10;
        if(play){
            const auto step=static_cast<long long>(std::floor(beat));
            const int active=static_cast<int>((step%4+4)%4);
            const double fraction=beat-std::floor(beat);
            for(int i=0;i<4;++i)energy_[i]=barBrightness(i,active,fraction);
            active_=active;playing_=true;stopping_=false;elapsed_=0;
            return;
        }
        const bool releaseAll=stop||!synced;
        if(playing_ || (releaseAll&&!stopping_)){
            from_=energy_;elapsed_=0;fadeSeconds_=kLightStopReleaseBeats*60.0/lastBPM_;hold_=releaseAll?-1:active_;
            stopping_=releaseAll;playing_=false;
            dt=0; // preserve the last displayed energy at the transition
        }
        elapsed_=std::min(fadeSeconds_,elapsed_+dt);
        const double x=elapsed_/fadeSeconds_;
        const double factor=1-x*x*(3-2*x);
        for(int i=0;i<4;++i)energy_[i]=i==hold_?from_[i]:from_[i]*factor;
    }
    double energy(int cell)const noexcept {return cell>=0&&cell<4?energy_[cell]:0;}
    bool animating()const noexcept {
        if(playing_)return true;
        for(int i=0;i<4;++i)if(i!=hold_&&energy_[i]>0)return true;
        return false;
    }
private:
    std::array<double,4> energy_{},from_{};
    int active_=0,hold_=-1;
    bool playing_=false,stopping_=false;
    double elapsed_=.05,fadeSeconds_=.05,lastBPM_=120;
};
}
