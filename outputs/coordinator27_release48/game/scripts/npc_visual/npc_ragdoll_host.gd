extends RefCounted
## One externally admitted NPC life. No HP, damage-to-impulse, death decision,
## automatic get-up, actor movement, or vehicle collision exceptions.
## Root must suspend the walking/animation writer for the complete ACTIVE lease.
const Body = preload("res://scripts/npc_visual/npc_body.gd")
const Eyes = preload("npc_death_eyes.gd")
var _eyes:RefCounted
const IDENTITY_FIELDS := ["session_id", "source_id", "render_id", "bridge_id", "descriptor_sha256", "placement_mode", "life_generation", "rig_epoch", "body_instance_id", "body_rid", "rig_instance_id"]
var mode := "UNBOUND"
var _body: RefCounted
var _actor: WeakRef
var _rig: WeakRef
var _binding: Dictionary = {}
var _current := Callable()
var _events := Callable()
var _names: Array[String] = []
var _parents: Array[int] = []
var _local_frames: Array[Transform3D] = []
var _busy := false
var _final_dead := false
var _death_key := ""
var _event_id := ""
var _fault := ""
var _last: Dictionary = {}
var _recovery_guard: WeakRef
var _walking_layer := 0
var _walking_mask := 0

static func _text(v: Variant) -> bool:
	return v is String and not v.is_empty() and v.length() <= 256

static func _identity(v: Variant) -> bool:
	return v is int and v >= 0 or _text(v)

static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b

static func _yes(v: Variant) -> bool:
	return v is bool and v

func _result(ok: bool, error := "") -> Dictionary:
	return {"ok":ok, "error":error, "mode":mode, "final_dead":_final_dead, "death_key":_death_key, "damage_authority":false, "event_id":_event_id}

func configure(token: Dictionary, parent: Node3D, current_binding: Callable, confirmed_events: Callable, options: Dictionary = {}) -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode != "UNBOUND": return _result(false,"lifetime")
	if not _yes(token.get("ok")) or not token.get("source_authority") is bool or token.source_authority: return _result(false,"target_token")
	for key: String in IDENTITY_FIELDS:
		if key == "body_rid":
			if not token.get(key) is RID or not token[key].is_valid(): return _result(false,"identity:"+key)
		elif not _identity(token.get(key)): return _result(false,"identity:"+key)
	if not _text(token.session_id) or not _text(token.render_id) or not token.life_generation is int or token.life_generation < 1: return _result(false,"binding")
	if not _text(token.bridge_id) or token.bridge_id != token.render_id or not token.descriptor_sha256 is String or token.descriptor_sha256.length() != 64 or not token.descriptor_sha256.is_valid_hex_number(false): return _result(false,"visual_binding")
	var actor: Variant = token.get("body")
	var rig: Variant = token.get("rig")
	if not actor is CharacterBody3D or not is_instance_valid(actor) or not rig is Skeleton3D or not is_instance_valid(rig): return _result(false,"nodes")
	if not actor.is_inside_tree() or not rig.is_inside_tree() or not actor.is_ancestor_of(rig) or actor.get_instance_id() != token.body_instance_id or actor.get_rid() != token.body_rid or rig.get_instance_id() != token.rig_instance_id or rig.get_bone_count() != 28: return _result(false,"rig_binding")
	if not current_binding.is_valid() or not confirmed_events.is_valid(): return _result(false,"authority_missing")
	_actor = weakref(actor); _rig = weakref(rig)
	for key: String in IDENTITY_FIELDS: _binding[key] = token[key]
	_current = current_binding; _events = confirmed_events
	_busy = true
	var valid := _is_current()
	_busy = false
	if not valid or mode != "UNBOUND": return _result(false,"current_binding")
	var mass: Variant = options.get("total_mass_kg",75.0)
	var layer: Variant = options.get("collision_layer",256)
	var mask: Variant = options.get("collision_mask",257)
	if not (mass is int or mass is float) or not is_finite(float(mass)) or mass < 20 or mass > 200 or not layer is int or layer <= 0 or not mask is int or mask <= 0: return _result(false,"physical_options")
	_body = Body.new()
	var configured: Dictionary = _body.configure(rig,parent,{"total_mass_kg":float(mass),"collision_layer":layer,"collision_mask":mask,"exceptions":[actor]})
	if not configured.get("ok",false):
		_body.dispose(); _body = null
		return _result(false,"body:"+str(configured.get("error")))
	for i in 28:
		_names.append(str(rig.get_bone_name(i))); _parents.append(rig.get_bone_parent(i))
	_local_frames.resize(28)
	mode = "IDLE"
	_eyes=Eyes.new()
	_eyes.configure(self,token,options.get("death_eyes_asset_dir",Eyes.ASSET_DIR))
	return _result(true)

