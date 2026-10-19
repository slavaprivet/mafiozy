# Transport burn and batch canonical material source audit

Status: **read-only source audit; no exporter, fixture, runtime, or adoption in this component**.

This audit defines the next identity proof needed after the frozen construction receipt. It covers source mesh registration into presentation batches, canonical material lookup during explosion-part copying, and the exact places where a load-time receipt is insufficient.

## Pinned evidence

| File | SHA-256 | Relevant lines |
| --- | --- | --- |
| `assets/maps/city_rebuild_v1/vehicle_damage.mjs` | `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92` | Import of canonical getter 5; construction capture 61–63; recursive copy 101–107; ordered detach 109–117; burn/callback/hide/detach order 276; reset 306. |
| `assets/maps/city_rebuild_v1/vehicle_render_batches.mjs` | `a9b4c0c93652b52e29a2c29fe65748bdf451122594583d3bd455238f766df648` | Private registration map and public helpers 10–24; candidates 41–79; hidden/canonical registration 80–100; fallback/update 104–133; toggle/dispose 135–148. |
| `assets/maps/city_rebuild_v1/vehicle_wheel_render_batches.mjs` | `dd295cd05d25ece2c68075286b12ee86f1e69f2c947b43771caf8b04fba3229e` | Shared registration API import 3–5; wheel candidates 22–53; hidden/canonical registration 54–63; fallback/update 69–86; toggle/dispose 88–98. |
| `assets/maps/city_rebuild_v1/vehicle_fleet.mjs` | `7fd414ed74da713da06ee6ea436828e3ace825edc1aa97aa33c57dee28e1e4a8` | Fleet options 23; trunk/hood 91–92; damage 93; body batching 96–98; optional wheel batching 99. |
| `godot/mafiozi_walk/data/transport/source_burn_identities.json` | `38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38` | Frozen actual-factory construction `materialRest`/glass receipt for all 13 profiles. It deliberately marks batch canonical identity pending. |
| `docs/godot/TRANSPORT_BURN_MATERIAL_IDENTITY_SOURCE_HANDOFF.md` | `e15527e409512349d2530c296f0f9c23f327b92e9c2b738230e6a3c6f26e4c7a` | Frozen step-1 method, results, identity scope, and limits. |

## Production call order

`createVehicleFleet` defaults to `detailOptimization=true` and `wheelRenderOptimization=false` at line 23. For an added car it constructs trunk and hood first, then `createVehicleDamage` at line 93, then the body/interior/door render batch manager at line 98. Wheel batching is created afterward only when both optimization switches and `THREE.BatchedMesh` allow it at line 99.

This order has two consequences:

1. Damage captures `materialRest` and `glass` from authored source meshes before hidden presentation replacements or batch proxy nodes exist.
2. Body and optional wheel batching subsequently register canonical source materials for the same original mesh objects. The original source meshes retain geometry, hierarchy, visibility, layers, and raycast ownership; batching changes their current material identity when enabled and adds separate `BatchedMesh` proxy nodes.

The frozen step-1 receipt proves that for its pinned 13 factory instances all 3,283 current construction containers are scalar and all 757 profile-local material identities occur in the real construction `materialRest`. That fact does not describe any hidden clones or post-construction batch proxies.

## Shared canonical registration contract

`vehicle_render_batches.mjs` owns a module-private `WeakMap` named `sourceMaterials` at line 10. Its record is exactly `{hidden, material}` keyed by the original source mesh.

- `registerVehicleRenderSourceMaterial` rejects a second owner for the same mesh, then stores the pair (lines 13–15).
- `unregisterVehicleRenderSourceMaterial` deletes only when the caller presents the same hidden identity (lines 17–18).
- `getVehicleRenderSourceMaterial(mesh)` returns the registered canonical `material` only when the mesh's **current material identity** is the registered `hidden` identity. Otherwise it returns `mesh.material` (line 24).

The last rule is intentionally identity-sensitive. A saved registration is not an unconditional alias. If current material is canonical because an optimization is disabled, the getter returns that current canonical identity. If current material is replaced, it returns the replacement. If registration has fallen back and been deleted, it returns whatever current material remains.

The public getter alone cannot prove that a mesh is registered when its current material already equals the canonical material: registered-but-disabled and unregistered states have the same getter result. Aggregate `stats` also has no mesh/member identity list. Exact registration therefore needs a read-only executed-source receipt from the private map; it cannot be inferred from the getter result, visibility, names, material values, or batch counts.

