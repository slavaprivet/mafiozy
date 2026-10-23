extends SceneTree
## Independent actual-scene/physics acceptance for the first exported block.
## Run headless. This does not certify pixels, frame rate, or migrated gameplay.

const SCENE_PATH: String = "res://scenes/main.tscn"
const BLOCK_PATH: String = "res://data/block.json"
const EXPECTED_IDS: Array[String] = [
	"REBUILD-VISUAL-print_shop-001",
	"REBUILD-VISUAL-old_town_narrow_townhouse_v1-013",
	"REBUILD-VISUAL-old_town_narrow_townhouse_v1-005",
	"REBUILD-VISUAL-gun_shop-001",
	"REBUILD-VISUAL-pawnshop-001",
	"REBUILD-VISUAL-old_town_narrow_townhouse_v1-004",
	"REBUILD-VISUAL-old_town_narrow_townhouse_v1-012",
	"REBUILD-VISUAL-old_town_narrow_townhouse_v1-007",
	"LAMP-1-83", "LAMP-15-78", "LAMP-19-97", "LAMP-21-84",
	"LAMP-29-79", "LAMP-30-98", "LAMP-9-102", "LAMP-9-84",
]

var _failures: Array[String] = []
var _block: Dictionary
var _world: Node3D
var _origin: Vector3
var _space: PhysicsDirectSpaceState3D
var _player: CharacterBody3D
var _asset_bodies: Array[StaticBody3D] = []
var _ground_exclusions: Array[RID] = []
var _all_body_rids: Array[RID] = []
var _report: Dictionary = {"test": "actual_preview_block", "live": false, "fps": false}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BLOCK_PATH))
	if not parsed is Dictionary:
		_check(false, "block JSON must be a dictionary")
		_finish()
		return
	_block = parsed
	_check(str(_block.get("schema", "")) == "mafiozi.godot.preview-block/v1", "known test fixture schema")
	_origin = _vector(_block["originM"])
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		_check(false, "actual root scene imports")
		_finish()
		return
	_world = packed.instantiate() as Node3D
	root.add_child(_world)
	await _frames(60)
	_check(bool(_world.get("preview_ready")) and _world.get("validation_errors").is_empty(), "actual scene passes admission before readiness")
	_space = _world.get_world_3d().direct_space_state
	for child: Node in _world.get_children():
		if child is StaticBody3D:
			_all_body_rids.append(child.get_rid())
			if child.has_meta("source_id"):
				_asset_bodies.append(child)
				_ground_exclusions.append(child.get_rid())
		elif child is CharacterBody3D:
			_check(_player == null, "only one preview player")
			_player = child
	if _player != null:
		_ground_exclusions.append(_player.get_rid())
		_all_body_rids.append(_player.get_rid())
	_check_assets()
	_check_source_colliders()
	_check_surface()
	_check_player()
	_report["negative_admission_tests"] = "test_preview_admission.gd covers actual main scene rejection"
	_finish()


