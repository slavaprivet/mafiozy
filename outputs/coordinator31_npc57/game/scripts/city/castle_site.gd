extends Node3D
## DSH_CASTLE: a large mediaeval castle as its own map, built from BRICKS that come down.
##
## Every course of every curtain wall, the battlements, the gate towers and the keep's
## crown are laid as individual bricks. Drawing thousands of separate bodies would cost
## more than the map is worth, so the bricks are DRAWN as one MultiMesh per material - a
## single draw call per wall - and a brick becomes a real falling body the moment a strike
## reaches it. Nothing about the look is faked: the bricks you see are the bricks that
## fall, the whole way through the wall.
##
## A hole opens upwards as well: bricks that lose the ones under them are dropped a moment
## later, so a hit low on a wall brings the courses above it down instead of leaving them
## hanging in the air.
##
## The map also has what an archer needs: two flights of stairs to the wall-walk, arrow
## slits in every wall and tower, four corner towers, a gatehouse with two hammered gates,
## and a keep in the courtyard.

const BRICK := Vector3(0.92, 0.46, 0.55)
const WALL_HEIGHT := 13.0
const WALL_HALF := 32.0          # half of the outside square
const WALL_THICK := 1.1
const TOWER_RADIUS := 4.4
const TOWER_HEIGHT := 18.0
const GATE_WIDTH := 7.4
const GATE_HEIGHT := 9.4
const DETACH_IMPULSE := 30.0
const SUPPORT_DELAY_MS := 240
const KEEP_SIZE := Vector3(18.0, 26.0, 18.0)

var _ready := false
var _materials: Dictionary = {}
var _brick_mesh: BoxMesh
var _cells: Array[Dictionary] = []
## One MultiMesh per material, holding every brick that is still in place.
var _buckets: Dictionary = {}     # material_id -> {instance: MultiMeshInstance3D, indices: Array}
var _falling: Array[Dictionary] = []
var _gate_leaves: Array[Dictionary] = []
var _detached := 0
var _collapsed := 0
var _events: Array[Dictionary] = []
var _pending_support: Array[Dictionary] = []
var _ground: StaticBody3D

## ------------------------------------------------------------------ build
func install(world: Node3D, origin: Vector3) -> Dictionary:
	if _ready: return {"ok": false, "reason": "already"}
	if not is_instance_valid(world): return {"ok": false, "reason": "no_world"}
	_build_materials()
	_brick_mesh = BoxMesh.new()
	_brick_mesh.size = BRICK
	_build_environment()
	_build_ground()
	_build_path()
	_build_curtain_walls()
	_build_corner_towers()
	_build_gatehouse()
	_build_stairs()
	_build_keep()
	_build_keep_details()
	_build_torches()
	_build_portcullis()
	_flush_buckets()
	_ready = true
	return {"ok": true, "origin": origin, "bricks": _cells.size(),
		"gates": _gate_leaves.size(), "stats": get_stats()}

func _build_materials() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.66, 0.63, 0.57)
	stone.roughness = 0.94
	var stone_warm := StandardMaterial3D.new()
	stone_warm.albedo_color = Color(0.58, 0.54, 0.47)
	stone_warm.roughness = 0.96
	var stone_cold := StandardMaterial3D.new()
	stone_cold.albedo_color = Color(0.52, 0.52, 0.51)
	stone_cold.roughness = 0.93
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.20, 0.10)
	wood.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.26, 0.27, 0.30)
	iron.metallic = 0.8
	iron.roughness = 0.42
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.33, 0.41, 0.24)
	grass.roughness = 0.98
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.04)
	dark.roughness = 1.0
	_materials = {"stone": stone, "warm": stone_warm, "cold": stone_cold,
		"wood": wood, "iron": iron, "grass": grass, "dark": dark}

func _build_ground() -> void:
	_ground = StaticBody3D.new()
	_ground.name = "CastleGround"
	_ground.collision_layer = 1
	_ground.collision_mask = 1
	add_child(_ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(320.0, 2.0, 320.0)
	shape.shape = box
	shape.position.y = -1.0
	_ground.add_child(shape)
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(320.0, 2.0, 320.0)
	slab.mesh = slab_mesh
	slab.material_override = _materials["grass"]
	slab.position.y = -1.0
	_ground.add_child(slab)

## ------------------------------------------------------------------ light and setting
## A castle needs its own sky and sun: the city's dusk lighting flattened every face of
## the stone into one grey tone, which is most of why it did not read as stone.
func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "CastleSky"
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.47, 0.72)
	sky_material.sky_horizon_color = Color(0.78, 0.80, 0.80)
	sky_material.ground_bottom_color = Color(0.25, 0.26, 0.24)
	sky_material.ground_horizon_color = Color(0.62, 0.63, 0.60)
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.14
	var sky := Sky.new()
	sky.sky_material = sky_material
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_sky_contribution = 0.55
	settings.ambient_light_energy = 0.9
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.35
	settings.fog_enabled = true
	settings.fog_light_color = Color(0.72, 0.75, 0.80)
	settings.fog_density = 0.0016
	settings.fog_aerial_perspective = 0.3
	environment.environment = settings
	add_child(environment)
	# The city already has a WorldEnvironment, and its dusk sky kept winning. The castle
	# is its own map, so it takes the sky over: every other environment is retired.
	for other: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if other != environment:
			(other as WorldEnvironment).environment = null
	if get_viewport() != null and get_viewport().world_3d != null:
		get_viewport().world_3d.environment = settings
	var sun := DirectionalLight3D.new()
	sun.name = "CastleSun"
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.rotation_degrees = Vector3(-38.0, 128.0, 0.0)
	add_child(sun)

