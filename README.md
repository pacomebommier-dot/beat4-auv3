# BEAT//4 — AUv3 for AUM

Independent iOS AUv3 instrument project, completely separate from XONE.

## Approved brief
- Four large, luminous phosphor-style beat bars, dark LO-FI 1980s design, responsive iPhone / iPad.
- Display follows AUM transport and musical position.
- Current Circuit Tracks Program Change (MIDI channel 16) selects a persistent SONG record: name, target BPM and sub-bass note.
- AUM owns MIDI Clock and sends it to Circuit Tracks. A stored BPM is sent to AUM's MIDI Control by configured pitch bend; no tempo change for an unknown SONG.
- Internal tunable analog-style kick, with constant transient and per-SONG sub note.
- KICK ON/OFF on the main page. Kick Level is a standard AUv3 parameter, touch-adjustable and compatible with native AUM MIDI Learn.
- PLAY/PAUSE/STOP buttons output MMC to AUM MIDI Control when routed.
- No Ableton Link, no extra bridge, no modification to XONE.

## Status
V0.5 source and portable tests have been prepared separately. iOS compilation, direct AUv3 MIDI routing to AUM, MIDI tempo control, and IPA signing are not yet verified. The unsigned IPA produced by Actions is not directly installable.

Source code will be added to this new repository; do not copy it into `xone-auv3-test`.
