extends SceneTree

var out_dir := "D:/MafioziCastle31/qa/natural_armor56abc/run"
var weapon := "sword"
var armor := false
var max_strokes := 16
var same_direction := false
var stroke_dx := 20.0
var report: Dictionary = {"scope": "rack equip + choose mouse direction + click/release, no damage injection or teleport after initial placement", "strokes": []}
var failures: Array[String] = []
var actor: Node
var host: Node
var trace: Array = []
var prior_hp: float = -1.0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out_dir = arg.trim_prefix("--qa-out=")
		if arg == "--armor=heavy": armor = true
		if arg.begins_with("--weapon="): weapon = arg.trim_prefix("--weapon=")
		if arg.begins_with("--strokes="): max_strokes = clampi(int(arg.trim_prefix("--strokes=")), 1, 16)
		if arg == "--same-direction=1": same_direction = true
		if arg == "--fast=1": stroke_dx = 20.0
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		if is_instance_valid(host):
			var state: Dictionary = host.snapshot()
			if float(state.npc_hp) != prior_hp:
				prior_hp = float(state.npc_hp)
				trace.append({"at_ms":Time.get_ticks_msec(),"npc_hp":prior_hp,"part_hp":state.npc_part_hp,"player_dead":actor.get("preview_dead"),"player_severed":state.player_severed,"player_disarmed":state.player_disarmed,"omega":state.omega,"hand":state.hand,"last_hit":state.last_hit_kind,"distance":state.player_position.distance_to(state.npc_position),"blade_from":state.blade_from,"blade_to":state.blade_to})

func _key(code: int) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)

func _hold_key(code: int, frames: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(frames)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)

