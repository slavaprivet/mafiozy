class_name SiegeBalloon
extends CharacterBody3D
## DSH_BALLOON: a siege hot-air balloon that is flown by choosing a wind layer.
##
## The only direct control is vertical: the burner heats the envelope and climbs,
## the valve vents heat and drops. Horizontally the balloon is carried by one of
## four altitude bands, each with its own direction and strength; a small rudder
## (A/D) only trims. That makes navigation a crew puzzle instead of a flight sim.
##
## Ballast bags give a quick lift, the anchor parks the balloon in the air or on
## the ground, and the basket carries the player while the envelope is a real
## collision body, so the balloon cannot be flown through a wall.

const ENVELOPE_RADIUS := 2.55
const SEAT_Y := 0.12
const MAX_BALLAST := 4
const HEAT_START := 0.40
const HEAT_IDLE := 0.46
const HEAT_BURN := 0.30
const HEAT_VENT := 0.55
const HEAT_COOL := 0.030
const LIFT_SCALE := 14.0
const VERTICAL_ACCEL := 3.2
const MAX_VERTICAL := 8.0
const RUDDER_ACCEL := 3.6
const RUDDER_SPEED := 2.2
const GROUND_PROBE := 0.35

var rider: CharacterBody3D = null
var heat := HEAT_START
var ballast := MAX_BALLAST
var anchored := true
var burner_on := false

var _time := 0.0
var _ground_y := 0.0
var _ground_probe := 0.0
var _base_y := 0.0
var _model: Node3D
var _flame: Node3D
var _anchor_rope: MeshInstance3D
var _flag: Node3D
var _ballast_key := false
var _anchor_key := false
var _last_altitude := 0.0
var _built := false

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
	_built = true
	return true

## ---------------------------------------------------------------- model
func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "BalloonModel"
	add_child(_model)
	var cloth := _envelope_material()
	var wicker := _material(Color(0.34, 0.22, 0.11), 0.95)
	var rim := _material(Color(0.24, 0.14, 0.07), 0.9)
	var rope := _material(Color(0.44, 0.32, 0.17), 0.9)
	var metal := _material(Color(0.35, 0.33, 0.28), 0.5, 0.6)
	# Envelope: a teardrop-ish sphere with a narrow neck and a top cap.
	var envelope := SphereMesh.new()
	envelope.radius = ENVELOPE_RADIUS
	envelope.height = ENVELOPE_RADIUS * 2.0
	envelope.radial_segments = 28
	envelope.rings = 16
	var env := MeshInstance3D.new()
	env.name = "Envelope"
	env.mesh = envelope
	env.material_override = cloth
	env.position = Vector3(0.0, 5.20, 0.0)
	env.scale = Vector3(1.0, 1.0, 1.0)
	env.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_model.add_child(env)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.72
	neck.bottom_radius = 1.10
	neck.height = 0.80
	neck.radial_segments = 20
	var neck_node := MeshInstance3D.new()
	neck_node.mesh = neck
	neck_node.material_override = cloth
	neck_node.position = Vector3(0.0, 2.55, 0.0)
	_model.add_child(neck_node)
	var cap := SphereMesh.new()
	cap.radius = 0.30
	cap.height = 0.38
	var cap_node := MeshInstance3D.new()
	cap_node.mesh = cap
	cap_node.material_override = rim
	cap_node.position = Vector3(0.0, 7.78, 0.0)
	_model.add_child(cap_node)
	# Hollow wicker basket: four walls, a floor and a rim. A solid box would seal a
	# standing crewman under a lid and leave only his hat showing.
	_box_part(Vector3(2.20, 0.10, 2.20), Vector3(0.0, 0.05, 0.0), wicker)
	_box_part(Vector3(2.20, 1.30, 0.12), Vector3(0.0, 0.65, 1.10), wicker)
	_box_part(Vector3(2.20, 1.30, 0.12), Vector3(0.0, 0.65, -1.10), wicker)
	_box_part(Vector3(0.12, 1.30, 2.20), Vector3(1.10, 0.65, 0.0), wicker)
	_box_part(Vector3(0.12, 1.30, 2.20), Vector3(-1.10, 0.65, 0.0), wicker)
	_box_part(Vector3(2.38, 0.12, 0.16), Vector3(0.0, 1.32, 1.12), rim)
	_box_part(Vector3(2.38, 0.12, 0.16), Vector3(0.0, 1.32, -1.12), rim)
	_box_part(Vector3(0.16, 0.12, 2.38), Vector3(1.12, 1.32, 0.0), rim)
	_box_part(Vector3(0.16, 0.12, 2.38), Vector3(-1.12, 1.32, 0.0), rim)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_rope(Vector3(sx * 1.00, 1.02, sz * 1.00), Vector3(sx * 1.20, 3.20, sz * 1.20), 0.030, rope)
	# Burner above the basket, under the envelope mouth.
	var burner := CylinderMesh.new()
	burner.top_radius = 0.26
	burner.bottom_radius = 0.22
	burner.height = 0.42
	burner.radial_segments = 12
	var burner_node := MeshInstance3D.new()
	burner_node.mesh = burner
	burner_node.material_override = metal
	burner_node.position = Vector3(0.0, 2.10, 0.0)
	_model.add_child(burner_node)
	_flame = Node3D.new()
	_flame.name = "BurnerFlame"
	_flame.position = Vector3(0.0, 2.28, 0.0)
	_model.add_child(_flame)
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.05
	flame_mesh.bottom_radius = 0.34
	flame_mesh.height = 0.95
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
	# A wind flag on the crown so the layer direction is readable from the basket.
	_flag = Node3D.new()
	_flag.name = "WindFlag"
	_flag.position = Vector3(0.0, 7.62, 0.0)
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
	# Anchor rope, hidden until the anchor is dropped.
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

