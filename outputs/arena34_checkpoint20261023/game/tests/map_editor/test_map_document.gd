extends SceneTree
const Document = preload("res://scripts/map_editor/map_document.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _init() -> void:
	var doc := Document.new(2)
	var original := {"id": "house:7", "kind": "building", "model": "townhouse", "source": {"owner": "gang:4", "rooms": [1, 2]}, "custom": {"texture": "original"}}
	check(doc.add_record(original).ok, "add native record")
	original.source.rooms.append(3)
	check(doc.get_record("house:7").source.rooms == [1, 2], "input is immutable")
	var returned := doc.get_record("house:7")
	returned.source.owner = "mutated"
	check(doc.get_record("house:7").source.owner == "gang:4", "returned value is detached")
	check(doc.get_record("house:7").transform.scale == [1.0, 1.0, 1.0], "identity transform normalization")
	check(not doc.add_record(original).ok, "duplicate rejected")
	var position_result := doc.update_record("house:7", {"transform": {"position": [4, 5, 6]}})
	check(position_result.ok, "position update")
	check(doc.get_record("house:7").source.rooms == [1, 2], "opaque gameplay source preserved")
	check(doc.get_record("house:7").custom.texture == "original", "opaque custom preserved")
	check(not doc.update_record("house:7", {"id": "replacement"}).ok, "id cannot be replaced")
	check(doc.delete_record("house:7").ok, "delete")
	var preview := doc.peek_undo()
	check(preview.ok and preview.document.objects[0].id == "house:7", "undo preflight candidate")
	check(not doc.has_record("house:7") and doc.can_undo(), "undo preview is non-mutating")
	check(doc.undo().ok and doc.has_record("house:7"), "undo delete")
	check(doc.undo().ok and doc.get_record("house:7").transform.position == [0.0, 0.0, 0.0], "undo transform")
	check(doc.peek_redo().ok and doc.peek_redo().document.objects[0].transform.position == [4, 5, 6], "redo preflight candidate")
	check(not doc.undo().ok, "bounded history drops oldest action")
	check(doc.redo().ok and doc.get_record("house:7").transform.position == [4, 5, 6], "redo transform")
	check(doc.add_record({"id": "lamp:1", "kind": "lamp"}).ok, "new branch add")
	check(not doc.can_redo(), "new branch clears redo")
	check(doc.add_record({"id": "lamp:2", "kind": "lamp"}).ok, "second branch add")
	check(doc.delete_record("lamp:1").ok and doc.undo().ok, "restore deleted order")
	check(doc.all_records()[1].id == "lamp:1", "restore exact order")
	for invalid in [
		{"id": "bad", "kind": "lamp", "transform": {"position": [NAN, 0, 0]}},
		{"id": "bad", "kind": "lamp", "transform": {"scale": [1, 0, 1]}},
		{"id": "bad", "kind": "lamp", "transform": {"scale": [-1, 1, 1]}},
		{"id": "bad", "kind": "lamp", "transform": {"rotation": ["0", 0, 0]}},
		{"id": "bad", "kind": "lamp", "source": Node.new()},
		{"id": "", "kind": "lamp"}, {"id": "bad", "kind": 7}
	]:
		check(not Document.validate_record(invalid).ok, "invalid record blocked")
		if invalid.get("source") is Node: invalid.source.free()
	var snapshot := doc.to_dictionary()
	snapshot.metadata = {"version": "original"}
	snapshot.custom_header = {"preserve": true}
	check(doc.load_document(snapshot).ok, "load document")
	check(not doc.can_undo() and not doc.can_redo(), "load resets history")
	check(doc.to_dictionary().custom_header.preserve, "opaque header retained")
	var bad := snapshot.duplicate(true)
	bad.objects.append(bad.objects[0].duplicate(true))
	check(not doc.load_document(bad).ok, "load duplicate rejected atomically")
	check(doc.object_count() == 3, "invalid load keeps current map")
	bad = snapshot.duplicate(true)
	bad.schema_version = 999
	check(not doc.load_document(bad).ok, "unknown schema rejected")
	var encoded := JSON.stringify(doc.to_dictionary())
	var parsed: Dictionary = JSON.parse_string(encoded)
	check(Document.validate_document(parsed).ok, "JSON round trip")
	var signal_count := [0]
	doc.changed.connect(func(): signal_count[0] += 1)
	check(doc.update_record("house:7", {}).ok and signal_count[0] == 0, "no-op update emits no change")
	check(doc.update_record("house:7", {"custom": {"texture": "different"}}).ok and signal_count[0] == 1, "change signal")
	var zero_history := Document.new(0)
	check(zero_history.add_record({"id": "1", "kind": "lamp"}).ok and not zero_history.can_undo(), "history can be disabled")
	zero_history.update_record("1", {"transform": {"rotation": [0, 1.4, 0], "scale": [2, 3, 4]}})
	check(zero_history.update_record("1", {"transform": {"position": [7, 8, 9]}}).ok, "partial transform patch")
	check(zero_history.get_record("1").transform.rotation == [0, 1.4, 0] and zero_history.get_record("1").transform.scale == [2, 3, 4], "moving preserves rotation and scale")
	var before_invalid: Dictionary = zero_history.to_dictionary()
	check(not zero_history.update_record("1", {"transform": "invalid"}).ok and zero_history.to_dictionary() == before_invalid, "bad transform patch atomic")
	print("map_document: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
