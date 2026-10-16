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
## Distance from the model origin to the middle of the grip along the blade axis.
## The fist closes on this point, so the handle (not the guard) sits in the hand.
const GRIP_CENTER_OFFSET := 0.0625
const SWEEP_SEGMENTS := 9
const MOUSE_TO_HAND := 0.0042
## The commanded hand offset cannot jump: it is slewed toward the mouse command
## at a bounded rate, which is what keeps a fast mouse flick from snapping the
## whole arm (and the blade with it) across the body.
const HAND_SLEW_RATE := 14.0    # units per second
const HAND_MAX_OFFSET := 1.5
const MAX_OMEGA := 22.0         # rad/s, a decisive cut, not a paint stroke
const MAX_ALPHA := 160.0        # rad/s^2, hard acceleration into the swing
## Steering: high gain so a flick really whips the blade, light damping and light
## target smoothing. Heavy damping here is what turned cuts into brush strokes.
const STEER_GAIN := 13.0
const STEER_DAMPING := 0.20
const STEER_DEADZONE := 0.25
const STEER_ANGLE_DEADZONE := 0.04
const STEER_TARGET_SMOOTH := 45.0
const MOUSE_NOISE_FLOOR := 1.2
const FOLLOW_RATE := 7.5        # hand spring rate toward the commanded point
const REST_RETURN_RATE := 4.5   # blade return when LMB is released
## Body weight: the swing is carried by hips, spine and chest, not only by the
## arm. The torso leans against the blade's angular acceleration and takes the
## recoil of every contact.
const BODY_FOLLOW_RATE := 4.5   # how fast the body follows the load
## The torso is driven by a damped spring, not by direct assignment: a heavy body
## lags the blade instead of twitching after every mouse movement.
const BODY_STIFFNESS := 22.0
const BODY_DAMPING := 8.5
const BODY_YAW_STIFFNESS := 16.0
const BODY_YAW_DAMPING := 7.5
const BODY_LEAN_GAIN := 0.018   # radians of lean per rad/s of blade rotation
const BODY_LEAN_LIMIT := 0.11
const BODY_PUSH_GAIN := 0.55    # metres of recoil per metre/second of contact
const BODY_PUSH_LIMIT := 0.22
const BODY_PUSH_DECAY := 3.2
## The torso only helps the swing: a small, soft turn plus the lean above. The
## arm is what reaches, and it is clamped in front of the torso, so the blade can
## never end up behind the back.
const BODY_YAW_SHARE := 0.16
const BODY_YAW_LIMIT := 0.30
## During a live cut the torso turns much further than while guarding, so the
## body visibly drives the swing.
const BODY_YAW_SHARE_SWING := 0.48
const BODY_YAW_LIMIT_SWING := 0.70
const DAMAGE_SPEED_MIN := 1.05  # m/s below which a touch deals no damage
const DAMAGE_PER_MPS := 9.0
const DAMAGE_MAX := 34.0
## Wind-up: radians of blade travel that saturate the strength bonus.
const MAX_SWING_TRAVEL := 2.4
const SWING_STRENGTH_GAIN := 0.62
const SWING_STRENGTH_MIN := 0.45
const CONTACT_COOLDOWN_MS := 700
## A blow only counts after the blade actually left the target for this long.
## Without it, a blade resting on the ground or wobbling against the dummy fires
## a fresh "entry" every frame and floods damage, sounds and damage numbers.
const CONTACT_REARM_MS := 260
const SPARK_COOLDOWN_MS := 140
const BLOCK_SOUND_COOLDOWN_MS := 420
const DAMAGE_NUMBER_COOLDOWN_MS := 220
const DAMAGE_NUMBER_LIMIT := 6
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
## Left arm chain, used by the two-handed grip (RMB).
var _bone_l_clavicle := -1
var _bone_l_upper := -1
var _bone_l_fore := -1
var _bone_l_hand := -1
var _rest_l_upper := Transform3D.IDENTITY
var _rest_l_fore := Transform3D.IDENTITY
var _rest_l_hand := Transform3D.IDENTITY
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
## Raw mouse command and the slewed value that actually drives the arm.
var _hand_cmd := Vector2.ZERO
var _sword_origin := Vector3.ZERO
var _dir := Vector3.FORWARD
var _omega := Vector3.ZERO
var _block_push := Vector3.ZERO
## Body load: lean (pitch, roll) and recoil carried by hips/spine/chest.
var _body_lean := Vector2.ZERO
var _body_lean_vel := Vector2.ZERO
var _body_yaw := 0.0
var _body_yaw_vel := 0.0
var _body_push := Vector3.ZERO
var _prev_points: PackedVector3Array = PackedVector3Array()
var _held := false
## Which hand is holding the sword. LMB = left hand, RMB = right hand, both
## buttons = two-handed grip. Releasing keeps the grip in the hand that had it.
var _hold_left := false
var _hold_right := false
var _carry_side: StringName = &"right"
## Distance between the supporting fist and the handle it should be gripping.
var _left_hand_error := 0.0
## Wheel-driven thrust: pulls the hand back or drives the point forward.
var _thrust := 0.2
## Blade direction expressed in the fist's own frame while the sword is carried.
## Locking the carried blade to the fist (instead of re-deriving it from the
## camera every frame) is what stops the idle jitter and keeps it in the hand.
var _carry_offset := Vector3.ZERO
var _carry_valid := false
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
## id -> time of the last frame the blade was NOT touching that collider.
var _contact_gap: Dictionary = {}
var _last_spark_ms := -1000
var _last_block_sound_ms := -1000
var _last_number_ms := -1000
var _ground_touch_ms := -10000
var _number_count := 0
## Blade travel accumulated during the current wind-up: a swipe that stroked the
## target barely counts, a full wind-up followed by a cut hits much harder.
var _swing_travel := 0.0
## Blade direction when the current swing began, and the previous held state.
var _swing_start_dir := Vector3.ZERO
## Smoothed steering target, so a raw camera/mouse target cannot ripple the blade.
var _steer_target := Vector3.ZERO
var _held_prev := false
## Largest wind-up angle that still counts (radians).
const SWING_ANGLE_MAX := 2.4

## How far the blade has turned since the swing started. Sensitivity-independent:
## any player can reach the same angles with the same swing.
func _windup_angle() -> float:
	if _swing_start_dir.length_squared() < 1.0e-6: return 0.0
	return clampf(_swing_start_dir.angle_to(_dir), 0.0, SWING_ANGLE_MAX)
## Kind of the last landed blow: slice, stab or flat.
var _last_hit_kind := ""
var _last_hit_scale := 1.0
## Time until which contacts are ignored: drawing the blade into the stance moves
## it fast, and that motion must not count as a blow.
var _arm_ready_ms := 0
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
	_bone_l_clavicle = rig.find_bone("clavicle_l")
	_bone_l_upper = rig.find_bone("upperarm_l")
	_bone_l_fore = rig.find_bone("forearm_l")
	_bone_l_hand = rig.find_bone("hand_l")
	# The rig is mirrored on screen: the "_l" bones are the character's RIGHT arm.
	# The rig-space "left" sign therefore points from the "_l"-named hand to the
	# "_r"-named one, which is what keeps the supporting hand on its own side.
	if _bone_hand >= 0 and _bone_l_hand >= 0:
		var visual_left_rig: Vector3 = rig.get_bone_global_pose(_bone_hand).origin
		var visual_right_rig: Vector3 = rig.get_bone_global_pose(_bone_l_hand).origin
		_left_sign = 1.0 if (visual_left_rig.x - visual_right_rig.x) >= 0.0 else -1.0
		if _left_sign == 0.0: _left_sign = 1.0
	# The two-handed offset (13 cm down the handle) must be in the rig's own bone
	# units, or the supporting fist lands on the main one and the arm folds up.
	var rig_scale := maxf(0.02, rig.global_transform.basis.get_scale().y)
	_two_hand_offset_rig = 0.11 / rig_scale
	_rest_l_upper = rig.get_bone_rest(_bone_l_upper) if _bone_l_upper >= 0 else Transform3D.IDENTITY
	_rest_l_fore = rig.get_bone_rest(_bone_l_fore) if _bone_l_fore >= 0 else Transform3D.IDENTITY
	_rest_l_hand = rig.get_bone_rest(_bone_l_hand) if _bone_l_hand >= 0 else Transform3D.IDENTITY
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
	_sword = _build_sword_model(_world, "PrototypeSword")
	_build_impacts()
	_build_hint()
	var placed := _place_targets()
	_rest_dir = _rest_direction()
	_dir = _rest_dir
	_sword_origin = _rig.global_transform * _rig.get_bone_global_pose(_bone_hand).origin
	_ready = true
	set_process_input(true)
	set_physics_process(true)
	set_process(true)
	# The player asks this host directly before turning the camera, so the lock
	# never depends on input routing order.
	player.set("_sword_host", self)
	print("DSH_SWORD_PROTO_BONES right=", _bone_clavicle, ",", _bone_upper, ",", _bone_fore, ",", _bone_hand,
		" left=", _bone_l_clavicle, ",", _bone_l_upper, ",", _bone_l_fore, ",", _bone_l_hand)
	return {"ok": true, "socket": rig.get_bone_name(_bone_socket), "upper_len": _upper_len, "fore_len": _fore_len, "dummy": placed.dummy, "pole": placed.pole}

## True while the player is actively steering the blade (LMB held).
func is_steering() -> bool:
	return _ready and _selected and _held

# ---------------------------------------------------------------- construction

## One-handed sword, built from parts: tapering double-edged blade with a fuller,
## ricasso, curved cross-guard with quillon blocks, wrapped grip and a disc
## pommel. Local +X is the point, so the sweep maths above stays unchanged.
## Builds one sword model into `parent` and returns it. Used for the player and
## for the sparring opponent, so both carry the same weapon.
func _build_sword_model(parent: Node3D, node_name: String) -> Node3D:
	var sword := Node3D.new()
	sword.name = node_name
	parent.add_child(sword)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.74, 0.78, 0.84); steel.metallic = 0.92; steel.roughness = 0.22
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.88, 0.91, 0.95); edge.metallic = 0.95; edge.roughness = 0.12
	var dark_steel := StandardMaterial3D.new()
	dark_steel.albedo_color = Color(0.52, 0.56, 0.62); dark_steel.metallic = 0.85; dark_steel.roughness = 0.34
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.22, 0.14, 0.10); leather.roughness = 0.88
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.66, 0.50, 0.20); brass.metallic = 0.78; brass.roughness = 0.34
	var start := 0.155                     # blade starts after the ricasso
	# Blade: four tapering sections so the profile narrows toward the point.
	var sections := [
		[0.42, 0.060, 0.021], [0.34, 0.050, 0.018], [0.26, 0.038, 0.014], [0.20, 0.024, 0.010],
	]
	var cursor := start
	for section: Array in sections:
		var length := float(section[0])
		var width := float(section[1])
		var thickness := float(section[2])
		var body := BoxMesh.new(); body.size = Vector3(length, width, thickness)
		var body_node := MeshInstance3D.new(); body_node.mesh = body; body_node.material_override = steel
		body_node.position = Vector3(cursor + length * 0.5, 0.0, 0.0)
		sword.add_child(body_node)
		# Cutting edges on both sides of every section.
		for side: float in [1.0, -1.0]:
			var bevel := BoxMesh.new(); bevel.size = Vector3(length, 0.014, thickness * 0.45)
			var bevel_node := MeshInstance3D.new(); bevel_node.mesh = bevel; bevel_node.material_override = edge
			bevel_node.position = Vector3(cursor + length * 0.5, side * (width * 0.5 - 0.005), 0.0)
			sword.add_child(bevel_node)
		cursor += length
	# Fuller (blood groove) running along the strong part of the blade.
	var fuller := BoxMesh.new(); fuller.size = Vector3(0.62, 0.026, 0.024)
	var fuller_node := MeshInstance3D.new(); fuller_node.mesh = fuller; fuller_node.material_override = dark_steel
	fuller_node.position = Vector3(start + 0.33, 0.0, -0.001)
	sword.add_child(fuller_node)
	# Ricasso: the flat, thicker root of the blade above the guard.
	var ricasso := BoxMesh.new(); ricasso.size = Vector3(0.085, 0.048, 0.026)
	var ricasso_node := MeshInstance3D.new(); ricasso_node.mesh = ricasso; ricasso_node.material_override = dark_steel
	ricasso_node.position = Vector3(start - 0.042, 0.0, 0.0)
	sword.add_child(ricasso_node)
	# Cross-guard: central block plus two arms tilted slightly toward the blade,
	# each finished with a small quillon block.
	var guard_core := BoxMesh.new(); guard_core.size = Vector3(0.045, 0.075, 0.042)
	var guard_core_node := MeshInstance3D.new(); guard_core_node.mesh = guard_core; guard_core_node.material_override = brass
	guard_core_node.position = Vector3(start - 0.095, 0.0, 0.0)
	sword.add_child(guard_core_node)
	for side: float in [1.0, -1.0]:
		var arm := BoxMesh.new(); arm.size = Vector3(0.030, 0.115, 0.032)
		var arm_node := MeshInstance3D.new(); arm_node.mesh = arm; arm_node.material_override = brass
		arm_node.position = Vector3(start - 0.098, side * 0.093, 0.0)
		arm_node.rotation = Vector3(0.0, 0.0, side * -0.16)
		sword.add_child(arm_node)
		var quillon := SphereMesh.new(); quillon.radius = 0.020; quillon.height = 0.040
		var quillon_node := MeshInstance3D.new(); quillon_node.mesh = quillon; quillon_node.material_override = brass
		quillon_node.position = Vector3(start - 0.098, side * 0.150, 0.0)
		sword.add_child(quillon_node)
	# Grip: leather core with metal ferrules and a wrapped pattern of rings.
	var grip := CylinderMesh.new(); grip.top_radius = 0.019; grip.bottom_radius = 0.021; grip.height = 0.175
	var grip_node := MeshInstance3D.new(); grip_node.mesh = grip; grip_node.material_override = leather
	grip_node.position = Vector3(start - 0.205, 0.0, 0.0)
	grip_node.rotation = Vector3(0.0, 0.0, PI * 0.5)
	sword.add_child(grip_node)
	for index: int in 5:
		var ring := TorusMesh.new(); ring.inner_radius = 0.020; ring.outer_radius = 0.025
		var ring_node := MeshInstance3D.new(); ring_node.mesh = ring
		ring_node.material_override = brass if index % 2 == 0 else dark_steel
		ring_node.position = Vector3(start - 0.130 - index * 0.035, 0.0, 0.0)
		ring_node.rotation = Vector3(0.0, PI * 0.5, 0.0)
		sword.add_child(ring_node)
	# Pommel: disc with a small button, sitting against the fist.
	var pommel := CylinderMesh.new(); pommel.top_radius = 0.040; pommel.bottom_radius = 0.044; pommel.height = 0.030
	var pommel_node := MeshInstance3D.new(); pommel_node.mesh = pommel; pommel_node.material_override = brass
	pommel_node.position = Vector3(start - 0.305, 0.0, 0.0)
	pommel_node.rotation = Vector3(0.0, 0.0, PI * 0.5)
	sword.add_child(pommel_node)
	var button := SphereMesh.new(); button.radius = 0.017; button.height = 0.030
	var button_node := MeshInstance3D.new(); button_node.mesh = button; button_node.material_override = dark_steel
	button_node.position = Vector3(start - 0.325, 0.0, 0.0)
	sword.add_child(button_node)
	return sword

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
	_hint.text = "ТЕСТОВЫЙ МЕЧ (прототип)\nЛКМ и мышь — рубящий удар ЛЕВОЙ рукой\nПКМ и мышь — БЛОК: меч ставится туда, куда ведёшь мышью\nЛКМ + ПКМ — двуручный хват, удар сильнее\nКолесо мыши — укол вперёд / оттянуть назад"
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
	# The sparring partner starts a few metres along the open direction and walks
	# in on his own, so the opening view already shows him approaching.
	var duelist_dir := (dummy_at - base)
	duelist_dir.y = 0.0
	if duelist_dir.length_squared() < 1.0e-6: duelist_dir = Vector3.FORWARD
	duelist_dir = duelist_dir.normalized()
	var duelist_at := _grounded(base + duelist_dir * 4.6)
	if not duelist_at.is_finite(): duelist_at = base + duelist_dir * 4.6
	_build_duelist(duelist_at)
	# The opponent is the game's own resident model, wearing plate, driven by the
	# canonical walk gait; the simple figure stays only as a fallback.
	if _spawn_resident_knight(duelist_at):
		_duelist.visible = false
		_duelist_hull.set_meta("sword_duelist", false)
	print("DSH_SWORD_PROTO_PLACEMENT dummy=", dummy_at, " pole=", pole_at, " duelist=", duelist_at, " player=", base)
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
	# Death restart must work even with the cursor released and the host inactive.
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_R and is_instance_valid(_world) and bool(_world.get("preview_dead")):
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene.call_deferred()
			return
	if not _ready or not _active(): return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_held_event = button.pressed
			_hold_left = button.pressed
			_held = _hold_left or _hold_right
			_player.set("_sword_lock", false)
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_hold_right = button.pressed
			_held = _hold_left or _hold_right
			_player.set("_sword_lock", false)
			get_viewport().set_input_as_handled()
			return
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# Wheel = pull back / drive the point forward (thrust), the missing
			# axis that lets the player stab as well as cut.
			var step := 0.22 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -0.22
			_thrust = clampf(_thrust + step, 0.0, 1.0)
			_player.set("_sword_lock", false)
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_hold_right = button.pressed
			_held = _hold_left or _hold_right
			_player.set("_sword_lock", false)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _held_event or _held):
		var motion := event as InputEventMouseMotion
		# Mouse sensors keep reporting a pixel or two while the hand is still; that
		# noise is what made the blade ripple. Anything below the floor is ignored.
		if absf(motion.relative.x) + absf(motion.relative.y) < MOUSE_NOISE_FLOOR:
			return
		# The SAME motion also turns the camera: the event is deliberately NOT
		# consumed here, so the view stays free while the blade is steered.
		_hand_cmd.x += motion.relative.x * MOUSE_TO_HAND
		_hand_cmd.y -= motion.relative.y * MOUSE_TO_HAND
		_hand_cmd = _hand_cmd.limit_length(HAND_MAX_OFFSET)

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
		_hand_cmd = Vector2.ZERO
		_omega = Vector3.ZERO
		_dir = _rest_direction()
		_block_push = Vector3.ZERO
		_body_push = Vector3.ZERO
		_body_lean = Vector2.ZERO
		_body_lean_vel = Vector2.ZERO
		_body_yaw = 0.0
		_body_yaw_vel = 0.0
		_contact_prev.clear()
		_contact_gap.clear()
		_prev_points = PackedVector3Array()
		if is_instance_valid(_sword): _sword.visible = false
		if is_instance_valid(_player): _player.set("_sword_lock", false)
	elif is_instance_valid(_player):
		if is_instance_valid(_rig) and _bone_hand >= 0:
			_sword_origin = _rig.global_transform * _rig.get_bone_global_pose(_bone_hand).origin
		_rest_dir = _rest_direction()
		_dir = _rest_dir
		_arm_ready_ms = Time.get_ticks_msec() + 700

