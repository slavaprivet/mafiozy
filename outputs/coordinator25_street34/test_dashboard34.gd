extends "dashboard_base34.gd"
## Reuses accepted native E/W/F/Space fixture helpers; never submits custom
## driving input unless the backend cannot synthesize physical Space.
var dashboard: Node
var speed_observations: Array[Dictionary] = []
var physical_space_supported := true

func bind_scene() -> bool:
	if not await super.bind_scene(): return false
	dashboard = controls.get("dashboard")
	if not is_instance_valid(dashboard): dashboard = controls.get("car_dashboard")
	if not is_instance_valid(dashboard): return false
	camera = p.get_preview_camera()
	return dashboard.has_method("snapshot") and dashboard.snapshot().get("ready",false)

func dashboard_state() -> Dictionary:
	dashboard.update()
	return dashboard.snapshot()

func set_hour(value: float) -> void:
	controls.day_clock.running = false
	controls.day_clock.set_hour(value)
	controls.day_night.apply_hour(value)
	controls.headlights.set_daylight(controls.day_night.daylight)
	if is_instance_valid(controls.get("street_lamps")):
		controls.street_lamps.apply_daylight(controls.day_night.daylight)
	controls._refresh_hint()

func planar_kmh() -> float:
	return Vector2(t.body.linear_velocity.x,t.body.linear_velocity.z).length()*3.6

func assert_native_speed(label: String) -> void:
	var actual: float = planar_kmh()
	var view: Dictionary = dashboard_state()
	check(absf(float(view.get("speed_kmh",-1.0))-actual)<0.0001,label+":reads_current_native_planar_velocity_in_kmh")
	check(str(view.get("speed_text",""))==("%02d" % roundi(actual)),label+":displayed_integer_matches_native_speed")
	check(absf(float(view.get("sampled_speed_mps",-1.0))*3.6-actual)<0.0001,label+":sampled_speed_units_match_native_body")
	speed_observations.append({"label":label,"native_linear_velocity":str(t.body.linear_velocity),"native_planar_kmh":actual,"dashboard":view})

func board_seat(seat: String) -> bool:
	release_keys()
	# One clear, explicit approach placement; the entire entry transition and
	# seat authority are still owned by the native E interaction.
	p.global_position = t.approach(seat)+Vector3.UP*0.03
	p.velocity = Vector3.ZERO
	await step(30)
	await acquire_input()
	key(KEY_E,true)
	for tick in 360:
		await step()
		if t.phase=="SEATED" or finished: break
	key(KEY_E,false)
	await step(3)
	report["board_"+seat] = {"phase":t.phase,"actual_seat":t.active_seat,"error":t.error,"dashboard":dashboard_state()}
	return t.phase=="SEATED" and t.active_seat==seat

func capture(label: String, _reposition: bool = true) -> Dictionary:
	if not gpu or finished: return {}
	dashboard.update()
	await process_frame
	await RenderingServer.frame_post_draw
	var saved: Error = root.get_texture().get_image().save_png(evidence_dir.path_join(label+".png"))
	check(saved==OK,"capture:"+label)
	await step(2)
	return {"path":label+".png","dashboard":dashboard_state(),"viewport":str(root.size)}

func no_input_interception() -> void:
	check(not dashboard.is_processing_input() and not dashboard.is_processing_unhandled_input(),"dashboard_does_not_process_gameplay_input")
	var layers: Array[Node] = game.find_children("CarDashboardLayer","CanvasLayer",true,false)
	check(layers.size()==1,"one_dashboard_canvas_layer")
	if layers.size()!=1: return
	var elements: Array[Node] = layers[0].find_children("*","Control",true,false)
	check(not elements.is_empty(),"dashboard_has_actual_controls")
	for element: Node in elements:
		var control := element as Control
		check(control.mouse_filter==Control.MOUSE_FILTER_IGNORE and control.focus_mode==Control.FOCUS_NONE,"dashboard_control_does_not_intercept:"+str(control.name))

func native_stop() -> void:
	release_keys()
	if absf(signed_speed())<0.06: return
	var brake_key: Key = KEY_S if signed_speed()>0 else KEY_W
	var original_direction: float = signf(signed_speed())
	key(brake_key,true)
	for tick in 180:
		await step()
		if absf(signed_speed())<0.06 or signf(signed_speed())!=original_direction: break
	key(brake_key,false)
	await step(3)

