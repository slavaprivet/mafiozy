extends RefCounted
## Local owner companion: completed actual-contact HP receipt -> native motion.
## No HP/death edits or collider replacement. Explicit local medical-survivor
## release is committed by the existing HP owner AFTER guarded physical getup.
const Balance = preload("res://scripts/npc_visual/npc_impact_balance.gd")
const Recovery = preload("res://scripts/npc_visual/npc_ragdoll_recovery.gd")
const MAX_TOTAL_NS := 300.0
const STANDING_MASS_KG := 75.0
const RECOIL_DRAG := 7.0
var _owner: WeakRef
var _balance: RefCounted = Balance.new()
var _recovery: RefCounted
var _recoil := Vector3.ZERO
var _fall_speed := 0.0
var _last_physics_frame := -1
var _last_accepted := -1
var last_result: Dictionary = {}
var _disposed := false
var _survival_ticket: Dictionary = {}
var _survival_event_id := ""
var _prepare_result: Dictionary = {}
var _recovery_observation: Dictionary = {}
var _recovery_transitions: Array[Dictionary] = []
var _recovery_signature := ""
var _last_recovery_observation_frame := -100000
var _dsh_settle_enabled := false  # DSH_HEALTH: --city-health-settle, default OFF = source cadence
var _flinch_bones := PackedInt32Array()
var _flinch_elapsed := 1.0
var _flinch_axis := Vector3.RIGHT
var _flinch_side := 1.0
var _flinch_power := 0.0
const FLINCH_SECONDS := .30

func configure(owner: RefCounted) -> Dictionary:
	if _owner != null or not is_instance_valid(owner) or not owner._is_current(owner._binding):
		return {"ok":false,"reason":"current_owner"}
	if not owner._host._ragdolls.has(owner._token.source_id): return {"ok":false,"reason":"prepared_physical_required"}
	_owner = weakref(owner)
	# DSH_HEALTH: the settled-balance skip in step() is the only opt-in part of this
	# patch (it freezes the diagnostic quiet_seconds for an untouched resident).
	_dsh_settle_enabled = OS.get_cmdline_user_args().has("--city-health-settle")
	for name: String in ["spine_01","chest","head","upperarm_l","upperarm_r"]:
		_flinch_bones.append(owner._token.rig.find_bone(name))
	return {"ok":true,"scope":"local_nonfatal_physical_reaction","authority":"existing_local_hit_owner"}

func _live() -> RefCounted:
	var owner: RefCounted = _owner.get_ref() if _owner != null else null
	if _disposed or not is_instance_valid(owner) or not owner._is_current(owner._binding): return null
	return owner

func _release(binding: Dictionary, _phase: String) -> Dictionary:
	var owner := _live()
	if owner == null or not owner._host.physical_life_current(binding): return {}
	var row: Dictionary = owner._row
	var medical_local: bool = row.get("_medicalDowned",false) and _balance.medical_held and owner.has_method("commit_local_survival_release")
	return {"binding":binding.duplicate(),"known":true,"revision":_balance.revision,"reaction_generation":_balance.reaction_generation,"final_dead":bool(row.get("dead",false)) or _balance.final_dead,"release_allowed":float(row.get("hp",0.0)) > 0.0 and not row.get("dead",false) and (medical_local or not row.get("_forcedCrawl",false) and not row.get("_medicalDowned",false)) and _balance.allows_release()}

func prepare_before_publish(event_id: String) -> Dictionary:
	var owner := _live()
	if owner == null: return {"ok":false,"reason":"owner"}
	var receipt: Dictionary = owner._adapter.receipt(event_id)
	if receipt != owner.last_result or not receipt.get("applied",false) or not receipt.get("ok",false): return {"ok":false,"reason":"receipt"}
	if not owner._row.get("_medicalDowned",false) or owner._row.get("dead",false): return {"ok":true,"needed":false}
	var physical: RefCounted = owner._host._ragdolls.get(owner._token.source_id)
	if physical == null: return {"ok":false,"reason":"physical"}
	if physical.mode != "IDLE": return {"ok":true,"needed":false}
	var prepared: Dictionary = _prepare_recovery(owner,physical)
	_prepare_result = {"event_id":event_id,"hp_revision":receipt.get("revision",-1),"physical_mode_before_publish":physical.mode,"result":prepared.duplicate(true)}
	return prepared

