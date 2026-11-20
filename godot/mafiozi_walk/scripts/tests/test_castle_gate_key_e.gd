extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	var castle: Node = scene.get("preview_castle")
	var player: Node3D = scene.get("_player")
	if not is_instance_valid(castle) or not is_instance_valid(player):
		print("CASTLE_GATE_KEY_E FAIL scene_not_ready")
		quit(1)
		return
	player.global_position = castle.call("lever_position")
	player.set("_free_mouse_look", true)
	var action: Dictionary = scene.call("_current_door_action")
	var failures: Array[String] = []
	if action.get("owner", "") != "castle" or action.get("key", "") != "E":
		failures.append("prompt_not_e")
	if castle.call("gate_open"):
		castle.call("set_gate", false)
	var f := InputEventKey.new()
	f.pressed = true
	f.physical_keycode = KEY_F
	scene.call("_unhandled_input", f)
	castle.call("_unhandled_input", f)
	if castle.call("gate_open"):
		failures.append("f_opened_gate")
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = KEY_E
	scene.call("_unhandled_input", e)
	castle.call("_unhandled_input", e)
	if not castle.call("gate_open"):
		failures.append("e_did_not_open_gate")
	scene.call("_unhandled_input", e)
	castle.call("_unhandled_input", e)
	if castle.call("gate_open"):
		failures.append("e_did_not_close_gate")
	print("CASTLE_GATE_KEY_E ", "PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
