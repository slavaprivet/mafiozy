extends RefCounted
## Bounds the full skinned path between two accepted getup poses. No world writes.
## Path: shortest local quaternion slerps, canonical constant scales/translations,
## and linear visual offset. A fixed world parent is required.
var _prepared: WeakRef
var _rest: Array[Transform3D] = []
var _parents := PackedInt32Array()
var _reach := 0.0
var _ready := false

static func _uniform(b: Basis) -> bool:
	var s := b.get_scale()
	return b.is_finite() and b.determinant() > .000001 and s.x > 0 and absf(s.x-s.y)<.00001 and absf(s.x-s.z)<.00001 and absf(b.x.dot(b.y))<.00001 and absf(b.x.dot(b.z))<.00001 and absf(b.y.dot(b.z))<.00001

func configure(prepared_pose: RefCounted) -> bool:
	_ready = false
	if prepared_pose == null or not bool(prepared_pose.get("_ready")): return false
	_rest.assign(prepared_pose.get("_rest"));_parents = prepared_pose.get("_parents")
	var to_motion: Transform3D = prepared_pose.get("_to_motion")
	if not _uniform(to_motion.basis) or _rest.is_empty() or _parents.size()!=_rest.size(): return false
	var lengths := PackedFloat64Array();var scales := PackedFloat64Array();var radii := PackedFloat64Array()
	lengths.resize(_rest.size());scales.resize(_rest.size());radii.resize(_rest.size())
	for i in _rest.size():
		if not _uniform(_rest[i].basis) or _parents[i] >= i: return false
		var parent := _parents[i]
		var parent_scale := 1.0 if parent < 0 else scales[parent]
		lengths[i] = (0.0 if parent < 0 else lengths[parent]) + parent_scale * _rest[i].origin.length()
		scales[i] = parent_scale * _rest[i].basis.get_scale().x
	for bone: int in prepared_pose.get("_rigid"):
		for point: Vector3 in prepared_pose.get("_rigid")[bone]: radii[bone] = maxf(radii[bone],point.length())
	var points: PackedVector3Array = prepared_pose.get("_points")
	var bones: PackedInt32Array = prepared_pose.get("_bones")
	var weights: PackedFloat32Array = prepared_pose.get("_weights")
	for i in points.size():
		if weights[i] <= 0: return false
		radii[bones[i]] = maxf(radii[bones[i]],points[i].length()/weights[i])
	var maximum_weight_sum := 1.0
	var first := 0
	for end: int in prepared_pose.get("_ends"):
		var sum := 0.0
		for at in range(first,end): sum += weights[at]
		maximum_weight_sum = maxf(maximum_weight_sum,sum);first=end
	_reach = 0.0
	for i in _rest.size(): _reach = maxf(_reach,lengths[i]+scales[i]*radii[i])
	_reach = maximum_weight_sum*(to_motion.origin.length()+to_motion.basis.get_scale().x*_reach)
	_prepared = weakref(prepared_pose);_ready = is_finite(_reach)
	return _ready

