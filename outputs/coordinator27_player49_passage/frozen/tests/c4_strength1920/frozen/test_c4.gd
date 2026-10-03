extends SceneTree
## Install beside c4_equipment.gd in the integrated game; author does not run it.
## Real main/player/camera/Q controls and viewport input. No positive synthetic
## RPG/bullet/C4 receipt. Explicit cold fixture pose precedes the measured hold.
const Equipment = preload("c4_equipment.gd")
var game: Node3D
var site: Node3D
var wall: RigidBody3D
var player: CharacterBody3D
var weapons: Node
var camera: Camera3D
var equipment: Node
var original_callback: Callable
var equipment_only := false
var screenshots := true
var output := "res://tests/c4_report.json"
var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var callbacks: Array[Dictionary] = []
var finished := false
var tracking := false
var target := Vector3.ZERO
var last_aim_frame := -1
var started_usec := 0
var holding_observation := false
var hold_start_frame := -1
var first_placed_frame := -1
var original_owned: Array = []
var original_uid := ""
var pistol := "tt_pistol"
var original_actor: Variant
var original_life: Variant

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks+=1
	if not value: failures.append(label); print("C4 FAIL ",label)
	return value

func step(count: int=1) -> void:
	for i in count:
		if finished: return
		await physics_frame
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event)

func mouse(button: MouseButton, pressed: bool, at: Vector2=Vector2(-1,-1)) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=button; event.pressed=pressed
	event.position=root.get_visible_rect().size*.5 if at.x<0 else at; event.global_position=event.position
	event.button_mask=Input.get_mouse_button_mask()
	if at.x>=0:
		# GUI positions are already content-viewport coordinates. Applying the
		# window stretch again would click a different button in headless/windowed
		# runs. Deliver exactly once through the native viewport GUI route.
		root.push_input(event,true)
	else:
		# Gameplay LMB has no screen-space target: the owner ray uses the camera.
		# Keep the real Input singleton's pressed state for the entire 3 s hold.
		Input.parse_input_event(event)

func _process(_delta: float) -> bool:
	if finished: return false
	if holding_observation and is_instance_valid(equipment) and first_placed_frame<0 and equipment.snapshot().placed.size()>0:
		first_placed_frame=int(Engine.get_physics_frames())
	var frame: int=int(Engine.get_physics_frames())
	if tracking and frame!=last_aim_frame and is_instance_valid(player) and is_instance_valid(camera):
		last_aim_frame=frame
		var direction: Vector3=(target-camera.global_position).normalized()
		var yaw: float=atan2(-direction.x,-direction.z); var pitch: float=asin(clampf(direction.y,-.98,.98))
		var correction:=Vector2(clampf(wrapf(yaw-player._camera_yaw,-PI,PI)*.35,-.045,.045),clampf((pitch-player._camera_pitch)*.35,-.045,.045))
		var event:=InputEventMouseMotion.new(); event.position=root.get_visible_rect().size*.5; event.global_position=event.position; event.button_mask=Input.get_mouse_button_mask()
		event.relative=-correction/player.mouse_sensitivity
		root.push_input(event,true)
	return false

func q_choice(button: Button, label: String) -> bool:
	if not weapons.menu_open:
		key(KEY_Q,true); await step(); key(KEY_Q,false); await step(2)
	if not check(weapons.menu_open,label+": Q opened the actual arsenal"): return false
	weapons._walk_ui.scroll.ensure_control_visible(button)
	await step(3)
	if is_instance_valid(equipment) and button==equipment._button and not evidence.get("screenshots",{}).has("arsenal"):
		await capture("arsenal")
	var at: Vector2=button.get_global_rect().get_center()
	if not check(button.is_visible_in_tree() and not button.disabled and weapons._walk_ui.scroll.get_global_rect().has_point(at),label+": real button visible inside Q scroll"): return false
	var motion:=InputEventMouseMotion.new(); motion.position=at; motion.global_position=at; root.push_input(motion,true)
	mouse(MOUSE_BUTTON_LEFT,true,at); await step(); mouse(MOUSE_BUTTON_LEFT,false,at); await step(3)
	return check(not weapons.menu_open,label+": native GUI click closed arsenal")

