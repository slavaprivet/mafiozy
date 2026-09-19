# Actual hospital access and source medical handoff — 12 September 2026

## Scope and physical failure

Artist16 npc_damage tested `REBUILD-VISUAL-hospital-001`, actual `hospital_exterior_canon_v2.glb`, correct placement/model offset, `createWindowedBuildingEntry`, all 406 entry collision bodies, other current placement/decor/detention collisions, native terrain/water, ambulance GLB footprint and production native car/pedestrian resolvers.

Initial RED: actual door was clear, but the authored `PAD_HOSPITAL_EXTERIOR_01` / `ROUTE_HOSPITAL_PUBLIC` crossing had no continuous floor support. Only 24 A* nodes were reachable from the entrance. Architect/interior_furnishing repaired the hospital approach in `hospital_public_approach.mjs`; no collision bodies were removed by this task. Old straight-corridor-only destination search was independently inadequate for an entrance requiring a turn.

## Changes

- `npc_service_destinations.mjs`: one reverse, resumable A* searches from actual door toward all physically valid roadside accesses. Radius .18 tile, .08 tile edge samples, .25 tile search grid. Shared nominal 2ms frame budget, resumable between candidates, goal checks and neighbor edges; atomic native queries can overrun the deadline. Maximum 12,000 expanded nodes / 10 tile search radius. Returns `footRoute` and preserves actual door/bay/access. Failure retries after 5 seconds; cached success avoids repeated searches.
- `ambulance_transport.js`: native hospital discharge destination and individual home/depot parking slot are distinct. Depot allocation reserves the common discharge bay. Final vehicle heading is physically swept before discharge; a blocked turn cannot rotate through a car or wall.
- Source `world.html`: hospital-bound loaded vehicle targets the verified discharge bay; empty vehicle targets its home. Arrival begins `hospital_discharge`; medics exit, move the patient along the verified footRoute, and only reaching the actual door completes medical delivery. The two medics follow the route front/back, with live .18-tile body sweeps. A new obstacle stops carrying, regardless of elapsed time. Medics return by the same route, board, and the ambulance drives back to its own depot slot.
- HP1/downed is alive. No healing on pickup, at parking, or on a timer. Dead patients remain dead. Driver/bearer death during hospital transfer interrupts transport and leaves the patient at the actual carried position.
- The source update handles this state before the boarded-crew driving guard and stall watchdog. Root owns snapshot parked/braking presentation integration.

## Verification

`node assets/maps/city_rebuild_v1/test_npc_hospital_actual.mjs`

GREEN with actual assets: door r9.722838259677609 / c164; bay r5.722838259677609 / c164; access r6.442838259677608 / c164. Fourteen route points; 390 radius/body samples dry and unblocked. Native startup with resolver unavailable creates zero vehicles/NPCs, then six actual physically distinct depot bays and eighteen persistent NPC crew members. Discharge bay stays empty of depot cars.

The fixture invokes actual `updateServiceVehicles` and actual source delivery functions. A wall introduced mid-route for 20 simulated seconds leaves patient HP1; after removal, medics reach the real door, patient recovers to35 HP, return and board. A driver casualty interrupts without healing. A corpse reaches the door with HP0/dead preserved. These tests use real geometry; navigation is not a permissive clear stub. The fixture sets a loaded vehicle at its destination to isolate hospital discharge; it does not claim a complete scene-to-hospital LIVE drive.

Also GREEN: `test_npc_service_destinations.mjs` (including bent obstacle detour and failure), `test_ambulance_transport.mjs` (arrival-heading block/rotation regression), `test_ambulance_native_cost.mjs`, and six Python client medical tests (`test_wounded_medical_ui`, `test_player_ambulance_transport.PlayerAmbulanceClientTests`).

## Cost and limitations

Actual hospital bootstrap took 7–8 resumed frames in repeated CPU runs. Latest p50/p95 2.260/2.809ms per search call (nominal2ms work budget, finite geometry-query overshoot). Before neighbor-level yields, an observed p95 reached4.226ms; after yielding between neighbor edges, latest2.809ms. This is a local comparison, not an identical full loaded-scene FPS benchmark.

Full source update during physical transfer, with six fleet vehicles and actual static geometry, latest p50/p95 .043/.244ms. Existing real native driving benchmark: 357 fixed polygon fixtures, legacy mover .00244/.00411ms → full native collision mover .07263/.08015ms. This added cost provides actual full-footprint collision checks.

Machine-readable report: `outputs/npc_actual_hospital_access_20260912.json`.

**Производительность общей сцены не проверена.** No additional GPU/browser was opened; root/coordinator owns queued LIVE acceptance. Generated forest/fences, moving trains/traffic and simultaneous ambulance queueing are not reproduced in this fixture. Runtime rechecks preserve obstacles; a blocked destination waits rather than faking delivery. Existing backend emergency contracts were preserved; static monitor18538 is not authenticated combat/medical acceptance. Prior server test database issue (`no such table characters`) is unchanged and outside this task.