func _prepare_recovery(owner: RefCounted, physical: RefCounted) -> Dictionary:
	# Freeze the CURRENT motion basis before activation. A configure at bootstrap
	# would become stale after the ordinary walking turn interpolation changed it.
	if _recovery != null: _recovery.dispose()
	_recovery = Recovery.new()
	var record: Dictionary = owner._host._records[owner._token.source_id]
	var result: Dictionary = _recovery.configure(physical,owner._token,record.motion,owner._weapons.scene,Callable(owner._host,"physical_life_current"),Callable(self,"_release"))
	# An unbound coordinator cannot ever advance. Preserve its concrete failure
	# instead of retaining an inert object and later reporting a benign impulse.
	if not result.get("ok",false):
		_recovery.dispose()
		_recovery = null
	return result

func accept(event_id: String, impulse_ns: Vector3, point: Vector3) -> Dictionary:
	var owner := _live()
	if owner == null or not impulse_ns.is_finite() or not point.is_finite() or impulse_ns.length() > MAX_TOTAL_NS or impulse_ns.length_squared() < .000001: return {"ok":false,"reason":"lifetime_or_vector"}
	var receipt: Dictionary = owner._adapter.receipt(event_id)
	if receipt.is_empty() or receipt != owner.last_result or not receipt.get("ok",false) or not receipt.get("applied",false) or receipt.get("binding") != owner._binding or not receipt.get("revision") is int or receipt.revision <= _last_accepted:
		return {"ok":false,"reason":"completed_current_hp_receipt"}
	if owner.last_contact.get("event_id") != event_id or owner.last_contact.get("source_id") != owner._token.source_id or owner.last_contact.get("life_generation") != owner._token.life_generation:
		return {"ok":false,"reason":"current_native_contact"}
	if not owner.last_contact.get("point") is Vector3 or point.distance_squared_to(owner.last_contact.point) > .00000001:
		return {"ok":false,"reason":"actual_contact_point"}
	var row: Dictionary = owner._row
	if row.get("_invulnerable",false): return {"ok":false,"reason":"invulnerable"}
	var hit: Dictionary = receipt.get("hit",{})
	var attack_type: String = str(hit.get("attack_type","punch")) if hit.get("contact_kind") == "melee" else "bullet"
	if attack_type not in ["bullet","punch","kick","heavy","dropkick"]: return {"ok":false,"reason":"attack_type"}
	var plan: Dictionary = _balance.accept(receipt.revision,impulse_ns.length(),bool(row.get("dead",false)),bool(row.get("_medicalDowned",false)),attack_type)
	if not plan.ok: return plan
	_last_accepted = receipt.revision
	_survival_event_id = event_id
	_survival_ticket.clear()
	_flinch_elapsed = 0.0
	_flinch_power = clampf(impulse_ns.length() / 95.0,.45,1.0)
	var local_direction: Vector3 = owner._token.rig.global_basis.inverse() * impulse_ns.normalized()
	var axis := Vector3.UP.cross(local_direction)
	_flinch_axis = axis.normalized() if axis.length_squared() > .000001 else Vector3.RIGHT
	_flinch_side = -1.0 if owner._token.rig.to_local(point).x < 0.0 else 1.0
	var physical: RefCounted = owner._host._ragdolls.get(owner._token.source_id)
	if physical == null: return {"ok":false,"reason":"physical_owner_missing"}
	# A new confirmed hit revokes an in-progress rise before any impulse. The
	# existing recovery restores the exact native pool or retains its safety guard.
	if physical.mode == "RECOVERING" and _recovery != null:
		_recovery.advance(1.0 / 60.0)
	var impulse: Vector3 = (impulse_ns * float(plan.get("burst_scale",1.0))).limit_length(MAX_TOTAL_NS)
	if not plan.get("recoverable",false):
		_recoil = Vector3.ZERO
		_fall_speed = 0.0
		# Terminal baseline owner already applies its initial impulse. Never double.
		if physical.mode == "ACTIVE" and owner.last_impulse.get("event_id") != event_id:
			last_result = _push_pool(physical,impulse,point,event_id)
		else: last_result = {"ok":true,"reason":"terminal_owner_retained"}
		return last_result
	if physical.mode == "ACTIVE":
		_balance.down = true
		if owner.last_impulse.get("event_id") == event_id:
			last_result = {"ok":true,"reason":"initial_terminal_impulse_already_applied"}
			return last_result
		last_result = _push_pool(physical,impulse,point,event_id)
		return last_result
	if physical.mode != "IDLE": return {"ok":false,"reason":"physical_guard_held"}
	if plan.knockdown:
		var prepared := _prepare_recovery(owner,physical)
		_prepare_result = {"event_id":event_id,"hp_revision":receipt.revision,"physical_mode_before_publish":physical.mode,"result":prepared.duplicate(true)}
		if not prepared.get("ok",false):
			_balance.down = false
			last_result = {"ok":false,"reason":"recovery_preparation","detail":prepared}
			return last_result
		var body: CharacterBody3D = owner._token.body
		owner._events[event_id] = {"id":event_id,"kind":"source_impact_knockdown","confirmed":true,"nonfatal_confirmed":true,"source_id":owner._token.source_id,"life_generation":owner._token.life_generation,"local_preview_hp_revision":receipt.revision,"reaction_generation":_balance.reaction_generation,"already_solved_by_godot":false,"apply_again":true,"linear_velocity":body.velocity + _recoil,"angular_velocity":Vector3.ZERO,"reference_point":point,"impulse_ns":impulse}
		last_result = owner._host.activate_physical(owner._token,event_id)
		# Activation consumes this bounded synchronous event; owner retains the
		# immutable HP receipt. No ever-growing reaction event registry is created.
		owner._events.erase(event_id)
		if last_result.get("ok",false):
			_recoil = Vector3.ZERO
			_fall_speed = 0.0
			last_result["reason"] = "nonfatal_native_knockdown"
		else:
			_balance.down = false
		return last_result
	_recoil = (_recoil + impulse / STANDING_MASS_KG).limit_length(4.0)
	_reset_navigation(owner)
	last_result = {"ok":true,"reason":"standing_native_recoil","velocity_mps":_recoil,"balance":_balance.load}
	return last_result

