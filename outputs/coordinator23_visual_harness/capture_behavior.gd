extends SceneTree
## ROOT-OWNED GPU execution only. This file has NOT been run with GPU by its author.
## --path candidate --script ABS/capture_behavior.gd --position -32000,-32000
## -- --qa-out=ABS_OUTPUT [--qa-resolution=1280x720|1920x1080|both]
## Ordinary attached spring camera; scripted player positioning/orbits are logged.
## This is behavior/visual acceptance, NOT a benchmark/FPS or desktop focus test.
const MAX_MS := 80000
const FILES := ["res://scripts/main.gd","res://scripts/preview_player.gd","res://scripts/preview_population.gd","res://scripts/weapons/preview_weapons.gd","res://scripts/weapons/preview_weapon_cargo.gd","res://scripts/weapons/walk_weapon_ui.gd","res://scripts/weapons/walk_cargo_card.gd","res://scripts/weapons/cargo_aim_picker.gd","res://scripts/weapons/weapon_pickup_visuals.gd","res://scripts/weapons/ground_weapon_rules.gd"]
var scene: Node3D
var player: CharacterBody3D
var weapons: Node
var cargo: Node
var transport: Node3D
var camera: Camera3D
var camera_parent: Node
var ui: Control
var out := ""
var resolution_arg := "both"
var started_ms := 0
var done := false
var phase_name := "init"
var failure_labels: Array[String]=[]
var checks := 0
var events: Array=[]
var captures: Array=[]
var input_log: Array=[]
var focus_resumes: Array=[]
var initial_hashes: Dictionary={}
var draw_count := 0
var controls_owned := false
var native_size := Vector2i(1280,720)
var resident_ids: Array=[]
var visibility_probes := false