func capture(label: String) -> void:
	if not evidence.has("screenshots"): evidence.screenshots={}
	if not screenshots:
		evidence.screenshots[label]={"skipped":true,"reason":"--palazzo-headless or headless display"}
		return
	# Read the rendered root viewport; do not relocate/replace the native camera,
	# release LMB, advance placement manually or manufacture a timer image.
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	if not check(image!=null and not image.is_empty(),label+": actual rendered root texture available"): return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var path: String=output.get_base_dir().path_join("c4_"+label+".png")
	var error: Error=image.save_png(path)
	check(error==OK,label+": actual GPU screenshot saved")
	evidence.screenshots[label]={"path":path,"error":error,"physics_frame":Engine.get_physics_frames(),"viewport_size":root.get_visible_rect().size,"camera":str(camera.get_path()),"native_camera":camera==player.get_preview_camera(),"equipment_elapsed_seconds":equipment.snapshot().elapsed_seconds,"real_LMB_held":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)}

func native_ray() -> Dictionary:
	var from: Vector3=camera.global_position
	var query:=PhysicsRayQueryParameters3D.create(from,from-camera.global_basis.z*30,1|512,[player.get_rid()]); query.hit_from_inside=true
	return game.get_world_3d().direct_space_state.intersect_ray(query)

func aim_wall(local_point: Vector3=Vector3(-.78,0,.17)) -> bool:
	target=wall.to_global(local_point)
	tracking=true
	for i in 180:
		await step()
		var hit:=native_ray()
		if hit.get("collider")==wall and hit.position.distance_to(target)<.015: break
	tracking=false; await step(8)
	var hit:=native_ray()
	var owner_target: Dictionary=equipment._target() # Read-only actual owner query.
	evidence.aim={"ray_collider":str(hit.get("collider")),"ray_point":str(hit.get("position")),"target":str(target),"owner_target":not owner_target.is_empty(),"player":str(player.global_position),"camera":str(camera.global_transform),"floor":player.is_on_floor(),"mouse_mode":Input.mouse_mode}
	if not check(hit.get("collider")==wall,"actual camera ray hits the selected native wall"): return false
	if not check(not owner_target.is_empty() and owner_target.body==wall,"actor range and unobstructed native placement query agree"): return false
	return check(player.is_on_floor() and Vector2(player.velocity.x,player.velocity.z).length()<.08,"same native actor is stationary on real ground")

func callback(event: Dictionary) -> Dictionary:
	# Event arrives only from the real selected equipment after native LMB. These
	# copies are NEGATIVE probes; no positive receipt or trigger is fabricated.
	var before: int=equipment.snapshot().placed.size()
	var copy: Dictionary=event.duplicate()
	var copied: Dictionary=equipment.consume_detonation(copy)
	check(not copied.get("ok",false),"copied C4 capability cannot consume the real charge")
	var forged: Dictionary=event.duplicate(); forged.power=481.0
	check(not equipment.consume_detonation(forged).get("ok",false),"modified copied capability is rejected")
	var result: Dictionary={}
	if equipment_only:
		var claim: Dictionary=equipment.consume_detonation(event)
		result={"ok":claim.get("ok",false),"equipment_only":true,"geometry_damage_tested":false}
	else:
		var actual: Variant=original_callback.call(event)
		result=actual if actual is Dictionary else {"ok":false,"reason":"root_callback_result"}
	check(result.get("ok",false),"configured actual callback accepts the real equipment dispatch")
	var repeated: Dictionary=equipment.consume_detonation(event)
	check(not repeated.get("ok",false),"same delivered capability cannot be consumed twice")
	check(equipment.snapshot().placed.size()==before-1,"one actual planted item removed exactly once")
	callbacks.append({"event_id":event.get("event_id"),"placement_id":event.get("placement_id"),"item_uid":event.get("item_uid"),"actor_id":event.get("actor_id"),"life_generation":event.get("life_generation"),"position":str(event.get("position")),"normal":str(event.get("normal")),"source_id":event.get("source_id"),"generation":event.get("generation"),"collider_id":event.collider.get_instance_id(),"physics_frame":Engine.get_physics_frames(),"damage":event.get("damage"),"radius":event.get("radius"),"scope":event.get("scope"),"callback":result,"copied_rejected":not copied.get("ok",false),"replay_rejected":not repeated.get("ok",false)})
	check(event.get("scope")=="new_local_session_c4" and event.get("authority")=="local_c4_equipment" and event.get("weapon_id")=="c4","C4 remains its own equipment authority, not an RPG receipt")
	check(event.get("damage")==480.0 and event.get("radius")==2.4,"actual delivered parameters are damage480 radius2.4")
	return result

