# Police custody, real drivers and native transport — 2026-09-12

Owner: Artist16 / npc_perception. Shared edits are scoped to police custody/crew/dispatch snapshots in world.html and canonical police_convoy handlers/hooks in mafiozi_bot.py. Native road/geometry resolver, seat rig and detention buildings belong to root/architecture; ordinary traffic and ambulance are separate owners.

## Implemented contract

- `citycop_arrest {capture:true}` is sent at actual cuffing / voluntary cuffed waiting. The existing server contact validator requires a real alive assigned cop, wanted threshold, server proximity and legacy LOS. The new record starts in `escort`: no new vehicle, no player teleport, no jail write. A validated captive is excluded from police targets and shooting. Rejected capture does not suppress aggression.
- Bounded `police_convoy escort` admits prisoner movement (3 source tiles/s, sequence time/corridor/legacy LOS checks). `board` requires a living real guard and a car pose within 1.6 tiles of accepted prisoner position; only then is a canonical quest car created, retaining custody ID and real server cop identity. Client waits for board ACK before moving. Legacy response_vehicle begin remains compatible.
- Transport motion is proposed at 5Hz with token and increasing seq; server validates elapsed time/speed, legacy wall LOS and canonical car blockade. Rejection returns canonical position. Actual driver HP/death comes from ordinary cop_shoot / cop_hit, not claimed client HP.
- All ground service police movement now requires a live seated driver. Boarding/reboarding retain NPC identity and HP, use a 650ms seat transition after reaching the door, and never mark occupants dead. Arrival disembarks the same crew. Return/parking retain the crew. Bank responders exist before departure too.
- Native police use road-targets endpoints, bounded route jobs (100ms polling, one reset per job) and physical sweeps; they do not fall through legacy empty-path arrival/turn movement. Native-not-ready/unsafe start/blocked route stays stopped. Initial native bays use committed district detention road nodes.
- Custody uses committed `detention_destinations.v1.json`, currently the three real district instances. Door `detention-access/open` must report ready before unload/escort/book. Handoff follows actual handoff/intake coordinates using swept physical movement. Removed 2.2/12/26 second escort teleport and missing-crew forced booking fallbacks. No available destination means safe hold.
- Booking occurs only after accepted prisoner position is near trusted intake. DB sentence/wanted reset happens there; replay retains the original end time and retries an unfinished durable write. Detention bounds/reconnect/release use the actual district rather than old island coordinates. Release opens the physical door; it does not teleport to the old island.
- Killing the real guard during foot capture interrupts custody without clearing wanted. Killing a vehicle driver stops the car. An authenticated same-crew friend can approach the canonical car (2.4 tiles + LOS), hold 1.2s and rescue. Server rechecks real driver/vehicle HP, stopped car, ally identity, continuous proximity and nonce. Cached rescue does not repeat effects. Ordinary GTA entry cannot bypass custody.
- True lethal police damage remains durable confirmed death and keeps its respawn owner; removed the old premature jail/wanted reset on lethal cop shots. No synthetic HP0-alive state was introduced. If a living captive later truly dies, the active convoy closes and does not revive them.
- Private `me.npc_convoy` restores transport/escort in the same running WorldSim after reconnect; tokens are sent only to the owner. `me.detention` restores the booked district. Source voluntary holding logic now exits once boarded, fixing the LIVE phase regression that changed transport back to surrender_wait_transport.

## UI / live hooks

`window.MafioziPoliceConvoyRescue.getPrompt()` returns text, canInteract, range, custodyId and carId, or null. `begin()`, `tick(dt)`, `end()` share a deduplicated hold with source E / keyup / blur handlers. Root connects this before native vehicle/building E. The source prompt scan is cached for 200ms; actual begin forces revalidation. Completion is server ACK only.

Local QA: `&npctransportqa=1` shows source buttons “QA: живой конвой” / “QA: поразить водителя”; `&previewprisonconvoy=drive` auto-starts the same physical setup. Uses a native road node 7–16 tiles from a real registry destination, actual source crew and production transport start. No direct booking shortcut. The initial fixture announces an existing studio teleport solely to place the QA camera/player at its start.

Native wrapper API: `window.MafioziPoliceTransportQA.begin()/hitDriver()/state()`.
DOM `data-npc-transport-qa` and `data-preview-prison-convoy`: phase, hp/dead, real driver ID/HP/alive, destination, blocked reason, vehicle/player coordinates, actual moved distance and delivered count.

## Verification

PASS:
- `python test_police_convoy.py` — 9 meaningful server cases: invalid/valid capture, no teleport/car, board distance, walls, real driver death, vehicle blockade, spoof HP ignored, ally/range/hold/replay, registry/book/intake, rearrest, reconnect and true-death interruption.
- `python test_police_convoy_server_wiring.py` — executes actual production WS arrest/capture branch, contact validator, GTA guard and police shooting-loop guards without starting backend. Captured players are not fired on; invalid/unbound players retain ordinary behavior.
- `node test_police_convoy_source.mjs` — actual source driver/ACK/door/escort helpers; ordinary server cop_shoot alias without local HP mutation; voluntary surrender cannot overwrite boarded transport.
- `node test_police_ground_transport.mjs` — actual native pending/route/sweep helpers, solid obstruction, driver death, stable route request, no timeout boarding teleport, identity retained.
- Existing custody contract, foot navigation (12 arrivals, zero overlap), perception, suspicion dispatch, server perception and inline syntax (6 classic scripts) pass. Python compilation passes.

