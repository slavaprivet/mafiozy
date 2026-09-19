# Wander collision query deduplication — Artist18

**CPU READY; production scope released. Whole-scene performance and visual LIVE acceptance are not checked.** The living-city task is still unfinished until the shared game visibly behaves correctly.

Only `pickNpcWaypoint` in `world.html` is changed. The existing BFS order, eight-choice early finish, 520-node horizon, persistent frontier, goal reservations, speeds, population, and shared two-admission/four-millisecond CPU budget are preserved. Root's actual elapsed CPU accounting and `finally` release remain intact.

`_npcPathPassable(custom edgePass)` previously checked `_npcRouteWalkBlocked` at five body points, then called `npcWaypointOk` on those same points; `npcWaypointOk` already performs that native obstruction check. The local `wanderEdgePassable` preserves the exact sample positions (step at most .14, centre and four .18 corners) and original `npcWaypointOk` surface/role restrictions, without repeating the native point obstruction gate. The continuous native .18 sweep is retained. Callbacks without an explicit `swept:true` contract still use the original path helper. Point memoization remains local to one admitted slice; runtime collision continues to check movement.

## Validation

- `node test_npc_wander_point_dedup18.mjs`: PASS. 1,152 identical actual city edge/footprint acceptance comparisons; all published paths independently checked end to end. First batch native point queries 836,552 -> 471,038 (-44%). First request issue p50 5.05 -> 4.35 simulated seconds; 259/259 -> 261/261 clear routes. Route planner CPU 1,830 -> 1,621 ms. Reservation publication order varies with real CPU slice timing; boolean geometry equivalence is checked separately.
- `node test_npc_wander_point_dedup_moving18.mjs`: PASS on two runs. 288 actors in actual city geometry, 60 simulated seconds at 20 Hz, 1.8 m/s. Actors physically follow every waypoint and pass actual body/sweep collision each step; after arrival they request another outing. Latest numbers below.
- `node test_npc_wander_continuation.mjs`: PASS, persistent FIFO/frontier, small courtyard, callback/surface invalidation, death/panic/cancel.
- `node test_npc_wander_first_slice_starvation.mjs`: PASS, actual first admission frame 104 versus continuous control 101; old distant case never admitted in 20 seconds.
- `node test_world_walk_melee.mjs`: PASS, inline parse and melee regressions.

| 60-second moving CPU fixture | Existing BFS | Deduplicated BFS |
|---|---:|---:|
| Routes issued / completed outings | 749 / 575 | 825 / 603 |
| Moving actor samples | 55.61% | 61.61% |
| Pending actor samples | 42.02% | 35.52% |
| Planner CPU total | 4,302 ms | 4,141 ms |
| Planner CPU per issued route | 5.74 ms | 5.02 ms |
| Route update CPU p95 | 4.76 ms | 4.75 ms |
| Request latency p50 / p95 | 5.1 / 20.4 s | 4.3 / 17.25 s |
| Movement CPU total | 3,966 ms | 4,438 ms |
| Blocked movement segments | 0 | 0 |

More actual movement naturally costs more movement CPU; this is not a claim of increased overall FPS. Fixture excludes whole AI update, social/commerce/combat systems, streamed railway/other cars, rendering and GPU. Results: `outputs/npc_wander_point_dedup18.json` and `outputs/npc_wander_point_dedup_moving18.json`.

## Rejected experiment and test maintenance

A bounded direct outing with turns reduced first-request latency, but sustained moving A/B did not improve: 716 -> 708 issued routes; CPU/route 6.30 -> 6.45 ms. It was completely removed from production. `outputs/npc_wander_moving18.json` preserves that negative result; it is not the final patch.

Historical `test_npc_wander_early_finish.mjs` originally reconstructed the obsolete endpoint-only baseline using a literal regex of the old edge gate. At root's follow-up request, the extraction now locates the same exact native-edge block and asserts it contains both sweep and path checks before removing it. Accuracy assertions are preserved. Regression PASS: old endpoint-only 265 issued / 163 wholly clear, 282 blocked segments; current early-finish 260 / 260 clear, zero blocked segments. Production was not changed during this follow-up.

## Read-only coarse-grid trap audit

`node test_npc_wander_grid_trap_audit18.mjs` confirms that the coarse 4.1 m grid trap also affects wander, not only directed visits. At actual print shop start `(4.990913843951179,97.94314630350254)` and hospital start `(6.469984627970292,165.137)`, `npcWaypointOk` accepts the actor's location, but all four connections to adjacent coarse cell centres fail continuous sweep. `pickNpcWaypoint` returns no path after one admission and schedules another idle retry.

The diagnostic .25-cell routes found by the separate visit audit are entirely clear under wander's own restrictions and full footprint/sweep: print shop 33/33 segments, hospital 14/14. Thus neither failure proves physical isolation. `outputs/npc_wander_grid_trap_audit18.json` records each neighbour and fine-path result. No fine-resolution wander fix was installed; root owns the next integration decision.
