extends RefCounted
## Bounded native articulated-body prototype. Never writes the visual skeleton,
## actor transform, collision filters, health, identity, or transport authority.
const BODY_NAMES := ["pelvis", "spine_01", "chest", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const PARENTS := ["", "pelvis", "spine_01", "chest", "chest", "upperarm_l", "forearm_l", "chest", "upperarm_r", "forearm_r", "pelvis", "thigh_l", "shin_l", "pelvis", "thigh_r", "shin_r"]
const ENDS := {"spine_01":"chest", "chest":"neck", "head":"socket_head", "upperarm_l":"forearm_l", "forearm_l":"hand_l", "hand_l":"socket_hand_l", "upperarm_r":"forearm_r", "forearm_r":"hand_r", "hand_r":"socket_hand_r", "thigh_l":"shin_l", "shin_l":"foot_l", "thigh_r":"shin_r", "shin_r":"foot_r"}
const WEIGHTS := [12.0,8.0,16.0,5.0,2.3,1.4,.5,2.3,1.4,.5,7.0,3.3,1.0,7.0,3.3,1.0]
const MAX_BONES := 64
const MAX_VELOCITY := 80.0
const MAX_ANGULAR_VELOCITY := 30.0
const MAX_IMPULSE_NS := 10000.0
var _root: Node3D
var _skeleton: WeakRef
var _bones: Array[String] = []
var _bone_parents := {}
var _rest := {}
var _rest_body := {}
var _bone_to_body := {}
var _initial := {}
var _body_to_bone := {}
var _frozen_world := {}
var _bodies := {}
var _shapes := {}
var _joints: Array[Dictionary] = []
var _dimensions := {}
var _bone_owner := {}
var _exceptions: Array[CollisionObject3D] = []
var _active := false
var _paused := false
var _disposed := false
var _layer := 256
var _mask := 257
var _total_mass := 75.0

static func _finite_frame(value: Variant) -> bool:
	if not value is Transform3D or not value.origin.is_finite() or not value.basis.is_finite(): return false
	var scale: Vector3 = value.basis.get_scale()
	var b: Basis = value.basis
	return b.determinant() > .000001 and scale.x > .0001 and maxf(absf(scale.x-scale.y),absf(scale.y-scale.z)) < .001 and absf(b.x.normalized().dot(b.y.normalized())) < .0001 and absf(b.x.normalized().dot(b.z.normalized())) < .0001 and absf(b.y.normalized().dot(b.z.normalized())) < .0001

static func _body_basis(direction: Vector3, fallback: Basis) -> Basis:
	var y := direction.normalized()
	if y.length_squared() < .9: return fallback.orthonormalized()
	var seed := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < .9 else Vector3.RIGHT
	var x := y.cross(seed).normalized()
	return Basis(x,y,x.cross(y).normalized())

func capture_world_frames() -> Dictionary:
	var skeleton: Skeleton3D = _skeleton.get_ref() if _skeleton != null else null
	if not is_instance_valid(skeleton) or not skeleton.is_inside_tree(): return {}
	var frames := {}
	for name: String in _bones:
		frames[name] = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name))
	return frames

func _segment(name: String, frames: Dictionary) -> Dictionary:
	var bone: Transform3D = frames[name]
	var a := bone.origin
	var b := a
	if name == "pelvis":
		a = frames.thigh_l.origin
		b = frames.thigh_r.origin
	elif name.begins_with("foot_"):
		var leg := name.replace("foot_","shin_")
		var length: float = frames[leg].origin.distance_to(bone.origin) * .70
		a -= bone.basis.z.normalized() * length*.18
		b += bone.basis.z.normalized() * length*.82
	else: b = frames[ENDS[name]].origin
	return {"a":a,"b":b,"frame":Transform3D(_body_basis(b-a,bone.basis),(a+b)*.5),"length":a.distance_to(b)}

