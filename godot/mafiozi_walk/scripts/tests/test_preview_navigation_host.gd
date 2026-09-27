extends SceneTree
const Host = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
var main: Node3D
var interior: Node3D
var body: CharacterBody3D
var host: RefCounted
var queue: RefCounted
var owner: RefCounted
var checks := 0
var failures: Array[String] = []
var reports: Array = []
var permitted := true
var worker_result := ""

func worker_attempt() -> void: worker_result = host.state()

func rejected_attach(label: String) -> void:
	var rejected := Host.new()
	var accepted: bool = rejected.attach_existing(main, interior, main.get("_block"), main.get("_printshop_data"), queue, "test:rejected", 1, 1)
	check(not accepted and rejected.diagnostics().backend.is_empty(), label)
	rejected.dispose()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

# Explicit TEST-only authority for the existing main player. Production host
# contains no equivalent policy and never imports this test.
func trusted_test_admit(point: Vector3, identity: String, generation: int) -> bool:
	if not permitted or identity != "test:existing-main-player" or generation != 1: return false
	if not main.preview_jump_surface_allowed(point, .36): return false
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .40, point - Vector3.UP * .45, 1, [body.get_rid()])
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.normal.y >= .70 and absf(hit.position.y - point.y) <= .30

func wait_map() -> bool:
	var until := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < until:
		await physics_frame; host.pump(Engine.get_physics_frames())
		if host.diagnostics().transitions == 0 and host.diagnostics().backend.state == "READY": return true
	return false

