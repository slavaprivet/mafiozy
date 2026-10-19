extends Node3D
const ModelFinish31 = preload("res://scripts/weapons/weapon_model_finish31.gd")
## DSH_BOW_PROTO
##
## A physical bow for the Mafiozi build, built the same way as the sword
## prototype: it drives the real hero rig with its own two-bone IK, owns its own
## models and HUD, and never writes the player's animation state.
##
## What it does:
##   * the bow is held in the archer's LEFT hand, the string is drawn with the
##     RIGHT one - hold the RIGHT mouse button to draw, release to loose;
##   * drawing pulls the string, brings the draw hand to the anchor and zooms the
##     view in, and a dotted arc shows where the arrow will actually fly;
##   * the arrow is a real ballistic projectile: it drops under gravity along its
##     whole flight, and it STICKS where it lands - into a body, a wall or a pole -
##     and stays there, riding along if it hit something that moves.

# ---------------------------------------------------------------- tuning
## Time from a slack string to a full draw.
const DRAW_TIME := 0.85
## Arrow speed at no draw and at full draw, in metres per second.
const ARROW_SPEED_MIN := 16.0
const ARROW_SPEED_MAX := 54.0
const GRAVITY := 9.81
## The archer's own body does not stop his arrows, but it does stop the aim probe.
const AIM_MASK := 1
const MAX_ARROWS := 44
const MAX_AIM_DOTS := 30
## How far the nock travels back at full draw, in metres.
const STRING_PULL := 0.42
## Field of view multiplier at full draw.
const ZOOM_FACTOR := 0.86
const ZOOM_RATE := 4.5
## Damage an arrow does to a body part, before armour.
const ARROW_DAMAGE := 26.0
## Where the arrow leaves the bow, measured from the grip along the aim.
const ARROW_MUZZLE := 0.55

var _world: Node3D
var _player: CharacterBody3D
var _rig: Skeleton3D
var _camera: Camera3D
var _sword_host: Node = null

var _ready := false
var _selected := false
var _drawing := false
var _fire_button_down := false
var _string_target_world := Vector3.ZERO
## Right button: shows the arrow's path without spending an arrow.
var _aiming := false
var _draw_amount := 0.0
var _release_ms := -10000
var _lock_until_ms := 0

# ---------------------------------------------------------------- rig binding
var _bone_bow_clavicle := -1
var _bone_bow_upper := -1
var _bone_bow_fore := -1
var _bone_bow_hand := -1
var _bone_draw_clavicle := -1
var _bone_draw_upper := -1
var _bone_draw_fore := -1
var _bone_draw_hand := -1
var _bone_chest := -1
var _bone_head := -1
var _rest_bow_upper := Transform3D.IDENTITY
var _rest_bow_fore := Transform3D.IDENTITY
var _rest_bow_hand := Transform3D.IDENTITY
var _rest_draw_upper := Transform3D.IDENTITY
var _rest_draw_fore := Transform3D.IDENTITY
var _rest_draw_hand := Transform3D.IDENTITY
## Rig-space sign of the character's visual left, used to keep each arm on its side.
var _left_sign := 1.0

# ---------------------------------------------------------------- models
var _bow: Node3D
var _string_a: MeshInstance3D
var _string_b: MeshInstance3D
var _nock: Node3D
var _aim_dots: Array[MeshInstance3D] = []
var _aim_dot_mesh: SphereMesh
var _aim_material: StandardMaterial3D
var _arrows: Array[Dictionary] = []
var _wood_dark: StandardMaterial3D
var _wood_light: StandardMaterial3D
var _horn: StandardMaterial3D
var _leather: StandardMaterial3D
var _feather: StandardMaterial3D
var _steel: StandardMaterial3D
var _string_material: StandardMaterial3D
## Meshes shared by every arrow and every quiver.
var _arrow_visual_parts31: Array[Dictionary] = []
var _shaft_mesh: CylinderMesh
var _head_mesh: CylinderMesh
var _collar_mesh: CylinderMesh
var _nock_mesh: CylinderMesh
var _vane_mesh: BoxMesh
var _quiver_shaft_mesh: CylinderMesh
var _quiver_fletch_mesh: BoxMesh
## The quiver worn on the back, and the arrows left in it.
var _quiver: Node3D
var _ground_quiver: Node3D
var _quiver_arrows: Array[Node3D] = []
var _quiver_worn := false
var _arrows_left := 0
var _nocked := false
var _quiver_mouth := Vector3.ZERO
## World position the drawing hand actually reached, which is where the string nock
## is drawn: the string and the hand can never disagree.
var _string_hand_world := Vector3.ZERO
## The arrow sitting on the string, shown while an arrow is nocked.
var _nocked_arrow: Node3D
const ARROWS_PER_QUIVER := 20

# ---------------------------------------------------------------- arrow fetching
## Where the fetching hand is in its trip to the quiver and back to the string.
var _fetch_phase := ""      # "" | "reach" | "nock"
var _fetch_t := 0.0
const FETCH_REACH_TIME := 0.42
const FETCH_NOCK_TIME := 0.30
## A drawn arrow in flight is spent; this is the state before it can shoot again.
var _grounded := false
var _ground_items: Array[Dictionary] = []
const GROUND_REACH := 2.4

# ---------------------------------------------------------------- hint
var _hint: Label
var _hint_layer: CanvasLayer

# ---------------------------------------------------------------- diagnostics
var _shots := 0
var _incoming_parries31 := 0
var _incoming_player_hits31 := 0
var _stuck_total := 0
var _last_hit_distance := -1.0
var _last_flight_time := 0.0
var _base_fov := 70.0
## Smoothed field-of-view multiplier handed to the shared aim camera.
var _zoom_scale := 1.0
var _sight_frame := -1
var _sight_camera := Transform3D.IDENTITY
var _sight_point := Vector3.ZERO
var _aim_frame := -1
var _aim_camera_transform := Transform3D.IDENTITY
var _aim_visual_transform := Transform3D.IDENTITY
var _frame_aim_direction := Vector3.FORWARD
var _weapons_host: Node = null
var _debug_tick := 0

func install(world: Node3D, player: CharacterBody3D) -> Dictionary:
	if _ready or not is_instance_valid(world) or not is_instance_valid(player):
		return {"ok": false, "reason": "binding"}
	_world = world
	_player = player
	var rig: Skeleton3D = player.get("_pose_skeleton") as Skeleton3D
	if rig == null: return {"ok": false, "reason": "skeleton"}
	_rig = rig
	_camera = player.get_preview_camera()
	if _camera == null: return {"ok": false, "reason": "camera"}
	_base_fov = _camera.fov
	# The rig is mirrored on screen: the "_l" bones are the character's RIGHT arm.
	# The bow hand is the character's LEFT, so it drives the "_r" bones.
	_bone_bow_clavicle = rig.find_bone("clavicle_r")
	_bone_bow_upper = rig.find_bone("upperarm_r")
	_bone_bow_fore = rig.find_bone("forearm_r")
	_bone_bow_hand = rig.find_bone("hand_r")
	# The string hand is the character's RIGHT: the "_l" bones.
	_bone_draw_clavicle = rig.find_bone("clavicle_l")
	_bone_draw_upper = rig.find_bone("upperarm_l")
	_bone_draw_fore = rig.find_bone("forearm_l")
	_bone_draw_hand = rig.find_bone("hand_l")
	_bone_chest = rig.find_bone("chest")
	_bone_head = rig.find_bone("head")
	if _bone_bow_upper < 0 or _bone_bow_fore < 0 or _bone_bow_hand < 0:
		return {"ok": false, "reason": "bow_arm_bones"}
	if _bone_draw_upper < 0 or _bone_draw_fore < 0 or _bone_draw_hand < 0:
		return {"ok": false, "reason": "draw_arm_bones"}
	if _bone_bow_hand >= 0 and _bone_draw_hand >= 0:
		var visual_left_rig: Vector3 = rig.get_bone_global_pose(_bone_bow_hand).origin
		var visual_right_rig: Vector3 = rig.get_bone_global_pose(_bone_draw_hand).origin
		_left_sign = 1.0 if (visual_left_rig.x - visual_right_rig.x) >= 0.0 else -1.0
		if _left_sign == 0.0: _left_sign = 1.0
	_rest_bow_upper = rig.get_bone_rest(_bone_bow_upper)
	_rest_bow_fore = rig.get_bone_rest(_bone_bow_fore)
	_rest_bow_hand = rig.get_bone_rest(_bone_bow_hand)
	_rest_draw_upper = rig.get_bone_rest(_bone_draw_upper)
	_rest_draw_fore = rig.get_bone_rest(_bone_draw_fore)
	_rest_draw_hand = rig.get_bone_rest(_bone_draw_hand)
	if _rest_bow_fore.origin.length() <= 0.01 or _rest_bow_hand.origin.length() <= 0.01:
		return {"ok": false, "reason": "arm_lengths"}
	_build_materials()
	_bow = _build_bow(_world)
	_nocked_arrow = _build_arrow(_world)
	_nocked_arrow.visible = false
	_quiver = _build_quiver(_world)
	_ground_quiver = _build_quiver(_world)
	_build_aim_dots()
	_build_arrow_audio31()
	_build_hint()
	_sword_host = _world.get("preview_sword_prototype")
	_weapons_host = _world.get("preview_weapons")
	# The archer starts with his quiver on and a full count, like a loaded weapon.
	_quiver_worn = true
	_arrows_left = ARROWS_PER_QUIVER
	_ready = true
	_player._bow_host = self
	# The shared aim camera rewrites the field of view every frame; running after it
	# is what lets the draw zoom actually be seen.
	process_priority = 200
	set_process_input(true)
	set_process(true)
	set_physics_process(true)
	print("DSH_BOW_PROTO_BONES bow=", _bone_bow_clavicle, ",", _bone_bow_upper, ",", _bone_bow_fore, ",", _bone_bow_hand,
		" draw=", _bone_draw_clavicle, ",", _bone_draw_upper, ",", _bone_draw_fore, ",", _bone_draw_hand)
	return {"ok": true, "bow_hand": rig.get_bone_name(_bone_bow_hand), "draw_hand": rig.get_bone_name(_bone_draw_hand)}

func _build_materials() -> void:
	_wood_dark = StandardMaterial3D.new()
	_wood_dark.albedo_color = Color(0.24, 0.14, 0.07)
	_wood_dark.roughness = 0.78
	_wood_light = StandardMaterial3D.new()
	_wood_light.albedo_color = Color(0.42, 0.27, 0.13)
	_wood_light.roughness = 0.72
	_horn = StandardMaterial3D.new()
	_horn.albedo_color = Color(0.68, 0.62, 0.45)
	_horn.roughness = 0.35
	_leather = StandardMaterial3D.new()
	_leather.albedo_color = Color(0.30, 0.19, 0.12)
	_leather.roughness = 0.88
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.76, 0.77, 0.80)
	_steel.metallic = 0.88
	_steel.roughness = 0.38
	_string_material = StandardMaterial3D.new()
	_string_material.albedo_color = Color(0.90, 0.87, 0.76)
	_string_material.roughness = 0.85
	_feather = StandardMaterial3D.new()
	_feather.albedo_color = Color(0.88, 0.86, 0.80)
	_feather.roughness = 0.92
	_build_shared_meshes()

