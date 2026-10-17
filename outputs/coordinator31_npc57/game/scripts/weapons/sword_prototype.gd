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

## DSH_GORE: the planar severer, preloaded because its class_name is not registered in
## a fresh run of this script.
const MeshSever = preload("res://scripts/weapons/mesh_sever.gd")

## DSH_MELEE_SET: the weapon table. Every melee weapon in the set is one entry here,
## so the proven mechanics - the sweep, the contacts, the gore, drop and pickup - are
## shared instead of copied five times.
##
##   length  the weapon's reach from the fist, in metres
##   mass    swing lag: 1.0 is the sword's feel, higher is heavier and slower
##   grip    "one" | "two" | "both_optional"
##   slice   damage multiplier for an edge drawn across the target
##   stab    damage multiplier for the point driven in
##   flat    damage multiplier for a blow laid on flat
##   crush   true for blunt weapons: they do NOT get stopped by plate, they dent it
##   category  how the arsenal groups it
const WEAPONS := {
	"sword": {
		"label": "Тестовый меч (прототип)", "category": "blade", "category_label": "МЕЧ · БЛИЖНИЙ БОЙ",
		"length": 1.15, "mass": 1.0, "grip": "both_optional",
		"slice": 1.0, "stab": 1.0, "flat": 1.0, "crush": false,
	},
	"mace": {
		"label": "Булава (прототип)", "category": "one_hand", "category_label": "БУЛАВА · ОДНОРУЧНОЕ",
		"length": 0.60, "mass": 1.45, "grip": "one",
		"slice": 0.22, "stab": 0.12, "flat": 1.05, "crush": true,
	},
	"axe": {
		"label": "Двуручный топор (прототип)", "category": "two_hand", "category_label": "ТОПОР · ДВУРУЧНОЕ",
		"length": 1.05, "mass": 2.0, "grip": "two",
		"slice": 1.45, "stab": 0.22, "flat": 0.55, "crush": false,
	},
	"sledge": {
		"label": "Кувалда (прототип)", "category": "two_hand", "category_label": "КУВАЛДА · ДВУРУЧНОЕ",
		"length": 0.92, "mass": 2.7, "grip": "two",
		"slice": 0.18, "stab": 0.10, "flat": 1.6, "crush": true,
	},
	"spear": {
		"label": "Копьё (прототип)", "category": "polearm", "category_label": "КОПЬЁ · КОЛЮЩЕЕ",
		"length": 1.95, "mass": 1.15, "grip": "two",
		"slice": 0.15, "stab": 1.9, "flat": 0.15, "crush": false, "throwable": true,
	},
}
## The weapon this host is currently presenting.
var _weapon_id := "sword"

func weapon_ids() -> Array:
	return WEAPONS.keys()

func set_weapon(id: String) -> bool:
	if not WEAPONS.has(id) or id == _weapon_id: return WEAPONS.has(id)
	_weapon_id = id
	var entry: Dictionary = WEAPONS[id]
	_weapon_length = float(entry.get("length", 1.15))
	_weapon_mass = maxf(0.4, float(entry.get("mass", 1.0)))
	_weapon_crush = bool(entry.get("crush", false))
	# DSH_MELEE_SET: models are CACHED, never rebuilt on equip. Rebuilding took a whole
	# frame (measured at 105 ms on the axe), which is the hitch that felt like a freeze
	# when choosing a weapon. A weapon is built the first time it is needed and then
	# only shown or hidden.
	var model: Node3D = _weapon_models.get(id)
	if not is_instance_valid(model):
		model = _build_weapon_model(_world, id)
		_weapon_models[id] = model
	for other: String in _weapon_models.keys():
		var node: Node3D = _weapon_models[other]
		if is_instance_valid(node): node.visible = (other == id)
	_sword = model
	if is_instance_valid(_sword): _sword.visible = true
	if is_instance_valid(_hint): _update_hint()
	return true

## One model per weapon of the set, built once and kept.
var _weapon_models: Dictionary = {}

## The current weapon's entry.
func weapon_entry() -> Dictionary:
	return WEAPONS.get(_weapon_id, WEAPONS["sword"])

## Damage multiplier of the current weapon for a blow of this kind.
func _kind_multiplier(kind: String) -> float:
	var entry := weapon_entry()
	match kind:
		"slice": return float(entry.get("slice", 1.0))
		"stab": return float(entry.get("stab", 1.0))
		_: return float(entry.get("flat", 1.0))

var _weapon_length := 1.15
var _weapon_mass := 1.0
var _weapon_crush := false
## Distance from the model origin to the middle of the grip along the blade axis.
## The fist closes on this point, so the handle (not the guard) sits in the hand.
const GRIP_CENTER_OFFSET := 0.0625
const SWEEP_SEGMENTS := 9
const MOUSE_TO_HAND := 0.0031
## The commanded hand offset cannot jump: it is slewed toward the mouse command
## at a bounded rate, which is what keeps a fast mouse flick from snapping the
## whole arm (and the blade with it) across the body.
const HAND_SLEW_RATE := 10.5    # units per second
const HAND_MAX_OFFSET := 1.5
# A decisive cut, not a blur. 22 rad/s was three and a half turns a second, which is
# why a flick of the wrist read as an instant cut with no weight behind it.
const MAX_OMEGA := 12.5         # rad/s
const MAX_ALPHA := 68.0         # rad/s^2, quick but not a teleport into the swing
## Steering: high gain so a flick really whips the blade, light damping and light
## target smoothing. Heavy damping here is what turned cuts into brush strokes.
const STEER_GAIN := 8.5
const STEER_DAMPING := 0.20
const STEER_DEADZONE := 0.25
const STEER_ANGLE_DEADZONE := 0.04
const STEER_TARGET_SMOOTH := 45.0
const MOUSE_NOISE_FLOOR := 1.2
## The most a single mouse event is allowed to move the blade target. A violent flick
## is damped instead of teleporting the blade: the arm has to TRAVEL to the cut.
const MOUSE_PER_EVENT_CAP := 24.0
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
const BODY_YAW_LIMIT := 0.50
## During a live cut the torso turns much further than while guarding, so the
## body visibly drives the swing.
const BODY_YAW_SHARE_SWING := 0.48
const BODY_YAW_LIMIT_SWING := 0.70
const DAMAGE_SPEED_MIN := 1.50  # m/s below which a touch deals no damage
const DAMAGE_PER_MPS := 9.0
const DAMAGE_MAX := 34.0
## Wind-up is what makes a blow strong. It counts the ANGLE the blade turned, and
## how DECISIVELY it turned: a slow wave of the mouse earns almost nothing, so
## flailing around the desk is not a strategy, while one committed wind-up behind a
## cut is. Sensitivity is still irrelevant - only angles and time are used.
const MAX_SWING_TRAVEL := 2.4
const SWING_STRENGTH_MIN := 0.20
const SWING_STRENGTH_GAIN := 0.95
const SWING_STRENGTH_MAX := 2.6
## Wind-up speed (rad/s) that counts as fully decisive.
const WINDUP_RATE_IDEAL := 6.0
const WINDUP_DECISION_FLOOR := 0.30
const CONTACT_COOLDOWN_MS := 700
## A blow only counts after the blade actually left the target for this long.
## Without it, a blade resting on the ground or wobbling against the dummy fires
## a fresh "entry" every frame and floods damage, sounds and damage numbers.
const CONTACT_REARM_MS := 175
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
var _bone_thigh_r := -1
var _bone_shin_r := -1
var _bone_thigh_l := -1
var _bone_shin_l := -1
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
## Flying sparks from blade-on-blade clashes: one entry per live streak.
var _sparks: Array[Dictionary] = []
var _spark_mesh: BoxMesh
var _spark_material: StandardMaterial3D
var _spark_mesh_instance: BoxMesh
## Hard cap on live sparks.
const MAX_SPARKS := 140
## Total sparks thrown since the prototype started, so a test can prove the bursts
## really happened even though the streaks themselves live a third of a second.
var _sparks_total := 0
var _last_block_sound_ms := -1000
var _last_number_ms := -1000
var _ground_touch_ms := -10000
var _number_count := 0
## Blade travel accumulated during the current wind-up: a swipe that stroked the
## target barely counts, a full wind-up followed by a cut hits much harder.
var _swing_travel := 0.0
## Blade direction when the current swing began, and the previous held state.
var _swing_start_dir := Vector3.ZERO
## When the current swing began, so the wind-up can be judged for decisiveness.
var _swing_start_ms := 0
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

## Strength of the blow about to land. It grows with the wind-up ANGLE and with how
## DECISIVELY that angle was taken, so one committed wind-up behind a cut is strong
## while slowly waving the mouse around earns almost nothing.
func _strength_now() -> float:
	var angle := _windup_angle()
	var seconds := maxf(0.06, float(Time.get_ticks_msec() - _swing_start_ms) * 0.001)
	var rate := angle / seconds
	var decisiveness := clampf(rate / WINDUP_RATE_IDEAL, WINDUP_DECISION_FLOOR, 1.0)
	return clampf(SWING_STRENGTH_MIN + angle * SWING_STRENGTH_GAIN * decisiveness,
		SWING_STRENGTH_MIN, SWING_STRENGTH_MAX)
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
	# DSH_ANIM: the stance. The front leg is the one OPPOSITE the weapon hand, which is
	# how a swordsman stands; it takes the weight while the back leg drives.
	_bone_thigh_r = rig.find_bone("thigh_r")
	_bone_shin_r = rig.find_bone("shin_r")
	_bone_thigh_l = rig.find_bone("thigh_l")
	_bone_shin_l = rig.find_bone("shin_l")
	# The stance: the FRONT leg is the one opposite the weapon hand, which is how a
	# swordsman stands. The rig is mirrored on screen, so "opposite" is resolved from
	# the side the weapon is actually carried on.
	var weapon_on_left: bool = _carry_side == &"left"
	_bone_thigh_front = _bone_thigh_r if weapon_on_left else _bone_thigh_l
	_bone_shin_front = _bone_shin_r if weapon_on_left else _bone_shin_l
	_bone_thigh_back = _bone_thigh_l if weapon_on_left else _bone_thigh_r
	_bone_shin_back = _bone_shin_l if weapon_on_left else _bone_shin_r
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
	# DSH_MELEE_SET: every weapon of the set is built NOW, at install time, so choosing
	# one never pays for building it. The cost of a first equip that was measured at
	# about 105 ms - long enough to feel like a freeze - is paid once, at load.
	for weapon_id: String in WEAPONS.keys():
		var model: Node3D = _build_weapon_model(_world, weapon_id)
		model.visible = (weapon_id == _weapon_id)
		_weapon_models[weapon_id] = model
	_sword = _weapon_models.get(_weapon_id)
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

## DSH_MELEE_SET: the SHIELD - worn in the second hand, raised with the right button.
##
## It is not a magic "block": it covers a real piece of space around its own boss,
## anything that lands inside that space is stopped outright, and the shield wears with
## every blow it takes. As it is beaten down its coverage SHRINKS, so a battered shield
## stops protecting the shoulder and the ribs and finally only the centre.
const SHIELD_MAX_HP := 130.0
const SHIELD_RADIUS := 0.62        ## coverage radius with a fresh shield, fully raised
const SHIELD_WEAR_SCALE := 1.0     ## shield HP lost per point of incoming damage
const SHIELD_RAISE_RATE := 9.0
const SHIELD_RAISE_NEEDED := 0.55  ## below this the shield is still coming up
var _shield_hp := SHIELD_MAX_HP
var _shield_worn := false
var _shield_broken := false
var _shield_raise := 0.0
var _shield: Node3D
var _shield_blocks_total := 0
var _shield_absorbed := 0.0
var _bone_shield_hand := -1

## The shield is worn on the RIGHT hand, as asked. On this mirrored rig `_arm_set` maps
## the string "right" to the bones that RENDER on the character's right.
func _shield_side() -> StringName:
	return &"right"

## One hand cannot hold a weapon and a shield at once, so while the shield is worn the
## weapon is carried in the other hand.
func _carry_side_effective() -> StringName:
	if _shield_worn and _carry_side == &"right": return &"left"
	return _carry_side

## How much space the shield covers right now: it grows as it comes up and shrinks as it
## is beaten down.
func _shield_coverage() -> float:
	if _shield_broken: return 0.0
	var health := clampf(_shield_hp / SHIELD_MAX_HP, 0.0, 1.0)
	return SHIELD_RADIUS * lerpf(0.42, 1.0, health) * lerpf(0.45, 1.0, _shield_raise)

## The shield's covering point in world space: where its boss sits.
func _shield_centre() -> Vector3:
	if is_instance_valid(_shield): return _shield.global_position
	var arm := _arm_set(_shield_side())
	if is_instance_valid(_rig) and arm.hand >= 0:
		return (_rig.global_transform * _rig.get_bone_global_pose(int(arm.hand))).origin
	return _player.global_position + Vector3.UP * 1.2

## A blow landing inside the shield is stopped by it, not by the body.
func _shield_blocks(at: Vector3) -> bool:
	if not _shield_worn or _shield_broken or _shield_raise < SHIELD_RAISE_NEEDED: return false
	return _shield_centre().distance_to(at) <= _shield_coverage()