## A road in from the gate, and cobbles across the courtyard.
func _build_path() -> void:
	var road := StandardMaterial3D.new()
	road.albedo_color = Color(0.34, 0.29, 0.22)
	road.roughness = 1.0
	var cobble := StandardMaterial3D.new()
	cobble.albedo_color = Color(0.45, 0.43, 0.39)
	cobble.roughness = 0.95
	var road_mesh := MeshInstance3D.new()
	var road_box := BoxMesh.new()
	road_box.size = Vector3(11.0, 0.12, 42.0)
	road_mesh.mesh = road_box
	road_mesh.material_override = road
	road_mesh.position = Vector3(0.0, -0.06, WALL_HALF + 21.0)
	add_child(road_mesh)
	var courtyard := MeshInstance3D.new()
	var courtyard_box := BoxMesh.new()
	courtyard_box.size = Vector3(WALL_HALF * 2.0 - 2.0, 0.12, WALL_HALF * 2.0 - 2.0)
	courtyard.mesh = courtyard_box
	courtyard.material_override = cobble
	courtyard.position = Vector3(0.0, -0.06, 0.0)
	add_child(courtyard)

## Torches on either side of the gate and along the wall-walk: light is what makes stone
## read as stone at night, and they give the gate a warm mouth instead of a black hole.
func _build_torches() -> void:
	var positions: Array[Vector3] = [
		Vector3(-GATE_WIDTH * 0.5 - 1.2, 5.2, WALL_HALF + 0.9),
		Vector3(GATE_WIDTH * 0.5 + 1.2, 5.2, WALL_HALF + 0.9),
		Vector3(-GATE_WIDTH * 0.5 - 1.2, 5.2, WALL_HALF - 0.9),
		Vector3(GATE_WIDTH * 0.5 + 1.2, 5.2, WALL_HALF - 0.9),
		Vector3(-WALL_HALF * 0.5, WALL_HEIGHT + 1.2, WALL_HALF - 0.8),
		Vector3(WALL_HALF * 0.5, WALL_HEIGHT + 1.2, WALL_HALF - 0.8),
	]
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.72, 0.32)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.55, 0.18)
	flame.emission_energy_multiplier = 4.0
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for at: Vector3 in positions:
		var bracket := MeshInstance3D.new()
		var bracket_mesh := BoxMesh.new()
		bracket_mesh.size = Vector3(0.16, 0.16, 0.5)
		bracket.mesh = bracket_mesh
		bracket.material_override = _materials["iron"]
		bracket.position = at
		add_child(bracket)
		var torch := MeshInstance3D.new()
		var torch_mesh := SphereMesh.new()
		torch_mesh.radius = 0.16
		torch_mesh.height = 0.34
		torch.mesh = torch_mesh
		torch.material_override = flame
		torch.position = at + Vector3(0.0, 0.22, 0.0)
		add_child(torch)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.66, 0.34)
		light.light_energy = 2.4
		light.omni_range = 9.0
		light.position = at + Vector3(0.0, 0.3, 0.0)
		add_child(light)

## The portcullis, raised behind the arch: the bars are what a gate is actually held by.
func _build_portcullis() -> void:
	var at := Vector3(0.0, GATE_HEIGHT * 0.5 + 0.4, WALL_HALF - 1.6)
	for i: int in 9:
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(0.11, GATE_HEIGHT * 0.72, 0.11)
		bar.mesh = bar_mesh
		bar.material_override = _materials["iron"]
		bar.position = at + Vector3(-GATE_WIDTH * 0.45 + float(i) * GATE_WIDTH * 0.1125, 0.0, 0.0)
		add_child(bar)
	for j: int in 4:
		var cross := MeshInstance3D.new()
		var cross_mesh := BoxMesh.new()
		cross_mesh.size = Vector3(GATE_WIDTH * 0.92, 0.10, 0.10)
		cross.mesh = cross_mesh
		cross.material_override = _materials["iron"]
		cross.position = at + Vector3(0.0, -GATE_HEIGHT * 0.28 + float(j) * GATE_HEIGHT * 0.18, 0.0)
		add_child(cross)

