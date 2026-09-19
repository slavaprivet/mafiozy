# NPC source hijack and native vehicle control — 13 September 2026

Owner: Artist17 / civilian_trips. Shared source only; host rendering, E bindings and snapshot wiring belong to parent Artist17.

## Implemented source behavior

The existing `_threeVehicleEntrySequence` now performs native door approach, opening, physical driver extraction and physical player boarding. It uses the actual native seat/door resolver and source swept body passability. Blocked corridors wait; elapsed time cannot grant arrival. The original NPC object, ID, look, HP and death timestamp remain intact. No replacement driver is spawned in the native branch. Dead occupants retain `_vehicleCorpseSeat` until physical extraction; `_deathR/_deathC` follow the body, without changing `deadAt`. Before extraction begins, an interrupted living occupant gets its existing driver binding back; a corpse stays seated.

After actual extraction, `_npcVehicleHijackReleased(npc,event,now)` invokes the incident agent's response once. Source `_npcVehicleHijackRetake` supplies a real door approach target, then physically extracts the player. It reports completion only after the existing server exit ACK (or actual local preview completion); a failed server reply does not transfer ownership to the NPC. Reaction/fight timing belongs to `npc_incident_reactions_source.js`.

Stopped driver and supported front-right passenger exits now pass through their actual door before the old `exitCar` action. Legacy moving-passenger behavior remains. Source player synchronization and existing driving position writes respect the active native transition.

## Bridge contract

- `getWalkVehicleState()` returns actual source state. External `sourceCarId` and `presentationCarId` use presentation keys such as `quest_ID`; `canonicalCarId` is the backend ID. Phase is `driving`, `foot`, or an active transition phase. Vehicle input is not a pose override.
- `getWalkVehicleAccess({carId,requestId})` returns seats, permissions, speed in metres per second, and matching top-level `accepted/pending/requestId/seatId` receipts.
- `performWalkVehicleAction({action,carId,seatId,requestId})` delegates to the existing action pipeline. Enter and exit are supported. Pose-based `drive` is refused; use `setWalkVehicleInput`.
- `setWalkVehicleInput({forward,back,left,right,handbrake})` applies only for the actual driver. A 300 ms watchdog clears stale forwarded input.
- Native non-helicopter control uses W throttle, S brake then reverse, and A/D steering. Steering reverses while reversing and cannot rotate a stopped car. The existing source acceleration, drift, collision and server movement pipeline remain authoritative. Legacy isometric and helicopter input remain on their previous branch.
- Current server passenger capacity is one. Rear seat entry is explicitly unavailable; this does not claim four authenticated passenger seats.
- Original traffic and provisional quest aliases remain explicit through actual canonical ACK remapping. Receipt source ID stays equal to the caller's requested key.

## Files

- `assets/maps/city_rebuild_v1/npc_vehicle_hijack_source.js`, mirrored exactly at `NPC_VEHICLE_HIJACK` markers in `world.html`.
- Scoped world hooks: existing entry/exit/hijack replies, player sync locks, once-per-update transition tick, bridge API, native non-heli control branch, and exact car identity on claim ACK.
- Occupant retention hooks in `ambient_traffic_driver_source.js` and `civilian_parking_trip_source.js`, with matching inline markers.
- `assets/maps/city_rebuild_v1/test_npc_vehicle_hijack_source.mjs`.

## Verification and limits

PASS source live/dead identity and HP/death-clock preservation, continuous extraction, blocked corridor/resume, no far-side teleport, counter-retake ACK/rejection, supported passenger physical exit, interrupted pre-pull driver restoration. PASS actual `createWorldVehiclePlayerAccess` + source facade/entry function VM sequence through remap, driving keys and exit. PASS actual source velocity block for heading-independent W throttle, S brake/reverse, forward/reverse steering and metre/second access speed. PASS `test_civilian_native_trip_contract.mjs` and `test_world_walk_melee.mjs` including all world inline syntax.

Bounded VM CPU measurement of native input plus existing velocity block (20 batches × 500 calls): p50 0.00385 ms/update, p95 0.00616 ms/update. This is not a before/after loaded-scene comparison. **Whole-scene performance and visual acceptance were not checked here; parent/coordinator owns the sole LIVE/GPU session.** Collision tests in this hijack suite use controlled source fixtures, not the full city static mesh. Earlier actual native hospital civilian lifecycle acceptance is documented separately.

The server agent implemented optional validated nested `carPose:{x,y,ang}`; this source sends it alongside legacy top-level x/y/ang. See `CIVILIAN_HIJACK_SERVER_POSE_20260913_HANDOFF.md`. No authenticated backend restart or authenticated live claim/exit was performed by this source agent.


## Follow-up: actual native player-car collision acceptance

`node assets/maps/city_rebuild_v1/test_player_hijacked_vehicle_collision.mjs` PASS. The test executes the current production `_playerVehicleFootprintClear` with an actual `quest_after-hijack` sedan actor, production native vehicle access resolver and production `createNpcVehicleNavigation` sweep. It loads the real compact_sedan GLB, real hospital GLB, current snapshot's 3673 static bodies, mapped native water and a second actor cloned from that sedan geometry/profile. No collision success stub is used.

- A 0.615 m step along an actual mapped road passes.
- A swept approach from a clear pose into the real hospital wall is refused (`solid-or-surface`).
- An approach from dry admissible ground to mapped water of depth 1.665 m is refused (`solid-or-surface`: the existing surface guard rejects it before the separate water-depth guard).
- Driving through another sedan is refused (`vehicle`); the far endpoint independently fits when the intervening car is absent.
- A rotation from 0 to pi is refused (`vehicle`) although both endpoint silhouettes individually fit with the second sedan present. The source car's mutable angle is already pi, while `_nativeDriveFrameFrom.angle` is 0: the test verifies the original frame pose is forwarded to the full sweep.

Bounded execution: 67 pose checks, approximately 1.63 seconds for process + assets + assertions. Report: `outputs/player_hijacked_vehicle_collision_20260913.json`. This closes the earlier controlled-fixture gap for the footprint/sweep boundary only. It does not run the full driving update, server claim/physics, streamed railway, rendered scene, or FPS comparison. Production files were not changed during this follow-up.
