extends SceneTree
const Ground = preload("res://ground_document.gd")
const Brush = preload("res://ground_brush.gd")
const GroundPanel = preload("res://ground_panel.gd")
var checks := 0
var failures := 0
var events: Array = []
var preview_calls: Array = []
var nav_ok := true
var physics_ok := true
var preview_ok := true
var forced_text := false
var rollback_calls := 0
var latest_delta: Dictionary = {}
var panel: CanvasLayer

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func preview(plan: Dictionary) -> Dictionary:
	preview_calls.append(plan)
	return {"ok": preview_ok}

func physical(delta: Dictionary) -> Dictionary:
	events.append("physics")
	latest_delta = delta
	return {"ok": physics_ok}

func nav(_delta: Dictionary) -> Dictionary:
	events.append("nav")
	return {"ok": nav_ok}

func rollback(_delta: Dictionary) -> Dictionary:
	events.append("rollback")
	rollback_calls += 1
	return {"ok": true}

func guard(event: InputEvent) -> Dictionary:
	var result: Dictionary = panel.input_guard(event)
	result.text_focused = forced_text or result.text_focused
	return result

func mouse(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event

func motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event

func cell_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * 4.1, 0, (cell.y + 0.5) * 4.1)

func centre_camera(camera: Camera3D, cell: Vector2i) -> void:
	camera.global_position = cell_world(cell) + Vector3(0, 200, 0)
	camera.rotation = Vector3(-PI / 2, 0, 0)

