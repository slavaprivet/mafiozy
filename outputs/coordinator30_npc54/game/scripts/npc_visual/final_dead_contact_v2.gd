extends "res://scripts/npc_visual/final_dead_contact_port.gd"
## OUTPUTS-ONLY, unrun. ONE port instance handles v1/v2 with shared force state.
const V2_SCHEMA := "npc_final_dead_contact/v2"
const BLOCKING_BIT := 1024
const BLOCKING_LAYER := 256 | BLOCKING_BIT
const V2_ENGINE_HASH := "ed1daf0bf001b61586d9930840f2f1394092c079"
const RagdollV2 = preload("npc_ragdoll_host_v2.gd")
var _v2_enabled := false
var _last_attempted_move := -1
var _part_properties: Dictionary = {}
var _capsule_properties: Dictionary = {}
var _registered_world: RID

func configure(player: CharacterBody3D, records: Array, options: Dictionary) -> Dictionary:
	if options.get("contact_schema", SCHEMA) == SCHEMA: return super.configure(player, records, options)
	if options.get("contact_schema") != V2_SCHEMA or not RagdollV2.blocking_backend_current(): return {"ok": false, "reason": "v2_contract_or_backend"}
	if not is_instance_valid(player) or not player.has_method("final_dead_block_contract_receipt"): return {"ok":false,"reason":"root_negotiated_receipt_required"}
	var negotiated: Dictionary = player.final_dead_block_contract_receipt()
	if negotiated.get("contract") != _static_contract() or negotiated.get("active") != false or negotiated.get("actor_instance_id") != player.get_instance_id() or negotiated.get("actor_rid") != player.get_rid() or negotiated.get("actor_layer") != 2 or negotiated.get("actor_mask") != 1 or player.collision_layer != 2 or player.collision_mask != 1: return {"ok":false,"reason":"root_negotiated_receipt_mismatch"}
	_registered_world = player.get_world_3d().space
	if not is_instance_valid(player) or not player.has_method("completed_ground_pressure_receipt") or not player.has_method("completed_ground_slide_contact"): return {"ok": false, "reason": "root_pressure_receipt_required"}
	var contract: Dictionary = _static_contract()
	for item: Variant in records:
		if not item is Dictionary or not is_instance_valid(item.get("ragdoll_host")) or not item.ragdoll_host.has_method("final_dead_block_contract") or item.ragdoll_host.final_dead_block_contract() != contract: return {"ok": false, "reason": "matching_npc_lifecycle_required"}
	var configured: Dictionary = super.configure(player, records, options)
	if not configured.get("ok", false): return configured
	if player.final_dead_block_contract_receipt() != negotiated or player.get_world_3d().space != _registered_world: dispose(); return {"ok":false,"reason":"root_negotiation_changed"}
	var capsule: CollisionShape3D = _capsule.get_ref()
	_capsule_properties = {"node": capsule.get_instance_id(), "shape": capsule.shape.get_instance_id(), "shape_rid": capsule.shape.get_rid(), "radius": capsule.shape.radius, "height": capsule.shape.height, "local": capsule.transform}
	for rid: RID in _by_rid:
		var part: Dictionary = _by_rid[rid]
		var body: RigidBody3D = part.body.get_ref()
		var shape: CollisionShape3D
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				if shape != null: dispose(); return {"ok": false, "reason": "one_original_part_shape"}
				shape = child
		if shape == null or not shape.shape is CapsuleShape3D or body.get_shape_owners().size() != 1: dispose(); return {"ok": false, "reason": "original_capsule_part_required"}
		_part_properties[rid] = {"parent": weakref(body.get_parent()), "shape": weakref(shape), "shape_id": shape.shape.get_instance_id(), "shape_rid": shape.shape.get_rid(), "radius": shape.shape.radius, "height": shape.shape.height, "local": shape.transform, "mass": body.mass, "inertia": body.inertia, "com_mode": body.center_of_mass_mode}
	_v2_enabled = true
	configured.schema = V2_SCHEMA
	return configured

func _static_contract() -> Dictionary:
	return RagdollV2.blocking_contract()

func player_final_dead_block_contract() -> Dictionary:
	if not Thread.is_main_thread() or _disposed or _busy or not RagdollV2.blocking_backend_current(): return {}
	return _static_contract()

