extends RefCounted
## Local /walk inventory only; authenticated ownership/save/receipts stay in host.
## Fire port must be the reviewed source port, with ids/create_state/profile API.
const DROP_LIFETIME_MS := 300000.0
const SAFE_INTEGER := 9007199254740991.0
const OMITTED := &"weapon_inventory_argument_omitted"
var _fire: RefCounted
var _ids: Array = []
var _magazine_sizes: Dictionary = {}
var _owned: Dictionary = {}
var _drops: Dictionary = {}
var _clock: Callable
var _max_drops: float = INF
var _equipped := "none"
var _serial := 0
var _ready := false
var _busy := false
var _disposed := false
## User-requested cargo extension. Item identity is separate from source ground
## drop.uid; original snapshots and original drop serial semantics are unchanged.
class CargoTicket extends RefCounted:
	pass
var _owned_uids: Dictionary = {}
var _drop_uids: Dictionary = {}
var _item_serial := 0
var _cargo_ticket: CargoTicket
var _cargo_pending: Dictionary = {}
var _destroy_receipts: Dictionary = {}

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func _integer(value: Variant, maximum: float) -> bool:
	return _finite(value) and value >= 0 and value <= maximum and floor(float(value)) == float(value)
static func _stowed(state: Dictionary) -> Dictionary:
	var copy := state.duplicate(true)
	copy.reloadRemaining = 0; copy.recoil = 0; copy.triggerHeld = false
	return copy
static func _position(value: Variant) -> bool:
	return value is Dictionary and _finite(value.get("x")) and _finite(value.get("y")) and _finite(value.get("z"))
static func _omitted(value: Variant) -> bool:
	return value is StringName and value == OMITTED
static func _failure(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}
func _available() -> bool:
	return _readable() and _cargo_ticket == null
func _readable() -> bool:
	return Thread.is_main_thread() and _ready and not _busy and not _disposed
func _valid_state(state: Variant, id: String) -> bool:
	if not state is Dictionary or not state.get("weaponId") is String or state.weaponId != id or not _ids.has(id): return false
	if not _integer(state.get("magazine"),float(_magazine_sizes[id])) or not _integer(state.get("reserveAmmo"),9999) or not _integer(state.get("sequence"),SAFE_INTEGER): return false
	for key: String in ["cooldown","reloadRemaining","recoil"]:
		if not _finite(state.get(key)) or state[key] < 0: return false
	return state.get("triggerHeld") is bool