## Dress the keep: quoins down its corners, windows with arched heads, and a buttress at
## each face, so it stops being a flat dark box.
func _build_keep_details() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	var half_x := KEEP_SIZE.x * 0.5
	var half_z := KEEP_SIZE.z * 0.5
	# Quoins: alternate long and short stones down every corner.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var courses := int(KEEP_SIZE.y / BRICK.y)
		for row: int in courses:
			var longer: bool = row % 2 == 0
			var size := Vector3(0.86 if longer else 0.56, BRICK.y, 0.86 if longer else 0.56)
			var at := base + Vector3(corner.x * (half_x - size.x * 0.5 + 0.06),
				(float(row) + 0.5) * BRICK.y, corner.y * (half_z - size.z * 0.5 + 0.06))
			_add_brick(at, size, "cold", Vector3.ZERO, "keep_quoin", row, 0)
	# Windows: a dark recess with a lit sill, two per face, three storeys.
	for storey: int in 3:
		for side: float in [-1.0, 1.0]:
			for i: int in 2:
				var at := base + Vector3(side * (half_x + 0.02),
					5.0 + float(storey) * 7.0, -3.6 + float(i) * 7.2)
				_add_brick(at, Vector3(0.14, 2.1, 1.05), "dark", Vector3.ZERO, "keep_window", storey, i)
				var sill := MeshInstance3D.new()
				var sill_mesh := BoxMesh.new()
				sill_mesh.size = Vector3(0.5, 0.16, 1.35)
				sill.mesh = sill_mesh
				sill.material_override = _materials["stone"]
				sill.position = at + Vector3(-side * 0.16, -1.15, 0.0)
				add_child(sill)
	# Buttresses at the corners of each face.
	for side: float in [-1.0, 1.0]:
		for other: float in [-1.0, 1.0]:
			var at := base + Vector3(side * (half_x + 0.45), KEEP_SIZE.y * 0.5, other * 5.4)
			var body := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.9, KEEP_SIZE.y - 3.0, 1.5)
			body.mesh = mesh
			body.material_override = _materials["warm"]
			body.position = at
			add_child(body)
## ------------------------------------------------------------------ bricks
## One brick at a place, drawn through its material's MultiMesh until it is knocked out.
func _add_brick(at: Vector3, size: Vector3, material_key: String, rotation: Vector3,
		group: String, row: int = 0, column: int = 0) -> int:
	var index := _cells.size()
	_cells.append({
		"at": at, "size": size, "material": material_key, "rotation": rotation,
		"group": group, "row": row, "column": column, "alive": true, "instance": -1,
	})
	return index

func _flush_buckets() -> void:
	# Group every live brick by its material and build one MultiMesh per material.
	_buckets.clear()
	for index: int in _cells.size():
		var cell: Dictionary = _cells[index]
		var key: String = str(cell.get("material", "stone"))
		if not _buckets.has(key):
			_buckets[key] = {"indices": []}
		(_buckets[key]["indices"] as Array).append(index)
	for key: String in _buckets.keys():
		var bucket: Dictionary = _buckets[key]
		var indices: Array = bucket["indices"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _brick_mesh
		multi.instance_count = indices.size()
		for slot: int in indices.size():
			var cell: Dictionary = _cells[int(indices[slot])]
			cell["instance"] = slot
			multi.set_instance_transform(slot, _brick_transform(cell))
			multi.set_instance_color(slot, _brick_tint(cell))
		var node := MultiMeshInstance3D.new()
		node.name = "Bricks_" + key
		node.multimesh = multi
		node.material_override = _materials[key]
		add_child(node)
		bucket["node"] = node

## A brick's transform: its place, its size, and a few degrees of settling so the wall
## does not look machine-made.
func _brick_transform(cell: Dictionary) -> Transform3D:
	var at: Vector3 = cell.get("at", Vector3.ZERO)
	var size: Vector3 = cell.get("size", BRICK)
	var rotation: Vector3 = cell.get("rotation", Vector3.ZERO)
	var basis := Basis.from_euler(Vector3(
		rotation.x + float(int(at.x * 7.0 + at.y * 13.0) % 5) * 0.004,
		rotation.y + float(int(at.z * 11.0 + at.y * 5.0) % 5) * 0.004,
		rotation.z))
	basis = basis.scaled(Vector3(size.x / BRICK.x, size.y / BRICK.y, size.z / BRICK.z))
	return Transform3D(basis, at)

## Slight colour variation per brick, so the wall reads as stone rather than as paint.
func _brick_tint(cell: Dictionary) -> Color:
	var at: Vector3 = cell.get("at", Vector3.ZERO)
	var hash := int(at.x * 11317.0) ^ int(at.y * 7111.0) ^ int(at.z * 5309.0)
	var tone := float(abs(hash) % 1000) / 1000.0
	var multiplier := 0.88 + tone * 0.24
	return Color(multiplier, multiplier * 0.99, multiplier * 0.95)

func _kill_brick(index: int, impulse: Vector3, power: float) -> void:
	if index < 0 or index >= _cells.size(): return
	var cell: Dictionary = _cells[index]
	if not bool(cell.get("alive", false)): return
	cell["alive"] = false
	_detached += 1
	# Take it out of the drawing: the instance is moved far below the world, which is
	# cheaper than rebuilding the MultiMesh.
	var key: String = str(cell.get("material", "stone"))
	if _buckets.has(key):
		var bucket: Dictionary = _buckets[key]
		var node: MultiMeshInstance3D = bucket.get("node")
		var slot: int = int(cell.get("instance", -1))
		if is_instance_valid(node) and slot >= 0:
			node.multimesh.set_instance_transform(slot,
				Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3(0.0, -4000.0, 0.0)))
	# And it becomes a real stone, falling where it stood.
	_spawn_falling_brick(cell, impulse, power)

