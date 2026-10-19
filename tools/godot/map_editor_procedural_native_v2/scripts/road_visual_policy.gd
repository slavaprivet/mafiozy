extends RefCounted
## Geometry-only source range/phase policy. Does not authorize traffic decisions.
var _factory: RefCounted
var _groups: Dictionary = {}
var _instance_group: Dictionary = {}
var _paint_spheres: Dictionary = {}
var _submitted: Dictionary = {}
var _original_equipment: Dictionary = {}
var _dirty: Dictionary = {}
var _has_focus_cache: Variant = null
var _focus_cache: Array = []
var _previous_phase: Dictionary = {}
var _previous_signal_visible: Dictionary = {}
var _signal_ids: Array = []
var _bulb_bases: Dictionary = {}
var _bulb_frames: Dictionary = {}
var time := 0.0
var writes := 0
var distance_checks := 0

func configure(factory: RefCounted) -> bool:
	if is_instance_valid(_factory) or not is_instance_valid(factory) or not is_instance_valid(factory._roads_root) or not factory.errors.is_empty():
		return false
	_factory = factory
	for receipt: Dictionary in factory._manifest.roads.equipmentChunks:
		_groups[receipt.key] = {"source": receipt, "sphere": receipt.sourceBoundingSphere.duplicate(true), "visible": null, "changed": false, "dirty": false}
		for index in receipt.instanceIndices:
			_instance_group[str(receipt.batch) + ":" + str(int(index))] = str(receipt.key)
	for key in factory._paint_batches:
		_paint_spheres[key] = _vertex_sphere(factory._paint_batches[key].current)
	for key in factory._batches:
		if str(key).begins_with("RoadEquipment_") or str(key).begins_with("TrafficBulbs:"):
			_submitted[key] = factory._batches[key].transforms.duplicate()
			if str(key).begins_with("RoadEquipment_"):
				_original_equipment[key] = factory._batches[key].transforms.duplicate()
	_signal_ids = factory._batches["TrafficBulbs:red"].source.objectIds.duplicate()
	for index in _signal_ids.size():
		var id: String = _signal_ids[index]
		_bulb_frames[id] = {}
		for name in ["red", "amber", "green"]:
			var frame: Transform3D = factory._batches["TrafficBulbs:" + name].transforms[index]
			_bulb_frames[id][name] = frame
			if absf(frame.basis.determinant()) > 0.00000001:
				_bulb_bases[id] = frame.basis
		if not _bulb_bases.has(id):
			return false
	factory._road_visual_dirty = Callable(self, "_mark_dirty")
	return true

func update(dt: float = 0.0, focus_native: Variant = null, absolute_time: Variant = null) -> Dictionary:
	if not is_instance_valid(_factory):
		return {"ok": false}
	if absolute_time != null and typeof(absolute_time) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(absolute_time)):
		time = float(absolute_time)
	else:
		time += maxf(0.0, dt if is_finite(dt) else 0.0)
	writes = 0
	distance_checks = 0
	var has_focus: bool = focus_native is Array and _factory._vector_valid(focus_native)
	var focus: Array = [float(focus_native[0]) + float(_factory._manifest.coordinateContract.originM[0]), float(focus_native[2]) + float(_factory._manifest.coordinateContract.originM[2])] if has_focus else []
	var focus_changed: bool = _has_focus_cache == null or _has_focus_cache != has_focus or focus != _focus_cache
	var forced: Dictionary = {}
	for id in _dirty:
		if _factory._paint_ids.has(id):
			var key: String = _factory._paint_ids[id].batch
			_paint_spheres[key] = _vertex_sphere(_factory._paint_batches[key].current)
		else:
			for part: Dictionary in _factory._parts[id]:
				forced[str(part.batch) + ":" + str(part.index)] = true
				var group_key: String = _instance_group.get(str(part.batch) + ":" + str(part.index), "")
				if not group_key.is_empty():
					_expand_group(group_key)
	if focus_changed or not _dirty.is_empty():
		for key in _paint_spheres:
			_factory._paint_batches[key].node.visible = _show(_paint_spheres[key], focus, has_focus)
		for group: Dictionary in _groups.values():
			var visible := _show(group.sphere, focus, has_focus)
			group.changed = group.visible != visible
			group.visible = visible
		_has_focus_cache = has_focus
		_focus_cache = focus.duplicate()
	var batch_visible: Dictionary = {}
	for group: Dictionary in _groups.values():
		var source: Dictionary = group.source
		var batch: Dictionary = _factory._batches[source.batch]
		batch_visible[source.batch] = batch_visible.get(source.batch, false) or group.visible
		if not group.changed and not group.dirty:
			continue
		for index in source.instanceIndices:
			var frame: Transform3D = batch.transforms[index]
			if not group.visible:
				frame.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
			_write(source.batch, int(index), frame, forced.has(str(source.batch) + ":" + str(int(index))))
		group.changed = false
		group.dirty = false
	for key in batch_visible:
		_factory._batches[key].node.visible = batch_visible[key]
	var phases: Array[String] = []
	var visible_signals := 0
	for index in _signal_ids.size():
		var id: String = _signal_ids[index]
		var lamp: Dictionary = _factory._source_records[id]
		var phase := _phase(time, int(lamp.axis), float(lamp.offset))
		phases.append(phase)
		var key := str(floori(float(lamp.x) / 128.0)) + "," + str(floori(float(lamp.z) / 128.0)) + ":box"
		var show: bool = (not _groups.has(key) or _groups[key].visible != false) and not _factory._deleted.get(id, false)
		if show:
			visible_signals += 1
		if _previous_phase.get(id, "") == phase and _previous_signal_visible.get(id, null) == show and not _dirty.has(id):
			continue
		_previous_phase[id] = phase
		_previous_signal_visible[id] = show
		for name in ["red", "amber", "green"]:
			var frame := _bulb_source(lamp, name, show and name == phase)
			var original_native: Transform3D = _factory._source_frames[id]
			original_native.origin -= _factory._origin
			if _factory.object_transform(id) != original_native:
				var desired: Transform3D = _factory.object_transform(id)
				desired.origin += _factory._origin
				frame = desired * (_factory._source_frames[id] as Transform3D).affine_inverse() * frame
			_write("TrafficBulbs:" + name, index, frame, _dirty.has(id))
	for phase in ["red", "amber", "green"]:
		_factory._batches["TrafficBulbs:" + phase].node.visible = visible_signals > 0
	_dirty.clear()
	return {"ok": true, "time": time, "phases": phases, "writes": writes, "distanceChecks": distance_checks, "visibleSignals": visible_signals, "status": "visual-policy-only-not-traffic-authority"}

