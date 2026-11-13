#pragma once
#include <algorithm>
#include <cmath>
namespace beat4 {
class AudioGain {
public:
    double next(bool playing,double level,double sr) noexcept {
        if(!(sr>0)||!std::isfinite(sr)){reset();return 0;}
        level=std::isfinite(level)?std::clamp(level,0.,1.):0;
        transport_=approach(transport_,playing?1.:0.,1./(.010*sr));
        level_=approach(level_,level,1./(.020*sr));
        return transport_*level_;
    }
    bool silent()const noexcept {return transport_==0;}
    void reset() noexcept {transport_=level_=0;}
private:
    static double approach(double from,double to,double step) noexcept {
        return from<to?std::min(to,from+step):std::max(to,from-step);
    }
    double transport_=0,level_=0;
};
}
