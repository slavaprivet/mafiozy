# Vehicle contact -> crash authority gaps

Status: **BLOCKED FOR RUNTIME WIRING**. This is a read-only audit receipt. It does
not authorize a direct call from `vehicle_contact_state_bridge.gd` to
`vehicle_crash_solver.gd`. No crash-contact adapter should be implemented until
the coherent observation and authority fields listed below exist.

## Pinned evidence

| File | SHA-256 | Relevant lines |
| --- | --- | --- |
| `assets/maps/city_rebuild_v1/vehicle_contact.mjs` | `668e776961d474e6a2bceb62f6435027b859f926b819c0f77da5f4bb0afd4020` | 1-2, 17-18, 25-38 |
| `assets/maps/city_rebuild_v1/vehicle_contact_motion.mjs` | `aa787eb0fef14df3e9324b797c263195e4cf943b594f7d0b3c1a1569164f63ff` | 42-65 |
| `assets/maps/city_rebuild_v1/vehicle_pair_impulse.mjs` | `544a6a3c0d3b406ada6f60d38084e3e9ace488e12e7b404e2d9ea75bbb2abbe1` | 1-34 |
| `assets/maps/city_rebuild_v1/vehicle_fleet.mjs` | `7fd414ed74da713da06ee6ea436828e3ace825edc1aa97aa33c57dee28e1e4a8` | 130-153, 169-183 |
| `assets/maps/city_rebuild_v1/vehicle_occupant_impact_fleet_seam.mjs` | `16fe6a6504393031b9e6c515fc9b985e365c946438663ac65079e5a496516643` | 5-16, 27-34 |
| `assets/maps/city_rebuild_v1/vehicle_damage.mjs` | `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92` | 6, 11-20, 202-245 |
| `assets/maps/city_rebuild_v1/vehicle_crash.mjs` | `cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44` | 137-139 |
| `assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs` | `3faeed3b6bea790396c7676958100bd5520105d452a61a14c45977d38095a166` | 116-125, 203-209 |
| `godot/mafiozi_walk/scripts/vehicle_physics/vehicle_contact_manifold.gd` | `dfe706e678fd64a6ac2d67f27bd659733287ff9aba6e62c6b9343889ba3ed9dd` | 53-123, 137-159 |
| `godot/mafiozi_walk/scripts/vehicle_physics/vehicle_contact_state_bridge.gd` | `73843ce758381b7911aa432ade0e66cfb9ea96ebd05986f0e9f39bc64a1de1a7` | 56-156, 277-322 |
| `godot/mafiozi_walk/scripts/vehicle_physics/vehicle_crash_solver.gd` | `3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129` | 1-12, 96-150, 231-245, 521-525 |
| `godot/mafiozi_walk/scripts/tests/test_vehicle_physics_static_contact_bridge.gd` | `b2972a3ad0141eaadef63d5cc322ff2609c374ae7daa1918a1c5ea75bb27ea69` | 64-138, 238-279 |
| `godot/mafiozi_walk/scripts/tests/test_vehicle_contact_state_bridge.gd` | `123a641a89e3b9d9e9e63348e75e821c3bf3243e3285480ca8dca97aa123c30a` | 56-114, 201-240 |

If any pinned file changes, this receipt must be reviewed again before it is
used as an integration contract.

## Source contact contract

The source collision normal points **from the car toward the obstacle**.
`polygonVehicleContact` says so explicitly and chooses the support point on the
car in that direction (`vehicle_contact.mjs:1-2,25-32`). The damage wrapper also
defines the incoming normal as pointing out of the body toward the obstacle and
normalizes/flips it outward before forwarding it to crash mechanics
(`vehicle_damage.mjs:202-214`). `vehicle_crash.mjs:137-139` then converts the
world point and direction through the current car root inverse.

The source crash point is therefore a point on the target car surface in world
space, converted to target-root local coordinates. It is not the obstacle
point, the midpoint between two physics points, the chassis collision-center
offset, or a COM-relative lever arm.

## Exact Godot direct-state meaning and sign

For the audited Godot 4.7.2 backend, these five values are already world-space
observations despite the API's `local` naming:

- `get_contact_local_position(index)`: point on self in world space;
- `get_contact_collider_position(index)`: point on counterpart in world space;
- `get_contact_local_normal(index)`: normal **on self** in world orientation;
- `get_contact_local_velocity_at_position(index)`: self point velocity in world
  space;
- `get_contact_collider_velocity_at_position(index)`: counterpart point
  velocity in world space.

`get_contact_impulse(index)` is the solver impulse on self in world orientation.
The actual translated and rotated fixture at
`test_vehicle_physics_static_contact_bridge.gd:238-278` rejects applying the
body transform a second time and proves that both impulse and normal point onto
self. Consequently, the source outward normal is the negative of the Godot
normal-on-self:

