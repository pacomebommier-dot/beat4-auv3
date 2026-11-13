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

Independent review: 3 important lifecycle/gesture/freshness issues fixed; native tests updated to remove snapshot prerequisite and explicitly address a non-current PC.
Ruling: 44pt guarantee concerns original transport target; exact 8-column R02/R10 grid cannot offer nonoverlapping 44pt squares on every narrow viewport without violating contracted geometry. Keep grid geometry. MODE/slider retain reference geometry; hardware ergonomics still requires device review.
Minor reallocation coverage strengthened: render block acquired before first 48k allocation, retained across 44.1k allocation.
ASan/UBSan local PASS with ASAN_OPTIONS=detect_leaks=0; LeakSanitizer unsupported under this executor ptrace. Full sanitizer CI remains enabled.
