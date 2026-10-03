extends "combat_base.gd"
## Actual normal main/player/rig. Only the explicitly named no-force control
## replaces sampler command delivery with a rejecting callback. Native receipts,
## body filters, geometry, transforms, velocities and ordinary ticks stay real.
class Watch extends Node:
	var observe: Callable
	func _physics_process(delta: float) -> void:
		if observe.is_valid(): observe.call(delta)

var force_enabled := false
var phase := "startup"
var watch: Watch
var selected_part: RigidBody3D
var driving := false
var control_start := {}
var control_positions := {}
var control_commands: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var contact_frames := 0
var blocked_frames := 0
var pressure_receipt_frames := 0
var max_part_shift := 0.0
var max_part_speed := 0.0
var max_part_angular := 0.0
var max_native_depth := 0.0
var first_contact_frame := -1
var held_frames := 0
var released_attempts := -1
var port: RefCounted
var initial_shapes := {}
var settle_samples: Array[Dictionary] = []
var ambient := {"ticks": 180, "max_shift_m": 0.0, "max_linear_mps": 0.0, "max_angular_rps": 0.0}
var mark_before := {}
var mark_after := {}
var accepted_events := {}

func marks_state() -> Dictionary:
	var renderer:RefCounted=owner.marks.renderer
	return {"actor_id":renderer._root.get_instance_id(),"rig_id":renderer._rig.get_instance_id(),"node_id":renderer._mesh_node.get_instance_id(),"mesh_id":renderer._mesh.get_instance_id(),"marks":renderer._marks.duplicate(true),"anchors":renderer._anchors.duplicate(true),"positions":renderer._positions(),"pose_key":renderer._pose_key.duplicate(true),"visible":renderer._mesh_node.visible,"vertices":renderer._anchors.size()}

func owns(collider: Variant) -> bool:
	if collider == owner._token.body:return true
	return collider is RigidBody3D and physical()!=null and collider in physical().owned_bodies()

func place_player() -> bool:
	# Bounded read-only placement search, followed by exactly one player setup
	# placement. All world/car/NPC blockers remain enabled and reported.
	var attempts: Array[Dictionary] = []
	var offsets := [Vector3(0,0,6),Vector3(6,0,0),Vector3(-6,0,0),Vector3(0,0,-6),Vector3(4.25,0,4.25),Vector3(-4.25,0,4.25),Vector3(4.25,0,-4.25),Vector3(-4.25,0,-4.25)]
	var shape: CollisionShape3D = player.get_node("PlayerCapsule")
	for offset: Vector3 in offsets:
		var at: Vector3 = owner._token.body.global_position+offset
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*4,at-Vector3.UP*4,1,[player.get_rid()]))
		if hit.is_empty() or hit.normal.y<.9:attempts.append({"offset":offset,"reason":"no_floor"});continue
		var start: Vector3 = hit.position+Vector3.UP*.03
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=shape.shape;query.transform=Transform3D(player.global_basis,start)*shape.transform;query.collision_mask=1025;query.exclude=[player.get_rid()];query.margin=0
		var overlaps: Array[Dictionary] = player.get_world_3d().direct_space_state.intersect_shape(query,8)
		if not overlaps.is_empty():attempts.append({"offset":offset,"reason":"native_capsule_blocked","colliders":overlaps});continue
		placement={"before":player.global_position,"after":start,"floor":str(hit.collider),"attempts":attempts,"one_explicit_setup_placement":true,"capsule_shape_id":shape.shape.get_instance_id(),"world_rid":str(player.get_world_3d().space),"mask":query.collision_mask}
		player.global_position=start
		return true
	placement={"attempts":attempts,"one_explicit_setup_placement":false}
	return check(false,"bounded actual clear-floor player fixture unavailable")

func _process(delta: float) -> bool:
	if tracking: return super._process(delta)
	if driving and is_instance_valid(selected_part):
		var difference: Vector3 = selected_part.global_position - player.global_position
		var wanted := atan2(-difference.x,-difference.z)
		var event := InputEventMouseMotion.new()
		event.relative=Vector2(-wrapf(wanted-player._camera_yaw,-PI,PI)/player.mouse_sensitivity,0)
		player._unhandled_input(event)
	return false

