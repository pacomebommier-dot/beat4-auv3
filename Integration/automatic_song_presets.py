"""Apply host-beat PRESET1 progress to the existing Mozaic preset controls."""
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

preset = edit(preset, "@OnLoad\n", """@OnLoad
  autoPch = -1
  autoOverride = -1
  autoLast = -1
""")
preset = edit(preset, "@OnMidiInput\n", """@OnMidiInput
  if MIDICommand = 224 and MIDIChannel = 0
    autoPosition = MIDIByte2 + 128 * MIDIByte3
    Call @AutoPreset
    Exit
  endif
""")
preset = edit(preset, "        Call @SceneRecall\n", """        if sceneSlot = 7
          autoOverride = pchActive
          if pchQueued >= 0
            autoOverride = pchQueued
          endif
        endif
        Call @SceneRecall
""")
preset = edit(preset, "\n@SceneReference\n", """
@AutoPreset
  if autoPosition = 16383
    autoPch = -1
    autoOverride = -1
    Exit
  endif
  if scenePending >= 0
    Exit
  endif
  autoTargetPch = pchActive
  if pchQueued >= 0
    autoTargetPch = pchQueued
  endif
  // Explicit PRESET8 owns the sound until a different PCH is requested.
  if autoTargetPch < 0 or autoTargetPch = autoOverride
    Exit
  endif
  if autoTargetPch <> autoPch or autoPosition < autoLast
    autoPch = autoTargetPch
    autoOverride = -1
    sceneActive = 0
    scenePch = autoPch
    morphEngaged = 0
    morphDirection = 0
    morphRebase = 0
    morphMix = 0
    sceneMixRamp = -1
    synced = 0
    direction = 0
    sceneTracking = 1
    for sc = 0 to 14
      sceneCell = sc
      Call @SceneReference
      autoGoal[sc] = sceneRef
      if sc < 8
        autoOrigin[sc] = fxSent[sc]
      elseif sc < 14
        autoOrigin[sc] = sceneRemote[sc - 8]
      else
        autoOrigin[sc] = Round (mix * 16383)
      endif
      if autoOrigin[sc] < 0
        autoOrigin[sc] = 0
      endif
    endfor
  endif
  autoLast = autoPosition
  autoRatio = autoPosition / 16382
  autoRatio = autoRatio * autoRatio * (3 - 2 * autoRatio)
  for autoIndex = 0 to 14
    autoValue[autoIndex] = -1
    if autoGoal[autoIndex] >= 0
      autoValue[autoIndex] = autoOrigin[autoIndex] + (autoGoal[autoIndex] - autoOrigin[autoIndex]) * autoRatio
      if autoIndex < 8
        fxTarget[autoIndex] = autoValue[autoIndex]
        fxStep[autoIndex] = 127
        fxGesture[autoIndex] = 0
        fxArmed[autoIndex] = 1
      elseif autoIndex = 14
        mix = autoValue[14] / 16383
        target = mix
        mixArmed = 1
      endif
    endif
  endfor
  sceneOp = 4
  Call @SceneSend
@End

@SceneReference
""")
preset = edit(preset, "  else\n    GLOBAL72 = recallValues[8]", """  elseif sceneOp = 4
    GLOBAL72 = autoValue[8]
    GLOBAL73 = autoValue[9]
    GLOBAL74 = autoValue[10]
    GLOBAL75 = autoValue[11]
    GLOBAL76 = autoValue[12]
    GLOBAL77 = autoValue[13]
  elseif sceneOp = 1
    GLOBAL72 = recallValues[8]""")
circuit = edit(circuit, "sceneOp = 1 or sceneOp = 2 or (sceneOp = 3 and base12Held = 0)",
               "sceneOp = 1 or sceneOp = 2 or sceneOp = 4 or (sceneOp = 3 and base12Held = 0)")
circuit = edit(circuit, "          else\n            sceneGoal = sceneRequest[sc]", """          elseif sceneOp = 4
            if sceneRequest[sc] >= 0
              sceneOwned[sceneTrack] = 1
              trackRate[sceneTrack] = 127
              trackTarget[sceneTrack] = sceneRequest[sc]
            endif
          else
            sceneGoal = sceneRequest[sc]""")
objects[385], objects[683] = preset.encode(), circuit.encode()
destination.write_bytes(plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=False))
