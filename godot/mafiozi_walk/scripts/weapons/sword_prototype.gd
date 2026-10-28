extends Node3D
const Interception31 = preload("res://scripts/combat/weapon_interception31.gd")
const ModelFinish31 = preload("res://scripts/weapons/weapon_model_finish31.gd")
const ArmorDamage31 = preload("res://scripts/combat/armor_damage31.gd")
const CastleArmorVisual31 = preload("res://scripts/combat/castle_armor_visual.gd")
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
## Shared castle melee host: five weapons, physical contacts, the resident
## opponent, armor and posed mesh dismemberment for both actors. No network.

## DSH_GORE: the planar severer, preloaded because its class_name is not registered in
## a fresh run of this script.
const MeshSever = preload("res://scripts/weapons/mesh_sever.gd")
const CharacterPhysicsDriver31 = preload("res://scripts/character_physics/character_physics_driver.gd")

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
	"hatchet": {"label":"Метательный топорик", "category":"one_hand", "category_label":"ТОПОРИК · МЕТАНИЕ", "length":.42, "mass":.72, "grip":"one", "slice":1.15, "stab":.1, "flat":.5, "crush":false},
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
		"length": 1.12, "mass": 2.7, "grip": "two",
		"slice": 0.18, "stab": 0.10, "flat": 1.6, "crush": true,
	},
	"spear": {
		"label": "Копьё (прототип)", "category": "polearm", "category_label": "КОПЬЁ · КОЛЮЩЕЕ",
		"length": 1.76, "mass": 1.15, "grip": "two",
		"slice": 0.15, "stab": 1.9, "flat": 0.15, "crush": false, "throwable": true,
	},
}
## The weapon this host is currently presenting.
var _weapon_id := "sword"
var _hatchet32:Node

func weapon_ids() -> Array:
	return WEAPONS.keys()

func set_weapon(id: String) -> bool:
	if not WEAPONS.has(id): return false
	if _shield_worn and str(WEAPONS[id].get("grip", "")) == "two": return false
	# A severed hand can never take a two-handed weapon, and a man with no hands
	# cannot take any weapon at all. One-handed weapons remain usable in the
	# surviving hand.
	if not _can_wield_weapon(id):
		print("DSH_SWORD_PROTO_WEAPON_REFUSED reason=severed_hands id=", id)
		return false
	if id == _weapon_id:
		if id=="hatchet" and is_instance_valid(_hatchet32):_hatchet32.selected()
		return true
	_cancel_throw_aim52()
	if is_instance_valid(_hatchet32):_hatchet32.cancel()
	_weapon_id = id
	# The sword-only blade grip cannot survive selection of a mace or another weapon.
	if id != "sword": set_half_sword(false)
	_sword_coast_until_ms31 = 0
	_hammer_torque44 = Vector3.ZERO
	_omega = Vector3.ZERO
	_reset_contact_plane()
	# Old reach and old target contacts do not belong to the newly equipped model.
	_prev_points = PackedVector3Array()
	_contact_prev.clear()
	_contact_gap.clear()
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
		if is_instance_valid(node): node.visible = (other == id) or _ground_swords.has(node)
	_sword = model
	_sword_grounded = _ground_swords.has(model)
	if id == "sledge" and _ready: _begin_sledge_swing35()
	if is_instance_valid(_sword): _sword.visible = true
	if id=="hatchet" and is_instance_valid(_hatchet32):_hatchet32.selected()
	if is_instance_valid(_hint): _update_hint()
	return true

## One model per weapon of the set, built once and kept.
var _weapon_models: Dictionary = {}

## How far the weapon model extends BEHIND its own grip, in metres. A long haft that
## reaches back further than the arm does is a weapon through the chest.
func weapon_rear_extent() -> float:
	if not is_instance_valid(_sword): return 0.0
	var rear := 0.0
	for node: Node in _sword.get_children():
		var mesh_node := node as MeshInstance3D
		if not is_instance_valid(mesh_node) or mesh_node.mesh == null: continue
		var aabb: AABB = mesh_node.transform * mesh_node.mesh.get_aabb()
		rear = maxf(rear, -aabb.position.x)
	return rear

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
const MAX_OMEGA := 15.5         # rad/s
const MAX_ALPHA := 82.0         # rad/s^2, quick but not a teleport into the swing
## Steering: high gain so a flick really whips the blade, light damping and light
## target smoothing. Heavy damping here is what turned cuts into brush strokes.
const STEER_GAIN := 10.5
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
var _sledge_swing_bias35 := Vector2.ZERO
var _sword_origin := Vector3.ZERO
var _dir := Vector3.FORWARD
var _omega := Vector3.ZERO
var _block_push := Vector3.ZERO
## Body load: lean (pitch, roll) and recoil carried by hips/spine/chest.
var _body_load_omega := Vector3.ZERO
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
var _carry_side: StringName = &"left"
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
## On the castle map the host exists for the enemy knight, not for the city test
## range: no dummy, no pole, no crude fallback duelist.
var _castle_enemy_only := false

func set_castle_enemy_only(value: bool) -> void:
	_castle_enemy_only = value
var _rest_dir := Vector3.FORWARD
var _last_block_ms := -1000
## Only a fresh sword input can catch a fast projectile. Holding RMB forever
## still poses the guard, but does not create an endless arrow parry window.
const ARROW_PARRY_WINDOW_MS31 := 280
var _arrow_parry_until_ms31 := -1
var _arrow_parries31 := 0
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
var _last_left_press_ms31 := 0
var _double_strike_until_ms31 := 0
var _sword_coast_until_ms31 := 0
var _arm_release_blend29 := 0.0
var _sword_coast_target31 := Vector3.FORWARD
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

func _sword_coasting31() -> bool:
	return WEAPONS.has(_weapon_id) and not _hold_right and not _throwing and now_ms() < _sword_coast_until_ms31

## The damage comes from the visible weapon's contact speed, its mass and the
## prepared arc. Squared speed makes a slow brush a scratch while a committed
## heavy swing can sever a limb or kill on an unarmoured head hit.
func _impact_damage31(contact_speed: float, prepared: float, kind: String) -> float:
	var grip := TWO_HAND_DAMAGE_SCALE if _active_side() == &"both" else 1.0
	var momentum := sqrt(maxf(0.4, _weapon_mass))
	return clampf(2.5 * contact_speed * contact_speed * prepared * momentum * grip
		* _kind_multiplier("flat" if _weapon_crush else kind), 0.0, 160.0)

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
	# DSH_NET: чужие броски слушаем с момента установки оружия.
	if not Net.event_received.is_connected(_on_net_event):
		Net.event_received.connect(_on_net_event)
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
	var placed := {"dummy": false, "pole": false}
	if not _castle_enemy_only:
		placed = _place_targets()
	else:
		print("DSH_SWORD_PROTO_ENEMY_ONLY player=", _player.global_position)
	_rest_dir = _rest_direction()
	_dir = _rest_dir
	_sword_origin = _rig.global_transform * _rig.get_bone_global_pose(_bone_hand).origin
	_ready = true
	_hatchet32=preload("res://scripts/weapons/throwing_axe32.gd").new();add_child(_hatchet32);_hatchet32.initialize(self)
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
var _melee_heading33: float = NAN

var _embedded29 = preload("res://scripts/combat/embedded_weapon29.gd").new()

func is_steering() -> bool:
	if _embedded29.active(self): return false
	if _shield_guard_active29(): return false
	return _active() and (_hold_left or _hold_right) and not _sword_grounded and not _unarmed \
		and not _aiming_throw and not _throwing and not bool(_world.get("preview_dead")) \
		and not _player._mount_mode and not _player._swimming and not _player._vehicle_hold

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
var _shield_drop_body31: RigidBody3D
var _shield_blocks_total := 0
var _shield_absorbed := 0.0
var _bone_shield_hand := -1
const SHIELD_GRIP_LOCAL29 := Vector3(0.0, 0.20, -0.12)
const SHIELD_FOREARM_STRAP_LOCAL29 := Vector3(0.0, -0.10, -0.12)
var _shield_guard_previous29 := false
var _shield_resume_frame29 := -1

## The shield is worn on the RIGHT hand, as asked. On this mirrored rig `_arm_set` maps
## the string "right" to the bones that RENDER on the character's right.

## Guard intent wins over attack, even when both buttons arrive in one frame.
func _shield_guard_active29() -> bool:
	return _shield_worn and not _shield_broken and (_hold_right or (not _synthetic_hands and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)))

func _sync_shield_guard29() -> void:
	var guarding := _shield_guard_active29()
	if guarding != _shield_guard_previous29:
		_shield_guard_previous29 = guarding
		_prev_points = PackedVector3Array()
		_contact_prev.clear(); _contact_gap.clear()
		_sword_coast_until_ms31 = 0
		_omega = Vector3.ZERO
		_held_prev = false
		_hand_cmd = _hand
		_steer_target = _dir
		_shield_resume_frame29 = Engine.get_physics_frames() + 1
		if has_method("_clay_invalidate_motion28"):
			call("_clay_invalidate_motion28")
			if guarding: get("_async_cut28").cancel("shield_guard")
	if guarding:
		_held = false
		_held_event = false
		_blocking = true
		_sword_coast_until_ms31 = 0
		_omega = Vector3.ZERO
		_prev_points = PackedVector3Array()

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
	if not _shield_guard_active29() or _shield_raise < SHIELD_RAISE_NEEDED: return false
	return _shield_centre().distance_to(at) <= _shield_coverage()

## Takes the wear of a stopped blow. Returns true when the shield has just failed.
func _shield_take_blow(amount: float) -> bool:
	var wear := maxf(1.0, amount * SHIELD_WEAR_SCALE)
	_shield_hp = maxf(0.0, _shield_hp - wear)
	_shield_blocks_total += 1
	_shield_absorbed += amount
	if _shield_hp <= 0.0 and not _shield_broken:
		_shield_broken = true
		_shatter_shield31()
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
	# One closed wooden panel, with a continuous rim following the silhouette.
	var panel := MeshInstance3D.new()
	panel.mesh = ModelFinish31.shield_plate()
	panel.material_override = plank
	shield.add_child(panel)
	var rim := MeshInstance3D.new()
	rim.mesh = ModelFinish31.shield_rim()
	rim.material_override = _mat_steel
	shield.add_child(rim)
	# The boss: a domed steel centre that is what the blows actually strike.
	var boss := MeshInstance3D.new()
	var boss_mesh := SphereMesh.new()
	boss_mesh.radius = 0.075
	boss_mesh.height = 0.11
	boss.mesh = boss_mesh
	boss.material_override = _mat_steel
	boss.position = Vector3(0.0, 0.10, 0.055)
	shield.add_child(boss)
	# Arm straps on the back, where the hand actually goes.
	for y: float in [0.20, -0.10]:
		var strap := MeshInstance3D.new()
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.24, 0.05, 0.20)
		strap.mesh = strap_mesh
		strap.material_override = _mat_leather
		strap.position = Vector3(0.0, y, -0.09)
		shield.add_child(strap)
	ModelFinish31.finish(shield)
	return shield

## Places the shield in its hand and raises it as the right button is held.
func _place_shield() -> void:
	if not _shield_worn: return
	if not is_instance_valid(_shield): _shield = _build_shield_model(_world)
	if not is_instance_valid(_shield) or not is_instance_valid(_rig): return
	var arm := _arm_set(_shield_side())
	if arm.hand < 0 or arm.upper < 0 or arm.fore < 0:
		_shield.visible = false
		return
	_shield.visible = not _shield_broken
	if _shield_broken: return
	var body_basis: Basis = _player._visual.global_basis.orthonormalized()
	var shoulder: Vector3 = _rig.global_transform * (_chain_global(arm.clav) * arm.rest_upper).origin
	var chest: Vector3 = _rig.global_transform * _chain_global(_bone_chest).origin
	var side := signf((body_basis.inverse() * (shoulder - chest)).x)
	var raised := clampf(_shield_raise, 0.0, 1.0)
	var want: Vector3 = shoulder + body_basis * Vector3(side * 0.025, lerpf(-0.38, -0.10, raised), lerpf(0.18, 0.28, raised))
	var want_rig: Vector3 = _rig.global_transform.affine_inverse() * want
	var grip_axis: Vector3 = (_rig.global_basis.inverse() * body_basis.x).normalized()
	_pose_arm_ik(arm.clav, arm.upper, arm.fore, arm.hand, arm.rest_upper, arm.rest_fore,
		arm.rest_hand, arm.offset, want_rig, grip_axis, 1.0, true, arm.pole)
	_rig.force_update_all_bone_transforms()
	# The back straps lie along the actual forearm; the handle crosses the palm.
	# Place the shield only after the arm solve, using the final displayed hand.
	var elbow: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(arm.fore).origin
	var wrist: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(arm.hand).origin
	var up: Vector3 = (wrist - elbow).normalized()
	var right: Vector3 = up.cross(body_basis.z).normalized()
	if right.length_squared() < 0.5: right = body_basis.x
	var front: Vector3 = right.cross(up).normalized()
	if front.dot(body_basis.z) < 0.0: right = -right; front = -front
	var shield_basis := Basis(right, up, front).orthonormalized()
	var palm_world := Basis(front, up, -right).orthonormalized()
	var fore_global: Transform3D = _chain_global(arm.fore)
	var palm_rig: Basis = _rig.global_basis.inverse() * palm_world
	_rig.set_bone_pose(arm.hand, Transform3D((fore_global.basis.inverse() * palm_rig).orthonormalized(), arm.rest_hand.origin))
	_rig.force_update_all_bone_transforms()
	var palm: Vector3 = _palm_position(_shield_side())
	_shield.global_transform = Transform3D(shield_basis, palm - shield_basis * SHIELD_GRIP_LOCAL29)

## What the shield is doing, for the HUD and for the checks.
func shield_status() -> Dictionary:
	return {
		"worn": _shield_worn, "broken": _shield_broken,
		"hp": _shield_hp, "max_hp": SHIELD_MAX_HP,
		"raise": _shield_raise, "coverage_m": _shield_coverage(),
		"blocks": _shield_blocks_total, "absorbed": _shield_absorbed,
		"centre": _shield_centre(),
		"guard_intent": _shield_guard_active29(),
		"grip_local": SHIELD_GRIP_LOCAL29,
		"forearm_strap_local": SHIELD_FOREARM_STRAP_LOCAL29,
	}

## Equips or stows the shield, and puts it on the ground with the weapon when dropped.
func _right_hand_available_for_shield31() -> bool:
	return _sword_grounded or _unarmed or _shield_only31 or str(weapon_entry().get("grip", "")) != "two"

func can_wear_shield31() -> bool:
	return _right_hand_available_for_shield31() and not _shield_broken \
		and not is_instance_valid(_shield_drop_body31)

var _shield_only31 := false

func set_shield_only31(enabled: bool) -> void:
	_shield_only31 = enabled
	_unarmed = enabled
	if is_instance_valid(_sword):
		_sword.visible = not enabled and _selected and not _sword_grounded

func set_shield_worn(worn: bool) -> bool:
	if worn and not can_wear_shield31(): return false
	if worn and _hand_lost31(&"right"): return false
	_shield_worn = worn
	if worn:
		_carry_side = &"left"
		_half_sword = false
	if not worn and is_instance_valid(_shield):
		_shield.visible = false
	if is_instance_valid(_shield):
		_shield.visible = worn and not _shield_broken
	if worn and is_instance_valid(_rig): _place_shield()
	return true

## G with RMB releases the actual right-hand shield as a physics body. E can
## recover that same model while the right hand is free again.
func drop_shield_to_ground31() -> bool:
	if not _shield_worn: return false
	_place_shield()
	if not is_instance_valid(_shield): return false
	var wrapper := ModelFinish31.make_ground_drop28(_shield, _world, _player._visual.global_basis.z, 2.6, 0.0)
	_shield_drop_body31 = wrapper
	_shield_worn = false
	_shield_raise = 0.0
	_shield = null
	return true

func try_pickup_shield31() -> bool:
	if not is_instance_valid(_shield_drop_body31) or _shield_worn or _shield_broken: return false
	if not _right_hand_available_for_shield31() or _hand_lost31(&"right"): return false
	if _player.global_position.distance_to(_shield_drop_body31.global_position) > GROUND_PICKUP_RANGE: return false
	for child: Node in _shield_drop_body31.get_children():
		if child is Node3D and not child is CollisionShape3D:
			_shield = child as Node3D
			break
	if not is_instance_valid(_shield): return false
	_shield.reparent(_world, true)
	_shield_drop_body31.queue_free()
	_shield_drop_body31 = null
	return set_shield_worn(true)

## A failed shield becomes several small physical pieces; it cannot be equipped
## again until a real replacement is supplied by the future equipment owner.
func _shatter_shield31() -> void:
	if not is_instance_valid(_shield): return
	var pose := _shield.global_transform
	_shield.visible = false
	_shield.queue_free()
	_shield = null
	_shield_worn = false
	_shield_raise = 0.0
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var shard := RigidBody3D.new()
			shard.name = "BrokenShieldPiece31"
			shard.add_to_group("shield_shard31")
			shard.mass = 0.45
			shard.collision_layer = 1
			shard.collision_mask = 1
			_world.add_child(shard)
			shard.global_transform = pose.translated_local(Vector3(x * 0.14, y * 0.17, 0.0))
			var block := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.27, 0.32, 0.045)
			block.mesh = mesh
			block.material_override = _mat_wood
			shard.add_child(block)
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = mesh.size
			collider.shape = box
			shard.add_child(collider)
			shard.apply_central_impulse(pose.basis * Vector3(x * 0.5, y * 0.5, 1.5))

## DSH_MELEE_SET: builds the model for whichever weapon is equipped. Every model is
## laid out with its point or head along local +X, because that is the axis the
## sweep, the IK and the placement maths all assume.
func _build_weapon_model(parent: Node3D, id: String) -> Node3D:
	match id:
		"hatchet":return preload("res://scripts/weapons/hatchet_model32.gd").build(self,parent)
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
	_mat_steel.albedo_color = Color(0.74, 0.78, 0.84); _mat_steel.metallic = 0.92; _mat_steel.roughness = 0.38
	_mat_edge = StandardMaterial3D.new()
	_mat_edge.albedo_color = Color(0.88, 0.91, 0.95); _mat_edge.metallic = 0.95; _mat_edge.roughness = 0.27
	_mat_dark_steel = StandardMaterial3D.new()
	_mat_dark_steel.albedo_color = Color(0.50, 0.54, 0.60); _mat_dark_steel.metallic = 0.86; _mat_dark_steel.roughness = 0.36
	_mat_iron = StandardMaterial3D.new()
	_mat_iron.albedo_color = Color(0.38, 0.39, 0.42); _mat_iron.metallic = 0.72; _mat_iron.roughness = 0.48
	_mat_leather = StandardMaterial3D.new()
	_mat_leather.albedo_color = Color(0.22, 0.14, 0.10); _mat_leather.roughness = 0.88
	_mat_brass = StandardMaterial3D.new()
	_mat_brass.albedo_color = Color(0.50, 0.39, 0.19); _mat_brass.metallic = 0.78; _mat_brass.roughness = 0.34
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
		flange.position = Vector3(0.52, cos(angle) * 0.048, sin(angle) * 0.048)
		flange.rotation = Vector3(angle, 0.0, 0.0)
		mace.add_child(flange)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.046; cap_mesh.height = 0.092
	cap.mesh = cap_mesh
	cap.material_override = _mat_steel
	cap.position = Vector3(0.60, 0.0, 0.0)
	mace.add_child(cap)
	ModelFinish31.finish(mace)
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
	spike.rotation = Vector3(0.0, 0.0, PI)
	spike.position = Vector3(0.86, -0.11, 0.0)
	axe.add_child(spike)
	ModelFinish31.finish(axe)
	return axe

## Two-handed sledgehammer: long haft, a heavy square block head with banded faces.
func _build_sledge_model(parent: Node3D) -> Node3D:
	_weapon_materials()
	var sledge := Node3D.new()
	sledge.name = "PrototypeSledge"
	parent.add_child(sledge)
	_add_haft(sledge, -0.34, 1.06, 0.034, 0.026, _mat_wood)
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
	head_mesh.size = Vector3(0.16, 0.32, 0.16)
	head.mesh = head_mesh
	head.material_override = _mat_iron
	head.position = Vector3(1.02, 0.0, 0.0)
	sledge.add_child(head)
	for side: float in [0.16, -0.16]:
		var face := MeshInstance3D.new()
		var face_mesh := BoxMesh.new()
		face_mesh.size = Vector3(0.17, 0.04, 0.17)
		face.mesh = face_mesh
		face.material_override = _mat_dark_steel
		face.position = Vector3(1.02, side, 0.0)
		sledge.add_child(face)
	# Banding either side of the eye.
	for at: float in [0.92, 1.08]:
		var band := MeshInstance3D.new()
		var band_mesh := CylinderMesh.new()
		band_mesh.top_radius = 0.040; band_mesh.bottom_radius = 0.040; band_mesh.height = 0.05
		band.mesh = band_mesh
		band.material_override = _mat_brass
		band.rotation = Vector3(0.0, 0.0, PI * 0.5)
		band.position = Vector3(at, 0.0, 0.0)
		sledge.add_child(band)
	ModelFinish31.finish(sledge)
	return sledge

## Two-handed spear: a long ash shaft with a leaf-shaped head, a collar and a
## butt-spike, balanced so it can also be thrown.
func _build_spear_model(parent: Node3D) -> Node3D:
	_weapon_materials()
	var spear := Node3D.new()
	spear.name = "PrototypeSpear"
	parent.add_child(spear)
	# A spear is held a third of the way from the butt, so only a short length of haft
	# sits behind the fist. The old model ran 1.05 m backwards - which is a spear going
	# straight through the man holding it.
	_add_haft(spear, -0.30, 1.60, 0.028, 0.022, _mat_wood)
	_add_grip(spear, -0.22, 0.02, 0.031)
	_add_grip(spear, 0.14, 0.46, 0.030)
	# Collar and the leaf head.
	var collar := MeshInstance3D.new()
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.030; collar_mesh.bottom_radius = 0.030; collar_mesh.height = 0.05
	collar.mesh = collar_mesh
	collar.material_override = _mat_brass
	collar.rotation = Vector3(0.0, 0.0, PI * 0.5)
	collar.position = Vector3(1.55, 0.0, 0.0)
	spear.add_child(collar)
	var blade := MeshInstance3D.new()
	var blade_mesh := PrismMesh.new()
	blade_mesh.size = Vector3(0.09, 0.30, 0.020)
	blade_mesh.left_to_right = 0.5
	blade.mesh = blade_mesh
	blade.material_override = _mat_edge
	blade.position = Vector3(1.69, 0.0, 0.0)
	blade.rotation = Vector3(0.0, 0.0, -PI * 0.5)
	spear.add_child(blade)
	# Butt-spike, which is what makes a spear throwable and still a weapon.
	var butt := MeshInstance3D.new()
	var butt_mesh := CylinderMesh.new()
	butt_mesh.top_radius = 0.026; butt_mesh.bottom_radius = 0.001; butt_mesh.height = 0.10
	butt.mesh = butt_mesh
	butt.material_override = _mat_steel
	butt.rotation = Vector3(0.0, 0.0, PI * 0.5)
	butt.position = Vector3(-0.36, 0.0, 0.0)
	spear.add_child(butt)
	ModelFinish31.finish(spear)
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
	steel.albedo_color = Color(0.74, 0.78, 0.84); steel.metallic = 0.92; steel.roughness = 0.38
	var dark_steel := StandardMaterial3D.new()
	dark_steel.albedo_color = Color(0.52, 0.56, 0.62); dark_steel.metallic = 0.85; dark_steel.roughness = 0.34
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.22, 0.14, 0.10); leather.roughness = 0.88
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.50, 0.39, 0.19); brass.metallic = 0.78; brass.roughness = 0.34
	var start := 0.155                     # blade starts after the ricasso
	var blade_node := MeshInstance3D.new()
	blade_node.mesh = ModelFinish31.sword_blade()
	blade_node.material_override = steel
	sword.add_child(blade_node)
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
		ring_node.rotation = Vector3(0.0, 0.0, PI * 0.5)
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
	ModelFinish31.finish(sword)
	return sword

func _build_impacts() -> void:
	_build_melee_audio31()
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
	var kind := "metal"
	var context: Dictionary = get_meta("contact_fx31",{})
	if int(context.get("frame",-100)) == Engine.get_physics_frames() and Vector3(context.get("point",Vector3.INF)).distance_squared_to(at)<.0025:
		kind=str(context.get("kind","metal"))
	_sparks_total += _ensure_contact_sparks31().burst(at,normal,count,kind,self)


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
		_hint.text = ""
		return
	var mode := "ПОЛУМЕЧ: рука на лезвии, укол в щели доспеха" if _half_sword else "ЛКМ + ПКМ — двуручный хват, удар сильнее"
	var right_hint := "Удерживать ПКМ и двигать мышью — удар правой рукой" if _right_hand_weapon54() else "ПКМ — блок / щит"
	var text := "ТЕСТОВЫЙ МЕЧ (прототип)\nЛКМ и мышь — рубящий удар\n" + right_hint + "\n" + mode + "\nКолесо мыши — укол вперёд / оттянуть назад\nX — полумеч (хват за лезвие против доспеха)\nG — бросить меч"
	if reachable and not is_instance_valid(_world.get("preview_castle")):
		text += "\nE — поднять оружие"
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
func drop_sword_to_ground(require_embedded31:bool=false) -> bool:
	if _weapon_id=="hatchet" and is_instance_valid(_hatchet32) and _sword==_hatchet32.empty:return false
	if not _selected or _sword_grounded or not is_instance_valid(_sword): return false
	var embedded_drop:Node=_embedded29.make_drop31(self)
	if require_embedded31 and not is_instance_valid(embedded_drop):return false
	_sword_grounded = true
	_reset_contact_plane()
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
	var flat := (_place_basis(at, forward) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)).basis
	if not is_instance_valid(embedded_drop):
		_sword.global_transform = ModelFinish31.resting_transform(_sword, flat, ground if ground.is_finite() else at - Vector3.UP * 0.05)
		ModelFinish31.make_ground_drop28(_sword, _world, forward, 1.2 if _weapon_id == "sledge" else 0.65)
	else:
		_dropped_at=_sword.global_position
	_register_ground_sword(_sword)
	_stamp_ground_weapon(_sword, _weapon_id)
	if _weapon_id=="hatchet" and is_instance_valid(_hatchet32):_hatchet32.mark_ground32(_sword)
	_update_hint()
	print("DSH_SWORD_PROTO_DROPPED at=", at, " ground_swords=", _ground_swords.size())
	return true

## Roll back a physical drop if the inventory handoff refuses to stow the item.
## Both operations are synchronous, so no physics frame observes this state.
func cancel_ground_drop31() -> bool:
	if not _sword_grounded or not is_instance_valid(_sword): return false
	var attachment:Node=_embedded29.dropped_attachment31(_sword)
	if is_instance_valid(attachment):
		if not attachment.can_regrab(self):return false
		attachment.prepare_regrab(self)
	_ground_swords.erase(_sword)
	ModelFinish31.recover_ground_drop28(_sword, _world)
	_sword_grounded = false
	_dropped_at = Vector3.ZERO
	if not _selected: set_selected(true)
	_sword.visible = true
	_reset_contact_plane()
	_update_hint()
	_embedded29.restore_regrab31(self)
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
	# A finished weapon root owns every material mesh, including grip and guard.
	# Only physical drop wrappers need unwrapping.
	if node.has_meta("visual_budget31"): return node
	if node is MeshInstance3D: return node
	if node.name == "PrototypeSpear" and _ground_weapon_of(node) == "spear": return node
	for child: Node in node.get_children():
		if child is CollisionShape3D: continue
		if child is Node3D: return child as Node3D
	return null

## E: take the nearest sword on the ground - the player's own or a knight's. A
## sword already in the hand cannot be swapped for another: drop it first.
func try_pickup_sword(allow_inactive: bool = false) -> bool:
	if is_instance_valid(_hatchet32) and _hatchet32.pickup_near():return true
	if not _selected and not allow_inactive: return false
	var arsenal: Node = _world.get("preview_weapons") if is_instance_valid(_world) else null
	var storage: Node = arsenal.get("castle_storage_owner") if is_instance_valid(arsenal) else null
	# Castle drops deselect the cached host without grounding its display model.
	# The live equipment/hand ledger, not that dormant model, owns empty hands.
	var castle_empty := allow_inactive and not _selected and is_instance_valid(storage) \
		and str(storage.get("_hand_weapon")).is_empty() \
		and str(arsenal.fire_state.get("weaponId", "none")) == "none"
	# Thrown away counts as empty-handed just as much as put down.
	if not _sword_grounded and not _unarmed and not castle_empty and not is_instance_valid(storage):
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
	var pickup_id := stamp if stamp != "" else _weapon_id
	# A two-handed weapon cannot be taken when one hand is gone, and no weapon can
	# be taken with no hands. The surviving hand can still take a one-handed sword.
	if not _can_wield_weapon(pickup_id):
		print("DSH_SWORD_PROTO_PICKUP_REFUSED reason=severed_hand grip=", str(WEAPONS.get(pickup_id, {}).get("grip", "")))
		return false
	var previous_id := _weapon_id
	var previous_empty := _unarmed or _sword_grounded or castle_empty
	var foreign_sword := pickup_id == "sword" and node == _npc_dropped_sword31
	if is_instance_valid(storage) and storage.has_method("can_adopt_ground_melee31"):
		var preflight: Dictionary = storage.can_adopt_ground_melee31(pickup_id, previous_id, previous_empty)
		if not bool(preflight.get("ok", false)):
			print("DSH_SWORD_PROTO_PICKUP_REFUSED reason=", preflight.get("reason", "storage"))
			return false
	if _shield_worn and not is_instance_valid(storage) and WEAPONS.has(pickup_id) and str(WEAPONS[pickup_id].get("grip", "")) == "two":
		print("DSH_SWORD_PROTO_PICKUP_REFUSED reason=shield_occupies_right_hand")
		return false
	# Validate the physical model before the ledger changes. Equipping through
	# storage can fail (for example, a menu or presentation transition), so it
	# must finish before the ground node/model is removed from world ownership.
	var pickup_model: Node3D = _sword if taken_own else _take_sword_model(node)
	if not is_instance_valid(pickup_model):
		print("DSH_SWORD_PROTO_PICKUP_REFUSED reason=bad_model")
		return false
	var embedded_pickup:Node=_embedded29.dropped_attachment31(pickup_model)
	if is_instance_valid(embedded_pickup) and not bool(embedded_pickup.call("can_regrab",self)):
		return false
	if is_instance_valid(storage) and storage.has_method("adopt_ground_melee31"):
		var adopted: Dictionary = storage.adopt_ground_melee31(pickup_id, previous_id, previous_empty,
			foreign_sword, pickup_model)
		if not bool(adopted.get("ok", false)):
			print("DSH_SWORD_PROTO_PICKUP_REFUSED reason=", adopted.get("reason", "adopt_failed"))
			return false
	if is_instance_valid(embedded_pickup):embedded_pickup.call("prepare_regrab",self)
	_ground_swords.erase(node)
	if stamp != "" and stamp != _weapon_id:
		# The known ID and shield policy were checked above; set_weapon is now
		# only a local model switch after storage accepted the same weapon.
		set_weapon(stamp)
	if not taken_own:
		# A knight's sword: hold its model, and leave the player's own sword lying
		# where it fell so it can still be collected later.
		var model := pickup_model
		if model == node:
			ModelFinish31.recover_ground_drop28(model, _world)
			if model.get_parent() != _world: model.reparent(_world, true)
		else:
			node.remove_child(model)
			_world.add_child(model)
			node.queue_free()
		var cached: Node3D = _weapon_models.get(_weapon_id)
		if is_instance_valid(cached) and cached != model and not _ground_swords.has(cached): cached.queue_free()
		_weapon_models[_weapon_id] = model
		_sword = model
		_dropped_at = Vector3.ZERO
	ModelFinish31.recover_ground_drop28(_sword, _world)
	_sword_grounded = false
	_unarmed = false
	_arm_ready_ms = Time.get_ticks_msec() + 450
	if is_instance_valid(_sword):
		_sword.visible = true
		_sword.global_transform = embedded_pickup.get("saved_pose") if is_instance_valid(embedded_pickup) else _place_basis(_player.global_position + Vector3.UP * 1.2, _dir)
	if not bool(get_meta("defer_embedded_restore31",false)):_embedded29.restore_regrab31(self)
	_update_hint()
	print("DSH_SWORD_PROTO_PICKED distance=", found.get("distance", 0.0), " own=", taken_own,
		" ground_swords=", _ground_swords.size())
	return true

