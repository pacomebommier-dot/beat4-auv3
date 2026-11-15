# Circuit transport implementation plan

Goal: implement the integrated relay agreed in the conversation.
Spec: ../specs/2026-11-15-circuit-transport-design.md

- [x] Reproduce missing single-byte transport conversion with a failing portable test.
- [x] Extend TransportPulse with explicit realtime input and host acknowledgement.
- [x] Accept one-byte AU MIDI events before parsing two-byte Program Changes.
- [x] Test duplicates, host feedback, missing host observations, local toggle,
  opposite requests while pending, Continue and ignored clock.
- [x] Extend native AU render harness for one-byte input, CC output and feedback.
- [x] Run full portable suite (15 executables) and packaging regression. ASan/UBSan pass locally with leak detection disabled: LeakSanitizer cannot run under workspace ptrace. CI retains full sanitizers.
- [ ] Compile iOS app/extension and execute native harness through CI.
- [ ] Validate on physical AUM/Circuit (user hardware).