func configure(fire_port: RefCounted, options: Dictionary = {}) -> Dictionary:
	if not Thread.is_main_thread() or _ready or _busy or _disposed: return _failure("lifetime")
	if fire_port == null or not fire_port.has_method("ids") or not fire_port.has_method("create_state") or not fire_port.has_method("profile"): return _failure("fire_port")
	_fire = fire_port; _ids = _fire.ids().duplicate()
	# Profiles are immutable source data. Do not deep-copy nested projectile and
	# handling metadata for every host fire-state update.
	_magazine_sizes.clear()
	for id: Variant in _ids:
		if not id is String or _magazine_sizes.has(id): return _failure("fire_port")
		var profile: Variant=_fire.profile(id)
		if not profile is Dictionary or not _integer(profile.get("magazineSize"),SAFE_INTEGER): return _failure("fire_port")
		_magazine_sizes[id]=profile.magazineSize
	var ids: Variant = options.get("ownedIds",_ids)
	var states: Variant = options.get("fireStates",{})
	var drops: Variant = options.get("dropped",[])
	var capacity: Variant = options.get("maxDrops",INF)
	var clock: Variant = options.get("now",Callable(self,"_default_now"))
	if not ids is Array or not states is Dictionary or not drops is Array or not clock is Callable or not clock.is_valid() or clock.get_argument_count()!=0: return _failure("configuration")
	if not ((capacity is float and capacity==INF) or _integer(capacity,SAFE_INTEGER)) or drops.size()>capacity: return _failure("drop_capacity")
	var owned := {}; var staged_drops := {}
	for id: Variant in ids:
		if not id is String or not _ids.has(id) or owned.has(id): return _failure("owned_ids")
		var state: Variant = states.get(id)
		if state == null: state = _fire.create_state(id)
		if not _valid_state(state,id): return _failure("initial_fire_state")
		owned[id] = _stowed(state)
	_busy=true
	for value: Variant in drops:
		if not value is Dictionary or not value.get("uid") is String or value.uid.is_empty() or staged_drops.has(value.uid) or not value.get("weaponId") is String or not _ids.has(value.weaponId) or not _position(value.get("position")) or not _finite(value.get("yaw")) or not _valid_state(value.get("fireState"),value.weaponId):
			_busy=false; return _failure("initial_drop")
		var at: Variant = value.droppedAt if value.has("droppedAt") else clock.call()
		if _disposed or not _finite(at) or at<0 or not is_finite(float(at)+DROP_LIFETIME_MS) or (value.has("expiresAt") and value.expiresAt!=float(at)+DROP_LIFETIME_MS):
			_busy=false; return _failure("initial_drop_time")
		var drop: Dictionary = value.duplicate(true)
		drop.droppedAt=at; drop.expiresAt=float(at)+DROP_LIFETIME_MS; drop.fireState=_stowed(value.fireState)
		staged_drops[drop.uid]=drop
	_busy=false; _owned=owned; _drops=staged_drops; _clock=clock; _max_drops=float(capacity); _ready=true
	for id: String in _owned: _owned_uids[id]=_new_item_uid()
	for uid: String in _drops: _drop_uids[uid]=_new_item_uid()
	return {"ok":true,"scope":"local_walk_inventory","authenticated_ownership":false}

func _default_now() -> float: return Time.get_ticks_usec()/1000.0
func get_owned_ids() -> Array:
	var result: Array = []
	if not _readable(): return result
	for id: String in _ids:
		if _owned.has(id): result.append(id)
	return result
func get_dropped() -> Array:
	return _drops.values().duplicate(true) if _readable() else []
func get_fire_state(id: Variant = OMITTED) -> Variant:
	if not _readable(): return null
	if _omitted(id): id=_equipped
	if not id is String: return null
	if id == "none": return _fire.create_state("none")
	return _owned[id].duplicate(true) if _owned.has(id) else null
func snapshot() -> Dictionary:
	if not _readable(): return {}
	return {"equippedId":_equipped,"ownedIds":get_owned_ids(),"fireStates":_owned.duplicate(true),"dropped":get_dropped()}