## Takes the wear of a stopped blow. Returns true when the shield has just failed.
func _shield_take_blow(amount: float) -> bool:
	var wear := maxf(1.0, amount * SHIELD_WEAR_SCALE)
	_shield_hp = maxf(0.0, _shield_hp - wear)
	_shield_blocks_total += 1
	_shield_absorbed += amount
	if _shield_hp <= 0.0 and not _shield_broken:
		_shield_broken = true
		return true
	return false

## Builds the shield: planks, a steel rim, a central boss and two straps, curved so it
## is a shape rather than a plank.
func _build_shield_model(parent: Node3D) -> Node3D:
	_weapon_materials()
	var shield := Node3D.new()
	shield.name = "PrototypeShield"
	parent.add_child(shield)
	var plank := StandardMaterial3D.new()
	plank.albedo_color = Color(0.46, 0.30, 0.16)
	plank.roughness = 0.82
	var face := StandardMaterial3D.new()
	face.albedo_color = Color(0.52, 0.36, 0.20)
	face.roughness = 0.78
	# The face is a heater shape: wide at the top, drawn to a point at the bottom.
	# It is built from a few tapering boxes so it reads as a real shield from the front.
	var widths := [0.66, 0.62, 0.54, 0.42, 0.26]
	var heights := 0.16
	for i: int in widths.size():
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(float(widths[i]), heights, 0.055)
		slab.mesh = box
		slab.material_override = plank if i % 2 == 0 else face
		# Slight curve: the middle of the shield sits forward of its edges.
		var curve := 0.03 * (1.0 - absf(float(i) - 2.0) / 2.0)
		slab.position = Vector3(0.0, 0.34 - float(i) * heights, curve)
		shield.add_child(slab)
	# Steel rim down both edges and across the top.
	for side: float in [-1.0, 1.0]:
		var rim := MeshInstance3D.new()
		var rim_mesh := BoxMesh.new()
		rim_mesh.size = Vector3(0.035, 0.80, 0.075)
		rim.mesh = rim_mesh
		rim.material_override = _mat_steel
		rim.position = Vector3(side * 0.33, -0.02, 0.02)
		rim.rotation = Vector3(0.0, 0.0, side * 0.05)
		shield.add_child(rim)
	var top_rim := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.70, 0.035, 0.075)
	top_rim.mesh = top_mesh
	top_rim.material_override = _mat_steel
	top_rim.position = Vector3(0.0, 0.42, 0.01)
	shield.add_child(top_rim)
	# The boss: a domed steel centre that is what the blows actually strike.
	var boss := MeshInstance3D.new()
	var boss_mesh := SphereMesh.new()
	boss_mesh.radius = 0.075
	boss_mesh.height = 0.11
	boss.mesh = boss_mesh
	boss.material_override = _mat_steel
	boss.position = Vector3(0.0, 0.10, 0.055)
	shield.add_child(boss)
	# A diagonal band across the face, so it is not a plain board.
	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.10, 0.74, 0.062)
	band.mesh = band_mesh
	band.material_override = _mat_brass
	band.position = Vector3(0.0, 0.02, 0.045)
	band.rotation = Vector3(0.0, 0.0, deg_to_rad(38.0))
	shield.add_child(band)
	# Arm straps on the back, where the hand actually goes.
	for y: float in [0.20, -0.10]:
		var strap := MeshInstance3D.new()
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.24, 0.05, 0.20)
		strap.mesh = strap_mesh
		strap.material_override = _mat_leather
		strap.position = Vector3(0.0, y, -0.09)
		shield.add_child(strap)
	return shield

## Places the shield in its hand and raises it as the right button is held.
func _place_shield() -> void:
	if not _shield_worn: return
	if not is_instance_valid(_shield):
		_shield = _build_shield_model(_world)
	if not is_instance_valid(_shield): return
	var arm := _arm_set(_shield_side())
	if not is_instance_valid(_rig) or arm.hand < 0:
		_shield.visible = false
		return
	_shield.visible = not _shield_broken
	var aim: Vector3 = _player._visual.global_basis.z.normalized()
	var hand: Vector3 = (_rig.global_transform * _rig.get_bone_global_pose(int(arm.hand))).origin
	# Raised: the shield comes up and across, covering the chest and the leading side.
	# Stowed: it hangs at the side, face down.
	var up_amount := clampf(_shield_raise, 0.0, 1.0)
	var raised: Vector3 = _player.global_position + Vector3.UP * 1.22 + aim * 0.46 \
		+ _player._visual.global_basis.x * (_left_sign * -0.16)
	var stowed: Vector3 = hand - aim * 0.06 - Vector3.UP * 0.10
	var place: Vector3 = stowed.lerp(raised, up_amount)
	_shield.global_position = place
	# The face looks where the danger comes from; while stowed it hangs.
	var face_dir: Vector3 = aim if up_amount > 0.05 else (-Vector3.UP)
	if face_dir.length_squared() > 1.0e-6:
		_shield.look_at(place + face_dir, Vector3.UP, true)
	# Beaten-down shields sit lower and tilt away, which is what shrinking coverage
	# looks like from outside.
	if _shield_broken:
		_shield.visible = false

## What the shield is doing, for the HUD and for the checks.
func shield_status() -> Dictionary:
	return {
		"worn": _shield_worn, "broken": _shield_broken,
		"hp": _shield_hp, "max_hp": SHIELD_MAX_HP,
		"raise": _shield_raise, "coverage_m": _shield_coverage(),
		"blocks": _shield_blocks_total, "absorbed": _shield_absorbed,
		"centre": _shield_centre(),
	}

## Equips or stows the shield, and puts it on the ground with the weapon when dropped.
func set_shield_worn(worn: bool) -> void:
	_shield_worn = worn
	if worn and _shield_hp <= 0.0:
		# A broken shield is a fresh one when it is taken up again from the menu.
		_shield_hp = SHIELD_MAX_HP
		_shield_broken = false
	if not worn and is_instance_valid(_shield):
		_shield.visible = false
	if is_instance_valid(_shield):
		_shield.visible = worn and not _shield_broken

## DSH_MELEE_SET: builds the model for whichever weapon is equipped. Every model is
## laid out with its point or head along local +X, because that is the axis the
## sweep, the IK and the placement maths all assume.
func _build_weapon_model(parent: Node3D, id: String) -> Node3D:
	match id:
		"mace": return _build_mace_model(parent)
		"axe": return _build_axe_model(parent)
		"sledge": return _build_sledge_model(parent)
		"spear": return _build_spear_model(parent)
		_: return _build_sword_model(parent, "PrototypeSword")

## Shared materials for the weapon set, so five models do not allocate five sets.
var _mat_steel: StandardMaterial3D
var _mat_edge: StandardMaterial3D
var _mat_dark_steel: StandardMaterial3D
var _mat_leather: StandardMaterial3D
var _mat_brass: StandardMaterial3D
var _mat_wood: StandardMaterial3D
var _mat_iron: StandardMaterial3D

func _weapon_materials() -> void:
	if _mat_steel != null: return
	_mat_steel = StandardMaterial3D.new()
	_mat_steel.albedo_color = Color(0.74, 0.78, 0.84); _mat_steel.metallic = 0.92; _mat_steel.roughness = 0.22
	_mat_edge = StandardMaterial3D.new()
	_mat_edge.albedo_color = Color(0.88, 0.91, 0.95); _mat_edge.metallic = 0.95; _mat_edge.roughness = 0.12
	_mat_dark_steel = StandardMaterial3D.new()
	_mat_dark_steel.albedo_color = Color(0.50, 0.54, 0.60); _mat_dark_steel.metallic = 0.86; _mat_dark_steel.roughness = 0.36
	_mat_iron = StandardMaterial3D.new()
	_mat_iron.albedo_color = Color(0.38, 0.39, 0.42); _mat_iron.metallic = 0.72; _mat_iron.roughness = 0.48
	_mat_leather = StandardMaterial3D.new()
	_mat_leather.albedo_color = Color(0.22, 0.14, 0.10); _mat_leather.roughness = 0.88
	_mat_brass = StandardMaterial3D.new()
	_mat_brass.albedo_color = Color(0.66, 0.50, 0.20); _mat_brass.metallic = 0.78; _mat_brass.roughness = 0.34
	_mat_wood = StandardMaterial3D.new()
	_mat_wood.albedo_color = Color(0.36, 0.23, 0.12); _mat_wood.roughness = 0.72

## A tapered shaft from the grip outward, the haft every hafted weapon shares.
## Returns the tip position so a head or a point can be placed on it.
func _add_haft(parent: Node3D, from: float, to: float, radius: float, taper: float, material: Material) -> Vector3:
	var steps := 4
	for i: int in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var x0 := lerpf(from, to, t0)
		var x1 := lerpf(from, to, t1)
		var r0 := lerpf(radius, taper, t0)
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = r0
		cyl.bottom_radius = lerpf(radius, taper, t1)
		cyl.height = absf(x1 - x0) * 1.05
		cyl.radial_segments = 10
		seg.mesh = cyl
		seg.material_override = material
		# Cylinders run along Y; lay this one along X.
		seg.rotation = Vector3(0.0, 0.0, PI * 0.5)
		seg.position = Vector3((x0 + x1) * 0.5, 0.0, 0.0)
		parent.add_child(seg)
	return Vector3(to, 0.0, 0.0)

## A wrapped grip, so every weapon's hand-hold reads as leather rather than metal.
func _add_grip(parent: Node3D, from: float, to: float, radius: float) -> void:
	var grip := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = absf(to - from)
	cyl.radial_segments = 12
	grip.mesh = cyl
	grip.material_override = _mat_leather
	grip.rotation = Vector3(0.0, 0.0, PI * 0.5)
	grip.position = Vector3((from + to) * 0.5, 0.0, 0.0)
	parent.add_child(grip)

## One-handed mace: a hafted weapon with a flanged iron head. Blunt, so it crushes
## rather than cuts - the damage table says so.
func _build_mace_model(parent: Node3D) -> Node3D:
	_weapon_materials()
	var mace := Node3D.new()
	mace.name = "PrototypeMace"
	parent.add_child(mace)
	_add_haft(mace, -0.16, 0.44, 0.030, 0.022, _mat_wood)
	_add_grip(mace, -0.15, 0.06, 0.034)
	# Pommel and a ferrule where the haft meets the head.
	for spec: Array in [[-0.175, 0.038], [0.44, 0.030]]:
		var ring := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = float(spec[1]); cyl.bottom_radius = float(spec[1]); cyl.height = 0.035
		cyl.radial_segments = 12
		ring.mesh = cyl
		ring.material_override = _mat_brass
		ring.rotation = Vector3(0.0, 0.0, PI * 0.5)
		ring.position = Vector3(float(spec[0]), 0.0, 0.0)
		mace.add_child(ring)
	# The head: a core with six radial flanges.
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.052; core_mesh.bottom_radius = 0.052; core_mesh.height = 0.17
	core_mesh.radial_segments = 12
	core.mesh = core_mesh
	core.material_override = _mat_iron
	core.rotation = Vector3(0.0, 0.0, PI * 0.5)
	core.position = Vector3(0.52, 0.0, 0.0)
	mace.add_child(core)
	for i: int in 6:
		var angle := TAU * float(i) / 6.0
		var flange := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.17, 0.052, 0.014)
		flange.mesh = box
		flange.material_override = _mat_steel
		flange.position = Vector3(0.52, sin(angle) * 0.048, cos(angle) * 0.048)
		flange.rotation = Vector3(angle, 0.0, 0.0)
		mace.add_child(flange)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.046; cap_mesh.height = 0.092
	cap.mesh = cap_mesh
	cap.material_override = _mat_steel
	cap.position = Vector3(0.60, 0.0, 0.0)
	mace.add_child(cap)
	return mace

## Two-handed axe: long haft, a bearded single-bit head with a back spike.
func _build_axe_model(parent: Node3D) -> Node3D:
	_weapon_materials()
	var axe := Node3D.new()
	axe.name = "PrototypeAxe"
	parent.add_child(axe)
	_add_haft(axe, -0.34, 0.86, 0.034, 0.026, _mat_wood)
	_add_grip(axe, -0.33, -0.02, 0.038)
	_add_grip(axe, 0.10, 0.34, 0.036)
	var butt := MeshInstance3D.new()
	var butt_mesh := CylinderMesh.new()
	butt_mesh.top_radius = 0.042; butt_mesh.bottom_radius = 0.042; butt_mesh.height = 0.04
	butt.mesh = butt_mesh
	butt.material_override = _mat_brass
	butt.rotation = Vector3(0.0, 0.0, PI * 0.5)
	butt.position = Vector3(-0.35, 0.0, 0.0)
	axe.add_child(butt)
	# Head socket.
	var socket := MeshInstance3D.new()
	var sock_mesh := CylinderMesh.new()
	sock_mesh.top_radius = 0.040; sock_mesh.bottom_radius = 0.040; sock_mesh.height = 0.16
	sock_mesh.radial_segments = 12
	socket.mesh = sock_mesh
	socket.material_override = _mat_iron
	socket.rotation = Vector3(0.0, 0.0, PI * 0.5)
	socket.position = Vector3(0.86, 0.0, 0.0)
	axe.add_child(socket)
	# The bit: a crescent blade sweeping forward and up from the socket.
	var bit := MeshInstance3D.new()
	var bit_mesh := PrismMesh.new()
	bit_mesh.size = Vector3(0.30, 0.34, 0.035)
	bit_mesh.left_to_right = 0.7
	bit.mesh = bit_mesh
	bit.material_override = _mat_edge
	bit.position = Vector3(0.99, 0.06, 0.0)
	bit.rotation = Vector3(0.0, 0.0, deg_to_rad(-14.0))
	axe.add_child(bit)
	# A back spike, so the reverse blow is a real one.
	var spike := MeshInstance3D.new()
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.001; spike_mesh.bottom_radius = 0.030; spike_mesh.height = 0.16
	spike.mesh = spike_mesh
	spike.material_override = _mat_steel
	spike.rotation = Vector3(0.0, 0.0, PI * 0.5)
	spike.position = Vector3(0.90, -0.11, 0.0)
	axe.add_child(spike)
	return axe