func click(brush: RefCounted, camera: Camera3D, point: Vector2) -> void:
	check(brush.handle_input(mouse(point, true), camera, guard), "LMB press consumed")
	check(brush.handle_input(mouse(point, false), camera, guard), "LMB release consumed")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var source_path := "C:/Users/Слава/Desktop/Мафиози/assets/maps/city_rebuild_v1/topology_for_placement.json"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var ground := Ground.new()
	check(ground.setup_baseline(source).ok, "actual authored200x180 fullgrid")
	var dry := Vector2i(-1, -1)
	var water := Vector2i(-1, -1)
	var locked := Vector2i(-1, -1)
	var line_start := Vector2i(-1, -1)
	for row in 200:
		for col in 180:
			if ground.is_editable(row, col):
				if ground.cell_state(row, col).tile != 16 and dry.x == -1: dry = Vector2i(col, row)
				if ground.cell_state(row, col).tile == 16 and water.x == -1: water = Vector2i(col, row)
				if line_start.x == -1 and col <= 160:
					var valid := true
					for offset in 20:
						if not ground.is_editable(row, col + offset): valid = false
					if valid: line_start = Vector2i(col, row)
			elif locked.x == -1: locked = Vector2i(col, row)
	check(dry.x >= 0 and water.x >= 0 and locked.x >= 0 and line_start.x >= 0, "actual sample dry water protected line found")
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 160
	camera.far = 1000
	world.add_child(camera)
	camera.make_current()
	panel = GroundPanel.new()
	world.add_child(panel)
	panel.set_active(true)
	await process_frame
	var actions: Array = []
	panel.action_requested.connect(func(action: String, payload: Dictionary): actions.append({"action": action, "payload": payload}))
	panel._brush_selected(5)
	check(actions.back() == {"action": "ground_layer", "payload": {"layer": "dirt"}}, "Russian dirt UI distinct namedlayer")
	panel._brush_selected(4)
	check(actions.back() == {"action": "ground_tile", "payload": {"tile": 16}}, "water UI uses16")
	panel._radius.value = 3
	check(actions.back() == {"action": "ground_radius", "payload": {"radius": 3}}, "brush radius signal")
	var brush := Brush.new()
	var commit_notifications := [0]
	brush.committed.connect(func(_result: Dictionary): commit_notifications[0] += 1)
	check(not brush.setup(ground, {}).ok, "missing hosthooks refused")
	check(brush.setup(ground, {"preview_chunks": preview, "physical_apply": physical, "nav_invalidate": nav, "rollback": rollback}).ok, "all hosthooks installed")
	check(not brush.handle_input(mouse(Vector2(640, 360), true), camera, guard), "inactive brush no paint")
	brush.set_active(true)
	check(not brush.set_selected_tile(9 + 100).ok and not brush.set_named_layer("water").ok and not brush.set_radius(9).ok, "unsafe brushsettings refused")
	centre_camera(camera, dry)
	var point: Vector2 = camera.unproject_position(cell_world(dry))
	var picked: Dictionary = brush.pick_screen(point, camera)
	check(picked.ok and picked.row == dry.y and picked.col == dry.x, "actual camera ray to sourcegrid")
	var original := ground.cell_state(dry.y, dry.x, false)
	brush.set_selected_tile(8 if original.tile != 8 else 0)
	check(brush.handle_input(mouse(point, true), camera, guard) and brush.is_painting(), "press starts staged stroke")
	check(ground.cell_state(dry.y, dry.x, false) == original and events.is_empty(), "press changes preview only no physics")
	check(preview_calls.back().chunks.size() == 1 and preview_calls.back().chunks[0].cell_count <= 256, "singlecell singleboundedchunk preview")
	var calls_before := preview_calls.size()
	for iteration in 20: brush.handle_input(motion(point), camera, guard)
	check(preview_calls.size() == calls_before and brush.debug_cost().stroke_unique_cells == 1, "samepointer cell dedup no repeatedchunkrebuild")
	check(brush.handle_input(mouse(point, false), camera, guard) and not brush.is_painting(), "release commits single stroke")
	check(events == ["physics", "nav"] and ground.cell_state(dry.y, dry.x, false).tile != original.tile, "explicit physical then nav data commit")
	check(ground.original_source() == source, "immutable fullsource masks retained")
	check(commit_notifications[0] == 1, "stroke emits finalization only after model commit")
	check(brush.undo().ok and ground.cell_state(dry.y, dry.x, false) == original, "brush undo native cells")
	check(commit_notifications[0] == 2, "undo also releases staged renderer transaction")
	check(brush.redo().ok and ground.cell_state(dry.y, dry.x, false).tile != original.tile, "brush redo native cells")
	check(commit_notifications[0] == 3, "redo also releases staged renderer transaction")
	forced_text = true
	var before := ground.export_patch()
	check(not brush.handle_input(mouse(point, true), camera, guard) and ground.export_patch() == before, "focused text never paints")
	forced_text = false
	panel._radius.get_line_edit().grab_focus()
	check(panel.is_text_focused() and not brush.handle_input(mouse(point, true), camera, guard), "actual native textfocus never paints")
	panel._radius.get_line_edit().release_focus()
	check(not brush.handle_input(mouse(Vector2(30, 30), true), camera, guard) and ground.export_patch() == before, "UIhover never paints")
	check(not brush.handle_input(mouse(point, true), camera, Callable()), "missing UIguard refuses paint")
	brush.handle_input(mouse(point, true), camera, guard)
	brush.handle_input(motion(Vector2(30, 30)), camera, guard)
	check(not brush.is_painting() and ground.export_patch() == before and preview_calls.back().cancelled, "drag into UI cancels preview")
	brush.handle_input(mouse(point, true), camera, guard)
	brush.focus_lost()
	check(not brush.is_painting() and ground.export_patch() == before, "focusloss cancel")
	brush.handle_input(mouse(point, true), camera, guard)
	brush.set_active(false)
	check(not brush.is_painting() and ground.export_patch() == before, "editor exit cancels")
	brush.set_active(true)
	centre_camera(camera, locked)
	point = camera.unproject_position(cell_world(locked))
	click(brush, camera, point)
	check(ground.export_patch() == before, "protected source cell cannot selfunlock")
	centre_camera(camera, water)
	point = camera.unproject_position(cell_world(water))
	brush.set_named_layer("dirt")
	click(brush, camera, point)
	check(ground.cell_state(water.y, water.x, false).tile == 16 and ground.cell_state(water.y, water.x, false).layer.is_empty(), "dirtwater blocked retains native16")
	centre_camera(camera, dry)
	point = camera.unproject_position(cell_world(dry))
	brush.set_named_layer("earth")
	var old_tile: int = ground.cell_state(dry.y, dry.x, false).tile
	click(brush, camera, point)
	check(ground.cell_state(dry.y, dry.x, false).tile == old_tile and ground.cell_state(dry.y, dry.x, false).layer == "earth", "earth separatevisual layer")
	brush.set_named_layer("")
	click(brush, camera, point)
	check(ground.cell_state(dry.y, dry.x, false).layer.is_empty() and ground.cell_state(dry.y, dry.x, false).tile == old_tile, "clear layer no tilealias")
	nav_ok = false
	before = ground.export_patch()
	brush.set_selected_tile(14)
	var old_rollbacks := rollback_calls
	click(brush, camera, point)
	check(ground.export_patch() == before and rollback_calls == old_rollbacks + 1, "navfailure baseline/state preserved physicalrollback")
	nav_ok = true
	preview_ok = false
	brush.handle_input(mouse(point, true), camera, guard)
	check(not brush.is_painting() and ground.export_patch() == before, "previewhookfailure cancels stagedmodel")
	preview_ok = true
	centre_camera(camera, line_start + Vector2i(9, 0))
	brush.set_selected_tile(14)
	var from: Vector2 = camera.unproject_position(cell_world(line_start))
	var to: Vector2 = camera.unproject_position(cell_world(line_start + Vector2i(19, 0)))
	brush.handle_input(mouse(from, true), camera, guard)
	brush.handle_input(motion(to), camera, guard)
	check(brush.debug_cost().stroke_unique_cells == 20, "longdrag samples only20pathcells nofullgrid")
	check(brush.debug_cost().dirty_chunks <= 3, "longdrag bounded dirtychunks")
	brush.handle_input(mouse(to, false), camera, guard)
	for offset in 20: check(ground.cell_state(line_start.y, line_start.x + offset, false).tile == 14, "drag noholes")
	var old_calls := preview_calls.size()
	brush.set_radius(2)
	brush.set_selected_tile(8)
	centre_camera(camera, line_start + Vector2i(9, 0))
	point = camera.unproject_position(cell_world(line_start + Vector2i(9, 0)))
	brush.handle_input(mouse(point, true), camera, guard)
	check(brush.debug_cost().stroke_unique_cells == 5 and preview_calls.size() >= old_calls + 1, "radius2 bounded fivecelldisk")
	brush.focus_lost()
	# Owner can place the ground root at another world transform: no origin guess.
	var translated := Transform3D(Basis.IDENTITY, Vector3(100, 5, 200))
	brush.setup(ground, {"preview_chunks": preview, "physical_apply": physical, "nav_invalidate": nav, "rollback": rollback}, translated)
	brush.set_active(true)
	camera.global_position = translated * cell_world(dry) + Vector3(0, 200, 0)
	point = camera.unproject_position(translated * cell_world(dry))
	picked = brush.pick_screen(point, camera)
	check(picked.ok and picked.row == dry.y and picked.col == dry.x, "transformed cityplane camera nativecoords")
	print("ground_brush: %d checks, %d failures" % [checks, failures])
	world.free()
	quit(1 if failures else 0)
