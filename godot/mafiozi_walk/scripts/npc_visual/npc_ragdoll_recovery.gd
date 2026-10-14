extends RefCounted
## Physical recovery coordinator, NOT source stun/HP/death policy. Requires a
## current external source-release projection on every attempted/accepted step.
## Flat static support only; unknown/moving support and blocked paths retry.
const CharacterPose = preload("res://scripts/character_physics/character_physics_pose.gd")
const Clearance = preload("res://scripts/character_physics/recovery_clearance.gd")
const RETRY_SECONDS := .25
const RISE_SECONDS := .9 # Visual duration only, never a source release timer.
var mode := "UNBOUND"
var reason := ""
var attempts := 0
var interruptions := 0
var _host: RefCounted
var _actor: WeakRef
var _rig: WeakRef
var _motion: WeakRef
var _world: WeakRef
var _binding: Dictionary
var _current := Callable()
var _gate := Callable()
var _pose: RefCounted
var _clearance: RefCounted
var _capsule: WeakRef
var _capsule_rid: RID
var _capsule_transform: Transform3D
var _base_motion: Transform3D
var _mask := 257
var _walking_layer := 0
var _walking_mask := 0
var _guard: StaticBody3D
var _guard_shape: BoxShape3D
var _guard_collision: CollisionShape3D
var _standing_query := PhysicsShapeQueryParameters3D.new()
var _sweep_query := PhysicsShapeQueryParameters3D.new()
var _sweep_shape := BoxShape3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _floor_y := 0.0
var _target := Transform3D.IDENTITY
var _base_world := Transform3D.IDENTITY
var _from: Dictionary
var _accepted_skin: Dictionary
var _proposed_skin: Dictionary
var _proposed_sweep: Dictionary
var _proposed: Dictionary
var _reaction: Variant
var _wait := 0.0
var _elapsed := 0.0
var _busy := false
var _gate_dead := false
var _source_revision := -1
var _previous_settled := false
var _committed := false
var _canonical_error_m := 0.0

func configure(host: RefCounted, token: Dictionary, motion: Node3D, world: Node3D, current_binding: Callable, source_release: Callable) -> Dictionary:
	if mode != "UNBOUND" or not Thread.is_main_thread() or host == null or not current_binding.is_valid() or not source_release.is_valid(): return {"ok":false,"reason":"binding"}
	var actor: Variant = token.get("body"); var rig: Variant = token.get("rig")
	if not actor is CharacterBody3D or not is_instance_valid(actor) or not rig is Skeleton3D or not is_instance_valid(rig) or not is_instance_valid(motion) or not is_instance_valid(world) or not motion.is_ancestor_of(rig) or not actor.is_ancestor_of(motion): return {"ok":false,"reason":"nodes"}
	var status: Dictionary = host.status()
	if status.get("mode") != "IDLE" or not status.get("binding") is Dictionary: return {"ok":false,"reason":"prewarm_only"}
	_binding = status.binding.duplicate()
	for key: String in _binding:
		if typeof(token.get(key)) != typeof(_binding[key]) or token.get(key) != _binding[key]: return {"ok":false,"reason":"identity"}
	var shapes: Array[CollisionShape3D] = []
	for child: Node in actor.get_children():
		if child is CollisionShape3D and not child.disabled: shapes.append(child)
	if shapes.size() != 1 or not shapes[0].shape is CapsuleShape3D: return {"ok":false,"reason":"walking_shape"}
	_host = host; _actor = weakref(actor); _rig = weakref(rig); _motion = weakref(motion); _world = weakref(world)
	_current = current_binding; _gate = source_release; _capsule = weakref(shapes[0]); _capsule_rid = shapes[0].shape.get_rid(); _capsule_transform = shapes[0].transform; _base_motion = motion.transform
	_mask = actor.collision_mask | 256
	_walking_layer = actor.collision_layer; _walking_mask = actor.collision_mask
	_pose = NpcPreparedPose.new()
	var rest: Array[Transform3D] = []
	for i in rig.get_bone_count(): rest.append(rig.get_bone_rest(i))
	if not _pose.configure(rig,motion,rest,1.0,motion): return {"ok":false,"reason":"npc_skin_binding","detail":_pose.diagnostics() if _pose.has_method("diagnostics") else _pose.get_status(),"target":_pose._tuck_target}
	_clearance = Clearance.new()
	if not _clearance.configure(_pose): return {"ok":false,"reason":"skin_path_binding"}
	_standing_query.shape = shapes[0].shape; _standing_query.collision_mask = _mask; _standing_query.margin = .001
	_sweep_query.shape = _sweep_shape; _sweep_query.collision_mask = _mask; _sweep_query.margin = .0005
	_ray.collision_mask = _mask
	mode = "WAITING"
	return {"ok":true,"skin_vertices":_pose._source_vertices,"source_timer_authority":false}

