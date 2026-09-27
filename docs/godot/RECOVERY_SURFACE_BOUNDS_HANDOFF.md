# Recovery skin versus actual box refinement

27 September 2026. Helper frozen SHA256 `23b78c72bdca0a2da64dcd7d4e8e54163299414feb66ae9c9cb489ed6f247c1e`.

## Problem and evidence

Actual mouse-selected kick → TEST_ONLY weak2Z → strong24Z → repeat8X in the native scene repeatedly interrupted standing recovery. Diagnostic driver subclasses preserved actual prewarmed body RIDs, returned unchanged production decisions, and recorded actual collision pairs. The blocker was the car's slightly rotated `NativeVehicleCollision` box, not actor self-collision. In the first recorded rejection skin was already above ground, ruling out existing floor penetration for that step.

Some full world AABBs overlapped the car although every triangle of the actual skin and its continuous interpolated path remained outside a separating car plane. Angular padding and empty world-AABB corners both caused false positives. Temporal subdivision alone did not eliminate all empty-corner cases. Another proposal genuinely penetrated the car by1.299mm, so reducing margins or ignoring the car would be incorrect.

Full diagnostic: `outputs/coordinator21_melee_recovery_diagnostic/DIAGNOSIS.md`; unchanged original native failure: `outputs/coordinator21_melee_liveqa/impact01`. Five diagnostic headless runs reproduced repeated block/resume but eventually recovered; the original native20s timeout was not reproduced exactly. Native visual/performance acceptance remains root-owned.

## New scoped files

- `godot/mafiozi_walk/scripts/character_physics/recovery_surface_bounds.gd`.
- `godot/mafiozi_walk/scripts/tests/test_recovery_surface_bounds.gd`.
- `godot/mafiozi_walk/scripts/tests/fixtures/recovery_surface_bounds.bin`.

The binary fixture is ordinary Godot Variant data from seven actual rejected poses: previous/proposed selections, world frame, actual car box transform/size, support plane, old sweep and independent continuous plane bound. SHA256 `43150a81badb6435cb89e6a5c66b56207c8f555e1780b5d0a2986efe8bacb835`, byte-identical to `outputs/coordinator21_melee_recovery_diagnostic/run05/fixtures.bin`; the test asserts this receipt. No production driver/player/main changes were made by this author. Root separately owns driver integration.

## Exact API and ownership

`configure(prepared_pose: RefCounted) -> bool`: once per live instance, binds the existing actual hero full-skin geometry and existing curvature-bound helper. Requires current8338 rendered source vertices and validates actual mesh/skin/skeleton bindings. The supplied prepared pose must be the host's current configured geometry, not an arbitrary provider. Resource mutations and added descendant meshes invalidate this cache; mesh removal/replacement, changed skeleton path, changed rig version, queued/freed ancestry and changed rig-to-motion transform fail closed. No full tree scan occurs during proof.

`snapshot(selected: Dictionary, world: Transform3D, use_prepared_cache: bool = true) -> Dictionary`: returns an opaque `{valid,id,epoch,owner}` handle; copies the canonical pose and captures all6673 unique prepared skin points. Only the latest two snapshots remain valid. Use false for the previously displayed pose; this computes its skin without modifying the prepared next-pose cache. Use true only immediately after the matching production standing sampler: actual bone-frame equality checks reject stale prepared cache.

`prove_box_separation(previous_handle, next_handle, box_node: CollisionShape3D, margin: float = .001, max_parts: int = 8) -> Dictionary`: returns `{proven,reason,parts,minimum_clearance_m}`. The box must be a live enabled actual BoxShape3D directly under PhysicsBody3D, with finite positive dimensions and a rigid unit transform. Shear/scale and unsupported shapes are not guessed. The two captured world transforms must be exactly equal; epochs must match. Margin cannot be reduced below1mm. Caller still verifies node/resource identity against the actual PhysicsServer shape index/RID/dimensions/transform before and after proof.

`reset()`: discards the two handles and pair-local subdivision cache, retaining configuration.

`dispose()`: disconnects mesh/skin and SceneTree lifetime signals, invalidates configuration and clears caches; idempotent. Configure failures after provisional binding also clean up. Host must call dispose when retiring the driver.

This helper does not modify collisions, query exclusions, actor position, ownership, floor admission or support. It is not an alternative physical collider. Root integration must retain all original checks, prove **every enabled shape of a candidate body** before temporarily excluding that body for the original query, reject unknown/truncated/mutated geometry, and restore query exclusions synchronously. In particular, a compound floor+wall is not exempt because one component is clear.

## Why the geometric proof is conservative

For each actual box axis, project every endpoint skin point into the box's rigid local frame. If all points lie outside one box plane by more than the existing continuous angular-curvature bound plus the original physical margin, that entire skin path is separated on that interval. Every triangle interior is a convex combination of its vertices, so whole-skin halfspace separation also covers triangles spanning different bones. No vertex-only triangle partition is used.

If needed, divide the same canonical local-quaternion shortest-slerp and linear visual-offset path into2,4,8 intervals. Every interval retains the unchanged existing curvature-bound formula. Midpoint skin is cached once per snapshot pair and reused for additional boxes. If an endpoint itself lacks a margin-separated plane, subdivision cannot help and the proof returns false immediately. This early failure removed a measured15.8ms futile refinement in a near-contact fixture. There are at most two endpoint skins and seven cached intermediate skins; no unbounded retries or work queues.

This proof follows the existing clearance interpolation contract. It does not claim to validate arbitrary animation interpolation, changing parent transforms, active balance, a moving obstacle's future path, or source combat admission. Live moving support and obstacles remain checked every driver tick.

## Acceptance and cost

Actual Godot4.7.2 headless test: **71 PASS**, clean log, helper hash unchanged. Results are in `outputs/coordinator21_melee_recovery_diagnostic/surface_bounds_test.json` and `.log`.

- Six of seven actual captured proposals prove clear with unchanged1mm margin.
- Fixture0 correctly rejects: only44µm continuous reference clearance, insufficient for1mm margin. It must not be called a seventh clear case.
- Seven derived TEST_ONLY translated versions independently place actual skin vertices1.299mm inside the captured box; all reject.
- A closer but still separated captured case requires2 intervals: one-interval proof rejects, bounded refinement passes.
- Further cases cover exact parent equality at worldX1000 with5mm displacement, nonfinite bone origin, retained margin, subdivision cap, opaque-handle mutation/eviction, stale prepared cache, preserved next-pose cache, mesh/skeleton/resource mutation, added rendered geometry, queued ancestry and explicit signal cleanup.

Conditional actual-fixture CPU, seven samples (not a stable benchmark): snapshot pair p50/p95 **1.585/1.878ms**; first proof **0.831/1.069ms**; cached repeated proof **0.750/0.943ms**. The two-part refinement case cost **1.685ms** beyond capture. These are conditional costs after broad rejection, not ordinary per-frame additions, hard time caps or whole-scene FPS. Root integration creates snapshots only on the rejected broad path, caps candidate bodies/shapes, and owns loaded-scene/native verification. This author started no GPU process.