func hold_cases() -> bool:
	var shots_before: int=weapons.shots_count
	var start_frame: int=int(Engine.get_physics_frames())
	mouse(MOUSE_BUTTON_LEFT,true)
	await step(2)
	if not check(equipment.snapshot().holding,"native LMB begins a hold on the wall"): mouse(MOUSE_BUTTON_LEFT,false); return false
	check(equipment._card.visible and equipment._card.heading.text=="Установка C4","world-anchored native progress card appears")
	check(equipment._card.counter.text.contains("с") and equipment._card.counter.text.contains(","),"visible countdown uses Russian decimal/time formatting")
	check(not equipment._card.get_global_rect().has_point(root.get_visible_rect().size*.5),"progress card leaves native aiming centre uncovered")
	# Subtract the already elapsed physical frames; independent timer targets
	# 2.9 simulated seconds with at most one physics-tick scheduling quantization.
	var elapsed: float=float(Engine.get_physics_frames()-start_frame)/float(Engine.physics_ticks_per_second)
	await create_timer(maxf(.01,2.9-elapsed),false,true).timeout
	var before_release: Dictionary=equipment.snapshot()
	var release_frame: int=int(Engine.get_physics_frames())
	mouse(MOUSE_BUTTON_LEFT,false); await step(2)
	evidence.cancel_2_9={"physics_seconds":float(release_frame-start_frame)/float(Engine.physics_ticks_per_second),"before_release":before_release,"after_release":equipment.snapshot()}
	check(before_release.elapsed_seconds>=2.85 and before_release.elapsed_seconds<3.0,"release occurs around2.9s and strictly before the3s threshold")
	check(equipment.snapshot().placed.is_empty() and not equipment.snapshot().holding,"early release cancels without placing a charge")
	check(callbacks.is_empty() and weapons.shots_count==shots_before,"cancelled hold emitted no C4 dispatch or native firearm shot")
	await step(4)
	if not await aim_wall(): return false
	first_placed_frame=-1; hold_start_frame=int(Engine.get_physics_frames()); holding_observation=true
	mouse(MOUSE_BUTTON_LEFT,true)
	await create_timer(1.2,false,true).timeout
	check(equipment.snapshot().holding and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"real continuous LMB remains held at the timer screenshot")
	await capture("timer")
	var held_seconds: float=float(Engine.get_physics_frames()-hold_start_frame)/float(Engine.physics_ticks_per_second)
	await create_timer(maxf(.01,3.15-held_seconds),false,true).timeout
	await step(2)
	var state: Dictionary=equipment.snapshot()
	if not check(state.placed.size()==1 and state.mode=="remote","continuous native hold installs exactly one charge then equips remote"):
		mouse(MOUSE_BUTTON_LEFT,false); holding_observation=false; return false
	check(first_placed_frame>=0 and float(first_placed_frame-hold_start_frame)/float(Engine.physics_ticks_per_second)>=HOLD_LIMIT_LOWER(),"independent physics-frame clock never observes an early placement")
	check(equipment._card.heading.text=="Заряд установлен" and equipment._card.counter.text=="0,0 с","finished card explicitly displays installed and0,0s")
	check(equipment._remote_tool.visible and not equipment._charge_tool.visible,"held procedural tool visibly switches to remote")
	await capture("placed")
	await step(20)
	check(callbacks.is_empty() and equipment.snapshot().placed.size()==1,"continuing to hold installation LMB cannot auto-detonate")
	mouse(MOUSE_BUTTON_LEFT,false); holding_observation=false; await step(2)
	check(weapons.shots_count==shots_before and weapons.fire_state.weaponId=="none","native firearm remains unequipped throughout C4 hold")
	evidence.complete_3s={"first_placed_physics_frame":first_placed_frame,"start_physics_frame":hold_start_frame,"physics_ticks_per_second":Engine.physics_ticks_per_second,"snapshot":equipment.snapshot()}
	return true

