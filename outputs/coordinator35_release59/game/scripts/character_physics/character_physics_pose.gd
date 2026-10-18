extends "res://scripts/vehicle_visual/vehicle_exit_pose_blend.gd"
## Converts physical world bone frames into the existing single pose writer.
## Keeps authored bone lengths; solver error must not stretch the rendered skin.
var _skeleton_ref: WeakRef

func configure(skeleton: Skeleton3D, motion: Node3D, canonical_rest: Array[Transform3D], source_scale: float, hero_root: Node3D) -> bool:
	if not super.configure(skeleton, motion, canonical_rest, source_scale, hero_root): return false
	_skeleton_ref = weakref(skeleton)
	# The inherited mixed-skin grounding solver also supports a standing target.
	_tuck_target = sample(1.0, 1.0, Callable(), null, 0)
	return bool(_tuck_target.get("valid", false))

func from_world_frames(frames: Dictionary, epoch: int) -> Dictionary:
	if not _ready or not is_instance_valid(_skeleton_ref.get_ref()) or epoch < 0: return {"valid":false}
	var skeleton := _skeleton_ref.get_ref() as Skeleton3D
	var skeleton_world := skeleton.global_transform
	var poses: Array[Transform3D] = _rest.duplicate()
	var offset := Vector3.ZERO
	for index in poses.size():
		var name := str(skeleton.get_bone_name(index))
		if not frames.get(name) is Transform3D: return {"valid":false,"reason":"missing_bone:"+name}
		var world: Transform3D = frames[name]
		if not world.is_finite() or world.basis.determinant() < .000001: return {"valid":false,"reason":"invalid_bone"}
		var parent_world: Transform3D = skeleton_world if _parents[index] < 0 else frames[str(skeleton.get_bone_name(_parents[index]))]
		var local := parent_world.affine_inverse() * world
		poses[index].basis = Basis(local.basis.orthonormalized().get_rotation_quaternion()) * Basis.from_scale(_rest[index].basis.get_scale())
		if _parents[index] < 0:
			offset = _to_motion.basis * (local.origin - _rest[index].origin)
	return {"valid":true,"poses":poses,"visual_offset":offset,"visual_rotation":Quaternion.IDENTITY,"authority_epoch":epoch}

func standing_blend(from_pose: Dictionary, progress: float, floor_height: Callable, epoch: int) -> Dictionary:
	return blend_release(from_pose, .55 + .45 * clampf(progress, 0.0, 1.0), floor_height, null, epoch)

# Exact full-skin grounding; native extrema accelerate flat supported terrain.
# Floor callback is a pure, stable-per-physics-tick height query.
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
	var tx := Array(world_points)
	var ty := Array(Transform3D(Basis(Vector3(0,1,0),Vector3(1,0,0),Vector3(0,0,1)),Vector3.ZERO)*world_points)
	var tz := Array(Transform3D(Basis(Vector3(0,0,1),Vector3(0,1,0),Vector3(1,0,0)),Vector3.ZERO)*world_points)
	var min_x: float = (tx.min() as Vector3).x;var max_x: float = (tx.max() as Vector3).x
	var lowest: float = (ty.min() as Vector3).x;var highest: float = (ty.max() as Vector3).x
	var min_z: float = (tz.min() as Vector3).x;var max_z: float = (tz.max() as Vector3).x
	if min_x < -8 or max_x > 8 or min_z < -8 or max_z > 8:
		_busy=false
		return {"valid":false,"reason":"floor-unavailable-or-outside-source-grid","floor_calls":0}
	var flat := true
	var height := INF
	for ix in range(clampi(floori(min_x),-8,7),clampi(floori(max_x),-8,7)+2):
		for iz in range(clampi(floori(min_z),-8,7),clampi(floori(max_z),-8,7)+2):
			var next_height := _floor_node(ix,iz,world.origin,floor_height)
			if _floor_failed:flat=false;break
			if height==INF:height=next_height
			elif next_height!=height:flat=false;break
		if not flat:break
	# A NaN in a rectangle node not used by actual vertices must not change the
	# original admission result. Discard probe state and run original queries.
	if _floor_failed:
		_floor_failed=false;_height_ready.fill(0);_floor_calls=0
	var lift := maxf(0.0,height-lowest) if flat else 0.0
	if not flat:
		var minima := _minimum_cell
		var occupied := PackedInt32Array()
		for point: Vector3 in world_points:
			var ix: int=mini(floori(point.x)+8,15)
			var iz: int=mini(floori(point.z)+8,15)
			var cell: int=iz*16+ix
			if minima[cell]==INF:occupied.append(cell)
			minima[cell]=minf(minima[cell],point.y)
		_minimum_cell=minima;_occupied_cells=occupied
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

