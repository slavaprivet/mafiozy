# Native debris event seam: exact source order and remaining receipts

Date: 2026-09-29. Status: **READ-ONLY SOURCE AUDIT; EVENT SEAM NOT
IMPLEMENTED**. This document adds no runtime, exporter, fixture, test, authority,
physics, main, LIVE, GPU, or Git integration. It is not an FPS or frame-time
receipt.

## Pinned source

| File | Bytes | SHA-256 | Relevant lines |
| --- | ---: | --- | --- |
| `assets/maps/city_rebuild_v1/vehicle_damage.mjs` | 30,331 | `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92` | 55-64, 101-127, 268-278, 306-308 |
| `assets/maps/city_rebuild_v1/vehicle_crash.mjs` | 19,937 | `cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44` | 124-135, 150-152 |
| `assets/maps/city_rebuild_v1/vehicle_render_batches.mjs` | 15,548 | `a9b4c0c93652b52e29a2c29fe65748bdf451122594583d3bd455238f766df648` | 10-24, 88-96, 104-146 |
| `assets/maps/city_rebuild_v1/vehicle_fleet.mjs` | 18,813 | `7fd414ed74da713da06ee6ea436828e3ace825edc1aa97aa33c57dee28e1e4a8` | production construction/callback owner |
| `assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs` | 43,956 | `5dcec7102fc425c7828239ad5de10d4feb29ff7216610fc842333894f811545c` | actual factory/material/geometry owner |

`vehicle_damage.mjs:276` is the authoritative full-wreck transaction. The
structural crash `detach()` in `vehicle_crash.mjs:127-135` is a separate path;
it must share assembly ownership with the explosion seam, but it does not add
an explosion callback or char/glass phase.

## Exact successful explosion order

1. `update(dt)` first advances crash mechanics, then calls
   `stepVehicleDamage`; only an increase in `state.explosions` enters the
   transaction (`vehicle_damage.mjs:273-276`).
2. It iterates the construction-captured `materialRest` keys in Map insertion
   order. Each still color-capable identity whose **current explosion-time**
   `transparent` value is false is mutated in place: current color lerps toward
   Three `Color('#100f0e')` by `.94`, then roughness becomes `.99`.
3. `onExplosion({vehicle, state, point})` runs synchronously. If it throws,
   char already happened; glass hiding, copying, source hiding, and launch do
   not happen. Source does not roll char back.
4. After a normal callback return, every pane captured in construction-time
   `glass` order gets `visible=false`.
5. `detachParts()` updates the car and debris-root world matrices, computes the
   debris-root inverse and car origin, and constructs the ordered roots:
   `car.doors.values()`, then shell members named exactly `Hood_lid` or
   `Trunk_lid`, then `car.wheels[].pivot`, truncated to the first ten
   (`vehicle_damage.mjs:109-114`).
6. For each source index `i`, `copyPart(source)` recursively evaluates the
   **post-callback, post-glass** hierarchy. A node rejects its whole subtree if
   it is locally invisible, is the damage-effects root, is a mark, is a line,
   has a directly transparent scalar material, or has
   `userData.vehicleRenderBatch`. An admitted mesh clones current geometry and
   clones the current `getVehicleRenderSourceMaterial(source)` result; an array
   clones each member. Local position/quaternion/scale and child order are
   copied (`vehicle_damage.mjs:102-107`).
7. A rejected root consumes no RNG and is not hidden. For an admitted root,
   source performs the operations per part, not as two global phases: compose
   the copy transform in the debris root, add the copy, remember source
   visibility, hide that source, then calculate launch state
   (`vehicle_damage.mjs:115-125`).
8. Each admitted part consumes exactly seven shared RNG draws in order: launch
   yaw offset, strength, vertical velocity, landing yaw, and spin X/Y/Z. The
   launch index remains the original source-list index `i`, including gaps from
   skipped roots. `getState()` is sampled inside each admitted iteration;
   signed speed is coerced then clamped to `[-35,35]`, and heading is
   `travelYaw ?? yaw ?? car.object.rotation.y`.
9. Bounds/landing use the just-created current copy. `fireFx.update()` occurs
   only after the complete detach loop (`vehicle_damage.mjs:277-278`).

This order is more precise than “callback, detach, copy”: copy and hide are
interleaved for each admitted root. A native validate-all/commit-all transaction
is a deliberate stronger failure model; it cannot be called exact exception
parity unless that difference is accepted explicitly.

## What the frozen proofs establish

- Construction material identity receipt
  `source_burn_identities.json` SHA
  `38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38`
  proves all 13 factory closures, 757 captured identities, 197 glass entries,
  scalar material containers in that pinned construction, rest color bytes,
  roughness type including `undefined`, and node/material alias order.
- Initial body-batch receipt `source_burn_batch_identities.json` SHA
  `49a0342fb3260e3963ddfbb0446ace151028dba12fb5f7b3b3ed81290ada2da9`
  proves 1,438 registrations and canonical/hidden/proxy identities. It also
  records the production pre-batch taillamp intensity difference.
- Toggle receipt `source_burn_batch_toggle_identities.json` SHA
  `32ebd8a1a6c5cfbfdb121c4e1cb0b4f529a02b39615533332b5fd315c2fff372`
  proves registered-current-canonical versus registered-current-hidden phases
  and disposal.
- Fallback receipt `source_burn_batch_fallback_identities.json` SHA
  `4342dcb0f38af60bcdf45e70326386f3d43025dd7321dbf436d85fad5004b8ad`
  proves four compact-sedan fallback causes: current material replacement,
  shared hidden mutation, geometry replacement, and source reparenting.
