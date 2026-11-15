# BEAT//4 0.5.11 build 11 — live Circuit investigation

## Reproduced PC defect

Incoming queued PC (64–127) were unconditionally marked uncertain, preventing
activation even with QUEUE absent and a valid next AUM bar. QUEUE absent now
schedules the future AUM bar, without sending PC back to Circuit. Activation
is labelled estimated until an immediate incoming PC confirms it.

A custom external cycle still requires phase evidence, as in the R10 contract.
This release does not claim to resolve custom-cycle phase uncertainty. The
user's current QUEUE setting has not yet been supplied.

Regression coverage: no early activation, exact future bar, latest request
wins, no PC echo, STOP cancels pending, immediate PC confirms estimate and
custom-cycle safeguard. Native AU harness exercises raw PC103 -> PC40 at bar.

## Long Play/Stop press: cause NOT confirmed

User removed external MIDI monitor. No captured sequence establishes whether
Circuit stops emitting, the host stops rendering, or the relay waits forever
for an unacknowledged command. A press-duration guess is not a diagnosis:
realtime MIDI Start/Stop contains no press-duration information.

Tap the BEAT//4 title to open Diagnostic MIDI after reproducing the problem.
The panel reports received Start/Continue and Stop counts, last realtime byte,
sent CC presses, outstanding target, observed host state, render freshness and
MIDI output status. Counters are collected on the render thread via atomics;
clock ticks are not logged. Journal events 8/9 record incoming realtime and
outgoing transport presses. The UI remains based on actual AUM state.

No transport logic change is claimed to fix the long-press symptom in this
release. Physical validation and analysis of the captured diagnostic remain
required. Build 11 distinguishes this diagnostic/PC fix from build 10.
