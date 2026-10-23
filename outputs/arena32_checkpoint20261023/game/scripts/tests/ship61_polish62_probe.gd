extends SceneTree
## SHIP62 polish probe (agent Q / QA), headless.
##
## Boots the real castle scene exactly like the game does and exercises the polished
## ship battle end to end:
##   * castle scene load + `preview_ship` host contract;
##   * `host.snapshot()`, `boat.snapshot()` and `model.rigging_snapshot()`;
##   * 30 s of sailing (speed > 4 m/s, live wake / bow wave, heel in a turn);
##   * 11 real broadside shots - one at the castle gate, ten spread over the south
##     wall - measuring bricks detached per hit (target 8..18, at most 1 miss);
##   * per-shot recoil / smoke / shots / last_hit_kind / flight_time and a flight
##     continuity check (the ball must not teleport);
##   * static FPS >= 60 (headless, so no rendering cost: this is the logic/frame floor).
##
## The script itself cannot see Godot's stderr, so the runner greps the captured log
## for `SCRIPT ERROR`; the probe prints its own summary and exits 0/1.
##
## Run:
##   & 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe' `
##     --path 'D:\MafioziCombat31\ship_polish62\game' --headless `
##     --script res://scripts/tests/ship61_polish62_probe.gd

const LOAD_DEADLINE_MS := 240000
const HOST_WAIT_MS := 30000
const DT := 1.0 / 60.0
const SAIL_SECONDS := 30.0
const TURN_FROM_S := 18.0
const TURN_TO_S := 24.0
const WALL_SHOTS := 10
const BLAST_MIN := 8
const BLAST_MAX := 18

var _scene: Node = null
var _castle: Node = null
var _host: Node = null
var _boat: Node3D = null
var _model: Node3D = null
var _cannons: Node = null
var _basin: Node = null

var _checks := 0
var _fails: Array[String] = []
var _skips: Array[String] = []
var _metrics: Dictionary = {}
var _wall_rows: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	print("SHIP62_POLISH_PROBE_START")
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHIP62_POLISH_FAIL scene_missing")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + LOAD_DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true:
			break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("SHIP62_POLISH_FAIL preview_ready_timeout")
		quit(1)
		return
	_castle = _scene.get("preview_castle") as Node
	_check(is_instance_valid(_castle), "preview_castle", str(_castle))

	var host_deadline := Time.get_ticks_msec() + HOST_WAIT_MS
	while Time.get_ticks_msec() < host_deadline:
		_host = _scene.get("preview_ship") as Node
		if is_instance_valid(_host):
			break
		await process_frame
	if not is_instance_valid(_host):
		print("SHIP62_POLISH_FAIL missing_host status=", str(_scene.get("ship_status")))
		quit(2)
		return
	_boat = _host.get("boat") as Node3D
	_model = _host.get("model") as Node3D
	_cannons = _host.get("cannons") as Node
	_basin = _host.get("basin") as Node
	_check(is_instance_valid(_boat), "host.boat", str(_boat))
	_check(is_instance_valid(_model), "host.model", str(_model))
	_check(is_instance_valid(_cannons), "host.cannons", str(_cannons))
	_check(is_instance_valid(_basin), "host.basin", str(_basin))
	print("SHIP62_HOST name=", str(_host.name), " status=", str(_host.get("status")))

	# ---------------------------------------------------------------- snapshots
	_phase_snapshots()
	# ---------------------------------------------------------------- rigging
	_phase_rigging()
	# ---------------------------------------------------------------- sailing
	await _phase_sailing()
	# ---------------------------------------------------------------- shooting
	await _phase_shooting()
	# ---------------------------------------------------------------- FPS floor
	await _phase_fps()

	# ---------------------------------------------------------------- summary
	var fired := int(_metrics.get("shots_fired", 0))
	var ok := _fails.is_empty()
	print("SHIP62_POLISH_SUMMARY ", JSON.stringify({
		"ok": ok,
		"checks": _checks,
		"fails": _fails,
		"skips": _skips,
		"shots_fired": fired,
		"metrics": _metrics,
	}))
	if ok:
		print("SHIP62_POLISH_OK")
		quit(0)
	else:
		print("SHIP62_POLISH_FAIL failed=", JSON.stringify(_fails))
		quit(1)


