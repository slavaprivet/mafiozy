extends Node
const Threat=preload("res://scripts/city/runtime/npc_threat_life30.gd")
const ThreatWorld=preload("res://scripts/city/runtime/npc_threat_world30.gd")
const Driver=preload("res://scripts/city/runtime/npc_threat_route30.gd")
const Attention=preload("res://scripts/npc_visual/npc_attention29.gd")
const Focus=preload("res://scripts/npc_visual/npc_resident_focus29.gd")
const Visit=preload("res://scripts/hospital/npc_restaurant_visit28.gd")
const Simple=preload("res://scripts/hospital/npc_simple_hospital.gd")
const Cohort=preload("res://scripts/city/runtime/npc_wait_cohort56.gd")
class HealthPort extends RefCounted:
	var _token: Dictionary
	var _row: Dictionary={"hp":60.0,"max_hp":60.0}
	var paused:=false
	func should_pause_walk() -> bool:return paused
	func incident_witness_snapshot() -> Dictionary:
		var body: CharacterBody3D=_token.body
		return {"eligible":true,"role_scope":"ordinary_unarmed_civilian","position":body.global_position,"forward":-body.global_basis.z,"source_id":_token.source_id,"session_id":_token.session_id,"life_generation":_token.life_generation,"owner_instance_id":get_instance_id(),"body_instance_id":body.get_instance_id(),"body":body,"token":_token}
class HostPort extends RefCounted:
	var _records: Dictionary={}
	func target_current(token: Dictionary) -> bool:return is_instance_valid(token.body) and token.life_generation==1
class WalkPort extends RefCounted:
	func interrupt_current_route() -> Dictionary:return {"ok":true}
class EconomyPort extends RefCounted:
	var _route: RefCounted
	var requests:=0
	var pauses:=0
	func request_priority(_reason: String) -> void:requests+=1
	func pause() -> void:pauses+=1
class DailyPort extends RefCounted:
	var _lives: Dictionary={}
	func wake_physical30(_id: String) -> void:pass
class PopulationPort extends RefCounted:
	var daily=DailyPort.new()
	func query_near30(_origin: Vector3,_radius: float,_count: int,_scan: int,_channel: String) -> Array:return []
	func health_from_body30(_body: CharacterBody3D) -> RefCounted:return null
	func incident_game_paused() -> bool:return false
class WeaponPort extends Node:
	signal shot_emitted(shot: Dictionary,muzzle: Dictionary,camera: Vector3,direction: Vector3)
	var player: CharacterBody3D
	func armed() -> bool:return false
class ScenePort extends Node3D:
	var _player: CharacterBody3D
	var _block: Dictionary={}
	var _origin:=Vector3.ZERO
class LifePort extends RefCounted:
	var controller=Threat.new()
	var _health=HealthPort.new()
	var _host=HostPort.new()
	var _walk=WalkPort.new()
	var _attention29=Attention.new()
	var _economy28: RefCounted
	var _token: Dictionary
	var _goal: Dictionary={}
	var _disposed:=false
	var _phase:="IDLE"
	var _next_decision:=0.0
	var _now:=0.0
	var _roam51: RefCounted
	var _roam51_active:=false
	var _visit: RefCounted
	var _threat30: RefCounted
	var _incident_waiting_release:=false
	var _interrupting:=false
	var _hospital_treat_started:=-1.0
	var _restaurant28_meal_started:=-1.0
	func _life() -> Dictionary:return _health._row
	func _hospital51_below_threshold(row: Dictionary) -> bool:return float(row.hp)>0 and float(row.hp)<30
	func _needs_hospital(row: Dictionary) -> bool:return _hospital51_below_threshold(row)
	func _ambient29_cancel(_reason: String) -> void:pass
	func _economy28_active() -> bool:return _economy28!=null
	func _restaurant28_active() -> bool:return false
	func _dsh_simple_goal_active() -> bool:return false
	func _dsh_simple_on() -> bool:return true
	func _dsh_energy_drain() -> void:pass
	func _dsh_resdiag_step(_row: Dictionary) -> void:pass
	func _hospital28_clear_treatment_pose() -> void:pass
	func threat_event30(event: Dictionary,world: RefCounted) -> Dictionary:return controller.accept(self,event,world)
var out:=""
var candidate:=false
var checks: Dictionary={}
var metrics: Dictionary={}
var world=ThreatWorld.new()
var life=LifePort.new()
var body: CharacterBody3D
var scene: ScenePort
var camera: Camera3D
const DT:=1.0/60.0
func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg=="--candidate31=1":candidate=true
	_run.call_deferred()
func tick() -> void:
	await get_tree().physics_frame
func check(key: String,value: bool) -> void:
	checks[key]=value;print("ATTENTION31_CHECK ",key," ",value)