## Two-handed sledgehammer: long haft, a heavy square block head with banded faces.
func _build_sledge_model(parent: Node3D) -> Node3D:
	_weapon_materials()
	var sledge := Node3D.new()
	sledge.name = "PrototypeSledge"
	parent.add_child(sledge)
	_add_haft(sledge, -0.34, 0.78, 0.034, 0.026, _mat_wood)
	_add_grip(sledge, -0.33, -0.02, 0.038)
	_add_grip(sledge, 0.10, 0.34, 0.036)
	var butt := MeshInstance3D.new()
	var butt_mesh := CylinderMesh.new()
	butt_mesh.top_radius = 0.042; butt_mesh.bottom_radius = 0.042; butt_mesh.height = 0.04
	butt.mesh = butt_mesh
	butt.material_override = _mat_brass
	butt.rotation = Vector3(0.0, 0.0, PI * 0.5)
	butt.position = Vector3(-0.35, 0.0, 0.0)
	sledge.add_child(butt)
	# Block head, square in section so a blow lands on a face.
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.30, 0.15, 0.15)
	head.mesh = head_mesh
	head.material_override = _mat_iron
	head.position = Vector3(0.90, 0.0, 0.0)
	sledge.add_child(head)
	for side: float in [0.075, -0.075]:
		var face := MeshInstance3D.new()
		var face_mesh := BoxMesh.new()
		face_mesh.size = Vector3(0.045, 0.16, 0.16)
		face.mesh = face_mesh
		face.material_override = _mat_dark_steel
		face.position = Vector3(0.90 + side, 0.0, 0.0)
		sledge.add_child(face)
	# Banding either side of the eye.
	for at: float in [0.72, 1.08]:
		var band := MeshInstance3D.new()
		var band_mesh := CylinderMesh.new()
		band_mesh.top_radius = 0.040; band_mesh.bottom_radius = 0.040; band_mesh.height = 0.05
		band.mesh = band_mesh
		band.material_override = _mat_brass
		band.rotation = Vector3(0.0, 0.0, PI * 0.5)
		band.position = Vector3(at, 0.0, 0.0)
		sledge.add_child(band)
	return sledge

## Two-handed spear: a long ash shaft with a leaf-shaped head, a collar and a
## butt-spike, balanced so it can also be thrown.
func _build_spear_model(parent: Node3D) -> Node3D:
	_weapon_materials()
	var spear := Node3D.new()
	spear.name = "PrototypeSpear"
	parent.add_child(spear)
	_add_haft(spear, -1.05, 0.74, 0.028, 0.022, _mat_wood)
	_add_grip(spear, -0.42, -0.06, 0.031)
	_add_grip(spear, 0.06, 0.40, 0.030)
	# Collar and the leaf head.
	var collar := MeshInstance3D.new()
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.030; collar_mesh.bottom_radius = 0.030; collar_mesh.height = 0.05
	collar.mesh = collar_mesh
	collar.material_override = _mat_brass
	collar.rotation = Vector3(0.0, 0.0, PI * 0.5)
	collar.position = Vector3(0.74, 0.0, 0.0)
	spear.add_child(collar)
	var blade := MeshInstance3D.new()
	var blade_mesh := PrismMesh.new()
	blade_mesh.size = Vector3(0.30, 0.09, 0.020)
	blade_mesh.left_to_right = 1.0
	blade.mesh = blade_mesh
	blade.material_override = _mat_edge
	blade.position = Vector3(0.92, 0.0, 0.0)
	spear.add_child(blade)
	var point := MeshInstance3D.new()
	var point_mesh := CylinderMesh.new()
	point_mesh.top_radius = 0.001; point_mesh.bottom_radius = 0.030; point_mesh.height = 0.10
	point.mesh = point_mesh
	point.material_override = _mat_steel
	point.rotation = Vector3(0.0, 0.0, -PI * 0.5)
	point.position = Vector3(1.10, 0.0, 0.0)
	spear.add_child(point)
	# Butt-spike, which is what makes a spear throwable and still a weapon.
	var butt := MeshInstance3D.new()
	var butt_mesh := CylinderMesh.new()
	butt_mesh.top_radius = 0.026; butt_mesh.bottom_radius = 0.001; butt_mesh.height = 0.10
	butt.mesh = butt_mesh
	butt.material_override = _mat_steel
	butt.rotation = Vector3(0.0, 0.0, PI * 0.5)
	butt.position = Vector3(-1.10, 0.0, 0.0)
	spear.add_child(butt)
	return spear

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
	# Flying sparks: short bright streaks thrown off a blade-on-blade clash. They
	# are drawn as thin boxes stretched along their own velocity, share one material
	# and one mesh, and are hard-capped so a long duel cannot flood the scene.
	_spark_mesh = BoxMesh.new(); _spark_mesh.size = Vector3(0.012, 0.012, 0.10)
	_spark_material = StandardMaterial3D.new()
	_spark_material.albedo_color = Color(1.0, 0.93, 0.68)
	_spark_material.emission_enabled = true
	_spark_material.emission = Color(1.0, 0.78, 0.34)
	_spark_material.emission_energy_multiplier = 3.2
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mesh_instance = _spark_mesh

## Throws a burst of sparks from `at`, away along `normal`.
func _spark_burst(at: Vector3, normal: Vector3, count: int) -> void:
	if not is_instance_valid(_world) or count <= 0: return
	var away: Vector3 = normal
	if away.length_squared() < 1.0e-6: away = Vector3.UP
	away = away.normalized()
	for i: int in count:
		if _sparks.size() >= MAX_SPARKS: return
		_sparks_total += 1
		var node := MeshInstance3D.new()
		node.mesh = _spark_mesh
		node.material_override = _spark_material
		_world.add_child(node)
		node.global_position = at + Vector3(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03), randf_range(-0.03, 0.03))
		var spread := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.4), randf_range(-1.0, 1.0))
		var velocity: Vector3 = away * randf_range(2.4, 6.2) + spread * 1.7
		var life: float = randf_range(0.22, 0.42)
		_sparks.append({"node": node, "velocity": velocity, "life": life, "max_life": life})
		_node_aim_along(node, velocity)

## Points a spark's long axis (local +Z) along its travel, so it reads as a streak.
func _node_aim_along(node: Node3D, direction: Vector3) -> void:
	if direction.length_squared() < 1.0e-8: return
	node.look_at(node.global_position + direction.normalized(), Vector3.UP, true)

func _update_sparks(delta: float) -> void:
	if _sparks.is_empty(): return
	var index := 0
	while index < _sparks.size():
		var entry: Dictionary = _sparks[index]
		var node: Node3D = entry.get("node")
		if not is_instance_valid(node):
			_sparks.remove_at(index)
			continue
		var life: float = float(entry.get("life", 0.0)) - delta
		if life <= 0.0:
			node.queue_free()
			_sparks.remove_at(index)
			continue
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO) - Vector3.UP * 16.0 * delta
		entry["life"] = life
		entry["velocity"] = velocity
		_sparks[index] = entry
		node.global_position += velocity * delta
		var fade: float = life / maxf(0.01, float(entry.get("max_life", 0.3)))
		node.scale = Vector3.ONE * clampf(fade, 0.12, 1.0)
		index += 1

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
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	panel.add_child(_hint)
	_hint_layer.add_child(panel)
	_update_hint()

## The hint follows the state: a sword lying within reach always offers "pick up".
func _update_hint() -> void:
	if not is_instance_valid(_hint): return
	var reachable := not _nearest_ground_sword().is_empty()
	_hint_ground_reachable = reachable
	if _sword_grounded or _unarmed:
		_hint.text = "Оружие лежит на земле\nE — поднять (то же самое оружие)"
		return
	var mode := "ПОЛУМЕЧ: рука на лезвии, укол в щели доспеха" if _half_sword else "ЛКМ + ПКМ — двуручный хват, удар сильнее"
	var text := "ТЕСТОВЫЙ МЕЧ (прототип)\nЛКМ и мышь — рубящий удар\nПКМ — БЛОК, мышь поднимает/опускает\n" + mode + "\nКолесо мыши — укол вперёд / оттянуть назад\nX — полумеч (хват за лезвие против доспеха)\nG — бросить меч"
	if reachable:
		text += "\nE — поднять меч (рядом лежит меч, свой или чужой)"
	_hint.text = text

## True while some sword lies within reach, so the hint can be refreshed cheaply.
var _hint_ground_reachable := false
var _hint_check_ms := 400.0

## A dropped sword lies on the ground and is picked up with E, the same way every
## other weapon in the game behaves.
var _sword_grounded := false
var _dropped_at := Vector3.ZERO

func is_sword_grounded() -> bool:
	return _sword_grounded

## G: leave the sword as a real 3D object lying on the ground.
func drop_sword_to_ground() -> bool:
	if not _selected or _sword_grounded or not is_instance_valid(_sword): return false
	_sword_grounded = true
	_held = false
	_hold_left = false
	_hold_right = false
	_held_event = false
	_blocking = false
	_omega = Vector3.ZERO
	_prev_points = PackedVector3Array()
	_contact_prev.clear()
	_contact_gap.clear()
	if is_instance_valid(_player): _player.set("_sword_lock", false)
	var visual: Node3D = _player._visual
	var forward: Vector3 = visual.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 1.0e-6: forward = Vector3.FORWARD
	forward = forward.normalized()
	var at: Vector3 = _player.global_position + forward * 0.75 + visual.global_basis.x * 0.25
	var ground := _grounded(at)
	if ground.is_finite(): at = ground + Vector3.UP * 0.05
	else: at = Vector3(at.x, _player.global_position.y + 0.05, at.z)
	_dropped_at = at
	# Lying flat: the blade runs along the ground with the flat face down.
	_sword.visible = true
	_sword.global_transform = _place_basis(at, forward) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	_register_ground_sword(_sword)
	_stamp_ground_weapon(_sword, _weapon_id)
	_update_hint()
	print("DSH_SWORD_PROTO_DROPPED at=", at, " ground_swords=", _ground_swords.size())
	return true

## Distance at which a sword on the ground can be reached.
const GROUND_PICKUP_RANGE := 2.4

## Swords lying on the ground. The held sword is in here while it is dropped, and
## so are the knights' swords - anyone may take any of them.
var _ground_swords: Array[Node3D] = []

func _register_ground_sword(node: Node3D) -> void:
	if not is_instance_valid(node): return
	if not _ground_swords.has(node): _ground_swords.append(node)

## Records WHICH weapon of the set a ground node is, so picking it back up returns the
## same axe or spear instead of whatever happened to be equipped last.
func _stamp_ground_weapon(node: Node3D, weapon: String) -> void:
	if is_instance_valid(node): node.set_meta("melee_weapon", weapon)

func _ground_weapon_of(node: Node3D) -> String:
	if not is_instance_valid(node) or not node.has_meta("melee_weapon"): return ""
	return str(node.get_meta("melee_weapon"))

