extends "test_c4.gd"
## QA47 overlay of frozen owner206eb: identical native workload, minimum frame windows.
## --charges=1|8 --variant=baseline|candidate --qa-manifest=<staged manifest>
## One fresh process per case. GPU only; no fixed FPS, fake place/damage, J or K.
const Perf45=preload("c4_perf_observer45.gd")
const SOFT_DEADLINE_USEC:=56000000
const MAX_SAMPLES_PER_PHASE:=12000
var requested_charges:=0
var variant45:=""
var manifest45:=""
var phase45:="startup"
var authored45: Dictionary={}
var authored_site45:=0
var holds45: Array[Dictionary]=[]
var measuring_hold45:=false
var hold_old_count45:=0
var first_new_frame45:=-1
var actual_initial_position45:=Vector3.ZERO
var hold_drift45:=0.0
var phase_records45: Array[Dictionary]=[]
var blast_owner45: Node
var tracked_fragments45: Dictionary={}
var fragment_events_seen45:=0
var fragment_samples45: Array[Dictionary]=[]
var stable_since_frame45:=-1
var warmup_frames47: int=0

func recovery_stable45() -> bool:
	var support: Dictionary=site._structure.diagnostics()
	var effects_done: bool=variant45!="candidate" or blast_owner45._fx45._active==0
	var stable: bool=effects_done and blast_owner45._pending.is_empty() and blast_owner45._events.size()==requested_charges and support.get("ok",false) and not support.get("busy",true) and support.get("pending",-1)==0 and support.get("state","")=="stable"
	if not stable: stable_since_frame45=-1
	elif stable_since_frame45<0: stable_since_frame45=Engine.get_physics_frames()
	return stable and Engine.get_physics_frames()-stable_since_frame45>=30

func _process(delta: float) -> bool:
	super._process(delta)
	if finished: return false
	if started_usec>0 and Time.get_ticks_usec()-started_usec>SOFT_DEADLINE_USEC:
		evidence.completion47="INCOMPLETE"
		check(false,"INCOMPLETE: unchanged 56-second wall-clock watchdog during "+phase45); finish(); return false
	if measuring_hold45 and is_instance_valid(equipment):
		hold_drift45=maxf(hold_drift45,player.global_position.distance_to(actual_initial_position45))
		if first_new_frame45<0 and equipment._charges.size()>hold_old_count45: first_new_frame45=Engine.get_physics_frames()
	return false

func observe_site45(node: Node) -> void:
	var script: Script=node.get_script() as Script
	if script!=null and script.resource_path=="res://scripts/destruction/palazzo/palazzo_structural_site.gd": node.ready.connect(capture_site45.bind(node),CONNECT_ONE_SHOT)

func capture_site45(value: Node3D) -> void:
	check(authored_site45==0,"only one actual authored Palazzo")
	authored_site45=value.get_instance_id(); authored45=Perf45.geometry(value)
	check(authored45.support.get("advance_calls",-1)==0,"authored collider inventory captured before first support advance")

func provenance45() -> bool:
	if not check(requested_charges in [1,8] and variant45 in ["baseline","candidate"] and not manifest45.is_empty(),"explicit charge count, variant and staged manifest required"): return false
	var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest45))
	if not check(document is Dictionary,"staged source manifest readable"): return false
	var pins: Dictionary=document.get("source_pins",document.get("expected_source_pins",{}))
	if not check(not pins.is_empty(),"full staged project source pins required"): return false
	var mismatches: Array[String]=[]
	for relative: String in pins:
		if relative.is_absolute_path() or relative.contains("..") or relative.contains(":") or FileAccess.get_sha256("res://".path_join(relative))!=pins[relative]: mismatches.append(relative)
	var own: String=get_script().resource_path
	evidence.provenance={"manifest":manifest45,"manifest_sha256":FileAccess.get_sha256(manifest45),"checked_sources":pins.size(),"mismatches":mismatches,"fixture_sha256":FileAccess.get_sha256(own),"observer_sha256":FileAccess.get_sha256("res://scripts/destruction/palazzo/c4_perf_observer45.gd"),"inherited_input_sha256":FileAccess.get_sha256("res://scripts/destruction/palazzo/test_c4.gd"),"revision":document.get("revision","")}
	return check(mismatches.is_empty(),"loaded source bytes match staged manifest")