## ------------------------------------------------------------------ checks
func _check(condition: bool, name: String, detail: String = "") -> bool:
	_checks += 1
	if condition:
		print("SHIP62_CHECK ok   ", name, "  ", detail)
	else:
		_fails.append(name)
		print("SHIP62_CHECK FAIL ", name, "  ", detail)
	return condition


func _skip(name: String, why: String) -> void:
	_skips.append(name)
	print("SHIP62_CHECK skip ", name, "  ", why)


## ------------------------------------------------------------------ 1. snapshots
func _phase_snapshots() -> void:
	print("SHIP62_PHASE snapshots")
	var host_state: Dictionary = _dict(_host.call("snapshot"))
	for key: String in ["water", "ship", "cannons", "hud"]:
		_check(host_state.has(key), "host.snapshot.%s" % key, _type_of(host_state.get(key)))
	var ship: Dictionary = _dict(host_state.get("ship"))
	_check(ship.has("speed"), "host.snapshot.ship.speed", str(ship.get("speed")))
	_check(ship.has("position"), "host.snapshot.ship.position", str(ship.get("position")))
	var boat_state: Dictionary = _dict(_boat.call("snapshot"))
	_check(not boat_state.is_empty(), "boat.snapshot()", str(boat_state.size()) + " keys")
	for key: String in ["speed", "position", "roll", "pitch", "heading"]:
		_check(boat_state.has(key), "boat.snapshot.%s" % key, _type_of(boat_state.get(key)))
	var cannon_state: Dictionary = _dict(_cannons.call("snapshot"))
	_check(bool(cannon_state.get("ok", false)), "cannons.snapshot.ok",
		str(cannon_state.get("ok")))
	_metrics["snapshot_keys"] = host_state.keys()


## ------------------------------------------------------------------ 2. rigging
func _phase_rigging() -> void:
	print("SHIP62_PHASE rigging")
	if not _model.has_method("rigging_snapshot"):
		_check(false, "model.rigging_snapshot()", "method missing (R delivers it)")
		_metrics["rigging"] = {}
		return
	var rig: Dictionary = _dict(_model.call("rigging_snapshot"))
	print("SHIP62_RIGGING ", JSON.stringify(rig))
	_metrics["rigging"] = rig
	var ropes := _first_int(rig, ["ropes", "rope_count", "trosses", "cables", "lines"])
	var segments := _first_int(rig, ["segments", "segment_count", "segments_total"])
	var flags := _first_int(rig, ["flags", "flag_count", "flags_total", "ensigns"])
	var live := _first_int(rig, ["live", "live_ropes", "animated"])
	_check(ropes >= 8 and ropes <= 14, "rigging.ropes 8..14", str(ropes))
	_check((segments >= ropes * 5) if ropes > 0 else (segments > 0),
		"rigging.segments >= ropes*5", "%d seg / %d ropes" % [segments, ropes])
	_check(flags >= 4, "rigging.flags >= 4", str(flags))
	if live >= 0:
		_check(live >= 8, "rigging.live_ropes >= 8", str(live))
	else:
		_skip("rigging.live_ropes", "no explicit live counter; ropes counted total")
	var hull_dark: Variant = null
	if _model.has_method("hull_dark"):
		hull_dark = _model.call("hull_dark")
	elif _model.get("hull_dark") != null:
		hull_dark = _model.get("hull_dark")
	if hull_dark != null:
		print("SHIP62_HULL_DARK ", str(hull_dark))
		_metrics["hull_dark"] = hull_dark
	else:
		_skip("hull_dark", "optional API not exposed; judged on the after_ shots")


