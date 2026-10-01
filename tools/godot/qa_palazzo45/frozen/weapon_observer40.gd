extends SceneTree
## Finished-window counterpart of the accepted support39 test_native.gd.
## Install as res://tests/test_palazzo_finished.gd in the integrated native project.
## No alternate host/player/camera and no synthetic positive damage receipt.
## Input is synthesized through Godot's viewport input route, not physical OS input.
## Independent fixture placement is explicit; measured walks never teleport/jump.
var game: Node3D
var host: Node
var player: CharacterBody3D
var weapons: Node
var camera: Camera3D
var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var finished := false
var tracking := false
var target := Vector3.ZERO
var phase := "load"
var output := "res://tests/palazzo_finished_report.json"
var screenshots := true
var csv: FileAccess
var sample_count := 0
var last_sample_usec := 0
var begin_usec := 0
var peak_static_bytes := 0
var phase_samples: Dictionary = {}
var retained: Dictionary = {}
var site_nodes: Array[Dictionary] = []
var terminals: Array[Dictionary] = []
var bullet_terminals: Array[Dictionary] = []
var emitted_shots: Array[Dictionary] = []
var last_aim_physics_frame := -1
var last_aim_input: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		print("PALAZZO FAIL ", label)
	return ok

func step(count: int = 1) -> void:
	for i in count:
		if finished: return
		await physics_frame
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func mouse(code: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.pressed = pressed
	event.position = root.get_visible_rect().size * .5
	event.global_position = event.position
	Input.parse_input_event(event)

func _process(_delta: float) -> bool:
	if finished: return false
	if csv != null and sample_count < 12000:
		var now := Time.get_ticks_usec()
		var elapsed := now - last_sample_usec if last_sample_usec != 0 else 0
		last_sample_usec = now
		var memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
		peak_static_bytes = maxi(peak_static_bytes, memory)
		csv.store_csv_line(PackedStringArray([str(sample_count),phase,str(now-begin_usec),str(elapsed),str(Performance.get_monitor(Performance.TIME_PROCESS)*1000000.0),str(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000000.0),str(memory),str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),str(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),str(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))]))
		sample_count += 1
		if not phase_samples.has(phase): phase_samples[phase] = []
		if elapsed > 0: phase_samples[phase].append(elapsed)
	# At most one bounded correction per physics frame. Several render ticks can
	# otherwise enqueue full corrections against the same old camera transform.
	var physics_frame_id := int(Engine.get_physics_frames())
	if tracking and physics_frame_id!=last_aim_physics_frame and is_instance_valid(player) and is_instance_valid(camera):
		last_aim_physics_frame=physics_frame_id
		var direction: Vector3 = (target-camera.global_position).normalized()
		var yaw := atan2(-direction.x,-direction.z)
		var pitch := asin(clampf(direction.y,-.98,.98))
		var event := InputEventMouseMotion.new()
		event.position=root.get_visible_rect().size*.5
		event.global_position=event.position
		event.button_mask=Input.get_mouse_button_mask()
		var yaw_correction := clampf(wrapf(yaw-player._camera_yaw,-PI,PI)*.35,-.045,.045)
		var pitch_correction: float = clampf((pitch-player._camera_pitch)*.35,-.045,.045)
		event.relative = Vector2(-yaw_correction/player.mouse_sensitivity,-pitch_correction/player.mouse_sensitivity)
		# These deltas are already in viewport coordinates. parse_input_event
		# would apply the window stretch again (20x in the headless fixture).
		# Public viewport dispatch still runs the actual gameplay input handlers.
		var before_yaw: float=player._camera_yaw
		var before_pitch: float=player._camera_pitch
		root.push_input(event,true)
		last_aim_input={"route":"Viewport.push_input(local=true)","physics_frame":physics_frame_id,"relative":event.relative,"requested_radians":Vector2(yaw_correction,pitch_correction),"observed_radians":Vector2(wrapf(player._camera_yaw-before_yaw,-PI,PI),player._camera_pitch-before_pitch),"viewport_size":root.get_visible_rect().size}
	return false

func pose(local: Vector3, yaw: float) -> void:
	# Setup between independent scenarios. Never called inside a measured walk.
	tracking = false
	player.global_position = host.site.to_global(local)
	player.velocity = Vector3.ZERO
	player._camera_yaw = yaw + host.site.global_rotation.y
	player._camera_pitch = -.08
	player._update_camera_rotation()

func owned_events(kind: String) -> Array:
	var result: Array = []
	for event: Dictionary in host.snapshot().get("events",[]):
		if event.get("kind") == kind: result.append(event)
	return result

