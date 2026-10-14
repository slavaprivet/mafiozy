# Transport debris burned-material preparation: source audit

Date: 2026-09-27. This is a read-only audit of the pinned JavaScript source. It does not change a Godot runtime, the frozen debris component, or the failed material-snapshot candidate.

## Verdict

A private burned-material variant may be prepared outside the impact frame for the **currently pinned production constructors below**, but it is source-exact only under a narrow receipt:

1. preparation reads the current canonical render-source material after vehicle construction, livery/traffic paint, and render-batch ownership have settled;
2. the prepared variant clones every material property and texture reference, then applies the exact source operation to its own color: `prepared.color = current.color.lerp(#100f0e, 0.94)` and `prepared.roughness = 0.99`;
3. material identity and all properties that the detached copy preserves remain unchanged until explosion, or a signalled mutation invalidates/rebuilds the prepared variant;
4. the explosion keeps source order: char the attached car, run the synchronous callback, hide glass, then detach/copy; a throwing callback must still prevent detachment;
5. the optimization is limited to the pinned callbacks enumerated here. `createVehicleDamage`, `createVehicleFleet`, `createCrashPartner`, and `createMercenaryProfessionShowcase` all accept caller-supplied callbacks, so the generic API does **not** promise that a callback leaves opaque materials unchanged.

An unconditional vehicle-load snapshot is therefore **not approved as a general source contract**. The fixed target `#100f0e` is not itself the final source color, and later material changes can make a load-time clone stale. A prepared variant with an exact current-material stamp/invalidation boundary is admissible for the pinned production paths; an unstamped preset is not.

## Exact explosion order

Pinned `vehicle_damage.mjs` SHA-256: `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92`.

- Lines 55-64 construct the adapter. Line 63 captures each unique mesh material's original `color` and `roughness` in `materialRest`.
- Lines 102-107 copy a detachable subtree. Each mesh clones its geometry and the result of `getVehicleRenderSourceMaterial(source)`; all current material fields are inherited by `material.clone()`.
- Lines 109-126 detach at most ten ordered sources: doors, `Hood_lid`/`Trunk_lid`, then wheel pivots.
- Line 276 is the complete explosion transaction. For each captured color-capable material whose **current explosion-time** `transparent` flag is false, it performs `color.lerp(new Color('#100f0e'), .94)` and sets `roughness=.99`; it then invokes `onExplosion(...)` synchronously; it then hides meshes registered as glass at construction; only then does it call `detachParts()`. Construction-time glass registration and explosion-time burn eligibility are distinct.
- Line 306 restores the originally captured color/roughness on reset. A prepared private burned variant must be discarded or regenerated across that lifecycle boundary.

Consequences:

- The burned RGB depends on the material color at explosion. Replacing it with literal `#100f0e` changes the rule.
- `materialRest` records only a scalar `mesh.material` that exposes `.color`; an array-valued material is not independently registered by line 63. A future preparer must mirror that exact eligibility and must not char every member of an array merely because `copyPart()` can clone material arrays.
- The identities in `materialRest` are fixed at adapter construction. If a mesh later replaces its material, source chars the old captured identity while `copyPart()` clones the current resolved identity. An identity-changing optimization must reject/refresh rather than silently char the replacement.
- The callback sits inside the material-to-copy interval. A callback exception leaves the attached material charred but prevents glass hiding and detachment. Prewarming resources must not change that control flow.
- The detached copy includes properties not touched by the char operation (maps, emissive state, opacity, metalness, side, and other material fields). A prepared clone must preserve their current values rather than manufacture a reduced material.

## Canonical render material and ownership

Pinned `vehicle_render_batches.mjs` SHA-256: `a9b4c0c93652b52e29a2c29fe65748bdf451122594583d3bd455238f766df648`.

- Lines 10-24 keep a `WeakMap` from an invisible presentation proxy to the authored source material. `getVehicleRenderSourceMaterial()` returns the authored material only while the mesh still owns that registered proxy.
- Lines 90-96 install the proxy and retain the authored material as the batch material.
- Lines 111-133 detect material/geometry/ownership changes and fall back from batching.
- Lines 143-146 restore the authored material on batch disposal.

Pinned `vehicle_fleet_models.mjs` SHA-256: `5dcec7102fc425c7828239ad5de10d4feb29ff7216610fc842333894f811545c`.

- Lines 134-164 clone source GLB geometry and materials per vehicle. A material is shared inside that vehicle when source meshes shared it, but it is not shared with sibling cars.
- Lines 270-321 construct the exact detachable lid/hatch/hood hierarchies; they can contain cut pieces of current authored meshes, not a synthetic generic panel.
- Lines 397-400 mutate taillamp `emissiveIntensity` during vehicle updates.
- Lines 414-417 record per-vehicle ownership and apply interior colors before returning the car.

This ownership permits private per-car burned variants, but it does not make a load-time material snapshot immutable. In particular, source preserves every current field when `clone()` runs, while the char rule changes only RGB and roughness. The existing dynamic taillamp emissive mutation is a concrete reason to stamp every material field actually cloned if an eligible detachable subtree can reference that material; do not infer immutability from per-car ownership.

## Actual constructors, profiles, and callbacks

### Walk fleet

Pinned `vehicle_fleet.mjs` SHA-256: `7fd414ed74da713da06ee6ea436828e3ace825edc1aa97aa33c57dee28e1e4a8`.

