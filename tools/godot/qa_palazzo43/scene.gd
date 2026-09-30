extends SceneTree
## Bounded observational integration fixture. No engine was run by its author.
## No teleport, fake damage, invented terminal, door request, or input injection.
const SOURCE_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const WATER_SHA := "ac70f924e1beef0f8501c48d09535a89d47effff014bf0f32b8abc72b3e3b824"
const NPC_IDS := ["resident_72", "resident_169", "resident_252"]
var game: Node3D
var out := "user://palazzo_only43_qa"
var started := 0
var done := false
var failures := 0
var checks: Array[Dictionary] = []
var evidence: Dictionary = {"native": "RUNNING", "combat": "NOT_TESTED", "door_toggle_and_walkthrough": "OWNER_FIXTURE_REQUIRED", "performance": "NOT_MEASURED", "captures": []}

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa43-out="): out = arg.trim_prefix("--qa43-out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec() - started > 45000:
		check(false, "bounded_45s_deadline")
		_finish()
	return false

func check(ok: bool, label: String, detail: Variant = null) -> bool:
	checks.append({"pass": ok, "check": label, "detail": detail})
	if not ok: failures += 1
	print("QA43 ", "PASS " if ok else "FAIL ", label, " ", detail)
	return ok

func _nodes() -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [game]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		result.append(node)
		for child: Node in node.get_children(): pending.append(child)
	return result

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if not check(scene != null, "main_scene_load"): _finish(); return
	game = scene.instantiate() as Node3D
	if not check(game != null, "main_scene_node"): _finish(); return
	root.add_child(game)
	current_scene = game
	for frame in 1200:
		if done: return
		if bool(game.get("preview_ready")): break
		await process_frame
	if not check(bool(game.get("preview_ready")), "preview_ready", game.get("validation_errors")): _finish(); return
	await physics_frame
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	check(FileAccess.get_sha256("res://data/block.json") == SOURCE_SHA, "original_block_bytes_unchanged")
	check(source.buildings.size() == 8 and source.decor.size() == 8, "frozen_source_has_8_buildings_8_decor")
	check(game.get_meta("preview_building_mode", "") == "palazzo_only43", "explicit_building_mode")
	var helper: Script = load("res://scripts/palazzo_only_preview.gd")
	var block: Dictionary = game.get("_block")
	check(helper.is_current(source, block), "derived_block_exact_helper_contract")
	var validator: Script = load("res://scripts/preview_block_validation.gd")
	check(validator.validate(block).is_empty(), "derived_block_valid")
	check(block.buildings.is_empty() and int(block.counts.buildings) == 0, "derived_building_count_zero")
	check(block.decor == source.decor and block.surface == source.surface and block.hero == source.hero, "decor_terrain_hero_data_preserved")
	var legacy_ids: Array[String] = []
	var legacy_paths: Array[String] = []
	for row: Dictionary in source.buildings:
		legacy_ids.append(str(row.id)); legacy_paths.append(str(row.path))
	var offenders: Array[String] = []
	var decor_roots: Dictionary = {}
	var decor_colliders := 0
	var terrain_instances := 0
	var terrain_strips := 0
	var nodes := _nodes()
	for node: Node in nodes:
		var id := str(node.get_meta("source_id", ""))
		var script: Script = node.get_script() as Script
		var script_path := script.resource_path if script != null else ""
		if id in legacy_ids or str(node.name) in legacy_ids or node.scene_file_path in legacy_paths or str(node.name) in ["PrintshopInterior", "Modular30Host"] or script_path.ends_with("/modular30_host.gd") or script_path.ends_with("/preview_printshop_interior.gd"):
			offenders.append(str(node.get_path()))
		for record: Dictionary in source.decor:
			if id == str(record.id):
				if node is PhysicsBody3D: decor_colliders += 1
				elif node.get_parent() == game: decor_roots[id] = true
		if node.get_parent() == game and node is MultiMeshInstance3D and str(node.name).begins_with("Surface_"):
			terrain_instances += node.multimesh.instance_count
		if node.get_parent() == game and node is StaticBody3D and not node.has_meta("source_id"):
			for child: Node in node.get_children():
				if child is CollisionShape3D and child.shape is BoxShape3D and is_equal_approx(child.shape.size.y, 0.16): terrain_strips += 1
	check(offenders.is_empty(), "legacy_visuals_colliders_interiors_modular_absent", offenders)
	check(not is_instance_valid(game.get("_printshop")) and not is_instance_valid(game.get("preview_modular30")), "removed_owner_references_absent")
	check(decor_roots.size() == 8, "actual_decor_roots_eight", decor_roots.keys())
	check(decor_colliders == int(block.counts.collisionBodies), "actual_decor_colliders_preserved", decor_colliders)
	var expected_strips := 0
	var expected_cells := 0
	for row: Array in source.surface.grid:
		var previous := ""
		for tile: Variant in row:
			var key := str(int(tile))
			expected_cells += 1
			if bool(source.surface.palette[key].solid) and key != previous: expected_strips += 1
			previous = key
	var detailed_water_cells := _check_water(source, nodes)
	check(terrain_instances == expected_cells - detailed_water_cells, "terrain_visual_cells_preserved", {"actual_boxes": terrain_instances, "expected_boxes": expected_cells - detailed_water_cells, "detailed_water_cells": detailed_water_cells, "source_total": expected_cells})
	check(terrain_strips == expected_strips, "terrain_collision_strips_preserved", {"actual": terrain_strips, "expected": expected_strips})
	check(game.get_node_or_null("PalazzoGroundExtension") != null, "palazzo_ground_retained")
	var host: Node = game.get("preview_palazzo")
	if not check(is_instance_valid(host) and host.get("status") == "ready", "palazzo_ready"): _finish(); return
	var site: Node3D = host.get("site")
	if not check(is_instance_valid(site), "actual_palazzo_site"): _finish(); return
	var sites := 0
	for node: Node in nodes:
		if node.get_script() == site.get_script(): sites += 1
	check(sites == 1, "actual_palazzo_exactly_one", sites)
	evidence["palazzo"] = host.snapshot()
	var transport: Node = game.get("preview_transport")
	var weapons: Node = game.get("preview_weapons")
	var c4: Node = game.get("preview_c4")
	check(is_instance_valid(transport) and bool(transport.get("ready_for_play")), "transport_ready")
	check(is_instance_valid(weapons) and bool(weapons.get("ready_for_play")) and weapons._owner_current(), "weapon_owner_ready")
	check(is_instance_valid(c4) and bool(c4.snapshot().get("ready", false)), "c4_owner_ready")
	var population: RefCounted = game.get("preview_population")
	if not check(population != null and population.get("status") == "ready", "population_ready"): _finish(); return
	var residents: RefCounted = population.get("residents")
	var initial: Dictionary = residents.snapshot()
	var first: Dictionary = {}
	var maximum: Dictionary = {}
	for row: Dictionary in initial.rows:
		if not check(row.position is Vector3 and row.position.is_finite(), "npc_live_position:" + str(row.source_id)): continue
		first[str(row.source_id)] = row.position
		maximum[str(row.source_id)] = 0.0
	check(first.size() == 3 and first.has_all(NPC_IDS), "original_three_npc_ids", first.keys())
	var owners: Array = population.get("hit_owners")
	var owner_ids: Array[String] = []
	for owner: RefCounted in owners:
		var row: Dictionary = owner.snapshot().get("row", {})
		owner_ids.append(str(row.get("source_id", "")))
		check(not owner._current(owner.get("_binding")).is_empty(), "hp_owner_current:" + str(row.get("source_id", "")))
	check(owners.size() == 3 and owner_ids.has("resident_72") and owner_ids.has("resident_169") and owner_ids.has("resident_252") and population.get("combat_status") == "new_local_session", "three_hp_owners_bound", owner_ids)
	evidence["population_before"] = population.snapshot()
	var observe_until := Time.get_ticks_msec() + 6500
	while Time.get_ticks_msec() < observe_until and not done:
		await physics_frame
		var observed: Dictionary = residents.snapshot()
		for row: Dictionary in observed.rows:
			var id := str(row.source_id)
			if first.has(id) and row.position is Vector3:
				maximum[id] = maxf(float(maximum[id]), first[id].distance_to(row.position))
	if done: return
	for id: String in NPC_IDS: check(float(maximum.get(id, 0.0)) > 0.025, "npc_observed_movement:" + id, maximum.get(id, 0.0))
	evidence["population_after"] = population.snapshot()
	evidence["npc_max_displacement_m"] = maximum
	# This samples the user's real startup position; it never moves the actor.
	var owner_action: Dictionary = host.door_action()
	var world_action: Dictionary = game._current_door_action()
	check(owner_action == world_action, "door_router_matches_owner_without_printshop")
	evidence["door_access_at_start"] = "OBSERVED" if not owner_action.is_empty() else "NOT_OBSERVED_NO_TELEPORT"
	evidence["door_action"] = owner_action
	var main_text := FileAccess.get_file_as_string("res://scripts/main.gd")
	var door_body := main_text.get_slice("func _current_door_action()", 1).get_slice("\nfunc ", 0)
	var tick_body := main_text.get_slice("func _physics_process(", 1).get_slice("\nfunc ", 0)
	check(door_body.contains("preview_palazzo.door_action()") and not door_body.contains("or not is_instance_valid(_printshop)"), "door_access_not_gated_by_missing_printshop")
	check(tick_body.contains("preview_population.step(delta)") and not tick_body.contains("or not is_instance_valid(_printshop)"), "population_tick_not_gated_by_missing_printshop")
	await _capture_wide(site)
	_finish()

