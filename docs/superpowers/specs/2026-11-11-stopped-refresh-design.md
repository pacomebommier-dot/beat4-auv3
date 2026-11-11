# BEAT//4 stopped refresh design

## Intent

When AUM is stopped, keep BEAT//4 responsive while avoiding redraws and text reconstruction for values that have not changed.

## Scope

- Keep the current BPM and Program Change behavior unchanged.
- Keep the audio render callback running because AUM owns that schedule.
- Poll only enough state to detect a host transition or stale render; do not redraw unchanged stopped UI.
- Keep 60 Hz visual updates while transport is moving.
- Stop showing render callback counters and changing beat values in the diagnostic line at rest.
- Make PLAY, PAUSE, and STOP reliable from one physical tap without changing AUM reception settings.
- Replace the two-stage bar lighting with one continuous whole-bar glow and remove the inner rectangle.

## Approach

Use a lightweight atomic UI revision. The display link reads that revision without allocation. While stopped, it returns immediately unless the revision changed or a one-second health check is due. A health check reads state but redraws only when a visible value actually changed. Host callback blocks stop being recopied once all three are present.

Transport buttons use at least a 44-point hit target. MMC commands remain pending until the requested host state is observed, with at most three bounded attempts when AUM has not yet changed state. Callback status is recorded separately from observed transport success.

The active bar uses one smooth monotonic brightness curve across the complete beat. The whole rounded bar receives a soft gradient and halo; the thresholded inner rectangle is removed. At STOP all four bars remain visually still.

## Constraints

- No blocking calls, allocations, disk access, UIKit calls, or dispatches from the audio render callback.
- Button and keyboard events remain independent from visual refresh.
- Existing transport, kick, SONG, BPM, and MIDI behavior remain unchanged.