# ------------------------------------------------------------------- steering

func _rest_direction() -> Vector3:
	# Rest is a ready stance with the point clearly UP and only slightly forward,
	# so the blade reads as carried in the fist instead of hanging from its tip.
	var basis := _camera.global_basis
	return (-basis.z * 0.35 + basis.y * 0.92 + basis.x * 0.10).normalized()

## Body-relative carried stance (independent of the camera): the point is up and
## a touch out and forward. This is what keeps the idle blade steady instead of
## chasing the camera's micro-movement.
func _carry_direction() -> Vector3:
	var visual: Node3D = _player._visual
	return (Vector3.UP * 0.92 + visual.global_basis.x * 0.26 + visual.global_basis.z * 0.26).normalized()

## Where the sword HAND rests in the ready stance: forward at chest height with a
## natural bend, so the elbow is not folded back into the chest.
func _ready_hand_direction() -> Vector3:
	var visual: Node3D = _player._visual
	return (visual.global_basis.z * 0.88 + Vector3.UP * 0.32).normalized()

## Where the blade is held while guarding. The steel lies ACROSS the body like a
## bar - mostly in the frontal plane, not pointing at the enemy - and the mouse
## slides that bar up/down/left/right so the player picks the zone to cover.
func _guard_direction() -> Vector3:
	var basis := _camera.global_basis
	var hx := clampf(_hand.x, -1.0, 1.0)
	var hy := clampf(_hand.y, -1.0, 1.0)
	var across := basis.x * (hx * 1.25) + basis.y * (0.55 + hy * 0.95)
	var guard := (across - basis.z * 0.22).normalized()
	if not guard.is_finite(): return _rest_dir
	return guard

func _target_direction() -> Vector3:
	var basis := _camera.global_basis
	var steer := basis.x * (_hand.x * 1.30) + basis.y * (_hand.y * 2.10)
	# A wheel thrust pushes the point straight forward (a stab); otherwise the
	# ready bias keeps the point up-forward so a low cut only happens when the
	# player actually drives the mouse down.
	var forward_bias := 0.55 + _thrust * 1.10
	var target := (-basis.z * forward_bias + steer + basis.y * 0.35).normalized()
	# Guard against a default low cut: without a deliberate downward command the
	# blade never points below the horizon.
	if _hand.y > -0.25 and target.y < 0.05:
		target = Vector3(target.x, 0.05, target.z).normalized()
	if not target.is_finite(): return _rest_dir
	return target

func _steer(delta: float) -> void:
	if _blocking and not _hold_left:
		# GUARD (RMB): the blade is placed where the mouse points and simply stays
		# there - a real, physical barrier for incoming blows, not a swing.
		var guard := _guard_direction()
		_dir = _dir.slerp(guard, clampf(14.0 * delta, 0.0, 1.0)).normalized()
		_omega = Vector3.ZERO
		return
	if not _held:
		# Carried stance: a stable, body-relative ready angle (up, a little out and
		# forward). Deriving it from the fist made the blade swing into the body as
		# the walk animation turned the wrist.
		var carry := _carry_direction()
		_dir = _dir.slerp(carry, clampf(7.0 * delta, 0.0, 1.0)).normalized()
		_omega = Vector3.ZERO
		return
	var target := _soft_body_limit(_constrain_forward(_target_direction()), 0.05, 0.22)
	# Smooth the target itself: the camera basis and the mouse both feed it, and a
	# raw per-frame target is what showed up as a ripple on the blade.
	if _steer_target.length_squared() < 1.0e-6:
		_steer_target = target
	else:
		_steer_target = _steer_target.slerp(target, clampf(STEER_TARGET_SMOOTH * delta, 0.0, 1.0)).normalized()
	target = _steer_target
	# After the tip has just touched the floor, the blade cannot be driven back
	# down until it has lifted - this is what stops the 10 Hz ground hop.
	if Time.get_ticks_msec() - _ground_touch_ms < 130 and target.y < 0.0:
		target = Vector3(target.x, 0.0, target.z).normalized()
	# A larger error drives a proportionally faster blade, so a decisive flick
	# whips the sword through instead of dragging it. Damping is essential now that
	# the view is free: without it the blade rings against a moving target and the
	# sword visibly buzzes while the button is merely held.
	var axis := _dir.cross(target)
	var angle := _dir.angle_to(target)
	var desired := Vector3.ZERO
	if angle > 1.0e-4 and axis.length_squared() > 1.0e-10:
		desired = axis.normalized() * clampf(angle * STEER_GAIN, 0.0, MAX_OMEGA)
	desired -= _omega * STEER_DAMPING
	var dv := desired - _omega
	var max_dv := MAX_ALPHA * delta
	if dv.length() > max_dv and dv.length() > 1.0e-9: dv = dv.normalized() * max_dv
	_omega += dv
	# Park a nearly-settled blade instead of letting it buzz around the target.
	if _omega.length() < STEER_DEADZONE and angle < STEER_ANGLE_DEADZONE:
		_omega = Vector3.ZERO
		if angle > 1.0e-5:
			_dir = _dir.slerp(target, clampf(6.0 * delta, 0.0, 1.0)).normalized()
	if _omega.length() > MAX_OMEGA: _omega = _omega.normalized() * MAX_OMEGA
	if _omega.length() > 1e-6:
		var q := Quaternion(_omega.normalized(), _omega.length() * delta)
		_dir = (q * _dir).normalized()

func _physics_process(delta: float) -> void:
	if not _ready or not is_instance_valid(_world): return
	var active := _active()
	# Camera lock follows the real button state and survives a momentary loss of
	# activity, so the view can never drift while the blade is being steered.
	_held = _hold_left or _hold_right or _held_event or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	# Remember which single hand is holding the sword, so releasing a button keeps
	# the grip exactly there. Both buttons = two-handed (right hand leads).
	if _hold_left and not _hold_right: _carry_side = &"left"
	elif _hold_right and not _hold_left: _carry_side = &"right"
	# RMB ALONE is the guard. LMB+RMB is the two-handed cut and must still wound,
	# which it could not while ANY right button counted as blocking.
	_blocking = _hold_right and not _hold_left
	_player.set("_sword_lock", false)
	if not active:
		# Outside the play state (menu, free cursor, death) no button stays held:
		# a missed release used to leave RMB stuck on and force a two-handed grip.
		_hold_left = false
		_hold_right = false
		_held = false
		_held_event = false
		_player.set("_sword_lock", false)
		_hand_cmd = _hand_cmd.lerp(Vector2.ZERO, clampf(REST_RETURN_RATE * delta, 0.0, 1.0))
		_hand = _hand.lerp(Vector2.ZERO, clampf(REST_RETURN_RATE * delta, 0.0, 1.0))
		_release_arm()
		if is_instance_valid(_sword): _sword.visible = false
		_prev_points = PackedVector3Array()
		_block_push = _block_push.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
		return
	if not _synthetic_hands:
		# Real input: the buttons are read from the engine every frame, so a missed
		# release event can never leave the view locked.
		_hold_left = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_hold_right = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		_held_event = _hold_left
		_held = _hold_left or _hold_right
		_player.set("_sword_lock", false)
	if is_instance_valid(_sword): _sword.visible = true
	_dir = _soft_body_limit(_constrain_forward(_dir), 0.10, 0.16)
	if not _held:
		# Released: the mouse command decays so the blade returns to rest.
		_hand_cmd = _hand_cmd.lerp(Vector2.ZERO, clampf(REST_RETURN_RATE * delta, 0.0, 1.0))
	# Slew the driving value toward the mouse command at a bounded rate.
	var to_command := _hand_cmd - _hand
	var max_step := HAND_SLEW_RATE * delta
	if to_command.length() > max_step and to_command.length() > 1.0e-6:
		to_command = to_command.normalized() * max_step
	_hand += to_command
	_thrust = lerpf(_thrust, 0.2, clampf(0.9 * delta, 0.0, 1.0))
	_steer(delta)
	# Wind-up bookkeeping, measured as the ANGLE the blade has turned away from
	# where the swing began. Accumulating mouse travel rewarded high DPI, which is
	# unfair; an angle is the same for every player and every sensitivity, and it is
	# still what a real wind-up is.
	if _held and not _held_prev:
		_swing_start_dir = _dir
	_held_prev = _held
	if not _held:
		_swing_start_dir = _dir
	_swing_travel = _windup_angle()
	_block_push = _block_push.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	_body_push = _body_push.lerp(Vector3.ZERO, clampf(BODY_PUSH_DECAY * delta, 0.0, 1.0))
	_solve_arm(delta)
	# The blade is never allowed to point behind the player.
	_dir = _soft_body_limit(_constrain_forward(_dir), 0.10, 0.16)
	# The opponent is a real body: his step, gravity and pose belong to the physics
	# frame, otherwise move_and_slide() leaves him hanging in the air.
	_update_city_npc(delta)

## The sword is attached in the DRAW frame, not in the physics step: the rig has
## already applied every bone pose by then (including the player's own pass), so
## the handle is placed on the fist the animation actually shows. Attaching it
## during the physics step read a stale skeleton and left the sword out of hand.
func _process(delta: float) -> void:
	if not _ready or not is_instance_valid(_world) or not is_instance_valid(_rig): return
	if not _active():
		if is_instance_valid(_sword): _sword.visible = false
		return
	# A severed limb is cut away every frame, AFTER the player's own pose pass, so
	# neither the animation nor our own arm IK can restore it.
	_apply_player_severed()
	var armed_with_sword := is_instance_valid(_sword)
	if armed_with_sword:
		_sword.visible = true
		_attach_sword_to_fist()
	_update_gore(delta)
	_update_stumps(delta)
	if not is_instance_valid(_npc_rig): _update_duelist(delta)
	if not armed_with_sword:
		# The blade lies on the ground with the hand that used to hold it.
		_prev_points = PackedVector3Array()
		return
	if not _held:
		# Carried blade: attached to the fist and nothing else. No limits, no
		# sweep bookkeeping - that is what keeps it still in the hand.
		_prev_points = PackedVector3Array()
		_update_dummy(delta)
		_update_spark(delta)
		return
	_sweep(delta)
	# A contact may deflect the blade; put it back into the allowed front space
	# immediately so it can never be shown behind the character.
	_dir = _soft_body_limit(_constrain_forward(_dir), 0.10, 0.16)
	_update_dummy(delta)
	_update_spark(delta)

## Places the sword on the RIG'S CURRENT fist (displayed pose), with the grip
## centre inside the hand and the blade along the commanded direction.
func _attach_sword_to_fist() -> void:
	var bone := _hand_bone_for(_active_side())
	if bone < 0: return
	var fist: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(bone).origin
	_sword_origin = fist + _dir * GRIP_CENTER_OFFSET
	_place_sword(_sword_origin, _dir)
	_grip_hand_error = _sword_origin.distance_to(fist)

## Left hand takes the lower part of the handle: reaches from its own shoulder to
## that point, so the second hand really sits on the grip instead of being faked.
## Distance from the right fist down the handle for the supporting hand.
const TWO_HAND_LOWER_OFFSET := 0.115
## Damage bonus of the two-handed grip.
const TWO_HAND_DAMAGE_SCALE := 1.25

