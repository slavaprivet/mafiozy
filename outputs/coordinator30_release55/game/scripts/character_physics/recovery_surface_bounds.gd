extends RefCounted
## Conservative full-skin separating-plane refinement for actual BoxShape3D.
## Never grants floor/support/ownership admission or excludes any collider RID.
const Clearance = preload("res://scripts/character_physics/recovery_clearance.gd")
const MAX_PARTS := 8
var _prepared: WeakRef
var _rig: WeakRef
var _motion: WeakRef
var _version := -1
var _clearance: RefCounted
var _serial := 0
var _records: Dictionary = {}
var _pair := Vector2i(-1,-1)
var _subdivisions: Dictionary = {}
var _ready := false
var _geometry: Array[Dictionary] = []
var _geometry_changed := false
var _tree: WeakRef

func configure(prepared: RefCounted) -> bool:
	if _ready or not Thread.is_main_thread() or not is_instance_valid(prepared) or not prepared.get("_ready"): return false
	var rig_ref: Variant = prepared.get("_rig"); var motion_ref: Variant = prepared.get("_motion")
	if not rig_ref is WeakRef or not motion_ref is WeakRef: return false
	var rig: Variant = rig_ref.get_ref(); var motion: Variant = motion_ref.get_ref()
	if not _node_live(rig) or not rig is Skeleton3D or not _node_live(motion): return false
	if int(prepared.get("_source_vertices")) != 8338 or int(prepared.get("_unique_vertices")) < 1 or int(prepared.get("_unique_vertices")) > 20000: return false
	var clearance := Clearance.new()
	if not clearance.configure(prepared): return false
	_prepared = weakref(prepared); _rig = rig_ref; _motion = motion_ref
	_version = rig.get_version(); _clearance = clearance; _ready = true
	var vertex_count := 0
	for node: Node in motion.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.skin == null or mesh.get_node_or_null(mesh.skeleton) != rig: dispose(); return false
		for surface in mesh.mesh.get_surface_count(): vertex_count += mesh.mesh.surface_get_array_len(surface)
		_geometry.append({"node":weakref(mesh),"mesh":weakref(mesh.mesh),"skin":weakref(mesh.skin),"skeleton":mesh.skeleton})
	if _geometry.is_empty() or vertex_count != int(prepared.get("_source_vertices")): dispose(); return false
	for item: Dictionary in _geometry:
		for key in ["mesh","skin"]:
			var resource: Resource = item[key].get_ref()
			if not resource.changed.is_connected(_invalidate_geometry): resource.changed.connect(_invalidate_geometry)
	_tree = weakref(motion.get_tree())
	motion.get_tree().node_added.connect(_on_node_added)
	return true

func dispose() -> void:
	for item: Dictionary in _geometry:
		for key in ["mesh","skin"]:
			var resource: Variant = item[key].get_ref()
			if is_instance_valid(resource) and resource.changed.is_connected(_invalidate_geometry): resource.changed.disconnect(_invalidate_geometry)
	if _tree != null:
		var tree: Variant = _tree.get_ref()
		if is_instance_valid(tree) and tree.node_added.is_connected(_on_node_added): tree.node_added.disconnect(_on_node_added)
	reset(); _geometry.clear(); _geometry_changed=false; _tree=null
	_ready=false; _prepared=null; _rig=null; _motion=null; _clearance=null; _version=-1

func _invalidate_geometry() -> void:
	_geometry_changed = true

func _on_node_added(node: Node) -> void:
	if not node is MeshInstance3D or _motion == null: return
	var motion: Variant = _motion.get_ref()
	if is_instance_valid(motion) and motion.is_ancestor_of(node): _geometry_changed = true

static func _node_live(node: Variant) -> bool:
	if not is_instance_valid(node) or not node is Node or not node.is_inside_tree(): return false
	while node != null:
		if node.is_queued_for_deletion(): return false
		node = node.get_parent()
	return true

func _live() -> bool:
	if not _ready or _geometry_changed or not Thread.is_main_thread(): return false
	var prepared: Variant = _prepared.get_ref(); var rig: Variant = _rig.get_ref()
	if not (is_instance_valid(prepared) and prepared.get("_ready") and _node_live(rig) and rig.get_version() == _version and _node_live(_motion.get_ref()) and prepared.get("_rig") == _rig and prepared.get("_motion") == _motion): return false
	if not ((_motion.get_ref().global_transform as Transform3D).affine_inverse()*rig.global_transform).is_equal_approx(prepared.get("_to_motion")): return false
	for item: Dictionary in _geometry:
		var mesh: Variant = item.node.get_ref()
		if not _node_live(mesh) or not is_instance_valid(item.mesh.get_ref()) or not is_instance_valid(item.skin.get_ref()) or mesh.mesh != item.mesh.get_ref() or mesh.skin != item.skin.get_ref() or mesh.skeleton != item.skeleton or mesh.get_node_or_null(mesh.skeleton) != rig: return false
	return true

