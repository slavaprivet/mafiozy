extends RefCounted
## Pure original-world math and proposed scalar state. This is not a hit ray,
## NPC owner, server receipt, blood renderer, rigid-body impulse or HP authority.
const ALIASES := {"tt_pistol":"pistol","deagle":"pistol_heavy","golden_colt":"pistol_gold","sawn_off":"shotgun","uzi":"smg","golden_uzi":"smg","ak74":"rifle","m16":"rifle"}
## Original world WEAPON_FX_CFG fields consumed by weaponDamageAt, not new tuning.
const DAMAGE_PROFILES := {
	"pistol":{"range":8.0,"dmg":24,"falloffStart":.72,"minDamageMul":.65},
	"nagan":{"range":9.2,"dmg":32,"falloffStart":.78,"minDamageMul":.76},
	"revolver":{"range":10.5,"dmg":86,"falloffStart":.84,"minDamageMul":.80},
	"pistol_heavy":{"range":11.2,"dmg":72,"falloffStart":.80,"minDamageMul":.76},
	"pistol_gold":{"range":11.5,"dmg":48,"falloffStart":.80,"minDamageMul":.76},
	"shotgun":{"range":6.2,"dmg":76,"falloffStart":.36,"minDamageMul":.38},
	"smg":{"range":8.0,"dmg":15,"falloffStart":.60,"minDamageMul":.52},
	"tommy_gun":{"range":10.0,"dmg":24,"falloffStart":.68,"minDamageMul":.58},
	"rifle":{"range":14.0,"dmg":42,"falloffStart":.76,"minDamageMul":.68},
	"sniper":{"range":20.0,"dmg":132,"falloffStart":.92,"minDamageMul":.88},
	"rpg":{"range":15.0,"dmg":160,"falloffStart":1.0,"minDamageMul":1.0}}
const SCALE := 4.1
const SOURCE_WORLD_SHA256 := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const HIT_NUMBERS := ["damage","dir_r","dir_c","now_ms","player_r","player_c"]
const PENETRATING := ["nagan","rifle","sniper"]
const NAGAN_CADENCE := [.48,.38,.30,.24]
static func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
static func _point(value: Variant) -> bool:
	return value is Dictionary and _finite(value.get("x")) and _finite(value.get("y")) and _finite(value.get("z"))
