extends Node3D
## DSH_HORSE: the castle horse and its rider.
##
## The horse is a real CharacterBody3D (scripts/mount/horse.gd) standing in the
## courtyard/approach. E next to it seats the player on the saddle; the same E gets
## him off again and leaves the horse exactly where he left it. While seated the player
## controller is suspended (pose authority stays "on_foot" so every weapon stays live),
## the capsule is switched off and the rider is glued to the saddle by the horse.
##
## E prompt and horse HP are one top-centre banner, the same keycap plate the other
## world interactions use; no extra world-space labels are drawn.

const HorseScript = preload("res://scripts/mount/horse.gd")
const RiderPose = preload("res://scripts/mount/horse_rider_pose.gd")
const MOUNT_RANGE := 3.4
const DISMOUNT_SIDES := [Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0)]
const DISMOUNT_DISTANCE := 2.15
const RIDING_CAMERA_DISTANCE := 7.2
const HP_VISIBLE_AFTER_HIT_MS := 4200
const HP_VISIBLE_RANGE := 8.0
const HORSE_MAX_HP := 100.0
const VAULT_DURATION := 0.50
const VAULT_DISTANCE := 2.9
const VAULT_ARC := 0.95
const VAULT_RANGE := 2.2

var horse: CharacterBody3D
var player: CharacterBody3D
var status := "idle"
var error := ""

var _pose: RefCounted
var _mounted := false
var _vault_active := false
var _vault_time := 0.0
var _vault_start := Vector3.ZERO
var _vault_end := Vector3.ZERO
var _vault_heading := 0.0
var _vault_layer := 2
var _vault_mask := 1
var _vault_cooldown := 0.0
var _vaults := 0
var _walking_layer := 0
var _walking_mask := 0
var _collision_owned := false
var _mounts := 0
var _dismounts := 0
var _last_dismount: Dictionary = {}
var _walking_camera_distance := 5.119570294468082
var _camera_distance_owned := false

var _hud: CanvasLayer
var _banner: PanelContainer
var _banner_label: Label
var _banner_state := -1
var _hp_panel: PanelContainer
var _hp_label: Label
var _hp_fill: ColorRect
var _hp_track_width := 188.0
var _hp_value := -1.0
var _hp_show_until := 0
var _viewport_size := Vector2(1280, 720)

func install(world: Node3D, existing_player: CharacterBody3D) -> Dictionary:
	if is_instance_valid(horse) or existing_player == null or not existing_player.is_inside_tree():
		return {"ok": false, "reason": "already_installed"}
	if not is_instance_valid(world):
		return {"ok": false, "reason": "no_world"}
	player = existing_player
	_pose = RiderPose.new()
	var rig: Skeleton3D = player.get("_pose_skeleton") as Skeleton3D
	var motion: Node3D = player.get("_pose_motion") as Node3D
	var locomotion: RefCounted = player.get("_locomotion") as RefCounted
	if not is_instance_valid(rig) or not is_instance_valid(motion) or locomotion == null:
		return {"ok": false, "reason": "rider_rig_missing"}
	var rest: Array = locomotion.get("_rest_poses")
	if not _pose.configure(rig, motion, rest, float(player.get("_model_scale"))):
		return {"ok": false, "reason": "rider_pose_binding"}
	# A clear patch of ground in front of and beside the player, wherever he starts.
	var heading := float(player.get("_heading"))
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(cos(heading), 0.0, -sin(heading))
	var spot: Vector3 = player.global_position + forward * 4.6 + right * 2.8
	spot.y = _ground_height(spot)
	var body: CharacterBody3D = HorseScript.new()
	body.name = "CastleHorse"
	add_child(body)
	if not body.setup(spot, heading):
		body.queue_free()
		return {"ok": false, "reason": "horse_setup_failed"}
	horse = body
	horse.damage_owner = player
	horse.set_meta("horse_id", "castle_horse")
	horse.set_meta("life_generation", 1)
	_build_hud()
	status = "ready"
	var mesh_nodes := 0
	for node: Node in horse.find_children("*", "MeshInstance3D", true, false):
		mesh_nodes += 1
	var receipt := {"ok": true, "position": horse.global_position, "yaw": heading,
		"rider_pose": _pose.status(), "ground_y": spot.y, "mesh_nodes": mesh_nodes,
		"player": player.global_position, "layer": horse.collision_layer, "mask": horse.collision_mask}
	print("DSH_HORSE_INSTALL ", JSON.stringify(receipt))
	return receipt

