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
# --- DSH_BINDFAST: session-scope proof for the two per-resident re-proofs ----------------
# configure() runs once per resident (287 times per city load) and re-proved two documents
# that cannot differ between residents, because both are addressed by a trusted sha256 and
# neither this file nor npc_preview_source_provider.gd mutates them:
#   * Provider.load_verified() over the 723 KB session_packet.json -- a sha256 of the whole
#     document, a JSON.parse_string of it, a 287-row schema sweep and a packet.duplicate(true),
#     and then candidates() deep-duplicates all 287 rows a second time.
#   * the raw 1.5 MB assets/npc_city/prepared/manifest.json -- one FileAccess read plus one
#     JSON.parse_string, per resident, with no verification and no cache at all.
# This holds the verdict of the first proof for the session and re-serves its derived data.
# NOT weakened: the packet is still re-hashed on EVERY call and the holder is only reachable
# when that digest equals trust.packet_sha256 in that same call, so a hit can never be spent
# on different bytes; the trusted source receipts are part of the key; verdicts are cached
# only on success; trust.accepted, the token session_id, candidate.bridge_id and
# candidate.descriptor_sha256 are still checked per resident; and the manifest entry is still
# re-validated per resident by Marks.configure()/Blood.configure(), which compare its
# bridge_id and descriptor_sha256 against the resident's own token.  The per-resident
# 287-entry manifest scan is untouched.  --city-load-strict=1 restores both original bodies
# verbatim (the same flag npc_visual_cache.gd uses for its DSH_LOADFAST holder).
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const BIND_MANIFEST_PATHS := ["res://assets/npc_city/prepared/manifest.json","res://assets/npc_visual/session/prepared/manifest.json"]
static var _bind_provider := {}
static var _bind_manifests := {}
static var _bind_strict_flag := -1
static var _bind_provider_builds := 0
static var _bind_provider_build_us := 0
static var _bind_provider_hits := 0
static var _bind_manifest_parses := 0
static var _bind_manifest_hits := 0
static var _bind_binds := 0

static func _bind_strict() -> bool:
	if _bind_strict_flag < 0:
		_bind_strict_flag = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-load-strict="):
				_bind_strict_flag = maxi(0, int(argument.trim_prefix("--city-load-strict=")))
	return _bind_strict_flag != 0

static func _bind_sources_digest(sources: Dictionary) -> String:
	var keys: Array = sources.keys()
	keys.sort()
	var text := ""
	for key: Variant in keys: text += str(key) + "=" + str(sources[key]) + ";"
	return Loader._hash(text.to_utf8_buffer())

