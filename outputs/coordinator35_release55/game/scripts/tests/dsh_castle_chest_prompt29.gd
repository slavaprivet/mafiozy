extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	var castle: Node3D = scene.get("preview_castle")
	var player: CharacterBody3D = scene.get("_player")
	var storage: Node = castle.armory_storage
	var errors: Array[String] = []
	player.set_mouse_captured(true)
	for frame: int in 120: await physics_frame
	player.global_position = castle.to_global(Vector3(5.4, 0.1, -14.9))
	var camera: Camera3D = player.get_preview_camera()
	var target: Vector3 = storage.chest_hint_position() - Vector3.UP * 0.9
	camera.look_at(target + Vector3(8.0, 0.0, 0.0))
	if storage.chest_focused() or scene._current_door_action().get("owner", "") == "castle_chest":
		errors.append("prompt_without_looking")
	camera.look_at(target)
	if not storage.chest_focused() or scene._current_door_action().get("label", "") != "Открыть сундук":
		errors.append("no_prompt_while_looking")
	scene._update_door_hint()
	if scene.get("_door_hint").text != "Открыть сундук": errors.append("chest_panel_not_visible")
	var e := InputEventKey.new(); e.physical_keycode = KEY_E; e.keycode = KEY_E; e.pressed = true
	scene._unhandled_input(e)
	if not storage.window_open: errors.append("e_did_not_open_chest")
	if scene._current_door_action().get("owner", "") == "castle_chest":
		errors.append("prompt_stays_when_open")
	print("CASTLE_CHEST_PROMPT29 ", JSON.stringify({"passed": errors.is_empty(), "errors": errors}))
	await create_timer(0.3).timeout
	quit(0 if errors.is_empty() else 1)