func configure(skeleton: Skeleton3D, parent: Node3D, options: Dictionary = {}) -> Dictionary:
	if _disposed or _root != null or not Thread.is_main_thread(): return {"ok":false,"error":"lifetime"}
	_bones.clear(); _rest.clear(); _bone_parents.clear(); _dimensions.clear(); _rest_body.clear(); _bone_to_body.clear()
	if not is_instance_valid(skeleton) or not is_instance_valid(parent) or not skeleton.is_inside_tree() or not parent.is_inside_tree() or skeleton.get_world_3d() != parent.get_world_3d(): return {"ok":false,"error":"world"}
	if skeleton.get_bone_count() < 28 or skeleton.get_bone_count() > MAX_BONES: return {"ok":false,"error":"rig_count"}
	var mass: float = options.get("total_mass_kg",75.0)
	if not is_finite(mass) or mass < 20.0 or mass > 200.0: return {"ok":false,"error":"mass"}
	var exceptions: Variant = options.get("exceptions",[])
	if not exceptions is Array or exceptions.size() > 16: return {"ok":false,"error":"exceptions"}
	for other: Variant in exceptions:
		if not other is CollisionObject3D or not is_instance_valid(other) or other.get_world_3d() != parent.get_world_3d(): return {"ok":false,"error":"exception_world"}
	for i in skeleton.get_bone_count():
		var name := str(skeleton.get_bone_name(i))
		var t := skeleton.global_transform*skeleton.get_bone_global_rest(i)
		if not _finite_frame(t): return {"ok":false,"error":"rig_frame"}
		_bones.append(name)
		_rest[name] = t
		var p := skeleton.get_bone_parent(i)
		if p >= i: return {"ok":false,"error":"rig_order"}
		_bone_parents[name] = str(skeleton.get_bone_name(p)) if p >= 0 else ""
	for name: String in BODY_NAMES + ["root","neck","socket_head","socket_hand_l","socket_hand_r"]:
		if not _rest.has(name): return {"ok":false,"error":"missing_bone:"+name}
	var hip_width: float = _rest.thigh_l.origin.distance_to(_rest.thigh_r.origin)
	if hip_width < .12 or hip_width > .7: return {"ok":false,"error":"rig_scale"}
	for name: String in BODY_NAMES:
		var segment := _segment(name,_rest)
		var length: float = segment.length
		if length < .015 or length > 1.2: return {"ok":false,"error":"segment_length:"+name}
		var radius := hip_width*.19
		if name in ["pelvis","spine_01","chest"]: radius = hip_width*(.52 if name == "chest" else .45)
		elif name == "head": radius = length*.42
		elif name.begins_with("thigh_"): radius = hip_width*.27
		elif name.begins_with("hand_"): radius = hip_width*.14
		elif name.begins_with("foot_"): radius = hip_width*.20
		_dimensions[name] = {"radius":radius,"height":maxf(length,2.0*radius),"length":length}
		_rest_body[name] = segment.frame
		_bone_to_body[name] = (_rest[name] as Transform3D).affine_inverse()*segment.frame
	var fitted := _fit_skin(skeleton)
	if not fitted: return {"ok":false,"error":"skin_fit"}
	_total_mass = mass
	_layer = int(options.get("collision_layer",256))
	_mask = int(options.get("collision_mask",1)) | _layer
	for other: CollisionObject3D in exceptions: _exceptions.append(other)
	_skeleton = weakref(skeleton)
	_root = Node3D.new()
	_root.name = "PhysicalCharacterBody"
	parent.add_child(_root)
	_root.top_level = true
	_root.global_transform = Transform3D.IDENTITY
	var weight_total := 0.0
	for weight: float in WEIGHTS: weight_total += weight
	var material := PhysicsMaterial.new()
	material.friction = .65
	material.bounce = 0.0
	for i in BODY_NAMES.size():
		var name: String = BODY_NAMES[i]
		var body := RigidBody3D.new()
		body.name = name
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		body.mass = mass*float(WEIGHTS[i])/weight_total
		body.continuous_cd = true
		body.can_sleep = true
		body.linear_damp = .15
		body.angular_damp = 2.0
		body.physics_material_override = material
		body.contact_monitor = true
		body.max_contacts_reported = 4
		body.set_meta("ragdoll_bone",name)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = _dimensions[name].radius
		capsule.height = _dimensions[name].height
		shape.shape = capsule
		shape.disabled = true
		body.add_child(shape)
		_root.add_child(body)
		body.global_transform = _segment(name,_rest).frame
		_bodies[name] = body
		_shapes[name] = shape
	# Capsule proxies overlap in authored tuck poses. Internal collision pairs
	# fight joint limits; exclude only this body's parts, never world/car bodies.
	for name: String in BODY_NAMES:
		for other: String in BODY_NAMES:
			if name != other: _bodies[name].add_collision_exception_with(_bodies[other])
	for i in range(1,BODY_NAMES.size()):
		var child: String = BODY_NAMES[i]
		var parent_name: String = PARENTS[i]
		var joint := Generic6DOFJoint3D.new()
		joint.name = "Joint_"+child
		_root.add_child(joint)
		var limit := Vector3(25,20,25)
		if child.begins_with("upperarm_"): limit = Vector3(85,55,85)
		elif child.begins_with("forearm_"): limit = Vector3(110,12,12)
		elif child.begins_with("thigh_"): limit = Vector3(80,30,40)
		elif child.begins_with("shin_"): limit = Vector3(110,8,8)
		elif child.begins_with("hand_"): limit = Vector3(25,20,25)
		elif child == "head": limit = Vector3(35,45,30)
		for axis: String in ["x","y","z"]:
			var axis_index := ["x","y","z"].find(axis)
			joint.set("linear_limit_"+axis+"/enabled",true)
			joint.set("linear_limit_"+axis+"/lower_distance",0.0)
			joint.set("linear_limit_"+axis+"/upper_distance",0.0)
			# In GodotPhysics this parameter is the positional error correction
			# coefficient, not the contact material bounce. Zero permits stretch.
			joint.set("linear_limit_"+axis+"/restitution",.5)
			joint.set("linear_limit_"+axis+"/softness",.8)
			joint.set("angular_limit_"+axis+"/enabled",true)
			joint.set("angular_limit_"+axis+"/lower_angle",-deg_to_rad(limit[axis_index]))
			joint.set("angular_limit_"+axis+"/upper_angle",deg_to_rad(limit[axis_index]))
			joint.set("angular_limit_"+axis+"/force_limit",400.0)
			joint.set("angular_limit_"+axis+"/erp",.3)
		joint.exclude_nodes_from_collision = true
		var anchor: Transform3D = _rest[child]
		joint.global_transform = Transform3D(anchor.basis.orthonormalized(),anchor.origin)
		joint.node_a = joint.get_path_to(_bodies[parent_name])
		joint.node_b = joint.get_path_to(_bodies[child])
		_joints.append({"node":joint,"parent":parent_name,"child":child,"a":Vector3.ZERO,"b":Vector3.ZERO})
	for name: String in _bones:
		var owner := name
		while not _bodies.has(owner) and not owner.is_empty(): owner = _bone_parents[owner]
		_bone_owner[name] = owner if not owner.is_empty() else "pelvis"
	return {"ok":true,"error":"","bodies":_bodies.size(),"joints":_joints.size(),"bones":_bones.size(),"total_mass_kg":_total_mass,"prewarmed":true}

