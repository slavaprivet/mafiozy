extends RefCounted
## Source-native RPG flight only. No ammo mutation, HP, server claim, or visuals.
## ROOT supplies current muzzle/owner and real closest-contact resolver.
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const SCALE := 4.1
const MAX_SLOTS := 112
const MAX_ITEMS := 512
const MAX_AGE_USEC := 15000000
const EPS := 0.0001
const MUZZLE_KEYS := ["weapon_id","actor_id","life_generation","pose_epoch","pose_revision","equip_generation","sample_serial","origin","direction","ejection_origin"]
var _binding: Dictionary = {}
var _live_port: Callable
var _muzzle_port: Callable
var _query_port: Callable
var _impact_port: Callable
var _clock: Callable
var _slots: Array[Dictionary] = []
var _free: Array[int] = []
var _last_sequence: Dictionary = {}
var _ready := false
var _disposed := false
var _busy := false
var _active := 0
var _serial := 0
var _last_time := -1
var _stats := {"launches":0,"impacts":0,"queries":0,"retired":0}
var _profile: Dictionary = {}
class LaunchTicket extends RefCounted:
	pass
var _ticket: LaunchTicket
var _prepared: Dictionary = {}

static func _finite(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))
static func _whole(v: Variant) -> bool:
	return _finite(v) and v >= 0 and v <= 9007199254740991.0 and floor(float(v)) == float(v)
