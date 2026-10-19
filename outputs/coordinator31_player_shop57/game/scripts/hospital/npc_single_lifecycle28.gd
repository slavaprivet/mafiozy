extends Node
## Explicit one-resident local-session lifecycle. No per-frame callback.
## Confirmed health receipts retire needs immediately; a one-shot timer alone
## starts a new generation after the corpse interval. Source rows stay immutable.
const Simple = preload("res://scripts/hospital/npc_simple_hospital.gd")
const Health = preload("res://scripts/npc_visual/npc_local_preview_hit_owner.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const ID := "resident_1"
var source_id30 := ID
var _mass_manager30: WeakRef
const MAX_SPAWN_ATTEMPTS := 9
var _population: WeakRef
var _scene: WeakRef
var _health: RefCounted
var _token: Dictionary = {}
var _packet := PackedByteArray()
var _trust: Dictionary = {}
var _timer: Timer
var _corpse_s := 5.0
var _phase := "unbound"
var _event := ""
var _generation := 0
var _spawn := Vector3.ZERO
var _new_owner: RefCounted
var _attempts := 0
var _death_frame := -1
var _respawn_frame := -1
var _death_count := 0
var _respawn_count := 0
var _reason := ""
var _birth_receipt: Dictionary = {}

static func enabled() -> bool:
	return Simple.enabled()

func configure(scene: Node3D, population: RefCounted, packet: PackedByteArray, trust: Dictionary) -> bool:
	set_process(false); set_physics_process(false)
	if _phase!="unbound" or not Simple.enabled() or not is_instance_valid(scene) or not is_instance_valid(population) or population.get("_stream_on")==true: return false
	if population.hit_owners.size()!=1 or population.daily==null: return false
	var health: RefCounted=population.hit_owners[0]
	var token: Dictionary=health.get("_token")
	if token.get("source_id")!=ID or not population.residents.target_current(token): return false
	var count:=0
	for record: Dictionary in population.residents._records.values():
		if is_instance_valid(record.body): count+=1
	if count!=1: return false
	return configure_resident30(scene,population,packet,trust,health,null)

func configure_resident30(scene: Node3D, population: RefCounted, packet: PackedByteArray, trust: Dictionary, health: RefCounted, manager: Node) -> bool:
	set_process(false);set_physics_process(false)
	if _phase!="unbound" or not Simple.enabled() or not is_instance_valid(scene) or population.daily==null or not is_instance_valid(health):return false
	var token: Dictionary=health.get("_token")
	source_id30=str(token.get("source_id",""))
	if source_id30.is_empty() or not population.residents.target_current(token) or not population.daily._lives.has(source_id30):return false
	if manager==null and (source_id30!=ID or population.hit_owners.size()!=1):return false
	_mass_manager30=weakref(manager) if manager!=null else null
	_population=weakref(population);_scene=weakref(scene);_packet=packet;_trust=trust.duplicate(true)
	if manager==null:population.daily._track_single28=true
	_health=health;_token=token.duplicate();_generation=int(token.life_generation)
	_spawn=population.residents._records[source_id30].origin
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--city-respawn-seconds="):_corpse_s=clampf(float(arg.trim_prefix("--city-respawn-seconds=")),1.0,30.0)
	if not population.residents.bind_single_lifecycle28(self) or not health.bind_single_lifecycle28(self):return false
	_phase="alive"
	return true

func _schedule30(seconds: float) -> void:
	if not is_instance_valid(_timer):
		_timer=Timer.new();_timer.one_shot=true;_timer.process_callback=Timer.TIMER_PROCESS_PHYSICS
		add_child(_timer);_timer.timeout.connect(_on_timer)
	_timer.start(seconds)

func _pop() -> RefCounted:
	var pop: RefCounted=_population.get_ref() if _population!=null else null
	return pop if is_instance_valid(pop) and not pop.get("_disposed") else null

func owns_health(health: RefCounted) -> bool:
	var pop: RefCounted=_pop()
	return _phase in ["alive","corpse"] and health==_health and pop!=null and _scene!=null and is_instance_valid(_scene.get_ref()) and pop.residents.physical_life_current(_token)

func suspended() -> bool:
	return _phase in ["corpse","spawning","blocked"]

func confirmed_death(health: RefCounted, event_id: String) -> bool:
	if _phase!="alive" or not owns_health(health):return false
	var row: Dictionary=health.get("_row")
	var receipt: Dictionary=health.get("last_result")
	if not row.get("dead",false) or float(row.get("hp",1))>0 or event_id.is_empty() or receipt.get("event_id")!=event_id or not receipt.get("ok",false) or not receipt.get("applied",false) or receipt.get("reason") not in ["final_death","bleedout"]:return false
	if health.get("_adapter").receipt(event_id)!=receipt:return false
	var pop: RefCounted=_pop()
	# Seal the event before callbacks: repeated hits cannot restart this timer.
	_phase="corpse";_event=event_id;_death_count+=1;_death_frame=Engine.get_physics_frames()
	if not pop.daily.retire_single_dead28(self,health):return _block("daily_retirement_failed")
	if not pop.residents.stop_single_dead28(self,_token):return _block("host_retirement_failed")
	pop._queue.cancel(pop.owners[source_id30])
	# Keep the authenticated corpse/contact owner alive, but remove periodic health,
	# effects and incident-candidate dispatch. The one NPC has no active owner now.
	pop.hit_owners.erase(health)
	_schedule30(_corpse_s)
	print("DSH_DEATH28 ",JSON.stringify(snapshot()))
	return true

func _block(reason: String) -> bool:
	_phase="blocked";_reason=reason
	if is_instance_valid(_timer):_timer.stop()
	# A failed integration or occupied spawn must remain cold. Never leave a
	# partially configured fresh life searching while the receipt says blocked.
	var pop: RefCounted=_pop()
	if pop!=null:
		if pop.daily!=null:
			if pop.daily.has_method("forget_physical30") and pop.daily._lives.has(source_id30):pop.daily.forget_physical30(source_id30,pop.daily._lives[source_id30])
			if pop.daily._lives.has(source_id30):pop.daily._lives[source_id30].dispose()
			if pop.daily._accounts.has(source_id30):pop.daily._accounts[source_id30].dispose()
			pop.daily._lives.erase(source_id30);pop.daily._accounts.erase(source_id30);pop.daily._health.erase(source_id30)
			pop.daily._dsh_ids.clear();pop.daily._cursor=0
		if is_instance_valid(_health):
			pop.hit_owners.erase(_health)
			if _health.get("_row").get("dead",false):pop.residents.stop_single_dead28(self,_token)
			else:_health.dispose()
		if pop.owners.has(source_id30):pop._queue.cancel(pop.owners[source_id30])
	print("DSH_DEATH28 ",JSON.stringify(snapshot()))
	return false

func _on_timer() -> void:
	var pop: RefCounted=_pop()
	var scene: Node3D=_scene.get_ref() if _scene!=null else null
	if pop==null or not is_instance_valid(scene) or not scene.is_inside_tree():dispose();return
	var manager: Node=_mass_manager30.get_ref() if _mass_manager30!=null else null
	if _mass_manager30!=null:
		if not is_instance_valid(manager):dispose();return
		if not manager.admit_respawn30(self):_schedule30(.06);return
	if _phase=="corpse":
		if not pop.residents.physical_life_current(_token) or pop.owners.get(source_id30)!=pop.residents._records[source_id30].owner or not pop.owners[source_id30].dead:
			_block("corpse_generation_changed");return
		_new_owner=Queue.Owner.new(source_id30,_generation+1)
		if not pop.policy.replace_single_dead_owner28(self,pop.residents,_token,pop.owners[source_id30],_new_owner):
			_block("source_generation_transfer_refused");return
		# Full cold teardown before any new actor is admitted. The corpse's rigid
		# bodies and walking rig are disposed by their original host, not recycled.
		if not pop.residents.prepare_single_respawn28(self,_token,_new_owner):
			_block("host_generation_transfer_refused");return
		_health.dispose();_health=null
		pop.owners[source_id30]=_new_owner
		_phase="spawning";_attempts=0
	if _phase!="spawning":return
	_attempts+=1
	# One candidate per timer, bounded to the original location and a 2 m ring.
	# An occupied ring sleeps between rounds and may retry after the player leaves.
	var proposal: Vector3=_spawn
	var slot: int=(_attempts-1)%MAX_SPAWN_ATTEMPTS
	if slot>0:
		var angle: float=TAU*float(slot-1)/8.0
		proposal+=Vector3(cos(angle),0,sin(angle))*2.0
	var admission: Dictionary=pop.residents.admit_single_respawn28(self,_new_owner,proposal)
	if admission.get("status")!="IDLE":
		_reason="spawn_wait:"+str(admission.get("reason",""))
		_schedule30(2.0 if slot==MAX_SPAWN_ATTEMPTS-1 else .5)
		return
	var body: CharacterBody3D=pop.residents._records[source_id30].body
	var token: Dictionary=pop.residents.target_from_collider(body)
	var health:=Health.new()
	var linked: Dictionary=health.configure(pop.residents,token,_packet,_trust,scene.preview_weapons,{"marksman":0.0,"scope":"local_new_session","session_id":token.get("session_id","")})
	if not linked.get("ok",false):health.dispose();_block("fresh_health:"+str(linked));return
	_health=health;_token=token.duplicate();_generation=int(token.life_generation)
	_phase="alive";_reason=""
	if not health.bind_single_lifecycle28(self):_block("fresh_death_binding");return
	pop.residents._records[source_id30].walk_pause=Callable(health,"should_pause_walk")
	pop.hit_owners.append(health)
	if not pop._stream_register_daily(source_id30,health):
		pop.hit_owners.erase(health);_block("fresh_daily_binding");return
	var life: RefCounted=pop.daily._lives[source_id30]
	var account: RefCounted=pop.daily._accounts[source_id30]
	var hp: Dictionary=health.get("_row")
	var wallet: Dictionary=account.snapshot().get("account",{})
	_birth_receipt={"hp":hp.get("hp"),"max_hp":hp.get("max_hp"),"energy":life.get("_energy"),"cash":wallet.get("cash"),"pending":life.get("_dsh_task_queue").duplicate(),"body_id":body.get_instance_id(),"health_id":health.get_instance_id(),"life_id":life.get_instance_id(),"account_id":account.get_instance_id(),"generation":_generation,"position":body.global_position}
	_birth_receipt["queue_owner_id"]=_new_owner.get_instance_id()
	_birth_receipt["search_pending"]=_new_owner.search_pending
	_birth_receipt["continuation_empty"]=_new_owner.continuation==null and _new_owner.search_kind==null and _new_owner.request_at==null
	if float(hp.get("hp",-1))!=float(hp.get("max_hp",0)) or float(life.get("_energy"))!=100.0 or int(wallet.get("cash",-1))!=1000 or not life.get("_dsh_task_queue").is_empty() or _birth_receipt.search_pending or not _birth_receipt.continuation_empty:
		# Integration must use the fresh-life economy reset. Never forge those values.
		_block("fresh_life_reset_contract");return
	_respawn_count+=1;_respawn_frame=Engine.get_physics_frames();_new_owner=null
	print("DSH_RESPAWN28 ",JSON.stringify(snapshot()))

func snapshot() -> Dictionary:
	return {"phase":_phase,"reason":_reason,"id":source_id30,"generation":_generation,"event":_event,"death_frame":_death_frame,"respawn_frame":_respawn_frame,"death_count":_death_count,"respawn_count":_respawn_count,"corpse_seconds":_corpse_s,"spawn_attempts":_attempts,"birth":_birth_receipt.duplicate(true),"per_frame_callback":false}

func dispose() -> void:
	if _phase=="disposed":return
	_phase="disposed"
	if is_instance_valid(_timer):_timer.stop()
	if is_instance_valid(_health) and _pop()!=null and not _pop().hit_owners.has(_health):_health.dispose()
	_health=null;_population=null;_scene=null;_mass_manager30=null;_packet=PackedByteArray();_trust.clear();_token.clear()
	queue_free()
