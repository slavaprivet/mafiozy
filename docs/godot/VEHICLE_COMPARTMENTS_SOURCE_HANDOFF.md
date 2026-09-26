# Vehicle compartments — source handoff, 27 September 2026

## Native panel implementation delivered

`godot/mafiozi_walk/scripts/vehicle_visual/vehicle_compartments.gd` now implements presentation-only private hood/trunk state. `assets/vehicle_visual/compartments.json` is an 18,023-byte companion bound to each actual visual GLB SHA. It records authored hinge angles, actual engine node keys, access profiles, cargo bounds and fixed support bases/lid-local tips extracted from the source controller. No GLB was re-exported.

`scripts/tests/test_vehicle_compartments.gd`: **11,793 actual Godot checks PASS across 13 imported profiles**, maximum local pose error **2.6656e-7**. Checked closed/open/reclosed samples against source, full engine visibility, moving supports, target reversal without position/velocity snapping, invalid cargo containment, settled idle, disposal and independent instances. Source extraction verifies support bases remain fixed between two different open poses before emitting the companion.

API: `configure(visual) -> {ok,error}`, `set_open(kind,bool) -> bool`, `is_open(kind)`, `amount(kind)`, `step(delta)`, `is_animating()`, `access_profile(kind)`, `cargo_bounds()`, `contains_item(center,half)`, `dispose()`. Configure after visual import; attach its root to the scene before stepping support transforms. Call `dispose` before visual removal. Configuration fails closed for wrong visual hash or missing bindings and does not partially modify meshes.

`access_profile` returns native vehicle-local `position_local_m`, `outward_local` and `range_m`, outside the source basis wrapper; other fields retain their declared source meanings. Host should apply source **horizontal** reach/sector and vertical limit checks, not interpret handle-height distance as the original planar interaction metric. `cargo_bounds` returns native-local Vector3 min/max. `contains_item` is containment only, not the full source opening/physical placement/inventory admission.

The module intentionally leaves occupancy, proximity, speed, roll, source authority, detached damage and inventory decisions to the host. Healthy open/close animation and supports are implemented; smoke, wreck/detach/repair require their own actual owner inputs. Settled `step` returns immediately without hierarchy scans, allocations or IO. Companion parsing happens once per configure, and only at most four cached supports update while moving; engine visibility changes only at its source threshold. Native tests are correctness checks, not a loaded-scene FPS comparison. GPU/main wiring remains coordinator-owned.

The source investigation below predates this implementation; its initial 248-check receipt described read-only discovery. The reproducer now additionally emits the explicitly authorized small companion data asset.

The source already opens functional hood/trunk panels and exposes actual engine geometry. Its cargo-volume helper is **placement eligibility, not inventory**. Actual stored goods exist in separate bank-bag and mission-box systems; native visible cargo needs an explicit bridge to those states and identities.

Independent actual-source oracle: `outputs/coordinator21_vehicle_compartments/source_oracle.mjs` → `source_oracle.json`, **248 checks PASS, 13 profiles, source bytes unchanged**. Real factory + hood/trunk adapters run closed → open → closed, including rejection gates. All 13 expose 49 engine detail parts when open. A small geometric probe fits each cargo volume only while open; **no inventory item is created**. Samples include exact hinge transforms, moving supports, engine-child visibility and cargo colliders. Keys match the source traversal used by the visual export (`v0001` begins the vehicle beneath the basis wrapper).

## Panel controls and presentation

| Source | Exact seam |
|---|---|
| `assets/maps/city_rebuild_v1/vehicle_hood.mjs` | `createVehicleHood`, `findHoodInteraction`, returned `interaction/toggle/update/reset/dispose`, internal `pose` |
| `assets/maps/city_rebuild_v1/vehicle_trunk.mjs` | `createVehicleTrunk`, `findTrunkInteraction`, `stepVehiclePanelMotion`, returned `interaction/toggle/setOpen/update/reset/dispose` |
| `assets/maps/city_rebuild_v1/vehicle_fleet.mjs:91–93,57–73` | Each vehicle owns its adapters; render calls their update with actual vehicle/damage/crash state |
| `assets/maps/city_rebuild_v1/walk_preview.mjs:1117–1132,1780,1796` | `nearestInteraction({fresh:true})`, `interactWithVehiclePanel`; single non-repeat E, optional R repair; consumes entry hold and weapon input |

Hood range 1.5 m, trunk range 1.45 m; source checks the corresponding front/rear approach sector and height difference ≤1.8 m. Both reject occupied, transitioning, blocked/unstable, destroyed or moving faster than 0.5 m/s; detached lids cannot toggle. Healthy panels auto-close above 2.5 m/s. Keep this separate from seat-door hold interaction.

Panel motion uses the exact critically damped spring in `stepVehiclePanelMotion`: omega 18, dt capped at .2, continuous velocity through reversal, then `smooth(amount) * authoredOpenAngle`. Do not replace all vehicles with a fixed 85° rotation: sedans use trunk +80°, hatches +85°, pickup tailgate −1.45 rad; bus has rear engine access and hood −1.4 rad. Exact per-profile values are in the oracle.

