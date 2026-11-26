"""Connect BEAT4's private PCH state output to the Mozaic preset script."""
import plistlib
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
archive = plistlib.loads(source.read_bytes())
objects = archive["$objects"]

def add(value):
    objects.append(value)
    return plistlib.UID(len(objects) - 1)

def entry(dictionary, key):
    return next(value for name, value in zip(dictionary["NS.keys"], dictionary["NS.objects"])
                if objects[name.data] == key)

def put(dictionary, key, value):
    assert key not in [objects[name.data] for name in dictionary["NS.keys"]]
    dictionary["NS.keys"].append(add(key))
    dictionary["NS.objects"].append(add(value))

routes, labels = objects[1491], objects[1587]
route_key = "Node:Chan1:Slot0:Preset Song State"
xone_route = objects[entry(routes, "CoreMIDISrc:XONE:K2").data]
preset_target, = (ref for ref in xone_route["NS.objects"] if objects[ref.data] == "Node:Chan0:Slot1")
put(routes, route_key, {"NS.objects": [preset_target], "$class": xone_route["$class"]})
relay_label = objects[entry(labels, "Node:Chan1:Slot0:RELAY Control").data]
put(labels, route_key, {"NS.objects": [add("BEAT//4 @A2 Preset Song State"), *relay_label["NS.objects"][1:]],
                        "$class": relay_label["$class"]})

script = objects[385].decode()
assert script.count("@OnLoad\n") == script.count("@OnMidiInput\n") == 1
script = script.replace("@OnLoad\n", "@OnLoad\n  pchActive = -1\n  pchQueued = -1\n")
script = script.replace("@OnMidiInput\n", """@OnMidiInput
  // Private BEAT4 cable: one packet carries the active and queued PCH.
  if MIDICommand = 224 and MIDIChannel = 15
    pchActive = -1
    pchQueued = -1
    if MIDIByte2 < 64
      pchActive = MIDIByte2
    endif
    if MIDIByte3 < 64
      pchQueued = MIDIByte3
    endif
    Exit
  endif
""")
objects[385] = script.encode()
destination.write_bytes(plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=False))
