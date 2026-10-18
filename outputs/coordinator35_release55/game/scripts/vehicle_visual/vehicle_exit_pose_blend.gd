extends "res://scripts/vehicle_visual/vehicle_exit_pose.gd"
## Additive presentation adapter. Inherited sample/configure retain canonical
## tumble geometry; blend_release grounds the ACTUAL blended skin, not endpoints.
var _tuck_target: Dictionary = {}

func configure(skeleton: Skeleton3D, motion: Node3D, canonical_rest: Array[Transform3D], source_scale: float, hero_root: Node3D) -> bool:
	_tuck_target.clear()
	if not super.configure(skeleton,motion,canonical_rest,source_scale,hero_root): return false
	# Geometry-only canonical target: independent of frame, floor and epoch. The
	# final mixed pose is grounded at the CURRENT world frame on every sample.
	_tuck_target = super.sample(0.0,1.0,Callable(),null,0)
	return bool(_tuck_target.get("valid",false))

func blend_release(from_pose: Dictionary, release_progress: float, floor_height: Callable,
		root_frame: Variant = null, epoch: int = 0) -> Dictionary:
	if not Thread.is_main_thread() or _busy or not _ready or not is_instance_valid(_rig.get_ref()) or not is_instance_valid(_motion.get_ref()):
		return {"valid":false,"reason":"unbound_or_busy"}
	if not bool(from_pose.get("valid",false)) or not is_finite(release_progress) or release_progress < 0 or release_progress > 1 or epoch < 0:
		return {"valid":false,"reason":"invalid_pose_or_progress"}
	if int(from_pose.get("authority_epoch",from_pose.get("epoch",epoch))) != epoch:
		return {"valid":false,"reason":"stale_epoch"}
	if release_progress <= .55: return from_pose.duplicate()
	if not floor_height.is_valid() or (root_frame != null and not root_frame is Transform3D):
		return {"valid":false,"reason":"floor_or_frame_unavailable"}
	var world: Transform3D = _motion.get_ref().get_parent().global_transform if root_frame == null else root_frame
	if not world.origin.is_finite() or not world.basis.is_finite() or absf(world.basis.determinant()) < .000001:
		return {"valid":false,"reason":"invalid_world"}
	var from: Variant = from_pose.get("poses")
	var offset_from: Variant = from_pose.get("visual_offset")
	var rotation_from: Variant = from_pose.get("visual_rotation",Quaternion.IDENTITY)
	if not from is Array or from.size() != _rest.size() or not offset_from is Vector3 or not offset_from.is_finite() or not rotation_from is Quaternion or not rotation_from.is_finite() or rotation_from.length_squared() < .000001:
		return {"valid":false,"reason":"invalid_pose_arrays"}
	var weight := smooth((release_progress-.55)/.45)
	var poses: Array[Transform3D] = _rest.duplicate()
	for i in poses.size():
		if not from[i] is Transform3D or not from[i].origin.is_finite() or not from[i].basis.is_finite() or absf(from[i].basis.determinant()) < .000001:
			return {"valid":false,"reason":"invalid_bone"}
		if from[i].origin.distance_to(_rest[i].origin) > .00001 or from[i].basis.get_scale().distance_to(_rest[i].basis.get_scale()) > .00001:
			return {"valid":false,"reason":"noncanonical_bone_translation_or_scale"}
		var rotation: Quaternion = from[i].basis.get_rotation_quaternion().slerp(_tuck_target.poses[i].basis.get_rotation_quaternion(),weight).normalized()
		poses[i].basis = Basis(rotation)*Basis.from_scale(_rest[i].basis.get_scale())
	var rotation: Quaternion = rotation_from.normalized().slerp(_tuck_target.visual_rotation,weight).normalized()
	var offset: Vector3 = offset_from.lerp(_tuck_target.visual_offset,weight)
	_busy = true
	var frame := Transform3D(Basis(rotation),Vector3.ZERO)*_to_motion
	for i in poses.size():
		_global[i] = poses[i] if _parents[i] < 0 else _global[_parents[i]]*poses[i]
		_frames[i] = frame*_global[i]
	_deformed.clear()
	for bone: int in _rigid: _deformed.append_array(_frames[bone]*(_rigid[bone] as PackedVector3Array))
	var first := 0
	for end: int in _ends:
		var point := Vector3.ZERO
		for at in range(first,end):
			var transform := _frames[_bones[at]]
			point += transform.basis*_points[at] + transform.origin*_weights[at]
		_deformed.append(point); first=end
	# Same conservative source floor grid as canonical ExitPose. Keep all actual
	# mixed vertices, including torso/hands; endpoint minima are never consulted.
	_floor_calls=0; _floor_failed=false; _outside=0
	_height_ready.fill(0); _minimum_cell.fill(INF); _occupied_cells.clear()
	var grid_scale := Basis.from_scale(Vector3(4,1,4))
	var world_offset := world*offset
	var grid_origin := Vector3((world_offset.x-world.origin.x)*4,world_offset.y,(world_offset.z-world.origin.z)*4)
	var world_points := Transform3D(grid_scale*world.basis,grid_origin)*_deformed
	var lowest := INF; var highest := -INF
	for point: Vector3 in world_points:
		lowest=minf(lowest,point.y); highest=maxf(highest,point.y)
		if absf(point.x)>8 or absf(point.z)>8: _outside+=1
		var ix:=clampi(int(floor(point.x)),-8,7); var iz:=clampi(int(floor(point.z)),-8,7)
		var cell: int=(iz+8)*16+ix+8
		if _minimum_cell[cell]==INF: _occupied_cells.append(cell)
		_minimum_cell[cell]=minf(_minimum_cell[cell],point.y)
	var lift := 0.0
	for cell: int in _occupied_cells:
		var ix: int=cell%16-8; var iz: int=cell/16-8
		var floor_y:=maxf(maxf(_floor_node(ix,iz,world.origin,floor_height),_floor_node(ix+1,iz,world.origin,floor_height)),maxf(_floor_node(ix,iz+1,world.origin,floor_height),_floor_node(ix+1,iz+1,world.origin,floor_height)))
		lift=maxf(lift,floor_y-_minimum_cell[cell])
		if _floor_failed: break
	_busy=false
	if _floor_failed or _outside>0: return {"valid":false,"reason":"floor-unavailable-or-outside-source-grid","floor_calls":_floor_calls}
	offset += world.basis.inverse()*Vector3.UP*lift
	return {"valid":true,"poses":poses,"visual_offset":offset,"visual_rotation":rotation,
		"authority_epoch":epoch,"release_blend":weight,"skin_height":highest-lowest,
		"floor_lift":lift,"floor_calls":_floor_calls,"support_vertices":_unique_vertices}

func dispose() -> void:
	if _busy or not Thread.is_main_thread(): return
	_tuck_target.clear()
	super.dispose()
