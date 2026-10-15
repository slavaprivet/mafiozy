extends Node
## Owner58 read-only watcher. Every second it prints one JSON line per resident with the
## state a human can check: where it is, what it is doing, why it is stopped, which goal
## and which seat it holds. It never writes to a body, a route, a claim, a clock or the
## population; it only reads fields that already exist.
const PERIOD_MS := 1000
const STILL_M := 0.10
const MAX_LINES := 20000
# DSH_FPS58: frame timing of the running window, sampled every drawn frame. 20000 frames
# cover the longest bounded run at 60 FPS; the report is written next to the run log.
const FRAME_SAMPLES := 20000
var _frame_us := PackedFloat32Array()
var _frame_count := 0
var _out_dir := ""
var _population: RefCounted
var _scene: Node3D
var _at := 0
var _frames := 0
var _lines := 0
var _previous: Dictionary = {}
var _still: Dictionary = {}
# DSH_EXPLAINED58: the worst stop that happened while the life itself wanted motion.
var _stalled_while_walking: Dictionary = {}
var _still_worst := 0.0
var _unsupported_goals := 0
var _seat_refusals := 0
var _frame_report_written := false

func _ready() -> void:
	_scene = get_parent() as Node3D
	_population = _scene.get("preview_population") if _scene != null else null
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt-dir="): _out_dir = argument.trim_prefix("--receipt-dir=")
		elif argument.begins_with("--qa-out="): _out_dir = argument.trim_prefix("--qa-out=")
	print("OWNER58_WATCH ready scene=", is_instance_valid(_scene), " population=", _population != null, " out=", _out_dir)

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_PREDELETE: return
	_write_frame_report()
	_frame_report_written = true

