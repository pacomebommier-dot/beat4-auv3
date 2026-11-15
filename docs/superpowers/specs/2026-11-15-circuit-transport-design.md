# Circuit transport relay

User-confirmed scope: PC reception and transmission work. Only relay Circuit
Start/Stop through BEAT//4 to AUM; keep local transport and prevent feedback.

Use the existing AUM Control output: FA/FB -> CC110, FC -> CC111, channel 16,
127 press followed by 0 release. AUM remains the musical authority and sends
its clock/transport to Circuit. Do not forward incoming F8 or raw realtime
messages on either output. PC, tempo and UI remain unchanged.

Approaches: an external converter was offered; user chose the integrated relay.
Keep explicit requested state until AUM confirms it. Repeated external commands
matching the requested or observed state do nothing. Host observations never
produce output. Local toggle uses the outstanding requested state when present.
This suppresses same-state echoes, including before host acknowledgement.

MIDI realtime messages do not carry origin IDs: arbitrarily delayed opposite
commands cannot be distinguished from intentional input. No automatic retry or
clock master switch. Physical AUM/Circuit testing is required before claiming
hardware validation.
