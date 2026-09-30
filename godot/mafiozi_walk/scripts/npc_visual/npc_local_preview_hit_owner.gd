extends RefCounted
const HitImpulse=preload("res://scripts/npc_visual/npc_hit_impulse.gd")
const MEDICAL_IMPULSE_MAX_NS:=75.0
const HeadZone=preload("res://scripts/npc_visual/npc_head_zone.gd")
var _head_zone: RefCounted
var last_head_zone: Dictionary={}
const POINT_SHARE:=0.10
const POINT_MAX_NS:=2.5
var _point_consumed: Dictionary={}
var _native_impulse_context: Dictionary={}
var last_impulse: Dictionary={}
var last_source_path_request: Dictionary={}
## Explicit NEW_SESSION_BOOTSTRAP combat owner for one already admitted resident.
## Owns ONLY new local HP/medical/death state. Never authenticates a save/server.
## Deferred world/social effects remain in pending_effects, not fake callbacks.
const Blood=preload("res://scripts/npc_visual/npc_blood_adapter.gd")
var blood: RefCounted
const Marks=preload("npc_postmortem_hit_marks_adapter.gd")
var marks: RefCounted
const Provider=preload("res://scripts/npc_visual/npc_preview_source_provider.gd")
const Adapter=preload("res://scripts/npc_visual/npc_ordinary_hit_lifecycle.gd")
const Rules=preload("res://scripts/weapons/weapon_hit_rules.gd")
const SINGLE_HIT := ["tt_pistol","deagle","golden_colt","revolver","uzi","golden_uzi","tommy_gun","nagan","ak74","m16","sniper"]
const PELLET_HIT := ["shotgun","sawn_off"]
static var _registries: Dictionary={}
var _host: RefCounted
var _weapons: Node
var _effects: RefCounted
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
var last_contact: Dictionary={}
var _serial:=0
var _last_player:=Vector3.ZERO
var _registry_key:=0
var _last_hit_us:=0
var _postmortem_receipt: Dictionary={}
var last_postmortem: Dictionary={}
var postmortem_count:=0
var _native_terminal_batch: Array[Dictionary]=[]

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
	_host=host; _token=token.duplicate(); _weapons=weapons; _effects=weapons.effects; _marksman=source_player_stats.marksman
	_native_terminal_batch=_effects._resolutions
	var registry_key: int=weapons.get_instance_id()
	if not _registries.has(registry_key):
		_rng.randomize()
		_registries[registry_key]={"shots":{},"consumers":0,"marksman":_marksman,"session_id":token.session_id,"start_us":Time.get_ticks_usec(),"rng":_rng,"owners":{},"nagan_last_at_ms":0.0,"nagan_chain":0,"pellet_closed":0,"pellet_cancelled":0,"cleanup_at_ms":0.0,"current_damage":{}}
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
	registry.owners[token.source_id]=weakref(self)
	weapons.shot_emitted.connect(_on_shot)
	_effects.cosmetic_impact.connect(_on_native_impact)
	if _effects.has_signal("projectile_resolved"): _effects.connect("projectile_resolved",_on_projectile_resolved)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_visual/session/prepared/manifest.json"))
	var entry: Dictionary={}
	for manifest_item: Dictionary in manifest.entries:
		if manifest_item.entry.bridge_id==_token.render_id: entry=manifest_item.entry
	marks=Marks.new()
	if not marks.configure(_host,_token,self,weapons.scene,entry):
		dispose(); return {"ok":false,"reason":"marks_original_binding"}
	blood=Blood.new()
	if not blood.configure(_host,_token,self,weapons.scene,entry):
		dispose(); return {"ok":false,"reason":"blood_original_binding"}
	_head_zone=HeadZone.new()
	if not _head_zone.configure(_token.rig): dispose(); return {"ok":false,"reason":"original_head_skin_required"}
	_host._records[_token.source_id]["walk_pause"]=Callable(self,"should_pause_walk")
	return {"ok":true,"scope":"new_local_session_hp","source_callbacks_complete":false,"pellet_receipts_bound":_effects.has_signal("projectile_resolved"),"gaps":["social_execution","blood_pending_rendered_acceptance","medical_crawl_ambulance","murder_authority","resident_respawn","additional_penetrating_targets","nagan_fire_cadence_owner"]}

func _now() -> float:
	return float(Time.get_ticks_usec()-_start_us)/1000.0+1.0

