extends Node
## Diagnostic replay capsule only. The ten real lives and geometry are untouched.
const Drive=preload("res://scripts/hospital/npc_simple_hospital.gd")
const Avoidance=preload("res://scripts/navigation/npc_avoidance_world29.gd")
const Core=preload("res://scripts/navigation/npc_local_avoidance29.gd")
const Physical=preload("res://scripts/hospital/npc_physical_route51.gd")
const START=Vector3(135.305358886719,.300851732492447,-2.2660436630249)
const GOAL=Vector3(136.218566894531,.303000032901764,2.69682502746582)
var out:=""
var born:=0
var ready_frame:=-1
var started_frame:=-1
var started_us:=0
var finished:=false
var actor:CharacterBody3D
var drive:RefCounted
var probe:RefCounted
var diagnostic_avoidance:RefCounted
var fixture_input:Core.FrameInput
var scene:Node3D
var life:RefCounted
var rows:Array=[]
var geometry:Array=[]
var contract:Dictionary={}
var paths:Array=[]
var prior_ready:=-2
var result:=""
func v(p:Vector3)->Array:return [p.x,p.y,p.z]
func vv(p:Variant)->Variant:return v(p) if p is Vector3 else null
func _ready()->void:
	born=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	scene=get_tree().current_scene
func shape_info(shape:CollisionShape3D)->Dictionary:
	var box:AABB=shape.global_transform*shape.shape.get_debug_mesh().get_aabb()
	var axes:Basis=shape.global_basis
	return {"path":str(shape.get_path()),"type":shape.shape.get_class(),"disabled":shape.disabled,
		"position":v(shape.global_position),"basis":[v(axes.x),v(axes.y),v(axes.z)],"aabb_position":v(box.position),"aabb_size":v(box.size),
		"shape_description":str(shape.shape)}
func _setup()->bool:
	var pop:Variant=scene.get("preview_population")
	if pop==null or pop.get("city_ready")!=true:return false
	if not pop.city_stream_complete():return false
	life=pop.daily._lives.get("resident_7")
	if life==null:return false
	var original:CharacterBody3D=life._token.body
	actor=CharacterBody3D.new();actor.name="QA_Roam7Replay"
	var properties:Array[String]=["collision_layer","collision_mask","motion_mode","up_direction","safe_margin","floor_snap_length","floor_max_angle","floor_stop_on_slope","floor_block_on_wall","floor_constant_speed","slide_on_ceiling","max_slides","wall_min_slide_angle","platform_floor_layers","platform_wall_layers","platform_on_leave"]
	for key:String in properties:
		actor.set(key,original.get(key));contract[key]=str(original.get(key))
	for child:Node in original.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D and not child.disabled:
			var shape:=CollisionShape3D.new();shape.shape=child.shape.duplicate(true);shape.transform=child.transform;actor.add_child(shape)
			contract.capsule={"radius":child.shape.radius,"height":child.shape.height,"local_position":v(child.position)}
	scene.add_child(actor);actor.global_position=START;actor.global_basis=original.global_basis
	contract.source_body_path=str(original.get_path());contract.source_generation=life._token.life_generation
	contract.original_body_not_relocated=true;contract.fixture_initial_placement_only=true
	var clone:Node=scene.get_node_or_null("TownClone_4")
	if clone==null:_finish("clone_missing");return false
	var stack:Array[Node]=[clone]
	while not stack.is_empty():
		var node:Node=stack.pop_back()
		if node is CollisionObject3D and node.global_position.distance_to(GOAL)<10.0:
			var shapes:Array=[]
			for child:Node in node.get_children():
				if child is CollisionShape3D:shapes.append(shape_info(child))
			geometry.append({"path":str(node.get_path()),"position":v(node.global_position),"layer":node.collision_layer,"mask":node.collision_mask,"shapes":shapes})
		for child:Node in node.get_children():stack.append(child)
	probe=Physical.new()
	if not probe.configure(actor):_finish("probe_configure_failed");return false
	ready_frame=Engine.get_physics_frames()
	print("ROAM58_REPLAY_READY ",JSON.stringify(contract))
	return true
func prepare_avoidance()->void:
	diagnostic_avoidance.refresh(scene)
	var inputs:Array[Core.FrameInput]=[]
	for entry:Variant in diagnostic_avoidance._entries.values():
		if entry.seen==Engine.get_physics_frames():inputs.append(entry.input)
	fixture_input.position=actor.global_position;fixture_input.velocity=actor.velocity
	fixture_input.radius=probe.shape.shape.radius;fixture_input.height=probe.shape.shape.height
	fixture_input.priority=0;fixture_input.waiting=false
	fixture_input.passage31=probe._passage31.body_zone(actor)
	inputs.append(fixture_input)
	diagnostic_avoidance._keys[actor.get_instance_id()]=fixture_input.key
	diagnostic_avoidance._valid=diagnostic_avoidance.core.snapshot(inputs,Engine.get_physics_frames(),Time.get_ticks_msec())
func collisions()->Array:
	var hits:Array=[]
	for i:int in actor.get_slide_collision_count():
		var hit:KinematicCollision3D=actor.get_slide_collision(i)
		var collider:Variant=hit.get_collider()
		hits.append({"path":str(collider.get_path()) if collider is Node else str(collider),"normal":v(hit.get_normal()),"point":v(hit.get_position()),"travel":v(hit.get_travel()),"remainder":v(hit.get_remainder()),"depth":hit.get_depth()})
	return hits
func overlap(at:Vector3)->Array:
	var hits:Array=[]
	for hit:Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(probe._query(at),8):
		var collider:Variant=hit.collider
		hits.append(str(collider.get_path()) if collider is Node else str(collider))
	return hits
