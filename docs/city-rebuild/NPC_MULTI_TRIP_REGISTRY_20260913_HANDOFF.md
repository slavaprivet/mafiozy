# Concurrent civilian trips — first bounded stage

Artist17 / civilian_trips, 13 September 2026. This stage removes the source singleton bottleneck; it does not claim the entire city is populated or LIVE parking admission is validated.

## Source contract

`_civilianTrips` is a Map keyed by the existing source car object, with `_civilianTripByNpc` as a WeakMap index for the original NPC. `_civilianTripForCar`, `_civilianTripForNpc`, `_civilianTripRegister` and `_civilianTripUnregister` provide exact ownership lookup and reject duplicate actors/cars. `_civilianTrip` remains a first-entry compatibility view for older CPU fixtures; production driving, hijack, death handling and NPC snapshots use the indexes.

Native capacity is eight concurrently active full trips, legacy remains one. This is a near/full-simulation work bound for the first stage, not the final desired car population across the world. Admission keeps rotating stable `_threeVehicleEntityId` identities, examines at most two cars per 750 ms and assigns existing eligible NPCs after canceling their previous civilian intent. Each release cleans only its own registry/index entry and `civilian_car` pending work. Death and hijack preserve other active trips. Interrupted hijack restoration registers its exact original trip when capacity permits; existing ambient fallback remains.

All native trip route planners share a FIFO admission queue: at most two admitted planning jobs per source frame with a four-ms admission deadline. The native route service still enforces its own incremental work budget. More active trips do not each independently initiate a full-frame A* budget. Physical driving continues in existing car/NPC updates with the same swept static/dynamic collisions, living-driver checks, traffic controls and source HP/identity.

Diagnostics remain globally bounded to one ordinary write per 500 ms, with per-trip transition history and an active-trip summary. Explicit releases remain immediately visible. Eight actors do not produce eight periodic JSON writes every frame.

## Changed scope

- `civilian_parking_trip_source.js`, exact inline marker in world.
- `npc_vehicle_hijack_source.js`, exact inline marker in world: registry-specific capture/release/restore.
- Exact NPC snapshot mapping in world: vehicle ID/phase/progress resolved by that NPC's registry entry.
- Tests and reports below. No walk renderer, native road planner or model geometry was edited.

## Verification

Existing native/single-trip lifecycle contracts, source hijack bridge tests and all world inline syntax/melee tests PASS.

`test_civilian_multi_trip_registry.mjs`: eight ordinary source admissions with distinct NPC identities, duplicate/cap rejection, max two planner admissions per frame, all eight receive planning work, one death or hijack leaves other trips intact. The performance comparison explicitly asserts the car really moves rather than timing a stalled fast path. Controlled-navigation CPU p50/p95 in ms per update batch:

| Scenario | p50 | p95 |
| --- | ---: | ---: |
| Before, one active car | 0.0078 | 0.0223 |
| After, one active car | 0.0080 | 0.0181 |
| After, eight active cars | 0.0542 | 0.0938 |

Report: `outputs/civilian_multi_trip_registry_20260913.json`. Before source retained at `outputs/civilian_trip_before_multi_20260913.js` for reproducibility. These navigation fixtures are controlled, so these timings isolate source logic and are not loaded-scene FPS.

`test_civilian_multi_trip_actual.mjs`: eight actual compact-sedan GLB profiles, 3673 current static bodies, actual native route planning and swept collisions, actual source registry/TickNpc/TickCar. Eight distinct NPCs simultaneously board, drive and physically exit; all retain ID/HP and selected building intent. Test runs 52 frames, eight simultaneous drivers, p50 0.2545 ms / p95 1.2550 ms per eight-actor update batch including collision callbacks. Report: `outputs/npc_multi_trip_actual_20260913.json`.

The actual test initially stages cars/actors at validated road and door positions; it does not validate LIVE randomized legacy parking, native parking migration, complete building visits, visual skinning or the full rendered city's FPS. **Whole-scene performance is not checked by this agent.** GPU remains with coordinator.

## Pending integration

Await road owner's native initial parking-anchor contract. Existing occupied/visible vehicles have not been teleported or reanchored. The earlier idless admission fix, civilian intent cleanup and bounded LIVE trace are preserved. Full-city density/zone cadence is a separate next stage coordinated by parent; do not interpret capacity eight as the final world population.
