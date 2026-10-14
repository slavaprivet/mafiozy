extends SceneTree
## Isolated three-resident K pause-only probe. Never edits or saves a map.
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func key_k(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_K
	event.physical_keycode = KEY_K
	event.pressed = down
	Input.parse_input_event(event)

func mouse_left(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)

func finish(scene: Node3D) -> void:
	var result := {"checks":checks,"failures":failures,"forcedStill":OS.get_cmdline_user_args().has("--diagnostic-force-still"),"vehicleLease":OS.get_cmdline_user_args().has("--vehicle-lease"),"scope":"isolated pause-only K, three residents; no map edits or LIVE"}
	print(JSON.stringify(result))
	if is_instance_valid(scene): scene.free()
	paused = false
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = true
	scene.preview_resident_walk_enabled = false
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if scene.preview_ready and scene.preview_population != null and scene.preview_population.navigation != null and scene.preview_population.navigation.state() == "READY": break
		await physics_frame
	var workspace: Node = scene.get_node_or_null("PauseOnlyAtomicWorkspace")
	check(scene.preview_ready and scene.population_status == "ready", "actual default resident owner ready")
	check(workspace != null and workspace.status == "pause_only_available", "K workspace mounted: " + (workspace.status if workspace != null else "missing"))
	if workspace == null or workspace.status != "pause_only_available": finish(scene); return
	for i in 12: await physics_frame
	if OS.get_cmdline_user_args().has("--vehicle-lease"):
		# The real owner needs 31 consecutive physics samples before K.
		for i in 48: await physics_frame
	var parked_origin: Vector3 = scene.preview_transport.body.global_position
	if not OS.get_cmdline_user_args().has("--diagnostic-force-still") and not OS.get_cmdline_user_args().has("--vehicle-lease"):
		for i in 600:
			var body: RigidBody3D = scene.preview_transport.body
			if body.linear_velocity.length_squared() <= 0.0001 and body.angular_velocity.length_squared() <= 0.0001 and body._contact_buffer.size() == 0 and not body._contact_buffer.has_gap(): break
			await physics_frame
	# Diagnostic isolation only: this does not prove the drifting parked car can
	# be admitted in the real game. It isolates later population/clock gates.
	if OS.get_cmdline_user_args().has("--diagnostic-force-still"):
		scene.preview_transport.body.freeze = true
		scene.preview_transport.body.linear_velocity = Vector3.ZERO
		scene.preview_transport.body.angular_velocity = Vector3.ZERO
	mouse_left(true); await process_frame
	mouse_left(false); await process_frame
	check(scene._player._free_mouse_look, "user click acquired player control")
	key_k(true); await process_frame
	key_k(false); await process_frame
	check(paused and workspace.active and workspace.enters == 1, "K enters with real three residents")
	if OS.get_cmdline_user_args().has("--vehicle-lease"):
		check(scene.preview_transport.body.freeze and workspace._vehicle_lease.verify(workspace._vehicle_receipt), "parked vehicle owner held while paused")
	if not paused or not workspace.active:
		print("K_ENTRY_DIAGNOSTIC ", JSON.stringify({"status":workspace.status,"body_linear_speed":scene.preview_transport.body.linear_velocity.length(),"body_angular_speed":scene.preview_transport.body.angular_velocity.length(),"body_displacement":scene.preview_transport.body.global_position.distance_to(parked_origin),"parked_brake":scene.preview_transport._parked_brake,"contacts":scene.preview_transport.body._contact_buffer.size(),"contact_gap":scene.preview_transport.body._contact_buffer.has_gap()}))
		check(false, "entry status: " + workspace.status)
		finish(scene); return
	var clock_before: float = scene.preview_melee.gameplay_clock.now_ms()
	var player_before: Transform3D = scene._player.global_transform
	await create_timer(0.1, true).timeout
	check(is_equal_approx(scene.preview_melee.gameplay_clock.now_ms(), clock_before), "melee active time frozen")
	check(scene._player.global_transform == player_before and scene.preview_population.verify_editor_pause(workspace._population_receipt), "player and population frozen")
	var args := OS.get_cmdline_user_args()
	if args.has("--teardown-clean"):
		scene.free()
		await process_frame
		await process_frame
		check(not paused and not has_meta("map_editor_pause_owner_token"), "clean owner teardown releases exact tree lease")
		finish(null)
		return
	if args.has("--teardown-corrupt"):
		set_meta("map_editor_pause_owner_token", "foreign-owner")
		scene.free()
		await process_frame
		await process_frame
		check(paused and get_meta("map_editor_pause_owner_token", "") == "foreign-owner", "foreign tree owner remains paused")
		finish(null)
		return
	if args.has("--teardown-receipt-corrupt"):
		workspace._source_session_bytes = PackedByteArray([0])
		scene.free()
		await process_frame
		await process_frame
		check(paused and has_meta("map_editor_pause_owner_token"), "corrupt owner snapshot retains paused tree")
		finish(null)
		return
	if args.has("--teardown-workspace-only"):
		workspace.free()
		await process_frame
		await process_frame
		check(paused and is_instance_valid(scene), "workspace removal retains live owner pause")
		scene.free()
		await process_frame
		await process_frame
		check(paused, "later owner removal does not silently release orphaned lease")
		finish(null)
		return
	if args.has("--vehicle-session-drift"):
		scene.preview_transport._session = {"fault_injection":"changed_vehicle_session"}
		check(not workspace._vehicle_lease.verify(workspace._vehicle_receipt), "changed vehicle session invalidates owner receipt")
		key_k(true); await process_frame
		key_k(false); await process_frame
		check(paused and workspace.active and scene.preview_transport.body.freeze and workspace.exits == 0, "K refusal retains paused vehicle and gameplay")
		finish(scene)
		return
	if args.has("--water-factory-drift"):
		scene._water_host._factory = null
		check(not workspace._verify_pause(workspace._receipt), "missing water factory invalidates pause owner")
		key_k(true); await process_frame
		key_k(false); await process_frame
		check(paused and workspace.active and workspace.exits == 0, "K refusal retains paused gameplay after water owner loss")
		finish(scene)
		return
	key_k(true); await process_frame
	key_k(false); await process_frame
	check(not paused and not workspace.active and workspace.exits == 1, "K exits and resumes all owners")
	if OS.get_cmdline_user_args().has("--vehicle-lease"):
		check(not scene.preview_transport.body.freeze and not workspace._vehicle_lease.held(), "parked vehicle owner released before gameplay resumes")
	check(scene.preview_melee.gameplay_clock.is_paused() == false, "clock resumed only after owner finalize")
	finish(scene)