func start(world_frames: Dictionary, inherited_linear_velocity: Vector3, outward_impulse_ns: Vector3 = Vector3.ZERO, inherited_angular_velocity: Vector3 = Vector3.ZERO, reference_point: Vector3 = Vector3.ZERO) -> Dictionary:
	if _disposed or _active or not is_instance_valid(_root) or not _root.is_inside_tree(): return {"ok":false,"error":"lifetime"}
	if not _pool_valid(): return {"ok":false,"error":"damaged_pool"}
	if not inherited_linear_velocity.is_finite() or inherited_linear_velocity.length() > MAX_VELOCITY or not outward_impulse_ns.is_finite() or outward_impulse_ns.length() > MAX_IMPULSE_NS: return {"ok":false,"error":"impulse_or_velocity"}
	if not inherited_angular_velocity.is_finite() or inherited_angular_velocity.length() > MAX_ANGULAR_VELOCITY or not reference_point.is_finite(): return {"ok":false,"error":"angular_or_reference"}
	for name: String in _bones:
		if not world_frames.has(name) or not _finite_frame(world_frames[name]): return {"ok":false,"error":"bone_frame:"+name}
		if (world_frames[name] as Transform3D).basis.get_scale().distance_to((_rest[name] as Transform3D).basis.get_scale()) > .0001: return {"ok":false,"error":"changed_rig_scale:"+name}
	for name: String in BODY_NAMES:
		var segment := _segment(name,world_frames)
		if absf(float(segment.length)-float(_dimensions[name].length)) > .01: return {"ok":false,"error":"changed_rig_length:"+name}
		var com: Vector3 = (world_frames[name]*_bone_to_body[name]).origin
		var velocity := inherited_linear_velocity + inherited_angular_velocity.cross(com-reference_point) + outward_impulse_ns/_total_mass
		if not velocity.is_finite() or velocity.length() > MAX_VELOCITY: return {"ok":false,"error":"segment_velocity"}
	_initial = world_frames.duplicate()
	for name: String in BODY_NAMES:
		var body: RigidBody3D = _bodies[name]
		body.global_transform = world_frames[name]*_bone_to_body[name]
		body.force_update_transform()
		_body_to_bone[name] = body.global_transform.affine_inverse()*world_frames[name]
		body.linear_velocity = inherited_linear_velocity + inherited_angular_velocity.cross(body.global_position-reference_point) + outward_impulse_ns/_total_mass
		body.angular_velocity = inherited_angular_velocity
		for other: CollisionObject3D in _exceptions:
			if is_instance_valid(other): body.add_collision_exception_with(other)
	for row: Dictionary in _joints:
		var joint: Generic6DOFJoint3D = row.node
		# Rebind constraints to the outgoing pose, not the prewarm rest frame.
		# Assigning the same node path alone can leave the old server anchors.
		joint.node_a = NodePath("")
		joint.node_b = NodePath("")
		var anchor: Transform3D = world_frames[row.child]
		if row.child == "spine_01": anchor.origin = world_frames.spine_01.origin
		joint.global_transform = Transform3D(anchor.basis.orthonormalized(),anchor.origin)
		joint.force_update_transform()
		joint.node_a = joint.get_path_to(_bodies[row.parent])
		joint.node_b = joint.get_path_to(_bodies[row.child])
		row.a = _bodies[row.parent].global_transform.affine_inverse()*anchor.origin
		row.b = _bodies[row.child].global_transform.affine_inverse()*anchor.origin
		_bind_rest_limits(row)
	for name: String in BODY_NAMES:
		var body: RigidBody3D = _bodies[name]
		body.collision_layer = _layer
		body.collision_mask = _mask
		_shapes[name].disabled = false
		body.freeze = false
		body.sleeping = false
	_active = true
	_paused = false
	_frozen_world.clear()
	return {"ok":true,"error":"","total_mass_kg":_total_mass,"bodies":_bodies.size(),"joints":_joints.size()}

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
		for point: Vector3 in points[name]: radius = maxf(radius,(point-center).distance_to(Vector3(0,clampf(point.y-center.y,-half,half),0))+.006)
		if radius > .4 or maximum.y-minimum.y > 1.5: return false
		var frame: Transform3D = _rest_body[name]
		frame.origin += frame.basis*center
		_rest_body[name] = frame
		_bone_to_body[name] = (_rest[name] as Transform3D).affine_inverse()*frame
		_dimensions[name].radius = radius
		_dimensions[name].height = 2.0*(half+radius)
	return true

