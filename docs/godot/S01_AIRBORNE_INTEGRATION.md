# S01 ordinary airborne integration — 26 September 2026

Implemented in the working source. **Not yet loaded into the user's running
release; LIVE animation and loaded-scene performance are not verified.** No GPU
window was launched, PID 43332 / session 9305 were untouched, no commit or push.

## Scope and ownership

- `godot/mafiozi_walk/scripts/preview_player.gd` is the single runtime pose writer.
  After `move_and_slide()` it takes actual `is_on_floor()` and
  `get_real_velocity()`, samples a fresh gait target, samples ordinary airborne,
  and applies one selected set of local bone poses and visual offset.
- `preview_locomotion.gd::sample()` constructs targets from cached canonical
  rest. It never reads the previous airborne result or writes nodes. Boot
  support uses cached hulls, parent indices and a composed candidate hierarchy.
  Existing `update_pose()` / `reset_pose()` remain standalone compatibility
  writers for existing tests/callers; the runtime player does not call them.
- `preview_airborne.gd` and its original test were not modified. Binding occurs
  before the first animated frame. Existing ordinary jump source coefficients,
  actual-contact landing and full elapsed landing recovery remain in the core.
- `set_preview_pose_authority(owner, new_lifetime=false)` clears both sampler
  states and increments the epoch on a changed owner or explicit new lifetime.
  Any owner other than `on_foot` makes the player skip all pose writes. This is a
  pose handoff seam, **not** an implementation of death/vehicle/custody/water or
  their movement authority. Future respawn/teleport integrations must request a
  new lifetime; changed rigs/static normalization require rebinding.
- Physics capsule, gravity, speeds, heading, camera, inputs and source authority
  contracts are unchanged. Main/perf/interior and the source Walk WIP were not
  edited. Combat/Max Payne/weapon/climbing animations remain outside this scope.

## Actual Godot verification

Engine `4.7.2.stable.official.ed1daf0bf`, invoked headless with
`--path godot/mafiozi_walk --script res://scripts/<test>.gd`.

Before editing:

- `test_preview_player.gd`: PASS, exit 0 (physical floor, walk/run/diagonal,
  existing jump and no double jump, wall obstruction and camera arm).
- `test_preview_locomotion.gd`: 23 checks PASS, exit 0.
- `test_preview_airborne.gd -- --quick`: 2 cycles, 400 samples × 8338 vertices,
  PASS, exit 0.

After editing:

- New `test_preview_airborne_integration.gd`: **298 checks PASS, exit 0**.
  Four actual controller/physics walk/run → jump → land → idle cycles. Peak
  physical height remains within 1.1–1.5 m; first supported frame carries the
  previous air pose exactly; no recovery starts before physical support.
  Both ascent and landing interruptions relinquish bones and visual offset,
  clear pending recovery, then recover canonical rest under a fresh lifetime.
  Same-owner lifetime increments and poisoned-live-pose isolation also pass.
  1182 samples of all 734 actual rigid boot vertices: minimum sole Y
  −0.000018718 m, maximum +0.000000576 m relative to the body foot plane;
  maximum adjacent boot displacement 0.063224 m at 60 Hz. Idle bone poses and
  visual offset restore exactly. Handoff jumps are excluded from continuity.
- `test_preview_locomotion.gd`: 23 checks PASS, exit 0. Skin floor range
  −0.000018789…−0.000017758 m; maximum skin step 0.063239 m. The existing test
  also verifies finite poses, unchanged bone translations/scales, unchanged
  physics root, exact rest return, 30/60/120 Hz gait distance and invalid input.
- `test_preview_player.gd`: all previous controller checks PASS, exit 0.
- `test_preview_player_materials.gd`: all seven meshes / 8338 vertex colours
  PASS, exit 0.
- Full `test_preview_airborne.gd`: **20 cycles / 4000 × 8338 vertex samples**,
  PASS, exit 0. Exact first-contact carry, full-skin floor error below 0.019 mm,
  maximum adjacent skin displacement 0.115610 m, source coefficients,
  authority invalidation, nonzero offsets and long steps preserved.
- Scoped `git diff --check`: no whitespace errors.

## CPU evidence and remaining acceptance

Same standalone gait test before/after: update CPU p50/p95 **17/33 → 27/49 µs**.
The fresh target and compatibility full-pose application cost more than the old
direct gait writer. In the actual integration test, the entire runtime
`_update_owned_pose()` measured **67/137 µs p50/p95**, including both samplers and
final application (also includes idle and external-owner frames). The unchanged
airborne core alone measured 15/58 µs in the final full-skin sampler test.
All support geometry/hierarchy work is cached at binding; no per-frame skin
vertex scan, new scene node or duplicate pose writer is used by the runtime.

These CPU samples come from headless test scenes, not comparable loaded game
frames. **Производительность общей сцены не проверена.** Coordinator must
schedule the single visible game's LIVE walk/run/jump/contact observation and
comparable frame-time p50/p95 measurement before declaring visual/perf acceptance.
Weapons, arbitrary slopes, other avatars and external action transitions need
their own acceptance when those systems are integrated.

## File receipts (SHA-256)

| File | SHA-256 |
| --- | --- |
| `scripts/preview_player.gd` | `a4dc0bb7ab3fdd2fdf2f8b4fdf8d10ed4e343e7c6c0f2f81cb6b4d7479816d77` |
| `scripts/preview_locomotion.gd` | `ce0d4d22e730246183283df79ba42a61bc8800b3178f91776e455b7cfcfc9478` |
| `scripts/test_preview_airborne_integration.gd` | `43378c47993711ebd865ea8a0e97ff590673312ac15ebedf3fbfe91043fbb5ad` |

Paths in the receipt table are relative to `godot/mafiozi_walk`.
