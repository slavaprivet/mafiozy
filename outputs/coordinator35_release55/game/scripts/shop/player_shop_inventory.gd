extends RefCounted
## Local preview backpack and the only armor owner.
## Money and prices stay in the shop, the guns stay in the weapon inventory. A
## worn vest is the source rule of the 3D version: incoming damage meets the vest
## first, the vest loses exactly what it took, and a vest whose points ran out is
## marked broken instead of silently absorbing forever. Consumables (grenades,
## molotov, C4, medkits) are plain counts with the catalog's carry limit.
const MAX_COUNT := 99
const KIND_ARMOR := "armor"
const KIND_CONSUMABLE := "consumable"
var _ready := false
var _error := ""
var _catalog: RefCounted
var _counts: Dictionary = {}
var _armor: Dictionary = {}
var _worn := ""
var _absorbed_total := 0
var _hits := 0
var _broken_total := 0
var _purchases := 0

func configure(catalog: RefCounted) -> Dictionary:
	if _ready:
		return {"ok": false, "reason": "already_configured"}
	if catalog == null or not catalog.ready():
		return _fail("catalog")
	_catalog = catalog
	_ready = true
	return {"ok": true, "scope": "local_preview_backpack", "armor_kinds": catalog.items_of(KIND_ARMOR).size()}

func ready() -> bool:
	return _ready

func error() -> String:
	return _error

## ── consumables ──────────────────────────────────────────────────────────
func count(id: String) -> int:
	return int(_counts.get(id, 0))

func has(id: String) -> bool:
	return count(id) > 0

func limit(id: String) -> int:
	return _catalog.limit(id) if _ready else 0

func add(id: String, qty: int = 1) -> Dictionary:
	if not _ready:
		return _fail("lifetime")
	if _catalog.kind(id) != KIND_CONSUMABLE:
		return {"ok": false, "reason": "not_consumable"}
	if qty <= 0 or qty > MAX_COUNT:
		return {"ok": false, "reason": "quantity"}
	var limit: int = _catalog.limit(id)
	var now := count(id)
	if now + qty > limit:
		return {"ok": false, "reason": "limit_reached", "count": now, "limit": limit}
	_counts[id] = now + qty
	_purchases += 1
	return {"ok": true, "id": id, "count": now + qty, "limit": limit}

func take(id: String, qty: int = 1) -> Dictionary:
	if not _ready:
		return _fail("lifetime")
	if qty <= 0 or qty > MAX_COUNT:
		return {"ok": false, "reason": "quantity"}
	var now := count(id)
	if now < qty:
		return {"ok": false, "reason": "not_enough", "count": now}
	_counts[id] = now - qty
	return {"ok": true, "id": id, "count": now - qty}

## ── armor ────────────────────────────────────────────────────────────────
func armor_owned(id: String) -> bool:
	return _armor.has(id) and int((_armor[id] as Dictionary).get("qty", 0)) > 0

func armor_ids() -> Array:
	return _armor.keys()

func armor_state(id: String) -> Dictionary:
	return (_armor.get(id, {}) as Dictionary).duplicate(true)

## The player may own one intact vest total. A broken vest can be replaced.
func grant_armor(id: String) -> Dictionary:
	if not _ready:
		return _fail("lifetime")
	if _catalog.kind(id) != KIND_ARMOR:
		return {"ok": false, "reason": "not_armor"}
	var protection: int = _catalog.defense(id)
	if protection <= 0:
		return {"ok": false, "reason": "armor_points"}
	for owned_id: String in _armor:
		var owned: Dictionary = _armor[owned_id]
		if int(owned.get("qty", 0)) > 0 and not bool(owned.get("broken", false)):
			return {"ok": false, "reason": "already_owned", "owned_id": owned_id}
	var replaced := not _armor.is_empty()
	_armor.clear()
	_worn = ""
	_armor[id] = {"qty": 1, "ap": protection, "max": protection, "broken": false}
	_purchases += 1
	return {"ok": true, "id": id, "replaced": replaced, "ap": protection, "max": protection}

func worn_armor() -> String:
	return _worn

func worn_state() -> Dictionary:
	return armor_state(_worn)

func equip(id: String) -> Dictionary:
	if not _ready:
		return _fail("lifetime")
	if not armor_owned(id):
		return {"ok": false, "reason": "not_owned"}
	_worn = id
	return {"ok": true, "worn": _worn, "state": armor_state(_worn)}

func unequip() -> Dictionary:
	var previous := _worn
	_worn = ""
	return {"ok": true, "worn": "", "previous": previous}

## Damage meets the vest first. Returns exactly what the vest took, so the health
## owner subtracts only the remainder.
func absorb(amount: int) -> Dictionary:
	if not _ready or amount <= 0 or _worn.is_empty() or not _armor.has(_worn):
		return {"absorbed": 0, "remaining": maxi(amount, 0), "armor_left": 0, "broken": false, "worn": _worn}
	var state: Dictionary = _armor[_worn]
	var left := int(state.get("ap", 0))
	if left <= 0:
		return {"absorbed": 0, "remaining": amount, "armor_left": 0, "broken": true, "worn": _worn}
	var absorbed: int = mini(left, amount)
	state["ap"] = left - absorbed
	var broke := int(state["ap"]) <= 0
	state["broken"] = broke
	_armor[_worn] = state
	_absorbed_total += absorbed
	_hits += 1
	if broke:
		_broken_total += 1
	return {"absorbed": absorbed, "remaining": amount - absorbed, "armor_left": int(state["ap"]), "broken": broke, "worn": _worn}

func backpack() -> Dictionary:
	return {
		"consumables": _counts.duplicate(),
		"armor": _armor.duplicate(true),
		"worn": _worn
	}

func snapshot() -> Dictionary:
	return {
		"ready": _ready,
		"error": _error,
		"scope": "local_preview_backpack",
		"consumables": _counts.duplicate(),
		"armor": _armor.duplicate(true),
		"worn": _worn,
		"absorbed_total": _absorbed_total,
		"hits": _hits,
		"broken_total": _broken_total,
		"purchases": _purchases,
		"catalog_items": _catalog.item_count() if _catalog != null else 0
	}

func _fail(reason: String) -> Dictionary:
	_error = reason
	return {"ok": false, "reason": reason}
