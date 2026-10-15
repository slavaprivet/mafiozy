extends "../fixture31.gd"
const Visit = preload("res://scripts/hospital/npc_restaurant_visit28.gd")
const Capacity = preload("res://scripts/venues/npc_venue_capacity29.gd")
const ServiceQueue = preload("res://scripts/venues/npc_service_queue29.gd")
var candidate := false

func _ready() -> void:
	Engine.physics_ticks_per_second = 60; Engine.time_scale = 1.0
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--candidate=1": candidate = true
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	_run.call_deferred()

func ledger_checks() -> void:
	var ledger: RefCounted = Capacity.new(); ledger.register("supported","shop",4); ledger.register("other","shop",2)
	for i: int in range(5): ledger.request("c"+str(i),"shop",[{"venue":"supported","cost":1.0}],100)
	check("room_capacity_remains4_fifth_waits",ledger.venues.supported.slots.size() == 4 and ledger.requests.c4.state == "waiting")
	if candidate: ledger.set_concurrent_portal31("supported",true)
	var granted := 0
	for i: int in range(4):
		if ledger.portal_request("c"+str(i),"supported"): granted += 1
	check("four_reserved_portal_permissions",granted == 4)
	check("unreserved_and_cross_venue_refused",not ledger.portal_request("c4","supported") and not ledger.portal_request("c0","other"))
	ledger.request("o0","shop",[{"venue":"other","cost":1.0}],100)
	ledger.request("o1","shop",[{"venue":"other","cost":1.0}],100)
	check("unsupported_venue_still_serial",ledger.portal_request("o0","other") and not ledger.portal_request("o1","other"))
	ledger.portal_release("c1","supported")
	check("portal_release_keeps_room_claim",ledger.requests.has("c1") and ledger.venues.supported.slots.size() == 4)
	ledger.release("c1",200,"physical_exit")
	check("physical_release_promotes_only_one_room_waiter",ledger.requests.c4.state == "reserved" and ledger.venues.supported.slots.size() == 4 and not ledger.requests.has("c1"))
	var service := ServiceQueue.new(); service.enqueue("c0","supported"); service.enqueue("c2","supported")
	check("cashier_staff_fifo_retained",service.owns("c0","supported") and not service.owns("c2","supported"))
	service.release("c0"); check("cashier_next_only_after_release",service.owns("c2","supported"))
	ledger.unregister("supported",300)
	check("retired_venue_releases_portal_and_claims",not ledger._portals.has("supported") and not ledger.requests.has("c0") and not ledger.requests.has("c4"))