func _mark_dirty(id: String) -> void:
	_dirty[id] = true

func _write(key: String, index: int, frame: Transform3D, force: bool) -> void:
	if not force and _submitted[key][index] == frame:
		return
	_factory._batches[key].mesh.set_instance_transform(index, frame)
	_submitted[key][index] = frame
	writes += 1

func _phase(at: float, axis: int, offset: float) -> String:
	var cycle := fmod(fmod(at + offset, 44.0) + 44.0, 44.0)
	if axis == 0:
		return "green" if cycle < 17 else ("amber" if cycle < 20 else "red")
	return "green" if cycle >= 22 and cycle < 39 else ("amber" if cycle >= 39 and cycle < 42 else "red")

func _bulb_source(lamp: Dictionary, name: String, on: bool) -> Transform3D:
	# All three original bulbs share their exact source basis; their translations
	# are present even in collapsed time-zero buffers. Reuse original Float32
	# values, avoiding native trig/Quaternion rounding and regenerated geometry.
	var frame: Transform3D = _bulb_frames[lamp.id][name]
	var basis: Basis = _bulb_bases[lamp.id]
	frame.basis = basis if on else Basis(basis.x * 0.0, basis.y * 0.0, basis.z * 0.0)
	return frame

func _show(sphere: Dictionary, focus: Array, has_focus: bool) -> bool:
	if not has_focus:
		return true
	distance_checks += 1
	var dx := float(sphere.center[0]) - float(focus[0])
	var dz := float(sphere.center[2]) - float(focus[1])
	return sqrt(dx * dx + dz * dz) < 360.0 + float(sphere.radius)

func _vertex_sphere(vertices: PackedVector3Array) -> Dictionary:
	var minimum := [INF, INF, INF]
	var maximum := [-INF, -INF, -INF]
	for vertex in vertices:
		for axis in 3:
			minimum[axis] = minf(minimum[axis], float(vertex[axis]))
			maximum[axis] = maxf(maximum[axis], float(vertex[axis]))
	var center := [(minimum[0] + maximum[0]) * 0.5, (minimum[1] + maximum[1]) * 0.5, (minimum[2] + maximum[2]) * 0.5]
	var radius_squared := 0.0
	for vertex in vertices:
		var dx := float(vertex.x) - float(center[0])
		var dy := float(vertex.y) - float(center[1])
		var dz := float(vertex.z) - float(center[2])
		radius_squared = maxf(radius_squared, dx * dx + dy * dy + dz * dz)
	return {"center": center, "radius": sqrt(radius_squared)}

func _expand_group(key: String) -> void:
	var group: Dictionary = _groups[key]
	group.dirty = true
	group.sphere = group.source.sourceBoundingSphere.duplicate(true)
	var batch: Dictionary = _factory._batches[group.source.batch]
	var center: Array = group.sphere.center
	# Keep original source sphere and conservatively expand around admitted edits.
	# Exact regroup/rebuild needs the gameplay owner's mutable-plan adapter.
	for index in group.source.instanceIndices:
		var frame: Transform3D = batch.transforms[index]
		if frame == _original_equipment[group.source.batch][index] or absf(frame.basis.determinant()) < 0.0000001:
			continue
		var box: AABB = frame * _factory._meshes[batch.source.geometry].get_aabb()
		for corner in 8:
			var point := box.get_endpoint(corner)
			var dx := float(point.x) - float(center[0])
			var dy := float(point.y) - float(center[1])
			var dz := float(point.z) - float(center[2])
			group.sphere.radius = maxf(float(group.sphere.radius), sqrt(dx * dx + dy * dy + dz * dz))
