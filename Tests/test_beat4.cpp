#include "../Beat4AU/Beat4Math.hpp"
#include "../Beat4AU/Beat4Display.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using beat4::project;
int main() {
    // A stopped unchanged interface must not allocate state or redraw.
    auto stopped=beat4::displayDecision(false,false,false);
    assert(!stopped.readSnapshot && !stopped.redraw);
    auto changed=beat4::displayDecision(false,true,false);
    assert(changed.readSnapshot && changed.redraw);
    auto watchdog=beat4::displayDecision(false,false,true);
    assert(watchdog.readSnapshot && !watchdog.redraw);
    auto moving=beat4::displayDecision(true,false,false);
    assert(moving.readSnapshot && moving.redraw);
    // A diagnostic/MMC revision while stopped may require a snapshot, but it
    // must not redraw the static beat bars.
    assert(!beat4::canvasShouldRedraw(false,false,false));
    assert(beat4::canvasShouldRedraw(false,true,false));
    assert(beat4::canvasShouldRedraw(false,false,true));
    assert(beat4::canvasShouldRedraw(true,false,false));

    for (int i=0; i<100; ++i) {
        auto d=project((double)i, 1024, true);
        assert(d.cell == i%4);
        assert(d.bar == i/4+1);
    }
    assert(project(3.999, 4000, true).cell == 3);
    assert(project(4.0, 4000, true).cell == 0);
    assert(project(-0.25, -100, true).cell == 3);
    assert(project(-4.0, -100, true).cell == 0);
    assert(project(0.0, 0, false).stoppedAtOrigin);
    assert(!project(5.5, 100000, false).stoppedAtOrigin);
    assert(project(2.75, 10000, false).fractional > 0.749);
    assert(std::abs(beat4::displayBeat(3.9, 120, true, .05, .01)-3.99) < 1e-6);
    assert(std::abs(beat4::displayBeat(3.9, 120, false, .05, .01)-3.9) < 1e-6);
    assert(beat4::displayBeat(2, 140, true, 100, .01) < 2.11);
    assert(beat4::displayBeat(2, 200, true, 100, .01) < 2.16);
    std::cout << "Beat4 core PASS: sequence, bars, negative beats, stop/hold, bounded prediction\n";
}