## Body, interior, and door batching

`createVehicleRenderBatches` collects permitted interior, door, and optional root owners at lines 41–46. Candidate traversal rejects non-mesh/animated/batched nodes, array-valued material containers, missing geometry, transparent/transmissive/invisible materials, breakable glass, moving/gameplay parts, unsupported geometry layout, and non-positive transforms (lines 62–79). These predicates are part of registration eligibility and must not be replaced with a visibility waiver.

Groups use canonical material UUID plus geometry layout and render flags (line 75). Only groups with at least two members become batches (line 81). Each `BatchedMesh` is created with the canonical `entry.material` (line 87) and is marked `vehicleRenderBatch` plus its more specific flags (line 89).

For each canonical material, the manager reuses one hidden clone from its `hiddenMaterials` map. The clone keeps the material name and has `visible=false` (lines 92–94). Each member then receives either canonical material or hidden clone according to the detail toggle, and the private map receives `{hidden, material: entry.material}` (line 95). The batch proxy is added separately at line 96.

During update, mutation of the hidden clone, current material replacement, geometry/ownership/render-state drift, or hierarchy loss causes fallback (lines 118–125). Fallback deletes the private registration (line 105). It restores canonical material only when current material is still the registered hidden identity and the hidden clone itself was not changed; a changed hidden resource can remain current after registration is removed (lines 106–109). Detail toggling swaps current material between hidden and canonical while keeping active registrations (lines 135–141). Dispose deletes registrations and restores canonical only for an active mesh still pointing to hidden (lines 143–146).

## Optional wheel batching

Wheel batching uses the same private map through the public registration helpers. It accepts only exact factory wheel bindings, supported opaque scalar `MeshStandardMaterial`, stable callbacks/geometry/ownership, and positive transforms (lines 22–53). It creates a new hidden clone per accepted batch entry, registers each original wheel mesh with that hidden/canonical pair, and installs hidden only when the manager is active (lines 54–63).

Its fallback unregisters with exact hidden identity and has the same changed-hidden retention behavior (lines 69–71). Enabled state swaps current canonical/hidden material without removing active registrations (lines 88–91); dispose unregisters and conditionally restores canonical (lines 93–96).

The wheel helper is optional in production. A receipt must record actual options and capability result. It must not claim wheel registration merely because wheel meshes exist.

## Explosion copy resolution

Damage's `copyPart` checks current source state before canonical lookup (lines 102–107): source visibility, damage-owned nodes, line type, `source.material?.transparent`, and `vehicleRenderBatch`. Therefore:

- Batch proxy nodes are rejected by their explicit `vehicleRenderBatch` metadata.
- Original source meshes remain eligible according to their exact current source fields. A hidden material's own `visible=false` is not the same as `source.visible=false`; the eligibility check does not waive or rewrite either property.
- Array semantics remain container semantics: the optional-chain transparency check is on the array object, while a successful copy clones every ordered material returned by the getter.
- The getter is evaluated only after eligibility succeeds. The returned scalar or ordered array is cloned into private debris materials.

Explosion assemblies are doors, exact hood/trunk lid shell entries, and wheel pivots, sliced to ten (lines 109–115). `copyPart` recursively walks their current children. It creates a group for non-mesh nodes and a cloned geometry/material mesh for mesh nodes. Thus the material receipt must cover all recursively reached eligible source meshes, not only the ten assembly roots.

At explosion line 276, construction-captured material identities are charred first. The `onExplosion` callback runs next. Glass is hidden after the callback, and `detachParts` resolves current/canonical materials last. A callback can mutate a captured canonical material, replace a source mesh material, toggle an optimization, mutate a hidden clone, or call a batch update before the getter is used. A load-time registration receipt cannot stand in for this event-time state.

For the ordinary active-body-batch case, the captured canonical identity is also the batch proxy material; charring it affects the rendered batch, while the invisible source mesh holds a hidden clone. The getter returns the captured canonical identity and debris receives a private clone. This is a consequence of exact identities and current registration state, not a rule that permits mapping by equal color or name.

## Evidence still missing

No frozen artifact currently records:

- exact original-mesh registration membership after body batching and optional wheel batching;
- registered hidden identity and canonical identity for each source node key;
- hidden-clone sharing relation, creation order, or owning batch manager;
- post-construction batch proxy identity, parent, material identity, and exact user-data flags;
- current material identity and canonical getter result at each batch phase;
- active registration after fallback, toggle, reparent, material replacement, hidden mutation, or dispose;
- actual per-mesh getter result at the post-callback explosion copy boundary;
- cloned debris material provenance from that getter result;
- a lifecycle/generation/revision binding for any of these post-construction identities.

The visual manifests cannot provide these facts because they are exported before damage/batch construction. The step-1 fixture intentionally stops before batches. Native surface/material identity also cannot prove a JavaScript `WeakMap` record.

## Proposed next executed-source oracle

Create a new standalone exporter and fixture; do not alter the frozen step-1 exporter or receipt. It should reconstruct the same 13 profiles and consume the frozen step-1 identity/key space as an input receipt.

### Instrumentation

Use a SHA- and unique-sentinel-pinned Node load hook for `vehicle_render_batches.mjs`. In memory only, expose a read-only query returning the exact private `sourceMaterials.get(mesh)` pair or null. Do not make the `WeakMap` iterable and do not change registration behavior. Add a separate synchronous observation hook around the public canonical getter only if exact explosion-call order/provenance is included; the hook must return the unmodified source result.

No production JavaScript, visual exporter, source GLB, runtime, or global project configuration should change.

### Identity namespaces

- Reuse `v####` source node keys and profile-local `m####` canonical material IDs only after exact validation against the frozen step-1 and visual receipts.
- Assign hidden materials a distinct profile/phase-local namespace such as `h####` by first observed registration order.
- Assign post-construction batch proxies a distinct namespace such as `b####` by exact creation/traversal order.
- Assign callback-created replacements a distinct event-local namespace such as `r####`.

None of these identifiers is global. Every record must be bound to profile ID, all source SHA pins, step-1 receipt SHA, visual manifest SHA, batch options/capabilities, and a future vehicle lifecycle generation.

### Required phase receipt

For every pre-keyed source mesh, record at least:

```text
source_node_key
pre_batch_container_kind and ordered m IDs
registration_owner: body | wheel | null
registered_hidden_id | null
registered_canonical_container_kind and ordered canonical IDs | null
current_container_kind and ordered current IDs
getter_container_kind and ordered getter IDs
source_visible
exact parent/source ancestry receipt
geometry identity/stamp receipt
batch phase and monotonically ordered observation index
```

For every hidden material, record its exact descriptor, canonical relation, member source keys, sharing relation, and owner. For every proxy record its separate proxy ID, parent source key, canonical material IDs, flags, member source keys, and geometry/layout receipt. Unknown fields stay null; absence is not converted to a guessed `m####`.

Required phases are: before batching, after body batch construction/initial update, after optional wheel batch construction/initial update, after each exact toggle, after controlled replacement/fallback cases, and after dispose. Use fresh vehicle instances for destructive cases so one fallback does not contaminate another.

### Explosion-copy proof

On fresh instances, execute the actual damage-before-body-before-optional-wheel order and one actual explosion transition. The oracle should observe getter calls made by recursive `copyPart` after the callback and bind each call to source node key, exact registration pair, current identity, returned canonical/current identity, and resulting private debris clone descriptor/identity. It should include bounded source cases for:

- active hidden source with canonical getter result;
- registered detail-disabled source whose current identity is already canonical;
- callback material replacement, which must return the replacement;
- changed-hidden plus batch update fallback, which must return the retained current hidden identity with no registration;
- proxy rejection and invisible-source rejection without a visibility waiver;
- disposal/reset on a fresh lifecycle.

The oracle must preserve the source callback order: char, callback, glass hide, detach/getter/copy. It should reference the existing numeric burn and damage assembly oracles rather than duplicate their arithmetic or RNG fixtures.

### Fail-closed assertions

Reject output if any source or input SHA, step-1 receipt, visual key/mID relation, batch option, capability result, registration owner, hidden/canonical identity, getter result, proxy flag, source visibility, hierarchy, geometry stamp, callback phase, clone descriptor, lifecycle, or double-export determinism check differs. A getter result equal by value is insufficient; object identity must match.

## Limits

This audit performs no source execution, Node/headless test, CPU benchmark, native binding, event transaction, rendering, physics, HP, authority, GPU, LIVE, or Git work. It authorizes no visibility exception and defines no global material ID. The proposed oracle remains a dependency for any native load-prepared burn/debris binding that claims exact batch canonical fidelity.