func HOLD_LIMIT_LOWER() -> float:
	return 3.0-1.0/float(Engine.physics_ticks_per_second)

func sticky_and_remote() -> bool:
	var id: String=str(equipment.snapshot().placed[0].id)
	var row: Dictionary=equipment._charges[id]
	var charge: Node3D=row.node.get_ref()
	var frame: Transform3D=charge.global_transform
	var local: Transform3D=charge.transform
	check(charge.get_parent()==wall and wall.freeze,"charge is actually attached to the native stationary wall body")
	check(absf(charge.global_basis.z.dot(Vector3.UP))<.25,"charge sits on a real vertical surface")
	var max_delta:=0.0
	for i in 60:
		await step()
		if not is_instance_valid(charge): check(false,"planted charge survives stationary wall observation"); return false
		max_delta=maxf(max_delta,charge.global_position.distance_to(frame.origin))
	check(max_delta<.00001 and charge.transform==local,"sticky charge neither falls nor drifts for sixty physics frames")
	evidence.sticky={"wall":str(wall.get_path()),"charge":str(charge.get_path()),"world_frame":str(frame),"local_frame":str(local),"maximum_drift_m":max_delta,"native_wall_frozen":wall.freeze}
	# Leave the blast radius using normal player controls, not a setup teleport.
	var before: Vector3=player.global_position
	key(KEY_S,true)
	for i in 130:
		await step()
		if player.global_position.distance_to(frame.origin)>5.0: break
	key(KEY_S,false); await step(8)
	if not check(player.global_position.distance_to(frame.origin)>3.5,"native S movement retreats outside the C4 blast before remote input"): return false
	evidence.remote_retreat={"start":str(before),"finish":str(player.global_position),"charge":str(frame.origin),"teleport_during_hold_or_retreat":false}
	if not check(equipment.snapshot().placed.size()==1 and charge.transform==local,"walking away preserves the same attached item"): return false
	var dispatches: int=callbacks.size()
	mouse(MOUSE_BUTTON_LEFT,true); await step(); mouse(MOUSE_BUTTON_LEFT,false); await step(12)
	await capture("afterblast")
	check(callbacks.size()==dispatches+1,"one real remote LMB press dispatches exactly one placed charge")
	check(equipment.snapshot().placed.is_empty(),"successful consumption leaves no armed physical item")
	if not equipment_only and callbacks.size()==dispatches+1:
		# Capture live physical identities BEFORE the later independent J reset.
		evidence.actual_three_times=capture_blast(str(callbacks[dispatches].event_id),12,"single native C4")
		evidence.actual_three_times.rpg_default_direct_fragments=4
		evidence.actual_three_times.comparison="Actual C4 bodies versus the source RPG default of four; no synthetic RPG receipt."
	mouse(MOUSE_BUTTON_LEFT,true); await step(); mouse(MOUSE_BUTTON_LEFT,false); await step(3)
	check(callbacks.size()==dispatches+1,"a later remote press cannot replay the consumed item")
	return true

func blast_snapshot() -> Dictionary:
	var blast: Variant=game.get("preview_c4_blast")
	if not check(is_instance_valid(blast) and blast.has_method("snapshot"),"real main C4 blast owner exposes its observation snapshot"): return {}
	return blast.snapshot()

