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
var _support_contact: Dictionary = {}
var _path_blocker: Dictionary = {}
var _path_diagnostic_frame := -100000
var _path_diagnostic_kind := ""
var _last_floor_probe: Dictionary = {}
var _flat_support_patch: RefCounted
var _flat_support_fallback: Dictionary = {}

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
	return {"ok":true,"skin_vertices":_pose._source_vertices,"source_timer_authority":false,"rigid_attachment_bindings":_pose.rigid_attachment_bindings.duplicate(true)}

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

func _record_floor_probe(reason_value: String,hit: Dictionary) -> void:
	# Failure-only observation of the SAME native query; no extra ray, skipped
	# collider, changed threshold or fallback support is introduced.
	_last_floor_probe={"reason":reason_value,"physics_frame":Engine.get_physics_frames(),"from":_point_value(_ray.from),"to":_point_value(_ray.to),"mask":_ray.collision_mask,"excluded_count":_ray.exclude.size(),"expected_floor_y":_floor_y,"hit":_hit_value(hit) if not hit.is_empty() else {}}
	if hit.get("position") is Vector3:_last_floor_probe.height_delta_m=hit.position.y-_floor_y

func _hit(x: float, z: float, top: float, bottom: float) -> Dictionary:
	_ray.from = Vector3(x,top,z); _ray.to = Vector3(x,bottom,z)
	var hit: Dictionary = _actor.get_ref().get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():_record_floor_probe("no_native_hit",hit);return {}
	if not hit.collider is StaticBody3D:_record_floor_probe("native_hit_not_static",hit);return {}
	if hit.normal.dot(Vector3.UP)<.999:_record_floor_probe("native_hit_not_flat_up",hit);return {}
	return hit

func _floor_height(x: float, z: float) -> float:
	var hit := _hit(x,z,_floor_y+.05,_floor_y-.05)
	if hit.is_empty():return NAN
	if absf(hit.position.y-_floor_y)>=.001:_record_floor_probe("native_height_differs_from_support",hit);return NAN
	return float(hit.position.y)

func _grounding_floor_height(x: float, z: float) -> float:
	# A source grid corner can lie outside the actual skin and hit a nearby ramp.
	# This analytical plane is admitted ONLY with native Box identity and complete
	# padded skin-sweep footprint containment in _path_clear. The original nine
	# standing rays and native obstacle query remain authoritative and unchanged.
	if _flat_support_patch != null:
		return _flat_support_patch.height if _flat_support_patch.current() else NAN
	return _floor_height(x,z)

func _fallback_optional_flat_patch(sweep: Dictionary, phase: String) -> bool:
	# One Box is an optional acceleration/proof, not a new requirement. A path
	# crossing adjacent flat floors must retain the original native-ray route.
	# Identity loss is NOT mere lack of coverage and never enables this fallback.
	if _flat_support_patch == null or not sweep.get("valid",false) or not sweep.get("bounds") is AABB or not _flat_support_patch.current():return false
	if _flat_support_patch.contains_sweep(sweep.bounds):return false
	_flat_support_fallback = {"phase":phase,"reason":"single_box_does_not_cover_padded_sweep","patch":_flat_support_patch.evidence(),"pose_recomputed_with_native_floor_rays":false}
	_flat_support_patch = null
	return true

func _sample_proposed_skin(floor_height: Callable) -> bool:
	_proposed = _pose.blend_release(_from,.55+.45*(_elapsed/RISE_SECONDS),floor_height,_base_world,_binding.rig_epoch)
	if not _proposed.get("valid",false):return false
	_proposed_skin = _clearance.snapshot(_proposed,_base_world)
	_proposed_sweep = _clearance.between(_accepted_skin,_proposed_skin,_floor_y)
	return true

func _prepare_proposed_skin() -> bool:
	if not _sample_proposed_skin(_grounding_floor_height):return false
	if not _fallback_optional_flat_patch(_proposed_sweep,"step"):return true
	# Discard the tentative analytical grounding; recompute from the SAME source
	# pose, time and epoch using real rays. No extra advance or borrowed height.
	_flat_support_fallback.pose_recomputed_with_native_floor_rays = true
	return _sample_proposed_skin(_floor_height)