func _ground_height(at: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return at.y
	var ray := PhysicsRayQueryParameters3D.new()
	ray.from = Vector3(at.x, at.y + 6.0, at.z)
	ray.to = Vector3(at.x, at.y - 30.0, at.z)
	ray.collision_mask = 1
	ray.exclude = [player.get_rid()] if is_instance_valid(player) else []
	var hit: Dictionary = world.direct_space_state.intersect_ray(ray)
	return float(hit.position.y) + 0.02 if not hit.is_empty() else at.y

## ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HorseHud"
	_hud.layer = 13
	add_child(_hud)
	_banner = _make_panel()
	_banner_label = _make_label(_banner)
	_banner.visible = false
	# HP: name + current/max, then a thin red bar on a dark track.
	_hp_panel = PanelContainer.new()
	_hp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.82)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	_hp_panel.add_theme_stylebox_override("panel", style)
	_hud.add_child(_hp_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	_hp_panel.add_child(column)
	_hp_label = Label.new()
	_hp_label.text = "ЛОШАДЬ"
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.add_theme_color_override("font_color", Color("d8c9a8"))
	column.add_child(_hp_label)
	var track := ColorRect.new()
	track.color = Color(0.12, 0.10, 0.09, 0.95)
	track.custom_minimum_size = Vector2(_hp_track_width, 7)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(track)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.62, 0.10, 0.11)
	_hp_fill.size = Vector2(_hp_track_width, 7)
	_hp_fill.position = Vector2.ZERO
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_hp_fill)
	_hp_panel.visible = false

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	style.content_margin_left = 6
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	_hud.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var key := PanelContainer.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color("f0c86b")
	key.add_theme_stylebox_override("panel", key_style)
	key.custom_minimum_size = Vector2(24, 24)
	row.add_child(key)
	var key_label := Label.new()
	key_label.text = "E"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_color_override("font_color", Color("15191b"))
	key.add_child(key_label)
	panel.set_meta("row", row)
	return panel

func _make_label(panel: PanelContainer) -> Label:
	var row: HBoxContainer = panel.get_meta("row") as HBoxContainer
	var text := Label.new()
	text.add_theme_font_size_override("font_size", 14)
	row.add_child(text)
	return text

## ---------------------------------------------------------------- E ownership
func _can_ride() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(horse):
		return false
	if bool(horse.get("dead")):
		return false
	if player.get("_pose_authority") != &"on_foot":
		return false
	if not bool(player.get("_free_mouse_look")):
		return false
	return true

func wants_e() -> bool:
	if not is_instance_valid(horse) or not is_instance_valid(player):
		return false
	if bool(horse.get("dead")):
		return false
	if _mounted:
		return true
	if not _can_ride():
		return false
	return player.global_position.distance_to(horse.global_position) <= MOUNT_RANGE

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or not is_instance_valid(horse):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_E:
		return
	if not bool(player.get("_free_mouse_look")):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if _mounted:
		if dismount_now():
			get_viewport().set_input_as_handled()
		return
	if not _can_ride():
		return
	if not wants_e():
		return
	if mount_now():
		get_viewport().set_input_as_handled()

## ---------------------------------------------------------------- seat in/out
func mount_now() -> bool:
	if _mounted or not is_instance_valid(horse) or not is_instance_valid(player):
		return false
	if not _can_ride():
		return false
	if _pose == null or not _pose.is_ready():
		error = "rider_pose_not_ready"
		return false
	_walking_layer = player.collision_layer
	_walking_mask = player.collision_mask
	_collision_owned = true
	# Keep the ordinary on-foot pose authority: every weapon owner (sword set,
	# shield, bow, firearm presentation) already keys off it, so combat stays live.
	if not player.begin_mounted(_pose):
		_collision_owned = false
		error = "mount_mode_rejected"
		return false
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	horse.rider = player
	horse.rider_hip = _pose.hip_height()
	horse.damage_owner = player
	_pose.reset()
	var body_visual: Node3D = player.get("_visual") as Node3D
	if is_instance_valid(body_visual):
		body_visual.rotation.y = deg_to_rad(float(player.get("visual_yaw_degrees")))
	var arm: SpringArm3D = player.get("_spring_arm") as SpringArm3D
	if is_instance_valid(arm):
		arm.add_excluded_object(horse.get_rid())
	# Pull the orbit back a little so the whole horse is in frame while riding.
	_walking_camera_distance = float(player.get("camera_distance"))
	_camera_distance_owned = _aim_camera_owns_distance() == false
	if _camera_distance_owned:
		player.set("camera_distance", RIDING_CAMERA_DISTANCE)
		if is_instance_valid(arm):
			arm.spring_length = RIDING_CAMERA_DISTANCE
	_mounted = true
	_mounts += 1
	status = "mounted"
	_hp_show_until = Time.get_ticks_msec() + HP_VISIBLE_AFTER_HIT_MS
	print("DSH_HORSE_MOUNT serial=", _mounts, " player=", player.global_position,
		" horse=", horse.global_position, " hip=", horse.rider_hip)
	return true