- Corrected post-factory geometry receipt
  `source_burn_postfactory_geometry.json` SHA
  `15c89bac33c5051766fa40ed6c39b7b09d8d5da703ec98a0bd08c7c4fc8aeebd`
  supersedes the old LOSS claim. The seven disputed nodes have zero positions,
  null index and no groups after the actual factory. Their captured material
  identities are real, but their original input triangles are not runtime
  geometry and must not be restored.
- Native physical debris SHA
  `1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f`
  prebuilds real private visual/collision bodies and atomically launches them.
  Native launch planner SHA
  `cfa09fbd15b2e4824cdcd6683254c2298d726bc1fe802e81271849bc537b55ca`
  reproduces the seven explosion launch draws when the host supplies exact
  accepted indices, offsets, motion, and draws.
- Material-pool SHA
  `c29037e98c71cc9bed733784adf107edd58417439d721680c0a43ca0ace329d0`
  prepares independent shells only. Snapshot candidate SHA
  `0e000ba7c30c463fae5ff6390323f1bb36d87c138ebd4673bdd5465102627001`
  documents source order and post-callback commit checks, but its measured
  event cost was rejected and it is not adopted.

## Missing fields for a future native event receipt

The event seam still needs one immutable, vehicle-lifetime-scoped receipt with
all fields below. Existing IDs are not authority by themselves.

### Event and lifecycle

- authoritative vehicle/entity ID, profile ID, source-profile ID, lifecycle
  generation, damage revision, visual/material revision, and assembly-ownership
  generation;
- prior/current explosion count and the exact accepted damage event identity;
  the source callback payload currently contains only `vehicle`, `state`, and
  `point`, so it supplies no causal damage/blast ID, authority token,
  source/cause, expected vehicle generation, or exactly-once native receipt;
- exact callback identity/version, callback-started and callback-returned flags,
  callback result/exception status, and post-callback revision;
- current batch-manager owner and phase (hidden/canonical/fallen back/disposed),
  plus a generation binding every `m####`/`h####` identity to this vehicle;
- preparation token and revision for any private shells, with explicit proof
  that transfer happened outside the event frame.

### Burn and glass interval

- ordered construction-captured material identities, insertion indices, rest
  color/roughness type, pre-char current color, explosion-time transparency,
  exact post-char bytes, and post-callback identity/property revision;
- a distinction between the identity charred from `materialRest` and the
  identity later returned by `getVehicleRenderSourceMaterial()` for copying;
  replacement during the callback makes them legitimately different;
- ordered construction glass identities and node bindings, visibility before
  hiding, hide completion after callback, and lifecycle generation;
- explicit zero-geometry material holders from the corrected post-factory
  receipt. They participate in material capture but provide no debris surface.

### Ordered copy graph

- exact ten-root candidate list with source index, semantic role/ID, object
  identity, parent/ancestry, local visibility, current transform, and the single
  shared ownership state against earlier structural/trunk detachment;
- for every recursively visited node, stable object key, child order, local
  transform, direct visibility, `isMesh`/`isLine`/mark/batch flags, direct
  transparency result, and admitted/skip reason. A rejected parent suppresses
  its descendants;
- for each admitted mesh, current geometry identity and revision, complete
  attribute/index/group/draw-range layout, scalar/array material container kind,
  ordered current container identities, canonical getter identities, and exact
  post-callback property receipt to clone;
- source and debris-parent global transforms at copy time and the composed copy
  transform. Callback hierarchy or pose edits must invalidate an older receipt;
- copy success/failure and accepted-root order. No RNG or source hide may be
  attributed to a rejected root.

The frozen body-batch receipts still mark exact batch proxy
`member_source_keys`, proxy geometry/layout, recursive `copyPart` getter calls,
private debris-clone provenance, wheel batch phase, and all-profile fallback
coverage as pending. The four compact fallback cases cannot stand in for those
missing event fields.

### Hide and launch

- prior visibility and hide ownership for every accepted source, with one
  registry shared by structural crash, trunk/lid mechanics, and explosion;
- original source index `i`, accepted ordinal, seven RNG values, RNG stream
  generation/cursor before and after, and proof that skipped roots consume zero;
- per-admitted-iteration `getState()` sample: raw speed value/coercion result,
  clamped signed speed, selected heading branch/value, debris-space start and
  car origin/outward vector;
- exact copied-geometry bounds input used by source landing logic. Native rigid
  collision/settling is an intentional physical extension, so source landing
  orientation is evidence for initial conditions, not a claim of identical
  later trajectory;
- final success/partial-failure state. Source can leave earlier roots copied and
  hidden if a later clone throws; native all-or-nothing behavior needs an
  explicit accepted divergence rather than an implicit parity claim.

## Root integration dependencies

Root must supply or own: authenticated damage/explosion transition; synchronous
callback execution and exception boundary; glass adapter completion; current
batch canonical getter/binding; vehicle/material/assembly generations; shared
assembly ownership; shared RNG cursor; post-callback geometry/material capture;
and the final physical launch commit. The transport helpers do not grant any of
those authorities.

A narrow next proof could instrument the actual `copyPart` closure after the
callback and record recursive getter calls, skips, cloned identities, hides and
RNG consumption. It should be a new SHA-pinned offline exporter/fixture, not a
rewritten formula oracle. This audit deliberately does not create it because
the current assignment permits only the read-only gap list.
