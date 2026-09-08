# Per-wheel tyre damage — 2026-09-08

This implements the user's new `/walk` tyre request. Pressure loss and the
60-metre detachment threshold are explicit preview tuning, not claimed copies
of an existing authoritative tyre system. Main game and server remain unchanged.

`createTyreDamage(THREE,car,{groundHeight,onDetach})` returns
`hit(payload)`, `update(carState,dt)`, `effects`, `state`, `stats()`, `reset()`,
`dispose()`. Instantiate after adding the car to its scene.

1. Forward the same weapon `onImpact` payload to `tyres.hit(payload)` alongside
   vehicle HP and glass. It verifies the exact hit object's car and wheel ancestry;
   a body hit, foreign car hit or repeated hit on an already flat tyre does not
   affect another wheel. No proximity approximation is used.
2. Before the real `stepCar`, set `carState.tyreEffects=tyres.effects`. The existing
   physics consumes `speedFactor/frontGrip/rearGrip/pull`, preserving normal
   behavior when absent or all tyres intact.
3. After `stepCar`, call `tyres.update(carState,dt)` before `car.update`, so the
   latter uses the current rolling radius for spoke rotation. Pass the actual
   frame distance returned by `stepCar`, not accumulated odometer distance.
   During any frame without a `stepCar` pass, supply `{...carState,distance:0}`.
4. Reset the tyre adapter alongside vehicle damage; dispose alongside the scene.
   Publish `tyres.stats()` for live QA if useful.

Wheel IDs follow seats: front_left/front_right/rear_left/rear_right (+X is left).
The wheel record now exposes `{id,pivot,wheel,tire,hub,front}`. `wheel` still
contains the rotating metal parts; `tire` is attached directly to its steering
pivot, allowing the pressure deformation to stay vertical instead of rotating
an oval contact patch. Existing `wheel.rotation.x` and front steering APIs remain.

A hit lowers pressure at .7 per second. Worn distance accumulates only from actual
movement after pressure drops below .2; reverse distance also counts. At 60 m the
rubber tyre detaches once and tumbles outward. The rim stays visible and spins
with its .24 m rolling radius. A flat reduces speed and axle grip; asymmetry pulls
the steering toward the damaged side. A bare rim worsens those effects further.
The controller remains the existing flat-map arcade model, without suspension.

Cosmetic loose tyres: at most four, fade/expire in five seconds. Bare-rim sparks:
64 pooled instances, emit only during movement and expire after stopping. These
effects never enter ballistic raycasts. Vehicle damage skips wheel deformation
because this adapter owns it; bullet marks may remain at the exact impact.

`test_tyre_damage.mjs` passes exact per-car/wheel admission, body-hit exclusion,
pressure loss while parked, no idle detachment, reverse wear, one detach event,
real controller speed/pull changes, rim visibility, bounded sparks and reset.
Car drive/seat regression tests also pass. Runtime tyre hookup is still pending
with the coordinator; four-seat/steering/HP/glass hookup was already delivered
separately in `walk_preview.mjs`.