func snapshot(selected: Dictionary, world: Transform3D, use_prepared_cache: bool = true) -> Dictionary:
	if not _ready or not Thread.is_main_thread() or not is_instance_valid(_prepared.get_ref()) or not selected.get("valid",false) or not _uniform(world.basis) or not world.origin.is_finite(): return {"valid":false,"reason":"binding_or_world"}
	var source: RefCounted = _prepared.get_ref()
	if not bool(source.get("_ready")): return {"valid":false,"reason":"prepared_retired"}
	var poses: Array = selected.get("poses",[])
	var offset: Vector3 = selected.get("visual_offset",Vector3(INF,INF,INF))
	var rotation: Quaternion = selected.get("visual_rotation",Quaternion.IDENTITY)
	if poses.size()!=_rest.size() or not offset.is_finite() or not rotation.is_finite() or absf(rotation.length_squared()-1)>.0001: return {"valid":false,"reason":"pose"}
	var global: Array[Transform3D] = [];var frames: Array[Transform3D] = [];var rotations: Array[Quaternion] = []
	var prefix := Transform3D(Basis(rotation),Vector3.ZERO)*(source.get("_to_motion") as Transform3D)
	for i in poses.size():
		if not poses[i] is Transform3D: return {"valid":false,"reason":"bone"}
		var pose: Transform3D = poses[i]
		if not _uniform(pose.basis) or pose.origin.distance_to(_rest[i].origin)>.00001 or pose.basis.get_scale().distance_to(_rest[i].basis.get_scale())>.00001: return {"valid":false,"reason":"bone_shape_changed"}
		global.append(pose if _parents[i]<0 else global[_parents[i]]*pose)
		frames.append(prefix*global[i]);rotations.append(pose.basis.orthonormalized().get_rotation_quaternion())
		if use_prepared_cache and not frames[i].is_equal_approx(source.get("_frames")[i]): return {"valid":false,"reason":"stale_prepared_cache"}
	var deformed: PackedVector3Array
	if use_prepared_cache: deformed = source.get("_deformed")
	else:
		for bone: int in source.get("_rigid"): deformed.append_array(frames[bone]*(source.get("_rigid")[bone] as PackedVector3Array))
		var first := 0
		for end: int in source.get("_ends"):
			var point := Vector3.ZERO
			for at in range(first,end):
				var frame: Transform3D = frames[source.get("_bones")[at]]
				point += frame.basis*source.get("_points")[at]+frame.origin*source.get("_weights")[at]
			deformed.append(point);first=end
	if deformed.is_empty(): return {"valid":false,"reason":"empty_skin"}
	var world_points := Transform3D(world.basis,world*offset)*deformed
	var box := AABB(world_points[0],Vector3.ZERO)
	for point: Vector3 in world_points: box = box.expand(point)
	return {"valid":true,"bounds":box,"rotations":rotations,"visual_rotation":rotation,"world":world,"epoch":selected.get("authority_epoch",-1),"vertices":deformed.size()}

func between(previous: Dictionary, next: Dictionary, flat_support_y: Variant = null) -> Dictionary:
	if not _ready or not previous.get("valid",false) or not next.get("valid",false) or previous.get("rotations",[]).size()!=_rest.size() or next.get("rotations",[]).size()!=_rest.size(): return {"valid":false,"reason":"snapshot"}
	if previous.epoch!=next.epoch or previous.epoch<0 or not (previous.world as Transform3D).is_equal_approx(next.world): return {"valid":false,"reason":"epoch_or_parent_changed"}
	var accumulated := PackedFloat64Array();accumulated.resize(_rest.size())
	var theta: float = (previous.visual_rotation as Quaternion).angle_to(next.visual_rotation)
	var maximum := theta
	for i in _rest.size():
		accumulated[i] = (0.0 if _parents[i]<0 else accumulated[_parents[i]])+(previous.rotations[i] as Quaternion).angle_to(next.rotations[i])
		maximum = maxf(maximum,theta+accumulated[i])
	# Every vertex is a weighted sum of rotated chain translations/bind points.
	# Each term has ||d²x/dt²|| <= length*(sum ancestor angles)².
	# Its deviation from the endpoint chord is <= max||x''||/8. Uniform
	# scales commute with rotation; fixed translations and linear offsets add 0.
	var padding := _reach*(previous.world as Transform3D).basis.get_scale().x*maximum*maximum/8.0+.00002
	var box: AABB = (previous.bounds as AABB).merge(next.bounds).grow(padding)
	if flat_support_y != null:
		# Optional contract: every intermediate pose is vertically grounded on
		# this ONE known plane, using max(0, plane-minimum_skin_y). The minimum
		# is then the plane; the upper excursion adds at most another padding.
		if not (flat_support_y is float or flat_support_y is int) or not is_finite(float(flat_support_y)) or minf(previous.bounds.position.y,next.bounds.position.y)<float(flat_support_y)-.00005: return {"valid":false,"reason":"support_plane"}
		var top := box.end.y+padding
		box.position.y = float(flat_support_y)-.00002;box.size.y=top-box.position.y
	return {"valid":true,"bounds":box,"angular_padding_m":padding,"reach_m":_reach,"max_chain_angle":maximum,"epoch":previous.epoch}