func on_terminal(receipt: Dictionary) -> void:
	# Read-only producer observation, never forwards/injects a receipt.
	var collider: Variant = receipt.get("hit",{}).get("collider")
	var pane: bool=is_instance_valid(collider) and is_instance_valid(host.site.get("_glazing")) and host.site._glazing.owns_collider(collider)
	terminals.append({"shot_id":receipt.get("shotId",receipt.get("shot_id","")),"point":str(receipt.get("point")),"position":receipt.get("point"),"direction":str(receipt.get("direction")),"normal":str(receipt.get("normal")),"collider_id":collider.get_instance_id() if is_instance_valid(collider) else 0,"owned_palazzo":is_instance_valid(collider) and (host.site.owns_collider(collider) or pane),"owned_pane":pane})
	if terminals.size() > 16: terminals.pop_front()

func on_bullet_terminal(receipt: Dictionary) -> void:
	# Native producer observation only; never creates or forwards a damage event.
	var collider: Variant=receipt.get("collider")
	bullet_terminals.append({"shot_id":receipt.get("shotId",""),"weapon_id":receipt.get("weaponId",""),"status":receipt.get("status",""),"collider_id":collider.get_instance_id() if is_instance_valid(collider) else 0,"point":receipt.get("point"),"owned_pane":is_instance_valid(collider) and is_instance_valid(host.site.get("_glazing")) and host.site._glazing.owns_collider(collider)})
	if bullet_terminals.size()>16: bullet_terminals.pop_front()

func on_shot(shot: Dictionary, muzzle: Dictionary, camera_origin: Vector3, camera_direction: Vector3) -> void:
	# Read-only observation after the real native producer commits its launch.
	emitted_shots.append({"shot_id":shot.get("shotId",""),"weapon_id":shot.get("weaponId",""),"camera_origin":str(camera_origin),"camera_direction":str(camera_direction),"muzzle_origin":str(muzzle.get("origin")),"muzzle_direction":str(muzzle.get("direction")),"target":str(target),"player":str(player.global_position),"tracking_during_commit":tracking,"physics_frame":Engine.get_physics_frames()})
	if emitted_shots.size()>16: emitted_shots.pop_front()

func snapshot_retained() -> void:
	var controls: Node = game.get_node("QuickControlsHook").controls
	retained = {"actor":player.get_instance_id(),"capsule":game._player_capsule.get_instance_id(),"layer":player.collision_layer,"mask":player.collision_mask,"world":game.get_instance_id(),"world_frame":game.global_transform,"rear":controls.rear_lights.get_instance_id(),"headlights":controls.headlights.get_instance_id(),"dashboard":controls.dashboard.get_instance_id(),"npc":[],"hud":[]}
	for owner: Variant in game.preview_population.hit_owners:
		retained.npc.append(owner.get_instance_id() if owner is Object else str(owner))
	for node: Node in game.find_children("*","CanvasLayer",true,false): retained.hud.append(node.get_instance_id())
	for node: Node in host.site.get_children():
		if node is Node3D and (str(node.name) in ["OriginalPlaza","OriginalFoundation"] or node.get_meta("palazzo_tree",false) or node.get_meta("palazzo_bench",false)):
			site_nodes.append({"id":node.get_instance_id(),"frame":node.transform})

func preserved(label: String) -> void:
	check(game._block.buildings.size()==8,label+": eight accepted buildings retained")
	check(game.preview_population.hit_owners.size()==3,label+": three NPC owners retained")
	var current_npc: Array = []
	for owner: Variant in game.preview_population.hit_owners: current_npc.append(owner.get_instance_id() if owner is Object else str(owner))
	check(current_npc==retained.npc,label+": original NPC identities retained")
	check(player.get_instance_id()==retained.actor and game._player_capsule.get_instance_id()==retained.capsule,label+": original player and capsule retained")
	check(player.collision_mask==retained.mask and player.collision_layer==retained.layer,label+": actor collision policy unchanged")
	check(game.get_instance_id()==retained.world and game.global_transform==retained.world_frame,label+": world instance and frame preserved")
	var controls: Node = game.get_node("QuickControlsHook").controls
	check(controls.street_lamps.entries.size()==8,label+": eight street lamps retained")
	check(controls.rear_lights.get_instance_id()==retained.rear and controls.headlights.get_instance_id()==retained.headlights and controls.dashboard.get_instance_id()==retained.dashboard,label+": original vehicle lights and dashboard retained")
	check(game.preview_modular30.status=="ready",label+": accepted modular owner still ready")
	for id: int in retained.hud:
		var node: Object = instance_from_id(id)
		check(is_instance_valid(node) and node is CanvasLayer and node.is_inside_tree(),label+": existing HUD CanvasLayer retained")
	for entry: Dictionary in site_nodes:
		var node: Object = instance_from_id(entry.id)
		check(is_instance_valid(node) and node.get_parent()==host.site and node.transform==entry.frame,label+": persistent plaza/foundation/tree/bench retained")

