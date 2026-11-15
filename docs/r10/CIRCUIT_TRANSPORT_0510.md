# BEAT//4 0.5.10 build 10 — Circuit transport relay

Circuit MIDI Start (250/FA), Continue (251/FB) and Stop (252/FC) are accepted as
single-byte AU MIDI events. Previously they were skipped by the minimum-length
check for Program Change. They produce the existing AUM CC110/111 channel-16
press/release commands on AUM Control (cable 0). No MMC. No raw realtime output.

Keep Circuit -> BEAT//4 input (allow System Real-time), AUM Control -> AUM MIDI
Control, and AUM Clock Send -> Circuit. Keep validated CC110 Start play and CC111
Stop/rewind mappings. Circuit Projects remains dedicated to PC. Do not connect
AUM Control to Circuit. Clock RX and TX settings on Circuit remain as tested.

The host's observed state remains authoritative. Repeated commands matching the
observed or outstanding requested state are ignored. Host state changes do not
generate commands. Local transport still toggles, including during a pending
request. Clock F8 and other non-transport realtime messages are ignored.

Hardware recipe (NOT executed by automated tests):
1. AUM stopped: Circuit Play starts AUM and BEAT//4 once, at AUM's BPM.
2. Circuit Stop stops AUM once; no restart or repeated CC presses.
3. Repeat from BEAT//4 and AUM buttons; Circuit follows with no feedback loop.
4. Repeat rapid Play/Stop, Continue, editor closed, save/reload and reallocation.
5. Verify PC in both directions, tempo CC118 and KICK/SUB remain functional.

The relay has no origin identifier and cannot distinguish an arbitrarily delayed
opposite echo from intentional input. Same-state duplicates are suppressed both
before and after host acknowledgement. Confirm physical behaviour in step 3.
No automatic retransmission when AUM does not acknowledge a command.
