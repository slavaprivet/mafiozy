extends SceneTree
const Lease = preload("res://vehicle_pause_lease.gd")

class Buffer:
	extends RefCounted
	func size() -> int: return 0
	func has_gap() -> bool: return false

class Body:
	extends RigidBody3D
	var _physics_tick := 0
	var _contact_sequence := 0
	var _control_sequence := 5
	var _control_source_clock := 10
	var _grounded_wheel_mask := 15
	var _throttle := 0.0
	var _steering_input := 0.0
	var _handbrake := true
	var _contact_buffer = Buffer.new()
	func snapshot_state() -> Dictionary: return {"tick":_physics_tick}

class Transport:
	extends Node3D
	var ready_for_play := true
	var phase := "ON_FOOT"
	var _parked_brake := true
	var _e_down := false
	var _pending_exit := false
	var _blocked_transition := false
	var _session := {"session_id":"test"}
	var _clock := 10
	var _sequence := 5
	var body: Body

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var transport := Transport.new()
	root.add_child(transport)
	var body := Body.new()
	transport.add_child(body)
	transport.body = body
	body.set_meta("vehicle_id", "parked-1")
	body.set_meta("life_generation", 1)
	var lease = Lease.new()
	transport.add_child(lease)
	for i in 31:
		body._physics_tick += 1
		body.position.x += .0002
		body.linear_velocity = Vector3(.012, 0, 0)
		lease._physics_process(1.0/60.0)
	var before := body.global_transform
	var receipt: Dictionary = lease.acquire()
	if receipt.is_empty() or not body.freeze or not lease.verify(receipt):
		printerr("FAIL: stable parked admission")
		quit(1); return
	if not lease.release(receipt) or body.freeze or body.global_transform != before or body.linear_velocity != Vector3(.012, 0, 0):
		printerr("FAIL: exact release")
		quit(1); return
	for i in 31:
		body._physics_tick += 1
		body.position.x += .001
		lease._physics_process(1.0/60.0)
	if not lease.acquire().is_empty():
		printerr("FAIL: drift admission")
		quit(1); return
	print("VEHICLE_PAUSE_NATIVE_PASS")
	quit(0)