func capture_blast(event_id: String, expected_count: int, label: String) -> Dictionary:
	var snapshot:=blast_snapshot()
	var matches: Array[Dictionary]=[]
	for row: Dictionary in snapshot.get("events",[]):
		if str(row.get("event_id"))==event_id: matches.append(row)
	var proof: Dictionary={"event_id":event_id,"captured_physics_frame":Engine.get_physics_frames(),"captured_generation":site.rebuild_generation,"matching_events":matches.size(),"actual_bodies":[]}
	if not check(matches.size()==1,label+": exactly one committed native blast event"): return proof
	var event: Dictionary=matches[0]
	proof.event=event.duplicate(true)
	check(event.get("physical_charge_consumed")==true and event.get("weapon_id")=="c4",label+": committed event came from one consumed C4 item")
	var ids: Array=event.get("released",[])
	if expected_count>=0:
		check(ids.size()==expected_count,label+": actual direct release count equals "+str(expected_count))
	else:
		check(not ids.is_empty() and ids.size()<=12,label+": queued charge actually releases one to twelve bodies")
	var unique: Dictionary={}
	for raw_id: Variant in ids:
		var id: int=int(raw_id)
		check(not unique.has(id),label+": released physical identity occurs only once")
		unique[id]=true
		var body: Variant=instance_from_id(id)
		var valid: bool=is_instance_valid(body) and body is RigidBody3D
		var fact: Dictionary={"id":id,"actual_rigid_body":valid}
		if valid:
			fact.path=str(body.get_path()); fact.owned=site.owns_collider(body)
			fact.detached=body.get_meta("detached",false); fact.freeze=body.freeze
			fact.collision_layer=body.collision_layer; fact.position=str(body.global_position)
			check(fact.owned and fact.detached,label+": released ID resolves to an actual owned detached native body")
		else: check(false,label+": released ID remains a live native rigid body before reset")
		proof.actual_bodies.append(fact)
	proof.unique_body_count=unique.size()
	if expected_count==12:
		check(unique.size()==4*3 and event.get("strength_multiplier")==3 and event.get("direct_fragment_budget")==12,label+": actual unique bodies prove three times the default four-fragment RPG budget")
	return proof

func reacquire_wall() -> bool:
	wall=null
	for body: RigidBody3D in site.wall_panels:
		if is_instance_valid(body) and str(body.name).begins_with("Facade") and body.position.distance_to(Vector3(-3,1.57,3))<.05: wall=body
	return check(is_instance_valid(wall) and wall.freeze and not wall.get_meta("detached",false) and not wall.get_meta("fracture_active",false),"fresh authored wall is intact after real J rebuild")

func await_generation(previous: int, label: String) -> bool:
	for i in 300:
		await step()
		if site.rebuild_generation>previous and site.site_ready and not site.rebuilding: break
	if not check(site.rebuild_generation>previous and site.site_ready and not site.rebuilding,label+": actual J creates a ready fresh building generation"): return false
	await step(12)
	return reacquire_wall()

func reset_case(label: String) -> bool:
	var previous: int=site.rebuild_generation
	key(KEY_J,true); await step(); key(KEY_J,false)
	if not await await_generation(previous,label): return false
	if not evidence.has("native_resets"): evidence.native_resets=[]
	evidence.native_resets.append({"case":label,"before":previous,"after":site.rebuild_generation,"wall_id":wall.get_instance_id(),"route":"Input.parse_input_event(KEY_J); main owns reset"})
	# Independent-case cold pose, never a placement/retreat shortcut. The closer
	# 0.98 m actor-to-wall gap obeys the native short-reach equipment admission.
	player.global_position=site.to_global(Vector3(-3.78,.12,4.15)); player.velocity=Vector3.ZERO
	player._camera_yaw=site.global_rotation.y; player._camera_pitch=-.08; player._update_camera_rotation()
	await step(25)
	return check(player._free_mouse_look and player.is_on_floor(),label+": actual actor is on the same ground after cold setup")

func plant_native(label: String, local_point: Vector3) -> Dictionary:
	if not await q_choice(equipment._button,label+" Q placement choice"): return {}
	if not await aim_wall(local_point): return {}
	var before: Dictionary=equipment.snapshot()
	var old_ids: Array=[]
	for row: Dictionary in before.placed: old_ids.append(str(row.id))
	var dispatches: int=callbacks.size()
	var start: int=int(Engine.get_physics_frames())
	mouse(MOUSE_BUTTON_LEFT,true)
	await create_timer(3.15,false,true).timeout
	var real_held: bool=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	mouse(MOUSE_BUTTON_LEFT,false); await step(2)
	var after: Dictionary=equipment.snapshot()
	if not check(real_held and after.placed.size()==old_ids.size()+1 and after.mode=="remote",label+": real continuous three-second LMB creates exactly one physical item"): return {}
	check(callbacks.size()==dispatches,label+": installation never invokes the blast callback")
	var id: String=""
	for row: Dictionary in after.placed:
		if not old_ids.has(str(row.id)): id=str(row.id)
	if not check(not id.is_empty() and equipment._charges.has(id),label+": independent planted item identity exists"): return {}
	var charge: Node3D=equipment._charges[id].node.get_ref()
	if not check(is_instance_valid(charge) and charge.get_parent()==wall,label+": actual physical charge is attached to the selected wall"): return {}
	return {"placement_id":id,"wall_id":wall.get_instance_id(),"position":str(charge.global_position),"local_frame":str(charge.transform),"generation":site.rebuild_generation,"real_held":real_held,"physics_seconds":float(Engine.get_physics_frames()-start)/float(Engine.physics_ticks_per_second)}

