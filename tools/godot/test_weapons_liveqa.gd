extends SceneTree
## Root schedules sequential GPU runs. Only this harness owns its test camera.
## Same actual main, three moving residents and 1200 preparation physics frames.
## Idle: 14 real trunk items. Active: take the same AK, leaving 13 trunk items.
## Usage: --qa-mode=baseline|weapons --qa-config=... --qa-out=... [--qa-smoke]
## --qa-smoke is headless logic verification ONLY, never a performance receipt.
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const HASH_FILES := ["res://scripts/main.gd", "res://scripts/preview_player.gd", "res://scripts/preview_population.gd", "res://scripts/weapons/preview_weapons.gd", "res://scripts/weapons/preview_weapon_cargo.gd", "res://scripts/weapons/weapon_projectiles.gd", "res://scripts/weapons/player_weapon_presentation.gd", "res://scripts/weapons/weapon_posture_base.gd", "res://scripts/transport/trunk/transport_trunk_cargo_store.gd", "res://scripts/weapons/weapon_fire.gd"]
var scene: Node3D
var player: CharacterBody3D
var weapons: Node
var cargo: Node
var camera: Camera3D
var out := ""
var mode := "baseline"
var smoke := false
var config := ""
var settings := {}
var failures: Array[String] = []
var checks := 0
var aborted := false
var watch_input := false
var input_events: Array[String] = []
var observing := false
var drawn_frames := 0
var sampled_drawn_frames := 0
var last_usec := 0
var last_draw_usec := 0
var samples: Array[Dictionary] = []
var render_samples: Array[float] = []
var distances := {}
var previous := {}
var hashes_before := {}
var phases: Array[Dictionary] = []
var behavior: Array[Dictionary] = []
var inventory_uids := {}
var prep_start := 0
var prep_end := 0
var done := false
var active_fire := false
var reload_requests := 0
var shot_receipts := 0
var screenshots: Array[String] = []
var scripted_controls := false
var focus_resumes: Array[Dictionary] = []

func drive_controls() -> void:
	# This benchmark owns PROGRAMMATIC input, not the desktop pointer. The
	# production blur/click contract is verified separately. Working in another
	# application must not silently turn the active-fire workload into idle.
	if not scripted_controls or not is_instance_valid(player): return
	if not player._free_mouse_look:
		focus_resumes.append({"physics_frame":Engine.get_physics_frames(),"active_fire":active_fire})
		player._free_mouse_look=true
		if active_fire: player._unhandled_input(mouse(true))

class InputObserver extends Node:
	var qa: SceneTree
	func _input(event: InputEvent) -> void:
		# Mouse motion is not an interrupt; a real click/key/controller is.
		if qa.watch_input and event is InputEventMouseMotion:
			qa.root.set_input_as_handled(); return
		var takeover: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>.25)
		if qa.watch_input and takeover:
			qa.root.set_input_as_handled()
			if qa.input_events.size()<20: qa.input_events.append("ignored:"+event.as_text())
			# Real input never changes the fixed scenario. Closing the QA window
			# still ends this process and restores the accepted interactive game.

