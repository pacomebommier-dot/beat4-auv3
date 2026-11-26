#include "../Beat4AU/Beat4Set.hpp"
#include <cassert>
int main() {
    using Gesture = beat4::XoneSetGesture;
    using Action = Gesture::Action;
    Gesture g;
    assert(g.event(31, true, 0)==Action::None);
    assert(g.event(12, true, 0.1)==Action::None);
    assert(g.event(12, true, 0.2)==Action::None);
    assert(g.event(31, false, 0.3)==Action::None);
    assert(g.event(12, false, 1)==Action::ToggleSet);
    assert(g.event(12, false, 1.1)==Action::None);
    assert(g.event(12, true, 2)==Action::None);
    assert(g.event(12, false, 2.1)==Action::Short);
    assert(g.event(12, true, 3)==Action::None);
    assert(g.event(12, false, 4)==Action::Long);
    beat4::SetEngine s;
    s.slots[2]=6;
    s.cursor=2;
    s.activePosition=2;
    s.queuedPosition=4;
    s.program.active=6;
    s.program.selected=8;
    s.toggleFromXone();
    assert(s.on && s.cursor==2 && s.activePosition==2 && s.queuedPosition==4);
    assert(s.program.active==6 && s.program.selected==8);
    s.toggleFromXone();
    assert(!s.on && s.program.selected==8);
    assert(beat4::redLedNote(false,false)==-1 && beat4::redLedNote(false,true)==-1);
    assert(beat4::redLedNote(true,false)==16 && beat4::redLedNote(true,true)==12);
}
