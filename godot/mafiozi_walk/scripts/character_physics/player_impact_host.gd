extends Node
## Actual fixed-preview hero ports for the admitted-event sink. This is not a
## combat producer: a source owner must supply a current accepted-event resolver.
const Sink = preload("res://scripts/character_physics/character_impact_sink.gd")
const LocalReaction = preload("res://scripts/character_physics/local_hit_reaction.gd")
var sink: RefCounted
var _local: RefCounted
var _player: CharacterBody3D
var _transport: Node3D
var _driver: RefCounted
var _skeleton: Skeleton3D
var _resolver: Callable
var _binding := {}
var _rig := {}
var _meshes: Array[MeshInstance3D] = []
var _mesh_resources: Array[Mesh] = []
var _skins: Array[Skin] = []
var _local_active := false
var _local_dirty := false
var _local_epoch := -1
var _ready_for_events := false
var _owns_physical_advance := false
var _configured_once := false
var last_error := ""

func _init() -> void:
	set_physics_process(false)

func _ready() -> void:
	# Godot enables an overridden callback when the node enters the tree.
	set_physics_process(false)

func configure(player: CharacterBody3D, transport: Node3D, profile: Dictionary, inertia_kg_m2: Dictionary, admitted_resolver: Callable) -> Dictionary:
	if _configured_once or not is_inside_tree() or not is_instance_valid(player) or not is_instance_valid(transport) or not admitted_resolver.is_valid():
		return {"ok":false,"error":"binding"}
	_configured_once = true
	if not transport.ready_for_play or transport.player != player or transport.character_physics == null:
		return {"ok":false,"error":"physical_owner"}
	if float(profile.get("mass_kg", 0)) != 75.0 or player._hit_pose_decorator.is_valid():
		return {"ok":false,"error":"profile_or_pose_consumer"}
	_player = player; _transport = transport; _driver = transport.character_physics
	_skeleton = player._pose_skeleton; _resolver = admitted_resolver
	if not is_instance_valid(_skeleton) or _skeleton.get_bone_count() != 28:
		return {"ok":false,"error":"rig"}
	_binding = {"actor_id":player.get_meta("actor_id", ""), "life_generation":player.get_meta("life_generation", 0),
		"session_id":transport._session.session_id, "session_generation":transport._session.session_generation}
	_rig = {"names":[],"parents":[],"rest_local":[],"inertia_kg_m2":inertia_kg_m2.duplicate(true)}
	for i in 28:
		_rig.names.append(str(_skeleton.get_bone_name(i)))
		_rig.parents.append(_skeleton.get_bone_parent(i))
		_rig.rest_local.append(player._locomotion._rest_poses[i])
	for node: Node in _player._visual.find_children("*", "MeshInstance3D", true, false):
		if node.skin != null:
			_meshes.append(node); _mesh_resources.append(node.mesh); _skins.append(node.skin)
	if _meshes.is_empty(): return {"ok":false,"error":"skin"}
	_local = LocalReaction.new()
	var bound: Dictionary = _local.bind(_binding.actor_id, player._pose_epoch, _rig)
	if not bound.get("ok", false): return bound
	_local_epoch = player._pose_epoch
	sink = Sink.new()
	var configured: Dictionary = sink.configure(_binding, profile, {
		"current_owner":Callable(self,"current_owner"), "resolve_admitted":Callable(self,"_resolve_admitted"),
		"preflight":Callable(self,"_preflight"), "dispatch":Callable(self,"_dispatch"),
		"decorate_local":Callable(self,"_decorate_local"), "clear_local":Callable(self,"_clear_local")})
	if not configured.get("ok", false): return configured
	# Validate sink/profile/actual owner before binding the driver's one-shot life.
	# A rejected install must not poison a corrected installation in this scene.
	var physical_binding: Dictionary = _driver.bind_impact_session(_binding)
	if not physical_binding.get("ok", false):
		sink.dispose()
		return physical_binding
	if not player.set_hit_pose_decorator(Callable(self,"decorate_selected")):
		sink.dispose(); return {"ok":false,"error":"pose_consumer"}
	_ready_for_events = true
	return {"ok":true,"binding":_binding.duplicate(),"geometry_revision":0}

