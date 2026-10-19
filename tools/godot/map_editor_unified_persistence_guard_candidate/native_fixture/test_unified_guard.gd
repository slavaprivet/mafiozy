extends SceneTree
## Opt-in native negative fixture; no game main, assets, or GPU acceptance.
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Workspace = preload("res://scripts/map_editor/editor_workspace.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Brush = preload("res://scripts/map_editor/ground_brush.gd")
const GroundPanel = preload("res://scripts/map_editor/ground_panel.gd")
const Persistence = preload("res://scripts/map_editor/editor_persistence.gd")
const BundleStore = preload("res://scripts/map_editor/map_bundle_store.gd")

class BadGroundPanel extends CanvasLayer:
	signal mode_requested(mode: String)
	func set_active(_value: bool) -> void: pass
	func set_status(_message: String) -> void: pass
	func input_guard(_event: InputEvent) -> Dictionary: return {}

class RendererStub extends Node:
	func finalize(_committed: bool = false) -> Dictionary: return {"ok": true}

class GroundStub extends RefCounted:
	func export_patch() -> Dictionary: return {}
	func validate_patch(_patch: Dictionary) -> Dictionary: return {"ok": true}

class AtomicStub extends RefCounted:
	func install_bundle(_bundle: Dictionary) -> Dictionary: return {"ok": false, "error": "Fixture does not exercise import"}
	func busy_status() -> Dictionary: return {"busy": false}

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1024, 768)
	var world := Node3D.new()
	root.add_child(world)
	var house := MeshInstance3D.new()
	house.mesh = BoxMesh.new()
	world.add_child(house)
	var rail := MeshInstance3D.new()
	rail.mesh = BoxMesh.new()
	rail.position = Vector3(10, 0, 0)
	world.add_child(rail)
	var registry := Registry.new()
	check(registry.register_object("house", house, {"kind": "building", "model": "house"}).ok, "editable source registered")
	check(registry.register_object("rail", rail, {"kind": "rail", "model": "rail"}, [], false).ok, "protected source registered")
	var baseline: Dictionary = registry.source_document("unified-guard-fixture")
	var camera := Camera3D.new()
	world.add_child(camera)
	var editor := Controller.new()
	world.add_child(editor)
	var begin := func() -> Dictionary: return {"ok": true}
	var end := func(_document: Dictionary) -> Dictionary: return {"ok": true}
	check(editor.setup(registry, baseline, camera, begin, end).ok, "controller configured")
	var suffix := str(Time.get_ticks_usec())
	editor._save_path = "user://maps/tests/legacy-" + suffix + ".json"
	var brush := Brush.new()
	var renderer := RendererStub.new()
	world.add_child(renderer)
	var workspace := Workspace.new()
	world.add_child(workspace)
	var bad_panel := BadGroundPanel.new()
	world.add_child(bad_panel)
	var ready := func() -> bool: return true
	var dummy_persistence := func(_action: String, _payload: Dictionary) -> Dictionary: return {"ok": true}
	check(not workspace.setup(editor, brush, bad_panel, renderer, dummy_persistence, ready).ok, "incomplete panel setup refused")
	check(workspace.editor == null and not editor._unified_persistence_only, "failed setup leaves one-way handoff and workspace state untouched")
	check(editor.enter_editor().ok, "legacy route still operable after failed setup")
	var old_save: Dictionary = editor.handle_action("save")
	check(old_save.ok and FileAccess.file_exists(editor._save_path), "pre-handoff legacy object-only route remains available")
	var old_bytes: String = FileAccess.get_file_as_string(editor._save_path)
	var protected_tiny: Dictionary = editor.document.to_dictionary()
	for row: Dictionary in protected_tiny.objects:
		if row.id == "rail":
			row.transform.position[0] += 0.0000001
			break
	check(not editor.prepare_install_document(protected_tiny).ok, "sub-epsilon protected import refused")
	var ordinary: Dictionary = editor.document.to_dictionary()
	for row: Dictionary in ordinary.objects:
		if row.id == "house":
			row.transform.position[0] += 1.0
			break
	check(editor.prepare_install_document(ordinary).ok, "ordinary source edit remains admissible")
	var good_panel := GroundPanel.new()
	world.add_child(good_panel)
	var ground := GroundStub.new()
	var atomic := AtomicStub.new()
	var persistence := Persistence.new()
	var combined_path := "user://maps/tests/combined-" + suffix + ".json"
	var read_text := func() -> String: return ""
	var write_text := func(_text: String) -> bool: return true
	check(persistence.configure(editor, ground, atomic, {"house": [], "rail": []}, {}, ready, {"read": read_text, "write": write_text}, combined_path, combined_path.trim_suffix(".json") + "-published.json").ok, "combined persistence owner configured")
	var calls: Array[String] = []
	var combined_callback := func(action: String, payload: Dictionary) -> Dictionary:
		calls.append(action)
		return persistence.handle_action(action, payload)
	check(workspace.setup(editor, brush, good_panel, renderer, combined_callback, ready).ok, "complete workspace setup succeeds")
	check(editor._unified_persistence_only and workspace.editor == editor, "one-way unified handoff established")
	for action: String in ["save", "load", "import", "export"]:
		check(not editor.handle_action(action).ok, "direct controller " + action + " refused after handoff")
	check(FileAccess.get_file_as_string(editor._save_path) == old_bytes, "direct file refusals preserve legacy file bytes")
	check(not editor.install_document(editor.document.to_dictionary()).ok, "direct object-only install refused")
	var patch: Dictionary = editor.get_versioned_patch()
	check(patch.ok and not editor.install_versioned_patch(patch.patch).ok, "direct versioned object-only install refused")
	editor.selected_id = "house"
	var before_position: Vector3 = house.global_position
	check(workspace.handle_action("move", {"delta": [2, 0, 0]}).ok and house.global_position != before_position, "ordinary object action remains usable")
	var combined_save: Dictionary = workspace.handle_action("save", {"label": "Combined fixture"})
	check(combined_save.ok and calls == ["save"], "workspace invokes configured combined callback")
	var loaded: Dictionary = BundleStore.load_bundle(baseline, {"house": [], "rail": []}, {}, combined_path, ground.validate_patch)
	check(loaded.ok and loaded.bundle.has("ground_patch") and loaded.bundle.has("object_patch"), "combined file contains both domains")
	world.free()
	for failure: String in failures: push_error(failure)
	print("UNIFIED_GUARD_NATIVE_QA ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "syntheticHost": true, "productionWired": false, "gpu": false}))
	quit(0 if failures.is_empty() else 1)