func callback(event: Dictionary) -> Dictionary:
	# Observe only actual equipment dispatch. No extra negative probes in timing.
	var before: int=blast_owner45._pending.size()
	var before_events: int=blast_owner45._events.size()
	var begin: int=Time.get_ticks_usec()
	var result: Variant=original_callback.call(event)
	callbacks.append({"id":event.event_id,"placement_id":event.placement_id,"physics_frame":Engine.get_physics_frames(),"pending_before":before,"pending_after":blast_owner45._pending.size(),"events_before":before_events,"events_after":blast_owner45._events.size(),"native_consume_usec":Time.get_ticks_usec()-begin,"damage":event.damage,"radius":event.radius,"position":Perf45.vector(event.position),"ok":result is Dictionary and result.get("ok",false)})
	return result if result is Dictionary else {"ok":false}

func observe_fragments45() -> void:
	# Twelve actual bodies maximum, identical observer bound for both variants.
	# Cross-check native event claims against real rigid bodies and movement.
	while fragment_events_seen45<blast_owner45._events.size():
		var event: Dictionary=blast_owner45._events[fragment_events_seen45]; fragment_events_seen45+=1
		for id: int in event.released:
			if tracked_fragments45.size()>=12: break
			if tracked_fragments45.has(id): continue
			var body: Variant=instance_from_id(id)
			if not body is RigidBody3D or not is_instance_valid(body): continue
			var enabled:=0
			for node: Node in body.get_children():
				if node is CollisionShape3D and node.shape!=null and not node.disabled: enabled+=1
			var row: Dictionary={"id":id,"event_id":event.event_id,"first_position":Perf45.vector(body.global_position),"first_velocity":Perf45.vector(body.linear_velocity),"first_frozen":body.freeze,"first_layer":body.collision_layer,"enabled_shapes":enabled,"maximum_travel_m":0.0,"first_physics_frame":Engine.get_physics_frames()}
			fragment_samples45.append(row); tracked_fragments45[id]={"ref":weakref(body),"start":body.global_position,"row":row}
	for entry: Dictionary in tracked_fragments45.values():
		var body: Variant=entry.ref.get_ref()
		if is_instance_valid(body): entry.row.maximum_travel_m=maxf(entry.row.maximum_travel_m,body.global_position.distance_to(entry.start))

func hold_one45(index: int) -> bool:
	phase45="place_"+str(index+1)
	if index>0 and not await q_choice(equipment._button,"native Q placement "+str(index+1)): return false
	if finished: return false
	var selected: Dictionary=equipment._target()
	if not check(not selected.is_empty() and selected.body==wall and player.is_on_floor(),"same real aimed wall remains reachable before hold "+str(index+1)): return false
	hold_old_count45=equipment._charges.size(); first_new_frame45=-1; hold_drift45=0.0
	actual_initial_position45=player.global_position; measuring_hold45=true
	var frame_begin: int=Engine.get_physics_frames(); var usec_begin: int=Time.get_ticks_usec()
	mouse(MOUSE_BUTTON_LEFT,true); await create_timer(3.15,false,true).timeout
	if finished: return false
	var pressed: bool=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	mouse(MOUSE_BUTTON_LEFT,false); await step(2); measuring_hold45=false
	var state: Dictionary=equipment.snapshot()
	if not check(pressed and state.placed.size()==index+1 and state.mode=="remote","real uninterrupted 3.15s LMB adds exactly one charge "+str(index+1)): return false
	check(first_new_frame45>=0 and first_new_frame45-frame_begin>=ceili(3.0*Engine.physics_ticks_per_second)-1,"independent physics clock sees no early placement")
	check(hold_drift45<=.04 and callbacks.is_empty(),"stationary installation has no blast or scripted actor movement")
	for row: Dictionary in equipment._charges.values():
		var charge: Node3D=row.node.get_ref()
		check(is_instance_valid(charge) and charge.get_parent()==wall,"every item is a real child of the aimed native wall")
	holds45.append({"number":index+1,"begin_frame":frame_begin,"first_placed_frame":first_new_frame45,"wall_usec":Time.get_ticks_usec()-usec_begin,"real_lmb":pressed,"maximum_actor_drift_m":hold_drift45,"contact":Perf45.vector(selected.point),"normal":Perf45.vector(selected.normal),"placed":state.placed})
	return failures.is_empty()