static func _failure(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
static func balance_id(id: String) -> String:
	return id if DAMAGE_PROFILES.has(id) else ALIASES.get(id, "")
static func damage_profile(id: String) -> Dictionary:
	return DAMAGE_PROFILES.get(balance_id(id),{}).duplicate()
static func _round(value: float) -> int: return int(floor(value+.5))
static func _hypot2(a: float, b: float) -> float: return sqrt(a*a+b*b)
static func _normal_length(n: Dictionary) -> float:
	var largest:=maxf(absf(n.x),maxf(absf(n.y),absf(n.z)))
	if largest==0:return 0
	var x:float=n.x/largest;var y:float=n.y/largest;var z:float=n.z/largest
	return largest*sqrt(x*x+y*y+z*z)
static func damage_at(id: String, distance_tiles: float) -> int:
	var key:=balance_id(id)
	if key.is_empty(): return -1
	var p: Dictionary=DAMAGE_PROFILES[key]
	var start: float=p.range*p.falloffStart
	if not is_finite(distance_tiles) or distance_tiles<=start or p.range<=start: return _round(p.dmg)
	var t:=clampf((distance_tiles-start)/(p.range-start),0,1)
	return maxi(1,_round(p.dmg*(1-t*(1-p.minDamageMul))))
static func current_shot_damage(damage: float, marksman: float, critical: bool, critical_multiplier: float) -> int:
	if not is_finite(damage) or not is_finite(marksman) or not is_finite(critical_multiplier):return -1
	return maxi(1,_round(damage*(1+clampf(marksman,0,5)*.05)*(critical_multiplier if critical else 1.0)))
static func penetrating_damage(id: String, distance_tiles: float, hit_index: int, critical: bool, critical_multiplier: float) -> Dictionary:
	var key:=balance_id(id)
	if key not in PENETRATING or hit_index<0 or hit_index>=(3 if key=="sniper" else 2) or not is_finite(critical_multiplier):return _failure("penetrating_context")
	var multiplier:=pow(.72 if key=="sniper" else (.62 if key=="nagan" else .56),hit_index)
	return {"ok":true,"damage":maxi(1,_round(damage_at(id,distance_tiles)*multiplier*(critical_multiplier if critical else 1.0))),"direction_multiplier":1.65 if key=="nagan" else 1.0}
static func shotgun_damage(actual_hit_distances_tiles: Array, marksman: float, critical: bool, critical_multiplier: float) -> Dictionary:
	if actual_hit_distances_tiles.is_empty() or actual_hit_distances_tiles.size()>7:return _failure("actual_pellet_contacts_required")
	var damage:=0.0
	for distance: Variant in actual_hit_distances_tiles:
		if not _finite(distance) or distance<0:return _failure("distance")
		damage+=maxf(1,(76.0/7.0)*(damage_at("shotgun",distance)/76.0))
	var result:=current_shot_damage(damage,marksman,critical,critical_multiplier)
	return {"ok":true,"damage":result} if result>=0 else _failure("shot_context")

## Called only AFTER actual source fire/ammo admission. Random sample belongs
## to that accepted source shot, not each pellet/target/render frame.
static func accepted_shot_modifiers(id: String, now_ms: float, last_nagan_at_ms: float, nagan_chain: int, random_sample: float) -> Dictionary:
	var key:=balance_id(id)
	if key.is_empty() or not is_finite(now_ms) or not is_finite(last_nagan_at_ms) or not is_finite(random_sample) or random_sample<0 or random_sample>=1 or nagan_chain<0:return _failure("shot_context")
	var chain:=0 if key=="nagan" and now_ms-last_nagan_at_ms>1050 else nagan_chain
	var duel:=key=="nagan" and now_ms-last_nagan_at_ms>=800
	return {"ok":true,"critical":duel or random_sample<.12,"critical_multiplier":1.8 if duel else 1.25,"nagan_critical":duel,"nagan_chain":mini(3,chain+1) if key=="nagan" else chain,"nagan_last_at_ms":now_ms if key=="nagan" else last_nagan_at_ms,"nagan_admission_cooldown_seconds":NAGAN_CADENCE[mini(chain,3)] if key=="nagan" else null}

## This validates geometry that the host has already obtained. resolved=true
## is exclusively for the real source resolveContact callback's result, never a
## caller-provided assertion that replaces a native ray or target life lease.
static func contact_geometry(hit: Dictionary, target: Dictionary, player: Dictionary, angle: float, range_tiles: float, resolved: bool, muzzle: Dictionary = {}) -> Dictionary:
	if not _point(hit.get("point")) or not _point(hit.get("normal")) or not _finite(target.get("r")) or not _finite(target.get("c")) or not _finite(player.get("r")) or not _finite(player.get("c")) or not is_finite(angle) or not is_finite(range_tiles) or range_tiles<=0:return _failure("geometry")
	var p: Dictionary=hit.point;var n: Dictionary=hit.normal
	var length:=_normal_length(n)
	if not is_finite(length) or length<.01:return _failure("normal")
	var r: float=p.z/SCALE;var c: float=p.x/SCALE
	if _hypot2(r-player.r,c-player.c)>range_tiles+1 or _hypot2(r-target.r,c-target.c)>1.5:return _failure("range")
	if not resolved:
		var mr: Variant=muzzle.get("r",player.r);var mc: Variant=muzzle.get("c",player.c)
		if not _finite(mr) or not _finite(mc):return _failure("muzzle")
		var dr: float=r-mr;var dc: float=c-mc
		if dr*sin(angle)+dc*cos(angle)<0 or absf(dr*cos(angle)-dc*sin(angle))>.035:return _failure("spread_direction")
	return {"ok":true,"contact":{"point":p.duplicate(),"normal":{"x":n.x/length,"y":n.y/length,"z":n.z/length},"zone":str(hit.zone) if hit.get("zone") else "torso"}}

static func _int32(value: float) -> int:
	var n:=fmod(floor(value) if value>=0 else ceil(value),4294967296.0)
	if n<0:n+=4294967296.0
	return int(n-4294967296.0 if n>=2147483648.0 else n)

## Exact ordinary hitNpc scalar branch as a PROPOSAL. Requires real local
## ownership, admitted shot/contact and fresh target generation in its caller.
## Source callbacks/social/medical scheduling/blood/death rendering are not
## replaced. Return state is NOT an instruction to overwrite all NPC state.
static func ordinary_hit_plan(state: Dictionary, hit: Dictionary, decisions: Dictionary, scope: String) -> Dictionary:
	if scope!="local_walk_ordinary":return _failure("local_authority_required")
	if not state.get("source_id") is String or state.source_id.is_empty() or not _finite(state.get("life_generation")) or state.life_generation<1 or floor(state.life_generation)!=state.life_generation:return _failure("target_life_binding")
	if not _finite(state.get("hp")) or not _finite(state.get("r")) or not _finite(state.get("c")):return _failure("target_state")
	for key: String in HIT_NUMBERS:
		if not _finite(hit.get(key)):return _failure("hit_context")
	if hit.damage<=0 or hit.now_ms<0 or not hit.get("weapon_id") is String or balance_id(hit.weapon_id).is_empty() or balance_id(hit.weapon_id)=="rpg":return _failure("ordinary_bullet_required")
	if not decisions.get("path_passable") is bool:return _failure("actual_path_decision_required")
	var source: Variant=hit.get("source")
	if source!=null and not source is Dictionary:return _failure("source_identity")
	if source!=null and source.has("kind") and not source.kind is String:return _failure("source_identity")
	if source==null and (not hit.get("player_uid") is String or hit.player_uid.is_empty()):return _failure("source_identity")
	var next:=state.duplicate(true)
	if state.get("dead",false):return {"ok":true,"applied":false,"state":next,"reason":"dead"}
	var player_attack: bool=source==null or source.get("kind")=="player"
	if (state.get("_empireBoss",false) or state.get("_empireCrew",false)) and player_attack:return _failure("source_empire_handler_required")
	next._threeHitAngle=atan2(hit.dir_r,hit.dir_c)
	next._threeHitPower=clampf(hit.damage/72.0,.18,1.6)
	next._threeHitWeapon=hit.weapon_id
	next._lastViolentSource=source.duplicate(true) if source!=null else {"kind":"player","uid":hit.player_uid}
	next._lastViolentAt=hit.now_ms
	if state.get("_invulnerable",false):return {"ok":true,"applied":false,"state":next,"reason":"invulnerable"}
	var was_downed: bool=bool(state.get("_medicalDowned",false))
	next.hp=maxi(0,_int32(state.hp)-_int32(hit.damage))
	var proposed: Dictionary={"r":state.r+hit.dir_r*.09,"c":state.c+hit.dir_c*.09}
	if decisions.path_passable:next.r=proposed.r;next.c=proposed.c
	next.idleUntil=hit.now_ms+250
	var eligible: bool=next.hp<=0 and not was_downed and not state.get("_policeCriminal",false) and not state.get("_guard",false) and not state.get("_cashier",false)
	if eligible and (not _finite(decisions.get("survival_roll")) or decisions.survival_roll<0 or decisions.survival_roll>=1):return _failure("actual_survival_sample_required")
	var survived: bool=eligible and decisions.survival_roll<.72
	if survived:
		next.hp=1;next._medicalDowned=true;next._medicalDownedAt=hit.now_ms;next._medicalBleedoutAt=hit.now_ms+30000;next._deathFromDowned=false
		next._knockedAt=hit.now_ms;next._knockedUntil=next._medicalBleedoutAt;next.walkPhase=0;next.snitching=false;next.panicUntil=0;next._forcedCrawl=true;next.panicSrcR=hit.player_r;next.panicSrcC=hit.player_c;next._ambulanceDispatched=false
	elif next.hp<=0:
		next.dead=true;next._deathFromDowned=was_downed;next.deadAt=hit.now_ms
		next._medicalDowned=false;next._medicalDownedAt=0;next._medicalBleedoutAt=0;next._knockedUntil=0;next._forcedCrawl=false;next.walking=false
	return {"ok":true,"applied":true,"state":next,"hp_at_confirm":maxi(0,_int32(state.hp)-_int32(hit.damage)),"medical_survival":survived,"fatal":bool(next.get("dead",false)),"proposed_source_position":proposed,"requested_world_displacement":{"x":hit.dir_c*.09*SCALE,"y":0.0,"z":hit.dir_r*.09*SCALE},"source_confirm_precedes_survival_and_death":true}
