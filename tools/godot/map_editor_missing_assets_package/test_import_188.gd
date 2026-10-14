extends SceneTree
## Opt-in headless import check. Does not instantiate the full game world.
var checks := 0
var failures: Array[String] = []
var loaded := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var raw := FileAccess.get_file_as_string("res://test_import_manifest.json")
	var manifest: Variant = JSON.parse_string(raw)
	if not manifest is Dictionary or manifest.get("schema") != "mafiozi.map-editor-missing-assets-package/v1":
		print(JSON.stringify({"checks":checks,"failures":["manifest_invalid"]}))
		quit(1); return
	var started := Time.get_ticks_msec()
	var missing := 0
	var present := 0
	for row: Dictionary in manifest.resources:
		if Time.get_ticks_msec() - started > 90000:
			failures.append("bounded_resource_check_timeout")
			break
		var location: String = row.proposedResPath
		if row.packagePath == null: present += 1
		else: missing += 1
		check(FileAccess.file_exists(location), "raw_glb:" + row.sha256)
		check(FileAccess.file_exists(location + ".import"), "import_sidecar:" + row.sha256)
		check(ResourceLoader.exists(location), "resource_exists:" + row.sha256)
		var resource: Resource = ResourceLoader.load(location)
		check(resource is PackedScene, "packed_scene:" + row.sha256)
		if resource is PackedScene: loaded += 1
		resource = null
	check(missing == 188 and present == 8, "exact_188_plus_8_catalog_paths")
	print(JSON.stringify({"checks":checks,"failures":failures,"missing":missing,"present":present,"loaded":loaded,"elapsed_ms":Time.get_ticks_msec()-started,"scope":"headless GLB import only; no full world or GPU"}))
	quit(0 if failures.is_empty() else 1)
