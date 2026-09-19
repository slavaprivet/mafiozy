# NPC movement and authored vehicle access — 12 September 2026

Artist16 scoped mobility work. Source world retains NPC/car identity, ownership, trip state and route authority. No second traffic loop or player fleet insertion. Existing `npc_population` pose-clock correction is untouched.

## Applied

- `civilian_parking_trip_source.js` and its identical `CIVILIAN_PARKING_TRIP` block in `world.html`: actual native front-left outside/driver anchors replace guessed .85-tile door and car-centre seat. Unloaded native models defer scheduling. Source boarding and exit advance continuously with dt capped .1; each short step checks five body points against native buildings, terrain, water and other cars. Only the occupied car is ignored inside this specific door passage. A blocked exit leaves the rider seated. Dead drivers stop their source trip.
- `npc_vehicle_access.mjs`: reusable per-actor anchor record, no matrix-tree traversal. Outside anchor additionally clears the source .18-tile pedestrian radius; merely using the hero handle distance could leave the path endpoint overlapping its car.
- `npc_native_navigation.mjs`: optional `ignoreVehicleId` reaches dynamic collision and is included in the frame cache key. Ordinary paths have no exclusion. `walk_preview` registers/unregisters the access resolver; existing traffic blocker already supports the corresponding `ignoreId`.
- `world_traffic_presentation.setNpcAccess`: animates only the driver door and refreshes its geometry batches only when opening changes. It does not modify traffic position, vehicle ownership or physics. Snapshot `civilianTripProgress` plus `npc_vehicle_pose` provide fold/reach during boarding and exit; the source root is preserved rather than snapped to the seat from the first frame.
- Driving now checks the actual native water and solids at its swept footprint at runtime as well as existing source-map/traffic/rail constraints. A source road drawn through a new obstacle no longer grants permission to cross it.
- Bus audit/fix in `world.html`: leaving waiters still count toward the existing two-per-stop population; a departed or different-stop bus stops being their moving target. Existing people remain in place and wait for the next bus. Alighted pedestrians are bounded to two per stop globally before spawning replacements, preventing blocked exits from accumulating without limit. Their stable IDs and pedestrian collision checks remain; `_busRiders` are not seated passengers.

## Tests and cost

PASS `test_npc_vehicle_access`, `test_civilian_parking_trip`, `test_npc_traffic_binding`, `test_world_traffic_presentation`, `test_npc_native_navigation`, `test_npc_native_water`, `test_npc_bus_foot`, `test_npc_bus_lifecycle`, `test_npc_bus_identity`; walk syntax PASS.

The complete existing source parking-to-shop trip still completes in 578 continuous steps in its fixture. Real compact-sedan and both actual hero GLBs match every bone of native `poseOccupant` at progress 0/.25/.5/.75/1 for both entry and exit; authority roots remain unchanged. A blocked door, new car obstacle, water, and a long frame cannot skip the checked passage. Five native probes maximum per capped door step. Unchanged door amounts cause zero repeated mesh rescans over 120 calls. The bus test runs 500 blocked arrivals without growing waiters beyond two or alighted people beyond the cap.

CPU microbenchmark `benchmark_npc_trip_access.mjs`: one active source driver on the same flat native fixture, 200 updates/window, 20 warmup and 120 measured windows. Before runtime native checks: p50 .02333 ms / p95 .02659 ms per update. After: .03595 / .04036 ms. Added .01262/.01377 ms pays for the missing physical checks, bounded to 18 probes in this one-step scenario; there is only one source civilian trip. This is not a full-scene FPS measurement. The baseline was saved before edits in the task temp directory; the benchmark accepts its path as argument, current source by default.

**Производительность общей сцены не проверена.** Root owns the single coordinated LIVE run; no GPU scene opened here.

## Limits / next acceptance

- Verify real native entry, door clearance, drive, stopping and exit in the loaded game. CPU evidence is not visual acceptance, nor an authenticated server contract.
- The planner still uses the existing source road graph/parking lots; native runtime collision can safely stop a trip whose source route conflicts with a new structure. This does not yet guarantee a new route around every new map obstacle or a completed shop/interior visit.
- Existing native-water tests pass: ordinary residents avoid water and return physically along non-increasing depth with bounded resumable search. Special boss/crew/guard and separate police loops are excluded by the existing generic water-egress helper; expanding their behavior needs their existing combat/mission state preserved. Water rendering already drives the NPC swimming pose from depth; this patch does not replace it.
- Existing authority interruption (hijack/tow/new owner) immediately releases the civilian trip. Complete presentation of contested ejection is not newly implemented here.
- Existing synthetic bus boarding/disembark simulation is not a fully seated, persistent bus-occupant transport model. The patch prevents chasing and unbounded accumulation without claiming that migration.