func player_final_dead_contact_ready() -> Dictionary:
	if not _v2_enabled: return super.player_final_dead_contact_ready()
	if not Thread.is_main_thread() or not RagdollV2.blocking_backend_current(): return {"ready": false}
	var result: Dictionary = super.player_final_dead_contact_ready()
	if result.get("ready", false): result.schema = V2_SCHEMA; result["blocking_bit"] = BLOCKING_BIT
	return result

func _reserve_attempt(r: Dictionary) -> String:
	var player: CharacterBody3D = _player.get_ref()
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion(): return "player_lifetime"
	if not Engine.is_in_physics_frame() or r.get("owner_epoch") != _epoch or r.get("physics_frame") != Engine.get_physics_frames(): return "frame_or_epoch"
	if r.get("actor_instance_id") != player.get_instance_id() or r.get("actor_rid") != player.get_rid() or r.get("actor_pose_epoch") != player._pose_epoch: return "actor_identity"
	var completed: Dictionary = player.completed_ground_move_receipt()
	if completed.get("frame") != Engine.get_physics_frames() or completed.get("pose_epoch") != player._pose_epoch or not completed.get("serial") is int or r.get("movement_serial") != completed.serial: return "completed_move_required"
	if completed.serial <= _last_attempted_move or completed.serial <= _last_consumed_move: return "movement_already_attempted"
	_last_attempted_move = completed.serial # One command per real move, even rejection.
	return ""

func _admit(r: Dictionary) -> Dictionary:
	if not _v2_enabled: return super._admit(r)
	if r.get("schema") not in [SCHEMA, V2_SCHEMA]: return _reject("schema")
	var reserved: String = _reserve_attempt(r)
	if not reserved.is_empty(): return _reject(reserved)
	if r.schema == SCHEMA: return super._admit(r) # Same v1 displacement/filter guards.
	return _admit_pressure(r)

func _capsule_current(player: CharacterBody3D, capsule: CollisionShape3D) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() or not is_instance_valid(capsule) or capsule.is_queued_for_deletion() or capsule.disabled or player.get_node_or_null("PlayerCapsule") != capsule: return false
	if player.get_world_3d().space != _registered_world: return false
	if not capsule.shape is CapsuleShape3D or capsule.get_instance_id() != _capsule_properties.node or capsule.shape.get_instance_id() != _capsule_properties.shape or capsule.shape.get_rid() != _capsule_properties.shape_rid: return false
	return capsule.shape.radius == _capsule_properties.radius and capsule.shape.height == _capsule_properties.height and capsule.transform == _capsule_properties.local

func _part_current(body: RigidBody3D, part: Dictionary, record: Dictionary, player: CharacterBody3D) -> bool:
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or body.get_rid() != part.rid or body.get_instance_id() != part.instance or not _part_properties.has(part.rid): return false
	var p: Dictionary = _part_properties[part.rid]
	var shape: CollisionShape3D = p.shape.get_ref()
	if body.get_parent() != p.parent.get_ref() or body.get_world_3d() != player.get_world_3d() or body.freeze or body.collision_layer != BLOCKING_LAYER or body.collision_mask != 257 or body not in record.host.owned_bodies(): return false
	if not is_instance_valid(shape) or shape.get_parent() != body or shape.disabled or not shape.shape is CapsuleShape3D or shape.shape.get_instance_id() != p.shape_id or shape.shape.get_rid() != p.shape_rid: return false
	return shape.transform == p.local and shape.shape.radius == p.radius and shape.shape.height == p.height and body.mass == p.mass and body.inertia == p.inertia and body.center_of_mass_mode == p.com_mode and body.get_shape_owners().size() == 1

func _pressure_life_current(record: Dictionary) -> bool:
	if not _live(record): return false
	var status: Dictionary = record.host.status()
	return status.get("blocking_enabled") == true and status.get("blocking_error") == "" and not str(status.get("blocking_death_key", "")).is_empty() and status.get("blocking_death_key") == status.get("death_key")