func _result(ok: bool, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok":ok,"equippedId":_equipped,"fireState":get_fire_state()}
	result.merge(extra,true)
	return result
func _current(state: Variant) -> bool:
	if _omitted(state): return true
	if _equipped=="none": return state is Dictionary and state.get("weaponId") is String and state.weaponId=="none"
	return _valid_state(state,_equipped)
func _store(state: Variant, stow: bool = true) -> void:
	if _equipped=="none": return
	var value: Dictionary = _owned[_equipped] if _omitted(state) else state
	_owned[_equipped]=_stowed(value) if stow else value.duplicate(true)
func update_fire_state(state: Variant) -> Dictionary:
	if not _available(): return _failure("lifetime")
	if _omitted(state) or not _current(state): return _result(false,{"reason":"invalid_fire_state"})
	_store(state,false)
	return _result(true)
func equip(id: Variant, current_state: Variant = OMITTED) -> Dictionary:
	if not _available(): return _failure("lifetime")
	if not id is String: return _result(false,{"reason":"not_owned"})
	if id!="none" and not _owned.has(id): return _result(false,{"reason":"not_owned"})
	if not _current(current_state): return _result(false,{"reason":"invalid_fire_state"})
	_store(current_state,id!=_equipped)
	if id!=_equipped and id!="none": _owned[id]=_stowed(_owned[id])
	_equipped=id
	return _result(true)
func _time(explicit_time: Variant = OMITTED) -> Variant:
	_busy=true
	var value: Variant = _clock.call() if _omitted(explicit_time) else explicit_time
	_busy=false
	return value if not _disposed and _finite(value) and value>=0 else null
func expire_drops(at_ms: Variant = OMITTED) -> Dictionary:
	if not _available(): return _failure("lifetime")
	var at: Variant = _time(at_ms)
	if at==null: return _failure("clock")
	var removed: Array = []
	for uid: String in _drops.keys():
		if at>=_drops[uid].expiresAt: removed.append(_drops[uid].duplicate(true)); _drops.erase(uid); _drop_uids.erase(uid)
	return {"ok":true,"expired":removed}
func drop(options: Dictionary = {}) -> Dictionary:
	if not _available(): return _failure("lifetime")
	if _equipped=="none": return _result(false,{"reason":"unarmed"})
	var position: Variant = options.get("position"); var yaw: Variant = options.get("yaw",0)
	if not _position(position) or not _finite(yaw): return _result(false,{"reason":"invalid_transform"})
	var state: Variant = options.get("fireState",OMITTED)
	if not _current(state): return _result(false,{"reason":"invalid_fire_state"})
	if _drops.size()>=_max_drops: return _result(false,{"reason":"drop_limit"})
	# Freeze caller data before invoking its real clock; reentry cannot replace
	# the already validated position or ammo between admission and commit.
	var dropped_position: Dictionary={"x":position.x,"y":position.y,"z":position.z}
	var dropped_state:=_stowed(_owned[_equipped] if _omitted(state) else state)
	var at: Variant = _time()
	if at==null: return _failure("clock")
	var uid := ""
	while uid.is_empty() or _drops.has(uid): _serial+=1; uid="weapon-drop-"+str(_serial)
	var value := {"uid":uid,"weaponId":_equipped,"position":dropped_position,"yaw":yaw,"droppedAt":at,"expiresAt":float(at)+DROP_LIFETIME_MS,"fireState":dropped_state}
	_drops[uid]=value; _drop_uids[uid]=_owned_uids[_equipped]; _owned_uids.erase(_equipped); _owned.erase(_equipped); _equipped="none"
	return _result(true,{"drop":value.duplicate(true)})
func pickup(uid: Variant, current_state: Variant = OMITTED) -> Dictionary:
	if not _available(): return _failure("lifetime")
	if not _drops.has(uid): return _result(false,{"reason":"missing_drop"})
	var value: Dictionary = _drops[uid]
	var at: Variant = _time()
	if at==null: return _failure("clock")
	if at>=value.expiresAt:
		_drops.erase(uid); _drop_uids.erase(uid)
		return _result(false,{"reason":"expired_drop","expired":[value.duplicate(true)]})
	if _owned.has(value.weaponId): return _result(false,{"reason":"already_owned"})
	if not _current(current_state): return _result(false,{"reason":"invalid_fire_state"})
	_store(current_state,false); _owned[value.weaponId]=_stowed(value.fireState); _owned_uids[value.weaponId]=_drop_uids[uid]; _drop_uids.erase(uid); _drops.erase(uid)
	return _result(true,{"drop":value.duplicate(true)})

func _new_item_uid() -> String:
	_item_serial+=1
	return "local-weapon-item-"+str(get_instance_id())+"-"+str(_item_serial)
func _has_item_uid(uid: String) -> bool:
	return _owned_uids.values().has(uid) or _drop_uids.values().has(uid)
func _valid_item(item: Variant) -> bool:
	return item is Dictionary and item.get("uid") is String and not item.uid.is_empty() and item.get("weaponId") is String and _valid_state(item.get("fireState"),item.weaponId)
func get_item_uid(id: Variant = OMITTED) -> Variant:
	if not _readable(): return null
	if _omitted(id): id=_equipped
	return _owned_uids.get(id) if id is String else null
func get_drop_item(uid: Variant) -> Variant:
	if not _readable() or not uid is String or not _drops.has(uid): return null
	var value: Dictionary=_drops[uid]
	return {"uid":_drop_uids[uid],"weaponId":value.weaponId,"fireState":value.fireState.duplicate(true)}
func item_identity_snapshot() -> Dictionary:
	return {"owned":_owned_uids.duplicate(),"dropped":_drop_uids.duplicate()} if _readable() else {}
func _reserve(value: Dictionary) -> CargoTicket:
	_cargo_ticket=CargoTicket.new();_cargo_pending=value
	return _cargo_ticket
func _ticket_matches(token: Variant, kind: String = "") -> bool:
	return Thread.is_main_thread() and _ready and not _busy and not _disposed and _cargo_ticket != null and token is CargoTicket and token == _cargo_ticket and (kind.is_empty() or _cargo_pending.get("kind")==kind)
func _release_reservation() -> void:
	_cargo_ticket=null;_cargo_pending={}
func cargo_transfer_pending() -> bool:
	return _cargo_ticket != null
func validate_cargo_transfer(token: Variant, kind: String) -> bool:
	return (kind=="export" or kind=="import" or kind=="ground") and _ticket_matches(token,kind)

## Begin does not relinquish ownership. Root must reserve the other side and
## cancel on any failure. Both commits then run synchronously without awaits or
## external callbacks. An opaque ticket cannot be replayed or used on another
## inventory. No network authority is inferred from a local reservation.
func begin_cargo_export(current_state: Variant = OMITTED) -> Dictionary:
	if not _available(): return _failure("lifetime")
	if _equipped=="none": return _failure("unarmed")
	if not _current(current_state): return _failure("invalid_fire_state")
	var item: Dictionary={"uid":_owned_uids[_equipped],"weaponId":_equipped,"fireState":_stowed(_owned[_equipped] if _omitted(current_state) else current_state)}
	var response: Dictionary={"ok":true,"equippedId":"none","fireState":_fire.create_state("none"),"item":item.duplicate(true)}
	var ticket:=_reserve({"kind":"export","id":_equipped,"item":item,"response":response})
	return {"ok":true,"token":ticket,"item":item.duplicate(true)}
func commit_cargo_export(token: Variant) -> Dictionary:
	if not _ticket_matches(token,"export"): return _failure("reservation")
	var pending:=_cargo_pending
	_owned.erase(pending.id);_owned_uids.erase(pending.id);_equipped="none"
	_release_reservation()
	return pending.response.duplicate(true)
func begin_cargo_import(item: Variant, current_state: Variant = OMITTED) -> Dictionary:
	if not _available(): return _failure("lifetime")
	if not _valid_item(item): return _failure("invalid_item")
	if _has_item_uid(item.uid): return _failure("duplicate_item_uid")
	if _owned.has(item.weaponId): return _failure("already_owned")
	if not _current(current_state): return _failure("invalid_fire_state")
	var held: Dictionary=get_fire_state() if _equipped=="none" or _omitted(current_state) else current_state.duplicate(true)
	var accepted: Dictionary={"uid":item.uid,"weaponId":item.weaponId,"fireState":_stowed(item.fireState)}
	var response: Dictionary={"ok":true,"equippedId":_equipped,"fireState":held.duplicate(true),"item":accepted.duplicate(true)}
	var ticket:=_reserve({"kind":"import","item":accepted,"held":held,"response":response})
	return {"ok":true,"token":ticket,"item":accepted.duplicate(true)}
func commit_cargo_import(token: Variant) -> Dictionary:
	if not _ticket_matches(token,"import"): return _failure("reservation")
	var pending:=_cargo_pending
	_store(pending.held,false)
	_owned[pending.item.weaponId]=pending.item.fireState;_owned_uids[pending.item.weaponId]=pending.item.uid
	_release_reservation()
	return pending.response.duplicate(true)
func cancel_cargo_transfer(token: Variant) -> Dictionary:
	if not _ticket_matches(token): return _failure("reservation")
	_release_reservation()
	return {"ok":true}

## An explicitly identified cargo destruction may release an entire batch to
## ground, never evicting existing drops. Root supplies a real transform and
## consumes cargo only after this complete admission succeeds. Receipt strings
## are local idempotency keys, not server proofs.
func begin_cargo_ground_import(items: Variant, position: Variant, yaw: Variant, destroy_receipt: Variant) -> Dictionary:
	if not items is Array: return _failure("invalid_items")
	var placements: Array=[]
	for _item: Variant in items: placements.append({"position":position,"yaw":yaw})
	return begin_cargo_ground_import_at_positions(items,placements,destroy_receipt)
func begin_cargo_ground_import_at_positions(items: Variant, placements: Variant, destroy_receipt: Variant) -> Dictionary:
	if not _available(): return _failure("lifetime")
	if not items is Array or items.is_empty(): return _failure("invalid_items")
	if not placements is Array or placements.size()!=items.size(): return _failure("invalid_transform")
	if not destroy_receipt is String or destroy_receipt.is_empty(): return _failure("invalid_destroy_receipt")
	if _destroy_receipts.has(destroy_receipt): return _failure("duplicate_destroy_receipt")
	if _drops.size()+items.size()>_max_drops: return _failure("drop_limit")
	var staged: Array=[];var unique: Dictionary={}
	for index in items.size():
		var item: Variant=items[index]
		var placement: Variant=placements[index]
		if not placement is Dictionary or not _position(placement.get("position")) or not _finite(placement.get("yaw")): return _failure("invalid_transform")
		if not _valid_item(item): return _failure("invalid_item")
		if unique.has(item.uid) or _has_item_uid(item.uid): return _failure("duplicate_item_uid")
		unique[item.uid]=true
		staged.append({"uid":item.uid,"weaponId":item.weaponId,"fireState":_stowed(item.fireState),"position":{"x":placement.position.x,"y":placement.position.y,"z":placement.position.z},"yaw":placement.yaw})
	var at: Variant=_time()
	if at==null or not is_finite(float(at)+DROP_LIFETIME_MS): return _failure("clock")
	var ticket:=_reserve({"kind":"ground","items":staged,"at":at,"receipt":destroy_receipt})
	return {"ok":true,"token":ticket,"count":staged.size()}
func commit_cargo_ground_import(token: Variant) -> Dictionary:
	if not _ticket_matches(token,"ground"): return _failure("reservation")
	var pending:=_cargo_pending
	var released: Array=[]
	for item: Dictionary in pending.items:
		var uid:=""
		while uid.is_empty() or _drops.has(uid): _serial+=1;uid="weapon-drop-"+str(_serial)
		var value: Dictionary={"uid":uid,"weaponId":item.weaponId,"position":item.position,"yaw":item.yaw,"droppedAt":pending.at,"expiresAt":float(pending.at)+DROP_LIFETIME_MS,"fireState":item.fireState}
		_drops[uid]=value;_drop_uids[uid]=item.uid;released.append(value.duplicate(true))
	_destroy_receipts[pending.receipt]=true
	_release_reservation()
	return {"ok":true,"dropped":released,"destroyReceipt":pending.receipt}
func dispose() -> void:
	if not Thread.is_main_thread(): return
	_release_reservation()
	_disposed=true; _ready=false; _owned.clear(); _drops.clear(); _owned_uids.clear(); _drop_uids.clear(); _destroy_receipts.clear(); _magazine_sizes.clear(); _clock=Callable(); _fire=null
