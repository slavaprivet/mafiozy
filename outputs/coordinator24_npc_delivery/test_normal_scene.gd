extends SceneTree
## Root behavior observer. It never advances/replaces an owner or changes an
## actor, player, inventory, input, main flag, door, physics setting or transform.
## Optional QA camera changes only observation. This is NOT a performance test.
const IDS := ["resident_169", "resident_252", "resident_72"]
const VISITOR := "resident_169"
const MAX_PHYSICS_FRAMES := 11400 # 180 active scheduler seconds plus startup/release.
const SAMPLE_INTERVAL := 60
const MAX_SAMPLES := 240
const IMMUTABLE_PINS := {
	"res://assets/npc_visual/session/e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096.json":"e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096",
	"res://assets/npc_visual/session/prepared/manifest.json":"3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0",
	"res://assets/npc_visual/local_printshop/entry.v1.json":"3bda89bb0017b2d1ee5f5fca9c066d28a8e0f11a09670be43c771a027ce3518c",
	"res://assets/npc_visual/local_printshop/geometry.v1.json":"e1bcf7b5ba88008b17362aaedb1d0c094dd7cefd756ec0e7afec0923a2aad618"
}
const COMPILED_SCRIPTS := [
	"scripts/main.gd", "scripts/preview_player.gd", "scripts/preview_transport.gd",
	"scripts/preview_population.gd", "scripts/npc_preview_visits.gd",
	"scripts/npc_visual/preview_resident_host.gd", "scripts/npc_visual/npc_local_printshop_route.gd",
	"scripts/npc_visual/npc_local_printshop_visit.gd", "scripts/npc_visual/npc_local_printshop_source_floor.gd",
	"scripts/npc_visual/npc_local_printshop_contact_sweep.gd", "scripts/navigation/npc_swept_footprint.gd",
	"scripts/weapons/preview_weapons.gd", "scripts/npc_visual/npc_local_preview_hit_owner.gd"
]

class PhysicsObserver extends Node:
	var observe: Callable
	func _physics_process(delta: float) -> void:
		if observe.is_valid(): observe.call(delta)

var scene: Node3D
var population: RefCounted
var host: RefCounted
var visits: RefCounted
var observer: PhysicsObserver
var camera: Camera3D
var original_camera: Camera3D
var output := ""
var revision := "s01-20260930-quality24c"
var expected_sha := ""
var pins_path := ""
var source_root := ""
var pack_path := ""
var packed := false
var gpu := false
var expected_approach_legs := 0
var require_clearance_wait := false
var begun := 0
var done := false
var initialized := false
var first_frame := -1
var last_frame := -1
var observed_frames := 0
var completion_frame := -1
var completion_position := Vector3.ZERO
var completion_previous := Vector3.ZERO
var completion_floor := false
var completion_return_distance := INF
var post_completion_travel := 0.0
var last_phase_key := ""
var player_serial := -1
var transport_sequence := -1
var player_tick_receipts := 0
var transport_tick_receipts := 0
var latest_visit := {}
var actors := {}
var car: RigidBody3D
var car_start := Vector3.ZERO
var car_max_displacement := 0.0
var cargo_owner: Node
var cargo_initial := {}
var floor_recovery_count := 0
var floor_recoveries: Array[Dictionary] = []
var phases: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var captures_pending: Array[String] = []
var captures_requested := {}
var captures: Array[Dictionary] = []
var failures := {}
var report := {"checks":0,"errors":[],"scope":"Unmodified ordinary main, real physics ticks; three original residents, local printshop visit; no full-city, source-agenda or performance acceptance.","mutations":"Only output files and optional separate QA Camera3D; no actor/player transform, input, owner stepping or runtime flags."}

func _initialize() -> void:
	begun = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		elif arg.begins_with("--qa-out="): output=arg.trim_prefix("--qa-out=")
		elif arg.begins_with("--revision="): revision=arg.trim_prefix("--revision=")
		elif arg.begins_with("--expected-sha="): expected_sha=arg.trim_prefix("--expected-sha=")
		elif arg.begins_with("--expectedsha="): expected_sha=arg.trim_prefix("--expectedsha=")
		elif arg.begins_with("--pins="): pins_path=arg.trim_prefix("--pins=")
		elif arg.begins_with("--source-root="): source_root=arg.trim_prefix("--source-root=")
		elif arg.begins_with("--pack-path="): pack_path=arg.trim_prefix("--pack-path=")
		elif arg=="--pack": packed=true
		elif arg=="--gpu": gpu=true
		elif arg=="--require-clearance-wait": require_clearance_wait=true
	var arguments := OS.get_cmdline_args()
	for i: int in arguments.size():
		if arguments[i]=="--main-pack" and i+1<arguments.size(): pack_path=arguments[i+1]
		elif arguments[i].begins_with("--main-pack="): pack_path=arguments[i].trim_prefix("--main-pack=")
	run.call_deferred()

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec()-begun>180000:
		check(false,"180-second wall deadline"); finish()
	return false

func check(value: bool, label: String) -> bool:
	report.checks+=1
	if not value and not failures.has(label):
		failures[label]=true; report.errors.append(label); print("FAIL ",label)
	return value

