extends SceneTree
# External outputs-only fixture: normalize rendered camera ONLY, keep source camera computations/queries, NPCs, physics and effects running.
const IDS := ["nagan","tt_pistol","revolver","deagle","golden_colt","sawn_off","shotgun","uzi","golden_uzi","ak74","m16","tommy_gun","sniper","rpg"]
var scene:Node3D
var player:CharacterBody3D
var weapons:Node
var transport:Node3D
var cargo:Node
var report:Dictionary={"schema":2,"phases":[],"errors":[],"not_gpu_timestamp":"frame_ms is post-draw wall cadence, not GPU duration"}
var output_path:=""
var finished:=false
var startup_only:=false
var begun:int
const BENCH_FOV:=65.0
const BENCH_DISTANCE:=4.8
const BENCH_PIVOT_HEIGHT:=1.501
var camera_expected:=Transform3D.IDENTITY
var camera_fixture_ready:=false
var camera_verified_frames:=0
var camera_max_position_error:=0.0
var camera_max_basis_error:=0.0
var camera_max_fov_error:=0.0
func _initialize()->void:
	begun=Time.get_ticks_usec()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-out="):output_path=arg.trim_prefix("--bench-out=")
		if arg.begins_with("--bench-label="):report.label=arg.trim_prefix("--bench-label=")
		if arg=="--bench-startup-only":startup_only=true
	process_frame.connect(virtual_focus)
	RenderingServer.frame_pre_draw.connect(normalize_render_camera)
	RenderingServer.frame_post_draw.connect(verify_render_camera)
	run.call_deferred()
func virtual_focus()->void:
	# Benchmark-only logical admission: no OS focus or cursor capture.
	if not finished and is_instance_valid(player):player._free_mouse_look=true
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func normalize_render_camera()->void:
	if finished or not is_instance_valid(player):return
	# Late draw-only normalization; original aim-camera advance/shape casts and
	# SpringArm physics still run. This is NOT a player camera behavior test.
	var basis:=Basis(Vector3.UP,player._camera_yaw)*Basis(Vector3.RIGHT,player._camera_pitch)
	camera_expected=Transform3D(basis,player.global_position+Vector3.UP*BENCH_PIVOT_HEIGHT+basis*Vector3(0,0,BENCH_DISTANCE))
	var camera:Camera3D=player.get_preview_camera()
	camera.global_transform=camera_expected;camera.fov=BENCH_FOV
	camera.near=.08;camera.far=1600.0;camera.h_offset=0.0;camera.v_offset=0.0
	camera_fixture_ready=true
func verify_render_camera()->void:
	if finished or not camera_fixture_ready or not is_instance_valid(player):return
	var camera:Camera3D=player.get_preview_camera()
	camera_max_position_error=maxf(camera_max_position_error,camera.global_position.distance_to(camera_expected.origin))
	camera_max_basis_error=maxf(camera_max_basis_error,maxf(camera.global_basis.x.distance_to(camera_expected.basis.x),maxf(camera.global_basis.y.distance_to(camera_expected.basis.y),camera.global_basis.z.distance_to(camera_expected.basis.z))))
	camera_max_fov_error=maxf(camera_max_fov_error,absf(camera.fov-BENCH_FOV))
	camera_verified_frames+=1
func fail(message:String)->void:report.errors.append(message)
func percentile(rows:Array,q:float)->float:
	if rows.is_empty():return -1
	var sorted:=rows.duplicate();sorted.sort();return float(sorted[clampi(int(ceil(sorted.size()*q))-1,0,sorted.size()-1)])
func summary(rows:Array)->Dictionary:
	return {"n":rows.size(),"p50":percentile(rows,.5),"p95":percentile(rows,.95),"max":percentile(rows,1)}
func pos(v:Vector3)->Array:return [v.x,v.y,v.z]
func mouse(button:int,down:bool)->void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=down;root.push_input(event)
func resident_count()->int:
	return scene.preview_population.residents.occupants().size() if scene.preview_population!=null and scene.preview_population.residents!=null else -1
func npc_fixture()->Array:
	var result:Array=[]
	for entry:Dictionary in scene.preview_population.residents.occupants():
		var record:Dictionary=scene.preview_population.residents._records[entry.source_id]
		var body:CharacterBody3D=record.body
		var shape:CollisionShape3D=body.get_child(0) as CollisionShape3D
		result.append({"source_id":entry.source_id,"life_generation":entry.life_generation,"height":entry.height,"radius":entry.radius,"layer":body.collision_layer,"mask":body.collision_mask,"shape_type":shape.shape.get_class() if shape!=null and shape.shape!=null else "missing","shape_height":shape.shape.height if shape!=null and shape.shape is CapsuleShape3D else -1,"shape_radius":shape.shape.radius if shape!=null and shape.shape is CapsuleShape3D else -1})
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.source_id<b.source_id)
	return result