func deliver(kind: String="visible_weapon",identified: bool=true) -> void:
	world._deliver(life._health,life._health.incident_witness_snapshot(),kind,"fixture",kind+"_fixture",Vector3(-3,0,0),identified,"golden_colt")
func actor(at: Vector3) -> CharacterBody3D:
	var value:=CharacterBody3D.new();value.collision_layer=1;value.collision_mask=1
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.36;capsule.height=1.9
	shape.shape=capsule;shape.position.y=.95;value.add_child(shape);scene.add_child(value);value.global_position=at
	return value
func reset_controller() -> void:
	life.controller.cancel("fixture_reset")
	life.controller=Threat.new();life._phase="IDLE";life._goal={};body.rotation.y=0.0;body.velocity=Vector3.ZERO
	world._now+=2.0
func hold_controller(phase: String="RECOVER") -> void:
	var driver=Driver.new();check("native_driver_configured_"+str(checks.size()),driver.configure(body,"fixture",1.8))
	life.controller._driver=driver;life.controller._phase=phase;life.controller._owned=true;life.controller._age=0.0;life.controller._attempts=3;life.controller._called=true;life._phase="THREAT30"
func point_focus_camera() -> void:
	# The headless display cannot capture a cursor. Align the actual camera ray
	# for its native viewport mouse position instead; never override Focus._hit.
	var screen: Vector2=get_viewport().get_visible_rect().size*.5 if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else get_viewport().get_mouse_position()
	var ray: Vector3=camera.project_ray_normal(screen)
	var toward: Vector3=(body.global_position+Vector3.UP-camera.global_position).normalized()
	camera.global_basis=Basis(Quaternion(ray,toward))*camera.global_basis