func xyz(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

func json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: return null
	return parser.data

func check_pin(path: String, sha: String, label: String) -> void:
	if check(FileAccess.file_exists(path),"pinned file exists: "+label):
		check(FileAccess.get_sha256(path)==sha,"exact file SHA: "+label)

func verify_inputs() -> void:
	for path: String in IMMUTABLE_PINS: check_pin(path,IMMUTABLE_PINS[path],path)
	report.immutable_data_pins=IMMUTABLE_PINS
	if packed:
		if check(not pack_path.is_empty() and FileAccess.file_exists(pack_path),"actual main-pack path supplied"):
			report.pack_sha256=FileAccess.get_sha256(pack_path)
			if not expected_sha.is_empty(): check(report.pack_sha256==expected_sha,"expected compiled PCK SHA")
		var compiled := {}
		for path: String in COMPILED_SCRIPTS:
			var script: Script=load("res://"+path)
			compiled[path]=script!=null and not script.has_source_code()
			check(compiled[path],"compiled script has no source: "+path)
		report.compiled_scripts=compiled
	elif not expected_sha.is_empty():
		check_pin("res://scripts/main.gd",expected_sha,"expected source main SHA")
	if not pins_path.is_empty():
		var data: Variant=json_file(pins_path)
		if not check(data is Dictionary,"root source freeze manifest parses"): return
		report.pins_manifest_sha256=FileAccess.get_sha256(pins_path)
		var files: Dictionary={}
		if data.get("inputs") is Array:
			for row: Dictionary in data.inputs: files[str(row.path)]=str(row.sha256)
		elif data.get("files") is Dictionary: files=data.files
		else: check(false,"pins manifest needs inputs[] or files{path:sha}"); return
		check(not files.is_empty(),"nonempty root freeze manifest")
		var checked := 0; var packed_remaps: Array[String]=[]
		for relative: String in files:
			var local: String=relative.trim_prefix("res://")
			var path: String=source_root.path_join(local) if not source_root.is_empty() else "res://"+local
			if packed and source_root.is_empty() and local.get_extension() in ["gd","tscn"]:
				packed_remaps.append(local); continue
			check_pin(path,str(files[relative]),relative); checked+=1
		report.freeze_files_checked=checked
		report.freeze_compiled_remaps=packed_remaps
		report.freeze_note="Compiled scripts/scenes are bound by whole PCK SHA; external source-root enables all source receipt pins."

func run() -> void:
	if not check(not output.is_empty(),"output directory argument required"): finish(); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: check(false,"output directory available"); finish(); return
	check(not gpu or DisplayServer.get_name()!="headless","GPU flag requires rendered renderer")
	verify_inputs()
	if not report.errors.is_empty(): finish(); return
	var approach: Variant=json_file("res://assets/npc_visual/local_printshop/approach.v1.json")
	if not check(approach is Dictionary and approach.get("path") is Array,"declared ordinary approach path parses"): finish(); return
	expected_approach_legs=approach.path.size()
	check(expected_approach_legs>=1 and expected_approach_legs<=64 and int(approach.get("leg_count",expected_approach_legs))==expected_approach_legs,"bounded declared ordinary approach leg count")
	report.approach={"sha256":FileAccess.get_sha256("res://assets/npc_visual/local_printshop/approach.v1.json"),"declared_legs":expected_approach_legs,"proposal_provenance":approach.get("proposal_provenance",{}),"reroute":approach.get("reroute",{})}
	var notes: Variant=json_file("res://data/preview_updates.json")
	check(notes is Dictionary and notes.get("runtime_revision")==revision,"notes expected runtime revision")
	check(notes is Dictionary and notes.get("items") is Array and notes.items.size()==5,"five current update notes")
	scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	# Observe after ordinary priority-zero owners. No owner is stepped here.
	observer=PhysicsObserver.new(); observer.name="RootNormalSceneObserver"
	observer.process_priority=100; observer.process_physics_priority=100
	observer.observe=Callable(self,"observe_physics"); root.add_child(observer)
	for startup: int in 600:
		await physics_frame; await process_frame
		if done: return
		if initialized: break
	if not check(initialized,"normal main startup within 600 physics frames"): finish(); return
	while not done and observed_frames<MAX_PHYSICS_FRAMES:
		await physics_frame; await process_frame
		if done: return
		if gpu and not captures_pending.is_empty(): await capture_frame(captures_pending.pop_front())
		if latest_visit.get("phase")=="HOLD": check(false,"normal scheduler HOLD: "+str(latest_visit.get("reason"))); break
		# A short real continuation proves no second visit and no released-owner stall.
		if completion_frame>=0 and last_frame-completion_frame>=180: break
	final_checks()
	if gpu:
		while not captures_pending.is_empty() and not done: await capture_frame(captures_pending.pop_front())
	finish()

func initialize_observation() -> bool:
	if not scene.preview_ready or scene.population_status!="ready" or scene.transport_status!="ready": return false
	population=scene.preview_population; host=population.residents; visits=population.get("_visits")
	if not check(visits!=null and visits.has_method("snapshot"),"ordinary population owns visit scheduler"): return false
	check(scene.PREVIEW_RUNTIME_REVISION==revision,"main expected runtime revision")
	check(scene.preview_transport_enabled and scene.preview_residents_enabled and scene.preview_weapons_enabled and scene.preview_resident_walk_enabled,"ordinary main feature flags enabled")
	check(scene.is_physics_processing() and scene.is_processing(),"ordinary main processes enabled")
	check(is_instance_valid(scene._player) and scene._player.is_physics_processing(),"original player physics enabled")
	check(scene.preview_transport.ready_for_play and scene.preview_transport.is_physics_processing(),"original transport physics enabled")
	car=scene.preview_transport.body; car_start=car.global_position
	cargo_owner=scene.preview_weapons.get_node_or_null("WeaponCargo")
	check(is_instance_valid(cargo_owner) and cargo_owner._ready_for_play,"ordinary cargo owner remains configured")
	if is_instance_valid(cargo_owner):
		cargo_initial=cargo_owner.cargo.snapshot(cargo_owner.generation)
		check(cargo_initial.get("ok",false) and not cargo_initial.get("destroyed",true),"original cargo lifetime current")
	report.original_car={"instance_id":car.get_instance_id(),"vehicle_id":car.get_meta("vehicle_id"),"life_generation":car.get_meta("life_generation"),"profile_id":car.get_meta("profile_id"),"start":xyz(car_start),"collision_layer":car.collision_layer,"collision_mask":car.collision_mask,"cargo":cargo_initial}
	check(population.hit_owners.size()==3 and population.occupants().size()==3,"three original NPC and hit owners")
	check(population.snapshot().get("local_visit_setup",{}).get("ok",false),"ordinary local visit setup admitted")
	var ids: Array=host._records.keys(); ids.sort(); check(ids==IDS,"exact original three resident IDs")
	var weapons: Node=scene.preview_weapons
	var guns: Array=weapons.inventory.get_owned_ids(); guns.sort()
	var expected_guns: Array=load("res://scripts/weapons/weapon_fire.gd").ids(); expected_guns.sort()
	check(guns.size()==14 and guns==expected_guns and scene.weapons_status=="local_arsenal","all fourteen original guns")
	var weapon_uids := {}
	for gun: String in guns: weapon_uids[gun]=weapons.inventory.get_item_uid(gun)
	report.weapon_uids=weapon_uids
	check(int(scene._block.counts.buildings)==8,"eight original buildings")
	check(scene.find_children("*","CollisionObject3D",true,false).size()==377,"377 original collision bodies")
	check(scene.find_children("*","CollisionShape3D",true,false).size()==377,"377 original collision shapes")
	for id: String in IDS:
		if not check(host._records.has(id),"original host record: "+id): continue
		var record: Dictionary=host._records[id]
		var token: Dictionary=host.target_from_collider(record.body)
		check(token.get("ok",false),"original current body/rig/life: "+id)
		actors[id]={"body":record.body,"token":token,"row":JSON.stringify(record.row,"",true,true),"row_sha256":JSON.stringify(record.row,"",true,true).sha256_text(),"start":record.body.global_position,"previous":record.body.global_position,"travel":0.0,"max_step":0.0,"moving_frames":0,"floor_frames":0,"min_y":record.body.global_position.y,"max_y":record.body.global_position.y}
	first_frame=Engine.get_physics_frames(); last_frame=first_frame-1
	player_serial=int(scene._player._ground_move_serial); transport_sequence=int(scene.preview_transport._sequence)
	report.initial={"main_instance":scene.get_instance_id(),"population_instance":population.get_instance_id(),"host_instance":host.get_instance_id(),"player_instance":scene._player.get_instance_id(),"transport_instance":scene.preview_transport.get_instance_id(),"guns":guns,"revision":scene.PREVIEW_RUNTIME_REVISION}
	if gpu:
		original_camera=root.get_camera_3d(); camera=Camera3D.new(); camera.name="RootQAObserverCamera"
		root.add_child(camera); camera.fov=52.0; camera.far=200.0; camera.make_current()
	initialized=true
	return true

func observe_physics(_delta: float) -> void:
	if done or observed_frames>=MAX_PHYSICS_FRAMES: return
	if not initialized and not initialize_observation(): return
	var frame: int=Engine.get_physics_frames()
	if not check(frame==last_frame+1,"one observer per consecutive physics frame"): return
	last_frame=frame; observed_frames+=1
	check(scene.preview_population==population and population.residents==host and population.get("_visits")==visits,"same normal population/host/scheduler")
	check(scene._player.get_instance_id()==report.initial.player_instance and scene.preview_transport.get_instance_id()==report.initial.transport_instance,"same player and transport instances")
	var ground: Dictionary=scene._player.completed_ground_move_receipt()
	if ground.get("frame")==frame: player_tick_receipts+=1
	check(not ground.is_empty(),"player completed real ground move in observed physics tick")
	var sequence: int=scene.preview_transport._sequence
	if observed_frames>1:
		if sequence==transport_sequence+1: transport_tick_receipts+=1
		check(sequence==transport_sequence+1,"transport advanced exactly once per physics tick")
	transport_sequence=sequence
	check(not scene.preview_physics_fault and scene.preview_transport.phase=="ON_FOOT","player and transport remain healthy on-foot")
	check(is_instance_valid(car) and scene.preview_transport.body==car and car.get_instance_id()==int(report.original_car.instance_id),"same original parked car throughout visit")
	car_max_displacement=maxf(car_max_displacement,car.global_position.distance_to(car_start))
	check(car.collision_layer==int(report.original_car.collision_layer) and car.collision_mask==int(report.original_car.collision_mask) and car_max_displacement<1.0,"original parked car collision retained within one metre of its initial parking")
	for id: String in actors:
		var item: Dictionary=actors[id]; var body: CharacterBody3D=item.body
		if not check(is_instance_valid(body),"original actor remains alive: "+id): continue
		var position: Vector3=body.global_position; var movement: float=position.distance_to(item.previous)
		item.travel+=movement; item.max_step=maxf(item.max_step,movement); item.previous=position
		item.min_y=minf(item.min_y,position.y); item.max_y=maxf(item.max_y,position.y)
		if movement>.0001: item.moving_frames+=1
		if body.is_on_floor(): item.floor_frames+=1
		check(movement<.12,"no actor teleport above .12m in one real tick: "+id)
		if observed_frames%SAMPLE_INTERVAL==0:
			check(host.target_current(item.token),"same original ID/body/rig/life: "+id)
			check(JSON.stringify(host._records[id].row,"",true,true)==item.row,"immutable original source row: "+id)
	latest_visit=visits.snapshot()
	var recovery_count: int=int(host._stats.get("floor_recoveries",0))
	if recovery_count>floor_recovery_count:
		floor_recovery_count=recovery_count
		var recovered: Dictionary=host._stats.get("last_floor_recovery",{}).duplicate(true)
		for key: String in ["before","correction","after_native","after_snap"]:
			if recovered.get(key) is Vector3:recovered[key]=xyz(recovered[key])
		if floor_recoveries.size()<32:floor_recoveries.append(recovered)
	if latest_visit.get("phase")=="WAIT_FOR_CLEARANCE":
		check(int(latest_visit.get("request_id",0))<0,"clearance wait has no active scheduler request")
		var current_record: Dictionary=host._records[VISITOR]
		check(current_record.status not in ["PENDING","READY"],"public cancellation leaves no active owner movement during clearance wait")
		for wait_record: Dictionary in latest_visit.get("clearance",{}).get("history",[]):
			check(float(wait_record.until)-float(wait_record.at)<=10.00001,"clearance waiting is bounded to ten active seconds per leg")
	var key: String=str(latest_visit.get("phase"))+":"+str(latest_visit.get("reason"))
	if key!=last_phase_key:
		last_phase_key=key
		if phases.size()<128: phases.append(sample(true))
		if latest_visit.get("reason")=="native_request_refused": diagnose_refused_approach()
		queue_capture(str(latest_visit.get("reason")) if latest_visit.get("phase")=="VISIT" else str(latest_visit.get("phase")))
	if observed_frames%SAMPLE_INTERVAL==0 and samples.size()<MAX_SAMPLES: samples.append(sample(false))
	if OS.get_cmdline_user_args().has("--trace-252") and observed_frames%60==0:
		if not report.has("resident252_motion_trace"):report["resident252_motion_trace"]=[]
		if report.resident252_motion_trace.size()<180:report.resident252_motion_trace.append(actor_motion_trace("resident_252"))
	if latest_visit.get("phase")=="COMPLETE" and completion_frame<0:
		completion_frame=frame; completion_position=actors[VISITOR].body.global_position
		completion_previous=completion_position; completion_floor=actors[VISITOR].body.is_on_floor()
		var legs: Array=latest_visit.get("legs",[])
		if not legs.is_empty():
			var arrival: Variant=legs[-1].get("arrival")
			if arrival is Array and arrival.size()==3:
				completion_return_distance=Vector2(completion_position.x-float(arrival[0]),completion_position.z-float(arrival[2])).length()
	elif completion_frame>=0:
		var position: Vector3=actors[VISITOR].body.global_position
		post_completion_travel+=position.distance_to(completion_previous); completion_previous=position
		check(latest_visit.get("phase")=="COMPLETE" and int(latest_visit.get("visit",{}).get("local_completed",0))==1,"no second local visit after release")
	if camera!=null and actors.has(VISITOR):
		var target: Vector3=actors[VISITOR].body.global_position+Vector3(0,1.0,0)
		camera.global_position=target+Vector3(5.0,3.3,5.0); camera.look_at(target,Vector3.UP)

func sample(include_reason: bool) -> Dictionary:
	var positions := {}
	for id: String in actors: positions[id]=xyz(actors[id].body.global_position)
	return {"physics_frame":last_frame,"observed_frame":observed_frames,"phase":latest_visit.get("phase"),"reason":latest_visit.get("reason") if include_reason else "","leg":latest_visit.get("leg"),"visit_phase":latest_visit.get("visit",{}).get("phase"),"positions":positions,"door_fraction":scene._printshop.door_fraction("public"),"player_position":xyz(scene._player.global_position),"transport_sequence":scene.preview_transport._sequence}

func collider_receipt(value: Variant) -> Dictionary:
	if not value is CollisionObject3D: return {"class":value.get_class() if value is Object else "none"}
	var body: CollisionObject3D=value
	var metadata := {}
	for key: StringName in body.get_meta_list():
		var item: Variant=body.get_meta(key)
		if item is String or item is int or item is bool or item is float: metadata[str(key)]=item
	return {"path":str(body.get_path()),"class":body.get_class(),"instance_id":body.get_instance_id(),"layer":body.collision_layer,"mask":body.collision_mask,"position":xyz(body.global_position),"metadata":metadata}

func actor_motion_trace(id: String) -> Dictionary:
	# Observer-only inspection; no owner/native step, transforms or motion writes.
	var record: Dictionary=host._records[id]
	var body: CharacterBody3D=record.body
	var nav: RefCounted=population.navigation
	var request: int=int(record.request)
	var native_record: Dictionary=nav._records.get(request,{})
	var pause: Callable=record.get("walk_pause",Callable())
	var result: Dictionary={"physics_frame":last_frame,"active_seconds":latest_visit.get("active_seconds"),"position":xyz(body.global_position),"velocity":xyz(body.velocity),"floor":body.is_on_floor(),"floor_normal":xyz(body.get_floor_normal()),"status":record.status,"request":request,"walk_pause":pause.is_valid() and bool(pause.call()),"walk_preview":host._walk_preview.get(id,{}).duplicate(true),"source_at_current":population.policy.source_admit(body.global_position,id,int(record.generation),host.FOOTPRINT,"route"),"slide_collisions":[]}
	if not native_record.is_empty():
		var path: Array=[]
		for point: Vector3 in native_record.path:path.append(xyz(point))
		result["native"]={"status":native_record.status,"reason":native_record.reason,"target":xyz(native_record.target),"path":path,"edge":native_record.edge,"source_at_target":population.policy.source_admit(native_record.target,id,int(record.generation),host.FOOTPRINT,"target")}
	for index: int in body.get_slide_collision_count():
		var hit: KinematicCollision3D=body.get_slide_collision(index)
		result.slide_collisions.append({"normal":xyz(hit.get_normal()),"position":xyz(hit.get_position()),"travel":xyz(hit.get_travel()),"collider":collider_receipt(hit.get_collider())})
	var space: PhysicsDirectSpaceState3D=scene.get_world_3d().direct_space_state
	var excluded: Array[RID]=[body.get_rid()]
	var ray:=PhysicsRayQueryParameters3D.new();ray.exclude=excluded;ray.collision_mask=1
	var floors: Array=[]
	for offset: Vector2 in host.SUPPORT_OFFSETS:
		var point: Vector3=body.global_position+Vector3(offset.x,0,offset.y)
		ray.from=point+Vector3.UP*.30;ray.to=point-Vector3.UP*.30
		var hit: Dictionary=space.intersect_ray(ray)
		if hit.is_empty():floors.append({"offset":[offset.x,offset.y],"hit":false})
		else:floors.append({"offset":[offset.x,offset.y],"normal":xyz(hit.normal),"position":xyz(hit.position),"collider":collider_receipt(hit.collider)})
	result["floor_rays"]=floors
	var square:=BoxShape3D.new();square.size=Vector3(host.FOOTPRINT*2,host.HEIGHT,host.FOOTPRINT*2)
	var query:=PhysicsShapeQueryParameters3D.new();query.exclude=excluded;query.margin=.001;query.collision_mask=1|256;query.shape=square
	query.transform=Transform3D(Basis.IDENTITY,body.global_position+Vector3.UP*(host.HEIGHT*.5+.025))
	var overlaps: Array=[]
	for hit: Dictionary in space.intersect_shape(query,16):overlaps.append(collider_receipt(hit.collider))
	result["owner_square_overlaps"]=overlaps
	var capsule:=CapsuleShape3D.new();capsule.radius=.36;capsule.height=1.9
	query.shape=capsule;query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,body.global_position+Vector3.UP*(1.9*.5+.04))
	var native_overlaps: Array=[]
	for hit: Dictionary in space.intersect_shape(query,16):native_overlaps.append(collider_receipt(hit.collider))
	result["native_capsule_overlaps"]=native_overlaps
	if record.status in ["BLOCKED","NO_PATH"]:
		var before: Transform3D=body.global_transform
		var recovery:=KinematicCollision3D.new()
		var collision: bool=body.test_move(before,Vector3.ZERO,recovery,body.safe_margin,true)
		var travel: Vector3=recovery.get_travel() if collision else Vector3.ZERO
		result["zero_motion_recovery_query"]={"collision":collision,"travel":xyz(travel),"normal":xyz(recovery.get_normal()) if collision else [],"collider":collider_receipt(recovery.get_collider()) if collision else {},"safe_margin":body.safe_margin,"source_at_recovered":population.policy.source_admit(before.origin+travel,id,int(record.generation),host.FOOTPRINT,"route"),"vertical_correction_within_owner_limit":travel.y>=0 and travel.y<=.05 and Vector2(travel.x,travel.z).length()<=.0001,"body_transform_unchanged":body.global_transform==before}
	return result

