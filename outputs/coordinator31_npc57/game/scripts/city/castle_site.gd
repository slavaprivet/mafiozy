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
const ArmoryStorage = preload("res://scripts/city/castle_armory_storage.gd")
var armory_storage: Node

func _build_furniture_meshes() -> void:
	# Unit sized profiles use the same chunked MultiMesh/damage path as brick cells.
	var turned := CylinderMesh.new()
	turned.top_radius = 0.34
	turned.bottom_radius = 0.43
	turned.height = 1.0
	turned.radial_segments = 8
	var cup := CylinderMesh.new()
	cup.top_radius = 0.45
	cup.bottom_radius = 0.24
	cup.height = 1.0
	cup.radial_segments = 10
	var disk := CylinderMesh.new()
	disk.top_radius = 0.5
	disk.bottom_radius = 0.5
	disk.height = 1.0
	disk.radial_segments = 12
	var soft := SphereMesh.new()
	soft.radius = 0.5
	soft.height = 1.0
	soft.radial_segments = 12
	soft.rings = 6
	_furniture_meshes = {"turned": turned, "cup": cup, "disk": disk, "soft": soft}
## DSH_OPT: a blast must not spawn a thousand solvers. Debris is capped, its physics is
## retired once it has settled, and every brick shares one mesh.
const MAX_FALLING := 150
const BRICK_SETTLE_S := 1.4
const BRICK_LIFE_S := 30.0
var _debris_mesh: BoxMesh
var _debris_materials: Dictionary = {}
## DSH_OPT: dead stones come back here instead of being freed. A blast that reuses its stones
## allocates nothing, and allocation spikes are what a hitch is made of.
var _debris_pool: Array[RigidBody3D] = []
## DSH_OPT: the build is timed by phase when --castle-timing=1 is passed, so a slow map
## load is attacked where the seconds actually are.
var _phase_us := 0
var _phase_name := ""
var _phase_report: Array[String] = []
var _phase_enabled := false

func _phase(label: String) -> void:
	var now := Time.get_ticks_usec()
	if _phase_name != "":
		_phase_report.append("%s=%.1fms" % [_phase_name, float(now - _phase_us) / 1000.0])
	_phase_name = label
	_phase_us = now

func _phase_done() -> void:
	var now := Time.get_ticks_usec()
	if _phase_name != "":
		_phase_report.append("%s=%.1fms" % [_phase_name, float(now - _phase_us) / 1000.0])
	_phase_name = ""
	if _phase_enabled:
		print("DSH_PHASES ", " ".join(_phase_report))
	_phase_report.clear()
const DEBRIS_POOL_MAX := 220
var _reused_stones := 0

## Put a stone away: hidden, frozen, out of every collision, and kept for the next blast.
func _recycle_stone(body: RigidBody3D) -> void:
	if not is_instance_valid(body): return
	if _debris_pool.size() >= DEBRIS_POOL_MAX:
		body.queue_free()
		return
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	_debris_pool.append(body)

const WALL_HEIGHT := 19.0
const WALL_HALF := 68.0          # half of the outside square: a siege map, not a yard
const WALL_THICK := 1.1
const ARROW_PORT_WIDTH := 0.32
const ARROW_PORT_HEIGHT := 1.55
const ARROW_PORT_Y := 14.4
const ARROW_PORT_ALONG := [-20.0, 0.0, 20.0]
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
var _furniture_meshes: Dictionary = {}
var _cells: Array[Dictionary] = []
## Small lookup for direct furniture hits; a sword never scans all 60k wall stones.
var _furniture_cells: Dictionary = {}
## One MultiMesh per material, holding every brick that is still in place.
var _buckets: Dictionary = {}     # material_id -> {instance: MultiMeshInstance3D, indices: Array}
## DSH_OPT: a blast is local. This grid of cell indices means it tests the stones the
## explosion touches instead of walking all sixty thousand of them three times.
const SPATIAL_STEP := 8.0
var _spatial: Dictionary = {}
var _falling: Array[Dictionary] = []
var _gate_leaves: Array[Dictionary] = []
var _detached := 0
var _collapsed := 0
var _events: Array[Dictionary] = []
var _pending_support: Array[Dictionary] = []
var _wall_collision: Array[Dictionary] = []
var _ground: StaticBody3D
var _player: CharacterBody3D
var _world_ref: Node3D