func _reset_navigation(owner: RefCounted) -> void:
	var record: Dictionary = owner._host._records[owner._token.source_id]
	if record.request >= 0:
		owner._host._navigation.cancel(record.request)
		record.request = -1
	record.status = "IDLE"
	if owner._host._walk_preview.has(owner._token.source_id):
		owner._host._walk_preview[owner._token.source_id].awaiting = false

func _push_pool(physical: RefCounted, impulse: Vector3, point: Vector3, event_id: String) -> Dictionary:
	var parts: Array[RigidBody3D] = physical.owned_bodies()
	if parts.size() != 16 or physical.mode != "ACTIVE" or not physical._is_current(): return {"ok":false,"reason":"current_pool"}
	var total := 0.0
	for part: RigidBody3D in parts:
		if not is_instance_valid(part) or part.freeze or not is_finite(part.mass) or part.mass <= 0.0: return {"ok":false,"reason":"live_parts"}
		total += part.mass
	# Bounded uniform momentum avoids imparting the entire whole-body impulse to
	# one light forearm. A small point impulse provides contact-side rotation.
	var point_impulse := impulse.normalized() * minf(2.5,impulse.length() * .10)
	var uniform := impulse - point_impulse
	for part: RigidBody3D in parts: part.apply_central_impulse(uniform * (part.mass / total))
	var point_result: Dictionary = physical._body.apply_impulse(point,point_impulse,event_id + ":reaction")
	return {"ok":true,"reason":"existing_pool_impulse","uniform_ns":uniform,"point_result":point_result,"point_ns":point_impulse if point_result.get("ok",false) else Vector3.ZERO}

func should_pause() -> bool:
	return _recoil.length_squared() > .0004 or _fall_speed > 0.0 or _balance.down

