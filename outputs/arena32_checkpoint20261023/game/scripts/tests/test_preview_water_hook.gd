extends SceneTree
## Real main-scene admission/lifecycle tests, no GPU shader/FPS claim.
const MAIN = preload("res://scenes/main.tscn")
const Water = preload("res://scripts/preview_water_surface.gd")
var _checks: int = 0
var _errors: Array[String] = []
var _fixtures: Array[String] = []
var _block: Dictionary
var _water: Dictionary
var _baseline: Array = []
var _cpu: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_block = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	_water = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_water.json"))
	if OS.get_cmdline_user_args().has("--preview-water-off"):
		var off: Node3D = _scene()
		_check(off.preview_ready and off.water_status == "baseline_disabled", "CLI override selects baseline while default export is true")
		_check(off.preview_water_detail_enabled and off._water_host == null and off.get_node_or_null("SourceNativeWater") == null, "CLI override does not mutate export property or create host")
		_check(off.get_node("Surface_water").multimesh.instance_count == 303, "CLI baseline retains303 original water boxes")
		off.free()
		_finish()
		return
	var baseline: Node3D = _scene(false, "user://water_absent_must_not_read.json")
	_check(baseline.preview_ready and baseline.water_status == "baseline_disabled" and baseline.water_errors.is_empty(), "explicit OFF does not read optional data")
	_check(baseline._water_host == null and baseline.get_node("Surface_water").multimesh.instance_count == 303, "OFF keeps original303-water batch only")
	_baseline = _dry_signature(baseline)
	_check(_baseline.size() == 169, "original exact169 dry-strip bodies")
	if OS.get_cmdline_user_args().has("--benchmark"):
		_cpu["baseline_main_process"] = _benchmark_main(baseline)
	baseline.free()
	var scene: Node3D = _scene()
	await _frames(3)
	_check(scene.preview_ready and scene.water_status == "detail_ready" and scene.water_errors.is_empty(), "default actual main admits trusted detail")
	if OS.get_cmdline_user_args().has("--benchmark"):
		_cpu["detail_main_process"] = _benchmark_main(scene)
		var at: Vector3 = scene._player.global_position
		var started: int = Time.get_ticks_usec()
		for i: int in range(10000):
			scene.preview_jump_surface_allowed(at, .36)
		_cpu["contains_guard_10000_mean_us"] = float(Time.get_ticks_usec() - started) / 10000.0
	_check(scene.get_node_or_null("Surface_water") == null and scene.find_children("SourceNativeWater", "MeshInstance3D", true, false).size() == 1, "one detail batch replaces baseline with no duplicate")
	_check(scene.water_summary.cells == 303 and scene.water_summary.vertices == 1818 and scene.water_summary.triangles == 606, "all303cells1818vertices606triangles admitted")
	_check(_dry_signature(scene) == _baseline, "detail preserves exact dry shape transforms/sizes/layers/masks")
	_check(scene.printshop_status == "ready" and scene.preview_perf != null and not scene.preview_perf.is_processing(), "typography and defaultOFF perf preserved")
	_check(scene.find_children("PreviewUpdates", "PanelContainer", true, false).size() == 1, "current update panel preserved")
	_test_surface_guard(scene)
	var mesh_node: MeshInstance3D = scene.get_node("SourceNativeWater")
	_check(mesh_node.get_child_count() == 0 and not mesh_node.is_processing() and not mesh_node.is_physics_processing(), "detail node has no physics/auto callbacks")
	var mesh: ArrayMesh = mesh_node.mesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var depths: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var zero: int = 0
	var exact: bool = depths.size() == 1818
	for i: int in range(_water.native.cells.size()):
		for j: int in range(6):
			var depth: float = depths[i*6+j]
			exact = exact and depth == float(_water.native.cells[i].depths[j])
			zero += 1 if depth == 0.0 else 0
	_check(exact and zero == 231, "actual mesh keeps every trusted depth including231 zero shoreline vertices")
	var water_floor_hits: int = 0
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	for cell: Dictionary in _water.native.cells:
		var source: Vector3 = Vector3((float(cell.c) + .5)*4.1, 0.1, (float(cell.r) + .5)*4.1)
		var at: Vector3 = source - Vector3(_water.originM[0], _water.originM[1], _water.originM[2])
		var query := PhysicsRayQueryParameters3D.create(at, at - Vector3.UP * .6, 1, [scene._player.get_rid()])
		if not space.intersect_ray(query).is_empty():
			water_floor_hits += 1
	_check(water_floor_hits == 0, "all303 water centres have no fabricated physical floor")
	var material: ShaderMaterial = mesh.surface_get_material(0)
	var time_before: float = material.get_shader_parameter("environmentTime")
	await _frames(5)
	var time_after: float = material.get_shader_parameter("environmentTime")
	_check(time_after > time_before, "main alone advances actual material from monotonic wall time")
	_check(mesh_node.mesh == mesh and mesh.surface_get_material(0) == material, "runtime reuses mesh/material references")
	# Pure root admission checks on a currently ready main, before adding nodes.
	var original_block: Dictionary = scene._block
	var changed: Dictionary = original_block.duplicate(true)
	changed.originM[0] += 1.0
	scene._block = changed
	_check(scene._validate_water_crop(_water).has("WATER_BLOCK_ORIGIN"), "root rejects stale source origin")
	changed = original_block.duplicate(true)
	changed.surface.cellSize = 4.2
	scene._block = changed
	_check(scene._validate_water_crop(_water).has("WATER_BLOCK_CELL_SIZE"), "root rejects stale metre scale")
	changed = original_block.duplicate(true)
	changed.surface.masks.protectedMask[0][10] = 1
	scene._block = changed
	_check(scene._validate_water_crop(_water).has("WATER_PROTECTED_CELL_UNSUPPORTED"), "protected-water footprint cannot silently disappear")
	changed = original_block.duplicate(true)
	changed.surface.masks.protectedMask = []
	scene._block = changed
	_check(scene._validate_water_crop(_water).has("WATER_PROTECTED_MASK_ROWS"), "malformed protected mask fails closed")
	scene._block = original_block
	var held_host: RefCounted = scene._water_host
	var held_instance: MeshInstance3D = mesh_node
	scene.free()
	_check(not is_instance_valid(held_instance) and not held_host.advance(1000000.0), "scene destruction disposes owned host before parent lifetime ends")
	# Root admission performs normalized LF hashing: actual CRLF package accepted.
	var normalized: String = FileAccess.get_file_as_string("res://data/preview_water.json").replace("\r\n", "\n")
	var crlf: String = _fixture("crlf", normalized.replace("\n", "\r\n"))
	scene = _scene(true, crlf)
	_check(scene.water_status == "detail_ready" and _dry_signature(scene) == _baseline, "CRLF trusted package admitted without changing dry physics")
	scene.free()
	var malformed: String = _fixture("bad", "{bad json")
	var untrusted: Dictionary = _water.duplicate(true)
	untrusted.native.cells[0].depths[0] = 1.0
	_check(Water.validate(untrusted).is_empty(), "changed-depth fixture remains structurally valid")
	var changed_data: String = _fixture("valid_untrusted", JSON.stringify(untrusted))
	for path: String in ["user://absent_water_hook_file.json", malformed, changed_data]:
		scene = _scene(true, path)
		_check(scene.preview_ready and scene.water_status == "baseline_fallback" and not scene.water_errors.is_empty(), "bad/missing/untrusted water keeps main READY with explicit fallback")
		_check(scene.get_node_or_null("SourceNativeWater") == null and scene._water_host == null and scene.get_node("Surface_water").multimesh.instance_count == 303, "failed admission has no partial or duplicate water node")
		_check(_dry_signature(scene) == _baseline, "bad package preserves all original dry strips")
		scene.free()
	# Structurally valid current blocks that no longer match this trusted water.
	for kind: String in ["bounds", "footprint"]:
		var block: Dictionary = _block.duplicate(true)
		if kind == "bounds":
			block.surface.startCol += 1
		else:
			# Keep303 water cells but move one cell into dry land.
			var original: Variant = block.surface.grid[0][0]
			block.surface.grid[0][0] = block.surface.grid[0][10]
			block.surface.grid[0][10] = original
		var block_path: String = _fixture(kind, JSON.stringify(block))
		var expected_scene: Node3D = _scene(false, "res://data/preview_water.json", block_path)
		var expected_shapes: Array = _dry_signature(expected_scene)
		_check(expected_scene.preview_ready, "stale block fixture still passes ordinary block admission")
		expected_scene.free()
		scene = _scene(true, "res://data/preview_water.json", block_path)
		_check(scene.preview_ready and scene.water_status == "baseline_fallback", "trusted water rejected for changed valid " + kind)
		_check(scene.water_errors.has("WATER_BLOCK_BOUNDS" if kind == "bounds" else "WATER_BLOCK_FOOTPRINT"), "specific stale " + kind + " error")
		_check(scene.get_node_or_null("SourceNativeWater") == null and _dry_signature(scene) == expected_shapes, "stale admission keeps only that block's baseline and unchanged dry strips")
		scene.free()
	# Valid trusted data but nonidentity host parent: exercise actual build failure.
	scene = MAIN.instantiate()
	scene.position.x = 1.0
	root.add_child(scene)
	_check(scene.preview_ready and scene.water_status == "baseline_fallback" and scene.water_errors.has("IDENTITY_WORLD_PARENT_REQUIRED"), "host build rejection returns to explicit baseline")
	_check(scene._water_host == null and scene.get_node_or_null("SourceNativeWater") == null and scene.get_node_or_null("Surface_water") != null, "build failure releases partial ownership before baseline")
	scene.free()
	_finish()