func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and not failures.has(label): failures.append(label); print("CHECK_FAILED ",label)
func hashes() -> Dictionary:
	var result := {}
	for path: String in HASH_FILES: result[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "COMPILED"
	return result
func memory() -> Dictionary:
	return {"static_bytes":OS.get_static_memory_usage(),"peak_bytes":OS.get_static_memory_peak_usage(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
func key(code: Key) -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true; return event
func mouse(pressed: bool) -> InputEventMouseButton:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; return event
func equip(id: String) -> Dictionary:
	drive_controls()
	var result: Dictionary=weapons.equip(id)
	behavior.append({"label":"equip_result","requested":id,"result":result.duplicate(true),"control_active":player._free_mouse_look,"authority":str(player._pose_authority),"jump":player._jump.duplicate(true),"host_fire_state":weapons.fire_state.duplicate(true)})
	if not result.get("ok",false): print("EQUIP_REJECTED ",JSON.stringify(behavior[-1]))
	# Runtime menu close requests capture. Restore before any event pump/await;
	# the observer consumes external motion, without changing production input.
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	return result
func release_trigger() -> void:
	active_fire=false
	if is_instance_valid(player): player._unhandled_input(mouse(false))
func sync(count: int=1) -> void:
	for i: int in count:
		if aborted: return
		await physics_frame; await process_frame
func phase(name: String) -> void:
	FileAccess.open(out.path_join("PHASE.json"),FileAccess.WRITE).store_string(JSON.stringify({"phase":name,"at_ms":Time.get_ticks_msec(),"physics_frame":Engine.get_physics_frames(),"samples":samples.size(),"aborted":aborted,"input_events":input_events}))
func _process(_delta: float) -> bool:
	drive_controls()
	if active_fire and not aborted and is_instance_valid(weapons):
		if int(weapons.fire_state.magazine)==0 and int(weapons.fire_state.reserveAmmo)>0 and float(weapons.fire_state.reloadRemaining)<=0:
			player._unhandled_input(key(KEY_R)); reload_requests+=1
	if observing:
		var at:=Time.get_ticks_usec()
		if last_usec>0: samples.append({"frame_ms":(at-last_usec)/1000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
		last_usec=at
	return false
func drawn() -> void:
	drawn_frames+=1
	if observing:
		sampled_drawn_frames+=1
		var at:=Time.get_ticks_usec()
		if last_draw_usec>0: render_samples.append((at-last_draw_usec)/1000.0)
		last_draw_usec=at
func _physics_process(_delta: float) -> bool:
	drive_controls()
	if not observing or not is_instance_valid(scene) or scene.preview_population==null: return false
	for row: Dictionary in scene.preview_population.residents.snapshot().rows:
		var point: Variant=row.position
		if not point is Vector3 or not point.is_finite(): check(false,"resident_position:"+row.source_id); continue
		if previous.has(row.source_id):
			var moved: float=point.distance_to(previous[row.source_id]); check(moved<.5,"resident_teleport:"+row.source_id)
			distances[row.source_id]=float(distances.get(row.source_id,0.0))+moved
		previous[row.source_id]=point
	return false
func capture(name: String) -> void:
	if aborted or DisplayServer.get_name()=="headless": return
	phase(name+"_before_render")
	var start:=drawn_frames; var deadline:=Time.get_ticks_msec()+2000
	while not aborted and drawn_frames==start and Time.get_ticks_msec()<deadline: await process_frame
	if aborted: return
	if drawn_frames==start: check(false,"render_not_presented:"+name); return
	phase(name+"_readback")
	var screenshot:=root.get_texture().get_image()
	check(screenshot.save_png(out.path_join(name+".png"))==OK,"capture:"+name); screenshots.append(name+".png")
func set_fixed_camera() -> void:
	camera.global_position=Vector3(settings.camera[0],settings.camera[1],settings.camera[2])
	camera.look_at(Vector3(settings.look_at[0],settings.look_at[1],settings.look_at[2]),Vector3.UP)
	camera.fov=float(settings.get("fov",65.0)); camera.make_current(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func aim_empty_space() -> bool:
	var aim_camera: Camera3D=player.get_preview_camera()
	aim_camera.top_level=true; aim_camera.global_position=player.global_position+Vector3.UP*2.2
	# Search real collision-free upward rays; never replace the physics query.
	var access: Dictionary=scene.preview_transport.compartments.access_profile("trunk")
	var outward: Vector3=scene.preview_transport.body.global_basis*access.outward_local
	var preferred:=Vector3(outward.x,.85,outward.z).normalized()
	for direction: Vector3 in [preferred,Vector3(0,.65,-.76),Vector3(.76,.65,0),Vector3(0,.65,.76),Vector3(-.76,.65,0)]:
		direction=direction.normalized()
		var query:=PhysicsRayQueryParameters3D.create(aim_camera.global_position,aim_camera.global_position+direction*100,5,[player.get_rid()])
		if scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			aim_camera.look_at(aim_camera.global_position+direction,Vector3.UP); return true
	return false
func muzzle_path_clear() -> bool:
	var receipt: Dictionary=weapons.presentation.current_muzzle()
	if not receipt.get("ok",false): return false
	var aim_camera: Camera3D=player.get_preview_camera()
	var target:=aim_camera.global_position-aim_camera.global_basis.z*100
	var query:=PhysicsRayQueryParameters3D.create(receipt.origin,target,5,[player.get_rid()])
	return scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func trunk_camera() -> void:
	var transport: Node3D=scene.preview_transport
	var bounds: Dictionary=transport.compartments.cargo_bounds()
	var center: Vector3=transport.visual.root.to_global((bounds.min+bounds.max)*.5)
	var aim_camera: Camera3D=player.get_preview_camera()
	aim_camera.top_level=true; aim_camera.global_position=player.global_position+Vector3.UP*2; aim_camera.look_at(center,Vector3.UP)
	# Camera outside the rear lid, aimed into the real compartment, for QA only.
	camera.global_position=aim_camera.global_position; camera.look_at(center,Vector3.UP); camera.make_current()
func verify_muzzle(label: String) -> void:
	var receipt: Dictionary=weapons.presentation.current_muzzle()
	check(receipt.get("ok",false),label+":current_muzzle")
	if receipt.get("ok",false): check(receipt.pose_revision==player._pose_revision and receipt.origin.is_finite() and receipt.direction.is_finite(),label+":latest_finite_pose")
func fire_once(id: String,label: String) -> void:
	check(weapons.fire_state.weaponId==id,label+":requested_weapon_active")
	if weapons.fire_state.weaponId!=id: return
	for i: int in 180:
		if aborted: return
		if float(weapons.fire_state.cooldown)<=0 and float(weapons.fire_state.reloadRemaining)<=0: break
		await sync()
	var ammo: int=weapons.fire_state.magazine; var shots: int=weapons.shots_count
	var effects_before: int=weapons.effects.stats().totalShots
	if aborted: return
	var clear:=muzzle_path_clear(); check(clear,label+":actual_muzzle_path_empty")
	if not clear: return
	player._unhandled_input(mouse(true)); await sync(2); player._unhandled_input(mouse(false)); await sync(2)
	var emitted: int=weapons.shots_count-shots; var spent: int=ammo-int(weapons.fire_state.magazine)
	check(emitted==0 and spent==0 if id=="rpg" else emitted>0 and spent==emitted,label+":finite_fire")
	check(int(weapons.effects.stats().totalShots)-effects_before==emitted,label+":actual_effects")
	behavior.append({"label":label,"weapon_id":id,"shots":emitted,"ammo_spent":spent,"effects":weapons.effects.stats()})
func prepare_weapons() -> void:
	var empty:=aim_empty_space(); check(empty,"behavior_actual_empty_ray")
	if not empty: return
	for id: String in Fire.ids():
		if aborted: return
		check(equip(id).get("ok",false),"original_equip:"+id); await sync(4)
		verify_muzzle(id); await fire_once(id,id)
	if aborted: return
	check(equip("ak74").get("ok",false),"AK_postures_equip"); await sync(4)
	camera.global_position=player.global_position+Vector3(3,1.3,3); camera.look_at(player.global_position+Vector3.UP*.9,Vector3.UP); camera.make_current()
	await capture("standing_AK")
	for item: Array in [[KEY_C,"crouch",1.0,1.69],[KEY_Z,"prone",2.0,.62]]:
		if aborted: return
		player._unhandled_input(key(item[0])); await sync(72)
		check(absf(float(weapons._posture_view.value)-float(item[2]))<.0001,"source_posture:"+item[1])
		check(absf(float(player.get_node("PlayerCapsule").shape.height)-float(item[3]))<.0001,"actual_capsule:"+item[1])
		verify_muzzle(item[1]); await fire_once("ak74",item[1])
		camera.global_position=player.global_position+Vector3(3,1.3,3); camera.look_at(player.global_position+Vector3.UP*.65,Vector3.UP); camera.make_current()
		await capture(item[1])
	if aborted: return
	player._unhandled_input(key(KEY_Z)); await sync(72)
	check(absf(float(weapons._posture_view.value))<.0001,"standing_restored")
func store_all() -> void:
	trunk_camera()
	for id: String in Fire.ids():
		if aborted: return
		check(equip(id).get("ok",false),"store_equip:"+id)
		inventory_uids[id]=weapons.inventory.get_item_uid(id)
		var stored_input: Dictionary=weapons.fire_state.duplicate(true)
		var answer: Dictionary=cargo.store_held()
		behavior.append({"label":"store_attempt","weapon_id":id,"fire_state":stored_input,"numeric_types":{"magazine":typeof(stored_input.magazine),"reserveAmmo":typeof(stored_input.reserveAmmo),"sequence":typeof(stored_input.sequence)},"ok":answer.get("ok",false),"reason":answer.get("reason","")})
		check(answer.get("ok",false),"actual_trunk_store:"+id+":"+str(answer.get("reason","")))
	var state: Dictionary=cargo.cargo.snapshot(cargo.generation)
	check(state.items.size()==14 and state.used_units==100 and weapons.inventory.get_owned_ids().is_empty(),"all14_authoritative_items_capacity100")
	for a: int in state.items.size():
		check(state.items[a].item.uid==inventory_uids.get(state.items[a].item.weaponId,""),"stored_uid_retained")
		for b: int in range(a+1,state.items.size()): check(not state.items[a].item_bounds_local_m.intersects(state.items[b].item_bounds_local_m),"trunk_nonoverlap")
	check(int(cargo.renderer.debug_snapshot().total_count)==14,"all14_actual_models")
	cargo._refresh=0; cargo._process(0)
	check(cargo._hint.text.contains("Занято 100 / 100") and cargo._hint.text.contains("Свободно 0"),"actual_capacity_HUD")
	behavior.append({"label":"stored_all14","cargo":state,"hud":cargo._hint.text,"visuals":cargo.renderer.debug_snapshot()})
	await capture("weaponpile14")
func take_actual_ak() -> bool:
	drive_controls()
	var uid: String=inventory_uids.get("ak74","")
	var trunks: Dictionary=cargo.renderer.get("_trunks")
	if not trunks.has(cargo.vehicle_id) or not trunks[cargo.vehicle_id].items.has(uid):
		behavior.append({"label":"take_failed","reason":"missing_visual","uid":uid}); return false
	var row: Dictionary=trunks[cargo.vehicle_id].items[uid]
	var aim_camera: Camera3D=player.get_preview_camera()
	aim_camera.global_position=row.visual.global_transform*row.bounds.get_center()+Vector3(0,2,.1)
	var contexts: Dictionary={}
	for part: Dictionary in row.parts:
		if not part.visible: continue
		var faces: PackedVector3Array=part.mesh.get_faces()
		for at: int in range(0,faces.size(),3):
			var point: Vector3=row.visual.global_transform*part.transform*((faces[at]+faces[at+1]+faces[at+2])/3.0)
			aim_camera.look_at(point,Vector3.UP)
			var context: Dictionary=cargo.aim_context()
			contexts[JSON.stringify(context)]=true
			if context.get("item_uid","")==uid:
				var answer: Dictionary=cargo.take_item(uid)
				behavior.append({"label":"take_result","uid":uid,"result":answer,"control_active":player._free_mouse_look})
				Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
				if not answer.get("ok",false): return false
				# Current runtime E/take auto-equips the original selected item.
				return weapons.fire_state.weaponId=="ak74" and weapons.inventory.get_item_uid("ak74")==uid and int(cargo.cargo.summary(cargo.generation).count)==13
	behavior.append({"label":"take_failed","reason":"no_aimed_triangle","control_active":player._free_mouse_look,"contexts":contexts.keys(),"player_position":player.global_position,"camera_position":aim_camera.global_position,"vehicle_transform":scene.preview_transport.body.global_transform})
	return false
func snapshot() -> Dictionary:
	return {"player_position":player.global_position,"player_transform":player.global_transform,"vehicle_transform":scene.preview_transport.body.global_transform,"population":scene.preview_population.snapshot(),"weapon":weapons.snapshot() if is_instance_valid(weapons) else {},"cargo":cargo.cargo.summary(cargo.generation) if is_instance_valid(cargo) else {},"camera_transform":camera.global_transform,"physics_frame":Engine.get_physics_frames()}
func delay_seconds(seconds: float,smoke_frames: int) -> void:
	if smoke: await sync(smoke_frames); return
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while not aborted and Time.get_ticks_msec()<until: await process_frame
func measure(label: String) -> void:
	phase(label+"_warmup"); await delay_seconds(5.0,30)
	if aborted: return
	if label=="idle14" and is_instance_valid(weapons): check(int(weapons.effects.stats().active)==0 and int(weapons.effects.stats().pendingCasings)==0,"idle_has_no_lingering_effects")
	await capture(label+"_start")
	if aborted: return
	for i: int in 3: await process_frame
	if aborted: return
	samples.clear(); render_samples.clear(); previous.clear(); distances.clear(); last_usec=0; last_draw_usec=0; sampled_drawn_frames=0
	var memory_before:=memory(); var before:=snapshot(); var start:=Time.get_ticks_usec(); var reloads_before:=reload_requests
	# Smoke still exercises one full 12 simulated seconds of automatic fire,
	# including finite-magazine reload; its accelerated wall timings are invalid.
	observing=true; phase(label+"_sampling"); await delay_seconds(12.0,720 if label=="active13_AK" else 120); observing=false
	var elapsed: float=(Time.get_ticks_usec()-start)/1000000.0
	var after:=snapshot(); var memory_after:=memory()
	check(samples.size()>100,label+":enough_frames")
	check(DisplayServer.get_name()=="headless" or render_samples.size()>100,label+":presented_frames")
	check(distances.size()==3,label+":three_residents_observed")
	for id: String in distances: check(float(distances[id])>(.01 if smoke else 1.0),label+":resident_moves:"+id)
	if mode=="weapons" and label=="active13_AK":
		var emitted: int=after.weapon.shots-before.weapon.shots
		var spent: int=int(before.weapon.fire_state.magazine+before.weapon.fire_state.reserveAmmo)-int(after.weapon.fire_state.magazine+after.weapon.fire_state.reserveAmmo)
		check(emitted>0 and emitted==spent,label+":finite_shots_equal_ammo")
		check(int(after.weapon.effects.totalShots)-int(before.weapon.effects.totalShots)==emitted,label+":actual_effects_emitted")
		check(after.weapon.fire_state.magazine>=0 and after.weapon.fire_state.reserveAmmo>=0,label+":nonnegative_ammo")
		check(reload_requests>0,label+":real_automatic_reload_input_exercised")
	var metrics: Dictionary={}
	for name: String in ["frame_ms","draw_calls","primitives","process_ms","physics_ms"]:
		var values: Array[float]=[]
		for row: Dictionary in samples: values.append(float(row[name]))
		metrics[name]=distribution(values)
	metrics.render_frame_ms=distribution(render_samples)
	phases.append({"label":label,"elapsed_seconds":elapsed,"samples":samples.size(),"actual_drawn_frames":sampled_drawn_frames,"metrics":metrics,"memory_before":memory_before,"memory_after":memory_after,"before":before,"after":after,"resident_travel_m":distances.duplicate(),"reload_requests":reload_requests-reloads_before})
	await capture(label+"_end")
func distribution(values: Array[float]) -> Dictionary:
	values.sort()
	return {} if values.is_empty() else {"p50":values[int((values.size()-1)*.5)],"p95":values[int((values.size()-1)*.95)],"max":values[-1]}
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-config="): config=arg.trim_prefix("--qa-config=")
		if arg.begins_with("--qa-mode="): mode=arg.trim_prefix("--qa-mode=")
		if arg=="--qa-smoke": smoke=true
	if out.is_empty() or config.is_empty() or mode not in ["baseline","weapons"]: quit(2); return
	DirAccess.make_dir_recursive_absolute(out)
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(config))
	if not parsed is Dictionary or not parsed.get("camera") is Array or not parsed.get("look_at") is Array or parsed.camera.size()!=3 or parsed.look_at.size()!=3: quit(2); return
	settings=parsed
	if smoke and DisplayServer.get_name()!="headless": push_error("qa-smoke requires headless"); quit(2); return
	create_timer(150.0).timeout.connect(func():
		if not done: check(false,"bounded_harness_timeout"); aborted=true; finish())
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,false)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,false)
		DisplayServer.window_set_size(Vector2i(1280,720))
		DisplayServer.window_set_title("Мафиози — проверка сборки, управление временно отключено")
	RenderingServer.frame_post_draw.connect(drawn); hashes_before=hashes()
	scene=load("res://scenes/main.tscn").instantiate(); scene.preview_residents_enabled=true; scene.preview_weapons_enabled=mode=="weapons"; root.add_child(scene)
	var observer:=InputObserver.new(); observer.qa=self; root.add_child(observer); watch_input=true
	var deadline:=Time.get_ticks_msec()+25000
	while not aborted and not scene.preview_ready and Time.get_ticks_msec()<deadline: await physics_frame
	check(scene.preview_ready,"actual_main_ready")
	if aborted or not scene.preview_ready: finish(); return
	player=scene._player; weapons=scene.preview_weapons; check(scene.transport_status=="ready","actual_transport_ready")
	# Handling an event does not clear Input's polling state. The QA process has
	# its own InputMap: remove OS bindings, keeping the direct scripted inputs.
	for action: StringName in [player.ACTION_LEFT,player.ACTION_RIGHT,player.ACTION_FORWARD,player.ACTION_BACK,player.ACTION_RUN,player.ACTION_JUMP]:
		Input.action_release(action); InputMap.action_erase_events(action)
	check(scene.preview_population!=null and scene.preview_population.occupants().size()==3,"same_three_residents")
	if scene.transport_status!="ready" or scene.preview_population==null: finish(); return
	if mode=="weapons":
		check(is_instance_valid(weapons),"actual_weapon_host")
		if not is_instance_valid(weapons): finish(); return
		cargo=weapons.get_node_or_null("WeaponCargo"); check(is_instance_valid(cargo),"actual_cargo_host")
		if not is_instance_valid(cargo): finish(); return
		weapons.shot_emitted.connect(func(_shot: Dictionary,muzzle: Dictionary,_origin: Vector3,_direction: Vector3):
			shot_receipts+=1; check(muzzle.get("ok",false) and muzzle.pose_revision==player._pose_revision,"emitted_shot_current_muzzle"))
	else: check(weapons==null,"baseline_weapon_subsystem_disabled")
	camera=Camera3D.new(); scene.add_child(camera); set_fixed_camera()
	# Explicit harness control; never capture the user's pointer.
	player._free_mouse_look=true; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	prep_start=Engine.get_physics_frames(); phase("preparing"); await sync(60)
	if aborted: finish(); return
	var transport: Node3D=scene.preview_transport
	check(transport.body.get_meta("profile_id")=="city_hatchback","actual_hatchback")
	var access: Dictionary=transport.compartments.access_profile("trunk")
	var stand: Vector3=transport.body.to_global(access.position_local_m+access.outward_local*.9)
	var query:=PhysicsRayQueryParameters3D.create(stand+Vector3.UP*3,stand-Vector3.UP*8,1,[player.get_rid(),transport.body.get_rid()])
	var floor_hit:=scene.get_world_3d().direct_space_state.intersect_ray(query)
	check(not floor_hit.is_empty(),"actual_floor_at_trunk")
	if floor_hit.is_empty(): finish(); return
	stand.y=floor_hit.position.y+.01
	# Keep the actual gun muzzle away from the hatchback during fire validation.
	# Both modes use the same floor-supported position and frame-900 return.
	var outward: Vector3=transport.body.global_basis*access.outward_local
	var firing_stand:=stand+Vector3(outward.x,0,outward.z).normalized()*2.4
	query=PhysicsRayQueryParameters3D.create(firing_stand+Vector3.UP*3,firing_stand-Vector3.UP*8,1,[player.get_rid(),transport.body.get_rid()])
	var firing_floor:=scene.get_world_3d().direct_space_state.intersect_ray(query)
	check(not firing_floor.is_empty(),"actual_floor_at_firing_stand")
	if firing_floor.is_empty(): finish(); return
	firing_stand.y=firing_floor.position.y+.01; player.global_position=firing_stand
	transport.compartments.set_open("trunk",true); await sync(100)
	# NO_FOCUS delivers startup focus-out asynchronously. Begin the explicitly
	# scripted control session after preparation, without capturing the pointer.
	# No retries or per-equip reactivation: any later loss is still a failure.
	player._free_mouse_look=true
	scripted_controls=true
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"scripted_control_without_pointer_capture")
	if mode=="weapons" and not aborted: await prepare_weapons()
	if aborted or not failures.is_empty(): finish(); return
	check(Engine.get_physics_frames()-prep_start<900,"behavior_within_shared_frame_budget")
	while not aborted and Engine.get_physics_frames()-prep_start<900: await physics_frame
	if aborted: finish(); return
	player.global_position=stand; await sync(8)
	if mode=="weapons" and not aborted: await store_all()
	if aborted or not failures.is_empty(): finish(); return
	set_fixed_camera()
	check(Engine.get_physics_frames()-prep_start<1200,"preparation_within_shared_frame_budget")
	while not aborted and Engine.get_physics_frames()-prep_start<1200: await physics_frame
	prep_end=Engine.get_physics_frames()
	if aborted: finish(); return
	await measure("idle14")
	if aborted: finish(); return
	var transition_start:=Engine.get_physics_frames()
	if mode=="weapons":
		var taken:=take_actual_ak(); check(taken,"take_same_AK_leaves13_no_duplicate")
		if not taken: finish(); return
		var empty:=aim_empty_space(); check(empty,"active_actual_empty_ray")
		if not empty: finish(); return
		await sync(4); verify_muzzle("active_AK")
		var clear:=muzzle_path_clear(); check(clear,"active_AK_actual_muzzle_path_empty")
		if not clear: finish(); return
		check(int(weapons.fire_state.magazine)+int(weapons.fire_state.reserveAmmo)>0,"active_has_real_finite_ammo")
	set_fixed_camera()
	while not aborted and Engine.get_physics_frames()-transition_start<60: await physics_frame
	if mode=="weapons" and not aborted:
		active_fire=true; player._unhandled_input(mouse(true))
	if not aborted: await measure("active13_AK")
	release_trigger(); finish()
func finish() -> void:
	if done: return
	done=true; observing=false; watch_input=false; release_trigger()
	scripted_controls=false
	check(hashes()==hashes_before,"runtime_source_unchanged")
	check(phases.size()==2,"both_measurement_phases_completed")
	var result:={"mode":mode,"passed":failures.is_empty() and not aborted,"checks":checks,"failures":failures,"aborted":aborted,"input_events":input_events,"headless":DisplayServer.get_name()=="headless","smoke":smoke,"performance_valid":not smoke and DisplayServer.get_name()!="headless" and failures.is_empty() and not aborted,"camera":settings,"config_sha256":FileAccess.get_sha256(config),"hashes":hashes_before,"preparation_physics_frames":prep_end-prep_start,"phases":phases,"behavior":behavior,"shot_receipts":shot_receipts,"screenshots":screenshots,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual bounded main, same 3 staged moving source residents and actual hatchback. Idle14 then active13+same AK; finite native inventory, no ammo injection, no HP/death/blood or authenticated ownership acceptance. Cover/passenger firing unsupported. Sequential before/after comparison requires identical configuration, runtime hashes and renderer; NPC start/end positions included. Headless results are logic only."}
	result["render_configuration"]={"window_size":DisplayServer.window_get_size(),"viewport_size":root.size,"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"physics_ticks_per_second":Engine.physics_ticks_per_second,"warmup_seconds":5,"sample_seconds":12}
	result["input_method"]="Programmatic held input; desktop focus independent. Not native OS-input acceptance."
	result["external_focus_resumes"]=focus_resumes
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("WEAPONS_LIVEQA ",JSON.stringify({"mode":mode,"passed":result.passed,"checks":checks,"failures":failures,"phases":phases.size(),"smoke":smoke}))
	if is_instance_valid(scene): scene.free()
	quit(0 if failures.is_empty() and not aborted else 1)