func _observe_recovery(owner: RefCounted,physical: RefCounted,state: Dictionary) -> void:
	# Observe cached physical output only: never step an extra writer or request
	# a fresh engine query for diagnostics. Twelve transitions, one latest sample.
	var frame: int = Engine.get_physics_frames()
	var signature: String = _survival_event_id + ":" + str(physical.mode) + ":" + str(state.get("mode","MISSING")) + ":" + str(state.get("reason",""))
	if signature == _recovery_signature and frame-_last_recovery_observation_frame < Engine.physics_ticks_per_second:return
	_last_recovery_observation_frame = frame
	if signature != _recovery_signature:
		_recovery_signature = signature
		if _recovery_transitions.size() >= 12: _recovery_transitions.pop_front()
		_recovery_transitions.append({"physics_frame":Engine.get_physics_frames(),"event_id":_survival_event_id,"physical_mode":physical.mode,"recovery_mode":state.get("mode","MISSING"),"reason":state.get("reason","")})
	var cached: Dictionary = physical._last
	var motion: Node3D = owner._host._records[owner._token.source_id].motion
	_recovery_observation = {"preparation":_prepare_result,"coordinator":state,"physical_mode":physical.mode,"quiet_seconds":_balance.quiet,"balance_down":_balance.down,"medical_held":_balance.medical_held,"allows_release":_balance.allows_release(),"medical_owner":bool(owner._row.get("_medicalDowned",false)),"owner_hp_revision":owner._adapter._revision,"accepted_hp_revision":_last_accepted,"hp":owner._row.hp,"final_dead":bool(owner._row.get("dead",false)),"motion_binding_matches":_recovery != null and motion.transform == _recovery._base_motion,"capsule_layer":owner._token.body.collision_layer,"capsule_mask":owner._token.body.collision_mask,"cached_physical":{},"transitions":_recovery_transitions}
	for key: String in ["settled","max_linear_speed","max_angular_speed","max_joint_anchor_error_m","contact_count","sleeping_count","support_contact_count","core_support_contact_count","side_contact_count","ceiling_contact_count","fastest_linear_bone","fastest_angular_bone"]:
		if cached.has(key):_recovery_observation.cached_physical[key]=cached[key]
	last_result["recovery_observation"] = _recovery_observation

