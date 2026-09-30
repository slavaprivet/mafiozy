extends RefCounted
## Port of world.html hitNpc ordinary branch. This is an owner ADAPTER, not a
## substitute authority: bind to the local session's actual mutable actor lease.
## All external source services are required; missing services fail before HP.
const Rules = preload("res://scripts/weapons/weapon_hit_rules.gd")
const REQUIRED := ["clock", "random", "admit_contact", "confirm", "bleeding", "path", "aggression", "rumor", "civilian", "panic", "fight", "surrender", "fatal_record", "murder", "respawn", "death_blood", "feedback"]
var _binding := {}
var _current := Callable()
var _services := {}
var _busy := false
var _retired := false
var _epoch := 0
var _revision := 0
var _events := {}
var _last_now := -1.0
var _row := {}
var _checking := false
var _seen := {}

func configure(binding: Dictionary, current_owner: Callable, services: Dictionary) -> Dictionary:
	if not _binding.is_empty() or _retired or not current_owner.is_valid(): return {"ok":false,"reason":"lifetime"}
	for key: String in ["session_id", "source_id", "render_id"]:
		if not binding.get(key) is String or binding[key].is_empty(): return {"ok":false,"reason":"identity"}
	if not binding.get("life_generation") is int or binding.life_generation < 1 or binding.get("scope") != "local_walk_ordinary" or not binding.get("owner_instance_id") is int or binding.owner_instance_id==0: return {"ok":false,"reason":"local_lease_required"}
	for key: String in REQUIRED:
		if not services.get(key) is Callable or not services[key].is_valid(): return {"ok":false,"reason":"missing_service:"+key}
	_binding=binding.duplicate(true); _current=current_owner; _services=services.duplicate()
	if not _fresh(): _retired=true; return {"ok":false,"reason":"current_owner_required"}
	return {"ok":true,"scope":"local_walk_ordinary","server_authority":false}

func dispose() -> void:
	_retired=true; _epoch+=1
	_current=Callable(); _services.clear()

func _fresh() -> bool:
	if _retired or _checking or not _current.is_valid(): return false
	_checking=true
	var before:=_epoch
	var reply: Variant=_current.call(_binding.duplicate(true))
	_checking=false
	if before!=_epoch or _retired or not reply is Dictionary or reply.get("scope")!="local_walk_ordinary" or not reply.get("row") is Dictionary or reply.get("binding")!=_binding: return false
	var actor: Dictionary=reply.row
	if actor.get("source_id")!=_binding.source_id or actor.get("life_generation")!=_binding.life_generation: return false
	for key: String in ["hp","r","c"]:
		if not Rules._finite(actor.get(key)): return false
	if actor.get("_empireBoss",false) or actor.get("_empireCrew",false): return false
	# Owner identity is independently leased; dictionary equality is not identity.
	if not reply.get("owner_instance_id") is int or reply.owner_instance_id==0: return false
	if _binding.has("owner_instance_id") and reply.owner_instance_id!=_binding.owner_instance_id: return false
	_row=actor
	return true

func _call(name: String, payload: Dictionary = {}) -> Variant:
	if not _fresh(): return null
	var before:=_epoch
	var value: Variant=_services[name].call(_row,payload.duplicate(true))
	if before!=_epoch or not _fresh(): return null
	return value

func _time() -> float:
	var value: Variant=_call("clock")
	if not Rules._finite(value) or value<_last_now: return -1.0
	_last_now=float(value); return _last_now

func _stop(reason: String, applied := false) -> Dictionary:
	_busy=false
	return {"ok":false,"reason":reason,"applied":applied,"revision":_revision}

func _done(event_id: String, applied: bool, reason: String, hit: Dictionary = {}) -> Dictionary:
	var record: Dictionary={"ok":true,"applied":applied,"reason":reason,"binding":_binding.duplicate(true),"revision":_revision,"row":_row.duplicate(true),"event_id":event_id,"hit":hit.duplicate(true),"source_now_ms":_last_now,"server_authority":false}
	if _seen.has(event_id): _events[event_id]=record.duplicate(true)
	_busy=false
	return record

