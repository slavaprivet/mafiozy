extends RefCounted
## Explicit NEW_SESSION_BOOTSTRAP combat owner for one already admitted resident.
## Owns ONLY new local HP/medical/death state. Never authenticates a save/server.
## Deferred world/social effects remain in pending_effects, not fake callbacks.
const Provider=preload("res://scripts/npc_visual/npc_preview_source_provider.gd")
const Adapter=preload("res://scripts/npc_visual/npc_ordinary_hit_lifecycle.gd")
const Rules=preload("res://scripts/weapons/weapon_hit_rules.gd")
const SINGLE_HIT := ["tt_pistol","deagle","golden_colt","revolver","uzi","golden_uzi","tommy_gun"]
static var _registries: Dictionary={}
var _host: RefCounted
var _weapons: Node
var _token: Dictionary={}
var _binding: Dictionary={}
var _row: Dictionary={}
var _adapter: RefCounted
var _rng:=RandomNumberGenerator.new()
var _marksman:=0.0
var _ready:=false
var _start_us:=0
var _shots: Dictionary={}
var _admitting: Dictionary={}
var _events: Dictionary={}
var pending_effects: Array[Dictionary]=[]
var last_result: Dictionary={}
var last_physical: Dictionary={}
var _serial:=0
var _last_player:=Vector3.ZERO
var _registry_key:=0
var _last_hit_us:=0

func configure(host: RefCounted, token: Dictionary, packet: PackedByteArray, trust: Dictionary, weapons: Node, source_player_stats: Dictionary) -> Dictionary:
	if _ready or not is_instance_valid(host) or not host.target_current(token) or not is_instance_valid(weapons) or not weapons.is_inside_tree() or not weapons.has_signal("shot_emitted"): return {"ok":false,"reason":"current_native_owners"}
	if not trust.get("accepted") is bool or not trust.accepted or not trust.get("sources") is Dictionary: return {"ok":false,"reason":"accepted_packet"}
	var loaded: Dictionary=Provider.load_verified(packet,str(trust.get("packet_sha256","")),trust.sources)
	if not loaded.ok or loaded.provider.session_receipt().session_id!=token.session_id: return {"ok":false,"reason":"verified_session"}
	var candidate: Dictionary={}
	for row: Dictionary in loaded.provider.candidates():
		if row.source_id==token.source_id: candidate=row
	if candidate.is_empty() or candidate.bridge_id!=token.render_id or candidate.descriptor_sha256!=token.descriptor_sha256: return {"ok":false,"reason":"original_actor"}
	if not Rules._finite(source_player_stats.get("marksman")) or source_player_stats.get("scope")!="local_new_session" or source_player_stats.get("session_id")!=token.session_id: return {"ok":false,"reason":"source_player_stats_required"}
	_row=candidate.source_raw.duplicate(true)
	if _row.get("dead",false) or _row.hp<=0 or _row.hp!=_row.max_hp or _row.get("_medicalDowned",false): return {"ok":false,"reason":"healthy_bootstrap_only"}
	# These richer roles require their actual combat/surrender owner.
	if candidate.source_id not in ["resident_72","resident_169","resident_252"] or _row.get("_arcKey","") not in ["housewife","student","pensioner"] or _row.get("_empireBoss",false) or _row.get("_empireCrew",false) or _row.get("_formerMercenary",false): return {"ok":false,"reason":"special_owner_required"}
	_host=host; _token=token.duplicate(); _weapons=weapons; _marksman=source_player_stats.marksman
	var registry_key: int=weapons.get_instance_id()
	if not _registries.has(registry_key):
		_rng.randomize()
		_registries[registry_key]={"shots":{},"consumers":0,"marksman":_marksman,"session_id":token.session_id,"start_us":Time.get_ticks_usec(),"rng":_rng}
	var registry: Dictionary=_registries[registry_key]
	if registry.marksman!=_marksman or registry.session_id!=token.session_id: return {"ok":false,"reason":"shared_shot_context"}
	registry.consumers+=1; _shots=registry.shots
	_registry_key=registry_key
	_row.source_id=token.source_id; _row.life_generation=token.life_generation
	_binding={"session_id":token.session_id,"source_id":token.source_id,"render_id":token.render_id,"life_generation":token.life_generation,"scope":"local_walk_ordinary","owner_instance_id":get_instance_id()}
	_start_us=registry.start_us; _rng=registry.rng; _ready=true
	_adapter=Adapter.new()
	var services:={}
	for name: String in Adapter.REQUIRED: services[name]=Callable(self,"_service").bind(name)
	var configured: Dictionary=_adapter.configure(_binding,Callable(self,"_current"),services)
	if not configured.ok: dispose(); return configured
	var prepared: Dictionary=host.prepare_physical(token,Callable(self,"physical_event"))
	if not prepared.ok: dispose(); return prepared
	weapons.shot_emitted.connect(_on_shot)
	weapons.effects.cosmetic_impact.connect(_on_native_impact)
	return {"ok":true,"scope":"new_local_session_hp","source_callbacks_complete":false,"gaps":["social_execution","blood_rendering","medical_crawl_ambulance","murder_authority","resident_respawn","penetrating_and_shotgun_hits"]}