## ------------------------------------------------------------------ 3. sailing
func _phase_sailing() -> void:
	print("SHIP62_PHASE sailing")
	if not is_instance_valid(_boat):
		return
	if _boat.has_method("set_autopilot"):
		_boat.call("set_autopilot", false)
	var level := _water_level()
	_boat.call("moor", Vector3(58.0, level, 994.0), deg_to_rad(-90.0))
	_boat.call("set_sails", true)
	var start_state: Dictionary = _dict(_boat.call("snapshot"))
	var start_pos: Vector3 = _vector(start_state.get("position"), Vector3.ZERO)

	var max_speed := 0.0
	var final_speed := 0.0
	var wake_peak := 0.0
	var bow_peak := 0.0
	var roll_straight := 0.0
	var roll_turn := 0.0
	var wake_seen := false
	var bow_seen := false
	var blocked := false
	var heading_before := 0.0
	var heading_after := 0.0
	var samples := 0
	var steps := int(round(SAIL_SECONDS / DT))
	var turn_from := int(round(TURN_FROM_S / DT))
	var turn_to := int(round(TURN_TO_S / DT))
	for i: int in steps:
		if i < turn_from:
			_boat.call("steer", 0.0)
		elif i < turn_to:
			_boat.call("steer", 1.0)
		else:
			_boat.call("steer", 0.0)
		if i == turn_from - 6:
			heading_before = _heading(_dict(_boat.call("snapshot")))
		_boat.call("simulate_step", DT)
		if i % 5 != 0:
			continue
		var snap: Dictionary = _dict(_boat.call("snapshot"))
		samples += 1
		var speed := float(snap.get("speed", 0.0))
		final_speed = speed
		max_speed = maxf(max_speed, speed)
		blocked = blocked or bool(snap.get("blocked_water", false))
		if snap.has("wake_strength"):
			wake_seen = true
			if speed > 4.0:
				wake_peak = maxf(wake_peak, _amount(snap.get("wake_strength")))
		if snap.has("bow_wave"):
			bow_seen = true
			if speed > 4.0:
				bow_peak = maxf(bow_peak, _amount(snap.get("bow_wave")))
		var roll := absf(float(snap.get("roll", 0.0)))
		if i < turn_from:
			roll_straight = maxf(roll_straight, roll)
		elif i < turn_to:
			roll_turn = maxf(roll_turn, roll)
		if i == turn_to - 6:
			heading_after = _heading(snap)
	# A short real-frame tail: fields computed in _process (wake mesh, flag wave)
	# have a chance to publish themselves.
	_boat.call("set_autopilot", true)
	for _f: int in 90:
		await process_frame
		var live_snap: Dictionary = _dict(_boat.call("snapshot"))
		var live_speed := float(live_snap.get("speed", 0.0))
		if live_snap.has("wake_strength"):
			wake_seen = true
			if live_speed > 4.0:
				wake_peak = maxf(wake_peak, _amount(live_snap.get("wake_strength")))
		if live_snap.has("bow_wave"):
			bow_seen = true
			if live_speed > 4.0:
				bow_peak = maxf(bow_peak, _amount(live_snap.get("bow_wave")))
		roll_turn = maxf(roll_turn, absf(float(live_snap.get("roll", 0.0))))
		final_speed = live_speed
	_boat.call("set_sails", false)
	_boat.call("steer", 0.0)
	_boat.call("set_autopilot", false)
	var end_state: Dictionary = _dict(_boat.call("snapshot"))
	var end_pos: Vector3 = _vector(end_state.get("position"), Vector3.ZERO)
	var turned := absf(wrapf(heading_after - heading_before, -PI, PI))
	var heel_delta := roll_turn - roll_straight

	print("SHIP62_SAIL max_speed=%.2f final_speed=%.2f travelled=%.1f wake=%.3f bow=%.3f roll_straight=%.4f roll_turn=%.4f turned_deg=%.1f blocked=%s"
		% [max_speed, final_speed, Vector2(end_pos.x - start_pos.x, end_pos.z - start_pos.z).length(),
		wake_peak, bow_peak, roll_straight, roll_turn, rad_to_deg(turned), str(blocked)])
	_metrics["sail"] = {
		"max_speed": snappedf(max_speed, 0.01),
		"final_speed": snappedf(final_speed, 0.01),
		"travelled_m": snappedf(Vector2(end_pos.x - start_pos.x, end_pos.z - start_pos.z).length(), 0.1),
		"wake_peak": snappedf(wake_peak, 0.001),
		"bow_wave_peak": snappedf(bow_peak, 0.001),
		"roll_straight_max": snappedf(roll_straight, 0.0001),
		"roll_turn_max": snappedf(roll_turn, 0.0001),
		"heel_delta": snappedf(heel_delta, 0.0001),
		"turned_deg": snappedf(rad_to_deg(turned), 0.1),
		"blocked_water": blocked,
		"samples": samples,
	}
	_check(max_speed > 4.0, "sail.speed > 4 m/s", "max %.2f" % max_speed)
	_check(wake_seen, "sail.snapshot.wake_strength field", str(wake_seen))
	_check(wake_peak > 0.0, "sail.wake_strength > 0 while moving", "peak %.3f" % wake_peak)
	_check(bow_seen, "sail.snapshot.bow_wave field", str(bow_seen))
	_check(bow_peak > 0.0, "sail.bow_wave > 0 while moving", "peak %.3f" % bow_peak)
	_check(rad_to_deg(turned) >= 5.0, "sail.turn changes heading >= 5 deg",
		"%.1f deg" % rad_to_deg(turned))
	_check(roll_turn > 0.015, "sail.heel in a turn > 0.015 rad (~0.9 deg)",
		"turn %.4f rad / straight %.4f rad" % [roll_turn, roll_straight])