func capture(label: String, relocate: bool = true) -> void:
	if not screenshots:
		evidence.get_or_add("screenshots",{} )[label] = {"skipped":true,"reason":"headless flag or display"}
		return
	if relocate: pose(Vector3(9,.11,8),.7)
	target = host.site.to_global(Vector3(0,3,0)) if relocate else host.site._door.global_position
	tracking = true
	await step(30)
	tracking = false
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path := output.get_base_dir().path_join("palazzo_"+label+".png")
	var error := image.save_png(path)
	check(error==OK,"native camera screenshot "+label)
	evidence.get_or_add("screenshots",{} )[label] = {"path":path,"error":error,"camera":str(camera.get_path()),"native_player_camera":camera==player.get_preview_camera()}

func doorway_ray() -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(host.site.to_global(Vector3(1,1.2,4)),host.site.to_global(Vector3(1,1.2,2.2)),1,[player.get_rid()])
	return game.get_world_3d().direct_space_state.intersect_ray(query)

func door_and_entry() -> void:
	phase = "door"
	pose(Vector3(1,.11,4.1),0)
	await step(12)
	target = host.site._door.global_position
	tracking = true
	await step(20)
	tracking = false
	check(game._current_door_action().get("owner")=="palazzo","main selects real Palazzo door for E")
	evidence.door={"before_open_prompt":host.site.get_door_prompt(player),"before_open_action":game._current_door_action()}
	check(doorway_ray().get("collider")==host.site._door,"closed native leaf blocks actual entrance ray")
	key(KEY_E,true); await step(); key(KEY_E,false); await step(40)
	check(host.site._door_open and absf(host.site._door_angle-PI*.5)<.001,"E through viewport/main completes real door swing")
	check(doorway_ray().get("collider")!=host.site._door,"opened leaf clears real entrance ray")
	evidence.door.after_open_prompt=host.site.get_door_prompt(player)
	await capture("door",false)
	# Aim normal to the door for a straight W/S measurement, with the same feet.
	player._camera_yaw = host.site.global_rotation.y
	player._camera_pitch = -.08
	player._update_camera_rotation()
	phase = "entry_walk"
	var start: Vector3 = player.global_position
	var peak_y: float = host.site.to_local(start).y
	key(KEY_W,true)
	for i in 100:
		await step()
		peak_y=maxf(peak_y,host.site.to_local(player.global_position).y)
		if host.site.to_local(player.global_position).z<1.6: break
	key(KEY_W,false); await step(8)
	var inside: Vector3 = host.site.to_local(player.global_position)
	var entered := inside.z<2.25 and inside.y>=.27 and player.is_on_floor()
	check(entered,"same native player walks over real entry access and through opened door")
	evidence.entry = {"start":str(start),"finish":str(player.global_position),"local_finish":str(inside),"max_local_feet_y":peak_y,"jump_used":false,"teleport_during_measurement":false,"passed":entered,"limitation_if_failed":"original foundation rises21cm; no player modification or raised fixture start"}
	if entered:
		phase = "exit_walk"
		key(KEY_S,true)
		for i in 100:
			await step()
			if host.site.to_local(player.global_position).z>3.85: break
		key(KEY_S,false); await step(8)
		check(host.site.to_local(player.global_position).z>3.7,"same actor walks back outside without relocation")
		evidence.exit = {"finish":str(player.global_position),"local_finish":str(host.site.to_local(player.global_position)),"teleported":false}
		evidence.door.before_close_prompt=host.site.get_door_prompt(player)
		evidence.door.before_close_action=game._current_door_action()
		key(KEY_E,true); await step(); key(KEY_E,false); await step(40)
		evidence.door.after_close_prompt=host.site.get_door_prompt(player)
		evidence.door.after_close_action=game._current_door_action()
		evidence.door.after_close_status=host.site.get_stats()
		check(not host.site._door_open and absf(host.site._door_angle)<.001,"second native E closes door after exit")
		check(doorway_ray().get("collider")==host.site._door,"closed door restores actual entrance collision")
	else: evidence.exit={"verified":false,"reason":"entry failed; no repositioned exit claim"}

func native_sight(wanted: Object) -> bool:
	var ray: Dictionary = weapons._projectile_ray({"origin":camera.global_position,"direction":-camera.global_basis.z,"range":100.0})
	var muzzle: Dictionary = weapons.presentation.current_muzzle()
	if not ray.has("point") or not muzzle.get("ok",false): return false
	var direction: Vector3 = (ray.point-muzzle.origin).normalized()
	var actual: Dictionary = weapons._projectile_ray({"origin":muzzle.origin,"direction":direction,"range":muzzle.origin.distance_to(ray.point)+.03})
	return ray.get("collider")==wanted and actual.get("collider")==wanted

