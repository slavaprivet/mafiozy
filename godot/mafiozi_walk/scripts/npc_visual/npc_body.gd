extends "res://scripts/character_physics/exit_ragdoll_body.gd"
## NPC capsule skin envelope includes 15mm solver contact reserve.
func _bind_rest_limits(row: Dictionary) -> void:
	super._bind_rest_limits(row)
	for axis in 3:
		PhysicsServer3D.generic_6dof_joint_set_param(row.node.get_rid(),axis,PhysicsServer3D.G6DOF_JOINT_LINEAR_RESTITUTION,.8)
		PhysicsServer3D.generic_6dof_joint_set_param(row.node.get_rid(),axis,PhysicsServer3D.G6DOF_JOINT_LINEAR_LIMIT_SOFTNESS,1.0)

func _fit_skin(skeleton: Skeleton3D) -> bool:
	var points := {}
	for name: String in BODY_NAMES: points[name] = PackedVector3Array()
	var count := 0
	for node: Node in skeleton.get_parent().find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.skin == null: continue
		var ids: Array[String] = []
		var binds: Array[Transform3D] = []
		for i in mesh.skin.get_bind_count():
			var name := str(mesh.skin.get_bind_name(i))
			# Godot Skin supports named binds and unnamed explicit skeleton indices.
			# A nonempty invalid name must not silently fall back to index zero.
			if name.is_empty():
				var bone := mesh.skin.get_bind_bone(i)
				if bone < 0 or bone >= skeleton.get_bone_count(): return false
				name = str(skeleton.get_bone_name(bone))
			if not _rest.has(name): return false
			ids.append(name); binds.append(mesh.skin.get_bind_pose(i))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			count += vertices.size()
			if count > 20000 or joints.size() != vertices.size()*4 or weights.size() != joints.size(): return false
			for v in vertices.size():
				var world := Vector3.ZERO
				var dominant := ""
				var maximum := 0.0
				for n in 4:
					var index := v*4+n
					var weight := weights[index]
					if weight <= 0: continue
					if joints[index] < 0 or joints[index] >= ids.size(): return false
					var name: String = ids[joints[index]]
					world += (_rest[name] as Transform3D)*binds[joints[index]]*vertices[v]*weight
					if weight > maximum: maximum = weight; dominant = name
				if dominant.is_empty() or not world.is_finite(): return false
				while not points.has(dominant) and not dominant.is_empty(): dominant = _bone_parents[dominant]
				if dominant.is_empty(): dominant = "pelvis"
				points[dominant].append((_rest_body[dominant] as Transform3D).affine_inverse()*world)
	if count == 0: return false
	for name: String in BODY_NAMES:
		if points[name].is_empty(): continue
		var minimum := Vector3(INF,INF,INF); var maximum := Vector3(-INF,-INF,-INF)
		for point: Vector3 in points[name]:
			minimum = minimum.min(point); maximum = maximum.max(point)
		var center := (minimum+maximum)*.5
		var radius := .015
		for point: Vector3 in points[name]: radius = maxf(radius,Vector2(point.x-center.x,point.z-center.z).length())
		var half := maxf(0.0,(maximum.y-minimum.y)*.5-radius)
		for point: Vector3 in points[name]: radius = maxf(radius,(point-center).distance_to(Vector3(0,clampf(point.y-center.y,-half,half),0))+.015)
		if radius > .4 or maximum.y-minimum.y > 1.5: return false
		var frame: Transform3D = _rest_body[name]
		frame.origin += frame.basis*center
		_rest_body[name] = frame
		_bone_to_body[name] = (_rest[name] as Transform3D).affine_inverse()*frame
		_dimensions[name].radius = radius
		_dimensions[name].height = 2.0*(half+radius)
	return true
