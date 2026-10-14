# Wet-exit authority candidate handoff

Date: 2026-09-30. Status: **PROOF-ONLY CANDIDATE; NOT ADOPTED BY RUNTIME OR
LOGICAL HOST; GAMEPLAY AUTHORITY PENDING**.

This additive candidate proves the bounded physical wet-exit admission and
movement seam without changing the dry transport path. It cannot release a
seat, change the player owner, grant a collision exception, or certify that an
actor is the authoritative occupant. Its only successful terminal state is
`WET_AUTHORITY_PENDING`.

## Frozen files

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `godot/mafiozi_walk/scripts/transport/candidates/transport_wet_exit_authority.gd` | 28,280 | `e9b017eb9a9c98f23cc896c69c25d229c730cfa73b304509e4d6eb991a48b241` |
| `godot/mafiozi_walk/scripts/tests/test_transport_wet_exit_authority.gd` | 20,728 | `0c276fd4ce00920a2c23c0f15b825dfd2bd4c76b86d09f9a015a8af06fa52e74` |
| `godot/mafiozi_walk/scripts/tests/test_transport_wet_exit_authority_cost.gd` | 3,341 | `72ad623344728d4d1c110f9e8851f24d34d2de472e97217ce174b71c4d3d5fbc` |

The candidate pins and uses the final doorway helper
`fb61223de23c81c4317e2cf934815d9d45182aa2fc0b41d1f8ff5a2d133b03c3`,
frozen surface helper
`cc72286766429bfa9942961bd85f1f26457342a2981d087bbe1af93265c0f200`,
catalog `85614568d1a4b23391618e84e8de250c9b872a9215353734d3f7e1f7638d3e97`,
descriptors `99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a`,
water-exit source `531fc5b01dd1ad6ce2fda5b8aac76688cf5f1888fc4f05610a7ef176c259a860`,
and `car_exit.mjs`
`c89df365c19659e02cd89a5ba75df1a3218808845a8154e0973ce682fb7ee263`.

## API and exact ownership boundary

```gdscript
configure(catalog, authority_epoch,
          water_at, ground_height, planar_allowed,
          own_vehicle_clear, source_motion) -> Dictionary

begin_hold(actor_ref, vehicle_ref, profile_id, seat_id,
           source_clock, actor_body, vehicle_body,
           capsule_adapter, door_ready, expected_epoch) -> Dictionary

advance_hold(token, expected_epoch, pressed, door_ready, source_clock) -> Dictionary
begin_transition(token, expected_epoch, source_clock) -> Dictionary
advance(token, expected_epoch, delta, source_clock) -> Dictionary
cancel(token, expected_epoch, reason = "CANCELLED") -> Dictionary
reset(new_authority_epoch) -> Dictionary
state(token, expected_epoch) -> Dictionary
dispose() -> void
```

`configure` has no permissive defaults. The host must provide actual water,
finite floor, source pedestrian admission, occupied-car clearance, and a
current source motion callback. `source_motion(vehicle, source_clock)` returns
exact vehicle ID, life generation, clock, finite signed `speed`, `yaw`, and
nullable `travel_yaw`. The candidate rejects a receipt from another
vehicle/incarnation/clock and checks yaw against the current native vehicle
forward. It implements source walk launch
with `.45` inherited speed and `.8 m/s` outward velocity, including reverse and
lateral travel. The source X/Z result is mapped once to native `-X/-Z`.

The capsule adapter must implement `bind`, `valid`, `can_occupy`, `begin`,
`advance`, and `dispose`. The test adapter binds the real `PlayerCapsule`, uses
`PhysicsDirectSpaceState3D.intersect_shape`, and moves the real
`CharacterBody3D` with `move_and_collide`. The interface itself is not an
authority credential; a future Runtime integration must instantiate its own
trusted production adapter and must not accept an arbitrary caller object.