# DSH_HEALTH: the one caller that owns this reaction (the hit owner's step()) has
# already passed the identical current-owner guard in this same physics frame, so
# re-running it here cost a second physical_life_current() host validation per
# resident per physics tick. Passing that proven owner back is exact: the two
# guards are adjacent statements with nothing between them, and the weakref
# identity is re-checked before the shortcut is taken. Null = the original path.
func step(prevalidated_owner: RefCounted = null) -> void:
	var owner: RefCounted = null
	if prevalidated_owner != null and not _disposed and is_instance_valid(prevalidated_owner) and _owner != null and _owner.get_ref() == prevalidated_owner:
		owner = prevalidated_owner
	else:
		owner = _live()
	if owner == null: return
	var frame := Engine.get_physics_frames()
	if frame == _last_physics_frame: return
	_last_physics_frame = frame
	# Call from the existing physics driver. Process-frame polls cannot accelerate
	# this timer; a skipped tick conservatively delays recovery instead of jumping.
	var delta := minf(.05,1.0 / float(Engine.physics_ticks_per_second))
	# DSH_HEALTH: a settled balance (see npc_impact_balance.settled()) can only push
	# quiet past a threshold it has already crossed and load down from the floor it
	# already sits on, so re-integrating it cannot change any value that is read.
	# A live recovery coordinator or a down owner always keeps the exact cadence.
	if not _dsh_settle_enabled or _recovery != null or not _balance.settled(): _balance.step(delta)
	# DSH_HEALTH: the flinch timer is clamped at 1.0, so integrating it again once it
	# is already there is an exact no-op.
	if _flinch_elapsed < 1.0: _flinch_elapsed = minf(1.0,_flinch_elapsed + delta)
	var physical: RefCounted = owner._host._ragdolls.get(owner._token.source_id)
	if physical == null: return
	if _recovery != null and physical.mode in ["ACTIVE","RECOVERING","RECOVERY_HOLD"]:
		var state: Dictionary = _recovery.advance(delta)
		_observe_recovery(owner,physical,state)
		if state.get("walking_ready",false):
			if owner._row.get("_medicalDowned",false):
				_survival_ticket = {"policy":"local_survivor_getup_v1","event_id":_survival_event_id,"source_id":owner._token.source_id,"life_generation":owner._token.life_generation,"hp_revision":_last_accepted,"reaction_generation":_balance.reaction_generation,"physics_frame":Engine.get_physics_frames(),"original_body_id":owner._token.body.get_instance_id(),"guarded_recovery_completed":true}
				var released: Dictionary = owner.commit_local_survival_release(_survival_event_id,_last_accepted,_survival_ticket.duplicate(true))
				_survival_ticket.clear()
				if not released.get("ok",false) or owner._row.get("_medicalDowned",false):
					last_result = {"ok":false,"reason":"local_medical_owner_release_failed","detail":released}
					# Do not expose an unapproved standing medical actor. Reactivate
					# its real articulated owner; never fake a source medical release.
					if owner._row.get("dead",false) or not owner._row.get("_medicalDowned",false) or float(owner._row.get("hp",0.0)) <= 0.0:
						return # A newer death/release belongs to that actual source owner.
					owner._events[_survival_event_id] = {"id":_survival_event_id,"kind":"source_medical_down","confirmed":true,"medical_downed":true,"source_id":owner._token.source_id,"life_generation":owner._token.life_generation,"local_preview_hp_revision":_last_accepted,"already_solved_by_godot":true,"apply_again":false,"linear_velocity":Vector3.ZERO,"angular_velocity":Vector3.ZERO,"reference_point":owner._token.body.global_position,"impulse_ns":Vector3.ZERO}
					last_result["medical_reactivation"] = owner._host.activate_physical(owner._token,_survival_event_id)
					owner._events.erase(_survival_event_id)
					return
			_balance.recovered()
			_recovery.dispose()
			_recovery = null
			_reset_navigation(owner)
			var body: CharacterBody3D = owner._token.body
			owner._row.r = (body.global_position.z + 45.1) / 4.1
			owner._row.c = (body.global_position.x + 395.65) / 4.1
		return
	if _balance.down and physical.mode != "IDLE":
		_observe_recovery(owner,physical,{"mode":"MISSING","reason":"recovery_not_prepared"})
	if physical.mode != "IDLE" or owner._row.get("dead",false) or owner._row.get("_medicalDowned",false): return
	if _recoil.length_squared() <= .0004 and _fall_speed <= 0.0:
		_recoil = Vector3.ZERO
		return
	var body: CharacterBody3D = owner._token.body
	if body.collision_layer != 1 or body.collision_mask != 1: return
	# Sole reaction motion pass in the host's existing serial physics driver.
	# Navigation is cancelled/paused while this request owns movement. Gravity
	# remains native if recoil crosses an edge; the capsule cannot hang in air.
	_fall_speed += 9.8 * delta
	body.velocity = _recoil + Vector3.DOWN * _fall_speed
	body.move_and_slide()
	_recoil = Vector3(body.velocity.x,0.0,body.velocity.z) * exp(-RECOIL_DRAG * delta)
	_fall_speed = 0.0 if body.is_on_floor() else maxf(0.0,-body.velocity.y)
	owner._row.r = (body.global_position.z + 45.1) / 4.1
	owner._row.c = (body.global_position.x + 395.65) / 4.1

## DSH_HEALTH2: true only when step() has no work left for this reaction: no
## recovery coordinator, no balance-down, no recoil, no fall and a finished
## flinch. Every operand is a local field: no owner, host, node or engine access.
func idle_reaction() -> bool:
	return not _disposed and _recovery == null and not _balance.down and _recoil == Vector3.ZERO and _fall_speed <= 0.0 and _flinch_elapsed >= 1.0

