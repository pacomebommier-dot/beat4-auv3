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

    // V0.5.3: the active bar rises for one full beat while the previous bar
    // fades with the exact time-reversed curve over that same beat.
    assert(beat4::beatRise(0.0)==0.0);
    assert(beat4::beatRise(1.0)==1.0);
    assert(beat4::beatRise(.25)<beat4::beatRise(.50));
    assert(beat4::beatRise(.50)<beat4::beatRise(.75));
    for(int step=0;step<=20;++step){
        const double f=step/20.0;
        assert(std::abs(beat4::barBrightness(1,1,f)-beat4::beatRise(f))<1e-12);
        assert(std::abs(beat4::barBrightness(0,1,f)-beat4::beatRise(1.0-f))<1e-12);
        assert(beat4::barBrightness(2,1,f)==0.0);
        assert(beat4::barBrightness(3,1,f)==0.0);
    }
    assert(beat4::barBrightness(0,0,-.01)==0.0);
    assert(beat4::barBrightness(0,0,1.01)==0.0);
    // About 15% more separation than V0.5.2 (41.5 points at width 500).
    assert(std::abs(beat4::beatBarGap(500)-48.0)<1e-12);
    assert(beat4::beatBarGap(100)==21.0);
    assert(beat4::beatBarGap(1000)==64.0);

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