The candidate owns only its opaque lease token, monotonic per-actor epoch clock,
0.3 s hold clock, physical
plan, and temporary adapter. It requires the seated collision exception to
already exist and never adds or removes it. All cancellation paths return or
imply `retain_vehicle_owner=true`. The terminal receipt reports
`host_seat_mutated=false` and has no commit method. This receipt is one-shot:
the candidate removes its token and disposes the capsule adapter before return.
It cannot be polled or replayed while waiting for a Host decision.

## Source mechanics retained

- exact 0.3 s hold and 120 ms continuity gap;
- exact 1.9 m then 2.4 m wet doorway order, 25 physical samples, current
  vehicle transform, same canonical seat/door, occupied-car clearance, and
  surface ascent gate;
- `.55 s` release, `.6 s` walk body, `6 m/s²` deceleration and `.1 s` step cap;
- source `movePedestrian` swept steps, 12-point circle, axis slide and blocked
  velocity correction before the actual native capsule move;
- water/floor target and final `body done && grounded && !blocked` gate;
- strict source clocks, strict epoch reset, actor/vehicle ID and life-generation
  checks, instance/world binding, catalog profile/seat identity, one active
  lease per actor, and fail-closed callback results.

A late release obstacle cancels the lease immediately. This prevents a
partially moved actor from resuming a timeline whose release elapsed time has
already advanced. Vehicle, actor, capsule, catalog, surface and owner result
are validated before the one-shot pending receipt is emitted; the lease and
adapter are then disposed, so no later candidate poll exists.

## Verification

Safe runner command:

```powershell
tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_wet_exit_authority.gd -TimeoutSeconds 60
```

Author result: Godot 4.7.2, **42/42 PASS**, exit 0. It covers exact reverse
launch motion with distinct travel yaw, real Jolt capsule admission and late
blocking, actual CharacterBody movement, dry rejection, explicit car-clear
rejection, 2-seat missing rear seat, unknown/foreign profile, source clock,
hold release/gap, reentry clock replay, epoch reset, stale/foreign token,
vehicle incarnation, malformed truthy adapter rows, nullable travel-yaw
fallback, source-motion receipt identity, and one-shot terminal authority
pending. The test also checks all four dry file hashes:

- Runtime `d493809fc33415ca9f0ad2204ad4fb2f458391cdcc80771311d1979f5dc9c04c`
- LogicalHost `5371b8561507d23334b83765d25d2d655033d3bb6f493568ff00868b779ea5ad`
- AccessProvider `325be57c92fca3b83aa884d47577c7e7014553850ee1806166fa67419f5cf830`
- ActorTransition `c9ed1ad7205c74d1131cfda0588f8c862fb1ae6cf64d7b42c83b25f1b0df4c6f`

Separate cost command:

```powershell
tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_wet_exit_authority_cost.gd -TimeoutSeconds 60
```

Author result: **100/100 operations, exit 0**. One isolated `begin_hold` with
actual Jolt capsule probes plus immediate cancel measured block-mean minimum
759.4 µs, true p50 844.3 µs, p95 990.2 µs, maximum 1,448.4 µs. This is a
headless isolated admission cost. It is not a frame, event, loaded-scene, GPU,
or FPS measurement.

## Required Root seam before adoption

Current `transport_logical_host.gd` cannot create a lawful wet claim because
its dry receipt validation requires `support_clear=true`. Runtime/Host need an
internal wet branch that validates the authoritative occupant and current
seat, owns the hold/claim table, instantiates the trusted capsule adapter,
consumes this physical lease, installs the real `swim` or `on_foot` owner, and
only then releases the seat/collision exception. It must consume the one-shot
physical receipt synchronously. A dictionary supplied by a caller cannot
acknowledge that boundary. The duck-typed callbacks and adapter remain
forgeable test interfaces; only a sealed Root-owned production adapter and
source-motion provider can make them trusted.

`IMPORTED_EXISTING` also needs authoritative source acknowledgement before
seat release. Unknown roster aliases remain fail closed; for example,
`city_taxi` must arrive through the existing authoritative
`source_profile_id=compact_sedan` mapping rather than inference.

This package is not a playable water exit, not LIVE-tested, and not evidence of
full-scene performance. No GPU window, Git operation, or existing runtime file
was touched.