func _spawn_falling_brick(cell: Dictionary, impulse: Vector3, power: float) -> void:
	var body := RigidBody3D.new()
	body.name = "Brick"
	body.collision_layer = 1
	body.collision_mask = 1
	body.mass = 18.0
	body.position = cell.get("at", Vector3.ZERO)
	body.rotation = cell.get("rotation", Vector3.ZERO)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = cell.get("size", BRICK)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	var key: String = str(cell.get("material", "stone"))
	var base_material: StandardMaterial3D = _materials.get(key, _materials["stone"])
	var tinted: StandardMaterial3D = base_material.duplicate()
	var tint: Color = _brick_tint(cell)
	tinted.albedo_color = Color(base_material.albedo_color.r * tint.r,
		base_material.albedo_color.g * tint.g, base_material.albedo_color.b * tint.b)
	mesh.material_override = tinted
	body.add_child(mesh)
	var direction: Vector3 = impulse.normalized() if impulse.length_squared() > 1.0e-6 else Vector3.DOWN
	body.linear_velocity = (direction * 0.55 + Vector3.UP * 0.55).normalized() \
		* clampf(power * 0.35, 2.0, 26.0) * randf_range(0.7, 1.3)
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	_falling.append({"body": body, "age": 0.0})
	body.set_meta("castle_brick", true)

## ------------------------------------------------------------------ walls
func _build_curtain_walls() -> void:
	# Four walls round the courtyard, laid course by course with a half-brick offset on
	# every other course, which is how a real bond looks.
	for side: String in ["north", "south", "east", "west"]:
		_build_wall(side)
		_add_battlements(side)
		_add_arrow_slits(side)
		_add_plinth(side)

func _build_wall(side: String) -> void:
	var courses := int(WALL_HEIGHT / BRICK.y)
	var per_course := int((WALL_HALF * 2.0) / BRICK.x)
	var gate_columns := int(GATE_WIDTH / BRICK.x)
	var middle := per_course / 2
	for row: int in courses:
		var offset := 0.0 if row % 2 == 0 else BRICK.x * 0.5
		for column: int in per_course:
			# The gate is a real opening: no bricks inside it.
			if (side == "south") and row * BRICK.y < GATE_HEIGHT \
					and absi(column - middle) < gate_columns / 2 + 1:
				continue
			var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x + offset
			var height := (float(row) + 0.5) * BRICK.y
			var at := Vector3.ZERO
			var size := BRICK
			match side:
				"north":
					at = Vector3(along, height, -WALL_HALF)
					size = Vector3(BRICK.x, BRICK.y, WALL_THICK)
				"south":
					at = Vector3(along, height, WALL_HALF)
					size = Vector3(BRICK.x, BRICK.y, WALL_THICK)
				"east":
					at = Vector3(WALL_HALF, height, along)
					size = Vector3(WALL_THICK, BRICK.y, BRICK.x)
				"west":
					at = Vector3(-WALL_HALF, height, along)
					size = Vector3(WALL_THICK, BRICK.y, BRICK.x)
			_add_brick(at, size, "stone", Vector3.ZERO, side, row, column)
		# The wall itself is solid: one collision slab per wall, so the map is a place you
		# can lean on, not a curtain of loose stones.
	if side in ["north", "south"]:
		_add_wall_collision(Vector3(0.0, WALL_HEIGHT * 0.5, -WALL_HALF if side == "north" else WALL_HALF),
			Vector3(WALL_HALF * 2.0, WALL_HEIGHT, WALL_THICK))
	else:
		_add_wall_collision(Vector3(WALL_HALF if side == "east" else -WALL_HALF, WALL_HEIGHT * 0.5, 0.0),
			Vector3(WALL_THICK, WALL_HEIGHT, WALL_HALF * 2.0))

