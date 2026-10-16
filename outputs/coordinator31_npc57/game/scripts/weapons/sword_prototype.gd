extends Node3D
## DSH_SWORD_PROTO (prototype only): mouse-driven heavy sword play inspired by
## Half Sword. Hold LMB and move the mouse to steer the blade (left/right/up/down
## and diagonals); the camera does NOT turn while the blade is steered. The blade
## follows the commanded direction with limited angular speed and acceleration,
## is swept along its whole length against the world, stops/deflects on impact,
## and returns to rest when LMB is released.
##
## The sword is held by an actually moving right arm: this host solves a two-bone
## IK for upperarm_r -> forearm_r -> hand_r around the existing skeleton socket,
## so the arm follows the commanded blade direction instead of hanging still.
## No source pose, animation, NPC, city or navigation owner is rewritten.
##
## Scope: one sword, one training dummy, one pole, one control scheme. No network,
## no combat AI, no dismemberment, no fully physical body.

const BLADE_LENGTH := 1.15
const SWEEP_SEGMENTS := 5
const MOUSE_TO_HAND := 0.0030
const MAX_OMEGA := 6.2          # rad/s, heavy weapon steering limit
const MAX_ALPHA := 20.0         # rad/s^2, acceleration limit
const FOLLOW_RATE := 7.5        # hand spring rate toward the commanded point
const REST_RETURN_RATE := 2.6   # blade return when LMB is released
## Body weight: the swing is carried by hips, spine and chest, not only by the
## arm. The torso leans against the blade's angular acceleration and takes the
## recoil of every contact.
const BODY_FOLLOW_RATE := 4.5   # how fast the body follows the load
const BODY_LEAN_GAIN := 0.055   # radians of lean per rad/s of blade rotation
const BODY_LEAN_LIMIT := 0.20
const BODY_PUSH_GAIN := 0.55    # metres of recoil per metre/second of contact
const BODY_PUSH_LIMIT := 0.30
const BODY_PUSH_DECAY := 3.2
## The torso only helps the swing: a small, soft turn plus the lean above. The
## arm is what reaches, and it is clamped in front of the torso, so the blade can
## never end up behind the back.
const BODY_YAW_SHARE := 0.35
const BODY_YAW_LIMIT := 0.50
const DAMAGE_SPEED_MIN := 1.05  # m/s below which a touch deals no damage
const DAMAGE_PER_MPS := 6.5
const DAMAGE_MAX := 26.0
const CONTACT_COOLDOWN_MS := 320
const DUMMY_MAX_HP := 100.0
const DUMMY_CLEAR_RADIUS := 0.75
const POLE_CLEAR_RADIUS := 0.55

var _world: Node3D
var _player: CharacterBody3D
var _rig: Skeleton3D
var _camera: Camera3D

# Right arm chain (names verified on this hero rig).
var _bone_clavicle := -1
var _bone_upper := -1
var _bone_fore := -1
var _bone_hand := -1
var _bone_socket := -1
var _bone_spine := -1
var _bone_chest := -1
var _bone_pelvis := -1
var _bone_head := -1
var _rest_upper := Transform3D.IDENTITY
var _rest_fore := Transform3D.IDENTITY
var _rest_hand := Transform3D.IDENTITY
var _rest_socket := Transform3D.IDENTITY
var _upper_len := 0.0
var _fore_len := 0.0

var _sword: Node3D
var _dummy: StaticBody3D
var _dummy_pivot: Node3D
var _dummy_label: Label3D
var _dummy_hp := DUMMY_MAX_HP
var _dummy_tilt := 0.0
var _dummy_tilt_axis := Vector3.RIGHT
var _dummy_down := false
var _down_until_ms := 0
var _pole: StaticBody3D

var _hand := Vector2.ZERO          # commanded hand offset in camera plane (x right, y up)
var _sword_origin := Vector3.ZERO
var _dir := Vector3.FORWARD
var _omega := Vector3.ZERO
var _block_push := Vector3.ZERO
## Body load: lean (pitch, roll) and recoil carried by hips/spine/chest.
var _body_lean := Vector2.ZERO
var _body_yaw := 0.0
var _body_push := Vector3.ZERO
var _prev_points: PackedVector3Array = PackedVector3Array()
var _held := false
## Wheel-driven thrust: pulls the hand back or drives the point forward.
var _thrust := 0.2
## True only while the prototype sword is the item equipped in the arsenal menu.
var _selected := false
## Button state straight from the events, so the blade also follows input that
## the Input singleton does not mirror (script-driven checks).
var _held_event := false
var _ready := false
var _rest_dir := Vector3.FORWARD
var _last_block_ms := -1000
var _hit_ms: Dictionary = {}
## Colliders the blade was already touching on the previous frame, so a target
## that stays on the edge is not struck over and over.
var _contact_prev: Dictionary = {}
var _hits := 0
var _blocks := 0
var _sweep_rays := 0
var _sweep_hits := 0
var _max_damage := 0.0
var _impact_player: AudioStreamPlayer3D
var _spark: MeshInstance3D
var _spark_left := 0.0
var _hint_layer: CanvasLayer
var _hint: Label

