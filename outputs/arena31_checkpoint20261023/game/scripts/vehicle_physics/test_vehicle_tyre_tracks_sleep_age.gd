extends SceneTree
## Test-only stale-body-clock regression: visible marks must expire while parked.

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const Host = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks_host_candidate.gd")
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _contact(tick: int, point: Vector3) -> Dictionary:
	return {"vehicle_id": "tyre-sleep-age", "life_generation": 1,
		"physics_tick": tick, "wheel_index": 0, "grounded": true,
		"surface_id": "road", "slip": 1.0,
		"point_world_m": point, "normal_world": Vector3.UP}

func _run() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(source is Dictionary, "source descriptors loaded")
	if not source is Dictionary:
		_finish({})
		return
	var profile: Dictionary = {}
	for row: Dictionary in source.get("profiles", []):
		if str(row.get("profile_id", "")) == "city_hatchback":
			profile = row
			break
	_check(not profile.is_empty(), "actual hatchback profile")
	if profile.is_empty():
		_finish({})
		return
	var world := Node3D.new()
	root.add_child(world)
	var body = Factory.new().spawn_from_descriptor({
		"vehicle_id": "tyre-sleep-age", "life_generation": 1,
		"profile_id": "city_hatchback", "source_clock": 1,
		"active": true, "position_m": Vector3.ZERO, "yaw_rad": 0.0,
	}, profile)
	_check(body != null, "real native body")
	if body == null:
		_finish({})
		return
	world.add_child(body)
	body.freeze = true
	var host := Host.new()
	world.add_child(host)
	_check(host.configure(body), "host attaches to frozen body")
	host.set_physics_process(false)
	var track = host._tracks
	_check(track.step(1.0 / 60.0, 1, 5.0, [_contact(1, Vector3.ZERO)]),
		"first physical-format contact")
	_check(track.step(1.0 / 60.0, 2, 5.0, [_contact(2, Vector3(0, 0, 0.34))]),
		"second physical-format contact")
	_check(int(track.stats().active) == 1, "one visible mark before idle")
	# No new body integration tick: this is the parked/sleeping-body condition.
	host._last_tick = body._physics_tick
	for frame in 660:
		host._physics_process(1.0 / 60.0)
	_check(int(track.stats().active) == 0, "mark expired after eleven idle seconds")
	_check(int(track.stats().last_physics_tick) == 2,
		"idle ageing did not invent a vehicle physics tick")
	var details := {"body_tick": body._physics_tick, "host_tick": host._last_tick,
		"track_tick": track.stats().last_physics_tick,
		"active_after_idle": track.stats().active}
	body.queue_free()
	for frame in 2:
		await physics_frame
	_check(not is_instance_valid(host), "body teardown still clears host")
	_finish(details)

func _finish(details: Dictionary) -> void:
	print("NATIVE_VEHICLE_TYRE_SLEEP_AGE_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"details": details,
		"host_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks_host_candidate.gd"),
		"paged_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks_paged_candidate.gd"),
	}))
	quit(0 if failures.is_empty() else 1)