## ------------------------------------------------------------------ 4. shooting
func _phase_shooting() -> void:
	print("SHIP62_PHASE shooting")
	if not is_instance_valid(_cannons) or not is_instance_valid(_castle):
		return
	var level := _water_level()

	# --- Gate shot: moor across the bay so the port battery bears on the gate.
	_boat.call("moor", Vector3(30.0, level, 1000.0), deg_to_rad(-47.0))
	await _settle(3)
	var gate_point := Vector3(0.0, 6.0, 968.3)
	var gate_before: Dictionary = _castle_stats()
	var gate_hit: Dictionary = await _fire_one(gate_point, "gate", true)
	var gate_after: Dictionary = _castle_stats()
	var gate_boards_before := int(gate_before.get("gate_boards_broken", 0))
	var gate_boards_after := int(gate_after.get("gate_boards_broken", 0))
	var gate_delta := gate_boards_after - gate_boards_before
	var gate_detached := int(gate_after.get("gate_leaves_detached", 0)) \
		- int(gate_before.get("gate_leaves_detached", 0))
	var gate_ok := gate_delta > 0 or gate_detached > 0 or bool(gate_after.get("gate_open", false))
	print("SHIP62_GATE boards_before=%d boards_after=%d leaves_detached=%d open=%s"
		% [gate_boards_before, gate_boards_after, gate_detached, str(gate_after.get("gate_open", false))])
	_metrics["gate"] = {
		"boards_delta": gate_delta,
		"leaves_detached": gate_detached,
		"open": bool(gate_after.get("gate_open", false)),
		"impact": gate_hit.get("impact_type", ""),
		"blast_detached": gate_hit.get("blast_detached", -1),
	}
	_check(gate_ok, "gate hit breaks boards / opens the gate",
		"boards %+d, leaves %+d" % [gate_delta, gate_detached])

	# --- Ten wall shots: two rows, each row fired from a mooring that keeps every
	# target inside the +/-32 deg broadside arc. Points are 4 m apart so a fresh
	# hole never swallows the next ball.
	var rows := [
		{"moor": Vector3(58.0, level, 994.0), "yaw": -90.0, "y": 5.0,
			"xs": [48.0, 52.0, 56.0, 60.0, 64.0]},
		{"moor": Vector3(30.0, level, 994.0), "yaw": -90.0, "y": 10.0,
			"xs": [20.0, 24.0, 28.0, 32.0, 36.0]},
	]
	var blast_values: Array[int] = []
	var total_values: Array[int] = []
	var misses := 0
	var hit_gate_or_door := 0
	var index := 0
	for row: Dictionary in rows:
		_boat.call("moor", row["moor"], deg_to_rad(float(row["yaw"])))
		await _settle(3)
		for x: float in (row["xs"] as Array):
			var point := Vector3(x, float(row["y"]), 968.0)
			var shot: Dictionary = await _fire_one(point, "wall_%d" % index, index == 0)
			index += 1
			var impact_type := str(shot.get("impact_type", ""))
			if impact_type != "castle":
				misses += 1
			var blast := int(shot.get("blast_detached", -1))
			if blast >= 0:
				blast_values.append(blast)
			var total := int(shot.get("total_delta", -1))
			if total >= 0:
				total_values.append(total)
			var gate_delta_shot := int(shot.get("gate_boards_delta", 0))
			if gate_delta_shot > 0:
				hit_gate_or_door += 1
			_wall_rows.append({"i": index - 1, "target": str(point), "kind": impact_type,
				"blast": blast, "total": total})
			print("SHIP62_SHOT i=%d target=%s kind=%s blast=%d total=%d flight=%.3f last_hit_kind=%s"
				% [index - 1, str(point), impact_type, blast, total,
				float(shot.get("flight_time", 0.0)), str(shot.get("last_hit_kind", ""))])
			await _wait_real(0.35)

	var blast_avg := _avg(blast_values)
	var blast_min := _min(blast_values)
	var blast_max := _max(blast_values)
	var total_avg := _avg(total_values)
	var hits := WALL_SHOTS - misses
	print("SHIP62_WALL shots=%d hits=%d misses=%d blast_avg=%.2f min=%d max=%d total_avg=%.2f"
		% [WALL_SHOTS, hits, misses, blast_avg, blast_min, blast_max, total_avg])
	_metrics["wall"] = {
		"shots": WALL_SHOTS,
		"hits": hits,
		"misses": misses,
		"blast_values": blast_values,
		"blast_avg": snappedf(blast_avg, 0.01),
		"blast_min": blast_min,
		"blast_max": blast_max,
		"total_delta_values": total_values,
		"total_avg": snappedf(total_avg, 0.01),
		"gate_or_door_hits": hit_gate_or_door + (1 if gate_ok else 0),
		"rows": _wall_rows,
	}
	_check(misses <= 1, "wall.misses <= 1", "%d of %d" % [misses, WALL_SHOTS])
	_check(blast_avg >= BLAST_MIN and blast_avg <= BLAST_MAX,
		"wall.blast_avg in 8..18", "%.2f (min %d / max %d)" % [blast_avg, blast_min, blast_max])
	_check(hit_gate_or_door + (1 if gate_ok else 0) >= 1, "at least one gate/door hit",
		"gate_ok=%s extra=%d" % [str(gate_ok), hit_gate_or_door])

	# --- Firing-cycle fields are judged on the first instrumented shot.
	var first: Dictionary = gate_hit
	_check(bool(first.get("shot_ok", false)), "fire.ok", str(first.get("reason", "")))
	_check(bool(first.get("recoil_present", false)), "cannon.state.recoil field", "")
	_check(float(first.get("recoil_peak", 0.0)) > 0.01, "cannon.recoil > 0 after fire",
		"%.3f" % float(first.get("recoil_peak", 0.0)))
	_check(bool(first.get("smoke_present", false)), "cannon.state.smoke field", "")
	_check(float(first.get("smoke_peak", 0.0)) > 0.0, "cannon.smoke alive after fire",
		"%.3f" % float(first.get("smoke_peak", 0.0)))
	_check(int(first.get("shots_delta", 0)) == 1, "cannon.shots increments by 1",
		str(first.get("shots_delta", 0)))
	_check(bool(first.get("flight_time_present", false)), "cannon.state.flight_time field", "")
	_check(float(first.get("flight_time", 0.0)) > 0.0, "cannon.flight_time > 0",
		"%.3f s" % float(first.get("flight_time", 0.0)))
	_check(bool(first.get("last_hit_kind_present", false)), "cannon.state.last_hit_kind field", "")
	_check(not str(first.get("last_hit_kind", "")).is_empty(), "cannon.last_hit_kind non-empty",
		str(first.get("last_hit_kind", "")))
	_check(bool(first.get("ball_seen", false)), "projectile was observed in flight", "")
	_check(float(first.get("sample_speed_max", 0.0)) <= 80.0,
		"projectile does not teleport (sample speed <= 80 m/s)",
		"%.1f m/s" % float(first.get("sample_speed_max", 0.0)))
	_metrics["cycle"] = first.duplicate(true)
	(_metrics["cycle"] as Dictionary)["target"] = str(first.get("target", Vector3.ZERO))
	_metrics["shots_fired"] = 1 + WALL_SHOTS
	print("SHIP62_CYCLE ", JSON.stringify({
		"recoil_peak": first.get("recoil_peak", 0.0),
		"smoke_peak": first.get("smoke_peak", 0.0),
		"shots_delta": first.get("shots_delta", 0),
		"flight_time": first.get("flight_time", 0.0),
		"last_hit_kind": first.get("last_hit_kind", ""),
		"ball_seen": first.get("ball_seen", false),
		"sample_speed_max": first.get("sample_speed_max", 0.0),
		"samples": first.get("flight_samples", 0),
	}))


