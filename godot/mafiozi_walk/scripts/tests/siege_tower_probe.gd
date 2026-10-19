extends SceneTree
## DSH_TOWER: functional acceptance for the siege ram tower.
##
## Headless probe: wheels, pushing, the ram, the ladder, damage immunity and
## full destruction.  Prints one JSON line and exits non-zero on a failed check.

var _scene: Node
var _host: Node
var _body: AnimatableBody3D
var _player: CharacterBody3D
var _castle: Node3D
var _checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(name: String, ok: bool, detail: Variant = "") -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	print("DSH_TOWER_CHECK ", JSON.stringify({"name": name, "ok": ok, "detail": detail}))

func _settle(frames: int, physics: bool = true) -> void:
	for _i: int in frames:
		if physics:
			await physics_frame
		else:
			await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("DSH_TOWER_PROBE_FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	if _scene.get("preview_ready") != true:
		print("DSH_TOWER_PROBE_FAIL not_ready")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		_host = _scene.get("preview_siege_tower") as Node
		if is_instance_valid(_host):
			break
		await process_frame
	if not is_instance_valid(_host):
		print("DSH_TOWER_PROBE_FAIL no_host status=", _scene.get("siege_tower_status"))
		quit(1)
		return
	_body = _host.call("body_ref") as AnimatableBody3D
	_player = _scene.get("_player") as CharacterBody3D
	_castle = _scene.get("preview_castle") as Node3D
	# The castle's startup guard teleports the player back if she is more than
	# 25 m from the spawn; the probe deliberately works at the gate.
	_scene.set("_castle_spawn_frames", 0)
	await _settle(20)
	var snap: Dictionary = _host.call("snapshot")
	var body_snap: Dictionary = snap.get("body", {})
	_check("installed", bool(body_snap.get("installed", false)), body_snap.get("origin"))
	_check("parts", int(body_snap.get("model_parts", 0)) >= 20, body_snap.get("model_parts"))
	_check("colliders", int(body_snap.get("colliders", 0)) >= 24, body_snap.get("colliders"))
	_check("integrity_full", float(body_snap.get("integrity", 0.0)) > 0.99, body_snap.get("integrity"))

	# 1. Blades and arrows are refused; siege damage is accepted.
	var wheel_local := Vector3(-2.28, 0.78, -2.45)
	var wheel_world: Vector3 = _body.to_global(wheel_local)
	var refused: Dictionary = _body.call("apply_hit", wheel_world, 80.0, Vector3.ZERO, "sword")
	_check("blade_immune", not bool(refused.get("ok", true)), refused.get("reason"))
	var before_hp := float(((_body.get("_part_hp") as Dictionary).get("wheel_0", 0.0)))
	var cannon: Dictionary = _body.call("apply_hit", wheel_world, 90.0, Vector3.ZERO, "cannonball")
	var after_hp := float(((_body.get("_part_hp") as Dictionary).get("wheel_0", 0.0)))
	_check("cannon_damage", bool(cannon.get("ok", false)) and after_hp < before_hp,
		{"before": before_hp, "after": after_hp, "part": cannon.get("part")})
	await _settle(5)
	var broken: Array = (_body.get("_broken") as Dictionary).keys()
	_check("wheel_broken", broken.has("wheel_0"), broken)
	_check("broken_collider_off", bool((_body.get("_part_nodes") as Dictionary).has("wheel_0"))
		and not ((_body.get("_part_nodes") as Dictionary)["wheel_0"] as Node3D).visible, "")

	# 2. Pushing: more men must give a higher steady speed; wheels must turn.
	var clear_pose := _castle.to_global(Vector3(30.0, 0.0, 150.0))
	_body.call("moor", clear_pose, 0.0)
	_body.call("debug_force_pushers", 1)
	await _settle(100)
	var speed_one := float(_body.get("_speed"))
	var wheel_after := float(_body.call("wheel_angle"))
	_check("push_one_moves", speed_one > 0.25, speed_one)
	_check("wheels_turn", absf(wheel_after) > 0.05, wheel_after)
	_body.call("moor", clear_pose, 0.0)
	_body.call("debug_force_pushers", 4)
	await _settle(120)
	var speed_four := float(_body.get("_speed"))
	_check("push_scales", speed_four > speed_one * 1.35, {"one": speed_one, "four": speed_four})
	_body.call("debug_force_pushers", 0)
	await _settle(40)
	_check("push_stops", float(_body.get("_speed")) < float(speed_four) * 0.4, _body.get("_speed"))

	# 2b. The real input path: stand at the push frame, hold W, and shove.
	_body.call("moor", clear_pose, 0.0)
	_body.call("debug_force_pushers", -1)
	_player.global_position = _body.to_global(Vector3(0.0, 0.15, 4.85))
	_player.velocity = Vector3.ZERO
	_player.set("_camera_yaw", 0.0)
	_player.set("_heading", 0.0)
	_player.call("set_mouse_captured", true)
	var player_visual: Variant = _player.get("_visual")
	if player_visual is Node3D:
		(player_visual as Node3D).rotation.y = 0.0
	await _settle(15)
	Input.action_press(&"preview_move_forward")
	await _settle(90)
	var input_speed := float(_body.get("_speed"))
	var input_pushers := int(_body.get("_pushers"))
	print("DSH_TOWER_INPUT_DEBUG ", JSON.stringify({
		"player": _player.global_position, "local": _body.call("to_local", _player.global_position),
		"floor": _player.is_on_floor(), "velocity": _player.velocity,
		"free": _player.get("_free_mouse_look"), "authority": str(_player.get("_pose_authority")),
		"pressed": Input.is_action_pressed(&"preview_move_forward"),
		"pushers": input_pushers, "speed": input_speed}))
	Input.action_release(&"preview_move_forward")
	_player.call("set_mouse_captured", false)
	_check("input_push", input_speed > 0.20 and input_pushers >= 1,
		{"speed": input_speed, "pushers": input_pushers})
	_body.call("debug_force_pushers", 0)
	await _settle(30)

	# 3. Ram: park in front of the gate and swing.  The gate must take damage.
	var gate_pose := _castle.to_global(Vector3(0.0, 0.0, 75.6))
	_body.call("moor", gate_pose, 0.0)
	await _settle(6)
	var trigger: bool = bool(_host.call("interact", {"kind": "tower_ram"}))
	_check("ram_trigger", trigger, "")
	await _settle(70)
	var last_hit: Dictionary = _body.get("_last_hit")
	var gate_stats: Dictionary = _castle.call("get_stats") if _castle.has_method("get_stats") else {}
	_check("ram_hits", int(_body.get("_ram_hits")) > 0, last_hit)
	_check("ram_gate_damage", int(gate_stats.get("gate_boards_broken", 0)) > 0
		or int(gate_stats.get("gate_bricks", 0)) > 0
		or int(gate_stats.get("gate_leaves_detached", 0)) > 0, gate_stats)

	# 3b. Catapult stone damage, and a broken ram must stop swinging.
	var before_catapult := float(_body.get("_integrity"))
	var catapult_ok := bool(_host.call("catapult_impact", _body.global_position + Vector3.UP * 2.6, Vector3.DOWN))
	await _settle(6)
	_check("catapult_damages", catapult_ok and float(_body.get("_integrity")) < before_catapult,
		{"ok": catapult_ok, "before": before_catapult, "after": _body.get("_integrity")})
	await _settle(120)
	_body.call("debug_break", "ram")
	await _settle(4)
	var ram_retrigger := bool(_host.call("interact", {"kind": "tower_ram"}))
	_check("ram_break_disables", bool(_body.get("_ram_broken")) and not ram_retrigger,
		{"broken": _body.get("_ram_broken"), "retrigger": ram_retrigger})

	# 4. Ladder: climb from the ground to the fighting top, then back down.
	_body.call("debug_climb_axis", 1.0)
	_player.global_position = _body.to_global(Vector3(3.30, 0.10, 0.55))
	_player.velocity = Vector3.ZERO
	for _i: int in 18:
		_body.call("climb_assist", _player, 0.05)
		await physics_frame
	var mid_local: Vector3 = _body.call("to_local", _player.global_position)
	_check("ladder_climbs", mid_local.y > 1.6, mid_local)
	for _i: int in 100:
		_body.call("climb_assist", _player, 0.05)
		await physics_frame
	var top_local: Vector3 = _body.call("to_local", _player.global_position)
	_check("ladder_top", top_local.y > 8.4 and top_local.x < 2.60, top_local)
	# Stand on the balcony without holding W: the floor must carry the player.
	_body.call("debug_climb_axis", 0.0)
	await _settle(25)
	var stand_local: Vector3 = _body.call("to_local", _player.global_position)
	_check("platform_stands", stand_local.y > 8.40, stand_local)
	# Step onto the ladder balcony before descending, as a player would.
	_player.global_position = _body.to_global(Vector3(2.60, 8.80, 0.55))
	_body.call("debug_climb_axis", -1.0)
	for _i: int in 110:
		_body.call("climb_assist", _player, 0.05)
		await physics_frame
	var bottom_local: Vector3 = _body.call("to_local", _player.global_position)
	_check("ladder_down", bottom_local.y < 0.6, bottom_local)
	_body.call("debug_climb_axis", NAN)

	# 5. Powder barrel blast and full collapse.
	var blasts := 0
	for _i: int in 5:
		if bool(_body.get("_destroyed")):
			break
		if bool(_body.call("blast_at", _body.to_global(Vector3(0.0, 1.15, 0.0)), 5.2, 3200.0, "powder")):
			blasts += 1
		await _settle(6)
	_check("powder_damages", blasts > 0, blasts)
	await _settle(90)
	var destroyed := bool(_body.get("_destroyed"))
	_check("full_collapse", destroyed, _body.call("snapshot"))
	_check("debris_burst", int(_body.call("debris_count")) >= 40, _body.call("debris_count"))
	_check("prompt_gone", (_host.call("action") as Dictionary).is_empty(), _host.call("action"))

	var failed := 0
	for entry: Dictionary in _checks:
		if not bool(entry.get("ok", false)):
			failed += 1
	var result := {"checks": _checks.size(), "failed": failed, "pass": failed == 0,
		"blasts": blasts, "checks_detail": _checks}
	print("DSH_TOWER_PROBE ", JSON.stringify(result))
	quit(0 if failed == 0 else 1)
