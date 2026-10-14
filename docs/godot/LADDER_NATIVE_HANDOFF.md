# Godot native roof-ladder package — 27 September 2026

## Result

The package ports the World roof-ladder descriptor, physical admission, route
motion and detailed rung-locked pose into isolated Godot helpers. It does not
read `Input`, mark viewport events handled, move a `CharacterBody3D`, write a
skeleton, modify the visible scene, or compete with door and vehicle E handlers.
When configured with the actual actor, the controller now owns only the exact
temporary `route_exclude_rids` collision exceptions and removes only those it
added on completion, abort, dispose or reconfiguration.

## Files

- `scripts/traversal/ladder_descriptor.gd` — validates source metre descriptors.
- `scripts/traversal/ladder_probe.gd` — full 1.9 m × .33 m capsule route checks
  and five-point physical landing support.
- `scripts/traversal/ladder_motion.gd` — deterministic 3.1 m/s climb, 7.2 m/s
  vertical slide, exact endpoints and safe reversal/cancel.
- `scripts/traversal/ladder_pose.gd` — climb-up/down/slide, mount/dismount,
  rung contacts and explicit holster proposal without root/bone translation.
- `scripts/traversal/ladder_controller.gd` — input-agnostic integration seam,
  terminal-support commit guard and exact collision-exception lifecycle.
- `scripts/tests/test_ladder_descriptor.gd`
- `scripts/tests/test_ladder_probe.gd`
- `scripts/tests/test_ladder_motion.gd`
- `scripts/tests/test_ladder_pose.gd`
- `scripts/tests/test_ladder_controller.gd`
- `scripts/tests/test_ladder_safety_lifecycle.gd`

No existing `traversal_*.gd`, `main.gd`, `preview_player.gd`, project/export/UI,
scene, or LIVE file is changed by this package.

## Input and ownership contract

Late-blocker addendum: render `committed_pose(rig_metrics)` after the actual
body prefix and `commit_step`. This follows physical rejection and additional
terminal-support truncation. See `TRAVERSAL_COMMITTED_POSE_HANDOFF.md`.

The host obtains a candidate with `nearest_prompt(feet)` and passes its own
resolved action to `try_begin`. Only `&"interact"` claims and starts a ladder;
any other action returns `claimed:false`. `request_slide()` also returns
`claimed:false` while inactive, so both Ctrl keys remain available to contextual
cover. Once active, slide is claimed and either accelerates descent or safely
reverses ascent toward the lower endpoint without changing the root immediately.

E while active maps to `request_cancel()`. An ordinary climb reverses over its
accepted history. A fast descent first becomes a controlled slow descent. Both
remain attached until a physical endpoint. The package never installs an input
listener, which prevents a third independent E consumer beside the current door
and vehicle handlers.

The future host remains the only body-transform and rig writer:

1. configure once with `configure_actor(space, mask, character_body)` so the
   controller can preserve pre-existing host exceptions and manage only the
   descriptor exclusions it adds;
2. set player pose authority to `&"ladder"` only after `try_begin.started`;
3. stop ordinary walk, jump, dive, posture, cover and combat transitions;
4. call `propose_step`, apply only accepted roots through the player physics
   owner, then call `commit_step`;
5. apply the returned rotations/contacts after the normal base-pose reset;
6. respect `weapon_policy:"holster"` while retaining previous visibility;
7. restore the standing capsule, floor snap, gravity, base pose and weapon at a
   terminal endpoint or external abort.

Door, vehicle, cash, weapon, rescue, conversation and ladder priority remains a
host responsibility. The controller intentionally cannot decide it.

## Physical contract

- lower reach: 1.35 m;
- upper reach: .95 m and feet no lower than `upper.y - 1.15 m`;
- body: 1.9 m high, conservative .33 m radius;
- ordered sweep spacing: at most .04 m;
- route: lower → crest at `upper.y + .12` → inner landing → upper;
- ascent endpoint: exactly `upper - normal * .75 m`;
- descent endpoint: exactly `lower`;
- route and final support are fully checked before admission and every proposed
  root is checked again during motion;
