extends SceneTree
const CatalogUI = preload("res://scripts/map_editor/catalog_ui.gd")
const EditorPanel = preload("res://scripts/map_editor/editor_panel.gd")
class Index extends RefCounted:
	var present := {"live-house": true, "protected-house": false}
	func has_object(id: String) -> bool: return present.has(id)
	func is_editable(id: String) -> bool: return present.get(id, false)
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(CatalogUI._label("\n  Жилой\t дом\r\n", "Объект") == "Жилой дом", "control labels cleaned without changing Cyrillic")
	var index := Index.new()
	var catalog := {"schema": "mafiozi.godot.map-editor-catalog/v1", "assets": [{"assetId": "house", "label": "Жилой дом", "category": "buildings"}], "objects": [{"key": "buildings:one", "id": "live-house", "assetId": "house", "dataset": "buildings"}, {"key": "buildings:two", "id": "protected-house", "assetId": "house", "available": true}, {"key": "decor:missing", "id": "not-admitted", "label": "Памятник", "category": "monuments", "available": true}]}
	var result := CatalogUI.build(catalog, index)
	check(result.ok and result.admitted == 1 and result.total == 3, "availability comes only from native registry")
	check(result.items[0].label == "Жилой дом" and result.items[0].category == "Дома и здания", "original Russian labels/categories")
	check(not result.items[1].available and result.items[1].reason == "нужен игровой адаптер", "protected present object not misreported missing")
	check(not result.items[2].available and result.items[2].reason == "ещё не подключён к сцене", "source flag cannot unlock absent object")
	var panel := EditorPanel.new()
	root.add_child(panel)
	panel.set_catalog(result.items)
	panel.set_selection({"id": "live-house"})
	check(panel._selection.text == "Выбрано: Жилой дом", "selection uses catalog label without changing object record")
	var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk/data/map_editor/catalog.json"))
	var before := Time.get_ticks_usec()
	var full := CatalogUI.build(actual, index)
	var usec := Time.get_ticks_usec() - before
	check(full.ok and full.total == actual.objects.size(), "full actual source inventory")
	panel.set_catalog(full.items)
	check(panel._catalog_list.item_count <= 160 and panel._catalog.size() == actual.objects.size(), "full inventory retained, native visible list bounded")
	check(not full.items[0].has("sourceRecord"), "UI does not duplicate heavy geometry/source data")
	panel.free()
	for failure: String in failures: push_error(failure)
	print("catalog UI: ", checks, " checks, failures=", failures.size(), "; actual objects=", full.get("total", 0), "; one-time CPU usec=", usec)
	quit(0 if failures.is_empty() else 1)