func _run() -> void:
	Engine.physics_ticks_per_second=60
	scene=ScenePort.new();get_tree().root.add_child(scene);get_tree().current_scene=scene
	var grid: Array=[]
	for z: int in 60:
		var row: Array=[]
		for x: int in 60:row.append(1)
		grid.append(row)
	scene._block={"surface":{"grid":grid,"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":-30,"startRow":-30}}
	var ground:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(60,.2,60);shape.shape=box;shape.position.y=-.1;ground.add_child(shape);scene.add_child(ground)
	body=actor(Vector3(0,.003,0));scene._player=actor(Vector3(-3,.003,0))
	var weapon:=WeaponPort.new();scene.add_child(weapon);weapon.player=scene._player
	var population=PopulationPort.new()
	life._token={"body":body,"source_id":"fixture","session_id":"attention31","life_generation":1}
	life._health._token=life._token;life._host._records.fixture={"body":body,"speed":1.8};population.daily._lives.fixture=life
	check("actual_world_configured",world.configure(weapon,population).ok)
	await tick();await tick()
	deliver();hold_controller("ALERT")
	for frame: int in 30:
		await tick();world._now+=DT;life.controller.step(DT,life._health._row)
	metrics.alert_yaw=body.rotation.y
	check("alert_faces_or_baseline_failure",absf(wrapf(body.rotation.y-PI/2,-PI,PI))<.12 if candidate else absf(body.rotation.y)<.001)
	reset_controller();deliver();hold_controller()
	var start: Vector3=body.global_position
	var first_motion:=-1;var max_step:=0.0;var previous: Vector3=start
	for frame: int in 360:
		await tick();world._now+=DT
		if frame%6==0:deliver()
		life.controller.step(DT,life._health._row)
		var moved: float=body.global_position.distance_to(previous);max_step=maxf(max_step,moved);previous=body.global_position
		if first_motion<0 and Vector2(body.global_position.x-start.x,body.global_position.z-start.z).length()>.03:first_motion=frame
	metrics.recover_first_motion_frame=first_motion;metrics.recover_distance_m=body.global_position.distance_to(start);metrics.max_native_step_m=max_step
	metrics.engine_physics_hz=Engine.physics_ticks_per_second;metrics.in_physics=Engine.is_in_physics_frame();metrics.native_physics_delta=body.get_physics_process_delta_time()
	check("persistent_visible_weapon_retries_or_baseline_freeze",first_motion>=120 and first_motion<180 and body.global_position.distance_to(start)>4.0 if candidate else first_motion<0 and body.global_position.distance_to(start)<.01)
	check("native_motion_no_teleport",max_step<.05)
	check("panic_speed_remains_plus10",is_equal_approx(life.controller._driver.fear_speed,1.98) and is_equal_approx(life._host._records.fixture.speed,1.8))
	# A no-longer-observed source must not create additional flee cycles.
	reset_controller();deliver();hold_controller();world._now=life.controller._last_observation+1.1
	for frame: int in 150:
		world._now+=DT;life.controller.step(DT,life._health._row)
	check("old_observation_does_not_retry",life.controller._phase=="RECOVER")
	world._now=life.controller._quiet_until-.001;life.controller.step(DT,life._health._row)
	check("quiet_active_before15",life.controller.active())
	world._now+=.002;life.controller.step(DT,life._health._row)
	check("quiet_releases_at15",not life.controller.active() and life._phase=="IDLE" and life.controller._reason=="quiet_15_seconds")
	reset_controller();deliver("near_shot",false);hold_controller()
	life.controller.step(DT,life._health._row)
	check("unidentified_shot_does_not_track_player",absf(body.rotation.y)<.0001)
	reset_controller();deliver();hold_controller();life._health._row.hp=12.0
	life.controller.step(DT,life._health._row)
	check("low_hp_cancels_threat_before_facing",not life.controller.active() and absf(body.rotation.y)<.0001)
	life._health._row.hp=60.0;reset_controller();deliver();hold_controller();life._health.paused=true
	life.controller.step(DT,life._health._row)
	check("hit_stagger_keeps_facing_authority",absf(body.rotation.y)<.0001)
	life._health.paused=false;reset_controller();deliver();hold_controller();life._health._row.dead=true
	life.controller.step(DT,life._health._row)
	check("death_cancels_before_facing",not life.controller.active() and absf(body.rotation.y)<.0001)
	life._health._row.erase("dead");reset_controller();deliver();hold_controller();life._token.life_generation=2
	life.controller.step(DT,life._health._row)
	check("stale_generation_cancels_before_facing",not life.controller.active() and absf(body.rotation.y)<.0001)
	life._token.life_generation=1
	# Actual attention and actual service wrapper, with the exact failed drive
	# state produced by a blocked OUTBOUND. No full city/transaction is asserted.
	reset_controller();body.global_position=Vector3(0,.003,0);body.velocity=Vector3.ZERO
	var visit=Visit.new();visit._body=body;visit._phase="OUTBOUND";visit._drive=Simple.new();visit._drive._body=body
	var economy=EconomyPort.new();economy._route=visit;life._economy28=economy;life._phase="WALKING"
	camera=Camera3D.new();scene.add_child(camera);camera.global_position=Vector3(-3,1,0);camera.look_at(Vector3(0,1,0),Vector3.UP);camera.current=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var motion:=InputEventMouseMotion.new();motion.position=get_viewport().get_visible_rect().size*.5;motion.global_position=motion.position
	get_viewport().push_input(motion,true)
	await tick();await tick()
	point_focus_camera()
	metrics.focus_state={"mouse_mode":Input.mouse_mode,"mouse_position":get_viewport().get_mouse_position(),"viewport_size":get_viewport().get_visible_rect().size,"camera_current":camera.is_current(),"body":body.global_position}
	check("native_focus_hits_stationary_service_resident",Focus.focused(body))
	var attention_owns:=false
	for frame: int in 30:
		await tick();point_focus_camera();attention_owns=life._attention29.step(life,DT,life._health._row) or attention_owns
	metrics.exit_retry_yaw=body.rotation.y
	check("exit_retry_faces_or_baseline_failure",absf(wrapf(body.rotation.y-PI/2,-PI,PI))<.12 if candidate else absf(body.rotation.y)<.001)
	check("exit_retry_never_held_or_paused",not attention_owns and not life._attention29.active and economy.pauses==0 and visit._phase=="OUTBOUND" and not visit._drive._active)
	# Same release boundary under threat: must yield to the service every tick.
	reset_controller();deliver();var yielded:=true
	for frame: int in 30:
		await tick();world._now+=DT;yielded=not life.controller.step(DT,life._health._row) and yielded
	metrics.release_service_yaw=body.rotation.y
	check("threat_exit_wait_faces_or_baseline_failure",absf(wrapf(body.rotation.y-PI/2,-PI,PI))<.12 if candidate else absf(body.rotation.y)<.001)
	check("threat_exit_wait_preserves_service_dispatch",yielded and economy.requests==30 and life.controller._phase=="RELEASE_SERVICE")
	check("near_player_wait_cohort_does_not_skip",not Cohort.new()._far(body,scene._player.global_position,camera.global_position))
	life._economy28=null;life.controller.cancel("fixture_done");life._attention29.clear();world.dispose();scene.queue_free();await tick()
	var passed:=not checks.values().has(false)
	var result: Dictionary={"passed":passed,"candidate":candidate,"checks":checks,"metrics":metrics,"scope":"Actual threat/attention/physical route/service wrapper; controlled health/perception delivery and failed-service state. Full city, purchase and performance acceptance are separate.","performance_accepted":false}
	var file:=FileAccess.open(out.path_join("NATIVE31.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("ATTENTION31_RESULT ",JSON.stringify(result));get_tree().quit(0 if passed else 1)