func hit(event_id: String, proposed: Dictionary) -> Dictionary:
	if _busy: _epoch+=1; return {"ok":false,"reason":"reentrant"}
	if _retired or event_id.is_empty() or _seen.has(event_id) or _seen.size()>=4096: return {"ok":false,"reason":"retired_or_duplicate"}
	_busy=true
	if not _fresh(): return _stop("lease")
	if _row.get("dead",false): return _done(event_id,false,"dead")
	var admitted: Variant=_call("admit_contact",{"event_id":event_id,"proposed":proposed})
	if not admitted is Dictionary or admitted.get("event_id")!=event_id or admitted.get("binding")!=_binding or not admitted.get("hit") is Dictionary: return _stop("actual_contact_required")
	var h: Dictionary=admitted.hit.duplicate(true)
	for key: String in ["damage","dir_r","dir_c","player_r","player_c"]:
		if not Rules._finite(h.get(key)): return _stop("hit_shape")
	if h.damage<=0 or not h.get("weapon_id") is String or Rules.balance_id(h.weapon_id) in ["","rpg"]: return _stop("ordinary_bullet_required")
	if not h.get("source") is Dictionary or not h.source.get("kind") is String: return _stop("source_identity")
	_seen[event_id]=true # Admission is consumed even if a later callback retires it.
	var now:=_time()
	if now<0: return _stop("clock")
	_row._threeHitAngle=atan2(h.dir_r,h.dir_c); _row._threeHitPower=clampf(h.damage/72.0,.18,1.6); _row._threeHitWeapon=h.weapon_id
	_row._lastViolentSource=h.source.duplicate(true); _row._lastViolentAt=now
	_revision+=1
	if _row.get("_invulnerable",false):
		_row.cryText="У нас ещё много дел."; _row.cryUntil=now+1300
		if _call("feedback",{"kind":"invulnerable"})==null: return _stop("feedback_lease")
		return _done(event_id,false,"invulnerable",h)
	var was_downed: bool=bool(_row.get("_medicalDowned",false))
	_row.hp=maxi(0,Rules._int32(_row.hp)-Rules._int32(h.damage))
	if _call("confirm",h)==null: return _stop("confirm_lease",true)
	if _call("bleeding",h)==null: return _stop("bleeding_lease",true)
	var nr: float=_row.r+h.dir_r*.09
	var nc: float=_row.c+h.dir_c*.09
	var passable: Variant=_call("path",{"from_r":_row.r,"from_c":_row.c,"r":nr,"c":nc})
	if not passable is bool: return _stop("path_lease",true)
	if passable: _row.r=nr; _row.c=nc
	now=_time()
	if now<0: return _stop("clock",true)
	_row.idleUntil=now+250
	if _call("aggression",{"amount":1})==null: return _stop("aggression_lease",true)
	now=_time()
	if now<0 or _call("rumor",{"now_ms":now})==null: return _stop("rumor_lease",true)
	var player_attack: bool=h.source.kind=="player"
	if player_attack and _row.hp>0:
		var civilian: Variant=_call("civilian")
		if not civilian is bool: return _stop("civilian_lease",true)
		if civilian:
			var roll: Variant=_call("random")
			if not Rules._finite(roll) or roll<0 or roll>=1: return _stop("random",true)
			if _call("panic",{"now_ms":_row._lastViolentAt,"until_ms":_row._lastViolentAt+4000+roll*2000,"r":h.player_r,"c":h.player_c,"style":"bullet"})==null: return _stop("panic_lease",true)
		if _row.get("_formerMercenary",false) and _call("fight")==null: return _stop("fight_lease",true)
	if _row.hp>0:
		now=_time()
		if now<0: return _stop("clock",true)
		var surrender: Variant=_call("surrender",{"now_ms":now})
		if not surrender is bool: return _stop("surrender_lease",true)
		if surrender: return _done(event_id,true,"surrender",h)
	if _row.hp<=0 and not _row.get("_medicalDowned",false) and not _row.get("_policeCriminal",false) and not _row.get("_guard",false) and not _row.get("_cashier",false) and not _row.get("_invulnerable",false):
		var survival: Variant=_call("random")
		if not Rules._finite(survival) or survival<0 or survival>=1: return _stop("survival_random",true)
		if survival<.72:
			now=_time()
			if now<0: return _stop("clock",true)
			_row.hp=1; _row._medicalDowned=true; _row._medicalDownedAt=now; _row._medicalBleedoutAt=now+30000; _row._deathFromDowned=false
			_row._knockedAt=now; _row._knockedUntil=_row._medicalBleedoutAt; _row.walkPhase=0; _row.snitching=false; _row.panicUntil=0; _row._forcedCrawl=true; _row.panicSrcR=h.player_r; _row.panicSrcC=h.player_c
			_row.cryText="Помогите…"; _row.cryUntil=now+1800; _row._ambulanceDispatched=false
			if _call("feedback",{"kind":"medical_downed"})==null: return _stop("medical_feedback_lease",true)
			return _done(event_id,true,"medical_downed",h)
	if _row.hp<=0:
		now=_time()
		if now<0: return _stop("clock",true)
		_row.dead=true; _row._deathFromDowned=was_downed; _row.deadAt=now
		_row._medicalDowned=false; _row._medicalDownedAt=0; _row._medicalBleedoutAt=0; _row._knockedUntil=0; _row._forcedCrawl=false; _row.walking=false
		var fatal: Variant=_call("fatal_record",h)
		if fatal==null: return _stop("fatal_record_lease",true)
		if fatal is Dictionary: _row._deathRecord20=fatal
		if _call("murder",{"source":_row._lastViolentSource,"now_ms":now})==null: return _stop("murder_lease",true)
		if _call("respawn",{"now_ms":now})==null: return _stop("respawn_lease",true)
		if _call("death_blood",h)==null: return _stop("death_blood_lease",true)
		return _done(event_id,true,"final_death",h)
	return _done(event_id,true,"hit",h)

func tick_medical(event_id: String) -> Dictionary:
	if _busy: _epoch+=1; return {"ok":false,"reason":"reentrant"}
	if _retired or event_id.is_empty() or _seen.has(event_id) or _seen.size()>=4096: return {"ok":false,"reason":"retired_or_duplicate"}
	_busy=true
	if not _fresh(): return _stop("lease")
	var now:=_time()
	if now<0: return _stop("clock")
	if _row.get("dead",false) or not _row.get("_medicalDowned",false) or now<float(_row.get("_medicalBleedoutAt",0)): return _done(event_id,false,"not_due")
	_seen[event_id]=true
	# Exact update-loop bleedout: does not invent a final bullet/fatal record.
	_row._medicalDowned=false; _row._knockedUntil=0; _row.hp=0; _row.dead=true; _row.deadAt=now; _row.cryText="…"; _row.cryUntil=now+500; _revision+=1
	if _call("murder",{"source":_row.get("_lastViolentSource"),"now_ms":now})==null: return _stop("murder_lease",true)
	if _call("respawn",{"now_ms":now})==null: return _stop("respawn_lease",true)
	return _done(event_id,true,"bleedout")

func receipt(event_id: String) -> Dictionary:
	return _events.get(event_id,{}).duplicate(true)

