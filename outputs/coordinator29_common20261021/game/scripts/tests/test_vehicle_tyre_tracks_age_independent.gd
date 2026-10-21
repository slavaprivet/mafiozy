extends SceneTree
## Independent partial-expiry/ring and material lifetime review of the CPU proposal.

const Tracks = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks_age_candidate.gd")
const ID := "tyre-age-independent"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _row(tick: int, z: float) -> Dictionary:
	return {"vehicle_id": ID, "life_generation": 1, "physics_tick": tick,
		"wheel_index": 0, "grounded": true, "surface_id": "road",
		"point_world_m": Vector3(0, 0, z), "normal_world": Vector3.UP,
		"slip": 1.0}

func _emit(track: Variant, tick: int, z: float, dt := 0.0) -> void:
	_check(track.step(dt, tick, 12.0, [_row(tick, z)]), "emit admitted " + str(tick))

func _run() -> void:
	var a := Tracks.new()
	var b := Tracks.new()
	root.add_child(a)
	root.add_child(b)
	_check(a.configure(ID, 1) and b.configure(ID, 1), "configure")
	var mat_a: ShaderMaterial = a.multimesh.mesh.surface_get_material(0)
	var mat_b: ShaderMaterial = b.multimesh.mesh.surface_get_material(0)
	_check(mat_a != mat_b and mat_a.shader != mat_b.shader,
		"per-instance material and shader ownership")
	_emit(a, 1, 0.0)
	for i in 600:
		_emit(a, i + 2, float(i + 1) * 0.5)
	_check(a.stats().active == 600 and a.stats().cursor == 600,
		"first chronological cohort")
	_check(a.step(5.0, 603, 0.0, []), "advance 5s")
	for i in 601:
		_emit(a, i + 604, float(i + 601) * 0.5)
	_check(a.stats().active == 1200 and a.stats().cursor == 0,
		"second cohort fills ring")
	_check(a.step(5.0, 1205, 0.0, []), "advance to first expiry")
	_check(a.stats().active == 600 and a.stats().cursor == 0 and
		a._active[0] == 0 and a._active[599] == 0 and
		a._active[600] == 1 and a._active[1199] == 1,
		"only oldest cohort retired")
	for i in 101:
		_emit(a, i + 1206, float(i + 1202) * 0.5)
	_check(a.stats().active == 700 and a.stats().cursor == 100,
		"new cohort enters freed head")
	_check(a.step(5.0, 1307, 0.0, []), "advance to second expiry")
	_check(a.stats().active == 100 and a.stats().cursor == 100 and
		a._active[0] == 1 and a._active[99] == 1 and
		a._active[600] == 0 and a._active[1199] == 0,
		"FIFO skips fresh wrapped cohort")
	_check(a.multimesh.get_instance_custom_data(600).r == 0.0 and
		a.multimesh.get_instance_custom_data(1199).r == 0.0,
		"expired GPU strengths cleared")
	_check(mat_a.get_shader_parameter("elapsed_clock_s") == 15.0 and
		mat_b.get_shader_parameter("elapsed_clock_s") == null,
		"separate uniforms")
	a.clear()
	_check(a.stats().active == 0 and a.stats().cursor == 0 and
		mat_a.get_shader_parameter("elapsed_clock_s") == 0.0,
		"clear resets material clock and ring")
	a.dispose()
	_check(a.multimesh == null and a.stats().disposed and
		b.multimesh != null and not b.stats().disposed,
		"dispose cannot affect sibling")
	b.dispose()
	print("NATIVE_VEHICLE_TYRE_TRACKS_AGE_INDEPENDENT ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"candidate_sha256": FileAccess.get_sha256(
			"res://scripts/vehicle_physics/vehicle_tyre_tracks_age_candidate.gd")}))
	quit(0 if failures.is_empty() else 1)
