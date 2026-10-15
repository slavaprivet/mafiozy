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
class HoldPort extends RefCounted:
	func hold(_delta: float) -> void:pass
	func cancel() -> void:pass
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

var out:=""
var baseline:=false
var checks: Dictionary={}
var world=World.new()
var life=LifePort.new()
func _initialize() -> void:_run.call_deferred()
func deliver(kind: String,id: String,at: float) -> Dictionary:
	world._now=at
	world._deliver(life._health,life._health.incident_witness_snapshot(),kind,"fixture_incident",id,Vector3(-3,0,0),true,"tt_pistol")
	return world._issued["%d:%s"%[life._health.get_instance_id(),kind]]
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg=="--qa-baseline":baseline=true
	await create_timer(2.0).timeout
	var scene:=Node3D.new();root.add_child(scene);current_scene=scene
	var body:=CharacterBody3D.new();scene.add_child(body)
	var weapon:=WeaponPort.new();scene.add_child(weapon);weapon.player=body
	var pop:=PopulationPort.new()
	life._token={"body":body,"source_id":"fixture","session_id":"fixture_order","life_generation":1}
	life._health._token=life._token;life._host._records.fixture={"body":body,"speed":1.8};pop.daily._lives.fixture=life
	checks.world_configured=world.configure(weapon,pop).ok
	deliver("near_shot","shot1",10.0)
	checks.first_observation_accepted=life.controller._event.kind=="near_shot"
	var hit: Dictionary=deliver("actual_hit","hit1",10.0)
	checks.same_tick_hit_priority_reproduced_or_fixed=life.controller._event.kind==("near_shot" if baseline else "actual_hit")
	var until: float=life.controller._quiet_until
	var replay: Dictionary=life.controller.accept(life,hit,world)
	checks.exact_replay_rejected=not replay.accepted and life.controller._quiet_until==until
	# Start a later actual-hit observation independently of the same-tick case.
	deliver("actual_hit","hit2",20.0)
	checks.later_hit_accepted=life.controller._event.kind=="actual_hit"
	deliver("near_shot","shot2",20.1)
	checks.lower_priority_downgrade_reproduced_or_fixed=life.controller._event.kind==("near_shot" if baseline else "actual_hit")
	checks.new_threat_extends_quiet=is_equal_approx(life.controller._quiet_until,35.1)
	var near_replay: Dictionary=world._issued["%d:near_shot"%life._health.get_instance_id()]
	checks.same_tick_lower_priority_replay_rejected=not life.controller.accept(life,near_replay,world).accepted
	until=life.controller._quiet_until
	var stale: Dictionary=deliver("actual_hit","stale_hit",20.05)
	checks.stale_time_does_not_extend=life.controller._quiet_until==until and life.controller._last_observation==20.1
	# Replace the stale issued key with a valid distinct same-tick hit.
	deliver("actual_hit","hit3",20.1)
	checks.distinct_same_tick_hit_reproduced_or_fixed=life.controller._event.event_id==("shot2" if baseline else "hit3")
	life._health._row.hp=12.0;deliver("actual_hit","medical_hit",21.0)
	checks.medical_priority_unchanged=life.controller._quiet_until==until
	life._health._row.hp=60.0
	life._token.life_generation=2
	checks.stale_generation_rejected=not world.authentic(life,stale)
	life._token.life_generation=1
	deliver("actual_hit","quiet_hit",22.0)
	life.controller._phase="RECOVER";life.controller._driver=HoldPort.new()
	life.controller._owned=true;life._phase="THREAT30"
	until=life.controller._quiet_until
	var observed_before: int=world._stats.observed
	# Weapons stay hidden. Advance the actual World and deadline logic with a
	# controlled hold port; this is a timer contract, not a physical flee receipt.
	for i: int in 899:
		world.step(1.0/60.0);life.controller.step(1.0/60.0,life._health._row)
	checks.hidden_weapon_does_not_renew=world._stats.observed==observed_before and life.controller._quiet_until==until
	checks.quiet_remains_active_before_15=life.controller.active()
	world.step(1.0/60.0);life.controller.step(1.0/60.0,life._health._row)
	world.step(1.0/60.0);life.controller.step(1.0/60.0,life._health._row)
	checks.quiet_releases_at_15=not life.controller.active() and life.controller._reason=="quiet_15_seconds" and life._phase=="IDLE"
	life.controller.cancel("fixture_finished");world.dispose();scene.queue_free();await process_frame
	checks.cleanup=not life.controller.active() and world._issued.is_empty()
	var passed: bool=not checks.values().has(false)
	var result: Dictionary={"passed":passed,"baseline_bug_reproduction":baseline,"checks":checks,"scope":"actual World deliver/authentic + Life acceptance ordering with controlled observation/health ports; real weapon proof is separate actual10 city test","performance_accepted":false}
	var f:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close();print("THREAT_ORDER56 ",JSON.stringify(result));quit(0 if passed else 1)

