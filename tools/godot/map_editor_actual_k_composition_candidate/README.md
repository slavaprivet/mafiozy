# Actual-main K pause composition — diagnostic HOLD

This tools-only candidate stages the immutable Coordinator22 residents checkpoint,
not the moving production project. Its source closure is SHA-pinned (192 files;
`cbd7182488cbaf56a72017c8be101b4bfdf4c9e9088e1d414324a7e435ba6`).
The derived scene leaves residents **enabled**, overlays the separate resident
and navigation atomic-owner candidates, and mounts the earlier actual-main K
router with an inert pause-only workspace. No map object can be edited here.

The workspace requires the real three-resident population and its atomic API
before admitting K. It acquires population/navigation before pausing the melee
clock and tree. On exit it checks the exact population receipt, prepares and
commits a population ticket, resumes the clock while the tree is still paused,
finalizes all population/navigation owners without yielding, unpauses, then
flushes held navigation completions. Refusal or drift retains a paused terminal
HOLD; focus loss, teardown and Escape do **not** try an unsafe partial restore.
There is a known one-way-clock hazard: this candidate resumes the melee clock
before population finalization, so a late finalizer refusal can leave the clock
advancing behind a paused scene. It must not be installed or treated as a safe
K handoff until a clock transaction fixes that ordering and native fault tests
prove it. This is a diagnostic contract, not proven engine-level atomicity.

Source/static checks for the original, one-way-clock variant:

```
node tools/godot/map_editor_actual_k_composition_candidate/test_source.mjs
node tools/godot/map_editor_actual_k_composition_candidate/stage.mjs --dry-run
```

`stage.mjs --stage --clock-atomic` selects the separate two-phase clock overlay
and creates a unique isolated project under `outputs/` with a separate Godot
user directory. Direct user authorization allowed a bounded headless check.
Clean stage `outputs/map-editor-actual-k-atomic-F3zzSu` imported in Godot 4.7.2
with exit 0. Its three-resident pause-only native fixture passed **8/8** only
with `--diagnostic-force-still`, which artificially freezes the parked car to
isolate the resident/navigation/clock path. Without that diagnostic flag the
same fixture failed **5 checks / 1 failure**: `rolling_or_contact_vehicle`.
The parked-brake car retained ~0.01213 m/s and moved ~0.1214 m over 600 physics
frames; relaxing the motion threshold would conceal real drift. This is an
observed blocker, not K acceptance. The open production game and main/player/
project were untouched.

The old unclocked `--stage` variant retains the known one-way-clock hazard and
must not be used. Even the new clocked stage is **pause-only**, not an editor,
and independent review found unresolved teardown, late navigation flush and
stale-water-owner hazards. Native happy-path checks do not prove safe failure
recovery or full-world editing.

An additional opt-in `--stage --clock-atomic --vehicle-lease` variant adds a
31-physics-sample, owner-issued parked-car lease. Clean isolated stage
`outputs/map-editor-actual-k-atomic-qHUriR` imported in Godot 4.7.2 (exit 0).
The actual three-resident K enter/exit fixture passed **10/10, exit 0** with
`--vehicle-lease` and **without** `--diagnostic-force-still`; the real parked
body was frozen under owner receipt and restored before gameplay resumed.
This closes the specific parked-drift happy-path refusal in the isolated
checkpoint only. That stage does not include map edits, negative cross-owner
faults, teardown-guard composition, LIVE, or the moving production source.

The next clean combined stage `outputs/map-editor-actual-k-atomic-dk8DDJ`
adds the independent teardown guard. Godot 4.7.2 import exited 0. Without
synthetic car freezing, normal K passed **10/10**; clean owner teardown,
foreign token, corrupt receipt and workspace-only removal passed **8/8,
8/8, 8/8, 9/9** respectively, all native exit 0. These cover only the
specified teardown paths; they do not close late navigation callback
side-effects, all possible owner drifts, map editing, or production LIVE.
An additional changed-vehicle-session attempt passed **9/9**, retaining
the scene paused with the native body held rather than allowing K to resume.
The navigation candidate separately passed a 23/23 native late-flush fixture,
but that test has not yet exercised the combined K handoff.

The water-owner overlay is independently source/native tested and then staged
with clock, vehicle and teardown as `outputs/map-editor-actual-k-atomic-YlRVuJ`.
Godot 4.7.2 import exit 0; normal K **10/10**, clean owner teardown **8/8**,
and removal of the water factory while paused **9/9**, all headless exit 0
without a synthetic car freeze. This proves only a narrow owner-lifetime
failure path in the pinned checkpoint. The real LIVE scene and full editor
remain unmodified and unverified.

## Isolated teardown recovery variant

`teardown_variant.mjs` composes over the two-phase clock workspace without
changing the base K builder. `stage_teardown.mjs` creates a separate pinned
headless stage and adds the root-owned `teardown_guard.gd`. Before a paused
scene is destroyed, the workspace checks its population, clock, source bytes,
snapshot and exact SceneTree token. The guard removes that token and releases
the global pause only after the entire owner scene is gone. Removal of the
workspace alone, a foreign token, a corrupt receipt, or a terminal fault keeps
the tree paused. No implicit Escape or focus recovery is added.

```
node tools/godot/map_editor_actual_k_composition_candidate/test_teardown_source.mjs
node tools/godot/map_editor_actual_k_composition_candidate/stage_teardown.mjs --dry-run
```

The isolated Godot 4.7.2 headless fixture passed clean teardown, foreign-token
and corrupt-receipt refusal, workspace-only removal refusal, and normal K exit
with the parked car artificially frozen. The final workspace SHA-256 was
`1bacb814684d5ea6e062742b75d540c12db99f56c47ace3b3b3b016637740314`.
This does not clear the real parked-car motion blocker, cover other teardown
orders, or establish production/LIVE acceptance. The staged variant remains
diagnostic HOLD.

Open requirements: negative fault injection and independent engine
navigation mutation during handoff, authored/procedural 9901-object rendering,
full edit transactions and save/load, root production integration, real LIVE
quality and frame-time checks. The running production project has newer weapon
and NPC source than this checkpoint; source pins must be deliberately rebased
and all owners revalidated before any main adoption.
