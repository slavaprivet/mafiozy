# Transport burn material identity gaps

Status: **source/native seam audit only; no runtime implementation and no adoption**.

This audit answers one narrow question: can the current 13-vehicle export reproduce the exact JavaScript material identities used by the explosion burn and debris-copy paths? It cannot. The current export preserves a useful per-profile alias graph, but it does not preserve the construction-time membership/order or the scalar/array and render-batch identity facts required for exact behavior.

## Frozen evidence

| Evidence | SHA-256 | Relevant behavior |
| --- | --- | --- |
| `assets/maps/city_rebuild_v1/vehicle_damage.mjs` | `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92` | Lines 61–63 capture `materialRest` and glass during construction; lines 102–107 copy current/canonical debris materials; lines 113–115 choose explosion assemblies; line 276 burns, calls back, hides glass, then detaches; line 306 resets captured identities. |
| `assets/maps/city_rebuild_v1/vehicle_render_batches.mjs` | `a9b4c0c93652b52e29a2c29fe65748bdf451122594583d3bd455238f766df648` | Lines 10–18 keep the private mesh → hidden/canonical material `WeakMap`; line 24 returns the canonical saved material only while the hidden replacement remains active. |
| `tools/godot/export_vehicle_visual.mjs` | `7e6c2f9b23bc47e17a28da84b6279214949b729a2b49255c42fa18c45a5d4f47` | Lines 56–68 assign object-identity labels per profile; line 134 resets the label map; lines 139–146 build the car/hood/trunk without damage or render batches; line 167 normalizes scalar and array material containers to an array. |
| `outputs/coordinator21_vehicle_visual/manifest.json` | `10133bb94515eb41078b5b801a647fedad21b1eab4199a430b112359928fc0db` | Raw 13-profile visual export. |
| `godot/mafiozi_walk/assets/vehicle_visual/manifest.json` | `38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03` | Production copy of the same material descriptor/alias data. |
| `godot/mafiozi_walk/data/transport/damage_assemblies.json` | `8643b11808f5834445e34be6d1c2930a9cc2f5a930042dfb7edfcf4ce6d78279` | Exact ordered detachable assemblies, but no burn membership or material-container/batch identity receipt. |
| `godot/mafiozi_walk/scripts/vehicle_visual/vehicle_visual.gd` | `d586952de302b7ec0467b89b91ba117e3350e8a5c217f48c303f06ff88494e34` | Lines 102–129 require one exported material entry, preserve sharing by `source_material_id`, and stamp that ID on the native `StandardMaterial3D`. |
| `docs/godot/TRANSPORT_SOURCE_BURN_PLAN_HANDOFF.md` | `c0ddfcbc01f7653c2515349feb922511c6daf6fb5fcf3cb3c029d09136f9cd35` | Pure burn arithmetic and synthetic source semantics. It is not an actual-profile identity map. |
| `godot/mafiozi_walk/data/transport/source_burn_oracle.json` | `625040555e6a4dcab21491e1ec6d0267e25a1db65a852a82f2da3f7019a0df9c` | Numeric/source semantic oracle only. |

## Exact source semantics that the seam must retain

At damage construction, `materialRest` is a JavaScript `Map` keyed by exact material object identity. The traversal registers only `mesh.material?.color`; therefore it registers a scalar material with color, including a scalar material that is transparent at construction, once in first-traversal order. An array has no array-level `.color`, so no member of an array-valued `mesh.material` is registered by this expression. Glass capture has the same scalar optional-chain shape through `mesh.material?.transparent`.

At explosion, the source iterates the identities captured in that construction-time map. It checks each identity's **current** `material.transparent`, then chars its current color and sets roughness to `0.99`. A transparent-at-construction scalar can therefore remain captured yet be skipped or burned according to its current transparency. A material replacement on a mesh does not replace the old identity in `materialRest`: the old captured object can burn even when no mesh currently points to it.

The explosion callback runs after charring and before glass hiding and debris copying. Debris copying reads each mesh's then-current material through `getVehicleRenderSourceMaterial`. That getter returns the saved authored/canonical material only when the mesh still holds the exact hidden batch material identity; otherwise it returns the current material. Scalar material containers clone as a scalar; arrays clone each ordered member. `copyPart` checks `source.material?.transparent` before the canonical lookup, so an array container does not behave like a scalar transparent material.