## Fire one real ball at `point` through the cannon QA hook and watch the whole cycle.
func _fire_one(point: Vector3, label: String, instrument: bool) -> Dictionary:
	var before_stats: Dictionary = _castle_stats()
	var state0: Dictionary = _dict(_cannons.call("state"))
	var shots0 := int(state0.get("shots", 0))
	var out := {
		"label": label,
		"target": str(point),
		"shot_ok": false,
		"impact_type": "",
		"blast_detached": -1,
		"total_delta": -1,
		"gate_boards_delta": 0,
		"flight_time": 0.0,
		"flight_time_present": false,
		"last_hit_kind": "",
		"last_hit_kind_present": false,
		"recoil_present": false,
		"recoil_peak": 0.0,
		"smoke_present": false,
		"smoke_peak": 0.0,
		"shots_delta": 0,
		"ball_seen": false,
		"flight_samples": 0,
		"sample_speed_max": 0.0,
	}
	var fired: Dictionary = _dict(_cannons.call("debug_fire_at", point))
	out["shot_ok"] = bool(fired.get("ok", false))
	out["reason"] = str(fired.get("reason", ""))
	if not out["shot_ok"]:
		print("SHIP62_FIRE_FAIL ", label, " reason=", out["reason"], " target=", point)
		return out
	var expect := shots0 + 1
	var state: Dictionary = _dict(_cannons.call("state"))
	out["recoil_present"] = state.has("recoil")
	out["smoke_present"] = state.has("smoke")
	out["recoil_peak"] = _amount(state.get("recoil"))
	out["smoke_peak"] = _amount(state.get("smoke"))
	var impact: Dictionary = {}
	var last_pos := Vector3.ZERO
	var last_age := 0.0
	var have_pos := false
	var max_sample_speed := 0.0
	var flight_samples := 0
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		state = _dict(_cannons.call("state"))
		if instrument:
			out["recoil_peak"] = maxf(float(out["recoil_peak"]), _amount(state.get("recoil")))
			out["smoke_peak"] = maxf(float(out["smoke_peak"]), _amount(state.get("smoke")))
		var ball: Node = _active_ball()
		if is_instance_valid(ball):
			out["ball_seen"] = true
			var pos: Vector3 = ball.global_position
			var age := float(ball.get("age"))
			if have_pos and age > last_age + 1.0e-4:
				var sample_speed: float = pos.distance_to(last_pos) / (age - last_age)
				max_sample_speed = maxf(max_sample_speed, sample_speed)
				flight_samples += 1
			last_pos = pos
			last_age = age
			have_pos = true
		var li: Dictionary = _dict(state.get("last_impact"))
		var li_id := str(li.get("event_id", ""))
		if int(state.get("shots", 0)) >= expect and li_id == "ship-cannon:%d" % expect:
			impact = li
			if int(state.get("balls_active", 0)) == 0:
				break
	out["sample_speed_max"] = snappedf(max_sample_speed, 0.1)
	out["flight_samples"] = flight_samples
	if not impact.is_empty():
		out["impact_type"] = str(impact.get("type", ""))
		var result: Dictionary = _dict(impact.get("result"))
		out["blast_detached"] = int(result.get("detached", -1))
	out["shots_delta"] = int(state.get("shots", 0)) - shots0
	out["flight_time_present"] = state.has("flight_time")
	out["flight_time"] = float(state.get("flight_time", 0.0))
	out["last_hit_kind_present"] = state.has("last_hit_kind")
	out["last_hit_kind"] = str(state.get("last_hit_kind", ""))
	await _wait_real(1.8)
	var after_stats: Dictionary = _castle_stats()
	out["total_delta"] = int(after_stats.get("detached", 0)) - int(before_stats.get("detached", 0))
	out["gate_boards_delta"] = int(after_stats.get("gate_boards_broken", 0)) \
		- int(before_stats.get("gate_boards_broken", 0))
	out["castle_detached_total"] = int(after_stats.get("detached", 0))
	return out


