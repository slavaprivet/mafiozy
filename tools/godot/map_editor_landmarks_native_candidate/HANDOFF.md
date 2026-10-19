# Native protected-landmark resource candidate — frozen

Source SHA `4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c`. No changes to `res://`, catalog, main, authority, Git, GPU windows or live game.

`stage.mjs --check` defaults to read-only; `--stage` copies approved source bytes and code to `outputs/map_editor_landmarks_native_candidate`. Changed existing targets and symlinks are refused. Run Godot 4.7.2 headless with staged project and `--script test_landmarks_resource_factory.gd`.

## Implemented API

- `configure(source_directory, admitted_manifest_sha)` verifies manifest and all binary SHA receipts before resource creation; no scripts/resources are executed from imported documents.
- `build_resources()` creates **267 shared ArrayMesh resources + 22 original MultiMesh groups** for the original **933 source parts**. SHA-keyed geometry reuse preserves exact positions, normals, UVs, indices and interleaved sprite storage. Source CCW triangle winding is changed to native CW without altering source vertex/normal/UV values. Lines retain their source primitive.
- `mesh_resource`, `mesh_upload_arrays`, `multimesh_resource`, `instance_transform_shadow` expose native resources and exact CPU submission snapshots. Public snapshot copies cannot mutate source state. Linear source vertex colors are not gamma-converted. Material recipes are retained verbatim; no default StandardMaterial or substitute bitmap is installed.
- `source_record`, `source_part`, `source_materials`, `texture_dependencies`: immutable-copy source metadata. Canonical POI `police`, topology crossing `XR-RED-01`, and editor keys remain different namespaces. Dormant mainland police decorator stays recipe-only, never fabricated as a new building.
- `placement_plan` provides source/native initial frames, unchanged collider recipe and ownership dependencies. **Two full-canal seawalls are detached dependencies**, excluded from bridge-owned move/delete transforms. Material/light/sprite records and source shadow/render order remain available for the future trusted visual adapter.
- `preview_edit` prepares transform/delete plans without mutation. Conservative mutable culling AABBs include every visible original vertex and all CPU-shadow instance transforms. Source matrices are already native-local using original 4.1 scale and origin; no second scaling is applied.
- `commit_edit(preview, trusted_owner_transaction)`, `undo`, `redo`: bounded 128-entry journal; exact source/model/canonical IDs cannot be edited. Stale/forged plans and rejected callbacks preserve internal state/history/resources. Callback must own an atomic paused transaction and return matching source SHA/editor key, `paused_lease:true`, `collider_nav_committed:true`. Host callback is responsible for its own external rollback on rejection; this resource-only factory does not own game physics or authority and does not claim external atomicity by itself.
- `checkpoint`: state/history and resource-instance identity snapshots. Moves/delete/undo/redo reuse resource identity. `dispose` drops only factory references, not externally retained resources. A resource `changed` signal poisons its old exactness admission so mutated cached resources cannot silently reuse stale receipts.
- `install_scene` **always returns HOLD** in this candidate, including when callables are supplied. It does not create invisible/blank/flat-color replacements. Future scene installation requires independently reviewed original visual adapter plus actual site authority, collider, navigation, doors/release and all texture/sampler owners.

## Verification and honest limits

**353,646 native CPU checks PASS**. Includes all submitted source attribute values, exact indices/winding, CPU-shadow instance transforms, opaque source immutability, every visible vertex inside mutable culling bounds, detached bank identity, move/delete/undo/redo, stale/forged/rejected transaction safety, shared resource identity, invalidation and external lifetime.

Original 823 geometry definitions deduplicate to 267 native meshes; this is sharing identical source buffers, not downsampling. Cold resource build **69,940 μs**; 60 warm bridge previews p50/p95 **1,426/2,346 μs**. These are candidate CPU measurements, not overall game FPS or a comparative full-scene performance claim.

Important discovery: ArrayMesh native normal readback applies Godot octahedral internal encoding (a source zero component can read back approximately `-0.000015259`); headless MultiMesh RenderingServer getters do not provide a reliable uploaded-transform oracle. Accordingly the exact CPU submission shadows are tested, **not presented as exact GPU readback**. Original raw normals/matrices remain unchanged in source/CPU arrays. Original/native visual parity remains a mandatory GPU gate; no quality-loss claim is waived and no scene is admitted.

All **38 original texture dependencies remain HOLD**. No original Canvas pixels/font/environment cube/asphalt/concrete bitmap is captured by this package. No repeated gamma conversion, material color changes, blank text labels or font fallback is used. This is resource readiness only, **not movable police acceptance or an installed map editor**.
