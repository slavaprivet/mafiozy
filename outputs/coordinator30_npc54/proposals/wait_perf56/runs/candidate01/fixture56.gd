extends SceneTree
const Daily=preload("res://scripts/npc_city_daily.gd")
const Simple=preload("res://scripts/hospital/npc_simple_hospital.gd")
const Budget=preload("res://scripts/hospital/npc_route_budget29.gd")

class AdapterPort extends RefCounted:
	var _revision:=0
class HealthPort extends RefCounted:
	var _row: Dictionary={"hp":60.0,"max_hp":60.0}
	var _ready:=true
	var _adapter=AdapterPort.new()
	func should_pause_walk() -> bool:return false
class HostPort extends RefCounted:
	var _records: Dictionary={}
class AttentionPort extends RefCounted:
	var active:=false
class ThreatPort extends RefCounted:
	var running:=false
	func active() -> bool:return running
class LifePort extends RefCounted:
	var _disposed:=false
	var _busy:=false
	var _visit: RefCounted
	var _attention29=AttentionPort.new()
	var _threat30=ThreatPort.new()
	var _ambient29: RefCounted
	var _interrupting:=false
	var _incident_waiting_release:=false
	var _phase:="WALKING"
	var _goal: Dictionary={"kind":"walk"}
	var _economy28: RefCounted
	var _restaurant28: RefCounted
	var _roam51: RefCounted
	var _roam51_active:=true
	var _token: Dictionary
	var _host: RefCounted
	var _health=HealthPort.new()
	var _frame:=-1
	var _dsh_last_ms:=0
	var _dsh_elapsed:=-1.0
	var calls:=0
	var max_call_gap:=0
	var last_call:=-1
	var generation_retired:=false
	func threat_physics_active30() -> bool:return _threat30.active()
	func _dsh_simple_goal_active() -> bool:return false
	func _economy28_active() -> bool:return false
	func _restaurant28_active() -> bool:return false
	func step(delta: float) -> void:
		_frame=Engine.get_physics_frames();calls+=1
		if last_call>=0:max_call_gap=maxi(max_call_gap,_frame-last_call)
		last_call=_frame
		if _host._records[_token.source_id].generation!=_token.life_generation:
			_roam51.cancel();_roam51_active=false;_disposed=true;generation_retired=true;return
		var result: String=_roam51.step(delta)
		if result in ["arrived","blocked"]:_roam51_active=false;_phase="RESTING"