func _write_frame_report() -> void:
	if _frame_count == 0: return
	var sorted_us: Array = []
	for value: float in _frame_us: sorted_us.append(value)
	sorted_us.sort()
	var total := 0.0
	for value: float in sorted_us: total += value
	var report := {
		"schema": "mafiozi.owner58.frames/v1",
		"frames": _frame_count,
		"mean_fps": 1000000.0 / (total / float(_frame_count)),
		"p50_ms": float(sorted_us[mini(_frame_count - 1, int(float(_frame_count) * .50))]) / 1000.0,
		"p95_ms": float(sorted_us[mini(_frame_count - 1, int(float(_frame_count) * .95))]) / 1000.0,
		"p99_ms": float(sorted_us[mini(_frame_count - 1, int(float(_frame_count) * .99))]) / 1000.0,
		"worst_ms": float(sorted_us[-1]) / 1000.0,
		"headless": DisplayServer.get_name() == "headless",
	}
	print("OWNER58_FPS ", JSON.stringify(report))
	if not _out_dir.is_empty():
		var file := FileAccess.open(_out_dir.path_join("FRAMES58.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()

func _process(delta: float) -> void:
	_frames += 1
	if _frame_count < FRAME_SAMPLES:
		_frame_us.append(delta * 1000000.0)
		_frame_count += 1
	elif not _frame_report_written:
		_write_frame_report()
		_frame_report_written = true
	if _population == null:
		if _scene != null: _population = _scene.get("preview_population")
		return
	var now := Time.get_ticks_msec()
	if now < _at: return
	_at = now + PERIOD_MS
	_sample(now)

func _sample(now: int) -> void:
	if _population.get("city_ready") != true: return
	var daily: RefCounted = _population.get("daily")
	if daily == null: return
	var lives: Dictionary = daily.get("_lives")
	if lives == null: return
	var ids: Array = lives.keys(); ids.sort()
	for id: String in ids:
		var life: RefCounted = lives[id]
		if life == null or life.get("_disposed") == true: continue
		if not _population.get("residents").target_current(life.get("_token")): continue
		_line(id, life, now)
	# One summary per sample: a human can see the whole cohort in one place.
	print("OWNER58_SAMPLE ", JSON.stringify({
		"t_ms": now, "residents": ids.size(), "lines": _lines,
		"worst_still_s": _still_worst, "goals_without_standing_point": _unsupported_goals,
		"seat_refusals": _seat_refusals, "peers_pass_through": _passthrough_on()}))

func _line(id: String, life: RefCounted, now: int) -> void:
	var body: CharacterBody3D = life.get("_token").get("body")
	if not is_instance_valid(body): return
	var at: Vector3 = body.global_position
	var moved: float = 0.0
	if _previous.has(id): moved = Vector2(at.x-_previous[id].x, at.z-_previous[id].z).length()
	_previous[id] = at
	if moved < STILL_M:
		_still[id] = float(_still.get(id, 0.0)) + float(PERIOD_MS)/1000.0
	else:
		_still[id] = 0.0
	_still_worst = maxf(_still_worst, float(_still[id]))
	var seat: Dictionary = {}
	var seat_reason := ""
	var seat_nearest_m := -1.0
	if life.get("_leisure58") != null:
		seat = life.get("_leisure58").reserved_slot()
		var snapshot: Dictionary = life.get("_leisure58").snapshot()
		seat_reason = str(snapshot.get("reason", ""))
		seat_nearest_m = float(snapshot.get("nearest_bench_m", -1.0))
	var goal: Dictionary = life.get("_goal")
	var driver: RefCounted = life.get("_roam51")
	var driver_state := {}
	if driver != null:
		driver_state = {"phase": driver._phase, "target_source": driver._target_source,
			"reason": driver.last_reason(), "dist_m": driver.distance_m(),
			"queries": int(driver._route.queries) if driver._route != null else -1,
			"expanded": int(driver._route.expanded) if driver._route != null else -1,
			"goal_supported": driver._last_goal_support58.duplicate(true)}
	var amb: RefCounted = life.get("_ambient29")
	var amb_state: Dictionary = amb.snapshot() if amb != null else {}
	if amb_state.get("active") == true:
		seat = amb_state.get("bench_slot", {})
	# DSH_EXPLAINED58: a quiet body is not a defect by itself. The defect is a body that
	# is asked to move and does not. So the counter runs only while the life itself says
	# this resident has somewhere to be: a walking phase, an active walk driver, or a live
	# route request. A resident in a real pose, on a bed, in a portal queue or inside a
	# building service is never charged, and neither is a resident between two actions.
	var asked_to_move: bool = bool(life.get("_roam51_active")) or str(life.get("_phase")) in ["WALKING", "THREAT30"]
	var busy_elsewhere: bool = str(amb_state.get("phase", "")) in ["APPROACH", "DOCK", "ALIGN", "ACTING"]
	busy_elsewhere = busy_elsewhere or str(life.get("_phase")) in ["AMBIENT", "HOME58", "THREAT30"] or bool(life.get("_visit") != null)
	if asked_to_move and not busy_elsewhere and moved < STILL_M:
		_still[id] = float(_still.get(id, 0.0)) + float(PERIOD_MS)/1000.0
		if _still[id] >= 3.0: _stalled_while_walking[id] = int(_still[id])
	else:
		_still[id] = 0.0
	_still_worst = maxf(_still_worst, float(_still[id]))
	print("OWNER58_LINE ", JSON.stringify({
		"id": id, "t_ms": now, "pos": [at.x, at.y, at.z], "moved_m": moved,
		"still_s": _still[id], "asked_to_move": asked_to_move, "busy_elsewhere": busy_elsewhere,
		"stalled_while_walking": _stalled_while_walking.get(id, -1),
		"phase": life.get("_phase"), "reason": life.get("_reason"),
		"goal_kind": goal.get("kind", ""), "roam_active": life.get("_roam51_active"),
		"seat_bench": seat.get("bench_id", -1), "seat_serial": seat.get("serial", -1),
		"seat_reason": seat_reason, "seat_nearest_m": seat_nearest_m, "leisure_arrived": life.get("_leisure_arrived58"),
		"ambient_phase": amb_state.get("phase", ""), "ambient_kind": amb_state.get("kind", ""),
		"driver": driver_state, "on_floor": body.is_on_floor(),
		"velocity": [body.velocity.x, body.velocity.y, body.velocity.z]}))
	_lines += 1
	if _lines >= MAX_LINES: set_process(false)

func _passthrough_on() -> bool:
	return true
