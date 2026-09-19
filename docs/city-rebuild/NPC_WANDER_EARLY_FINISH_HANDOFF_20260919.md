# Wander: stop once a real outing is available

Production scope: only `pickNpcWaypoint` in `world.html`. Root's separate pre-admission persistent-search marker is preserved. No directed route, FIFO, traffic, speed, host collision callback or movement changes.

Native wander stops after finding eight currently unoccupied candidates at depth >= 8, at least six tiles from the actor, and respecting the existing previous-origin direction test. That means an early-completed path is at least 32.8 m along the grid, with at least 24.6 m net displacement at the native 4.1 scale. The existing 520-node/depth horizon and short-courtyard fallback remain when there are insufficient choices. Candidate reservations are rechecked on each admitted retained slice. The existing two jobs/four milliseconds budget is unchanged.

Every native BFS edge now also passes the actual continuous .18-tile footprint sweep plus `_npcPathPassable` with the original `npcWaypointOk` surface rules. The first edge starts at the actual actor coordinates, not the tile centre. Exact point samples are memoized only inside one admitted search slice: no cross-frame cache of vehicles, doors or water. Existing runtime movement collision remains live.

## CPU validation

- `node test_npc_wander_continuation.mjs`: PASS, historical lost-frontier stall still reproduced; two retained owners finish in 61 synthetic frames; short courtyard, resolver/surface invalidation, cancellation, panic and death pass.
- `node test_npc_wander_first_slice_starvation.mjs`: PASS, root's distant first-admission fix survives; 104 frames against 101-frame continuously updated control with 200 older requests.
- `node test_npc_wander_early_finish.mjs`: PASS, 288 simultaneous wander requests. Early-finish A/B disables only the candidate threshold, retaining exact edges and the current FIFO marker. A third historical baseline removes the new exact-edge gate. Native fixture includes non-centred initial positions. Every published new route is checked end to end using actual execution footprint collision.
- `node assets/maps/city_rebuild_v1/test_npc_native_cadence_movement.mjs`: PASS. Exact thin-obstacle collision still blocks both 60 Hz and 250 ms movement; 288-actor elapsed movement regression passes.

Synthetic 0.02 ms waypoint predicate, simple edge callback: 292,938 -> 92,809 predicate calls; route completion p95 25.67 -> 8.15 simulated seconds; all 288 routes finish, unique goals/direction/long-distance/wall constraints pass. Per-frame test CPU p95 1.59 -> 1.24 ms; simulated frames drop 1,547 -> 496. This is not a frame-rate benchmark.

Actual CPU geometry fixture (3,674 static bodies, one loaded hospital, native water, one actual car; no GPU), 40 simulated seconds with real retry cooldown respected:

| Planner | Published / actually clear whole paths | Invalid segments | Issue p95 | CPU p95 | Total planner CPU |
| --- | --- | --- | --- | --- | --- |
| Old endpoint-only, full horizon | 265 / 163 | 282 / 2815 | 2.30 s | 1.30 ms | 747 ms |
| Exact edges, full horizon | 252 / 252 | 0 / 2633 | 8.38 s | 4.64 ms | 7190 ms |
| Exact edges, early finish | 263 / 263 | 0 / 2280 | 6.93 s | 4.60 ms | 2998 ms |

Early finish reduces the exact-edge predicate count 1,654,162 -> 633,331 and total CPU by 58%. It produces 100 more genuinely traversable whole paths than the old endpoint-only planner. Correct collision has a real cost relative to the old incorrect planner; it consumes the existing bounded work window instead of raising that budget. Atomic edge checks can slightly overrun the nominal 4 ms window. The remaining 25 crowded/disconnected origins are not claimed solved. Counts vary slightly across repeated real-time slice runs because publication order changes goal reservations; zero invalid segments remains asserted.

## Limits

The previous cell-endpoint defect is fixed by the exact-edge gate. Dynamic obstacles can still invalidate a retained route later, so live execution collision is intentionally retained. Root separately owns correction of premature intermediate-waypoint arrival, which could cut a corner despite valid grid edges; this planner test does not claim to validate that movement-follower change.

Results: `outputs/npc_wander_early_finish_20260919.json`. Whole loaded-scene performance and visual LIVE acceptance are not checked by this CPU-only agent; parent coordinates the single gameplay tab.