func moving_and_brake(label: String, focus_test: bool) -> void:
	await acquire_input()
	key(KEY_W,true)
	for tick in 150:
		await step()
		if planar_kmh()>4.0 or finished: break
	check(t.body._throttle>0.5 and signed_speed()>0.20,label+":native_W_accelerates_real_vehicle")
	assert_native_speed(label+"_moving")
	check(float(dashboard_state().get("speed_kmh",0.0))>0.7,label+":moving_speed_is_visible")
	report[label+"_moving_capture"] = await capture(label+"_moving")
	key(KEY_W,false)
	key(KEY_SPACE,true)
	await step(3)
	var view: Dictionary = dashboard_state()
	if t.body._handbrake:
		check(view.get("handbrake_on",false),label+":physical_Space_native_handbrake_indicator_on")
		report[label+"_brake_capture"] = await capture(label+"_brake")
		for tick in 150:
			await step()
			if planar_kmh()<0.15 or finished: break
	else:
		physical_space_supported = false
		report.limitations.append(label+": physical Space injection unavailable; handbrake read-model checked only against one accepted native control submission. No brake screenshot claimed.")
		# This is an explicit accepted-control fixture, not keyboard proof.
		# Do not pause transport or hold the car to fabricate a rendered state.
		check(native_fixture(0.0,0.0,true),label+":native_handbrake_read_fixture_accepted")
		check(dashboard_state().get("handbrake_on",false),label+":dashboard_reads_accepted_native_handbrake")
		check(native_fixture(0.0,0.0,false),label+":native_handbrake_read_fixture_released")
	if focus_test:
		p.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await step(3)
		view = dashboard_state()
		check(not t.body._handbrake and not view.get("handbrake_on",true),"focus_loss_clears_accepted_handbrake_and_indicator_without_key_up")
		check(not p._free_mouse_look,"focus_loss_releases_player_controls")
		report.focus_lost = view
	key(KEY_SPACE,false)
	release_keys()
	await step(3)
	check(not dashboard_state().get("handbrake_on",true),label+":Space_release_clears_indicator")
	await acquire_input()
	await native_stop()

