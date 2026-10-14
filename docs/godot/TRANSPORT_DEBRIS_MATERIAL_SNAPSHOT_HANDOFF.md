# Transport debris post-burn material snapshot candidate

Date: 2026-09-27. Status: **PERFORMANCE REJECTED / DO NOT ADOPT**. This is a
transport-only candidate and headless evidence. It is not connected to Root,
damage authority, the live game, or the exported build.

## Frozen inputs

- Source `assets/maps/city_rebuild_v1/vehicle_damage.mjs`:
  `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92`.
- Physical debris `transport_vehicle_debris.gd`:
  `1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f`.
- Dirty geometry candidate `transport_vehicle_debris_refresh.gd`:
  `d2a4453901465e9310033156baefc751fc74f889bb51a3402da27bf6f34b2479`.
- Candidate `transport_vehicle_debris_material_snapshot.gd`:
  `0e000ba7c30c463fae5ff6390323f1bb36d87c138ebd4673bdd5465102627001`.
- Test `test_transport_vehicle_debris_material_snapshot.gd`:
  `caad7e5edde31933b11af022c7fbd55c51a3fb25170af1b5e92d69b910ee8718`.
- Independent nested-resource review test
  `test_transport_debris_material_snapshot_review.gd`:
  `74320a27830021137fe1e71726c87fe6bf0cb7365a51cdb1e9c701b01ab5a9fa`.

The two frozen dependencies were not edited.

## Exact ordering and API

The source boundary remains:

1. char source materials;
2. finish the `onExplosion` callback;
3. hide glass;
4. stage and commit private debris materials;
5. launch debris and hide detachable source assemblies.

`SOURCE_EXPLOSION_ORDER` records those five steps. The helper does not invoke or
authenticate the callback. Root must call it only after the callback completes.

- `stage_material_snapshot(expected_revision, revision)` duplicates every
  effective active `StandardMaterial3D` and returns an opaque `stage_token`.
- `commit_material_snapshot(stage_token)` validates every source/prepared
  binding before its first write and advances the visual revision atomically.
- `abort_material_snapshot(stage_token)` discards pending private copies.
- `launch_with_visual_revision(motions, expected_visual_revision)` prevents a
  launch without the exact committed receipt. Plain `launch()` fails closed.
- `reset()` invalidates pending and committed receipts. A new monotonically
  advancing material revision is required. After an earlier launch, geometry
  refresh remains sealed by the inherited candidate; dispose and reconfigure
  when new geometry is required.

The transaction checks mesh/surface/material identities, byte signatures of all
stored direct material properties, recursive resource change signals, saved
source hierarchy and poses, prepared body/template ancestry, queued deletion,
and the private snapshot again at launch. Every surface gets its own duplicated
material, including surfaces which shared the same source material. Geometry
refresh is allowed only before the material transaction starts.

## Verification and cost

Safe headless runner: **60/60 author PASS + 60/60 parent PASS**, without script
warnings or errors. It
covers two surfaces sharing one source material, the callback boundary,
source-reset independence, atomic rollback, replacement and in-place mutation,
surface layout changes, stale/foreign tokens, reset, reparenting, queued/free
nodes, prepared body movement, revision gates, launch validation, and explicit
`ShaderMaterial` rejection.

The independent nested-resource review is **8/8 reviewer PASS + 8/8 parent
PASS**. A same-frame source `Gradient` mutation after stage invalidates commit;
a private `Gradient` mutation after commit invalidates launch. The reviewer also
rechecked configure, hierarchy/body reparenting, queued/free nodes, safe receipt
failure, and refresh material-reference continuity, with no correctness blocker
inside the supported `StandardMaterial3D` graph contract.

The actual compact-sedan source explosion order bound indices `0..9`: ten
assemblies, 72 copied meshes and 72 surfaces. Parent's sequential confirmation:

- prepare/configure, outside the impact boundary: `99.819 ms`;
- explosion-frame stage: `29.559 ms`;
- explosion-frame commit: `27.958 ms`;
- stage plus commit: **`57.517 ms`**.

The author's immediately preceding sequential actual run measured `28.434 ms`
stage plus `26.812 ms` commit (`55.246 ms` total), consistent with rejection.

The small two-surface fixture measured `1.212 ms` stage and `0.838 ms` commit.
Caching the immutable `StandardMaterial3D` property-name schema reduced an
earlier actual run from roughly 272 ms to 57.5 ms, while preserving all checks.
The remaining cost is still unacceptable for the same explosion frame, so the
candidate must not be integrated.

## Limits

- Only `StandardMaterial3D` is supported. Other material classes fail closed.
- Direct stored properties are compared byte-for-byte. Nested resource identity
  is included and its resource graph is watched recursively, but correctness
  still depends on nested resources emitting `Resource.changed` when their
  internal content mutates. A resource implementation that mutates silently is
  outside this candidate's proof.
- The helper proves the snapshot it receives. It does not prove that Root
  completed the authoritative char/callback/glass sequence.
- Damage marks are not cloned or managed here. They must remain outside
  detachable assembly subtrees as described in the visual-fidelity review.
- The test is CPU/headless evidence, not full-scene FPS or GPU acceptance.
