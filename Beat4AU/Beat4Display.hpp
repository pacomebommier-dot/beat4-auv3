#pragma once

namespace beat4 {

struct DisplayDecision {
    bool readSnapshot = false;
    bool redraw = false;
};

// The display link may keep ticking so an external AUM PLAY is detected on the
// next frame. At rest, an unchanged frame is reduced to one cheap revision read.
inline DisplayDecision displayDecision(bool moving, bool revisionChanged,
                                       bool watchdogDue) noexcept {
    if (moving || revisionChanged) return {true, true};
    if (watchdogDue) return {true, false};
    return {};
}

// The beat canvas only changes while it is animated, or when its host sync /
// moving state changes. Revisions belonging to diagnostics, MMC, song data,
// or controls must not invalidate the static bars.
inline bool canvasShouldRedraw(bool moving, bool syncChanged,
                               bool movingChanged) noexcept {
    return moving || syncChanged || movingChanged;
}

} // namespace beat4
