#pragma once
#include <algorithm>
#include <cmath>

namespace beat4 {

constexpr int kBPMMinimum = 20;
constexpr int kBPMMaximum = 240;
constexpr double kBPMPointsPerStep = 4.0;

inline bool usableBPM(double bpm) noexcept {
    return std::isfinite(bpm) && bpm>=kBPMMinimum && bpm<=kBPMMaximum;
}

inline int initialDraggedBPM(double savedBPM,double hostBPM) noexcept {
    const double source=usableBPM(savedBPM)?savedBPM:(usableBPM(hostBPM)?hostBPM:120.0);
    return std::clamp(static_cast<int>(std::lround(source)),kBPMMinimum,kBPMMaximum);
}

inline int draggedBPM(int startingBPM,double horizontalPoints) noexcept {
    const int start=std::clamp(startingBPM,kBPMMinimum,kBPMMaximum);
    if(!std::isfinite(horizontalPoints))return start;
    const int steps=static_cast<int>(horizontalPoints/kBPMPointsPerStep);
    return std::clamp(start+steps,kBPMMinimum,kBPMMaximum);
}

} // namespace beat4
