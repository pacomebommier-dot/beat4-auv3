"""Resolve SPOT values from the active song's local preset and Circuit INIT."""
import plistlib
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
archive = plistlib.loads(source.read_bytes())
objects = archive["$objects"]
preset, circuit = (objects[index].decode() for index in (385, 683))

def edit(script, before, after):
    assert script.count(before) == 1, before
    return script.replace(before, after)

preset = edit(preset, "@OnLoad\n", "@OnLoad\n  GLOBAL93 = 0\n")
preset = edit(preset, "      pchQueued = MIDIByte3\n    endif\n    Exit",
              "      pchQueued = MIDIByte3\n    endif\n    Call @PublishSpotPreset\n    Exit")
preset = edit(preset, "      fxTarget[fxButtonIndex] = 0\n", """      fxTarget[fxButtonIndex] = 0
      if pchActive >= 0 and localHas1[pchActive] = 1
        spotFx = localPreset1[pchActive * 15 + fxButtonIndex]
        if spotFx >= 0
          fxTarget[fxButtonIndex] = spotFx
        endif
      endif
""")
preset = edit(preset, "          sceneCurrent[sceneCell] = sceneCapture[sc]\n        endfor",
              "          sceneCurrent[sceneCell] = sceneCapture[sc]\n        endfor\n        Call @PublishSpotPreset")
publish = "  GLOBAL93 = 0\n  if pchActive >= 0 and localHas1[pchActive] = 1\n"
publish += "".join(f"    GLOBAL{94+i} = localPreset1[pchActive * 15 + {8+i}]\n" for i in range(6))
publish += "    GLOBAL93 = pchActive + 1\n  endif\n"
preset += "\n@PublishSpotPreset\n" + publish + "@End\n"

circuit = edit(circuit, "  FillArray spot12Commanded, 0, 3\n  son4TraceTick", """  if Unassigned circuitInitSchema
    circuitInitSchema = 1
    FillArray circuitInit, -1, 512
    for initPch = 0 to 63
      for initDrum = 0 to 2
        circuitInit[initPch * 8 + 5 + initDrum] = spot12InitByProject[initPch * 3 + initDrum]
      endfor
    endfor
  endif
  FillArray spotCommanded, 0, 8
  son4TraceTick""")
start = circuit.index("        if incomingIndex >= 5 and activeProject")
end = circuit.index("      endif\n    endif\n  endif", start)
# Replace the old nested Drum-only capture through its matching endif.
old = circuit[start:end]
assert old.count("spot12InitByProject") == 2
circuit = circuit[:start] + """        if activeProject >= 0 and queuedProject < 0
          initKey = activeProject * 8 + incomingIndex
          if spotCommanded[incomingIndex] = 0 and circuitInit[initKey] < 0
            circuitInit[initKey] = MIDIByte3
          endif
        endif
""" + circuit[end:]
circuit = edit(circuit, "  FillArray spot12Commanded, 0, 3\n", "  FillArray spotCommanded, 0, 8\n")
circuit = edit(circuit, "  // SPOT12 restores the known INIT or the last SON4 position, then zero.",
               "  // SPOT reset: local PRESET1, first Circuit INIT, then zero.")
start = circuit.index("        if groupIndex = 3\n          spot12Target")
end = circuit.index("    endif\n  endif\n  if MIDICommand = 176 and MIDIChannel = 14 and MIDIByte2 = 0", start)
circuit = circuit[:start] + """        spotTarget = 0
        if activeProject >= 0
          initKey = activeProject * 8 + trackIndex
          if circuitInit[initKey] >= 0
            spotTarget = circuitInit[initKey]
          endif
          if GLOBAL93 = activeProject + 1
            localSpot = -1
            if trackIndex = 0
              localSpot = GLOBAL94
            elseif trackIndex = 1
              localSpot = GLOBAL95
            elseif trackIndex = 3
              localSpot = GLOBAL96
            elseif trackIndex = 5
              localSpot = GLOBAL97
            elseif trackIndex = 6
              localSpot = GLOBAL98
            elseif trackIndex = 7
              localSpot = GLOBAL99
            endif
            if localSpot >= 0
              spotTarget = localSpot
            endif
          endif
        endif
        spotCommanded[trackIndex] = 1
        sceneOwned[trackIndex] = 1
        trackRate[trackIndex] = 1.5
        trackTarget[trackIndex] = spotTarget
        if groupIndex = 3
          Log {SPOT12 cible piste }, trackIndex + 1, { valeur }, spotTarget
        endif
      endfor
      circuitGesture = circuitGesture + 1
""" + circuit[end:]
circuit = edit(circuit, "  if trackIndex >= 5\n    spot12Drum = trackIndex - 5\n    spot12Commanded[spot12Drum] = 1",
               "  spotCommanded[trackIndex] = 1\n  if trackIndex >= 5\n    spot12Drum = trackIndex - 5")
objects[385], objects[683] = preset.encode(), circuit.encode()
destination.write_bytes(plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=False))
