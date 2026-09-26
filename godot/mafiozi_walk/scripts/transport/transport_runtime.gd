extends Node3D

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Host = preload("res://scripts/transport/transport_logical_host.gd")
const AccessProvider = preload("res://scripts/transport/transport_access_provider.gd")

@export_flags_3d_physics var access_collision_mask := 1

var catalog: RefCounted
var host: RefCounted
var access: RefCounted
var initialized := false
var error := ""
var _runtime_leases: Dictionary = {}

func _ready() -> void:
	catalog = Catalog.new(); host = Host.new(); access = AccessProvider.new()
	if not catalog.load_file():
		error = catalog.error; return
	host.configure(catalog)
	initialized = true

func begin_session(packet: Dictionary) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	_runtime_leases.clear()
	return host.begin_session(packet)

func publish_roster(snapshot: Dictionary) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var result: Dictionary = host.publish_roster(snapshot)
	for token in _runtime_leases.keys():
		if host.lease(token).is_empty(): _runtime_leases.erase(token)
	return result

func begin_board(actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int, actor_feet: Vector3, exclude: Array[RID] = []) -> Dictionary:
	return _begin("BOARD", actor_ref, vehicle_ref, seat_id, source_clock, actor_feet, exclude)

func begin_exit(actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int, actor_feet: Vector3, exclude: Array[RID] = []) -> Dictionary:
	return _begin("EXIT", actor_ref, vehicle_ref, seat_id, source_clock, actor_feet, exclude)

func advance_interaction(token: String, pressed: bool, source_clock: int, actor_feet: Vector3, exclude: Array[RID] = []) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var lease: Dictionary = _runtime_leases.get(token, {})
	if lease.is_empty(): return {"code": "LEASE"}
	var target_data: Dictionary = host.approach_world_pose(lease.vehicle, lease.seat_id)
	if target_data.is_empty():
		_runtime_leases.erase(token); host.cancel(token); return {"code": "LIFETIME_ENDED"}
	var target := _vector(target_data.position_m)
	access.configure(get_world_3d().direct_space_state, access_collision_mask)
	var physical: Dictionary = access.probe_access(lease.actor, lease.vehicle, lease.seat_id, lease.action, source_clock, actor_feet, target, exclude)
	var result: Dictionary = host.advance_hold(token, pressed, source_clock, physical)
	if result.code != "HOLDING": _runtime_leases.erase(token)
	return result

func cancel_interaction(token: String) -> Dictionary:
	_runtime_leases.erase(token)
	return host.cancel(token) if initialized else {"code": "NOT_READY", "error": error}

func _begin(action: String, actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int, actor_feet: Vector3, exclude: Array[RID]) -> Dictionary:
	if not initialized: return {"code": "NOT_READY", "error": error}
	var target_data: Dictionary = host.approach_world_pose(vehicle_ref, seat_id)
	if target_data.is_empty(): return {"code": "IDENTITY"}
	var target := _vector(target_data.position_m)
	access.configure(get_world_3d().direct_space_state, access_collision_mask)
	var physical: Dictionary = access.probe_access(actor_ref, vehicle_ref, seat_id, action, source_clock, actor_feet, target, exclude)
	var result: Dictionary = host.begin_board(actor_ref, vehicle_ref, seat_id, source_clock, physical) if action == "BOARD" else host.begin_exit(actor_ref, vehicle_ref, seat_id, source_clock, physical)
	if result.code == "HOLDING":
		_runtime_leases[result.token] = {"action": action, "actor": actor_ref.duplicate(true), "vehicle": vehicle_ref.duplicate(true), "seat_id": seat_id}
	return result

func _vector(value: Dictionary) -> Vector3:
	return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