func _solve_left_arm(grip_world: Vector3) -> void:
	if _bone_l_upper < 0 or _bone_l_fore < 0 or _bone_l_hand < 0: return
	if _bone_l_clavicle < 0: return
	var rig_basis := _rig.global_transform.basis
	var target_rig := rig_basis.inverse() * grip_world
	var clavicle_global := _chain_global(_bone_l_clavicle)
	var joint := (clavicle_global * _rest_l_upper).origin
	var to_target := target_rig - joint
	if to_target.length_squared() < 1.0e-8: return
	var reach_dir := to_target.normalized()
	var upper_local := _point_bone(_bone_l_upper, _rest_l_upper, _rest_l_fore.origin, clavicle_global.basis, reach_dir)
	var upper_global := clavicle_global * upper_local
	var fore_local := _point_bone(_bone_l_fore, _rest_l_fore, _rest_l_hand.origin, upper_global.basis, reach_dir)
	var fore_global := upper_global * fore_local
	# The supporting palm faces the handle, so the wrist is aimed along it.
	var wrist_dir := (target_rig - fore_global.origin)
	if wrist_dir.length_squared() > 1.0e-8:
		_point_bone(_bone_l_hand, _rest_l_hand, _rest_l_hand.origin, fore_global.basis, wrist_dir.normalized())
	_left_hand_error = (rig_basis * fore_global.origin).distance_to(grip_world)

## World basis of the sword fist, as the rig currently displays it.
func _fist_basis() -> Basis:
	if not is_instance_valid(_rig) or _bone_hand < 0: return Basis.IDENTITY
	return (_rig.global_transform.basis * _rig.get_bone_global_pose(_bone_hand).basis).orthonormalized()

## Blends into the body-space limit instead of snapping to it, so the blade is
## pulled back into the allowed front space over a few frames.
func _soft_body_limit(direction: Vector3, min_forward: float, weight: float) -> Vector3:
	var limited := _constrain_to_body(direction, min_forward)
	if limited.distance_squared_to(direction) < 1.0e-10: return direction
	return direction.slerp(limited, weight).normalized()

## Keeps a direction inside the player's forward half space (never behind).
func _constrain_forward(direction: Vector3) -> Vector3:
	var forward := -_camera.global_basis.z
	var cast := direction.dot(forward)
	if cast >= 0.02: return direction
	var corrected := direction - forward * (cast - 0.02)
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
	if side.length_squared() > 0.81: side = side.normalized() * 0.9
	var corrected := (side + Vector3(0.0, 0.0, min_forward)).normalized()
	return (basis * corrected).normalized()

## Where the sword hand is allowed to go. The whole front hemisphere is open -
## high, low, left, right and thrusting forward - but never behind the back and
## never folded through the head.
func _hand_target_direction() -> Vector3:
	var basis := _camera.global_basis
	var hx := clampf(_hand.x, -1.0, 1.0)
	var hy := clampf(_hand.y, -1.0, 1.0)
	var yaw_off := hx * 1.30
	# The whole vertical arc is open, and now a real wind-up is possible too: the
	# fist can swing from below the hip right up over the head.
	var pitch_off := clampf(0.10 + hy * 1.05 - _thrust * 0.30, -1.00, 1.30)
	var flat := (-basis.z).rotated(Vector3.UP, -yaw_off).normalized()
	return (flat * cos(pitch_off) + Vector3.UP * sin(pitch_off)).normalized()

## Two-bone IK over the real rig so the sword arm actually moves with the blade.
## The sword arm is written as LOCAL bone poses after the player's own pose pass,
## which is why it no longer flickers: no global override competes with the rig
## authority. The arm is extended toward the commanded direction, the wrist
## follows the blade, and the torso turns toward the target.
func _solve_arm(delta: float) -> void:
	var rig_basis := _rig.global_transform.basis
	if not _held:
		# Carried but READY: the sword hand keeps a light, bent grip on the raised
		# blade, so the sword stays visibly in the fist while walking instead of
		# hanging down beside the leg. The target is the body-relative carry, so it
		# does not chase the camera and cannot shake.
		# The HAND goes to a natural ready position (forward and slightly up, elbow
		# bent), while the BLADE still points up. Using the blade direction for the
		# hand as well is what folded the arm across the chest.
		var want_dir := _constrain_forward(_ready_hand_direction())
		want_dir = _constrain_to_body(want_dir, 0.10)
		var want_rig := (rig_basis.inverse() * want_dir).normalized()
		var blade_rig := (rig_basis.inverse() * _dir).normalized()
		_lean_body(want_dir, delta)
		var side := _active_side()
		var grip_rig := _pose_main(side, want_rig, blade_rig, 0.72)
		if grip_rig != Vector3.ZERO:
			_sword_origin = (_rig.global_transform * grip_rig) + _dir * GRIP_CENTER_OFFSET
		return
	var want_dir := _constrain_forward(_hand_target_direction())
	want_dir = _constrain_to_body(want_dir, 0.10)
	var want_rig := (rig_basis.inverse() * want_dir).normalized()
	var blade_rig := (rig_basis.inverse() * _dir).normalized()
	_lean_body(want_dir, delta)
	var side := _active_side()
	var grip_rig := Vector3.ZERO
	if side == &"both":
		# Two-handed: BOTH hands are pushed well forward of the chest, so the arms
		# read as an extended grip instead of a knot against the body. Right leads.
		grip_rig = _pose_main(&"right", want_rig, blade_rig, 0.88)
		if grip_rig != Vector3.ZERO:
			var support := grip_rig - blade_rig * _two_hand_offset_rig
			# The supporting hand never reaches across the centre line, which is
			# what used to knot the two arms together during a cut.
			if support.x * _left_sign < 0.06: support.x = _left_sign * 0.06
			_pose_support(&"left", support)
	elif side == &"left":
		grip_rig = _pose_main(&"left", want_rig, blade_rig)
	else:
		grip_rig = _pose_main(&"right", want_rig, blade_rig)
	if grip_rig == Vector3.ZERO: return
	_sword_origin = (_rig.global_transform * grip_rig) + _dir * GRIP_CENTER_OFFSET

## Which hand holds the sword right now. LMB = left-hand strike, RMB = a guard in
## the right hand (the blade is placed where the mouse points and stops blows),
## both buttons = two-handed grip.
var _blocking := false

func _active_side() -> StringName:
	if _hold_left and _hold_right: return &"both"
	if _hold_left: return &"left"
	if _hold_right: return &"right"
	return _carry_side

func _hand_bone_for(side: StringName) -> int:
	return _arm_set(side).hand

## Bone set that is VISUALLY on the requested side. The hero rig names are
## mirrored relative to the model's visible sides, so the mapping is resolved
## once at install time by comparing the clavicle positions.
func _arm_set(side: StringName) -> Dictionary:
	# The hero rig is MIRRORED on screen: the "_l" bones render on the character's
	# right. So LMB (left) drives the "_r" bones and RMB (right) the "_l" bones.
	var use_l_named: bool = side == &"right"
	# The elbow must fall to the arm's OWN side. That side is decided by the visual
	# side, not by which bones happen to be named "_l"/"_r".
	var pole := _left_sign if side == &"left" else -_left_sign
	if use_l_named:
		return {
			"clav": _bone_l_clavicle, "upper": _bone_l_upper, "fore": _bone_l_fore, "hand": _bone_l_hand,
			"rest_upper": _rest_l_upper, "rest_fore": _rest_l_fore, "rest_hand": _rest_l_hand,
			"offset": _rest_l_hand.origin, "pole": pole,
		}
	return {
		"clav": _bone_clavicle, "upper": _bone_upper, "fore": _bone_fore, "hand": _bone_hand,
		"rest_upper": _rest_upper, "rest_fore": _rest_fore, "rest_hand": _rest_hand,
		"offset": _rest_socket.origin if _bone_socket >= 0 else Vector3(0.0, 1.0, 0.0), "pole": pole,
	}

## Poses the arm that holds the sword in the main grip; returns the fist in
## rig space. `side` is the VISUAL side, so the rig's mirrored names are handled
## here and nowhere else.
func _pose_main(side: StringName, want_rig: Vector3, blade_rig: Vector3, reach_scale: float = 1.0) -> Vector3:
	var set := _arm_set(side)
	return _pose_arm_ik(set.clav, set.upper, set.fore, set.hand, set.rest_upper, set.rest_fore, set.rest_hand, set.offset, want_rig, blade_rig, reach_scale, false, set.pole)

## Supporting hand closes on the lower part of the handle (two-handed grip).
## The wrist simply continues the forearm - no twist toward the handle, which is
## what used to fold the arm into a hook.
func _pose_support(side: StringName, grip_rig: Vector3) -> void:
	var set := _arm_set(side)
	var fist: Vector3 = _pose_arm_ik(set.clav, set.upper, set.fore, set.hand, set.rest_upper, set.rest_fore, set.rest_hand, set.offset, grip_rig, Vector3.UP, 1.0, true, set.pole)
	if fist != Vector3.ZERO: _left_hand_error = fist.distance_to(grip_rig)

## Two-bone IK with a real elbow: the hand reaches the requested point (clamped
## to the arm's length) instead of always being fully extended. That bend is what
## lets the second hand reach the handle in a two-handed grip.
func _pose_arm_ik(clav: int, upper: int, fore: int, hand: int, rest_upper: Transform3D, rest_fore: Transform3D, rest_hand: Transform3D, hand_offset: Vector3, want_rig: Vector3, blade_rig: Vector3, reach_scale: float = 1.0, want_is_point: bool = false, pole_side: float = 1.0) -> Vector3:
	if clav < 0 or upper < 0 or fore < 0 or hand < 0: return Vector3.ZERO
	var clavicle_global := _chain_global(clav)
	var joint := (clavicle_global * rest_upper).origin
	var l1 := rest_fore.origin.length()
	var l2 := rest_hand.origin.length()
	if l1 <= 0.01 or l2 <= 0.01: return Vector3.ZERO
	var target := want_rig if want_is_point else joint + want_rig * (l1 + l2) * clampf(reach_scale, 0.3, 1.0)
	var to_target := target - joint
	var distance := to_target.length()
	if distance < 1.0e-4: return Vector3.ZERO
	var direction := to_target.normalized()
	var d := clampf(distance, absf(l1 - l2) + 1.0e-3, l1 + l2 - 1.0e-3)
	# The elbow hangs DOWN (a little to its own side and slightly back), which is
	# what a human arm does. A sideways pole threw the elbow out into a Г shape.
	var pole := Vector3(0.16 * pole_side, -1.0, -0.12)
	pole -= direction * pole.dot(direction)
	if pole.length_squared() < 1.0e-6:
		pole = direction.cross(Vector3.RIGHT)
		if pole.length_squared() < 1.0e-6: pole = direction.cross(Vector3.UP)
	pole = pole.normalized()
	var cos_angle := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var upper_dir := (Quaternion(pole.cross(direction).normalized(), -acos(cos_angle)) * direction).normalized()
	var elbow := joint + upper_dir * l1
	var fore_dir := (joint + direction * d - elbow).normalized()
	var upper_local := _point_bone(upper, rest_upper, rest_fore.origin, clavicle_global.basis, upper_dir)
	var upper_global := clavicle_global * upper_local
	var fore_local := _point_bone(fore, rest_fore, rest_hand.origin, upper_global.basis, fore_dir)
	var fore_global := upper_global * fore_local
	var wrist_dir := blade_rig
	if want_is_point:
		var to_grip := target - fore_global.origin
		if to_grip.length_squared() > 1.0e-8: wrist_dir = to_grip.normalized()
	var hand_local := _point_bone(hand, rest_hand, hand_offset, fore_global.basis, wrist_dir)
	return (fore_global * hand_local).origin

## Hard guarantee that the sword hand can never end up behind the character's
## Hard guarantee that the sword hand can never end up behind the character's
## back or on top of his head: the grip is clamped into a front envelope at
## chest-to-shoulder height, so the blade is always readable in front of him.
func _guard_hand_in_front(origin: Vector3) -> Vector3:
	if not is_instance_valid(_player) or not is_instance_valid(_player._visual): return origin
	var visual: Node3D = _player._visual
	var basis: Basis = visual.global_basis
	var local: Vector3 = basis.inverse() * (origin - visual.global_position)
	local.z = maxf(local.z, 0.32)
	local.x = clampf(local.x, -0.75, 0.75)
	local.y = clampf(local.y, -0.05, 0.92)
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
	# 1. Torso yaw toward the commanded blade direction. A live cut turns the body
	# much further than a guard does, which is what sells the swing.
	var yaw_target := 0.0
	var flat := Vector3(want_dir.x, 0.0, want_dir.z)
	if flat.length_squared() > 1.0e-6:
		# The visual node faces along +Z, so its yaw is atan2(x, z).
		var delta_yaw := wrapf(atan2(flat.x, flat.z) - visual.global_rotation.y, -PI, PI)
		var swing_intensity := clampf(_omega.length() / maxf(0.01, MAX_OMEGA), 0.0, 1.0)
		var share := lerpf(BODY_YAW_SHARE, BODY_YAW_SHARE_SWING, swing_intensity)
		var limit := lerpf(BODY_YAW_LIMIT, BODY_YAW_LIMIT_SWING, swing_intensity)
		yaw_target = clampf(delta_yaw * share, -limit, limit)
	_body_yaw = lerpf(_body_yaw, yaw_target, clampf(BODY_FOLLOW_RATE * delta, 0.0, 1.0))
	var yaw_accel := (yaw_target - _body_yaw) * BODY_YAW_STIFFNESS - _body_yaw_vel * BODY_YAW_DAMPING
	_body_yaw_vel += yaw_accel * delta
	_body_yaw += _body_yaw_vel * delta
	_body_yaw = clampf(_body_yaw, -BODY_YAW_LIMIT_SWING, BODY_YAW_LIMIT_SWING)
	# 2. Lean: opposite the blade's angular acceleration, plus contact recoil.
	var swing_pitch := -_omega.dot(world_right) * BODY_LEAN_GAIN
	var swing_roll := -_omega.dot(world_fwd) * BODY_LEAN_GAIN
	var push_pitch := _body_push.dot(world_fwd) * BODY_PUSH_GAIN
	var push_roll := -_body_push.dot(world_right) * BODY_PUSH_GAIN
	var target_lean := Vector2(swing_pitch + push_pitch, swing_roll + push_roll)
	target_lean.x = clampf(target_lean.x, -BODY_LEAN_LIMIT, BODY_LEAN_LIMIT)
	target_lean.y = clampf(target_lean.y, -BODY_LEAN_LIMIT, BODY_LEAN_LIMIT)
	# A damped spring: the body carries weight and settles instead of snapping.
	var lean_accel := (target_lean - _body_lean) * BODY_STIFFNESS - _body_lean_vel * BODY_DAMPING
	_body_lean_vel += lean_accel * delta
	_body_lean += _body_lean_vel * delta
	_body_lean.x = clampf(_body_lean.x, -BODY_LEAN_LIMIT, BODY_LEAN_LIMIT)
	_body_lean.y = clampf(_body_lean.y, -BODY_LEAN_LIMIT, BODY_LEAN_LIMIT)
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
	# 4. The head counter-turns against the torso so the eyes keep following the
	# blade through the whole cut instead of swinging away with the chest.
	if _bone_head >= 0 and absf(_body_yaw) > 0.02:
		var head_turn := Quaternion(axis_up, -_body_yaw * 0.45)
		var head_local := _rig.get_bone_pose(_bone_head)
		_rig.set_bone_pose(_bone_head, Transform3D((Basis(head_turn) * head_local.basis).orthonormalized(), head_local.origin))