func _add_wall_collision(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = at
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _add_battlements(side: String) -> void:
	var per_course := int((WALL_HALF * 2.0) / BRICK.x)
	for row: int in 3:
		for column: int in per_course:
			if column % 2 == 1: continue
			var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
			var height := WALL_HEIGHT + (float(row) + 0.5) * BRICK.y
			var at := Vector3.ZERO
			var size := BRICK
			match side:
				"north": at = Vector3(along, height, -WALL_HALF)
				"south": at = Vector3(along, height, WALL_HALF)
				"east": at = Vector3(WALL_HALF, height, along)
				"west": at = Vector3(-WALL_HALF, height, along)
			if side in ["east", "west"]:
				size = Vector3(BRICK.z, BRICK.y, BRICK.x)
			_add_brick(at, size, "warm" if row == 1 else "stone", Vector3.ZERO, side + "_merlon", row, column)

func _add_plinth(side: String) -> void:
	var per_course := int((WALL_HALF * 2.0) / BRICK.x)
	for column: int in per_course:
		var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
		var at := Vector3.ZERO
		var size := Vector3(BRICK.x * 1.02, BRICK.y * 1.1, WALL_THICK * 1.35)
		match side:
			"north": at = Vector3(along, BRICK.y * 0.5, -WALL_HALF)
			"south": at = Vector3(along, BRICK.y * 0.5, WALL_HALF)
			"east":
				at = Vector3(WALL_HALF, BRICK.y * 0.5, along)
				size = Vector3(WALL_THICK * 1.35, BRICK.y * 1.1, BRICK.x * 1.02)
			"west":
				at = Vector3(-WALL_HALF, BRICK.y * 0.5, along)
				size = Vector3(WALL_THICK * 1.35, BRICK.y * 1.1, BRICK.x * 1.02)
		_add_brick(at, size, "cold", Vector3.ZERO, side + "_plinth", 0, column)

func _add_arrow_slits(side: String) -> void:
	var step := 9.0
	var count := int((WALL_HALF * 2.0) / step)
	for i: int in count:
		var along := (float(i) - float(count - 1) * 0.5) * step
		for height: float in [5.2, 9.0]:
			var at := Vector3.ZERO
			var size := Vector3(0.30, 1.30, 0.14)
			match side:
				"north":
					at = Vector3(along, height, -WALL_HALF + WALL_THICK * 0.5 + 0.02)
				"south":
					at = Vector3(along, height, WALL_HALF - WALL_THICK * 0.5 - 0.02)
				"east":
					at = Vector3(WALL_HALF - WALL_THICK * 0.5 - 0.02, height, along)
					size = Vector3(0.14, 1.30, 0.30)
				"west":
					at = Vector3(-WALL_HALF + WALL_THICK * 0.5 + 0.02, height, along)
					size = Vector3(0.14, 1.30, 0.30)
			_add_brick(at, size, "dark", Vector3.ZERO, side + "_slit", 0, i)

## ------------------------------------------------------------------ towers, gate, keep
func _build_corner_towers() -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
		# The tower is laid as rings of bricks: it is round because the bricks are.
		var courses := int(TOWER_HEIGHT / BRICK.y)
		var around := 22
		for row: int in courses:
			var radius := TOWER_RADIUS - float(row) * 0.012
			var angle_offset: float = (float(row % 2)) * (TAU / float(around)) * 0.5
			for i: int in around:
				var angle: float = TAU * float(i) / float(around) + angle_offset
				var at := centre + Vector3(cos(angle) * radius,
					(float(row) + 0.5) * BRICK.y, sin(angle) * radius)
				var size := Vector3(BRICK.x * 0.95, BRICK.y, BRICK.z * 1.5)
				var key := "stone" if row % 4 != 0 else "cold"
				_add_brick(at, size, key, Vector3(0.0, -angle, 0.0), "tower")
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.position = centre + Vector3.UP * TOWER_HEIGHT * 0.5
		add_child(body)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = TOWER_RADIUS
		cylinder.height = TOWER_HEIGHT
		shape.shape = cylinder
		body.add_child(shape)
		# Slits, facing outwards at three heights.
		for i: int in 6:
			var angle := TAU * float(i) / 6.0
			for height: float in [6.4, 10.2, 14.4]:
				_add_brick(centre + Vector3(cos(angle) * (TOWER_RADIUS + 0.05), height,
					sin(angle) * (TOWER_RADIUS + 0.05)),
					Vector3(0.30, 1.25, 0.16), "dark", Vector3(0.0, -angle, 0.0), "tower_slit")

func _build_gatehouse() -> void:
	var at := Vector3(0.0, 0.0, WALL_HALF)
	for side: float in [-1.0, 1.0]:
		var centre := at + Vector3(side * (GATE_WIDTH * 0.5 + 3.6), 0.0, 0.0)
		var courses := int(20.0 / BRICK.y)
		var per_course := 6
		for row: int in courses:
			for column: int in per_course:
				var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
				_add_brick(centre + Vector3(along, (float(row) + 0.5) * BRICK.y, 0.0),
					Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.6),
					"warm" if (row / 4) % 2 == 0 else "stone", Vector3.ZERO, "gatehouse", row, column)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.position = centre + Vector3.UP * 10.0
		add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(per_course * BRICK.x, 20.0, WALL_THICK * 1.6)
		shape.shape = box
		body.add_child(shape)
	# Quoins down the outer corners, battlements on top, and corbels carrying them: a
	# gatehouse is the part of a castle a lord pays to have look expensive.
	for side: float in [-1.0, 1.0]:
		var tower_centre := at + Vector3(side * (GATE_WIDTH * 0.5 + 3.6), 0.0, 0.0)
		var tower_courses: int = int(20.0 / BRICK.y)
		var tower_per_course: int = 6
		for row: int in tower_courses:
			var longer: bool = row % 2 == 0
			var size := Vector3(0.7 if longer else 0.44, BRICK.y, WALL_THICK * 1.75)
			_add_brick(tower_centre + Vector3(side * (tower_per_course * BRICK.x * 0.5 - size.x * 0.5 + 0.02),
				(float(row) + 0.5) * BRICK.y, 0.0), size, "cold", Vector3.ZERO, "gate_quoin", row, 0)
		for i: int in 5:
			_add_brick(tower_centre + Vector3(-tower_per_course * BRICK.x * 0.4
				+ float(i) * tower_per_course * BRICK.x * 0.2,
				20.0 + BRICK.y * 0.5, 0.0), Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.6),
				"stone", Vector3.ZERO, "gate_merlon", 0, i)
		for i: int in 4:
			var corbel := MeshInstance3D.new()
			var corbel_mesh := BoxMesh.new()
			corbel_mesh.size = Vector3(0.36, 0.5, WALL_THICK * 2.4)
			corbel.mesh = corbel_mesh
			corbel.material_override = _materials["cold"]
			corbel.position = tower_centre + Vector3(-tower_per_course * BRICK.x * 0.36
				+ float(i) * tower_per_course * BRICK.x * 0.24, 19.4, 0.0)
			add_child(corbel)	# The arch over the gate.
	var arch_rows := 3
	for row: int in arch_rows:
		var per_course := int((GATE_WIDTH + 7.0) / BRICK.x)
		for column: int in per_course:
			var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
			_add_brick(at + Vector3(along, GATE_HEIGHT + (float(row) + 0.5) * BRICK.y, 0.0),
				Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.6), "stone", Vector3.ZERO, "gate_arch", row, column)
	# Two hammered leaves, real bodies that can be blown in.
	for side: float in [-1.0, 1.0]:
		var leaf := RigidBody3D.new()
		leaf.name = "GateLeaf" + ("Left" if side < 0.0 else "Right")
		leaf.collision_layer = 1
		leaf.collision_mask = 1
		leaf.freeze = true
		leaf.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		leaf.mass = 420.0
		leaf.position = at + Vector3(side * GATE_WIDTH * 0.25, GATE_HEIGHT * 0.5, 0.0)
		add_child(leaf)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(GATE_WIDTH * 0.5, GATE_HEIGHT, 0.5)
		shape.shape = box
		leaf.add_child(shape)
		var mesh := MeshInstance3D.new()
		var leaf_mesh := BoxMesh.new()
		leaf_mesh.size = box.size
		mesh.mesh = leaf_mesh
		mesh.material_override = _materials["wood"]
		leaf.add_child(mesh)
		for band: int in 3:
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(box.size.x * 0.96, 0.24, 0.68)
			strip.mesh = strip_mesh
			strip.material_override = _materials["iron"]
			strip.position = Vector3(0.0, -box.size.y * 0.5 + 1.6 + float(band) * 2.9, 0.0)
			leaf.add_child(strip)
		leaf.set_meta("castle_gate", true)
		_gate_leaves.append({"body": leaf, "side": side, "detached": false})