## Drops the held sword at an exact point (used by the driven test and diagnostics).
func drop_sword_at(point: Vector3) -> bool:
	if not _selected or _sword_grounded or not is_instance_valid(_sword): return false
	_sword_grounded = true
	_reset_contact_plane()
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
	# A deferred host can be equipped during scene construction, before the
	# castle's colliders have entered the physics space. Never pass INF from a
	# failed ground query into a target transform or direction normalisation.
	if not dummy_at.is_finite(): dummy_at = base + dummy_dir * 2.6
	if not pole_at.is_finite(): pole_at = base + pole_dir * 2.4
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
	if not bool(_world.get("castle_map")) and _spawn_resident_knight(duelist_at):
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
	if is_instance_valid(_hatchet32) and _hatchet32.input(event):
		get_viewport().set_input_as_handled();return
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
		# G chooses the held hand: RMB releases the right-hand shield, LMB the
		# left-hand weapon. A two-handed weapon is one object and always drops.
		if code == KEY_G:
			# Castle storage owns carried weapons and their physical dropped models.
			var weapon_host: Node = _world.get('preview_weapons') if is_instance_valid(_world) else null
			var storage: Node = weapon_host.get('castle_storage_owner') if is_instance_valid(weapon_host) else null
			if is_instance_valid(storage):
				var stored: Dictionary = storage.snapshot()
				var prefer_shield: bool = _shield_worn and _hold_right
				var item_id: String = 'shield' if prefer_shield or str(stored.get('hand_weapon', '')).is_empty() else str(stored.get('hand_weapon', ''))
				if stored.get('carried', {}).has(item_id):
					if bool(storage.drop_held(prefer_shield).get('ok', false)):
						get_viewport().set_input_as_handled()
					return
			var released := false
			if _shield_worn and _hold_right: released = drop_shield_to_ground31()
			elif not _sword_grounded: released = drop_sword_to_ground()
			if released:
				get_viewport().set_input_as_handled()
				return
		if code == KEY_E and is_instance_valid(_world) and _world.has_method("_current_door_action"):
			var primary: Dictionary = _world.call("_current_door_action")
			if str(primary.get("key", "F")) == "E" and str(primary.get("owner", "")) != "castle_pickup": return
		if code == KEY_E and try_pickup_shield31():
			get_viewport().set_input_as_handled()
			return
		if code == KEY_E and (_sword_grounded or _unarmed):
			# DSH_CATAPULT: if the siege machine claims E here - a stone to lift, a spoon to
			# load, a frame to stand at - a dropped sword must NOT steal the key. Both
			# prototypes listen for E, and this is exactly what made the stone impossible to
			# pick up whenever the sword happened to be lying on the ground.
			var siege: Variant = _world.get("preview_catapult") if is_instance_valid(_world) else null
			if is_instance_valid(siege) and siege.has_method("wants_e") and bool(siege.call("wants_e")):
				return
			if try_pickup_sword():
				get_viewport().set_input_as_handled()
				return
		# X: half-sword - the off hand takes the blade instead of the hilt.
		if code == KEY_X and not _sword_grounded:
			set_half_sword(not _half_sword)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and _embedded29.active(self):
			if button.button_index == MOUSE_BUTTON_LEFT: _hold_left = button.pressed
			else: _hold_right = button.pressed
			_aiming_throw = false
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			if _shield_guard_active29():
				_hold_left = button.pressed
				_sync_shield_guard29()
				get_viewport().set_input_as_handled()
				return
			# Aimed throw: hold RMB to see the arc, then hold and release LMB.
			# Without RMB, LMB keeps the spear's ordinary melee strike.
			if is_throwable() and not _unarmed and not _sword_grounded and (
				(button.pressed and _aiming_throw and not _hold_left) or (not button.pressed and _throwing)):
				if button.pressed: _begin_throw()
				else: _release_throw()
				get_viewport().set_input_as_handled()
				return
			if button.pressed and not _hold_left and WEAPONS.has(_weapon_id):
				if _weapon_id == "sledge": _begin_sledge_swing35()
				var press_ms := Time.get_ticks_msec()
				if press_ms - _last_left_press_ms31 <= 350:
					_double_strike_until_ms31 = press_ms + 450
				_last_left_press_ms31 = press_ms
				_arrow_parry_until_ms31 = now_ms() + ARROW_PARRY_WINDOW_MS31
				_sword_coast_until_ms31 = 0
			elif not button.pressed and _hold_left and WEAPONS.has(_weapon_id):
				_sword_coast_until_ms31 = now_ms() + (180 if _weapon_id == "sword" else int(180.0 * sqrt(_weapon_mass)))
				_sword_coast_target31 = _dir
				_steer_target = _dir
			_held_event = button.pressed
			_hold_left = button.pressed
			_held = _hold_left or (_hold_right and not _shield_worn and str(weapon_entry().get("grip", "")) != "two")
			_player.set("_sword_lock", false)
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			if _shield_worn:
				_hold_right = button.pressed
				_aiming_throw = false
				_sync_shield_guard29()
				_blocking = _shield_guard_active29()
				_held = _hold_left and not _blocking
				get_viewport().set_input_as_handled()
				return
			# Holding RMB enters aim; releasing it cancels an unfinished wind-up.
			_aiming_throw = button.pressed and is_throwable()
			if not button.pressed and _throwing:
				_throwing = false
			if button.pressed and not _hold_right and (_weapon_id == "sword" or _right_hand_weapon54()):
				_arrow_parry_until_ms31 = now_ms() + ARROW_PARRY_WINDOW_MS31
			if _right_hand_weapon54():
				if button.pressed and not _hold_right:
					_sword_coast_until_ms31 = 0
				elif not button.pressed and _hold_right and not _hold_left:
					_sword_coast_until_ms31 = now_ms() + 180
					_sword_coast_target31 = _dir
					_steer_target = _dir
			_hold_right = button.pressed
			_held = _hold_left or (_hold_right and not _shield_worn and str(weapon_entry().get("grip", "")) != "two")
			_player.set("_sword_lock", false)
			get_viewport().set_input_as_handled()
			return
		# Wheel belongs to preview_player camera zoom, including while steering.
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_hold_right = button.pressed
			_held = _hold_left or _hold_right
			_player.set("_sword_lock", false)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _held_event or _held):
		if _embedded29.active(self): return
		if _shield_guard_active29(): return
		var motion := event as InputEventMouseMotion
		# Mouse sensors keep reporting a pixel or two while the hand is still; that
		# noise is what made the blade ripple. Anything below the floor is ignored.
		if absf(motion.relative.x) + absf(motion.relative.y) < MOUSE_NOISE_FLOOR:
			return
		# Keep events available to the camera predicate; only melee changes facing.
		if is_steering():
			if not is_finite(_melee_heading33): _melee_heading33 = _player._visual.global_rotation.y
			_melee_heading33 -= motion.relative.x * _player.mouse_sensitivity
		# Preserve mouse travel even on fast devices. The command saturates at the
		# same range the arm uses, so reversing never spends 161px unloading an
		# invisible command reserve. Slew, torque and swept collisions bound motion.
		_hand_cmd.x = clampf(_hand_cmd.x + motion.relative.x * MOUSE_TO_HAND, -1.0, 1.0)
		_hand_cmd.y = clampf(_hand_cmd.y - motion.relative.y * MOUSE_TO_HAND, -1.0, 1.0)

func _active() -> bool:
	return _ready and _selected and is_instance_valid(_player) and _player.is_inside_tree() \
		and bool(_player.get("_free_mouse_look")) and _player.get("_pose_authority") == &"on_foot" \
		and not _player._text_control_focused()

## Called by the arsenal host when the prototype sword is equipped or removed.
func set_selected(value: bool) -> void:
	if _selected == value: return
	_selected = value
	_reset_contact_plane()
	if not _selected:
		_cancel_throw_aim52()
		_arrow_parry_until_ms31 = -1
		_spear_cast_pending31 = false
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
		if is_instance_valid(_sword): _sword.visible = _sword_grounded
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

func _spear_aim_direction52() -> Vector3:
	var camera_origin := _camera.global_position
	var forward := -_camera.global_basis.z.normalized()
	var target := camera_origin + forward * 160.0
	var query := PhysicsRayQueryParameters3D.create(camera_origin, target, 1, [_player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): target = hit.position
	# A shoulder-launched spear converges on the camera crosshair, like the bow.
	var direction := target - _sword_origin
	return direction.normalized() if direction.length_squared() > 0.01 else forward

func _begin_sledge_swing35() -> void:
	# Keep the accepted carried direction when a free swing starts. Store the
	# angular origin separately: changing _hand here also lifts the two-hand IK.
	var forward := Vector3(-_camera.global_basis.z.x, 0.0, -_camera.global_basis.z.z)
	if forward.length_squared() < 0.000001 or not _dir.is_finite(): return
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var camera_pitch := asin(clampf(-_camera.global_basis.z.y, -1.0, 1.0))
	var neutral_pitch := atan2(0.35, 0.55 + _thrust * 1.10)
	_sledge_swing_bias35 = Vector2(atan2(_dir.dot(right), _dir.dot(forward)) - _hand.x * 2.05,
		asin(clampf(_dir.y, -1.0, 1.0)) - camera_pitch - neutral_pitch - _hand.y * 1.35)
	_steer_target = _dir

func _target_direction() -> Vector3:
	if is_throwable() and (_aiming_throw or _spear_cast_pending31): return _spear_aim_direction52()
	var basis := _camera.global_basis
	# Angular steering gives the full requested lateral arc independently of
	# vertical aim. A linear vector plus fixed forward bias compressed side cuts.
	var yaw := clampf(_hand.x, -1.0, 1.0) * (2.05 if _weapon_id in ["axe", "sledge"] else 1.48)
	var neutral_pitch := atan2(0.35, 0.55 + _thrust * 1.10)
	var pitch := clampf(neutral_pitch + clampf(_hand.y, -1.0, 1.0) * 1.35, -1.10, 1.48)
	if _weapon_id == "sledge":
		yaw += _sledge_swing_bias35.x
		pitch = neutral_pitch + clampf(_hand.y, -1.0, 1.0) * 1.35 + _sledge_swing_bias35.y
	if _weapon_id in ["sword", "axe", "sledge"]:
		# Rotate a lateral stroke around world up. Mixing a pitched camera forward
		# vector with its right vector changed elevation as yaw crossed the front.
		var forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
		if forward.length_squared() < 0.000001: forward = Vector3.FORWARD
		forward = forward.normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var elevation := clampf(asin(clampf(-basis.z.y, -1.0, 1.0)) + pitch, -1.10, 1.48)
		return ((forward * cos(yaw) + right * sin(yaw)) * cos(elevation) + Vector3.UP * sin(elevation)).normalized()
	var flat := -basis.z * cos(yaw) + basis.x * sin(yaw)
	var target := (flat * cos(pitch) + basis.y * sin(pitch)).normalized()
	if not target.is_finite(): return _rest_dir
	return target

func _steer(delta: float) -> void:
	if _embedded29.active(self):
		_dir = _embedded29.status().axis
		_omega = Vector3.ZERO
		return
	if _blocking and (not _hold_left or _shield_guard_active29()):
		_hammer_torque44 = Vector3.ZERO
		# GUARD (RMB): the blade is placed where the mouse points and simply stays
		# there - a real, physical barrier for incoming blows, not a swing.
		var guard := _guard_direction()
		_dir = _dir.slerp(guard, clampf(14.0 * delta, 0.0, 1.0)).normalized()
		_omega = Vector3.ZERO
		return
	if not _held:
		_hammer_torque44 = Vector3.ZERO
		# Carried stance: a stable, body-relative ready angle (up, a little out and
		# forward). Deriving it from the fist made the blade swing into the body as
		# the walk animation turned the wrist.
		var carry := _clear_blade_from_world(_clear_blade_from_body(_carry_direction()))
		_dir = _dir.slerp(carry, clampf(7.0 * delta, 0.0, 1.0)).normalized()
		_omega = Vector3.ZERO
		return
	# The spring target must be reachable. A partial body limit left the
	# target behind the actual pose limit and fed torque into that limit forever.
	# Only existing blade momentum travels after release; no timed phase turns it.
	var target := _sword_coast_target31 if _sword_coasting31() else _target_direction()
	if _weapon_id not in ["axe", "sledge"]:
		target = _constrain_to_body(_constrain_forward(target), 0.10).normalized()
	# Smooth the target itself: the camera basis and the mouse both feed it, and a
	# raw per-frame target is what showed up as a ripple on the blade.
	if _steer_target.length_squared() < 1.0e-6:
		_steer_target = target
	elif _steer_target.dot(target) > 0.9999:
		# Nearly parallel endpoints have no reliable slerp rotation axis.
		# Normalized lerp keeps the same smoothing rate at this numerical limit.
		_steer_target = _steer_target.lerp(target, clampf(STEER_TARGET_SMOOTH * delta, 0.0, 1.0)).normalized()
	elif _weapon_id == "spear" and _aiming_throw:
		# Turning the torso across an opposite old aim can make Vector3.slerp's
		# internal axis numerically non-unit. Normalized lerp stays continuous.
		_steer_target = _steer_target.lerp(target, clampf(STEER_TARGET_SMOOTH * delta, 0.0, 1.0)).normalized()
	else:
		_steer_target = _steer_target.slerp(target, clampf(STEER_TARGET_SMOOTH * delta, 0.0, 1.0)).normalized()
	target = _steer_target
	target = _contact_direction(target, true)
	# A larger error drives a proportionally faster blade, so a decisive flick
	# whips the sword through instead of dragging it. Damping is essential now that
	# the view is free: without it the blade rings against a moving target and the
	# sword visibly buzzes while the button is merely held.
	var axis := _dir.cross(target)
	var angle := _dir.angle_to(target)
	var desired := Vector3.ZERO
	var one_hand_sword := _weapon_id == "sword" and _active_side() != &"both"
	if WEAPONS.has(_weapon_id) and not (_weapon_id == "spear" and _aiming_throw):
		# Drive the weapon with bounded torque, then brake near the aimed endpoint.
		# Mass changes acceleration and reversal, not an extra division of both
		# target speed and gain that made the hammer crawl for its entire arc.
		var heavy := _weapon_id == "sledge"
		var speed_limit := 7.6 if heavy else (9.0 if one_hand_sword else 10.0)
		var acceleration := 28.0 if heavy else (40.0 if one_hand_sword else 52.0)
		if _weapon_id != "sword":
			# Sword-equivalent steering with one weight scale for all other melee.
			# The authored mass affects acceleration, reversal and maximum speed;
			# the two-hand IK adds a support hand without changing the mouse target.
			speed_limit = 9.0 / pow(_weapon_mass, 0.18)
			acceleration = 40.0 / sqrt(_weapon_mass)
			if _weapon_id in ["sledge", "axe"]:
				speed_limit *= 1.35
				acceleration *= 1.80
		if _weapon_id=="hatchet":speed_limit=10.2;acceleration=46.0
		if _weapon_id in ["axe","sledge"] and has_method("_lab_melee_limits29"):
			var laboratory_limits:Vector2=call("_lab_melee_limits29",speed_limit,acceleration)
			speed_limit=laboratory_limits.x
			acceleration=laboratory_limits.y
		# Sledge uses the same steering in every direction; lower acceleration
		# and speed preserve its weight without a separate overhead constraint.
		# The stopping distance grows with kinetic energy. Brake before the aimed
		# endpoint, without an underdamped spring repeatedly overshooting it.
		var stopping_speed := sqrt(2.0 * acceleration * angle) * 0.72
		var aim_speed := minf(speed_limit, minf(stopping_speed, angle * 14.0))
		var aim_velocity := axis.normalized() * aim_speed if axis.length_squared() > 0.00000001 else Vector3.ZERO
		# A reversal first brakes the old swing, then accelerates with the weapon's
		# weight. This removes the long uncontrolled tail without adding top speed.
		var reversing := aim_velocity.dot(_omega) < 0.0
		var torque := ((aim_velocity - _omega) / maxf(delta, 0.001)).limit_length(acceleration * (1.65 if reversing else 1.0))
		if _sword_coasting31() and not _hold_left:
			# Release spends existing momentum only: no target spring or new energy.
			torque = -_omega * (7.0 if _weapon_id == "sword" else 7.0 / sqrt(_weapon_mass))
		_omega = (_omega + torque * delta).limit_length(speed_limit)
		if Time.get_ticks_msec() < _bind_until_ms: _omega = _omega.limit_length(1.6)
	else:
		if angle > 1.0e-4 and axis.length_squared() > 1.0e-10:
			desired = axis.normalized() * clampf(angle * STEER_GAIN / _weapon_mass, 0.0, MAX_OMEGA / _weapon_mass)
		desired -= _omega * STEER_DAMPING
		if Time.get_ticks_msec() < _bind_until_ms: desired = desired.limit_length(1.6)
		_omega += (desired - _omega).limit_length(25.0 * delta / _weapon_mass)
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
	if _player_death_driver31 != null and bool(_world.get("preview_dead")):
		var fallen: Dictionary = _player_death_driver31.advance(delta, false)
		if bool(fallen.get("valid", false)) and bool(fallen.get("pose", {}).get("valid", false)):
			_player._apply_selected_pose(fallen.pose)
		elif not bool(fallen.get("valid", false)):
			_player_death_physics31.reason = str(fallen.get("reason", "advance_failed"))
	var active := _active()
	# Camera lock follows the real button state and survives a momentary loss of
	# activity, so the view can never drift while the blade is being steered.
	_held = _hold_left or _held_event or _sword_coasting31() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or (_hold_right and not _shield_worn and str(weapon_entry().get("grip", "")) != "two") \
		or (_aiming_throw and is_throwable()) or _spear_cast_pending31 or _spear_follow_left > 0.0
	# Remember which single hand is holding the sword, so releasing a button keeps
	# the grip exactly there. Both buttons = two-handed (right hand leads).
	if _hold_left and not _hold_right and not _hand_lost31(&"left"): _carry_side = &"left"
	elif _hold_right and not _hold_left and not _hand_lost31(&"right") and not _shield_worn: _carry_side = &"right"
	elif _hand_lost31(_carry_side) and not _both_hands_lost():
		_carry_side = &"right" if not _hand_lost31(&"right") else &"left"
	# Single-hand sword/mace RMB uses the approved free swing in the right hand.
	# Shields, two-handed weapons and half-sword retain their existing controls.
	_blocking = _hold_right and not _hold_left and not is_throwable() and not _shield_worn and not _right_hand_weapon54()
	_sync_shield_guard29()
	_player.set("_sword_lock", false)
	var spear_pose_wanted := active and _weapon_id == "spear" and not _sword_grounded and (
		(_aiming_throw and not _unarmed) or _spear_cast_pending31 or _spear_follow_left > 0.0)
	_spear_aim_blend = move_toward(_spear_aim_blend, 1.0 if spear_pose_wanted else 0.0, delta * 6.0)
	# DSH_MELEE_SET: with the weapon thrown the hands are empty, so no steering and no
	# arm IK except the brief visible follow-through after release.
	if _unarmed:
		if _spear_follow_left > 0.0:
			_solve_arm(delta)
			_spear_follow_left = maxf(0.0, _spear_follow_left - delta)
		# A thrown weapon frees the hands; RMB still raises the shield.
		if _shield_worn and not _shield_broken:
			_shield_raise = move_toward(_shield_raise, 1.0 if _hold_right else 0.0, SHIELD_RAISE_RATE * delta)
		_reset_contact_plane()
		_held = false
		_hold_left = false
		if not _shield_worn: _hold_right = false
		_throwing = false
		_omega = Vector3.ZERO
		_prev_points = PackedVector3Array()
		_update_city_npc(delta)
		_step_thrown(delta)
		_step_net_thrown(delta)
		return
	if not active:
		_reset_contact_plane()
		_spear_cast_pending31 = false
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
		if is_instance_valid(_sword): _sword.visible = _sword_grounded
		_prev_points = PackedVector3Array()
		_block_push = _block_push.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
		# NPC and airborne weapons are world actors: keep their physics running
		# while the menu or another weapon owns player input.
		if not bool(_world.get("preview_dead")):
			_update_city_npc(delta)
			_step_thrown(delta)
			_step_net_thrown(delta)
		return
	if not _synthetic_hands:
		# Real input: the buttons are read from the engine every frame, so a missed
		# release event can never leave the view locked.
		_hold_left = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_hold_right = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		_held_event = _hold_left
		_held = _hold_left or _hold_right or _sword_coasting31() or _spear_cast_pending31
		_sync_shield_guard29()
		_player.set("_sword_lock", false)
	if is_instance_valid(_sword): _sword.visible = true
	if _sword_grounded:
		_reset_contact_plane()
		if _shield_worn and not _shield_broken:
			_shield_raise = move_toward(_shield_raise, 1.0 if _hold_right else 0.0, SHIELD_RAISE_RATE * delta)
		_held = false
		_hold_left = false
		if not _shield_worn: _hold_right = false
		_blocking = false
		_omega = Vector3.ZERO
		_prev_points = PackedVector3Array()
		if is_instance_valid(_player): _player.set("_sword_lock", false)
		_update_city_npc(delta)
		return
	_arm_release_blend29 = 1.0 if _held else (0.0 if _weapon_id == "spear" else move_toward(_arm_release_blend29, 0.0, delta * 3.0))
	_face_spear_aim31(delta)
	_dir = _contact_direction(_melee_axis_envelope29(_dir))
	if not _held:
		# Released: the mouse command decays so the blade returns to rest.
		_hand_cmd = _hand_cmd.lerp(Vector2.ZERO, clampf(REST_RETURN_RATE * delta, 0.0, 1.0))
	# Slew the driving value toward the mouse command at a bounded rate.
	var to_command := _hand_cmd - _hand
	var max_step := HAND_SLEW_RATE * delta
	if _weapon_id in ["axe", "sledge"]: max_step *= 1.35
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
	if _spear_cast_pending31:
		_spear_cast_elapsed31 = minf(_spear_cast_elapsed31 + delta, SPEAR_CAST_TIME31)
	_solve_arm(delta)
	# The blade is never allowed to point behind the player.
	_dir = _contact_direction(_melee_axis_envelope29(_dir))
	_advance_edge(delta)
	if _spear_cast_pending31 and _spear_cast_elapsed31 >= SPEAR_CAST_TIME31:
		_launch_spear_from_hand31()
	# The opponent is a real body: his step, gravity and pose belong to the physics
	# frame, otherwise move_and_slide() leaves him hanging in the air.
	_update_city_npc(delta)
	# DSH_MELEE_SET: a thrown weapon flies on its own, once per physics tick.
	_step_thrown(delta)
	_step_net_thrown(delta)
	# The wind-up runs on the physics clock so a missed release cannot leave it stuck.
	if _throwing:
		_throw_windup = minf(_throw_windup + delta, THROW_WINDUP_TIME)

## ---- DSH_MELEE_SET: throwing -----------------------------------------
## A throwable weapon (the spear) can be wound up with RMB + LMB. The model leaves
## the hand as a real projectile: it flies under gravity, sticks where it lands, and
## is stamped as the weapon it is so E lifts the same spear back up.
const THROW_SPEED_MIN := 11.0
const THROW_SPEED_MAX := 26.0
const THROW_WINDUP_TIME := 0.55
const THROW_GRAVITY := 9.81
## The spear's actual model tip is at local +X 1.84 m from its root.
const SPEAR_TIP_OFFSET := 1.84
const SPEAR_STICK_DEPTH := 0.12
const SPEAR_BODY_PIERCE_DEPTH := 0.38
const SPEAR_LETHAL_SPEED := 22.0
const SPEAR_LETHAL_INCIDENCE := 0.72
const SPEAR_FOLLOW_TIME := 0.24
const SPEAR_CAST_TIME31 := 0.18
var _throwing := false
var _spear_cast_pending31 := false
var _spear_cast_elapsed31 := 0.0
var _spear_cast_power31 := 0.0
## Right button held with a throwable weapon: the aiming stance, which draws the arc.
var _aiming_throw := false
var _throw_windup := 0.0
## Wall-clock start of the wind-up, so the power cannot be lost to a skipped frame.
var _throw_start_ms := 0
var _spear_aim_blend := 0.0
var _spear_aim_heading31 := 0.0
var _spear_aim_heading_active31 := false
var _spear_follow_left := 0.0
var _spear_release_power := 0.0
var _thrown: Array[Dictionary] = []
## DSH_NET: видимые дубли чужих бросков (летят, втыкаются, урона не наносят).
var _net_thrown: Array[Dictionary] = []
var _unarmed := false
var _thrown_total := 0

func is_throwable() -> bool:
	return bool(weapon_entry().get("throwable", false))

func _face_spear_aim31(delta: float) -> void:
	if _embedded29.active(self): return
	if not is_steering(): _melee_heading33 = NAN
	elif not is_finite(_melee_heading33): _melee_heading33 = _player._visual.global_rotation.y
	if _held and WEAPONS.has(_weapon_id) and not _aiming_throw and is_instance_valid(_player):
		# Mouse look and free weapon aim share one facing frame. Without this,
		# the camera/front-body constraints fought and sent side cuts vertically.
		var melee_visual: Node3D = _player._visual
		var view_forward: Vector3 = -_camera.global_basis.z
		if is_instance_valid(melee_visual) and Vector2(view_forward.x, view_forward.z).length_squared() > 0.01:
			var camera_yaw := atan2(view_forward.x, view_forward.z)
			var wanted_yaw := _melee_heading33 if is_steering() and is_finite(_melee_heading33) else camera_yaw
			# A stationary view must not accumulate whole revolutions of foot facing.
			# Reuse the existing authored swing excursion; discard saturated heading
			# so reversing the mouse immediately unloads the stance.
			wanted_yaw = camera_yaw + clampf(wrapf(wanted_yaw - camera_yaw, -PI, PI), -BODY_YAW_LIMIT_SWING, BODY_YAW_LIMIT_SWING)
			if is_steering(): _melee_heading33 = wanted_yaw
			var yaw_error := wrapf(wanted_yaw - melee_visual.global_rotation.y, -PI, PI)
			melee_visual.rotation.y += clampf(yaw_error, -8.0 * delta, 8.0 * delta)
			_player._heading = melee_visual.rotation.y - deg_to_rad(_player.visual_yaw_degrees)
		_spear_aim_heading_active31 = false
		return
	if _weapon_id != "spear" or not _aiming_throw or not is_instance_valid(_player):
		_spear_aim_heading_active31 = false
		return
	var visual: Node3D = _player._visual
	if not is_instance_valid(visual): return
	var forward: Vector3 = -_camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01: return
	var target_yaw := atan2(forward.x, forward.z)
	if not _spear_aim_heading_active31:
		_spear_aim_heading31 = visual.global_rotation.y
		_spear_aim_heading_active31 = true
	_spear_aim_heading31 = lerp_angle(_spear_aim_heading31, target_yaw, clampf(5.0 * delta, 0.0, 1.0))
	visual.rotation.y = _spear_aim_heading31 - _player.global_rotation.y

## ---- throwing aim -----------------------------------------------
## While RMB aims a throwable weapon, a dotted arc shows where the
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

func _throw_preview_owned52() -> bool:
	return _active() and _aiming_throw and is_throwable() and not _unarmed and not _sword_grounded and not _spear_cast_pending31

func _cancel_throw_aim52() -> void:
	_aiming_throw = false
	_throwing = false
	_hold_left = false
	_hold_right = false
	_held_event = false
	_spear_cast_pending31 = false
	_spear_aim_blend = 0.0
	_hide_throw_dots()

func _update_throw_preview() -> void:
	if not _throw_preview_owned52():
		_hide_throw_dots()
		return
	_build_throw_dots()
	var speed: float = _throw_speed_now()
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_player.get_rid()]
	if is_instance_valid(_npc_corpse31): excluded.append(_npc_corpse31.get_rid())
	var at := _sword_origin + _dir.normalized() * SPEAR_TIP_OFFSET
	var velocity := _dir.normalized() * speed
	var shown := 0
	var travelled := 0.0
	for i: int in MAX_THROW_DOTS:
		velocity += Vector3.DOWN * THROW_GRAVITY * THROW_PREVIEW_STEP
		var next := at + velocity * THROW_PREVIEW_STEP
		var hit: Dictionary = {}
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(at, next, 1, excluded)
			query.hit_from_inside = true
			hit = space.intersect_ray(query)
			if not hit.is_empty(): next = hit.get("position", next)
		var dot: MeshInstance3D = _aim_dots[i]
		dot.visible = true
		dot.global_position = next
		dot.scale = Vector3.ONE * clampf(1.15 - float(i) / float(MAX_THROW_DOTS), 0.25, 1.15)
		shown += 1
		travelled += at.distance_to(next)
		at = next
		if not hit.is_empty(): break
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
	var power := _spear_cast_power31 if _spear_cast_pending31 else (0.5 if not _throwing else clampf(_throw_held_seconds() / THROW_WINDUP_TIME, 0.0, 1.0))
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
	if _embedded29.active(self):_cancel_throw_aim52();return
	if not _active() or _unarmed or not is_throwable(): return
	if _throwing or _spear_cast_pending31: return
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
	if _embedded29.active(self):_cancel_throw_aim52();return
	if not _throwing: return
	var held := _throw_held_seconds()
	_throwing = false
	if _sword_grounded or _unarmed or not is_throwable(): return
	_spear_cast_power31 = clampf(held / THROW_WINDUP_TIME, 0.0, 1.0)
	_spear_cast_elapsed31 = 0.0
	_spear_cast_pending31 = true
	# The same visible spear stays in the fist while the shoulder and elbow drive
	# it forward. The projectile is created only at the end of that cast.

func _launch_spear_from_hand31() -> void:
	if _embedded29.active(self):_cancel_throw_aim52();return
	if not _spear_cast_pending31: return
	_spear_cast_pending31 = false
	if _sword_grounded or _unarmed or not is_throwable(): return
	var power := _spear_cast_power31
	if not is_instance_valid(_sword): return
	var speed := lerpf(THROW_SPEED_MIN, THROW_SPEED_MAX, power)
	# Input arrives between render poses. Sample the visible model itself so its
	# first projectile frame starts exactly where the player saw it in the hand.
	var direction: Vector3 = _sword.global_basis.x.normalized()
	var from: Vector3 = _sword.global_position + direction * SPEAR_TIP_OFFSET
	# The spear leaves the hand and lives in the world from here on.
	_sword.visible = true
	_thrown.append({
		"node": _sword, "velocity": direction * speed, "prev": from,
		"weapon": _weapon_id, "alive": true, "fired_ms": Time.get_ticks_msec(),
	})
	_unarmed = true
	_hide_throw_dots()
	_spear_release_power = power
	_spear_follow_left = SPEAR_FOLLOW_TIME
	_thrown_total += 1
	_announce_throw(_weapon_id, from, direction * speed)
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

# ------------------------------------------------------------------ DSH_NET
## Бросок меча/копья. Оружие уже летит как снаряд с ручной интеграцией, поэтому по
## сети идёт одно событие: какое оружие, откуда, с какой скоростью. Вторая сторона
## строит такой же видимый снаряд и ведёт его тем же шагом, но урона не наносит:
## урон остаётся за владельцем броска.
func _announce_throw(weapon_id: String, origin: Vector3, velocity: Vector3) -> void:
	if not Net.online():
		return
	print("DSH_NET_THROW_SENT weapon=", weapon_id, " from=", origin, " v=", velocity)
	Net.send_event("throw", {"w": weapon_id, "o": origin, "v": velocity})


func _on_net_event(kind: String, data: Dictionary, from_id: int) -> void:
	if kind != "throw" or from_id == Net.local_id:
		return
	var origin: Variant = data.get("o")
	var velocity: Variant = data.get("v")
	if not (origin is Vector3) or not (velocity is Vector3):
		return
	_spawn_net_thrown(str(data.get("w", "sword")), origin, velocity, from_id)


func _spawn_net_thrown(weapon_id: String, origin: Vector3, velocity: Vector3, from_id: int) -> void:
	var model: Node3D = _build_weapon_model(_world, weapon_id)
	if not is_instance_valid(model):
		return
	model.visible = true
	model.global_position = origin
	_net_thrown.append({"node": model, "v": velocity, "age": 0.0, "stuck": false})
	print("DSH_NET_THROW_PROXY weapon=", weapon_id, " from=", from_id, " at=", origin)


func _step_net_thrown(delta: float) -> void:
	if _net_thrown.is_empty():
		return
	for index: int in range(_net_thrown.size() - 1, -1, -1):
		var entry: Dictionary = _net_thrown[index]
		var node: Variant = entry.get("node")
		if not is_instance_valid(node):
			_net_thrown.remove_at(index)
			continue
		var age: float = float(entry.get("age", 0.0)) + delta
		entry["age"] = age
		if bool(entry.get("stuck", false)):
			_net_thrown[index] = entry
			if age > 12.0:
				(node as Node3D).queue_free()
				_net_thrown.remove_at(index)
			continue
		var velocity: Vector3 = entry.get("v", Vector3.ZERO)
		var from: Vector3 = (node as Node3D).global_position
		velocity += Vector3.DOWN * THROW_GRAVITY * delta
		entry["v"] = velocity
		var to: Vector3 = from + velocity * delta
		var hit: Dictionary = {}
		if is_inside_tree():
			var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
			if space != null:
				var query := PhysicsRayQueryParameters3D.create(from, to, 1)
				query.hit_from_inside = true
				hit = space.intersect_ray(query)
		if not hit.is_empty():
			(node as Node3D).global_position = hit.get("position", to)
			entry["stuck"] = true
			_net_thrown[index] = entry
			print("DSH_NET_THROW_LAND at=", hit.get("position", to))
			continue
		(node as Node3D).global_position = to
		_net_thrown[index] = entry
		if age > 12.0:
			(node as Node3D).queue_free()
			_net_thrown.remove_at(index)


## Тест/отладка: бросить оружие без анимации замаха.
func debug_throw() -> Dictionary:
	# Тест/отладка: бросаемое оружие в наборе только копьё, поэтому переключаемся
	# на него и ставим модель перед игроком, если она ещё не в руке.
	if not is_throwable():
		_weapon_id = "spear"
		_sword_grounded = false
		_unarmed = false
		if not is_instance_valid(_sword):
			_sword = _build_weapon_model(_world, "spear")
		if not is_instance_valid(_sword):
			return {"ok": false, "reason": "no_spear_model"}
		var dir: Vector3 = -_player.global_transform.basis.z
		dir.y = 0.0
		if dir.length_squared() < 1.0e-6:
			dir = Vector3.FORWARD
		dir = dir.normalized()
		var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP)).orthonormalized()
		_sword.global_transform = Transform3D(basis, _player.global_position + Vector3.UP * 1.4)
	if _unarmed or not is_throwable():
		return {"ok": false, "reason": "not_armed", "weapon": _weapon_id}
	_spear_cast_power31 = 1.0
	_spear_cast_pending31 = true
	_launch_spear_from_hand31()
	return {"ok": true, "weapon": _weapon_id, "thrown": _thrown_total}


func _step_thrown(delta: float) -> void:
	if _thrown.is_empty(): return
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_player.get_rid()]
	if is_instance_valid(_npc_corpse31): excluded.append(_npc_corpse31.get_rid())
	for index: int in range(_thrown.size() - 1, -1, -1):
		var entry: Dictionary = _thrown[index]
		var node: Node3D = entry.get("node")
		if not is_instance_valid(node):
			_thrown.remove_at(index)
			continue
		if not bool(entry.get("alive", false)): continue
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		var from: Vector3 = entry.get("prev", node.global_position + node.global_basis.x * SPEAR_TIP_OFFSET)
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
		node.global_position = to - velocity.normalized() * SPEAR_TIP_OFFSET
		if velocity.length_squared() > 1.0e-6:
			_orient_thrown_spear(node, velocity)

## The spear mesh points along local +X. Node3D.look_at() points local -Z,
## which made the thrown spear fly sideways despite its correct velocity.
func _orient_thrown_spear(node: Node3D, direction: Vector3) -> void:
	var x := direction.normalized()
	if x.length_squared() < 1.0e-6: return
	var up := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var y := (up - x * up.dot(x)).normalized()
	node.global_basis = Basis(x, y, x.cross(y).normalized())