func warmup47() -> void:
	phase45="warmup"
	var begin: int=Time.get_ticks_usec()
	evidence.warmup47={"required_process_frames":120,"frames":0,"ticks_begin":begin,"camera_before":Perf45.camera_state(player,camera,site),"population_before":Perf45.population(game)}
	while warmup_frames47<120 and not finished:
		await process_frame
		if finished: return
		warmup_frames47+=1
		evidence.warmup47.frames=warmup_frames47
	evidence.warmup47.ticks_end=Time.get_ticks_usec()
	evidence.warmup47.camera_after=Perf45.camera_state(player,camera,site)
	evidence.warmup47.population_after=Perf45.population(game)
	check(warmup_frames47==120,"120 actual process frames warmed the same native camera/content")

func sample45(label: String,seconds: float,fire: bool=false,until_stable: bool=false,minimum_frames47: int=30) -> void:
	phase45=label
	var record: Dictionary={"label":label,"samples":Perf45.samples(),"queue_observations":[],"camera_before":Perf45.camera_state(player,camera,site),"population_before":Perf45.population(game),"ticks_begin":Time.get_ticks_usec()}
	record.required_frames47=minimum_frames47; record.minimum_wall_seconds47=seconds; record.until_stable47=until_stable
	phase_records45.append(record)
	var start_actor: Vector3=player.global_position; var start_camera: Transform3D=camera.global_transform
	var actor_drift:=0.0; var camera_drift:=0.0; var camera_angle:=0.0
	var previous: int=Time.get_ticks_usec(); var stop: int=previous+int(seconds*1000000.0)
	var previous_events: int=blast_owner45._events.size(); var previous_frame: int=Engine.get_physics_frames()
	if fire:
		var begin: int=Time.get_ticks_usec()
		mouse(MOUSE_BUTTON_LEFT,true); mouse(MOUSE_BUTTON_LEFT,false)
		record.input_dispatch_usec=Time.get_ticks_usec()-begin
	while (Time.get_ticks_usec()<stop or record.samples.frame_ms.size()<minimum_frames47) and not finished:
		await process_frame
		if finished: return
		var now: int=Time.get_ticks_usec()
		Perf45.append_sample(record.samples,float(now-previous)/1000.0); previous=now
		if fire: observe_fragments45()
		var recovery_complete: bool=recovery_stable45()
		var current_events: int=blast_owner45._events.size(); var current_frame: int=Engine.get_physics_frames()
		if current_events!=previous_events:
			check(current_events-previous_events<=current_frame-previous_frame,"observed native queue commits at most one event per elapsed physics frame")
			record.queue_observations.append({"ticks_usec":now,"physics_frame":current_frame,"events":current_events,"pending":blast_owner45._pending.size(),"delta_events":current_events-previous_events,"elapsed_physics_frames":current_frame-previous_frame})
		if variant45=="candidate": check(blast_owner45._fx45._active<=6,"actual live FX pool never exceeds six slots")
		previous_events=current_events; previous_frame=current_frame
		actor_drift=maxf(actor_drift,player.global_position.distance_to(start_actor)); camera_drift=maxf(camera_drift,camera.global_position.distance_to(start_camera.origin))
		camera_angle=maxf(camera_angle,camera.global_basis.get_rotation_quaternion().angle_to(start_camera.basis.get_rotation_quaternion()))
		if record.samples.frame_ms.size()>=MAX_SAMPLES_PER_PHASE: check(false,"bounded sample storage exceeded"); break
		if until_stable and recovery_complete and record.samples.frame_ms.size()>=minimum_frames47: break
	record.summary=Perf45.summary(record.samples); record.ticks_end=Time.get_ticks_usec()
	record.camera_after=Perf45.camera_state(player,camera,site); record.population_after=Perf45.population(game)
	record.actor_drift_m=actor_drift; record.camera_drift_m=camera_drift; record.camera_angle_rad=camera_angle
	record.support_after=site._structure.diagnostics(); record.stable_for_30_physics_frames=recovery_stable45()
	record.minimum_window_complete47=record.samples.frame_ms.size()>=minimum_frames47 and (until_stable or record.ticks_end>=stop)
	check(record.minimum_window_complete47,label+": required actual frame count AND minimum wall duration completed")
	check(camera==root.get_camera_3d() and actor_drift<.02 and camera_drift<.02 and camera_angle<.002,label+": normal camera and actor stayed still throughout measurement")
	check(record.population_before.ids==record.population_after.ids and record.population_after.hp_owners==3 and record.population_after.live_hp_owners==3,label+": original three NPC/HP owners remain present")
	if not record.summary.is_empty(): check(record.summary.draw_calls.p50>0,label+": GPU workload actually rendered")

