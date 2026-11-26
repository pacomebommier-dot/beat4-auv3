#pragma once

#include <algorithm>
#include <cmath>

namespace beat4 {
// Beat-domain timing for a preset target. -1 on the wire model means idle.
class PresetTimeline {
public:
    void queue(int pc, double start, double end) noexcept {
        if (pc != target || !waiting) {
            target = pc;
            from = start;
            waiting = true;
        }
        until = end;
    }

    void activate(int pc, double at, double end) noexcept {
        if (!waiting || pc != target)
            from = at;
        target = pc;
        until = end;
        waiting = false;
    }

    void cancelQueue() noexcept {
        if (waiting)
            *this = {};
    }

    void reset() noexcept { *this = {}; }

    int progress(double beat) const noexcept {
        if (target < 0)
            return -1;
        constexpr int last = 16382;
        // Leave the final value to actual activation, even when a scheduled
        // boundary becomes overdue before the host can confirm the change.
        const int ceiling = waiting ? last - 1 : last;
        if (until <= from)
            return waiting ? 0 : last;
        return std::min(ceiling, int(std::round(std::clamp((beat - from) / (until - from), 0., 1.) * last)));
    }

private:
    int target = -1;
    bool waiting = false;
    double from = 0;
    double until = 0;
};
}