func _check_assets() -> void:
	var records: Array = _block["buildings"] + _block["decor"]
	_check(_block["buildings"].size() == 8 and _block["decor"].size() == 8, "fixture retains eight buildings and eight lamps")
	var ids: Array[String] = []
	var material_surfaces: int = 0
	var hidden_helpers: int = 0
	var hashed: Dictionary = {}
	for record: Dictionary in records:
		var id: String = str(record["id"])
		_check(not ids.has(id), "unique record ID " + id)
		ids.append(id)
		var holders: Array[Node3D] = []
		for child: Node in _world.get_children():
			if child is Node3D and not child is CollisionObject3D and str(child.get_meta("source_id", "")) == id:
				holders.append(child)
		_check(holders.size() == 1, "one actual visual with source ID " + id)
		if holders.size() != 1:
			continue
		var holder: Node3D = holders[0]
		_check(str(holder.name) == id and holder.get_parent() == _world, "stable root visual name " + id)
		_check(holder.get_child_count() == 1, "one authored scene under " + id)
		if holder.get_child_count() != 1:
			continue
		var visual: Node3D = holder.get_child(0) as Node3D
		var transform_data: Dictionary = record["transform"]
		var source_position: Vector3 = _vector(transform_data["positionM"])
		_check(holder.global_position.distance_to(source_position - _origin) < 0.0002, "source origin conversion " + id)
		_check(holder.position.distance_to(_vector(record["positionLocalM"])) < 0.0002, "export local position " + id)
		var offset: Vector3 = _vector(transform_data["modelLocalOffsetM"])
		_check(visual.position.distance_to(offset) < 0.00001, "authored model local offset " + id)
		# Compare independently expanded source-coordinate witnesses, not main._v3
		# or its parent transform. These catch wrong yaw, scale, or offset order.
		for probe: Vector3 in [Vector3.ZERO, Vector3(1.2, 0.8, -0.7), Vector3(-0.6, 2.1, 1.3)]:
			var expected: Vector3 = _source_visual_point(transform_data, probe)
			_check(visual.to_global(probe).distance_to(expected) < 0.0003, "TRS witness " + id)
		var resource_path: String = str(record["path"])
		_check(visual.scene_file_path == resource_path, "actual imported resource binding " + id)
		if not hashed.has(resource_path):
			hashed[resource_path] = FileAccess.get_sha256(resource_path)
		_check(str(hashed[resource_path]) == str(record["binding"]["sha256"]), "exact GLB source bytes " + id)
		var original: Node3D = (load(resource_path) as PackedScene).instantiate() as Node3D
		var visible_meshes: int = 0
		for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			var reference: MeshInstance3D = original.get_node_or_null(visual.get_path_to(mesh)) as MeshInstance3D
			_check(reference != null, "authored mesh path " + id + "/" + str(mesh.name))
			if reference == null or mesh.mesh == null:
				continue
			_check(mesh.mesh == reference.mesh, "imported geometry unchanged " + id)
			if mesh.is_visible_in_tree():
				visible_meshes += 1
			for surface: int in range(mesh.mesh.get_surface_count()):
				var actual: Material = mesh.get_active_material(surface)
				var authored: Material = reference.get_active_material(surface)
				_check(actual != null and actual == authored, "authored asset material preserved " + id)
				material_surfaces += 1
		_check(visible_meshes > 0, "visible authored geometry " + id)
		for expected_name: String in record.get("effectiveHiddenNodeNames", []):
			for node: Node in visual.find_children("*", "Node3D", true, false):
				if str(node.name) in [expected_name, expected_name.validate_node_name()]:
					_check(not node.visible, "non-rendered source helper " + expected_name)
					hidden_helpers += 1
		original.free()
	var stable_ids: Array[String] = EXPECTED_IDS.duplicate()
	ids.sort()
	stable_ids.sort()
	_check(ids == stable_ids, "exact stable checkpoint ID set")
	_report["assets"] = {"buildings": 8, "decor": 8, "unique_hashed_glbs": hashed.size(), "authored_material_surfaces": material_surfaces, "hidden_helper_matches": hidden_helpers}


func _source_visual_point(data: Dictionary, local: Vector3) -> Vector3:
	var point: Vector3 = local + _vector(data["modelLocalOffsetM"])
	var horizontal: Array = data["horizontalScale"]
	var scale_value: float = float(data["uniformScale"])
	point *= Vector3(float(horizontal[0]) * scale_value, scale_value, float(horizontal[1]) * scale_value)
	var angle: float = deg_to_rad(float(data["yawDegrees"]))
	var rotated: Vector3 = Vector3(cos(angle) * point.x + sin(angle) * point.z, point.y, -sin(angle) * point.x + cos(angle) * point.z)
	return _vector(data["positionM"]) - _origin + rotated


