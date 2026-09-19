# Root-mounted fixed-fixture batches — 2026-09-13

## Implemented scope

`vehicle_render_batches.mjs` now permits an exact, root-direct assembled-body
fixture whitelist to bypass only the generic moving-name exclusion:

- `Headlamp_housing_-1/1`
- `Front_bumper_bracket_-1/1`, `Rear_bumper_bracket_-1/1`
- `Rear_corner_lamp_mount_-1/1`
- `Engine_bay_sidewall_-1/1`, `Engine_bay_firewall`

`mesh.parent === root` and `mesh.userData.assembledBody === true` are mandatory.
Existing damagePart, detached, vehicleDoorId and vehicleWheelId guards remain
active. No steering, trunk, rolling wheels, transparent glass, actual lamps or
engine core were added. No material-equivalence grouping was introduced.

Fixture groups use a separate `fixture` key lane, exact existing material UUID,
geometry layout, shadow/layer/render-order settings. They never mix with legacy
or arch members. Every fixture entry is `detail=true`. Existing capability-off
creation allocates none; the existing runtime detail toggle restores source
materials and hides fixture batches. New stats: `fixtureMembers`,
`fixtureBatches`; batch marker: `userData.vehicleFixtureRenderBatch`.

Runtime validation additionally rechecks the exact fixture predicate. This is
necessary for renaming a fixture to an otherwise ordinary allowed body name,
removing assembledBody, or reparenting under a neutral group: those must leave
the fixture lane. Existing fallback preserves original per-part ownership.

## Bounded verification

Command: `node assets/maps/city_rebuild_v1/test_vehicle_fixed_fixture_batches.mjs`

**53 PASS**. One CPU-only run; no WebGL context, browser, GPU or timing loops.
The requested two-minute central-profile pause elapsed before it was run.

Coverage includes creation and runtime exclusions for ownership flags, names,
parent changes, material identity/replacement, geometry layout/replacement and
buffer version, shadows/layers/order, visibility and transform updates,
capability-off, runtime off/on, mutation while off, canonical paint/material
changes, hidden-proxy mutation, source raycasting, separate legacy lane, and
idempotent disposal without disposing original geometries.

All 12 actual GLBs are constructed through the real vehicle factory. The test
uses an in-memory copy of the current helper with only the fixture whitelist
disabled as the preceding draw-path baseline; no baseline production file is
written or replaced. Under two poses with transformed parent and car
pitch/yaw/roll, wheel/steering updates and opening doors, **456,708 world vertices**
are compared to their original source geometry. Tolerance is 3e-5 world units
because BatchedMesh instance matrices use Float32 storage. Original geometry,
material identity, parent, raycast and shadow settings are retained. Fallback=0.

## Structural result (one of each model)

| Models | Fixture members → batches | Saved per main/shadow pass |
| --- | ---: | ---: |
| 11 models other than bus | 10 → 3 each | 7 each |
| City bus | 8 → 2 | 6 |
| Total | **118 → 35** | **83** |

The full 12-car structural census changes from **1397 → 1314 main submissions**
and **1299 → 1216 submissions per shadow pass**, without camera/frustum culling.
This assumes the same multi-draw-capable batch path as the existing helper.
The firewall name is eligible, but layout/single-member grouping may still keep
its mesh unbatched; no geometry-layout guard was weakened to increase coverage.

This is approximately 5.9% fewer main submissions and 6.4% fewer shadow
submissions in this fixture, **not measured frame-time or FPS improvement**.
Central renderer/GPU acceptance remains with main/coordinator.

Main reviewed production guards and independently ran traffic paint regression
(12 GLBs / 13 independent actors, fallback 0), profiler, freeze (20), and shadow
(76,320 sampled points) tests successfully. Traffic diagnostics now aggregate
`fixtureMembers` and `fixtureBatches` to identify the loaded implementation.
Coordinator 17 received READY for one combined reload with its own HUD/roster/
static-house updates. Detail OFF/ON compares all optional detail batches, not
only fixtures; do not attribute that entire result to this whitelist.

## Combined detail LIVE result — Coordinator 17 relay

One game, reload confirmed traffic fixtureMembers 188 / fixtureBatches 56,
activeMembers 2043, fallback 0, traffic 19 / loading 0. Other owners' HUD,
roster and woodland patches also loaded, so no cross-reload causal FPS claim.
Viewport had changed to 549x920; only the new held pair is comparable.

Held detail OFF then ON, 120 samples each, camera [165.777,2.560,167.847],
NPC 56 seen / 16 visible / pending 0, traffic 19 / loading 0:

| Metric | OFF | ON |
| --- | ---: | ---: |
| Render p50 / p95 ms | 74.7 / 86 | 73.8 / 81.4 |
| Interval p50 / p95 ms | 94.2 / 108.4 | 93.6 / 103.2 |
| Main submit p50 / p95 ms | 29.4 / 34.4 | 29.6 / 32.6 |
| Shadow p50 / p95 ms | 25.4 / 29.2 | 25.8 / 30.2 |
| GPU timer p50 / p95 ms | 35.27 / 45.21 | 36.68 / 43.8 |
| Full calls | 3553 | 3289 |
| Main calls | 1570 | 1478 |
| Shadow calls | 1983 | 1811 |
| Main triangles | 1692224 | 1692224 |
| Shadow triangles | 1524879 | 1528407 |

Coordinator reports matching screenshots; hold stayed active, then released by
Escape and optimization left ON. Source failed updates 0. Main geometry count
unchanged; shadow triangles rose by 3528, plausibly from batch-bound granularity
(not independently established). Net 264 fewer calls gave only 0.9 ms median
render improvement. This is NOT a meaningful lag cure and NOT fixture-only gain.
Do not claim GPU median improvement: it worsened in this pair. Traffic remained
1740 calls including 1090 shadow in the sampled census, motivating the separate
default-OFF wheel candidate and further source picking analysis by coordinator.

## Review notes

With explicit follow-up scope, this agent updated the pre-existing
`test_vehicle_render_batches.mjs` blanket Engine-name assertion to allow only
the exact fixture names with `assembledBody === true`, `parent === car.object`
and `includeBody`. Other dynamic-name exclusions remain intact. Added optional
`--no-benchmark` to skip only its 500-update timing loops; skipped timings report
`updateMs: null` rather than a misleading zero.

Final reruns, after central clean A/B completed:

- `node assets/maps/city_rebuild_v1/test_vehicle_render_batches.mjs --no-benchmark`
  — **PASS**, 12 GLBs × 3 batching modes, **6,467,718 compared vertices**, source
  identity/raycast/anchors, moving doors, shadow/layers/order, mutation/detachment
  fallback, and actual SUV crash/explosion debris parity and disposal.
- `node assets/maps/city_rebuild_v1/test_vehicle_fixed_fixture_batches.mjs`
  — **53 PASS**, **456,708 compared vertices**, same 83 saved submissions/pass.

Both exited zero. No timing loops or GPU were run. All other production files,
damage behavior, materials/shaders, and visual model assets were left untouched
by this change.