func _current(binding: Dictionary) -> Dictionary:
	if not _ready or binding!=_binding or not is_instance_valid(_weapons) or not _weapons.is_inside_tree() or _weapons.effects!=_effects or not is_instance_valid(_effects) or not _effects._live() or not _host.physical_life_current(_token): return {}
	return {"scope":"local_walk_ordinary","binding":_binding,"owner_instance_id":get_instance_id(),"row":_row}

func _service(row: Dictionary,p: Dictionary,name: String) -> Variant:
	match name:
		"clock": return _now()
		"random": return _rng.randf()
		"admit_contact": return _admitting.duplicate(true) if p.event_id==_admitting.get("event_id") else null
		"path":
			# Preserve the source's .09-cell request without instantly sliding the
			# native standing collider. Physical impact owns the visible movement.
			if _current(_binding).is_empty(): return false
			last_source_path_request=p.duplicate(true)
			return false
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

func _on_shot(shot: Dictionary,muzzle: Dictionary,_camera_origin: Vector3,camera_direction: Vector3) -> void:
	if _current(_binding).is_empty() or not muzzle.get("origin") is Vector3 or not muzzle.origin.is_finite(): return
	var pellets: bool=shot.get("weaponId") in PELLET_HIT
	if shot.get("weaponId") not in SINGLE_HIT and not pellets and shot.get("weaponId")!="rpg": return
	if (not _effects.has_signal("projectile_resolved") or not _effects.has_method("resolution_epoch")): return # Required native terminal proof, not a timer.
	_native_terminal_batch=_effects._resolutions
	_cleanup_shots()
	var id: String=str(shot.get("shotId",str(shot.weaponId)+":"+str(shot.get("sequence",""))))
	if _shots.has(id) or not shot.get("projectiles") is Array or shot.projectiles.size()!=(7 if pellets else 1): return
	var indices: Dictionary={}
	for p: Variant in shot.projectiles:
		if not p is Dictionary or not Rules._finite(p.get("index")) or p.index!=floor(p.index) or p.index<0 or p.index>=shot.projectiles.size() or indices.has(int(p.index)): return
		indices[int(p.index)]=true
	if _shots.size()>=128: _shots.erase(_shots.keys()[0])
	var registry: Dictionary=_registries[_registry_key]
	var at:=_now()
	# Original JS short-circuit does not consume a random sample for a Nagan duel.
	var duel: bool=shot.weaponId=="nagan" and at-registry.nagan_last_at_ms>=800
	var modifiers:=Rules.accepted_shot_modifiers(shot.weaponId,at,registry.nagan_last_at_ms,registry.nagan_chain,0.0 if duel else _rng.randf())
	if not modifiers.ok: return
	registry.nagan_last_at_ms=modifiers.nagan_last_at_ms; registry.nagan_chain=modifiers.nagan_chain
	registry.current_damage={"marksman":_marksman,"critical":modifiers.critical,"critical_multiplier":modifiers.critical_multiplier}
	var base_direction:=Vector3(camera_direction.x,0,camera_direction.z)
	if base_direction.length_squared()>0.000001: base_direction=base_direction.normalized()
	_shots[id]={"weapon_id":shot.weaponId,"muzzle":muzzle.origin,"at_ms":at,"modifiers":modifiers,"used":shot.weaponId=="rpg","pellets":pellets,"indices":indices,"terminals":{},"targets":{},"base_direction":base_direction,"cancelled":false,"producerEpoch":_effects.resolution_epoch(),"postmortem_tickets":{},"native_terminals":{}}

## Source RPG blast reads the current accepted global modifiers at impact.
## A launch is context-only here; the separate RPG gate owns native blast proof.
func current_damage_context() -> Dictionary:
	if _current(_binding).is_empty() or not _registries.has(_registry_key): return {}
	return _registries[_registry_key].current_damage.duplicate()

func _cleanup_shots() -> void:
	if not _registries.has(_registry_key): return
	var registry: Dictionary=_registries[_registry_key]
	var now:=_now()
	if now<registry.cleanup_at_ms: return
	registry.cleanup_at_ms=now+250.0
	var epoch: int=_effects.resolution_epoch() if _effects.has_method("resolution_epoch") else -1
	# Shared bounded scan, once per session interval (not once per actor/frame).
	# Timeout only discards incomplete receipts; it can never commit damage.
	for id: String in _shots.keys():
		var shot: Dictionary=_shots[id]
		if now-shot.at_ms>15000 or (shot.pellets and shot.producerEpoch!=epoch):
			shot.used=true; shot.targets.clear(); _shots.erase(id)