func _release_arm() -> void:
	# Nothing to undo: the pose authority rewrites every bone on its next pass as
	# soon as this host stops writing the arm.
	pass
## ------------------------------------------------------------------ duelist
## A sparring partner with the same sword. It walks in, winds up and cuts; the
## player's blade is a REAL physical guard: if the two blades meet during the
## incoming cut, the blow is stopped and no health is lost.
const DUELIST_HP := 120.0
const DUELIST_SPEED := 1.7
const DUELIST_REACH := 1.05
const DUELIST_WINDUP := 0.55
const DUELIST_STRIKE := 0.20
const DUELIST_RECOVER := 0.85
const DUELIST_DAMAGE := 12.0
const BLOCK_RADIUS := 0.24

var _duelist: Node3D
var _duelist_hull: StaticBody3D
var _duelist_body: Node3D
var _duelist_sword: Node3D
var _duelist_dir := Vector3.FORWARD
var _duelist_hp := DUELIST_HP
var _duelist_state := "approach"
var _duelist_timer := 0.0
var _duelist_blade_prev: PackedVector3Array = PackedVector3Array()
var _duelist_swings := 0
var _duelist_hits := 0
var _duelist_blocked := 0
var _player_blocks := 0
var _sparring_hp := 100.0
var _last_clash_ms := -1000

## Distance between the sword grip and the fist that should be holding it; a
## health check that the weapon really follows the chosen hand.
var _grip_hand_error := 0.0
## The opponent only fights back once the player has actually hurt him.
var _duelist_engaged := false
var _duelist_aggro_until_ms := 0
## While set, the opponent's blade is still springing back from a parry.
var _duelist_recoil_until_ms := 0
## True when the rig's "_l"/"_r" names are mirrored relative to the visible sides
## (the hero faces +Z), resolved once at install time.
var _side_inverted := false
## X sign (rig space) of the arm the player sees as the left one.
var _left_sign := 1.0
## Whether the "_l"-named bones are the ones on the visual left side.
var _left_is_l_named := true
## Distance down the handle for the supporting hand, in the rig's bone units.
var _two_hand_offset_rig := 0.3
## Set by a driven test that feeds button state directly, because synthetic mouse
## events are not mirrored by Input.is_mouse_button_pressed.
var _synthetic_hands := false

func _build_duelist(at: Vector3) -> void:
	_duelist = Node3D.new()
	_duelist.name = "SwordDuelist"
	_world.add_child(_duelist)
	var body_shape := StaticBody3D.new()
	body_shape.name = "DuelistHull"
	body_shape.collision_layer = 1
	body_shape.collision_mask = 0
	body_shape.set_meta("sword_duelist", true)
	var hull := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.32; capsule.height = 1.55
	hull.shape = capsule; hull.position = Vector3(0.0, 0.85, 0.0)
	body_shape.add_child(hull)
	_duelist.add_child(body_shape)
	_duelist_hull = body_shape
	_duelist_body = Node3D.new()
	_duelist.add_child(_duelist_body)
	var cloth := StandardMaterial3D.new(); cloth.albedo_color = Color(0.22, 0.26, 0.38); cloth.roughness = 0.85
	var skin := StandardMaterial3D.new(); skin.albedo_color = Color(0.78, 0.62, 0.48); skin.roughness = 0.7
	var torso := CapsuleMesh.new(); torso.radius = 0.26; torso.height = 0.95
	var torso_node := MeshInstance3D.new(); torso_node.mesh = torso; torso_node.material_override = cloth
	torso_node.position = Vector3(0.0, 1.02, 0.0)
	_duelist_body.add_child(torso_node)
	var head := SphereMesh.new(); head.radius = 0.16; head.height = 0.32
	var head_node := MeshInstance3D.new(); head_node.mesh = head; head_node.material_override = skin
	head_node.position = Vector3(0.0, 1.68, 0.0)
	_duelist_body.add_child(head_node)
	for side: float in [1.0, -1.0]:
		var leg := CylinderMesh.new(); leg.top_radius = 0.10; leg.bottom_radius = 0.09; leg.height = 0.75
		var leg_node := MeshInstance3D.new(); leg_node.mesh = leg; leg_node.material_override = cloth
		leg_node.position = Vector3(side * 0.13, 0.38, 0.0)
		_duelist_body.add_child(leg_node)
	# Sword held in the opponent's right hand, pivoting about that fist.
	var fist := Node3D.new(); fist.name = "Fist"
	fist.position = Vector3(0.30, 1.24, 0.16)
	_duelist_body.add_child(fist)
	_duelist_sword = _build_sword_model(fist, "DuelistSword")
	_duelist.position = at
	_duelist_look_at_player(0.0)

func _duelist_look_at_player(delta: float) -> void:
	if not is_instance_valid(_duelist) or not is_instance_valid(_player): return
	var to_player := _player.global_position - _duelist.global_position
	to_player.y = 0.0
	if to_player.length_squared() < 1.0e-6: return
	var want := atan2(to_player.x, to_player.z)
	var current := _duelist.rotation.y
	_duelist.rotation.y = lerp_angle(current, want, clampf(5.0 * delta, 0.0, 1.0))

## Walk in, wind up, cut, recover. Every strike sweeps the opponent's blade and
## asks the player's blade whether it is in the way.
func _update_duelist(delta: float) -> void:
	if not is_instance_valid(_duelist) or not is_instance_valid(_player): return
	if _duelist_hp <= 0.0:
		_duelist_body.rotation.x = lerp_angle(_duelist_body.rotation.x, -1.35, clampf(3.0 * delta, 0.0, 1.0))
		return
	_duelist_look_at_player(delta)
	# He waits until the player actually lands a blow, then fights for a while and
	# calms down again if nothing happens.
	if _duelist_engaged and now_ms() > _duelist_aggro_until_ms:
		_duelist_engaged = false
		_duelist_state = "idle"
		_duelist_timer = 0.0
	if not _duelist_engaged:
		# He walks up and waits in guard: reachable, but he does not attack until
		# the player actually lands a blow on him.
		var to_player_idle := _player.global_position - _duelist.global_position
		to_player_idle.y = 0.0
		if to_player_idle.length() > DUELIST_REACH:
			_duelist.global_position += to_player_idle.normalized() * DUELIST_SPEED * delta
			_duelist.global_position.y = _player.global_position.y
		_duelist_dir = _duelist_dir.slerp(_duelist_high_guard(), clampf(3.0 * delta, 0.0, 1.0)).normalized()
		var fist_idle: Vector3 = _duelist_body.to_global(Vector3(0.30, 1.24, 0.16))
		_duelist_sword.global_transform = _place_basis(fist_idle + _duelist_dir * GRIP_CENTER_OFFSET, _duelist_dir)
		return
	var to_player := _player.global_position - _duelist.global_position
	to_player.y = 0.0
	var distance := to_player.length()
	_duelist_timer += delta
	match _duelist_state:
		"approach":
			if distance > DUELIST_REACH:
				_duelist.global_position += to_player.normalized() * DUELIST_SPEED * delta
				_duelist.global_position.y = _player.global_position.y
			else:
				_duelist_state = "windup"
				_duelist_timer = 0.0
		"windup":
			_duelist_dir = _duelist_dir.slerp(_duelist_high_guard(), clampf(7.0 * delta, 0.0, 1.0)).normalized()
			if _duelist_timer >= DUELIST_WINDUP:
				_duelist_state = "strike"
				_duelist_timer = 0.0
				_duelist_swings += 1
				_duelist_blade_prev = PackedVector3Array()
		"strike":
			var cut := _duelist_cut_direction()
			_duelist_dir = _duelist_dir.slerp(cut, clampf(16.0 * delta, 0.0, 1.0)).normalized()
			# A short lunge so the blade actually reaches the player.
			_duelist.global_position += cut * 1.2 * delta
			_duelist.global_position.y = _player.global_position.y
			_duelist_resolve_strike(delta)
			if _duelist_timer >= DUELIST_STRIKE:
				_duelist_state = "recover"
				_duelist_timer = 0.0
		_:
			_duelist_dir = _duelist_dir.slerp(_duelist_high_guard(), clampf(4.0 * delta, 0.0, 1.0)).normalized()
			if _duelist_timer >= DUELIST_RECOVER:
				_duelist_state = "approach" if distance > DUELIST_REACH else "windup"
				_duelist_timer = 0.0
	var fist_global: Vector3 = _duelist_body.to_global(Vector3(0.30, 1.24, 0.16))
	_duelist_sword.global_transform = _place_basis(fist_global + _duelist_dir * GRIP_CENTER_OFFSET, _duelist_dir)

func _duelist_high_guard() -> Vector3:
	var up := Vector3.UP
	return (up * 0.85 + _duelist.global_basis.z * -0.35).normalized()

func _duelist_cut_direction() -> Vector3:
	var to_player := (_player.global_position + Vector3.UP * 1.0) - _duelist.global_position
	if to_player.length_squared() < 1.0e-6: return Vector3.FORWARD
	return to_player.normalized()

func _duelist_blade_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	var origin: Vector3 = _duelist_sword.global_position
	var direction: Vector3 = _duelist_sword.global_basis.x.normalized()
	for i: int in 5:
		points.append(origin + direction * (0.10 + BLADE_LENGTH * float(i) / 4.0))
	return points

## The incoming cut: first ask the player's blade (a real guard), then the body.
func _duelist_resolve_strike(delta: float) -> void:
	var points := _duelist_blade_points()
	if _duelist_blade_prev.size() != points.size():
		_duelist_blade_prev = points
		return
	var space := _player.get_world_3d().direct_space_state
	for i: int in points.size():
		var from := _duelist_blade_prev[i]
		var to := points[i]
		if from.distance_squared_to(to) < 1.0e-8: continue
		# 1. Did the player's blade meet ours on this segment?
		if _player_blade_intercepts(from, to):
			_register_clash((from + to) * 0.5)
			_duelist_blade_prev = points
			return
		# 2. Otherwise a real hit on the body? The player is on layer 2, and the
		# opponent's own hull is on layer 1, so no exclusion list is needed.
		var query := PhysicsRayQueryParameters3D.create(from, to, 2)
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		if now_ms() - _last_player_hit_ms < 400: continue
		_last_player_hit_ms = now_ms()
		_duelist_hits += 1
		_apply_player_damage(DUELIST_DAMAGE, hit.position, (to - from).normalized())
		_duelist_blade_prev = points
		return
	# Fallback reach test: a cut swung at the player from close range lands unless
	# the player's blade is actually in the way, even if the thin ray misses.
	var to_player := (_player.global_position + Vector3.UP * 1.0) - _duelist.global_position
	if to_player.length() <= BLADE_LENGTH + 0.75 and _duelist_dir.dot(to_player.normalized()) > 0.72:
		var clash_at := _player.global_position + Vector3.UP * 1.0
		if _player_blade_intercepts(_duelist.global_position, clash_at):
			_register_clash(clash_at)
		elif now_ms() - _last_player_hit_ms >= 400:
			_last_player_hit_ms = now_ms()
			_duelist_hits += 1
			_apply_player_damage(DUELIST_DAMAGE, clash_at, to_player.normalized())
	_duelist_blade_prev = points

## True when the segment of the opponent's cut crosses the player's blade.
func _player_blade_intercepts(from: Vector3, to: Vector3) -> bool:
	if not is_instance_valid(_sword) or not _sword.visible: return false
	var mine_a: Vector3 = _sword_origin
	var mine_b: Vector3 = _sword_origin + _dir * (0.06 + BLADE_LENGTH)
	return _segment_distance(from, to, mine_a, mine_b) <= BLOCK_RADIUS

func _register_clash(at: Vector3) -> void:
	var now := now_ms()
	if now - _last_clash_ms < 260: return
	_last_clash_ms = now
	_player_blocks += 1
	_duelist_blocked += 1
	# Blade-on-blade bounce: both swords are knocked a little off the line, which
	# is what a parry feels like with steel.
	var away := _sword_origin - at
	away.y *= 0.35
	if away.length_squared() < 1.0e-6: away = -_dir
	away = away.normalized()
	_dir = (_dir - away * 0.45).normalized()
	_omega += away.cross(Vector3.UP) * 3.0
	if _omega.length() > MAX_OMEGA: _omega = _omega.normalized() * MAX_OMEGA
	_block_push = (_block_push + away * 0.05).limit_length(0.5)
	_body_push = (_body_push + away * 0.02).limit_length(BODY_PUSH_LIMIT)
	# The opponent's blade is knocked away too.
	var push_back := -away
	_duelist_dir = (_duelist_dir + push_back * 0.5).normalized()
	_duelist_recoil_until_ms = now + 200
	_impact_player.global_position = at
	_impact_player.pitch_scale = 1.7
	_impact_player.play()
	_show_spark(at)
	_duelist_state = "recover"
	_duelist_timer = 0.0

## Damage to the player: goes through the session health owner when present, so
## the ordinary HUD reacts, with a local sparring counter as a fallback.
var _last_player_hit_ms := -1000
func _apply_player_damage(amount: float, at: Vector3, direction: Vector3) -> void:
	# The wound lands on a real part of the body: it is tracked and, when it gives
	# out, that limb comes off the player exactly as it does off the opponent.
	_player_take_blade(amount, at, direction)
	_sparring_hp = maxf(0.0, _sparring_hp - amount)
	_impact_player.global_position = at
	_impact_player.pitch_scale = 0.8
	_impact_player.play()
	var owner := _session_health()
	if owner != null:
		var hp: Variant = owner.get("_hp")
		if hp is int:
			var remaining := maxi(0, int(hp) - int(round(amount)))
			owner.set("_hp", remaining)
			owner.set("_hit_age", 0.0)
			owner.call("_refresh")
			if remaining == 0: _kill_player()
	if is_instance_valid(_player): _player.apply_contact_melee_impulse(direction, 18.0)

## True when both arms are gone, so no hand can carry the sword at all.
func _both_hands_lost() -> bool:
	var right_lost: bool = _player_severed.has("hand_r") or _player_severed.has("forearm_r") or _player_severed.has("upperarm_r")
	var left_lost: bool = _player_severed.has("hand_l") or _player_severed.has("forearm_l") or _player_severed.has("upperarm_l")
	return right_lost and left_lost

## Player dismemberment: which part was hit, how much it can take, and what is
## lost when it comes off.
var _player_part_hp: Dictionary = {}
var _player_severed: Dictionary = {}
var _player_hidden_bones: Dictionary = {}
var _player_disarmed := false

