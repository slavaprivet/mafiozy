extends RefCounted
## Actual source tumblePose presentation. Host owns trajectory/contact/authority.
const REQUIRED := ["chest", "thigh_l", "thigh_r", "shin_l", "shin_r", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r"]
var _rig: WeakRef
var _motion: WeakRef
var _rest: Array[Transform3D] = []
var _parents: PackedInt32Array = []
var _names: Dictionary = {}
var _global: Array[Transform3D] = []
var _frames: Array[Transform3D] = []
var _to_motion := Transform3D.IDENTITY
var _bones: PackedInt32Array = []
var _points := PackedVector3Array()
var _weights := PackedFloat32Array()
var _ends: PackedInt32Array = []
var _rigid: Dictionary = {}
var _unique_vertices := 0
var _packed_influences := 0
var _deformed := PackedVector3Array()
var _source_vertices := 0
var _ready := false
var _busy := false
var _heights := PackedFloat64Array()
var _height_ready := PackedByteArray()
var _floor_calls := 0
var _floor_failed := false
var _outside := 0
var _minimum_cell := PackedFloat32Array()
var _occupied_cells: PackedInt32Array = []

func configure(skeleton: Skeleton3D, motion: Node3D, canonical_rest: Array[Transform3D], source_scale: float, hero_root: Node3D) -> bool:
	if _busy or not Thread.is_main_thread(): return false
	_ready = false
	if not is_instance_valid(skeleton) or not is_instance_valid(motion) or not is_instance_valid(hero_root) or not is_finite(source_scale) or source_scale <= 0 or source_scale > 10: return false
	if canonical_rest.size() != skeleton.get_bone_count() or canonical_rest.size() > 128: return false
	_rest = canonical_rest.duplicate(); _parents.clear(); _names.clear(); _global.clear(); _frames.clear()
	_bones.clear(); _points.clear(); _weights.clear(); _ends.clear(); _source_vertices = 0
	_rigid.clear(); _unique_vertices = 0; _packed_influences = 0
	for i in _rest.size():
		if skeleton.get_bone_parent(i) >= i or not _rest[i].origin.is_finite() or not _rest[i].basis.is_finite(): return false
		_parents.append(skeleton.get_bone_parent(i)); _names[skeleton.get_bone_name(i)] = i
		_global.append(Transform3D.IDENTITY); _frames.append(Transform3D.IDENTITY)
	for name: String in REQUIRED:
		if not _names.has(name): return false
	_to_motion = motion.global_transform.affine_inverse() * skeleton.global_transform
	var unique: Dictionary = {}
	for node: Node in hero_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.skin == null: return false
		var ids := PackedInt32Array(); var binds: Array[Transform3D] = []
		for i in mesh.skin.get_bind_count():
			var bone := skeleton.find_bone(str(mesh.skin.get_bind_name(i)))
			if bone < 0: return false
			ids.append(bone); binds.append(mesh.skin.get_bind_pose(i))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or joints.size() != vertices.size() * 4 or weights.size() != joints.size(): return false
			_source_vertices += vertices.size()
			if _source_vertices > 20000: return false
			for v in vertices.size():
				var key: Array = []
				for influence in range(4):
					var at := v * 4 + influence; var weight := weights[at]
					if weight <= 0: continue
					var joint := joints[at]
					if joint < 0 or joint >= ids.size(): return false
					var point: Vector3 = binds[joint] * vertices[v]
					if not point.is_finite() or not is_finite(weight): return false
					key.append(ids[joint]); key.append(point * weight); key.append(weight)
				if key.is_empty(): return false
				if unique.has(key): continue
				unique[key] = true
				_unique_vertices += 1; _packed_influences += key.size() / 3
				if key.size() == 3 and key[2] == 1.0:
					if not _rigid.has(key[0]): _rigid[key[0]] = PackedVector3Array()
					_rigid[key[0]].append(key[1])
					continue
				for at in range(0, key.size(), 3):
					_bones.append(key[at]); _points.append(key[at + 1]); _weights.append(key[at + 2])
				_ends.append(_bones.size())
	_deformed.resize(_unique_vertices)
	_heights.resize(289); _height_ready.resize(289)
	_minimum_cell.resize(256)
	_rig = weakref(skeleton); _motion = weakref(motion)
	_ready = _source_vertices == 8338 and _unique_vertices > 0
	return _ready

static func smooth(t: float) -> float:
	t = clampf(t, 0, 1); return t * t * (3.0 - 2.0 * t)

func _floor_node(ix: int, iz: int, origin: Vector3, floor: Callable) -> float:
	var index := (iz + 8) * 17 + ix + 8
	if _height_ready[index] == 0:
		_floor_calls += 1
		var value: Variant = floor.call(origin.x + ix * .25, origin.z + iz * .25)
		if not (value is float or value is int) or not is_finite(float(value)): _floor_failed = true; return 0.0
		_heights[index] = float(value); _height_ready[index] = 1
	return _heights[index]

## floor(x_world,z_world) returns current world support Y, NOT capsule height.
## No floor callable means source groundPose at the trajectory root plane only.
func sample(progress: float, rolls: float = 1.0, floor: Callable = Callable(), root_frame: Variant = null, epoch: int = 0) -> Dictionary:
	if not Thread.is_main_thread() or _busy or not _ready or not is_instance_valid(_rig.get_ref()) or not is_instance_valid(_motion.get_ref()) or not is_finite(progress) or not is_finite(rolls) or rolls < 0 or rolls > 4 or epoch < 0: return {"valid": false}
	if root_frame != null and not root_frame is Transform3D: return {"valid": false}
	var world: Transform3D = _motion.get_ref().get_parent().global_transform if root_frame == null else root_frame
	if not world.origin.is_finite() or not world.basis.is_finite() or absf(world.basis.determinant()) < .000001: return {"valid": false}
	_busy = true
	var p := clampf(progress, 0, 1); var tuck := 1.0 - smooth((p - .72) / .28)
	var poses: Array[Transform3D] = _rest.duplicate()
	var angles := {"chest": .95 * tuck}
	for side: String in ["l", "r"]:
		angles["thigh_" + side] = -1.9 * tuck; angles["shin_" + side] = 1.35 * tuck
		angles["upperarm_" + side] = -1.3 * tuck; angles["forearm_" + side] = -1.1 * tuck
	for name: String in angles:
		var bone: int = _names[name]
		var q := (_rest[bone].basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, angles[name])).normalized()
		poses[bone].basis = Basis(q) * Basis.from_scale(_rest[bone].basis.get_scale())
	var rotation := Quaternion(Vector3.RIGHT, TAU * rolls * smooth((p - .06) / .64)).normalized()
	var frame := Transform3D(Basis(rotation), Vector3.ZERO) * _to_motion
	for i in poses.size():
		_global[i] = poses[i] if _parents[i] < 0 else _global[_parents[i]] * poses[i]
		_frames[i] = frame * _global[i]
	# Fold source scaled.position.y=-.65 into the one native motion transform.
	var offset := Vector3.UP * .65 + rotation * Vector3.DOWN * .65
	var lowest := INF; var highest := -INF; var first := 0
	_deformed.clear()
	for bone: int in _rigid: _deformed.append_array(_frames[bone] * (_rigid[bone] as PackedVector3Array))
	for end: int in _ends:
		var point := Vector3.ZERO
		if end == first + 1 and _weights[first] == 1.0:
			point = _frames[_bones[first]] * _points[first]
		else:
			for at in range(first, end):
				var transform := _frames[_bones[at]]
				point += transform.basis * _points[at] + transform.origin * _weights[at]
		_deformed.append(point); first = end
	for point: Vector3 in _deformed:
		lowest = minf(lowest, point.y + offset.y); highest = maxf(highest, point.y + offset.y)
	offset.y -= lowest
	var lift := 0.0
	_floor_calls = 0; _outside = 0; _floor_failed = false
	if floor.is_valid():
		_height_ready.fill(0)
		_minimum_cell.fill(INF); _occupied_cells.clear()
		# Native bulk transform; the source sampler is CONSTANT inside each cell.
		# Exact max(floor-y) therefore needs only its lowest actual skin vertex,
		# without discarding any vertex or approximating a nonlinear floor.
		var world_offset := world * offset
		var grid_scale := Basis.from_scale(Vector3(4, 1, 4))
		var grid_origin := Vector3((world_offset.x - world.origin.x) * 4.0, world_offset.y, (world_offset.z - world.origin.z) * 4.0)
		var world_points := Transform3D(grid_scale * world.basis, grid_origin) * _deformed
		for world_point: Vector3 in world_points:
			var dx := world_point.x; var dz := world_point.z
			if absf(dx) > 8 or absf(dz) > 8: _outside += 1
			var ix := clampi(int(floor(dx)), -8, 7); var iz := clampi(int(floor(dz)), -8, 7)
			var cell := (iz + 8) * 16 + ix + 8
			if _minimum_cell[cell] == INF: _occupied_cells.append(cell)
			_minimum_cell[cell] = minf(_minimum_cell[cell], world_point.y)
		for cell: int in _occupied_cells:
			var ix := cell % 16 - 8; var iz := cell / 16 - 8
			var cell_floor := maxf(maxf(_floor_node(ix, iz, world.origin, floor), _floor_node(ix + 1, iz, world.origin, floor)), maxf(_floor_node(ix, iz + 1, world.origin, floor), _floor_node(ix + 1, iz + 1, world.origin, floor)))
			lift = maxf(lift, cell_floor - _minimum_cell[cell])
			if _floor_failed: break
		offset += world.basis.inverse() * Vector3.UP * lift
	_busy = false
	if _floor_failed or _outside > 0: return {"valid": false, "reason": "floor-unavailable-or-outside-source-grid", "floor_calls": _floor_calls}
	return {"valid": true, "poses": poses, "visual_offset": offset, "visual_rotation": rotation, "progress": p, "rolls": rolls, "authority_epoch": epoch, "skin_height": highest - lowest, "floor_lift": lift, "floor_calls": _floor_calls, "support_vertices": _unique_vertices}

func diagnostics() -> Dictionary:
	return {"ready": _ready, "source_vertices": _source_vertices, "unique_vertices": _unique_vertices, "packed_influences": _packed_influences, "rigid_groups": _rigid.size(), "weighted_vertices": _ends.size()}

func dispose() -> void:
	if _busy or not Thread.is_main_thread(): return
	_ready = false; _rig = null; _motion = null; _rest.clear(); _global.clear(); _frames.clear(); _points.clear(); _bones.clear(); _weights.clear(); _ends.clear(); _deformed.clear()
	_rigid.clear()
