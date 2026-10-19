extends SceneTree
const Factory = preload("res://landmarks_resource_factory.gd")
const SOURCE_SHA := "4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c"
var checks := 0
var failed := false

func require(condition: bool, reason: String) -> void:
	checks += 1
	if not condition:
		if not failed: push_error(reason)
		failed = true

func _init() -> void:
	var factory = Factory.new()
	require(not factory.configure("res://source", "0".repeat(64)).ok, "Reject wrong SHA")
	require(factory.configure("res://source", SOURCE_SHA).ok, "Configure source")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://source/manifest.json"))
	var buffers := {}
	for row in source.buffers: buffers[row.sha256] = row.file
	var cold_start := Time.get_ticks_usec()
	var built: Dictionary = factory.build_resources()
	var cold_us := Time.get_ticks_usec() - cold_start
	require(built.ok and not built.scene_admitted, "CPU-only resources")
	for geometry in source.geometries:
		var line_geometry: bool = source.parts.any(func(p: Dictionary) -> bool: return p.get("geometry") == geometry.id and p.type == "LineSegments")
		var primitive := Mesh.PRIMITIVE_LINES if line_geometry else Mesh.PRIMITIVE_TRIANGLES
		var mesh: ArrayMesh = factory.mesh_resource(geometry.id, primitive)
		require(mesh != null and mesh == factory.mesh_resource(geometry.id, primitive), "Cached shared mesh")
		if mesh == null: continue
		var arrays: Array = factory.mesh_upload_arrays(geometry.id, primitive)
		for pair in [["position", Mesh.ARRAY_VERTEX, 3], ["normal", Mesh.ARRAY_NORMAL, 3], ["uv", Mesh.ARRAY_TEX_UV, 2]]:
			if not geometry.attributes.has(pair[0]): continue
			var a: Dictionary = geometry.attributes[pair[0]]
			var raw := FileAccess.get_file_as_bytes("res://source/" + str(buffers[a.buffer])).to_float32_array()
			var stride := int(a.get("stride", a.itemSize))
			var offset := int(a.get("offset", 0))
			var native: Variant = arrays[pair[1]]
			require(native.size() == int(a.count), "Exact attribute count")
			for i in range(int(a.count)):
				for component in range(int(pair[2])): require(is_equal_approx(native[i][component], raw[i * stride + offset + component]), "Source attribute parity " + str(pair[0]) + " " + str(native[i][component]) + " vs " + str(raw[i * stride + offset + component]))
		var expected := PackedInt32Array()
		if geometry.index == null:
			for i in range(int(geometry.attributes.position.count)): expected.append(i)
		else:
			var a: Dictionary = geometry.index
			var bytes := FileAccess.get_file_as_bytes("res://source/" + str(buffers[a.buffer]))
			for i in range(int(a.count)): expected.append(bytes.decode_u16(i * 2) if a.arrayType == "Uint16Array" else bytes.decode_u32(i * 4))
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(expected.size()):
			var source_index: int = i if primitive == Mesh.PRIMITIVE_LINES else i - i % 3 + ([0, 2, 1][i % 3])
			require(indices[i] == expected[source_index], "Exact winding bridge")
	for part in source.parts:
		require(factory.source_part(part.id) == part, "Opaque source part immutable")
		if not part.has("matrices"): continue
		var resource: MultiMesh = factory.multimesh_resource(part.id)
		require(resource != null and resource == factory.multimesh_resource(part.id), "Shared original instances")
		var original := FileAccess.get_file_as_bytes("res://source/" + str(buffers[part.matrices.buffer])).to_float32_array()
		for i in range(int(part.count)): require(factory.instance_transform_shadow(part.id, i).is_equal_approx(Factory.source_transform(original, i * 16)), "Source instance transforms")
		var caller_copy: Dictionary = factory.source_part(part.id)
		caller_copy.name = "tamper"
		require(factory.source_part(part.id).name == part.name, "Immutable public input")
	var initial: Dictionary = factory.checkpoint()
	print("Resource census: ", built, "; cold resources CPU us=", cold_us)
	var bridge := "protected-landmarks:red-bridge"
	var plan: Dictionary = factory.placement_plan(bridge)
	require(plan.detached_dependencies.size() == 2 and plan.owned_parts.size() == 190, "Two canal banks outside movable bridge")
	require(factory.source_record(bridge).canonicalGameId == null, "No invented bridge authority")
	require(factory.source_record("protected-landmarks:police-island").canonicalGameId == "police", "Canonical POI separate")
	var move := Transform3D(Basis.IDENTITY, Vector3(1000, 0, -1200))
	var preview: Dictionary = factory.preview_edit(bridge, move)
	for key in [bridge, "protected-landmarks:police-island"]:
		var culling_plan: Dictionary = factory.placement_plan(key)
		var culling: AABB = culling_plan.culling_aabb.grow(0.001)
		for item in culling_plan.owned_parts:
			var part: Dictionary = factory.source_part(item.part_id)
			if not part.has("geometry") or part.type == "Sprite" or not item.visible: continue
			var primitive := Mesh.PRIMITIVE_LINES if part.type == "LineSegments" else Mesh.PRIMITIVE_TRIANGLES
			var vertices: PackedVector3Array = factory.mesh_upload_arrays(part.geometry, primitive)[Mesh.ARRAY_VERTEX]
			for instance_index in range(int(part.get("count", 1))):
				var frame: Transform3D = item.frame
				if part.has("matrices"): frame *= factory.instance_transform_shadow(part.id, instance_index)
				for vertex in vertices: require(culling.has_point(frame * vertex), "Culling includes every original visible vertex")
	var samples := PackedInt64Array()
	for i in range(60):
		var started := Time.get_ticks_usec()
		var warm: Dictionary = factory.preview_edit(bridge, Transform3D(Basis.IDENTITY, Vector3(i, 0, -i)))
		require(warm.ok, "Warm source-plan preview")
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	print("Warm bridge preview CPU p50/p95 us=", samples[29], "/", samples[56], "; no GPU/FPS claim")
	require(preview.ok and preview.culling_aabb.position.x > plan.culling_aabb.position.x + 900, "Moved culling bounds")
	require(preview.detached_dependencies == plan.detached_dependencies, "Seawalls unchanged")
	require(not factory.commit_edit(preview, Callable()).ok, "No owner self-unlock")
	require(factory.checkpoint() == initial, "Rejected edit checkpoint unchanged")
	var denied := func(_request: Dictionary) -> Dictionary: return {"ok": false}
	require(not factory.commit_edit(preview, denied).ok and factory.checkpoint() == initial, "Callback failure atomic")
	var owner := func(request: Dictionary) -> Dictionary: return {"ok": true, "source_sha256": SOURCE_SHA, "key": request.key, "paused_lease": true, "collider_nav_committed": true}
	require(factory.commit_edit(preview, owner).ok, "Explicit fake test owner transaction")
	var moved: Dictionary = factory.checkpoint()
	require(initial.mesh_ids == moved.mesh_ids and initial.multimesh_ids == moved.multimesh_ids, "Edit resource identity")
	require(factory.undo(owner).ok and factory.state(bridge).delta == Transform3D.IDENTITY, "Undo")
	require(factory.redo(owner).ok and factory.state(bridge).delta == move, "Redo")
	var deletion: Dictionary = factory.preview_edit(bridge, move, true)
	require(not deletion.has_visible_bounds and deletion.detached_dependencies == plan.detached_dependencies, "Delete preserves detached banks")
	require(factory.commit_edit(deletion, owner).ok and factory.undo(owner).ok, "Delete and undo transaction")
	var forged: Dictionary = factory.preview_edit(bridge, move)
	forged.source_record.canonicalGameId = "fake"
	require(not factory.commit_edit(forged, owner).ok, "Forged metadata rejected")
	require(factory.source_materials() == source.materials and factory.texture_dependencies() == source.textures, "No recipe/gamma/sampler mutation")
	var host := Node3D.new()
	require(factory.install_scene(host).status == "HOLD" and host.get_child_count() == 0, "No blank/default scene installation")
	host.free()
	var retained: ArrayMesh = factory.mesh_resource(source.geometries[0].id)
	retained.emit_changed()
	require(factory.mesh_resource(source.geometries[0].id) == null, "Externally changed resource cannot reuse stale exactness receipt")
	factory.dispose()
	require(is_instance_valid(retained) and retained.get_surface_count() == 1, "External resource lifetime retained")
	print("PASS" if not failed else "FAIL", " landmarks resource factory: ", checks, " CPU checks; source38 texture and owner gates HOLD")
	quit(1 if failed else 0)