## Two flights up to the wall-walk, for archers.
##
## The steps are DRAWN, and an invisible RAMP carries the player up underneath them. A
## stair built from boxes of collision is a stair a character gets stuck on - the first
## version used half-metre steps and a single rectangular block for the whole flight, and
## he could not get up it at all. A ramp cannot be stuck on, and the steps are what is seen.
func _build_stairs() -> void:
	for side: float in [-1.0, 1.0]:
		var rise := 0.26
		var run := 0.36
		var width := 2.8
		var steps := int(ceil(WALL_HEIGHT / rise))
		var length := float(steps) * run
		var x := side * WALL_HALF * 0.52
		var z_bottom := WALL_HALF - 3.0
		var z_top := z_bottom - length
		var top_height := float(steps) * rise
		# The ramp: one box, tilted, its top face running from BELOW THE GROUND up to the
		# wall-walk. Its lower end must be buried, because a ramp that starts exactly at
		# floor level presents its own one-metre end face as a wall - which is precisely
		# what the first version did, and the man could not walk onto it.
		var angle := atan2(top_height, length)
		var bury := 0.6
		var start_point := Vector3(x, -bury, z_bottom + bury / maxf(0.05, tan(angle)))
		var end_point := Vector3(x, top_height, z_top)
		var forward := (end_point - start_point).normalized()
		var up := Vector3(0.0, cos(angle), sin(angle))
		var slope_length := (end_point - start_point).length()
		var basis := Basis(Vector3(1.0, 0.0, 0.0), up, -forward)
		var mid := (start_point + end_point) * 0.5
		var thickness := 1.2
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.transform = Transform3D(basis, mid - up * (thickness * 0.5))
		add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, thickness, slope_length)
		shape.shape = box
		body.add_child(shape)		# The steps themselves, as bricks, with no collision of their own.
		var step_material: String = "cold"
		for i: int in steps:
			var at := Vector3(x, rise * (float(i) + 0.5), z_bottom - run * (float(i) + 0.5))
			_add_brick(at, Vector3(width, rise, run * 1.04), step_material, Vector3.ZERO, "stairs", i, 0)
		# A parapet along the open side, so the flight reads as a stair and not as a slope.
		for i: int in steps:
			var at := Vector3(x + side * width * 0.5 - side * 0.18,
				rise * (float(i) + 0.5) + 0.5, z_bottom - run * (float(i) + 0.5))
			_add_brick(at, Vector3(0.32, 1.0, run * 1.04), "stone", Vector3.ZERO, "stairs_rail", i, 0)
		# And the wall-walk it leads onto: a real place to stand behind the battlements.
		var walk := StaticBody3D.new()
		walk.collision_layer = 1
		walk.collision_mask = 1
		walk.position = Vector3(x, WALL_HEIGHT + 0.02, WALL_HALF - 1.6)
		add_child(walk)
		var walk_shape := CollisionShape3D.new()
		var walk_box := BoxShape3D.new()
		walk_box.size = Vector3(width + 1.2, 0.16, 3.4)
		walk_shape.shape = walk_box
		walk.add_child(walk_shape)
		var walk_mesh := MeshInstance3D.new()
		var walk_mesh_box := BoxMesh.new()
		walk_mesh_box.size = walk_box.size
		walk_mesh.mesh = walk_mesh_box
		walk_mesh.material_override = _materials["warm"]
		walk_mesh.position = walk.position
		add_child(walk_mesh)