## ------------------------------------------------------------------ build
func install(world: Node3D, origin: Vector3) -> Dictionary:
	if _ready: return {"ok": false, "reason": "already"}
	if not is_instance_valid(world): return {"ok": false, "reason": "no_world"}
	# DSH_OPT: --castle-timing=1 prints what each phase of the build costs.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--castle-timing="):
			_phase_enabled = int(argument.trim_prefix("--castle-timing=")) != 0
	_world_ref = world
	_player = world.get("_player") as CharacterBody3D
	# DSH_OPT: the project runs 4x MSAA and TAA at the same time. TAA already resolves
	# the brick edges - two settings measured 0.6/255 mean difference on stills - so on
	# the castle map the samples are spent on pixels instead. The city map keeps its own.
	if get_viewport() != null:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if _phase_enabled: _phase("_build_materials")
	_build_materials()
	_brick_mesh = BoxMesh.new()
	_brick_mesh.size = BRICK
	_build_furniture_meshes()
	if _phase_enabled: _phase("_build_environment")
	_build_environment()
	if _phase_enabled: _phase("_build_ground")
	_build_ground()
	if _phase_enabled: _phase("_build_path")
	_build_path()
	if _phase_enabled: _phase("_build_curtain_walls")
	_build_curtain_walls()
	if _phase_enabled: _phase("_build_corner_towers")
	_build_corner_towers()
	if _phase_enabled: _phase("_build_gatehouse")
	_build_gatehouse()
	if _phase_enabled: _phase("_build_exterior_crowns")
	_build_exterior_crowns()
	if _phase_enabled: _phase("_build_stairs")
	_build_stairs()
	if _phase_enabled: _phase("_build_wall_walks")
	_build_wall_walks()
	if _phase_enabled: _phase("_build_corner_bypasses")
	_build_corner_bypasses()
	if _phase_enabled: _phase("_build_gatehouse_bypass")
	_build_gatehouse_bypass()
	if _phase_enabled: _phase("_build_keep")
	_build_keep()
	if _phase_enabled: _phase("_build_keep_rooms")
	_build_keep_rooms()
	if _phase_enabled: _phase("_build_keep_interior")
	_build_keep_interior()
	if _phase_enabled: _phase("_build_keep_details")
	_build_keep_details()
	if _phase_enabled: _phase("_build_gate_arch")
	_build_gate_arch()
	if _phase_enabled: _phase("_build_banners")
	_build_banners()
	if _phase_enabled: _phase("_build_ring_road")
	_build_ring_road()
	if _phase_enabled: _phase("_build_tower_platforms")
	_build_tower_platforms()
	if _phase_enabled: _phase("_build_gate_bridge")
	_build_gate_bridge()
	# The far slabs are retired: the bricks are drawn at every distance anyway, so the
	# slab only covered the gate opening and any breach seen from afar with intact stone.
	if _phase_enabled: _phase("_build_string_courses")
	_build_string_courses()
	if _phase_enabled: _phase("_build_facade_relief")
	_build_facade_relief()
	if _phase_enabled: _phase("_build_entrance_layer31")
	_build_entrance_layer31()
	if _phase_enabled: _phase("_build_wall_banners")
	_build_wall_banners()
	if _phase_enabled: _phase("_build_brick_floor")
	_build_brick_floor()
	if _phase_enabled: _phase("_add_rubble")
	_add_rubble()
	if _phase_enabled: _phase("_build_torches")
	_build_torches()
	if _phase_enabled: _phase("_build_portcullis")
	_build_portcullis()
	if _phase_enabled: _phase("_build_gate_lamps")
	_build_gate_lamps()
	if _phase_enabled: _phase("_build_gate_deck")
	_build_gate_deck()
	if _phase_enabled: _phase("_cull_small_shadows")
	_cull_small_shadows()
	# Same triangles, same materials, same shadows - just not one draw call per bracket.
	if _phase_enabled: _phase("_batch_static_decoration")
	_batch_static_decoration()
	if _phase_enabled: _phase("_flush_buckets")
	_flush_buckets()
	if _phase_enabled: _phase_done()
	_ready = true
	if is_instance_valid(world.get("preview_weapons")):
		armory_storage = ArmoryStorage.new()
		armory_storage.name = "ArmoryStorage"
		add_child(armory_storage)
		var armoury_origin := Vector3(8.0, 0.0, -14.2)
		var points: Array[Vector3] = []
		for dz: float in [-3.85, -2.95, -0.45, 0.45, 2.95, 3.85]:
			points.append(armoury_origin + Vector3(1.1, 0.0, dz))
		points.append(armoury_origin + Vector3(1.1, 0.0, 5.2))
		armory_storage.configure(self, world.get("preview_weapons"), points,
			armoury_origin + Vector3(-2.6, 0.0, -2.0))
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
	var wood_alt := StandardMaterial3D.new()
	wood_alt.albedo_color = Color(0.33, 0.205, 0.11)
	wood_alt.roughness = 0.97
	var floor_wood := ShaderMaterial.new()
	var floor_grain := Shader.new()
	floor_grain.code = """
shader_type spatial;
render_mode diffuse_burley;
void fragment() {
	float grain = sin(UV.x * 96.0 + UV.y * 3.0) * 0.045;
	ALBEDO = vec3(0.49, 0.32, 0.19) * (1.0 + grain) * COLOR.rgb;
	ROUGHNESS = 0.94;
}
"""
	floor_wood.shader = floor_grain
	var linen := StandardMaterial3D.new()
	linen.albedo_color = Color(0.57, 0.52, 0.43)
	linen.roughness = 1.0
	var ochre := StandardMaterial3D.new()
	ochre.albedo_color = Color(0.70, 0.49, 0.19)
	ochre.roughness = 0.82
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
	var velvet := StandardMaterial3D.new()
	velvet.albedo_color = Color(0.42, 0.055, 0.075)
	velvet.roughness = 0.9
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.8, 0.59, 0.19)
	gold.metallic = 0.55
	gold.roughness = 0.4
	_materials = {"stone": stone, "warm": stone_warm, "cold": stone_cold,
		"wood": wood, "wood_alt": wood_alt, "floor_wood": floor_wood,
		"linen": linen, "ochre": ochre,
		"iron": iron, "grass": grass, "dark": dark,
		"velvet": velvet, "gold": gold}

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
	# Reach the inner edge of the outer ring road on every side. The previous
	# 68.8 m edge left a green strip between the wall and the road at 70 m.
	var paved_span := WALL_HALF * 2.0 + 2.0 * RING_GAP + 0.5
	courtyard_box.size = Vector3(paved_span, 0.12, paved_span)
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
	paving_shape.size = Vector3(paved_span, 0.10, paved_span)
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
	# GPU vertex sway animates every flame without a per-frame script or light flicker.
	# One shared material keeps all sconces in the same static batch. The
	# cylinder's UV.y runs from zero at the tip to one at the bowl after batching.
	var flame_shader := Shader.new()
	flame_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void vertex() {
	float height = clamp(1.0 - UV.y, 0.0, 1.0);
	float phase = TIME * 5.4 + VERTEX.x * 0.61 + VERTEX.z * 0.37;
	VERTEX.x += sin(phase + height * 3.8) * 0.095 * height;
	VERTEX.z += cos(phase * 0.78 + height * 4.1) * 0.055 * height;
}
void fragment() {
	vec3 ember = vec3(1.0, 0.27, 0.055);
	vec3 tip = vec3(1.0, 0.85, 0.34);
	ALBEDO = mix(ember, tip, clamp(1.0 - UV.y, 0.0, 1.0));
	EMISSION = ALBEDO * 3.2;
}
"""
	var flame := ShaderMaterial.new()
	flame.shader = flame_shader
	for at: Vector3 in positions:
		var outward: float = 1.0 if at.z > WALL_HALF else -1.0
		var plate := MeshInstance3D.new()
		plate.name = "GateSconceBackplate"
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(0.42, 0.64, 0.10)
		plate.mesh = plate_mesh
		plate.material_override = _materials["iron"]
		plate.position = at - Vector3(0.0, 0.06, outward * 0.22)
		add_child(plate)
		var bracket := MeshInstance3D.new()
		var bracket_mesh := BoxMesh.new()
		bracket_mesh.size = Vector3(0.16, 0.16, 0.76)
		bracket.mesh = bracket_mesh
		bracket.material_override = _materials["iron"]
		bracket.position = at + Vector3(0.0, -0.10, outward * 0.18)
		add_child(bracket)
		var cup_at := at + Vector3(0.0, 0.10, outward * 0.52)
		var bowl := MeshInstance3D.new()
		bowl.name = "GateSconceBowl"
		var bowl_mesh := CylinderMesh.new()
		bowl_mesh.top_radius = 0.31
		bowl_mesh.bottom_radius = 0.14
		bowl_mesh.height = 0.30
		bowl_mesh.radial_segments = 8
		bowl.mesh = bowl_mesh
		bowl.material_override = _materials["iron"]
		bowl.position = cup_at
		add_child(bowl)
		var torch := MeshInstance3D.new()
		torch.name = "GateSconceFlame"
		var torch_mesh := CylinderMesh.new()
		torch_mesh.top_radius = 0.0
		torch_mesh.bottom_radius = 0.23
		torch_mesh.height = 0.62
		torch_mesh.radial_segments = 7
		torch.mesh = torch_mesh
		torch.material_override = flame
		torch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		torch.position = cup_at + Vector3.UP * 0.40
		add_child(torch)
		# HALF THE LIGHTS, ALL OF THE GLOW. Four torches flank the gate but only one light per
		# side is needed - they are two metres apart - and the two high on the wall throw no
		# light at all: nothing a player can see is up there but the emissive flame itself.
		# Ten lights became four, and every lit surface in range stopped paying for them.
		if at.y < WALL_HEIGHT and at.x < 0.0:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.66, 0.34)
			light.light_energy = 2.6
			light.omni_range = 9.5
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
	# The gate deck and courtyard floor already meet here. A separate raised
	# threshold made a visible lip while adding an unnecessary collision island.
	_add_gate_threshold(Vector3(0.0, 0.02, WALL_HALF + 13.0),
		Vector3(GATE_WIDTH + 14.0, 0.12, 20.0), "GateOuterApron")
	_build_gate_forecourt_pavers()
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

func _add_gate_threshold(at: Vector3, size: Vector3, label: String) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("surface", "stone")
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _materials["stone"]
	body.add_child(visual)

## One batched paving draw call gives the wide stone approach a visible bond.
## The slab beneath, rather than hundreds of separate tiles, owns collision.
func _build_gate_forecourt_pavers() -> void:
	var paving := StandardMaterial3D.new()
	paving.albedo_color = Color(0.53, 0.50, 0.45)
	paving.roughness = 0.98
	var tile := BoxMesh.new()
	tile.size = Vector3(1.78, 0.035, 0.86)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = tile
	multi.instance_count = 12 * 22
	var slot := 0
	for row: int in 22:
		for column: int in 12:
			var x := (float(column) - 5.5) * 1.86 + (0.45 if row % 2 == 1 else 0.0)
			var z := WALL_HALF + 3.0 + (float(row) + 0.5) * 0.88
			multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY,
				Vector3(x, 0.093, z)))
			var tone := 0.88 + float((row * 17 + column * 29) % 11) * 0.013
			multi.set_instance_color(slot, Color(tone, tone * 0.98, tone * 0.94))
			slot += 1
	var stones := MultiMeshInstance3D.new()
	stones.name = "GateForecourtPavers"
	stones.multimesh = multi
	stones.material_override = paving
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stones)

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
				var at_x := base + Vector3(side * (half_x + WALL_THICK * 0.68),
					6.0 + float(storey) * 9.0, -4.6 + float(i) * 9.2)
				_add_brick(at_x, Vector3(0.14, 2.4, 1.2), "dark", Vector3.ZERO, "keep_window", storey, i)
				var sill_x := MeshInstance3D.new()
				var sill_x_mesh := BoxMesh.new()
				sill_x_mesh.size = Vector3(0.5, 0.18, 1.5)
				sill_x.mesh = sill_x_mesh
				sill_x.material_override = _materials["stone"]
				sill_x.position = at_x + Vector3(side * 0.12, -1.3, 0.0)
				add_child(sill_x)
				var at_z := base + Vector3(-4.6 + float(i) * 9.2,
					6.0 + float(storey) * 9.0, side * (half_z + WALL_THICK * 0.68))
				_add_brick(at_z, Vector3(1.2, 2.4, 0.14), "dark", Vector3.ZERO, "keep_window_z", storey, i)
				var sill_z := MeshInstance3D.new()
				var sill_z_mesh := BoxMesh.new()
				sill_z_mesh.size = Vector3(1.5, 0.18, 0.5)
				sill_z.mesh = sill_z_mesh
				sill_z.material_override = _materials["stone"]
				sill_z.position = at_z + Vector3(0.0, -1.3, side * 0.12)
				add_child(sill_z)
	# Buttresses at the corners of each face.
	for side: float in [-1.0, 1.0]:
		for other: float in [-1.0, 1.0]:
			var at := base + Vector3(side * (half_x + 0.45), KEEP_SIZE.y * 0.5, other * 5.4)
			for row: int in int((KEEP_SIZE.y - 3.0) / BRICK.y):
				_add_brick(Vector3(at.x, 1.5 + (float(row) + 0.5) * BRICK.y, at.z),
					Vector3(0.9, BRICK.y, 1.5), "warm", Vector3.ZERO, "keep_buttress", row, 0)
	# Stone bands mark the four levels; short modules can fall where struck.
	for level: int in 4:
		var height := 5.0 + float(level) * 9.0
		for i: int in 13:
			var along := -12.0 + float(i) * 2.0
			for side: float in [-1.0, 1.0]:
				_add_brick(base + Vector3(along, height, side * (half_z + 0.66)),
					Vector3(1.98, 0.26, 0.26), "cold", Vector3.ZERO, "keep_band", level, i)
				_add_brick(base + Vector3(side * (half_x + 0.66), height, along),
					Vector3(0.26, 0.26, 1.98), "cold", Vector3.ZERO, "keep_band", level, i)
	# The roof has an actual battlement silhouette instead of a flat square lid.
	for i: int in 13:
		if i % 2 == 1: continue
		var along := -12.0 + float(i) * 2.0
		for side: float in [-1.0, 1.0]:
			_add_brick(base + Vector3(along, KEEP_SIZE.y + 0.85, side * half_z),
				Vector3(1.75, 1.7, 0.95), "stone", Vector3.ZERO, "keep_merlon", 0, i)
			_add_brick(base + Vector3(side * half_x, KEEP_SIZE.y + 0.85, along),
				Vector3(0.95, 1.7, 1.75), "stone", Vector3.ZERO, "keep_merlon", 0, i)
## ------------------------------------------------------------------ bricks
## One brick at a place, drawn through its material's MultiMesh until it is knocked out.
func _add_brick(at: Vector3, size: Vector3, material_key: String, rotation: Vector3,
		group: String, row: int = 0, column: int = 0, shape_key: String = "box") -> int:
	var index := _cells.size()
	_cells.append({
		"at": at, "size": size, "material": material_key, "rotation": rotation,
		"group": group, "row": row, "column": column, "shape": shape_key,
		"alive": true, "instance": -1,
	})
	return index

## DSH_OPT: bricks are drawn in CHUNKS, not as one MultiMesh for the whole castle.
##
## A single MultiMesh is never frustum-culled - the engine has no way to know that most of
## a hundred-and-thirty-metre wall is behind you - so one big mesh would draw thirty
## thousand bricks every frame. Split into chunks of a few metres, each chunk is culled on
## its own and the cost follows what is on screen. Bricks that are knocked out are moved
## out of the chunk's mesh, and the falling body is spawned as before.
const CHUNK_X := 26.0
const CHUNK_Y := 10.0
const CHUNK_Z := 26.0

## DSH_OPT: a bracket, a stud, a rope or a lantern glass does not need to cast a shadow, and
## every caster is a draw in the shadow pass - the whole castle was 390 of them. Only shapes
## bigger than a metre and a half keep their shadow, so the walls, towers, gate and banners
## still throw exactly the shadow they did before.
func _cull_small_shadows() -> void:
	var kept := 0
	var dropped := 0
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null: continue
		if mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: continue
		var size := 0.0
		if mesh_instance.mesh != null:
			size = mesh_instance.mesh.get_aabb().size.length()
		if size <= 1.8:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dropped += 1
		else:
			kept += 1
	print("DSH_SHADOWS kept=", kept, " dropped=", dropped)
## DSH_OPT: one mesh per material instead of one node per bracket.
## Everything under the castle that never moves is appended into a single surface per
## material and the originals are freed. Triangles, materials and shadows are unchanged; the
## draw calls go from hundreds to a handful. The gate leaves (which swing and lose planks one
## by one) and the lever (which turns) are skipped.
func _batch_static_decoration() -> void:
	var groups: Dictionary = {}
	var doomed: Array[MeshInstance3D] = []
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance == null or instance.mesh == null: continue
		if _under_moving_parent(instance): continue
		# LOD slabs carry their own visibility range. Flattening them into the near
		# decoration mesh made the plain distant proxy cover all nearby masonry.
		if instance.visibility_range_begin > 0.0 or instance.visibility_range_end > 0.0:
			continue
		var material: Variant = instance.material_override
		if material == null and instance.mesh.get_surface_count() > 0:
			material = instance.mesh.surface_get_material(0)
		if material == null: continue
		# Family by LOOK, not by identity: a duplicate material with the same colour and the same
		# parameters draws identically, so it can share one merged surface.
		var key: String = _material_family(material) + "|" + instance.mesh.get_class()
		if not groups.has(key):
			groups[key] = {"material": material, "items": [], "shadow": false}
		var group: Dictionary = groups[key]
		(group["items"] as Array).append(instance)
		if instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			group["shadow"] = true
	var merged_nodes := 0
	var merged_sources := 0
	# Only what was really merged goes: the list is filled inside the merge loop, because a
	# group with a single member is left exactly as it is.
	var to_free: Array[MeshInstance3D] = []
	for key: String in groups:
		var group: Dictionary = groups[key]
		var items: Array = group.get("items", [])
		if items.size() < 2: continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var appended := 0
		for item: MeshInstance3D in items:
			if not is_instance_valid(item) or item.mesh == null: continue
			var relative: Transform3D = global_transform.affine_inverse() * item.global_transform
			tool.append_from(item.mesh, 0, relative)
			appended += 1
		if appended < 2: continue
		var merged: Mesh = tool.commit()
		if merged == null: continue
		var node := MeshInstance3D.new()
		node.name = "Batched_" + str(merged_nodes)
		node.mesh = merged
		node.material_override = group.get("material")
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(group.get("shadow", false)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		merged_nodes += 1
		merged_sources += items.size()
		# The geometry is copied into the merged surface; the originals can go now.
		for item: MeshInstance3D in items:
			if is_instance_valid(item):
				item.queue_free()
	print("DSH_BATCH merged_nodes=", merged_nodes, " sources_merged=", merged_sources,
		" left=", find_children("*", "MeshInstance3D", true, false).size())

## A stable key for "this will look the same as that": colour, roughness, metalness, emission
## and shading mode. Textured materials are keyed by their texture as well.
func _material_family(material: Variant) -> String:
	var standard := material as StandardMaterial3D
	if standard == null:
		return "other|%d" % (material as Resource).get_instance_id()
	var key := "%s|%s|%.3f|%.3f|%s|%d|%.2f" % [
		standard.albedo_color.to_html(),
		str(standard.albedo_texture != null),
		standard.roughness, standard.metallic,
		standard.emission.to_html(),
		standard.shading_mode,
		standard.emission_energy_multiplier]
	if standard.albedo_texture != null:
		key += "|%d" % standard.albedo_texture.get_instance_id()
	return key

func _under_moving_parent(node: Node) -> bool:
	var walk: Node = node
	while walk != null and walk != self:
		var name_text := String(walk.name)
		if name_text.begins_with("GateLeaf") or name_text.begins_with("Lever") \
			or name_text.begins_with("OuterLever"):
			return true
		walk = walk.get_parent()
	return false

## DSH_OPT: the iron bands, studs, hinges, stiles and the seam strips of one gate leaf
## never come apart on their own - they go when the whole leaf goes. Merged into one mesh
## per material they still swing on the hinge, and the leaf drops from ~40 draws to 2.
func _merge_pivot_decoration(pivot: Node3D) -> void:
	var groups: Dictionary = {}
	for child: Node in pivot.get_children():
		if child is MultiMeshInstance3D: continue
		var item := child as MeshInstance3D
		if item == null or item.mesh == null: continue
		var material: Variant = item.material_override
		if material == null and item.mesh.get_surface_count() > 0:
			material = item.mesh.surface_get_material(0)
		if material == null: continue
		var key: String = _material_family(material)
		if not groups.has(key):
			groups[key] = {"material": material, "items": []}
		(groups[key]["items"] as Array).append(item)
	var pivot_inverse: Transform3D = pivot.global_transform.affine_inverse()
	for key: String in groups:
		var items: Array = groups[key]["items"]
		if items.size() < 2: continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var appended := 0
		for item: MeshInstance3D in items:
			if not is_instance_valid(item) or item.mesh == null: continue
			tool.append_from(item.mesh, 0, pivot_inverse * item.global_transform)
			appended += 1
		if appended < 2: continue
		var merged: Mesh = tool.commit()
		if merged == null: continue
		var node := MeshInstance3D.new()
		node.name = "GateLeafFittings"
		node.mesh = merged
		node.material_override = groups[key]["material"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(node)
		for item: MeshInstance3D in items:
			if is_instance_valid(item):
				item.queue_free()

func _flush_buckets() -> void:
	_buckets.clear()
	_spatial.clear()
	for index: int in _cells.size():
		var cell: Dictionary = _cells[index]
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		var spatial_key := "%d|%d|%d" % [int(floor(at.x / SPATIAL_STEP)),
			int(floor(at.y / SPATIAL_STEP)), int(floor(at.z / SPATIAL_STEP))]
		if not _spatial.has(spatial_key):
			_spatial[spatial_key] = []
		(_spatial[spatial_key] as Array).append(index)
		var key := "%s|%s|%d|%d|%d" % [str(cell.get("material", "stone")),
			str(cell.get("shape", "box")),
			int(floor(at.x / CHUNK_X)), int(floor(at.y / CHUNK_Y)), int(floor(at.z / CHUNK_Z))]
		if not _buckets.has(key):
			_buckets[key] = {"indices": [], "material": str(cell.get("material", "stone")),
				"shape": str(cell.get("shape", "box"))}
		(_buckets[key]["indices"] as Array).append(index)
	var chunk_count := 0
	for key: String in _buckets.keys():
		var bucket: Dictionary = _buckets[key]
		var indices: Array = bucket["indices"]
		if indices.is_empty(): continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _furniture_meshes.get(str(bucket.get("shape", "box")), _brick_mesh)
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
		if str(bucket.get("material", "")) == "floor_wood":
			# Thin boards sit directly on solid tiles, so their shadow pass only
			# repeats the same surface at extra draw cost.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
##
## A chunk node is added at the castle's own origin and its bricks are spread along a whole
## wall, so asking whether the NODE's position is inside the camera said every chunk was on
## screen: all 60k stones "in frame" from any angle. The real answer is the world-space AABB
## of the chunk's LIVE instances, tested against the camera's frustum. Dead bricks are left
## out on purpose - a knocked-out stone is parked kilometres below the map so the engine
## would otherwise count it again.
func render_stats() -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var planes: Array[Plane] = []
	var inside_point := Vector3.ZERO
	if camera != null:
		planes = camera.get_frustum()
		# The camera lies ON four of its six planes (the sides), so it cannot say which
		# side of them is "inside". A metre in front of the lens can.
		inside_point = camera.global_position - camera.global_basis.z
	# One pass over the cells: each live brick grows the box of its own chunk, and each
	# chunk's live count is kept for the report.
	var bounds: Dictionary = {}
	var live_by_chunk: Dictionary = {}
	var alive := 0
	for cell: Dictionary in _cells:
		if not bool(cell.get("alive", false)): continue
		var key: String = str(cell.get("bucket", ""))
		if key == "": continue
		alive += 1
		live_by_chunk[key] = int(live_by_chunk.get(key, 0)) + 1
		var brick_box: AABB = _brick_transform(cell) * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		if bounds.has(key):
			bounds[key] = (bounds[key] as AABB).merge(brick_box)
		else:
			bounds[key] = brick_box
	var visible := 0
	var instances := 0
	var live := 0
	for key: String in _buckets.keys():
		var node: MultiMeshInstance3D = (_buckets[key] as Dictionary).get("node")
		if not is_instance_valid(node) or not bounds.has(key): continue
		live += 1
		var world_box: AABB = global_transform * (bounds[key] as AABB)
		if planes.is_empty() or _aabb_in_frustum(world_box, planes, inside_point):
			visible += 1
			instances += int(live_by_chunk.get(key, 0))
	return {"chunks": _chunk_total, "chunks_live": live, "chunks_in_frustum": visible,
		"bricks_in_frustum": instances, "bricks": _cells.size(), "bricks_alive": alive,
		"bounds_alive": bounds.size()}

## Conservative frustum test against a world-space box: a box is outside when its corner
## furthest along one plane's inward normal is still behind that plane. The inward side is
## anchored on the camera itself, which is always inside its own frustum.
func _aabb_in_frustum(box: AABB, planes: Array[Plane], inside_point: Vector3) -> bool:
	for plane: Plane in planes:
		var inward: float = 1.0 if plane.distance_to(inside_point) >= 0.0 else -1.0
		var positive := box.position
		if plane.normal.x >= 0.0: positive.x += box.size.x
		if plane.normal.y >= 0.0: positive.y += box.size.y
		if plane.normal.z >= 0.0: positive.z += box.size.z
		if plane.distance_to(positive) * inward < 0.0:
			return false
	return true
## A brick's transform: its place, its size, and a few degrees of settling so the wall
## does not look machine-made.
func _brick_transform(cell: Dictionary) -> Transform3D:
	var at: Vector3 = cell.get("at", Vector3.ZERO)
	var size: Vector3 = cell.get("size", BRICK)
	var group: String = str(cell.get("group", ""))
	var structural: bool = group == "keep" or group == "keep_floor_board" or group in ["north", "south", "east", "west", "tower", "gatehouse"]
	if structural:
		# A dark slit through a wall reads as a missing stone. Keep the joint tight;
		# colour variation and relief still give each course its bond.
		size = Vector3(size.x * 0.99, size.y * 0.98, size.z * 0.995)
	var rotation: Vector3 = cell.get("rotation", Vector3.ZERO)
	var jitter := 0.0 if structural else 1.0
	var basis := Basis.from_euler(Vector3(
		rotation.x + jitter * float(int(at.x * 7.0 + at.y * 13.0) % 5) * 0.004,
		rotation.y + jitter * float(int(at.z * 11.0 + at.y * 5.0) % 5) * 0.004,
		rotation.z))
	if str(cell.get("shape", "box")) == "box":
		basis = basis.scaled(Vector3(size.x / BRICK.x, size.y / BRICK.y, size.z / BRICK.z))
	else:
		basis = basis.scaled(size)
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
	# Long furnishings split into short boards instead of flying away as one
	# implausibly large box. The existing capped debris pool owns every piece.
	var material_key: String = str(cell.get("material", "stone"))
	var group: String = str(cell.get("group", ""))
	var size: Vector3 = cell.get("size", BRICK)
	if material_key.begins_with("wood") and (group.begins_with("hall_") or
			group.begins_with("armour_") or group.begins_with("archive_") or
			group.begins_with("chamber_")) and maxf(size.x, size.z) >= 1.5:
		var along_x: bool = size.x >= size.z
		var length: float = size.x if along_x else size.z
		var pieces: int = clampi(int(ceil(length / 1.0)), 2, 4)
		for piece: int in pieces:
			var fragment: Dictionary = cell.duplicate()
			var fragment_size := size
			var fragment_at: Vector3 = cell["at"]
			var offset: float = (float(piece) + 0.5 - float(pieces) * 0.5) * length / float(pieces)
			if along_x:
				fragment_size.x = length / float(pieces) * 0.97
				fragment_at.x += offset
			else:
				fragment_size.z = length / float(pieces) * 0.97
				fragment_at.z += offset
			fragment["size"] = fragment_size
			fragment["at"] = fragment_at
			_spawn_falling_brick(fragment, impulse, power * 0.65)
	else:
		_spawn_falling_brick(cell, impulse, power)

func _spawn_falling_brick(cell: Dictionary, impulse: Vector3, power: float) -> void:
	# FROM THE POOL when there is one: a blast that reuses its stones allocates nothing.
	var body: RigidBody3D = null
	while not _debris_pool.is_empty():
		var candidate: RigidBody3D = _debris_pool.pop_back()
		if is_instance_valid(candidate):
			body = candidate
			break
	var from_pool: bool = body != null
	if body == null:
		body = RigidBody3D.new()
		body.name = "Brick"
		body.mass = 18.0
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		body.add_child(shape)
		if _debris_mesh == null:
			_debris_mesh = BoxMesh.new()
			_debris_mesh.size = Vector3.ONE
		var fresh_mesh := MeshInstance3D.new()
		fresh_mesh.name = "Mesh"
		fresh_mesh.mesh = _debris_mesh
		fresh_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(fresh_mesh)
		add_child(body)
	var size: Vector3 = cell.get("size", BRICK)
	var material_key: String = str(cell.get("material", "stone"))
	var volume: float = size.x * size.y * size.z
	var density: float = 3.5 if material_key in ["wood", "wood_alt", "floor_wood"] else \
		0.8 if material_key in ["linen", "velvet"] else 18.0
	body.mass = clampf(volume * density, 0.3, 80.0)
	var body_shape: CollisionShape3D = body.get_node_or_null("Shape") as CollisionShape3D
	if body_shape != null:
		var box := BoxShape3D.new()
		box.size = size
		body_shape.shape = box
	var mesh_instance: MeshInstance3D = body.get_node_or_null("Mesh") as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.scale = size
		var key: String = str(cell.get("material", "stone"))
		var tint: Color = _brick_tint(cell)
		var debris_key := "%s|%d" % [key, int(tint.r * 40.0)]
		if not _debris_materials.has(debris_key):
			var base_material: Material = _materials.get(key, _materials["stone"])
			if base_material is StandardMaterial3D:
				var tinted: StandardMaterial3D = base_material.duplicate()
				tinted.albedo_color = Color(base_material.albedo_color.r * tint.r,
					base_material.albedo_color.g * tint.g, base_material.albedo_color.b * tint.b)
				_debris_materials[debris_key] = tinted
			else:
				_debris_materials[debris_key] = base_material
		mesh_instance.material_override = _debris_materials[debris_key]
	body.freeze = false
	body.collision_layer = 1
	body.collision_mask = 1
	body.visible = true
	body.position = cell.get("at", Vector3.ZERO)
	body.rotation = cell.get("rotation", Vector3.ZERO)
	var direction: Vector3 = impulse.normalized() if impulse.length_squared() > 1.0e-6 else Vector3.DOWN
	body.linear_velocity = (direction * 0.55 + Vector3.UP * 0.55).normalized() \
		* clampf(power * 0.35, 2.0, 26.0) * randf_range(0.7, 1.3)
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	_falling.append({"body": body, "age": 0.0})
	if from_pool:
		_reused_stones += 1
	while _falling.size() > MAX_FALLING:
		var oldest: Dictionary = _falling.pop_front()
		var old_body: Node = oldest.get("body")
		if is_instance_valid(old_body):
			_recycle_stone(old_body as RigidBody3D)
func _build_curtain_walls() -> void:
	# Four walls round the courtyard, laid course by course with a half-brick offset on
	# every other course, which is how a real bond looks.
	for side: String in ["north", "south", "east", "west"]:
		_build_wall(side)
		_add_battlements(side)
		# Narrow shooting ports are cut through both brick skins and collision.
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
	var layer_depth := WALL_THICK * 0.5
	for layer: int in 2:
		var layer_sign: float = -1.0 if layer == 0 else 1.0
		var inset: float = layer_sign * (WALL_THICK * 0.5 - layer_depth * 0.5)
		for row: int in courses:
			var offset := 0.0 if (row + layer) % 2 == 0 else BRICK.x * 0.5
			for column: int in per_course:
				var along := (float(column) - float(per_course - 1) * 0.5) * BRICK.x + offset
				# The gate is a real opening: no bricks inside it.
				if side == "south" and row * BRICK.y < GATE_HEIGHT \
					and absf(along) < GATE_WIDTH * 0.5 + BRICK.x * 0.5:
					continue
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
				_add_slit_cut_brick(at, size, side, row, column)
		# The wall itself is solid: one collision slab per wall, so the map is a place you
		# can lean on, not a curtain of loose stones.
	if side == "south":
		# The wall is solid EXCEPT at the gate: two piers and a lintel, so the opening can
		# be walked through and the masonry either side of it is still a wall.
		var pier: float = (WALL_HALF * 2.0 - GATE_WIDTH) * 0.5
		for pier_side: float in [-1.0, 1.0]:
			_add_wall_collision(Vector3(pier_side * (GATE_WIDTH * 0.5 + pier * 0.5), WALL_HEIGHT * 0.5, WALL_HALF),
				Vector3(pier, WALL_HEIGHT, WALL_THICK), "south")
		_add_wall_collision(Vector3(0.0, (WALL_HEIGHT + GATE_HEIGHT) * 0.5, WALL_HALF),
			Vector3(GATE_WIDTH, WALL_HEIGHT - GATE_HEIGHT, WALL_THICK), "south")
	elif side == "north":
		# RUN PAST THE CORNER. The wall box ended exactly at the corner, where the round
		# tower begins, and that joint was a seam a player could squeeze into. Extending it by
		# a tower radius costs nothing visible - the thickness is unchanged - and shuts it.
		_add_wall_collision(Vector3(0.0, WALL_HEIGHT * 0.5, -WALL_HALF),
			Vector3(WALL_HALF * 2.0 + TOWER_RADIUS * 2.0, WALL_HEIGHT, WALL_THICK), "north")
	else:
		_add_wall_collision(Vector3(WALL_HALF if side == "east" else -WALL_HALF, WALL_HEIGHT * 0.5, 0.0),
			Vector3(WALL_THICK, WALL_HEIGHT, WALL_HALF * 2.0 + TOWER_RADIUS * 2.0), side)

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

func _slit_pieces(at: Vector3, size: Vector3, side: String) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = [{"at": at, "size": size}]
	if side not in ["north", "south", "east", "west"]: return pieces
	if at.y + size.y * 0.5 <= ARROW_PORT_Y - ARROW_PORT_HEIGHT * 0.5 \
		or at.y - size.y * 0.5 >= ARROW_PORT_Y + ARROW_PORT_HEIGHT * 0.5:
		return pieces
	var along_x := side in ["north", "south"]
	for opening: float in ARROW_PORT_ALONG:
		var next_pieces: Array[Dictionary] = []
		for piece: Dictionary in pieces:
			var centre: Vector3 = piece["at"]
			var dimensions: Vector3 = piece["size"]
			var along: float = centre.x if along_x else centre.z
			var span: float = dimensions.x if along_x else dimensions.z
			var lo: float = along - span * 0.5
			var hi: float = along + span * 0.5
			var bottom: float = centre.y - dimensions.y * 0.5
			var top: float = centre.y + dimensions.y * 0.5
			var cut_lo: float = maxf(lo, opening - ARROW_PORT_WIDTH * 0.5)
			var cut_hi: float = minf(hi, opening + ARROW_PORT_WIDTH * 0.5)
			var cut_bottom: float = maxf(bottom, ARROW_PORT_Y - ARROW_PORT_HEIGHT * 0.5)
			var cut_top: float = minf(top, ARROW_PORT_Y + ARROW_PORT_HEIGHT * 0.5)
			if cut_hi <= cut_lo or cut_top <= cut_bottom:
				next_pieces.append(piece)
				continue
			for interval: Vector2 in [Vector2(lo, cut_lo), Vector2(cut_hi, hi)]:
				if interval.y - interval.x < 0.025: continue
				var fragment_at := centre
				var fragment_size := dimensions
				if along_x:
					fragment_at.x = (interval.x + interval.y) * 0.5
					fragment_size.x = interval.y - interval.x
				else:
					fragment_at.z = (interval.x + interval.y) * 0.5
					fragment_size.z = interval.y - interval.x
				next_pieces.append({"at": fragment_at, "size": fragment_size})
			for interval: Vector2 in [Vector2(bottom, cut_bottom), Vector2(cut_top, top)]:
				if interval.y - interval.x < 0.025: continue
				var fragment_at := centre
				var fragment_size := dimensions
				fragment_at.y = (interval.x + interval.y) * 0.5
				fragment_size.y = interval.y - interval.x
				if along_x:
					fragment_at.x = (cut_lo + cut_hi) * 0.5
					fragment_size.x = cut_hi - cut_lo
				else:
					fragment_at.z = (cut_lo + cut_hi) * 0.5
					fragment_size.z = cut_hi - cut_lo
				next_pieces.append({"at": fragment_at, "size": fragment_size})
		pieces = next_pieces
	return pieces

func _add_slit_cut_brick(at: Vector3, size: Vector3, side: String, row: int, column: int) -> void:
	for piece: Dictionary in _slit_pieces(at, size, side):
		_add_brick(piece["at"], piece["size"], "stone", Vector3.ZERO, side, row, column)

func _add_wall_collision(at: Vector3, size: Vector3, slit_side: String = "") -> void:
	# Split collision into bounded sections. A catapult breach must remove the solid
	# collision behind its missing bricks without making the whole wall intangible.
	var along_x := size.x >= size.z
	var horizontal := size.x if along_x else size.z
	var columns := maxi(1, int(ceil(horizontal / 3.8)))
	var levels := maxi(1, int(ceil(size.y / 3.8)))
	for column: int in columns:
		for level: int in levels:
			var section_size := size
			if along_x: section_size.x = horizontal / float(columns)
			else: section_size.z = horizontal / float(columns)
			section_size.y = size.y / float(levels)
			var section_at := at
			if along_x: section_at.x += -horizontal * 0.5 + (float(column) + 0.5) * section_size.x
			else: section_at.z += -horizontal * 0.5 + (float(column) + 0.5) * section_size.z
			section_at.y += -size.y * 0.5 + (float(level) + 0.5) * section_size.y
			for piece: Dictionary in _slit_pieces(section_at, section_size, slit_side):
				_add_breakable_collision(piece["at"], piece["size"])

func _add_breakable_collision(at: Vector3, size: Vector3, rotation_y: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = at
	body.rotation.y = rotation_y
	body.set_meta("castle_brick", true)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_wall_collision.append({"body": body, "at": at, "size": size, "alive": true})

func _break_collision_near(at: Vector3, radius: float) -> void:
	var world_at: Vector3 = to_global(at)
	for section: Dictionary in _wall_collision:
		if not bool(section.get("alive", false)): continue
		var body: StaticBody3D = section["body"]
		if not is_instance_valid(body): continue
		var size: Vector3 = section["size"]
		# DSH_OPT: a cheap sphere reject first. The exact test inverts a transform and
		# clamps a point, and most of the 2k sections are nowhere near the strike.
		var reach: float = radius + size.length() * 0.5
		if body.global_position.distance_squared_to(world_at) > reach * reach: continue
		# Floor tiles lose their own support when struck, leaving adjacent tiles intact.
		if body.get_meta("castle_keep_floor", false) and section["at"].distance_to(at) > radius:
			continue
		var local_hit: Vector3 = body.global_transform.affine_inverse() * world_at
		var nearest := Vector3(clampf(local_hit.x, -size.x * 0.5, size.x * 0.5),
			clampf(local_hit.y, -size.y * 0.5, size.y * 0.5),
			clampf(local_hit.z, -size.z * 0.5, size.z * 0.5))
		# The visible masonry uses the full impact radius; the collision must leave
		# the same opening, including curved tower panels just behind the outer skin.
		if nearest.distance_to(local_hit) > radius: continue
		section["alive"] = false
		body.collision_layer = 0

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
		# Sixteen curved collision panels per level keep the tower hollow. A stone
		# removes only the panels behind its visible masonry breach; no hidden
		# cylinder or corner block can continue to stop a player afterwards.
		var to_centre: Vector3 = Vector3(-corner.x, 0.0, -corner.y).normalized()
		var doorway_angle: float = atan2(to_centre.z, to_centre.x)
		var levels := int(ceil(TOWER_HEIGHT / 3.8))
		var segments := 16
		var arc_width := TAU * (TOWER_RADIUS - 0.25) / float(segments) * 1.035
		for level: int in levels:
			var panel_height := TOWER_HEIGHT / float(levels)
			var y := (float(level) + 0.5) * panel_height
			for segment: int in segments:
				var angle: float = TAU * (float(segment) + 0.5) / float(segments)
				if y > WALL_HEIGHT and absf(wrapf(angle - doorway_angle, -PI, PI)) < 0.42:
					continue
				var panel_at := centre + Vector3(cos(angle) * (TOWER_RADIUS - 0.25), y,
					sin(angle) * (TOWER_RADIUS - 0.25))
				_add_breakable_collision(panel_at, Vector3(arc_width, panel_height, 1.0),
					PI * 0.5 - angle)
		# Slits, facing outwards at three heights.
		for i: int in 6:
			var slit_angle := TAU * float(i) / 6.0
			for height: float in [6.4, 10.2, 14.4]:
				_add_brick(centre + Vector3(cos(slit_angle) * (TOWER_RADIUS + 0.05), height,
					sin(slit_angle) * (TOWER_RADIUS + 0.05)),
					Vector3(0.30, 1.25, 0.16), "dark", Vector3(0.0, -slit_angle, 0.0), "tower_slit")

## Projecting courses and spaced merlons make the four towers read above the long
## curtain walls. They use the existing breakable masonry buckets: no new static
## draw calls, lights, shadow casters or permanent collision bodies per stone.
func _build_exterior_crowns() -> void:
	var around := maxi(12, int(round(TAU * TOWER_RADIUS / (BRICK.x * 0.98))))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var centre := Vector3(corner.x * WALL_HALF, 0.0, corner.y * WALL_HALF)
		for tier: int in 2:
			var radius := TOWER_RADIUS + 0.22 + float(tier) * 0.28
			var height := TOWER_HEIGHT - 0.38 + float(tier) * 0.44
			for segment: int in around:
				var angle := TAU * (float(segment) + float(tier % 2) * 0.5) / float(around)
				_add_brick(centre + Vector3(cos(angle) * radius, height, sin(angle) * radius),
					Vector3(1.13, 0.38, 0.62), "cold" if tier == 0 else "warm",
					Vector3(0.0, -angle, 0.0), "tower_crown", tier, segment)
		for segment: int in around:
			if segment % 2 != 0: continue
			var angle := TAU * float(segment) / float(around)
			_add_brick(centre + Vector3(cos(angle) * (TOWER_RADIUS + 0.34),
				TOWER_HEIGHT + 0.85, sin(angle) * (TOWER_RADIUS + 0.34)),
				Vector3(1.12, 1.70, 0.72), "stone", Vector3(0.0, -angle, 0.0),
				"tower_crown_merlon", 0, segment)
	# A compact heraldic stone shield above the gate gives the entrance a focal
	# point. Relief stays in front of the facade and never closes the passage.
	var face_z := WALL_HALF + WALL_THICK * 0.98
	for row: int in 4:
		var half_width := 1.7 if row < 2 else (1.25 if row == 2 else 0.75)
		_add_brick(Vector3(0.0, 15.7 + float(row) * 0.68, face_z),
			Vector3(half_width * 2.0, 0.62, 0.28), "cold", Vector3.ZERO,
			"gate_shield", row, 0)
	_add_brick(Vector3(0.0, 16.92, face_z + 0.19), Vector3(0.35, 2.05, 0.12),
		"ochre", Vector3.ZERO, "gate_device")
	_add_brick(Vector3(0.0, 17.31, face_z + 0.19), Vector3(1.85, 0.32, 0.12),
		"ochre", Vector3.ZERO, "gate_device")

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
		_add_wall_collision(centre + Vector3.UP * 10.0,
			Vector3(per_course * BRICK.x, 20.0, WALL_THICK * 1.6))
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
		# DSH_OPT: the planks are drawn as TWO MultiMeshes per leaf, one per oak tone, not
		# as forty-eight meshes. A plank still breaks on its own: the broken one is parked
		# out of the world, exactly like a knocked-out brick, and its collider is disabled.
		var leaf_columns := 6
		var leaf_rows := 8
		var board_w := leaf_width / float(leaf_columns)
		var board_h := (GATE_HEIGHT * 0.96) / float(leaf_rows)
		var board_box := BoxMesh.new()
		# IN CONTACT, with a hair of overlap: at 0.98 and 0.97 the planks showed light
		# through the joints, which read as cracks in the door.
		board_box.size = Vector3(board_w * 1.004, board_h * 1.004, 0.62)
		var tone_counts: Dictionary = {}
		for column: int in leaf_columns:
			var tone: String = "wood_alt" if column % 3 == 1 else "wood"
			tone_counts[tone] = int(tone_counts.get(tone, 0)) + 1
		var board_multis: Dictionary = {}
		for tone: String in tone_counts:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = board_box
			multi.instance_count = int(tone_counts[tone]) * leaf_rows
			var boards_node := MultiMeshInstance3D.new()
			boards_node.name = "GateBoards_" + tone
			boards_node.multimesh = multi
			boards_node.material_override = _materials[tone]
			boards_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(boards_node)
			board_multis[tone] = boards_node
		var board_slots: Dictionary = {}
		var boards: Array = []
		for row: int in leaf_rows:
			for column: int in leaf_columns:
				var tone: String = "wood_alt" if column % 3 == 1 else "wood"
				var slot: int = int(board_slots.get(tone, 0))
				board_slots[tone] = slot + 1
				var board_at := Vector3(
					-side * (board_w * (float(column) + 0.5)),
					board_h * (float(row) + 0.5) + GATE_HEIGHT * 0.02,
					0.0)
				(board_multis[tone] as MultiMeshInstance3D).multimesh.set_instance_transform(
					slot, Transform3D(Basis.IDENTITY, board_at))
				boards.append({"at": board_at, "broken": false, "size": board_box.size,
					"multi": board_multis[tone], "slot": slot})
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
			seam.position = Vector3(-side * (board * float(i)), GATE_HEIGHT * 0.5, 0.335)
			pivot.add_child(seam)
		for band: int in 3:
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(leaf_width * 0.98, 0.30, 0.14)
			strip.mesh = strip_mesh
			strip.material_override = _materials["iron"]
			strip.position = Vector3(-side * leaf_width * 0.5, GATE_HEIGHT * (0.18 + float(band) * 0.3), 0.39)
			pivot.add_child(strip)
			for stud: int in 5:
				var bolt := MeshInstance3D.new()
				var bolt_mesh := BoxMesh.new()
				bolt_mesh.size = Vector3(0.11, 0.11, 0.18)
				bolt.mesh = bolt_mesh
				bolt.material_override = _materials["iron"]
				bolt.position = Vector3(-side * leaf_width * (0.1 + float(stud) * 0.2),
					GATE_HEIGHT * (0.18 + float(band) * 0.3), 0.46)
				pivot.add_child(bolt)
		# A square forged frame has identical dimensions on both leaves. The old
		# diagonals were offset and made the ironwork appear crooked.
		for edge: float in [0.18, leaf_width - 0.18]:
			var stile := MeshInstance3D.new()
			var stile_box := BoxMesh.new()
			stile_box.size = Vector3(0.16, GATE_HEIGHT * 0.94, 0.16)
			stile.mesh = stile_box
			stile.material_override = _materials["iron"]
			stile.position = Vector3(-side * edge, GATE_HEIGHT * 0.5, 0.39)
			pivot.add_child(stile)
		for edge_y: float in [0.54, GATE_HEIGHT - 0.54]:
			var rail := MeshInstance3D.new()
			var rail_box := BoxMesh.new()
			rail_box.size = Vector3(leaf_width * 0.98, 0.16, 0.16)
			rail.mesh = rail_box
			rail.material_override = _materials["iron"]
			rail.position = Vector3(-side * leaf_width * 0.5, edge_y, 0.39)
			pivot.add_child(rail)
		for hinge_index: int in 3:
			var hinge := MeshInstance3D.new()
			var hinge_box := BoxMesh.new()
			hinge_box.size = Vector3(1.1, 0.34, 0.36)
			hinge.mesh = hinge_box
			hinge.material_override = _materials["iron"]
			hinge.position = Vector3(-side * 0.55,
				GATE_HEIGHT * (0.18 + float(hinge_index) * 0.3), 0.43)
			pivot.add_child(hinge)
		var plate := MeshInstance3D.new()
		var plate_box := BoxMesh.new()
		plate_box.size = Vector3(0.56, 0.82, 0.12)
		plate.mesh = plate_box
		plate.material_override = _materials["iron"]
		plate.position = Vector3(-side * (leaf_width - 0.55), 4.95, 0.47)
		pivot.add_child(plate)
		var pull := MeshInstance3D.new()
		var pull_mesh := TorusMesh.new()
		pull_mesh.inner_radius = 0.18
		pull_mesh.outer_radius = 0.26
		pull.mesh = pull_mesh
		pull.material_override = _materials["iron"]
		pull.position = plate.position + Vector3(0.0, -0.10, 0.16)
		pull.rotation.x = PI * 0.5
		pivot.add_child(pull)
		# The collision rides with the hinge, so an open gate is really open.
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.position = Vector3.ZERO
		pivot.add_child(body)
		# One collider for each board: the hole made by a stone can be walked and shot
		# through while the sound boards continue to swing on the hinge.
		for board_entry: Dictionary in boards:
			var board_shape := CollisionShape3D.new()
			var board_shape_box := BoxShape3D.new()
			board_shape_box.size = board_entry["size"]
			board_shape.shape = board_shape_box
			board_shape.position = board_entry["at"]
			body.add_child(board_shape)
			board_entry["shape"] = board_shape
		body.set_meta("castle_gate", true)
		body.set_meta("surface", "wood")
		_merge_pivot_decoration(pivot)
		_gate_leaves.append({"pivot": pivot, "side": side, "body": body, "detached": false,
			"boards": boards})
		if side < 0.0: _gate_left = pivot
		else: _gate_right = pivot
	# Wall-mounted lever at eye height, on the courtyard side of the gate.
	var lever_base := at + Vector3(GATE_WIDTH * 0.5 + 3.4, 1.55, -1.1)
	var lever_plate := MeshInstance3D.new()
	lever_plate.name = "LeverWallPlate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.50, 1.85, 0.15)
	lever_plate.mesh = plate_mesh
	lever_plate.material_override = _materials["iron"]
	lever_plate.position = lever_base + Vector3(0.0, 0.0, 0.17)
	add_child(lever_plate)
	_add_lever_plate_collision("LeverWallPlateBody", lever_plate.position, plate_mesh.size)
	for marker_y: float in [-0.64, 0.64]:
		var stop := MeshInstance3D.new()
		var stop_mesh := BoxMesh.new()
		stop_mesh.size = Vector3(0.24, 0.13, 0.22)
		stop.mesh = stop_mesh
		stop.material_override = _materials["cold"]
		stop.position = lever_base + Vector3(0.0, marker_y, -0.02)
		add_child(stop)
	_lever_pivot = Node3D.new()
	_lever_pivot.name = "LeverArm"
	_lever_pivot.position = lever_base
	add_child(_lever_pivot)
	var axle := MeshInstance3D.new()
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = 0.16
	axle_mesh.bottom_radius = 0.16
	axle_mesh.height = 0.32
	axle.mesh = axle_mesh
	axle.rotation.x = PI * 0.5
	axle.position.z = -0.18
	axle.material_override = _materials["cold"]
	_lever_pivot.add_child(axle)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.065
	handle_mesh.bottom_radius = 0.10
	handle_mesh.height = 0.68
	handle.mesh = handle_mesh
	handle.material_override = _materials["wood"]
	handle.position = Vector3(0.0, 0.34, -0.27)
	_lever_pivot.add_child(handle)
	var grip := MeshInstance3D.new()
	var grip_mesh := SphereMesh.new()
	grip_mesh.radius = 0.18
	grip_mesh.height = 0.36
	grip.mesh = grip_mesh
	grip.material_override = _materials["iron"]
	grip.position = Vector3(0.0, 0.68, -0.27)
	_lever_pivot.add_child(grip)
	_add_lever_handle_collision(_lever_pivot, "LeverHandleBody", -0.27, 0.68, 0.18)
	_lever_pivot.rotation.z = PI # handle points down while gates are closed
	_lever_pos = lever_base
	# A lamp over the lever: a mechanism nobody can find is a mechanism nobody uses.
	var lever_lamp := OmniLight3D.new()
	lever_lamp.light_color = Color(1.0, 0.78, 0.45)
	lever_lamp.light_energy = 2.2
	lever_lamp.omni_range = 6.0
	lever_lamp.position = lever_base + Vector3.UP * 2.1
	add_child(lever_lamp)
	_build_outer_gate_lever()

## The exterior control sits on a fixed pier, clear of both moving leaves.
## It uses the same gate state as the courtyard lever and needs no extra light.
func _build_outer_gate_lever() -> void:
	_outer_lever_pos = Vector3(GATE_WIDTH * 0.5 + 3.0, 1.55, WALL_HALF + 1.25)
	var plate := MeshInstance3D.new()
	plate.name = "OuterLeverWallPlate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.58, 1.85, 0.16)
	plate.mesh = plate_mesh
	plate.material_override = _materials["iron"]
	plate.position = _outer_lever_pos - Vector3(0.0, 0.0, 0.18)
	add_child(plate)
	_add_lever_plate_collision("OuterLeverWallPlateBody", plate.position, plate_mesh.size)
	for marker_y: float in [-0.64, 0.64]:
		var stop := MeshInstance3D.new()
		var stop_mesh := BoxMesh.new()
		stop_mesh.size = Vector3(0.28, 0.13, 0.22)
		stop.mesh = stop_mesh
		stop.material_override = _materials["cold"]
		stop.position = _outer_lever_pos + Vector3(0.0, marker_y, 0.06)
		add_child(stop)
	_outer_lever_pivot = Node3D.new()
	_outer_lever_pivot.name = "OuterLeverArm"
	_outer_lever_pivot.position = _outer_lever_pos
	add_child(_outer_lever_pivot)
	var axle := MeshInstance3D.new()
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = 0.19
	axle_mesh.bottom_radius = 0.19
	axle_mesh.height = 0.36
	axle.mesh = axle_mesh
	axle.rotation.x = PI * 0.5
	axle.position.z = 0.18
	axle.material_override = _materials["cold"]
	_outer_lever_pivot.add_child(axle)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.085
	handle_mesh.bottom_radius = 0.12
	handle_mesh.height = 0.85
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.42, 0.31)
	handle.material_override = _materials["wood"]
	_outer_lever_pivot.add_child(handle)
	var grip := MeshInstance3D.new()
	var grip_mesh := SphereMesh.new()
	grip_mesh.radius = 0.21
	grip_mesh.height = 0.42
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, 0.86, 0.31)
	grip.material_override = _materials["iron"]
	_outer_lever_pivot.add_child(grip)
	_add_lever_handle_collision(_outer_lever_pivot, "OuterLeverHandleBody", 0.31, 0.86, 0.21)
	_outer_lever_pivot.rotation.z = PI

func _add_lever_plate_collision(label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _add_lever_handle_collision(pivot: Node3D, label: String, z: float, length: float, radius: float) -> void:
	var body := AnimatableBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 1
	pivot.add_child(body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = length + radius * 2.0
	shape.shape = capsule
	shape.position = Vector3(0.0, length * 0.5, z)
	body.add_child(shape)

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
var _outer_lever_pivot: Node3D
var _outer_lever_pos := Vector3.ZERO
var _gate_open_state := false
var _gate_angle := 0.0
var _lever_angle := PI

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

func _gate_board_colliders_active() -> int:
	var count := 0
	for entry: Dictionary in _gate_leaves:
		for board: Dictionary in entry.get("boards", []):
			var shape: CollisionShape3D = board.get("shape")
			if is_instance_valid(shape) and not shape.disabled: count += 1
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
	return to_global(_lever_pos)

func outer_lever_position() -> Vector3:
	return to_global(_outer_lever_pos)

## True when E would work the lever from where the player is standing.
func wants_e() -> bool:
	if not _ready or not is_instance_valid(_player): return false
	return _player.global_position.distance_to(lever_position()) <= 2.6 \
		or _player.global_position.distance_to(outer_lever_position()) <= 2.6

## E at the lever works the gate. The gate is the player's own business, so it answers the
## key itself rather than going through the weapons.
func _unhandled_input(event: InputEvent) -> void:
	if not _ready or not is_instance_valid(_player): return
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_E: return
	if not bool(_player.get("_free_mouse_look")): return
	if is_instance_valid(armory_storage) and armory_storage.interact():
		get_viewport().set_input_as_handled()
		return
	if not wants_e(): return
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
		_lever_angle = lerpf(PI, 0.0, eased)
		_lever_pivot.rotation.z = _lever_angle
	if is_instance_valid(_outer_lever_pivot):
		_outer_lever_pivot.rotation.z = _lever_angle

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
	var deck_axis: Vector3 = (deck_point_b - deck_point_a).normalized()
	var deck_up: Vector3 = lateral.cross(deck_axis).normalized()
	var deck_basis := Basis(lateral, deck_up, -deck_axis)
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
		var post_height: float = maxf(0.4, height - deck_thickness)
		# The two visible supports stay clear of the player's route.
		for flank: float in [-1.0, 1.0]:
			var at: Vector3 = bottom_centre + slope * along + lateral * (flank * width * 0.5) \
				+ Vector3.UP * (post_height * 0.5)
			var pillar := StaticBody3D.new()
			pillar.collision_layer = 1
			pillar.collision_mask = 1
			pillar.set_meta("surface", "stone")
			pillar.position = at
			add_child(pillar)
			var pillar_shape := CollisionShape3D.new()
			var pillar_box := BoxShape3D.new()
			pillar_box.size = Vector3(0.6, post_height, 0.6)
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
		var across_x: bool = absf(slope.x) < 0.5
		var step_size := Vector3(width, rise, run * 1.04) if across_x \
			else Vector3(run * 1.04, rise, width)
		_add_brick(at, step_size, "cold", Vector3.ZERO, "stairs_" + name, i, 0)
		_add_brick(at + lateral * (width * 0.5 + 0.16) + Vector3.UP * 0.55,
			Vector3(0.32, 1.0, run * 1.04) if across_x \
			else Vector3(run * 1.04, 1.0, 0.32), "stone", Vector3.ZERO, "stairs_rail_" + name, i, 0)
	# The final step overlaps a broad landing and the wall walk. It does not end
	# at a narrow seam in front of the inner parapet.
	var landing_at := top_centre + normal * 1.7 + Vector3.UP * (WALL_HEIGHT - 0.12)
	var landing_size := Vector3(width + 0.6, 0.24, 3.8) if absf(normal.z) > 0.5 \
		else Vector3(3.8, 0.24, width + 0.6)
	_add_brick(landing_at, landing_size, "warm", Vector3.ZERO, "stair_landing_" + name)
	_add_breakable_collision(landing_at, landing_size)

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
				# The south face has a real entrance into the keep.
				if not (side > 0.0 and absf(along) < 2.35 and row * BRICK.y < 4.35):
					_add_brick(base + Vector3(along, (float(row) + 0.5) * BRICK.y,
						side * KEEP_SIZE.z * 0.5),
						Vector3(BRICK.x, BRICK.y, WALL_THICK * 1.3), "stone", Vector3.ZERO, "keep", row, column)
				_add_brick(base + Vector3(side * KEEP_SIZE.x * 0.5,
					(float(row) + 0.5) * BRICK.y, along),
					Vector3(WALL_THICK * 1.3, BRICK.y, BRICK.x), "warm", Vector3.ZERO, "keep", row, column)
	# Hollow shell: no hidden solid block behind the entrance or future breaches.
	for face: float in [-1.0, 1.0]:
		_add_wall_collision(base + Vector3(face * KEEP_SIZE.x * 0.5, KEEP_SIZE.y * 0.5, 0.0),
			Vector3(WALL_THICK * 1.3, KEEP_SIZE.y, KEEP_SIZE.z))
	_add_wall_collision(base + Vector3(0.0, KEEP_SIZE.y * 0.5, -KEEP_SIZE.z * 0.5),
		Vector3(KEEP_SIZE.x, KEEP_SIZE.y, WALL_THICK * 1.3))
	for side: float in [-1.0, 1.0]:
		_add_wall_collision(base + Vector3(side * 7.65, KEEP_SIZE.y * 0.5, KEEP_SIZE.z * 0.5),
			Vector3(10.7, KEEP_SIZE.y, WALL_THICK * 1.3))
	_add_wall_collision(base + Vector3(0.0, (KEEP_SIZE.y + 4.35) * 0.5, KEEP_SIZE.z * 0.5),
		Vector3(4.6, KEEP_SIZE.y - 4.35, WALL_THICK * 1.3))

func _build_keep_rooms() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	# Ground tiles and roof courses use the same destructible MultiMesh as the walls.
	for x: int in 13:
		for z: int in 13:
			var offset := Vector3(-12.0 + float(x) * 2.0, 0.0, -12.0 + float(z) * 2.0)
			var floor_at := base + offset + Vector3.UP * 0.12
			var floor_size := Vector3(1.995, 0.24, 1.995)
			_add_brick(floor_at, floor_size,
				"warm" if (x + z) % 3 == 0 else "stone", Vector3.ZERO, "keep_floor", x, z)
			_add_breakable_collision(floor_at, Vector3(1.995, 0.32, 1.995))
			(_wall_collision.back()["body"] as StaticBody3D).set_meta("castle_keep_floor", true)
			_add_brick(base + offset + Vector3.UP * (KEEP_SIZE.y + 0.12), Vector3(2.01, 0.24, 2.01),
				"cold", Vector3.ZERO, "keep_roof", x, z)
	# Stagger the end joints from one plank to the next. Cut half boards finish
	# alternate rows at the walls, and all planks use the existing wood batch.
	for column: int in 26:
		var board_x := -12.5 + float(column)
		if column % 2 == 0:
			for segment: int in 13:
				_add_brick(base + Vector3(board_x, 0.25, -12.0 + float(segment) * 2.0),
					Vector3(0.975, 0.055, 1.965), "floor_wood", Vector3.ZERO,
					"keep_floor_board", column, segment)
		else:
			for segment: int in 14:
				var half_board: bool = segment == 0 or segment == 13
				var board_z := -12.5 if segment == 0 else 12.5 if segment == 13 \
					else -11.0 + float(segment - 1) * 2.0
				_add_brick(base + Vector3(board_x, 0.25, board_z),
					Vector3(0.975, 0.055, 0.965 if half_board else 1.965),
					"floor_wood", Vector3.ZERO, "keep_floor_board", column, segment)
	# Four ground-floor rooms open onto a broad central passage. Each opening is
	# wider than the player capsule; partitions are struck and removed in sections.
	for side: float in [-1.0, 1.0]:
		for z_index: int in 10:
			var along := -11.0 + float(z_index) * 2.35
			if absf(along - 5.95) < 1.3 or absf(along + 5.95) < 1.3: continue
			var partition_at := base + Vector3(side * 3.4, 2.45, along)
			for row: int in 9:
				_add_brick(partition_at + Vector3(0.0, -2.16 + float(row) * BRICK.y, 0.0),
					Vector3(0.38, BRICK.y, 2.34), "warm", Vector3.ZERO, "keep_partition", row, z_index)
			_add_breakable_collision(partition_at, Vector3(0.38, 4.9, 2.34))
		for x_index: int in 4:
			var x_pos := 4.7 + float(x_index) * 2.3
			var cross_at := base + Vector3(side * x_pos, 2.45, 0.0)
			for row: int in 9:
				_add_brick(cross_at + Vector3(0.0, -2.16 + float(row) * BRICK.y, 0.0),
					Vector3(2.29, BRICK.y, 0.38), "stone", Vector3.ZERO, "keep_partition", row, x_index)
			_add_breakable_collision(cross_at, Vector3(2.29, 4.9, 0.38))
	# Stone framing leaves a level, unobstructed passage into the keep.
	for side: float in [-1.0, 1.0]:
		for row: int in 9:
			_add_brick(base + Vector3(side * 2.5, (float(row) + 0.5) * BRICK.y, 13.18),
				Vector3(0.65, BRICK.y, 0.9), "cold", Vector3.ZERO, "keep_door_jamb", row, 0)
	_add_brick(base + Vector3(0.0, 4.55, 13.18), Vector3(5.6, 0.5, 0.9),
		"cold", Vector3.ZERO, "keep_door_head")
	# A red runner guides the eye from the entrance through the central passage.
	# Small independent sections keep a local explosion from deleting the whole rug.
	for section: int in 12:
		var z_at := -10.9 + float(section) * 2.0
		var runner := base + Vector3(0.0, 0.295, z_at)
		_add_brick(runner, Vector3(2.15, 0.025, 1.98), "velvet",
			Vector3.ZERO, "keep_runner", section, 0)
		for side: float in [-1.0, 1.0]:
			_add_brick(runner + Vector3(side * 1.1, 0.008, 0.0),
				Vector3(0.075, 0.014, 1.98), "gold", Vector3.ZERO,
				"keep_runner_edge", section, int(side))
	for light_z: float in [-7.0, 6.0]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.42)
		lamp.light_energy = 1.1
		lamp.omni_range = 9.0
		lamp.shadow_enabled = false
		lamp.position = base + Vector3(0.0, 3.7, light_z)
		add_child(lamp)

## Interior pieces share the masonry MultiMesh and the capped, pooled debris physics.
## Broad surfaces alone need standing collision; trim stays visually breakable.
func _furnish(at: Vector3, size: Vector3, material_key: String, group: String,
		solid: bool = false, shape_key: String = "box") -> void:
	_add_brick(at, size, material_key, Vector3.ZERO, group, 0, 0, shape_key)
	if not _furniture_cells.has(group): _furniture_cells[group] = []
	(_furniture_cells[group] as Array).append(_cells.size() - 1)
	if solid:
		_add_breakable_collision(at, size)
		if material_key in ["stone", "warm", "cold", "iron"]: return
		var section: Dictionary = _wall_collision.back()
		var body: StaticBody3D = section["body"]
		body.set_meta("castle_furnishing", true)
		body.set_meta("castle_furnishing_group", group)
		body.set_meta("castle_furnishing_material", material_key)
		body.set_meta("castle_melee_hp", 2.0 if material_key.begins_with("wood") else 1.0)
		section["group"] = group

func _build_keep_interior() -> void:
	var base := Vector3(0.0, 0.0, -8.0)
	# One unshadowed warm light per room: enough to read colour through thick partitions.
	# No dynamic shadows, reflection probes, or per-object lights.
	for centre: Vector2 in [Vector2(-8.0, -6.3), Vector2(8.0, -6.3),
			Vector2(-8.0, 6.3), Vector2(8.0, 6.3)]:
		# The keep is tall outside, but the ground-floor chambers need a ceiling.
		# Four solid vault panels per chamber retain local destruction and support.
		for panel: int in 4:
			var ceiling_z := centre.y - 3.75 + float(panel) * 2.5
			_furnish(base + Vector3(centre.x, 5.12, ceiling_z),
				Vector3(8.7, 0.22, 2.48), "cold", "room_vault", true)
		for beam_z: float in [-3.75, -1.25, 1.25, 3.75]:
			_furnish(base + Vector3(centre.x, 4.92, centre.y + beam_z),
				Vector3(8.8, 0.28, 0.26), "wood_alt", "room_ceiling_beam")
		for side_z: float in [-2.9, 2.9]:
			var wall_x: float = centre.x + (-3.85 if centre.x < 0.0 else 3.85)
			_furnish(base + Vector3(wall_x, 2.5, centre.y + side_z),
				Vector3(0.44, 4.8, 0.48), "warm", "room_wall_pier")
			_furnish(base + Vector3(wall_x, 4.76, centre.y + side_z),
				Vector3(0.72, 0.32, 0.76), "cold", "room_pier_cap")
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.70, 0.39)
		light.light_energy = 1.55
		light.omni_range = 7.5
		light.shadow_enabled = false
		light.position = base + Vector3(centre.x, 3.7, centre.y)
		add_child(light)
		var sconce := base + Vector3(centre.x, 3.5, centre.y)
		_furnish(sconce, Vector3(0.45, 0.13, 0.45), "gold", "room_lantern")
		_furnish(sconce + Vector3.UP * 0.18, Vector3(0.24, 0.25, 0.24), "linen", "room_lantern")
		_furnish(base + Vector3(centre.x, 0.295, centre.y),
			Vector3(5.8, 0.025, 7.0), "velvet", "room_rug")
		var face: float = -1.0 if centre.x < 0.0 else 1.0
		var banner := base + Vector3(face * 12.58, 2.8, centre.y)
		_furnish(banner, Vector3(0.08, 2.8, 2.0), "velvet", "room_banner")
		_furnish(banner + Vector3(-face * 0.06, 0.45, 0.0),
			Vector3(0.09, 0.48, 0.85), "gold", "room_banner_device")
		_furnish(banner + Vector3(-face * 0.06, -0.8, 0.0),
			Vector3(0.09, 0.07, 2.0), "gold", "room_banner_trim")
	# West/north: feasting table, benches, high-backed seat, wall chests.
	var hall := base + Vector3(-8.1, 0.0, -6.3)
	_furnish(hall + Vector3(0, 1.05, 0), Vector3(2.5, 0.18, 4.0), "wood", "hall_table", true)
	for x_offset: float in [-0.78, 0.0, 0.78]:
		_furnish(hall + Vector3(x_offset, 1.155, 0.0), Vector3(0.72, 0.035, 3.92),
			"wood_alt", "hall_table_slats")
	for side: float in [-1.0, 1.0]:
		_furnish(hall + Vector3(side * 1.19, 0.98, 0.0), Vector3(0.09, 0.16, 3.8),
			"wood_alt", "hall_table_edge")
	_furnish(hall + Vector3(0, 0.48, 0), Vector3(1.85, 0.12, 0.14),
		"wood_alt", "hall_table_brace")
	for sx: float in [-1.0, 1.0]:
		_furnish(hall + Vector3(sx * 0.95, 0.52, -1.35), Vector3(0.24, 1.04, 0.24),
			"wood_alt", "hall_table_leg", false, "turned")
		_furnish(hall + Vector3(sx * 0.95, 0.52, 1.35), Vector3(0.24, 1.04, 0.24),
			"wood_alt", "hall_table_leg", false, "turned")
		_furnish(hall + Vector3(sx * 2.05, 0.55, 0), Vector3(0.55, 0.16, 3.8), "wood", "hall_bench", true)
		_furnish(hall + Vector3(sx * 2.05, 0.27, -1.3), Vector3(0.2, 0.54, 0.2),
			"wood_alt", "hall_bench_leg", false, "turned")
		_furnish(hall + Vector3(sx * 2.05, 0.27, 1.3), Vector3(0.2, 0.54, 0.2),
			"wood_alt", "hall_bench_leg", false, "turned")
	_furnish(hall + Vector3(0, 0.58, -3.2), Vector3(1.3, 0.16, 1.02),
		"wood_alt", "hall_chair", true)
	_furnish(hall + Vector3(0, 0.69, -3.2), Vector3(1.1, 0.11, 0.82),
		"velvet", "hall_chair_cushion", false, "soft")
	for sx: float in [-1.0, 1.0]:
		for dz: float in [-0.38, 0.38]:
			_furnish(hall + Vector3(sx * 0.5, 0.26, -3.2 + dz), Vector3(0.18, 0.52, 0.18),
				"wood_alt", "hall_chair_leg", false, "turned")
		_furnish(hall + Vector3(sx * 0.52, 1.08, -3.65), Vector3(0.16, 1.25, 0.16),
			"wood_alt", "hall_chair_back", false, "turned")
	_furnish(hall + Vector3(0, 1.55, -3.65), Vector3(1.28, 0.22, 0.18),
		"wood", "hall_chair_back")
	for dz: float in [-3.8, 3.8]:
		_furnish(hall + Vector3(-3.0, 0.55, dz), Vector3(1.4, 1.1, 0.8), "wood_alt", "hall_chest", true)
		_furnish(hall + Vector3(-3.0, 1.13, dz), Vector3(1.45, 0.2, 0.84),
			"wood", "hall_chest_lid", false, "soft")
		_furnish(hall + Vector3(-2.25, 0.7, dz), Vector3(0.08, 0.44, 0.2),
			"iron", "hall_chest_band")
	for dz: float in [-1.2, 0.0, 1.2]:
		_furnish(hall + Vector3(0, 1.21, dz), Vector3(0.72, 0.04, 0.72),
			"gold", "hall_plate", false, "disk")
		_furnish(hall + Vector3(0.55, 1.38, dz), Vector3(0.18, 0.3, 0.18),
			"gold", "hall_goblet", false, "cup")

	# East/north: racks, shield silhouettes, and a compact work bench.
	var armoury := base + Vector3(8.0, 0.0, -6.2)
	for dz: float in [-3.3, 0.0, 3.3]:
		_furnish(armoury + Vector3(2.65, 1.3, dz), Vector3(0.22, 2.6, 2.1), "wood_alt", "armour_rack", true)
		for side: float in [-1.0, 1.0]:
			_furnish(armoury + Vector3(2.46, 1.3, dz + side * 0.95),
				Vector3(0.2, 2.6, 0.2), "wood", "armour_rack_post", false, "turned")
		for height: float in [0.55, 1.35, 2.15]:
			_furnish(armoury + Vector3(2.42, height, dz), Vector3(0.18, 0.16, 1.94),
				"wood", "armour_rack_rail")
		_furnish(armoury + Vector3(2.39, 2.38, dz), Vector3(0.12, 0.28, 0.5),
			"gold", "armour_crest")
	# A paired iron cradle carries each real weapon at its lower end and keeps
	# the shaft against the upper rail. The display mesh no longer hangs in air.
	for slot_z: float in [-3.85, -2.95, -0.45, 0.45, 2.95, 3.85]:
		_furnish(armoury + Vector3(2.52, 1.37, slot_z),
			Vector3(0.035, 1.72, 0.66), "linen", "armour_backer")
		for height: float in [0.66, 1.45]:
			_furnish(armoury + Vector3(2.23, height, slot_z),
				Vector3(0.42, 0.08, 0.17), "iron", "armour_hook")
			_furnish(armoury + Vector3(2.03, height + 0.085, slot_z),
				Vector3(0.08, 0.17, 0.17), "iron", "armour_hook")
	# A separate shield mount on the wall uses the same unique take/drop path.
	_furnish(armoury + Vector3(2.62, 1.58, 5.2), Vector3(0.18, 1.45, 1.05),
		"wood", "armour_shield_mount", true)
	for side: float in [-1.0, 1.0]:
		_furnish(armoury + Vector3(2.48, 1.58, 5.2 + side * 0.43),
			Vector3(0.08, 1.38, 0.07), "iron", "armour_shield_trim")
	_furnish(armoury + Vector3(2.37, 1.39, 5.2), Vector3(0.32, 0.10, 0.24),
		"iron", "armour_shield_hook")
	_furnish(armoury + Vector3(-1.2, 0.83, 0), Vector3(1.7, 0.18, 2.6), "wood", "armour_bench", true)
	for x_offset: float in [-0.5, 0.5]:
		_furnish(armoury + Vector3(-1.2 + x_offset, 0.94, 0), Vector3(0.68, 0.035, 2.5),
			"wood_alt", "armour_bench_slats")
	for dz: float in [-0.9, 0.9]:
		_furnish(armoury + Vector3(-1.7, 0.41, dz), Vector3(0.22, 0.82, 0.22),
			"wood_alt", "armour_leg", false, "turned")
	# Separate floor chest, away from the display racks. Its lid and iron fittings
	# share the furniture destruction path; only this carcass owns storage access.
	var chest_at := armoury + Vector3(-2.6, 0.0, -3.4)
	_furnish(chest_at + Vector3(0, 0.61, 0), Vector3(1.78, 0.92, 1.16),
		"wood_alt", "armour_chest", true)
	for side: float in [-1.0, 1.0]:
		_furnish(chest_at + Vector3(side * 0.75, 0.61, 0.60),
			Vector3(0.10, 0.86, 0.08), "wood", "armour_chest_frame")
		_furnish(chest_at + Vector3(side * 0.72, 0.18, 0),
			Vector3(0.16, 0.28, 0.16), "iron", "armour_chest_foot", false, "turned")
	for side: float in [-1.0, 1.0]:
		_furnish(chest_at + Vector3(side * 0.51, 0.66, 0.60),
			Vector3(0.62, 0.56, 0.07), "wood", "armour_chest_panel")
		_furnish(chest_at + Vector3(side * 0.47, 0.66, 0.65),
			Vector3(0.04, 0.42, 0.03), "gold", "armour_chest_inlay")
	for plank: int in 4:
		_furnish(chest_at + Vector3(-0.66 + plank * 0.44, 1.12, 0),
			Vector3(0.43, 0.15, 1.28), "wood", "armour_chest_lid")
	for band_x: float in [-0.64, 0.64]:
		_furnish(chest_at + Vector3(band_x, 1.22, 0),
			Vector3(0.08, 0.04, 1.34), "iron", "armour_chest_band")
	_furnish(chest_at + Vector3(0, 0.69, 0.67), Vector3(0.24, 0.32, 0.08),
		"iron", "armour_chest_lock")

	# West/south: three tall shelves with individually breakable ledgers.
	var archive := base + Vector3(-8.0, 0.0, 6.4)
	for dz: float in [-3.3, 0.0, 3.3]:
		_furnish(archive + Vector3(-2.9, 1.6, dz), Vector3(0.38, 3.2, 2.5),
			"wood_alt", "archive_shelf", true)
		for side: float in [-1.0, 1.0]:
			_furnish(archive + Vector3(-2.42, 1.6, dz + side * 1.15),
				Vector3(0.22, 3.2, 0.22), "wood", "archive_shelf_post", false, "turned")
		_furnish(archive + Vector3(-2.55, 3.17, dz), Vector3(0.85, 0.2, 2.65),
			"wood", "archive_shelf_crown")
		for level: int in 3:
			for volume: int in 4:
				_furnish(archive + Vector3(-2.27, 0.55 + level * 0.92, dz - 0.76 + volume * 0.5),
					Vector3(0.16, 0.67, 0.44), "velvet" if volume % 2 == 0 else "linen", "archive_books")
			_furnish(archive + Vector3(-2.2, 0.2 + level * 0.92, dz), Vector3(0.72, 0.1, 2.5), "wood", "archive_shelf_trim")
	_furnish(archive + Vector3(0.4, 0.75, 0), Vector3(1.5, 0.16, 2.2), "wood", "archive_desk", true)
	for x_offset: float in [-0.43, 0.43]:
		_furnish(archive + Vector3(0.4 + x_offset, 0.85, 0), Vector3(0.62, 0.025, 2.12),
			"wood_alt", "archive_desk_slats")
		for dz: float in [-0.8, 0.8]:
			_furnish(archive + Vector3(0.4 + x_offset, 0.37, dz), Vector3(0.18, 0.74, 0.18),
				"wood_alt", "archive_desk_leg", false, "turned")
	_furnish(archive + Vector3(0.4, 0.84, 0), Vector3(1.1, 0.04, 1.65), "linen", "archive_map")

	# East/south: bed, canopy, wardrobes, and paired chests.
	var chamber := base + Vector3(8.0, 0.0, 6.3)
	_furnish(chamber + Vector3(0, 0.47, 0), Vector3(2.5, 0.75, 3.3), "wood_alt", "chamber_bed", true)
	for side: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(side * 1.18, 0.52, 0.0), Vector3(0.18, 0.58, 3.2),
			"wood", "chamber_bed_rail")
	_furnish(chamber + Vector3(0, 0.91, 0), Vector3(2.25, 0.22, 2.95),
		"linen", "chamber_mattress", false, "soft")
	_furnish(chamber + Vector3(0, 1.03, 0.82), Vector3(2.16, 0.045, 1.16),
		"velvet", "chamber_cover")
	for side: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(side * 0.52, 1.1, -1.0), Vector3(0.82, 0.17, 0.52),
			"linen", "chamber_pillow", false, "soft")
	_furnish(chamber + Vector3(0, 1.68, -1.73), Vector3(2.7, 0.24, 0.22),
		"wood", "chamber_headboard", true)
	for x_offset: float in [-1.08, -0.36, 0.36, 1.08]:
		_furnish(chamber + Vector3(x_offset, 1.05, -1.73), Vector3(0.2, 1.15, 0.2),
			"wood_alt", "chamber_headboard", true, "turned")
	_furnish(chamber + Vector3(0, 1.84, -1.57), Vector3(0.48, 0.4, 0.14),
		"gold", "chamber_headboard_crest", false, "soft")
	for side: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(side * 1.18, 1.75, -1.7), Vector3(0.18, 0.45, 0.18),
			"gold", "chamber_headboard_finial", false, "turned")
	for sx: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(sx * 1.25, 2.15, 0), Vector3(0.2, 4.3, 0.2),
			"wood", "chamber_post", false, "turned")
	_furnish(chamber + Vector3(0, 4.2, 0), Vector3(2.65, 0.12, 3.3), "linen", "chamber_canopy")
	_furnish(chamber + Vector3(0, 4.13, 0), Vector3(2.5, 0.03, 3.12), "velvet", "chamber_canopy_lining")
	for side: float in [-1.0, 1.0]:
		_furnish(chamber + Vector3(side * 1.28, 3.9, 0.0), Vector3(0.08, 0.34, 3.25),
			"velvet", "chamber_canopy_valance")
	for sx: float in [-1.0, 1.0]:
		for fold: int in 2:
			_furnish(chamber + Vector3(sx * (1.08 + float(fold) * 0.13), 3.2, -1.42),
				Vector3(0.08, 1.6, 0.28), "velvet", "chamber_drape")
	for dz: float in [-3.3, 3.3]:
		_furnish(chamber + Vector3(2.9, 1.2, dz), Vector3(0.8, 2.4, 1.55), "wood_alt", "chamber_wardrobe", true)
		_furnish(chamber + Vector3(2.48, 2.42, dz), Vector3(0.92, 0.22, 1.7),
			"wood", "chamber_wardrobe_crown")
		for side: float in [-1.0, 1.0]:
			_furnish(chamber + Vector3(2.45, 1.2, dz + side * 0.39),
				Vector3(0.08, 1.95, 0.67), "wood", "chamber_wardrobe_panel")
			_furnish(chamber + Vector3(2.37, 1.2, dz + side * 0.12),
				Vector3(0.09, 0.17, 0.09), "gold", "chamber_handle", false, "cup")

## ------------------------------------------------------------------ colour and banners
## Banners hanging on the walls, in the colour of the house, with a gold device: a
const WALK_WIDTH := 3.0
const WALK_PARAPET := 0.9

## THE WALL-WALK: a continuous platform round all four walls at the wall head, wide enough
## for two men to pass, with a waist-high parapet on the courtyard side. Without it the
## battlements are decoration nobody can stand on.
func _build_wall_walks() -> void:
	# Short spans are visible through the masonry MultiMesh and have matching
	# breakable support. A hit at parapet height can destroy one span without
	# leaving an invisible 136-metre slab across the courtyard.
	var spans := 28
	var length := WALL_HALF * 2.0 / float(spans)
	for side: String in ["north", "south", "east", "west"]:
		var along_x := side == "north" or side == "south"
		var sign: float = 1.0 if side in ["south", "east"] else -1.0
		for span: int in spans:
			var along := -WALL_HALF + (float(span) + 0.5) * length
			var centre := Vector3(along, WALL_HEIGHT - 0.1, sign * (WALL_HALF - 0.55)) if along_x \
				else Vector3(sign * (WALL_HALF - 0.55), WALL_HEIGHT - 0.1, along)
			var deck_size := Vector3(length, 0.24, WALK_WIDTH) if along_x \
				else Vector3(WALK_WIDTH, 0.24, length)
			_add_brick(centre, deck_size, "warm", Vector3.ZERO, side + "_walk", 0, span)
			_add_breakable_collision(centre, deck_size)
			var inner := centre + (Vector3(0.0, 0.0, -sign) if along_x \
				else Vector3(-sign, 0.0, 0.0)) * (WALK_WIDTH * 0.5 - 0.2)
			var rail_at := inner + Vector3.UP * (WALK_PARAPET * 0.5 + 0.12)
			var rail_size := Vector3(length, WALK_PARAPET, 0.35) if along_x \
				else Vector3(0.35, WALK_PARAPET, length)
			# Open the stair landing and both corner connectors through this inner rail.
			var landing: float = WALL_HALF * 0.42 * (1.0 if side in ["north", "east"] else -1.0)
			var segment_min: float = along - length * 0.5
			var segment_max: float = along + length * 0.5
			var intervals: Array[Vector2] = [Vector2(segment_min, segment_max)]
			var corner_lane := WALL_HALF - TOWER_RADIUS - 2.4
			var gap_centres: Array[float] = [landing, -corner_lane, corner_lane]
			if side == "south":
				gap_centres.append_array([-14.0, 14.0])
			for gap_centre: float in gap_centres:
				var gap_min := gap_centre - 1.8
				var gap_max := gap_centre + 1.8
				var remaining: Array[Vector2] = []
				for interval: Vector2 in intervals:
					if interval.y <= gap_min or interval.x >= gap_max:
						remaining.append(interval)
					else:
						if interval.x < gap_min: remaining.append(Vector2(interval.x, gap_min))
						if interval.y > gap_max: remaining.append(Vector2(gap_max, interval.y))
				intervals = remaining
			for interval: Vector2 in intervals:
				if interval.y - interval.x < 0.05: continue
				var piece_at := rail_at
				var piece_size := rail_size
				if along_x:
					piece_at.x = (interval.x + interval.y) * 0.5
					piece_size.x = interval.y - interval.x
				else:
					piece_at.z = (interval.x + interval.y) * 0.5
					piece_size.z = interval.y - interval.x
				_add_brick(piece_at, piece_size, "cold", Vector3.ZERO, side + "_parapet", 0, span)
				_add_breakable_collision(piece_at, piece_size)

func _build_corner_bypasses() -> void:
	# An L-shaped passage inside each tower joins neighbouring wall walks. The
	# tower remains solid until struck, while archers can circulate around it.
	var lane := WALL_HALF - TOWER_RADIUS - 2.4
	var link := (WALL_HALF - 0.55) - lane
	var centre_along := (WALL_HALF - 0.55 + lane) * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var first := Vector3(sx * lane, WALL_HEIGHT - 0.1, sz * centre_along)
			var second := Vector3(sx * centre_along, WALL_HEIGHT - 0.1, sz * lane)
			var first_size := Vector3(WALK_WIDTH, 0.24, link + WALK_WIDTH)
			var second_size := Vector3(link + WALK_WIDTH, 0.24, WALK_WIDTH)
			for item: Dictionary in [
				{"at": first, "size": first_size}, {"at": second, "size": second_size}]:
				_add_brick(item["at"], item["size"], "warm", Vector3.ZERO, "corner_walk")
				_add_breakable_collision(item["at"], item["size"])
			# Four short rails protect the inside edge without covering the turn.
			var rail_y := WALL_HEIGHT + WALK_PARAPET * 0.5 + 0.02
			var rail_link := link - 1.8
			var rail_centre := lane + rail_link * 0.5
			var first_rail := Vector3(sx * (lane - WALK_WIDTH * 0.5), rail_y, sz * rail_centre)
			var second_rail := Vector3(sx * rail_centre, rail_y, sz * (lane - WALK_WIDTH * 0.5))
			var first_rail_size := Vector3(0.28, WALK_PARAPET, rail_link)
			var second_rail_size := Vector3(rail_link, WALK_PARAPET, 0.28)
			for item: Dictionary in [
				{"at": first_rail, "size": first_rail_size},
				{"at": second_rail, "size": second_rail_size}]:
				_add_brick(item["at"], item["size"], "cold", Vector3.ZERO, "corner_parapet")
				_add_breakable_collision(item["at"], item["size"])
			# A visible pier under the bend supports both short spans.
			var pier_height := WALL_HEIGHT - 0.24
			var pier_at := Vector3(sx * lane, pier_height * 0.5, sz * lane)
			_add_brick(pier_at, Vector3(0.9, pier_height, 0.9), "stone", Vector3.ZERO,
				"corner_pier")
			_add_breakable_collision(pier_at, Vector3(0.9, pier_height, 0.9))

func _build_gatehouse_bypass() -> void:
	# The gatehouse turrets reach above the main walk. Pass them on the
	# courtyard side while preserving the gate arch and outer silhouette.
	var deck_y := WALL_HEIGHT - 0.1
	var inner_z := WALL_HALF - 5.0
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			var branch_at := Vector3(side * 14.0, deck_y, 63.5 + float(i) * 1.725)
			var branch_size := Vector3(WALK_WIDTH, 0.24, 2.45)
			_add_brick(branch_at, branch_size, "warm", Vector3.ZERO, "gate_bypass", 0, i)
			_add_breakable_collision(branch_at, branch_size)
	# Twelve short spans keep a blast local instead of erasing the entire bridge.
	for i: int in 12:
		var bridge_at := Vector3(-13.75 + float(i) * 2.5, deck_y, inner_z)
		var bridge_size := Vector3(2.55, 0.24, WALK_WIDTH)
		_add_brick(bridge_at, bridge_size, "warm", Vector3.ZERO, "gate_bypass", 1, i)
		_add_breakable_collision(bridge_at, bridge_size)
	# Stone piers carry the long cross span. The central gate approach stays open.
	for side: float in [-1.0, 1.0]:
		var pier_height := WALL_HEIGHT - 0.24
		var pier_at := Vector3(side * 10.0, pier_height * 0.5, inner_z)
		var pier_size := Vector3(1.1, pier_height, 1.1)
		_add_brick(pier_at, pier_size, "stone", Vector3.ZERO, "gate_bypass_pier")
		_add_breakable_collision(pier_at, pier_size)

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
	var bars: Array[Transform3D] = []
	var flags: Array[Transform3D] = []
	var devices: Array[Transform3D] = []
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
				anchor = Vector3(along, WALL_HEIGHT - 0.5,
					sign_z * (WALL_HALF + WALL_THICK * 0.5 + 0.12))
				outward = Vector3(0.0, 0.0, sign_z)
			else:
				anchor = Vector3(sign_x * (WALL_HALF + WALL_THICK * 0.5 + 0.12),
					WALL_HEIGHT - 0.5, along)
				outward = Vector3(sign_x, 0.0, 0.0)
			var rotation_y: float = 0.0 if vertical else PI * 0.5
			var facing := Basis(Vector3.UP, rotation_y)
			bars.append(Transform3D(facing * Basis(Vector3.FORWARD, PI * 0.5), anchor))
			flags.append(Transform3D(facing,
				anchor + Vector3.DOWN * 2.15 - outward * 0.06))
			# The device remains on the cloth plane on east/west walls as well.
			for petal: int in 3:
				var offset_x: float = 0.0 if petal == 1 else (-0.30 if petal == 0 else 0.30)
				var size := Vector3(0.22, 1.05 if petal == 1 else 0.75, 0.05)
				devices.append(Transform3D(facing.scaled(size),
					anchor + facing * Vector3(offset_x, -1.7, 0.0) + outward * 0.02))
			devices.append(Transform3D(facing.scaled(Vector3(0.95, 0.18, 0.05)),
				anchor + Vector3.DOWN * 2.25 + outward * 0.02))
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = 0.07
	bar_mesh.bottom_radius = 0.07
	bar_mesh.height = 2.5
	_add_banner_batch("BannerBars", bar_mesh, pole, bars)
	_add_banner_batch("HangingBanners", _make_hanging_banner_mesh(), cloth, flags)
	_add_banner_batch("BannerDevices", BoxMesh.new(), gold, devices)

func _add_banner_batch(label: String, mesh: Mesh, material: Material,
		transforms: Array[Transform3D]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)

func _make_hanging_banner_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(-1.15, 2.1), Vector2(1.15, 2.1), Vector2(1.15, -2.1),
		Vector2(0.35, -2.1), Vector2(0.0, -1.52), Vector2(-0.35, -2.1),
		Vector2(-1.15, -2.1)])
	var triangles := Geometry2D.triangulate_polygon(outline)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index: int in triangles:
		var point := outline[index]
		vertices.append(Vector3(point.x, point.y, 0.0))
		normals.append(Vector3.FORWARD)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## ------------------------------------------------------------------ the floor
## The courtyard is laid in BRICKS, a shade cooler and darker than the walls, so the
## ground does not read as one poured slab. Drawn as a MultiMesh (one draw call) with a
## little variation per stone; the collision is the flat slab that was already there.
func _build_brick_floor() -> void:
	var paving := StandardMaterial3D.new()
	paving.albedo_color = Color(0.44, 0.42, 0.40)
	paving.roughness = 1.0
	var stone_mesh := BoxMesh.new()
	# Small, even mortar joints reveal the running bond without the jagged gaps
	# caused by rotating each large paving stone independently.
	stone_mesh.size = Vector3(1.855, 0.10, 0.94)
	var per_row: int = int((WALL_HALF * 2.0) / 1.88)
	var rows: int = int((WALL_HALF * 2.0) / 0.96)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = stone_mesh
	# A straight threshold course covers the scattered ends at the south keep face.
	# It lives in this same MultiMesh: no new draw call or collision island.
	multi.instance_count = per_row * rows + 14
	var slot := 0
	for row: int in rows:
		var offset: float = 0.0 if row % 2 == 0 else 0.94
		for column: int in per_row:
			var x: float = (float(column) - float(per_row - 1) * 0.5) * 1.88 + offset
			var z: float = (float(row) - float(rows - 1) * 0.5) * 0.96
			multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY, Vector3(x, 0.02, z)))
			var tone: float = 0.88 + float(abs(int(x * 131.0) ^ int(z * 977.0)) % 100) / 100.0 * 0.22
			multi.set_instance_color(slot, Color(tone, tone * 0.99, tone * 0.97))
			slot += 1
	for apron: int in 14:
		var x := (float(apron) - 6.5) * 2.0
		var scale := Vector3(1.975 / stone_mesh.size.x, 1.02, 1.30 / stone_mesh.size.z)
		multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(scale),
			Vector3(x, 0.035, 6.10)))
		var tone := 0.95 + float(apron % 4) * 0.018
		multi.set_instance_color(slot, Color(tone, tone * 0.99, tone * 0.97))
		slot += 1
	var node := MultiMeshInstance3D.new()
	node.name = "FloorBricks"
	node.multimesh = multi
	node.material_override = paving
	add_child(node)

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

## Recessed looking arcade in actual raised stone: the long curtains gain a strong
## rhythm between their existing buttresses without another light or mesh family.
## Each stone remains a breakable cell in the existing chunked MultiMesh.
func _build_facade_relief() -> void:
	for side: String in ["north", "south", "east", "west"]:
		var along_x: bool = side in ["north", "south"]
		var normal: float = 1.0 if side in ["south", "east"] else -1.0
		for bay: int in 8:
			var along := -52.5 + float(bay) * 15.0
			if side == "south" and absf(along) < 10.0: continue
			var face := normal * (WALL_HALF + 0.74)
			for flank: float in [-1.0, 1.0]:
				var foot := along + flank * 2.7
				var jamb_at := Vector3(foot, 5.5, face) if along_x else Vector3(face, 5.5, foot)
				var jamb_size := Vector3(0.48, 3.0, 0.42) if along_x \
					else Vector3(0.42, 3.0, 0.48)
				_add_brick(jamb_at, jamb_size, "cold", Vector3.ZERO, "wall_arcade", bay, 0)
				var arm_at := Vector3(along + flank * 1.37, 8.25, face) if along_x \
					else Vector3(face, 8.25, along + flank * 1.37)
				var arm_size := Vector3(0.48, 3.8, 0.42) if along_x \
					else Vector3(0.42, 3.8, 0.48)
				var tilt := Vector3(0.0, 0.0, flank * 0.63) if along_x \
					else Vector3(-flank * 0.63, 0.0, 0.0)
				_add_brick(arm_at, arm_size, "cold", tilt, "wall_arcade", bay, 1)
			var crown := Vector3(along, 9.73, face + normal * 0.04) if along_x \
				else Vector3(face + normal * 0.04, 9.73, along)
			_add_brick(crown, Vector3(0.92, 0.58, 0.50), "warm", Vector3.ZERO,
				"wall_arcade_keystone", bay, 0)
	# Frame existing keep windows with projecting jambs and small stone hoods.
	# The window dark panels are left exposed and their positions are unchanged.
	var keep_base := Vector3(0.0, 0.0, -8.0)
	for storey: int in 3:
		var height := 6.0 + float(storey) * 9.0
		for side: float in [-1.0, 1.0]:
			for opening: int in 2:
				var along := -4.6 + float(opening) * 9.2
				for along_x: bool in [true, false]:
					var face := side * (KEEP_SIZE.z * 0.5 + 0.92)
					var centre := keep_base + (Vector3(along, height, face) if along_x \
						else Vector3(face, height, along))
					for flank: float in [-1.0, 1.0]:
						var jamb := centre + (Vector3(flank * 0.82, 0.0, 0.0) if along_x \
							else Vector3(0.0, 0.0, flank * 0.82))
						var size := Vector3(0.32, 2.92, 0.38) if along_x \
							else Vector3(0.38, 2.92, 0.32)
						_add_brick(jamb, size, "cold", Vector3.ZERO, "keep_window_frame", storey, opening)
					var hood := centre + Vector3.UP * 1.52
					_add_brick(hood, Vector3(2.15, 0.30, 0.48) if along_x \
						else Vector3(0.48, 0.30, 2.15), "warm", Vector3.ZERO,
						"keep_window_hood", storey, opening)

## A projecting, layered entrance gives the front wall a readable profile from the
## catapult spawn. It only adds stones to the existing breakable MultiMesh cells;
## the gate leaves, passage, support colliders and destruction rules stay intact.
func _build_entrance_layer31() -> void:
	var front := WALL_HALF + WALL_THICK * 1.65
	# Two concentric rings of rotated voussoirs. The gap between the rings casts
	# a real shadow and lets the wooden leaves sit visibly behind stone.
	for ring: int in 2:
		var radius := 5.05 + float(ring) * 0.73
		var depth := front + float(ring) * 0.20
		for segment: int in 23:
			var angle := PI * float(segment) / 22.0
			var at := Vector3(cos(angle) * radius, 10.75 + sin(angle) * radius, depth)
			_add_brick(at, Vector3(0.86, 0.75, 0.54),
				"warm" if segment % 4 == 0 else "cold",
				Vector3(0.0, 0.0, angle - PI * 0.5), "entrance_arch31", ring, segment)
	# Narrow piers step out of the flat gatehouse. Each course is independent,
	# so a catapult breach can remove the trim with the masonry around it.
	for side: float in [-1.0, 1.0]:
		for offset: float in [6.15, 10.65]:
			var x := side * offset
			for row: int in 18:
				var height := 0.56 + float(row) * 1.06
				var face := front - 0.24 + (0.12 if row % 2 == 0 else 0.0)
				_add_brick(Vector3(x, height, face), Vector3(0.82, 1.02, 0.66),
					"warm" if row % 5 == 0 else "cold", Vector3.ZERO,
					"entrance_pier31", row, int(offset))
			for band: float in [4.8, 10.9, 17.8]:
				_add_brick(Vector3(x, band, front + 0.18), Vector3(1.25, 0.34, 0.92),
					"warm", Vector3.ZERO, "entrance_pier_cap31", int(band), int(offset))
		# A stepped capital and short corbels make the gate towers read as towers
		# rather than continuations of the curtain wall.
		for course: int in 3:
			_add_brick(Vector3(side * 8.35, 19.35 + float(course) * 0.46,
				front + 0.16 + float(course) * 0.12),
				Vector3(6.15 + float(course) * 0.36, 0.39, 0.70),
				"cold" if course == 1 else "warm", Vector3.ZERO,
				"entrance_crown31", course, int(side))
		for corbel: int in 5:
			_add_brick(Vector3(side * 8.35 + (float(corbel) - 2.0) * 1.35,
				18.65, front + 0.32), Vector3(0.48, 0.72, 0.86),
				"cold", Vector3.ZERO, "entrance_corbel31", corbel, int(side))
	# A lintel and inset heraldic panel bridge the two tower crowns above the
	# opening. Neither touches the 9.2 m clear gate passage.
	for tier: int in 4:
		_add_brick(Vector3(0.0, 17.15 + float(tier) * 0.75, front - 0.04),
			Vector3(6.65 - float(tier) * 1.05, 0.61, 0.48),
			"warm" if tier % 2 == 0 else "cold", Vector3.ZERO,
			"entrance_pediment31", tier, 0)
	_add_brick(Vector3(0.0, 18.42, front + 0.26), Vector3(0.23, 1.43, 0.14),
		"ochre", Vector3.ZERO, "entrance_crest31")
	_add_brick(Vector3(0.0, 18.75, front + 0.26), Vector3(1.12, 0.20, 0.14),
		"ochre", Vector3.ZERO, "entrance_crest31")
	# Two projecting bastions give the gate a real defensive mass. Their front
	# faces stand 3.4 m ahead of the curtain, and their ten separate collision
	# sections open with the same local breach rules as the existing wall.
	for side: float in [-1.0, 1.0]:
		var tower_x := side * 14.35
		var tower_z := WALL_HALF + 1.55
		for tier: int in 10:
			var at := Vector3(tower_x, 1.02 + float(tier) * 2.04, tower_z)
			var size := Vector3(4.25, 2.02, 3.7)
			_add_brick(at, size, "warm" if tier % 3 == 0 else "stone",
				Vector3.ZERO, "entrance_bastion31", tier, int(side))
			_add_breakable_collision(at, size)
			for edge: float in [-1.0, 1.0]:
				_add_brick(at + Vector3(edge * 1.86, 0.0, 2.00),
					Vector3(0.52, 2.03, 0.55), "cold", Vector3.ZERO,
					"entrance_bastion_quoin31", tier, int(edge))
		for band: float in [5.9, 12.0, 18.2, 20.7]:
			_add_brick(Vector3(tower_x, band, tower_z + 0.15),
				Vector3(4.76, 0.34, 4.15), "cold", Vector3.ZERO,
				"entrance_bastion_band31", int(band), int(side))
		for merlon: int in 3:
			_add_brick(Vector3(tower_x + (float(merlon) - 1.0) * 1.72,
				21.53, tower_z + 1.58), Vector3(0.96, 1.32, 0.88),
				"warm", Vector3.ZERO, "entrance_bastion_merlon31", merlon, int(side))
	# Four roof corner pinnacles break the keep's rectangular outline in the
	# distant approach view. They sit above the existing crenellated roof.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(sx * 11.55, 0.0, -8.0 + sz * 11.55)
			for tier: int in 5:
				var width := 2.55 - float(tier) * 0.33
				_add_brick(corner + Vector3.UP * (39.55 + float(tier) * 0.78),
					Vector3(width, 0.72, width), "warm" if tier % 2 == 0 else "cold",
					Vector3.ZERO, "keep_pinnacle31", tier, int(sx * 2.0 + sz))
			_add_brick(corner + Vector3.UP * 43.55, Vector3(0.48, 0.52, 0.48),
				"ochre", Vector3.ZERO, "keep_pinnacle_tip31")
	# Alternating cut-stone plinth and cornice along the four curtain walls.
	# Their projecting shadows split the otherwise uninterrupted flat elevation.
	for side_name: String in ["north", "south", "east", "west"]:
		var along_x := side_name in ["north", "south"]
		var sign := 1.0 if side_name in ["south", "east"] else -1.0
		for part: int in 46:
			var along := -67.5 + float(part) * 3.0
			if side_name == "south" and absf(along) < 12.0: continue
			for level: int in 2:
				var height := 1.05 if level == 0 else 17.9
				var face := sign * (WALL_HALF + 0.77 + (0.10 if part % 2 == 0 else 0.0))
				var at := Vector3(along, height, face) if along_x else Vector3(face, height, along)
				var size := Vector3(2.93, 0.42, 0.50) if along_x else Vector3(0.50, 0.42, 2.93)
				_add_brick(at, size, "warm" if (part + level) % 3 == 0 else "cold",
					Vector3.ZERO, "curtain_trim31", level, part)
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

## Shallow stone relief over the gate. All details remain breakable masonry instances.
func _build_gate_arch() -> void:
	var face_z := WALL_HALF + WALL_THICK * 0.72
	# A real voussoir rhythm replaces the three isolated diamonds. The shallow
	# arch follows the gateway and stays below the separate heraldic shield.
	for stone: int in 17:
		var angle := deg_to_rad(11.0 + float(stone) * 9.875)
		var x := cos(angle) * 4.05
		var y := 10.9 + sin(angle) * 4.05
		_add_brick(Vector3(x, y, face_z + 0.14),
			Vector3(1.18, 1.12, 0.48) if stone == 8 else Vector3(0.94, 0.90, 0.42),
			"warm" if stone == 8 else "cold", Vector3.ZERO,
			"gate_voussoir", stone, 0)
	for side: float in [-1.0, 1.0]:
		_add_brick(Vector3(side * 4.75, 12.08, face_z), Vector3(1.22, 0.36, 0.46),
			"warm", Vector3.ZERO, "gate_impost")
	for side: float in [-1.0, 1.0]:
		_add_brick(Vector3(side * 6.22, GATE_HEIGHT + 1.9, face_z),
			Vector3(0.30, 3.12, 0.40), "cold", Vector3.ZERO, "gate_relief")
	# Paired courses retain the old jamb footprint while showing actual stone bond.
	# The inner edge stays outside the passage; the gate leaves are unchanged.
	for side: float in [-1.0, 1.0]:
		for row: int in 12:
			for column: int in 2:
				var x := side * (GATE_WIDTH * 0.5 + 0.44 + float(column) * 1.02)
				_add_brick(Vector3(x, (float(row) + 0.5) * GATE_HEIGHT / 12.0, WALL_HALF),
					Vector3(0.96, GATE_HEIGHT / 12.0 * 0.91, WALL_THICK * 1.7),
					"cold" if (row + column) % 3 == 0 else "stone", Vector3.ZERO,
					"gate_jamb", row, column)
			# Projecting stone ends break the flat facade at every second course.
			if row % 2 == 0:
				_add_brick(Vector3(side * (GATE_WIDTH * 0.5 + 1.45),
					(float(row) + 0.5) * GATE_HEIGHT / 12.0, WALL_HALF + 1.02),
					Vector3(0.48, 0.84, 0.24), "warm", Vector3.ZERO,
					"gate_jamb_quoin", row, 0)

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
	# A single shared mesh and shader draw all four forked pennants. The vertex
	# wave runs on the GPU; no per-frame scene-tree work or cloth physics is added.
	var cloth := ShaderMaterial.new()
	var cloth_shader := Shader.new()
	cloth_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void vertex() {
	float reach = clamp(UV.x, 0.0, 1.0);
	VERTEX.z += sin(TIME * 1.5 - reach * 5.0) * 0.17 * reach;
}
void fragment() {
	vec3 red = vec3(0.36, 0.025, 0.045);
	vec3 gold = vec3(0.79, 0.57, 0.18);
	float edge = 1.0 - step(0.065, UV.y) + step(0.935, UV.y);
	float charge = step(abs(UV.x - 0.33) + abs(UV.y - 0.5) * 0.68, 0.19);
	ALBEDO = mix(red, gold, clamp(edge + charge, 0.0, 1.0));
}
"""
	cloth.shader = cloth_shader
	var flag_mesh := _make_forked_flag_mesh()
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
		flag.mesh = flag_mesh
		flag.material_override = cloth
		flag.position = centre + Vector3(0.12, TOWER_HEIGHT + 5.55, 0.0)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flag)

