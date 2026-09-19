# Ordinary traffic: real NPC drivers and native motion admission — 2026-09-12

Scope: ambient ordinary `CARS` in native walk. Source helper `assets/maps/city_rebuild_v1/ambient_traffic_driver_source.js` is mirrored exactly at `AMBIENT_TRAFFIC_DRIVER_START/END` in world.html. Root owns native vehicle navigation + bridge + model-ready dispatch. No second vehicle simulation or fake driver objects were introduced.

## Behavior

- One existing eligible nearby resident is assigned at most once per 500ms. Same NPCS object, ID, HP and ordinary damage path remain. The resident walks a checked route to the authored left door and continuously boards through the existing civilian trip access corridor/animation. No teleport to seat.
- Driving waits for completed boarding, living source NPC, and root mode:driver readiness of the loaded shared rig and vehicle. Dead, zero-HP, knocked-out, medically downed, cuffed, missing, or unloaded drivers cannot drive. A dead driver does not receive an automatic replacement.
- Snapshot includes actual civilianTrip riding/car/phase/progress fields, with driver mission priority before ordinary sticky sorting. Cap72 remains. Assigned drivers and their cars are protected from ordinary population/density pruning.
- Native motion is checked BEFORE both near and far LOD movement, with dt limited to0.1s. Swept footprint query checks actual road, buildings, water and other vehicles through root helper. Null readiness stops motion. Native cars bypass legacy offroad teleport/recovery and unchecked gridlock sidesteps.
- Native route requests reuse stable requestId and reset only on first request; pending work resumes under root shared budget. Blocked goals retry with cooldown and a different target. Target candidates still come from source road destinations, while paths/collision use actual native geometry. Ranking scores are computed once per target, including random leisure preferences.
- Player/owned cars, civilian parking trip, gang/convoy and police/emergency models remain in their existing owners' scopes. Root was notified that special-looking ambient CARS need service-owner review.

## Verification

PASS test_ambient_traffic_drivers.mjs uses exact current source helper + actual _npcAdvanceRoute: identity preserved; physical approach/boarding; loaded rig admission; zeroHP/knockout/death/no-driver stop; source swept contract; stable pending route; near/far hook; snapshot priority.
PASS test_npc_vehicle_navigation.mjs: actual root helper water/solid/own-car exclusion, road detour and newly blocked path.
PASS test_civilian_parking_trip.mjs: full existing trip in578 continuous steps and prior ownership/driveway/collision checks.
PASS test_civilian_purposeful_plan.mjs: existing civilian schedules + complete world inline syntax.
PASS test_npc_incoming_threat_and_traffic.js.

## CPU and limits

Source admission did not exist before (0ms additional guard). Same30-car CPU batches,100ticks/window,20warmup+100 measured:
- No-driver stop guard: p50 0.024869ms; p95 0.029760ms per30-car batch.
- Loaded living drivers, readiness + sweep dispatch with geometry stub: p50 0.063194ms; p95 0.065948ms per30-car batch.
These are added source costs, NOT a full before/after updateCars or FPS comparison. Native geometry/planning cost is separate and root-owned. General loaded-scene performance is not verified; GPU slot/LIVE coordinated by root.

Cars with no eligible resident/loaded model or no physically valid road route wait in place. Source destination candidates can be stale; impossible candidates cycle rather than teleport. Existing mechanically stalled cars do not yet have a new animated abandonment policy in this bounded task. Driver rigs share existing seat adapter; current real GLB screenshot/raycast verification is root LIVE scope. Authenticated ownership/server authority and dedicated service behavior are intentionally unchanged.

## Follow-up: every unowned CARS gate, native targets, city bus

The previous special-model exception is now closed at the common updateCars admission gate: every autonomous unowned/nonplayer/nontrip CARS requires an actual mapped living ready driver. Existing orphan police/emergency and gang/convoy cars remain present and stopped. New randomly selected special ambient models are retained as parked vehicles (their model/content is not removed). Gang convoy spawn has no family/crew source identity, so no arbitrary gang NPC is stolen to manufacture a driver. Its autonomous movement is safely stopped pending a real family-owned driver contract. Gang-car shooting is an older vehicle-owned aggression subsystem, not a newly verified NPC gunner.

