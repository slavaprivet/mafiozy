extends RefCounted
## Display metadata only. Availability is admitted by the live registry, never
## by editable/available flags contained in a source or imported JSON catalog.
const CATEGORIES := {"buildings": "Дома и здания", "roads": "Дороги", "ground": "Земля и покрытия", "lights": "Фонари", "signs": "Дорожные знаки", "monuments": "Памятники и фонтаны", "decor": "Городские объекты", "nature": "Деревья и природа", "railway": "Железная дорога"}
static var _control_characters := RegEx.create_from_string("[\\x00-\\x1f]")
static func _label(value: Variant, fallback: String) -> String:
	if not value is String: return fallback
	var cleaned: String = _control_characters.sub(value.left(300), "", true).strip_edges()
	return fallback if cleaned.is_empty() else cleaned

static func build(catalog: Dictionary, registry: RefCounted, registered_ids: Dictionary = {}) -> Dictionary:
	if catalog.get("schema") != "mafiozi.godot.map-editor-catalog/v1" or not catalog.get("objects") is Array or not catalog.get("assets") is Array:
		return {"ok": false, "error": "Нет проверенного каталога объектов"}
	if registry == null or not registry.has_method("has_object") or not registry.has_method("is_editable"):
		return {"ok": false, "error": "Нет реестра объектов игровой сцены"}
	var assets := {}
	for asset: Variant in catalog.assets:
		if asset is Dictionary and asset.get("assetId") is String: assets[asset.assetId] = asset
	var counts := {}
	for row: Variant in catalog.objects:
		if row is Dictionary and row.get("id") is String: counts[row.id] = counts.get(row.id, 0) + 1
	var items: Array = []
	var seen := {}
	var admitted := 0
	for row: Variant in catalog.objects:
		if not row is Dictionary or not row.get("key") is String or not row.get("id") is String or seen.has(row.key):
			return {"ok": false, "error": "Неоднозначная запись каталога"}
		seen[row.key] = true
		var asset: Dictionary = assets.get(row.get("assetId", ""), {})
		var id: String = str(registered_ids.get(row.key, row.key))
		if not registered_ids.has(row.key) and not registry.has_object(id) and counts[row.id] == 1 and registry.has_object(row.id): id = row.id
		var present: bool = registry.has_object(id)
		var available: bool = present and registry.is_editable(id)
		if available: admitted += 1
		var category := str(row.get("category", asset.get("category", "decor")))
		if row.get("dataset") in ["buildings", "detention"]: category = "buildings"
		items.append({"id": id, "semantic_key": row.key, "label": _label(row.get("label", asset.get("label")), "Объект " + row.id), "category": CATEGORIES.get(category, "Городские объекты"), "available": available, "reason": "" if available else ("нужен игровой адаптер" if present else "ещё не подключён к сцене")})
	return {"ok": true, "items": items, "admitted": admitted, "total": items.size()}
