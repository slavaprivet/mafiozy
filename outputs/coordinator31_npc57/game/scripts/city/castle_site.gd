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

const BRICK := Vector3(1.00, 0.54, 0.58)
## DSH_OPT: a blast must not spawn a thousand solvers. Debris is capped, its physics is
## retired once it has settled, and every brick shares one mesh.
const MAX_FALLING := 150
const BRICK_SETTLE_S := 1.4
const BRICK_LIFE_S := 30.0
var _debris_mesh: BoxMesh
var _debris_materials: Dictionary = {}
const WALL_HEIGHT := 19.0
const WALL_HALF := 68.0          # half of the outside square: a siege map, not a yard
const WALL_THICK := 1.1
const TOWER_RADIUS := 5.6
const TOWER_HEIGHT := 27.0
const GATE_WIDTH := 9.2
const GATE_HEIGHT := 12.0
const DETACH_IMPULSE := 30.0
const SUPPORT_DELAY_MS := 240
const KEEP_SIZE := Vector3(26.0, 38.0, 26.0)

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
var _player: CharacterBody3D
var _world_ref: Node3D

## ------------------------------------------------------------------ build
func install(world: Node3D, origin: Vector3) -> Dictionary:
	if _ready: return {"ok": false, "reason": "already"}
	if not is_instance_valid(world): return {"ok": false, "reason": "no_world"}
	_world_ref = world
	_player = world.get("_player") as CharacterBody3D
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
	_build_wall_walks()
	_build_keep()
	_build_keep_details()
	_build_gate_arch()
	_build_banners()
	_build_ring_road()
	_build_tower_platforms()
	_build_gate_bridge()
	_build_far_slabs()
	_build_string_courses()
	_build_wall_banners()
	_build_brick_floor()
	_add_rubble()
	_build_torches()
	_build_portcullis()
	_build_gate_lamps()
	_build_gate_deck()
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
	# The gate leaves sat in the shadow of the arch and read as a black hole. Oak, not tar.
	var wood := StandardMaterial3D.new()
	# Oak. It read as pale plaster under a strong sun, so it is darker and rougher.
	wood.albedo_color = Color(0.38, 0.24, 0.13)
	wood.roughness = 0.96
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
	box.size = Vector3(600.0, 2.0, 600.0)
	shape.shape = box
	shape.position.y = -1.0
	_ground.add_child(shape)
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(600.0, 2.0, 600.0)
	slab.mesh = slab_mesh
	slab.material_override = _materials["grass"]
	slab.position.y = -1.03
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
	settings.ambient_light_sky_contribution = 0.7
	settings.ambient_light_energy = 0.95
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 0.82
	settings.ssao_enabled = true
	settings.ssao_radius = 2.4
	settings.ssao_intensity = 1.4
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
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_blur = 1.6
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
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
	road_mesh.position = Vector3(0.0, -0.04, WALL_HALF + 21.0)
	add_child(road_mesh)
	var courtyard := MeshInstance3D.new()
	var courtyard_box := BoxMesh.new()
	# The paving runs all the way UNDER the walls: it used to stop a metre short, and in
	# that gap the grass showed through the floor - exactly the ugly strip at the foot of
	# the stairs.
	courtyard_box.size = Vector3(WALL_HALF * 2.0 + 1.6, 0.12, WALL_HALF * 2.0 + 1.6)
	courtyard.mesh = courtyard_box
	courtyard.material_override = cobble
	courtyard.position = Vector3(0.0, -0.04, 0.0)
	add_child(courtyard)
	# The paving is a SURFACE of its own, a whisker above the earth: without this a footstep
	# inside the walls would take the ground slab underneath and sound like a field.
	var paving_body := StaticBody3D.new()
	paving_body.name = "CourtyardPaving"
	paving_body.collision_layer = 1
	paving_body.collision_mask = 1
	paving_body.set_meta("surface", "stone")
	paving_body.position = Vector3(0.0, -0.02, 0.0)
	add_child(paving_body)
	var paving_area := CollisionShape3D.new()
	var paving_shape := BoxShape3D.new()
	paving_shape.size = Vector3(WALL_HALF * 2.0 + 1.6, 0.10, WALL_HALF * 2.0 + 1.6)
	paving_area.shape = paving_shape
	paving_body.add_child(paving_area)

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
func _build_gate_lamps() -> void:
	for side: float in [-1.0, 1.0]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.76, 0.48)
		# Three metres out and faint: at half a metre the inverse-square turned the oak
		# into a white panel.
		lamp.light_energy = 0.45
		lamp.omni_range = 6.0
		lamp.position = Vector3(side * GATE_WIDTH * 0.60, GATE_HEIGHT * 0.55, WALL_HALF + 3.0)
		add_child(lamp)

## A plank deck through the gate passage: a timber floor under the arch, which is what a
## gate is actually floored with - and the one place on the map where a boot lands on wood.
func _build_gate_deck() -> void:
	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color(0.42, 0.30, 0.18)
	deck_material.roughness = 0.94
	var body := StaticBody3D.new()
	body.name = "GateDeck"
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("surface", "wood")
	body.position = Vector3(0.0, -0.02, WALL_HALF)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GATE_WIDTH + 2.0, 0.10, 6.0)
	shape.shape = box
	body.add_child(shape)
	var deck := MeshInstance3D.new()
	var deck_box := BoxMesh.new()
	deck_box.size = box.size
	deck.mesh = deck_box
	deck.material_override = deck_material
	deck.position = body.position
	add_child(deck)
	# The boards, drawn as seams across the deck.
	var seam := StandardMaterial3D.new()
	seam.albedo_color = Color(0.24, 0.16, 0.09)
	seam.roughness = 0.96
	for i: int in 9:
		var strip := MeshInstance3D.new()
		var strip_box := BoxMesh.new()
		strip_box.size = Vector3(GATE_WIDTH + 2.0, 0.02, 0.06)
		strip.mesh = strip_box
		strip.material_override = seam
		strip.position = Vector3(0.0, 0.03, WALL_HALF - 2.6 + float(i) * 0.68)
		add_child(strip)
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
				# Two faces run along X, two along Z: windows on all four, or the tower
				# is blind on the sides the player actually walks past.
				var at_x := base + Vector3(side * (half_x + 0.02),
					6.0 + float(storey) * 9.0, -4.6 + float(i) * 9.2)
				_add_brick(at_x, Vector3(0.14, 2.4, 1.2), "dark", Vector3.ZERO, "keep_window", storey, i)
				var sill_x := MeshInstance3D.new()
				var sill_x_mesh := BoxMesh.new()
				sill_x_mesh.size = Vector3(0.5, 0.18, 1.5)
				sill_x.mesh = sill_x_mesh
				sill_x.material_override = _materials["stone"]
				sill_x.position = at_x + Vector3(-side * 0.16, -1.3, 0.0)
				add_child(sill_x)
				var at_z := base + Vector3(-4.6 + float(i) * 9.2,
					6.0 + float(storey) * 9.0, side * (half_z + 0.02))
				_add_brick(at_z, Vector3(1.2, 2.4, 0.14), "dark", Vector3.ZERO, "keep_window_z", storey, i)
				var sill_z := MeshInstance3D.new()
				var sill_z_mesh := BoxMesh.new()
				sill_z_mesh.size = Vector3(1.5, 0.18, 0.5)
				sill_z.mesh = sill_z_mesh
				sill_z.material_override = _materials["stone"]
				sill_z.position = at_z + Vector3(0.0, -1.3, -side * 0.16)
				add_child(sill_z)
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

## DSH_OPT: bricks are drawn in CHUNKS, not as one MultiMesh for the whole castle.
##
## A single MultiMesh is never frustum-culled - the engine has no way to know that most of
## a hundred-and-thirty-metre wall is behind you - so one big mesh would draw thirty
## thousand bricks every frame. Split into chunks of a few metres, each chunk is culled on
## its own and the cost follows what is on screen. Bricks that are knocked out are moved
## out of the chunk's mesh, and the falling body is spawned as before.
## Bricks are drawn in detail up to this distance; past it a plain slab stands in.
const BRICK_LOD_END := 110.0
const CHUNK_X := 26.0
const CHUNK_Y := 10.0
const CHUNK_Z := 26.0