func retreat_native(label: String) -> bool:
	var point: Vector3=wall.to_global(Vector3(-.78,0,.17))
	key(KEY_S,true)
	for i in 130:
		await step()
		if player.global_position.distance_to(point)>5.0: break
	key(KEY_S,false); await step(8)
	return check(player.global_position.distance_to(point)>3.5,label+": actual S movement safely retreats before the remote press")

func two_charges_one_wall() -> bool:
	if not await reset_case("two charges on one wall"): return false
	var first:=await plant_native("first adjacent charge",Vector3(-.78,0,.17))
	if first.is_empty(): return false
	var second:=await plant_native("second adjacent charge",Vector3(-.78,.32,.17))
	if second.is_empty(): return false
	check(first.wall_id==second.wall_id and first.placement_id!=second.placement_id and first.local_frame!=second.local_frame,"two distinct physical C4 items share the same unbroken wall at different points")
	if not await retreat_native("two charges"): return false
	var before: Dictionary=equipment.snapshot()
	var dispatches: int=callbacks.size()
	if not check(before.placed.size()==2,"both real charges survive until the same remote press"): return false
	mouse(MOUSE_BUTTON_LEFT,true)
	# Deliberately no await: both real capability callbacks must be consumed and
	# queued while their shared wall is still intact, before any physics blast.
	var immediate: Dictionary=blast_snapshot()
	var consumed: Dictionary=equipment.snapshot()
	check(callbacks.size()==dispatches+2 and consumed.placed.is_empty(),"one remote input synchronously consumes both real adjacent charges")
	check(immediate.get("pending")==2,"both consumed charges enter the real queue before the first geometry mutation")
	check(not wall.get_meta("fracture_active",false),"synchronous queue consumption has not fractured the shared parent yet")
	mouse(MOUSE_BUTTON_LEFT,false); await step(12)
	var proofs: Array[Dictionary]=[]
	var unique: Dictionary={}
	for callback_index in range(dispatches,callbacks.size()):
		var proof:=capture_blast(str(callbacks[callback_index].event_id),-1,"adjacent native charge "+str(callback_index-dispatches+1))
		for fact: Dictionary in proof.actual_bodies:
			check(not unique.has(fact.id),"two queued C4 events never claim the same physical release twice")
			unique[fact.id]=true
		proofs.append(proof)
	var after: Dictionary=equipment.snapshot()
	check(after.totals.detonated==before.totals.detonated+2 and after.totals.disarmed==before.totals.disarmed,"first wall blast cannot disarm the already-consumed second charge")
	check(blast_snapshot().get("pending")==0,"both native queued blasts finish")
	evidence.two_charges_same_wall={"first":first,"second":second,"before_remote":before,"immediately_consumed":consumed,"pending_before_physics":immediate.get("pending"),"after_physics":after,"actual_blasts_before_later_reset":proofs,"unique_released_bodies":unique.size()}
	return true

