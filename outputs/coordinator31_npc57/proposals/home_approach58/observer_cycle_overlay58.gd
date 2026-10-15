extends Node
## Component intent takeover only. All ten real bodies retain native physics,
## collision, health, avoidance and the resident host's sole skeleton writer.
const Home=preload("res://scripts/homes/npc_home_controller58.gd")
const Avoidance=preload("res://scripts/navigation/npc_avoidance_world29.gd")
var scene: Node3D
var out_path: String
var checks: Array[Dictionary]=[]
var actors: Dictionary={}
var evidence: Dictionary={"scope":"merged-source component home intents; ordinary daily selection suspended, no body placement or collision edits", "samples":[], "transitions":[], "physics_context":true}
var started:=0
var cycle_started:=0
var wake_started:=0
var sample_at:=0.0
var all_sleep_since:=-1.0
var captures_started:=false
var captures_done:=false
var finished:=false

func _ready() -> void:
	process_physics_priority=-50;started=Time.get_ticks_usec()

func check(ok: bool,name: String,detail: Variant=null) -> bool:
	checks.append({"ok":ok,"name":name,"detail":detail});return ok
func vec(v:Vector3)->Array:return [v.x,v.y,v.z]
func elapsed()->float:return float(Time.get_ticks_usec()-cycle_started)/1000000.0 if cycle_started else 0.0
func finish(reason: String="") -> void:
	if finished:return
	finished=true;set_physics_process(false)
	if not reason.is_empty():check(false,reason)
	evidence.checks=checks;evidence.passed=true;evidence.elapsed_s=elapsed();evidence.final=[]
	for id: String in actors:evidence.final.append(sample_actor(id))
	for row: Dictionary in checks:
		if not row.ok:evidence.passed=false
	var file:=FileAccess.open(out_path.path_join("HOME_CYCLE58.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"));file.close()
	print("HOME_CYCLE58 terminal passed=",evidence.passed," reason=",reason)
	get_tree().quit(0 if evidence.passed else 1)

func eligible(life: RefCounted)->bool:
	return not life._disposed and life._visit==null and not life._economy28_active() and not life._restaurant28_active() and not life._dsh_simple_goal_active() and not life.threat_physics_active30() and not life._health.should_pause_walk() and not life._attention29.active

func capture(life: RefCounted,id: String)->bool:
	if not eligible(life):return false
	var body: CharacterBody3D=life._token.body
	if not life._host.target_current(life._token):return false
	# Explicitly retire only the ordinary walking/ambient intent at its current
	# generation. No service is force-cancelled and the life itself remains alive.
	life._ambient29_cancel("home_component_takeover")
	if life._roam51!=null:life._roam51.cancel()
	life._roam51_active=false
	if life._walk!=null:life._walk.cancel()
	life._phase="HOME_COMPONENT58";life._goal={};life._next_decision=INF
	var home: RefCounted=Home.new()
	if not check(home.configure(life,scene,life._dsh_simple_map()),"configure "+id):finish("configure failed");return false
	if not check(home.available(),"assigned current bed "+id):finish("no current bed");return false
	var slot: Dictionary=scene.preview_homes58.registry58.assigned(id)
	actors[id]={"life":life,"body":body,"home":home,"slot":slot,"start":body.global_position,"last":body.global_position,"travel":0.0,"max_step":0.0,"began":false,"sleep":false,"exited":false,"phase":"","initial_layer":body.collision_layer,"initial_mask":body.collision_mask,"sleep_geometry":{},"sleep_since":-1.0,"failed":false}
	return true

func bone(rig:Skeleton3D,name:String)->Vector3:
	var index:=rig.find_bone(name)
	return rig.global_transform*rig.get_bone_global_pose(index).origin if index>=0 else Vector3.INF