- Lines 76-103 create a fleet record. Line 93 constructs damage after trunk/hood ownership and before render batches (lines 96-99).
- The damage profile is exactly `maxHp = clamp(round(massKg * .16), 240, 1200)`; the wrapper forwards `onExplosion({...event, record})` synchronously.

Pinned `walk_preview.mjs` SHA-256: `e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47`.

- Lines 1301-1305 load all 12 artist profiles and one taxi variant, then add them to the fleet.
- Lines 1365-1376 add the demo `red_sedan` and construct the production fleet callback.
- The line 1375 callback performs occupant-authority delivery, writes a diagnostic dataset, enqueues a blast, shatters glass, and may begin an exit transition for the active demo car. Its callback body contains no opaque vehicle-material assignment or replacement.
- `glass.shatterAll` is geometry/visibility work on breakable glass. In pinned `glass_breakage.mjs` SHA-256 `d5b8f7380eb716067203395808e7c94ed45cc44ff4d7cfc4bb1d278b24cecf3a`, lines 124-128 fracture registered glass; it does not mutate opaque detachable materials.

The 12 pinned authored profiles are in `vehicle_fleet_models.mjs` lines 67-82. Their IDs, masses, and resulting fleet HP are:

| Profile | Mass kg | Max HP |
|---|---:|---:|
| `city_hatchback` | 1150 | 240 |
| `compact_sedan` | 1320 | 240 |
| `family_wagon` | 1540 | 246 |
| `executive_sedan` | 1810 | 290 |
| `sport_coupe` | 1380 | 240 |
| `city_suv` | 2020 | 323 |
| `delivery_van` | 2390 | 382 |
| `utility_pickup` | 2160 | 346 |
| `city_bus` | 9800 | 1200 |
| `police_interceptor` | 1830 | 293 |
| `city_ambulance` | 3500 | 560 |
| `fire_engine` | 10500 | 1200 |

`city_taxi` is a second `compact_sedan` instance and therefore has 240 HP. Pinned `vehicle_taxi.mjs` SHA-256 `684dfe7879a96215dc06f625d5fe9ea062722e6607999804cff6f14c9c47fcde`, lines 1-5, applies yellow paint and roughness `.38` before `fleet.addCar()` constructs damage. The demo `red_sedan` uses 1500 kg and therefore 240 HP.

### Claimed source-world traffic vehicle

Pinned `world_traffic_presentation.mjs` SHA-256: `be373d5b10474f94480e3f79fcae21c76ea3e7b5bac0a5fa2b82bf48bdfb5d51`.

- Lines 22-45 map supported source rows onto the same 12 authored profile families.
- Lines 108-113 apply source paint to the canonical render-source material.
- Line 150 disposes body and wheel batches and restores canonical materials when the player claims the car.

`walk_preview.mjs` lines 413-416 construct damage only after `claimPlayerControl()` (lines 428-431) has returned the actor. The callback only enqueues the blast and shatters glass; it contains no opaque material mutation/replacement. The profile uses the same mass formula as the fleet. While player-controlled, `world_traffic_presentation.mjs` lines 100-102 skip later pose/paint application, so the claimed actor does not receive a new source paint through that presentation loop after damage construction.

This makes preparation after claim and after the existing source paint safe for the current path, subject to the material stamp above. Preparation before claim/paint is stale by construction.

### Mercenary QA showcase

Pinned `mercenary_profession_showcase.mjs` SHA-256: `4832c9f2d59f2a41a0b9a3f80f164ae5e13d0e203bfdcd5f69bae5844f12aee5`.

- Lines 45-57 create a demo car, then create damage with the default 240 HP profile.
- The wrapper adds `record` and forwards to the callback supplied by `walk_preview.mjs` line 880. For a vehicle, that callback only enqueues the blast and calls `glass.shatterAll`; it contains no opaque material mutation/replacement.

### Crash partner

Pinned `crash_partner.mjs` SHA-256: `6ad7b87841aaa846aca2cc50602f4b544b4e1449c7061da81960ebbddee3b69b`.

- Lines 6-14 construct a demo car and default-240-HP damage, forwarding an arbitrary caller callback.
- No non-test production call to `createCrashPartner` exists in the pinned tree. It cannot justify a production preset contract, and its arbitrary callback must be treated as potentially mutating or replacing materials.

## Integration boundary for a future optimization

The current pinned production callback bodies do not block private preprepared burned materials. The safe implementation boundary is still narrower than “prepare at load and always reuse”:

- prepare from `getVehicleRenderSourceMaterial()` for every exact eligible mesh, after taxi/source paint and current batch ownership are final, while retaining whether that exact material identity was captured in `materialRest` and rechecking its current `transparent == false` value at explosion;
- retain an exact identity/property receipt for the source material and reject or refresh if it changes;
- compute the `.94` lerp from the receipt color and keep all other cloned fields current;
- do not assign prepared materials, hide sources, or advance lifecycle during preparation;
- at explosion, preserve char -> callback -> glass hide -> detach order and callback exception behavior;
- scope acceptance to the three live `walk_preview` paths above. Any new callback or constructor requires a fresh audit or an explicit callback contract.

This audit does not establish GPU compilation readiness, shader equivalence, or the measured 57 ms candidate cost. It only establishes when source semantics permit moving private material construction out of the impact frame.
