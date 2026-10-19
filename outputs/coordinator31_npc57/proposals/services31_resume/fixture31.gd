extends Node
const Site = preload("res://scripts/venues/npc_compact_service_site29.gd")
const Visit = preload("res://scripts/hospital/npc_restaurant_visit28.gd")
const Registry = preload("res://scripts/venues/npc_venue_registry29.gd")
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
const Drive = preload("res://scripts/hospital/npc_simple_hospital.gd")
class Residents extends RefCounted:
	var _records: Dictionary = {}
class Population extends RefCounted:
	var residents := Residents.new()
	func occupants() -> Array: return []
class World extends Node3D:
	var preview_population := Population.new()
	var preview_venue_staff29: Node
	var _player: CharacterBody3D
	var _origin := Vector3.ZERO
	var _block: Dictionary = {}
var world: World
var out := ""
var candidate := false
var frames := 0
var rows: Array = []
var checks: Dictionary = {}
var finished := false
var physics_context_misses := 0
var min_observed_delta := INF
var max_observed_delta := 0.0
func _ready() -> void:
	Engine.physics_ticks_per_second=60
	Engine.time_scale=1.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
		if arg == "--candidate31=1": candidate = true
	_run.call_deferred()
func check(label: String, value: bool) -> void:
	checks[label] = value
	print("PASSAGE31_CHECK ", label, " ", value)
func step() -> void:
	await get_tree().physics_frame
	if not Engine.is_in_physics_frame():physics_context_misses+=1
	min_observed_delta=minf(min_observed_delta,get_physics_process_delta_time())
	max_observed_delta=maxf(max_observed_delta,get_physics_process_delta_time())
	frames += 1
func actor(id: String, at: Vector3, npc: bool = true) -> CharacterBody3D:
	var body := CharacterBody3D.new(); body.name=id; body.collision_layer=1; body.collision_mask=1
	var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius=.36; capsule.height=1.9
	shape.shape=capsule; shape.position.y=.95; body.add_child(shape); world.add_child(body); body.global_position=at
	if npc: world.preview_population.residents._records[id]={"body":body,"row":{"source_id":id},"generation":1}
	return body
func snapshot(visit: RefCounted, body: CharacterBody3D) -> Dictionary:
	var drive: RefCounted=visit._drive
	var physical: RefCounted=drive._route if drive!=null else null
	var hits: Array=[]
	if physical!=null:
		for hit: Dictionary in body.get_world_3d().direct_space_state.intersect_shape(physical._query(drive._target),8):
			hits.append(str(hit.collider.get_path()))
	return {"frame":frames,"position":body.global_position,"phase":visit._phase,"reason":visit._reason,"leg":visit._leg,"goal":drive._target if drive!=null else null,"plan":physical.diagnostics() if physical!=null else {},"goal_hits":hits,"door":visit._door_owner.door_fraction("public"),"exit_state":visit._exit_door_state56,"avoidance":drive._avoidance29_state if drive!=null else {}}