func _bind_rest_limits(row: Dictionary) -> void:
	# Independent local angular references retain canonical anatomical zero,
	# while both positional anchors exactly match the outgoing pose.
	var a: RigidBody3D = _bodies[row.parent]
	var b: RigidBody3D = _bodies[row.child]
	var zero: Basis = (_rest[row.child] as Transform3D).basis.orthonormalized()
	var ref_a := Transform3D((_rest_body[row.parent] as Transform3D).basis.inverse()*zero,row.a)
	var ref_b := Transform3D((_rest_body[row.child] as Transform3D).basis.inverse()*zero,row.b)
	var joint: Generic6DOFJoint3D = row.node
	var hinge: bool = str(row.child).begins_with("shin_") or str(row.child).begins_with("forearm_")
	if not hinge:
		ref_a.basis = a.global_basis.inverse()*joint.global_basis
		ref_b.basis = b.global_basis.inverse()*joint.global_basis
	var rid := joint.get_rid()
	PhysicsServer3D.joint_make_generic_6dof(rid,a.get_rid(),ref_a,b.get_rid(),ref_b)
	PhysicsServer3D.joint_disable_collisions_between_bodies(rid,true)
	for axis in 3:
		var key: String = ["x","y","z"][axis]
		var lower: float = joint.get("angular_limit_"+key+"/lower_angle")
		var upper: float = joint.get("angular_limit_"+key+"/upper_angle")
		# GodotPhysics measures parent relative to child (opposite source X).
		if axis == 0:
			if str(row.child).begins_with("shin_"): lower = deg_to_rad(-145); upper = deg_to_rad(5)
			elif str(row.child).begins_with("forearm_"): lower = deg_to_rad(-5); upper = deg_to_rad(145)
			elif str(row.child).begins_with("thigh_"): lower = deg_to_rad(-25); upper = deg_to_rad(125)
		PhysicsServer3D.generic_6dof_joint_set_flag(rid,axis,PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT,true)
		PhysicsServer3D.generic_6dof_joint_set_flag(rid,axis,PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT,true)
		for item: Array in [[PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT,0.0],[PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT,0.0],[PhysicsServer3D.G6DOF_JOINT_LINEAR_RESTITUTION,.5],[PhysicsServer3D.G6DOF_JOINT_LINEAR_LIMIT_SOFTNESS,.8],[PhysicsServer3D.G6DOF_JOINT_LINEAR_DAMPING,1.0],[PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT,lower],[PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT,upper],[PhysicsServer3D.G6DOF_JOINT_ANGULAR_FORCE_LIMIT,400.0],[PhysicsServer3D.G6DOF_JOINT_ANGULAR_ERP,.3],[PhysicsServer3D.G6DOF_JOINT_ANGULAR_DAMPING,1.0],[PhysicsServer3D.G6DOF_JOINT_ANGULAR_LIMIT_SOFTNESS,.5]]:
			PhysicsServer3D.generic_6dof_joint_set_param(rid,axis,item[0],item[1])