## Nearest sword on the ground within reach, or an empty dictionary.
func _nearest_ground_sword() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := GROUND_PICKUP_RANGE
	for index: int in range(_ground_swords.size() - 1, -1, -1):
		var node: Node3D = _ground_swords[index]
		if not is_instance_valid(node):
			_ground_swords.remove_at(index)
			continue
		var distance: float = _player.global_position.distance_to(node.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = {"node": node, "distance": distance, "own": node == _sword}
	return best

## Pulls the sword model out of a dropped knight's sword (a physics body wrapper)
## so the player can hold the very same model.
func _take_sword_model(node: Node3D) -> Node3D:
	if node is MeshInstance3D: return node
	for child: Node in node.get_children():
		if child is CollisionShape3D: continue
		if child is Node3D: return child as Node3D
	return null

## E: take the nearest sword on the ground - the player's own or a knight's. A
## sword already in the hand cannot be swapped for another: drop it first.
func try_pickup_sword() -> bool:
	if not _selected: return false
	# Thrown away counts as empty-handed just as much as put down.
	if not _sword_grounded and not _unarmed:
		print("DSH_SWORD_PROTO_PICKUP_REFUSED reason=in_hand")
		return false
	var found := _nearest_ground_sword()
	if found.is_empty():
		print("DSH_SWORD_PROTO_PICKUP_REFUSED reason=nothing_in_reach")
		return false
	var node: Node3D = found.get("node")
	var taken_own: bool = bool(found.get("own", false))
	# DSH_MELEE_SET: a weapon of the set that was put down is picked back up AS ITSELF.
	var stamp := _ground_weapon_of(node)
	_ground_swords.erase(node)
	if stamp != "" and stamp != _weapon_id:
		set_weapon(stamp)
		if is_instance_valid(node): node.queue_free()
		_sword_grounded = false
		_unarmed = false
		_arm_ready_ms = Time.get_ticks_msec() + 450
		if is_instance_valid(_sword): _sword.visible = true
		_update_hint()
		print("DSH_SWORD_PROTO_PICKED weapon=", stamp)
		return true
	if not taken_own:
		# A knight's sword: hold its model, and leave the player's own sword lying
		# where it fell so it can still be collected later.
		var model := _take_sword_model(node)
		if model == null:
			_register_ground_sword(node)
			print("DSH_SWORD_PROTO_PICKUP_REFUSED reason=bad_model")
			return false
		node.remove_child(model)
		_world.add_child(model)
		node.queue_free()
		_sword = model
		_dropped_at = Vector3.ZERO
	_sword_grounded = false
	_unarmed = false
	_arm_ready_ms = Time.get_ticks_msec() + 450
	if is_instance_valid(_sword):
		_sword.visible = true
		_sword.global_transform = _place_basis(_player.global_position + Vector3.UP * 1.2, _dir)
	_update_hint()
	print("DSH_SWORD_PROTO_PICKED distance=", found.get("distance", 0.0), " own=", taken_own,
		" ground_swords=", _ground_swords.size())
	return true

## Drops the held sword at an exact point (used by the driven test and diagnostics).
func drop_sword_at(point: Vector3) -> bool:
	if not _selected or _sword_grounded or not is_instance_valid(_sword): return false
	_sword_grounded = true
	_held = false
	_hold_left = false
	_hold_right = false
	_held_event = false
	_blocking = false
	_omega = Vector3.ZERO
	_prev_points = PackedVector3Array()
	_contact_prev.clear()
	_contact_gap.clear()
	if is_instance_valid(_player): _player.set("_sword_lock", false)
	var forward: Vector3 = _player._visual.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 1.0e-6: forward = Vector3.FORWARD
	_dropped_at = point
	_sword.visible = true
	_sword.global_transform = _place_basis(point, forward.normalized()) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	_register_ground_sword(_sword)
	_stamp_ground_weapon(_sword, _weapon_id)
	_update_hint()
	return true

func ground_sword_count() -> int:
	var count := 0
	for node: Node3D in _ground_swords:
		if is_instance_valid(node): count += 1
	return count

## How many swords lie on the ground, how many of them belong to someone else, and
## where the first foreign one is - so a test can walk up to it.
func ground_sword_info() -> Dictionary:
	var foreign := 0
	var first_foreign := Vector3.ZERO
	for node: Node3D in _ground_swords:
		if not is_instance_valid(node): continue
		if node == _sword: continue
		if foreign == 0: first_foreign = node.global_position
		foreign += 1
	return {"count": ground_sword_count(), "foreign": foreign, "first_foreign_at": first_foreign,
		"own_grounded": _sword_grounded}

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
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		# T winds up a throwable weapon; letting T go throws it.
		if code == KEY_T and is_throwable() and not _unarmed and not _sword_grounded:
			_begin_throw()
			get_viewport().set_input_as_handled()
			return
		# G drops the sword as a real object on the ground; E picks it back up.
		if code == KEY_G and not _sword_grounded:
			if drop_sword_to_ground():
				get_viewport().set_input_as_handled()
				return
		if code == KEY_E and _sword_grounded:
			if try_pickup_sword():
				get_viewport().set_input_as_handled()
				return
		# X: half-sword - the off hand takes the blade instead of the hilt.
		if code == KEY_X and not _sword_grounded:
			set_half_sword(not _half_sword)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and not event.pressed and not event.echo:
		var released: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if released == KEY_T and _throwing:
			_release_throw()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			# DSH_MELEE_SET: with a throwable weapon the LEFT button THROWS - hold to
			# wind up, release to let the spear go. The right button aims for it.
			if is_throwable() and not _unarmed and not _sword_grounded:
				if button.pressed:
					_begin_throw()
				else:
					_release_throw()
				get_viewport().set_input_as_handled()
				return
			_held_event = button.pressed
			_hold_left = button.pressed
			_held = _hold_left or _hold_right
			_player.set("_sword_lock", false)
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			# Holding the right button shows where the throw would land. It is also
			# the aiming stance, so the melee sweep still works while it is held.
			_aiming_throw = button.pressed and is_throwable()
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
		# A single violent flick is DAMPED: one event may only move the target so far,
		# so a hard wrist snap cannot teleport the blade through a whole arc in one
		# frame. The arm still gets there - it just has to travel for it.
		var mouse_x := clampf(motion.relative.x, -MOUSE_PER_EVENT_CAP, MOUSE_PER_EVENT_CAP)
		var mouse_y := clampf(motion.relative.y, -MOUSE_PER_EVENT_CAP, MOUSE_PER_EVENT_CAP)
		_hand_cmd.x += mouse_x * MOUSE_TO_HAND
		_hand_cmd.y -= mouse_y * MOUSE_TO_HAND
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

## Which way is AWAY from the body, horizontally, on the sword-hand side. The
## blade leans that way so it can never cross the character's own head.
func _outward_from_body() -> Vector3:
	var visual: Node3D = _player._visual
	var bone := _hand_bone_for(_carry_side)
	if bone < 0: return visual.global_basis.x
	var fist: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(bone).origin
	var outward := fist - _player.global_position
	outward.y = 0.0
	if outward.length_squared() < 1.0e-6: return visual.global_basis.x
	return outward.normalized()

## Radius of the character's own body that the blade must stay out of. Deliberately
## tight: this safety net should only fire when the blade really is inside him.
const BODY_CLEAR_RADIUS := 0.16
## Largest correction the safety net may apply, in 15-degree steps. A big turn here
## moved the ready pose and wrecked the cut built on top of it.
const BODY_CLEAR_MAX_STEPS := 3

## Steel must never be drawn through the character's own body. If the wanted blade
## line passes through his torso, the blade is swung around the vertical axis to
## the nearest side that clears him - turning the sword is better than letting it
## pass through the character. The correction is small and bounded.
func _clear_blade_from_body(direction: Vector3) -> Vector3:
	if not is_instance_valid(_rig) or _bone_chest < 0 or _bone_pelvis < 0: return direction
	var chest: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_chest).origin
	var pelvis: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_pelvis).origin
	var reach := 0.06 + _weapon_length
	if _segment_distance(_sword_origin, _sword_origin + direction * reach, chest, pelvis) > BODY_CLEAR_RADIUS:
		return direction
	for step: int in BODY_CLEAR_MAX_STEPS:
		var angle := deg_to_rad(15.0) * float(step + 1)
		for turn: float in [1.0, -1.0]:
			var rotated := direction.rotated(Vector3.UP, angle * turn)
			if _segment_distance(_sword_origin, _sword_origin + rotated * reach, chest, pelvis) > BODY_CLEAR_RADIUS:
				return rotated
	return direction

## Body-relative carried stance (independent of the camera): the point is up, out
## to the sword side and forward, so the raised blade stands clear of the head
## instead of being driven up through the face.
func _carry_direction() -> Vector3:
	var visual: Node3D = _player._visual
	if _half_sword:
		# Half-sword carries the point FORWARD and level: it is a thrusting stance,
		# not a raised guard.
		return (visual.global_basis.z * 0.94 + Vector3.UP * 0.22).normalized()
	return (Vector3.UP * 0.74 + _outward_from_body() * 0.34 + visual.global_basis.z * 0.50).normalized()

## Where the sword HAND rests in the ready stance: forward and clearly BELOW the
## shoulder, so the fist sits at chest height. This is the third time this pose has
## been wrong for the same reason - the fist drifting up to the face - so the
## downward component is decisive here rather than a touch.
func _ready_hand_direction() -> Vector3:
	var visual: Node3D = _player._visual
	return (visual.global_basis.z * 0.94 - Vector3.UP * 0.34).normalized()

## The guard is the SAME diagonal carried pose the sword rests in (steel across the
## body, point up), held as a barrier. The mouse only raises or lowers that guard,
## so blocking always looks right and the player still picks the covered zone.
func _guard_direction() -> Vector3:
	var hy := clampf(_hand.y, -1.0, 1.0)
	var hx := clampf(_hand.x, -1.0, 1.0)
	var base: Vector3 = _carry_direction()
	var visual: Node3D = _player._visual
	var guard: Vector3 = (base + Vector3.UP * (hy * 0.50 + 0.12) + visual.global_basis.x * (hx * 0.30)).normalized()
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
		var carry := _clear_blade_from_world(_clear_blade_from_body(_carry_direction()))
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
		# DSH_MELEE_SET: mass is felt as lag. A sledge answers the mouse later than a
		# sword does, which is the whole point of carrying one.
		desired = axis.normalized() * clampf(angle * STEER_GAIN / _weapon_mass, 0.0, MAX_OMEGA / _weapon_mass)
	desired -= _omega * STEER_DAMPING
	# Biting into a body or blade makes the sword heavy for a moment.
	if Time.get_ticks_msec() < _bind_until_ms:
		desired = desired.limit_length(1.6)
	var dv := desired - _omega
	var max_dv := MAX_ALPHA * delta / _weapon_mass
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
	_blocking = _hold_right and not _hold_left and not is_throwable()
	_player.set("_sword_lock", false)
	# DSH_MELEE_SET: with the weapon thrown the hands are empty, so no steering and no
	# arm IK - the player's own animation owns the arms again until E lifts it.
	if _unarmed:
		_held = false
		_hold_left = false
		_hold_right = false
		_throwing = false
		_omega = Vector3.ZERO
		_prev_points = PackedVector3Array()
		_update_city_npc(delta)
		_step_thrown(delta)
		return
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
	if _sword_grounded:
		# The sword lies on the ground: no steering, no arm, it is simply not held.
		_held = false
		_hold_left = false
		_hold_right = false
		_blocking = false
		_omega = Vector3.ZERO
		_prev_points = PackedVector3Array()
		if is_instance_valid(_player): _player.set("_sword_lock", false)
		_update_city_npc(delta)
		return
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
		_swing_start_ms = Time.get_ticks_msec()
		# A fresh, deliberate swing re-arms every target. The old rule demanded the
		# blade LEAVE a part before it could be cut again, which never happened in a
		# close fight - the blade simply stayed inside the body, so a whole duel
		# landed a single blow.
		_contact_prev.clear()
		_contact_gap.clear()
	_held_prev = _held
	if not _held:
		_swing_start_dir = _dir
	_swing_travel = _windup_angle()
	_block_push = _block_push.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	_body_push = _body_push.lerp(Vector3.ZERO, clampf(BODY_PUSH_DECAY * delta, 0.0, 1.0))
	# The shield comes up while the right button is held and drops back when it is let
	# go: that IS the block animation.
	if _shield_worn and not _shield_broken:
		var want_raise := 1.0 if (_hold_right or _blocking) else 0.0
		_shield_raise = move_toward(_shield_raise, want_raise, SHIELD_RAISE_RATE * delta)
	_solve_arm(delta)
	# The blade is never allowed to point behind the player.
	_dir = _soft_body_limit(_constrain_forward(_dir), 0.10, 0.16)
	# The opponent is a real body: his step, gravity and pose belong to the physics
	# frame, otherwise move_and_slide() leaves him hanging in the air.
	_update_city_npc(delta)
	# DSH_MELEE_SET: a thrown weapon flies on its own, once per physics tick.
	_step_thrown(delta)
	# The wind-up runs on the physics clock so a missed release cannot leave it stuck.
	if _throwing:
		_throw_windup = minf(_throw_windup + delta, THROW_WINDUP_TIME)

## ---- DSH_MELEE_SET: throwing -----------------------------------------
## A throwable weapon (the spear) can be wound up with T and let go. The model leaves
## the hand as a real projectile: it flies under gravity, sticks where it lands, and
## is stamped as the weapon it is so E lifts the same spear back up.
const THROW_SPEED_MIN := 11.0
const THROW_SPEED_MAX := 26.0
const THROW_WINDUP_TIME := 0.55
const THROW_GRAVITY := 9.81
var _throwing := false
## Right button held with a throwable weapon: the aiming stance, which draws the arc.
var _aiming_throw := false
var _throw_windup := 0.0
## Wall-clock start of the wind-up, so the power cannot be lost to a skipped frame.
var _throw_start_ms := 0
var _thrown: Array[Dictionary] = []
var _unarmed := false
var _thrown_total := 0

func is_throwable() -> bool:
	return bool(weapon_entry().get("throwable", false))

## ---- throwing aim -----------------------------------------------
## While the LEFT button is held with a throwable weapon, a dotted arc shows where the
## throw would send it, using the same launch speed and gravity as the real throw.
const MAX_THROW_DOTS := 26
const THROW_PREVIEW_STEP := 0.035
var _aim_dots: Array[MeshInstance3D] = []
var _aim_dot_mesh: SphereMesh
var _aim_material: StandardMaterial3D
var _aim_visible := 0
var _aim_range := 0.0