func _player_part_at(point: Vector3) -> Dictionary:
	var best := {"key": "chest", "sever": "chest", "distance": 1.0e9}
	var probes := {
		"head": ["head", "neck"],
		"chest": ["chest", "spine_01"],
		"pelvis": ["pelvis"],
		"upperarm": ["upperarm_r", "upperarm_l"],
		"forearm": ["forearm_r", "forearm_l"],
		"hand": ["hand_r", "hand_l"],
		"thigh": ["thigh_r", "thigh_l"],
		"shin": ["shin_r", "shin_l"],
		"foot": ["foot_r", "foot_l"],
	}
	for part: String in probes.keys():
		for bone_name: String in probes[part]:
			var bone := _rig.find_bone(bone_name)
			if bone < 0: continue
			var bone_at: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(bone).origin
			var distance := bone_at.distance_to(point)
			if distance < best.distance:
				best = {"key": part, "sever": bone_name, "distance": distance}
	return best

func _player_take_blade(amount: float, at: Vector3, direction: Vector3) -> void:
	var part := _player_part_at(at)
	var kind: String = part.key
	var bone_name: String = part.sever
	var suffix := ""
	if bone_name.ends_with("_r"): suffix = "_r"
	elif bone_name.ends_with("_l"): suffix = "_l"
	var full_key: String = kind + suffix if kind not in ["head", "chest", "pelvis"] else kind
	if _player_severed.has(full_key): return
	if not _player_part_hp.has(full_key):
		_player_part_hp[full_key] = float(PART_HP.get(kind, 40.0))
	_player_part_hp[full_key] = float(_player_part_hp[full_key]) - maxf(4.0, amount)
	if float(_player_part_hp[full_key]) > 0.0: return
	_player_severed[full_key] = true
	_hide_player_limb(full_key, kind, bone_name)
	_spray_blood(at, direction, 30)
	_throw_stump(kind, at, direction, 3.0)
	if kind in ["upperarm", "forearm", "hand"]:
		var side := &"right"
		if full_key.ends_with("_l"): side = &"left"
		if _carry_side == side or (side == &"right" and _blocking):
			_player_disarmed = true
			_drop_player_sword(direction)
	if kind == "head":
		_player_disarmed = true
		_kill_player()
	print("DSH_SWORD_PROTO_PLAYER_SEVER part=", full_key, " disarmed=", _player_disarmed)

func _hide_player_limb(full_key: String, kind: String, bone_name: String) -> void:
	if kind in ["head", "chest", "pelvis"]:
		var chain: Array[String] = ["head", "neck"] if kind == "head" else []
		for name: String in chain: _player_hidden_bones[name] = true
		return
	_player_hidden_bones[bone_name] = true

## Applied every frame, AFTER the player's own pose pass, so the limb really
## disappears and cannot be restored by the animation or by our own arm IK.
func _apply_player_severed() -> void:
	if _player_hidden_bones.is_empty(): return
	for name: String in _player_hidden_bones.keys():
		var bone := _rig.find_bone(name)
		if bone < 0: continue
		var pose := _rig.get_bone_pose(bone)
		_rig.set_bone_pose(bone, Transform3D(Basis.IDENTITY.scaled(Vector3(0.001, 0.001, 0.001)), pose.origin))

func _drop_player_sword(direction: Vector3) -> void:
	if not is_instance_valid(_sword): return
	var falling: Node3D = _sword
	_sword = null
	var body := RigidBody3D.new()
	body.mass = 1.2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(1.3, 0.1, 0.1)
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = falling.global_position
	var visual := falling
	if visual.get_parent() != null: visual.get_parent().remove_child(visual)
	body.add_child(visual)
	visual.transform = Transform3D.IDENTITY
	body.linear_velocity = direction.normalized() * 1.5 + Vector3.UP * 0.5
	body.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))


## Mirrors the session death path so the ordinary R restart works after a
## sparring death.
func _kill_player() -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_player): return
	_world.set("preview_dead", true)
	var transport: Variant = _world.get("preview_transport")
	if is_instance_valid(transport) and transport.has_method("mark_dead"): transport.mark_dead()
	else: _player.set_preview_pose_authority(&"dead")
	_player.set_mouse_captured(false)
	_held = false
	_hold_left = false
	_hold_right = false
	_player.set("_sword_lock", false)

func _session_health() -> Object:
	if not is_instance_valid(_player) or not _player.has_meta("local_contact_health_owner"): return null
	var id: int = int(_player.get_meta("local_contact_health_owner"))
	var owner: Object = instance_from_id(id)
	return owner if is_instance_valid(owner) else null

func now_ms() -> int:
	return Time.get_ticks_msec()

## Shortest distance between two segments (used for blade-on-blade contact).
func _segment_distance(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	var u := a1 - a0
	var v := b1 - b0
	var w := a0 - b0
	var a := u.dot(u); var b := u.dot(v); var c := v.dot(v)
	var d := u.dot(w); var e := v.dot(w)
	var denominator := a * c - b * b
	var s := 0.0
	var t := 0.0
	if denominator > 1.0e-9:
		s = clampf((b * e - c * d) / denominator, 0.0, 1.0)
		t = clampf((a * e - b * d) / denominator, 0.0, 1.0)
	else:
		s = 0.0
		t = clampf(e / maxf(c, 1.0e-9), 0.0, 1.0)
	var closest_a := a0 + u * s
	var closest_b := b0 + v * t
	return closest_a.distance_to(closest_b)

## Builds a sword transform with +X along `direction`.
func _place_basis(origin: Vector3, direction: Vector3) -> Transform3D:
	var x := direction.normalized()
	var reference := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	var z := x.cross(reference).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), origin)

func _place_sword(origin: Vector3, direction: Vector3) -> void:
	_sword.global_transform = _place_basis(origin, direction)

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
	var now := Time.get_ticks_msec()
	var touched: Dictionary = {}
	# EVERY collider the blade crossed this frame is a contact, not just the
	# nearest one: a single swing through an arm and a chest is two hits.
	var hits: Array[Dictionary] = []
	var seen: Dictionary = {}
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
		if not is_instance_valid(collider): continue
		var id: int = collider.get_instance_id()
		touched[id] = true
		if seen.has(id): continue
		seen[id] = true
		hit["_speed"] = from.distance_to(to) / delta
		# Direction of the contact point's motion decides cut vs thrust.
		hit["_velocity"] = (to - from) / delta
		hit["_index"] = i
		hits.append(hit)
	for hit: Dictionary in hits:
		_resolve_contact(hit, points, now, touched)
	# Remember what the blade was already touching: a target that stays in
	# contact is not struck again, so one swing cannot machine-gun damage.
	for id: Variant in _contact_prev:
		if not touched.has(id): _contact_gap[id] = now
	_contact_prev = touched
	_prev_points = points

func _resolve_contact(hit: Dictionary, points: PackedVector3Array, now: int, touched: Dictionary) -> void:
	var collider: Variant = hit.get("collider")
	var speed := float(hit.get("_speed", 0.0))
	var position: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var is_target: bool = is_instance_valid(collider) and collider.has_meta("sword_target")
	var is_duelist: bool = is_instance_valid(collider) and collider.has_meta("sword_duelist")
	if not _held:
		# Carrying the sword is not a strike: a tip brushing the ground must not
		# push, deflect or rattle anything. Reacting here was the 10 Hz jitter.
		return
	var id_any: int = collider.get_instance_id() if is_instance_valid(collider) else -1
	var fresh: bool = id_any < 0 or not _contact_prev.has(id_any)
	# Ground contact never bounces: a blade resting on the floor only has its
	# downward rotation damped. Pushing or deflecting here made it hop repeatedly.
	if normal.y > 0.7:
		_ground_touch_ms = now
		_omega *= 0.90
		if fresh and now - _last_block_sound_ms >= BLOCK_SOUND_COOLDOWN_MS:
			_last_block_sound_ms = now
			_impact_player.global_position = position
			_impact_player.pitch_scale = 1.05
			_impact_player.play()
		return
	# Hitting a body stops the blade just like masonry does: it never sinks in and
	# stays there. The push is applied on a fresh touch and blended, so the sword
	# neither jerks in the hand nor bounces off the same surface every frame.
	var point_index := int(hit.get("_index", 0))
	var correction := position - points[point_index]
	var penetration := correction.length()
	if penetration > 0.02 and (fresh or penetration > 0.10):
		var gain := 0.30 if is_target else 0.50
		var add := correction * gain
		# Recoil is applied in bounded steps, never as one snap.
		if add.length() > 0.05: add = add.normalized() * 0.05
		_block_push = (_block_push + add).limit_length(0.55)
	if fresh:
		var into := _dir.dot(normal)
		if into < 0.0:
			_dir = _dir.slerp((_dir - normal * into).normalized(), 0.45).normalized()
		var deflect := _dir - normal * _dir.dot(normal)
		if deflect.length_squared() > 1e-6:
			_dir = _dir.slerp(deflect.normalized(), 0.25 if is_target else 0.45).normalized()
	# Rotation is braked on a fresh impact only; while the blade simply rests
	# against masonry it keeps sliding instead of stalling and re-accelerating.
	if fresh:
		_omega *= 0.60 if is_target else 0.25
		var recoil := clampf(speed, 0.0, 4.0)
		_body_push += normal * recoil * (0.02 if is_target else 0.04)
		_body_push = _body_push.limit_length(BODY_PUSH_LIMIT)
	if is_duelist:
		if _held and now - int(_hit_ms.get(id_any, -10000)) >= CONTACT_COOLDOWN_MS:
			_hit_ms[id_any] = now
			var cut := clampf((speed * 0.6 - DAMAGE_SPEED_MIN) * DAMAGE_PER_MPS, 1.0, DAMAGE_MAX)
			_duelist_hp = maxf(0.0, _duelist_hp - cut)
			# Being struck is what makes him fight back.
			_duelist_engaged = true
			_duelist_aggro_until_ms = now + 30000
			if _duelist_state == "idle":
				_duelist_state = "approach"
				_duelist_timer = 0.0
			_impact_player.global_position = position
			_impact_player.pitch_scale = 1.3
			_impact_player.play()
			_show_spark(position)
			_duelist_body.rotation.x = 0.22
		return
	var npc_part := ""
	if is_instance_valid(collider):
		var tag: Variant = collider.get_meta("sword_npc_part", "")
		if tag is String: npc_part = tag
	if npc_part != "" or _is_npc_collider(collider):
		# Hitting the armed resident hurts the LIMB that was struck, and a limb
		# that gives out is cut off - losing the sword arm also loses the sword.
		# One ENTRY = one blow: the blade must have left the part again, so a fast
		# second swing counts while a blade resting in the wound does not spam.
		var npc_rearmed: bool = not _contact_gap.has(id_any) or now - int(_contact_gap[id_any]) >= CONTACT_REARM_MS
		if _held and npc_rearmed and not _contact_prev.has(id_any):
			_hit_ms[id_any] = now
			# A full wind-up lands far harder, so a strong, prepared cut is what
			# actually severs a limb.
			var strength := clampf(SWING_STRENGTH_MIN + _swing_travel * SWING_STRENGTH_GAIN, SWING_STRENGTH_MIN, 2.0)
			var npc_cut := clampf((speed * 0.6 - DAMAGE_SPEED_MIN) * DAMAGE_PER_MPS * strength, 4.0, DAMAGE_MAX)
			_swing_start_dir = _dir
			_swing_travel = 0.0
			if npc_part != "":
				_npc_take_blade_part(npc_part, position, speed, hit.get("_velocity", Vector3.ZERO), npc_cut)
			else:
				_npc_take_blade(position, speed, hit.get("_velocity", Vector3.ZERO), npc_cut)
		return
	if is_target:
		var id: int = collider.get_instance_id()
		# One entry = one blow, and only a deliberately steered blade (LMB held,
		# past the arming delay) hurts anything. Carrying the sword, drawing it or
		# letting it rest against the dummy never removes health. A blade that
		# keeps resting on the target must first leave it again (rearm window).
		var armed: bool = _held and not _blocking and Time.get_ticks_msec() >= _arm_ready_ms
		var rearmed: bool = not _contact_gap.has(id) or now - int(_contact_gap[id]) >= CONTACT_REARM_MS
		if armed and rearmed and not _contact_prev.has(id):
			_damage_dummy(collider, position, speed, hit.get("_velocity", Vector3.ZERO), now)
		return
	# Wall/pole: the visible blade stops and slides along the surface instead
	# of passing through. Pulling the mouse back releases it immediately. The
	# clang and the sparks are rate-limited so resting on masonry stays quiet.
	var first_touch: bool = fresh
	if first_touch and now - _last_block_sound_ms >= BLOCK_SOUND_COOLDOWN_MS:
		_last_block_sound_ms = now
		_blocks += 1
		_impact_player.global_position = position
		_impact_player.pitch_scale = 1.15
		_impact_player.play()
	if first_touch and now - _last_spark_ms >= SPARK_COOLDOWN_MS:
		_last_spark_ms = now
		_show_spark(position)

## A blow is judged by HOW the edge arrives, not just how fast the point moves:
## a slice (motion across the blade axis) cuts at full strength, a stab (motion
## along the axis) is weaker, and sliding flat along the surface barely marks.
func _damage_dummy(dummy: StaticBody3D, position: Vector3, speed: float, velocity: Vector3, now: int) -> void:
	if _dummy_down: return
	var key := dummy.get_instance_id()
	if _hit_ms.has(key) and now - int(_hit_ms[key]) < CONTACT_COOLDOWN_MS: return
	var motion := velocity
	if motion.length_squared() < 1.0e-8: motion = _dir * speed
	var along := absf(motion.normalized().dot(_dir))
	var across := sqrt(maxf(0.0, 1.0 - along * along))
	# Blend from a pure stab to a clean slice; a flat slap stays near zero.
	var quality := clampf(across * 1.0 + along * 0.45, 0.0, 1.0)
	var effective := speed * quality
	var kind := "slice" if across >= 0.72 else ("stab" if along >= 0.72 else "flat")
	# Wind-up matters: a stroke that barely moved the blade stays a graze, while a
	# full wind-up followed by a cut lands far harder.
	var strength := clampf(SWING_STRENGTH_MIN + _swing_travel * SWING_STRENGTH_GAIN, SWING_STRENGTH_MIN, 2.0)
	if _active_side() == &"both": strength *= TWO_HAND_DAMAGE_SCALE
	_last_hit_kind = kind
	_last_hit_scale = strength
	var damage := clampf((effective * strength - DAMAGE_SPEED_MIN) * DAMAGE_PER_MPS, 0.0, DAMAGE_MAX)
	# A landed blow spends the wind-up; the next hit must be earned again.
	_swing_start_dir = _dir
	_swing_travel = 0.0
	_hit_ms[key] = now
	if damage <= 0.05:
		# A light or flat touch is felt but does not remove health.
		_impact_player.global_position = position
		_impact_player.pitch_scale = 1.45
		_impact_player.volume_db = -12.0
		_impact_player.play()
		_dummy_tilt = maxf(_dummy_tilt, 0.05)
		return
	_impact_player.volume_db = 0.0
	_impact_player.global_position = position
	# A slice rings higher and sharper than a stab.
	_impact_player.pitch_scale = (1.35 + randf() * 0.25) if kind == "slice" else (0.85 + randf() * 0.15)
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
	_spawn_damage_number(position, damage, kind)
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