func dismount_now() -> bool:
	if not _mounted or not is_instance_valid(horse) or not is_instance_valid(player):
		return false
	var spot := _find_dismount_spot()
	if spot.is_empty():
		error = "no_dismount_ground"
		return false
	var was_at := horse.global_position
	var yaw := horse.rotation.y
	horse.rider = null
	_mounted = false
	player.end_mounted()
	_restore_player_collision()
	_clear_weapon_inputs()
	if is_instance_valid(player.get("_spring_arm")):
		var arm: SpringArm3D = player.get("_spring_arm") as SpringArm3D
		arm.remove_excluded_object(horse.get_rid())
		if _camera_distance_owned:
			player.set("camera_distance", _walking_camera_distance)
			if _aim_camera_owns_distance() == false:
				arm.spring_length = _walking_camera_distance
		_camera_distance_owned = false
	# Keep the root unrotated: the character's facing is the visual's yaw, and the
	# movement code writes that yaw in world terms. Rotating the root as well made the
	# body face 2*yaw after any dismount from an angled horse.
	player.global_transform = Transform3D(Basis(), spot.position)
	player.velocity = Vector3.ZERO
	player._heading = yaw
	var visual: Node3D = player.get("_visual") as Node3D
	if is_instance_valid(visual):
		visual.rotation.y = yaw + deg_to_rad(float(player.get("visual_yaw_degrees")))
	player.set_preview_pose_authority(&"on_foot", true)
	var pivot: Node3D = player.get("_yaw_pivot") as Node3D
	if is_instance_valid(pivot):
		pivot.position.y = float(player.get("model_target_height")) * 0.79
	player._update_camera_rotation()
	_dismounts += 1
	_last_dismount = {"player": player.global_position, "horse": horse.global_position,
		"horse_moved": horse.global_position.distance_to(was_at), "side": spot.side,
		"ground": spot.ground, "serial": _dismounts, "horse_dead": bool(horse.get("dead"))}
	status = "ready"
	print("DSH_HORSE_DISMOUNT ", JSON.stringify(_last_dismount))
	return true

func _restore_player_collision() -> void:
	if not _collision_owned:
		return
	player.collision_layer = _walking_layer
	player.collision_mask = _walking_mask
	_collision_owned = false

## A button held while mounting/dismounting must not stay latched in the weapon
## host: otherwise the sword thinks RMB/LMB is still down and the right hand or the
## two-handed grip cannot be selected after the fall.
func _clear_weapon_inputs() -> void:
	var weapons: Node = player.get("_weapon_host") as Node
	if is_instance_valid(weapons) and weapons.has_method("cancel_inputs"):
		weapons.call("cancel_inputs", false)

func _aim_camera_owns_distance() -> bool:
	var weapons: Node = player.get("_weapon_host") as Node
	if not is_instance_valid(weapons):
		return false
	var aim: Variant = weapons.get("aim_camera")
	return aim != null and aim.has_method("owns_distance") and bool(aim.owns_distance())

func _excluded_rids() -> Array[RID]:
	var excluded: Array[RID] = [horse.get_rid(), player.get_rid()]
	var dead_body: Variant = horse.get("corpse")
	if dead_body is CollisionObject3D and is_instance_valid(dead_body):
		excluded.append((dead_body as CollisionObject3D).get_rid())
	return excluded