func fixture()->Dictionary:
	return {"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"collision_shape_count":scene.find_children("*","CollisionShape3D",true,false).size(),"npc":resident_count(),"npc_fixture":npc_fixture(),"buildings":scene._block.counts.buildings,"source_colliders":scene._block.counts.collisionBodies,"transport":scene.transport_status,"population":scene.population_status,"player":pos(player.global_position),"camera":pos(player.get_preview_camera().global_position),"camera_fov":player.get_preview_camera().fov,"camera_forward":pos(-player.get_preview_camera().global_basis.z),"camera_basis_x":pos(player.get_preview_camera().global_basis.x),"camera_yaw":player._camera_yaw,"camera_pitch":player._camera_pitch,"camera_attached":not player.get_preview_camera().top_level,"physics_active":Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),"body_count":scene.find_children("*","CollisionObject3D",true,false).size(),"mesh_count":scene.find_children("*","MeshInstance3D",true,false).size(),"taa":root.use_taa,"msaa":root.msaa_3d,"mouse_mode":Input.mouse_mode,"drawn_frames":Engine.get_frames_drawn()}
func wait_render(seconds:float)->void:
	var until:=Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec()<until:await RenderingServer.frame_post_draw
func phase(label:String,seconds:float,shoot:bool=false)->void:
	var frames:Array=[];var draws:Array=[];var primitives:Array=[];var memory:Array=[];var vram:Array=[];var gpu:Array=[]
	camera_max_position_error=0.0;camera_max_basis_error=0.0;camera_max_fov_error=0.0
	var camera_frames_before:=camera_verified_frames
	var before:=fixture()
	await RenderingServer.frame_post_draw
	var start:=Time.get_ticks_usec();var previous:=start;var next_shot:=start;var release_next:=false;var start_shots:int=weapons.shots_count
	while Time.get_ticks_usec()-start<int(seconds*1000000):
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
		if frames.size()%12==0:
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			memory.append(Performance.get_monitor(Performance.MEMORY_STATIC));vram.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
			if RenderingServer.has_method("viewport_get_measured_render_time_gpu"):gpu.append(RenderingServer.call("viewport_get_measured_render_time_gpu",root.get_viewport_rid()))
		if shoot:
			if release_next:mouse(MOUSE_BUTTON_LEFT,false);release_next=false
			elif now>=next_shot:mouse(MOUSE_BUTTON_LEFT,true);release_next=true;next_shot=now+400000
	mouse(MOUSE_BUTTON_LEFT,false)
	var after:=fixture()
	if camera_max_position_error>.0001 or camera_max_basis_error>.00001 or camera_max_fov_error>.00001:fail(label+": rendered camera normalization was overwritten")
	if gpu.is_empty() or percentile(gpu,.95)<=0.0:fail(label+": offscreen GPU timestamp missing; cannot prove GPU work")
	if frames.size()<60:fail(label+": fewer than60 rendered frames")
	if before.npc!=3 or after.npc!=3:fail(label+": expected3 living resident occupants")
	for edge:Dictionary in [before,after]:
		if int(edge.buildings)!=8 or int(edge.body_count)!=377 or int(edge.collision_shape_count)!=377:fail(label+": expected8buildings377bodies377shapes")
	if after.drawn_frames-before.drawn_frames<frames.size()-2:fail(label+": post-draw samples did not advance render counter")
	if shoot and weapons.shots_count-start_shots<5:fail(label+": weapon workload failed")
	report.phases.append({"name":label,"frame_ms":summary(frames),"drawcalls":summary(draws),"primitives":summary(primitives),"static_memory_bytes":summary(memory),"vram_bytes":summary(vram),"gpu_ms":summary(gpu),"wall_seconds":(Time.get_ticks_usec()-start)/1000000.0,"shots":weapons.shots_count-start_shots,"before":before,"after":after,"raw_frame_ms":frames,"camera_proof":{"verified_rendered_frames":camera_verified_frames-camera_frames_before,"max_position_error":camera_max_position_error,"max_basis_error":camera_max_basis_error,"max_fov_error":camera_max_fov_error}})
func finish()->void:
	if finished:return
	finished=true
	if is_instance_valid(player):player.set_mouse_captured(false)
	report.total_seconds=(Time.get_ticks_usec()-begun)/1000000.0
	report.valid=report.errors.is_empty()
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	if file==null:push_error("Cannot save benchmark "+output_path);quit(3);return
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("LOADED_BENCH ",report.get("label","")," valid=",report.valid," seconds=",report.total_seconds," errors=",report.errors)
	quit(0 if report.valid else 2)
func deadline()->void:
	if not finished:fail("35second whole-process budget exceeded");finish()
func run()->void:
	if output_path.is_empty():push_error("Required --bench-out=ABS_PATH");quit(3);return
	if DisplayServer.get_name()=="headless":fail("GPU benchmark refuses headless renderer");finish();return
	create_timer(35.0).timeout.connect(deadline)
	seed(230930)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	root.use_taa=true;root.msaa_3d=Viewport.MSAA_4X
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	if RenderingServer.has_method("viewport_set_measure_render_time"):RenderingServer.call("viewport_set_measure_render_time",root.get_viewport_rid(),true)
	report.settings={"camera_fixture":{"version":2,"fov":BENCH_FOV,"distance":BENCH_DISTANCE,"pivot_height":BENCH_PIVOT_HEIGHT,"shoulder_offset":0.0,"hook":"frame_pre_draw","scope":"Rendered framing equality only; source camera code and collision queries still run; not camera behavior QA"},"rendering_method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"viewport":[1280,720],"taa":true,"msaa":"4x","directional_shadows":"medium","vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,"window_position":[DisplayServer.window_get_position().x,DisplayServer.window_get_position().y],"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"logical_input_only":true,"engine":Engine.get_version_info()}
	report.inputs={}
	for path:String in ["res://scripts/main.gd","res://scripts/preview_population.gd","res://scripts/preview_player.gd","res://scripts/weapons/preview_weapons.gd","res://scripts/weapons/preview_weapon_cargo.gd","res://data/block.json","res://project.godot"]:report.inputs[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "export_remapped_unreadable"
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	while not scene.preview_ready:await RenderingServer.frame_post_draw
	player=scene._player;weapons=scene.preview_weapons;transport=scene.preview_transport
	if not is_instance_valid(weapons) or not is_instance_valid(transport):fail("missing actual weapon/transport host");finish();return
	cargo=weapons.get_node_or_null("WeaponCargo")
	if cargo==null:fail("missing actual cargo host");finish();return
	# main.preview_ready only means setup returned; independently require fully admitted residents.
	var admitted_at:=Time.get_ticks_usec()
	report.population_readiness={"initial_count":resident_count(),"initial_status":scene.population_status,"initial_snapshot":scene.preview_population.snapshot() if scene.preview_population!=null else {},"physics_frame":Engine.get_physics_frames(),"render_frame":Engine.get_frames_drawn()}
	while (resident_count()!=3 or scene.preview_population.status!="ready") and Time.get_ticks_usec()-admitted_at<2000000:
		await RenderingServer.frame_post_draw
	report.population_readiness.final_count=resident_count()
	report.population_readiness.wait_seconds=(Time.get_ticks_usec()-admitted_at)/1000000.0
	report.population_readiness.final_snapshot=scene.preview_population.snapshot() if scene.preview_population!=null else {}
	if resident_count()!=3 or scene.preview_population.status!="ready" or int(scene._block.counts.buildings)!=8:
		fail("loaded fixture requires3fully-admittedNPC8buildings; see population_readiness snapshots");finish();return
	if startup_only:report.startup_only=true;finish();return
	player._free_mouse_look=true # Logical gameplay admission only; never capture the user cursor.
	# Common player orbit inputs; attached camera gets explicit equal framing before every draw.
	player._camera_yaw=-PI/2.0;player._camera_pitch=-.32;player._update_camera_rotation()
	weapons.equip("none")
	await wait_render(7.0)
	await phase("idle_loaded",4.0)
	var equipped:Dictionary=weapons.equip("ak74");Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if not equipped.get("ok",false):fail("AK equip failed");finish();return
	# Pitch into nearby ground, avoiding the NPCs; normal attached orbit remains.
	player._camera_pitch=-.95;player._update_camera_rotation();mouse(MOUSE_BUTTON_RIGHT,true)
	await wait_render(2.0)
	await phase("active_ak_ground_shots",4.0,true)
	mouse(MOUSE_BUTTON_RIGHT,false)
	# Position the player at authored trunk interaction anchor. Camera stays attached.
	var access:Dictionary=transport.compartments.access_profile("trunk")
	var stand:Vector3=transport.body.to_global(access.position_local_m+access.outward_local*.7);stand.y=.01;player.global_position=stand
	player._camera_yaw=0.0;player._camera_pitch=-.55;player._update_camera_rotation()
	transport.compartments.set_open("trunk",true)
	await wait_render(1.3)
	var stores:Array=[]
	for id:String in IDS:
		var eq:Dictionary=weapons.equip(id);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var stored:Dictionary=cargo.store_held()
		stores.append({"id":id,"equip":eq.get("ok",false),"store":stored.get("ok",false),"reason":stored.get("reason","")})
		if not eq.get("ok",false) or not stored.get("ok",false):fail("cargo fixture transfer failed "+id)
		await RenderingServer.frame_post_draw
	report.cargo_stores=stores;report.cargo_summary=cargo.cargo.summary(cargo.generation)
	if int(report.cargo_summary.get("count",-1))!=14 or int(report.cargo_summary.get("used_units",-1))!=100 or int(report.cargo_summary.get("capacity_units",-1))!=100:fail("cargo must actually contain14 models using100of100 units")
	await wait_render(1.0)
	await phase("open_trunk_full14",4.0)
	finish()