func _spawn_damage_number(at: Vector3, damage: float, kind: String) -> void:
	var now := Time.get_ticks_msec()
	# Damage numbers are rate-limited and capped: a blade resting on a target can
	# otherwise spawn one label per frame and stall the frame rate.
	if now - _last_number_ms < DAMAGE_NUMBER_COOLDOWN_MS: return
	if _number_count >= DAMAGE_NUMBER_LIMIT: return
	_last_number_ms = now
	_number_count += 1
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 110
	label.pixel_size = 0.0032
	label.outline_size = 20
	label.modulate = Color(1.0, 0.35, 0.28) if kind == "slice" else Color(1.0, 0.72, 0.35)
	label.text = "-%d" % int(round(damage))
	label.position = at + Vector3.UP * 0.22
	_world.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector3.UP * 0.75, 0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(func() -> void:
		_number_count = maxi(0, _number_count - 1)
		label.queue_free())

# ------------------------------------------------------------------- reporting

## ------------------------------------------------------- resident swordsman
## The opponent is built exactly like a city resident: the SAME character model
## from the game's own prepared assets, driven by the SAME canonical walk gait
## (PreviewLocomotion) the population uses. He is dressed in plate armour, gets a
## sword in his right fist and is cut apart piece by piece.
const NpcCache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const NpcGait = preload("res://scripts/preview_locomotion.gd")
const NPC_MANIFEST := "res://assets/npc_visual/session/prepared/manifest.json"
const NPC_DIRECTORY := "res://assets/npc_visual/session/prepared"
const NPC_MANIFEST_SHA := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
const NPC_SOURCES := [
	{"bridge": "npc_resident_72", "descriptor": "fb812a2fc447726dd30548edb34805295ac28e6970c2ca55a6abb18a5a4c39bd"},
	{"bridge": "npc_resident_252", "descriptor": "63013b43b2210fd997d9a57fd8b1fa315312bd2ff3e1387e115f667e6db75b55"},
]
const NPC_HEIGHT := 1.9
var _npc_gait: RefCounted
var _npc_record: Dictionary = {}
var _npc_body: CharacterBody3D
var _npc_motion: Node3D
var _npc_rig: Skeleton3D
var _npc_sword: Node3D
var _npc_hand := -1
var _npc_clav := -1
var _npc_upper := -1
var _npc_fore := -1
var _npc_rest_upper := Transform3D.IDENTITY
var _npc_rest_fore := Transform3D.IDENTITY
var _npc_rest_hand := Transform3D.IDENTITY
var _npc_dir := Vector3.FORWARD
var _npc_state := "wait"
var _npc_timer := 0.0
var _npc_hp := 90.0
var _npc_engaged := false
var _npc_swings := 0
var _npc_hits := 0
var _npc_blocked := 0
var _npc_blade_prev: PackedVector3Array = PackedVector3Array()
var _npc_hit_ms := -10000
var _npc_blade_ms := -10000
## Deferred binding: the population host appears after the prototype.
var _npc_bind_timer := 0.0
var _npc_bind_attempts := 0

## Takes the nearest idle city resident and hands him a sword.
## ------------------------------------------------------------ knight armour
## Plate fitted to the bones themselves: every piece is authored in its own
## bone's frame, so it sits correctly on the body whatever the model scale is.
const STEEL := Color(0.70, 0.73, 0.78)
const STEEL_DARK := Color(0.30, 0.33, 0.38)
const MAIL := Color(0.20, 0.21, 0.24)
var _knight_armour: Array[Node3D] = []

func _dress_knight() -> void:
	if not is_instance_valid(_npc_rig): return
	_recolour_as_mail()
	var shoulder := 0.40
	var left := _npc_rig.find_bone("clavicle_l")
	var right := _npc_rig.find_bone("clavicle_r")
	if left >= 0 and right >= 0:
		shoulder = maxf(0.25, _npc_rig.get_bone_rest(left).origin.distance_to(_npc_rig.get_bone_rest(right).origin) * 0.62)
	# Helm with a raised visor and a crest.
	_fit_plate("head", "KnightHelm", [
		{"shape": "sphere", "along": 0.5, "radius": shoulder * 1.05, "offset": Vector3(0.0, 0.0, 0.0), "scale": Vector3(1.0, 1.05, 1.02), "color": STEEL},
		{"shape": "box", "along": 0.62, "radius": shoulder * 0.52, "offset": Vector3(0.0, 0.0, 0.30), "size": Vector3(0.52, 0.30, 0.34), "color": STEEL_DARK},
		{"shape": "box", "along": 0.62, "radius": shoulder * 0.52, "offset": Vector3(0.0, 0.10, -0.06), "size": Vector3(0.10, 0.34, 0.52), "color": STEEL},
	])
	# Breastplate, fauld and a gorget collar.
	_fit_plate("chest", "KnightBreastplate", [
		{"shape": "box", "along": 0.55, "radius": shoulder, "offset": Vector3(0.0, 0.0, 0.02), "size": Vector3(shoulder * 2.05, shoulder * 1.45, shoulder * 1.20), "color": STEEL},
		{"shape": "box", "along": 0.90, "radius": shoulder, "offset": Vector3(0.0, 0.0, 0.0), "size": Vector3(shoulder * 2.10, shoulder * 0.42, shoulder * 1.26), "color": STEEL_DARK},
		{"shape": "box", "along": 1.02, "radius": shoulder, "offset": Vector3(0.0, 0.0, 0.0), "size": Vector3(shoulder * 1.55, shoulder * 0.34, shoulder * 1.10), "color": STEEL},
	])
	# Pauldrons and vambraces on both arms.
	for bone_name: String in ["upperarm_l", "upperarm_r"]:
		var side := -1.0 if bone_name.ends_with("_l") else 1.0
		_fit_plate(bone_name, "KnightPauldron" + bone_name, [
			{"shape": "sphere", "along": 0.12, "radius": shoulder * 0.78, "offset": Vector3(side * shoulder * 0.22, 0.0, 0.0), "scale": Vector3(1.15, 0.85, 1.10), "color": STEEL},
		])
	for bone_name: String in ["forearm_l", "forearm_r"]:
		_fit_plate(bone_name, "KnightVambrace" + bone_name, [
			{"shape": "cylinder", "along": 0.5, "radius": shoulder * 0.48, "offset": Vector3.ZERO, "color": STEEL},
		])
	for bone_name: String in ["shin_l", "shin_r"]:
		_fit_plate(bone_name, "KnightGreave" + bone_name, [
			{"shape": "cylinder", "along": 0.45, "radius": shoulder * 0.52, "offset": Vector3(0.0, 0.0, shoulder * 0.06), "color": STEEL},
		])
	print("DSH_SWORD_PROTO_ARMOUR plates=", _knight_armour.size(), " shoulder=", shoulder)

## Paints the street clothes into dark mail so the plate reads as armour.
func _recolour_as_mail() -> void:
	var visual: Node = _npc_rig.get_parent()
	if visual == null: return
	var paint := StandardMaterial3D.new()
	paint.albedo_color = MAIL
	paint.metallic = 0.35
	paint.roughness = 0.55
	var count := 0
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var name := String(mesh.name)
		if name.begins_with("Knight") or name.begins_with("ResidentSword") or name.begins_with("KnightSword"): continue
		mesh.material_override = paint
		count += 1
	print("DSH_SWORD_PROTO_MAIL meshes=", count)

## Attaches one plate group to a bone. Distances are expressed as fractions of
## the bone length and of the shoulder width, so nothing is hard-coded to a model.
func _fit_plate(bone_name: String, label: String, parts: Array) -> void:
	var bone := _npc_rig.find_bone(bone_name)
	if bone < 0: return
	var anchor := BoneAttachment3D.new()
	anchor.name = label + "Anchor"
	anchor.bone_name = bone_name
	_npc_rig.add_child(anchor)
	var holder := Node3D.new()
	holder.name = label
	anchor.add_child(holder)
	var bone_len := maxf(0.12, _npc_rig.get_bone_rest(bone).origin.length())
	for part: Dictionary in parts:
		var node := MeshInstance3D.new()
		var radius := float(part.get("radius", 0.2))
		match String(part.get("shape", "box")):
			"sphere":
				var sphere := SphereMesh.new()
				sphere.radius = radius
				sphere.height = radius * 2.0
				sphere.radial_segments = 16
				sphere.rings = 8
				node.mesh = sphere
			"cylinder":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = radius
				cylinder.bottom_radius = radius * 1.05
				cylinder.height = bone_len * 0.9
				cylinder.radial_segments = 14
				node.mesh = cylinder
			_:
				var box := BoxMesh.new()
				box.size = part.get("size", Vector3(radius, radius, radius))
				node.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = part.get("color", STEEL)
		material.metallic = 0.92
		material.roughness = 0.18
		node.material_override = material
		var scale_value: Vector3 = part.get("scale", Vector3.ONE)
		node.scale = scale_value
		# Down the bone (its own +Y points at the child) plus a local offset.
		node.position = Vector3(0.0, bone_len * float(part.get("along", 0.5)), 0.0) + part.get("offset", Vector3.ZERO)
		holder.add_child(node)
	_knight_armour.append(holder)

## Per-bone hit boxes. One capsule for the whole body made every cut land on the
## torso, so arms and legs never took damage and never came off. Each limb now has
## its own tagged collider.
func _add_npc_hitboxes() -> void:
	if not is_instance_valid(_npc_rig): return
	# Everything here is in the rig's own bone units: the box is sized from the
	# bone's TRUE length (the offset to its child), so it wraps the limb whatever
	# the model scale is.
	var unit := 1.0
	var thigh := _npc_rig.find_bone("thigh_l")
	if thigh >= 0: unit = maxf(0.2, _bone_length(thigh))
	var limbs := ["head", "chest", "pelvis", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r",
		"hand_l", "hand_r", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]
	var count := 0
	for part: String in limbs:
		var bone := _npc_rig.find_bone(part)
		if bone < 0: continue
		var blen := _bone_length(bone)
		var radius := blen * 0.45
		var box_size := Vector3.ZERO
		var box_at := Vector3(0.0, blen * 0.5, 0.0)
		if part == "head":
			blen = unit * 0.55
			radius = unit * 0.32
			box_size = Vector3(radius * 2.1, blen * 1.15, radius * 2.1)
		elif part == "chest":
			# Torso: a big box centred on the chest bone, not a limb along it.
			box_size = Vector3(unit * 1.55, unit * 1.45, unit * 0.95)
			box_at = Vector3.ZERO
		elif part == "pelvis":
			box_size = Vector3(unit * 1.30, unit * 0.95, unit * 0.90)
			box_at = Vector3.ZERO
		elif part.begins_with("hand"):
			blen = maxf(blen, unit * 0.22)
			radius = blen * 0.5
			box_size = Vector3(radius * 2.1, blen * 1.15, radius * 2.1)
		elif part.begins_with("foot"):
			blen = maxf(blen, unit * 0.20)
			radius = blen * 0.5
			box_size = Vector3(radius * 2.1, blen * 1.15, radius * 2.1)
		else:
			if blen < 0.05 or radius < 0.03: continue
			box_size = Vector3(radius * 2.1, blen * 1.15, radius * 2.1)
		var anchor := BoneAttachment3D.new()
		anchor.name = "Hit" + part
		anchor.bone_name = part
		_npc_rig.add_child(anchor)
		# AnimatableBody3D, not StaticBody3D: a static body hung on a bone never
		# synced its transform with the physics server, so rays missed the limbs.
		var hit_body := AnimatableBody3D.new()
		hit_body.sync_to_physics = true
		hit_body.collision_layer = 1
		hit_body.collision_mask = 0
		hit_body.set_meta("sword_npc_part", part)
		var hit_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = box_size
		hit_shape.shape = box
		hit_shape.position = box_at
		hit_body.add_child(hit_shape)
		anchor.add_child(hit_body)
		count += 1
	print("DSH_SWORD_PROTO_HITBOXES parts=", count, " unit=", unit)

## Distance from a bone to its first child - the bone's real length, in rig units.
func _bone_length(bone: int) -> float:
	if not is_instance_valid(_npc_rig): return 0.0
	var count := _npc_rig.get_bone_count()
	for index: int in count:
		if _npc_rig.get_bone_parent(index) == bone:
			return _npc_rig.get_bone_rest(index).origin.length()
	return 0.0

## Damage a named part directly (used by the tagged limb hit boxes).
func _npc_take_blade_part(full_key: String, point: Vector3, speed: float, direction: Vector3, damage: float) -> void:
	if _npc_dead: return
	if _npc_severed.has(full_key): return
	var kind := full_key
	if full_key.ends_with("_l") or full_key.ends_with("_r"):
		kind = full_key.substr(0, full_key.length() - 2)
	if not _npc_part_hp.has(full_key):
		_npc_part_hp[full_key] = float(PART_HP.get(kind, 40.0))
	_npc_part_hp[full_key] = float(_npc_part_hp[full_key]) - maxf(4.0, damage)
	_npc_engaged = true
	if _npc_state == "wait":
		_npc_state = "approach"
		_npc_timer = 0.0
	_spray_blood(point, direction, 10 if damage < 20.0 else 24)
	# A wound keeps bleeding for a while, like a stream rather than one puff.
	_npc_bleed_until_ms = Time.get_ticks_msec() + 2600
	_npc_bleed_at = point
	if float(_npc_part_hp[full_key]) > 0.0: return
	# The torso cannot be taken off - a cut that empties it simply drops him.
	if kind in ["chest", "pelvis"]:
		_npc_dead = true
		_npc_disarmed = true
		_npc_engaged = false
		_npc_state = "wait"
		_spray_blood(point, direction, 60)
		_npc_bleed_until_ms = Time.get_ticks_msec() + 4000
		print("DSH_SWORD_PROTO_SEVER part=", full_key, " kind=cut_down")
		return
	_sever_part(full_key, kind, {"sever": full_key}, point, direction, speed)

## The wound keeps pouring for a few seconds instead of a single puff.
var _npc_bleed_until_ms := 0
var _npc_bleed_at := Vector3.ZERO
var _npc_bleed_accum := 0.0
## When he is cut down he topples over instead of standing there.
var _npc_fall := 0.0

## Runs the open wound: a steady stream of drops from the cut.
func _update_npc_bleed(delta: float) -> void:
	if not is_instance_valid(_npc_body): return
	var now := Time.get_ticks_msec()
	if _npc_dead and _npc_fall < 1.0:
		# Dead: fall over on the ground, physically.
		_npc_fall = minf(1.0, _npc_fall + delta * 1.6)
		var t := _npc_fall * _npc_fall
		_npc_motion.rotation.x = -PI * 0.5 * t
		var drop := _npc_body.global_position.y
		if _npc_fall >= 1.0:
			_npc_body.velocity = Vector3.ZERO
	if now > _npc_bleed_until_ms: return
	_npc_bleed_accum += delta
	if _npc_bleed_accum < 0.05: return
	_npc_bleed_accum = 0.0
	var drop_dir := Vector3(randf_range(-0.4, 0.4), -1.0, randf_range(-0.4, 0.4)).normalized()
	_spray_blood(_npc_bleed_at + Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06), randf_range(-0.06, 0.06)),
		drop_dir, 3)