## ------------------------------------------------------------------ 5. FPS floor
func _phase_fps() -> void:
	print("SHIP62_PHASE fps")
	for _f: int in 60:
		await process_frame
	var fps := Engine.get_frames_per_second()
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	print("SHIP62_FPS fps=%d draw_calls=%d objects=%d physics_ms=%.2f process_ms=%.2f headless=%s"
		% [fps, draw_calls, objects, physics_ms, process_ms, str(DisplayServer.get_name())])
	_metrics["fps"] = fps
	_metrics["draw_calls"] = draw_calls
	_metrics["objects"] = objects
	_metrics["physics_ms"] = snappedf(physics_ms, 0.01)
	_metrics["process_ms"] = snappedf(process_ms, 0.01)
	_check(fps >= 60, "static fps >= 60", str(fps))
	print("SHIP62_SCRIPT_ERRORS 0 expected: the runner scans the captured stderr for the engine marker")


## ------------------------------------------------------------------ helpers
func _castle_stats() -> Dictionary:
	if is_instance_valid(_castle) and _castle.has_method("get_stats"):
		return _dict(_castle.call("get_stats"))
	return {}


func _active_ball() -> Node:
	var balls: Variant = _cannons.get("_balls")
	if balls is Array:
		for item: Variant in (balls as Array):
			if is_instance_valid(item) and bool((item as Node).get("active")):
				return item as Node
	return null