func _build_keep() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	var courses := int(KEEP_SIZE.y / BRICK.y)
	var per_course := int(KEEP_SIZE.x / BRICK.x)
	for row: int in courses:
		for column: int in per_course:
			var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x
			for side: float in [-1.0, 1.0]:
				_add_brick(base + Vector3(along, (float(row) + 0.5) * BRICK.y,
					side * KEEP_SIZE.z * 0.5),
					Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.3), "stone", Vector3.ZERO, "keep", row, column)
				_add_brick(base + Vector3(side * KEEP_SIZE.x * 0.5,
					(float(row) + 0.5) * BRICK.y, along),
					Vector3(WALL_THICK * 1.3, BRICK.y, BRICK.x), "warm", Vector3.ZERO, "keep", row, column)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = base + Vector3.UP * KEEP_SIZE.y * 0.5
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = KEEP_SIZE
	shape.shape = box
	body.add_child(shape)

## ------------------------------------------------------------------ destruction
func owns_collider(body: Node) -> bool:
	if not is_instance_valid(body): return false
	return body.get_meta("castle_brick", false) or body.get_meta("castle_gate", false)

func get_stats() -> Dictionary:
	return {
		"ok": _ready, "bricks": _cells.size(), "detached": _detached,
		"collapsed": _collapsed, "gates": _gate_leaves.size(),
		"gate_open": _gate_leaves.size() > 0 and bool(_gate_leaves[0].get("detached", false)),
		"falling": _falling.size(), "events": _events.size(),
	}

