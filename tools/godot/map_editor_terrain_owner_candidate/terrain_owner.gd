extends RefCounted
## Read-only admission of the actual checkpoint main's terrain, water and floor collision.
const MAIN_SHA := "faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const WATER_SHA := "ac70f924e1beef0f8501c48d09535a89d47effff014bf0f32b8abc72b3e3b824"

class Receipt extends RefCounted:
	var owner: RefCounted
	var main: Node3D
	var source_id: String
	var body_count: int
	var old_frame: Transform3D
	var snapshot: Array
	var surface: Dictionary
	var origin: Vector3
	var committed := false
	var released := false

	func verify() -> Dictionary:
		if released or not is_instance_valid(main) or not main.is_inside_tree() or main.is_queued_for_deletion() or not main.get_tree().paused or Engine.is_in_physics_frame(): return _no("owner-lifetime-or-pause")
		if not main.get("preview_ready") or main.get("water_status") != "detail_ready" or main.get("_block").get("surface", {}) != surface: return _no("source-or-water-drift")
		if owner.capture(main, surface) != snapshot: return _no("terrain-water-collision-drift")
		return _yes()

	func commit(change: Dictionary) -> Dictionary:
		var before := verify()
		if not before.ok or committed: return _no("receipt-stale-or-reused")
		if str(change.get("source_id", "")) != source_id or not change.get("new_frame") is Transform3D: return _no("source-or-frame-mismatch")
		if change.get("deleted", false):
			committed = true
			return _yes()
		var new_frame: Transform3D = change.new_frame
		if not new_frame.is_finite() or absf(new_frame.origin.y - old_frame.origin.y) > 0.00001: return _no("vertical-support-unverified")
		var bodies: Array[StaticBody3D] = []
		for child: Node in main.get_children():
			if child is StaticBody3D and str(child.get_meta("source_id", "")) == source_id: bodies.append(child)
		if bodies.size() != body_count: return _no("source-collider-count-drift")
		for body: StaticBody3D in bodies:
			var shapes := body.get_children().filter(func(node: Node): return node is CollisionShape3D)
			if shapes.size() != 1 or not shapes[0].shape is ConvexPolygonShape3D: return _no("source-shape-drift")
			var points: PackedVector3Array = shapes[0].shape.points
			var polygon := PackedVector2Array()
			for point: Vector3 in points:
				var world: Vector3 = body.global_transform * point
				var flat := Vector2(world.x, world.z)
				if not flat in polygon: polygon.append(flat)
			if polygon.size() < 3 or not owner.dry_footprint(polygon, surface, origin): return _no("terrain-water-or-crop-occupancy")
		committed = true
		return _yes()

	func rollback() -> Dictionary:
		# The owner changes no terrain state. Rollback releases the exact captured lease.
		var answer := verify()
		released = true
		return answer

	func _yes() -> Dictionary: return {"ok": true, "ready": true, "pending": false}
	func _no(error: String) -> Dictionary: return {"ok": false, "ready": false, "pending": false, "error": error}

static func _sha(path: String) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_bytes(path))
	return hash.finish().hex_encode()

func issue(request: Dictionary, main: Node3D) -> Dictionary:
	if not is_instance_valid(main) or not main.is_inside_tree() or main.is_queued_for_deletion() or main.get_script() != load("res://scripts/main.gd") or not main.get_tree().paused or Engine.is_in_physics_frame(): return {"ok": false, "error": "not-paused-actual-main"}
	if _sha("res://scripts/main.gd") != MAIN_SHA or _sha("res://data/block.json") != BLOCK_SHA or _sha("res://data/preview_water.json") != WATER_SHA: return {"ok": false, "error": "source-lineage-drift"}
	if int(request.get("owner_instance_id", -1)) != main.get_instance_id() or not request.get("old_frame") is Transform3D or int(request.get("body_count", 0)) < 1: return {"ok": false, "error": "request-owner-mismatch"}
	if not main.get("preview_ready") or main.get("water_status") != "detail_ready" or main.get("_water_host") == null: return {"ok": false, "error": "water-owner-unavailable"}
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	if main.get("_block") != block: return {"ok": false, "error": "live-block-drift"}
	var source_id := str(request.get("source_id", ""))
	var source_found := false
	for record: Dictionary in block.buildings:
		if str(record.get("id", "")) == source_id: source_found = true; break
	if not source_found: return {"ok": false, "error": "source-building-unavailable"}
	var visual_count := 0
	var live_body_count := 0
	for child: Node in main.get_children():
		if str(child.get_meta("source_id", "")) != source_id: continue
		if child is StaticBody3D: live_body_count += 1
		elif child is Node3D:
			visual_count += 1
			if child.global_transform != request.old_frame: return {"ok": false, "error": "source-frame-drift"}
	if visual_count != 1 or live_body_count != int(request.body_count): return {"ok": false, "error": "source-collision-owner-mismatch"}
	var surface: Dictionary = block.surface
	var snapshot := capture(main, surface)
	if snapshot.is_empty(): return {"ok": false, "error": "terrain-water-collision-owner-mismatch"}
	var token := Receipt.new()
	token.owner = self
	token.main = main
	token.source_id = source_id
	token.body_count = int(request.body_count)
	token.old_frame = request.old_frame
	token.snapshot = snapshot
	token.surface = surface.duplicate(true)
	token.origin = Vector3(block.originM[0], block.originM[1], block.originM[2])
	return {"ok": true, "token": token, "owner": "actual-main-terrain-water-collision", "terrain_strips": snapshot[0], "water_cells": 303}