## Every arrow in the game - nocked, in flight, and the ones standing in a quiver -
## is drawn from these meshes. Building a fresh set per arrow allocated several
## hundred mesh resources for an identical picture.
func _build_shared_meshes() -> void:
	_shaft_mesh = CylinderMesh.new()
	_shaft_mesh.top_radius = 0.0048
	_shaft_mesh.bottom_radius = 0.0072
	_shaft_mesh.height = 0.74
	_shaft_mesh.radial_segments = 8
	_head_mesh = CylinderMesh.new()
	_head_mesh.top_radius = 0.0
	_head_mesh.bottom_radius = 0.0125
	_head_mesh.height = 0.095
	_head_mesh.radial_segments = 8
	_collar_mesh = CylinderMesh.new()
	_collar_mesh.top_radius = 0.0075
	_collar_mesh.bottom_radius = 0.0075
	_collar_mesh.height = 0.018
	_collar_mesh.radial_segments = 8
	_nock_mesh = CylinderMesh.new()
	_nock_mesh.top_radius = 0.0072
	_nock_mesh.bottom_radius = 0.0072
	_nock_mesh.height = 0.028
	_nock_mesh.radial_segments = 6
	_vane_mesh = BoxMesh.new()
	_vane_mesh.size = Vector3(0.0016, 0.042, 0.115)
	_quiver_shaft_mesh = CylinderMesh.new()
	_quiver_shaft_mesh.top_radius = 0.0044
	_quiver_shaft_mesh.bottom_radius = 0.0044
	_quiver_shaft_mesh.height = 0.34
	_quiver_shaft_mesh.radial_segments = 6
	_quiver_fletch_mesh = BoxMesh.new()
	_quiver_fletch_mesh.size = Vector3(0.0016, 0.075, 0.030)

# ---------------------------------------------------------------- construction

## A recurve bow: a wrapped riser, two limbs built from tapered staves that bow
## away and then flick back, horn nocks at the tips, and a two-part string.
## Local frame: +Z is the shooting direction, +Y runs along the limbs.
func _build_bow(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "PrototypeBow"
	parent.add_child(root)
	root.visible = false
	# Riser: the stiff middle the hand holds.
	var riser := MeshInstance3D.new()
	var riser_box := BoxMesh.new()
	riser_box.size = Vector3(0.042, 0.34, 0.070)
	riser.mesh = riser_box
	riser.material_override = _wood_dark
	riser.position = Vector3(0.0, 0.0, 0.10)
	root.add_child(riser)
	# Leather grip wrap, slightly proud of the riser so the wrap reads.
	var wrap := MeshInstance3D.new()
	var wrap_box := BoxMesh.new()
	wrap_box.size = Vector3(0.052, 0.17, 0.080)
	wrap.mesh = wrap_box
	wrap.material_override = _leather
	wrap.position = Vector3(0.0, 0.0, 0.10)
	root.add_child(wrap)
	# Limbs, upper and lower. The staves are MERGED into one mesh per tone per side,
	# which takes the bow from thirty-odd nodes and meshes down to a handful while
	# keeping the two-tone limbs exactly as they were drawn.
	for side: float in [1.0, -1.0]:
		for dark: bool in [true, false]:
			var merged := _build_limb_mesh(side, dark)
			if merged == null: continue
			var limb := MeshInstance3D.new()
			limb.mesh = merged
			limb.material_override = _wood_dark if dark else _wood_light
			root.add_child(limb)
		# Horn nock at the tip, where the string sits.
		var tip := _limb_point(1.0, side)
		var nock := MeshInstance3D.new()
		var nock_box := BoxMesh.new()
		nock_box.size = Vector3(0.026, 0.045, 0.030)
		nock.mesh = nock_box
		nock.material_override = _horn
		nock.position = tip
		root.add_child(nock)
	# The two string halves, stretched every frame from a tip to the nock.
	_string_a = _make_string(root)
	_string_b = _make_string(root)
	_nock = Node3D.new()
	_nock.name = "Nock"
	root.add_child(_nock)
	ModelFinish31.finish(root, [_string_a, _string_b])
	return root

## One limb's staves of a single tone, merged into a single surface. The taper is
## kept exactly: each stave is placed with the same size and rotation it had as its
## own node, only now they share one mesh.
func _build_limb_mesh(side: float, dark: bool) -> ArrayMesh:
	var staves := 16
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed := 0
	for i: int in staves:
		var s0 := float(i) / float(staves)
		var s1 := float(i + 1) / float(staves)
		if (s0 < 0.5) != dark: continue
		var a := _limb_point(s0, side)
		var b := _limb_point(s1, side)
		var thick := lerpf(0.036, 0.014, s0)
		var size := Vector3(thick, a.distance_to(b) * 1.15, thick * 0.72)
		var along := (b - a).normalized()
		# The box length is local Y; scale its basis columns along the curved limb.
		var basis := Basis(Vector3.RIGHT * size.x, along * size.y, Vector3.RIGHT.cross(along) * size.z)
		tool.append_from(unit, 0, Transform3D(basis, (a + b) * 0.5))
		placed += 1
	if placed == 0: return null
	tool.generate_normals()
	return tool.commit()

## Point on a limb at `s` (0 at the riser, 1 at the tip). The limb bows away from
## the archer and then curves back, which is what makes it a recurve.
func _limb_point(s: float, side: float) -> Vector3:
	var y := side * lerpf(0.17, 0.66, s)
	var z := 0.10 + 0.13 * sin(PI * s) - 0.045 * s
	return Vector3(0.0, y, z)

## Rotation that lays a box's long (Y) axis along `direction`.
func _rotation_along(direction: Vector3) -> Vector3:
	var dir := direction.normalized()
	var yaw := atan2(dir.x, dir.z)
	var pitch := -asin(clampf(dir.y, -1.0, 1.0))
	return Vector3(pitch, yaw, 0.0)

func _make_string(parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.007, 0.007, 1.0)
	node.mesh = box
	node.material_override = _string_material
	parent.add_child(node)
	return node

## Stretches a unit-length box between two GLOBAL points.
func _stretch(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var span := b - a
	var length := span.length()
	if length < 1.0e-5:
		node.visible = false
		return
	node.visible = true
	node.global_position = (a + b) * 0.5
	node.scale = Vector3(1.0, 1.0, length)
	node.look_at(b, Vector3.UP, true)

func _build_aim_dots() -> void:
	_aim_dot_mesh = SphereMesh.new()
	_aim_dot_mesh.radius = 0.022
	_aim_dot_mesh.height = 0.044
	_aim_material = StandardMaterial3D.new()
	_aim_material.albedo_color = Color(0.95, 0.95, 0.98)
	_aim_material.emission_enabled = true
	_aim_material.emission = Color(0.55, 0.62, 0.75)
	_aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i: int in MAX_AIM_DOTS:
		var dot := MeshInstance3D.new()
		dot.mesh = _aim_dot_mesh
		dot.material_override = _aim_material
		# The trajectory is an aiming aid, so it must not draw a second dotted
		# path as shadows on the ground or the target behind it.
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.visible = false
		_world.add_child(dot)
		_aim_dots.append(dot)

func _build_hint() -> void:
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 30
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
	_hint.add_theme_color_override("font_color", Color(0.80, 0.94, 1.0))
	panel.add_child(_hint)
	_hint_layer.add_child(panel)
	_hint_layer.visible = false
	_update_hint()

func _update_hint() -> void:
	if not is_instance_valid(_hint): return
	var quiver := "колчан на спине" if _quiver_worn else "КОЛЧАНА НЕТ — стрел 0"
	var state := "СТРЕЛ %d / %d   (%s)" % [_arrows_left, ARROWS_PER_QUIVER, quiver]
	if _nocked:
		state += "   стрела на тетиве"
	elif _fetch_phase != "":
		state += "   достаёт стрелу из колчана"
	var draw := ""
	if _drawing:
		draw = "\nНАТЯЖЕНИЕ %d%%   ЛКМ — выстрел от 18%% натяжения" % int(round(_draw_amount * 100.0))
	var pick := ""
	var near := _nearest_ground_item()
	if not near.is_empty():
		pick = "\nE — поднять " + ("лук" if str(near.get("kind", "")) == "bow" else "колчан")
	_hint.text = state + "\nПКМ — прицел и натяжение · ЛКМ — выстрел\nG — бросить" + pick + draw

# ---------------------------------------------------------------- archer pose

## The real shoulder joint of the bow arm, in world space.
func _bow_shoulder() -> Vector3:
	if not is_instance_valid(_rig) or _bone_bow_clavicle < 0:
		return _player.global_position + Vector3.UP * 1.42
	return (_rig.global_transform * _chain_global(_bone_bow_clavicle) * _rest_bow_upper).origin

## The drawing shoulder joint, in world space.
func _draw_shoulder() -> Vector3:
	if not is_instance_valid(_rig) or _bone_draw_clavicle < 0:
		return _player.global_position + Vector3.UP * 1.42
	return (_rig.global_transform * _chain_global(_bone_draw_clavicle) * _rest_draw_upper).origin

## How long each arm actually is, in metres. Every hand target is a FRACTION of this:
## asking for a point beyond the arm's length is what left the hands 0.14 m and 0.38 m
## short of where the pose wanted them, with both arms stretched straight.
func _arm_length() -> float:
	var scale := _rig.global_transform.basis.get_scale().y if is_instance_valid(_rig) else 0.38
	if scale <= 1.0e-5: scale = 0.38
	var bones := _rest_bow_fore.origin.length() + _rest_bow_hand.origin.length()
	if bones <= 0.01: return 0.55
	return bones * scale

## Where the bow hand holds the grip: out in front of the bow shoulder, a little
## below it and a little to the bow side, at a reachable fraction of the arm.
func _bow_hand_point() -> Vector3:
	var arm := _arm_length()
	return _bow_shoulder() \
		+ _aim_direction() * (arm * 0.74) \
		- Vector3.UP * (arm * 0.07) \
		- _draw_side() * (arm * 0.13)

func _aim_direction() -> Vector3:
	if not is_instance_valid(_camera): return Vector3.FORWARD
	var raw: Vector3 = -_camera.global_basis.z.normalized()
	if not is_instance_valid(_player) or not is_instance_valid(_player._visual): return raw
	var frame: int = Engine.get_process_frames()
	var visual: Node3D = _player._visual
	if frame == _aim_frame and _aim_camera_transform.is_equal_approx(_camera.global_transform) \
			and _aim_visual_transform.is_equal_approx(visual.global_transform):
		return _frame_aim_direction
	var sight_direction: Vector3 = raw
	if _show_aim():
		# The shoulder camera is lateral to the bow. Converge the shot on its
		# central sight ray. Cache the world hit for all pose and preview calls in
		# this frame; the bow is asked for its direction many times per frame.
		if frame != _sight_frame or not _sight_camera.is_equal_approx(_camera.global_transform):
			var sight_from: Vector3 = _camera.global_position
			var sight_hit: Dictionary = _arrow_ray31(sight_from, sight_from + raw * 100.0)
			_sight_point = sight_hit.position if not sight_hit.is_empty() else sight_from + raw * 100.0
			_sight_frame = frame
			_sight_camera = _camera.global_transform
		# Converge from the actual nock height. The former fixed shoulder point sat
		# over half a metre above the arrow and drove nearby shots into the floor.
		var launch_from: Vector3 = _string_nock_point(raw) + raw * 0.37
		sight_direction = (_sight_point - launch_from).normalized()
	# Keep the hands in the body's forward arc while the torso catches the camera.
	# Bow, displayed arrow, trajectory and fired projectile all use this direction.
	var basis: Basis = _player._visual.global_basis.orthonormalized()
	var local: Vector3 = basis.inverse() * sight_direction
	var yaw := clampf(atan2(local.x, local.z), -deg_to_rad(65.0), deg_to_rad(65.0))
	var pitch := clampf(asin(clampf(local.y, -1.0, 1.0)), -PI * 0.46, PI * 0.46)
	_frame_aim_direction = (basis * Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))).normalized()
	_aim_frame = frame
	_aim_camera_transform = _camera.global_transform
	_aim_visual_transform = visual.global_transform
	return _frame_aim_direction