func _physics_process(delta:float)->void:
	if finished:return
	if ready_frame<0:
		if Time.get_ticks_msec()-born>110000:_finish("startup_timeout");return
		_setup();return
	if started_frame<0:
		probe.hold(delta)
		if Engine.get_physics_frames()-ready_frame<3:return
		drive=Drive.new()
		if not drive.begin(GOAL,actor,life._dsh_simple_map(),"qa_roam7_replay58","roam"):_finish("begin_failed");return
		diagnostic_avoidance=Avoidance.new();fixture_input=Core.FrameInput.new()
		fixture_input.key="qa_roam7_replay58:life:1:body:"+str(actor.get_instance_id())
		drive._avoidance29=diagnostic_avoidance
		contract.avoidance_snapshot="Separate native Core snapshot with the actual10 plus this diagnostic capsule; global service and original records unchanged."
		started_frame=Engine.get_physics_frames();started_us=Time.get_ticks_usec()
		contract.start_after_native_settle=v(actor.global_position)
		return
	prepare_avoidance()
	var before:Vector3=actor.global_position
	var pre_hits:Array=collisions()
	var way_before:int=drive._way
	var waypoint:Vector3=drive._route.route[way_before] if way_before<drive._route.route.size() else GOAL
	var direction:Vector3=waypoint-before;direction.y=0;direction=direction.normalized()
	var floor_here:Variant=probe.floor_at(before,before.y)
	var floor_ahead:Variant=probe.floor_at(before+direction*.4,before.y)
	var edge_query:bool=probe.edge_clear(before,waypoint)
	var standing_actual:bool=probe.standing(before)
	var sweep_actual:bool=probe.sweep(before,waypoint)
	var native_test_hit:=KinematicCollision3D.new()
	var native_test_blocked:bool=actor.test_move(actor.global_transform,direction*.03,native_test_hit)
	var test_path:=""
	if native_test_blocked:
		var hit:Variant=native_test_hit.get_collider();test_path=str(hit.get_path()) if hit is Node else str(hit)
	result=drive.step(delta)
	var after:Vector3=actor.global_position
	var native:Dictionary=drive._route.diagnostics()
	if drive._route._ready_frame!=prior_ready:
		prior_ready=drive._route._ready_frame
		var route_points:Array=[]
		for point:Vector3 in drive._route.route:route_points.append(v(point))
		paths.append({"frame":Engine.get_physics_frames(),"ready_frame":prior_ready,"points":route_points})
	rows.append({"frame":Engine.get_physics_frames(),"elapsed_s":float(Time.get_ticks_usec()-started_us)/1000000.0,"delta":delta,
		"before":v(before),"after":v(after),"velocity":v(actor.velocity),"on_floor":actor.is_on_floor(),"floor_normal":v(actor.get_floor_normal()),
		"way":way_before,"way_after":drive._way,"waypoint":v(waypoint),"remaining_before":Vector2(before.x-waypoint.x,before.z-waypoint.z).length(),
		"remaining_after":Vector2(after.x-waypoint.x,after.z-waypoint.z).length(),"result":result,"drive_phase":drive._phase,"attempts":drive._attempts,
		"stall_s":drive._stall_s,"roam_step_phase":drive._roam_step29_phase,"roam_watch":drive._roam_watch29_state.duplicate(true),
		"direction_before_steer":v(direction),"direction_after_steer":vv(drive._avoidance29_state.get("direction")),
		"standing_actual":standing_actual,"sweep_actual_to_wp":sweep_actual,"native_test_blocked":native_test_blocked,"native_test_collider":test_path,
		"native_test_normal":v(native_test_hit.get_normal()) if native_test_blocked else [],"floor_here":vv(floor_here),"floor_ahead":vv(floor_ahead),"edge_query":edge_query,"waypoint_overlaps":overlap(waypoint),
		"native_diagnostics":native,"slide_before":pre_hits,"slide_after":collisions(),
		"door_clearance":drive._door_clear31.snapshot() if drive._door_clear31!=null else {},"avoidance":str(drive._avoidance29_state)})
	if rows.size()%600==0:print("ROAM58_REPLAY_PROGRESS ",JSON.stringify({"rows":rows.size(),"at":v(after),"way":drive._way,"phase":drive._phase,"result":result}))
	if result in ["arrived","blocked"]:_finish(result);return
	if Engine.get_physics_frames()-started_frame>=2700:_finish("bounded45s_end")
func _finish(reason:String)->void:
	if finished:return
	finished=true
	var record:Dictionary={"schema":"mafiozi.roam58.native-diagnostic/v1","reason":reason,"full_city_acceptance":false,"performance_accepted":false,
		"start":v(START),"goal":v(GOAL),"contract":contract,"geometry":geometry,"paths":paths,"rows":rows,
		"physics_hz":Engine.physics_ticks_per_second,"time_scale":Engine.time_scale,"native_physics_frames":Engine.get_physics_frames()-started_frame if started_frame>=0 else 0,
		"elapsed_s":float(Time.get_ticks_usec()-started_us)/1000000.0 if started_us>0 else 0,"production_source_modified":false}
	if not out.is_empty():
		var file:=FileAccess.open(out.path_join("NATIVE58.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(record));file.close()
	print("ROAM58_REPLAY_RESULT ",JSON.stringify({"reason":reason,"rows":rows.size(),"frames":record.native_physics_frames,"elapsed_s":record.elapsed_s}))
	get_tree().quit(0 if reason in ["arrived","blocked","bounded45s_end"] else 1)