func aim_sample(wanted: Object) -> Dictionary:
	var muzzle: Dictionary=weapons.presentation.current_muzzle()
	var direction: Vector3=(target-camera.global_position).normalized()
	var forward: Vector3=-camera.global_basis.z
	var arm: Node3D=player._spring_arm
	return {"physics_frame":Engine.get_physics_frames(),"yaw":player._camera_yaw,"pitch":player._camera_pitch,"camera_position":camera.global_position,"camera_direction":forward,"target":target,"angular_error_rad":forward.angle_to(direction),"muzzle_ok":muzzle.get("ok",false),"muzzle_origin":muzzle.get("origin",Vector3.ZERO),"player_velocity":player.velocity,"arm_position":arm.position,"arm_length":arm.spring_length,"aiming":weapons._aiming,"aim_camera":weapons.aim_camera.stats(),"both_rays":native_sight(wanted),"last_motion":last_aim_input.duplicate(true)}

func settle_aim(wanted: Object, label: String) -> bool:
	var previous: Dictionary={}
	var samples: Array=[]
	var stable:=0
	var still_frames:=0
	tracking=true
	for i in 300:
		await step()
		var sample: Dictionary=aim_sample(wanted)
		samples.append(sample)
		if samples.size()>16: samples.pop_front()
		var settled: bool=sample.both_rays and sample.muzzle_ok and sample.aiming and sample.angular_error_rad<.004 and float(sample.aim_camera.blend)>.995 and player.velocity.length()<.05 and weapons.fire_state.cooldown<=0
		if not previous.is_empty():
			settled=settled and sample.camera_position.distance_to(previous.camera_position)<.006 and sample.muzzle_origin.distance_to(previous.muzzle_origin)<.012 and sample.camera_direction.angle_to(previous.camera_direction)<.002
		else: settled=false
		previous=sample
		if tracking:
			stable=stable+1 if settled else 0
			if stable>=8:
				tracking=false
				# Motion dispatch is synchronous; drain any buffered button input.
				# Never call gameplay handlers or write camera/muzzle state here.
				Input.flush_buffered_events()
				still_frames=0
		elif settled:
			still_frames+=1
			if still_frames>=6:
				evidence.get_or_add("aim",{})[label]={"stable_tracking_frames":stable,"still_frames":still_frames,"samples":samples,"before_fire":sample}
				return true
		else:
			stable=0; still_frames=0; tracking=true
	tracking=false
	evidence.get_or_add("aim",{})[label]={"settled":false,"samples":samples,"stable_tracking_frames":stable,"still_frames":still_frames}
	return false

func fire_rpg(wanted: CollisionObject3D, at: Vector3, label: String) -> Dictionary:
	target=at; mouse(MOUSE_BUTTON_RIGHT,true)
	var settled: bool=await settle_aim(wanted,label)
	if not check(settled and native_sight(wanted),label+": camera and mounted muzzle remain settled on owned collision before fire"):
		tracking=false; mouse(MOUSE_BUTTON_RIGHT,false); return {}
	var ammo: int=weapons.fire_state.magazine
	var shots: int=weapons.shots_count
	var before: int=owned_events("blast").size()
	var admitted: int=host.snapshot().damage.stats.admitted_blast_events
	var terminal_count:=terminals.size()
	mouse(MOUSE_BUTTON_LEFT,true); await step(2); mouse(MOUSE_BUTTON_LEFT,false)
	evidence.aim[label].after_fire=aim_sample(wanted)
	for i in 240:
		await step()
		if owned_events("blast").size()>before: break
	tracking=false; mouse(MOUSE_BUTTON_RIGHT,false)
	check(weapons.shots_count==shots+1 and weapons.fire_state.magazine==ammo-1,label+": native RPG consumes exactly one round")
	check(terminals.size()==terminal_count+1 and terminals[-1].owned_palazzo and terminals[-1].collider_id==wanted.get_instance_id(),label+": native projectile terminal hits the actual aimed owned collider")
	check(host.snapshot().damage.stats.admitted_blast_events==admitted+1,label+": authenticated bridge admits one native terminal")
	if not check(owned_events("blast").size()==before+1,label+": one native event reaches integrated owner"): return {}
	var event: Dictionary=owned_events("blast")[-1]
	check(event.result.get("committed",false) and event.result.get("detached")==4,label+": exactly four tiles released")
	return event

func solid_face_witness(body: RigidBody3D,expected: CollisionObject3D) -> Dictionary:
	# A compound tile's origin can be window air. Sample a real enabled BoxShape
	# face and require native collision to prove that face is currently occupied.
	for child: Node in body.get_children():
		if not child is CollisionShape3D or child.disabled or not child.shape is BoxShape3D: continue
		var point: Vector3=child.to_global(Vector3(0,0,child.shape.size.z*.5))
		var normal: Vector3=child.global_basis.z.normalized()
		var query:=PhysicsRayQueryParameters3D.create(point+normal*.03,point-normal*.03,1,[player.get_rid()])
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.get("collider")==expected:
			return {"point":hit.position,"normal":normal,"shape_size":child.shape.size,"role":child.get_meta("finished_role","core"),"tile_id":body.get_instance_id(),"original_collider_id":expected.get_instance_id()}
	return {}

