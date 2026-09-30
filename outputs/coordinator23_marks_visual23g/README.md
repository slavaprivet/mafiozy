# Robust exposed-face capture,23g

Prepared **new** output-only harness; previous GPU failure/evidence unchanged. No runtime/production edits and no GPU launched.

Actual compiled candidate10 PCK `3ba945307a9d71f800a687c3cb75fb62c5d7a39834eaa30be74f263b6f8adb0a` passed21checks headless in5.92s (`headless01`) and again with300physics frames of extra normal NPC walking in10.87s (`headless_delayed300`). The latter changed the NPC position and facing substantially. Both produced an actual2-round TT sequence, HP36→0/head-final, FABRIC first wound, SKIN second wound and closed eyes. No engine errors. This proves fixture behavior, not PNG appearance.

Instead of aiming at the head centre from the old player location, the fixture enumerates up to16 original rigid SKIN triangle candidates (8angular sectors ×2height bands). It positions only the player2.8m along the triangle's outward horizontal normal, verifies a real static supporting floor and a clear actual player capsule, and leaves scheduled player/NPC physics active. The target follows that original local head triangle as the resident moves. QA camera height1.65m avoids the previous steep overhead/parallax angle. No NPC/skeleton/body rotation, pose, HP, mesh or collision writes.

The actual muzzle must reach the same owned collider, native head classifier must prove the anatomical hit, and the frontmost original cosmetic surface must be exposed SKIN. No shooting through hair and no cosmetic filtering/x-ray. Each attempted player position, original triangle and result is recorded in VISUAL_RESULT.fixtures. Both headless scenarios needed2placements. Allocation and geometry searches exist only in this external test fixture.

GPU runner (root-owned window only):

```powershell
python outputs/coordinator23_marks_visual23g/run_capture.py --pack "ABS/candidate10/godot/mafiozi_walk/exports/win64/s01-20260930-quality23g/MafioziPreview.pck" --sha256 3ba945307a9d71f800a687c3cb75fb62c5d7a39834eaa30be74f263b6f8adb0a --out "ABS/FRESH_OUTPUT_DIRECTORY"
```

Same four PNG names: clothing wound, exposed head skin wound, two final-eye head-axis views. Original NO_FOCUS/offscreen1280×720 and23s guard preserved; runner25s bound. HARNESS_PINS verifies local two-script closure. The run may still fail honestly if no supported exposed angle exists; it never alters NPCs to force one.

The inherited RESULT.scope string says stationary NPCs because it comes from the historical helper. That label is stale for this override: capture.run loads normal scene without disabling resident walking; VISUAL_RESULT.scope and fixture evidence describe the actual scenario. The label is retained with the frozen helper for provenance, and does not imply NPCs were frozen. Camera/player placement are explicit QA fixtures, not normal-camera parity or performance acceptance.
