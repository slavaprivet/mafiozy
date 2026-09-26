# S01 source normal jump and directional Max Payne dive — runtime hook

27 September2026. Coordinator21 scoped integration. **Actual input, controller physics, imported pose and headless tests PASS; native LIVE, loaded-scene FPS and release export remain root gates.** No GPU window/restart/export/Git operation was performed in this scope.

Owned changes: `scripts/preview_player.gd`, `scripts/tests/test_preview_dive_integration.gd`, this document. Existing `preview_dive.gd` remains unchanged. Main's source containment callback was implemented by the water/main owner under root authorization; see `S01_WATER_MAIN_HOOK.md`.

## Runtime behavior

First discrete Space starts the source normal trajectory. A released second Space within500ms inclusive upgrades the existing flight in its current direction, current input direction, or camera-forward when stationary. Repeat/held duplicate keydown, late/third presses and unsupported new jumps cannot add an impulse or reset elapsed. Text focus blocks admission. Actual timestamps use the monotonic tick clock.

Normal and dive now share the source clock from the first Space: normal3.5m/s, height1.05m, maximum2.8m; dive4.2m/s, fully immediate range3.36m, arc0.42m; flight0.8s/recovery0.45s and blend0.24s. This intentionally replaces the earlier Godot5.2m/s upward-velocity/gravity9.8 normal arc, whose apex was about1.38m. Root requested source trajectory parity before enabling upgrades; a separate reset-on-second-press trajectory would be wrong. Old tests asserting1.1..1.5m have been migrated by root, outside this scope.

The physical actor uses one velocity/movement owner. Each source substep calls real `CharacterBody3D.move_and_slide`; no flight/landing code assigns position. Velocity is expressed using the same engine-context delta that `move_and_slide` consumes, so bounded source substeps also work during a large accepted callback. Current physical capsule stays radius0.30/height1.9. A cached radius0.36 capsule query enforces the existing source permission footprint before moving; requested XZ movement retains the source≤0.12m subdivision and whole-step→X→Z slide order. Thin walls therefore receive an actual swept-volume test, not only endpoint probes.

Ceiling/support are queried from the physical world per substep. Source `resolveJumpSurface` order is retained: ceilingFoot=ceiling−bodyHeight−0.04; a ceiling or unsupported flight end initializes falling and integrates gravity18 **in that same substep**. Downward body collision confirms contact. Recovery holds physical support with a small downward contact query, never a timer teleport. When the source trajectory lifetime ends while still falling, actual fall velocity and gravity18 transfer to continued movement until support. Ordinary unrelated ledge movement retains its existing controller path.

## Pose ownership and cancellation

One final `_apply_selected_pose` writes the skeleton and complete visual transform. Source normal/dive selects exact sampler bones, visual quaternion and full-skin floor offset. The ordinary airborne sampler remains the fallback for unsupported non-source falls; it is reset at source takeoff. Directional banking uses actual world travel yaw; final gaze follows camera yaw/pitch independently, including downward camera aim. Quaternion tests treat q and−q as the same rotation.

Authority change/new lifetime cancels trajectory and pending source pose, clears velocity, resets sampler epochs and clears residual visual tilt. Non-on-foot authority owns movement as well as pose; the player does not continue walk/jump updates under another owner. Vehicle/death/custody/water/traversal systems still need their actual gameplay owners connected as those systems migrate; this hook provides the tested cancellation seam rather than inventing them.

Free mouse look, wheel zoom, Tab/Escape handling and text focus paths remain. Blur releases movement/Space latches as source `releaseControls` does. A visible unfocused game keeps simulating the trajectory; a minimized/hidden native window freezes the source clock. Invalid/nonpositive/>1s gaps are ignored; visible accepted deltas consume at most0.25s as≤7substeps of≤0.04s with no deferred debt.

## Source water semantics

