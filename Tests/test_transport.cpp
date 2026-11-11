#include "../Beat4AU/Beat4Transport.hpp"
#include <cassert>
#include <iostream>
using beat4::HostMemory;
using beat4::HostMode;
using beat4::HostReading;

HostReading frame(bool moving, double beat, double samples, bool changed = false) {
    return {true, true, moving, changed, beat, samples};
}
int main() {
    // Callback availability, return status, and payload validity are separate gates.
    assert(!beat4::validTransportReading(false, false, 0));
    assert(!beat4::validTransportReading(true, false, 0));
    assert(!beat4::validTransportReading(true, true, std::nan("")));
    assert(beat4::validTransportReading(true, true, 0));
    assert(!beat4::validMusicalReading(false, false, 120, 4, 4, 0));
    assert(!beat4::validMusicalReading(true, false, 120, 4, 4, 0));
    assert(!beat4::validMusicalReading(true, true, 0, 4, 4, 0));
    assert(!beat4::validMusicalReading(true, true, std::nan(""), 4, 4, 0));
    assert(!beat4::validMusicalReading(true, true, 120, 3, 4, 0));
    assert(!beat4::validMusicalReading(true, true, 120, 4, 3, 0));
    assert(!beat4::validMusicalReading(true, true, 120, 4, 4, std::nan("")));
    assert(beat4::validMusicalReading(true, true, 120, 4, 4, 1.5));
    assert(beat4::validMMCCommand(0x01));
    assert(beat4::validMMCCommand(0x02));
    assert(beat4::validMMCCommand(0x09));
    assert(!beat4::validMMCCommand(0x03));

    HostMemory h;
    // Initial unloaded/idle host is READY, not a proven STOP.
    assert(h.observe(frame(false, 0, 0)) == HostMode::ReadyAtZero);
    assert(h.observe(frame(true, 0, 0, true)) == HostMode::Play);
    assert(h.observe(frame(true, 7.5, 180000)) == HostMode::Play);
    assert(h.observe(frame(false, 7.5, 180000, true)) == HostMode::PauseLikely);
    assert(h.observe(frame(false, 7.5, 180000)) == HostMode::PauseLikely);
    assert(h.observe(frame(true, 7.5, 180000, true)) == HostMode::Play);
    // Observed rewind after moving: RESET, and must remain stable.
    assert(h.observe(frame(false, 0, 0, true)) == HostMode::Rewound);
    assert(h.observe(frame(false, 0, 0)) == HostMode::Rewound);
    assert(h.observe(frame(true, 0, 0)) == HostMode::Play);
    // At a 4/4 bar boundary the pause is exactly at beat 0 modulo 4,
    // but *not* timeline zero. This is still clearly stationary mid-song.
    assert(h.observe(frame(true, 8, 192000)) == HostMode::Play);
    assert(h.observe(frame(false, 8, 192000, true)) == HostMode::PauseLikely);

    HostMemory zero;
    assert(zero.observe(frame(true, 0, 0)) == HostMode::Play);
    assert(zero.observe(frame(false, 0, 0, true)) == HostMode::HoldUnknown);
    assert(zero.observe(frame(false, 0, 0)) == HostMode::HoldUnknown);

    HostMemory loadedWhileStopped;
    assert(loadedWhileStopped.observe(frame(false, 6, 144000)) == HostMode::HoldUnknown);
    assert(loadedWhileStopped.observe(frame(false, 6, 144000, true)) == HostMode::HoldUnknown);
    assert(loadedWhileStopped.observe(frame(false, 0, 0, true)) == HostMode::Rewound);

    HostMemory noRewind;
    assert(noRewind.observe(frame(true, 9, 216000)) == HostMode::Play);
    // Indistinguishable intent: stop-without-rewind looks like pause.
    assert(noRewind.observe(frame(false, 9, 216000, true)) == HostMode::PauseLikely);

    HostMemory preRoll;
    assert(preRoll.observe(frame(true, -0.25, -6000)) == HostMode::Play);
    assert(preRoll.observe(frame(false, -0.25, -6000)) == HostMode::PauseLikely);
    assert(preRoll.observe(frame(false, 0, 0, true)) == HostMode::Rewound);
    HostReading missing = frame(false, 0, 0);
    missing.musicalValid = false;
    assert(preRoll.observe(missing) == HostMode::Unknown);
    assert(preRoll.observe(frame(false, 0, 0)) == HostMode::ReadyAtZero);

    // A callback that appears after an unavailable interval can immediately
    // provide a usable reading; no permanently cached UNKNOWN state remains.
    HostMemory lateCallback;
    HostReading noHost = frame(false, 0, 0);
    noHost.transportValid = false;
    noHost.musicalValid = false;
    assert(lateCallback.observe(noHost) == HostMode::Unknown);
    assert(lateCallback.observe(frame(true, 1.25, 30000)) == HostMode::Play);

    HostReading nan = frame(false, 0, 0);
    nan.samplePosition = std::nan("");
    assert(preRoll.observe(nan) == HostMode::Unknown);
    std::cout << "Beat4 transport memory PASS: play, pause, resume, rewind, at-zero ambiguity, missing sync\n";
}