These are identity and ordering rules. Color equality, material name equality, visibility, a surface index, or an export-time transparency value cannot substitute for them.

## What the current exports do preserve

- Per-profile object-identity labels such as `m0000`, material descriptors, and the alias relation between exported mesh slots.
- Linear source RGB descriptors, roughness, opacity, transparency, and other direct material properties at visual-export time.
- In native visuals, one shared `StandardMaterial3D` per `source_material_id` within a visual instance. This preserves the exported alias graph for the current manifests.
- Ordered explosion assembly IDs in the separate damage assembly oracle.
- Pure burn arithmetic and synthetic behavior cases in the existing source burn oracle.

The labels are local to one profile export because the exporter resets its identity map for each profile. A valid identity key therefore needs at least `{profile_id, visual/export receipt SHA, visual lifecycle generation, source_material_id}`. `m0000` alone is not global.

## Actual 13-profile descriptor census

Both visual manifests above produce the same counts. `alias slots` is `material slots - unique IDs`; `shared IDs` counts IDs used by more than one exported slot. `multi-entry nodes` reports normalized exported material arrays longer than one.

| Profile | Slots | Unique IDs | Alias slots | Shared IDs | Max uses of one ID | Multi-entry nodes | Transparent slots |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `city_hatchback` | 270 | 57 | 213 | 19 | 63 | 0 | 15 |
| `compact_sedan` | 267 | 57 | 210 | 19 | 63 | 0 | 15 |
| `family_wagon` | 267 | 57 | 210 | 19 | 63 | 0 | 15 |
| `executive_sedan` | 272 | 57 | 215 | 19 | 63 | 0 | 15 |
| `sport_coupe` | 221 | 58 | 163 | 19 | 50 | 0 | 13 |
| `city_suv` | 273 | 57 | 216 | 19 | 63 | 0 | 15 |
| `delivery_van` | 227 | 57 | 170 | 19 | 49 | 0 | 13 |
| `utility_pickup` | 221 | 58 | 163 | 19 | 51 | 0 | 13 |
| `city_bus` | 233 | 59 | 174 | 21 | 44 | 0 | 27 |
| `police_interceptor` | 272 | 60 | 212 | 19 | 63 | 0 | 15 |
| `city_ambulance` | 234 | 60 | 174 | 20 | 49 | 0 | 13 |
| `fire_engine` | 250 | 61 | 189 | 20 | 48 | 0 | 13 |
| `city_taxi` | 276 | 59 | 217 | 20 | 63 | 0 | 15 |

Every current exported list has length one, but the exporter always converts a scalar to `[scalar]`. Therefore this census does **not** prove that the original source container was scalar. It proves only that no normalized list contains more than one entry. The native binder's current `size() == 1` check is consequently not an identity receipt for the source container kind.

## Missing evidence

No current artifact exports all of the following:

- Exact `materialRest` membership and first-insertion order for each actual profile after the real construction sequence.
- The captured rest color and roughness attached to each exact `materialRest` identity.
- Exact construction-time glass membership and order.
- Original material container kind (`scalar` or `array`) plus ordered identity members. A one-member normalized list remains ambiguous.
- The private render-batch registration relation: source mesh identity, hidden material identity, canonical authored material identity, current mesh material identity, and the resulting getter choice.
- Exact event-time active material identity, current transparency, replacement identity, array shape, overrides, or callback-driven changes.
- A lifecycle/revision receipt tying the exported JavaScript identity to current native Resources and ArrayMesh surface/group positions.
- A mapping for replacement materials created after export. In particular, construction burn can mutate an old captured identity while debris clones a different current replacement.

The damage assembly oracle cannot fill these gaps because assembly membership and material identity are independent. The source burn oracle cannot fill them because its rows are synthetic semantic/numeric fixtures, not a traversal receipt from the 13 actual factories.

## Required future source receipt

A future exporter should instrument the actual factory construction sequence and the real damage/render-batch registrations. It must observe source objects; it must not reimplement membership from names or descriptors. A narrow read-only hook in the source modules is preferable to a second copy of the formulas.

