extends RefCounted
## ISOLATED APPLY-CANDIDATE, NOT ENGINE-VALIDATED. Requires Artist24 v2.
## No transforms, forces, masks, life, or HP writes. Existing v1 stays unchanged.
const SCHEMA := "npc_final_dead_contact/v2"
const BLOCK_BIT := 1024 # Exact negotiated root/owner reservation; 512 is rubble.
const MAX_SLIDES := 16
const MAX_CONTACTS := 32
var _ready_hook: Callable
var _admit_hook: Callable
var _last_attempt_ms := -1000000
var _serial := 0
var _last_consumed_move := -1
var _contract: Dictionary = {}
var attempts := 0
var accepted := 0
var last_result: Dictionary = {}

func configure(ready_hook: Callable, admit_hook: Callable, contract: Dictionary) -> bool:
	if not contract.get("ok", false) or contract.get("schema") != SCHEMA or contract.get("blocking_bit") != BLOCK_BIT or contract.get("part_layer") != 1280 or contract.get("part_mask") != 257 or contract.get("movement_mask") != 1025 or contract.get("world_support_mask") != 1: return false
	_contract = contract.duplicate(true)
	_ready_hook = ready_hook
	_admit_hook = admit_hook
	return _ready_hook.is_valid() and _admit_hook.is_valid()

func begin(player: CharacterBody3D) -> Dictionary:
	if not _ready_hook.is_valid() or not _admit_hook.is_valid(): return {}
	if not player.has_method("completed_ground_pressure_receipt") or not player.has_method("completed_ground_slide_contact"): return {}
	if not _walking(player) or player.collision_layer != 2 or player.collision_mask != int(_contract.movement_mask): return {}
	return {"position": player.global_position, "frame": Engine.get_physics_frames(), "pose_epoch": player._pose_epoch}

func _walking(player: CharacterBody3D) -> bool:
	return player._pose_authority == &"on_foot" and player._jump.is_empty() and player.is_on_floor() and player._free_mouse_look and not player._text_control_focused() and not (is_instance_valid(player._weapon_host) and player._weapon_host.controls_blocked())

## Pure preliminary math; NOT an admission proof. The NPC port must independently
## read the player's same-frame public receipt and native slide contact again.
static func pressure_candidate(move: Dictionary, contact: Dictionary, maximum_speed: float = 7.0) -> Dictionary:
	for key: String in ["start", "end", "pre_velocity", "input_direction"]:
		if not move.get(key) is Vector3 or not move[key].is_finite(): return {}
	for key: String in ["point", "normal", "body_velocity"]:
		if not contact.get(key) is Vector3 or not contact[key].is_finite(): return {}
	if not move.get("controls_allowed", false) or not move.get("grounded_before", false): return {}
	if typeof(move.get("delta")) not in [TYPE_FLOAT, TYPE_INT]: return {}
	var dt: float = move.delta
	if not is_finite(dt) or dt <= 0.0 or dt > 0.1 or not is_finite(maximum_speed) or maximum_speed <= 0.0: return {}
	var motion: Vector3 = move.end - move.start
	var attempted := Vector3(move.pre_velocity.x, 0.0, move.pre_velocity.z)
	var direction := Vector3(move.input_direction.x, 0.0, move.input_direction.z)
	var normal := Vector3(contact.normal.x, 0.0, contact.normal.z)
	if absf(motion.y) > 0.15 or attempted.length() > maximum_speed: return {}
	if Vector2(motion.x, motion.z).length() > attempted.length() * dt + 0.02: return {}
	if direction.length_squared() < 0.001 or direction.length_squared() > 1.001 or normal.length_squared() < 0.25: return {}
	normal = normal.normalized()
	# Held direction must press into this contact. Residual deceleration alone
	# after key-up, tangential motion, and a moving corpse approaching us fail.
	if -direction.dot(normal) <= 0.05 or -attempted.dot(normal) <= 0.01: return {}
	var height: float = contact.point.y - minf(move.start.y, move.end.y)
	if height < -0.025 or height > 0.65: return {}
	var closing: float = -(attempted - contact.body_velocity).dot(normal)
	if closing <= 0.01 or closing > maximum_speed: return {}
	# Unlike v1, zero travel is valid ONLY when a current native slide supplies
	# the proof. No fake positive displacement or minimum-speed floor is added.
	return {"normal": normal, "closing": closing, "height": height, "actual_velocity": Vector3(motion.x, 0.0, motion.z) / dt}

