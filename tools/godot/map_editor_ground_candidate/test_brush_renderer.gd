extends SceneTree
const Ground = preload("res://ground_document.gd")
const Brush = preload("res://ground_brush.gd")
const Renderer = preload("res://ground_renderer.gd")
var checks := 0
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func mouse(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event
func run() -> void:
	root.size = Vector2i(1280, 720)
	var masks := {}
	for name: String in Ground.MASK_NAMES: masks[name] = [[0, 0], [0, 0]]
	var source := {"rows": 2, "cols": 2, "startRow": 0, "startCol": 0, "cellSize": 4.1, "grid": [[0, 0], [0, 0]], "masks": masks, "palette": Ground.DEFAULT_PALETTE.duplicate(true)}
	var doc := Ground.new()
	check(doc.setup_baseline(source).ok, "source admitted")
	var renderer := Renderer.new()
	root.add_child(renderer)
	var materials := {}
	for tile in Ground.SOURCE_TILES: materials[str(tile)] = StandardMaterial3D.new()
	var lease := func() -> bool: return true
	var water := func(_phase: String, _delta: Dictionary) -> Dictionary: return {"ok": true}
	var nav := func(_delta: Dictionary) -> Dictionary: return {"ok": true}
	check(renderer.configure(doc, materials, lease, water, nav).ok, "real native renderer configured")
	var brush := Brush.new()
	var preview := func(_plan: Dictionary) -> Dictionary: return {"ok": true}
	check(brush.setup(doc, {"preview_chunks": preview, "physical_apply": renderer.apply, "nav_invalidate": renderer.validate_navigation, "rollback": renderer.rollback}).ok, "brush uses actual renderer transaction")
	var finalized := [0]
	brush.committed.connect(func(_result: Dictionary):
		var result: Dictionary = renderer.finalize(true)
		check(result.ok, "renderer finalization after data commit")
		finalized[0] += 1
	)
	brush.set_active(true)
	brush.set_selected_tile(8)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	camera.position = Vector3(2.05, 20, 2.05)
	camera.rotation.x = -PI / 2
	camera.make_current()
	await process_frame
	var point := camera.unproject_position(Vector3(2.05, 0, 2.05))
	var guard := func(_event: InputEvent) -> bool: return false
	check(brush.handle_input(mouse(point, true), camera, guard), "stroke starts")
	check(brush.handle_input(mouse(point, false), camera, guard), "stroke release")
	check(doc.cell_state(0, 0).tile == 8 and renderer._pending.is_empty() and finalized[0] == 1, "stroke model/render lease cleaned")
	check(brush.undo().ok and doc.cell_state(0, 0).tile == 0 and renderer._pending.is_empty() and finalized[0] == 2, "undo model/render lease cleaned")
	check(brush.redo().ok and doc.cell_state(0, 0).tile == 8 and renderer._pending.is_empty() and finalized[0] == 3, "redo model/render lease cleaned")
	brush.handle_input(mouse(point, true), camera, guard)
	brush.handle_input(mouse(point, false), camera, guard)
	check(finalized[0] == 3 and renderer._pending.is_empty(), "unchanged stroke never finalizes absent transaction")
	camera.free()
	renderer.free()
	for failure: String in failures: push_error(failure)
	print("brush renderer integration: ", checks, " checks, failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