func _same_binding(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: String in _binding:
		if typeof(value.get(key)) != typeof(_binding[key]) or value.get(key) != _binding[key]: return false
	return true

func _alive_binding() -> bool:
	if not _current.is_valid() or not is_instance_valid(_actor.get_ref()) or not is_instance_valid(_rig.get_ref()) or not is_instance_valid(_motion.get_ref()) or not is_instance_valid(_world.get_ref()): return false
	var capsule: CollisionShape3D = _capsule.get_ref()
	if not is_instance_valid(capsule) or capsule.disabled or capsule.shape == null or capsule.shape.get_rid() != _capsule_rid or capsule.transform != _capsule_transform or _motion.get_ref().transform != _base_motion: return false
	var actor: CharacterBody3D = _actor.get_ref()
	var walking: bool = _host.mode == "IDLE"
	if actor.collision_layer != (_walking_layer if walking else 0) or actor.collision_mask != (_walking_mask if walking else 0): return false
	var result: Variant = _current.call(_binding.duplicate())
	return result is bool and result

func _source_allows(phase: String) -> bool:
	if not _gate.is_valid() or not _alive_binding(): return false
	var row: Variant = _gate.call(_binding.duplicate(),phase)
	if not row is Dictionary or not _same_binding(row.get("binding")) or not row.get("known") is bool or not row.known or not row.get("final_dead") is bool or not row.get("release_allowed") is bool or not row.get("revision") is int or row.revision < 0 or row.revision < _source_revision or not (row.get("reaction_generation") is int or row.get("reaction_generation") is String): return false
	_source_revision = row.revision
	_gate_dead = _gate_dead or row.final_dead
	if _gate_dead or not row.release_allowed: return false
	if mode == "RISING" and (typeof(row.reaction_generation) != typeof(_reaction) or row.reaction_generation != _reaction): return false
	_reaction = row.reaction_generation
	return _alive_binding() and not _host.status().final_dead

func _exclusions() -> void:
	var excluded: Array[RID] = [_actor.get_ref().get_rid()]
	for body: RigidBody3D in _host.owned_bodies(): excluded.append(body.get_rid())
	if is_instance_valid(_guard): excluded.append(_guard.get_rid())
	_standing_query.exclude = excluded; _sweep_query.exclude = excluded; _ray.exclude = excluded

func _hit(x: float, z: float, top: float, bottom: float) -> Dictionary:
	_ray.from = Vector3(x,top,z); _ray.to = Vector3(x,bottom,z)
	var hit: Dictionary = _actor.get_ref().get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.dot(Vector3.UP)<.999: return {}
	return hit

func _floor_height(x: float, z: float) -> float:
	var hit := _hit(x,z,_floor_y+.05,_floor_y-.05)
	return float(hit.position.y) if not hit.is_empty() and absf(hit.position.y-_floor_y)<.001 else NAN

func _support() -> bool:
	var capsule: CapsuleShape3D = _standing_query.shape
	for dx in [-capsule.radius,0.0,capsule.radius]:
		for dz in [-capsule.radius,0.0,capsule.radius]:
			if not is_finite(_floor_height(_target.origin.x+dx,_target.origin.z+dz)): return false
	return true

func _standing_clear() -> bool:
	_standing_query.transform = _target*_capsule_transform
	return _actor.get_ref().get_world_3d().direct_space_state.intersect_shape(_standing_query,1).is_empty()

func _path_clear(sweep: Dictionary) -> bool:
	if not sweep.get("valid",false): return false
	var box: AABB = sweep.bounds
	var upper := box.end; var lower := box.position
	# between(..., flat_support_y) proves a continuously grounded full skin.
	# Keep the accepted support plane in collision queries, clipping ONLY the
	# mathematically sub-plane padding, not excluding an entire compound floor.
	lower.y = maxf(lower.y,_floor_y+.001)
	if upper.y <= lower.y: return false
	_sweep_shape.size = (upper-lower).max(Vector3.ONE*.001)
	_sweep_query.transform = Transform3D(Basis.IDENTITY,(upper+lower)*.5)
	return _actor.get_ref().get_world_3d().direct_space_state.intersect_shape(_sweep_query,1).is_empty()

func _proof(phase: String, binding: Dictionary) -> bool:
	return _same_binding(binding) and _source_allows(phase) and _support() and _standing_clear() and _path_clear(_proposed_sweep)

func _frames(pose: Dictionary) -> Dictionary:
	var result := {}; var globals: Array[Transform3D] = []
	var prefix: Transform3D = _base_world*Transform3D(Basis(pose.visual_rotation),pose.visual_offset)*_pose._to_motion
	var rig: Skeleton3D = _rig.get_ref()
	for i in pose.poses.size():
		var parent := rig.get_bone_parent(i)
		globals.append(pose.poses[i] if parent<0 else globals[parent]*pose.poses[i])
		result[str(rig.get_bone_name(i))] = prefix*globals[i]
	return result

func _set_guard(box: AABB) -> void:
	if not is_instance_valid(_guard):
		_guard = StaticBody3D.new(); _guard.name = "NpcRecoveryCollisionGuard"
		_guard_shape = BoxShape3D.new(); _guard_collision = CollisionShape3D.new(); _guard_collision.shape = _guard_shape; _guard.add_child(_guard_collision); _world.get_ref().add_child(_guard)
	var lower := box.position; var upper := box.end
	lower.y = maxf(lower.y,_floor_y+.002)
	_guard_shape.size = (upper-lower).max(Vector3.ONE*.001)
	_guard.global_transform = Transform3D(Basis.IDENTITY,(upper+lower)*.5)
	_guard.collision_layer = 256; _guard.collision_mask = _mask
	_exclusions()

func _remove_guard() -> void:
	if is_instance_valid(_guard): _guard.free()
	_guard = null; _guard_shape = null; _guard_collision = null

func _cancel(why: String) -> Dictionary:
	interruptions += 1
	var resumed: Dictionary = _host.cancel_recovery(why) if _host.mode == "RECOVERING" else {"ok":_host.mode == "ACTIVE"}
	if not resumed.get("ok",false): mode = "HOLD"; reason = "physical_resume_unproved"; return status()
	_remove_guard(); mode = "WAITING"; reason = why; _wait = RETRY_SECONDS; _elapsed = 0
	return status()

func _attempt(physical: Dictionary) -> bool:
	attempts += 1; _exclusions()
	if not _source_allows("attempt"): reason = "source_dead" if _gate_dead else "source_not_released"; return false
	if not physical.get("settled",false): reason = "physical_not_settled"; return false
	var anchor: Vector3 = physical.anchor_world
	var hit := _hit(anchor.x,anchor.z,anchor.y+.5,anchor.y-2.5)
	if hit.is_empty(): reason = "support_unknown"; return false
	_floor_y = hit.position.y
	_target = _actor.get_ref().global_transform; _target.origin = Vector3(anchor.x,_floor_y+.003,anchor.z)
	_base_world = _target*_base_motion
	if not _support() or not _standing_clear(): reason = "standing_blocked"; return false
	_from = _pose.from_world_frames(physical.bone_world_frames,_binding.rig_epoch)
	if not _from.get("valid",false): reason = "pose_conversion"; return false
	var previous_base: Transform3D = _actor.get_ref().global_transform*_base_motion
	_from.visual_offset += _base_world.basis.inverse()*(previous_base.origin-_base_world.origin)
	var initial_frames := _frames(_from)
	var correction := 0.0
	for name: String in initial_frames: correction = maxf(correction,(initial_frames[name] as Transform3D).origin.distance_to(physical.bone_world_frames[name].origin))
	_canonical_error_m = correction
	if correction>.004: reason = "physical_pose_not_canonical_yet"; return false
	_accepted_skin = _clearance.snapshot(_from,_base_world,false)
	_proposed_skin = _accepted_skin; _proposed = _from
	_proposed_sweep = _clearance.between(_accepted_skin,_accepted_skin,_floor_y)
	if not _path_clear(_proposed_sweep): reason = "initial_skin_blocked"; return false
	_set_guard(_proposed_sweep.bounds)
	var started: Dictionary = _host.begin_recovery(_guard,_proof)
	if not started.get("ok",false): _remove_guard(); reason = "begin:"+str(started.get("error")); return false
	mode = "RISING"; _elapsed = 0.0; reason = ""
	return true

func advance(delta: float, physical: Dictionary = {}) -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode in ["UNBOUND","DISPOSED","HOLD"] or not is_finite(delta) or delta<=0 or delta>.05: return status()
	_busy = true
	if not _alive_binding(): _busy = false; dispose(); reason = "stale_life_or_rig"; return status()
	if _host.status().final_dead:
		if _host.mode == "RECOVERING": _cancel("final_dead")
		if mode == "HOLD" or _host.mode == "RECOVERY_HOLD":
			mode = "HOLD"; reason = "final_dead_physical_resume_unproved"; _busy = false; return status()
		_remove_guard(); mode = "FINAL_DEAD"; reason = "final_dead"; _busy = false; return status()
	if mode == "FINAL_DEAD": _busy = false; return status()
	if _host.mode == "IDLE":
		mode = "DONE" if _committed else "WAITING"
		reason = "" if _committed else "awaiting_physical_activation"
		_busy = false; return status()
	if mode == "DONE": mode = "WAITING"; _committed = false
	if mode == "WAITING":
		var sample: Dictionary = physical if not physical.is_empty() else _host.advance()
		if not sample.get("ok",false): _busy = false; reason = "physical_unavailable"; return status()
		_wait -= delta
		var settled: bool = sample.physical.get("settled",false)
		# A brief physically settled interval must not be missed by the retry clock.
		if _wait<=0 or (settled and not _previous_settled): _wait = RETRY_SECONDS; _attempt(sample.physical)
		_previous_settled = settled
		_busy = false; return status()
	if not _source_allows("step"):
		var why := "final_dead" if _gate_dead else "source_restun_or_held"
		var value := _cancel(why)
		if _gate_dead and mode != "HOLD": mode = "FINAL_DEAD"
		_busy = false; return status()
	_elapsed = minf(RISE_SECONDS,_elapsed+delta)
	_proposed = _pose.blend_release(_from,.55+.45*(_elapsed/RISE_SECONDS),_floor_height,_base_world,_binding.rig_epoch)
	if not _proposed.get("valid",false): _busy = false; return _cancel("floor_or_pose_changed")
	_proposed_skin = _clearance.snapshot(_proposed,_base_world)
	_proposed_sweep = _clearance.between(_accepted_skin,_proposed_skin,_floor_y)
	if not _support() or not _standing_clear() or not _path_clear(_proposed_sweep): _busy = false; return _cancel("support_or_path_blocked")
	_set_guard(_proposed_sweep.bounds)
	var applied: Dictionary = _host.apply_recovery_pose(_frames(_proposed),_proof)
	if not applied.get("ok",false): _busy = false; return _cancel("pose_proof_changed")
	_accepted_skin = _proposed_skin
	if _elapsed>=RISE_SECONDS:
		if _proposed.visual_offset.length()>.0001 or _proposed.visual_rotation.angle_to(Quaternion.IDENTITY)>.0001: _busy = false; return _cancel("noncanonical_standing_end")
		var poses: Array[Transform3D] = []; poses.assign(_proposed.poses)
		var committed: Dictionary = _host.commit_recovery(_target,poses,_proof)
		if not committed.get("ok",false): _busy = false; return _cancel("commit_proof_changed")
		_remove_guard(); mode = "DONE"; _committed = true; reason = ""
	_busy = false; return status()

func status() -> Dictionary:
	return {"mode":mode,"reason":reason,"attempts":attempts,"interruptions":interruptions,"walking_ready":mode == "DONE" and _host != null and _host.mode == "IDLE","source_timer_authority":false,"getup_progress":_elapsed/RISE_SECONDS}

func dispose() -> void:
	if mode == "DISPOSED": return
	if _host != null and _host.mode == "RECOVERING":
		var resumed: Dictionary = _host.cancel_recovery("recovery_disposed")
		if not resumed.get("ok",false): _host.retire("recovery_dispose_failed")
	_remove_guard()
	if _pose != null: _pose.dispose()
	_current = Callable(); _gate = Callable(); mode = "DISPOSED"

# NPC adapter for the existing proved skin/path machinery. Source hero helper
# rejects indexed binds and hardcodes8338vertices; no shared helper is changed.
class NpcPreparedPose extends CharacterPose:
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
			if mesh.mesh == null: return false
			if mesh.skin == null:
				var attachment: Node = mesh.get_parent()
				while attachment != null and attachment != hero_root and not attachment is BoneAttachment3D: attachment = attachment.get_parent()
				if not attachment is BoneAttachment3D or attachment.get_parent() != skeleton or attachment.override_pose: return false
				var rigid_bone: int = skeleton.find_bone(str(attachment.bone_name)) if not str(attachment.bone_name).is_empty() else attachment.bone_idx
				if rigid_bone < 0 or rigid_bone >= skeleton.get_bone_count(): return false
				var to_bone: Transform3D = (skeleton.global_transform*skeleton.get_bone_global_pose(rigid_bone)).affine_inverse()*mesh.global_transform
				if not _rigid.has(rigid_bone): _rigid[rigid_bone] = PackedVector3Array()
				for surface in mesh.mesh.get_surface_count():
					var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					_source_vertices += vertices.size()
					if _source_vertices > 20000: return false
					for vertex: Vector3 in vertices:
						var point: Vector3 = to_bone*vertex
						if not point.is_finite(): return false
						_rigid[rigid_bone].append(point); _unique_vertices += 1; _packed_influences += 1
				continue
			var ids := PackedInt32Array(); var binds: Array[Transform3D] = []
			for i in mesh.skin.get_bind_count():
				var name := str(mesh.skin.get_bind_name(i))
				var bone := skeleton.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(i)
				if bone >= skeleton.get_bone_count(): return false
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
		_ready = _source_vertices > 0 and _source_vertices <= 20000 and _unique_vertices > 0
		_skeleton_ref = weakref(skeleton)
		_tuck_target = sample(1.0,1.0,Callable(),null,0)
		return _ready and bool(_tuck_target.get("valid",false))