## DSH_HEALTH2: the exact work step() does for an idle reaction (see
## idle_reaction()): the physics-frame guard, the same delta, the same
## `_balance.step()` cadence and the same clamped flinch integrator, and nothing
## else. The hit owner may therefore skip the rest of its own body when this
## returns true. It returns false - and leaves _last_physics_frame untouched -
## for any other owner, so the unmodified step() still runs for those.
func step_idle(prevalidated_owner: RefCounted, frame: int) -> bool:
	if not idle_reaction(): return false
	if prevalidated_owner == null or not is_instance_valid(prevalidated_owner) or _owner == null or _owner.get_ref() != prevalidated_owner: return false
	if frame == _last_physics_frame: return true
	_last_physics_frame = frame
	var delta := minf(.05,1.0 / float(Engine.physics_ticks_per_second))
	# DSH_HEALTH: same expression as step(); a settled balance can only push
	# quiet past a threshold it has already crossed and load down from its floor.
	if not _dsh_settle_enabled or _recovery != null or not _balance.settled(): _balance.step(delta)
	# DSH_HEALTH: same clamped flinch integrator as step().
	if _flinch_elapsed < 1.0: _flinch_elapsed = minf(1.0,_flinch_elapsed + delta)
	return true

func validate_survival_release(proof: Dictionary, event_id: String, expected_revision: int) -> bool:
	var owner := _live()
	if owner == null or _survival_ticket.is_empty() or proof != _survival_ticket or event_id != _survival_event_id or expected_revision != _last_accepted: return false
	if _recovery == null or not _recovery.status().get("walking_ready",false) or not _balance.allows_release(): return false
	var physical: RefCounted = owner._host._ragdolls.get(owner._token.source_id)
	return physical != null and physical.mode == "IDLE" and not physical.status().final_dead and owner._token.body.collision_layer == 1 and owner._token.body.collision_mask == 1 and proof.physics_frame == Engine.get_physics_frames() and owner._row.get("_medicalDowned",false) and float(owner._row.get("hp",0.0)) > 0.0 and not owner._row.get("dead",false)

func hit_pose_active() -> bool:
	# DSH_HEALTH: preview_resident_host calls this for every resident every physics
	# tick, and the two tests below are pure local fields, so rejecting an
	# unflinch/expired-flinch resident here is identical and skips the expensive
	# owner-liveness guard (a third physical_life_current() per owner per tick).
	if _flinch_elapsed >= FLINCH_SECONDS or _flinch_power <= 0.0: return false
	var owner := _live()
	if owner == null or owner._row.get("dead",false): return false
	var physical: RefCounted = owner._host._ragdolls.get(owner._token.source_id)
	return physical != null and physical.mode == "IDLE"

func compose_hit_pose(selected: Dictionary) -> Dictionary:
	# Pure pose composition. The host remains the only skeleton/motion writer.
	if not selected.get("valid",false) or not selected.get("poses") is Array or not hit_pose_active(): return selected
	var poses: Array[Transform3D] = selected.poses
	if poses.size() != 28 or _flinch_bones.size() != 5: return selected
	var weight := sin(PI * clampf(_flinch_elapsed / FLINCH_SECONDS,0.0,1.0)) * _flinch_power
	for slot: int in _flinch_bones.size():
		var bone: int = _flinch_bones[slot]
		if bone < 0 or bone >= poses.size(): continue
		var angle := .05 if slot == 0 else .14 if slot == 1 else .07
		var axis := _flinch_axis
		if slot >= 3:
			var same_side: bool = (slot == 3 and _flinch_side < 0.0) or (slot == 4 and _flinch_side > 0.0)
			angle = .10 if same_side else .025
			axis = Vector3.RIGHT
		var old: Transform3D = poses[bone]
		var rotation := Quaternion(axis,angle * weight) * old.basis.get_rotation_quaternion()
		poses[bone] = Transform3D(Basis(rotation.normalized()) * Basis.from_scale(old.basis.get_scale()),old.origin)
	return selected

func dispose() -> void:
	if _recovery != null: _recovery.dispose(); _recovery = null
	_recoil = Vector3.ZERO
	_fall_speed = 0.0
	_disposed = true
	_owner = null