func deny_force_control(request: Dictionary) -> Dictionary:
	if control_commands.size()<128:
		var move: Dictionary=player.completed_ground_pressure_receipt()
		var native: Dictionary=player.completed_ground_slide_contact(request.slide_index,request.contact_index)
		check(not move.is_empty() and not native.is_empty(),"control received actual same-frame native getters")
		check(request.movement_serial==move.serial and request.collider_rid==native.collider_rid and request.world_point==native.point,"control exact command/native identity")
		control_commands.append({"request":request.duplicate(true),"move":move.duplicate(true),"native":native.duplicate(true)})
	return {"ok":false,"reason":"TEST_ONLY_EXPLICIT_FORCE_DISABLED","applied_impulse_ns":Vector3.ZERO}

func observe_pressure(_delta: float) -> void:
	if done or phase not in ["pressure","released"]:return
	var result:Dictionary=player._corpse_contact_sampler.last_result
	if force_enabled and result.get("ok",false) and not accepted_events.has(result.event_id):
		accepted_events[result.event_id]=result.duplicate(true)
		check(result.applied_impulse_ns.length()<=3.00001 and result.predicted.delta_energy_j<=1.5 and result.predicted.linear_speed<=2.5 and result.predicted.angular_speed<=15.0,"actual accepted owner impulse preserves configured caps")
	var move: Dictionary=player.completed_ground_pressure_receipt()
	if not move.is_empty():pressure_receipt_frames+=1
	var touched:=false
	for i in player.get_slide_collision_count():
		var hit:=player.get_slide_collision(i)
		for j in hit.get_collision_count():
			if owns(hit.get_collider(j)):
				touched=true;max_native_depth=maxf(max_native_depth,hit.get_depth())
				if first_contact_frame<0:first_contact_frame=Engine.get_physics_frames()
	if touched:
		contact_frames+=1
		if phase=="pressure" and not move.is_empty() and Vector2(move.end.x-move.start.x,move.end.z-move.start.z).length()<.001 and Vector2(move.pre_velocity.x,move.pre_velocity.z).length()>.2:blocked_frames+=1
	if phase=="pressure":held_frames+=1
	for body: RigidBody3D in physical().owned_bodies():
		max_part_shift=maxf(max_part_shift,body.global_position.distance_to(control_positions[str(body.name)]))
		max_part_speed=maxf(max_part_speed,body.linear_velocity.length())
		max_part_angular=maxf(max_part_angular,body.angular_velocity.length())
	if samples.size()<240 and (held_frames%5==0 or (touched and samples.size()<40)):
		samples.append({"frame":Engine.get_physics_frames(),"phase":phase,"position":player.global_position,"move":move,"native_delta":player.get_position_delta(),"touched":touched,"port_stats":port.stats.duplicate(true),"sampler_attempts":player._corpse_contact_sampler.attempts,"last_result":player._corpse_contact_sampler.last_result.duplicate(true)})

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
	if out.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(95).timeout.connect(func():
		if not done:check(false,"bounded pressure deadline");finish())
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	await sync(8)
	if not check(game.preview_ready and game.preview_population.hit_owners.size()==3 and game.final_dead_contact_status=="v2_bound_waiting_final_death","ordinary three-resident v2 startup"):finish();return
	player=game._player;weapons=game.preview_weapons;port=game.preview_population._final_dead_contact_port
	for item:RefCounted in game.preview_population.hit_owners:
		initial_actors[item._token.source_id]={"body":item._token.body.get_instance_id(),"rig":item._token.rig.get_instance_id(),"row":item.snapshot().row}
		if item._token.source_id=="resident_72":owner=item
	if not check(owner!=null,"original72 target"):finish();return
	for body:RigidBody3D in physical().owned_bodies():
		var shape:CollisionShape3D=body.get_child(0)
		initial_shapes[str(body.name)]={"rid":body.get_rid(),"instance":body.get_instance_id(),"node":shape.get_instance_id(),"shape":shape.shape.get_instance_id(),"shape_rid":shape.shape.get_rid(),"mass":body.mass,"radius":shape.shape.radius,"height":shape.shape.height}
	if not place_player():finish();return # One declared clear-floor player fixture; never moves a corpse.
	button(MOUSE_BUTTON_LEFT,true);button(MOUSE_BUTTON_LEFT,false)
	if not check(weapons.equip("tt_pistol").get("ok",false),"native finite TT equip"):finish();return
	weapons.shot_emitted.connect(func(shot:Dictionary,muzzle:Dictionary,_origin:Vector3,_direction:Vector3):
		check(muzzle.get("ok",false) and muzzle.pose_revision==player._pose_revision,"fresh actual muzzle")
		shots.append({"shot_id":shot.shotId,"ammo":weapons.fire_state.magazine,"frame":Engine.get_physics_frames()}))
	weapons.effects.cosmetic_impact.connect(func(hit:Dictionary):contacts.append({"shot_id":hit.shotId,"point":hit.point,"owned":owns(hit.collider)}))
	tracking=true;button(MOUSE_BUTTON_RIGHT,true);await sync(60)
	for i in 20:
		if owner.snapshot().row.get("dead",false):break
		if not await fire_once("actual_lethal_"+str(i)):finish();return
	if not check(owner.snapshot().row.get("dead",false) and physical().status().get("final_dead",false),"actual weapon-confirmed final death"):finish();return
	button(MOUSE_BUTTON_RIGHT,false);tracking=false
	dead_row=owner.snapshot().row.duplicate(true);dead_revision=int(owner.last_result.get("revision",-1));dead_impulse=owner.last_impulse.duplicate(true)
	var state:Dictionary=physical().status()
	check(state.blocking_enabled and state.blocking_error=="" and state.blocking_death_key==state.death_key,"confirmed death installs exact blocking death key")
	check(player.collision_layer==2 and player.collision_mask==1025 and player.platform_floor_layers==1 and player.platform_wall_layers==0,"player filter/support policy retained")
	for body:RigidBody3D in physical().owned_bodies():
		var shape:CollisionShape3D=body.get_child(0);var before:Dictionary=initial_shapes[str(body.name)]
		check(body.get_rid()==before.rid and body.get_instance_id()==before.instance and shape.get_instance_id()==before.node and shape.shape.get_instance_id()==before.shape and shape.shape.get_rid()==before.shape_rid and body.mass==before.mass and shape.shape.radius==before.radius and shape.shape.height==before.height,"death preserves original native part/shape:"+body.name)
		check(body.collision_layer==1280 and body.collision_mask==257 and not body.freeze,"only active final parts block:"+body.name)
	check(physical()._body._joints.size()==15,"fifteen original joints retained")
	var sleeping:=false
	var stable_ticks:=0
	for i in 1200:
		sleeping=true
		var linear:=0.0
		var angular:=0.0
		var awake: Array[String] = []
		for body:RigidBody3D in physical().owned_bodies():
			linear=maxf(linear,body.linear_velocity.length());angular=maxf(angular,body.angular_velocity.length())
			if not body.sleeping:sleeping=false;awake.append(str(body.name))
		stable_ticks=stable_ticks+1 if linear<=.002 and angular<=.02 else 0
		if i%60==0:settle_samples.append({"tick":i,"linear_mps":linear,"angular_rps":angular,"awake":awake,"stable_ticks":stable_ticks})
		if sleeping or stable_ticks>=120:break
		await sync()
	# Natural rig micro-motion is measured, never suppressed or called sleeping.
	# All-sleep was a QA preparation assumption, not an owner requirement.
	var ambient_positions := {}
	for body:RigidBody3D in physical().owned_bodies():ambient_positions[str(body.name)]=body.global_position
	for i in 180:
		await sync()
		for body:RigidBody3D in physical().owned_bodies():
			ambient.max_shift_m=maxf(ambient.max_shift_m,body.global_position.distance_to(ambient_positions[str(body.name)]))
			ambient.max_linear_mps=maxf(ambient.max_linear_mps,body.linear_velocity.length())
			ambient.max_angular_rps=maxf(ambient.max_angular_rps,body.angular_velocity.length())
	var nearest:=INF
	for body:RigidBody3D in physical().owned_bodies():
		control_positions[str(body.name)]=body.global_position
		var d:=Vector2(body.global_position.x-player.global_position.x,body.global_position.z-player.global_position.z).length()
		if d<nearest:nearest=d;selected_part=body
	control_start={"player":player.global_position,"positions":control_positions.duplicate(true),"selected_part":str(selected_part.name),"distance":nearest,"port_stats":port.stats.duplicate(true),"all_sleeping":sleeping,"quiescent_ticks":stable_ticks,"world_rid":str(player.get_world_3d().space)}
	mark_before=marks_state()
	if not force_enabled:player._corpse_contact_sampler._admit_hook=Callable(self,"deny_force_control")
	watch=Watch.new();watch.process_physics_priority=100;watch.observe=Callable(self,"observe_pressure");game.add_child(watch)
	phase="pressure";driving=true;Input.action_press(player.ACTION_FORWARD)
	for i in 720:
		await sync()
		if first_contact_frame>=0 and Engine.get_physics_frames()-first_contact_frame>=180:break
	Input.action_release(player.ACTION_FORWARD);driving=false;phase="released"
	released_attempts=player._corpse_contact_sampler.attempts
	await sync(120)
	check(contact_frames>0,"actual native slide contact with original dead part")
	check(blocked_frames>0,"actual inward pressure blocks ordinary player travel")
	check(max_native_depth<=.08,"native penetration bounded80mm")
	check(player._corpse_contact_sampler.attempts==released_attempts,"release stops all new pressure commands")
	if force_enabled:
		check(port.stats.accepted>0,"real owner admitted positive pressure")
		check(max_part_shift>.0001 and max_part_shift<.5,"original corpse shifts slightly without runaway")
	else:
		check(control_commands.size()>0,"real candidate command reached explicit no-force control")
		check(port.stats.accepted==0 and port.stats.attempted==0,"no-force control sends no owner impulse")
		# This checks bounded natural movement, not an unobservable zero solver
		# impulse. Preserve exact baseline and contact values for independent review.
		check(max_part_shift<=maxf(.02,ambient.max_shift_m) and max_part_speed<=maxf(.15,ambient.max_linear_mps*2.0) and max_part_angular<=maxf(1.0,ambient.max_angular_rps*2.0),"no-force contact bounded by measured ambient displacement and doubled speed envelope")
	check(owner.snapshot().row==dead_row and int(owner.last_result.get("revision",-1))==dead_revision and owner.last_impulse==dead_impulse,"pressure changes no HP/death/bullet authority")
	mark_after=marks_state()
	check(mark_before.vertices>0 and mark_after.visible and mark_after.actor_id==mark_before.actor_id and mark_after.rig_id==mark_before.rig_id and mark_after.node_id==mark_before.node_id and mark_after.mesh_id==mark_before.mesh_id,"original nonempty mark mesh remains bound to original actor and rig")
	check(mark_after.marks==mark_before.marks and mark_after.anchors==mark_before.anchors,"pressure preserves accepted mark and clothing anchor topology")
	check(mark_after.pose_key!=mark_before.pose_key and mark_after.positions!=mark_before.positions,"ordinary renderer follows changed original rig pose without manual step")
	for item:RefCounted in game.preview_population.hit_owners:
		check(item._token.body.get_instance_id()==initial_actors[item._token.source_id].body and item._token.rig.get_instance_id()==initial_actors[item._token.source_id].rig,"original resident identity:"+item._token.source_id)
	finish()