func _water_level() -> float:
	if is_instance_valid(_basin) and _basin.has_method("water_level"):
		return float(_basin.call("water_level"))
	return -0.55


func _heading(snapshot: Dictionary) -> float:
	var value: Variant = snapshot.get("heading")
	if value is float or value is int:
		return float(value)
	return 0.0


func _settle(frames: int) -> void:
	for _i: int in frames:
		await process_frame


func _wait_real(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _vector(value: Variant, fallback: Vector3) -> Vector3:
	return value as Vector3 if value is Vector3 else fallback


func _amount(value: Variant) -> float:
	if value == null:
		return 0.0
	if value is bool:
		return 1.0 if bool(value) else 0.0
	if value is int:
		return float(int(value))
	if value is float:
		return float(value)
	if value is Array:
		return float((value as Array).size())
	if value is Dictionary:
		return float((value as Dictionary).size())
	return 0.0


func _first_int(source: Dictionary, keys: Array) -> int:
	for key: String in keys:
		var value: Variant = source.get(key)
		if value is int:
			return int(value)
		if value is float:
			return int(value)
		if value is bool:
			return 1 if bool(value) else 0
		if value is Array:
			return (value as Array).size()
	return -1


func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value: Variant in values:
		sum += float(value)
	return sum / float(values.size())


func _min(values: Array) -> int:
	if values.is_empty():
		return -1
	var best := 2147483647
	for value: Variant in values:
		best = mini(best, int(value))
	return best


func _max(values: Array) -> int:
	if values.is_empty():
		return -1
	var best := -2147483648
	for value: Variant in values:
		best = maxi(best, int(value))
	return best


func _type_of(value: Variant) -> String:
	if value == null:
		return "null"
	return type_string(typeof(value))
