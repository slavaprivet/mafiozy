extends SceneTree
const Persistence = preload("res://scripts/map_editor/editor_persistence.gd")
const Document = preload("res://scripts/map_editor/map_document.gd")
const Ground = preload("C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_ground_candidate/ground_document.gd")
class EditorFixture extends Node:
	var active := true
	var document: RefCounted
	var _baseline: Dictionary
class AtomicFixture extends RefCounted:
	var received: Array = []
	var busy := false
	var committed := false
	func busy_status() -> Dictionary: return {"busy": busy, "committed": committed}
	func install_bundle(bundle: Dictionary) -> Dictionary:
		received.append(bundle.duplicate(true))
		return {"ok": true}
	func retry_finalize() -> Dictionary:
		busy = false
		return {"ok": true}
	func retry_rollback() -> Dictionary:
		busy = false
		return {"ok": false, "rollback_ok": true}
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	var editor := EditorFixture.new()
	root.add_child(editor)
	editor._baseline = {"schema_version": 1, "map_id": "persistence", "metadata": {}, "objects": [{"id": "house", "kind": "building", "model": "house", "transform": {"position": [0, 0, 0], "rotation": [0, 0, 0], "scale": [1, 1, 1]}}]}
	editor.document = Document.new()
	editor.document.load_document(editor._baseline)
	editor.document.update_record("house", {"transform": {"position": [5, 0, 9]}})
	var ground := Ground.new()
	var masks := {}
	for name in Ground.MASK_NAMES: masks[name] = [[0]]
	ground.setup_baseline({"rows": 1, "cols": 1, "startRow": 0, "startCol": 0, "cellSize": 4.1, "grid": [[0]], "masks": masks})
	var atomic := AtomicFixture.new()
	var ready := [true]
	var clipboard := [""]
	var ready_callback := func() -> bool: return ready[0]
	var io := {"read": func() -> String: return clipboard[0], "write": func(text: String) -> bool: clipboard[0] = text; return true}
	var token := str(Time.get_ticks_usec())
	var save_path := "user://maps/tests/persistence-" + token + ".json"
	var export_path := "user://maps/tests/export-" + token + ".json"
	var persistence := Persistence.new()
	var hash := "a".repeat(64)
	check(persistence.configure(editor, ground, atomic, {"house": [hash]}, {hash: true}, ready_callback, io, save_path, export_path).ok, "unified persistence configured")
	check(persistence.handle_action("save").ok and FileAccess.file_exists(save_path), "combined file save")
	check(persistence.handle_action("load").ok and atomic.received.size() == 1, "load only delegates to atomic owner")
	check(not atomic.received[0].ground_patch.is_empty() and atomic.received[0].schema == "mafiozi.godot.map-bundle/v1", "file includes ground and source object patch")
	check(persistence.handle_action("export").ok and FileAccess.file_exists(export_path) and not clipboard[0].is_empty(), "publish file and text export")
	check(persistence.handle_action("import").ok and atomic.received.size() == 2, "text import delegates same atomic owner")
	clipboard[0] = "invalid JSON"
	check(not persistence.handle_action("import").ok and atomic.received.size() == 2, "bad import never touches scene")
	ready[0] = false
	check(not persistence.handle_action("save").ok, "unfinished transaction blocks file action")
	atomic.busy = true
	check(persistence.handle_action("retry_pending").ok and not atomic.busy, "precommit rollback acknowledged")
	atomic.busy = true
	atomic.committed = true
	check(persistence.handle_action("retry_pending").ok and not atomic.busy, "postcommit cleanup acknowledged")
	editor.active = false
	check(not persistence.handle_action("load").ok, "play mode cannot import map")
	for owned_path: String in [save_path, export_path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(owned_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(owned_path + suffix))
	editor.free()
	for failure: String in failures: push_error(failure)
	print("editor persistence: ", checks, " checks, failures=", failures.size(), "; file/UI routing only, atomic scene proof separate")
	quit(0 if failures.is_empty() else 1)
