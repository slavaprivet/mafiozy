extends SceneTree
const Document = preload("res://scripts/map_editor/map_document.gd")
const Patch = preload("res://scripts/map_editor/map_patch.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _init() -> void:
	var baseline := {"schema_version": 1, "map_id": "city", "metadata": {"source_sha": "original", "native_scale": 4.1}, "opaque": {"keep": [3, 2, 1]}, "objects": [
		{"id": "house:1", "kind": "building", "model": "original_house", "source": {"authority": "server", "owner": "gang:2", "nested": {"unchanged": true}}},
		{"id": "lamp:1", "kind": "lamp", "model": "original_lamp", "protected_metadata": {"editable": false}}
	]}
	baseline = Document.validate_document(baseline).document
	var baseline_snapshot := baseline.duplicate(true)
	var editor := Document.new()
	editor.load_document(baseline)
	editor.update_record("house:1", {"transform": {"position": [10, 2, 30], "rotation": [0, 1.2, 0]}})
	editor.delete_record("lamp:1")
	editor.add_record({"id": "editor:sign:1", "kind": "sign", "model": "stop_sign", "transform": {"position": [1, 2, 3]}, "source": {"palette": "trusted_catalogue"}})
	var current: Dictionary = editor.to_dictionary()
	var derived := Patch.derive_patch(baseline, current)
	check(derived.ok, "derive move remove add patch")
	check(derived.patch.deleted == ["lamp:1"] and derived.patch.modified.size() == 1 and derived.patch.added.size() == 1, "exact operations")
	check(derived.patch.baseline_sha256.length() == 64, "baseline SHA256 length")
	var restored := Patch.apply_patch(baseline, derived.patch)
	check(restored.ok and restored.document == current, "lossless reconstructed map")
	check(baseline == baseline_snapshot, "immutable baseline")
	check(restored.document.objects[0].source == baseline.objects[0].source, "original authority owner source intact")
	var json_patch: Dictionary = JSON.parse_string(JSON.stringify(derived.patch, "", true, true))
	check(Patch.apply_patch(baseline, json_patch).ok, "JSON patch roundtrip")
	var reordered := {"objects": baseline.objects.duplicate(true), "opaque": baseline.opaque.duplicate(true), "metadata": {"native_scale": 4.1, "source_sha": "original"}, "map_id": "city", "schema_version": 1}
	check(Patch.baseline_hash(baseline).sha256 == Patch.baseline_hash(reordered).sha256, "recursive dictionary order canonical")
	var parsed_base: Dictionary = JSON.parse_string(JSON.stringify(baseline, "", true, true))
	check(Patch.baseline_hash(baseline).sha256 == Patch.baseline_hash(parsed_base).sha256, "number hash JSON roundtrip")
	var other_base := baseline.duplicate(true)
	other_base.objects[0].source.owner = "gang:3"
	check(not Patch.apply_patch(other_base, derived.patch).ok, "changed baseline rejected")
	for tampered_key in ["model", "source", "kind"]:
		var tampered := current.duplicate(true)
		tampered.objects[0][tampered_key] = {"authority": "client"} if tampered_key == "source" else "forged"
		check(not Patch.derive_patch(baseline, tampered).ok, "immutable original field rejected")
	var bad := current.duplicate(true)
	bad.metadata.source_sha = "forged"
	check(not Patch.derive_patch(baseline, bad).ok, "header immutable")
	bad = baseline.duplicate(true)
	bad.objects[1].protected_metadata.editable = true
	check(not Patch.derive_patch(baseline, bad).ok, "protected metadata cannot self-unlock")
	bad = current.duplicate(true)
	bad.objects[1].id = "source:forged"
	check(not Patch.derive_patch(baseline, bad).ok, "added ID namespace")
	var patch: Dictionary = derived.patch.duplicate(true)
	patch.modified[0].source = {"authority": "forged"}
	check(not Patch.apply_patch(baseline, patch).ok, "modified forged source rejected")
	patch = derived.patch.duplicate(true)
	patch.modified[0].transform.authority = "forged"
	check(not Patch.apply_patch(baseline, patch).ok, "modified transform extra key rejected")
	patch = derived.patch.duplicate(true)
	patch.modified[0].transform.scale = [-1, 1, 1]
	check(not Patch.apply_patch(baseline, patch).ok, "invalid transform rejected")
	patch = derived.patch.duplicate(true)
	patch.deleted.append("lamp:1")
	check(not Patch.apply_patch(baseline, patch).ok, "duplicate delete rejected")
	patch = derived.patch.duplicate(true)
	patch.deleted.append("house:1")
	check(not Patch.apply_patch(baseline, patch).ok, "cross-operation duplicate rejected")
	patch = derived.patch.duplicate(true)
	patch.modified[0].id = "unknown:1"
	check(not Patch.apply_patch(baseline, patch).ok, "unknown ID rejected")
	patch = derived.patch.duplicate(true)
	patch.added.append(patch.added[0].duplicate(true))
	check(not Patch.apply_patch(baseline, patch).ok, "duplicate added rejected")
	patch = derived.patch.duplicate(true)
	patch.map_id = "other"
	check(not Patch.apply_patch(baseline, patch).ok, "wrong map rejected")
	patch = derived.patch.duplicate(true)
	patch.baseline_sha256 = "a".repeat(64)
	check(not Patch.apply_patch(baseline, patch).ok, "wrong hash rejected")
	patch = derived.patch.duplicate(true)
	patch.custom = "unknown"
	check(not Patch.apply_patch(baseline, patch).ok, "unknown patch field rejected")
	var unchanged := Patch.derive_patch(baseline, baseline)
	check(unchanged.ok and unchanged.patch.deleted.is_empty() and unchanged.patch.modified.is_empty() and unchanged.patch.added.is_empty(), "no-op patch")
	check(Patch.apply_patch(baseline, unchanged.patch).document == baseline, "no-op roundtrip")
	print("map_patch: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