func _support() -> bool:
	var capsule: CapsuleShape3D = _standing_query.shape
	for dx in [-capsule.radius,0.0,capsule.radius]:
		for dz in [-capsule.radius,0.0,capsule.radius]:
			if not is_finite(_floor_height(_target.origin.x+dx,_target.origin.z+dz)): return false
	return true

func _standing_clear() -> bool:
	_standing_query.transform = _target*_capsule_transform
	return _actor.get_ref().get_world_3d().direct_space_state.intersect_shape(_standing_query,1).is_empty()

static func _point_value(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

static func _box_value(box: AABB) -> Dictionary:
	return {"minimum":_point_value(box.position),"maximum":_point_value(box.end),"size":_point_value(box.size)}

func _hit_value(hit: Dictionary) -> Dictionary:
	var value: Dictionary = {"collider_id":hit.get("collider_id",0),"rid":str(hit.get("rid",RID())),"shape_index":hit.get("shape",-1)}
	var collider: Object = hit.get("collider")
	if is_instance_valid(collider):
		value["class"] = collider.get_class()
		if collider is Node:value["path"] = str(collider.get_path())
		if collider is CollisionObject3D:
			value["layer"] = collider.collision_layer;value["mask"] = collider.collision_mask
			value["source_id"] = str(collider.get_meta("source_id",""))
			var index: int = int(hit.get("shape",-1))
			if index >= 0:
				var shape_owner: Object = collider.shape_owner_get_owner(collider.shape_find_owner(index))
				if shape_owner is CollisionShape3D and shape_owner.shape != null:
					value["shape_path"] = str(shape_owner.get_path())
					value["shape_class"] = shape_owner.shape.get_class()
					value["shape_origin"] = _point_value(shape_owner.global_position)
					if shape_owner.shape is BoxShape3D:value["shape_size"] = _point_value(shape_owner.shape.size)
	for key: String in ["position","point","normal"]:
		if hit.get(key) is Vector3:value[key] = _point_value(hit[key])
	return value

func _record_path_blocker(kind: String,sweep: Dictionary,native_hit: Dictionary = {}) -> void:
	# Failure-only, at most once per physics second for an unchanged class.
	# Observations never change the query, clearance result, exclusions or pose.
	var frame: int = Engine.get_physics_frames()
	if kind == _path_diagnostic_kind and frame-_path_diagnostic_frame < Engine.physics_ticks_per_second:return
	_path_diagnostic_kind = kind;_path_diagnostic_frame = frame
	_path_blocker = {"kind":kind,"physics_frame":frame,"floor_y":_floor_y,"support_contact":_support_contact,"canonical_error_m":_canonical_error_m,"sweep_valid":sweep.get("valid",false),"sweep_reason":sweep.get("reason",""),"accepted_skin_valid":_accepted_skin.get("valid",false),"accepted_skin_reason":_accepted_skin.get("reason",""),"proposed_skin_valid":_proposed_skin.get("valid",false),"proposed_skin_reason":_proposed_skin.get("reason",""),"native_query_performed":not native_hit.is_empty()}
	# Real articulated-part contact identities are needed before attributing an
	# invalid support-plane sweep to floor contact. Merely having eight contacts
	# or a nearby support ray is insufficient evidence for a recovery exception.
	var physical_contacts: Array[Dictionary] = []
	for bone: String in _host._body._bodies:
		var part: RigidBody3D = _host._body._bodies[bone]
		var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(part.get_rid())
		if state == null:continue
		for contact: int in state.get_contact_count():
			var other: Object = state.get_contact_collider_object(contact)
			if not is_instance_valid(other) or (other is Node and other.get_parent() == part.get_parent()):continue
			var actual: Dictionary = _hit_value({"collider":other,"collider_id":other.get_instance_id(),"rid":state.get_contact_collider(contact),"shape":state.get_contact_collider_shape(contact),"point":state.get_contact_collider_position(contact),"normal":state.get_contact_local_normal(contact)})
			actual["bone"] = bone
			actual["body_side_position_raw"] = _point_value(state.get_contact_local_position(contact))
			physical_contacts.append(actual)
			if physical_contacts.size() >= 16:break
		if physical_contacts.size() >= 16:break
	_path_blocker["native_part_contacts_max16"] = physical_contacts
	for item: Dictionary in [{"name":"accepted","skin":_accepted_skin},{"name":"proposed","skin":_proposed_skin}]:
		if item.skin.get("bounds") is AABB:
			var bounds: AABB = item.skin.bounds
			_path_blocker[item.name+"_bounds"] = _box_value(bounds)
			_path_blocker[item.name+"_below_floor_m"] = maxf(0.0,_floor_y-bounds.position.y)
	if sweep.get("bounds") is AABB:_path_blocker["sweep_bounds"] = _box_value(sweep.bounds)
	if native_hit.is_empty():return
	_path_blocker["first_collider"] = _hit_value(native_hit)
	_path_blocker["query_center"] = _point_value(_sweep_query.transform.origin)
	_path_blocker["query_size"] = _point_value(_sweep_shape.size)
	_path_blocker["query_margin"] = _sweep_query.margin
	_path_blocker["query_mask"] = _sweep_query.collision_mask
	_path_blocker["excluded_count"] = _sweep_query.exclude.size()
	var space: PhysicsDirectSpaceState3D = _actor.get_ref().get_world_3d().direct_space_state
	var hits: Array[Dictionary] = []
	for hit: Dictionary in space.intersect_shape(_sweep_query,4):hits.append(_hit_value(hit))
	_path_blocker["colliders_max4"] = hits
	var rest: Dictionary = space.get_rest_info(_sweep_query)
	_path_blocker["nearest_rest"] = _hit_value(rest) if not rest.is_empty() else {}
	var points: Array[Vector3] = space.collide_shape(_sweep_query,8)
	var pairs: Array[Dictionary] = []
	for index: int in range(0,points.size()-1,2):
		pairs.append({"query_point":_point_value(points[index]),"collider_point":_point_value(points[index+1]),"separation_m":points[index].distance_to(points[index+1]),"delta":_point_value(points[index+1]-points[index])})
	_path_blocker["contact_pairs_max8"] = pairs
	_path_blocker["pair_identity_note"] = "Native pair points have no per-pair collider ID; use nearest_rest for identified normal/point."

func _path_clear(sweep: Dictionary) -> bool:
	if not sweep.get("valid",false):
		_record_path_blocker("invalid_sweep:"+str(sweep.get("reason","unknown")),sweep)
		return false
	var box: AABB = sweep.bounds
	if _flat_support_patch != null and not _flat_support_patch.contains_sweep(box):
		_record_path_blocker("flat_support_patch_changed_or_edge",sweep)
		return false
	var upper := box.end; var lower := box.position
	# between(..., flat_support_y) proves a continuously grounded full skin.
	# Keep the accepted support plane in collision queries, clipping ONLY the
	# mathematically sub-plane padding, not excluding an entire compound floor.
	lower.y = maxf(lower.y,_floor_y+.001)
	if upper.y <= lower.y:
		_record_path_blocker("empty_above_support",sweep)
		return false
	_sweep_shape.size = (upper-lower).max(Vector3.ONE*.001)
	_sweep_query.transform = Transform3D(Basis.IDENTITY,(upper+lower)*.5)
	var hits: Array[Dictionary] = _actor.get_ref().get_world_3d().direct_space_state.intersect_shape(_sweep_query,1)
	if not hits.is_empty():_record_path_blocker("native_overlap",sweep,hits[0])
	return hits.is_empty()

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
	_support_contact = _hit_value(hit)
	_floor_y = hit.position.y
	_flat_support_patch = FlatSupportPatch.capture(hit,_mask)
	_flat_support_fallback = {}
	if _flat_support_patch != null: _floor_y = _flat_support_patch.height
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
	# No analytical grounding has run at this point: _from is the actual physical
	# pose. Lack of single-Box coverage may use the unchanged original path proof.
	_fallback_optional_flat_patch(_proposed_sweep,"attempt")
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
	if not _prepare_proposed_skin(): _busy = false; return _cancel("floor_or_pose_changed")
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
	return {"mode":mode,"reason":reason,"attempts":attempts,"interruptions":interruptions,"walking_ready":mode == "DONE" and _host != null and _host.mode == "IDLE","source_timer_authority":false,"getup_progress":_elapsed/RISE_SECONDS,"last_path_blocker":_path_blocker,"last_floor_probe":_last_floor_probe,"flat_support_patch":_flat_support_patch.evidence() if _flat_support_patch != null else {},"flat_support_fallback":_flat_support_fallback}

func dispose() -> void:
	if mode == "DISPOSED": return
	if _host != null and _host.mode == "RECOVERING":
		var resumed: Dictionary = _host.cancel_recovery("recovery_disposed")
		if not resumed.get("ok",false): _host.retire("recovery_dispose_failed")
	_remove_guard()
	if _pose != null: _pose.dispose()
	_current = Callable(); _gate = Callable(); mode = "DISPOSED"

# A continuously covered FLAT support region, not general terrain interpolation.
# Reading the exact native Box proves no unseen hole between sparse ray samples.
# Native whole-skin overlap still tests this body and all its compound shapes.
class FlatSupportPatch extends RefCounted:
	const EDGE_INSET := .001
	var height := 0.0
	var failure := ""
	var _body: WeakRef
	var _node: WeakRef
	var _shape: WeakRef
	var _body_rid: RID
	var _shape_rid: RID
	var _owner := -1
	var _index := -1
	var _count := 0
	var _layer := 0
	var _collision_mask := 0
	var _mask := 0
	var _body_frame := Transform3D.IDENTITY
	var _shape_frame := Transform3D.IDENTITY
	var _world_frame := Transform3D.IDENTITY
	var _inverse := Transform3D.IDENTITY
	var _size := Vector3.ZERO
	var _last_bounds := AABB()
	var _contained := false

	static func flat_box_top(frame: Transform3D, size: Vector3) -> Dictionary:
		if not frame.is_finite() or not size.is_finite() or size.min_axis_index() < 0 or minf(size.x,minf(size.y,size.z)) <= 0.0 or frame.basis.determinant() <= .000001:return {}
		# Exact horizontal top required. Yaw and independent positive axis scales
		# are supported; pitch/roll/shear are deliberately not a flat-plane proof.
		var b: Basis = frame.basis
		if b.x.y != 0.0 or b.z.y != 0.0 or b.y.x != 0.0 or b.y.z != 0.0 or b.y.y <= 0.0 or absf(b.x.normalized().dot(b.z.normalized())) > .000001:return {}
		return {"height":frame.origin.y+b.y.y*size.y*.5,"inverse":frame.affine_inverse()}

	static func footprint_contains(inverse: Transform3D, size: Vector3, floor_y: float, box: AABB) -> bool:
		if not inverse.is_finite() or not size.is_finite() or not is_finite(floor_y) or not box.position.is_finite() or not box.size.is_finite() or minf(box.size.x,minf(box.size.y,box.size.z)) < 0.0:return false
		for x: float in [box.position.x,box.end.x]:
			for z: float in [box.position.z,box.end.z]:
				var local: Vector3 = inverse*Vector3(x,floor_y,z)
				if absf(local.x) > size.x*.5-EDGE_INSET or absf(local.z) > size.z*.5-EDGE_INSET:return false
		return true

	static func capture(hit: Dictionary, mask: int) -> RefCounted:
		var body: Variant = hit.get("collider")
		var index: int = int(hit.get("shape",-1))
		if not body is StaticBody3D or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or index < 0 or not hit.get("position") is Vector3:return null
		var rid: RID = body.get_rid()
		var count: int = PhysicsServer3D.body_get_shape_count(rid)
		if index >= count or count > 64 or (body.collision_layer & mask) == 0:return null
		var owner: int = body.shape_find_owner(index)
		var node: Object = body.shape_owner_get_owner(owner)
		if not node is CollisionShape3D or node.get_parent() != body or node.disabled or node.is_queued_for_deletion() or not node.shape is BoxShape3D:return null
		var patch := FlatSupportPatch.new()
		patch._body = weakref(body);patch._node = weakref(node);patch._shape = weakref(node.shape)
		patch._body_rid = rid;patch._shape_rid = node.shape.get_rid();patch._owner = owner;patch._index = index;patch._count = count
		patch._layer = body.collision_layer;patch._collision_mask = body.collision_mask;patch._mask = mask
		patch._body_frame = body.global_transform
		patch._shape_frame = PhysicsServer3D.body_get_shape_transform(rid,index)
		patch._world_frame = patch._body_frame*patch._shape_frame;patch._size = node.shape.size
		var top: Dictionary = flat_box_top(patch._world_frame,patch._size)
		if top.is_empty() or absf((hit.position as Vector3).y-float(top.height)) > .00005:return null
		patch.height = top.height;patch._inverse = top.inverse
		return patch if patch.current() else null

	func _reject(why: String) -> bool:
		failure = why
		return false

	func current() -> bool:
		var body: StaticBody3D = _body.get_ref()
		var node: CollisionShape3D = _node.get_ref()
		var shape: BoxShape3D = _shape.get_ref()
		if not is_instance_valid(body) or not is_instance_valid(node) or not is_instance_valid(shape) or not body.is_inside_tree() or body.is_queued_for_deletion() or node.is_queued_for_deletion() or node.get_parent() != body:return _reject("support_removed")
		if body.get_rid() != _body_rid or body.global_transform != _body_frame or body.collision_layer != _layer or body.collision_mask != _collision_mask or (_layer & _mask) == 0:return _reject("support_body_changed")
		if node.shape != shape or shape.get_rid() != _shape_rid or shape.size != _size or node.disabled or node.global_transform != _world_frame:return _reject("support_shape_changed")
		if not body.get_shape_owners().has(_owner) or body.shape_owner_get_owner(_owner) != node or body.shape_owner_get_shape_count(_owner) != 1 or body.shape_owner_get_shape_index(_owner,0) != _index or body.is_shape_owner_disabled(_owner):return _reject("support_owner_changed")
		if PhysicsServer3D.body_get_shape_count(_body_rid) != _count or PhysicsServer3D.body_get_shape(_body_rid,_index) != _shape_rid or PhysicsServer3D.body_get_state(_body_rid,PhysicsServer3D.BODY_STATE_TRANSFORM) != _body_frame or PhysicsServer3D.body_get_shape_transform(_body_rid,_index) != _shape_frame:return _reject("support_native_binding_changed")
		if PhysicsServer3D.shape_get_type(_shape_rid) != PhysicsServer3D.SHAPE_BOX or PhysicsServer3D.shape_get_data(_shape_rid) != _size*.5:return _reject("support_native_shape_changed")
		failure = ""
		return true

	func contains_sweep(box: AABB) -> bool:
		_last_bounds = box;_contained = false
		if not current():return false
		_contained = footprint_contains(_inverse,_size,height,box)
		if not _contained:failure = "padded_skin_sweep_outside_support"
		return _contained

	func evidence() -> Dictionary:
		var node: CollisionShape3D = _node.get_ref()
		return {"kind":"exact_native_flat_box_patch","shape_path":str(node.get_path()) if is_instance_valid(node) and node.is_inside_tree() else "","shape_index":_index,"height":height,"failure":failure,"last_sweep_contained":_contained,"last_sweep_min":[_last_bounds.position.x,_last_bounds.position.y,_last_bounds.position.z],"last_sweep_max":[_last_bounds.end.x,_last_bounds.end.y,_last_bounds.end.z],"general_slope_support":false}

# NPC adapter for the existing proved skin/path machinery. Source hero helper
# rejects indexed binds and hardcodes8338vertices; no shared helper is changed.
class NpcPreparedPose extends CharacterPose:
	var rigid_attachment_bindings: Array[Dictionary] = []

	static func authored_rigid_bind(skeleton: Skeleton3D, mesh: MeshInstance3D) -> Dictionary:
		# A BoneAttachment's global transform can still describe the preceding
		# ragdoll pose immediately after the sole writer commits standing bones.
		# Derive its rigid mesh binding from authored descendants only. Reading
		# inverse(current bone) * stale mesh.global would bake that frame lag into
		# every subsequent skin-clearance snapshot. No bone/mesh node is mutated.
		if not is_instance_valid(skeleton) or not is_instance_valid(mesh):return {}
		var relative := Transform3D.IDENTITY
		var cursor: Node = mesh
		while cursor != null and cursor != skeleton and not cursor is BoneAttachment3D:
			if not cursor is Node3D or cursor.is_set_as_top_level() or not cursor.transform.is_finite():return {}
			relative = cursor.transform * relative
			cursor = cursor.get_parent()
		if not cursor is BoneAttachment3D or cursor.get_parent() != skeleton or cursor.override_pose or cursor.use_external_skeleton:return {}
		var bone: int = skeleton.find_bone(str(cursor.bone_name)) if not str(cursor.bone_name).is_empty() else cursor.bone_idx
		if bone < 0 or bone >= skeleton.get_bone_count() or not relative.is_finite():return {}
		return {"bone":bone,"to_bone":relative}

	func configure(skeleton: Skeleton3D, motion: Node3D, canonical_rest: Array[Transform3D], source_scale: float, hero_root: Node3D) -> bool:
		if _busy or not Thread.is_main_thread(): return false
		_ready = false
		if not is_instance_valid(skeleton) or not is_instance_valid(motion) or not is_instance_valid(hero_root) or not is_finite(source_scale) or source_scale <= 0 or source_scale > 10: return false
		if canonical_rest.size() != skeleton.get_bone_count() or canonical_rest.size() > 128: return false
		_rest = canonical_rest.duplicate(); _parents.clear(); _names.clear(); _global.clear(); _frames.clear()
		_bones.clear(); _points.clear(); _weights.clear(); _ends.clear(); _source_vertices = 0
		_rigid.clear(); _unique_vertices = 0; _packed_influences = 0; rigid_attachment_bindings.clear()
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
				var binding: Dictionary = authored_rigid_bind(skeleton,mesh)
				if binding.is_empty():return false
				var rigid_bone: int = binding.bone
				var to_bone: Transform3D = binding.to_bone
				# Read-only evidence of notification lag at this actual rebind.
				var current_bone_world: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(rigid_bone)
				var authored_mesh_world: Transform3D = current_bone_world*to_bone
				var actual_mesh_world: Transform3D = mesh.global_transform
				var binding_row: Dictionary = {"mesh_path":str(mesh.get_path()),"bone":str(skeleton.get_bone_name(rigid_bone)),"vertices":0,"legacy_world_drift_m":0.0,"binding":"authored_attachment_descendants"}
				if not _rigid.has(rigid_bone): _rigid[rigid_bone] = PackedVector3Array()
				for surface in mesh.mesh.get_surface_count():
					var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					_source_vertices += vertices.size()
					binding_row.vertices += vertices.size()
					if _source_vertices > 20000: return false
					for vertex: Vector3 in vertices:
						var point: Vector3 = to_bone*vertex
						if not point.is_finite(): return false
						binding_row.legacy_world_drift_m = maxf(float(binding_row.legacy_world_drift_m),(authored_mesh_world*vertex).distance_to(actual_mesh_world*vertex))
						_rigid[rigid_bone].append(point); _unique_vertices += 1; _packed_influences += 1
				rigid_attachment_bindings.append(binding_row)
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
