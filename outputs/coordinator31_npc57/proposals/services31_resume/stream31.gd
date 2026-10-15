extends "fixture31.gd"

func _run() -> void:
	world=World.new();world.name="NativeSixPassage31";get_tree().root.add_child(world);get_tree().current_scene=world
	var grid:Array=[]
	for z:int in range(40):
		var row:Array=[]
		for x:int in range(40):row.append(1)
		grid.append(row)
	world._block={"surface":{"grid":grid,"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":-20,"startRow":-20}}
	var ground:=StaticBody3D.new();ground.name="NativeGround"
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(40,.2,40);floor_shape.shape=floor_box;floor_shape.position.y=-.1;ground.add_child(floor_shape);world.add_child(ground)
	await step();await step()
	var site:Node3D=Site.new();site.name="CompactShopStreams31";site.source_id="stream_shop31";site.service_kind="shop";site.service_sign="МАГАЗИН";site.native_ground29.assign([ground]);site.set_meta("dsh_town_extra",true);site.set_meta("venue_capacity29",4);site.set_meta("venue_closed29",true);world.add_child(site)
	check("actual_compact_native_site",bool(site.bind_service(world).get("ok",false)))
	await step();await step()
	var bodies:Array[CharacterBody3D]=[]
	var seed:=actor("inbound_0",Vector3(0,.003,4.9));bodies.append(seed)
	await step();await step()
	var registry:RefCounted=Registry.for_scene(world);registry.refresh(seed,Time.get_ticks_msec(),"shop")
	check("native_door_discovered",registry._entries.size()==1)
	var swing:Node3D=site._swing29;swing.request_door("public",true,swing.anchor,[])
	for tick:int in range(100):
		await step()
		if swing.door_fraction("public")>=.999:break
	check("real_door_open",swing.door_fraction("public")>=.999)
	# Poses are initialized only after the real leaf has completed its sweep.
	# The measured streams request the door like a visit controller would.
	for index:int in range(1,3):bodies.append(actor("inbound_"+str(index),Vector3(0,.003,4.9+.8*index)))
	for index:int in range(3):bodies.append(actor("outbound_"+str(index),Vector3(0,.243,2.1-.8*index)))
	var drives:Array=[];var arrived:Array=[];var previous:Array=[];var min_cross:Dictionary={};var started:=true
	for index:int in range(6):
		var drive:=Drive.new();drives.append(drive);arrived.append(false);previous.append(bodies[index].global_position)
		started=drive.begin(Vector3(0,.243,.5) if index<3 else Vector3(0,.003,6.5),bodies[index],RID(),str(bodies[index].name),"service_approach") and started
	check("six_native_routes_started",started)
	for a:int in range(3):
		for b:int in range(3,6):min_cross[str(a)+":"+str(b)]=INF
	var maximum_step:=0.0;var movement_frames:=0
	var movement_start_tick:int=Engine.get_physics_frames();var movement_start_us:int=Time.get_ticks_usec()
	for tick:int in range(720):
		await step();movement_frames+=1
		swing.request_door("public",true,swing.anchor,[])
		for index:int in range(6):
			if not arrived[index]:arrived[index]=drives[index].step(1.0/60.0)=="arrived"
			else:drives[index].hold(1.0/60.0)
			maximum_step=maxf(maximum_step,bodies[index].global_position.distance_to(previous[index]));previous[index]=bodies[index].global_position
		for a:int in range(3):
			for b:int in range(3,6):
				var key:=str(a)+":"+str(b);var separation:Vector3=bodies[a].global_position-bodies[b].global_position
				min_cross[key]=minf(min_cross[key],Vector2(separation.x,separation.z).length())
		if arrived.all(func(value:bool)->bool:return value):break
	check("six_native_walks_without_teleport",maximum_step<.1)
	var movement_elapsed_s:float=float(Engine.get_physics_frames()-movement_start_tick)/60.0
	var movement_wall_s:float=float(Time.get_ticks_usec()-movement_start_us)/1000000.0
	check("two_streams_all_six_complete_under_12s",arrived.all(func(value:bool)->bool:return value) and movement_elapsed_s<12.0 and movement_wall_s<12.0)
	check("all_nine_opposed_pairs_physically_cross",min_cross.values().all(func(value:float)->bool:return value<.35))
	var masks_unchanged:=true;var world_collision_preserved:=true
	for body:CharacterBody3D in bodies:
		masks_unchanged=masks_unchanged and body.collision_layer==1 and body.collision_mask==1
		world_collision_preserved=world_collision_preserved and not body.get_collision_exceptions().has(ground)
	check("all_native_masks_unchanged",masks_unchanged);check("all_native_ground_collisions_preserved",world_collision_preserved)
	var positions:Array=[]
	for body:CharacterBody3D in bodies:positions.append(body.global_position)
	var passage:Variant=world.get_meta("npc_passage31") if world.has_meta("npc_passage31") else null
	var metrics:Dictionary=passage.diagnostics() if passage!=null else {}
	for drive:RefCounted in drives:drive.cancel()
	for body:CharacterBody3D in bodies:body.queue_free()
	await step();await step()
	if candidate:check("all_six_removed_without_stale_pairs",passage._pairs.is_empty())
	check("native_moves_in_physics_context",physics_context_misses==0)
	check("fixed_60hz_controller_and_engine",Engine.physics_ticks_per_second==60 and absf(min_observed_delta-1.0/60.0)<.000001 and absf(max_observed_delta-1.0/60.0)<.000001)
	var record:Dictionary={"candidate":candidate,"checks":checks,"frames":frames,"movement_frames":movement_frames,"arrived":arrived,"positions":positions,"max_native_step_m":maximum_step,"min_cross_pair_m":min_cross,"passage":metrics,"full_city_acceptance":false,"performance_accepted":false,"physics_hz":Engine.physics_ticks_per_second,"controller_delta":1.0/60.0,"observed_delta_min":min_observed_delta,"observed_delta_max":max_observed_delta,"physics_context_misses":physics_context_misses,"movement_elapsed_s":movement_elapsed_s,"movement_wall_s":movement_wall_s}
	var file:=FileAccess.open(out.path_join("NATIVE31.json"),FileAccess.WRITE);file.store_string(JSON.stringify(record,"\t"));file.close()
	world.queue_free();await step();await step();get_tree().quit(0)