## How much slower he moves with legs missing.
func _npc_speed_scale() -> float:
	var loss := 0.0
	for key: String in ["thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]:
		if _npc_severed.has(key): loss += 0.28
	return clampf(1.0 - loss, 0.18, 1.0)

## Builds the opponent from the game's own resident model and canonical walk gait.
func _spawn_resident_knight(at: Vector3) -> bool:
	if is_instance_valid(_npc_rig): return true
	var cache_bytes := FileAccess.get_file_as_bytes(NPC_MANIFEST)
	if cache_bytes.is_empty():
		print("DSH_SWORD_PROTO_NPC manifest_missing")
		return false
	var source: Dictionary = NPC_SOURCES[0]
	var loaded: Dictionary = NpcCache.load_verified(cache_bytes, NPC_MANIFEST_SHA, String(source.bridge), String(source.descriptor), NPC_DIRECTORY)
	if not loaded.get("ok", false):
		print("DSH_SWORD_PROTO_NPC load_failed ", loaded.get("error", ""))
		return false
	var cache: RefCounted = loaded.cache
	var appearance: Dictionary = cache.instantiate_actor()
	cache.dispose()
	if not appearance.get("ok", false):
		print("DSH_SWORD_PROTO_NPC appearance_failed ", appearance.get("error", ""))
		return false
	var body := CharacterBody3D.new()
	body.name = "SwordKnight"
	body.collision_layer = 1
	body.collision_mask = 1
	body.floor_snap_length = 0.25
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.36; capsule.height = NPC_HEIGHT
	var hull := CollisionShape3D.new(); hull.shape = capsule; hull.position.y = NPC_HEIGHT * 0.5
	body.add_child(hull)
	var motion := Node3D.new(); motion.name = "KnightMotion"
	body.add_child(motion)
	motion.add_child(appearance.visual)
	# Canonical forward +Z is converted to the native body heading once, the same
	# way the population host does it.
	motion.rotation.y = PI
	_world.add_child(body)
	body.global_position = at
	var gait: RefCounted = NpcGait.new()
	if not gait.bind(appearance.visual, motion, true):
		print("DSH_SWORD_PROTO_NPC gait_failed ", gait.get_status())
		body.queue_free()
		return false
	var rigs: Array[Node] = appearance.visual.find_children("*", "Skeleton3D", true, false)
	if rigs.size() != 1:
		print("DSH_SWORD_PROTO_NPC rig_count=", rigs.size())
		body.queue_free()
		return false
	_npc_body = body
	_npc_motion = motion
	_npc_gait = gait
	_npc_rig = rigs[0] as Skeleton3D
	_npc_clav = _npc_rig.find_bone("clavicle_r")
	_npc_upper = _npc_rig.find_bone("upperarm_r")
	_npc_fore = _npc_rig.find_bone("forearm_r")
	_npc_hand = _npc_rig.find_bone("hand_r")
	if _npc_hand < 0:
		print("DSH_SWORD_PROTO_NPC no_hand_r")
		return false
	_npc_rest_upper = _npc_rig.get_bone_rest(_npc_upper)
	_npc_rest_fore = _npc_rig.get_bone_rest(_npc_fore)
	_npc_rest_hand = _npc_rig.get_bone_rest(_npc_hand)
	_npc_sword = _build_sword_model(motion, "KnightSword")
	print("DSH_SWORD_PROTO_NPC spawned bones=", _npc_rig.get_bone_count(), " at=", at)
	_dress_knight()
	_add_npc_hitboxes()
	return true

## Poses the resident's sword arm and hangs the sword in that fist.
func _update_city_npc(delta: float) -> void:
	if not is_instance_valid(_npc_rig):
		# The model loads asynchronously, so he is picked up as soon as it is ready.
		_npc_bind_timer += delta
		if _npc_bind_timer >= 0.5 and _npc_bind_attempts < 20:
			_npc_bind_timer = 0.0
			_npc_bind_attempts += 1
			if _spawn_resident_knight(_grounded(_player.global_position + _player._visual.global_basis.z * 4.6)) \
				and is_instance_valid(_duelist):
				_duelist.visible = false
				_duelist_hull.set_meta("sword_duelist", false)
		return
	if not is_instance_valid(_npc_sword):
		# Disarmed (sword arm severed) or already cut down: he neither carries the
		# blade nor attacks, but he is still standing there.
		_npc_engaged = false
		_npc_body.velocity = Vector3.ZERO
		return
	_npc_sword.visible = _npc_hp > 0.0
	var to_player := _player.global_position - _npc_body.global_position
	to_player.y = 0.0
	var distance := to_player.length()
	# He faces the player and looks passive until the fight starts.
	if to_player.length_squared() > 1.0e-6:
		var want_yaw := atan2(to_player.x, to_player.z)
		_npc_body.rotation.y = lerp_angle(_npc_body.rotation.y, want_yaw + PI, clampf(4.0 * delta, 0.0, 1.0))
	# Wake up when the player swings at him from close range.
	if not _npc_engaged and _held and distance < 3.2:
		_npc_engaged = true
		_npc_state = "approach"
		print("DSH_SWORD_PROTO_NPC aggro distance=", distance)
	_npc_timer += delta
	_update_npc_bleed(delta)
	if _npc_dead:
		# Cut down: he is on the ground and no longer acts.
		_npc_engaged = false
		_npc_body.velocity = Vector3.ZERO
		_npc_body.move_and_slide()
		if _npc_gait != null:
			_npc_gait.update_pose(delta, Vector3.ZERO, _npc_body.is_on_floor())
		_apply_npc_severed()
		return
	var want := _npc_high_guard()
	var move := Vector3.ZERO
	var speed_scale := _npc_speed_scale()
	if _npc_engaged:
		# Walk in, wind up, cut - the walk animation plays because his own body is
		# actually moving, and the gait samples the horizontal velocity from it.
		match _npc_state:
			"approach":
				if distance > 1.25:
					move = to_player.normalized() * 1.9 * speed_scale
				if _npc_timer > 0.6:
					_npc_state = "windup"
					_npc_timer = 0.0
			"windup":
				want = _npc_high_guard()
				if _npc_timer > 0.5:
					_npc_state = "strike"
					_npc_timer = 0.0
					_npc_swings += 1
					_npc_blade_prev = PackedVector3Array()
			"strike":
				move = to_player.normalized() * 1.1 * speed_scale
				want = _npc_cut_direction()
				_npc_resolve_strike(delta)
				if _npc_timer > 0.22:
					_npc_state = "recover"
					_npc_timer = 0.0
			_:
				if _npc_timer > 0.7:
					_npc_state = "approach"
					_npc_timer = 0.0
		if _npc_hp <= 0.0:
			_npc_engaged = false
			_npc_state = "wait"
	# Gravity keeps him planted on the ground; without it he drifts through the air.
	_npc_body.velocity = move
	if _npc_body.is_on_floor():
		_npc_body.velocity.y = -0.5
	else:
		_npc_body.velocity.y -= 9.8 * delta
	_npc_body.move_and_slide()
	# The canonical walk gait plays FIRST, so his legs really step while he moves;
	# the sword arm is then written over it, exactly like the player's own arm.
	if _npc_gait != null:
		_npc_gait.update_pose(delta, _npc_body.velocity, _npc_body.is_on_floor())
	# Hidden limbs, re-cut every frame behind the gait.
	_apply_npc_severed()
	_npc_dir = _npc_dir.slerp(want, clampf(10.0 * delta, 0.0, 1.0)).normalized()
	if not _npc_severed.has("upperarm_r") and not _npc_severed.has("forearm_r") and not _npc_severed.has("hand_r"):
		_npc_pose_arm()
	var local := _npc_dir
	# The sword is held in the resident's own right hand, in world space.
	var fist: Vector3 = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(_npc_hand).origin
	if _npc_hp > 0.0:
		_npc_sword.global_transform = _place_basis(fist + local * GRIP_CENTER_OFFSET, local)

func _npc_high_guard() -> Vector3:
	return (Vector3.UP * 0.80 + _npc_body.global_basis.z * 0.45).normalized()

func _npc_cut_direction() -> Vector3:
	var to_player := (_player.global_position + Vector3.UP * 1.05) - _npc_body.global_position
	if to_player.length_squared() < 1.0e-6: return Vector3.FORWARD
	return to_player.normalized()

## Two-bone IK on the resident's rig: the same maths used for the player's arm.
func _npc_pose_arm() -> void:
	if _npc_clav < 0 or _npc_upper < 0 or _npc_fore < 0 or _npc_hand < 0: return
	var rig_basis: Basis = _npc_rig.global_transform.basis
	var dir_rig: Vector3 = (rig_basis.inverse() * _npc_dir).normalized()
	var clavicle_global := _npc_chain(_npc_clav)
	var joint := (clavicle_global * _npc_rest_upper).origin
	var l1 := _npc_rest_fore.origin.length()
	var l2 := _npc_rest_hand.origin.length()
	if l1 <= 0.01 or l2 <= 0.01: return
	var target := joint + dir_rig * (l1 + l2) * 0.94
	var to_target := target - joint
	var distance := to_target.length()
	if distance < 1.0e-4: return
	var direction := to_target.normalized()
	var d := clampf(distance, absf(l1 - l2) + 1.0e-3, l1 + l2 - 1.0e-3)
	var pole := Vector3(0.45, -0.55, -0.25)
	pole -= direction * pole.dot(direction)
	if pole.length_squared() < 1.0e-6: pole = direction.cross(Vector3.UP)
	pole = pole.normalized()
	var cos_angle := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var upper_dir := (Quaternion(pole.cross(direction).normalized(), -acos(cos_angle)) * direction).normalized()
	var elbow := joint + upper_dir * l1
	var fore_dir := (joint + direction * d - elbow).normalized()
	var upper_local := _npc_point_bone(_npc_upper, _npc_rest_upper, _npc_rest_fore.origin, clavicle_global.basis, upper_dir)
	var upper_global := clavicle_global * upper_local
	var fore_local := _npc_point_bone(_npc_fore, _npc_rest_fore, _npc_rest_hand.origin, upper_global.basis, fore_dir)
	var fore_global := upper_global * fore_local
	_npc_point_bone(_npc_hand, _npc_rest_hand, _npc_rest_hand.origin, fore_global.basis, dir_rig)

func _npc_point_bone(bone: int, rest: Transform3D, child_offset: Vector3, parent_basis: Basis, dir_rig: Vector3) -> Transform3D:
	var rest_dir := rest.basis * child_offset
	if rest_dir.length_squared() < 1.0e-10: rest_dir = rest.basis.y
	var local_dir := parent_basis.inverse() * dir_rig
	if local_dir.length_squared() < 1.0e-10: local_dir = rest_dir
	var turn := Quaternion(rest_dir.normalized(), local_dir.normalized())
	var local := Transform3D((Basis(turn) * rest.basis).orthonormalized(), rest.origin)
	_npc_rig.set_bone_pose(bone, local)
	return local

func _npc_chain(bone: int) -> Transform3D:
	var chain: Array[int] = []
	var index := bone
	while index >= 0:
		chain.push_front(index)
		index = _npc_rig.get_bone_parent(index)
	var result := Transform3D.IDENTITY
	for item: int in chain:
		result = result * _npc_rig.get_bone_pose(item)
	return result

func _npc_blade_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	var origin: Vector3 = _npc_sword.global_position
	var direction: Vector3 = _npc_sword.global_basis.x.normalized()
	for i: int in 5:
		points.append(origin + direction * (0.10 + BLADE_LENGTH * float(i) / 4.0))
	return points

## His cut: our blade stops it, otherwise it reaches the body.
func _npc_resolve_strike(delta: float) -> void:
	var points := _npc_blade_points()
	if _npc_blade_prev.size() != points.size():
		_npc_blade_prev = points
		return
	var space := _player.get_world_3d().direct_space_state
	for i: int in points.size():
		var from := _npc_blade_prev[i]
		var to := points[i]
		if from.distance_squared_to(to) < 1.0e-8: continue
		if _player_blade_intercepts(from, to):
			_npc_blocked += 1
			if now_ms() - _last_clash_ms >= 260:
				_register_clash((from + to) * 0.5)
			_npc_blade_prev = points
			return
		var query := PhysicsRayQueryParameters3D.create(from, to, 2)
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		if now_ms() - _npc_hit_ms < 400: continue
		_npc_hit_ms = now_ms()
		_npc_hits += 1
		_apply_player_damage(DUELIST_DAMAGE, hit.position, (to - from).normalized())
		_npc_blade_prev = points
		return
	# Reach fallback, same as the sparring dummy opponent.
	var to_player := (_player.global_position + Vector3.UP * 1.0) - _npc_body.global_position
	if to_player.length() <= BLADE_LENGTH + 0.8 and _npc_dir.dot(to_player.normalized()) > 0.70:
		var at := _player.global_position + Vector3.UP * 1.0
		if _player_blade_intercepts(_npc_body.global_position, at):
			_npc_blocked += 1
			if now_ms() - _last_clash_ms >= 260: _register_clash(at)
		elif now_ms() - _npc_hit_ms >= 400:
			_npc_hit_ms = now_ms()
			_npc_hits += 1
			_apply_player_damage(DUELIST_DAMAGE, at, to_player.normalized())
	_npc_blade_prev = points

## The player's blade damages the resident, which also wakes him up.
func _damage_npc(amount: float, position: Vector3, now: int) -> void:
	if _npc_hp <= 0.0: return
	_npc_hp = maxf(0.0, _npc_hp - amount)
	_npc_engaged = true
	if _npc_state == "wait":
		_npc_state = "approach"
		_npc_timer = 0.0
	_impact_player.global_position = position
	_impact_player.pitch_scale = 1.25
	_impact_player.play()
	_show_spark(position)

## True when the collider belongs to the resident we armed.
func _is_npc_collider(collider: Variant) -> bool:
	return is_instance_valid(_npc_body) and is_instance_valid(collider) \
		and (collider == _npc_body or _npc_body.is_ancestor_of(collider as Node))

## ------------------------------------------------------------- dismemberment
## The resident is cut apart piece by piece: every limb has its own health, and
## a limb that takes enough damage is taken off - the mesh really disappears, the
## wound bleeds, a physical stump is thrown, and a severed sword arm can no longer
## hold the weapon.
const PART_HP := {"head": 55.0, "chest": 110.0, "pelvis": 110.0,
	"upperarm": 42.0, "forearm": 34.0, "hand": 24.0,
	"thigh": 55.0, "shin": 42.0, "foot": 26.0}
const BLOOD_LIFETIME := 2.6
## Severed pieces are permanent; the cap only stops unbounded growth.
const MAX_STUMPS := 48
var _stump_count := 0
var _stumps: Array[Node3D] = []
var _npc_part_hp: Dictionary = {}
var _npc_severed: Dictionary = {}
var _npc_gore: Array[Node3D] = []
var _npc_disarmed := false
var _npc_dead := false

## Which body part sits closest to the wound.
func _npc_part_at(point: Vector3) -> Dictionary:
	var best := {"key": "chest", "bone": -1, "distance": 1.0e9, "sever": ""}
	var probes := {
		"head": ["head", "neck"],
		"chest": ["chest", "spine_01"],
		"pelvis": ["pelvis"],
		"upperarm": ["upperarm_r", "upperarm_l"],
		"forearm": ["forearm_r", "forearm_l"],
		"hand": ["hand_r", "hand_l"],
		"thigh": ["thigh_r", "thigh_l"],
		"shin": ["shin_r", "shin_l"],
		"foot": ["foot_r", "foot_l"],
	}
	for part: String in probes.keys():
		for bone_name: String in probes[part]:
			var bone := _npc_rig.find_bone(bone_name)
			if bone < 0: continue
			var at: Vector3 = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(bone).origin
			var distance := at.distance_to(point)
			if distance < best.distance:
				best = {"key": part, "bone": bone, "distance": distance, "sever": bone_name}
	return best

## Blade lands on the resident: damage the part, and cut it off when it gives out.
func _npc_take_blade(point: Vector3, speed: float, direction: Vector3, damage: float) -> void:
	if _npc_dead: return
	var part := _npc_part_at(point)
	var key: String = part.key
	var side_suffix := ""
	if String(part.sever).ends_with("_r"): side_suffix = "_r"
	elif String(part.sever).ends_with("_l"): side_suffix = "_l"
	var full_key := key + side_suffix if key not in ["head", "chest", "pelvis"] else key
	if _npc_severed.has(full_key): return
	if not _npc_part_hp.has(full_key):
		_npc_part_hp[full_key] = float(PART_HP.get(key, 40.0))
	_npc_part_hp[full_key] = float(_npc_part_hp[full_key]) - maxf(4.0, damage)
	_npc_engaged = true
	if _npc_state == "wait":
		_npc_state = "approach"
		_npc_timer = 0.0
	_spray_blood(point, direction, 8 if damage < 20.0 else 16)
	if float(_npc_part_hp[full_key]) > 0.0: return
	_sever_part(full_key, key, part, point, direction, speed)

## Takes the limb off: the mesh vanishes, the stump bleeds, a chunk is thrown.
func _sever_part(full_key: String, kind: String, part: Dictionary, point: Vector3, direction: Vector3, speed: float) -> void:
	_npc_severed[full_key] = true
	_hide_limb(full_key, kind, String(part.sever))
	_spray_blood(point, direction, 34)
	_throw_stump(kind, point, direction, speed)
	_impact_player.global_position = point
	_impact_player.pitch_scale = 0.65
	_impact_player.play()
	# Losing the sword arm means losing the sword.
	if kind in ["upperarm", "forearm", "hand"] and full_key.ends_with("_r"):
		_npc_disarmed = true
		_npc_engaged = false
		_npc_state = "wait"
		if is_instance_valid(_npc_sword):
			_drop_sword(_npc_sword.global_position, direction, speed)
	if kind == "head":
		_npc_dead = true
		_npc_disarmed = true
		_npc_engaged = false
	print("DSH_SWORD_PROTO_SEVER part=", full_key, " kind=", kind, " disarmed=", _npc_disarmed)

## Collapses the bones of that limb (and everything under them) to nothing.
func _hide_limb(full_key: String, kind: String, bone_name: String) -> void:
	var bones: Array[String] = []
	match kind:
		"head": bones = ["head", "neck"]
		"upperarm": bones = [bone_name]
		"forearm": bones = [bone_name]
		"hand": bones = [bone_name]
		"thigh": bones = [bone_name]
		"shin": bones = [bone_name]
		"foot": bones = [bone_name]
	for name: String in bones:
		var bone := _npc_rig.find_bone(name)
		if bone < 0: continue
		var pose := _npc_rig.get_bone_pose(bone)
		_npc_rig.set_bone_pose(bone, Transform3D(Basis.IDENTITY.scaled(Vector3(0.001, 0.001, 0.001)), pose.origin))

## Re-hides every severed limb. Called every frame right after the walk gait,
## which rewrites all bones and would otherwise put the limb straight back on.
func _apply_npc_severed() -> void:
	if _npc_severed.is_empty() or not is_instance_valid(_npc_rig): return
	for full_key: String in _npc_severed.keys():
		var kind := full_key
		if full_key.ends_with("_l") or full_key.ends_with("_r"):
			kind = full_key.substr(0, full_key.length() - 2)
		var bones: Array[String] = []
		match kind:
			"head": bones = ["head", "neck"]
			"upperarm", "forearm", "hand", "thigh", "shin", "foot": bones = [full_key]
			_: bones = []
		for name: String in bones:
			var bone := _npc_rig.find_bone(name)
			if bone < 0: continue
			var pose := _npc_rig.get_bone_pose(bone)
			_npc_rig.set_bone_pose(bone, Transform3D(Basis.IDENTITY.scaled(Vector3(0.001, 0.001, 0.001)), pose.origin))

## A short burst of blood drops that fall and fade.
func _spray_blood(at: Vector3, direction: Vector3, count: int) -> void:
	# A hard cap keeps a long fight from drowning the scene in drop nodes.
	if _blood_count >= MAX_BLOOD:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.012, 0.018)
	mat.roughness = 0.35
	for i: int in count:
		if _blood_count >= MAX_BLOOD: return
		var drop := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = randf_range(0.020, 0.050)
		sphere.height = sphere.radius * 2.0
		drop.mesh = sphere
		drop.material_override = mat
		_world.add_child(drop)
		drop.global_position = at + Vector3(randf_range(-0.07, 0.07), randf_range(-0.05, 0.09), randf_range(-0.07, 0.07))
		var spread := Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 1.4), randf_range(-1.0, 1.0))
		var velocity := (direction.normalized() * randf_range(1.6, 4.2) + spread * 1.1)
		_npc_gore.append(drop)
		_blood_velocities.append(velocity)
		_blood_timers.append(BLOOD_LIFETIME)
		_blood_count += 1

