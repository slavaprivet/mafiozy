extends "res://scripts/character_physics/exit_ragdoll_body.gd"
## Core original-skin boxes separate torso width from depth; limbs preserve
## the original capsule fitting. Every assigned REST vertex has15mm reserve.
## This is not a guarantee for arbitrary later multi-bone blended skin poses.
const CORE_NAMES := ["pelvis","spine_01","chest"]
const CORE_RESERVE_M := .015
var _core_fits: Dictionary = {}
var _core_boxes: Dictionary = {}
var core_fit_report: Dictionary = {"mode":"UNCONFIGURED"}

func configure(skeleton: Skeleton3D, parent: Node3D, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super.configure(skeleton,parent,options)
	if not result.get("ok",false):return result
	# Base configure has created disabled shapes on frozen bodies. Replace only
	# resources: identical body/bone frames, joints, masses and filter authority.
	var prepared: Dictionary = {}
	for name: String in CORE_NAMES:
		if not _core_fits.has(name):return _core_fallback(result,"missing_core_points:"+name)
		var fit: Dictionary = _core_fits[name]
		var body: RigidBody3D = _bodies[name]
		var collision: CollisionShape3D = _shapes[name]
		if not fit.get("valid",false) or not body.freeze or not collision.disabled or not collision.shape is CapsuleShape3D or collision.transform!=Transform3D.IDENTITY:return _core_fallback(result,"core_shape_guard:"+name)
		var box := BoxShape3D.new()
		box.size = fit.size
		prepared[name] = box
	for name: String in CORE_NAMES:
		var collision: CollisionShape3D = _shapes[name]
		_core_boxes[name] = {"size":_core_fits[name].size,"baseline_capsule":collision.shape}
		collision.shape = prepared[name]
	core_fit_report = {"mode":"CORE_BOXES","reserve_m":CORE_RESERVE_M,"cores":_core_fits.duplicate(true),"body_count":_bodies.size(),"joint_count":_joints.size(),"baseline_limbs":"CAPSULE_UNCHANGED","binding_frames_changed":false,"runtime_pose_enclosure":"NOT_GUARANTEED_BY_REST_FIT"}
	result.core_fit = core_fit_report.duplicate(true)
	return result

func _core_fallback(result: Dictionary, reason: String) -> Dictionary:
	# Preparation is atomic: no resource has been replaced on any fallback path.
	core_fit_report = {"mode":"BASELINE_CAPSULE_FALLBACK","reason":reason,"reserve_m":CORE_RESERVE_M,"candidate_acceptance":false}
	result.core_fit = core_fit_report.duplicate(true)
	return result

static func core_box_fit(points: PackedVector3Array) -> Dictionary:
	if points.is_empty():return {"valid":false,"reason":"empty"}
	var minimum := Vector3(INF,INF,INF)
	var maximum := Vector3(-INF,-INF,-INF)
	for point: Vector3 in points:
		if not point.is_finite():return {"valid":false,"reason":"nonfinite"}
		minimum = minimum.min(point);maximum = maximum.max(point)
	var center := (minimum+maximum)*.5
	var size := maximum-minimum+Vector3.ONE*(2.0*CORE_RESERVE_M)
	if not size.is_finite() or size[size.min_axis_index()]<2.0*CORE_RESERVE_M or size[size.max_axis_index()]>1.5:return {"valid":false,"reason":"extent"}
	var reserve_min := INF
	for point: Vector3 in points:
		var clearance: Vector3 = size*.5-(point-center).abs()
		reserve_min = minf(reserve_min,clearance[clearance.min_axis_index()])
	# Native Vector3 arithmetic is float32; one micrometre arithmetic reserve.
	if reserve_min<CORE_RESERVE_M-.000001:return {"valid":false,"reason":"enclosure"}
	return {"valid":true,"size":size,"center":center,"min_assigned_vertex_reserve_m":reserve_min,"assigned_vertices":points.size(),"rest_minimum":minimum,"rest_maximum":maximum}

static func fitted_distance(local: Vector3, dimensions: Dictionary, box_size: Vector3 = Vector3.ZERO) -> float:
	if box_size!=Vector3.ZERO:
		return (local.abs()-box_size*.5).max(Vector3.ZERO).length()
	# This is the inherited capsule formula, unchanged for all13 other parts.
	var half := maxf(0.0,float(dimensions.height)*.5-float(dimensions.radius))
	var nearest := Vector3(0,clampf(local.y,-half,half),0)
	return maxf(0.0,local.distance_to(nearest)-float(dimensions.radius))

func apply_impulse(world_point: Vector3, impulse_ns: Vector3, event_id: String = "") -> Dictionary:
	if not _active or _paused or _disposed or not world_point.is_finite() or not impulse_ns.is_finite() or impulse_ns.length()>MAX_IMPULSE_NS:return {"ok":false,"error":"inactive_or_impulse"}
	if not _pool_valid():return {"ok":false,"error":"damaged_pool"}
	var selected := ""
	var distance := INF
	for name: String in BODY_NAMES:
		var body: RigidBody3D = _bodies[name]
		var local: Vector3 = body.global_transform.affine_inverse()*world_point
		var size: Vector3 = _core_boxes[name].size if _core_boxes.has(name) else Vector3.ZERO
		var next := fitted_distance(local,_dimensions[name],size)
		if next<distance:selected = name;distance = next
	if distance>.75:return {"ok":false,"error":"outside_body"}
	var body: RigidBody3D = _bodies[selected]
	body.sleeping = false
	body.apply_impulse(impulse_ns,world_point-body.global_position)
	return {"ok":true,"error":"","bone":selected,"event_id":event_id,"distance_m":distance}

static func authored_joint_anchors(parent_rest_body: Transform3D,child_rest_body: Transform3D,child_rest_bone: Transform3D) -> Dictionary:
	# Body frames are already fitted to the unchanged original skin at configure.
	# Anatomical attachment points are lifetime constants, not solver output.
	return {"a":parent_rest_body.affine_inverse()*child_rest_bone.origin,"b":child_rest_body.affine_inverse()*child_rest_bone.origin}

func _bind_rest_limits(row: Dictionary) -> void:
	# Base start() deliberately places current native bodies and supplies both
	# refs at the outgoing child origin. Reusing that measured position on each
	# interrupted get-up embeds the previous solver's translation error into a
	# new rest length. Restore the authored LOCAL anchors before the engine
	# creates its constraint; only the real native solver moves physical parts.
	var anchors:=authored_joint_anchors(_rest_body[row.parent],_rest_body[row.child],_rest[row.child])
	var previous_a: Vector3=row.a;var previous_b: Vector3=row.b
	row.a=anchors.a;row.b=anchors.b
	if not core_fit_report.has("joint_anchor_rebind"):core_fit_report.joint_anchor_rebind={"policy":"fixed_authored_body_local_anchors","bind_calls":0,"latest":{}}
	var report: Dictionary=core_fit_report.joint_anchor_rebind
	report.bind_calls+=1
	report.latest[str(row.child)]={"a":row.a,"b":row.b,"discarded_parent_rebase_m":previous_a.distance_to(row.a),"discarded_child_rebase_m":previous_b.distance_to(row.b),"native_initial_anchor_gap_m":(_bodies[row.parent].global_transform*row.a).distance_to(_bodies[row.child].global_transform*row.b)}
	super._bind_rest_limits(row)
	for axis in 3:
		PhysicsServer3D.generic_6dof_joint_set_param(row.node.get_rid(),axis,PhysicsServer3D.G6DOF_JOINT_LINEAR_RESTITUTION,.8)
		PhysicsServer3D.generic_6dof_joint_set_param(row.node.get_rid(),axis,PhysicsServer3D.G6DOF_JOINT_LINEAR_LIMIT_SOFTNESS,1.0)

func _fit_skin(skeleton: Skeleton3D) -> bool:
	_core_fits.clear()
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
		if name in CORE_NAMES:_core_fits[name] = core_box_fit(points[name])
		var radius := .015
		for point: Vector3 in points[name]: radius = maxf(radius,Vector2(point.x-center.x,point.z-center.z).length())
		var half := maxf(0.0,(maximum.y-minimum.y)*.5-radius)
		for point: Vector3 in points[name]: radius = maxf(radius,(point-center).distance_to(Vector3(0,clampf(point.y-center.y,-half,half),0))+.015)
		if radius > .5 or maximum.y-minimum.y > 1.5: return false
		var frame: Transform3D = _rest_body[name]
		frame.origin += frame.basis*center
		_rest_body[name] = frame
		_bone_to_body[name] = (_rest[name] as Transform3D).affine_inverse()*frame
		_dimensions[name].radius = radius
		_dimensions[name].height = 2.0*(half+radius)
	return true