func _flush_buckets() -> void:
	_buckets.clear()
	for index: int in _cells.size():
		var cell: Dictionary = _cells[index]
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		var key := "%s|%d|%d|%d" % [str(cell.get("material", "stone")),
			int(floor(at.x / CHUNK_X)), int(floor(at.y / CHUNK_Y)), int(floor(at.z / CHUNK_Z))]
		if not _buckets.has(key):
			_buckets[key] = {"indices": [], "material": str(cell.get("material", "stone"))}
		(_buckets[key]["indices"] as Array).append(index)
	var chunk_count := 0
	for key: String in _buckets.keys():
		var bucket: Dictionary = _buckets[key]
		var indices: Array = bucket["indices"]
		if indices.is_empty(): continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _brick_mesh
		multi.instance_count = indices.size()
		for slot: int in indices.size():
			var cell: Dictionary = _cells[int(indices[slot])]
			cell["bucket"] = key
			cell["instance"] = slot
			multi.set_instance_transform(slot, _brick_transform(cell))
			multi.set_instance_color(slot, _brick_tint(cell))
		var node := MultiMeshInstance3D.new()
		node.name = "Bricks%d" % chunk_count
		node.multimesh = multi
		node.material_override = _materials[str(bucket.get("material", "stone"))]
		# No global-illumination participation for thousands of static stones: it buys
		# nothing on a wall and costs a lot to bake.
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(node)
		bucket["node"] = node
		chunk_count += 1
	_chunk_total = chunk_count

var _chunk_total := 0

## How much of the castle is actually being drawn, for the optimisation to be measured
## rather than claimed.
func render_stats() -> Dictionary:
	var visible := 0
	var instances := 0
	var camera: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	for key: String in _buckets.keys():
		var node: MultiMeshInstance3D = (_buckets[key] as Dictionary).get("node")
		if not is_instance_valid(node): continue
		if camera != null and camera.is_position_in_frustum(node.global_position):
			visible += 1
			instances += node.multimesh.instance_count
	return {"chunks": _chunk_total, "chunks_in_frustum": visible,
		"bricks_in_frustum": instances, "bricks": _cells.size()}
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
	# One stone in sixteen is weathered: a wall of stones all the same age is a wall of
	# stones nobody has ever lived with.
	var multiplier := 0.945 + tone * 0.11
	if abs(hash) % 16 == 0:
		multiplier *= 0.86
	return Color(multiplier, multiplier * 0.99, multiplier * 0.95)

func _kill_brick(index: int, impulse: Vector3, power: float) -> void:
	if index < 0 or index >= _cells.size(): return
	var cell: Dictionary = _cells[index]
	if not bool(cell.get("alive", false)): return
	cell["alive"] = false
	_detached += 1
	# Take it out of the drawing: the instance is moved far below the world, which is
	# cheaper than rebuilding the MultiMesh.
	var key: String = str(cell.get("bucket", ""))
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
	# ONE mesh resource, scaled per stone: a BoxMesh per brick meant a resource allocation
	# for every one of hundreds of bodies in a single blast.
	if _debris_mesh == null:
		_debris_mesh = BoxMesh.new()
		_debris_mesh.size = Vector3.ONE
	mesh.mesh = _debris_mesh
	mesh.scale = box.size
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var key: String = str(cell.get("material", "stone"))
	var tint: Color = _brick_tint(cell)
	var debris_key := "%s|%d" % [key, int(tint.r * 40.0)]
	if not _debris_materials.has(debris_key):
		var base_material: StandardMaterial3D = _materials.get(key, _materials["stone"])
		var tinted: StandardMaterial3D = base_material.duplicate()
		tinted.albedo_color = Color(base_material.albedo_color.r * tint.r,
			base_material.albedo_color.g * tint.g, base_material.albedo_color.b * tint.b)
		_debris_materials[debris_key] = tinted
	mesh.material_override = _debris_materials[debris_key]
	body.add_child(mesh)
	var direction: Vector3 = impulse.normalized() if impulse.length_squared() > 1.0e-6 else Vector3.DOWN
	body.linear_velocity = (direction * 0.55 + Vector3.UP * 0.55).normalized() \
		* clampf(power * 0.35, 2.0, 26.0) * randf_range(0.7, 1.3)
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	_falling.append({"body": body, "age": 0.0})
	# Over the cap the oldest debris is retired: a solver per stone is what stalls a blast.
	while _falling.size() > MAX_FALLING:
		var oldest: Dictionary = _falling.pop_front()
		var old_body: Node = oldest.get("body")
		if is_instance_valid(old_body): old_body.queue_free()
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
		_add_corbels(side)
		_add_buttresses(side)

## The wall is laid in TWO skins of brick, an outer and an inner. A single skin with a dark
## slab behind it is what a breach used to show: a grey square, with the street beyond it.
## Two skins give a breach depth, and the joints between the bricks read dark on their own
## because the opposite skin sits half a metre behind them in shadow.
func _build_wall(side: String) -> void:
	var courses := int(WALL_HEIGHT / BRICK.y)
	var per_course := int((WALL_HALF * 2.0) / BRICK.x)
	var gate_columns := int(GATE_WIDTH / BRICK.x)
	var middle := per_course / 2
	var layer_depth := WALL_THICK * 0.5
	for layer: int in 2:
		var layer_sign: float = -1.0 if layer == 0 else 1.0
		var inset: float = layer_sign * (WALL_THICK * 0.5 - layer_depth * 0.5)
		for row: int in courses:
			var offset := 0.0 if (row + layer) % 2 == 0 else BRICK.x * 0.5
			for column: int in per_course:
				# The gate is a real opening: no bricks inside it.
				if (side == "south") and row * BRICK.y < GATE_HEIGHT and absi(column - middle) < gate_columns / 2 + 1:
					continue
				var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x + offset
				var height := (float(row) + 0.5) * BRICK.y
				var at := Vector3.ZERO
				var size := BRICK
				match side:
					"north":
						at = Vector3(along, height, -WALL_HALF + inset)
						size = Vector3(BRICK.x, BRICK.y, layer_depth)
					"south":
						at = Vector3(along, height, WALL_HALF + inset)
						size = Vector3(BRICK.x, BRICK.y, layer_depth)
					"east":
						at = Vector3(WALL_HALF + inset, height, along)
						size = Vector3(layer_depth, BRICK.y, BRICK.x)
					"west":
						at = Vector3(-WALL_HALF + inset, height, along)
						size = Vector3(layer_depth, BRICK.y, BRICK.x)
				_add_brick(at, size, "stone", Vector3.ZERO, side, row, column)
		# The wall itself is solid: one collision slab per wall, so the map is a place you
		# can lean on, not a curtain of loose stones.
	if side == "south":
		# The wall is solid EXCEPT at the gate: two piers and a lintel, so the opening can
		# be walked through and the masonry either side of it is still a wall.
		var pier: float = (WALL_HALF * 2.0 - GATE_WIDTH) * 0.5
		for pier_side: float in [-1.0, 1.0]:
			_add_wall_collision(Vector3(pier_side * (GATE_WIDTH * 0.5 + pier * 0.5), WALL_HEIGHT * 0.5, WALL_HALF),
				Vector3(pier, WALL_HEIGHT, WALL_THICK))
		_add_wall_collision(Vector3(0.0, (WALL_HEIGHT + GATE_HEIGHT) * 0.5, WALL_HALF),
			Vector3(GATE_WIDTH, WALL_HEIGHT - GATE_HEIGHT, WALL_THICK))
	elif side == "north":
		_add_wall_collision(Vector3(0.0, WALL_HEIGHT * 0.5, -WALL_HALF),
			Vector3(WALL_HALF * 2.0, WALL_HEIGHT, WALL_THICK))
	else:
		_add_wall_collision(Vector3(WALL_HALF if side == "east" else -WALL_HALF, WALL_HEIGHT * 0.5, 0.0),
			Vector3(WALL_THICK, WALL_HEIGHT, WALL_HALF * 2.0))

func _add_mortar(at: Vector3, size: Vector3, vertical: bool = false) -> void:
	# A dark core, a little thinner than the wall, seen through the joints between bricks.
	var mortar := MeshInstance3D.new()
	if vertical:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 16
		mortar.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mortar.mesh = box
	mortar.material_override = _materials["cold"]
	mortar.position = at
	add_child(mortar)

