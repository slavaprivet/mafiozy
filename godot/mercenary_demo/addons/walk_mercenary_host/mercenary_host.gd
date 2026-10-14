extends RefCounted
## Source Walk ownership adapter. No movement solver, actor construction or hiring price.
const PROFESSIONS := ["medic", "bruiser", "safecracker", "engineer", "demolitions"]
const PROFESSION_NAMES := {"medic":"Медик","bruiser":"Громила","safecracker":"Медвежатник","engineer":"Электрик-резчик","demolitions":"Подрывник"}
const SKILL_NAMES := {"medicine":"Медицина","fitness":"Выносливость","melee":"Рукопашный бой","intimidation":"Запугивание","lockpicking":"Взлом","cutting":"Резка","explosives":"Взрывы"}
const FIRST_MALE := ["Лука","Марко","Карло","Антонио","Винченцо","Паоло","Марио","Франко","Джованни","Сальваторе","Энцо","Роберто","Дарио","Бруно","Пьетро","Анджело"]
const FIRST_FEMALE := ["Лючия","Мария","Анна","Джулия","София","Кьяра","Франческа","Паола","Елена","Роза","Валентина","Изабелла","Карла","Джованна","Анджела","Сильвия"]
const LAST_NAMES := ["Рицци","Моретти","Конти","Романо","Ломбарди","Марино","Греко","Ферраро","Коста","Фонтана","Беллини","Риччи","Манчини","Коломбо","Витале","Де Лука"]
const EXCLUDED := ["dead", "_empireBoss", "_empireGuard", "_specialistId", "_medicalDowned", "_hostile", "_fighting", "_fightingMelee", "gang", "snitching", "_invulnerable", "_guard", "_cashier", "_empireCrew", "_policeCriminal", "_clientOfBiz", "_botCorpse", "_transientCorpseId", "_said", "_civilianTrip", "_civilianTripRiding", "_ambientTrafficDriver", "_civilianSeat", "vehicleId", "vehicle_id", "_inVehicle", "_inCar", "_insideBuilding", "_residentIndoors", "_interiorId", "interior_id", "_evacuated", "_carriedByAmbulance"]
var _options: Dictionary
var _core: RefCounted
var _candidates: Dictionary = {}
var _members: Dictionary = {}
var _originals: Dictionary = {}
var _inventory_seen: Array = []
var _inventory_object_seen: Dictionary = {}
var _presentation_cache: Dictionary = {}
var _conversations: Dictionary = {}
var _disposed := false
var _last_candidates := -INF

func _init(options: Dictionary = {}) -> void:
	_options = options.duplicate()

func bind_core(core: RefCounted) -> bool:
	if _disposed or _core != null or core == null: return false
	for name in ["recruit", "dismiss", "stats", "set_weapon", "get_record", "get_roster", "available_actions", "command", "cancel", "get_queue", "get_action", "update"]:
		if not core.has_method(name): return false
	_core = core
	return true

func core_options() -> Dictionary:
	return {"getMember":Callable(self,"get_member"), "getTarget":Callable(self,"get_target"), "moveMember":Callable(self,"move_member"), "performEffect":Callable(self,"perform_effect"), "onAction":Callable(self,"on_action"), "now":Callable(self,"now")}

func _call(name: String, args: Array = [], fallback: Variant = null) -> Variant:
	var callback: Callable = _options.get(name, Callable())
	return callback.callv(args) if callback.is_valid() else fallback

func now() -> float:
	return float(_call("now", [], Time.get_unix_time_from_system()))

func _allowed() -> bool:
	return not _disposed and _core != null and _call("is_local", [], false) == true

func _fail(reason: String) -> Dictionary:
	return {"ok":false, "reason":reason}