func _find_dismount_spot() -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	for side: int in DISMOUNT_SIDES.size():
		var local: Vector3 = DISMOUNT_SIDES[side] * DISMOUNT_DISTANCE
		var world_spot: Vector3 = horse.to_global(local)
		var ray := PhysicsRayQueryParameters3D.new()
		ray.from = world_spot + Vector3.UP * 2.0
		ray.to = world_spot - Vector3.UP * 6.0
		ray.collision_mask = 1
		ray.exclude = _excluded_rids()
		var hit: Dictionary = world.direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			continue
		var ground := Vector3(world_spot.x, float(hit.position.y) + 0.03, world_spot.z)
		if not _capsule_free(ground):
			continue
		return {"position": ground, "side": side, "ground": hit.position}
	return {}

func _capsule_free(at: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.30
	shape.height = float(player.get("model_target_height"))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * shape.height * 0.5)
	query.collision_mask = 1
	query.exclude = _excluded_rids()
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## ---------------------------------------------------------------- runtime
func is_mounted() -> bool:
	return _mounted and is_instance_valid(horse) and horse.rider != null

func _physics_process(_delta: float) -> void:
	_place_world_banner()
	if not is_instance_valid(horse) or not is_instance_valid(player):
		return
	if _vault_active:
		_tick_vault(_delta)
		return
	_vault_cooldown = maxf(0.0, _vault_cooldown - _delta)
	if bool(horse.get("dead")):
		if _mounted:
			# The horse died under the rider: put him down next to the body.
			if not dismount_now():
				_force_player_off_dead_horse()
		# Whatever path got us here, walking collision must be back on: the corpse is
		# solid, so the player has to collide with it instead of slipping through.
		_restore_player_collision()
		_try_vault()
		_update_hud(true)
		return
	if _mounted and not horse.has_rider():
		# The horse lost its rider (respawn/teleport); restore walking here.
		horse.rider = null
		_mounted = false
		player.end_mounted()
		_restore_player_collision()
		player.set_preview_pose_authority(&"on_foot", true)
	_update_hud(false)

## Last-resort placement if every dismount candidate is blocked by the corpse.
func _force_player_off_dead_horse() -> void:
	var yaw := horse.rotation.y
	var right: Vector3 = horse.global_transform.basis.x.normalized()
	var at: Vector3 = horse.global_position + right * 2.4
	at.y = _ground_height(at)
	horse.rider = null
	_mounted = false
	player.end_mounted()
	_restore_player_collision()
	_clear_weapon_inputs()
	if is_instance_valid(player.get("_spring_arm")):
		var arm: SpringArm3D = player.get("_spring_arm") as SpringArm3D
		arm.remove_excluded_object(horse.get_rid())
		if _camera_distance_owned:
			player.set("camera_distance", _walking_camera_distance)
			if _aim_camera_owns_distance() == false:
				arm.spring_length = _walking_camera_distance
		_camera_distance_owned = false
	player.global_transform = Transform3D(Basis(), at)
	player.velocity = Vector3.ZERO
	player._heading = yaw
	var visual: Node3D = player.get("_visual") as Node3D
	if is_instance_valid(visual):
		visual.rotation.y = yaw + deg_to_rad(float(player.get("visual_yaw_degrees")))
	player.set_preview_pose_authority(&"on_foot", true)
	var pivot: Node3D = player.get("_yaw_pivot") as Node3D
	if is_instance_valid(pivot):
		pivot.position.y = float(player.get("model_target_height")) * 0.79
	player._update_camera_rotation()
	_dismounts += 1
	_last_dismount = {"player": at, "horse": horse.global_position, "forced": true, "serial": _dismounts, "horse_dead": true}
	print("DSH_HORSE_FORCED_DISMOUNT ", JSON.stringify(_last_dismount))

