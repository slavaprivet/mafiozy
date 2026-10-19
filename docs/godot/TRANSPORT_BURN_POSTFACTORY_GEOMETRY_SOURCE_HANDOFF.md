# Transport burn post-factory geometry source correction

Status: **executed-source correction accepted by the author; native zero-surface result is source-faithful for the seven disputed nodes**.

## Frozen files

| File | SHA-256 |
| --- | --- |
| `tools/godot/export_transport_burn_postfactory_geometry.mjs` | `89c99fea75a818b7b2636080261fd1fc7803e7855fee04a313e37f4120a22fb1` |
| `godot/mafiozi_walk/data/transport/source_burn_postfactory_geometry.json` | `15c89bac33c5051766fa40ed6c39b7b09d8d5da703ec98a0bd08c7c4fc8aeebd` |
| Frozen burn identity prerequisite | `38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38` |
| Raw visual manifest | `10133bb94515eb41078b5b801a647fedad21b1eab4199a430b112359928fc0db` |
| Native visual manifest | `38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03` |

Machine-readable package metadata is in `docs/godot/TRANSPORT_BURN_POSTFACTORY_GEOMETRY_SOURCE_MANIFEST.json`.

## Correction

This package supersedes one unsupported conclusion in the frozen alias audit and census: **the seven missing native surfaces are not an export/import coverage loss**.

The original input GLBs do contain nonempty indexed meshes at those names. The actual source factory then clones and repeatedly clips owned geometry. The relevant assignments are in pinned `vehicle_fleet_models.mjs` SHA `5dcec7102fc425c7828239ad5de10d4feb29ff7216610fc842333894f811545c`: `mesh.geometry=split.outside` at lines 182 and 193. The exporter executes the complete factory rather than inferring an outcome from those lines.

For every disputed source node, actual post-factory geometry is:

- position attribute count `0`, values length `0`;
- index `null`;
- groups `[]`;
- draw range start `0`, count positive infinity;
- material container still scalar and its exact `m####` identity still captured in construction `materialRest`.

The raw visual oracle independently contains an empty position array, null indices, no groups and serialized null draw-count. Parsing each raw exported visual GLB produces a zero-child non-Mesh node at the exact `v####` key. Godot's zero native surface therefore preserves the actual post-factory source result. The original input triangles are evidence of the clipping transition; they are no longer runtime content and must not be restored.

## Exact seven-node receipt

| Profile / key | Material rest | Original input | Actual post-factory | Raw visual GLB |
| --- | --- | ---: | ---: | --- |
| `city_hatchback/v0008` taillamp L | `m0003`, insertion 3 | 216 positions / 324 indices | 0 / null | non-Mesh, 0 children |
| `city_hatchback/v0009` taillamp R | `m0003`, insertion 3 | 216 / 324 | 0 / null | non-Mesh, 0 children |
| `family_wagon/v0007` taillamp L | `m0003`, insertion 3 | 216 / 324 | 0 / null | non-Mesh, 0 children |
| `family_wagon/v0008` taillamp R | `m0003`, insertion 3 | 216 / 324 | 0 / null | non-Mesh, 0 children |
| `city_suv/v0009` taillamp L | `m0003`, insertion 3 | 216 / 324 | 0 / null | non-Mesh, 0 children |
| `city_suv/v0010` taillamp R | `m0003`, insertion 3 | 216 / 324 | 0 / null | non-Mesh, 0 children |
| `delivery_van/v0002` cargo split | `m0000`, insertion 0 | 96 / 132 | 0 / null | non-Mesh, 0 children |

The fixture pins exact typed-array hashes for original and post-factory attributes, all four original GLBs, all four raw visual oracles, all four raw visual GLBs, both manifests, and the loaded source closure.

## Full-recipe safeguards

All 13 visual recipes are reconstructed. Each profile must reproduce:

- the exact `v####` traversal keys, names, parents, visibility and shadow flags from the raw manifest;
- the complete profile-local `m####` material descriptor and alias graph after canonicalizing only nondeterministic Three UUID spelling;
- the exact frozen scalar/array container kind and ordered material identity IDs from source-burn receipt `38d37079...`.

Damage construction is then executed with a SHA/sentinel-pinned in-memory `materialRest` observer. All seven empty post-factory nodes remain scalar material holders and all seven identities are genuinely captured.

## Determinism, cost and limits

Two sequential corrected full exports produced byte-identical fixture SHA `15c89bac...`. Observed wall times were about 9.9 s and 10.3 s, including all 13 fresh factories and raw visual GLB parses. The fixture is 46,195 bytes. These are offline source-tool measurements, not frame-time or FPS.

Only the seven disputed nodes are admitted by this correction. This does not change the valid material identity, batching, callback, copy, debris or authority requirements in the other burn handoffs. It restores no geometry and changes no production source, exporter, native visual, runtime, GPU, LIVE, or Git state.