func _nodes_current() -> bool:
	var actor: CharacterBody3D = _actor.get_ref() if _actor != null else null
	var rig: Skeleton3D = _rig.get_ref() if _rig != null else null
	if not is_instance_valid(actor) or not is_instance_valid(rig) or not actor.is_inside_tree() or not rig.is_inside_tree() or actor.is_queued_for_deletion() or rig.is_queued_for_deletion() or not actor.is_ancestor_of(rig): return false
	if actor.get_instance_id() != _binding.body_instance_id or actor.get_rid() != _binding.body_rid or rig.get_instance_id() != _binding.rig_instance_id or rig.get_bone_count() != 28: return false
	for i in _names.size():
		if str(rig.get_bone_name(i)) != _names[i] or rig.get_bone_parent(i) != _parents[i]: return false
	return true

func _is_current() -> bool:
	if not _nodes_current() or not _current.is_valid(): return false
	var accepted: Variant = _current.call(_binding.duplicate())
	return accepted is bool and accepted and mode != "RETIRED" and _nodes_current()

func _receipt(event_id: String) -> Dictionary:
	if not _text(event_id) or not _events.is_valid(): return {}
	var raw: Variant = _events.call({"mode":"event", "binding":_binding.duplicate(), "event_id":event_id})
	if not raw is Dictionary or not _is_current() or mode == "RETIRED": return {}
	if not _yes(raw.get("known")) or not _yes(raw.get("completed")) or not _yes(raw.get("accepted")) or not raw.get("binding") is Dictionary or not raw.get("event") is Dictionary: return {}
	for key: String in IDENTITY_FIELDS:
		if not _same(raw.binding.get(key),_binding[key]): return {}
	var event: Dictionary = raw.event.duplicate(true)
	if event.get("id") != event_id or not _yes(event.get("confirmed")) or event.get("kind") not in ["final_death","vehicle_knockdown","source_medical_down"]: return {}
	if not event.get("already_solved_by_godot") is bool or not event.get("apply_again") is bool or event.already_solved_by_godot == event.apply_again: return {}
	if event.kind == "final_death":
		if not _text(event.get("death_key")): return {}
	elif event.kind == "source_medical_down":
		if event.get("source_id") != _binding.source_id or event.get("life_generation") != _binding.life_generation or not _yes(event.get("medical_downed")) or not event.get("local_preview_hp_revision") is int or event.local_preview_hp_revision < 1: return {}
	else:
		if not _yes(event.get("contact_verified")) or not _identity(event.get("vehicle_id")): return {}
	for key: String in ["linear_velocity", "angular_velocity", "reference_point", "impulse_ns"]:
		if not event.get(key) is Vector3 or not event[key].is_finite(): return {}
	return event

## Call outside physics query flush, after the outgoing animated pose is applied.
## The canonical provider owns freshness, mass/speed/contact and final-death proof.
func activate(event_id: String) -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode != "IDLE": return _result(false,"lifetime_or_busy")
	_busy = true
	if not _is_current():
		_busy = false; retire("stale_binding"); return _result(false,"stale_binding")
	var event := _receipt(event_id)
	if event.is_empty() or mode != "IDLE":
		_busy = false; return _result(false,"event_not_confirmed")
	var frames: Dictionary = _body.capture_world_frames()
	var actor: CharacterBody3D = _actor.get_ref()
	var saved_layer := actor.collision_layer
	var saved_mask := actor.collision_mask
	_walking_layer = saved_layer; _walking_mask = saved_mask
	# One synchronous transaction outside query flush: no physics step can see
	# both the standing capsule and the articulated pool enabled. Rejection
	# restores exact filters; no source/gait state is committed by this module.
	actor.collision_layer = 0; actor.collision_mask = 0
	var pending_impulse: Vector3 = Vector3.ZERO if event.already_solved_by_godot else event.impulse_ns
	var started: Dictionary = _body.start(frames,event.linear_velocity,pending_impulse,event.angular_velocity,event.reference_point)
	if not started.get("ok",false):
		actor.collision_layer = saved_layer; actor.collision_mask = saved_mask
		_busy = false; return _result(false,"start:"+str(started.get("error")))
	var initial: Dictionary = _body.snapshot()
	if not _prepare_pose(initial):
		_body.reset(); actor.collision_layer = saved_layer; actor.collision_mask = saved_mask
		_busy = false; return _result(false,"initial_pose")
	actor.velocity = Vector3.ZERO
	_final_dead = event.kind == "final_death"
	_death_key = event.get("death_key","") if _final_dead else ""
	_event_id = event_id; mode = "ACTIVE"
	_write_pose(); _last = initial; _busy = false
	if _final_dead and _eyes!=null:_eyes.close_after_confirmed_death()
	return _result(true)

