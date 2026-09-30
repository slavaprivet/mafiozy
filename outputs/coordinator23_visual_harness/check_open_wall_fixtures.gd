extends "capture_open_wall_marks.gd"
## Headless geometry/input preflight only. No captures or visual PASS.
func _initialize() -> void:
	started=Time.get_ticks_msec()
	out=get_script().resource_path.get_base_dir().path_join("open_wall_fixture_preflight")
	DirAccess.make_dir_recursive_absolute(out); run.call_deferred()
func _process(_dt:float)->bool:
	if not done and Time.get_ticks_msec()-started>9000: done=true; print("OPEN_FIXTURE_TIMEOUT"); quit(2)
	controls();return false
func run() -> void:
	scene=load("res://scenes/main.tscn").instantiate(); scene.preview_weapons_enabled=true; scene.preview_residents_enabled=true; root.add_child(scene)
	while not scene.preview_ready: await process_frame
	player=scene._player; host=scene.preview_weapons
	if not check(is_instance_valid(host),"actual_weapon_host_loaded"):
		done=true; print("WALL_FIXTURE_PREFLIGHT_SETUP_FAILED ",failures); quit(2); return
	camera=player.get_preview_camera(); parent_camera=camera.get_parent()
	virtual_focus=true; controls(); await frames(45)
	if not await find_wall(): print("WALL_FIXTURE_PREFLIGHT_FAIL ",failures); done=true; quit(1); return
	selected_wall=target.duplicate(); host.equip("ak74")
	for wanted: float in [4.5,10.0]:
		distance_label=str(wanted)
		aim_input(false)
		var wheel:=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.factor=30; wheel.pressed=true; dispatch(wheel)
		var normal: Vector3=selected_wall.normal
		if not await place_supported(selected_wall.point+normal*(wanted-3.0)): break
		var yaw: float=atan2(normal.x,normal.z)
		await orbit(yaw,-.04); aim_input(true); await frames(35)
		if not await after_fixture_aim(): break
		var target_at_fixture:=wall_ray()
		check(not target_at_fixture.is_empty() and target_at_fixture.collider==selected_wall.collider,"fixture_real_ray_same_collider:"+str(wanted))
		if target_at_fixture.is_empty(): break
		aim_input(false); await orbit(yaw+deg_to_rad(5),-.04); await frames(24)
		var distance: float=camera.global_position.distance_to(target_at_fixture.point)
		check(distance>=2 and distance<=5 if wanted<6 else distance>=9 and distance<=11,"actual_camera_distance_band:"+str(wanted))
		print("WALL_FIXTURE_MEASURE ",wanted," actual=",distance," player=",player.global_position.distance_to(target_at_fixture.point)," fov=",camera.fov)
	done=true
	var report: Dictionary={"checks":checks,"failures":failures,"pass":failures.is_empty(),"GPU_checked":false,"scope":"Actual existing wall/floor/capsule, ordinary aim/wheel/orbit; no shooting or screenshot validation"}
	write_json("RESULT.json",report); print("WALL_FIXTURE_PREFLIGHT ",JSON.stringify(report)); scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
