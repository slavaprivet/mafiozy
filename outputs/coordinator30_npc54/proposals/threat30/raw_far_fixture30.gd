extends SceneTree
const Threat=preload("res://scripts/city/runtime/npc_threat_world30.gd")
const Spatial=preload("res://scripts/navigation/npc_avoidance_world29.gd")
class HealthPort extends RefCounted:
	var token: Dictionary
	var eligible := true
	func incident_witness_snapshot() -> Dictionary:
		if not eligible:return {}
		return {"eligible":true,"role_scope":"ordinary_unarmed_civilian","body":token.body,"body_instance_id":token.body.get_instance_id(),"owner_instance_id":get_instance_id(),"life_generation":token.life_generation,"session_id":"raw_native_fixture","source_id":token.source_id,"position":token.body.global_position,"forward":-token.body.global_basis.z}
class LifePort extends RefCounted:
	var _health: RefCounted
	var events: Array[Dictionary]=[]
	func threat_event30(event: Dictionary, world: RefCounted) -> Dictionary:
		if not world.authentic(self,event):return {"accepted":false}
		events.append(event.duplicate());return {"accepted":true}
class DailyPort extends RefCounted:
	var _lives: Dictionary={}
	func wake_physical30(_id: String) -> void:pass
class ResidentsPort extends RefCounted:
	var _records: Dictionary={}
class PopulationPort extends RefCounted:
	var daily=DailyPort.new()
	var residents=ResidentsPort.new()
	var health: Dictionary={}
	var view: RefCounted
	var scene: Node3D
	var max_results := 0
	func incident_game_paused() -> bool:return false
	func health_from_body30(body: CharacterBody3D) -> RefCounted:return health.get(body.get_instance_id())
	func query_near30(origin: Vector3,radius: float,results: int,scan: int,channel: String) -> Array[Dictionary]:
		var rows: Array[Dictionary]=[]
		view.refresh(scene)
		for row: Dictionary in view.query_near30(origin,radius,results,scan,channel):
			var owner: RefCounted=health_from_body30(row.body)
			if owner==null or owner.token.life_generation!=row.life_generation:continue
			row.health=owner;rows.append(row)
		max_results=maxi(max_results,rows.size());return rows
class WeaponPort extends Node:
	signal shot_emitted(shot: Dictionary,muzzle: Dictionary,camera: Vector3,direction: Vector3)
	var player: CharacterBody3D
	func armed() -> bool:return false
class Fixture extends Node3D:
	var preview_population=PopulationPort.new()
	var spatial=Spatial.new()
	var world=Threat.new()
	var weapons=WeaponPort.new()
	var checks: Dictionary={}
	var clock := 0.0
	var started := false
	var max_scan := 0
	var max_los := 0
	var out := ""
	var stale_checked := false
	var ready30 := false
	func _ready() -> void:_setup.call_deferred()
	func _body(at: Vector3) -> CharacterBody3D:
		var body:=CharacterBody3D.new();body.collision_layer=1;body.collision_mask=1
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7
		shape.shape=capsule;shape.position.y=.85;body.add_child(shape);add_child(body);body.position=at
		if at.length()>.01:body.look_at(at+at.normalized(),Vector3.UP)
		return body
	func _setup() -> void:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		preview_population.scene=self;preview_population.view=spatial
		weapons.player=_body(Vector3(0,0,-10));add_child(weapons)
		for i: int in 66:
			var id: String="witness_"+str(i)
			var body: CharacterBody3D=_body(Vector3(cos(TAU*float(i)/66.0)*25.0,0,sin(TAU*float(i)/66.0)*25.0))
			var health:=HealthPort.new();health.token={"source_id":id,"body":body,"life_generation":1};health.eligible=i<64
			var life:=LifePort.new();life._health=health
			preview_population.residents._records[id]={"row":{"source_id":id},"body":body,"generation":1}
			preview_population.health[body.get_instance_id()]=health;preview_population.daily._lives[id]=life
		checks.configured=world.configure(weapons,preview_population).ok
		ready30=true
	func _shot(id: String) -> void:
		weapons.shot_emitted.emit({"shotId":id,"weaponId":"tt_pistol","projectiles":[{}]},{"origin":Vector3(0,1.35,0)},Vector3.ZERO,Vector3.FORWARD)
	func _physics_process(delta: float) -> void:
		if not ready30:return
		clock+=delta;spatial.refresh(self)
		if not started:
			started=true;_shot("single_fixture");_shot("single_fixture")
			checks.duplicate_signal_ignored=world._stats.shots==1 and world._shot_jobs30.size()==1
		if clock<.45:
			# Exhaust the real production spatial budget before the observer's lane.
			for i: int in 8:spatial.query_near30(Vector3.ZERO,41,32,128,"shot")
		var rays_before: int=world._stats.los_queries
		world.step(delta)
		max_los=maxi(max_los,int(world._stats.los_queries)-rays_before)
		max_scan=maxi(max_scan,int(spatial.query_state30().scans_this_frame))
		if clock>.35 and clock<.44:checks.empty_budget_retains_shot=world._shot_jobs30.size()==1 and world._stats.delivered==0
		if clock>4.3 and not stale_checked:
			stale_checked=true
			var reached := 0
			for i: int in 64:
				var life: RefCounted=preview_population.daily._lives["witness_"+str(i)]
				if life.events.size()==1 and life.events[0].kind=="near_shot":reached+=1
			checks.single_event_all_64_current_witnesses=reached==64
			checks.reached_count=reached==64
			checks.single_event_not_just_first32=reached>32
			checks.role_filter_preserved=preview_population.daily._lives.witness_64.events.is_empty() and preview_population.daily._lives.witness_65.events.is_empty()
			checks.native_query_and_delivery_bounds=preview_population.max_results<=16 and max_scan<=128 and world._stats.max_pending<=128
			checks.far_los_budget_deferred_not_dropped=world._stats.los_deferred>0 and world._stats.los_queries>=64 and max_los<=2
			checks.opaque_scan_ends_by_ttl=world._shot_jobs30.is_empty() and world._pending.is_empty()
			_shot("stale_fixture");world._pump_shots30()
			checks.real_batch_for_generation_test=not world._pending.is_empty()
			if not world._pending.is_empty():
				var pending: Dictionary=world._pending[0]
				var owner: RefCounted=pending.owner.get_ref();owner.token.life_generation+=1
				preview_population.residents._records[owner.token.source_id].generation=owner.token.life_generation
		if clock>4.6:
			checks.captured_generation_change_rejected=world._stats.stale>=1
			var stats: Dictionary=world.snapshot()
			world.dispose();checks.dispose_releases_all_pending=world._shot_jobs30.is_empty() and world._pending.is_empty()
			var result: Dictionary={"passed":not checks.values().has(false),"checks":checks,"stats":stats,"native_capsules":67,"native_spatial_query":true,"max_native_scan":max_scan,"max_los_per_sense":max_los,"scope":"Controlled shot signal and life/health ports; genuine production spatial grid and LOS rays on 66 native witness capsules 25m away (outside close hearing). Not a real inventory shot or full city acceptance.","performance_accepted":false}
			var file:=FileAccess.open(out.path_join("RAW_SHOTS30.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
			print("RAW_SHOTS30 ",JSON.stringify(result));set_physics_process(false);get_tree().quit(0 if result.passed else 1)
func _initialize() -> void:_start.call_deferred()
func _start() -> void:
	var fixture:=Fixture.new();root.add_child(fixture);current_scene=fixture
