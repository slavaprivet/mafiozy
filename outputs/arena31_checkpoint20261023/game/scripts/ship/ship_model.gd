extends Node3D
## SHIP61 — procedural 3D model of an 8–10 player battle sailing ship.
##
## Local frame is fixed by the contract: origin on the waterline, +Z stern,
## -Z bow, +X starboard.  main deck y=1.75, quarterdeck y=3.0, upper
## fighting top y=5.2, mast base (0,1.75,-1.0).
##
## Everything is built once from primitives, batched into one SurfaceTool per
## material/part, so a whole hull side is a single draw call while still being
## made of individual strakes with per-plank colours.  Dynamic pieces (wheel,
## cannons, sails, flags, lanterns) are separate nodes because the boat, the
## gun crew and the damage code have to animate them.
##
## build() is idempotent: the boat, cannon host and battle host may all call it.

const LENGTH := 26.0
const BEAM := 8.8
const DECK_Y := 1.75
const QUARTER_Y := 3.0
const CABIN_FLOOR_Y := 0.5
const CABIN_CEIL_Y := 2.95
const BOW_Z := -13.0
const STERN_Z := 13.0
const MAST_BASE := Vector3(0.0, 1.75, -1.0)
const MAST_TOP := Vector3(0.0, 17.7, -1.0)
const UPPER_Y := 5.2
const UPPER_POS := Vector3(0.0, 5.2, -1.2)
const LADDER_BASE := Vector3(0.0, 1.75, 2.3)
const HELM_POS := Vector3(0.0, 3.05, 10.4)
const LEVER_POS := Vector3(1.0, 2.2, 0.2)
const BOW_POS := Vector3(0.0, 2.15, -13.0)
const HOLE_CAP := 24
## Torn canvas holes are decals in a single MultiMesh (two instances per hole so
## the two-sided sail shows the hole from both sides).  The pool is fixed; the
## oldest hole is recycled once it is full.
const SAIL_HOLE_CAP := 16
const SAIL_HOLE_SEGMENTS := 15

## Live rigging: twelve Verlet chains, seven points (six rendered segments)
## each.  All positions stay in the model's local frame, so the boat's roll,
## pitch and yaw are fed back into the simulation as a local gravity vector.
const RIG_POINTS := 7
const RIG_SEGMENTS := 6
const RIG_ROPE_COUNT := 12
## Wet band height above the local waterline (y = 0).
const WET_BAND_M := 0.30

const PORT_Z: Array[float] = [-4.2, 3.4]
const PORT_HALF_WIDTH := 0.80
const PORT_BOTTOM := 1.82
const PORT_TOP := 3.40
## Companionway treads (main deck -> cabin floor).  Six shallow treads in a longer
## opening instead of four steep ones: a 1.9 m character has to get his head below
## the quarterdeck slab (2.955 m) before its front edge at z=6.05, and the old
## 0.72 m opening kept him at 1.4 m there — the doorway was a dead end.
const STEP_TOPS: Array[float] = [1.60, 1.38, 1.16, 0.94, 0.72, 0.52]
const STEP_BASE_Z := 4.70
const STEP_PITCH := 0.25
const COMPANION_Z0 := 4.60
const COMPANION_Z1 := 6.02

const SEC_H: Array[float] = [0.0, 0.07, 0.19, 0.35, 0.52, 0.68, 0.81, 0.92, 1.0]
const SEC_F: Array[float] = [0.0, 0.40, 0.74, 0.93, 1.0, 1.0, 0.985, 0.94, 0.87]

const HULL_TONES: Array[Color] = [
	Color(0.355, 0.250, 0.168), Color(0.315, 0.220, 0.148),
	Color(0.390, 0.278, 0.185), Color(0.288, 0.202, 0.132),
	Color(0.370, 0.262, 0.175), Color(0.330, 0.232, 0.156),
	Color(0.345, 0.242, 0.162), Color(0.306, 0.214, 0.144),
]
const COPPER_TONES: Array[Color] = [
	Color(0.195, 0.300, 0.250), Color(0.168, 0.268, 0.225),
	Color(0.225, 0.335, 0.268), Color(0.180, 0.288, 0.240),
]
const DECK_TONES: Array[Color] = [
	Color(0.285, 0.225, 0.165), Color(0.250, 0.195, 0.142),
	Color(0.315, 0.245, 0.178), Color(0.235, 0.185, 0.135),
	Color(0.270, 0.210, 0.155), Color(0.300, 0.235, 0.170),
	Color(0.262, 0.205, 0.150), Color(0.308, 0.240, 0.176),
]
const DARK_WOOD: Array[Color] = [
	Color(0.280, 0.200, 0.130), Color(0.310, 0.220, 0.145),
	Color(0.250, 0.175, 0.115), Color(0.330, 0.235, 0.155),
]
const CABIN_TONES: Array[Color] = [
	Color(0.440, 0.320, 0.215), Color(0.400, 0.290, 0.195),
	Color(0.480, 0.355, 0.240), Color(0.370, 0.270, 0.180),
]
const SAIL_COLOR := Color(0.88, 0.845, 0.755)

var _materials: Dictionary = {}
var _batch_defs: Dictionary = {}
var _batches: Dictionary = {}
var _batch_used: Dictionary = {}
var _built := false
var _anchors_cache: Dictionary = {}

var _visual: Node3D
var _static: Node3D
var _mast_node: Node3D
var _mast_lower: Node3D
var _mast_upper: Node3D
var _mast_stump: Node3D
var _sails_node: Node3D
var _rig_upper: Node3D
var _bowsprit_node: Node3D
var _transom_node: Node3D
var _rails_node: Node3D
var _upper_rail_node: Node3D
var _upper_deck_node: Node3D
var _bow_node: Node3D
var _helm_node: Node3D
var _lanterns_node: Node3D
var _cannon_nodes: Array[Node3D] = []
var _cannon_pivots: Array[Node3D] = []
var _cannon_barrels: Array[Node3D] = []
var _crate_ammo: Node3D
var _crate_boards: Node3D
var _lever_node: Node3D
var _lever_pivot: Node3D
var _wheel: Node3D

var _sail_meshes: Array[Dictionary] = []
var _rolls: Array[Dictionary] = []
var _sail_amount := 0.0
var _sail_target := 0.0
var _lever_on := false
var _lever_angle := 0.0
var _lever_pump_hold := 0.0
var _lever_pump_phase := 0.0
var _wheel_angle := 0.0
var _mast_broken := false
var _shake_amount := 0.0
var _time := 0.0
var _lantern_lights: Array[OmniLight3D] = []
var _lantern_glass_material: StandardMaterial3D

## Live rigging state (preallocated: no per-frame array allocations).
var _rig_live_mm: MultiMeshInstance3D
var _rig_meta: Array[Dictionary] = []
var _rig_a := PackedVector3Array()
var _rig_b := PackedVector3Array()
var _rig_points := PackedVector3Array()
var _rig_prev := PackedVector3Array()
var _rig_rest := PackedFloat32Array()
var _rig_solve := PackedFloat32Array()
var _rig_slack := PackedFloat32Array()
var _rig_radius := PackedFloat32Array()
var _rig_flags := PackedInt32Array()
var _rig_prev_origin := Vector3.ZERO
var _rig_prev_basis := Basis.IDENTITY
var _rig_has_prev := false
var _rig_velocity := Vector3.ZERO
var _rig_accel := Vector3.ZERO
var _rig_ang_speed := 0.0
var _rig_wind := Vector3.ZERO
var _rig_time := 0.0
var _rig_sag_max := 0.0

## Flags and pennants built for QA / break handling.
var _flags: Array[Dictionary] = []
var _flag_count := 0

var _parts: Array = []
var _part_by_id: Dictionary = {}
var _collision: Array = []
var _walk: Dictionary = {}

var _holes: Array[MeshInstance3D] = []
var _hole_mesh: ArrayMesh
var _hole_next := 0
var _damage_cells: MultiMeshInstance3D
const DAMAGE_CELL_CAP := 256

## Canvas holes: surface descriptions built with the sails, plus the pooled decals.
var _sail_defs: Array[Dictionary] = []
var _sail_holes: Array[Dictionary] = []
var _sail_hole_next := 0
var _sail_hole_mm: MultiMeshInstance3D
var _sail_hole_mesh: ArrayMesh

var _debris: Dictionary = {}
var _cannonball_mm: MultiMeshInstance3D
var _cannonball_slots: Array[Vector3] = []

var _stats_cache: Dictionary = {}

# ----------------------------------------------------------------------------- build
func build() -> Dictionary:
	if _built:
		return _anchors_cache
	_build_materials()
	_make_nodes()
	_register_batches()
	_build_hull()
	_build_damage_cells()
	_build_transom()
	_build_bulwarks()
	_build_decks()
	_build_cabin()
	_build_deck_furniture()
	_build_bow()
	_build_boarding_ladders()
	_build_stern_dressing()
	_build_details()
	_build_bulwark_carvings()
	_build_upper_deck()
	_build_cannons()
	_build_helm()
	_build_lever()
	_build_mast()
	_build_sails()
	_build_rigging()
	_build_flags()
	_build_lanterns()
	_build_holes()
	_build_debris()
	_flush_batches()
	_build_cannonballs()
	_build_collision()
	_build_parts()
	_build_walk()
	_anchors_cache = _make_anchors()
	_apply_sail_visual()
	_apply_lever_visual()
	_built = true
	return _anchors_cache

func _make_nodes() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_static = Node3D.new()
	_static.name = "Static"
	_visual.add_child(_static)

	_mast_node = Node3D.new()
	_mast_node.name = "Mast"
	_mast_node.position = MAST_BASE
	_visual.add_child(_mast_node)
	_mast_lower = Node3D.new()
	_mast_lower.name = "MastLower"
	_mast_node.add_child(_mast_lower)
	_mast_upper = Node3D.new()
	_mast_upper.name = "MastUpper"
	_mast_upper.position = Vector3(0.0, 7.2, 0.0)
	_mast_node.add_child(_mast_upper)
	_mast_stump = Node3D.new()
	_mast_stump.name = "MastStump"
	_mast_stump.position = Vector3(0.0, 7.2, 0.0)
	_mast_stump.visible = false
	_mast_node.add_child(_mast_stump)
	_rig_upper = Node3D.new()
	_rig_upper.name = "RiggingUpper"
	_mast_upper.add_child(_rig_upper)
	_rig_upper.position = -(MAST_BASE + _mast_upper.position)

	_sails_node = Node3D.new()
	_sails_node.name = "Sails"
	_mast_upper.add_child(_sails_node)
	_sails_node.position = -(MAST_BASE + _mast_upper.position)

	_bowsprit_node = Node3D.new()
	_bowsprit_node.name = "Bowsprit"
	_bowsprit_node.position = Vector3(0.0, 2.45, -12.25)
	_visual.add_child(_bowsprit_node)

	_transom_node = Node3D.new()
	_transom_node.name = "Transom"
	_visual.add_child(_transom_node)

	_rails_node = Node3D.new()
	_rails_node.name = "Rails"
	_visual.add_child(_rails_node)

	_upper_rail_node = Node3D.new()
	_upper_rail_node.name = "UpperRail"
	_visual.add_child(_upper_rail_node)

	_upper_deck_node = Node3D.new()
	_upper_deck_node.name = "UpperDeck"
	_upper_deck_node.position = UPPER_POS
	_visual.add_child(_upper_deck_node)

	_bow_node = Node3D.new()
	_bow_node.name = "Bow"
	_bow_node.position = BOW_POS
	_visual.add_child(_bow_node)

	_helm_node = Node3D.new()
	_helm_node.name = "Helm"
	_helm_node.position = HELM_POS
	_visual.add_child(_helm_node)

	_lever_node = Node3D.new()
	_lever_node.name = "SailLever"
	_lever_node.position = LEVER_POS
	_visual.add_child(_lever_node)

	_crate_ammo = Node3D.new()
	_crate_ammo.name = "CrateAmmo"
	_crate_ammo.position = Vector3(-2.0, 0.95, 10.2)
	_visual.add_child(_crate_ammo)
	_crate_boards = Node3D.new()
	_crate_boards.name = "CrateBoards"
	_crate_boards.position = Vector3(2.0, 0.95, 10.2)
	_visual.add_child(_crate_boards)

	for i: int in 4:
		var cannon := Node3D.new()
		cannon.name = "Cannon%d" % i
		var side := -1.0 if i < 2 else 1.0
		var z := PORT_Z[i % 2]
		cannon.position = Vector3(side * 3.55, DECK_Y, z)
		cannon.rotation.y = deg_to_rad(90.0) if side < 0.0 else deg_to_rad(-90.0)
		_visual.add_child(cannon)
		_cannon_nodes.append(cannon)
		var pivot := Node3D.new()
		pivot.name = "Pivot"
		pivot.position = Vector3(0.0, 0.55, 0.45)
		cannon.add_child(pivot)
		_cannon_pivots.append(pivot)
		var barrel := Node3D.new()
		barrel.name = "Barrel"
		pivot.add_child(barrel)
		_cannon_barrels.append(barrel)

	_lanterns_node = Node3D.new()
	_lanterns_node.name = "Lanterns"
	_visual.add_child(_lanterns_node)

# ----------------------------------------------------------------------------- materials
func _build_materials() -> void:
	_materials["wood"] = _wood_material(1.0, 0.9)
	_materials["wood_dark"] = _wood_material(0.86, 0.94)
	_materials["deck"] = _wood_material(0.68, 0.93)
	_materials["cabin"] = _wood_material(1.0, 0.92)

	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(1.0, 1.0, 1.0)
	copper.vertex_color_use_as_albedo = true
	copper.metallic = 0.15
	copper.roughness = 0.82
	_materials["copper"] = copper

	var tar := StandardMaterial3D.new()
	tar.albedo_color = Color(0.055, 0.048, 0.042)
	tar.roughness = 0.96
	_materials["tar"] = tar

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.165, 0.175, 0.195)
	iron.metallic = 0.5
	iron.roughness = 0.58
	_materials["iron"] = iron

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.76, 0.56, 0.20)
	gold.metallic = 0.62
	gold.roughness = 0.4
	_materials["gold"] = gold

	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.55, 0.455, 0.275)
	rope.roughness = 0.96
	_materials["rope"] = rope

	var canvas_plain := StandardMaterial3D.new()
	canvas_plain.albedo_color = Color(0.80, 0.765, 0.675)
	canvas_plain.roughness = 0.98
	_materials["canvas_plain"] = canvas_plain

	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.80, 0.735, 0.565)
	paper.roughness = 0.94
	_materials["paper"] = paper

	var velvet := StandardMaterial3D.new()
	velvet.albedo_color = Color(0.40, 0.052, 0.068)
	velvet.roughness = 0.92
	_materials["velvet"] = velvet

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.70, 0.665, 0.585)
	paint.roughness = 0.9
	_materials["paint"] = paint

	var glass_dark := StandardMaterial3D.new()
	glass_dark.albedo_color = Color(0.10, 0.16, 0.13)
	glass_dark.metallic = 0.35
	glass_dark.roughness = 0.16
	_materials["glass_dark"] = glass_dark

	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.55, 0.36, 0.13)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.70, 0.32)
	lamp.emission_energy_multiplier = 3.4
	lamp.roughness = 0.4
	_materials["lamp"] = lamp
	_lantern_glass_material = lamp

	var window := StandardMaterial3D.new()
	window.albedo_color = Color(0.34, 0.20, 0.085)
	window.emission_enabled = true
	window.emission = Color(1.0, 0.58, 0.24)
	window.emission_energy_multiplier = 1.15
	window.metallic = 0.25
	window.roughness = 0.3
	_materials["window"] = window

	var char := StandardMaterial3D.new()
	char.albedo_color = Color(1.0, 1.0, 1.0)
	char.vertex_color_use_as_albedo = true
	char.roughness = 1.0
	_materials["char"] = char

	# Wet waterline band: a thin, glossy strip over the planking.  Vertex colours
	# carry the green-black seaweed stain, the low roughness catches the sky and
	# separates the wet band from both the dry topsides and the submerged copper.
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(1.0, 1.0, 1.0)
	wet.vertex_color_use_as_albedo = true
	wet.roughness = 0.24
	wet.metallic = 0.10
	wet.metallic_specular = 0.72
	_materials["wet"] = wet

	var sail := ShaderMaterial.new()
	sail.shader = _make_sail_shader("cull_back")
	sail.set_shader_parameter("billow", 0.34)
	sail.set_shader_parameter("flip_normal", 0.0)
	_materials["sail"] = sail
	var sail2: ShaderMaterial = sail.duplicate()
	sail2.set_shader_parameter("billow", 0.24)
	_materials["sail_jib"] = sail2
	# Explicit back faces.  The sails are single planes, so one front-side and
	# one back-side copy guarantee the canvas is readable from the helm, from
	# astern and from the bow in every renderer state.  They are separated by a
	# centimetre, so the two copies never z-fight.
	var sail_back := ShaderMaterial.new()
	sail_back.shader = _make_sail_shader("cull_front")
	sail_back.set_shader_parameter("billow", 0.34)
	sail_back.set_shader_parameter("flip_normal", 1.0)
	_materials["sail_back"] = sail_back
	var sail_jib_back: ShaderMaterial = sail_back.duplicate()
	sail_jib_back.set_shader_parameter("billow", 0.24)
	_materials["sail_jib_back"] = sail_jib_back

	var flag := ShaderMaterial.new()
	var flag_shader := Shader.new()
	flag_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec3 cloth : source_color = vec3(0.52, 0.065, 0.055);
