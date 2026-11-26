"""Apply the reviewed preset, A/B and project-state fixes to AUM V15.15."""
import plistlib
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
archive = plistlib.loads(source.read_bytes())
objects = archive["$objects"]
preset, circuit = (objects[index].decode() for index in (385, 683))

def edit(script, old, new):
    assert script.count(old) == 1, old
    return script.replace(old, new)

# Local save reads the last published levels without stopping the renderer.
preset = edit(preset, """            sceneHeld = sceneSlot
            sceneSavePch = pchActive
            Call @SceneBeginSave""", """            Call @SaveLocalPreset""")
preset += """
@SaveLocalPreset
  for localCell = 0 to 14
    localValue = -1
    if localCell < 8
      if fxKnown[localCell] = 1
        localValue = fxSent[localCell]
      endif
    elseif localCell < 14
      localValue = sceneRemote[localCell - 8]
    elseif mixArmed = 1
      localValue = Round (mix * 16383)
    endif
    if sceneSlot = 0
      localPreset1[pchActive * 15 + localCell] = localValue
    else
      localPreset8[pchActive * 15 + localCell] = localValue
    endif
  endfor
  if sceneSlot = 0
    localHas1[pchActive] = 1
    Call @PublishSpotPreset
  else
    localHas8[pchActive] = 1
  endif
  if sceneActive = sceneSlot and (scenePch < 0 or scenePch = pchActive)
    scenePch = pchActive
  endif
@End
"""

# If a direct load or a shortened deadline reports a discontinuous completion,
# restart the existing short curve from the actually emitted values.
preset = edit(preset, "  autoLast = autoPosition\n  recallRatio", """  if autoPosition = 16382 and autoLast < 15890
    autoLast = autoPosition
    Call @CaptureRecallCurve
    manualRecallTicks = 0
    Exit
  endif
  autoLast = autoPosition
  recallRatio""")
preset = edit(preset, "    autoPch = autoTargetPch\n    autoOverride", "    autoPch = autoTargetPch\n    autoLast = -1\n    autoOverride")

# Circuit feedback, including first known INIT by track, is scoped to the PCH.
init_globals = (66, 67, 68, 69, 79, 89)
track_ids = (0, 1, 3, 5, 6, 7)
init_publish = "  GLOBAL59 = activeProject + 1\n"
for number, track in zip(init_globals, track_ids):
    init_publish += f"  GLOBAL{number} = -1\n  if activeProject >= 0\n    GLOBAL{number} = circuitInit[activeProject * 8 + {track}]\n  endif\n"
circuit = edit(circuit, "  GLOBAL80 = scenePublish\n", init_publish + "  GLOBAL80 = scenePublish\n")
preset = edit(preset, "  FillArray sceneRemote, -1, 6\n", "  FillArray sceneRemote, -1, 6\n  FillArray morphCircuitInit, -1, 6\n  morphInitPch = -1\n")
init_receive = "    morphIncomingPch = GLOBAL59 - 1\n" + "".join(
    f"    morphInitIncoming[{i}] = GLOBAL{number}\n" for i, number in enumerate(init_globals))
preset = edit(preset, "    if sceneState = GLOBAL80\n", init_receive + """    if sceneState = GLOBAL80
      morphInitPch = morphIncomingPch
      CopyArray morphInitIncoming, morphCircuitInit, 6
""")
start = preset.index("        morphCell = morphSlots[morphNext]")
end = preset.index("      else\n        morphValue = morphHome[sc]", start)
preset = preset[:start] + """        morphPreset = morphSlots[morphNext]
        morphCell = morphPreset * 15 + sc
        morphValue = -1
        if pchActive >= 0
          if morphPreset = 0 and localHas1[pchActive] = 1
            morphValue = localPreset1[pchActive * 15 + sc]
          elseif morphPreset = 7 and localHas8[pchActive] = 1
            morphValue = localPreset8[pchActive * 15 + sc]
          endif
        endif
        if morphValue < 0
          morphValue = sceneSaved[morphCell]
        endif
        if morphValue < 0 and sc >= 8 and sc < 14 and pchActive >= 0 and pchActive = morphInitPch
          morphValue = morphCircuitInit[sc - 8]
        endif
        if morphValue < 0
          morphValue = morphOrigin[sc]
        endif
""" + preset[end:]

