extends SceneTree
## Startup catapult spawn guard: accidental boot teleport is corrected, but real
## player movement immediately releases the guard and can leave the machine.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("BATTLEFIELD_SPAWN_GUARD_FAIL scene")
		quit(1)
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and game.get("preview_ready") != true:
		await process_frame
	var player: CharacterBody3D = game.get("_player") as CharacterBody3D
	var castle: Node3D = game.get("preview_castle") as Node3D
	if player == null or castle == null or game.get("preview_catapult") == null:
		print("BATTLEFIELD_SPAWN_GUARD_FAIL missing_scene_parts")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and game.get("_catapult_at_castle") != true:
		await physics_frame
	if game.get("_catapult_at_castle") != true:
		print("BATTLEFIELD_SPAWN_GUARD_FAIL catapult_placement_timeout")
		quit(1)
		return
	var target: Vector3 = game.get("_castle_spawn_target")
	var initial_frames: int = int(game.get("_castle_spawn_frames"))
	# Simulate a late city boot step with NO input; main must restore catapult spawn.
	player.global_position = target + Vector3(0.0, 0.0, -31.0)
	player.velocity = Vector3.ZERO
	for tick: int in 3:
		await physics_frame
	var corrected_distance: float = player.global_position.distance_to(target)
	var corrected: bool = corrected_distance < 2.0
	var frames_before_input: int = int(game.get("_castle_spawn_frames"))
	player.set_mouse_captured(true)
	player.set("_camera_yaw", 0.0) # Forward points away from gate, toward -Z.
	Input.action_press(player.ACTION_FORWARD)
	Input.action_press(player.ACTION_RUN)
	await physics_frame
	var frames_after_input: int = int(game.get("_castle_spawn_frames"))
	var max_distance: float = player.global_position.distance_to(target)
	var min_z: float = player.global_position.z
	var grounded := 0
	for tick: int in 340:
		await physics_frame
		max_distance = maxf(max_distance, player.global_position.distance_to(target))
		min_z = minf(min_z, player.global_position.z)
		if player.is_on_floor():
			grounded += 1
	Input.action_release(player.ACTION_FORWARD)
	Input.action_release(player.ACTION_RUN)
	var end_distance: float = player.global_position.distance_to(target)
	var run_away: bool = max_distance > 25.5 and end_distance > 25.0 \
		and min_z < target.z - 25.0 and grounded > 280
	var passed: bool = initial_frames > 0 and corrected and frames_before_input > 0 \
		and frames_after_input == 0 and run_away
	print("BATTLEFIELD_SPAWN_GUARD ", JSON.stringify({"pass": passed,
		"initial_frames": initial_frames, "corrected": corrected,
		"corrected_distance": corrected_distance,
		"frames_before_input": frames_before_input,
		"frames_after_input": frames_after_input,
		"max_distance": max_distance, "end_distance": end_distance,
		"target_z": target.z, "min_z": min_z, "grounded": grounded,
		"run_away": run_away}))
	current_scene = null
	game.queue_free()
	packed = null
	for tick: int in 18:
		await process_frame
	quit(0 if passed else 1)