func _add_wall_collision(at: Vector3, size: Vector3) -> void:
	# No mortar slab behind the masonry: it was the pale sheet visible through every joint
	# and straight through the open gate. The wall is two solid skins now, and that is what
	# a breach shows.
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
		var around: int = maxi(12, int(round(TAU * TOWER_RADIUS / (BRICK.x * 0.98))))
		var brick_length: float = TAU * TOWER_RADIUS / float(around) * 1.06
		for row: int in courses:
			var radius := TOWER_RADIUS - float(row) * 0.012
			var angle_offset: float = (float(row % 2)) * (TAU / float(around)) * 0.5
			for i: int in around:
				var angle: float = TAU * float(i) / float(around) + angle_offset
				var at := centre + Vector3(cos(angle) * radius,
					(float(row) + 0.5) * BRICK.y, sin(angle) * radius)
				var size := Vector3(brick_length, BRICK.y, BRICK.z * 1.5)
				var key := "stone" if row % 4 != 0 else "cold"
				_add_brick(at, size, key, Vector3(0.0, -angle, 0.0), "tower")
		_add_mortar(centre + Vector3.UP * TOWER_HEIGHT * 0.5,
			Vector3(TOWER_RADIUS * 1.92, TOWER_HEIGHT, 0.0), true)
		# SOLID only up to the wall-walk. Above it the tower is a RING with an open middle
		# and a doorway onto the battlements, so its top is a room and not a drum.
		var base := StaticBody3D.new()
		base.collision_layer = 1
		base.collision_mask = 1
		base.set_meta("surface", "stone")
		base.position = centre + Vector3.UP * WALL_HEIGHT * 0.5
		add_child(base)
		var base_shape := CollisionShape3D.new()
		var base_cylinder := CylinderShape3D.new()
		base_cylinder.radius = TOWER_RADIUS
		base_cylinder.height = WALL_HEIGHT
		base_shape.shape = base_cylinder
		base.add_child(base_shape)
		var to_centre: Vector3 = Vector3(-corner.x, 0.0, -corner.y).normalized()
		var doorway_angle: float = atan2(to_centre.z, to_centre.x)
		for segment: int in 8:
			var angle: float = TAU * float(segment) / 8.0
			if absf(wrapf(angle - doorway_angle, -PI, PI)) < 0.45: continue
			var ring := StaticBody3D.new()
			ring.collision_layer = 1
			ring.collision_mask = 1
			ring.set_meta("surface", "stone")
			ring.position = centre + Vector3(cos(angle) * (TOWER_RADIUS - 0.35),
				(WALL_HEIGHT + TOWER_HEIGHT) * 0.5, sin(angle) * (TOWER_RADIUS - 0.35))
			add_child(ring)
			var ring_shape := CollisionShape3D.new()
			var ring_box := BoxShape3D.new()
			ring_box.size = Vector3(0.7, TOWER_HEIGHT - WALL_HEIGHT, TOWER_RADIUS * 0.95)
			ring_shape.shape = ring_box
			ring.add_child(ring_shape)
			ring.rotation.y = -angle
		# A SOLID BLOCK IN THE CORNER. The wall boxes end exactly at ±WALL_HALF and the tower
		# is a cylinder, so a man could slip between them at the four corners - measured: 84
		# rays went straight through the walls there. This block seals the joint.
		var corner_block := StaticBody3D.new()
		corner_block.collision_layer = 1
		corner_block.collision_mask = 1
		corner_block.set_meta("surface", "stone")
		corner_block.position = centre + Vector3.UP * WALL_HEIGHT * 0.5
		add_child(corner_block)
		var corner_shape := CollisionShape3D.new()
		var corner_box := BoxShape3D.new()
		# Just wide enough to close the joint: the first version was 2.6x the tower radius and
		# stuck metres out from the corner, where it blocked a man walking near the wall.
		corner_box.size = Vector3(TOWER_RADIUS * 1.35, WALL_HEIGHT, TOWER_RADIUS * 1.35)
		corner_shape.shape = corner_box
		corner_block.add_child(corner_shape)
		# Slits, facing outwards at three heights.
		for i: int in 6:
			var slit_angle := TAU * float(i) / 6.0
			for height: float in [6.4, 10.2, 14.4]:
				_add_brick(centre + Vector3(cos(slit_angle) * (TOWER_RADIUS + 0.05), height,
					sin(slit_angle) * (TOWER_RADIUS + 0.05)),
					Vector3(0.30, 1.25, 0.16), "dark", Vector3(0.0, -slit_angle, 0.0), "tower_slit")

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
	# THE LEAVES are hung on HINGES: each one a pivot at its own edge, so it can be swung.
	# The leaf is ONE SOLID SHIELD of oak with the plank seams cut into its face. Built from
	# six separate boards it had finger-wide gaps between them, and an oak gate that you can
	# see through is a grille.
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "GateLeaf" + ("Left" if side < 0.0 else "Right")
		pivot.position = at + Vector3(side * GATE_WIDTH * 0.5, 0.0, 0.0)
		add_child(pivot)
		var leaf_width := GATE_WIDTH * 0.5
		var board := leaf_width / 6.0
		# THE LEAF IS A GRID OF PLANKS: six columns by eight rows. A single tall board meant
		# that knocking it out tore an eleven-metre strip out of the door; with a grid a hit
		# opens a hole the size of the strike, which is what was asked for.
		var leaf_columns := 6
		var leaf_rows := 8
		var board_w := leaf_width / float(leaf_columns)
		var board_h := (GATE_HEIGHT * 0.96) / float(leaf_rows)
		var boards: Array = []
		for row: int in leaf_rows:
			for column: int in leaf_columns:
				var board_mesh := MeshInstance3D.new()
				var board_box := BoxMesh.new()
				# IN CONTACT, with a hair of overlap: at 0.98 and 0.97 the planks showed light
				# through the joints, which read as cracks in the door.
				board_box.size = Vector3(board_w * 1.004, board_h * 1.004, 0.26)
				board_mesh.mesh = board_box
				board_mesh.material_override = _materials["wood"]
				board_mesh.position = Vector3(
					-side * (board_w * (float(column) + 0.5)),
					board_h * (float(row) + 0.5) + GATE_HEIGHT * 0.02,
					0.0)
				pivot.add_child(board_mesh)
				boards.append({"mesh": board_mesh, "broken": false, "size": board_box.size})
		# The seams between the boards: shallow dark strips on the face, not slots.
		var seam_material := StandardMaterial3D.new()
		seam_material.albedo_color = Color(0.24, 0.15, 0.08)
		seam_material.roughness = 0.95
		for i: int in range(1, 6):
			var seam := MeshInstance3D.new()
			var seam_mesh := BoxMesh.new()
			seam_mesh.size = Vector3(0.045, GATE_HEIGHT * 0.94, 0.05)
			seam.mesh = seam_mesh
			seam.material_override = seam_material
			seam.position = Vector3(-side * (board * float(i)), GATE_HEIGHT * 0.5, 0.14)
			pivot.add_child(seam)
		for band: int in 3:
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(leaf_width * 0.98, 0.30, 0.34)
			strip.mesh = strip_mesh
			strip.material_override = _materials["iron"]
			strip.position = Vector3(-side * leaf_width * 0.5, GATE_HEIGHT * (0.18 + float(band) * 0.3), 0.0)
			pivot.add_child(strip)
			for stud: int in 5:
				var bolt := MeshInstance3D.new()
				var bolt_mesh := BoxMesh.new()
				bolt_mesh.size = Vector3(0.11, 0.11, 0.42)
				bolt.mesh = bolt_mesh
				bolt.material_override = _materials["iron"]
				bolt.position = Vector3(-side * leaf_width * (0.1 + float(stud) * 0.2),
					GATE_HEIGHT * (0.18 + float(band) * 0.3), 0.0)
				pivot.add_child(bolt)
		# The collision rides with the hinge, so an open gate is really open.
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.position = Vector3(-side * leaf_width * 0.5, GATE_HEIGHT * 0.5, 0.0)
		pivot.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# A thick leaf, because a thin one lets the camera cast straight through it and the
		# view ends up outside the gate looking in.
		box.size = Vector3(leaf_width, GATE_HEIGHT * 0.96, 0.7)
		shape.shape = box
		body.add_child(shape)
		body.set_meta("castle_gate", true)
		body.set_meta("surface", "wood")
		_gate_leaves.append({"pivot": pivot, "side": side, "body": body, "detached": false,
			"boards": boards})
		if side < 0.0: _gate_left = pivot
		else: _gate_right = pivot
	# THE LEVER, inside the courtyard by the gate: a post, a handle, and a hinge of its own.
	# Right beside the gate on the courtyard side, where a man coming out of the doors
	# cannot miss it.
	# At EYE HEIGHT on the wall beside the gate, where a man looks for it.
	var lever_base := at + Vector3(GATE_WIDTH * 0.5 + 1.3, 1.55, -1.1)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.16
	post_mesh.bottom_radius = 0.20
	post_mesh.height = 0.9
	post.mesh = post_mesh
	post.material_override = _materials["iron"]
	# A bracket bolted to the wall, and the post standing against it.
	post.position = lever_base
	var bracket := MeshInstance3D.new()
	var bracket_mesh := BoxMesh.new()
	bracket_mesh.size = Vector3(0.55, 0.22, 0.30)
	bracket.mesh = bracket_mesh
	bracket.material_override = _materials["iron"]
	bracket.position = lever_base + Vector3(0.0, 1.25, 0.32)
	add_child(bracket)
	add_child(post)
	_lever_pivot = Node3D.new()
	_lever_pivot.position = lever_base
	add_child(_lever_pivot)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.075
	handle_mesh.bottom_radius = 0.09
	handle_mesh.height = 1.1
	handle.mesh = handle_mesh
	handle.material_override = _materials["wood"]
	handle.position = Vector3(0.0, -0.5, 0.0)
	_lever_pivot.add_child(handle)
	_lever_pivot.rotation.x = -0.7
	_lever_pos = lever_base
	# A lamp over the lever: a mechanism nobody can find is a mechanism nobody uses.
	var lever_lamp := OmniLight3D.new()
	lever_lamp.light_color = Color(1.0, 0.78, 0.45)
	lever_lamp.light_energy = 2.2
	lever_lamp.omni_range = 6.0
	lever_lamp.position = lever_base + Vector3.UP * 2.1
	add_child(lever_lamp)

