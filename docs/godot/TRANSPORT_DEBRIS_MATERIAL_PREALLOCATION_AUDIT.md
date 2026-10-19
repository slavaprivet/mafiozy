# Debris material preallocation audit

Date: 2026-09-27. Status: **read-only design audit; no candidate or adoption**.
This audit explains which work from the rejected 57.517 ms explosion-frame
snapshot can be moved to vehicle preparation without changing source material
ownership. It changes no runtime, frozen helper, source asset, scene, or export.

## Pinned evidence

| Evidence | SHA-256 | Relevant contract |
| --- | --- | --- |
| `assets/maps/city_rebuild_v1/vehicle_damage.mjs` | `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92` | Construction capture 61-63; recursive `copyPart` 102-107; explosion order 276. |
| `godot/mafiozi_walk/scripts/transport/transport_vehicle_debris.gd` | `1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f` | Frozen native subtree/material copy 249-280. |
| `godot/mafiozi_walk/scripts/transport/candidates/transport_vehicle_debris_material_snapshot.gd` | `0e000ba7c30c463fae5ff6390323f1bb36d87c138ebd4673bdd5465102627001` | Rejected post-callback stage/commit candidate. |
| `godot/mafiozi_walk/data/transport/damage_assemblies.json` | `8643b11808f5834445e34be6d1c2930a9cc2f5a930042dfb7edfcf4ce6d78279` | Exact compact-sedan ten-source explosion order. |
| `godot/mafiozi_walk/assets/vehicle_visual/manifest.json` | `38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03` | Native/source node keys and authored material IDs. |
| `godot/mafiozi_walk/data/transport/source_burn_identities.json` | `38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38` | Actual factory scalar-container and construction `materialRest` identities. |
| Three r180 `build/three.core.js` | `eb077d2417f61d3e6d9264c317cabc4ea35769ed6b0ab533067292a550784c20` | `Material.clone/copy` 17149-17214; `MeshStandardMaterial` 38030 and its `copy` near 38352. |

The already frozen snapshot evidence remains **PERFORMANCE REJECTED**: actual
compact sedan, ten assemblies, 72 copied meshes/surfaces, 29.559 ms stage plus
27.958 ms commit = **57.517 ms** in the parent sequential run. This audit does
not rerun or reinterpret that measurement.

## Actual compact material census

The ten source assemblies contain 76 manifest mesh slots. Four fitted door
glass slots (`m0006`) are transparent and are rejected by source `copyPart` and
native `_opaque_mesh`, leaving the measured 72 copied mesh/surface rows. Those
72 rows refer to **29 authored profile-local material IDs**:

- `m0002`: 28 rows;
- `m0000`, `m0004`, `m0005`, `m0007`, `m0008`: four rows each;
- `m0009`: two rows;
- 22 other IDs: one row each.

The 29 count is the SHA-pinned authored/native manifest alias graph. The exact
post-batch canonical object result at the explosion boundary still depends on
the separate private `WeakMap` batch receipt described in
`TRANSPORT_BURN_BATCH_CANONICAL_SOURCE_AUDIT.md`; value/name/color equality is
not an identity receipt.

## Why 29 shared debris materials would be wrong

Source `copyPart` obtains the current canonical material for each eligible mesh
and calls `material.clone()` independently for that mesh. Even when 28 meshes
resolve to the same canonical `m0002` object, the 28 debris meshes receive 28
distinct material objects. This permits later per-part mutation and disposal
without affecting a sibling part. An optimization may reuse one immutable
source property receipt for the 28 equal source identities, but it must still
preallocate **one private material shell per copied mesh surface**. Sharing one
private burned Resource per canonical ID would change source ownership.

The frozen native helper already follows the independent-shell rule:
`_copy_subtree` duplicates the effective active material for every surface and
places that Resource on the private copied mesh. Its 72 prepared Resources are
therefore the correct storage to update or replace during preparation; a new
set of 72 Resources need not be allocated during the explosion.

## Source clone semantics versus Godot

Three `Material.clone()` is `new this.constructor().copy(this)`. Base `copy`
copies scalar render state, clones clipping planes, copies `blendColor`, and
JSON-copies `userData`. `MeshStandardMaterial.copy` additionally copies color,
emissive, normal scale and environment rotation values, scalar PBR/render
fields, and retains the exact texture/map object references. Thus the material
shell and mutable value objects are independent, while textures are shared.

The frozen Godot helper uses `material.duplicate(true)`. That asks Godot to
duplicate eligible nested subresources as well as the material shell, which is
broader than Three's texture-reference behavior. The executed-source fixture
asserts that the current 13-profile material objects contain no Three Texture
values, so this distinction does not create a known mismatch for the pinned
fleet. It must remain a fail-closed concern for a future textured profile:
preparation must preserve mapped nested-resource identity where source `copy`
preserves it, rather than assuming recursive duplication is equivalent.

