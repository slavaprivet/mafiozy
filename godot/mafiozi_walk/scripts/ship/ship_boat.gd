extends AnimatableBody3D
## SHIP61 (agent C) — the ship as a kinematic platform with buoyancy, sailing, rudder,
## flooding from hull holes and destructible parts.
##
## Design notes:
##  - The hull is NOT a RigidBody. It is an AnimatableBody3D driven every physics tick:
##    heave/pitch/roll come from `basin.water_height_at` samples on the waterline, the
##    course comes from the sail/rudder model. `sync_to_physics = true` makes the deck a
##    moving platform for CharacterBody3D players.
##  - `sync_to_physics` bodies take their transform from the physics body state, and a
##    plain `global_position` write outside a physics step is reverted on the next step.
##    The ship therefore keeps its own authoritative transform (`_origin`, `_yaw`,
##    `_pitch`, `_roll`), rebuilds it once per step and pushes it both to the node and to
##    `PhysicsServer3D`. That makes `simulate_step()` valid in and out of the tree (QA
##    drives it headless), while the live game still gets a normal moving platform.
##  - All foreign APIs (`ship_water_basin.gd`, `ship_model.gd`) are called dynamically
##    through `has_method`/`call`, because the agents that own them work in parallel and
##    may deliver a partial or differently-shaped dictionary. Every public method is
##    tolerant to null/invalid nodes.
##
## Local frame (contract): +Z stern, -Z bow, +X starboard, y=0 waterline.

const DEFAULT_WATER_LEVEL := -0.55
const START_WORLD := Vector3(62.0, -0.55, 988.0)
const START_YAW_DEG := -65.0

const HULL_LENGTH := 26.0
const HULL_BEAM := 8.8
const DECK_Y := 1.75

const MAX_SPEED := 6.5
const ACCEL := 0.55
const BRAKE := 0.75
const MAST_BRAKE := 1.6
const MAX_TURN_RAD := 0.3141592653589793 # 18 deg/s
const YAW_ACCEL := 0.70
const RUDDER_RATE := 1.5

## Forward water samples: 2-3 hull lengths would point past the bay mouth at the contract
## berth, so the navigability probe looks 9/15/21 m ahead (the bow is at 13 m).
const AHEAD_SAMPLES := [9.0, 15.0, 21.0]
const NAV_DRAFT := 1.8

const MAST_HP := 80.0
const DEFAULT_PART_HP := 60.0
const CANNON_HP := 90.0
const HULL_MAX_DAMAGE := 520.0
## SHIP81: the hull is a coarse plank-block shell.  Integrity is the fraction of
## surviving blocks, not a free-floating HP number.
const BLOCK_Z0 := -12.0
const BLOCK_Z1 := 12.0
const BLOCK_STEP_Z := 1.10
const BLOCK_ROWS := 5
const BLOCK_Y0 := 0.30
const BLOCK_Y1 := 2.30
const BLOCK_TOTAL := 2 * 22 * BLOCK_ROWS

const HOLE_FLOOD_RATE := 0.005 # flooding per second per unit of hole severity
const MAX_HOLES := 24
const FLOOD_SINK_HEIGHT := 2.2
const FLOOD_REPAIR_RELIEF := 0.05
const SINK_SECONDS := 10.0
const SINK_DEPTH := 13.0

const MAX_DEBRIS := 40
const DEBRIS_LIFE := 20.0

const CLIMB_SPEED := 2.2
const REPAIR_REACH := 3.2

## ------------------------------------------------------------------ wake / spray
## SHIP62 (agent W).  The wake is deliberately cheap:
##  - one shader-driven ribbon in world space (the trail rides in two uniform
##    arrays, so nothing is rebuilt or re-uploaded per frame),
##  - one ship-local bow-foam sheet,
##  - one 24-instance MultiMesh for the spray.
## That is three draw calls and no per-frame mesh allocation.
const WAKE_SAMPLES := 28          # trail samples, spaced by distance travelled
const WAKE_SPACING := 2.0         # metres per sample -> 54 m trail = 2.1 hulls
const WAKE_MIN_SPEED := 0.45      # below this the water is not disturbed
const WAKE_LIFT := 0.075          # foam sits just above the wave crests
const WAKE_FADE_RATE := 2.2       # strength units per second (fades when stopping)
const WAKE_RIPPLE_SLOW := 1.15    # basin ripple cadence at cruising speed
const WAKE_RIPPLE_FAST := 0.75    # ... at full speed
const WAKE_DRAW_CALLS := 3

const BOW_WAVE_SPEED := 0.9       # bow foam starts to show
const BOW_WAVE_FULL := 3.2        # ... full strength here

const SPRAY_MAX := 24
const SPRAY_SPEED := 3.0          # spray only above this speed
const SPRAY_INTERVAL := 0.045
const SPRAY_GRAVITY := 7.5

const HEEL_GAIN := 0.34           # roll per rad/s of turn (outward heel)
const HEEL_MAX := 0.1396          # 8 degrees

const GROUND_DEPTH := 1.6         # less water than this under the forefoot = aground
const GROUND_BRAKE := 1.1         # gentle beaching deceleration, m/s^2
const GROUND_CREEP := 0.25
const GROUND_LIFT_MAX := 0.32

## The bow-foam profile: z, inner half-width, foam width, alpha, crest rise.
const BOW_PROFILE := [
	[-13.0, 0.20, 0.72, 0.85, 0.13],
	[-12.3, 1.15, 0.88, 0.82, 0.11],
	[-11.4, 1.95, 1.00, 0.76, 0.08],
	[-10.4, 2.65, 1.10, 0.64, 0.05],
	[-9.2, 3.25, 1.18, 0.52, 0.03],
	[-7.8, 3.70, 1.22, 0.40, 0.02],
	[-6.0, 4.00, 1.20, 0.28, 0.02],
	[-3.0, 4.25, 1.10, 0.18, 0.01],
	[0.0, 4.38, 0.96, 0.11, 0.01],
	[3.0, 4.30, 0.84, 0.07, 0.01],
	[6.5, 4.05, 0.68, 0.0, 0.01],
]

## The crest that piles up against the stem and falls away aft:
## z, inner x (hull), outer x, inner y, crest y, alpha.
const BOW_CREST := [
	[-13.0, 0.20, 0.72, 0.02, 0.34, 0.80],
	[-12.5, 0.86, 1.58, 0.00, 0.50, 0.74],
	[-11.9, 1.60, 2.42, -0.02, 0.44, 0.58],
	[-11.2, 2.30, 3.18, -0.03, 0.30, 0.40],
	[-10.4, 2.90, 3.78, -0.04, 0.16, 0.22],
]

const WAKE_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform int wake_mode = 0;
uniform float strength = 0.0;
uniform float valid = 0.0;
uniform int sample_max = 28;
uniform vec4 wake_pos[28];
uniform vec4 wake_nrm[28];
uniform vec3 tint : source_color = vec3(0.93, 0.98, 1.0);
uniform float foam_scale = 2.6;

varying float v_alpha;
varying float v_far;
varying float v_lat;
varying float v_edge;
varying vec3 v_world;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	if (wake_mode == 0) {
		int idx = clamp(int(floor(UV.x + 0.5)), 0, sample_max - 1);
		vec4 a = wake_pos[idx];
		vec4 b = wake_nrm[idx];
		float span = max(valid - 1.0, 1.0);
		float t = clamp(float(idx) / span, 0.0, 1.0);
		float edge = UV.y;
		float strip = UV2.x;
		float lateral;
		if (strip < 0.5) {
			lateral = (edge * 2.0 - 1.0) * mix(1.05, 0.60, t);
		} else {
			float side = (strip < 1.5) ? -1.0 : 1.0;
			lateral = side * mix(2.60, 21.0, t) + (edge * 2.0 - 1.0) * mix(0.55, 1.95, t);
		}
		vec3 world_pos = vec3(a.x + b.x * lateral, a.y, a.z + b.z * lateral);
		VERTEX = world_pos - MODEL_MATRIX[3].xyz;
		v_world = world_pos;
		float on = step(float(idx) + 0.5, valid);
		float fade = pow(max(1.0 - t, 0.0), 0.45);
		float body = (strip < 0.5) ? 1.0 : 0.95;
		float head = smoothstep(0.0, 0.06, t);
		v_alpha = strength * on * fade * body * mix(0.85, 1.0, head) * a.w;
		v_far = t;
		v_lat = lateral;
		v_edge = edge;
	} else {
		v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_alpha = strength * COLOR.a;
		v_far = UV.x;
		v_lat = UV.y;
		v_edge = UV.y;
	}
}

