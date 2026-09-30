# Clear original-face observer, test-only23g

New folder; prior GPU25PASS/blank-frame evidence preserved. Actual compiled23g headless test: **25checks PASS**,4.24s, no engine errors (`headless01`). No GPU or production changes.

The fatal shot still uses real input/ammo/projectiles/HP. It now returns after the actual impact/final-death receipt instead of waiting an extra24physics frames, and the subsequent90frame wait was removed. The three final pictures capture **confirmed final death during its natural fall**, before the floor can cover the face. No body freeze/pose edit; ordinary NPC and player physics continue.

Observer improvements:

- Skin wound view follows original bound mark geometry.
- Eye views use the actual changed original SKIN eyelid vertices from the approved closed-eye mesh, computing their current skinned centre and outward face direction. Both views are from the front with opposite small lateral offsets; no automatic back-of-head view.
- Every camera candidate requires a supporting floor and at least18cm camera clearance above it; the world ray must be clear.
- A second original-rendered-triangle query rejects nearer hair/back-of-head geometry. Skin views require first surface SKIN and proximity to the intended target. Failures are explicit `clear_observer` assertions.
- Observer evidence records camera/target/floor, actual frontmost surface, distance error and closed-eye vertex count. These are geometric visibility checks, not pixel-image acceptance.

Root-only GPU command uses the same runner interface:

```powershell
python outputs/coordinator23_marks_visual23g_clear/run_capture.py --pack "ABS/candidate10/godot/mafiozi_walk/exports/win64/s01-20260930-quality23g/MafioziPreview.pck" --sha256 3ba945307a9d71f800a687c3cb75fb62c5d7a39834eaa30be74f263b6f8adb0a --out "ABS/FRESH_OUTPUT_DIRECTORY"
```

NO_FOCUS/offscreen1280×720, four PNG names,23/25s bounds unchanged. capture SHA `065217ed53ba909a73f1e0c3e74f07458f663e37ca87c188f17ed46f43881ea1`; closure in HARNESS_PINS. Root must inspect images; headless PASS does not make the previous blank images acceptable.

Inherited RESULT.scope still contains the historical stationary-NPC wording. This override leaves residents moving; VISUAL_RESULT and fixture/observer receipts describe the actual scenario. Detached observer and player placement are QA-only, not ordinary camera or performance proof.
