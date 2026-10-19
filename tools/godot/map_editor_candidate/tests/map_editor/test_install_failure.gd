extends SceneTree
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
class RejectRegistry extends Registry:
	var reject_apply := false
	func apply_document(value: Dictionary, dry_run: bool = false) -> Dictionary:
		if reject_apply and not dry_run: return {"ok": false, "error": "Injected second admission failure"}
		return super.apply_document(value, dry_run)
var failures: Array[String] = []
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var house := MeshInstance3D.new()
	house.mesh = BoxMesh.new()
	world.add_child(house)
	var index := RejectRegistry.new()
	index.register_object("house", house, {"kind": "building", "model": "house", "source": {"owner": 7}})
	var camera := Camera3D.new()
	world.add_child(camera)
	var editor := Controller.new()
	world.add_child(editor)
	var gate := func() -> Dictionary: return {"ok": true}
	var end_gate := func(_doc: Dictionary) -> Dictionary: return {"ok": true}
	check(editor.setup(index, index.source_document("install-test"), camera, gate, end_gate).ok, "setup")
	check(editor.enter_editor().ok, "enter")
	editor.selected_id = "house"
	check(editor.handle_action("move", {"delta": [3, 0, 0]}).ok, "prior history")
	var before := editor.document.to_dictionary()
	var before_frame := house.global_transform
	var before_undo := editor.document._undo.duplicate(true)
	var before_redo := editor.document._redo.duplicate(true)
	var notifications := [0]
	editor.document.changed.connect(func(): notifications[0] += 1)
	var imported: Dictionary = before.duplicate(true)
	imported.objects[0].transform.position = [20, 0, 0]
	var clone: Dictionary = imported.objects[0].duplicate(true)
	clone.id = "editor:fresh"
	clone.template_id = "house"
	imported.objects.append(clone)
	index.reject_apply = true
	check(not editor.install_document(imported).ok, "second scene admission rejects")
	check(editor.document.to_dictionary() == before, "old model exact")
	check(editor.document._undo == before_undo and editor.document._redo == before_redo, "old history exact")
	check(house.global_transform == before_frame and house.visible, "old scene unchanged")
	check(not index.has_object("editor:fresh"), "staged clone removed")
	check(notifications[0] == 0, "no intermediate model notification")
	index.reject_apply = false
	var consistent := [true]
	editor.document.changed.connect(func(): consistent[0] = consistent[0] and house.global_position.x == editor.document.get_record("house").transform.position[0])
	check(editor.install_document(imported).ok, "successful replacement")
	check(consistent[0] and notifications[0] == 1, "observers see scene and model agree")
	check(index.has_object("editor:fresh") and not editor.document.can_undo(), "fresh clone and replacement history")
	world.free()
	for failure: String in failures: push_error(failure)
	print("map install failure: ", checks, " checks, failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
