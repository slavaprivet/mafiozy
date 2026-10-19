extends RefCounted
## Player shop catalog: prices, flavour text and the seller's lines are data
## (data/player_shop.json), never hardcoded authority. This module only reads and
## validates; it never moves money and never touches the arsenal or the backpack.
## Three kinds are sold: weapons (must be real ids of the reviewed fire port),
## armor (a vest worn over the clothes) and consumables (grenades, molotov, C4,
## medkits) that live in the local backpack.
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const Sizes = preload("res://scripts/weapons/weapon_cargo_sizes.gd")
const SCHEMA := "mafiozi.player-shop/v1"
const DEFAULT_PATH := "res://data/player_shop.json"
const MAX_ITEMS := 96
const MAX_BYTES := 262144
const MAX_MONEY := 100000000
const MAX_TEXT := 400
const MAX_DEFENSE := 100000
const MAX_LIMIT := 99
const DEFAULT_TITLE := "Оружейная лавка"
const KIND_WEAPON := "weapon"
const KIND_AMMO := "ammo"
const KIND_ARMOR := "armor"
const KIND_CONSUMABLE := "consumable"
const KIND_TABS := [
	{"kind": KIND_WEAPON, "label": "ОРУЖИЕ"},
	{"kind": KIND_AMMO, "label": "ПАТРОНЫ"},
	{"kind": KIND_ARMOR, "label": "БРОНЯ"},
	{"kind": KIND_CONSUMABLE, "label": "РАСХОД"}
]
const KIND_ICONS := {KIND_WEAPON: "🔫", KIND_AMMO: "🎯", KIND_ARMOR: "🦺", KIND_CONSUMABLE: "📦"}
const DEFAULT_SELLER := {
	"name": "Продавец",
	"line": "Смотри, что есть. Деньги вперёд, разговоры потом.",
	"prompt": "Поговорить",
	"goods": "Товар",
	"leave": "Уйти",
	"sold": "Готово. Ствол твой."
}
var _ready := false
var _error := ""
var _path := ""
var _title := DEFAULT_TITLE
var _cash := 0
var _seller: Dictionary = {}
var _starter: Array = []
var _items: Array = []
var _by_id: Dictionary = {}
var _labels: Dictionary = {}
var _skipped: Array = []

func ready() -> bool:
	return _ready

func error() -> String:
	return _error

func path() -> String:
	return _path

func title() -> String:
	return _title

func starting_cash() -> int:
	return _cash

func seller() -> Dictionary:
	return _seller.duplicate(true)

func warnings() -> Array:
	return _skipped.duplicate()

## Display labels for weapons stay owned by the weapon host
## (preview_weapons.LABELS); the catalog never duplicates gun names.
func attach_labels(labels: Dictionary) -> void:
	_labels = labels.duplicate(true)

## Gun names are resolved at call time, because the weapon host attaches its
## LABELS after the catalog is already open.
func display_name(id: String) -> String:
	if kind(id) == KIND_WEAPON:
		return str(_labels.get(id, id))
	var item: Dictionary = _by_id.get(id, {})
	var stored := str(item.get("name", ""))
	if not stored.is_empty() and stored != id:
		return stored
	return str(_labels.get(id, id))

## Ordered item cards of the catalog (id, kind, price, desc, name). The order is
## the file order, so every tab shows its cheapest goods first.
func items() -> Array:
	var result: Array = []
	for id: String in _items:
		result.append((_by_id[id] as Dictionary).duplicate(true))
	return result

func items_of(kind: String) -> Array:
	var result: Array = []
	for card: Variant in items():
		if str((card as Dictionary).get("kind", "")) == kind:
			result.append(card)
	return result

func item_ids() -> Array:
	return _items.duplicate()

func item_count() -> int:
	return _items.size()

func has(id: String) -> bool:
	return _by_id.has(id)

func item(id: String) -> Dictionary:
	return (_by_id.get(id, {}) as Dictionary).duplicate(true)

func kind(id: String) -> String:
	return str((_by_id.get(id, {}) as Dictionary).get("kind", ""))

func price(id: String) -> int:
	return int((_by_id.get(id, {}) as Dictionary).get("price", 0))

func desc(id: String) -> String:
	return str((_by_id.get(id, {}) as Dictionary).get("desc", ""))

func rounds(id: String) -> int:
	return int((_by_id.get(id, {}) as Dictionary).get("rounds", 0))

func caliber(id: String) -> String:
	return str((_by_id.get(id, {}) as Dictionary).get("caliber", ""))

## Guns this box of ammo feeds. Empty for anything that is not ammo.
func ammo_weapons(id: String) -> Array:
	return ((_by_id.get(id, {}) as Dictionary).get("weapons", []) as Array).duplicate()

func limit(id: String) -> int:
	return int((_by_id.get(id, {}) as Dictionary).get("limit", MAX_LIMIT))

func defense(id: String) -> int:
	return int((_by_id.get(id, {}) as Dictionary).get("defense", 0))

func armor_color(id: String) -> String:
	var color := str((_by_id.get(id, {}) as Dictionary).get("color", ""))
	return color if not color.is_empty() else "#46525c"

