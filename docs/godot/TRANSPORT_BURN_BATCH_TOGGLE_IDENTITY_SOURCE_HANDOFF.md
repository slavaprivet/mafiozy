# Transport burn batch detail-toggle and dispose source proof

Status: **functional source proof for body registration, detail off/on, and dispose; no runtime adoption**.

## Frozen files

| File | SHA-256 |
| --- | --- |
| `tools/godot/export_transport_burn_batch_toggle_identity.mjs` | `56e460d2cc8788e7a35c955b22feee9862733a8e451da09c5a81f83044970a35` |
| `godot/mafiozi_walk/data/transport/source_burn_batch_toggle_identities.json` | `32ebd8a1a6c5cfbfdb121c4e1cb0b4f529a02b39615533332b5fd315c2fff372` |
| Frozen prerequisite `godot/mafiozi_walk/data/transport/source_burn_batch_identities.json` | `49a0342fb3260e3963ddfbb0446ace151028dba12fb5f7b3b3ed81290ada2da9` |

Machine-readable package metadata is in `docs/godot/TRANSPORT_BURN_BATCH_TOGGLE_IDENTITY_SOURCE_MANIFEST.json`.

## Scope and method

The new exporter copies no result from the prerequisite. It reconstructs every actual factory, repeats the same SHA/sentinel-pinned private `sourceMaterials` query, and rebuilds the initial and active-body receipt. Before toggling, it requires the entire per-profile row to be `deepEqual` to frozen component `49a0342f…`, including source pins, production material differences, node/material identities, tyre auxiliary receipt, active registrations, hidden sharing, proxy flags, and all explicit pending fields.

It then runs only three additional actual source phases:

1. `setDetailOptimizationEnabled(false)`;
2. `setDetailOptimizationEnabled(true)`;
3. `dispose()`.

Wheel batching, mutation fallback, explosion callback, recursive `copyPart`, and debris material cloning are not executed or inferred.

## Detail optimization disabled

All 1,438 active body registrations persist in the private `WeakMap`.

- 340 registered detail members switch their current material identity from hidden `h####` to canonical `m####`.
- 1,098 registered non-detail members retain current hidden identity.
- For every registered source mesh, `getVehicleRenderSourceMaterial` returns the exact canonical identity.

This is the executed case that distinguishes registered-but-current-canonical from unregistered. Equality of getter and current material is not treated as evidence that registration is absent.

Per-profile registered-current-canonical counts are:

| Profile | Canonical current | Hidden current |
| --- | ---: | ---: |
| `city_hatchback` | 28 | 102 |
| `compact_sedan` | 26 | 95 |
| `family_wagon` | 28 | 100 |
| `executive_sedan` | 26 | 100 |
| `sport_coupe` | 26 | 59 |
| `city_suv` | 30 | 104 |
| `delivery_van` | 22 | 69 |
| `utility_pickup` | 28 | 63 |
| `city_bus` | 24 | 73 |
| `police_interceptor` | 26 | 95 |
| `city_ambulance` | 24 | 69 |
| `fire_engine` | 22 | 74 |
| `city_taxi` | 30 | 95 |

## Detail optimization re-enabled

All detail members return to their exact hidden identities. For every profile, the complete source mesh receipt after re-enable is byte-structurally equal to that profile's original active-body mesh receipt: source key/order, visibility, current IDs, getter IDs, hidden/canonical registration pair, and container kind.

## Dispose

After actual body-manager disposal:

- every source-mesh private registration query returns null;
- every source mesh has canonical `m####` current material;
- getter and current identity are equal;
- no batch proxy remains under the car;
- all 291 saved proxy objects are unparented;
- manager stats report zero active members and batches.

These assertions cover the pristine active lifecycle proven here. Mutation fallback behavior is a separate pending component and is not generalized from dispose.

## Determinism and cost

Two sequential full exports produced identical fixture SHA `32ebd8a1a6c5cfbfdb121c4e1cb0b4f529a02b39615533332b5fd315c2fff372`. Offline wall times were 8,901.619 ms and 8,855.702 ms. The fixture is 9,924,084 bytes. These are authoring-tool measurements, not frame-time or FPS results.

## Preserved dependencies and limits

The unresolved source/native baseline from the prerequisite remains: production pre-batch taillamp emissive intensity is `1.6199999141693127`, while the visual/native receipt is `0.5`. Shared `m####` identity does not waive the property mismatch; a current source-state writer and material revision remain required.

Proxy `member_source_keys` and `geometry_layout_receipt` remain null/pending. Wheel, fallback, callback, copy traversal, and debris provenance remain pending. There is no visibility waiver, global material ID, native binder, runtime mutation, authority, HP, physics, GPU, LIVE, or Git work in this package.
