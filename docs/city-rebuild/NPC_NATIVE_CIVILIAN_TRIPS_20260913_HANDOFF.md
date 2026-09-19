# Native civilian trips — Artist17 scoped implementation

Production owner in this turn: subagent `civilian_trips`. Only `civilian_parking_trip_source.js`, its exact world marker, and the approved one-line ambient drive handoff in `ambient_traffic_driver_source.js` / its marker were edited. Root owns decorative parking-NPC migration and the navigation runtime; `civilian_visits` owns the actual native door list and physical building visit.

## Behavior implemented

- Native parked-car admission no longer requires legacy `PARKING_LOTS` membership. Ownership, emergency/police/gang/convoy, wreck/tow/player restrictions remain. Decorative parking reservations are still respected until root migrates their existing actors.
- One existing source NPC and one existing source car are reserved for a stable trip. `planning → approach → board → drive → parked → exit` preserves identity and HP. The existing single concurrent trip bound remains; ordinary ambient cars outside that trip retain their existing drivers and movement.
- Native destinations use actual `_residentBuildingDoors()`. The first attempt calls the shared `lane-route` service with the building ID. A blocked lane route can use `road-targets` around that same actual entrance and bounded `route`. No second graph, legacy driveway requirement, or direct-position arrival fallback is used in native mode.
- Both vehicle and pedestrian pending work retain their actor, target and request. The old twelve-second schedule reset cannot discard them. Pedestrian planning uses the actual road-capable native pass function with a full body check; the exact car-door endpoint is appended only after a swept final segment passes.
- Moving vehicles require a living, positive-HP, seated source NPC and a ready rendered actor/vehicle binding. Every turn and translation calls the existing full native vehicle sweep; a conservative pedestrian-footprint sweep additionally prevents driving through people. Blocked motion stays stopped and replans to the same building after 1.5 seconds. No teleport or timeout arrival is added.
- Lane controls are queried before reaching their stop distance; reverse segments preserve body heading. Generic native fallback routes do not carry the directed-lane control list, so this is not full traffic-law acceptance.
- Existing seated ordinary ambient drivers can transfer into this same trip lifecycle through `_civilianTripAdoptAmbient`, then physically leave their car and visit. Buses and service vehicles are excluded from this handoff.
- After physical exit, `_residentDoor` and `walk_to_shop`/`doorId`/`tripDestination` remain even if the next pedestrian route is pending. The on-foot visit owner resumes that exact building.
- `html.dataset.civilianTrip` now reports exact phase, pending reason, destination ID, vehicle/NPC positions and waypoint count at most four times a second, instead of serializing every drive tick.

## Checks and limits

`test_civilian_parking_trip.mjs`: PASS existing legacy collision, graph departure/arrival, scheduled continuous boarding/drive/exit/visit and exact live marker equality.

`test_civilian_native_trip_contract.mjs`: PASS stable vehicle pending for 16 seconds, stable pedestrian pending for another 16 seconds, native parking admission, real source boarding state, missing-render-driver stop, zero-HP stop, and retained destination when the building path is pending. This fixture substitutes navigation responses to isolate lifecycle contracts; it is explicitly **not** the actual-city proof.

Parent review found and fixed a separate existing death-order bug: NPC ticking preceded the car's death check, so an interrupted dead passenger could start the physical exit path. Both ticks now release a dead/zero-HP driver before any door movement, preserve exact positions and HP/death flags, and assign no living routine. Six source TickNpc regressions cover dead flag / zero HP in boarding, driving and exiting phases; PASS.

The actual GLB/native full-lifecycle harness is owned by the independent `lifecycle_qa` agent. At this checkpoint it has not completed acceptance. No GPU scene was opened. Heavy CPU profiling was paused at the parent’s request while the central populated-scene FPS profile runs. Therefore **производительность общей сцены не проверена**; no FPS improvement or full trip completion in the user’s game is claimed by this handoff.

## Subsequent actual-source acceptance

Independent QA subsequently ran `test_civilian_native_lifecycle.mjs`; `outputs/npc_civilian_actual_lifecycle_20260913.json` reports **done:true, error:null**. The same source NPC completed all phases in 784 frames: actual sedan boarding 12 frames, 39.0957 m continuous native drive in 170 frames, physical exit 12 frames, real hospital entrance/visible indoor visit for 82 frames, and physical building exit. Pedestrian path planning and movement were the actual source functions, not forced-success substitutions. The actual static city fixture, compact-sedan GLB and authored hospital entry were used. This is CPU integration evidence, not LIVE acceptance of every city establishment or dynamic traffic scenario.