## Two flights up to the wall-walk, for archers.
##
## The steps are DRAWN, and an invisible RAMP carries the player up underneath them. A
## stair built from boxes of collision is a stair a character gets stuck on - the first
## version used half-metre steps and a single rectangular block for the whole flight, and
## he could not get up it at all. A ramp cannot be stuck on, and the steps are what is seen.
var _gate_left: Node3D
var _gate_right: Node3D
var _lever_pivot: Node3D
var _lever_pos := Vector3.ZERO
var _gate_open_state := false
var _gate_angle := 0.0
var _lever_angle := 0.5

## Swings the two leaves inward, smoothly, and back. The angle is eased every physics step,
## so the gate never snaps: a gate this heavy takes a moment to move.
func set_gate(open: bool) -> void:
	_gate_open_state = open

func _gate_boards_broken() -> int:
	var count := 0
	for entry: Dictionary in _gate_leaves:
		for board: Dictionary in entry.get("boards", []):
			if bool(board.get("broken", false)): count += 1
	return count

func _gate_leaves_detached() -> int:
	var count := 0
	for entry: Dictionary in _gate_leaves:
		if bool(entry.get("detached", false)): count += 1
	return count

func gate_open() -> bool:
	return _gate_open_state

func _leaf_debug() -> Dictionary:
	if _gate_leaves.is_empty(): return {}
	var pivot: Node3D = _gate_leaves[0].get("pivot")
	if not is_instance_valid(pivot): return {"pivot": "invalid"}
	var child: Node3D = pivot.get_child(0)
	return {"pivot": pivot.global_position,
		"child": child.global_position if is_instance_valid(child) else "none",
		"child_visible": child.is_visible_in_tree() if is_instance_valid(child) else false,
		"child_name": child.name if is_instance_valid(child) else "",
		"mats": _materials.size()}

func _count_gate_bricks() -> int:
	var count := 0
	for cell: Dictionary in _cells:
		if not bool(cell.get("alive", false)): continue
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		if absf(at.x) < 4.4 and at.y > 1.0 and at.y < 10.0 and absf(at.z - WALL_HALF) < 1.6:
			count += 1
	return count

func gate_angle() -> float:
	return _gate_angle

func lever_position() -> Vector3:
	return _lever_pos

## True when E would work the lever from where the player is standing.
func wants_e() -> bool:
	if not _ready or not is_instance_valid(_player): return false
	return _player.global_position.distance_to(_lever_pos) <= 2.6

## E at the lever works the gate. The gate is the player's own business, so it answers the
## key itself rather than going through the weapons.
func _unhandled_input(event: InputEvent) -> void:
	if not _ready or not is_instance_valid(_player): return
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_E: return
	if not bool(_player.get("_free_mouse_look")): return
	if _player.global_position.distance_to(_lever_pos) > 2.6: return
	set_gate(not _gate_open_state)
	get_viewport().set_input_as_handled()

func _advance_gate(delta: float) -> void:
	if not is_instance_valid(_gate_left) or not is_instance_valid(_gate_right): return
	var target := 1.0 if _gate_open_state else 0.0
	_gate_angle = move_toward(_gate_angle, target, (1.0 / 1.6) * delta)
	var eased := smoothstep(0.0, 1.0, _gate_angle)
	_gate_left.rotation.y = eased * 1.85
	_gate_right.rotation.y = -eased * 1.85
	if is_instance_valid(_lever_pivot):
		_lever_angle = lerpf(0.5, -0.5, eased)
		_lever_pivot.rotation.z = _lever_angle

## Flights up to the wall-walk, one on every wall.
##
## The first version climbed AWAY from the wall: it reached nineteen metres at a point
## twenty-six metres out in the courtyard, with nothing to step onto. A stair to the
## battlements must LAND on them, so each flight now runs from deep in the courtyard up to
## the wall head, and the wall carries a walk along its whole length for the archers.
func _build_stairs() -> void:
	var flights := [
		{"normal": Vector3(0.0, 0.0, 1.0), "name": "south"},
		{"normal": Vector3(1.0, 0.0, 0.0), "name": "east"},
		{"normal": Vector3(0.0, 0.0, -1.0), "name": "north"},
		{"normal": Vector3(-1.0, 0.0, 0.0), "name": "west"},
	]
	for flight: Dictionary in flights:
		_build_stair_flight(flight["normal"], str(flight["name"]))

func _build_stair_flight(normal: Vector3, name: String) -> void:
	var rise := 0.26
	var run := 0.36
	var width := 2.8
	var steps := int(ceil(WALL_HEIGHT / rise))
	var length := float(steps) * run
	var top_height := float(steps) * rise
	var inward: Vector3 = -normal
	var lateral: Vector3 = Vector3(inward.z, 0.0, -inward.x).normalized()
	var lateral_offset := WALL_HALF * 0.42
	# The wall head is where the flight ENDS; the foot runs back into the courtyard.
	var top_centre: Vector3 = -inward * (WALL_HALF - 2.2) + lateral * lateral_offset
	var bottom_centre: Vector3 = top_centre + inward * length
	# THE FLIGHT IS A THIN DECK ON PILLARS. A solid wedge from the ground up is a wall you
	# cannot pass, and a man should be able to walk under a staircase - that is where a
	# castle puts its stores. The deck carries the climb, the pillars stand every couple of
	# metres, and between them there is a way through.
	var slope: Vector3 = -inward
	var deck_thickness := 0.45
	var deck_point_a: Vector3 = bottom_centre - Vector3.UP * (deck_thickness * 0.5)
	var deck_point_b: Vector3 = top_centre + Vector3.UP * (top_height - deck_thickness * 0.5)
	var deck_mid: Vector3 = (deck_point_a + deck_point_b) * 0.5
	var deck_length: float = (deck_point_b - deck_point_a).length()
	var deck_up: Vector3 = (Vector3.UP - slope * slope.dot(Vector3.UP)).normalized()
	var deck_basis := Basis(lateral, deck_up, -slope)
	var deck := StaticBody3D.new()
	deck.collision_layer = 1
	deck.collision_mask = 1
	deck.set_meta("surface", "stone")
	deck.transform = Transform3D(deck_basis, deck_mid)
	add_child(deck)
	var deck_shape := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	deck_box.size = Vector3(width, deck_thickness, deck_length)
	deck_shape.shape = deck_box
	deck.add_child(deck_shape)
	var stations: int = maxi(2, int(length / 2.6))
	for station: int in stations:
		var along: float = (float(station) + 0.5) * (length / float(stations))
		var height: float = (along / length) * top_height
		var at: Vector3 = bottom_centre + slope * along + Vector3.UP * (height * 0.5 - deck_thickness)
		var pillar := StaticBody3D.new()
		pillar.collision_layer = 1
		pillar.collision_mask = 1
		pillar.set_meta("surface", "stone")
		pillar.position = at
		add_child(pillar)
		var pillar_shape := CollisionShape3D.new()
		var pillar_box := BoxShape3D.new()
		pillar_box.size = Vector3(0.8, maxf(0.4, height - deck_thickness), 0.8)
		pillar_shape.shape = pillar_box
		pillar.add_child(pillar_shape)
		var pillar_mesh := MeshInstance3D.new()
		var pillar_mesh_box := BoxMesh.new()
		pillar_mesh_box.size = pillar_box.size
		pillar_mesh.mesh = pillar_mesh_box
		pillar_mesh.material_override = _materials["cold"]
		pillar_mesh.position = at
		add_child(pillar_mesh)
	# The steps, drawn but not colliding: the deck carries the man. They must climb the
	# SAME WAY as the wedge - towards the wall - or the stone you see and the stone you walk
	# on are two different staircases, and the end of the wedge shows as a flat grey face at
	# the foot of the steps.
	for i: int in steps:
		var at: Vector3 = bottom_centre - inward * (float(i) * run) + Vector3.UP * (rise * float(i) + rise * 0.5)
		_add_brick(at, Vector3(width, rise, run * 1.04), "cold", Vector3.ZERO, "stairs_" + name, i, 0)
		_add_brick(at + lateral * (width * 0.5 + 0.16) + Vector3.UP * 0.55,
			Vector3(0.32, 1.0, run * 1.04), "stone", Vector3.ZERO, "stairs_rail_" + name, i, 0)