func heal(id: String) -> int:
	return int((_by_id.get(id, {}) as Dictionary).get("heal", 0))

func icon(id: String) -> String:
	var item: Dictionary = _by_id.get(id, {})
	var explicit := str(item.get("icon", ""))
	if not explicit.is_empty():
		return explicit
	return str(KIND_ICONS.get(str(item.get("kind", "")), "📦"))

## Only the kinds that actually have goods, in the fixed tab order.
func tabs() -> Array:
	var result: Array = []
	for tab: Variant in KIND_TABS:
		var kind := str((tab as Dictionary).get("kind", ""))
		if not items_of(kind).is_empty():
			result.append((tab as Dictionary).duplicate(true))
	return result

func starter_ids() -> Array:
	return _starter.duplicate()

## Card statistics: weapons come from the real fire profile, armor from its own
## defence value, consumables from their carry limit. Plain comparisons instead of
## `match`: a non-literal pattern in GDScript binds a variable rather than
## comparing it, which would silently match every kind.
func stats(id: String) -> String:
	var card_kind := kind(id)
	if card_kind == KIND_WEAPON:
		return _weapon_stats(id)
	if card_kind == KIND_AMMO:
		var names := PackedStringArray()
		for gun: String in ammo_weapons(id):
			names.append(display_name(gun))
		return "%d патронов · калибр %s · подходит: %s" % [rounds(id), caliber(id), ", ".join(names)]
	if card_kind == KIND_ARMOR:
		return "Броня %d · первый урон принимает жилет · надевается поверх одежды" % defense(id)
	if card_kind == KIND_CONSUMABLE:
		return "В рюкзаке до %d шт." % limit(id)
	return ""

func open(at_path: String = DEFAULT_PATH) -> Dictionary:
	if _ready:
		return {"ok": false, "reason": "already_open"}
	_path = at_path
	if not FileAccess.file_exists(at_path):
		return _fail("catalog_missing")
	var file := FileAccess.open(at_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return _fail("catalog_unreadable")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("catalog_not_dictionary")
	var data: Dictionary = parsed
	if str(data.get("schema", "")) != SCHEMA:
		return _fail("catalog_schema")
	_title = _text(data.get("title", DEFAULT_TITLE), DEFAULT_TITLE)
	_cash = _money(data.get("starting_cash", 0))
	_seller = _seller_from(data.get("seller", {}))
	_read_weapons(data.get("weapons", []))
	_read_ammo(data.get("ammo", []))
	_read_armor(data.get("armor", []))
	_read_consumables(data.get("consumables", []))
	if _items.is_empty():
		return _fail("catalog_no_items")
	for value: Variant in data.get("starter", []):
		var id := str(value)
		if _by_id.has(id) and kind(id) == KIND_WEAPON and not _starter.has(id):
			_starter.append(id)
	_ready = true
	return {
		"ok": true,
		"items": _items.size(),
		"weapons": items_of(KIND_WEAPON).size(),
		"armor": items_of(KIND_ARMOR).size(),
		"consumables": items_of(KIND_CONSUMABLE).size(),
		"starter": _starter.size(),
		"cash": _cash,
		"skipped": _skipped.duplicate()
	}

func snapshot() -> Dictionary:
	return {
		"ready": _ready,
		"error": _error,
		"path": _path,
		"title": _title,
		"cash": _cash,
		"seller": _seller.duplicate(),
		"starter": _starter.duplicate(),
		"items": _items.size(),
		"skipped": _skipped.duplicate(),
		"weapons": _ids_of(KIND_WEAPON),
		"ammo": _ids_of(KIND_AMMO),
		"armor": _ids_of(KIND_ARMOR),
		"consumables": _ids_of(KIND_CONSUMABLE)
	}

## Typed loop variables are not allowed inside a list comprehension, so the id
## lists are built explicitly.
func _ids_of(kind: String) -> Array:
	var result: Array = []
	for card: Variant in items_of(kind):
		result.append(str((card as Dictionary).get("id", "")))
	return result

func _fail(reason: String) -> Dictionary:
	_error = reason
	_ready = false
	return {"ok": false, "reason": reason}

func _read_weapons(value: Variant) -> void:
	if not value is Array:
		_skipped.append("weapons_not_array")
		return
	for row: Variant in value:
		if not row is Dictionary:
			_skipped.append("weapon_not_dictionary")
			continue
		var id := str((row as Dictionary).get("id", ""))
		if not Fire.FIREARM_IDS.has(id):
			_skipped.append(id + ":unknown_weapon")
			continue
		_add_card(row as Dictionary, KIND_WEAPON, id)

## Ammo is sold as whole boxes of rounds and lands in the owned guns of that
## caliber, exactly like the 3D shop's Патроны tab.
func _read_ammo(value: Variant) -> void:
	if not value is Array:
		_skipped.append("ammo_not_array")
		return
	for row: Variant in value:
		if not row is Dictionary:
			_skipped.append("ammo_not_dictionary")
			continue
		var id := str((row as Dictionary).get("id", ""))
		if id.is_empty():
			_skipped.append("ammo_without_id")
			continue
		var rounds := _bounded_int((row as Dictionary).get("rounds", 0), 1, 200)
		var caliber := _text((row as Dictionary).get("caliber", ""), "")
		var guns: Array = []
		for wanted: Variant in (row as Dictionary).get("weapons", []):
			var gun := str(wanted)
			if Fire.FIREARM_IDS.has(gun) and not guns.has(gun):
				guns.append(gun)
		if rounds <= 0 or caliber.is_empty() or guns.is_empty():
			_skipped.append(id + ":ammo_fields")
			continue
		var card := _card(row as Dictionary, KIND_AMMO, id)
		card["rounds"] = rounds
		card["caliber"] = caliber
		card["weapons"] = guns
		card["name"] = _text((row as Dictionary).get("name", id), id)
		_store(card, id)

func _read_armor(value: Variant) -> void:
	if not value is Array:
		_skipped.append("armor_not_array")
		return
	for row: Variant in value:
		if not row is Dictionary:
			_skipped.append("armor_not_dictionary")
			continue
		var id := str((row as Dictionary).get("id", ""))
		if id.is_empty():
			_skipped.append("armor_without_id")
			continue
		var protection := _bounded_int((row as Dictionary).get("defense", 0), 1, MAX_DEFENSE)
		if protection <= 0:
			_skipped.append(id + ":defense")
			continue
		var card := _card(row as Dictionary, KIND_ARMOR, id)
		card["defense"] = protection
		card["color"] = _text((row as Dictionary).get("color", ""), "#46525c")
		card["name"] = _text((row as Dictionary).get("name", id), id)
		_store(card, id)

func _read_consumables(value: Variant) -> void:
	if not value is Array:
		_skipped.append("consumables_not_array")
		return
	for row: Variant in value:
		if not row is Dictionary:
			_skipped.append("consumable_not_dictionary")
			continue
		var id := str((row as Dictionary).get("id", ""))
		if id.is_empty():
			_skipped.append("consumable_without_id")
			continue
		var card := _card(row as Dictionary, KIND_CONSUMABLE, id)
		card["limit"] = _bounded_int((row as Dictionary).get("limit", MAX_LIMIT), 1, MAX_LIMIT)
		card["icon"] = _text((row as Dictionary).get("icon", ""), "")
		card["heal"] = _bounded_int((row as Dictionary).get("heal", 0), 0, 100000)
		card["name"] = _text((row as Dictionary).get("name", id), id)
		_store(card, id)

func _card(row: Dictionary, kind: String, id: String) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"name": id,
		"desc": _text(row.get("desc", ""), ""),
		"price": _money(row.get("price", 0))
	}

