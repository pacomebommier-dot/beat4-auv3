#pragma once
#include <cmath>
#include <cstdint>
#include <string>
#include <array>
#include <algorithm>

namespace beat4 {
// MIDI PG is stored as its raw Program Change byte, 0..127. No off-by-one
// conversion and no special treatment of queued Circuit Tracks values.
struct Song {
    std::string title = "UNKNOWN";
    double bpm = 0; // 0 = not configured, NEVER send to AUM
    int subNote = -1; // pitch class 0=C ... 11=B; -1 = not configured
};
constexpr int kNumberOfPrograms = 128;
inline bool validProgram(int pg) noexcept {return pg >= 0 && pg < kNumberOfPrograms;}
inline bool validBPM(double bpm) noexcept {return std::isfinite(bpm) && bpm >= 20 && bpm <= 240;}
inline bool validSub(int pitchClass) noexcept {return pitchClass >= 0 && pitchClass < 12;}
inline const char* noteName(int pitchClass) noexcept {
    static constexpr const char* names[] = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
    return validSub(pitchClass) ? names[pitchClass] : "--";
}
inline double subFrequency(int pitchClass) noexcept {
    // MIDI C1 is 24, hence F1 is MIDI 29 -> 43.65 Hz.
    if (!validSub(pitchClass)) return 43.653528929; // neutral sound until song known
    return 440.0 * std::pow(2.0, (24 + pitchClass - 69.0) / 12.0);
}
inline int pitchBend14(double bpm, double minBPM=20, double maxBPM=240) noexcept {
    if (!validBPM(bpm) || !(maxBPM > minBPM) || bpm < minBPM || bpm > maxBPM) return -1;
    const double normalized = std::clamp((bpm - minBPM)/(maxBPM - minBPM), 0.0, 1.0);
    return static_cast<int>(std::lround(normalized * 16383.0));
}
inline bool isCircuitProgramChange(uint8_t status, uint8_t program, int &pg) noexcept {
    if (status != 0xCF || program > 127) return false; // channel 16 only
    pg = static_cast<int>(program);
    return true;
}
}
