# Transport water exit surface

Additive source-parity provider for the submerged part of vehicle exit. It does not replace the frozen dry access/transition providers and is not wired into Root, player, swimming, vehicle physics or LIVE.

## Frozen inputs

- `assets/maps/city_rebuild_v1/vehicle_water_exit.mjs` SHA `531fc5b01dd1ad6ce2fda5b8aac76688cf5f1888fc4f05610a7ef176c259a860`: `canAscendFromVehicle` and `createVehicleWaterExitSurface`.
- `assets/maps/city_rebuild_v1/walk_preview.mjs` SHA `e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47`: Root chooses water versus dry, advances the exit body and calls `finishExit` only after body completion and `grounded && !blocked`.
- Existing dry seams remain `transport_access_provider.gd` SHA `325be57c92fca3b83aa884d47577c7e7014553850ee1806166fa67419f5cf830` and `transport_actor_transition.gd` SHA `c9ed1ad7205c74d1131cfda0588f8c862fb1ae6cf64d7b42c83b25f1b0df4c6f`.

## API and behavior

`transport_water_exit_surface.gd` exports the pinned source constants and:

- `can_ascend_from_vehicle(position, water_at, can_occupy, body_height=1.1) -> bool`
- `configure(position, ground_height, water_at, can_occupy, rise_speed=.9, body_height=1.1) -> Dictionary`
- `update(x, z, dt) -> Dictionary`
- `floor_height(x, z)`, `state()`, and `dispose()`

The helper retains the exact source step sizes: inclusive ascent probes every at most 0.12 m, horizontal sweep every at most 0.12 m, vertical movement every at most 0.08 m, water target `max(floor, level-.05)`, rise speed 0.9 m/s, and `dt` cap 0.1 s. A failed horizontal step keeps the last accepted X/Z. A failed vertical step keeps the last accepted Y. `blocked` and `grounded` may both be true; the host must require `grounded && !blocked`. Dry continuation targets the finite floor and can descend, as the source does. With stable water/floor, an admitted submerged ascent never moves downward. The exact source update can descend when its sampled target later falls; this provider deliberately preserves that rule.

Configuration and updates fail closed. An invalid update, nonfinite floor, or non-boolean occupancy result leaves committed state unchanged. An invalid water sample intentionally becomes dry/null, matching source, so the same update may then descend toward the floor. Returned state is a defensive copy. `dispose()` invalidates callbacks and state. Providers remain host-owned: `water_at(x,z)` supplies `{depth,level}`, `ground_height(x,z,current_y)` supplies a finite floor, and `can_occupy(position,body_height)` supplies the real capsule/solid-world result with only the occupied vehicle excluded during its own doorway crossing. Matching JavaScript exactly, water requires `depth > 0` and a finite level; positive infinite depth is accepted, while NaN, negative infinity and zero are rejected.

## Verification

Godot 4.7.2 headless: 21/21 PASS. The fixture pins both source hashes, checks lifecycle and transactional failures, positive infinite and NaN depth edges with finite level, the inclusive 43-probe ascent case, exact step counts, `dt=0` and `dt=.1`, dry descent, finish-ready flags, no downward submerged motion, settled benchmark precondition, and a host-supplied test predicate backed by `PhysicsDirectSpaceState3D` capsule queries for ceiling and horizontal wall blockers. The test capsule proves the provider seam against actual Godot physics; it is not a claim that its dimensions already match Root's player collider.

Bounded isolated cost uses the host-supplied Godot capsule predicate on every occupancy step. It measures separate 2,000-update scenarios, 100 calls per block: a state warmed until `grounded && !blocked`, and active ascent with a fresh deep start for every block. p50 is the median of 20 sorted block means and p95 is nearest-rank sample 19. Exact numbers are pinned in the manifest. These are provider costs in the headless fixture, not loaded-scene FPS, Root player-collider parity or LIVE evidence.

## Root seam and limits

Root must select this provider only from its authoritative water test, bind real collision callbacks, move the existing exit body, and finish only after the source body is done plus `grounded && !blocked`. The native API is positional and result-wrapped: `update(x,z,dt)` returns `{ok,state,...}` and `floor_height` returns `{ok,floor_y}`. A Root adapter must unwrap success or abort; these methods cannot be passed directly as the source object/numeric callables used by tumble pose. Root also owns switching to swimming and all player/seat/door state. Vehicle physics owns the exclusion/body pose. This component grants no seat, door, HP, authority or clock state. There is no LIVE/swim adoption claim and no visible game update.
