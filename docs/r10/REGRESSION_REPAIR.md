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

R02 exact published gradient stops restored: #d9efc7 → #bbd8ad (50%) → #829e79. Logo #e4e6db.
New geometry assertions pin compact tool typographic edge 273 and slider center267 from approved SVG. Gesture test pins ±36points→±9BPM and fallback120.

Final verification: GitHub Actions run 43519975745, commit b8bc9993bf1f2c9bc77c9943fe09620f741a87f5: SUCCESS. 14 portable executables, full ASan/UBSan, persistence Foundation, iOS app+extension build, 12 UIKit renders and native MIDI/lifecycle harness, IPA verification all PASS.
IPA 0.5.8/build8 SHA256 d9224b147b7632872176de15afdcbd1d4074d2769d4acceabee92b745629f320. Artifact14082952381; screenshots14081694674.
Task5: native execution complete; visual inspection of captures blocked by GitHub Azure download403, as is IPA transfer into Drive. AUM/Circuit hardware remains untested.
Source ZIP upload to Drive rejected by automatic approval review as beyond original IPA authorization; not retried or routed around. Sources remain in authorized GitHub PR3.
Branch retained, PR remains draft; no merge performed.