QA measured a cold first lane-route query around 117 ms (graph initialization around 49 ms); repeated warm queries were around 1–2.6 ms. Root then confirmed the actual walk host already calls `cityRoadNavigation.prepare()` during initialization. The fixture's missing prepare step therefore does **not** establish a first-NPC hitch in the actual game. Root/QA own the remaining sequence and shared-scene acceptance. Full populated-scene FPS remains unverified here.


## LIVE follow-up: stable idless admission and bounded trace

LIVE observations supplied by parent: resident53 had an approach plan for local_vehicle22, later the same resident was planning with local_vehicle19. This observation does **not** establish a completed native drive. Parent found an actual fairness bug: source cars often lack `car.id`, while their stable presentation identity is assigned by `_threeVehicleEntityId` through a WeakMap. The admission cursor used `String(car.id)`, so all idless cars compared as `undefined`. Both cursor lookup and assignment now use `_threeVehicleEntityId`. Regression with five idless cars proves rotating admission pairs rather than repeated near-car admission.

Opt-in dataset `civilianTrip` now includes a rolling maximum of eight phase changes/releases and the release snapshot before route/plan cleanup. Refresh is bounded to 500 ms plus explicit release. Debug is enabled by npcqa/npctransportqa/npccombatqa/perfqa in source or same-origin parent URL, or `window.__npcTripDiagnostics=true` in the source. Ordinary output keeps its minimal existing fields.

Trace includes exact NPC/car/door position, current route index/waypoint, pedestrian pending/status, lane versus fallback route stage, result/reason/expanded count, candidate target and retained planning origin. A failed approach records five actual navigation probes once, comparing ordinary collision with ignoring only its own vehicle; it also records whether `_npcAdvanceRoute` advanced the waypoint index before rejection. This can distinguish own-car obstruction from other solids and identify an early waypoint corner cut. No collision is bypassed, no NPC is replaced, and trace does not itself change release/approach behavior.

PASS source contracts, rolling-history bound/no recursive history, idless admission rotation, all world inline syntax and existing melee regression. Exact LIVE cause of local_vehicle22 approach failure remains unproven until a release trace with positions is collected. Full-scene performance was not measured by this agent; no GPU scene was opened.


### LIVE stale civilian intent cleanup

Parent observed resident53 newly assigned to car19 while retaining an ~83-second-old `building_entry` search (zero expansion / no queue owner). Admission had overwritten `_civilianPlan`, but `_clearNpcRoute` did not cancel directed pending work or release a bench seat/reservation. Native and legacy admission now call existing `_civilianPlanCancel` before assigning the trip. Release calls `_cancelNpcDirectedSearch` only when that search belongs to `civilian_car`; another new owner's search, such as `medical_rescue`, is retained.

Regression executes the actual current world `_civilianPlanCancel` and `_cancelNpcDirectedSearch` methods: seated actor with bench reservation and pending building-entry queue becomes a trip actor with the old intent, seat and reservation removed. Own trip search is canceled on release; unrelated rescue pending work survives. PASS, alongside native trip contracts and all world inline syntax. This cleanup preserves existing identity and passability; LIVE driving acceptance still requires a completed observed drive.


### Bounded car22 parking approach reproduction

`test_npc_car22_approach_repro.mjs` recreates the observed legacy parking coordinates using actual compact_sedan GLB clones facing north (source angle -pi/2), real current native static snapshot (3673 bodies), water and actual source approach/path stepping. Three explicit occupancy scenarios are checked: car22 alone, known19+22, all six legacy-grid slots. The full grid is a stress scenario, not a claim of actual LIVE occupancy.

From the earlier observed NPC position r47.325/c38.949, all scenarios reach car22's actual door and clear boarding corridor after 48 × 50 ms fixture steps. From the later r45.775375/c38.53033 position, the NPC body is already intersecting car22 at the start: two body-corner probes toward the car strike the car; ignoring that exact car removes those two blocks. The first approach step is blocked in all three scenarios. There is no route-index corner skip, water, wall or neighbor cause in this compact-sedan reproduction. It proves the late position is invalid for this model, not how LIVE got there; LIVE random model and preceding position mutations remain unknown.

Result: `outputs/npc_car22_approach_repro_20260913.json`. Bounded process ~1.58 s, no GPU or production modifications. Do not weaken the car collision based on this reproduction; collect actual release/history to establish the upstream cause.
