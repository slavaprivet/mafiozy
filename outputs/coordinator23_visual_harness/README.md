# Root-only offline visual/behavior harness

`capture_behavior.gd` prepared and **syntax checked only** under Godot 4.7.2. No GPU run performed by this agent; no screenshot/behavior PASS claimed.

Visual02 audit revision: snapshot is now passive and never invokes mutating `current_muzzle()`. Original model projected bounds, actual context plate rectangle, visual visibility and pose receipt are recorded as observations, not shot admission/pixel visibility. Optional `--qa-visibility-probes` adds cargo03b/ground05b normal-camera views after explicit +.65m player fixture offsets, then restores fixtures before E. With this flag there are16 PNGs per resolution. Revised harness syntax checked; new GPU output not yet produced. See `../coordinator23_visual_audit/HANDOFF.md` for limits and UI proposal.

## Scope

- Actual `res://scenes/main.tscn`, original 8-building quarter, exactly three real NPC. Same original attached **4.8m spring-arm camera** throughout.
- Script may set **player position** for repeatable rear-trunk and existing street fixtures; every position change logged. Orbit uses real `InputEventMouseMotion` deltas through `root.push_input`, legal yaw/pitch only. Never sets camera position/transform, never `look_at`, never detaches camera, never aims at model triangles or alters bones/ammo.
- Real viewport click on launcher from free cursor, real Q/card click selection, real E opening, G storage, named exact UID E pickup, source G ground / E pickup, head-turn views armed/unarmed, C crouch / Z prone / forward crawl / Z stand / Esc release.
- Continuous movement polls InputMap; harness uses `Input.action_press/release` for the 36-frame crawl and logs this separately. All UI and action keys go through actual viewport dispatch.
- Each resolution yields fourteen PNGs plus per-PNG JSON receipts: 1280×720 and 1920×1080 by default. `--qa-resolution=1280x720` or `1920x1080` selects one.

## Root execution only

After the single GPU slot is coordinated, launch the engine against the isolated candidate with its usual Forward+ GPU renderer and an **offscreen starting position**:

```
GodotConsole.exe --path CANDIDATE_PROJECT --script ABS/capture_behavior.gd --position -32000,-32000 --resolution 1280x720 -- --qa-out=ABS_OUTPUT --qa-resolution=both
```

Use `Start-Process -WindowStyle Hidden` for the launcher helper as required. Never expose this QA window as the user's new playable demo. Script repeats the offscreen position and `NO_FOCUS` flag, and immediately restores `Input.mouse_mode=VISIBLE` after GUI/input dispatch. No accepted game process is stopped or started by this script; root owns sequential GPU inventory/lifecycle.

Do **not** use `--headless` for capture: script rejects that backend. If the offscreen/hidden platform does not deliver `frame_post_draw`, receipt fails after 3 seconds for that image; it does not silently fabricate a screenshot or fall back to a visible demo. Offscreen rendering on this machine is unverified until root runs it.

Root can parse the script safely with `--headless --check-only`; that does not exercise GPU or behavior.

## Timing and receipts

- Internal deadline **80 seconds**, writes failing `RESULT.json` and exits. Use an external root-owned **88-second watchdog** too, because a blocked GPU driver or synchronous engine stall can prevent any in-process timer from executing.
- For each screenshot, freeze the actual scene **only after real transitions/physics** and wait for two `RenderingServer.frame_post_draw` events. Capture comes from the real root viewport texture, checks native pixel dimensions and sampled color variation, writes PNG+hash+state. Re-enable scene immediately after readback.
- Every receipt explicitly says `performance_valid=false`. Freeze/capture/input ownership makes this a **visual/behavior scenario, not FPS/memory acceptance**. Root still runs its separate same-loaded-scene benchmark.
- `PROGRESS.json` updates for phases; per-frame image JSON records player/camera hierarchy, orbit, distances, inventory/current ammo, cargo context/summary, source NPC states and visible UI rectangles. `RESULT.json` contains all input events, fixture moves, failed checks, image receipts and before/after source hashes.
- NO_FOCUS may deliver OS blur. Harness keeps the scripted local control flag active while restoring the desktop cursor; records each resume. Thus this **does not certify native desktop focus/blur behavior**. The explicit Esc/free-cursor launcher behavior is tested with virtual ownership disabled around those actions.
- Bounded cargo acquisition uses only a finite ordinary orbit grid (42 legal yaw/pitch combinations) and actual `cargo.aim_context()` exact incoming UID. It does not inspect gun mesh triangles or relocate camera. A failed acquisition stores failure capture; never substitutes direct inventory pickup.
- The script fails if all fifteen actual thumbnail textures are not loaded, if NPC count or quarter population changed, if normal spring camera is detached, if any UID/ammo roundtrip changes, or if input sources change during capture.

No production files changed. This helper must not be exported as the normal scene or used to replace player controls.
