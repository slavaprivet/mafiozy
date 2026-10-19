# Transport burn body-batch identity source proof

Status: **functional initial/body source proof; wheel/toggle/fallback/callback phases remain pending; no runtime adoption**.

## Frozen files

| File | SHA-256 |
| --- | --- |
| `tools/godot/export_transport_burn_batch_identity.mjs` | `a39eb6f5f6c46f0e69a206ab5125b39eacc3d7b461867566d197ef15eab95a8a` |
| `godot/mafiozi_walk/data/transport/source_burn_batch_identities.json` | `49a0342fb3260e3963ddfbb0446ace151028dba12fb5f7b3b3ed81290ada2da9` |
| `docs/godot/TRANSPORT_BURN_BATCH_CANONICAL_SOURCE_AUDIT.md` | `91a375b242b3696efbe56f29f999576aa57f8edfdd97405084f096ed57b96d73` |

Machine-readable package metadata is in `docs/godot/TRANSPORT_BURN_BATCH_IDENTITY_SOURCE_MANIFEST.json`.

## Executed source boundary

The exporter SHA-pins `vehicle_render_batches.mjs` and requires one exact canonical-getter sentinel. Its Node loader adds one in-memory read-only function that returns the exact private `sourceMaterials.get(mesh)` pair or null. Registration, getter, batch, and source behavior are not replaced.

Each actual profile is reconstructed from its pinned source GLB. The exporter first validates the entire frozen step-1 dependency list, the raw/native visual manifests, each raw visual GLB and visual oracle, and the step-1 `v####`/`m####` identity graph. It compares source node keys, parent keys, visibility, shadow flags, exact JSON matrices, container kinds, ordered material IDs, material source-node aliases, and property/metadata descriptors.

Only Three's nondeterministic `interiorPaletteSource` UUID spelling uses the frozen first-seen canonical token. Its equality graph remains exact. No property values, node identity, source visibility, or matrices use a tolerance.

After visual receipt validation, the car is removed from the RY(pi) export wrapper and placed directly under the source scene. The executed constructor order is:

1. damage;
2. rollover;
3. tyre damage;
4. body/interior/door render batches.

No pre-batch `car.update`, `trunk.update`, or `hood.update` is called. This matches fleet construction rather than visual-export normalization. The fleet-equivalent damage maximum HP is derived from the actual profile mass. Ground height and admission are constant zero/true because they do not run during these constructors; the exact options are stored in every row.

Tyre construction creates its scene-owned effect subtree before body batching. Those nodes and materials are recorded under separate `a####`/`am####` namespaces, and the exporter proves the subtree never enters the car source-copy hierarchy.

## Result

Across all 13 profiles:

- 1,438 original source meshes have exact private body-batch registration records.
- All 1,438 currently point to their registered hidden identity in this default active phase.
- 123 profile-local hidden identities preserve their exact canonical `m####` relation and source-member sharing.
- 291 batch proxies have separate profile/phase-local `b####` identities, parents, canonical materials, and exact source flags.
- Every profile has six separately scoped tyre auxiliary nodes.

The source observer distinguishes registration from getter equality. In this default active phase every registered mesh is current-hidden, so there is no executed registered-current-canonical row yet. That behavior belongs to the pending toggle phase and is not claimed by this fixture.

## Production pre-batch versus visual step-1 material state

The identity/alias graph is exact, but one material property per profile intentionally differs by lifecycle phase. Production creates batches before the first animated `render/car.update`, while the visual exporter sampled after a neutral `car.update`. The actual pre-batch taillamp emissive intensity is `1.6199999141693127`; the frozen visual value is `0.5`.

The fixture does not hide this with a pre-batch update or a whitelist. It stores both full descriptors and an exact structural diff for every material. There are 13 differing materials and 13 differing fields total, one taillamp emissive-intensity field in each profile.

This is an unresolved native-baseline dependency. Burn charring does not write emissive intensity, so a native prepared state derived from the visual value `0.5` cannot silently stand in for production pre-batch `1.6199999141693127`. The host needs an exact current source-state writer plus material revision before binding; common `m####` identity does not waive the property mismatch.

## Determinism and workload

Two sequential full exports produced the identical fixture SHA `49a0342fb3260e3963ddfbb0446ace151028dba12fb5f7b3b3ed81290ada2da9`. Offline wall times were 9,389.045 ms and 9,197.337 ms. The 5,152,798-byte fixture includes exact per-source-mesh pre/body phases and all dependency receipts. This is offline authoring cost, not frame time or a full-scene FPS measurement.

## Identity scope

- `m####`: frozen step-1 canonical identity, valid only within profile and pinned visual/source receipt.
- `h####`: hidden identity, valid only within profile and this body phase, assigned by first keyed source observation.
- `b####`: batch proxy identity, valid only within profile and this body phase, assigned by source traversal.
- `a####` / `am####`: tyre auxiliary node/material identity outside the car source-copy subtree.

None is global. A runtime binding additionally requires the vehicle lifecycle generation and material revision.

## Explicit pending work

The fixture marks these phases pending rather than inferring them:

- optional wheel batching;
- registered-but-current-canonical detail toggle;
- hidden mutation/material replacement/hierarchy/geometry fallback;
- dispose and registration removal;
- explosion callback ordering and exact recursive `copyPart` getter calls;
- debris private-clone provenance;
- private batch-entry member-to-proxy relation.
- proxy geometry/layout receipt.

Proxy `member_source_keys` and `geometry_layout_receipt` are therefore null with explicit pending statuses. Absence of a getter call is not treated as a copy rejection, and no visibility waiver is introduced.

No native binder, runtime mutation, authority, HP, physics, GPU, LIVE, or Git work is included.
