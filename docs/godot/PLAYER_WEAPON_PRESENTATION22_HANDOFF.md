# Player weapon presentation — Coordinator22

Frozen 2026-09-30. Root owns player/main wiring; this package does not edit them.
Component: `godot/mafiozi_walk/scripts/weapons/player_weapon_presentation.gd`.
Test: `godot/mafiozi_walk/scripts/tests/test_player_weapon_presentation.gd`.
Evidence: `outputs/coordinator22_weapon_presentation/{report.json,test.log,freeze.json}`.
Requires the frozen original weapon visuals/catalog and weapon_pose.gd. Inherits
the documented final full-skin ground correction and arbitrary affine DISPLAY
limitations in `WEAPON_POSE22_HANDOFF.md`; neither is silently claimed fixed.

## Root API and order

`configure(actual_player) -> {ok}` after hero and actor_id/life_generation setup.
Caches actual28 names/rest hierarchy, source hand/head frames, normalized scale,
socket_weapon and catalog. Actual source layout fields read: `_visual`,
`_pose_motion`, `_pose_skeleton`, `_source_height`, `model_target_height`,
`_pose_authority`, `_pose_epoch`, `_pose_revision`. No skeleton write is performed.
Binding excludes the current motion transform, so it may occur after locomotion.

`equip(original_id) -> {ok,weapon_id}` lazily instantiates one original model.
`none` frees that visual and clears all pending/muzzle state. Model remains hidden
until its first accepted pose. Unknown IDs reject without replacing an existing
valid visual. First source magazine/drum rest origin is cached for reload IK.
Models inherit actual rig normalization once; no extra yaw or scale is added.

For each accepted player update:

1. `selected = presentation.decorate(selected, aim, posture, phase, gait, epoch)`
   before the hit decorator. Pass the same source phase/gait used by locomotion
   (`_locomotion._phase/_gait` or get_status); no wall-clock approximation. Aim uses
   original names documented by weapon_pose. Failed/denied samples return the
   unchanged base and invalidate visibility/receipt. There is no bone write.
2. Keep `weapon` and `weapon_presentation` keys through the hit decorator. Extend
   root's sole writer affine predicate to `selected.has("melee") or
   selected.has("weapon")`. Write the selected full pose once.
3. If writing succeeds, `presentation.after_pose_applied(selected)`. It accepts
   only the pending serial/equip/epoch and exactly ONE newly accepted revision;
   intervening actor movement, old sample, reentry/lifetime or other writer rejects.
   It reads the CURRENT displayed socket and refreshes a plain Node3D child of the
   rig, applies weapon local transform and source reload parts. It performs no
   Skeleton setter, force-update call, mesh scan or skin capture.
4. `current_muzzle() -> {ok,origin,direction,ejection_origin,weapon_id,pose_epoch,
   pose_revision,equip_generation,sample_serial,actor_id,life_generation}` for the
   actual displayed model. No guessed or last-frame fallback. Direction is source
   weapon +Z. Returned dictionary is caller-owned. Ammo/authority/fire is root-owned.
5. On writer failure or authority change call `invalidate_pose()` immediately.
   On leaving on-foot authority it removes the visual; after return, explicitly
   equip again. On owner/model/lifetime replacement dispose and configure afresh.
   `dispose()` is idempotent and removes nodes/cache/binding. All API is main-thread.

The mount is manually refreshed from get_bone_global_pose(socket_weapon), so it
does not wait for a deferred BoneAttachment update. A current muzzle additionally
checks actor lifetime, exact current rig/actor/motion identity, queued ancestors,
unchanged bind-node transforms/dimensions, pose epoch/revision, socket/world/local
transforms, visibility and actual muzzle/ejection anchors. A changed or hidden
model cannot resurrect a stale receipt by being restored or shown later.

Root must keep the component and call invalidate_pose when ownership changes;
it is deliberately RefCounted with no autonomous process or authority callback.
Configure after actor identity metadata is established. The headless test uses
the CURRENT actual preview_player plus a test-only has(melee) shim to enter its
existing affine writer branch. The production predicate change is still root work.

## Checks and cost

1863 PASS: actual preview_player and imported hero, all14 original models,
standing/running/aim/reload, original magazine extraction, actual socket/muzzle,
no bone writes during decorate, no extra scale, caller receipt mutation,
unapplied/intervening revision, movement between sampling/apply, root movement,
unpublished skeleton change, changed muzzle, hide/show, old equip/sample, none,
vehicle/reentry, lifetime epoch/identity, normalization replacement, queued
intermediate ancestor/owner, dispose/rebind. No main autoload in the test project.

Cache/rest lookup/resource loading occurs once per binding/equip; only one visual
is alive, immutable model resources share the catalog's bounded lazy cache.
No dynamic nodes/resource loads/full-skin capture in the frame path. Measured full
decorate + actual sole writer + after/receipt path (200 samples): p50 291µs,
p95 380µs. Cold original model equip: 2.333–3.095ms each (14). These are isolated
component CPU measurements, not loaded-city FPS. Root must still do coordinated
LIVE validation after wiring. No GPU, production export or Git was used here.

SHA256:

- Component: `be0f7cec49b91b48cd3c76abafb2dbe8820ed4c28b83f3eaf073b2b54e996e58`
- Test: `948e22cdb0d0e068e068c88f634990feee5ad217498b8385afeea6878cb5ef54`
- Report: `a5c17f771caa4cbad1fb2eb044d93a1d3cdfd9a585588cf1a31701d4039ea586`

Rerun using the saved isolated project and its test.gd, passing one absolute
report path. Frozen source/model oracle checks remain in their preceding bundles.