func _binding_valid() -> bool:
	if not is_instance_valid(_player) or not _player.is_inside_tree() or not is_instance_valid(_transport) or not _transport.is_inside_tree(): return false
	if _transport.player != _player or _transport.character_physics != _driver or not _transport.ready_for_play: return false
	if not is_instance_valid(_transport.runtime) or not is_instance_valid(_transport.runtime.host): return false
	if not is_instance_valid(_skeleton) or _player._pose_skeleton != _skeleton or not _skeleton.is_inside_tree(): return false
	if _player.get_meta("actor_id", "") != _binding.get("actor_id") or _player.get_meta("life_generation", -1) != _binding.get("life_generation"): return false
	var session: Dictionary = _transport.runtime.host.diagnostics().session
	if session.get("session_id") != _binding.get("session_id") or session.get("session_generation") != _binding.get("session_generation"): return false
	# This host binds one fixed native appearance. Replacement requires rebinding
	# through the source owner, never silently accepting a stale contact anchor.
	if _skeleton.get_bone_count() != 28: return false
	for i in _meshes.size():
		if not is_instance_valid(_meshes[i]) or not _meshes[i].is_inside_tree() or _meshes[i].mesh != _mesh_resources[i] or _meshes[i].skin != _skins[i]: return false
	return true

func current_owner() -> Dictionary:
	if not _binding_valid(): return {}
	var state: Dictionary = _driver.impact_owner_state()
	var transport_state := "none"
	if _transport.phase in ["SEATED","EXIT_HOLD"]: transport_state = "seated"
	elif _transport.phase == "EXITING" and _driver.mode in ["FALLING","GETTING_UP"]: transport_state = "exit_physical"
	elif _transport.phase not in ["ON_FOOT","DEAD"]: transport_state = "transition"
	var transport_token := ""
	if transport_state != "none":
		var vehicle: Dictionary = _transport.runtime.host.vehicle_record(_transport._vehicle_ref)
		if vehicle.is_empty(): return {}
		if _transport.phase in ["SEATED","EXIT_HOLD","EXITING","RETURNING_TO_SEAT"]:
			var occupant: Variant = vehicle.get("seats", {}).get(_transport.active_seat)
			if not occupant is Dictionary or occupant.get("actor_id") != _binding.actor_id or occupant.get("life_generation") != _binding.life_generation: return {}
		# Completing BOARD retires its interaction token. Represent current source
		# occupancy/transition identity; this fingerprint grants no new authority.
		transport_token = str(_transport.token)
		if transport_token.is_empty():
			transport_token = "native-owner:" + JSON.stringify([_binding.session_id, _binding.session_generation,
				_transport._vehicle_ref, _transport.active_seat, _binding.actor_id, _binding.life_generation,
				_transport.phase, _player._pose_epoch]).sha256_text()
	var stance := "standing" if _player.is_on_floor() else "airborne"
	var owner: Dictionary = _binding.duplicate()
	owner.merge({"pose_epoch":_player._pose_epoch,"pose_owner":str(_player._pose_authority),
		"geometry_revision":0,"physics_tick":Engine.get_physics_frames(),"stance":stance,"mass_kg":75.0,
		"driver_mode":state.get("driver_mode", "DISPOSED"),"dead":state.get("dead", false) or _transport.phase == "DEAD",
		"recovery_suppressed":state.get("recovery_suppressed", false),"transport_state":transport_state,
		"transport_token":transport_token,
		"physical_body_rids":state.get("physical_body_rids", [])})
	return owner

func _resolve_admitted(handle: Variant) -> Dictionary:
	if not _binding_valid() or not _resolver.is_valid(): return {"ok":false}
	var value: Variant = _resolver.call(handle)
	return value.duplicate(true) if value is Dictionary else {"ok":false}

func _local_event(command: Dictionary) -> Dictionary:
	return {"actor_id":_binding.actor_id,"epoch_id":_player._pose_epoch,
		"event_id":str(command.event_key).sha256_text(),"world_point":command.admitted.world_point,
		"impulse_ns":command.physical_input.impulse_ns}