Ordinary route destinations now come exclusively from root mode:road-targets (actual clear road poses). No legacy road graph or lane offset is used. Pending target/route readiness waits. Exact carCanGo regression confirms native admitted roads remain passable when every legacy MAP tile is a building, while lead-vehicle stopping and legacy-mode road restrictions remain.

City BUS now takes an existing resident through the same physical approach/board/ready mechanism. Temporary snapshot role bus_driver and vehicle identity city_bus bind the shared rig to the actual seat; ordinary HP/death remains on that NPC. Native bus movement uses bounded route requests toward actual clear road poses near successive stops, swept body checks each movement step, and 1.8 source tiles/s with capped dt. No-driver, dead-driver, unavailable model and blocked route all stop it. Arrival is continuous (no final waypoint teleport). Legacy bus motion remains only outside native walk. The initial bus starts six source tiles west of its first stop: it waits there for a driver; it is not teleported to the stop to simplify boarding.

The bus's old ambient waiter/alighting decorative lifecycle still exists. It is not proof that passenger seating/fully physical bus passengers is implemented. Stop candidates near legacy stop coordinates can be inaccessible; the bus then waits/retries rather than entering water/buildings. UI/snapshot role and loaded actual bus seat need root LIVE verification.

The shared civilian door corridor now accepts explicit native land/road surfaces over obsolete legacy building tiles, while retaining physical blockers/depth and prison/arena/lair restrictions. Existing full trip tests still pass.

Additional exact-source tests PASS: bus existing-ID approach/board, wall stop, native route, continuous arrival, driver death stop; no-driver special/convoy gate; no legacy route target dependency; native-vs-legacy carCanGo. Latest30-car source admission CPU p50/p95 0.0239/0.0341ms empty and0.0655/0.0905ms loaded with geometry stub; ordinary run-to-run contention variation is visible. Overall loaded-scene performance remains unverified.

## Follow-up: fire/tow serviceVehicles and native new-car admission

Firetruck/tow are distinct serviceVehicles, not ordinary CARS. Added only those two kinds to existing-resident approach/boarding via cached coordinate proxies. Proxies forward r/c/angle to the same source x/y/angle vehicle; they are not inserted into CARS or rendered as duplicate vehicles. Identity is service_{source.id}; temporary source NPC role firefighter/tow_operator uses the existing snapshot seat fields. NPCS object, HP and damage remain real. No eligible resident, no loaded seat/model, knockout or death stops service movement and work progression.

Only native fire/tow `_vehicleStep` takes the new bounded road-route+swept-footprint branch. Ambulance and police keep their owners' paths. Source fire/tow watchdog scene teleports are blocked; home parking refuses distant coordinate snap and continues returning. Native send-home no longer completes tow removal merely because legacy route construction failed. Existing job/hose/tow ownership logic is retained. Source fire/tow dispatch parking/depot selection still has legacy predicates: unreachable or badly placed preexisting depots can WAIT, and were not relocated in this task.

Two side doors around movement admission were also closed: service siren cannot slide uncrewed CARS; native ordinary car sidestep is swept; service priority yielding requires actual driver for fire/tow and sweeps before shifting the source vehicle. No-driver vehicles remain obstacles rather than being pushed aside automatically.

New spawnCar in native mode now defers before native resolver readiness. Candidates come from actual road-targets near focus, use a conservative whole-vehicle footprint (source halfLength1.3,halfWidth.55), and are separated from existing CARS. This only admits new objects; existing visible cars are never repositioned. Existing initial static cars, BUS initial point and fire/tow depot placement still need authored native initial-placement QA. Some source model/direction selection still uses the legacy road sampler before native placement admission, which can defer a spawn when no source candidate is chosen.

Exact actual-source tests PASS for both fire/tow: existing resident approach/board and correct service ID/role; driver readiness; native blocked footprint; continuous source move/arrival; driver death stop; no watchdog teleport; ambulance/police exclusion. Actual spawnCar test verifies unloaded resolver defer, clear native candidate admission, blocked footprint refusal and no existing-object mutation. Existing traffic/incoming-threat, civilian purposeful/full inline syntax pass.

Added10-service no-driver guard cost,100ticks/window,20warmup+100measured: p50 0.00228ms,p95 0.00329ms per10service batch (before new guard0ms). This is admission CPU only, not routing geometry or full scene FPS. No GPU run.