func _owns_collider(collider: Variant) -> bool:
	if not is_instance_valid(collider): return false
	if collider==_token.body: return true
	if _host._ragdolls.has(_token.source_id):
		for segment: Variant in _host._ragdolls[_token.source_id].owned_bodies():
			if collider==segment: return true
	return false

static func _contact_shape(impact: Dictionary) -> bool:
	return impact.get("point") is Vector3 and impact.get("normal") is Vector3 and impact.get("direction") is Vector3 and impact.point.is_finite() and impact.normal.is_finite() and impact.direction.is_finite() and impact.normal.length_squared()>.5 and impact.direction.length_squared()>.5

func _on_native_impact(impact: Dictionary) -> void:
	if _current(_binding).is_empty() or not _shots.has(str(impact.get("shotId",""))): return
	var shot: Dictionary=_shots[impact.shotId]
	_native_terminal_batch=_effects._resolutions
	_capture_postmortem_native(impact,shot)
	if _row.get("dead",false): return
	if shot.pellets or shot.used or _now()-shot.at_ms>15000 or impact.get("weaponId")!=shot.weapon_id: return
	if not _contact_shape(impact) or not _owns_collider(impact.get("collider")): return
	var distance: float=shot.muzzle.distance_to(impact.point)/4.1
	var profile:=Rules.damage_profile(shot.weapon_id)
	if distance>float(profile.range)+.05: return
	shot.used=true
	var damage:=Rules.current_shot_damage(Rules.damage_at(shot.weapon_id,distance),_marksman,shot.modifiers.critical,shot.modifiers.critical_multiplier)
	var direction: Vector3=impact.direction
	if Rules.balance_id(shot.weapon_id) in Rules.PENETRATING:
		# Native pool stops at the first collision. This is ONLY source index0;
		# never fabricate an additional penetration target behind it.
		var first:=Rules.penetrating_damage(shot.weapon_id,distance,0,shot.modifiers.critical,shot.modifiers.critical_multiplier)
		if not first.ok: return
		damage=first.damage; direction*=first.direction_multiplier
	var zone:=_head_contact(shot,impact)
	_apply_hit(str(impact.shotId),shot,damage,direction,zone.get("point",impact.point),zone.get("normal",impact.normal),zone.get("direction",Vector3.ZERO),zone)

func _apply_hit(shot_id: String,shot: Dictionary,damage: int,direction: Vector3,point: Vector3,normal: Vector3,physical_direction: Vector3=Vector3.ZERO,zone: Dictionary={}) -> void:
	if _current(_binding).is_empty() or _row.get("dead",false): return
	var started_us:=Time.get_ticks_usec()
	var body: CharacterBody3D=_token.body
	_row.r=(body.global_position.z+45.1)/4.1; _row.c=(body.global_position.x+395.65)/4.1
	_last_player=_weapons.player.global_position
	_serial+=1
	var id: String=_token.source_id+":"+str(_serial)+":"+shot_id
	_admitting={"event_id":id,"binding":_binding.duplicate(true),"hit":{"weapon_id":shot.weapon_id,"damage":damage,"dir_r":direction.z,"dir_c":direction.x,"player_r":(_last_player.z+45.1)/4.1,"player_c":(_last_player.x+395.65)/4.1,"source":{"kind":"player","uid":"local"}}}
	if zone.get("zone")=="head" and zone.get("proof")=="native_owned_hit_then_first_anatomical_skin_triangle":
		_admitting.hit["hit_zone"]="head"
		_admitting.hit["head_policy"]="user_requested_headshot_final_v1"
		last_head_zone=zone.duplicate(true)
	var contact_actor_transform: Transform3D=body.global_transform
	last_result=_adapter.hit(id,_admitting.hit)
	_admitting={}
	if not last_result.ok or not last_result.get("applied",false): return
	last_contact={"event_id":id,"incoming_direction":(direction if physical_direction==Vector3.ZERO else physical_direction).normalized(),"actor_transform_at_impact":contact_actor_transform,"point":point,"normal":normal,"shot_id":shot_id,"weapon_id":shot.weapon_id,"source_id":_token.source_id,"life_generation":_token.life_generation}
	if not zone.is_empty(): last_contact["projectile_index"]=zone.get("projectile_index",0)
	if blood!=null: blood.receive(id,point,normal)
	if marks!=null: marks.receive(id,point,normal)
	_native_impulse_context={"event_id":id,"value":HitImpulse.bullet(shot.weapon_id,shot.muzzle.distance_to(point),damage,direction if physical_direction==Vector3.ZERO else physical_direction,_row.get("_invulnerable",false))}
	_publish_physical(id,last_result.reason,point)
	_native_impulse_context={}
	_last_hit_us=Time.get_ticks_usec()-started_us