func diagnose_refused_approach() -> void:
	# Read-only observer queries duplicate the owner's unchanged footprint.
	# They neither call request/step nor mutate any body or navigation record.
	var data: Variant=json_file("res://assets/npc_visual/local_printshop/approach.v1.json")
	var leg: int=int(latest_visit.get("leg",-1))
	if not data is Dictionary or leg<0 or leg>=data.path.size(): return
	var coordinates: Array=data.path[leg]
	var target:=Vector3(coordinates[0],coordinates[1],coordinates[2])
	var record: Dictionary=host._records[VISITOR]
	var body: CharacterBody3D=record.body
	var space: PhysicsDirectSpaceState3D=scene.get_world_3d().direct_space_state
	var excluded: Array[RID]=[body.get_rid()]
	var ray:=PhysicsRayQueryParameters3D.new(); ray.collision_mask=1; ray.exclude=excluded
	var supports: Array[Dictionary]=[]
	for offset: Vector2 in host.SUPPORT_OFFSETS:
		var point: Vector3=target+Vector3(offset.x,0,offset.y)
		ray.from=point+Vector3.UP*.30; ray.to=point-Vector3.UP*.30
		var hit: Dictionary=space.intersect_ray(ray)
		var receipt: Dictionary={"offset":[offset.x,offset.y],"hit":not hit.is_empty()}
		if not hit.is_empty():
			receipt["normal"]=xyz(hit.normal); receipt["position"]=xyz(hit.position)
			receipt["support_ok"]=hit.normal.y>=.70 and absf(hit.position.y-target.y)<=.18
			receipt["collider"]=collider_receipt(hit.collider)
		supports.append(receipt)
	var box:=BoxShape3D.new(); box.size=Vector3(host.FOOTPRINT*2,host.HEIGHT,host.FOOTPRINT*2)
	var overlap:=PhysicsShapeQueryParameters3D.new(); overlap.shape=box; overlap.collision_mask=1|256
	overlap.margin=.001; overlap.exclude=excluded
	overlap.transform=Transform3D(Basis.IDENTITY,target+Vector3.UP*(host.HEIGHT*.5+.025))
	var collisions: Array[Dictionary]=[]
	for hit: Dictionary in space.intersect_shape(overlap,32): collisions.append(collider_receipt(hit.collider))
	var navigation: RefCounted=population.navigation
	var receipt: Dictionary={"physics_frame":last_frame,"phase":latest_visit.get("phase"),"leg":leg,"target":xyz(target),"actor":xyz(body.global_position),"distance_m":body.global_position.distance_to(target),"source_admits":host._source_admits(target,record,"target"),"host_busy":host._busy,"host_disposed":host._disposed,"physical_failed":record.get("physical_failed",false),"physical_occupied":host._physical_occupied(VISITOR),"owner_dead":record.owner.dead,"record_status":record.status,"request":record.request,"body_layer":body.collision_layer,"body_mask":body.collision_mask,"navigation_body_supported":navigation._body_supported(body),"navigation_state":navigation.state(),"navigation_busy":navigation._busy,"navigation_geometry_valid":navigation._geometry_valid,"navigation_transitions":navigation._transitions.size(),"supports":supports,"overlap_colliders":collisions}
	if not report.has("refused_approach_diagnostics"): report["refused_approach_diagnostics"]=[]
	report.refused_approach_diagnostics.append(receipt)
	if OS.get_cmdline_user_args().has("--plan-detour") and not report.has("detour_plan"):
		report["detour_plan"]=plan_ordinary_detour(data,body)