class Scene extends Node3D:
	var _origin:=Vector3(128,0,128)
	var _block: Dictionary={}
	var _player: Node3D
	var daily=Daily.new()
	var host=HostPort.new()
	var lives: Array[RefCounted]=[]
	var platform: CollisionShape3D
	var camera: Camera3D
	var run_frame:=0
	var started:=false
	var fixed:=true
	var out:=""
	var checks: Dictionary={}
	var first_position:=Vector3.ZERO
	var first_calls:=0
	var floor_disabled_frame:=-1
	var floor_fall_frame:=-1
	var revision_frame:=-1
	var threat_frame:=-1
	var generation_frame:=-1
	var camera_frame:=-1
	var max_dispatch_us:=0
	var total_dispatch_us:=0
	func _ready() -> void:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
			if arg=="--city-wait-cohort56=0":fixed=false
		var grid: Array=[]
		for r: int in 32:
			var row: Array=[];row.resize(32);row.fill(0);grid.append(row)
		_block={"surface":{"cellSize":8.0,"startCol":0,"startRow":0,"grid":grid,"palette":{"0":{"kind":"grass","solid":true,"heightM":0.0},"1":{"kind":"water","solid":false,"heightM":-1.0}}}}
		_fixed(Vector3(256,1,256),Vector3(0,-.5,0))
		platform=_fixed(Vector3(5,.4,5),Vector3(-50,2.8,0))
		_player=Node3D.new();add_child(_player)
		camera=Camera3D.new();add_child(camera);camera.position=Vector3(0,2,0);camera.current=true
		daily._scene=weakref(self);daily._physical_enabled30=1
		_setup.call_deferred()
	func _fixed(size: Vector3,at: Vector3) -> CollisionShape3D:
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=1
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);add_child(body);body.position=at
		return shape
	func _make(index: int,at: Vector3,goal: Vector3) -> RefCounted:
		var body:=CharacterBody3D.new();body.collision_layer=1;body.collision_mask=1;body.floor_snap_length=.3
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7;shape.shape=capsule;shape.position.y=.85;body.add_child(shape);add_child(body);body.position=at
		var id:="wait_fixture_"+str(index)
		var life:=LifePort.new();life._host=host;life._token={"source_id":id,"life_generation":1,"body":body}
		host._records[id]={"body":body,"generation":1}
		life._roam51=Simple.new();assert(life._roam51.begin(goal,body,RID(),id,"roam"))
		lives.append(life);daily._lives[id]=life;daily.wake_physical30(id)
		return life
	func _setup() -> void:
		await get_tree().physics_frame
		var mover: RefCounted=_make(0,Vector3(35,.003,-100),Vector3(43,.003,-100))
		for attempt: int in 100:
			await get_tree().physics_frame
			mover.step(1.0/60.0)
			if mover._roam51._route.status=="ready":break
		checks.mover_native_route_ready=mover._roam51._route.status=="ready"
		_make(1,Vector3(0,.003,0),Vector3(24,.003,0))
		_make(2,Vector3(-50,3.003,0),Vector3(-30,3.003,0))
		for i: int in range(3,287):
			var at:=Vector3(35+(i%17)*3,.003,-70+floori(float(i)/17)*3)
			_make(i,at,at+Vector3(24,0,0))
		first_position=mover._token.body.global_position;first_calls=mover.calls
		started=true
	func _eligible(index: int) -> bool:
		var id: String=lives[index]._token.source_id
		if not daily._wait_cohort56._states.has(id):return false
		return int(daily._wait_cohort56._states[id].next_frame)>Engine.get_physics_frames()+1
	func _physics_process(delta: float) -> void:
		if not started:return
		run_frame+=1
		var frame: int=Engine.get_physics_frames()
		if floor_disabled_frame<0 and run_frame>20 and (not fixed or _eligible(2)):
			platform.set_deferred("disabled",true);floor_disabled_frame=frame+1
		if revision_frame<0 and run_frame>40 and (not fixed or _eligible(3)):
			lives[3]._health._adapter._revision+=1;revision_frame=frame
		if threat_frame<0 and run_frame>45 and (not fixed or _eligible(4)):
			lives[4]._threat30.running=true;threat_frame=frame
		if generation_frame<0 and run_frame>50 and (not fixed or _eligible(5)):
			host._records[lives[5]._token.source_id].generation=2;generation_frame=frame
		if camera_frame<0 and run_frame>55 and (not fixed or _eligible(6)):
			camera.global_position=lives[6]._token.body.global_position+Vector3.UP*2;camera_frame=frame
		elif camera_frame>=0 and frame>camera_frame:camera.position=Vector3(0,2,0)
		var before: int=Time.get_ticks_usec()
		daily._physical_tick30(delta)
		var cost: int=Time.get_ticks_usec()-before;max_dispatch_us=maxi(max_dispatch_us,cost);total_dispatch_us+=cost
		if floor_disabled_frame>=0 and frame>=floor_disabled_frame and floor_fall_frame<0 and lives[2]._token.body.global_position.y<2.999:floor_fall_frame=frame
		if frame==revision_frame:checks.revision_wakes_same_tick=lives[3].last_call==frame
		if frame==threat_frame:checks.threat_wakes_same_tick=lives[4].last_call==frame
		if frame==generation_frame:checks.generation_wakes_same_tick=lives[5].generation_retired
		if frame==camera_frame:checks.camera_near_wakes_same_tick=lives[6].last_call==frame
		if run_frame>=120:_finish()
	func _finish() -> void:
		started=false
		var state: Dictionary=daily._wait_cohort56.snapshot()
		var calls:=0;var max_gap:=0;var active:=0
		for life: RefCounted in lives:calls+=life.calls;max_gap=maxi(max_gap,life.max_call_gap);active+=int(life._roam51_active)
		checks.all_287_preserved=lives.size()==287 and daily._lives.size()==287
		checks.moving_every_tick=lives[0].calls-first_calls==120
		var moved: float=Vector2(lives[0]._token.body.global_position.x-first_position.x,lives[0]._token.body.global_position.z-first_position.z).length()
		checks.moving_speed_preserved=moved>3.4 and moved<3.8
		checks.near_every_tick=lives[1].calls==120
		checks.floor_removal_observed=floor_disabled_frame>=0 and floor_fall_frame>=floor_disabled_frame and floor_fall_frame-floor_disabled_frame<=1
		checks.every_waiter_polled_within_6_ticks=max_gap<=6
		checks.bounded_skipped_wall_time=int(state.max_skipped_gap_ms)<100
		checks.skips_are_substantial=int(state.skipped)>18000 if fixed else int(state.skipped)==0
		checks.planner_shared_budget=Budget.diagnostics().budget_us==1800 and Budget.diagnostics().max_jobs==384
		var planner: Dictionary=Budget.diagnostics()
		for life: RefCounted in lives:life._roam51.cancel()
		daily._wait_cohort56.clear()
		checks.cleanup=Budget.diagnostics().jobs==0 and daily._wait_cohort56.snapshot().states==0
		var passed:=true
		for value: bool in checks.values():passed=passed and value
		var result: Dictionary={"passed":passed,"fixed":fixed,"checks":checks,"details":{"lives":287,"frames":120,"full_life_calls":calls,"wait":state,"active_routes_end":active,"native_moved_m":moved,"floor_disabled_frame":floor_disabled_frame,"floor_fall_frame":floor_fall_frame,"max_call_gap_frames":max_gap,"dispatch_us_mean":float(total_dispatch_us)/120,"dispatch_us_max":max_dispatch_us,"planner":planner,"full_city_performance_accepted":false,"health_threat_ports":"controlled revisions/events, not a real inventory shot"}}
		var file:=FileAccess.open(out+"/RESULT.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
		print("WAIT56 ",JSON.stringify(result));get_tree().quit(0 if passed else 1)

func _initialize() -> void:
	var scene:=Scene.new();root.add_child.call_deferred(scene);set_deferred("current_scene",scene)
