class_name CastleHorse
extends CharacterBody3D
## The castle horse: a real CharacterBody3D with swept collision, procedural
## medieval presentation and a rider socket. It owns its own locomotion while a
## rider is seated; the mount host owns E, the seated pose and dismount placement.
##
## Collision layer 1 is the same world/actor layer every resident body uses, so the
## walking player, the camera arm and the horse all agree on what is solid.

const TROT_SPEED := 7.0
const GALLOP_SPEED := 12.5
const GROUND_ACCELERATION := 8.5
const AIR_ACCELERATION := 3.4
const BRAKE := 12.0
const TURN_RATE := 8.0
const JUMP_SPEED := 8.4
const FALL_GRAVITY := 20.0
## The body collider is a swept capsule over the barrel; a second, lower capsule is
## what actually stands on the ground, so hooves touch the floor but the barrel
## still stops at a wall.
const BODY_RADIUS := 0.42
const BODY_LENGTH := 1.95
const BODY_CENTRE_Y := 1.24
const FEET_RADIUS := 0.26
const FEET_HEIGHT := 0.85
const SEAT_Y := 1.895
const SEAT_Z := 0.02
const RIDER_FALLBACK_HIP := 0.49
const MAX_HP := 100.0
const MELEE_DAMAGE := 16.0
const ARROW_BASE_DAMAGE := 10.0
const ARROW_SPEED_DAMAGE := 1.6
const MELEE_COOLDOWN_MS := 380
const BloodFx = preload("res://scripts/mount/horse_blood.gd")

var rider: CharacterBody3D = null
var rider_hip := RIDER_FALLBACK_HIP
var damage_owner: Node3D = null
var hp := MAX_HP
var dead := false
var corpse: RigidBody3D = null
var hits_taken := 0
var last_hit_kind := ""
var last_hit_at := Vector3.ZERO

var _model: Node3D
var _pivot: Node3D
var _rig: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Dictionary = {}
var _coat: StandardMaterial3D
var _coat_dark: StandardMaterial3D
var _dark: StandardMaterial3D
var _hoof: StandardMaterial3D
var _leather: StandardMaterial3D
var _cloth: StandardMaterial3D
var _linen: StandardMaterial3D
var _metal: StandardMaterial3D
var _gold: StandardMaterial3D
var _sock: StandardMaterial3D
var _eye: StandardMaterial3D

var _blood: RefCounted
var _splats: Array[MeshInstance3D] = []
var _splat_cursor := 0
var _splat_material: StandardMaterial3D
var _splat_mesh: SphereMesh
var _ear_left: Node3D
var _ear_right: Node3D
var _lid_left: Node3D
var _lid_right: Node3D
var _idle_clock := 0.0
var _blink_age := 0.0
var _blink_timer := 3.4
var _blink_index := 0
var _ear_age := 0.0
var _ear_timer := 5.2
var _ear_index := 0
var _ear_side := 1
var _lids_visible := false
var _yaw := 0.0
var _phase := 0.0
var _air_time := 0.0
var _was_airborne := false
var _land_absorb := 0.0
var _flinch := 0.0
var _built := false
var _jump_serial := 0
var _last_speed := 0.0
var _pace := 0.0
var _blade_tip := Vector3.ZERO
var _blade_tip_valid := false
var _next_melee_hit_ms := 0

func setup(at: Vector3, yaw: float) -> bool:
	if _built:
		return false
	name = "CastleHorse"
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	up_direction = Vector3.UP
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	max_slides = 8
	_yaw = yaw
	global_position = at
	rotation.y = _yaw
	_build_collision()
	_build_model()
	_build_blood_splats()
	_blood = BloodFx.new()
	if is_instance_valid(get_parent()):
		_blood.configure(get_parent())
	_built = true
	return true

## A small recycled pool of flat stains parented to the barrel: they move with the
## horse and stay after the hit, unlike a one-frame particle burst.
func _build_blood_splats() -> void:
	_splat_material = _material(Color(0.34, 0.025, 0.035), 0.9)
	_splat_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_splat_material.albedo_color.a = 0.92
	_splat_mesh = SphereMesh.new()
	_splat_mesh.radius = 1.0
	_splat_mesh.height = 2.0
	_splat_mesh.radial_segments = 8
	_splat_mesh.rings = 4
	for index: int in 10:
		var splat := MeshInstance3D.new()
		splat.name = "BloodSplat%d" % index
		splat.mesh = _splat_mesh
		splat.material_override = _splat_material
		splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		splat.visible = false
		_rig.add_child(splat)
		_splats.append(splat)

func _spawn_splat(point: Vector3, normal: Vector3) -> void:
	if _splats.is_empty() or not is_instance_valid(_rig):
		return
	var direction := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var local_point: Vector3 = _rig.global_transform.affine_inverse() * (point + direction * 0.03)
	var local_normal: Vector3 = (_rig.global_transform.basis.inverse() * direction).normalized()
	var tangent := local_normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = local_normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(local_normal).normalized()
	var size := 0.090 + float(_splat_cursor % 4) * 0.022
	var splat: MeshInstance3D = _splats[_splat_cursor % _splats.size()]
	_splat_cursor += 1
	splat.transform = Transform3D(Basis(tangent * size, local_normal * 0.020, bitangent * size), local_point)
	splat.visible = true

func _build_collision() -> void:
	# Barrel: the part that must not pass through a wall.
	var body := CapsuleShape3D.new()
	body.radius = BODY_RADIUS
	body.height = BODY_LENGTH
	var body_shape := CollisionShape3D.new()
	body_shape.name = "HorseBarrel"
	body_shape.shape = body
	body_shape.rotation_degrees.x = 90.0
	body_shape.position = Vector3(0.0, BODY_CENTRE_Y, 0.0)
	add_child(body_shape)
	# Legs: the part that stands on the ground and carries the horse over steps.
	var feet := CapsuleShape3D.new()
	feet.radius = FEET_RADIUS
	feet.height = FEET_HEIGHT
	var feet_shape := CollisionShape3D.new()
	feet_shape.name = "HorseFeet"
	feet_shape.shape = feet
	feet_shape.position = Vector3(0.0, FEET_HEIGHT * 0.5, 0.02)
	add_child(feet_shape)
	# No collider on the head/neck: a rider's arrow and blade leave the saddle at the
	# withers, and a head-sized blocker there ate every shot before it cleared the
	# horse. The barrel capsule already stops the body at a wall.

