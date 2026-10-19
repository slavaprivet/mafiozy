class_name SiegeBalloon
extends CharacterBody3D
## DSH_BALLOON: a simple, readable siege balloon.
##
## It always glides slowly forward in the direction it is pointing and sinks
## gently when nobody holds the lift. Space lifts, Shift descends, A/D turns the
## nose. A visible dust gust crosses the camp every few seconds and pushes the
## balloon sideways, so the crew has to steer into it. No heat, no ballast: the
## point is the flight and the view, not a simulator.
##
## The envelope is a real collision body, so the balloon cannot be flown through
## a wall, and the basket is a hollow two-person wicker tub.

const ENVELOPE_RADIUS := 2.90
const SEAT_Y := 0.12
const SEAT_HALF_X := 1.55
const SEAT_HALF_Z := 1.10
const SEAT_MOVE_SPEED := 1.4
const CREW_COUNT := 5
const PASSENGER_WEIGHT := 90.0
const BASE_CEILING := 16.0
const CEILING_PER_SOUL := 2.0
const GLIDE_FORWARD := 2.0
const GLIDE_SINK := -0.5
const THROTTLE_SPEED := 2.8
const LIFT_SPEED := 4.5
const DOWN_SPEED := -3.5
const VERTICAL_ACCEL := 3.0
const HORIZONTAL_ACCEL := 2.8
const TURN_RATE := 1.1
const HEAT_UP := 0.055
const HEAT_COOL := 0.09
const AMBIENT_WIND := Vector3(1.2, 0.0, 0.4)
const GUST_MIN_GAP := 7.0
const GUST_MAX_GAP := 13.0
const GUST_DURATION := 1.8
const GUST_MIN_SPEED := 3.5
const GUST_MAX_SPEED := 6.5
const GUST_COUNT := 40
const GUST_HALF := 9.0
const ROPE_POINTS := 6
const ROPE_SEGMENTS := 5
const ROPE_SLACK := 1.04

var rider: CharacterBody3D = null
var anchored := false
var lift_on := false
var gust_active := false
var gust_dir := Vector3.ZERO
var gust_speed := 0.0
var heat := 0.0
var popped := false
var crew := CREW_COUNT
var load := 1.0
var weight := 0.0
var max_altitude := 5.0
var load_factor := 1.0
var debug_lift := false

var _time := 0.0
var _ground_y := 0.0
var _ground_probe := 0.0
var _base_y := 0.0
var _built := false
var _model: Node3D
var _basket_node: Node3D
var _envelope: MeshInstance3D
var _neck: MeshInstance3D
var _flame: Node3D
var _anchor_rope: MeshInstance3D
var _flag: Node3D
var _gust_mm: MultiMeshInstance3D
var _gust_points: Array[Vector3] = []
var _gust_left := 0.0
var _gust_timer := 6.0
var _anchor_key := false
var _last_altitude := 0.0
var _lean := 0.0
var _throttle := 0.0
var _seat := Vector2.ZERO
var _airborne := false
var _crew_people: Array[Node3D] = []
var _tilt_roll := 0.0
var _tilt_pitch := 0.0
var _last_velocity := Vector3.ZERO
var _suspension_mm: MultiMeshInstance3D
var _suspension_points: Array[PackedVector3Array] = []
var _suspension_prev: Array[PackedVector3Array] = []
var _suspension_rest: Array[float] = []

func setup(at: Vector3, yaw: float) -> bool:
	if _built:
		return false
	name = "SiegeBalloon"
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	up_direction = Vector3.UP
	floor_snap_length = 0.0
	global_position = at
	rotation.y = yaw
	_base_y = at.y
	_ground_y = at.y
	_build_model()
	_build_collision()
	_build_gust_visual()
	_build_suspension()
	_built = true
	return true

