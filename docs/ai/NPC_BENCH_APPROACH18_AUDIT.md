# NPC bench approach audit — 20 September 2026

Status: APPLIED by root in `world.html`; lifecycle audit agent changed tests/documentation only. Applied mode verifies production without transforming it again.

The static activity scheduler does not explain a city-wide permanent stop: optional activities are bounded to 20 records, conversations and smoking have lower caps, and their source records terminate. The separate ordinary 1.2–3.8 second arrival pause was subsequently removed by root for eligible Walk civilians in v5; deliberate activity rest and legacy 2D timing remain.

An independently reproduced bench failure prevents the visible sitting/reading part of city life:

- `_civilianPlanNext` puts a pedestrian only 0.6 m ahead of the bench center. The normal square body footprint intersects the bench itself at most yaw angles.
- `civilian_bench` still uses the old coarse directed BFS, which accepts cells without verifying every connecting edge. A route can be accepted across the bench collider and repeatedly blocked during movement.
- Merely increasing the approach to 1.25 m remained insufficient: 19/28 endpoints blocked and one accepted route crossed a bench.

Applied production changes the front approach to 1.8 m and routes `civilian_bench` through the existing bounded native A*, preserving the actor's stable `npcWaypointOk` point callback and full body/edge checks. Historical transformer `test_npc_bench_candidate18.mjs::stageNpcBenchApproach` remains for comparison. No road/water bypass or population change. Existing failure blacklist and bench reservation continue to apply.

Verification:

`node test_npc_bench_physical_audit18.mjs`

`node test_npc_bench_obstacle_recovery18.mjs`

Actual city snapshot has 49 benches. A nearby safe coarse start was found for 28. Baseline: 0 accepted bench routes, 21 endpoints fail full body clearance. Candidate: 23 accepted routes, 0 invalid segments, all 23 physically walk to the approach, reserve/sit and release through the actual ordinary source foot branch. Five remaining cases safely refuse; one has an obstructed endpoint. Candidate aggregate route CPU ~98 ms across 28 independent requests; largest cumulative request ~16 ms, spread over existing 4 ms route slices. CPU geometry/behavior only; full-scene performance and GPU not checked.

Visual limitation: `npc_activity_pose.mjs` already interpolates the visual hip to the physical seat over 0.5 seconds and releases over 0.5 seconds. The longer safe approach can make that slide noticeable; requires LIVE inspection, not a claim of final animation quality. NPC source position remains at its safe approach as in the existing seat contract.

Dynamic obstruction regression: after accepting an actual bench route, place the fixture's real compact sedan over the destination. Ordinary walking reaches the obstruction, stays blocked for 11 updates (~1 second), clears the route and replans once. The new native A* refuses the obstructed goal; existing `_failedBenches` stores the bench for 60 seconds and clears `benchId`. Measured 11.6 seconds from start (including walking there), no endless same-bench retry. Therefore an additional recovery candidate is not justified: the applied safe planner plus existing blacklist already recover.