func _check_source_colliders() -> void:
	_check(_asset_bodies.size() == 27, "exactly 27 exported world colliders")
	var count: int = 0
	for record: Dictionary in _block["buildings"] + _block["decor"]:
		var bodies: Array[StaticBody3D] = []
		for body: StaticBody3D in _asset_bodies:
			if str(body.get_meta("source_id")) == str(record["id"]):
				bodies.append(body)
		# Use retained original world polygonCR instead of the runtime's polygonXZ.
		var source_bodies: Array = record["collision"]["worldBodies"]
		_check(bodies.size() == source_bodies.size(), "source collider membership " + str(record["id"]))
		for index: int in range(mini(bodies.size(), source_bodies.size())):
			var body: StaticBody3D = bodies[index]
			var data: Dictionary = source_bodies[index]
			_check(body.get_parent() == _world and body.global_transform.is_equal_approx(Transform3D.IDENTITY), "world-space collider is not transformed twice")
			var center: Vector3 = Vector3.ZERO
			var min_x: float = INF
			for point: Array in data["polygonCR"]:
				var world_point: Vector3 = Vector3(float(point[0]) * float(_block["metresPerCell"]), 0.0, float(point[1]) * float(_block["metresPerCell"])) - _origin
				center += world_point
				min_x = minf(min_x, world_point.x)
			center /= float(data["polygonCR"].size())
			var bottom: float = float(data["minYM"]) - _origin.y
			var top: float = float(data["maxYM"]) - _origin.y
			var exclusions: Array[RID] = _all_body_rids.duplicate()
			exclusions.erase(body.get_rid())
			var roof: Dictionary = _ray(Vector3(center.x, top + 0.5, center.z), Vector3(center.x, bottom - 0.1, center.z), exclusions)
			_check(not roof.is_empty() and roof.get("collider") == body, "actual physical hull at source centroid " + str(record["id"]))
			if not roof.is_empty():
				_check(absf(roof["position"].y - top) < 0.006, "source collider top height")
			var side: Dictionary = _ray(Vector3(min_x - 0.25, (top + bottom) * 0.5, center.z), Vector3(center.x, (top + bottom) * 0.5, center.z), exclusions)
			_check(not side.is_empty() and side.get("collider") == body, "physical side wall at original polygon")
			if not side.is_empty():
				_check(absf(side["position"].x - min_x) < 0.006, "source collider side coordinate")
			count += 1
	_report["physics_asset_hulls"] = {"tested": count, "ray_probes": count * 2, "reference": "retained source worldBodies polygonCR, not runtime polygonXZ"}


func _check_surface() -> void:
	var surface: Dictionary = _block["surface"]
	var grid: Array = surface["grid"]
	var palette: Dictionary = surface["palette"]
	var counts: Dictionary = {}
	var dry: int = 0
	var wet: int = 0
	var coast_edges: int = 0
	var cell: float = float(surface["cellSize"])
	for row: int in range(grid.size()):
		for column: int in range(grid[row].size()):
			var key: String = str(int(grid[row][column]))
			counts[key] = int(counts.get(key, 0)) + 1
			var definition: Dictionary = palette[key]
			var point: Vector3 = _cell_center(row, column)
			var ground: Dictionary = _ray(point + Vector3(0, 2, 0), point - Vector3(0, 2, 0), _ground_exclusions)
			if bool(definition["solid"]):
				dry += 1
				_check(not ground.is_empty(), "dry source tile has physical ground")
				if not ground.is_empty():
					_check(absf(ground["position"].y - float(definition["heightM"])) < 0.006, "dry tile physical height")
			else:
				wet += 1
				_check(ground.is_empty(), "water source tile has no solid ground")
			if column + 1 < grid[row].size():
				var next_key: String = str(int(grid[row][column + 1]))
				if bool(definition["solid"]) != bool(palette[next_key]["solid"]):
					var boundary: Vector3 = point + Vector3(cell * 0.5, 0, 0)
					for side: float in [-0.03, 0.03]:
						var sample: Vector3 = boundary + Vector3(side, 0, 0)
						var hit: Dictionary = _ray(sample + Vector3(0, 2, 0), sample - Vector3(0, 2, 0), _ground_exclusions)
						var expect_ground: bool = bool(definition["solid"]) if side < 0 else bool(palette[next_key]["solid"])
						_check((not hit.is_empty()) == expect_ground, "shoreline exact dry/water boundary")
					coast_edges += 1
	_check(dry == 658 and wet == 303, "checkpoint source crop retains 658 dry and 303 water cells")
	_check(coast_edges > 0, "actual mixed shoreline probed")
	for key: String in counts:
		var definition: Dictionary = palette[key]
		var instance: MultiMeshInstance3D = _world.get_node_or_null("Surface_" + str(definition["kind"])) as MultiMeshInstance3D
		_check(instance != null, "declared surface material group " + key)
		if instance == null:
			continue
		_check(instance.multimesh.instance_count == int(counts[key]), "surface visual instance count matches source cells")
		var material: Material = instance.multimesh.mesh.surface_get_material(0)
		var base: BaseMaterial3D = material as BaseMaterial3D
		if material is ShaderMaterial:
			# Native environment shader replaces the flat preview material. Its
			# source base descriptor and recentering contract remain observable.
			base = material.get_meta("source_base_material", null) as BaseMaterial3D
			_check(material.get_shader_parameter("source_origin_m").is_equal_approx(_origin), "native surface preserves source pattern origin")
		var expected_color: Color = Color(str(definition["colorSrgb"]))
		if key == "0":
			for descriptor: Dictionary in surface.get("materialDescriptors", []):
				if descriptor.get("id") == "MAT_CLAY_ASPHALT_CLEAN":
					var factor: Array = descriptor["baseColorFactor"]
					expected_color = Color(float(factor[0]), float(factor[1]), float(factor[2]), float(factor[3])).linear_to_srgb()
		_check(base != null and base.albedo_color.is_equal_approx(expected_color), "declared native base surface colour " + key)
		_check(instance.multimesh.mesh is BoxMesh and absf(instance.multimesh.mesh.size.x - cell) < 0.0001 and absf(instance.multimesh.mesh.size.z - cell) < 0.0001, "surface cell footprint scale")
	var middle_row: int = grid.size() / 2
	var middle_col: int = grid[0].size() / 2
	var outside: Array[Vector3] = [
		_cell_center(middle_row, 0) - Vector3(cell * 0.5 + 0.03, 0, 0),
		_cell_center(middle_row, grid[0].size() - 1) + Vector3(cell * 0.5 + 0.03, 0, 0),
		_cell_center(0, middle_col) - Vector3(0, 0, cell * 0.5 + 0.03),
		_cell_center(grid.size() - 1, middle_col) + Vector3(0, 0, cell * 0.5 + 0.03),
	]
	for point: Vector3 in outside:
		_check(_ray(point + Vector3(0, 2, 0), point - Vector3(0, 2, 0), _ground_exclusions).is_empty(), "no invented ground beyond crop boundary")
	_report["surface"] = {"dry_cell_center_probes": dry, "water_cell_center_probes": wet, "shore_edges": coast_edges, "outside_boundary_probes": 4}