func _make_forked_flag_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	for strip: int in 8:
		var left := float(strip) * 0.3
		var right := float(strip + 1) * 0.3
		for point: Vector2 in [Vector2(left, -0.75), Vector2(right, -0.75),
				Vector2(right, 0.75), Vector2(left, -0.75),
				Vector2(right, 0.75), Vector2(left, 0.75)]:
			vertices.append(Vector3(point.x, point.y, 0.04 * sin(point.x * 2.0)))
			uvs.append(Vector2(point.x / 3.0, (point.y + 0.75) / 1.5))
			normals.append(Vector3.FORWARD)
	# The two tapered tails leave a distinct V-shaped notch in the free edge.
	for point: Vector2 in [Vector2(2.4, 0.0), Vector2(3.0, 0.75), Vector2(2.4, 0.75),
			Vector2(2.4, -0.75), Vector2(3.0, -0.75), Vector2(2.4, 0.0)]:
		vertices.append(Vector3(point.x, point.y, 0.04 * sin(point.x * 2.0)))
		uvs.append(Vector2(point.x / 3.0, (point.y + 0.75) / 1.5))
		normals.append(Vector3.FORWARD)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
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

## A blade can splinter timber furnishings, but cannot fracture masonry, iron or
## the oak gate. The caller supplies the exact physics collider and contact point.
func apply_melee_hit(collider: Node, point: Vector3, speed: float,
		impulse: Vector3) -> Dictionary:
	if not _ready or not is_instance_valid(collider) or collider.get_parent() != self:
		return {"ok": false, "reason": "foreign_or_unready"}
	if not bool(collider.get_meta("castle_furnishing", false)) or speed < 1.5:
		return {"ok": false, "reason": "blade_resistant"}
	var group: String = str(collider.get_meta("castle_furnishing_group", ""))
	var material_key: String = str(collider.get_meta("castle_furnishing_material", ""))
	var section: Dictionary = {}
	for candidate: Dictionary in _wall_collision:
		if candidate.get("body") == collider and bool(candidate.get("alive", false)):
			section = candidate
			break
	if section.is_empty(): return {"ok": false, "reason": "already_broken"}
	var hp: float = float(collider.get_meta("castle_melee_hp", 2.0)) - \
		clampf(speed / 5.0, 0.5, 1.5)
	collider.set_meta("castle_melee_hp", hp)
	if hp > 0.0:
		return {"ok": true, "broken": false, "material": material_key, "hp": hp}
	var local_point: Vector3 = to_local(point)
	var best_index := -1
	var best_distance := INF
	for value: Variant in _furniture_cells.get(group, []):
		var index: int = int(value)
		var cell: Dictionary = _cells[index]
		if not bool(cell.get("alive", false)):
			continue
		var centre: Vector3 = cell["at"]
		var half: Vector3 = cell["size"] * 0.5
		var delta: Vector3 = local_point - centre
		var nearest := Vector3(clampf(delta.x, -half.x, half.x),
			clampf(delta.y, -half.y, half.y), clampf(delta.z, -half.z, half.z))
		var distance: float = (delta - nearest).length()
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index < 0 or best_distance > 0.5:
		return {"ok": false, "reason": "no_matching_piece"}
	_kill_brick(best_index, impulse, clampf(speed * 1.2, 3.0, 12.0))
	_release_furniture_dependents(group, section["at"], impulse, speed)
	section["alive"] = false
	(collider as CollisionObject3D).collision_layer = 0
	(collider as CollisionObject3D).collision_mask = 0
	if material_key.begins_with("wood"):
		for splinter: int in 3:
			_spawn_falling_brick({"at": local_point + Vector3(
				randf_range(-0.15, 0.15), randf_range(-0.15, 0.15),
				randf_range(-0.15, 0.15)), "size": Vector3(0.08, 0.28, 0.06),
				"material": material_key, "rotation": Vector3.ZERO,
				"row": 0, "column": splinter}, impulse, speed)
	return {"ok": true, "broken": true, "material": material_key, "group": group}

