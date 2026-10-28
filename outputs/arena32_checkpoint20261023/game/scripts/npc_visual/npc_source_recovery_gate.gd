extends RefCounted
## Pure source projection + persistent recovery intent. Never clears a source
## medical state, moves a body, applies HP, or proves collision clearance.
const POPULATION_SHA := "fc3c4cc243ccb7700526b6680fa7ee83e7fbad9e83798880458cb1dd8c0816ad"
const LIFECYCLE_SHA := "e2ffa20660b666f9fe993b3ccaed150107789dee6b3456e2e77dc4732d7940e5"
const ACTOR_SHA := "ceb7266a1fcb9013eda78b6dce8ee67cf5f80c547beb2850e2be76602110af30"
const FLAGS := ["dead","deathConfirmed","fatal","meleeStunned","downed","forcedCrawl","prone","medicalDowned","deathFromDowned"]
const CLOCKS := ["deadAt","downedAt","downedUntil","meleeStunnedAt","meleeStunnedUntil"]
static func _finite(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))
static func _yes(v: Variant) -> bool:
	return v is bool and v
static func _no(v: Variant) -> bool:
	return v is bool and not v
static func _text(v: Variant) -> bool:
	return v is String and not v.is_empty() and v.length() <= 256
static func _number(row: Dictionary,key: String) -> float:
	return float(row[key]) if _finite(row.get(key)) else 0.0
static func _unknown(reason: String) -> Dictionary:
	return {"known":false,"status":"UNKNOWN","reason":reason,"state":{},"request_clearance":false,"rise_permitted":false,"apply_pose":false,"damage_authority":false}

static func source_projection(row: Dictionary,now_ms: float, source_death_key: Variant = null) -> Dictionary:
	if not is_finite(now_ms) or now_ms < 0: return {}
	for key: String in FLAGS:
		if row.has(key) and row[key] != null and not row[key] is bool: return {}
	for key: String in CLOCKS:
		if row.has(key) and row[key] != null and not _finite(row[key]): return {}
	if row.get("lifeState") != null and not row.lifeState is String: return {}
	var raw_state: String = row.get("lifeState","") if row.get("lifeState") != null else ""
	var state := raw_state.to_lower()
	var nonfatal := _yes(row.get("meleeStunned")) or _yes(row.get("downed")) or state == "downed"
	var confirmed := _yes(row.get("deathConfirmed")) or _yes(row.get("fatal")) or state in ["dead","corpse"]
	var dead := confirmed or (not _no(row.get("deathConfirmed")) and _yes(row.get("dead")) and not nonfatal)
	var at := _number(row,"deadAt")
	var death_key: Variant = "dead" if dead else null
	if dead and at > 0:
		# Preserve the actual source Number.toString key: Godot str(float) rounds
		# differently. Never invent a different lifecycle epoch from a timestamp.
		if source_death_key != null:
			if not _text(source_death_key) or not source_death_key.is_valid_float() or source_death_key.to_float() != at: return {}
			death_key = source_death_key
		elif at == floor(at) and at <= 9007199254740991.0: death_key = str(int(at))
		else: return {}
	var life := {"dead":dead,"explicitAlive":not dead and not nonfatal and _no(row.get("dead")),"key":death_key,"age":maxf(0.0,(now_ms-at)/1000.0) if dead and at > 0 else null,"side":-1 if _finite(row.get("deathSide")) and row.deathSide == -1 else 1}
	if dead and _yes(row.get("deathFromDowned")): life.fromDowned = true
	var forced := _yes(row.get("forcedCrawl")) or _yes(row.get("prone"))
	var downed := _yes(row.get("downed")) or raw_state == "downed"
	var flag := _yes(row.get("meleeStunned")) or (downed and not forced)
	var until := _number(row,"downedUntil" if downed else "meleeStunnedUntil")
	var start := _number(row,"downedAt" if downed else "meleeStunnedAt")
	if start == 0: start = at
	var stun := {"active":flag and (until == 0 or now_ms < until),"age":maxf(0.0,(now_ms-start)/1000.0) if start > 0 else null,"remaining":maxf(0.0,(until-now_ms)/1000.0) if until > 0 else null,"endedAge":maxf(0.0,(now_ms-until)/1000.0) if until > 0 else 0.0}
	return {"lifecycle":life,"stun":stun,"forced_prone":forced,"medical_held":_yes(row.get("medicalDowned")),"source_now_ms":now_ms}

