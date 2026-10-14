# V3 source-admitted procedural editor registry — frozen candidate

Code-only candidate outside the production Godot project. `stage.mjs --check` is read-only; `--stage` verifies fixed original manifest/dependencies/catalog/all 982 buffers and exclusively creates `outputs/map_editor_procedural_review_v3`, refusing changed existing files/symlinks. It generates actual original Three source LOD and road-policy oracles, then copies frozen factory/registry/native Controller fixtures. V1/V2 stay frozen separately.

## Verified native milestones

- Original exploration: **448,582 checks**, 2,440 IDs/28,718 parts, 464 shared uploads, original 64/180/8 LOD.
- Original roads/edit ownership: **134,894 checks**, 505 controls/6,449 markings, 3,571 equipment parts/eight uploads/38,694 paint vertices/59 paint chunks.
- Original road visual policy: **63,909 checks**, 17 actual source time/focus states, original 112 equipment spheres, 59 paint spheres, 60 phases/180 exact Float32 bulb matrices per state, maximum difference zero. Idle unchanged focus/time has zero distance checks/writes.
- Registry: **9,458 checks**, all 9,394 original IDs/JSON records/bounds, moves/deletes/undo, five new admitted template copies (pine, monument, road sign, paint, traffic signal), full save→fresh factory recreation, three further save/load cycles, whole-import rollback on a later owner failure, exact shared-resource identity and live-parent checkpoint guards.
- Actual existing native Controller: **26 checks**, K lease, camera ray selects source pine, move/undo, actual short RMB delete/undo, top/flight, palette add/undo/redo, actual MapStore file save (9,395 records), new Controller+factory recreates the added tree, K exit.
- Native original glTF emission oracle: one check. No GPU visual proof.

Native tests run headless sequentially. Main headless Window is fixed 64×64, so Controller test uses a real native 1280×720 SubViewport with rendering disabled, not a new GPU window. MapStore writes only the isolated QA application's `user://maps/procedural_controller_v3_qa.json`; gameplay edit/play/physics owner gates are mocked, not real server/collider integration.

## Public registry contract

`configure(admitted_factory, trusted_owner_callable)`; both original systems must be built and their roots inside the tree. JSON record uses the existing core schema:

```json
{"id":"original-id","kind":"pine","model":"procedural:pine","source":{"dataset":"exploration","descriptor":{}},"transform":{"position":[0,0,0],"rotation":[0,0,0],"scale":[1,1,1]}}
```

The descriptor is the admitted original source object, not caller data. Copies add **only** `template_id` and a new `editor:` ID; no alternate basis/deleted/is_copy fields. Presence/absence in MapDoc encodes deletion. Original source descriptors remain separately immutable; issued metadata is their once-canonical trusted JSON transport. A real Godot 64-bit JSON case moved scale `0.9020102752285311` by one ULP on transport. Only exact original or exact deterministic trusted transport is accepted, never caller normalization/epsilon. Byte-constructed next-neighbour ULP is rejected; repeated save/load cycles retain exact canonical source. `trusted_json.gd` is the shared core helper copied unchanged for this frozen fixture.

Methods: `ids`, `has_object`, `get_record` (empty if deleted), `source_document(map_id)` (original baseline only, excludes copies), `current_document(map_id)` (current live originals/copies), `is_editable` (owner dry-run gate), `template_frame`, `world_bounds` (cached native AABB/null), `pick(origin,direction,distance)->String`, static `encode_transform`/`decode_transform`, `apply_record(id,record_or_null,dry_run=false)`, `apply_document(document,dry_run=false)`, `create_copy(template_id,new_id,frame)->{ok,record}`, `discard_copy(id)->void`.

All mutation requires a fresh host Callable prepare with valid commit/rollback Callables; road policy/traffic/collider/navigation flags cannot self-authorize. Dry-run does not change geometry or commit authority. Source record/model/template and transform-extra metadata cannot change. Transform vector roundtrips that decode to the same native frame do not rewrite 9,394 unchanged entries during import. Copies append their admitted original parts into existing shared MM/chunks, preserving per-part original Mesh/material/LOD; paint copies append their exact six vertices/normals/winding into only their original chunk. Source manifest/cached source geometry resources are not mutated. Cloned traffic lenses use the exact original basis/offsets and current source phase. Dirty bounds conservatively expand; moving copies far apart can retain a broad original chunk and increase work, so mutable-plan spatial repartition remains a future owner optimization, not a visual simplification.

`capture_install_checkpoint()->{ok,registry:WeakRef,token:RefCounted,geometryOnly:true}` / `restore_install_checkpoint(capsule)->{ok}`: nonserializable host-token admission, exact original MM/Mesh/material resource identities, counts/CPU arrays/frames/history/paint/LOD bounds and submitted road visual overlays. Original live nodes/same parent/node→MM ownership preflight before restore; destroyed/reparented original dependency fails closed, owner must retain pause. Incoming capsule dictionary cannot supply restoration state. Whole apply-document preflights every ID/template, checkpoints, then journals successful external owner rollbacks in reverse on later failure. The outer composite owner remains responsible for its gameplay/lease checkpoint. `discard_copy` removes its identity and collapses reserved append slots without shifting other source indices; those slots compact on checkpoint/fresh rebuild, not by mutating others' IDs.

## Remaining gates

Actual GPU color/material/normal/shadow/depth-bias comparison, native paint polygonOffset equivalence, source gameplay collision/navigation/traffic authority integration, actual unified production workspace/UI installation and comparable full-scene p50/p95 are **not** verified. Headless Dummy cannot read back MultiMesh storage: exact submitted CPU overlays/resources are proven, not GPU readback. Source normal inputs are exact; native normal codec normalizes/octpacks with maximum direction error 0.0001294055. Original geometries/LOD/density/material scalar metadata are not intentionally reduced; no unqualified visually lossless/full editor/full traffic/full-world completion claim is made.