func _release_furniture_dependents(group: String, at: Vector3,
		impulse: Vector3, speed: float) -> void:
	var dependent: Array[String] = []
	var reach := 2.5
	match group:
		"hall_table": dependent = ["hall_table_leg", "hall_table_slats", "hall_table_edge",
			"hall_table_brace", "hall_plate", "hall_goblet"]
		"hall_bench": dependent = ["hall_bench_leg"]
		"hall_chair": dependent = ["hall_chair_cushion", "hall_chair_leg", "hall_chair_back"]
		"hall_chest": dependent = ["hall_chest_band", "hall_chest_lid"]
		"armour_rack": dependent = ["armour_rack_post", "armour_rack_rail", "armour_crest",
			"armour_hook", "armour_backer"]
		"armour_shield_mount": dependent = ["armour_shield_trim", "armour_shield_hook"]
		"armour_bench": dependent = ["armour_leg", "armour_bench_slats"]
		"armour_chest": dependent = ["armour_chest_lid", "armour_chest_frame",
			"armour_chest_foot", "armour_chest_panel", "armour_chest_inlay",
			"armour_chest_band", "armour_chest_lock"]
		"archive_shelf": dependent = ["archive_shelf_post", "archive_shelf_crown",
			"archive_books", "archive_shelf_trim"]
		"archive_desk": dependent = ["archive_desk_slats", "archive_desk_leg", "archive_map"]
		"chamber_bed": dependent = ["chamber_bed_rail", "chamber_mattress",
			"chamber_cover", "chamber_pillow"]
		"chamber_headboard": dependent = ["chamber_headboard_crest", "chamber_headboard_finial"]
		"chamber_wardrobe": dependent = ["chamber_wardrobe_crown",
			"chamber_wardrobe_panel", "chamber_handle"]
		_: return
	for dependent_group: String in dependent:
		for value: Variant in _furniture_cells.get(dependent_group, []):
			var index: int = int(value)
			var cell: Dictionary = _cells[index]
			if bool(cell.get("alive", false)) and \
					(cell["at"] as Vector3).distance_to(at) <= reach:
				_kill_brick(index, impulse, minf(speed, 8.0))