## ---------------------------------------------------------------- presentation
func _material(colour: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	return material

func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3,
		rotation_degrees_value: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation_degrees_value
	instance.scale = scale_value
	parent.add_child(instance)
	return instance

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _sphere(radius: float, height: float = -1.0) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height if height > 0.0 else radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return mesh

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.rings = 6
	return mesh

func _cylinder(top: float, bottom: float, height: float, segments: int = 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh

func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 18
	mesh.ring_segments = 8
	return mesh

## A leather strap between two points in rig space, long axis along the segment.
func _strap(parent: Node3D, from: Vector3, to: Vector3, width: float, material: Material,
		thickness: float = -1.0) -> MeshInstance3D:
	var middle := (from + to) * 0.5
	var length := from.distance_to(to)
	var mesh: Mesh
	if thickness > 0.0:
		mesh = _box(Vector3(width, length, thickness))
	else:
		mesh = _cylinder(width, width, length, 6)
	var node := _part(parent, mesh, material, middle)
	node.look_at_from_position(middle, to, Vector3.UP)
	node.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	return node

func _build_model() -> void:
	_coat = _material(Color(0.33, 0.205, 0.125), 0.78)
	_coat_dark = _material(Color(0.245, 0.145, 0.085), 0.82)
	_dark = _material(Color(0.105, 0.075, 0.055), 0.85)
	_hoof = _material(Color(0.12, 0.11, 0.10), 0.62)
	_leather = _material(Color(0.19, 0.11, 0.06), 0.66)
	_cloth = _material(Color(0.42, 0.09, 0.08), 0.9)
	_linen = _material(Color(0.62, 0.57, 0.45), 0.95)
	_metal = _material(Color(0.55, 0.52, 0.44), 0.38, 0.72)
	_gold = _material(Color(0.68, 0.50, 0.18), 0.35, 0.65)
	_sock = _material(Color(0.80, 0.75, 0.66), 0.85)
	_eye = _material(Color(0.04, 0.03, 0.025), 0.35)

	_model = Node3D.new()
	_model.name = "HorseModel"
	add_child(_model)
	# Everything tips around the barrel, not around the hooves.
	_pivot = Node3D.new()
	_pivot.name = "BarrelPivot"
	_pivot.position = Vector3(0.0, 1.22, 0.0)
	_model.add_child(_pivot)
	_rig = Node3D.new()
	_rig.name = "HorseBody"
	_rig.position = Vector3(0.0, -1.22, 0.0)
	_pivot.add_child(_rig)

	# Barrel: a long capsule plus chest and hindquarters.
	_part(_rig, _capsule(0.30, 1.60), _coat, Vector3(0.0, 1.37, 0.0),
		Vector3(90.0, 0.0, 0.0), Vector3(1.04, 1.0, 1.0))
	_part(_rig, _sphere(0.335), _coat, Vector3(0.0, 1.38, -0.58), Vector3.ZERO, Vector3(0.94, 1.04, 0.92))
	_part(_rig, _sphere(0.365), _coat, Vector3(0.0, 1.35, 0.60), Vector3.ZERO, Vector3(1.0, 1.02, 1.0))
	_part(_rig, _sphere(0.30), _coat_dark, Vector3(0.0, 1.30, -0.30), Vector3.ZERO, Vector3(0.96, 0.98, 2.3))

	# Neck and head.
	_part(_rig, _capsule(0.205, 0.98), _coat, Vector3(0.0, 1.86, -0.84), Vector3(-37.0, 0.0, 0.0))
	_head = Node3D.new()
	_head.name = "HeadPivot"
	_head.position = Vector3(0.0, 2.06, -1.04)
	_rig.add_child(_head)
	_part(_head, _box(Vector3(0.285, 0.32, 0.60)), _coat, Vector3(0.0, 0.13, -0.18), Vector3(-15.0, 0.0, 0.0))
	_part(_head, _box(Vector3(0.225, 0.24, 0.36)), _coat, Vector3(0.0, 0.005, -0.53), Vector3(-24.0, 0.0, 0.0))
	_part(_head, _box(Vector3(0.20, 0.055, 0.30)), _dark, Vector3(0.0, -0.105, -0.58), Vector3(-24.0, 0.0, 0.0))
	_part(_head, _sphere(0.06), _coat, Vector3(0.0, 0.30, -0.10), Vector3.ZERO, Vector3(1.2, 0.9, 1.0))
	# White blaze down the face and soft nostrils.
	_part(_head, _box(Vector3(0.070, 0.235, 0.020)), _sock, Vector3(0.0, 0.16, -0.478), Vector3(-15.0, 0.0, 0.0))
	_part(_head, _sphere(0.020), _dark, Vector3(0.065, -0.055, -0.686), Vector3.ZERO, Vector3(1.0, 0.8, 0.5))
	_part(_head, _sphere(0.020), _dark, Vector3(-0.065, -0.055, -0.686), Vector3.ZERO, Vector3(1.0, 0.8, 0.5))
	_part(_head, _sphere(0.042), _eye, Vector3(0.148, 0.17, -0.38))
	_part(_head, _sphere(0.042), _eye, Vector3(-0.148, 0.17, -0.38))
	for side: float in [-1.0, 1.0]:
		# Bridle: cheek strap, browband, noseband, bit and bit ring.
		_part(_head, _box(Vector3(0.030, 0.29, 0.030)), _leather, Vector3(side * 0.146, 0.09, -0.33))
		_part(_head, _box(Vector3(0.026, 0.026, 0.34)), _leather, Vector3(side * 0.120, 0.0, -0.49), Vector3(-24.0, 0.0, 0.0))
		_part(_head, _cylinder(0.024, 0.024, 0.225, 8), _metal, Vector3(side * 0.11, -0.10, -0.59), Vector3(0.0, 0.0, 90.0))
		_part(_head, _torus(0.030, 0.048), _metal, Vector3(side * 0.135, -0.10, -0.59), Vector3(0.0, 0.0, 90.0))
		_part(_head, _box(Vector3(0.030, 0.024, 0.024)), _gold, Vector3(side * 0.146, 0.22, -0.31))
	_part(_head, _box(Vector3(0.300, 0.034, 0.030)), _leather, Vector3(0.0, 0.285, -0.235), Vector3(-15.0, 0.0, 0.0))
	_part(_head, _box(Vector3(0.290, 0.030, 0.028)), _leather, Vector3(0.0, 0.005, -0.545), Vector3(-24.0, 0.0, 0.0))
	# A leather brow plate with a red gem: the medieval headstall.
	_part(_head, _box(Vector3(0.190, 0.055, 0.022)), _gold, Vector3(0.0, 0.285, -0.265), Vector3(-15.0, 0.0, 0.0))
	_part(_head, _sphere(0.030), _cloth, Vector3(0.0, 0.285, -0.280))
	# Forelock between the ears.
	_part(_head, _box(Vector3(0.075, 0.20, 0.10)), _dark, Vector3(0.0, 0.38, -0.13), Vector3(-30.0, 0.0, 0.0))
	# Mane along the crest.
	for index: int in 6:
		var t: float = float(index) / 5.0
		var crest := Vector3(0.0, 1.70 + t * 0.52, -0.62 - t * 0.36)
		_part(_rig, _box(Vector3(0.07, 0.19 + t * 0.03, 0.15)), _dark, crest, Vector3(-26.0, 0.0, 0.0))
	_part(_head, _box(Vector3(0.07, 0.18, 0.13)), _dark, Vector3(0.0, 0.29, -0.13), Vector3(-24.0, 0.0, 0.0))

	# Legs. Each is a real pivot at the joint so the gait swings the whole limb.
	_build_leg("fl", Vector3(-0.235, 1.16, -0.56), true)
	_build_leg("fr", Vector3(0.235, 1.16, -0.56), false)
	_build_leg("rl", Vector3(-0.255, 1.18, 0.60), false)
	_build_leg("rr", Vector3(0.255, 1.18, 0.60), true)

	# Tail: a soft chain that sways.
	_tail = Node3D.new()
	_tail.name = "TailPivot"
	_tail.position = Vector3(0.0, 1.52, 0.94)
	_rig.add_child(_tail)
	for index: int in 4:
		_part(_tail, _capsule(0.082 - float(index) * 0.012, 0.36), _dark,
			Vector3(0.0, -0.15 - float(index) * 0.19, 0.08 + float(index) * 0.10),
			Vector3(-16.0 - float(index) * 7.0, 0.0, 0.0))

	# Saddle, blanket, stirrups and reins.
	_part(_rig, _box(Vector3(0.80, 0.05, 0.96)), _cloth, Vector3(0.0, 1.685, 0.02))
	_part(_rig, _box(Vector3(0.56, 0.10, 0.56)), _leather, Vector3(0.0, 1.775, 0.02))
	_part(_rig, _box(Vector3(0.48, 0.17, 0.10)), _leather, Vector3(0.0, 1.845, 0.28), Vector3(-10.0, 0.0, 0.0))
	_part(_rig, _box(Vector3(0.40, 0.13, 0.09)), _leather, Vector3(0.0, 1.835, -0.23), Vector3(9.0, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		_part(_rig, _box(Vector3(0.040, 0.16, 0.050)), _leather, Vector3(side * 0.375, 1.755, 0.02))
		_part(_rig, _box(Vector3(0.105, 0.030, 0.135)), _metal, Vector3(side * 0.365, 1.675, 0.01))
		# Reins: bit -> over the crest -> the rider's hands, so they read as a line
		# along the neck instead of cutting straight through it.
		var bit := Vector3(side * 0.11, 1.93, -1.60)
		var crest := Vector3(side * 0.10, 2.36, -0.78)
		var hands := Vector3(side * 0.28, 2.255, -0.34)
		_strap(_rig, bit, crest, 0.017, _leather)
		_strap(_rig, crest, hands, 0.017, _leather)

	# ---------------------------------------------------------------- harness
	# A proper medieval riding harness: girth, breast collar with a ring and
	# martingale, saddlebags, a bedroll, gold trim and brass studs.
	_part(_rig, _torus(0.330, 0.382), _leather, Vector3(0.0, 1.37, 0.03), Vector3(90.0, 0.0, 0.0))
	# Breast collar: four short segments per side follow the chest curve instead of
	# one straight strap whose outer end hovered in front of the shoulder.
	var collar_middle := Vector3(0.0, 1.28, -0.92)
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.255, 1.60, -0.58)
		var upper := Vector3(side * 0.240, 1.52, -0.74)
		var lower := Vector3(side * 0.160, 1.42, -0.86)
		_strap(_rig, Vector3(side * 0.34, 1.48, -0.34), shoulder, 0.028, _leather, 0.045)
		_strap(_rig, shoulder, upper, 0.032, _leather, 0.052)
		_strap(_rig, upper, lower, 0.032, _leather, 0.052)
		_strap(_rig, lower, collar_middle, 0.030, _leather, 0.050)
		for point: Vector3 in [shoulder, upper, lower]:
			_part(_rig, _sphere(0.023), _gold, point)
	_part(_rig, _torus(0.048, 0.072), _metal, collar_middle, Vector3(90.0, 0.0, 0.0))
	# Martingale from the collar ring back under the girth.
	_strap(_rig, collar_middle, Vector3(0.0, 1.52, -0.18), 0.024, _leather, 0.040)
	_strap(_rig, Vector3(0.0, 1.52, -0.18), Vector3(0.0, 1.40, 0.02), 0.022, _leather, 0.038)
	# Crupper strap from the cantle round the tail root.
	_strap(_rig, Vector3(0.0, 1.84, 0.30), Vector3(0.0, 1.56, 0.90), 0.026, _leather, 0.042)
	# Short caparison flaps with gold borders and a round emblem: unmistakably a
	# harnessed warhorse, and still clear of the rider's legs.
	for side: float in [-1.0, 1.0]:
		_part(_rig, _box(Vector3(0.035, 0.40, 0.52)), _cloth, Vector3(side * 0.335, 1.46, 0.20))
		_part(_rig, _box(Vector3(0.045, 0.022, 0.52)), _gold, Vector3(side * 0.345, 1.27, 0.20))
		_part(_rig, _sphere(0.060), _gold, Vector3(side * 0.360, 1.50, 0.20), Vector3.ZERO, Vector3(0.35, 1.0, 1.0))
		_part(_rig, _sphere(0.028), _cloth, Vector3(side * 0.372, 1.50, 0.20), Vector3.ZERO, Vector3(0.35, 1.0, 1.0))
	# Saddlebags behind the cantle, one on each flank.
	for side: float in [-1.0, 1.0]:
		_part(_rig, _box(Vector3(0.26, 0.30, 0.20)), _leather, Vector3(side * 0.40, 1.52, 0.40), Vector3(0.0, 0.0, side * 6.0))
		_part(_rig, _box(Vector3(0.28, 0.10, 0.22)), _coat_dark, Vector3(side * 0.40, 1.66, 0.40), Vector3(0.0, 0.0, side * 6.0))
		_part(_rig, _box(Vector3(0.045, 0.05, 0.025)), _gold, Vector3(side * 0.40, 1.60, 0.505))
	# A rolled bedroll across the back of the saddle.
	_part(_rig, _cylinder(0.095, 0.095, 0.66, 12), _linen, Vector3(0.0, 1.80, 0.50), Vector3(0.0, 0.0, 90.0))
	for side: float in [-1.0, 1.0]:
		_part(_rig, _torus(0.100, 0.120), _leather, Vector3(side * 0.21, 1.80, 0.50), Vector3(0.0, 0.0, 90.0))
	# Gold border on the saddle blanket.
	for side: float in [-1.0, 1.0]:
		_part(_rig, _box(Vector3(0.80, 0.012, 0.020)), _gold, Vector3(0.0, 1.713, side * 0.47))
		_part(_rig, _box(Vector3(0.020, 0.012, 0.96)), _gold, Vector3(side * 0.40, 1.713, 0.02))
	# Fewer nodes, identical pixels: static parts of one material are baked into one
	# mesh. Only the animated pivots (four legs, head, tail) stay separate.
	var static_skip: Array[Node] = [_head, _tail]
	for leg: Node3D in _legs.values():
		static_skip.append(leg)
	_merge_static_parts(_rig, static_skip)
	_merge_static_parts(_head, [])
	_merge_static_parts(_tail, [])
	for leg: Node3D in _legs.values():
		_merge_static_parts(leg, [])
	# These four stay separate because they move: the ears flick, the lids blink.
	_build_ears()
	_build_eyelids()

## Ears on their own pivots so an idle flick costs one rotation, not a rebuild.
func _build_ears() -> void:
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "EarL" if side < 0.0 else "EarR"
		pivot.position = Vector3(side * 0.10, 0.40, 0.02)
		pivot.rotation_degrees = Vector3(-14.0, 0.0, side * 11.0)
		_head.add_child(pivot)
		_part(pivot, _cylinder(0.0, 0.058, 0.21, 8), _coat, Vector3.ZERO)
		if side < 0.0:
			_ear_left = pivot
		else:
			_ear_right = pivot

## A thin coat-coloured lid over each eye sphere: hidden at rest, stretched to a
## line for ~0.16 s on blink. No skeleton and no per-blink material allocation.
func _build_eyelids() -> void:
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "EyelidL" if side < 0.0 else "EyelidR"
		pivot.position = Vector3(side * 0.148, 0.17, -0.392)
		pivot.visible = false
		_head.add_child(pivot)
		var lid := _part(pivot, _sphere(0.050), _coat, Vector3.ZERO)
		lid.scale = Vector3(1.10, 1.0, 0.55)
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if side < 0.0:
			_lid_left = pivot
		else:
			_lid_right = pivot

## Bake every MeshInstance3D child of the same material into one surface. The
## transforms, meshes and materials are unchanged, so the picture is identical and
## the draw-call/node count drops sharply.
func _merge_static_parts(container: Node3D, keep: Array) -> void:
	var groups: Dictionary = {}
	for child: Node in container.get_children():
		if not child is MeshInstance3D or keep.has(child):
			continue
		var instance: MeshInstance3D = child as MeshInstance3D
		if instance.mesh == null:
			continue
		var material: Material = instance.material_override
		if not groups.has(material):
			groups[material] = []
		(groups[material] as Array).append(instance)
	for material: Variant in groups:
		var parts: Array = groups[material]
		if parts.size() < 2:
			continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in parts:
			for surface: int in part.mesh.get_surface_count():
				tool.append_from(part.mesh, surface, part.transform)
		var merged: ArrayMesh = tool.commit()
		if merged == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = "Merged_" + str(container.name)
		instance.mesh = merged
		instance.material_override = material
		container.add_child(instance)
		for part: MeshInstance3D in parts:
			part.free()

func _build_leg(key: String, pivot_at: Vector3, sock: bool = false) -> void:
	var pivot := Node3D.new()
	pivot.name = "Leg_" + key
	pivot.position = pivot_at
	_rig.add_child(pivot)
	_part(pivot, _capsule(0.10, 0.58), _coat, Vector3(0.0, -0.28, 0.0))
	_part(pivot, _cylinder(0.072, 0.060, 0.50, 10), _sock if sock else _coat, Vector3(0.0, -0.74, 0.0))
	_part(pivot, _sphere(0.074), _coat if not sock else _sock, Vector3(0.0, -0.52, 0.0))
	_part(pivot, _box(Vector3(0.128, 0.10, 0.168)), _hoof, Vector3(0.0, -1.11, -0.012))
	_legs[key] = pivot

## ---------------------------------------------------------------- physics
func _input_allowed() -> bool:
	if not is_instance_valid(rider):
		return false
	if not bool(rider.get("_free_mouse_look")):
		return false
	if DisplayServer.get_name() != "headless":
		var window := get_window()
		if not is_instance_valid(window) or not window.visible or window.mode == Window.MODE_MINIMIZED:
			return false
	return true

func _drive() -> Vector3:
	if not _input_allowed():
		return Vector3.ZERO
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return Vector3.ZERO
	if not InputMap.has_action(&"preview_move_forward"):
		return Vector3.ZERO
	var axes: Vector2 = Input.get_vector(&"preview_move_left", &"preview_move_right",
		&"preview_move_forward", &"preview_move_back")
	if axes.is_zero_approx():
		return Vector3.ZERO
	var camera_yaw := float(rider.get("_camera_yaw"))
	return (Basis(Vector3.UP, camera_yaw) * Vector3(axes.x, 0.0, axes.y)).limit_length(1.0)

func _gallop_pressed() -> bool:
	return _input_allowed() and InputMap.has_action(&"preview_run") and Input.is_action_pressed(&"preview_run")

func _jump_pressed() -> bool:
	return _input_allowed() and InputMap.has_action(&"preview_jump") and Input.is_action_just_pressed(&"preview_jump")

func _physics_process(delta: float) -> void:
	if not _built:
		return
	if dead:
		if _blood != null:
			_blood.update(delta)
		return
	var drive := _drive()
	var target_speed := GALLOP_SPEED if _gallop_pressed() else TROT_SPEED
	var target := drive * target_speed
	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	if drive.is_zero_approx():
		acceleration = BRAKE if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if is_instance_valid(rider) and is_on_floor() and _jump_pressed():
		velocity.y = JUMP_SPEED
		_jump_serial += 1
		print("DSH_HORSE_JUMP serial=", _jump_serial, " at=", global_position)
	if not is_on_floor():
		velocity.y -= FALL_GRAVITY * delta
		_air_time += delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
		_air_time = 0.0
	var before := global_position
	move_and_slide()
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
	if is_instance_valid(rider) and horizontal > 0.35:
		# Curve the body into the direction it is actually travelling.
		var wanted := atan2(-velocity.x, -velocity.z)
		_yaw = lerp_angle(_yaw, wanted, minf(1.0, delta * TURN_RATE))
		rotation.y = _yaw
	_last_speed = horizontal
	_pace = clampf(horizontal / GALLOP_SPEED, 0.0, 1.0)
	_check_blade_hit()
	_animate(delta)
	if _blood != null:
		_blood.update(delta)
	if is_instance_valid(rider):
		_seat_rider(delta)
	# Safety: a body that somehow leaves the world falls back onto the castle ground.
	if global_position.y < -40.0:
		global_position = Vector3(global_position.x, 0.2, global_position.z)
		velocity = Vector3.ZERO
	if not before.is_finite():
		global_position = Vector3.ZERO

## ---------------------------------------------------------------- damage
## Every hit is accepted here, whether it came from the rider's blade, an arrow or
## anything else. At zero the horse is retired and a real rigid-body corpse takes
## over, so it falls and settles on the ground instead of hanging in the air.
func take_hit(amount: float, point: Vector3, direction: Vector3, kind: String = "blade") -> void:
	if dead or not is_finite(amount) or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	hits_taken += 1
	last_hit_kind = kind
	last_hit_at = point if point.is_finite() else global_position
	_flinch = minf(0.32, _flinch + 0.14)
	var normal := -direction if direction.length_squared() > 0.0001 else Vector3.UP
	var burst_at := last_hit_at + normal.normalized() * 0.18
	if _blood != null:
		_blood.burst(burst_at, normal, amount >= 14.0, _ground_below(burst_at))
	# Three overlapping stains per wound; the recycled pool keeps them cheap.
	_spawn_splat(last_hit_at, normal)
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(normal).normalized()
	_spawn_splat(last_hit_at + tangent * 0.11, normal)
	_spawn_splat(last_hit_at + bitangent * 0.08, normal)
	print("DSH_HORSE_HIT kind=", kind, " amount=", snappedf(amount, 0.1), " hp=", hp, " at=", last_hit_at)
	if hp <= 0.0:
		_die(direction)

func take_arrow_hit(point: Vector3, speed: float, direction: Vector3, _normal: Vector3) -> void:
	var speed_value := clampf(speed, 0.0, 90.0) if is_finite(speed) else 0.0
	take_hit(clampf(ARROW_BASE_DAMAGE + speed_value * ARROW_SPEED_DAMAGE, 10.0, 38.0),
		point, direction, "arrow")

func _ground_below(point: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return point.y - 1.2
	var ray := PhysicsRayQueryParameters3D.new()
	ray.from = Vector3(point.x, point.y + 2.0, point.z)
	ray.to = Vector3(point.x, point.y - 8.0, point.z)
	ray.collision_mask = 1
	ray.exclude = [get_rid()]
	if is_instance_valid(corpse):
		ray.exclude.append(corpse.get_rid())
	var hit: Dictionary = world.direct_space_state.intersect_ray(ray)
	return float(hit.position.y) if not hit.is_empty() else point.y - 1.2

## The rider's blade is a real world segment; compare it with the barrel and the
## neck. A hit needs actual blade motion, so a sword resting against the horse does
## not tick damage every frame.
func _check_blade_hit() -> void:
	if dead or not is_instance_valid(damage_owner):
		return
	var sword: Node = damage_owner.get("_sword_host") as Node
	if not is_instance_valid(sword):
		_blade_tip_valid = false
		return
	var segment: Array = sword.call("blade_segment31")
	if segment.size() != 2:
		_blade_tip_valid = false
		return
	var blade_a: Vector3 = segment[0]
	var blade_b: Vector3 = segment[1]
	if not blade_a.is_finite() or not blade_b.is_finite():
		return
	var tip_moved := blade_b.distance_to(_blade_tip) if _blade_tip_valid else 0.0
	_blade_tip = blade_b
	_blade_tip_valid = true
	var now := Time.get_ticks_msec()
	if tip_moved < 0.05 or now < _next_melee_hit_ms:
		return
	var body_a := to_global(Vector3(0.0, 1.36, -0.62))
	var body_b := to_global(Vector3(0.0, 1.34, 0.62))
	var neck_a := to_global(Vector3(0.0, 1.66, -0.55))
	var neck_b := to_global(Vector3(0.0, 2.10, -1.15))
	var best := _closest_segment_points(blade_a, blade_b, neck_a, neck_b)
	var radius := 0.36
	# Mounted, the barrel under the rider is never a target: only the neck/head is
	# reachable and that avoids the rider's own body registering a hit on the back.
	if not is_instance_valid(rider):
		var body := _closest_segment_points(blade_a, blade_b, body_a, body_b)
		if float(body[2]) < float(best[2]):
			best = body
			radius = BODY_RADIUS + 0.10
	if float(best[2]) > radius:
		return
	_next_melee_hit_ms = now + MELEE_COOLDOWN_MS
	var contact: Vector3 = ((best[0] as Vector3) + (best[1] as Vector3)) * 0.5
	take_hit(MELEE_DAMAGE, contact, (contact - blade_a).normalized(), "blade")

## Returns [point_on_a, point_on_b, distance].
func _closest_segment_points(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> Array:
	var da := a1 - a0
	var db := b1 - b0
	var r := a0 - b0
	var a := da.dot(da)
	var e := db.dot(db)
	var f := db.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 0.000001 and e <= 0.000001:
		pass
	elif a <= 0.000001:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := da.dot(r)
		if e <= 0.000001:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := da.dot(db)
			var denom := a * e - b * b
			s = clampf((b * f - c * e) / denom, 0.0, 1.0) if absf(denom) > 0.000001 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	var pa := a0 + da * s
	var pb := b0 + db * t
	return [pa, pb, pa.distance_to(pb)]

func _die(direction: Vector3) -> void:
	if dead:
		return
	dead = true
	rider = null
	_flinch = 0.0
	_exit_air_pose()
	_make_corpse(direction)
	if _blood != null:
		_blood.burst(seat_world(), Vector3.UP, true, _ground_below(seat_world()))
	print("DSH_HORSE_DEAD at=", global_position, " hits=", hits_taken, " killer=", last_hit_kind)

func _exit_air_pose() -> void:
	velocity = Vector3.ZERO
	if is_instance_valid(_lid_left): _lid_left.visible = false
	if is_instance_valid(_lid_right): _lid_right.visible = false
	_lids_visible = false
	for key: String in ["fl", "fr", "rl", "rr"]:
		var leg: Node3D = _legs.get(key) as Node3D
		if is_instance_valid(leg):
			leg.rotation.x = -0.35 if key.begins_with("f") else 0.30
	if is_instance_valid(_head):
		_head.rotation.x = 0.25
	if is_instance_valid(_tail):
		_tail.rotation.x = 0.10

func _make_corpse(direction: Vector3) -> void:
	var parent: Node = get_parent()
	if not is_instance_valid(parent):
		return
	var rb := RigidBody3D.new()
	rb.name = "HorseCorpse"
	rb.mass = 420.0
	rb.collision_layer = 1
	rb.collision_mask = 1
	rb.continuous_cd = true
	rb.linear_damp = 0.6
	rb.angular_damp = 1.2
	rb.can_sleep = true
	parent.add_child(rb)
	rb.global_transform = Transform3D(global_transform.basis, global_position + Vector3.UP * 0.06)
	# Barrel, head and legs: the corpse must rest on the ground, never hang over it.
	var barrel_shape := CapsuleShape3D.new()
	barrel_shape.radius = 0.33
	barrel_shape.height = 1.90
	var barrel := CollisionShape3D.new()
	barrel.shape = barrel_shape
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 1.30, 0.0)
	rb.add_child(barrel)
	var head_shape := SphereShape3D.new()
	head_shape.radius = 0.28
	var head := CollisionShape3D.new()
	head.shape = head_shape
	head.position = Vector3(0.0, 2.02, -1.12)
	rb.add_child(head)
	var legs_shape := CapsuleShape3D.new()
	legs_shape.radius = 0.30
	legs_shape.height = 0.90
	var legs := CollisionShape3D.new()
	legs.shape = legs_shape
	legs.position = Vector3(0.0, 0.45, 0.02)
	rb.add_child(legs)
	if is_instance_valid(_model):
		_model.reparent(rb, true)
	# The living body stops existing for physics, but remains the stable owner the
	# mount host and its telemetry still point at.
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	var forward := global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	var side := 1.0
	if direction.length_squared() > 0.0001:
		var lateral := direction.dot(right)
		if absf(lateral) > 0.15:
			side = 1.0 if lateral >= 0.0 else -1.0
	rb.rotate_object_local(Vector3.BACK, 0.20 * side)
	rb.angular_velocity = forward * (2.3 * side) + Vector3.UP * 0.35
	rb.linear_velocity = Vector3.UP * 0.30 + direction.limit_length(2.0) * 0.65
	corpse = rb
	_spawn_blood_pool(parent, right * side)
	print("DSH_HORSE_CORPSE at=", rb.global_position, " side=", side)

func _spawn_blood_pool(parent: Node, away: Vector3) -> void:
	var pool := MeshInstance3D.new()
	pool.name = "HorseBloodPool"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.60
	disc.bottom_radius = 1.60
	disc.height = 0.012
	disc.radial_segments = 22
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.028, 0.038, 0.92)
	material.roughness = 1.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.mesh = disc
	pool.material_override = material
	parent.add_child(pool)
	var at := global_position + away * 0.55
	pool.global_position = Vector3(at.x, _ground_below(at) + 0.012, at.z)
	pool.scale = Vector3(0.22, 1.0, 0.22)
	pool.create_tween().tween_property(pool, "scale", Vector3(1.0, 1.0, 1.0), 1.5)\
		.set_trans(Tween.TRANS_SINE)

## ---------------------------------------------------------------- rider socket
func seat_world() -> Vector3:
	return to_global(Vector3(0.0, SEAT_Y, SEAT_Z))

func _seat_rider(_delta: float) -> void:
	var seat := seat_world()
	var origin := seat - Vector3.UP * rider_hip
	rider.global_transform = Transform3D(Basis(Vector3.UP, _yaw), origin)
	rider._heading = _yaw
	# The visual's own 180-degree correction is set once at mount: a weapon that
	# owns the facing (spear aim) is allowed to turn it without being reset here.
	rider.velocity = Vector3.ZERO
	# The player composes the seated base pose and every weapon decorator on top of
	# it in its own physics tick; the horse only publishes its gait.
	rider.set_mount_state(_pace, _phase, not is_on_floor())
	var pivot: Node3D = rider.get("_yaw_pivot") as Node3D
	if is_instance_valid(pivot):
		pivot.position.y = rider_hip + 0.88
	rider._update_camera_rotation()

## ---------------------------------------------------------------- animation
func _rotate_leg(key: String, angle: float) -> void:
	var leg: Node3D = _legs.get(key) as Node3D
	if is_instance_valid(leg):
		leg.rotation.x = angle

func _animate(delta: float) -> void:
	if not is_instance_valid(_pivot):
		return
	_idle_clock += delta
	var airborne := not is_on_floor()
	if not airborne and _was_airborne:
		_land_absorb = 0.32
	_was_airborne = airborne
	_land_absorb = maxf(0.0, _land_absorb - delta)
	_flinch = maxf(0.0, _flinch - delta)
	var moving := _last_speed > 0.12
	if airborne:
		# Rise: front legs tucked, hind legs trailing. Fall: front legs reach for
		# the landing and the hind legs come under the body. The barrel follows the
		# arc with a nose-up / nose-down pitch.
		_phase = fposmod(_phase + delta * 4.0, TAU)
		var tuck := clampf(_air_time * 6.0, 0.0, 1.0)
		var fall := clampf(-velocity.y / 7.0, 0.0, 1.0)
		var rise := clampf(velocity.y / JUMP_SPEED, 0.0, 1.0)
		var front := lerpf(-1.10, 0.45, fall)
		var rear := lerpf(0.95, -0.55, fall)
		_rotate_leg("fl", lerpf(_rotate_leg_value("fl"), front, tuck))
		_rotate_leg("fr", lerpf(_rotate_leg_value("fr"), front * 0.90, tuck))
		_rotate_leg("rl", lerpf(_rotate_leg_value("rl"), rear, tuck))
		_rotate_leg("rr", lerpf(_rotate_leg_value("rr"), rear * 0.92, tuck))
		_pivot.position.y = lerpf(_pivot.position.y, 1.22 + 0.035 * rise, minf(1.0, delta * 9.0))
		var pitch := 0.26 * rise - 0.22 * fall
		_pivot.rotation.x = lerpf(_pivot.rotation.x, pitch, minf(1.0, delta * 9.0))
		_pivot.rotation.z = lerpf(_pivot.rotation.z, 0.0, minf(1.0, delta * 8.0))
	elif _land_absorb > 0.0:
		# Landing absorption: the knees give, the barrel drops and recovers.
		var progress := 1.0 - _land_absorb / 0.32
		var absorb := sin(PI * clampf(progress, 0.0, 1.0))
		_phase = fposmod(_phase + delta * 1.4, TAU)
		for key: String in _legs:
			var bend := (0.30 if key.begins_with("f") else 0.36) * absorb
			_rotate_leg(key, lerpf(_rotate_leg_value(key), bend, minf(1.0, delta * 14.0)))
		_pivot.position.y = 1.22 - 0.11 * absorb
		_pivot.rotation.x = lerpf(_pivot.rotation.x, 0.05 * absorb, minf(1.0, delta * 12.0))
		_pivot.rotation.z = lerpf(_pivot.rotation.z, 0.0, minf(1.0, delta * 10.0))
	elif moving:
		_phase = fposmod(_phase + delta * (3.4 + _last_speed * 1.55), TAU)
		var wave := sin(_phase)
		var amplitude := 0.16 + _pace * 0.62
		_rotate_leg("fl", wave * amplitude)
		_rotate_leg("rr", wave * amplitude)
		_rotate_leg("fr", -wave * amplitude)
		_rotate_leg("rl", -wave * amplitude)
		_pivot.position.y = 1.22 + absf(sin(_phase)) * 0.032 * _pace
		_pivot.rotation.x = lerpf(_pivot.rotation.x, -0.035 * _pace, minf(1.0, delta * 6.0))
		_pivot.rotation.z = lerpf(_pivot.rotation.z, 0.0, minf(1.0, delta * 8.0))
	else:
		_phase = fposmod(_phase + delta * 1.7, TAU)
		for key: String in _legs:
			_rotate_leg(key, lerpf(_rotate_leg_value(key), 0.0, minf(1.0, delta * 5.0)))
		_pivot.position.y = 1.22 + sin(_phase) * 0.012
		_pivot.rotation.x = lerpf(_pivot.rotation.x, 0.0, minf(1.0, delta * 4.0))
		# A slow weight shift from one foreleg to the other, barely a degree.
		_pivot.rotation.z = lerpf(_pivot.rotation.z, sin(_idle_clock * 0.52) * 0.007, minf(1.0, delta * 2.0))
	if is_instance_valid(_head):
		var nod := sin(_phase * 0.9) * (0.03 + _pace * 0.05)
		_head.rotation.x = lerpf(_head.rotation.x, nod - 0.04 * _pace, minf(1.0, delta * 6.0))
		var look := 0.0 if (moving or airborne) else sin(_idle_clock * 0.34) * 0.085
		_head.rotation.y = lerpf(_head.rotation.y, look, minf(1.0, delta * 2.2))
		if _flinch > 0.0:
			_head.rotation.x -= 0.10 * clampf(_flinch / 0.32, 0.0, 1.0)
	if is_instance_valid(_tail):
		_tail.rotation.y = sin(_phase * 0.75) * 0.16
		_tail.rotation.x = -0.06 + sin(_phase * 0.45) * 0.04
	if _flinch > 0.0 and is_instance_valid(_pivot):
		_pivot.rotation.z += sin(_flinch * 55.0) * 0.02 * clampf(_flinch / 0.32, 0.0, 1.0)
	_animate_idle_details(delta)
	# Breathing: the barrel widens slightly on the inhale. Scaled on the visual pivot
	# only, so physics, the saddle socket and the rider are untouched.
	var breath_target := Vector3.ONE
	if not airborne and not moving:
		var breath := sin(_idle_clock * 1.55)
		breath_target = Vector3(1.0 + 0.005 * breath, 1.0 + 0.008 * breath, 1.0 + 0.006 * breath)
	_pivot.scale = _pivot.scale.lerp(breath_target, minf(1.0, delta * 3.0))

## Blink and ear-flick clocks. Deterministic intervals, cached nodes, no allocation
## while idle and no work at all while the horse is dead.
func _animate_idle_details(delta: float) -> void:
	_blink_timer -= delta
	if _blink_age > 0.0:
		_blink_age = maxf(0.0, _blink_age - delta)
	if _blink_timer <= 0.0 and not dead:
		_blink_age = 0.16
		_blink_timer = 3.0 + fmod(float(_blink_index) * 1.73, 3.4)
		_blink_index += 1
	var lid := 0.0
	if _blink_age > 0.0:
		var t := 1.0 - _blink_age / 0.16
		lid = sin(PI * clampf(t, 0.0, 1.0))
	var show := lid > 0.02
	if show != _lids_visible:
		_lids_visible = show
		if is_instance_valid(_lid_left): _lid_left.visible = show
		if is_instance_valid(_lid_right): _lid_right.visible = show
	if show:
		var lid_scale := Vector3(1.0, maxf(0.04, lid), 0.6)
		if is_instance_valid(_lid_left): _lid_left.scale = lid_scale
		if is_instance_valid(_lid_right): _lid_right.scale = lid_scale
	_ear_timer -= delta
	if _ear_age > 0.0:
		_ear_age = maxf(0.0, _ear_age - delta)
	if _ear_timer <= 0.0 and not dead:
		_ear_age = 0.36
		_ear_timer = 4.4 + fmod(float(_ear_index) * 2.17, 5.2)
		_ear_side = _ear_index % 2
		_ear_index += 1
	var flick := 0.0
	if _ear_age > 0.0:
		flick = sin(PI * clampf(1.0 - _ear_age / 0.36, 0.0, 1.0)) * 0.38
	var left_active := flick > 0.0 and _ear_side == 0
	var right_active := flick > 0.0 and _ear_side == 1
	if is_instance_valid(_ear_left):
		var target := Vector3(-14.0, 0.0, -11.0)
		if left_active: target = Vector3(-14.0 - flick * 28.0, 0.0, -11.0 - flick * 18.0)
		_ear_left.rotation_degrees = _ear_left.rotation_degrees.lerp(target, minf(1.0, delta * 9.0))
	if is_instance_valid(_ear_right):
		var target := Vector3(-14.0, 0.0, 11.0)
		if right_active: target = Vector3(-14.0 - flick * 28.0, 0.0, 11.0 + flick * 18.0)
		_ear_right.rotation_degrees = _ear_right.rotation_degrees.lerp(target, minf(1.0, delta * 9.0))

func _rotate_leg_value(key: String) -> float:
	var leg: Node3D = _legs.get(key) as Node3D
	return leg.rotation.x if is_instance_valid(leg) else 0.0

## ---------------------------------------------------------------- evidence
func has_rider() -> bool:
	return is_instance_valid(rider)

## QA hooks: make the next idle detail immediate so a screenshot can catch it.
func debug_blink() -> void:
	_blink_age = 0.16

func debug_ear_flick(side: int = 0) -> void:
	_ear_age = 0.36
	_ear_side = side

func snapshot() -> Dictionary:
	return {"position": global_position, "yaw": rotation.y, "speed_mps": _last_speed,
		"grounded": is_on_floor(), "air_time": _air_time, "jumps": _jump_serial,
		"mounted": is_instance_valid(rider), "seat": seat_world(),
		"collision_layer": collision_layer, "collision_mask": collision_mask,
		"hp": hp, "max_hp": MAX_HP, "dead": dead, "hits": hits_taken,
		"last_hit_kind": last_hit_kind, "last_hit_at": last_hit_at,
		"corpse": is_instance_valid(corpse),
		"corpse_position": corpse.global_position if is_instance_valid(corpse) else Vector3.ZERO,
		"corpse_sleeping": corpse.sleeping if is_instance_valid(corpse) else false,
		"blood_active": _blood.active if _blood != null else 0,
		"blinks": _blink_index, "ears": _ear_index, "blink_age": _blink_age, "ear_age": _ear_age,
		"breath_scale": _pivot.scale.x if is_instance_valid(_pivot) else 1.0,
		"below_y": global_position.y < -5.0}