- all five support rays are checked again inside `commit_step` before accepting
  the first terminal/release sample and on every release sample; disappearing
  support returns `terminal_unsupported` and retains the last accepted root;
- a new blocker accepts only leading clear samples and keeps the controller
  active at the last safe root.

`route_exclude_rids` is an explicit descriptor field for a building body whose
source collision envelope covers the authored aperture. Side-rail colliders must
never be included in that exclusion. Landing support rays do not use route
exclusions, so real ground and roof support remain mandatory.

`configure(space, mask, actor_rid)` remains the read-only/probe configuration
and does not manage exceptions because an RID alone cannot distinguish a host's
pre-existing exceptions. Integrated character motion must use
`configure_actor(...)`; a descriptor with exclusions fails closed with
`collision_exception_body_required` under RID-only configuration. Successful `try_begin` installs only authored route
exceptions. Normal completion, `abort`, `dispose` and reconfiguration remove
only controller-owned exceptions; pre-existing host exceptions and both rail
bodies remain untouched.

## Pose contract

The pose sample uses the source .28 m default rung spacing and a true half-cycle
left/right exchange. One side reaches at least `.8` while the other is at most
`.2`, with no frame where both hands or both feet are below `.2` during attached
travel. Slide hands stay on both rails and feet stay together. Direction changes
both the `climb-up`/`climb-down` phase and contact rhythm. Mount uses the source
`.20 s` blend; ascent dismount follows the final crest/roof step-off route.
Ordinary lower descent, Ctrl slide, reversed ascent and safe cancel hold the exact
physical endpoint for a `.20 s` release blend, reaching pose weight zero before
the controller becomes complete. No extra lower translation or step-off is
invented.

Every pose result declares `root_owned:false`, `root_yaw_owned:false`,
`collision_owned:false`, `bone_translation_owned:false`, and
`bone_scale_owned:false`. The yaw is a request for the body owner, not a pose
write. Unreachable rig contacts are released.

## Verification boundary

All six suites passed in three consecutive runs with the official Godot 4.7.2 console
(`ed1daf0bf`) in `--headless` mode and project path `godot/mafiozi_walk`:

- descriptor: 11 checks;
- motion: 24 checks, including `10/30/60/144 Hz`, top/bottom cancel and `dt=0`;
  fixture descent is 2.75 s and Ctrl slide 1.8167 s including the `.20 s` release;
- pose: 18 checks; 200,000 proposals measured
  `4,926,503–5,102,661 us` (`24.633–25.513 us/sample`) across the three final runs;
- probe: 6 checks against real `PhysicsDirectSpaceState3D`; 80 warmed full-route
  samples measured `489–512 us` p50 and `585–762 us` p95;
- controller: 33 checks over 169 simulated frames, including source guards for
  input listeners and body writes.
- safety lifecycle: 17 checks with a real `CharacterBody3D`, fail-closed RID-only
  admission, compound authored
  envelope, separate blocking rails, preserved pre-existing exception, normal /
  abort / dispose cleanup, and support removal between admission and commit.

The six suites contain **109 checks**. The output-only audit also reports opposed
hand frames `60/281`, zero simultaneous hand/foot pair release frames, rung
quantization error `1.15e-7 m`, ordered sweep `<= .040001 m`, zero command-time
root delta for Ctrl reversal/cancel/`dt=0`, bottom terminal pose weight `0` at all
four rates, successful real-body exception travel/cleanup, and blocked final
commit after support removal.

Measurements are headless CPU microbenchmarks, not loaded-scene FPS or LIVE
acceptance. Performance of the common loaded scene remains unverified by design
because this package did not open the one visible GPU game.

The isolated module gate is GO. Integration and visual acceptance remain pending
because the existing player, skeleton IK adapter, central interaction resolver,
native ladder fixture export, weapon runtime, scene and single visible game are
outside this package.