func queued_reset_case() -> bool:
	if not await reset_case("pending blast reset isolation"): return false
	var charge:=await plant_native("charge before pending reset",Vector3(-.78,0,.17))
	if charge.is_empty(): return false
	if not await retreat_native("pending reset"): return false
	var previous: int=site.rebuild_generation
	var old_wall: int=wall.get_instance_id()
	var dispatches: int=callbacks.size()
	var input_frame: int=int(Engine.get_physics_frames())
	mouse(MOUSE_BUTTON_LEFT,true)
	var pending: Dictionary=blast_snapshot()
	# Same native input batch: no timer, process/physics await, direct site call,
	# synthetic capability or mutation of the pending queue appears between them.
	key(KEY_J,true); mouse(MOUSE_BUTTON_LEFT,false); key(KEY_J,false)
	var immediate_generation: int=site.rebuild_generation
	check(int(Engine.get_physics_frames())==input_frame,"remote and real J enter in exactly the same physics-frame input batch")
	check(callbacks.size()==dispatches+1 and pending.get("pending")==1,"one real physical charge was consumed and queued before J")
	check(immediate_generation>previous,"native J invalidates the queued building generation before its physics dispatch")
	if not await await_generation(previous,"pending blast reset isolation"): return false
	if callbacks.size()!=dispatches+1: return false
	var proof:=capture_blast(str(callbacks[dispatches].event_id),0,"old queued charge after native J")
	check(proof.get("event",{}).get("affected_houses",[]).is_empty(),"stale queued C4 never affects any house in the fresh generation")
	check(blast_snapshot().get("pending")==0 and equipment.snapshot().placed.is_empty(),"stale queue resolves without leaving a reusable charge")
	check(wall.get_instance_id()!=old_wall and wall.freeze and not wall.get_meta("fracture_active",false) and not wall.get_meta("detached",false),"rebuilt physical wall has a new identity and remains intact after stale C4 dispatch")
	evidence.pending_reset={"physical_charge":charge,"before_generation":previous,"immediate_generation":immediate_generation,"ready_generation":site.rebuild_generation,"remote_and_J_physics_frame":input_frame,"pending_before_J":pending.get("pending"),"old_wall_id":old_wall,"fresh_wall_id":wall.get_instance_id(),"actual_stale_event":proof}
	return true

func regular_weapon_after() -> void:
	if not await q_choice(weapons._walk_ui.choices[pistol].button,"regular pistol after C4"): return
	check(equipment.snapshot().mode=="off" and weapons.fire_state.weaponId==pistol,"native pistol selection exits C4 mode")
	check(not equipment._held_root.visible and not equipment._card.visible,"C4 hand prop and progress UI disappear after normal selection")
	check(weapons.inventory.get_owned_ids()==original_owned and weapons.inventory.get_item_uid(pistol)==original_uid,"original weapon inventory and item identity are unchanged")
	check(player.get_meta("actor_id")==original_actor and player.get_meta("life_generation")==original_life,"same native actor life owns the complete scenario")
	# A cold aim setup points the NORMAL weapon safely into sky; actual trigger,
	# pose/muzzle admission and shot launch are still the unchanged native path.
	player._camera_pitch=.45; player._update_camera_rotation(); await step(12)
	var shots: int=weapons.shots_count; var magazine: int=int(weapons.fire_state.magazine)
	mouse(MOUSE_BUTTON_LEFT,true); await step(2); mouse(MOUSE_BUTTON_LEFT,false); await step(8)
	check(weapons.shots_count==shots+1 and int(weapons.fire_state.magazine)==magazine-1,"normal native pistol still commits one real shot and one round")
	evidence.normal_weapon={"weapon":pistol,"shots_before":shots,"shots_after":weapons.shots_count,"magazine_before":magazine,"magazine_after":weapons.fire_state.magazine,"inventory_ids":weapons.inventory.get_owned_ids()}