## One completed native pellet terminal per accepted p.index. A cosmetic hit
## alone is insufficient: misses/cancellation must also settle the seven rays.
func _on_projectile_resolved(receipt: Dictionary) -> void:
	if _current(_binding).is_empty() or not _shots.has(receipt.get("shotId","")): return
	var shot: Dictionary=_shots[receipt.shotId]
	_remember_native_terminal(receipt,shot)
	if not shot.pellets:
		_resolve_postmortem_single(receipt,shot)
		return
	if not shot.pellets or shot.used or _now()-shot.at_ms>15000 or receipt.get("weaponId")!=shot.weapon_id: return
	if not receipt.get("producerEpoch") is int or receipt.producerEpoch!=shot.producerEpoch or shot.producerEpoch!=_effects.resolution_epoch():
		shot.used=true; shot.cancelled=true; shot.targets.clear(); return
	if not receipt.get("projectileIndex") is int or not receipt.get("projectileCount") is int or receipt.projectileCount!=7 or not shot.indices.has(receipt.projectileIndex): return
	var index: int=receipt.projectileIndex
	if shot.terminals.has(index): return
	if receipt.get("status") not in ["hit","miss","cancelled"]: return
	if receipt.status=="hit" and not _contact_shape(receipt): return
	shot.terminals[index]=receipt.status
	if shot.postmortem_tickets.has(index) and shot.postmortem_tickets[index].terminal!=receipt: shot.cancelled=true
	if receipt.status=="cancelled": shot.cancelled=true
	if receipt.status=="hit":
		var distance: float=shot.muzzle.distance_to(receipt.point)/4.1
		if distance>float(Rules.damage_profile(shot.weapon_id).range)+.05: shot.cancelled=true
		else:
			var registry: Dictionary=_registries[_registry_key]
			for ref: WeakRef in registry.owners.values():
				var candidate: Variant=ref.get_ref()
				if not is_instance_valid(candidate) or candidate._current(candidate._binding).is_empty() or not candidate._owns_collider(receipt.get("collider")): continue
				var id: String=candidate._token.source_id
				if not shot.targets.has(id): shot.targets[id]={"owner":ref,"binding":candidate._binding.duplicate(true),"distances":[],"point":receipt.point,"normal":receipt.normal,"physical_direction":receipt.direction}
				shot.targets[id].distances.append(distance)
				if not shot.targets[id].has("head_zone") and not candidate._row.get("dead",false):
					var zone: Dictionary=candidate._head_contact(shot,receipt)
					if zone.get("zone")=="head":
						# One selected native pellet owns the entire refined contact tuple.
						shot.targets[id]["head_zone"]=zone
						shot.targets[id].point=zone.point
						shot.targets[id].normal=zone.normal
						shot.targets[id].physical_direction=zone.direction
				break
	if shot.terminals.size()!=7: return
	shot.used=true # close before callbacks, including recursively emitted signals.
	var registry: Dictionary=_registries[_registry_key]
	registry.pellet_closed+=1
	if shot.cancelled: registry.pellet_cancelled+=1; shot.targets.clear(); return
	# Preserve existing live density: one selected genuine pellet per target.
	var cosmetic_targets: Dictionary={}
	for ticket: Dictionary in shot.postmortem_tickets.values():
		var cosmetic_owner: Variant=ticket.owner.get_ref()
		if not is_instance_valid(cosmetic_owner) or cosmetic_owner.marks==null or cosmetic_targets.has(cosmetic_owner.get_instance_id()): continue
		cosmetic_targets[cosmetic_owner.get_instance_id()]=true
		cosmetic_owner._commit_postmortem(ticket,shot)
	shot.postmortem_tickets.clear()
	for group: Dictionary in shot.targets.values():
		var target: Variant=group.owner.get_ref()
		if not is_instance_valid(target) or target._current(group.binding).is_empty(): continue
		var damage:=Rules.shotgun_damage(group.distances,_marksman,shot.modifiers.critical,shot.modifiers.critical_multiplier)
		if damage.ok: target._apply_hit(str(receipt.shotId),shot,damage.damage,shot.base_direction,group.point,group.normal,group.physical_direction,group.get("head_zone",{}))
	shot.targets.clear()