## Where the rejected cost comes from

The rejected candidate does substantially more than copy changed color:

- stage allocates 72 new material duplicates even though configure already
  made 72 private surface materials;
- it serializes stored properties of both source and private material for each
  row, repeating the same source work across aliases;
- it walks resource graphs for source/private rows, then repeats private graph
  work after commit;
- commit writes 72 surface bindings, serializes every private copy again and
  installs change watchers;
- launch serializes the 72 committed private materials again;
- `_find_refresh_row` searches the complete prepared row collection once for
  every source row rather than using an identity index.

Across a successful stage, commit validation, committed receipt, and launch,
the current code performs 432 full `_base_material_signature` serializations
for 72 surfaces. It also invokes `_resource_graph` 216 times before deduplication
of watched identities. These counts follow directly from the frozen loops;
they are operation counts, not a new timing result.

Caching a source signature by exact Resource identity can reduce repeated
source inspection from 72 rows to the actual unique identity count for that
phase. It cannot justify sharing the 72 private outputs or skipping validation
of independently mutable private materials.

## Concrete bounded candidate

A future additive candidate can test this design without editing the frozen
helper:

1. During load/prewarm, bind every eligible source mesh/surface to its exact
   canonical Resource identity, source node key, surface index, vehicle
   generation, geometry revision, and material revision. Build an O(1) source
   identity index instead of `_find_refresh_row` scans.
2. Retain one immutable property receipt per exact source Resource identity,
   but allocate and bind one private prepared material shell per copied surface.
   Populate every shell with the complete source clone state, preserving nested
   Resource identities according to the pinned source semantics.
3. Apply the exact burn RGB/roughness operation to each private shell outside
   the event boundary. Watch every source receipt and every private shell for
   mutation. Replacement, silent unsupported nested mutation, topology/layout
   change, reset, callback-contract change, or revision drift invalidates the
   prepared set.
4. At explosion preserve exact source order: char construction-captured source
   identities, execute the synchronous callback, stop on throw, hide glass,
   then resolve each eligible mesh through the actual canonical getter.
5. The fast path is allowed only when the post-callback exact identities and
   material revision receipt prove that each resolved material still matches
   its prepared basis plus the expected burn writes. Then launch using the
   already-bound 72 private shells, with no event-time Resource allocation,
   `duplicate`, surface rebinding, reflection schema discovery, serialization,
   or resource-graph construction.
6. A callback capable of replacing or mutating opaque materials has no generic
   fast-path waiver. It requires an explicit synchronous material-revision
   contract that updates/rebuilds the prepared shells before launch, or the
   event fails closed. The rejected 57 ms snapshot remains the semantic
   fallback evidence, not an acceptable hidden frame spike.

The current pinned production callbacks were separately audited as not mutating
opaque vehicle materials, but constructors accept arbitrary callbacks. The
candidate must bind acceptance to the reviewed callback identity/contract and
must invalidate when that contract changes.

## Required tests before adoption

- Actual compact census: 10 assemblies, 76 candidate mesh slots, four
  transparent exclusions, 72 distinct private materials, 29 authored IDs, and
  no private Resource identity shared between surfaces.
- Alias case: all 28 `m0002` rows reuse one source receipt while retaining 28
  independently mutable private shells.
- Post-callback replacement/mutation/throw, render-batch toggle/fallback,
  changed hidden clone, source/private `Resource.changed`, nested-resource
  replacement, reset, generation rollback, material revision, surface layout,
  queued/free/reparented nodes, and stale/foreign tokens all fail atomically.
- Source clone parity for every stored native property and nested Resource
  identity. A synthetic texture case must prove shared nested texture identity
  or reject; current texture-free assets cannot waive it.
- Event instrumentation must prove zero Resource/material allocation and zero
  schema reflection/serialization/graph traversal on the accepted launch path.
- Compare source behavior after independently mutating one launched part's
  material: no sibling part or attached source material may change.
- Sequential load/prewarm and explosion-frame p50/p95/max measurements on the
  actual compact profile, followed by the coordinated full-scene/GPU check.

## Limits

This audit supplies no implementation, exporter, callback authority, batch
`WeakMap` receipt, renderer proof, shader warmup, benchmark, GPU result, FPS,
LIVE result, or main-scene integration. Preallocation does not authorize stale
snapshots, material matching by values/names, content removal, skipped callback
semantics, shared per-ID debris materials, or a delayed explosion.
