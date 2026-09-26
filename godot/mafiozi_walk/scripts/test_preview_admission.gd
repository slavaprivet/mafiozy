extends SceneTree
## Actual main.tscn admission regression. Expected rejection diagnostics remain
## visible on stderr; no global error suppression or runtime-source replacement.
## Temporary fixtures contain only copies of the public block manifest.

const SCENE_PATH: String = "res://scenes/main.tscn"
const BLOCK_PATH: String = "res://data/block.json"
var _failures: Array[String] = []
var _fixtures: Array[String] = []
var _results: Array[Dictionary] = []
var _prefix: String


func _initialize() -> void:
	_prefix = "user://preview_admission_test_%d_%d_" % [OS.get_process_id(), Time.get_ticks_usec()]
	call_deferred("_run")


func _run() -> void:
	var source_hash: String = FileAccess.get_sha256(BLOCK_PATH)
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BLOCK_PATH))
	var invalid_schema: Dictionary = block.duplicate(true)
	invalid_schema["schema"] = "mafiozi.godot.preview-block/v999"
	await _reject_case("unknown_schema", invalid_schema, "schema:")
	var missing_asset: Dictionary = block.duplicate(true)
	missing_asset["buildings"][0]["path"] = "res://assets/buildings/absent-admission-test.glb"
	await _reject_case("missing_building", missing_asset, "resource missing or unrecognized:")
	var missing_hero: Dictionary = block.duplicate(true)
	missing_hero["hero"]["path"] = "res://assets/absent-admission-hero.glb"
	await _reject_case("missing_hero", missing_hero, "resource missing or unrecognized:")
	# Previously reproduced false READY: malformed source material passed schema
	# admission and failed only after construction. This regression is mandatory.
	var invalid_material: Dictionary = block.duplicate(true)
	for descriptor: Dictionary in invalid_material["surface"].get("materialDescriptors", []):
		if descriptor.get("id") == "MAT_CLAY_ASPHALT_CLEAN":
			descriptor["colorSpace"] = "invalid-admission-colour-space"
	await _reject_case("invalid_material_descriptor", invalid_material, "surface.materialDescriptors")
	var unsupported_tile: Dictionary = block.duplicate(true)
	unsupported_tile["surface"]["palette"]["200"] = {"kind": "not_implemented", "colorSrgb": "#888888", "heightM": 0, "solid": true}
	unsupported_tile["surface"]["grid"][0][0] = 200
	await _reject_case("unsupported_surface_tile", unsupported_tile, "surface.grid: unsupported tile")
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	var valid: Node3D = packed.instantiate() as Node3D
	root.add_child(valid)
	await _frames(45)
	_check(bool(valid.get("preview_ready")), "valid actual scene becomes ready after prior rejections")
	_check(valid.get("validation_errors").is_empty(), "valid actual scene has no stale rejection errors")
	var player: CharacterBody3D = valid.get("_player") as CharacterBody3D
	_check(player != null, "valid scene creates real player")
	if player != null:
		_check(bool(player.get_preview_status().get("model_loaded", false)), "valid actual hero imports")
		_check(player.is_on_floor(), "valid actual hero settles on block floor")
	var visuals: int = 0
	var colliders: int = 0
	for child: Node in valid.get_children():
		if child.has_meta("source_id"):
			if child is StaticBody3D:
				colliders += 1
			elif child is Node3D:
				visuals += 1
	_check(visuals == 16 and colliders == 27, "valid scene restores all 16 visuals and 27 source colliders")
	_results.append({"case": "valid_after_rejections", "preview_ready": valid.get("preview_ready"), "visuals": visuals, "source_colliders": colliders})
	var valid_ref: WeakRef = weakref(valid)
	valid.queue_free()
	valid = null
	player = null
	await _frames(2)
	_check(valid_ref.get_ref() == null, "valid scene instance freed")
	for path: String in _fixtures:
		_check(path.begins_with(_prefix) and path.ends_with(".json"), "fixture cleanup stays within owned prefix")
		if path.begins_with(_prefix) and path.ends_with(".json"):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "temporary fixture removed")
			_check(not FileAccess.file_exists(path), "temporary fixture no longer exists")
	_check(FileAccess.get_sha256(BLOCK_PATH) == source_hash, "actual block data unchanged")
	print("PREVIEW_ADMISSION_TEST ", JSON.stringify({"passed": _failures.is_empty(), "cases": _results, "expected_rejection_diagnostics": _fixtures.size(), "temporary_files_removed": _fixtures.size(), "failures": _failures, "live": false, "fps": false}))
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _reject_case(label: String, fixture: Dictionary, error_prefix: String) -> void:
	var path: String = _prefix + label + ".json"
	_check(not FileAccess.file_exists(path), "unique temporary fixture " + label)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "could not create owned temporary fixture " + label)
		return
	file.store_string(JSON.stringify(fixture))
	file.close()
	_fixtures.append(path)
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	var instance: Node3D = packed.instantiate() as Node3D
	instance.set("block_data_path", path)
	print("EXPECTED_REJECTION_BEGIN case=", label, " message=MAFIOZI_PREVIEW_REJECTED: ", error_prefix)
	root.add_child(instance)
	await _frames(2)
	var errors: PackedStringArray = instance.get("validation_errors")
	_check(not bool(instance.get("preview_ready")), label + " never becomes ready")
	_check(errors.size() == 1 and errors[0].begins_with(error_prefix), label + " has the specific expected diagnostic only: " + str(errors))
	_check(instance.get("_player") == null, label + " creates no player")
	_check(instance.get("_resource_scenes").is_empty(), label + " exposes no partial resource map")
	_check(instance.find_children("*", "Node3D", true, false).is_empty(), label + " creates no 3D assets or physical bodies")
	_check(instance.find_children("*", "StaticBody3D", true, false).is_empty(), label + " creates no static physics")
	_check(instance.find_children("*", "WorldEnvironment", true, false).is_empty(), label + " creates no environment")
	_check(not instance.is_processing(), label + " stops preview processing")
	_check(instance.get_child_count() == 1 and instance.get_child(0) is CanvasLayer, label + " only error UI is present")
	_check(not instance.find_children("*", "Label", true, false).is_empty(), label + " explains failure in UI")
	_results.append({"case": label, "preview_ready": instance.get("preview_ready"), "errors": Array(errors), "three_d_children": instance.find_children("*", "Node3D", true, false).size()})
	var instance_ref: WeakRef = weakref(instance)
	instance.queue_free()
	instance = null
	await _frames(2)
	_check(instance_ref.get_ref() == null, label + " rejected instance freed")
	print("EXPECTED_REJECTION_END case=", label)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame
		await process_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.append(label)
