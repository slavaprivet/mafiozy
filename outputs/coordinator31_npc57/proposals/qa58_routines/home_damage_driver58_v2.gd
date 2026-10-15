extends Node
## Component intent owner for resident_3 only. Same real life, body, host, map.
const Home = preload("res://scripts/homes/npc_home_controller58.gd")
const Avoidance = preload("res://scripts/navigation/npc_avoidance_world29.gd")
var scene: Node3D
var life: RefCounted
var home: RefCounted
var actor: CharacterBody3D
var started:=false
var failed:=""
var ended:=false
var rows: Array=[]
var takeover: Dictionary={}
var born_us:=0
var born_frame:=0
var next_sample:=0.0
var last_progress:=0.0
var progress_position:=Vector3.ZERO
var max_required_idle:=0.0
var damage_trigger_frame:=-1
var sleep_cancel_frame:=-1
var exit_frame:=-1
func _ready() -> void:
	process_physics_priority=-100
	scene=get_tree().current_scene
func v(p: Vector3) -> Array:return [p.x,p.y,p.z]
func _setup() -> bool:
	var population: Variant=scene.preview_population
	if population==null or not population.city_ready or not population.city_stream_complete():return false
	life=population.daily._lives.get("resident_3")
	if life==null or not is_instance_valid(life._token.get("body")):return false
	if life._visit!=null or life._economy28_active() or life._restaurant28_active() or life._dsh_simple_goal_active() or life.threat_physics_active30() or life._health.should_pause_walk() or life._attention29.active:return false
	actor=life._token.body
	takeover={"source_id":"resident_3","body_id":actor.get_instance_id(),"life_generation":life._token.life_generation,"start":v(actor.global_position),"ordinary_phase":life._phase,"scope":"Suspend this resident's ordinary intent scheduling only; no position/health/mask/physics/host changes"}
	life._ambient29_cancel("home_damage_component58")
	if life._roam51!=null:life._roam51.cancel();life._roam51_active=false
	if not life._walk.cancel().get("ok",false):failed="walk_owner_not_released";return false
	life._phase="HOME_COMPONENT58";life._next_decision=INF;life._goal={}
	home=Home.new()
	if not home.configure(life,scene,life._dsh_simple_map()):failed="home_configure_failed";return false
	Avoidance.refresh_scene(scene)
	if not home.begin({"kind":"home_sleep","source_id":"resident_3"}):failed="home_begin_failed";return false
	born_us=Time.get_ticks_usec();born_frame=Engine.get_physics_frames();progress_position=actor.global_position
	started=true;return true
func _physics_process(delta: float) -> void:
	if not failed.is_empty():return
	if not started:
		_setup();return
	# Reserve the ordinary daily callback this frame so only this component home
	# controller writes locomotion; the native resident host still commits pose.
	life._frame=Engine.get_physics_frames()
	Avoidance.refresh_scene(scene)
	if home.active():home.step(delta,life._life())
	var elapsed: float=float(Time.get_ticks_usec()-born_us)/1000000.0
	var state: Dictionary=home.snapshot()
	var required: bool=home.active() and str(state.phase) not in ["HOME_SETTLE","HOME_SLEEP","HOME_REST"]
	if not required or Vector2(actor.global_position.x-progress_position.x,actor.global_position.z-progress_position.z).length()>.05:
		last_progress=elapsed;progress_position=actor.global_position
	if required:max_required_idle=maxf(max_required_idle,elapsed-last_progress)
	if damage_trigger_frame>=0 and sleep_cancel_frame<0 and str(state.phase) not in ["HOME_SLEEP","HOME_REST","HOME_SETTLE"]:sleep_cancel_frame=Engine.get_physics_frames()
	if damage_trigger_frame>=0 and not home.active() and exit_frame<0:exit_frame=Engine.get_physics_frames()
	if elapsed>=next_sample:
		var driver: Variant=home._visit._drive if home._visit!=null else null
		var row: Dictionary={"at_s":elapsed,"frame":Engine.get_physics_frames(),"position":v(actor.global_position),"home":state,"required_motion":required,"motion_idle_s":elapsed-last_progress if required else 0.0,"native_velocity":v(actor.velocity),"hp":life._life().get("hp"),"driver":driver.diagnostics() if driver!=null and driver.has_method("diagnostics") else {}}
		rows.append(row);next_sample+=1.0
func snapshot() -> Dictionary:
	return {"started":started,"failed":failed,"takeover":takeover,"rows":rows,"max_required_idle_s":max_required_idle,"damage_trigger_frame":damage_trigger_frame,"sleep_cancel_frame":sleep_cancel_frame,"exit_frame":exit_frame,"home":home.snapshot() if home!=null else {}}
