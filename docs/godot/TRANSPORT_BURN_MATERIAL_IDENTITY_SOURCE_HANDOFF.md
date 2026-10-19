# Transport burn material identity source proof

Status: **functional offline source proof; render-batch canonical identity remains pending; no runtime adoption**.

The package executes the actual 13 Walk vehicle factories and the actual `createVehicleDamage` capture traversal. It modifies no production JavaScript. A Node load hook first verifies the complete `vehicle_damage.mjs` SHA and a unique exact capture sentinel, then inserts an in-memory synchronous observer immediately after the source fills `materialRest` and `glass`.

## Frozen files

| File | SHA-256 |
| --- | --- |
| `tools/godot/export_transport_burn_identity.mjs` | `8bd2a6d3dfc4651d40287dd0b943fda61c76404d91ba3ec18c94064adaa48240` |
| `godot/mafiozi_walk/data/transport/source_burn_identities.json` | `38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38` |
| `docs/godot/TRANSPORT_BURN_MATERIAL_IDENTITY_GAPS.md` | `3647900de3fe180c4cbbc10264663c96b00a6d264d565364c1f9477d7e5f6bbc` |

The machine-readable package manifest is `docs/godot/TRANSPORT_BURN_MATERIAL_IDENTITY_SOURCE_MANIFEST.json`.

## Proof boundary

For each profile the exporter reproduces the visual export construction order: factory, taxi decoration when applicable, trunk, hood, neutral controller update, and `VehicleVisual` wrapper traversal. It assigns `v####` and profile-local `m####` by the same traversal and first-object-identity order as `export_vehicle_visual.mjs`, without renaming the authored nodes.

Before creating damage it requires:

- exact node key/name/parent/visibility equality with the raw visual manifest;
- exact material slot order, descriptor values, `m####` alias graph, and source metadata relation;
- exact equality between raw and production-native manifest material/node receipts;
- correct SHA and byte count for every raw exported visual GLB;
- correct SHA for every raw visual oracle and source input GLB.

Three assigns fresh UUID spellings to `source_metadata.interiorPaletteSource` on every factory construction. The exporter verifies that each such value has UUID form and replaces only its spelling with a stable first-seen token in both compared receipts. The equality/alias relation remains exact. No material property, source identity, node key, or container kind is normalized for this comparison.

The in-memory source hook then records the real construction closure:

- `materialRest` identities in insertion order;
- cloned linear RGB rest values as JSON binary64 values and explicit little-endian binary64 hex;
- roughness with an explicit `f64` or `undefined` type tag and bytes only for a numeric value;
- transparency and source material type at capture;
- literal `glass` array order, node keys, material IDs, source names, and visibility;
- every mesh's actual source container kind and ordered material identity IDs;
- the ordered source node keys using every identity.

The `undefined` roughness distinction is required. `MeshBasicMaterial` has color and is captured by the source optional-chain, while its construction rest roughness is `undefined`; explosion creates `roughness = 0.99` and reset writes `undefined` back. The visual descriptor's JSON `roughness: null` alone cannot prove that source runtime type.

## Actual 13-profile result

- 3,283 mesh material slots; all 3,283 current mesh containers are proven scalar in this construction.
- 757 profile-local unique material identities; all 757 occur in the actual construction `materialRest` maps.
- 3,166 `MeshStandardMaterial` slots and 117 `MeshBasicMaterial` slots.
- 117 captured identities have source `undefined` rest roughness, exactly the `MeshBasicMaterial` identities.
- 197 literal construction `glass` entries.
- No array-valued material container occurs in these actual factory receipts. This is now an executed-source construction fact for the pinned inputs, rather than an inference from normalized one-entry visual lists.

Per-profile detail, every material descriptor, rest bytes, mesh container, node key, and source dependency SHA is stored in the JSON receipt.

## Validation and workload

Two sequential full exports produced the same JSON SHA `38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38`. Measured offline wall times were 7,331.634 ms and 6,601.609 ms. This loads and verifies all source GLBs, factories, raw visual GLBs, visual oracles, and manifests; it is an offline authoring workload and says nothing about frame time or full-scene FPS.

The exporter fails before writing a receipt when the damage SHA/sentinel, Three revision, input GLB, visual GLB/oracle, traversal, descriptor, alias graph, source identity resolution, capture clone, rest type/value, or profile count differs.

## Host seam and remaining dependency

`source_material_id` is valid only with its profile, pinned visual/export receipt, and future vehicle lifecycle generation. A native binder must validate the corresponding native Resource alias graph and current material revision; a bare `m####` is never sufficient.

This component intentionally stops before render batching. The receipt states `batch_canonical_registration_exported: false`. The next proof must construct damage first and render batches second, matching `vehicle_fleet.mjs`, then record per mesh the pre-batch identity, hidden identity, public `getVehicleRenderSourceMaterial` result, proxy state, and current container identity. Hidden batch materials must use a separate identity namespace and must not be invented as current visual `m####` identities.

No event-time burn transaction, explosion callback boundary, glass hiding/reset replay, native binder, runtime cache, material mutation, HP, physics, authority, GPU, LIVE, or Git work is part of this package.
