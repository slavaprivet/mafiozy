# Static batching native render QA — coordinator handoff

Harness: `tools/godot/preview_static_render_qa.gd`.

Frozen SHA256: `e31db5d40b3aa091f1ace48b9bdfd7ff4d4faea7a872ab80a99be33b9922d7c2`.

Only the coordinator launches the native run after checking the actual window inventory. This helper has not launched a GPU window. It does not edit main, player, assets, export settings or production defaults. A single native window is reused and remains interactive after QA.

## Launch

Use the **actual Godot console engine**, not the exported release executable (the release executable does not execute this external test script). Supply the exported candidate PCK and absolute script/output paths. Do not pass `--preview-static-batch`, `--preview-static-batch-off`, `--preview-perf`, `--preview-capture` or `--fixed-fps`; the harness rejects these conflicting controls.

PowerShell, from the repository root, after the coordinator selects the verified candidate PCK:

```powershell
$staticQaEngine = 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$staticQaScript = 'C:/Users/Слава/Desktop/Мафиози/tools/godot/preview_static_render_qa.gd'
$staticQaPack = 'C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk/exports/win64/s01-20260927-static-candidate11/MafioziPreview.pck'
& $staticQaEngine --main-pack $staticQaPack --script $staticQaScript -- --static-qa-output=C:/Users/Слава/Desktop/Мафиози/outputs/static_render_native11
```

The candidate PCK path above was observed in the export directory; the coordinator must still verify its build receipt/hash before the native run. No extra renderer, cap or VSync flags are supplied: the candidate's settings, including the user's frame cap, remain in force and are recorded. Keep that window focused without moving the mouse or pressing keys during QA. Input or focus loss cancels the run and restores normal control. The script never closes a successfully loaded native game.

## Measurement and evidence

One actual-main instance is reused in **OFF / ON / ON / OFF** order. Each native window has 5 seconds of warmup and 600 measured wall-frame intervals. Arrays are preallocated. Per-frame checks record draw calls/primitives, focus, input and setting changes; there is no PNG, JSON, content hash, GPU readback or notes-file poll inside the measured windows. The report retains raw intervals and p50/p95/max, actual settings, batch status, source hashes and startup plan/apply costs.

This is **static small-quarter QA, NPC0/vehicles0**, not whole-city or normal gameplay FPS. Main/player callbacks are frozen; the water host is explicitly sampled at zero and its clock no longer advances. The notes timer is stopped for the test. A fresh interactive main restores its normal controller, water, notes timer and authored printshop-approach spawn afterward. Frozen callbacks are an explicit measurement qualification, not a production optimization.

The fixed camera looks at both actual block candidates: gunshop local `(0,0,24.6)` and pawnshop `(0,0,-24.6)`. The resulting first view is `(61.5,31.675,0)` toward `(0,4,0)`, FOV 65. Three additional OFF/ON camera pairs cover each facade obliquely and the reverse side/culling view. Exact transforms appear in the report.

Eight PNGs, `view-0-off.png` through `view-3-on.png`, are saved outside timing. Compare each pair for facade colors/material boundaries, normal/light direction, cast shadows, silhouettes and missing/cull-disappearing pieces. Image equality and Godot image error metrics are supplementary: differences require actual image inspection; the script does not declare visual correctness from a numeric threshold. The report's `passed` is automated harness acceptance, with `visual_review_required=true` on native runs.

## Actual GPU transform check

The ON run collects the helper's CPU receipts, but does not call those GPU evidence. After a rendered frame and outside timing, a render-thread callback uses `RenderingServer.multimesh_get_buffer_rd_rid` and **`RenderingDevice.buffer_get_data`**. Expected transforms are packed from the independent CPU receipt, with a maximum admitted allocation of 16 MiB. The current actual block has 69 batches / 248 source instances / 11,904 expected transform bytes.

The raw format is pinned to the exact engine commit `ed1daf0bf001b61586d9930840f2f1394092c079`. Its allocation uses 12 floats for a 3D transform without colors/custom data; transform rows and translation occupy three four-float rows. Motion-vector allocation can double the buffer and swap current/previous offsets. The harness reads the **whole allocation**, admits only one or two exact-size banks, and requires **both banks** to match the same static transforms if doubled. It never guesses the current bank. A different engine hash, changed format/count, unexpected allocation, nonfinite value or error above 1e-5 fails closed. See the pinned [allocation and motion-vector implementation](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp#L1419) and [transform packing](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp#L1721).

This is stricter than reading a possibly cached `MultiMesh` transform getter. An unavailable RenderingDevice (for example an incompatible backend), ambiguous double-bank data or a readback timeout is not a PASS. The main scene is still restored. A doubled static buffer whose historical bank differs may conservatively fail despite a correct current render; inspect that result before choosing any alternative evidence.

## Headless control-flow checks already completed

```powershell
& $staticQaEngine --headless --path godot/mafiozi_walk --script $staticQaScript -- --static-qa-selftest --static-qa-output=C:/Users/Слава/Desktop/Мафиози/outputs/coordinator21_static_qa_selftest
& $staticQaEngine --headless --path godot/mafiozi_walk --script $staticQaScript -- --static-qa-selftest --static-qa-selftest-abort --static-qa-output=C:/Users/Слава/Desktop/Мафиози/outputs/coordinator21_static_qa_abort
```

Both exit 0. The complete self-test produced four 12-frame windows with statuses disabled/ready/ready/restored and one stopped notes timer; fresh interactive scene restoration passed. The abort test injects a measurement interruption in window 1: its report correctly has `passed=false`, `cancelled=true`, and `interactive_restored=true`; exit 0 means this expected cancellation path passed.

Headless reports explicitly say **`HEADLESS_NOT_GPU_READBACK`** and mark native render evidence false. Dummy draw counts, omitted PNGs and short timings are not native rendering/FPS admission. Native readback, material/shadow/culling image review and comparable frame results remain for the coordinator's one-window run.

## Candidate11 native interruption

`outputs/static_render_qa11/report.json` records cancellation after user input during the first OFF window (61 measured frames). `passed=false`, `cancelled=true`, `input_seen=true`, `interactive_restored=true`. No ON comparison, GPU transform readback or material/shadow acceptance was completed; these partial OFF values are not comparative FPS evidence. Static batching remains default OFF.