func _now() -> float:
	return float(Time.get_ticks_usec()-_start_us)/1000.0+1.0

func _current(binding: Dictionary) -> Dictionary:
	if not _ready or binding!=_binding or not is_instance_valid(_weapons) or not _weapons.is_inside_tree() or not _host.physical_life_current(_token): return {}
	return {"scope":"local_walk_ordinary","binding":_binding,"owner_instance_id":get_instance_id(),"row":_row}

func _service(row: Dictionary,p: Dictionary,name: String) -> Variant:
	match name:
		"clock": return _now()
		"random": return _rng.randf()
		"admit_contact": return _admitting.duplicate(true) if p.event_id==_admitting.get("event_id") else null
		"path":
			# This callback checks real source admission AND native collision before
			# a body movement. It does not replace either with a boolean assertion.
			var body: CharacterBody3D=_token.body
			var to:=Vector3(float(p.c)*4.1-395.65,body.global_position.y,float(p.r)*4.1-45.1)
			var record: Dictionary=_host._records[_token.source_id]
			if _host._physical_occupied(_token.source_id): return false
			if not _host._source_admits(to,record,"hit_knockback") or not _host._physical_clear(to,[body.get_rid()]) or not _host._owned_clear(to,_token.source_id): return false
			if body.test_move(body.global_transform,to-body.global_position): return false
			body.global_position=to; return true
		"aggression": row._relation=clampf(float(row.get("_relation",0))+1,-2,2); row._relUpdAt=_now(); return true
		"civilian": return true # configure admits verified ordinary three only.
		"surrender": return false # bandit/formerMerc excluded at configure.
		"bleeding":
			var now:=_now()
			row._lastHitAt=now; row._bloodDirR=p.dir_r; row._bloodDirC=p.dir_c if p.dir_c!=0 else 1
			row._bleedUntil=maxf(float(row.get("_bleedUntil",0)),now+minf(9000,3200+p.damage*42))
			row._bleedSeverity=maxf(float(row.get("_bleedSeverity",0)),minf(1.6,.45+p.damage/55))
		"fatal_record":
			# No manufactured original _deathRecord20; this separate request records
			# the required cause for its eventual original owner.
			_queue(name,p); return false
	_queue(name,p)
	return "queued_local_effect_not_source_execution"

func _queue(name: String,p: Dictionary) -> void:
	if pending_effects.size()>=256: pending_effects.pop_front()
	pending_effects.append({"service":name,"source_id":_token.source_id,"life_generation":_token.life_generation,"at_ms":_now(),"payload":p.duplicate(true),"executed":false})

func _on_shot(shot: Dictionary,muzzle: Dictionary,_camera_origin: Vector3,_camera_direction: Vector3) -> void:
	if _current(_binding).is_empty() or shot.get("weaponId") not in SINGLE_HIT or not muzzle.get("origin") is Vector3: return
	var id: String=str(shot.get("shotId",str(shot.weaponId)+":"+str(shot.get("sequence",""))))
	if _shots.has(id) or not shot.get("projectiles") is Array or shot.projectiles.size()!=1: return
	if _shots.size()>=128: _shots.erase(_shots.keys()[0])
	var modifiers:=Rules.accepted_shot_modifiers(shot.weaponId,_now(),0,0,_rng.randf())
	if not modifiers.ok: return
	_shots[id]={"weapon_id":shot.weaponId,"muzzle":muzzle.origin,"at_ms":_now(),"modifiers":modifiers,"used":false}

