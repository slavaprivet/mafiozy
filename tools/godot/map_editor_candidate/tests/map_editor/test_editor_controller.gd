extends SceneTree

const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
var failures: Array[String] = []
var begin_ok := true
var end_ok := true
var begin_calls := 0
var end_calls := 0
var saved_exit: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func begin_gate() -> Dictionary:
	begin_calls += 1
	return {"ok": begin_ok}

func end_gate(document: Dictionary) -> Dictionary:
	end_calls += 1
	saved_exit = document.duplicate(true)
	return {"ok": end_ok}

func key(code: int, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	return event

func mouse(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	return event

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var house := Node3D.new()
	world.add_child(house)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	house.add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 5
	body.collision_mask = 7
	world.add_child(body)
	body.position = Vector3(0, -1, 0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	var protected := Node3D.new()
	world.add_child(protected)
	protected.position = Vector3(30, 0, 0)
	var registry := Registry.new()
	check(registry.register_object("house", house, {"kind": "building", "label": "Дом", "source": {"id": 12}}, [body]).ok, "House identity registered with detached collider")
	check(registry.register_object("protected", protected, {"kind": "building", "source": {"id": 99}}, [], false).ok, "Protected identity registered")
	var source := registry.source_document("test-controller-map")
	var game := Camera3D.new()
	world.add_child(game)
	game.position = Vector3(0, 0, 10)
	game.make_current()
	var original_camera := game.global_transform
	var controller := Controller.new()
	world.add_child(controller)
	check(controller.setup(registry, source, game, begin_gate, end_gate).ok, "Controller setup")
	check(not controller.setup(registry, source, game, begin_gate, end_gate).ok, "Duplicate setup rejected")
	await process_frame
	check(not controller.handle_input(key(KEY_W)), "Inactive gameplay input untouched")
	check(not controller.handle_action("delete").ok, "Inactive mutations rejected")
	begin_ok = false
	check(controller.handle_input(key(KEY_K)) and not controller.active and game.current, "K failed begin gate keeps game camera")
	begin_ok = true
	check(not controller.handle_input(key(KEY_K, true)) and not controller.active, "Echo K does not toggle")
	check(controller.handle_input(key(KEY_K)) and controller.active and controller.camera.current, "K enters editor")
	var calls := begin_calls
	check(controller.enter_editor().ok and begin_calls == calls, "Repeated enter does not reacquire lease")
	controller.panel._search.grab_focus()
	check(not controller.handle_input(key(KEY_K)) and controller.active, "Typing K in search does not close editor")
	var pose: Transform3D = controller.camera.global_transform
	check(not controller.handle_input(key(KEY_W)), "Search receives W")
	controller._process(0.2)
	check(controller.camera.global_transform.is_equal_approx(pose), "Search typing cannot move camera")
	controller.panel._search.release_focus()
	var center := root.get_visible_rect().size / 2.0
	check(controller.select_at(center) == "house", "Ray picking finds house visual")
	controller.handle_input(mouse(center, true))
	controller.handle_input(mouse(center, false))
	check(not controller.document.has_record("house") and not house.visible and body.collision_layer == 0 and body.collision_mask == 0, "Short RMB deletes visual and detached collision")
	check(controller.handle_action("undo").ok and house.visible and body.collision_layer == 5 and body.collision_mask == 7, "Undo restores visual and collision layers")
	controller.handle_input(mouse(center, true))
	var motion := InputEventMouseMotion.new()
	motion.position = center + Vector2(10, 0)
	motion.relative = Vector2(10, 0)
	controller.handle_input(motion)
	controller.handle_input(mouse(center + Vector2(10, 0), false))
	check(controller.document.has_record("house"), "RMB drag never deletes")
	controller.handle_input(mouse(center, true))
	controller._right_time -= 501
	controller.handle_input(mouse(center, false))
	check(controller.document.has_record("house"), "Long RMB hold never deletes")
	controller.handle_input(mouse(center, true))
	controller._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	controller.handle_input(mouse(center, false))
	check(controller.document.has_record("house"), "Focus loss cancels deletion")
	controller.selected_id = "house"
	check(controller.handle_action("move", {"delta": [2, 0, 3]}).ok, "Move action succeeds")
	check(house.position.is_equal_approx(Vector3(2, 0, 3)) and body.position.is_equal_approx(Vector3(2, -1, 3)), "Detached collider follows exact movement")
	check(controller.handle_action("rotate", {"degrees": 15.0}).ok and is_equal_approx(house.rotation.y, deg_to_rad(15.0)), "Rotation action")
	check(controller.handle_action("undo").ok and is_zero_approx(house.rotation.y), "Rotation undo")
	check(controller.handle_action("redo").ok and is_equal_approx(house.rotation.y, deg_to_rad(15.0)), "Rotation redo")
	var trusted := controller.document.to_dictionary()
	controller.selected_id = "protected"
	check(not controller.handle_action("move", {"delta": [1, 0, 0]}).ok and controller.document.to_dictionary() == trusted, "Protected transform mutation rejected before history change")
	var tampered := trusted.duplicate(true)
	tampered.objects[0].source.id = 999
	check(not controller.install_document(tampered).ok and controller.document.to_dictionary() == trusted, "Imported source identity forgery rejected atomically")
	controller._save_path = "user://maps/tests/controller-%d.json" % Time.get_ticks_usec()
	check(controller.handle_action("save").ok, "Save test path")
	var normalized_save: Dictionary = Store.load_document(controller._save_path)
	check(normalized_save.ok, "Saved JSON readback")
	controller.selected_id = "house"
	check(controller.handle_action("move", {"delta": [7, 0, 0]}).ok, "Post-save movement")
	var load_result: Dictionary = controller.handle_action("load")
	if not load_result.ok: print("LOAD REVIEW: ", load_result)
	check(load_result.ok and Controller._json_equal(controller.document.to_dictionary(), normalized_save.document) and house.position.is_equal_approx(Vector3(2, 0, 3)), "Load restores saved native scene and admitted JSON representation")
	check(controller.document.get_record("house").source == trusted.objects[0].source, "Load retains exact trusted source descriptor instead of JSON numeric types")
	var patch: Dictionary = controller.get_versioned_patch()
	check(patch.ok and patch.patch.modified.size() == 1, "Loaded JSON derives immutable-baseline patch")
	check(controller.install_versioned_patch(patch.patch).ok, "Versioned patch recreates current map")
	var bad_patch: Dictionary = patch.patch.duplicate(true)
	bad_patch.baseline_sha256 = "0".repeat(64)
	check(not controller.install_versioned_patch(bad_patch).ok, "Wrong-baseline patch rejected")
	check(controller.handle_action("camera_top").ok and controller.camera.mode == "top", "UI top action")
	check(controller.handle_action("camera_fly").ok and controller.camera.mode == "fly", "UI fly action")
	end_ok = false
	check(not controller.exit_editor().ok and controller.active and controller.camera.current, "Failed end gate keeps editor lease/camera")
	end_ok = true
	check(controller.handle_input(key(KEY_K)) and not controller.active and game.current, "K exits only after successful rebuild gate")
	check(game.global_transform.is_equal_approx(original_camera) and Controller._json_equal(saved_exit, normalized_save.document), "Exit exact camera restoration and semantically exact JSON document handoff")
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = ProjectSettings.globalize_path(controller._save_path + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	world.queue_free()
	if failures.is_empty():
		print("PASS map editor controller: K/text gates, RMB click/drag/hold/focus, visual+collision move/delete/undo/redo, source guards, test-path save/load, exit rebuild gating")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
