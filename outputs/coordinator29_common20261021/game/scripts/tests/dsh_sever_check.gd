extends SceneTree
## DSH_GORE MeshSever check
##
## Proves the sever is a REAL cut of the skin rather than a swap. It runs on meshes
## whose answer is known in advance, so the check is arithmetic and not a screenshot:
##   1. a CUBE cut through its middle has to come apart into two halves, each one
##      entirely on its own side, with the opening CLOSED by a cap;
##   2. a SKINNED mesh (two bones, real BONES/WEIGHTS attributes) has to keep its bone
##      data on both sides of the cut - that is what lets the surviving body go on
##      deforming with the skeleton while the piece that came off is free;
##   3. the cost has to stay small, because a cut happens once and a body may be cut
##      many times.
## No scene is loaded: this is pure geometry, so it is fast and cannot hang.

const Sever = preload("res://scripts/weapons/mesh_sever.gd")

func _initialize() -> void:
	_run()

## A box as a plain indexed triangle mesh, the same layout a body uses.
func _box_mesh(size: Vector3) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var arrays: Array = box.get_mesh_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## A skinned cylinder: two bones, the bottom weighted to bone 0 and the top to bone 1,
## blended across the middle so a cut actually has to interpolate weights.
func _skinned_cylinder() -> ArrayMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.25
	cylinder.bottom_radius = 0.25
	cylinder.height = 1.6
	cylinder.radial_segments = 12
	cylinder.rings = 8
	var arrays: Array = cylinder.get_mesh_arrays()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(positions.size() * 4)
	weights.resize(positions.size() * 4)
	for i: int in positions.size():
		var t: float = clampf(positions[i].y / 1.6 + 0.5, 0.0, 1.0)
		bones[i * 4] = 0; bones[i * 4 + 1] = 1
		bones[i * 4 + 2] = 0; bones[i * 4 + 3] = 0
		weights[i * 4] = 1.0 - t; weights[i * 4 + 1] = t
		weights[i * 4 + 2] = 0.0; weights[i * 4 + 3] = 0.0
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _run() -> void:
	# --- 1. the cube -------------------------------------------------
	var cube := _box_mesh(Vector3(1.0, 2.0, 1.0))
	var started := Time.get_ticks_usec()
	var cut = Sever.cut(cube, Plane(Vector3.UP, 0.0))
	var cube_us := Time.get_ticks_usec() - started
	var front_verts := 0
	var back_verts := 0
	var front_clean := true
	var back_clean := true
	for arrays: Array in cut.front_arrays:
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		front_verts += points.size()
		for p: Vector3 in points:
			if p.y < -1.0e-4: front_clean = false
	for arrays: Array in cut.back_arrays:
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		back_verts += points.size()
		for p: Vector3 in points:
			if p.y > 1.0e-4: back_clean = false
	print("SEVER_CUBE triangles_in=", cut.triangles_in, " split=", cut.triangles_split,
		" front_verts=", front_verts, " back_verts=", back_verts,
		" boundary_segments=", cut.boundary_segments, " cap_triangles=", cut.cap_triangles,
		" cap_arrays=", cut.front_cap_arrays.size(), " skin_in_cap=",
		(cut.front_cap_arrays.size() > 0 and cut.front_cap_arrays[0][Mesh.ARRAY_BONES] != null),
		" elapsed_us=", cube_us)

	# --- 2. the skinned mesh -----------------------------------------
	var body := _skinned_cylinder()
	var started2 := Time.get_ticks_usec()
	var body_cut = Sever.cut(body, Plane(Vector3.UP, 0.0))
	var body_us := Time.get_ticks_usec() - started2
	var skin_front := false
	var skin_back := false
	var weight_sum_ok := true
	var kept := 0
	for arrays: Array in body_cut.front_arrays:
		if arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null:
			skin_front = true
			var w: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for i: int in count:
				var sum := w[i * 4] + w[i * 4 + 1] + w[i * 4 + 2] + w[i * 4 + 3]
				if absf(sum - 1.0) > 0.02: weight_sum_ok = false
	for arrays: Array in body_cut.back_arrays:
		if arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null:
			skin_back = true
		kept += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	print("SEVER_SKINNED triangles_in=", body_cut.triangles_in, " split=", body_cut.triangles_split,
		" kept_verts=", kept, " cap_triangles=", body_cut.cap_triangles,
		" skin_front=", skin_front, " skin_back=", skin_back,
		" weights_normalised=", weight_sum_ok, " elapsed_us=", body_us)

	var verdict := {
		"cut_is_real": cut.triangles_split > 0 and front_verts > 0 and back_verts > 0,
		"halves_are_on_their_own_side": front_clean and back_clean,
		"opening_is_closed": cut.cap_triangles > 0,
		"cap_carries_its_skinning": cut.front_cap_arrays.size() > 0
			and cut.front_cap_arrays[0][Mesh.ARRAY_BONES] != null,
		"cube_cut_is_fast": cube_us < 20000,
		"skinned_cut_is_real": body_cut.triangles_split > 0 and kept > 0,
		"skinning_survives_on_both_sides": skin_front and skin_back,
		"skin_weights_stay_normalised": weight_sum_ok,
		"body_cut_is_fast": body_us < 60000,
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("SEVER_OBJECTIVE ", JSON.stringify(verdict))
	print("SEVER_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
