extends "res://scripts/transport/transport_actor_transition.gd"
## Local physical extension of the verified transport transaction. Boarding and
## walking exits retain the base provider; an articulated fall owns fast exits.
var character_physics: RefCounted

func _step_exit(state: Dictionary, actor: CharacterBody3D, vehicle: RigidBody3D, dt: float) -> Dictionary:
	if state.exit_kind != "tumble" or state.phase == "RELEASE" or character_physics == null:
		return super._step_exit(state, actor, vehicle, dt)
	if not state.get("ragdoll_started", false):
		var outward := (vehicle.global_basis * ((state.approach_local_m as Vector3) - (state.seat_local_m as Vector3))).slide(Vector3.UP).normalized()
		var point_velocity := vehicle.linear_velocity + vehicle.angular_velocity.cross(actor.global_position - vehicle.global_position)
		var started: Dictionary = character_physics.start_fall(point_velocity, outward * 2.4, vehicle.angular_velocity, actor.global_position)
		if not started.get("ok", false): return _result("BLOCKED", {"reason":"RAGDOLL_START", "detail":started, "pose":_pose_state(state, 0.0, 0.0)})
		state.ragdoll_started = true
	state.elapsed = float(state.elapsed) + dt
	var physical: Dictionary = character_physics.advance(dt)
	if not physical.get("valid", false): return _result("BLOCKED", {"reason":"RAGDOLL_PHYSICS", "detail":physical})
	var pose := _public_state(state)
	pose.merge({"source_phase":"exit_ragdoll", "physical_pose":physical.get("pose", {}), "ragdoll_mode":physical.mode, "door":0.0})
	if not physical.get("done", false): return _result("ACTIVE", {"pose":pose})
	var proof := _final_exit_probe(state, actor, vehicle)
	if not proof.get("reachable", false): return _result("BLOCKED", {"physical":proof,"pose":pose})
	var ground := KinematicCollision3D.new()
	if not actor.test_move(actor.global_transform, Vector3.DOWN * .01, ground, .001, true) or ground.get_normal().dot(Vector3.UP) < .7:
		return _result("BLOCKED", {"reason":"AWAIT_PHYSICAL_GROUND", "pose":pose})
	return _result("COMPLETE", {"receipt":_receipt(state, {"outside_reached":true,"source_exit_kind":"tumble","door_release_done":true,"recovery_done":true,"grounded":true,"blocked":false}),"physical":proof,"pose":pose})

func _cancel_state(state: Dictionary, release_all: bool = false) -> void:
	if state.get("ragdoll_started", false) and character_physics != null: character_physics.cancel()
	super._cancel_state(state, release_all)