func detour_point_clear(point: Vector3, body: CharacterBody3D) -> bool:
	var excluded: Array[RID]=[body.get_rid()]
	return population.policy.source_admit(point,VISITOR,int(host._records[VISITOR].generation),host.FOOTPRINT,"route") and host._physical_clear(point,excluded)

func plan_ordinary_detour(data: Dictionary, body: CharacterBody3D) -> Dictionary:
	# Diagnostic planning only. No request, movement, owner step or frame advance.
	# The separate full observer must later prove every accepted leg physically.
	var began_usec: int=Time.get_ticks_usec()
	var start_frame: int=Engine.get_physics_frames()
	var start: Vector3=body.global_position; start.y=0.0
	var old_goal: Array=data.path[6]
	var goal:=Vector3(old_goal[0],0,old_goal[2])
	var wanted:=Vector2(goal.x-start.x,goal.z-start.z)
	var nodes: Dictionary={Vector2i.ZERO:{"parent":null,"g":0.0}}
	var open: Array[Vector2i]=[Vector2i.ZERO]
	var closed: Dictionary={}; var cache: Dictionary={}
	var found: Variant=null; var expanded: int=0; var query_count: int=0
	while not open.is_empty() and expanded<1024 and Time.get_ticks_usec()-began_usec<5000000:
		var best: int=0; var cost: float=INF
		for i: int in open.size():
			var estimate: float=float(nodes[open[i]].g)+Vector2(open[i]).distance_to(wanted)
			if estimate<cost: best=i; cost=estimate
		var key: Vector2i=open[best]; open.remove_at(best); closed[key]=true; expanded+=1
		var point: Vector3=start+Vector3(key.x,0,key.y)
		if point.distance_to(goal)<.01: found=key; break
		for offset: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i=key+offset
			if closed.has(next) or next.x < -12 or next.x>8 or next.y < -20 or next.y>5: continue
			var to: Vector3=start+Vector3(next.x,0,next.y)
			if not cache.has(next): cache[next]=detour_point_clear(to,body); query_count+=1
			if not cache[next]: continue
			var clear: bool=true
			for alpha: float in [.25,.5,.75]:
				query_count+=1
				if not detour_point_clear(point.lerp(to,alpha),body): clear=false; break
			if not clear: continue
			var distance: float=float(nodes[key].g)+1.0
			if nodes.has(next) and distance>=float(nodes[next].g): continue
			nodes[next]={"parent":key,"g":distance}
			if next not in open: open.append(next)
	var path: Array[Vector3]=[]
	if found!=null:
		var reverse: Array[Vector3]=[]
		while found!=Vector2i.ZERO:
			reverse.append(start+Vector3(found.x,0,found.y)); found=nodes[found].parent
		reverse.reverse()
		for point: Vector3 in reverse:
			if path.size()>1:
				var a: Vector3=path[-1]-path[-2]; var b: Vector3=point-path[-1]
				if a.normalized().is_equal_approx(b.normalized()) and path[-2].distance_to(point)<6.5: path[-1]=point; continue
			path.append(point)
	var encoded: Array=[]
	for point: Vector3 in path: encoded.append(xyz(point))
	return {"status":"PROPOSAL_NEEDS_COMPLETE_NATIVE_VISIT" if not path.is_empty() else "NO_PLAN","original_data_sha256":FileAccess.get_sha256("res://assets/npc_visual/local_printshop/approach.v1.json"),"replace_first_old_points":7,"original_start":xyz(start),"goal":xyz(goal),"prefix":encoded,"expanded":expanded,"queries":query_count,"microseconds":Time.get_ticks_usec()-began_usec,"same_physics_frame":Engine.get_physics_frames()==start_frame,"actor_position_unchanged":body.global_position.is_equal_approx(Vector3(start.x,body.global_position.y,start.z)),"physics_frame":start_frame,"bounds":{"expansions":1024,"wall_usec":5000000,"x":[-12,8],"z":[-20,5]},"admission":"unchanged source policy and owner square footprint supports+overlap, quarter-metre edge samples","scene":"ordinary main, transport/player/three original residents active; no flags or transforms changed"}