func _raw_slide(player: CharacterBody3D, capsule: CollisionShape3D, si: int, ci: int, completed: Dictionary) -> Dictionary:
	if si < 0 or si >= 16 or ci < 0 or ci >= 32 or si >= player.get_slide_collision_count() or player.get_slide_collision_count() > 16: return {}
	var count := 0
	for index: int in range(si + 1):
		var earlier: KinematicCollision3D = player.get_slide_collision(index)
		if earlier == null: return {}
		count += earlier.get_collision_count() if index < si else ci + 1
	if count > 32: return {}
	var hit: KinematicCollision3D = player.get_slide_collision(si)
	if hit == null or ci >= hit.get_collision_count() or hit.get_local_shape(ci) != capsule: return {}
	return {"frame": completed.frame, "serial": completed.serial, "pose_epoch": completed.pose_epoch, "slide_index": si, "contact_index": ci, "capsule_instance_id": capsule.get_instance_id(), "capsule_shape_id": capsule.shape.get_instance_id(), "collider_instance_id": hit.get_collider_id(ci), "collider_rid": hit.get_collider_rid(ci), "shape_index": hit.get_collider_shape_index(ci), "point": hit.get_position(ci), "normal": hit.get_normal(ci), "body_velocity": hit.get_collider_velocity(ci), "depth": hit.get_depth()}

static func pressure_math(move: Dictionary, contact: Dictionary) -> Dictionary:
	# Independent admission math mirrors reviewed Root prototype, with no minimum J.
	for key: String in ["start", "end", "pre_velocity", "input_direction"]:
		if not move.get(key) is Vector3 or not move[key].is_finite(): return {}
	for key: String in ["point", "normal", "body_velocity"]:
		if not contact.get(key) is Vector3 or not contact[key].is_finite(): return {}
	if move.get("controls_allowed") != true or move.get("grounded_before") != true or typeof(move.get("delta")) not in [TYPE_FLOAT, TYPE_INT]: return {}
	var dt: float = move.delta
	if not is_finite(dt) or dt <= 0.0 or dt > .1: return {}
	var motion: Vector3 = move.end - move.start
	var attempted := Vector3(move.pre_velocity.x, 0, move.pre_velocity.z)
	var direction := Vector3(move.input_direction.x, 0, move.input_direction.z)
	var normal := Vector3(contact.normal.x, 0, contact.normal.z)
	if absf(motion.y) > .15 or attempted.length() > 7.0 or Vector2(motion.x, motion.z).length() > attempted.length() * dt + .02: return {}
	if direction.length_squared() < .001 or direction.length_squared() > 1.001 or normal.length_squared() < .25: return {}
	normal = normal.normalized()
	if -direction.dot(normal) <= .05 or -attempted.dot(normal) <= .01: return {}
	var height: float = contact.point.y - minf(move.start.y, move.end.y)
	var closing: float = -(attempted - contact.body_velocity).dot(normal)
	if height < -.025 or height > .65 or closing <= .01 or closing > 7.0: return {}
	return {"normal": normal, "closing": closing}

