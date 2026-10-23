extends SceneTree
## Candidate-only CPU/resource contract. No body/provider/main binding and no GPU
## acceptance. Contacts are explicit trusted rows in world metres.

const Tracks = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks.gd")
const SOURCE := "res://../../assets/maps/city_rebuild_v1/tire_tracks.mjs"
const SOURCE_SHA256 := "2be4718fc72d4fb42627004219d6b91f202c7b7aaa78d44bcfcb66b5aebc80b0"
const VEHICLE_ID := "tyre-track-candidate"
const LIFE := 7

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _close(a: float, b: float, tolerance := 0.00001) -> bool:
	return absf(a - b) <= tolerance

func _percentile_us(samples: PackedInt64Array, fraction: float) -> int:
	samples.sort()
	var index := clampi(int(ceil(fraction * samples.size())) - 1, 0, samples.size() - 1)
	return int(samples[index])

func _row(index: int, tick: int, point: Vector3, slip: float,
		surface := "road", grounded := true, normal := Vector3.UP) -> Dictionary:
	return {"vehicle_id": VEHICLE_ID, "life_generation": LIFE,
		"physics_tick": tick, "wheel_index": index, "grounded": grounded,
		"point_world_m": point, "normal_world": normal,
		"surface_id": surface, "slip": slip}

func _four(tick: int, offset_z: float, front_slip: float, rear_slip: float,
		surface := "road") -> Array:
	return [
		_row(0, tick, Vector3(-0.92, 0, 1.30 + offset_z), front_slip, surface),
		_row(1, tick, Vector3(0.92, 0, 1.30 + offset_z), front_slip, surface),
		_row(2, tick, Vector3(-0.92, 0, -1.35 + offset_z), rear_slip, surface),
		_row(3, tick, Vector3(0.92, 0, -1.35 + offset_z), rear_slip, surface),
	]

