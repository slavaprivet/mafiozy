extends RefCounted
## Explicit dry extension for the one reviewed Palazzo placement (48.5, 0, 0), yaw -90 degrees.
## Keeps the admitted 31x31 block, water, NPC crop and navigation source unchanged.
## Main owns the Boundary and jump-surface hooks. This helper has no processing/input.

const ROOT_NAME := "PalazzoGroundExtension"
const MIN_X := 43.05
const MAX_X := 59.45
const MIN_Z := -45.1
const MAX_Z := 82.0
const APPROACH_X0 := 38.95
const APPROACH_X1 := 39.5
const APPROACH_Z0 := -11.0
const APPROACH_Z1 := 11.0
const PLAZA_TOP := 0.09

static func contains_world(point: Vector3) -> bool:
	# Match the original jump guard's horizontal surface-domain contract.
	return point.is_finite() and point.x >= MIN_X and point.x <= MAX_X and point.z >= MIN_Z and point.z <= MAX_Z

static func bounds(original: Dictionary) -> Dictionary:
	var minimum: Vector3 = _vector(original.get("min"))
	var maximum: Vector3 = _vector(original.get("max"))
	if not minimum.is_finite() or not maximum.is_finite() or maximum.x <= minimum.x or maximum.z <= minimum.z or maximum.y < minimum.y:
		return {}
	var result: Dictionary = original.duplicate(true)
	# Preserve every untouched original number/type, including JSON doubles.
	if result["max"] is Array:
		result["max"][0] = maxf(float(result["max"][0]), MAX_X)
	else:
		var expanded: Vector3 = result["max"]
		expanded.x = maxf(expanded.x, MAX_X)
		result["max"] = expanded
	return result

static func install(world: Node3D) -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion():
		return {"ok": false, "reason": "world_lifetime"}
	# The fixed coordinates and contains_world use current main's world metre frame.
	if not world.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return {"ok": false, "reason": "world_identity_required"}
	if world.get_node_or_null(NodePath(ROOT_NAME)) != null:
		return {"ok": false, "reason": "ground_already_installed"}
	var materials: Variant = world.get("_surface_materials")
	if not materials is Dictionary or not materials.get("8") is Material:
		return {"ok": false, "reason": "accepted_grass_material_required"}
	var grass: Material = materials["8"]
	var root := Node3D.new()
	root.name = ROOT_NAME
	root.set_meta("palazzo_ground_extension", true)
	root.set_meta("navigation_policy", "outside_unchanged_source_crop_no_npc_entry")
	# Bodies are children of this container, never scene-root candidates of
	# preview_navigation_host's exact authored-source capture.
	var ground := StaticBody3D.new()
	ground.name = "DryGround"
	ground.collision_layer = 1
	ground.collision_mask = 1
	ground.position = Vector3((MIN_X + MAX_X) * 0.5, -0.08, (MIN_Z + MAX_Z) * 0.5)
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(MAX_X - MIN_X, 0.16, MAX_Z - MIN_Z)
	var ground_collision := CollisionShape3D.new()
	ground_collision.shape = ground_shape
	ground.add_child(ground_collision)
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(MAX_X - MIN_X, 0.04, MAX_Z - MIN_Z)
	var ground_visual := MeshInstance3D.new()
	ground_visual.name = "Grass"
	ground_visual.mesh = ground_mesh
	ground_visual.material_override = grass # Read-only reuse of accepted world shader/material.
	ground_visual.position.y = 0.06 # Body centre -0.08, visible centre -0.02, top exactly 0.
	ground_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.add_child(ground_visual)
	root.add_child(ground)

	# Full western edge: sidewalk top 0 at x=38.95, original plaza top .09 at
	# x=39.5. A .55m run gives a 9.3-degree slope, without a new vertical step.
	# The prism extends below existing dry terrain; its top never leaves an air gap.
	var points := PackedVector3Array([
		Vector3(APPROACH_X0, -0.16, APPROACH_Z0), Vector3(APPROACH_X1, -0.16, APPROACH_Z0),
		Vector3(APPROACH_X1, -0.16, APPROACH_Z1), Vector3(APPROACH_X0, -0.16, APPROACH_Z1),
		Vector3(APPROACH_X0, 0.0, APPROACH_Z0), Vector3(APPROACH_X1, PLAZA_TOP, APPROACH_Z0),
		Vector3(APPROACH_X1, PLAZA_TOP, APPROACH_Z1), Vector3(APPROACH_X0, 0.0, APPROACH_Z1)
	])
	var approach := StaticBody3D.new()
	approach.name = "PlazaApproach"
	approach.collision_layer = 1
	approach.collision_mask = 1
	var ramp_shape := ConvexPolygonShape3D.new()
	ramp_shape.points = points
	var ramp_collision := CollisionShape3D.new()
	ramp_collision.shape = ramp_shape
	approach.add_child(ramp_collision)
	var ramp_visual := MeshInstance3D.new()
	ramp_visual.name = "Paving"
	ramp_visual.mesh = _ramp_mesh(points)
	var paving := StandardMaterial3D.new()
	paving.albedo_color = Color("b8b3a2") # Original Palazzo plaza material.
	paving.roughness = 0.72
	ramp_visual.material_override = paving
	ramp_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	approach.add_child(ramp_visual)
	root.add_child(approach)
	world.add_child(root)
	return {"ok": true, "root": root, "ground": ground, "approach": approach,
		"extension_xz": [MIN_X, MIN_Z, MAX_X, MAX_Z], "surface_y": 0.0,
		"approach_xz": [APPROACH_X0, APPROACH_Z0, APPROACH_X1, APPROACH_Z1],
		"approach_rise_m": PLAZA_TOP, "approach_run_m": APPROACH_X1 - APPROACH_X0,
		"native_static_bodies": 2, "source_block_mutated": false, "npc_crop_expanded": false}

static func _ramp_mesh(points: PackedVector3Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	# Clockwise winding seen from outside, matching Godot front faces.
	for indices: Array in [[4,5,6,7], [0,3,2,1], [0,4,7,3], [1,2,6,5], [0,1,5,4], [3,7,6,2]]:
		var a: Vector3 = points[indices[0]]
		var b: Vector3 = points[indices[1]]
		var c: Vector3 = points[indices[2]]
		var normal: Vector3 = (c - a).cross(b - a).normalized()
		for corner: int in [0,1,2,0,2,3]:
			var point: Vector3 = points[indices[corner]]
			vertices.append(point)
			normals.append(normal)
			uvs.append(Vector2(point.x, point.z))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _vector(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		for item: Variant in value:
			if not (item is float or item is int) or not is_finite(float(item)):
				return Vector3(NAN, NAN, NAN)
		return Vector3(value[0], value[1], value[2])
	return Vector3(NAN, NAN, NAN)
