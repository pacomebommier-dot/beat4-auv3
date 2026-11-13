# R10 regression repair ledger
Plan: docs/superpowers/plans/2026-11-13-regressions-et-reference-visuelle.md
Base: 688afe3; working branch fix/r10-regression-repair.
Reference: user V2 PNG + R02 alignment notes + R10/V08 later functional requirements.
Ruling: restore general diagnostics via snapshot, not extra UI rows absent from approved composition.
Baseline: 9 portable executables pass.

Tasks 1–4 implemented: R02 compact/desktop/portrait geometry from Drive SVG, V2 phosphor gradient, LED 0.02/0.58/0.10 beat envelope, audio ramps and seams; lifecycle, timestamps, gesture and ACTIVE numbering.
Ruling: new delivery 0.5.8 build8 preserves historical IPA filenames and identities.
Tests: portable suite (13 executables) and IPA verifier unit test PASS; native lifecycle and UIKit assertions added but require CI.
Ruling: Linux cannot execute Objective-C/UIKit; CI will be the native verification gate.