func _build_throw_dots() -> void:
	if _aim_dot_mesh != null: return
	_aim_dot_mesh = SphereMesh.new()
	_aim_dot_mesh.radius = 0.024
	_aim_dot_mesh.height = 0.048
	_aim_material = StandardMaterial3D.new()
	_aim_material.albedo_color = Color(0.96, 0.94, 0.90)
	_aim_material.emission_enabled = true
	_aim_material.emission = Color(0.62, 0.60, 0.55)
	_aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i: int in MAX_THROW_DOTS:
		var dot := MeshInstance3D.new()
		dot.mesh = _aim_dot_mesh
		dot.material_override = _aim_material
		dot.visible = false
		_world.add_child(dot)
		_aim_dots.append(dot)

func _update_throw_preview() -> void:
	_build_throw_dots()
	var speed: float = _throw_speed_now()
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_player.get_rid()]
	var at := _sword_origin
	var velocity := _dir.normalized() * speed
	var shown := 0
	var travelled := 0.0
	for i: int in MAX_THROW_DOTS:
		var next := at + velocity * THROW_PREVIEW_STEP
		velocity += Vector3.DOWN * THROW_GRAVITY * THROW_PREVIEW_STEP
		# The arc stops where the weapon would hit, but always shows a few points.
		if shown >= 3 and space != null:
			var query := PhysicsRayQueryParameters3D.create(at, next, 1, excluded)
			query.hit_from_inside = true
			if not space.intersect_ray(query).is_empty(): break
		var dot: MeshInstance3D = _aim_dots[i]
		dot.visible = true
		dot.global_position = next
		dot.scale = Vector3.ONE * clampf(1.15 - float(i) / float(MAX_THROW_DOTS), 0.25, 1.15)
		shown += 1
		travelled += THROW_PREVIEW_STEP * speed
		at = next
	for i: int in range(shown, _aim_dots.size()):
		_aim_dots[i].visible = false
	_aim_visible = shown
	_aim_range = travelled

func _hide_throw_dots() -> void:
	for dot: MeshInstance3D in _aim_dots:
		if is_instance_valid(dot): dot.visible = false
	_aim_visible = 0
	_aim_range = 0.0

## The speed the throw would leave at right now, which is what the arc is drawn with.
func _throw_speed_now() -> float:
	var power := 0.5 if not _throwing else clampf(_throw_held_seconds() / THROW_WINDUP_TIME, 0.0, 1.0)
	return lerpf(THROW_SPEED_MIN, THROW_SPEED_MAX, power)

## How many thrown weapons are still in the air, and where the last one is.
func _thrown_alive() -> int:
	var alive := 0
	for entry: Dictionary in _thrown:
		if bool(entry.get("alive", false)): alive += 1
	return alive

func _thrown_position() -> Vector3:
	for entry: Dictionary in _thrown:
		var node: Node3D = entry.get("node")
		if is_instance_valid(node): return node.global_position
	return Vector3.ZERO

func _begin_throw() -> void:
	if not _active() or _unarmed or not is_throwable(): return
	if _throwing: return
	_throwing = true
	_throw_windup = 0.0
	# The power is measured in WALL TIME, not in accumulated physics deltas: a skipped
	# physics frame used to cut the wind-up short and throw far weaker than the player
	# had held for.
	_throw_start_ms = Time.get_ticks_msec()
	_update_hint()
	print("DSH_MELEE_THROW windup weapon=", _weapon_id)

## How long the wind-up has been held, in seconds.
func _throw_held_seconds() -> float:
	if not _throwing: return 0.0
	return float(Time.get_ticks_msec() - _throw_start_ms) / 1000.0

## Lets the weapon go: it becomes a projectile and the hands are empty.
func _release_throw() -> void:
	if not _throwing: return
	var held := _throw_held_seconds()
	_throwing = false
	var power := clampf(held / THROW_WINDUP_TIME, 0.0, 1.0)
	if not is_instance_valid(_sword): return
	var speed := lerpf(THROW_SPEED_MIN, THROW_SPEED_MAX, power)
	var from: Vector3 = _sword_origin
	var direction: Vector3 = _dir.normalized()
	# The spear leaves the hand and lives in the world from here on.
	_sword.visible = true
	_thrown.append({
		"node": _sword, "velocity": direction * speed, "prev": from,
		"weapon": _weapon_id, "alive": true, "fired_ms": Time.get_ticks_msec(),
	})
	_unarmed = true
	_thrown_total += 1
	_prev_points = PackedVector3Array()
	# A fresh model is built for the next time the player picks something up.
	# DSH_MELEE_SET: every weapon of the set is built NOW, at install time, so choosing
	# one never pays for building it. The cost of a first equip that was measured at
	# about 105 ms - long enough to feel like a freeze - is paid once, at load.
	for weapon_id: String in WEAPONS.keys():
		var model: Node3D = _build_weapon_model(_world, weapon_id)
		model.visible = (weapon_id == _weapon_id)
		_weapon_models[weapon_id] = model
	_sword = _weapon_models.get(_weapon_id)
	_sword.visible = false
	print("DSH_MELEE_THROW released weapon=", _weapon_id, " power=", power, " speed=", speed)

func _step_thrown(delta: float) -> void:
	if _thrown.is_empty(): return
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_player.get_rid()]
	for index: int in range(_thrown.size() - 1, -1, -1):
		var entry: Dictionary = _thrown[index]
		var node: Node3D = entry.get("node")
		if not is_instance_valid(node):
			_thrown.remove_at(index)
			continue
		if not bool(entry.get("alive", false)): continue
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		var from: Vector3 = entry.get("prev", node.global_position)
		velocity += Vector3.DOWN * THROW_GRAVITY * delta
		var to: Vector3 = from + velocity * delta
		var hit: Dictionary = {}
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(from, to, 1, excluded)
			query.hit_from_inside = true
			hit = space.intersect_ray(query)
		entry["velocity"] = velocity
		entry["prev"] = to
		_thrown[index] = entry
		if not hit.is_empty():
			_land_thrown(index, hit, velocity)
			continue
		node.global_position = to
		if velocity.length_squared() > 1.0e-6:
			node.look_at(to + velocity, Vector3.UP, true)

## The weapon comes to rest where it struck, is stamped so it can be lifted again, and
## hurts whatever it hit on the way in.
func _land_thrown(index: int, hit: Dictionary, velocity: Vector3) -> void:
	var entry: Dictionary = _thrown[index]
	var node: Node3D = entry.get("node")
	var point: Vector3 = hit.get("position", node.global_position)
	var collider: Variant = hit.get("collider")
	var direction := velocity.normalized()
	var rest := point - direction * (_weapon_length * 0.5)
	node.global_position = rest
	if direction.length_squared() > 1.0e-6:
		node.look_at(rest + direction, Vector3.UP, true)
	entry["alive"] = false
	entry["velocity"] = Vector3.ZERO
	_thrown[index] = entry
	_register_ground_sword(node)
	_stamp_ground_weapon(node, str(entry.get("weapon", _weapon_id)))
	# A thrown spear is a thrust: it uses the weapon's own stab multiplier.
	var speed := velocity.length()
	if is_instance_valid(collider) and collider is Node3D and collider.has_meta("sword_npc_part"):
		var part := str(collider.get_meta("sword_npc_part"))
		var cut := clampf((speed * 0.7 - DAMAGE_SPEED_MIN) * DAMAGE_PER_MPS * _kind_multiplier("stab"), 4.0, DAMAGE_MAX)
		_npc_take_blade_part(part, point, speed, direction, cut)
	elif is_instance_valid(collider) and collider is Node3D and collider.has_meta("sword_target"):
		_damage_dummy(collider, point, speed, direction, Time.get_ticks_msec())
	print("DSH_MELEE_THROWN_LAND weapon=", entry.get("weapon", ""), " at=", point,
		" speed=", speed, " distance=", _player.global_position.distance_to(point))

## The sword is attached in the DRAW frame, not in the physics step: the rig has
## already applied every bone pose by then (including the player's own pass), so
## the handle is placed on the fist the animation actually shows. Attaching it
## during the physics step read a stale skeleton and left the sword out of hand.
func _process(delta: float) -> void:
	if not _ready or not is_instance_valid(_world) or not is_instance_valid(_rig): return
	if not _active():
		if is_instance_valid(_sword): _sword.visible = false
		return
	if _unarmed:
		# Empty hands after a throw: the player's own animation owns the arms again.
		if is_instance_valid(_sword): _sword.visible = false
		_update_gore(delta)
		_update_stumps(delta)
		_update_sparks(delta)
		if not is_instance_valid(_npc_rig): _update_duelist(delta)
		return
	# A severed limb is cut away every frame, AFTER the player's own pose pass, so
	# neither the animation nor our own arm IK can restore it.
	_apply_player_severed()
	# The "pick up" line appears as soon as a sword comes within reach, and goes
	# again when it does not - checked a few times a second, not every frame.
	_hint_check_ms -= delta * 1000.0
	if _hint_check_ms <= 0.0:
		_hint_check_ms = 400.0
		if (not _nearest_ground_sword().is_empty()) != _hint_ground_reachable:
			_update_hint()
	var armed_with_sword := is_instance_valid(_sword)
	if armed_with_sword and not _sword_grounded:
		_sword.visible = true
		_attach_sword_to_fist()
	# DSH_MELEE_SET: the shield hangs in the second hand, here in the draw frame where
	# the rig has already settled.
	_place_shield()
	# DSH_MELEE_SET: the right button is the aiming stance for a throwable weapon, so
	# the arc is drawn here - after the model has been placed on the fist.
	if _aiming_throw and is_throwable() and not _unarmed:
		_update_throw_preview()
	else:
		_hide_throw_dots()
	_update_gore(delta)
	_update_stumps(delta)
	_update_sparks(delta)
	if not is_instance_valid(_npc_rig): _update_duelist(delta)
	if not armed_with_sword:
		# The blade lies on the ground with the hand that used to hold it.
		_prev_points = PackedVector3Array()
		return
	if _sword_grounded:
		# Dropped: the sword stays a real object where it fell.
		_prev_points = PackedVector3Array()
		if is_instance_valid(_player): _player.set("_sword_lock", false)
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

## True when the character himself is standing inside geometry. The driven test
## teleports him around, so it can leave him inside a building - a sword measured
## there says nothing about the sword.
func player_inside_geometry() -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(_world): return false
	var space := _player.get_world_3d().direct_space_state
	if space == null: return false
	var sphere := SphereShape3D.new()
	sphere.radius = 0.42
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, _player.global_position + Vector3.UP * 0.95)
	params.collision_mask = BLADE_PROBE_MASK
	params.exclude = [_player.get_rid()]
	return not space.intersect_shape(params, 1).is_empty()

## Places the sword on the RIG'S CURRENT fist (displayed pose), with the grip
## centre inside the hand and the blade along the commanded direction.
func _attach_sword_to_fist() -> void:
	var bone := _hand_bone_for(_active_side())
	if bone < 0: return
	var fist: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(bone).origin
	_sword_origin = fist + _dir * GRIP_CENTER_OFFSET
	_grip_hand_error = _sword_origin.distance_to(fist)
	if not _held:
		_settle_carried_blade()
	_place_sword(_sword_origin, _dir)

## While the sword is merely CARRIED, steel may not stand inside the world. The
## blade is first turned clear; whatever still does not fit is drawn back until the
## point rests on the surface, and the arm is pulled in to match on the next frame.
## Simply turning the blade was not enough - the blade was inside the world in 66 of
## 140 walking frames - because the whole sword had been driven into an obstacle.
func _settle_carried_blade() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_world): return
	var direction := _clear_blade_from_world(_dir)
	_dir = direction
	if not _blade_penetrates_world(direction, _sword_origin):
		_carry_pull = maxf(0.0, _carry_pull - 0.03)
		return
	# Turning the blade was not enough - the whole sword had been driven in. Draw it
	# back until the SAME test that measures the fault reports it clear, so the fix
	# and the check can never disagree.
	var pulled := 0.0
	var origin := _sword_origin
	for step: int in BLADE_PULL_STEPS:
		pulled += BLADE_PULL_STEP
		origin = _sword_origin - direction * pulled
		if not _blade_penetrates_world(direction, origin):
			break
	_sword_origin = origin
	_carry_pull = pulled