func queue_capture(label: String) -> void:
	if not gpu or label not in ["START_DELAY","APPROACH","WALK_TO_ENTRY","OPENING","ENTERING","BROWSING","EXITING","RETURNING_TO_STREET","COMPLETE"] or captures_requested.has(label): return
	captures_requested[label]=true; captures_pending.append(label)

func capture_frame(label: String) -> void:
	await RenderingServer.frame_post_draw
	if done: return
	var image: Image=root.get_texture().get_image()
	var name: String="stage_%02d_%s.png"%[captures.size(),label.to_lower()]
	var result: Error=image.save_png(output.path_join(name))
	check(result==OK,"saved rendered QA frame: "+label)
	# Record actual capture state separately; the requested transition may have advanced.
	captures.append({"requested_stage":label,"file":name,"actual":sample(true),"capture_engine_physics_frame":Engine.get_physics_frames(),"width":image.get_width(),"height":image.get_height()})

func final_checks() -> void:
	if not initialized: return
	check(observed_frames<=MAX_PHYSICS_FRAMES,"observer respects declared 11400-frame bound")
	check(completion_frame>=0 and latest_visit.get("phase")=="COMPLETE","normal visit completes within bounded physics frames")
	check(int(latest_visit.get("leg",-1))==expected_approach_legs and int(latest_visit.get("leg_count",-1))==expected_approach_legs,"all declared ordinary approach legs completed")
	var completed := {}
	for leg: Dictionary in latest_visit.get("legs",[]):
		if leg.get("status")=="ARRIVED": completed[int(leg.leg)]=true
	check(completed.size()==expected_approach_legs,"every declared leg has a physical ARRIVED route receipt")
	var seen := {}
	for phase: Dictionary in phases:
		seen[str(phase.phase)]=true; seen[str(phase.visit_phase)]=true
	for phase: String in ["APPROACH","WALK_TO_ENTRY","OPENING","ENTERING","BROWSING","EXITING","RETURNING_TO_STREET","COMPLETE"]: check(seen.has(phase),"observed ordinary phase: "+phase)
	if require_clearance_wait:
		check(seen.has("WAIT_FOR_CLEARANCE") and int(latest_visit.get("clearance",{}).get("polls",0))>0,"actual original NPC obstruction exercised bounded clearance wait")
	if OS.get_cmdline_user_args().has("--require-floor-recovery"):
		var recovered252: bool=false
		for receipt: Dictionary in floor_recoveries:
			if receipt.get("source_id")=="resident_252" and receipt.get("floor_only_no_path",false):
				recovered252=true
				check(absf(float(receipt.after_native[1])-float(receipt.after_snap[1]))<.002,"floor snap preserves actual native recovery height")
				check(float(receipt.after_snap[1])-float(receipt.before[1])>.02,"actual 252 native floor recovery resolves measured intrusion")
		check(recovered252,"actual original252 NO_PATH floor-only recovery exercised")
	check(int(latest_visit.get("visit",{}).get("local_completed",0))==1,"exactly one local visit completed")
	check(not latest_visit.get("lease_bound",true) and latest_visit.get("release",{}).get("ok",false),"public visit lease released")
	check(completion_floor and completion_return_distance<=.12,"visitor physically returns to last arrived street position")
	check(last_frame-completion_frame>=180 and post_completion_travel>.1,"ordinary walking resumes after release for 180 real ticks")
	check(not latest_visit.get("source_authority",true) and not latest_visit.get("original_source_progress_written",true),"local visit does not claim source progress")
	check(int(latest_visit.get("duplicate_step_calls_ignored",-1))==0,"scheduler receives one real tick")
	check(int(latest_visit.get("invalid_deltas_ignored",-1))==0,"scheduler has valid deltas")
	check(int(latest_visit.get("request_frame_limit_hits",-1))==0,"no duplicate per-frame route request")
	check(player_tick_receipts==observed_frames,"player physically processed throughout visit")
	check(transport_tick_receipts==maxi(0,observed_frames-1),"transport processed throughout visit")
	for gun: String in report.weapon_uids:
		check(scene.preview_weapons.inventory.get_item_uid(gun)==report.weapon_uids[gun],"same original weapon UID: "+gun)
	for id: String in actors:
		var item: Dictionary=actors[id]
		check(host.target_current(item.token),"final same ID/body/rig/life: "+id)
		check(JSON.stringify(host._records[id].row,"",true,true)==item.row,"final immutable source row: "+id)
		check(item.travel>(60.0 if id==VISITOR else .5),"ordinary movement remains active: "+id)
		if id==VISITOR: check(item.max_y>.38,"visitor physically reaches interior floor")
	check(scene.find_children("*","CollisionObject3D",true,false).size()==377 and scene.find_children("*","CollisionShape3D",true,false).size()==377,"collision body and shape population preserved")
	check(car.get_meta("vehicle_id")==report.original_car.vehicle_id and car.get_meta("life_generation")==report.original_car.life_generation and car.get_meta("profile_id")==report.original_car.profile_id,"same original car ID/life/profile")
	var cargo_final: Dictionary=cargo_owner.cargo.snapshot(cargo_owner.generation)
	check(JSON.stringify(cargo_final,"",true,true)==JSON.stringify(cargo_initial,"",true,true),"cargo contents/revision/life unchanged by ordinary NPC visit")
	report.final_car={"position":xyz(car.global_position),"max_displacement_m":car_max_displacement,"cargo":cargo_final}
	report.final_population=population.snapshot()