func _publish_physical(id: String,reason: String,point: Vector3) -> void:
	if reason not in ["final_death","medical_downed","bleedout"]: return
	var final: bool=reason!="medical_downed"
	var kind: String="final_death" if final else "source_medical_down"
	var body: CharacterBody3D=_token.body
	_events[id]={"id":id,"kind":kind,"confirmed":true,"death_key":str(_row.deadAt) if final else "","source_id":_token.source_id,"life_generation":_token.life_generation,"medical_downed":not final,"local_preview_hp_revision":last_result.get("revision",0),"already_solved_by_godot":true,"apply_again":false,"linear_velocity":body.velocity,"angular_velocity":Vector3.ZERO,"reference_point":point,"impulse_ns":Vector3.ZERO}
	var physical: RefCounted=_host._ragdolls[_token.source_id]
	var impulse:=Vector3.ZERO
	if reason in ["final_death","medical_downed"] and _native_impulse_context.get("event_id")==id and not _current(_binding).is_empty():
		var proposal: Dictionary=_native_impulse_context.value
		# Requests are bounded, physical velocities are never clamped.
		if proposal.get("ok",false) and last_result.get("ok",false) and last_result.get("applied",false) and not _row.get("_invulnerable",false):
			impulse=proposal.impulse_ns
			if reason=="medical_downed":impulse=impulse.limit_length(MEDICAL_IMPULSE_MAX_NS)
	if physical.status().mode=="IDLE":
		var point_impulse:=impulse.normalized()*minf(POINT_MAX_NS,impulse.length()*POINT_SHARE)
		var uniform_impulse:=impulse-point_impulse
		if impulse!=Vector3.ZERO:
			_events[id].impulse_ns=uniform_impulse
			_events[id].already_solved_by_godot=false
			_events[id].apply_again=true
		last_physical=_host.activate_physical(_token,id)
		if last_physical.get("ok",false) and impulse!=Vector3.ZERO:
			last_impulse={"event_id":id,"impulse_ns":impulse,"reason":reason,"source_id":_token.source_id,"life_generation":_token.life_generation,"phase":"initial","requested_total_ns":impulse,"uniform_ns":uniform_impulse,"point_ns":Vector3.ZERO,"point":point}
			last_impulse.impulse_ns=uniform_impulse
			# Same completed HP receipt and activated physical lease; native point
			# share is subtracted from uniform J, never added to the total budget.
			if not _point_consumed.has(id) and _adapter.receipt(id)==last_result and not _current(_binding).is_empty() and _host._ragdolls.get(_token.source_id)==physical and physical.status().mode=="ACTIVE":
				_point_consumed[id]=true
				var applied: Dictionary=physical._body.apply_impulse(point,point_impulse,id+":point")
				last_impulse["point_result"]=applied
				if applied.get("ok",false):
					last_impulse["point_lever_m"]=point-physical._body._bodies[applied.bone].global_position
					last_impulse["point_torque_ns_m"]=last_impulse.point_lever_m.cross(point_impulse)
					last_impulse.point_ns=point_impulse
					last_impulse.impulse_ns=uniform_impulse+point_impulse
	elif final:last_physical=_host.confirm_physical_death(_token,id)


func physical_event(request: Dictionary) -> Dictionary:
	if _current(_binding).is_empty() or request.get("mode")!="event" or not request.get("binding") is Dictionary or not _events.has(request.get("event_id","")): return {}
	for key: String in request.binding:
		if request.binding[key]!=_token.get(key): return {}
	return {"known":true,"completed":true,"accepted":true,"binding":request.binding.duplicate(),"event":_events[request.event_id].duplicate(true),"scope":"new_local_session_hp","source_callbacks_complete":false}