## How far, and in how many steps, the carried sword may be drawn out of geometry.
const BLADE_PULL_STEP := 0.07
const BLADE_PULL_STEPS := 9

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
		# The HAND goes to a natural ready position (forward at chest height, elbow
		# bent), while the BLADE still points up. Using the blade direction for the
		# hand as well is what folded the arm across the chest. The reach stays well
		# short of full extension: a nearly straight arm is both ugly and unstable.
		var want_dir := _constrain_forward(_ready_hand_direction())
		want_dir = _constrain_to_body(want_dir, 0.34)
		var want_rig := (rig_basis.inverse() * want_dir).normalized()
		var blade_rig := (rig_basis.inverse() * _dir).normalized()
		_lean_body(want_dir, delta)
		var side := _active_side()
		# If the carried sword had to be drawn out of a wall, the arm comes in with
		# it, so the fist keeps holding the grip instead of being left behind.
		var pulled := clampf(_carry_pull / 0.55, 0.0, 1.0)
		var grip_rig := _pose_main(side, want_rig, blade_rig, lerpf(0.70, 0.40, pulled))
		if grip_rig != Vector3.ZERO:
			_sword_origin = (_rig.global_transform * grip_rig) + _dir * GRIP_CENTER_OFFSET
		# The carried blade is never shown inside the character or inside the world:
		# if the pose would drive steel through him or a wall, the blade is turned.
		_dir = _clear_blade_from_body(_dir)
		_dir = _clear_blade_from_world(_dir)
		return
	var want_dir := _constrain_forward(_hand_target_direction())
	want_dir = _constrain_to_body(want_dir, 0.10)
	# The GUARD keeps the same diagonal arm as the carried pose, just lifted or
	# lowered by the mouse, so blocking always reads as the same guard.
	if _blocking and not _hold_left:
		var lift := clampf(_hand.y, -1.0, 1.0)
		want_dir = _constrain_forward((_ready_hand_direction() + Vector3.UP * (lift * 0.45)).normalized())
		want_dir = _constrain_to_body(want_dir, 0.34)
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
			# The supporting hand must stay OUT of the torso: never across the centre
			# line, and never inside the body's own radius. Without this the arm
			# passed straight through the chest during a cut.
			if support.x * _left_sign < 0.06: support.x = _left_sign * 0.06
			var body_center: Vector3 = _chain_global(_bone_chest).origin
			var flat := Vector3(support.x - body_center.x, 0.0, support.z - body_center.z)
			var min_radius: float = maxf(0.28, _two_hand_offset_rig * 0.85)
			if flat.length() < min_radius:
				var away: Vector3 = flat.normalized() if flat.length_squared() > 1.0e-8 else Vector3(_left_sign, 0.0, 0.0)
				support.x = body_center.x + away.x * min_radius
				support.z = body_center.z + away.z * min_radius
			_pose_support(&"left", support)
	elif _half_sword:
		# HALF-SWORD: the off hand grips the BLADE, well up from the guard, which is
		# the technique the game is named after - it shortens the weapon and puts the
		# point exactly where the armour opens. Right hand keeps the hilt.
		grip_rig = _pose_main(&"right", want_rig, blade_rig, 0.62)
		if grip_rig != Vector3.ZERO:
			var on_blade := grip_rig + blade_rig * (HALF_SWORD_GRIP / maxf(0.05, _rig_scale()))
			_pose_support(&"left", on_blade)
			_half_sword_blade_point = (_rig.global_transform * on_blade)
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
	# DSH_MELEE_SET: the weapon decides the grip. A two-handed axe, sledge or spear is
	# always held in both hands; a mace never is; the sword can be either.
	var grip := str(weapon_entry().get("grip", "both_optional"))
	if grip == "two": return &"both"
	if grip == "one": return _carry_side_effective() if _carry_side != &"both" else &"right"
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
## DSH_ANIM: the body animation layer.
##
## The arm IK only places the hands. This owns the BODY, and it is built the way a
## real cut is: the hips start the turn, the chest follows a moment later and carries
## the most, the legs brace against the ground, the whole frame coils before the blow
## and settles after it, and steel biting into something jolts the torso. It replaces
## the old "lean" which moved the whole chain at once and had no anticipation.
const WINDUP_TIME := 0.14          # coil before the cut
const RECOVER_TIME := 0.26         # follow-through and settle
const WINDUP_ANTICIPATION := 0.30  # radians the torso counter-turns while coiling
const CHAIN_RATE := 15.0           # how fast each link catches the one below it
const IMPACT_JOLT_LIMIT := 0.105
const BREATH_RATE := 1.5
const BREATH_AMPLITUDE := 0.013
## The kinetic chain: pelvis, spine, chest, each with its own share and its own
## stiffness, so the turn travels UP the body instead of arriving all at once.
var _chain_yaw := Vector3.ZERO     # pelvis, spine, chest
var _chain_pitch := Vector3.ZERO
var _chain_roll := Vector3.ZERO
var _swing_phase := "idle"
var _phase_t := 0.0
var _impact_jolt := 0.0
var _breath := 0.0
var _brace := 0.0
## Which way the cut is about to go, captured as the coil starts.
var _swing_sign := 1.0
var _anticipation := 0.0
var _bone_thigh_front := -1
var _bone_shin_front := -1
var _bone_thigh_back := -1
var _bone_shin_back := -1

## Runs the phase machine that the body animation is built on. `yaw_target` is the
## turn the cut is heading into, and its sign is what the coil is measured against.
func _advance_swing_phase(delta: float, yaw_target: float) -> void:
	_phase_t += delta
	var entering := false
	match _swing_phase:
		"windup":
			if _phase_t >= WINDUP_TIME: _swing_phase = "strike"; _phase_t = 0.0
		"strike":
			if not _held: _swing_phase = "recover"; _phase_t = 0.0
		"recover":
			if _phase_t >= RECOVER_TIME: _swing_phase = "idle"; _phase_t = 0.0
		_:
			if _held:
				_swing_phase = "windup"
				_phase_t = 0.0
				entering = true
	# The direction the cut will go. Captured as the coil STARTS, because that is when
	# the body has to decide which way to wind up against.
	if entering:
		var sign_now := signf(yaw_target)
		if absf(sign_now) < 0.01: sign_now = signf(_omega.dot(Vector3.UP))
		if absf(sign_now) < 0.01: sign_now = 1.0
		_swing_sign = sign_now
	# How far into the anticipation the body is: 1 at the peak of the coil, 0 in the
	# strike, and a small overshoot during the follow-through.
	var want_anticipation := 0.0
	match _swing_phase:
		"windup": want_anticipation = clampf(_phase_t / maxf(0.001, WINDUP_TIME), 0.0, 1.0)
		"strike": want_anticipation = 0.0
		"recover": want_anticipation = -0.40 * (1.0 - clampf(_phase_t / maxf(0.001, RECOVER_TIME), 0.0, 1.0))
	_anticipation = lerpf(_anticipation, want_anticipation, clampf(12.0 * delta, 0.0, 1.0))
	# The legs brace hardest in the coil and push through the cut.
	var want_brace := 0.0
	if _swing_phase == "windup": want_brace = clampf(_phase_t / maxf(0.001, WINDUP_TIME), 0.0, 1.0)
	elif _swing_phase == "strike": want_brace = 1.0
	elif _swing_phase == "recover": want_brace = 1.0 - clampf(_phase_t / maxf(0.001, RECOVER_TIME), 0.0, 1.0)
	_brace = lerpf(_brace, want_brace, clampf(10.0 * delta, 0.0, 1.0))
	# The jolt has to LAST long enough to be seen: at 4.5/s it was gone in two frames.
	_impact_jolt = maxf(0.0, _impact_jolt - delta * 2.2)
	_breath += delta * BREATH_RATE

## Writes one link of the chain: it chases the link below it, never the target
## directly, which is what makes the turn travel up the body.
func _chain_link(current: float, below: float, delta: float) -> float:
	return lerpf(current, below, clampf(CHAIN_RATE * delta, 0.0, 1.0))

func _apply_chain(bone: int, yaw: float, pitch: float, roll: float,
		axis_up: Vector3, axis_right: Vector3, axis_fwd: Vector3) -> void:
	if bone < 0: return
	if absf(yaw) + absf(pitch) + absf(roll) < 0.002: return
	var turn := Quaternion(axis_up, yaw) * Quaternion(axis_right, -pitch) * Quaternion(axis_fwd, roll)
	var local := _rig.get_bone_pose(bone)
	_rig.set_bone_pose(bone, Transform3D((Basis(turn) * local.basis).orthonormalized(), local.origin))

## A landed blow jolts the frame; this is what the player feels when the blade bites.
func register_impact_jolt(strength: float) -> void:
	_impact_jolt = minf(IMPACT_JOLT_LIMIT, _impact_jolt + IMPACT_JOLT_LIMIT * clampf(strength, 0.0, 1.0))

func _lean_body(want_dir: Vector3, delta: float) -> void:
	var rig_basis := _rig.global_transform.basis
	var inv := rig_basis.inverse()
	var visual: Node3D = _player._visual
	# DSH_ANIM: the body axes must be the CHARACTER's own, not the world's. They used
	# to be the world axes, which is only correct while he happens to be facing along
	# world +Z. Facing any other way, a rotation meant to swing a leg fore and aft swung
	# it SIDEWAYS instead - which is what pulled the legs together on a walk.
	var axis_right := (inv * visual.global_basis.x).normalized()
	var axis_fwd := (inv * visual.global_basis.z).normalized()
	var axis_up := (inv * visual.global_basis.y).normalized()
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
	# 3. Distribute the load over the chain: hips START the turn, the chest carries the
	# most, and each link follows the one below it a moment later. That lag is the
	# difference between a body that swings and a body that is dragged.
	_advance_swing_phase(delta, yaw_target)
	# The coil turns the chest the OPPOSITE way first, then the strike whips it back
	# through. The follow-yaw is DAMPED while the coil is on, otherwise following the
	# mouse simply overpowers the wind-up and the body never reads as winding up.
	var coil := -_swing_sign * WINDUP_ANTICIPATION * _anticipation
	var chest_yaw := _body_yaw * (1.0 - 0.90 * maxf(0.0, _anticipation)) + coil
	# The coil is also, and most clearly, a matter of WEIGHT: the frame settles back and
	# down onto the rear leg, then drives forward through the cut. Unlike the yaw, this
	# reads the same whichever way the blow is aimed, so it is the honest measure of
	# anticipation.
	var strike_drive := 0.0
	if _swing_phase == "strike": strike_drive = 0.055
	elif _swing_phase == "recover": strike_drive = 0.055 * (1.0 - clampf(_phase_t / maxf(0.001, RECOVER_TIME), 0.0, 1.0))
	var lean_pitch := _body_lean.x * (1.0 - 0.75 * maxf(0.0, _anticipation))
	var chest_pitch := lean_pitch + _impact_jolt - _anticipation * 0.22 + strike_drive + sin(_breath) * BREATH_AMPLITUDE
	var chest_roll := _body_lean.y + _anticipation * 0.06
	_chain_yaw.x = _chain_link(_chain_yaw.x, chest_yaw * 0.45, delta)
	_chain_yaw.y = _chain_link(_chain_yaw.y, _chain_yaw.x * 0.85, delta)
	_chain_yaw.z = _chain_link(_chain_yaw.z, _chain_yaw.y, delta)
	_chain_pitch.x = _chain_link(_chain_pitch.x, chest_pitch * 0.40, delta)
	_chain_pitch.y = _chain_link(_chain_pitch.y, _chain_pitch.x * 0.85, delta)
	_chain_pitch.z = _chain_link(_chain_pitch.z, _chain_pitch.y, delta)
	_chain_roll.x = _chain_link(_chain_roll.x, chest_roll * 0.40, delta)
	_chain_roll.y = _chain_link(_chain_roll.y, _chain_roll.x * 0.85, delta)
	_chain_roll.z = _chain_link(_chain_roll.z, _chain_roll.y, delta)
	# DSH_ANIM: THE PELVIS AND THE LEGS ARE NOT TOUCHED. The pelvis is the parent of both
	# legs, so rotating it swings them sideways, and the leg brace rotated the thighs
	# directly - together they read as the legs opening and closing while he walks. The
	# legs belong to the walking gait; this layer now owns everything ABOVE the hips.
	_apply_chain(_bone_spine, _chain_yaw.y, _chain_pitch.y, _chain_roll.y, axis_up, axis_right, axis_fwd)
	_apply_chain(_bone_chest, _chain_yaw.z, _chain_pitch.z, _chain_roll.z, axis_up, axis_right, axis_fwd)
	# 4. The head counter-turns against the torso so the eyes keep following the
	# blade through the whole cut instead of swinging away with the chest.
	if _bone_head >= 0 and (absf(_chain_yaw.z) > 0.02 or absf(_anticipation) > 0.02):
		var head_turn := Quaternion(axis_up, -_chain_yaw.z * 0.45 + _anticipation * WINDUP_ANTICIPATION * 0.5 * _swing_sign)
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
## How close the two BLADES must actually be for the player's cut to be stopped by
## the opponent's steel. This has to be the real thickness of the blades: the
## generous BLOCK_RADIUS above is for judging an incoming blow as parried, and
## using it for the player's own swing made every cut at close range clash.
const BLADE_TOUCH_RADIUS := 0.07

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
		points.append(origin + direction * (0.10 + _weapon_length * float(i) / 4.0))
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
	if to_player.length() <= _weapon_length + 0.75 and _duelist_dir.dot(to_player.normalized()) > 0.72:
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
	var mine_b: Vector3 = _sword_origin + _dir * (0.06 + _weapon_length)
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
	# A SMALL bounce: enough to feel the steel and to stop the cut dead, not enough
	# to throw the sword out of the hand.
	_dir = (_dir - away * 0.30).normalized()
	_omega += away.cross(Vector3.UP) * 2.0
	if _omega.length() > MAX_OMEGA: _omega = _omega.normalized() * MAX_OMEGA
	_block_push = (_block_push + away * 0.04).limit_length(0.5)
	_body_push = (_body_push + away * 0.02).limit_length(BODY_PUSH_LIMIT)
	# The opponent's blade is knocked away too - including the real knight.
	var push_back := -away
	_duelist_dir = (_duelist_dir + push_back * 0.5).normalized()
	_duelist_recoil_until_ms = now + 200
	if is_instance_valid(_npc_rig) and is_instance_valid(_npc_sword):
		_npc_dir = (_npc_dir + push_back * 0.55).normalized()
		_npc_recoil_until_ms = now + 220
		if _npc_state == "strike":
			_npc_state = "recover"
			_npc_timer = 0.0
	_impact_player.global_position = at
	_impact_player.pitch_scale = 1.7
	_impact_player.play()
	_show_spark(at)
	# Real sparks off the steel, thrown away from the point of contact.
	_spark_burst(at, -away, 16)
	_duelist_state = "recover"
	_duelist_timer = 0.0