func install(world: Node3D, player: CharacterBody3D) -> Dictionary:
	if _ready or not is_instance_valid(world) or not is_instance_valid(player): return {"ok": false, "reason": "binding"}
	_world = world
	_player = player
	var rig: Skeleton3D = player.get("_pose_skeleton") as Skeleton3D
	if rig == null: return {"ok": false, "reason": "skeleton"}
	_rig = rig
	_camera = player.get_preview_camera()
	if _camera == null: return {"ok": false, "reason": "camera"}
	_bone_clavicle = rig.find_bone("clavicle_r")
	_bone_upper = rig.find_bone("upperarm_r")
	_bone_fore = rig.find_bone("forearm_r")
	_bone_hand = rig.find_bone("hand_r")
	_bone_socket = rig.find_bone("socket_weapon")
	_bone_spine = rig.find_bone("spine_01")
	_bone_chest = rig.find_bone("chest")
	_bone_pelvis = rig.find_bone("pelvis")
	_bone_head = rig.find_bone("head")
	if _bone_upper < 0 or _bone_fore < 0 or _bone_hand < 0:
		return {"ok": false, "reason": "arm_bones"}
	if _bone_socket < 0: _bone_socket = rig.find_bone("socket_hand_r")
	_rest_upper = rig.get_bone_rest(_bone_upper)
	_rest_fore = rig.get_bone_rest(_bone_fore)
	_rest_hand = rig.get_bone_rest(_bone_hand)
	_rest_socket = rig.get_bone_rest(_bone_socket) if _bone_socket >= 0 else Transform3D.IDENTITY
	_upper_len = _rest_fore.origin.length()
	_fore_len = _rest_hand.origin.length()
	if _upper_len <= 0.01 or _fore_len <= 0.01: return {"ok": false, "reason": "arm_lengths"}
	_build_sword()
	_build_impacts()
	_build_hint()
	var placed := _place_targets()
	_rest_dir = _rest_direction()
	_dir = _rest_dir
	_sword_origin = _rig.global_transform * _rig.get_bone_global_pose(_bone_hand).origin
	_ready = true
	set_process_input(true)
	set_physics_process(true)
	return {"ok": true, "socket": rig.get_bone_name(_bone_socket), "upper_len": _upper_len, "fore_len": _fore_len, "dummy": placed.dummy, "pole": placed.pole}

# ---------------------------------------------------------------- construction

func _build_sword() -> void:
	_sword = Node3D.new()
	_sword.name = "PrototypeSword"
	_world.add_child(_sword)
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color(0.72, 0.76, 0.82); steel.metallic = 0.85; steel.roughness = 0.28
	var leather := StandardMaterial3D.new(); leather.albedo_color = Color(0.20, 0.13, 0.09); leather.roughness = 0.85
	var brass := StandardMaterial3D.new(); brass.albedo_color = Color(0.62, 0.47, 0.18); brass.metallic = 0.7; brass.roughness = 0.4
	var blade := BoxMesh.new(); blade.size = Vector3(BLADE_LENGTH, 0.052, 0.013)
	var blade_node := MeshInstance3D.new(); blade_node.mesh = blade; blade_node.material_override = steel
	blade_node.position = Vector3(0.10 + BLADE_LENGTH * 0.5, 0.0, 0.0)
	_sword.add_child(blade_node)
	var tip := BoxMesh.new(); tip.size = Vector3(0.10, 0.052, 0.013)
	var tip_node := MeshInstance3D.new(); tip_node.mesh = tip; tip_node.material_override = steel
	tip_node.position = Vector3(0.10 + BLADE_LENGTH + 0.04, 0.0, 0.0)
	_sword.add_child(tip_node)
	var guard := BoxMesh.new(); guard.size = Vector3(0.030, 0.230, 0.040)
	var guard_node := MeshInstance3D.new(); guard_node.mesh = guard; guard_node.material_override = brass
	guard_node.position = Vector3(0.095, 0.0, 0.0)
	_sword.add_child(guard_node)
	var grip := BoxMesh.new(); grip.size = Vector3(0.170, 0.036, 0.038)
	var grip_node := MeshInstance3D.new(); grip_node.mesh = grip; grip_node.material_override = leather
	grip_node.position = Vector3(-0.005, 0.0, 0.0)
	_sword.add_child(grip_node)
	var pommel := SphereMesh.new(); pommel.radius = 0.034; pommel.height = 0.068
	var pommel_node := MeshInstance3D.new(); pommel_node.mesh = pommel; pommel_node.material_override = brass
	pommel_node.position = Vector3(-0.105, 0.0, 0.0)
	_sword.add_child(pommel_node)

func _build_impacts() -> void:
	_impact_player = AudioStreamPlayer3D.new()
	_impact_player.name = "SwordImpact"
	_impact_player.stream = _impact_stream(0.26, 195.0, 0.55)
	_impact_player.unit_size = 3.0
	_impact_player.max_distance = 24.0
	_world.add_child(_impact_player)
	var spark := BoxMesh.new(); spark.size = Vector3(0.05, 0.05, 0.05)
	_spark = MeshInstance3D.new(); _spark.mesh = spark
	var spark_mat := StandardMaterial3D.new(); spark_mat.albedo_color = Color(1.0, 0.86, 0.55)
	spark_mat.emission_enabled = true; spark_mat.emission = Color(1.0, 0.72, 0.30)
	_spark.material_override = spark_mat
	_spark.visible = false
	_world.add_child(_spark)