func _add_card(row: Dictionary, kind: String, id: String) -> void:
	# Weapons keep the bare id here; display_name() borrows the host labels.
	var card := _card(row, kind, id)
	_store(card, id)

func _store(card: Dictionary, id: String) -> void:
	if _by_id.has(id):
		_skipped.append(id + ":duplicate")
		return
	if int(card.get("price", 0)) <= 0:
		_skipped.append(id + ":price")
		return
	if _items.size() >= MAX_ITEMS:
		_skipped.append(id + ":too_many_items")
		return
	_by_id[id] = card
	_items.append(id)

func _weapon_stats(id: String) -> String:
	var profile: Dictionary = Fire.profile(id)
	if profile.is_empty():
		return ""
	var parts := PackedStringArray()
	parts.append("Урон %d" % int(round(float(profile.get("damage", 0.0)))))
	parts.append("Магазин %d" % int(profile.get("magazineSize", 0)))
	parts.append("Перезарядка %.1f с" % float(profile.get("reloadSeconds", 0.0)))
	parts.append("Дальность %.0f м" % float(profile.get("range", 0.0)))
	if int(profile.get("pellets", 1)) > 1:
		parts.append("Дробь %d" % int(profile.get("pellets", 1)))
	parts.append("автоматический" if bool(profile.get("automatic", false)) else "одиночный")
	var units: int = int(Sizes.COSTS.get(id, 0))
	if units > 0:
		parts.append("место %d" % units)
	return " · ".join(parts)

func _money(value: Variant) -> int:
	if not (value is int or value is float):
		return 0
	var number := float(value)
	if not is_finite(number) or number < 0.0 or number > float(MAX_MONEY):
		return 0
	return int(floor(number))

func _bounded_int(value: Variant, minimum: int, maximum: int) -> int:
	if not (value is int or value is float):
		return minimum
	var number := float(value)
	if not is_finite(number) or number < float(minimum) or number > float(maximum):
		return minimum
	return int(floor(number))

func _text(value: Variant, fallback: String) -> String:
	if not value is String:
		return fallback
	var text: String = value.strip_edges()
	if text.is_empty():
		return fallback
	return text.substr(0, MAX_TEXT)

func _seller_from(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for key: String in DEFAULT_SELLER:
		result[key] = _text(source.get(key, DEFAULT_SELLER[key]), str(DEFAULT_SELLER[key]))
	return result