func wait_request(id: int) -> Dictionary:
	var until := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < until:
		await physics_frame; host.pump(Engine.get_physics_frames())
		var status: Dictionary = host.poll(id)
		if status.status != "PENDING": return status
	return {"status": "TIMEOUT"}

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame; await physics_frame
	check(main.preview_ready and main.printshop_status == "ready", "actual main ready")
	if not main.preview_ready: print(JSON.stringify({"failures": failures})); quit(1); return
	interior = main.get("_printshop"); body = main.get("_player")
	# Test takes exclusive control of this EXISTING actor. No replacement physics
	# world, new NPC body or changes to its capsule/floor/safe-margin properties.
	body.set_physics_process(false)
	queue = Queue.new(); host = Host.new()
	var existing_static: StaticBody3D
	for child: Node in main.get_children():
		if child is StaticBody3D and child.has_meta("source_id"): existing_static = child; break
	var duplicate: Node = existing_static.duplicate()
	main.add_child(duplicate)
	rejected_attach("duplicate source collider identity fails closed")
	duplicate.free()
	var collision: CollisionShape3D = existing_static.get_child(0)
	var saved_shape: Shape3D = collision.shape
	collision.shape = CapsuleShape3D.new()
	rejected_attach("unsupported static shape fails closed")
	collision.shape = saved_shape
	var original_position := existing_static.position
	existing_static.position += Vector3.RIGHT
	rejected_attach("changed static source transform fails closed")
	existing_static.position = original_position
	var chosen: Dictionary
	for record: Dictionary in main.get("_block").buildings:
		if record.id != "REBUILD-VISUAL-print_shop-001" and not record.collisionBodiesM.is_empty(): chosen = record.collisionBodiesM[0]; break
	var saved_min: float = chosen.minY
	chosen.minY = NAN
	rejected_attach("nonfinite current source fails closed")
	chosen.minY = saved_min
	var sensor := Area3D.new(); sensor.name = "TestOnlyIgnoredSensor"; main.add_child(sensor)
	var count_before := get_node_count()
	var attached: bool = host.attach_existing(main, interior, main.get("_block"), main.get("_printshop_data"), queue, "test:actual-main-authority", 1, 1)
	check(attached, "actual source geometry attach: " + str(host.diagnostics()))
	check(get_node_count() == count_before, "adapter creates zero scene/physics nodes")
	sensor.free()
	if not attached: print(JSON.stringify({"checks": checks, "failures": failures, "diagnostics": host.diagnostics()})); host.dispose(); main.free(); queue.dispose(); quit(1); return
	check(host.diagnostics().stats.door_shapes == 4, "four existing authored door leaves")
	owner = Queue.Owner.new("test:existing-main-player", 1)
	var worker := Thread.new(); worker.start(worker_attempt); worker.wait_to_finish()
	check(worker_result == "INVALID_THREAD", "worker thread fails closed")
	check(host.request(owner, body, interior.anchor("publicInside"), Callable()) == -1, "trusted admission mandatory")
	var closed_id: int = host.request(owner, body, interior.anchor("publicInside"), trusted_test_admit)
	var duplicate_owner := Queue.Owner.new(owner.source_id, 1)
	check(host.request(duplicate_owner, body, interior.anchor("publicInside"), trusted_test_admit) == -1, "duplicate source owner refused")
	check(host.poll(closed_id).status == "PENDING", "unsynced main map is pending")
	check(await wait_map(), "actual main Recast ready")
	check((await wait_request(closed_id)).status == "NO_PATH", "existing closed door refuses route")
	var acceptance: Dictionary = interior.request_door("public", true, body.global_position, [])
	check(acceptance.accepted, "existing public door request accepted")
	check(host.door_transition_started("public", 1.0), "start invalidates before first actual advance")
	check(host.poll(closed_id).status == "STALE", "old receipt stale immediately")
	check(host.poll(closed_id).source_id == owner.source_id, "stale receipt retains original source ID")
	check(host.request(owner, body, interior.anchor("publicInside"), trusted_test_admit) == -1, "no new route during motion")
	var publications: int = host.diagnostics().stats.publications
	for i in range(30):
		await physics_frame; host.pump(Engine.get_physics_frames())
		if interior.door_fraction("public") >= 1.0: break
		check(host.diagnostics().stats.publications == publications, "no per-fraction bake")
	check(await wait_map(), "stable open door map ready")
	check(host.diagnostics().stats.publications == publications + 1, "exactly one settled-door publication")
	var id: int = host.request(owner, body, interior.anchor("publicInside"), trusted_test_admit)
	check((await wait_request(id)).status == "READY", "actual open main route admitted")
	var original_capsule: Shape3D = body.get_node("PlayerCapsule").shape
	var safe_margin := body.safe_margin; var snap := body.floor_snap_length
	var maximum_step := 0.0; var frames := 0; var blocked := 0
	var timing: Array = []
	for frame in range(1200):
		await physics_frame; host.pump(Engine.get_physics_frames())
		var started := Time.get_ticks_usec()
		var result: Dictionary = host.step(id, 1.0 / 60.0, 2.0, 9.8)
		timing.append(Time.get_ticks_usec() - started)
		frames += 1; maximum_step = maxf(maximum_step, result.get("step_metres", 0.0))
		if result.status == "BLOCKED": blocked += 1
		if result.status == "ARRIVED": break
	check(host.poll(id).status == "ARRIVED", "existing main CharacterBody physically arrives: " + str(body.global_position))
	check(maximum_step < .10, "server path follower never teleports")
	check(body.safe_margin == safe_margin and body.floor_snap_length == snap and body.get_node("PlayerCapsule").shape == original_capsule, "existing body properties preserved")
	timing.sort()
	reports.append({"frames": frames, "blocked": blocked, "max_step": maximum_step, "step_us": {"p50": timing[timing.size() / 2], "p95": timing[int(timing.size() * .95)], "max": timing[-1]}, "end": body.global_position})
	var current_publications: int = host.diagnostics().stats.publications
	permitted = false
	check(host.update_access_version(2), "authority version advances")
	check(host.poll(id).status == "STALE", "access version invalidates arrived receipt")
	check(host.poll(id).access_version == 1 and host.poll(id).current_access_version == 2, "receipt records old and current authority versions separately")
	check(host.diagnostics().stats.publications == current_publications, "access-only version does not rebake")
	var denied: int = host.request(owner, body, interior.anchor("publicApproach"), trusted_test_admit)
	check((await wait_request(denied)).status == "NO_PATH", "current source access blocks native geometry proposal")
	check(not host.update_access_version(2), "stale access version refused")
	check(host.step(denied, 1.0, 2.0, 9.8).status == "INVALID_STEP", "oversize movement time rejected")
	check(host.step(denied, 1.0 / 60.0, NAN, 9.8).status == "INVALID_STEP", "nonfinite movement rejected")
	owner.dead = true
	check(host.poll(denied).status == "CANCELLED", "owner death invalidates native receipt")
	check(host.diagnostics().stats.captures == 1, "static CPU geometry captured once")
	reports.append(host.diagnostics())
	main.free() # tree_exiting must release host before its physics world disappears.
	host.dispose()
	check(host.diagnostics().disposed and host.diagnostics().records == 0, "dispose releases records and is idempotent")
	while host.diagnostics().backend.bakes_inflight > 0: await process_frame
	queue.dispose()
	print(JSON.stringify({"checks": checks, "failures": failures, "reports": reports, "scope": "actual main scene headless, existing player test consumer; no production spawn or FPS claim"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void: run.call_deferred()