uniform vec3 trim : source_color = vec3(0.80, 0.60, 0.22);
varying vec2 flag_uv;
void vertex() {
	flag_uv = UV;
	float t = UV.x;
	VERTEX += NORMAL * (sin(t * 7.0 - TIME * 3.4) * 0.14 + sin(t * 3.0 + TIME * 1.7) * 0.06) * t;
	VERTEX.y += sin(t * 5.0 - TIME * 2.6) * 0.035 * t;
}
void fragment() {
	vec2 uv = flag_uv;
	float border = max(step(0.93, uv.y), step(0.965, uv.x));
	float cross_v = step(abs(uv.x - 0.34), 0.075) * step(abs(uv.y - 0.5), 0.30);
	float cross_h = step(abs(uv.y - 0.5), 0.075) * step(abs(uv.x - 0.34), 0.20);
	vec3 c = mix(cloth, trim, clamp(border + max(cross_v, cross_h), 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
"""
	flag.shader = flag_shader
	_materials["flag"] = flag

	# Long masthead pennant: a tapered ribbon with a stronger, faster wave.
	var pennant := ShaderMaterial.new()
	var pennant_shader := Shader.new()
	pennant_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec3 cloth : source_color = vec3(0.58, 0.062, 0.052);
uniform vec3 trim : source_color = vec3(0.84, 0.65, 0.24);
varying vec2 flag_uv;
void vertex() {
	flag_uv = UV;
	float t = UV.x;
	VERTEX += NORMAL * (sin(t * 8.0 - TIME * 4.2) * 0.24 + sin(t * 3.7 + TIME * 2.3) * 0.11) * t;
	VERTEX.y += sin(t * 6.4 - TIME * 3.2) * 0.10 * t;
}
void fragment() {
	vec2 uv = flag_uv;
	vec3 c = cloth;
	c = mix(c, trim, step(uv.x, 0.035));
	c = mix(c, vec3(0.91, 0.88, 0.79), step(0.90, uv.x) * 0.80);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
"""
	pennant.shader = pennant_shader
	_materials["pennant"] = pennant

	# Signal flags: the base colour comes from the mesh vertex colours, so one
	# material can hoist red, yellow, blue and green bunting in one place.
	var signal_mat := ShaderMaterial.new()
	var signal_shader := Shader.new()
	signal_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec3 trim : source_color = vec3(0.92, 0.90, 0.82);
varying vec2 flag_uv;
void vertex() {
	flag_uv = UV;
	float t = UV.x;
	VERTEX += NORMAL * (sin(t * 9.0 - TIME * 4.7) + sin(t * 4.1 + TIME * 2.6) * 0.62) * 0.045 * t;
	VERTEX.y += sin(t * 7.2 - TIME * 3.4) * 0.022 * t;
}
void fragment() {
	vec3 c = COLOR.rgb;
	float band = smoothstep(0.80, 0.82, flag_uv.y) * (1.0 - smoothstep(0.95, 0.97, flag_uv.y));
	c = mix(c, trim, band * 0.80);
	c *= mix(0.70, 1.0, smoothstep(0.0, 0.06, flag_uv.x));
	ALBEDO = c;
	ROUGHNESS = 0.90;
}
"""
	signal_mat.shader = signal_shader
	_materials["flag_signal"] = signal_mat

func _make_sail_shader(cull_mode: String) -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode %s, diffuse_burley, specular_schlick_ggx;
uniform vec3 cloth_color : source_color = vec3(0.86, 0.82, 0.72);
uniform float billow = 0.34;
uniform float rough = 0.96;
uniform float flip_normal = 0.0;
varying vec2 sail_uv;
void vertex() {
	sail_uv = UV;
	vec3 cloth_normal = NORMAL;
	float belly = sin(UV.x * PI) * sin(UV.y * PI);
	float flap = sin(UV.x * 9.0 + TIME * 2.1 + UV.y * 4.0) * 0.012;
	VERTEX += cloth_normal * (belly * billow + flap);
	if (flip_normal > 0.5) {
		NORMAL = -cloth_normal;
	}
}
void fragment() {
	vec3 c = cloth_color;
	// Cloth panels: eight vertical seams and five horizontal cloth bands.
	float u = fract(sail_uv.x * 8.0);
	float seam = 1.0 - smoothstep(0.0, 0.045, min(u, 1.0 - u));
	float v = fract(sail_uv.y * 5.0);
	float band = 1.0 - smoothstep(0.0, 0.035, min(v, 1.0 - v));
	c *= 1.0 - 0.10 * seam - 0.06 * band;
	// Bolt rope around the edges.
	float edge = min(min(sail_uv.x, 1.0 - sail_uv.x), min(sail_uv.y, 1.0 - sail_uv.y));
	c *= mix(0.72, 1.0, smoothstep(0.004, 0.022, edge));
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.15;
	BACKLIGHT = vec3(0.24, 0.21, 0.15);
}
""" % cull_mode
	return shader

func _wood_material(brightness: float, roughness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float brightness = 1.0;
uniform float rough = 0.9;
uniform float specular_amount = 0.05;
varying vec3 wood_local;
void vertex() {
	wood_local = VERTEX;
}
void fragment() {
	vec3 c = COLOR.rgb * brightness;
	float grain = sin(wood_local.z * 41.0 + sin(wood_local.y * 7.0) * 3.2);
	float fine = sin(wood_local.z * 151.0 + wood_local.y * 13.0);
	c *= 0.925 + 0.055 * grain + 0.025 * fine;
	c *= 0.97 + 0.06 * sin(wood_local.z * 2.6 + wood_local.y * 9.0);
	ALBEDO = clamp(c, vec3(0.0), vec3(1.0));
	ROUGHNESS = rough;
	// Small specular: a rough oak hull otherwise turns into a mirror of the
	// bright sky at the grazing angles a side view uses.
	SPECULAR = specular_amount;
}
"""
	material.shader = shader
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("rough", roughness)
	return material

# ----------------------------------------------------------------------------- batches
func _register(key: String, material_name: String, parent: Node3D, shadows: bool) -> void:
	_batch_defs[key] = {"material": _materials[material_name], "parent": parent, "shadows": shadows}

func _register_batches() -> void:
	var names := [
		"wood", "wood_dark", "deck", "copper", "tar", "iron", "gold", "rope",
		"cabin", "paper", "velvet", "window", "lamp", "char",
	]
	for n: String in names:
		_register("static_" + n, n, _static, n != "rope")
	# Hull, decks and bulk structure: these cast shadows.  The hull loft and the
	# copper sheathing are a zero-thickness shell, though: a directional shadow
	# map makes them shadow themselves and the whole side goes flat black, so
	# those two batches receive light only.
	_register("hull", "wood", _static, false)
	_register("hull_meet", "wood_dark", _static, true)
	_register("copper", "copper", _static, false)
	_register("wet", "wet", _static, false)
	_register("deck", "deck", _static, true)
	_register("deck_dark", "wood_dark", _static, true)
	_register("trim", "wood_dark", _static, true)
	_register("iron", "iron", _static, true)
	_register("gold", "gold", _static, true)
	_register("rope", "rope", _static, false)
	_register("window", "window", _static, false)
	_register("velvet", "velvet", _static, true)
	# Cabins / interior.
	_register("cabin_wood", "cabin", _static, true)
	_register("cabin_dark", "wood_dark", _static, true)
	_register("cabin_paper", "paper", _static, false)
	_register("cabin_paint", "paint", _static, true)
	_register("cabin_glass", "glass_dark", _static, false)
	# Mast.
	_register("mast_lower", "wood", _mast_lower, true)
	_register("mast_upper", "wood", _mast_upper, true)
	_register("mast_iron", "iron", _mast_lower, false)
	_register("mast_stump", "wood_dark", _mast_stump, true)
	# Yards and rigging above the break.
	_register("yard", "wood", _rig_upper, true)
	_register("yard_iron", "iron", _rig_upper, false)
	# Bowsprit.
	_register("bowsprit", "wood", _bowsprit_node, true)
	_register("bowsprit_iron", "iron", _bowsprit_node, false)
	_register("bowsprit_gold", "gold", _bowsprit_node, false)
	# Transom dressing.
	_register("transom", "wood", _transom_node, true)
	_register("transom_dark", "wood_dark", _transom_node, true)
	_register("transom_gold", "gold", _transom_node, false)
	_register("transom_glass", "window", _transom_node, false)
	_register("transom_velvet", "velvet", _transom_node, true)
	# Rails.
	_register("rails", "wood_dark", _rails_node, true)
	_register("rails_gold", "gold", _rails_node, false)
	_register("upper_rail", "wood_dark", _upper_rail_node, true)
	# Helm.
	_register("helm_wood", "wood_dark", _helm_node, true)
	_register("helm_iron", "iron", _helm_node, false)
	_register("helm_gold", "gold", _helm_node, false)
	# Lever.
	_register("lever_iron", "iron", _lever_node, false)
	_register("lever_gold", "gold", _lever_node, false)
	# Crates.
	_register("crate_ammo_wood", "wood", _crate_ammo, true)
	_register("crate_ammo_iron", "iron", _crate_ammo, false)
	_register("crate_boards_wood", "wood", _crate_boards, true)
	_register("crate_boards_iron", "iron", _crate_boards, false)
	# Cannons: the carriage is static, the barrel lives under its own pivot.
	for i: int in 4:
		var node := _cannon_nodes[i]
		_register("cannon%d_wood" % i, "wood", node, true)
		_register("cannon%d_iron" % i, "iron", node, false)
		_register("cannon%d_rope" % i, "rope", node, false)
		_register("cannon%d_barrel_iron" % i, "iron", _cannon_barrels[i], false)
	# Lanterns.
	_register("lantern_iron", "iron", _lanterns_node, false)
	_register("lantern_gold", "gold", _lanterns_node, false)
	_register("lantern_glass", "lamp", _lanterns_node, false)

func _st(key: String) -> SurfaceTool:
	if _batches.has(key):
		_batch_used[key] = true
		return _batches[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_batches[key] = st
	_batch_used[key] = true
	return st

func _flush_batches() -> void:
	for key: String in _batches:
		if not _batch_defs.has(key) or not _batch_used.get(key, false):
			continue
		var st: SurfaceTool = _batches[key]
		st.index()
		var mesh := st.commit()
		if mesh == null or mesh.get_surface_count() <= 0:
			continue
		var node := MeshInstance3D.new()
		node.name = "M_" + key
		node.mesh = mesh
		var def: Dictionary = _batch_defs[key]
		node.material_override = def["material"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if def["shadows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(def["parent"] as Node3D).add_child(node)

# ----------------------------------------------------------------------------- primitives
func _vertex(st: SurfaceTool, p: Vector3, n: Vector3, c: Color, uv: Vector2 = Vector2.ZERO) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)

func _tri(key: String, a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3) -> void:
	var st := _st(key)
	# Godot's front faces are CLOCKWISE: the right-hand geometric normal must
	# point opposite the outward normal we want to light/cull from outside.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var tmp := b
		b = c
		c = tmp
	_vertex(st, a, normal, color)
	_vertex(st, b, normal, color)
	_vertex(st, c, normal, color)

func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, normal: Vector3) -> void:
	var st := _st(key)
	var gn := (b - a).cross(c - a) + (c - a).cross(d - a)
	if gn.dot(normal) > 0.0:
		var tmp := b
		b = d
		d = tmp
	_vertex(st, a, normal, color, Vector2(0.0, 0.0))
	_vertex(st, b, normal, color, Vector2(0.0, 1.0))
	_vertex(st, c, normal, color, Vector2(1.0, 1.0))
	_vertex(st, a, normal, color, Vector2(0.0, 0.0))
	_vertex(st, c, normal, color, Vector2(1.0, 1.0))
	_vertex(st, d, normal, color, Vector2(1.0, 0.0))

func _box(key: String, center: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	if hx <= 0.0 or hy <= 0.0 or hz <= 0.0:
		return
	var p := [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
		Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz),
	]
	var faces := [
		[1, 5, 6, 2, Vector3(1, 0, 0), 0.98],
		[0, 4, 7, 3, Vector3(-1, 0, 0), 0.96],
		[3, 7, 6, 2, Vector3(0, 1, 0), 1.10],
		[0, 1, 5, 4, Vector3(0, -1, 0), 0.74],
		[4, 5, 6, 7, Vector3(0, 0, 1), 1.03],
		[0, 3, 2, 1, Vector3(0, 0, -1), 0.92],
	]
	for f: Array in faces:
		var face_normal: Vector3 = f[4]
		var n: Vector3 = basis * face_normal
		var shade: float = f[5]
		_quad(key, center + basis * p[f[0]], center + basis * p[f[1]],
			center + basis * p[f[2]], center + basis * p[f[3]], color * shade, n)

func _box_y(key: String, center: Vector3, size: Vector3, color: Color, yaw: float) -> void:
	_box(key, center, size, color, Basis(Vector3.UP, yaw))

func _tube(key: String, from: Vector3, to: Vector3, r0: float, r1: float, sides: int, color: Color, caps: bool = true) -> void:
	var axis := to - from
	var length := axis.length()
	if length < 0.0005 or sides < 3:
		return
	var up := axis / length
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x_axis := ref.cross(up).normalized()
	var z_axis := x_axis.cross(up).normalized()
	var st := _st(key)
	for i: int in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := x_axis * cos(a0) + z_axis * sin(a0)
		var d1 := x_axis * cos(a1) + z_axis * sin(a1)
		var n0 := d0
		var n1 := d1
		_quad(key, from + d0 * r0, to + d0 * r1, to + d1 * r1, from + d1 * r0,
			color, ((n0 + n1) * 0.5).normalized())
	if caps:
		var n_from := -up
		var n_to := up
		for i: int in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var d0 := x_axis * cos(a0) + z_axis * sin(a0)
			var d1 := x_axis * cos(a1) + z_axis * sin(a1)
			_tri(key, from, from + d0 * r0, from + d1 * r0, color, n_from)
			_tri(key, to, to + d0 * r1, to + d1 * r1, color, n_to)

func _ring(key: String, center: Vector3, axis: Vector3, radius: float, tube_r: float, segments: int, color: Color) -> void:
	var up := axis.normalized()
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x_axis := ref.cross(up).normalized()
	var z_axis := x_axis.cross(up).normalized()
	var prev := center + x_axis * radius
	for i: int in range(1, segments + 1):
		var a := TAU * float(i) / float(segments)
		var dir := x_axis * cos(a) + z_axis * sin(a)
		var p := center + dir * radius
		_tube(key, prev, p, tube_r, tube_r, 4, color, false)
		prev = p

func _sphere(key: String, center: Vector3, radius: float, color: Color, rings: int = 5, sides: int = 8) -> void:
	var st := _st(key)
	for r: int in rings:
		var a0 := PI * float(r) / float(rings)
		var a1 := PI * float(r + 1) / float(rings)
		for s: int in sides:
			var b0 := TAU * float(s) / float(sides)
			var b1 := TAU * float(s + 1) / float(sides)
			var p00 := center + Vector3(sin(a0) * cos(b0), cos(a0), sin(a0) * sin(b0)) * radius
			var p01 := center + Vector3(sin(a0) * cos(b1), cos(a0), sin(a0) * sin(b1)) * radius
			var p11 := center + Vector3(sin(a1) * cos(b1), cos(a1), sin(a1) * sin(b1)) * radius
			var p10 := center + Vector3(sin(a1) * cos(b0), cos(a1), sin(a1) * sin(b0)) * radius
			var n := ((p00 - center) + (p11 - center)).normalized()
			_quad(key, p00, p01, p11, p10, color, n)

func _hash01(a: int, b: int, c: int = 0) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = h & 0x7fffffff
	return float(h % 997) / 996.0

func _tone(tones: Array, index: int) -> Color:
	if tones.is_empty():
		return Color(0.5, 0.35, 0.2)
	var i := index % tones.size()
	if i < 0:
		i += tones.size()
	return tones[i]

## Submerged copper: green-black patina, progressively extinguished with depth.
## Kept above the black point so the plates still read as copper near the water.
func _copper_tone(base: Color, y: float) -> Color:
	var depth := clampf(maxf(-y, 0.0) / 1.10, 0.0, 1.0)
	var patina := base.lerp(Color(0.082, 0.126, 0.104), 0.40 + 0.24 * depth)
	return patina * lerpf(0.82, 0.46, depth)

## Topsides close to the water: a thin wet/weed stain that fades out by 0.6 m.
func _topsides_tone(base: Color, y: float) -> Color:
	if y >= 0.62:
		return base
	var wet := 1.0 - smoothstep(0.08, 0.62, y)
	return (base.lerp(Color(0.105, 0.125, 0.095), wet * 0.55) * lerpf(0.86, 1.0, wet))

func _waterline_tone(z: float, height: float) -> Color:
	var n := _hash01(int(z * 9.0), int(height * 100.0), 7)
	return (Color(0.105, 0.135, 0.108) * (0.86 + 0.18 * n)).lerp(
		Color(0.070, 0.095, 0.078), clampf(height / WET_BAND_M, 0.0, 1.0) * 0.35)

# ----------------------------------------------------------------------------- hull shape
func _half_beam(z: float) -> float:
	var table := [
		[-13.0, 0.30], [-12.5, 0.85], [-11.8, 1.70], [-10.8, 2.70], [-9.5, 3.50],
		[-7.5, 4.05], [-5.0, 4.32], [-2.0, 4.40], [2.0, 4.40], [5.0, 4.34],
		[7.0, 4.24], [9.5, 4.02], [11.5, 3.80], [13.0, 3.58],
	]
	if z <= table[0][0]:
		return table[0][1]
	for i: int in range(table.size() - 1):
		var z0: float = table[i][0]
		var z1: float = table[i + 1][0]
		if z <= z1:
			var t := (z - z0) / (z1 - z0)
			return lerpf(table[i][1], table[i + 1][1], t * t * (3.0 - 2.0 * t))
	return table[table.size() - 1][1]

func _keel_y(z: float) -> float:
	var t := clampf((z + 13.0) / 26.0, 0.0, 1.0)
	return -2.15 + 1.25 * pow(absf(t * 2.0 - 1.0), 2.4)

func _rail_top(z: float) -> float:
	if z >= 6.0:
		return 3.86
	if z <= -12.0:
		return 3.02
	if z <= -8.0:
		return lerpf(3.02, 2.88, (z + 12.0) / 4.0)
	if z <= -4.0:
		return lerpf(2.88, 2.82, (z + 8.0) / 4.0)
	if z <= 3.0:
		return 2.80
	return lerpf(2.80, 2.84, (z - 3.0) / 3.0)

func _deck_level(z: float) -> float:
	return QUARTER_Y if z >= 5.999 else DECK_Y

func _section_factor(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	for i: int in range(SEC_H.size() - 1):
		if u <= SEC_H[i + 1]:
			var span: float = SEC_H[i + 1] - SEC_H[i]
			var k: float = 0.0 if span <= 0.0 else (u - SEC_H[i]) / span
			return lerpf(SEC_F[i], SEC_F[i + 1], k)
	return SEC_F[SEC_F.size() - 1]

## Half width of the hull at a height.  Below the keel / above the rail it
## clamps, which is exactly what the bulwark panels want for their top edge.
func _hull_gunport_cut(z0: float, z1: float, y0: float, y1: float) -> bool:
	for pz: float in PORT_Z:
		if z1 > pz - PORT_HALF_WIDTH and z0 < pz + PORT_HALF_WIDTH and y1 > PORT_BOTTOM and y0 < PORT_TOP:
			return true
	return false


func _hull_x_at(z: float, y: float) -> float:
	var keel := _keel_y(z)
	var rail := _rail_top(z)
	var t := 0.0 if rail - keel <= 0.0001 else (y - keel) / (rail - keel)
	return _half_beam(z) * _section_factor(t)

func _hull_normal(side: float, z: float, y: float) -> Vector3:
	var dz := 0.09
	var dy := 0.07
	var xz := _hull_x_at(z + dz, y) - _hull_x_at(z - dz, y)
	var xy := _hull_x_at(z, y + dy) - _hull_x_at(z, y - dy)
	var tan_z := Vector3(xz, 0.0, dz * 2.0)
	var tan_y := Vector3(xy, dy * 2.0, 0.0)
	var n := tan_y.cross(tan_z)
	if n.length_squared() < 0.000001:
		return Vector3(side, -0.2, 0.0).normalized()
	n = n.normalized()
	n.x *= side
	return n

func _build_hull() -> void:
	var stations: Array[float] = []
	var z := BOW_Z
	while z < STERN_Z - 0.001:
		stations.append(z)
		z += 0.62
	stations.append(STERN_Z)
	for extra: float in [5.94, 6.0, 6.06, -12.9, 12.9]:
		if not stations.has(extra):
			stations.append(extra)
	stations.sort()

	var copper_rows := 3
	var wood_rows := 7
	for si: int in range(stations.size() - 1):
		var z0: float = stations[si]
		var z1: float = stations[si + 1]
		if z1 - z0 < 0.005:
			continue
		for side: float in [1.0, -1.0]:
			# Copper sheathing: the whole bottom up to a horizontal waterline seam.
			for row: int in copper_rows:
				var a0 := float(row) / float(copper_rows)
				var a1 := float(row + 1) / float(copper_rows)
				var y00 := lerpf(_keel_y(z0), 0.20, a0)
				var y01 := lerpf(_keel_y(z1), 0.20, a0)
				var y10 := lerpf(_keel_y(z0), 0.20, a1)
				var y11 := lerpf(_keel_y(z1), 0.20, a1)
				if row == copper_rows - 1:
					y10 = 0.20
					y11 = 0.20
				var p00 := Vector3(side * _hull_x_at(z0, y00), y00, z0)
				var p01 := Vector3(side * _hull_x_at(z1, y01), y01, z1)
				var p11 := Vector3(side * _hull_x_at(z1, y11), y11, z1)
				var p10 := Vector3(side * _hull_x_at(z0, y10), y10, z0)
				var color: Color = _tone(COPPER_TONES, row * 7 + int((z0 + 13.0) * 3.0) + (1 if side > 0.0 else 0))
				color = _copper_tone(color, (y00 + y10) * 0.5)
				_quad("copper", p00, p10, p11, p01, color, _hull_normal(side, (z0 + z1) * 0.5, (y00 + y10) * 0.5))
			# Oak planking above the waterline up to the deck edge.
			for row: int in wood_rows:
				var l0 := _deck_level(z0)
				var l1 := _deck_level(z1)
				var a0 := float(row) / float(wood_rows)
				var a1 := float(row + 1) / float(wood_rows)
				var y00 := lerpf(0.20, l0, a0)
				var y01 := lerpf(0.20, l1, a0)
				var y10 := lerpf(0.20, l0, a1)
				var y11 := lerpf(0.20, l1, a1)
				if row == wood_rows - 1:
					y10 = l0
					y11 = l1
				if _hull_gunport_cut(z0, z1, y00, y10):
					continue
				var p00 := Vector3(side * _hull_x_at(z0, y00), y00, z0)
				var p01 := Vector3(side * _hull_x_at(z1, y01), y01, z1)
				var p11 := Vector3(side * _hull_x_at(z1, y11), y11, z1)
				var p10 := Vector3(side * _hull_x_at(z0, y10), y10, z0)
				var plank := int((z0 + 13.0) / 1.9)
				var color := _tone(HULL_TONES, plank + row * 3 + (1 if side > 0.0 else 0))
				color = color * (0.93 + 0.14 * _hash01(plank, row, 1 if side > 0.0 else 2))
				color = _topsides_tone(color, (y00 + y10) * 0.5)
				_quad("hull", p00, p10, p11, p01, color, _hull_normal(side, (z0 + z1) * 0.5, (y00 + y10) * 0.5))
			# Caulked strake seams.  A shallow dark band at every plank boundary
			# makes the side read as clinker planking instead of a smooth wall.
			for seam: int in range(1, wood_rows):
				var l0 := _deck_level(z0)
				var l1 := _deck_level(z1)
				var a := float(seam) / float(wood_rows)
				var sy0 := lerpf(0.20, l0, a)
				var sy1 := lerpf(0.20, l1, a)
				if _hull_gunport_cut(z0, z1, sy0, sy1):
					continue
				var q00 := Vector3(side * (_hull_x_at(z0, sy0) + 0.012), sy0 - 0.017, z0)
				var q01 := Vector3(side * (_hull_x_at(z1, sy1) + 0.012), sy1 - 0.017, z1)
				var q11 := Vector3(side * (_hull_x_at(z1, sy1) + 0.012), sy1 + 0.017, z1)
				var q10 := Vector3(side * (_hull_x_at(z0, sy0) + 0.012), sy0 + 0.017, z0)
				_quad("hull_meet", q00, q10, q11, q01, Color(0.165, 0.108, 0.068),
					_hull_normal(side, (z0 + z1) * 0.5, (sy0 + sy1) * 0.5))
			# Wet waterline band.  A separate thin glossy strip sits proud of the
			# planking between the waterline and 0.30 m above it: in a side view
			# the hull now reads dry oak -> wet stain -> dark copper, not one
			# uniform brown wall down to the keel.
			var wy0 := 0.015
			var wy1 := WET_BAND_M
			var w00 := Vector3(side * (_hull_x_at(z0, wy0) + 0.022), wy0, z0)
			var w01 := Vector3(side * (_hull_x_at(z1, wy0) + 0.022), wy0, z1)
			var w11 := Vector3(side * (_hull_x_at(z1, wy1) + 0.018), wy1, z1)
			var w10 := Vector3(side * (_hull_x_at(z0, wy1) + 0.018), wy1, z0)
			_quad("wet", w00, w10, w11, w01,
				_waterline_tone((z0 + z1) * 0.5, (wy0 + wy1) * 0.5),
				_hull_normal(side, (z0 + z1) * 0.5, 0.15))

	# Keel and stem: a real timber along the bottom, not a painted line.
	var keel_prev := Vector3(0.0, _keel_y(-13.0), -13.0)
	z = -12.9
	while z <= 13.01:
		var p := Vector3(0.0, _keel_y(z) - 0.02, z)
		_tube("hull_meet", keel_prev, p, 0.17, 0.17, 6, Color(0.16, 0.10, 0.058), true)
		keel_prev = p
		z += 0.9

	# Three proud wales follow the sheer.  They are what makes the side read as a hull.
	var wale_levels := [0.16, 0.92, 1.56]
	for level: float in wale_levels:
		z = -11.9
		while z < 12.95:
			var z_next := minf(z + 1.25, 12.95)
			for side: float in [1.0, -1.0]:
				var x0 := side * (_hull_x_at(z, level) + 0.035)
				var x1 := side * (_hull_x_at(z_next, level) + 0.035)
				var mid := Vector3((x0 + x1) * 0.5, level, (z + z_next) * 0.5 + 0.0)
				var len := Vector2(x1 - x0, z_next - z).length()
				var yaw := atan2(x1 - x0, z_next - z)
				_box("hull_meet", mid + Vector3(0.0, 0.0, 0.0), Vector3(0.10, 0.145, len + 0.03),
					Color(0.17, 0.105, 0.058), Basis(Vector3.UP, yaw))
			z = z_next

	# Gunport sills / frames are added by _build_bulwarks; this is the
	# waterline rubbing strake seen from the side.
	z = -11.7
	while z < 12.5:
		var z_next := minf(z + 2.4, 12.5)
		for side: float in [1.0, -1.0]:
			var x := side * (_hull_x_at((z + z_next) * 0.5, 0.06) + 0.02)
			_box("hull_meet", Vector3(x, 0.055, (z + z_next) * 0.5),
				Vector3(0.08, 0.08, z_next - z - 0.05), Color(0.12, 0.085, 0.05))
		z = z_next

func _build_transom() -> void:
	# Curved stern: the hull sides close on a transom that rakes aft towards the top.
	var cols := 10
	var rows := 6
	for r: int in rows:
		var t0 := float(r) / float(rows)
		var t1 := float(r + 1) / float(rows)
		var y0 := lerpf(_keel_y(13.0), 3.70, t0)
		var y1 := lerpf(_keel_y(13.0), 3.70, t1)
		var z0 := lerpf(12.985, 13.045, t0)
		var z1 := lerpf(12.985, 13.045, t1)
		var w0 := _hull_x_at(13.0, y0)
		var w1 := _hull_x_at(13.0, y1)
		for c: int in cols:
			var u0 := -1.0 + 2.0 * float(c) / float(cols)
			var u1 := -1.0 + 2.0 * float(c + 1) / float(cols)
			var p00 := Vector3(u0 * w0, y0, z0)
			var p01 := Vector3(u1 * w0, y0, z0)
			var p11 := Vector3(u1 * w1, y1, z1)
			var p10 := Vector3(u0 * w1, y1, z1)
			var tone := _tone(HULL_TONES, c + r * 2 + (3 if r > 2 else 0))
			tone = _topsides_tone(tone, (y0 + y1) * 0.5)
			_quad("hull", p00, p10, p11, p01, tone, Vector3(0.0, 0.15, 1.0).normalized())
	# Wet waterline band across the stern, matching the sides.
	for c: int in 8:
		var u0 := -1.0 + 2.0 * float(c) / 8.0
		var u1 := -1.0 + 2.0 * float(c + 1) / 8.0
		var w := _hull_x_at(13.0, 0.15)
		var p00 := Vector3(u0 * w, 0.015, 13.074)
		var p01 := Vector3(u1 * w, 0.015, 13.074)
		var p11 := Vector3(u1 * w, WET_BAND_M, 13.078)
		var p10 := Vector3(u0 * w, WET_BAND_M, 13.078)
		_quad("wet", p00, p10, p11, p01, _waterline_tone(u0 * 3.0, 0.15), Vector3(0.0, 0.15, 1.0).normalized())
	# Transom trim, mouldings and the stern gallery window bank.
	for row: int in 3:
		var y := 1.86 + float(row) * 0.38
		_box("transom_dark", Vector3(0.0, y, 13.055),
			Vector3(minf(6.05, _hull_x_at(13.0, y) * 1.9), 0.10, 0.10), Color(0.18, 0.115, 0.065))
	for side: float in [-1.0, 1.0]:
		_box("transom_dark", Vector3(side * 2.92, 2.2, 13.06), Vector3(0.12, 2.9, 0.10),
			Color(0.20, 0.13, 0.072))
	# Three cabin windows with gold frames and warm glass.
	for i: int in 3:
		var x := lerpf(-1.72, 1.72, float(i) / 2.0)
		var z := 13.07
		_box("transom_glass", Vector3(x, 2.32, z + 0.02), Vector3(0.94, 0.72, 0.05),
			Color(1.0, 0.75, 0.42))
		_box("transom_gold", Vector3(x, 2.70, z + 0.03), Vector3(1.10, 0.09, 0.08), Color(1, 1, 1))
		_box("transom_gold", Vector3(x, 1.94, z + 0.03), Vector3(1.10, 0.09, 0.08), Color(1, 1, 1))
		_box("transom_gold", Vector3(x - 0.55, 2.32, z + 0.03), Vector3(0.09, 0.84, 0.08), Color(1, 1, 1))
		_box("transom_gold", Vector3(x + 0.55, 2.32, z + 0.03), Vector3(0.09, 0.84, 0.08), Color(1, 1, 1))
		_box("transom_dark", Vector3(x, 2.32, z + 0.055), Vector3(0.035, 0.66, 0.03), Color(0.16, 0.10, 0.055))
	# Gilded crest above the windows.
	_box("transom_velvet", Vector3(0.0, 3.14, 13.09), Vector3(1.15, 0.72, 0.08), Color(1, 1, 1))
	_box("transom_gold", Vector3(0.0, 3.54, 13.105), Vector3(1.35, 0.12, 0.10), Color(1, 1, 1))
	_box("transom_gold", Vector3(0.0, 2.74, 13.105), Vector3(1.35, 0.12, 0.10), Color(1, 1, 1))
	_box("transom_gold", Vector3(-0.63, 3.14, 13.105), Vector3(0.12, 0.86, 0.10), Color(1, 1, 1))
	_box("transom_gold", Vector3(0.63, 3.14, 13.105), Vector3(0.12, 0.86, 0.10), Color(1, 1, 1))
	_sphere("transom_gold", Vector3(0.0, 3.14, 13.145), 0.26, Color(1, 1, 1), 4, 8)
	# Brass nameplate under the crest: the ship reads as a named vessel even
	# without textured lettering.
	_box("transom_gold", Vector3(0.0, 2.90, 13.115), Vector3(1.08, 0.18, 0.025), Color(1, 1, 1))
	_box("transom_dark", Vector3(0.0, 2.90, 13.128), Vector3(0.88, 0.10, 0.018), Color(0.16, 0.10, 0.055))
	# Scroll brackets under the quarterdeck corners.
	for side: float in [-1.0, 1.0]:
		for i: int in 5:
			var a := -0.5 + float(i) * 0.24
			_box("transom_gold", Vector3(side * (1.55 + i * 0.24), 3.30 - 0.05 * i, 13.08),
				Vector3(0.20, 0.07, 0.10), Color(1, 1, 1), Basis(Vector3.FORWARD, a))
	# Rudder.
	_box("hull_meet", Vector3(0.0, -0.15, 13.24), Vector3(0.30, 3.5, 0.26), Color(0.19, 0.12, 0.067))
	for y: float in [-1.35, -0.35, 0.65, 1.35]:
		_box("iron", Vector3(0.0, y, 13.39), Vector3(0.22, 0.10, 0.08), Color(1, 1, 1))
	_tube("iron", Vector3(0.0, 1.40, 13.18), Vector3(0.0, 1.62, 12.55), 0.06, 0.05, 5, Color(1, 1, 1))

# ----------------------------------------------------------------------------- bulwarks
func _build_bulwarks() -> void:
	var breaks: Array[float] = []
	var z := -12.90
	while z < 12.951:
		breaks.append(z)
		z += 0.62
	breaks.append(12.95)
	breaks.append(6.0)
	for pz: float in PORT_Z:
		breaks.append(pz - PORT_HALF_WIDTH)
		breaks.append(pz + PORT_HALF_WIDTH)
	breaks.sort()
	for i: int in range(breaks.size() - 1):
		var z0: float = breaks[i]
		var z1: float = breaks[i + 1]
		if z1 - z0 < 0.02:
			continue
		var mid := (z0 + z1) * 0.5
		var opening := false
		for pz: float in PORT_Z:
			if absf(mid - pz) < PORT_HALF_WIDTH:
				opening = true
		for side: float in [1.0, -1.0]:
			_bulwark_panel(side, z0, z1, opening)
	_build_break_bulkhead()
	_build_gunport_frames()
	_build_quarter_gallery()
	_build_cap_rails()

func _build_cap_rails() -> void:
	# One continuous cap rail per side.  A per-panel box cap left visible dark
	# end faces along the sheer, which read as crenellations from the side.
	var stations: Array[float] = []
	var z := -12.9
	while z < 12.94:
		stations.append(z)
		z += 0.62
	stations.append(6.0)
	stations.append(12.95)
	for pz: float in PORT_Z:
		stations.append(pz - PORT_HALF_WIDTH)
		stations.append(pz + PORT_HALF_WIDTH)
	stations.sort()
	for side: float in [1.0, -1.0]:
		for i: int in range(stations.size() - 1):
			var za: float = stations[i]
			var zb: float = stations[i + 1]
			if zb - za < 0.02:
				continue
			if _hull_gunport_cut(za, zb, 2.0, 3.0):
				continue
			var ya := _rail_top(za) + 0.04
			var yb := _rail_top(zb) + 0.04
			var xoa := _hull_x_at(za, ya) + 0.015
			var xob := _hull_x_at(zb, yb) + 0.015
			var w := 0.30
			var xia := xoa - w
			var xib := xob - w
			var color := Color(0.275, 0.180, 0.098)
			# Top face.
			_quad("trim", Vector3(side * xoa, ya + 0.05, za), Vector3(side * xob, yb + 0.05, zb),
				Vector3(side * xib, yb + 0.05, zb), Vector3(side * xia, ya + 0.05, za), color, Vector3.UP)
			# Outer and inner faces.
			_quad("trim", Vector3(side * xoa, ya - 0.05, za), Vector3(side * xob, yb - 0.05, zb),
				Vector3(side * xob, yb + 0.05, zb), Vector3(side * xoa, ya + 0.05, za), color * 0.94,
				Vector3(side, 0.0, 0.0))
			_quad("trim", Vector3(side * xia, ya - 0.05, za), Vector3(side * xib, yb - 0.05, zb),
				Vector3(side * xib, yb + 0.05, zb), Vector3(side * xia, ya + 0.05, za), color * 0.82,
				Vector3(-side, 0.0, 0.0))
	# A gold rubbing strip on the outer top edge, quarterdeck only.
	for side: float in [1.0, -1.0]:
		for i: int in range(stations.size() - 1):
			var za: float = stations[i]
			var zb: float = stations[i + 1]
			if za < 6.1 or zb - za < 0.02:
				continue
			var ya := _rail_top(za) + 0.085
			var yb := _rail_top(zb) + 0.085
			var xa := _hull_x_at(za, ya) + 0.02
			var xb := _hull_x_at(zb, yb) + 0.02
			_quad("rails_gold", Vector3(side * xa, ya, za), Vector3(side * xb, yb, zb),
				Vector3(side * (xb - 0.10), yb, zb), Vector3(side * (xa - 0.10), ya, za),
				Color(1, 1, 1), Vector3.UP)

func _build_quarter_gallery() -> void:
	# Quarter gallery: warm cabin windows and gold pilasters on the tall
	# quarterdeck side.  Without them the stern reads as a plain brown block.
	for side: float in [1.0, -1.0]:
		for i: int in 2:
			var z := 8.75 + float(i) * 2.45
			var y := 2.42
			var x := side * (_hull_x_at(z, y) + 0.035)
			_box("transom_glass", Vector3(x, y, z), Vector3(0.05, 0.66, 0.98), Color(1, 1, 1))
			_box("transom_gold", Vector3(x + side * 0.01, y + 0.40, z), Vector3(0.09, 0.09, 1.12), Color(1, 1, 1))
			_box("transom_gold", Vector3(x + side * 0.01, y - 0.40, z), Vector3(0.09, 0.09, 1.12), Color(1, 1, 1))
			_box("transom_gold", Vector3(x + side * 0.01, y, z - 0.56), Vector3(0.09, 0.80, 0.09), Color(1, 1, 1))
			_box("transom_gold", Vector3(x + side * 0.01, y, z + 0.56), Vector3(0.09, 0.80, 0.09), Color(1, 1, 1))
			_box("transom_dark", Vector3(x + side * 0.03, y, z), Vector3(0.02, 0.60, 0.03), Color(0.16, 0.10, 0.055))
		for z: float in [7.35, 12.15]:
			var y := 2.55
			var x := side * (_hull_x_at(z, y) + 0.01)
			_box("transom_dark", Vector3(x, y, z), Vector3(0.10, 1.75, 0.16), Color(0.23, 0.15, 0.09))
			_box("transom_gold", Vector3(x + side * 0.01, 3.34, z), Vector3(0.12, 0.10, 0.22), Color(1, 1, 1))
		var x_mid := side * (_hull_x_at(9.7, 3.34) + 0.02)
		_box("transom_gold", Vector3(x_mid, 3.34, 9.7), Vector3(0.07, 0.07, 4.9), Color(1, 1, 1))
		# Stern quarter badge.
		_box("transom_gold", Vector3(side * (_hull_x_at(11.9, 3.05) + 0.03), 3.05, 11.9),
			Vector3(0.07, 0.34, 0.52), Color(1, 1, 1))
		_box("transom_velvet", Vector3(side * (_hull_x_at(11.9, 3.05) + 0.07), 3.05, 11.9),
			Vector3(0.03, 0.22, 0.38), Color(1, 1, 1))

func _bulwark_panel(side: float, z0: float, z1: float, opening: bool) -> void:
	var mid := (z0 + z1) * 0.5
	var deck := _deck_level(mid)
	var rail0 := _rail_top(z0) - 0.02
	var rail1 := _rail_top(z1) - 0.02
	var thickness := 0.15
	var y_sill := deck + 0.18
	var y_head := minf(deck + 0.95, minf(rail0, rail1) - 0.12)
	if mid >= 6.0:
		y_sill = deck + 0.34
		y_head = minf(deck + 0.64, minf(rail0, rail1) - 0.10)
	if opening:
		y_sill = PORT_BOTTOM
		y_head = PORT_TOP
	var bands := [[deck, y_sill], [y_sill, y_head], [y_head, minf(rail0, rail1)]]
	for bi: int in bands.size():
		if opening and bi == 1:
			continue
		var ya0: float = bands[bi][0]
		var ya1: float = bands[bi][1]
		if ya1 - ya0 < 0.02:
			continue
		# The panel follows the hull at each end, so a tapered bow reads correctly.
		var o00 := Vector3(side * _hull_x_at(z0, ya0), ya0, z0)
		var o01 := Vector3(side * _hull_x_at(z1, ya0), ya0, z1)
		var o11 := Vector3(side * _hull_x_at(z1, ya1), ya1, z1)
		var o10 := Vector3(side * _hull_x_at(z0, ya1), ya1, z0)
		var i00 := Vector3(side * (_hull_x_at(z0, ya0) - thickness), ya0, z0)
		var i01 := Vector3(side * (_hull_x_at(z1, ya0) - thickness), ya0, z1)
		var i11 := Vector3(side * (_hull_x_at(z1, ya1) - thickness), ya1, z1)
		var i10 := Vector3(side * (_hull_x_at(z0, ya1) - thickness), ya1, z0)
		var n_out := _hull_normal(side, mid, (ya0 + ya1) * 0.5)
		var n_in := -n_out
		var tone := _tone(DARK_WOOD, bi + int(z0 * 2.0) + (2 if side > 0.0 else 0))
		_quad("trim", o00, o10, o11, o01, tone, n_out)
		_quad("cabin_dark", i00, i10, i11, i01, tone * 0.92, n_in)
		# Top rail cap of every band closes the 15 cm sandwich.
		if bi == bands.size() - 1:
			_quad("trim", o10, i10, i11, o11, Color(0.24, 0.155, 0.085), Vector3(side, 0.0, 0.0))
	# Inner frames / ribs on the visible bulwark.
	if not opening and int((z0 + 12.9) / 1.24) != int((z1 + 12.9) / 1.24):
		var rib_h := _rail_top(mid) - deck - 0.06
		var rib_x := side * (_hull_x_at(mid, deck + 0.4) - thickness - 0.055)
		_box("cabin_dark", Vector3(rib_x, deck + rib_h * 0.5 + 0.02, mid),
			Vector3(0.075, rib_h, 0.105), _tone(DARK_WOOD, int((mid + 13.0) * 2.0)))
	# Cap rail is built as one continuous lofted strip below, not per panel.

func _build_break_bulkhead() -> void:
	# Front face of the quarterdeck / cabin top at z=6: two wall cheeks around
	# the 2.4 m doorway and a lintel above it.
	for side: float in [-1.0, 1.0]:
		var x0 := 1.2 if side > 0.0 else -3.34
		var x1 := 3.34 if side > 0.0 else -1.2
		var cx := (x0 + x1) * 0.5
		var w := absf(x1 - x0)
		_box("trim", Vector3(cx, 2.36, 6.0), Vector3(w, 1.22, 0.16), Color(0.27, 0.175, 0.098))
		for i: int in 3:
			var bx := lerpf(x0 + 0.25, x1 - 0.25, float(i) / 2.0)
			_box("trim", Vector3(bx, 2.36, 5.905), Vector3(0.09, 1.18, 0.03), Color(0.20, 0.13, 0.075))
	_box("trim", Vector3(0.0, 2.84, 6.0), Vector3(2.55, 0.22, 0.18), Color(0.25, 0.16, 0.09))
	# Door frame and the leaf folded flat against the bulkhead, clear of the
	# cabin interior: an open leaf used to stand in the middle of the doorway.
	for side: float in [-1.0, 1.0]:
		_box("gold", Vector3(side * 1.23, 1.63, 5.93), Vector3(0.10, 2.24, 0.12), Color(1, 1, 1))
	_box("gold", Vector3(0.0, 2.72, 5.93), Vector3(2.56, 0.10, 0.12), Color(1, 1, 1))
	_box("trim", Vector3(1.98, 1.62, 6.02), Vector3(1.02, 2.02, 0.06), Color(0.30, 0.19, 0.105),
		Basis(Vector3.UP, deg_to_rad(-92.0)))
	_box("iron", Vector3(1.98, 1.62, 6.10), Vector3(0.05, 0.20, 0.05), Color(1, 1, 1))
	# Outside stair cheeks on the starboard side (main deck -> quarterdeck).
	for x: float in [2.27, 3.18]:
		_box("trim", Vector3(x, 2.38, 5.70), Vector3(0.10, 0.72, 0.66),
			Color(0.22, 0.14, 0.08), Basis(Vector3.RIGHT, deg_to_rad(-18.0)))

func _build_gunport_frames() -> void:
	for pz: float in PORT_Z:
		for side: float in [1.0, -1.0]:
			var x_out := side * (_hull_x_at(pz, 2.15) + 0.01)
			var x_in := side * (_hull_x_at(pz, 2.15) + 0.10)
			# A real empty opening, shared with both skins, ribs and cap rail.
			# No dark backing plane: it would seal the gunner's sightline.
			var mid_y := (PORT_BOTTOM + PORT_TOP) * 0.5
			var height := PORT_TOP - PORT_BOTTOM + 0.20
			_box("trim", Vector3(x_in, PORT_TOP + 0.05, pz), Vector3(0.13, 0.10, 1.80), Color(0.25, 0.16, 0.09))
			_box("trim", Vector3(x_in, PORT_BOTTOM - 0.05, pz), Vector3(0.13, 0.10, 1.80), Color(0.25, 0.16, 0.09))
			_box("trim", Vector3(x_in, mid_y, pz - PORT_HALF_WIDTH - 0.05), Vector3(0.13, height, 0.10), Color(0.25, 0.16, 0.09))
			_box("trim", Vector3(x_in, mid_y, pz + PORT_HALF_WIDTH + 0.05), Vector3(0.13, height, 0.10), Color(0.25, 0.16, 0.09))
			var hinge := Vector3(x_out + side * 0.02, PORT_TOP + 0.05, pz)
			var lid := Basis(Vector3.RIGHT, 0.0) * Basis(Vector3.UP, 0.0) * Basis(Vector3.FORWARD, side * deg_to_rad(-74.0))
			_box("trim", hinge + Vector3(side * 0.16, 0.30, 0.0), Vector3(0.07, 0.88, 1.58),
				Color(0.24, 0.155, 0.085), lid)
			for plank_z: float in [-0.50, 0.0, 0.50]:
				_box("trim", hinge + Vector3(side * 0.20, 0.30, plank_z), Vector3(0.05, 0.84, 0.44),
					Color(0.28, 0.18, 0.10), lid)
			for strap_y: float in [-0.22, 0.22]:
				_box("iron", hinge + Vector3(side * 0.235, 0.30 + strap_y, 0.0),
					Vector3(0.035, 0.055, 1.52), Color(1, 1, 1), lid)
			_box("static_gold", hinge + Vector3(side * 0.245, 0.04, 0.0),
				Vector3(0.045, 0.13, 0.13), Color(1, 1, 1), lid)
			_box("iron", hinge, Vector3(0.09, 0.05, 1.58), Color(1, 1, 1))
	# Small decorative closed ports further along the side.
	for pz: float in [-9.3, -7.2, 1.1, 8.4, 10.8]:
		for side: float in [1.0, -1.0]:
			var y := 2.22 if pz < 6.0 else 3.20
			var x := side * (_hull_x_at(pz, y) + 0.015)
			_box("static_tar", Vector3(x - side * 0.05, y, pz), Vector3(0.05, 0.44, 0.62), Color(1, 1, 1))
			# Closed small port: a planked lid with iron straps and a ring.
			_box("trim", Vector3(x + side * 0.02, y, pz), Vector3(0.05, 0.40, 0.62),
				Color(0.24, 0.155, 0.085))
			for strap_y: float in [-0.12, 0.12]:
				_box("iron", Vector3(x + side * 0.055, y + strap_y, pz), Vector3(0.035, 0.045, 0.58),
					Color(1, 1, 1))
			_box("static_gold", Vector3(x + side * 0.07, y - 0.02, pz), Vector3(0.035, 0.12, 0.12),
				Color(1, 1, 1))
			_box("trim", Vector3(x + side * 0.015, y + 0.26, pz), Vector3(0.06, 0.07, 0.72), Color(0.21, 0.135, 0.08))
			_box("trim", Vector3(x + side * 0.015, y - 0.26, pz), Vector3(0.06, 0.07, 0.72), Color(0.21, 0.135, 0.08))
			_box("trim", Vector3(x + side * 0.015, y, pz - 0.33), Vector3(0.06, 0.52, 0.07), Color(0.21, 0.135, 0.08))
			_box("trim", Vector3(x + side * 0.015, y, pz + 0.33), Vector3(0.06, 0.52, 0.07), Color(0.21, 0.135, 0.08))

# ----------------------------------------------------------------------------- decks
func _build_decks() -> void:
	# Sub-decks first: dark timber that shows between the plank seams.  The main
	# sub-deck stops at the companionway opening; narrow strips run beside it.
	_deck_base(-12.85, COMPANION_Z0, 1.70, 0.30)
	for side: float in [-1.0, 1.0]:
		_deck_base_strip(COMPANION_Z0, 5.28, 1.70, 1.25, side)
		_deck_base_strip(5.28, 5.99, 1.70, 1.25, side)
	_deck_base(6.02, 12.44, 2.925, 0.24)
	_deck_base(-13.58, -11.82, 2.075, 0.0, true)
	# Main deck: individual planks, staggered lengths, a 2.4 m companionway hole.
	_deck_planks("deck", -12.8, 5.28, 1.78, 4.02, 0.455, DECK_TONES,
		Rect2(-1.2, COMPANION_Z0, 2.4, COMPANION_Z1 - COMPANION_Z0), true)
	# The narrow side decks beside the companionway opening.
	_deck_planks("deck", 5.28, 5.99, 1.78, 4.02, 0.455, DECK_TONES, Rect2(-1.24, 5.28, 2.48, 0.74), true)
	# Quarterdeck.
	_deck_planks("deck", 6.04, 12.44, 3.03, 3.38, 0.455, DECK_TONES, Rect2(), false)
	# Bow platform.
	_deck_planks("deck", -13.52, -11.86, 2.18, 2.18, 0.42, DECK_TONES, Rect2(), false)
	# Cabin floor.
	_deck_planks("cabin_wood", 6.06, 12.34, 0.52, 3.20, 0.40, CABIN_TONES, Rect2(), false)
	# King plank down the centre of the main deck (it stops at the companionway).
	_box("deck_dark", Vector3(0.0, 1.752, -4.08), Vector3(0.28, 0.075, 17.36), Color(0.30, 0.205, 0.12))
	# Waterways: dark gutters where the deck meets the bulwark.
	for z0: float in [-12.4, -9.2, -6.0, -2.8, 0.4, 3.6]:
		var z1 := minf(z0 + 3.2, 5.3)
		for side: float in [-1.0, 1.0]:
			var x := side * (_hull_x_at((z0 + z1) * 0.5, 1.80) - 0.16)
			_box("deck_dark", Vector3(x, 1.775, (z0 + z1) * 0.5),
				Vector3(0.19, 0.06, z1 - z0), Color(0.22, 0.145, 0.085))
	for z0: float in [6.3, 9.3, 12.0]:
		var z1 := minf(z0 + 2.9, 12.44)
		for side: float in [-1.0, 1.0]:
			var x := side * (_hull_x_at((z0 + z1) * 0.5, 3.05) - 0.14)
			_box("deck_dark", Vector3(x, 3.028, (z0 + z1) * 0.5),
				Vector3(0.17, 0.05, z1 - z0), Color(0.22, 0.145, 0.085))

	# Companionway coaming and the six steps down into the cabin.  The opening runs
	# from COMPANION_Z0 to the door so a 1.9 m character is already low enough when
	# he passes under the quarterdeck slab.
	for side: float in [-1.0, 1.0]:
		_box("trim", Vector3(side * 1.35, 1.99, 5.31), Vector3(0.16, 0.44, 1.40), Color(0.26, 0.17, 0.095))
		_box("cabin_dark", Vector3(side * 1.30, 1.10, 5.32), Vector3(0.20, 1.30, 1.36), Color(0.20, 0.13, 0.075))
	_box("trim", Vector3(0.0, 1.80, COMPANION_Z0), Vector3(2.80, 0.08, 0.16), Color(0.26, 0.17, 0.095))
	_box("cabin_dark", Vector3(0.0, 1.05, COMPANION_Z0 + 0.03), Vector3(2.68, 1.40, 0.14), Color(0.18, 0.115, 0.065))
	var step_tops := STEP_TOPS
	for i: int in step_tops.size():
		var top: float = step_tops[i]
		var z := STEP_BASE_Z + float(i) * STEP_PITCH
		_box("trim", Vector3(0.0, top - 0.055, z), Vector3(2.32, 0.11, 0.34), Color(0.31, 0.205, 0.115))
		_box("cabin_dark", Vector3(0.0, top - 0.20, z), Vector3(2.24, 0.21, 0.14), Color(0.20, 0.13, 0.075))
	# Rope handrail along the companionway (starboard side).
	_box("iron", Vector3(1.52, 2.06, COMPANION_Z0 + 0.05), Vector3(0.07, 0.62, 0.07), Color(1, 1, 1))
	_box("iron", Vector3(1.52, 1.52, 6.02), Vector3(0.07, 0.62, 0.07), Color(1, 1, 1))
	_tube("rope", Vector3(1.52, 2.35, COMPANION_Z0 + 0.05), Vector3(1.52, 1.82, 6.02), 0.028, 0.028, 4, Color(1, 1, 1), false)

	# Stairs from the main deck up to the quarterdeck, both sides.
	var q_tops := [2.17, 2.59, 3.01]
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			var z := 5.40 + float(i) * 0.25
			_box("trim", Vector3(side * 2.72, q_tops[i] - 0.06, z), Vector3(0.96, 0.12, 0.30), Color(0.30, 0.20, 0.11))
			_box("cabin_dark", Vector3(side * 2.72, q_tops[i] - 0.26, z), Vector3(0.92, 0.26, 0.14), Color(0.20, 0.13, 0.075))
		_box("trim", Vector3(side * 3.24, 2.55, 5.62), Vector3(0.10, 1.40, 0.10), Color(0.24, 0.155, 0.088),
			Basis(Vector3.RIGHT, deg_to_rad(-20.0)))
		_tube("rope", Vector3(side * 3.24, 3.22, 5.36), Vector3(side * 3.24, 2.60, 6.16), 0.03, 0.03, 4, Color(1, 1, 1), false)

	# Bow-platform steps.
	_box("trim", Vector3(0.0, 1.94, -11.72), Vector3(2.6, 0.12, 0.34), Color(0.30, 0.20, 0.11))
	_box("trim", Vector3(0.0, 2.08, -12.06), Vector3(2.6, 0.12, 0.34), Color(0.30, 0.20, 0.11))

	# Two cargo hatches with gratings.
	_hatch(Vector3(-2.30, 1.80, -2.60), 1.25, 1.55)
	_hatch(Vector3(2.35, 1.80, -7.90), 1.15, 1.40)
	_hatch(Vector3(1.10, 3.05, 8.70), 0.95, 1.05)

func _deck_base(z_from: float, z_to: float, y: float, inset: float, fixed_width: bool = false) -> void:
	var stations: Array[float] = [z_from]
	var z := z_from
	while z < z_to - 0.01:
		z = minf(z + 0.8, z_to)
		stations.append(z)
	for i: int in range(stations.size() - 1):
		var z0: float = stations[i]
		var z1: float = stations[i + 1]
		var mid := (z0 + z1) * 0.5
		var w0 := 3.72 if fixed_width else maxf(0.2, _hull_x_at(z0, y + 0.04) - inset)
		var w1 := 3.72 if fixed_width else maxf(0.2, _hull_x_at(z1, y + 0.04) - inset)
		_quad("deck_dark", Vector3(-w0, y, z0), Vector3(-w1, y, z1),
			Vector3(w1, y, z1), Vector3(w0, y, z0), Color(0.19, 0.125, 0.072), Vector3.UP)

func _deck_base_strip(z_from: float, z_to: float, y: float, inner: float, side: float) -> void:
	var stations: Array[float] = [z_from]
	var z := z_from
	while z < z_to - 0.01:
		z = minf(z + 0.35, z_to)
		stations.append(z)
	for i: int in range(stations.size() - 1):
		var z0: float = stations[i]
		var z1: float = stations[i + 1]
		var w0 := maxf(inner + 0.05, _hull_x_at(z0, y + 0.04) - 0.28)
		var w1 := maxf(inner + 0.05, _hull_x_at(z1, y + 0.04) - 0.28)
		_quad("deck_dark", Vector3(side * inner, y, z0), Vector3(side * inner, y, z1),
			Vector3(side * w1, y, z1), Vector3(side * w0, y, z0), Color(0.19, 0.125, 0.072), Vector3.UP)

func _deck_planks(key: String, z_from: float, z_to: float, y_top: float, x_limit: float,
		plank_w: float, tones: Array, hole: Rect2, check_hull: bool) -> void:
	var rows := int(floor((x_limit * 2.0) / plank_w))
	var first := -x_limit + plank_w * 0.5
	for row: int in rows:
		var cx := first + float(row) * plank_w
		if absf(cx) > x_limit - 0.08:
			continue
		var intervals: Array = [[z_from, z_to]]
		if hole.size.x > 0.0 and absf(cx) < hole.size.x * 0.5:
			var cut: Array = []
			var hz0 := hole.position.y
			var hz1 := hole.position.y + hole.size.y
			for iv: Array in intervals:
				var a: float = iv[0]
				var b: float = iv[1]
				if b <= hz0 or a >= hz1:
					cut.append([a, b])
				else:
					if a < hz0:
						cut.append([a, hz0])
					if b > hz1:
						cut.append([hz1, b])
			intervals = cut
		for iv: Array in intervals:
			var z := float(iv[0])
			var z_end := float(iv[1])
			while z < z_end - 0.01:
				var z1 := minf(z + 2.35, z_end)
				var mz := (z + z1) * 0.5
				var reach := 3.9 if not check_hull else _hull_x_at(mz, y_top - 0.01) - 0.22
				if absf(cx) <= reach and z1 - z > 0.16:
					var tone := _tone(tones, row * 5 + int((z + 13.0) * 0.7))
					tone = tone * (0.94 + 0.12 * _hash01(row, int(z * 7.0), 3))
					_box(key, Vector3(cx, y_top - 0.017, mz), Vector3(plank_w - 0.010, 0.034, z1 - z - 0.008), tone)
				z = z1

func _hatch(at: Vector3, width: float, length: float) -> void:
	var y := at.y + 0.005
	_box("static_tar", at + Vector3(0.0, 0.0, 0.0), Vector3(width - 0.10, 0.06, length - 0.10), Color(1, 1, 1))
	# Frame.
	_box("trim", at + Vector3(0.0, 0.06, -length * 0.5), Vector3(width, 0.13, 0.12), Color(0.27, 0.18, 0.10))
	_box("trim", at + Vector3(0.0, 0.06, length * 0.5), Vector3(width, 0.13, 0.12), Color(0.27, 0.18, 0.10))
	_box("trim", at + Vector3(-width * 0.5, 0.06, 0.0), Vector3(0.12, 0.13, length), Color(0.27, 0.18, 0.10))
	_box("trim", at + Vector3(width * 0.5, 0.06, 0.0), Vector3(0.12, 0.13, length), Color(0.27, 0.18, 0.10))
	# Grating slats.
	var count := int(length / 0.16)
	for i: int in count:
		var z := -length * 0.5 + 0.10 + float(i) * 0.155
		_box("static_tar", at + Vector3(0.0, 0.075, z), Vector3(width - 0.20, 0.055, 0.075), Color(1, 1, 1))
	for i: int in int(width / 0.20):
		var x := -width * 0.5 + 0.12 + float(i) * 0.20
		_box("deck_dark", at + Vector3(x, 0.095, 0.0), Vector3(0.055, 0.04, length - 0.18), Color(0.25, 0.16, 0.09))

# ----------------------------------------------------------------------------- cabin
func _build_cabin() -> void:
	var floor_y := CABIN_FLOOR_Y + 0.02
	# Side walls: horizontal cabin boards with vertical frames.
	for side: float in [-1.0, 1.0]:
		var x := side * 3.26
		for i: int in 14:
			var y := 0.62 + float(i) * 0.165
			_box("cabin_wood", Vector3(x, y, 9.2), Vector3(0.06, 0.158, 6.26),
				_tone(CABIN_TONES, i + (4 if side > 0.0 else 0)))
		for i: int in 5:
			var z := 6.25 + float(i) * 1.52
			_box("cabin_dark", Vector3(x - side * 0.045, 1.72, z), Vector3(0.09, 2.32, 0.13),
				Color(0.23, 0.15, 0.085))
	# Front bulkhead (door opening x ±1.2).
	for side: float in [-1.0, 1.0]:
		var x0 := 1.2 if side > 0.0 else -3.3
		var x1 := 3.3 if side > 0.0 else -1.2
		var cx := (x0 + x1) * 0.5
		var w := absf(x1 - x0)
		_box("cabin_wood", Vector3(cx, 1.72, 6.06), Vector3(w, 2.40, 0.10), Color(0.40, 0.27, 0.16))
		for i: int in 4:
			var bx := lerpf(x0 + 0.2, x1 - 0.2, float(i) / 3.0)
			_box("cabin_dark", Vector3(bx, 1.72, 6.115), Vector3(0.08, 2.34, 0.04), Color(0.22, 0.14, 0.08))
	_box("cabin_wood", Vector3(0.0, 2.84, 6.06), Vector3(2.42, 0.24, 0.10), Color(0.38, 0.255, 0.15))
	_box("gold", Vector3(0.0, 2.73, 6.13), Vector3(2.50, 0.07, 0.07), Color(1, 1, 1))
	# Rear wall with three warm windows.
	_box("cabin_wood", Vector3(0.0, 1.72, 12.36), Vector3(6.48, 2.46, 0.10), Color(0.36, 0.24, 0.14))
	for i: int in 3:
		var x := lerpf(-1.72, 1.72, float(i) / 2.0)
		_box("cabin_glass", Vector3(x, 2.28, 12.30), Vector3(0.92, 0.70, 0.05), Color(1, 1, 1))
		_box("gold", Vector3(x, 2.66, 12.31), Vector3(1.04, 0.07, 0.06), Color(1, 1, 1))
		_box("gold", Vector3(x, 1.90, 12.31), Vector3(1.04, 0.07, 0.06), Color(1, 1, 1))
		_box("gold", Vector3(x - 0.50, 2.28, 12.31), Vector3(0.07, 0.80, 0.06), Color(1, 1, 1))
		_box("gold", Vector3(x + 0.50, 2.28, 12.31), Vector3(0.07, 0.80, 0.06), Color(1, 1, 1))
	# Painted ceiling with heavy deck beams; the underside of the quarterdeck.
	_box("cabin_paint", Vector3(0.0, 2.905, 9.2), Vector3(6.44, 0.06, 6.28), Color(1, 1, 1))
	for i: int in 6:
		var z := 6.32 + float(i) * 1.20
		_box("cabin_dark", Vector3(0.0, 2.86, z), Vector3(6.46, 0.16, 0.20), Color(0.24, 0.155, 0.088))
	# Rear wall shelf and a small stern locker.
	_box("cabin_wood", Vector3(0.0, 1.52, 12.18), Vector3(3.5, 0.07, 0.34), Color(0.35, 0.23, 0.135))
	_box("cabin_dark", Vector3(-1.5, 1.62, 12.16), Vector3(0.16, 0.24, 0.22), Color(0.22, 0.14, 0.08))
	_box("gold", Vector3(-1.5, 1.74, 12.16), Vector3(0.18, 0.04, 0.24), Color(1, 1, 1))
	_box("cabin_glass", Vector3(0.2, 1.64, 12.16), Vector3(0.12, 0.26, 0.12), Color(1, 1, 1))
	_box("cabin_glass", Vector3(0.6, 1.60, 12.16), Vector3(0.10, 0.20, 0.10), Color(1, 1, 1))

	# Rug and the captain's table.
	_box("velvet", Vector3(0.0, floor_y + 0.012, 8.95), Vector3(3.0, 0.025, 2.3), Color(1, 1, 1))
	_box("velvet", Vector3(0.0, floor_y + 0.02, 8.95), Vector3(2.7, 0.02, 2.0), Color(0.74, 0.56, 0.26))
	var table_top := 1.02
	_box("cabin_wood", Vector3(0.0, table_top, 8.95), Vector3(1.85, 0.10, 1.15), Color(0.56, 0.42, 0.28))
	_box("trim", Vector3(0.0, table_top + 0.055, 8.95), Vector3(1.98, 0.05, 1.26), Color(0.38, 0.27, 0.17))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box("cabin_dark", Vector3(sx * 0.76, 0.77, 8.95 + sz * 0.42), Vector3(0.12, 0.50, 0.12), Color(0.24, 0.155, 0.09))
	# Chart, dividers, compass, bottle.
	_box("cabin_paper", Vector3(-0.12, table_top + 0.09, 8.90), Vector3(0.82, 0.02, 0.60), Color(1, 1, 1),
		Basis(Vector3.UP, deg_to_rad(7.0)))
	for i: int in 4:
		_box("cabin_dark", Vector3(-0.42 + i * 0.2, table_top + 0.102, 8.75 + i * 0.06), Vector3(0.17, 0.006, 0.012), Color(0.30, 0.24, 0.16))
	_box("gold", Vector3(0.62, table_top + 0.10, 8.55), Vector3(0.10, 0.04, 0.10), Color(1, 1, 1))
	_box("iron", Vector3(0.42, table_top + 0.13, 9.22), Vector3(0.20, 0.02, 0.02), Color(1, 1, 1),
		Basis(Vector3.UP, deg_to_rad(35.0)))
	_box("cabin_glass", Vector3(-0.68, table_top + 0.20, 9.22), Vector3(0.11, 0.30, 0.11), Color(1, 1, 1))
	_box("cabin_dark", Vector3(-0.68, table_top + 0.36, 9.22), Vector3(0.055, 0.10, 0.055), Color(0.24, 0.16, 0.09))
	# Two chairs.
	for side: float in [-1.0, 1.0]:
		var cx := side * 1.45
		_box("cabin_wood", Vector3(cx, 0.78, 8.95), Vector3(0.52, 0.07, 0.52), Color(0.38, 0.255, 0.15))
		_box("cabin_wood", Vector3(cx, 1.22, 8.95 + 0.24), Vector3(0.52, 0.80, 0.07), Color(0.36, 0.24, 0.14))
		for lx: float in [-0.20, 0.20]:
			for lz: float in [-0.20, 0.20]:
				_box("cabin_dark", Vector3(cx + lx, 0.64, 8.95 + lz), Vector3(0.06, 0.34, 0.06), Color(0.22, 0.14, 0.08))
	# Hanging lantern over the chart table, shifted to port so it never sits in
	# the middle of the companionway view.
	_tube("iron", Vector3(-1.90, 2.90, 8.95), Vector3(-1.90, 2.48, 8.95), 0.02, 0.02, 4, Color(1, 1, 1), false)
	_box("iron", Vector3(-1.90, 2.44, 8.95), Vector3(0.20, 0.06, 0.20), Color(1, 1, 1))
	_box("static_lamp", Vector3(-1.90, 2.28, 8.95), Vector3(0.15, 0.28, 0.15), Color(1, 1, 1))
	_box("gold", Vector3(-1.90, 2.11, 8.95), Vector3(0.19, 0.05, 0.19), Color(1, 1, 1))
	var cabin_light := OmniLight3D.new()
	cabin_light.position = Vector3(-1.90, 2.24, 8.95)
	cabin_light.light_color = Color(1.0, 0.72, 0.40)
	cabin_light.light_energy = 2.1
	cabin_light.omni_range = 5.2
	cabin_light.shadow_enabled = false
	_cabin_light = cabin_light
	_visual.add_child(cabin_light)
	# Daylight through the three stern windows, plus a little spill from the
	# open door.  A sealed wooden box with one lantern reads as a cave.
	var stern_light := OmniLight3D.new()
	stern_light.position = Vector3(0.0, 2.22, 12.02)
	stern_light.light_color = Color(1.0, 0.68, 0.36)
	stern_light.light_energy = 1.45
	stern_light.omni_range = 4.4
	stern_light.shadow_enabled = false
	_visual.add_child(stern_light)
	var door_light := OmniLight3D.new()
	door_light.position = Vector3(0.0, 1.55, 6.35)
	door_light.light_color = Color(0.82, 0.86, 0.95)
	door_light.light_energy = 0.55
	door_light.omni_range = 3.2
	door_light.shadow_enabled = false
	_visual.add_child(door_light)
	# Framed chart, mirror and a sword give the cabin some lived-in detail.
	_box("cabin_paper", Vector3(3.21, 1.98, 8.20), Vector3(0.03, 0.62, 0.92), Color(1, 1, 1))
	_box("gold", Vector3(3.19, 2.32, 8.20), Vector3(0.04, 0.05, 1.02), Color(1, 1, 1))
	_box("gold", Vector3(3.19, 1.64, 8.20), Vector3(0.04, 0.05, 1.02), Color(1, 1, 1))
	_box("gold", Vector3(3.19, 1.98, 7.72), Vector3(0.04, 0.72, 0.05), Color(1, 1, 1))
	_box("gold", Vector3(3.19, 1.98, 8.68), Vector3(0.04, 0.72, 0.05), Color(1, 1, 1))
	for i: int in 4:
		_box("cabin_dark", Vector3(3.17, 2.10 - float(i) * 0.12, 8.10 + float(i) * 0.06),
			Vector3(0.02, 0.008, 0.44), Color(0.30, 0.24, 0.16))
	_box("gold", Vector3(-3.19, 2.02, 10.55), Vector3(0.04, 0.92, 0.72), Color(1, 1, 1))
	_box("cabin_glass", Vector3(-3.17, 2.02, 10.55), Vector3(0.02, 0.78, 0.58), Color(1, 1, 1))
	_box("iron", Vector3(-3.14, 1.48, 11.30), Vector3(0.03, 0.92, 0.07), Color(1, 1, 1),
		Basis(Vector3.BACK, deg_to_rad(-12.0)))
	_box("gold", Vector3(-3.14, 1.98, 11.30), Vector3(0.06, 0.16, 0.26), Color(1, 1, 1))
	_box("cabin_dark", Vector3(-3.14, 1.32, 11.36), Vector3(0.05, 0.12, 0.34), Color(0.24, 0.16, 0.09))
	# A small arms rack and a sea chest along the port wall.
	_box("cabin_dark", Vector3(-2.72, 1.18, 8.55), Vector3(0.22, 1.18, 1.60), Color(0.24, 0.155, 0.09))
	for i: int in 4:
		_box("iron", Vector3(-2.58, 1.52, 8.05 + i * 0.33), Vector3(0.05, 0.52, 0.05), Color(1, 1, 1),
			Basis(Vector3.FORWARD, deg_to_rad(12.0)))
	_box("cabin_wood", Vector3(2.72, 0.78, 7.40), Vector3(0.60, 0.52, 1.30), Color(0.37, 0.245, 0.15))
	_box("iron", Vector3(2.72, 1.04, 7.40), Vector3(0.64, 0.07, 1.34), Color(1, 1, 1))
	_box("gold", Vector3(2.44, 0.78, 7.40), Vector3(0.04, 0.16, 0.18), Color(1, 1, 1))
	# The two contract crates: shot and boards.
	_crate(_crate_ammo, "crate_ammo", true)
	_crate(_crate_boards, "crate_boards", false)

var _cabin_light: OmniLight3D

func _crate(node: Node3D, part_id: String, ammo: bool) -> void:
	var key_wood := part_id + "_wood"
	var key_iron := part_id + "_iron"
	# Crate body centred on the anchor; bottom sits on the cabin floor.
	# Geometry is in the crate node's local space (the batch is parented to it).
	for i: int in 9:
		var y := -0.41 + float(i) * 0.105
		_box(key_wood, Vector3(0.0, y, 0.515), Vector3(1.36, 0.098, 0.04),
			_tone(CABIN_TONES, i + 1))
	for side: float in [-1.0, 1.0]:
		_box(key_wood, Vector3(side * 0.69, 0.02, 0.0), Vector3(0.03, 0.86, 1.00),
			_tone(CABIN_TONES, 2 if side > 0.0 else 4) * 0.86)
		for i: int in 3:
			_box(key_wood, Vector3(side * 0.70, -0.26 + float(i) * 0.28, 0.0),
				Vector3(0.02, 0.24, 0.92), _tone(CABIN_TONES, i + (3 if side > 0.0 else 0)) * 0.80)
	_box(key_wood, Vector3(0.0, 0.462, 0.0), Vector3(1.30, 0.06, 0.94), Color(0.34, 0.225, 0.135))
	_box(key_wood, Vector3(0.0, -0.455, 0.0), Vector3(1.30, 0.06, 0.94), Color(0.30, 0.20, 0.12))
	for zs: float in [-0.37, 0.37]:
		_box(key_iron, Vector3(0.0, 0.0, zs), Vector3(1.44, 0.94, 0.07), Color(1, 1, 1))
	for xs: float in [-0.63, 0.63]:
		_box(key_iron, Vector3(xs, 0.0, 0.0), Vector3(0.06, 0.94, 1.04), Color(1, 1, 1))
	for i: int in 4:
		_box(key_iron, Vector3(-0.66 + float(i) * 0.44, 0.475, 0.0), Vector3(0.07, 0.05, 0.28), Color(1, 1, 1))
	# A rope handle on each end.
	for zs: float in [-1.0, 1.0]:
		_tube("rope", Vector3(0.0, 0.20, zs * 0.54), Vector3(0.0, -0.16, zs * 0.54),
			0.03, 0.03, 4, Color(1, 1, 1), false)
	if ammo:
		# Open lid with shot visible, so the crate reads as ammunition.
		_box(key_wood, Vector3(0.0, 0.54, -0.40), Vector3(1.36, 0.05, 0.70), Color(0.34, 0.225, 0.135),
			Basis(Vector3.RIGHT, deg_to_rad(-58.0)))
		for i: int in 5:
			_sphere(key_iron, Vector3(-0.42 + float(i % 3) * 0.42, 0.49, -0.18 + float(i / 3) * 0.34),
				0.13, Color(0.28, 0.28, 0.30), 4, 7)
	else:
		for i: int in 4:
			_box(key_wood, Vector3(-0.45 + float(i) * 0.30, 0.50 + float(i % 2) * 0.06, 0.0),
				Vector3(0.27, 0.05, 0.86), Color(0.52, 0.40, 0.27), Basis(Vector3.UP, deg_to_rad(-4.0 + float(i) * 3.0)))

# ----------------------------------------------------------------------------- deck furniture
func _build_deck_furniture() -> void:
	# Capstan.
	var cy := DECK_Y + 0.03
	_tube("cabin_wood", Vector3(0.0, cy, 3.55), Vector3(0.0, cy + 0.52, 3.55), 0.34, 0.28, 12, Color(0.34, 0.225, 0.135))
	_tube("iron", Vector3(0.0, cy + 0.52, 3.55), Vector3(0.0, cy + 0.60, 3.55), 0.32, 0.20, 12, Color(1, 1, 1))
	for i: int in 8:
		var a := TAU * float(i) / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		_box("trim", Vector3(0.0, cy + 0.34, 3.55) + dir * 0.38, Vector3(0.13, 0.52, 0.13),
			Color(0.29, 0.19, 0.105), Basis(Vector3.UP, -a))
		_box("iron", Vector3(0.0, cy + 0.58, 3.55) + dir * 0.38, Vector3(0.16, 0.06, 0.16), Color(1, 1, 1))
	_ring("rope", Vector3(0.0, cy + 0.20, 3.55), Vector3.UP, 0.35, 0.045, 12, Color(1, 1, 1))

	# Barrels.
	_barrel(Vector3(-2.72, DECK_Y + 0.02, 1.35), 0.30, 0.86)
	_barrel(Vector3(2.78, DECK_Y + 0.02, -2.15), 0.28, 0.80)
	_barrel(Vector3(-2.85, DECK_Y + 0.02, -8.10), 0.29, 0.84)
	_barrel(Vector3(2.62, DECK_Y + 0.02, 4.60), 0.26, 0.76)
	_barrel(Vector3(2.66, QUARTER_Y + 0.03, 7.30), 0.25, 0.72)
	_barrel(Vector3(-2.55, QUARTER_Y + 0.03, 11.55), 0.24, 0.70)
	# A crate and a coiled cable on the quarterdeck.
	_box("cabin_wood", Vector3(-2.90, QUARTER_Y + 0.36, 7.10), Vector3(0.86, 0.72, 0.78), Color(0.38, 0.255, 0.15))
	_box("iron", Vector3(-2.90, QUARTER_Y + 0.36, 7.10), Vector3(0.90, 0.08, 0.82), Color(1, 1, 1))
	_ring("rope", Vector3(2.35, QUARTER_Y + 0.06, 11.70), Vector3.UP, 0.32, 0.055, 12, Color(1, 1, 1))
	_ring("rope", Vector3(2.35, QUARTER_Y + 0.12, 11.70), Vector3.UP, 0.24, 0.045, 12, Color(0.92, 0.85, 0.7))

	# Coils and buckets on the main deck.
	_ring("rope", Vector3(-1.45, DECK_Y + 0.06, 2.80), Vector3.UP, 0.34, 0.055, 12, Color(1, 1, 1))
	_ring("rope", Vector3(-1.45, DECK_Y + 0.13, 2.80), Vector3.UP, 0.25, 0.045, 12, Color(0.9, 0.84, 0.7))
	_ring("rope", Vector3(1.75, DECK_Y + 0.06, 0.65), Vector3.UP, 0.27, 0.05, 12, Color(1, 1, 1))
	_bucket(Vector3(1.65, DECK_Y + 0.02, -5.55))
	_bucket(Vector3(-2.20, DECK_Y + 0.02, -4.80))
	# A little more cargo in the waist so the deck does not read as an empty stage.
	_box("cabin_wood", Vector3(2.68, DECK_Y + 0.38, -6.35), Vector3(0.84, 0.74, 0.82), Color(0.38, 0.255, 0.15))
	_box("iron", Vector3(2.68, DECK_Y + 0.38, -6.35), Vector3(0.88, 0.08, 0.86), Color(1, 1, 1))
	_box("iron", Vector3(2.68, DECK_Y + 0.38, -6.72), Vector3(0.88, 0.70, 0.05), Color(1, 1, 1))
	_box("cabin_wood", Vector3(-2.24, DECK_Y + 0.33, -9.55), Vector3(0.78, 0.64, 0.74), Color(0.36, 0.24, 0.145))
	_box("iron", Vector3(-2.24, DECK_Y + 0.33, -9.55), Vector3(0.82, 0.07, 0.78), Color(1, 1, 1))
	_ring("rope", Vector3(-2.55, DECK_Y + 0.06, 4.42), Vector3.UP, 0.30, 0.05, 12, Color(1, 1, 1))
	_ring("rope", Vector3(-2.55, DECK_Y + 0.12, 4.42), Vector3.UP, 0.21, 0.04, 12, Color(0.9, 0.84, 0.7))
	_barrel(Vector3(1.78, DECK_Y + 0.02, 4.95), 0.24, 0.68)

	# Belaying pins along the inside of the bulwark.
	for side: float in [-1.0, 1.0]:
		for i: int in 7:
			var z := -3.6 + float(i) * 0.62
			var x := side * (_hull_x_at(z, 2.20) - 0.26)
			_box("trim", Vector3(x, 2.26, z), Vector3(0.06, 0.30, 0.06), Color(0.31, 0.22, 0.14))
			_box("rope", Vector3(x, 2.36, z), Vector3(0.09, 0.04, 0.09), Color(0.68, 0.60, 0.42))

	# Fife rail around the mast.
	for side: float in [-1.0, 1.0]:
		_box("trim", Vector3(side * 0.95, DECK_Y + 0.52, 0.15), Vector3(0.12, 0.12, 2.90), Color(0.28, 0.18, 0.10))
		for i: int in 3:
			_box("trim", Vector3(side * 0.95, DECK_Y + 0.26, -0.95 + float(i) * 1.05), Vector3(0.10, 0.52, 0.10), Color(0.24, 0.155, 0.09))
		for i: int in 6:
			_box("rope", Vector3(side * 0.95, DECK_Y + 0.61, -1.05 + float(i) * 0.44), Vector3(0.07, 0.10, 0.07), Color(0.62, 0.54, 0.36))

	# Ship's bell on a small frame near the break.
	_box("trim", Vector3(-2.50, DECK_Y + 0.55, 4.85), Vector3(0.16, 1.10, 0.16), Color(0.25, 0.16, 0.09))
	_box("trim", Vector3(-2.10, DECK_Y + 1.02, 4.85), Vector3(0.95, 0.12, 0.14), Color(0.25, 0.16, 0.09))
	_tube("gold", Vector3(-1.72, DECK_Y + 1.02, 4.85), Vector3(-1.72, DECK_Y + 0.90, 4.85), 0.08, 0.15, 8, Color(1, 1, 1))
	_sphere("gold", Vector3(-1.72, DECK_Y + 0.88, 4.85), 0.05, Color(1, 1, 1), 3, 6)

	# Spare yards and a small boat's oar lashed along the waist.
	_tube("trim", Vector3(-3.15, 2.02, -9.4), Vector3(-3.15, 1.90, -6.2), 0.075, 0.065, 6, Color(0.33, 0.22, 0.13))
	_tube("trim", Vector3(3.10, 2.00, 1.2), Vector3(3.10, 1.88, 4.2), 0.075, 0.065, 6, Color(0.33, 0.22, 0.13))

	# Bowsprit gammoning and a pair of anchors stowed on the starboard bow.
	_tube("iron", Vector3(2.20, 1.55, -12.10), Vector3(2.20, 2.10, -12.10), 0.05, 0.05, 5, Color(1, 1, 1))
	_tube("iron", Vector3(2.20, 2.55, -12.10), Vector3(2.84, 2.10, -12.10), 0.05, 0.05, 5, Color(1, 1, 1))
	_tube("iron", Vector3(2.20, 2.55, -12.10), Vector3(1.60, 2.10, -12.10), 0.05, 0.05, 5, Color(1, 1, 1))
	_box("trim", Vector3(2.20, 2.30, -12.10), Vector3(0.12, 1.10, 0.12), Color(0.28, 0.18, 0.10))

func _barrel(at: Vector3, radius: float, height: float) -> void:
	var base := at
	var top := at + Vector3(0.0, height, 0.0)
	_tube("cabin_wood", base, top, radius * 0.86, radius * 0.86, 12, Color(0.40, 0.27, 0.16))
	_tube("cabin_wood", base + Vector3(0.0, 0.03, 0.0), base + Vector3(0.0, height * 0.5, 0.0),
		radius, radius, 12, Color(0.40, 0.27, 0.16))
	_tube("cabin_wood", base + Vector3(0.0, height * 0.5, 0.0), top - Vector3(0.0, 0.03, 0.0),
		radius, radius * 0.86, 12, Color(0.40, 0.27, 0.16))
	for t: float in [0.08, 0.42, 0.92]:
		_ring("iron", base + Vector3(0.0, height * t, 0.0), Vector3.UP, radius * 0.92, 0.022, 12, Color(1, 1, 1))
	_tube("cabin_dark", top, top + Vector3(0.0, 0.02, 0.0), radius * 0.80, radius * 0.80, 12, Color(0.30, 0.20, 0.12))

func _bucket(at: Vector3) -> void:
	_tube("cabin_wood", at, at + Vector3(0.0, 0.30, 0.0), 0.13, 0.17, 10, Color(0.36, 0.245, 0.145))
	_ring("iron", at + Vector3(0.0, 0.29, 0.0), Vector3.UP, 0.165, 0.012, 10, Color(1, 1, 1))
	_tube("rope", at + Vector3(-0.17, 0.30, 0.0), at + Vector3(0.0, 0.46, 0.0), 0.012, 0.012, 4, Color(1, 1, 1), false)
	_tube("rope", at + Vector3(0.17, 0.30, 0.0), at + Vector3(0.0, 0.46, 0.0), 0.012, 0.012, 4, Color(1, 1, 1), false)

# ----------------------------------------------------------------------------- bow
func _build_bow() -> void:
	# Stem: a curved timber from the keel up to the head.
	var stem_points := [
		Vector3(0.0, -0.9, -13.00), Vector3(0.0, 0.25, -13.12),
		Vector3(0.0, 1.20, -13.34), Vector3(0.0, 1.90, -13.55),
		Vector3(0.0, 2.30, -13.60),
	]
	for i: int in range(stem_points.size() - 1):
		var a: Vector3 = stem_points[i]
		var b: Vector3 = stem_points[i + 1]
		_tube("hull_meet", a, b, 0.20, 0.17, 6, Color(0.21, 0.135, 0.078))
		_tube("static_gold", a + Vector3(0.0, 0.0, 0.14), b + Vector3(0.0, 0.0, 0.14),
			0.035, 0.03, 4, Color(1, 1, 1), false)
	# Solid stem knee closes the V between the two sides and backs the figurehead.
	_box("hull_meet", Vector3(0.0, 0.55, -12.96), Vector3(0.55, 2.90, 0.56), Color(0.20, 0.130, 0.076))
	_box("hull_meet", Vector3(0.0, 1.88, -13.40), Vector3(0.46, 0.60, 0.40), Color(0.20, 0.130, 0.076))
	# Face under the bow platform: without it the head is an open dark box.
	_box("trim", Vector3(0.0, 1.97, -13.54), Vector3(4.10, 0.48, 0.14), Color(0.24, 0.16, 0.095))
	for side: float in [-1.0, 1.0]:
		_box("trim", Vector3(side * 1.55, 1.97, -13.44), Vector3(0.12, 0.44, 0.14), Color(0.22, 0.145, 0.085))
	# Knee of the head and the head rails, tied into the platform corners.
	for side: float in [-1.0, 1.0]:
		_tube("trim", Vector3(side * 0.18, 1.75, -13.30), Vector3(side * 2.15, 2.14, -13.62),
			0.09, 0.06, 5, Color(0.27, 0.175, 0.10))
		_tube("trim", Vector3(side * 0.18, 1.10, -13.10), Vector3(side * 2.02, 1.98, -13.58),
			0.085, 0.055, 5, Color(0.27, 0.175, 0.10))
		_box("static_gold", Vector3(side * 1.62, 2.08, -13.60), Vector3(0.36, 0.10, 0.10), Color(1, 1, 1))
	# Bow platform grating already planked; add its rim and knees.
	for side: float in [-1.0, 1.0]:
		_box("trim", Vector3(side * 2.22, 2.16, -12.70), Vector3(0.14, 0.14, 1.84), Color(0.28, 0.18, 0.105))
		_tube("trim", Vector3(side * 0.24, 1.80, -13.55), Vector3(side * 2.10, 2.10, -13.35),
			0.10, 0.07, 5, Color(0.25, 0.16, 0.09))
	# Mermaid figurehead, gilded, carried ahead of the platform so it reads.
	_tube("static_gold", Vector3(0.0, 1.35, -14.35), Vector3(0.0, 1.80, -14.20), 0.13, 0.22, 8, Color(1, 1, 1))
	_tube("static_gold", Vector3(0.0, 1.80, -14.20), Vector3(0.0, 2.36, -14.26), 0.21, 0.14, 8, Color(1, 1, 1))
	_sphere("static_gold", Vector3(0.0, 2.51, -14.26), 0.18, Color(1, 1, 1), 4, 8)
	# Carved face: eyes and a small gilded crown, all in existing batches.
	for side: float in [-1.0, 1.0]:
		_sphere("iron", Vector3(side * 0.065, 2.53, -14.12), 0.028, Color(1, 1, 1), 3, 6)
	_box("static_gold", Vector3(0.0, 2.68, -14.24), Vector3(0.34, 0.07, 0.13), Color(1, 1, 1))
	for side: float in [-1.0, 1.0]:
		_box("static_gold", Vector3(side * 0.15, 2.75, -14.24), Vector3(0.06, 0.14, 0.08),
			Color(1, 1, 1))
	_box("static_gold", Vector3(0.0, 2.78, -14.24), Vector3(0.06, 0.18, 0.08), Color(1, 1, 1))
	for side: float in [-1.0, 1.0]:
		_tube("static_gold", Vector3(side * 0.11, 2.36, -14.30), Vector3(side * 0.38, 2.55, -14.03),
			0.05, 0.03, 5, Color(1, 1, 1), false)
		_tube("static_gold", Vector3(side * 0.14, 1.80, -14.20), Vector3(side * 0.34, 1.52, -14.03),
			0.055, 0.03, 5, Color(1, 1, 1), false)
	# Tail curving down into the stem and a scalloped fin.
	_tube("static_gold", Vector3(0.0, 1.60, -14.24), Vector3(0.0, 1.24, -13.96), 0.17, 0.08, 7, Color(1, 1, 1))
	_tube("static_gold", Vector3(0.0, 1.24, -13.96), Vector3(0.0, 1.08, -13.70), 0.08, 0.12, 7, Color(1, 1, 1))
	for side: float in [-1.0, 1.0]:
		_box("static_gold", Vector3(side * 0.17, 1.18, -13.88), Vector3(0.30, 0.05, 0.26), Color(1, 1, 1),
			Basis(Vector3.UP, side * deg_to_rad(28.0)))
	# Hair curls and a small crown.
	for i: int in 4:
		var a := -0.9 + float(i) * 0.6
		_tube("static_gold", Vector3(sin(a) * 0.15, 2.62, -14.28), Vector3(sin(a) * 0.22, 2.76, -14.12),
			0.038, 0.02, 4, Color(1, 1, 1), false)
	_box("static_gold", Vector3(0.0, 2.70, -14.26), Vector3(0.24, 0.06, 0.24), Color(1, 1, 1))
	# Carved knee carrying the figure from the stem.
	_tube("trim", Vector3(0.0, 2.18, -13.55), Vector3(0.0, 1.92, -14.18), 0.11, 0.07, 5, Color(0.27, 0.175, 0.10))

	# Bowsprit spar, from the deck knee out over the head.
	_tube("bowsprit", Vector3.ZERO, Vector3(0.0, 2.00, -5.75), 0.23, 0.10, 8, Color(0.30, 0.195, 0.11))
	for t: float in [0.18, 0.46, 0.74, 0.95]:
		var p := Vector3(0.0, 2.00 * t, -5.75 * t)
		_ring("bowsprit_iron", p, Vector3(0.0, 2.0, -5.75).normalized(), 0.205 - 0.10 * t, 0.022, 8, Color(1, 1, 1))
	# Gammoning: ropes binding the spar to the stem.
	for i: int in 4:
		_ring("rope", Vector3(0.0, 0.18 + float(i) * 0.13, -0.42 - float(i) * 0.17), Vector3(0.0, 2.0, -5.75).normalized(), 0.25, 0.035, 8, Color(1, 1, 1))
	# Dolphin striker below the tip and a properly connected martingale.
	_tube("bowsprit", Vector3(0.0, 1.88, -5.66), Vector3(0.0, 0.98, -5.66), 0.075, 0.05, 5, Color(0.28, 0.18, 0.10))
	_tube("bowsprit_gold", Vector3(0.0, 2.02, -5.80), Vector3(0.0, 2.18, -5.98), 0.09, 0.02, 6, Color(1, 1, 1))
	# Sprit yard across the spar at the tip and its footropes.
	_tube("bowsprit", Vector3(-1.45, 1.88, -5.46), Vector3(1.45, 1.88, -5.46), 0.055, 0.045, 5, Color(0.28, 0.18, 0.10))
	_tube("rope", Vector3(-1.45, 1.88, -5.46), Vector3(-1.45, 1.42, -5.46), 0.014, 0.014, 4, Color(1, 1, 1), false)
	_tube("rope", Vector3(1.45, 1.88, -5.46), Vector3(1.45, 1.42, -5.46), 0.014, 0.014, 4, Color(1, 1, 1), false)
	# Bobstay and martingale from the tip back to the stem, so nothing floats.
	_tube("rope", Vector3(0.0, 2.01, -5.78), Vector3(0.0, -0.05, -1.05), 0.022, 0.022, 4, Color(1, 1, 1), false)
	_tube("rope", Vector3(0.0, 0.98, -5.66), Vector3(0.0, -1.55, -0.95), 0.018, 0.018, 4, Color(1, 1, 1), false)

# ----------------------------------------------------------------------------- boarding ladders
func _build_boarding_ladders() -> void:
	# Two boarding ladders per side, from the waterline to the main deck.
	# They sit outside the bulwark; `ship_boat.climb_assist` has matching
	# zones, so W climbs them and steps in over the rail.
	for z: float in [-3.0, 4.2]:
		for side: float in [-1.0, 1.0]:
			var x := side * 4.48
			for rail_z: float in [-0.32, 0.32]:
				_box("trim", Vector3(x, -0.01, z + rail_z), Vector3(0.11, 3.58, 0.10),
					Color(0.31, 0.20, 0.11))
			var rung := -1.55
			while rung < 1.75:
				_box("trim", Vector3(x, rung, z), Vector3(0.10, 0.07, 0.72),
					Color(0.37, 0.25, 0.14))
				rung += 0.27
			# Finish at deck level, below the neighbouring gun's depressed barrel.
			_box("iron", Vector3(x - side * 0.16, 1.75, z), Vector3(0.34, 0.06, 0.80),
				Color(1, 1, 1))


# ----------------------------------------------------------------------------- stern dressing
func _build_stern_dressing() -> void:
	# Quarterdeck taffrail with turned balusters.
	for side: float in [-1.0, 1.0]:
		for i: int in 7:
			var x := side * (0.48 + float(i) * 0.42)
			_box("rails", Vector3(x, 3.44, 12.42), Vector3(0.075, 0.74, 0.075), Color(0.30, 0.20, 0.11))
			_sphere("rails", Vector3(x, 3.60, 12.42), 0.055, Color(0.30, 0.20, 0.11), 3, 6)
	_box("rails", Vector3(0.0, 3.81, 12.42), Vector3(5.95, 0.10, 0.16), Color(0.32, 0.215, 0.12))
	_box("rails_gold", Vector3(0.0, 3.87, 12.43), Vector3(6.10, 0.045, 0.10), Color(1, 1, 1))
	# Side quarterdeck rails on top of the bulwark cap.
	for side: float in [-1.0, 1.0]:
		var x := side * 3.12
		for i: int in 5:
			var z := 6.55 + float(i) * 1.36
			_box("rails", Vector3(x, 3.92, z), Vector3(0.08, 0.48, 0.08), Color(0.29, 0.19, 0.105))
		_box("rails", Vector3(x, 4.15, 9.30), Vector3(0.10, 0.08, 6.10), Color(0.31, 0.205, 0.115))
	# Break rail above the quarterdeck front, opened on the starboard stair.
	for i: int in 5:
		var x := -2.95 + float(i) * 0.72
		_box("rails", Vector3(x, 3.44, 6.10), Vector3(0.08, 0.80, 0.08), Color(0.30, 0.20, 0.11))
	_box("rails", Vector3(-1.25, 3.86, 6.10), Vector3(3.75, 0.09, 0.14), Color(0.33, 0.22, 0.125))
	_box("rails", Vector3(3.02, 3.86, 6.10), Vector3(0.55, 0.09, 0.14), Color(0.33, 0.22, 0.125))
	# Bow platform railing.
	_box("rails", Vector3(0.0, 2.66, -13.50), Vector3(4.10, 0.09, 0.12), Color(0.31, 0.205, 0.115))
	for i: int in 5:
		var x := -1.95 + float(i) * 0.975
		_box("rails", Vector3(x, 2.42, -13.50), Vector3(0.07, 0.50, 0.07), Color(0.29, 0.19, 0.105))
	for side: float in [-1.0, 1.0]:
		_box("rails", Vector3(side * 2.02, 2.42, -12.70), Vector3(0.07, 0.50, 1.80), Color(0.29, 0.19, 0.105))
	# Stern ensign staff.
	_tube("rails", Vector3(0.0, 3.95, 12.42), Vector3(0.0, 7.64, 12.55), 0.055, 0.030, 6, Color(0.30, 0.20, 0.11))
	_sphere("rails_gold", Vector3(0.0, 7.68, 12.55), 0.075, Color(1, 1, 1), 3, 6)

# ----------------------------------------------------------------------------- details
## Small hand-worked details that make the ship read as a built object rather
## than a lofted hull: transom carving, a bell with a lanyard, quarterdeck
## belaying pins and a skylight grating.  Everything joins an existing batch,
## so the whole block costs no extra draw call.
func _build_bulwark_carvings() -> void:
	# Carved relief panels along the outside of the bulwark: a dark inset,
	# gold end-beads and a rosette.  Every piece is a box/sphere in the existing
	# trim/static_gold batches, so the whole carved run costs no extra draw call.
	for side: float in [-1.0, 1.0]:
		for z: float in [-10.4, -7.6, -6.0, -2.0, 0.8, 2.0]:
			var y := 2.40
			var x := side * (_hull_x_at(z, y) + 0.025)
			_box("trim", Vector3(x, y, z), Vector3(0.035, 0.62, 0.86), Color(0.23, 0.15, 0.085))
			for dz: float in [-0.36, 0.36]:
				_box("static_gold", Vector3(x + side * 0.018, y, z + dz),
					Vector3(0.025, 0.50, 0.055), Color(1, 1, 1))
			_sphere("static_gold", Vector3(x + side * 0.035, y, z), 0.095, Color(1, 1, 1), 4, 8)
		for z: float in [6.9, 9.1, 11.3]:
			var y := 3.50
			var x := side * (_hull_x_at(z, y) + 0.025)
			_box("trim", Vector3(x, y, z), Vector3(0.035, 0.58, 0.82), Color(0.23, 0.15, 0.085))
			for dz: float in [-0.34, 0.34]:
				_box("static_gold", Vector3(x + side * 0.018, y, z + dz),
					Vector3(0.025, 0.46, 0.05), Color(1, 1, 1))
			_sphere("static_gold", Vector3(x + side * 0.035, y, z), 0.09, Color(1, 1, 1), 4, 8)


func _build_details() -> void:
	# Gilt scroll frieze below the stern windows.
	for i: int in 9:
		var x := lerpf(-2.55, 2.55, float(i) / 8.0)
		var h := 0.095 + 0.05 * sin(float(i) / 8.0 * PI)
		_box("transom_gold", Vector3(x, 1.62, 13.092), Vector3(0.27, h, 0.06), Color(1, 1, 1),
			Basis(Vector3.BACK, sin(float(i) * 1.7) * 0.30))
	# Scallop shell above the crest, under the taffrail.
	for i: int in 7:
		var a := lerpf(-0.62, 0.62, float(i) / 6.0)
		_box("transom_gold", Vector3(sin(a) * 0.74, 3.60 + cos(a) * 0.13, 13.118),
			Vector3(0.095, 0.30, 0.055), Color(1, 1, 1), Basis(Vector3.BACK, a))
	# Carved corner rosettes with a dark recess behind them.
	for side: float in [-1.0, 1.0]:
		_box("transom_dark", Vector3(side * 2.58, 2.92, 13.070), Vector3(0.36, 0.36, 0.05),
			Color(0.19, 0.12, 0.068), Basis(Vector3.BACK, deg_to_rad(45.0)))
		_sphere("transom_gold", Vector3(side * 2.58, 2.92, 13.098), 0.105, Color(1, 1, 1), 3, 8)
	# Ship's bell: mouth rim, clapper, yoke and a lanyard down to the cleat.
	_ring("gold", Vector3(-1.72, 2.655, 4.85), Vector3.UP, 0.155, 0.016, 10, Color(1, 1, 1))
	_tube("gold", Vector3(-1.72, 2.66, 4.85), Vector3(-1.72, 2.55, 4.85), 0.052, 0.024, 6, Color(1, 1, 1))
	_sphere("gold", Vector3(-1.72, 2.535, 4.85), 0.045, Color(1, 1, 1), 3, 6)
	_tube("rope", Vector3(-1.72, 2.52, 4.85), Vector3(-1.72, 2.09, 4.85), 0.012, 0.012, 4, Color(1, 1, 1), false)
	_box("trim", Vector3(-1.72, 2.04, 4.85), Vector3(0.17, 0.10, 0.17), Color(0.30, 0.20, 0.11))
	# Quarterdeck pin rails: a double row of belaying pins inside the bulwark.
	for side: float in [-1.0, 1.0]:
		for i: int in 5:
			var z := 7.20 + float(i) * 0.94
			var x := side * (_hull_x_at(z, 3.44) - 0.20)
			_box("trim", Vector3(x, 3.60, z), Vector3(0.055, 0.30, 0.055), Color(0.32, 0.225, 0.145))
			_box("rope", Vector3(x, 3.70, z), Vector3(0.075, 0.035, 0.075), Color(0.66, 0.58, 0.40))
	# Skylight grating over the cabin: frame, slats and two cross battens.
	var gy := QUARTER_Y + 0.055
	for side: float in [-1.0, 1.0]:
		_box("trim", Vector3(side * 0.68, gy, 8.20), Vector3(0.11, 0.10, 1.26), Color(0.29, 0.19, 0.105))
	for zz: float in [7.60, 8.80]:
		_box("trim", Vector3(0.0, gy, zz), Vector3(1.40, 0.10, 0.10), Color(0.29, 0.19, 0.105))
	for i: int in 6:
		var z := 7.68 + float(i) * 0.205
		_box("deck_dark", Vector3(0.0, gy + 0.045, z), Vector3(1.18, 0.045, 0.085), Color(0.23, 0.155, 0.088))
	_box("deck_dark", Vector3(0.0, gy + 0.052, 8.20), Vector3(1.22, 0.04, 0.06), Color(0.22, 0.145, 0.082))

# ----------------------------------------------------------------------------- upper deck
func _build_upper_deck() -> void:
	var y := UPPER_Y + 0.02
	var z0 := -4.20
	var z1 := 1.80
	var half := 3.20
	# Frame.
	for side: float in [-1.0, 1.0]:
		_box("trim", Vector3(side * (half - 0.12), y - 0.06, -1.20), Vector3(0.20, 0.22, 6.00), Color(0.28, 0.18, 0.105))
	for i: int in 5:
		var z := z0 + 0.12 + float(i) * 1.44
		_box("trim", Vector3(0.0, y - 0.06, z), Vector3(6.30, 0.20, 0.16), Color(0.26, 0.17, 0.10))
	# Grating slats along z with a narrow gap, plus two cross battens.
	var slat_count := 15
	for i: int in slat_count:
		var x := -half + 0.18 + float(i) * 0.425
		_box("deck", Vector3(x, y, -1.20), Vector3(0.115, 0.055, 5.84),
			_tone(DECK_TONES, i + 2) * 0.94)
	for i: int in 2:
		_box("deck_dark", Vector3(0.0, y + 0.035, -2.80 + float(i) * 3.20), Vector3(6.10, 0.045, 0.09),
			Color(0.24, 0.16, 0.095))
	# Diagonal knees from the bulwark up to the platform: the fighting top must
	# look carried, not floating.
	for side: float in [-1.0, 1.0]:
		for z: float in [-2.80, 1.40]:
			_tube("trim", Vector3(side * 3.48, 2.58, z), Vector3(side * 2.95, 5.10, z),
				0.13, 0.09, 6, Color(0.27, 0.175, 0.10))
			_box("trim", Vector3(side * 2.92, 4.80, z), Vector3(0.18, 0.55, 0.50), Color(0.26, 0.17, 0.10),
				Basis(Vector3.RIGHT, deg_to_rad(-28.0)))
		for z: float in [-4.15, 1.75]:
			_box("trim", Vector3(side * 2.95, 4.95, z), Vector3(0.24, 0.42, 0.24), Color(0.26, 0.17, 0.10))
	# Mast collar where the mast passes through.
	_ring("trim", Vector3(0.0, y + 0.03, -1.00), Vector3.UP, 0.34, 0.07, 10, Color(0.25, 0.16, 0.095))
	# Railing: posts on the perimeter, opening at the ladder on the south side.
	var rail_y := UPPER_Y + 0.86
	for side: float in [-1.0, 1.0]:
		for i: int in 5:
			var z := z0 + 0.10 + float(i) * 1.42
			_box("upper_rail", Vector3(side * (half - 0.08), rail_y - 0.43, z), Vector3(0.085, 0.86, 0.085),
				Color(0.29, 0.19, 0.105))
		_box("upper_rail", Vector3(side * (half - 0.08), rail_y, -1.20), Vector3(0.11, 0.09, 5.90), Color(0.31, 0.205, 0.115))
	for i: int in 5:
		var x := -half + 0.10 + float(i) * 1.55
		if absf(x) < 0.55:
			continue
		_box("upper_rail", Vector3(x, rail_y - 0.43, z0 + 0.08), Vector3(0.085, 0.86, 0.085), Color(0.29, 0.19, 0.105))
	for i: int in 5:
		var x := -half + 0.10 + float(i) * 1.55
		_box("upper_rail", Vector3(x, rail_y - 0.43, z1 - 0.08), Vector3(0.085, 0.86, 0.085), Color(0.29, 0.19, 0.105))
	_box("upper_rail", Vector3(0.0, rail_y, z0 + 0.08), Vector3(6.30, 0.09, 0.11), Color(0.31, 0.205, 0.115))
	_box("upper_rail", Vector3(-2.05, rail_y, z1 - 0.08), Vector3(2.20, 0.09, 0.11), Color(0.31, 0.205, 0.115))
	_box("upper_rail", Vector3(2.05, rail_y, z1 - 0.08), Vector3(2.20, 0.09, 0.11), Color(0.31, 0.205, 0.115))
	# A ladder rail on the far side of the ladder opening.
	_box("upper_rail", Vector3(0.72, rail_y - 0.30, z1 - 0.34), Vector3(1.05, 0.06, 0.08), Color(0.30, 0.20, 0.11))
	# The ladder: two stringers and twelve rungs, raked from the main deck.
	var base := Vector3(0.0, DECK_Y + 0.02, 2.34)
	var top := Vector3(0.0, UPPER_Y + 0.01, 1.86)
	for side: float in [-1.0, 1.0]:
		_box("trim", (base + top) * 0.5 + Vector3(side * 0.38, 0.0, 0.0),
			Vector3(0.09, 3.62, 0.10), Color(0.27, 0.175, 0.10),
			Basis(Vector3.RIGHT, atan2(top.z - base.z, top.y - base.y)))
	for i: int in 12:
		var t := (float(i) + 0.5) / 12.0
		var p := base.lerp(top, t)
		_box("trim", p, Vector3(0.82, 0.055, 0.11), Color(0.32, 0.21, 0.12),
			Basis(Vector3.RIGHT, atan2(top.z - base.z, top.y - base.y)))
	# A small barrel and a coil of cable on the top.
	_barrel(Vector3(-2.45, UPPER_Y + 0.05, -0.20), 0.22, 0.62)
	_ring("rope", Vector3(2.40, UPPER_Y + 0.07, -3.20), Vector3.UP, 0.24, 0.045, 10, Color(1, 1, 1))
	_box("trim", Vector3(2.45, UPPER_Y + 0.24, -3.20), Vector3(0.55, 0.32, 0.55), Color(0.30, 0.20, 0.11))

# ----------------------------------------------------------------------------- cannons
func _build_cannons() -> void:
	for i: int in 4:
		var side := -1.0 if i < 2 else 1.0
		var z: float = PORT_Z[i % 2]
		var wood_key := "cannon%d_wood" % i
		var iron_key := "cannon%d_iron" % i
		var rope_key := "cannon%d_rope" % i
		# Carriage: cheeks, cross members, four trucks and iron caps.
		for sx: float in [-1.0, 1.0]:
			_box(wood_key, Vector3(sx * 0.34, 0.34, 0.05), Vector3(0.12, 0.44, 1.35),
				Color(0.34, 0.225, 0.135))
			_box(wood_key, Vector3(sx * 0.34, 0.32, 0.05), Vector3(0.14, 0.10, 1.40),
				Color(0.28, 0.18, 0.105))
			for zz: float in [-0.45, 0.50]:
				_box(iron_key, Vector3(sx * 0.34, 0.56, zz), Vector3(0.20, 0.08, 0.16), Color(1, 1, 1))
				_tube(iron_key, Vector3(sx * 0.52, 0.24, zz), Vector3(sx * 0.30, 0.24, zz),
					0.20, 0.20, 12, Color(1, 1, 1))
		_box(wood_key, Vector3(0.0, 0.22, -0.48), Vector3(0.80, 0.16, 0.16), Color(0.30, 0.20, 0.12))
		_box(wood_key, Vector3(0.0, 0.22, 0.52), Vector3(0.80, 0.16, 0.16), Color(0.30, 0.20, 0.12))
		_tube(iron_key, Vector3(-0.52, 0.20, -0.35), Vector3(0.52, 0.20, -0.35), 0.045, 0.045, 6, Color(1, 1, 1))
		_tube(iron_key, Vector3(-0.52, 0.20, 0.42), Vector3(0.52, 0.20, 0.42), 0.045, 0.045, 6, Color(1, 1, 1))
		# Breeching rope and side tackles.
		_tube(rope_key, Vector3(-0.34, 0.52, 0.62), Vector3(0.34, 0.52, 0.62), 0.035, 0.035, 5, Color(1, 1, 1), false)
		_tube(rope_key, Vector3(-0.34, 0.52, 0.62), Vector3(-0.62, 0.30, 0.30), 0.028, 0.028, 4, Color(1, 1, 1), false)
		_tube(rope_key, Vector3(0.34, 0.52, 0.62), Vector3(0.62, 0.30, 0.30), 0.028, 0.028, 4, Color(1, 1, 1), false)
		# Barrel in the pivot's local frame, muzzle -Z.  The mesh is parented to
		# the barrel node, so pivot.rotation.y / barrel.rotation.x really train
		# and elevate the visible gun (ship_cannons.gd drives those nodes).
		var barrel := _cannon_barrels[i]
		var barrel_key := "cannon%d_barrel_iron" % i
		_tube(barrel_key, Vector3(0.0, 0.0, 0.32), Vector3(0.0, 0.0, -1.80),
			0.155, 0.105, 14, Color(1, 1, 1))
		_tube(barrel_key, Vector3(0.0, 0.0, -1.60), Vector3(0.0, 0.0, -1.82),
			0.165, 0.135, 14, Color(1, 1, 1))
		_sphere(barrel_key, Vector3(0.0, 0.0, 0.40), 0.12, Color(1, 1, 1), 4, 8)
		_tube(barrel_key, Vector3(0.0, 0.0, 0.50), Vector3(0.0, 0.0, 0.62), 0.075, 0.045, 8, Color(1, 1, 1))
		for zz: float in [0.18, -0.30, -0.72, -1.30, -1.76]:
			var radius := 0.165 if zz > -0.4 else 0.14
			_tube(barrel_key, Vector3(0.0, 0.0, zz + 0.035), Vector3(0.0, 0.0, zz - 0.035),
				radius, radius, 14, Color(1, 1, 1))
		# Trunnions belong to the barrel, so they tilt with it.
		_tube(barrel_key, Vector3(-0.20, 0.0, 0.02), Vector3(0.20, 0.0, 0.02),
			0.075, 0.075, 8, Color(1, 1, 1))
		# Aim the gun gently outboard and level for the default pose.
		var pivot := _cannon_pivots[i]
		pivot.rotation.y = 0.0
		barrel.rotation.x = 0.0
		# Shot pyramid on the deck inboard of each gun.
		var base_x := side * 2.78
		for level: int in 3:
			var count := 3 - level
			for n: int in count:
				var px := base_x + float(n) * 0.26 - float(count - 1) * 0.13
				var p := Vector3(px, DECK_Y + 0.13 + float(level) * 0.20, z + 0.78)
				_cannonball_slots.append(p)

# ----------------------------------------------------------------------------- helm & lever
func _build_helm() -> void:
	# Stand: two carved cheeks and the barrel that carries the axle.
	for side: float in [-1.0, 1.0]:
		_box("helm_wood", Vector3(side * 0.52, 0.48, 0.10), Vector3(0.12, 0.96, 0.16), Color(0.28, 0.18, 0.105),
			Basis(Vector3.BACK, side * deg_to_rad(-5.0)))
		_box("helm_gold", Vector3(side * 0.52, 0.91, 0.10), Vector3(0.14, 0.05, 0.18), Color(1, 1, 1))
		_box("helm_iron", Vector3(side * 0.52, 0.10, 0.10), Vector3(0.18, 0.08, 0.20), Color(1, 1, 1))
	_tube("helm_wood", Vector3(0.0, 0.96, -0.02), Vector3(0.0, 0.96, 0.24), 0.14, 0.14, 12, Color(0.26, 0.17, 0.10))
	_tube("helm_iron", Vector3(0.0, 0.96, 0.24), Vector3(0.0, 0.96, 0.30), 0.10, 0.10, 10, Color(1, 1, 1))
	# Binnacle and compass in front of the wheel.
	_box("helm_wood", Vector3(0.94, 0.34, 0.34), Vector3(0.46, 0.68, 0.46), Color(0.30, 0.20, 0.12))
	_tube("helm_gold", Vector3(0.94, 0.70, 0.34), Vector3(0.94, 0.73, 0.34), 0.19, 0.16, 12, Color(1, 1, 1))
	_box("static_tar", Vector3(0.94, 0.735, 0.34), Vector3(0.24, 0.02, 0.24), Color(1, 1, 1))
	_box("helm_gold", Vector3(0.94, 0.75, 0.34), Vector3(0.06, 0.01, 0.22), Color(1, 1, 1))
	# The wheel itself: one merged mesh on a pivot so it can spin.
	_wheel = Node3D.new()
	_wheel.name = "Wheel"
	_wheel.position = Vector3(0.0, 1.06, 0.20)
	_helm_node.add_child(_wheel)
	var wheel_st := "wheel_mesh_tmp"
	_ring(wheel_st, Vector3.ZERO, Vector3.BACK, 0.70, 0.045, 16, Color(0.30, 0.20, 0.115))
	# Ten spokes with iron ferrules and turned handles read as a real ship's
	# wheel; the previous eight-spoke wheel looked like a cart wheel.
	for i: int in 10:
		var a := TAU * float(i) / 10.0
		var dir := Vector3(cos(a), sin(a), 0.0)
		_box(wheel_st, dir * 0.34, Vector3(0.050, 0.58, 0.042), Color(0.28, 0.185, 0.105),
			Basis(Vector3.BACK, a - PI * 0.5))
		_box(wheel_st, dir * 0.74, Vector3(0.045, 0.24, 0.045), Color(0.26, 0.17, 0.10),
			Basis(Vector3.BACK, a - PI * 0.5))
		_sphere(wheel_st, dir * 0.86, 0.038, Color(0.72, 0.55, 0.22), 3, 6)
		# Iron ferrule where the spoke meets the rim.
		_box(wheel_st, dir * 0.64, Vector3(0.055, 0.045, 0.055), Color(0.12, 0.12, 0.13),
			Basis(Vector3.BACK, a - PI * 0.5))
	_tube(wheel_st, Vector3(0.0, 0.0, -0.09), Vector3(0.0, 0.0, 0.09), 0.135, 0.135, 14, Color(0.30, 0.20, 0.115))
	# Brass hub cap and a rope wrap around the axle.
	_tube(wheel_st, Vector3(0.0, 0.0, 0.09), Vector3(0.0, 0.0, 0.14), 0.095, 0.070, 12, Color(0.78, 0.60, 0.24))
	for r: int in 3:
		_ring(wheel_st, Vector3(0.0, 0.0, 0.06 + float(r) * 0.018), Vector3.BACK, 0.175, 0.018, 12,
			Color(0.35, 0.24, 0.13))
	_commit_temp(wheel_st, _materials["wood_dark"], _wheel, false)
	# Dark iron tyre around the wooden rim, on its own tiny batch.
	var tyre_st := "wheel_tyre_tmp"
	_ring(tyre_st, Vector3.ZERO, Vector3.BACK, 0.742, 0.012, 24, Color(1, 1, 1))
	_commit_temp(tyre_st, _materials["iron"], _wheel, false)
	# Iron braces from the deck to the wheel cheeks.
	for side: float in [-1.0, 1.0]:
		_box("helm_iron", Vector3(side * 0.52, 0.16, 0.02), Vector3(0.06, 0.42, 0.06), Color(1, 1, 1),
			Basis(Vector3.RIGHT, side * deg_to_rad(24.0)))
	# Brass nameplate on the front of the stand.
	_box("helm_gold", Vector3(0.0, 0.66, 0.19), Vector3(0.34, 0.10, 0.02), Color(1, 1, 1))
	_box("helm_iron", Vector3(0.0, 0.66, 0.20), Vector3(0.26, 0.045, 0.01), Color(1, 1, 1))
	# Brass compass glass on the binnacle.
	_sphere("helm_gold", Vector3(0.94, 0.79, 0.34), 0.105, Color(1, 1, 1), 6, 12)
	_box("static_tar", Vector3(0.94, 0.82, 0.34), Vector3(0.16, 0.02, 0.16), Color(1, 1, 1))
	# King spoke marked with gold, so the wheel angle is readable.
	_box("helm_gold", _wheel.position + Vector3(0.0, 0.20, 0.03), Vector3(0.05, 0.10, 0.05), Color(1, 1, 1))

func _build_lever() -> void:
	# Brass quadrant on an oak pedestal, the handle throws fore and aft.
	_box("lever_gold", Vector3(0.0, -0.42, 0.0), Vector3(0.48, 0.10, 0.48), Color(1, 1, 1))
	_box("lever_iron", Vector3(0.0, -0.22, 0.0), Vector3(0.42, 0.34, 0.42), Color(1, 1, 1))
	for i: int in 7:
		var a := -0.9 + float(i) * 0.3
		_box("lever_gold", Vector3(0.0, 0.10, 0.0) + Vector3(0.0, cos(a) * 0.20, sin(a) * 0.20),
			Vector3(0.10, 0.035, 0.10), Color(1, 1, 1), Basis(Vector3.RIGHT, a))
	_lever_pivot = Node3D.new()
	_lever_pivot.name = "LeverPivot"
	_lever_pivot.position = Vector3(0.0, 0.16, 0.0)
	_lever_node.add_child(_lever_pivot)
	# The handle is its own mesh hierarchy under the pivot.  The pedestal and
	# quadrant stay batched and never move.
	var iron_mat: Material = _materials.get("iron", null)
	var gold_mat: Material = _materials.get("gold", null)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.060, 0.78, 0.060)
	shaft.mesh = shaft_mesh
	shaft.material_override = iron_mat
	shaft.position = Vector3(0.0, 0.39, 0.0)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_lever_pivot.add_child(shaft)
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.105
	knob_mesh.height = 0.21
	knob_mesh.radial_segments = 10
	knob_mesh.rings = 6
	knob.mesh = knob_mesh
	knob.material_override = gold_mat
	knob.position = Vector3(0.0, 0.80, 0.0)
	_lever_pivot.add_child(knob)
	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.10, 0.22, 0.035)
	grip.mesh = grip_mesh
	grip.material_override = gold_mat
	grip.position = Vector3(0.0, 0.40, 0.045)
	_lever_pivot.add_child(grip)

# ----------------------------------------------------------------------------- mast, yards
func _build_mast() -> void:
	# Lower mast (stays with the hull) and the upper mast (breaks away).
	_tube("mast_lower", Vector3(0.0, -0.10, 0.0), Vector3(0.0, 7.24, 0.0), 0.295, 0.215, 12, Color(0.31, 0.20, 0.115))
	for t: float in [0.10, 0.34, 0.58, 0.82, 0.98]:
		var y := t * 7.2
		var r := lerpf(0.295, 0.215, t) + 0.015
		_ring("mast_iron", Vector3(0.0, y, 0.0), Vector3.UP, r, 0.025, 10, Color(1, 1, 1))
	_box("mast_lower", Vector3(0.0, 7.18, 0.0), Vector3(0.62, 0.14, 0.62), Color(0.25, 0.16, 0.095))
	_tube("mast_upper", Vector3(0.0, -0.06, 0.0), Vector3(0.0, 8.80, 0.0), 0.205, 0.055, 12, Color(0.32, 0.205, 0.12))
	for t: float in [0.06, 0.24, 0.43, 0.62, 0.80, 0.94]:
		var y := t * 8.75
		var r := lerpf(0.205, 0.055, t) + 0.012
		_ring("mast_upper", Vector3(0.0, y, 0.0), Vector3.UP, r, 0.02, 8, Color(0.27, 0.18, 0.10))
	# Topmast cap and truck.
	_box("mast_upper", Vector3(0.0, 5.30, 0.0), Vector3(0.40, 0.14, 0.40), Color(0.27, 0.175, 0.10))
	_tube("mast_upper", Vector3(0.0, 8.76, 0.0), Vector3(0.0, 8.94, 0.0), 0.075, 0.05, 8, Color(1, 1, 1))
	# The jagged stump that replaces the mast when it is shot away.
	_tube("mast_stump", Vector3(0.0, -0.30, 0.0), Vector3(0.0, 0.16, 0.0), 0.225, 0.16, 9, Color(0.25, 0.16, 0.092))
	for i: int in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		_box("mast_stump", Vector3(cos(a) * 0.10, 0.24, sin(a) * 0.10), Vector3(0.055, 0.42, 0.055),
			Color(0.36, 0.24, 0.14), Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.20))
	# Yards, all attached above the break.
	var yard_data := [
		{"y": 10.35, "half": 5.80, "r": 0.11},
		{"y": 14.15, "half": 4.55, "r": 0.085},
		{"y": 16.55, "half": 3.20, "r": 0.065},
	]
	for yd: Dictionary in yard_data:
		var y: float = yd["y"]
		var half: float = yd["half"]
		var r: float = yd["r"]
		_tube("yard", Vector3(-half, y, -1.0), Vector3(0.0, y + 0.04, -1.0), r, r * 1.25, 7, Color(0.30, 0.195, 0.11))
		_tube("yard", Vector3(0.0, y + 0.04, -1.0), Vector3(half, y, -1.0), r * 1.25, r, 7, Color(0.30, 0.195, 0.11))
		for sx: float in [-1.0, 1.0]:
			_ring("yard_iron", Vector3(sx * half * 0.34, y + 0.02, -1.0), Vector3.RIGHT, r + 0.02, 0.018, 6, Color(1, 1, 1))
			_tube("yard_iron", Vector3(sx * half, y, -1.0), Vector3(sx * half, y - 0.03, -1.0), r * 0.7, r * 0.4, 6, Color(1, 1, 1))
	# A short mast-top lantern bracket and the truck.
	_ring("yard_iron", Vector3(0.0, 8.86, 0.0), Vector3.UP, 0.18, 0.025, 8, Color(1, 1, 1))

# ----------------------------------------------------------------------------- sails
func _build_sails() -> void:
	var sail_specs := [
		{"top": 10.22, "height": 3.62, "width_top": 10.60, "width_bottom": 11.10, "material": "sail"},
		{"top": 13.98, "height": 3.20, "width_top": 8.20, "width_bottom": 8.75, "material": "sail"},
	]
	for spec: Dictionary in sail_specs:
		var top_y: float = spec["top"]
		var height: float = spec["height"]
		var sail_node := Node3D.new()
		sail_node.name = "Sail"
		sail_node.position = Vector3(0.0, top_y, -0.96)
		_sails_node.add_child(sail_node)
		var mesh := _make_sail_mesh(float(spec["width_top"]), float(spec["width_bottom"]), height, 8, 6)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _materials[spec["material"]]
		# Canvas shadows are intentionally off: an eleven-metre sail directly
		# above the deck otherwise throws the whole hull and rig into one flat
		# shadow, which hides the planking the model exists to show.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sail_node.add_child(mi)
		var back := MeshInstance3D.new()
		back.name = "SailBack"
		back.mesh = mesh
		back.material_override = _materials["sail_back"]
		back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		back.position = Vector3(0.0, 0.0, 0.010)
		sail_node.add_child(back)
		_sail_meshes.append({"node": sail_node, "kind": "square", "height": height})
		_sail_defs.append({
			"kind": "square",
			"origin": Vector3(0.0, top_y - height * 0.5, -0.96),
			"right": Vector3.RIGHT,
			"up": Vector3.UP,
			"normal": Vector3.FORWARD,
			"half_w": float(spec["width_bottom"]) * 0.5,
			"half_h": height * 0.5,
			"width_top": float(spec["width_top"]),
			"width_bottom": float(spec["width_bottom"]),
			"billow": 0.34,
		})
		# The furled bundle on the yard.
		var roll := MeshInstance3D.new()
		roll.name = "FurledSail"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.17
		cyl.bottom_radius = 0.17
		cyl.height = float(spec["width_top"]) * 0.92
		cyl.radial_segments = 8
		cyl.rings = 1
		roll.mesh = cyl
		roll.material_override = _materials["canvas_plain"]
		roll.rotation.z = deg_to_rad(90.0)
		roll.position = Vector3(0.0, top_y + 0.10, -0.96)
		roll.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sails_node.add_child(roll)
		_rolls.append({"node": roll, "kind": "square"})
	# Jib: head on the forestay, tack at the bowsprit, clew aft and inboard.
	var head := Vector3(0.0, 13.50, -5.55)
	var tack := Vector3(0.0, 4.50, -17.80)
	var clew := Vector3(0.0, 6.20, -12.50)
	var luff := (head - tack).normalized()
	var clew_vec := clew - head
	var perp := clew_vec - luff * clew_vec.dot(luff)
	var x_axis := perp.normalized()
	var z_axis := x_axis.cross(luff).normalized()
	var y_axis := luff
	var jib_node := Node3D.new()
	jib_node.name = "Jib"
	jib_node.position = head
	jib_node.transform.basis = Basis(x_axis, y_axis, z_axis)
	_sails_node.add_child(jib_node)
	var local_tack := Vector3(0.0, -(head - tack).length(), 0.0)
	var local_clew := Vector3(perp.length(), luff.dot(clew_vec), 0.0)
	var jib_mesh := _make_jib_mesh(local_tack, local_clew, 7)
	var jib_mi := MeshInstance3D.new()
	jib_mi.mesh = jib_mesh
	jib_mi.material_override = _materials["sail_jib"]
	jib_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jib_node.add_child(jib_mi)
	var jib_back := MeshInstance3D.new()
	jib_back.name = "JibBack"
	jib_back.mesh = jib_mesh
	jib_back.material_override = _materials["sail_jib_back"]
	jib_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jib_back.position = Vector3(0.0, 0.0, 0.010)
	jib_node.add_child(jib_back)
	_sail_meshes.append({"node": jib_node, "kind": "jib", "height": (head - tack).length()})
	var jib_len := (head - tack).length()
	var jib_perp := perp.length()
	var jib_basis := Basis(x_axis, y_axis, z_axis)
	_sail_defs.append({
		"kind": "jib",
		"origin": head + jib_basis * Vector3(jib_perp * 0.5, -jib_len * 0.5, 0.0),
		"right": x_axis,
		"up": y_axis,
		"normal": -z_axis,
		"half_w": jib_perp * 0.5,
		"half_h": jib_len * 0.5,
		"width_top": jib_perp,
		"width_bottom": jib_perp,
		"billow": 0.24,
	})
	var jib_roll := Node3D.new()
	jib_roll.name = "JibRoll"
	jib_node.add_child(jib_roll)
	var jib_roll_st := "jib_roll_tmp"
	_tube(jib_roll_st, Vector3(0.0, 0.10, 0.0), Vector3(0.0, -((head - tack).length()) + 0.2, 0.0),
		0.10, 0.075, 7, Color(0.84, 0.80, 0.70))
	_commit_temp(jib_roll_st, _materials["canvas_plain"], jib_roll, false)
	_rolls.append({"node": jib_roll, "kind": "jib"})
	# Clew sheet and the jib sheet blocks.
	_tube("static_rope", clew, Vector3(2.30, 3.10, -9.40), 0.018, 0.018, 4, Color(1, 1, 1), false)
	_tube("static_rope", clew, Vector3(-2.30, 3.10, -9.40), 0.018, 0.018, 4, Color(1, 1, 1), false)
	_build_sail_holes()

# ----------------------------------------------------------------------------- sail holes
## A torn hole is a dark ragged disc with a charred, frayed rim.  All holes live in
## one MultiMesh: instance `i*2` sits just proud of the bow-side canvas and
## `i*2+1` just behind the stern-side copy, so the two-sided sail shows the same
## hole from both sides.  Nothing is parented to the (animated, scaled) sail
## nodes: the decals keep their size and position in ship space, and are hidden
## while the canvas is furled.
func _build_sail_holes() -> void:
	if _sail_hole_mm != null:
		return
	_sail_hole_mesh = _make_sail_hole_mesh()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color.WHITE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _sail_hole_mesh
	mm.instance_count = SAIL_HOLE_CAP * 2
	var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3(0.0001, 0.0001, 0.0001)), Vector3(0.0, -200.0, 0.0))
	for i: int in mm.instance_count:
		mm.set_instance_transform(i, hidden)
	_sail_hole_mm = MultiMeshInstance3D.new()
	_sail_hole_mm.name = "SailHoles"
	_sail_hole_mm.multimesh = mm
	_sail_hole_mm.material_override = material
	_sail_hole_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sail_hole_mm.visible = false
	_sails_node.add_child(_sail_hole_mm)

func _make_sail_hole_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	var normal := Vector3(0.0, 0.0, 1.0)
	var core := Color(0.020, 0.018, 0.016)
	var rim := Color(0.055, 0.045, 0.035)
	var charred := Color(0.105, 0.078, 0.050)
	var fray := Color(0.335, 0.280, 0.195)
	var segments := SAIL_HOLE_SEGMENTS
	var ring: Array[Vector3] = []
	for i: int in segments:
		var a := TAU * float(i) / float(segments)
		var r := 0.80 + 0.18 * sin(float(i) * 2.37 + 0.9) + 0.05 * sin(float(i) * 5.1)
		ring.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for i: int in segments:
		var a0: Vector3 = ring[i]
		var a1: Vector3 = ring[(i + 1) % segments]
		_tri_color(st, center, a1, a0, core, normal)
	# Charred ring: a few short, irregular burnt tongues rather than long spikes,
	# plus a lighter frayed thread so the edge reads as torn canvas.
	for i: int in segments:
		var a0: Vector3 = ring[i]
		var a1: Vector3 = ring[(i + 1) % segments]
		var mid := (a0 + a1) * 0.5
		var outward := Vector3(mid.x, mid.y, 0.0).normalized()
		var tip := mid + outward * (0.05 + 0.09 * absf(sin(float(i) * 1.9)))
		_tri_color(st, mid, a0, tip, rim, normal)
		_tri_color(st, mid, tip, a1, charred, normal)
		if i % 2 == 0:
			var thread := a1 + outward * (0.12 + 0.10 * absf(cos(float(i) * 2.2)))
			_tri_color(st, a0, a1, thread, fray, normal)
	st.index()
	return st.commit()

## Project a ship-local point onto the nearest canvas.  `score` is the plane
## distance plus how far outside the rectangle the point is; anything above
## `max_score` is not canvas (a rail, the deck or the mast).
func _sail_pick(local: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 1.0e9
	for i: int in _sail_defs.size():
		var def: Dictionary = _sail_defs[i]
		var origin: Vector3 = def["origin"]
		var rel := local - origin
		var px := rel.dot(def["right"])
		var py := rel.dot(def["up"])
		var pz := rel.dot(def["normal"])
		var half_w: float = def["half_w"]
		var half_h: float = def["half_h"]
		var score := absf(pz) + maxf(0.0, absf(px) - half_w) + maxf(0.0, absf(py) - half_h)
		if score < best_score:
			best_score = score
			best = {"def": def, "index": i, "px": px, "py": py, "score": score}
	if best.is_empty():
		return best
	best["score"] = best_score
	return best

func _sail_surface(local: Vector3, max_score: float = 0.9) -> Dictionary:
	if _sail_defs.is_empty() or not local.is_finite():
		return {"ok": false}
	var pick := _sail_pick(local)
	if pick.is_empty():
		return {"ok": false}
	if float(pick["score"]) > max_score:
		return {"ok": false, "score": pick["score"]}
	var def: Dictionary = pick["def"]
	var half_h: float = def["half_h"]
	var py := clampf(float(pick["py"]), -half_h * 0.92, half_h * 0.92)
	var v := clampf(0.5 - py / (2.0 * half_h), 0.0, 1.0)
	var half_w_at: float = def["half_w"]
	if def["kind"] == "square":
		half_w_at = lerpf(float(def["width_top"]), float(def["width_bottom"]), v) * 0.5
	var px := clampf(float(pick["px"]), -half_w_at * 0.92, half_w_at * 0.92)
	var u := clampf(0.5 + px / (2.0 * half_w_at), 0.0, 1.0)
	var belly := sin(u * PI) * sin(v * PI)
	var surface: Vector3 = def["origin"] + def["right"] * px + def["up"] * py \
		+ def["normal"] * (float(def["billow"]) * belly)
	return {
		"ok": true,
		"position": surface,
		"right": def["right"],
		"up": def["up"],
		"normal": def["normal"],
		"sail": def["kind"],
		"u": u,
		"v": v,
		"billow": belly,
	}

## QA: is this ship-local point on canvas?  Used by `ship_boat.apply_hit` to
## classify a hit as `"sail"` before the generic upper-deck fallback.
func sail_zone_at(local_position: Vector3) -> bool:
	return bool(_sail_surface(local_position, 0.8).get("ok", false))

func punch_sail_hole(local_position: Vector3, radius: float) -> Dictionary:
	if not _built or _sail_hole_mm == null:
		return {"ok": false, "reason": "not_built"}
	if not local_position.is_finite() or not is_finite(radius) or radius <= 0.0:
		return {"ok": false, "reason": "bad_input"}
	var surface := _sail_surface(local_position)
	if not bool(surface.get("ok", false)):
		return {"ok": false, "reason": "not_on_sail"}
	var r := clampf(radius, 0.12, 1.10)
	var index := _sail_holes.size()
	var record := {
		"position": surface["position"],
		"radius": r,
		"sail": surface["sail"],
		"right": surface["right"],
		"up": surface["up"],
		"normal": surface["normal"],
		"u": surface["u"],
		"v": surface["v"],
		"index": index,
	}
	if _sail_holes.size() < SAIL_HOLE_CAP:
		_sail_holes.append(record)
		_sail_hole_next = _sail_holes.size() % SAIL_HOLE_CAP
	else:
		index = _sail_hole_next
		record["index"] = index
		_sail_holes[index] = record
		_sail_hole_next = (index + 1) % SAIL_HOLE_CAP
	_write_sail_hole(index)
	_sail_hole_mm.visible = _sail_amount > 0.15
	_stats_cache.clear()
	return {
		"ok": true,
		"index": index,
		"radius": r,
		"sail": record["sail"],
		"position": record["position"],
		"count": _sail_holes.size(),
	}

func _write_sail_hole(index: int) -> void:
	if _sail_hole_mm == null or index < 0 or index >= _sail_holes.size():
		return
	var rec: Dictionary = _sail_holes[index]
	var pos: Vector3 = rec["position"]
	var normal: Vector3 = rec["normal"]
	var radius: float = rec["radius"]
	var basis := Basis(rec["right"], rec["up"], normal)
	var angle := _hash01(int(pos.x * 31.0), int(pos.z * 17.0), index) * TAU
	var spin := Basis(normal, angle)
	# Scale the two in-plane axes, not the world axes: Basis.scaled() works in
	# global space on Godot 4.7, which would shear a hole on the raked jib.
	var quad := spin * Basis(basis.x * radius, basis.y * radius, basis.z)
	var front := Transform3D(quad, pos + normal * 0.025)
	var back := Transform3D(quad, pos - normal * 0.025)
	# The transforms are kept in the record too: headless builds use a dummy
	# MultiMesh implementation where get_instance_transform() cannot be read back.
	rec["front"] = front
	rec["back"] = back
	var mm := _sail_hole_mm.multimesh
	mm.set_instance_transform(index * 2, front)
	mm.set_instance_transform(index * 2 + 1, back)

func sail_hole_count() -> int:
	return _sail_holes.size()

func sail_holes() -> Array:
	return _sail_holes.duplicate(true)

func sail_holes_visible() -> bool:
	return _sail_hole_mm != null and _sail_hole_mm.visible

func _make_sail_mesh(width_top: float, width_bottom: float, height: float, cols: int, rows: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3(0.0, 0.0, -1.0)
	for r: int in rows:
		for c: int in cols:
			var u0 := float(c) / float(cols)
			var u1 := float(c + 1) / float(cols)
			var v0 := float(r) / float(rows)
			var v1 := float(r + 1) / float(rows)
			var w0 := lerpf(width_top, width_bottom, v0) * 0.5
			var w1 := lerpf(width_top, width_bottom, v1) * 0.5
			var p00 := Vector3(lerpf(-w0, w0, u0), -height * v0, 0.0)
			var p10 := Vector3(lerpf(-w0, w0, u1), -height * v0, 0.0)
			var p11 := Vector3(lerpf(-w1, w1, u1), -height * v1, 0.0)
			var p01 := Vector3(lerpf(-w1, w1, u0), -height * v1, 0.0)
			# Curved foot: the clews are pulled up a little.
			if r == rows - 1:
				var lift := 0.14 * sin(u0 * PI)
				p01.y += lift
				p11.y += 0.14 * sin(u1 * PI)
			_sail_vertex(st, p00, normal, Vector2(u0, v0))
			_sail_vertex(st, p10, normal, Vector2(u1, v0))
			_sail_vertex(st, p11, normal, Vector2(u1, v1))
			_sail_vertex(st, p00, normal, Vector2(u0, v0))
			_sail_vertex(st, p11, normal, Vector2(u1, v1))
			_sail_vertex(st, p01, normal, Vector2(u0, v1))
	st.index()
	return st.commit()

func _make_jib_mesh(tack: Vector3, clew: Vector3, steps: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3(0.0, 0.0, 1.0)
	for i: int in steps:
		for j: int in steps - i:
			var s0 := float(i) / float(steps)
			var s1 := float(i + 1) / float(steps)
			var t0 := float(j) / float(steps)
			var t1 := float(j + 1) / float(steps)
			var p00 := tack * s0 + clew * t0
			var p10 := tack * s1 + clew * t0
			var p01 := tack * s0 + clew * t1
			_sail_vertex(st, p00, normal, Vector2(t0, s0 + t0))
			_sail_vertex(st, p10, normal, Vector2(t0, s1 + t0))
			_sail_vertex(st, p01, normal, Vector2(t1, s0 + t1))
			# The second triangle only exists while the cell is inside the
			# head-tack-clew triangle.
			if j < steps - i - 1:
				var p11 := tack * s1 + clew * t1
				_sail_vertex(st, p10, normal, Vector2(t0, s1 + t0))
				_sail_vertex(st, p11, normal, Vector2(t1, s1 + t1))
				_sail_vertex(st, p01, normal, Vector2(t1, s0 + t1))
	st.index()
	return st.commit()

func _sail_vertex(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2, color: Color = Color(1, 1, 1)) -> void:
	st.set_color(color)
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)

# ----------------------------------------------------------------------------- rigging
func _build_rigging() -> void:
	# Only owner-bound chains; do not restore the obsolete floating static lines.
	_build_live_rigging()

# Resolve in Visual space, including when build() runs before entering the tree.
func _rig_owner_transform(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current != _visual and is_instance_valid(current):
		result = current.transform * result
		current = current.get_parent() as Node3D
	return result

func _rig_definition(a_node: Node3D, a: Vector3, b_node: Node3D, b: Vector3, radius: float) -> Dictionary:
	return {"a_node": a_node, "a_local": _rig_owner_transform(a_node).affine_inverse() * a,
		"b_node": b_node, "b_local": _rig_owner_transform(b_node).affine_inverse() * b,
		"a": a, "b": b, "r": radius, "slack": 1.035}

func _rig_owner_visible(node: Variant) -> bool:
	if not is_instance_valid(node) or not node is Node3D:
		return false
	var current: Node3D = node
	while is_instance_valid(current) and current != _visual:
		if not current.visible or current.is_queued_for_deletion():
			return false
		current = current.get_parent() as Node3D
	return current == _visual

## Build the twelve simulated ropes.  Everything is preallocated here: the
## per-frame update only writes into PackedVector3Array slots and MultiMesh
## transforms, so a live rig never allocates while the scene is running.
func _build_live_rigging() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = RIG_ROPE_COUNT * RIG_SEGMENTS
	_rig_live_mm = MultiMeshInstance3D.new()
	_rig_live_mm.name = "RiggingLive"
	_rig_live_mm.multimesh = mm
	_rig_live_mm.material_override = _materials["rope"]
	_rig_live_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_rig_live_mm)

	var defs: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		for z: float in [-2.55, -1.25]:
			defs.append(_rig_definition(_static, Vector3(side * 3.50, 1.78, z),
				_static, Vector3(side * 3.08, 5.16, z), 0.023))
		defs.append(_rig_definition(_static, Vector3(side * 3.08, 5.16, -2.55),
			_mast_lower, Vector3(side * 0.225, 8.35, -1.0), 0.020))
		defs.append(_rig_definition(_mast_upper, Vector3(side * 0.08, 16.10, -1.0),
			_static, Vector3(side * 3.0, 3.03, 11.40), 0.019))
		defs.append(_rig_definition(_rig_upper, Vector3(side * 5.80, 10.35, -1.0),
			_static, Vector3(side * 3.40, 1.78, 1.80), 0.017))
	defs.append(_rig_definition(_mast_upper, Vector3(0.0, 17.05, -1.07),
		_bowsprit_node, Vector3(0.0, 4.45, -18.0), 0.026))
	defs.append(_rig_definition(_mast_upper, Vector3(0.0, 14.95, -1.10),
		_static, Vector3(0.0, 1.78, -10.0), 0.022))

	var count := defs.size()
	_rig_meta = defs
	_rig_a.resize(count)
	_rig_b.resize(count)
	_rig_rest.resize(count)
	_rig_solve.resize(count)
	_rig_slack.resize(count)
	_rig_radius.resize(count)
	_rig_flags.resize(count)
	_rig_points.resize(count * RIG_POINTS)
	_rig_prev.resize(count * RIG_POINTS)
	for r: int in count:
		var def: Dictionary = defs[r]
		var a: Vector3 = def["a"]
		var b: Vector3 = def["b"]
		_rig_a[r] = a
		_rig_b[r] = b
		var slack: float = float(def["slack"])
		_rig_slack[r] = slack
		# Two lengths per rope:
		#  * _rig_rest is the physical rest length with the full configured
		#    slack (1.03–1.045) and is what rigging_snapshot reports.
		#  * _rig_solve adds only a couple of millimetres per segment: the
		#    standing rigging is under tension, so the solver does not let a
		#    20 m stay hang in a half-metre U while the wind and roll still move
		#    the chain.  This is the pretension of a real shroud.
		var straight := a.distance_to(b) / float(RIG_POINTS - 1)
		_rig_rest[r] = maxf(0.12, straight * slack)
		_rig_solve[r] = maxf(0.12, straight + minf(straight * (slack - 1.0), 0.0006))
		_rig_radius[r] = float(def["r"])
		_rig_flags[r] = 0
		var base := r * RIG_POINTS
		for p: int in RIG_POINTS:
			var point := a.lerp(b, float(p) / float(RIG_POINTS - 1))
			_rig_points[base + p] = point
			_rig_prev[base + p] = point
	_rig_has_prev = false
	_rig_wind = Vector3(0.55, 0.04, 0.25)
	# Pre-settle the chains at build time.  A probe that calls
	# rigging_snapshot() in the same frame as build() must already see the
	# gravity sag and the steady wind lean, not a perfectly straight line.
	for step: int in 96:
		_update_live_rigging(1.0 / 60.0)

func _rope_visible(r: int) -> bool:
	var def := _rig_meta[r]
	return _rig_owner_visible(def["a_node"]) and _rig_owner_visible(def["b_node"])

func _update_live_rigging(delta: float) -> void:
	if not is_instance_valid(_rig_live_mm) or _rig_points.is_empty():
		return
	var dt := clampf(delta, 0.0, 0.05)
	_rig_time += dt
	var gt := _visual.global_transform if is_inside_tree() else transform * _visual.transform
	var inv_basis := gt.basis.inverse()
	var gravity := inv_basis * Vector3.DOWN * 9.8
	var speed := 0.0
	var inertia := Vector3.ZERO
	if _rig_has_prev and dt > 0.0001:
		var velocity := (gt.origin - _rig_prev_origin) / dt
		var accel := (velocity - _rig_velocity) / dt
		if not accel.is_finite():
			accel = Vector3.ZERO
		_rig_velocity = _rig_velocity.lerp(velocity, 0.35)
		_rig_accel = _rig_accel.lerp(accel, 0.22)
		speed = velocity.length()
		inertia = inv_basis * (_rig_accel * -0.90)
		inertia = inertia.limit_length(9.0)
		var rel := _rig_prev_basis.inverse() * gt.basis
		var q := rel.orthonormalized().get_rotation_quaternion()
		var angle := q.get_angle()
		if angle > PI:
			angle -= TAU
		if absf(angle) > 0.0001:
			_rig_ang_speed = lerpf(_rig_ang_speed, absf(angle) / dt, 0.18)
		else:
			_rig_ang_speed = lerpf(_rig_ang_speed, 0.0, 0.18)
	_rig_prev_origin = gt.origin
	_rig_prev_basis = gt.basis
	_rig_has_prev = true
	_rig_ang_speed = minf(_rig_ang_speed, 8.0)
	# Slow, slowly-turning wind.  On a moored ship it is barely visible; as the
	# hull gets way on, the flutter term grows and the ropes shiver.
	var wind_target := Vector3(
		sin(_rig_time * 0.23 + 0.7) * 0.75 + 0.45,
		sin(_rig_time * 0.31 + 1.2) * 0.12,
		cos(_rig_time * 0.19) * 0.55 + 0.22)
	_rig_wind = _rig_wind.lerp(wind_target, clampf(dt * 0.30, 0.0, 1.0))
	var vibration := 0.06 + speed * 0.18 + _rig_ang_speed * 0.35 + _shake_amount * 1.4
	var flutter := Vector3(
		sin(_rig_time * 17.0) + sin(_rig_time * 23.0 + 1.3) * 0.6,
		sin(_rig_time * 19.0 + 0.4) * 0.45,
		sin(_rig_time * 13.0 + 2.1) + sin(_rig_time * 29.0 + 0.8) * 0.5) * (vibration * 0.60)
	var force := gravity + _rig_wind + inertia + flutter
	# Apparent wind: when the hull gets way on, the rig trails aft and shivers.
	if speed > 0.05:
		var apparent: Vector3 = inv_basis * (-_rig_velocity * 0.32)
		force += apparent.limit_length(4.0)
	var mm := _rig_live_mm.multimesh
	for r: int in _rig_meta.size():
		var base := r * RIG_POINTS
		var def := _rig_meta[r]
		var visible := _rope_visible(r)
		var a := _rig_a[r]
		var b := _rig_b[r]
		# Broken/removed owners must be checked before dereferencing their transforms.
		if visible:
			a = _rig_owner_transform(def["a_node"]) * def["a_local"]
			b = _rig_owner_transform(def["b_node"]) * def["b_local"]
		var straight := a.distance_to(b) / float(RIG_SEGMENTS)
		_rig_rest[r] = maxf(0.12, straight * _rig_slack[r])
		_rig_solve[r] = maxf(0.12, straight + minf(straight * (_rig_slack[r] - 1.0), 0.0006))
		_rig_a[r] = a
		_rig_b[r] = b
		if not visible or dt <= 0.0:
			for p: int in RIG_POINTS:
				var rest_point := a.lerp(b, float(p) / float(RIG_POINTS - 1))
				_rig_points[base + p] = rest_point
				_rig_prev[base + p] = rest_point
		else:
			_rig_points[base] = a
			_rig_points[base + RIG_POINTS - 1] = b
			for p: int in range(1, RIG_POINTS - 1):
				var idx := base + p
				var velocity := (_rig_points[idx] - _rig_prev[idx]) * 0.90
				_rig_prev[idx] = _rig_points[idx]
				var next := _rig_points[idx] + velocity + force * dt * dt
				if not next.is_finite():
					next = a.lerp(b, float(p) / float(RIG_POINTS - 1))
				_rig_points[idx] = next
			var rest: float = _rig_solve[r]
			for iteration: int in 4:
				for p: int in range(RIG_POINTS - 1):
					var i0 := base + p
					var i1 := base + p + 1
					var dv := _rig_points[i1] - _rig_points[i0]
					var distance := dv.length()
					if distance < 0.0001:
						continue
					var correction := (distance - rest) / distance * 0.5
					if p > 0:
						_rig_points[i0] += dv * correction
					if p + 1 < RIG_POINTS - 1:
						_rig_points[i1] -= dv * correction
				_rig_points[base] = a
				_rig_points[base + RIG_POINTS - 1] = b
			# Pretension toward the straight chord.  Standing rigging does not
			# hang loose: the pull keeps the sag in the 1–4 cm range while the
			# wind/inertia still bend the rope away from the chord every frame.
			var span := a.distance_to(b)
			var chord_pull := clampf(0.01 + span * 0.0012, 0.01, 0.05)
			for p: int in range(1, RIG_POINTS - 1):
				var idx := base + p
				var line := a.lerp(b, float(p) / float(RIG_POINTS - 1))
				_rig_points[idx] = _rig_points[idx].lerp(line, chord_pull)
			# Hard safety rail: no point may wander far from its rest chord and
			# no point may move more than 0.6 m per frame.  The rail scales with
			# the rope span, so a 20 m stay may sag a few centimetres without
			# being clipped into a kink, while a real explosion is still caught.
			var max_offset := clampf(span * 0.08, 0.25, 1.10)
			for p: int in range(1, RIG_POINTS - 1):
				var idx := base + p
				var line := a.lerp(b, float(p) / float(RIG_POINTS - 1))
				var offset := _rig_points[idx] - line
				if offset.length() > max_offset:
					_rig_points[idx] = line + offset.normalized() * max_offset
				var displacement := _rig_points[idx] - _rig_prev[idx]
				if displacement.length() > 0.6:
					_rig_points[idx] = _rig_prev[idx] + displacement.normalized() * 0.6
		var radius := _rig_radius[r]
		for s: int in RIG_SEGMENTS:
			var slot := r * RIG_SEGMENTS + s
			if not visible:
				mm.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ZERO), a))
				continue
			var pa := _rig_points[base + s]
			var pb := _rig_points[base + s + 1]
			var segment := pb - pa
			var length := segment.length()
			if length < 0.005:
				mm.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ZERO), pa))
				continue
			var y_axis := segment / length
			var x_axis := y_axis.cross(Vector3.UP)
			if x_axis.length_squared() < 0.0001:
				x_axis = y_axis.cross(Vector3.RIGHT)
			x_axis = x_axis.normalized()
			var z_axis := x_axis.cross(y_axis).normalized()
			var basis := Basis(x_axis * radius, y_axis * length, z_axis * radius)
			mm.set_instance_transform(slot, Transform3D(basis, (pa + pb) * 0.5))


func _make_ropes(segments: Array, node_name: String, parent: Node3D, upper: bool) -> void:
	if segments.is_empty():
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.02
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = segments.size()
	for i: int in segments.size():
		var seg: Dictionary = segments[i]
		var a: Vector3 = seg["a"]
		var b: Vector3 = seg["b"]
		var r: float = seg["r"]
		var delta := b - a
		var length := delta.length()
		if length < 0.0005:
			mm.set_instance_transform(i, Transform3D(Basis(), a))
			continue
		var dir := delta / length
		var ref := Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var x_axis := ref.cross(dir).normalized()
		var z_axis := x_axis.cross(dir).normalized()
		var basis := Basis(x_axis, dir, z_axis)
		var scaled := basis.scaled(Vector3(r / 0.02, length, r / 0.02))
		mm.set_instance_transform(i, Transform3D(scaled, (a + b) * 0.5))
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = _materials["rope"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

# ----------------------------------------------------------------------------- flags
## All flags are cloth meshes driven by a TIME shader: a long tapered masthead
## pennant, the stern ensign, a bow jack on the bowsprit staff, a small fighting
## top flag and three signal flags bent onto the live shrouds.  Each flies aft
## or outboard of the mast so it never sits between the helm camera and the bow.
func _build_flags() -> void:
	_flags.clear()
	# 1. Long, tapered masthead pennant on the breakable upper rig.
	var pennant := _make_cloth(Vector3(0.0, 17.48, -1.0), 4.20, 0.58, 16, 3,
		Color(1, 1, 1), 0.86, "pennant", _rig_upper, deg_to_rad(-45.0), false)
	pennant.name = "MastPennant"
	_register_flag("pennant", pennant, true, false)
	_tube("yard_iron", Vector3(0.0, 17.0, -1.0), Vector3(0.0, 17.7, -1.0), 0.035, 0.025, 5, Color(1, 1, 1))
	# 2. Stern ensign on its staff.  Deliberately high above the helm camera.
	var stern_flag := _make_cloth(Vector3(0.0, 7.55, 12.58), 1.90, 0.78, 10, 4,
		Color(1, 1, 1), 0.0, "flag", _visual, 0.0, false)
	stern_flag.name = "SternEnsign"
	_register_flag("ensign", stern_flag, false, false)
	# 3. Bow jack on a short staff at the bowsprit tip; breaks with the spar.
	_tube("bowsprit_iron", Vector3(0.0, 2.00, -5.75), Vector3(0.0, 2.92, -5.75),
		0.030, 0.018, 5, Color(1, 1, 1))
	var jack := _make_cloth(Vector3(0.0, 2.86, -5.78), 1.05, 0.62, 8, 3,
		Color(0.075, 0.135, 0.360), 0.0, "flag_signal", _bowsprit_node,
		deg_to_rad(-15.0), false)
	jack.name = "BowJack"
	_register_flag("jack", jack, false, true)
	# 4. Fighting-top flag on a staff at the PORT after corner (left of the helm
	# view; it used to sit dead centre on the starboard side and block the bow).
	_tube("upper_rail", Vector3(-2.80, 5.24, 1.62), Vector3(-2.80, 6.58, 1.62),
		0.030, 0.018, 5, Color(0.29, 0.19, 0.105))
	var top_flag := _make_cloth(Vector3(-2.80, 6.52, 1.62), -0.92, 0.52, 8, 3,
		Color(0.095, 0.300, 0.135), 0.0, "flag_signal", _visual, deg_to_rad(-90.0), true)
	top_flag.name = "TopFlag"
	_register_flag("top", top_flag, false, false)
	# 5. Three small signal flags: red and yellow on the starboard shrouds, blue
	# on the port side.  Only the fighting-top flag moved left of the helm view.
	var shroud_signals := [
		{"x": 3.380, "y": 4.578, "z": -2.693, "hx": 3.920, "hy": 2.620, "hz": -2.550,
			"color": Color(0.640, 0.080, 0.060), "len": 0.46},
		{"x": 3.420, "y": 4.420, "z": -2.235, "hx": 3.920, "hy": 2.620, "hz": -1.250,
			"color": Color(0.820, 0.620, 0.145), "len": 0.42},
		{"x": -3.380, "y": 4.578, "z": -1.800, "hx": -3.920, "hy": 2.620, "hz": -1.650,
			"color": Color(0.090, 0.165, 0.420), "len": 0.44},
	]
	for spec: Dictionary in shroud_signals:
		var p := Vector3(float(spec["x"]), float(spec["y"]), float(spec["z"]))
		var hull_point := Vector3(float(spec["hx"]), float(spec["hy"]), float(spec["hz"]))
		var hang := (hull_point - p).normalized()
		var normal := hang.cross(Vector3(0.0, 0.0, 1.0))
		if normal.length_squared() < 0.0001:
			normal = Vector3.RIGHT
		normal = normal.normalized()
		var width_axis := normal.cross(hang).normalized()
		_tube("static_rope", p, p + hang * 0.10, 0.012, 0.012, 4, Color(1, 1, 1), false)
		var tint: Color = spec["color"]
		var flag := _make_cloth(p, float(spec["len"]), 0.24, 6, 3,
			tint, 0.45, "flag_signal", _visual, 0.0, false)
		flag.name = "SignalFlag"
		flag.transform = Transform3D(Basis(hang, width_axis, normal), p)
		_register_flag("signal", flag, false, false)
	_flag_count = _flags.size()

func _make_cloth(at: Vector3, length: float, height: float, cols: int, rows: int,
		color: Color, taper: float, material_name: String, parent: Node3D,
		yaw: float, mirror: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3(0.0, 0.0, 1.0)
	for c: int in cols:
		for r: int in rows:
			var u0 := float(c) / float(cols)
			var u1 := float(c + 1) / float(cols)
			var v0 := float(r) / float(rows)
			var v1 := float(r + 1) / float(rows)
			var w0 := height * (1.0 - taper * u0)
			var w1 := height * (1.0 - taper * u1)
			var p00 := Vector3(length * u0, 0.0, 0.0)
			var p10 := Vector3(length * u1, 0.0, 0.0)
			var p11 := Vector3(length * u1, -w1, 0.0)
			var p01 := Vector3(length * u0, -w0, 0.0)
			_sail_vertex(st, p00, normal, Vector2(u0, v0), color)
			_sail_vertex(st, p10, normal, Vector2(u1, v0), color)
			_sail_vertex(st, p11, normal, Vector2(u1, v1), color)
			_sail_vertex(st, p00, normal, Vector2(u0, v0), color)
			_sail_vertex(st, p11, normal, Vector2(u1, v1), color)
			_sail_vertex(st, p01, normal, Vector2(u0, v1), color)
	st.index()
	var mi := MeshInstance3D.new()
	mi.name = "Flag"
	mi.mesh = st.commit()
	mi.material_override = _materials[material_name]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi

func _register_flag(kind: String, node: MeshInstance3D, upper: bool, bow: bool) -> void:
	_flags.append({"kind": kind, "node": node, "upper": upper, "bow": bow})
	_flag_count = _flags.size()

func _live_flag_count() -> int:
	var count := 0
	for entry: Dictionary in _flags:
		var node: Variant = entry["node"]
		if is_instance_valid(node) and node.is_visible_in_tree():
			count += 1
	return count

# ----------------------------------------------------------------------------- lanterns
func _build_lanterns() -> void:
	_lantern(Vector3(-2.24, 4.45, 12.56), 1.0, false)
	_lantern(Vector3(2.24, 4.45, 12.56), 1.0, true)
	_lantern(Vector3(0.94, 3.62, 10.15), 0.78, true)
	_lantern(Vector3(-2.30, 3.78, 6.55), 0.85, false)
	_lantern(Vector3(2.85, 2.55, -11.20), 0.75, false)

func _lantern(at: Vector3, scale: float, with_light: bool) -> void:
	var h := 0.30 * scale
	var w := 0.18 * scale
	_tube("lantern_iron", at + Vector3(0.0, -h * 0.5, 0.0), at + Vector3(0.0, h * 0.5, 0.0),
		0.012, 0.012, 4, Color(1, 1, 1), false)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box("lantern_iron", at + Vector3(sx * w * 0.5, 0.0, sz * w * 0.5), Vector3(0.018 * scale, h, 0.018 * scale), Color(1, 1, 1))
	_box("lantern_glass", at, Vector3(w * 0.92, h * 0.78, w * 0.92), Color(1, 1, 1))
	_tube("lantern_gold", at + Vector3(0.0, h * 0.55, 0.0), at + Vector3(0.0, h * 0.80, 0.0),
		w * 0.62, 0.02 * scale, 8, Color(1, 1, 1))
	_box("lantern_gold", at + Vector3(0.0, -h * 0.52, 0.0), Vector3(w, 0.03 * scale, w), Color(1, 1, 1))
	_ring("lantern_iron", at + Vector3(0.0, h * 0.86, 0.0), Vector3.UP, 0.045 * scale, 0.010 * scale, 6, Color(1, 1, 1))
	if with_light:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = Color(1.0, 0.70, 0.38)
		light.light_energy = 1.15
		light.omni_range = 5.2
		light.shadow_enabled = false
		_lanterns_node.add_child(light)
		_lantern_lights.append(light)

# ----------------------------------------------------------------------------- holes
func _build_holes() -> void:
	_hole_mesh = _make_hole_mesh()
	for i: int in HOLE_CAP:
		var mi := MeshInstance3D.new()
		mi.name = "Hole%d" % i
		mi.mesh = _hole_mesh
		mi.material_override = _materials["char"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_visual.add_child(mi)
		_holes.append(mi)

func _make_hole_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	var dark := Color(0.018, 0.016, 0.014)
	var ember := Color(0.10, 0.055, 0.03)
	var splinter := Color(0.42, 0.295, 0.17)
	var splinter_dark := Color(0.24, 0.16, 0.09)
	var segments := 11
	var ring: Array[Vector3] = []
	for i: int in segments:
		var a := TAU * float(i) / float(segments)
		var r := 0.82 + 0.20 * sin(float(i) * 2.3 + 0.7)
		ring.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for i: int in segments:
		var a0: Vector3 = ring[i]
		var a1: Vector3 = ring[(i + 1) % segments]
		_tri_color(st, center, a1, a0, dark, Vector3.UP)
	for i: int in segments:
		var a0: Vector3 = ring[i]
		var a1: Vector3 = ring[(i + 1) % segments]
		# Splintered boards around the rim: two shards per segment pointing out.
		var mid := (a0 + a1) * 0.5
		var outward := Vector3(mid.x, 0.0, mid.z).normalized()
		var tip := mid + outward * (0.35 + 0.30 * absf(sin(float(i) * 1.7)))
		var side := a1 - a0
		_tri_color(st, mid, a0 + outward * 0.04, tip, splinter, Vector3.UP)
		_tri_color(st, mid, tip, a1 + outward * 0.04, splinter_dark, Vector3.UP)
		# Small dark cracks radiating past the shards.
		if i % 2 == 0:
			_tri_color(st, mid, mid + outward * 0.95, mid + side * 0.10, ember, Vector3.UP)
	st.index()
	return st.commit()

func _tri_color(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3) -> void:
	# Clockwise front faces, same convention as _tri/_quad.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)
	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(Vector2.ONE)
	st.add_vertex(b)
	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(Vector2.ONE)
	st.add_vertex(c)

func _basis_for_normal(normal: Vector3) -> Basis:
	var n := normal.normalized()
	if n.dot(Vector3.UP) > 0.999:
		return Basis.IDENTITY
	if n.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	var x_axis := Vector3.UP.cross(n).normalized()
	var z_axis := x_axis.cross(n).normalized()
	# This basis maps +Y to n and stays orthonormal for horizontal normals too:
	# `x_axis.cross(Vector3.UP)` collapsed to `n` there and the hole decal became
	# a zero-area sliver (found by agent T on the second ship).
	return Basis(x_axis, n, z_axis)

# ----------------------------------------------------------------------------- debris
func _build_debris() -> void:
	# A set of pre-built wrecks, hidden until a part is shot away.  They live in
	# ship coordinates under the visual node.
	for key: String in ["mast", "rails", "crate_ammo", "crate_boards", "helm", "transom", "bowsprit", "upper_rail", "cannon_0", "cannon_1", "cannon_2", "cannon_3"]:
		var node := Node3D.new()
		node.name = "Wreck_" + key
		node.visible = false
		_visual.add_child(node)
		_debris[key] = node
		_register("debris_" + key + "_wood", "wood", node, true)
		_register("debris_" + key + "_dark", "wood_dark", node, true)
		_register("debris_" + key + "_iron", "iron", node, false)
		_register("debris_" + key + "_rope", "rope", node, false)
	# Fallen topmast and yard across the waist.
	var mast_wreck: Node3D = _debris["mast"]
	_tube("debris_mast_wood", Vector3(-4.60, 2.55, 3.35), Vector3(4.40, 2.30, 2.70), 0.19, 0.15, 8, Color(0.29, 0.19, 0.11))
	_tube("debris_mast_wood", Vector3(-5.10, 2.30, 4.10), Vector3(5.00, 2.05, 3.30), 0.10, 0.07, 7, Color(0.32, 0.205, 0.12))
	for i: int in 8:
		var p := Vector3(-4.0 + float(i) * 1.1, 2.05 + 0.12 * sin(float(i)), 3.0 + 0.3 * cos(float(i) * 1.7))
		_box("debris_mast_dark", p, Vector3(0.55, 0.055, 0.10), Color(0.38, 0.25, 0.145),
			Basis(Vector3.UP, 0.4 + float(i) * 0.2))
	_ring("debris_mast_rope", Vector3(-1.10, 2.40, 3.20), Vector3.RIGHT, 0.24, 0.03, 8, Color(1, 1, 1))
	# Broken rails at the break and the taffrail.
	var rails_wreck: Node3D = _debris["rails"]
	for i: int in 5:
		var x := -2.60 + float(i) * 1.30
		_box("debris_rails_dark", Vector3(x, 3.35, 6.14), Vector3(0.09, 0.62, 0.09), Color(0.29, 0.19, 0.105),
			Basis(Vector3.RIGHT, 0.10 + 0.06 * float(i)))
	for i: int in 4:
		_box("debris_rails_dark", Vector3(-1.8 + float(i) * 1.2, 3.06, 6.30 + 0.2 * float(i)),
			Vector3(0.62, 0.07, 0.07), Color(0.31, 0.20, 0.115), Basis(Vector3.UP, 0.3 * float(i)))
	# Shot-apart crates.
	var ammo_wreck: Node3D = _debris["crate_ammo"]
	for i: int in 5:
		_box("debris_crate_ammo_wood", Vector3(-2.0 + float(i) * 0.26 - 0.5, 0.56 + 0.05 * float(i), 10.2 + 0.5 * float(i)),
			Vector3(0.85, 0.055, 0.20), Color(0.42, 0.29, 0.17), Basis(Vector3.UP, -0.5 + float(i) * 0.4))
	for i: int in 3:
		_sphere("debris_crate_ammo_iron", Vector3(-2.3 + float(i) * 0.3, 0.64, 10.0 + float(i) * 0.2), 0.13,
			Color(0.28, 0.28, 0.30), 4, 7)
	var boards_wreck: Node3D = _debris["crate_boards"]
	for i: int in 6:
		_box("debris_crate_boards_wood", Vector3(2.0 - 0.6 + float(i) * 0.24, 0.56 + 0.04 * (i % 3), 10.2 - 0.4 + 0.2 * float(i)),
			Vector3(0.24, 0.05, 1.10), Color(0.50, 0.38, 0.25), Basis(Vector3.UP, -0.35 + float(i) * 0.2))
	# Wrecked cannon carriages.
	for i: int in 4:
		var side := -1.0 if i < 2 else 1.0
		var z: float = PORT_Z[i % 2]
		var key := "debris_cannon_%d" % i
		var node: Node3D = _debris["cannon_%d" % i]
		_box(key + "_wood", Vector3(side * 3.20, DECK_Y + 0.10, z + 0.10), Vector3(0.18, 0.16, 1.10),
			Color(0.30, 0.20, 0.12), Basis(Vector3.UP, side * 0.30))
		_box(key + "_dark", Vector3(side * 2.95, DECK_Y + 0.22, z - 0.30), Vector3(0.80, 0.12, 0.20),
			Color(0.26, 0.17, 0.10), Basis(Vector3.UP, side * 0.7))
		_tube(key + "_iron", Vector3(side * 3.55, DECK_Y + 0.22, z + 0.30), Vector3(side * 2.75, DECK_Y + 0.22, z + 0.55),
			0.19, 0.19, 10, Color(1, 1, 1))
	# Broken helm.
	_box("debris_helm_dark", Vector3(0.0, 3.45, 10.30), Vector3(0.12, 0.90, 0.12), Color(0.28, 0.18, 0.10),
		Basis(Vector3.RIGHT, 0.18))
	_box("debris_helm_wood", Vector3(0.35, 3.08, 10.55), Vector3(0.50, 0.06, 0.50), Color(0.30, 0.20, 0.115),
		Basis(Vector3.UP, 0.6))
	_ring("debris_helm_wood", Vector3(0.55, 3.12, 10.62), Vector3.UP, 0.30, 0.035, 10, Color(0.30, 0.20, 0.115))
	# Scorched transom panel.
	_box("debris_transom_dark", Vector3(0.0, 2.55, 13.03), Vector3(3.5, 1.35, 0.08), Color(0.10, 0.075, 0.055))
	for i: int in 6:
		_box("debris_transom_wood", Vector3(-2.2 + float(i) * 0.85, 2.45 + 0.18 * float(i % 2), 13.10),
			Vector3(0.20, 0.95, 0.05), Color(0.33, 0.215, 0.125), Basis(Vector3.BACK, -0.2 + 0.12 * float(i)))
	# Splintered bowsprit stump.
	_tube("debris_bowsprit_wood", Vector3(0.0, 2.40, -12.25), Vector3(0.0, 2.85, -13.30), 0.23, 0.15, 8, Color(0.30, 0.195, 0.11))
	for i: int in 4:
		_box("debris_bowsprit_dark", Vector3(-0.12 + 0.08 * float(i), 2.82, -13.35 - 0.05 * float(i)),
			Vector3(0.05, 0.36, 0.05), Color(0.38, 0.25, 0.145), Basis(Vector3.RIGHT, 0.2 + 0.15 * float(i)))
	# Upper rail stumps.
	for i: int in 4:
		var p := Vector3(-2.2 + float(i) * 1.45, 5.55, -4.10)
		_box("debris_upper_rail_dark", p, Vector3(0.09, 0.55, 0.09), Color(0.29, 0.19, 0.105),
			Basis(Vector3.RIGHT, 0.16 * float(i)))

func _commit_temp(key: String, material: Material, parent: Node3D, shadows: bool) -> MeshInstance3D:
	if not _batches.has(key):
		return null
	var st: SurfaceTool = _batches[key]
	_batches.erase(key)
	if not _batch_used.get(key, false):
		return null
	_batch_used.erase(key)
	st.index()
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() <= 0:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_cannonballs() -> void:
	# Loose decorative balls are gone; the host places four real pickable balls
	# beside the guns instead.
	return
	var mesh := SphereMesh.new()
	mesh.radius = 0.125
	mesh.height = 0.25
	mesh.radial_segments = 8
	mesh.rings = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = _cannonball_slots.size()
	for i: int in _cannonball_slots.size():
		mm.set_instance_transform(i, Transform3D(Basis(), _cannonball_slots[i]))
	_cannonball_mm = MultiMeshInstance3D.new()
	_cannonball_mm.name = "Cannonballs"
	_cannonball_mm.multimesh = mm
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.20, 0.205, 0.22)
	iron.metallic = 0.9
	iron.roughness = 0.38
	_cannonball_mm.material_override = iron
	_cannonball_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_cannonball_mm)

# ----------------------------------------------------------------------------- collision
## Collision entries are plain dictionaries so `ship_boat.gd` can turn every one of
## them into a BoxShape3D.  `part` is optional: when a destructible part is shot
## away, the boat disables the shapes that carry its id, so a broken wheel or gun
## stops being an invisible wall.
func _add_collision(pos: Vector3, size: Vector3, yaw: float = 0.0, part: String = "") -> void:
	_collision.append({"position": pos, "size": size, "rotation_y": yaw, "part": part})

func _build_collision() -> void:
	_collision.clear()
	# Hull sides: stepped boxes that follow the taper, plus a solid bottom.
	# The tall sides follow the bulwark up to the cap rail so a player cannot walk
	# over the side on the main deck or the quarterdeck.  The foremost span stays
	# low because the bow platform hangs above it; the platform gets its own rails.
	_add_collision(Vector3(0.0, -1.75, 0.0), Vector3(5.4, 1.0, 24.0))
	var spans := [
		[-13.0, -11.0, 1.10, 2.05], [-11.0, -9.0, 2.70, 2.90], [-9.0, -6.0, 4.05, 2.82],
		[-6.0, 0.0, 4.28, 2.82], [0.0, 6.0, 4.30, 2.86], [6.0, 10.0, 4.00, 3.86],
		[10.0, 13.0, 3.70, 3.86],
	]
	for span: Array in spans:
		var z0: float = span[0]
		var z1: float = span[1]
		var half: float = span[2]
		var top: float = span[3]
		var bottom := -1.85
		for side: float in [-1.0, 1.0]:
			_add_collision(Vector3(side * (half - 0.26), (top + bottom) * 0.5, (z0 + z1) * 0.5),
				Vector3(0.52, top - bottom, z1 - z0 + 0.06))
	# Solid bow volume stays below the platform deck (2.18): it used to rise to
	# 2.80 and formed an invisible wall across the middle of the bow platform.
	_add_collision(Vector3(0.0, 0.96, -12.95), Vector3(2.0, 2.32, 0.7))
	_add_collision(Vector3(0.0, 1.45, 12.72), Vector3(6.6, 4.4, 0.45))
	# Main deck, in width steps so the bow does not have invisible floor.  The
	# centre is cut away from COMPANION_Z0 aft so the companionway opening is real.
	_add_collision(Vector3(0.0, 1.74, -12.0), Vector3(1.90, 0.08, 2.0))
	_add_collision(Vector3(0.0, 1.74, -9.5), Vector3(4.30, 0.08, 3.0))
	_add_collision(Vector3(0.0, 1.74, -6.0), Vector3(6.90, 0.08, 4.0))
	_add_collision(Vector3(0.0, 1.74, (-7.8 + COMPANION_Z0) * 0.5),
		Vector3(7.82, 0.08, COMPANION_Z0 + 7.8))
	# Side decks beside the companionway opening (the centre stays open).
	for side: float in [-1.0, 1.0]:
		_add_collision(Vector3(side * 2.555, 1.74, (COMPANION_Z0 + 5.29) * 0.5),
			Vector3(2.71, 0.08, 5.29 - COMPANION_Z0))
	_add_collision(Vector3(-2.55, 1.74, 5.65), Vector3(2.56, 0.08, 0.72))
	_add_collision(Vector3(2.55, 1.74, 5.65), Vector3(2.56, 0.08, 0.72))
	# Quarterdeck and cabin.
	_add_collision(Vector3(0.0, 2.995, 9.25), Vector3(6.86, 0.08, 6.4))
	_add_collision(Vector3(0.0, 0.48, 9.20), Vector3(6.40, 0.08, 6.2))
	for side: float in [-1.0, 1.0]:
		_add_collision(Vector3(side * 3.33, 1.72, 9.20), Vector3(0.14, 2.40, 6.2))
		_add_collision(Vector3(side * 2.25, 1.72, 6.00), Vector3(2.10, 2.40, 0.16))
	# No lintel box over the doorway: the 2.4 m-wide opening runs up to the ceiling
	# slab.  A 1.9 m character descending the companionway gets under the slab
	# before its front edge thanks to the longer opening and six shallow treads.
	# Companionway: six treads and the well sides.
	for i: int in STEP_TOPS.size():
		var top: float = STEP_TOPS[i]
		_add_collision(Vector3(0.0, top - 0.06, STEP_BASE_Z + float(i) * STEP_PITCH),
			Vector3(2.32, 0.12, 0.34))
	for side: float in [-1.0, 1.0]:
		# SHIP69: the well wall now runs 0.45 m above the deck as the visible
		# companionway coaming, so stepping sideways off the narrow side deck
		# into the open well is blocked.  The head of the stair (z=4.6) still
		# opens onto the first tread and the doorway at z=6.0 stays clear.
		_add_collision(Vector3(side * 1.32, 1.34, 5.31), Vector3(0.20, 1.78, 1.40))
	# Stairs to the quarterdeck, both sides.
	var q_tops := [2.17, 2.59, 3.01]
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			_add_collision(Vector3(side * 2.72, q_tops[i] - 0.06, 5.40 + float(i) * 0.25), Vector3(0.96, 0.12, 0.34))
	# Upper deck, its ladder and its rails.  The ladder is a climb zone in
	# `ship_boat.climb_assist`, not twelve blocking boxes: the old rung
	# colliders stopped the player at the foot of the ladder (he could not even
	# enter the zone, and could not step down from the top).
	_add_collision(Vector3(0.0, 5.19, -1.20), Vector3(6.36, 0.08, 5.96))
	for side: float in [-1.0, 1.0]:
		_add_collision(Vector3(side * 3.14, UPPER_Y + 0.42, -1.20), Vector3(0.10, 0.86, 5.90))
	_add_collision(Vector3(-2.05, UPPER_Y + 0.42, 1.72), Vector3(2.20, 0.86, 0.10))
	_add_collision(Vector3(2.05, UPPER_Y + 0.42, 1.72), Vector3(2.20, 0.86, 0.10))
	_add_collision(Vector3(0.0, UPPER_Y + 0.42, -4.13), Vector3(6.30, 0.86, 0.10))
	# Bow platform and its two steps.
	_add_collision(Vector3(0.0, 2.14, -12.70), Vector3(4.40, 0.08, 1.80))
	# Bridge the small gap between the main-deck edge and the raised platform,
	# and extend the platform toe forward so a jump on the nose cannot slip
	# through the front edge.
	_add_collision(Vector3(0.0, 1.86, -11.40), Vector3(4.20, 0.08, 1.10))
	_add_collision(Vector3(0.0, 2.14, -13.95), Vector3(4.20, 0.08, 1.10))
	_add_collision(Vector3(0.0, 2.42, -14.50), Vector3(4.20, 0.50, 0.10))
	_add_collision(Vector3(0.0, 1.90, -11.72), Vector3(2.60, 0.10, 0.34))
	_add_collision(Vector3(0.0, 2.04, -12.06), Vector3(2.60, 0.10, 0.34))
	# Bow platform rail: sides and the head rail, matching the visible timber.
	for side: float in [-1.0, 1.0]:
		_add_collision(Vector3(side * 2.02, 2.42, -12.70), Vector3(0.10, 0.50, 1.80))
	_add_collision(Vector3(0.0, 2.42, -13.50), Vector3(4.10, 0.50, 0.10))
	# Quarterdeck break rail: centre section only, open at both side stairs.
	_add_collision(Vector3(0.0, 3.46, 6.10), Vector3(2.10, 0.80, 0.12))
	# The helm: a solid stand and the wheel.  The player stops at the wheel from
	# the front and still fits on the stand point (0, 3.06, 11.15) behind it.
	_add_collision(Vector3(0.0, 3.55, 10.50), Vector3(1.30, 1.02, 0.42), 0.0, "helm")
	_add_collision(Vector3(0.0, 4.11, 10.61), Vector3(1.80, 1.80, 0.20), 0.0, "helm")
	# Gun carriages: a 0.7 m high block around each mount.  The gunner stands
	# 1.2 m inboard of the mount, so he is clear of the box.
	for i: int in 4:
		var side := -1.0 if i < 2 else 1.0
		var z: float = PORT_Z[i % 2]
		_add_collision(Vector3(side * 3.55, DECK_Y + 0.36, z),
			Vector3(1.10, 0.72, 1.35), 0.0, "cannon_%d" % i)
	# SHIP69 deck safety.  Two floor patches close the real holes: the z -9..-8
	# deck step (the hull collision widens to 3.53 there while the old floor
	# stayed 2.15 wide) and the bow trench / bow-platform shoulders
	# (z -11.95..-10.9).  Both stay inside the visible hull; the bow patch is
	# tucked under the overhanging bow platform, so neither can read as an
	# invisible shelf out over the water.
	_add_collision(Vector3(0.0, 1.74, -8.50), Vector3(6.90, 0.08, 1.00))
	_add_collision(Vector3(0.0, 1.74, -11.45), Vector3(4.30, 0.08, 1.10))
	# Catch net under the main deck: a body that finds any remaining seam lands
	# on it (local y ~= 1.0) instead of dropping under the hull into the water.
	# It stops at the companionway (z=4.55) and before the bow taper (z=-9), so
	# it never enters the cabin, the treads or the ladder climb zone, and it
	# never becomes an invisible floor outside the hull.  The companionway
	# coaming is the raised well-wall pair above (no extra boxes).
	_add_collision(Vector3(0.0, 1.02, -2.225), Vector3(7.70, 0.08, 13.55))
	# Real bulwark collision above follows visible timber. Extra invisible
	# perimeter caps prevented intentional jumps overboard and are omitted.

func _build_parts() -> void:
	_parts.clear()
	_part_by_id.clear()
	var entries := [
		["mast", 80.0, _mast_node],
		["mast_lower", 100.0, _mast_lower],
		["mast_upper", 80.0, _mast_upper],
		["bowsprit", 55.0, _bowsprit_node],
		["rails", 55.0, _rails_node],
		["transom", 85.0, _transom_node],
		["helm", 50.0, _helm_node],
		["crate_ammo", 20.0, _crate_ammo],
		["crate_boards", 20.0, _crate_boards],
		["cannon_0", 55.0, _cannon_nodes[0]],
		["cannon_1", 55.0, _cannon_nodes[1]],
		["cannon_2", 55.0, _cannon_nodes[2]],
		["cannon_3", 55.0, _cannon_nodes[3]],
		["upper_rail", 50.0, _upper_rail_node],
		["lanterns", 10.0, _lanterns_node],
	]
	for entry: Array in entries:
		var data := {"id": entry[0], "hp": entry[1], "node": entry[2]}
		_parts.append(data)
		_part_by_id[entry[0]] = data

func _build_walk() -> void:
	_walk = {
		"main": [
			Vector3(-3.2, 1.78, -6.0), Vector3(0.0, 1.78, -8.0), Vector3(3.2, 1.78, -2.0),
			Vector3(0.0, 1.78, 0.0), Vector3(-3.0, 1.78, 3.2), Vector3(2.0, 1.78, 4.6),
			Vector3(0.0, 1.78, -3.0), Vector3(-2.4, 1.78, -10.5),
		],
		"quarter": [
			Vector3(-2.8, 3.03, 7.2), Vector3(0.0, 3.03, 8.6), Vector3(0.0, 3.03, 10.4),
			Vector3(2.4, 3.03, 11.6), Vector3(0.0, 3.03, 12.0), Vector3(-2.6, 3.03, 9.6),
		],
		"upper": [
			Vector3(0.0, 5.23, 1.0), Vector3(0.0, 5.23, -1.2), Vector3(-2.6, 5.23, -3.2),
			Vector3(2.6, 5.23, -3.2), Vector3(0.0, 1.78, 2.3), Vector3(0.0, 5.23, 1.85),
		],
		"cabin": [
			Vector3(0.0, 0.52, 7.0), Vector3(0.0, 0.52, 9.0), Vector3(0.0, 0.52, 11.0),
			Vector3(-2.4, 0.52, 9.4), Vector3(2.4, 0.52, 9.4), Vector3(0.0, 0.52, 6.3),
		],
	}

# ----------------------------------------------------------------------------- anchors
func _make_anchors() -> Dictionary:
	var cannons: Array = []
	for i: int in 4:
		var side := -1.0 if i < 2 else 1.0
		var z: float = PORT_Z[i % 2]
		cannons.append({
			"index": i,
			"side": "port" if side < 0.0 else "starboard",
			"node": _cannon_nodes[i],
			"mount": Vector3(side * 3.55, DECK_Y, z),
			"pivot": _cannon_pivots[i],
			"barrel": _cannon_barrels[i],
			"muzzle": Vector3(side * 4.90, 2.30, z),
		})
	return {
		"ok": true,
		"length": LENGTH,
		"beam": BEAM,
		"deck_y": DECK_Y,
		"helm": {"node": _helm_node, "position": HELM_POS},
		"sail_lever": {"node": _lever_node, "position": LEVER_POS},
		"mast": {"node": _mast_node, "base": MAST_BASE, "top": MAST_TOP},
		"sails": {"node": _sails_node},
		"upper_deck": {"node": _upper_deck_node, "position": UPPER_POS, "ladder_base": LADDER_BASE},
		"bow": {"node": _bow_node, "position": BOW_POS},
		"cannons": cannons,
		"crates": {
			"ammo": {"node": _crate_ammo, "position": Vector3(-2.0, 0.95, 10.2)},
			"boards": {"node": _crate_boards, "position": Vector3(2.0, 0.95, 10.2)},
		},
		"collision": _collision,
		"walk": _walk,
		"parts": _parts,
	}

# ----------------------------------------------------------------------------- public api
func anchors() -> Dictionary:
	if not _built:
		return build()
	return _anchors_cache

func parts() -> Array:
	return _parts

func part_health(id: String) -> float:
	if not _part_by_id.has(id):
		return 0.0
	return float(_part_by_id[id]["hp"])

## QA contract for the live rig, flags and the dark underwater hull.  Cheap and
## read-only, so a headless probe can call it every frame if it wants to.
func rigging_snapshot() -> Dictionary:
	var live := 0
	var sag := 0.0
	var sag_ratio := 0.0
	for r: int in _rig_meta.size():
		if _rope_visible(r):
			live += 1
		var base := r * RIG_POINTS
		var a := _rig_a[r]
		var b := _rig_b[r]
		var span := maxf(a.distance_to(b), 0.001)
		for p: int in range(1, RIG_POINTS - 1):
			var line := a.lerp(b, float(p) / float(RIG_POINTS - 1))
			var offset := _rig_points[base + p].distance_to(line) if base + p < _rig_points.size() else 0.0
			if offset > sag:
				sag = offset
			if offset / span > sag_ratio:
				sag_ratio = offset / span
	var slack_min := 0.0
	var slack_max := 0.0
	var slack_effective_min := 0.0
	var slack_effective_max := 0.0
	if not _rig_slack.is_empty():
		slack_min = _rig_slack[0]
		slack_max = _rig_slack[0]
		slack_effective_min = 9.0
		for r: int in _rig_slack.size():
			slack_min = minf(slack_min, _rig_slack[r])
			slack_max = maxf(slack_max, _rig_slack[r])
			var span := maxf(_rig_a[r].distance_to(_rig_b[r]), 0.001)
			var effective := _rig_rest[r] * float(RIG_POINTS - 1) / span
			slack_effective_min = minf(slack_effective_min, effective)
			slack_effective_max = maxf(slack_effective_max, effective)
	var top_copper := _copper_tone(COPPER_TONES[0], 0.15)
	var keel_copper := _copper_tone(COPPER_TONES[0], -1.10)
	return {
		"ropes": _rig_meta.size(),
		"ropes_live": live,
		"segments": _rig_meta.size() * RIG_SEGMENTS,
		"segments_live": live * RIG_SEGMENTS,
		"points": RIG_POINTS,
		"slack_min": slack_min,
		"slack_max": slack_max,
		"slack_effective_min": slack_effective_min,
		"slack_effective_max": slack_effective_max,
		"sag_max": sag,
		"sag_ratio_max": sag_ratio,
		"wind": _rig_wind.length(),
		"flags": _live_flag_count(),
		"flags_total": _flag_count,
		"anchors_ok": _rig_anchors_ok(),
		"mast_broken": _mast_broken,
		"hull_dark": _hull_dark_value(),
		"hull_dark_info": {
			"wet_band_m": WET_BAND_M,
			"copper_top_lum": top_copper.get_luminance(),
			"copper_keel_lum": keel_copper.get_luminance(),
		},
	}

func _rig_anchors_ok() -> bool:
	if not is_instance_valid(_rig_live_mm):
		return false
	if _rig_meta.size() < 8 or _rig_meta.size() > 14:
		return false
	if _rig_points.size() != _rig_meta.size() * RIG_POINTS:
		return false
	if _rig_prev.size() != _rig_points.size():
		return false
	for r: int in _rig_meta.size():
		if not _rig_a[r].is_finite() or not _rig_b[r].is_finite():
			return false
		if _rig_rest[r] <= 0.0:
			return false
	return true

func _hull_dark_value() -> bool:
	if not _materials.has("wet") or not _batch_used.get("wet", false):
		return false
	return _copper_tone(COPPER_TONES[0], -1.0).get_luminance() < 0.22

func set_sail_amount(amount: float) -> void:
	if not is_finite(amount):
		return
	_sail_target = clampf(amount, 0.0, 1.0)
	if not _built:
		_sail_amount = _sail_target

func set_lever(on: bool) -> void:
	_lever_on = on
	_lever_pump_hold = 0.0
	if not _built:
		_lever_angle = -1.0 if on else 1.0


## A held forward/back key at the winch pumps the lever in a continuous loop.
## The sail state is unchanged until the player presses F; this is the working
## motion, not a snap to the open/closed pose.
func pump_lever(delta: float, direction: float) -> void:
	if not _built or not is_instance_valid(_lever_pivot):
		return
	var dir := 1.0 if direction >= 0.0 else -1.0
	_lever_pump_phase += delta * 7.0 * dir
	_lever_pump_hold = 0.25
	_lever_angle = sin(_lever_pump_phase) * 0.52
	_apply_lever_visual()

func set_wheel_angle(radians: float) -> void:
	if not is_finite(radians):
		return
	_wheel_angle = radians
	if is_instance_valid(_wheel):
		_wheel.rotation.z = -radians

func set_mast_broken(broken: bool) -> void:
	_apply_mast_broken(broken)

func shake(amount: float) -> void:
	if not is_finite(amount):
		return
	_shake_amount = clampf(_shake_amount + amount, 0.0, 1.2)

func _build_damage_cells() -> void:
	# SHIP81: one MultiMesh for the whole destructive shell.  Each visible block
	# is a charred plank-sized hole; the whole breach costs a single draw call.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = DAMAGE_CELL_CAP
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.52, 1.10)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.055, 0.045, 0.038)
	material.roughness = 0.95
	box.material = material
	mm.mesh = box
	_damage_cells = MultiMeshInstance3D.new()
	_damage_cells.name = "HullDamageBlocks"
	_damage_cells.multimesh = mm
	_damage_cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_damage_cells)
	for i in range(DAMAGE_CELL_CAP):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	mm.visible_instance_count = 0


func show_damage_cell(index: int, side: float, z: float, y: float) -> void:
	if not is_instance_valid(_damage_cells):
		return
	if index < 0 or index >= DAMAGE_CELL_CAP:
		return
	var hull_x := _hull_x_at(z, clampf(y, 0.0, 3.2))
	var at := Vector3(side * (hull_x + 0.035), y, z)
	var mm := _damage_cells.multimesh
	mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
	mm.visible_instance_count = maxi(mm.visible_instance_count, index + 1)
	_stats_cache.clear()


func punch_hole(local_position: Vector3, radius: float) -> void:
	if not _built or _holes.is_empty():
		return
	if not local_position.is_finite() or not is_finite(radius) or radius <= 0.0:
		return
	var p := local_position
	var normal := _hole_normal(p)
	var r := clampf(radius, 0.12, 1.6)
	var mi: MeshInstance3D = _holes[_hole_next]
	_hole_next = (_hole_next + 1) % _holes.size()
	var basis := _basis_for_normal(normal)
	basis = Basis(normal, _hash01(int(p.x * 13.0), int(p.z * 17.0), _hole_next) * TAU) * basis
	# Scale in the decal's own plane.  `Basis.scaled()` scales world axes, so the
	# old call squashed a side hit into a tall sliver on an upright hull.
	var rim := r * 1.35
	var decal := Basis(basis.x * rim, basis.y, basis.z * rim)
	mi.transform = Transform3D(decal, p + normal * 0.045)
	mi.visible = true
	_stats_cache.clear()

func _hole_normal(p: Vector3) -> Vector3:
	var candidates: Array = []
	var side := 1.0 if p.x >= 0.0 else -1.0
	var deck := _deck_level(p.z)
	var hull_x := _hull_x_at(p.z, clampf(p.y, 0.0, deck))
	candidates.append({"n": Vector3(side, 0.0, 0.0), "d": absf(absf(p.x) - hull_x)})
	candidates.append({"n": Vector3(0.0, 1.0, 0.0), "d": absf(p.y - deck) + 0.35})
	candidates.append({"n": Vector3(0.0, -1.0, 0.0), "d": absf(p.y - _keel_y(p.z)) + 0.5})
	candidates.append({"n": Vector3(0.0, 0.0, 1.0), "d": absf(p.z - 13.0)})
	candidates.append({"n": Vector3(0.0, 0.0, -1.0), "d": absf(p.z + 13.0) + 0.3})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	return candidates[0]["n"]

func break_part(id: String) -> bool:
	if not _part_by_id.has(id):
		if id == "rail":
			id = "rails"
		elif id == "crate":
			id = "crate_ammo"
		elif id == "upper_deck":
			id = "upper_rail"
		else:
			return false
		if not _part_by_id.has(id):
			return false
	var entry: Dictionary = _part_by_id[id]
	if id == "mast_lower":
		entry["hp"] = 0.0
		_mast_lower.visible = false
		_apply_mast_broken(true)
		return true
	if id == "mast" or id == "mast_upper":
		entry["hp"] = 0.0
		_apply_mast_broken(true)
		return true
	entry["hp"] = 0.0
	var node: Node3D = entry["node"]
	if is_instance_valid(node):
		node.visible = false
	if _debris.has(id):
		(_debris[id] as Node3D).visible = true
	if id == "lanterns":
		for light: OmniLight3D in _lantern_lights:
			if is_instance_valid(light):
				light.visible = false
	_update_live_rigging(0.0)
	return true

## The public version is kept separate from the internal visual switch so that
## restoring the mast never restores its hit points.
func _apply_mast_broken(broken: bool) -> void:
	# Missing lower support cannot be repaired by toggling the upper visual.
	broken = broken or (is_instance_valid(_mast_lower) and not _mast_lower.visible)
	_mast_broken = broken
	if is_instance_valid(_mast_upper):
		_mast_upper.visible = not broken
	if is_instance_valid(_rig_upper):
		_rig_upper.visible = not broken
	if is_instance_valid(_sails_node):
		_sails_node.visible = not broken
	if is_instance_valid(_mast_stump):
		_mast_stump.visible = broken and _mast_lower.visible
	if _debris.has("mast"):
		(_debris["mast"] as Node3D).visible = broken
	if broken and _part_by_id.has("mast"):
		_part_by_id["mast"]["hp"] = 0.0
		_part_by_id["mast_upper"]["hp"] = 0.0
	_update_live_rigging(0.0)

func _apply_sail_visual() -> void:
	var amount := clampf(_sail_amount, 0.0, 1.0)
	for entry: Dictionary in _sail_meshes:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		if entry["kind"] == "jib":
			node.scale = Vector3(maxf(0.06, amount), 1.0, 1.0)
		else:
			node.scale = Vector3(lerpf(0.62, 1.0, amount), maxf(0.035, amount), 1.0)
	for entry: Dictionary in _rolls:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var show := amount < 0.90
		node.visible = show
		if show:
			var s := lerpf(1.0, 0.30, amount / 0.90)
			node.scale = Vector3(s, 1.0, s)
	if is_instance_valid(_sail_hole_mm):
		# Holes stay in ship space (no stretch), so they only make sense while the
		# canvas is actually set; the furled bundle would leave them floating.
		_sail_hole_mm.visible = amount > 0.15 and not _sail_holes.is_empty()

func _apply_lever_visual() -> void:
	# Only the handle throws.  The pedestal/quadrant are static.
	if is_instance_valid(_lever_pivot):
		# Positive handle angle must throw the lever toward the bow, not aft.
		_lever_pivot.rotation.x = -_lever_angle

func _process(delta: float) -> void:
	if not _built:
		return
	_time += delta
	_update_live_rigging(delta)
	if absf(_sail_amount - _sail_target) > 0.0005:
		_sail_amount = move_toward(_sail_amount, _sail_target, delta * 0.85)
		_apply_sail_visual()
	var target_angle := (1.05 if _lever_on else 0.0)
	_lever_pump_hold = maxf(0.0, _lever_pump_hold - delta)
	if _lever_pump_hold <= 0.0 and absf(_lever_angle - target_angle) > 0.0005:
		# Door-like throw: one F drives the handle forward to the open stop and
		# it stays there; the next F drives it back to the closed stop.
		_lever_angle = move_toward(_lever_angle, target_angle, delta * 4.0)
		_apply_lever_visual()
	if _shake_amount > 0.0001:
		_shake_amount = maxf(0.0, _shake_amount - delta * 1.8)
		var s := _shake_amount
		_visual.position = Vector3(sin(_time * 61.0) * 0.035 * s, sin(_time * 47.0 + 1.7) * 0.05 * s,
			sin(_time * 53.0 + 0.7) * 0.03 * s)
		_visual.rotation.z = sin(_time * 39.0) * 0.004 * s
	elif _visual.position != Vector3.ZERO or _visual.rotation.z != 0.0:
		_visual.position = Vector3.ZERO
		_visual.rotation.z = 0.0

# ----------------------------------------------------------------------------- stats
func stats() -> Dictionary:
	if not _stats_cache.is_empty():
		return _stats_cache
	var meshes := 0
	var triangles := 0
	var surfaces := 0
	var materials: Dictionary = {}
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			meshes += 1
			surfaces += mi.mesh.get_surface_count()
			triangles += _mesh_triangles(mi.mesh)
			if mi.material_override != null:
				materials[mi.material_override.get_instance_id()] = true
		elif node is MultiMeshInstance3D:
			var mmi := node as MultiMeshInstance3D
			if mmi.multimesh == null or mmi.multimesh.mesh == null:
				continue
			meshes += 1
			var per := _mesh_triangles(mmi.multimesh.mesh)
			triangles += per * mmi.multimesh.instance_count
			if mmi.material_override != null:
				materials[mmi.material_override.get_instance_id()] = true
	_stats_cache = {"meshes": meshes, "triangles": triangles, "surfaces": surfaces,
		"materials": materials.size(), "holes": _holes.size(), "sail_holes": _sail_holes.size(),
		"parts": _parts.size(), "collision": _collision.size(), "built": _built}
	return _stats_cache

func _mesh_triangles(mesh: Mesh) -> int:
	if not (mesh is ArrayMesh):
		# Primitive meshes (BoxMesh, SphereMesh, TorusMesh...) do not expose
		# surface_get_array_*, but get_faces() is the reliable triangle soup.
		return mesh.get_faces().size() / 3
	var total := 0
	for s: int in mesh.get_surface_count():
		var idx: int = mesh.surface_get_array_index_len(s)
		if idx > 0:
			total += idx / 3
		else:
			var verts: int = mesh.surface_get_array_len(s)
			total += verts / 3
	return total
