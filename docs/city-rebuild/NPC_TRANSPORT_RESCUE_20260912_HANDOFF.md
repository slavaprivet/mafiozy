# NPC transport and convoy rescue — 12 September 2026

Owner: Artist16, with npc_mobility, npc_damage and npc_perception. Shared files are concurrently owned; do not restore entire world.html or walk_preview.mjs. User requested NPC-only driving, no water/building crossings, ambulance and police transport, multiple detention facilities, and rescuing a friend from a stopped convoy after its driver is killed.

## Integration currently on disk

- `npc_vehicle_navigation.mjs`: current native car footprint, supported water/terrain, indexed static collision and other vehicles; swept motion also covers turning. Source coordinates are tiles r,c, angle atan2(dr,dc), exact presentation vehicle ID. Source callers retain authority over movement. `route` is resumable with a shared 3 ms budget, fair queue and car/origin/shape cache identity. `road-targets` supplies physically clear current-road targets. It does not claim the authored lane/signal plan is integrated.
- `npc_service_destinations.mjs`: actual loaded hospital entry, safe road bay and stretcher corridor; bounded search, no legacy POI substitution. `npc_detention_access.mjs`: actual instance doors, animated clearance, source-authorized opening/closing. Walk refresh invalidates destination/route jobs; pagehide unregisters the resolver.
- Bridge `registerWalkTrafficNavigationResolver`; dispatch modes sweep/default, route, road-targets, driver readiness, hospital, detention-access. Driver readiness requires both real loaded actor and vehicle. Root added source ambulance initialization deferral until the native resolver exists.
- `npc_vehicle_pose.mjs`: actual seat ID and anchor, not all occupants in front_left; male/female passenger and boarding regression pass. Real medical NPCS replace synthetic HP100 scene figures; injury, life state and medic action fields survive snapshots.
- `ambient_traffic_driver_source.js`: existing residents physically approach and board cars/BUS; no live ready driver means stop. Near/far motion and anti-stuck/yield paths are being audited. Orphan gang/special traffic cannot silently drive; content remains. See scoped handoff for current exact limits.
- `ambulance_transport.js`: persistent damageable driver and medics; physical approach/loading/return; actual hospital bay; no watchdog delivery/teleport. Server medical authority was not replaced.
- `police_convoy.py` and source police hooks: staged live custody, canonical server driver and quest vehicle, motion/escort/booking checks, same-crew rescue with distance/LOS/stopped vehicle/dead driver/held interaction. Source only accepts server HP for canonical aliases. Confirmed lethal death remains death, rather than being converted to an early prison sentence. Wiring and lifecycle checks are still being finalized at this checkpoint.
- `MafioziPoliceConvoyRescue` source API owns begin/tick/end and server ACK. Walk E rescue takes priority over ordinary vehicle/building entry, keyup/blur/control release cancels holding; the normal HUD shows the rescue prompt. Client UI alone does not release custody.
- Architecture owner supplied three actual district detention buildings and `detention_destinations.v1.json`: southside, chinatown, iron_harbor. Main police/prison IDs remain. Physical geometry tests pass; convoy LIVE acceptance is separate. Final reported rendering cost is **112 draws per copy**, not the earlier reverted 38. Architect owns these files.
- `npc_contact_ray.mjs`: seated driver's skin can be displaced from its source authority root; broadphase follows the actual head bone, caching identity only. Closed window blocks, opened/fractured window permits head contact, metal door still blocks.

## Evidence so far

Passed root checks: actual source ambient/BUS drivers, native sweep/cache, hospital/detention helper, medical transport, physical fire admission, world melee/inline syntax, male/female real vehicle passenger bones, perception, Python server convoy unit tests and compilation. Source convoy tests are being adjusted alongside final wiring; do not count an intermediate red fixture as a completed pass.

Actual route audit: 373 placement/decor/detention collision bodies, three real GLB vehicle profiles, 12 routes to district stops and hospital road-probe fixture all complete; every edge rechecked. Fairness improves last job's first service from 17 to 3 frames. CPU p95 approximately 3.69 to 3.36 ms per shared route update; an earlier after-run outlier 7.93 ms is recorded. This excludes generated forest/rail/dynamic scene and is not game FPS.

Source admission for 30 cars adds roughly p95 .03–.066 ms before native geometry; medical native sweep fixture costs roughly .094 ms/update p95. Seated skin contact remains roughly 4–6 ms for one real actor/car; broadphase fix does not claim a general speed improvement.

