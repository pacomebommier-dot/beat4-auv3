"""Use one Mozaic interpolation for manual and BEAT4-timed recalls."""
import plistlib
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
archive = plistlib.loads(source.read_bytes())
objects = archive["$objects"]
script = objects[385].decode()

def edit(before, after):
    global script
    assert script.count(before) == 1, before
    script = script.replace(before, after)

edit("@OnLoad\n", "@OnLoad\n  manualRecallTicks = -1\n")
edit("  Call @SceneTick\n", """  Call @SceneTick
  if manualRecallTicks >= 0
    manualRecallTicks = manualRecallTicks + 1
    recallRatio = manualRecallTicks / 130
    Call @ApplyRecallCurve
    if manualRecallTicks >= 130
      manualRecallTicks = -1
    endif
  endif
""")

start = script.index("    morphEngaged = 0", script.index("\n@AutoPreset\n"))
end = script.index("\n  endif\n  autoLast", start)
capture = "\n".join(line[2:] for line in script[start:end].splitlines())
capture = capture.replace("      sceneCell = sc", "      sceneCell = sceneActive * 15 + sc") if "      sceneCell = sc" in capture else capture.replace("    sceneCell = sc", "    sceneCell = sceneActive * 15 + sc")
script = script[:start] + "    manualRecallTicks = -1\n    Call @CaptureRecallCurve" + script[end:]
edit("  if autoTargetPch <> autoPch or autoPosition < autoLast\n", """  if autoTargetPch = autoPch and autoPosition = autoLast
    Exit
  endif
  if autoTargetPch <> autoPch or autoPosition < autoLast
""")
edit("""  autoLast = autoPosition
  autoRatio = autoPosition / 16382
  autoRatio = autoRatio * autoRatio * (3 - 2 * autoRatio)""", """  autoLast = autoPosition
  recallRatio = autoPosition / 16382
  Call @ApplyRecallCurve
@End

@CaptureRecallCurve
""" + capture + """
@End

@ApplyRecallCurve
  autoRatio = recallRatio * recallRatio * (3 - 2 * recallRatio)""")

edit("""        if sceneSlot = 7
          autoOverride = pchActive
          if pchQueued >= 0
            autoOverride = pchQueued
          endif
        endif""", """        autoOverride = pchActive
        if pchQueued >= 0
          autoOverride = pchQueued
        endif""")
edit("// Explicit PRESET8 owns the sound until a different PCH is requested.",
     "// A manual recall owns the sound until a different PCH is requested.")

start = script.index("\n@SceneRecall\n")
end = script.index("\n@SceneSend\n", start)
script = script[:start] + """
@SceneRecall
  Call @CaptureRecallCurve
  for sc = 0 to 7
    if autoGoal[sc] < 0
      autoGoal[sc] = 0
    endif
  endfor
  if autoGoal[14] < 0
    autoGoal[14] = 0
  endif
  // 130 steps at the existing 10 ms timer. Restart from emitted levels.
  manualRecallTicks = 0
@End
""" + script[end:]
start = script.index("  elseif sceneOp = 1\n    GLOBAL72 = recallValues[8]")
end = script.index("  endif\n  GLOBAL70", start)
script = script[:start] + script[end:]

edit("@SceneBeginSave\n  morphEngaged", "@SceneBeginSave\n  manualRecallTicks = -1\n  morphEngaged")
edit("@MorphTargets\n  if", "@MorphTargets\n  manualRecallTicks = -1\n  if")
edit("@YellowStartRamp\n  yellowRampStarted", "@YellowStartRamp\n  manualRecallTicks = -1\n  yellowRampStarted")
objects[385] = script.encode()
destination.write_bytes(plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=False))