func validate_blast45() -> void:
	var snap: Dictionary=blast_owner45.snapshot(); var seen: Dictionary={}; var released: Dictionary={}
	var expected_damage: float=1920.0 if variant45=="candidate" else 480.0
	var expected_radius: float=3.2 if variant45=="candidate" else 2.4
	var expected_budget: int=48 if variant45=="candidate" else 12
	check(callbacks.size()==requested_charges and snap.events.size()==requested_charges and snap.pending==0,"all real planted charges are consumed and committed once")
	check(equipment.snapshot().placed.is_empty(),"no orphan physical charge remains after actual remote input")
	for index: int in callbacks.size():
		var receipt: Dictionary=callbacks[index]
		check(receipt.ok and receipt.pending_before==index and receipt.pending_after==index+1 and receipt.events_before==0 and receipt.events_after==0,"synchronous remote queues each real charge before any wall mutation")
		check(receipt.physics_frame==callbacks[0].physics_frame,"one remote input dispatches the entire batch synchronously")
		check(receipt.damage==expected_damage and receipt.radius==expected_radius,"actual equipment emits the declared variant profile")
		seen[receipt.id]=false
	for event: Dictionary in snap.events:
		check(seen.has(event.event_id) and not seen.get(event.event_id,true),"committed event is unique and has an actual input-created charge")
		seen[event.event_id]=true
		check(event.physical_charge_consumed and event.damage==expected_damage and event.radius==expected_radius and event.direct_fragment_budget==expected_budget,"native physics event preserves receipt and intended strength")
		check(event.released.size()<=expected_budget,"per-charge direct fragment budget remains bounded")
		for id: int in event.released: released[id]=true
	check(not released.is_empty(),"actual building physics released at least one fragment; workload was not merely cosmetic")
	var actual_mobile:=false
	for row: Dictionary in fragment_samples45:
		if not row.first_frozen and row.first_layer!=0 and row.enabled_shapes>0 and row.maximum_travel_m>.03: actual_mobile=true
	check(actual_mobile,"at least one input-released rigid body has real collision and visibly advances under native physics")
	evidence.fragment_observation=fragment_samples45
	if variant45=="candidate":
		check(snap.fx.total==requested_charges and snap.fx.active==0,"exactly one real effect per consumed charge and all effects finish")
		var maximum_evictions: int=maxi(0,requested_charges-6)
		check(snap.fx.capacity==6 and snap.fx.flash_capacity==2 and snap.fx.evicted>=0 and snap.fx.evicted<=maximum_evictions,"genuine explosions preserve the bounded six-slot/two-light pool")
		var workload: Dictionary=phase_records45[1]
		var observations: Array=workload.queue_observations
		var dense: bool=not observations.is_empty() and int(observations[-1].ticks_usec)-int(workload.ticks_begin)<=1000000 and Engine.time_scale==1.0
		if dense: check(snap.fx.evicted==maximum_evictions,"observed dense batch replaces exactly the expected live slots")
		evidence.pool_eviction={"dense_dequeue_within_one_wall_second":dense,"actual_evicted":snap.fx.evicted,"maximum_evictions":maximum_evictions,"note":"A stalled frame may retire a prior slot before reuse; that is not an allocation/capacity failure."}
	evidence.final_blast=snap; evidence.released_unique=released.size(); evidence.final_physics=Perf45.physics_state(site)
	check(evidence.final_physics.native_stats.native_body_count==authored45.native_stats.native_body_count and evidence.final_physics.native_stats.native_shape_count==authored45.native_stats.native_shape_count,"native body and collider inventory is preserved through real destruction")
	check(recovery_stable45(),"FX retired and native support follow-up graph remains stable for 30 physics frames within deadline")