func _admit_pressure(r: Dictionary) -> Dictionary:
	if not _v2_enabled or not RagdollV2.blocking_backend_current() or r.get("contact_kind") != "completed_native_slide_pressure": return _reject("v2_contract")
	var incarnation: int = _epoch
	var player: CharacterBody3D = _player.get_ref()
	var capsule: CollisionShape3D = _capsule.get_ref()
	if not _capsule_current(player, capsule): return _reject("capsule_changed")
	var negotiated: Dictionary = player.final_dead_block_contract_receipt()
	if negotiated.get("contract") != _static_contract() or negotiated.get("active") != true or negotiated.get("actor_instance_id") != player.get_instance_id() or negotiated.get("actor_rid") != player.get_rid() or negotiated.get("actor_layer") != 2 or negotiated.get("actor_mask") != (1 | BLOCKING_BIT) or player.collision_layer != 2 or player.collision_mask != (1 | BLOCKING_BIT): return _reject("negotiated_player_filters")
	if (player.platform_floor_layers & ~1) != 0 or player.platform_wall_layers != 0: return _reject("corpse_platform_carry_forbidden")
	if player._pose_authority != &"on_foot" or not player._jump.is_empty() or not player.is_on_floor() or not player._free_mouse_look or player._text_control_focused(): return _reject("actor_not_ground_walking")
	if is_instance_valid(player._weapon_host) and player._weapon_host.controls_blocked(): return _reject("actor_menu")
	if not r.get("event_id") is String or r.event_id.is_empty() or r.event_id.length() > 160 or _seen.has(r.event_id): return _reject("replay_or_event_id")
	if r.get("delivery") != "command_unapplied" or r.get("damage") != false or not _by_rid.has(r.get("collider_rid")): return _reject("target_or_delivery")
	var completed: Dictionary = player.completed_ground_move_receipt()
	var pressure: Dictionary = player.completed_ground_pressure_receipt()
	for key: String in ["frame", "serial", "pose_epoch", "start", "end"]:
		if not pressure.has(key) or pressure[key] != completed.get(key): return _reject("pressure_move_mismatch")
	if completed.get("start") != r.get("actor_start") or completed.get("end") != r.get("actor_end") or completed.get("end") != player.global_position: return _reject("completed_move_mismatch")
	if typeof(pressure.get("delta")) not in [TYPE_FLOAT, TYPE_INT] or absf(float(pressure.delta) - player.get_physics_process_delta_time()) > 1e-9: return _reject("physics_delta")
	if not pressure.get("capsule_transform") is Transform3D or not pressure.capsule_transform.is_finite() or pressure.get("capsule_shape_id") != capsule.shape.get_instance_id(): return _reject("captured_capsule")
	var start_capsule: Transform3D = capsule.global_transform
	start_capsule.origin -= player.global_position - completed.start
	if not pressure.capsule_transform.is_equal_approx(start_capsule): return _reject("capsule_frame_changed")
	if not r.get("slide_index") is int or not r.get("contact_index") is int: return _reject("contact_indices")
	var contact: Dictionary = _raw_slide(player, capsule, r.slide_index, r.contact_index, completed)
	if contact.is_empty() or player.completed_ground_slide_contact(r.slide_index, r.contact_index) != contact: return _reject("native_slide_required")
	for pair: Array in [["collider_rid", "collider_rid"], ["collider_instance_id", "collider_instance_id"], ["shape_index", "shape_index"], ["world_point", "point"], ["world_normal", "normal"], ["body_velocity", "body_velocity"]]:
		if r.get(pair[0]) != contact.get(pair[1]): return _reject("native_contact_mismatch:" + pair[0])
	if not is_finite(float(contact.depth)) or contact.depth < 0.0: return _reject("native_depth")
	var part: Dictionary = _by_rid[r.collider_rid]
	var record: Dictionary = _records[part.record]
	if not _pressure_life_current(record): return _reject("not_current_final_dead")
	var death_key: String = str(record.host.status().get("death_key", ""))
	var body: RigidBody3D = part.body.get_ref()
	if not _part_current(body, part, record, player): return _reject("part_changed")
	var shape_owner: int = body.get_shape_owners()[0]
	if contact.collider_instance_id != part.instance or body.shape_owner_get_shape_count(shape_owner) != 1 or body.shape_owner_get_shape_index(shape_owner, 0) != contact.shape_index or body.shape_owner_get_owner(shape_owner) != _part_properties[part.rid].shape.get_ref(): return _reject("owned_part_shape")
	var now: int = Time.get_ticks_msec()
	if not r.get("now_ms") is int or abs(now - r.now_ms) > 50: return _reject("stale_clock")
	if now - int(record.last_ms) < int(_options.cooldown_ms): return _reject("corpse_cooldown")
	var math: Dictionary = pressure_math(pressure, contact)
	if math.is_empty(): return _reject("not_inward_pressure")
	if typeof(r.get("relative_closing_speed")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(r.relative_closing_speed)) or absf(float(r.relative_closing_speed) - math.closing) > .00001: return _reject("closing_mismatch")
	var origin: Vector3 = player.global_position + Vector3.UP * .35
	var end: Vector3 = contact.point + (origin - contact.point).normalized() * .003
	if not player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 1, [player.get_rid()])).is_empty(): return _reject("world_occluded")
	var expected: Vector3 = -math.normal * minf(float(_options.max_impulse_ns), math.closing * float(_options.impulse_ns_per_mps))
	if not r.get("suggested_impulse_ns") is Vector3 or not r.suggested_impulse_ns.is_finite() or expected.distance_to(r.suggested_impulse_ns) > .005: return _reject("impulse_formula")
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state == null or not state.inverse_inertia_tensor.is_finite() or not is_finite(body.mass) or body.mass <= 0: return _reject("native_state")
	var native_transform: Transform3D = body.global_transform
	var native_linear: Vector3 = state.linear_velocity
	var native_angular: Vector3 = state.angular_velocity
	var native_inertia: Basis = state.inverse_inertia_tensor
	var offset: Vector3 = contact.point - body.global_position
	var lower := 0.0
	var upper := 1.0
	var fraction := 1.0
	var predicted: Dictionary = {}
	# Existing v1 point-energy limiter, same10-step bound and no velocity clamp.
	for attempt: int in 10:
		var trial: Vector3 = expected * fraction
		var dv: Vector3 = trial / body.mass
		var dw: Vector3 = state.inverse_inertia_tensor * (offset.cross(trial))
		var v: Vector3 = state.linear_velocity + dv
		var w: Vector3 = state.angular_velocity + dw
		var linear_energy: float = .5 * body.mass * (v.length_squared() - state.linear_velocity.length_squared())
		var angular_energy: float = state.angular_velocity.dot(offset.cross(trial)) + .5 * dw.dot(offset.cross(trial))
		if v.length() <= float(_options.max_linear_speed_mps) and w.length() <= float(_options.max_angular_speed_rps) and linear_energy + angular_energy <= float(_options.max_point_delta_energy_j):
			lower = fraction
			predicted = {"linear_speed": v.length(), "angular_speed": w.length(), "delta_energy_j": linear_energy + angular_energy}
			if fraction == 1.0: break
		else: upper = fraction
		fraction = (lower + upper) * .5
	var impulse: Vector3 = expected * lower
	if predicted.is_empty() or impulse.length() < .005: return _reject("point_energy_bound")
	if not _pressure_life_current(record) or not _identity_live(record, incarnation) or str(record.host.status().get("death_key", "")) != death_key: return _reject("life_changed_before_commit")
	if not _capsule_current(player, capsule) or not _part_current(body, part, record, player): return _reject("part_changed_before_commit")
	if player.completed_ground_move_receipt() != completed or player.completed_ground_pressure_receipt() != pressure or _raw_slide(player, capsule, r.slide_index, r.contact_index, completed) != contact or player.completed_ground_slide_contact(r.slide_index, r.contact_index) != contact: return _reject("move_changed_before_commit")
	if player.final_dead_block_contract_receipt() != negotiated: return _reject("negotiation_changed_before_commit")
	if player.global_position != completed.end or player.collision_layer != 2 or player.collision_mask != (1 | BLOCKING_BIT) or player._pose_authority != &"on_foot" or not player._jump.is_empty() or not player.is_on_floor() or not player._free_mouse_look or player._text_control_focused(): return _reject("player_changed_before_commit")
	if is_instance_valid(player._weapon_host) and player._weapon_host.controls_blocked(): return _reject("menu_changed_before_commit")
	if (player.platform_floor_layers & ~1) != 0 or player.platform_wall_layers != 0: return _reject("platform_changed_before_commit")
	var final_state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	if final_state == null or body.global_transform != native_transform or final_state.linear_velocity != native_linear or final_state.angular_velocity != native_angular or final_state.inverse_inertia_tensor != native_inertia: return _reject("native_state_changed_before_commit")
	_last_consumed_move = completed.serial
	_seen[r.event_id] = true
	if _seen.size() > 1024: _seen.erase(_seen.keys()[0])
	record.last_ms = now
	var was_sleeping: bool = body.sleeping
	body.apply_impulse(impulse, offset)
	stats.accepted += 1
	stats.applied_ns += impulse.length()
	return {"ok": true, "schema": V2_SCHEMA, "event_id": r.event_id, "owner_epoch": _epoch, "source_id": record.binding.source_id, "life_generation": record.binding.life_generation, "death_key": death_key, "applied_body_instance_id": part.instance, "applied_segment": str(body.name), "applied_impulse_ns": impulse, "native_point": contact.point, "native_depth": contact.depth, "was_sleeping": was_sleeping, "sleeping_after_call": body.sleeping, "predicted": predicted, "damage": false}

func dispose() -> void:
	_v2_enabled = false
	_part_properties.clear()
	_capsule_properties.clear()
	super.dispose()