func reset() -> void:
	_records.clear(); _subdivisions.clear(); _pair = Vector2i(-1,-1)

func snapshot(selected: Dictionary, world: Transform3D, use_prepared_cache: bool = true) -> Dictionary:
	if not _live(): return {"valid":false,"reason":"binding"}
	var record := _build(selected,world,use_prepared_cache)
	if not record.get("valid",false): return record
	_serial += 1
	_records[_serial] = record
	while _records.size() > 2: _records.erase(_records.keys()[0])
	return {"valid":true,"id":_serial,"epoch":record.epoch,"owner":get_instance_id()}

func _record(handle: Dictionary) -> Dictionary:
	if not handle.get("valid",false) or handle.get("owner") != get_instance_id() or not handle.get("id") is int: return {}
	var record: Dictionary = _records.get(handle.id,{})
	return record if not record.is_empty() and handle.get("epoch") == record.epoch else {}

func _build(selected: Dictionary, world: Transform3D, use_cache: bool) -> Dictionary:
	var prepared: RefCounted = _prepared.get_ref()
	if not selected.get("valid",false) or not Clearance._uniform(world.basis) or not world.origin.is_finite() or not is_finite(world.basis.determinant()): return {"valid":false,"reason":"world_or_pose"}
	var poses: Variant = selected.get("poses"); var offset: Variant = selected.get("visual_offset")
	var rotation: Variant = selected.get("visual_rotation",Quaternion.IDENTITY); var epoch: Variant = selected.get("authority_epoch")
	if not poses is Array or poses.size()!=_clearance._rest.size() or not offset is Vector3 or not offset.is_finite() or not rotation is Quaternion or not rotation.is_finite() or absf(rotation.length_squared()-1)>.0001 or not epoch is int or epoch<0: return {"valid":false,"reason":"pose"}
	var global: Array[Transform3D] = []; var frames: Array[Transform3D] = []; var rotations: Array[Quaternion] = []
	var prefix := Transform3D(Basis(rotation),Vector3.ZERO)*(prepared.get("_to_motion") as Transform3D)
	for i in poses.size():
		if not poses[i] is Transform3D: return {"valid":false,"reason":"bone"}
		var pose: Transform3D = poses[i]; var rest: Transform3D = _clearance._rest[i]
		if not pose.is_finite() or not Clearance._uniform(pose.basis) or pose.origin.distance_to(rest.origin)>.00001 or pose.basis.get_scale().distance_to(rest.basis.get_scale())>.00001: return {"valid":false,"reason":"canonical_geometry"}
		global.append(pose if _clearance._parents[i]<0 else global[_clearance._parents[i]]*pose)
		frames.append(prefix*global[i]); rotations.append(pose.basis.orthonormalized().get_rotation_quaternion())
		if use_cache and not frames[i].is_equal_approx(prepared.get("_frames")[i]): return {"valid":false,"reason":"stale_prepared_cache"}
	var points := PackedVector3Array()
	if use_cache: points = prepared.get("_deformed")
	else:
		var rigid: Dictionary = prepared.get("_rigid")
		var ends: PackedInt32Array = prepared.get("_ends")
		var bones: PackedInt32Array = prepared.get("_bones")
		var bind_points: PackedVector3Array = prepared.get("_points")
		var weights: PackedFloat32Array = prepared.get("_weights")
		for bone: int in rigid: points.append_array(frames[bone]*(rigid[bone] as PackedVector3Array))
		var first := 0
		for end: int in ends:
			var point := Vector3.ZERO
			for at in range(first,end):
				var frame: Transform3D = frames[bones[at]]
				point += frame.basis*bind_points[at]+frame.origin*weights[at]
			points.append(point); first=end
	if points.size()!=int(prepared.get("_unique_vertices")): return {"valid":false,"reason":"skin_geometry"}
	points = Transform3D(world.basis,world*offset)*points
	return {"valid":true,"points":points,"poses":poses.duplicate(),"visual_offset":offset,"visual_rotation":rotation,"world":world,"epoch":epoch,"rotations":rotations,"bounds":AABB()}

func _at(previous: Dictionary, next: Dictionary, index: int) -> Dictionary:
	if index == 0: return previous
	if index == MAX_PARTS: return next
	if _subdivisions.has(index): return _subdivisions[index]
	var t := float(index)/MAX_PARTS
	var selected := {"valid":true,"poses":[],"visual_offset":(previous.visual_offset as Vector3).lerp(next.visual_offset,t),"visual_rotation":(previous.visual_rotation as Quaternion).slerp(next.visual_rotation,t),"authority_epoch":previous.epoch}
	for i in previous.poses.size():
		var pose: Transform3D = previous.poses[i]
		pose.basis = Basis((previous.rotations[i] as Quaternion).slerp(next.rotations[i],t))*Basis.from_scale(_clearance._rest[i].basis.get_scale())
		selected.poses.append(pose)
	var result := _build(selected,previous.world,false)
	_subdivisions[index] = result
	return result