## The weapon comes to rest where it struck, is stamped so it can be lifted again, and
## hurts whatever it hit on the way in.
func _land_thrown(index: int, hit: Dictionary, velocity: Vector3) -> void:
	var entry: Dictionary = _thrown[index]
	var node: Node3D = entry.get("node")
	var point: Vector3 = hit.get("position", node.global_position)
	var collider: Variant = hit.get("collider")
	var direction := velocity.normalized()
	var depth := SPEAR_STICK_DEPTH
	var debris_before := _npc_debris.size()
	var stumps_before := _stumps.size()
	# Only a ray from the flying TIP into this resident's real collider can wound.
	# The outer walking capsule may win the ray before a tagged bone hitbox does.
	var npc_part := ""
	if _is_npc_collider(collider):
		if collider.has_meta("sword_npc_part"):
			npc_part = str(collider.get_meta("sword_npc_part"))
		elif is_instance_valid(_npc_rig):
			var nearest: Dictionary = _npc_part_at(point)
			npc_part = str(nearest.get("key", ""))
			var bone_name := str(nearest.get("sever", ""))
			if bone_name.ends_with("_l") or bone_name.ends_with("_r"):
				npc_part += bone_name.substr(bone_name.length() - 2)
	if npc_part != "" and str(entry.get("weapon", "")) == "spear":
		depth = _thrown_spear_hit_npc(npc_part, point, hit.get("normal", Vector3.ZERO), velocity)
	elif is_instance_valid(collider) and collider is Node3D and collider.has_meta("sword_target"):
		_damage_dummy(collider, point, velocity.length(), direction, Time.get_ticks_msec())
	var rest := point - direction * (SPEAR_TIP_OFFSET - depth)
	node.global_position = rest
	if direction.length_squared() > 1.0e-6:
		_orient_thrown_spear(node, direction)
	if npc_part != "" and str(entry.get("weapon", "")) == "spear":
		_embed_spear_in_npc31(node, collider, npc_part, point, debris_before, stumps_before)
	entry["alive"] = false
	entry["velocity"] = Vector3.ZERO
	_thrown[index] = entry
	_register_ground_sword(node)
	_stamp_ground_weapon(node, str(entry.get("weapon", _weapon_id)))
	var speed := velocity.length()
	print("DSH_MELEE_THROWN_LAND weapon=", entry.get("weapon", ""), " at=", point,
		" speed=", speed, " distance=", _player.global_position.distance_to(point))

func _embed_spear_in_npc31(node: Node3D, collider: Variant, part: String,
		point: Vector3, debris_before: int, stumps_before: int) -> void:
	var piece := _nearest_new_detached_piece31(point, debris_before, stumps_before)
	if is_instance_valid(piece):
		node.reparent(piece, true)
		node.set_meta("spear_embedded_part31", part)
		return
	var anchor: Node3D = null
	if collider is Node3D and collider != _npc_body and _is_npc_collider(collider):
		anchor = collider as Node3D
	elif is_instance_valid(_npc_rig):
		anchor = _npc_rig.get_node_or_null("Hit" + part) as Node3D
	if not is_instance_valid(anchor): anchor = _npc_body
	if is_instance_valid(anchor):
		node.reparent(anchor, true)
		node.set_meta("spear_embedded_part31", part)

func _nearest_new_detached_piece31(point: Vector3, debris_from: int, stumps_from: int,
		allow_stump: bool = true) -> Node3D:
	var best: Node3D = null
	var best_distance := 1.6
	for index: int in range(debris_from, _npc_debris.size()):
		var piece: Node3D = _npc_debris[index].get("node")
		if not is_instance_valid(piece) or not piece is RigidBody3D: continue
		var distance := piece.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = piece
	if is_instance_valid(best) or not allow_stump: return best
	for index: int in range(stumps_from, _stumps.size()):
		var stump: Node3D = _stumps[index]
		if not is_instance_valid(stump) or not stump is RigidBody3D: continue
		var distance := stump.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = stump
	return best

## The ray already proved a tip impact on the resident. Intact plate over the
## struck bone takes the point, rings and sparks; exposed vital tissue can be
## penetrated by a fast, square hit. A slow/glancing throw remains an ordinary
## local wound, never an automatic kill from proximity to the actor.
func _thrown_spear_hit_npc(part: String, point: Vector3, normal: Vector3, velocity: Vector3) -> float:
	var direction := velocity.normalized()
	var speed := velocity.length()
	var cut := clampf((speed * 0.7 - DAMAGE_SPEED_MIN) * DAMAGE_PER_MPS *
		float(WEAPONS["spear"].get("stab", 1.0)), 4.0, DAMAGE_MAX)
	var incidence := 0.0
	if normal.is_finite() and normal.length_squared() > 0.5:
		incidence = clampf(-direction.dot(normal.normalized()), 0.0, 1.0)
	var contact := _armor_point31(_npc_rig, part, point)
	var protection := ArmorDamage31.resolve(_npc_armor_loadout31, part, "stab", cut, contact, incidence)
	if str(protection.region) in ["cloth","mail","plate"] and str(protection.tier) in ["light","medium","heavy"]:
		combat_audio_event30("armor_"+str(protection.tier),point,clampf(cut/160.0,.08,1.0),"thrown:"+part+":"+str(protection.region))
	var wound := float(protection.damage)
	if protection.region == "plate":
		_spark_burst(point, normal, 12)
		_play_melee_hit31(point, "metal", clampf(speed / THROW_SPEED_MAX, 0.25, 1.0))
		_scuff_knight_plate(part, speed)
	else:
		_play_melee_hit31(point, "flesh", clampf(wound / DAMAGE_MAX, 0.0, 1.0))
	var penetrates: bool = ArmorDamage31.tissue_penetrates(str(protection.region), "stab", wound)
	_npc_take_blade_part(part, point, speed, direction, wound, false, penetrates)
	var base_part := part
	if base_part.ends_with("_l") or base_part.ends_with("_r"):
		base_part = base_part.substr(0, base_part.length() - 2)
	var vital_penetration: bool = protection.region != "plate" or wound >= float(NPC_PART_HP57.get(base_part, 288.0))
	# A penetrating spear can still travel through a vital zone; the ordinary
	# wound/part-health owner decides whether that contact was fatal.
	if base_part in ["head", "chest", "pelvis"] and speed >= SPEAR_LETHAL_SPEED \
		and incidence >= SPEAR_LETHAL_INCIDENCE and vital_penetration:
		return SPEAR_BODY_PIERCE_DEPTH
	return SPEAR_STICK_DEPTH

func _spear_plate_covers(part: String) -> bool:
	var plate_bone := "chest" if part == "pelvis" else part
	for holder: Node3D in _knight_armour:
		if is_instance_valid(holder) and str(holder.get_meta("sword_armour_part", "")) == plate_bone:
			return true
	return false

## The sword is attached in the DRAW frame, not in the physics step: the rig has
## already applied every bone pose by then (including the player's own pass), so
## the handle is placed on the fist the animation actually shows. Attaching it
## during the physics step read a stale skeleton and left the sword out of hand.
func _process(delta: float) -> void:
	if not _ready or not is_instance_valid(_world) or not is_instance_valid(_rig): return
	if not _active():
		_hide_throw_dots()
		# A fatal head wound remains visible after control passes to the ragdoll.
		if bool(_world.get("preview_dead")): _apply_player_severed()
		if is_instance_valid(_sword): _sword.visible = _sword_grounded
		return
	if _unarmed:
		_hide_throw_dots()
		# Empty hands after a throw: the player's own animation owns the arms again.
		if is_instance_valid(_sword): _sword.visible = _sword_grounded
		# Finish the visible shoulder and torso drive after the spear leaves the fist.
		if _spear_follow_left > 0.0: _solve_arm(0.0)
		# This shield is parented to the world and must be placed on the live hand
		# every draw frame, including after the spear has been released.
		_place_shield()
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
	if _throw_preview_owned52():
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
	if _weapon_id == "spear" and (_throwing or _spear_cast_pending31):
		# The forward casting motion belongs to the projectile launch. It cannot
		# also score an invisible close-range melee sweep before the spear leaves.
		_prev_points = PackedVector3Array()
		_update_dummy(delta)
		_update_spark(delta)
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
	_dir = _contact_direction(_melee_axis_envelope29(_dir))
	# Display and next sweep begin at the RESOLVED pose, never the penetrated
	# pre-contact blade. This removes the render/physics tug of war at rest.
	_attach_sword_to_fist()
	_place_shield()
	_prev_points = PackedVector3Array()
	for i in SWEEP_SEGMENTS + 1:
		_prev_points.append(_sword_origin + _dir * (0.06 + _weapon_length * float(i) / SWEEP_SEGMENTS))
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
func _grip_origin_offset() -> float:
	if _weapon_id != "sword": return GRIP_CENTER_OFFSET
	return 0.005 if _active_side() == &"both" else 0.05

func _palm_offset(hand: int) -> Vector3:
	var socket_name := "socket_hand_l" if hand == _bone_l_hand else "socket_hand_r"
	var socket := _rig.find_bone(socket_name)
	return _rig.get_bone_rest(socket).origin if socket >= 0 else Vector3.ZERO

func _palm_position(side: StringName) -> Vector3:
	var bone := _hand_bone_for(side)
	return _rig.global_transform * (_rig.get_bone_global_pose(bone) * _palm_offset(bone))

func _attach_sword_to_fist() -> void:
	if is_instance_valid(_hatchet32) and _hatchet32.pose(get_process_delta_time()):return
	if _embedded29.pose(self): return
	var bone := _hand_bone_for(_active_side())
	if bone < 0: return
	var started := Time.get_ticks_usec()
	_self_begin_step45()
	_dir = _self_limit_step45(_dir)
	var incoming_direction := _dir
	var incoming_bones: Array[Transform3D] = []
	for index in _rig.get_bone_count(): incoming_bones.append(_rig.get_bone_pose(index))
	_self_pose_evaluations45 = 0
	var previous_forward := _self_pose_forward
	if _self_model_frame45 != Engine.get_physics_frames():
		_self_pose_forward = maxf(0.0, _self_pose_forward - (0.008 if _weapon_id == "sword" and _held else 0.06) * _self_elapsed_steps51)
	_self_evaluate_pose45(_dir)
	if not _held: _settle_carried_blade()
	var requested := _dir
	# Resolve the hand anchor before changing weapon orientation. The old
	# anchor can make an otherwise reachable downstroke appear to hit the head.
	var resolved := _self_anchor_clear29(requested)
	if not resolved and _self_pose_forward < previous_forward:
		# Retraction is a trial, not a new anchor. If it collides, first retry the
		# exact previously accepted reach. Adding 12 cm after a failed 6 cm
		# retraction made a still, downward weapon alternate between two grips.
		_self_pose_forward = previous_forward
		_self_evaluate_pose45(requested)
		resolved = _self_anchor_clear29(requested)
	for attempt in 6:
		if resolved: break
		var rejected_forward := _self_pose_forward
		_self_pose_forward = minf(0.80, _self_pose_forward + 0.12)
		_self_evaluate_pose45(requested)
		resolved = _self_anchor_clear29(requested)
		if resolved and _weapon_id == "sword" and _held:
			# The 12 cm search bracket is not a pose step. Find the first reachable
			# anchor inside that bracket instead of snapping both wrists outward.
			var accepted_forward := _self_pose_forward
			for refine in 6:
				_self_pose_forward = (rejected_forward + accepted_forward) * 0.5
				_self_evaluate_pose45(requested)
				if _self_anchor_clear29(requested): accepted_forward = _self_pose_forward
				else: rejected_forward = _self_pose_forward
			_self_pose_forward = accepted_forward
			_self_evaluate_pose45(requested)
			resolved = _self_anchor_clear29(requested)
	if not resolved:
		# A known pose is safer than rotating the weapon abruptly around the
		# head. Restore it only after validating it against this frame's body.
		resolved = _restore_safe_self_pose45()
		if resolved:
			# A body contact removes momentum into the rejected rotation, while
			# preserving motion tangent to that contact.
			var blocked_axis := _dir.cross(requested).normalized()
			_omega -= blocked_axis * maxf(0.0, _omega.dot(blocked_axis))
			_hammer_torque44 -= blocked_axis * maxf(0.0, _hammer_torque44.dot(blocked_axis))
		if not resolved:
			# Cold equipment has no compatible verified pose yet. Search locally
			# with the remaining fixed budget, never displaying a rejected trial.
			var tangent := requested.cross(Vector3.UP).normalized()
			if tangent.length_squared() < 0.5:
				tangent = requested.cross(Vector3.RIGHT).normalized()
			for angle: float in [5.0, 10.0, 15.0, 20.0]:
				for spoke in 4:
					var axis := tangent.rotated(requested, PI * 0.5 * float(spoke))
					var next := requested.rotated(axis, deg_to_rad(angle)).normalized()
					if _self_evaluate_pose45(next):
						resolved = true
						break
				if resolved: break
		if not resolved:
			for index in incoming_bones.size():
				_rig.set_bone_pose(index, incoming_bones[index])
			_rig.force_update_all_bone_transforms()
			_dir = incoming_direction
			_sword_origin = _palm_position(_active_side()) + _dir * _grip_origin_offset()
	_self_pose_clear = _self_blade_clear(_dir)
	if _self_pose_clear:
		_self_safe_dir = _dir
		_save_safe_self_pose45()
	else:
		_self_pose_unresolved45 += 1
	_self_model_frame45 = Engine.get_physics_frames()
	if _held:
		_self_motion_excess45 = maxf(_self_motion_excess45, _self_motion_from45.angle_to(_dir) - _self_motion_budget45)
	_place_sword(_sword_origin, _dir)
	var fist := _palm_position(_active_side())
	_grip_hand_error = (_sword_origin - _dir * _grip_origin_offset()).distance_to(fist)
	if _active_side() == &"both":
		_left_hand_error = _palm_position(&"left").distance_to(fist - _dir * 0.11)
	_self_pose_usec45 = Time.get_ticks_usec() - started
	_self_pose_evaluations_max45 = maxi(_self_pose_evaluations_max45, _self_pose_evaluations45)
	_self_pose_usec_max45 = maxi(_self_pose_usec_max45, _self_pose_usec45)

func _self_anchor_clear29(direction: Vector3) -> bool:
	if not _self_path_clear45(direction): return false
	if _weapon_id != "sword" or not _held: return true
	# A solver parked exactly on the body boundary becomes invalid as breathing
	# moves the body on the next frame. Keep a small clearance reserve; the swept
	# guard itself remains unchanged and still validates every transition.
	var chest: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_chest).origin
	var pelvis: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_pelvis).origin
	var head: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_head).origin
	var rear := _sword_origin - direction * weapon_rear_extent()
	var tip := _sword_origin + direction * (0.06 + _weapon_length)
	return _segment_distance(rear,tip,chest,pelvis)>=0.208 and _segment_distance(rear,tip,head,head)>=0.188

const SELF_POSE_IK_BUDGET45 := 24
var _self_pose_evaluations45 := 0
var _self_pose_evaluations_max45 := 0
var _self_pose_usec45 := 0
var _self_pose_usec_max45 := 0
var _self_pose_unresolved45 := 0
var _self_pose_restores45 := 0
var _self_safe_bones45: Array[Transform3D] = []
var _self_safe_local_dir45 := Vector3.ZERO
var _self_safe_weapon45 := ""
var _self_safe_side45: StringName = &""

var _self_motion_frame45 := -1
var _self_motion_from45 := Vector3.ZERO
var _self_motion_weapon45 := ""
var _self_motion_budget45 := 0.0
var _self_motion_excess45 := 0.0
var _self_model_frame45 := -1
var _self_safe_local_origin51 := Vector3.ZERO
var _self_elapsed_steps51 := 1

func _self_begin_step45() -> void:
	var frame := Engine.get_physics_frames()
	if not _held or _self_motion_weapon45 != _weapon_id or _self_motion_from45.length_squared() < 0.5:
		_self_elapsed_steps51 = 1
		_self_motion_from45 = _dir
		_self_motion_weapon45 = _weapon_id
		_self_motion_frame45 = frame
	elif frame != _self_motion_frame45:
		_self_elapsed_steps51 = maxi(1, frame - _self_motion_frame45)
		_self_motion_from45 = _self_safe_dir if _self_safe_dir.length_squared() > 0.5 else _dir
		_self_motion_frame45 = frame
	var rate := 10.0
	if _weapon_id == "sledge": rate = 7.6
	elif _weapon_id == "mace": rate = 8.4
	elif _weapon_id == "axe": rate = 7.4
	elif _weapon_id == "spear": rate = 8.0
	elif _weapon_id == "hatchet": rate = 10.2
	elif _weapon_id == "sword" and _active_side() != &"both": rate = 9.0
	if _weapon_id in ["axe", "sledge"]: rate *= 1.35
	if _weapon_id in ["axe","sledge"] and has_method("_lab_melee_rate29"):
		rate=float(call("_lab_melee_rate29",rate))
	_self_motion_budget45 = rate * get_physics_process_delta_time() * _self_elapsed_steps51

func _self_limit_step45(direction: Vector3) -> Vector3:
	if not _held or _self_motion_from45.length_squared() < 0.5: return direction
	var angle := _self_motion_from45.angle_to(direction)
	if angle <= _self_motion_budget45: return direction
	return _self_motion_from45.slerp(direction, _self_motion_budget45 / angle).normalized()

func _self_path_clear45(direction: Vector3) -> bool:
	if not _self_blade_clear(direction): return false
	if _self_safe_weapon45 != _weapon_id or _self_safe_side45 != _active_side(): return true
	if _self_safe_dir.length_squared() < 0.5: return true
	var old_origin: Vector3 = _rig.global_transform * _self_safe_local_origin51
	var old_direction: Vector3 = (_rig.global_basis * _self_safe_local_dir45).normalized()
	var steps := maxi(1, maxi(ceili(old_direction.angle_to(direction) / deg_to_rad(3.0)), ceili(old_origin.distance_to(_sword_origin) / 0.025)))
	for step in range(steps + 1):
		var t := float(step) / steps
		var between := old_direction.lerp(direction, t).normalized() if old_direction.dot(direction) > 0.9999 else old_direction.slerp(direction, t).normalized()
		if not _self_blade_clear_at51(between, old_origin.lerp(_sword_origin, t)): return false
	return true

func _self_evaluate_pose45(direction: Vector3) -> bool:
	if _self_pose_evaluations45 >= SELF_POSE_IK_BUDGET45: return false
	_self_pose_evaluations45 += 1
	_dir = _self_limit_step45(direction)
	_solve_arm(0.0)
	_rig.force_update_all_bone_transforms()
	_sword_origin = _palm_position(_active_side()) + _dir * _grip_origin_offset()
	if _held: _probe_blade_contact29()
	# Moving the shared grip changes the plane clearance after steering. Resolve
	# the existing world-contact plane against this actual IK origin as well.
	for contact_step in 4:
		var constrained := _contact_direction(_dir)
		if constrained.distance_squared_to(_dir) < 1.0e-10: break
		_dir = constrained
		_solve_arm(0.0)
		_rig.force_update_all_bone_transforms()
		_sword_origin = _palm_position(_active_side()) + _dir * _grip_origin_offset()
	return _self_blade_clear(_dir)

func _save_safe_self_pose45() -> void:
	_self_safe_bones45.clear()
	for index in _rig.get_bone_count():
		_self_safe_bones45.append(_rig.get_bone_pose(index))
	_self_safe_local_dir45 = (_rig.global_basis.inverse() * _dir).normalized()
	_self_safe_local_origin51 = _rig.global_transform.affine_inverse() * _sword_origin
	_self_safe_weapon45 = _weapon_id
	_self_safe_side45 = _active_side()

func _restore_safe_self_pose45() -> bool:
	if _self_safe_weapon45 != _weapon_id or _self_safe_side45 != _active_side() \
			or _self_safe_bones45.size() != _rig.get_bone_count(): return false
	for index in _self_safe_bones45.size():
		_rig.set_bone_pose(index, _self_safe_bones45[index])
	_rig.force_update_all_bone_transforms()
	_dir = (_rig.global_basis * _self_safe_local_dir45).normalized()
	_sword_origin = _palm_position(_active_side()) + _dir * _grip_origin_offset()
	_self_pose_restores45 += 1
	if _held and _dir.angle_to(_self_limit_step45(_dir)) > 0.0001: return false
	return _self_blade_clear(_dir)


var _self_pose_forward := 0.0
var _self_pose_clear := true
var _self_safe_dir := Vector3.ZERO

func _self_blade_clear(direction: Vector3) -> bool:
	return _self_blade_clear_at51(direction, _sword_origin)

func _self_blade_clear_at51(direction: Vector3, origin: Vector3) -> bool:
	var chest: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_chest).origin
	var pelvis: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_pelvis).origin
	var head: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_head).origin
	# The pommel/haft behind the hand is part of the same weapon. A clear
	# blade tip alone must not approve a hilt driven through the face or torso.
	var rear := origin - direction * weapon_rear_extent()
	var tip := origin + direction * (0.06 + _weapon_length)
	return _segment_distance(rear, tip, chest, pelvis) >= 0.20 and _segment_distance(rear, tip, head, head) >= 0.18

func _guard_self_blade(wanted: Vector3) -> Vector3:
	# Test the whole angular path, not only a tip already on the far side of the body.
	if _self_safe_dir.length_squared() > 0.5 and _self_blade_clear(_self_safe_dir):
		var steps := maxi(1, ceili(_self_safe_dir.angle_to(wanted) / deg_to_rad(3.0)))
		var safe := _self_safe_dir
		for step in range(1, steps + 1):
			var next := _self_safe_dir.slerp(wanted, float(step) / steps).normalized()
			if not _self_blade_clear(next):
				_omega *= 0.35
				_self_safe_dir = safe
				return safe
			safe = next
		_self_safe_dir = safe
		return safe
	if _self_blade_clear(wanted):
		_self_safe_dir = wanted
		return wanted
	# The body may move around a previously safe blade. Find the nearest clear
	# direction towards the front before displaying it, retaining its hand anchor.
	var forward: Vector3 = _player._visual.global_basis.z.normalized()
	for step in range(1, 25):
		var next := wanted.slerp(forward, float(step) / 24.0).normalized()
		if _self_blade_clear(next):
			_self_safe_dir = next
			_omega *= 0.35
			return next
	# No feasible rotation was found; attachment retries the hand pose.
	_self_safe_dir = Vector3.ZERO
	return wanted

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
func _melee_axis_envelope29(direction: Vector3) -> Vector3:
	# Shoulder wind-up uses the same swept body checks as the forward strike;
	# the former camera hemisphere alone prevented this reachable pose.
	if _held and _weapon_id in ["axe", "sledge"]: return direction
	return _soft_body_limit(_constrain_forward(direction), 0.10, 0.16)

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
	var yaw_off := hx * 1.48
	# The whole vertical arc is open, and now a real wind-up is possible too: the
	# fist can swing from below the hip right up over the head.
	var pitch_off := clampf(0.10 + hy * 1.42 - _thrust * 0.30, -1.00, 1.48)
	var flat := (-basis.z).rotated(Vector3.UP, -yaw_off).normalized()
	return (flat * cos(pitch_off) + Vector3.UP * sin(pitch_off)).normalized()

## Two-bone IK over the real rig so the sword arm actually moves with the blade.
## The sword arm is written as LOCAL bone poses after the player's own pose pass,
## which is why it no longer flickers: no global override competes with the rig
## authority. The arm is extended toward the commanded direction, the wrist
## follows the blade, and the torso turns toward the target.
func _solve_arm(delta: float) -> void:
	if _embedded29.active(self): return
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
		if _arm_release_blend29 > 0.0:
			want_dir = want_dir.slerp(_constrain_forward(_hand_target_direction()), _arm_release_blend29).normalized()
		want_dir = _constrain_to_body(want_dir, 0.34)
		var want_rig := (rig_basis.inverse() * want_dir).normalized()
		var blade_rig := (rig_basis.inverse() * _dir).normalized()
		if delta > 0.0: _lean_body(want_dir, delta)
		var side := _active_side()
		# If the carried sword had to be drawn out of a wall, the arm comes in with
		# it, so the fist keeps holding the grip instead of being left behind.
		var pulled := clampf(_carry_pull / 0.55, 0.0, 1.0)
		var carry_reach := lerpf(lerpf(0.70, 0.40, pulled), 1.0, _arm_release_blend29)
		var grip_rig := _pose_shared_grip(want_dir, blade_rig) if side == &"both" else _pose_main(side, want_rig, blade_rig, carry_reach)
		if grip_rig != Vector3.ZERO:
			_sword_origin = (_rig.global_transform * grip_rig) + _dir * _grip_origin_offset()
		# The carried blade is never shown inside the character or inside the world:
		# if the pose would drive steel through him or a wall, the blade is turned.
		_dir = _clear_blade_from_body(_dir)
		_dir = _clear_blade_from_world(_dir)
		return
	var want_dir := _constrain_forward(_hand_target_direction())
	want_dir = _constrain_to_body(want_dir, 0.10)
	# The GUARD keeps the same diagonal arm as the carried pose, just lifted or
	# lowered by the mouse, so blocking always reads as the same guard.
	if _blocking and (not _hold_left or _shield_guard_active29()):
		var lift := clampf(_hand.y, -1.0, 1.0)
		want_dir = _constrain_forward((_ready_hand_direction() + Vector3.UP * (lift * 0.45)).normalized())
		want_dir = _constrain_to_body(want_dir, 0.34)
	var want_rig := (rig_basis.inverse() * want_dir).normalized()
	var blade_rig := (rig_basis.inverse() * _dir).normalized()
	if delta > 0.0: _lean_body(want_dir, delta)
	var side := _active_side()
	var grip_rig := Vector3.ZERO
	if side == &"both":
		grip_rig = _pose_shared_grip(want_dir, blade_rig)
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
	_sword_origin = (_rig.global_transform * grip_rig) + _dir * _grip_origin_offset()

## Solve one rigid handle reachable by both arms. Moving the supporting hand
## independently breaks its contact with the handle and crosses the forearms.
func _pose_shared_grip(want_dir: Vector3, blade_rig: Vector3) -> Vector3:
	if _weapon_id == "spear" and _spear_aim_blend > 0.0:
		return _pose_spear_throw31(want_dir, blade_rig)
	var rig_to_world := _rig.global_transform
	var world_to_rig := rig_to_world.affine_inverse()
	var visual_basis: Basis = _player._visual.global_basis.orthonormalized()
	var right_set := _arm_set(&"right")
	var left_set := _arm_set(&"left")
	var right_joint: Vector3 = (_chain_global(right_set.clav) * right_set.rest_upper).origin
	var left_joint: Vector3 = (_chain_global(left_set.clav) * left_set.rest_upper).origin
	var middle_world: Vector3 = rig_to_world * ((right_joint + left_joint) * 0.5)
	var local_want: Vector3 = visual_basis.inverse() * want_dir
	var side_load := (1.0 - smoothstep(0.20, 0.70, absf(_hand.y))) if _weapon_id in ["sledge", "axe", "spear"] and _hold_left else 0.0
	var side_reach := lerpf(0.30, 0.36, side_load)
	# Live weapon momentum carries the hands away from the chest into the strike.
	# Stopping the mouse leaves the loading pose; no timed attack drives the hands.
	var arm_drive := 1.0 if _hold_left else 0.0
	var target_world: Vector3 = middle_world + visual_basis * Vector3(
		clampf(local_want.x * (side_reach if _hold_left else 0.14), -side_reach, side_reach),
		clampf(local_want.y * (0.64 if _hold_left else 0.20) - 0.08, -0.30, 0.48),
		lerpf(0.38, 0.25, clampf(local_want.y, 0.0, 1.0)) + arm_drive * 0.34 + _self_pose_forward)
	var lateral_extension := _lateral_extension29()
	var reach_fraction := lerpf(0.94, 0.9995, lateral_extension)
	if (_held or _arm_release_blend29 > 0.0) and not _blocking:
		# Follow the requested arm direction on a reachable arc instead of a
		# narrow X box at fixed forward extension. Both palms are solved below.
		var reach_world := minf(right_set.rest_fore.origin.length() + right_set.rest_hand.origin.length(), left_set.rest_fore.origin.length() + left_set.rest_hand.origin.length()) * _rig_scale() * reach_fraction
		var visible_axis: Vector3 = visual_basis.inverse() * (rig_to_world.basis * blade_rig).normalized()
		var reach_axis := (visible_axis - Vector3.UP * 0.30).normalized()
		var arm_target := reach_axis * reach_world
		arm_target.z = maxf(0.24, arm_target.z) + _self_pose_forward
		if _weapon_id in ["axe", "sledge"]:
			# A real blade moving past the shoulder loads the handle close to that
			# shoulder. Moving forward opens the same continuous arc into extension.
			var shoulder_load := 1.0 - smoothstep(0.25, 0.65, visible_axis.z)
			# The same vertical command owns loading and extension; a purely lateral
			# stroke must not drop the hands when it leaves the shoulder pose.
			var swing_height := clampf(0.20 + _hand.y * 0.45, -0.30, 0.48)
			arm_target.y = swing_height
			var shoulder_target := Vector3(signf(visible_axis.x) * 0.22, swing_height, 0.24 + _self_pose_forward)
			arm_target = arm_target.lerp(shoulder_target, shoulder_load)
		var extended_target := middle_world + visual_basis * arm_target
		target_world = extended_target if _weapon_id == "spear" else target_world.lerp(extended_target, _arm_release_blend29)
	var grip: Vector3 = world_to_rig * target_world
	# Reach spheres belong to wrists; offset their centres to the palm anchors
	# using the SAME wrist orientation that the final IK will apply.
	var right_rest_basis: Basis = (_chain_global(right_set.clav) * right_set.rest_upper * right_set.rest_fore * right_set.rest_hand).basis.orthonormalized()
	var left_rest_basis: Basis = (_chain_global(left_set.clav) * left_set.rest_upper * left_set.rest_fore * left_set.rest_hand).basis.orthonormalized()
	var offset := blade_rig * _two_hand_offset_rig
	var right_reach: float = (right_set.rest_fore.origin.length() + right_set.rest_hand.origin.length()) * reach_fraction
	var left_reach: float = (left_set.rest_fore.origin.length() + left_set.rest_hand.origin.length()) * reach_fraction
	for iteration in 10:
		var right_basis := _palm_basis51(right_joint, grip, blade_rig, right_rest_basis)
		var right_center: Vector3 = right_joint + right_basis * _palm_offset(right_set.hand)
		grip = right_center + (grip - right_center).limit_length(right_reach)
		var support := grip - offset
		var left_basis := _palm_basis51(left_joint, support, blade_rig, left_rest_basis)
		var left_center: Vector3 = left_joint + left_basis * _palm_offset(left_set.hand)
		support = left_center + (support - left_center).limit_length(left_reach)
		grip = support + offset
	var fist: Vector3 = _pose_arm_ik(right_set.clav, right_set.upper, right_set.fore,
		right_set.hand, right_set.rest_upper, right_set.rest_fore, right_set.rest_hand,
		right_set.offset, grip, blade_rig, 1.0, true, right_set.pole)
	_pose_support(&"left", fist - offset)
	return fist

## One visible throwing arm rises above and behind the right shoulder while the
## left hand lets go of the shaft. Only after a forward, accelerating cast does
## the same model leave the hand and become the existing physical projectile.
func _pose_spear_throw31(want_dir: Vector3, blade_rig: Vector3) -> Vector3:
	var rig_to_world := _rig.global_transform
	var world_to_rig := rig_to_world.affine_inverse()
	var visual_basis: Basis = _player._visual.global_basis.orthonormalized()
	var right_set := _arm_set(&"right")
	var left_set := _arm_set(&"left")
	var right_joint: Vector3 = (_chain_global(right_set.clav) * right_set.rest_upper).origin
	var left_joint: Vector3 = (_chain_global(left_set.clav) * left_set.rest_upper).origin
	var shoulder_world: Vector3 = rig_to_world * right_joint
	var left_shoulder_world: Vector3 = rig_to_world * left_joint
	var charge := clampf(_throw_held_seconds() / THROW_WINDUP_TIME, 0.0, 1.0) if _throwing else 0.0
	var cast_phase := clampf(_spear_cast_elapsed31 / SPEAR_CAST_TIME31, 0.0, 1.0) if _spear_cast_pending31 else 0.0
	var follow_phase := clampf(1.0 - _spear_follow_left / SPEAR_FOLLOW_TIME, 0.0, 1.0) if _spear_follow_left > 0.0 else 0.0
	var left_release := clampf((charge - 0.12) / 0.40, 0.0, 1.0)
	var local_hand := Vector3(0.02, 0.13, 0.25).lerp(Vector3(0.12, 0.36, -0.42), charge)
	if _spear_cast_pending31:
		# Squared time makes the visible wrist accelerate forward instead of
		# jumping to a fixed launch position on mouse release.
		var drive := cast_phase * cast_phase
		local_hand = Vector3(0.12, 0.36, -0.42).lerp(Vector3(0.02, 0.16, 0.66), drive)
		left_release = 1.0
	elif _spear_follow_left > 0.0:
		local_hand = Vector3(0.02, 0.16, 0.66).lerp(Vector3(0.00, 0.04, 0.34), follow_phase)
		left_release = 1.0
	var middle_world: Vector3 = rig_to_world * ((right_joint + left_joint) * 0.5)
	var local_want: Vector3 = visual_basis.inverse() * want_dir
	var ready_world: Vector3 = middle_world + visual_basis * Vector3(
		clampf(local_want.x * (0.34 if _hold_left else 0.14), -0.34, 0.34),
		clampf(local_want.y * (0.82 if _hold_left else 0.20) - 0.12, -0.38, 0.64),
		lerpf(0.38, 0.25, clampf(local_want.y, 0.0, 1.0)) + _self_pose_forward)
	var blend := _spear_aim_blend * (1.0 - follow_phase * follow_phase)
	var hand_world: Vector3 = ready_world.lerp(shoulder_world + visual_basis * local_hand, blend)
	var grip: Vector3 = world_to_rig * hand_world
	var fist: Vector3 = _pose_arm_ik(right_set.clav, right_set.upper, right_set.fore,
		right_set.hand, right_set.rest_upper, right_set.rest_fore, right_set.rest_hand,
		right_set.offset, grip, blade_rig, 1.0, true, right_set.pole,
		charge > 0.12 or _spear_cast_pending31 or _spear_follow_left > 0.0)
	if fist == Vector3.ZERO: return fist
	var support_world: Vector3 = left_shoulder_world + visual_basis * Vector3(-0.03, -0.18, 0.25)
	var shaft_grip: Vector3 = fist - blade_rig * _two_hand_offset_rig
	var support_rig: Vector3 = shaft_grip.lerp(world_to_rig * support_world, left_release)
	_pose_support(&"left", support_rig)
	return fist