var _blood_velocities: Array[Vector3] = []
var _blood_timers: Array[float] = []
var _blood_count := 0
## Most live blood drops at once.
const MAX_BLOOD := 260

## A real piece of the body, thrown where the limb used to be: the shape follows
## the part that came off (arm, leg, head with helm) and the cut end is bloody.
func _throw_stump(kind: String, at: Vector3, direction: Vector3, speed: float) -> void:
	var body := RigidBody3D.new()
	body.mass = 1.2
	body.gravity_scale = 1.35
	# A separate layer keeps the player from bumping into severed pieces, while
	# mask 1 still lets them fall and roll on the real ground.
	body.collision_layer = 128
	body.collision_mask = 1
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.78, 0.62, 0.49)
	skin.roughness = 0.62
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = MAIL
	cloth.roughness = 0.6
	var plate := StandardMaterial3D.new()
	plate.albedo_color = STEEL
	plate.metallic = 0.9
	plate.roughness = 0.22
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.45, 0.03, 0.035)
	flesh.roughness = 0.4
	var length := 0.34
	var radius := 0.09
	var material: Material = cloth
	match kind:
		"upperarm": length = 0.34; radius = 0.10; material = cloth
		"forearm": length = 0.30; radius = 0.08; material = cloth
		"hand": length = 0.17; radius = 0.08; material = skin
		"thigh": length = 0.44; radius = 0.12; material = cloth
		"shin": length = 0.40; radius = 0.10; material = cloth
		"foot": length = 0.14; radius = 0.10; material = cloth
		"head": length = 0.24; radius = 0.13; material = skin
	# One ArrayMesh with one surface per material: a single MeshInstance3D instead
	# of a stack of nodes, which is what keeps many pieces cheap.
	var mesh := ArrayMesh.new()
	if kind == "head":
		_add_stump_surface(mesh, true, radius, Vector3.ZERO, skin)
		_add_stump_surface(mesh, true, radius * 1.02, Vector3(0.0, 0.05, 0.0), plate)
		_add_stump_surface(mesh, false, radius * 0.62, Vector3(0.0, -length * 0.5, 0.0), flesh, 0.06)
	else:
		_add_stump_surface(mesh, false, radius, Vector3.ZERO, material, length)
		_add_stump_surface(mesh, false, radius * 1.04, Vector3(0.0, -length * 0.5, 0.0), flesh, 0.05)
		if kind in ["forearm", "hand", "shin", "foot"]:
			_add_stump_surface(mesh, true, radius * 0.95, Vector3(0.0, length * 0.5, 0.0), skin)
	var visual := MeshInstance3D.new()
	visual.name = "Piece"
	visual.mesh = mesh
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(radius * 2.2, length)
	shape.shape = capsule
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = at
	body.linear_velocity = direction.normalized() * clampf(speed * 0.35, 1.0, 4.5) + Vector3.UP * 1.1
	body.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	_npc_gore.append(body)
	# Severed pieces are left lying on the ground for good; only a hard cap keeps
	# the scene bounded.
	_stumps.append(body)
	_stump_count += 1
	if _stumps.size() > MAX_STUMPS:
		var oldest: Node3D = _stumps.pop_front()
		if is_instance_valid(oldest): oldest.queue_free()
		_stump_count = _stumps.size()

## Appends one primitive (sphere or a length-sized cylinder) as its own surface.
func _add_stump_surface(mesh: ArrayMesh, is_sphere: bool, radius: float, at: Vector3, material: Material, height: float = 0.0) -> void:
	var prim: Mesh
	if is_sphere:
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		prim = sphere
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = height if height > 0.0 else radius * 2.0
		cylinder.radial_segments = 12
		prim = cylinder
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	st.append_from(prim, 0, Transform3D(Basis.IDENTITY, at))
	st.commit(mesh)

func _drop_sword(at: Vector3, direction: Vector3, speed: float) -> void:
	if not is_instance_valid(_npc_sword): return
	var falling: Node3D = _npc_sword
	_npc_sword = null
	var body := RigidBody3D.new()
	body.mass = 1.2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(1.3, 0.1, 0.1)
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = at
	var visual := falling
	visual.get_parent().remove_child(visual)
	body.add_child(visual)
	visual.transform = Transform3D.IDENTITY
	body.linear_velocity = direction.normalized() * clampf(speed * 0.3, 0.8, 3.0) + Vector3.UP * 0.6
	body.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))

## Blood drops fall, and everything gore-related is cleaned up over time.
func _update_gore(delta: float) -> void:
	var index := 0
	while index < _npc_gore.size():
		var node: Node3D = _npc_gore[index]
		if not is_instance_valid(node):
			_npc_gore.remove_at(index)
			if index < _blood_velocities.size():
				_blood_velocities.remove_at(index)
				_blood_timers.remove_at(index)
				_blood_count = maxi(0, _blood_count - 1)
			continue
		if index < _blood_velocities.size():
			var velocity: Vector3 = _blood_velocities[index] - Vector3.UP * 9.0 * delta
			_blood_velocities[index] = velocity
			_blood_timers[index] -= delta
			if node is MeshInstance3D:
				node.global_position += velocity * delta
				if _blood_timers[index] <= 0.0:
					node.queue_free()
					_npc_gore.remove_at(index)
					_blood_velocities.remove_at(index)
					_blood_timers.remove_at(index)
					_blood_count = maxi(0, _blood_count - 1)
					continue
		index += 1

## Walking into a severed piece kicks it along the ground. The pieces live on
## their own layer so they never block the player, but a real nudge still rolls
## them, which is what a body part on the floor should do.
func _update_stumps(delta: float) -> void:
	if not is_instance_valid(_player) or _stumps.is_empty(): return
	var player_pos: Vector3 = _player.global_position + Vector3.UP * 0.45
	for index: int in range(_stumps.size() - 1, -1, -1):
		var body: Node3D = _stumps[index]
		if not is_instance_valid(body):
			_stumps.remove_at(index)
			continue
		if not body is RigidBody3D: continue
		var to_body := body.global_position - player_pos
		var distance := to_body.length()
		if distance > 1.05 or distance < 0.02: continue
		var push := (to_body / distance) * (1.05 - distance) * 0.16
		push.y = 0.0
		(body as RigidBody3D).apply_central_impulse(push)
		(body as RigidBody3D).apply_torque_impulse(Vector3(0.0, push.x * 2.0, 0.0) + Vector3(push.z * 2.0, 0.0, 0.0))

func snapshot() -> Dictionary:
	return {
		"ready": _ready, "held": _held, "hits": _hits, "blocks": _blocks,
		"dummy_hp": _dummy_hp, "dummy_down": _dummy_down, "max_damage": _max_damage,
		"hand": [_hand.x, _hand.y], "direction": [_dir.x, _dir.y, _dir.z],
		"body_yaw": _body_yaw, "body_pitch": _body_lean.x, "body_roll": _body_lean.y,
		"body_push": _body_push.length(), "omega": _omega.length(), "thrust": _thrust,
		"last_hit_kind": _last_hit_kind, "contact_now": _contact_prev.size(),
		"swing_travel": _swing_travel, "hit_scale": _last_hit_scale,
		"two_handed": _active_side() == &"both", "left_hand_error": _left_hand_error,
		"hand_side": str(_active_side()),
		"duelist_state": _duelist_state, "duelist_hp": _duelist_hp, "duelist_swings": _duelist_swings,
		"duelist_engaged": _duelist_engaged,
		"npc_bound": is_instance_valid(_npc_rig), "npc_hp": _npc_hp, "npc_state": _npc_state,
		"npc_engaged": _npc_engaged, "npc_swings": _npc_swings, "npc_hits": _npc_hits,
		"npc_blocked": _npc_blocked, "npc_sword": _npc_sword.global_position if is_instance_valid(_npc_sword) else Vector3.ZERO,
		"player_severed": _player_severed.keys(), "player_disarmed": _player_disarmed,
		"has_sword": is_instance_valid(_sword),
		"npc_severed": _npc_severed.keys(), "npc_disarmed": _npc_disarmed, "npc_dead": _npc_dead,
		"npc_part_hp": _npc_part_hp.duplicate(),
		"npc_position": _npc_body.global_position if is_instance_valid(_npc_body) else Vector3.ZERO,
		"grip_hand_error": _grip_hand_error,
		"armour_plates": _knight_armour.size(), "stump_count": _stumps.size(),
		"bleeding": Time.get_ticks_msec() < _npc_bleed_until_ms,
		"npc_fall": _npc_fall, "npc_speed_scale": _npc_speed_scale(),
		"clav_l_x": (_rig.global_transform * _chain_global(_bone_l_clavicle).origin).x if _bone_l_clavicle >= 0 else 0.0,
		"clav_r_x": (_rig.global_transform * _chain_global(_bone_clavicle).origin).x if _bone_clavicle >= 0 else 0.0,
		"uparm_l_x": (_rig.global_transform * _chain_global(_bone_l_upper).origin).x if _bone_l_upper >= 0 else 0.0,
		"uparm_r_x": (_rig.global_transform * _chain_global(_bone_upper).origin).x if _bone_upper >= 0 else 0.0,
		"grip_x": _sword_origin.x,
		"left_is_l_named": _left_is_l_named,
		"visual_fwd": _player._visual.global_basis.z if is_instance_valid(_player) and is_instance_valid(_player._visual) else Vector3.ZERO,
		"hold_left": _hold_left, "hold_right": _hold_right, "carry_side": str(_carry_side),
		"duelist_hits": _duelist_hits, "duelist_blocked": _duelist_blocked, "player_blocks": _player_blocks,
		"sparring_hp": _sparring_hp,
		"duelist_position": _duelist.global_position if is_instance_valid(_duelist) else Vector3.ZERO,
		"blade_from": _sword_origin, "blade_to": _sword_origin + _dir * (0.06 + BLADE_LENGTH),
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
	if is_instance_valid(_player):
		_player.set("_sword_lock", false)
		if _player.get("_sword_host") == self: _player.set("_sword_host", null)
	_release_arm()
	set_physics_process(false)
	set_process_input(false)