void fragment() {
	if (v_alpha <= 0.004) {
		discard;
	}
	vec2 p = v_world.xz * foam_scale;
	float n1 = vnoise(p * 1.15 + vec2(TIME * 0.22, -TIME * 0.18));
	float n2 = vnoise(p * 3.60 - vec2(TIME * 0.45, TIME * 0.33));
	// Streaks that run along the trail: without them the strips read as painted tape.
	float s1 = vnoise(vec2(v_lat * 1.30, v_far * 16.0 + TIME * 0.25));
	float s2 = vnoise(vec2(v_lat * 4.20 - TIME * 0.15, v_far * 40.0 + 7.0));
	float streak = s1 * 0.65 + s2 * 0.35;
	float foam_n = n1 * 0.30 + n2 * 0.18 + streak * 0.52;
	float threshold = mix(0.11, 0.30, clamp(v_far, 0.0, 1.0));
	if (foam_n < threshold * 0.70) {
		discard;
	}
	float foam = smoothstep(threshold, threshold + 0.30, foam_n);
	// Feather the strip borders in the fragment: a true gradient, not a flat dim.
	float feather = 1.0 - pow(abs(v_edge * 2.0 - 1.0), 2.5);
	float a = v_alpha * mix(0.35, 1.0, foam) * mix(0.25, 1.0, feather);
	if (a < 0.004) {
		discard;
	}
	ALBEDO = tint;
	ALPHA = clamp(a, 0.0, 0.95);
}
"""

## Seven waterline samples: 0 bow, 1 stern, 2 port-bow, 3 starboard-bow,
## 4 port-quarter, 5 starboard-quarter, 6 centre.
const SAMPLE_OFFSETS := [
	Vector2(0.0, -11.5),
	Vector2(0.0, 11.5),
	Vector2(-4.0, -5.0),
	Vector2(4.0, -5.0),
	Vector2(-4.0, 5.0),
	Vector2(4.0, 5.0),
	Vector2(0.0, 0.0),
]

var _installed := false
var _autopilot := true

var _world: Node3D = null
var _basin: Object = null
var _player: CharacterBody3D = null
var _model: Node3D = null

var _length := HULL_LENGTH
var _beam := HULL_BEAM
var _deck_y := DECK_Y
var _water_level := DEFAULT_WATER_LEVEL

## Authoritative world transform state (the node is only a mirror of it).
var _origin := START_WORLD
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0

## Anchors (ship-local) taken from `model.build()`.
var _anchors: Dictionary = {}
var _cannon_mounts: Array[Vector3] = []

var _sails_open := false
var _speed := 0.0
var _rudder := 0.0
var _rudder_target := 0.0
var _yaw_rate := 0.0
var _time := 0.0
var _moor_position := START_WORLD
var _moor_yaw := 0.0

var _flooding := 0.0
var _flood_rate := 0.0
var _hull_damage := 0.0
var _destroyed_blocks: Dictionary = {}
var _mast_hp := MAST_HP
var _mast_broken := false
var _mast_segments: Dictionary = {}
var _mast_step_delta := 0.0
var _sunk := false
var _sink_t := 0.0
var _holes: Array[Dictionary] = []
var _part_hp: Dictionary = {}
var _broken_parts: Array[String] = []

var _obstacle_blocked := false
var _water_blocked := false
var _collision_disabled := false
var _rail_shapes: Array[CollisionShape3D] = []

var _debris_container: Node3D = null
var _debris_nodes: Array[Node3D] = []
var _debris_life: Array[float] = []
var _rng := RandomNumberGenerator.new()

var _step_transform := Transform3D.IDENTITY
var _carry_compensation := true

var _climb_input_bound := false
var _climb_input := 0.0
var _climbing_ladder := false
var _climbing_companionway := false

## Wake / bow wave / spray (built once by `_install_wake`).
var _wake_enabled := true
var _wake_render := true
var _wake_node: MeshInstance3D = null
var _bow_node: MeshInstance3D = null
var _spray_node: MultiMeshInstance3D = null
var _wake_mat: ShaderMaterial = null
var _bow_mat: ShaderMaterial = null
var _spray_mesh: MultiMesh = null
var _wake_pos: PackedVector4Array = PackedVector4Array()
var _wake_nrm: PackedVector4Array = PackedVector4Array()
var _wake_hist: PackedVector3Array = PackedVector3Array()
var _wake_path: PackedVector3Array = PackedVector3Array()
var _wake_shade: PackedFloat32Array = PackedFloat32Array()
var _wake_hist_count := 0
var _wake_last_normal := Vector3(0.0, 0.0, 1.0)
var _wake_strength := 0.0
var _bow_wave := 0.0
var _wake_ripple_timer := 0.0
var _ripple_events := 0
var _wake_ms := 0.0
var _spray_pos: PackedVector3Array = PackedVector3Array()
var _spray_vel: PackedVector3Array = PackedVector3Array()
var _spray_life: PackedFloat32Array = PackedFloat32Array()
var _spray_max_life: PackedFloat32Array = PackedFloat32Array()
var _spray_size: PackedFloat32Array = PackedFloat32Array()
var _spray_alive := 0
var _spray_timer := 0.0

## Water behaviour.
var _speed_factor := 0.0
var _heel := 0.0
var _aground := false
var _depth_center := 0.0
var _depth_bow := 0.0
var _ground_lift := 0.0


## ------------------------------------------------------------------ install

func install(world: Node3D, basin: Object, player: CharacterBody3D, model: Node3D) -> Dictionary:
	if _installed:
		return {"ok": false, "reason": "already_installed", "position": _origin}
	if model == null:
		return {"ok": false, "reason": "no_model"}
	_world = world
	_basin = basin
	_player = player
	_model = model
	if world != null and not is_inside_tree() and get_parent() == null:
		world.add_child(self)
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 1
	_rng.randomize()
	if model.get_parent() != self:
		var old_parent: Node = model.get_parent()
		if old_parent != null:
			old_parent.remove_child(model)
		add_child(model)
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	var build: Dictionary = {}
	if model.has_method("build"):
		var raw: Variant = model.call("build")
		if raw is Dictionary:
			build = raw as Dictionary
	_read_build(build)
	var shapes := _build_collision(build)
	shapes += _build_rails()
	_debris_container = Node3D.new()
	_debris_container.name = "ShipDebris"
	if world != null:
		world.add_child(_debris_container)
	else:
		add_child(_debris_container)
	_install_parts(build)
	shapes += _install_mast_segments(build)
	_water_level = _basin_water_level()
	_install_wake()
	_installed = true
	moor(START_WORLD, deg_to_rad(START_YAW_DEG))
	_apply_sails_visual()
	print("SHIP61_BOAT_INSTALL pos=", _origin, " yaw_deg=", rad_to_deg(_yaw),
		" shapes=", shapes, " anchors=", _anchors.size(), " model_build=", not build.is_empty())
	return {
		"ok": true,
		"position": _origin,
		"yaw_deg": rad_to_deg(_yaw),
		"collision_shapes": shapes,
		"water_level": _water_level,
		"length": _length,
		"beam": _beam,
		"deck_y": _deck_y,
		"anchors": _anchors.keys(),
		"model_built": not build.is_empty(),
	}


func is_installed() -> bool:
	return _installed


func _read_build(build: Dictionary) -> void:
	_length = maxf(6.0, _num(build.get("length", null), HULL_LENGTH))
	_beam = maxf(2.0, _num(build.get("beam", null), HULL_BEAM))
	_deck_y = _num(build.get("deck_y", null), DECK_Y)
	_cache_anchors(build)


func _cache_anchors(build: Dictionary) -> void:
	_anchors = {
		"helm": Vector3(0.0, 3.05, 10.4),
		"sail_lever": Vector3(1.0, 2.2, 0.2),
		"crate_ammo": Vector3(-2.0, 0.95, 10.2),
		"crate_boards": Vector3(2.0, 0.95, 10.2),
		"mast_base": Vector3(0.0, 1.75, -1.0),
		"mast_top": Vector3(0.0, 17.7, -1.0),
		"upper_deck": Vector3(0.0, 5.2, -1.2),
		"ladder_base": Vector3(0.0, 1.75, 2.3),
		"ladder_top": Vector3(0.0, 5.2, 2.0),
		"bow": Vector3(0.0, 2.15, -13.0),
	}
	_cannon_mounts = [
		Vector3(-3.55, 1.75, -4.2),
		Vector3(3.55, 1.75, -4.2),
		Vector3(-3.55, 1.75, 3.4),
		Vector3(3.55, 1.75, 3.4),
	]
	for id: String in ["helm", "sail_lever"]:
		var entry: Variant = build.get(id, null)
		if entry is Dictionary:
			var dict := entry as Dictionary
			_anchors[id] = _vector_or(dict.get("position", null), _anchors[id])
	var mast: Variant = build.get("mast", null)
	if mast is Dictionary:
		var mast_dict := mast as Dictionary
		_anchors["mast_base"] = _vector_or(mast_dict.get("base", null), _anchors["mast_base"])
		_anchors["mast_top"] = _vector_or(mast_dict.get("top", null), _anchors["mast_top"])
	var upper: Variant = build.get("upper_deck", null)
	if upper is Dictionary:
		var upper_dict := upper as Dictionary
		_anchors["upper_deck"] = _vector_or(upper_dict.get("position", null), _anchors["upper_deck"])
		_anchors["ladder_base"] = _vector_or(upper_dict.get("ladder_base", null), _anchors["ladder_base"])
	var bow: Variant = build.get("bow", null)
	if bow is Dictionary:
		_anchors["bow"] = _vector_or((bow as Dictionary).get("position", null), _anchors["bow"])
	var crates: Variant = build.get("crates", null)
	if crates is Dictionary:
		var crate_dict := crates as Dictionary
		var pairs := [["ammo", "crate_ammo"], ["boards", "crate_boards"]]
		for pair: Array in pairs:
			var entry: Variant = crate_dict.get(str(pair[0]), null)
			if entry is Dictionary:
				var dict := entry as Dictionary
				_anchors[str(pair[1])] = _vector_or(dict.get("position", null), _anchors[str(pair[1])])
	var cannons: Variant = build.get("cannons", null)
	if cannons is Array and not (cannons as Array).is_empty():
		_cannon_mounts.clear()
		for entry: Variant in (cannons as Array):
			if not entry is Dictionary:
				continue
			var dict := entry as Dictionary
			var index := int(_num(dict.get("index", null), float(_cannon_mounts.size())))
			while _cannon_mounts.size() <= index:
				_cannon_mounts.append(Vector3.ZERO)
			_cannon_mounts[index] = _vector_or(dict.get("mount", null), _cannon_mounts[index])


func _install_hatch_cover() -> void:
	# Invisible walkable cover over the companionway opening.  The visual
	# grating stays open, but crossing it on deck no longer drops the player into
	# the stair and freezes him; F still teleports down into the cabin.
	var body := StaticBody3D.new()
	body.name = "CompanionwayCover"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.4, 0.16, 5.2)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, 1.74, 7.4)
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)


func _install_parts(build: Dictionary) -> void:
	_part_hp = {
		"mast": MAST_HP,
		"rail": 120.0,
		"crate_ammo": 90.0,
		"crate_boards": 90.0,
		"helm": 120.0,
		"transom": 180.0,
		"bowsprit": 100.0,
		"upper_deck": 260.0,
	}
	for index in 4:
		_part_hp["cannon_%d" % index] = CANNON_HP
	var parts: Variant = build.get("parts", null)
	if parts is Array:
		for entry: Variant in (parts as Array):
			if not entry is Dictionary:
				continue
			var dict := entry as Dictionary
			var id := str(dict.get("id", ""))
			var hp := _num(dict.get("hp", null), 0.0)
			if not id.is_empty() and hp > 0.0:
				_part_hp[id] = hp
	_mast_hp = maxf(1.0, _num(_part_hp.get("mast", null), MAST_HP))
	_broken_parts.clear()


## ------------------------------------------------------------------ transform

func _world_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, _roll)), _origin)


func _sync_transform(force_immediate: bool = false) -> void:
	var xform := _world_transform()
	if not is_inside_tree():
		transform = xform
		return
	var parent := get_parent()
	var local_xform := xform
	if parent is Node3D:
		local_xform = (parent as Node3D).global_transform.affine_inverse() * xform
	var use_physics := sync_to_physics
	# install()/moor() can be called from the host's own `_physics_process`, where the
	# plain write on a sync_to_physics body stays stale until the next step. The host
	# reads `boat.to_global()`/`global_position` immediately to seat the player, so moor
	# forces the node transform through the sync toggle even inside a physics frame.
	var immediate := force_immediate or not Engine.is_in_physics_frame()
	if use_physics and not immediate:
		# Normal live path: the node is a mirror of the body state, which is applied at
		# the end of the physics step.
		transform = local_xform
	else:
		if use_physics:
			sync_to_physics = false
			transform = local_xform
			sync_to_physics = true
		else:
			transform = local_xform
	if use_physics:
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xform)


func _world_from_local(point_local: Vector3) -> Vector3:
	if not point_local.is_finite():
		return _origin
	return _world_transform() * point_local


func _local_from_world(point_world: Vector3) -> Vector3:
	if not point_world.is_finite():
		return Vector3.ZERO
	return _world_transform().affine_inverse() * point_world


func local_of(point_world: Vector3) -> Vector3:
	## Ship-local coordinates of a world point (handy for QA / prompts).
	return _local_from_world(point_world)


## ------------------------------------------------------------------ collision

func _build_collision(build: Dictionary) -> int:
	var count := 0
	var entries: Variant = build.get("collision", null)
	if not entries is Array or (entries as Array).is_empty():
		_punch_fallback_hull()
		return 4
	for entry: Variant in (entries as Array):
		if not entry is Dictionary:
			continue
		var dict := entry as Dictionary
		var position := _vector_or(dict.get("position", null), Vector3.ZERO)
		var size := _vector_or(dict.get("size", null), Vector3.ONE)
		if size.x == 0.0 and size.y == 0.0 and size.z == 0.0:
			continue
		var rotation_y := _num(dict.get("rotation_y", null), 0.0)
		var part := str(dict.get("part", ""))
		_add_box("Hull_%d" % count, position, size, rotation_y, part)
		count += 1
	if count == 0:
		_punch_fallback_hull()
		return 4
	return count


func _punch_fallback_hull() -> void:
	## Only used when the model has not delivered collision data yet: a deck you can
	## stand on and a hull you cannot walk through.
	_add_box("Hull_Deck", Vector3(0.0, 1.55, 0.0), Vector3(8.6, 0.4, 25.6), 0.0)
	_add_box("Hull_Body", Vector3(0.0, -1.2, 0.0), Vector3(8.6, 2.9, 24.6), 0.0)
	_add_box("Hull_Quarter", Vector3(0.0, 2.85, 9.2), Vector3(8.4, 0.3, 6.4), 0.0)
	_add_box("Hull_Upper", Vector3(0.0, 5.05, -1.2), Vector3(6.4, 0.3, 6.0), 0.0)


func _build_rails() -> int:
	## Invisible bulwark boxes so a player does not simply walk overboard. The stern
	## quarter (z > 6) stays open on both sides: that is where the pier gangway meets the
	## hull, and a rail there would block boarding. `set_railings_enabled(false)` removes
	## them entirely if the host builds its own barriers.
	var half_beam := _beam * 0.5
	var rail_y := _deck_y + 0.60
	var rail_center_z := -3.3
	var rail_size_z := 18.4
	_rail_shapes.clear()
	_rail_shapes.append(_add_box("RailPort", Vector3(-(half_beam - 0.10), rail_y, rail_center_z), Vector3(0.16, 1.2, rail_size_z), 0.0, "rail"))
	_rail_shapes.append(_add_box("RailStarboard", Vector3(half_beam - 0.10, rail_y, rail_center_z), Vector3(0.16, 1.2, rail_size_z), 0.0, "rail"))
	return _rail_shapes.size()


func set_railings_enabled(enabled: bool) -> void:
	for shape: CollisionShape3D in _rail_shapes:
		if is_instance_valid(shape):
			shape.disabled = not enabled


func _disable_hull_collision() -> void:
	if _collision_disabled:
		return
	_collision_disabled = true
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	print("SHIP61_BOAT_COLLISION_OFF pos=", _origin)


func _add_box(shape_name: String, position: Vector3, size: Vector3, rotation_y: float,
		part: String = "") -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.name = shape_name
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(absf(size.x), 0.05), maxf(absf(size.y), 0.05), maxf(absf(size.z), 0.05))
	node.shape = box
	node.position = position
	node.rotation.y = rotation_y
	if not part.is_empty():
		node.set_meta("ship_part", part)
	add_child(node)
	return node


## ------------------------------------------------------------------ mooring / state

func moor(world_position: Vector3, yaw: float) -> void:
	if not world_position.is_finite() or not is_finite(yaw):
		return
	_moor_position = world_position
	_moor_yaw = wrapf(yaw, -PI, PI)
	_yaw = _moor_yaw
	_yaw_rate = 0.0
	_rudder = 0.0
	_rudder_target = 0.0
	_speed = 0.0
	_pitch = 0.0
	_roll = 0.0
	_water_level = _basin_water_level()
	var y := _water_level if _basin != null else world_position.y
	_origin = Vector3(world_position.x, y, world_position.z)
	_reset_wake()
	_sync_transform(true)
	_step_transform = _world_transform()
	_mast_step_delta = 0.0


func set_sails(open: bool) -> void:
	var wanted := open and not _mast_broken and not _unusable()
	if not _installed:
		_sails_open = wanted
		return
	_sails_open = wanted
	_apply_sails_visual()


## `moor()` takes radians; this convenience is for callers that keep degrees.
func moor_deg(world_position: Vector3, yaw_degrees: float) -> void:
	if not is_finite(yaw_degrees):
		return
	moor(world_position, deg_to_rad(yaw_degrees))


func toggle_sails() -> bool:
	set_sails(not _sails_open)
	return _sails_open


func sails_open() -> bool:
	return _sails_open


func mast_broken() -> bool:
	return _mast_broken


func _apply_sails_visual() -> void:
	if _model == null or not is_instance_valid(_model):
		return
	if _model.has_method("set_sail_amount"):
		_model.call("set_sail_amount", 1.0 if _sails_open else 0.0)
	if _model.has_method("set_lever"):
		_model.call("set_lever", _sails_open)


func steer(axis: float) -> void:
	if not is_finite(axis):
		return
	if _unusable():
		# A sinking wreck does not answer the helm: no rudder, no wheel spin.
		_rudder_target = 0.0
		_rudder = 0.0
		_yaw_rate = 0.0
		if _model != null and is_instance_valid(_model) and _model.has_method("set_wheel_angle"):
			_model.call("set_wheel_angle", 0.0)
		return
	_rudder_target = clampf(axis, -1.0, 1.0)


## A cannon host may push its recoil through the boat.  On a wreck the gun crew is
## gone (the host locks the stations too); the call stays a safe no-op so nothing
## can rock a sunk hull.
func apply_recoil(_direction: Vector3 = Vector3.ZERO, _amount: float = 0.0) -> void:
	if not _installed or _unusable():
		return


## Can the ship still be sailed / served?  False once she is going down.
func usable() -> bool:
	return _installed and not _unusable()


func _unusable() -> bool:
	return _sunk or _sink_t > 0.0 or _collision_disabled


func speed() -> float:
	return _speed


func heading() -> float:
	return _yaw


func heading_deg() -> float:
	return rad_to_deg(_yaw)


func water_level() -> float:
	return _water_level


func mast_hp() -> float:
	return _mast_hp


func hole_count() -> int:
	return _holes.size()


func hull_integrity() -> float:
	if BLOCK_TOTAL > 0:
		return clampf(1.0 - float(_destroyed_blocks.size()) / float(BLOCK_TOTAL), 0.0, 1.0)
	return clampf(1.0 - _hull_damage / HULL_MAX_DAMAGE, 0.0, 1.0)


func destroyed_blocks() -> int:
	return _destroyed_blocks.size()


func _destroy_blocks_at(local: Vector3, radius: float) -> void:
	var side := 1.0 if local.x >= 0.0 else -1.0
	var cols := 22
	var z_step := (BLOCK_Z1 - BLOCK_Z0) / float(cols - 1)
	var y_step := (BLOCK_Y1 - BLOCK_Y0) / float(BLOCK_ROWS - 1)
	var side_index := 0 if side < 0.0 else 1
	var zi := int(round((local.z - BLOCK_Z0) / z_step))
	var span := int(ceil(radius / z_step)) + 1
	for dz in range(-span, span + 1):
		var zi2 := zi + dz
		if zi2 < 0 or zi2 >= cols:
			continue
		var cell_z := BLOCK_Z0 + float(zi2) * z_step
		for row in range(BLOCK_ROWS):
			var cell_y := BLOCK_Y0 + float(row) * y_step
			if Vector2(cell_z - local.z, cell_y - local.y).length() > radius:
				continue
			var id := side_index * cols * BLOCK_ROWS + zi2 * BLOCK_ROWS + row
			if _destroyed_blocks.has(id):
				continue
			_destroyed_blocks[id] = true
			if _model != null and is_instance_valid(_model) and _model.has_method("show_damage_cell"):
				_model.call("show_damage_cell", id, side, cell_z, cell_y)
	_hull_damage = float(_destroyed_blocks.size()) / float(BLOCK_TOTAL) * HULL_MAX_DAMAGE


func flooding() -> float:
	return _flooding


func is_sunk() -> bool:
	return _sunk


func part_health(id: String) -> float:
	return _num(_part_hp.get(id, null), 0.0)


func _basin_water_level() -> float:
	if _basin != null and _basin.has_method("water_level"):
		var value: Variant = _basin.call("water_level")
		if value is float or value is int:
			var level := float(value)
			if is_finite(level):
				return level
	return DEFAULT_WATER_LEVEL


func _water_height(x: float, z: float) -> float:
	if _basin != null and _basin.has_method("water_height_at"):
		var value: Variant = _basin.call("water_height_at", x, z)
		if value is float or value is int:
			var height := float(value)
			if is_finite(height):
				return height
	return _water_level


func _navigable(x: float, z: float) -> bool:
	if _basin == null or not _basin.has_method("is_navigable"):
		return true
	var value: Variant = _basin.call("is_navigable", x, z, NAV_DRAFT)
	if value is bool:
		return bool(value)
	return true


func _depth_at(x: float, z: float) -> float:
	## Water under the keel. Deep water when the basin cannot tell us.
	if _basin != null and _basin.has_method("depth_at"):
		var value: Variant = _basin.call("depth_at", x, z)
		if value is float or value is int:
			var depth := float(value)
			if is_finite(depth):
				return depth
	if _basin != null and _basin.has_method("is_navigable"):
		return 99.0 if bool(_basin.call("is_navigable", x, z, NAV_DRAFT)) else 0.0
	return 99.0


## ------------------------------------------------------------------ anchors

func world_helm() -> Vector3:
	return _anchor_world("helm")


func world_sail_lever() -> Vector3:
	return _anchor_world("sail_lever")


func world_crate(kind: String) -> Vector3:
	var id := ""
	if kind == "ammo":
		id = "crate_ammo"
	elif kind == "boards":
		id = "crate_boards"
	if id.is_empty():
		return _origin
	return _anchor_world(id)


func world_deck(point_local: Vector3) -> Vector3:
	return _world_from_local(point_local)


func _anchor_world(id: String) -> Vector3:
	var local: Variant = _anchors.get(id, null)
	if local is Vector3:
		return _world_from_local(local as Vector3)
	return _origin


## ------------------------------------------------------------------ simulation step

func simulate_step(delta: float) -> void:
	if not _installed:
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, 0.1)
	_mast_step_delta = delta
	_step_transform = _world_transform()
	_time += delta
	_update_obstacles()
	_update_flooding(delta)
	_update_grounding()
	_update_motion(delta)
	_update_buoyancy(delta)
	_update_wake(delta)
	_update_debris(delta)
	_sync_transform()
	_carry_riders()


func _physics_process(delta: float) -> void:
	if not _autopilot:
		return
	# DSH_NET: корпус ведёт хост. Клиент не симулирует корабль, а повторяет
	# присланный трансформ: иначе у двух игроков корабль стоит в разных местах и
	# палуба с пушками оказывается не там, где её видят.
	if Net.online() and Net.is_host() and has_meta("net_authority"):
		simulate_step(delta)
		Net.publish_world("ship", {"p": global_position,
			"q": global_basis.get_rotation_quaternion()})
		return
	simulate_step(delta)


func set_autopilot(enabled: bool) -> void:
	_autopilot = enabled


func set_carry_compensation(enabled: bool) -> void:
	_carry_compensation = enabled


## ------------------------------------------------------------------ movement

func _update_obstacles() -> void:
	_obstacle_blocked = false
	if not is_inside_tree():
		return
	var space := get_world_3d()
	if space == null:
		return
	var state := space.direct_space_state
	if state == null:
		return
	var xform := _world_transform()
	var exclude: Array[RID] = [get_rid()]
	for offset: float in [-3.2, 0.0, 3.2]:
		var from := xform * Vector3(offset, 2.2, -12.0)
		var to := xform * Vector3(offset, 2.2, -28.0)
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
		if not state.intersect_ray(query).is_empty():
			_obstacle_blocked = true
			return


func _water_ahead_ok() -> bool:
	if _basin == null:
		return true
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	for distance: float in AHEAD_SAMPLES:
		var point := _origin + forward * distance
		if not _navigable(point.x, point.z):
			return false
	return true


func _update_grounding() -> void:
	## A shallow berth is not a wall: the ship is allowed to feel the bottom, loses
	## way gently and rides up a little instead of sinking into the ground mesh.
	_depth_center = _depth_at(_origin.x, _origin.z)
	var bow_world := _world_from_local(Vector3(0.0, 0.0, -_length * 0.5 + 2.0))
	_depth_bow = _depth_at(bow_world.x, bow_world.z)
	var shallow := minf(_depth_center, _depth_bow)
	_aground = not _sunk and shallow < GROUND_DEPTH
	_ground_lift = 0.0
	if _aground:
		_ground_lift = clampf((GROUND_DEPTH - shallow) / GROUND_DEPTH, 0.0, 1.0) * GROUND_LIFT_MAX


func _update_motion(delta: float) -> void:
	_water_blocked = not _water_ahead_ok()
	var blocked := _mast_broken or _sunk or _water_blocked or _obstacle_blocked
	var target_speed := MAX_SPEED if (_sails_open and not blocked) else 0.0
	if _aground:
		target_speed = minf(target_speed, GROUND_CREEP)
	var rate := ACCEL if target_speed > _speed else BRAKE
	if _mast_broken or _sunk:
		rate = maxf(rate, MAST_BRAKE)
	if _aground:
		# Softer than the mast brake: the hull scrubs to a stop without a jolt.
		rate = maxf(rate, GROUND_BRAKE)
	_speed = move_toward(_speed, target_speed, rate * delta)
	if _speed < 0.0:
		_speed = 0.0
	_rudder = move_toward(_rudder, _rudder_target, RUDDER_RATE * delta)
	# The wheel follows the real rudder angle instead of snapping to the key:
	# the helmsman sees the spokes ease round with the ship.
	if _model != null and is_instance_valid(_model) and _model.has_method("set_wheel_angle"):
		_model.call("set_wheel_angle", _rudder * 1.2)
	_speed_factor = clampf(_speed / MAX_SPEED, 0.0, 1.0)
	var target_yaw_rate := -_rudder * MAX_TURN_RAD * _speed_factor
	if _aground:
		# The keel is in the mud: the helm only nudges the heading.
		target_yaw_rate *= 0.25
	_yaw_rate = move_toward(_yaw_rate, target_yaw_rate, YAW_ACCEL * delta)
	if _speed < 0.05:
		# A ship that is not moving through the water does not answer the helm.
		_yaw_rate = 0.0
	_yaw = wrapf(_yaw + _yaw_rate * delta, -PI, PI)
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	_origin += forward * _speed * delta


## ------------------------------------------------------------------ buoyancy

func _update_buoyancy(delta: float) -> void:
	var xform := _world_transform()
	var heights: Array[float] = []
	var sum := 0.0
	for offset: Vector2 in SAMPLE_OFFSETS:
		var point := xform * Vector3(offset.x, 0.0, offset.y)
		var height := _water_height(point.x, point.z)
		heights.append(height)
		sum += height
	var mean := sum / float(heights.size())
	var bow := heights[0]
	var stern := heights[1]
	var starboard := (heights[3] + heights[5]) * 0.5
	var port := (heights[2] + heights[4]) * 0.5
	var pitch_target := clampf(atan2(bow - stern, _length), -0.10, 0.10) * 0.9
	var roll_target := clampf(atan2(starboard - port, _beam), -0.10, 0.10) * 0.9
	# Ambient swell, tiny, so the deck is alive even in calm water.
	if not _sunk:
		pitch_target += sin(_time * 0.45 + 1.2) * 0.008
		roll_target += sin(_time * 0.60) * 0.012
		# Speed squat: the bow lifts a hair as the hull starts to plane.
		pitch_target += 0.010 * _speed_factor
	# Heel out of a turn: proportional to the turn rate, capped at 8 degrees.
	var heel_target := clampf(-_yaw_rate * _speed_factor * HEEL_GAIN, -HEEL_MAX, HEEL_MAX)
	if _aground:
		heel_target *= 0.4
	_heel = lerpf(_heel, heel_target, 1.0 - exp(-delta * 3.2))
	roll_target += _heel
	if _aground and _ground_lift > 0.0:
		# The forefoot has found the bottom: the bow rides up instead of digging in.
		pitch_target += 0.018 * clampf(_ground_lift / GROUND_LIFT_MAX, 0.0, 1.0)
	var centroid := _hole_centroid()
	if _flooding > 0.0 and not centroid.is_zero_approx():
		# List toward the flooded side; the water inside is heavier than the water outside.
		roll_target += -0.42 * _flooding * clampf(centroid.x / 3.0, -1.0, 1.0)
		pitch_target += 0.34 * _flooding * clampf(centroid.y / 9.0, -1.0, 1.0)
	var target_y := mean - _flooding * FLOOD_SINK_HEIGHT - _sink_extra() + _ground_lift
	var blend := 1.0 - exp(-delta * 2.6)
	_pitch = lerpf(_pitch, clampf(pitch_target, -0.35, 0.35), 1.0 - exp(-delta * 1.8))
	_roll = lerpf(_roll, clampf(roll_target, -0.40, 0.40), 1.0 - exp(-delta * 1.8))
	_origin.y = lerpf(_origin.y, target_y, blend)


func _sink_extra() -> float:
	if not _sunk:
		return 0.0
	return minf(1.0, _sink_t / SINK_SECONDS) * SINK_DEPTH


func _hole_centroid() -> Vector2:
	if _holes.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var weight := 0.0
	for hole: Dictionary in _holes:
		var local: Vector3 = hole.get("local", Vector3.ZERO)
		var severity := _num(hole.get("severity", null), 1.0)
		sum += Vector2(local.x, local.z) * severity
		weight += severity
	if weight <= 0.0:
		return Vector2.ZERO
	return sum / weight


## ------------------------------------------------------------------ flooding

func _update_flooding(delta: float) -> void:
	_flood_rate = _hole_severity_sum() * HOLE_FLOOD_RATE
	if _sunk:
		_sink_t += delta
		if _sink_t >= SINK_SECONDS * 0.6:
			# Well under the surface now: the deck stops being a floor, so a player left
			# on it drops into the water (the integrator fishes him out).
			_disable_hull_collision()
		return
	if _flood_rate > 0.0:
		_flooding = minf(1.0, _flooding + _flood_rate * delta)
	if _flooding >= 1.0:
		_sunk = true
		_sink_t = 0.0
		_speed = minf(_speed, 1.0)
		# A wreck cannot be sailed: canvas comes in, helm goes amidships.
		_sails_open = false
		_rudder = 0.0
		_rudder_target = 0.0
		_yaw_rate = 0.0
		if _model != null and is_instance_valid(_model) and _model.has_method("set_wheel_angle"):
			_model.call("set_wheel_angle", 0.0)
		_apply_sails_visual()
		print("SHIP61_BOAT_SUNK pos=", _origin, " holes=", _holes.size(),
			" flooding=", _flooding)


func _hole_severity_sum() -> float:
	var total := 0.0
	for hole: Dictionary in _holes:
		total += _num(hole.get("severity", null), 1.0)
	return total


## ------------------------------------------------------------------ damage

## Physical projectile entry point. A real shape owner takes precedence over
## proximity guesses (a rail beside a cannon is still a rail).
func apply_surface_hit(hit: Dictionary, damage: float, impulse: Vector3, kind: String) -> Dictionary:
	var collider := hit.get("collider") as CollisionObject3D
	if not is_instance_valid(collider) or (collider != self and not is_ancestor_of(collider)):
		return {"ok": false, "reason": "foreign_surface"}
	var shape_index := int(hit.get("shape", -1))
	var part := ""
	var surface_name := ""
	# Resolve only an index present on this body, including compound bodies.
	for owner_id: int in collider.get_shape_owners():
		for index in collider.shape_owner_get_shape_count(owner_id):
			if collider.shape_owner_get_shape_index(owner_id, index) != shape_index:
				continue
			var owner: Object = collider.shape_owner_get_owner(owner_id)
			if owner is CollisionShape3D:
				if (owner as CollisionShape3D).disabled:
					return {"ok": false, "reason": "surface_disabled"}
				part = str(owner.get_meta("ship_part", ""))
				surface_name = str((owner as Node).name)
			break
		if not surface_name.is_empty():
			break
	if not part.is_empty() and _broken_parts.has(part):
		return {"ok": false, "reason": "surface_already_broken", "part": part}
	var result := apply_hit(hit.get("position", global_position), damage, impulse, kind, part)
	result["surface"] = surface_name
	result["shape_index"] = shape_index
	return result


func apply_hit(world_point: Vector3, damage: float, impulse: Vector3, kind: String,
		surface_part: String = "") -> Dictionary:
	var result := {
		"ok": false,
		"zone": "",
		"damage": 0.0,
		"hole": false,
		"flooding": _flooding,
		"integrity": hull_integrity(),
		"hole_world": Vector3.ZERO,
		"sunk": _sunk,
		"sail_hole": false,
		"sail_radius": 0.0,
	}
	if not _installed:
		result["reason"] = "not_installed"
		return result
	if not world_point.is_finite():
		result["reason"] = "bad_point"
		return result
	var hit_damage := damage
	if not is_finite(hit_damage) or hit_damage < 0.0:
		hit_damage = 0.0
	hit_damage = minf(hit_damage, 500.0)
	var local := _local_from_world(world_point)
	var zone := surface_part if not surface_part.is_empty() else _classify_zone(local)
	var part_id := ""
	var hole := false
	var hole_world := Vector3.ZERO
	var sail_hole := false
	var sail_radius := 0.0
	if zone == "hull":
		var radius := clampf(0.45 + hit_damage * 0.0065, 0.45, 1.2)
		hole_world = _add_hole(local, radius)
		hole = true
		var block_radius := 2.10 if kind == "powder" else maxf(radius * 1.35, 0.85)
		_destroy_blocks_at(local, block_radius)
	elif zone == "sail":
		# Canvas: no flooding, just a torn hole.  A ball punches a small hole; a
		# catapult stone or a powder blast tears a big one.
		var heavy := hit_damage >= 140.0 or kind == "powder" or kind == "barrel" \
			or kind == "catapult" or kind == "bomb" or kind == "explosion"
		sail_radius = clampf(0.5 + hit_damage * 0.0008, 0.5, 0.9) if heavy \
			else clampf(0.15 + hit_damage * 0.003, 0.15, 0.35)
		if _model != null and is_instance_valid(_model) and _model.has_method("punch_sail_hole"):
			var punched: Variant = _model.call("punch_sail_hole", local, sail_radius)
			sail_hole = punched is Dictionary and bool((punched as Dictionary).get("ok", false))
	elif zone == "mast_lower" or zone == "mast_upper":
		part_id = zone
		_part_hp[part_id] = maxf(0.0, part_health(part_id) - hit_damage)
		if part_id == "mast_upper":
			_mast_hp = part_health(part_id)
			_part_hp["mast"] = _mast_hp
		if part_health(part_id) <= 0.0:
			_break_mast_segment(part_id, world_point, impulse)
	elif zone == "mast":
		part_id = "mast"
		_mast_hp = maxf(0.0, _mast_hp - hit_damage)
		_part_hp["mast"] = _mast_hp
		if _mast_hp <= 0.0 and not _mast_broken:
			_break_mast(local)
	else:
		part_id = zone
		var hp := _num(_part_hp.get(part_id, null), DEFAULT_PART_HP) - hit_damage
		_part_hp[part_id] = maxf(0.0, hp)
		if hp <= 0.0 and not _broken_parts.has(part_id):
			_break_part(part_id, local)
	_after_hit_fx(world_point, zone, local, impulse)
	result["ok"] = true
	result["zone"] = zone
	result["damage"] = hit_damage
	result["hole"] = hole
	result["flooding"] = _flooding
	result["integrity"] = hull_integrity()
	result["hole_world"] = hole_world
	result["sunk"] = _sunk
	result["sail_hole"] = sail_hole
	result["sail_radius"] = sail_radius
	result["sail_hole_count"] = _model_sail_hole_count()
	result["part"] = part_id
	result["part_hp"] = _num(_part_hp.get(part_id, null), -1.0) if not part_id.is_empty() else -1.0
	return result


func _classify_zone(local: Vector3) -> String:
	# The contact comes from actual convex wood geometry; resolve its segment
	# using the mesh-local bounds, with a small surface tolerance. The surviving lower mast
	# remains a target after the upper part (and propulsion) has failed.
	for id: String in ["mast_lower", "mast_upper"]:
		if not _mast_segments.has(id) or _broken_parts.has(id):
			continue
		var shape: CollisionShape3D = _mast_segments[id]["shape"]
		if is_instance_valid(shape) and not shape.disabled and (_mast_segments[id]["bounds"] as AABB).grow(0.06).has_point(
				shape.transform.affine_inverse() * local):
			return id
	var mast_base: Vector3 = _anchors.get("mast_base", Vector3(0.0, 1.75, -1.0))
	var mast_top: Vector3 = _anchors.get("mast_top", Vector3(0.0, 17.7, -1.0))
	if _mast_segments.is_empty() and not _mast_broken and local.y >= mast_base.y - 0.4 and local.y <= mast_top.y + 1.0:
		if Vector2(local.x - mast_base.x, local.z - mast_base.z).length() <= 1.25:
			return "mast"
	# Canvas above the bulwark, at the mast and on the forestay.  The model owns
	# the exact sail rectangles; the geometric fallback keeps old test doubles and
	# an unbuilt model working.
	if _is_sail_zone(local):
		return "sail"
	var helm: Vector3 = _anchors.get("helm", Vector3(0.0, 3.05, 10.4))
	if local.distance_to(helm) <= 1.35:
		return "helm"
	var ammo: Vector3 = _anchors.get("crate_ammo", Vector3(-2.0, 0.95, 10.2))
	if local.distance_to(ammo) <= 1.45:
		return "crate_ammo"
	var boards: Vector3 = _anchors.get("crate_boards", Vector3(2.0, 0.95, 10.2))
	if local.distance_to(boards) <= 1.45:
		return "crate_boards"
	for index in _cannon_mounts.size():
		if local.distance_to(_cannon_mounts[index]) <= 1.9:
			return "cannon_%d" % index
	if local.z < -13.2 and local.y > 0.6:
		return "bowsprit"
	if local.z > 11.6 and local.y < 6.0:
		return "transom"
	var upper: Vector3 = _anchors.get("upper_deck", Vector3(0.0, 5.2, -1.2))
	if local.y > upper.y - 0.7 and absf(local.z - upper.z) < 5.6:
		return "upper_deck"
	if local.y > 1.95 and (absf(local.x) > 3.15 or local.z > 6.0):
		return "rail"
	if local.y < 2.0:
		return "hull"
	return "upper_deck"


func _is_sail_zone(local: Vector3) -> bool:
	if _model != null and is_instance_valid(_model) and _model.has_method("sail_zone_at"):
		return bool(_model.call("sail_zone_at", local))
	# Fallback rectangles, matching ship_model's square sails and jib.
	if local.y >= 6.4 and local.y <= 14.4 and absf(local.x) <= 5.8 \
			and local.z > -2.2 and local.z < 0.4:
		return true
	if local.y >= 4.2 and local.y <= 14.4 and absf(local.x) <= 3.4 \
			and local.z < -3.4 and local.z > -18.5:
		return true
	return false


func _model_sail_hole_count() -> int:
	if _model != null and is_instance_valid(_model) and _model.has_method("sail_hole_count"):
		return int(_model.call("sail_hole_count"))
	return 0


func _add_hole(local: Vector3, radius: float) -> Vector3:
	if _holes.size() >= MAX_HOLES:
		# The pool is full: the oldest hole is widened instead of growing forever.
		var oldest: Dictionary = _holes.pop_front()
		var old_radius := _num(oldest.get("radius", null), radius)
		radius = maxf(radius, minf(1.35, old_radius + 0.15))
	var severity := clampf(radius / 0.8, 0.5, 2.0)
	_holes.append({"local": local, "radius": radius, "severity": severity})
	_flood_rate = _hole_severity_sum() * HOLE_FLOOD_RATE
	var world := _world_from_local(local)
	if _model != null and is_instance_valid(_model):
		if _model.has_method("punch_hole"):
			_model.call("punch_hole", local, radius)
		if _model.has_method("shake"):
			_model.call("shake", 0.4)
	if _basin != null and _basin.has_method("add_ripple"):
		_basin.call("add_ripple", world, 1.0)
	print("SHIP61_BOAT_HOLE local=", local, " world=", world, " radius=", radius,
		" holes=", _holes.size(), " flood_rate=", _flood_rate)
	return world


func _install_mast_segments(build: Dictionary) -> int:
	_mast_segments.clear()
	for entry: Dictionary in build.get("parts", []):
		var id := str(entry.get("id", ""))
		if id != "mast_lower" and id != "mast_upper":
			continue
		var node := entry.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		var mesh_node := node.get_node_or_null("M_" + id) as MeshInstance3D
		if not is_instance_valid(mesh_node) or mesh_node.mesh == null:
			continue
		var convex := mesh_node.mesh.create_convex_shape()
		if convex == null or convex.points.size() < 4:
			continue
		var shape := CollisionShape3D.new()
		shape.name = "Hit_" + id
		shape.shape = convex
		shape.transform = global_transform.affine_inverse() * mesh_node.global_transform
		shape.set_meta("ship_part", id)
		add_child(shape)
		_mast_segments[id] = {"node": node, "mesh": mesh_node, "shape": shape, "bounds": mesh_node.mesh.get_aabb()}
	return _mast_segments.size()


func _break_mast_segment(id: String, world_point: Vector3, impulse: Vector3) -> void:
	if _broken_parts.has(id) or not _mast_segments.has(id):
		return
	# Detach the upper portion while its original visuals are still present.
	if id == "mast_lower":
		# Loss of support is not a second projectile impulse on the upper segment.
		_break_mast_segment("mast_upper", world_point, Vector3.ZERO)
	_spawn_mast_segment(id, world_point, impulse)
	_broken_parts.append(id)
	_part_hp[id] = 0.0
	_disable_part_collision(id)
	_mast_broken = true
	_mast_hp = 0.0
	_part_hp["mast"] = 0.0
	if not _broken_parts.has("mast"):
		_broken_parts.append("mast")
	_sails_open = false
	if is_instance_valid(_model) and _model.has_method("break_part"):
		_model.call("break_part", id)
		# The model's legacy static wreck would duplicate our falling real mesh.
		var static_wreck := _model.find_child("Wreck_mast", true, false) as Node3D
		if is_instance_valid(static_wreck):
			static_wreck.visible = false
	_apply_sails_visual()
	print("SHIP33_MAST_SEGMENT_BROKEN id=", id, " at=", world_point)


func _spawn_mast_segment(id: String, world_point: Vector3, impulse: Vector3) -> void:
	var entry: Dictionary = _mast_segments[id]
	var node: Node3D = entry["node"]
	var mesh_node: MeshInstance3D = entry["mesh"]
	var original_shape: CollisionShape3D = entry["shape"]
	if not is_instance_valid(node) or not is_instance_valid(mesh_node):
		return
	var local_mesh := global_transform.affine_inverse() * mesh_node.global_transform
	var local_node := global_transform.affine_inverse() * node.global_transform
	var center: Vector3 = local_mesh * mesh_node.mesh.get_aabb().get_center()
	var now := _world_transform()
	var body := RigidBody3D.new()
	body.name = "Falling_" + id
	body.mass = 180.0 if id == "mast_lower" else 95.0
	body.collision_layer = 4
	body.collision_mask = 1 | 4
	body.continuous_cd = true
	var visual := node.duplicate() as Node3D
	visual.visible = true
	body.add_child(visual)
	visual.transform = Transform3D(Basis.IDENTITY, -center) * local_node
	var shape := CollisionShape3D.new()
	shape.shape = original_shape.shape
	shape.transform = Transform3D(Basis.IDENTITY, -center) * original_shape.transform
	body.add_child(shape)
	_debris_root().add_child(body)
	body.global_transform = now * Transform3D(Basis.IDENTITY, center)
	var inherited := Vector3(-sin(_yaw), 0.0, -cos(_yaw)) * _speed
	var angular := Vector3.UP * _yaw_rate
	if _mast_step_delta > 0.0:
		inherited = ((now * center) - (_step_transform * center)) / _mast_step_delta
		var rotation_delta := (now.basis * _step_transform.basis.inverse()).get_rotation_quaternion().normalized()
		if rotation_delta.w < 0.0:
			rotation_delta = -rotation_delta
		if rotation_delta.get_angle() > 0.00001:
			angular = rotation_delta.get_axis() * rotation_delta.get_angle() / _mast_step_delta
	body.linear_velocity = inherited
	body.angular_velocity = angular
	body.set_meta("ship_mast_segment", id)
	body.set_meta("inherited_linear_velocity", inherited)
	body.set_meta("inherited_angular_velocity", angular)
	if impulse.is_finite():
		body.apply_impulse(impulse.limit_length(1200.0), world_point - body.global_position)
	# Short joint-overlap grace; afterwards the actual trunk can land on the deck.
	body.add_collision_exception_with(self)
	_release_mast_collision_grace(body)
	for other: Node3D in _debris_nodes:
		if is_instance_valid(other) and other is RigidBody3D and other.has_meta("ship_mast_segment"):
			body.add_collision_exception_with(other)
			_release_mast_pair_grace(body, other as RigidBody3D)
	while _debris_nodes.size() >= MAX_DEBRIS:
		var old := _debris_nodes.pop_front() as Node3D
		_debris_life.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_debris_nodes.append(body)
	_debris_life.append(DEBRIS_LIFE)


func _release_mast_collision_grace(body: RigidBody3D) -> void:
	await get_tree().create_timer(0.20, false, true).timeout
	if is_instance_valid(body) and is_instance_valid(self):
		body.remove_collision_exception_with(self)


func _release_mast_pair_grace(body: RigidBody3D, other: RigidBody3D) -> void:
	await get_tree().create_timer(0.20, false, true).timeout
	if is_instance_valid(body) and is_instance_valid(other):
		body.remove_collision_exception_with(other)


func _exit_tree() -> void:
	# Debris lives beside the boat in world space; lifecycle cleanup belongs to
	# the boat, independent of the host guessing Godot's auto-renamed node name.
	if is_instance_valid(_debris_container) and not _debris_container.is_queued_for_deletion():
		_debris_container.queue_free()
	_debris_nodes.clear()
	_debris_life.clear()


func _break_mast(local: Vector3) -> void:
	if _mast_segments.has("mast_upper"):
		_break_mast_segment("mast_upper", _world_from_local(local), Vector3.ZERO)
		return
	_mast_broken = true
	_mast_hp = 0.0
	_part_hp["mast"] = 0.0
	if not _broken_parts.has("mast"):
		_broken_parts.append("mast")
	if _model != null and is_instance_valid(_model):
		if _model.has_method("set_mast_broken"):
			_model.call("set_mast_broken", true)
		if _model.has_method("shake"):
			_model.call("shake", 1.0)
	var world := _world_from_local(local)
	_spawn_debris(world, 6)
	if _basin != null and _basin.has_method("add_ripple"):
		_basin.call("add_ripple", world, 1.5)
	print("SHIP61_BOAT_MAST_BROKEN pos=", _origin, " speed=", _speed)


func _break_part(id: String, local: Vector3) -> void:
	if id.is_empty() or _broken_parts.has(id):
		return
	_broken_parts.append(id)
	# A shot-away wheel or gun must not leave an invisible wall behind.
	_disable_part_collision(id)
	var world := _world_from_local(local)
	if _model != null and is_instance_valid(_model):
		if _model.has_method("break_part"):
			_model.call("break_part", id)
		if _model.has_method("shake"):
			_model.call("shake", 0.8)
	_spawn_debris(world, 4)
	if _basin != null and _basin.has_method("add_ripple"):
		_basin.call("add_ripple", world, 1.0)
	print("SHIP61_BOAT_PART_BROKEN id=", id, " at=", world)


func _disable_part_collision(id: String) -> void:
	for child: Node in get_children():
		if child is CollisionShape3D:
			var shape := child as CollisionShape3D
			if shape.has_meta("ship_part") and str(shape.get_meta("ship_part")) == id:
				shape.disabled = true


func _after_hit_fx(world_point: Vector3, zone: String, _local: Vector3, impulse: Vector3) -> void:
	if _basin != null and _basin.has_method("add_ripple"):
		_basin.call("add_ripple", world_point, 0.6)
	if _model != null and is_instance_valid(_model) and _model.has_method("shake"):
		_model.call("shake", 0.25)
	if zone != "hull" and zone != "sail" and not _sunk:
		_spawn_debris(world_point, 2)


## ------------------------------------------------------------------ repair

func nearest_hole_world(from_world: Vector3, reach: float = 3.0) -> Vector3:
	if _holes.is_empty() or not from_world.is_finite():
		return Vector3.ZERO
	var best := Vector3.ZERO
	var best_distance := maxf(reach, 0.01)
	for hole: Dictionary in _holes:
		var local: Vector3 = hole.get("local", Vector3.ZERO)
		var world := _world_from_local(local)
		var distance := world.distance_to(from_world)
		if distance <= best_distance:
			best_distance = distance
			best = world
	return best


func repair_at(world_point: Vector3) -> bool:
	if _holes.is_empty() or not world_point.is_finite():
		return false
	var index := -1
	var best := REPAIR_REACH
	for i in _holes.size():
		var local: Vector3 = _holes[i].get("local", Vector3.ZERO)
		var distance := _world_from_local(local).distance_to(world_point)
		if distance <= best:
			best = distance
			index = i
	if index < 0:
		return false
	var hole: Dictionary = _holes[index]
	_holes.remove_at(index)
	_hull_damage = maxf(0.0, _hull_damage - 25.0)
	_flooding = maxf(0.0, _flooding - FLOOD_REPAIR_RELIEF)
	_flood_rate = _hole_severity_sum() * HOLE_FLOOD_RATE
	if _model != null and is_instance_valid(_model) and _model.has_method("repair_hole"):
		_model.call("repair_hole", hole.get("local", Vector3.ZERO), _num(hole.get("radius", null), 0.6))
	print("SHIP61_BOAT_REPAIR at=", world_point, " holes=", _holes.size(),
		" flooding=", _flooding, " flood_rate=", _flood_rate)
	return true


## ------------------------------------------------------------------ ladder

func set_climb_input(axis: float) -> void:
	if is_nan(axis):
		_climb_input_bound = false
		return
	_climb_input_bound = true
	_climb_input = clampf(axis, -1.0, 1.0)


func _climb_axis() -> float:
	if _climb_input_bound:
		return _climb_input
	var axis := 0.0
	if InputMap.has_action(&"preview_move_forward") and Input.is_action_pressed(&"preview_move_forward"):
		axis += 1.0
	if InputMap.has_action(&"preview_move_back") and Input.is_action_pressed(&"preview_move_back"):
		axis -= 1.0
	return clampf(axis, -1.0, 1.0)


func climb_assist(player: CharacterBody3D, delta: float) -> void:
	if not _installed or player == null or not is_instance_valid(player):
		return
	if not is_finite(delta) or delta <= 0.0 or delta > 0.25:
		return
	var local := _local_from_world(player.global_position)
	var axis := _climb_axis()
	var just_forward := InputMap.has_action(&"preview_move_forward") and Input.is_action_just_pressed(&"preview_move_forward")
	var just_back := InputMap.has_action(&"preview_move_back") and Input.is_action_just_pressed(&"preview_move_back")
	# Explicit W only: walking through the ladder zone with W already held must
	# not capture the player.  The first W press while standing at the ladder
	# starts the climb; afterwards the held W keeps climbing.
	# Follow the open companionway in both directions.  Only the centred stair
	# mouth accepts the descent, so walking across the neighbouring deck stays
	# on the deck; climbing out from below remains possible without F.
	var on_companionway := _in_companionway_zone(local)
	var leaving_cabin := local.y < 1.55 and axis > 0.0
	var entering_cabin := local.y >= 1.55 and local.z >= 4.30 and local.z <= 4.90 and axis < 0.0
	if not on_companionway:
		_climbing_companionway = false
	if on_companionway and (_climbing_companionway or leaving_cabin or entering_cabin):
		_climbing_ladder = false
		_climbing_companionway = true
		_climb_companionway(player, local, axis, delta)
		return
	if _in_quarter_stair_zone(local):
		_climbing_ladder = false
		_climb_quarter_stair(player, local, axis, delta)
		return
	if _in_bow_stair_zone(local):
		_climbing_ladder = false
		_climb_bow_stair(player, local, axis, delta)
		return
	var boarding := _boarding_ladder_at(local)
	if not boarding.is_empty():
		# Boarding is explicit: F at the ladder.  W near the hull must never
		# capture the player and freeze deck movement.
		return
	if not _in_ladder_zone(local):
		_climbing_ladder = false
		return
	if not _climbing_ladder and not (just_forward or (just_back and local.y > 4.50)):
		return
	_climbing_ladder = true
	if is_zero_approx(axis):
		return
	var base: Vector3 = _anchors.get("ladder_base", Vector3(0.0, 1.75, 2.3))
	var top: Vector3 = _anchors.get("ladder_top", Vector3(0.0, 5.2, 2.0))
	var next_y := clampf(local.y + CLIMB_SPEED * axis * delta, base.y, top.y)
	var span := maxf(0.01, top.y - base.y)
	var t := clampf((next_y - base.y) / span, 0.0, 1.0)
	var z_target := lerpf(base.z, top.z, t)
	var grab := minf(1.0, delta * 6.0)
	var next_local := Vector3(lerpf(local.x, 0.0, grab), next_y, lerpf(local.z, z_target, grab))
	if axis > 0.0 and next_y >= top.y - 0.001:
		# Step off the ladder onto the fighting top; the next frame is normal walking.
		next_local.z = minf(next_local.z, 1.40)
		_climbing_ladder = false
	if axis < 0.0 and next_y <= base.y + 0.001:
		next_local.z = maxf(next_local.z, base.z + 0.20)
		_climbing_ladder = false
	player.global_position = _world_from_local(next_local)
	player.velocity = Vector3(0.0, CLIMB_SPEED * axis, 0.0)


func _in_ladder_zone(local: Vector3) -> bool:
	if absf(local.x) > 1.15:
		return false
	if local.z < 1.55 or local.z > 3.85:
		return false
	return local.y >= 1.45 and local.y <= 5.75


## ------------------------------------------------------------------ companionway / quarter stairs
## The visible cabin steps are 0.22 m high: a CharacterBody cannot step that
## without a jump, so the player was trapped in the cabin.  These two zones
## turn the stairs into a proper walk-up/walk-down surface.
func _in_companionway_zone(local: Vector3) -> bool:
	if absf(local.x) > 1.28:
		return false
	if local.z < 4.30 or local.z > 6.08:
		return false
	return local.y >= 0.45 and local.y <= 1.95


func _climb_companionway(player: CharacterBody3D, local: Vector3, axis: float, delta: float) -> void:
	if is_zero_approx(axis):
		return
	var next_y := clampf(local.y + CLIMB_SPEED * 1.35 * axis * delta, 0.52, 1.78)
	var z_target := 4.30 if axis > 0.0 else 6.02
	var grab := minf(1.0, delta * 8.0)
	var next_local := Vector3(local.x, next_y, lerpf(local.z, z_target, grab))
	if axis > 0.0 and next_y >= 1.77:
		next_local.y = 1.78
		next_local.z = 4.30
		_climbing_companionway = false
	elif axis < 0.0 and next_y <= 0.53:
		next_local.y = 0.52
		next_local.z = 6.02
		_climbing_companionway = false
	player.global_position = _world_from_local(next_local)
	player.velocity = Vector3(0.0, CLIMB_SPEED * 1.35 * axis, 0.0)


func _in_quarter_stair_zone(local: Vector3) -> bool:
	if absf(local.x) < 1.95 or absf(local.x) > 3.48:
		return false
	if local.z < 4.75 or local.z > 6.16:
		return false
	return local.y >= 1.60 and local.y <= 3.18


func _climb_quarter_stair(player: CharacterBody3D, local: Vector3, axis: float, delta: float) -> void:
	if is_zero_approx(axis):
		return
	# The quarterdeck lies aft (+Z), so S climbs it and W descends.
	var rise := -axis
	var next_y := clampf(local.y + CLIMB_SPEED * rise * delta, 1.78, 3.03)
	var z_target := 6.10 if rise > 0.0 else 5.24
	var grab := minf(1.0, delta * 8.0)
	var next_local := Vector3(local.x, next_y, lerpf(local.z, z_target, grab))
	if rise > 0.0 and next_y >= 3.02:
		next_local.y = 3.03
		next_local.z = 6.10
	elif rise < 0.0 and next_y <= 1.79:
		next_local.y = 1.78
		next_local.z = 5.24
	player.global_position = _world_from_local(next_local)
	player.velocity = Vector3(0.0, CLIMB_SPEED * rise, 0.0)


func _in_bow_stair_zone(local: Vector3) -> bool:
	return absf(local.x) < 1.30 and local.z >= -12.50 and local.z <= -11.25 \
		and local.y >= 1.60 and local.y <= 2.42


func _climb_bow_stair(player: CharacterBody3D, local: Vector3, axis: float, delta: float) -> void:
	if is_zero_approx(axis):
		return
	var next_y := clampf(local.y + CLIMB_SPEED * 0.45 * axis * delta, 1.78, 2.18)
	var z_target := -12.38 if axis > 0.0 else -11.20
	var grab := minf(1.0, delta * 8.0)
	var next_local := Vector3(local.x, next_y, lerpf(local.z, z_target, grab))
	if axis > 0.0 and next_y >= 2.17:
		next_local = Vector3(local.x, 2.18, -12.38)
	elif axis < 0.0 and next_y <= 1.79:
		next_local = Vector3(local.x, 1.78, -11.20)
	player.global_position = _world_from_local(next_local)
	player.velocity = Vector3(0.0, CLIMB_SPEED * 0.45 * axis, 0.0)


## ------------------------------------------------------------------ boarding ladders
## Two ladders per side at z -3.0 / 4.2, matching the visible rungs in
## `ship_model._build_boarding_ladders`.  They climb from the waterline/shore
## to the main deck and step in over the rail.
const BOARD_LADDER_Z: Array[float] = [-3.0, 4.2]
const BOARD_LADDER_X := 4.55
const BOARD_LADDER_TOP := 1.88
const BOARD_LADDER_BOTTOM := -1.65


func _boarding_ladder_at(local: Vector3) -> Dictionary:
	for z: float in BOARD_LADDER_Z:
		for side: float in [-1.0, 1.0]:
			if absf(local.x - side * BOARD_LADDER_X) > 1.55:
				continue
			if absf(local.z - z) > 0.85:
				continue
			if local.y < BOARD_LADDER_BOTTOM - 0.30 or local.y > BOARD_LADDER_TOP + 0.27:
				continue
			return {"side": side, "z": z}
	return {}


func in_boarding_zone(world_position: Vector3) -> bool:
	return not _boarding_ladder_at(_local_from_world(world_position)).is_empty()


func boarding_ladder_at(world_position: Vector3) -> Dictionary:
	return _boarding_ladder_at(_local_from_world(world_position))


func _climb_boarding(player: CharacterBody3D, local: Vector3, axis: float,
		boarding: Dictionary, delta: float) -> void:
	if is_zero_approx(axis):
		return
	var side: float = float(boarding.get("side", 1.0))
	var z: float = float(boarding.get("z", 0.0))
	var next_y := clampf(local.y + CLIMB_SPEED * axis * delta,
		BOARD_LADDER_BOTTOM, BOARD_LADDER_TOP)
	var grab := minf(1.0, delta * 8.0)
	var next_local := Vector3(lerpf(local.x, side * BOARD_LADDER_X, grab), next_y, z)
	if axis < 0.0 and local.y >= BOARD_LADDER_TOP - 0.35 and absf(local.x) < 4.05:
		# The rail cap blocks a straight step out from the deck; place the
		# climber on the outboard ladder, then the normal descent continues.
		next_local = Vector3(side * BOARD_LADDER_X, BOARD_LADDER_TOP - 0.18, z)
	if axis > 0.0 and next_y >= BOARD_LADDER_TOP - 0.001:
		# Step in over the bulwark onto the main deck.
		next_local = Vector3(side * 3.15, BOARD_LADDER_TOP, z)
	elif axis < 0.0 and next_y <= BOARD_LADDER_BOTTOM + 0.001:
		# Step off into the water beside the hull.
		next_local = Vector3(side * 4.85, BOARD_LADDER_BOTTOM, z)
	player.global_position = _world_from_local(next_local)
	player.velocity = Vector3(0.0, CLIMB_SPEED * axis, 0.0)


## ------------------------------------------------------------------ platform carry

func _carry_riders() -> void:
	if not _carry_compensation:
		return
	if _player == null or not is_instance_valid(_player):
		return
	# Godot already follows a moving floor.  During the authored jump the body
	# leaves that floor, so add only the deck's own motion while it is airborne.
	if _player.is_on_floor():
		return
	var now := _world_transform()
	var motion := now * _step_transform.affine_inverse()
	if motion.is_equal_approx(Transform3D.IDENTITY):
		return
	var local := _local_from_world(_player.global_position)
	if _on_deck_local(local):
		_player.global_position = motion * _player.global_position


func _on_deck_local(local: Vector3) -> bool:
	# The fighting top is 3.45 m above the main deck.  Keep its full jump arc
	# aboard too, including the 1.1 m rise above that upper floor.
	if local.y < _deck_y - 0.5 or local.y > _deck_y + 5.2:
		return false
	return absf(local.x) <= _beam * 0.5 + 0.35 and absf(local.z) <= _length * 0.5 + 0.60


## ------------------------------------------------------------------ debris

func _debris_root() -> Node3D:
	if _debris_container != null and is_instance_valid(_debris_container):
		return _debris_container
	return self


func _spawn_debris(world_position: Vector3, count: int) -> void:
	var root := _debris_root()
	var amount := clampi(count, 1, 8)
	for _i in amount:
		if _debris_nodes.size() >= MAX_DEBRIS:
			var old: Node3D = _debris_nodes.pop_front()
			_debris_life.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		var body := RigidBody3D.new()
		body.name = "ShipWreck_%d" % _rng.randi_range(0, 99999)
		body.mass = 8.0
		body.collision_layer = 4
		body.collision_mask = 1
		var size := Vector3(_rng.randf_range(0.25, 0.9), _rng.randf_range(0.12, 0.30), _rng.randf_range(0.40, 1.10))
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.30, 0.21, 0.13)
		material.roughness = 0.92
		mesh.material_override = material
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
		body.global_position = world_position + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.1, 0.9), _rng.randf_range(-0.6, 0.6))
		body.linear_velocity = Vector3(_rng.randf_range(-2.2, 2.2), _rng.randf_range(1.0, 4.0), _rng.randf_range(-2.2, 2.2))
		body.angular_velocity = Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0))
		_debris_nodes.append(body)
		_debris_life.append(DEBRIS_LIFE)


func _update_debris(delta: float) -> void:
	var index := _debris_nodes.size() - 1
	while index >= 0:
		_debris_life[index] -= delta
		var node := _debris_nodes[index]
		var remove := _debris_life[index] <= 0.0 or not is_instance_valid(node)
		if not remove and node.global_position.y < -25.0:
			remove = true
		if remove:
			if is_instance_valid(node):
				node.queue_free()
			_debris_nodes.remove_at(index)
			_debris_life.remove_at(index)
		index -= 1


func debris_count() -> int:
	return _debris_nodes.size()


## ------------------------------------------------------------------ wake / bow wave / spray

func set_wake_enabled(enabled: bool) -> void:
	## QA / perf switch: the whole foam system is off and costs nothing.
	_wake_enabled = enabled
	_wake_strength = 0.0
	_bow_wave = 0.0
	_wake_hist_count = 0
	_spray_alive = 0
	_spray_timer = 0.0
	if _spray_mesh != null:
		_spray_mesh.visible_instance_count = 0
	if _wake_node != null:
		_wake_node.visible = false
	if _bow_node != null:
		_bow_node.visible = false
	if _spray_node != null:
		_spray_node.visible = false


func wake_enabled() -> bool:
	return _wake_enabled


func set_wake_render(enabled: bool) -> void:
	## Perf A/B without losing the trail: the simulation keeps running, only the
	## three foam meshes are hidden. Used by the wake cost probe.
	_wake_render = enabled
	if not enabled:
		if _wake_node != null:
			_wake_node.visible = false
		if _bow_node != null:
			_bow_node.visible = false
		if _spray_node != null:
			_spray_node.visible = false


func wake_render_enabled() -> bool:
	return _wake_render


func wake_strength() -> float:
	return _wake_strength


func bow_wave() -> float:
	return _bow_wave


func foam_particles() -> int:
	return _spray_alive


func wake_length() -> float:
	## Metres of trail currently laid down behind the transom.
	if _wake_hist_count <= 1:
		return 0.0
	return float(_wake_hist_count - 1) * WAKE_SPACING


func _install_wake() -> void:
	if _wake_node != null:
		return
	_wake_pos.resize(WAKE_SAMPLES)
	_wake_nrm.resize(WAKE_SAMPLES)
	_wake_hist.resize(WAKE_SAMPLES)
	_wake_path.resize(WAKE_SAMPLES)
	_wake_shade.resize(WAKE_SAMPLES)
	for index in WAKE_SAMPLES:
		_wake_pos[index] = Vector4(0.0, _water_level + WAKE_LIFT, 0.0, 0.0)
		_wake_nrm[index] = Vector4(1.0, 0.0, 0.0, 0.0)
		_wake_hist[index] = Vector3.ZERO
		_wake_path[index] = Vector3.ZERO
		_wake_shade[index] = 0.0
	_wake_hist_count = 0
	_wake_last_normal = Vector3(0.0, 0.0, 1.0)
	var shader := Shader.new()
	shader.code = WAKE_SHADER
	# 1) The V trail and the centre foam lane: world space, shader-driven, 1 draw call.
	_wake_mat = ShaderMaterial.new()
	_wake_mat.shader = shader
	_wake_mat.set_shader_parameter("wake_mode", 0)
	_wake_mat.set_shader_parameter("sample_max", WAKE_SAMPLES)
	_wake_mat.set_shader_parameter("foam_scale", 2.6)
	_wake_mat.set_shader_parameter("strength", 0.0)
	_wake_mat.set_shader_parameter("valid", 0.0)
	_wake_mat.set_shader_parameter("wake_pos", _wake_pos)
	_wake_mat.set_shader_parameter("wake_nrm", _wake_nrm)
	_wake_node = MeshInstance3D.new()
	_wake_node.name = "WakeRibbon"
	_wake_node.mesh = _make_wake_mesh()
	_wake_node.material_override = _wake_mat
	_wake_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The vertices are world-space offsets, so the instance AABB must cover the trail
	# rather than the authored (zeroed) mesh.
	_wake_node.custom_aabb = AABB(Vector3(-72.0, -4.0, -72.0), Vector3(144.0, 8.0, 144.0))
	_wake_node.top_level = true
	_wake_node.visible = false
	add_child(_wake_node)
	# 2) The bow wave and the foam lane along the waterline: hull local, 1 draw call.
	_bow_mat = ShaderMaterial.new()
	_bow_mat.shader = shader
	_bow_mat.set_shader_parameter("wake_mode", 1)
	_bow_mat.set_shader_parameter("sample_max", WAKE_SAMPLES)
	_bow_mat.set_shader_parameter("foam_scale", 2.6)
	_bow_mat.set_shader_parameter("strength", 0.0)
	_bow_node = MeshInstance3D.new()
	_bow_node.name = "BowWave"
	_bow_node.mesh = _make_bow_mesh()
	_bow_node.material_override = _bow_mat
	_bow_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bow_node.visible = false
	add_child(_bow_node)
	# 3) The spray pool: 24 droplets in one MultiMesh, 1 draw call.
	var drop := SphereMesh.new()
	drop.radius = 0.14
	drop.height = 0.28
	drop.radial_segments = 6
	drop.rings = 3
	var spray_material := StandardMaterial3D.new()
	spray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spray_material.vertex_color_use_as_albedo = true
	spray_material.albedo_color = Color(0.94, 0.98, 1.0, 0.95)
	spray_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = spray_material
	_spray_mesh = MultiMesh.new()
	_spray_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_spray_mesh.use_colors = true
	_spray_mesh.mesh = drop
	_spray_mesh.instance_count = SPRAY_MAX
	_spray_mesh.visible_instance_count = 0
	_spray_node = MultiMeshInstance3D.new()
	_spray_node.name = "BowSpray"
	_spray_node.multimesh = _spray_mesh
	_spray_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spray_node.custom_aabb = AABB(Vector3(-12.0, -6.0, -22.0), Vector3(24.0, 16.0, 30.0))
	_spray_node.top_level = true
	_spray_node.visible = false
	add_child(_spray_node)
	_spray_pos.resize(SPRAY_MAX)
	_spray_vel.resize(SPRAY_MAX)
	_spray_life.resize(SPRAY_MAX)
	_spray_max_life.resize(SPRAY_MAX)
	_spray_size.resize(SPRAY_MAX)
	_spray_alive = 0
	_spray_timer = 0.0


func _make_wake_mesh() -> ArrayMesh:
	## Three strips (port arm, foam lane, starboard arm) in one surface. The vertex
	## positions are authored as zero: the shader places them from `wake_pos` /
	## `wake_nrm`, so the mesh is never rebuilt and never re-uploaded.
	var vertex_count := WAKE_SAMPLES * 6
	var vertices := PackedVector3Array()
	vertices.resize(vertex_count)
	var normals := PackedVector3Array()
	normals.resize(vertex_count)
	normals.fill(Vector3.UP)
	var uvs := PackedVector2Array()
	uvs.resize(vertex_count)
	var uv2s := PackedVector2Array()
	uv2s.resize(vertex_count)
	var colors := PackedColorArray()
	colors.resize(vertex_count)
	colors.fill(Color(1.0, 1.0, 1.0, 1.0))
	var indices := PackedInt32Array()
	for strip in 3:
		for index in WAKE_SAMPLES:
			var vertex := strip * WAKE_SAMPLES * 2 + index * 2
			uvs[vertex] = Vector2(float(index), 0.0)
			uvs[vertex + 1] = Vector2(float(index), 1.0)
			uv2s[vertex] = Vector2(float(strip), 0.0)
			uv2s[vertex + 1] = Vector2(float(strip), 0.0)
		for index in WAKE_SAMPLES - 1:
			var base := strip * WAKE_SAMPLES * 2 + index * 2
			indices.append(base)
			indices.append(base + 2)
			indices.append(base + 1)
			indices.append(base + 1)
			indices.append(base + 2)
			indices.append(base + 3)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_bow_mesh() -> ArrayMesh:
	## A thin foam sheet that follows the waterline from the stem aft, plus the crest
	## that piles up at the forefoot. Vertex alpha carries the fade.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scale_z := _length / HULL_LENGTH
	var count := BOW_PROFILE.size()
	for side: float in [-1.0, 1.0]:
		for index in count - 1:
			var a: Array = BOW_PROFILE[index]
			var b: Array = BOW_PROFILE[index + 1]
			var z0: float = float(a[0]) * scale_z
			var z1: float = float(b[0]) * scale_z
			var in0: float = float(a[1])
			var in1: float = float(b[1])
			var w0: float = float(a[2])
			var w1: float = float(b[2])
			var al0: float = float(a[3])
			var al1: float = float(b[3])
			var y0: float = 0.06 + float(a[4])
			var y1: float = 0.06 + float(b[4])
			var u0 := float(index) / float(count - 1)
			var u1 := float(index + 1) / float(count - 1)
			var inner0 := Vector3(side * in0, y0, z0)
			var outer0 := Vector3(side * (in0 + w0), y0 - 0.015, z0)
			var inner1 := Vector3(side * in1, y1, z1)
			var outer1 := Vector3(side * (in1 + w1), y1 - 0.015, z1)
			var c0 := Color(0.93, 0.98, 1.0, al0)
			var c0o := Color(0.93, 0.98, 1.0, al0 * 0.45)
			var c1 := Color(0.93, 0.98, 1.0, al1)
			var c1o := Color(0.93, 0.98, 1.0, al1 * 0.45)
			_bow_vertex(st, inner0, Vector2(u0, 0.0), c0)
			_bow_vertex(st, outer0, Vector2(u0, 1.0), c0o)
			_bow_vertex(st, outer1, Vector2(u1, 1.0), c1o)
			_bow_vertex(st, inner0, Vector2(u0, 0.0), c0)
			_bow_vertex(st, outer1, Vector2(u1, 1.0), c1o)
			_bow_vertex(st, inner1, Vector2(u1, 0.0), c1)
	_add_bow_crest(st, scale_z)
	var mesh: ArrayMesh = st.commit()
	return mesh


func _add_bow_crest(st: SurfaceTool, scale_z: float) -> void:
	## A slanted sheet that stands up at the stem: from a distance this is the bow
	## wave proper, not just a painted line.
	var count := BOW_CREST.size()
	for side: float in [-1.0, 1.0]:
		for index in count - 1:
			var a: Array = BOW_CREST[index]
			var b: Array = BOW_CREST[index + 1]
			var z0: float = float(a[0]) * scale_z
			var z1: float = float(b[0]) * scale_z
			var al0: float = float(a[5])
			var al1: float = float(b[5])
			var u0 := float(index) / float(count - 1)
			var u1 := float(index + 1) / float(count - 1)
			var inner0 := Vector3(side * float(a[1]), float(a[3]), z0)
			var outer0 := Vector3(side * float(a[2]), float(a[4]), z0)
			var inner1 := Vector3(side * float(b[1]), float(b[3]), z1)
			var outer1 := Vector3(side * float(b[2]), float(b[4]), z1)
			var c0 := Color(0.94, 0.98, 1.0, al0)
			var c1 := Color(0.94, 0.98, 1.0, al1)
			var c0o := Color(0.94, 0.98, 1.0, al0 * 0.42)
			var c1o := Color(0.94, 0.98, 1.0, al1 * 0.42)
			_bow_vertex(st, inner0, Vector2(u0, 0.0), c0)
			_bow_vertex(st, outer0, Vector2(u0, 1.0), c0o)
			_bow_vertex(st, outer1, Vector2(u1, 1.0), c1o)
			_bow_vertex(st, inner0, Vector2(u0, 0.0), c0)
			_bow_vertex(st, outer1, Vector2(u1, 1.0), c1o)
			_bow_vertex(st, inner1, Vector2(u1, 0.0), c1)


func _bow_vertex(st: SurfaceTool, position: Vector3, uv: Vector2, color: Color) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(uv)
	st.set_color(color)
	st.add_vertex(position)


func _wake_stern_world() -> Vector3:
	# Start at the transom face, never under the counter.
	var point := _world_from_local(Vector3(0.0, 0.0, _length * 0.5 - 0.4))
	point.y = _water_level + WAKE_LIFT
	return point


func _update_wake(delta: float) -> void:
	if _wake_node == null or not _wake_enabled:
		return
	var started := Time.get_ticks_usec()
	var speed_factor := clampf(_speed / MAX_SPEED, 0.0, 1.0)
	# --- strength follows the speed smoothly, both up and down.
	var target := 0.0
	if _speed > WAKE_MIN_SPEED and not _sunk:
		target = clampf((_speed - WAKE_MIN_SPEED) / (MAX_SPEED - WAKE_MIN_SPEED), 0.0, 1.0)
	if _aground:
		target *= 0.35
	_wake_strength = move_toward(_wake_strength, target, delta * WAKE_FADE_RATE)
	var bow_target := 0.0
	if _speed > BOW_WAVE_SPEED and not _sunk:
		bow_target = clampf((_speed - BOW_WAVE_SPEED) / (BOW_WAVE_FULL - BOW_WAVE_SPEED), 0.0, 1.0)
	if _aground:
		bow_target = minf(bow_target, 0.3)
	_bow_wave = move_toward(_bow_wave, bow_target, delta * 2.6)
	# --- distance-spaced history of the transom; the trail is a real world curve.
	var stern := _wake_stern_world()
	# A teleport (moor, respawn) must never stretch the old trail across the bay.
	if _wake_hist_count > 0 and stern.distance_to(_wake_hist[0]) > WAKE_SPACING * 4.0:
		_wake_hist_count = 0
	var shore := _wake_shore_factor(stern.x, stern.z)
	if _speed > WAKE_MIN_SPEED and not _sunk:
		if _wake_hist_count == 0:
			_wake_hist[0] = stern
			_wake_shade[0] = shore
			_wake_hist_count = 1
		elif stern.distance_to(_wake_hist[0]) >= WAKE_SPACING:
			var last := mini(_wake_hist_count, WAKE_SAMPLES - 1)
			for index in range(last, 0, -1):
				_wake_hist[index] = _wake_hist[index - 1]
				_wake_shade[index] = _wake_shade[index - 1]
			_wake_hist[0] = stern
			_wake_shade[0] = shore
			_wake_hist_count = mini(_wake_hist_count + 1, WAKE_SAMPLES)
	elif _wake_strength <= 0.001:
		# Stopped and gone: the next start lays a fresh trail.
		_wake_hist_count = 0
	# --- path in uniform arrays: index 0 is the live transom, then the history.
	var path_count := 1
	_wake_path[0] = stern
	if _wake_hist_count > 0:
		path_count = mini(_wake_hist_count + 1, WAKE_SAMPLES)
		for index in range(1, path_count):
			_wake_path[index] = _wake_hist[index - 1]
	var normal := _wake_last_normal
	for index in path_count:
		var direction := Vector3(0.0, 0.0, 1.0)
		if index < path_count - 1:
			direction = _wake_path[index] - _wake_path[index + 1]
		elif index > 0:
			direction = _wake_path[index - 1] - _wake_path[index]
		direction.y = 0.0
		var span := direction.length()
		if span > 0.001:
			normal = Vector3(-direction.z, 0.0, direction.x) / span
			_wake_last_normal = normal
		var shade := shore if index == 0 else _wake_shade[index - 1]
		_wake_pos[index] = Vector4(_wake_path[index].x, _wake_path[index].y,
			_wake_path[index].z, shade)
		_wake_nrm[index] = Vector4(normal.x, 0.0, normal.z, 0.0)
	for index in range(path_count, WAKE_SAMPLES):
		_wake_pos[index] = _wake_pos[path_count - 1]
		_wake_nrm[index] = _wake_nrm[path_count - 1]
	var ribbon_visible := _wake_strength > 0.02 and path_count >= 2
	_wake_node.visible = ribbon_visible and _wake_render
	if ribbon_visible:
		_wake_node.transform = Transform3D(Basis.IDENTITY, stern)
		_wake_mat.set_shader_parameter("wake_pos", _wake_pos)
		_wake_mat.set_shader_parameter("wake_nrm", _wake_nrm)
		_wake_mat.set_shader_parameter("valid", float(path_count))
		_wake_mat.set_shader_parameter("strength", _wake_strength)
	_bow_node.visible = _bow_wave > 0.02 and _wake_render
	if _bow_node.visible:
		_bow_mat.set_shader_parameter("strength", _bow_wave)
	# --- spray: bursts off the forefoot only when the bow really breaks water.
	_spray_timer -= delta
	var spraying := _bow_wave > 0.32 and _speed > SPRAY_SPEED and not _sunk and not _aground
	if spraying:
		while _spray_timer <= 0.0:
			_spray_timer += SPRAY_INTERVAL
			_spawn_spray()
	else:
		_spray_timer = maxf(_spray_timer, 0.0)
	_update_spray(delta)
	# --- basin ripples: stern wash + bow push. The 8-slot pool is shared with the
	# host and with gunfire, so the boat only asks for a ring when there is room.
	_wake_ripple_timer -= delta
	if _wake_ripple_timer <= 0.0 and _speed > 0.8 and not _sunk and not _aground \
			and _basin != null and _basin.has_method("add_ripple") and _ripple_room():
		_wake_ripple_timer = lerpf(WAKE_RIPPLE_SLOW, WAKE_RIPPLE_FAST, speed_factor)
		var bow := _world_from_local(Vector3(0.0, 0.0, -_length * 0.5 + 2.0))
		_basin.call("add_ripple", stern, 0.6 + 0.7 * speed_factor)
		_basin.call("add_ripple", bow, 0.4 + 0.5 * speed_factor)
		_ripple_events += 2
	_wake_ms = lerpf(_wake_ms, float(Time.get_ticks_usec() - started) * 0.001, 0.08)


func _ripple_room() -> bool:
	## Leave two of the eight ripple slots free so the water never churns.
	if _basin == null or not _basin.has_method("stats"):
		return true
	var raw: Variant = _basin.call("stats")
	if not raw is Dictionary:
		return true
	var stats := raw as Dictionary
	var active := int(stats.get("ripples_active", 0))
	var pool := int(stats.get("ripple_pool", 8))
	if pool <= 0:
		return true
	return active < pool - 2


func _wake_shore_factor(x: float, z: float) -> float:
	## Foam on dry sand looks wrong: fade the trail out where the water is gone.
	var depth := _depth_at(x, z)
	return clampf((depth - 0.35) / 0.85, 0.0, 1.0)


func _reset_wake() -> void:
	## Called on moor/teleport: the old trail belongs to another place.
	_wake_hist_count = 0
	_wake_strength = 0.0
	_bow_wave = 0.0
	_spray_alive = 0
	_spray_timer = 0.0
	_wake_ripple_timer = 0.0
	_wake_last_normal = Vector3(0.0, 0.0, 1.0)
	if _wake_mat != null:
		_wake_mat.set_shader_parameter("valid", 0.0)
		_wake_mat.set_shader_parameter("strength", 0.0)
	if _bow_mat != null:
		_bow_mat.set_shader_parameter("strength", 0.0)
	if _spray_mesh != null:
		_spray_mesh.visible_instance_count = 0
	if _wake_node != null:
		_wake_node.visible = false
	if _bow_node != null:
		_bow_node.visible = false
	if _spray_node != null:
		_spray_node.visible = false


func _spawn_spray() -> void:
	if _spray_node == null or _spray_alive >= SPRAY_MAX:
		return
	var index := _spray_alive
	_spray_alive += 1
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var local := Vector3(side * _rng.randf_range(0.4, 2.4), 0.12,
		-_length * 0.5 + _rng.randf_range(0.2, 2.4))
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var outward := Vector3(cos(_yaw), 0.0, -sin(_yaw)) * side
	_spray_pos[index] = _world_from_local(local)
	_spray_vel[index] = forward * (_speed * _rng.randf_range(0.35, 0.6)) \
		+ outward * _rng.randf_range(0.8, 2.6) \
		+ Vector3.UP * _rng.randf_range(1.2, 3.4)
	var life := _rng.randf_range(0.45, 0.9)
	_spray_life[index] = life
	_spray_max_life[index] = life
	_spray_size[index] = _rng.randf_range(0.6, 1.5)


func _update_spray(delta: float) -> void:
	if _spray_node == null:
		return
	var alive := _spray_alive
	var index := 0
	while index < alive:
		_spray_life[index] -= delta
		if _spray_life[index] <= 0.0:
			alive -= 1
			_spray_life[index] = _spray_life[alive]
			_spray_max_life[index] = _spray_max_life[alive]
			_spray_size[index] = _spray_size[alive]
			_spray_pos[index] = _spray_pos[alive]
			_spray_vel[index] = _spray_vel[alive]
			continue
		var velocity := _spray_vel[index]
		velocity.y -= SPRAY_GRAVITY * delta
		_spray_vel[index] = velocity
		var position := _spray_pos[index] + velocity * delta
		_spray_pos[index] = position
		if position.y < _water_level - 0.2:
			_spray_life[index] = 0.0
			continue
		index += 1
	_spray_alive = alive
	_spray_node.transform = Transform3D(Basis.IDENTITY, _origin)
	for slot in alive:
		var ratio := clampf(_spray_life[slot] / maxf(_spray_max_life[slot], 0.01), 0.0, 1.0)
		var size: float = _spray_size[slot] * (0.55 + 0.85 * (1.0 - ratio))
		_spray_mesh.set_instance_transform(slot,
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), _spray_pos[slot] - _origin))
		_spray_mesh.set_instance_color(slot, Color(0.93, 0.97, 1.0, 0.9 * pow(ratio, 0.6)))
	_spray_mesh.visible_instance_count = alive
	_spray_node.visible = alive > 0 and _wake_render


func _wake_draw_calls() -> int:
	if not _wake_enabled or not _wake_render:
		return 0
	var count := 0
	if _wake_node != null and _wake_node.visible:
		count += 1
	if _bow_node != null and _bow_node.visible:
		count += 1
	if _spray_node != null and _spray_node.visible:
		count += 1
	return count


## ------------------------------------------------------------------ snapshot

func snapshot() -> Dictionary:
	var hole_worlds: Array[Vector3] = []
	for hole: Dictionary in _holes:
		hole_worlds.append(_world_from_local(hole.get("local", Vector3.ZERO)))
	return {
		"ok": _installed,
		"speed": _speed,
		"speed_mps": _speed,
		"heading": _yaw,
		"heading_deg": rad_to_deg(_yaw),
		"sails_open": _sails_open,
		"flooding": _flooding,
		"flood_rate": _flood_rate,
		"integrity": hull_integrity(),
		"hull_damage": _hull_damage,
		"holes": _holes.size(),
		"hole_worlds": hole_worlds,
		"mast_hp": _mast_hp,
		"mast_broken": _mast_broken,
		"sunk": _sunk,
		"sink_t": _sink_t,
		"position": _origin,
		"rudder": _rudder,
		"rudder_target": _rudder_target,
		"yaw_rate": _yaw_rate,
		"blocked_water": _water_blocked,
		"blocked_obstacle": _obstacle_blocked,
		"debris": _debris_nodes.size(),
		"broken_parts": _broken_parts.duplicate(),
		"water_level": _water_level,
		"pitch": _pitch,
		"roll": _roll,
		"pitch_deg": rad_to_deg(_pitch),
		"roll_deg": rad_to_deg(_roll),
		"heel_deg": rad_to_deg(_heel),
		"wake_strength": _wake_strength,
		"bow_wave": _bow_wave,
		"wake_mesh_visible": _wake_node != null and _wake_node.visible,
		"bow_wave_visible": _bow_node != null and _bow_node.visible,
		"foam_particles": _spray_alive,
		"spray_visible": _spray_node != null and _spray_node.visible,
		"wake_length": wake_length(),
		"wake_draw_calls": _wake_draw_calls(),
		"wake_ms": _wake_ms,
		"wake_enabled": _wake_enabled,
		"wake_render": _wake_render,
		"ripple_events": _ripple_events,
		"speed_factor": _speed_factor,
		"aground": _aground,
		"depth_center": _depth_center,
		"depth_bow": _depth_bow,
		"ground_lift": _ground_lift,
		"collision_disabled": _collision_disabled,
		"moor_position": _moor_position,
		"moor_yaw": _moor_yaw,
		"installed": _installed,
		"usable": usable(),
		"sail_holes": _model_sail_hole_count(),
	}


## ------------------------------------------------------------------ helpers

func _num(value: Variant, fallback: float) -> float:
	if value is float:
		var as_float := float(value)
		return as_float if is_finite(as_float) else fallback
	if value is int:
		return float(value)
	return fallback


func _vector_or(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		var as_vector := value as Vector3
		if as_vector.is_finite():
			return as_vector
	return fallback