func wall_half() -> float:
	return WALL_HALF

func get_stats() -> Dictionary:
	return {
		"ok": _ready, "bricks": _cells.size(), "detached": _detached,
		"collapsed": _collapsed, "gates": _gate_leaves.size(),
		"gate_open": _gate_leaves.size() > 0 and bool(_gate_leaves[0].get("detached", false)),
		"gate_leaves_detached": _gate_leaves_detached(),
		"gate_boards_broken": _gate_boards_broken(),
		"gate_board_colliders_active": _gate_board_colliders_active(),
		"wall_collision_active": _wall_collision.filter(func(section: Dictionary) -> bool:
			return bool(section.get("alive", false))).size(),
		"falling": _falling.size(), "events": _events.size(), "leaf_dbg": _leaf_debug(),
		"gate_bricks": _count_gate_bricks(),
	}

## DSH_OPT: every cell index whose grid box overlaps a cube round `at`. The boxes are
## coarse (8 m) so a blast touches a few dozen of them, not the whole map.
func _indices_near(at: Vector3, reach: float) -> Array[int]:
	var out: Array[int] = []
	var low := at - Vector3.ONE * reach
	var high := at + Vector3.ONE * reach
	var gx0 := int(floor(low.x / SPATIAL_STEP))
	var gx1 := int(floor(high.x / SPATIAL_STEP))
	var gy0 := int(floor(low.y / SPATIAL_STEP))
	var gy1 := int(floor(high.y / SPATIAL_STEP))
	var gz0 := int(floor(low.z / SPATIAL_STEP))
	var gz1 := int(floor(high.z / SPATIAL_STEP))
	for gx: int in range(gx0, gx1 + 1):
		for gy: int in range(gy0, gy1 + 1):
			for gz: int in range(gz0, gz1 + 1):
				var bucket: Variant = _spatial.get("%d|%d|%d" % [gx, gy, gz])
				if bucket != null:
					for index: int in bucket:
						out.append(index)
	return out

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
	for index: int in _indices_near(at, radius):
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
		# SECTION BY SECTION, where the stone struck. Each leaf has six plank columns
		# and eight short courses; a hit opens a local hole. The hinge releases only
		# when every section of the leaf has been destroyed.
		# The planks are drawn through the leaf's MultiMesh, so the distance is taken
		# in the PIVOT's space: the leaf can be swinging, and the planks swing with it.
		# Distance to the NEAREST POINT of the board, not to its middle: a stone that
		# strikes the top of a door is four metres from the centre of every board and was
		# measured as a miss.
		var pivot_hit: Vector3 = pivot.to_local(at_world)
		for board: Dictionary in boards:
			if bool(board.get("broken", false)): continue
			var local_hit: Vector3 = pivot_hit
			var board_at: Vector3 = board.get("at", Vector3.ZERO)
			var board_size: Vector3 = board.get("size", Vector3(0.8, 1.4, 0.26))
			var nearest := Vector3(
				clampf(local_hit.x, board_at.x - board_size.x * 0.5, board_at.x + board_size.x * 0.5),
				clampf(local_hit.y, board_at.y - board_size.y * 0.5, board_at.y + board_size.y * 0.5),
				clampf(local_hit.z, board_at.z - board_size.z * 0.5, board_at.z + board_size.z * 0.5))
			var hole: float = clampf(0.5 + power * 0.004, 0.6, 2.0)
			if local_hit.distance_to(nearest) > hole: continue
			board["broken"] = true
			var multi: MultiMeshInstance3D = board.get("multi")
			var slot: int = int(board.get("slot", -1))
			if is_instance_valid(multi) and multi.multimesh != null and slot >= 0:
				multi.multimesh.set_instance_transform(slot,
					Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001),
						Vector3(0.0, -4000.0, 0.0)))
			var board_shape: CollisionShape3D = board.get("shape")
			if is_instance_valid(board_shape): board_shape.disabled = true
			killed += 1
			# The fallen plank and chips share the bounded debris pool with masonry.
			var plank_at: Vector3 = to_local(pivot.global_transform * board_at) \
				+ Vector3(0.0, 0.2, 0.9)
			_spawn_falling_brick({"at": plank_at, "size": board_size, "material": "wood",
				"rotation": Vector3.ZERO, "row": 0, "column": 0}, direction, power * 0.45)
			for splinter: int in 3:
				_spawn_falling_brick({"at": plank_at + Vector3(randf_range(-0.3, 0.3),
					randf_range(-0.4, 0.4), 0.1), "size": Vector3(randf_range(0.05, 0.10),
					randf_range(0.20, 0.48), randf_range(0.04, 0.08)),
					"material": "wood", "rotation": Vector3.ZERO, "row": 0, "column": splinter},
					direction, power * 0.4)
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
	if killed > 0:
		_break_collision_near(at, radius)
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
	for index: int in _indices_near(at, radius + 0.5):
		var cell: Dictionary = _cells[index]
		if bool(cell.get("alive", false)): continue
		var brick_at: Vector3 = cell.get("at", Vector3.ZERO)
		if brick_at.distance_to(at) > radius + 0.5: continue
		holes.append({"x": brick_at.x, "y": brick_at.y, "z": brick_at.z})
	if holes.is_empty(): return
	# Only the box a breach can reach upward needs to be visited: a support brick is
	# within a brick of the hole's footprint and inside the same breach height.
	var reach: float = radius * 3.2 + 2.0
	for index: int in _indices_near(at, reach):
		var cell: Dictionary = _cells[index]
		if not bool(cell.get("alive", false)): continue
		var brick_at: Vector3 = cell.get("at", Vector3.ZERO)
		if brick_at.distance_to(at) > reach: continue
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
			# Back to the pool, not to the allocator.
			_recycle_stone(body)
			_falling.remove_at(index)

## Where the player appears: in the courtyard, with the gate behind him.
func spawn_point() -> Vector3:
	return global_position + Vector3(0.0, 1.2, 14.0)
