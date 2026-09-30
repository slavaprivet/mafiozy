extends SceneTree
## Independent bounded stress check for this isolated prototype, not city FPS.
## Run without --qa/--walk-qa: those flags start the showcase's own test runner.

var demo: Variant
var report: Dictionary = {
	"scope": "Isolated destruction showcase; physics-frame intervals and CPU, NOT city performance. display_server identifies headless versus real GPU run",
	"clock": "Time.get_ticks_usec between physics_frame signals; includes engine frame cap and scheduler waits",
	"phases": {},
	"checks": [],
	"failures": []
}
var finished: bool = false
var largest_piece_count: int = 0
var largest_awake_count: int = 0
var maximum_linear_speed: float = 0.0
var maximum_angular_speed: float = 0.0

func _initialize() -> void:
	_run.call_deferred()

func _finish(code: int) -> void:
	if finished:
		return
	finished = true
	report["passed"] = code == 0
	report["largest_piece_count"] = largest_piece_count
	report["largest_awake_count"] = largest_awake_count
	report["maximum_linear_speed"] = maximum_linear_speed
	report["maximum_angular_speed"] = maximum_angular_speed
	report["static_memory_bytes_end"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	var output = FileAccess.open("res://stress_qa.json", FileAccess.WRITE)
	if output == null:
		push_error("Cannot save destruction stress report")
		code = 1
	else:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("DESTRUCTION_STRESS_QA_", "PASS " if code == 0 else "FAIL ", JSON.stringify(report))
	quit(code)

func _require(condition: bool, message: String) -> bool:
	if condition:
		report.checks.append(message)
		return true
	report.failures.append(message)
	push_error("Destruction stress: " + message)
	_finish(1)
	return false

func _distribution(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	values.sort()
	return {
		"samples": values.size(),
		"p50": values[int(values.size() * .5)],
		"p95": values[mini(values.size() - 1, int(values.size() * .95))],
		"max": values.back()
	}

func _count_awake() -> int:
	var awake: int = 0
	for body in demo.pieces:
		if is_instance_valid(body) and not body.freeze and not body.sleeping:
			awake += 1
	return awake

func _sample_phase(label: String, frames: int) -> void:
	var wall_ms: Array = []
	var physics_cpu_ms: Array = []
	var process_cpu_ms: Array = []
	var awake_samples: Array = []
	var previous_usec: int = Time.get_ticks_usec()
	for frame in range(frames):
		await physics_frame
		if finished:
			return
		var now: int = Time.get_ticks_usec()
		wall_ms.append((now - previous_usec) / 1000.0)
		previous_usec = now
		physics_cpu_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		process_cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var awake: int = _count_awake()
		awake_samples.append(awake)
		largest_awake_count = maxi(largest_awake_count, awake)
		largest_piece_count = maxi(largest_piece_count, demo.pieces.size())
		for body in demo.pieces:
			if not body.freeze:
				maximum_linear_speed = maxf(maximum_linear_speed, body.linear_velocity.length())
				maximum_angular_speed = maxf(maximum_angular_speed, body.angular_velocity.length())
	report.phases[label] = {
		"physics_frame_wall_interval_ms": _distribution(wall_ms),
		"engine_physics_process_cpu_ms": _distribution(physics_cpu_ms),
		"engine_process_cpu_ms": _distribution(process_cpu_ms),
		"awake_bodies": _distribution(awake_samples),
		"piece_count": demo.pieces.size(),
		"pooled_fragment_count": demo.pooled_fragments.size(),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)
	}
	if DisplayServer.get_name() != "headless":
		await process_frame
		demo._check_batches()

func _check_rubble() -> bool:
	var seen: Dictionary = {}
	for body in demo.pieces:
		if not is_instance_valid(body):
			return _require(false, "all active-piece references are valid")
		if seen.has(body.get_instance_id()):
			return _require(false, "active pieces contain no duplicate bodies")
		seen[body.get_instance_id()] = true
		if not body.global_transform.is_finite() or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite():
			return _require(false, "every rubble transform and velocity is finite")
		if body.position.y < -1.0 or body.position.length() > 90.0:
			return _require(false, "rubble stays on the bounded test ground")
	return _require(true, "rubble remains finite, bounded, with unique body references")

func _run() -> void:
	if not _require(not "--qa" in OS.get_cmdline_user_args() and not "--walk-qa" in OS.get_cmdline_user_args() and not "--capture" in OS.get_cmdline_user_args(), "no competing showcase runner requested"):
		return
	create_timer(75.0).timeout.connect(func():
		if not finished:
			report.failures.append("stress runner exceeded 75-second watchdog")
			_finish(2)
	)
	var scene = load("res://showcase.tscn") as PackedScene
	if not _require(scene != null, "showcase scene loads"):
		return
	demo = scene.instantiate()
	root.add_child(demo)
	current_scene = demo
	await process_frame
	await physics_frame
	# Prevent UI/input while retaining the ordinary scene lifecycle.
	demo.qa_mode = true
	DisplayServer.window_set_title("Мафиози — автоматическая проверка разрушений")
	demo.status.text = "Автоматическая проверка. Управление временно отключено."
	for button in demo.action_buttons:
		button.disabled = true
	report["engine"] = Engine.get_version_info().string
	report["display_server"] = DisplayServer.get_name()
	report["engine_max_fps"] = Engine.max_fps
	report["physics_ticks_per_second"] = Engine.physics_ticks_per_second
	var intact_count: int = demo.pieces.size()
	var pool_count: int = demo.pooled_fragments.size()
	var building_nodes: int = demo.building.get_child_count()
	var scene_nodes: int = demo.get_child_count()
	var panels: Array = demo.pieces.filter(func(body): return body.has_meta("fracture_tiles"))
	var expected_split_count: int = intact_count
	for panel in panels:
		expected_split_count += panel.get_meta("fracture_tiles").size() - 1
	report["initial_sections"] = intact_count
	report["wall_panels"] = panels.size()
	report["initial_pool"] = pool_count
	report["expected_all_split_sections"] = expected_split_count
	if not _require(panels.size() == 28 and pool_count > 0, "all 28 architectural wall panels have a bounded fracture pool"):
		return
	await _sample_phase("intact", 60)
	for panel in panels:
		var entrance: bool = String(panel.name).begins_with("Entrance")
		var hit: Vector3 = panel.to_global(Vector3(0, -.37 if entrance else .12, .24))
		demo.explode(hit, 3.0, panel, entrance)
		await physics_frame
	if not _require(demo.pieces.size() == expected_split_count, "all 28 panels split without losing or duplicating fragments"):
		return
	if not _require(demo.pooled_fragments.size() == pool_count and demo.building.get_child_count() == building_nodes, "repeated local impacts allocate no new building nodes or fragment bodies"):
		return
	await _sample_phase("all_panels_locally_breached", 60)
	demo.collapse()
	await _sample_phase("full_%d_section_collapse" % expected_split_count, 360)
	if not _check_rubble():
		return
	for body in demo.pieces:
		if body.freeze and not body.get_meta("parked",false):
			_require(false, "full collapse releases every visible section")
			return
	await _sample_phase("settling_after_full_collapse", 300)
	if not _check_rubble():
		return
	report["settled_awake_count"] = _count_awake()
	if demo.has_method("_park_debris") and not _require(_count_awake() <= 32,"settled rubble has at most32 active bodies; no perpetual whole-pile simulation"):
		return
	# A known small sleeping piece provides a reproducible push case in dense rubble.
	var probe: RigidBody3D
	for body in demo.pieces:
		var size: Vector3 = body.get_meta("section_size")
		if size.x < .7 and size.y < .7:
			probe = body
			break
	if not _require(probe != null, "small rubble probe is available"):
		return
	probe.global_transform = Transform3D(Basis.IDENTITY, Vector3(1, .48, 5.0))
	probe.linear_velocity = Vector3.ZERO
	probe.angular_velocity = Vector3.ZERO
	probe.sleeping = true
	probe.set_meta("pushed_by_walker", false)
	demo.walker.position = Vector3(1, .34, 6.6)
	demo.walker.velocity = Vector3.ZERO
	demo.walk_testing = true
	demo.walk_test_input = Vector3.FORWARD
	var probe_start: Vector3 = probe.position
	await _sample_phase("walking_through_dense_rubble", 210)
	demo.walk_test_input = Vector3.ZERO
	if not _require(demo.walker.position.z < 2.2 and demo.walker.position.y > -.2, "character passes the rubble field into the building footprint"):
		return
	if not _require(probe.get_meta("pushed_by_walker", false) and probe.position.distance_to(probe_start) > .2, "walking wakes and displaces sleeping lightweight rubble"):
		return
	if not _check_rubble():
		return
	if demo.has_method("_park_debris"):
		var small: Array = demo.pieces.filter(func(p): return p.has_meta("panel_center"))
		var lower: RigidBody3D = small[0]
		var upper: RigidBody3D = small[1]
		for body in [lower,upper]:
			demo._wake_debris(body)
			# Isolate this fixture beyond the rubble field, on the large ground plane.
			body.global_transform = Transform3D(Basis.IDENTITY,Vector3(20,.22 if body == lower else .76,0))
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
		await _sample_phase("support_stack_settles",150)
		report["support_upper_before"] = upper.position
		if not _require(upper.position.y > .62,"upper test fragment is genuinely supported above the ground before removal"):
			return
		# The engine may sleep a perfectly balanced pair before our jitter timer.
		# Explicitly establish the parked case whose wake path is being tested.
		for body in [lower,upper]:
			if not _require(body.linear_velocity.length() < .1,"support fixture is physically at rest before parking"):
				return
			body.park_pending = true
			demo._park_debris(body)
		await physics_frame
		if not _require(lower.freeze and upper.freeze and lower.get_meta("parked",false) and upper.get_meta("parked",false),"both support fragments are parked before testing explicit support wake"):
			return
		demo._wake_debris(lower)
		lower.position.x += 2.0 # Remove the support completely, not slide both together.
		lower.linear_velocity = Vector3.ZERO
		await _sample_phase("support_removal_wakes_upper",120)
		report["support_upper_after"] = upper.position
		if not _require(upper.position.y < .53,"moving lower support wakes upper rubble instead of leaving it floating"):
			return
	demo.reset_building()
	await process_frame
	await process_frame
	await _sample_phase("after_reset", 30)
	if not _require(demo.pieces.size() == intact_count and demo.pooled_fragments.size() == pool_count, "reset restores original section and pool counts"):
		return
	if not _require(demo.building.get_child_count() == building_nodes and demo.get_child_count() == scene_nodes, "reset does not grow scene or building node counts"):
		return
	# Pending delayed releases must never hit a newly restored building.
	demo.collapse()
	demo.reset_building()
	await process_frame
	await process_frame
	await _sample_phase("reset_cancels_pending_collapse", 150)
	for body in demo.pieces:
		if not body.freeze:
			_require(false, "old collapse cannot release the restored building")
			return
	if not _require(demo.pieces.size() == intact_count and demo.pooled_fragments.size() == pool_count, "repeated reset keeps resource-pool counts bounded"):
		return
	_finish(0)