func _initialize() -> void:
	started_ms=Time.get_ticks_msec()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-out="): out=argument.trim_prefix("--qa-out=")
		if argument.begins_with("--qa-resolution="): resolution_arg=argument.trim_prefix("--qa-resolution=")
		if argument=="--qa-visibility-probes": visibility_probes=true
	if out.is_empty(): push_error("--qa-out absolute output required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(out)
	# No focus/capture theft. Place this QA-owned window outside every monitor.
	# Root launcher must supply offscreen --position as well to avoid startup flash.
	root.unfocusable=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	RenderingServer.frame_post_draw.connect(func(): draw_count+=1)
	run.call_deferred()

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec()-started_ms>=MAX_MS:
		check(false,"deadline_80_seconds:"+phase_name); finish("timeout")
	virtual_controls()
	return false

func _physics_process(_delta: float) -> bool:
	virtual_controls(); return false

func virtual_controls() -> void:
	# Only this separate QA process is scripted; do not change production guards.
	# NO_FOCUS may send blur during the run. Preserve scripted behavior workload,
	# while the actual desktop cursor ALWAYS remains visible and uncaptured.
	if controls_owned and is_instance_valid(player) and not player._free_mouse_look:
		focus_resumes.append({"phase":phase_name,"physics_frame":Engine.get_physics_frames()})
		player._free_mouse_look=true
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func check(value: bool,label: String) -> bool:
	checks+=1
	if not value and not failure_labels.has(label): failure_labels.append(label); print("QA_FAIL ",label)
	return value

static func vector(value: Vector3) -> Array: return [value.x,value.y,value.z]

func hashes() -> Dictionary:
	var result: Dictionary={}
	for path: String in FILES: result[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
	return result

func snapshot(label: String) -> Dictionary:
	var data: Dictionary={"label":label,"phase":phase_name,"elapsed_ms":Time.get_ticks_msec()-started_ms,"resolution":[native_size.x,native_size.y],"draw_count":draw_count,"measurement":false}
	if not is_instance_valid(player): return data
	data.player={"position":vector(player.global_position),"velocity":vector(player.velocity),"source_visual_yaw":player._visual.global_rotation.y,"camera_yaw":player._camera_yaw,"camera_pitch":player._camera_pitch,"camera_distance":player.camera_distance,"controls":player._free_mouse_look,"pose_authority":str(player._pose_authority),"posture":weapons.posture.posture_state(),"capsule_height":player.get_node("PlayerCapsule").shape.height}
	data.camera={"position":vector(camera.global_position),"forward":vector(-camera.global_basis.z),"top_level":camera.top_level,"same_parent":camera.get_parent()==camera_parent,"parent_path":str(camera.get_parent().get_path()),"spring_length":player._spring_arm.spring_length,"fov":camera.fov}
	data.weapons={"equipped":weapons.fire_state.weaponId,"ammo":weapons.fire_state.duplicate(true),"item_uid":weapons.inventory.get_item_uid(),"owned":weapons.inventory.get_owned_ids(),"menu_open":weapons.menu_open,"reticle":weapons._crosshair.visible}
	# Passive diagnostics only: current_muzzle() INVALIDATES/HIDES stale poses.
	# A diagnostic call here previously hid guns immediately before capture freeze.
	var presentation: RefCounted=weapons.presentation
	var prior_receipt: Dictionary=presentation.get("_receipt")
	data.weapons.last_applied_receipt=prior_receipt.duplicate(true)
	data.weapons.last_applied_receipt.erase("_rig_world")
	data.weapons.last_applied_receipt.erase("_socket_pose")
	data.weapons.last_applied_receipt.erase("_visual_local")
	data.weapons.receipt_is_passive_not_shot_admission=true
	var held_visual: Node3D=presentation.get("_visual")
	data.weapons.visual_exists=is_instance_valid(held_visual)
	data.weapons.visual_visible=is_instance_valid(held_visual) and held_visual.is_visible_in_tree()
	data.weapons.pose_revision=player.get("_pose_revision")
	data.weapons.pose_epoch=player.get("_pose_epoch")
	var skeleton: Skeleton3D=player.get("_pose_skeleton")
	if is_instance_valid(skeleton):
		var head_bones:Array=[]
		for bone: int in skeleton.get_bone_count():
			var bone_name: String=skeleton.get_bone_name(bone)
			if "head" in bone_name.to_lower() or "neck" in bone_name.to_lower():
				head_bones.append({"name":bone_name,"pose":str(skeleton.get_bone_global_pose(bone))})
		data.player.head_bones=head_bones
	data.cargo={"context":cargo.aim_context(),"summary":cargo.cargo.summary(cargo.generation),"visual":cargo.renderer.debug_snapshot(),"lid_open":transport.compartments.is_open("trunk")}
	data.ui={"launcher_rect":str(ui.launcher.get_global_rect()),"menu_rect":str(ui.menu.get_global_rect()),"logical_viewport":str(root.get_visible_rect()),"window_position":str(DisplayServer.window_get_position()),"window_visible":root.visible}
	data.ui.context_card_rect=str(cargo._hint.get_global_rect())
	data.ui.context_card_visible=cargo._hint.is_visible_in_tree()
	if ui.crosshair.has_method("snapshot"): data.ui.crosshair=ui.crosshair.snapshot()
	data.pickup_projection=pickup_projection()
	var capsule: CollisionShape3D=player.get_node("PlayerCapsule")
	var radius: float=capsule.shape.radius
	var height: float=capsule.shape.height
	data.player.capsule_projection=project_box(AABB(Vector3(-radius,-height*.5,-radius),Vector3(radius*2,height,radius*2)),capsule.global_transform)
	if scene.preview_population!=null:
		data.residents=scene.preview_population.residents.snapshot()
	return data

func project_box(box: AABB, transform: Transform3D) -> Dictionary:
	var projected: Rect2; var first:=true
	for corner: int in 8:
		var world: Vector3=transform*box.get_endpoint(corner)
		if camera.is_position_behind(world): return {"ok":false,"behind":true}
		var point: Vector2=camera.unproject_position(world)
		if first: projected=Rect2(point,Vector2.ZERO); first=false
		else: projected=projected.expand(point)
	return {"ok":true,"rect":str(projected),"position":[projected.position.x,projected.position.y],"size":[projected.size.x,projected.size.y]}

func pickup_projection() -> Array:
	# QA-only passive original bounds. Does not invoke picking or alter authority.
	var rows: Array=[]
	var ground: Dictionary=cargo.renderer.get("_ground")
	for row: Dictionary in ground.values(): rows.append(row)
	var trunks: Dictionary=cargo.renderer.get("_trunks")
	for binding: Dictionary in trunks.values():
		for row: Dictionary in binding.items.values(): rows.append(row)
	var result: Array=[]
	for row: Dictionary in rows:
		var visual: Node3D=row.get("visual")
		if not is_instance_valid(visual): continue
		var entry: Dictionary=project_box(row.bounds,visual.global_transform)
		entry.uid=row.uid; entry.weapon_id=row.weapon_id; entry.visible=visual.is_visible_in_tree()
		entry.world_transform=str(visual.global_transform)
		entry.local_bounds=str(row.bounds)
		entry.note="Projected original mesh bounds only; not pixel visibility or occlusion acceptance"
		result.append(entry)
	return result

func event(label: String,details: Dictionary={}) -> void:
	var row:=snapshot(label); row.details=details; events.append(row)
	FileAccess.open(out.path_join("PROGRESS.json"),FileAccess.WRITE).store_string(JSON.stringify({"phase":phase_name,"checks":checks,"failures":failure_labels,"last":row},"\t"))

func frames(count: int) -> void:
	for index: int in count:
		if done: return
		await physics_frame
		await process_frame

func dispatch(event_input: InputEvent) -> void:
	virtual_controls()
	input_log.append({"phase":phase_name,"event":event_input.as_text(),"frame":Engine.get_physics_frames(),"path":"root.push_input(in_local_coords=true)"})
	root.push_input(event_input,true)
	# Menu opening/closing may call production mouse capture. Undo desktop
	# capture immediately before returning to the OS event loop.
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func key(code: Key,pressed: bool=true) -> void:
	var value:=InputEventKey.new(); value.keycode=code; value.physical_keycode=code; value.pressed=pressed
	dispatch(value)

func tap(code: Key) -> void:
	key(code,true); await frames(1); key(code,false); await frames(2)

func mouse_button(at: Vector2,pressed: bool) -> void:
	var value:=InputEventMouseButton.new(); value.position=at; value.global_position=at
	value.button_index=MOUSE_BUTTON_LEFT; value.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; value.pressed=pressed; dispatch(value)

func click(control: Control) -> bool:
	if not check(is_instance_valid(control) and control.is_visible_in_tree(),"click_visible:"+str(control.name)): return false
	var at: Vector2=control.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new(); move.position=at; move.global_position=at; dispatch(move)
	mouse_button(at,true); mouse_button(at,false); await frames(3)
	return true

func orbit(yaw: float,pitch: float,label: String,settle: int=3) -> void:
	# Feed ordinary mouse-look deltas. No camera top_level, position, transform,
	# detached render camera, look_at, ray-triangle steering or forced bone pose.
	var move:=InputEventMouseMotion.new()
	move.relative=Vector2(wrapf(player._camera_yaw-yaw,-PI,PI)/player.mouse_sensitivity,(player._camera_pitch-clampf(pitch,-1.05,.45))/player.mouse_sensitivity)
	dispatch(move); await frames(settle)
	event(label,{"scripted_orbit":true,"requested_yaw":yaw,"requested_pitch":pitch})
	check(not camera.top_level and camera.get_parent()==camera_parent,label+":ordinary_attached_camera")

func place_player(position: Vector3,label: String) -> void:
	# Explicit fixture positioning allowed by root; never counted as walking.
	var old:=player.global_position
	player.global_position=position
	event(label,{"scripted_player_position":true,"from":vector(old),"to":vector(position)})
	await frames(8)

func capture(label: String) -> void:
	if done: return
	var basename: String=str(native_size.x)+"x"+str(native_size.y)+"_"+label
	phase_name="capture:"+basename
	var receipt:=snapshot(basename)
	# Freeze only AFTER actual actions/physics settled. This isolated still-capture
	# phase is never used as performance evidence. Children freeze too.
	var process_mode_before:=scene.process_mode
	scene.process_mode=Node.PROCESS_MODE_DISABLED
	var target:=draw_count+2; var deadline:=Time.get_ticks_msec()+3000
	while not done and draw_count<target and Time.get_ticks_msec()<deadline: await process_frame
	if done: return
	var presented:=check(draw_count>=target,basename+":frame_post_draw")
	var path:=out.path_join(basename+".png")
	if presented:
		var picture:=root.get_texture().get_image()
		var available:=picture!=null and not picture.is_empty()
		check(available,basename+":readback")
		if available:
			check(picture.get_width()==native_size.x and picture.get_height()==native_size.y,basename+":native_pixel_size")
			var first: Color=picture.get_pixel(picture.get_width()/2,picture.get_height()/2)
			var variation:=0.0
			for fraction: Vector2 in [Vector2(.1,.1),Vector2(.5,.1),Vector2(.9,.1),Vector2(.1,.8),Vector2(.9,.8)]:
				var pixel: Color=picture.get_pixel(int(picture.get_width()*fraction.x),int(picture.get_height()*fraction.y))
				variation=maxf(variation,absf(pixel.r-first.r)+absf(pixel.g-first.g)+absf(pixel.b-first.b))
			check(variation>.02,basename+":nonblank_render")
			check(picture.save_png(path)==OK,basename+":saved")
			receipt.image={"path":path,"sha256":FileAccess.get_sha256(path),"width":picture.get_width(),"height":picture.get_height(),"sample_variation":variation}
	receipt.frozen_for_capture_only=true; receipt.performance_valid=false
	captures.append(receipt)
	FileAccess.open(out.path_join(basename+".json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	scene.process_mode=process_mode_before
	await frames(2)

func select_via_menu(id: String) -> bool:
	if not weapons.menu_open: await tap(KEY_Q)
	if not check(weapons.menu_open,"Q_opens_menu_for:"+id): return false
	var button: Control=ui.choices[id].button
	ui.scroll.ensure_control_visible(button); await frames(3)
	await click(button)
	return check(weapons.fire_state.weaponId==id and not weapons.menu_open,"real_card_select:"+id)

func trunk_orbit_for(uid: String="") -> bool:
	# Finite ordinary mouse orbit grid around known trunk. No model vertices,
	# AABB/triangle centre targeting or camera relocation. All attempts recorded.
	var yaws: Array=[0.0] if uid.is_empty() else [.36,.32,.40,.28,.44,.24,.48]
	var pitches: Array=[-.55,-.60,-.50,-.65] if uid.is_empty() else [-.60,-.56,-.64,-.52,-.68,-.70]
	for yaw_offset: float in yaws:
		for pitch: float in pitches:
			if done: return false
			await orbit(transport.body.global_rotation.y+yaw_offset,pitch,"trunk_orbit_attempt",2)
			var context: Dictionary=cargo.aim_context()
			if context.aimed_trunk and (uid.is_empty() or str(context.item_uid)==uid):
				event("trunk_orbit_admitted",{"uid":uid,"context":context}); return true
	check(false,"bounded_ordinary_orbit_could_not_find:"+uid)
	return false

func set_resolution(value: Vector2i) -> void:
	native_size=value; root.size=value
	# Preserve project's canvas_items stretch contract; verify actual PNG size.
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	await frames(6)
	event("resolution",{"native":str(value),"content_scale_size":str(root.content_scale_size),"content_scale_mode":root.content_scale_mode})

func run_resolution(value: Vector2i) -> void:
	await set_resolution(value)
	phase_name="launcher_click_free_cursor"
	controls_owned=false; player.set_mouse_captured(false)
	await frames(2)
	await click(ui.launcher)
	if not check(weapons.menu_open and player._free_mouse_look,"launcher_click_from_free_cursor_opens_arsenal"): return
	controls_owned=true
	await capture("01_menu")
	if not await select_via_menu("ak74"): return
	await tap(KEY_Q); ui.scroll.ensure_control_visible(ui.choices.ak74.button); await frames(3)
	check(ui.choices.ak74.detail.text.begins_with("В РУКАХ"),"menu_selected_AK_marker")
	await capture("02_selected_AK")
	await tap(KEY_Q)
	var original_ammo: Dictionary=weapons.fire_state.duplicate(true)
	var uid: String=weapons.inventory.get_item_uid("ak74")
	var access: Dictionary=transport.compartments.access_profile("trunk")
	var stand: Vector3=transport.body.to_global(access.position_local_m+access.outward_local*.7); stand.y=.01
	await place_player(stand,"rear_trunk_fixture")
	if not transport.compartments.is_open("trunk"): await tap(KEY_E)
	await frames(65)
	check(transport.compartments.is_open("trunk"),"real_E_opens_trunk")
	if not await trunk_orbit_for(): return
	await tap(KEY_G); await frames(8)
	if not check(not weapons.inventory.get_owned_ids().has("ak74") and weapons.fire_state.weaponId=="none","real_G_stores_AK"): return
	check(cargo.cargo.summary(cargo.generation).count==1,"one_original_model_in_trunk")
	check(weapons._crosshair.visible,"unarmed_reticle_after_G")
	if not await trunk_orbit_for(uid):
		await capture("03_cargo_pick_failure"); return
	await frames(10)
	check(cargo._hint.visible,"named_cargo_plate_visible")
	await capture("03_visible_cargo_AK")
	if visibility_probes:
		# An additional observational photo, not the exact-reticle E evidence.
		# Small legal player fixture offset; original spring camera and gun untouched.
		var before_probe: Vector3=player.global_position
		await place_player(before_probe+transport.body.global_basis.x*.65,"cargo_visible_side_fixture")
		await orbit(transport.body.global_rotation.y,-.60,"cargo_visible_side_orbit",8)
		await capture("03b_cargo_original_model_side_probe")
		await place_player(before_probe,"cargo_return_exact_pick_fixture")
		if not await trunk_orbit_for(uid): return
	await tap(KEY_E); await frames(5)
	check(weapons.fire_state.weaponId=="ak74" and weapons.inventory.get_item_uid("ak74")==uid,"real_E_exact_UID_autoequip")
	check(weapons.fire_state.magazine==original_ammo.magazine and weapons.fire_state.reserveAmmo==original_ammo.reserveAmmo,"cargo_roundtrip_ammo_preserved")
	check(cargo.cargo.summary(cargo.generation).count==0,"taken_model_removed_from_trunk")
	await capture("04_taken_AK")
	# Source ground test uses original main's safe existing street, not a fake floor.
	await place_player(Vector3(31,.01,-18),"ground_street_fixture")
	await orbit(0,-.35,"street_orbit",6)
	await tap(KEY_G); await frames(30)
	var drops: Array=weapons.inventory.get_dropped()
	if not check(drops.size()==1 and weapons.fire_state.weaponId=="none","real_G_ground_drop"): return
	check(weapons.inventory.get_drop_item(drops[0].uid).uid==uid,"ground_drop_exact_UID")
	check(cargo.renderer.debug_snapshot().falling_count==0,"real_ground_fall_settled")
	await capture("05_ground_pickup_plate")
	if visibility_probes:
		var before_probe: Vector3=player.global_position
		await place_player(before_probe+Vector3(.65,0,0),"ground_visible_side_fixture")
		await orbit(0,-.35,"ground_visible_side_orbit",8)
		await capture("05b_ground_original_model_side_probe")
		await place_player(before_probe,"ground_return_pick_fixture")
	await tap(KEY_E); await frames(5)
	check(weapons.fire_state.weaponId=="ak74" and weapons.inventory.get_item_uid("ak74")==uid,"real_ground_E_autoequip_same_UID")
	check(weapons.inventory.get_dropped().is_empty(),"ground_model_removed_after_E")
	await capture("06_ground_taken")
	await orbit(.70,-.24,"armed_look_right",8); await capture("07_armed_look_right")
	await orbit(-.70,-.24,"armed_look_left",8); await capture("08_armed_look_left")
	await select_via_menu("none")
	await orbit(.70,-.24,"unarmed_look_right",8); await capture("09_unarmed_look_right")
	await orbit(-.70,-.24,"unarmed_look_left",8); await capture("10_unarmed_look_left")
	await select_via_menu("ak74")
	await orbit(0,-.32,"stance_orbit",3)
	await tap(KEY_C); await frames(50)
	check(weapons.posture.posture_state().target=="crouch","real_C_crouch_target")
	await capture("11_crouch")
	await tap(KEY_Z); await frames(60)
	check(weapons.posture.posture_state().target=="prone","real_Z_prone_target")
	await capture("12_prone")
	var before:=player.global_position
	# Continuous movement is polled through InputMap, not event callbacks. Record
	# this standard input-action fixture separately from viewport UI/key dispatch.
	Input.action_press(player.ACTION_FORWARD)
	input_log.append({"phase":phase_name,"path":"Input.action_press forward","frames":36})
	await frames(36)
	var moved:=player.global_position.distance_to(before)
	check(moved>.05,"actual_prone_forward_movement")
	event("prone_move",{"from":vector(before),"to":vector(player.global_position),"distance":moved})
	await capture("13_crawl_moving")
	Input.action_release(player.ACTION_FORWARD); await frames(5)
	await tap(KEY_Z); await frames(60)
	check(weapons.posture.posture_state().target=="stand","real_Z_returns_stand")
	# User requested S-facing and original aim camera: actual native inputs.
	Input.action_press(player.ACTION_BACK); await frames(35)
	await capture("15_S_faces_camera")
	Input.action_release(player.ACTION_BACK); await frames(8)
	var aim_event:=InputEventMouseButton.new(); aim_event.button_index=MOUSE_BUTTON_RIGHT; aim_event.pressed=true; dispatch(aim_event)
	await frames(35)
	check(absf(camera.fov-38.0)<.12,"user_requested_RMB_FOV38")
	check(ui.crosshair.has_method("snapshot"),"source_crosshair_Control_loaded")
	if ui.crosshair.has_method("snapshot"):
		var reticle: Dictionary=ui.crosshair.snapshot()
		check(ui.crosshair.visible and reticle.arms and reticle.rects.size()==4,"RMB_source_four_arms_visible")
		check(reticle.gap>=3 and reticle.gap<=64,"source_crosshair_spread_gap_bounds")
	await capture("16_RMB_shoulder")
	aim_event=InputEventMouseButton.new(); aim_event.button_index=MOUSE_BUTTON_RIGHT; aim_event.pressed=false; dispatch(aim_event)
	await select_via_menu("sniper")
	aim_event=InputEventMouseButton.new(); aim_event.button_index=MOUSE_BUTTON_RIGHT; aim_event.pressed=true; dispatch(aim_event)
	await frames(25); check(weapons.aim_camera.scoped(),"real_RMB_sniper_scope")
	check(absf(camera.fov-14.0)<.12 and not ui.crosshair.visible,"sniper_FOV14_hides_ordinary_reticle")
	await capture("17_sniper_scope")
	aim_event=InputEventMouseButton.new(); aim_event.button_index=MOUSE_BUTTON_RIGHT; aim_event.pressed=false; dispatch(aim_event)
	await select_via_menu("ak74"); await frames(8)
	controls_owned=false
	await tap(KEY_ESCAPE)
	check(not player._free_mouse_look and not weapons.menu_open,"Esc_releases_controls")
	await frames(3)
	await capture("14_Esc_free_cursor")

func run() -> void:
	if not check(DisplayServer.get_name()!="headless","requires_actual_GPU_not_headless"): finish("invalid_backend"); return
	if resolution_arg not in ["both","1280x720","1920x1080"]: check(false,"invalid_resolution"); finish("invalid_arguments"); return
	initial_hashes=hashes()
	scene=load("res://scenes/main.tscn").instantiate()
	scene.preview_weapons_enabled=true; scene.preview_residents_enabled=true
	root.add_child(scene)
	while not done and not scene.preview_ready: await process_frame
	if done: return
	player=scene._player; weapons=scene.preview_weapons; transport=scene.preview_transport
	if not check(is_instance_valid(weapons) and is_instance_valid(transport),"actual_main_weapons_transport"): finish("setup_failed"); return
	cargo=weapons.get_node_or_null("WeaponCargo"); camera=player.get_preview_camera(); camera_parent=camera.get_parent(); ui=weapons._walk_ui
	if not check(is_instance_valid(cargo) and is_instance_valid(ui),"actual_cargo_UI_hosts"): finish("setup_failed"); return
	check(ui.textures.size()==15,"all_fifteen_original_model_photographs_loaded")
	for id: String in ui.FAMILIES:
		check(ui.textures.get(id)!=null,"model_thumbnail:"+id)
	check(not camera.top_level and camera_parent==player._spring_arm,"ordinary_springarm_on_entry")
	# Source connected-world orbit offset (3,1.1,4), independently audited in zoom review.
	check(is_equal_approx(player.camera_distance,Vector3(3,1.1,4).length()),"ordinary_default_camera_distance")
	var residents: Dictionary=scene.preview_population.residents.snapshot()
	for row: Dictionary in residents.rows: resident_ids.append(row.source_id)
	check(resident_ids.size()==3,"same_three_actual_residents")
	check(scene._block.counts.buildings==8,"same_eight_building_quarter")
	await frames(75)
	var resolutions: Array=[Vector2i(1280,720),Vector2i(1920,1080)] if resolution_arg=="both" else [Vector2i(1280,720) if resolution_arg=="1280x720" else Vector2i(1920,1080)]
	for value: Vector2i in resolutions:
		if done: return
		var count_before:=captures.size()
		await run_resolution(value)
		check(captures.size()-count_before==(19 if visibility_probes else 17),"complete_capture_scenario:"+str(value))
		if not failure_labels.is_empty(): break
	finish("completed")

func finish(reason: String) -> void:
	if done: return
	done=true; controls_owned=false
	if is_instance_valid(player):
		for action: StringName in [player.ACTION_FORWARD,player.ACTION_BACK,player.ACTION_LEFT,player.ACTION_RIGHT,player.ACTION_RUN,player.ACTION_JUMP]: Input.action_release(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var final_hashes:=hashes()
	if not initial_hashes.is_empty(): check(final_hashes==initial_hashes,"runtime_inputs_unchanged_during_capture")
	var report: Dictionary={"schema":"mafiozi.root23.visual-behavior/v1","reason":reason,"pass":failure_labels.is_empty() and reason=="completed","checks":checks,"failures":failure_labels,"elapsed_ms":Time.get_ticks_msec()-started_ms,"purpose":"behavior_and_visual_only","performance_valid":false,"control_scope":"viewport input + explicitly logged QA-owned virtual focus and InputMap movement; no desktop-focus acceptance","camera_contract":"Walk connected-world attached 5.11957m spring camera (source offset 3,1.1,4), no camera detachment/position/look_at/bone writes","resident_ids":resident_ids,"inputs_before":initial_hashes,"inputs_after":final_hashes,"focus_resumes":focus_resumes,"input_log":input_log,"events":events,"captures":captures}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ROOT23_VISUAL_RESULT ",JSON.stringify({"pass":report.pass,"checks":checks,"failures":failure_labels,"captures":captures.size(),"elapsed_ms":report.elapsed_ms,"performance_valid":false}))
	quit(0 if report.pass else 1)