func apply_impulse(world_point: Vector3, impulse_ns: Vector3, event_id: String = "") -> Dictionary:
	if not _active or _paused or _disposed or not world_point.is_finite() or not impulse_ns.is_finite() or impulse_ns.length() > MAX_IMPULSE_NS: return {"ok":false,"error":"inactive_or_impulse"}
	if not _pool_valid(): return {"ok":false,"error":"damaged_pool"}
	var selected := ""
	var distance := INF
	for name: String in BODY_NAMES:
		var body: RigidBody3D = _bodies[name]
		var d: Dictionary = _dimensions[name]
		var half := maxf(0.0,float(d.height)*.5-float(d.radius))
		var local := body.global_transform.affine_inverse()*world_point
		var nearest := Vector3(0,clampf(local.y,-half,half),0)
		var next := maxf(0.0,local.distance_to(nearest)-float(d.radius))
		if next < distance: selected = name; distance = next
	if distance > .75: return {"ok":false,"error":"outside_body"}
	var body: RigidBody3D = _bodies[selected]
	body.sleeping = false
	body.apply_impulse(impulse_ns,world_point-body.global_position)
	return {"ok":true,"error":"","bone":selected,"event_id":event_id,"distance_m":distance}

func _pool_valid() -> bool:
	for name: String in BODY_NAMES:
		if not is_instance_valid(_bodies.get(name)) or not _bodies[name].is_inside_tree() or not is_instance_valid(_shapes.get(name)): return false
	for row: Dictionary in _joints:
		if not is_instance_valid(row.node) or not row.node.is_inside_tree(): return false
	return _bodies.size() == 16 and _joints.size() == 15

func owned_bodies() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	for body: Variant in _bodies.values():
		if is_instance_valid(body): result.append(body as RigidBody3D)
	return result

func body_rids() -> Array[RID]:
	var result: Array[RID] = []
	for body: RigidBody3D in owned_bodies(): result.append(body.get_rid())
	return result

func stop_preserve() -> Dictionary:
	if _disposed or not _active: return {"ok":false,"error":"inactive"}
	_frozen_world.clear()
	for name: String in BODY_NAMES:
		if not is_instance_valid(_bodies[name]) or not _bodies[name].is_inside_tree(): continue
		var body: RigidBody3D = _bodies[name]
		_frozen_world[name] = body.global_transform
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		if is_instance_valid(_shapes[name]): _shapes[name].disabled = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	_paused = true
	return {"ok":true,"error":"","frozen":true}

func freeze_at_rest() -> Dictionary:
	var current := snapshot()
	if not current.get("settled",false): return {"ok":false,"error":"not_settled"}
	return stop_preserve()

func reset() -> Dictionary:
	if _disposed or not is_instance_valid(_root): return {"ok":false,"error":"disposed"}
	if _active: stop_preserve()
	_active = false
	_paused = false
	_initial.clear()
	_body_to_bone.clear()
	_frozen_world.clear()
	return {"ok":true,"error":"","prewarmed":true,"bodies":_bodies.size(),"joints":_joints.size()}