static func _plane_extrema(points: PackedVector3Array, inverse: Transform3D) -> Dictionary:
	var local := inverse*points
	var low := Vector3(INF,INF,INF); var high := -low
	for point: Vector3 in local:
		if not point.is_finite(): return {}
		low = low.min(point); high = high.max(point)
	return {"low":low,"high":high}

func prove_box_separation(previous_handle: Dictionary, next_handle: Dictionary, box_node: CollisionShape3D, margin: float = .001, max_parts: int = MAX_PARTS) -> Dictionary:
	if not _live() or not _node_live(box_node) or box_node.disabled or not box_node.shape is BoxShape3D or not box_node.get_parent() is PhysicsBody3D: return {"proven":false,"reason":"binding_or_box"}
	if not is_finite(margin) or margin<.001 or margin>.1 or max_parts not in [1,2,4,8]: return {"proven":false,"reason":"limits"}
	var transform := box_node.global_transform; var size: Vector3 = box_node.shape.size
	# Godot collision-node scale/shear semantics are not inferred here. Only
	# actual rigid unit transforms are supported; caller retains all other guards.
	if not transform.is_finite() or not Clearance._uniform(transform.basis) or transform.basis.get_scale().distance_to(Vector3.ONE)>.00001 or minf(size.x,minf(size.y,size.z))<=0 or not size.is_finite(): return {"proven":false,"reason":"box_transform"}
	var previous := _record(previous_handle); var next := _record(next_handle)
	if previous.is_empty() or next.is_empty() or previous.epoch!=next.epoch or previous.world != next.world: return {"proven":false,"reason":"snapshot_or_epoch"}
	var pair := Vector2i(previous_handle.id,next_handle.id)
	if pair != _pair: _subdivisions.clear(); _pair = pair
	var inverse := transform.affine_inverse(); var half := size*.5
	var extrema: Dictionary = {}
	for index in [0,MAX_PARTS]:
		extrema[index] = _plane_extrema((previous if index==0 else next).points,inverse)
		if extrema[index].is_empty(): return {"proven":false,"reason":"nonfinite_projection"}
		var endpoint_gap := -INF
		for axis in 3: endpoint_gap=maxf(endpoint_gap,maxf(extrema[index].low[axis]-half[axis],-half[axis]-extrema[index].high[axis]))
		# Subdivision cannot improve an endpoint that itself has no separating
		# box plane. Fail immediately instead of skinning seven futile midpoints.
		if endpoint_gap<=margin+.00002: return {"proven":false,"reason":"endpoint_not_separate","parts":0,"minimum_clearance_m":endpoint_gap-margin-.00002}
	var last_gap := -INF
	for pieces in [1,2,4,8]:
		if pieces>max_parts: break
		var step: int = MAX_PARTS/pieces; var all_separated := true; var smallest_gap := INF
		for part in pieces:
			var a := _at(previous,next,part*step); var b := _at(previous,next,(part+1)*step)
			if not a.get("valid",false) or not b.get("valid",false): return {"proven":false,"reason":"subdivision_geometry"}
			for index in [part*step,(part+1)*step]:
				if not extrema.has(index): extrema[index] = _plane_extrema((a if index==part*step else b).points,inverse)
				if extrema[index].is_empty(): return {"proven":false,"reason":"nonfinite_projection"}
			var bound: Dictionary = _clearance.between(a,b)
			if not bound.get("valid",false): return {"proven":false,"reason":"continuous_bound"}
			var low: Vector3 = extrema[part*step].low.min(extrema[(part+1)*step].low)
			var high: Vector3 = extrema[part*step].high.max(extrema[(part+1)*step].high)
			var gap := -INF
			for axis in 3: gap=maxf(gap,maxf(low[axis]-half[axis],-half[axis]-high[axis]))
			# Full endpoint skin lies outside one plane. Curvature padding bounds
			# every vertex between endpoints; triangle convexity covers interiors.
			gap -= float(bound.angular_padding_m)+margin
			smallest_gap=minf(smallest_gap,gap)
			if gap<=0: all_separated=false; break
		last_gap=smallest_gap
		if all_separated: return {"proven":true,"reason":"continuous_skin_separating_planes","parts":pieces,"minimum_clearance_m":smallest_gap,"vertices":previous.points.size()}
	return {"proven":false,"reason":"not_proven_separate","parts":max_parts,"minimum_clearance_m":last_gap}
