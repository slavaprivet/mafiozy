extends SceneTree
## Headless load-admission tests. No fixture files or actual scene are modified.
## Import failures are injected at the loader boundary; the positive path loads
## all six real resources with Godot's actual importer/cache.

const Validation = preload("res://scripts/preview_block_validation.gd")
var _failures: Array[String] = []
var _negative_cases: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	var before: String = JSON.stringify(block)
	var good: PackedStringArray = Validation.validate(block)
	_check(good.is_empty(), "actual block passes: " + str(good))
	_check(JSON.stringify(block) == before, "pure validator leaves actual data unchanged")
	_check(not Validation.validate(null).is_empty(), "null input rejects without throwing")
	_check(not Validation.validate({}).is_empty(), "missing structure rejects without throwing")
	_check(not Validation.validate([]).is_empty(), "array input rejects without throwing")
	_expect(block, "unknown schema", func(d: Dictionary) -> void: d["schema"] = "mafiozi.godot.preview-block/v999", "schema")
	_expect(block, "duplicate visual ID", func(d: Dictionary) -> void: d["decor"][0]["id"] = d["buildings"][0]["id"], "duplicate ID")
	_expect(block, "missing anchor", func(d: Dictionary) -> void: d["anchorId"] = "NO-SUCH-ID", "anchorId")
	_expect(block, "declared building count differs", func(d: Dictionary) -> void: d["counts"]["buildings"] = 7, "counts.buildings")
	_expect(block, "declared collider count differs", func(d: Dictionary) -> void: d["counts"]["collisionBodies"] = 26, "counts.collisionBodies")
	_expect(block, "declared resources count differs", func(d: Dictionary) -> void: d["counts"]["uniqueGlbs"] = 5, "counts.uniqueGlbs")
	_expect(block, "declared cells count differs", func(d: Dictionary) -> void: d["counts"]["surfaceCells"] = 962, "counts.surfaceCells")
	_expect(block, "non-finite origin", func(d: Dictionary) -> void: d["originM"][0] = INF, "originM")
	_expect(block, "non-finite collider coordinate", func(d: Dictionary) -> void: d["buildings"][0]["collisionBodiesM"][0]["polygonXZ"][0][0] = NAN, "polygon")
	_expect(block, "source/local coordinate mismatch", func(d: Dictionary) -> void: d["buildings"][0]["positionLocalM"][0] += 1, "source origin")
	_expect(block, "zero scale", func(d: Dictionary) -> void: d["buildings"][0]["transform"]["uniformScale"] = 0, "uniform scale")
	_expect(block, "negative axis scale", func(d: Dictionary) -> void: d["buildings"][0]["transform"]["horizontalScale"][0] = -1, "horizontalScale")
	_expect(block, "non-finite yaw", func(d: Dictionary) -> void: d["buildings"][0]["transform"]["yawDegrees"] = NAN, "yaw")
	_expect(block, "unsafe resource traversal", func(d: Dictionary) -> void: d["buildings"][0]["path"] = "res://assets/../scripts/main.gd", ".path")
	_expect(block, "remote resource", func(d: Dictionary) -> void: d["hero"]["path"] = "https://example.invalid/hero.glb", "hero.path")
	_expect(block, "inverted collider height", func(d: Dictionary) -> void: d["buildings"][0]["collisionBodiesM"][0]["maxY"] = -1, "height bounds")
	_expect(block, "bow-tie collider", func(d: Dictionary) -> void: d["buildings"][0]["collisionBodiesM"][0]["polygonXZ"] = [[0, 0], [2, 2], [0, 2], [2, 0]], "polygon")
	_expect(block, "collinear collider", func(d: Dictionary) -> void: d["buildings"][0]["collisionBodiesM"][0]["polygonXZ"] = [[0, 0], [1, 0], [2, 0]], "polygon")
	_expect(block, "repeated collider vertex", func(d: Dictionary) -> void: d["buildings"][0]["collisionBodiesM"][0]["polygonXZ"] = [[0, 0], [1, 0], [1, 0], [0, 1]], "polygon")
	_expect(block, "non-dictionary collider", func(d: Dictionary) -> void: d["decor"][0]["collisionBodiesM"][0] = "bad", "expected dictionary")
	_expect(block, "ragged surface", func(d: Dictionary) -> void: d["surface"]["grid"][0].pop_back(), "columns")
	_expect(block, "unknown tile", func(d: Dictionary) -> void: d["surface"]["grid"][0][0] = 255, "palette entry")
	_expect(block, "invalid palette entry", func(d: Dictionary) -> void: d["surface"]["palette"]["16"] = null, "descriptor")
	_expect(block, "water must not become solid land", func(d: Dictionary) -> void: d["surface"]["palette"]["16"]["solid"] = true, "water tile")
	_expect(block, "invalid colour", func(d: Dictionary) -> void: d["surface"]["palette"]["16"]["colorSrgb"] = "not-a-colour", "colour")
	_expect(block, "mismatched world scale", func(d: Dictionary) -> void: d["surface"]["cellSize"] = 3.0, "world scale")
	_expect(block, "unbounded grid dimension", func(d: Dictionary) -> void: d["surface"]["rows"] = 100000, "bounded dimension")
	_expect(block, "crop outside real map", func(d: Dictionary) -> void: d["surface"]["startRow"] = d["surface"]["sourceMapRows"], "outside source map")
	_expect(block, "fractional tile index", func(d: Dictionary) -> void: d["surface"]["grid"][0][0] = 0.5, "palette entry")
	_expect(block, "boolean is not a number", func(d: Dictionary) -> void: d["hero"]["targetHeightM"] = true, "body dimensions")
	_expect(block, "invalid helper shape", func(d: Dictionary) -> void: d["decor"][0]["effectiveHiddenNodeNames"] = {}, "helper list")
	_expect(block, "material descriptor container", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"] = {}, "descriptor array")
	_expect(block, "material descriptor shape", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0] = null, "expected dictionary")
	_expect(block, "duplicate material ID", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][1]["id"] = d["surface"]["materialDescriptors"][0]["id"], "duplicate material ID")
	_expect(block, "invalid material ID", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["id"] = "", "stable material ID")
	_expect(block, "invalid material colour space", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["colorSpace"] = "srgb", "colorSpace")
	_expect(block, "incomplete RGBA factor", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["baseColorFactor"] = [0.1, 0.2, 0.3], "four finite")
	_expect(block, "nonfinite material channel", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["baseColorFactor"][0] = NAN, "finite 0..1")
	_expect(block, "material channel out of range", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["baseColorFactor"][3] = 1.1, "finite 0..1")
	_expect(block, "material boolean is not channel", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["baseColorFactor"][0] = true, "finite 0..1")
	_expect(block, "nonfinite material roughness", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["roughnessFactor"] = INF, "roughnessFactor")
	_expect(block, "negative material metallic", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["metallicFactor"] = -0.1, "metallicFactor")
	_expect(block, "material sidedness type", func(d: Dictionary) -> void: d["surface"]["materialDescriptors"][0]["doubleSided"] = "true", "doubleSided")
	_expect(block, "palette alone cannot introduce unsupported tile", func(d: Dictionary) -> void:
		d["surface"]["palette"]["200"] = {"kind": "not_implemented", "colorSrgb": "#888888", "heightM": 0, "solid": true}
		d["surface"]["grid"][0][0] = 200, "unsupported tile")
	var no_descriptors: Dictionary = block.duplicate(true)
	no_descriptors["surface"].erase("materialDescriptors")
	_check(Validation.validate(no_descriptors).is_empty(), "absent optional descriptors retain explicit native-palette fallback")
	var node_count: int = root.get_child_count()
	var prepared: Dictionary = Validation.prepare_assets(block)
	_check(prepared["errors"].is_empty() and prepared["scenes"].size() == 6, "all six actual imported scenes prepared atomically")
	_check(prepared["scenes"].has(block["hero"]["path"]), "hero included in preflight")
	_check(root.get_child_count() == node_count, "preflight does not build partial scene-tree nodes")
	var loads: Dictionary = {}
	var counted: Dictionary = Validation.prepare_assets(block, func(path: String) -> Resource:
		loads[path] = int(loads.get(path, 0)) + 1
		return ResourceLoader.load(path, "PackedScene"))
	_check(counted["errors"].is_empty() and loads.size() == 6, "shared building resources deduplicated")
	for count: int in loads.values():
		_check(count == 1, "each unique resource loaded only once")
	var missing: Dictionary = block.duplicate(true)
	missing["hero"]["path"] = "res://assets/absent-s00-test-hero.glb"
	_expect_resource_failure(Validation.prepare_assets(missing), "actual missing resource", "resource missing")
	var fail_path: String = str(block["buildings"][0]["path"])
	_expect_resource_failure(Validation.prepare_assets(block, func(path: String) -> Resource:
		return null if path == fail_path else ResourceLoader.load(path, "PackedScene")), "failed/corrupt import boundary", "failed PackedScene")
	_expect_resource_failure(Validation.prepare_assets(block, func(path: String) -> Resource:
		return StandardMaterial3D.new() if path == fail_path else ResourceLoader.load(path, "PackedScene")), "wrong resource type", "failed PackedScene")
	_expect_resource_failure(Validation.prepare_assets(block, func(path: String) -> Resource:
		return PackedScene.new() if path == fail_path else ResourceLoader.load(path, "PackedScene")), "empty PackedScene", "failed PackedScene")
	var wrong_root: Node2D = Node2D.new()
	var wrong_scene: PackedScene = PackedScene.new()
	wrong_scene.pack(wrong_root)
	wrong_root.free()
	_expect_resource_failure(Validation.prepare_assets(block, func(path: String) -> Resource:
		return wrong_scene if path == fail_path else ResourceLoader.load(path, "PackedScene")), "non-Node3D scene root", "root must be Node3D")
	var invalid: Dictionary = block.duplicate(true)
	invalid["schema"] = "unknown"
	var called: Array[int] = [0]
	_expect_resource_failure(Validation.prepare_assets(invalid, func(_path: String) -> Resource:
		called[0] += 1
		return null), "invalid schema prevents resource work", "schema")
	_check(called[0] == 0, "structural rejection loads no resources")
	_check(JSON.stringify(block) == before, "preflight leaves source data unchanged")
	print("PREVIEW_BLOCK_VALIDATION_TEST ", JSON.stringify({"passed": _failures.is_empty(), "negative_cases": _negative_cases, "actual_scenes": prepared["scenes"].size(), "failures": _failures, "limits": "load-admission tests only; corrupt importer result injected; no LIVE/FPS claim"}))
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _expect(block: Dictionary, label: String, mutate: Callable, message_fragment: String) -> void:
	var candidate: Dictionary = block.duplicate(true)
	mutate.call(candidate)
	var errors: PackedStringArray = Validation.validate(candidate)
	_check(not errors.is_empty() and str(errors).contains(message_fragment), label + ": " + str(errors))
	_negative_cases.append(label)


func _expect_resource_failure(result: Dictionary, label: String, message_fragment: String) -> void:
	_check(not result["errors"].is_empty() and str(result["errors"]).contains(message_fragment), label + " rejects with reason")
	_check(result["scenes"].is_empty(), label + " exposes no partial prepared scene map")
	_negative_cases.append(label)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.append(label)
