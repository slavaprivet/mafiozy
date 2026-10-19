# Original weapon pose package — Coordinator22

Frozen 2026-09-30. This is a pure presentation component, ready for root integration.
No main/player changes, GPU run, Git operation, ammo/HP/fire admission or NPC edit.
The separate original model package remains frozen at
`outputs/coordinator22_weapon_visual/freeze.json`.

## Files and contract

- `godot/mafiozi_walk/scripts/weapons/weapon_pose.gd`: original `hero_walk.mjs`
  weaponPose, applyReloadPose and lookAlongAim, supplied-base sampler.
- `godot/mafiozi_walk/scripts/tests/test_weapon_pose.gd`: independent source oracle
  comparison, actual imported hero skeleton writer, negative/lifetime tests.
- `tools/godot/build_weapon_pose_oracle.mjs`: exposes original private functions
  through an in-memory return-property injection. Function bodies/source files
  remain untouched. Requires existing Three r180 vendor or MAFIOZI_THREE_VENDOR.
- Evidence: `outputs/coordinator22_weapon_pose/{oracle.json,report.json,test.log,freeze.json}`.

Configure once with actual names, parents, absolute local rest transforms and
rest rig-to-source-actor transform. Main-thread only; no live Skeleton3D reference.
`sample(base, weapon, frame, aim, posture, phase, gait, epoch)` returns a new full
28-pose array, retained base visual fields and `weapon.local_to_socket` plus
`weapon.world_before_ground`. It never writes bones or reads current live geometry.
`none` returns the base unchanged. Binding errors, malformed frames, wrong identity,
duplicate decoration, epoch mismatch and degenerate arms reject with valid=false.
Returned poses are independent across subsequent samples. `dispose()` releases
cached binding data. Parent retains lifecycle/pose authority.

Weapon input is `{id, two_handed, source_metadata, reload_magazine_local}`. The
first three fields are the frozen visual profile. Cache the original first
magazine/drum rest origin once from geometry_nodes() and its weapon_rest metadata;
this is needed by the left reload grip (required for Uzi variants, AK74, M16,
Tommy). Do not read the currently animated magazine origin as the rest value.

Aim keys preserve source spellings: aimPitch, aimYaw, recoil, recoilYaw, airborne,
airBlend, landingAirBlend, reloadProgress. Posture is crouch/prone in [0,1].
Phase/gait must come from the same sampled locomotion state. Input dimensions and
positive affine matrices are checked. Source nonfinite optional aim/reload values
use the original fallback behavior; malformed nonnumeric values reject.

## Minimal root seam

1. Capture rest transforms once: source actor corresponds to `_visual` (including
   its source +Z heading), rig-to-motion and normalized-node-to-motion. At binding
   the motion node must be in its rest frame. Do not add another PI yaw or scale.
2. Call `make_frame(actor_world, actor_yaw, selected_base, rig_to_motion_rest,
   normalized_to_motion_rest, target_height, source_height)` each sample. It folds
   selected visual_rotation, visual_offset and scaled_offset exactly as source;
   it must not use last frame's posed live Skeleton transform.
3. Decorate selected locomotion/airborne pose before hit response and before the
   sole writer. Extend the existing affine writer route to `selected.has("weapon")`.
   Keep full matrices; do not independently overwrite hand rotations afterward.
4. After accepted bone writing, apply local_to_socket to the original model on
   actual socket_weapon, then visual.apply_reload(progress, prone) for its moving
   magazine/slide. No extra scale: the normalized hero ancestor already supplies it.
5. Refresh actual socket attachment before reading muzzle/shot_transform; never
   publish a muzzle receipt from a prior displayed pose. Switching to none/vehicle
   must remove this decorator result and clear the writer's prior override.

## Full-ground-pose dependency and engine boundary

The source held-gun solver depends on supplied full-body base poses and current
actor/visual hierarchy; it does not require skin vertices. However, original
update calls groundPose AFTER weapon/reload/head for prone or landing. Original
jumpPose calls it before weapon and again after weapon for a dive. groundPose
scans actual full skin and adjusts the shared visual origin. This package returns
the pre-final-ground weapon world frame and explicit flags. Host must own that
final physical floor correction; the attached gun and rig must move together.
This package does not claim to migrate that skin-floor pass.

Additional adversarial supplied matrices preserve source math in the sampler,
including Three's non-orthonormal quaternion decomposition. Godot4.7.2's displayed
Skeleton override is a narrower contract: skeleton_3d.cpp:1152 calls
Transform3D.interpolate_with even at amount=1, and transform_3d.cpp:96–110
decomposes shear. Exact upstream copies are saved in the evidence directory.
Therefore arbitrary affine DISPLAY parity is explicitly FALSE in the report:
max global matrix error 0.0047426 source units under the artificial shear stress.
Stored override matrices remain exact. All 294 ordinary original-source cases
display within 8.38e-7. This is not an engine fix or a blanket full-affine claim.
Upstream: https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/skeleton_3d.cpp
and https://github.com/godotengine/godot/blob/4.7.2-stable/core/math/transform_3d.cpp.

## Validation and cost

35189 checks PASS: 14 guns × 10 modes × 3 aim/reload variants = 420 cases.
Standing, running, crouch, prone, jump, dive, landing and three affine stress
modes. Every local bone matrix, weapon local/world matrix and both palm positions
compared to original JavaScript; actual hero names/rest hierarchy also checked.
Max local error 2.2307615e-5, weapon frame 2.6964824e-6; independent tolerances
3e-5 and 1e-5. Oracle rebuild is byte-identical. Raw hero hash and CRLF-to-LF-only
source hashes are verified by tests (no other source text normalization).

Binding/rest lookup, original hand/head rest rotations and scratch arrays are
cached. No resources, scene searches, skin capture, clocks or per-frame nodes in
the sampler. Work is bounded (28 bones, source16 reach-constraint passes); source
solver fidelity was retained. Final run: 4200 sample measurements across modes,
p50 342–374 microseconds and p95 507–685 microseconds on this shared running host;
an earlier run was 167–180/236–285 microseconds. The spread means these are component
costs, not a clean full-scene before/after FPS acceptance. Root must measure
actual loaded-scene integration; no GPU/full-city performance claim.

Run the oracle builder, then run test_weapon_pose.gd in an isolated headless
project containing this sampler and frozen weapon_visual.gd. Three arguments:
absolute oracle path, report path and repository root. Existing isolated project
is `outputs/coordinator22_weapon_pose/project`; no main autoload or production
project changes are required.

Hashes (SHA256):

- Sampler: `c728d6c875fe1fd4e8812c629c3422a2354ce5409675dee123c41eee272a334b`
- Test: `8ff6baf77fb3349a30ee9bd02982f03f22892bc8576c237bb444d1dcaa525232`
- Oracle builder: `65f04f42446d0eaa78756e1d387bee10a42c252c2d46deecf9a66bbc524fb54b`
- Oracle: `f16adb515a2451416e7ef8398073e527388771c8cb99ec7acb320532b2880a7a`
- Report: `43743ddefa77297cb35d07806894ef36d117e0a4bf71c4c1402d23c671e8f5f2`
