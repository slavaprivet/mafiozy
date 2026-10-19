extends SceneTree
## Read-only native loader check in the production project. No scene/UI/GPU.
var failures: Array[String] = []
var samples: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var file := FileAccess.open("res://data/map_editor/catalog.json", FileAccess.READ)
	if file == null:
		printerr("MAP_ASSET_LOAD_FAIL catalog")
		quit(1); return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("resources", null) is Array:
		printerr("MAP_ASSET_LOAD_FAIL catalog format")
		quit(1); return
	var rows: Array = parsed.resources
	for row: Dictionary in rows:
		var id: String = str(row.get("id", ""))
		var path := "res://assets/map_editor/" + id + ".glb"
		var started := Time.get_ticks_usec()
		var packed: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		samples.append(Time.get_ticks_usec() - started)
		if not packed is PackedScene:
			failures.append(id)
	samples.sort()
	var count := samples.size()
	print("MAP_ASSET_LOAD ", JSON.stringify({"models":count,"failures":failures,"p50_us":samples[count / 2] if count>0 else -1,"p95_us":samples[mini(count - 1, int(ceil(count * 0.95)))] if count>0 else -1,"scope":"native PackedScene load only; no full map/FPS"}))
	quit(0 if count == 196 and failures.is_empty() else 1)
