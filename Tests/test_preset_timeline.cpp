#include "../Beat4AU/Beat4PresetTimeline.hpp"

#include <cassert>

int main() {
    beat4::PresetTimeline timing;
    assert(timing.progress(8) == -1);
    timing.queue(7, 8, 12);
    assert(timing.progress(8) == 0);
    assert(timing.progress(10) == 8191);
    assert(timing.progress(12) == 16381);
    timing.activate(7, 12, 12);
    assert(timing.progress(12) == 16382);

    timing.queue(8, 12, 20);
    assert(timing.progress(16) == 8191);
    timing.queue(9, 16, 24);
    assert(timing.progress(16) == 0);
    timing.queue(9, 17, 24);
    assert(timing.progress(20) == 8191);
    timing.cancelQueue();
    assert(timing.progress(20) == -1);

    timing.queue(10, 20, 32);
    timing.activate(10, 24, 32);
    timing.cancelQueue();
    assert(timing.progress(26) == 8191);
    assert(timing.progress(32) == 16382);
    timing.reset();
    timing.activate(11, 34, 42);
    assert(timing.progress(34) == 0);
    assert(timing.progress(38) == 8191);
}