func measured_frames(seconds: float) -> Dictionary:
	var samples: Array[Dictionary] = []
	var until: int = Time.get_ticks_usec()+int(seconds*1000000.0)
	var last := 0
	while Time.get_ticks_usec()<until and not finished:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		if last>0:
			samples.append({"frame_ms":(now-last)/1000.0,"engine_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"engine_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"drawcalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)})
		last = now
	var result := {"samples":samples}
	for metric: String in ["frame_ms","engine_process_ms","engine_physics_ms","drawcalls","primitives","static_bytes"]:
		var values: Array[float] = []
		for sample: Dictionary in samples: values.append(float(sample[metric]))
		values.sort()
		if not values.is_empty(): result[metric] = {"count":values.size(),"p50":values[int(values.size()*.5)],"p95":values[mini(values.size()-1,int(values.size()*.95))],"max":values[-1]}
	return result

func paired_hud_cost() -> void:
	if not gpu: return
	await native_stop()
	check(planar_kmh()<1.0,"HUD_cost_fixture_vehicle_stopped_by_native_controls")
	var fixed := Camera3D.new()
	fixed.name = "DashboardCostCamera"
	fixed.fov = camera.fov
	game.add_child(fixed)
	fixed.global_transform = camera.global_transform
	fixed.make_current()
	var at: Transform3D = fixed.global_transform
	var body_at: Vector3 = t.body.global_position
	dashboard.dispose()
	await step(60)
	check(game.find_children("CarDashboardLayer","CanvasLayer",true,false).is_empty(),"HUD_cost_baseline_removes_only_dashboard_canvas")
	var without: Dictionary = await measured_frames(3.0)
	check(dashboard.configure(game,p,t,controls.headlights),"HUD_restores_after_cost_baseline")
	dashboard.update()
	await step(60)
	var with_hud: Dictionary = await measured_frames(3.0)
	check(dashboard_state().get("visible",false),"HUD_visible_after_cost_restore")
	check(fixed.global_transform.is_equal_approx(at),"HUD_pair_same_camera")
	check(game._block.buildings.size()==8 and game.preview_population.hit_owners.size()==3,"HUD_pair_keeps_eight_buildings_three_active_residents")
	report.hud_cost = {"without":without,"with":with_hud,"camera":str(at),"fov":fixed.fov,"viewport":str(root.size),"vehicle_displacement_m":t.body.global_position.distance_to(body_at),"policy":"One paired HUD off/on measurement at fixed native-view camera and same1280x720/144fps,1s warmup+3s observed per state. No vehicle freeze, actor removal, scene pause or disabled residents. Active-world drift is possible; capped wall frames do not isolate CPU/GPU work. PNG capture excluded."}
	camera.make_current()
	fixed.queue_free()
	await acquire_input()

func run() -> void:
	gpu = DisplayServer.get_name()!="headless"
	var run_id := "gpu01" if gpu else "headless01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run-id="): run_id = arg.trim_prefix("--run-id=")
	evidence_dir = get_script().resource_path.get_base_dir().path_join(run_id)
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	report = {"limitations":["Logical native key-event fixture in the loaded8-building/3-resident preview quarter, not manual keyboard or full-city acceptance."]}
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	Engine.max_fps = 144
	if gpu: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	create_timer(110.0).timeout.connect(func(): check(false,"bounded110_second_watchdog"); finish())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if not await bind_scene():
		check(false,"dashboard_combined_scene_ready")
		finish(); return
	check(game.PREVIEW_RUNTIME_REVISION=="s01-20260930-quality25a","exact_integrated25a_revision")
	root34_dashboard_guards()
	var notes := game.find_child("PreviewUpdates",true,false)
	var packed_notes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	check(notes!=null and not notes.get_status().get("restart_required",true) and notes.get_status().get("notes",{}).get("title","")==packed_notes.get("title") and notes.get_status().get("notes",{}).get("items",[])==packed_notes.get("items",[]),"current_integrated25a_notes_visible_without_overlay")
	if gpu and notes!=null:
		check((notes as Control).get_global_rect().end.y<528.0,"notes_leave_clear_space_above_dashboard")
	check(controls.street_lamps_status=="ready" and controls.street_lamps.entries.size()==8,"combined_eight_street_lamps_ready")
	check(not dashboard_state().get("visible",true),"dashboard_hidden_on_foot")
	no_input_interception()
	var passenger: bool = await board_seat("front_right")
	check(passenger,"native_E_enters_actual_passenger_seat")
	if not passenger: finish(); return
	check(not dashboard_state().get("visible",true),"dashboard_hidden_for_native_passenger")
	var exited: bool = await exit_before_fixture()
	check(exited,"native_E_exits_passenger_seat")
	if not exited: finish(); return
	check(not dashboard_state().get("visible",true),"dashboard_hidden_after_passenger_exit")
	var boarded: bool = await board_seat("front_left")
	check(boarded,"native_E_enters_actual_driver_seat")
	if not boarded: finish(); return
	check(dashboard_state().get("visible",false) and dashboard_state().get("driving",false),"dashboard_visible_only_for_native_driver")
	set_hour(12.0)
	assert_native_speed("day_idle")
	report.day_idle_capture = await capture("day_idle")
	var previous_lights: bool = controls.headlights.enabled
	key(KEY_F,true); key(KEY_F,false)
	await step(3)
	check(controls.headlights.enabled!=previous_lights and dashboard_state().get("headlights_on",previous_lights)==controls.headlights.enabled,"native_F_toggles_headlights_and_dashboard_indicator")
	await moving_and_brake("day",false)
	set_hour(22.0)
	assert_native_speed("night_idle")
	report.night_idle_capture = await capture("night_idle")
	await moving_and_brake("night",true)
	await paired_hud_cost()
	no_input_interception()
	exited = await exit_before_fixture()
	check(exited,"native_E_exits_driver_seat")
	if not exited: finish(); return
	check(not dashboard_state().get("visible",true),"dashboard_hidden_after_driver_exit")
	var old_dashboard: WeakRef = weakref(dashboard)
	var old_layers: Array[Node] = game.find_children("CarDashboardLayer","CanvasLayer",true,false)
	var old_layer: WeakRef = weakref(old_layers[0]) if old_layers.size()==1 else null
	check(reload_current_scene()==OK,"native_scene_reload_requested")
	await process_frame
	if not await bind_scene():
		check(false,"dashboard_rebound_after_scene_reload")
		finish(); return
	check(old_dashboard.get_ref()==null and old_layer!=null and old_layer.get_ref()==null,"old_dashboard_owner_and_layer_freed_on_reload")
	check(game.find_children("CarDashboardLayer","CanvasLayer",true,false).size()==1 and get_nodes_in_group("mafiozi_quick_controls").size()==1,"reload_has_one_dashboard_and_one_controls_owner")
	check(not dashboard_state().get("visible",true),"reload_on_foot_dashboard_hidden")
	finish()

func finish() -> void:
	if finished: return
	finished = true
	release_keys()
	report.speed_observations = speed_observations
	report.physical_space_supported = physical_space_supported
	var result := {"checks":checks,"failures":failures,"gpu":gpu,"report":report,"test_sha256":FileAccess.get_sha256(get_script().resource_path)}
	var file := FileAccess.open(evidence_dir.path_join("RESULT.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(result,"\t"))
	print("DASHBOARD_RESULT ",checks," checks, ",failures.size()," failures: ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func root34_dashboard_guards() -> void:
	var lamps: Node = controls.street_lamps
	check(game.get_node("QuickControlsHook").get_script().resource_path == "res://scripts/quick_controls/scene_hook.gd", "dashboard_integrated_hook")
	check(controls.get_script().resource_path == "res://scripts/quick_controls/quick_controls.gd", "dashboard_integrated_controls")
	check(dashboard.get_script().resource_path == "res://scripts/quick_controls/car_dashboard.gd", "dashboard_integrated_owner")
	check(lamps.get_script().resource_path == "res://scripts/quick_controls/street_lamps.gd", "dashboard_integrated_lamps")
	check(lamps.sound.get_script().resource_path == "res://scripts/quick_controls/street_glass_sound.gd", "dashboard_integrated_sound")
	var lantern: Script = lamps.get_script().get_script_constant_map().get("Lantern")
	check(lantern != null and lantern.resource_path == "res://scripts/quick_controls/street_lamp_visual.gd", "dashboard_integrated_lantern")
	var notes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	check(notes is Dictionary and notes.get("runtime_revision") == "s01-20260930-quality25a" and notes.get("items", []).size() == 5, "dashboard_notes_match_integrated_revision")
	check(notes is Dictionary and notes.get("items", []).size() > 0 and "фонар" in str(notes.items[0]).to_lower(), "dashboard_first_note_has_lamps")
	check(game._block.buildings.size() == 8 and game.preview_population.hit_owners.size() == 3, "dashboard_full_eight_building_three_resident_scene")
	check(controls.headlights.get_script().resource_path == "res://scripts/quick_controls/car_headlights.gd", "dashboard_integrated_headlights")
	check(controls.rear_lights.get_script().resource_path == "res://scripts/quick_controls/car_rear_lights.gd", "dashboard_integrated_rear_lights")
	check(controls.horn.get_script().resource_path == "res://scripts/quick_controls/car_horn.gd", "dashboard_integrated_horn")
	check(controls.day_night.get_script().resource_path == "res://scripts/quick_controls/day_night.gd", "dashboard_integrated_day_night")
	check(controls.day_clock.get_script().resource_path == "res://scripts/quick_controls/day_night_clock.gd", "dashboard_integrated_day_clock")
	check(FileAccess.get_sha256("res://audio/street_glass_break_01.bytes") == "6ce9ebf4036f856e42181a224d9a7a01e2783ca8a23b8f4fc51a510accaaaf56", "dashboard_packed_audio:audio/street_glass_break_01.bytes")
	check(FileAccess.get_sha256("res://audio/street_glass_break_02.bytes") == "9e92dafb70f165ac5b12581b65f95203b17ee66a43b9c5494b0af7585da71168", "dashboard_packed_audio:audio/street_glass_break_02.bytes")
	check(FileAccess.get_sha256("res://audio/street_glass_break_03.bytes") == "f05f418fb070369723b597a8a7d54a801b69aac007dcb650ee131e711b5ac22e", "dashboard_packed_audio:audio/street_glass_break_03.bytes")