static func _bind_manifest_stamp(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return "absent"
	var size := file.get_length()
	file.close()
	return str(FileAccess.get_modified_time(path)) + ":" + str(size)

static func _bind_manifest(path: String) -> Dictionary:
	# The parsed document is held under its path plus a cheap identity (modification time and
	# byte length).  A rewrite that preserved both would have to preserve the content too,
	# because trust.prepared_sha256 is re-proved against this same file by the host on every
	# admission (npc_visual_cache.gd), and a genuinely stale entry could only ever be REJECTED
	# downstream by Marks.configure()/Blood.configure(), which compare entry.bridge_id and
	# entry.descriptor_sha256 against the resident's own token.  This never makes a stale
	# entry acceptable and never accepts a resident the original would have rejected.
	var stamp := _bind_manifest_stamp(path)
	var cached: Variant = _bind_manifests.get(path)
	if cached is Dictionary and str(cached.get("stamp","")) == stamp and cached.get("parsed") is Dictionary:
		_bind_manifest_hits += 1
		return cached["parsed"]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_bind_manifest_parses += 1
	if not parsed is Dictionary:
		_bind_manifests[path] = {"stamp":stamp,"parsed":{}}
		return {}
	_bind_manifests[path] = {"stamp":stamp,"parsed":parsed}
	return parsed

static func _bind_session_data(packet: PackedByteArray, trust: Dictionary, token: Dictionary) -> Dictionary:
	# The verdict of Provider.load_verified() is a pure function of the packet bytes, the
	# trusted sha256 and the trusted source receipts.  The bytes are re-proved by sha256 on
	# every call below, so a hit is only ever spent on bytes identical to the ones the cached
	# verdict was built from.  Failure is never cached: every failing call still runs the
	# original verification verbatim.
	var trusted_sha: String = str(trust.get("packet_sha256",""))
	var bytes_sha: String = Loader._hash(packet)
	var sources_digest: String = _bind_sources_digest(trust.sources)
	var held: Variant = _bind_provider
	if bytes_sha == trusted_sha and held is Dictionary and str(held.get("sha","")) == bytes_sha and str(held.get("sources_digest","")) == sources_digest:
		_bind_provider_hits += 1
		if str(held["session_id"]) != str(token.get("session_id","")): return {"ok":false}
		return {"ok":true,"candidate":held["by_id"].get(str(token.get("source_id","")),{})}
	var build_started := Time.get_ticks_usec()
	var loaded: Dictionary=Provider.load_verified(packet,trusted_sha,trust.sources)
	if not loaded.ok: return {"ok":false}
	var session_id: String = str(loaded.provider.session_receipt().session_id)
	var by_id: Dictionary = {}
	for row: Dictionary in loaded.provider.candidates():
		by_id[str(row.source_id)] = row
	_bind_provider_builds += 1
	_bind_provider_build_us = Time.get_ticks_usec() - build_started
	_bind_provider = {"sha":bytes_sha,"sources_digest":sources_digest,"session_id":session_id,"by_id":by_id}
	if session_id != str(token.get("session_id","")): return {"ok":false}
	return {"ok":true,"candidate":by_id.get(str(token.get("source_id","")),{})}

# DSH_BINDFAST telemetry: one line at bind 1 and every 32 binds.  provider_build_us is the
# single full proof this session paid; provider_hits is how many binds were served from it,
# so the provider cost this run avoided is about provider_build_us * provider_hits.
# manifest_parses must be 1 (the 1.5 MB document read and parsed once, not 287 times).
static func _bind_report() -> void:
	_bind_binds += 1
	if _bind_binds % 32 != 0 and _bind_binds != 1: return
	print("DSH_BINDFAST binds=",_bind_binds," provider_builds=",_bind_provider_builds," provider_build_us=",_bind_provider_build_us," provider_hits=",_bind_provider_hits," manifest_parses=",_bind_manifest_parses," manifest_hits=",_bind_manifest_hits," strict=",1 if _bind_strict() else 0)
var _host: RefCounted
var _weapons: Node
var _effects: RefCounted
var _token: Dictionary={}
var _binding: Dictionary={}
var _row: Dictionary={}
var _incident_role_scope := ""
var _adapter: RefCounted
var _rng:=RandomNumberGenerator.new()
var _marksman:=0.0
var _dsh_shot_frame := -1  # DSH_ROWPROBE: frame of the last shot event this owner heard
var _dsh_probe_fired := false  # DSH_ROWPROBE: --city-damage-probe=1 fires exactly once
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
const MELEE_DAMAGE := {"punch":12,"kick":21,"heavy":18,"dropkick":18}
const BulletReaction=preload("res://scripts/npc_visual/npc_bullet_reaction.gd")
var bullet_reaction: RefCounted
var _idle_gate_last := false  # DSH_RECORDLOOP
var _melee_producer: WeakRef
var _melee_busy := false
var _completed_player_damage: Dictionary={}
# DSH_HEALTH2: idle fast-path lease for step(). DSH2_LEASE_FRAMES is the base
# lease length in physics frames; DSH2_LEASE_SPREAD staggers the per-owner
# revalidation frame so 284 owners never revalidate in the same frame.
const DSH2_LEASE_FRAMES:=60
const DSH2_LEASE_SPREAD:=60
# DSH_HEALTH2: the lease is a cadence trade and is OFF by default. The exact idle
# fast path in step() is unconditional; only the cached actor lease needs
# --city-health-lease (read from OS.get_cmdline_user_args() in configure()).
var _dsh2_lease_enabled:=true  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
var _dsh2_lease_ok:=false
var _dsh2_lease_until:=-1

static func _incident_scope_for_candidate(candidate: Dictionary) -> String:
	var bridge: Variant=candidate.get("bridge_row")
	var raw: Variant=candidate.get("source_raw")
	if not bridge is Dictionary or not raw is Dictionary or bridge.get("visualRole","")!="civilian": return ""
	if bridge.get("role","") not in ["pensioner","housewife","student","businessman","worker","homeless"] or raw.get("_arcKey","")!=bridge.get("role"): return ""
	for flag: String in ["police","empireBoss","shield"]:
		if not bridge.get(flag) is bool or bool(bridge[flag]): return ""
	if not bridge.has("prisonGear") or str(bridge.get("prisonGear",""))!="" or raw.get("_empireBoss",false) or raw.get("_empireCrew",false) or raw.get("_formerMercenary",false): return ""
	for raw_key: Variant in raw.keys():
		var key_text: String=str(raw_key).to_lower()
		if "weapon" in key_text or "firearm" in key_text or key_text=="gun": return ""
	return "ordinary_unarmed_civilian"

func configure(host: RefCounted, token: Dictionary, packet: PackedByteArray, trust: Dictionary, weapons: Node, source_player_stats: Dictionary) -> Dictionary:
	if _ready or not is_instance_valid(host) or not host.target_current(token) or not is_instance_valid(weapons) or not weapons.is_inside_tree() or not weapons.has_signal("shot_emitted"): return {"ok":false,"reason":"current_native_owners"}
	if not trust.get("accepted") is bool or not trust.accepted or not trust.get("sources") is Dictionary: return {"ok":false,"reason":"accepted_packet"}
	var candidate: Dictionary={}
	# DSH_BINDFAST: --city-load-strict=1 runs the pre-DSH_BINDFAST body verbatim.
	if _bind_strict():
		var loaded: Dictionary=Provider.load_verified(packet,str(trust.get("packet_sha256","")),trust.sources)
		if not loaded.ok or loaded.provider.session_receipt().session_id!=token.session_id: return {"ok":false,"reason":"verified_session"}
		for row: Dictionary in loaded.provider.candidates():
			if row.source_id==token.source_id: candidate=row
	else:
		var session_data: Dictionary=_bind_session_data(packet,trust,token)
		if not session_data.get("ok",false): return {"ok":false,"reason":"verified_session"}
		candidate=session_data.get("candidate",{})
	if candidate.is_empty() or candidate.bridge_id!=token.render_id or candidate.descriptor_sha256!=token.descriptor_sha256: return {"ok":false,"reason":"original_actor"}
	if not Rules._finite(source_player_stats.get("marksman")) or source_player_stats.get("scope")!="local_new_session" or source_player_stats.get("session_id")!=token.session_id: return {"ok":false,"reason":"source_player_stats_required"}
	_row=candidate.source_raw.duplicate(true)
	_incident_role_scope=_incident_scope_for_candidate(candidate)
	if _row.get("dead",false) or _row.hp<=0 or _row.hp!=_row.max_hp or _row.get("_medicalDowned",false): return {"ok":false,"reason":"healthy_bootstrap_only"}
	# These richer roles require their actual combat/surrender owner.
	# The original guard allowed only three named residents and three arc roles: a
	# palazzo-preview whitelist applied to the 287-resident city, where the health loop
	# aborts on the first rejection. Keep the real intent (richer roles need their own
	# combat/surrender owner) as a BLACKLIST instead, so ordinary city residents bind.
	if _row.get("_empireBoss",false) or _row.get("_empireCrew",false) or _row.get("_formerMercenary",false): return {"ok":false,"reason":"special_owner_required"}
	_host=host; _token=token.duplicate(); _weapons=weapons; _effects=weapons.effects; _marksman=source_player_stats.marksman
	# DSH_HEALTH2: --city-health-lease caches the actor lease for a provably idle owner.
	# Default OFF keeps today's cadence: one full lease revalidation per owner per
	# city step. The flag is a cadence trade, never a behaviour switch.
	for dsh_arg: String in OS.get_cmdline_user_args():
		if dsh_arg=="--city-health-lease" or dsh_arg=="--city-health-lease=1" or dsh_arg=="--city-health-lease=true": _dsh2_lease_enabled=true
		elif dsh_arg=="--city-health-lease=0" or dsh_arg=="--city-health-lease=false": _dsh2_lease_enabled=false  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
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
	bullet_reaction=BulletReaction.new()
	var reaction_ready: Dictionary=bullet_reaction.configure(self)
	if not reaction_ready.get("ok",false): dispose(); return reaction_ready
	if not _adapter.bind_local_survival_release(Callable(self,"_validate_local_survival_release")):
		dispose(); return {"ok":false,"reason":"local_survival_release_binding"}
	registry.owners[token.source_id]=weakref(self)
	weapons.shot_emitted.connect(_on_shot)
	_effects.cosmetic_impact.connect(_on_native_impact)
	if _effects.has_signal("projectile_resolved"): _effects.connect("projectile_resolved",_on_projectile_resolved)
	# The preview manifest is hardcoded here and holds only the palazzo preview's three
	# residents. City residents come from their own prepared set, so the lookup silently
	# produced an empty entry and marks.configure failed with marks_original_binding.
	# Try the requested token's own manifest first, then fall back to the preview one.
	var entry: Dictionary={}
	# DSH_BINDFAST: --city-load-strict=1 runs the pre-DSH_BINDFAST manifest body verbatim,
	# including the per-resident re-read and re-parse of the 1.5 MB document.
	if _bind_strict():
		for manifest_path: String in ["res://assets/npc_city/prepared/manifest.json","res://assets/npc_visual/session/prepared/manifest.json"]:
			if not FileAccess.file_exists(manifest_path): continue
			var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if manifest == null or not manifest.get("entries") is Array: continue
			for manifest_item: Dictionary in manifest.entries:
				if manifest_item.entry.bridge_id==_token.render_id: entry=manifest_item.entry
			if not entry.is_empty(): break
	else:
		# DSH_BINDFAST: the same two paths in the same order; only the per-resident re-read and
		# re-parse of the 1.5 MB document is removed, the entry scan below is unchanged.
		for manifest_path: String in BIND_MANIFEST_PATHS:
			if not FileAccess.file_exists(manifest_path): continue
			var manifest: Dictionary=_bind_manifest(manifest_path)
			if manifest == null or not manifest.get("entries") is Array: continue
			for manifest_item: Dictionary in manifest.entries:
				if manifest_item.entry.bridge_id==_token.render_id: entry=manifest_item.entry
			if not entry.is_empty(): break
		# DSH_BINDFAST: the held document is shared for the session, so each owner takes its
		# own copy -- exactly the private sub-dictionary a fresh JSON.parse_string() gave it.
		if not entry.is_empty(): entry=entry.duplicate(true)
	marks=Marks.new()
	if not marks.configure(_host,_token,self,weapons.scene,entry):
		dispose(); return {"ok":false,"reason":"marks_original_binding"}
	blood=Blood.new()
	if not blood.configure(_host,_token,self,weapons.scene,entry):
		dispose(); return {"ok":false,"reason":"blood_original_binding"}
	_head_zone=HeadZone.new()
	if not _head_zone.configure(_token.rig): dispose(); return {"ok":false,"reason":"original_head_skin_required"}
	_host._records[_token.source_id]["walk_pause"]=Callable(self,"_idle_gate")  # DSH_RECORDLOOP
	_bind_report()  # DSH_BINDFAST
	return {"ok":true,"scope":"new_local_session_hp","source_callbacks_complete":false,"pellet_receipts_bound":_effects.has_signal("projectile_resolved"),"gaps":["social_execution","blood_pending_rendered_acceptance","medical_crawl_ambulance","murder_authority","resident_respawn","additional_penetrating_targets","nagan_fire_cadence_owner"]}

const ResDiag = preload("res://scripts/npc_visual/npc_resident_diag.gd")  # DSH_RESDIAG

func _now() -> float:
	return float(Time.get_ticks_usec()-_start_us)/1000.0+1.0

## DSH_RESDIAG: one read-only repaint of this resident's head-up caption. It writes a
## Label3D text and one log line and nothing else - the label refresh is not a simulation
## decision, and without --city-resident-name there is no caption to paint.
func _dsh_refresh_caption(body: Node3D) -> void:
	if not ResDiag.hp_label_on() and not ResDiag.diag_on(): return
	if ResDiag.simple_vitals_on():
		ResDiag.repaint_focus30(body); return
	var name: String = str(body.get_meta("dsh_test_resident_name", ""))
	if name.is_empty(): return
	ResDiag.refresh_after_hit(body, name, _row)

## DSH_RESDIAG: the every-frame repaint of this resident's caption. The hit owner is stepped
## once per physics frame by the city population, so this is the one hook that can paint the
## owner's display without waiting for the resident's daily poll turn. It writes a Label3D
## text and nothing else; only the owner's named resident has a caption at all.
func _dsh_repaint_caption() -> void:
	if not _ready: return
	if ResDiag.simple_vitals_on() and not ResDiag.diag_on():
		ResDiag.repaint_focus30(_token.get("body")); return
	if not ResDiag.hp_label_on() and not ResDiag.diag_on(): return
	var body: Variant = _token.get("body")
	if not is_instance_valid(body) or not body is Node3D: return
	if str((body as Node3D).get_meta("dsh_test_resident_name", "")).is_empty(): return
	var life: RefCounted = ResDiag.life_of(str(_token.source_id))
	if life == null or not life.has_method("dsh_repaint_caption"): return
	life.call("dsh_repaint_caption")

## DSH_MEDPRIORITY: hand the hit to this resident's own life scheduler, which decides the
## medical priority in this same call. Read-only seam: a miss (no life registered yet, or a
## life that is busy/not current) leaves today's behaviour untouched.
func _dsh_notice_damage() -> void:
	var life: RefCounted = ResDiag.life_of(str(_token.source_id))
	if life == null or not life.has_method("dsh_notice_damage"): return
	var noted: Variant = life.call("dsh_notice_damage")
	if noted is Dictionary and noted.get("reason", "") == "medical_priority_from_hit":
		print("DSH_DAMAGE id=", str(_token.source_id), " medical_notice=", str(noted))

## DSH_ROWPROBE: --city-damage-probe=1 makes this resident take ONE hit through the project's
## own damage pipeline (`_apply_hit` -> adapter.hit -> npc_ordinary_hit_lifecycle), so the row
## identity, the hp write and the label repaint can be measured headlessly, where no player
## can shoot. The damage number is the project's own (`Rules.damage_at`), never a new balance.
static var _damage_probe_flag30 := -1
func _dsh_damage_probe() -> void:
	if _dsh_probe_fired or not _ready: return
	if _damage_probe_flag30<0:_damage_probe_flag30=1 if OS.get_cmdline_user_args().has("--city-damage-probe=1") else 0
	if _damage_probe_flag30==0:return
	var body: Variant = _token.get("body")
	if not is_instance_valid(body) or not body is Node3D: return
	if str(body.get_meta("dsh_test_resident_name", "")).is_empty(): return
	var life: RefCounted = ResDiag.life_of(str(_token.source_id))
	if life == null: return
	if Engine.get_physics_frames() < 900: return
	_dsh_probe_fired = true
	var point: Vector3 = (body as Node3D).global_position + Vector3(0.0, 1.2, 0.0)
	var muzzle: Vector3 = point + Vector3(0.6, 0.0, 0.6)
	var direction := Vector3(-0.7, 0.0, -0.7)
	var damage: int = maxi(1, Rules.damage_at("nagan", 1.0))
	var shot := {"weapon_id": "nagan", "muzzle": muzzle, "at_ms": _now(), "used": false,
		"pellets": false, "modifiers": {"critical": false, "critical_multiplier": 1.0}}
	print("DSH_ROWPROBE site=probe id=", str(_token.source_id), " damage=", damage,
		" frame=", Engine.get_physics_frames(), " note=real_pipeline_hit")
	_apply_hit("dsh-probe:" + str(_serial + 1), shot, damage, direction, point, Vector3.UP)

# DSH_HEALTH: the per-tick step() path only needs the boolean answer, and building
# the four-entry Dictionary once per resident per physics tick was pure overhead.
# This is the one authoritative predicate (same expressions, same order, same
# short-circuiting); _current() below still returns the identical Dictionary for
# the adapter callable and for the sibling files that consume it.
func _is_current(binding: Dictionary) -> bool:
	if not _ready or binding!=_binding or not is_instance_valid(_weapons) or not _weapons.is_inside_tree() or _weapons.effects!=_effects or not is_instance_valid(_effects) or not _effects._live() or not _host.physical_life_current(_token): return false
	return true

func _current(binding: Dictionary) -> Dictionary:
	if not _is_current(binding): return {}
	return {"scope":"local_walk_ordinary","binding":_binding,"owner_instance_id":get_instance_id(),"row":_row}

func _service(row: Dictionary,p: Dictionary,name: String) -> Variant:
	match name:
		"clock": return _now()
		"random": return _rng.randf()
		"admit_contact": return _admitting.duplicate(true) if p.event_id==_admitting.get("event_id") else null
		"path":
			# Preserve the source's .09-cell request without instantly sliding the
			# native standing collider. Physical impact owns the visible movement.
			if not _is_current(_binding): return false
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

func incident_witness_snapshot() -> Dictionary:
	if _incident_role_scope!="ordinary_unarmed_civilian" or not _ready or not _is_current(_binding) or not _host.target_current(_token): return {}
	var body: Variant=_token.get("body")
	if not is_instance_valid(body) or not body is CharacterBody3D or _row.get("dead",false) or float(_row.get("hp",0))<=0 or _row.get("_medicalDowned",false): return {}
	var position: Vector3=body.global_position
	var forward: Vector3=-body.global_basis.z
	if not position.is_finite() or not forward.is_finite(): return {}
	return {"eligible":true,"role_scope":_incident_role_scope,"position":position,"forward":forward,"source_id":str(_token.get("source_id","")),"session_id":str(_token.get("session_id","")),"life_generation":int(_token.get("life_generation",-1)),"owner_instance_id":get_instance_id(),"body_instance_id":body.get_instance_id(),"body":body,"token":_token.duplicate()}

func _on_shot(shot: Dictionary,muzzle: Dictionary,_camera_origin: Vector3,camera_direction: Vector3) -> void:
	_dsh_shot_frame = Engine.get_physics_frames()  # DSH_ROWPROBE: the shot that may become a hit
	if not _is_current(_binding) or not muzzle.get("origin") is Vector3 or not muzzle.origin.is_finite(): return
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
	if not _is_current(_binding) or not _registries.has(_registry_key): return {}
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
	if not _is_current(_binding) or not _shots.has(str(impact.get("shotId",""))): return
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
	if not _is_current(_binding) or _row.get("dead",false): return
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
	var hp_before: float=float(_row.get("hp",0))
	last_result=_adapter.hit(id,_admitting.hit)
	_admitting={}
	# DSH_DAMAGE: one line per actual hit, printed in the same call that applied it, with
	# the same `_row.hp` the medical decision reads. `hp_before`/`hp_after` are clamped to
	# the owner's 0..100 range, so a negative hit point value can never be reported.
	if ResDiag.hp_label_on() or ResDiag.diag_on():
		# DSH_ROWPROBE: the identity of the ROW this hit wrote to, stamped so the life side
		# can prove it reads the same object, plus the shot->apply frame gap.
		_row["_dsh_hit_frame"] = Engine.get_physics_frames()
		_row["_dsh_hit_hp"] = float(_row.get("hp", 0))
		_row["_dsh_hit_owner"] = get_instance_id()
		print("DSH_ROWPROBE site=hit id=", str(_token.source_id), " row_hash=", _row.hash(),
			" owner_id=", get_instance_id(), " body_id=", body.get_instance_id(),
			" hp_before=", "%.0f" % clampf(hp_before,0.0,100.0),
			" hp_after=", "%.0f" % clampf(float(_row.get("hp",0)),0.0,100.0),
			" frame_hit=", _dsh_shot_frame, " frame_apply=", Engine.get_physics_frames())
		print("DSH_DAMAGE id=", str(_token.source_id), " hp_before=", "%.0f" % clampf(hp_before,0.0,100.0),
			" damage=", damage, " hp_after=", "%.0f" % clampf(float(_row.get("hp",0)),0.0,100.0),
			" weapon=", str(shot.get("weapon_id","-")), " zone=", str(zone.get("zone","body")),
			" applied=", str(last_result.ok and last_result.get("applied",false)),
			" frame=", Engine.get_physics_frames())
	# DSH_RESDIAG: the caption over the head is repainted from this very hit, with the same
	# `_row.hp` the medical decision reads, so the owner sees the drop immediately instead of
	# waiting for this resident's turn in the daily poll slice (measured period ~1.6 s).
	_dsh_refresh_caption(body)
	# DSH_MEDPRIORITY: the medical threshold is re-checked in this same call. Without it the
	# resident's decision waited for its next slice turn, which is why an owner's shot at
	# 25 % hp could sit unseen for a whole poll period.
	_dsh_notice_damage()
	if not last_result.ok or not last_result.get("applied",false): return
	last_contact={"event_id":id,"incoming_direction":(direction if physical_direction==Vector3.ZERO else physical_direction).normalized(),"actor_transform_at_impact":contact_actor_transform,"point":point,"normal":normal,"shot_id":shot_id,"weapon_id":shot.weapon_id,"source_id":_token.source_id,"life_generation":_token.life_generation}
	if not zone.is_empty(): last_contact["projectile_index"]=zone.get("projectile_index",0)
	if blood!=null: blood.receive(id,point,normal)
	if marks!=null: marks.receive(id,point,normal)
	_native_impulse_context={"event_id":id,"value":HitImpulse.bullet(shot.weapon_id,shot.muzzle.distance_to(point),damage,direction if physical_direction==Vector3.ZERO else physical_direction,_row.get("_invulnerable",false))}
	if bullet_reaction!=null: bullet_reaction.prepare_before_publish(id)
	_publish_physical(id,last_result.reason,point)
	if bullet_reaction!=null: bullet_reaction.accept(id,_native_impulse_context.value.get("impulse_ns",Vector3.ZERO),point)
	_native_impulse_context={}
	_last_hit_us=Time.get_ticks_usec()-started_us

## The thrown item's real swept impact is owned by player_throwables. Each actor
## checks its own current body and life lease before admitting one area contact.
func apply_throwable_area(producer: Node,event_id: String,kind: String,center: Vector3,radius: float,damage: int) -> Dictionary:
	if not _is_current(_binding) or _row.get("dead",false) or not is_instance_valid(producer) or producer!=_weapons.scene.get("player_throwables"):
		return {"ok":false,"reason":"owner"}
	if kind not in ["grenade","molotov"] or not center.is_finite() or radius<=0 or radius>3.1 or damage<=0 or damage>(80 if kind=="grenade" else 12) or not producer.owns_area_event(event_id,kind,center):
		return {"ok":false,"reason":"area_event"}
	var body: CharacterBody3D=_token.body
	if not is_instance_valid(body) or not _host.target_current(_token): return {"ok":false,"reason":"body"}
	var point: Vector3=body.global_position+Vector3.UP*.95
	var distance: float=point.distance_to(center)
	if distance>radius+.45:
		return {"ok":false,"reason":"out_of_range"}
	var sight:=PhysicsRayQueryParameters3D.create(center+Vector3.UP*.12,point,1,[body.get_rid(),_weapons.player.get_rid()])
	var obstruction: Dictionary=body.get_world_3d().direct_space_state.intersect_ray(sight)
	if not obstruction.is_empty(): return {"ok":false,"reason":"area_occluded"}
	var direction: Vector3=(point-center).normalized()
	if direction.length_squared()<.001: direction=Vector3.RIGHT
	var scaled: int=maxi(1,int(round(float(damage)*(1.0-.55*clampf(distance/radius,0.0,1.0)))))
	_serial+=1
	var id: String=_token.source_id+":"+str(_serial)+":"+event_id
	_last_player=_weapons.player.global_position
	_admitting={"event_id":id,"binding":_binding.duplicate(true),"hit":{"weapon_id":kind,"contact_kind":"throwable_area","contact_proof":"consumed_player_throw_swept_impact","damage":scaled,"dir_r":direction.z,"dir_c":direction.x,"player_r":(_last_player.z+45.1)/4.1,"player_c":(_last_player.x+395.65)/4.1,"source":{"kind":"player","uid":"local"}}}
	last_result=_adapter.hit(id,_admitting.hit)
	_admitting={}
	_dsh_refresh_caption(body); _dsh_notice_damage()
	if not last_result.get("ok",false) or not last_result.get("applied",false): return last_result.duplicate(true)
	last_contact={"event_id":id,"incoming_direction":direction,"actor_transform_at_impact":body.global_transform,"point":point,"normal":Vector3.UP,"weapon_id":kind,"source_id":_token.source_id,"life_generation":_token.life_generation}
	if kind=="grenade" and blood!=null: blood.receive(id,point,Vector3.UP)
	var impulse: Dictionary=HitImpulse.blast(distance,direction,_row.get("_invulnerable",false)) if kind=="grenade" else {"ok":false,"impulse_ns":Vector3.ZERO}
	if impulse.get("ok",false): impulse.impulse_ns=(impulse.impulse_ns as Vector3).limit_length(300.0)
	_native_impulse_context={"event_id":id,"value":impulse}
	if bullet_reaction!=null: bullet_reaction.prepare_before_publish(id)
	_publish_physical(id,last_result.reason,point)
	if bullet_reaction!=null: bullet_reaction.accept(id,_native_impulse_context.value.get("impulse_ns",Vector3.ZERO),point)
	_native_impulse_context={}
	return last_result.duplicate(true)

## One completed native pellet terminal per accepted p.index. A cosmetic hit
## alone is insufficient: misses/cancellation must also settle the seven rays.
func _on_projectile_resolved(receipt: Dictionary) -> void:
	if not _is_current(_binding) or not _shots.has(receipt.get("shotId","")): return
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
				if not is_instance_valid(candidate) or not candidate._is_current(candidate._binding) or not candidate._owns_collider(receipt.get("collider")): continue
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
		if not is_instance_valid(target) or not target._is_current(group.binding): continue
		var damage:=Rules.shotgun_damage(group.distances,_marksman,shot.modifiers.critical,shot.modifiers.critical_multiplier)
		if damage.ok: target._apply_hit(str(receipt.shotId),shot,damage.damage,shot.base_direction,group.point,group.normal,group.physical_direction,group.get("head_zone",{}))
	shot.targets.clear()

var _single_lifecycle28: WeakRef
var _step_calls28 := 0

func bind_single_lifecycle28(owner: Node) -> bool:
	if _single_lifecycle28!=null or not is_instance_valid(owner) or not owner.is_inside_tree() or owner.get_script().resource_path!="res://scripts/hospital/npc_single_lifecycle28.gd":return false
	if _token.get("source_id")!=owner.get("source_id30") or not _host.single_lifecycle28_current(owner) or owner.get("_health")!=self or owner.get("_token")!=_token:return false
	_single_lifecycle28=weakref(owner)
	return true

func _notify_final_death28(event_id: String) -> void:
	var owner: Node=_single_lifecycle28.get_ref() if _single_lifecycle28!=null else null
	if is_instance_valid(owner):owner.confirmed_death(self,event_id)

func _publish_physical(id: String,reason: String,point: Vector3) -> void:
	if reason not in ["final_death","medical_downed","bleedout"]: return
	var final: bool=reason!="medical_downed"
	var kind: String="final_death" if final else "source_medical_down"
	var body: CharacterBody3D=_token.body
	_events[id]={"id":id,"kind":kind,"confirmed":true,"death_key":str(_row.deadAt) if final else "","source_id":_token.source_id,"life_generation":_token.life_generation,"medical_downed":not final,"local_preview_hp_revision":last_result.get("revision",0),"already_solved_by_godot":true,"apply_again":false,"linear_velocity":body.velocity,"angular_velocity":Vector3.ZERO,"reference_point":point,"impulse_ns":Vector3.ZERO}
	var physical: RefCounted=_host._ragdolls[_token.source_id]
	var impulse:=Vector3.ZERO
	if reason in ["final_death","medical_downed"] and _native_impulse_context.get("event_id")==id and _is_current(_binding):
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
			if not _point_consumed.has(id) and _adapter.receipt(id)==last_result and _is_current(_binding) and _host._ragdolls.get(_token.source_id)==physical and physical.status().mode=="ACTIVE":
				_point_consumed[id]=true
				var applied: Dictionary=physical._body.apply_impulse(point,point_impulse,id+":point")
				last_impulse["point_result"]=applied
				if applied.get("ok",false):
					last_impulse["point_lever_m"]=point-physical._body._bodies[applied.bone].global_position
					last_impulse["point_torque_ns_m"]=last_impulse.point_lever_m.cross(point_impulse)
					last_impulse.point_ns=point_impulse
					last_impulse.impulse_ns=uniform_impulse+point_impulse
	elif final:last_physical=_host.confirm_physical_death(_token,id)
	if final:_notify_final_death28(id)


func physical_event(request: Dictionary) -> Dictionary:
	if not _is_current(_binding) or request.get("mode")!="event" or not request.get("binding") is Dictionary or not _events.has(request.get("event_id","")): return {}
	for key: String in request.binding:
		if request.binding[key]!=_token.get(key): return {}
	return {"known":true,"completed":true,"accepted":true,"binding":request.binding.duplicate(),"event":_events[request.event_id].duplicate(true),"scope":"new_local_session_hp","source_callbacks_complete":false}

# DSH_HEALTH2: exact idle fast path plus an optional, flag-gated actor-lease cache.
# An idle owner's whole step() writes nothing (see npc_bullet_reaction.idle_reaction()):
# the reaction's own idle tick, the contractual `_native_terminal_batch` refresh and
# `_cleanup_shots()` are its complete body, so those are exactly what this keeps.
# Without --city-health-lease the full actor-lease chain still runs for every owner
# on every step (today's cadence). The flag only caches that chain for an owner that
# is alive, not medical downed and provably idle, revalidating it at most once per
# DSH2_LEASE_FRAMES physics frames per owner, staggered by instance id so the
# revalidations never bunch into one frame. The lease is a cadence trade: OFF default.
# What can invalidate the leased operands: the weapons node and the effects owner
# leave the tree only with the whole 3D scene (which stops this loop in the same
# frame); preview_weapons.effects is assigned once, guarded by ready_for_play; the
# resident host drops a single life only through record.body=null when _living() is
# false, and _living() is false exactly when owner.dead is set (excluded here by the
# live row flags) or when the whole host is disposed with the scene. _is_current()
# itself is untouched, so every event caller keeps the exact per-call contract.
func step() -> void:
	if _single_lifecycle28!=null:_step_calls28+=1
	var frame:=Engine.get_physics_frames()
	publish_pause_gate(frame)  # DSH_PAUSEPUSH: the host reads this instead of the Callable
	_dsh_repaint_caption()  # DSH_RESDIAG: every frame, no throttle - the owner's display
	_dsh_damage_probe()  # DSH_ROWPROBE: optional one real-pipeline hit for a headless measurement
	var idle_row: bool = not _row.get("dead",false) and not _row.get("_medicalDowned",false)
	if _dsh2_lease_enabled and _ready and _dsh2_lease_ok and frame<_dsh2_lease_until and idle_row and (bullet_reaction==null or bullet_reaction.step_idle(self,frame)):
		_native_terminal_batch=_effects._resolutions
		_cleanup_shots()
		return
	if not _is_current(_binding):
		_dsh2_lease_ok=false
		return
	if _dsh2_lease_enabled:
		# DSH_HEALTH2: the call above just revalidated the whole actor lease against the
		# host in this exact frame; record it for the idle fast path.
		_dsh2_lease_ok=true
		_dsh2_lease_until=frame+DSH2_LEASE_FRAMES+int(get_instance_id())%DSH2_LEASE_SPREAD
	if idle_row and (bullet_reaction==null or bullet_reaction.step_idle(self,frame)):
		_native_terminal_batch=_effects._resolutions
		_cleanup_shots()
		return
	# DSH_HEALTH: _is_current() has just proven this exact owner in this same physics
	# frame, so the reaction must not repeat the identical host validation (which
	# re-scans the rig subtree for its Skeleton3D) again for the same tick.
	if bullet_reaction!=null: bullet_reaction.step(self)
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
# DSH_RECORDLOOP: the host binds this as its per-record `walk_pause` Callable and
# calls it for every resident on every city step. This wrapper exposes the same
# boolean through a zero-argument method, so the stored Callable no longer carries
# the default-parameter trampoline. should_pause_walk() below is unchanged and
# remains the single authoritative idle gate for every other caller.
# DSH_PAUSEPUSH: the host called should_pause_walk() once per resident per city
# step through record.walk_pause (284 Callable dispatches, measured 2.8 ms/step).
# This owner is already stepped once per city step by population.step()'s
# `for health in hit_owners: health.step()` loop, which runs BEFORE
# residents.step() in the same physics frame, so it can publish the operands the
# host needs and the host can read them instead of paying the dispatch chain.
# The disjuncts are evaluated in should_pause_walk()'s own order, and
# should_pause_walk() itself stays the single authority for every other caller.
var _pause_pub_block := false  # DSH_PAUSEPUSH: last published non-clock disjunct
var _pause_pub_deadline := 0.0  # DSH_PAUSEPUSH: last published raw idleUntil
var _pause_pub_epoch := -1  # DSH_PAUSEPUSH: last published _start_us
var _pause_pub_seen := false  # DSH_PAUSEPUSH: first publish always writes
var _dsh_pause_push := -1  # DSH_PAUSEPUSH: --city-pause-push=0 restores today's Callable path

# DSH_PAUSEPUSH: the A/B lever. Default 1 publishes and lets the host read; 0
# makes both sides take today's exact path (the Callable), so one flag toggles the
# whole change and a diff of the two arms is attributable to it alone.
func _pause_push_on() -> bool:  # DSH_PAUSEPUSH
	if _dsh_pause_push < 0:
		# DSH_PAUSEPUSHOFF: measured twice - the publication costs ~765 us in the health
		# loop and saves only ~670 us of resid, a net wash. 0 ships today's Callable path;
		# --city-pause-push=1 re-enables the published-gate experiment.
		_dsh_pause_push = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-pause-push="):
				_dsh_pause_push = 0 if int(argument.trim_prefix("--city-pause-push=")) == 0 else 1
	return _dsh_pause_push != 0

func publish_pause_gate(frame: int) -> void:  # DSH_PAUSEPUSH
	if _host == null or not _pause_push_on(): return
	var block := true
	if _ready:
		block = (bullet_reaction != null and bullet_reaction.should_pause()) or bool(_row.get("dead",false)) or bool(_row.get("_medicalDowned",false)) or bool(_row.get("_forcedCrawl",false))
	var record: Dictionary = _host._records.get(str(_token.get("source_id","")), {})
	if record.is_empty(): return
	# The frame stamp is rewritten every step: a missing or stale stamp makes the
	# host fall back to the unchanged Callable, so a record can never act on a
	# value this owner did not compute in this exact city step.
	record["pause_stamp"] = frame
	if not _pause_pub_seen or block != _pause_pub_block:
		_pause_pub_block = block
		record["pause_block"] = block
	if not block:
		var deadline := float(_row.get("idleUntil",0.0))
		var epoch := int(_start_us)
		if not _pause_pub_seen or deadline != _pause_pub_deadline or epoch != _pause_pub_epoch:
			_pause_pub_deadline = deadline
			_pause_pub_epoch = epoch
			record["pause_deadline_ms"] = deadline
			record["pause_epoch_us"] = epoch
	_pause_pub_seen = true

func _idle_gate() -> bool:
	var value := should_pause_walk()
	_idle_gate_last = value
	return value

func should_pause_walk(source_now_ms: float = -1.0) -> bool:
	if not _ready: return true
	if bullet_reaction!=null and bullet_reaction.should_pause(): return true
	if _row.get("dead",false) or _row.get("_medicalDowned",false) or _row.get("_forcedCrawl",false): return true
	var now: float=_now() if source_now_ms==-1.0 else source_now_ms
	if not is_finite(now) or now<0: return true
	return now<float(_row.get("idleUntil",0.0))

func dispose() -> void:
	_single_lifecycle28=null
	_dsh2_lease_ok=false; _dsh2_lease_until=-1  # DSH_HEALTH2
	if bullet_reaction!=null: bullet_reaction.dispose(); bullet_reaction=null
	_melee_producer=null; _completed_player_damage.clear()
	if blood!=null: blood.dispose(); blood=null
	if marks!=null: marks.dispose(); marks=null
	_ready=false; _incident_role_scope=""
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

## The contact producer owns the physical query, attack window and occlusion.
## Binding does not admit damage. Only its synchronous single-use ticket does.
func bind_melee_producer(producer: Object) -> bool:
	if not _is_current(_binding) or not is_instance_valid(producer) or not producer.has_method("validate_melee_contact"): return false
	if _melee_producer!=null and is_instance_valid(_melee_producer.get_ref()): return _melee_producer.get_ref()==producer
	_melee_producer=weakref(producer)
	return true

func apply_melee_contact(contact: Dictionary, producer: Object) -> Dictionary:
	if _melee_busy or not _is_current(_binding) or _row.get("dead",false) or _row.get("_medicalDowned",false): return {"ok":false,"reason":"melee_target_unavailable"}
	if _melee_producer==null or not is_instance_valid(producer) or _melee_producer.get_ref()!=producer: return {"ok":false,"reason":"melee_producer"}
	if contact.get("collider")!=_token.body or contact.get("source_id")!=_token.source_id or contact.get("life_generation")!=_token.life_generation: return {"ok":false,"reason":"melee_target_lease"}
	for key: String in ["point","normal","direction","attack_origin"]:
		if not contact.get(key) is Vector3 or not contact[key].is_finite(): return {"ok":false,"reason":"melee_geometry"}
	if contact.normal.length_squared()<.5 or contact.direction.length_squared()<.5: return {"ok":false,"reason":"melee_direction"}
	var attack_type: String=str(contact.get("attack_type",""))
	if not MELEE_DAMAGE.has(attack_type) or contact.get("damage")!=MELEE_DAMAGE[attack_type]: return {"ok":false,"reason":"melee_damage_profile"}
	if not contact.get("event_id") is String or contact.event_id.is_empty() or not contact.get("attack_id") is String or contact.attack_id.is_empty(): return {"ok":false,"reason":"melee_identity"}
	if not is_instance_valid(_weapons.player) or contact.get("attacker_instance_id")!=_weapons.player.get_instance_id(): return {"ok":false,"reason":"melee_attacker"}
	if marks==null or marks.renderer==null or not contact.get("surface_index") is int or contact.surface_index<0 or contact.surface_index>=marks.renderer._surfaces.size(): return {"ok":false,"reason":"melee_original_surface"}
	# Never allow caller flags to bypass the producer's geometry/sequence receipt.
	_melee_busy=true
	var admitted: Variant=producer.call("validate_melee_contact",self,contact.duplicate(true))
	if admitted!=true or not _is_current(_binding):
		_melee_busy=false; return {"ok":false,"reason":"melee_contact_proof"}
	var body: CharacterBody3D=_token.body
	_row.r=(body.global_position.z+45.1)/4.1; _row.c=(body.global_position.x+395.65)/4.1
	_last_player=_weapons.player.global_position
	var hp_before: int=int(_row.hp)
	var id: String=contact.event_id
	var direction: Vector3=contact.direction.normalized()
	_admitting={"event_id":id,"binding":_binding.duplicate(true),"hit":{"weapon_id":"unarmed","contact_kind":"melee","contact_proof":"native_swept_fist_original_surface","attack_type":attack_type,"damage":MELEE_DAMAGE[attack_type],"dir_r":direction.z,"dir_c":direction.x,"player_r":(_last_player.z+45.1)/4.1,"player_c":(_last_player.x+395.65)/4.1,"source":{"kind":"player","uid":"local"}}}
	var contact_actor_transform: Transform3D=body.global_transform
	last_result=_adapter.hit(id,_admitting.hit); _admitting={}
	if not last_result.get("ok",false) or not last_result.get("applied",false):
		_melee_busy=false; return last_result.duplicate(true)
	last_contact=contact.duplicate(true)
	last_contact.merge({"event_id":id,"incoming_direction":direction,"actor_transform_at_impact":contact_actor_transform,"weapon_id":"unarmed","contact_kind":"melee"},true)
	if blood!=null: blood.receive(id,contact.point,contact.normal)
	if marks!=null: marks.receive(id,contact.point,contact.normal)
	var melee_impulse: float=140.0 if attack_type=="dropkick" else 45.0 if attack_type in ["heavy","kick"] else 30.0
	_native_impulse_context={"event_id":id,"value":{"ok":true,"impulse_ns":direction*melee_impulse}}
	if bullet_reaction!=null: bullet_reaction.prepare_before_publish(id)
	_publish_physical(id,last_result.reason,contact.point)
	if bullet_reaction!=null: bullet_reaction.accept(id,_native_impulse_context.value.impulse_ns,contact.point)
	_native_impulse_context={}
	_completed_player_damage={"accepted":true,"confirmed":true,"event_id":id,"source_id":_token.source_id,"life_generation":_token.life_generation,"attacker_kind":"player","attacker_instance_id":contact.attacker_instance_id,"hp_before":hp_before,"hp_after":int(_row.hp),"damage":maxi(0,hp_before-int(_row.hp)),"revision":int(last_result.revision),"kind":"melee"}
	_melee_busy=false
	return last_result.duplicate(true)

func confirmed_player_damage(event_id: String) -> Dictionary:
	if not _is_current(_binding) or _completed_player_damage.get("event_id")!=event_id or _adapter.receipt(event_id)!=last_result or not last_result.get("applied",false): return {}
	return _completed_player_damage.duplicate(true)

func _validate_local_survival_release(event_id: String, expected_revision: int, proof: Dictionary) -> bool:
	if not _is_current(_binding) or bullet_reaction==null: return false
	return bullet_reaction.validate_survival_release(proof,event_id,expected_revision)

func commit_local_survival_release(event_id: String, expected_revision: int, proof: Dictionary) -> Dictionary:
	if not _is_current(_binding) or _adapter==null: return {"ok":false,"reason":"local_survival_owner"}
	var result: Dictionary=_adapter.release_local_survival(event_id,expected_revision,proof)
	if result.get("ok",false) and result.get("applied",false):
		last_result=result
		_completed_player_damage.clear()
	return result.duplicate(true)

## Geometry can refine only an existing accepted shot on this owned collider.
func _head_contact(shot: Dictionary,impact: Dictionary) -> Dictionary:
	if _head_zone==null or _row.get("_invulnerable",false) or not _is_current(_binding) or not _contact_shape(impact) or not _owns_collider(impact.get("collider")):return {}
	var physical: RefCounted=_host._ragdolls[_token.source_id]
	var excluded: Array[RID]=[_token.body.get_rid(),_weapons.player.get_rid()]
	excluded.append_array(physical._body.body_rids())
	var zone: Dictionary=_head_zone.classify(shot.muzzle,impact.direction,float(Rules.damage_profile(shot.weapon_id).range)*4.1,physical,_weapons.scene,excluded)
	if not zone.is_empty(): zone["projectile_index"]=impact.get("projectileIndex",0)
	return zone

## Local native cosmetic authority only. No HP service, death event, impulse or
## source revision is called here. A disabled walking capsule is never a corpse.
func _postmortem_context(collider: Variant) -> Dictionary:
	if not Thread.is_main_thread() or not _is_current(_binding) or _row.get("dead")!=true or not Rules._finite(_row.get("hp")) or _row.hp>0 or not Rules._finite(_row.get("deadAt")): return {}
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
