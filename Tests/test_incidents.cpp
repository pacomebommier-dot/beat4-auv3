#include "../Beat4AU/Beat4Incidents.hpp"
#include <cassert>

int main() {
    using namespace beat4;
    const uint8_t wet[]{0xF0, 0x7D, 66, 52, 1, 2, 19, 5, 0xF7};
    IncidentMidi message{};
    assert(decodeIncident(wet, sizeof wet, message));
    assert(message.kind == 2 && message.value == 659);
    assert(!decodeIncident(wet, sizeof wet - 1, message));
    const uint8_t invalid[]{0xF0, 0x7D, 66, 52, 1, 1, 19, 5, 0xF7};
    assert(!decodeIncident(invalid, sizeof invalid, message));
    IncidentHistory history;
    history.write(1, 3, 0, 12);
    history.write(2, 456, 0, 12.1);
    assert(history.read().size() == 2);
    for (int i = 0; i < 1100; ++i) history.write(2, i, 0, 13);
    const auto records = history.read();
    assert(records.size() == 1024 && records.back().pc == 1099);
}