## LMB drives the left hand; RMB drives a free right-hand sword/mace swing.
## Both buttons keep the existing shared grip; shields retain RMB defense.
var _blocking := false

func _active_side() -> StringName:
	# DSH_MELEE_SET: the weapon decides the grip. A two-handed axe, sledge or spear is
	# always held in both hands; a mace never is; the sword can be either.
	var grip := str(weapon_entry().get("grip", "both_optional"))
	if grip == "two": return &"both"
	if _shield_worn: return &"left"
	if _hold_left and _hold_right and not _hand_lost31(&"left") and not _hand_lost31(&"right"):
		return &"both"
	var wanted := _carry_side_effective() if grip == "one" else _carry_side
	if _hold_left and not _hold_right: wanted = &"left"
	elif _hold_right and not _hold_left: wanted = &"right"
	if _hand_lost31(wanted) and not _both_hands_lost():
		return &"right" if not _hand_lost31(&"right") else &"left"
	return wanted

func _hand_bone_for(side: StringName) -> int:
	return _arm_set(side).hand

## Bone set that is VISUALLY on the requested side. The hero rig names are
## mirrored relative to the model's visible sides, so the mapping is resolved
## once at install time by comparing the clavicle positions.
func _arm_set(side: StringName) -> Dictionary:
	# The hero rig is MIRRORED on screen: the "_l" bones render on the character's
	# right. So LMB (left) drives the "_r" bones and RMB (right) the "_l" bones.
	var use_l_named: bool = side in [&"right", &"both"]
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
func _lateral_extension29() -> float:
	if _weapon_id == "spear" or _blocking or _half_sword or _aiming_throw: return 0.0
	return smoothstep(0.45, 0.85, absf(_hand.x)) * _arm_release_blend29

func _pose_main(side: StringName, want_rig: Vector3, blade_rig: Vector3, reach_scale: float = 1.0) -> Vector3:
	var set := _arm_set(side)
	# The hand loads near the shoulder, then extends with real weapon momentum.
	# Mouse direction and angular dynamics remain free; this only solves the arm.
	if _hold_left and not _aiming_throw and not _half_sword and reach_scale > 0.99:
		reach_scale *= 1.0
	return _pose_arm_ik(set.clav, set.upper, set.fore, set.hand, set.rest_upper, set.rest_fore, set.rest_hand, set.offset, want_rig, blade_rig, reach_scale, false, set.pole)

## Supporting hand closes on the lower part of the handle (two-handed grip).
## The wrist simply continues the forearm - no twist toward the handle, which is
## what used to fold the arm into a hook.
func _pose_support(side: StringName, grip_rig: Vector3) -> void:
	var set := _arm_set(side)
	var fist: Vector3 = _pose_arm_ik(set.clav, set.upper, set.fore, set.hand, set.rest_upper, set.rest_fore, set.rest_hand, set.offset, grip_rig, (_rig.global_basis.inverse() * _dir).normalized(), 1.0, true, set.pole)
	if fist != Vector3.ZERO: _left_hand_error = fist.distance_to(grip_rig)

## Two-bone IK with a real elbow: the hand reaches the requested point (clamped
## to the arm's length) instead of always being fully extended. That bend is what
## lets the second hand reach the handle in a two-handed grip.
func _palm_basis51(shoulder: Vector3, grip: Vector3, blade: Vector3, fallback: Basis) -> Basis:
	# The grip axis crosses the closed palm. Choose its remaining roll from
	# the forearm reach, so the wrist continues the arm instead of folding back.
	var z := -blade.normalized()
	var y := (grip - shoulder).normalized()
	y -= z * y.dot(z)
	if y.length_squared() < 0.0001:
		y = fallback.y - z * fallback.y.dot(z)
	if y.length_squared() < 0.0001:
		y = z.cross(Vector3.RIGHT)
		if y.length_squared() < 0.0001: y = z.cross(Vector3.UP)
	y = y.normalized()
	return Basis(y.cross(z).normalized(), y, z).orthonormalized()

func _pose_arm_ik(clav: int, upper: int, fore: int, hand: int, rest_upper: Transform3D, rest_fore: Transform3D, rest_hand: Transform3D, hand_offset: Vector3, want_rig: Vector3, blade_rig: Vector3, reach_scale: float = 1.0, want_is_point: bool = false, pole_side: float = 1.0, elbow_up: bool = false) -> Vector3:
	if clav < 0 or upper < 0 or fore < 0 or hand < 0: return Vector3.ZERO
	var clavicle_global := _chain_global(clav)
	var joint := (clavicle_global * rest_upper).origin
	var l1 := rest_fore.origin.length()
	var l2 := rest_hand.origin.length()
	if l1 <= 0.01 or l2 <= 0.01: return Vector3.ZERO
	var target := want_rig if want_is_point else joint + want_rig * (l1 + l2) * clampf(reach_scale, 0.3, 1.0)
	# Single-hand targets stay forward of the chest and on a reachable arc.
	if not want_is_point:
		var visual_basis: Basis = _player._visual.global_basis.orthonormalized()
		var chest_world: Vector3 = _rig.global_transform * _chain_global(_bone_chest).origin
		var target_world: Vector3 = _rig.global_transform * target
		var relative: Vector3 = visual_basis.inverse() * (target_world - chest_world)
		relative.z = maxf(relative.z, 0.24 + _self_pose_forward)
		target = _rig.global_transform.affine_inverse() * (chest_world + visual_basis * relative)
	# Aim the grip axis across the closed palm; IK solves the wrist behind
	# that palm centre rather than placing the wrist itself on the handle.
	var rest_global_basis := (clavicle_global * rest_upper * rest_fore * rest_hand).basis.orthonormalized()
	var grip_axis := (rest_global_basis * Vector3(0, 0, -1)).normalized()
	var palm_basis := _palm_basis51(joint, target, blade_rig, rest_global_basis)
	var palm_offset := _palm_offset(hand)
	target -= palm_basis * palm_offset
	var to_target := target - joint
	var lateral_extension := _lateral_extension29()
	# The target above is a palm anchor; subtracting its offset must not shorten
	# the requested wrist reach during a lateral strike. Keep a small IK epsilon.
	if not want_is_point and reach_scale > 0.70 and lateral_extension > 0.0:
		to_target = to_target.normalized() * lerpf(to_target.length(), (l1 + l2) * 0.9995, lateral_extension)
	var distance := to_target.length()
	if distance < 1.0e-4: return Vector3.ZERO
	var direction := to_target.normalized()
	var d := clampf(distance, absf(l1 - l2) + 1.0e-3, (l1 + l2) * lerpf(0.96, 0.9995, lateral_extension))
	# The elbow hangs DOWN (a little to its own side and slightly back), which is
	# what a human arm does. A sideways pole threw the elbow out into a Г shape.
	var pole := Vector3(0.75 * pole_side, 0.82, -0.32) if elbow_up else Vector3(0.55 * pole_side, -1.0, -0.12)
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
	# Share axial rotation with forearm pronation instead of twisting only the wrist.
	var natural_hand := (fore_global.basis * rest_hand.basis).orthonormalized()
	var natural_cross := natural_hand.z - fore_dir * natural_hand.z.dot(fore_dir)
	var wanted_cross := palm_basis.z - fore_dir * palm_basis.z.dot(fore_dir)
	if natural_cross.length_squared() > 0.0001 and wanted_cross.length_squared() > 0.0001:
		var pronation := clampf(natural_cross.signed_angle_to(wanted_cross, fore_dir), -1.35, 1.35)
		fore_global.basis = Basis(fore_dir, pronation) * fore_global.basis
		fore_local.basis = upper_global.basis.inverse() * fore_global.basis
		_rig.set_bone_pose(fore, fore_local)
	var hand_local := Transform3D((fore_global.basis.inverse() * palm_basis).orthonormalized(), rest_hand.origin)
	_rig.set_bone_pose(hand, hand_local)
	return (fore_global * hand_local) * palm_offset

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
const WINDUP_TIME := 0.25          # visible preparation while the mouse drives the blade
const RECOVER_TIME := 0.26         # follow-through and settle
const WINDUP_ANTICIPATION := 0.48  # radians the torso counter-turns while coiling
const CHAIN_RATE := 15.0           # how fast each link catches the one below it
const IMPACT_JOLT_LIMIT := 0.105
const BREATH_RATE := 1.5
const BREATH_AMPLITUDE := 0.013
## The kinetic chain: pelvis, spine, chest, each with its own share and its own
## stiffness, so the turn travels UP the body instead of arriving all at once.
var _chain_yaw := Vector3.ZERO     # pelvis, spine, chest
var _chain_pitch := Vector3.ZERO
var _chain_roll := Vector3.ZERO
var _hammer_torque44 := Vector3.ZERO
var _swing_phase := "idle"
var _phase_t := 0.0
var _swing_button_latched31 := false
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
	if not _swing_held54(): _swing_button_latched31 = false
	match _swing_phase:
		"windup":
			if not _swing_held54():
				_swing_phase = "recover"; _phase_t = 0.0
			elif _phase_t >= WINDUP_TIME: _swing_phase = "strike"; _phase_t = 0.0
		"strike":
			if not _swing_held54():
				_swing_phase = "recover"; _phase_t = 0.0
		"recover":
			if _phase_t >= RECOVER_TIME: _swing_phase = "idle"; _phase_t = 0.0
		_:
			if _swing_held54() and not _swing_button_latched31:
				_swing_phase = "windup"
				_phase_t = 0.0
				entering = true
				_swing_button_latched31 = true
	# The direction the cut will go. Captured as the coil STARTS, because that is when
	# the body has to decide which way to wind up against.
	if entering:
		var sign_now := signf(yaw_target)
		if absf(_hand_cmd.x) > 0.02:
			sign_now = signf(_hand_cmd.x)
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

## RMB is a free right-hand swing only for these one-handed weapon modes.
func _right_hand_weapon54() -> bool:
	return _weapon_id in ["sword", "mace"] and not _shield_worn and not _half_sword

func _swing_held54() -> bool:
	if _shield_guard_active29(): return false
	return _hold_left or (_hold_right and _right_hand_weapon54())

func _swing_can_damage31() -> bool:
	if _shield_guard_active29() or Engine.get_physics_frames() <= _shield_resume_frame29: return false
	return _swing_held54() or _sword_coasting31()

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
	var angular_load := ((_omega - _body_load_omega) / maxf(delta, 0.001)).limit_length(45.0)
	_body_load_omega = _omega
	var swing_pitch := -_omega.dot(world_right) * BODY_LEAN_GAIN - angular_load.dot(world_right) * 0.0015
	var swing_roll := -_omega.dot(world_fwd) * BODY_LEAN_GAIN - angular_load.dot(world_fwd) * 0.0015
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
	var chest_yaw := _body_yaw * (1.0 - 0.70 * maxf(0.0, _anticipation)) + coil
	if WEAPONS.has(_weapon_id) and _swing_held54() and not _aiming_throw:
		chest_yaw += clampf(_hand.x, -1.0, 1.0) * 0.30
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
	if _weapon_id == "spear" and _spear_aim_blend > 0.0:
		var throw_phase := 1.0 - _spear_follow_left / SPEAR_FOLLOW_TIME if _spear_follow_left > 0.0 else 0.0
		var throw_coil := _spear_release_power if _spear_follow_left > 0.0 else clampf(_throw_held_seconds() / THROW_WINDUP_TIME, 0.0, 1.0)
		var throw_blend := _spear_aim_blend * (1.0 - throw_phase * throw_phase)
		chest_pitch += throw_blend * lerpf(-0.10 * throw_coil, 0.12, throw_phase)
		chest_yaw += throw_blend * lerpf(-0.08 * throw_coil, 0.10, throw_phase)
	_chain_yaw.x = _chain_link(_chain_yaw.x, chest_yaw * 0.45, delta)
	_chain_yaw.y = _chain_link(_chain_yaw.y, chest_yaw * 0.50, delta)
	_chain_yaw.z = _chain_link(_chain_yaw.z, chest_yaw * 0.65, delta)
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

## During locomotion the gait follows travel while the weapon keeps its existing
## aiming frame. Counter-turn at the spine retains the upper-body orientation;
## all authored bone offsets and scale remain unchanged.
func _align_melee_gait27() -> void:
	if not _held or not is_steering() or _aiming_throw: return
	if _bone_pelvis < 0 or _bone_spine < 0: return
	var axes := Input.get_vector(&"preview_move_left", &"preview_move_right", &"preview_move_forward", &"preview_move_back")
	var travel: Vector3 = _player.velocity
	travel.y = 0.0
	if axes.length_squared() < 0.001 or travel.length_squared() < 0.04: return
	var turn: float = wrapf(atan2(travel.x, travel.z) - _player._visual.global_rotation.y, -PI, PI)
	var spine_before := _chain_global(_bone_spine).basis
	var pelvis_parent := _rig.get_bone_parent(_bone_pelvis)
	var pelvis_parent_basis := _chain_global(pelvis_parent).basis if pelvis_parent >= 0 else Basis.IDENTITY
	var axis := (pelvis_parent_basis.inverse() * _rig.global_basis.inverse() * Vector3.UP).normalized()
	var pelvis := _rig.get_bone_pose(_bone_pelvis)
	pelvis.basis = (Basis(axis, turn) * pelvis.basis).orthonormalized()
	_rig.set_bone_pose(_bone_pelvis, pelvis)
	var spine_parent := _rig.get_bone_parent(_bone_spine)
	var spine := _rig.get_bone_pose(_bone_spine)
	spine.basis = (_chain_global(spine_parent).basis.inverse() * spine_before).orthonormalized()
	_rig.set_bone_pose(_bone_spine, spine)

func _release_arm() -> void:
	# Nothing to undo: the pose authority rewrites every bone on its next pass as
	# soon as this host stops writing the arm.
	pass
## ------------------------------------------------------------------ duelist
## A sparring partner with the same sword. It walks in, winds up and cuts; the
## player's blade is a REAL physical guard: if the two blades meet during the
## incoming cut, the blow is stopped and no health is lost.
const DUELIST_HP := 480.0
const DUELIST_SPEED := 1.7
const DUELIST_REACH := 1.05
const DUELIST_WINDUP := 0.55
const DUELIST_STRIKE := 0.20
const DUELIST_RECOVER := 0.85
const DUELIST_DAMAGE := 12.0
## A swept incoming blade must actually reach the held steel. Allow a small
## physics-step margin beyond the visible blade, not the old torso-sized guard.
const BLOCK_RADIUS := 0.11
## The player's outgoing cut has its own tighter steel-to-steel threshold.
## Incoming parries use the swept segment margin above.
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
	_duelist_blade_prev = points

## True when the segment of the opponent's cut crosses the player's blade.
func _player_blade_intercepts(from: Vector3, to: Vector3) -> bool:
	return not Interception31.player_segment(self,from,to).is_empty()


## Incoming arrow tip sweep against the displayed metal, not the player's
## broad body capsule. Caller clips this sweep to the first world/body hit.
func incoming_arrow_parry31(from: Vector3, to: Vector3) -> Dictionary:
	# Held steel/wood remains solid even between swings. The caller already
	# clipped the real arrow tip path to the nearest world/body obstruction.
	if not _active():return {}
	return Interception31.player_segment(self,from,to)

func register_arrow_parry31(at: Vector3) -> void:
	_arrow_parries31 += 1
	_play_melee_hit31(at, "metal", 0.8)
	_show_spark(at)

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
			_npc_stop_attack43()
	# Steel on steel pushes BOTH men, not only the swords. The player gets the
	# existing bounded ground impulse (at most .30 m, no launch); the knight gets a
	# body push through his own CharacterBody3D. Neither is a teleport.
	var player_pushed := false
	if is_instance_valid(_player):
		player_pushed = _player.apply_contact_melee_impulse(away, ENEMY_CLASH_PLAYER_PUSH_NS)
	if is_instance_valid(_npc_body):
		_npc_hit_push31 = (_npc_hit_push31 + push_back * ENEMY_CLASH_BODY_PUSH).limit_length(5.0)
		_enemy_last_clash_push = ENEMY_CLASH_BODY_PUSH
		_enemy_clashes += 1
		_enemy_clash_lock_until_ms = now + ENEMY_CLASH_LOCK_MS
		# The clash interrupts whatever beat he was in; both recover visibly.
		if _npc_state in ["windup", "strike", "follow", "evade"] or _npc_sword.visible:
			_npc_stop_attack43()
		print("DSH_ENEMY_KNIGHT_CLASH count=", _enemy_clashes, " player_pushed=", player_pushed,
			" npc_push=", ENEMY_CLASH_BODY_PUSH, " at=", at)
	_play_melee_hit31(at, "metal", clampf(_omega.length() / 7.0, 0.35, 1.0))
	_show_spark(at)
	# Real sparks off the steel, thrown away from the point of contact.
	_spark_burst(at, -away, 16)
	_duelist_state = "recover"
	_duelist_timer = 0.0

## Damage to the player: goes through the session health owner when present, so
## the ordinary HUD reacts, with a local sparring counter as a fallback.
var _npc_armor_loadout31: Dictionary = {}
var _npc_armor_visual31: Node3D

## Equipment and rendered pieces commit together for player and opponent.
func set_npc_armor31(loadout: Dictionary) -> Dictionary:
	if not is_instance_valid(_npc_rig) or not is_instance_valid(_npc_body):
		return {"ok": false, "reason": "npc_not_spawned"}
	for slot: Variant in loadout:
		if not slot is String or not ArmorDamage31.SLOT_WEIGHT.has(slot):
			return {"ok": false, "reason": "slot", "slot": slot}
		if ArmorDamage31.tier_of(str(loadout[slot]), str(slot)) == "":
			return {"ok": false, "reason": "item_id", "slot": slot}
	if not is_instance_valid(_npc_armor_visual31):
		var visual := CastleArmorVisual31.new()
		visual.name = "CastleArmorVisualNPC"
		_npc_body.add_child(visual)
		var configured: Dictionary = visual.configure(_npc_rig, _npc_body)
		if not bool(configured.get("ok", false)):
			visual.queue_free()
			return {"ok": false, "reason": "visual_configure", "detail": configured}
		visual.reset_severed()
		_npc_armor_visual31 = visual
	var prior: Dictionary = _npc_armor_loadout31.duplicate()
	for slot: String in ArmorDamage31.SLOT_WEIGHT:
		var target_id := str(loadout.get(slot, ""))
		var applied: Dictionary = _npc_armor_visual31.set_armor(slot, target_id)
		if not bool(applied.get("ok", false)):
			for restore_slot: String in ArmorDamage31.SLOT_WEIGHT:
				_npc_armor_visual31.set_armor(restore_slot, str(prior.get(restore_slot, "")))
			return {"ok": false, "reason": "visual_set", "detail": applied}
	for lost_part: String in _npc_severed.keys():
		_npc_armor_visual31.on_severed(lost_part)
	_npc_armor_loadout31 = loadout.duplicate()
	return {"ok": true, "equipped": _npc_armor_loadout31.duplicate(),
		"visual": _npc_armor_visual31.snapshot()}

func npc_armor_snapshot31() -> Dictionary:
	return _npc_armor_loadout31.duplicate()

## Read-only presentation proof: the equipped IDs plus how many visible armour
## meshes are actually attached to the resident rig.
func npc_armor_visual_snapshot31() -> Dictionary:
	if not is_instance_valid(_npc_armor_visual31) or not is_instance_valid(_npc_rig): return {}
	var snap: Dictionary = _npc_armor_visual31.call("snapshot")
	var meshes := 0
	for node: Node in _npc_rig.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with("Armor"):
			meshes += 1
	snap["meshes"] = meshes
	return snap



func _player_armor_snapshot31() -> Dictionary:
	var controller := _world.get_node_or_null("CastleArmorEquipment") if is_instance_valid(_world) else null
	return controller.equipped_snapshot() if controller != null else {}

func _armor_point31(rig: Skeleton3D, bone_name: String, world_point: Vector3,
		hit_body: CollisionObject3D = null) -> Vector3:
	if hit_body != null:
		var shape_node := hit_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node == null:
			for child: Node in hit_body.get_children():
				if child is CollisionShape3D:
					shape_node = child as CollisionShape3D
					break
		if shape_node != null and shape_node.shape is BoxShape3D:
			var half := (shape_node.shape as BoxShape3D).size * 0.5
			var local := shape_node.to_local(world_point)
			return Vector3(local.x / maxf(half.x, 0.01), local.y / maxf(half.y, 0.01), local.z / maxf(half.z, 0.01))
	if not is_instance_valid(rig): return Vector3.ZERO
	var index := rig.find_bone(bone_name)
	if index < 0: return Vector3.ZERO
	var bone_world := rig.global_transform * rig.get_bone_global_pose(index)
	# The player has a broad capsule, not per-limb hitboxes. Convert the true
	# capsule contact into an orthonormal WORLD-space bone frame; using the
	# scaled inverse made every chest contact a phantom lower-edge seam.
	var local := bone_world.basis.orthonormalized().inverse() * (world_point - bone_world.origin)
	var half := Vector3(0.18, 0.22, 0.18)
	if bone_name in ["chest", "spine_01", "pelvis"]: half = Vector3(0.43, 0.30, 0.43)
	elif bone_name in ["head", "neck"]: half = Vector3(0.25, 0.29, 0.25)
	elif bone_name.begins_with("thigh"): half = Vector3(0.22, 0.29, 0.22)
	elif bone_name.begins_with("hand") or bone_name.begins_with("foot"):
		half = Vector3(0.15, 0.18, 0.15)
	return Vector3(local.x / half.x, local.y / half.y, local.z / half.z)

var _last_player_hit_ms := -1000
var _player_death_physics31: Dictionary = {}
var _player_death_driver31: RefCounted
func _apply_player_arrow_damage31(amount: float, at: Vector3, direction: Vector3) -> void:
	var struck := _player_part_at(at)
	_apply_player_damage(amount * (2.0 if str(struck.key) == "head" else 1.0), at, direction, "stab")

func _apply_player_damage(amount: float, at: Vector3, direction: Vector3, kind: String = "slice", full_key50: String = "", hit_body50: CollisionObject3D = null, normal50: Vector3 = Vector3.ZERO, speed50: float = -1.0) -> void:
	if is_instance_valid(_world) and bool(_world.get("preview_dead")): return
	# DSH_MELEE_SET: the SHIELD. A blow that lands inside its coverage is stopped by
	# it: the body takes nothing, no limb is damaged, and the shield wears instead.
	# Checked BEFORE the wound is tracked, which is what makes it a real block.
	if _shield_blocks(at):
		_shield_take_blow(amount)
		_play_melee_hit31(at, "metal", clampf(amount / DAMAGE_MAX, 0.25, 1.0))
		_block_push = (_block_push + direction.normalized() * 0.10).limit_length(0.5)
		print("DSH_SHIELD_BLOCK amount=", amount, " hp=", _shield_hp,
			" coverage=", _shield_coverage(), " broken=", _shield_broken)
		if is_instance_valid(_player): _player.apply_contact_melee_impulse(direction, 8.0)
		return
	# The wound lands on a real part of the body: it is tracked and, when it gives
	# out, that limb comes off the player exactly as it does off the opponent.
	var struck := _player_part_at(at) if full_key50 == "" else {"key":full_key50.trim_suffix("_l").trim_suffix("_r"),"sever":full_key50}
	var contact := _armor_point31(_rig, str(struck.sever), at, hit_body50)
	var incidence := clampf(-direction.normalized().dot(normal50.normalized()), 0.0, 1.0) if normal50.length_squared() > 0.5 else 1.0
	var protection := ArmorDamage31.resolve(_player_armor_snapshot31(), str(struck.sever), kind, amount, contact, incidence)
	if str(protection.region) in ["cloth","mail","plate"] and str(protection.tier) in ["light","medium","heavy"]:
		combat_audio_event30("armor_"+str(protection.tier),at,clampf(amount/160.0,.08,1.0),"player:"+str(struck.sever)+":"+str(protection.region))
	amount = float(protection.damage) * (0.12 if speed50 >= 0.0 and kind == "flat" else 1.0)
	var penetrates: bool = ArmorDamage31.tissue_penetrates(str(protection.region), kind, amount)
	var hero_appearance31 := _world.get_node_or_null("CastleArmorEquipment") if is_instance_valid(_world) else null
	if penetrates and amount > 0.05 and hero_appearance31 != null and hero_appearance31.has_method("apply_wound31"):
		hero_appearance31.apply_wound31(self, at, direction, kind, amount, str(struck.sever))
	# Plate still transfers trauma into the local part without making an
	# open wound or severing a limb.
	_player_take_blade(amount, at, direction, kind == "slice" and penetrates and (speed50 < 0.0 or (speed50 >= 3.2 and amount >= 8.0)), full_key50, maxf(speed50, 0.0))
	if penetrates:
		_play_melee_hit31(at, "flesh", clampf(amount / DAMAGE_MAX, 0.0, 1.0))
	elif protection.tier != "":
		_play_melee_hit31(at, "metal", clampf(amount / DAMAGE_MAX, 0.1, 1.0))
	_sparring_hp = maxf(0.0, _sparring_hp - amount)
	var owner := _session_health()
	if owner != null:
		var hp: Variant = owner.get("_hp")
		if hp is int:
			var remaining := maxi(0, int(hp) - int(round(amount)))
			owner.set("_hp", remaining)
			owner.set("_hit_age", 0.0)
			owner.call("_refresh")
			if remaining == 0: _kill_player(at, direction, amount)
	elif _sparring_hp <= 0.0:
		_kill_player(at, direction, amount)
	if is_instance_valid(_player) and not bool(_world.get("preview_dead")):
		_player.apply_contact_melee_impulse(direction, 18.0)

## True when both arms are gone, so no hand can carry the sword at all.
func _both_hands_lost() -> bool:
	return _hand_lost31(&"right") and _hand_lost31(&"left")

## The resident visual is mirrored: bones with suffix _r render on the visible
## left. Grip state names the visible hand, so sever checks must use that map.
func _hand_lost31(side: StringName) -> bool:
	var suffix := "_l" if side == &"right" else "_r"
	return _player_severed.has("hand" + suffix) or _player_severed.has("forearm" + suffix) \
		or _player_severed.has("upperarm" + suffix) or _player_disabled_parts50.has("hand" + suffix) \
		or _player_disabled_parts50.has("forearm" + suffix) or _player_disabled_parts50.has("upperarm" + suffix)

## A weapon can be held only if there is a hand for every grip it needs. A
## two-handed axe/sledge/spear requires both hands; one-handed weapons still work
## in the surviving hand. No weapon is held by a stump.
func _can_wield_weapon(id: String) -> bool:
	if _both_hands_lost(): return false
	var grip := str(WEAPONS.get(id, {}).get("grip", ""))
	if grip == "two" and (_hand_lost31(&"left") or _hand_lost31(&"right")):
		return false
	return true

## Player dismemberment: which part was hit, how much it can take, and what is
## lost when it comes off.
var _player_part_hp: Dictionary = {}
var _player_severed: Dictionary = {}
var _player_hidden_bones: Dictionary = {}
var _player_disarmed := false
var _player_disabled_parts50: Dictionary = {}
var _player_mesh_cut_parts50: Dictionary = {}
var _player_cut_total50 := 0

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

func _player_take_blade(amount: float, at: Vector3, direction: Vector3, may_sever: bool = true, exact_part50: String = "", contact_speed50: float = 0.0) -> void:
	if amount <= 0.05: return
	var part := _player_part_at(at) if exact_part50 == "" else {"key":exact_part50.trim_suffix("_l").trim_suffix("_r"),"sever":exact_part50}
	var kind: String = part.key
	var bone_name: String = part.sever
	var suffix := ""
	if bone_name.ends_with("_r"): suffix = "_r"
	elif bone_name.ends_with("_l"): suffix = "_l"
	var full_key: String = kind + suffix if kind not in ["head", "chest", "pelvis"] else kind
	if _player_severed.has(full_key): return
	if not _player_part_hp.has(full_key):
		_player_part_hp[full_key] = float(PART_HP.get(kind, 40.0))
	_player_part_hp[full_key] = float(_player_part_hp[full_key]) - amount
	if float(_player_part_hp[full_key]) > 0.0: return
	if not may_sever:
		if kind in ["head", "chest", "pelvis"]: _kill_player(at, direction, amount)
		elif kind in ["upperarm", "forearm", "hand"]: _player_disable_arm50(full_key, direction)
		return
	# The hero has no compound torso mesh to cut.
	if kind in ["chest", "pelvis"]:
		_spray_blood(at, direction, 12)
		_kill_player(at, direction, amount)
		return
	var old_grip := _active_side()
	_player_severed[full_key] = true
	var armor_visual := _player.get_node_or_null("CastleArmorVisual") if is_instance_valid(_player) else null
	var hero_appearance31 := _world.get_node_or_null("CastleArmorEquipment") if is_instance_valid(_world) else null
	if hero_appearance31 != null and hero_appearance31.has_method("on_severed"): armor_visual = hero_appearance31
	var cut_done50: bool = _hide_player_limb(full_key, kind, bone_name, at, direction, contact_speed50)
	if armor_visual != null: armor_visual.on_severed(full_key, cut_done50)
	_spray_blood(at, direction, 30)
	if not cut_done50: _throw_stump(kind, at, direction, 3.0)
	if kind in ["upperarm", "forearm", "hand"]:
		var side := &"right" if full_key.ends_with("_l") else &"left"
		_half_sword = false
		if side == &"right" and _shield_worn: drop_shield_to_ground31()
		if old_grip == side or old_grip == &"both":
			var other := &"left" if side == &"right" else &"right"
			if str(weapon_entry().get("grip", "")) != "two" and not _hand_lost31(other) \
					and not (other == &"right" and _shield_worn):
				_carry_side = other
			else:
				_player_disarmed = true
				_drop_player_sword(direction)
	if kind == "head":
		_player_disarmed = true
		_kill_player(at, direction, amount)
	print("DSH_SWORD_PROTO_PLAYER_SEVER part=", full_key, " disarmed=", _player_disarmed)

func _hide_player_limb(full_key: String, kind: String, bone_name: String, point: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO, speed: float = 0.0) -> bool:
	# Both actors use the same posed surface cut, caps, materials and physical debris.
	if is_instance_valid(_rig) and direction.length_squared() > 0.000001:
		var normal := direction.normalized()
		var proximal := _rig.find_bone("chest" if kind == "head" else bone_name)
		var keep := point - normal
		if proximal >= 0:
			keep = _rig.global_transform * _rig.get_bone_global_pose(proximal).origin
			if absf(normal.dot(keep - point)) < 0.0001:
				var parent := _rig.get_bone_parent(proximal)
				if parent >= 0: keep = _rig.global_transform * _rig.get_bone_global_pose(parent).origin
		var scope := "neck" if kind == "head" else bone_name
		if npc_cut_body(Plane(normal, normal.dot(point)), keep, scope, kind == "head", _rig):
			_player_mesh_cut_parts50[full_key] = true
			return true

	if kind in ["head", "chest", "pelvis"]:
		var chain: Array[String] = []
		if kind == "head": chain.assign(["head", "neck"])
		for name: String in chain: _player_hidden_bones[name] = true
		return false
	_player_hidden_bones[bone_name] = true
	return false

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
func _kill_player(at: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO, amount: float = 0.0) -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_player): return
	if bool(_world.get("preview_dead")): return
	var transport: Variant = _world.get("preview_transport")
	_player_death_physics31 = {"started": false, "impulse_ok": false, "reason": "no_physics_owner"}
	var driver: RefCounted
	if is_instance_valid(transport) and transport.get("character_physics") != null:
		driver = transport.get("character_physics")
	elif _player.get("_pose_authority") == &"on_foot":
		# The castle has no vehicle transport. Reuse its existing articulated
		# physics driver locally; the sword host becomes the sole dead-pose writer.
		var local_driver: RefCounted = CharacterPhysicsDriver31.new()
		var configured: Dictionary = local_driver.configure(_player, _world)
		if bool(configured.get("ok", false)):
			_player_death_driver31 = local_driver
			driver = local_driver
		else:
			_player_death_physics31.reason = str(configured.get("error", "configure_failed"))
	if driver != null and _player.get("_pose_authority") == &"on_foot":
		var push: Vector3 = direction.normalized() if direction.is_finite() and direction.length_squared() > 0.0001 else _player._visual.global_basis.z.normalized()
		var contact: Vector3 = at if at.is_finite() and at.length_squared() > 0.0001 else _player.global_position + Vector3.UP * 1.1
		var impulse: Vector3 = push * clampf(amount * 0.45, 10.0, 45.0)
		# Shared outward velocity carries the mass along the blow. The point impulse
		# adds the local turn of the struck head or torso under native joints.
		var outward: Vector3 = push * clampf(amount * 0.018, 0.2, 1.5)
		var started: Dictionary = driver.start_fall(_player.velocity, outward)
		_player_death_physics31 = {"started": bool(started.get("ok", false)), "impulse_ok": false,
			"reason": str(started.get("error", "")), "contact": contact, "impulse": impulse,
			"outward_velocity": outward}
		if bool(started.get("ok", false)):
			var applied: Dictionary = driver.body.apply_impulse(contact, impulse,
				"castle_player_death_%d" % Time.get_ticks_usec())
			_player_death_physics31.impulse_ok = bool(applied.get("ok", false))
			_player_death_physics31.reason = str(applied.get("error", ""))
			_player_death_physics31.bone = str(applied.get("bone", ""))
	_world.set("preview_dead", true)
	if is_instance_valid(transport) and transport.has_method("mark_dead"): transport.mark_dead()
	else: _player.set_preview_pose_authority(&"dead")
	if _player_death_driver31 != null and bool(_player_death_physics31.get("started", false)):
		_player_death_driver31.continue_after_death()
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
	var r := a0 - b0
	var a := u.dot(u)
	var e := v.dot(v)
	var f := v.dot(r)
	var first := 0.0
	var second := 0.0
	if a <= 0.00000001 and e <= 0.00000001: return a0.distance_to(b0)
	if a <= 0.00000001:
		second = clampf(f / e, 0.0, 1.0)
	else:
		var c := u.dot(r)
		if e <= 0.00000001:
			first = clampf(-c / a, 0.0, 1.0)
		else:
			var b := u.dot(v)
			var denominator := a * e - b * b
			if denominator > 0.00000001: first = clampf((b * f - c * e) / denominator, 0.0, 1.0)
			second = (b * first + f) / e
			if second < 0.0:
				second = 0.0
				first = clampf(-c / a, 0.0, 1.0)
			elif second > 1.0:
				second = 1.0
				first = clampf((b - c) / a, 0.0, 1.0)
	return (a0 + u * first).distance_to(b0 + v * second)

