"""Add local PRESET1 and PRESET8 to the routed BEAT4 session."""
import plistlib
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
archive = plistlib.loads(source.read_bytes())
objects = archive["$objects"]
script = objects[385].decode()

def replace(old, new):
    global script
    assert script.count(old) == 1, old
    script = script.replace(old, new)

replace("  diagPresetTicks = 0\n  sceneHeld", """  if Unassigned localPresetSchema
    localPresetSchema = 1
    FillArray localPreset1, -1, 960
    FillArray localPreset8, -1, 960
    FillArray localHas1, 0, 64
    FillArray localHas8, 0, 64
  endif
  scenePch = -1
  sceneSavePch = -1
  diagPresetTicks = 0
  sceneHeld""")

replace("        if morphButtons[0] = 1 or morphButtons[1] = 1\n", """        if base12Held = 1 and (sceneSlot = 0 or sceneSlot = 7)
          if pchActive >= 0 and sceneHeld = -1
            sceneHeld = sceneSlot
            sceneSavePch = pchActive
            Call @SceneBeginSave
          endif
        elseif morphButtons[0] = 1 or morphButtons[1] = 1
""")
replace("          scenePressTicks = 0\n", "          sceneSavePch = -1\n          scenePressTicks = 0\n")
replace("        sceneActive = sceneSlot\n", "        sceneActive = sceneSlot\n        scenePch = pchActive\n")

replace("\n@SceneRecall\n", """
@SceneReference
  sceneRef = sceneSaved[sceneCell]
  if scenePch >= 0
    if sceneActive = 0 and localHas1[scenePch] = 1
      sceneRef = localPreset1[scenePch * 15 + sc]
    elseif sceneActive = 7 and localHas8[scenePch] = 1
      sceneRef = localPreset8[scenePch * 15 + sc]
    endif
  endif
@End

@SceneRecall
  for sc = 0 to 14
    sceneCell = sceneActive * 15 + sc
    Call @SceneReference
    recallValues[sc] = sceneRef
  endfor
""")
replace("    sceneGoal = sceneSaved[sceneCell]\n", "    sceneGoal = recallValues[sc]\n")
replace("  sceneCell = sceneOffset + 14\n  sceneGoal = sceneSaved[sceneCell]", "  sceneGoal = recallValues[14]")
for index in range(6):
    replace(f"    sceneCell = sceneOffset + {index+8}\n    GLOBAL{72+index} = sceneSaved[sceneCell]",
            f"    GLOBAL{72+index} = recallValues[{index+8}]")

start = script.index("      morphEngaged = 0", script.index("\n@SceneTick\n"))
end = script.index("    endif\n  endif\n  sceneState =", start)
capture = "\n".join(line[4:] for line in script[start:end].splitlines())
script = script[:start] + "      Call @SceneBeginSave\n" + script[end:]
replace("\n@SceneTick\n", "\n@SceneBeginSave\n" + capture + "\n@End\n\n@SceneTick\n")
replace("        sceneExists[sceneActive] = 1\n", """        scenePch = sceneSavePch
        if scenePch < 0
          sceneExists[sceneActive] = 1
        elseif sceneActive = 0
          localHas1[scenePch] = 1
        else
          localHas8[scenePch] = 1
        endif
""")
replace("          sceneSaved[sceneCell] = sceneCapture[sc]\n", """          if scenePch < 0
            sceneSaved[sceneCell] = sceneCapture[sc]
          elseif sceneActive = 0
            localPreset1[scenePch * 15 + sc] = sceneCapture[sc]
          else
            localPreset8[scenePch * 15 + sc] = sceneCapture[sc]
          endif
""")
replace("    sceneRef = sceneSaved[sceneCell]\n", "    Call @SceneReference\n")
replace("    if sceneExists[sceneActive] = 0 and (sc < 8 or sc = 14)", """    sceneHasReference = sceneExists[sceneActive]
    if scenePch >= 0
      if sceneActive = 0 and localHas1[scenePch] = 1
        sceneHasReference = 1
      elseif sceneActive = 7 and localHas8[scenePch] = 1
        sceneHasReference = 1
      endif
    endif
    if sceneHasReference = 0 and (sc < 8 or sc = 14)""")
replace("      sceneActive = yellowPreset\n", "      sceneActive = yellowPreset\n      scenePch = yellowPresetPch\n")
replace("  yellowPreset = sceneActive\n", "  yellowPreset = sceneActive\n  yellowPresetPch = scenePch\n")

objects[385] = script.encode()
destination.write_bytes(plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=False))
