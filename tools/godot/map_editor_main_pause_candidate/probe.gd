extends SceneTree
## Headless CPU only. The control and candidate instantiate the same actual source.
var failures: Array[String] = []
var checks := 0
var samples := []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("_run")

func _key(pressed: bool, code: Key = KEY_K) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _mouse(pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	for pass_index in 6:
		var candidate: bool = pass_index % 2 == 1
		var scene_path := "res://scenes/main.tscn" if candidate else "res://scenes/main_original.tscn"
		var before := Time.get_ticks_usec()
		var scene: PackedScene = load(scene_path)
		check(scene != null, "scene_load:" + scene_path)
		if scene == null: break
		var main: Node3D = scene.instantiate()
		root.add_child(main)
		for i in 180:
			if main.preview_ready: break
			await process_frame
		for i in 12: await physics_frame
		check(main.preview_ready, "actual_main_ready:" + str(pass_index))
		if not main.preview_ready:
			main.queue_free(); await process_frame; break
		var load_ms := float(Time.get_ticks_usec() - before) / 1000.0
		var mem_mb := float(OS.get_static_memory_usage()) / 1048576.0
		var nodes := _count_nodes(main)
		var block_hash := hash(main._block)
		var workspace: Node = main.get_node_or_null("PauseOnlyWorkspace")
		if candidate:
			check(workspace != null and workspace.status == "pause_only_available", "workspace_mounted:" + str(pass_index) + ":" + (workspace.status if workspace != null else "missing"))
			if workspace != null and workspace.status == "pause_only_available":
				_key(true); await process_frame
				_key(true); await process_frame
				check(paused and workspace.active and workspace.exits == 0, "same_k_press_not_exit")
				_key(false); await process_frame
				check(paused and workspace.active and workspace.enters == 1, "native_k_enter:" + workspace.status)
				_key(true, KEY_ESCAPE); await process_frame
				_key(false, KEY_ESCAPE); await process_frame
				check(paused and workspace.active and workspace._host != null and not workspace._host._fault, "escape_cannot_cancel_healthy_lease")
				var old_request: Dictionary = workspace._current_request.duplicate(true)
				var clock_before: float = float(main._clock)
				var water_before: float = float(main._water_host._factory._time) if main._water_host != null else -1.0
				var player_before: Transform3D = main._player.global_transform
				var body_before: Transform3D = main.preview_transport.body.global_transform
				var gameplay_time_before: float = main.preview_melee.gameplay_clock.now_ms()
				await create_timer(0.2, true).timeout
				check(is_equal_approx(main._clock, clock_before) and paused, "native_physics_and_process_stopped")
				check(main._water_host == null or is_equal_approx(float(main._water_host._factory._time), float(water_before)), "water_frozen")
				check(main._player.global_transform == player_before and main.preview_transport.body.global_transform == body_before, "player_and_body_frozen")
				check(is_equal_approx(main.preview_melee.gameplay_clock.now_ms(), gameplay_time_before), "melee_active_time_frozen")
				_key(true, KEY_W); await process_frame
				_key(true); await process_frame
				check(paused and workspace.active and workspace.exits == 0, "held_W_blocks_resume")
				_key(false); _key(false, KEY_W); await process_frame
				_key(true); await process_frame
				_key(false); await process_frame
				check(not paused and not workspace.active and workspace.exits == 1, "native_k_exit:" + workspace.status)
				await process_frame
				check(main._water_host == null or absf(float(main._water_host._factory._time) - float(water_before)) < 0.15, "water_phase_no_wall_jump")
				check(hash(main._block) == block_hash, "source_unchanged")
				main.preview_residents_enabled = true
				_key(true); await process_frame
				check(not paused and workspace.status.contains("nav_owner_missing"), "residents_fail_closed")
				_key(false); await process_frame
				main.preview_residents_enabled = false
				main.preview_transport.phase = "SEATED"
				_key(true); await process_frame
				check(not paused and workspace.status.contains("transport_lease"), "seated_fail_closed")
				_key(false); await process_frame
				main.preview_transport.phase = "ON_FOOT"
				main.preview_transport._parked_brake = false
				_key(true); await process_frame
				check(not paused and workspace.status.contains("rolling_or_contact_vehicle"), "rolling_vehicle_fail_closed")
				_key(false); await process_frame
				main.preview_transport._parked_brake = true
				var saved_melee_state: Dictionary = main.preview_melee._state.duplicate(true)
				main.preview_melee._state["start"] = {"seq":1}
				_key(true); await process_frame
				check(not paused and workspace.status.contains("melee_lease"), "active_melee_fail_closed")
				_key(false); await process_frame
				main.preview_melee._state = saved_melee_state
				main.preview_melee._source._timers.append({"kind":"test_pending"})
				_key(true); await process_frame
				check(not paused and workspace.status.contains("melee_lease"), "pending_melee_timer_fail_closed")
				_key(false); await process_frame
				main.preview_melee._source._timers.pop_back()
				main.preview_melee._cooldown = true
				_key(true); await process_frame
				check(not paused and workspace.status.contains("melee_lease"), "cooldown_melee_fail_closed")
				_key(false); await process_frame
				main.preview_melee._cooldown = false
				var impact := Node.new()
				main.preview_character_impacts = impact
				_key(true); await process_frame
				check(not paused and workspace.status.contains("impact_owner_missing"), "optional_impact_fail_closed")
				_key(false); await process_frame
				main.preview_character_impacts = null
				impact.free()
				if pass_index == 3:
					_key(true); await process_frame
					_key(false); await process_frame
					check(paused and workspace.active, "second_lease_enter")
					check(not workspace._cancel_pause(old_request).get("ok", false) and paused and workspace.active, "stale_A_cannot_cancel_B")
					var current_request: Dictionary = workspace._current_request.duplicate(true)
					var door: Dictionary = main._printshop._doors["public"]
					var saved_door: Transform3D = door.node.transform
					door.node.position.x += 1.0
					check(not workspace._cancel_pause(current_request).get("ok", false) and paused, "changed_door_cannot_cancel")
					door.node.transform = saved_door
					var water_owner: RefCounted = main._water_host
					main._water_host = RefCounted.new()
					check(not workspace._cancel_pause(current_request).get("ok", false) and paused, "changed_water_owner_cannot_cancel")
					main._water_host = water_owner
					Input.action_press(&"preview_jump")
					_key(true); await process_frame
					check(paused and workspace.active, "injected_jump_action_blocks_exit")
					_key(false); Input.action_release(&"preview_jump"); await process_frame
					_key(true); await process_frame
					_key(false); await process_frame
					check(not paused and not workspace.active, "rearmed_action_exit")
					_key(true); await process_frame
					_key(false); await process_frame
					check(paused and workspace.active, "fault_recovery_enter")
					var previous_source_clock: int = main.preview_transport.body._control_source_clock
					main.preview_transport.body._control_source_clock += 1
					_key(true); await process_frame
					_key(false); await process_frame
					check(paused and workspace.active and workspace._host._fault, "changed_owner_faults_host")
					check(workspace._k_released, "faulted_k_release_rearms_recovery")
					main.preview_transport.body._control_source_clock = previous_source_clock
					workspace._k_released = false
					_key(true, KEY_ESCAPE); await process_frame
					_key(false, KEY_ESCAPE); await process_frame
					check(paused and workspace.active and workspace._host._fault, "fault_escape_without_k_rearm_cannot_recover")
					workspace._k_released = true
					_key(true, KEY_W); await process_frame
					_key(true, KEY_ESCAPE); await process_frame
					_key(false, KEY_W); await process_frame
					_key(false, KEY_ESCAPE); await process_frame
					check(paused and workspace.active and workspace._host._fault, "fault_escape_held_W_press_cannot_recover")
					_key(true, KEY_SPACE); await process_frame
					_key(true, KEY_ESCAPE); await process_frame
					_key(false, KEY_ESCAPE); await process_frame
					check(paused and workspace.active and workspace._host._fault, "fault_escape_held_jump_cannot_recover")
					_key(false, KEY_SPACE); await process_frame
					_mouse(true); await process_frame
					_key(true, KEY_ESCAPE); await process_frame
					_key(false, KEY_ESCAPE); await process_frame
					check(paused and workspace.active and workspace._host._fault, "fault_escape_held_mouse_cannot_recover")
					_mouse(false); await process_frame
					_key(true, KEY_ESCAPE); await process_frame
					check(workspace._escape_recovery_armed, "fault_escape_neutral_press_arms")
					_key(true, KEY_W); await process_frame
					_key(false, KEY_ESCAPE); await process_frame
					check(paused and workspace.active and workspace._host._fault, "fault_escape_held_W_release_cannot_recover")
					_key(false, KEY_W); await process_frame
					_key(true, KEY_ESCAPE); await process_frame
					check(paused and workspace.active and workspace._escape_recovery_armed, "fault_escape_press_arms_without_resume")
					_key(false, KEY_ESCAPE); await process_frame
					check(not paused and not workspace.active and workspace.status == "emergency_cancel:manual_current_owner_recovery", "exact_current_owner_escape_recovery")
				if pass_index == 1:
					_key(true); await process_frame
					_key(false); await process_frame
					check(paused and workspace.active, "focus_fixture_enter")
					workspace.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
					check(not paused and not workspace.active and workspace.status == "emergency_cancel:focus_out", "focus_out_owner_cancel")
				elif pass_index == 5:
					_key(true); await process_frame
					_key(false); await process_frame
					check(paused and workspace.active, "teardown_fixture_enter")
					var current_request: Dictionary = workspace._current_request.duplicate(true)
					main.preview_transport.body._control_source_clock += 1
					check(not workspace._cancel_pause(current_request).get("ok", false) and paused, "changed_native_control_cannot_cancel")
		else:
			_key(true); await process_frame
			_key(false); await process_frame
			check(not paused, "original_k_does_not_pause")
		samples.append({"kind":"candidate" if candidate else "original","pass":pass_index,"load_ms":load_ms,"static_mb":mem_mb,"nodes":nodes,"buildings":int(main._block.counts.buildings),"decor":int(main._block.counts.decor),"block_hash":block_hash})
		main.queue_free()
		await process_frame
		await process_frame
		if candidate and pass_index == 5: check(not paused, "scene_teardown_unpauses_owned_tree")
		if paused:
			failures.append("pause_leaked_between_runs")
			break
	print("MAIN_PAUSE_PROBE ", JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += _count_nodes(child)
	return count