func finish() -> void:
	if done:return
	done=true;tracking=false;driving=false
	if is_instance_valid(player):Input.action_release(player.ACTION_FORWARD);button(MOUSE_BUTTON_LEFT,false);button(MOUSE_BUTTON_RIGHT,false)
	var report:Dictionary={"valid":errors.is_empty(),"checks":checks,"errors":errors,"force_enabled":force_enabled,"phase":phase,"scope":"ordinary real physics at60Hz; actual finite weapon death, one explicit clear-floor player placement, no corpse/rig transforms or manual stepping; synthetic input, not OS or FPS acceptance","placement":placement,"shots":shots,"contacts":contacts,"stages":stages,"initial_shapes":initial_shapes,"control_start":control_start,"control_commands":control_commands,"samples":samples,"contact_frames":contact_frames,"blocked_frames":blocked_frames,"pressure_receipt_frames":pressure_receipt_frames,"max_part_shift_m":max_part_shift,"max_part_speed_mps":max_part_speed,"max_part_angular_rps":max_part_angular,"max_native_depth_m":max_native_depth,"held_frames":held_frames,"port_stats":port.stats.duplicate(true) if port!=null else {},"sampler_result":player._corpse_contact_sampler.last_result if is_instance_valid(player) and player._corpse_contact_sampler!=null else {}}
	report["ambient_without_contact"]=ambient
	report["accepted_events"]=accepted_events
	report["mark_before"]=mark_before
	report["mark_after"]=mark_after
	report["control_limit"]= "Awake original rig: bounded native contact movement, not proof of exactly zero implicit solver force. Baseline180ticks; pressure/contact and release separately retained. No sleeping, velocity or transform mutation."
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open(out.path_join("SETTLE.json"),FileAccess.WRITE).store_string(JSON.stringify(settle_samples,"  "))
	# Exercise real SceneTree quit/exit order, including an unfinished visit.
	quit(0 if errors.is_empty() else 1)
