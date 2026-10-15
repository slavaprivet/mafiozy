extends "fixture_base31.gd"

func _run()->void:
	var test_case:="recovery"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--door-case="):test_case=arg.trim_prefix("--door-case=")
	world=World.new();world.name="MafioziWalkMigration";get_tree().root.add_child(world);get_tree().current_scene=world
	var grid:Array=[]
	for z:int in range(40):
		var row:Array=[]
		for x:int in range(40):row.append(1)
		grid.append(row)
	world._block={"surface":{"grid":grid,"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":-160,"startRow":142}}
	var ground:=StaticBody3D.new();ground.name="NativeGround"
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,.2,40);shape.shape=box;shape.position=Vector3(-140,-.1,162);ground.add_child(shape);world.add_child(ground)
	await step();await step()
	var site:Node3D=Site.new();site.name="CompactService29_VENUE29-SHOP-002";site.source_id="VENUE29-SHOP-002";site.service_kind="shop";site.service_sign="МАГАЗИН";site.position=Vector3(-139.4,0,161.95);site.rotation.y=PI/2
	site.native_ground29.assign([ground]);site.set_meta("dsh_town_extra",true);site.set_meta("venue_capacity29",4);site.set_meta("venue_closed29",true);world.add_child(site)
	check("exact_compact_shop002_geometry",bool(site.bind_service(world).get("ok",false)))
	await step();await step()
	var owner:Node3D=site._swing29
	# Restore the observed partial leaf pose once, before actor/controller setup.
	# There are no pose/fraction writes during measured native movement.
	owner.fraction=9.0/13.0;owner.target=1.0;owner._commit_pose();owner._sync_state()
	var customer:CharacterBody3D=actor("npc_resident_2",Vector3(-138.2059021,.2400011,161.9554291))
	var walker:CharacterBody3D=actor("npc_resident_9",Vector3(-137.7398224,.2409419,162.0625763))
	if test_case in ["player","watch"]:world._player=actor("NativePlayer31",Vector3(-137.45,.243,162.75),false)
	await step();await step()
	var registry:RefCounted=Registry.for_scene(world);registry.refresh(customer,Time.get_ticks_msec(),"shop")
	var probe:=Physical.new();probe.configure(customer)
	await step();await step()
	owner.fraction=9.0/13.0;owner.target=1.0;owner._commit_pose();owner._sync_state()
	if test_case=="closed":owner.fraction=0.0;owner.target=0.0;owner._commit_pose();owner._sync_state()
	var visit:=Visit.new();check("actual_resident2_service_route",visit.begin(world,customer,RID(),"resident_2","МАГАЗИН"))
	var roam:=Drive.new();var roam_goal:=Vector3(-132.3,.003,161.95)
	check("actual_resident9_roam_route",roam.begin(roam_goal,walker,RID(),"resident_9","roam"))
	var player_probe:RefCounted
	if test_case=="watch":
		roam._roam_watch29._planning_ms=13000;roam._roam_watch29._motion_idle_ms=2000
		player_probe=Physical.new();check("native_player_probe",player_probe.configure(world._player))
	if candidate:
		# The helper must not respond to a stale blocker after real close intent.
		owner._request_target(false,"boundary_close")
		check("close_revokes_open_intent",not owner.opening_requested31() and not roam._door_clear31.poll(roam._route))
		roam._door_clear31._next_poll=0
	var request:Dictionary=owner.request_door("public",true,customer.global_position,[])
	if test_case=="closed":check("actual_closed_open_request_refused_by9",not request.accepted and owner._blocked_reason=="sweep_body:"+str(walker.get_path()) and owner.target==0.0)
	print("DOOR31_SETUP visit=",visit.last_reason()," roam=",roam.last_reason()," entries=",visit._registry._entries.size() if visit._registry!=null else -1)
	var entered:bool=visit._entered;check("resident2_owned_inside_exit_started",entered and visit.begin_exit())
	var exited:=false;var arrived:=false;var exit_tick:=-1;var exit_wall:=-1
	var stalled_open:=false;var own_blocker_seen:=false;var pair_seen:=false;var same_zone:=false;var inner_hits:Array=[]
	var max_step:=0.0;var previous:Array=[customer.global_position,walker.global_position]
	var start_tick:int=Engine.get_physics_frames();var start_us:int=Time.get_ticks_usec()
	for tick:int in range(1200):
		await step()
		if test_case=="watch":
			if tick>=180 and tick<240:player_probe.move(Vector3.LEFT,1.8/60.0,1.0/60.0)
			else:player_probe.hold(1.0/60.0)
		if candidate and tick==5 and test_case=="retire":
			check("retire_during_active_backoff",roam._door_clear31.active());walker.collision_layer=0
		if candidate and tick==5 and test_case=="revoke":
			check("close_during_active_backoff",roam._door_clear31.active());owner.request_door("public",false,customer.global_position,[])
		if candidate and tick==5 and test_case=="pause":
			check("pause_in_active_backoff",roam._door_clear31.active() and roam.attention_pause29())
			check("pause_retires_backoff",not roam._door_clear31.active())
		if candidate and tick==13 and test_case=="pause":check("resume_original_roam",roam.attention_resume29())
		if candidate and tick==5 and test_case=="cancel":
			check("cancel_in_active_backoff",roam._door_clear31.active());roam.cancel()
			check("cancel_retires_backoff_and_route",not roam._door_clear31.active() and not roam._active and roam._route.status=="cancelled")
		if candidate and tick==13 and test_case=="cancel":check("new_roam_route_begins_clean",roam.begin(roam_goal,walker,RID(),"resident_9","roam") and not roam._door_clear31.active())
		var outcome:String=visit.step(1.0/60.0) if not exited else ""
		if outcome=="entered":entered=true;check("resident2_exit_started",visit.begin_exit());exit_tick=Engine.get_physics_frames();exit_wall=Time.get_ticks_usec()
		if outcome=="exited":exited=true
		if not arrived:arrived=roam.step(1.0/60.0)=="arrived"
		else:roam.hold(1.0/60.0)
		if candidate and tick==5 and test_case=="revoke":check("revocation_retires_backoff_immediately",not roam._door_clear31.active() and roam._door_clear31.snapshot().events.any(func(e:Dictionary)->bool:return e.event=="open_intent_revoked"))
		if candidate and tick==5 and test_case=="retire":check("retired_body_stops_without_original_goal_restart",not roam._active and not roam._door_clear31.active() and roam._route.status=="cancelled" and roam.last_reason()=="door_backoff_actor_retired31")
		if exited:visit._drive.hold(1.0/60.0)
		max_step=maxf(max_step,maxf(customer.global_position.distance_to(previous[0]),walker.global_position.distance_to(previous[1])));previous=[customer.global_position,walker.global_position]
		own_blocker_seen=own_blocker_seen or owner._blocked_reason=="sweep_body:"+str(walker.get_path())
		pair_seen=pair_seen or (customer.get_collision_exceptions().has(walker) and walker.get_collision_exceptions().has(customer))
		var passage:Node=world.get_meta("npc_passage31")
		same_zone=same_zone or (not passage.body_zone(customer).is_empty() and passage.body_zone(customer)==passage.body_zone(walker))
		stalled_open=stalled_open or (visit._exit_door_state56=="opening" and tick>600)
		if tick%6==0:
			inner_hits=[]
			for hit:Dictionary in customer.get_world_3d().direct_space_state.intersect_shape(visit._support._query(visit._inner),16):inner_hits.append(str(hit.collider.get_path()))
			var clear:Variant=roam.get("_door_clear31")
			rows.append({"frame":Engine.get_physics_frames(),"elapsed_s":float(Engine.get_physics_frames()-start_tick)/60.0,"resident2":snapshot(visit,customer),"resident9":{"position":walker.global_position,"phase":roam._phase,"waypoint":roam._route.route[roam._way] if roam._way<roam._route.route.size() else null,"goal":roam._target,"plan":roam._route.diagnostics(),"avoidance":roam._avoidance29_state.duplicate(true),"clearance":clear.snapshot() if clear!=null else {}},"door":owner.snapshot(),"inner_overlap":inner_hits,"same_zone":same_zone,"native_pair_exception":customer.get_collision_exceptions().has(walker)})
		if exited and arrived:break
		if test_case=="player" and not roam._active and roam.last_reason()=="door_backoff_timeout31":break
		if test_case=="retire" and tick==6:break
	check("actual_door_sweep_blocked_by_resident9",own_blocker_seen)
	check("both_npcs_share_live_zone_and_symmetric_exceptions",same_zone and pair_seen)
	if test_case not in ["player","retire"]:check("resident2_and_roamer_both_physically_exit",entered and exited and arrived)
	var elapsed:float=float(Engine.get_physics_frames()-start_tick)/60.0
	if test_case not in ["player","retire"]:check("both_finish_under10_seconds",exited and arrived and elapsed<10.0)
	if test_case=="player":
		check("real_player_keeps_door_blocked",owner.fraction<.999 and owner._blocked_reason=="sweep_body:"+str(world._player.get_path()))
		check("bounded_backoff_timeout_preserves_goal",not roam._active and roam.last_reason()=="door_backoff_timeout31" and elapsed>=6.0 and elapsed<6.2)
		check("player_collision_never_exempted",not walker.get_collision_exceptions().has(world._player) and not roam._route.standing(world._player.global_position))
	check("native_step_bounded_no_teleport",max_step<.10)
	check("door_collision_preserved",not customer.get_collision_exceptions().has(owner.leaf) and not walker.get_collision_exceptions().has(owner.leaf) and owner.leaf.collision_layer==1)
	check("world_and_capsules_unchanged",customer.collision_mask==1 and walker.collision_mask==1 and not customer.get_collision_exceptions().has(ground) and not walker.get_collision_exceptions().has(ground))
	check("original_roam_goal_preserved",roam._target==roam_goal)
	if test_case=="watch":
		check("three_seconds_real_door_wait_then_goal_completed",elapsed>3.0 and exited and arrived)
		check("prior13s_planning_retained_without_charging_idle",roam._roam_watch29._planning_ms>=13000 and roam._roam_watch29._planning_ms<14000)
		check("real_backoff_resets_only_motion_stall",roam._roam_watch29._motion_idle_ms<500)
	if candidate:
		check("service_driver_has_no_roam_backoff",visit._drive._door_clear31==null)
		var events:Array=roam._door_clear31.snapshot().events
		if test_case in ["recovery","closed"]:check("physical_backoff_and_actual_open_resume_observed",events.any(func(e:Dictionary)->bool:return e.event=="native_backoff_begin") and events.any(func(e:Dictionary)->bool:return e.event=="fully_open_original_goal_resume"))
	check("native60hz",physics_context_misses==0 and Engine.physics_ticks_per_second==60 and absf(min_observed_delta-1.0/60.0)<.000001 and absf(max_observed_delta-1.0/60.0)<.000001)
	var data:Dictionary={"candidate":candidate,"case":test_case,"checks":checks,"rows":rows,"watch":roam._roam_watch29_state,"elapsed_s":elapsed,"wall_s":float(Time.get_ticks_usec()-start_us)/1000000.0,"max_native_step_m":max_step,"opening_stalled_past10s":stalled_open,"setup":"Exact authored SHOP-002 transform/geometry, real production Visit/Drive, initial observed partial leaf pose and resident9 position; no movement or door pose writes during measurement. Watch case restores13s prior planning/2s motion stall and uses a native player blocking the door for3s before physically walking away.","full_city_acceptance":false,"performance_accepted":false}
	var file:=FileAccess.open(out.path_join("NATIVE31.json"),FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
	visit.cancel();roam.cancel();world.queue_free();await step();await step();get_tree().quit(0)
