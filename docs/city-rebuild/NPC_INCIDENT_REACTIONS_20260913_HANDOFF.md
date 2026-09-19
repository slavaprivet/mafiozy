# Source incident reactions — Artist 17

`npc_incident_reactions_source.js` is loaded by `world.html` alongside the existing ambulance helper, before the main source script. It contains global source functions; tests that isolate the world functions must also load this file. It does not introduce a server message type, respawn a driver or change a business/police identity.

## Ejected living driver

The vehicle lifecycle owner calls `_npcVehicleHijackReleased(npc,{eventId,carId,playerR,playerC},now)` only after physical extraction. The NPC must be the existing live source object with positive HP when HP is defined. Dead/downed corpses never enter the reaction. Special police/guard/boss combat ownership remains with its existing systems.

One deterministic choice per event selects a prototype 20% attempt to retake the car; the remainder protests and retreats/calls police through the existing witness system. The caller must provide a unique event ID. Duplicate release callbacks do not reroll or restart a finished reaction.

After the brief protest, `_npcVehicleHijackReactionTick` asks the vehicle owner's `_npcVehicleHijackRetake(n,reaction,dt,now)` for `pending` plus an actual driver-door target, `pulling`, `complete` or `unavailable`. It uses native collision-checked walking to approach. The existing fight is started only after actual exit/authority completion and `myDrivingCarId` has cleared; it cannot punch the player through the occupied car. Failed or distant retake attempts retreat and use the existing police witness call. Vehicle ownership and extraction are not implemented by this helper.

Snapshot field: `hijackReaction:{eventId,phase,since,until,carId}`; physical extraction pose takes priority. The animation owner handles protest arms. Corpses receive no reaction snapshot.

## Corpse discovery and ambulance phone call

The discovery pool contains source `NPCS`, the actual dead player emergency patient and beach residents. Nearby living civilian witnesses must pass the existing 140-degree source view cone and actual native LOS, with a .35 m target height for a body. Hearing or generic corpse panic does not authorize an ambulance.

One witness reserves one death incident, stops and displays the existing phone animation for 3.2 seconds. Only completed calls write `_corpseEmsReportAt`, `_corpseEmsIncidentAt` and reporter ID. `_npcCorpseEmsReported(n)` requires matching numeric `deadAt` and a completed report; zero is a valid death time. Death, medical downing, fighting, displacement, removal or evacuation interrupts the call and releases the reservation. No NPC is revived.

The source snapshot's existing `phoneCalling` includes an active EMS phone call. Discovery is limited to eight witnesses per 250 ms, with a once-per-second corpse spatial index and at most 32 local candidates per witness. Active call ticks do not traverse render scenes or use a GPU.

The parent owns the central `spawnAmbulance`/dispatcher report gate and five-minute corpse expiry, including protection for a body being extracted, loaded, carried or transported. Living wounded-patient dispatch remains separate. This helper alone does not claim that those central gates are integrated.

## Checks and limits

- `test_npc_incident_reactions.mjs`: native polygon LOS/source FOV, body behind a wall or behind the witness, dead witness, completed-call gate, reservation dedup, interrupted call, zero-time incident, player/beach pools, silent corpse extraction, stable event choice and retake-before-melee contract — PASS.
- Existing `test_npc_perception.mjs` and `test_civilian_purposeful_plan.mjs` — PASS, including inline source syntax.
- No new GPU scene was opened. Full shared-scene performance and combined LIVE vehicle extraction/retake/EMS arrival remain parent/coordinator acceptance. These unit checks do not prove server ownership transfer or actual vehicle extraction.
