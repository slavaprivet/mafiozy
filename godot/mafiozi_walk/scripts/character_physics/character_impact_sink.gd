extends RefCounted
## Synchronous per-life adapter. Ports are trusted local owners, not network proof.
## This adapter never writes HP, Nodes, physical velocity or skeleton transforms.
const Policy = preload("res://scripts/character_physics/character_impact_policy.gd")
const CAPACITY := 64
const PORTS := ["current_owner", "resolve_admitted", "preflight", "dispatch", "decorate_local", "clear_local"]
const BINDING := ["actor_id", "life_generation", "session_id", "session_generation"]
const GUARD := ["actor_id", "life_generation", "session_id", "session_generation", "pose_epoch", "pose_owner", "stance", "driver_mode", "transport_state", "transport_token", "physics_tick", "geometry_revision", "dead", "mass_kg"]
var _binding := {}
var _profile := {}
var _ports := {}
var _policy: RefCounted
var _receipts := {}
var _order: Array[String] = []
var _ready := false
var _busy := false
var _disposed := false
var _local_epoch := -1
var _requires_dead := false

static func _text(value: Variant, maximum: int = 256) -> bool:
	return value is String and not value.is_empty() and value.length() <= maximum

static func _integer(value: Variant, minimum: int = 0) -> bool:
	return value is int and value >= minimum and value <= 2147483647

static func _point(value: Variant) -> bool:
	return value is Vector3 and value.is_finite() and maxf(absf(value.x),maxf(absf(value.y),absf(value.z))) <= 10000000.0

static func _identity(value: Dictionary) -> bool:
	return _text(value.get("actor_id")) and _text(value.get("session_id")) and _integer(value.get("life_generation"),1) and _integer(value.get("session_generation"),1)

func _same_binding(value: Dictionary) -> bool:
	for key: String in BINDING:
		if typeof(value.get(key)) != typeof(_binding.get(key)) or value.get(key) != _binding.get(key): return false
	return true

func _owner() -> Dictionary:
	if not _ports.get("current_owner") is Callable or not _ports.current_owner.is_valid(): return {}
	var value: Variant = _ports.current_owner.call()
	if not value is Dictionary or not _same_binding(value): return {}
	if not _integer(value.get("pose_epoch")) or not _text(value.get("pose_owner"),96) or not _integer(value.get("geometry_revision")) or not _integer(value.get("physics_tick")): return {}
	if not value.get("dead") is bool or not value.get("stance") is String or not _profile.stance_thresholds_mps.has(value.stance): return {}
	if value.get("driver_mode") not in ["IDLE","DONE","FALLING","GETTING_UP","FAULTED","DISPOSED"] or value.get("transport_state") not in ["none","seated","transition","exit_physical"]: return {}
	if not value.get("transport_token") is String or value.transport_token.length() > 256 or (value.transport_state != "none" and value.transport_token.is_empty()): return {}
	if not (value.get("mass_kg") is float or value.get("mass_kg") is int) or not is_finite(float(value.mass_kg)) or absf(float(value.mass_kg)-float(_profile.mass_kg)) > .000001: return {}
	if not value.get("physical_body_rids") is Array or value.physical_body_rids.size() > 16: return {}
	for rid: Variant in value.physical_body_rids:
		if not rid is RID or not rid.is_valid(): return {}
	if value.has("recovery_suppressed") and not value.recovery_suppressed is bool: return {}
	if _requires_dead and not value.dead: return {}
	if _ready and value.dead: _requires_dead = true
	var snapshot := {}
	for key: String in GUARD: snapshot[key] = value[key]
	snapshot.physical_body_rids = value.physical_body_rids.duplicate()
	snapshot.recovery_suppressed = value.get("recovery_suppressed")
	return snapshot

func _ports_valid() -> bool:
	for name: String in PORTS:
		if not _ports.get(name) is Callable or not _ports[name].is_valid(): return false
	return true