func step() -> void:
	if _current(_binding).is_empty(): return
	_native_terminal_batch=_effects._resolutions
	_cleanup_shots()
	if not _row.get("_medicalDowned",false) or _row.get("dead",false) or _now()<float(_row.get("_medicalBleedoutAt",0)): return
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
	if blood!=null: blood.dispose(); blood=null
	if marks!=null: marks.dispose(); marks=null
	_ready=false
	if _registry_key!=0 and _registries.has(_registry_key):
		var owners: Dictionary=_registries[_registry_key].owners
		if owners.has(_token.get("source_id","")) and owners[_token.source_id].get_ref()==self: owners.erase(_token.source_id)
		_registries[_registry_key].consumers-=1
		if _registries[_registry_key].consumers<=0: _registries.erase(_registry_key)
	_registry_key=0
	if is_instance_valid(_weapons):
		if _weapons.shot_emitted.is_connected(_on_shot): _weapons.shot_emitted.disconnect(_on_shot)
	if is_instance_valid(_effects):
		if _effects.cosmetic_impact.is_connected(_on_native_impact): _effects.cosmetic_impact.disconnect(_on_native_impact)
		if _effects.has_signal("projectile_resolved") and _effects.is_connected("projectile_resolved",_on_projectile_resolved): _effects.disconnect("projectile_resolved",_on_projectile_resolved)
	if _adapter!=null: _adapter.dispose()
	_adapter=null; _head_zone=null; _host=null; _weapons=null; _effects=null

## Geometry can refine only an existing accepted shot on this owned collider.
func _head_contact(shot: Dictionary,impact: Dictionary) -> Dictionary:
	if _head_zone==null or _row.get("_invulnerable",false) or _current(_binding).is_empty() or not _contact_shape(impact) or not _owns_collider(impact.get("collider")):return {}
	var physical: RefCounted=_host._ragdolls[_token.source_id]
	var excluded: Array[RID]=[_token.body.get_rid(),_weapons.player.get_rid()]
	excluded.append_array(physical._body.body_rids())
	var zone: Dictionary=_head_zone.classify(shot.muzzle,impact.direction,float(Rules.damage_profile(shot.weapon_id).range)*4.1,physical,_weapons.scene,excluded)
	if not zone.is_empty(): zone["projectile_index"]=impact.get("projectileIndex",0)
	return zone

## Local native cosmetic authority only. No HP service, death event, impulse or
## source revision is called here. A disabled walking capsule is never a corpse.
func _postmortem_context(collider: Variant) -> Dictionary:
	if not Thread.is_main_thread() or _current(_binding).is_empty() or _row.get("dead")!=true or not Rules._finite(_row.get("hp")) or _row.hp>0 or not Rules._finite(_row.get("deadAt")): return {}
	if not collider is RigidBody3D or not is_instance_valid(collider) or not collider.is_inside_tree() or collider.is_queued_for_deletion() or collider.collision_layer==0: return {}
	var physical: Variant=_host._ragdolls.get(_token.source_id)
	if not is_instance_valid(physical) or not physical._is_current(): return {}
	var status: Dictionary=physical.status()
	if status.get("mode")!="ACTIVE" or status.get("final_dead")!=true or str(status.get("death_key",""))!=str(_row.deadAt) or str(status.get("death_key","")).is_empty(): return {}
	if not _host.public_final_dead_contact_current(status.binding,physical) or collider not in physical.owned_bodies(): return {}
	# Pin identity without retaining the RefCounted host (whose event Callable
	# references this owner). Incomplete/cancelled tickets must not form a cycle.
	return {"physical_id":physical.get_instance_id(),"physical_binding":status.binding.duplicate(true),"death_key":status.death_key,"collider":collider,"collider_id":collider.get_instance_id(),"collider_rid":collider.get_rid(),"collider_parent":collider.get_parent(),"binding":_binding.duplicate(true)}

## Native producer queues the terminal before emitting cosmetic_impact. Capture
## that exact pending hit, so a cosmetic-only ray or invented index is insufficient.
## This is a local trusted-code contract, not hostile-script/server authentication.
func _capture_postmortem_native(impact: Dictionary,shot: Dictionary) -> void:
	if shot.used or _now()-shot.at_ms>15000 or impact.get("weaponId")!=shot.weapon_id or not _contact_shape(impact) or shot.producerEpoch!=_effects.resolution_epoch(): return
	var context:=_postmortem_context(impact.get("collider"))
	if context.is_empty() or shot.muzzle.distance_to(impact.point)/4.1>float(Rules.damage_profile(shot.weapon_id).range)+.05: return
	for native: Dictionary in _effects._resolutions:
		if native.get("status")!="hit" or native.get("shotId")!=impact.shotId or native.get("weaponId")!=shot.weapon_id or native.get("producerEpoch")!=shot.producerEpoch: continue
		if native.get("projectileCount")!=(7 if shot.pellets else 1) or not native.get("projectileIndex") is int or not shot.indices.has(native.projectileIndex): continue
		var same:=true
		for key: String in ["point","normal","direction","collider"]:
			if native.get(key)!=impact.get(key): same=false
		if not same or shot.postmortem_tickets.has(native.projectileIndex): continue
		shot.postmortem_tickets[native.projectileIndex]={"owner":weakref(self),"context":context,"terminal":native.duplicate(true)}