func _build_keep() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	var courses := int(KEEP_SIZE.y / BRICK.y)
	var per_course := int(KEEP_SIZE.x / BRICK.x)
	# The keep is LAID IN BRICKS on all four faces - a solid box underneath it would hide
	# every one of them behind a flat slab, which is exactly how it looked: a featureless
	# monolith with no windows at all.
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
	# Collision inside the brick skin, so the tower is solid but its face is the masonry.
	_add_mortar(base + Vector3.UP * KEEP_SIZE.y * 0.5,
		Vector3(KEEP_SIZE.x - 0.5, KEEP_SIZE.y, KEEP_SIZE.z - 0.5))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = base + Vector3.UP * KEEP_SIZE.y * 0.5
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(KEEP_SIZE.x - 0.6, KEEP_SIZE.y, KEEP_SIZE.z - 0.6)
	shape.shape = box
	body.add_child(shape)
	# A roof slab, so the keep is not an open-topped shell.
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(KEEP_SIZE.x + 0.8, 0.5, KEEP_SIZE.z + 0.8)
	roof.mesh = roof_mesh
	roof.material_override = _materials["cold"]
	roof.position = base + Vector3.UP * (KEEP_SIZE.y + 0.25)
	add_child(roof)
	# And a floor, for a man standing inside it.
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(KEEP_SIZE.x - 0.4, 0.2, KEEP_SIZE.z - 0.4)
	floor_mesh.mesh = floor_box
	floor_mesh.material_override = _materials["warm"]
	floor_mesh.position = base + Vector3.UP * 0.1
	add_child(floor_mesh)
## ------------------------------------------------------------------ colour and banners
## Banners hanging on the walls, in the colour of the house, with a gold device: a
const WALK_WIDTH := 3.0
const WALK_PARAPET := 0.9

## THE WALL-WALK: a continuous platform round all four walls at the wall head, wide enough
## for two men to pass, with a waist-high parapet on the courtyard side. Without it the
## battlements are decoration nobody can stand on.
func _build_wall_walks() -> void:
	for side: String in ["north", "south", "east", "west"]:
		var vertical: bool = side == "north" or side == "south"
		var sign_z: float = 1.0 if side == "south" else -1.0
		var sign_x: float = 1.0 if side == "east" else -1.0
		var centre: Vector3
		if vertical:
			centre = Vector3(0.0, WALL_HEIGHT - 0.1, sign_z * (WALL_HALF - 0.55))
		else:
			centre = Vector3(sign_x * (WALL_HALF - 0.55), WALL_HEIGHT - 0.1, 0.0)
		var size := Vector3(WALK_WIDTH if vertical else WALL_HALF * 2.0, 0.24,
			WALL_HALF * 2.0 if vertical else WALK_WIDTH)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.position = centre
		add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		var slab := MeshInstance3D.new()
		var slab_mesh := BoxMesh.new()
		slab_mesh.size = size
		slab.mesh = slab_mesh
		slab.material_override = _materials["warm"]
		slab.position = centre
		add_child(slab)
		# The inner parapet: what keeps a man from falling into the courtyard.
		var inward_dir: Vector3 = Vector3(0.0, 0.0, -sign_z) if vertical else Vector3(-sign_x, 0.0, 0.0)
		var inner: Vector3 = centre + inward_dir * (WALK_WIDTH * 0.5 - 0.2)
		var parapet_size := Vector3(0.35, WALK_PARAPET, WALL_HALF * 2.0) if vertical \
			else Vector3(WALL_HALF * 2.0, WALK_PARAPET, 0.35)
		var parapet := StaticBody3D.new()
		parapet.collision_layer = 1
		parapet.collision_mask = 1
		parapet.position = inner + Vector3.UP * (WALK_PARAPET * 0.5 + 0.12)
		add_child(parapet)
		var parapet_shape := CollisionShape3D.new()
		var parapet_box := BoxShape3D.new()
		parapet_box.size = parapet_size
		parapet_shape.shape = parapet_box
		parapet.add_child(parapet_shape)
		var parapet_mesh := MeshInstance3D.new()
		var parapet_mesh_box := BoxMesh.new()
		parapet_mesh_box.size = parapet_size
		parapet_mesh.mesh = parapet_mesh_box
		parapet_mesh.material_override = _materials["cold"]
		parapet_mesh.position = parapet.position
		add_child(parapet_mesh)

## ------------------------------------------------------------------ colour and banners
func _build_wall_banners() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.46, 0.07, 0.08)
	cloth.roughness = 0.92
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.72, 0.55, 0.18)
	gold.metallic = 0.6
	gold.roughness = 0.42
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.26, 0.18, 0.11)
	pole.roughness = 0.9
	for side: String in ["north", "south", "east", "west"]:
		var vertical: bool = side == "north" or side == "south"
		var sign_z: float = 1.0 if side == "south" else -1.0
		var sign_x: float = 1.0 if side == "east" else -1.0
		# On the gate wall the middle bay IS the gate: a banner hanging over it reads as a
		# black stripe across the doors, so that wall gets its two side bays only.
		var bays: Array = [0, 2] if side == "south" else [0, 1, 2]
		for slot: int in bays:
			var along: float = (float(slot) - 1.0) * (WALL_HALF * 0.52)
			var anchor := Vector3.ZERO
			var outward := Vector3.ZERO
			if vertical:
				anchor = Vector3(along, WALL_HEIGHT - 0.5, sign_z * (WALL_HALF - 0.9))
				outward = Vector3(0.0, 0.0, sign_z)
			else:
				anchor = Vector3(sign_x * (WALL_HALF - 0.9), WALL_HEIGHT - 0.5, along)
				outward = Vector3(sign_x, 0.0, 0.0)
			var rotation_y: float = 0.0 if vertical else PI * 0.5
			# The cross-bar the cloth hangs from.
			var bar := MeshInstance3D.new()
			var bar_mesh := CylinderMesh.new()
			bar_mesh.top_radius = 0.07
			bar_mesh.bottom_radius = 0.07
			bar_mesh.height = 2.5
			bar.mesh = bar_mesh
			bar.material_override = pole
			bar.position = anchor
			bar.rotation = Vector3(0.0, rotation_y, PI * 0.5)
			add_child(bar)
			# The cloth, hanging two metres down the face.
			var flag := MeshInstance3D.new()
			var flag_mesh := BoxMesh.new()
			flag_mesh.size = Vector3(2.3, 4.2, 0.07)
			flag.mesh = flag_mesh
			flag.material_override = cloth
			flag.position = anchor + Vector3(0.0, -2.15, 0.0) - outward * 0.06
			flag.rotation = Vector3(0.0, rotation_y, 0.0)
			add_child(flag)
			# A gold device: three petals and a bar, a fleur-de-lis at any distance.
			for petal: int in 3:
				var device := MeshInstance3D.new()
				var device_mesh := BoxMesh.new()
				device_mesh.size = Vector3(0.22, 1.05 if petal == 1 else 0.75, 0.05)
				device.mesh = device_mesh
				device.material_override = gold
				var offset_x: float = 0.0 if petal == 1 else (-0.30 if petal == 0 else 0.30)
				device.position = anchor + Vector3(offset_x, -1.7, 0.0) + outward * 0.02
				device.rotation = Vector3(0.0, rotation_y, 0.0)
				add_child(device)
			var band := MeshInstance3D.new()
			var band_mesh := BoxMesh.new()
			band_mesh.size = Vector3(0.95, 0.18, 0.05)
			band.mesh = band_mesh
			band.material_override = gold
			band.position = anchor + Vector3(0.0, -2.25, 0.0) + outward * 0.02
			band.rotation = Vector3(0.0, rotation_y, 0.0)
			add_child(band)