func _right(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = down
	event.position = Vector2(640, 360)
	Input.parse_input_event(event)

func _left(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = Vector2(640, 360)
	Input.parse_input_event(event)

func _move(dx: float, dy: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.position = Vector2(640, 360)
	Input.parse_input_event(event)

func _shot(_name: String) -> void:
	await _frames(1)

func _finish() -> void:
	report["trace"] = trace
	report["player_dead"] = actor.get("preview_dead") if is_instance_valid(actor) else null
	report["player_severed"] = host.snapshot().player_severed if is_instance_valid(host) else null
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	FileAccess.open(out_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("NATURAL_ARMOR56ABC_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	report["armor_requested"] = armor
	report["max_strokes"] = max_strokes
	report["same_direction"] = same_direction
	report["stroke_dx_per_frame"] = stroke_dx
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	scene.set("preview_residents_enabled", false)
	scene.set_meta("npc_home_registry58", RefCounted.new())
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 90000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline: await process_frame
	if scene.get("preview_ready") != true:
		failures.append("castle_ready")
		_finish()
		return
	await _frames(30)
	scene.set("_castle_spawn_frames", 0)
	var player: CharacterBody3D = scene.get("_player")
	var weapons: Node = scene.get("preview_weapons")
	player.set_mouse_captured(true)
	var castle: Node3D = scene.get("preview_castle")
	var storage: Node = castle.get("armory_storage")
	var rack: Array = storage.get("_rack_points")
	player.global_position = castle.to_global(rack[3 if weapon == "sledge" else 0])
	player.velocity = Vector3.ZERO
	if not storage.interact(): failures.append("rack_take"); _finish(); return
	await _frames(10)
	var sword: Node = scene.get("preview_sword_prototype")
	if not is_instance_valid(sword):
		failures.append("q_sword_host")
		_finish()
		return
	report["weapon_after_q"] = str(sword.snapshot().get("weapon", ""))
	var knight: CharacterBody3D = sword.get("_npc_body")
	var rig: Skeleton3D = sword.get("_npc_rig")
	for i in 300:
		if is_instance_valid(knight) and is_instance_valid(rig): break
		await _frames(1)
		knight = sword.get("_npc_body")
		rig = sword.get("_npc_rig")
	if not is_instance_valid(knight) or not is_instance_valid(rig):
		failures.append("natural_knight")
		_finish()
		return
	if armor:
		var armor_result: Dictionary = sword.set_npc_armor31({"head": "heavy_head", "torso": "heavy_torso", "hands": "heavy_hands", "legs": "heavy_legs", "feet": "heavy_feet"})
		report["armor_setup"] = armor_result
		if not bool(armor_result.get("ok", false)):
			failures.append("armor_setup")
			_finish()
			return
	report["armor_snapshot"] = sword.npc_armor_snapshot31()
	var rear: Vector3 = (sword.get("_npc_motion") as Node3D).global_basis.z.normalized()
	player.global_position = knight.global_position + rear * 1.05
	player.velocity = Vector3.ZERO
	var toward: Vector3 = knight.global_position - player.global_position
	var yaw := atan2(-toward.x, -toward.z) + 0.15
	player.set("_camera_yaw", yaw)
	player.set("_camera_pitch", -0.24)
	player.set("_heading", yaw)
	player._visual.rotation.y = yaw + PI - player.global_rotation.y
	player._update_camera_rotation()
	await _frames(8)
	actor = scene
	host = sword
	var initial: Dictionary = sword.snapshot()
	report["initial"] = {"npc_hp": initial.get("npc_hp"), "part_hp": initial.get("npc_part_hp"), "npc_dead": initial.get("npc_dead"), "npc_sword": is_instance_valid(sword.get("_npc_sword")), "player_pos": player.global_position, "npc_pos": knight.global_position}
	await _shot("before")
	for stroke in max_strokes:
		var pre: Dictionary = sword.snapshot()
		var sign := 1.0 if same_direction or stroke % 2 == 0 else -1.0
		_left(true)
		for frame in 55:
			_move(20.0 * sign, -6.0 if frame<20 else 6.0)
			await _frames(1)
		_left(false)
		await _frames(30)
		var post: Dictionary = sword.snapshot()
		var row := {"index": stroke, "npc_hp_before": pre.get("npc_hp"), "npc_hp_after": post.get("npc_hp"), "part_hp_before": pre.get("npc_part_hp"), "part_hp_after": post.get("npc_part_hp"), "bleeding": post.get("bleeding"), "severed": post.get("npc_severed"), "dead": post.get("npc_dead"), "disarmed": post.get("npc_disarmed"), "fall": post.get("npc_fall"), "sword_held": is_instance_valid(sword.get("_npc_sword")), "ground_swords": sword.ground_sword_count(), "hits_delta": int(post.get("hits", 0)) - int(pre.get("hits", 0)), "sweep_hits_delta": int(post.get("sweep_hits", 0)) - int(pre.get("sweep_hits", 0)), "blocks_delta": int(post.get("blocks", 0)) - int(pre.get("blocks", 0)), "sparks_delta": int(post.get("sparks_total", 0)) - int(pre.get("sparks_total", 0)), "player_npc_distance": player.global_position.distance_to(knight.global_position)}
		report.strokes.append(row)
		if row.severed.size() > 0 and not report.has("first_sever"):
			report["first_sever"] = row
			await _shot("first_sever")
			break
		if bool(post.get("npc_dead", false)):
			await _shot("death_start")
			await _frames(65)
			var settled: Dictionary = sword.snapshot()
			report["death_settled"] = {"dead": settled.get("npc_dead"), "fall": settled.get("npc_fall"), "disarmed": settled.get("npc_disarmed"), "sword_held": is_instance_valid(sword.get("_npc_sword")), "ground_swords": (sword.get("_ground_swords") as Array).size() if sword.get("_ground_swords") is Array else -1, "npc_velocity": knight.velocity, "npc_position": knight.global_position}
			await _shot("death_settled")
			break
	await _frames(180)
	await _shot("settled")
	var last: Dictionary = sword.snapshot()
	report["final"] = {"npc_hp": last.get("npc_hp"), "part_hp": last.get("npc_part_hp"), "dead": last.get("npc_dead"), "severed": last.get("npc_severed"), "fall": last.get("npc_fall"), "disarmed": last.get("npc_disarmed"), "sword_held": is_instance_valid(sword.get("_npc_sword"))}
	if report.strokes.is_empty(): failures.append("no_strokes")
	if last.get("npc_part_hp") == initial.get("npc_part_hp"): failures.append("no_real_damage")
	if weapon == "sword" and not report.has("first_sever"): failures.append("sharp_sever_missing")
	if weapon == "sledge" and not (last.get("npc_severed") as Array).is_empty(): failures.append("blunt_must_not_slice")
	if weapon == "sledge" and float(last.get("npc_part_hp",{}).get("forearm_r",1)) <= 0.0 and not last.get("npc_disarmed",false): failures.append("broken_arm_still_armed")
	report["weapon_test"] = weapon
	report["directional"] = sword.snapshot().get("directional41")
	_finish()