func _on_native_impact(impact: Dictionary) -> void:
	if _current(_binding).is_empty() or not _shots.has(str(impact.get("shotId",""))): return
	var shot: Dictionary=_shots[impact.shotId]
	if shot.used or _now()-shot.at_ms>15000 or impact.get("weaponId")!=shot.weapon_id: return
	if not impact.get("point") is Vector3 or not impact.get("normal") is Vector3 or not impact.get("direction") is Vector3 or not impact.point.is_finite() or not impact.normal.is_finite() or impact.normal.length_squared()<.5: return
	# The native projectile owner emits after its actual closest-hit ray; accept
	# only this exact resident's walker or one of its owned rigid segments.
	var collider: Variant=impact.get("collider")
	var own: bool=collider==_token.body
	if not own and _host._ragdolls.has(_token.source_id):
		var physical: RefCounted=_host._ragdolls[_token.source_id]
		for segment: Variant in physical._body._bodies.values():
			if collider==segment: own=true; break
	if not own: return
	var distance: float=shot.muzzle.distance_to(impact.point)/4.1
	var profile:=Rules.damage_profile(shot.weapon_id)
	if distance>float(profile.range)+.05: return
	shot.used=true
	var started_us:=Time.get_ticks_usec()
	var body: CharacterBody3D=_token.body
	_row.r=(body.global_position.z+45.1)/4.1; _row.c=(body.global_position.x+395.65)/4.1
	_last_player=_weapons.player.global_position
	_serial+=1
	var id: String=_token.source_id+":"+str(_serial)+":"+str(impact.shotId)
	var damage:=Rules.current_shot_damage(Rules.damage_at(shot.weapon_id,distance),_marksman,shot.modifiers.critical,shot.modifiers.critical_multiplier)
	var direction: Vector3=impact.direction
	_admitting={"event_id":id,"binding":_binding.duplicate(true),"hit":{"weapon_id":shot.weapon_id,"damage":damage,"dir_r":direction.z,"dir_c":direction.x,"player_r":(_last_player.z+45.1)/4.1,"player_c":(_last_player.x+395.65)/4.1,"source":{"kind":"player","uid":"local"}}}
	last_result=_adapter.hit(id,_admitting.hit)
	_admitting={}
	if not last_result.ok: return
	_publish_physical(id,last_result.reason,impact.point)
	_last_hit_us=Time.get_ticks_usec()-started_us

func _publish_physical(id: String,reason: String,point: Vector3) -> void:
	if reason not in ["final_death","medical_downed","bleedout"]: return
	var final: bool=reason!="medical_downed"
	var kind: String="final_death" if final else "source_medical_down"
	var body: CharacterBody3D=_token.body
	_events[id]={"id":id,"kind":kind,"confirmed":true,"death_key":str(_row.deadAt) if final else "","source_id":_token.source_id,"life_generation":_token.life_generation,"medical_downed":not final,"local_preview_hp_revision":last_result.get("revision",0),"already_solved_by_godot":true,"apply_again":false,"linear_velocity":body.velocity,"angular_velocity":Vector3.ZERO,"reference_point":point,"impulse_ns":Vector3.ZERO}
	var physical: RefCounted=_host._ragdolls[_token.source_id]
	if physical.status().mode=="IDLE": last_physical=_host.activate_physical(_token,id)
	elif final: last_physical=_host.confirm_physical_death(_token,id)

func physical_event(request: Dictionary) -> Dictionary:
	if _current(_binding).is_empty() or request.get("mode")!="event" or not request.get("binding") is Dictionary or not _events.has(request.get("event_id","")): return {}
	for key: String in request.binding:
		if request.binding[key]!=_token.get(key): return {}
	return {"known":true,"completed":true,"accepted":true,"binding":request.binding.duplicate(),"event":_events[request.event_id].duplicate(true),"scope":"new_local_session_hp","source_callbacks_complete":false}

func step() -> void:
	if _current(_binding).is_empty() or not _row.get("_medicalDowned",false) or _row.get("dead",false) or _now()<float(_row.get("_medicalBleedoutAt",0)): return
	_serial+=1
	var id: String=_token.source_id+":bleedout:"+str(_serial)
	last_result=_adapter.tick_medical(id)
	if last_result.get("ok",false) and last_result.get("applied",false): _publish_physical(id,"bleedout",_token.body.global_position)

func snapshot() -> Dictionary:
	return {"scope":"new_local_session_hp","row":_row.duplicate(true),"last_result":last_result.duplicate(true),"physical":last_physical.duplicate(true),"last_hit_us":_last_hit_us,"pending_effects":pending_effects.duplicate(true),"server_authority":false,"source_callbacks_complete":false}

## Read-only source idle gate. Default uses the same shared session clock as HP.
## Native host retains its own lifetime check and owns navigation/gait writes.
## It must not use a visual flinch timer to clear medical-down or revive death.
func should_pause_walk(source_now_ms: float = -1.0) -> bool:
	if not _ready: return true
	if _row.get("dead",false) or _row.get("_medicalDowned",false) or _row.get("_forcedCrawl",false): return true
	var now: float=_now() if source_now_ms==-1.0 else source_now_ms
	if not is_finite(now) or now<0: return true
	return now<float(_row.get("idleUntil",0.0))

func dispose() -> void:
	_ready=false
	if _registry_key!=0 and _registries.has(_registry_key):
		_registries[_registry_key].consumers-=1
		if _registries[_registry_key].consumers<=0: _registries.erase(_registry_key)
	_registry_key=0
	if is_instance_valid(_weapons):
		if _weapons.shot_emitted.is_connected(_on_shot): _weapons.shot_emitted.disconnect(_on_shot)
		if is_instance_valid(_weapons.effects) and _weapons.effects.cosmetic_impact.is_connected(_on_native_impact): _weapons.effects.cosmetic_impact.disconnect(_on_native_impact)
	if _adapter!=null: _adapter.dispose()
	_adapter=null; _host=null; _weapons=null
