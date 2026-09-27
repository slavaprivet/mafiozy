# Moving exit presentation timing — 27 September 2026

New user-approved presentation profile; original canonical tumble geometry is retained. Only new helper/test files were written here. Root owns transport hookup; Transport3 owns physical exit corrections. No player/main/transition/pose implementation was changed by this package.

## Observed cause

Actual native02 (real E/W drive, speed at exit 5.737398 m/s) shows recovery root translation only .421399 m after the first recorded recovery frame. It stops by body_progress .196078 (~.333 s), then stays in place for another 1.350 s. Canonical source tumble rotation runs during progress .06..70, or .102..1.19 s. Thus most rotation happens after physical travel has already ended. Native01 reproduces the same pattern (.422294 m, same final translating progress).

Both successful traces advance recovery time: 96 distinct progress values, longest repeated sample about 21.8 ms. They do not show a frozen elapsed clock. Current native recovery's arbitrary collision→BLOCKED/elapsed-freeze and inherited Y are separate physical defects being handled by Transport3; these must not be concealed by animation remapping.

`replay_exit_visual_timing.mjs` executes actual `car_exit.mjs::stepExitBody` against an all-clear callback with inferred native02 launch planar speed 2.903047 m/s. Maximum native/source XY difference is .000045451 m. Speed/9 predicts stop at .322561 s. Source pose has completed only 10.66% of a turn by this stop; it keeps rotating another .867439 s afterward.

## Frozen pure API

`res://scripts/vehicle_visual/vehicle_exit_presentation.gd`

```gdscript
var presentation = ExitPresentation.sample(
    recovery_elapsed_s, recovery_duration_s,
    initial_planar_speed_mps, previous_visual_progress, blocked)
```

Output: valid, visual_progress, roll_window_s, physical_progress, rolls_scale, blocked, done. It reads no node, changes no rig/body/authority and performs no I/O. Helper SHA256 `5acd95e835b3779847a9518cca3a0ab8aef266ce362547021343a1f5e04be1cb`.

Retain initial **planar** speed once at RECOVERY launch from the physical owner, not car speed at initial E, not current speed and not an inferred value in runtime. Key `previous_visual_progress` by the same exit token/lifetime/epoch, start at 0, discard at completion/cancellation/authority loss. Never carry it to a new exit. On valid sample pass visual_progress to the existing canonical `_exit_pose.sample`, and multiply canonical roll count by rolls_scale. Keep physical elapsed/body_progress/occupancy/release unchanged. Render status should expose physical and visual progress separately rather than overwriting the physical receipt.

The planned rotation window is `clamp(initial_planar_speed / 9, .25, 1.19)` for normal 1.7-second recovery. General shorter durations cap the window at 70% of duration. During this window canonical progress is `.70*u*(2-u)`. This finite initial slope reaches the .06 rotation threshold during the first 60-Hz frame at current native speed, instead of waiting .102 s. Afterward `.70 → 1` uses smoothstep over the remaining recovery time. First p0 and final p1 are exact. Canonical rotation completes before canonical get-up (>p.72), so the actor stays tucked until rotation has finished and then unfolds while stationary.

At native02 stop .322561 s the new presentation has completed one turn; time before authority release stays 1.7 s. This is an explicit user presentation change, not source time-parity. Current maximum 60-Hz rotation step is .749459 rad (~43°); at minimum normal launch speed 2.4 m/s it reaches .906973 rad. The action is much quicker and requires sole-window visual review. This timing helper cannot by itself promise realistic no-slip rolling distance.

High launch speeds cap the presentation window at 1.19 s; physical motion may continue afterward, as before. Zero launch speed returns rolls_scale=0 so no invented stationary spin occurs, while progress still reaches the canonical recovery endpoint. A blocked flag does not reset or freeze presentation time. A brief wall contact must not replay the beginning; physical owner still decides safe movement and release. Unexpected early stopping at a wall can leave some presentation rotation in place until the planned window ends; this helper does not invent contact geometry or dynamically rewind animation.

## Release seam: additive adapter delivered

Source RELEASE lasts .55 s and its fold formula reaches zero by release progress .88 (last ~66 ms fully unfolded). RECOVERY canonical p0 immediately tucks fully. The recovery timing remap alone does not remove this seam.