## Builds a sword transform with +X along `direction`.
func _place_basis(origin: Vector3, direction: Vector3) -> Transform3D:
	var x := direction.normalized()
	var reference := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	var z := x.cross(reference).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), origin)

var _contact_plane := Plane()
var _contact_anchor := Vector3.ZERO
var _contact_plane_active := false
var _contact_rid := RID()
var _edge_direction := Vector3.UP

func _reset_contact_plane() -> void:
	_contact_plane_active = false
	_contact_rid = RID()
	_contact_plane = Plane()
	_contact_anchor = Vector3.ZERO
	_ground_touch_ms = -10000

func _probe_blade_contact29() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_world): return
	var space := _player.get_world_3d().direct_space_state
	if space == null: return
	var reach := 0.06 + _weapon_length
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.030
	capsule.height = reach
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = _blade_shape_transform(_dir, _sword_origin + _dir * reach * 0.5)
	query.collision_mask = BLADE_PROBE_MASK
	# Match the strike sweep: rig hitboxes own flesh contact; movement hulls
	# must never become a world plane that prevents reaching those hitboxes.
	var excluded: Array[RID] = [_player.get_rid()]
	if is_instance_valid(_npc_body) and is_instance_valid(_npc_rig):
		excluded.append(_npc_body.get_rid())
	if is_instance_valid(_npc_corpse31):
		excluded.append(_npc_corpse31.get_rid())
	query.exclude = excluded
	var hit := space.get_rest_info(query)
	if hit.is_empty(): return
	var collider = instance_from_id(int(hit.get("collider_id", 0)))
	if not is_instance_valid(collider) or collider.has_meta("sword_target") or collider.has_meta("sword_duelist") or collider.has_meta("sword_npc_part"): return
	var normal: Vector3 = hit.normal
	if not normal.is_finite() or normal.length_squared() < 0.5: return
	_contact_plane = Plane(normal.normalized(), hit.point)
	_contact_rid = hit.get("rid", RID())
	_contact_anchor = _sword_origin
	_contact_plane_active = true

func _contact_direction(wanted: Vector3, allow_release: bool = false) -> Vector3:
	if not _contact_plane_active: return wanted
	var reach := 0.06 + _weapon_length
	var distance := _contact_plane.distance_to(_sword_origin)
	var clearance := distance + wanted.dot(_contact_plane.normal) * reach
	# A requested upward flick does not mean the heavy blade has already left
	# the floor. Keep the contact until the visible axis is clear too; outward
	# steering remains unrestricted by the plane while momentum catches up.
	var actual_clearance := distance + _dir.dot(_contact_plane.normal) * reach
	if _sword_origin.distance_to(_contact_anchor) > 0.55 or (allow_release and clearance > 0.10 and actual_clearance > 0.05):
		_reset_contact_plane()
		return wanted
	
	# The blade probe is a 3 cm capsule, whose far sphere is centered one
	# radius before its endpoint. Keep its support, not just its centerline, clear.
	var minimum := clampf(maxf((0.018 - distance) / reach, (0.031 - distance) / (reach - 0.030)), -1.0, 1.0)
	if wanted.dot(_contact_plane.normal) < minimum + 0.015:
		# Project angular velocity onto the contact constraint at EVERY step,
		# including frames without a new collision. Otherwise torque accumulates
		# against an immovable floor and is released as a repeated twitch.
		var gradient := _dir.cross(_contact_plane.normal)
		var into := _omega.dot(gradient)
		if into < 0.0 and gradient.length_squared() > 0.000001:
			_omega -= gradient * (into / gradient.length_squared())
	if wanted.dot(_contact_plane.normal) >= minimum: return wanted
	var tangent := wanted - _contact_plane.normal * wanted.dot(_contact_plane.normal)
	if tangent.length_squared() < 0.000001:
		tangent = _contact_plane.normal.cross(Vector3.RIGHT)
		if tangent.length_squared() < 0.000001: tangent = _contact_plane.normal.cross(Vector3.UP)
	return (tangent.normalized() * sqrt(maxf(0.0, 1.0 - minimum * minimum)) + _contact_plane.normal * minimum).normalized()

func _edge_axis(direction: Vector3) -> Vector3:
	# Pure projection: repeated render placement never advances the edge state.
	var x := direction.normalized()
	var y := _edge_direction - x * _edge_direction.dot(x)
	if y.length_squared() < 0.000001: y = x.cross(Vector3.RIGHT)
	if y.length_squared() < 0.000001: y = x.cross(Vector3.FORWARD)
	return y.normalized()

func _advance_edge(delta: float) -> void:
	# Integrate twist once on the physics clock, independently of render count.
	var x := _dir.normalized()
	var y := _edge_axis(x)
	var travel := _omega.cross(x)
	if _held and travel.length() > 0.6:
		var wanted := travel.normalized()
		if wanted.dot(y) < 0.0: wanted = -wanted
		var angle := y.signed_angle_to(wanted, x)
		y = y.rotated(x, clampf(angle, -4.0 * delta, 4.0 * delta))
	_edge_direction = y

func _place_sword(origin: Vector3, direction: Vector3) -> void:
	var x := direction.normalized()
	var y := _edge_axis(x)
	_sword.global_transform = Transform3D(Basis(x, y, x.cross(y).normalized()), origin)

func _edge_motion(motion: Vector3) -> float:
	if _weapon_id != "sword":
		var along := absf(motion.normalized().dot(_dir))
		return sqrt(maxf(0.0, 1.0 - along * along))
	return absf(motion.normalized().dot(_sword.global_basis.y.normalized()))

# -------------------------------------------------------------- blade sweeping

func _sweep(delta: float) -> void:
	if _embedded29.active(self):
		_prev_points = PackedVector3Array()
		return
	if _shield_guard_active29() or Engine.get_physics_frames() <= _shield_resume_frame29:
		_prev_points = PackedVector3Array()
		return
	if delta <= 0.0: return
	var authored_clash := Interception31.outgoing(self,delta)
	var points := PackedVector3Array()
	for i: int in SWEEP_SEGMENTS + 1:
		var t := float(i) / float(SWEEP_SEGMENTS)
		points.append(_sword_origin + _dir * (0.06 + _weapon_length * t))
	if _prev_points.size() != points.size():
		_prev_points = points
		return
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_player.get_rid()]
	# Tagged rig hitboxes own cuts; the broad movement hull must not hide them.
	if is_instance_valid(_npc_body) and is_instance_valid(_npc_rig):
		excluded.append(_npc_body.get_rid())
	if is_instance_valid(_npc_corpse31):
		excluded.append(_npc_corpse31.get_rid())
	var now := Time.get_ticks_msec()
	var touched: Dictionary = {}
	# A cut MEETS something and stops there. Only the FIRST contact along the swing
	# is resolved: resolving every collider crossed in one frame let a single swing
	# slice through an arm, a chest and both legs at once, with no resistance.
	var best_hit: Dictionary = {}
	var best_time := INF
	var seen: Dictionary = {}
	# The opponent's steel is a REAL barrier: if our blade meets his anywhere along
	# the swing, the cut stops there and nothing behind it is reached.
	var clash := not authored_clash.is_empty()
	var clash_time: float = float(authored_clash.get("fraction",INF))
	var clash_at: Vector3 = authored_clash.get("point",Vector3.ZERO)
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
		touched[collider.get_instance_id()] = true
		# Compare when each blade sample reaches its surface during this tick.
		var hit_time := clampf(from.distance_to(hit.position) / from.distance_to(to), 0.0, 1.0)
		if hit_time < best_time:
			best_time = hit_time
			best_hit = hit
			best_hit["_speed"] = from.distance_to(to) / delta
			best_hit["_velocity"] = (to - from) / delta
			best_hit["_index"] = i
	if clash and (best_hit.is_empty() or clash_time <= best_time + 0.001):
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
	# A ray beginning inside a solid reports a zero normal; never turn that
	# sentinel into a plane or a deflection axis.
	if not normal.is_finite() or normal.length_squared() < 0.5:
		var hit_rid: RID = hit.get("rid", RID())
		# An inside-hit sentinel cannot borrow a different obstacle's normal.
		if not _contact_plane_active or not hit_rid.is_valid() or hit_rid != _contact_rid: return
		normal = _contact_plane.normal
		position = _contact_plane.project(position)
	var is_target: bool = is_instance_valid(collider) and collider.has_meta("sword_target")
	var is_duelist: bool = is_instance_valid(collider) and collider.has_meta("sword_duelist")
	if not _held:
		# Carrying the sword is not a strike: a tip brushing the ground must not
		# push, deflect or rattle anything. Reacting here was the 10 Hz jitter.
		return
	var id_any: int = collider.get_instance_id() if is_instance_valid(collider) else -1
	var fresh: bool = id_any < 0 or not _contact_prev.has(id_any)
	if not is_target and not is_duelist and is_instance_valid(collider) and not collider.has_meta("sword_npc_part"):
		_contact_plane = Plane(normal.normalized(), position)
		_contact_rid = hit.get("rid", RID())
		_contact_anchor = _sword_origin
		_contact_plane_active = true
		_dir = _contact_direction(_dir)
		# Remove only velocity pressing into the plane. There is no restitution
		# while resting on it, so held input cannot repeatedly recharge a bounce.
		var tip_velocity := _omega.cross(_dir)
		if tip_velocity.dot(normal) < 0.0:
			var tangent := tip_velocity - normal * tip_velocity.dot(normal)
			_omega = _dir.cross(tangent)
		if normal.y > 0.7:
			_ground_touch_ms = now
			if fresh and speed > DAMAGE_SPEED_MIN and now - _last_block_sound_ms >= BLOCK_SOUND_COOLDOWN_MS:
				_last_block_sound_ms = now
				_combat_audio_surface30(collider,position,speed)
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
		if _held and _swing_can_damage31() and now - int(_hit_ms.get(id_any, -10000)) >= CONTACT_COOLDOWN_MS:
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
			_play_melee_hit31(position, "flesh", clampf(cut / DAMAGE_MAX, 0.0, 1.0))
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
		if _held and _swing_can_damage31() and npc_rearmed and not _contact_prev.has(id_any):
			_hit_ms[id_any] = now
			# The swept blade speed is measured at the point that contacted the
			# body, then weighted by preparation and weapon momentum.
			var strength := _strength_now()
			var npc_cut := _impact_damage31(speed * 0.6, strength, "slice")
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
				var contact_axis: Vector3 = call("_production_axis29") if has_method("_production_axis29") else _dir
				var along := absf(motion.normalized().dot(contact_axis))
				var across := _edge_motion(motion)
				var kind := "flat" if _weapon_crush else ("slice" if across >= 0.72 else ("stab" if along >= 0.72 else "flat"))
				npc_cut = _impact_damage31(speed * 0.6, strength, kind)
				var contact := _armor_point31(_npc_rig, npc_part, position, collider)
				var incidence := clampf(-motion.normalized().dot(normal), 0.0, 1.0)
				var attack_kind := "blunt" if _weapon_crush else kind
				var protection := ArmorDamage31.resolve(_npc_armor_loadout31, npc_part,
					attack_kind, npc_cut, contact, incidence)
				if str(protection.region) in ["cloth","mail","plate"] and str(protection.tier) in ["light","medium","heavy"]:
					combat_audio_event30("armor_"+str(protection.tier),position,clampf(npc_cut/160.0,.08,1.0),npc_part+":"+str(protection.region))
				var factor := float(protection.factor)
				if _weapon_id == "sword" and kind == "flat": factor *= 0.12
				if _half_sword:
					# Half-swording trades the cut for the point: a thrust from the
					# blade grip goes into the joints whatever the plate says.
					if kind == "stab" and protection.region == "joint":
						factor = maxf(factor, HALF_SWORD_THRUST)
					elif kind != "stab":
						factor *= HALF_SWORD_CUT
				var wound := npc_cut * factor
				var penetrates: bool = ArmorDamage31.tissue_penetrates(str(protection.region), attack_kind, wound)
				var rang_off_plate: bool = protection.region == "plate" and not penetrates
				# DSH_ANIM: a blow that bites jolts the body; one that rings off plate
				# jolts it less, which is a real difference in how the two feel.
				register_impact_jolt(0.45 if rang_off_plate else 0.8)
				_bite_into(0.72 if not rang_off_plate else 0.35)
				if rang_off_plate:
					# Steel on plate: clang and sparks instead of a wound.
					_spark_burst(position, -motion.normalized(), 8)
					_play_melee_hit31(position, "metal", clampf(npc_cut / DAMAGE_MAX, 0.2, 1.0))
					_scuff_knight_plate(npc_part, npc_cut)
					if wound > 0.05:
						_npc_take_blade_part(npc_part, position, speed, motion, wound,
							_npc_can_sever_contact31(attack_kind, speed, wound) and penetrates, penetrates)
				else:
					_play_melee_hit31(position, "flesh", clampf(wound / DAMAGE_MAX, 0.0, 1.0))
					if wound > 0.05:
						_npc_take_blade_part(npc_part, position, speed, motion, wound,
							_npc_can_sever_contact31(attack_kind, speed, wound) and penetrates, penetrates)
			else:
				_play_melee_hit31(position, "flesh", clampf(npc_cut / DAMAGE_MAX, 0.0, 1.0))
				if npc_cut > 0.05:
					_npc_take_blade(position, speed, hit.get("_velocity", Vector3.ZERO), npc_cut,
						_npc_can_sever_contact31("slice" if _edge_motion(hit.get("_velocity", Vector3.ZERO)) >= 0.72 else "flat", speed, npc_cut))
			_last_hit_kind = "slice"
		return
	if is_target:
		var id: int = collider.get_instance_id()
		# One entry = one blow, and only a deliberately steered blade (LMB held,
		# past the arming delay) hurts anything. Carrying the sword, drawing it or
		# letting it rest against the dummy never removes health. A blade that
		# keeps resting on the target must first leave it again (rearm window).
		var armed: bool = _held and _swing_can_damage31() and not _blocking and Time.get_ticks_msec() >= _arm_ready_ms
		var rearmed: bool = not _contact_gap.has(id) or now - int(_contact_gap[id]) >= CONTACT_REARM_MS
		if armed and rearmed and not _contact_prev.has(id):
			_damage_dummy(collider, position, speed, hit.get("_velocity", Vector3.ZERO), now)
		return
	if is_instance_valid(collider) and collider.get_meta("castle_furnishing", false):
		var site: Node = collider.get_parent()
		var armed: bool = _held and _swing_can_damage31() and not _blocking \
			and now >= _arm_ready_ms and speed >= DAMAGE_SPEED_MIN
		var rearmed: bool = not _contact_gap.has(id_any) or \
			now - int(_contact_gap[id_any]) >= CONTACT_REARM_MS
		if armed and fresh and rearmed and is_instance_valid(site) \
				and site.has_method("apply_melee_hit"):
			var result: Dictionary = site.call("apply_melee_hit", collider, position,
				speed, hit.get("_velocity", Vector3.ZERO))
			if bool(result.get("ok", false)):
				_combat_audio_surface30(collider,position,speed)
		return
	# Wall/pole: the visible blade stops and slides along the surface instead
	# of passing through. Pulling the mouse back releases it immediately. The
	# clang and the sparks are rate-limited so resting on masonry stays quiet.
	var first_touch: bool = fresh
	if first_touch and now - _last_block_sound_ms >= BLOCK_SOUND_COOLDOWN_MS:
		_last_block_sound_ms = now
		_blocks += 1
		_combat_audio_surface30(collider,position,speed)
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
	var across := _edge_motion(motion)
	# Blend from a pure stab to a clean slice; a flat slap stays near zero.
	var quality := 1.0 if _weapon_crush else clampf(across + along * 0.45, 0.0, 1.0)
	var effective := speed * quality
	var kind := "flat" if _weapon_crush else ("slice" if across >= 0.72 else ("stab" if along >= 0.72 else "flat"))
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
		combat_audio_event30("wood",position,.10,str(key))
		_dummy_tilt = maxf(_dummy_tilt, 0.05)
		return
	combat_audio_event30("wood",position,clampf(damage/DAMAGE_MAX,.1,1.0),str(key))
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
	# Shared helper merges the legacy flash+burst pair into one finite event.
	_spark_burst(at,-_dir,10)

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
var _npc_omega43 := Vector3.ZERO
var _npc_swing_started_ms50 := 0
var _npc_edge_up50 := Vector3.UP
var _npc_route_dir50 := Vector3.ZERO
var _npc_route_request53 := Vector3.ZERO
var _npc_replan_ms50 := 0
var _npc_detour_side50 := 1.0
var _npc_replans50 := 0
var _player_hitboxes50: Array[AnimatableBody3D] = []
const PLAYER_MELEE_LAYER50 := 1048576
var _npc_aim43 := Vector3.FORWARD
var _npc_threat_since43 := 0
var _npc_swing_start43 := Vector3.FORWARD
var _npc_state := "wait"
var _npc_timer := 0.0
const NPC_MAX_HP57 := 270.0
var _npc_hp := NPC_MAX_HP57
var _npc_engaged := false
var _npc_swings := 0
var _npc_hits := 0
var _npc_blocked := 0
var _npc_blade_prev: PackedVector3Array = PackedVector3Array()

## ---------------------------------------------------------- enemy knight
## The castle opponent is the enemy knight: a hostile, medium-armoured swordsman
## built from the city resident's own skin and canonical walk gait. He follows the
## same enemy-NPC rules the population uses, with no invisible shortcuts:
##   1. sight: real line of sight, a frontal cone and a 180 ms confirmation;
##   2. chase: the same local navigation/detour the residents use, never a teleport;
##   3. measure: he keeps sword distance, retreats when crowded and circles sideways;
##   4. defence: he reads the visible player blade, guards and counters after 180 ms;
##   5. attack: a windup only at a reachable, visible distance, with no late homing;
##   6. variety: left/right/overhead/rising/thrust chosen from the actual geometry;
##   7. pressure: a landed cut may chain into a second beat, a low-HP knight presses;
##   8. steel: a blade-on-blade clash stops BOTH cuts and physically pushes both men;
##   9. damage: only the swept visible blade deals damage, through the shared armour law;
##  10. death: the same real hitboxes, severing, blood and corpse ownership as the player.
## Medium harness = the lightest tier that still turns an edge, but a thrust and the
## joints get through; he is faster than the old plate duelist because of it.
const ENEMY_KNIGHT_ARMOR := {
	"head": "medium_head", "torso": "medium_torso", "hands": "medium_hands",
	"legs": "medium_legs", "feet": "medium_feet",
}
const ENEMY_SIGHT_RANGE := 24.0
## cos(~78 deg): a man watching his front, not a radar.
const ENEMY_SIGHT_DOT := 0.20
const ENEMY_REACTION_MS := 180
const ENEMY_LOST_SIGHT_MS := 2400
## Clash response: the player gets a bounded physical shove, the knight a body push.
const ENEMY_CLASH_PLAYER_PUSH_NS := 22.0
const ENEMY_CLASH_BODY_PUSH := 1.35
const ENEMY_CLASH_LOCK_MS := 220
const ENEMY_COMBO_GAP := 0.14
const ENEMY_ENRAGE_FRACTION := 0.35
var _enemy_seen_since_ms := 0
var _enemy_last_seen := Vector3.ZERO
var _enemy_lost_since_ms := 0
var _enemy_spotted_once := false
var _enemy_combo_left := 0
var _enemy_clashes := 0
var _enemy_last_clash_push := 0.0
var _enemy_clash_lock_until_ms := 0
var _enemy_evade_cooldown_ms := 0
var _enemy_evades := 0
var _enemy_armor_tier := "medium"
## Deliberate castle duel beats. The arm and visible steel perform every motion;
## damage still belongs exclusively to the swept blade ray below.
var _npc_attack_kind := "left"
var _npc_attack_cursor := 0
var _npc_guard_cooldown_ms := 0
var _npc_attack_counts: Dictionary = {"left": 0, "right": 0, "overhead": 0, "rising": 0, "thrust": 0}
var _npc_guard_entries := 0
var _npc_follow_dir := Vector3.FORWARD
var _npc_strike_had_hit := false
var _npc_last_impact31: Dictionary = {}
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
	if on and (_weapon_id != "sword" or _shield_worn or _hand_lost31(&"left") or _hand_lost31(&"right")):
		return
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
	# This castle opponent wears a torn shirt. No invisible plate protection.
	if _knight_armour.is_empty(): return 1.0
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
	_hammer_torque44 = Vector3.ZERO
	_omega *= clampf(1.0 - hardness, 0.05, 0.92)
	_bind_until_ms = now_ms() + (165 if _weapon_id == "sledge" else 95)
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
const MAIL := Color(0.78, 0.55, 0.27)
const PEASANT_SKIN := Color(0.79, 0.60, 0.43)
const PEASANT_HAIR := Color(0.24, 0.14, 0.085)
const PEASANT_TRIM := Color(0.43, 0.30, 0.18)
var _knight_armour: Array[Node3D] = []

func _dress_knight() -> void:
	if not is_instance_valid(_npc_rig): return
	# The enemy knight wears the existing MEDIUM harness on all five slots: an open
	# helmet and mail rather than the old black plate. The same fitted meshes and the
	# same ArmorDamage31 protection apply, so an edge is turned but a point or a joint
	# still finds him, and his mobility is the medium tier (1.0) instead of heavy 0.78.
	var result := set_npc_armor31(ENEMY_KNIGHT_ARMOR)
	if not result.get("ok", false): push_error("Enemy knight armor binding failed: " + str(result))
	_enemy_armor_tier = "medium"

## Cosmetic scuff only; future armour durability needs the life/gear owner.
func _scuff_knight_plate(part: String, impact: float) -> void:
	var bone_name := "chest" if part == "pelvis" else part
	for holder: Node3D in _knight_armour:
		if not is_instance_valid(holder): continue
		var anchor := holder.get_parent() as BoneAttachment3D
		if anchor == null or String(anchor.bone_name) != bone_name: continue
		for child: Node in holder.get_children():
			var plate := child as MeshInstance3D
			if plate == null or not plate.material_override is StandardMaterial3D: continue
			var previous := int(plate.get_meta("impact_scuffs", 0))
			if previous >= 8: continue
			var hits := previous + 1
			plate.set_meta("impact_scuffs", hits)
			var material := plate.material_override as StandardMaterial3D
			var darkened := material.duplicate() as StandardMaterial3D
			darkened.albedo_color = material.albedo_color.lerp(Color(0.14, 0.12, 0.11), clampf(float(hits) * 0.08 + impact * 0.002, 0.0, 0.68))
			plate.material_override = darkened

## Recolour the actual skinned resident surfaces separately. The former blanket
## dark-mail override made the face, hair, shirt and trousers equally black.
func _dress_peasant() -> void:
	var visual: Node = _npc_rig.get_parent()
	if visual == null: return
	var cloth_texture := _peasant_cloth_texture()
	var counts := {"fabric": 0, "skin": 0, "hair": 0, "trim": 0}
	var resident_fabric: MeshInstance3D = null
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var name := String(mesh.name)
		if name.begins_with("Knight") or name.begins_with("ResidentSword") or name.begins_with("KnightSword"): continue
		var key := ""
		if name.contains("FABRIC"): key = "fabric"
		elif name.contains("SKIN"): key = "skin"
		elif name.contains("HAIR") or name.begins_with("npc_hair") or name.begins_with("npc_combed") or name.begins_with("npc_brow"): key = "hair"
		elif name.contains("TRIM"): key = "trim"
		if key.is_empty(): continue
		var old := mesh.mesh.surface_get_material(0) as StandardMaterial3D if mesh.mesh != null else null
		var paint := old.duplicate() as StandardMaterial3D if old != null else StandardMaterial3D.new()
		paint.metallic = 0.0
		match key:
			"fabric":
				paint.albedo_color = Color.WHITE
				paint.albedo_texture = cloth_texture
				paint.vertex_color_use_as_albedo = false
				paint.roughness = 0.98
				resident_fabric = mesh
			"skin":
				paint.albedo_color = PEASANT_SKIN
				paint.roughness = 0.86
			"hair":
				paint.albedo_color = PEASANT_HAIR
				paint.roughness = 0.91
			"trim":
				paint.albedo_color = PEASANT_TRIM
				paint.roughness = 0.96
				# The resident's city tie, buttons and pocket edging are this mesh.
				# The rough over-shirt below takes their place in the castle.
				mesh.visible = false
		mesh.material_override = paint
		counts[key] = int(counts[key]) + 1
	if is_instance_valid(resident_fabric):
		_add_peasant_tunic(resident_fabric)
	print("DSH_SWORD_PROTO_PEASANT_MATERIALS ", counts)

## Woven, sun-faded cloth with two ragged dark snags. The texture stays opaque:
## this resident mesh has no torso flesh underneath to expose through holes.
func _peasant_cloth_texture(base_color: Color = MAIL) -> ImageTexture:
	var side := 128
	var cloth := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y: int in side:
		for x: int in side:
			var grain := float((x * 73 + y * 151 + x * y * 17) % 29) / 29.0
			var weave := 0.025 if (x % 4 < 2) == (y % 5 < 2) else -0.025
			var fade := 0.04 * sin(float(x) * 0.13 + float(y) * 0.07)
			var shade := 0.90 + (grain - 0.5) * 0.17 + weave + fade
			var tone := base_color * shade
			var stain := ((x * 11 + y * 17 + x * y) % 83) < 5
			if stain:
				tone = tone.lerp(Color(0.42, 0.31, 0.20), 0.28)
			cloth.set_pixel(x, y, tone)
	cloth.generate_mipmaps()
	return ImageTexture.create_from_image(cloth)

## A rough, uneven cloth overshirt lies over the original city coat. It uses
## the resident's own Skin and chest bind, so they follow the same walk/duel
## skeleton and can be cut by MeshSever. They have no collision or armour tag.
func _add_peasant_tunic(source: MeshInstance3D) -> void:
	if source.skin == null: return
	var chest := _npc_rig.find_bone("chest")
	if chest < 0: return
	var bind := -1
	for i: int in source.skin.get_bind_count():
		if source.skin.get_bind_bone(i) == chest:
			bind = i
			break
	if bind < 0: return
	var origin := _npc_rig.get_bone_global_pose(chest).origin
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: int in 2:
		var direction := 1.0 if face == 0 else -1.0
		var normal := Vector3(0.0, 0.0, direction)
		var points := PackedVector3Array()
		var uvs := PackedVector2Array()
		for row: int in 6:
			for column: int in 9:
				var u := float(column) / 8.0
				var v := float(row) / 5.0
				var x := (u - 0.5) * 2.10
				var y := 0.96 - v * 1.80
				if row == 0:
					y -= 0.20 * (1.0 - minf(1.0, absf(x) * 1.45))
				if row == 5:
					y += [-0.07, 0.03, -0.14, 0.02, -0.18, 0.01, -0.09, 0.05, -0.13][column]
				var curve := 0.50 + 0.19 * (1.0 - (x / 1.05) * (x / 1.05))
				var z := direction * (curve + 0.025 * sin(y * 4.3 + x * 5.7))
				points.append(origin + Vector3(x, y, z))
				uvs.append(Vector2(u, v))
		for row: int in 5:
			for column: int in 8:
				var a := row * 9 + column
				var b := a + 1
				var c := a + 9
				var d := c + 1
				var triangles := [[a, c, b], [b, c, d]]
				for side: int in 2:
					# Missing ragged triangles expose the resident's real cloth below.
					if face == 0 and ((row == 2 and column == 1 and side == 1) or (row == 3 and column == 6 and side == 0)):
						continue
					for index: int in triangles[side]:
						tool.set_normal(normal)
						tool.set_uv(uvs[index])
						tool.set_bones(PackedInt32Array([bind, 0, 0, 0]))
						tool.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
						tool.add_vertex(points[index])
	var tunic_mesh := tool.commit()
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color.WHITE
	cloth.albedo_texture = _peasant_cloth_texture(Color(0.95, 0.81, 0.55))
	cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	tunic_mesh.surface_set_material(0, cloth)
	var tunic := MeshInstance3D.new()
	tunic.name = "PeasantTornOvershirt"
	tunic.mesh = tunic_mesh
	tunic.skin = source.skin
	tunic.skeleton = source.skeleton
	tunic.set_meta("sword_peasant_cloth", true)
	_npc_rig.add_child(tunic)
	print("DSH_SWORD_PROTO_TUNIC skinned=", tunic.skin != null, " triangles=", tunic_mesh.surface_get_array_len(0) / 3)

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
	holder.set_meta("sword_armour_part", bone_name)
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
			# The original thigh-derived .396 x .373 box misses the resident's
			# visible eyes and helmet apertures. Preserve the per-bone hitbox and
			# physics exceptions, but fit the actual head/visor silhouette.
			box_size = Vector3(unit * 1.42, unit * 1.42, unit * 1.25)
			box_at = Vector3(0.0, blen * 0.55, 0.0)
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
		hit_body.sync_to_physics = false
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
		# The target box is hittable by the player's blade, but the knight's
		# own walking capsule must pass through his moving arm and legs.
		_npc_body.add_collision_exception_with(hit_body)
		hit_body.add_collision_exception_with(_npc_body)
		# Target volumes stay ray-queryable, but the player collides with the
		# physical knight/corpse rather than 15 invisible bone-attached boxes.
		if is_instance_valid(_player):
			_player.add_collision_exception_with(hit_body)
			hit_body.add_collision_exception_with(_player)
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

## Only a fast blade edge can separate tissue. A mace or sledge always crushes.
func _npc_can_sever_contact31(kind: String, speed: float, wound: float) -> bool:
	return not _weapon_crush and kind == "slice" and speed >= 3.2 and wound >= 8.0

## Damage a named part directly (used by the tagged limb hit boxes).
func _npc_take_blade_part(full_key: String, point: Vector3, speed: float, direction: Vector3,
		damage: float, sever_contact: bool = false, penetrates: bool = true) -> void:
	if _npc_severed.has(full_key): return
	if damage <= 0.05: return
	var kind := full_key
	if full_key.ends_with("_l") or full_key.ends_with("_r"):
		kind = full_key.substr(0, full_key.length() - 2)
	if _npc_dead and kind in ["chest", "pelvis"]: return
	if not _npc_part_hp.has(full_key):
		_npc_part_hp[full_key] = float(NPC_PART_HP57.get(kind, 120.0))
	_npc_part_hp[full_key] = float(_npc_part_hp[full_key]) - damage
	_npc_receive_impulse31(kind, speed, direction, damage)
	if _npc_dead: _npc_corpse_hit31(point, direction, clampf(speed * 1.5, 0.0, 32.0))
	if not _npc_dead: _npc_engaged = true
	if not _npc_dead and damage >= 3.0:
		_npc_state = "recover"
		_npc_timer = 0.0
		_npc_blade_prev = PackedVector3Array()
	if penetrates:
		_spray_blood(point, direction, 2 if damage < 3.0 else (10 if damage < 20.0 else 24))
		# A wound keeps bleeding for a while, like a stream rather than one puff.
		_npc_bleed_until_ms = max(_npc_bleed_until_ms, Time.get_ticks_msec() + (600 if damage < 3.0 else 2600))
		_npc_anchor_wound27(full_key, point)
	# Small melee scratches flinch visually; only deep wounds interrupt combat.
	if damage >= 3.0:
		_npc_pain_until_ms = maxi(_npc_pain_until_ms, Time.get_ticks_msec() + (1200 if damage >= 20.0 else 650))
	else:
		_npc_flinch_until_ms31 = maxi(_npc_flinch_until_ms31, Time.get_ticks_msec() + 160)
	if float(_npc_part_hp[full_key]) > 0.0:
		_npc_apply_health_wound50(damage, point, direction, speed, penetrates)
		return
	# Vital tissue can fail from a blunt blow, a thrust, or cumulative wounds.
	# Separation is a separate event: only a fast slicing contact may sever.
	if kind in ["chest", "pelvis"] or (kind == "head" and not sever_contact):
		_npc_die_from_vital_wound31(point, direction, speed, penetrates)
	# A ruined weapon arm cannot keep fighting just because a blunt blow did
	# not cut it off. Keep the real limb visible and its collider intact.
	if not sever_contact and full_key in ["upperarm_r", "forearm_r", "hand_r"] and not _npc_dead:
		_npc_disarmed = true
		_npc_engaged = false
		_npc_state = "wait"
		if is_instance_valid(_npc_sword): _drop_sword(_npc_sword.global_position, direction, speed)
	if kind in ["chest", "pelvis"] or not sever_contact or not penetrates:
		_npc_apply_health_wound50(damage, point, direction, speed, penetrates)
		return
	_sever_part(full_key, kind, {"sever": full_key}, point, direction, speed)
	_npc_apply_health_wound50(damage, point, direction, speed, penetrates)

func _npc_die_from_vital_wound31(point: Vector3, direction: Vector3, speed: float,
		bleeds: bool = true) -> void:
	if _npc_dead: return
	_npc_dead = true
	_npc_disarmed = true
	_npc_engaged = false
	_npc_state = "wait"
	if bleeds:
		_spray_blood(point, direction, 60)
		_npc_bleed_until_ms = maxi(_npc_bleed_until_ms, Time.get_ticks_msec() + 4000)
	if is_instance_valid(_npc_sword):
		_drop_sword(_npc_sword.global_position, direction, speed)
	_queue_npc_corpse31(point, direction, speed)

## A projectile punctures tissue; it never calls the blade/mesh severing path.
func _npc_take_arrow_part(full_key: String, point: Vector3, speed: float,
		direction: Vector3, damage: float, hit_normal: Vector3 = Vector3.ZERO) -> Dictionary:
	var base := full_key.trim_suffix("_l").trim_suffix("_r")
	var hit_body: CollisionObject3D = null
	var anchor := _npc_rig.get_node_or_null("Hit" + full_key) if is_instance_valid(_npc_rig) else null
	if anchor != null:
		for child: Node in anchor.get_children():
			if child is CollisionObject3D:
				hit_body = child
				break
	var incidence := 1.0
	if hit_normal.length_squared() > 0.5:
		incidence = clampf(-direction.normalized().dot(hit_normal.normalized()), 0.0, 1.0)
	var incoming := damage * (2.0 if base == "head" else 1.0)
	var contact := _armor_point31(_npc_rig, full_key, point, hit_body)
	var protection := ArmorDamage31.resolve(_npc_armor_loadout31, full_key, "stab", incoming, contact, incidence)
	if str(protection.region) in ["cloth","mail","plate"] and str(protection.tier) in ["light","medium","heavy"]:
		combat_audio_event30("armor_"+str(protection.tier),point,clampf(incoming/160.0,.08,1.0),"arrow:"+full_key+":"+str(protection.region))
	var wound := float(protection.damage)
	var penetrates: bool = ArmorDamage31.tissue_penetrates(str(protection.region), "stab", wound)
	var result := _npc_take_puncture_part31(full_key, point, speed, direction, wound, 0.06, penetrates)
	result["region"] = protection.region
	result["penetrates"] = penetrates
	result["residual_damage"] = wound
	return result