func native_reload_round(label: String) -> bool:
	if weapons.fire_state.magazine>0 and weapons.fire_state.cooldown<=0: return true
	key(KEY_R,true); await step(); key(KEY_R,false)
	for i in 300:
		await step()
		if weapons.fire_state.magazine>0 and weapons.fire_state.cooldown<=0: break
	return check(weapons.fire_state.magazine>0 and weapons.fire_state.cooldown<=0,label+": native R reload supplies an existing round")

func rpg_case() -> void:
	phase="native_rpg"
	pose(Vector3(-14,.11,0),-PI*.5); await step(15)
	var panel: RigidBody3D
	for body: RigidBody3D in host.site.wall_panels:
		if str(body.name).begins_with("Side") and body.position.distance_to(Vector3(-4,1.57,0))<.01: panel=body
	if not check(panel!=null,"original west side panel exists"): return
	if not check(weapons.equip("rpg").get("ok",false),"native inventory equips existing RPG"): return
	if not await native_reload_round("first RPG"): return
	var size: Vector3=panel.get_meta("section_size")
	var witnesses: Dictionary={}
	for tile: RigidBody3D in panel.get_meta("pooled_fragments",[]):
		var witness: Dictionary=solid_face_witness(tile,panel)
		if not witness.is_empty(): witnesses[tile.get_instance_id()]=witness
	if not check(witnesses.size()==panel.get_meta("pooled_fragments").size(),"every pooled tile has a native-blocked real solid face before destruction"): return
	# This lies in the actual left core, outside the centered .95 m window.
	# At y=.12 the unchanged .63 m source selector contains only three cells;
	# y=0 remains on this same solid core and contains four genuine cells.
	var first: Dictionary=await fire_rpg(panel,panel.to_global(Vector3(-.78,0,size.z*.5)),"first RPG")
	evidence.rpg={"first":first,"solid_face_witnesses":witnesses,"synthetic_positive_receipt":false}
	if first.is_empty(): return
	check(host.site.pieces.size()==116 and detached_architecture_count()==4,"local hit expands only one source panel97-1+20 and releases four structural tiles")
	if not await native_reload_round("second RPG"): return
	var remaining: RigidBody3D
	var remaining_face: Dictionary={}
	var nearest:=INF
	for tile: RigidBody3D in panel.get_meta("pooled_fragments",[]):
		if tile.get_meta("detached",false): continue
		var face: Dictionary=solid_face_witness(tile,tile)
		if face.is_empty(): continue
		var score: float=panel.to_local(face.point).distance_squared_to(Vector3(0,-.6,size.z*.5))
		if score<nearest: nearest=score; remaining=tile; remaining_face=face
	if not check(remaining!=null,"repeat targets actual surviving lower tile"): return
	evidence.rpg.repeat_face=remaining_face
	evidence.rpg.repeat=await fire_rpg(remaining,remaining_face.point,"repeat RPG")
	check(detached_architecture_count()==8 and not host.site.collapsing,"two real rounds release eight structural tiles without whole collapse")
	await step(2) # Let the real physics space retire the old panel collision.
	var ray_holes := 0
	for tile: RigidBody3D in panel.get_meta("pooled_fragments",[]):
		if not tile.get_meta("detached",false): continue
		if not witnesses.has(tile.get_instance_id()): continue
		var face: Dictionary=witnesses[tile.get_instance_id()]
		var query:=PhysicsRayQueryParameters3D.create(face.point+face.normal*.03,face.point-face.normal*.03,1,[player.get_rid()])
		if game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): ray_holes+=1
	check(ray_holes==8,"eight previously blocked solid faces become actual native collision holes")
	evidence.rpg.native_static_ray_holes=ray_holes
	for neighbour: RigidBody3D in host.site.wall_panels:
		if neighbour!=panel: check(neighbour.freeze and not neighbour.get_meta("detached",false),"other original wall panel remains intact")
	await capture("local")

func west_panel() -> RigidBody3D:
	for body: RigidBody3D in host.site.wall_panels:
		if str(body.name).begins_with("Side") and body.position.distance_to(Vector3(-4,1.57,0))<.01: return body
	return null

func pane_target(panel: RigidBody3D) -> Dictionary:
	if not is_instance_valid(panel) or not is_instance_valid(host.site.get("_glazing")) or not panel.has_meta("finished_window"): return {}
	var window: Dictionary=panel.get_meta("finished_window")
	for body: Node in host.site._glazing.get_children():
		if not body is StaticBody3D or not host.site._glazing.owns_collider(body): continue
		if body.global_position.distance_to(panel.to_global(window.center))>.0001: continue
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.disabled or not child.shape is BoxShape3D: continue
			# A pane quadrant, clear of the actual brass mullions and wall core.
			var point: Vector3=child.to_global(child.shape.size*Vector3(-.27,.23,.5))
			var normal: Vector3=child.global_basis.z.normalized()
			var query:=PhysicsRayQueryParameters3D.create(point+normal*.03,point-normal*.03,1,[player.get_rid()])
			if game.get_world_3d().direct_space_state.intersect_ray(query).get("collider")==body:
				return {"body":body,"point":point,"normal":normal,"pane_id":body.get_instance_id(),"wall_id":panel.get_instance_id()}
	return {}

