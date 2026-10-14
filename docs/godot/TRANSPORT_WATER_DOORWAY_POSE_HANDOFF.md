# Transport water doorway pose

Additive pure spatial-pose component for the position fields of `vehicleWaterDeparturePoint` and `vehicleWaterSeatPoint`. It is separate from the frozen water surface provider and from the dry actor transition. It does not move an actor, grant a seat, query collision, advance authority clocks, enter swimming or wire Root/LIVE.

## Frozen source and native inputs

- `vehicle_water_exit.mjs` SHA `531fc5b01dd1ad6ce2fda5b8aac76688cf5f1888fc4f05610a7ef176c259a860`
- `vehicle_seats.mjs` SHA `1e6b2178bee7ed6ec51ecbb5d99e13772942c8fb71a2f3cc7579ad2aa3537779`
- `car_entry.mjs` SHA `342a3f959cd7d82bfa5759f1706d6471bc32998fdb49be79361a2556ab3245b6`
- native `vehicle_descriptors.v1.json` SHA `99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a`
- descriptor reader SHA `85614568d1a4b23391618e84e8de250c9b872a9215353734d3f7e1f7638d3e97`
- actual factory anchor exporter SHA `7e6c2f9b23bc47e17a28da84b6279214949b729a2b49255c42fa18c45a5d4f47`
- descriptor projection exporter SHA `766f6df08c622565413a17e31e3b09341981455918f94c006e665e2ea0b6d53c`

The catalog already owns exact per-profile native `anchor_local_m`, `approach_local_m`, `source_side` and seat-to-door identity. The dry `transport_actor_transition.gd` SHA `c9ed1ad7205c74d1131cfda0588f8c862fb1ae6cf64d7b42c83b25f1b0df4c6f` adds the doorway arc and drives a real actor. This helper does not duplicate that responsibility: water discards the dry Y arc, holds the exact local seat-root Y throughout the doorway, and applies the full current vehicle `Transform3D`, including pitch, roll and submerged translation.

## API

- `water_departure_point(vehicle_transform, seat_descriptor, distance, progress) -> Dictionary`
- `water_seat_point(vehicle_transform, seat_descriptor) -> Dictionary`

Success returns `ok`, exact `seat_id`/`door_id`, `local_position_m`, and `world_position_m`; departure also returns clamped `progress` and source `seat_blend`. The four source seat IDs must map to their own four door IDs. `distance=1.9` uses the exported approach. `distance=2.4` extends it by exactly 0.5 m along the source seat side after native X conversion. The source exit blend is `smooth(((1-progress)-.25)/.5)`. Only local X/Z interpolate; local Y is reset to the seat anchor before the full transform. Nonfinite transforms, distance, progress or anchors fail closed. This bounded API intentionally does not reproduce the nested JavaScript `pose` presentation object (`fold`, `door`, `reach`, `phase`, `done`, and related fields); it is exact only for seat blend and spatial projection.

## Verification and cost

Godot 4.7.2 safe runner covers all exported profile seats plus fixed numeric and negative rows. Tests pin source, both descriptor exporters, descriptor data and catalog reader; load the actual descriptor catalog; exercise both 1.9/2.4 m candidates for every exported seat; check progress endpoints and midpoint; use a fixed axis-permuting, translated transform numeric oracle to expose ignored pitch/roll; and reject mismatched or non-string door identity and nonfinite input. Exact final check count is pinned in the manifest.

Bounded pure-pose cost in the released quiet CPU window: 20,000 calls in 20 blocks of 1,000, true median p50 13.452 us/call and nearest-rank p95 13.618 us/call. This is isolated helper cost, not loaded-scene FPS or LIVE evidence.

## Root seam and limits

Root supplies a current descriptor seat and the actual vehicle body's global transform at each pose step. This pure helper validates fields but cannot prove that a supplied dictionary belongs to the catalog or matches the current vehicle profile; the authoritative host must obtain it from the SHA-pinned catalog and bind it to the vehicle lifetime/profile. Root chooses the admitted 1.9/2.4 m plan, excludes only the occupied vehicle in collision, applies the returned world point to its exit body, then hands the result to the frozen water surface provider. Root must retain the source presentation fields through the existing transition or a separately verified port; this helper's `seat_blend` is not the complete source `pose` object. Root remains responsible for `body.done && grounded && !blocked`, collision failure, authority, door visuals, exit completion and swimming. No Root/player/physics/runtime integration has been performed.