func snapshot() -> Dictionary:
	if _disposed or not is_instance_valid(_root) or not _root.is_inside_tree(): return {"valid":false,"active":false,"settled":false}
	if not _pool_valid(): return {"valid":false,"active":_active,"settled":false,"error":"damaged_pool"}
	if not _active: return {"valid":true,"active":false,"settled":false,"bodies":_bodies.size(),"joints":_joints.size()}
	var frames := {}
	var max_linear := 0.0
	var max_angular := 0.0
	var sleeping := 0
	var contacts := 0
	var max_joint_error := 0.0
	var core_linear := 0.0
	var core_angular := 0.0
	var energy := 0.0
	var energy_valid := not _paused
	var support_contacts := 0
	var core_support_contacts := 0
	var side_contacts := 0
	var ceiling_contacts := 0
	var fastest_linear := ""
	var fastest_angular := ""
	for name: String in BODY_NAMES:
		if not is_instance_valid(_bodies[name]): return {"valid":false,"active":true,"settled":false,"error":"damaged_pool"}
		var body: RigidBody3D = _bodies[name]
		if not is_instance_valid(body) or not body.global_transform.is_finite() or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite(): return {"valid":false,"active":true,"settled":false,"error":"nonfinite_or_lifetime"}
		var physical_frame: Transform3D = _frozen_world[name] if _paused else body.global_transform
		frames[name] = physical_frame*_body_to_bone[name]
		if body.linear_velocity.length() > max_linear: fastest_linear = name
		if body.angular_velocity.length() > max_angular: fastest_angular = name
		max_linear = maxf(max_linear,body.linear_velocity.length())
		max_angular = maxf(max_angular,body.angular_velocity.length())
		if name in ["pelvis","chest"]:
			core_linear = maxf(core_linear,body.linear_velocity.length())
			core_angular = maxf(core_angular,body.angular_velocity.length())
		energy += .5*body.mass*body.linear_velocity.length_squared()
		if not _paused:
			var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
			if state == null or not state.inverse_inertia_tensor.is_finite() or absf(state.inverse_inertia_tensor.determinant()) < .000001:
				energy_valid = false
			else:
				energy += .5*body.angular_velocity.dot(state.inverse_inertia_tensor.inverse()*body.angular_velocity)
				for contact in state.get_contact_count():
					var other := state.get_contact_collider_object(contact)
					if not is_instance_valid(other) or (other is Node and other.get_parent() == _root): continue
					# GodotPhysics reports this normal in world axes ("local" means
					# the body's side of the contact, not a body-basis rotation).
					var up := state.get_contact_local_normal(contact).dot(Vector3.UP)
					if up >= .7:
						support_contacts += 1
						if name in ["pelvis","chest"]: core_support_contacts += 1
					elif up <= -.7: ceiling_contacts += 1
					else: side_contacts += 1
		if body.sleeping: sleeping += 1
		for other: Node3D in body.get_colliding_bodies():
			if other.get_parent() != _root: contacts += 1
	for name: String in _bones:
		if frames.has(name): continue
		var owner: String = _bone_owner[name]
		frames[name] = frames[owner]*(_initial[owner] as Transform3D).affine_inverse()*_initial[name]
	for row: Dictionary in _joints:
		var a: Vector3 = _bodies[row.parent].global_transform*row.a
		var b: Vector3 = _bodies[row.child].global_transform*row.b
		max_joint_error = maxf(max_joint_error,a.distance_to(b))
	var pelvis: Transform3D = _frozen_world.pelvis if _paused else _bodies.pelvis.global_transform
	return {"valid":true,"active":true,"paused":_paused,"bone_world_frames":frames,"root_world_transform":frames.root,"pelvis_body_transform":pelvis,"anchor_world":pelvis.origin,"max_linear_speed":max_linear,"max_angular_speed":max_angular,"contact_count":contacts,"sleeping_count":sleeping,"settled":not _paused and contacts > 0 and max_linear < .12 and max_angular < .3 and max_joint_error < .035,"max_joint_anchor_error_m":max_joint_error,"bodies":_bodies.size(),"joints":_joints.size(),"total_mass_kg":_total_mass,"core_max_linear_speed":core_linear,"core_max_angular_speed":core_angular,"kinetic_energy_j":energy,"specific_kinetic_energy_j_kg":energy/_total_mass,"energy_valid":energy_valid,"support_contact_count":support_contacts,"core_support_contact_count":core_support_contacts,"side_contact_count":side_contacts,"ceiling_contact_count":ceiling_contacts,"fastest_linear_bone":fastest_linear,"fastest_angular_bone":fastest_angular}

func dispose() -> void:
	if _disposed: return
	_disposed = true
	_active = false
	if is_instance_valid(_root): _root.free()
	_root = null
	_bodies.clear()
	_shapes.clear()
	_joints.clear()
	_exceptions.clear()
	_initial.clear()
	_skeleton = null