func _npc_take_puncture_part31(full_key: String, point: Vector3, speed: float,
		direction: Vector3, damage: float, projectile_mass: float, penetrates: bool = true) -> Dictionary:
	if _npc_dead or _npc_severed.has(full_key) or damage <= 0.05:
		return {"applied": false, "damage": 0.0, "dead": _npc_dead}
	var base := full_key.trim_suffix("_l").trim_suffix("_r")
	_npc_part_hp[full_key] = float(_npc_part_hp.get(full_key, NPC_PART_HP57.get(base, 120.0))) - damage
	_npc_hp = maxf(0.0, _npc_hp - damage)
	_npc_engaged = true
	_npc_stop_attack43()
	# Projectile momentum uses projectile mass, never the player's held weapon.
	var push := direction.normalized() * clampf(projectile_mass * speed / 65.0, 0.0, 3.5)
	push.y = 0.0
	_npc_hit_push31 = (_npc_hit_push31 + push).limit_length(5.0)
	_npc_pain_until_ms = maxi(_npc_pain_until_ms, now_ms() + (650 if damage >= 3.0 else 160))
	if penetrates:
		_spray_blood(point, direction, 2 if damage < 3.0 else 12)
		_npc_bleed_until_ms = maxi(_npc_bleed_until_ms, now_ms() + (600 if damage < 3.0 else 2600))
		_npc_anchor_wound27(full_key, point)
	if _npc_hp <= 0.0 or (base in ["head", "chest", "pelvis"] and float(_npc_part_hp[full_key]) <= 0.0):
		_npc_dead = true
		_npc_disarmed = true
		_npc_engaged = false
		_npc_state = "wait"
		if is_instance_valid(_npc_sword): _drop_sword(_npc_sword.global_position, direction, speed)
		_queue_npc_corpse31(point, direction, speed)
	return {"applied": true, "damage": damage, "dead": _npc_dead}

## The wound keeps pouring for a few seconds instead of a single puff.
var _npc_bleed_until_ms := 0
var _npc_bleed_at := Vector3.ZERO
var _npc_bleed_local := Vector3.ZERO
var _npc_bleed_bone27 := -1
var _npc_bleed_bone_local27 := Vector3.ZERO
var _npc_bleed_accum := 0.0
var _npc_pain_until_ms := 0
var _npc_flinch_until_ms31: int = 0
var _npc_hop_wait := 0.0
var _npc_hit_push31 := Vector3.ZERO
var _npc_knocked_until_ms31 := 0
var _npc_hull31: CollisionShape3D
var _npc_knockdowns31 := 0
var _npc_knock_pose_active27 := false
var _npc_knock_roll_speed27 := 0.0
## When he is cut down he topples over instead of standing there.
var _npc_corpse31: RigidBody3D
var _npc_corpse_pending31 := false
var _npc_dropped_sword31: RigidBody3D
var _npc_disarmed_at_ms := 0

## A single physical corpse carries the existing actor and rig. Keeping the
## CharacterBody node as a disabled child preserves tagged hitbox ancestry,
## existing wound ownership and the live skinned/armor meshes for later cuts.
func _queue_npc_corpse31(point: Vector3, direction: Vector3, speed: float) -> void:
	if _npc_corpse_pending31 or is_instance_valid(_npc_corpse31) or not is_instance_valid(_npc_body): return
	_npc_corpse_pending31 = true
	_start_npc_corpse31.call_deferred(_npc_body.get_instance_id(), point, direction, speed)

## Freeze the collision envelope from the same posed skin shown at death.
## A standing capsule does not enclose bent limbs or the rig's skin offset.
func _npc_corpse_shape31(corpse_frame: Transform3D) -> Shape3D:
	var points := PackedVector3Array()
	var inverse := corpse_frame.affine_inverse()
	for child: Node in _npc_rig.get_parent().find_children("*", "MeshInstance3D", true, false):
		var visual := child as MeshInstance3D
		if visual.mesh == null or not visual.is_visible_in_tree(): continue
		var binds: Array[Transform3D] = []
		if visual.skin != null:
			for index in visual.skin.get_bind_count():
				var name := visual.skin.get_bind_name(index)
				var bone := _npc_rig.find_bone(name) if name != &"" else visual.skin.get_bind_bone(index)
				if bone < 0 or bone >= _npc_rig.get_bone_count(): return null
				binds.append(inverse * _npc_rig.global_transform * _npc_rig.get_bone_global_pose(bone) * visual.skin.get_bind_pose(index))
		for surface in visual.mesh.get_surface_count():
			var arrays: Array = visual.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if points.size() + vertices.size() > 100000: return null
			var skinned := not binds.is_empty() and bones != null and weights != null
			if skinned and (bones.size() != vertices.size() * 4 or weights.size() != bones.size()): return null
			for index in vertices.size():
				var point: Vector3 = inverse * visual.global_transform * vertices[index]
				if skinned:
					point = Vector3.ZERO
					for slot in 4:
						var weight: float = weights[index * 4 + slot]
						if weight <= 0.0: continue
						var bind: int = bones[index * 4 + slot]
						if bind < 0 or bind >= binds.size(): return null
						point += binds[bind] * vertices[index] * weight
				if not point.is_finite(): return null
				points.append(point)
	if points.size() < 4: return null
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	hull.margin = 0.015
	return hull

func _start_npc_corpse31(life_id: int, point: Vector3, direction: Vector3, speed: float) -> void:
	_npc_corpse_pending31 = false
	if not _npc_dead or not is_instance_valid(_npc_body) or _npc_body.get_instance_id() != life_id or is_instance_valid(_npc_corpse31): return
	if not point.is_finite(): point = _npc_body.global_position + Vector3.UP
	if not direction.is_finite(): direction = _npc_body.global_basis.z
	if not is_finite(speed): speed = 0.0
	var corpse := RigidBody3D.new()
	corpse.name = "SwordKnightCorpse31"
	corpse.set_meta("melee_corpse33", true)
	corpse.mass = 7.0
	# Lightweight remains yield to real foot contacts without excessive friction.
	var contact_material := PhysicsMaterial.new()
	contact_material.friction = 0.25
	contact_material.bounce = 0.0
	corpse.physics_material_override = contact_material
	corpse.collision_layer = 1
	corpse.collision_mask = 1
	corpse.continuous_cd = true
	corpse.contact_monitor = true
	corpse.max_contacts_reported = 16
	corpse.linear_damp = 0.25
	corpse.angular_damp = 1.2
	var corpse_frame := Transform3D(_npc_body.global_basis,
		_npc_body.global_position + Vector3.UP * (NPC_HEIGHT * 0.5 + 0.06))
	var shape := CollisionShape3D.new()
	shape.shape = _npc_corpse_shape31(corpse_frame)
	if shape.shape == null:
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.36
		capsule.height = NPC_HEIGHT
		shape.shape = capsule
	corpse.add_child(shape)
	_world.add_child(corpse)
	# The castle paving overlaps the standing feet by a few centimetres. Give
	# only the new proxy capsule 6 cm of clearance; the visible rig stays put.
	corpse.global_transform = corpse_frame
	# Swap collision authority outside the physics query flush. The old walking
	# capsule stays alive only as a transform/ownership root for postmortem cuts.
	_npc_body.collision_layer = 0
	_npc_body.collision_mask = 0
	_npc_hull31.disabled = true
	_npc_body.reparent(corpse, true)
	for hit: Node in _npc_rig.find_children("*", "AnimatableBody3D", true, false):
		if str(hit.get_meta("sword_npc_part", "")) != "":
			corpse.add_collision_exception_with(hit as CollisionObject3D)
			(hit as CollisionObject3D).add_collision_exception_with(corpse)
	# The blade was dropped at the fist in this death tick. Its box can start
	# inside the torso capsule, so keep their collisions separate while the blade
	# remains its own pickable world rigid body.
	if is_instance_valid(_npc_dropped_sword31):
		corpse.add_collision_exception_with(_npc_dropped_sword31)
		_npc_dropped_sword31.add_collision_exception_with(corpse)
	_npc_corpse31 = corpse
	var horizontal: Vector3 = _npc_body.velocity + _npc_hit_push31
	horizontal.y = 0.0
	corpse.linear_velocity = horizontal.limit_length(3.0)
	var impact: Vector3 = direction.normalized() if direction.length_squared() > 0.0001 else _npc_body.global_basis.z
	var impulse: Vector3 = impact * clampf(speed * 5.0, 18.0, 120.0) * (corpse.mass / 70.0)
	_npc_corpse_hit31(point, impact, impulse.length())
	_npc_hit_push31 = Vector3.ZERO
	print("DSH_NPC_CORPSE31 physical=1 impulse=", impulse, " at=", point)

func _npc_corpse_hit31(point: Vector3, direction: Vector3, impulse_ns: float) -> void:
	if not is_instance_valid(_npc_corpse31) or not point.is_finite() or not direction.is_finite() or not is_finite(impulse_ns): return
	if direction.length_squared() < 0.0001 or impulse_ns <= 0.0: return
	if _npc_corpse31.has_meta("ragdoll31"):
		if int(get_meta("solid_impulse_frame31",-1))==Engine.get_physics_frames():return
		_npc_corpse31.get_meta("ragdoll31").impact(point,direction,impulse_ns)
		return
	var corpse: RigidBody3D = _npc_corpse31
	var capsule_radius := 0.36
	var impulse: Vector3 = direction.normalized() * impulse_ns
	# In the castle transition fixture, applying an impulse before this new body
	# completed its first physics step yielded a velocity near the impulse value
	# despite mass 70. Transfer this measured momentum explicitly in kg, with the
	# hit point's turning moment, so the initial result stays bounded.
	corpse.linear_velocity += impulse / corpse.mass
	var lever: Vector3 = point - corpse.global_position
	var transverse_inertia: float = corpse.mass * (NPC_HEIGHT * NPC_HEIGHT + 3.0 * capsule_radius * capsule_radius) / 12.0
	corpse.angular_velocity += (lever.cross(impulse) / transverse_inertia).limit_length(3.0)

## Transfer only measured impact momentum. The heavy head of a sledge can push
## a much lighter body over, while a slow brush barely moves it. The capsule
## stays on the physics floor during the fall and lies along the fallen torso.
func _npc_receive_impulse31(part: String, speed: float, direction: Vector3, damage: float) -> void:
	if _npc_dead or not is_instance_valid(_npc_body): return
	var horizontal := direction
	horizontal.y = 0.0
	if horizontal.length_squared() < 0.04 and is_instance_valid(_player):
		horizontal = _npc_body.global_position - _player.global_position
		horizontal.y = 0.0
	if horizontal.length_squared() < 0.0001: return
	var balance_impact := clampf(sqrt(maxf(0.4, _weapon_mass)) * maxf(0.0, speed - 1.0) \
		* maxf(0.0, damage) * 0.0072, 0.0, 5.0)
	# Wound severity can break balance, but it is not translational momentum.
	# Use the same 65 kg body mass as the projectile path. Multiplying damage
	# by speed used to launch a standing fighter at 5 m/s for several metres.
	var impulse := maxf(0.4, _weapon_mass) * maxf(0.0, speed - 1.0) / 65.0
	_npc_hit_push31 = (_npc_hit_push31 + horizontal.normalized() * impulse).limit_length(1.25)
	if part in ["head", "chest", "pelvis"] and balance_impact >= 2.7 \
			and _npc_state != "guard" and now_ms() >= _npc_knocked_until_ms31:
		_npc_knocked_until_ms31 = now_ms() + 1900
		_npc_knockdowns31 += 1
		_npc_knock_pose_active27 = true
		_npc_knock_roll_speed27 = 0.0
		_npc_state = "recover"
		_npc_timer = 0.0
		_npc_blade_prev = PackedVector3Array()

## Runs the open wound: a steady stream of drops from the cut.
func _npc_advance_knock_pose27(delta: float, down: bool) -> void:
	# Start from rest and accelerate into the fall. Exponential pose lerp applied
	# its largest rotation in the first tick, moving the chest by 16cm instantly.
	var target := -PI * 0.48 if down else 0.0
	var angle := _npc_motion.rotation.x
	var remaining := target - angle
	var acceleration := 9.0
	var desired := signf(remaining) * minf(3.0, sqrt(2.0 * acceleration * absf(remaining)) * 0.80)
	_npc_knock_roll_speed27 = move_toward(_npc_knock_roll_speed27, desired, acceleration * delta)
	var step := _npc_knock_roll_speed27 * delta
	if absf(step) > absf(remaining) and signf(step) == signf(remaining):
		step = remaining
		_npc_knock_roll_speed27 = 0.0
	angle += step
	_npc_motion.rotation.x = angle
	var fraction := clampf(angle / (-PI * 0.48), 0.0, 1.0)
	if is_instance_valid(_npc_hull31):
		_npc_hull31.rotation.x = -PI * 0.5 * fraction
		_npc_hull31.position = Vector3(0.0, NPC_HEIGHT * 0.5, 0.0).lerp(Vector3(0.0, 0.38, -0.70), fraction)
	if not down and absf(angle) < 0.001 and absf(_npc_knock_roll_speed27) < 0.02:
		_npc_motion.rotation.x = 0.0
		_npc_knock_roll_speed27 = 0.0
		_npc_knock_pose_active27 = false

func _npc_anchor_wound27(part: String, point: Vector3, stump: bool = false) -> void:
	_npc_bleed_at = point
	_npc_bleed_bone27 = -1
	if is_instance_valid(_npc_body): _npc_bleed_local = _npc_body.to_local(point)
	if not is_instance_valid(_npc_rig): return
	var bone := _npc_rig.find_bone(part)
	# A stump belongs to the remaining proximal joint, never the hidden distal bone.
	if stump and bone >= 0: bone = _npc_rig.get_bone_parent(bone)
	if bone < 0: return
	var frame := _npc_rig.global_transform * _npc_rig.get_bone_global_pose(bone)
	if absf(frame.basis.determinant()) < 0.000001: return
	_npc_bleed_bone27 = bone
	_npc_bleed_bone_local27 = frame.affine_inverse() * point

func _npc_wound_position27() -> Vector3:
	if is_instance_valid(_npc_rig) and _npc_bleed_bone27 >= 0 and _npc_bleed_bone27 < _npc_rig.get_bone_count():
		return _npc_rig.global_transform * _npc_rig.get_bone_global_pose(_npc_bleed_bone27) * _npc_bleed_bone_local27
	return _npc_body.to_global(_npc_bleed_local) if is_instance_valid(_npc_body) else _npc_bleed_at

func _update_npc_bleed(delta: float) -> void:
	if not is_instance_valid(_npc_body): return
	var now := Time.get_ticks_msec()
	if now > _npc_bleed_until_ms: return
	# The wound belongs to the moving body. A fixed world point left a blood fountain
	# behind when a wounded opponent limped or hopped away.
	_npc_bleed_at = _npc_wound_position27()
	_npc_bleed_accum += delta
	if _npc_bleed_accum < 0.035: return
	_npc_bleed_accum = 0.0
	var drop_dir := (Vector3.UP * 0.30 + _npc_body.global_basis.x * randf_range(-0.65, 0.65)
		+ _npc_body.global_basis.z * randf_range(0.35, 0.8)).normalized()
	_spray_blood(_npc_bleed_at + Vector3(randf_range(-0.012, 0.012), randf_range(-0.012, 0.012), randf_range(-0.012, 0.012)),
		drop_dir, 4)

## A lost foot or leg leaves one support leg for a slow hop. Losing both removes
## locomotion rather than letting the walking gait keep moving an invisible body.
# Match the NPC support rule: depleted HP alone is not a missing limb.
func player_leg_speed_scale50() -> float:
	var left_lost := _player_severed.has("thigh_l") or _player_severed.has("shin_l") or _player_severed.has("foot_l")
	var right_lost := _player_severed.has("thigh_r") or _player_severed.has("shin_r") or _player_severed.has("foot_r")
	if left_lost and right_lost: return 0.0
	if left_lost or right_lost: return 0.24
	return 1.0

func _npc_leg_lost(side: String) -> bool:
	return _npc_severed.has("thigh_" + side) or _npc_severed.has("shin_" + side) \
		or _npc_severed.has("foot_" + side)

func _npc_speed_scale() -> float:
	var left_lost := _npc_leg_lost("l")
	var right_lost := _npc_leg_lost("r")
	if left_lost and right_lost: return 0.0
	if left_lost or right_lost: return 0.24 * ArmorDamage31.movement_multiplier(_npc_armor_loadout31)
	return ArmorDamage31.movement_multiplier(_npc_armor_loadout31)

## ---- DSH_GORE: real severing of the knight's own skin ----------------
## The old dismemberment collapsed a limb's bones to nothing and spawned a stump that
## only looked like a wound. These functions cut the ACTUAL body surface along a plane,
## keep the side that stays on the body (still skinned, so it keeps deforming), and
## hand the side that comes off to the world as rigid debris - the same piece of skin
## that was cut away, not a stand-in.
var _npc_cut_total := 0
# A real head cut leaves a skinned neck cap; shrinking its bone destroys the cap.
var _npc_head_mesh_cut31 := false
var _npc_mesh_cut_parts39: Dictionary = {}
var _npc_debris: Array[Dictionary] = []

## The knight's SKINNED mesh instances. The armour plates are attached rigidly to bones,
## so they are deliberately skipped: only real skinned surfaces can be cut.
func _npc_skinned_meshes(target_rig: Skeleton3D = null) -> Array:
	var cut_rig: Skeleton3D = target_rig if is_instance_valid(target_rig) else _npc_rig
	var out: Array = []
	if not is_instance_valid(cut_rig): return out
	var visual: Node = cut_rig.get_parent()
	if visual == null: return out
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if cut_rig == _rig and not mesh_node.is_visible_in_tree(): continue
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
func _npc_limb_bind_ids(mesh_node: MeshInstance3D, part_key: String, target_rig: Skeleton3D = null) -> Dictionary:
	var cut_rig: Skeleton3D = target_rig if is_instance_valid(target_rig) else _npc_rig
	var ids: Dictionary = {}
	if not is_instance_valid(cut_rig) or mesh_node.skin == null: return ids
	var base := cut_rig.find_bone(part_key)
	if base < 0: return ids
	for bind: int in mesh_node.skin.get_bind_count():
		var bind_name := mesh_node.skin.get_bind_name(bind)
		var bone: int = cut_rig.find_bone(bind_name) if bind_name != &"" else mesh_node.skin.get_bind_bone(bind)
		while bone >= 0:
			if bone == base:
				ids[bind] = true
				break
			bone = cut_rig.get_bone_parent(bone)
	return ids

# Cut in the visible posed surface, then restore the kept vertices to bind space.
# Detached pieces keep the posed coordinates and no longer follow a skeleton.
func _cut_skin_transforms39(node: MeshInstance3D, target_rig: Skeleton3D = null) -> Array[Transform3D]:
	var cut_rig: Skeleton3D = target_rig if is_instance_valid(target_rig) else _npc_rig
	var out: Array[Transform3D] = []
	if node.skin == null: return out
	var to_mesh := node.global_transform.affine_inverse() * cut_rig.global_transform
	for index in node.skin.get_bind_count():
		var name := node.skin.get_bind_name(index)
		var bone := cut_rig.find_bone(name) if name != &"" else node.skin.get_bind_bone(index)
		if bone < 0: return []
		out.append(to_mesh * cut_rig.get_bone_global_pose(bone) * node.skin.get_bind_pose(index))
	return out

func _cut_skin_arrays39(source: Array, binds: Array[Transform3D], undo: bool) -> Array:
	var arrays: Array = source.duplicate(true)
	if arrays.is_empty() or binds.is_empty(): return arrays
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	if bones == null or weights == null or bones.size() != vertices.size() * 4: return arrays
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	for i in vertices.size():
		var matrix := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
		var total := 0.0
		for k in 4:
			var weight: float = weights[i * 4 + k]
			var index: int = bones[i * 4 + k]
			if weight <= 0.0 or index < 0 or index >= binds.size(): continue
			matrix.basis.x += binds[index].basis.x * weight
			matrix.basis.y += binds[index].basis.y * weight
			matrix.basis.z += binds[index].basis.z * weight
			matrix.origin += binds[index].origin * weight
			total += weight
		if total < 0.001 or absf(matrix.basis.determinant()) < 0.0000001: continue
		if undo: matrix = matrix.affine_inverse()
		vertices[i] = matrix * vertices[i]
		if normals.size() == vertices.size(): normals[i] = (matrix.basis.inverse().transposed() * normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not normals.is_empty(): arrays[Mesh.ARRAY_NORMAL] = normals
	return arrays

func _record_actor_cut50(cut_rig: Skeleton3D) -> void:
	if cut_rig == _rig: _player_cut_total50 += 1
	else: _npc_cut_total += 1

func npc_cut_body(plane_world: Plane, keep_point_world: Vector3, part_key: String = "", preserve_head31: bool = false, target_rig: Skeleton3D = null) -> bool:
	var cut_rig: Skeleton3D = target_rig if is_instance_valid(target_rig) else _npc_rig
	var meshes := _npc_skinned_meshes(cut_rig)
	if meshes.is_empty():
		print("DSH_GORE_CUT refused=no_skinned_mesh")
		return false
	var any := false
	var detached_whole31: Array[Node3D] = []
	var debris_start31 := _npc_debris.size()
	var prepared_layers39: Array[Dictionary] = []
	for entry: Variant in meshes:
		var mesh_node: MeshInstance3D = entry
		if not is_instance_valid(mesh_node): continue
		var source: ArrayMesh = mesh_node.mesh
		var local_plane := _plane_in_local(mesh_node, plane_world)
		var keep_local: Vector3 = mesh_node.global_transform.affine_inverse() * keep_point_world
		var keep_front: bool = local_plane.distance_to(keep_local) >= 0.0
		var part_binds: Dictionary = {}
		if not part_key.is_empty():
			part_binds = _npc_limb_bind_ids(mesh_node, part_key, cut_rig)
			if part_binds.is_empty(): continue
		var skin_transforms := _cut_skin_transforms39(mesh_node, cut_rig)
		var posed := ArrayMesh.new()
		for surface in source.get_surface_count():
			posed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
				_cut_skin_arrays39(source.surface_get_arrays(surface), skin_transforms, false))
		var cut = MeshSever.cut(posed, local_plane, part_binds, keep_front)
		if cut.body_contour_invalid: return false
		var kept_arrays: Array = cut.front_arrays if keep_front else cut.back_arrays
		var gone_arrays: Array = cut.back_arrays if keep_front else cut.front_arrays
		var kept_cap: Array = cut.front_cap_arrays if keep_front else cut.back_cap_arrays
		var gone_cap: Array = cut.back_cap_arrays if keep_front else cut.front_cap_arrays
		# A closed glove/boot can lie wholly beyond the cut with no crossing edges.
		# Move that original layer rather than leaving it on preserved bones.
		var whole_detach39: bool = kept_arrays.is_empty() and not gone_arrays.is_empty() and cut.triangles_split == 0
		# Disconnected skin islands can share one surface: a fist is entirely distal
		# while the face and opposite hand stay proximal. They need partitioning even
		# when no triangle crosses the plane; there is no new opening to cap.
		var disconnected_detach33: bool = cut.triangles_split == 0 and not gone_arrays.is_empty()
		if cut.triangles_split == 0 and not disconnected_detach33: continue
		# Validate every intersecting layer before changing ANY original mesh.
		# Partial failure must not mark the whole limb as successfully mesh-cut.
		if not disconnected_detach33:
			if kept_arrays.is_empty() or gone_arrays.is_empty(): return false
			if kept_cap.is_empty() or gone_cap.is_empty():
				# Clay-only garment sheets can have an original open edge. Slice the
				# real sheet without inventing a flesh cap; closed body layers still
				# require both caps, and branch-created gaps do not qualify.
				var verified_sheet28: bool = part_key == "_clay_torso" and str(mesh_node.name).begins_with("Armor") and cut.open_boundary_verified
				if not verified_sheet28: return false
				kept_cap = []
				gone_cap = []
		var kept_indices: Array[int] = cut.front_surface_indices if keep_front else cut.back_surface_indices
		var gone_indices: Array[int] = cut.back_surface_indices if keep_front else cut.front_surface_indices
		var source_materials: Array[Material] = []
		for surface_index: int in source.get_surface_count():
			source_materials.append(mesh_node.get_active_material(surface_index))
		var gone_materials: Array[Material] = []
		for source_index: int in gone_indices:
			gone_materials.append(source_materials[source_index])
		prepared_layers39.append({"node":mesh_node,"source":source,"kept":kept_arrays,"gone":gone_arrays,
			"kept_cap":kept_cap,"gone_cap":gone_cap,"kept_indices":kept_indices,
			"materials":source_materials,"gone_materials":gone_materials,"binds":skin_transforms,"whole":whole_detach39})
	for layer39: Dictionary in prepared_layers39:
		var mesh_node: MeshInstance3D = layer39.node
		var source: ArrayMesh = layer39.source
		var kept_arrays: Array = layer39.kept
		var gone_arrays: Array = layer39.gone
		var kept_cap: Array = layer39.kept_cap
		var gone_cap: Array = layer39.gone_cap
		var kept_indices: Array[int] = layer39.kept_indices
		var source_materials: Array[Material] = layer39.materials
		var gone_materials: Array[Material] = layer39.gone_materials
		var skin_transforms: Array[Transform3D] = layer39.binds
		if layer39.whole:
			_spawn_cut_debris(gone_arrays, [], mesh_node, plane_world.normal, gone_materials, _player if cut_rig == _rig else _npc_body)
			mesh_node.mesh = null
			any = true
			_record_actor_cut50(cut_rig)
			continue
		# 1. The body keeps its side, with the cut face closed.
		var body_mesh := ArrayMesh.new()
		var hero_first_arrays31: Array = []
		for arrays: Array in kept_arrays:
			var restored_arrays31: Array = _cut_skin_arrays39(arrays, skin_transforms, true)
			if hero_first_arrays31.is_empty(): hero_first_arrays31 = restored_arrays31
			body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, restored_arrays31)
		for i: int in body_mesh.get_surface_count():
			var material: Material = source_materials[kept_indices[i]]
			if material != null: body_mesh.surface_set_material(i, material)
		# The cut face is ONE surface with its own flesh material. The cap comes back as a
		# single packed array, not a list of them - iterating it as a list handed a Null
		# to add_surface_from_arrays, which is why the cut silently fell back.
		if not kept_cap.is_empty():
			body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _cut_skin_arrays39(kept_cap, skin_transforms, true))
			body_mesh.surface_set_material(body_mesh.get_surface_count() - 1, _flesh())
		if body_mesh.get_surface_count() > 0:
			# Old slot overrides would otherwise recolour a shifted surface or its cap.
			for surface_index: int in source.get_surface_count():
				mesh_node.set_surface_override_material(surface_index, null)
			mesh_node.mesh = body_mesh
			if mesh_node.has_meta("hero_medieval31"):
				mesh_node.set_meta("hero_wound_arrays31", {"mesh":body_mesh,"arrays":hero_first_arrays31})
			# The old mail override hid the flesh cap. Surface materials preserve mail
			# on the exterior while the new cap shows its own flesh material.
			mesh_node.material_override = null
		# 2. The piece that came off is the same original surface, not a duplicate stump.
		_spawn_cut_debris(gone_arrays, gone_cap, mesh_node, plane_world.normal, gone_materials, _player if cut_rig == _rig else _npc_body)
		any = true
		_record_actor_cut50(cut_rig)
	if any and preserve_head31:
		# Prepared appearance hair/brows are rigid children of the head attachment.
		# Move those exact nodes with the real removed mesh, not a replacement head.
		for anchor: Node in cut_rig.find_children("*", "BoneAttachment3D", true, false):
			if str(anchor.bone_name) not in ["head", "socket_head"]: continue
			for child: Node in anchor.get_children():
				if not child is Node3D or child is CollisionObject3D or child is CollisionShape3D: continue
				if not child.find_children("*", "CollisionObject3D", true, false).is_empty(): continue
				var visuals: Array[Node] = child.find_children("*", "MeshInstance3D", true, false)
				if child is MeshInstance3D: visuals.append(child)
				var rigid_visuals := not visuals.is_empty()
				for visual: Node in visuals:
					if visual.skin != null: rigid_visuals = false
				if rigid_visuals: detached_whole31.append(child)
		for whole: Node3D in detached_whole31:
			var nearest: RigidBody3D
			var distance := INF
			var centre: Vector3 = whole.to_global(whole.mesh.get_aabb().get_center()) if whole is MeshInstance3D else whole.global_position
			for i: int in range(debris_start31, _npc_debris.size()):
				var piece := _npc_debris[i].get("node") as RigidBody3D
				if not is_instance_valid(piece): continue
				var d: float = piece.global_position.distance_squared_to(centre)
				if d < distance:
					distance = d
					nearest = piece
			if is_instance_valid(nearest):
				whole.reparent(nearest, true)
	if any and cut_rig == _rig:
		var hero_appearance31 := _world.get_node_or_null("CastleArmorEquipment") if is_instance_valid(_world) else null
		if hero_appearance31 != null and hero_appearance31.has_method("after_cut31") and _npc_debris.size() > debris_start31:
			hero_appearance31.after_cut31({"plane":plane_world,"keep":keep_point_world,"scope":part_key,"head_gone":preserve_head31}, _npc_debris[debris_start31].get("node"))
	if not any:
		print("DSH_GORE_CUT refused=nothing_crossed")
	return any