## Damage to the player: goes through the session health owner when present, so
## the ordinary HUD reacts, with a local sparring counter as a fallback.
var _last_player_hit_ms := -1000
func _apply_player_damage(amount: float, at: Vector3, direction: Vector3) -> void:
	# DSH_MELEE_SET: the SHIELD. A blow that lands inside its coverage is stopped by
	# it: the body takes nothing, no limb is damaged, and the shield wears instead.
	# Checked BEFORE the wound is tracked, which is what makes it a real block.
	if _shield_blocks(at):
		var failed := _shield_take_blow(amount)
		_impact_player.global_position = at
		_impact_player.pitch_scale = 1.35 if failed else 1.1
		_impact_player.play()
		_block_push = (_block_push + direction.normalized() * 0.10).limit_length(0.5)
		print("DSH_SHIELD_BLOCK amount=", amount, " hp=", _shield_hp,
			" coverage=", _shield_coverage(), " broken=", _shield_broken)
		if is_instance_valid(_player): _player.apply_contact_melee_impulse(direction, 8.0)
		return
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
		points.append(_sword_origin + _dir * (0.06 + _weapon_length * t))
	if _prev_points.size() != points.size():
		_prev_points = points
		return
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_player.get_rid()]
	var now := Time.get_ticks_msec()
	var touched: Dictionary = {}
	# A cut MEETS something and stops there. Only the FIRST contact along the swing
	# is resolved: resolving every collider crossed in one frame let a single swing
	# slice through an arm, a chest and both legs at once, with no resistance.
	var best_hit: Dictionary = {}
	var best_distance := INF
	var seen: Dictionary = {}
	# The opponent's steel is a REAL barrier: if our blade meets his anywhere along
	# the swing, the cut stops there and nothing behind it is reached.
	var npc_blade_ok := false
	var npc_a := Vector3.ZERO
	var npc_b := Vector3.ZERO
	if is_instance_valid(_npc_sword) and _npc_sword.visible:
		npc_a = _npc_sword.global_position
		npc_b = npc_a + _npc_sword.global_basis.x.normalized() * (0.06 + _weapon_length)
		npc_blade_ok = true
	var clash := false
	var clash_at := Vector3.ZERO
	for i: int in points.size():
		var from := _prev_points[i]
		var to := points[i]
		if from.distance_squared_to(to) < 1.0e-8: continue
		if npc_blade_ok and _segment_distance(from, to, npc_a, npc_b) <= BLADE_TOUCH_RADIUS:
			clash = true
			clash_at = (from + to) * 0.5
			break
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, excluded)
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		_sweep_rays += 1
		if hit.is_empty(): continue
		_sweep_hits += 1
		var collider: Variant = hit.get("collider")
		if not is_instance_valid(collider): continue
		touched[collider.get_instance_id()] = true
		# Nearest blade point to the grip meets the surface first.
		var reach := from.distance_to(hit.position)
		if reach < best_distance:
			best_distance = reach
			best_hit = hit
			best_hit["_speed"] = from.distance_to(to) / delta
			best_hit["_velocity"] = (to - from) / delta
			best_hit["_index"] = i
	if clash:
		# Steel on steel: a small bounce for both blades, and this swing is spent.
		_register_clash(clash_at)
		for id: Variant in _contact_prev:
			if not touched.has(id): _contact_gap[id] = now
		_contact_prev = touched
		_prev_points = points
		return
	if not best_hit.is_empty():
		_resolve_contact(best_hit, points, now, touched)
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
			_bite_into(0.70)
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
			var strength := _strength_now()
			var npc_cut := clampf((speed * 0.6 - DAMAGE_SPEED_MIN) * DAMAGE_PER_MPS * strength, 4.0, DAMAGE_MAX)
			_swing_start_dir = _dir
			_swing_start_ms = now
			_swing_travel = 0.0
			if npc_part != "":
				# Armour decides how much of the blow actually lands: plate turns an
				# edge but not a point, so a cut mostly rings off the steel while a
				# thrust finds the gaps. This is how Half Sword treats armour, and it
				# is what makes a knight in plate different from a bare body.
				var motion: Vector3 = hit.get("_velocity", Vector3.ZERO)
				if motion.length_squared() < 1.0e-8: motion = _dir * speed
				var along := absf(motion.normalized().dot(_dir))
				var across := sqrt(maxf(0.0, 1.0 - along * along))
				var kind := "slice" if across >= 0.72 else ("stab" if along >= 0.72 else "flat")
				var factor := _armour_factor(npc_part, kind)
				# DSH_MELEE_SET: blunt weapons do not have an edge to turn. A mace or a
				# sledge transmits the blow through plate, which is exactly why they were
				# carried against armour, so they skip the armour reduction entirely.
				if _weapon_crush:
					factor = 1.0
				factor *= _kind_multiplier(kind)
				if _half_sword:
					# Half-swording trades the cut for the point: a thrust from the
					# blade grip goes into the joints whatever the plate says.
					if kind == "stab":
						factor = HALF_SWORD_THRUST
					else:
						factor *= HALF_SWORD_CUT
				var rang_off_plate: bool = is_instance_valid(_npc_rig) and factor < 1.0
				# DSH_ANIM: a blow that bites jolts the body; one that rings off plate
				# jolts it less, which is a real difference in how the two feel.
				register_impact_jolt(0.45 if rang_off_plate else 0.8)
				_bite_into(0.72 if not rang_off_plate else 0.35)
				if rang_off_plate:
					# Steel on plate: clang and sparks instead of a wound.
					_spark_burst(position, -motion.normalized(), 8)
					_impact_player.global_position = position
					_impact_player.pitch_scale = 1.95
					_impact_player.play()
				_npc_take_blade_part(npc_part, position, speed, motion, npc_cut * factor)
			else:
				_npc_take_blade(position, speed, hit.get("_velocity", Vector3.ZERO), npc_cut)
			_last_hit_kind = "slice"
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
		# Steel scraping stone throws a smaller, shorter burst.
		_spark_burst(position, normal, 8)

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
	var strength := _strength_now()
	if _active_side() == &"both": strength *= TWO_HAND_DAMAGE_SCALE
	# DSH_MELEE_SET: the weapon decides how much of each kind of blow it delivers.
	strength *= _kind_multiplier(kind)
	# DSH_ANIM: a landed blow jolts the frame, which is what the player feels.
	register_impact_jolt(0.65)
	_bite_into(0.62)
	_last_hit_kind = kind
	_last_hit_scale = strength
	var damage := clampf((effective * strength - DAMAGE_SPEED_MIN) * DAMAGE_PER_MPS, 0.0, DAMAGE_MAX)
	# A landed blow spends the wind-up; the next hit must be earned again.
	_swing_start_dir = _dir
	_swing_start_ms = now
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
## Builds a transform whose local Y runs along `direction`, which is the axis a
## capsule shape uses.
func _blade_shape_transform(direction: Vector3, origin: Vector3) -> Transform3D:
	var y := direction.normalized()
	if y.length_squared() < 1.0e-8: y = Vector3.UP
	var reference := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.94 else Vector3.RIGHT
	var x := y.cross(reference).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), origin)

## True when the blade itself is inside world geometry or another body. A thin
## capsule along the steel answers this properly, where a single ray would miss a
## blade lying across a wall.
func _blade_penetrates_world(direction: Vector3, origin: Vector3) -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(_world): return false
	var space := _player.get_world_3d().direct_space_state
	if space == null: return false
	var length := 0.06 + _weapon_length
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.030
	capsule.height = length
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = capsule
	params.transform = _blade_shape_transform(direction, origin + direction.normalized() * length * 0.5)
	params.collision_mask = BLADE_PROBE_MASK
	params.exclude = [_player.get_rid()]
	return not space.intersect_shape(params, 1).is_empty()

## Keeps the CARRIED blade out of the world: if the steel would sink into a wall,
## the dummy or a body, it is turned until it lies clear. Bounded and only applied
## while the sword is not being swung, so it can never fight the cut itself.
func _clear_blade_from_world(direction: Vector3) -> Vector3:
	if not _blade_penetrates_world(direction, _sword_origin): return direction
	var up_axis := direction.cross(Vector3.UP)
	if up_axis.length_squared() < 1.0e-6: up_axis = Vector3.RIGHT
	up_axis = up_axis.normalized()
	var side_axis := direction.cross(up_axis).normalized()
	for step: int in BLADE_CLEAR_STEPS:
		var angle := deg_to_rad(12.0) * float(step + 1)
		for axis: Vector3 in [up_axis, -up_axis, side_axis, -side_axis]:
			var rotated := direction.rotated(axis, angle)
			if not _blade_penetrates_world(rotated, _sword_origin):
				return rotated
	# Nothing cleared it: lift the blade straight up, which always frees a blade
	# lying against something low.
	var lifted := (direction + Vector3.UP * 1.2).normalized()
	if not _blade_penetrates_world(lifted, _sword_origin): return lifted
	return direction

## Physics layer the carried blade must stay out of.
const BLADE_PROBE_MASK := 1
## How many 12-degree steps the carried blade may be turned to free it.
const BLADE_CLEAR_STEPS := 6

## ---- half-swording -------------------------------------
## Gripping the BLADE with the off hand: the technique the reference game is named
## after. It gives up reach and cutting power and buys a precise, armour-piercing
## point, which is the only sane way to fight a man in plate.
var _half_sword := false
## How far up the blade the off hand takes hold, in metres from the guard.
const HALF_SWORD_GRIP := 0.40
## Cutting power and thrust power of the half-sword grip.
const HALF_SWORD_CUT := 0.45
const HALF_SWORD_THRUST := 1.90
## World position the off hand is gripping the blade at, for measurement.
var _half_sword_blade_point := Vector3.ZERO

func is_half_swording() -> bool:
	return _half_sword

func set_half_sword(on: bool) -> void:
	if _half_sword == on: return
	_half_sword = on
	if not on: _half_sword_blade_point = Vector3.ZERO
	_update_hint()
	print("DSH_SWORD_PROTO_HALF_SWORD ", on)

## How far the carried sword had to be drawn back out of an obstacle, so the arm
## can be pulled in to match instead of leaving the fist behind.
var _carry_pull := 0.0
## Rig scale, needed to convert metres into bone units.
func _rig_scale() -> float:
	if is_instance_valid(_rig):
		var s := _rig.global_transform.basis.get_scale()
		if s.y > 1.0e-5: return s.y
	return 0.38

var _npc_hit_ms := -10000
var _npc_blade_ms := -10000
## Armour: how much of a SLICE each covered part eats. A thrust is not stopped this
## way - a point goes into the joints and the helmet slits, which is exactly why
## half-swording exists. Unlisted parts (arms, legs, hands) are taken as unarmoured.
const ARMOUR_SLICE := {"head": 0.16, "chest": 0.22, "pelvis": 0.40}
## A thrust against armour actually gets through, rather than merely not being cut.
const ARMOUR_THRUST_BONUS := 1.30

## Damage multiplier for a blow of `kind` landing on `part` of the armoured knight.
func _armour_factor(part: String, kind: String) -> float:
	var base := part
	if base.ends_with("_l") or base.ends_with("_r"): base = base.substr(0, base.length() - 2)
	if kind == "stab": return ARMOUR_THRUST_BONUS
	if kind == "slice": return float(ARMOUR_SLICE.get(base, 1.0))
	# A flat slap lays steel on plate: it bruises at most.
	return 0.35
## While set, the blade is biting into something and cannot accelerate freely.
var _bind_until_ms := 0

## The blade bites into what it hits: it loses speed on impact and stays heavy for
## a moment. That is the resistance that stops a cut from slicing straight through.
func _bite_into(hardness: float) -> void:
	_omega *= clampf(1.0 - hardness, 0.05, 0.92)
	_bind_until_ms = now_ms() + 110
## While set, the knight's blade is still springing back from a parry.
var _npc_recoil_until_ms := 0
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

## ---- DSH_GORE: real severing of the knight's own skin ----------------
## The old dismemberment collapsed a limb's bones to nothing and spawned a stump that
## only looked like a wound. These functions cut the ACTUAL body surface along a plane,
## keep the side that stays on the body (still skinned, so it keeps deforming), and
## hand the side that comes off to the world as rigid debris - the same piece of skin
## that was cut away, not a stand-in.
var _npc_cut_total := 0
var _npc_debris: Array[Dictionary] = []

## The knight's SKINNED mesh instances. The armour plates are attached rigidly to bones,
## so they are deliberately skipped: only real skinned surfaces can be cut.
func _npc_skinned_meshes() -> Array:
	var out: Array = []
	if not is_instance_valid(_npc_rig): return out
	var visual: Node = _npc_rig.get_parent()
	if visual == null: return out
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or not (mesh_node.mesh is ArrayMesh): continue
		var mesh: ArrayMesh = mesh_node.mesh
		for s: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			if arrays.size() <= Mesh.ARRAY_BONES: continue
			var bones = arrays[Mesh.ARRAY_BONES]
			if bones is PackedInt32Array and (bones as PackedInt32Array).size() > 0:
				out.append(mesh_node)
				break
	return out

