extends SceneTree
const Pause = preload("res://scripts/map_editor/scene_pause_owner.gd")
class Counter extends Node3D:
	var logical_clock := 0.0
	var ticks := 0
	func _physics_process(delta: float) -> void:
		logical_clock += delta
		ticks += 1
var failures: Array = []
var checks := 0
var main: Node3D
var actor: Counter
var body: RigidBody3D
var timer: Timer
var pause_owner: RefCounted
var refuse_kind := ""
var support_ok := true
var injected_reentry := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func admit(request: Dictionary) -> bool:
	return request.owner_id == main.get_instance_id() and actor.get_meta("life_generation") == 2 and body.get_meta("life_generation") == 3
func support(receipt: Dictionary, objects: Dictionary, ground: Dictionary) -> bool:
	return support_ok and receipt.owner_id == main.get_instance_id() and objects.get("map_id") == "actual-test" and ground.get("source") == "actual-test"
func ready(_receipt: Dictionary) -> bool: return support_ok
func ground() -> Dictionary: return {"source": "actual-test"}
func step(event: Dictionary) -> bool:
	if not injected_reentry:
		injected_reentry = true
		check(not pause_owner.pause_gameplay(event.request).ok, "Reentrant partial pause refused")
		check(not pause_owner.cancel_pause(event.request).ok, "Reentrant partial cancellation refused")
	return event.kind != refuse_kind
func config(owner: RefCounted) -> Dictionary:
	return owner.configure(main, [{"node": main, "stop_input": false}, {"node": actor, "identity": {"actor_id": "actual-actor", "life_generation": 2}, "fields": ["logical_clock", "ticks"]}, {"node": timer}], [{"node": body, "identity": {"vehicle_id": "actual-vehicle", "life_generation": 3}}], {"admit_pause": admit, "validate_resume": support, "transaction_ready": ready, "ground_patch": ground, "pause_step": step})
func request(id: String) -> Dictionary: return {"owner_id": main.get_instance_id(), "request_id": id}
func run() -> void:
	main = Node3D.new()
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	main.set_process_input(true) # Independent editor router must stay active.
	actor = Counter.new()
	main.add_child(actor)
	actor.set_meta("actor_id", "actual-actor")
	actor.set_meta("life_generation", 2)
	actor.set_process_input(true)
	actor.set_process_unhandled_input(true)
	body = RigidBody3D.new()
	main.add_child(body)
	body.set_meta("vehicle_id", "actual-vehicle")
	body.set_meta("life_generation", 3)
	body.gravity_scale = 0
	body.linear_velocity = Vector3(2, 0, 0)
	body.angular_velocity = Vector3(0, 0.4, 0)
	body.collision_layer = 5
	body.collision_mask = 7
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	timer = Timer.new()
	main.add_child(timer)
	timer.wait_time = 5
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.start()
	await physics_frame
	await physics_frame
	pause_owner = Pause.new()
	check(config(pause_owner).ok, "Explicit actual Node and RigidBody owners admitted")
	var frame := body.global_transform
	var velocity := body.linear_velocity
	var angular := body.angular_velocity
	var clock := actor.logical_clock
	var ticks := actor.ticks
	var sleeping := body.sleeping
	var timer_left := timer.time_left
	var result: Dictionary = pause_owner.pause_gameplay(request("first"))
	check(result.ok and pause_owner.verify_pause(result.receipt), "Native freeze and input flags produce owned receipt")
	check(main.is_processing_input() and not main.is_processing() and not actor.is_physics_processing() and not actor.is_processing_unhandled_input(), "Independent router survives; exact gameplay flags suspended")
	check(not pause_owner.transaction_ready(result.receipt), "No same-frame native physics barrier admission")
	for i in 5: await physics_frame
	check(body.global_transform.is_equal_approx(frame) and body.linear_velocity.is_equal_approx(velocity) and body.angular_velocity.is_equal_approx(angular), "Actual RigidBody pose and velocities stable across five physics frames")
	check(actor.logical_clock == clock and actor.ticks == ticks, "Actual physics-driven actor clock stops")
	check(timer.paused and is_equal_approx(timer.time_left, timer_left), "Real Timer internal physics clock is paused without restart")
	check(pause_owner.verify_pause(result.receipt) and pause_owner.transaction_ready(result.receipt), "Verified lease crosses real physics frame barrier")
	support_ok = false
	check(not pause_owner.resume_gameplay(result.receipt, {"map_id": "actual-test"}, ground()).ok and body.freeze and not actor.is_physics_processing(), "Missing real support/transaction admission cannot resume bodies")
	support_ok = true
	check(pause_owner.resume_gameplay(result.receipt, {"map_id": "actual-test"}, ground()).ok, "Explicit owner-admitted resume succeeds")
	check(not body.freeze and body.sleeping == sleeping and body.linear_velocity.is_equal_approx(velocity) and body.angular_velocity.is_equal_approx(angular) and body.collision_layer == 5 and body.collision_mask == 7, "Exact body original freeze/sleep/velocity/filter restored")
	check(actor.is_physics_processing() and actor.is_processing_input() and actor.is_processing_unhandled_input() and not main.is_processing() and not main.is_physics_processing(), "Previously disabled main flags remain disabled; actor flags restored")
	check(not timer.paused and is_equal_approx(timer.time_left, timer_left) and timer.wait_time == 5, "Timer prior paused flag and partial phase restored exactly")
	for i in 2: await physics_frame
	check(actor.ticks > ticks and not body.global_transform.is_equal_approx(frame), "Real simulation resumes after owned restoration")
	refuse_kind = "body"
	injected_reentry = false
	var partial_request := request("partial")
	var partial: Dictionary = pause_owner.pause_gameplay(partial_request)
	check(not partial.ok and pause_owner.state().fault and body.freeze and not actor.is_physics_processing(), "Failure after actual partial body freeze retains fault and captured state")
	check(pause_owner.cancel_pause(partial_request).ok and not body.freeze and actor.is_physics_processing(), "Cancellation restores partial real pause, not all-true defaults")
	refuse_kind = ""
	var lifetime_request := request("lifetime")
	result = pause_owner.pause_gameplay(lifetime_request)
	check(result.ok, "Second lifetime-bound receipt acquired")
	actor.set_meta("life_generation", 99)
	check(not pause_owner.verify_pause(result.receipt) and not pause_owner.cancel_pause(lifetime_request).ok and body.freeze and not actor.is_physics_processing(), "Generation replacement refuses exact rollback without unfreezing surviving bodies")
	actor.set_meta("life_generation", 2)
	var elsewhere := Node3D.new()
	root.add_child(elsewhere)
	body.reparent(elsewhere)
	check(not pause_owner.cancel_pause(lifetime_request).ok and body.freeze, "Body reparenting cannot be hidden by successful rollback")
	body.reparent(main)
	check(pause_owner.cancel_pause(lifetime_request).ok and not pause_owner.state().fault and not body.freeze, "Explicit owner repair permits exact cancellation retry")
	check(not pause_owner.verify_pause(result.receipt), "Completed receipt cannot be replayed")
	main.free()
	elsewhere.free()
	print(JSON.stringify({"suite": "scene-pause-owner", "checks": checks, "failures": failures, "nativeBodies": 1, "wholeGamePauseVerified": false}))
	quit(0 if failures.is_empty() else 1)