static func project(row: Dictionary, previous: Dictionary, current: Dictionary) -> Dictionary:
	for key: String in ["session_id","source_id"]:
		if not _text(current.get(key)): return _unknown("identity:"+key)
	if not row.get("id") is String or row.id != current.source_id: return _unknown("source_id")
	for key: String in ["life_generation","reaction_generation","tick"]:
		if not current.get(key) is int or current[key] < (0 if key == "tick" else 1): return _unknown("generation:"+key)
	for key: String in ["source_state_complete","current_lifetime_confirmed","nonfatal_reaction_confirmed","final_death_confirmed","get_up_gate_ready","source_dead"]:
		if not current.get(key) is bool: return _unknown("receipt_shape:"+key)
	if not current.source_state_complete or not current.current_lifetime_confirmed: return _unknown("current_source_required")
	for key: String in ["population_sha256","lifecycle_sha256","actor_sha256"]:
		if not current.get(key) is String: return _unknown("source_binding")
	if current.population_sha256 != POPULATION_SHA or current.lifecycle_sha256 != LIFECYCLE_SHA or current.actor_sha256 != ACTOR_SHA: return _unknown("source_binding")
	if not current.get("clearance") is String or current.clearance not in ["UNKNOWN","BLOCKED","CLEAR"]: return _unknown("clearance_shape")
	if not _finite(current.get("source_now_ms")) or current.source_now_ms < 0: return _unknown("clock")
	if not previous.is_empty():
		for key: String in ["session_id","source_id","life_generation"]:
			if typeof(previous.get(key)) != typeof(current[key]) or previous[key] != current[key]: return _unknown("stale_lifetime")
		for key: String in ["reaction_generation","tick"]:
			if not previous.get(key) is int or previous[key] < (0 if key == "tick" else 1) or previous[key] > current[key]: return _unknown("stale_generation_or_tick")
		if not _finite(previous.get("source_now_ms")) or previous.source_now_ms < 0 or previous.source_now_ms > current.source_now_ms: return _unknown("stale_clock")
		for key: String in ["final_dead","recovery_pending"]:
			if not previous.get(key) is bool: return _unknown("previous_shape")
	var source := source_projection(row,float(current.source_now_ms),current.get("source_death_key"))
	if source.is_empty(): return _unknown("source_shape")
	if not current.has("source_death_key") or typeof(current.source_death_key) != typeof(source.lifecycle.key) or current.source_death_key != source.lifecycle.key or current.source_dead != source.lifecycle.dead: return _unknown("lifecycle_receipt_mismatch")
	var ack: Variant = current.get("ack_standing")
	if ack != null:
		if not ack is Dictionary or not _yes(ack.get("root_verified_physical_completion")): return _unknown("standing_ack_required")
		for key: String in ["session_id","source_id","life_generation","reaction_generation","tick","source_now_ms"]:
			if typeof(ack.get(key)) != typeof(current[key]) or ack[key] != current[key]: return _unknown("stale_standing_ack")
	var new_reaction: bool = previous.is_empty() or current.reaction_generation > previous.reaction_generation
	var final_dead: bool = source.lifecycle.dead or current.final_death_confirmed or _yes(previous.get("final_dead"))
	var pending: bool = _yes(previous.get("recovery_pending")) or (new_reaction and current.nonfatal_reaction_confirmed) or source.stun.active
	var status := "IDLE"
	var request := false
	var permitted := false
	if final_dead: pending = false; status = "FINAL_DEAD"
	elif source.medical_held or source.forced_prone:
		status = "MEDICAL_OWNER_REQUIRED" if source.medical_held else "SOURCE_PRONE_OWNER_REQUIRED"
	elif source.stun.active: status = "HELD_SOURCE"
	elif pending:
		request = true
		permitted = current.clearance == "CLEAR" and current.get_up_gate_ready
		status = "RISE_PERMITTED" if permitted else "WAIT_CLEARANCE"
		if permitted and ack != null: pending = false; request = false; permitted = false; status = "RECOVERED"
	var state := {"session_id":current.session_id,"source_id":current.source_id,"life_generation":current.life_generation,"reaction_generation":current.reaction_generation,"tick":current.tick,"source_now_ms":current.source_now_ms,"final_dead":final_dead,"recovery_pending":pending}
	return {"known":true,"status":status,"state":state,"source":source,"request_clearance":request,"request_help_or_crawl":not final_dead and (source.medical_held or source.forced_prone),"rise_permitted":permitted,"apply_pose":false,"damage_authority":false}
