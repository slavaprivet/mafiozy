# Wheel role batching — opt-in candidate, 2026-09-13

Status: implemented and CPU/regression checked; **default-off opt-in integration**
is available in fleet/traffic. No GPU/FPS claim. Existing factory callers preserve
independent legacy materials. Root owns the walk flag and controlled LIVE acceptance.

## Ownership and integration contract

- `createArtistVehicle(T, RoundedBox, source, profile, {wheelRenderOptimization:false})`
  remains default-off. Passing true creates five exact factory-owned material roles
  shared only among the four wheels of this one car. Never share a palette across cars.
- The factory exposes role ownership through private WeakMap bindings, not matching
  colours, names, arbitrary material UUID equivalence, or copied userData.
- Create damage/tyre/crash adapters **after the factory and before wheel batching**.
  Damage captures canonical material references and rest values at construction.
- `createVehicleWheelRenderBatches({THREE,car,multiDraw:false,enabled:true})`
  allocates no batches without explicit `WEBGL_multi_draw` capability admission.
  Fleet/traffic call it only when `wheelRenderOptimization` and the existing
  `detailOptimization` multi-draw capability gate are both true.
- With capability true it creates five batches for twenty ordinary wheel meshes.
  Call `update()` after wheel spin/steer and damage/tyre updates, before rendering.
  Stationary visibility/material/geometry mutations still need this check.
- Fleet creates the helper after all adapters/body batches and updates after
  tyre/crash modifications. Root added the separate active-car walk hook (fleet's
  passive update owns only parked cars). Traffic preserves the old body-batch
  `driveChanged` cadence; the new wheel helper validates every visited enabled
  actor, including stationary external geometry/material changes.
- Traffic forwards the fifth factory argument only when enabled+supported;
  default/unsupported mock factories still receive exactly four arguments.
- Fleet and traffic expose aggregate `wheelRenderBatches` diagnostics. Wheel
  batches are disposed before body batches, damage adapters and source resources;
  traffic replacement/removal has the same teardown ordering.
- `setEnabled(bool)` / `setVehicleWheelRenderOptimization(car.object,bool)` support
  source-vs-batch A/B. Availability cannot be enabled after unsupported construction.
- Dispose the wheel helper before releasing source meshes/materials. It owns only
  its batch geometry/textures and hidden proxy materials, never canonical materials.

## Preserved contracts

Original source geometry, hierarchy, visibility, IDs, raycast and wheel state remain.
Each role instance has its exact car-local matrix; tyre radial deflation includes the
nested tread transform. Tyre visibility hides tyre+tread, not rim/hub/rotor. Full
ancestry snapshots prevent ghost batches after moving a tyre with its nested tread
to another car or to a sibling branch of the same car.

Changed geometry, material replacement, callbacks, shadow flags/layers, negative
determinants, damage markers or ownership changes permanently restore that source.
Canonical material burn remains live. Edited hidden proxies are preserved as caller
owned replacements. Failed construction restores already-masked sources and leaves
another owner's material registration intact.

The shared canonical registry in `vehicle_render_batches.mjs` is used by existing
crash/explosion copying. Every detached mesh retains an independent cloned material.
The new batches are marked both `vehicleRenderBatch` and `vehicleWheelId` so debris,
wheel hit handling and body deformation/contact scanners do not duplicate them.

Current installed-wheel mutators do not apply independent per-wheel tint/heat.
Future wheel-specific recolouring must explicitly replace/clone that wheel material;
direct mutation of a shared role intentionally changes that role across this car.

## CPU evidence

Short interleaved Node measurement, actual twelve artist GLBs, 24 warm-up and 120
samples per mode. No renderer/GPU active. Values are coarse milliseconds for all
twelve cars together, not browser FPS:

| Scenario | Transform-only p50/p95 | Transform + helper p50/p95 |
| --- | ---: | ---: |
| Stationary | 0.0095 / 0.0117 | 0.2145 / 0.2653 |
| Every wheel spinning + changing steer | 0.0126 / 0.0242 | 0.3515 / 0.6937 |

Structural visible draw submissions: 240 source meshes to 60 batches per pass,
potentially 180 fewer calls. Frustum and actual scene pass mix determine LIVE savings.
The benchmark includes material/geometry/ancestry checks and dynamic bounds rebuilds.

## Verification

- `test_vehicle_wheel_render_batches.mjs`: PASS, including real compact-sedan
  default/opt-in material-property and exact vertex/index parity, separate-car
  isolation, raycast parity, world matrix parity, tyre deflation/loss, source child
  visibility, full-chain reparent regressions, all four callbacks, mutation fallback,
  A/B/disposal, partial-construction rollback, actual explosion wheel debris/reset.
- Existing `test_tyre_damage.mjs`, `test_vehicle_damage.mjs`: PASS.
- Existing `test_vehicle_crash_visual.mjs`: 12/12 PASS.
- Existing `test_vehicle_wheels_geometry.mjs`: all 13 vehicles / 52 wheels PASS,
  including reverse/steer/handbrake, wheel-arch clearance, detach and reset.
- `test_vehicle_wheel_batch_integration.mjs`: PASS (default/capability gates,
  factory arity, real traffic lifecycle/profile replacement, stationary mutation
  fallback, fleet update ordering, canonical disposal and diagnostics).
- Existing `test_vehicle_fleet.mjs`: 12/12 PASS. Existing traffic regression
  passes after its front-left access mock receives the seat required by the
  current independent Artist access contract; no production access logic changed.

Next acceptance: independent review, then capability-gated controlled LIVE A/B;
do not enable broadly solely from the structural call count.

## Main walk integration / acceptance readiness

Main added a local unauthenticated perfqa-only `wheelbatched=1` gate, requiring
WEBGL_multi_draw. The fleet factory wrapper opts into palette ownership before
damage captures materials. Traffic receives the same flag; ordinary callers stay
OFF. Active-car wheel batches update after the existing active render-batch update
(after tyre/crash/damage), while the fleet helper covers parked cars. The separate
hold-only `vehicle-wheel-batch-qa` button at 198px toggles only wheel batching and
restores ON on every hold exit. Main lifecycle/source hook tests: 24/24 PASS;
probe/GPU query mock, canonical registry and walk syntax tests also pass.

Coordinator17 received final READY for controlled LIVE after its current shared
reload window. Compare wheel OFF/ON with other settings fixed. Both modes retain
the factory-shared palette; the pair isolates batching, not palette sharing itself.
Source code review and CPU tests do not establish general-scene FPS improvement.

## Controlled LIVE result — remain default OFF

Coordinator17 measured 120 samples per mode at the same held camera [167,2.74,168],
911x920 viewport, 59 residents seen / 20 visible and 19 loaded traffic vehicles.
Wheel batching OFF to ON reduced calls 4841 to 4464 (main 2864 to 2654;
shadow 1977 to 1810). Total triangles stayed exactly 4,389,940, including
1,633,946 shadow triangles. Screenshots matched and the hold was released.

However, render p50/p95 was 91/99.9 to 91.3/101.2 ms and GPU elapsed was
67.61/74.1 to 69.32/77.79 ms. Main submission was 45.6/48.9 to 45/49.2 ms;
shadow submission 14.1/15.5 to 14.5/16.3 ms. Source update remained
10.8/13 to 10.7/12.6 ms with zero errors.

This test establishes fewer calls, NOT a frame-time improvement. Keep the
candidate globally default OFF; do not present its structural savings as an
optimization that resolves the user's lag. ON restoration applies only to the
explicitly opted-in diagnostic session.