func run() -> void:
	started_usec=Time.get_ticks_usec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		if arg=="--c4-equipment-only": equipment_only=true
		if arg=="--palazzo-headless": screenshots=false
	if DisplayServer.get_name()=="headless": screenshots=false
	create_timer(100.0).timeout.connect(func():
		if not finished: check(false,"100-second focused native watchdog"); finish())
	var packed: PackedScene=load("res://scenes/main.tscn") as PackedScene
	if not check(packed!=null,"actual main scene exists"): finish(); return
	game=packed.instantiate(); root.add_child(game); current_scene=game
	for i in 900:
		await step()
		if game.get("preview_ready")==true: break
	if not check(game.get("preview_ready")==true,"actual loaded game reached native ready"): finish(); return
	player=game._player; weapons=game.preview_weapons; camera=player.get_preview_camera()
	original_actor=player.get_meta("actor_id"); original_life=player.get_meta("life_generation")
	var host: Variant=game.get("preview_palazzo")
	if not check(is_instance_valid(host) and is_instance_valid(host.get("site")),"real placed Palazzo owner exists"): finish(); return
	site=host.site
	for body: RigidBody3D in site.wall_panels:
		if str(body.name).begins_with("Facade") and body.position.distance_to(Vector3(-3,1.57,3))<.05: wall=body
	if not check(is_instance_valid(wall),"actual authored lower wall selected"): finish(); return
	# Explicit independent-scenario setup only. Main player/camera/physics remain.
	player.global_position=site.to_global(Vector3(-3.78,.12,4.15)); player.velocity=Vector3.ZERO
	player._camera_yaw=site.global_rotation.y; player._camera_pitch=-.08; player._update_camera_rotation()
	await step(25)
	if not player._free_mouse_look:
		mouse(MOUSE_BUTTON_LEFT,true); await step(); mouse(MOUSE_BUTTON_LEFT,false); await step(3)
	if not check(player._free_mouse_look and player.is_on_floor(),"real click capture and native floor contact active"): finish(); return
	equipment=game.get_node_or_null("LocalC4Equipment")
	if equipment_only:
		if is_instance_valid(equipment): check(false,"equipment-only flag requires no integrated C4 owner"); finish(); return
		equipment=Equipment.new()
		if not check(equipment.configure(game,Callable(self,"callback")).get("ok",false),"C4 configures against the real loaded arsenal"): finish(); return
	else:
		if not check(is_instance_valid(equipment) and equipment.has_method("snapshot") and equipment.snapshot().ready,"main already configured its actual C4 owner"): finish(); return
		original_callback=equipment.get("_explosion")
		if not check(original_callback.is_valid(),"integrated root explosion callback is bound"): finish(); return
		equipment.set("_explosion",Callable(self,"callback")) # Observation wrapper preserves real root.
	original_owned=weapons.inventory.get_owned_ids().duplicate()
	if not check(original_owned.has(pistol),"real native pistol inventory available"): finish(); return
	original_uid=weapons.inventory.get_item_uid(pistol)
	if not await q_choice(weapons._walk_ui.choices[pistol].button,"native pistol before C4"): finish(); return
	check(weapons.fire_state.weaponId==pistol,"ordinary real Q equip works before C4")
	var ammunition: int=int(weapons.fire_state.magazine)
	if not await q_choice(equipment._button,"C4 placement card"): finish(); return
	check(equipment.snapshot().mode=="place" and weapons.fire_state.weaponId=="none","Q C4 selection uses native unequip and placement mode")
	check(not is_instance_valid(weapons.presentation._visual),"native weapon model was removed before C4 tool")
	if not await aim_wall(): finish(); return
	if not await hold_cases(): finish(); return
	check(int(weapons.inventory.get_fire_state(pistol).magazine)==ammunition,"C4 did not spend a pistol round")
	if not await sticky_and_remote(): finish(); return
	if not equipment_only:
		if not await two_charges_one_wall(): finish(); return
		if not await queued_reset_case(): finish(); return
	else:
		evidence.root_geometry_cases={"skipped":true,"reason":"Explicit equipment-only run cannot assert root geometry, multi-charge queue or generation isolation."}
	await regular_weapon_after()
	evidence.final_equipment=equipment.snapshot()
	evidence.root_callback_wrapped=not equipment_only
	finish()

func finish() -> void:
	if finished: return
	finished=true; tracking=false; holding_observation=false
	key(KEY_Q,false); key(KEY_S,false); key(KEY_J,false); mouse(MOUSE_BUTTON_LEFT,false); mouse(MOUSE_BUTTON_RIGHT,false)
	if is_instance_valid(equipment) and original_callback.is_valid(): equipment.set("_explosion",original_callback)
	var report: Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"evidence":evidence,"actual_c4_callbacks":callbacks,"elapsed_usec":Time.get_ticks_usec()-started_usec,"native_scene":"res://scenes/main.tscn","input_routes":{"keys_and_gameplay_LMB":"Input.parse_input_event; real global held state","mouse_motion_and_Q_GUI_clicks":"Viewport.push_input(event,true); already-local content coordinates"},"synthetic_positive_damage_receipt":false,"equipment_only":equipment_only,"root_blast_callback_exercised":not equipment_only and not callbacks.is_empty(),"screenshots_requested":screenshots,"display_server":DisplayServer.get_name(),"loaded_scene_performance_accepted":false,"manual_OS_input_verified":false,"source_only_author_did_not_launch_engine":true}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t")); file.close()
	else: print("C4 report write failed: ",output)
	print("C4_NATIVE ",report.status," checks=",checks," failures=",failures.size()," report=",output)
	quit(0 if failures.is_empty() else 2)