static func _vector(v: Variant) -> bool: return v is Vector3 and v.is_finite()
static func _bad(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _time_default() -> int: return Time.get_ticks_usec()

func configure(binding: Dictionary, live_port: Callable, muzzle_port: Callable, query_port: Callable, impact_port: Callable, options: Dictionary = {}) -> Dictionary:
	if not Thread.is_main_thread() or _ready or _disposed or _busy: return _bad("state")
	if not binding.get("actor_id") is String or binding.actor_id.is_empty() or not binding.get("life_generation") is int or binding.life_generation < 1 or not binding.get("scene_token") is String or binding.scene_token.is_empty(): return _bad("binding")
	for item: Array in [[live_port,0],[muzzle_port,0],[query_port,1],[impact_port,1]]:
		if not item[0].is_valid() or item[0].get_argument_count() != item[1]: return _bad("ports")
	var cap: Variant = options.get("capacity",MAX_SLOTS)
	if not cap is int or cap < 1 or cap > MAX_SLOTS: return _bad("capacity")
	var clock_port: Variant = options.get("clock",Callable(self,"_time_default"))
	if not clock_port is Callable or not clock_port.is_valid() or clock_port.get_argument_count() != 0: return _bad("clock")
	_clock = clock_port
	_profile = Fire.profile("rpg")
	if _profile.get("projectileSpeed") != 17 or _profile.get("range") != 15 or _profile.get("damage") != 160 or _profile.get("explosive") != true: return _bad("source_profile")
	_binding = binding.duplicate(true); _live_port = live_port; _muzzle_port = muzzle_port; _query_port = query_port; _impact_port = impact_port
	for i: int in cap: _slots.append({}); _free.append(cap-1-i)
	_ready = true
	return {"ok":true,"capacity":cap,"scope":"flight_and_impact_only"}

func _owner_valid(required_item: String = "") -> bool:
	if _disposed or not _ready or not _live_port.is_valid(): return false
	var value: Variant = _live_port.call()
	if _disposed or not value is Dictionary or value.get("active") != true: return false
	for key: String in ["actor_id","life_generation","scene_token"]:
		if value.get(key) != _binding[key]: return false
	if not required_item.is_empty() and value.get("equipped_item_uid") != required_item: return false
	return true
func _now() -> int:
	if _disposed or not _clock.is_valid(): return -1
	var value: Variant = _clock.call()
	if _disposed or not _whole(value) or int(value) < _last_time: return -1
	_last_time = int(value)
	return _last_time
func _current_muzzle(receipt: Dictionary) -> bool:
	if receipt.get("ok") != true or receipt.get("weapon_id") != "rpg" or receipt.get("actor_id") != _binding.actor_id or receipt.get("life_generation") != _binding.life_generation: return false
	for key: String in ["origin","direction","ejection_origin"]:
		if not _vector(receipt.get(key)): return false
	for key: String in ["pose_epoch","pose_revision","equip_generation","sample_serial"]:
		if not receipt.get(key) is int or receipt[key] < 0: return false
	if absf(receipt.direction.length_squared()-1.0) > 0.0001 or not _muzzle_port.is_valid(): return false
	var current: Variant = _muzzle_port.call()
	if _disposed or not current is Dictionary or current.get("ok") != true: return false
	for key: String in MUZZLE_KEYS:
		if current.get(key) != receipt.get(key): return false
	return true
func _free_slot() -> int:
	return -1 if _free.is_empty() else _free[-1]

## Origin is frozen from the latest presentation receipt. Direction is the
## host's admitted source aim, which may differ from visual recoil direction.
func launch(shot: Dictionary, muzzle: Dictionary, item_uid: String, direction: Vector3) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not _ready or _ticket != null: return _bad("state")
	_busy = true
	var answer := _launch(shot.duplicate(true),muzzle.duplicate(true),item_uid,direction)
	if answer.get("ok",false): answer = _commit_launch(answer.ticket)
	_busy = false
	return answer

## Two-phase root seam: preflight callbacks happen before ammo commit. The
## actual inventory commit and commit_launch must be consecutive synchronous
## operations with no intervening external callback/await. No authority granted.
func prepare_launch(shot: Dictionary, muzzle: Dictionary, item_uid: String, direction: Vector3) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not _ready or _ticket != null: return _bad("state")
	_busy = true
	var answer := _launch(shot.duplicate(true),muzzle.duplicate(true),item_uid,direction)
	_busy = false
	return answer
func commit_launch(ticket: RefCounted) -> Dictionary:
	if not Thread.is_main_thread() or _busy: return _bad("state")
	return _commit_launch(ticket)
func cancel_launch(ticket: RefCounted) -> bool:
	if not Thread.is_main_thread() or _busy or ticket == null or ticket != _ticket: return false
	_ticket = null; _prepared = {}; return true
func _commit_launch(ticket: RefCounted) -> Dictionary:
	if not _ready or _disposed or ticket == null or ticket != _ticket: return _bad("ticket")
	var slot: int = _prepared.slot
	var row: Dictionary = _prepared.row
	_free.pop_back(); _slots[slot] = row
	_last_sequence[row.item_uid] = float(row.sequence); _active += 1; _stats.launches += 1
	_ticket = null; _prepared = {}
	return {"ok":true,"token":row.token,"slot":slot,"position":row.position,"direction":row.direction,"range_world":float(_profile.range)*SCALE,"speed_world":float(_profile.projectileSpeed)*SCALE,"visual":_profile.projectileVisual.duplicate(true)}
func _launch(shot: Dictionary, muzzle: Dictionary, item_uid: String, direction: Vector3) -> Dictionary:
	if not _owner_valid(): return _bad("owner")
	if item_uid.is_empty() or item_uid.length() > 192 or not _whole(shot.get("sequence")) or shot.sequence < 1 or shot.get("weaponId") != "rpg" or shot.get("shotId") != "rpg:"+str(int(shot.sequence)): return _bad("shot_identity")
	if float(shot.sequence) <= float(_last_sequence.get(item_uid,0)): return _bad("duplicate_or_old")
	if not _last_sequence.has(item_uid) and _last_sequence.size() >= MAX_ITEMS: return _bad("item_capacity")
	if not direction.is_finite() or absf(direction.length_squared()-1.0) > 0.0001: return _bad("direction")
	if not shot.get("projectiles") is Array or shot.projectiles.size() != 1: return _bad("source_projectile")
	var projectile: Variant = shot.projectiles[0]
	if not projectile is Dictionary or projectile.get("explosive") != true or projectile.get("speed") != _profile.projectileSpeed or projectile.get("range") != _profile.range or projectile.get("visualId") != "rpg" or shot.get("damage") != _profile.damage: return _bad("source_projectile")
	var slot := _free_slot()
	if slot < 0: return _bad("pool_full")
	if not _current_muzzle(muzzle): return _bad("stale_muzzle")
	var now := _now()
	if now < 0 or not _owner_valid(item_uid): return _bad("lifetime_or_item")
	# Recheck after all external callbacks; no callbacks between admission and
	# publishing the immutable launch data. Disposed callbacks cannot revive it.
	if _disposed: return _bad("disposed")
	_serial += 1
	var row := {"token":_serial,"shot_id":shot.shotId,"sequence":int(shot.sequence),"item_uid":item_uid,"origin":muzzle.origin,"position":muzzle.origin,"direction":direction,"travelled":0.0,"born_usec":now,"muzzle":muzzle}
	_ticket = LaunchTicket.new(); _prepared = {"row":row,"slot":slot}
	return {"ok":true,"ticket":_ticket,"slot":slot,"position":muzzle.origin,"direction":direction}

func advance(delta: float) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not _ready or _ticket != null: return _bad("state")
	if not is_finite(delta) or delta < 0: return _bad("delta")
	_busy = true
	var answer := _advance(delta)
	_busy = false
	return answer
func _advance(delta: float) -> Dictionary:
	if not _owner_valid(): _retire_all(); return _bad("owner")
	var now := _now()
	if now < 0: _retire_all(); return _bad("clock")
	var events: Array[Dictionary] = []
	for i: int in _slots.size():
		if _disposed: return _bad("disposed")
		if _slots[i].is_empty(): continue
		var row: Dictionary = _slots[i]
		if now-row.born_usec > MAX_AGE_USEC: _retire(i); continue
		var remaining: float = float(_profile.range)*SCALE-float(row.travelled)
		# Full finite elapsed delta, source nativeRpgImpact has no .1/5s cap.
		var distance: float = minf(remaining,float(_profile.projectileSpeed)*SCALE*delta)
		if distance <= 0: continue
		var request := {"origin":row.position,"direction":row.direction,"range":distance,"token":row.token,"item_uid":row.item_uid,"shot_id":row.shot_id}
		_stats.queries += 1
		if not _query_port.is_valid(): _retire_all(); return _bad("query_provider")
		# Fresh packet contains value types only, so no shared mutable row escapes.
		var raw: Variant = _query_port.call(request)
		# Callback may dispose the component or invalidate actor/scene lifetime.
		if _disposed: return _bad("disposed")
		if not raw is Dictionary or not raw.get("hit") is bool: _retire(i); return _bad("query_result")
		var hit: Dictionary = raw.duplicate(true)
		if not _owner_valid(): _retire_all(); return _bad("owner")
		var at := _now()
		if at < 0: _retire_all(); return _bad("clock")
		if at-row.born_usec > MAX_AGE_USEC: _retire(i); continue
		if hit.hit and not _valid_hit(hit,row,distance): _retire(i); return _bad("query_result")
		var point: Vector3 = hit.point if hit.hit else row.position+row.direction*distance
		row.position = point
		row.travelled = float(row.travelled)+(float(hit.distance) if hit.hit else distance)
		var range_end: bool = not hit.hit and float(_profile.range)*SCALE-float(row.travelled) <= 0.00001
		if not hit.hit and not range_end: continue
		var receipt := {"token":row.token,"shot_id":row.shot_id,"item_uid":row.item_uid,"sequence":row.sequence,"actor_id":_binding.actor_id,"life_generation":_binding.life_generation,"scene_token":_binding.scene_token,"origin":row.origin,"point":point,"direction":row.direction,"normal":hit.normal.normalized() if hit.hit else -row.direction,"distance_world":row.travelled,"range_end":range_end,"hit":hit,"damage":_profile.damage,"source_radius_cells":2.7,"explosive":true,"native_rpg_impact":true,"authority":"EXTERNAL_OWNER_REQUIRED"}
		_retire(i); _stats.impacts += 1
		# Retire BEFORE any consumer runs. Recursive advance/launch are rejected;
		# dispose is immediate. Consumers cannot replay a consumed projectile.
		events.append(receipt.duplicate(true))
		if not _impact_port.is_valid(): return {"ok":false,"reason":"impact_provider","impacts":events}
		_impact_port.call(receipt)
		if _disposed: return {"ok":false,"reason":"disposed","impacts":events}
		if not _owner_valid(): _retire_all(); return {"ok":false,"reason":"owner","impacts":events}
	return {"ok":true,"impacts":events,"active":_active}

func _valid_hit(hit: Dictionary, row: Dictionary, limit: float) -> bool:
	if not _vector(hit.get("point")) or not _vector(hit.get("normal")) or not _finite(hit.get("distance")): return false
	if hit.distance < 0 or hit.distance > limit+EPS or hit.normal.length_squared() < 0.000001: return false
	return hit.point.distance_to(row.position+row.direction*float(hit.distance)) <= EPS
func _retire(i: int) -> void:
	if _slots[i].is_empty(): return
	_slots[i] = {}; _free.append(i); _active -= 1; _stats.retired += 1
## Trusted shared-render-pool eviction; no query, impact, owner callback or HP.
## Exact tokens prevent a reused slot from retiring a later projectile.
func retire_token(token: int) -> bool:
	if not Thread.is_main_thread() or token<=0: return false
	for i: int in _slots.size():
		if not _slots[i].is_empty() and _slots[i].token==token: _retire(i); return true
	return false
func _retire_all() -> void:
	for i: int in _slots.size(): _retire(i)
func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	for row: Dictionary in _slots:
		if not row.is_empty(): rows.append(row.duplicate(true))
	return {"configured":_ready,"disposed":_disposed,"active":_active,"capacity":_slots.size(),"reserved":_ticket!=null,"seen_items":_last_sequence.size(),"rows":rows,"stats":_stats.duplicate()}
func dispose() -> void:
	if not Thread.is_main_thread(): return
	_disposed = true; _ready = false; _retire_all()
	_ticket = null; _prepared = {}
	_live_port = Callable(); _muzzle_port = Callable(); _query_port = Callable(); _impact_port = Callable(); _clock = Callable()
