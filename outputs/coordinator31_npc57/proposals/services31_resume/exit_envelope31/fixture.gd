extends "../fixture31.gd"

func wall(name31:String,at:Vector3,size31:Vector3)->void:
	var node:=StaticBody3D.new();node.name=name31
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size31;shape.shape=box
	node.add_child(shape);world.add_child(node);node.global_position=at

func detail(visit:RefCounted,body:CharacterBody3D)->Dictionary:
	return {"position":body.global_position,"door":visit._door,"inward":visit._inward,"depth":visit.depth_inside(),"inside_envelope":visit._inside_envelope30(),"entered_flag":visit._entered,"needs_exit":visit.needs_exit(),"phase":visit._phase,"leg":visit._leg,"target":visit._drive._target,"physical":visit._drive._route.diagnostics(),"reason":visit.last_reason(),"claim":visit._registry.ledger.requests.get(visit._key,{}).duplicate(true)}

func _run()->void:
	world=World.new();world.name="NativeExteriorEnvelope31";get_tree().root.add_child(world);get_tree().current_scene=world
	var grid:Array=[]
	for z:int in range(40):
		var row:Array=[]
		for x:int in range(40):row.append(1)
		grid.append(row)
	world._block={"surface":{"grid":grid,"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":-20,"startRow":-20}}
	var ground:=StaticBody3D.new();ground.name="NativeGround"
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,.2,40);shape.shape=box;shape.position.y=-.1;ground.add_child(shape);world.add_child(ground)
	await step();await step()
	var site:Node3D=Site.new();site.name="RealCompactShop";site.source_id="exterior_shop31";site.service_kind="shop";site.service_sign="МАГАЗИН";site.native_ground29.assign([ground]);site.set_meta("dsh_town_extra",true);site.set_meta("venue_capacity29",4);site.set_meta("venue_closed29",true);world.add_child(site)
	check("native_shop_ready",bool(site.bind_service(world).get("ok",false)))
	await step();await step()
	# A real unreachable exterior start on the inward side of the infinite
	# entrance plane. The capsule is clear; the four native walls reject routes.
	wall("ExteriorEast",Vector3(1.8,1.5,-12),Vector3(.2,3,3.8))
	wall("ExteriorWest",Vector3(-1.8,1.5,-12),Vector3(.2,3,3.8))
	wall("ExteriorNorth",Vector3(0,1.5,-13.8),Vector3(3.8,3,.2))
	wall("ExteriorSouth",Vector3(0,1.5,-10.2),Vector3(3.8,3,.2))
	var customer:=actor("distant_customer31",Vector3(0,.003,-12))
	await step();await step()
	var visit:=Visit.new()
	check("real_registry_admission",visit.begin(world,customer,RID(),"distant_customer31","МАГАЗИН"))
	check("initial_far_start_is_supported_exterior",visit.depth_inside()>.55 and not visit._inside_envelope30() and not visit._entered and not visit.needs_exit() and Visit.supported(customer,visit._support))
	var before:Dictionary=detail(visit,customer)
	await step()
	var result:String=visit.step(1.0/60.0)
	var first:Dictionary=detail(visit,customer)
	check("first_step_does_not_claim_distant_interior",not visit._entered and not visit.needs_exit())
	var final:=first;var elapsed_frames:=1;var max_native_queries:int=int(visit._drive._route.queries)
	for tick:int in range(1800):
		if result=="blocked":break
		await step();elapsed_frames+=1;result=visit.step(1.0/60.0)
		max_native_queries=maxi(max_native_queries,int(visit._drive._route.queries))
		if tick%30==0:rows.append(detail(visit,customer))
	final=detail(visit,customer)
	check("native_wall_search_returns_blocked",result=="blocked" and max_native_queries>0)
	check("blocked_exterior_needs_no_exit",not visit.needs_exit() and not visit._entered)
	check("blocked_exterior_releases_capacity",not visit._registry.ledger.requests.has(visit._key))
	var false_exit:bool=visit.begin_exit()
	var after_exit:Dictionary=detail(visit,customer)
	check("blocked_exterior_refuses_false_outbound",not false_exit and visit._phase!="OUTBOUND")
	check("all_motion_in_physics_context",physics_context_misses==0 and Engine.physics_ticks_per_second==60 and absf(min_observed_delta-1.0/60.0)<.000001 and absf(max_observed_delta-1.0/60.0)<.000001)
	check("no_customer_teleport_or_displacement",customer.global_position.distance_to(Vector3(0,.003,-12))<.05)
	var value:Dictionary={"candidate":candidate,"checks":checks,"before":before,"first":first,"final":final,"after_exit":after_exit,"false_exit_started":false_exit,"trace":rows,"frames":elapsed_frames,"max_native_queries":max_native_queries,"actual_physics_hz":Engine.physics_ticks_per_second,"context_misses":physics_context_misses,"performance_accepted":false,"full_city_acceptance":false,"setup":"real compact service plus four native exterior walls; no NPC position writes after initial setup"}
	var file:=FileAccess.open(out.path_join("NATIVE31.json"),FileAccess.WRITE);file.store_string(JSON.stringify(value,"\t"));file.close()
	visit.cancel();world.queue_free();await step();await step();get_tree().quit(0)