## The dead horse is solid; stepping over it is a short scripted vault when the
## player walks into it. Collisions go off for the arc and come back on the far side.
func _try_vault() -> void:
	if _vault_active or _vault_cooldown > 0.0 or _mounted:
		return
	if not is_instance_valid(horse) or not is_instance_valid(player):
		return
	if not bool(horse.get("dead")) or not player.is_on_floor():
		return
	var body: Node3D = horse.get("corpse") as Node3D
	if not is_instance_valid(body):
		return
	if not InputMap.has_action(&"preview_move_forward") \
			or not Input.is_action_pressed(&"preview_move_forward"):
		return
	var visual: Node3D = player.get("_visual") as Node3D
	if not is_instance_valid(visual):
		return
	var facing: Vector3 = visual.global_transform.basis.z
	facing.y = 0.0
	if facing.length_squared() < 0.01:
		return
	facing = facing.normalized()
	var to_body: Vector3 = body.global_position - player.global_position
	to_body.y = 0.0
	var distance := to_body.length()
	if distance > VAULT_RANGE or distance < 0.2:
		return
	if facing.dot(to_body.normalized()) < 0.55:
		return
	# Land beyond the whole body, not on top of it: the corpse AABB gives the half
	# extent along the vault direction.
	var extent := _corpse_extent(body, facing)
	var end: Vector3 = body.global_position + facing * (extent + 0.75)
	end.y = _ground_height_excluding(body, end)
	if not is_finite(end.y):
		return
	# A wall in the landing zone cancels or shortens the vault; a wall right in front
	# cancels it outright so the player does not hop into masonry.
	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP * 0.9, end + Vector3.UP * 0.9, 1)
		query.exclude = [player.get_rid(), horse.get_rid(), body.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var wall_distance: float = player.global_position.distance_to(hit.position)
			if wall_distance < 1.2:
				return
			var wall: Vector3 = hit.position - facing * 0.40
			wall.y = _ground_height_excluding(body, wall)
			if is_finite(wall.y):
				end = wall
			else:
				return
	_vault_active = true
	_vault_time = 0.0
	_vault_start = player.global_position
	_vault_end = end
	_vault_heading = atan2(-facing.x, -facing.z)
	_vault_layer = player.collision_layer
	_vault_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	_vaults += 1
	print("DSH_HORSE_VAULT start=", _vault_start, " end=", _vault_end, " facing=", facing)

## Half extent of the corpse's collision AABB along a flat direction.
func _corpse_extent(body: RigidBody3D, direction: Vector3) -> float:
	var box := AABB()
	var first := true
	for child: Node in body.get_children():
		if not child is CollisionShape3D:
			continue
		var collider := child as CollisionShape3D
		var shape := collider.shape
		if shape == null:
			continue
		var half := Vector3.ZERO
		if shape is BoxShape3D:
			half = (shape as BoxShape3D).size * 0.5
		elif shape is SphereShape3D:
			half = Vector3.ONE * (shape as SphereShape3D).radius
		elif shape is CapsuleShape3D:
			var capsule := shape as CapsuleShape3D
			half = Vector3(capsule.radius, capsule.height * 0.5 + capsule.radius, capsule.radius)
		else:
			continue
		var world := collider.global_transform * AABB(-half, half * 2.0)
		box = world if first else box.merge(world)
		first = false
	if first:
		return 1.2
	var extent := absf(direction.x) * box.size.x * 0.5 + absf(direction.z) * box.size.z * 0.5
	return maxf(0.8, extent)

func _ground_height_excluding(body: Node3D, at: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return at.y
	var ray := PhysicsRayQueryParameters3D.new()
	ray.from = Vector3(at.x, at.y + 6.0, at.z)
	ray.to = Vector3(at.x, at.y - 30.0, at.z)
	ray.collision_mask = 1
	ray.exclude = [player.get_rid(), horse.get_rid(), body.get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(ray)
	return float(hit.position.y) + 0.02 if not hit.is_empty() else at.y

func _tick_vault(delta: float) -> void:
	_vault_time += delta / VAULT_DURATION
	var t := clampf(_vault_time, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var at := _vault_start.lerp(_vault_end, eased)
	at.y = lerpf(_vault_start.y, _vault_end.y, eased) + sin(PI * t) * VAULT_ARC
	player.global_position = at
	if t < 1.0:
		return
	_vault_active = false
	player.global_position = _vault_end
	player.velocity = Vector3.ZERO
	player.collision_layer = _vault_layer
	player.collision_mask = _vault_mask
	player.set_physics_process(true)
	player._heading = _vault_heading
	var visual: Node3D = player.get("_visual") as Node3D
	if is_instance_valid(visual):
		visual.rotation.y = _vault_heading + deg_to_rad(float(player.get("visual_yaw_degrees")))
	_vault_cooldown = 0.6
	print("DSH_HORSE_VAULT_END at=", player.global_position)

func _update_hud(dead: bool) -> void:
	# How centred is the horse in the actual view? Both the E plate and the HP plate
	# are look-driven on foot: turning away (or walking off) hides them, so they do
	# not sit in front of the eyes while the player is doing something else.
	var view_dot := -1.0
	if is_instance_valid(horse):
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var target: Vector3 = horse.global_position + Vector3.UP * 1.25
			var to_target: Vector3 = target - camera.global_position
			if to_target.length_squared() > 0.04:
				view_dot = (-camera.global_transform.basis.z).dot(to_target.normalized())
	var horse_gap := player.global_position.distance_to(horse.global_position) \
		if is_instance_valid(player) and is_instance_valid(horse) else INF
	var text := ""
	if not dead:
		if _mounted:
			text = "Слезть с лошади"
		elif _can_ride() and horse_gap <= MOUNT_RANGE and view_dot >= 0.78:
			text = "Сесть на лошадь"
	var state := 0 if text.is_empty() else (1 if _mounted else 2)
	if state != _banner_state:
		_banner_state = state
		if text.is_empty():
			_banner.visible = false
		else:
			_banner_label.text = text
			_banner.visible = true
			_banner.reset_size()
			_place_world_banner()
	# HP plate: while riding, or on foot only when the camera is actually centred on
	# the horse and it is still within reach of the HUD.
	var hp := float(horse.get("hp"))
	if not is_equal_approx(hp, _hp_value):
		_hp_value = hp
		_hp_label.text = "ЛОШАДЬ  %d / %d" % [int(ceil(hp)), int(HORSE_MAX_HP)]
		_hp_fill.size = Vector2(maxf(0.0, _hp_track_width * clampf(hp / HORSE_MAX_HP, 0.0, 1.0)), 7.0)
		_hp_fill.color = Color(0.62, 0.10, 0.11) if hp > 35.0 else Color(0.78, 0.28, 0.08)
	var show_hp := not dead and horse_gap <= HP_VISIBLE_RANGE and (_mounted or view_dot >= 0.90)
	_hp_panel.visible = show_hp
	if show_hp:
		_layout_top_center(_hp_panel, 70.0)

func _place_world_banner() -> void:
	if not is_instance_valid(_banner) or not _banner.visible or not is_instance_valid(horse):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := horse.global_position + Vector3.UP * 2.0
	if camera.is_position_behind(at):
		return
	var screen := camera.unproject_position(at)
	var view := get_viewport().get_visible_rect().size
	_banner.reset_size()
	_banner.position = Vector2(
		clampf(screen.x - _banner.size.x * 0.5, 12.0, maxf(12.0, view.x - _banner.size.x - 12.0)),
		clampf(screen.y - _banner.size.y - 12.0, 12.0, maxf(12.0, view.y - _banner.size.y - 12.0)))

func _layout_top_center(control: Control, top: float) -> void:
	var viewport := get_viewport()
	if viewport != null:
		_viewport_size = viewport.get_visible_rect().size
	var size := control.size
	if size.x <= 0.0:
		control.reset_size()
		size = control.size
	control.position = Vector2((_viewport_size.x - size.x) * 0.5, top)

func snapshot() -> Dictionary:
	var horse_snapshot: Dictionary = horse.snapshot() if is_instance_valid(horse) else {}
	return {"status": status, "mounted": _mounted, "mounts": _mounts, "dismounts": _dismounts,
		"vaults": _vaults, "vault_active": _vault_active,
		"last_dismount": _last_dismount.duplicate(true), "horse": horse_snapshot,
		"player": player.global_position if is_instance_valid(player) else Vector3.ZERO,
		"mount_mode": bool(player.get("_mount_mode")) if is_instance_valid(player) else false,
		"player_authority": str(player.get("_pose_authority")) if is_instance_valid(player) else "",
		"player_layer": player.collision_layer if is_instance_valid(player) else -1,
		"player_mask": player.collision_mask if is_instance_valid(player) else -1,
		"rider_pose": _pose.status() if _pose != null else {},
		"banner": _banner_label.text if is_instance_valid(_banner) and _banner.visible else "",
		"hp_panel_visible": _hp_panel.visible if is_instance_valid(_hp_panel) else false,
		"hp_shown": _hp_value,
		"seat_gap": player.global_position.distance_to(horse.seat_world()) if is_instance_valid(horse) and is_instance_valid(player) else -1.0}

func dispose() -> void:
	if _mounted:
		dismount_now()
	if _pose != null:
		_pose.dispose()
		_pose = null
	if is_instance_valid(horse):
		var corpse: Variant = horse.get("corpse")
		if corpse is Node and is_instance_valid(corpse):
			(corpse as Node).queue_free()
		horse.queue_free()
	horse = null
	queue_free()