func _run() -> void:
	_check(FileAccess.get_sha256(SOURCE) == SOURCE_SHA256, "exact tyre-track source receipt")
	_check(Tracks.MAX_SEGMENTS == 1200 and Tracks.LIFETIME_S == 10.0
		and Tracks.SPACING_M == 0.28 and Tracks.WIDTH_M == 0.19,
		"exact source pool, lifetime, spacing and width")
	_check(Tracks.MIN_SLIP == 0.2 and Tracks.MIN_SPEED_MPS == 0.6
		and Tracks.MAX_GAP_M == 3.0 and Tracks.MAX_ALPHA == 0.42,
		"exact source admission and alpha constants")
	var rejected := Tracks.new()
	_check(not rejected.configure("", LIFE) and not rejected.configure(VEHICLE_ID, 0),
		"invalid identity and lifetime fail closed")
	rejected.free()
	var never_configured := Tracks.new()
	never_configured.clear()
	never_configured.dispose()
	_check(never_configured.stats().disposed, "clear and dispose are safe before configuration")
	never_configured.free()
	var tracks := Tracks.new()
	root.add_child(tracks)
	_check(tracks.configure(VEHICLE_ID, LIFE), "exact identity configures once")
	_check(not tracks.configure(VEHICLE_ID, LIFE), "reconfigure is rejected")
	_check(tracks.get_parent() == root, "emitter is a world sibling, not a car child")
	_check(tracks.multimesh != null and tracks.multimesh.instance_count == 1200
		and tracks.multimesh.mesh.surface_get_array_len(0) == 6,
		"one 1200-instance pool uses the exact six-vertex segment")
	_check(tracks.get_child_count() == 0, "emitter has no child raycast or per-segment nodes")
	var track_material := tracks.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	var shader_source := track_material.shader.code
	_check(shader_source.contains("track_color : source_color")
		and shader_source.contains("vec4(0.2039215686, 0.2156862745, 0.1960784314, 1.0)"),
		"track color is authored as exact sRGB #343732 for source_color conversion")
	_check(tracks.step(0.02, 1, 12.0, _four(1, 0.0, 0.0, 1.0)),
		"first trusted wheel frame is accepted")
	_check(tracks.step(0.02, 2, 12.0, _four(2, 0.5, 0.0, 1.0)),
		"second trusted wheel frame is accepted")
	_check(tracks.stats().count == 2 and tracks.stats().active == 2,
		"only the two locked rear wheels leave source marks")
	# The dummy headless renderer does not retain readable MultiMesh instance
	# buffers, so inspect the bounded CPU shadow written by the same emit path.
	var transform: Transform3D = tracks._segment_transforms[0]
	var vertices: PackedVector3Array = tracks.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected := PackedVector3Array([
		Vector3(-1.015, 0.018, -1.35), Vector3(-0.825, 0.018, -1.35), Vector3(-1.015, 0.018, -0.85),
		Vector3(-1.015, 0.018, -0.85), Vector3(-0.825, 0.018, -1.35), Vector3(-0.825, 0.018, -0.85),
	])
	for i in 6:
		_check((transform * vertices[i]).distance_to(expected[i]) < 0.00001,
			"source six-vertex geometry " + str(i))
	_check(_close(tracks._opacities[0], 0.42),
		"source maximum slip alpha")
	var age_before_stale: float = tracks._ages[0]
	_check(not tracks.step(1.25, 2, 0.0, [])
		and _close(tracks._ages[0], age_before_stale),
		"same-tick rejection cannot age active marks")
	tracks.step(5.5, 3, 0.0, [])
	_check(_close(tracks._opacities[0], 0.42),
		"mark remains opaque for first 5.5 seconds")
	tracks.step(2.25, 4, 0.0, [])
	_check(_close(tracks._opacities[0], 0.21, 0.0001),
		"mark fades linearly through final 4.5 seconds")
	tracks.step(2.25, 5, 0.0, [])
	_check(tracks.stats().active == 0 and _close(tracks._opacities[0], 0.0),
		"mark expires at ten seconds")
	tracks.clear()
	tracks.step(0.0, 10, 12.0, [_row(2, 10, Vector3.ZERO, 1.0)])
	tracks.step(0.0, 11, 12.0, [_row(2, 11, Vector3(0, 0, 100), 1.0)])
	_check(tracks.stats().count == 0, "teleport never draws a long segment")
	tracks.step(0.0, 12, 12.0, [_row(2, 12, Vector3(0, 0, 100.5), 0.0)])
	tracks.step(0.0, 13, 12.0, [_row(2, 13, Vector3(0, 0, 101.0), 1.0)])
	_check(tracks.stats().count == 0, "release and reapply do not bridge an unmarked gap")
	tracks.step(0.0, 14, 12.0, [_row(2, 14, Vector3(0, 0, 101.5), 1.0)])
	_check(tracks.stats().count == 1, "reapplied slip starts from a fresh sample")
	tracks.clear()
	tracks.step(0.0, 16, 0.6, [_row(2, 16, Vector3.ZERO, 0.2)])
	tracks.step(0.0, 17, 0.6, [_row(2, 17, Vector3(0, 0, 0.28), 0.2)])
	_check(tracks.stats().count == 1 and _close(tracks._opacities[0], 0.084, 0.0001),
		"source thresholds are inclusive and slip scales alpha")
	tracks.clear()
	var tick := 20
	for surface: String in ["grass", "sand", "water", "default"]:
		tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3(0, 0, tick), 1.0, surface)])
		tick += 1
		tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3(0, 0, tick + 0.5), 1.0, surface)])
		tick += 1
	_check(tracks.stats().count == 0, "grass sand water and unknown surfaces are suppressed")
	for surface: String in ["road", "sidewalk", "bridge"]:
		tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3(0, 0, tick), 1.0, surface)])
		tick += 1
		tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3(0, 0, tick + 0.5), 1.0, surface)])
		tick += 1
		tracks.step(0.0, tick, 12.0, [])
		tick += 1
	_check(tracks.stats().count == 3, "only actual source road sidewalk and bridge enums are admitted")
	tracks.clear()
	tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3.ZERO, 1.0)])
	_check(not tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3(0, 0, 0.5), 1.0)]),
		"stale physics tick is rejected")
	tick += 1
	tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3(0, 0, 1.0), 1.0)])
	_check(tracks.stats().count == 0, "stale tick clears segment continuity")
	tick += 1
	var wrong := _row(2, tick, Vector3(0, 0, 1.5), 1.0)
	wrong.life_generation = LIFE + 1
	_check(not tracks.step(0.0, tick, 12.0, [wrong]), "wrong source lifetime is rejected")
	_check(not tracks.step(NAN, tick + 1, 12.0, [])
		and not tracks.step(0.0, tick + 2, INF, []), "nonfinite frame inputs fail closed")
	var bad_slip := _row(2, tick + 3, Vector3.ZERO, INF)
	var bad_point := _row(2, tick + 4, Vector3(NAN, 0, 0), 1.0)
	var bad_normal := _row(2, tick + 5, Vector3.ZERO, 1.0, "road", true, Vector3.ZERO)
	_check(not tracks.step(0.0, tick + 3, 12.0, [bad_slip])
		and not tracks.step(0.0, tick + 4, 12.0, [bad_point])
		and not tracks.step(0.0, tick + 5, 12.0, [bad_normal]),
		"nonfinite or degenerate trusted contact rows fail closed")
	tracks.clear()
	tick += 20
	tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3.ZERO, 1.0)])
	for i in Tracks.MAX_SEGMENTS + 25:
		tick += 1
		tracks.step(0.0, tick, 12.0, [_row(2, tick, Vector3(0, 0, float(i + 1) * 0.5), 1.0)])
	_check(tracks.stats().count == 1200 and tracks.stats().active == 1200,
		"long skid remains bounded by exact 1200-slot ring")
	for _warmup in 32:
		tick += 1
		tracks.step(0.0, tick, 0.0, [])
	var cpu_samples := PackedInt64Array()
	for _sample in 240:
		tick += 1
		var started_us := Time.get_ticks_usec()
		tracks.step(0.0, tick, 0.0, [])
		cpu_samples.append(Time.get_ticks_usec() - started_us)
	var cpu_p50_us := _percentile_us(cpu_samples.duplicate(), 0.50)
	var cpu_p95_us := _percentile_us(cpu_samples.duplicate(), 0.95)
	_check(tracks.stats().active == 1200 and cpu_p95_us >= cpu_p50_us,
		"warmed CPU sample retains the synthetic 1200-active worst case")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"source_sha256": FileAccess.get_sha256(SOURCE),
		"component_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks.gd"),
		"synthetic_cpu_us_1200_active": {"samples": cpu_samples.size(),
			"p50": cpu_p50_us, "p95": cpu_p95_us,
			"qualification": "warmed headless CPU step cost; not FPS, GPU, provider, main or LIVE"},
		"stats": tracks.stats(),
		"scope": "candidate explicit-contact CPU/resource contract only; provider/body/main/GPU/LIVE remain unwired"}
	print("NATIVE_VEHICLE_TYRE_TRACKS_TEST ", JSON.stringify(report))
	tracks.dispose()
	quit(0 if failures.is_empty() else 1)