func glass_cases() -> void:
	phase="native_glass_bullet"
	pose(Vector3(-14,.11,0),-PI*.5); await step(15)
	var panel: RigidBody3D=west_panel()
	var pane: Dictionary=pane_target(panel)
	if not check(not pane.is_empty(),"finished wall has a separately owned native pane in its actual opening"): return
	if not check(weapons.inventory.get_owned_ids().has("tt_pistol") and weapons.equip("tt_pistol").get("ok",false),"existing inventory equips real TT for the glass bullet"): return
	if not await native_reload_round("TT pane shot"): return
	target=pane.point; mouse(MOUSE_BUTTON_RIGHT,true)
	if not check(await settle_aim(pane.body,"TT glass") and native_sight(pane.body),"native TT camera and mounted muzzle target the actual pane"):
		tracking=false; mouse(MOUSE_BUTTON_RIGHT,false); return
	var shots: int=weapons.shots_count; var ammo: int=weapons.fire_state.magazine
	var before_events: int=owned_events("glass_bullet").size()
	var before_terminals: int=bullet_terminals.size()
	var before_forwarded: int=host.snapshot().damage.stats.forwarded_glass_candidates
	var before_broken: int=host.site._glazing.stats().broken
	var before_structural: int=detached_architecture_count()
	mouse(MOUSE_BUTTON_LEFT,true); await step(2); mouse(MOUSE_BUTTON_LEFT,false)
	for i in 120:
		await step()
		if pane.body.collision_layer==0 and owned_events("glass_bullet").size()>before_events: break
	tracking=false; mouse(MOUSE_BUTTON_RIGHT,false)
	check(weapons.shots_count==shots+1 and weapons.fire_state.magazine==ammo-1,"one native TT shot spends exactly one existing bullet")
	check(bullet_terminals.size()==before_terminals+1 and bullet_terminals[-1].status=="hit" and bullet_terminals[-1].collider_id==pane.pane_id and bullet_terminals[-1].owned_pane,"native bullet terminal identifies the actual pane")
	check(host.snapshot().damage.stats.forwarded_glass_candidates==before_forwarded+1,"native authenticated bullet bridge forwards exactly one glass candidate")
	var bullet_events: Array=owned_events("glass_bullet")
	check(bullet_events.size()==before_events+1 and bullet_events[-1].result.get("ok",false),"integrated glass owner accepts that native bullet")
	check(host.site._glazing.stats().broken==before_broken+1 and pane.body.collision_layer==0,"Walk delayed fracture removes the actual pane collision")
	var hole:=PhysicsRayQueryParameters3D.create(pane.point+pane.normal*.03,pane.point-pane.normal*.03,1,[player.get_rid()])
	check(game.get_world_3d().direct_space_state.intersect_ray(hole).is_empty(),"broken glass reveals an actual empty aperture without hidden wall backing")
	check(detached_architecture_count()==before_structural and panel.freeze and not panel.get_meta("fracture_active",false),"TT glass shot retains the original stone wall core")
	evidence.glass_bullet={"pane_id":pane.pane_id,"wall_id":pane.wall_id,"events":bullet_events,"terminals":bullet_terminals.duplicate(true),"glazing":host.site._glazing.stats(),"synthetic_positive_receipt":false}
	await reset_by_key("restore after native glass bullet")
	await step(30)
	phase="native_rpg_pane"
	panel=west_panel(); pane=pane_target(panel)
	if not check(not pane.is_empty(),"J restores a new actual pane before the RPG contact"): return
	if not check(weapons.equip("rpg").get("ok",false),"existing RPG equips for independent pane contact"): return
	if not await native_reload_round("RPG pane contact"): return
	var event: Dictionary=await fire_rpg(pane.body,pane.point,"RPG pane")
	if not event.is_empty():
		check(terminals[-1].owned_pane and event.result.get("contact_collider_id")==pane.pane_id,"RPG admission retains the original native glass collider")
		check(event.result.get("original_position") is Vector3 and event.result.original_position.is_equal_approx(terminals[-1].position) and event.result.get("original_radius")==.8,"RPG pane area damage retains the unmodified native contact and breach radius")
		check(event.result.get("area_target_id")==panel.get_instance_id() and event.result.get("area_distance_m",-1.0)>=0 and event.result.area_distance_m<=.8,"pane blast affects the actual nearby structural core as a separate area target")
		for i in 120:
			await step()
			if pane.body.collision_layer==0: break
		check(pane.body.collision_layer==0,"native RPG also completes the Walk pane fracture")
	evidence.rpg_pane={"event":event,"pane_id":pane.pane_id,"wall_id":pane.wall_id,"glazing":host.site._glazing.stats(),"synthetic_positive_receipt":false}
	await reset_by_key("restore after native RPG pane")

