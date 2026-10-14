extends SceneTree

const EditorCamera = preload("res://scripts/map_editor/editor_camera.gd")
const EditorPanel = preload("res://scripts/map_editor/editor_panel.gd")
var failures: Array[String] = []
var actions: Array = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label:
		return node
	for child in node.get_children():
		var found := find_button(child, label)
		if found != null:
			return found
	return null

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var game := Camera3D.new()
	world.add_child(game)
	game.position = Vector3(3, 4, 5)
	game.rotation = Vector3(-0.2, 0.6, 0.0)
	game.fov = 63.0
	game.near = 0.13
	game.far = 850.0
	game.make_current()
	var original := game.global_transform
	var previous_mouse := Input.mouse_mode
	var camera := EditorCamera.new()
	world.add_child(camera)
	camera.activate_from(game)
	check(camera.active and camera.current, "Editor camera activates")
	check(camera.global_transform.is_equal_approx(original), "Editor starts at game-camera pose")
	check(is_equal_approx(camera.fov, game.fov) and is_equal_approx(camera.near, game.near) and is_equal_approx(camera.far, game.far), "Editor copies original projection parameters")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_W
	press.pressed = true
	check(camera.input_handle(press), "Fly key consumed")
	camera.process_motion(0.1)
	check(not camera.global_transform.is_equal_approx(original), "Fly movement works")
	check(game.global_transform.is_equal_approx(original), "Gameplay camera never moved")
	camera.clear_motion()
	var flying_pose := camera.global_transform
	camera.set_view("top")
	check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.rotation.x, -PI / 2.0), "Top projection")
	camera.set_view("fly")
	check(camera.global_transform.is_equal_approx(flying_pose), "Fly view restores previous pose")
	check(is_equal_approx(camera.far, game.far), "Fly far restored after top view")
	camera.input_handle(press)
	camera.focus_lost()
	camera.process_motion(1.0)
	check(camera.global_transform.is_equal_approx(flying_pose), "Focus loss stops stuck movement")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	camera.input_handle(right)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(1, 1)
	camera.input_handle(motion)
	check(camera.global_transform.is_equal_approx(flying_pose), "Short RMB click does not turn camera")
	motion.relative = Vector2(10, 0)
	check(camera.input_handle(motion), "RMB drag turns camera")
	camera.deactivate_to(game)
	check(not camera.active and game.current, "Game camera restored current")
	check(game.global_transform.is_equal_approx(original), "Original camera exact restoration")
	check(Input.mouse_mode == previous_mouse, "Mouse mode restored")
	var inactive_pose := camera.global_transform
	check(not camera.input_handle(press), "Inactive camera does not consume input")
	camera.process_motion(1.0)
	check(camera.global_transform.is_equal_approx(inactive_pose), "Inactive camera does not move")
	var panel := EditorPanel.new()
	root.add_child(panel)
	panel.action_requested.connect(func(action: String, payload: Dictionary) -> void: actions.append({"action": action, "payload": payload}))
	panel.set_active(true)
	panel.set_catalog([
		{"id": "lamp", "label": "Фонарь", "category": "Декор", "available": true},
		{"id": "house", "label": "Дом", "category": "Здания", "available": false}
	])
	check(panel._catalog_list.item_count == 2, "Catalog displayed")
	check(panel._catalog_list.is_item_disabled(1), "Unavailable assets visibly disabled")
	panel._catalog_selected(0)
	panel._search.text = "ф"
	panel._refresh()
	check(panel._selected_id == "lamp", "Visible catalog selection survives filtering")
	find_button(panel, "Добавить выбранный объект").pressed.emit()
	check(actions.back() == {"action": "add", "payload": {"catalog_id": "lamp"}}, "Add action carries catalog ID")
	panel._move_step.value = 2.5
	find_button(panel, "X+").pressed.emit()
	check(actions.back() == {"action": "move", "payload": {"delta": [2.5, 0.0, 0.0]}}, "Move action uses numeric chosen step")
	find_button(panel, "Экспорт JSON").pressed.emit()
	check(actions.back().action == "export", "Export action")
	find_button(panel, "Импорт JSON").pressed.emit()
	check(actions.back().action == "import", "Import action")
	panel._search.text = "фон"
	panel._refresh()
	check(panel._catalog_list.item_count == 1, "Russian search works")
	panel.set_selection({"id": "house-12", "label": "Дом"})
	check(panel._selection.text == "Выбрано: Дом", "Selection Russian label")
	panel.set_status("Сохранено")
	check(panel._status.text == "Сохранено", "Status visible")
	panel._search.text = ""
	var many: Array = []
	for index in range(205):
		many.append({"id": "item-%d" % index, "label": "Объект %d" % index, "category": "Тест"})
	panel.set_catalog(many)
	check(panel._catalog_list.item_count == 160 and "205" in panel._result_count.text, "Large catalog bounded with total results shown")
	check(panel._root.size.y <= root.get_visible_rect().size.y, "Panel stays within viewport height")
	panel.set_active(false)
	check(not panel._root.visible and not panel.is_pointer_over_panel(Vector2(20, 20)), "Hidden panel never blocks play input")
	world.queue_free()
	panel.queue_free()
	if failures.is_empty():
		print("PASS map editor controls: projection, fly/top, exact restoration, focus loss, RMB threshold, Russian catalog/UI, move/export/import payloads, bounded catalog, responsive height, inactive input")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