func _check_water(source: Dictionary, nodes: Array[Node]) -> int:
	# Independent source footprint and actual triangle coverage, not just a count
	# exception: detailed water must replace every omitted tile16 exactly once.
	var expected: Dictionary = {}
	for r in source.surface.grid.size():
		for c in source.surface.grid[r].size():
			if int(source.surface.grid[r][c]) == 16:
				expected[Vector2i(int(source.surface.startRow) + r, int(source.surface.startCol) + c)] = true
	var water_nodes: Array[Node] = []
	for node: Node in nodes:
		if str(node.name) == "SourceNativeWater": water_nodes.append(node)
	var status := str(game.get("water_status"))
	var host: RefCounted = game.get("_water_host")
	var requested := bool(game.get("preview_water_detail_enabled")) and not OS.get_cmdline_user_args().has("--preview-water-off")
	evidence["water"] = {"status": status, "source_cells": expected.size(), "summary": game.get("water_summary"), "errors": game.get("water_errors")}
	check(status == "detail_ready" if requested else status == "baseline_disabled", "water_requested_mode_ready", status)
	if status != "detail_ready":
		check(water_nodes.is_empty() and host == null, "baseline_water_has_no_duplicate_detail_mesh")
		return 0
	var active := host != null and bool(host.get("_built"))
	check(active, "detailed_water_host_active")
	if active: check(int(host.get("_cell_count")) == expected.size(), "water_host_cell_count")
	var summary: Dictionary = game.get("water_summary")
	check(bool(summary.get("ok", false)) and int(summary.get("cells", -1)) == expected.size() and int(summary.get("vertices", -1)) == expected.size() * 6 and int(summary.get("triangles", -1)) == expected.size() * 2 and int(summary.get("mesh_instances", -1)) == 1, "water_summary_matches_source_footprint", summary)
	var text := FileAccess.get_file_as_string(str(game.get("water_data_path"))).replace("\r\n", "\n")
	check(text.sha256_text() == WATER_SHA, "original_water_package_unchanged")
	var data: Variant = JSON.parse_string(text)
	if not check(data is Dictionary and data.get("native") is Dictionary, "water_package_readable"): return expected.size()
	var declared: Dictionary = {}
	var duplicate_cells := 0
	for cell: Dictionary in data.native.cells:
		var key := Vector2i(int(cell.r), int(cell.c))
		if declared.has(key): duplicate_cells += 1
		declared[key] = true
	check(declared == expected and duplicate_cells == 0, "water_package_exact_block_cells", {"declared": declared.size(), "duplicates": duplicate_cells})
	if not check(water_nodes.size() == 1 and water_nodes[0] is MeshInstance3D, "actual_water_mesh_exactly_one", water_nodes.size()): return expected.size()
	var instance: MeshInstance3D = water_nodes[0] as MeshInstance3D
	check(active and host.get("_instance") == instance and instance.get_parent() == game and instance.is_visible_in_tree(), "water_mesh_owned_live_visible")
	if not check(instance.mesh is ArrayMesh and instance.mesh.get_surface_count() == 1, "water_actual_single_array_surface"): return expected.size()
	check(instance.mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES and instance.get_active_material(0) is ShaderMaterial, "water_actual_triangle_shader_surface")
	var arrays: Array = instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	check(vertices.size() == expected.size() * 6 and indices.size() == expected.size() * 6, "water_actual_vertex_index_counts", {"vertices": vertices.size(), "indices": indices.size()})
	var origin := Vector3(source.originM[0], source.originM[1], source.originM[2])
	var size: float = source.surface.cellSize
	var level: float = source.surface.palette["16"].heightM
	var coverage: Dictionary = {}
	var errors: Array[String] = []
	for offset in range(0, indices.size() - 2, 3):
		var triangle: Array[Vector3] = []
		for j in 3:
			var index := int(indices[offset + j])
			if index < 0 or index >= vertices.size():
				errors.append("index_out_of_bounds"); break
			triangle.append(instance.global_transform * vertices[index] + origin)
		if triangle.size() != 3: continue
		var center: Vector3 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
		var key := Vector2i(floori(center.z / size), floori(center.x / size))
		if not expected.has(key): errors.append("triangle_outside_source_water:" + str(key)); continue
		var corners: Array[int] = []
		for point: Vector3 in triangle:
			var dx: float = point.x - float(key.y) * size
			var dz: float = point.z - float(key.x) * size
			if not point.is_finite() or absf(point.y - level) > 0.0001 or minf(absf(dx), absf(dx - size)) > 0.0002 or minf(absf(dz), absf(dz - size)) > 0.0002:
				errors.append("vertex_not_source_cell_corner:" + str(key))
			corners.append((1 if dx > size * 0.5 else 0) + (2 if dz > size * 0.5 else 0))
		corners.sort()
		var area := absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).y) * 0.5
		if absf(area - size * size * 0.5) > 0.001: errors.append("triangle_area:" + str(key))
		if not coverage.has(key): coverage[key] = {"triangles": [], "corners": {}}
		var record: Dictionary = coverage[key]
		if record.triangles.has(corners): errors.append("duplicate_triangle:" + str(key))
		record.triangles.append(corners)
		for corner: int in corners: record.corners[corner] = true
	for key: Vector2i in expected:
		if not coverage.has(key) or coverage[key].triangles.size() != 2 or coverage[key].corners.size() != 4:
			errors.append("incomplete_cell:" + str(key))
			continue
		var pair: Array = coverage[key].triangles
		var shared: Array[int] = []
		for corner: int in pair[0]:
			if pair[1].has(corner): shared.append(corner)
		# Two complementary triangles share a diagonal, never an outside edge.
		if shared.size() != 2 or shared[0] + shared[1] != 3:
			errors.append("non_complementary_cell_triangles:" + str(key))
	check(errors.is_empty() and coverage.size() == expected.size(), "actual_water_triangles_cover_each_source_cell", {"covered_cells": coverage.size(), "errors": errors.slice(0, 12), "error_count": errors.size()})
	evidence.water["actual_covered_cells"] = coverage.size()
	return expected.size()