`set_preview_jump_surface_guard(Callable)` accepts `(feet_world:Vector3,radius:float)->bool`. Main wires `preview_jump_surface_allowed` immediately after adding the player. It preserves the audited source map containment: native walkable land, authorized police tile9, **or** unprotected native water tile16; center+12footprint points, outside current crop=false. It is not a dry-only rule. The water surface creates no physical floor. Jumping beyond dry support may therefore enter actual falling while swimming/shore authority remains unported. Do not describe this as completed water gameplay or add an invisible water floor to hide that remaining gate.

## Verification

Actual Godot4.7.2-stable ed1daf0bf, headless, new integration suite: **145 assertions PASS, exit0**, including:

- Actual released Space input, held/repeat rejection,500ms guard, late/third press, stationary fallback and text focus.
- Deterministic physical replays at supplied3/5/10/30/60Hz callback deltas: normal distance2.80034–2.80035m and dive3.36036–3.36037m (under0.4mm physical solver difference); source normal apex1.05m and dive0.42m observed at5Hz and above. At3Hz the sample grid misses exact apex, as expected. These are supplied-clock replays, not a claim about wall-clock rendering at3GPU FPS.
- All8directions preserve3.36m with no diagonal boost;200ms upgrade preserves3.22m total and never moves the body at upgrade time.
- A separate run uses actual engine physics callbacks and real input events, checking delayed range and source visual transform each tick.
-2cm wall blocks at source0.36 permission footprint; low ceiling transitions to falling/contact in the triggering substep; actual lower floor catches the fall; post-lifetime gravity18 is retained.
- Owner/epoch reset, hidden/large-gap no-debt behavior, visible blur continuation, real player size and sampler binding.
- Actual main is instantiated after the standalone world: source containment callback is bound, out-of-crop rejects, a source water location is allowed while a physical ray confirms no water floor.

Log: `outputs/coordinator21_perf_acceptance/dive_integration.log`.

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_preview_dive_integration.gd
```

The existing source oracle already covers168actual Three.js/GLB poses and3trajectory traces; details in `PREVIEW_DIVE_HANDOFF.md`. Runtime source appearance follows that immediate source pose selection; the old Godot takeoff blend is not silently reintroduced. Root's old integration probe measured a larger idle→takeoff boundary step but continuous same-phase motion remained small; this distinction must stay explicit in visual acceptance.

## Cost and remaining gates

Loaded standalone headless player/floor, same rig/camera/settings, one player and no NPC/vehicles: complete controller+source pose callback CPU p50/p95 **0.579/0.785ms** across the measured suite. The prior accepted standalone sampler kernel was about0.530/0.708ms; these different windows are not a rigorous overhead subtraction. Collider/query objects are cached, physics work is bounded per callback, the source full-skin sampler uses prepared support rather than scene scans, and only one final pose is sampled/applied per callback. No geometry was removed for performance.

**Производительность общей сцены не проверена.** Root owns matched loaded-scene before/after measurement, visual Max Payne input/direction/distance, camera/floor contact, obstacles/slopes/steps, lighting and export. The current support/ceiling rays plus body sweeps are a physics adaptation, not a port of all source `surfaceMotion` step/slope and swimming systems. Weapon IK/grips/shooting, crouch/prone queued landing transition and traversal/shore interaction remain OPEN; no substitutes were invented.

`get_preview_status().source_dive_ready` checks the actual bound sampler readiness; `jump_surface_guard_bound` reports main containment wiring separately. Neither flag is a LIVE/FPS acceptance claim. `source_jump`, `source_jump_pose` and `source_falling` expose trajectory/physical handoff state for review.

Current tested player SHA256: `57e9762b7f836bb9729ac5f218886d8400c18a90e36cb4d022c3988027b7826b`.
Unchanged sampler SHA256: `9a90722492bbf6e1c0303251d78dccd599093cb8a30804548011bb44be3bc86c`.
Independent review remains separate and must use the final frozen player hash.