func run() -> void:
	started_usec=Time.get_ticks_usec(); screenshots=false; output="res://tests/c4_input_perf45.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		elif arg.begins_with("--charges="): requested_charges=int(arg.trim_prefix("--charges="))
		elif arg.begins_with("--variant="): variant45=arg.trim_prefix("--variant=")
		elif arg.begins_with("--qa-manifest="): manifest45=arg.trim_prefix("--qa-manifest=")
	if not check(DisplayServer.get_name()!="headless","real GPU required; accelerated headless cannot establish wall-clock frame performance") or not provenance45(): finish(); return
	evidence.variant=variant45; evidence.charges=requested_charges; evidence.settings=Perf45.settings(root); evidence.engine=Engine.get_version_info()
	node_added.connect(observe_site45)
	var packed: PackedScene=load("res://scenes/main.tscn") as PackedScene
	if not check(packed!=null,"actual main scene load"): finish(); return
	game=packed.instantiate(); root.add_child(game); current_scene=game
	while not finished and game.get("preview_ready")!=true: await process_frame
	if finished: return
	if node_added.is_connected(observe_site45): node_added.disconnect(observe_site45)
	player=game._player; weapons=game.preview_weapons; site=game.preview_palazzo.site; camera=player.get_preview_camera()
	equipment=game.get_node_or_null("LocalC4Equipment"); blast_owner45=game.preview_c4_blast
	if not check(is_instance_valid(equipment) and equipment.snapshot().ready and is_instance_valid(blast_owner45),"actual main configured equipment and blast owner"): finish(); return
	if not check(authored_site45==site.get_instance_id() and not authored45.is_empty() and authored45.missing==0,"authored physical scene captured without content mutation"): finish(); return
	evidence.authored_geometry=authored45; evidence.startup_population=Perf45.population(game); evidence.startup_usec=Time.get_ticks_usec()-started_usec
	evidence.static_geometry=Perf45.static_geometry_after_host(site)
	check(evidence.static_geometry.convex_shapes==3 and evidence.static_geometry.unknown_shapes.is_empty(),"three original stone ramps and complete static collision geometry retained after host setup")
	check(evidence.startup_population.ids==["resident_169","resident_252","resident_72"] and evidence.startup_population.decor==8,"same original population and decor retained")
	if variant45=="candidate": check(equipment.snapshot().get("icons",{}).get("ready",false) and blast_owner45.snapshot().has("fx"),"candidate model icons and actual FX45 owner present")
	else: check(not blast_owner45.snapshot().has("fx"),"baseline uses the accepted pre-FX45 blast owner")
	for body: RigidBody3D in site.wall_panels:
		if str(body.name).begins_with("Facade") and body.position.distance_to(Vector3(-3,1.57,3))<.05: wall=body
	if not check(is_instance_valid(wall),"same authored lower facade wall exists"): finish(); return
	original_callback=equipment._explosion; equipment._explosion=Callable(self,"callback")
	# Only cold scenario setup: no actor or camera writes after this point.
	player.global_position=site.to_global(Vector3(-3.78,.12,4.15)); player.velocity=Vector3.ZERO
	player._camera_yaw=site.global_rotation.y; player._camera_pitch=-.08; player._update_camera_rotation(); await step(25)
	if not player._free_mouse_look:
		mouse(MOUSE_BUTTON_LEFT,true); await step(); mouse(MOUSE_BUTTON_LEFT,false); await step(3)
	if finished: return
	if not await q_choice(equipment._button,"actual Q C4 placement card") or not await aim_wall(Vector3(-.78,0,.17)): finish(); return
	if finished: return
	evidence.pre_hold_physics=Perf45.physics_state(site)
	for index: int in requested_charges:
		if not await hold_one45(index): finish(); return
	if not await retreat_native("same actual S retreat to five metres"): finish(); return
	if finished: return
	# Re-aim through mouse INPUT only; never replace the native gameplay camera.
	target=wall.to_global(Vector3(-.78,0,.17)); tracking=true; await step(35); tracking=false; await step(12)
	if finished: return
	await warmup47()
	if finished: return
	evidence.measurement_camera=Perf45.camera_state(player,camera,site)
	evidence.pre_blast_physics=Perf45.physics_state(site); evidence.pre_blast_population=Perf45.population(game)
	check(evidence.pre_blast_physics.support.get("ok",false) and not evidence.pre_blast_physics.support.get("busy",true),"initial intact support graph is stable before measured workload")
	if not failures.is_empty(): finish(); return
	await sample45("idle",2.0,false,false,240)
	if finished: return
	await sample45("actual_blast_and_physics",5.3,true,false,600)
	if finished: return
	await sample45("recovery",6.0)
	if finished: return
	if not recovery_stable45():
		# Capture all outstanding graph work; no content/physics reduction to fit.
		# Reserve 1 second for validation/report within the 56s wall watchdog.
		var remaining: float=float(SOFT_DEADLINE_USEC-(Time.get_ticks_usec()-started_usec))/1000000.0-1.0
		if remaining>0.6: await sample45("support_tail",minf(6.0,remaining),false,true)
		else: check(false,"INCOMPLETE: no remaining native window for stable support recovery")
	if finished: return
	validate_blast45()
	var event_count: int=blast_owner45._events.size(); var callback_count: int=callbacks.size()
	mouse(MOUSE_BUTTON_LEFT,true); mouse(MOUSE_BUTTON_LEFT,false); await step(2)
	check(blast_owner45._events.size()==event_count and callbacks.size()==callback_count,"real second remote input cannot replay consumed charges")
	finish()