Delivered new `scripts/vehicle_visual/vehicle_exit_pose_blend.gd`, SHA256 `8e1350680b10511e88c75df70be887b9ac3bc40041575a7578362d07589ecad3`. It inherits the unchanged canonical ExitPose and keeps its normal `configure`, `sample`, `diagnostics`, `dispose` API. Root can replace its existing ExitPose preload with this subclass, reusing **one** prepared skin cache. Configure prepares canonical p0 once; no second full ExitPose sample is needed per release frame.

After the actual occupant sampler, only for source_phase=exit / exit_kind=tumble:

```gdscript
sampled = _exit_pose.blend_release(sampled, release_progress,
    Callable(self, "_exit_floor_height"), null, player._pose_epoch)
```

Apply the returned valid selected pose once via the existing final writer. Progress <=.55 returns the original occupant proposal; .55..1 uses smoothstep quaternion interpolation to canonical p0, with preserved canonical bone translations/scales. Visual rotation and offset blend as well. The adapter recomputes **every actual blended skin vertex** through the prepared rigid/weighted groups and resolves conservative source-grid floor support for that mixed pose. It does not interpolate endpoint minima, move the physical root, modify the collider, or alter release/authority clocks. Unknown floor, stale epoch, invalid/noncanonical pose and out-of-grid skin fail closed. Canonical target cache is geometry-only; current world frame, floor and epoch are supplied per blend.

`test_vehicle_exit_pose_blend.gd`: **677 checks PASS**, actual male occupant poses on both sides, 168 frames across flat/slope/step floors, independent brute-force inspection of all 8,338 original vertices each frame. Minimum clearance −0.104 µm (float noise), maximum release endpoint→grounded canonical p0 vertex difference 1.09 µm, maximum adjacent test vertex travel .06568 m per .016667 release-progress step (~9.17 ms of the .55-s release). Maximum mixed-pose floor lift .270754 m on the stepped fixture; this corrects actual intermediate skin geometry, not endpoint heights. Isolated mixed sample CPU p50/p95 2.869/3.754 ms over 162 samples. This cost replaces a canonical full-skin pass during the short release blend; it does not include the occupant sampler or establish loaded FPS. Evidence: `outputs/coordinator21_vehicle_liveqa/exit_pose_blend_test.json` and log.

The initial <=.55 pose remains the existing occupant contract; its physical/world support must already be valid. Root's actual release geometry and camera need a real driving check. No smoothing or physical teleport is used to hide contact errors.

## Verification and reproduction

- Godot headless `--script res://scripts/tests/test_vehicle_exit_presentation.gd`: **545 checks PASS**, five launch speeds, zero/high speed, endpoint equality, monotonic/stale-clock behavior, brief blocked flags, invalid values and first-frame rotation. Test prints isolated helper p50/p95 CPU; no scene/FPS inference.
- `node outputs/coordinator21_vehicle_liveqa/analyze_exit_trace.mjs outputs/coordinator21_vehicle_liveqa/native02/report.json`: native recorded timing/motion diagnosis.
- `node outputs/coordinator21_vehicle_liveqa/replay_exit_visual_timing.mjs outputs/coordinator21_vehicle_liveqa/native02/report.json`: actual source physical replay and proposed presentation timing; result `native02/exit_visual_timing_candidate.json`.
- `node outputs/coordinator21_vehicle_liveqa/check_exit_presentation_source.mjs`: **40 checks PASS**, actual unchanged JS `hero.tumblePose` on actual male GLB at 20 remapped times. Quaternion error <=2.98e-8 rad; every mesh vertex inspected, flat-floor minY −2.22e-16 m. Uses the same existing THREE vendor path as the source pose oracle, overridable with MAFIOZI_THREE_VENDOR. Result `exit_presentation_source_result.json`.

The isolated blend now validates actual native male rig skin against the three sampled floor fixtures. It does not validate loaded main release/hop/vertical physics, wall poses, female rig or LIVE aesthetics. Root must rerun real driving/exit and inspect the sole visible game after its integration and Transport3's physical fixes. This author launched no GPU.
