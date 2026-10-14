extends SceneTree
const Document = preload("res://scripts/map_editor/map_document.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _init() -> void:
	# Only unique test-owned saves; never touch the player's current map.
	var path := "user://maps/tests/document_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var document := Document.new()
	document.add_record({"id": "building:1", "kind": "building", "model": "original", "source": {"owner": "gang:2", "collision": {"a": 0.12345678901234567}}, "custom": [1, {"skin": "родной"}]})
	check(Store.export_json(document).ok, "export native model")
	check(Store.import_json(Store.export_json(document).text).ok, "import JSON")
	check(not Store.import_json("{broken").ok, "reject corrupt JSON")
	check(not Store.import_json("[]").ok, "reject wrong root")
	for rejected in ["res://maps/game.json", "C:/game.json", "user://maps/../game.json", "user://maps//game.json", "user://maps/foo\\bar.json", "user://maps/.json/../b.json", "user://maps/evil.gd", "user://maps/.. /game.json", "user://maps/nul.json", "user://maps/lpt1.json", "user://maps/foo./bar.json", "user://maps/fo*/bar.json"]:
		check(not Store.valid_path(rejected), "path traversal/resource writes blocked")
	check(Store.valid_path(path), "test-owned nested path")
	check(Store.save_document(document, path).ok, "save first revision")
	var loaded := Store.load_document(path)
	check(loaded.ok and not loaded.recovered, "load primary")
	check(loaded.document.objects[0].custom[1].skin == "родной", "UTF8 preserved")
	check(loaded.document.objects[0].source.collision.a == 0.12345678901234567, "full precision preserved")
	document.update_record("building:1", {"model": "revision2"})
	check(Store.save_document(document, path).ok, "save second revision with backup")
	check(Store.load_document(path).document.objects[0].model == "revision2", "second revision current")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("truncated")
	corrupt.close()
	loaded = Store.load_document(path)
	check(loaded.ok and loaded.recovered and loaded.document.objects[0].model == "original", "corrupt primary recovers healthy backup")
	document.update_record("building:1", {"model": "revision3"})
	check(Store.save_document(document, path).ok, "repair corrupt primary without losing backup")
	check(Store.load_document(path).document.objects[0].model == "revision3", "repaired current")
	var backup := Store.import_json(FileAccess.get_file_as_string(path + ".bak"))
	check(backup.ok and backup.document.objects[0].model == "original", "corrupt primary never overwrites good backup")
	var invalid := document.to_dictionary()
	invalid.objects[0].transform.position = [INF, 0, 0]
	check(not Store.save_document(invalid, path).ok, "invalid save rejected before disk mutation")
	check(Store.load_document(path).document.objects[0].model == "revision3", "invalid save retains primary")
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("map_store: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