```text
source_outward_world = -normal_on_self_world
```

Given the target root frame captured at the same observation tick, the only
lawful conversion into the solver's public native-local axes is:

```text
point_native_m = frame_at_observation.affine_inverse() * point_on_self_world_m
normal_native = (frame_at_observation.basis.inverse()
                 * source_outward_world).normalized()
```

For an orthonormal rigid-body basis, the inverse basis is its transpose. Do not
subtract the COM. Do not use a later/current transform. The solver then performs
its reviewed native-local -> source-local involution `(-x,+y,-z)` at
`vehicle_crash_solver.gd:122-125,521-525`.

## Two-tick chronology

The actual Godot fixture produced this deterministic onset:

| Callback | Closing speed | Reported impulse |
| --- | ---: | --- |
| tick 38 | `7.4937105178833 m/s` | `(0,0,0) Ns` |
| tick 39 | `0 m/s` | `(1143.41,812.619,4074.227) Ns` |

The first callback's body linear velocity was already post-solve, while its
paired contact-point velocities still retained the incoming closing motion.
The later callback supplied impulse but no longer supplied the source impact
speed. The same fixture measured a `0.3751` relative error even for a favourable
same-sign whole-window `J` versus mass-delta-velocity comparison, and a
`>1000` relative chronology error for the callback-local window
(`test_vehicle_physics_static_contact_bridge.gd:251-278`).

Therefore:

- latch qualifying closing speed on the zero-impulse onset;
- do not wait for a later nonzero `J` to choose impact speed;
- do not derive `impactSpeed` from `J / mass`, energy, or the later body
  velocity;
- if a future authority delays dispatch for confirmation, it must retain the
  onset point, normal, frame, tick and speed as one coherent snapshot and must
  preserve target sequence ordering.

## `impactSpeed` has three source meanings

There is no lawful universal `bridge.peak_closing_speed_mps -> impactSpeed`
conversion.

### Active vehicle against static world

`vehicle_contact_motion.mjs:47-53` computes the pre-response normal closing
speed at the contact point, including the yaw-rate lever arm. With a static
counterpart, the bridge expression
`max(0, -(v_self_point-v_other_point).dot(normal_on_self))` is the same sign
convention and is the correct native 3D generalization, provided point, normal,
velocity and frame all refer to the same raw observation.

### Passive fleet vehicle against static world

The passive source path calls `contactKinematics` and uses only linear velocity
(`vehicle_fleet.mjs:175-178`, `vehicle_contact.mjs:35-38`). It omits yaw-arm
velocity. A bridge point-velocity result is therefore not bit-equivalent to this
source branch. The authority receipt must identify which source semantic is
being preserved instead of silently treating both static paths as identical.

### Vehicle against vehicle

The source pair solver first computes one canonical planar impulse from both
pre-solve bodies, their masses, inertias, contact arms and relative closing
speed (`vehicle_pair_impulse.mjs:15-34`). It then assigns distinct directed
speeds:

```text
impactSpeed(A) = deltaVA = impulse / massA
impactSpeed(B) = deltaVB = impulse / massB
```

The fleet seam sends the same canonical event to both targets, reverses the
normal for B, and preserves the two distinct delta-V values
(`vehicle_occupant_impact_fleet_seam.mjs:5-16`). A bridge closing speed is not
either directed delta-V. A later Godot impulse is not source-equivalent because
of the demonstrated chronology and incomplete reported impulse window.

Exact peer parity therefore requires an independently reviewed port of the
source pair resolver, supplied with both pre-solve body states, masses,
half-extents/planar inertias, roots and one canonical contact point. None may be
reconstructed from the present bridge impulse.

## Why the current bridge row is not solver-ready

`vehicle_contact_manifold.gd:112-122,146-156` currently:

- stores `peak_closing_speed_mps` and relative velocity from one raw point;
- exports an impulse-weighted average of `(point_self + point_other) / 2`;
- exports an independently impulse-weighted aggregate normal.

Those three outputs are not guaranteed to describe the same raw contact. The
source uses the car's own surface point and its corresponding outward normal.
The actual fixture measured `5.7268 mm` between self and collider points, so the
current midpoint already moves the source surface point by about `2.8634 mm` in
that simple wall case. A larger separation or multi-point manifold can move it
farther.

The row also does not contain the target root transform. Computing local
coordinates after queuing with a later transform changes the struck location.
Finally, `complete` is a collection-level result at
`vehicle_contact_state_bridge.gd:297-322`; a detached row cannot prove that the
same collection had no cap, identity or manifold gap.

At minimum, an authority candidate needs these additional coherent fields:

