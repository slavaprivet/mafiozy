extends SceneTree
## Real native sedan + host lifecycle, without root scene or GPU.

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const Host = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks_host_candidate.gd")
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
	var profile_id := "city_hatchback" if OS.get_cmdline_user_args().has("--hatchback") else "compact_sedan"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(parsed is Dictionary, "descriptors load")
	if not parsed is Dictionary:
		_finish({})
		return
	var profile: Dictionary = {}
	for row: Dictionary in parsed.get("profiles", []):
		if str(row.get("profile_id", "")) == profile_id:
			profile = row
			break
	_check(not profile.is_empty(), "actual source profile")
	if profile.is_empty():
		_finish({})
		return
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.set_meta("vehicle_surface_id", "road")
	var floor_collision := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(80, 0.5, 200)
	floor_collision.shape = slab
	floor_collision.position.y = -0.25
	floor.add_child(floor_collision)
	world.add_child(floor)
	var body = Factory.new().spawn_from_descriptor({
		"vehicle_id": "tyre-host-sedan", "life_generation": 1,
		"profile_id": profile_id, "source_clock": 1,
		"active": true, "position_m": Vector3(0, 0, 40), "yaw_rad": 0.0,
	}, profile)
	_check(body != null, "native body")
	if body == null:
		_finish({})
		return
	world.add_child(body)
	var host := Host.new()
	world.add_child(host)
	_check(host.configure(body), "host configured beside car")
	_check(host.get_parent() == body.get_parent() and host._tracks.top_level,
		"world-space sibling render pool")
	for tick in 120:
		await physics_frame
	_check(int(body.snapshot_state().grounded_wheel_mask) == 15, "supported four rays")
	body.submit_control(1.0, 0.0, 0.0, false, 1)
	for tick in 90:
		await physics_frame
	body.submit_control(0.0, 0.5, 0.0, true, 2)
	for tick in 90:
		await physics_frame
	var stats: Dictionary = host.stats()
	var published: Dictionary = body.snapshot_state()
	_check(stats.configured and int(stats.last_tick) > 0, "host processed native ticks")
	_check(int(published.physics_tick) == body._physics_tick
		and (published.linear_velocity_mps as Vector3).distance_to(body._last_linear_velocity) < 0.000001,
		"direct host tick and velocity match public body publication")
	_check(int(stats.tracks.count) > 0, "host emitted real physical skid marks")
	_check(host._tracks.global_transform.origin.length() < 0.0001,
		"track world frame does not follow moving car")
	var segments := int(stats.tracks.count)
	body.queue_free()
	for tick in 3:
		await physics_frame
	_check(not is_instance_valid(host), "vehicle teardown removes host and marks")
	_finish({"profile_id": profile_id, "segments": segments, "last_tick": stats.last_tick})

func _finish(details: Dictionary) -> void:
	print("NATIVE_VEHICLE_TYRE_TRACKS_HOST_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "details": details,
		"host_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks_host_candidate.gd"),
		"body_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),
	}))
	quit(0 if failures.is_empty() else 1)