func is_authored_unsupported_table(body: RigidBody3D) -> bool:
	# The original table's visual legs have no collision. Support39 correctly
	# releases this one authored body; no wall, roof or other prop is exempted.
	return str(body.name)=="LobbyTable96" and body.get_meta("section_size",Vector3.ZERO).is_equal_approx(Vector3(1.5,.12,.8))

func detached_architecture_count() -> int:
	var count:=0
	for body: RigidBody3D in host.site.pieces:
		if body.get_meta("detached",false) and not is_authored_unsupported_table(body): count+=1
	return count

func rebuilt_architecture_snapshot() -> Dictionary:
	var records: Array[Dictionary]=[]
	var invalid: Array[String]=[]
	var tables: Array[Dictionary]=[]
	for body: RigidBody3D in host.site.pieces:
		if is_authored_unsupported_table(body):
			tables.append({"id":body.get_instance_id(),"name":str(body.name),"detached":body.get_meta("detached",false),"support_released":body.get_meta("support_released",false)})
			if body.get_meta("detached",false) and not body.get_meta("support_released",false): invalid.append("table_without_support_release")
			continue
		records.append({"id":body.get_instance_id(),"name":str(body.name),"frame":body.transform})
		if not host.site.owns_collider(body) or not body.freeze or body.get_meta("detached",false) or body.get_meta("fracture_active",false) or (body.collision_layer&1)==0: invalid.append(str(body.name))
	return {"generation":host.site.rebuild_generation,"records":records,"invalid":invalid,"authored_table":tables}

func reset_by_key(label: String) -> Dictionary:
	var generation: int=host.site.get_stats().generation
	var before: int=owned_events("reset").size()
	key(KEY_J,true); await step(); key(KEY_J,false)
	for i in 60:
		await step()
		if host.site.get_stats().generation>generation and not host.site.rebuilding: break
	var stats: Dictionary=host.site.get_stats()
	var architecture: Dictionary=rebuilt_architecture_snapshot()
	check(owned_events("reset").size()==before+1,label+": J reaches integrated reset owner once")
	check(stats.generation==generation+1 and stats.pieces==97 and stats.pool==560 and architecture.records.size()==96 and architecture.invalid.is_empty() and architecture.authored_table.size()==1 and not stats.collapsing,label+": original structural inventory restored; only authored unsupported table may fall")
	check(not host.site._door_open and absf(host.site._door_angle)<.001,label+": original closed door restored")
	evidence.get_or_add("resets",{})[label]={"stats":stats,"architecture":architecture}
	return architecture

func collapse_and_reset() -> void:
	phase="full_collapse"
	pose(Vector3(9,.11,8),.7); await step(12)
	var expected: int=host.site.pieces.size()
	var before: int=owned_events("collapse").size()
	key(KEY_K,true); await step(); key(KEY_K,false)
	if not check(owned_events("collapse").size()==before+1,"native K reaches integrated full collapse once"): return
	var command: Dictionary=owned_events("collapse")[-1]
	check(command.result.get("started",false),"nearby player starts actual full collapse")
	for i in 180:
		await step()
		if host.event_status(command.event_id).get("completed",false): break
	var stats: Dictionary=host.site.get_stats()
	check(host.event_status(command.event_id).get("completed",false),"all three timed collapse stages finish")
	check(stats.detached==expected and stats.pieces==expected and stats.pool==560,"full collapse releases current exact sections without activating unused pool")
	evidence.collapse={"command":command,"terminal":host.event_status(command.event_id),"stats":stats,"expected_current_sections":expected}
	await capture("full")
	phase="reset"
	await reset_by_key("completed collapse")
	preserved("after reset")
	# Cancel pending timed stages using the same actual main key routes.
	key(KEY_K,true); await step(); key(KEY_K,false); await step(10)
	var pending: Array=owned_events("collapse")
	var cancel_id: String=str(pending[-1].event_id) if not pending.is_empty() else ""
	var rebuilt: Dictionary=await reset_by_key("cancel in-flight collapse")
	await step(140)
	var after: Dictionary=rebuilt_architecture_snapshot()
	var changed: Array[String]=[]
	for record: Dictionary in rebuilt.records:
		var body: Object=instance_from_id(record.id)
		if not is_instance_valid(body) or not body is RigidBody3D or not host.site.pieces.has(body) or not body.transform.is_equal_approx(record.frame): changed.append(record.name)
	check(host.site.pieces.size()==97 and after.records.size()==96 and after.invalid.is_empty() and after.authored_table.size()==1 and after.generation==rebuilt.generation and changed.is_empty(),"cancelled delayed stages cannot detach or move rebuilt support-connected architecture")
	check(host.event_status(cancel_id).get("state")=="cancelled_generation","cancelled native collapse has explicit terminal state")
	evidence.cancel={"event_id":cancel_id,"terminal":host.event_status(cancel_id),"after_wait":after,"changed_architecture":changed,"permitted_exception":"one original LobbyTable96, only with support_released provenance"}

