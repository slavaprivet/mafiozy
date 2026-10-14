extends SceneTree
const Ground = preload("res://ground_document.gd")
var checks := 0
var failures := 0
var events: Array = []
var last_delta: Dictionary = {}
var allow_physics := true
var allow_nav := true

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func physics_apply(delta: Dictionary) -> Dictionary:
	events.append("physics")
	last_delta = delta
	return {"ok": allow_physics}

func nav_invalidate(_delta: Dictionary) -> Dictionary:
	events.append("nav")
	return {"ok": allow_nav}

func physics_rollback(_delta: Dictionary) -> Dictionary:
	events.append("rollback")
	return {"ok": true}

func commit(ground: RefCounted) -> Dictionary:
	return ground.commit_stroke(physics_apply, nav_invalidate, physics_rollback)

func fixture(rows: int = 4, cols: int = 6) -> Dictionary:
	var grid: Array = []
	var masks := {}
	for name in Ground.MASK_NAMES: masks[name] = []
	for row in rows:
		var tiles: Array = []
		for col in cols: tiles.append(0)
		grid.append(tiles)
		for name in masks:
			var flags: Array = []
			for col in cols: flags.append(0)
			masks[name].append(flags)
	grid[0][0] = 16
	grid[0][1] = 8
	grid[0][2] = 9
	grid[0][3] = 14
	grid[0][4] = 19
	masks.bridgeDeckMask[0][4] = 1
	masks.protectedMask[1][0] = 1
	masks.policeMask[1][1] = 1
	masks.roadMask[2][2] = 1
	return {"schema": "source_exact", "rows": rows, "cols": cols, "startRow": 10, "startCol": 20, "cellSize": 4.1, "grid": grid, "masks": masks, "palette": Ground.DEFAULT_PALETTE.duplicate(true), "opaque": {"districts": [1, 2], "seed": 77}}