## ---------------------------------------------------------------- model
func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "BalloonModel"
	add_child(_model)
	var cloth := _envelope_material()
	var wicker := _material(Color(0.36, 0.23, 0.12), 0.95)
	var rim := _material(Color(0.22, 0.13, 0.07), 0.9)
	var rope := _material(Color(0.44, 0.32, 0.17), 0.9)
	var metal := _material(Color(0.35, 0.33, 0.28), 0.5, 0.6)
	# Envelope.
	var envelope := SphereMesh.new()
	envelope.radius = ENVELOPE_RADIUS
	envelope.height = ENVELOPE_RADIUS * 2.0
	envelope.radial_segments = 28
	envelope.rings = 16
	var env := MeshInstance3D.new()
	env.name = "Envelope"
	env.mesh = envelope
	env.material_override = cloth
	env.position = Vector3(0.0, 5.60, 0.0)
	env.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_model.add_child(env)
	_envelope = env
	var neck := CylinderMesh.new()
	neck.top_radius = 0.72
	neck.bottom_radius = 1.10
	neck.height = 0.80
	neck.radial_segments = 20
	var neck_node := MeshInstance3D.new()
	neck_node.mesh = neck
	neck_node.material_override = cloth
	neck_node.position = Vector3(0.0, 2.90, 0.0)
	_model.add_child(neck_node)
	_neck = neck_node
	var cap := SphereMesh.new()
	cap.radius = 0.30
	cap.height = 0.38
	var cap_node := MeshInstance3D.new()
	cap_node.mesh = cap
	cap_node.material_override = rim
	cap_node.position = Vector3(0.0, 8.65, 0.0)
	_model.add_child(cap_node)
	# Hollow crew basket: big enough for a whole crowd (5 crew + the player).
	_basket_node = Node3D.new()
	_basket_node.name = "Basket"
	_model.add_child(_basket_node)
	_box_part(Vector3(3.80, 0.10, 2.80), Vector3(0.0, 0.05, 0.0), wicker, _basket_node)
	_box_part(Vector3(3.80, 1.30, 0.12), Vector3(0.0, 0.65, 1.34), wicker, _basket_node)
	_box_part(Vector3(3.80, 1.30, 0.12), Vector3(0.0, 0.65, -1.34), wicker, _basket_node)
	_box_part(Vector3(0.12, 1.30, 2.80), Vector3(1.84, 0.65, 0.0), wicker, _basket_node)
	_box_part(Vector3(0.12, 1.30, 2.80), Vector3(-1.84, 0.65, 0.0), wicker, _basket_node)
	_box_part(Vector3(3.98, 0.12, 0.16), Vector3(0.0, 1.32, 1.36), rim, _basket_node)
	_box_part(Vector3(3.98, 0.12, 0.16), Vector3(0.0, 1.32, -1.36), rim, _basket_node)
	_box_part(Vector3(0.16, 0.12, 2.98), Vector3(1.86, 1.32, 0.0), rim, _basket_node)
	_box_part(Vector3(0.16, 0.12, 2.98), Vector3(-1.86, 1.32, 0.0), rim, _basket_node)
	# Benches down both sides, a place for the crowd to sit or lean.
	_box_part(Vector3(0.52, 0.10, 2.40), Vector3(-1.55, 0.80, 0.0), wicker, _basket_node)
	_box_part(Vector3(0.52, 0.10, 2.40), Vector3(1.55, 0.80, 0.0), wicker, _basket_node)
	_build_crew(_basket_node)
	# Four suspension ropes are built as live Verlet chains in _build_suspension.
	# Burner, raised clear of the crew's heads, and a metal heat shield below it.
	var shield := CylinderMesh.new()
	shield.top_radius = 0.70
	shield.bottom_radius = 0.70
	shield.height = 0.06
	shield.radial_segments = 16
	var shield_node := MeshInstance3D.new()
	shield_node.mesh = shield
	shield_node.material_override = metal
	shield_node.position = Vector3(0.0, 2.10, 0.0)
	_model.add_child(shield_node)
	var burner := CylinderMesh.new()
	burner.top_radius = 0.24
	burner.bottom_radius = 0.20
	burner.height = 0.36
	burner.radial_segments = 12
	var burner_node := MeshInstance3D.new()
	burner_node.mesh = burner
	burner_node.material_override = metal
	burner_node.position = Vector3(0.0, 2.50, 0.0)
	_model.add_child(burner_node)
	_flame = Node3D.new()
	_flame.name = "BurnerFlame"
	_flame.position = Vector3(0.0, 2.85, 0.0)
	_model.add_child(_flame)
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.04
	flame_mesh.bottom_radius = 0.22
	flame_mesh.height = 0.50
	flame_mesh.radial_segments = 8
	var flame_mat := _material(Color(1.0, 0.52, 0.12), 0.4)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.42, 0.08)
	flame_mat.emission_energy_multiplier = 4.0
	var flame := MeshInstance3D.new()
	flame.mesh = flame_mesh
	flame.material_override = flame_mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.add_child(flame)
	_flame.visible = false
	# Wind flag on the crown.
	_flag = Node3D.new()
	_flag.name = "WindFlag"
	_flag.position = Vector3(0.0, 8.55, 0.0)
	_model.add_child(_flag)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.018
	pole.bottom_radius = 0.024
	pole.height = 0.9
	var pole_node := MeshInstance3D.new()
	pole_node.mesh = pole
	pole_node.material_override = rope
	pole_node.position = Vector3(0.0, 0.45, 0.0)
	_flag.add_child(pole_node)
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.58, 0.30, 0.02)
	var flag_cloth := MeshInstance3D.new()
	flag_cloth.mesh = cloth_mesh
	flag_cloth.material_override = _material(Color(0.72, 0.12, 0.10), 0.9)
	flag_cloth.position = Vector3(0.29, 0.78, 0.0)
	_flag.add_child(flag_cloth)
	# Anchor rope.
	_anchor_rope = MeshInstance3D.new()
	_anchor_rope.name = "AnchorRope"
	_anchor_rope.mesh = CylinderMesh.new()
	(_anchor_rope.mesh as CylinderMesh).top_radius = 0.018
	(_anchor_rope.mesh as CylinderMesh).bottom_radius = 0.022
	(_anchor_rope.mesh as CylinderMesh).height = 1.0
	(_anchor_rope.mesh as CylinderMesh).radial_segments = 5
	_anchor_rope.material_override = rope
	_anchor_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anchor_rope.visible = false
	_model.add_child(_anchor_rope)

