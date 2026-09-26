extends SceneTree
## Offline actual Godot import against exported source-controller/geometry oracle.
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
var failures: Array[String] = []
var checks := 0
var checked_vertices := 0
var max_position_error := 0.0
var max_matrix_error := 0.0
var limits: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _matrix(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]), Vector3(values[4], values[5], values[6]), Vector3(values[8], values[9], values[10])), Vector3(values[12], values[13], values[14]))

func _point(values: Array, index: int) -> Vector3:
	return Vector3(values[index * 3], values[index * 3 + 1], values[index * 3 + 2])

func _transform_error(actual: Transform3D, expected: Transform3D) -> float:
	var result := actual.origin.distance_to(expected.origin)
	for axis in 3:
		result = maxf(result, actual.basis[axis].distance_to(expected.basis[axis]))
	return result

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://../../outputs/coordinator21_vehicle_visual")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-directory="):
			directory = argument.trim_prefix("--visual-directory=")
	var catalogue: Dictionary = Visual.load_catalogue(directory.path_join("manifest.json"))
	_check(catalogue.get("ok", false), "catalogue")
	if not catalogue.get("ok", false):
		_finish()
		return
	for id: String in catalogue.entries:
		var entry: Dictionary = catalogue.entries[id]
		var started := Time.get_ticks_usec()
		var result: Dictionary = Visual.instantiate_visual(entry, directory)
		_check(result.get("ok", false), id + ": import " + str(result.get("error", "")))
		if not result.get("ok", false):
			continue
		var visual: RefCounted = result.visual
		root.add_child(visual.root)
		var oracle_bytes := FileAccess.get_file_as_bytes(directory.path_join(id + ".oracle.json"))
		_check(Visual._sha(oracle_bytes) == entry.oracle_sha256, id + ": oracle hash")
		var oracle: Dictionary = JSON.parse_string(oracle_bytes.get_string_from_utf8())
		var source_nodes: Dictionary = {}
		for row: Dictionary in oracle.nodes:
			source_nodes[row.key] = row
			var node: Node3D = visual.nodes.get(row.key)
			var error := _transform_error(node.global_transform, _matrix(row.world_matrix))
			max_matrix_error = maxf(max_matrix_error, error)
			_check(error < 0.00002, id + ": rest matrix " + row.key)
			_check(node.visible == row.visible, id + ": source visibility " + row.key)
		for row: Dictionary in oracle.meshes:
			var source_positions: Array = row.attributes.position.values
			var source_indices: Array = []
			if row.indices != null:
				source_indices = row.indices
			else:
				for i in source_positions.size() / 3:
					source_indices.append(i)
			var candidate: Node3D = visual.nodes[row.key]
			if source_indices.is_empty():
				_check(not candidate is MeshInstance3D or candidate.mesh == null, id + ": empty source geometry " + row.key)
				continue
			_check(candidate is MeshInstance3D, id + ": missing source mesh " + row.key)
			if not candidate is MeshInstance3D:
				continue
			var node := candidate as MeshInstance3D
			var mesh := node.mesh as ArrayMesh
			var groups: Array = row.groups
			if groups.is_empty():
				groups = [{"start": 0, "count": source_indices.size(), "materialIndex": 0}]
			# Three exporter ignores geometry groups for a scalar material.
			if row.materials.size() == 1:
				groups = [{"start": 0, "count": source_indices.size(), "materialIndex": 0}]
			_check(mesh.get_surface_count() == groups.size(), id + ": surface count " + row.key)
			if mesh.get_surface_count() != groups.size():
				continue
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var group: Dictionary = groups[surface]
				_check(indices.size() == int(group.count), id + ": index count " + row.key)
				if indices.size() != int(group.count):
					continue
				var local_error := 0.0
				for triangle in indices.size() / 3:
					for corner in 3:
						var source_index := int(source_indices[int(group.start) + triangle * 3 + corner])
						# Godot's front-face winding reverses glTF's CCW triangles.
						var native_index := indices[triangle * 3 + ([0, 2, 1][corner])]
						local_error = maxf(local_error, positions[native_index].distance_to(_point(source_positions, source_index)))
						checked_vertices += 1
				max_position_error = maxf(max_position_error, local_error)
				_check(local_error < 0.00002, id + ": triangle positions " + row.key + " error=" + str(local_error))
		for sample: Dictionary in oracle.samples:
			for door_id: String in visual.doors:
				_check(visual.set_door_amount(door_id, sample.door_amount), id + ": door control")
			_check(visual.update_wheels(sample.steer, sample.distance_delta_m), id + ": wheel control")
			for key: String in sample.nodes:
				var node: Node3D = visual.nodes[key]
				var error := _transform_error(node.global_transform, _matrix(sample.nodes[key]))
				max_matrix_error = maxf(max_matrix_error, error)
				_check(error < 0.00003, id + ": animated matrix " + key + " error=" + str(error))
		_check(not visual.set_door_amount("not_a_door", 1.0), id + ": invalid door")
		_check(not visual.set_door_amount("front_left", NAN), id + ": nonfinite door")
		_check(not visual.update_wheels(NAN, 0.0), id + ": nonfinite wheel")
		visual.dispose()
		_check(not visual.update_wheels(0.0, 1.0), id + ": disposed update")
		print("VEHICLE_VISUAL_PROFILE ", id, " import_and_verify_us=", Time.get_ticks_usec() - started)
	limits.append("Native rendered materials, emission/glass/KHR extensions, main/LIVE/GPU and damage are not verified by this geometry test")
	_finish()

func _finish() -> void:
	print(JSON.stringify({"checks": checks, "failures": failures, "triangle_corners": checked_vertices, "max_local_position_error_m": max_position_error, "max_matrix_error": max_matrix_error, "limits": limits}))
	quit(0 if failures.is_empty() else 1)
