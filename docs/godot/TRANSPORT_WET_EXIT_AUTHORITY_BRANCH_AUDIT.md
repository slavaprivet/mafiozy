# Minimal native wet-exit authority branch audit

Date: 2026-09-30. Status: **SOURCE AUDIT COMPLETE; IMPLEMENTED CANDIDATE IS
PROOF-ONLY AND NOT ADOPTED**. The current candidate/API/results are frozen in
`TRANSPORT_WET_EXIT_AUTHORITY_CANDIDATE_HANDOFF.md`; that handoff supersedes the
older proposed API.

## Exact source and native pins

| File | SHA-256 |
| --- | --- |
| `assets/maps/city_rebuild_v1/vehicle_water_exit.mjs` | `531fc5b01dd1ad6ce2fda5b8aac76688cf5f1888fc4f05610a7ef176c259a860` |
| `assets/maps/city_rebuild_v1/car_exit.mjs` | `c89df365c19659e02cd89a5ba75df1a3218808845a8154e0973ce682fb7ee263` |
| `assets/maps/city_rebuild_v1/walk_preview.mjs` | `e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47` |
| `godot/mafiozi_walk/scripts/transport/transport_water_doorway_pose.gd` | `fb61223de23c81c4317e2cf934815d9d45182aa2fc0b41d1f8ff5a2d133b03c3` |
| `godot/mafiozi_walk/scripts/transport/transport_water_exit_surface.gd` | `cc72286766429bfa9942961bd85f1f26457342a2981d087bbe1af93265c0f200` |
| `godot/mafiozi_walk/data/transport/vehicle_descriptors.v1.json` | `99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a` |
| `godot/mafiozi_walk/scripts/transport/transport_descriptor_catalog.gd` | `85614568d1a4b23391618e84e8de250c9b872a9215353734d3f7e1f7638d3e97` |

The optional Root review adapter at
`outputs/coordinator22_water_exit_review/actual_capsule_surface_adapter.gd`
(SHA `a24a1e4a037abd93a146f85c97e48ac49527337ddc201667f23b294280f75522`)
is reference output only. Production must not preload a file from `outputs/`.

## Why the dry route cannot authorize water exit

The existing access provider requires solid support rays and rejects a collider
marked as water. LogicalHost then requires `support_clear=true` for every exit;
the actor transition repeats dry support and grounded checks. A submerged exit
has no truthful dry support receipt. Supplying a fabricated clear/grounded row
would bypass collision authority.

The current dry files therefore remain byte-identical:

- Runtime `d493809fc33415ca9f0ad2204ad4fb2f458391cdcc80771311d1979f5dc9c04c`
- LogicalHost `5371b8561507d23334b83765d25d2d655033d3bb6f493568ff00868b779ea5ad`
- AccessProvider `325be57c92fca3b83aa884d47577c7e7014553850ee1806166fa67419f5cf830`
- ActorTransition `c9ed1ad7205c74d1131cfda0588f8c862fb1ae6cf64d7b42c83b25f1b0df4c6f`

A future integration needs an internal LogicalHost/Runtime wet claim. It must
validate the actual occupant/seat/vehicle roster, own the hold and source-clock
tables, instantiate a sealed actual-capsule adapter, install the real swim or
on-foot owner, then release the seat and seated collision exception. The
candidate cannot perform or acknowledge these operations.

## Source rules retained by the candidate

The water planner tries the current seat's 1.9 m and 2.4 m departures in that
order, samples 25 doorway poses, requires positive-depth finite-level water,
rejects occupied-car overlap, and checks a real capsule ascent. Water exit is
always the walk kind.

Release lasts .55 s and continually recomputes the pose from the current
vehicle transform. Walk-body launch uses signed `car.speed * .45`,
`travelYaw ?? yaw`, the car yaw and `.8 m/s` outward. The source pedestrian
step caps dt at .1 s, decelerates at `6 m/s²`, sweeps at no more than .12 m,
samples the centre plus twelve circle points, performs full/X/Z slide attempts,
and replaces velocity with actual displacement when blocked. Recovery lasts
.6 s. Completion requires body done, surface grounded, and surface unblocked.

The additive candidate applies those rules but deliberately returns a one-shot
`WET_AUTHORITY_PENDING` receipt and disposes its physical lease. It has no Host
commit API. Its duck-typed callbacks remain proof interfaces rather than
credentials, despite strict schemas and identity/clock/transform checks.

## Descriptor/lifetime boundary

Only catalog-issued profile/seat rows are accepted. Every seat's door ID must
match its seat ID. Two-seat profiles reject rear seats. `city_taxi` is not a
canonical descriptor profile and requires the authoritative roster mapping to
`compact_sedan`; the candidate never infers aliases from labels or geometry.
Actor and vehicle IDs, life generations, instance IDs, common World3D, catalog
rows, epochs, per-actor clocks and adapter lifetime are revalidated.

This audit and candidate are not evidence that water exit is playable in LIVE,
not a Host-authority receipt, and not a full-scene FPS measurement. No GPU,
LIVE, Git or existing dry runtime edit was performed.
