extends "entry_c4_home_damage58_v2.gd"
var component: Node

func _start() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out_path=arg.trim_prefix("--qa-out=")
	if out_path.is_empty():quit(2);return
	var scene: Node3D=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	component=load(get_script().resource_path.get_base_dir().path_join("home_damage_driver58_v2.gd")).new()
	scene.add_child(component)
	var stop: int=Time.get_ticks_msec()+210000
	while Time.get_ticks_msec()<stop:
		await process_frame
		if not component.failed.is_empty():break
		if component.home!=null and component.home.snapshot().sleeping:break
	if not check(component.failed.is_empty() and component.home!=null and component.home.snapshot().sleeping,"original resident physically reached assigned bed and host committed sleep",component.snapshot()):finish();return
	check(Engine.physics_ticks_per_second==60,"native physics60",Engine.physics_ticks_per_second)
	evidence.sleep_before_damage=component.home.snapshot()
	evidence.visual_companion="runs/home_damage01/sleep_resident3_native.png; exact stage05 rendered native pose; this test is headless"
	# Base geometry gates are replaced here by exact scene-source verification in
	# the runner. This is a new sleeping-interruption test, not a retry of C4_03.
	finished_c4=true
	await c4_case(scene)
	evidence.component=component.snapshot()
	check(component.damage_trigger_frame>=0 and component.sleep_cancel_frame>=component.damage_trigger_frame and component.sleep_cancel_frame-component.damage_trigger_frame<=3,"C4 cancels sleep within three native ticks",{"damage":component.damage_trigger_frame,"cancel":component.sleep_cancel_frame})
	check(component.damage_trigger_frame>=0 and component.sleep_cancel_frame>=0 and component.exit_frame>=component.sleep_cancel_frame,"damaged-home owner physically exits before release",component.exit_frame)
	check(component.max_required_idle<=10.0,"home required motion gate remains10seconds",component.max_required_idle)
	finish()

func finish() -> void:
	finished_c4=true;tracking58=false
	if is_instance_valid(component):evidence.component=component.snapshot()
	evidence.scope="Exact stage05 original resident3 native walk/bed pose/actual C4 interruption/exit/reset; component intent scheduling; not natural routines or performance"
	super.finish()

func capture_bed58(scene: Node3D) -> void:
	var slot: Dictionary=scene.preview_homes58.registry58.assigned("resident_3")
	var house: Node3D=slot.house.get_ref()
	var native_camera: Camera3D=scene._player.get_preview_camera()
	var camera:=Camera3D.new();camera.name="QA58BedInspectionCamera";scene.add_child(camera)
	camera.global_position=house.to_global(Vector3(0,2.45,1.0));camera.look_at(Vector3(slot.bed_surface)+Vector3.UP*.12,Vector3.UP);camera.fov=68;camera.make_current()
	await process_frame;await RenderingServer.frame_post_draw
	var picture: Image=root.get_texture().get_image()
	if check(picture!=null and not picture.is_empty(),"native rendered bed-pose frame available"):
		var path: String=out_path.path_join("sleep_resident3_native.png")
		check(picture.save_png(path)==OK,"native bed PNG saved")
		evidence.sleep_image={"path":path,"camera":"native QA inspection camera; no NPC/body pose or transform change","physics_frame":Engine.get_physics_frames(),"home":component.home.snapshot(),"actor_position":component.actor.global_position,"bed_surface":slot.bed_surface}
	native_camera.make_current();camera.queue_free()

func mark_damage58() -> void:
	component.damage_trigger_frame=Engine.get_physics_frames()

func wait_exit58() -> void:
	var deadline: int=Time.get_ticks_msec()+60000
	while component.home.active() and Time.get_ticks_msec()<deadline:
		await process_frame