func finish() -> void:
	if done: return
	done=true
	if observer!=null: observer.set_physics_process(false)
	var results := {}
	for id: String in actors:
		var item: Dictionary=actors[id]; var token: Dictionary=item.token
		results[id]={"row_sha256":item.row_sha256,"bridge_id":token.get("bridge_id"),"life_generation":token.get("life_generation"),"body_instance_id":token.get("body_instance_id"),"rig_instance_id":token.get("rig_instance_id"),"start":xyz(item.start),"end":xyz(item.previous),"travel_m":item.travel,"max_step_m":item.max_step,"moving_frames":item.moving_frames,"floor_frames":item.floor_frames,"min_y":item.min_y,"max_y":item.max_y}
	report.actors=results; report.phases=phases; report.samples=samples; report.captures=captures
	report.floor_recovery_count=floor_recovery_count;report.floor_recovery_receipts=floor_recoveries
	report.visit=latest_visit; report.observed_physics_frames=observed_frames; report.first_physics_frame=first_frame; report.last_physics_frame=last_frame
	report.player_tick_receipts=player_tick_receipts; report.transport_tick_receipts=transport_tick_receipts
	report.completion_position=xyz(completion_position); report.completion_floor=completion_floor
	report.completion_return_distance_m=completion_return_distance if is_finite(completion_return_distance) else -1.0
	report.post_completion_travel_m=post_completion_travel; report.post_completion_frames=maxi(0,last_frame-completion_frame) if completion_frame>=0 else 0
	report.rendered=gpu; report.packed=packed; report.seconds=(Time.get_ticks_msec()-begun)/1000.0
	report.valid=report.errors.is_empty(); report.harness_sha256=FileAccess.get_sha256(get_script().resource_path)
	if not output.is_empty():
		var file:=FileAccess.open(output.path_join("RESULT.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"\t",true,true)+"\n"); file.close()
	print("NORMAL_SCENE24 ",JSON.stringify({"valid":report.valid,"checks":report.checks,"errors":report.errors,"frames":observed_frames,"phase":latest_visit.get("phase"),"actors":results,"seconds":report.seconds}))
	if is_instance_valid(original_camera): original_camera.make_current()
	if is_instance_valid(camera): camera.queue_free()
	if is_instance_valid(scene): scene.queue_free()
	quit.call_deferred(0 if report.valid else 1)