## A blast knocks out every brick inside its radius, and the courses above them come down
## a moment later.
func apply_explosion(event: Dictionary) -> Dictionary:
	if not _ready: return {"ok": false, "reason": "not_ready"}
	# The strike arrives in WORLD coordinates - a catapult stone knows nothing of this
	# node - while the bricks are laid in local ones.
	var at: Vector3 = to_local(event.get("position", Vector3.ZERO))
	var radius: float = maxf(1.0, float(event.get("radius", 3.0)))
	var power: float = maxf(1.0, float(event.get("power", 40.0)))
	var direction: Vector3 = event.get("direction", Vector3.DOWN)
	var killed := 0
	for index: int in _cells.size():
		var cell: Dictionary = _cells[index]
		if not bool(cell.get("alive", false)): continue
		var brick_at: Vector3 = cell.get("at", Vector3.ZERO)
		if brick_at.distance_to(at) > radius: continue
		_kill_brick(index, direction, power)
		killed += 1
	for entry: Dictionary in _gate_leaves:
		if bool(entry.get("detached", false)): continue
		var body: RigidBody3D = entry.get("body")
		if not is_instance_valid(body): continue
		if body.global_position.distance_to(at) > radius + 2.0: continue
		entry["detached"] = true
		body.freeze = false
		body.sleeping = false
		var away: Vector3 = direction.normalized() if direction.length_squared() > 1.0e-6 else Vector3.BACK
		body.apply_central_impulse((away * 0.9 + Vector3.UP * 0.1).normalized()
			* DETACH_IMPULSE * 2.4 * clampf(power / 120.0, 0.6, 2.6))
		_detached += 1
		killed += 1
	_schedule_support_failure(at, radius)
	var result := {"ok": killed > 0, "detached": killed, "state": "committed",
		"event_id": str(event.get("event_id", "")), "total": _detached}
	_events.append(result.duplicate())
	if _events.size() > 24: _events.pop_front()
	return result

## Bricks left with nothing under them.
##
## The hole is what matters, not a distance: every brick standing in a column ABOVE a
## brick that has just gone has lost its support, so it is scheduled to come down. This
## walks upwards from the hole, so a hit low on a wall opens a breach that climbs instead
## of leaving courses hanging over nothing.
func _schedule_support_failure(at: Vector3, radius: float) -> void:
	var now := Time.get_ticks_msec()
	var holes: Array[Dictionary] = []
	for index: int in _cells.size():
		var cell: Dictionary = _cells[index]
		if bool(cell.get("alive", false)): continue
		var brick_at: Vector3 = cell.get("at", Vector3.ZERO)
		if brick_at.distance_to(at) > radius + 0.5: continue
		holes.append({"x": brick_at.x, "y": brick_at.y, "z": brick_at.z})
	if holes.is_empty(): return
	for index: int in _cells.size():
		var cell: Dictionary = _cells[index]
		if not bool(cell.get("alive", false)): continue
		var brick_at: Vector3 = cell.get("at", Vector3.ZERO)
		for hole: Dictionary in holes:
			var dx: float = absf(brick_at.x - float(hole.get("x", 0.0)))
			var dz: float = absf(brick_at.z - float(hole.get("z", 0.0)))
			var dy: float = brick_at.y - float(hole.get("y", 0.0))
			# Above the hole, inside its footprint, and close enough to be part of the
			# same breach rather than a different wall.
			if dy > BRICK.y * 0.6 and dy < radius * 2.2 and dx < BRICK.x * 1.1 and dz < BRICK.x * 1.1:
				_pending_support.append({"index": index,
					"at": now + SUPPORT_DELAY_MS + int(dy * 55.0) + int(randf_range(0.0, 0.25) * 1000.0)})
				break
func _physics_process(_delta: float) -> void:
	if not _ready: return
	# The cascade.
	if not _pending_support.is_empty():
		var now := Time.get_ticks_msec()
		for index: int in range(_pending_support.size() - 1, -1, -1):
			var pending: Dictionary = _pending_support[index]
			if now < int(pending.get("at", 0)): continue
			var cell_index: int = int(pending.get("index", -1))
			if cell_index >= 0 and bool((_cells[cell_index] as Dictionary).get("alive", false)):
				_kill_brick(cell_index, Vector3.DOWN, 30.0)
				_collapsed += 1
			_pending_support.remove_at(index)
	# Falling bricks settle, and very old ones are cleaned up so a long siege does not
	# fill the map with bodies.
	if _falling.is_empty(): return
	for index: int in range(_falling.size() - 1, -1, -1):
		var entry: Dictionary = _falling[index]
		var body: RigidBody3D = entry.get("body")
		if not is_instance_valid(body):
			_falling.remove_at(index)
			continue
		entry["age"] = float(entry.get("age", 0.0)) + _delta
		if float(entry.get("age", 0.0)) > 90.0:
			body.queue_free()
			_falling.remove_at(index)

## Where the player appears: in the courtyard, with the gate behind him.
func spawn_point() -> Vector3:
	return global_position + Vector3(0.0, 1.2, 14.0)
