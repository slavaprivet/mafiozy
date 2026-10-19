extends SceneTree
const Bundle = preload("res://scripts/map_editor/map_bundle.gd")
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	var hash := "a".repeat(64)
	var baseline := {"schema_version": 1, "map_id": "published-map", "metadata": {"revision": 3}, "objects": [{"id": "house", "kind": "building", "model": "native-house", "source": {"authority": 7}, "transform": {"position": [0, 0, 0], "rotation": [0, 0, 0], "scale": [1, 1, 1]}}]}
	var edited: Dictionary = baseline.duplicate(true)
	edited.objects[0].transform.position = [12, 0, 4]
	var requirements := {"native-house": [hash]}
	var available := {hash: true}
	var created: Dictionary = Bundle.create(baseline, edited, requirements, "Моя карта")
	check(created.ok, "create portable bundle")
	var encoded: Dictionary = Bundle.export_json(created.bundle)
	var parsed: Dictionary = Bundle.import_json(encoded.text)
	var accepted: Dictionary = Bundle.validate(baseline, parsed.bundle, requirements, available)
	check(accepted.ok and accepted.document.objects[0].transform.position == [12.0, 0.0, 4.0], "roundtrip preserves edit")
	check(baseline.objects[0].transform.position == [0, 0, 0] and baseline.objects[0].source.authority == 7, "baseline unchanged")
	check(not Bundle.validate(baseline, parsed.bundle, requirements, {}).ok, "missing native resource")
	check(not Bundle.validate(baseline, parsed.bundle, requirements, {hash: false}).ok, "listed but unverified resource")
	var corrupted: Dictionary = parsed.bundle.duplicate(true)
	corrupted.label = "подмена"
	check(not Bundle.validate(baseline, corrupted, requirements, available).ok, "checksum rejects modified file")
	corrupted = parsed.bundle.duplicate(true)
	corrupted.script = "res://malicious.gd"
	check(not Bundle.validate(baseline, corrupted, requirements, available).ok, "executable path rejected")
	var different: Dictionary = baseline.duplicate(true)
	different.metadata.revision = 4
	check(not Bundle.validate(different, parsed.bundle, requirements, available).ok, "different source map")
	check(not Bundle.create(baseline, edited, {}, "Моя карта").ok, "model requires trusted resource table")
	check(not Bundle.create(baseline, edited, requirements, "Моя карта", {"trusted": true}).ok, "ground cannot self-authorize")
	check(not Bundle.import_json("{invalid}").ok, "invalid JSON")
	for failure: String in failures: push_error(failure)
	print("map publication bundle: 11 checks, failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