static func _same_guard(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty(): return false
	for key: String in GUARD:
		if typeof(a.get(key)) != typeof(b.get(key)) or a.get(key) != b.get(key): return false
	return a.physical_body_rids == b.physical_body_rids and a.recovery_suppressed == b.recovery_suppressed

func configure(binding: Dictionary, profile: Dictionary, ports: Dictionary) -> Dictionary:
	if _busy or not Thread.is_main_thread(): return {"ok":false,"error":"reentry_or_thread"}
	if _ready or _disposed or binding.size() != 4 or not _identity(binding): return {"ok":false,"error":"binding"}
	for name: String in PORTS:
		if not ports.get(name) is Callable or not ports[name].is_valid(): return {"ok":false,"error":"port:"+name}
	var policy := Policy.new()
	var configured: Dictionary = policy.configure(binding.actor_id,binding.life_generation,binding.session_id,profile)
	if not configured.get("ok",false): return configured
	_busy = true
	_binding = binding.duplicate(true); _profile = profile.duplicate(true)
	for name: String in PORTS: _ports[name] = ports[name]
	var owner := _owner()
	if owner.is_empty() or not _ports_valid():
		_ports.clear(); _binding.clear(); _profile.clear(); policy.dispose(); _busy = false
		return {"ok":false,"error":"current_owner"}
	_policy = policy; _ready = true; _local_epoch = owner.pose_epoch
	_requires_dead = owner.dead
	_ports.clear_local.call(_local_epoch)
	_busy = false
	return {"ok":true}

func _result(status: String, error: String = "", consumed: bool = false) -> Dictionary:
	return {"ok":status in ["no_reaction","local_presented","physical_applied","physical_started","observed_only"],"status":status,"error":error,"consumed":consumed,"binding":_binding.duplicate(),"physical_applied":false,"applied_impulse_ns":Vector3.ZERO}

func _remember(key: String, result: Dictionary) -> Dictionary:
	if _order.size() == CAPACITY: _receipts.erase(_order.pop_front())
	_order.append(key); _receipts[key] = result.duplicate(true)
	return result

static func _uncertain(result: Dictionary, error: String) -> Dictionary:
	result.ok = false; result.status = "consumed_failed"; result.error = error
	result.may_have_applied = true; result.physical_applied = null; result.applied_impulse_ns = null
	return result

func _input_error(input: Dictionary, owner: Dictionary, admitted: Dictionary) -> String:
	var delivery: Variant = input.get("delivery")
	if delivery not in ["command_unapplied","solver_observed"]: return "delivery"
	var fields := ["delivery","world_point","impulse_ns","physics_tick","force_profile_id"]
	if delivery == "solver_observed": fields.append_array(["solver_body_rid","post_velocity","post_angular_velocity","velocity_reference"])
	if input.size() != fields.size(): return "physical_schema"
	for key: Variant in input:
		if not (key is String or key is StringName) or str(key) not in fields: return "physical_schema"
	if not _text(input.get("force_profile_id"),128) or not _integer(input.get("physics_tick")) or input.physics_tick != owner.physics_tick: return "physical_sample"
	if not _point(input.get("world_point")) or input.world_point.distance_to(admitted.world_point) > .0001: return "contact_changed"
	if not input.get("impulse_ns") is Vector3 or not input.impulse_ns.is_finite(): return "impulse"
	var impulse: Vector3 = input.impulse_ns
	var limit: float = _profile.max_impulse_ns
	if maxf(absf(impulse.x),maxf(absf(impulse.y),absf(impulse.z))) > limit or impulse.length() > limit: return "excess_impulse"
	if delivery == "solver_observed":
		if not input.get("solver_body_rid") is RID or input.solver_body_rid not in owner.physical_body_rids: return "solver_owner"
		if not _point(input.get("velocity_reference")) or not input.get("post_velocity") is Vector3 or not input.post_velocity.is_finite() or input.post_velocity.length() > 80: return "post_velocity"
		if not input.get("post_angular_velocity") is Vector3 or not input.post_angular_velocity.is_finite() or input.post_angular_velocity.length() > 30: return "post_angular_velocity"
	return ""

func submit(admission_handle: Variant, physical_input: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy: return _result("rejected","reentry_or_thread")
	if not _ready or _disposed or not _ports_valid(): return _result("rejected","lifetime")
	if physical_input.size() > 9: return _result("rejected","physical_schema")
	_busy = true
	var result := _submit(admission_handle,physical_input.duplicate())
	_busy = false
	return result

func _submit(handle: Variant, input: Dictionary) -> Dictionary:
	var owner := _owner()
	if owner.is_empty(): return _result("rejected","current_owner")
	if owner.pose_epoch != _local_epoch:
		_local_epoch = owner.pose_epoch; _ports.clear_local.call(_local_epoch)
	var value: Variant = _ports.resolve_admitted.call(handle)
	if not value is Dictionary or not value.get("ok",false) is bool or value.get("ok") != true: return _result("rejected","source_admission")
	var admitted := {}
	for field: String in BINDING + ["pose_epoch","geometry_revision","producer_id","event_id","kind","world_point","final_dead","authoritative_knockdown"]: admitted[field] = value.get(field)
	if not _same_binding(admitted) or not _integer(admitted.get("pose_epoch")) or admitted.pose_epoch != owner.pose_epoch or not _integer(admitted.get("geometry_revision")) or admitted.geometry_revision != owner.geometry_revision: return _result("rejected","stale_admission")
	if not _text(admitted.get("producer_id"),128) or not _text(admitted.get("event_id")) or not admitted.get("kind") is String or admitted.kind not in Policy.KINDS: return _result("rejected","event_identity")
	if not _point(admitted.get("world_point")) or not admitted.get("final_dead") is bool or not admitted.get("authoritative_knockdown") is bool: return _result("rejected","admission_fields")
	var key := JSON.stringify([admitted.producer_id,admitted.event_id])
	if _receipts.has(key):
		var duplicate := _result("rejected","duplicate_event",true)
		duplicate.previous_status = _receipts[key].status; duplicate.event_key = key
		return duplicate
	var invalid := _input_error(input,owner,admitted)
	if not invalid.is_empty(): return _result("rejected",invalid)
	if owner.driver_mode in ["FAULTED","DISPOSED"]: return _result("rejected","physical_owner_unavailable")
	if owner.transport_state in ["seated","transition"] or (owner.transport_state == "exit_physical" and owner.driver_mode != "FALLING"): return _result("owner_deferred","transport_owner")
	# Preview immutable policy classification solely to preflight before consume.
	var reaction := "none"
	if owner.dead or admitted.final_dead or admitted.authoritative_knockdown or input.impulse_ns.length()/float(_profile.mass_kg) >= float(_profile.stance_thresholds_mps[owner.stance]): reaction = "knockdown"
	elif input.impulse_ns.length() > 0: reaction = "local"
	var route := "none"; var action := "none"
	if reaction != "none":
		if owner.driver_mode in ["FALLING","GETTING_UP"]:
			route = "physical"
			action = "apply_existing" if owner.driver_mode == "FALLING" else "resume_point_impulse"
			if input.delivery == "solver_observed": action = "observe_existing" if owner.driver_mode == "FALLING" else "resume_observed"
		elif reaction == "local" and not owner.dead:
			route = "local"; action = "local_present"
		else:
			route = "physical"; action = "begin_point_impulse" if input.delivery == "command_unapplied" else "begin_observed"
	var command := {"event_key":key,"binding":_binding.duplicate(),"owner_before":owner,"admitted":admitted,"physical_input":input,"reaction":reaction,"action":action,"apply_impulse_ns":input.impulse_ns if route == "physical" and input.delivery == "command_unapplied" else Vector3.ZERO,"final_dead":owner.dead or admitted.final_dead}
	var expected_epoch: int = owner.pose_epoch
	var expected_pose_owner: String = owner.pose_owner
	if not _ports_valid(): return _result("rejected","port_lifetime")
	if route != "none":
		var preflight: Variant = _ports.preflight.call(route,command.duplicate(true))
		if not preflight is Dictionary or not preflight.get("ok") is bool or preflight.get("ok") != true: return _result("rejected","unsupported_route")
		if not _integer(preflight.get("pose_epoch")) or not _text(preflight.get("pose_owner"),96): return _result("rejected","planned_pose_lease")
		expected_epoch = preflight.pose_epoch; expected_pose_owner = preflight.pose_owner
		if route == "local" or action in ["apply_existing","observe_existing"]:
			if expected_epoch != owner.pose_epoch or expected_pose_owner != owner.pose_owner: return _result("rejected","planned_pose_lease")
		elif expected_epoch < owner.pose_epoch: return _result("rejected","planned_pose_lease")
	command.expected_pose_epoch = expected_epoch; command.expected_pose_owner = expected_pose_owner
	if not _ports_valid() or not _same_guard(owner,_owner()): return _result("rejected","owner_changed_before_consume")
	# The policy key includes producer namespace without introducing alias collisions.
	var event_id := key.sha256_text()
	var policy_event := {"actor_id":_binding.actor_id,"life_generation":_binding.life_generation,"session_id":_binding.session_id,"event_id":event_id,"kind":admitted.kind,"world_point":admitted.world_point,"impulse_ns":input.impulse_ns,"stance":owner.stance,"dead":command.final_dead,"authoritative_knockdown":admitted.authoritative_knockdown}
	var policy: Dictionary = _policy.consume(policy_event)
	if not policy.get("ok",false): return _result("rejected","policy:"+str(policy.get("error")))
	var result := _result("consumed_failed","dispatch_not_committed",true)
	result.event_key = key; result.reaction = reaction; result.pose_epoch = owner.pose_epoch
	if policy.reaction != reaction: return _remember(key,result)
	if route == "none":
		result.status = "no_reaction"; result.ok = true; result.error = ""
		return _remember(key,result)
	# A definitive admitted death is monotonic for this bound life, even if the
	# owner transaction subsequently fails. This rejects revival; it writes no HP.
	_requires_dead = _requires_dead or command.final_dead
	# Exactly one attempt. A failed/uncertain receipt is terminal in this window.
	var delivered: Variant = _ports.dispatch.call(route,command.duplicate(true))
	var after := _owner()
	result.may_have_applied = true
	result.physical_applied = null; result.applied_impulse_ns = null
	if not delivered is Dictionary or not delivered.get("ok") is bool or delivered.get("ok") != true or delivered.get("event_key") != key or after.is_empty(): return _remember(key,result)
	if not delivered.get("applied_impulse_ns") is Vector3 or not delivered.applied_impulse_ns.is_finite() or delivered.applied_impulse_ns.distance_to(command.apply_impulse_ns) > .00001: return _remember(key,result)
	if not _integer(delivered.get("pose_epoch")) or delivered.get("pose_epoch") != after.pose_epoch or after.pose_epoch != expected_epoch or after.pose_owner != expected_pose_owner or after.geometry_revision != owner.geometry_revision or after.transport_state != owner.transport_state or after.transport_token != owner.transport_token or after.physics_tick != owner.physics_tick: return _remember(key,result)
	if route == "local" and not _same_guard(owner,after): return _remember(key,result)
	if route == "physical" and after.driver_mode != "FALLING": return _remember(key,result)
	if route == "physical" and action in ["apply_existing","observe_existing"] and after.physical_body_rids != owner.physical_body_rids: return _remember(key,result)
	if command.final_dead and (not after.dead or after.recovery_suppressed != true): return _remember(key,result)
	result.ok = true; result.error = ""; result.may_have_applied = false
	result.pose_epoch = after.pose_epoch; result.applied_impulse_ns = command.apply_impulse_ns
	result.physical_applied = command.apply_impulse_ns != Vector3.ZERO
	result.status = "local_presented" if route == "local" else ("physical_applied" if result.physical_applied else "observed_only")
	if route == "physical" and not result.physical_applied and action in ["begin_point_impulse","begin_observed","resume_point_impulse","resume_observed"]: result.status = "physical_started"
	if route == "physical":
		if not _ports.clear_local.is_valid():
			return _remember(key,_uncertain(result,"port_changed_after_commit"))
		_ports.clear_local.call(after.pose_epoch); _local_epoch = after.pose_epoch
		if not _same_guard(after,_owner()):
			result = _uncertain(result,"owner_changed_after_commit")
	return _remember(key,result)

func decorate_selected(delta: float, base_selected: Dictionary) -> Dictionary:
	if _busy or not Thread.is_main_thread() or not _ready or _disposed or not _ports_valid() or not is_finite(delta) or delta < 0 or delta > .1: return {"valid":false,"error":"lifetime_or_delta"}
	_busy = true
	var owner := _owner()
	var result := base_selected.duplicate(true)
	if owner.is_empty(): result = {"valid":false,"error":"current_owner"}
	elif owner.transport_state == "none" and not owner.dead and owner.driver_mode in ["IDLE","DONE"]:
		if owner.pose_epoch != _local_epoch: _ports.clear_local.call(owner.pose_epoch); _local_epoch = owner.pose_epoch
		if not _integer(base_selected.get("authority_epoch")) or base_selected.get("authority_epoch") != owner.pose_epoch: result = {"valid":false,"error":"pose_epoch"}
		else:
			var decorated: Variant = _ports.decorate_local.call(delta,base_selected.duplicate(true))
			if not decorated is Dictionary or not decorated.get("valid") is bool or decorated.get("valid") != true or not _integer(decorated.get("authority_epoch")) or decorated.get("authority_epoch") != owner.pose_epoch or not _same_guard(owner,_owner()): result = {"valid":false,"error":"presentation_port"}
			elif decorated.get("visual_offset") != base_selected.get("visual_offset") or decorated.get("visual_rotation") != base_selected.get("visual_rotation"): result = {"valid":false,"error":"presentation_root_changed"}
			else: result = decorated.duplicate(true)
	else:
		_ports.clear_local.call(owner.pose_epoch); _local_epoch = owner.pose_epoch
	_busy = false
	return result

func state() -> Dictionary:
	return {"ready":_ready,"disposed":_disposed,"busy":_busy,"binding":_binding.duplicate(),"remembered_events":_receipts.size(),"capacity":CAPACITY,"requires_dead":_requires_dead}

func dispose() -> void:
	if _busy or not Thread.is_main_thread() or _disposed: return
	_disposed = true; _ready = false
	if _policy != null: _policy.dispose()
	_policy = null; _ports.clear(); _receipts.clear(); _order.clear(); _profile.clear(); _binding.clear()