func _preflight(route: String, command: Dictionary) -> Dictionary:
	if not _binding_valid(): return {"ok":false,"error":"lifetime"}
	if route == "physical":
		var result: Dictionary = _driver.preflight_impact(command)
		if not result.get("ok", false): last_error = "preflight:" + str(result.get("error", "unknown"))
		return result
	if route != "local" or _transport.phase != "ON_FOOT" or _player._pose_authority != &"on_foot": return {"ok":false,"error":"local_owner"}
	if _local_epoch != _player._pose_epoch: _clear_local(_player._pose_epoch)
	var result: Dictionary = _local.can_add_hit(_local_event(command), _driver.body.capture_world_frames())
	result.pose_epoch = _player._pose_epoch; result.pose_owner = str(_player._pose_authority)
	return result

func _dispatch(route: String, command: Dictionary) -> Dictionary:
	if not _binding_valid(): return {"ok":false,"error":"lifetime"}
	if route == "physical":
		var result: Dictionary = _driver.dispatch_impact(command)
		if _player._pose_authority == &"physical_impact":
			_owns_physical_advance = true
			set_physics_process(true)
		return result
	var checked := _preflight(route, command)
	if not checked.get("ok", false): return checked
	var added: Dictionary = _local.add_hit(_local_event(command), _driver.body.capture_world_frames())
	if not added.get("ok", false): return added
	_local_dirty = true
	return {"ok":true,"event_key":command.event_key,"pose_epoch":_player._pose_epoch,"applied_impulse_ns":Vector3.ZERO}

func submit(handle: Variant, physical_input: Dictionary) -> Dictionary:
	if not _ready_for_events or not _binding_valid(): return {"ok":false,"error":"lifetime","consumed":false}
	return sink.submit(handle, physical_input)

func _clear_local(epoch: int) -> void:
	if _local != null: _local.reset(epoch)
	_local_epoch = epoch; _local_active = false; _local_dirty = false

func _decorate_local(delta: float, selected: Dictionary) -> Dictionary:
	var sampled: Dictionary = _local.apply_to_selected(delta, selected)
	if sampled.get("valid", false):
		_local_active = sampled.get("active", false); _local_dirty = false
	return sampled

func decorate_selected(delta: float, selected: Dictionary) -> Dictionary:
	# No sink snapshots, copies or seven-joint simulation on ordinary idle gait.
	if not _local_active and not _local_dirty: return selected
	if not _binding_valid() or _player._pose_authority != &"on_foot":
		_clear_local(_local_epoch)
		return selected
	var base := selected.duplicate()
	base.authority_epoch = _player._pose_epoch
	var result: Dictionary = sink.decorate_selected(delta, base)
	if not result.get("valid", false):
		last_error = str(result.get("error", "local_pose"))
		_clear_local(_player._pose_epoch)
		return selected
	return result

func _physics_process(delta: float) -> void:
	if not _owns_physical_advance: return
	if not _binding_valid() or _player._pose_authority != &"physical_impact" or _transport.phase != "ON_FOOT":
		if is_instance_valid(_driver): _driver.fault_impact_owner("impact_host_binding_changed")
		_owns_physical_advance = false; set_physics_process(false)
		return # E.g. transport owns confirmed void death; never double-advance.
	var physical: Dictionary = _driver.advance(delta)
	if not physical.get("valid", false):
		last_error = str(physical.get("reason", "physical_pose"))
		_driver.fault_impact_owner("impact_host_advance:" + last_error)
		set_physics_process(false)
		return
	if physical.get("pose", {}).get("valid", false): _player._apply_selected_pose(physical.pose)
	if physical.get("done", false):
		var contact := KinematicCollision3D.new()
		if not _player.test_move(_player.global_transform, Vector3.DOWN * .01, contact, .001, true) or contact.get_normal().dot(Vector3.UP) < .7:
			return
		_player.set_preview_pose_authority(&"on_foot")
		_owns_physical_advance = false; set_physics_process(false)

func _exit_tree() -> void:
	_ready_for_events = false
	if is_instance_valid(_player) and _player._hit_pose_decorator == Callable(self,"decorate_selected"):
		_player.set_hit_pose_decorator(Callable())
	if sink != null: sink.dispose()
	if _owns_physical_advance and is_instance_valid(_driver):
		_driver.fault_impact_owner("impact_host_removed")
	# The guarded fault never restores walking filters or touches a newer lease.