func _capture_wide(site: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		evidence["captures_status"] = "NOT_RUN_HEADLESS"
		return
	var previous: Camera3D = root.get_camera_3d()
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 600.0
	game.add_child(camera)
	var views := [{"name": "wide_palazzo.png", "position": site.to_global(Vector3(38, 24, 38)), "target": site.to_global(Vector3(0, 5, 0))}, {"name": "wide_empty_block.png", "position": Vector3(-65, 92, 115), "target": Vector3(15, 0, 0)}]
	for view: Dictionary in views:
		camera.global_position = view.position
		camera.look_at(view.target)
		camera.make_current()
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path := out.path_join(str(view.name))
		var result := ERR_CANT_CREATE if image == null or image.is_empty() else image.save_png(path)
		check(result == OK, "gpu_capture:" + str(view.name), result)
		evidence.captures.append({"path": ProjectSettings.globalize_path(path), "camera": view, "saved": result == OK, "visual_review": "PENDING_HUMAN_OR_ROOT_INSPECTION"})
	if is_instance_valid(previous): previous.make_current()
	camera.queue_free()
	evidence["captures_status"] = "SAVED_REVIEW_REQUIRED"

func _finish() -> void:
	if done: return
	done = true
	evidence["native"] = "PASS" if failures == 0 else "FAIL"
	evidence["failures"] = failures
	evidence["checks"] = checks
	evidence["elapsed_ms"] = Time.get_ticks_msec() - started
	evidence["engine"] = Engine.get_version_info()
	evidence["renderer"] = RenderingServer.get_current_rendering_method()
	var file := FileAccess.open(out.path_join("report43.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(evidence, "\t")); file.close()
	else: failures += 1; push_error("QA43 report write failed: " + out)
	print("QA43_FINISHED failures=", failures, " report=", ProjectSettings.globalize_path(out.path_join("report43.json")))
	quit(0 if failures == 0 else 1)
