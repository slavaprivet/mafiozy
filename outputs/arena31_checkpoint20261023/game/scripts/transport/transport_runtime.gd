extends Node3D

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Host = preload("res://scripts/transport/transport_logical_host.gd")
const AccessProvider = preload("res://scripts/transport/transport_access_provider.gd")
const BootstrapProvider = preload("res://scripts/transport/transport_bootstrap_provider.gd")
const ActorTransition = preload("res://scripts/transport/transport_actor_transition.gd")

@export_flags_3d_physics var access_collision_mask := 1

var catalog: RefCounted
var host: RefCounted
var access: RefCounted
var bootstrap: RefCounted
var actor_transition: RefCounted
var initialized := false
var error := ""
var _runtime_leases: Dictionary = {}
var _native_vehicle_bodies: Dictionary = {}
var _native_actor_bodies: Dictionary = {}

func _ready() -> void:
	catalog = Catalog.new(); host = Host.new(); access = AccessProvider.new(); bootstrap = BootstrapProvider.new(); actor_transition = ActorTransition.new()
	if not catalog.load_file():
		error = catalog.error; return
	host.configure(catalog)
	if not bootstrap.configure(catalog):
		error = bootstrap.error; return
	actor_transition.configure(access)
	initialized = true

func bootstrap_new_session(request: Dictionary) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var issued: Dictionary = bootstrap.new_session(request)
	if issued.code not in ["OK", "DUPLICATE"]: return issued
	var packet: Dictionary = issued.packet
	if issued.code == "DUPLICATE": return {"code": "DUPLICATE", "packet": packet, "host": host.diagnostics()}
	var started: Dictionary = begin_session(packet.session)
	if started.code != "OK": return {"code": "HOST_SESSION", "host": started}
	var published: Dictionary = publish_roster(packet.roster)
	if published.code != "OK": return {"code": "HOST_ROSTER", "host": published}
	return {"code": "OK", "packet": packet, "host": host.diagnostics()}

func begin_session(packet: Dictionary) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var result: Dictionary = host.begin_session(packet)
	if result.code != "OK": return result
	actor_transition.cancel_all()
	_runtime_leases.clear()
	_native_vehicle_bodies.clear(); _native_actor_bodies.clear()
	return result

func publish_roster(snapshot: Dictionary) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var result: Dictionary = host.publish_roster(snapshot)
	for token in _runtime_leases.keys():
		if host.lease(token).is_empty():
			actor_transition.cancel(token)
			_runtime_leases.erase(token)
	return result

func sync_native_vehicle_pose(vehicle_ref: Dictionary, vehicle_body: RigidBody3D, source_clock: int) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	if vehicle_body == null or not vehicle_body.is_inside_tree() or vehicle_body.get_world_3d() != get_world_3d(): return {"code": "WORLD"}
	if String(vehicle_body.get_meta("vehicle_id", "")) != String(vehicle_ref.get("vehicle_id", "")) or int(vehicle_body.get_meta("life_generation", 0)) != int(vehicle_ref.get("life_generation", -1)): return {"code": "IDENTITY"}
	var vehicle_key := _vehicle_key(vehicle_ref)
	if vehicle_key.is_empty(): return {"code": "IDENTITY"}
	if _native_vehicle_bodies.has(vehicle_key) and int(_native_vehicle_bodies[vehicle_key]) != vehicle_body.get_instance_id(): return {"code": "BODY_BINDING"}
	var position := vehicle_body.global_position
	var forward := (-vehicle_body.global_basis.z).slide(Vector3.UP)
	if not is_finite(position.x) or not is_finite(position.y) or not is_finite(position.z) or forward.length_squared() < .000001: return {"code": "POSE"}
	forward = forward.normalized()
	var yaw := atan2(-forward.x, -forward.z)
	var result: Dictionary = host.sync_native_vehicle_pose(vehicle_ref, position, yaw, source_clock)
	if result.code == "OK": _native_vehicle_bodies[vehicle_key] = vehicle_body.get_instance_id()
	return result

func begin_board(actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int, actor_feet: Vector3, door_ready: bool, exclude: Array[RID] = []) -> Dictionary:
	return _begin("BOARD", actor_ref, vehicle_ref, seat_id, source_clock, actor_feet, door_ready, exclude)

func begin_exit(actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int, actor_feet: Vector3, door_ready: bool, exclude: Array[RID] = []) -> Dictionary:
	return _begin("EXIT", actor_ref, vehicle_ref, seat_id, source_clock, actor_feet, door_ready, exclude)