func _envelope_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec3 panel_a : source_color = vec3(0.52, 0.09, 0.07);
uniform vec3 panel_b : source_color = vec3(0.82, 0.70, 0.47);
void fragment() {
	float stripe = step(0.5, fract(UV.x * 7.0));
	ALBEDO = mix(panel_a, panel_b, stripe);
	ROUGHNESS = 0.88;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _material(colour: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	return material

func _box_part(size: Vector3, at: Vector3, material: Material, parent: Node3D = null) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	(parent if parent != null else _model).add_child(node)

## Five low-poly crewmen packed into the basket. Their count is the balloon's load:
## every extra body lowers the ceiling and makes every control heavier.
func _build_crew(parent: Node3D) -> void:
	var spots: Array[Vector3] = [
		Vector3(-1.40, 0.12, -0.85),
		Vector3(1.40, 0.12, -0.85),
		Vector3(-1.40, 0.12, 0.85),
		Vector3(1.40, 0.12, 0.85),
		Vector3(0.0, 0.12, -1.18),
	]
	var tunics: Array[Color] = [
		Color(0.36, 0.32, 0.22), Color(0.28, 0.34, 0.24), Color(0.40, 0.24, 0.18),
		Color(0.30, 0.28, 0.36), Color(0.46, 0.36, 0.16),
	]
	var skin := _material(Color(0.74, 0.58, 0.44), 0.9)
	var hat_mat := _material(Color(0.18, 0.14, 0.10), 0.95)
	for index: int in spots.size():
		var person := Node3D.new()
		person.position = spots[index]
		parent.add_child(person)
		_crew_people.append(person)
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.20
		body_mesh.height = 0.90
		body_mesh.radial_segments = 8
		body_mesh.rings = 4
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = _material(tunics[index], 0.95)
		body.position = Vector3(0.0, 0.52, 0.0)
		person.add_child(body)
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.17
		head_mesh.height = 0.30
		head_mesh.radial_segments = 10
		head_mesh.rings = 6
		var head := MeshInstance3D.new()
		head.mesh = head_mesh
		head.material_override = skin
		head.position = Vector3(0.0, 1.08, 0.0)
		person.add_child(head)
		var hat_mesh := CylinderMesh.new()
		hat_mesh.top_radius = 0.17
		hat_mesh.bottom_radius = 0.22
		hat_mesh.height = 0.10
		hat_mesh.radial_segments = 8
		var hat := MeshInstance3D.new()
		hat.mesh = hat_mesh
		hat.material_override = hat_mat
		hat.position = Vector3(0.0, 1.24, 0.0)
		person.add_child(hat)

func _rope(from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = width
	mesh.bottom_radius = width * 1.1
	mesh.height = 1.0
	mesh.radial_segments = 5
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	add_rope_segment(_model, node, from, to)

func add_rope_segment(parent: Node3D, node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return
	var y_axis := delta / length
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length_squared() < 0.0001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	node.transform = Transform3D(Basis(x_axis, y_axis * length, z_axis), (from + to) * 0.5)
	node.visible = true
	if node.get_parent() == null:
		parent.add_child(node)

func _build_collision() -> void:
	var basket_shape := BoxShape3D.new()
	basket_shape.size = Vector3(4.0, 1.45, 3.0)
	var basket := CollisionShape3D.new()
	basket.name = "BasketCollider"
	basket.shape = basket_shape
	basket.position = Vector3(0.0, 0.72, 0.0)
	add_child(basket)
	var envelope_shape := SphereShape3D.new()
	envelope_shape.radius = ENVELOPE_RADIUS
	var envelope := CollisionShape3D.new()
	envelope.name = "EnvelopeCollider"
	envelope.shape = envelope_shape
	envelope.position = Vector3(0.0, 5.60, 0.0)
	add_child(envelope)
	var foot_shape := BoxShape3D.new()
	foot_shape.size = Vector3(3.6, 0.10, 2.6)
	var foot := CollisionShape3D.new()
	foot.name = "BasketFoot"
	foot.shape = foot_shape
	foot.position = Vector3(0.0, 0.05, 0.0)
	add_child(foot)

## ---------------------------------------------------------------- gust visual
func _build_gust_visual() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.045, 1.60)
	var material := _material(Color(0.93, 0.88, 0.72), 0.95)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.72
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = GUST_COUNT
	for index: int in GUST_COUNT:
		var point := Vector3(
			randf_range(-GUST_HALF, GUST_HALF),
			randf_range(-1.5, 8.0),
			randf_range(-GUST_HALF, GUST_HALF))
		_gust_points.append(point)
		mm.set_instance_transform(index, Transform3D(Basis(), global_position + point))
	_gust_mm = MultiMeshInstance3D.new()
	_gust_mm.name = "GustDust"
	_gust_mm.multimesh = mm
	_gust_mm.material_override = material
	_gust_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gust_mm.top_level = true
	_gust_mm.visible = false
	add_child(_gust_mm)
	_gust_mm.global_transform = Transform3D()

## ---------------------------------------------------------------- suspension ropes
## Four Verlet chains from the basket rim to the envelope shoulders. Both ends move
## with the balloon, so acceleration, a turn or a gust makes the ropes lag and sway
## instead of standing as rigid sticks.
func _build_suspension() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.028
	mesh.bottom_radius = 0.031
	mesh.height = 1.0
	mesh.radial_segments = 5
	var material := _material(Color(0.44, 0.32, 0.17), 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = ROPE_SEGMENTS * 4
	_suspension_mm = MultiMeshInstance3D.new()
	_suspension_mm.name = "SuspensionRopes"
	_suspension_mm.multimesh = mm
	_suspension_mm.material_override = material
	_suspension_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_suspension_mm.top_level = true
	add_child(_suspension_mm)
	_suspension_mm.global_transform = Transform3D()
	_init_suspension()

func _init_suspension() -> void:
	_suspension_points.clear()
	_suspension_prev.clear()
	_suspension_rest.clear()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var bottom := _basket_global(Vector3(sx * 1.90, 1.02, sz * 1.35))
			var top := to_global(Vector3(sx * 1.60, 3.60, sz * 1.30))
			var pts := PackedVector3Array()
			pts.resize(ROPE_POINTS)
			for index: int in ROPE_POINTS:
				pts[index] = bottom.lerp(top, float(index) / float(ROPE_POINTS - 1))
			_suspension_points.append(pts)
			_suspension_prev.append(pts.duplicate())
			var length := bottom.distance_to(top)
			_suspension_rest.append(maxf(0.08, length / float(ROPE_POINTS - 1) * ROPE_SLACK))

func _update_suspension(delta: float) -> void:
	if not is_instance_valid(_suspension_mm):
		return
	if popped:
		_suspension_mm.visible = false
		return
	_suspension_mm.visible = true
	var corners := [
		[Vector3(-1.90, 1.02, -1.35), Vector3(-1.60, 3.60, -1.30)],
		[Vector3(1.90, 1.02, -1.35), Vector3(1.60, 3.60, -1.30)],
		[Vector3(-1.90, 1.02, 1.35), Vector3(-1.60, 3.60, 1.30)],
		[Vector3(1.90, 1.02, 1.35), Vector3(1.60, 3.60, 1.30)],
	]
	for rope_index: int in 4:
		var pts: PackedVector3Array = _suspension_points[rope_index]
		var prev: PackedVector3Array = _suspension_prev[rope_index]
		var rest: float = _suspension_rest[rope_index]
		var bottom := _basket_global(corners[rope_index][0])
		var top := to_global(corners[rope_index][1])
		pts[0] = bottom
		pts[ROPE_POINTS - 1] = top
		for index: int in range(1, ROPE_POINTS - 1):
			var velocity := (pts[index] - prev[index]) * 0.88
			prev[index] = pts[index]
			pts[index] += velocity + Vector3.DOWN * 9.8 * delta * delta
		for iteration: int in 2:
			for index: int in range(ROPE_POINTS - 1):
				var delta_v := pts[index + 1] - pts[index]
				var distance := delta_v.length()
				if distance < 0.0001:
					continue
				var correction := (distance - rest) / distance * 0.5
				if index > 0:
					pts[index] += delta_v * correction
				if index + 1 < ROPE_POINTS - 1:
					pts[index + 1] -= delta_v * correction
			pts[0] = bottom
			pts[ROPE_POINTS - 1] = top
		_suspension_points[rope_index] = pts
		_suspension_prev[rope_index] = prev
	# One MultiMesh for every rope segment.
	var mm := _suspension_mm.multimesh
	var slot := 0
	for rope_index: int in 4:
		var pts: PackedVector3Array = _suspension_points[rope_index]
		for index: int in range(ROPE_POINTS - 1):
			var a := pts[index]
			var b := pts[index + 1]
			var segment := b - a
			var length := segment.length()
			if length < 0.01:
				mm.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ZERO), a))
			else:
				var y_axis := segment / length
				var x_axis := y_axis.cross(Vector3.UP)
				if x_axis.length_squared() < 0.0001:
					x_axis = y_axis.cross(Vector3.RIGHT)
				x_axis = x_axis.normalized()
				var z_axis := x_axis.cross(y_axis).normalized()
				mm.set_instance_transform(slot, Transform3D(Basis(x_axis, y_axis * length, z_axis), (a + b) * 0.5))
			slot += 1

## ---------------------------------------------------------------- flight
func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	_time += delta
	var piloted := is_instance_valid(rider)
	var lift := piloted and (Input.is_action_pressed(&"preview_jump") or debug_lift)
	var throttle := 0.0
	# Weight steering: the pilot physically walks around the basket. Moving the
	# weight forward makes the balloon glide faster, sideways makes it bank and
	# turn, and the hanging basket visibly tips under the crowd.
	load = (1.0 if piloted else 0.0) + float(crew)
	weight = load * PASSENGER_WEIGHT
	load_factor = 1.0 + 0.15 * maxf(0.0, load - 1.0)
	max_altitude = 100.0
	if piloted:
		var move := Input.get_vector(&"preview_move_left", &"preview_move_right",
			&"preview_move_forward", &"preview_move_back")
		_seat += move * SEAT_MOVE_SPEED * delta
		_seat.x = clampf(_seat.x, -SEAT_HALF_X, SEAT_HALF_X)
		_seat.y = clampf(_seat.y, -SEAT_HALF_Z, SEAT_HALF_Z)
	else:
		_seat = _seat.move_toward(Vector2.ZERO, delta * 1.2)
	_lean = _seat.x / SEAT_HALF_X
	_throttle = -_seat.y / SEAT_HALF_Z
	throttle = _throttle
	_airborne = _last_altitude > 0.6
	# The weight only steers while the balloon is actually in the air. On the
	# ground walking around the basket must not turn or drag the balloon.
	if piloted and _airborne:
		rotation.y -= _lean * (TURN_RATE / load_factor) * delta
	_ground_probe -= delta
	if _ground_probe <= 0.0:
		_ground_probe = 0.2
		_ground_y = _ground_below()
	_last_altitude = global_position.y - _ground_y
	# Holding Space heats the envelope: hold it too long and the balloon pops.
	if lift:
		heat = minf(1.0, heat + HEAT_UP * delta)
	else:
		heat = maxf(0.0, heat - HEAT_COOL * delta)
	if heat >= 1.0 and not popped:
		pop()
	if popped:
		velocity.y = move_toward(velocity.y, -4.0, 3.0 * delta)
		# A burst balloon drops straight down and then lies still; it must not
		# sail along the ground with the ambient wind.
		velocity.x = move_toward(velocity.x, 0.0, 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 4.0 * delta)
		var before_pop := global_position
		move_and_slide()
		if not before_pop.is_finite():
			global_position = Vector3(0.0, 2.0, 0.0)
			velocity = Vector3.ZERO
		if _last_altitude < 0.35:
			velocity = Vector3.ZERO
		_update_visual(delta)
		_update_basket_tilt(delta, 0.0)
		_update_suspension(delta)
		_seat_rider()
		return
	# Glide: lift on Space, otherwise a gentle sink; Shift drops faster. A heavy
	# A heavy basket climbs slower, but there is no height limit: the crew can
	# always take her higher, it just takes longer.
	var lift_speed := LIFT_SPEED / load_factor
	var target_vy := lift_speed if lift else (GLIDE_SINK * load_factor)
	velocity.y = move_toward(velocity.y, target_vy, (VERTICAL_ACCEL / load_factor) * delta)
	lift_on = lift
	# Visible side gusts.
	_gust_timer -= delta
	if _gust_left <= 0.0 and piloted and _airborne and _gust_timer <= 0.0:
		start_gust()
	if _gust_left > 0.0:
		_gust_left -= delta
		if _gust_left <= 0.0:
			_end_gust()
	var gust := gust_dir * gust_speed if _gust_left > 0.0 else Vector3.ZERO
	var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var target_h := forward * ((GLIDE_FORWARD + throttle * THROTTLE_SPEED) / load_factor) + AMBIENT_WIND + gust
	if not _airborne:
		target_h = Vector3.ZERO
	velocity.x = move_toward(velocity.x, target_h.x, (HORIZONTAL_ACCEL / load_factor) * delta)
	velocity.z = move_toward(velocity.z, target_h.z, (HORIZONTAL_ACCEL / load_factor) * delta)
	var before := global_position
	move_and_slide()
	if not before.is_finite():
		global_position = Vector3(0.0, 2.0, 0.0)
		velocity = Vector3.ZERO
	_update_visual(delta)
	_update_basket_tilt(delta, throttle)
	_update_gust_visual(delta)
	_update_suspension(delta)
	_seat_rider()

## The basket hangs from the envelope: leaning on A/D (and the weight of the
## crowd) rolls it, W/S pitches it, and acceleration makes it swing a little.
func _update_basket_tilt(delta: float, throttle: float) -> void:
	if not is_instance_valid(_basket_node):
		return
	var crowd := 1.0 + 0.08 * maxf(0.0, load - 1.0)
	var target_roll := -_seat.x * 0.18 * crowd
	var target_pitch := _seat.y * 0.10 * crowd
	var acceleration := (velocity - _last_velocity) / maxf(delta, 0.001)
	_last_velocity = velocity
	var right := global_transform.basis.x
	var forward := global_transform.basis.z
	target_roll += clampf(-acceleration.dot(right) * 0.020, -0.14, 0.14)
	target_pitch += clampf(acceleration.dot(forward) * 0.015, -0.12, 0.12)
	_tilt_roll = lerpf(_tilt_roll, target_roll, minf(1.0, delta * 6.0))
	_tilt_pitch = lerpf(_tilt_pitch, target_pitch, minf(1.0, delta * 6.0))
	var pivot := Vector3(0.0, 3.30, 0.0)
	var basis := Basis.from_euler(Vector3(_tilt_pitch, 0.0, _tilt_roll))
	_basket_node.transform = Transform3D(basis, pivot - basis * pivot)
	# The crew are alive: a small idle bob and sway keeps the basket from looking
	# like a wax museum.
	for index: int in _crew_people.size():
		var person: Node3D = _crew_people[index]
		if not is_instance_valid(person):
			continue
		person.position.y = 0.12 + sin(_time * 1.8 + float(index) * 1.4) * 0.025
		person.rotation.z = sin(_time * 1.1 + float(index) * 1.7) * 0.025

func _basket_global(local: Vector3) -> Vector3:
	if is_instance_valid(_basket_node):
		return _basket_node.global_transform * local
	return to_global(local)

## Holding Space too long bursts the envelope; the balloon drops and the host
## ejects the crew, then respawns the deflated balloon in the camp.
func pop() -> void:
	if popped:
		return
	popped = true
	heat = 1.0
	anchored = false
	lift_on = false
	velocity = Vector3.ZERO
	if is_instance_valid(_envelope): _envelope.visible = false
	if is_instance_valid(_neck): _neck.visible = false
	if is_instance_valid(_suspension_mm): _suspension_mm.visible = false
	if is_instance_valid(_flame): _flame.visible = false
	print("DSH_BALLOON_POP at=", global_position)

func respawn(at: Vector3, yaw: float) -> void:
	popped = false
	heat = 0.0
	anchored = false
	velocity = Vector3.ZERO
	global_position = at
	rotation.y = yaw
	_gust_left = 0.0
	gust_active = false
	_gust_timer = 6.0
	if is_instance_valid(_envelope): _envelope.visible = true
	if is_instance_valid(_neck): _neck.visible = true
	if is_instance_valid(_flame): _flame.visible = false
	_init_suspension()
	if is_instance_valid(_suspension_mm): _suspension_mm.visible = true
	print("DSH_BALLOON_RESPAWN at=", at)

func start_gust(direction: Vector3 = Vector3.ZERO, strength: float = -1.0) -> void:
	if _gust_left > 0.0:
		return
	if direction.length_squared() < 0.01:
		var side := 1.0 if randf() < 0.5 else -1.0
		var angle := -rotation.y + side * (PI * 0.5 + randf_range(-0.45, 0.45))
		direction = Vector3(cos(angle), 0.0, sin(angle))
	gust_dir = direction.normalized()
	gust_speed = strength if strength > 0.0 else randf_range(GUST_MIN_SPEED, GUST_MAX_SPEED)
	_gust_left = GUST_DURATION
	_gust_timer = randf_range(GUST_MIN_GAP, GUST_MAX_GAP)
	gust_active = true
	print("DSH_BALLOON_GUST dir=", gust_dir, " speed=", gust_speed)

func _end_gust() -> void:
	_gust_left = 0.0
	gust_active = false
	if is_instance_valid(_gust_mm):
		_gust_mm.visible = false

func _update_gust_visual(delta: float) -> void:
	if not is_instance_valid(_gust_mm):
		return
	if _gust_left <= 0.0:
		_gust_mm.visible = false
		return
	_gust_mm.visible = true
	var mm := _gust_mm.multimesh
	for index: int in GUST_COUNT:
		var point: Vector3 = _gust_points[index] + gust_dir * gust_speed * delta
		point.x = wrapf(point.x, -GUST_HALF, GUST_HALF)
		point.z = wrapf(point.z, -GUST_HALF, GUST_HALF)
		point.y = clampf(point.y, -2.0, 7.0)
		_gust_points[index] = point
		var at := global_position + point
		var z_axis := gust_dir
		var x_axis := z_axis.cross(Vector3.UP)
		if x_axis.length_squared() < 0.0001:
			x_axis = z_axis.cross(Vector3.RIGHT)
		x_axis = x_axis.normalized()
		var y_axis := x_axis.cross(z_axis).normalized()
		mm.set_instance_transform(index, Transform3D(Basis(x_axis, y_axis, z_axis), at))

func wind_now() -> Vector3:
	var gust := gust_dir * gust_speed if _gust_left > 0.0 else Vector3.ZERO
	return AMBIENT_WIND + gust

func altitude() -> float:
	return global_position.y - _ground_y

func toggle_anchor() -> bool:
	if not is_instance_valid(rider):
		return false
	anchored = not anchored
	if anchored:
		velocity.x = 0.0
		velocity.z = 0.0
	return anchored

func _update_visual(delta: float) -> void:
	if not is_instance_valid(_model):
		return
	var horizontal := Vector2(velocity.x, velocity.z)
	var lean := clampf(horizontal.length() * 0.012, 0.0, 0.12)
	var side := 0.0
	if horizontal.length() > 0.3:
		side = clampf(horizontal.normalized().x * -lean, -0.10, 0.10)
	_model.rotation.z = lerpf(_model.rotation.z, side, minf(1.0, delta * 3.0))
	_model.rotation.x = lerpf(_model.rotation.x, -clampf(velocity.y * 0.008, -0.05, 0.05), minf(1.0, delta * 3.0))
	_flame.visible = lift_on
	if lift_on:
		var flicker := 0.86 + sin(_time * 23.0) * 0.14
		_flame.scale = Vector3(flicker, 0.85 + sin(_time * 17.0) * 0.15, flicker)
	if is_instance_valid(_flag):
		var wind := wind_now()
		if wind.length_squared() > 0.01:
			_flag.rotation.y = atan2(wind.x, wind.z) + PI * 0.5
	_update_anchor_rope()

func _update_anchor_rope() -> void:
	if not is_instance_valid(_anchor_rope):
		return
	_anchor_rope.visible = anchored
	if not anchored:
		return
	var from := Vector3(0.0, 0.08, 0.0)
	var length := maxf(0.2, global_position.y - _ground_y)
	add_rope_segment(_model, _anchor_rope, from, Vector3(0.0, 0.08 - length, 0.0))

func _seat_rider() -> void:
	if not is_instance_valid(rider):
		return
	rider.global_position = _basket_global(Vector3(_seat.x, SEAT_Y, _seat.y))
	rider.velocity = Vector3.ZERO
	rider._heading = rotation.y
	var visual: Node3D = rider.get("_visual") as Node3D
	if is_instance_valid(visual):
		visual.rotation.y = rotation.y + deg_to_rad(float(rider.get("visual_yaw_degrees")))

func _ground_below() -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return _base_y
	var ray := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5, global_position - Vector3.UP * 60.0, 1)
	ray.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(ray)
	return float(hit.position.y) if not hit.is_empty() else _base_y

func snapshot() -> Dictionary:
	return {"position": global_position, "altitude": altitude(), "anchored": anchored,
		"rider": is_instance_valid(rider), "velocity": velocity, "lift": lift_on,
		"heat": heat, "popped": popped,
		"crew": crew, "load": load, "weight": weight, "max_altitude": max_altitude,
		"load_factor": load_factor, "lean": _lean, "tilt_roll": _tilt_roll, "tilt_pitch": _tilt_pitch,
		"seat": _seat, "throttle": _throttle, "airborne": _airborne,
		"gust": gust_active, "gust_dir": gust_dir, "gust_speed": gust_speed,
		"wind": wind_now(), "yaw": rotation.y}
