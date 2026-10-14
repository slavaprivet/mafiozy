# Transport map registry — isolated candidate V1

Frozen consumer `../map_editor_transport_decor_native_candidate` is unchanged.
This separate registry reads its admitted SHA-addressed geometry, and exposes
the same MapDocument/Controller/Composite record APIs as procedural V3.
No production res://, main, Git or GPU changes are made.

## Actual native tests

Godot 4.7.2 official ed1daf0bf, headless, clean exit:
- Registry 852 checks, zero failures. All 265 original descriptor records;
  parking 233 actual rendered IDs, railway 32 inventoried but held.
- Actual current core Controller 26 checks, zero failures: K lease, native ray
  selecting hospital parking, move/undo, RMB delete/undo, top/fly, palette
  copy/undo/redo, actual JSON MapStore save (266 rows), fresh factory/load.

Parking copy adds only an editor: ID and immutable template_id, admits the
original trusted source descriptor, appends original source transforms/colors
to the existing shared MultiMeshes, and retains original Mesh/Material/UV/
vertex and source routing metadata. CPU bounds expand conservatively. Counts
grow only in those source batches, not via individual resource duplicates.
Discard collapses clone slots; fresh rebuild compacts them. Source 300m parking
culling is unchanged, edits conservatively admit moved parts. Repartition and
reuse of discarded slots remain performance work, not removed content.

All 265 baseline records are JSON-safe core schema objects. Source semantic
IDs include dataset prefix exactly as frozen manifest; they are not renamed.
An unchanged railway record round-trips without constructing fake visuals;
changed/deleted/added railway records fail closed until original station pixel
captures, actual train construction and runtime owner are provided. Rail clone
is explicitly HOLD in V1, not advertised as implemented.

Trusted owner Callable must approve each change and return commit/rollback.
It owns the paused lease, original routes, bays, colliders, vehicle/NPC access,
rail/signal rules and resume. Test owners are mocked; no gameplay acceptance.
No supplied locked/movable/editable boolean grants authority. Dry-run causes no
mutation. Whole installs preflight everything, capture private nonserialized
WeakRef checkpoints, reverse all successful external commits after refusal.
Root/batch lifetime and same-parent ownership, original MM/Mesh/Material
identity must remain intact; invalid dependency retains the owner pause.

Exact original OR exact once-trusted JSON transport immutable admission uses
the shared core trusted_json helper; caller numbers are never normalized.
Tests include adjacent-double-ULP rejection and three fresh save/load cycles.
Native baseline record undo restores exact original CPU part arrays, not a
lossy Euler arithmetic round trip. GPU Dummy storage cannot provide meaningful
MM readback; proof is CPU submitted transforms/resources only.

## APIs

`configure(factory, trusted_owner_callable)` after build_parking + attach root.
`ids/has_object/is_editable/get_record/source_document/current_document`,
`template_frame/world_bounds/pick`, `encode_transform/decode_transform`,
`apply_record(id, record_or_null, dry_run=false)`,
`create_copy(template_id, new_editor_id, native_frame) -> {ok,record}`,
`discard_copy(id)`, `apply_document(document,dry_run=false)`,
`capture_install_checkpoint()/restore_install_checkpoint(capsule) -> {ok}`.
ID dispatch is dictionary O(1); ray picking scans cached parking AABBs.
Call registry.dispose() before factory.dispose() to release host Callables.

## Reproduce

`node tools/godot/map_editor_transport_registry_candidate/stage.mjs --check`
`node tools/godot/map_editor_transport_registry_candidate/stage.mjs --stage`
Default target outputs/map_editor_transport_registry_review.
Run approved Godot console headless at that path, scripts
`res://test_registry.gd`, then `res://test_controller.gd` sequentially.
Original consumer `res://test_transport_decor_factory.gd` also remains included.
Only outputs may be staged, changed existing target bytes are refused.

Controller QA uses its isolated app userdata maps/transport_controller_v1_qa.json
and backup; not production game userdata. GPU visual/shadow/depth/material
parity, station exact pixels, true owners, general-scene p50/p95, complete rail
clone, and unified production integration are OPEN. No FPS or complete map
editor claim follows from these headless checks.
