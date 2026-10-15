extends SceneTree
const World=preload("res://scripts/city/runtime/npc_threat_world30.gd")
const LifeController=preload("res://scripts/city/runtime/npc_threat_life30.gd")
const Physical=preload("res://scripts/hospital/npc_physical_route51.gd")
const Budget=preload("res://scripts/hospital/npc_route_budget29.gd")

class HealthPort extends RefCounted:
	var _token: Dictionary
	var _row: Dictionary={"hp":60.0,"max_hp":60.0}
	var paused := false
	func should_pause_walk() -> bool:return paused
	func incident_witness_snapshot() -> Dictionary:
		var body: CharacterBody3D=_token.body
		return {"eligible":true,"role_scope":"ordinary_unarmed_civilian","position":body.global_position,"forward":-body.global_basis.z,"source_id":_token.source_id,"session_id":_token.session_id,"life_generation":_token.life_generation,"owner_instance_id":get_instance_id(),"body_instance_id":body.get_instance_id(),"body":body,"token":_token}
class HostPort extends RefCounted:
	var _records: Dictionary={}
	func target_current(token: Dictionary) -> bool:return is_instance_valid(token.body) and token.life_generation==1
class WalkPort extends RefCounted:
	func interrupt_current_route() -> Dictionary:return {"ok":true}
class AttentionPort extends RefCounted:
	func clear() -> void:pass
class DailyPort extends RefCounted:
	var _lives: Dictionary={}
	func wake_physical30(_id: String) -> void:pass
class PopulationPort extends RefCounted:
	var daily=DailyPort.new()
	var rows: Array[Dictionary]=[]
	func query_near30(_origin: Vector3,_radius: float,_max_results: int,_max_scan: int,_channel: String) -> Array[Dictionary]:return rows
	func health_from_body30(_body: CharacterBody3D) -> RefCounted:return null
	func incident_game_paused() -> bool:return false
class WeaponPort extends Node:
	signal shot_emitted(shot: Dictionary,muzzle: Dictionary,camera: Vector3,direction: Vector3)
	var player: CharacterBody3D
	var fire_state: Dictionary={"weaponId":"none"}
	func armed() -> bool:return false
class LifePort extends RefCounted:
	var controller=LifeController.new()
	var _health=HealthPort.new()
	var _host=HostPort.new()
	var _walk=WalkPort.new()
	var _attention29=AttentionPort.new()
	var _token: Dictionary
	var _goal: Dictionary={}
	var _disposed := false
	var _phase := "IDLE"
	var _next_decision := 0.0
	var _now := 0.0
	var _roam51: RefCounted
	var _roam51_active := false
	var _visit: RefCounted
	func _life() -> Dictionary:return _health._row
	func _hospital51_below_threshold(row: Dictionary) -> bool:return float(row.hp)<30
	func _ambient29_cancel(_reason: String) -> void:pass
	func _economy28_active() -> bool:return false
	func _restaurant28_active() -> bool:return false
	func _dsh_simple_on() -> bool:return true
	func _dsh_energy_drain() -> void:pass
	func _dsh_resdiag_step(_row: Dictionary) -> void:pass
	func threat_event30(event: Dictionary,world: RefCounted) -> Dictionary:return controller.accept(self,event,world)

