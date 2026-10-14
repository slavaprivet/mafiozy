# Transport burn batch fallback identity source proof

Status: **functional executed-source proof for four compact-sedan fallback causes and their dispose ownership; no runtime adoption**.

## Frozen files

| File | SHA-256 |
| --- | --- |
| `tools/godot/export_transport_burn_batch_fallback_identity.mjs` | `0575ebe69db67168cf7a02beb21a524408332eb0a0f0a404f6064745877573fe` |
| `godot/mafiozi_walk/data/transport/source_burn_batch_fallback_identities.json` | `4342dcb0f38af60bcdf45e70326386f3d43025dd7321dbf436d85fad5004b8ad` |
| Frozen initial/body prerequisite | `49a0342fb3260e3963ddfbb0446ace151028dba12fb5f7b3b3ed81290ada2da9` |
| Frozen toggle/dispose prerequisite | `32ebd8a1a6c5cfbfdb121c4e1cb0b4f529a02b39615533332b5fd315c2fff372` |

Machine-readable package metadata is in `docs/godot/TRANSPORT_BURN_BATCH_FALLBACK_IDENTITY_SOURCE_MANIFEST.json`.

## Executed contract

Each case constructs a fresh actual `compact_sedan` through the pinned source factory, damage, rollover, tyre, and body-batch order. Before mutation, the complete initial/body row must be structurally equal to frozen receipt `49a0342f...`; the exporter also verifies that frozen toggle receipt `32ebd8a...` is tied to the same prerequisite.

The proof then mutates one exact source condition and calls the real `body.update()`. It observes the private `WeakMap` through an in-memory, SHA/sentinel-pinned query and records both current material identity and `getVehicleRenderSourceMaterial()` identity. The relevant source paths are `fallback` at `vehicle_render_batches.mjs:104`, the hidden mutation guard at line 118, material/geometry guards at line 122, ancestry guard at line 125, and disposal at line 143.

IDs are scoped to one fresh case and are never global: `m####` canonical materials, `h####` private hidden materials, `r####` caller replacements, and `g####` geometry identities.

## Results

| Fresh case | Exact source nodes leaving batching | Current/getter after update | Dispose ownership result |
| --- | ---: | --- | --- |
| Current material replacement | 1 (`v0005`) | caller replacement `r0000` | replacement retained; zero manager dispose events |
| Shared hidden mutation | 53 exact members sharing `h0000` | retained changed hidden `h0000` | all 53 retain it; zero manager dispose events |
| Geometry identity replacement | 1 (`v0005`) | canonical `m0002`; geometry `g0003` -> `g0267` | caller geometry retained; zero manager dispose events |
| Source reparented to scene | 1 (`v0005`) | canonical `m0002`; parent scope `scene` | detached source remains scene-owned |

This proves that a hidden-material mutation falls back every exact active member sharing that hidden object. It does not assume that only the selected mesh changes. The source removes that changed hidden resource from its owned-disposal set, so actual manager disposal leaves the changed hidden object attached to all 53 fallen-back source meshes. This retained lifetime is recorded explicitly and is not generalized to unrelated resources.

For every case, all unrelated registrations remain byte-structurally equal before disposal. After disposal, every private registration is absent, every saved proxy is unparented, and current/getter identities agree. The replacement and changed-hidden cases retain their caller/source-owned material; unaffected and geometry/reparent fallbacks use canonical material.

## Determinism and cost

Two sequential exports produced byte-identical JSON SHA `4342dcb0...`. The observed command wall times were approximately 3.5 s and 3.7 s. The fixture is 1,183,570 bytes. This is offline authoring-tool cost, not game frame time or FPS.

## Limits and integration dependency

Only these four fresh `compact_sedan` causes are proved. Wheel registration, explosion callback, `copyPart` traversal, debris cloning, other fallback guards, and all-profile fallback coverage remain pending. Proxy member binding and geometry/layout receipts remain pending from the prerequisite.

The prior native baseline gap remains: the production pre-batch taillamp emissive intensity is `1.6199999141693127`, while the visual/native receipt is `0.5`. The host still needs an exact current-state writer and material revision. This package adds no native binder, runtime mutation, authority, HP, physics, rendering, GPU, LIVE, or Git integration.
