#include "../Beat4AU/Beat4Transport.hpp"
#include "../Beat4AU/Beat4MMC.hpp"
#include <cassert>
#include <iostream>
using beat4::HostMemory;
using beat4::HostMode;
using beat4::HostReading;

HostReading frame(bool moving, double beat, double samples, bool changed = false) {
    return {true, true, moving, changed, beat, samples};
}
int main() {
    assert(beat4::mmcGoalReached(0x02,true,false));
    assert(!beat4::mmcGoalReached(0x02,false,true));
    assert(beat4::mmcGoalReached(0x09,false,false));
    assert(!beat4::mmcGoalReached(0x09,true,false));
    assert(beat4::mmcGoalReached(0x01,false,true));
    assert(beat4::mmcGoalReached(0x01,false,false)); // STOP must not require rewind
    assert(beat4::mmcGoalReached(0x05,false,true));
    assert(!beat4::mmcGoalReached(0x05,false,false));
    assert(beat4::mmcShouldAttempt(0x02,false,true,0,0));
    assert(!beat4::mmcShouldAttempt(0x02,true,true,0,0));
    assert(!beat4::mmcShouldAttempt(0x02,false,false,0,0));
    assert(!beat4::mmcShouldAttempt(0x02,false,true,3,0));
    assert(!beat4::mmcShouldAttempt(0x02,false,true,1,2));
    assert(beat4::mmcRetryFrameGap(48000.0)==12000);
    assert(beat4::mmcCooldownAfterFrames(2400,32)==2368);
    assert(beat4::mmcCooldownAfterFrames(2400,4096)==0);
    const auto delivery=beat4::mmcPackDelivery(7,0x02,1,2400,false);
    assert(beat4::mmcDeliveryGeneration(delivery)==7);
    assert(beat4::mmcDeliveryCommand(delivery)==0x02);
    assert(beat4::mmcDeliveryAttempts(delivery)==1);
    assert(beat4::mmcDeliveryCooldown(delivery)==2400);
    assert(!beat4::mmcDeliveryFailed(delivery));
    const auto failed=beat4::mmcPackDelivery(8,0,3,0,true);
    assert(beat4::mmcDeliveryFailed(failed) && beat4::mmcDeliveryCommand(failed)==0);

    // V0.5.3: callback errors fail immediately; only accepted sends may retry.
    const auto requested=beat4::mmcPackDelivery(9,0x02,0,0,false);
    auto decision=beat4::mmcRenderDecision(requested,false,true,512);
    assert(decision.action==beat4::MMCAction::Send);
    const auto rejected=beat4::mmcAfterSend(decision.nextWord,-50,48000.0);
    assert(beat4::mmcDeliveryFailed(rejected));
    assert(beat4::mmcDeliveryCommand(rejected)==0);
    assert(beat4::mmcDeliveryAttempts(rejected)==1);

    const auto accepted1=beat4::mmcAfterSend(decision.nextWord,0,48000.0);
    assert(!beat4::mmcDeliveryFailed(accepted1));
    assert(beat4::mmcDeliveryCommand(accepted1)==0x02);
    assert(beat4::mmcDeliveryAttempts(accepted1)==1);
    assert(beat4::mmcDeliveryCooldown(accepted1)==12000);
    decision=beat4::mmcRenderDecision(accepted1,false,true,512);
    assert(decision.action==beat4::MMCAction::None);
    assert(beat4::mmcDeliveryCooldown(decision.nextWord)==11488);

    decision=beat4::mmcRenderDecision(decision.nextWord,true,true,512);
    assert(decision.action==beat4::MMCAction::Acknowledge);
    assert(beat4::mmcDeliveryCommand(decision.nextWord)==0);

    auto third=beat4::mmcPackDelivery(10,0x01,3,0,false);
    decision=beat4::mmcRenderDecision(third,false,true,512);
    assert(decision.action==beat4::MMCAction::FailNoAck);
    assert(beat4::mmcDeliveryFailed(decision.nextWord));
    assert(beat4::mmcDeliveryCommand(decision.nextWord)==0);

    decision=beat4::mmcRenderDecision(requested,false,false,512);
    assert(decision.action==beat4::MMCAction::None);
    assert(decision.nextWord==requested);
    assert(beat4::hostCallbacksMustRefresh(true,false,false));
    assert(beat4::hostCallbacksMustRefresh(false,true,false));
    assert(beat4::hostCallbacksMustRefresh(false,false,true));
    assert(!beat4::hostCallbacksMustRefresh(false,false,false));

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

    // An accepted STOP may not be repeated when host readback is missing.
    const auto stopSent=beat4::mmcAfterSend(beat4::mmcPackDelivery(11,1,0,0,false),0,48000);
    auto stopWait=beat4::mmcRenderDecision(stopSent,false,true,12000);
    assert(stopWait.action==beat4::MMCAction::FailNoAck);
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
