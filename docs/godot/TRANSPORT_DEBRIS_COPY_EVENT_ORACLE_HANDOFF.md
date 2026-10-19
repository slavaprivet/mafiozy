# Transport debris copy-event executed-source oracle

Status: **frozen test-only source proof; no gameplay adoption**.

This package executes the private `copyPart` / `detachParts` explosion path from the current source vehicle damage factory. It does not reimplement that path. The exporter checks the production files by SHA-256, replaces unique source sentinels only in Node's in-memory module loader, constructs the 12 authored vehicle profiles plus the derived `city_taxi`, admits each through the actual `createVehicleFleet(...).addCar(...)` constructor order, and triggers the actual RPG damage/update boundary. This includes the fleet's mass-derived `maxHp` rule. No source file, Godot transport runtime, physics file, project file, Git state, GPU window, or LIVE scene is changed.

## Frozen files

| File | Bytes | SHA-256 |
|---|---:|---|
| `tools/godot/export_transport_debris_copy_event_oracle.mjs` | 26,791 | `bc7cf288fd898335cfd4c39ec6916710314f5bcbaf41167ddb023cd8e1a51d98` |
| `godot/mafiozi_walk/data/transport/source_debris_copy_event.json` | 5,443,013 | `5c748173306afb6b6acd1136f84749fe0f3196465e841849db415e76a4c59281` |
| `godot/mafiozi_walk/scripts/tests/test_transport_debris_copy_event_oracle.gd` | 14,727 | `660709c9396c3083b2e5fe8c261bca0b5377c58e78541b499f9135e2128e9a4c` |

The JSON is a test fixture. It is not a runtime export dependency.

## Critical source pins

- `assets/maps/city_rebuild_v1/vehicle_damage.mjs`: `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92`
- `assets/maps/city_rebuild_v1/vehicle_render_batches.mjs`: `a9b4c0c93652b52e29a2c29fe65748bdf451122594583d3bd455238f766df648`
- `assets/maps/city_rebuild_v1/vehicle_fleet.mjs`: `7fd414ed74da713da06ee6ea436828e3ace825edc1aa97aa33c57dee28e1e4a8`
- `assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs`: `5dcec7102fc425c7828239ad5de10d4feb29ff7216610fc842333894f811545c`
- frozen source identity receipt `godot/mafiozi_walk/data/transport/source_burn_identities.json`: `38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38`
- Three.js revision: `180`.

The fixture also records every repo source module actually loaded by the exporter and its SHA. All loaded files must be present in the frozen source identity allowlist or the explicit fleet dependency pin set; an unpinned dependency aborts export. The fixture therefore contains and verifies `vehicle_fleet.mjs`, rather than merely naming it as an external reference.

## Exact evidence

The baseline matrix contains all 13 real profiles. Fresh `compact_sedan` instances add five destructive callback cases:

1. callback replaces one currently batched detachable mesh material;
2. callback disables detail batching, leaving canonical and hidden current-material branches according to the real batch owner;
3. callback mutates a hidden material and calls the real batch update, forcing source fallback and registration removal before copy;
4. callback hides original root index 0 before traversal, proving the rejected root consumes no hide/RNG/`getState` and later roots retain original indexes 1 through 9;
5. callback throws.

The fixture has 18 isolated cases, 7,464 ordered events and 157 accepted roots. Every accepted root preserves its original 0-based candidate index and records exactly seven RNG requests, one `getState`, one source hide, and one completed launch. The explicit root-skip case records one rejected top-level index 0, zero hide/RNG/`getState` for it, then completed original indexes 1 through 9. The rejection guard is instrumented as the original ordered short-circuit chain without observer-side predicate rereads. Glass is already hidden before traversal and therefore rejects as `invisible`; reached render-batch proxy subtrees reject as `render_batch`. Both call neither the canonical getter nor copy creation. The hidden-material fallback case removes the reached batch proxy before traversal, which is recorded explicitly.

The event receipt proves this executed order:

`char materials → onExplosion callback → glass hide → ordered roots → recursive copy/getter → source hide → launch RNG/getState`

The callback-throw case proves the source's partial transaction: exact before/after color and roughness receipts show every captured opaque material changed before the throw, while callback return, glass hide, traversal, source hide, RNG, `getState`, and debris creation never occur. A future native seam must choose and document whether to reproduce this partial behavior; an all-or-nothing native transaction is stronger and is not source-exact.

The canonical getter receipt stores object-identity namespaces, not color/name equivalence: original `m####`, current hidden/replacement/private `xmat####`, source node `v####`, auxiliary/copy node `x####`. Every geometry attribute and index buffer, transform matrix, group, and material container is bounded by exact counts/types/SHA-256 digests instead of embedding complete buffers. RNG and `getState` events carry the original root index, and the test verifies the exact per-root tail `hide → random → random → getState → random ×5 → complete`, including global RNG cursor continuity. The exporter injects fixed RNG return values only at the seven actual source call sites so repeat exports are byte-identical; it does not rewrite the launch formula or order.

## Verification

- Export command: `node tools/godot/export_transport_debris_copy_event_oracle.mjs`
- Two consecutive final exports were byte-identical at `5c748173…`; the last took about 8.7 seconds in the isolated source harness.
- Godot 4.7.2 safe runner: `tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_debris_copy_event_oracle.gd -TimeoutSeconds 60`
- Author result: **3540/3540 PASS**, exit 0.
- Godot JSON open/parse/validation cost in the final author run: **184,077 µs** for the 5,443,013-byte test fixture.

These are offline exporter and headless test costs. They are not event-frame cost, full-scene frame time, GPU behavior, or FPS evidence.

## Root dependencies and limits

- This package supplies evidence only. It has no native event API, lifecycle generation, material revision, authoritative explosion identity, HP ownership, callback authority, physics spawn, render integration, or exactly-once receipt.
- The callback matrix is all-profile baseline plus bounded compact-sedan destructive variants. It does not claim all-profile fallback equivalence.
- Wheel batch ownership remains outside this proof. Body/interior/door source getter identity is observed only where the actual explosion traversal reaches it.
- The production callback can replace, reparent, hide, mutate, or throw before traversal. A future Root-owned seam must bind the current vehicle/profile/generation/material revision after callback and before any native mutation.
- The existing frozen native debris component remains independently authoritative for prepared real geometry and collision. This fixture does not authorize connecting source event rows to it.
- No render-batch proxy member map, native surface binder, main-scene hook, LIVE check, or shared Git change is included.
