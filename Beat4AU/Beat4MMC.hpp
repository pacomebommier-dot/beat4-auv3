#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace beat4 {

constexpr int kMMCAttemptLimit = 3;

inline int mmcRetryFrameGap(double sampleRate) noexcept {
    if (!(sampleRate > 0) || !std::isfinite(sampleRate)) return 1;
    return std::max(1,static_cast<int>(std::lround(sampleRate*.050)));
}

inline int mmcCooldownAfterFrames(int remaining,std::uint32_t renderedFrames) noexcept {
    return std::max(0,remaining-static_cast<int>(renderedFrames));
}

inline std::uint64_t mmcPackDelivery(std::uint32_t generation,int command,int attempts,
                                     int cooldown,bool failed) noexcept {
    const auto gen=static_cast<std::uint64_t>(generation&0x7fffffffU)<<32;
    const auto cmd=static_cast<std::uint64_t>(command&0xff);
    const auto tries=static_cast<std::uint64_t>(std::clamp(attempts,0,255))<<8;
    const auto wait=static_cast<std::uint64_t>(std::clamp(cooldown,0,65535))<<16;
    return gen|wait|tries|cmd|(failed?(1ULL<<63):0);
}
inline std::uint32_t mmcDeliveryGeneration(std::uint64_t word) noexcept {
    return static_cast<std::uint32_t>((word>>32)&0x7fffffffU);
}
inline int mmcDeliveryCommand(std::uint64_t word) noexcept {return static_cast<int>(word&0xffU);}
inline int mmcDeliveryAttempts(std::uint64_t word) noexcept {return static_cast<int>((word>>8)&0xffU);}
inline int mmcDeliveryCooldown(std::uint64_t word) noexcept {return static_cast<int>((word>>16)&0xffffU);}
inline bool mmcDeliveryFailed(std::uint64_t word) noexcept {return (word&(1ULL<<63))!=0;}

inline bool mmcGoalReached(int command, bool moving, bool atOrigin) noexcept {
    if (command == 0x02) return moving;                 // PLAY
    if (command == 0x09) return !moving;                // PAUSE
    if (command == 0x01) return !moving && atOrigin;    // STOP + rewind
    if (command == 0x05) return atOrigin;               // REWIND
    return false;
}

inline bool mmcShouldAttempt(int command, bool goalReached, bool midiAvailable,
                             int attempts, int cooldown) noexcept {
    const bool valid = command == 0x01 || command == 0x02 || command == 0x05 || command == 0x09;
    return valid && !goalReached && midiAvailable &&
           attempts >= 0 && attempts < kMMCAttemptLimit && cooldown <= 0;
}

} // namespace beat4