- `point_on_self_at_peak_world_m`;
- `normal_on_self_at_peak_world` from that same point;
- `relative_velocity_at_peak_world_mps` from that same point;
- `target_root_frame_at_peak` or precomputed native-local point and outward
  normal made from that exact frame;
- parent collection `valid && complete` and its gap flags;
- authored static collision role proving equivalence to a source blocking
  obstacle, not merely `kind == "static"`;
- for peer contacts, both pre-solve body inputs required by the source pair
  solver.

## Event, lifetime and cooldown authority

The bridge intentionally emits directed, non-canonical, proposal-only rows
(`vehicle_contact_state_bridge.gd:136-146`). It owns neither a ledger nor event
admission. The crash solver verifies only its target `(vehicle_id,
life_generation)`, a nondecreasing physics tick, a strictly increasing
target-local `impact_sequence`, and a bounded local `event_id` replay list
(`vehicle_crash_solver.gd:96-137,239-242`). It does not validate counterpart
lifetime, establish a global tick, canonicalize a pair, or own server damage.

Required authority behaviour:

1. Validate the target and counterpart identity/life against the live registry.
2. Treat the caller-supplied bridge tick as untrusted until it is bound to the
   authoritative physics clock.
3. Coalesce A->B and B->A bridge observations into one canonical peer event.
4. Fan that event out into exactly two directed target receipts. These are not
   duplicates: each vehicle receives its own delta-V and outward normal.
5. Scope replay by `(canonical_event_id, target_vehicle_id,
   target_life_generation)`, or use an equivalently unambiguous target-scoped
   event ID. A global event-only dedupe would incorrectly discard the second
   vehicle.
6. Allocate `impact_sequence` independently and monotonically for each target
   lifetime. Multiple legitimate target impacts may share one physics tick;
   the solver intentionally permits that when sequence increases.
7. Include both vehicle lives in peer keys so respawning with a reused ID cannot
   inherit an old contact episode, cooldown or replay receipt.
8. Reset bridge/reducer lifetime state when the target life changes.

Source admission has two separate `0.25 s` gates:

- `vehicle_damage.contactImpact` has a target-global collision cooldown
  (`vehicle_damage.mjs:206-223`);
- vehicle pairs additionally use a canonical pair cooldown
  (`vehicle_fleet.mjs:147-152`).

The common confirmed collision-event authority must own these gates and fan one
admitted event into structural crash, server damage and other consumers. A pure
coordinate adapter must not own cooldown. A persistent resting row must never
replay an old retained peak after cooldown; a re-impact requires a new
qualifying source-semantic observation. Conversely, a genuinely new closing
impact may qualify after cooldown without requiring the collider identity to
have disappeared in between.

## Damage boundary

`vehicle_crash_solver.gd` is a proposal-only structural mechanics port. Its
derived `energy_j` is internal crash bookkeeping, not HP authority. Source HP
uses the separate `vehicleCrashDamage(impactSpeed)` branch and enforces a
nonlethal collision result (`vehicle_damage.mjs:11-20,220-223`). No contact
adapter may invent any of the following:

- impulse-to-speed conversion;
- impulse/energy-to-HP conversion;
- collision HP, explosion, destruction or nonlethal-floor authority;
- server admission from a local physics proposal.

## Lawful future pure proposal component

A new pure component may be considered only after the upstream authority can
provide a frozen, confirmed receipt containing:

- canonical event ID and target-scoped replay tuple;
- target vehicle ID and life generation;
- counterpart identity and life where applicable;
- authoritative physics tick and target-local impact sequence;
- collection completeness/provenance;
- coherent target surface point, outward normal and target frame from one
  observation;
- already resolved `impact_speed_mps` plus an explicit semantic tag such as
  `active_static_point_closing`, `passive_static_linear_closing`, or
  `peer_directed_source_delta_v`.

That component may validate the receipt, perform the world -> native-local
conversion shown above, and return a solver-shaped **proposal**. It must not
calculate speed, choose event identity, canonicalize pairs, run cooldown,
mutate the solver, or produce HP. Until those inputs exist, no pure adapter
implementation is lawful.

## Actual verification receipts

Both commands were run headless with Godot 4.7.2 and fixed 60 Hz against the
pinned files:

- `test_vehicle_contact_state_bridge.gd`: `PASS 81/81`, bridge SHA `73843ce7...`;
- `test_vehicle_physics_static_contact_bridge.gd`: `PASS 32/32`, first contact
  tick 38, first nonzero impulse tick 39, maximum self/collider point separation
  `0.005789758 m`.

These are component/diagnostic receipts only. `runtime_wired` remains false;
they provide no main, GPU, LIVE, server or HP acceptance.