Focused source CPU benchmark, same fixture: baseline attachment p50 ~0.0013ms / p95 ~0.0021ms; attachment + active crew/admission gate p50 ~0.0034ms / p95 ~0.0044ms. Canonical server 16 active convoys / 16 cops: p50 0.0704ms / p95 0.0748ms per tick. These are isolated logic costs, NOT loaded-scene FPS acceptance.

## Explicit limits / next owner acceptance

- Root owns GPU LIVE. Initial run found the voluntary phase overwrite; it is fixed and covered by regression. At handoff, full arrival/driver-hit visual acceptance is still being run by root. Performance of the shared loaded scene is not verified by this subagent.
- No backend restarted and no authenticated two-player session was run here. Friend rescue is production-wired and server-fixture-tested, not claimed as authenticated LIVE-proven.
- Active custody records are in the running WorldSim, not a new durable DB custody table. Reconnect to that same world is restored. Server restart loses an in-transit record; a canonical “custody missing” rejection clears the stale local presentation. This is not crash-durable convoy migration.
- Native world geometry is not available in the Python server. Server motion/escort validates canonical server entities and legacy map LOS; root native client resolver validates current physical geometry. Do not describe this as full native authoritative server vehicle physics.
- Before capture, existing local response-car AI remains source simulation; canonical server identity is bound at validated capture/boarding. Do not claim the entire source service fleet is globally server-simulated.
- Living reconnect waiting uses `ar._serverCaptureLiving=true`, `ar.voluntary=true`; root owns the matching awaiting_pickup rig classification so it stays a living captive rather than a corpse pose.

## Follow-up regression — 2026-09-13

Root adjusted getPlayerState living reconnect and confirmed-death priority. `node test_police_custody_player_state.mjs` executes the complete actual bridge method: a living `_serverCaptureLiving` awaiting_pickup returns cuffing and dead=false; true myDead remains dead in awaiting_pickup/cuffing/escort/transport/booking; old downed presentation remains distinct from healthDead, ordinary death and alive transport retain their behavior, and faction/clothes identity remains until booking. Passed. The previous static custody test was updated to remove its obsolete exact dead-expression expectation and now passes alongside the runtime test. No production code changed in this follow-up; no new performance cost.

## Checkpoint 2026-09-13 — police initial native admission (handoff Artist17)

Owner `/root/npc_perception` completed and released this scope. Current `world.html` helpers: `_policeBayOutsideCustody`, `_policeInitialBayAdmit`, `_policeResponseBays`, `_ensurePoliceResponseFleet`, and the small `spawnPoliceCar` admission/heading/home block. Two legacy QA bay reads also now tolerate no available bay.

Confirmed red before fix by executing actual `_ensurePoliceResponseFleet` in VM: zero bays threw `Cannot read properties of undefined (reading c)`; one bay created three overlapping cars with angle 0 despite its tested angle being PI/2. Production now defers creation when native is unavailable, empty, occupied, or full-footprint blocked. No existing vehicles are relocated. Each new car preserves admitted heading and home; admission checks live source cars/service vehicles and repeats the native whole-body query immediately before push. A conservative 1.25 by .6 tile half-shape is supplied before a rendered actor exists. Staging excludes a 4.5 tile centre buffer around stop/handoff/intake/release segments, preserving at least 3 tiles beyond that conservative body radius. These are roadside service bays, not authored parking lots.

Work bounds: at most 3 destination queries / 12 candidates per destination, 9 distinct cached candidates total, 250ms retry for incomplete fleets and candidate discovery. Full fleet exits before native queries. Actual source tests cover 0/1/3 bays, blocked then available, occupied then available, repeated creation, preserved angle/home, no legacy fallback while native is unready, custody corridor exclusion, real bank-response crew, and repeated-frame query debounce.

Validation: `node test_police_initial_admission.mjs`, `node test_police_ground_transport.mjs`, `node test_police_convoy_source.mjs`, six inline world scripts syntax PASS. Focused partial-fleet deferred-call CPU after: p50 .000478ms / p95 .000818ms (1000 calls/window, 20 warmup +100 measured). This is not loaded-scene FPS or a comparable before/after scene measurement. Root owns LIVE and reported the original empty-bay exception; refreshed LIVE after this patch remains his/Artist17's acceptance step. No GPU or authenticated server run performed here.

Read-only parking audit used current placement + three detention-site data with `createCityParkingPlan`: nearest generated actual bays were approx132m southside,168m chinatown,177m iron_harbor. This base-plan calculation excludes final worker road/decor adjustments and does not prove runtime availability. No new parking adapter or geometry was added. Bank dispatch creation safely returns when no place is admitted; it does not add a new persistent retry queue. A permanently occupied cached roadside candidate remains deferred until cleared; no teleport fallback.
