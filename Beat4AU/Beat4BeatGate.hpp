#pragma once
// Sample-accurate quarter-note event gate driven solely by AUv3 host beat position.
// Explicitly keeps state between render buffers: no retrigger at every callback.
#include <cmath>
#include <cstdint>
#include <limits>

namespace beat4 {
class BeatGate {
public:
    void reset() noexcept {
        active_ = false;
        nextFrame_ = -1;
        lastTriggered_ = std::numeric_limits<int64_t>::min();
        previousStart_ = std::numeric_limits<double>::quiet_NaN();
        previousEnd_ = std::numeric_limits<double>::quiet_NaN();
    }

    void prepare(double beat, double bpm, double sampleRate, int frames, bool moving) noexcept {
        active_ = false;
        nextFrame_ = -1;
        if (!moving || !std::isfinite(beat) || !std::isfinite(bpm) ||
            bpm <= 0 || sampleRate <= 0 || frames <= 0 || !std::isfinite(sampleRate)) {
            reset();
            return;
        }
        step_ = bpm / (60.0 * sampleRate);
        if (!(step_ > 0) || step_ >= 1 || std::abs(beat) > 1e10) {
            reset();
            return;
        }
        start_ = beat;
        frames_ = frames;
        // Detect host seek / loop, rather than considering a fresh start as a new beat.
        // A large discontinuity requires no synthetic intermediate ticks.
        if (std::isfinite(previousEnd_) &&
            (beat < previousStart_ - 0.01 ||
             std::abs(beat - previousEnd_) > 0.08)) {
            lastTriggered_ = std::numeric_limits<int64_t>::min();
        }
        previousStart_ = beat;
        previousEnd_ = beat + frames * step_;
        // The half-sample tolerance matches the nearest frame to a beat boundary.
        nextBeat_ = static_cast<int64_t>(std::ceil(start_ - step_ * 0.5));
        findNext();
        active_ = true;
    }

    bool atSample(int frame) noexcept {
        if (!active_ || frame != nextFrame_) return false;
        const int64_t eventBeat = nextBeat_;
        ++nextBeat_;
        findNext();
        if (eventBeat == lastTriggered_) return false;
        lastTriggered_ = eventBeat;
        return true;
    }
private:
    void findNext() noexcept {
        const double exact = (static_cast<double>(nextBeat_) - start_) / step_;
        const double rounded = std::ceil(exact - 0.5);
        if (!std::isfinite(rounded) || rounded >= frames_) {nextFrame_ = -1; return;}
        nextFrame_ = rounded <= 0 ? 0 : static_cast<int>(rounded);
    }
    bool active_ = false;
    double start_ = 0, step_ = 0;
    double previousStart_ = std::numeric_limits<double>::quiet_NaN();
    double previousEnd_ = std::numeric_limits<double>::quiet_NaN();
    int frames_ = 0, nextFrame_ = -1;
    int64_t nextBeat_ = 0;
    int64_t lastTriggered_ = std::numeric_limits<int64_t>::min();
};
} // namespace beat4