func _impact_stream(duration: float, base_hz: float, noise: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 20261016
	for i: int in count:
		var t := float(i) / float(rate)
		var env := exp(-t * 20.0)
		var sample := sin(TAU * base_hz * t) * 0.75 + (rng.randf() * 2.0 - 1.0) * noise
		data.encode_s16(i * 2, int(clampf(sample * env, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func _build_hint() -> void:
	_hint_layer = CanvasLayer.new(); _hint_layer.layer = 30
	_world.add_child(_hint_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 6; style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	_hint = Label.new()
	_hint.text = "ТЕСТОВЫЙ МЕЧ (прототип)\nЛКМ + движение мыши — рубить влево/вправо/вверх/вниз и по диагонали\nКолесо мыши — укол вперёд / оттянуть назад\nОтпустите ЛКМ — меч возвращается; камера при удержании не вращается"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	panel.add_child(_hint)
	_hint_layer.add_child(panel)

# ------------------------------------------------------------ target placement

## The dummy stands on open ground away from the palazzo facade but still inside
## sword reach; the pole goes to the side. Both stay visible in front of the player.
func _place_targets() -> Dictionary:
	var forward := -_camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 1e-6: forward = -_player.global_basis.z
	forward = forward.normalized()
	var base := _player.global_position
	var dummy_dir := _most_open_direction(base, forward)
	var side_left := dummy_dir.rotated(Vector3.UP, 1.15)
	var side_right := dummy_dir.rotated(Vector3.UP, -1.15)
	var pole_dir := side_left if _open_score(base, side_left) >= _open_score(base, side_right) else side_right
	var dummy_at := _pick_along(base, dummy_dir, [1.4, 1.6, 1.2, 1.8], DUMMY_CLEAR_RADIUS)
	var pole_at := _pick_along(base, pole_dir, [1.6, 1.9, 1.3, 2.2], POLE_CLEAR_RADIUS)
	if dummy_at.is_finite() and pole_at.is_finite() and pole_at.distance_to(dummy_at) < 2.0:
		pole_at = _pick_along(base, side_right, [2.6, 2.9, 2.2], POLE_CLEAR_RADIUS)
	if not dummy_at.is_finite(): dummy_at = _grounded(base + dummy_dir * 2.6)
	if not pole_at.is_finite(): pole_at = _grounded(base + pole_dir * 2.4)
	_dummy = _build_dummy(dummy_at)
	_pole = _build_pole(pole_at)
	print("DSH_SWORD_PROTO_PLACEMENT dummy=", dummy_at, " pole=", pole_at, " player=", base, " dir=", dummy_dir)
	return {"dummy": true, "pole": true}

## Picks the most open azimuth around the player, softly preferring the camera
## forward direction, so the targets land on the street and not against a wall.
func _most_open_direction(base: Vector3, forward: Vector3) -> Vector3:
	var best := forward
	var best_score := -1e9
	for i: int in 24:
		var angle := -PI + TAU * float(i) / 24.0
		var dir := forward.rotated(Vector3.UP, angle)
		var score := _open_score(base, dir) - 1.10 * (1.0 - cos(angle))
		if score > best_score:
			best_score = score
			best = dir
	return best

func _open_score(base: Vector3, dir: Vector3) -> float:
	var probe := _grounded(base + dir * 3.0)
	if not probe.is_finite(): return -1.0
	return _clearance(probe + Vector3.UP * 1.0, 3.0)

func _pick_along(base: Vector3, dir: Vector3, distances: Array, clear_radius: float) -> Vector3:
	for distance: float in distances:
		var at := _grounded(base + dir * distance)
		if not at.is_finite(): continue
		if _player.global_position.distance_to(at) < 1.3: continue
		if not _is_clear(at + Vector3.UP * 0.75, clear_radius): continue
		if _clearance(at + Vector3.UP * 1.0, 3.5) < 1.2: continue
		return at
	return Vector3(NAN, NAN, NAN)

func _grounded(at: Vector3) -> Vector3:
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.6, at + Vector3.DOWN * 5.0, 1, [_player.get_rid()])
	query.hit_from_inside = false
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return Vector3(NAN, NAN, NAN)
	var point: Vector3 = hit.position
	if not point.is_finite() or absf(point.y - _player.global_position.y) > 3.0: return Vector3(NAN, NAN, NAN)
	return point

## Free volume check for a candidate spot. The probe volume floats just above
## the ground so the floor itself is never mistaken for an obstacle.
func _is_clear(center: Vector3, radius: float) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new(); shape.radius = radius; shape.height = 1.2
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	var excluded: Array[RID] = [_player.get_rid()]
	query.exclude = excluded
	return space.intersect_shape(query, 1).is_empty()

## Smallest horizontal distance to world geometry around a point (capped).
func _clearance(at: Vector3, cap: float) -> float:
	var space := _player.get_world_3d().direct_space_state
	var smallest := cap
	for i: int in 8:
		var angle := TAU * float(i) / 8.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(at, at + dir * cap, 1, [_player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		smallest = minf(smallest, at.distance_to(hit.position))
	return smallest

func _build_dummy(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SwordTrainingDummy"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("sword_target", true)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.28; capsule.height = 1.30
	shape.shape = capsule; shape.position = Vector3(0.0, 0.78, 0.0)
	body.add_child(shape)
	_dummy_pivot = Node3D.new(); _dummy_pivot.name = "DummyPivot"
	body.add_child(_dummy_pivot)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.48, 0.33, 0.20); wood.roughness = 0.9
	var straw := StandardMaterial3D.new(); straw.albedo_color = Color(0.72, 0.60, 0.32); straw.roughness = 0.95
	var torso := CapsuleMesh.new(); torso.radius = 0.27; torso.height = 1.05
	var torso_node := MeshInstance3D.new(); torso_node.mesh = torso; torso_node.material_override = straw
	torso_node.position = Vector3(0.0, 0.92, 0.0)
	_dummy_pivot.add_child(torso_node)
	var arms := BoxMesh.new(); arms.size = Vector3(1.32, 0.11, 0.11)
	var arms_node := MeshInstance3D.new(); arms_node.mesh = arms; arms_node.material_override = wood
	arms_node.position = Vector3(0.0, 1.22, 0.0)
	_dummy_pivot.add_child(arms_node)
	var head := SphereMesh.new(); head.radius = 0.15; head.height = 0.30
	var head_node := MeshInstance3D.new(); head_node.mesh = head; head_node.material_override = wood
	head_node.position = Vector3(0.0, 1.52, 0.0)
	_dummy_pivot.add_child(head_node)
	var post := CylinderMesh.new(); post.top_radius = 0.09; post.bottom_radius = 0.09; post.height = 1.35
	var post_node := MeshInstance3D.new(); post_node.mesh = post; post_node.material_override = wood
	post_node.position = Vector3(0.0, 0.28, 0.0)
	_dummy_pivot.add_child(post_node)
	var base_plate := CylinderMesh.new(); base_plate.top_radius = 0.42; base_plate.bottom_radius = 0.46; base_plate.height = 0.10
	var base_node := MeshInstance3D.new(); base_node.mesh = base_plate; base_node.material_override = wood
	base_node.position = Vector3(0.0, 0.05, 0.0)
	_dummy_pivot.add_child(base_node)
	_dummy_label = Label3D.new()
	_dummy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dummy_label.font_size = 96
	_dummy_label.pixel_size = 0.0035
	_dummy_label.outline_size = 18
	_dummy_label.modulate = Color(1.0, 0.92, 0.65)
	_dummy_label.position = Vector3(0.0, 1.95, 0.0)
	_dummy_label.text = "Манекен 100"
	_dummy_pivot.add_child(_dummy_label)
	body.position = at
	_world.add_child(body)
	return body

func _build_pole(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SwordTestPole"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("sword_pole", true)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new(); cylinder.radius = 0.17; cylinder.height = 2.4
	shape.shape = cylinder; shape.position = Vector3(0.0, 1.2, 0.0)
	body.add_child(shape)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.52, 0.40, 0.26); wood.roughness = 0.95
	var mesh := CylinderMesh.new(); mesh.top_radius = 0.17; mesh.bottom_radius = 0.20; mesh.height = 2.4
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = wood
	node.position = Vector3(0.0, 1.2, 0.0)
	body.add_child(node)
	body.position = at
	_world.add_child(body)
	return body

# ---------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not _ready or not _active(): return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_held_event = button.pressed
			_held = button.pressed
			_player.set("_sword_lock", _held)
			get_viewport().set_input_as_handled()
			return
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# Wheel = pull back / drive the point forward (thrust), the missing
			# axis that lets the player stab as well as cut.
			var step := 0.22 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -0.22
			_thrust = clampf(_thrust + step, 0.0, 1.0)
			_player.set("_sword_lock", true)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _held_event or _held):
		var motion := event as InputEventMouseMotion
		# The same motion must not also turn the camera.
		_hand.x += motion.relative.x * MOUSE_TO_HAND
		_hand.y -= motion.relative.y * MOUSE_TO_HAND
		_hand = _hand.limit_length(1.0)
		get_viewport().set_input_as_handled()

func _active() -> bool:
	return _ready and _selected and is_instance_valid(_player) and _player.is_inside_tree() \
		and bool(_player.get("_free_mouse_look")) and _player.get("_pose_authority") == &"on_foot" \
		and not _player._text_control_focused()

## Called by the arsenal host when the prototype sword is equipped or removed.
func set_selected(value: bool) -> void:
	if _selected == value: return
	_selected = value
	if not _selected:
		_held = false
		_held_event = false
		_hand = Vector2.ZERO
		_omega = Vector3.ZERO
		_dir = _rest_direction()
		_block_push = Vector3.ZERO
		_body_push = Vector3.ZERO
		_body_lean = Vector2.ZERO
		_body_yaw = 0.0
		_contact_prev.clear()
		_prev_points = PackedVector3Array()
		if is_instance_valid(_sword): _sword.visible = false
		if is_instance_valid(_player): _player.set("_sword_lock", false)
	elif is_instance_valid(_player):
		if is_instance_valid(_rig) and _bone_hand >= 0:
			_sword_origin = _rig.global_transform * _rig.get_bone_global_pose(_bone_hand).origin
		_rest_dir = _rest_direction()
		_dir = _rest_dir

# ------------------------------------------------------------------- steering

func _rest_direction() -> Vector3:
	# Rest is a ready stance: the point of the blade looks UP, slightly forward
	# and outward, so the sword is visible and reads as held, not hanging.
	var basis := _camera.global_basis
	return (-basis.z * 0.42 + basis.y * 0.88 + basis.x * 0.12).normalized()

func _target_direction() -> Vector3:
	var basis := _camera.global_basis
	var steer := basis.x * (_hand.x * 1.25) + basis.y * (_hand.y * 1.25)
	# A wheel thrust pushes the point straight forward (a stab), without one it
	# keeps the ordinary diagonal swing bias.
	var forward_bias := 0.95 + _thrust * 0.95
	var target := (-basis.z * forward_bias + steer + basis.y * 0.10).normalized()
	if not target.is_finite(): return _rest_dir
	return target

func _steer(delta: float) -> void:
	var target := _constrain_to_body(_constrain_forward(_target_direction()), 0.20) if _held else _constrain_to_body(_constrain_forward(_rest_dir), 0.20)
	var rate := 1.0 if _held else REST_RETURN_RATE
	var axis := _dir.cross(target)
	var angle := _dir.angle_to(target)
	var desired := Vector3.ZERO
	if angle > 1e-4 and axis.length_squared() > 1e-10:
		desired = axis.normalized() * clampf(angle * 7.0 * rate, 0.0, MAX_OMEGA)
	var dv := desired - _omega
	var max_dv := MAX_ALPHA * delta
	if dv.length() > max_dv and dv.length() > 1e-9: dv = dv.normalized() * max_dv
	_omega += dv
	if _omega.length() > MAX_OMEGA: _omega = _omega.normalized() * MAX_OMEGA
	if _omega.length() > 1e-6:
		var q := Quaternion(_omega.normalized(), _omega.length() * delta)
		_dir = (q * _dir).normalized()

func _physics_process(delta: float) -> void:
	if not _ready or not is_instance_valid(_world): return
	var active := _active()
	# Camera lock follows the real button state and survives a momentary loss of
	# activity, so the view can never drift while the blade is being steered.
	_held = _held_event or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_player.set("_sword_lock", _selected and _held and bool(_player.get("_free_mouse_look")))
	if not active:
		_hand = _hand.lerp(Vector2.ZERO, clampf(REST_RETURN_RATE * delta, 0.0, 1.0))
		_release_arm()
		_sword.visible = false
		_prev_points = PackedVector3Array()
		_block_push = _block_push.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
		return
	_sword.visible = true
	if not _held:
		# Released: the commanded hand offset decays so the blade returns to rest.
		_hand = _hand.lerp(Vector2.ZERO, clampf(REST_RETURN_RATE * delta, 0.0, 1.0))
	_thrust = lerpf(_thrust, 0.2, clampf(0.9 * delta, 0.0, 1.0))
	_steer(delta)
	_block_push = _block_push.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	_body_push = _body_push.lerp(Vector3.ZERO, clampf(BODY_PUSH_DECAY * delta, 0.0, 1.0))
	_solve_arm(delta)
	# The blade is never allowed to point behind the player.
	_dir = _constrain_forward(_dir)
	_dir = _constrain_to_body(_dir, 0.40)
	_place_sword(_sword_origin, _dir)
	_sweep(delta)
	# A contact may deflect the blade; put it back into the allowed front space
	# immediately so it can never be shown behind the character.
	_dir = _constrain_to_body(_constrain_forward(_dir), 0.40)
	_update_dummy(delta)
	_update_spark(delta)

## Keeps a direction inside the player's forward half space (never behind).
func _constrain_forward(direction: Vector3) -> Vector3:
	var forward := -_camera.global_basis.z
	var cast := direction.dot(forward)
	if cast >= 0.12: return direction
	var corrected := direction - forward * (cast - 0.12)
	if corrected.length_squared() < 1e-8: return forward
	return corrected.normalized()

## Keeps the sword hand in front of the TORSO (never behind the back). The hero
## model faces along +Z of its visual node, so "ahead" is +local.z here.
func _constrain_to_body(direction: Vector3, min_forward: float) -> Vector3:
	if not is_instance_valid(_player) or not is_instance_valid(_player._visual): return direction
	var visual: Node3D = _player._visual
	var basis: Basis = visual.global_basis
	var local: Vector3 = basis.inverse() * direction
	var ahead: float = local.z
	if ahead >= min_forward: return direction
	var side := Vector3(local.x, local.y, 0.0)
	if side.length_squared() > 0.36: side = side.normalized() * 0.6
	var corrected := (side + Vector3(0.0, 0.0, min_forward)).normalized()
	return (basis * corrected).normalized()

## Where the sword hand is allowed to go. The whole front hemisphere is open —
## high, low, left, right and thrusting forward — but never behind the back and
## never folded through the head.
func _hand_target_direction() -> Vector3:
	var basis := _camera.global_basis
	var hx := clampf(_hand.x, -1.0, 1.0)
	var hy := clampf(_hand.y, -1.0, 0.40)
	var yaw_off := hx * 0.95
	# Base pitch keeps the fist at chest height; a thrust drives it forward.
	var pitch_off := clampf(0.02 + hy * 0.60 - _thrust * 0.35, -0.65, 0.35)
	var flat := (-basis.z).rotated(Vector3.UP, -yaw_off).normalized()
	return (flat * cos(pitch_off) + Vector3.UP * sin(pitch_off)).normalized()

## Two-bone IK over the real rig so the sword arm actually moves with the blade.
## The sword arm is written as LOCAL bone poses after the player's own pose pass,
## which is why it no longer flickers: no global override competes with the rig
## authority. The arm is extended toward the commanded direction, the wrist
## follows the blade, and the torso turns toward the target.
func _solve_arm(delta: float) -> void:
	var rig_basis := _rig.global_transform.basis
	var want_dir := _constrain_forward(_hand_target_direction())
	# The hand stays in front of the torso even while the body is still turning.
	want_dir = _constrain_to_body(want_dir, 0.55)
	var want_rig := (rig_basis.inverse() * want_dir).normalized()
	var blade_rig := (rig_basis.inverse() * _dir).normalized()
	_lean_body(want_dir, delta)
	var clavicle_global := _chain_global(_bone_clavicle)
	if _bone_upper < 0 or _bone_fore < 0 or _bone_hand < 0: return
	var upper_local := _point_bone(_bone_upper, _rest_upper, _rest_fore.origin, clavicle_global.basis, want_rig)
	var upper_global := clavicle_global * upper_local
	var fore_local := _point_bone(_bone_fore, _rest_fore, _rest_hand.origin, upper_global.basis, want_rig)
	var fore_global := upper_global * fore_local
	var hand_offset := _rest_socket.origin if _bone_socket >= 0 else Vector3(0.0, 1.0, 0.0)
	var hand_local := _point_bone(_bone_hand, _rest_hand, hand_offset, fore_global.basis, blade_rig)
	var hand_global := fore_global * hand_local
	# The pommel sits in the fist: the grip centre is the wrist, pushed a little
	# back along the blade so the hand does not hold the guard.
	_sword_origin = _guard_hand_in_front((_rig.global_transform * hand_global.origin) - _dir * 0.055)

## Hard guarantee that the sword hand can never end up behind the character's
## back: the grip is clamped into the front half space of the torso, with a
## bounded sideways/vertical envelope so the arm cannot wrap around the body.
func _guard_hand_in_front(origin: Vector3) -> Vector3:
	if not is_instance_valid(_player) or not is_instance_valid(_player._visual): return origin
	var visual: Node3D = _player._visual
	var basis: Basis = visual.global_basis
	var local: Vector3 = basis.inverse() * (origin - visual.global_position)
	local.z = maxf(local.z, 0.22)
	local.x = clampf(local.x, -0.80, 0.80)
	local.y = clampf(local.y, -0.10, 1.25)
	return visual.global_position + basis * local

## Rotates one bone so that the direction toward its child points at dir_rig.
func _point_bone(bone: int, rest: Transform3D, child_offset: Vector3, parent_global_basis: Basis, dir_rig: Vector3) -> Transform3D:
	var rest_dir := rest.basis * child_offset
	if rest_dir.length_squared() < 1.0e-10: rest_dir = rest.basis.y
	var local_dir := parent_global_basis.inverse() * dir_rig
	if local_dir.length_squared() < 1.0e-10: local_dir = rest_dir
	var turn := Quaternion(rest_dir.normalized(), local_dir.normalized())
	var local := Transform3D((Basis(turn) * rest.basis).orthonormalized(), rest.origin)
	_rig.set_bone_pose(bone, local)
	return local

## Rig-space pose built from the CURRENT local poses, so it includes both the
## player's locomotion pose and the rotations written above.
func _chain_global(bone: int) -> Transform3D:
	var chain: Array[int] = []
	var index := bone
	while index >= 0:
		chain.push_front(index)
		index = _rig.get_bone_parent(index)
	var result := Transform3D.IDENTITY
	for item: int in chain:
		result = result * _rig.get_bone_pose(item)
	return result

## The character keeps facing the target, and the whole body carries the weight:
## the hips, spine and chest lean against the blade's angular load and absorb the
## recoil of a contact, while the head keeps looking at the target.
func _lean_body(want_dir: Vector3, delta: float) -> void:
	var rig_basis := _rig.global_transform.basis
	var inv := rig_basis.inverse()
	var axis_right := (inv * Vector3(1.0, 0.0, 0.0)).normalized()
	var axis_fwd := (inv * Vector3(0.0, 0.0, 1.0)).normalized()
	var axis_up := (inv * Vector3(0.0, 1.0, 0.0)).normalized()
	var visual: Node3D = _player._visual
	var world_fwd: Vector3 = -visual.global_basis.z
	var world_right: Vector3 = visual.global_basis.x
	# 1. Torso yaw toward the commanded blade direction.
	var yaw_target := 0.0
	var flat := Vector3(want_dir.x, 0.0, want_dir.z)
	if flat.length_squared() > 1.0e-6:
		# The visual node faces along +Z, so its yaw is atan2(x, z).
		var delta_yaw := wrapf(atan2(flat.x, flat.z) - visual.global_rotation.y, -PI, PI)
		yaw_target = clampf(delta_yaw * BODY_YAW_SHARE, -BODY_YAW_LIMIT, BODY_YAW_LIMIT)
	_body_yaw = lerpf(_body_yaw, yaw_target, clampf(BODY_FOLLOW_RATE * delta, 0.0, 1.0))
	# 2. Lean: opposite the blade's angular acceleration, plus contact recoil.
	var swing_pitch := -_omega.dot(world_right) * BODY_LEAN_GAIN
	var swing_roll := -_omega.dot(world_fwd) * BODY_LEAN_GAIN
	var push_pitch := _body_push.dot(world_fwd) * BODY_PUSH_GAIN
	var push_roll := -_body_push.dot(world_right) * BODY_PUSH_GAIN
	var target_lean := Vector2(swing_pitch + push_pitch, swing_roll + push_roll)
	target_lean.x = clampf(target_lean.x, -BODY_LEAN_LIMIT, BODY_LEAN_LIMIT)
	target_lean.y = clampf(target_lean.y, -BODY_LEAN_LIMIT, BODY_LEAN_LIMIT)
	_body_lean = _body_lean.lerp(target_lean, clampf(BODY_FOLLOW_RATE * delta, 0.0, 1.0))
	# 3. Distribute the load over the chain: hips take the least, chest the most.
	var shares := [
		[_bone_pelvis, 0.35, 0.30, 0.45],
		[_bone_spine, 0.65, 0.60, 0.70],
		[_bone_chest, 1.00, 1.00, 1.00],
	]
	for entry: Array in shares:
		var bone: int = entry[0]
		if bone < 0: continue
		var yaw := _body_yaw * float(entry[1])
		var pitch := _body_lean.x * float(entry[2])
		var roll := _body_lean.y * float(entry[3])
		if absf(yaw) + absf(pitch) + absf(roll) < 0.002: continue
		var turn := Quaternion(axis_up, yaw) * Quaternion(axis_right, -pitch) * Quaternion(axis_fwd, roll)
		var local := _rig.get_bone_pose(bone)
		_rig.set_bone_pose(bone, Transform3D((Basis(turn) * local.basis).orthonormalized(), local.origin))
	# 4. The head counter-turns a little so the character keeps his eyes on target.
	if _bone_head >= 0 and absf(_body_yaw) > 0.01:
		var head_turn := Quaternion(axis_up, -_body_yaw * 0.45)
		var head_local := _rig.get_bone_pose(_bone_head)
		_rig.set_bone_pose(_bone_head, Transform3D((Basis(head_turn) * head_local.basis).orthonormalized(), head_local.origin))

func _release_arm() -> void:
	# Nothing to undo: the pose authority rewrites every bone on its next pass as
	# soon as this host stops writing the arm.
	pass
func _place_sword(origin: Vector3, direction: Vector3) -> void:
	var x := direction.normalized()
	var reference := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	var z := x.cross(reference).normalized()
	var y := z.cross(x).normalized()
	_sword.global_transform = Transform3D(Basis(x, y, z), origin)

# -------------------------------------------------------------- blade sweeping

func _sweep(delta: float) -> void:
	if delta <= 0.0: return
	var points := PackedVector3Array()
	for i: int in SWEEP_SEGMENTS + 1:
		var t := float(i) / float(SWEEP_SEGMENTS)
		points.append(_sword_origin + _dir * (0.06 + BLADE_LENGTH * t))
	if _prev_points.size() != points.size():
		_prev_points = points
		return
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_player.get_rid()]
	var best_hit: Dictionary = {}
	var best_distance := INF
	var now := Time.get_ticks_msec()
	var touched: Dictionary = {}
	for i: int in points.size():
		var from := _prev_points[i]
		var to := points[i]
		if from.distance_squared_to(to) < 1.0e-8: continue
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, excluded)
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		_sweep_rays += 1
		if hit.is_empty(): continue
		_sweep_hits += 1
		var collider: Variant = hit.get("collider")
		if is_instance_valid(collider): touched[collider.get_instance_id()] = true
		var distance := from.distance_to(hit.position)
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
			best_hit["_speed"] = from.distance_to(to) / delta
			best_hit["_index"] = i
	if not best_hit.is_empty():
		_resolve_contact(best_hit, points, now, touched)
	# Remember what the blade was already touching: a target that stays in
	# contact is not struck again, so one swing cannot machine-gun damage.
	_contact_prev = touched
	_prev_points = points

func _resolve_contact(hit: Dictionary, points: PackedVector3Array, now: int, touched: Dictionary) -> void:
	var collider: Variant = hit.get("collider")
	var speed := float(hit.get("_speed", 0.0))
	var position: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var is_target: bool = is_instance_valid(collider) and collider.has_meta("sword_target")
	# Hitting a body stops the blade just like masonry does: it never sinks in and
	# stays there. The push is softer than a wall so the sword frees itself.
	var point_index := int(hit.get("_index", 0))
	var correction := position - points[point_index]
	var penetration := correction.length()
	if penetration > 0.02:
		_block_push += correction * (0.55 if is_target else 0.85)
	var into := _dir.dot(normal)
	if into < 0.0:
		_dir = (_dir - normal * into).normalized()
	var deflect := _dir - normal * _dir.dot(normal)
	if deflect.length_squared() > 1e-6: _dir = deflect.normalized()
	_omega *= 0.45 if is_target else 0.15
	var recoil := clampf(speed, 0.0, 4.0)
	_body_push += normal * recoil * (0.05 if is_target else 0.08)
	_body_push = _body_push.limit_length(BODY_PUSH_LIMIT)
	if is_target:
		var id: int = collider.get_instance_id()
		# One entry = one blow. While the blade keeps touching the dummy (or the
		# dummy is wobbling away from it) no further damage is dealt.
		if not _contact_prev.has(id) and penetration >= 0.0:
			_damage_dummy(collider, position, speed, now)
		return
	# Wall/pole: the visible blade stops and slides along the surface instead
	# of passing through. Pulling the mouse back releases it immediately.
	if now - _last_block_ms >= 180:
		_last_block_ms = now
		_blocks += 1
		_impact_player.global_position = position
		_impact_player.pitch_scale = 1.15
		_impact_player.play()
	_show_spark(position)

func _damage_dummy(dummy: StaticBody3D, position: Vector3, speed: float, now: int) -> void:
	if _dummy_down: return
	var key := dummy.get_instance_id()
	if _hit_ms.has(key) and now - int(_hit_ms[key]) < CONTACT_COOLDOWN_MS: return
	var damage := clampf((speed - DAMAGE_SPEED_MIN) * DAMAGE_PER_MPS, 0.0, DAMAGE_MAX)
	_hit_ms[key] = now
	if damage <= 0.05:
		# A light touch is felt but does not remove health.
		_impact_player.global_position = position
		_impact_player.pitch_scale = 1.45
		_impact_player.volume_db = -12.0
		_impact_player.play()
		_dummy_tilt = maxf(_dummy_tilt, 0.05)
		return
	_impact_player.volume_db = 0.0
	_impact_player.global_position = position
	_impact_player.pitch_scale = 0.85 + randf() * 0.25
	_impact_player.play()
	# A landed blow pushes the body back through the arm.
	_body_push += -_dir * clampf(speed, 0.0, 4.0) * 0.05
	_body_push = _body_push.limit_length(BODY_PUSH_LIMIT)
	_show_spark(position)
	_hits += 1
	_max_damage = maxf(_max_damage, damage)
	_dummy_hp = maxf(0.0, _dummy_hp - damage)
	var local := dummy.to_local(position)
	_dummy_tilt_axis = Vector3(local.z, 0.0, -local.x).normalized()
	if _dummy_tilt_axis.length_squared() < 1e-6: _dummy_tilt_axis = Vector3.RIGHT
	_dummy_tilt = clampf(_dummy_tilt + 0.12 + damage * 0.012, 0.0, 0.62)
	_dummy_label.text = "Манекен %d" % int(round(_dummy_hp))
	_dummy_label.modulate = Color(1.0, 0.55, 0.45) if _dummy_hp <= 40.0 else Color(1.0, 0.92, 0.65)
	_spawn_damage_number(position, damage)
	if _dummy_hp <= 0.0:
		_dummy_down = true
		_down_until_ms = now + 2200
		_dummy_tilt = 0.62
		_dummy_label.text = "Манекен сбит"

func _update_dummy(delta: float) -> void:
	if not is_instance_valid(_dummy_pivot): return
	if _dummy_down and Time.get_ticks_msec() >= _down_until_ms:
		_dummy_down = false
		_dummy_hp = DUMMY_MAX_HP
		_dummy_label.text = "Манекен %d" % int(DUMMY_MAX_HP)
		_dummy_label.modulate = Color(1.0, 0.92, 0.65)
	_dummy_tilt = maxf(0.0, _dummy_tilt - delta * (0.55 if _dummy_down else 1.35))
	_dummy_pivot.rotation = _dummy_tilt_axis * _dummy_tilt

func _show_spark(at: Vector3) -> void:
	if not is_instance_valid(_spark): return
	_spark.global_position = at
	_spark.visible = true
	_spark_left = 0.09

func _update_spark(delta: float) -> void:
	if not is_instance_valid(_spark) or not _spark.visible: return
	_spark_left -= delta
	_spark.scale = Vector3.ONE * maxf(0.15, _spark_left / 0.09)
	if _spark_left <= 0.0: _spark.visible = false

func _spawn_damage_number(at: Vector3, damage: float) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 110
	label.pixel_size = 0.0032
	label.outline_size = 20
	label.modulate = Color(1.0, 0.35, 0.28)
	label.text = "-%d" % int(round(damage))
	label.position = at + Vector3.UP * 0.22
	_world.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector3.UP * 0.75, 0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(label.queue_free)

# ------------------------------------------------------------------- reporting

func snapshot() -> Dictionary:
	return {
		"ready": _ready, "held": _held, "hits": _hits, "blocks": _blocks,
		"dummy_hp": _dummy_hp, "dummy_down": _dummy_down, "max_damage": _max_damage,
		"hand": [_hand.x, _hand.y], "direction": [_dir.x, _dir.y, _dir.z],
		"body_yaw": _body_yaw, "body_pitch": _body_lean.x, "body_roll": _body_lean.y,
		"body_push": _body_push.length(), "omega": _omega.length(), "thrust": _thrust,
		"blade_body_dot": _dir.dot(_player._visual.global_basis.z) if is_instance_valid(_player) and is_instance_valid(_player._visual) else -1.0,
		"hand_local_z": (_player._visual.global_basis.inverse() * (_sword_origin - _player._visual.global_position)).z if is_instance_valid(_player) and is_instance_valid(_player._visual) else 0.0,
		"upper_len": _upper_len, "fore_len": _fore_len,
		"player_position": _player.global_position if is_instance_valid(_player) else Vector3.ZERO,
		"dummy_position": _dummy.global_position if is_instance_valid(_dummy) else Vector3.ZERO,
		"pole_position": _pole.global_position if is_instance_valid(_pole) else Vector3.ZERO,
		"dummy_distance": _player.global_position.distance_to(_dummy.global_position) if is_instance_valid(_player) and is_instance_valid(_dummy) else -1.0,
		"blade_tip": _sword_origin + _dir * (0.06 + BLADE_LENGTH),
		"sweep_rays": _sweep_rays, "sweep_hits": _sweep_hits, "selected": _selected,
		"rig_scale": _rig.global_transform.basis.get_scale() if is_instance_valid(_rig) else Vector3.ZERO,
		"shoulder_world": _rig.global_transform * (_rig.get_bone_global_pose(_bone_clavicle) * _rest_upper).origin if is_instance_valid(_rig) and _bone_clavicle >= 0 else Vector3.ZERO,
		"sword_origin": _sword_origin,
	}

func _exit_tree() -> void:
	_ready = false
	if is_instance_valid(_player): _player.set("_sword_lock", false)
	_release_arm()
	set_physics_process(false)
	set_process_input(false)