func _active() -> bool:
	if not _ready or not is_instance_valid(_player): return false
	# The prototype must stand down while the arsenal menu is open - and that method
	# lives on the weapons host, not on the player, which is where it was being
	# asked for before.
	if is_instance_valid(_weapons_host) and _weapons_host.has_method("controls_blocked") \
			and bool(_weapons_host.call("controls_blocked")):
		return false
	# The bow must NOT consume the mouse while the cursor is free: the ordinary
	# player code re-captures the mouse on a left click, and eating that click is
	# what stopped the character from walking. Same rule as the sword prototype.
	if not bool(_player.get("_free_mouse_look")): return false
	if _player.get("_pose_authority") != &"on_foot": return false
	if is_instance_valid(_world):
		if bool(_world.get("preview_dead")) or bool(_world.get("preview_physics_fault")): return false
	return _selected

func set_selected(value: bool) -> void:
	if _selected == value: return
	_selected = value
	if is_instance_valid(_bow): _bow.visible = value or _grounded or _stowed_on_back31
	if is_instance_valid(_hint_layer): _hint_layer.visible = value
	if not value:
		_aiming = false
		_fire_button_down = false
		_drawing = false
		_draw_amount = 0.0
		_hide_aim()
		_restore_zoom()
	_update_hint()

var _stowed_on_back31 := false

func set_stowed_on_back31(stowed: bool) -> void:
	_stowed_on_back31 = stowed
	if is_instance_valid(_bow): _bow.visible = stowed or _selected or _grounded
	if is_instance_valid(_quiver): _quiver.visible = stowed and _quiver_worn or _selected and _quiver_worn

func _place_back_equipment31() -> void:
	if not _stowed_on_back31 or not is_instance_valid(_player): return
	var visual: Node3D = _player._visual
	var back: Vector3 = visual.global_basis.z
	if is_instance_valid(_bow) and not _grounded:
		_bow.visible = true
		_bow.global_transform = Transform3D(visual.global_basis * Basis(Vector3.FORWARD, 0.22),
			_player.global_position + Vector3.UP * 1.15 + back * 0.29 + visual.global_basis.x * 0.13)
	if _quiver_worn: _place_quiver()