func _run() -> void:
	world=World.new(); world.name="NativeCompactShop31"; get_tree().root.add_child(world);get_tree().current_scene=world
	var grid: Array=[]
	for z: int in range(40):
		var row: Array=[]
		for x: int in range(40): row.append(1)
		grid.append(row)
	world._block={"surface":{"grid":grid,"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":-20,"startRow":-20}}
	var ground:=StaticBody3D.new();ground.name="NativeGround";var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(40,.2,40);floor_shape.shape=floor_box;floor_shape.position.y=-.1;ground.add_child(floor_shape);world.add_child(ground)
	await step();await step()
	var site:Node3D=Site.new();site.name="CompactServiceShop31";site.source_id="fixture_shop31";site.service_kind="shop";site.service_sign="МАГАЗИН";site.native_ground29.assign([ground]);site.set_meta("dsh_town_extra",true);site.set_meta("venue_capacity29",4);site.set_meta("venue_closed29",true);world.add_child(site)
	check("actual_compact_native_site",bool(site.bind_service(world).get("ok",false)))
	await step();await step()
	var customer:=actor("customer31",Vector3(0,.243,.5))
	var blocker:=actor("blocker31",Vector3(0,.243,4.25))
	var physical:=Physical.new();check("native_capsule_configured",physical.configure(customer))
	for body:CharacterBody3D in [customer,blocker]:
		var support:Variant=physical.floor_at(body.global_position,body.global_position.y)
		if support is Vector3:body.global_position=support
	# All position assignments above are initial fixture setup; subsequent travel is native.
	await step();await step()
	var visit:=Visit.new();check("service_admission",visit.begin(world,customer,RID(),"customer31","МАГАЗИН"))
	var entered:=false;var exited:=false;var blocked:=0;var first_exit_frame:=-1
	var first_exit_tick:=-1;var first_exit_us:=-1
	var nearest_peer:=INF;var maximum_step:=0.0;var previous:Vector3=customer.global_position
	for tick:int in range(1500):
		await step()
		blocker.velocity=Vector3(0,-1.0,0);blocker.move_and_slide()
		var result:String=visit.step(1.0/60.0)
		nearest_peer=minf(nearest_peer,Vector2(customer.global_position.x-blocker.global_position.x,customer.global_position.z-blocker.global_position.z).length())
		maximum_step=maxf(maximum_step,customer.global_position.distance_to(previous));previous=customer.global_position
		if result=="entered":
			entered=true;check("physical_service_interior",visit.is_inside());check("physical_exit_begins",visit.begin_exit());first_exit_frame=frames
			first_exit_tick=Engine.get_physics_frames();first_exit_us=Time.get_ticks_usec()
		elif result=="blocked":
			blocked+=1
			if visit.needs_exit():visit.begin_exit()
		elif result=="exited":exited=true;break
		if tick%30==0:rows.append(snapshot(visit,customer))
	check("physical_entry_then_exit",entered and exited and visit.is_outside())
	var exit_elapsed_s:float=float(Engine.get_physics_frames()-first_exit_tick)/60.0
	var exit_wall_s:float=float(Time.get_ticks_usec()-first_exit_us)/1000000.0
	check("bounded_exit_under_8_seconds",exited and exit_elapsed_s<8.0 and exit_wall_s<8.0)
	rows.append(snapshot(visit,customer))
	var registry:RefCounted=Registry.for_scene(world)
	check("claim_released_only_after_physical_exit",exited and not registry.ledger.requests.has(visit._key))
	var passage:Variant=world.get_meta("npc_passage31") if world.has_meta("npc_passage31") else null
	var metrics:Dictionary=passage.diagnostics() if passage!=null else {}
	check("no_world_collision_exception",not customer.get_collision_exceptions().has(ground))
	check("native_walk_without_teleport",maximum_step<.10)
	check("actual_body_overlap_in_passage",nearest_peer<.35)
	if candidate:
		check("symmetric_passage_exceptions",customer.get_collision_exceptions().has(blocker) and blocker.get_collision_exceptions().has(customer))
		check("planner_ignores_passage_peer",physical.standing(blocker.global_position))
		var ray:=PhysicsRayQueryParameters3D.create(blocker.global_position+Vector3(-.6,1.0,0),blocker.global_position+Vector3(.6,1.0,0),1)
		var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check("native_hit_ray_still_hits_peer",hit.get("collider")==blocker)
		world._player=actor("player31",Vector3(.8,.1,4.25),false)
		await step();await step()
		check("player_never_ignored",not customer.get_collision_exceptions().has(world._player) and not physical.standing(world._player.global_position))
		check("wall_still_blocks_capsule",not physical.standing(Vector3(4,.243,0)))
		world._player.queue_free();world._player=null
		# Isolated cleanup case reset, outside the measured passage.
		customer.global_position=Vector3(6,.003,6)
		await step();await step()
		check("exceptions_removed_on_passage_exit",not customer.get_collision_exceptions().has(blocker) and not blocker.get_collision_exceptions().has(customer))
		var outside_peer:=actor("outside_peer31",Vector3(7,.003,6))
		await step();await step()
		check("outside_planner_keeps_peer_collision",passage.body_zone(customer).is_empty() and not physical.standing(outside_peer.global_position) and not customer.get_collision_exceptions().has(outside_peer))
		outside_peer.queue_free()
		blocker.queue_free();await step();await step()
		check("freed_body_pairs_retired",passage._pairs.is_empty())
	else:blocker.queue_free();await step();await step()
	visit.cancel()
	customer.queue_free();await step();await step()
	# Second native scenario: two moving clients traverse the same open doorway
	# in opposite directions. New initial poses; no changes after motion begins.
	var swing:Node3D=site._swing29
	swing.request_door("public",true,swing.anchor,[])
	for tick:int in range(100):
		await step()
		if swing.door_fraction("public")>=.999:break
	var inbound:=actor("inbound31",Vector3(0,.003,5.5))
	var outbound:=actor("outbound31",Vector3(0,.243,1.0))
	await step();await step()
	var drive_in:=Drive.new();var drive_out:=Drive.new()
	check("head_on_routes_started",drive_in.begin(Vector3(0,.243,1.0),inbound,RID(),"inbound31","service_approach") and drive_out.begin(Vector3(0,.003,5.5),outbound,RID(),"outbound31","service_approach"))
	var in_done:=false;var out_done:=false;var headon_frames:=0;var min_pair:=INF
	var headon_start_tick:int=Engine.get_physics_frames();var headon_start_us:int=Time.get_ticks_usec()
	for tick:int in range(480):
		await step();headon_frames+=1
		if not in_done:in_done=drive_in.step(1.0/60.0)=="arrived"
		else:drive_in.hold(1.0/60.0)
		if not out_done:out_done=drive_out.step(1.0/60.0)=="arrived"
		else:drive_out.hold(1.0/60.0)
		min_pair=minf(min_pair,Vector2(inbound.global_position.x-outbound.global_position.x,inbound.global_position.z-outbound.global_position.z).length())
		if in_done and out_done:break
	var headon_elapsed_s:float=float(Engine.get_physics_frames()-headon_start_tick)/60.0
	var headon_wall_s:float=float(Time.get_ticks_usec()-headon_start_us)/1000000.0
	check("head_on_both_complete_within_8s",in_done and out_done and headon_elapsed_s<8.0 and headon_wall_s<8.0)
	check("head_on_actual_overlap",min_pair<.35)
	drive_in.cancel();drive_out.cancel()
	if candidate:
		# A lifecycle retirement while both bodies are still in the doorway must
		# remove old native exceptions before a newly spawned identity is admitted.
		inbound.global_position=Vector3(0,.243,2.5);outbound.global_position=Vector3(0,.243,3.5)
		await step();await step()
		check("second_pair_has_symmetric_exceptions",inbound.get_collision_exceptions().has(outbound) and outbound.get_collision_exceptions().has(inbound))
		outbound.collision_layer=512
		await step();await step()
		check("death_layer_retires_exceptions",not inbound.get_collision_exceptions().has(outbound) and not outbound.get_collision_exceptions().has(inbound))
		outbound.queue_free();await step();await step()
		var reborn:=actor("outbound31",Vector3(0,.243,3.5))
		await step();await step()
		check("respawn_binds_only_new_body",inbound.get_collision_exceptions().has(reborn) and reborn.get_collision_exceptions().has(inbound) and passage._pairs.size()==1)
		reborn.free()
		check("same_frame_free_query_safe",passage.query_exclusions(inbound,inbound.global_position).size()==1)
		inbound.queue_free();await step();await step()
		check("all_old_pairs_removed",passage._pairs.is_empty())
		var door_probe:=actor("door_probe31",Vector3(0,.003,6))
		var door_physical:=Physical.new();door_physical.configure(door_probe)
		swing.request_door("public",false,swing.anchor,[])
		for tick:int in range(120):
			await step()
			if swing.door_fraction("public")<=.001:break
		check("closed_real_door_still_blocks",swing.door_fraction("public")<=.001 and not door_physical.standing(Vector3(0,.243,3.5)))
	check("native_moves_in_physics_context",physics_context_misses==0)
	check("fixed_60hz_controller_and_engine",Engine.physics_ticks_per_second==60 and absf(min_observed_delta-1.0/60.0)<.000001 and absf(max_observed_delta-1.0/60.0)<.000001)
	var record:Dictionary={"candidate":candidate,"native_compact_source":true,"full_city_acceptance":false,"initial_placement_only_per_case":true,"checks":checks,"blocked":blocked,"frames":frames,"rows":rows,"passage":metrics,"nearest_peer_m":nearest_peer,"max_native_step_m":maximum_step,"head_on_frames":headon_frames,"head_on_min_separation_m":min_pair,"performance_accepted":false,"physics_hz":Engine.physics_ticks_per_second,"controller_delta":1.0/60.0,"observed_delta_min":min_observed_delta,"observed_delta_max":max_observed_delta,"physics_context_misses":physics_context_misses,"exit_elapsed_s":exit_elapsed_s,"exit_wall_s":exit_wall_s,"headon_elapsed_s":headon_elapsed_s,"headon_wall_s":headon_wall_s}
	var file:=FileAccess.open(out.path_join("NATIVE31.json"),FileAccess.WRITE);file.store_string(JSON.stringify(record,"\t"));file.close()
	world.queue_free();await step();await step()
	get_tree().quit(0)