## The cut-away piece: the very same surface, no skeleton, falling under gravity.
func _spawn_cut_debris(gone_arrays: Array, gone_cap: Array, from: MeshInstance3D, push: Vector3, outer_materials: Array[Material] = [], owner_body: PhysicsBody3D = null) -> void:
	if gone_arrays.is_empty(): return
	var debris_mesh := ArrayMesh.new()
	for surface_index: int in gone_arrays.size():
		debris_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, gone_arrays[surface_index])
		if surface_index < outer_materials.size() and outer_materials[surface_index] != null:
			debris_mesh.surface_set_material(surface_index, outer_materials[surface_index])
	if not gone_cap.is_empty():
		debris_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, gone_cap)
		debris_mesh.surface_set_material(debris_mesh.get_surface_count() - 1, _flesh())
	if debris_mesh.get_surface_count() == 0: return
	var bounds := debris_mesh.get_aabb()
	if bounds.size.length_squared() < 1.0e-8: return
	var body := RigidBody3D.new()
	body.name = "KnightCutLimb"
	body.mass = 0.08
	# Lightweight remains yield to real foot contacts without excessive friction.
	var contact_material := PhysicsMaterial.new()
	contact_material.friction = 0.25
	contact_material.bounce = 0.0
	body.physics_material_override = contact_material
	body.continuous_cd = true
	# The player masks layer 1. Both player and world can now push the cut limb.
	body.collision_layer = 1
	body.collision_mask = 3
	var scale_value := from.global_basis.get_scale()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(0.045, bounds.size.x * scale_value.x),
		maxf(0.045, bounds.size.y * scale_value.y),
		maxf(0.045, bounds.size.z * scale_value.z))
	shape.shape = box
	body.add_child(shape)
	var piece := MeshInstance3D.new()
	piece.name = "KnightCutPiece"
	piece.mesh = debris_mesh
	body.add_child(piece)
	piece.scale = scale_value
	piece.position = -bounds.get_center() * scale_value
	_world.add_child(body)
	# Put the rigid body's centre at the removed mesh's centre of mass. The mesh
	# still lands exactly where the skinned surface used to be before the cut.
	body.global_transform = Transform3D(from.global_basis.orthonormalized(),
		from.to_global(bounds.get_center()))
	var owner: PhysicsBody3D = owner_body if is_instance_valid(owner_body) else _npc_body
	if is_instance_valid(owner): body.add_collision_exception_with(owner)
	body.linear_velocity = push.normalized() * randf_range(0.6, 1.8) + Vector3.UP * randf_range(0.2, 0.8)
	body.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	_npc_debris.append({
		"node": body,
		"visual": piece,
		"age": 0.0,
	})
	if owner_body == _player and not gone_cap.is_empty(): preload("res://scripts/combat/blood_flow32.gd").register_player_cap(self, from, piece, gone_cap)

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
		if node is RigidBody3D:
			entry["age"] = float(entry.get("age", 0.0)) + delta
			_npc_debris[index] = entry
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
	if not at.is_finite(): return false
	if is_instance_valid(_npc_rig): return true
	if is_instance_valid(_npc_corpse31): _npc_corpse31.queue_free()
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
	body.name = "EnemyKnight"
	body.collision_layer = 1
	body.collision_mask = 1
	body.floor_snap_length = 0.25
	body.set_meta("enemy_knight", true)
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
	# A newly created actor cannot inherit wounds, missing limbs or armour
	# from an older generation. Its mesh starts whole; equipment is explicit.
	_npc_severed.clear()
	_npc_head_mesh_cut31 = false
	_npc_mesh_cut_parts39.clear()
	_npc_part_hp.clear()
	_npc_dead = false
	_npc_hp = NPC_MAX_HP57
	_npc_engaged = false
	_npc_state = "hunt"
	_npc_timer = 0.0
	_enemy_seen_since_ms = 0
	_enemy_last_seen = at
	_enemy_lost_since_ms = 0
	_enemy_spotted_once = false
	_enemy_combo_left = 0
	_enemy_clashes = 0
	_enemy_last_clash_push = 0.0
	_enemy_clash_lock_until_ms = 0
	_enemy_evade_cooldown_ms = 0
	_enemy_evades = 0
	_enemy_armor_tier = "medium"
	_npc_route_dir50 = Vector3.ZERO
	_npc_route_request53 = Vector3.ZERO
	_npc_replan_ms50 = 0
	_npc_omega43 = Vector3.ZERO
	_npc_threat_since43 = 0
	_npc_observations53.clear()
	_npc_observed53.clear()
	_npc_last_tip53 = Vector3.INF
	_npc_threat53 = false
	_npc_counter_until53 = 0
	_npc_spacing_retreat53 = false
	_npc_orbit_side53 = 1.0
	_npc_orbit_until53 = 0
	_npc_disarmed = false
	_npc_knock_pose_active27 = false
	_npc_knock_roll_speed27 = 0.0
	_npc_knocked_until_ms31 = 0
	_npc_bleed_until_ms = 0
	_npc_bleed_at = Vector3.ZERO
	_npc_bleed_local = Vector3.ZERO
	_npc_bleed_bone27 = -1
	_npc_bleed_bone_local27 = Vector3.ZERO
	_npc_bleed_accum = 0.0
	_npc_armor_loadout31.clear()
	_npc_corpse31 = null
	_npc_corpse_pending31 = false
	_npc_dropped_sword31 = null
	_npc_disarmed_at_ms = 0
	if is_instance_valid(_npc_armor_visual31): _npc_armor_visual31.queue_free()
	_npc_armor_visual31 = null
	_npc_body = body
	_npc_motion = motion
	_npc_hull31 = hull
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
	_ensure_player_hitboxes50()
	if not is_instance_valid(_npc_rig):
		# Castle setup moves the player into the courtyard after this host installs.
		# Spawning beforehand leaves the opponent behind the castle at the old
		# player position, too far away to take part in the fight.
		if not bool(_world.get("preview_ready")): return
		if bool(_world.get("castle_map")) and not bool(_world.get("_catapult_at_castle")): return
		# The model loads asynchronously, so he is picked up as soon as it is ready.
		_npc_bind_timer += delta
		if _npc_bind_timer >= 0.5 and _npc_bind_attempts < 20:
			_npc_bind_timer = 0.0
			var knight_spawn: Vector3 = _player.global_position + _player._visual.global_basis.z * 4.6
			if bool(_world.get("castle_map")):
				# The knight guards the gate; main.gd places the player ten metres in
				# front of the same threshold.
				var gate_target: Vector3 = _world.get("_castle_enemy_spawn_target")
				if gate_target.is_finite() and not gate_target.is_zero_approx():
					knight_spawn = gate_target
				else:
					var castle_target: Vector3 = _world.get("_castle_spawn_target")
					if castle_target.is_finite() and not castle_target.is_zero_approx():
						knight_spawn = castle_target + _player._visual.global_basis.x * 4.6 + _player._visual.global_basis.z * 4.0
			var grounded_spawn := _grounded(knight_spawn)
			if not grounded_spawn.is_finite(): return
			_npc_bind_attempts += 1
			if _spawn_resident_knight(grounded_spawn) \
				and is_instance_valid(_duelist):
				_duelist.visible = false
				_duelist_hull.set_meta("sword_duelist", false)
		return
	if _npc_dead:
		# Native RigidBody3D owns motion after death. Do not run the walking
		# capsule, gait, or the old scripted tilt against the physical corpse.
		_update_npc_bleed(delta)
		_apply_npc_severed()
		return
	if not _npc_dead and (now_ms() < _npc_knocked_until_ms31 or _npc_knock_pose_active27):
		# A real capsule slides with the impact while the torso and collider roll
		# onto the ground. Movement and attacks pause until the fighter gets up.
		var vertical := _npc_body.velocity.y
		_npc_body.velocity = _npc_hit_push31
		_npc_body.velocity.y = -0.5 if _npc_body.is_on_floor() else vertical - 9.8 * delta
		_npc_body.velocity = _embedded29.constrain_target_velocity(self, _npc_body.velocity)
		_npc_body.move_and_slide()
		_npc_hit_push31 = _npc_hit_push31.move_toward(Vector3.ZERO, 2.6 * delta)
		_npc_advance_knock_pose27(delta, now_ms() < _npc_knocked_until_ms31)
		_update_npc_bleed(delta)
		if _npc_gait != null: _npc_gait.update_pose(delta, Vector3.ZERO, _npc_body.is_on_floor())
		_apply_npc_severed()
		if is_instance_valid(_npc_sword):
			var fallen_fist: Vector3 = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(_npc_hand).origin
			_npc_sword.global_transform = _place_basis(fallen_fist + _npc_dir * GRIP_CENTER_OFFSET, _npc_dir)
		return
	if _npc_knocked_until_ms31 > 0 and not _npc_dead:
		_npc_knocked_until_ms31 = 0
		_npc_state = "recover"
		_npc_timer = 0.0
	if is_instance_valid(_npc_hull31) and not _npc_dead:
		_npc_hull31.rotation.x = lerpf(_npc_hull31.rotation.x, 0.0, clampf(7.0 * delta, 0.0, 1.0))
		_npc_hull31.position = _npc_hull31.position.lerp(Vector3(0.0, NPC_HEIGHT * 0.5, 0.0), clampf(7.0 * delta, 0.0, 1.0))
	if not is_instance_valid(_npc_sword):
		# An intact hand can recover the actual dropped sword; a severed hand or
		# a sword already taken by the player cannot conjure a replacement.
		_npc_engaged = false
		_npc_state = "retreat"
		var move_disarmed := Vector3.ZERO
		if not bool(_world.get("preview_dead")) and now_ms() - _npc_disarmed_at_ms >= 450 and is_instance_valid(_player):
			var dropped: RigidBody3D = _npc_dropped_sword31
			var can_reclaim := is_instance_valid(dropped) and _ground_swords.has(dropped) \
				and not _npc_severed.has("upperarm_r") and not _npc_severed.has("forearm_r") and not _npc_severed.has("hand_r")
			if can_reclaim:
				var to_sword := dropped.global_position - _npc_body.global_position
				var height := absf(to_sword.y)
				to_sword.y = 0.0
				if to_sword.length() < 16.0 and height < 1.25:
					_npc_state = "retrieve"
					if to_sword.length() <= 1.15 and dropped.linear_velocity.length() < 1.7:
						if _npc_reclaim_sword59(dropped): return
					elif to_sword.length_squared() > 1.0e-6:
						move_disarmed = _npc_navigation50(to_sword.normalized()) * 2.1 * _npc_speed_scale()
			if _npc_state != "retrieve":
				_npc_state = "retreat"
				var away := _npc_body.global_position - _player.global_position
				away.y = 0.0
				if away.length_squared() > 1.0e-6 and away.length() < 11.5:
					move_disarmed = _npc_navigation50(away.normalized()) * 2.8 * _npc_speed_scale()
			var face := _player.global_position - _npc_body.global_position
			if _npc_state == "retrieve" and is_instance_valid(dropped): face = dropped.global_position - _npc_body.global_position
			face.y = 0.0
			if face.length_squared() > 1.0e-6:
				_npc_body.rotation.y = rotate_toward(_npc_body.rotation.y, atan2(face.x, face.z) + PI, 4.2 * delta)
		var retreat_vertical := _npc_body.velocity.y
		_npc_body.velocity = move_disarmed + _npc_hit_push31
		_npc_hit_push31 = _npc_hit_push31.move_toward(Vector3.ZERO, 2.6 * delta)
		if _npc_body.is_on_floor():
			_npc_body.velocity.y = -0.5
			if (_npc_leg_lost("l") != _npc_leg_lost("r")) and move_disarmed.length() > 0.05 \
					and _npc_hop_wait <= 0.0:
				_npc_body.velocity.y = 2.4
				_npc_hop_wait = 0.72
		else:
			_npc_body.velocity.y = retreat_vertical - 9.8 * delta
		_npc_hop_wait = maxf(0.0, _npc_hop_wait - delta)
		_npc_body.velocity = _embedded29.constrain_target_velocity(self, _npc_body.velocity)
		_npc_body.move_and_slide()
		_update_npc_bleed(delta)
		if _npc_gait != null:
			_npc_gait.update_pose(delta, _npc_body.velocity, _npc_body.is_on_floor())
		_apply_npc_severed()
		if not _npc_dead:
			_npc_motion.rotation.x = lerpf(_npc_motion.rotation.x,
				0.42 if now_ms() < maxi(_npc_pain_until_ms, _npc_flinch_until_ms31) else 0.16, clampf(5.0 * delta, 0.0, 1.0))
		return
	_npc_sword.visible = _npc_hp > 0.0
	var to_player := _player.global_position - _npc_body.global_position
	to_player.y = 0.0
	var distance := to_player.length()
	# He faces the player (or the last place he saw him while searching).
	var face_at: Vector3 = _player.global_position
	if _npc_state == "search" and _enemy_last_seen.is_finite():
		face_at = _enemy_last_seen
	var face_delta := face_at - _npc_body.global_position
	face_delta.y = 0.0
	if face_delta.length_squared() > 1.0e-6:
		var want_yaw := atan2(face_delta.x, face_delta.z)
		_npc_body.rotation.y = rotate_toward(_npc_body.rotation.y, want_yaw + PI, 4.2 * delta)
	if bool(_world.get("preview_dead")):
		_npc_engaged = false
		_npc_state = "wait"
	elif not _npc_engaged:
		# A real enemy does not wait to be hit: he watches his front arc, confirms
		# the player through a real line of sight for 180 ms, then hunts.
		_enemy_acquire(distance, to_player)
	else:
		_enemy_update_memory()
	_npc_timer += delta
	_npc_observe53(delta)
	_update_npc_bleed(delta)
	var want := _npc_high_guard()
	var move := Vector3.ZERO
	var strike_sample := false
	var speed_scale := _npc_speed_scale()
	if not _npc_engaged and _npc_state != "wait":
		move = _enemy_search_move() * speed_scale
	if _npc_engaged:
		# A lost player turns the duel into a search for the last seen position; the
		# knight does not keep swinging at a memory through a wall.
		if _enemy_lost_since_ms > 0 and now_ms() - _enemy_lost_since_ms > ENEMY_LOST_SIGHT_MS:
			_npc_state = "search"
		# Walk in, wind up, cut - the walk animation plays because his own body is
		# actually moving, and the gait samples the horizontal velocity from it.
		match _npc_state:
			"search":
				move = _enemy_search_move() * speed_scale
				want = _npc_guard_direction()
				if _npc_visible_player43() and distance <= ENEMY_SIGHT_RANGE:
					_enemy_seen_since_ms = now_ms()
					_enemy_lost_since_ms = 0
					_npc_state = "approach"
					_npc_timer = 0.0
			"approach":
				move = _npc_footwork53(to_player, distance, false) * speed_scale
				if _npc_should_guard(distance):
					_npc_state = "guard"
					_npc_timer = 0.0
					_npc_guard_entries += 1
					_npc_guard_cooldown_ms = now_ms() + 650
				# A windup is allowed only once the real arm and blade can reach.
				# This is positioning, never a damage fallback. A counter after a
				# parry starts 180 ms earlier, exactly like the residents.
				elif _npc_timer > _enemy_attack_delay() and distance >= 1.20 and distance <= _npc_reach50() and _npc_visible_player43():
					_npc_begin_attack53(distance)
			"windup":
				# Track the observed opponent early, then commit the swing. No late homing.
				if _npc_timer < 0.32: _npc_update_aim53()
				want = _npc_windup_direction()
				# A small planted retreat loads the legs before the lunge. The capsule
				# moves normally; the visual never jumps ahead of its collision body.
				if distance < 1.18: move = _npc_navigation50(-to_player.normalized()) * 1.7 * speed_scale
				elif distance > 1.45 and _npc_timer < 0.32: move = _npc_navigation50(to_player.normalized()) * 0.85 * speed_scale
				# He reads the real incoming steel and may abort the windup into a
				# sidestep. This is the same buffered 180 ms observation, not input
				# reading; it has a cooldown and a visible 260 ms evade.
				if _npc_timer > 0.24 and _npc_timer < 0.55:
					_enemy_try_evade(distance)
				if _npc_timer > 0.55:
					_npc_state = "strike"
					_npc_timer = 0.0
					_npc_swings += 1
					_npc_attack_counts[_npc_attack_kind] = int(_npc_attack_counts[_npc_attack_kind]) + 1
					_npc_blade_prev = PackedVector3Array()
					_npc_strike_had_hit = false
			"strike":
				var impulse: float = 1.75 if _npc_attack_kind == "thrust" else 1.52
				if distance > 1.10:
					move = _npc_navigation50(to_player.normalized()) * impulse * speed_scale
				want = _npc_cut_direction()
				strike_sample = true
				if _npc_timer > _npc_strike_duration():
					_npc_follow_dir = _npc_dir
					_npc_state = "follow"
					_npc_timer = 0.0
					# A landed cut earns pressure: every other clean hit can chain a
					# second beat after a short, visible recovery.
					if _npc_strike_had_hit and _enemy_combo_left <= 0 and _npc_hits % 2 == 1:
						_enemy_combo_left = 1
			"follow":
				want = _npc_follow_dir
				if distance > 1.10:
					move = _npc_navigation50(to_player.normalized()) * 0.45 * speed_scale
				if _npc_timer > 0.19:
					_npc_state = "recover"
					_npc_timer = 0.0
			"evade":
				# A real sidestep away from the player's blade, then guard and counter.
				var evade_forward := to_player.normalized()
				var evade_side := evade_forward.cross(Vector3.UP) * _npc_orbit_side53
				var evade_dir := (evade_side - evade_forward * 0.55).normalized()
				move = _npc_navigation50(evade_dir) * 3.0 * speed_scale
				want = _npc_guard_direction()
				if _npc_timer > 0.26:
					_npc_state = "guard"
					_npc_timer = 0.0
					_npc_guard_entries += 1
					_npc_guard_cooldown_ms = now_ms() + 650
			"guard":
				want = _npc_guard_direction()
				move = _npc_footwork53(to_player, distance, true) * speed_scale
				if _npc_timer > 0.24 and not _npc_threat53 and distance >= 1.20 and distance <= _npc_reach50() and _npc_visible_player43():
					_npc_begin_attack53(distance)
				elif _npc_timer > 0.72:
					_npc_state = "recover"
					_npc_timer = 0.0
			_:
				# A clean hit chains one more beat before the normal recovery. The
				# combo still needs a reachable, visible target and real blade contact.
				if _enemy_combo_left > 0 and now_ms() >= _enemy_clash_lock_until_ms \
						and _npc_timer > ENEMY_COMBO_GAP and distance <= _npc_reach50() + 0.15 \
						and _npc_visible_player43():
					_enemy_combo_left -= 1
					print("DSH_ENEMY_KNIGHT_COMBO distance=", distance)
					_npc_begin_attack53(distance)
				else:
					move = _npc_footwork53(to_player, distance, true) * speed_scale * 0.7
					if _npc_timer > 0.22 and _npc_should_guard(distance):
						_npc_state = "guard"
						_npc_timer = 0.0
						_npc_guard_entries += 1
						_npc_guard_cooldown_ms = now_ms() + 650
					elif _npc_timer > _enemy_recover_delay():
						_npc_state = "approach"
						_npc_timer = 0.0
		if _npc_hp <= 0.0:
			_npc_engaged = false
			_npc_state = "wait"
	if now_ms() < _npc_pain_until_ms and not _npc_dead:
		# The first moment of a deep wound interrupts the attack and folds him over.
		move *= 0.12
		strike_sample = false
		if _npc_state in ["windup", "strike", "follow"]: _npc_stop_attack43()
		_npc_motion.rotation.x = lerpf(_npc_motion.rotation.x, 0.38, clampf(8.0 * delta, 0.0, 1.0))
	elif now_ms() < _npc_flinch_until_ms31 and not _npc_dead:
		# Preserve the short visible reaction without cancelling a committed attack.
		_npc_motion.rotation.x = lerpf(_npc_motion.rotation.x, 0.38, clampf(8.0 * delta, 0.0, 1.0))
	elif not _npc_dead:
		_npc_motion.rotation.x = lerpf(_npc_motion.rotation.x, 0.0, clampf(4.0 * delta, 0.0, 1.0))
	# Gravity keeps him planted on the ground; without it he drifts through the air.
	var vertical_speed := _npc_body.velocity.y
	_npc_body.velocity = move + _npc_hit_push31
	_npc_hit_push31 = _npc_hit_push31.move_toward(Vector3.ZERO, 2.6 * delta)
	if _npc_body.is_on_floor():
		_npc_body.velocity.y = -0.5
		if (_npc_leg_lost("l") != _npc_leg_lost("r")) and move.length() > 0.05 \
				and _npc_hop_wait <= 0.0 and now_ms() >= _npc_pain_until_ms:
			_npc_body.velocity.y = 2.4
			_npc_hop_wait = 0.72
	else:
		_npc_body.velocity.y = vertical_speed - 9.8 * delta
	_npc_hop_wait = maxf(0.0, _npc_hop_wait - delta)
	_npc_body.velocity = _embedded29.constrain_target_velocity(self, _npc_body.velocity)
	_npc_body.move_and_slide()
	# The canonical walk gait plays FIRST, so his legs really step while he moves;
	# the sword arm is then written over it, exactly like the player's own arm.
	if _npc_gait != null:
		_npc_gait.update_pose(delta, _npc_body.velocity, _npc_body.is_on_floor())
	_npc_apply_combat_pose()
	# Hidden limbs, re-cut every frame behind the gait.
	_apply_npc_severed()
	_npc_drive43(want, delta)
	if not _npc_severed.has("upperarm_r") and not _npc_severed.has("forearm_r") and not _npc_severed.has("hand_r"):
		_npc_pose_arm()
	var local := _npc_dir
	# The sword is held in the resident's own right hand, in world space.
	var fist: Vector3 = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(_npc_hand).origin
	if _npc_hp > 0.0:
		_npc_sword.global_transform = _npc_blade_transform50(fist + local * GRIP_CENTER_OFFSET, delta)
	# Contact is sampled only AFTER the same frame wrote the visible gait, arm and steel.
	if strike_sample and _npc_hp > 0.0:
		_npc_resolve_strike(delta)

func _npc_high_guard() -> Vector3:
	return (Vector3.UP * 0.80 + _npc_body.global_basis.z * 0.45).normalized()

func _npc_visible_player43() -> bool:
	var start := _npc_body.global_position + Vector3.UP * 1.15
	var finish := _player.global_position + Vector3.UP * 1.05
	var query := PhysicsRayQueryParameters3D.create(start, finish, 3)
	query.exclude = [_npc_body.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == _player

func _npc_should_guard(distance: float) -> bool:
	return distance < 2.7 and _npc_threat53 and now_ms() >= _npc_guard_cooldown_ms

## ------------------------------------------------------------ enemy knight
## Perception: a frontal cone, a real ray and a 180 ms confirmation. Being very
## close bypasses the cone (he hears the man), but a wall still blocks sight.
func _enemy_acquire(distance: float, to_player: Vector3) -> void:
	if distance <= 0.01 or not is_instance_valid(_player): return
	var visible := _npc_visible_player43()
	var forward := -_npc_body.global_basis.z
	var facing := forward.dot(to_player.normalized()) if to_player.length_squared() > 1.0e-6 else -1.0
	var in_cone := distance <= ENEMY_SIGHT_RANGE and (facing >= ENEMY_SIGHT_DOT or distance < 1.6)
	if visible and in_cone:
		var now := now_ms()
		if _enemy_seen_since_ms == 0:
			_enemy_seen_since_ms = now
			print("DSH_ENEMY_KNIGHT_SPOTS distance=", distance, " facing=", facing)
		_enemy_last_seen = _player.global_position
		if now - _enemy_seen_since_ms >= ENEMY_REACTION_MS:
			_npc_engaged = true
			_enemy_spotted_once = true
			_enemy_lost_since_ms = 0
			_npc_state = "approach"
			_npc_timer = 0.0
			print("DSH_ENEMY_KNIGHT_ALERT distance=", distance,
				" reaction_ms=", now - _enemy_seen_since_ms)
	else:
		_enemy_seen_since_ms = 0

## Once engaged, keeps the last position at which the player was actually seen.
## Losing the line of sight starts a search instead of tracking through geometry.
func _enemy_update_memory() -> void:
	if not is_instance_valid(_player): return
	# At sword distance a man is not lost because a limb hitbox crossed the ray;
	# the line-of-sight test matters for the approach/search, not for two men in
	# contact. This keeps the search from cancelling a live exchange.
	var close := _npc_body.global_position.distance_to(_player.global_position) < 2.2
	if _npc_visible_player43() or close:
		_enemy_last_seen = _player.global_position
		_enemy_lost_since_ms = 0
	elif _enemy_lost_since_ms == 0:
		_enemy_lost_since_ms = now_ms()
		print("DSH_ENEMY_KNIGHT_LOST_AT ", _enemy_last_seen)

## Walks to the last seen position using the population's own navigation/detour.
func _enemy_search_move() -> Vector3:
	if not _enemy_spotted_once or not _enemy_last_seen.is_finite(): return Vector3.ZERO
	var target := _enemy_last_seen - _npc_body.global_position
	target.y = 0.0
	if target.length() <= 1.2: return Vector3.ZERO
	return _npc_navigation50(target.normalized()) * 2.4

func _enemy_is_enraged() -> bool:
	return _npc_hp > 0.0 and _npc_hp <= NPC_MAX_HP57 * ENEMY_ENRAGE_FRACTION

func _enemy_attack_delay() -> float:
	if now_ms() < _npc_counter_until53: return 0.18
	if _enemy_combo_left > 0: return 0.12
	return 0.20 if _enemy_is_enraged() else 0.36

func _enemy_recover_delay() -> float:
	return 0.28 if _enemy_is_enraged() else 0.46

## Reading the visible incoming blade: abort a windup into a real sidestep. The
## observation is already buffered 180 ms; the cooldown keeps it from becoming a
## perfect dodge and the evade itself is a 260 ms, collider-driven move.
func _enemy_try_evade(distance: float) -> bool:
	if not _npc_threat53 or distance > 2.3: return false
	if now_ms() < _enemy_evade_cooldown_ms: return false
	if _npc_attack_cursor % 2 != 0: return false
	_enemy_evade_cooldown_ms = now_ms() + 1600
	_enemy_evades += 1
	_npc_state = "evade"
	_npc_timer = 0.0
	_npc_strike_had_hit = true
	_npc_blade_prev = PackedVector3Array()
	print("DSH_ENEMY_KNIGHT_EVADE distance=", distance)
	return true

func _npc_stop_attack43() -> void:
	_npc_state = "recover"
	_npc_timer = 0.0
	_npc_strike_had_hit = true
	_npc_omega43 = Vector3.ZERO
	_npc_blade_prev = PackedVector3Array()

func _npc_drive43(target: Vector3, delta: float) -> void:
	# Same bounded torque and stopping-distance law as the player's one-hand sword.
	var axis := _npc_dir.cross(target)
	var angle := _npc_dir.angle_to(target)
	var acceleration := 40.0
	var aim_speed := minf(9.0, minf(sqrt(2.0 * acceleration * angle) * 0.72, angle * 14.0))
	var velocity := axis.normalized() * aim_speed if axis.length_squared() > 0.00000001 else Vector3.ZERO
	var torque := ((velocity - _npc_omega43) / maxf(delta, 0.001)).limit_length(acceleration)
	_npc_omega43 = (_npc_omega43 + torque * delta).limit_length(9.0)
	if _npc_omega43.length() > 0.000001:
		_npc_dir = (Quaternion(_npc_omega43.normalized(), _npc_omega43.length() * delta) * _npc_dir).normalized()

func _npc_guard_direction() -> Vector3:
	if _npc_observed53.is_empty() or not is_instance_valid(_npc_rig): return _npc_high_guard()
	var shoulder: Vector3 = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(_npc_upper).origin
	var steel: Vector3 = _npc_observed53.tip
	var toward := steel - shoulder
	return (toward.normalized() + Vector3.UP * 0.18).normalized() if toward.length_squared() > 0.01 else _npc_high_guard()

var _npc_mix_cursor27 := 0

func _npc_choose_attack(distance: float) -> String:
	var pick := _npc_attack_opening27(distance)
	if distance > 1.42 and _npc_attack_cursor % 4 == 3:
		return "thrust"
	if _enemy_is_enraged() and distance <= 1.55:
		return "overhead" if _npc_attack_cursor % 2 == 0 else "left"
	# A low passive guard used to replace every choice with overhead, even after
	# repeated misses. Keep the observed opening, but vary the next committed cut.
	if pick == _npc_attack_kind:
		var alternatives := ["left", "right", "overhead", "rising"]
		for offset in alternatives.size():
			var candidate: String = alternatives[(_npc_mix_cursor27 + offset) % alternatives.size()]
			if candidate == pick or (candidate == "rising" and distance > 1.48): continue
			_npc_mix_cursor27 = (_npc_mix_cursor27 + offset + 1) % alternatives.size()
			return candidate
	return pick

func _npc_attack_opening27(distance: float) -> String:
	var choices := ["left", "right", "overhead", "rising"]
	var pick: String = choices[_npc_attack_cursor % choices.size()]
	_npc_attack_cursor += 1
	# Only a settled, previously visible weapon can expose a useful opening.
	# This snapshot passed the same 180ms observation buffer as aim and defense.
	var seen := _npc_observed53
	var age := now_ms() - int(seen.get("at", -10000))
	var valid := not seen.is_empty() and bool(seen.get("visible", false)) \
		and bool(seen.get("steel", false)) and age >= 180 and age <= 500
	if valid and is_instance_valid(_npc_body):
		var position: Vector3 = seen.get("position", Vector3.INF)
		var tip: Vector3 = seen.get("tip", Vector3.INF)
		if position.is_finite() and tip.is_finite():
			var forward := position - _npc_body.global_position
			forward.y = 0.0
			if forward.length_squared() > 0.01:
				forward = forward.normalized()
				var across := forward.cross(Vector3.UP).normalized()
				var offset := tip - position
				if int(seen.get("steady_ms", 0)) >= 160 and float(seen.get("speed", INF)) <= 0.65:
					# A rising cut enters from below; preserve its existing close-range limit.
					if offset.y >= 1.70 and distance <= 1.48: return "rising"
					if offset.y <= 0.80: return "overhead"
					var occupied_side := offset.dot(across)
					if absf(occupied_side) >= 0.45:
						# left winds up at -across, right at +across: enter opposite the steel.
						return "left" if occupied_side > 0.0 else "right"
				# Retain the old side context, using the observed position rather than live input.
				var player_side := _npc_body.global_basis.x.dot(forward)
				if absf(player_side) > 0.32 and pick in ["overhead", "rising"]:
					return "left" if player_side > 0.0 else "right"
	if distance > 1.48 and pick == "rising": return "overhead"
	return pick

func _npc_strike_duration() -> float:
	return 0.38 if _npc_attack_kind == "thrust" else 0.40

## A loaded beat, a fast middle third, then a slower follow-through. This changes
## the actual displayed blade speed sampled by the existing physics sweep.
func _npc_attack_ease(phase: float) -> float:
	var t := clampf(phase, 0.0, 1.0)
	if t < 0.22: return t * (0.08 / 0.22)
	if t < 0.67: return 0.08 + (t - 0.22) * (0.78 / 0.45)
	return 0.86 + (t - 0.67) * (0.14 / 0.33)

func _npc_apply_combat_pose() -> void:
	if not is_instance_valid(_npc_rig): return
	var chest := _npc_rig.find_bone("chest")
	var left_leg := _npc_rig.find_bone("thigh_l")
	var right_leg := _npc_rig.find_bone("thigh_r")
	if chest < 0 or left_leg < 0 or right_leg < 0: return
	var side := -1.0 if _npc_attack_kind == "left" else (1.0 if _npc_attack_kind == "right" else 0.0)
	if _npc_attack_kind == "overhead": side = -0.30
	if _npc_attack_kind == "rising": side = 0.30
	var coil := 0.0
	var turn := 0.0
	var lean := 0.0
	match _npc_state:
		"windup":
			coil = smoothstep(0.0, 0.55, _npc_timer)
			turn = side * 0.52 * coil
			lean = (-0.16 if _npc_attack_kind != "rising" else 0.12) * coil
		"strike":
			var beat := _npc_attack_ease(_npc_timer / _npc_strike_duration())
			coil = 1.0 - beat * 0.45
			turn = lerpf(side * 0.52, -side * 0.28, beat)
			lean = lerpf(-0.16, 0.25, beat)
		"follow":
			coil = 0.55
			turn = -side * 0.28
			lean = 0.25
		"recover":
			var release := 1.0 - smoothstep(0.0, 0.70, _npc_timer)
			coil = 0.55 * release
			turn = -side * 0.28 * release
			lean = 0.25 * release
	if coil <= 0.0 and absf(turn) < 0.001 and absf(lean) < 0.001: return
	var chest_pose := _npc_rig.get_bone_pose_rotation(chest)
	_npc_rig.set_bone_pose_rotation(chest, (chest_pose * Quaternion(Vector3.UP, turn) * Quaternion(Vector3.RIGHT, lean)).normalized())
	# Opposed thigh pitches turn the neutral gait into a braced two-foot stance.
	for bone: int in [left_leg, right_leg]:
		var sign := 1.0 if bone == left_leg else -1.0
		var leg_pose := _npc_rig.get_bone_pose_rotation(bone)
		_npc_rig.set_bone_pose_rotation(bone, (leg_pose * Quaternion(Vector3.RIGHT, sign * 0.20 * coil)).normalized())

func _npc_windup_direction() -> Vector3:
	var front := _npc_aim43
	var side := front.cross(Vector3.UP).normalized()
	match _npc_attack_kind:
		"left": return (front - side * 0.8 + Vector3.UP * 0.18).normalized()
		"right": return (front + side * 0.8 + Vector3.UP * 0.18).normalized()
		"overhead": return (front * 0.12 + Vector3.UP * 1.4).normalized()
		"rising": return (front - Vector3.UP * 0.65).normalized()
		_: return (front + Vector3.UP * 0.08).normalized()

func _npc_cut_direction() -> Vector3:
	# Aim the visible arm-and-steel chain from its real shoulder. A vector from
	# the actor's feet to chest points the blade too high by roughly a metre.
	var upper := _npc_rig.find_bone("upperarm_r")
	if upper < 0: return _npc_high_guard()
	var shoulder: Vector3 = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(upper).origin
	var toward: Vector3 = _npc_aim43
	if toward.length_squared() < 1.0e-6: return _npc_high_guard()
	var forward := toward.normalized()
	var across := forward.cross(Vector3.UP).normalized()
	var phase := _npc_attack_ease(_npc_timer / _npc_strike_duration())
	match _npc_attack_kind:
		"left": return (forward + across * lerpf(-1.05, 0.90, phase)).normalized()
		"right": return (forward + across * lerpf(1.05, -0.90, phase)).normalized()
		"overhead": return (forward + Vector3.UP * lerpf(1.14, -0.82, phase)).normalized()
		"rising": return (forward + Vector3.UP * lerpf(-0.88, 1.02, phase)).normalized()
		_: return (forward + Vector3.UP * 0.02).normalized()

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
	var reach := 0.94
	if _npc_state == "windup": reach = 0.97 if _npc_attack_kind == "overhead" else 0.72
	if _npc_state == "strike":
		var beat := _npc_attack_ease(_npc_timer / _npc_strike_duration())
		reach = lerpf(0.97 if _npc_attack_kind == "overhead" else 0.72, 0.99, beat)
	if _npc_state == "follow": reach = 0.99
	var target := joint + dir_rig * (l1 + l2) * reach
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
	for i: int in SWEEP_SEGMENTS + 1:
		points.append(origin + direction * (0.06 + float(WEAPONS["sword"]["length"]) * float(i) / float(SWEEP_SEGMENTS)))
	return points

## Impact energy comes from the moving, displayed steel at the contact sample.
## Phase records how much of the loaded swing has been released; it cannot make
## a motionless blade powerful. A future spear-wielding NPC can use this same
## contact law after it has its own visible spear and sweep.
func _npc_contact_damage31(blade_speed: float, phase: float, part: String, pointed: bool, spear: bool = false, kind50: String = "slice") -> float:
	# Sword mass=1 and one-hand grip=1: same speed-squared law as player.
	# Preparation is measured angular travel, never an elapsed attack timer bonus.
	var angle := clampf(_npc_swing_start43.angle_to(_npc_dir), 0.0, SWING_ANGLE_MAX)
	var seconds50 := maxf(0.06, float(now_ms() - _npc_swing_started_ms50) * 0.001) if _npc_swing_started_ms50 > 0 else maxf(0.06, _npc_timer)
	var rate := angle / seconds50
	var decisive := clampf(rate / WINDUP_RATE_IDEAL, WINDUP_DECISION_FLOOR, 1.0)
	var prepared := clampf(SWING_STRENGTH_MIN + angle * SWING_STRENGTH_GAIN * decisive, SWING_STRENGTH_MIN, SWING_STRENGTH_MAX)
	return clampf(2.5 * pow(blade_speed * 0.6, 2.0) * prepared * float(WEAPONS["sword"].get(kind50, 1.0)), 0.0, 160.0)


## His cut: our blade stops it, otherwise it reaches the body.
func _npc_resolve_strike(delta: float) -> void:
	if _npc_strike_had_hit or delta <= 0.0: return
	var points := _npc_blade_points()
	if _npc_blade_prev.size() != points.size():
		_npc_blade_prev = points
		return
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_npc_body.get_rid(), _player.get_rid()]
	for own: Node in _npc_rig.find_children("*", "AnimatableBody3D", true, false):
		if own is CollisionObject3D: excluded.append(own.get_rid())
	var best: Dictionary = {}
	var best_time := INF
	var clash_time := INF
	var clash_at := Vector3.ZERO
	for i: int in points.size():
		var from := _npc_blade_prev[i]
		var to := points[i]
		if from.distance_squared_to(to) < 1.0e-8: continue
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | PLAYER_MELEE_LAYER50, excluded)
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		var sweep_end: Vector3 = to if hit.is_empty() else hit.position
		if _player_blade_intercepts(from, sweep_end):
			var low := 0.0
			var high := clampf(from.distance_to(sweep_end)/from.distance_to(to),0.0,1.0)
			for step in 10:
				var middle := (low + high) * 0.5
				if _player_blade_intercepts(from, from.lerp(to,middle)): high=middle
				else: low=middle
			if high < clash_time: clash_time=high;clash_at=from.lerp(to,high)
		if hit.is_empty(): continue
		var contact_time := clampf(from.distance_to(hit.position)/from.distance_to(to),0.0,1.0)
		if contact_time < best_time:
			best_time=contact_time;best=hit
			best["_velocity"]=(to-from)/delta;best["_speed"]=from.distance_to(to)/delta;best["_sample"]=i
	if clash_time < INF and (best.is_empty() or clash_time <= best_time+0.001):
		_npc_blocked += 1
		if now_ms()-_last_clash_ms>=260: _register_clash(clash_at)
		_npc_stop_attack43()
		return
	if best.is_empty():
		_npc_blade_prev=points
		return
	if not is_instance_valid(best.get("collider")) or not best.collider.has_meta("sword_player_part50"):
		_npc_stop_attack43()
		return
	if now_ms()-_npc_hit_ms<400:
		_npc_blade_prev=points
		return
	var speed:float=best._speed
	var motion:Vector3=best._velocity
	var blade_direction:=_npc_sword.global_basis.x.normalized()
	var across:=absf(motion.normalized().dot(_npc_sword.global_basis.y.normalized()))
	var along:=absf(motion.normalized().dot(blade_direction))
	var kind:="slice" if across>=0.72 else ("stab" if along>=0.72 else "flat")
	var zone:=str(best.collider.get_meta("sword_player_part50"))
	var phase:=_npc_attack_ease(_npc_timer/_npc_strike_duration())
	var amount:=_npc_contact_damage31(speed,phase,zone,kind=="stab",false,kind)
	_npc_last_impact31={"speed":speed,"phase":phase,"zone":zone,"kind":kind,"damage":amount,"sample":best._sample,"edge_across":across,"point_along":along}
	_npc_hit_ms=now_ms();_npc_strike_had_hit=true;_npc_hits+=1
	_apply_player_damage(amount,best.position,motion,kind,zone,best.collider,best.normal,speed)
	_npc_blade_prev=points


