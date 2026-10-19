extends SceneTree
const Ground = preload("res://ground_document.gd")
const Renderer = preload("res://ground_renderer.gd")
const SurfaceMaterials = preload("C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk/scripts/preview_surface_materials.gd")
var failures: Array[String] = []
var checks := 0
var lease_active := true
var allow_nav := true
var allow_water_apply := true
var allow_water_finalize := true
var water_events: Array[String] = []
var nav_calls := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func lease() -> bool:
	return lease_active

func water(phase: String, _delta: Dictionary) -> Dictionary:
	water_events.append(phase)
	return {"ok": (phase != "apply" or allow_water_apply) and (phase != "finalize" or allow_water_finalize), "receipt": {"owner": "explicit-test-water-host"}}

func navigation(_delta: Dictionary) -> Dictionary:
	nav_calls += 1
	return {"ok": allow_nav}

func fixture() -> Dictionary:
	var grid: Array = []
	var masks := {}
	for name in Ground.MASK_NAMES: masks[name] = []
	for row in range(32):
		grid.append([])
		for col in range(32): grid[row].append(0)
		for name in masks:
			masks[name].append([])
			for col in range(32): masks[name][row].append(0)
	grid[0][0] = 16
	return {"rows": 32, "cols": 32, "startRow": 0, "startCol": 0, "cellSize": 4.1, "grid": grid, "masks": masks, "palette": Ground.DEFAULT_PALETTE.duplicate(true)}

func materials(source: Dictionary, origin: Vector3 = Vector3.ZERO) -> Dictionary:
	var result := {}
	for tile in Ground.SOURCE_TILES:
		if source.palette[str(tile)].has("colorSrgb"):
			result[str(tile)] = SurfaceMaterials.create_material(source, tile, origin)
		else:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.1 * tile, 0.4, 0.3)
			result[str(tile)] = material
	for name in Ground.NAMED_LAYERS:
		result["layer:" + name] = StandardMaterial3D.new()
	return result

func owned(source: Dictionary, origin: Vector3 = Vector3.ZERO) -> Dictionary:
	var document := Ground.new()
	check(document.setup_baseline(source, origin).ok, "Ground source admitted")
	var renderer := Renderer.new()
	root.add_child(renderer)
	var shared := materials(source, origin)
	check(renderer.configure(document, shared, lease, water, navigation).ok, "Standalone owned render root prepared/validated")
	return {"document": document, "renderer": renderer, "materials": shared}