## Follow-up: special local actors in water

Root requested extending existing physical egress to excluded families. `npc_native_water_source.js` / its exact live world block now includes native-mode local boss, crew, guard, gang and unique actors. Their mission/action/identity objects remain; only locomotion pauses for the same depth-monotonic escape and resumes on dry land. The empire stuck-route watcher is paused during swimming so it does not classify the shore return as a failed land route. Dead, hospitalized/downed/stunned/cuffed, interior, carried and vehicle actors remain controlled by their existing owners.

Local `cityCops` get `_npcPoliceWaterEscape` before their old body-recovery call. It reuses the actual cop object/search queue via temporary r/c aliases, updates y/x continuously and restores those aliases; patrol tx/ty and case/vehicle references remain intact. Custody and scripted boarding/disembark/return phases keep their existing authority. The old `_recoverPoliceFootCop` refuses water relocation in native mode, eliminating its near-shore snap. This hook was coordinated with the perception agent; no perception function changed.

Extended actual-source tests cover all six special flags, protected lifecycle/vehicle/interior phases, local police y/x shore return, unchanged orders/IDs/tx/ty, finite gait, ordinary-route water refusal, and normalized deep-water snapshots. Existing actual-GLB NPC actor swim-enter/swim-leave test, police foot navigation and murder custody transport pass. Existing 4-ms resumed search remains; previous 22-slice budget test passes unchanged.

CPU benchmark for 72 dry local special actors: prior excluded path p50 .000699 ms / p95 .002919 ms per whole batch; depth-aware path .076392 / .086189 ms. This added <.09 ms per 72-actor fixture batch is the cost of one physical depth query each; searches occur only in water and retain the shared bounded budget. `benchmark_npc_water_roles.mjs` accepts the prior source path. **Производительность общей сцены не проверена.** No GPU tab opened.

Authoritative `worldCops` are different: server `applyCopsTargets` feeds `interpWorldNpcs`. They were deliberately not moved by client-side water AI, which would conflict with the next server snapshot. They receive depth-based swimming presentation; authoritative shore routes need the server's navigation contract. The current shore search is bounded to the existing 12-tile radius and non-increasing straight segments; it safely waits when no such shore exists instead of teleporting or pretending a route succeeded. Protected transport/custody behavior is not overridden to invent a rescue sequence.

## Follow-up: obsolete source walls in native streets

Root LIVE found the QA target could not find valid ground near the player's visible road. Source pedestrian predicates checked both real native solids and the old `MAP`/`isBlockedPed`, so moved/removed source buildings could remain phantom walls. Added explicit native `surface: land|road` to registered navigation results and actual walk topology/terrain bounds in the native callback. Only this explicit authoritative surface can replace obsolete source masks; generic veto-only resolvers retain the old fallback.

`npcPassable`, `npcPassableForSnitch`, `npcWaypointOk`, unique-city, empire-order and police-crew predicates retain their prison/arena/lair/beach/pit rules. Ordinary residents/unique city NPCs still cannot choose road targets; witnesses/police/ordered empire actors preserve their existing road permissions. Current buildings, cars, water and terrain bounds always block. `npccombatqa` on a road still needs an ordinary lawful sidewalk spawn; the mobility patch does not bypass the spawn gate.

`test_npc_native_surface_authority` runs the actual source functions with actual native resolver: old MAP1/old collider + real land allowed; current wall/car/water/unknown terrain/restricted zones denied; road policy preserved and legacy fallback unchanged. Native scene, initial placement, route fairness/resume, fixed 4-ms budget, purposeful plans, full parking trip and police foot tests pass. Real scene CPU fixture: 8813 samples in44.97ms; native placement32/32 in5 slices, max continuation2.04ms; shore search1.68ms. These are fixture timings, not before/after loaded-game performance; root owns the LIVE comparison.