func finish() -> void:
	if finished: return
	var windows_complete47: bool=warmup_frames47==120 and phase_records45.size()>=3
	for row: Dictionary in phase_records45:
		windows_complete47=windows_complete47 and bool(row.get("minimum_window_complete47",false))
	evidence.minimum_windows47={"warmup_process_frames":120,"idle_process_frames":240,"idle_seconds":2.0,"damage_process_frames":600,"damage_seconds":5.3,"recovery_seconds":6.0,"complete":windows_complete47,"watchdog_seconds":56,"hard_runner_seconds":60}
	if not windows_complete47: check(false,"INCOMPLETE: required frame and time windows were not completed")
	evidence.completion47="COMPLETE" if windows_complete47 and failures.is_empty() else "INCOMPLETE_OR_FAILED"
	evidence.holds=holds45; evidence.phases=phase_records45
	evidence.scenario_complete=windows_complete47 and holds45.size()==requested_charges and phase_records45.size() in [3,4] and evidence.has("final_blast") and recovery_stable45()
	if not evidence.scenario_complete: check(false,"finite input/performance scenario did not finish")
	evidence.acceptance="NATIVE_INPUT_AND_MEASUREMENT_ONLY_COMPARE_REQUIRED"
	evidence.scope={"manual_OS_input":false,"full_city":false,"hand_contact_pose44":false,"incoming_player_damage":false,"idle_vs_blast_comparison_is_not_before_after_optimization_proof":true,"separate_cold_baseline_and_candidate_required":true}
	measuring_hold45=false
	super.finish()