func check_geometry(renderer: Node, document: RefCounted) -> void:
	var info: Dictionary = document.coordinate_info()
	var palette: Dictionary = document.surface_palette()
	for chunk: Node3D in renderer._chunks.values():
		for instance: MultiMeshInstance3D in chunk.get_children():
			var multi := instance.multimesh
			check(multi.mesh.material == renderer._materials[str(instance.name).trim_prefix("Surface_").replace("layer_", "layer:")], "Shared exact material resource identity")
			check(instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Original source surface shadow policy")
			if multi.mesh is BoxMesh:
				check(multi.mesh.size.is_equal_approx(Vector3(4.1, 0.04, 4.1)), "Exact source 4.1 m render geometry")
			check(not str(instance.name).ends_with("16"), "Water visuals delegated, no substituted box")
	for row: int in renderer._rows:
		for body: StaticBody3D in renderer._rows[row].get_children():
			var strip: Dictionary = body.get_meta("source_strip")
			var tile: int = strip.tile
			check(tile != 16 and palette[str(tile)].solid, "No physical floor under water")
			var shape: BoxShape3D = body.get_child(0).shape
			check(shape.size.is_equal_approx(Vector3((strip.end_col - strip.first_col) * 4.1, 0.16, 4.1)), "Exact strip width/thickness")
			var expected := Vector3((strip.first_col + strip.end_col) * 0.5 * 4.1 - info.origin_m.x, float(palette[str(tile)].heightM) - 0.08, (row + 0.5) * 4.1 - info.origin_m.z)
			check(body.position.is_equal_approx(expected), "Exact source strip position")

func percentile(values: Array[int], fraction: float) -> int:
	values.sort()
	return values[mini(values.size() - 1, int(values.size() * fraction))]

func run() -> void:
	var synthetic := owned(fixture())
	var doc: RefCounted = synthetic.document
	var renderer: Node = synthetic.renderer
	check_geometry(renderer, doc)
	var untouched: Node3D = renderer._chunks[Vector2i(1, 1)]
	var shared_mesh: Mesh = renderer._mesh_cache["0"]
	var shared_material: Material = synthetic.materials["0"]
	doc.begin_stroke()
	doc.set_tile(3, 3, 8)
	check(renderer.commit_stroke().ok, "Single-cell paint transaction")
	check(renderer.last_built_chunks == 1 and renderer.last_built_rows == 1 and renderer._chunks[Vector2i(1, 1)] == untouched, "Only touched chunk/row rebuilt")
	check(renderer._mesh_cache["0"] == shared_mesh and shared_mesh.material == shared_material, "No shared mesh/material mutation")
	check(renderer.undo().ok and doc.cell_state(3, 3).tile == 0, "Renderer-aware ground undo")
	check(renderer.redo().ok and doc.cell_state(3, 3).tile == 8, "Renderer-aware ground redo")
	var previous_patch: Dictionary = doc.export_patch()
	var previous_chunk: Node3D = renderer._chunks[Vector2i.ZERO]
	var previous_multi: MultiMesh = previous_chunk.get_child(0).multimesh
	var previous_row: Node3D = renderer._rows[3]
	var previous_body: StaticBody3D = previous_row.get_child(0)
	previous_body.collision_layer = 5
	previous_body.collision_mask = 9
	allow_nav = false
	doc.begin_stroke()
	doc.set_tile(3, 4, 14)
	check(not renderer.commit_stroke().ok and doc.export_patch() == previous_patch, "Navigation failure leaves ground model/history unchanged")
	check(renderer._chunks[Vector2i.ZERO] == previous_chunk and previous_chunk.get_child(0).multimesh == previous_multi and renderer._rows[3] == previous_row, "Rollback restores exact old nodes/resources")
	check(previous_body.collision_layer == 5 and previous_body.collision_mask == 9, "Rollback restores exact body layer and mask")
	allow_nav = true
	doc.cancel_stroke()
	lease_active = false
	doc.begin_stroke()
	doc.set_tile(3, 4, 9)
	check(not renderer.commit_stroke().ok and doc.export_patch() == previous_patch and renderer._chunks[Vector2i.ZERO] == previous_chunk, "No renderer or ground mutation during play")
	lease_active = true
	doc.cancel_stroke()
	allow_water_apply = false
	doc.begin_stroke()
	doc.set_tile(3, 4, 16)
	var water_count := water_events.size()
	check(not renderer.commit_stroke().ok and doc.export_patch() == previous_patch and renderer._rows[3] == previous_row, "Water apply rejection restores dry renderer/model")
	check(water_events.slice(water_count) == ["prepare", "apply", "rollback"], "Water explicitly staged/applied/rolled back by its owner")
	allow_water_apply = true
	doc.cancel_stroke()
	doc.begin_stroke()
	doc.set_tile(3, 4, 16)
	check(renderer.commit_stroke().ok and doc.cell_state(3, 4).tile == 16, "Authorized water change adopted without placeholder geometry")
	check_geometry(renderer, doc)
	check(renderer.undo().ok and doc.cell_state(3, 4).tile == 0, "Water undo rebuilds correct dry strips")
	allow_water_finalize = false
	doc.begin_stroke()
	doc.set_tile(3, 4, 16)
	var cleanup_pending: Dictionary = renderer.commit_stroke()
	check(not cleanup_pending.ok and cleanup_pending.get("committed", false) and cleanup_pending.get("retry_finalize", false) and doc.cell_state(3, 4).tile == 16, "Cleanup failure reports committed model and requires paused finalize retry")
	check(not renderer.rollback().ok, "Committed model cannot be desynchronized by render-only rollback")
	allow_water_finalize = true
	check(renderer.finalize().ok and renderer.undo().ok, "Paused cleanup retry then normal undo works")
	# Exact real source topology and native shared materials, isolated only.
	var topology: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("C:/Users/Слава/Desktop/Мафиози/assets/maps/city_rebuild_v1/topology_for_placement.json"))
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk/data/block.json"))
	topology["palette"] = block.surface.palette.duplicate(true)
	var origin := Vector3(block.originM[0], block.originM[1], block.originM[2])
	var cropped := owned(block.surface, origin)
	check(cropped.document.dimensions() == Vector2i(31, 31) and cropped.document.coordinate_info().start_col == 76, "Actual 31×31 source crop preserves nonzero starting column")
	check(cropped.renderer._chunks.size() == 4 and cropped.renderer._rows.has(0) and cropped.renderer._rows.has(30), "Crop chunks remain local-relative while physical rows retain source IDs")
	check_geometry(cropped.renderer, cropped.document)
	var crop_cell := Vector2i(-1, -1)
	for row in range(31):
		for col in range(76, 107):
			if cropped.document.is_editable(row, col) and cropped.document.cell_state(row, col).tile == 0:
				crop_cell = Vector2i(col, row)
				break
		if crop_cell.x >= 0: break
	check(crop_cell.x >= 0, "Editable cropped source cell found")
	var crop_position := Vector2((crop_cell.x + 0.5) * 4.1 - origin.x, (crop_cell.y + 0.5) * 4.1 - origin.z)
	var picked_crop: Dictionary = cropped.document.pick_cell(crop_position)
	check(picked_crop.ok and picked_crop.col == crop_cell.x and picked_crop.row == crop_cell.y, "Crop cursor/source origin roundtrip exact")
	var untouched_crop: Node3D = cropped.renderer._chunks[Vector2i(1, 1)]
	cropped.document.begin_stroke()
	cropped.document.set_tile(crop_cell.y, crop_cell.x, 8)
	check(cropped.renderer.commit_stroke().ok and cropped.renderer.last_built_chunks == 1 and cropped.renderer.last_built_rows == 1, "Cropped actual source changes only one local-relative chunk/row")
	var changed_chunk := Vector2i((crop_cell.x - 76) / 16, crop_cell.y / 16)
	if changed_chunk != Vector2i(1, 1): check(cropped.renderer._chunks[Vector2i(1, 1)] == untouched_crop, "Cropped untouched chunk resource identity retained")
	check(cropped.renderer.undo().ok and cropped.document.export_patch().tile_overrides.is_empty(), "Cropped exact baseline restored")
	cropped.renderer.queue_free()
	var initial_start := Time.get_ticks_usec()
	var actual := owned(topology, origin)
	var initial_usec := Time.get_ticks_usec() - initial_start
	var real_doc: RefCounted = actual.document
	var real_renderer: Node = actual.renderer
	check(real_doc.dimensions() == Vector2i(180, 200), "Actual full topology 200×180")
	check_geometry(real_renderer, real_doc)
	var selected := Vector2i(-1, -1)
	for row in range(200):
		for col in range(180):
			if real_doc.is_editable(row, col) and real_doc.cell_state(row, col).tile == 0:
				selected = Vector2i(col, row)
				break
		if selected.x >= 0: break
	check(selected.x >= 0, "Editable actual source asphalt cell located")
	var timings: Array[int] = []
	for iteration in range(20):
		real_doc.begin_stroke()
		real_doc.set_tile(selected.y, selected.x, 8)
		var started := Time.get_ticks_usec()
		check(real_renderer.commit_stroke().ok, "Actual cell paint adopted")
		timings.append(Time.get_ticks_usec() - started)
		check(real_renderer.last_built_chunks == 1 and real_renderer.last_built_rows == 1, "Actual pointer update touches one chunk and one row")
		started = Time.get_ticks_usec()
		check(real_renderer.undo().ok, "Actual undo adopted")
		timings.append(Time.get_ticks_usec() - started)
	check(real_doc.export_patch().tile_overrides.is_empty(), "Actual source terrain restored after repeated transactions")
	print("GROUND_RENDERER_QA ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "actualRows": 200, "actualCols": 180, "renderChunks": real_renderer._chunks.size(), "physicalRowRoots": real_renderer._rows.size(), "dirtyChunksPerAction": real_renderer.last_built_chunks, "dirtyRowsPerAction": real_renderer.last_built_rows, "samples": timings.size(), "transactionCpuUsecP50": percentile(timings, 0.5), "transactionCpuUsecP95": percentile(timings, 0.95), "initialSourceSetupCpuUsec": initial_usec, "scope": "Output-only renderer ownership candidate; explicit water host, paused lease, exact native source geometry. CPU only; no gameplay/LIVE/GPU admission."}))
	actual.renderer.queue_free()
	renderer.queue_free()
	quit(0 if failures.is_empty() else 1)