## The player's blade damages the resident, which also wakes him up.
func _damage_npc(amount: float, position: Vector3, now: int) -> void:
	if _npc_hp <= 0.0: return
	_npc_hp = maxf(0.0, _npc_hp - amount)
	_npc_engaged = true
	if _npc_state == "wait":
		_npc_state = "approach"
		_npc_timer = 0.0
	combat_audio_event30("blunt",position,clampf(amount/DAMAGE_MAX,.1,1.0))
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
## The opponent lasts several landed blows; player body-part thresholds stay intact.
const NPC_PART_HP57 := {"head": 200.0, "chest": 288.0, "pelvis": 288.0,
	"upperarm": 102.0, "forearm": 90.0, "hand": 66.0,
	"thigh": 132.0, "shin": 102.0, "foot": 66.0}
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
func _npc_take_blade(point: Vector3, speed: float, direction: Vector3, damage: float, sever_contact: bool = false) -> void:
	if damage <= 0.05: return
	var part := _npc_part_at(point)
	var key: String = part.key
	if _npc_dead and key in ["chest", "pelvis"]: return
	var side_suffix := ""
	if String(part.sever).ends_with("_r"): side_suffix = "_r"
	elif String(part.sever).ends_with("_l"): side_suffix = "_l"
	var full_key := key + side_suffix if key not in ["head", "chest", "pelvis"] else key
	if _npc_severed.has(full_key): return
	if not _npc_part_hp.has(full_key):
		_npc_part_hp[full_key] = float(NPC_PART_HP57.get(key, 120.0))
	_npc_part_hp[full_key] = float(_npc_part_hp[full_key]) - damage
	_npc_engaged = true
	if damage >= 3.0:
		_npc_state = "recover"
		_npc_timer = 0.0
		_npc_blade_prev = PackedVector3Array()
	_spray_blood(point, direction, 2 if damage < 3.0 else (8 if damage < 20.0 else 16))
	_npc_bleed_until_ms = max(_npc_bleed_until_ms, Time.get_ticks_msec() + (600 if damage < 3.0 else 2600))
	_npc_anchor_wound27(full_key, point)
	# Small melee scratches flinch visually; only deep wounds interrupt combat.
	if damage >= 3.0:
		_npc_pain_until_ms = maxi(_npc_pain_until_ms, Time.get_ticks_msec() + (1200 if damage >= 20.0 else 650))
	else:
		_npc_flinch_until_ms31 = maxi(_npc_flinch_until_ms31, Time.get_ticks_msec() + 160)
	if float(_npc_part_hp[full_key]) > 0.0: return
	if key in ["chest", "pelvis"] or (key == "head" and not sever_contact):
		_npc_die_from_vital_wound31(point, direction, speed)
	if key in ["chest", "pelvis"] or not sever_contact: return
	_sever_part(full_key, key, part, point, direction, speed)

func _embedded_part_follows_cut31(embedded_part: String, severed_part: String) -> bool:
	if embedded_part == severed_part: return true
	for side: String in ["_l", "_r"]:
		if not severed_part.ends_with(side) or not embedded_part.ends_with(side): continue
		if severed_part == "upperarm" + side and embedded_part in ["forearm" + side, "hand" + side]: return true
		if severed_part == "forearm" + side and embedded_part == "hand" + side: return true
		if severed_part == "thigh" + side and embedded_part in ["shin" + side, "foot" + side]: return true
		if severed_part == "shin" + side and embedded_part == "foot" + side: return true
	return false

## The original bone attachments remain in the skeleton after a mesh cut. They
## must stop receiving hits when their skin has become detached debris.
func _disable_severed_npc_hitboxes31(severed_part: String) -> void:
	if not is_instance_valid(_npc_rig): return
	for part: String in ["head", "chest", "pelvis", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r", "hand_l", "hand_r", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]:
		if not _embedded_part_follows_cut31(part, severed_part): continue
		var anchor := _npc_rig.get_node_or_null("Hit" + part)
		if anchor == null: continue
		for child: Node in anchor.get_children():
			if child is CollisionObject3D:
				child.collision_layer = 0
				child.collision_mask = 0

## Takes the limb off: the mesh vanishes, the stump bleeds, a chunk is thrown.
func _sever_part(full_key: String, kind: String, part: Dictionary, point: Vector3, direction: Vector3, speed: float) -> void:
	# DSH_GORE: cut the ACTUAL skin first. The plane runs through the point that was
	# struck, with the blade's own motion as its normal, and the side that stays is
	# whichever lies towards the chest - so the limb comes away as the skin it was, and
	# the body keeps a closed, still-skinned cut face. Only when that is impossible does
	# the old bone collapse happen.
	var debris_before := _npc_debris.size()
	var stumps_before := _stumps.size()
	var cut_done := false
	if is_instance_valid(_npc_rig):
		var chest := _npc_rig.find_bone("chest")
		var body_side: Vector3 = point - direction.normalized()
		if chest >= 0:
			body_side = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(chest).origin
		var normal: Vector3 = direction.normalized()
		# Bent limbs can place the chest on the distal side of the hit plane.
		# Preserve the joint leading into this limb, not a remote torso point.
		if kind != "head":
			var proximal := _npc_rig.find_bone(full_key)
			if proximal >= 0:
				body_side = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(proximal).origin
				if absf(normal.dot(body_side - point)) < 0.0001:
					var parent := _npc_rig.get_bone_parent(proximal)
					if parent >= 0: body_side = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(parent).origin
		if normal.length_squared() > 1.0e-6:
			var scoped_part := "neck" if kind == "head" else full_key
			cut_done = npc_cut_body(Plane(normal, normal.dot(point)), body_side, scoped_part, kind == "head")
	if cut_done: _npc_mesh_cut_parts39[full_key] = true
	if cut_done and kind == "head": _npc_head_mesh_cut31 = true
	if not cut_done:
		_hide_limb(full_key, kind, String(part.sever))
		# The stand-in belongs only to the explicit legacy fallback. A successful
		# mesh cut already emitted the original cut-away surface as debris.
		_throw_stump(kind, point, direction, speed)
	var detached_piece := _nearest_new_detached_piece31(point, debris_before, stumps_before, not cut_done)
	for thrown_entry: Dictionary in _thrown:
		var embedded: Node3D = thrown_entry.get("node")
		if not is_instance_valid(embedded) or not embedded.has_meta("spear_embedded_part31"): continue
		if not _embedded_part_follows_cut31(str(embedded.get_meta("spear_embedded_part31")), full_key): continue
		if is_instance_valid(detached_piece):
			embedded.reparent(detached_piece, true)
		elif is_instance_valid(_npc_body):
			embedded.reparent(_npc_body, true)
	_npc_severed[full_key] = true
	_disable_severed_npc_hitboxes31(full_key)
	if is_instance_valid(_npc_armor_visual31): _npc_armor_visual31.on_severed(full_key, cut_done)
	_spray_blood(point, direction, 34)
	_npc_bleed_until_ms = Time.get_ticks_msec() + 6500
	_npc_anchor_wound27(full_key, point, true)
	_npc_pain_until_ms = Time.get_ticks_msec() + 2200
	# The accepted melee/arrow hit owns wound audio; severing does not double it.
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
		_queue_npc_corpse31(point, direction, speed)
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
		if _npc_mesh_cut_parts39.has(full_key): continue
		var kind := full_key
		if full_key.ends_with("_l") or full_key.ends_with("_r"):
			kind = full_key.substr(0, full_key.length() - 2)
		var bones: Array[String] = []
		match kind:
			"head":
				if not _npc_head_mesh_cut31: bones = ["head", "neck"]
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
const BloodBudget31 = preload("res://scripts/combat/blood_budget31.gd")

func _ensure_blood_resources() -> void:
	if _blood_material == null:
		_blood_material = StandardMaterial3D.new()
		_blood_material.albedo_color = Color(0.42, 0.012, 0.018)
		_blood_material.roughness = 0.35
	if _blood_meshes.is_empty():
		for i: int in BLOOD_MESH_VARIANTS:
			var sphere := SphereMesh.new()
			sphere.radial_segments = 12
			sphere.rings = 6
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
		if not BloodBudget31.available(_world):return
		var drop := MeshInstance3D.new()
		drop.mesh = _blood_meshes[_blood_mesh_cursor % _blood_meshes.size()]
		_blood_mesh_cursor += 1
		drop.material_override = _blood_material
		_world.add_child(drop)
		BloodBudget31.track(_world,drop)
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
	body.mass = 0.12
	# Lightweight remains yield to real foot contacts without excessive friction.
	var contact_material := PhysicsMaterial.new()
	contact_material.friction = 0.25
	contact_material.bounce = 0.0
	body.physics_material_override = contact_material
	body.gravity_scale = 1.35
	# The player masks layer 1, so the fallback piece can also be stepped into and
	# pushed instead of becoming non-interactive decoration.
	body.collision_layer = 1
	body.collision_mask = 3
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.78, 0.62, 0.49)
	skin.roughness = 0.62
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = MAIL
	cloth.roughness = 0.6
	var plate := StandardMaterial3D.new()
	plate.albedo_color = PEASANT_HAIR
	plate.metallic = 0.0
	plate.roughness = 0.91
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
	_npc_disarmed_at_ms = now_ms()
	var body := RigidBody3D.new()
	_npc_dropped_sword31 = body
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
	_stamp_ground_weapon(body, "sword")
	_register_ground_sword(body)

func _npc_reclaim_sword59(dropped: RigidBody3D) -> bool:
	if _npc_dead or not is_instance_valid(dropped) or not _ground_swords.has(dropped): return false
	if _npc_severed.has("upperarm_r") or _npc_severed.has("forearm_r") or _npc_severed.has("hand_r"): return false
	var model := _take_sword_model(dropped)
	if not is_instance_valid(model): return false
	_ground_swords.erase(dropped)
	model.reparent(_npc_motion, true)
	dropped.queue_free()
	_npc_dropped_sword31 = null
	_npc_sword = model
	_npc_sword.visible = true
	_npc_disarmed = false
	_npc_engaged = true
	_npc_state = "recover"
	_npc_timer = 0.0
	_npc_blade_prev = PackedVector3Array()
	_npc_omega43 = Vector3.ZERO
	_npc_replan_ms50 = 0
	print("DSH_SWORD_PROTO_NPC_REARM hp=", _npc_hp)
	return true

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

## All severed rigid bodies use the player's actual slide contacts, just like
## the settled corpse. Register pieces here; proximity alone never applies force.
func _update_stumps(_delta: float) -> void:
	for index: int in range(_stumps.size() - 1, -1, -1):
		var body: Node3D = _stumps[index]
		if not is_instance_valid(body):
			_stumps.remove_at(index)
			continue
		if body is RigidBody3D:
			body.set_meta("melee_corpse33", true)
	for entry: Dictionary in _npc_debris:
		var body: Node3D = entry.get("node")
		if is_instance_valid(body) and body is RigidBody3D:
			body.set_meta("melee_corpse33", true)
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

## True while the player is delivering a deliberate strong blow: both mouse
## buttons held (the two-handed grip) or a double click on the left button.
func strong_strike31() -> bool:
	return (_hold_left and _hold_right) or Time.get_ticks_msec() < _double_strike_until_ms31

## Read-only world blade segment for an external damage owner (the castle horse).
## No pose, state or hit bookkeeping is changed here.
func blade_segment31() -> Array:
	if not _ready or not _active() or _unarmed or _sword_grounded or _weapon_id == "none":
		return []
	return [_sword_origin, _sword_origin + _dir * (0.06 + _weapon_length)]

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
		"player_death_physics31": _player_death_physics31.duplicate(),
		"has_sword": is_instance_valid(_sword),
		"npc_severed": _npc_severed.keys(), "npc_disarmed": _npc_disarmed, "npc_dead": _npc_dead,
		"npc_part_hp": _npc_part_hp.duplicate(),
		"npc_position": _npc_body.global_position if is_instance_valid(_npc_body) else Vector3.ZERO,
		"npc_cuts": _npc_cut_total, "npc_debris": _npc_debris.size(),
		"npc_severed_count": _npc_severed.size(),
		"grip_hand_error": _grip_hand_error, "self_pose_clear": _self_pose_clear,
		"sword_grounded": _sword_grounded, "dropped_at": _dropped_at,
		"head_clearance": _head_blade_clearance(),
		"blade_in_world": _blade_penetrates_world(_dir, _sword_origin),
		"body_clearance": _body_blade_clearance(),
		"armour_plates": _knight_armour.size(), "stump_count": _stumps.size(),
		"npc_armor": _npc_armor_loadout31.duplicate(), "npc_armor_tier": _enemy_armor_tier,
		"npc_walk_gait": is_instance_valid(_npc_gait),
		"enemy_hunting": _npc_engaged, "enemy_enraged": _enemy_is_enraged(),
		"enemy_clashes": _enemy_clashes, "enemy_last_clash_push": _enemy_last_clash_push,
		"enemy_combo_left": _enemy_combo_left, "enemy_evades": _enemy_evades,
		"enemy_attack_counts": _npc_attack_counts.duplicate(),
		"enemy_last_seen": _enemy_last_seen, "enemy_lost_ms": _enemy_lost_since_ms,
		"sparks": _sparks.size(), "sparks_total": _sparks_total, "half_sword": _half_sword, "half_sword_point": _half_sword_blade_point,
		"bleeding": Time.get_ticks_msec() < _npc_bleed_until_ms,
		"npc_fall": (1.0 - absf(_npc_corpse31.global_basis.y.dot(Vector3.UP))) if is_instance_valid(_npc_corpse31) else 0.0,
		"npc_corpse_physics31": {"active": is_instance_valid(_npc_corpse31),
			"position": _npc_corpse31.global_position if is_instance_valid(_npc_corpse31) else Vector3.ZERO,
			"linear_velocity": _npc_corpse31.linear_velocity if is_instance_valid(_npc_corpse31) else Vector3.ZERO,
			"angular_velocity": _npc_corpse31.angular_velocity if is_instance_valid(_npc_corpse31) else Vector3.ZERO,
			"sleeping": _npc_corpse31.sleeping if is_instance_valid(_npc_corpse31) else false},
		"npc_speed_scale": _npc_speed_scale(),
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
		"weapon_visible": is_instance_valid(_sword) and _sword.visible,
		"weapon_rear_m": weapon_rear_extent(),
		"weapon_active": _active(),
		"swing_phase": _swing_phase, "anticipation": _anticipation, "brace": _brace,
		"omega_speed": _omega.length(), "omega_cap": (7.6 if _weapon_id == "sledge" else (9.5 if _active_side() != &"both" else 11.0)) if _weapon_id in ["sword", "sledge"] else MAX_OMEGA / _weapon_mass,
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
	if is_instance_valid(_npc_corpse31): _npc_corpse31.queue_free()
	set_physics_process(false)
	set_process_input(false)


var _combat_audio_node30: Node3D

func _ensure_combat_audio30() -> Node3D:
	if not is_instance_valid(_combat_audio_node30):
		_combat_audio_node30=preload("res://scripts/audio/combat_audio30.gd").new()
		_combat_audio_node30.name="CombatAudio30"
		add_child(_combat_audio_node30)
	return _combat_audio_node30

func _build_melee_audio31() -> void:
	_ensure_combat_audio30()

func _melee_stream31(kind: String, variant: int) -> AudioStreamWAV:
	var audio := _ensure_combat_audio30()
	var bank: String="blunt" if kind=="flesh" else kind
	return audio.banks[bank][posmod(variant,4)]

func _play_melee_hit31(at: Vector3, kind: String, strength: float) -> void:
	combat_audio_event30(kind,at,strength)

func combat_audio_event30(kind: String, at: Vector3, strength: float, event_key: String="") -> void:
	if kind=="metal":
		var contact:Dictionary=get_meta("interception_contact31",{})
		if int(contact.get("frame",-100))==Engine.get_physics_frames() and Vector3(contact.get("point",Vector3.INF)).distance_squared_to(at)<.0025:
			kind=str(contact.get("material","metal"))
	var fx_kind:=kind
	if kind=="armor_light":fx_kind="flesh"
	elif kind in ["armor_medium","armor_heavy"]:fx_kind="metal"
	set_meta("contact_fx31",{"kind":fx_kind,"point":at,"frame":Engine.get_physics_frames()})
	_ensure_combat_audio30().emit_event(self,kind,at,strength,event_key)

func _combat_audio_surface30(collider: Node, at: Vector3, speed: float) -> void:
	if speed<0.15:return
	var audio := _ensure_combat_audio30()
	var kind:String=audio.material_kind(collider)
	set_meta("contact_fx31",{"kind":kind,"point":at,"frame":Engine.get_physics_frames()})
	audio.emit_event(self,kind,at,clampf(speed/7.0,.08,1.0),str(collider.get_instance_id()) if is_instance_valid(collider) else "world")

func _combat_audio_tick30(delta: float) -> void:
	_ensure_combat_audio30().tick(self,delta)

func combat_audio_reset30() -> void:
	if is_instance_valid(_combat_audio_node30):_combat_audio_node30.reset()

func melee_audio_report31() -> Dictionary:
	return _ensure_combat_audio30().report()

## A falling catapult stone is a blunt impact, not a sword cut. The catapult
## supplies one measured contact and the damage calculated from its 92 kg mass
## and relative speed. Keep the existing player/NPC HP and death owners here.
func apply_catapult_stone_impact31(body: Node, damage: int, point: Vector3,
		velocity: Vector3) -> Dictionary:
	if damage <= 0 or not is_instance_valid(body): return {"applied": false}
	var direction: Vector3 = velocity.normalized() if velocity.length_squared() > 0.001 else Vector3.DOWN
	if body == _player:
		if not is_instance_valid(_world) or bool(_world.get("preview_dead")):
			return {"applied": false, "reason": "dead"}
		var before: float = _sparring_hp
		_sparring_hp = maxf(0.0, _sparring_hp - float(damage))
		var owner: Object = _session_health()
		if owner != null:
			before = float(owner.get("_hp"))
			owner.set("_hp", maxi(0, int(owner.get("_hp")) - damage))
			owner.set("_hit_age", 0.0)
			owner.call("_refresh")
		_sparring_hp = minf(_sparring_hp, maxf(0.0, before - float(damage)))
		_play_melee_hit31(point, "flesh", clampf(float(damage) / 100.0, 0.35, 1.0))
		if _sparring_hp <= 0.0 or (owner != null and int(owner.get("_hp")) <= 0):
			_kill_player(point, direction, float(damage))
		elif is_instance_valid(_player):
			_player.apply_contact_melee_impulse(direction, clampf(float(damage) * 0.22, 5.0, 30.0))
		return {"applied": true, "hp_before": before,
			"hp_after": float(owner.get("_hp")) if owner != null else _sparring_hp,
			"dead": bool(_world.get("preview_dead"))}
	if _is_npc_collider(body):
		if _npc_dead or _npc_hp <= 0.0: return {"applied": false, "reason": "dead"}
		var before: float = _npc_hp
		_npc_hp = maxf(0.0, _npc_hp - float(damage))
		_npc_receive_impulse31("chest", velocity.length(), direction, float(damage))
		_npc_pain_until_ms = maxi(_npc_pain_until_ms, Time.get_ticks_msec() + 1200)
		_npc_engaged = true
		_play_melee_hit31(point, "flesh", clampf(float(damage) / 100.0, 0.35, 1.0))
		if damage >= 30: _spray_blood(point, direction, mini(20, damage / 4))
		if _npc_hp <= 0.0:
			_npc_dead = true
			_npc_disarmed = true
			_npc_engaged = false
			_npc_state = "wait"
			if is_instance_valid(_npc_sword):
				_drop_sword(_npc_sword.global_position, direction, velocity.length())
			_queue_npc_corpse31(point, direction, velocity.length())
		return {"applied": true, "hp_before": before, "hp_after": _npc_hp, "dead": _npc_dead}
	return {"applied": false, "reason": "foreign_body"}

func _add_player_hitboxes50() -> void:
	if not is_instance_valid(_rig): return
	# Everything here is in the rig's own bone units: the box is sized from the
	# bone's TRUE length (the offset to its child), so it wraps the limb whatever
	# the model scale is.
	var unit := 1.0
	var thigh := _rig.find_bone("thigh_l")
	if thigh >= 0: unit = maxf(0.2, _player_bone_length50(thigh))
	var limbs := ["head", "chest", "pelvis", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r",
		"hand_l", "hand_r", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]
	var count := 0
	for part: String in limbs:
		var bone := _rig.find_bone(part)
		if bone < 0: continue
		var blen := _player_bone_length50(bone)
		var radius := blen * 0.45
		var box_size := Vector3.ZERO
		var box_at := Vector3(0.0, blen * 0.5, 0.0)
		if part == "head":
			# The original thigh-derived .396 x .373 box misses the resident's
			# visible eyes and helmet apertures. Preserve the per-bone hitbox and
			# physics exceptions, but fit the actual head/visor silhouette.
			box_size = Vector3(unit * 1.42, unit * 1.42, unit * 1.25)
			box_at = Vector3(0.0, blen * 0.55, 0.0)
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
		_rig.add_child(anchor)
		# AnimatableBody3D, not StaticBody3D: a static body hung on a bone never
		# synced its transform with the physics server, so rays missed the limbs.
		var hit_body := AnimatableBody3D.new()
		hit_body.sync_to_physics = false
		hit_body.collision_layer = PLAYER_MELEE_LAYER50
		hit_body.collision_mask = 0
		hit_body.set_meta("sword_player_part50", part)
		var hit_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = box_size
		hit_shape.shape = box
		hit_shape.position = box_at
		hit_body.add_child(hit_shape)
		anchor.add_child(hit_body)
		# The target box is hittable by the player's blade, but the knight's
		# own walking capsule must pass through his moving arm and legs.
		_player.add_collision_exception_with(hit_body)
		hit_body.add_collision_exception_with(_player)
		# Target volumes stay ray-queryable, but the player collides with the
		# physical knight/corpse rather than 15 invisible bone-attached boxes.
		if is_instance_valid(_npc_body):
			_npc_body.add_collision_exception_with(hit_body)
			hit_body.add_collision_exception_with(_npc_body)
		_player_hitboxes50.append(hit_body)
		count += 1
	print("DSH_PLAYER_HITBOXES50 parts=", count, " unit=", unit)



func _player_bone_length50(bone: int) -> float:
	if not is_instance_valid(_rig): return 0.0
	for index in _rig.get_bone_count():
		if _rig.get_bone_parent(index) == bone: return _rig.get_bone_rest(index).origin.length()
	return 0.0

func _ensure_player_hitboxes50() -> void:
	if not is_instance_valid(_rig) or not is_instance_valid(_player): return
	if _player_hitboxes50.is_empty(): _add_player_hitboxes50()
	for hit: AnimatableBody3D in _player_hitboxes50:
		if not is_instance_valid(hit): continue
		var part := str(hit.get_meta("sword_player_part50", ""))
		var removed := false
		for lost: String in _player_severed:
			if _embedded_part_follows_cut31(part, lost): removed = true; break
		hit.collision_layer = 0 if removed or bool(_world.get("preview_dead")) else PLAYER_MELEE_LAYER50

func _npc_reach50() -> float:
	var arm := (_npc_rest_fore.origin.length() + _npc_rest_hand.origin.length()) * _npc_rig.global_basis.get_scale().length() / sqrt(3.0)
	return clampf(arm + float(WEAPONS["sword"]["length"]) - 0.12, 1.45, 1.8)

func _npc_path_clear50(direction: Vector3, length50: float = 1.35) -> bool:
	var forward := Vector3(direction.x,0,direction.z).normalized()
	if forward.length_squared() < 0.5: return false
	var space := _npc_body.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_npc_body.get_rid(), _player.get_rid()]
	for body: Node in _npc_rig.find_children("*", "AnimatableBody3D",true,false):
		if body is CollisionObject3D: excluded.append(body.get_rid())
	var side := forward.cross(Vector3.UP)
	for x in [-0.31,0.0,0.31]:
		for y in [0.45,1.35]:
			var from: Vector3 = _npc_body.global_position + side * float(x) + Vector3.UP * float(y)
			var ray := PhysicsRayQueryParameters3D.create(from, from + forward * length50, 1, excluded)
			if not space.intersect_ray(ray).is_empty(): return false
	var foot := _npc_body.global_position + forward * minf(length50,0.7)
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.55,foot-Vector3.UP*.65,1,excluded))
	return not ground.is_empty() and (ground.normal as Vector3).y >= 0.55

func _npc_navigation50(desired: Vector3) -> Vector3:
	# Bounded local detour. Every route still goes through move_and_slide and
	# stops if there is no supported, capsule-width corridor. No teleports.
	var now := now_ms()
	var forward := Vector3(desired.x,0,desired.z).normalized()
	# A cached chase must never override a newly requested retreat or sidestep.
	if now < _npc_replan_ms50 and forward.dot(_npc_route_request53) > 0.85:
		return _npc_route_dir50
	_npc_route_request53 = forward
	_npc_replan_ms50 = now + 250
	_npc_replans50 += 1
	if _npc_path_clear50(forward):
		_npc_route_dir50 = forward
		return forward
	var best := Vector3.ZERO
	var score := -INF
	for degrees in [45.0,80.0,115.0,150.0,-45.0,-80.0,-115.0]:
		var angle := deg_to_rad(degrees * _npc_detour_side50)
		var candidate := forward.rotated(Vector3.UP,angle)
		if not _npc_path_clear50(candidate): continue
		var value := candidate.dot(forward) + (0.3 if degrees > 0.0 else 0.0)
		if value > score: best=candidate;score=value
	_npc_route_dir50 = best
	return best

func _npc_blade_transform50(origin: Vector3, delta: float) -> Transform3D:
	var x := _npc_dir.normalized()
	var tangent := _npc_omega43.cross(x)
	var up := _npc_edge_up50 - x * _npc_edge_up50.dot(x)
	if up.length_squared() < 0.000001: up = x.cross(Vector3.RIGHT if absf(x.x) < 0.8 else Vector3.UP)
	up = up.normalized()
	if tangent.length_squared() > 0.04:
		var desired := tangent.normalized()
		# Either face of the double edge cuts; use the closest roll to avoid a
		# half turn whenever the arm reverses its preparation.
		if up.dot(desired) < 0.0: desired = -desired
		var angle := up.angle_to(desired)
		if angle > 0.00001: up = up.slerp(desired, minf(1.0, 6.0 * delta / angle)).normalized()
	_npc_edge_up50 = up
	return Transform3D(Basis(x,up,x.cross(up).normalized()),origin)

func _npc_apply_health_wound50(amount: float, point: Vector3, direction: Vector3, speed: float, penetrates: bool) -> void:
	_npc_hp = maxf(0.0, _npc_hp - amount)
	if _npc_hp <= 0.0 and not _npc_dead: _npc_die_from_vital_wound31(point,direction,speed,penetrates)

func _player_disable_arm50(full_key: String, direction: Vector3) -> void:
	var grip := _active_side()
	_player_disabled_parts50[full_key] = true
	var side := &"right" if full_key.ends_with("_l") else &"left"
	if side == &"right" and _shield_worn: drop_shield_to_ground31()
	if grip != side and grip != &"both": return
	var other := &"left" if side == &"right" else &"right"
	if str(weapon_entry().get("grip", "")) != "two" and not _hand_lost31(other) and not (other == &"right" and _shield_worn):
		_carry_side = other
	else:
		_player_disarmed = true
		_drop_player_sword(direction)

# Decisions use visible poses buffered for a human-scale reaction delay. No input reads.
var _npc_observations53: Array[Dictionary] = []
var _npc_observed53: Dictionary = {}
var _npc_last_tip53 := Vector3.INF
var _npc_threat53 := false
var _npc_counter_until53 := 0
var _npc_orbit_side53 := 1.0
var _npc_orbit_until53 := 0
var _npc_counters53 := 0
var _npc_orbit_steps53 := 0
var _npc_spacing_retreat53 := false

func _npc_observe53(delta: float) -> void:
	var now := now_ms()
	var seen := _npc_visible_player43()
	var steel := seen and is_instance_valid(_sword) and _sword.is_visible_in_tree() and not _sword_grounded and not _unarmed
	var tip := _sword_origin + _dir * _weapon_length if steel else _player.global_position + Vector3.UP
	var tip_velocity := (tip - _npc_last_tip53) / maxf(delta, 0.001) if steel and _npc_last_tip53.is_finite() else Vector3.ZERO
	# Translating with a held blade is not an attack; observe motion relative to the wielder.
	var speed := (tip_velocity - _player.velocity).length() if steel and _npc_last_tip53.is_finite() else 0.0
	_npc_last_tip53 = tip if steel else Vector3.INF
	# Stability is recorded at capture time, then delayed with the whole snapshot.
	# No newer sample can make an older observation retrospectively look settled.
	var steady_ms := 0
	var previous: Dictionary = _npc_observations53.back() if not _npc_observations53.is_empty() else _npc_observed53
	if steel and speed <= 0.65 and not previous.is_empty() \
			and bool(previous.get("steel", false)) and bool(previous.get("visible", false)) \
			and float(previous.get("speed", INF)) <= 0.65:
		var elapsed := now - int(previous.at)
		var offset := tip - _player.global_position
		var prior_offset: Vector3 = (previous.tip as Vector3) - (previous.position as Vector3)
		if elapsed > 0 and elapsed <= 80 and offset.distance_to(prior_offset) <= 0.08:
			steady_ms = mini(1000, int(previous.get("steady_ms", 0)) + elapsed)
	_npc_observations53.append({"at":now,"position":_player.global_position,"velocity":_player.velocity,"tip":tip,"speed":speed,"steel":steel,"visible":seen,"steady_ms":steady_ms})
	while not _npc_observations53.is_empty() and now - int(_npc_observations53[0].at) >= 180:
		_npc_observed53 = _npc_observations53.pop_front()
	if _npc_observations53.size() > 64: _npc_observations53.pop_front()
	var danger := false
	if not _npc_observed53.is_empty():
		danger = _npc_observed53.visible and _npc_observed53.steel and float(_npc_observed53.speed) > 1.7 and (_npc_observed53.tip as Vector3).distance_to(_npc_body.global_position + Vector3.UP) < 2.05
	if _npc_threat53 and not danger: _npc_counter_until53 = now + 650
	_npc_threat53 = danger

func _npc_update_aim53() -> void:
	if _npc_observed53.is_empty() or not _npc_observed53.visible: return
	var shoulder: Vector3 = _npc_rig.global_transform * _npc_rig.get_bone_global_pose(_npc_upper).origin
	var lead: Vector3 = (_npc_observed53.velocity as Vector3).limit_length(4.0) * 0.10
	lead.y = 0.0
	_npc_aim43 = ((_npc_observed53.position as Vector3) + Vector3.UP * 1.05 + lead - shoulder).normalized()

func _npc_begin_attack53(distance: float) -> void:
	# A combo is one follow-up beat. If the target left reach, the stored beat has
	# expired; it must not shorten every later approach.
	_enemy_combo_left = 0
	_npc_attack_kind = _npc_choose_attack(distance)
	_npc_update_aim53()
	if now_ms() < _npc_counter_until53: _npc_counters53 += 1
	_npc_counter_until53 = 0
	_npc_state = "windup"
	_npc_swing_start43 = _npc_dir
	_npc_swing_started_ms50 = now_ms()
	_npc_timer = 0.0

func _npc_footwork53(to_player: Vector3, distance: float, defensive: bool) -> Vector3:
	if distance < 0.01: return Vector3.ZERO
	var forward := to_player.normalized()
	# Keep opening space until the sword arm can work, rather than oscillating at one threshold.
	if distance < 1.08: _npc_spacing_retreat53 = true
	elif distance > 1.25: _npc_spacing_retreat53 = false
	if _npc_spacing_retreat53: return _npc_navigation50(-forward) * 1.7
	if distance > (1.95 if defensive else 1.52) or not _npc_visible_player43():
		return _npc_navigation50(forward) * (3.6 if distance > 3.0 else 2.35)
	if now_ms() >= _npc_orbit_until53:
		_npc_orbit_side53 *= -1.0
		_npc_orbit_until53 = now_ms() + 1100 + (_npc_attack_cursor % 3) * 170
	var side := forward.cross(Vector3.UP) * _npc_orbit_side53
	var direction := (side + forward * (-0.42 if defensive and _npc_threat53 else 0.10)).normalized()
	_npc_orbit_steps53 += 1
	return _npc_navigation50(direction) * (1.05 if defensive else 0.85)

func _ensure_contact_sparks31() -> Node3D:
	var scene:Node=get_tree().current_scene
	if not is_instance_valid(scene):scene=get_tree().root
	var helper:Node3D=scene.get_meta("contact_sparks31") if scene.has_meta("contact_sparks31") else null
	if not is_instance_valid(helper):
		helper=preload("res://scripts/combat/contact_sparks31.gd").new()
		helper.name="ContactSparks31";helper.host=self;scene.add_child(helper);scene.set_meta("contact_sparks31",helper)
	set_meta("contact_sparks31",helper)
	return helper

func _prepare_contact31() -> Dictionary:
	for model:Node3D in _weapon_models.values():Interception31.warm(model)
	Interception31.warm(_npc_sword)
	var helper:=_ensure_contact_sparks31()
	return await helper.warm_render()