static func capture(main: Node3D, surface: Dictionary) -> Array:
	if not is_instance_valid(main) or main.get("water_status") != "detail_ready": return []
	var host: RefCounted = main.get("_water_host")
	if host == null or not bool(host.get("_built")): return []
	var water: MeshInstance3D = host.get("_instance")
	if not is_instance_valid(water) or water.get_parent() != main or water.name != "SourceNativeWater" or water.mesh == null or int(host.get("_cell_count")) != 303: return []
	var grid: Array = surface.grid
	var cell := float(surface.cellSize)
	var origin: Vector3 = main.get("_origin")
	var groups: Dictionary = {}
	var strips: Array = []
	for row in grid.size():
		for tile_col in grid[row].size():
			var tile_key := str(int(grid[row][tile_col]))
			if not groups.has(tile_key): groups[tile_key] = []
			groups[tile_key].append(Vector3((int(surface.startCol) + tile_col + 0.5) * cell - origin.x, float(surface.palette[tile_key].heightM) - 0.02, (int(surface.startRow) + row + 0.5) * cell - origin.z))
		var col := 0
		while col < grid[row].size():
			var key := str(int(grid[row][col]))
			if not bool(surface.palette[key].solid): col += 1; continue
			var first := col
			while col < grid[row].size() and str(int(grid[row][col])) == key: col += 1
			strips.append([Vector3((int(surface.startCol) + (first + col) * 0.5) * cell - origin.x, float(surface.palette[key].heightM) - 0.08, (int(surface.startRow) + row + 0.5) * cell - origin.z), Vector3((col - first) * cell, 0.16, cell)])
	var actual: Array = []
	for child: Node in main.get_children():
		if child is StaticBody3D and not child.has_meta("source_id"):
			if child.get_child_count() != 1 or not child.get_child(0) is CollisionShape3D: return []
			var shape: CollisionShape3D = child.get_child(0)
			if not shape.shape is BoxShape3D or shape.disabled: return []
			actual.append([child, child.get_instance_id(), child.get_parent(), child.transform, child.collision_layer, child.collision_mask, shape, shape.get_instance_id(), shape.shape, shape.shape.size, shape.disabled])
	if actual.size() != strips.size(): return []
	for index in strips.size():
		if actual[index][3] != Transform3D(Basis.IDENTITY, strips[index][0]) or actual[index][9] != strips[index][1] or actual[index][4] != 1 or actual[index][5] != 1: return []
	var visuals: Array = []
	for child: Node in main.get_children():
		if not child is MultiMeshInstance3D or not child.name.begins_with("Surface_"): continue
		var multi: MultiMesh = child.multimesh
		if multi == null or not multi.mesh is BoxMesh: return []
		var matched := false
		for tile_key: String in groups:
			if tile_key == "16": continue
			if child.name != "Surface_" + str(surface.palette[tile_key].kind): continue
			if multi.instance_count != groups[tile_key].size() or multi.mesh.size != Vector3(cell, 0.04, cell): return []
			matched = true
			break
		if not matched: return []
		visuals.append([child, child.get_instance_id(), child.transform, child.visible, multi, multi.mesh, multi.mesh.size, multi.mesh.material, multi.instance_count, multi.buffer])
	if visuals.size() != groups.size() - 1: return []
	var water_mesh: ArrayMesh = water.mesh
	var water_material: ShaderMaterial = water_mesh.surface_get_material(0)
	if water_mesh.get_surface_count() != 1 or water_material == null: return []
	var water_params: Array = []
	for name: String in ["source_origin_m", "use_vertex_depth", "default_depth", "environmentShallow", "environmentDeep", "environmentShore", "environmentTime", "environmentRipples"]:
		water_params.append(water_material.get_shader_parameter(name))
	return [strips.size(), actual, host, host.get_instance_id(), water, water.get_instance_id(), water.transform, water.visible, water_mesh, water_mesh.surface_get_arrays(0), water_material, water_material.shader, water_params, main.get("water_summary").duplicate(true), surface.duplicate(true), visuals]

static func dry_footprint(polygon: PackedVector2Array, surface: Dictionary, origin: Vector3) -> bool:
	var cell := float(surface.cellSize)
	var min_col := int(floorf((polygon[0].x + origin.x) / cell))
	var max_col := min_col
	var min_row := int(floorf((polygon[0].y + origin.z) / cell))
	var max_row := min_row
	for point: Vector2 in polygon:
		var col := int(floorf((point.x + origin.x) / cell))
		var row := int(floorf((point.y + origin.z) / cell))
		min_col = mini(min_col, col); max_col = maxi(max_col, col)
		min_row = mini(min_row, row); max_row = maxi(max_row, row)
	if min_col < int(surface.startCol) or max_col >= int(surface.startCol) + int(surface.cols) or min_row < int(surface.startRow) or max_row >= int(surface.startRow) + int(surface.rows): return false
	for row in range(min_row, max_row + 1):
		for col in range(min_col, max_col + 1):
			var tile: String = str(int(surface.grid[row - int(surface.startRow)][col - int(surface.startCol)]))
			if bool(surface.palette[tile].solid): continue
			var x := col * cell - origin.x
			var z := row * cell - origin.z
			var square := PackedVector2Array([Vector2(x,z), Vector2(x+cell,z), Vector2(x+cell,z+cell), Vector2(x,z+cell)])
			for intersection: PackedVector2Array in Geometry2D.intersect_polygons(polygon, square):
				if intersection.size() >= 3 and absf(_area(intersection)) > 0.000001: return false
	return true

static func _area(polygon: PackedVector2Array) -> float:
	var value := 0.0
	for index in polygon.size():
		var next := (index + 1) % polygon.size()
		value += polygon[index].x * polygon[next].y - polygon[next].x * polygon[index].y
	return value * 0.5