func run() -> void:
	begin_usec=Time.get_ticks_usec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		if arg=="--palazzo-headless": screenshots=false
	if DisplayServer.get_name()=="headless": screenshots=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	csv=FileAccess.open(output.get_base_dir().path_join("palazzo_live_frames.csv"),FileAccess.WRITE)
	if csv!=null: csv.store_csv_line(PackedStringArray(["sample","phase","elapsed_usec","observed_frame_usec","engine_process_usec","engine_physics_usec","godot_static_bytes","nodes","draw_calls","primitives"]))
	create_timer(120).timeout.connect(func():
		if not finished: check(false,"120 second bounded fixture watchdog"); finish())
	var packed: PackedScene=load("res://scenes/main.tscn") as PackedScene
	if not check(packed!=null,"integrated native main scene exists"): finish(); return
	game=packed.instantiate(); root.add_child(game); current_scene=game
	for i in 1200:
		await process_frame
		if game.preview_ready: break
	if not check(game.preview_ready,"full native scene ready"): finish(); return
	player=game._player; weapons=game.preview_weapons; camera=player.get_preview_camera()
	host=game.get("preview_palazzo")
	if not check(is_instance_valid(host) and host.has_method("snapshot") and host.get("status")=="ready","main has already prepared and bound Palazzo host"): finish(); return
	if not check(is_instance_valid(host.site),"integrated site exists"): finish(); return
	if not check(is_instance_valid(host.site.get("_glazing")) and host.site._glazing.stats().ready and host.site.get_stats().get("finished_errors",[]).is_empty(),"finished facade has current real glazing and no cold geometry errors"): finish(); return
	evidence.initial_host=host.snapshot()
	evidence.site_frame=str(host.site.global_transform)
	await step(6)
	# Capture mouse using the real native click route; do not set capture flags.
	if not player._free_mouse_look:
		mouse(MOUSE_BUTTON_LEFT,true); await step(); mouse(MOUSE_BUTTON_LEFT,false); await step(2)
	if not check(player._free_mouse_look,"native click enables normal gameplay input"): finish(); return
	if weapons.rpg_effects.has_signal("native_impact"): weapons.rpg_effects.connect("native_impact",on_terminal)
	if weapons.has_signal("shot_emitted"): weapons.connect("shot_emitted",on_shot)
	if weapons.effects.has_signal("projectile_resolved"): weapons.effects.connect("projectile_resolved",on_bullet_terminal)
	snapshot_retained()
	var stats: Dictionary=host.site.get_stats()
	check(stats.pieces==97 and stats.panels==28 and stats.pool==560 and stats.trees==4 and stats.benches==2,"exact original Palazzo and landscaped site inventory")
	preserved("before")
	phase="intact"; await capture("intact")
	await door_and_entry()
	await rpg_case()
	await collapse_and_reset()
	await glass_cases()
	preserved("final")
	evidence.final_host=host.snapshot()
	evidence.native_terminals=terminals
	evidence.native_bullet_terminals=bullet_terminals
	evidence.emitted_shots=emitted_shots
	finish()

func finish() -> void:
	if finished: return
	finished=true; tracking=false
	for code: Key in [KEY_W,KEY_S,KEY_E,KEY_R,KEY_K,KEY_J]: key(code,false)
	mouse(MOUSE_BUTTON_LEFT,false); mouse(MOUSE_BUTTON_RIGHT,false)
	if csv!=null: csv.close(); csv=null
	var timings: Dictionary={}
	for label: String in phase_samples:
		var values: Array=phase_samples[label]
		values.sort()
		if not values.is_empty(): timings[label]={"samples":values.size(),"frame_usec_p50":values[int((values.size()-1)*.50)],"frame_usec_p95":values[int((values.size()-1)*.95)],"frame_usec_max":values[-1]}
	var report: Dictionary={"status":"PASS" if failures.is_empty() else "UNRESOLVED_INTEGRATION_GATES","checks":checks,"failures":failures,"evidence":evidence,"elapsed_usec":Time.get_ticks_usec()-begin_usec,"phase_timings":timings,"frame_samples":sample_count,"peak_godot_static_bytes":peak_static_bytes,"csv":"palazzo_live_frames.csv","native_scene":"res://scenes/main.tscn","integrated_existing_host":true,"manual_OS_input_verified":false,"synthetic_positive_damage_receipt":false,"headless":not screenshots,"loaded_performance_accepted":false,"measurement_limit":"single instrumented functional run; CPU process/physics monitors are engine timings, static bytes are not OS RSS; no matched before/after FPS claim"}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t")); file.close()
	else: print("PALAZZO report write failed: ",output)
	print("PALAZZO_NATIVE ",report.status," checks=",checks," failures=",failures.size()," report=",output)
	quit(0 if failures.is_empty() else 2)
