#pragma once
#include <algorithm>
#include <cmath>

namespace beat4 {

struct DisplayDecision {
    bool readSnapshot = false;
    bool redraw = false;
};

// The display link may keep ticking so an external AUM PLAY is detected on the
// next frame. At rest, an unchanged frame is reduced to one cheap revision read.
inline DisplayDecision displayDecision(bool moving, bool revisionChanged,
                                       bool watchdogDue) noexcept {
    if (moving || revisionChanged) return {true, true};
    if (watchdogDue) return {true, false};
    return {};
}

// The beat canvas only changes while it is animated, or when its host sync /
// moving state changes. Revisions belonging to diagnostics, MMC, song data,
// or controls must not invalidate the static bars.
inline bool canvasShouldRedraw(bool moving, bool syncChanged,
                               bool movingChanged) noexcept {
    return moving || syncChanged || movingChanged;
}

inline double beatRise(double fraction) noexcept {
    if (!(fraction >= 0.0 && fraction <= 1.0)) return 0.0;
    // A single continuous phosphor rise over the whole quarter note.
    return std::pow(fraction,1.5);
}

// User-selected prototype at 120 BPM: attack 10 ms, release 290 ms.
// These are fractions of a quarter-note, so the shape follows host BPM.
constexpr double kLightAttackBeats = .02;
constexpr double kLightReleaseBeats = .58;
constexpr double kLightStopReleaseBeats = .10;
inline double lightSmooth(double x) noexcept {
    x=std::clamp(x,0.0,1.0);
    return x*x*(3.0-2.0*x);
}
inline double barBrightness(int cell,int active,double fraction) noexcept {
    if(cell<0 || cell>3 || active<0 || active>3 ||
       !(fraction>=0.0 && fraction<=1.0))return 0.0;
    if(cell==active)return 1.0-lightSmooth(fraction/kLightReleaseBeats);
    if(cell==(active+1)%4)
        return lightSmooth((fraction-(1.0-kLightAttackBeats))/kLightAttackBeats);
    return 0.0;
}

inline double beatBarGap(double areaWidth) noexcept {
    if(!std::isfinite(areaWidth) || areaWidth<=0)return 21.0;
    return std::clamp(areaWidth*.096,21.0,64.0);
}

} // namespace beat4