func _resolve_postmortem_single(terminal: Dictionary,shot: Dictionary) -> void:
	if shot.used or shot.pellets or _now()-shot.at_ms>15000 or terminal.get("weaponId")!=shot.weapon_id or terminal.get("producerEpoch")!=shot.producerEpoch or shot.producerEpoch!=_effects.resolution_epoch(): return
	if terminal.get("projectileIndex")!=0 or terminal.get("projectileCount")!=1 or terminal.get("status") not in ["hit","miss","cancelled"]: return
	# Only the actual dead target captured a ticket; other owner signal listeners
	# must not consume this shared shot first.
	if not shot.postmortem_tickets.has(0): return
	var ticket: Dictionary=shot.postmortem_tickets[0]
	if ticket.owner.get_ref()!=self: return
	shot.used=true
	shot.terminals[0]=terminal.status
	if terminal==ticket.terminal: _commit_postmortem(ticket,shot)
	shot.postmortem_tickets.clear()

func _commit_postmortem(ticket: Dictionary,shot: Dictionary) -> void:
	if not _postmortem_receipt.is_empty() or ticket.owner.get_ref()!=self or not shot.used or shot.cancelled or shot.producerEpoch!=_effects.resolution_epoch(): return
	if shot.native_terminals.size()!=(7 if shot.pellets else 1): return
	for index: int in shot.native_terminals:
		if shot.native_terminals[index].status!=shot.terminals.get(index): return
	var native: Dictionary=ticket.terminal
	if native.get("status")!="hit" or not _contact_shape(native) or _postmortem_context(native.get("collider"))!=ticket.context: return
	var id: String="postmortem:"+_token.source_id+":"+str(_token.life_generation)+":"+str(native.shotId)+":"+str(native.projectileIndex)
	_postmortem_receipt={"event_id":id,"kind":"authenticated_local_postmortem_cosmetic","binding":_binding.duplicate(true),"context":ticket.context.duplicate(true),"terminal":native.duplicate(true),"hp_applied":false,"server_authority":false}
	var started:=Time.get_ticks_usec()
	var rendered: bool=marks!=null and marks.receive_postmortem(id,native.point,native.normal)
	postmortem_count+=1
	last_postmortem={"event_id":id,"shot_id":native.shotId,"projectile_index":native.projectileIndex,"rendered":rendered,"cosmetic_us":Time.get_ticks_usec()-started,"death_key":ticket.context.death_key,"hp_applied":false,"server_authority":false}
	_postmortem_receipt.clear()

func postmortem_receipt(event_id: String) -> Dictionary:
	if _postmortem_receipt.get("event_id")!=event_id: return {}
	var native: Dictionary=_postmortem_receipt.terminal
	if _postmortem_context(native.get("collider"))!=_postmortem_receipt.context: return {}
	return _postmortem_receipt.duplicate(true)

## Keep an alias to the current producer batch, refreshed each owner frame and
## shot/cosmetic callback. Native drain moves that array aside and assigns a new
## empty queue; this retained array therefore proves miss/cancel as well as hit.
## If a nonstandard caller drains twice without owner.step, fail closed.
func _remember_native_terminal(terminal: Dictionary,shot: Dictionary) -> void:
	if shot.used or terminal not in _native_terminal_batch or terminal.get("producerEpoch")!=shot.producerEpoch or shot.producerEpoch!=_effects.resolution_epoch(): return
	if terminal.get("weaponId")!=shot.weapon_id or not terminal.get("projectileIndex") is int or not shot.indices.has(terminal.projectileIndex) or terminal.get("projectileCount")!=(7 if shot.pellets else 1): return
	if terminal.get("status") not in ["hit","miss","cancelled"]: return
	shot.native_terminals[terminal.projectileIndex]=terminal.duplicate(true)