func is_drawing() -> bool:
	return _drawing

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not _active(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_set_aiming(event.pressed)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _fire_button_down: _loose()
		_fire_button_down = event.pressed
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_G:
			# The castle inventory owns carried gear and its physical floor item.
			# Keep its carried slots and visible bow in the same transaction.
			var storage: Node = _weapons_host.get('castle_storage_owner') if is_instance_valid(_weapons_host) else null
			if is_instance_valid(storage) and bool(storage.snapshot().get('carried', {}).get('bow', false)):
				if bool(storage.drop_held(false).get('ok', false)):
					get_viewport().set_input_as_handled()
				return
			# Outside castle storage, the prototype still drops its own bow.
			# First the bow goes down, then the quiver comes off the back.
			if drop_bow_to_ground():
				get_viewport().set_input_as_handled()
				return
			if drop_quiver_to_ground():
				get_viewport().set_input_as_handled()
				return
		if code == KEY_E and try_pickup_ground():
			get_viewport().set_input_as_handled()
			return

func _begin_draw() -> void:
	if not _aiming or _drawing or Time.get_ticks_msec() < _lock_until_ms: return
	if _arrows_left <= 0: return
	_ensure_nocked()
	_drawing = true
	_draw_amount = 0.0
	_update_hint()

func _set_aiming(value: bool) -> void:
	_aiming = value
	if value:
		_begin_draw()
	else:
		_drawing = false
		_draw_amount = 0.0
		_hide_aim()
		_restore_zoom()
	_update_hint()

func ready_to_fire() -> bool:
	return _active() and not _grounded and _aiming and _drawing and _nocked and _fetch_phase == "" and _draw_amount >= MIN_RELEASE_DRAW31 and _arrows_left > 0 and Time.get_ticks_msec() >= _lock_until_ms

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_fire_button_down = false
		if _ready: _set_aiming(false)

## Releases the string: the arrow leaves with the speed the draw earned.
func _loose() -> void:
	# Only a new left press while the right button is aiming fires a ready arrow.
	# Early clicks and cancellation consume nothing and queue no surprise shot.
	if not ready_to_fire(): return
	var shots_before := _shots
	_fire(_draw_amount)
	if _shots == shots_before: return
	_draw_amount = 0.0
	_nocked = false
	_drawing = false
	_lock_until_ms = Time.get_ticks_msec() + 350
	_update_hint()

# ---------------------------------------------------------------- firing

const MIN_RELEASE_DRAW31 := 0.18

func launch_speed(power: float) -> float:
	return lerpf(ARROW_SPEED_MIN, ARROW_SPEED_MAX, clampf(power, 0.0, 1.0))

func _muzzle_point() -> Vector3:
	var aim := _aim_direction()
	return _string_nock_point(aim) + aim * 0.37

func _fire(power: float) -> void:
	var aim := _aim_direction()
	var speed := launch_speed(power)
	var from := _muzzle_point()
	var arrow := _take_arrow()
	if arrow == null: return
	_arrows_left = maxi(0, _arrows_left - 1)
	arrow.visible = true
	arrow.global_transform = _basis_z_along(from, aim)
	_arrows.append({
		"node": arrow, "velocity": aim * speed, "prev": from,
		"prev_tip": from + aim * ARROW_TIP_OFFSET31,
		"alive": true, "stuck": false, "age": 0.0,
		"fired_ms": Time.get_ticks_msec(),
	})
	_last_fired_index = _arrows.size() - 1
	_shots += 1
	_impact_sound(from)
	# The tip must not spawn beyond a nearby wall. Check from the actual bow grip.
	var hit := _arrow_ray31(_launch_guard_point31(), from + aim * ARROW_TIP_OFFSET31)
	if not hit.is_empty():
		_stick(_last_fired_index, hit, aim * speed, speed)
	else:
		_start_arrow_flight31(arrow)

## Index of the arrow most recently loosed, so a test can follow that one.
var _last_fired_index := -1

func last_fired_index() -> int:
	return _last_fired_index

func _take_arrow() -> Node3D:
	# Remove an old record BEFORE _fire registers the reused node, or two records
	# would integrate the same arrow every tick. Embedded arrows persist until cap.
	for index: int in range(_arrows.size() - 1, -1, -1):
		var entry: Dictionary = _arrows[index]
		var node: Variant = entry.get("node")
		if not is_instance_valid(node):
			_arrows.remove_at(index)
		elif not bool(entry.get("alive", false)):
			_arrows.remove_at(index)
			if node.get_parent() != _world: node.reparent(_world, true)
			return node
	if _arrows.size() < MAX_ARROWS: return _build_arrow(_world)
	for index: int in _arrows.size():
		var entry: Dictionary = _arrows[index]
		if not bool(entry.get("stuck", false)): continue
		var node: Variant = entry.get("node")
		if not is_instance_valid(node): continue
		_stop_arrow_flight31(node)
		if node.get_parent() != _world: node.reparent(_world, true)
		_arrows.remove_at(index)
		return node
	return null

## A real arrow: a tapered shaft, a steel bodkin point, a nock and three vanes set
## at an angle so the arrow would spin in flight.
func _build_arrow(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "PrototypeArrow"
	parent.add_child(root)
	# Each arrow reuses the same four finished material meshes.
	if not _arrow_visual_parts31.is_empty():
		for spec: Dictionary in _arrow_visual_parts31:
			var part := MeshInstance3D.new()
			part.mesh = spec.mesh
			part.material_override = spec.material
			root.add_child(part)
		return root
	var shaft := MeshInstance3D.new()
	shaft.mesh = _shaft_mesh
	shaft.material_override = _wood_light
	# A cylinder runs along Y; the arrow flies along Z.
	shaft.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	head.mesh = _head_mesh
	head.material_override = _steel
	head.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	head.position = Vector3(0.0, 0.0, 0.395)
	root.add_child(head)
	var collar := MeshInstance3D.new()
	collar.mesh = _collar_mesh
	collar.material_override = _horn
	collar.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	collar.position = Vector3(0.0, 0.0, 0.345)
	root.add_child(collar)
	var nock := MeshInstance3D.new()
	nock.mesh = _nock_mesh
	nock.material_override = _horn
	nock.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	nock.position = Vector3(0.0, 0.0, -0.368)
	root.add_child(nock)
	for i: int in 3:
		var vane := MeshInstance3D.new()
		vane.mesh = _vane_mesh
		vane.material_override = _feather
		var angle := TAU * float(i) / 3.0
		vane.position = Vector3(cos(angle) * 0.0185, sin(angle) * 0.0185, -0.295)
		# Set at a few degrees of helix, which is what steers a real arrow.
		vane.rotation = Vector3(deg_to_rad(6.0), 0.0, angle - PI * 0.5)
		root.add_child(vane)
	ModelFinish31.finish(root)
	for child: MeshInstance3D in root.get_children():
		_arrow_visual_parts31.append({"mesh":child.mesh,"material":child.material_override})
	return root

## The quiver: a leather tube with a stitched rim and a shoulder strap, plus the
## shafts of the arrows still in it. It hangs on the archer's back.
func _build_quiver(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "PrototypeQuiver"
	parent.add_child(root)
	root.visible = false
	var body := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.062
	tube.bottom_radius = 0.052
	tube.height = 0.56
	tube.radial_segments = 12
	tube.cap_top = false
	body.mesh = tube
	body.material_override = _leather
	root.add_child(body)
	var rim := MeshInstance3D.new()
	var rim_tube := TorusMesh.new()
	rim_tube.inner_radius = 0.055
	rim_tube.outer_radius = 0.070
	rim_tube.rings = 16
	rim_tube.ring_segments = 6
	rim.mesh = rim_tube
	rim.material_override = _horn
	rim.position = Vector3(0.0, 0.27, 0.0)
	root.add_child(rim)
	var base := MeshInstance3D.new()
	var base_tube := CylinderMesh.new()
	base_tube.top_radius = 0.055
	base_tube.bottom_radius = 0.048
	base_tube.height = 0.040
	base.mesh = base_tube
	base.material_override = _wood_dark
	base.position = Vector3(0.0, -0.28, 0.0)
	root.add_child(base)
	# Strap across the body.
	var strap := MeshInstance3D.new()
	var strap_box := BoxMesh.new()
	strap_box.size = Vector3(0.030, 0.62, 0.012)
	strap.mesh = strap_box
	strap.material_override = _leather
	strap.position = Vector3(-0.055, 0.02, -0.045)
	strap.rotation = Vector3(0.0, 0.0, deg_to_rad(18.0))
	root.add_child(strap)
	# The arrows still in the quiver: a bundle of shafts and fletchings. A MultiMesh
	# draws all twenty in one node, and `visible_instance_count` is the quiver's
	# count, so the arrows thin out as they are spent at almost no cost.
	var shaft_multi := MultiMesh.new()
	shaft_multi.transform_format = MultiMesh.TRANSFORM_3D
	shaft_multi.mesh = _quiver_shaft_mesh
	shaft_multi.instance_count = ARROWS_PER_QUIVER
	shaft_multi.visible_instance_count = ARROWS_PER_QUIVER
	var fletch_multi := MultiMesh.new()
	fletch_multi.transform_format = MultiMesh.TRANSFORM_3D
	fletch_multi.mesh = _quiver_fletch_mesh
	fletch_multi.instance_count = ARROWS_PER_QUIVER
	fletch_multi.visible_instance_count = ARROWS_PER_QUIVER
	for i: int in ARROWS_PER_QUIVER:
		var angle := TAU * float(i) / float(ARROWS_PER_QUIVER)
		var radius := 0.030 * sqrt(float(i) / float(ARROWS_PER_QUIVER))
		var lean := deg_to_rad(4.0)
		var at := Vector3(cos(angle) * radius, 0.30, sin(angle) * radius)
		var lean_basis := Basis.from_euler(Vector3(cos(angle) * lean, 0.0, -sin(angle) * lean))
		shaft_multi.set_instance_transform(i, Transform3D(lean_basis, at))
		fletch_multi.set_instance_transform(i,
			Transform3D(Basis.from_euler(Vector3(0.0, 0.0, angle)), Vector3(cos(angle) * radius, 0.44, sin(angle) * radius)))
	var shafts_node := MultiMeshInstance3D.new()
	shafts_node.multimesh = shaft_multi
	shafts_node.material_override = _wood_light
	root.add_child(shafts_node)
	var fletch_node := MultiMeshInstance3D.new()
	fletch_node.multimesh = fletch_multi
	fletch_node.material_override = _feather
	root.add_child(fletch_node)
	root.set_meta("shaft_multimesh", shaft_multi)
	root.set_meta("fletch_multimesh", fletch_multi)
	ModelFinish31.finish(root)
	return root

## The quiver's count is the number of instances it draws: no per-arrow nodes, no
## per-arrow visibility bookkeeping.
func _show_quiver_arrows(root: Node3D, shown: int) -> void:
	if not is_instance_valid(root): return
	var count := clampi(shown, 0, ARROWS_PER_QUIVER)
	for key: String in ["shaft_multimesh", "fletch_multimesh"]:
		var multi: Variant = root.get_meta(key, null)
		if multi is MultiMesh:
			(multi as MultiMesh).visible_instance_count = count

## Hangs the quiver off the archer's chest bone, tilted across his back. Setting the
## transform every frame keeps it on the body without an attachment node.
func _place_quiver() -> void:
	if not is_instance_valid(_quiver): return
	if not _quiver_worn:
		_quiver.visible = false
		return
	_quiver.visible = true
	var anchor: Transform3D = _rig.global_transform
	if _bone_chest >= 0:
		anchor = _rig.global_transform * _chain_global(_bone_chest)
	var visual: Node3D = _player._visual
	var back: Vector3 = visual.global_basis.z
	# Behind the back but TOWARD THE DRAWING SIDE, and laid ALONG the back rather
	# than pushed out from it. The offsets are small on purpose: the tube has to sit
	# against the spine, and a quiver standing off the back is what the player saw.
	var origin: Vector3 = anchor.origin - back * 0.125 + _draw_side() * 0.115 + Vector3.UP * 0.02
	var basis := Basis(visual.global_basis.x, Vector3.UP, back) * Basis(Vector3.RIGHT, deg_to_rad(-34.0)) * Basis(Vector3.UP, deg_to_rad(16.0))
	_quiver.global_transform = Transform3D(basis.orthonormalized(), origin)
	_quiver_mouth = _quiver.global_transform * Vector3(0.0, 0.30, 0.0)
	_show_quiver_arrows(_quiver, clampi(_arrows_left, 0, ARROWS_PER_QUIVER))

## Nearest bow or quiver lying on the ground within reach.
func _nearest_ground_item() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := GROUND_REACH
	for index: int in range(_ground_items.size() - 1, -1, -1):
		var entry: Dictionary = _ground_items[index]
		var node: Variant = entry.get("node")
		if not is_instance_valid(node):
			_ground_items.remove_at(index)
			continue
		var distance: float = _player.global_position.distance_to(node.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = entry
	return best

## G: put the bow down. Once it is down, G takes the quiver off the back instead.
func _drop_floor(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at - Vector3.UP * 3.0, 1, [_player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else at

func drop_bow_to_ground() -> bool:
	if not _selected or _grounded or not is_instance_valid(_bow): return false
	_grounded = true
	_drawing = false
	_draw_amount = 0.0
	_nocked = false
	_fetch_phase = ""
	_hide_aim()
	_restore_zoom()
	var forward := _flat_forward()
	var at: Vector3 = _player.global_position + forward * 0.72
	_bow.visible = true
	# Lying flat: the bow's own long axis along the ground.
	var flat_basis: Basis = _basis_z_along(at, forward).basis * Basis(Vector3.RIGHT, PI * 0.5)
	_bow.global_transform = ModelFinish31.resting_transform(_bow, flat_basis, _drop_floor(at))
	_ground_items.append({"kind": "bow", "node": _bow})
	_update_hint()
	print("DSH_BOW_PROTO_DROPPED at=", at)
	return true

## G again: the quiver comes off the back with whatever arrows are left in it.
func drop_quiver_to_ground() -> bool:
	if not _quiver_worn or not is_instance_valid(_ground_quiver): return false
	_quiver_worn = false
	_quiver.visible = false
	var forward := _flat_forward()
	var visual: Node3D = _player._visual
	var at: Vector3 = _player.global_position + forward * 0.58 + visual.global_basis.x * (0.34 * _left_sign)
	_ground_quiver.visible = true
	_ground_quiver.global_transform = ModelFinish31.resting_transform(_ground_quiver, Basis(Vector3.RIGHT, PI * 0.5), _drop_floor(at))
	var carried_arrows := _arrows_left
	_show_quiver_arrows(_ground_quiver, clampi(carried_arrows, 0, ARROWS_PER_QUIVER))
	# The arrows go with the quiver: with it off his back the bow has none.
	_ground_items.append({"kind": "quiver", "node": _ground_quiver, "arrows": carried_arrows})
	_arrows_left = 0
	_nocked = false
	_fetch_phase = ""
	_update_hint()
	print("DSH_BOW_PROTO_QUIVER_DROPPED at=", at, " arrows_gone_with_it=", carried_arrows)
	return true

## E: take the nearest bow or quiver. A bow already in hand cannot be swapped, but
## a quiver is ammunition and can always be taken.
func try_pickup_ground() -> bool:
	var found := _nearest_ground_item()
	if found.is_empty(): return false
	var kind := str(found.get("kind", ""))
	var node: Node3D = found.get("node")
	if kind == "bow":
		if not _grounded: return false
		_grounded = false
		_ground_items.erase(found)
		_lock_until_ms = Time.get_ticks_msec() + 450
		_update_hint()
		print("DSH_BOW_PROTO_PICKED kind=bow")
		return true
	if kind == "quiver":
		var carried := int(found.get("arrows", 0))
		_ground_items.erase(found)
		if is_instance_valid(node): node.visible = false
		_quiver_worn = true
		_arrows_left = maxi(_arrows_left, carried)
		_update_hint()
		print("DSH_BOW_PROTO_PICKED kind=quiver arrows=", _arrows_left)
		return true
	return false

func _flat_forward() -> Vector3:
	var visual: Node3D = _player._visual
	var forward: Vector3 = visual.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 1.0e-6: return Vector3.FORWARD
	return forward.normalized()

# ---------------------------------------------------------------- flight

func _physics_process(delta: float) -> void:
	if not _ready or not is_instance_valid(_player): return
	if _active() and not _grounded:
		if _aiming and not _drawing: _begin_draw()
		if _drawing and _nocked and _fetch_phase == "":
			_draw_amount = clampf(_draw_amount + delta / DRAW_TIME, 0.0, 1.0)
	elif _aiming or _drawing:
		_set_aiming(false)
	_step_arrows(delta)

func _step_arrows(delta: float) -> void:
	if delta <= 0.0 or _arrows.is_empty(): return
	for index: int in range(_arrows.size() - 1, -1, -1):
		var entry: Dictionary = _arrows[index]
		var node: Variant = entry.get("node")
		if not is_instance_valid(node):
			_arrows.remove_at(index)
			continue
		if not bool(entry.get("alive", false)): continue
		if bool(entry.get("stuck", false)):
			_follow_severed_arrow31(index, entry, node)
			continue
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		var from: Vector3 = entry.get("prev", node.global_position)
		var from_tip: Vector3 = entry.get("prev_tip", from + velocity.normalized() * ARROW_TIP_OFFSET31)
		# Exact constant-gravity step; the preview uses this same equation.
		var to := _ballistic_point31(from, velocity, delta)
		var next_velocity := velocity + Vector3.DOWN * GRAVITY * delta
		var to_tip := to + next_velocity.normalized() * ARROW_TIP_OFFSET31
		var incoming: bool = bool(entry.get("incoming", false))
		var hit := _incoming_arrow_ray31(from_tip, to_tip, entry) if incoming else _arrow_ray31(from_tip, to_tip)
		entry["velocity"] = next_velocity
		entry["prev"] = to
		entry["prev_tip"] = to_tip
		entry["age"] = float(entry.get("age", 0.0)) + delta
		_arrows[index] = entry
		if incoming and is_instance_valid(_sword_host) and _sword_host.has_method("incoming_arrow_parry31"):
			var sweep_end: Vector3 = hit.position if not hit.is_empty() else to_tip
			var contact: Dictionary = _sword_host.call("incoming_arrow_parry31", from_tip, sweep_end)
			if not contact.is_empty():
				_deflect_incoming_arrow31(index, contact, next_velocity)
				continue
		if not hit.is_empty():
			if incoming and hit.get("collider") == _player and is_instance_valid(_sword_host) \
					and _sword_host.has_method("_apply_player_arrow_damage31"):
				_incoming_player_hits31 += 1
				var impact_damage := ARROW_DAMAGE * pow(clampf(next_velocity.length() / ARROW_SPEED_MAX, 0.0, 1.0), 2.0)
				_sword_host.call("_apply_player_arrow_damage31", impact_damage, hit.position, next_velocity.normalized())
			_stick(index, hit, next_velocity, next_velocity.length())
			continue
		node.global_transform = _basis_z_along(to, next_velocity)
		_update_arrow_flight31(node, next_velocity.length())
		if to.y < _player.global_position.y - 60.0 or float(entry["age"]) > 15.0:
			_recycle(index)

func _incoming_arrow_ray31(from: Vector3, to: Vector3, entry: Dictionary) -> Dictionary:
	var excluded: Array[RID] = []
	var shooter_rid: RID = entry.get("shooter_rid", RID())
	if shooter_rid.is_valid(): excluded.append(shooter_rid)
	var query := PhysicsRayQueryParameters3D.create(from, to, AIM_MASK | 2, excluded)
	query.hit_from_inside = true
	return _player.get_world_3d().direct_space_state.intersect_ray(query)

func _deflect_incoming_arrow31(index: int, contact: Dictionary, velocity: Vector3) -> void:
	var entry: Dictionary = _arrows[index]
	var node: Variant = entry.get("node")
	var blade_axis: Vector3 = contact.axis
	var across: Vector3 = velocity - blade_axis * velocity.dot(blade_axis)
	var reflected: Vector3 = velocity.bounce(across.normalized()) if across.length_squared() > 0.000001 else -velocity
	reflected = reflected.normalized() * velocity.length() * 0.55
	var at: Vector3 = contact.point
	var origin: Vector3 = at - reflected.normalized() * ARROW_TIP_OFFSET31
	entry["velocity"] = reflected
	entry["prev"] = origin
	entry["prev_tip"] = at
	entry["incoming"] = false
	entry["deflected"] = true
	_arrows[index] = entry
	node.global_transform = _basis_z_along(origin, reflected)
	_incoming_parries31 += 1
	_sword_host.call("register_arrow_parry31", at)
	_start_arrow_flight31(node)

## An arrow that hit something stays there, and rides along if the thing moves.
func _stick(index: int, hit: Dictionary, velocity: Vector3, speed: float) -> void:
	var entry: Dictionary = _arrows[index]
	var node: Variant = entry.get("node")
	if not is_instance_valid(node) or bool(entry.get("stuck", false)): return
	var point: Vector3 = hit.get("position", node.global_position)
	var collider: Variant = hit.get("collider")
	var direction := velocity.normalized()
	var surface := _arrow_surface31(collider)
	var embed := 0.07 if surface == "wood" else (0.10 if surface in ["dirt", "flesh"] else 0.015)
	var rest := point - direction * (ARROW_TIP_OFFSET31 - embed)
	node.global_transform = _basis_z_along(rest, direction)
	node.visible = true
	_stop_arrow_flight31(node)
	# Keep the entire world transform on reparent. This also supports doors,
	# movable props and physical rubble, not only the old NPC special case.
	if is_instance_valid(collider) and collider is Node3D and not collider.is_queued_for_deletion():
		node.reparent(collider, true)
	entry["stuck"] = true
	entry["alive"] = true
	entry["velocity"] = Vector3.ZERO
	entry["surface"] = surface
	entry["hit_point"] = point
	if is_instance_valid(collider) and collider.has_meta("sword_npc_part"):
		entry["npc_part"] = str(collider.get_meta("sword_npc_part"))
		entry["npc_debris_start"] = (_sword_host.get("_npc_debris") as Array).size() if is_instance_valid(_sword_host) else 0
	_arrows[index] = entry
	_stuck_total += 1
	_last_hit_distance = _player.global_position.distance_to(point)
	_last_flight_time = float(entry.get("age", 0.0))
	_last_arrow_surface31 = surface
	_play_arrow_impact31(point, surface, speed)
	_apply_arrow_damage(collider, point, speed, direction, hit.get("normal", Vector3.ZERO))
	print("DSH_BOW_PROTO_STICK at=", point, " speed=", speed, " surface=", surface)

func _follow_severed_arrow31(index: int, entry: Dictionary, node: Node3D) -> void:
	var part: String = entry.get("npc_part", "")
	if part == "" or not is_instance_valid(_sword_host): return
	var severed: Dictionary = _sword_host.get("_npc_severed")
	if not severed.has(part): return
	var debris: Array = _sword_host.get("_npc_debris")
	var best: RigidBody3D = null
	var best_distance := 1.2
	for i in range(int(entry.get("npc_debris_start", 0)), debris.size()):
		var candidate: RigidBody3D = (debris[i] as Dictionary).get("node")
		if not is_instance_valid(candidate): continue
		var distance := candidate.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	if best == null: return
	node.reparent(best, true)
	entry["npc_part"] = ""
	_arrows[index] = entry

## An arrow in a body does damage through the sword prototype's own gore system, so
## arrow wounds and sword wounds are the same wounds.
func _apply_arrow_damage(collider: Variant, point: Vector3, speed: float, direction: Vector3, normal: Vector3 = Vector3.ZERO) -> void:
	if is_instance_valid(collider) and collider is Node and collider.has_method("take_arrow_hit"):
		collider.call("take_arrow_hit", point, speed, direction, normal)
		return
	if not is_instance_valid(collider) or not is_instance_valid(_sword_host): return
	var part := ""
	if collider is Node and collider.has_meta("sword_npc_part"):
		part = str(collider.get_meta("sword_npc_part"))
	if part != "" and _sword_host.has_method("_npc_take_arrow_part"):
		var impact_damage := ARROW_DAMAGE * pow(clampf(speed / ARROW_SPEED_MAX, 0.0, 1.0), 2.0)
		_sword_host.call("_npc_take_arrow_part", part, point, speed, direction, impact_damage, normal)
		return
	if collider is Node and collider.has_meta("sword_target") and _sword_host.has_method("_damage_dummy"):
		_sword_host.call("_damage_dummy", collider, point, speed, direction, Time.get_ticks_msec())

func _recycle(index: int) -> void:
	var entry: Dictionary = _arrows[index]
	var node: Variant = entry.get("node")
	if is_instance_valid(node):
		_stop_arrow_flight31(node)
		if node.get_parent() != _world: node.reparent(_world, true)
		node.visible = false
	entry["alive"] = false
	entry["stuck"] = false
	entry["velocity"] = Vector3.ZERO
	_arrows[index] = entry

# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	if not _ready or not is_instance_valid(_player) or not is_instance_valid(_rig): return
	# The WAIT state is reported periodically so a live session can be diagnosed from
	# its log without guessing which branch of _process is being taken.
	_debug_tick += 1
	if not _active():
		if is_instance_valid(_bow): _bow.visible = _grounded or _stowed_on_back31
		if is_instance_valid(_quiver): _quiver.visible = _stowed_on_back31 and _quiver_worn
		_place_back_equipment31()
		_hide_aim()
		_restore_zoom()
		return
	# NOTE: arrows are stepped ONLY in _physics_process. Stepping them here as well
	# applied gravity twice and made every arrow fall about 1.8 times too fast.
	if _grounded:
		# The bow lies where it was put down; the hands are the player's again.
		_hide_aim()
		_restore_zoom()
		_update_hint()
		return
	if is_instance_valid(_bow): _bow.visible = true
	# Face the shot before posing: every hand target below is built from the camera.
	_face_the_aim(delta)
	_pose_archer(delta)
	_place_bow()
	_place_quiver()
	_update_aim_preview()
	_update_zoom(delta)
	_update_hint()
	_cache_pose_metrics()
	# Reported AFTER the pose and the bow placement, so the numbers describe the
	# frame that is actually drawn instead of the state left by the physics step.
	_debug_tick += 1
	if _debug_tick % 240 == 0:
		print("DSH_BOW_PROTO_TICK selected=", _selected, " drawing=", _drawing,
			" draw=", _draw_amount, " nocked=", _nocked, " quiver=", _quiver_worn,
			" arrows=", _arrows_left, " bow_visible=", is_instance_valid(_bow) and _bow.visible,
			" bow_in_hand_error=", _bow_hand_error(),
			" quiver_offset_m=", quiver_offset_m())

## Aim zoom: the view tightens as the string comes back, and opens again on release.
## The field of view belongs to the shared aim camera, so the bow asks it for a
## scale instead of writing `fov` and being overwritten every frame.
func _update_zoom(delta: float) -> void:
	_zoom_scale = lerpf(_zoom_scale, ZOOM_FACTOR if _show_aim() else 1.0, clampf(ZOOM_RATE * delta, 0.0, 1.0))
	var aim_camera: Variant = _aim_camera()
	if aim_camera != null:
		aim_camera.set("bow_aim_active", _show_aim())
		aim_camera.set("zoom_scale", _zoom_scale)

func _aim_camera() -> Variant:
	if is_instance_valid(_weapons_host): return _weapons_host.get("aim_camera")
	return null

func _restore_zoom() -> void:
	_zoom_scale = 1.0
	var aim_camera: Variant = _aim_camera()
	if aim_camera != null:
		aim_camera.set("bow_aim_active", false)
		aim_camera.set("zoom_scale", 1.0)

## The archer must FACE where he shoots. The bow is placed along the CAMERA, so
## without this the body keeps whatever facing it had, the bow is thrown out to his
## side, and the string reads as passing through his back with the hands hidden.
func owns_player_facing() -> bool:
	return _ready and _active() and not _grounded

func _face_the_aim(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_camera): return
	var visual: Node3D = _player._visual
	if not is_instance_valid(visual): return
	var aim: Vector3 = -_camera.global_basis.z.normalized()
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length_squared() < 1.0e-6: return
	# The model faces along its own +Z, so its yaw is atan2(x, z).
	var want := atan2(flat.x, flat.z) - _player.global_rotation.y
	visual.rotation.y += wrapf(want - visual.rotation.y, -PI, PI) * clampf(FACE_RATE * delta, 0.0, 1.0)
	# Hand back the actual facing when dropping/switching; no stale travel heading.
	_player._heading = visual.rotation.y - deg_to_rad(_player.visual_yaw_degrees)

## How fast the body swings round to face the shot.
const FACE_RATE := 9.0

## Two-bone IK on both arms, so no bone is ever written without a reason.
func _pose_archer(delta: float) -> void:
	var bow_point := _bow_hand_point()
	_pose_arm(_bone_bow_clavicle, _bone_bow_upper, _bone_bow_fore, _bone_bow_hand,
		_rest_bow_upper, _rest_bow_fore, _rest_bow_hand, bow_point, _left_sign)
	_string_target_world = _constrain_hand_path(_draw_hand_point(delta))
	_pose_arm(_bone_draw_clavicle, _bone_draw_upper, _bone_draw_fore, _bone_draw_hand,
		_rest_draw_upper, _rest_draw_fore, _rest_draw_hand, _string_target_world, -_left_sign)
	_rig.force_update_all_bone_transforms()
	_string_hand_world = _hand_palm(_bone_draw_hand)

func _hand_offset(hand: int) -> Vector3:
	var name := "socket_hand_l" if hand == _bone_draw_hand else "socket_hand_r"
	var socket := _rig.find_bone(name)
	return _rig.get_bone_rest(socket).origin if socket >= 0 else Vector3.ZERO

func _hand_palm(hand: int) -> Vector3:
	return _rig.global_transform * (_rig.get_bone_global_pose(hand) * _hand_offset(hand))

## Keeps the drawing hand OUT of the archer's own body. Whatever the fetch or the
## draw asks for, the hand target is pushed out of a cylinder around his spine, so
## the arm can never be posed through his chest or back.
func _constrain_hand_path(point: Vector3) -> Vector3:
	var centre: Vector3 = _player.global_position
	if _fetch_phase == "":
		var forward: Vector3 = _player._visual.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		point += forward * maxf(0.0, 0.10 - (point - centre).dot(forward))
	var flat := Vector3(point.x - centre.x, 0.0, point.z - centre.z)
	var radius: float = maxf(0.30, _draw_side().length() * 0.0 + 0.30)
	if flat.length() >= radius: return point
	var away: Vector3 = flat.normalized() if flat.length_squared() > 1.0e-8 else _draw_side()
	return Vector3(centre.x + away.x * radius, point.y, centre.z + away.z * radius)

## Which way the DRAWING side is, horizontally. It is measured between the two
## SHOULDERS, not from the drawing hand: during a draw the hand is out in front of
## the chest, so a hand-derived "side" is really "forward", and the quiver was
## pushed into the middle of his back instead of sitting on it.
func _draw_side() -> Vector3:
	if not is_instance_valid(_rig) or _bone_bow_clavicle < 0 or _bone_draw_clavicle < 0:
		return _player._visual.global_basis.x
	var bow_at: Vector3 = _rig.global_transform * _chain_global(_bone_bow_clavicle).origin
	var draw_at: Vector3 = _rig.global_transform * _chain_global(_bone_draw_clavicle).origin
	var side := draw_at - bow_at
	side.y = 0.0
	if side.length_squared() < 1.0e-6: return _player._visual.global_basis.x
	return side.normalized()

## Where the string hand is right now. It works the string once an arrow is nocked,
## or travels to the quiver and back when one has to be fetched.
##
## NOTE: the hand comes back to the ARCHER'S FACE, not behind his back. Pulling the
## hand backwards past the body is what made the arm read as going through the back;
## a real draw ends at the jaw, and the string follows the hand.
func _string_hand_point() -> Vector3:
	var aim := _aim_direction()
	var arm := _arm_length()
	# Braced: the fingers are on the string, a short way back from the bow hand.
	var braced: Vector3 = _bow_hand_point() - aim * (arm * 0.16)
	# Full draw: the hand comes to the jaw, on the drawing side. NOT behind the back,
	# and inside the arm's reach so the elbow can stay bent.
	var anchor: Vector3 = _draw_shoulder() \
		+ _draw_side() * (arm * 0.20) \
		+ _player._visual.global_basis.z.normalized() * (arm * 0.30) \
		- Vector3.UP * (arm * 0.04)
	return braced.lerp(anchor, clampf(_draw_amount, 0.0, 1.0))

## Where the string hand is right now: working the string once an arrow is nocked,
## or on its way to the quiver and back when one has to be fetched. The path curves
## out past the shoulder, so the arm never cuts through the head or chest.
func _draw_hand_point(delta: float) -> Vector3:
	_advance_fetch(delta)
	if _fetch_phase == "reach":
		return _arc_point(_rest_hand_anchor(), _over_shoulder_point(), _quiver_mouth, _fetch_t)
	if _fetch_phase == "nock":
		return _arc_point(_quiver_mouth, _over_shoulder_point(), _string_hand_point(), _fetch_t)
	return _string_hand_point()

## Runs the fetch: hand to the quiver, then quiver to string, then the arrow is on.
func _advance_fetch(delta: float) -> void:
	if _fetch_phase == "reach":
		_fetch_t += delta / FETCH_REACH_TIME
		if _fetch_t >= 1.0:
			_fetch_phase = "nock"
			_fetch_t = 0.0
		return
	if _fetch_phase == "nock":
		_fetch_t += delta / FETCH_NOCK_TIME
		if _fetch_t >= 1.0:
			_fetch_phase = ""
			_fetch_t = 0.0
			_nocked = true
		return
	# Nothing in hand, nothing on the string: go and get one.
	if not _nocked and _arrows_left > 0 and not _drawing:
		_fetch_phase = "reach"
		_fetch_t = 0.0

## Starts the fetch at once, for a player who draws before the arrow is on.
func _ensure_nocked() -> void:
	if _nocked or _arrows_left <= 0: return
	if _fetch_phase == "":
		_fetch_phase = "reach"
		_fetch_t = 0.0

func _rest_hand_anchor() -> Vector3:
	return _player.global_position + Vector3.UP * 1.20 + _aim_direction() * 0.24

## A point beside and above the DRAWING shoulder, out to the drawing side. The hand
## travels around this, not through the neck, and never crosses the body.
func _over_shoulder_point() -> Vector3:
	var visual: Node3D = _player._visual
	return _player.global_position + Vector3.UP * 1.54 \
		+ _draw_side() * 0.38 \
		- visual.global_basis.z * 0.04

## Quadratic Bezier, used for both halves of the fetch.
func _arc_point(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	var u := clampf(t, 0.0, 1.0)
	var inv := 1.0 - u
	return a * (inv * inv) + control * (2.0 * inv * u) + b * (u * u)

func _pose_arm(clav: int, upper: int, fore: int, hand: int,
		rest_upper: Transform3D, rest_fore: Transform3D, rest_hand: Transform3D,
		world_target: Vector3, pole_side: float) -> void:
	if clav < 0 or upper < 0 or fore < 0 or hand < 0: return
	# AFFINE inverse, not Basis.inverse(): the target is a world POSITION, and this
	# must undo the rig's translation as well as its rotation and scale. Using the
	# plain basis treated the target as a direction, so with the player standing at
	# x=42 the arm was aimed at a point over a hundred rig units away - the bow looked
	# held only because the model is placed on the hand AFTER the pose.
	var target_rig: Vector3 = _rig.global_transform.affine_inverse() * world_target
	var clavicle_global := _chain_global(clav)
	var joint := (clavicle_global * rest_upper).origin
	var l1 := rest_fore.origin.length()
	var l2 := rest_hand.origin.length()
	if l1 <= 0.01 or l2 <= 0.01: return
	var rest_basis := (clavicle_global * rest_upper * rest_fore * rest_hand).basis.orthonormalized()
	var grip_axis := (rest_basis * Vector3(0,0,-1)).normalized()
	var model_up: Vector3 = _basis_z_along(Vector3.ZERO, _aim_direction()).basis.y
	var grip_up: Vector3 = (_rig.global_basis.inverse() * model_up).normalized()
	var palm_basis := Basis(Quaternion(grip_axis, grip_up)) * rest_basis
	target_rig -= palm_basis * _hand_offset(hand)
	var to_target := target_rig - joint
	var distance := to_target.length()
	if distance < 1.0e-4: return
	var direction := to_target.normalized()
	var d := clampf(distance, absf(l1 - l2) + 1.0e-3, (l1 + l2) * 0.96)
	# The elbow hangs down and slightly back - a natural bend, never an inverted one.
	# Explicit world-space shoulder side avoids mirrored rig-name assumptions.
	var side: Vector3 = _draw_side() * (1.0 if hand == _bone_draw_hand else -1.0)
	var world_pole: Vector3 = side * 0.80 - Vector3.UP * 0.60 + _player._visual.global_basis.z * 0.05
	var pole: Vector3 = (_rig.global_basis.inverse() * world_pole).normalized()
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
	var hand_local := Transform3D((fore_global.basis.inverse() * palm_basis).orthonormalized(), rest_hand.origin)
	_rig.set_bone_pose(hand, hand_local)

func _point_bone(bone: int, rest: Transform3D, child_offset: Vector3, parent_global_basis: Basis, dir_rig: Vector3) -> Transform3D:
	var rest_dir := rest.basis * child_offset
	if rest_dir.length_squared() < 1.0e-10: rest_dir = rest.basis.y
	var local_dir := parent_global_basis.inverse() * dir_rig
	if local_dir.length_squared() < 1.0e-10: local_dir = rest_dir
	var turn := Quaternion(rest_dir.normalized(), local_dir.normalized())
	var local := Transform3D((Basis(turn) * rest.basis).orthonormalized(), rest.origin)
	_rig.set_bone_pose(bone, local)
	return local

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

## The bow sits in the bow hand, its own +Z along the aim, and the string runs from
## tip to tip THROUGH THE STRING HAND. The nock is the hand itself, so what the
## player sees is the string really coming back as he draws.
## Where the grip sits inside the bow's own model, along its +Z. The bow is placed so
## THIS point lands on the bow hand, not the bow's origin: otherwise the model floats
## in front of the fist and the hand is holding empty air.
const BOW_GRIP_LOCAL_Z := 0.10
## How far past the wrist the fingers are, where the string is actually held.
const FINGER_OFFSET := 0.045

func _place_bow() -> void:
	if not is_instance_valid(_bow): return
	var aim := _aim_direction()
	var fist: Vector3 = _hand_palm(_bone_bow_hand)
	var origin := fist - aim * BOW_GRIP_LOCAL_Z
	_bow.global_transform = _basis_z_along(origin, aim)
	# The tips must be the SAME points the limbs were built from, or the string hangs
	# off the bow instead of running between the nocks.
	var tip_a: Vector3 = _bow.to_global(_limb_point(1.0, 1.0))
	var tip_b: Vector3 = _bow.to_global(_limb_point(1.0, -1.0))
	# The nock is taken from the HAND BONE, not from the IK target: the string stays
	# in the fingers even if the arm could not reach the point it was asked for.
	var nock_at: Vector3 = _string_nock_point(aim)
	if is_instance_valid(_nock): _nock.global_position = nock_at
	if is_instance_valid(_string_a): _stretch(_string_a, tip_a, nock_at)
	if is_instance_valid(_string_b): _stretch(_string_b, nock_at, tip_b)
	_place_nocked_arrow(nock_at)

## The string is held in the fingers, a little past the wrist bone.
func _string_nock_point(_aim: Vector3) -> Vector3:
	if not is_instance_valid(_rig) or _bone_draw_hand < 0: return _string_hand_world
	return _hand_palm(_bone_draw_hand)

## How far the bow's GRIP is from the hand that is supposed to be holding it.
func bow_grip_error() -> float:
	if not is_instance_valid(_bow) or not is_instance_valid(_rig) or _bone_bow_hand < 0: return 99.0
	var fist: Vector3 = _hand_palm(_bone_bow_hand)
	return _bow.to_global(Vector3(0.0, 0.0, BOW_GRIP_LOCAL_Z)).distance_to(fist)

## Pose metrics are CACHED at the end of our own frame. Reading the bones from
## outside is unreliable: a caller that resumes on `process_frame` sees the skeleton
## right after the physics step, i.e. the WALK animation, not the pose we wrote. That
## is what made the hands look half a metre off.
var _pose_metrics: Dictionary = {}

func _cache_pose_metrics() -> void:
	_pose_metrics = {
		"bow_grip_error": bow_grip_error(),
		"string_grip_error": string_grip_error(),
		"string_reach_error": string_reach_error(),
		"bow_reach_error": bow_reach_error(),
		"draw_hand_forward": draw_hand_forward(),
		"bow_hand_forward": bow_hand_forward(),
		"hand_clearance": hand_clearance(),
		"elbow_clearance": elbow_clearance(),
		"quiver_offset_m": quiver_offset_m(),
		"string_pull_m": string_pull_m(),
	}

## The raw geometry of the archer pose, so a reach failure can be diagnosed by numbers
## instead of by guesswork.
func pose_report() -> Dictionary:
	return {
		"arm_length_m": _arm_length(),
		"bow_target_dist_m": _bow_shoulder().distance_to(_bow_hand_point()),
		"string_target_dist_m": _draw_shoulder().distance_to(_string_hand_point()),
		"bow_shoulder": _bow_shoulder(),
		"draw_shoulder": _draw_shoulder(),
	}

## Distance from the string nock to the drawing hand's bone. It should equal the
## finger offset - the nock is in the fingers, not on the wrist - so the useful check
## is that it stays within a hand's width.
func string_grip_error() -> float:
	if not is_instance_valid(_rig) or _bone_draw_hand < 0 or not is_instance_valid(_nock): return 99.0
	return _nock.global_position.distance_to(_hand_palm(_bone_draw_hand))

## How far the drawing hand BONE ended up from the point the IK was asked to reach.
## A large value means the arm cannot get there and the pose is stretched or folded.
func string_reach_error() -> float:
	if not is_instance_valid(_rig) or _bone_draw_hand < 0: return 99.0
	return _hand_palm(_bone_draw_hand).distance_to(_string_target_world)

## How far the bow hand BONE is from the point its IK was asked to reach.
func bow_reach_error() -> float:
	if not is_instance_valid(_rig) or _bone_bow_hand < 0: return 99.0
	return _hand_palm(_bone_bow_hand).distance_to(_bow_hand_point())

## The arrow on the string, which is what makes a draw readable: it sits between the
## archer's fingers with its point toward the target.
func _place_nocked_arrow(nock_at: Vector3) -> void:
	if not is_instance_valid(_nocked_arrow): return
	var wanted: bool = _nocked and _arrows_left > 0
	_nocked_arrow.visible = wanted
	if not wanted: return
	var aim := _aim_direction()
	# The model's nock sits 0.37 m behind its origin.
	var origin: Vector3 = nock_at + aim * 0.37
	_nocked_arrow.global_position = origin
	_nocked_arrow.look_at(origin + aim, Vector3.UP, true)

## Basis whose local +Z runs along `direction`.
func _basis_z_along(origin: Vector3, direction: Vector3) -> Transform3D:
	var z := direction.normalized()
	if z.length_squared() < 1.0e-8: z = Vector3.FORWARD
	var reference := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.94 else Vector3.RIGHT
	var x := reference.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), origin)

# ---------------------------------------------------------------- aim preview

## The dotted arc under the crosshair is the arrow's REAL path: the same launch
## speed and the same gravity the shot will use, so what is drawn is what flies.
## The first few dots are always shown - the ray from the bow can clip the archer's
## own surroundings right at the muzzle, and an arc that vanishes is no use.
func _update_aim_preview() -> void:
	if not _show_aim():
		_hide_aim()
		return
	var aim := _aim_direction()
	var speed := launch_speed(_draw_amount if _drawing else 1.0)
	var step := clampf(0.9 / maxf(speed, 1.0), 0.012, 0.05)
	var at := _muzzle_point()
	var velocity := aim * speed
	var tip := at + aim * ARROW_TIP_OFFSET31
	var shown := 0
	var travelled := 0.0
	# No decorative dots beyond a nearby wall: the launch check matches _fire.
	if not _arrow_ray31(_launch_guard_point31(), tip).is_empty():
		_hide_aim()
		_predicted_range = 0.0
		return
	for i: int in MAX_AIM_DOTS:
		var next := _ballistic_point31(at, velocity, step)
		velocity += Vector3.DOWN * GRAVITY * step
		var next_tip := next + velocity.normalized() * ARROW_TIP_OFFSET31
		var hit := _arrow_ray31(tip, next_tip)
		var dot: MeshInstance3D = _aim_dots[i]
		dot.visible = true
		dot.global_position = hit.position if not hit.is_empty() else next_tip
		var fade := 1.0 - float(i) / float(MAX_AIM_DOTS)
		dot.scale = Vector3.ONE * clampf(0.35 + fade * 0.85, 0.2, 1.2)
		shown += 1
		travelled += step * speed
		if not hit.is_empty(): break
		at = next
		tip = next_tip
	for i: int in range(shown, _aim_dots.size()): _aim_dots[i].visible = false
	_predicted_range = travelled
var _predicted_range := 0.0

func _hide_aim() -> void:
	for dot: MeshInstance3D in _aim_dots:
		if is_instance_valid(dot): dot.visible = false

# ---------------------------------------------------------------- audio
var _impact_player: AudioStreamPlayer3D

func _impact_sound(at: Vector3) -> void:
	_build_arrow_audio31()
	_arrow_audio_counts31["release"] += 1
	if not is_instance_valid(_impact_player):
		_impact_player = AudioStreamPlayer3D.new()
		_impact_player.name = "BowRelease"
		_impact_player.stream = _arrow_audio_streams31["release"]
		_impact_player.unit_size = 3.0
		_impact_player.max_distance = 26.0
		add_child(_impact_player)
	_impact_player.global_position = at
	_impact_player.pitch_scale = randf_range(0.92, 1.12)
	_impact_player.play()

## A short string twang, synthesised so no audio asset is needed.
func _pluck_stream() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.22)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t := float(i) / float(rate)
		var envelope := exp(-26.0 * t)
		var value := sin(TAU * 220.0 * t) * 0.65 + sin(TAU * 330.0 * t) * 0.35
		var sample := int(clampf(value * envelope, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

# ---------------------------------------------------------------- diagnostics

func snapshot() -> Dictionary:
	if not is_inside_tree() or not is_instance_valid(_player) or not _player.is_inside_tree(): return {}
	return {
		"ready": _ready, "ready_to_fire": ready_to_fire(), "selected": _selected, "drawing": _drawing,
		"aiming": _aiming, "aim_shown": _show_aim(),
		"draw": _draw_amount, "arrows": _arrows.size(), "shots": _shots,
		"arrows_left": _arrows_left, "quiver_worn": _quiver_worn,
		"nocked": _nocked, "fetch_phase": _fetch_phase, "grounded": _grounded,
		"string_pull_m": _pose_metrics.get("string_pull_m", 0.0),
		"hand_clearance": _pose_metrics.get("hand_clearance", 0.0),
		"elbow_clearance": _pose_metrics.get("elbow_clearance", 0.0),
		"string_visible": string_visible(),
		"nocked_arrow_visible": is_instance_valid(_nocked_arrow) and _nocked_arrow.visible,
		"quiver_offset_m": _pose_metrics.get("quiver_offset_m", 0.0),
		"quiver_clear_of_body": quiver_clear_of_body(),
		"draw_hand_forward": _pose_metrics.get("draw_hand_forward", 0.0),
		"bow_hand_forward": _pose_metrics.get("bow_hand_forward", 0.0),
		"bow_grip_error": _pose_metrics.get("bow_grip_error", 99.0),
		"string_grip_error": _pose_metrics.get("string_grip_error", 99.0),
		"string_reach_error": _pose_metrics.get("string_reach_error", 99.0),
		"bow_reach_error": _pose_metrics.get("bow_reach_error", 99.0),
		"ground_items": _ground_items.size(), "quiver_mouth": _quiver_mouth,
		"stuck": _stuck_total, "last_hit_distance": _last_hit_distance,
		"last_flight_time": _last_flight_time, "predicted_range": _predicted_range,
		"speed_now": launch_speed(_draw_amount), "aim": _aim_direction(),
		"zoom_scale": _zoom_scale,
		"muzzle": _muzzle_point(), "fov": _camera.fov if is_instance_valid(_camera) else 0.0,
		"active": _active(), "aim_dots": _visible_aim_dots(),
		"bow_in_hand_error": _bow_hand_error(),
	}

## The arc is shown while the string is drawn AND while the right button is held:
## that button is the targeting aid, and costs no arrow.
func _show_aim() -> bool:
	return _active() and not _grounded and (_drawing or _aiming)

## How far the predicted arc ends BELOW the straight line from the muzzle: the one
## number that says the aim line is ballistic rather than a laser.
func aim_arc_drop() -> float:
	if _aim_dots.is_empty(): return 0.0
	var straight := _muzzle_point() + _aim_direction() * _predicted_range
	var last_visible := Vector3.ZERO
	for dot: MeshInstance3D in _aim_dots:
		if is_instance_valid(dot) and dot.visible: last_visible = dot.global_position
	if last_visible == Vector3.ZERO: return 0.0
	return straight.y - last_visible.y

## Live state of one arrow, so a driven test can watch the flight itself.
func arrow_state(index: int) -> Dictionary:
	if index < 0 or index >= _arrows.size(): return {}
	var entry: Dictionary = _arrows[index]
	var node: Variant = entry.get("node")
	return {
		"alive": bool(entry.get("alive", false)),
		"stuck": bool(entry.get("stuck", false)),
		"position": node.global_position if is_instance_valid(node) else Vector3.ZERO,
		"velocity": entry.get("velocity", Vector3.ZERO),
		"fired_ms": int(entry.get("fired_ms", 0)),
	}

## Only used by diagnostics: how far above the straight line the arrow is, which is
## the ballistic drop made visible.
func arrow_count() -> int:
	return _arrows.size()

## How far IN FRONT of the body a hand actually ended up, in metres. Negative means
## the arm is behind the character, which is the fault being chased: it measures the
## BONE the player sees, not the target we asked for.
func draw_hand_forward() -> float:
	return _bone_forward(_bone_draw_hand)

func bow_hand_forward() -> float:
	return _bone_forward(_bone_bow_hand)

func _bone_forward(bone: int) -> float:
	if not is_instance_valid(_rig) or bone < 0 or not is_instance_valid(_player): return 0.0
	var at: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(bone).origin
	var fwd: Vector3 = _player._visual.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1.0e-6: return 0.0
	return (at - _player.global_position).dot(fwd.normalized())

## Horizontal distance from the drawing hand to the archer's own centre line, and
## the same for his elbow. These are the measurements that say whether the arm is
## being posed through his body, which is exactly the fault being fixed.
## How far the quiver's axis sits from the archer's spine, horizontally. It has to
## clear the body but stay against it: too small is inside the torso, too large is
## the quiver standing off his back.
func quiver_offset_m() -> float:
	if not is_instance_valid(_quiver) or not _quiver_worn: return 0.0
	var spine: Vector3 = _player.global_position
	if is_instance_valid(_rig) and _bone_chest >= 0:
		spine = (_rig.global_transform * _chain_global(_bone_chest)).origin
	var flat := Vector2(_quiver.global_position.x - spine.x, _quiver.global_position.z - spine.z)
	return flat.length()

## The quiver's tube must not be inside the character's own body.
func quiver_clear_of_body() -> bool:
	return quiver_offset_m() > 0.135

func hand_clearance() -> float:
	return _flat_clearance(_string_hand_world)

func elbow_clearance() -> float:
	if not is_instance_valid(_rig) or _bone_draw_fore < 0: return 99.0
	var elbow: Vector3 = _rig.global_transform * _rig.get_bone_global_pose(_bone_draw_fore).origin
	return _flat_clearance(elbow)

func _flat_clearance(point: Vector3) -> float:
	if not is_instance_valid(_player): return 99.0
	var flat := Vector2(point.x - _player.global_position.x, point.z - _player.global_position.z)
	return flat.length()

## How far the string has actually been drawn: the distance the nock sits BEHIND the
## bow's grip, along the aim. This is the number that says whether a draw is visible.
func string_pull_m() -> float:
	if not is_instance_valid(_bow) or _string_hand_world == Vector3.ZERO: return 0.0
	var grip: Vector3 = _bow.to_global(Vector3(0.0, 0.0, BOW_GRIP_LOCAL_Z))
	var nock: Vector3 = _string_nock_point(_aim_direction())
	return maxf(0.0, (grip - nock).dot(_aim_direction()))

func string_visible() -> bool:
	return is_instance_valid(_string_a) and _string_a.visible \
		and is_instance_valid(_string_b) and _string_b.visible

## Counts what the bow actually costs the scene: total nodes, mesh-drawing nodes,
## MultiMesh nodes, and how many UNIQUE meshes they share. The point of the pooling
## is that the unique-mesh count stays tiny however many arrows are in flight.
func perf_report() -> Dictionary:
	# The models live under the world, not under this host, so they are named here.
	var roots: Array[Node] = []
	for candidate: Variant in [_bow, _nocked_arrow, _quiver, _ground_quiver]:
		if is_instance_valid(candidate): roots.append(candidate)
	for entry: Dictionary in _arrows:
		var node: Variant = entry.get("node")
		if is_instance_valid(node): roots.append(node)
	for dot: MeshInstance3D in _aim_dots:
		if is_instance_valid(dot): roots.append(dot)
	if is_instance_valid(_string_a): roots.append(_string_a)
	if is_instance_valid(_string_b): roots.append(_string_b)
	var nodes := 0
	var mesh_nodes := 0
	var multimesh_nodes := 0
	var unique: Dictionary = {}
	var stack: Array[Node] = roots.duplicate()
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		nodes += 1
		if node is MeshInstance3D:
			mesh_nodes += 1
			var m: Mesh = (node as MeshInstance3D).mesh
			if m != null: unique[m.get_instance_id()] = true
		elif node is MultiMeshInstance3D:
			multimesh_nodes += 1
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null: unique[mm.mesh.get_instance_id()] = true
		for child: Node in node.get_children():
			stack.append(child)
	return {"nodes": nodes, "mesh_nodes": mesh_nodes, "multimesh_nodes": multimesh_nodes,
		"unique_meshes": unique.size(), "arrows": _arrows.size(), "stuck": _stuck_total}

func _visible_aim_dots() -> int:
	var count := 0
	for dot: MeshInstance3D in _aim_dots:
		if is_instance_valid(dot) and dot.visible: count += 1
	return count

func _bow_hand_error() -> float:
	if not is_instance_valid(_bow) or not is_instance_valid(_rig) or _bone_bow_hand < 0: return 99.0
	var fist: Vector3 = _hand_palm(_bone_bow_hand)
	return bow_grip_error()

func _exit_tree() -> void:
	for entry: Dictionary in _arrows:
		var node: Variant = entry.get("node")
		if is_instance_valid(node): node.queue_free()
	_arrows.clear()


const ARROW_TIP_OFFSET31 := 0.4425
const MAX_FLIGHT_AUDIO31 := 6
var _last_arrow_surface31 := ""
var _arrow_audio_streams31: Dictionary = {}
var _arrow_impact_players31: Array[AudioStreamPlayer3D] = []
var _arrow_impact_cursor31 := 0
var _flight_audio_count31 := 0
var _arrow_audio_counts31 := {"release": 0, "flight": 0, "wood": 0, "stone": 0, "dirt": 0, "flesh": 0}

func _ballistic_point31(at: Vector3, velocity: Vector3, delta: float) -> Vector3:
	return at + velocity * delta + Vector3.DOWN * (0.5 * GRAVITY * delta * delta)

func _launch_guard_point31() -> Vector3:
	if is_instance_valid(_bow): return _bow.to_global(Vector3(0, 0, BOW_GRIP_LOCAL_Z))
	return _bow_hand_point()

func _arrow_ray31(from: Vector3, to: Vector3) -> Dictionary:
	if from.distance_squared_to(to) < 0.000000001: return {}
	var space := _player.get_world_3d().direct_space_state
	if space == null: return {}
	var excluded: Array[RID] = [_player.get_rid()]
	# The NPC's movement capsule surrounds the animated limb hitboxes. Resolve
	# arrows against the limb hitboxes, which carry the damage part identity.
	if is_instance_valid(_sword_host):
		var npc_body: Variant = _sword_host.get("_npc_body")
		if is_instance_valid(npc_body) and npc_body is CollisionObject3D:
			excluded.append(npc_body.get_rid())
		# The dead resident's physical capsule is only a collision shell. Arrows
		# must still meet the moving tagged rig hitboxes to identify the part.
		var npc_corpse: Variant = _sword_host.get("_npc_corpse31")
		if is_instance_valid(npc_corpse) and npc_corpse is CollisionObject3D:
			excluded.append(npc_corpse.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, AIM_MASK, excluded)
	query.hit_from_inside = true
	return space.intersect_ray(query)

func _arrow_surface31(collider: Variant) -> String:
	if not is_instance_valid(collider): return "stone"
	if collider.has_meta("sword_npc_part"): return "flesh"
	var current := collider as Node
	var names := ""
	for depth: int in 5:
		if not is_instance_valid(current): break
		names += " " + String(current.name).to_lower()
		for key: String in ["surface", "surface_type", "material_type"]:
			if not current.has_meta(key): continue
			var value := str(current.get_meta(key)).to_lower()
			if value in ["wood", "timber", "plank"]: return "wood"
			if value in ["dirt", "earth", "ground", "grass", "sand", "soil"]: return "dirt"
			if value in ["stone", "concrete", "brick", "masonry", "metal"]: return "stone"
		current = current.get_parent()
	if "wood" in names or "gate" in names or "plank" in names or "pole" in names: return "wood"
	if "ground" in names or "dirt" in names or "grass" in names or "soil" in names: return "dirt"
	return "stone"

func _build_arrow_audio31() -> void:
	if not _arrow_audio_streams31.is_empty(): return
	_arrow_audio_streams31["release"] = _pluck_stream()
	for kind: String in ["flight", "wood", "stone", "dirt", "flesh"]:
		_arrow_audio_streams31[kind] = _arrow_stream31(kind)

func _arrow_stream31(kind: String) -> AudioStreamWAV:
	# Shared, deterministic mono resources. No per-shot file decode or synthesis.
	var rate := 22050
	var duration := 0.40 if kind == "flight" else 0.20
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 310718
	var low := 0.0
	for i: int in count:
		var t := float(i) / float(rate)
		var noise := random.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.12)
		var value := 0.0
		match kind:
			"flight": value = (noise - low) * 0.13 * (0.90 + 0.10 * cos(TAU * t / duration))
			"wood": value = sin(TAU * 540.0 * t) * exp(-35.0 * t) * 0.65 + noise * exp(-85.0 * t) * 0.23
			"stone": value = (sin(TAU * 2300.0 * t) + 0.4 * sin(TAU * 3750.0 * t)) * exp(-48.0 * t) * 0.28 + noise * exp(-100.0 * t) * 0.34
			"dirt": value = low * exp(-32.0 * t) * 1.7 + sin(TAU * 105.0 * t) * exp(-50.0 * t) * 0.26
			"flesh": value = sin(TAU * (190.0 * t - 160.0 * t * t)) * exp(-30.0 * t) * 0.62 + noise * exp(-115.0 * t) * 0.28 + low * exp(-55.0 * absf(t - 0.025)) * 0.72
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if kind == "flight":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream

func _start_arrow_flight31(arrow: Node3D) -> void:
	_flight_audio_count31 = _flight_voices31()
	if _flight_audio_count31 >= MAX_FLIGHT_AUDIO31: return
	_build_arrow_audio31()
	var sound := arrow.get_node_or_null("FlightSound31") as AudioStreamPlayer3D
	if sound == null:
		sound = AudioStreamPlayer3D.new()
		sound.name = "FlightSound31"
		sound.stream = _arrow_audio_streams31["flight"]
		sound.unit_size = 2.5
		sound.max_distance = 24.0
		sound.volume_db = -16.0
		arrow.add_child(sound)
	if sound.playing: return
	sound.play()
	_flight_audio_count31 += 1
	_arrow_audio_counts31["flight"] += 1

func _update_arrow_flight31(arrow: Node3D, speed: float) -> void:
	var sound := arrow.get_node_or_null("FlightSound31") as AudioStreamPlayer3D
	if sound == null or not sound.playing: return
	sound.pitch_scale = clampf(speed / ARROW_SPEED_MAX, 0.65, 1.35)
	sound.volume_db = lerpf(-24.0, -14.0, clampf(speed / ARROW_SPEED_MAX, 0.0, 1.0))

func _stop_arrow_flight31(arrow: Node3D) -> void:
	var sound := arrow.get_node_or_null("FlightSound31") as AudioStreamPlayer3D
	if sound == null or not sound.playing: return
	sound.stop()
	_flight_audio_count31 = maxi(0, _flight_audio_count31 - 1)

func _play_arrow_impact31(at: Vector3, surface: String, speed: float) -> void:
	_build_arrow_audio31()
	if _arrow_impact_players31.size() < 4:
		var sound := AudioStreamPlayer3D.new()
		sound.name = "ArrowImpact31"
		sound.unit_size = 4.0
		sound.max_distance = 35.0
		add_child(sound)
		_arrow_impact_players31.append(sound)
	var player := _arrow_impact_players31[_arrow_impact_cursor31 % _arrow_impact_players31.size()]
	_arrow_impact_cursor31 += 1
	player.stream = _arrow_audio_streams31.get(surface, _arrow_audio_streams31["stone"])
	player.global_position = at
	player.pitch_scale = randf_range(0.94, 1.06)
	player.volume_db = lerpf(-14.0, -3.0, clampf(speed / ARROW_SPEED_MAX, 0.0, 1.0))
	player.play()
	_arrow_audio_counts31[surface] = int(_arrow_audio_counts31.get(surface, 0)) + 1

func arrow_audio_report31() -> Dictionary:
	return {"events": _arrow_audio_counts31.duplicate(), "last_surface": _last_arrow_surface31,
		"flight_voices": _flight_voices31(), "impact_voices": _arrow_impact_players31.size(),
		"cached_streams": _arrow_audio_streams31.size()}

func _flight_voices31() -> int:
	var count := 0
	for entry: Dictionary in _arrows:
		var node: Variant = entry.get("node")
		if not is_instance_valid(node): continue
		var sound := node.get_node_or_null("FlightSound31") as AudioStreamPlayer3D
		if sound != null and sound.playing: count += 1
	return count