## A later final death never restarts or teleports an already physical body.
func confirm_final_death(event_id: String) -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode not in ["ACTIVE","RECOVERING"] or _final_dead: return _result(false,"lifetime_or_busy")
	_busy = true
	var event := _receipt(event_id)
	if event.is_empty() or event.kind != "final_death" or mode not in ["ACTIVE","RECOVERING"]:
		_busy = false; return _result(false,"event_not_confirmed")
	_final_dead = true; _death_key = event.death_key; _busy = false
	if _eyes!=null:_eyes.close_after_confirmed_death()
	if mode == "RECOVERING": return cancel_recovery("confirmed_final_death")
	return _result(true)

## Recovery has a separate live clearance/source-release owner. Its colliding
## guard covers the accepted full-skin volume while the rigid pool is paused.
func begin_recovery(guard: CollisionObject3D, clearance: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode != "ACTIVE" or _final_dead: return _result(false,"recovery_lifetime")
	_busy = true
	var valid := _is_current() and _guard_valid(guard) and _clearance_accepts(clearance,"begin")
	if not valid or mode != "ACTIVE" or _final_dead:
		_busy = false; return _result(false,"recovery_proof")
	var physical: Dictionary = _body.snapshot()
	if not physical.get("settled",false): _busy = false; return _result(false,"physical_not_settled")
	var paused: Dictionary = _body.stop_preserve()
	if not paused.get("ok",false): _busy = false; return _result(false,"pause_failed")
	_recovery_guard = weakref(guard); mode = "RECOVERING"; _busy = false
	var value := _result(true); value["physical"] = physical; return value

func _guard_valid(guard: Variant) -> bool:
	return guard is CollisionObject3D and is_instance_valid(guard) and guard.is_inside_tree() and not guard.is_queued_for_deletion() and guard.collision_layer != 0 and guard.collision_mask != 0 and _nodes_current() and guard.get_world_3d() == _actor.get_ref().get_world_3d()

func _clearance_accepts(clearance: Callable, phase: String) -> bool:
	if not clearance.is_valid() or not _nodes_current(): return false
	var actor: CharacterBody3D = _actor.get_ref()
	if actor.collision_layer != 0 or actor.collision_mask != 0: return false
	var accepted: Variant = clearance.call(phase,_binding.duplicate())
	return accepted is bool and accepted and _is_current() and actor.collision_layer == 0 and actor.collision_mask == 0 and not _final_dead

func apply_recovery_pose(frames: Dictionary, clearance: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode != "RECOVERING" or _final_dead: return _result(false,"recovery_lifetime")
	_busy = true
	var valid := _guard_valid(_recovery_guard.get_ref()) and _clearance_accepts(clearance,"step")
	if not valid or mode != "RECOVERING" or not _prepare_pose({"valid":true,"active":true,"bone_world_frames":frames}):
		_busy = false; return _result(false,"recovery_proof")
	_write_pose(); _busy = false; return _result(true)

func cancel_recovery(reason := "blocked") -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode != "RECOVERING": return _result(false,"recovery_lifetime")
	_busy = true
	if not _is_current(): _busy = false; retire("stale_recovery"); return _result(false,"stale_recovery")
	var frames: Dictionary = _body.capture_world_frames()
	var guard: CollisionObject3D = _recovery_guard.get_ref() if _recovery_guard != null else null
	var guard_layer := guard.collision_layer if is_instance_valid(guard) else 0
	var guard_mask := guard.collision_mask if is_instance_valid(guard) else 0
	if is_instance_valid(guard): guard.collision_layer = 0; guard.collision_mask = 0
	_body.reset()
	var resumed: Dictionary = _body.start(frames,Vector3.ZERO)
	if not resumed.get("ok",false):
		if is_instance_valid(guard): guard.collision_layer = guard_layer; guard.collision_mask = guard_mask
		mode = "RECOVERY_HOLD"; _fault = "resume_failed:"+str(resumed.get("error")); _busy = false
		return _result(false,_fault)
	mode = "ACTIVE"; _recovery_guard = null; _busy = false
	return _result(true,reason)

## Caller must prove full standing shape/support/path and same-life external
## source release inside clearance('commit'). No generic boolean receipt.
func commit_recovery(target: Transform3D, local_poses: Array[Transform3D], clearance: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode != "RECOVERING" or _final_dead or not target.is_finite() or local_poses.size() != 28: return _result(false,"recovery_lifetime")
	for pose: Transform3D in local_poses:
		if not pose.is_finite(): return _result(false,"standing_pose")
	_busy = true
	var valid := _guard_valid(_recovery_guard.get_ref()) and _clearance_accepts(clearance,"commit")
	if not valid or mode != "RECOVERING": _busy = false; return _result(false,"recovery_proof")
	var actor: CharacterBody3D = _actor.get_ref()
	var rig: Skeleton3D = _rig.get_ref()
	var guard: CollisionObject3D = _recovery_guard.get_ref()
	guard.collision_layer = 0; guard.collision_mask = 0
	actor.global_transform = target
	for i in 28: rig.set_bone_pose(i,local_poses[i])
	rig.clear_bones_global_pose_override()
	actor.collision_layer = _walking_layer; actor.collision_mask = _walking_mask; actor.velocity = Vector3.ZERO
	_body.reset(); _recovery_guard = null; mode = "IDLE"; _event_id = ""; _busy = false
	return _result(true)

func _prepare_pose(snapshot: Dictionary) -> bool:
	if not snapshot.get("valid",false) or not snapshot.get("active",false) or not snapshot.get("bone_world_frames") is Dictionary or snapshot.bone_world_frames.size() != 28 or not _nodes_current(): return false
	var rig: Skeleton3D = _rig.get_ref()
	if not rig.global_transform.is_finite() or absf(rig.global_basis.determinant()) < .000001: return false
	var inverse := rig.global_transform.affine_inverse()
	for i in 28:
		var frame: Variant = snapshot.bone_world_frames.get(_names[i])
		if not frame is Transform3D or not frame.is_finite(): return false
		_local_frames[i] = inverse * frame
	return true

func _write_pose() -> void:
	var rig: Skeleton3D = _rig.get_ref()
	for i in 28: rig.set_bone_global_pose_override(i,_local_frames[i],1.0,true)

## Root calls once after each physics step; no animation or timer creates motion.
func advance() -> Dictionary:
	if not Thread.is_main_thread() or _busy or mode != "ACTIVE": return _result(false,"lifetime_or_busy")
	_busy = true
	if not _is_current():
		_busy = false; retire("stale_binding"); return _result(false,"stale_binding")
	var actor: CharacterBody3D = _actor.get_ref()
	if actor.collision_layer != 0 or actor.collision_mask != 0:
		_busy = false; retire("capsule_owner_changed"); return _result(false,"capsule_owner_changed")
	var physical: Dictionary = _body.snapshot()
	if not _prepare_pose(physical):
		_busy = false; retire("physical_pose"); return _result(false,"physical_pose")
	_write_pose(); _last = physical; _busy = false
	return {"ok":true, "mode":mode, "final_dead":_final_dead, "death_key":_death_key, "physical":physical, "damage_authority":false}

func owned_bodies() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	if _body != null and mode != "RETIRED": result.assign(_body.owned_bodies())
	return result

func status() -> Dictionary:
	var value := _result(mode in ["IDLE","ACTIVE","RECOVERING"],_fault)
	value["binding"] = _binding.duplicate()
	value["automatic_recovery"] = false
	return value

## Irreversible for this life. Does not restore a dead/stale walking capsule or
## clear a replacement rig's pose. Root owns respawn, corpse removal and recovery.
func retire(reason := "retired") -> void:
	if not Thread.is_main_thread() or mode == "RETIRED": return
	mode = "RETIRED"; _fault = reason
	if _eyes!=null:_eyes.dispose();_eyes=null
	if _body != null: _body.dispose(); _body = null
	_current = Callable(); _events = Callable(); _last.clear()

func dispose() -> void:
	retire("disposed")
