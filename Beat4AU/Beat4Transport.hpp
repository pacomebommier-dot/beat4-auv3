#pragma once
// Conservative, realtime-safe transport inference from AUv3 host observations.
// No wall clock, MIDI clock, allocations or artificial pulse generation.
#include <cmath>
#include <cstdint>

namespace beat4 {

enum class HostMode : int {
    Unknown = 0,
    Play = 1,
    PauseLikely = 2,
    Rewound = 3,
    ReadyAtZero = 4,
    HoldUnknown = 5
};

struct HostReading {
    bool transportValid = false;
    bool musicalValid = false;
    bool moving = false;
    bool changed = false; // AUHostTransportStateChanged: useful evidence, not a command identity.
    double beat = 0;
    double samplePosition = 0;
};

class HostMemory {
public:
    HostMode observe(const HostReading& r) noexcept {
        if (!r.transportValid || !r.musicalValid ||
            !std::isfinite(r.beat) || !std::isfinite(r.samplePosition)) {
            // A missing host reading must not be converted into an imaginary STOP.
            reset();
            return HostMode::Unknown;
        }

        // Use beat AND sample positions so that host preroll or a non-zero
        // timeline position does not masquerade as a rewind to origin.
        const bool atOrigin = std::abs(r.beat) < 0.005 &&
                              std::abs(r.samplePosition) < 1024.0;
        const bool previousAway = havePrevious_ &&
            (std::abs(previousBeat_) >= 0.05 ||
             std::abs(previousSample_) >= 4096.0);

        HostMode result = HostMode::Unknown;
        if (r.moving) {
            result = HostMode::Play;
            haveSeenPlay_ = true;
        } else if (atOrigin && previousAway) {
            // Direct observation of a return to zero, not a guess based only
            // on the Moving flag. AUM may have used seek/rewind/stop+rewind.
            result = HostMode::Rewound;
        } else if (atOrigin && mode_ == HostMode::Rewound) {
            result = HostMode::Rewound;
        } else if (atOrigin && (previousMoving_ || mode_ == HostMode::HoldUnknown)) {
            // Pausing *on* beat zero is indistinguishable from STOP at zero.
            result = HostMode::HoldUnknown;
        } else if (atOrigin) {
            result = HostMode::ReadyAtZero;
        } else if (previousMoving_ || mode_ == HostMode::PauseLikely || haveSeenPlay_) {
            // Likely pause. A host STOP without rewind is observationally
            // identical: we do not claim that this is an exact Pause event.
            result = HostMode::PauseLikely;
        } else {
            // Plugin was loaded after the host had already stopped at a
            // non-zero beat. Intent cannot be reconstructed from the position.
            result = HostMode::HoldUnknown;
        }

        mode_ = result;
        havePrevious_ = true;
        previousMoving_ = r.moving;
        previousBeat_ = r.beat;
        previousSample_ = r.samplePosition;
        return result;
    }

    void reset() noexcept {
        mode_ = HostMode::Unknown;
        havePrevious_ = false;
        previousMoving_ = false;
        haveSeenPlay_ = false;
        previousBeat_ = 0;
        previousSample_ = 0;
    }

private:
    HostMode mode_ = HostMode::Unknown;
    bool havePrevious_ = false;
    bool previousMoving_ = false;
    bool haveSeenPlay_ = false;
    double previousBeat_ = 0;
    double previousSample_ = 0;
};

} // namespace beat4