func _check_player() -> void:
	_check(_player != null, "actual root scene creates player")
	if _player == null:
		return
	var status: Dictionary = _player.get_preview_status()
	_check(bool(status.get("model_loaded", false)), "actual authored hero loaded")
	_check(_player.is_on_floor(), "actual hero settles onto real block floor")
	var spawn: Vector3 = _vector(_block["hero"]["spawnLocalM"])
	_check(Vector2(_player.position.x - spawn.x, _player.position.z - spawn.z).length() < 0.001, "settling does not relocate hero horizontally")
	var floor_hit: Dictionary = _ray(_player.global_position + Vector3(0, 0.25, 0), _player.global_position - Vector3(0, 0.4, 0), _ground_exclusions)
	_check(not floor_hit.is_empty(), "spawn is supported by actual dry floor")
	if not floor_hit.is_empty():
		_check(absf(_player.global_position.y - floor_hit["position"].y) < 0.015, "capsule feet touch physical ground height")
	_check(_player.velocity.is_finite() and absf(_player.velocity.y) < 0.01, "settled finite vertical motion")
	_report["player"] = {"grounded": _player.is_on_floor(), "position": [_player.position.x, _player.position.y, _player.position.z], "model_loaded": status.get("model_loaded", false)}


func _cell_center(row: int, column: int) -> Vector3:
	var surface: Dictionary = _block["surface"]
	var cell: float = float(surface["cellSize"])
	return Vector3((float(surface["startCol"]) + float(column) + 0.5) * cell - _origin.x, 0, (float(surface["startRow"]) + float(row) + 0.5) * cell - _origin.z)


func _ray(from: Vector3, to: Vector3, exclusions: Array[RID]) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1, exclusions)
	return _space.intersect_ray(query)


func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame
		await process_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.append(label)


func _finish() -> void:
	_report["passed_positive_scene_checks"] = _failures.is_empty()
	_report["failure_count"] = _failures.size()
	_report["failures"] = _failures
	print("PREVIEW_BLOCK_TEST ", JSON.stringify(_report))
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
