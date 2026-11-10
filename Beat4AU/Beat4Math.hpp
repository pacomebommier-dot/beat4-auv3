#pragma once

// Pure, portable beat-to-display logic. No UIKit or CoreAudio dependencies.
#include <cmath>
#include <cstdint>

namespace beat4 {

struct Display {
    int cell = 0;              // 0...3; negative beat positions wrap correctly
    double fractional = 0.0;   // 0...1, progress through the current quarter note
    int64_t bar = 1;           // 1-based for 4/4
    bool stoppedAtOrigin = false;
};

inline Display project(double beat, double samplePosition, bool moving) noexcept {
    Display d;
    if (!std::isfinite(beat)) beat = 0;
    const double whole = std::floor(beat);
    const auto b = static_cast<int64_t>(whole);
    d.cell = static_cast<int>((b % 4 + 4) % 4);
    d.fractional = beat - whole;
    d.bar = static_cast<int64_t>(std::floor(beat / 4.0)) + 1;
    d.stoppedAtOrigin = !moving && std::abs(beat) < 0.005 && std::abs(samplePosition) < 1024.0;
    return d;
}

inline double displayBeat(double beatAtCallback, double bpm, bool moving,
                          double elapsedSeconds, double bufferSeconds) noexcept {
    if (!moving || !std::isfinite(beatAtCallback)) return beatAtCallback;
    if (!std::isfinite(bpm) || bpm <= 0) return beatAtCallback;
    // Predict only until one short buffer after the last render callback.
    // Never let an independent clock free-run if AUM stops rendering.
    const double horizon = std::fmax(0.0, std::fmin(0.090, bufferSeconds + 0.035));
    const double dt = std::fmax(0.0, std::fmin(elapsedSeconds, horizon));
    return beatAtCallback + dt * bpm / 60.0;
}

} // namespace beat4