func pose_geometry(actor:Dictionary)->Dictionary:
	var rig:Skeleton3D=actor.life._token.rig
	var surface:Vector3=actor.slot.bed_surface
	var face:Vector3=actor.slot.bed_face
	var right:Vector3=actor.slot.bed_right
	var head:=bone(rig,"head");var pelvis:=bone(rig,"pelvis")
	var hips:Vector3=(bone(rig,"thigh_l")+bone(rig,"thigh_r"))*.5
	var points:Dictionary={}
	var finite:=true;var supported:=true
	for name:String in ["head","pelvis","foot_l","foot_r","hand_l","hand_r"]:
		var point:=bone(rig,name);var offset:=point-surface
		points[name]={"world":vec(point),"bed_local":[offset.dot(right),offset.y,offset.dot(face)]}
		finite=finite and point.is_finite()
		# Skeleton joints, not skinned skin bounds; PNG is a separate visual proof.
		supported=supported and absf(offset.dot(right))<.72 and absf(offset.dot(face))<1.2 and offset.y>-.03 and offset.y<.50
	var axis:Vector3=(head-pelvis).normalized()
	return {"finite":finite,"joints_in_bed_envelope":supported,"head_axis_dot":axis.dot(face),"head_axis_up":absf(axis.y),"hips_surface_error":hips.distance_to(surface+Vector3.UP*.12),"points":points}

func sample_actor(id:String)->Dictionary:
	var a:Dictionary=actors[id];var home:RefCounted=a.home;var body:CharacterBody3D=a.body
	var state:Dictionary=home.snapshot()
	state["source_id"]=id;state["position"]=vec(body.global_position);state["travel_m"]=a.travel;state["max_step_m"]=a.max_step
	if home._visit!=null:
		var visit:RefCounted=home._visit
		state["door_state"]={"entry_wait":visit._entry_door_wait56,"exit_stage":visit._exit_door_state56,"inner":vec(visit._inner),"staging":vec(visit._staging)}
		if visit._drive!=null:
			var drive:RefCounted=visit._drive
			var route:RefCounted=drive._route
			state["driver"]={"phase":drive._phase,"reason":drive._last_reason,"target":vec(drive._target),"leg":drive._leg,"legs":drive._legs,"way":drive._way,"attempts":drive._attempts,"avoidance":drive._avoidance29_state.duplicate(true),"service_watch":drive._service_watch30.duplicate(true),"route":route.diagnostics() if route!=null else {},"guide":drive._guide.diagnostics() if drive._guide!=null else {}}
			if route!=null:
				state.driver["route_goal"]=vec(route.goal)
				if drive._way<route.route.size():state.driver["waypoint"]=vec(route.route[drive._way])
			if drive._guide!=null:
				var point:Variant=drive._guide.waypoint()
				if point is Vector3:state.driver["guide_point"]=vec(point)
	state["start"]=vec(a.start);state["ever_sleep"]=a.sleep;state["actual_exit"]=a.exited;state["sleep_geometry"]=a.sleep_geometry
	return state

