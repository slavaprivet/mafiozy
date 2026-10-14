extends SceneTree
const Factory = preload("res://scripts/procedural_factory.gd")
const Registry = preload("res://scripts/procedural_registry.gd")
const Policy = preload("res://scripts/road_visual_policy.gd")
const Document = preload("res://scripts/map_editor/map_document.gd")
const SHA := "82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"
var checks := 0
var failures: Array[String] = []
var mode := "allow"
var commits := 0
var rollbacks := 0
var fail_at := -1
var owner_state: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _make() -> Dictionary:
	var factory := Factory.new()
	_expect(factory.configure(SHA), "source admitted")
	var exploration: Dictionary = factory.build_exploration()
	var roads: Dictionary = factory.build_roads()
	get_root().add_child(exploration.root)
	get_root().add_child(roads.root)
	var policy := Policy.new()
	_expect(policy.configure(factory), "shared visual source policy")
	policy.update(0,null,39)
	var registry := Registry.new()
	_expect(registry.configure(factory,Callable(self,"_admit")).ok, "owner-scoped registry configured")
	return {"factory":factory,"registry":registry,"policy":policy,"exploration":exploration.root,"roads":roads.root}

func _run() -> void:
	var scene := _make()
	var registry: RefCounted = scene.registry
	var factory: RefCounted = scene.factory
	_expect(registry.ids().size() == 9394, "all9394 original IDs accessible")
	var baseline: Dictionary = registry.source_document("fullmap")
	_expect(Document.validate_document(baseline).ok, "actual core schema accepts every original descriptor")
	var pine := ""
	var monument := ""
	var sign_id := ""
	for id: String in registry.ids():
		var row: Dictionary = registry.get_record(id)
		_expect(Document.validate_record(row).ok and registry.world_bounds(id) is AABB, "every source object has core record and bounds")
		if pine.is_empty() and row.kind == "pine": pine = id
		if monument.is_empty() and row.kind == "monument": monument = id
		if sign_id.is_empty() and row.source.dataset == "roads" and not row.kind in ["traffic_signal","center_dash","lane_dash","crosswalk","stop_line","arrow"] and factory._road_ids.has(id): sign_id = id
	var original: Dictionary = registry.get_record(pine)
	var changed := original.duplicate(true)
	changed.transform.position[0] += 7.0
	var frame_before: Transform3D = factory.object_transform(pine)
	var commits_before := commits
	_expect(registry.apply_record(pine,changed,true).ok and factory.object_transform(pine) == frame_before and commits == commits_before, "dryrun readonly")
	var bad := changed.duplicate(true)
	bad.source.descriptor.x += 100
	_expect(not registry.apply_record(pine,bad,true).ok, "poisoned immutable source refused")
	var precision_id := "explore-pine-239"
	var trusted_precision: Dictionary = registry.get_record(precision_id)
	var raw_precision := trusted_precision.duplicate(true)
	raw_precision.source = registry._raw_sources[precision_id].duplicate(true)
	_expect(registry.apply_record(precision_id,raw_precision,true).ok, "exact original trusted number also admitted")
	var neighbour := trusted_precision.duplicate(true)
	var bits := PackedFloat64Array([float(neighbour.source.descriptor.scale)]).to_byte_array()
	bits.encode_u64(0,bits.decode_u64(0)+1)
	neighbour.source.descriptor.scale = bits.decode_double(0)
	_expect(not registry.apply_record(precision_id,neighbour,true).ok, "neighbouring ULP not in either trusted variant rejected")
	_expect(registry.apply_record(pine,changed).ok and registry.get_record(pine) == changed, "existing tree moved by trusted owner")
	_expect(registry.apply_record(pine,null).ok and registry.get_record(pine).is_empty() and registry.world_bounds(pine) == null, "RMB-equivalent tree deletion")
	_expect(registry.apply_record(pine,changed).ok and registry.apply_record(pine,original).ok, "tree deletion/move undo by core record")
	var paint_id := "road-paint-0"
	var paint_original: Dictionary = registry.get_record(paint_id)
	var paint_batch: Dictionary = factory._paint_batches[factory._paint_ids[paint_id].batch]
	var original_paint_mesh: Mesh = paint_batch.node.mesh
	var paint_changed := paint_original.duplicate(true)
	paint_changed.transform.position[0] += 5.0
	_expect(registry.apply_record(paint_id,paint_changed).ok and registry.apply_record(paint_id,paint_original).ok, "existing paint move undo")
	_expect(paint_batch.node.mesh == original_paint_mesh, "core-record paint undo restores exact Mesh resource")
	var capsule: Dictionary = registry.capture_install_checkpoint()
	_expect(capsule.ok, "host non-JSON checkpoint")
	var ids_before: Array = registry.ids()
	var mesh_ids := _mesh_ids(factory)
	var clone_rows: Array = []
	for pair in [[pine,"editor:pine"],[monument,"editor:monument"],[sign_id,"editor:sign"],[paint_id,"editor:paint"],["road-traffic_signal-0","editor:signal"]]:
		var frame: Transform3D = registry.template_frame(pair[0])
		frame.origin += Vector3(23,0,10)
		var created: Dictionary = registry.create_copy(pair[0],pair[1],frame)
		_expect(created.ok, "admitted original template clone")
		if created.ok:
			clone_rows.append(created.record)
			_expect(Document.validate_record(created.record).ok and created.record.template_id == pair[0], "clone exact core schema/template")
			var immutable: Dictionary = created.record.duplicate(true)
			immutable.erase("template_id")
			immutable.id = pair[0]
			immutable.transform = registry.get_record(pair[0]).transform
			_expect(immutable == registry.get_record(pair[0]), "clone immutable source/model preserved")
			_expect(registry.world_bounds(pair[1]) is AABB, "clone bounds available")
	_expect(_mesh_ids(factory) == mesh_ids, "all original MM/Mesh/material resource identities unchanged by clones")
	scene.policy.update(0,null,39)
	_expect(scene.policy._signal_indices.has("editor:signal"), "cloned signal participates in original phase visual policy")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(registry.current_document("fullmap"),"",false,true))
	_expect(saved.objects.size() == 9399 and Document.validate_document(saved).ok, "save JSON exact compatible five new instances")
	var fresh := _make()
	var loaded: Dictionary = fresh.registry.apply_document(saved,true)
	if not loaded.ok: print("FRESH_DRYRUN_ERROR ",loaded)
	_expect(loaded.ok and fresh.registry.ids().size() == 9394, "freshload complete dryrun without clone mutation")
	loaded = fresh.registry.apply_document(saved)
	if not loaded.ok: print("FRESH_INSTALL_ERROR ",loaded)
	_expect(loaded.ok and fresh.registry.ids().size() == 9399, "save to fresh factory recreates all five IDs")
	for row: Dictionary in clone_rows:
		_expect(Registry._equal(fresh.registry.get_record(row.id),row), "fresh clone metadata/transform exact JSON semantics")
	fresh.policy.update(0,null,39)
	_expect(fresh.policy._signal_indices.has("editor:signal"), "fresh cloned signal phases indexed")
	for cycle in 3:
		var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(fresh.registry.current_document("fullmap"),"",false,true))
		_expect(fresh.registry.apply_document(roundtrip).ok, "multiple save-load cycles no immutable drift")
		_expect(Registry._equal(fresh.registry.get_record(precision_id).source,trusted_precision.source), "issued trusted source stays canonical exactly")
	_expect(registry.restore_install_checkpoint(capsule).ok and registry.ids() == ids_before, "whole owner checkpoint restores original IDs")
	_expect(_mesh_ids(factory) == mesh_ids and paint_batch.node.mesh == original_paint_mesh, "checkpoint restores original shared resources")
	var lens_before: Dictionary = scene.policy._submitted.duplicate(true)
	var signal_row: Dictionary = registry.get_record("road-traffic_signal-0")
	signal_row.transform.position[0] += 12
	fail_at = commits+1
	_expect(not registry.apply_record(signal_row.id,signal_row).ok and scene.policy._submitted == lens_before, "failed owner commit restores exact rendered phase/culling overlay")
	fail_at = -1
	_expect(not registry.restore_install_checkpoint({"ok":true,"registry":weakref(registry),"token":RefCounted.new()}).ok, "forged host token refused")
	var atomic_before: Dictionary = registry.current_document("fullmap")
	var desired := atomic_before.duplicate(true)
	var edits := 0
	for row: Dictionary in desired.objects:
		if row.id in [pine,monument]:
			row.transform.position[0] += 9
			edits += 1
	fail_at = commits + 2
	var rollback_before := rollbacks
	_expect(not registry.apply_document(desired).ok, "second owner commit failure fails whole import")
	fail_at = -1
	_expect(registry.current_document("fullmap") == atomic_before and rollbacks >= rollback_before + 2, "whole import exact geometry/records and both owner rollbacks")
	mode = "deny"
	_expect(not registry.create_copy(pine,"editor:denied",registry.template_frame(pine)).ok and not registry.has_object("editor:denied"), "no unauthorized copy")
	mode = "allow"
	var dependency: Node = factory._batches.values()[0].node
	var old_parent: Node = dependency.get_parent()
	var checkpoint: Dictionary = registry.capture_install_checkpoint()
	dependency.reparent(get_root())
	_expect(not registry.restore_install_checkpoint(checkpoint).ok, "reparented source dependency fails closed")
	dependency.reparent(old_parent)
	_expect(registry.restore_install_checkpoint(checkpoint).ok, "same owner repaired dependency restores")
	print("PROCEDURAL_REGISTRY_QA ",JSON.stringify({"checks":checks,"failures":failures,"sourceIds":9394,"clonesSavedFreshloaded":clone_rows.size(),"ownerCommits":commits,"ownerRollbacks":rollbacks,"scope":"native core-schema clone/freshload/checkpoint; GPU/collider authority implementation pending"}))
	scene.exploration.free()
	scene.roads.free()
	fresh.exploration.free()
	fresh.roads.free()
	quit(0 if failures.is_empty() else 1)

func _mesh_ids(factory: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for key in factory._batches:
		var batch: Dictionary = factory._batches[key]
		result[key] = [batch.mesh.get_instance_id(),batch.mesh.mesh.get_instance_id(),batch.node.material_override.get_instance_id()]
	return result

func _admit(request: Dictionary) -> Dictionary:
	if mode == "deny": return {"approved":false}
	if request.dryRun: return {"approved":true}
	var previous: Variant = owner_state.get(request.sourceId,null)
	return {"approved":true,"commit":Callable(self,"_commit").bind(request.duplicate(true)),"rollback":Callable(self,"_rollback").bind(request.sourceId,previous)}

func _commit(request: Dictionary) -> bool:
	commits += 1
	owner_state[request.sourceId] = request.record
	return commits != fail_at

func _rollback(id: String, previous: Variant) -> void:
	rollbacks += 1
	if previous == null: owner_state.erase(id)
	else: owner_state[id] = previous

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition and failures.size() < 40: failures.append(message)