func _truthy(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is String: return value != ""
	if value is int or value is float: return value != 0 and not is_nan(float(value))
	return true # Source empty objects/arrays are truthy.

func _quantity(item: Dictionary) -> float:
	return maxf(0.0, float(item.get("qty",item.get("count",item.get("quantity",0)))))

func _set_quantity(item: Dictionary, value: float) -> void:
	item.qty = value
	if item.has("count"): item.count = value
	if item.has("quantity"): item.quantity = value

func _inventory() -> Array:
	return _call("get_inventory", [], [])

func _weapon_item(id: String) -> Dictionary:
	for item in _inventory():
		if item is Dictionary and str(item.get("id","")) == id and item.get("type") == "weapon" and _quantity(item) > 0: return item
	return {}

func _take_weapon(id: String) -> Variant:
	var item := _weapon_item(id)
	if item.is_empty(): return null
	var copy := item.duplicate()
	copy.merge({"qty":1,"count":1,"quantity":1},true)
	_set_quantity(item,_quantity(item)-1)
	_mark_inventory_seen(item)
	return copy

func _mark_inventory_seen(item: Dictionary) -> void:
	var token: Variant = _call("inventory_identity",[item])
	if token is Object and is_instance_valid(token):
		var id: int = token.get_instance_id()
		if not _inventory_object_seen.has(id):
			for old_id in _inventory_object_seen.keys():
				if _inventory_object_seen[old_id].get_ref() == null: _inventory_object_seen.erase(old_id)
			_inventory_object_seen[id] = weakref(token)
		return
	for seen in _inventory_seen:
		if is_same(seen,item): return
	_inventory_seen.append(item)

func _has_seen_inventory(item: Dictionary) -> bool:
	var token: Variant = _call("inventory_identity",[item])
	if token is Object and is_instance_valid(token):
		var tracked: WeakRef = _inventory_object_seen.get(token.get_instance_id())
		return tracked != null and tracked.get_ref() == token
	for seen in _inventory_seen:
		if is_same(seen,item): return true
	return false

func reconcile_inventory(items: Array) -> Array:
	if not _allowed(): return items
	var reserved: Dictionary = {}
	for record in _core.get_roster():
		if record.weapon is Dictionary:
			var id := str(record.weapon.id)
			reserved[id] = reserved.get(id,0)+1
	for item in items:
		if not item is Dictionary or item.get("type") != "weapon" or _has_seen_inventory(item): continue
		_mark_inventory_seen(item)
		var id := str(item.get("id",item.get("item_id","")))
		var remaining := float(reserved.get(id,0))
		if remaining > 0:
			var used := minf(_quantity(item),remaining)
			_set_quantity(item,_quantity(item)-used)
			reserved[id] = remaining-used
	return items

func _return_weapon(weapon: Variant) -> void:
	if not weapon is Dictionary: return
	for item in _inventory():
		if item is Dictionary and item.get("id") == weapon.get("id") and item.get("type") == "weapon":
			_set_quantity(item,_quantity(item)+1)
			_mark_inventory_seen(item)
			return
	var item: Dictionary = weapon.duplicate()
	item.merge({"qty":1,"count":1,"quantity":1},true)
	_inventory().append(item)
	_mark_inventory_seen(item)

func _position(row: Dictionary) -> Variant:
	var body: Node3D = row.get("body")
	if not is_instance_valid(body) or not body.is_inside_tree(): return null
	var p := body.global_position
	if not p.is_finite(): return null
	# Reuse the row's coordinate container; dictionary access cannot move the body.
	var position: Dictionary = row.get("position",{})
	position.x = p.x
	position.y = p.y
	position.z = p.z
	row.position = position
	return position

func _horizontal_distance(row: Dictionary) -> float:
	var position: Variant = _position(row)
	var player: Variant = _call("get_player_position")
	if not position is Dictionary or not player is Dictionary: return INF
	return Vector2(float(position.x)-float(player.x),float(position.z)-float(player.z)).length()

func _eligible(row: Dictionary) -> bool:
	if not row.has("id") or float(row.get("hp",0)) <= 0 or _position(row) == null: return false
	for flag in EXCLUDED:
		if _truthy(row.get(flag,false)): return false
	return _call("is_respawnable_resident", [row], true) == true and _call("is_combat_session_target",[row],false) != true

func _present_and_eligible(row: Dictionary, residents: Array) -> bool:
	for live in residents:
		if is_same(live,row): return _eligible(row)
	return false

func _personal_name(id: String, look: Dictionary) -> String:
	var hash_value: int = 2166136261
	for character in id:
		var code: int = character.unicode_at(0)
		if code > 0xffff: code = 0xd800 + ((code-0x10000)>>10)
		hash_value = ((hash_value^code)*16777619)&0xffffffff
	var first: Array = FIRST_FEMALE if float(look.get("gender",0)) == 1 else FIRST_MALE
	return first[hash_value%first.size()]+" "+LAST_NAMES[int(hash_value/first.size())%LAST_NAMES.size()]

func adopt_candidates(force: bool = false) -> void:
	if not _allowed() or (not force and now()-_last_candidates < 2.0): return
	_last_candidates = now()
	var residents: Array = _call("get_residents",[],[])
	for id in _candidates.keys():
		var row: Dictionary = _candidates[id].resident
		var present := false
		for live in residents:
			if is_same(live,row): present = true; break
		if not present or not _eligible(row): _candidates.erase(id)
	var occupied: Dictionary = {}
	for record in _core.get_roster(): occupied[record.profession] = true
	for candidate in _candidates.values(): occupied[candidate.profession] = true
	var choices: Array = []
	var hired_sources: Dictionary = {}
	for member in _call("get_gang",[],_members.values()):
		if member is Dictionary and member.has("sourceBotId"): hired_sources[str(member.sourceBotId)] = true
	for resident in residents:
		if resident is Dictionary and _eligible(resident) and not hired_sources.has(str(resident.id)): choices.append(resident)
	choices.sort_custom(func(a,b):
		var da := _horizontal_distance(a)
		var db := _horizontal_distance(b)
		return da < db if da != db else str(a.id).casecmp_to(str(b.id)) < 0)
	for profession in PROFESSIONS:
		if occupied.has(profession): continue
		for resident in choices:
			var id := str(resident.id)
			if _candidates.has(id) or (resident.has("_mercenaryProfession") and resident._mercenaryProfession != profession): continue
			resident._mercenaryProfession = profession
			resident._mercenaryOwnWeapon = "pistol"
			resident.weapon = "pistol"
			if str(resident.get("name","")).strip_edges() == "": resident.name = _personal_name(id,resident.get("look",{}))
			_candidates[id] = {"resident":resident,"profession":profession}
			break

func recruit(id: String, weapon_id: String = "") -> Dictionary:
	if not _allowed(): return _fail("authority_unavailable")
	adopt_candidates()
	if not _candidates.has(id): return _fail("candidate_unavailable")
	var candidate: Dictionary = _candidates[id]
	var resident: Dictionary = candidate.resident
	var present := false
	for live in _call("get_residents",[],[]):
		if is_same(live,resident): present = true; break
	if not present or not _eligible(resident): return _fail("candidate_unavailable")
	if _horizontal_distance(resident) > 3.0: return _fail("candidate_distance")
	if _call("get_gang",[],_members.values()).size() >= maxi(5,int(_options.get("capacity",5))): return _fail("squad_full")
	if weapon_id != "" and _weapon_item(weapon_id).is_empty(): return _fail("weapon_unavailable")
	var transfer: Callable = _options.get("transfer_member",Callable())
	if not transfer.is_valid(): return _fail("ownership_not_connected")
	var member_id := "merc_"+id
	var receipt: Dictionary = _core.recruit({"id":member_id,"profession":candidate.profession,"name":resident.get("name","")})
	if not receipt.get("ok",false): return receipt
	var base_hp := float(resident.get("max_hp",resident.hp))
	var max_hp := roundf(base_hp*float(_core.stats(member_id).hpMultiplier))
	var member := {"id":member_id,"sourceBotId":id,"name":resident.get("name",""),"look":resident.get("look",{}).duplicate(),"body":resident.body,"hp":max_hp,"max_hp":max_hp,"_mercenaryBaseHp":base_hp,"weapon":"pistol","dead":false,"_mercenaryOrder":"follow"}
	if transfer.call(resident,member) != true:
		_core.dismiss(member_id)
		return _fail("ownership_rejected")
	var weapon: Variant = _take_weapon(weapon_id) if weapon_id != "" else null
	member.weapon = weapon.id if weapon is Dictionary else "pistol"
	_core.set_weapon(member_id,weapon)
	_members[member_id] = member
	_originals[member_id] = resident
	_candidates.erase(id)
	_changed()
	return {"ok":true,"memberId":member_id}

func begin_conversation(id: String) -> Dictionary:
	if not _allowed(): return _fail("authority_unavailable")
	# Source raw() resolves presentation aliases only for an owned member.
	var member_id := id.trim_prefix("npc:")
	if member_id.begins_with("npc_crew_"): member_id = member_id.substr(9)
	elif member_id.begins_with("crew_"): member_id = member_id.substr(5)
	var member: Variant = _members.get(member_id)
	if member is Dictionary and _core.get_record(str(member.id)) != null:
		if float(member.get("hp",0)) <= 0 or _truthy(member.get("dead")) or _truthy(member.get("_mercenaryHospital")) or _horizontal_distance(member) > 2.5:
			return _fail("member_conversation_unavailable")
		member._mercenaryConversation = true
		_conversations[id] = member
		return {"ok":true}
	var candidate: Variant = _candidates.get(id)
	if not candidate is Dictionary or not _present_and_eligible(candidate.resident,_call("get_residents",[],[])) or _horizontal_distance(candidate.resident) > 3.0:
		return _fail("resident_conversation_unavailable")
	# Physical resident AI belongs to the registry owner. Require both halves of
	# its source hold/end/resume lifecycle before accepting a resident dialogue.
	for method: String in ["begin_npc_player_conversation","end_npc_player_conversation","resume_npc_after_player_conversation"]:
		var callback: Callable = _options.get(method,Callable())
		if not callback.is_valid(): return _fail("conversation_owner_not_connected")
	var resident: Dictionary = candidate.resident
	if _call("begin_npc_player_conversation",[resident],false) != true:
		return _fail("resident_conversation_rejected")
	_conversations[id] = resident
	return {"ok":true}

func end_conversation(id: String) -> bool:
	if _disposed: return false
	var person: Variant = _conversations.get(id)
	if person == null and _candidates.has(id): person = _candidates[id].resident
	_conversations.erase(id)
	if not person is Dictionary: return false
	if _core != null and _core.get_record(str(person.get("id",""))) != null:
		person.erase("_mercenaryConversation")
		return true
	var residents: Array = _call("get_residents",[],[])
	var present := false
	for resident: Variant in residents:
		if is_same(resident,person): present = true; break
	# Source demo lineup intentionally stays held when a dialogue closes.
	var stamp := float(_call("performance_now_ms",[],Time.get_ticks_msec()))
	if _call("demo_supported",[],false) == true and _truthy(person.get("_mercenaryDemoLineup")) and present and _eligible(person) and not (float(person.get("panicUntil",0)) > stamp):
		_call("begin_npc_player_conversation",[person],false)
		return true
	_call("end_npc_player_conversation",[person])
	_call("resume_npc_after_player_conversation",[person,present])
	return true

func get_member(id: String) -> Variant:
	if _disposed or not _members.has(id): return null
	var member: Dictionary = _members[id]
	var record: Variant = _core.get_record(id)
	if not record is Dictionary or _position(member) == null: return null
	return {"id":id,"kind":"npc","position":member.position.duplicate(),"hp":member.hp,"dead":false,"downed":float(member.hp)<=0,"available":record.status != "hospital","revivable":record.status != "hospital","intimidatable":false,"queued":record.queued,"followArrived":_horizontal_distance(member)<7}

func get_target(id: String) -> Variant:
	var member: Variant = get_member(id)
	return member if member != null else _call("get_target",[id])

func move_member(id: String, target: Variant, options: Dictionary) -> void:
	if _disposed or not _members.has(id): return
	_call("move_member",[id,target,options])

func perform_effect(effect: Dictionary) -> Variant:
	if not _allowed(): return false
	var id := str(effect.get("memberId",""))
	var action: Variant = _core.get_action(id)
	if effect.get("kind") == "plant_bomb" and action is Dictionary and action.get("armed",false) and action.get("id") == effect.get("actionId"):
		return _call("perform_effect",[effect],false)
	if not _members.has(id): return false
	return _call("perform_effect",[effect],false)

func on_action(id: String, action: Dictionary) -> void:
	if _disposed or not _members.has(id): return
	_members[id]._mercenaryAction = action
	_call("on_action",[id,action])

func command(kind: String, target: Dictionary) -> Dictionary:
	if not _allowed(): return _fail("authority_unavailable")
	var options: Array = []
	for option in _core.available_actions(target):
		if option.kind == kind and option.available: options.append(option)
	options.sort_custom(func(a,b):
		return int(a.willQueue)<int(b.willQueue) if a.willQueue != b.willQueue else int(a.queuedCount)<int(b.queuedCount))
	if options.is_empty(): return _fail("specialist_unavailable")
	var receipt: Dictionary = _core.command(options[0].memberId,kind,target.id)
	if receipt.get("ok",false): _changed()
	return receipt

func cancel_command(id: String = "") -> Dictionary:
	if not _allowed(): return _fail("authority_unavailable")
	var cancelled := 0
	var blocked: Array = []
	for record in _core.get_roster():
		if id != "" and record.id != id: continue
		if _core.get_action(record.id) == null and _core.get_queue(record.id).is_empty() and not record.get("resumeWork"): continue
		var receipt: Dictionary = _core.cancel(record.id)
		if receipt.get("ok",false) or receipt.get("queuedCleared",0): cancelled += 1
		else: blocked.append({"memberId":record.id,"reason":receipt.reason})
	if cancelled > 0: _changed()
	return {"ok":cancelled>0,"cancelled":cancelled,"blocked":blocked}

func equip(id: String, weapon_id: String) -> Dictionary:
	if not _allowed(): return _fail("authority_unavailable")
	var record: Variant = _core.get_record(id)
	if not _members.has(id) or not record is Dictionary or record.status == "hospital": return _fail("member_unavailable")
	var weapon: Variant = _take_weapon(weapon_id)
	if weapon == null: return _fail("weapon_unavailable")
	_return_weapon(record.weapon)
	_core.set_weapon(id,weapon)
	_members[id].weapon = weapon.id
	_changed()
	return {"ok":true}

func dismiss(id: String) -> Dictionary:
	if not _allowed(): return _fail("authority_unavailable")
	var record: Variant = _core.get_record(id)
	if not _members.has(id) or not record is Dictionary: return _fail("member_unavailable")
	var callback: Callable = _options.get("dismiss_member",Callable())
	if not callback.is_valid(): return _fail("ownership_not_connected")
	var member: Dictionary = _members[id]
	var resident: Dictionary = _originals[id]
	# The registry owner releases this same person at the current body position.
	if callback.call(member,resident) != true: return _fail("ownership_rejected")
	_return_weapon(record.weapon)
	_core.dismiss(id)
	_members.erase(id)
	_originals.erase(id)
	_last_candidates = -INF # Source dismissal permits immediate candidate adoption.
	_changed()
	return {"ok":true}

func _changed() -> void:
	_call("sync_inventory",[_inventory()])
	_call("persist",[_core.snapshot(),export_host_rows()])

func export_host_rows() -> Array:
	var result: Array = []
	var world_scale := float(_options.get("world_scale",4.1))
	for member in _members.values():
		var position: Variant = _position(member)
		if not position is Dictionary or not is_finite(world_scale) or world_scale <= 0: continue
		var row := {"id":member.id,"sourceBotId":member.sourceBotId,"name":member.name,"look":member.look.duplicate(true),"r":float(position.z)/world_scale,"c":float(position.x)/world_scale,"hp":member.hp,"max_hp":member.max_hp,"weapon":member.weapon,"baseHp":member._mercenaryBaseHp,"_mercenaryLifeGeneration":member.get("_mercenaryLifeGeneration",0),"_mercenaryOrder":member.get("_mercenaryOrder","follow"),"_mercenaryRally":member.get("_mercenaryRally")}
		for key in ["faction","gangName"]:
			if member.has(key): row[key] = member[key]
		if member.get("_mercenaryVehicleExplosionFatal") == true:
			row.merge({"_mercenaryVehicleExplosionFatal":true,"dead":true,"deathConfirmed":true,"deadAt":member.get("deadAt",0),"_lifeState":"dead"},true)
		var rescue: Variant = member.get("_mercenaryQaRescueUntil")
		if _options.get("qa_enabled",false) == true and (rescue is int or rescue is float) and is_finite(float(rescue)) and float(rescue)>now():
			row._mercenaryQaRescueUntil = minf(now()+600.0,float(rescue))
		result.append(row)
	return result

func bind_restored_member(member: Dictionary, original_resident: Dictionary) -> bool:
	# Persistence helper owns validation/core.restore; registry owner owns placement.
	if _disposed or _core == null or not member.has("id") or not member.has("sourceBotId") or _position(member) == null: return false
	if _core.get_record(str(member.id)) == null or _members.has(str(member.id)): return false
	for owned in _members.values():
		if owned.body == member.body or owned.sourceBotId == member.sourceBotId: return false
	_members[str(member.id)] = member
	_originals[str(member.id)] = original_resident
	_candidates.erase(str(member.sourceBotId))
	return true

func get_roster() -> Dictionary:
	if _disposed or _core == null: return {"members":[],"candidates":[],"weapons":[]}
	adopt_candidates()
	var result := {"capacity":maxi(5,int(_options.get("capacity",5))),"members":[],"candidates":[],"weapons":[]}
	var cash: Variant = _call("get_cash")
	if cash != null: result.cash = cash
	for item in _inventory():
		if item is Dictionary and item.get("type") == "weapon" and _quantity(item)>0:
			result.weapons.append({"id":item.id,"label":item.get("name",item.id),"count":_quantity(item)})
	for record in _core.get_roster():
		if not _members.has(record.id): continue
		var member: Dictionary = _members[record.id]
		var row: Dictionary = record.duplicate(true)
		var action: Variant = _core.get_action(record.id)
		row.merge({"name":member.name,"hp":member.hp,"maxHp":member.max_hp,"weaponId":member.weapon,"weaponLabel":record.weapon.get("name",member.weapon) if record.weapon is Dictionary else ("Пистолет" if member.weapon == "pistol" else member.weapon),"weaponOrigin":"player" if record.weapon is Dictionary else "personal","order":member.get("_mercenaryOrder","follow"),"rallyPosition":member.get("_mercenaryRally"),"phase":action.phase if action is Dictionary else record.status,"progress":action.get("progress") if action is Dictionary else null,"canUpgrade":record.skillPoints>0},true)
		var skills: Array = []
		for skill in record.skills: skills.append({"id":skill,"label":SKILL_NAMES.get(skill,skill),"level":record.skills[skill]})
		row.skills = skills
		result.members.append(row)
	for id in _candidates:
		var candidate: Dictionary = _candidates[id]
		var resident: Dictionary = candidate.resident
		if not _present_and_eligible(resident,_call("get_residents",[],[])): continue
		var distance := _horizontal_distance(resident)
		var row := {"id":id,"name":resident.get("name",PROFESSION_NAMES[candidate.profession]),"profession":candidate.profession,"weaponId":resident.get("weapon","pistol"),"weaponLabel":"Пистолет" if resident.get("weapon","pistol") == "pistol" else resident.weapon,"distanceMeters":distance,"hp":resident.hp,"maxHp":resident.get("max_hp",resident.hp),"level":1,"canRecruit":distance<=3}
		if distance>3: row.disabledReason = "Подойдите ближе 3 м"
		result.candidates.append(row)
	return result

func upgrade(id: String, skill: String = "") -> Dictionary:
	if not _allowed() or not _members.has(id): return _fail("member_unavailable")
	var record: Dictionary = _core.get_record(id)
	var chosen := skill
	if chosen == "":
		for key in record.skills:
			if record.skills[key] < 5: chosen = key; break
	var receipt: Dictionary = _core.upgrade(id,chosen)
	if receipt.get("ok",false):
		var member: Dictionary = _members[id]
		member.max_hp = roundf(float(member._mercenaryBaseHp)*float(_core.stats(id).hpMultiplier))
		member.hp = minf(float(member.hp),float(member.max_hp))
		_changed()
	return receipt

func tick() -> void:
	if _allowed(): _core.update()

func member_row(id: String) -> Dictionary:
	return _members.get(id,{})

func get_actor(id: String) -> Node3D:
	if _disposed: return null
	var row: Dictionary = _members.get(id,{})
	if row.is_empty() and _candidates.has(id):
		var candidate: Dictionary = _candidates[id].resident
		if _present_and_eligible(candidate,_call("get_residents",[],[])): row = candidate
	var body: Node3D = row.get("body")
	return body if is_instance_valid(body) and body.is_inside_tree() else null

func presentation_actors() -> Array:
	if _disposed or _core == null: return []
	# Existing actor wrappers are reused; the UI owns projected card lifecycle.
	var result: Array = []
	var seen: Dictionary = {}
	for actor in _call("get_residents",[],[]) + _call("get_gang",[],_members.values()):
		if not actor is Dictionary or not actor.has("id"): continue
		var body: Node3D = actor.get("body")
		if not is_instance_valid(body) or not body.is_inside_tree(): continue
		var id := str(actor.id)
		if seen.has(id): continue
		seen[id] = true
		var wrapper: Dictionary = _presentation_cache.get(id,{"id":id,"name":"","object":null,"source":{}})
		var source: Dictionary = wrapper.source
		source.clear()
		source.merge(actor,true)
		source.erase("body")
		source.erase("mercenary")
		source.erase("mercenaryCandidate")
		if _members.has(id):
			var record: Variant = _core.get_record(id)
			if record is Dictionary:
				source.mercenary = {"profession":record.profession,"level":record.level,"status":record.status}
				source.downed = float(actor.get("hp",0)) <= 0 and actor.get("deathConfirmed") != true and actor.get("dead") != true
				if source.downed: source.dead = false
		elif _candidates.has(id) and _eligible(actor):
			source.mercenaryCandidate = true
			source.mercenary = {"profession":_candidates[id].profession}
		wrapper.name = str(actor.get("name",""))
		wrapper.object = body
		_presentation_cache[id] = wrapper
		result.append(wrapper)
	for id in _presentation_cache.keys():
		if not seen.has(id): _presentation_cache.erase(id)
	return result

func candidate_rows() -> Array:
	adopt_candidates()
	var result: Array = []
	for id in _candidates:
		var candidate: Dictionary = _candidates[id]
		if not _present_and_eligible(candidate.resident,_call("get_residents",[],[])): continue
		result.append({"id":id,"profession":candidate.profession,"distanceMeters":_horizontal_distance(candidate.resident)})
	return result

func dispose() -> void:
	if _disposed: return
	for id: String in _conversations.keys(): end_conversation(id)
	_conversations.clear()
	_disposed = true
	_core = null
	_options.clear()
	_candidates.clear()
	_members.clear()
	_originals.clear()
	_inventory_seen.clear()
	_inventory_object_seen.clear()
	_presentation_cache.clear()
