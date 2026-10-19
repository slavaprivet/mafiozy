extends SceneTree
## One real resident, ordinary daily hospital owner and real staffed service.
## The sole initial placement precedes explicit medical begin. No later relocation.
const Registry = preload("res://scripts/venues/npc_venue_registry29.gd")
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
const Budget = preload("res://scripts/hospital/npc_route_budget29.gd")
const Work = preload("res://scripts/navigation/npc_navigation_work29.gd")
const START := Vector3(136.338562,.003,-13.815775)
var game:Node3D
var output:=""
var checks:Array[Dictionary]=[]
var samples:Array[Dictionary]=[]
var evidence:Dictionary={}
func _initialize()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out=" ):output=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func check(label:String,passed:bool,extra:Dictionary={})->bool:
	extra.merge({"label":label,"passed":passed});checks.append(extra);return passed
func finish()->void:
	var passed:bool=checks.all(func(row:Dictionary)->bool:return row.passed)
	var report:Dictionary={"passed":passed,"checks":checks,"samples":samples,"evidence":evidence,"production_residents":1,"extra_fixture_bodies":0,"initial_position_setup_before_medical_begin":true,"relocations_after_medical_begin":0,"hp_initialization":"ordinary --city-hp=20 flag","synthetic_damage":false,"synthetic_healing":false,"fake_arrivals":false,"performance_accepted":false}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("REAL_HOSPITAL30 ",JSON.stringify(report));quit(0 if passed else 1)
func _run()->void:
	game=load("res://scenes/main_city.tscn").instantiate();root.add_child(game);current_scene=game
	var ready_until:int=Time.get_ticks_msec()+90000;var pop:RefCounted
	while Time.get_ticks_msec()<ready_until:
		await physics_frame
		pop=game.get("preview_population")
		if pop!=null and pop.city_ready and pop.daily!=null:break
	if not check("one_real_resident_ready",pop!=null and pop.city_ready and pop.hit_owners.size()==1 and pop.daily._lives.size()==1):finish();return
	var life:RefCounted=pop.daily._lives.get("resident_1");var body:CharacterBody3D=life._token.body
	var row:Dictionary=life._life();var initial_hp:float=float(row.hp)
	if not check("ordinary_low_hp_initial_condition",initial_hp>0 and initial_hp<float(row.max_hp)*.5):finish();return
	var probe:RefCounted=Physical.new();probe.configure(body)
	var at:Variant=probe.floor_at(START,START.y)
	if not check("initial_native_floor_and_capsule",at is Vector3 and probe.standing(at)):finish();return
	# This is a fixture initial condition, before the route/hospital being measured.
	body.global_position=at;body.velocity=Vector3.ZERO
	var before_completed:int=int(life._completed.hospital)
	if not check("real_daily_medical_begin",life._dsh_simple_begin(row)):finish();return
	var initial_route:RefCounted=life._dsh_simple
	check("far_inner_half_plane_is_not_inside",initial_route.depth_inside()>.55 and not initial_route._entered and not initial_route.needs_exit() and initial_route._legs.size()==4,{"depth":initial_route.depth_inside(),"distance_to_room":body.global_position.distance_to(initial_route._room),"legs":initial_route._legs.duplicate(),"bounds":initial_route._entry_bounds30})
	var registry:RefCounted=Registry.for_scene(game);var host:Node=game.preview_venue_staff29
	check("stationary_doctors_present",is_instance_valid(host) and host._rows.size()==12)
	var started:int=Time.get_ticks_msec();var last:int=-1000;var progress:=0.0;var previous:Vector3=body.global_position
	var previous_hp:float=initial_hp;var previous_service:=false;var completed:=false;var healed:=false;var violated:=false;var doorway_seen:=false
	while Time.get_ticks_msec()-started<210000:
		await physics_frame;await process_frame
		progress+=Vector2(body.global_position.x-previous.x,body.global_position.z-previous.z).length();previous=body.global_position
		var route:RefCounted=life._dsh_simple;var service:=false;var state:Dictionary={}
		if route!=null:
			state=route.snapshot()
			if route._leg>=1 and route._phase=="INBOUND":evidence["staging_passed"]={"position":body.global_position,"leg":route._leg,"ms":Time.get_ticks_msec()-started}
			if route._flat(body.global_position,route._door)<2.5:doorway_seen=true
			if route.is_inside():
				service=registry.service_owner29(route._key,route._venue,route)
				if service:
					var entry:Dictionary=registry.entry(route._venue);var staff:CharacterBody3D=host._rows[route._venue].actor
					evidence["staff_service"]={"position":body.global_position,"point":entry.service_point29,"distance":body.global_position.distance_to(entry.service_point29),"serving":staff.serving29,"customer_matches":registry.service_customer29(route._venue)==body,"ms":Time.get_ticks_msec()-started}
		var hp:float=float(life._life().hp)
		if hp>previous_hp:
			healed=true
			if not service and not previous_service:violated=true
		previous_hp=hp;previous_service=service
		completed=int(life._completed.hospital)>before_completed
		if Time.get_ticks_msec()-last>=1000 or completed:
			last=Time.get_ticks_msec()
			var sample:Dictionary={"ms":last-started,"position":body.global_position,"progress_m":progress,"hp":hp,"stage":life._hospital_stage,"completed":life._completed.hospital,"route":state,"service":service,"budget":Budget.diagnostics(),"native":Work.diagnostics(),"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT)}
			samples.append(sample);print("HOSPITAL30_SAMPLE ",JSON.stringify(sample))
		if completed:break
	check("physical_staging_door_heal_and_exit",completed and healed and doorway_seen and evidence.has("staging_passed") and evidence.has("staff_service") and progress>60.0 and float(life._life().hp)==float(life._life().max_hp),{"completed":completed,"healed":healed,"doorway_seen":doorway_seen,"progress_m":progress,"elapsed_ms":Time.get_ticks_msec()-started})
	check("healing_only_at_authoritative_staff_service",not violated and evidence.has("staff_service") and evidence.get("staff_service",{}).get("distance",INF)<=.42 and evidence.get("staff_service",{}).get("customer_matches",false))
	check("hospital_claims_released_after_real_exit",completed and registry.ledger.requests.is_empty() and registry._service29.keys.is_empty())
	for second in 12:
		await create_timer(1.0).timeout
		samples.append({"cleanup_second":second+1,"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"budget":Budget.diagnostics(),"native":Work.diagnostics(),"resident_count":pop.hit_owners.size()})
	check("one_resident_after_soak",pop.hit_owners.size()==1 and pop.daily._lives.size()==1)
	finish()