Hood `pose()` switches actual engine detail visibility when `amount > .01`, detached or lid hidden. It also recomputes support struts from their fixed bases to transformed lid tips. Merely rotating the hinge leaves the engine hidden and supports stale. `Engine_bay_detail` contains the actual block, valve cover, radiator, fan, battery, hoses and other meshes; `Engine_core` is hidden by source to avoid blocking the bay. Smoke is a separate severity-driven effect and must not be made visible just because the hood is open. Source damage owns deformation/debris; hood only offsets its rigid bay mount and observes lid detachment.

## Cargo geometry and what is missing

`vehicle_trunk.mjs:115–163` exports `cargoBounds`, `cargoColliders`, `containsItem`, `acceptsItem`, `toCargoLocal/toCargoWorld`, `worldCargoBounds/worldCargoColliders`. Bounds are tightened against actual visible floor/wall extents, not the external car AABB. `acceptsItem` requires a physical cargo floor, amount ≥.85 or detached lid, complete item containment and an adequate opening beside the lid. It explicitly performs **no inventory, item motion or teleportation**. Four cargo colliders exist for most profiles; pickup has six.

Coordinates here are vehicle-local source metres (+X left/+Y up/+Z front). Native local data needs RY(pi), including all corners when converting bounds. A rendered stored item must use a saved local placement under the exact vehicle instance, so it follows driving/roll; do not recompute it from camera or ground position each frame. Item size, rotation, existing-item collision and placement policy are not supplied by this helper.

No generic arbitrary-item trunk inventory or native stored-cargo mesh controller was found in these panel/fleet/Walk modules. Opening the lid is safe to port immediately; claiming an item was stored requires the relevant owner to commit that state first.

## Existing goods, IDs and authority

**Bank bags:** `world.html:58897–59080` provides `_bagVehicleCandidates`, `_bagVehicleAvailable`, `_bagTrunkPoint`, `loadBagIntoVan`, `unloadBagFromCar`. Source stores precise `_bankBagIds` plus `_bagsLoaded` on the selected car, `_bankVanBagIds` for the special bank van, `_bankRob.myBag` and `_stableBankBagId` for carried identity. Preserve those IDs across load/unload; do not regenerate from a count. Capacity is the existing `BAG_CAPACITY` table at line 19342 (e.g. sedan/taxi 2, van 6, pickup 4, truck 8, bus 0), with a special bank-van capacity override. The older trunk reach is **1.65 source cells**, distinct from the native panel's metre range. Conversion/admission belongs to the gameplay bridge.

Bank client messages `bank_rob_bag_loaded` and `bank_rob_bag_carried` are handled at `mafiozi_bot.py:34116–34150`. The server validates the active robbery/player and records aggregate loaded/carried state; this is not a complete server-owned per-vehicle item-placement snapshot. Avoid presenting `_bagsLoaded` alone as a fully authoritative generic inventory.

**Mission box:** `mafiozi_bot.py:24592–24604` creates a quest owned by uid with `_taken_at`; `box_load` at 24719 changes carrying → loaded and binds `car_id`; `box_unload` requires that same car ID and drops to ground; `box_status` at 24789 exposes active state/car_id. `world.html:28876–28902` updates presentation only after `box_load_reply`/`box_unload_reply`. Preserve these reply gates. The current status DTO does not expose a durable box-instance ID/generation, so reconnect-safe native item identity needs an explicit contract; do not infer it from the array index. The source `box_load` itself checks quest state and non-empty car_id, not complete native car reach/cargo geometry.

`world.html:71845,71861–71863` publishes **ground** money bags and mission boxes to the Walk object bridge. These records do not establish loaded-item poses inside a trunk. No existing per-item cargo transform snapshot was found.

## Proposed native ownership

1. **Visual/compartment module (root):** own only panel spring/pose, engine visibility, supports, immutable cargo geometry and private visual instances. Expose source-consistent `request_panel`, `update`, `contains/accepts` queries. It must not grant inventory ownership.
2. **Interaction host (root/player integration):** select nearest actual panel, route one E, supply current vehicle lifetime, speed, occupancy, transition, roll and player position. Keep seat boarding and panel actions mutually exclusive for that event.
3. **Cargo owner/authority bridge:** maintain exact vehicle lifetime + item identity + revision + local placement, validate transfer and return a receipt. Map existing bank bags/quest boxes through their owners; imported sessions need actual snapshots. General arbitrary-item storage is new required work, not an existing capability of the geometric helper.
4. **Cargo presentation adapter:** create/update/remove one visual per admitted item identity after the receipt; retain local placement while the car moves, remove on authoritative unload/delete/lifetime end, never duplicate ground/carried/stored representations. If no actual storage data exists, show the empty real compartment rather than demonstration goods.

Validation for root: reversal continuity, engine exposed and rehidden, real floor/cavity bounds, moving supports, rotated/rolled vehicle cargo, closed/too-large/blocked placement rejection, repeated load/unload without duplication, stale vehicle/item revisions, and player seat-pose ownership remaining independent.

Reviewed source SHA256: hood `c4acdbbf023d4e5c5245325400620c2a55a40c91d8439851bca509b5270969c8`; trunk `91d8575b2f52ca10b43bfe73d4a004ec4ebfef7b066835c8d1ed1a46239f5fb0`; world `9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5`; backend `76d5f192fa42fc16a9980adefcf9fd016f125f8606bb2b5bd517a2cd2dbebcb9`. Oracle records all loaded geometry dependencies. No runtime/source/main/Git/GPU edits; no storage action, server request or FPS acceptance was performed.
