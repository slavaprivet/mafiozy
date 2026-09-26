extends SceneTree

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const TRANSPORT := "res://data/transport/vehicle_descriptors.v1.json"
const WARMUP_TICKS := 120
const MEASURE_TICKS := 240
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRANSPORT))
	var compact: Dictionary = {}
	for candidate: Dictionary in document.profiles:
		if candidate.profile_id == "compact_sedan": compact = candidate; break
	check(not compact.is_empty(), "actual compact source profile")
	var report: Array[Dictionary] = []
	for scenario: Dictionary in [
		{"name":"baseline", "count":0, "active":false},
		{"name":"one_active", "count":1, "active":true},
		{"name":"sixteen_active", "count":16, "active":true},
		{"name":"seventy_two_active", "count":72, "active":true},
		{"name":"seventy_two_sleeping", "count":72, "active":false},
	]:
		report.append(await measure_scenario(scenario, compact))
	for row: Dictionary in report:
		check(row.samples == MEASURE_TICKS, str(row.name) + " complete sample window")
		check(is_finite(float(row.physics_process_cpu_ms.p95)), str(row.name) + " finite engine physics CPU")
	print("NATIVE_VEHICLE_CPU_SCALING ", JSON.stringify({"passed":failures.is_empty(), "checks":checks,
		"failures":failures, "engine":Engine.get_version_info().get("string", "unknown"),
		"physics_hz":Engine.physics_ticks_per_second, "warmup_ticks":WARMUP_TICKS,
		"measure_ticks":MEASURE_TICKS, "scenarios":report,
		"qualification":"headless engine physics-process CPU monitor; not render frame time, GPU, LIVE or FPS"}))
	quit(0 if failures.is_empty() else 1)

func measure_scenario(scenario: Dictionary, compact: Dictionary) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.set_meta("vehicle_id", "benchmark-floor")
	floor.set_meta("vehicle_surface_id", "dry_asphalt")
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(160, 0.5, 260)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	floor.add_child(floor_collision)
	world.add_child(floor)
	var factory := Factory.new()
	var bodies: Array[RigidBody3D] = []
	for i in int(scenario.count):
		var x := float(i % 8) * 8.0 - 28.0
		var z := float(i / 8) * 12.0 - 48.0
		var body := factory.spawn_from_descriptor({"vehicle_id":"bench-%s-%d" % [scenario.name, i],
			"life_generation":1, "profile_id":"compact_sedan", "active":true,
			"position_m":{"x":x,"y":0.0,"z":z}, "yaw_rad":0.0, "source_clock":1}, compact)
		body.can_sleep = not bool(scenario.active)
		world.add_child(body)
		bodies.append(body)
	for tick in WARMUP_TICKS:
		await physics_frame
	for body: RigidBody3D in bodies:
		if scenario.active:
			body.submit_control(0.12, 0.0, 0.0, false, 1)
			body.sleeping = false
		else:
			body.sleeping = true
	var samples: Array[float] = []
	var active_objects: Array[float] = []
	for tick in MEASURE_TICKS:
		await physics_frame
		samples.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		active_objects.append(float(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)))
	var result := {"name":scenario.name, "vehicles":scenario.count, "active_requested":scenario.active,
		"samples":samples.size(), "physics_process_cpu_ms":stats(samples), "active_objects":stats(active_objects)}
	world.free()
	await process_frame
	return result

func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":nearest(values, .50), "p95":nearest(values, .95), "max":values[-1] if not values.is_empty() else 0.0}

func nearest(values: Array[float], percentile: float) -> float:
	if values.is_empty(): return 0.0
	return values[clampi(int(ceil(percentile * values.size())) - 1, 0, values.size() - 1)]