## ------------------------------------------------------------------ the floor
## The courtyard is laid in BRICKS, a shade cooler and darker than the walls, so the
## ground does not read as one poured slab. Drawn as a MultiMesh (one draw call) with a
## little variation per stone; the collision is the flat slab that was already there.
func _build_brick_floor() -> void:
	var paving := StandardMaterial3D.new()
	paving.albedo_color = Color(0.44, 0.42, 0.40)
	paving.roughness = 1.0
	var stone_mesh := BoxMesh.new()
	stone_mesh.size = Vector3(1.86, 0.10, 0.92)
	var per_row: int = int((WALL_HALF * 2.0) / 0.90)
	var rows: int = int((WALL_HALF * 2.0) / 0.46)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = stone_mesh
	multi.instance_count = per_row * rows
	var slot := 0
	for row: int in rows:
		var offset: float = 0.0 if row % 2 == 0 else 0.95
		for column: int in per_row:
			var x: float = (float(column) - float(per_row - 1) * 0.5) * 0.90 + offset
			var z: float = (float(row) - float(rows - 1) * 0.5) * 0.46
			var basis := Basis.from_euler(Vector3(0.0, float(int(x * 31.0 + z * 17.0) % 7) * 0.006, 0.0))
			multi.set_instance_transform(slot, Transform3D(basis, Vector3(x, 0.02, z)))
			var tone: float = 0.88 + float(abs(int(x * 131.0) ^ int(z * 977.0)) % 100) / 100.0 * 0.22
			multi.set_instance_color(slot, Color(tone, tone * 0.99, tone * 0.97))
			slot += 1
	var node := MultiMeshInstance3D.new()
	node.name = "FloorBricks"
	node.multimesh = multi
	node.material_override = paving
	add_child(node)
## ------------------------------------------------------------------ distance and detail
## A plain slab standing in for the masonry beyond the brick-LOD distance: without it the
## walls would vanish at a hundred metres, and with it a far view costs four boxes.
func _build_far_slabs() -> void:
	for side: String in ["north", "south", "east", "west"]:
		var vertical: bool = side == "north" or side == "south"
		var sign_z: float = 1.0 if side == "south" else -1.0
		var sign_x: float = 1.0 if side == "east" else -1.0
		var centre := Vector3(0.0, WALL_HEIGHT * 0.5, sign_z * WALL_HALF) if vertical \
			else Vector3(sign_x * WALL_HALF, WALL_HEIGHT * 0.5, 0.0)
		var size := Vector3(WALL_HALF * 2.0, WALL_HEIGHT, WALL_THICK) if vertical \
			else Vector3(WALL_THICK, WALL_HEIGHT, WALL_HALF * 2.0)
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		slab.mesh = box
		slab.material_override = _materials["stone"]
		slab.position = centre
		slab.visibility_range_begin = BRICK_LOD_END - 4.0
		slab.visibility_range_begin_margin = 6.0
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(slab)
		# The shadow proxy: the same box, invisible, casting what the bricks no longer cast.
		var proxy := MeshInstance3D.new()
		var proxy_box := BoxMesh.new()
		proxy_box.size = size
		proxy.mesh = proxy_box
		var hidden := StandardMaterial3D.new()
		hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hidden.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
		proxy.material_override = hidden
		proxy.position = centre
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(proxy)

## String courses: a band of stone standing proud of the wall at two heights, which is the
## cheapest way to break a flat face - one line and the wall stops being a panel.
func _build_string_courses() -> void:
	for side: String in ["north", "south", "east", "west"]:
		var vertical: bool = side == "north" or side == "south"
		var per_course: int = int((WALL_HALF * 2.0) / BRICK.x)
		for height in [WALL_HEIGHT * 0.42, WALL_HEIGHT * 0.78]:
			for column: int in per_course:
				var along: float = (float(column) - float(per_course - 1) * 0.5) * BRICK.x
				# The band stops at the gate: a course of stone run across the doorway is a
				# bar on the doors.
				if side == "south" and absf(along) < GATE_WIDTH * 0.5 + 1.0: continue
				var at := Vector3.ZERO
				var size := Vector3(BRICK.x * 1.02, 0.34, WALL_THICK * 1.22)
				match side:
					"north": at = Vector3(along, height, -WALL_HALF)
					"south": at = Vector3(along, height, WALL_HALF)
					"east":
						at = Vector3(WALL_HALF, height, along)
						size = Vector3(WALL_THICK * 1.22, 0.34, BRICK.x * 1.02)
					"west":
						at = Vector3(-WALL_HALF, height, along)
						size = Vector3(WALL_THICK * 1.22, 0.34, BRICK.x * 1.02)
				_add_brick(at, size, "cold", Vector3.ZERO, side + "_course", 0, column)
## A ROAD AROUND THE CASTLE. Four paved strips running the whole way round the outside of
## the walls, wide enough to march a column along: the wall foot is where an army waits, and
## without it the outside of the castle is a field you can only cross by eye.
const RING_WIDTH := 9.0
const RING_GAP := 2.0

func _build_ring_road() -> void:
	var road := StandardMaterial3D.new()
	road.albedo_color = Color(0.38, 0.34, 0.28)
	road.roughness = 1.0
	var kerb := StandardMaterial3D.new()
	kerb.albedo_color = Color(0.52, 0.50, 0.46)
	kerb.roughness = 0.95
	var ring_radius: float = WALL_HALF + RING_GAP + RING_WIDTH * 0.5
	for side: String in ["north", "south", "east", "west"]:
		var vertical: bool = side == "north" or side == "south"
		var sign_z: float = 1.0 if side == "south" else -1.0
		var sign_x: float = 1.0 if side == "east" else -1.0
		# The strip runs past the corners so the four of them join without a gap.
		var span: float = WALL_HALF * 2.0 + (RING_WIDTH + RING_GAP) * 2.0
		var centre := Vector3(0.0, 0.02, sign_z * ring_radius) if vertical \
			else Vector3(sign_x * ring_radius, 0.02, 0.0)
		var size := Vector3(span, 0.08, RING_WIDTH) if vertical \
			else Vector3(RING_WIDTH, 0.08, span)
		var strip := MeshInstance3D.new()
		var strip_box := BoxMesh.new()
		strip_box.size = size
		strip.mesh = strip_box
		strip.material_override = road
		strip.position = centre
		add_child(strip)
		# A kerb on the inner edge, so the road reads as a road.
		var inner := Vector3(0.0, 0.06, sign_z * (WALL_HALF + RING_GAP * 0.5)) if vertical \
			else Vector3(sign_x * (WALL_HALF + RING_GAP * 0.5), 0.06, 0.0)
		var kerb_size := Vector3(span, 0.12, 0.5) if vertical else Vector3(0.5, 0.12, span)
		var kerb_mesh := MeshInstance3D.new()
		var kerb_box := BoxMesh.new()
		kerb_box.size = kerb_size
		kerb_mesh.mesh = kerb_box
		kerb_mesh.material_override = kerb
		kerb_mesh.position = inner
		add_child(kerb_mesh)
	# The ground under the road must be walkable stone, so a footstep there is stone too.
	var ring_body := StaticBody3D.new()
	ring_body.name = "RingRoad"
	ring_body.collision_layer = 1
	ring_body.collision_mask = 1
	ring_body.set_meta("surface", "stone")
	ring_body.position = Vector3(0.0, -0.02, 0.0)
	add_child(ring_body)
	var ring_shape := CollisionShape3D.new()
	var ring_box_shape := BoxShape3D.new()
	var outer: float = WALL_HALF + RING_GAP + RING_WIDTH
	ring_box_shape.size = Vector3(outer * 2.0, 0.10, outer * 2.0)
	ring_shape.shape = ring_box_shape
	ring_body.add_child(ring_shape)
## ------------------------------------------------------------------ masonry detail
## A wall of identical stones still looks manufactured. These are the things that make it
## read as a building that has stood for a century: brackets under the battlements,
## buttresses where the wall is weakest, worn stones here and there, rubble at the foot.

