#pragma once

#include "Beat4Journal.hpp"

namespace beat4 {

using IncidentHistory = DiagnosticRing<1024>;
using IncidentAlerts = DiagnosticRing<64>;

enum IncidentEvent { Fader4 = 1, WetPitchBend, InputRebound, OutputRebound, SessionVersion, MixSource, MidiFailure };

struct IncidentMidi {
    int kind;
    int value;
};

inline bool decodeIncident(const uint8_t* bytes, std::size_t size, IncidentMidi& message) noexcept {
    if (size != 9 || bytes[0] != 0xF0 || bytes[1] != 0x7D || bytes[2] != 66 ||
        bytes[3] != 52 || bytes[4] != 1 || bytes[8] != 0xF7 ||
        bytes[6] > 127 || bytes[7] > 127)
        return false;
    const int kind = bytes[5];
    const int value = bytes[6] + 128 * bytes[7];
    if (kind < Fader4 || kind > MixSource ||
        ((kind == Fader4 || kind == InputRebound) && value > 127) || (kind == MixSource && value > 4))
        return false;
    message = {kind, value};
    return true;
}

}