func advance_interaction(token: String, pressed: bool, source_clock: int, actor_feet: Vector3, door_ready: bool, exclude: Array[RID] = []) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var lease: Dictionary = _runtime_leases.get(token, {})
	if lease.is_empty(): return {"code": "LEASE"}
	var target_data: Dictionary = host.approach_world_pose(lease.vehicle, lease.seat_id)
	if target_data.is_empty():
		_runtime_leases.erase(token); host.cancel(token); return {"code": "LIFETIME_ENDED"}
	var target := _vector(target_data.position_m)
	access.configure(get_world_3d().direct_space_state, access_collision_mask)
	var physical: Dictionary = access.probe_access(lease.actor, lease.vehicle, lease.seat_id, lease.action, source_clock, actor_feet, target, exclude)
	physical["door_ready"] = door_ready
	var result: Dictionary = host.advance_hold(token, pressed, source_clock, physical)
	if result.code not in ["HOLDING", "TRANSITION_REQUIRED"]: _runtime_leases.erase(token)
	return result

func begin_actor_transition(token: String, source_clock: int, actor_body: CharacterBody3D, vehicle_body: RigidBody3D) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var claim: Dictionary = host.lease(token)
	if claim.is_empty() or claim.get("phase", "") != "TRANSITION": return {"code": "LEASE"}
	if source_clock < int(claim.get("transition_started_clock", 0)): return {"code": "STALE_CLOCK"}
	var vehicle_key := _vehicle_key(claim.vehicle); var actor_key := _actor_key(claim.actor)
	if not _native_vehicle_bodies.has(vehicle_key) or int(_native_vehicle_bodies[vehicle_key]) != vehicle_body.get_instance_id(): return {"code": "BODY_BINDING"}
	if _native_actor_bodies.has(actor_key) and int(_native_actor_bodies[actor_key]) != actor_body.get_instance_id(): return {"code": "BODY_BINDING"}
	var vehicle_record: Dictionary = host.vehicle_record(claim.vehicle)
	var descriptor: Dictionary = catalog.seat(vehicle_record.get("profile_id", ""), claim.seat_id)
	if descriptor.is_empty(): return {"code": "SEAT"}
	var result: Dictionary = actor_transition.begin(token, claim.action, claim.actor, claim.vehicle, claim.seat_id, source_clock, actor_body, vehicle_body, _vector(descriptor.anchor_local_m), _vector(descriptor.approach_local_m))
	if result.code == "ACTIVE": _native_actor_bodies[actor_key] = actor_body.get_instance_id()
	return result

func advance_actor_transition(token: String, delta: float, source_clock: int) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var physical: Dictionary = actor_transition.step(token, delta, source_clock)
	if physical.code != "COMPLETE": return physical
	var logical: Dictionary = host.complete_transition(token, source_clock, physical.receipt)
	if logical.code in ["BOARDED", "EXITED", "AWAITING_SOURCE"]:
		actor_transition.commit(token); _runtime_leases.erase(token)
	return {"code": logical.code, "logical": logical, "physical": physical}

func cancel_interaction(token: String) -> Dictionary:
	_runtime_leases.erase(token)
	actor_transition.cancel(token)
	return host.cancel(token) if initialized else {"code": "NOT_READY", "error": error}

func complete_transition(token: String, source_clock: int, transition_receipt: Dictionary) -> Dictionary:
	# Production completion is emitted internally by advance_actor_transition()
	# after it moves the bound CharacterBody3D.  Refuse caller-authored receipt
	# dictionaries so this compatibility surface cannot fabricate seat arrival.
	return {"code": "TRANSITION_PROVIDER_REQUIRED", "token": token, "source_clock": source_clock, "provider": transition_receipt.get("provider", "")}

func _begin(action: String, actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int, actor_feet: Vector3, door_ready: bool, exclude: Array[RID]) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var target_data: Dictionary = host.approach_world_pose(vehicle_ref, seat_id)
	if target_data.is_empty(): return {"code": "IDENTITY"}
	var target := _vector(target_data.position_m)
	access.configure(get_world_3d().direct_space_state, access_collision_mask)
	var physical: Dictionary = access.probe_access(actor_ref, vehicle_ref, seat_id, action, source_clock, actor_feet, target, exclude)
	physical["door_ready"] = door_ready
	var result: Dictionary = host.begin_board(actor_ref, vehicle_ref, seat_id, source_clock, physical) if action == "BOARD" else host.begin_exit(actor_ref, vehicle_ref, seat_id, source_clock, physical)
	if result.code == "HOLDING":
		_runtime_leases[result.token] = {"action": action, "actor": actor_ref.duplicate(true), "vehicle": vehicle_ref.duplicate(true), "seat_id": seat_id}
	return result

func _vector(value: Dictionary) -> Vector3:
	return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))

func _vehicle_key(ref: Dictionary) -> String:
	var id := String(ref.get("vehicle_id", "")); var generation := int(ref.get("life_generation", 0))
	return "%s@%d" % [id, generation] if not id.is_empty() and generation > 0 else ""

func _actor_key(ref: Dictionary) -> String:
	var id := String(ref.get("actor_id", "")); var generation := int(ref.get("life_generation", 0))
	return "%s@%d" % [id, generation] if not id.is_empty() and generation > 0 else ""