## Machicolation corbels: the brackets that carry the battlements out over the wall.
func _add_corbels(side: String) -> void:
	var step := 2.6
	var count := int((WALL_HALF * 2.0) / step)
	for i: int in count:
		var along := (float(i) - float(count - 1) * 0.5) * step
		var at := Vector3.ZERO
		var size := Vector3(0.55, 0.9, 0.85)
		match side:
			"north": at = Vector3(along, WALL_HEIGHT - 0.45, -WALL_HALF + 0.55)
			"south": at = Vector3(along, WALL_HEIGHT - 0.45, WALL_HALF - 0.55)
			"east":
				at = Vector3(WALL_HALF - 0.55, WALL_HEIGHT - 0.45, along)
				size = Vector3(0.85, 0.9, 0.55)
			"west":
				at = Vector3(-WALL_HALF + 0.55, WALL_HEIGHT - 0.45, along)
				size = Vector3(0.85, 0.9, 0.55)
		_add_brick(at, size, "cold", Vector3.ZERO, side + "_corbel", 0, i)

## Buttresses: a thicker pier against the wall every dozen metres, which is both how the
## wall stands up and where the eye rests.
func _add_buttresses(side: String) -> void:
	var step := 15.0
	var count := int((WALL_HALF * 2.0) / step)
	for i: int in count:
		var along := (float(i) - float(count - 1) * 0.5) * step
		# NOT across the gate. A pier lands every fifteen metres, and one of them lands dead
		# centre on the opening - a column of brick standing where the doors are.
		if side == "south" and absf(along) < GATE_WIDTH * 0.5 + 2.5: continue
		for row: int in int(WALL_HEIGHT / BRICK.y):
			var at := Vector3.ZERO
			var size := Vector3(1.5, BRICK.y, 1.9)
			match side:
				"north": at = Vector3(along, (float(row) + 0.5) * BRICK.y, -WALL_HALF - 0.5)
				"south": at = Vector3(along, (float(row) + 0.5) * BRICK.y, WALL_HALF + 0.5)
				"east":
					at = Vector3(WALL_HALF + 0.5, (float(row) + 0.5) * BRICK.y, along)
					size = Vector3(1.9, BRICK.y, 1.5)
				"west":
					at = Vector3(-WALL_HALF - 0.5, (float(row) + 0.5) * BRICK.y, along)
					size = Vector3(1.9, BRICK.y, 1.5)
			_add_brick(at, size, "warm", Vector3.ZERO, side + "_buttress", row, i)

## A proper ARCH over the gate: wedge stones laid on a radius, not a flat lintel.
func _build_gate_arch() -> void:
	var at := Vector3(0.0, GATE_HEIGHT, WALL_HALF)
	var radius := GATE_WIDTH * 0.5
	var count := 15
	for i: int in count:
		var angle := PI * (float(i) + 0.5) / float(count)
		var offset := Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
		_add_brick(at + offset, Vector3(0.62, 1.05, WALL_THICK * 1.7), "cold",
			Vector3(0.0, 0.0, angle - PI * 0.5), "gate_voussoir", 0, i)
	# The springers on either side, where the arch meets the jambs.
	for side: float in [-1.0, 1.0]:
		_add_brick(at + Vector3(side * (radius + 0.3), -0.5, 0.0),
			Vector3(0.9, 1.2, WALL_THICK * 1.7), "stone", Vector3.ZERO, "gate_jamb", 0, 0)

## Rubble: chips of stone fallen from the walls over the years.
func _add_rubble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20251017
	for i: int in 240:
		var side := i % 4
		var along := rng.randf_range(-WALL_HALF + 2.0, WALL_HALF - 2.0)
		var out := WALL_HALF + rng.randf_range(-1.2, 3.0)
		var at := Vector3.ZERO
		match side:
			0: at = Vector3(along, rng.randf_range(0.02, 0.12), -out)
			1: at = Vector3(along, rng.randf_range(0.02, 0.12), out)
			2: at = Vector3(out, rng.randf_range(0.02, 0.12), along)
			_: at = Vector3(-out, rng.randf_range(0.02, 0.12), along)
		var size := Vector3(rng.randf_range(0.20, 0.55), rng.randf_range(0.10, 0.24),
			rng.randf_range(0.20, 0.55))
		_add_brick(at, size, "cold" if i % 3 != 0 else "warm",
			Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), "rubble", 0, i)

## Banners on the corner towers: cloth, a pole, and a colour that carries.
func _build_banners() -> void:
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.30, 0.22, 0.14)
	pole.roughness = 0.9
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.55, 0.09, 0.10)
	cloth.roughness = 0.85
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.08
		mast_mesh.bottom_radius = 0.10
		mast_mesh.height = 7.0
		mast.mesh = mast_mesh
		mast.material_override = pole
		mast.position = centre + Vector3.UP * (TOWER_HEIGHT + 3.4)
		add_child(mast)
		var flag := MeshInstance3D.new()
		var flag_mesh := BoxMesh.new()
		flag_mesh.size = Vector3(2.6, 1.5, 0.06)
		flag.mesh = flag_mesh
		flag.material_override = cloth
		flag.position = centre + Vector3(1.35, TOWER_HEIGHT + 5.6, 0.0)
		add_child(flag)
## ------------------------------------------------------------------ towers and bridges
## A tower that is a solid drum is a box. Each corner tower gets a FLOOR at the level of the
## wall-walk, an opening onto it, and crenellations above: a room at the top a man can walk
## into from the battlements, which is what the reference picture shows.
func _build_tower_platforms() -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
		# The floor of the upper room, at the height of the wall-walk.
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 1
		floor_body.collision_mask = 1
		floor_body.set_meta("surface", "stone")
		floor_body.position = centre + Vector3.UP * (WALL_HEIGHT - 0.1)
		add_child(floor_body)
		var floor_shape := CollisionShape3D.new()
		var floor_cylinder := CylinderShape3D.new()
		floor_cylinder.radius = TOWER_RADIUS - 0.35
		floor_cylinder.height = 0.24
		floor_shape.shape = floor_cylinder
		floor_body.add_child(floor_shape)
		var floor_mesh := MeshInstance3D.new()
		var floor_cylinder_mesh := CylinderMesh.new()
		floor_cylinder_mesh.top_radius = TOWER_RADIUS - 0.35
		floor_cylinder_mesh.bottom_radius = TOWER_RADIUS - 0.35
		floor_cylinder_mesh.height = 0.24
		floor_cylinder_mesh.radial_segments = 20
		floor_mesh.mesh = floor_cylinder_mesh
		floor_mesh.material_override = _materials["warm"]
		floor_mesh.position = floor_body.position
		add_child(floor_mesh)
		# A roof ring at the top, so the room is not open to the sky in the middle.
		var roof := MeshInstance3D.new()
		var roof_mesh := CylinderMesh.new()
		roof_mesh.top_radius = 0.8
		roof_mesh.bottom_radius = TOWER_RADIUS + 0.4
		roof_mesh.height = 2.4
		roof_mesh.radial_segments = 20
		roof.mesh = roof_mesh
		roof.material_override = _materials["cold"]
		roof.position = centre + Vector3.UP * (TOWER_HEIGHT + 1.2)
		add_child(roof)

## A HANGING BRIDGE between the two gate towers, at the height of the wall-walk: planks,
## two ropes, and nothing under them. The planks are bricks like everything else, so a stone
## from a catapult takes the bridge apart exactly the way it takes a wall apart.
func _build_gate_bridge() -> void:
	var y := WALL_HEIGHT + 0.15
	var span := GATE_WIDTH + 7.2
	var planks := 22
	var plank_w: float = span / float(planks)
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.52, 0.44, 0.30)
	rope.roughness = 0.95
	for i: int in planks:
		var x: float = -span * 0.5 + plank_w * (float(i) + 0.5)
		# A shallow sag in the middle, the way a rope bridge hangs.
		var sag: float = -0.28 * sin(PI * (float(i) + 0.5) / float(planks))
		_add_brick(Vector3(x, y + sag, WALL_HALF), Vector3(plank_w * 0.94, 0.16, 2.2),
			"wood", Vector3.ZERO, "bridge", 0, i)
	for side: float in [-1.0, 1.0]:
		for i: int in 9:
			var t_norm: float = float(i) / 8.0
			var x: float = -span * 0.5 + span * t_norm
			var sag: float = -0.28 * sin(PI * t_norm)
			var rope_mesh := MeshInstance3D.new()
			var rope_cylinder := CylinderMesh.new()
			rope_cylinder.top_radius = 0.05
			rope_cylinder.bottom_radius = 0.05
			rope_cylinder.height = span / 8.0 * 1.1
			rope_mesh.mesh = rope_cylinder
			rope_mesh.material_override = rope
			rope_mesh.position = Vector3(x, y + sag + 0.95, WALL_HALF + side * 1.15)
			rope_mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
			add_child(rope_mesh)
