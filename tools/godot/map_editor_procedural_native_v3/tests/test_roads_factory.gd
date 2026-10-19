extends SceneTree
const Factory = preload("res://scripts/procedural_factory.gd")
const EXPECTED_SHA := "82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"
var checks := 0
var failures: Array[String] = []
var mode := "allow"
var owner_state: Dictionary = {}
var owner_commits := 0
var owner_rollbacks := 0
var admissions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var locked := Factory.new()
	_expect(locked.configure(EXPECTED_SHA), "locked configure")
	var locked_result: Dictionary = locked.build_roads()
	_expect(locked_result.ok and locked_result.controls == 505 and locked_result.markings == 6449, "all source road IDs built")
	var locked_root: Node3D = locked_result.root
	get_root().add_child(locked_root)
	var locked_signal := ""
	for id in locked._road_ids:
		if str(id).begins_with("traffic-signal"):
			locked_signal = id
			break
	if locked_signal.is_empty():
		locked_signal = str(locked._road_ids.keys()[0])
	var locked_paint: String = locked._paint_ids.keys()[0]
	_expect(not locked.delete_object(locked_signal), "no source dictionary can authorize traffic deletion")
	_expect(not locked.set_object_transform(locked_paint, locked.object_transform(locked_paint)), "paint cannot bypass nav adapter")
	_expect(locked._history.is_empty(), "denied action leaves history empty")
	_expect(not locked.build_exploration().ok, "invalid road-first combined ordering safely refused")
	locked_root.free()
	var factory := Factory.new()
	_expect(factory.configure(EXPECTED_SHA, Callable(self, "_authorize")), "trusted callable admitted")
	var exploration: Dictionary = factory.build_exploration()
	get_root().add_child(exploration.root)
	var result: Dictionary = factory.build_roads()
	get_root().add_child(result.root)
	_expect(result.batches == 67 and factory.road_upload_calls == 8, "eight shared road instance uploads")
	_expect(factory._parts.size() == 2945 and factory._paint_ids.size() == 6449, "combined 9394 stable IDs")
	var part_count := 0
	var paint_vertex_count := 0
	for source: Dictionary in factory._manifest.roads.batches:
		if source.kind == "merged-original-paint":
			var batch: Dictionary = factory._paint_batches[source.key]
			_expect(batch.node.mesh == factory._meshes[source.geometry], "initial paint exact shared source mesh")
			_expect(batch.current.to_byte_array() == factory._buffers[factory._meshes[source.geometry].get_meta("source_geometry").attributes.position.buffer], "original Float32 paint offsets")
			_expect(batch.node.material_override == factory._materials[source.material], "paint original shared material")
			_expect(batch.node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "paint original no shadow")
			for index in source.objectIds.size():
				for vertex in 6:
					_expect(factory.resolve_paint_vertex(source.key, index * 6 + vertex) == str(source.objectIds[index]), "every original paint vertex maps exact stable ID")
					paint_vertex_count += 1
			_expect(factory.resolve_paint_vertex(source.key, source.objectIds.size() * 6) == "", "paint out of range refused")
			continue
		var batch: Dictionary = factory._batches[source.key]
		var values := factory._float_data(source.instanceMatrices)
		var colors := factory._float_data(source.instanceColors) if source.has("instanceColors") else PackedFloat32Array()
		_expect(batch.mesh.mesh == factory._meshes[source.geometry] and batch.node.material_override == factory._materials[source.material], "equipment mesh and material shared exact identity")
		_expect(batch.node.cast_shadow == (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "equipment original shadow state")
		for index in int(source.count):
			_expect(batch.transforms[index] == factory._transform(values, index * 16), "all equipment original matrices exact")
			_expect(factory.resolve_part(source.key, index) == str(source.objectIds[index]), "all parts exact stable ID")
			for row in 3:
				for col in 4:
					_expect(batch.initial_native_buffer[index * int(batch.stride) + row * 4 + col] == values[index * 16 + col * 4 + row], "all row-major upload inputs exact")
			if not colors.is_empty():
				_expect(batch.colors[index] == Color(colors[index * 3], colors[index * 3 + 1], colors[index * 3 + 2]), "original equipment linear RGB exact")
				for channel in 3:
					_expect(batch.initial_native_buffer[index * 16 + 12 + channel] == colors[index * 3 + channel], "RGB bulk fields unchanged")
			part_count += 1
	_expect(part_count == 3571 and paint_vertex_count == 38694, "all 3571 equipment parts and 38694 paint vertices")
	var id: String = factory._road_ids.keys()[0]
	var original := factory.object_transform(id)
	var shifted := original
	shifted.origin += Vector3(900, 0, -20)
	var before := _snapshot(factory)
	var resource_ids := _resource_ids(factory)
	_expect(factory.set_object_transform(id, shifted), "trusted owner commits equipment transform")
	_expect(factory.last_changed_instances == factory._parts[id].size(), "only mapped source parts submitted")
	_verify_only_id(factory, before, id)
	_expect(factory.object_transform(id) == shifted, "source frame updated")
	_expect(factory.undo() and factory.object_transform(id) == original, "equipment undo exact frame")
	_expect(_snapshot(factory) == before and _resource_ids(factory) == resource_ids, "equipment undo exact CPU buffers and shared resource identity")
	_expect(factory.redo() and factory.delete_object(id) and factory.undo() and factory.undo(), "equipment redo delete undo chain")
	_expect(_snapshot(factory) == before, "equipment final rollback exact")
	var paint_id: String = factory._paint_ids.keys()[0]
	var part: Dictionary = factory._paint_ids[paint_id]
	var paint: Dictionary = factory._paint_batches[part.batch]
	var original_mesh: Mesh = paint.node.mesh
	var original_vertices: PackedVector3Array = paint.current.duplicate()
	var paint_frame := factory.object_transform(paint_id)
	var target := paint_frame
	target.origin += Vector3(8, 0, 2)
	_expect(factory.set_object_transform(paint_id, target), "trusted owner paint transform")
	var changed := 0
	for vertex in paint.current.size():
		if paint.current[vertex] != original_vertices[vertex]:
			changed += 1
			_expect(vertex >= int(part.first) and vertex < int(part.first) + 6, "only chosen paint six vertices changed")
	_expect(changed == 6 and factory.last_changed_instances == 6, "six original vertices changed")
	var changed_mesh: Mesh = paint.node.mesh
	_expect(changed_mesh != original_mesh and factory.undo(), "only affected paint chunk rebuilt")
	_expect(paint.node.mesh == original_mesh and paint.current == original_vertices, "paint undo exact original mesh identity and vertices")
	_expect(factory.redo() and paint.node.mesh == changed_mesh, "paint redo exact replacement resource identity")
	_expect(factory.delete_object(paint_id) and factory.undo() and factory.undo(), "paint delete undo transform undo")
	_expect(paint.node.mesh == original_mesh and paint.current == original_vertices, "paint full rollback exact")
	for denied_mode in ["deny", "forged", "fail"]:
		mode = denied_mode
		var history_size: int = factory._history.size()
		var state := _snapshot(factory)
		_expect(not factory.set_object_transform(id, shifted), "equipment owner refusal/invalid/commit failure")
		_expect(_snapshot(factory) == state and factory.object_transform(id) == original and factory._history.size() == history_size, "equipment failed transaction geometry/history exact")
		_expect(not factory.set_object_transform(paint_id, target), "paint owner refusal/invalid/commit failure")
		_expect(paint.node.mesh == original_mesh and paint.current == original_vertices and factory._history.size() == history_size, "paint failed transaction exact resource rollback")
	_expect(owner_rollbacks == 2, "both failed owner commits explicitly rolled back")
	mode = "allow"
	_expect(factory.set_object_transform(id, shifted), "prepare undo refusal")
	mode = "deny"
	_expect(not factory.undo() and factory.object_transform(id) == shifted, "fresh authorization required for undo")
	mode = "allow"
	_expect(factory.undo(), "owner authorizes undo later")
	_expect(not factory.delete_object("forged-source-id"), "unadmitted ID refused")
	print("ROAD_NATIVE_QA ", JSON.stringify({"checks": checks, "failures": failures, "controls": 505, "markings": 6449, "parts": part_count, "paintVertices": paint_vertex_count, "bulkUploads": factory.road_upload_calls, "ownerAdmissions": admissions, "ownerCommits": owner_commits, "ownerRollbacks": owner_rollbacks, "scope": "headless-geometry-inputs-not-GPU-or-traffic-authority"}))
	result.root.free()
	exploration.root.free()
	quit(0 if failures.is_empty() else 1)

func _authorize(request: Dictionary) -> Dictionary:
	admissions += 1
	if mode == "deny":
		return {"approved": false}
	if mode == "forged":
		return {"approved": true, "commit": true, "rollback": true}
	var previous: Variant = owner_state.get(request.sourceId, null)
	return {"approved": true, "commit": Callable(self, "_owner_commit").bind(request.duplicate(true)), "rollback": Callable(self, "_owner_rollback").bind(request.sourceId, previous)}

func _owner_commit(request: Dictionary) -> bool:
	owner_commits += 1
	owner_state[request.sourceId] = request.frameAfter
	return mode != "fail"

func _owner_rollback(id: String, previous: Variant) -> void:
	owner_rollbacks += 1
	if previous == null:
		owner_state.erase(id)
	else:
		owner_state[id] = previous

func _snapshot(factory: RefCounted) -> Dictionary:
	var value: Dictionary = {}
	for key in factory._batches:
		value[key] = factory._batches[key].transforms.duplicate()
	return value

func _resource_ids(factory: RefCounted) -> Dictionary:
	var value: Dictionary = {}
	for key in factory._batches:
		value[key] = [factory._batches[key].mesh.get_instance_id(), factory._batches[key].mesh.mesh.get_instance_id()]
	return value

func _verify_only_id(factory: RefCounted, before: Dictionary, id: String) -> void:
	var allowed: Dictionary = {}
	for part: Dictionary in factory._parts[id]:
		allowed[str(part.batch) + ":" + str(part.index)] = true
	for key in before:
		for index in before[key].size():
			if not allowed.has(str(key) + ":" + str(index)):
				_expect(before[key][index] == factory._batches[key].transforms[index], "other source object slot untouched")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition and failures.size() < 30:
		failures.append(message)
