"""Build the V15.18 AUM session from the published V15.17 candidate."""
import hashlib
import plistlib
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
raw = source.read_bytes()
assert hashlib.sha256(raw).hexdigest() == "01978d14906c4401adc21725dcc35483adcc2da5a73b376b6cfa7a245ba7e578"
archive = plistlib.loads(raw)
objects = archive["$objects"]
script = objects[385].decode()

def replace(old, new):
    global script
    assert script.count(old) == 1, old
    script = script.replace(old, new)

replace("@OnLoad\n", """@OnLoad
  incPacket = [125, 66, 52, 1, 0, 0, 0]
  incTick = 0
  incCC = -1
  incDownTick = -100
  incUpTick = -100
  incAlertTick = -100
  incMode = 0
  incLastMode = -1
""")
replace("  if MIDICommand = 176 and MIDIChannel = 14 and MIDIByte2 = 19\n",
        """  if MIDICommand = 176 and MIDIChannel = 14 and MIDIByte2 = 19
    Call @IncidentFader
""")
replace("@OnTimer\n", """@OnTimer
  incTick = incTick + 1
  if incTick % 100 = 1
    incKind = 5
    incValue = 1518
    Call @IncidentSend
  endif
""")
replace("    SendMIDIPitchbend 13, wetOut\n", """    SendMIDIPitchbend 13, wetOut
    Call @IncidentWet
""")
replace("        mix = autoValue[14] / 16383", "        incMode = 2\n        mix = autoValue[14] / 16383")
replace("    sceneMixRamp = morphOutput[14] / 16383", "    incMode = 3\n    sceneMixRamp = morphOutput[14] / 16383")
replace("    mix = yellowFromMix + yellowProgress * (yellowSavedMix - yellowFromMix)", """    incMode = 4
    mix = yellowFromMix + yellowProgress * (yellowSavedMix - yellowFromMix)""")
script += """
@IncidentFader
  if base12Held = 0 and initialized = 1 and MIDIByte3 <> previous
    incMode = 1
  endif
  Call @IncidentSendMode
  incKind = 1
  incValue = MIDIByte3
  Call @IncidentSend
  if incCC >= 0 and base12Held = 0
    if MIDIByte3 < incCC
      if incTick - incUpTick <= 10 and incTick - incAlertTick >= 50
        incKind = 3
        incValue = incCC
        Call @IncidentSend
        incAlertTick = incTick
      endif
      incDownTick = incTick
      incUpTick = -100
    elseif MIDIByte3 > incCC
      incUpTick = -100
      if MIDIByte3 - incCC = 1 and incTick - incDownTick <= 10
        incUpTick = incTick
      endif
    endif
  endif
  incCC = MIDIByte3
@End

@IncidentWet
  Call @IncidentSendMode
  incKind = 2
  incValue = wetOut
  Call @IncidentSend
  if incMode = 1 and direction < 0 and lastWet >= 0 and wetOut > lastWet
    if incTick - incDownTick <= 50 and incTick - incAlertTick >= 50
      incKind = 4
      incValue = wetOut
      Call @IncidentSend
      incAlertTick = incTick
    endif
  endif
@End

@IncidentSendMode
  if incMode <> incLastMode
    incKind = 6
    incValue = incMode
    Call @IncidentSend
    incLastMode = incMode
  endif
@End

@IncidentSend
  incPacket[4] = incKind
  incPacket[5] = incValue % 128
  incPacket[6] = (incValue - incPacket[5]) / 128
  SendSysex incPacket, 7
@End
"""
objects[385] = script.encode()
routes = objects[1491]
routes_by_name = dict(zip((objects[k.data] for k in routes["NS.keys"]), routes["NS.objects"]))
outputs = objects[routes_by_name["Node:Chan0:Slot1:MIDI OUT"].data]["NS.objects"]
beat_input, = (ref for ref in objects[routes_by_name["CoreMIDISrc:XONE:K2"].data]["NS.objects"]
               if objects[ref.data] == "Node:Chan1:Slot0")
assert beat_input not in outputs
outputs.append(beat_input)
destination.write_bytes(plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=False))