## ------------------------------------------------------------------ destruction
func owns_collider(body: Node) -> bool:
	if not is_instance_valid(body): return false
	return body.get_meta("castle_brick", false) or body.get_meta("castle_gate", false)

func wall_half() -> float:
	return WALL_HALF

func get_stats() -> Dictionary:
	return {
		"ok": _ready, "bricks": _cells.size(), "detached": _detached,
		"collapsed": _collapsed, "gates": _gate_leaves.size(),
		"gate_open": _gate_leaves.size() > 0 and bool(_gate_leaves[0].get("detached", false)),
		"gate_leaves_detached": _gate_leaves_detached(),
		"gate_boards_broken": _gate_boards_broken(),
		"falling": _falling.size(), "events": _events.size(), "leaf_dbg": _leaf_debug(),
		"gate_bricks": _count_gate_bricks(),
	}

## A blast knocks out every brick inside its radius, and the courses above them come down
## a moment later.
func apply_explosion(event: Dictionary) -> Dictionary:
	if not _ready: return {"ok": false, "reason": "not_ready"}
	# The strike arrives in WORLD coordinates - a catapult stone knows nothing of this
	# node - while the bricks are laid in local ones.
	# The strike arrives in WORLD coordinates - a catapult stone knows nothing of this
	# node - while the bricks are laid in local ones. Both are kept: the gates hang on
	# nodes whose positions are world, and comparing those against a local point put them
	# nine hundred metres from every blast.
	var at_world: Vector3 = event.get("position", Vector3.ZERO)
	var at: Vector3 = to_local(at_world)
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
		var pivot: Node3D = entry.get("pivot")
		if not is_instance_valid(pivot): continue
		var boards: Array = entry.get("boards", [])
		# BOARD BY BOARD, where the stone struck. A leaf is six oak boards; a hit takes the
		# boards it reaches and leaves the rest of the door standing. Only when every board is
		# gone does the leaf come off its hinge.
		for board: Dictionary in boards:
			if bool(board.get("broken", false)): continue
			var board_mesh: MeshInstance3D = board.get("mesh")
			if not is_instance_valid(board_mesh): continue
			# Distance to the NEAREST POINT of the board, not to its middle: a stone that
			# strikes the top of a door is four metres from the centre of every board and was
			# measured as a miss.
			var board_at: Vector3 = board_mesh.global_position
			var flat := Vector2(at_world.x - board_at.x, at_world.z - board_at.z).length()
			var drop: float = maxf(0.0, absf(at_world.y - board_at.y) - GATE_HEIGHT * 0.46)
			# A stone takes the boards within about a metre of where it struck. The blast
			# radius is for masonry; a door gives way locally.
			# THE HOLE SCALES WITH THE STRIKE: a fast heavy stone takes more of the door than
			# a slow one. power arrives from the machine, so the hole is its own force.
			# A stone opens a patch about the size of itself, not half the door.
			var hole: float = clampf(0.5 + power * 0.004, 0.6, 2.0)
			if Vector2(flat, drop).length() > hole: continue
			board["broken"] = true
			board_mesh.visible = false
			killed += 1
			var plank := RigidBody3D.new()
			plank.collision_layer = 1
			plank.collision_mask = 1
			plank.mass = 30.0
			# IN THE TREE FIRST, then placed. Setting a global position before a node is
			# parented stores it as a LOCAL one, and against this castle at z=900 the board
			# was thrown nine hundred metres into the fields, which looked like it vanishing.
			add_child(plank)
			# OUTWARD, clear of the doorway, so the board is SEEN flying instead of being
			# hidden behind the door it came out of.
			var outward: Vector3 = Vector3(0.0, 0.0, 1.0) if global_position.z > 0.0 \
				else Vector3(0.0, 0.0, -1.0)
			plank.global_position = board_mesh.global_position + outward * 0.9 + Vector3.UP * 0.2
			var plank_shape := CollisionShape3D.new()
			var plank_box := BoxShape3D.new()
			# THE PIECE THAT FLIES IS THE PIECE THAT BROKE: a plank, not a twelve-metre
			# beam. The debris was sized as a whole door leaf, which is why long timbers kept
			# falling out of the gate.
			plank_box.size = board.get("size", Vector3(0.8, 1.4, 0.26))
			plank_shape.shape = plank_box
			plank.add_child(plank_shape)
			if _debris_mesh == null:
				_debris_mesh = BoxMesh.new()
				_debris_mesh.size = Vector3.ONE
			var plank_mesh := MeshInstance3D.new()
			plank_mesh.mesh = _debris_mesh
			plank_mesh.scale = plank_box.size
			plank_mesh.material_override = _materials["wood"]
			plank_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plank.add_child(plank_mesh)
			var away: Vector3 = direction.normalized() if direction.length_squared() > 1.0e-6 else Vector3.BACK
			plank.linear_velocity = (away * 0.8 + Vector3.UP * 0.35).normalized() \
				* clampf(power * 0.12, 3.0, 12.0) * randf_range(0.7, 1.3)
			plank.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0),
				randf_range(-4.0, 4.0))
			_falling.append({"body": plank, "age": 0.0})
			# A door does not break into one neat plank: chips of oak go with it, thrown
			# outward with the board so the break is seen as pieces and not as a hole.
			for splinter: int in 5:
				var chip := RigidBody3D.new()
				chip.collision_layer = 1
				chip.collision_mask = 1
				chip.mass = 2.0
				add_child(chip)
				chip.global_position = board_mesh.global_position + outward * 0.6 \
					+ Vector3(randf_range(-0.4, 0.4), randf_range(-1.2, 1.2), 0.0)
				var chip_shape := CollisionShape3D.new()
				var chip_box := BoxShape3D.new()
				chip_box.size = Vector3(randf_range(0.12, 0.3), randf_range(0.2, 0.5), 0.12)
				chip_shape.shape = chip_box
				chip.add_child(chip_shape)
				if _debris_mesh == null:
					_debris_mesh = BoxMesh.new()
					_debris_mesh.size = Vector3.ONE
				var chip_mesh := MeshInstance3D.new()
				chip_mesh.mesh = _debris_mesh
				chip_mesh.scale = chip_box.size
				chip_mesh.material_override = _materials["wood"]
				chip_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				chip.add_child(chip_mesh)
				chip.linear_velocity = (outward * 1.2 + Vector3.UP * randf_range(0.4, 1.2)
					+ Vector3(randf_range(-0.8, 0.8), 0.0, 0.0)).normalized() \
					* randf_range(5.0, 11.0)
				chip.angular_velocity = Vector3(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0),
					randf_range(-12.0, 12.0))
				_falling.append({"body": chip, "age": 0.0})
		var remaining := 0
		for board: Dictionary in boards:
			if not bool(board.get("broken", false)): remaining += 1
		if remaining > 0 or bool(entry.get("detached", false)): continue
		entry["detached"] = true
		_gate_open_state = false
		_gate_angle = 0.0
		pivot.visible = false
		for child: Node in pivot.get_children():
			var child_body := child as StaticBody3D
			if is_instance_valid(child_body):
				child_body.collision_layer = 0
				child_body.collision_mask = 0
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
	_advance_gate(_delta)
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
		var age: float = float(entry.get("age", 0.0)) + _delta
		entry["age"] = age
		# A stone that has stopped is rubble, not a moving body. Retiring its solver is the
		# single biggest saving after a blast: a hundred solvers awake is what stalls the
		# frame, and once they are asleep the cost is their meshes and nothing else.
		# ONLY when it has actually come to rest. Freezing on a timer alone left boards
		# hanging in mid-air exactly where they were blown to.
		var resting: bool = body.linear_velocity.length() < 0.7 \
			and body.angular_velocity.length() < 1.6
		if ((age > BRICK_SETTLE_S and resting) or age > 6.0) \
				and not bool(entry.get("settled", false)):
			entry["settled"] = true
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			body.freeze = true
			body.collision_layer = 0
			body.collision_mask = 0
		if age > BRICK_LIFE_S:
			body.queue_free()
			_falling.remove_at(index)

## Where the player appears: in the courtyard, with the gate behind him.
func spawn_point() -> Vector3:
	return global_position + Vector3(0.0, 1.2, 14.0)