class Fixture extends Node3D:
	var _origin=Vector3(32,0,32)
	var _block: Dictionary={}
	var preview_population: RefCounted
	var world=World.new()
	var life=LifePort.new()
	var weapons=WeaponPort.new()
	var actor: CharacterBody3D
	var ordinary: CharacterBody3D
	var ordinary_route=Physical.new()
	var clock := 0.0
	var started := false
	var second := false
	var replay := false
	var recovered := false
	var out := ""
	var checks: Dictionary={}
	var samples: Array[Dictionary]=[]
	var flee_speed_max := 0.0
	var ordinary_speed_max := 0.0
	var max_deviation := 0.0
	var recovered_at := -1.0
	var saved_route: Dictionary={}
	var next_sample := 0.0
	var follow: RefCounted
	var follow_way := 0
	var follow_complete := false
	var at_first_threat := Vector3.ZERO
	var setup_done := false
	func _ready() -> void:
		_setup.call_deferred()
	func _setup() -> void:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		var grid: Array=[]
		for r: int in 64:
			var row: Array=[];row.resize(64);row.fill(0);grid.append(row)
		_block={"surface":{"cellSize":1.0,"startCol":0,"startRow":0,"grid":grid,"palette":{"0":{"kind":"grass","solid":true,"heightM":0.0},"1":{"kind":"water","solid":false,"heightM":-1.0}}}}
		_fixed(Vector3(64,1,64),Vector3(0,-.5,0))
		_fixed(Vector3(.7,2.5,2.5),Vector3(3,1.25,0))
		actor=_body(Vector3(0,.005,0));actor.rotation.y=-PI*.5
		ordinary=_body(Vector3(0,.005,-8))
		weapons.player=ordinary;add_child(weapons)
		preview_population=PopulationPort.new()
		var rig:=Skeleton3D.new();actor.add_child(rig)
		life._token={"body":actor,"rig":rig,"source_id":"resident_fixture","session_id":"controlled_fixture30","life_generation":1}
		life._health._token=life._token
		life._host._records["resident_fixture"]={"body":actor,"speed":1.8}
		preview_population.daily._lives["resident_fixture"]=life
		checks.world_configured=world.configure(weapons,preview_population).ok
		checks.ordinary_physical_configured=ordinary_route.configure(ordinary)
		setup_done=true
	func _fixed(size: Vector3,at: Vector3) -> void:
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=1
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);add_child(body);body.position=at
	func _body(at: Vector3) -> CharacterBody3D:
		var body:=CharacterBody3D.new();body.collision_layer=1;body.collision_mask=1;body.floor_snap_length=.3
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7;shape.shape=capsule;shape.position.y=.85;body.add_child(shape);add_child(body);body.position=at
		return body
	func _observe(id: String) -> void:
		var observation: Dictionary=life._health.incident_witness_snapshot()
		world._deliver(life._health,observation,"near_shot","component_incident",id,Vector3(-3,1.1,0),false)
	func _physics_process(delta: float) -> void:
		if not setup_done:return
		clock+=delta;world.step(delta);life._now=clock*1000.0
		if not started:
			ordinary_route.hold(delta)
			if clock<.2:return
			started=true;at_first_threat=actor.global_position
			world._los_left=2
			checks.wall_blocks_actual_ray=not world._line_clear(life._health.incident_witness_snapshot(),Vector3(6,1.35,0))
			checks.front_fov=World.in_fov(life._health.incident_witness_snapshot(),Vector3(6,1.1,0))
			checks.back_fov_rejected=not World.in_fov(life._health.incident_witness_snapshot(),Vector3(-6,1.1,0))
			life._health._row.hp=12.0
			_observe("controlled_low_hp")
			checks.medical_priority=not life.controller.active()
			life._health._row.hp=60.0
			preview_population.rows.append({"health":life._health})
			for index: int in 300:
				world._on_shot({"shotId":"controlled_burst_"+str(index),"weaponId":"tt_pistol","projectiles":[{}]},{"origin":Vector3(6,1.35,0)},Vector3.ZERO,Vector3.RIGHT)
			checks.burst_coalesced=world._pending.size()==1 and world._stats.coalesced_shots==299
			checks.shot_ledger_bounded=world._seen_shots.size()==256
			world._pending.clear();preview_population.rows.clear()
			_observe("component_first")
		if clock<3:
			var before: Vector3=ordinary.global_position
			ordinary_route.move(Vector3.RIGHT,1.8*delta,delta)
			ordinary_speed_max=maxf(ordinary_speed_max,Vector2(ordinary.global_position.x-before.x,ordinary.global_position.z-before.z).length()/delta)
		else:ordinary_route.hold(delta)
		if clock>7 and not second:
			second=true;_observe("component_second")
		if clock>8 and not replay:
			replay=true
			var old_deadline: float=life.controller._quiet_until
			var result: Dictionary=life.controller.accept(life,life.controller._event,world)
			checks.replay_does_not_extend=not result.accepted and life.controller._quiet_until==old_deadline
		var before: Vector3=actor.global_position
		if not recovered:
			life.controller.step(delta,life._health._row)
			var measured: float=Vector2(actor.global_position.x-before.x,actor.global_position.z-before.z).length()/delta
			flee_speed_max=maxf(flee_speed_max,measured)
			max_deviation=maxf(max_deviation,absf(actor.global_position.z))
			if life.controller._driver!=null:saved_route=life.controller._driver.snapshot()
			if second and not life.controller.active():
				recovered=true;recovered_at=clock
				checks.quiet_15_seconds=clock>=21.99 and clock<22.15 and life.controller._reason=="quiet_15_seconds"
				checks.life_released=life._phase=="IDLE" and is_equal_approx(float(life._host._records.resident_fixture.speed),1.8)
				follow=Physical.new()
				checks.follow_route_configured=follow.configure(actor) and follow.begin(actor.global_position+Vector3(0,0,3.0))
		elif follow!=null and not follow_complete:
			if follow.status=="searching":follow.tick()
			if follow.status=="ready":
				while follow_way<follow.route.size()-1 and actor.global_position.distance_to(follow.route[follow_way])<.2:follow_way+=1
				var offset: Vector3=follow.route[follow_way]-actor.global_position;offset.y=0
				if follow_way==follow.route.size()-1 and offset.length()<.3:follow_complete=true;follow.cancel()
				elif offset.length()>.001:follow.move(offset.normalized(),minf(1.8*delta,offset.length()),delta)
			else:follow.hold(delta)
		if clock>=next_sample:
			next_sample=clock+.5;samples.append({"t":clock,"phase":life.controller._phase,"position":str(actor.global_position),"quiet_until":life.controller._quiet_until,"jobs":Budget._jobs.size()})
		if (recovered and follow_complete) or clock>30:
			checks.actual_flee_distance=actor.global_position.distance_to(at_first_threat)>4.0
			checks.physical_wall_detour=max_deviation>1.4
			checks.speed_multiplier=absf(flee_speed_max/ordinary_speed_max-1.10)<.005
			checks.returned_to_following_native_route=follow_complete
			life.controller.cancel("fixture_finished");ordinary_route.cancel()
			if follow!=null:follow.cancel()
			checks.no_retained_route_jobs=Budget._jobs.is_empty()
			var result: Dictionary={"passed":not checks.values().has(false),"checks":checks,"ordinary_speed_mps":ordinary_speed_max,"fear_speed_mps":flee_speed_max,"measured_ratio":flee_speed_max/ordinary_speed_max,"recovered_at":recovered_at,"last_route":saved_route,"world":world.snapshot(),"samples":samples,"scope":"Controlled observation/life ports with actual Godot floor, wall, LOS, A-star and capsule movement. No real player gunshot/HP/police report proof. Following route proves released native movement, not complete production daily agenda.","full_city_accepted":false,"phone_visual_accepted":false,"police_dispatch_accepted":false,"performance_accepted":false}
			if not out.is_empty():
				var file:=FileAccess.open(out.path_join("COMPONENT30.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
			print("THREAT30_COMPONENT ",JSON.stringify(result));world.dispose();set_physics_process(false);get_tree().quit(0 if result.passed else 1)

func _initialize() -> void:_start.call_deferred()
func _start() -> void:
	var fixture:=Fixture.new();root.add_child(fixture);current_scene=fixture
