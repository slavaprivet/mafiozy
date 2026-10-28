extends SceneTree
## Isolated physical wheel-to-mark adapter test; no main scene or GPU window.

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const Provider = preload("res://scripts/vehicle_physics/vehicle_tyre_contact_provider.gd")
const Fast = preload("res://scripts/vehicle_physics/vehicle_tyre_contact_provider_fast_candidate.gd")
const Tracks = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks_paged_candidate.gd")
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(parsed is Dictionary, "descriptor JSON")
	if not parsed is Dictionary:
		_finish({})
		return
	var profile: Dictionary = {}
	for row: Dictionary in parsed.get("profiles", []):
		if str(row.get("profile_id", "")) == "compact_sedan":
			profile = row
			break
	_check(not profile.is_empty(), "actual compact sedan profile")
	if profile.is_empty():
		_finish({})
		return
	var floor := StaticBody3D.new()
	floor.set_meta("vehicle_surface_id", "road")
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(80.0, 0.5, 200.0)
	floor_shape.shape = slab
	floor_shape.position.y = -0.25
	floor.add_child(floor_shape)
	root.add_child(floor)
	var body = Factory.new().spawn_from_descriptor({
		"vehicle_id": "tyre-provider-test", "life_generation": 1,
		"profile_id": "compact_sedan", "source_clock": 1,
		"active": true, "position_m": Vector3(0, 0, 40), "yaw_rad": 0.0,
	}, profile)
	_check(body != null, "native sedan created")
	if body == null:
		_finish({})
		return
	root.add_child(body)
	var tracks := Tracks.new()
	root.add_child(tracks) # World sibling, never a child of the moving car.
	_check(tracks.configure("tyre-provider-test", 1), "track identity configured")
	for i in 120:
		await physics_frame
	_check(int(body.snapshot_state().grounded_wheel_mask) == 15, "four physical wheel rays supported")
	var rows: Array[Dictionary] = []
	var fast_rows: Array[Dictionary] = []
	var starting_rays := body.get_child_count()
	var grounded_rows := 0
	var slipping_ticks := 0
	var max_marks := 0
	body.submit_control(1.0, 0.0, 0.0, false, 1)
	for i in 90:
		await physics_frame
		var state: Dictionary = body.snapshot_state()
		var tick := int(state.physics_tick)
		_check(Provider.collect_into(body, tick, rows), "live ray collection tick %d" % i)
		_check(Fast.collect_into(body, tick, fast_rows) and fast_rows == rows,
			"fast candidate parity drive tick %d" % i)
		_check(rows.size() <= 4, "bounded wheel rows tick %d" % i)
		grounded_rows += rows.size()
		var speed := (state.linear_velocity_mps as Vector3).length()
		_check(tracks.step(1.0 / 60.0, tick, speed, rows), "mark step tick %d" % i)
	if body != null:
		body.submit_control(0.0, 0.5, 0.0, true, 2)
	for i in 90:
		await physics_frame
		var state: Dictionary = body.snapshot_state()
		var tick := int(state.physics_tick)
		_check(Provider.collect_into(body, tick, rows), "skid ray collection tick %d" % i)
		_check(Fast.collect_into(body, tick, fast_rows) and fast_rows == rows,
			"fast candidate parity skid tick %d" % i)
		if not rows.is_empty():
			slipping_ticks += 1
		var speed := (state.linear_velocity_mps as Vector3).length()
		_check(tracks.step(1.0 / 60.0, tick, speed, rows), "skid mark step tick %d" % i)
		max_marks = maxi(max_marks, int(tracks.stats().count))
	_check(body.get_child_count() == starting_rays, "provider creates no raycasts or nodes")
	_check(grounded_rows > 0 and slipping_ticks > 0, "actual wheel slip reaches adapter")
	_check(max_marks > 0, "physical skid creates a visible track segment")
	var last_tick := int(body.snapshot_state().physics_tick)
	var benchmark_start := Time.get_ticks_usec()
	for i in 1000:
		Provider.collect_into(body, last_tick, rows)
	var public_first_us := float(Time.get_ticks_usec() - benchmark_start) / 1000.0
	benchmark_start = Time.get_ticks_usec()
	for i in 1000:
		Fast.collect_into(body, last_tick, fast_rows)
	var fast_second_us := float(Time.get_ticks_usec() - benchmark_start) / 1000.0
	benchmark_start = Time.get_ticks_usec()
	for i in 1000:
		Fast.collect_into(body, last_tick, fast_rows)
	var fast_first_us := float(Time.get_ticks_usec() - benchmark_start) / 1000.0
	benchmark_start = Time.get_ticks_usec()
	for i in 1000:
		Provider.collect_into(body, last_tick, rows)
	var public_second_us := float(Time.get_ticks_usec() - benchmark_start) / 1000.0
	_check(not Provider.collect_into(body, last_tick - 1, rows) and rows.is_empty(),
		"stale physics tick rejected without stale rows")
	_check(not Fast.collect_into(body, last_tick - 1, fast_rows) and fast_rows.is_empty(),
		"fast stale physics tick rejected without stale rows")
	floor.set_meta("vehicle_surface_id", "water")
	for i in 3:
		await physics_frame
	_check(Provider.collect_into(body, int(body.snapshot_state().physics_tick), rows)
		and rows.is_empty(), "non-track surface produces no marks")
	_check(Fast.collect_into(body, int(body.snapshot_state().physics_tick), fast_rows)
		and fast_rows == rows, "fast non-track surface parity")
	_finish({"grounded_rows": grounded_rows, "slipping_ticks": slipping_ticks,
		"max_marks": max_marks, "track_stats": tracks.stats(),
		"adapter_mean_us_warm_1000": {"public_first": public_first_us,
			"fast_second": fast_second_us, "fast_first": fast_first_us,
			"public_second": public_second_us}})

func _finish(details: Dictionary) -> void:
	print("NATIVE_VEHICLE_TYRE_CONTACT_PROVIDER_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "details": details,
		"body_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),
		"provider_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_contact_provider.gd"),
		"fast_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_contact_provider_fast_candidate.gd"),
		"tracks_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks_paged_candidate.gd"),
	}))
	quit(0 if failures.is_empty() else 1)