func _test_surface_guard(scene: Node3D) -> void:
	_check((scene._player._jump_surface_guard as Callable).is_valid(), "player receives main source-contains guard")
	var water_cell: Dictionary = _water.native.cells[0]
	var source: Vector3 = Vector3((float(water_cell.c)+.5)*4.1, 0.0, (float(water_cell.r)+.5)*4.1)
	var local: Vector3 = source - Vector3(_water.originM[0], _water.originM[1], _water.originM[2])
	_check(local.x < 0 and scene.preview_jump_surface_allowed(local, .36), "actual water footprint and valid negative local coordinate are admitted")
	# First water cell borders dry cell c85: both sides belong to source contains.
	local.x = float(water_cell.c)*4.1 - float(_water.originM[0]) + .1
	_check(scene.preview_jump_surface_allowed(local, .36), "shoreline footprint straddling admitted land/water remains allowed")
	_check(not scene.preview_jump_surface_allowed(Vector3(NAN, 0, 0), .36), "nonfinite world point rejected")
	_check(not scene.preview_jump_surface_allowed(Vector3.ZERO, -1.0), "invalid footprint radius rejected")
	var saved_block: Dictionary = scene._block
	var saved_origin: Vector3 = scene._origin
	var grid: Array = [[8,8,8],[8,9,8],[8,8,8]]
	var walk: Array = [[1,1,1],[1,0,1],[1,1,1]]
	var police: Array = [[0,0,0],[0,1,0],[0,0,0]]
	var protected: Array = [[0,0,0],[0,1,0],[0,0,0]]
	scene._block = {"surface": {"grid": grid, "cellSize": 4.1, "rows": 3, "cols": 3, "startRow": 0, "startCol": 0,
		"masks": {"walkableMask": walk, "policeMask": police, "protectedMask": protected}}}
	scene._origin = Vector3.ZERO
	scene._cache_jump_surface_contains()
	_check(scene.preview_jump_surface_allowed(Vector3(6.15, 0, 6.15), .36), "protected police tile9 admitted even with walkableMask0")
	_check(not scene.preview_jump_surface_allowed(Vector3(-.001, 0, 2.0), .36), "negative source coordinate cannot truncate into first cell")
	_check(not scene.preview_jump_surface_allowed(Vector3(.2, 0, 2.0), .36), "centre in bounds rejected when source footprint crosses crop")
	_check(not scene.preview_jump_surface_allowed(Vector3(12.3, 0, 2.0), .36), "exclusive upper crop bound rejected")
	_check(scene.preview_jump_surface_allowed(Vector3(4.25, 0, 4.25), .36), "protected dry corner admitted with dry neighbours")
	grid[0][0] = 16
	walk[0][0] = 0
	protected[0][0] = 1
	scene._cache_jump_surface_contains()
	_check(not scene.preview_jump_surface_allowed(Vector3(4.25, 0, 4.25), .36), "12-point source footprint detects blocked diagonal corner missed by cardinal-only probe")
	protected[0][0] = 0
	scene._cache_jump_surface_contains()
	_check(scene.preview_jump_surface_allowed(Vector3(4.25, 0, 4.25), .36), "same diagonal unprotected water admitted")
	# A valid footprint is cached: mutation is invisible until explicit rebuild.
	walk[2][2] = 0
	_check(scene.preview_jump_surface_allowed(Vector3(10.25, 0, 10.25), .36), "runtime guard uses cached bytes rather than rescanning source arrays")
	scene._cache_jump_surface_contains()
	_check(not scene.preview_jump_surface_allowed(Vector3(10.25, 0, 10.25), .36), "nonwalkable dry tile without police permission not silently admitted by palette")
	scene._block = saved_block
	scene._origin = saved_origin
	scene._cache_jump_surface_contains()
	_check(scene.preview_jump_surface_allowed(scene._player.global_position, .36), "actual native cache restored after guard fixtures")

