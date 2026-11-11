# Stopped Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Avoid redrawing unchanged BEAT//4 UI while AUM is stopped, without delaying controls or host transport detection.

**Architecture:** Add a portable refresh decision helper and an atomic UI revision. The display link remains available for immediate host detection but performs only an atomic read on unchanged stopped frames; a one-second watchdog reads health without forcing a redraw.

**Tech Stack:** C++17, Objective-C++, UIKit CADisplayLink, AUv3 atomics.

**Spec:** `docs/superpowers/specs/2026-11-11-stopped-refresh-design.md`

## Global Constraints

- BPM and Program Change behavior are unchanged.
- No non-realtime-safe work enters the audio callback.
- Moving transport remains visually updated at 60 Hz.

## Review Focus

- External PLAY while stopped must be detected on the next display frame.
- A stopped healthy render must not redraw every frame.
- A render that becomes stale while stopped must become visible within one second.
- Missing host callbacks must continue to be discovered.
- Buttons and text entry must remain independent from the redraw gate.

---

### Task 1: Refresh decision contract

**Files:**
- Create: `Beat4AU/Beat4Display.hpp`
- Modify: `Tests/test_beat4.cpp`

**Interfaces:**
- Produces: `beat4::displayDecision(bool moving, bool revisionChanged, bool watchdogDue)` returning read/redraw booleans.

- [ ] Write assertions for moving, changed stopped, unchanged stopped, and watchdog-only cases.
- [ ] Run `bash Tests/run.sh` and verify the missing interface fails compilation.
- [ ] Implement the minimal pure helper.
- [ ] Run `bash Tests/run.sh` and verify all tests pass.

### Task 2: Revision-driven UI

**Files:**
- Modify: `Beat4AU/Beat4AudioUnit.h`
- Modify: `Beat4AU/Beat4AudioUnit.mm`
- Modify: `Beat4AU/Beat4ViewController.mm`

**Interfaces:**
- Consumes: `beat4::displayDecision`.
- Produces: `-displayRevision`, a cheap atomic revision read.

- [ ] Increment the revision only for visible state transitions and UI/MIDI requests.
- [ ] Stop callback block refresh once transport, musical, and MIDI blocks are present.
- [ ] Gate snapshot allocation, label updates, and canvas redraws while stopped.
- [ ] Replace changing diagnostic counters with stable status text.
- [ ] Run the complete portable and sanitizer test suites.

### Task 3: Reliable transport controls

**Files:**
- Create: `Beat4AU/Beat4MMC.hpp`
- Modify: `Beat4AU/Beat4AudioUnit.mm`
- Modify: `Beat4AU/Beat4Layout.hpp`
- Modify: `Beat4AU/Beat4ViewController.mm`
- Modify: `Tests/test_transport.cpp`
- Modify: `Tests/test_layout.cpp`

- [ ] Write failing tests for MMC goal recognition, bounded retry decisions, and 44-point hit rectangles.
- [ ] Keep the MMC request pending until host state confirms PLAY, PAUSE, or STOP; retry at most three times.
- [ ] Record the MIDI callback status instead of treating a call as execution proof.
- [ ] Enlarge transport hit targets without overlap.
- [ ] Run the complete portable and sanitizer test suites.

### Task 4: Continuous bar glow

**Files:**
- Modify: `Beat4AU/Beat4Kick.hpp`
- Modify: `Beat4AU/Beat4ViewController.mm`
- Modify: `Tests/test_songs_kick.cpp`

- [ ] Write a failing test that requires smooth monotonic brightness over the complete beat.
- [ ] Replace the half-beat two-stage envelope with the continuous curve.
- [ ] Remove the thresholded inner rectangle and draw a whole-bar gradient and halo.
- [ ] Run the complete portable and sanitizer test suites.

### Task 5: iOS build evidence

**Files:**
- Modify only version metadata if a new IPA is produced.

- [ ] Run `git diff --check` and inspect the scoped diff.
- [ ] Publish the branch update and wait for GitHub Actions core tests and unsigned iOS build.
- [ ] Report CI evidence separately from the required iPad validation.