## Turns a world plane into the mesh's own space.
func _plane_in_local(mesh_node: MeshInstance3D, plane_world: Plane) -> Plane:
	var inv := mesh_node.global_transform.affine_inverse()
	var point_world := plane_world.normal * plane_world.d
	var point_local := inv * point_world
	var normal_local := (inv.basis * plane_world.normal).normalized()
	return Plane(normal_local, normal_local.dot(point_local))

## The flesh material of a fresh cut. One instance for the whole run.
var _flesh_material: StandardMaterial3D

func _flesh() -> StandardMaterial3D:
	if _flesh_material == null:
		_flesh_material = StandardMaterial3D.new()
		_flesh_material.albedo_color = Color(0.42, 0.06, 0.07)
		_flesh_material.roughness = 0.55
		_flesh_material.metallic = 0.0
	return _flesh_material

## Cuts the knight's skin along `plane_world`. `keep_point_world` says which side stays
## on the body. Returns true when anything was actually cut.
func npc_cut_body(plane_world: Plane, keep_point_world: Vector3) -> bool:
	var meshes := _npc_skinned_meshes()
	if meshes.is_empty():
		print("DSH_GORE_CUT refused=no_skinned_mesh")
		return false
	var any := false
	for entry: Variant in meshes:
		var mesh_node: MeshInstance3D = entry
		if not is_instance_valid(mesh_node): continue
		var source: ArrayMesh = mesh_node.mesh
		var local_plane := _plane_in_local(mesh_node, plane_world)
		var keep_local: Vector3 = mesh_node.global_transform.affine_inverse() * keep_point_world
		var keep_front: bool = local_plane.distance_to(keep_local) >= 0.0
		var cut = MeshSever.cut(source, local_plane)
		if cut.triangles_split == 0:
			continue
		var kept_arrays: Array = cut.front_arrays if keep_front else cut.back_arrays
		var gone_arrays: Array = cut.back_arrays if keep_front else cut.front_arrays
		var kept_cap: Array = cut.front_cap_arrays if keep_front else cut.back_cap_arrays
		var gone_cap: Array = cut.back_cap_arrays if keep_front else cut.front_cap_arrays
		# 1. The body keeps its side, with the cut face closed.
		var body_mesh := ArrayMesh.new()
		for arrays: Array in kept_arrays:
			body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		for i: int in body_mesh.get_surface_count():
			var material: Material = source.surface_get_material(mini(i, source.get_surface_count() - 1))
			if material != null: body_mesh.surface_set_material(i, material)
		for arrays: Array in kept_cap:
			body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			body_mesh.surface_set_material(body_mesh.get_surface_count() - 1, _flesh())
		if body_mesh.get_surface_count() > 0:
			mesh_node.mesh = body_mesh
		# 2. The piece that came off goes into the world as the same skin, rigid.
		_spawn_cut_debris(gone_arrays, gone_cap, mesh_node, plane_world.normal)
		any = true
		_npc_cut_total += 1
		print("DSH_GORE_CUT surfaces_in=", source.get_surface_count(),
			" kept=", body_mesh.get_surface_count(),
			" taken=", gone_arrays.size(), " cap=", kept_cap.size(),
			" split=", cut.triangles_split, " boundary=", cut.boundary_segments,
			" cap_triangles=", cut.cap_triangles)
	if not any:
		print("DSH_GORE_CUT refused=nothing_crossed")
	return any

## The cut-away piece: the very same surface, no skeleton, falling under gravity.
func _spawn_cut_debris(gone_arrays: Array, gone_cap: Array, from: MeshInstance3D, push: Vector3) -> void:
	if gone_arrays.is_empty(): return
	var debris_mesh := ArrayMesh.new()
	for arrays: Array in gone_arrays:
		debris_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		debris_mesh.surface_set_material(debris_mesh.get_surface_count() - 1, _flesh())
	for arrays: Array in gone_cap:
		debris_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		debris_mesh.surface_set_material(debris_mesh.get_surface_count() - 1, _flesh())
	if debris_mesh.get_surface_count() == 0: return
	var piece := MeshInstance3D.new()
	piece.name = "KnightCutPiece"
	piece.mesh = debris_mesh
	_world.add_child(piece)
	# The piece keeps the transform of the surface it came from, so it starts exactly
	# where it was cut, not at the origin.
	piece.global_transform = from.global_transform
	_npc_debris.append({
		"node": piece,
		"velocity": push.normalized() * randf_range(0.6, 1.8) + Vector3.UP * randf_range(0.2, 0.8),
		"spin": Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)),
		"age": 0.0,
	})

## Drops the cut pieces under gravity, spins them, and lets them settle.
func _update_npc_debris(delta: float) -> void:
	if _npc_debris.is_empty(): return
	var floor_y: float = 0.0
	if is_instance_valid(_player): floor_y = _player.global_position.y - 0.9
	for index: int in range(_npc_debris.size() - 1, -1, -1):
		var entry: Dictionary = _npc_debris[index]
		var node: Node3D = entry.get("node")
		if not is_instance_valid(node):
			_npc_debris.remove_at(index)
			continue
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		velocity.y -= 9.81 * delta
		var position := node.global_position + velocity * delta
		var spin: Vector3 = entry.get("spin", Vector3.ZERO)
		node.global_position = position
		node.rotate_x(spin.x * delta)
		node.rotate_y(spin.y * delta)
		node.rotate_z(spin.z * delta)
		if position.y <= floor_y:
			# Settled: stop moving, and let it rest flat where it landed.
			velocity = Vector3.ZERO
			position.y = floor_y
			node.global_position = position
		entry["velocity"] = velocity
		entry["age"] = float(entry.get("age", 0.0)) + delta
		_npc_debris[index] = entry

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
		points.append(origin + direction * (0.10 + _weapon_length * float(i) / 4.0))
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
	if to_player.length() <= _weapon_length + 0.8 and _npc_dir.dot(to_player.normalized()) > 0.70:
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
const PART_HP := {"head": 50.0, "chest": 96.0, "pelvis": 96.0,
	"upperarm": 34.0, "forearm": 30.0, "hand": 22.0,
	"thigh": 44.0, "shin": 34.0, "foot": 22.0}
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
		# A dead knight lets go of his sword, and anyone may take it.
		if is_instance_valid(_npc_sword):
			_drop_sword(_npc_sword.global_position, direction, speed)
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
## Blood is drawn from a shared pool: one material and a few drop meshes reused by
## every drop. Creating a fresh material and sphere per drop cost hundreds of GPU
## resources during a fight for exactly the same picture.
var _blood_material: StandardMaterial3D
var _blood_meshes: Array[SphereMesh] = []
const BLOOD_MESH_VARIANTS := 5

func _ensure_blood_resources() -> void:
	if _blood_material == null:
		_blood_material = StandardMaterial3D.new()
		_blood_material.albedo_color = Color(0.42, 0.012, 0.018)
		_blood_material.roughness = 0.35
	if _blood_meshes.is_empty():
		for i: int in BLOOD_MESH_VARIANTS:
			var sphere := SphereMesh.new()
			sphere.radius = lerpf(0.020, 0.050, float(i) / float(BLOOD_MESH_VARIANTS - 1))
			sphere.height = sphere.radius * 2.0
			_blood_meshes.append(sphere)
var _blood_mesh_cursor := 0

func _spray_blood(at: Vector3, direction: Vector3, count: int) -> void:
	# A hard cap keeps a long fight from drowning the scene in drop nodes.
	if _blood_count >= MAX_BLOOD:
		return
	_ensure_blood_resources()
	for i: int in count:
		if _blood_count >= MAX_BLOOD: return
		var drop := MeshInstance3D.new()
		drop.mesh = _blood_meshes[_blood_mesh_cursor % _blood_meshes.size()]
		_blood_mesh_cursor += 1
		drop.material_override = _blood_material
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
	# A sword on the ground can be taken by ANYONE, the player included.
	_register_ground_sword(body)

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

## Walking into a severed piece kicks it along the ground. The pieces live on their
## own layer so they never block the player, but a real nudge still rolls them.
## The kick is ONE impulse per approach with a cooldown: applying it every frame
## used to accelerate a piece away across the map.
func _update_stumps(delta: float) -> void:
	if not is_instance_valid(_player) or _stumps.is_empty(): return
	var now := Time.get_ticks_msec()
	var player_pos: Vector3 = _player.global_position + Vector3.UP * 0.45
	for index: int in range(_stumps.size() - 1, -1, -1):
		var body: Node3D = _stumps[index]
		if not is_instance_valid(body):
			_stumps.remove_at(index)
			continue
		if not body is RigidBody3D: continue
		var rig_body := body as RigidBody3D
		var to_body := rig_body.global_position - player_pos
		to_body.y = 0.0
		var distance := to_body.length()
		if distance > 0.9 or distance < 0.02: continue
		# One nudge per approach, and never on a piece that is already rolling.
		if now - int(rig_body.get_meta("kick_ms", -10000)) < 500: continue
		if rig_body.linear_velocity.length() > 1.6: continue
		rig_body.set_meta("kick_ms", now)
		var away := to_body / distance
		rig_body.apply_central_impulse(away * 0.30 + Vector3.UP * 0.05)
		rig_body.apply_torque_impulse(Vector3(away.z, 0.0, -away.x) * 0.22)
		# Hard caps: a severed piece rolls, it never launches.
		rig_body.linear_velocity = rig_body.linear_velocity.limit_length(2.2)
		rig_body.angular_velocity = rig_body.angular_velocity.limit_length(7.0)
## Shortest distance from the character's OWN head to the blade line. The "sword is
## stuck through his face" pose is measurable this way instead of argued about.
func _head_blade_clearance() -> float:
	if not is_instance_valid(_rig) or not is_instance_valid(_sword) or _bone_head < 0: return 99.0
	var head: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_head).origin
	var a: Vector3 = _sword_origin
	var b: Vector3 = _sword_origin + _dir * (0.06 + _weapon_length)
	return _segment_distance(head, head, a, b)

## Shortest distance from the blade line to the character's own SPINE. Companion to
## the head clearance: together they prove no steel is drawn through the body.
func _body_blade_clearance() -> float:
	if not is_instance_valid(_rig) or not is_instance_valid(_sword) or _bone_chest < 0 or _bone_pelvis < 0: return 99.0
	var chest: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_chest).origin
	var pelvis: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_pelvis).origin
	var a: Vector3 = _sword_origin
	var b: Vector3 = _sword_origin + _dir * (0.06 + _weapon_length)
	return _segment_distance(a, b, chest, pelvis)

func snapshot() -> Dictionary:	return {
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
		"sword_grounded": _sword_grounded, "dropped_at": _dropped_at,
		"head_clearance": _head_blade_clearance(),
		"blade_in_world": _blade_penetrates_world(_dir, _sword_origin),
		"body_clearance": _body_blade_clearance(),
		"armour_plates": _knight_armour.size(), "stump_count": _stumps.size(),
		"sparks": _sparks.size(), "sparks_total": _sparks_total, "half_sword": _half_sword, "half_sword_point": _half_sword_blade_point,
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
		"weapon": _weapon_id, "weapon_mass": _weapon_mass, "weapon_length": _weapon_length,
		"weapon_crush": _weapon_crush, "weapon_category": str(weapon_entry().get("category", "")),
		"throwable": is_throwable(), "throwing": _throwing, "unarmed": _unarmed,
		"aiming_throw": _aiming_throw, "throw_aim_dots": _aim_visible, "throw_aim_range": _aim_range,
		"thrown_total": _thrown_total, "thrown_alive": _thrown_alive(),
		"thrown_at": _thrown_position(), "ground_swords": _ground_swords.size(),
		"shield": shield_status(),
		"blade_from": _sword_origin, "blade_to": _sword_origin + _dir * (0.06 + _weapon_length),
		"blade_body_dot": _dir.dot(_player._visual.global_basis.z) if is_instance_valid(_player) and is_instance_valid(_player._visual) else -1.0,
		"hand_local_z": (_player._visual.global_basis.inverse() * (_sword_origin - _player._visual.global_position)).z if is_instance_valid(_player) and is_instance_valid(_player._visual) else 0.0,
		"upper_len": _upper_len, "fore_len": _fore_len,
		"player_position": _player.global_position if is_instance_valid(_player) else Vector3.ZERO,
		"dummy_position": _dummy.global_position if is_instance_valid(_dummy) else Vector3.ZERO,
		"pole_position": _pole.global_position if is_instance_valid(_pole) else Vector3.ZERO,
		"dummy_distance": _player.global_position.distance_to(_dummy.global_position) if is_instance_valid(_player) and is_instance_valid(_dummy) else -1.0,
		"blade_tip": _sword_origin + _dir * (0.06 + _weapon_length),
		"sweep_rays": _sweep_rays, "sweep_hits": _sweep_hits, "selected": _selected,
		"side": str(_active_side()),
		"swing_phase": _swing_phase, "anticipation": _anticipation, "brace": _brace,
		"omega_speed": _omega.length(), "omega_cap": MAX_OMEGA / _weapon_mass,
		"hand_cmd": _hand_cmd,
		"jolt": _impact_jolt, "chain_yaw": _chain_yaw, "chain_pitch": _chain_pitch,
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