# RELAY audio engine publishes actual fade start, finish and safe-live.
preset = edit(preset, "@OnLoad\n", "@OnLoad\n  relayReportPch = -1\n  relayReport = 0\n")
preset = edit(preset, "@OnMidiInput\n", """@OnMidiInput
  if MIDICommand = 176 and MIDIChannel = 1 and MIDIByte2 >= 116 and MIDIByte2 <= 118
    if HostRunning = 1 and MIDIByte3 < 64
      relayReportPch = MIDIByte3
      relayReport = MIDIByte2
      if relayReport >= 117 and relayReportPch = pchActive and pchQueued < 0
        autoPosition = 16382
        Call @AutoPreset
      endif
    endif
    Exit
  endif
""")
preset = edit(preset, "@OnHostStop\n  yellowClock = 0", """@OnHostStop
  relayReportPch = -1
  relayReport = 0
  pchQueued = -1
  autoPch = -1
  autoLast = -1
  manualRecallTicks = -1
  yellowClock = 0""")
preset = edit(preset, "  if autoTargetPch = autoPch and autoPosition = autoLast", """  if pchQueued < 0 and relayReportPch = autoTargetPch
    if relayReport = 116 and autoPosition = 16382
      autoPosition = 16381
    elseif relayReport >= 117
      autoPosition = 16382
    endif
  endif
  if autoTargetPch = autoPch and autoPosition = autoLast""")
preset = edit(preset, "      pchQueued = MIDIByte3\n    endif\n    Call @PublishSpotPreset", """      pchQueued = MIDIByte3
    endif
    if pchQueued >= 0 and pchQueued <> relayPreviousQueue and pchQueued = relayReportPch
      relayReportPch = -1
      relayReport = 0
    endif
    Call @PublishSpotPreset""")

preset = edit(preset, "  if MIDICommand = 224 and MIDIChannel = 15\n    pchActive = -1", """  if MIDICommand = 224 and MIDIChannel = 15
    relayPreviousQueue = pchQueued
    pchActive = -1""")

# Give M3 the same active/queued identity as M2. Keep legacy behaviour until
# the first packet, e.g. while opening a session with an older BEAT4.
circuit = edit(circuit, "@OnLoad\n", "@OnLoad\n  beatProjectState = 0\n")
circuit = edit(circuit, "@OnMidiInput\n", """@OnMidiInput
  if MIDICommand = 224 and MIDIChannel = 15
    beatProjectState = 1
    nextProject = -1
    if MIDIByte2 < 64
      nextProject = MIDIByte2
    endif
    if nextProject <> activeProject
      Call @ActivateProject
    endif
    queuedProject = -1
    if MIDIByte3 < 64
      queuedProject = MIDIByte3
    endif
    Exit
  endif
  if MIDICommand = 224 and MIDIChannel = 0
    Exit
  endif
""")
circuit = edit(circuit, "  if MIDICommand = 192 and MIDIChannel = 15\n", "  if beatProjectState = 0 and MIDICommand = 192 and MIDIChannel = 15\n")
start = circuit.index("\n@OnHostStop\n")
end = circuit.index("\n@End", start)
circuit = circuit[:start] + "\n@OnHostStop\n  queuedProject = -1\n  GLOBAL92 = -1" + circuit[end:]
circuit = edit(circuit, "  if queuedProject >= 0\n    readyNow", "  if beatProjectState = 0 and queuedProject >= 0\n    readyNow")

routes = objects[1491]
def route(name):
    return next(objects[value.data] for key, value in zip(routes["NS.keys"], routes["NS.objects"])
                if objects[key.data] == name)
destination_m3, = (ref for ref in route("CoreMIDISrc:XONE:K2")["NS.objects"] if objects[ref.data] == "Node:Chan0:Slot2")
route("Node:Chan1:Slot0:Preset Song State")["NS.objects"].append(destination_m3)
def add(value):
    objects.append(value)
    return plistlib.UID(len(objects) - 1)

def put(dictionary, key, value):
    assert all(objects[ref.data] != key for ref in dictionary["NS.keys"])
    dictionary["NS.keys"].append(add(key))
    dictionary["NS.objects"].append(add(value))

relay_key = "Node:Chan2:Slot2:RELAY Fade Status"
preset_route = route("Node:Chan1:Slot0:Preset Song State")
put(routes, relay_key, {"NS.objects": [preset_route["NS.objects"][0]], "$class": preset_route["$class"]})
labels = objects[1587]
example = next(objects[value.data] for key, value in zip(labels["NS.keys"], labels["NS.objects"])
               if objects[key.data] == "Node:Chan1:Slot0:RELAY Control")
put(labels, relay_key, {"NS.objects": [add("RELAY @A3 RELAY Fade Status"), *example["NS.objects"][1:]],
                        "$class": example["$class"]})
objects[385], objects[683] = preset.encode(), circuit.encode()
destination.write_bytes(plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=False))