## LIVE and open checks at checkpoint

No new transport LIVE completed yet. GPU queue: covers owner → Coordinator16 V/X/following → Artist16 transport. Artist16 CUA inventory returned tabs=[] and the prior tab2 was not found; user still sees the game in ambient context. Do not close that user game or create uncontrolled parallel GPU scenes. Hidden IAB tabs may continue rendering.

Need actual drive/boarding, ambulance approach/load/arrival, local live convoy handoff/book/release, driver shot through broken glass, and controlled scene performance. Authenticated friend rescue needs a running game backend and two actual participants; static monitor18538 is not that backend. Registry readiness records geometry checks, not authenticated gameplay acceptance.

Special service/fire/tow and initial native spawn admission are still under final audit. Architectural road owner is separately adding lane-route/road-rules based on the authored directed graph; current route/sweep API must remain compatible. Preserve other authors' mercenary, death interruption, renderer freeze, pose continuity, building sizes and vehicle batching hooks.

Scoped reports: NPC_AMBIENT_DRIVER_TRAFFIC_HANDOFF_20260912.md; AMBULANCE_REAL_CREW_20260912_HANDOFF.md; NPC_NATIVE_VEHICLE_ROUTE_AUDIT_20260912.md; NPC_SEATED_DRIVER_CONTACT_20260912_HANDOFF.md. No commit/push/publication performed by Artist16 in this stage.

## Continued verification, 13 September

The checkpoint above is historical. Final server/source convoy contracts and 9 server cases now pass; see `POLICE_CONVOY_CUSTODY_HANDOFF_20260912.md`. Capture validates a live server cop before cuffs/escort, stops server police fire against the detained player, creates the canonical car only after boarding validation, and preserves true death. Same-process reconnect restores custody; process-restart durable convoy persistence is still open. Actual complete getPlayerState regression covers living reconnect and genuine death.

Hospital actual-geometry regression initially exposed an isolated public approach. Architecture fixed the physical ramp in `hospital_public_approach.mjs`: all 406 collision bodies retained, 723 full-capsule placements and 639 surface raycasts pass. Destination helper now uses a bounded foot A* and returns the actual route. Ambulance separates discharge bay from depot slots, carries the patient to the actual door before recovery, returns medics to their seats, then drives home. Actual source update regression: six ambulances / 18 existing damageable crew, obstruction for 20 seconds does not heal, door arrival changes HP1 to35, driver death cancels delivery and dead patients remain dead. See `NPC_ACTUAL_HOSPITAL_ACCESS_20260912_HANDOFF.md`.

Fire/tow and BUS now require live drivers on all motion branches, including siren yielding and service turns. New fire/tow native fleet initialization waits for authored depots: placement contains no real fire_station/junkyard. Architecture/industrial owner was notified; ordinary buildings are not substituted. Existing vehicles are preserved. BUS actual starting position passes current physical footprint. See `NPC_NATIVE_DEPOT_INITIAL_HANDOFF_20260912.md`.

First functional LIVE found and fixed two real source bugs: undefined `kind` in police fleet initialization (actual fleet smoke added), and voluntary surrender overwriting boarded transport with waiting. Root also found navigation invalidated on every unchanged 15-second placement poll; invalidation now occurs only when installing actual changed geometry. Actual refresh regression preserves pending searches on unchanged or failed polls. Exact observed LIVE start/goal passes the 373-body CPU route fixture, but generated environment/dynamic vehicles remain outside that fixture.

LIVE also exposed source-locked hero position moving while camera/support remained at the old location; a scoped fix and regression are in progress. No successful complete transport LIVE or controlled FPS acceptance at this checkpoint. Current temporary QA belongs to Artist16; next functional GPU slot is architecture. User game and cover demo remain open, so measurements cannot be treated as controlled scene comparisons.

Coordinator16 relayed a new user requirement: ordinary civilians have no guns. `npc_civilian_weapon_policy.mjs` now prevents stale weapon/_fightWeapon fallbacks in source and population; ordinary civilian combat stays melee. Protected police, guards, bosses, gangs and armed story roles are preserved. Peaceful mercenary weapon:none does not leak inventory guns. Policy and existing 21 population tests pass. Optimizer separately integrated verified per-actor skeleton sharing; actor independence is preserved and its CPU result is not full-game FPS.