func finish(player: CharacterBody3D, start: Dictionary, delta: float) -> void:
	if start.is_empty() or not Engine.is_in_physics_frame() or not _walking(player): return
	if start.frame != Engine.get_physics_frames() or start.pose_epoch != player._pose_epoch: return
	if not _ready_hook.is_valid() or not _admit_hook.is_valid() or not is_finite(delta) or delta <= 0.0 or delta > 0.1: return
	var move: Dictionary = player.completed_ground_pressure_receipt()
	if move.get("frame") != start.frame or move.get("pose_epoch") != start.pose_epoch or move.get("start") != start.position or move.get("end") != player.global_position: return
	if move.get("schema") != "player_completed_ground_pressure/v2" or not move.get("serial") is int or move.serial < 1 or move.serial <= _last_consumed_move or move.get("delta") != delta: return
	var now := Time.get_ticks_msec()
	if now - _last_attempt_ms < 50: return
	var count := player.get_slide_collision_count()
	if count <= 0 or count > MAX_SLIDES: return
	var examined := 0
	for slide_index: int in range(count):
		var slide := player.get_slide_collision(slide_index)
		if slide == null: continue
		for contact_index: int in range(slide.get_collision_count()):
			examined += 1
			if examined > MAX_CONTACTS: return # Bounded, no fall-through force.
			var body: Variant = slide.get_collider(contact_index)
			if not body is RigidBody3D or not is_instance_valid(body) or body.freeze: continue
			if body.collision_layer != int(_contract.part_layer) or body.collision_mask != int(_contract.part_mask): continue
			var contact: Dictionary = player.completed_ground_slide_contact(slide_index, contact_index)
			if contact.is_empty(): continue
			var preliminary := pressure_candidate(move, contact)
			if preliminary.is_empty(): continue
			var contract: Variant = _ready_hook.call()
			if not contract is Dictionary or not contract.get("ready", false) or contract.get("schema") != SCHEMA or contract.get("blocking_bit") != BLOCK_BIT: return
			if not contract.get("epoch") is int or contract.epoch < 1: return
			for key: String in ["max_impulse_ns", "impulse_ns_per_mps", "cooldown_ms", "max_relative_speed_mps", "max_contact_height_m"]:
				if typeof(contract.get(key)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(contract[key])): return
			if contract.max_impulse_ns <= 0.0 or contract.max_impulse_ns > 3.0 or contract.impulse_ns_per_mps <= 0.0 or contract.impulse_ns_per_mps > 1.0: return
			if contract.cooldown_ms < 80 or contract.cooldown_ms > 1000 or now - _last_attempt_ms < contract.cooldown_ms: return
			if contract.max_relative_speed_mps <= 0.0 or contract.max_relative_speed_mps > 7.0: return
			var pressure := pressure_candidate(move, contact, float(contract.max_relative_speed_mps))
			if pressure.is_empty(): continue
			if contract.max_contact_height_m <= 0.0 or contract.max_contact_height_m > 0.65 or pressure.height > contract.max_contact_height_m: return
			# Existing layer1 occlusion guard retained. Owner repeats it itself.
			var origin := player.global_position + Vector3.UP * 0.35
			var end: Vector3 = contact.point + (origin - contact.point).normalized() * 0.003
			if not player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 1, [player.get_rid()])).is_empty(): return
			# Public readiness callbacks cannot smuggle a changed player/native move
			# into the command. The owner must repeat these guards before force.
			if player.completed_ground_pressure_receipt() != move or player.completed_ground_slide_contact(slide_index, contact_index) != contact: return
			if not is_instance_valid(body) or body.is_queued_for_deletion() or body.freeze or body.collision_layer != int(_contract.part_layer) or body.collision_mask != int(_contract.part_mask): return
			_last_consumed_move = move.serial
			_last_attempt_ms = now
			_serial += 1
			attempts += 1
			var request := {"schema": SCHEMA, "contact_kind": "completed_native_slide_pressure", "owner_epoch": contract.epoch, "event_id": "player_pressure:%d:%d:%d" % [player.get_instance_id(), start.pose_epoch, _serial], "physics_frame": start.frame, "movement_serial": move.serial, "now_ms": now, "actor_instance_id": player.get_instance_id(), "actor_rid": player.get_rid(), "actor_pose_epoch": start.pose_epoch, "actor_start": move.start, "actor_end": move.end, "slide_index": slide_index, "contact_index": contact_index, "collider_instance_id": contact.collider_instance_id, "collider_rid": contact.collider_rid, "shape_index": contact.shape_index, "world_point": contact.point, "world_normal": contact.normal, "body_velocity": contact.body_velocity, "relative_closing_speed": pressure.closing, "suggested_impulse_ns": -pressure.normal * minf(float(contract.max_impulse_ns), pressure.closing * float(contract.impulse_ns_per_mps)), "delivery": "command_unapplied", "damage": false}
			var result: Variant = _admit_hook.call(request)
			last_result = result.duplicate(true) if result is Dictionary else {"ok": false, "reason": "invalid_owner_result"}
			if last_result.get("ok", false): accepted += 1
			return # At most one owner command per move, including rejection.