func _scene(enabled: bool = true, path: String = "res://data/preview_water.json", block_path: String = "res://data/block.json") -> Node3D:
	var scene: Node3D = MAIN.instantiate()
	scene.preview_water_detail_enabled = enabled
	scene.water_data_path = path
	scene.block_data_path = block_path
	root.add_child(scene)
	return scene

func _dry_signature(scene: Node3D) -> Array:
	var rows: Array = []
	for node: Node in scene.get_children():
		if not node is StaticBody3D or node.has_meta("source_id") or node.get_child_count() != 1:
			continue
		var collider: CollisionShape3D = node.get_child(0) as CollisionShape3D
		if collider == null or not collider.shape is BoxShape3D:
			continue
		rows.append({"body_transform": node.transform, "shape_transform": collider.transform, "size": collider.shape.size, "layer": node.collision_layer, "mask": node.collision_mask})
	return rows

func _fixture(label: String, content: String) -> String:
	var path: String = "user://water_hook_%s_%d.json" % [label, OS.get_process_id()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	_fixtures.append(path)
	return path

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _benchmark_main(scene: Node3D) -> Dictionary:
	for i: int in range(800):
		scene._process(0.0)
	var batches: Array[float] = []
	for batch: int in range(64):
		var started: int = Time.get_ticks_usec()
		for i: int in range(100):
			scene._process(0.0)
		batches.append(float(Time.get_ticks_usec() - started) / 100.0)
	batches.sort()
	return {"batch_mean_us_p50": batches[31], "batch_mean_us_p95": batches[60], "scope": "64x100 direct main callbacks in loaded headless scene, idle player, delta0, warm600-frame ring; NOT rendered frame percentiles or FPS"}

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_errors.append(label)

func _finish() -> void:
	for path: String in _fixtures:
		_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "owned fixture removed")
	print(JSON.stringify({"passed": _errors.is_empty(), "checks": _checks, "errors": _errors, "dry_strips": _baseline.size(), "cpu": _cpu, "scope": "actual headless main admission/physics/depth/lifecycle; no GPU shader compile or LIVE/FPS acceptance"}))
	quit(0 if _errors.is_empty() else 1)