func _box_part(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	_model.add_child(node)

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
	basket_shape.size = Vector3(2.3, 1.45, 2.3)
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
	envelope.position = Vector3(0.0, 5.20, 0.0)
	add_child(envelope)
	# The actual standing feet of the basket, used for ground and landing checks.
	var foot_shape := BoxShape3D.new()
	foot_shape.size = Vector3(2.0, 0.10, 2.0)
	var foot := CollisionShape3D.new()
	foot.name = "BasketFoot"
	foot.shape = foot_shape
	foot.position = Vector3(0.0, 0.05, 0.0)
	add_child(foot)

## ---------------------------------------------------------------- flight
func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	_time += delta
	var piloted := is_instance_valid(rider)
	var burner := piloted and Input.is_action_pressed(&"preview_jump")
	var valve := piloted and Input.is_action_pressed(&"preview_run")
	if burner:
		heat += HEAT_BURN * delta
	if valve:
		heat -= HEAT_VENT * delta
	heat = clampf(heat - HEAT_COOL * delta, 0.0, 1.0)
	if piloted:
		var ballast_down := Input.is_key_pressed(KEY_B)
		if ballast_down and not _ballast_key:
			drop_ballast()
		_ballast_key = ballast_down
		var anchor_down := Input.is_key_pressed(KEY_F)
		if anchor_down and not _anchor_key:
			toggle_anchor()
		_anchor_key = anchor_down
	else:
		_ballast_key = false
		_anchor_key = false
	_ground_probe -= delta
	if _ground_probe <= 0.0:
		_ground_probe = 0.2
		_ground_y = _ground_below()
	_last_altitude = global_position.y - _ground_y
	var target_vy := clampf((heat - HEAT_IDLE) * LIFT_SCALE, -MAX_VERTICAL, MAX_VERTICAL)
	velocity.y = move_toward(velocity.y, target_vy, VERTICAL_ACCEL * delta)
	var wind := wind_at_altitude(_last_altitude)
	var rudder := 0.0
	if piloted:
		rudder = Input.get_axis(&"preview_move_left", &"preview_move_right")
	var target_h := Vector3(wind.x + rudder * RUDDER_SPEED, 0.0, wind.z)
	if anchored:
		target_h = Vector3.ZERO
	velocity.x = move_toward(velocity.x, target_h.x, RUDDER_ACCEL * delta)
	velocity.z = move_toward(velocity.z, target_h.z, RUDDER_ACCEL * delta)
	burner_on = burner
	var before := global_position
	move_and_slide()
	if not before.is_finite():
		global_position = Vector3(0.0, 2.0, 0.0)
		velocity = Vector3.ZERO
	_update_visual(delta, piloted)
	_seat_rider()

func wind_at_altitude(altitude: float) -> Vector3:
	var gust := sin(_time * 0.63) * 0.7
	if altitude < 10.0:
		return Vector3(1.2, 0.0, 0.4)
	if altitude < 26.0:
		return Vector3(-2.4 + gust, 0.0, 3.2)
	if altitude < 48.0:
		return Vector3(4.2, 0.0, -2.6 + gust)
	return Vector3(6.5 + gust, 0.0, 1.5)

func altitude() -> float:
	return global_position.y - _ground_y

func drop_ballast() -> bool:
	if ballast <= 0 or not is_instance_valid(rider):
		return false
	ballast -= 1
	velocity.y = minf(MAX_VERTICAL, velocity.y + 2.8)
	return true

func toggle_anchor() -> bool:
	if not is_instance_valid(rider):
		return false
	anchored = not anchored
	if anchored:
		velocity.x = 0.0
		velocity.z = 0.0
	return anchored

func _update_visual(delta: float, piloted: bool) -> void:
	if not is_instance_valid(_model):
		return
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() > 0.4:
		var wanted := atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, wanted, minf(1.0, delta * 1.6))
	# The envelope leans into the motion; the basket stays level.
	var lean := clampf(horizontal.length() * 0.012, 0.0, 0.12)
	var side := 0.0
	if horizontal.length() > 0.3:
		side = clampf((horizontal.normalized().x) * -lean, -0.10, 0.10)
	_model.rotation.z = lerpf(_model.rotation.z, side, minf(1.0, delta * 3.0))
	_model.rotation.x = lerpf(_model.rotation.x, -clampf(velocity.y * 0.008, -0.05, 0.05), minf(1.0, delta * 3.0))
	_flame.visible = burner_on
	if burner_on:
		var flicker := 0.86 + sin(_time * 23.0) * 0.14
		_flame.scale = Vector3(flicker, 0.85 + sin(_time * 17.0) * 0.15, flicker)
	if is_instance_valid(_flag):
		var wind := wind_at_altitude(altitude())
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
	# The rope hangs from the basket bottom to the ground in the balloon's own space.
	add_rope_segment(_model, _anchor_rope, from, Vector3(0.0, 0.08 - length, 0.0))

func _seat_rider() -> void:
	if not is_instance_valid(rider):
		return
	rider.global_position = global_position + Vector3(0.0, SEAT_Y, 0.0)
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
	return {"position": global_position, "altitude": altitude(), "heat": heat,
		"ballast": ballast, "anchored": anchored, "burner": burner_on,
		"rider": is_instance_valid(rider), "velocity": velocity,
		"wind": wind_at_altitude(altitude()), "yaw": rotation.y}