func _physics_process(delta:float)->void:
	if finished:return
	evidence.physics_context=bool(evidence.physics_context) and Engine.is_in_physics_frame()
	if not scene.preview_ready or scene.preview_population==null or not scene.preview_population.city_ready:
		if Time.get_ticks_usec()-started>90000000:finish("city readiness deadline")
		return
	var daily:RefCounted=scene.preview_population.daily
	if daily==null:return
	for id:String in daily._lives:
		if not actors.has(id):capture(daily._lives[id],id)
	if finished:return
	# Native current-frame snapshot precedes the same current-frame native move.
	# Population's later refresh sees the same frame and does not resnapshot.
	Avoidance.refresh_scene(scene)
	for id:String in actors:
		var a:Dictionary=actors[id]
		a.life._frame=Engine.get_physics_frames()
	if actors.size()!=10:
		if Time.get_ticks_usec()-started>180000000:finish("ten outside owners could not be acquired")
		return
	if cycle_started==0:
		cycle_started=Time.get_ticks_usec()
		check(Engine.physics_ticks_per_second==60,"60Hz native physics",Engine.physics_ticks_per_second)
		check(scene.preview_population.residents._records.size()==287,"catalogue preserved287")
		for id:String in actors:
			var a:Dictionary=actors[id]
			a.began=a.home.begin({"kind":"home_sleep","source_id":id,"hour":23.0,"wake_hour":7.0})
			check(a.began,"begin assigned home "+id)
		if not actors.values().all(func(a:Dictionary)->bool:return a.began):finish("home begin failed");return
	var sleeping:=0;var done:=0;var failed_count:=0
	for id:String in actors:
		var a:Dictionary=actors[id];var home:RefCounted=a.home;var body:CharacterBody3D=a.body
		var result:String=home.step(delta,a.life._life())
		var distance:float=body.global_position.distance_to(a.last)
		a.travel+=distance;a.max_step=maxf(a.max_step,distance);a.last=body.global_position
		var phase:String=home._phase
		if phase!=a.phase:
			evidence.transitions.append({"at":elapsed(),"id":id,"from":a.phase,"to":phase,"state":sample_actor(id)})
			print("HOME_CYCLE58 ",id," ",phase," t=",elapsed()," reason=",home._reason)
			a.phase=phase
		if body.collision_layer!=a.initial_layer or body.collision_mask!=a.initial_mask:finish("body collision changed "+id);return
		if distance>.10:finish("nonphysical movement step "+id);return
		# At pre-main callback the previous host commit is exactly one frame old.
		if phase=="HOME_SLEEP" and home._support_current and home._pose_frame>=Engine.get_physics_frames()-1:
			sleeping+=1
			if a.sleep_since<0:a.sleep_since=elapsed()
			if not a.sleep and elapsed()-a.sleep_since>=2.0:
				a.sleep=true;a.sleep_geometry=pose_geometry(a)
				check(a.sleep_geometry.finite and a.sleep_geometry.joints_in_bed_envelope and a.sleep_geometry.head_axis_dot>.94 and a.sleep_geometry.head_axis_up<.12 and a.sleep_geometry.hips_surface_error<.03,"actual committed bed skeleton "+id,a.sleep_geometry)
		if a.failed:failed_count+=1;continue
		if not home.active() and wake_started>0:
			if not a.exited:
				a.exited=true
				var outside:float=(body.global_position-Vector3(a.slot.door)).dot(Vector3(a.slot.normal))
				check(outside<-.8 and not body.has_meta("npc_home_pose58"),"physical outside and pose released "+id,{"side":outside,"reason":home._reason})
			done+=1
		elif not home.active():
			a.failed=true;failed_count+=1
			check(false,"home terminated before sleep "+id,home._reason)
	if elapsed()>=sample_at:
		var rows:Array=[]
		for id:String in actors:rows.append(sample_actor(id))
		evidence.samples.append({"t":elapsed(),"frame":Engine.get_physics_frames(),"sleeping":sleeping,"actors":rows});sample_at+=1.0
	if sleeping+failed_count==10 and sleeping>0 and wake_started==0:
		if all_sleep_since<0:all_sleep_since=elapsed()
		if elapsed()-all_sleep_since>=2.0 and not captures_started:
			captures_started=true;capture_houses.call_deferred()
		if captures_done:
			check(sleeping==10,"all ten concurrently sleeping in assigned 3+3+2+2 beds",sleeping)
			wake_started=Time.get_ticks_usec()
			for id:String in actors:actors[id].home.request_wake("fixture_ordinary_morning")
	if done+failed_count==10 and wake_started>0:
		check(scene.get_meta("npc_home_claims58",{}).get("claims",{}).is_empty(),"all assigned-bed claims released")
		check(evidence.physics_context,"all controller steps in real physics callback")
		finish();return
	if wake_started==0 and elapsed()>300.0:finish("300s approach and sleep deadline")
	if wake_started>0 and Time.get_ticks_usec()-wake_started>90000000:finish("90s actual exit deadline")

func capture_houses()->void:
	if DisplayServer.get_name()=="headless":
		evidence["visual_png_acceptance"]="PENDING graphical companion; headless checks actual committed bone geometry only"
		captures_done=true;return
	var camera:=Camera3D.new();camera.name="HomeComponentCamera58";camera.fov=92.0;camera.near=.05
	scene.add_child(camera);camera.make_current()
	for house:Node3D in scene.preview_homes58.current_sites():
		camera.global_position=house.to_global(Vector3(0,2.65,2.7))
		camera.look_at(house.to_global(Vector3(0,.82,-1.55)),Vector3.UP)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path:String=out_path.path_join(str(house.source_id)+"_sleep.png")
		var error:int=get_viewport().get_texture().get_image().save_png(path)
		check(error==OK,"native bed screenshot "+str(house.source_id),path)
	captures_done=true