func _run() -> void:
	run_started = Time.get_ticks_usec(); ledger_checks()
	world = World.new(); world.name = "ConcurrentPortal31"; get_tree().root.add_child(world); get_tree().current_scene = world
	var grid: Array = []
	for z: int in range(40):
		var row: Array = []
		for x: int in range(40): row.append(1)
		grid.append(row)
	world._block = {"surface":{"grid":grid,"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":-20,"startRow":-20}}
	ground = box_body("RealGround",Vector3(0,-.1,0),Vector3(40,.2,40))
	await step(); await step()
	var site: Node3D = Site.new(); site.name = "RealPortalShop"; site.source_id = "portal31_shop"
	site.service_kind = "shop"; site.service_sign = "МАГАЗИН"; site.native_ground29.assign([ground]); site.set_meta("dsh_town_extra",true); site.set_meta("venue_capacity29",4); site.set_meta("venue_closed29",true); world.add_child(site)
	check("real_compact_site",bool(site.bind_service(world).get("ok",false)))
	await step(); await step()
	bodies.assign([actor("held_outbound",Vector3(0,.243,.5)),actor("free_outbound",Vector3(1.2,.243,.5)),actor("inbound_a",Vector3(-2.8,.003,7.1)),actor("inbound_b",Vector3(2.8,.003,7.1))])
	await step(); await step()
	var registry: RefCounted = Registry.for_scene(world); registry.refresh(bodies[0],Time.get_ticks_msec(),"shop")
	check("actual_door_inventory",registry._entries.size() == 1)
	var venue: String = str(registry._entries.keys()[0])
	await step(); await step()
	var entry: Dictionary = registry.entry(venue)
	# Initial placement: each already-inside customer starts at its own distinct
	# measured room slot, never occupying another customer's reserved destination.
	bodies[0].global_position = entry.rooms[0]
	bodies[1].global_position = entry.rooms[1]
	await step(); await step()
	check("capability_from_live_passage",bool(registry.ledger.venues[venue].get("concurrent_portal31",false)))
	var visits: Array = []; var begun := true
	for i: int in range(4):
		var visit: RefCounted = Visit.new(); visits.append(visit)
		begun = visit.begin(world,bodies[i],RID(),str(bodies[i].name),"МАГАЗИН") and begun
	check("four_real_visit_admissions",begun)
	check("two_physical_exit_requests",visits[0].begin_exit() and visits[1].begin_exit())
	var held_start: Vector3 = bodies[0].global_position
	var done := [false,false,false,false]; var entered := [false,false,false,false]
	var max_owners := 0; var max_step := 0.0; var min_cross := INF; var trace: Array = []
	var start_tick: int = Engine.get_physics_frames(); var started: int = Time.get_ticks_usec()
	for tick: int in range(900):
		await step()
		# A real paused outgoing visit retains its claim, as during attention.
		# Others must be able to enter/exit without cancelling or teleporting it.
		visits[0].attention_hold29(1.0/60.0)
		for i: int in range(1,4):
			var before: Vector3 = bodies[i].global_position
			if done[i]: visits[i].hold(1.0/60.0)
			else:
				var result: String = visits[i].step(1.0/60.0)
				if result == "entered": entered[i] = true; visits[i].begin_exit()
				elif result == "exited": done[i] = true
			max_step = maxf(max_step,bodies[i].global_position.distance_to(before))
		var owners := 0
		for visit: RefCounted in visits:
			if candidate:
				if registry.ledger.portal_owner31(visit._key,venue): owners += 1
			else:
				var queue: Array = registry.ledger._portals.get(venue,[])
				if not queue.is_empty() and queue[0] == visit._key: owners += 1
		max_owners = maxi(max_owners,owners)
		for i: int in [2,3]: min_cross = minf(min_cross,Vector2(bodies[1].global_position.x-bodies[i].global_position.x,bodies[1].global_position.z-bodies[i].global_position.z).length())
		if tick % 30 == 0:
			var rows: Array = []
			for i: int in range(4): rows.append({"id":str(bodies[i].name),"position":bodies[i].global_position,"phase":visits[i]._phase,"leg":visits[i]._leg,"door_stage":visits[i]._exit_door_state56,"reason":visits[i]._reason,"hint":registry.doorway_state29(bodies[i])})
			trace.append({"tick":tick,"owners":owners,"door_fraction":site._swing29.door_fraction("public"),"rows":rows})
		if done[1] and done[2] and done[3]: break
	var elapsed_s: float = float(Engine.get_physics_frames()-start_tick)/60.0
	check("concurrent_real_portal_owners",max_owners >= 2)
	check("others_physically_exit_while_first_paused",done[1] and done[2] and done[3])
	check("both_inbound_physically_entered",entered[2] and entered[3])
	check("held_claim_not_cancelled_or_teleported",registry.ledger.requests.has(visits[0]._key) and bodies[0].global_position.distance_to(held_start) < .05)
	check("completed_claims_released_after_exit",not done[1] or not registry.ledger.requests.has(visits[1]._key))
	check("opposed_streams_native_overlap",min_cross < .35)
	check("native_no_teleports",max_step < .1)
	check("physical_floor_preserved",bodies.all(func(body: CharacterBody3D) -> bool: return body.collision_layer == 1 and body.collision_mask == 1 and not body.get_collision_exceptions().has(ground)))
	check("native60hz_context",physics_misses == 0 and absf(minimum_delta-1.0/60.0) < .000001 and absf(maximum_delta-1.0/60.0) < .000001)
	for visit: RefCounted in visits: visit.cancel()
	check("lifecycle_clears_portal_claims",registry.ledger.requests.is_empty() and registry.ledger._portals.is_empty())
	site.set_meta("venue_closed29",true); registry.entry(venue)
	check("closed_venue_not_supported",not registry.ledger.venues.has(venue))
	var record := {"candidate":candidate,"checks":checks,"elapsed_s":elapsed_s,"wall_s":float(Time.get_ticks_usec()-started)/1000000.0,"max_owners":max_owners,"done":done,"entered":entered,"min_opposed_separation_m":min_cross,"max_native_step_m":max_step,"physics_context_misses":physics_misses,"trace":trace,"source_route_unchanged":true,"production_integrated":false,"full_city_acceptance":false}
	var file := FileAccess.open(out.path_join("NATIVE.json"),FileAccess.WRITE); file.store_string(JSON.stringify(record,"\t")); file.close()
	world.queue_free(); await step(); await step(); get_tree().quit(0)
