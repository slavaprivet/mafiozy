extends Node
## DSH_NIGHT58 observer: read-only. It samples the real night routine, then moves the
## SAME shared clock to the morning hour and samples the real wake/exit. Nothing here
## writes a resident, a bed claim, HP or money.
var night_hour := 3.0
var morning_hour := 10.75
var night_seconds := 300.0
var morning_seconds := 180.0
var _clock: RefCounted
var _scene: Node
var _out := ""
var _rows: Array = []
var _started_ms := 0
var _switched := false
var _switched_ms := 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-night-seconds="): night_seconds = float(argument.trim_prefix("--qa-night-seconds="))
		if argument.begins_with("--qa-morning-seconds="): morning_seconds = float(argument.trim_prefix("--qa-morning-seconds="))
		if argument.begins_with("--qa-out="): _out = argument.trim_prefix("--qa-out=")
	_run.call_deferred()


func _run() -> void:
	_started_ms = Time.get_ticks_msec()
	var wait_until := _started_ms + 115000
	while Time.get_ticks_msec() < wait_until:
		_scene = get_tree().current_scene
		var pop: Variant = _scene.get("preview_population") if _scene != null else null
		if pop != null and _scene.get("preview_ready") == true and pop.get("city_ready") == true and pop.get("daily") != null:
			break
		await get_tree().process_frame
	_clock = get_tree().root.get_meta("mafiozi_visual_clock", null)
	if _clock == null:
		_finish({"ok": false, "reason": "no_shared_clock"})
		return
	_clock.call("set_hour", night_hour)
	_clock.set("running", false)
	print("DSH_NIGHT58 stage=start hour=", night_hour, " night_s=", night_seconds, " morning_s=", morning_seconds)
	var night_end := Time.get_ticks_msec() + int(night_seconds * 1000.0)
	while Time.get_ticks_msec() < night_end:
		_sample("night")
		await get_tree().create_timer(1.0).timeout
	_clock.call("set_hour", morning_hour)
	_switched = true
	_switched_ms = Time.get_ticks_msec()
	print("DSH_NIGHT58 stage=morning hour=", morning_hour)
	var morning_end := Time.get_ticks_msec() + int(morning_seconds * 1000.0)
	while Time.get_ticks_msec() < morning_end:
		_sample("morning")
		await get_tree().create_timer(1.0).timeout
	_finish(_verdict())


func _lives() -> Dictionary:
	if _scene == null:
		return {}
	var pop: Variant = _scene.get("preview_population")
	if pop == null:
		return {}
	var daily: Variant = pop.get("daily")
	if daily == null:
		return {}
	var lives: Variant = daily.get("_lives")
	return lives if lives is Dictionary else {}


func _sample(phase: String) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	var hour: float = float(_clock.get("hour")) if _clock != null else -1.0
	for id: String in _lives():
		var life: RefCounted = _lives()[id]
		if life == null or not is_instance_valid(life):
			continue
		var body: Variant = life._token.get("body")
		var position := Vector3.ZERO
		if is_instance_valid(body) and body is Node3D:
			position = (body as Node3D).global_position
		var home: Dictionary = {}
		var node: Variant = life.get("_home58")
		if node != null and is_instance_valid(node) and node.has_method("snapshot"):
			home = node.call("snapshot")
		var routine: Dictionary = {}
		var routine_node: Variant = life.get("_routine58")
		if routine_node != null and is_instance_valid(routine_node) and routine_node.has_method("snapshot"):
			routine = routine_node.call("snapshot")
		_rows.append({
			"phase": phase, "ms": Time.get_ticks_msec() - _started_ms, "hour": hour, "id": id,
			"life_phase": str(life.get("_phase")), "position": [position.x, position.y, position.z],
			"home_active": bool(home.get("active", false)), "home_phase": str(home.get("phase", "")),
			"sleeping": bool(home.get("sleeping", false)), "claim": bool(home.get("claim_current", false)),
			"support": bool(home.get("support_current", false)), "pose_frames": int(home.get("pose_frames", 0)),
			"home_id": str(home.get("home_id", "")), "bed_id": str(home.get("bed_id", "")),
			"inside": bool(home.get("inside", false)), "reason": str(home.get("reason", "")),
			"intent": str(routine.get("intent", {}).get("kind", ""))})


func _verdict() -> Dictionary:
	var ids: Array = []
	for row: Dictionary in _rows:
		if not ids.has(row.id):
			ids.append(row.id)
	ids.sort()
	var per: Dictionary = {}
	for id: String in ids:
		var rows: Array = []
		for row: Dictionary in _rows:
			if row.id == id:
				rows.append(row)
		var slept := false
		var has_anchor := false
		var sleep_anchor := Vector3.ZERO
		var max_pose := 0
		var beds: Array = []
		for row: Dictionary in rows:
			max_pose = maxi(max_pose, int(row.pose_frames))
			if row.home_phase == "HOME_SLEEP" and row.sleeping and row.claim and row.support:
				slept = true
				if not has_anchor:
					sleep_anchor = _vec(row.position)
					has_anchor = true
				if not beds.has(str(row.bed_id)):
					beds.append(str(row.bed_id))
		# exit: the home went inactive after the morning switch and the resident moved
		var exit_ms := -1
		var move_ms := -1
		var exited := false
		var was_active := false
		for row: Dictionary in rows:
			if row.phase != "morning":
				continue
			if row.home_active:
				was_active = true
				continue
			if was_active and exit_ms < 0:
				exit_ms = int(row.ms)
				was_active = false
			if exit_ms >= 0 and has_anchor:
				if _vec(row.position).distance_to(sleep_anchor) >= 0.75:
					exited = true
					if move_ms < 0:
						move_ms = int(row.ms)
		# longest unexplained still period: not in an active home and barely moving
		var idle_run := 0
		var idle_max := 0
		var previous := Vector3.ZERO
		var first_sample := true
		for row: Dictionary in rows:
			var here := _vec(row.position)
			var moved := 999.0 if first_sample else here.distance_to(previous)
			previous = here
			first_sample = false
			var resting_phase: bool = str(row.life_phase) in ["IDLE", "RESTING", "AMBIENT"]
			if resting_phase and not row.home_active and moved < 0.10:
				idle_run += 1
				idle_max = maxi(idle_max, idle_run)
			else:
				idle_run = 0
		per[id] = {"slept_in_own_bed": slept, "sleep_pose_frames": max_pose, "beds": beds,
			"exited_home": exited, "exit_to_move_s": (-1.0 if (exit_ms < 0 or move_ms < 0) else roundf((move_ms - exit_ms) / 1000.0)),
			"longest_still_s": idle_max, "samples": rows.size()}
	var slept_count := 0
	var exited_count := 0
	var worst_still := 0
	for id: String in per:
		if per[id].slept_in_own_bed:
			slept_count += 1
		if per[id].exited_home:
			exited_count += 1
		worst_still = maxi(worst_still, int(per[id].longest_still_s))
	return {"ok": true, "residents": per, "slept_count": slept_count, "exited_count": exited_count,
		"worst_still_s": worst_still, "night_hour": night_hour, "morning_hour": morning_hour,
		"verdict": {"all_ten_slept_in_own_bed": slept_count == 10, "all_ten_left_after_wake": exited_count == 10,
			"no_unexplained_still_over_10s": worst_still <= 10}}


func _vec(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _finish(value: Dictionary) -> void:
	print("DSH_NIGHT58_RESULT ", JSON.stringify(value))
	if not _out.is_empty():
		var path := _out.path_join("NIGHT58.json")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(value, "\t"))
			file.close()
	get_tree().quit(0 if value.get("ok", false) else 1)