Minimum receipt:

```text
header:
  schema
  profile_id
  Three revision
  source file SHA map
  input GLB SHA
  visual manifest SHA
  factory/options receipt

materials[]:
  identity_id
  construction_traversal_index
  captured_in_material_rest
  material_rest_insertion_index | null
  captured_rest_color_linear_f64[3] | null
  captured_rest_roughness_f64 | null
  transparent_at_capture
  material_type

meshes[]:
  source_node_key
  construction_traversal_index
  material_container_kind: scalar | array
  ordered_material_identity_ids[]
  construction_glass_member
  construction_glass_index | null
  vehicle_render_batch_proxy
  batch_registration | null:
    hidden_identity_id
    canonical_identity_id or ordered canonical identity IDs
  canonical_copy_container_kind
  canonical_copy_identity_ids[]
```

If batching is installed after damage construction, the receipt must include the ordering/lifecycle phases and both snapshots. The batch relation lives in a private `WeakMap`; it cannot be reconstructed from `visible == false`, material values, or the hidden material's appearance.

## Required native binding and event API

A load-time binder may consume the source receipt, but it must validate the current native visual rather than infer membership:

```text
bind(profile_id, visual_generation, receipt_sha, nodes)
  -> captured material bindings + mesh container/surface bindings
```

Each material binding needs the exact exported identity ID and the current owned Resource identity. Each mesh binding needs the original source node key, container kind, ordered material IDs, and an explicit ArrayMesh surface/group mapping. Any native override or replacement also needs a host-assigned identity and monotonically increasing material revision. The binder must reject alias splitting/merging relative to the receipt.

An event-stage call needs `expected_generation` and `expected_material_revision`. It must read the current exact Resource identities and current transparency semantics, stage the char changes against construction-captured identities, then allow the source callback boundary before resolving the current/canonical debris materials. A two-phase host transaction must revalidate generation, revision, Resources, surface layout, overrides, and callback results before commit. It must also preserve the case where a captured old Resource burns even though no current surface references it.

The current Godot notion of effective material can come from an ArrayMesh surface material or a MeshInstance override. Future code must state which one corresponds to the source `mesh.material`, and reject an unknown override/replacement instead of choosing by value. A prepared cache keyed only by color, name, node name, or surface index is invalid.

For a source array or multiple geometry material groups, the present native binder is insufficient: it rejects normalized exported lists whose size is not one and has no explicit source array-index → glTF primitive/native surface receipt. That mapping must be exported and verified before supporting such a profile.

## Property representation and units

- Source color components and burn interpolation use JavaScript binary64 values in Three.js linear RGB. Preserve the exact source values through the burn planner. Convert the resulting linear RGB explicitly to Godot's sRGB-facing albedo property, preserving alpha.
- `roughness` is dimensionless. Preserve source arithmetic/value; do not introduce a parity-changing clamp unless the source does.
- `transparent` is an exact Boolean evaluated on the captured identity at explosion time for charring. Export-time transparency is descriptive, not an event eligibility decision.
- `opacity` is dimensionless and separate from the `transparent` Boolean.
- Material identity means JavaScript object reference identity or native `Resource` identity under a validated binding. Equal property values are not identity.
- Array member and geometry material/group indices are zero-based and ordered.

## Fail-closed cases

Future load-prepared burn/debris work must reject, without partial mutation, when any of these applies:

- construction `materialRest` or glass membership/order is absent;
- scalar versus array container kind is ambiguous;
- a native alias is split or distinct source identities are merged;
- a material override/replacement has no exact identity and revision;
- current transparency cannot be read with the source-equivalent semantics;
- render-batch hidden/canonical registration is missing, stale, or mismatched;
- profile, receipt SHA, visual generation, or material revision is stale;
- native surface count, geometry group order, or material-slot mapping differs;
- callback mutation changes a current material without an observed revision;
- an old captured identity is discarded merely because no mesh currently references it;
- a one-member normalized export is assumed to prove a scalar source container.

No existing runtime component should adopt or precompute actual-profile burn eligibility from the present manifests. The existing data is sufficient for the visual alias graph and pure numeric tests, but not for this identity-sensitive source seam.