func _init() -> void:
	var source := fixture()
	var original := source.duplicate(true)
	var ground := Ground.new()
	var origin := Vector3(70, 0, 20)
	check(ground.setup_baseline(source, origin, 2).ok, "native source accepted")
	check(ground.original_source() == original, "original all fields preserved")
	source.opaque.seed = 123
	check(ground.original_source().opaque.seed == 77, "input immutable")
	var exposed := ground.original_source()
	exposed.masks.roadMask[2][2] = 0
	check(ground.original_source().masks.roadMask[2][2] == 1, "output immutable roadmask")
	check(ground.coordinate_info().start_row == 10 and ground.coordinate_info().start_col == 20 and ground.coordinate_info().origin_m == origin, "readonly coordinate accessor")
	var exposed_palette := ground.surface_palette()
	exposed_palette["16"].solid = true
	check(not ground.surface_palette()["16"].solid, "palette accessor detached")
	check(ground.cell_state(10, 20).tile == 16 and ground.cell_state(10, 21).tile == 8 and ground.cell_state(10, 22).tile == 9 and ground.cell_state(10, 23).tile == 14, "exact tile semantics")
	var picked := ground.pick_cell(Vector2((22.5) * 4.1 - 70, (12.5) * 4.1 - 20))
	check(picked.ok and picked.id == "cell:12:22", "source row col world pick")
	check(not ground.pick_cell(Vector2(20 * 4.1 - 70 - 0.001, 10 * 4.1 - 20)).ok, "negative offset beforefloor rejected")
	check(not ground.pick_cell(Vector2(26 * 4.1 - 70, 10 * 4.1 - 20)).ok, "far bound exclusive")
	check(not ground.pick_cell(Vector2(1e30, 1e30)).ok and not ground.pick_cell(Vector2(NAN, 0)).ok, "unsafe world bounds rejected")
	check(ground.begin_stroke().ok, "begin stroke")
	check(not ground.set_tile(11, 20, 8).ok and not ground.set_tile(11, 21, 8).ok and not ground.set_tile(10, 24, 8).ok, "protected police bridge retained")
	for iteration in 50: check(ground.set_tile(12, 22, 8).ok, "pointer repeated same cell")
	check(ground.debug_cost().staged_cells == 1 and ground.debug_cost().pointer_cell_touches == 50, "constantcell pointer storage")
	check(ground.cell_state(12, 22).tile == 8 and ground.cell_state(12, 22, false).tile == 0, "stroke preview no model commit")
	var delta := ground.prepare_stroke()
	check(delta.cells.size() == 1 and delta.dirty_rows == [12] and delta.dirty_chunks == [Vector2i.ZERO], "bounded dirty plan")
	check(delta.physical_rows[0].strips.size() == 3, "dry row merges consecutive strips")
	var delta_chunk := ground.build_chunk_delta(0, 0, delta.desired)
	check(delta_chunk.ok and delta_chunk.groups["8"].size() == 2, "explicit staged delta chunk render")
	check(ground.row_strips(12).ok and ground.row_strips(12).strips.size() == 1 and not ground.row_strips(9).ok, "public initial physical strips beforecommit")
	var invalid_desired: Dictionary = delta.desired.duplicate(true)
	invalid_desired["cell:11:20"] = {"row": 11, "col": 20, "id": "cell:11:20", "tile": 8, "layer": ""}
	check(not ground.build_chunk_delta(0, 0, invalid_desired).ok, "explicit delta cannot change protected cells")
	check(commit(ground).ok and events == ["physics", "nav"], "physicalrows then nav then commit")
	check(ground.debug_cost().tile_overrides == 1, "sparse override")
	check(ground.original_source() == original, "stroke retains exact masks and source")
	events.clear()
	ground.begin_stroke()
	check(ground.set_tile(12, 23, 16).ok, "water brush native16")
	check(not ground.set_named_layer(12, 23, "dirt").ok, "dirt neverwater substitute")
	check(ground.set_named_layer(12, 22, "dirt").ok, "named dirt layer independent oftile")
	check(commit(ground).ok, "second batch commit")
	check(last_delta.physical_rows[0].strips.size() == 3, "water removes physical floor strip")
	check(ground.cell_state(12, 22).tile == 8 and ground.cell_state(12, 22).layer == "dirt", "custom namedlayer keeps tile8")
	var patch := ground.export_patch()
	check(patch.tile_overrides.size() == 2 and patch.layers.dirt.size() == 1 and patch.layers.earth.is_empty(), "sparse versioned patch")
	check(ground.validate_patch(patch).ok, "validpatch")
	var imported := Ground.new()
	imported.setup_baseline(original, origin)
	check(imported.load_patch(JSON.parse_string(JSON.stringify(patch, "", true, true)), physics_apply, nav_invalidate, physics_rollback).ok, "JSON sparse patch roundtrip")
	check(imported.export_patch() == patch, "roundtrip exact editedfields")
	var chunk := ground.build_chunk(0, 0)
	check(chunk.ok and chunk.cell_count == 24 and chunk.groups.has("16") and chunk.groups.has("layer:dirt"), "groupedchunk no individualnodes")
	check(is_equal_approx(chunk.groups["8"][0].origin.y, -0.02), "nativebox visualheight parity")
	var shared_materials := {}
	for key in chunk.groups: shared_materials[key] = StandardMaterial3D.new()
	shared_materials["8"].roughness = 0.95
	var resources := Ground.build_multimesh_resources(chunk, shared_materials)
	check(resources.ok and resources.multimeshes["8"] is MultiMesh, "native multimesh resource builder")
	check(resources.multimeshes["8"].mesh.material == shared_materials["8"] and is_equal_approx(shared_materials["8"].roughness, 0.95), "shared source materials exact reference unmodified")
	check(not resources.multimeshes.has("16") and resources.water_host_dirty, "water kept with original highquality host")
	check(resources.multimeshes["layer:dirt"].mesh is PlaneMesh, "named custom layer geometry separate")
	var second_resources := Ground.build_multimesh_resources(chunk, shared_materials, resources.mesh_cache)
	check(second_resources.multimeshes["8"].mesh == resources.multimeshes["8"].mesh, "mesh reused across chunks")
	check(not Ground.build_multimesh_resources(chunk, {}).ok, "missing original material refuses render")
	check(ground.undo(physics_apply, nav_invalidate, physics_rollback).ok and ground.cell_state(12, 23).tile == 0 and ground.cell_state(12, 22).layer.is_empty(), "undo batch water and overlay")
	var inverse_chunk := ground.build_chunk_delta(0, 0, last_delta.desired)
	check(inverse_chunk.ok and not inverse_chunk.groups.has("layer:dirt") and inverse_chunk.groups["16"].size() == 1, "undo desired chunk without active stroke")
	check(ground.redo(physics_apply, nav_invalidate, physics_rollback).ok and ground.export_patch() == patch, "redo batch")
	events.clear()
	allow_nav = false
	ground.begin_stroke()
	ground.set_named_layer(13, 23, "earth")
	var failed := commit(ground)
	check(not failed.ok and failed.rollback_ok and events == ["physics", "nav", "rollback"], "navfailure rolls back scene beforecommit")
	check(ground.cell_state(13, 23, false).layer.is_empty(), "failed transaction model unchanged")
	ground.cancel_stroke()
	allow_nav = true
	allow_physics = false
	events.clear()
	ground.begin_stroke()
	ground.set_tile(13, 23, 14)
	check(not commit(ground).ok and events == ["physics", "rollback"], "physicsfailure prevents nav")
	ground.cancel_stroke()
	allow_physics = true
	var before := ground.export_patch()
	for mode in ["hash", "bounds", "id", "duplicate", "protected", "unknown", "nan", "layerwater", "layerduplicate", "huge"]:
		var corrupt := patch.duplicate(true)
		match mode:
			"hash": corrupt.baseline_sha256 = "wrong"
			"bounds": corrupt.tile_overrides[0].row = 999
			"id": corrupt.tile_overrides[0].id = "cell:12:0"
			"duplicate": corrupt.tile_overrides.append(corrupt.tile_overrides[0].duplicate(true))
			"protected": corrupt.tile_overrides[0] = {"id": "cell:11:20", "row": 11, "col": 20, "tile": 8}
			"unknown": corrupt.roadMask = [[1]]
			"nan": corrupt.tile_overrides[0].tile = NAN
			"layerwater": corrupt.layers.dirt = [{"id": "cell:12:23", "row": 12, "col": 23}]
			"layerduplicate": corrupt.layers.earth = corrupt.layers.dirt.duplicate(true)
			"huge": corrupt.tile_overrides[0].row = 1e300
		check(not ground.load_patch(corrupt, physics_apply, nav_invalidate, physics_rollback).ok, "corruptpatch rejected: " + mode)
		check(ground.export_patch() == before, "corruptpatch no mutation: " + mode)
	var bad_source := original.duplicate(true)
	bad_source.masks.roadMask[0][0] = 4
	check(not ground.setup_baseline(bad_source).ok and ground.export_patch() == before, "source mask invalid no mutation")
	bad_source = original.duplicate(true)
	bad_source.cellSize = 3.0
	check(not ground.setup_baseline(bad_source).ok, "source scale cannot change")
	check(not ground.setup_baseline({"surface": "bad"}).ok, "wrong surface dictionary")
	ground.begin_stroke()
	ground.set_tile(12, 22, 0)
	ground.set_named_layer(12, 22, "")
	check(commit(ground).ok and ground.debug_cost().tile_overrides == 1, "return tobaseline removes sparse entry")
	# Actual full authored grid/masks are admitted unchanged, CPU only.
	var real_path := "C:/Users/Слава/Desktop/Мафиози/assets/maps/city_rebuild_v1/topology_for_placement.json"
	var real_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(real_path))
	var full := Ground.new()
	check(full.setup_baseline(real_source).ok and full.dimensions() == Vector2i(180, 200), "actual fulltopology native admission")
	check(full.original_source() == real_source, "actual unknown sourcefields all intact")
	check(full.build_chunk(0, 0).cell_count == 256, "actual bounded16x16 chunk")
	full.begin_stroke()
	var count := 0
	for row in 200:
		for col in 180:
			if count >= 100: break
			if full.is_editable(row, col):
				full.set_tile(row, col, 8)
				count += 1
		if count >= 100: break
	check(full.debug_cost().staged_cells == 100, "fullgrid stroke stores100cells not36000clone")
	check(commit(full).ok, "actual fulltopology headless stroke")
	print("ground_document: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

