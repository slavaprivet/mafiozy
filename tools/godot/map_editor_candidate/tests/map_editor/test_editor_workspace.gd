extends SceneTree
const Workspace = preload("res://scripts/map_editor/editor_workspace.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Brush = preload("C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_ground_candidate/ground_brush.gd")
const GroundPanel = preload("C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_ground_candidate/ground_panel.gd")
const Ground = preload("C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_ground_candidate/ground_document.gd")
class RendererStub extends Node:
	var allow_finalize := true
	var finalized := 0
	func finalize(_committed: bool) -> Dictionary:
		finalized += 1
		return {"ok": allow_finalize, "error": "Cleanup pending", "committed": true}
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
func mouse(point: Vector2, button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	return event
func press_button(panel: CanvasLayer, text: String) -> bool:
	for button: Node in panel._root.find_children("*", "Button", true, false):
		if button.text == text:
			button.pressed.emit()
			return true
	return false
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var house := MeshInstance3D.new()
	house.mesh = BoxMesh.new()
	world.add_child(house)
	var index := Registry.new()
	index.register_object("house", house, {"kind": "building", "model": "house"})
	var camera := Camera3D.new()
	world.add_child(camera)
	var editor := Controller.new()
	world.add_child(editor)
	var begin := func() -> Dictionary: return {"ok": true}
	var end := func(_doc: Dictionary) -> Dictionary: return {"ok": true}
	check(editor.setup(index, index.source_document("workspace"), camera, begin, end).ok, "editor configured")
	var masks := {}
	for name in Ground.MASK_NAMES: masks[name] = [[0, 0], [0, 0]]
	var ground := Ground.new()
	ground.setup_baseline({"rows": 2, "cols": 2, "startRow": 0, "startCol": 0, "cellSize": 4.1, "grid": [[0, 0], [0, 0]], "masks": masks})
	var brush := Brush.new()
	var callback := func(_delta: Dictionary) -> Dictionary: return {"ok": true}
	brush.setup(ground, {"preview_chunks": callback, "physical_apply": callback, "nav_invalidate": callback, "rollback": callback})
	var panel := GroundPanel.new()
	world.add_child(panel)
	var renderer := RendererStub.new()
	world.add_child(renderer)
	var workspace := Workspace.new()
	world.add_child(workspace)
	var persisted: Array[String] = []
	var persist := func(action: String, _payload: Dictionary) -> Dictionary:
		persisted.append(action)
		return {"ok": true}
	var ready := [true]
	var ready_callback := func() -> bool: return ready[0]
	check(not workspace.setup(editor, brush, panel, renderer, Callable(), ready_callback).ok, "combined persistence mandatory")
	check(workspace.setup(editor, brush, panel, renderer, persist, ready_callback).ok, "workspace configured")
	check(not brush.active and not panel._active, "inactive workspace no ground input")
	check(workspace.handle_input(key(KEY_K)) and editor.active and editor.panel._active, "K activates object editor")
	check(press_button(editor.panel, "Земля и дороги"), "actual ground mode button exists")
	check(workspace.mode == "ground" and brush.active and panel._active and not editor.panel._active, "mode signal switches actual panels")
	workspace.handle_action("camera_top")
	editor.camera.position = Vector3(2.05, 20, 2.05)
	editor.camera.rotation = Vector3(-PI / 2, 0, 0)
	editor.camera.size = 10
	await process_frame
	var point := editor.camera.unproject_position(Vector3(2.05, 0, 2.05))
	check(workspace.handle_input(mouse(point, MOUSE_BUTTON_RIGHT, true)) and workspace.handle_input(mouse(point, MOUSE_BUTTON_RIGHT, false)), "ground RMB consumed as camera input")
	check(ground.cell_state(0, 0).tile == 0 and house.visible and editor.document.has_record("house"), "ground RMB never deletes objects")
	workspace.handle_action("ground_tile", {"tile": 8})
	workspace.handle_input(mouse(point, MOUSE_BUTTON_LEFT, true))
	workspace.handle_input(mouse(point, MOUSE_BUTTON_LEFT, false))
	check(ground.cell_state(0, 0).tile == 8 and renderer.finalized == 1, "workspace paint finalization")
	check(workspace.handle_action("ground_undo").ok and renderer.finalized == 2 and ground.cell_state(0, 0).tile == 0, "workspace undo finalization")
	check(workspace.handle_action("ground_redo").ok and renderer.finalized == 3 and ground.cell_state(0, 0).tile == 8, "workspace redo finalization")
	panel.action_requested.emit("save", {})
	editor.panel.action_requested.emit("export", {})
	check(persisted == ["save", "export"], "both panels route to one joint persistence owner")
	panel._radius.get_line_edit().grab_focus()
	check(not workspace.handle_input(key(KEY_K)) and editor.active, "ground text K does not exit")
	panel._radius.get_line_edit().release_focus()
	ready[0] = false
	check(workspace.handle_input(key(KEY_K)) and editor.active, "pending shared transaction prevents play")
	ready[0] = true
	renderer.allow_finalize = false
	workspace.handle_action("ground_undo")
	check(workspace._cleanup_blocked and not brush.active and editor.active, "cleanup failure keeps editor paused")
	check(not workspace.handle_action("save").ok and workspace.handle_input(key(KEY_K)) and editor.active, "cleanup failure prevents save and exit")
	renderer.allow_finalize = true
	check(workspace.retry_finalize().ok and brush.active, "trusted cleanup retry re-enables editing")
	brush._nav_invalidate = func(_delta: Dictionary) -> Dictionary: return {"ok": false}
	brush._rollback = func(_delta: Dictionary) -> Dictionary: return {"ok": false}
	check(not workspace.handle_action("ground_redo").ok and workspace._recovery_required and not brush.active, "failed rollback cannot reactivate brush")
	check(workspace.handle_input(key(KEY_K)) and editor.active and not workspace.retry_finalize().ok, "rollback failure requires scene recovery, not cleanup retry")
	check(not workspace.restore_session(func() -> bool: return false).ok, "unconfirmed owner recovery denied")
	brush._nav_invalidate = callback
	brush._rollback = callback
	check(workspace.restore_session(func() -> bool: return true).ok and brush.active, "trusted scene recovery re-enables editor")
	check(press_button(panel, "Объекты"), "actual object mode button exists")
	check(workspace.mode == "objects" and not brush.active and editor.panel._active, "ground panel returns to objects")
	check(workspace.handle_input(key(KEY_K)) and not editor.active and not panel._active, "K exits both panels")
	world.free()
	for failure: String in failures: push_error(failure)
	print("editor workspace: ", checks, " checks, failures=", failures.size(), "; synthetic input/UI, not main/LIVE acceptance")
	quit(0 if failures.is_empty() else 1)
