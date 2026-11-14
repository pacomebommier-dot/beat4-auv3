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
// AUM: CC119, channel 15, absolute range 50..177 BPM (one BPM per value).
// The repertoire uses 50..170; 171..177 completes the 128-value MIDI range.
// Keep legacy song storage intact, but never wrap or clamp an unsupported tempo.
inline int tempoCC7(double bpm) noexcept {
    if (!std::isfinite(bpm) || bpm < 50 || bpm > 177) return -1;
    return static_cast<int>(std::lround(bpm)) - 50;
}
inline bool isCircuitProgramChange(uint8_t status, uint8_t program, int &pg) noexcept {
    if (status != 0xCF || program > 127) return false; // channel 16 only
    pg = static_cast<int>(program);
    return true;
}
inline int storedQueue(int value) noexcept {return value>0 && value<=65536?value:0;}
inline int storedMode(int value) noexcept {return value>=0 && value<=2?value:-1;}
inline double storedBPM(double value) noexcept {return validBPM(value)?std::round(value):0;}
struct MIDIMessage { uint8_t cable=0,length=0;std::array<uint8_t,3> bytes{}; };
inline MIDIMessage circuitMessage(int pc) noexcept {
 if(pc<0 || pc>=64)return {};
 return {1,2,{0xCF,static_cast<uint8_t>(pc),0}};
}
inline MIDIMessage tempoMessage(double bpm) noexcept {
 int n=tempoCC7(bpm);if(n<0)return {};
 return {0,3,{0xBE,119,static_cast<uint8_t>(n)}};
}

// Existing V0.5.6 AUM mapping: channel 16, CC110 START / CC111 STOP.
// Preserve each release before another press, as the previous SafetyPulse did.
class TransportPulse {
 int pending=-1,release=-1;
public:
 void request(bool moving) noexcept {pending=moving?111:110;}
 MIDIMessage next() noexcept {
  if(release>=0){const int cc=release;release=-1;return {0,3,{0xBF,static_cast<uint8_t>(cc),0}};}
  if(pending<0)return {};
  const int cc=pending;pending=-1;release=cc;
  return {0,3,{0xBF,static_cast<uint8_t>(cc),127}};
 }
};

}
