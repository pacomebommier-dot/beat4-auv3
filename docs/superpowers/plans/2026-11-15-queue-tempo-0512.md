# Queue and tempo 0.5.12 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reliable destination-based activation and selection-time tempo ramps, delivered as IPA.
**Architecture:** ProgramEngine schedules AUM bar boundaries and independently tracks the BPM ramp. AU integration preserves transport and MIDI outputs; existing persistence retains pcMode.
**Tech Stack:** C++17, Objective-C++, native AUv3, GitHub Actions Xcode.
**Spec:** docs/superpowers/specs/2026-11-15-queue-tempo-0512.md

## Global Constraints
- Unknown ignores global mode, activates strict next boundary + one full bar.
- Saved 0/1/2 = immediate / fourth boundary / first boundary.
- Tempo starts at selection: <=10 BPM one bar, >10 two bars, may continue past activation.
- Preserve Circuit confirmations, no echo, app state and memory.

## Review Focus
- Incoming queue with legacy custom queue must not hang.
- Confirmation of pending project must preserve running ramp.
- Multiple selections, active cancellation, STOP and backward seek.
- Invalid host then recovery, non-4/4 bars, missing BPM.
- Queue display and native harness assertions reflect new semantics.

### Task 1: engine and regression tests
- [x] Add test_destination_queue.cpp for defaults, saved modes, destinations, ramps, confirmations, interruption and recovery; run and observe old behavior failing.
- [x] Replace ProgramEngine scheduling and tempo lifecycle with independent state; keep public request/advance signatures.
- [x] Update obsolete old assertions to approved new timings; run full portable suite and sanitizers.

### Task 2: integration and delivery
- [x] Update displayed queue semantics and existing native harness assertions; verify persistence SAVE target and legacy compatibility.
- [ ] Bump app/extension/workflow to 0.5.12 build12, build on CI, inspect native harness and package verification.
- [ ] Independent review, correct material findings, retrieve CI IPA and verify hash/package.
- [ ] Create dedicated BEAT Drive folder; upload raw IPA, spec and validation notes, read back metadata.
