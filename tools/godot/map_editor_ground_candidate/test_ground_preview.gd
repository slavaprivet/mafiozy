extends SceneTree
const Ground = preload("res://ground_document.gd")
const Preview = preload("res://ground_preview.gd")
var checks := 0
var failures: Array[String] = []
var owner_paused := true
func lease() -> bool: return owner_paused
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var grid: Array = []
	var masks := {}
	for name in Ground.MASK_NAMES: masks[name] = []
	for row in 33:
		var tiles: Array = []
		for col in 33: tiles.append(0)
		grid.append(tiles)
		for name in masks:
			var flags: Array = []
			for col in 33: flags.append(0)
			masks[name].append(flags)
	masks.protectedMask[0][0] = 1
	var source := {"rows": 33, "cols": 33, "startRow": 10, "startCol": 76, "cellSize": 4.1, "grid": grid, "masks": masks, "palette": Ground.DEFAULT_PALETTE.duplicate(true)}
	var document := Ground.new()
	check(document.setup_baseline(source, Vector3(395.65, 0, 45.1)).ok, "source admitted")
	var before: Dictionary = document.export_patch()
	var preview := Preview.new()
	root.add_child(preview)
	check(preview.configure(document, lease).ok, "explicit preview root")
	check(preview.show_cursor(10, 76, 1).ok, "cursor on protected cell")
	check(preview._cursor.multimesh.instance_count == 1, "one cell cursor")
	var old_cursor: Node = preview._cursor
	check(preview.show_cursor(10, 76, 1).unchanged and preview._cursor == old_cursor, "unchanged cursor reuses exact resource")
	check(preview.show_cursor(20, 90, 8).cells == 149, "bounded circular size8 footprint")
	check(document.export_patch() == before, "cursor never changes source/history")
	check(document.begin_stroke().ok, "stroke")
	check(document.set_tile(11, 77, 8).ok and document.set_tile(30, 96, 16).ok, "two actual changes in separate chunks")
	var desc := {"preview": true, "cancelled": false, "dirty_chunks": [Vector2i(0, 0), Vector2i(1, 1)], "chunks": [{"forged": "ignored"}]}
	check(preview.apply(desc).ok, "preview derives exact pending cells not caller geometry")
	check(preview._chunks.size() == 2, "only dirty chunks allocated")
	for node: MultiMeshInstance3D in preview._chunks.values():
		check(node.multimesh.instance_count == 1 and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "changed cells only, no shadows")
		check(node.multimesh.mesh == preview._mesh and node.material_override == preview._material, "shared editor-only resources")
		check(node.get_child_count() == 0, "no collider/nav/water nodes")
	var untouched: Node = preview._chunks[Vector2i(1, 1)]
	check(preview.apply({"preview": true, "dirty_chunks": [Vector2i(0, 0)]}).ok and preview._chunks[Vector2i(1, 1)] == untouched, "other chunk resource identity retained")
	check(not preview.apply({"preview": true, "dirty_chunks": [Vector2i(3, 3)]}).ok and preview._chunks.size() == 2, "invalid batch changes no preview")
	owner_paused = false
	check(not preview.apply(desc).ok, "lost lease refuses preview update")
	check(not preview.show_cursor(11, 77, 1).ok and preview._cursor == null, "lost lease hides cursor")
	check(preview.apply({"cancelled": true}).ok and preview._chunks.is_empty(), "cancel always removes editor artifacts")
	owner_paused = true
	document.cancel_stroke()
	check(preview.apply(desc).ok and preview._chunks.is_empty(), "cancelled model yields no changed cells")
	check(document.export_patch() == before and not document.debug_cost().undo_actions, "source and history exact after preview/cancel")
	preview.free()
	for failure in failures: push_error(failure)
	print("ground preview: ", checks, " checks, failures=", failures.size(), "; editor-only, GPU not verified")
	quit(0 if failures.is_empty() else 1)
