# Vehicle water matrix traversal — 12 September 2026

Scoped optimization of `vehicle_water_state.mjs`; no fleet, walk, render-batch,
NPC, geometry, material, collision, simulation-rate or population changes.

## Cause and change

The water step updated every descendant of each car twice on dry/shallow ground
and four times during sinking. The engine sampler repeated the full traversal,
although its only consumers are the actual engine vertices. This was additional
CPU matrix work before the renderer's ordinary propagation.

The water step now updates the car root and its ancestors. Engine sampling updates
each engine mesh and its current ancestor chain, covering dirty/deformed mounts,
reparenting and transformed scene parents without trusting stale matrices. The
already-updated root matrix supplies the origin instead of a redundant
`getWorldPosition` update. Engine support indices, exact vertex thresholds,
flooding latch, depth/drag, descent integration, bridge support and reset rules
are unchanged. No cadence reduction or approximate engine bounding box.

Unrelated descendants are updated by their existing on-demand world queries or
normal scene matrix propagation. Tests compare engine matrices immediately,
downstream wheel world queries and every descendant after normal propagation.
This is not a blanket promise that arbitrary raw descendant matrices are fresh
before a consumer requests their update.

## CPU A/B result

Command: `node assets/maps/city_rebuild_v1/test_vehicle_water_matrix_cost.mjs`.
Node v26.1.0 on the shared Windows workstation. Twelve actual authored GLBs, same
moving roots/mounts in both versions; 200 warm-up frames and 600 samples per row,
alternating old/new order each frame. Timed region excludes loads, pose setup,
assertions and counters. The baseline reconstructs only the former full-matrix
calls from current production source, preserving all other current game logic.
Second complete run below; this agent ran no concurrent tests during that run.
Other desktop/game tasks and OS scheduling are not controlled.

All times are milliseconds **for all twelve cars per sample**, not per car.

| Scenario | Water CPU p50 before → after | Water CPU p95 before → after | Water + normal CPU matrix propagation p50 before → after | Corresponding p95 |
| --- | ---: | ---: | ---: | ---: |
| Dry | 0.5689 → 0.0581 | 1.1158 → 0.1113 | 1.0411 → 0.7631 | 1.8679 → 1.1515 |
| Shallow | 0.4999 → 0.0537 | 0.9376 → 0.1093 | 1.0122 → 0.7637 | 1.7445 → 1.1286 |
| Sinking | 1.4015 → 0.1093 | 2.3466 → 0.2010 | 1.9326 → 0.9354 | 2.9322 → 1.4224 |
| Moving, pitch/roll | 0.6150 → 0.0774 | 1.1713 → 0.1490 | 1.1632 → 0.8343 | 2.2572 → 1.3187 |

Water `updateWorldMatrix` node visits per twelve-car sample: 6,602 → 516
dry/shallow/moving; 13,192 → 1,056 sinking. Subsequent normal matrix propagation
remains exactly 3,283 visits in both variants. Timings include a second workload
with that propagation so savings are not reported merely by excluding deferred
matrix work. The normal propagation benchmark is CPU-only, not renderer draw
submission or GPU time.

## Correctness and limits

- Exact A/B parity: 4,320 water steps across all twelve GLBs and all four scenarios;
  1,181,880 full descendant matrices compared. Includes dirty translated/rotated/
  nonuniformly scaled parents, pitch/roll, moving/open hood, displaced and
  reparented mounts, replacement bay/manual local matrix, changed engine vertices
  with version increment, replaced position buffer, fallback core and no engine.
- Existing `test_vehicle_water_state.mjs` PASS: dry/bridge exact NOOP, shallow
  torque/damage composition, continuous sink/terminal limit, permanent latch,
  explicit reset, dt clamp, 30/60/120 Hz stability, all twelve engine thresholds,
  real sedan/fire-engine deep drive with no underwater forward/reverse torque.
- Existing water exit, vapor, walk water hooks, walk vehicle-water hooks and actual
  vehicle/jump water integration tests PASS. Real extracted submerged exit tests
  retain all sedan/fire-engine seats, other-car/static/ceiling rejection and
  continuous ascent (max 0.015 m/frame at 60 Hz).

**Производительность общей сцены не проверена.** No browser/GPU scene was opened
or reloaded by this subtask. No full-frame p50/p95, draw calls, triangles or GPU
times measured. This removes roughly half a millisecond of scoped dry-water CPU
work for this twelve-car fixture; it does not establish that the game's much
larger renderer bottleneck or all user-visible lag is solved. The parent task
coordinates the single-GPU queue and whole-game acceptance.

No server changes, restart, account mutation, commit or push.
