extends Node3D
## DSH_BARRELS: powder barrels for the siege balloon.
##
## E near a barrel picks it up with the very same two-handed hug the catapult
## stone uses. Carry it to the balloon: boarding hands it to the basket as cargo.
## G in the basket drops a barrel; it falls, bursts with the city C4 blast effect
## and forwards the same explosion into the castle / camp damage owners.

const BlastFX = preload("res://scripts/destruction/palazzo/blast_fx45.gd")
const PICK_RANGE := 2.5
const BLAST_POWER := 1400.0
const BLAST_RADIUS := 3.8
const BARREL_COUNT := 3

var world: Node3D
var player: CharacterBody3D
var status := "disabled"
var carrying := false
var _barrel_wood_mesh: ArrayMesh
var _barrel_metal_mesh: ArrayMesh
var _barrel_white_mesh: ArrayMesh
var _barrel_black_mesh: ArrayMesh
var _barrel_spark_mesh: SphereMesh
var _barrel_wood_mat: StandardMaterial3D
var _barrel_metal_mat: StandardMaterial3D
var _barrel_white_mat: StandardMaterial3D
var _barrel_black_mat: StandardMaterial3D
var _barrel_spark_mat: StandardMaterial3D
var barrels: Array[Node3D] = []
var last_explosion: Dictionary = {}

var _carried: Node3D
var _fx: Node3D
var _prompt: PanelContainer
var _prompt_label: Label
var _prompt_state := -1
var _prompt_tween: Tween
var _throw_key: PanelContainer
var _throw_label: Label
var _events := 0
var _falling: Array[Dictionary] = []
var _skeleton: Skeleton3D
var _arm_bones: Array[int] = []
var _arm_rest: Array[Quaternion] = []
var _arms_hugging := false

func install(world_in: Node3D, player_in: CharacterBody3D) -> Dictionary:
	if is_instance_valid(world) or not is_instance_valid(world_in) or player_in == null:
		return {"ok": false, "reason": "barrel_install"}
	world = world_in
	player = player_in
	var heading := float(player.get("_heading"))
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(cos(heading), 0.0, -sin(heading))
	var spots: Array[Vector3] = [
		player.global_position + forward * 3.0 + right * 2.2,
		player.global_position + forward * 4.6 + right * 2.8,
		player.global_position + forward * 3.6 + right * 3.8,
	]
	for index: int in mini(BARREL_COUNT, spots.size()):
		var at := spots[index]
		at.y = _ground_height(at)
		var barrel: Node3D = _barrel_model(self, false)
		barrel.name = "PowderBarrel%d" % index
		barrel.global_position = at
		barrels.append(barrel)
	_fx = BlastFX.new()
	var fx_setup: Dictionary = _fx.configure(world)
	if not bool(fx_setup.get("ok", false)):
		_fx = null
	_build_prompt()
	status = "ready"
	print("DSH_BARRELS_STATUS ready count=", barrels.size(), " fx=", bool(fx_setup.get("ok", false)))
	return {"ok": true, "count": barrels.size(), "fx": bool(fx_setup.get("ok", false))}

func _ground_height(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return at.y
	var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 4.0, at.z), Vector3(at.x, at.y - 20.0, at.z), 1)
	var excludes: Array[RID] = []
	if is_instance_valid(player):
		excludes.append(player.get_rid())
	if is_instance_valid(world):
		var balloon_host: Variant = world.get("preview_balloon")
		if is_instance_valid(balloon_host):
			var balloon: Variant = balloon_host.get("balloon")
			if is_instance_valid(balloon):
				excludes.append((balloon as CollisionObject3D).get_rid())
	ray.exclude = excludes
	var hit: Dictionary = space.intersect_ray(ray)
	return float(hit.position.y) + 0.02 if not hit.is_empty() else at.y

## ---------------------------------------------------------------- model
func _ensure_barrel_assets() -> void:
	if _barrel_wood_mesh != null:
		return
	_barrel_wood_mat = StandardMaterial3D.new()
	_barrel_wood_mat.albedo_color = Color(0.34, 0.22, 0.11)
	_barrel_wood_mat.roughness = 0.92
	_barrel_metal_mat = StandardMaterial3D.new()
	_barrel_metal_mat.albedo_color = Color(0.28, 0.28, 0.26)
	_barrel_metal_mat.metallic = 0.65
	_barrel_metal_mat.roughness = 0.45
	_barrel_white_mat = StandardMaterial3D.new()
	_barrel_white_mat.albedo_color = Color(0.84, 0.80, 0.68)
	_barrel_white_mat.roughness = 0.85
	_barrel_black_mat = StandardMaterial3D.new()
	_barrel_black_mat.albedo_color = Color(0.06, 0.05, 0.04)
	_barrel_black_mat.roughness = 0.8
	_barrel_spark_mat = StandardMaterial3D.new()
	_barrel_spark_mat.albedo_color = Color(1.0, 0.55, 0.12)
	_barrel_spark_mat.emission_enabled = true
	_barrel_spark_mat.emission = Color(1.0, 0.40, 0.08)
	_barrel_spark_mat.emission_energy_multiplier = 3.0
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := CylinderMesh.new()
	body.top_radius = 0.30
	body.bottom_radius = 0.34
	body.height = 0.66
	body.radial_segments = 14
	wood.append_from(body, 0, Transform3D(Basis(), Vector3(0.0, 0.35, 0.0)))
	for i: int in 12:
		var angle := TAU * float(i) / 12.0
		var stave := BoxMesh.new()
		stave.size = Vector3(0.10, 0.63, 0.028)
		wood.append_from(stave, 0, Transform3D(Basis(Vector3.UP, -angle), Vector3(sin(angle) * 0.335, 0.35, cos(angle) * 0.335)))
	_barrel_wood_mesh = wood.commit()
	var metal := SurfaceTool.new()
	metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: float in [0.14, 0.35, 0.56]:
		var hoop := CylinderMesh.new()
		hoop.top_radius = 0.35
		hoop.bottom_radius = 0.35
		hoop.height = 0.055
		hoop.radial_segments = 14
		metal.append_from(hoop, 0, Transform3D(Basis(), Vector3(0.0, y, 0.0)))
		for i: int in 8:
			var angle := TAU * float(i) / 8.0
			var rivet := BoxMesh.new()
			rivet.size = Vector3(0.032, 0.032, 0.018)
			metal.append_from(rivet, 0, Transform3D(Basis(Vector3.UP, -angle), Vector3(sin(angle) * 0.352, y, cos(angle) * 0.352)))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.27
	lid.bottom_radius = 0.30
	lid.height = 0.06
	metal.append_from(lid, 0, Transform3D(Basis(), Vector3(0.0, 0.70, 0.0)))
	var bung := CylinderMesh.new()
	bung.top_radius = 0.05
	bung.bottom_radius = 0.055
	bung.height = 0.05
	metal.append_from(bung, 0, Transform3D(Basis(), Vector3(0.0, 0.73, 0.0)))
	var fuse := CylinderMesh.new()
	fuse.top_radius = 0.018
	fuse.bottom_radius = 0.022
	fuse.height = 0.16
	metal.append_from(fuse, 0, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0.03, 0.81, 0.0)))
	_barrel_metal_mesh = metal.commit()
	var white := SurfaceTool.new()
	white.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stripe := CylinderMesh.new()
	stripe.top_radius = 0.347
	stripe.bottom_radius = 0.347
	stripe.height = 0.105
	stripe.radial_segments = 14
	white.append_from(stripe, 0, Transform3D(Basis(), Vector3(0.0, 0.42, 0.0)))
	_barrel_white_mesh = white.commit()
	var black := SurfaceTool.new()
	black.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emblem := BoxMesh.new()
	emblem.size = Vector3(0.10, 0.10, 0.014)
	black.append_from(emblem, 0, Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0.0, 0.42, 0.352)))
	_barrel_black_mesh = black.commit()
	_barrel_spark_mesh = SphereMesh.new()
	_barrel_spark_mesh.radius = 0.035
	_barrel_spark_mesh.height = 0.07

## Detailed powder barrel: staved body, riveted iron hoops, lid with a bung,
## fuse, a white powder stripe and a black warning emblem. All static parts are
## merged into four cached meshes shared by every barrel; only the burning spark
## is separate, so each barrel costs five draw calls.
func _barrel_model(parent: Node3D, carried: bool) -> Node3D:
	_ensure_barrel_assets()
	var root := Node3D.new()
	var parts: Array = [
		[_barrel_wood_mesh, _barrel_wood_mat], [_barrel_metal_mesh, _barrel_metal_mat],
		[_barrel_white_mesh, _barrel_white_mat], [_barrel_black_mesh, _barrel_black_mat],
	]
	for part: Array in parts:
		var node := MeshInstance3D.new()
		node.mesh = part[0]
		node.material_override = part[1]
		root.add_child(node)
	var spark := MeshInstance3D.new()
	spark.mesh = _barrel_spark_mesh
	spark.material_override = _barrel_spark_mat
	spark.position = Vector3(0.03, 0.895, 0.0)
	root.add_child(spark)
	root.scale = Vector3.ONE * (0.62 if carried else 1.0)
	parent.add_child(root)
	return root


## ---------------------------------------------------------------- prompt
func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BarrelPrompt"
	layer.layer = 14
	add_child(layer)
	_prompt = PanelContainer.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.85)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	_prompt.add_theme_stylebox_override("panel", style)
	layer.add_child(_prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_prompt.add_child(row)
	var key := PanelContainer.new()
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.95, 0.78, 0.22)
	key_style.set_corner_radius_all(6)
	key.add_theme_stylebox_override("panel", key_style)
	row.add_child(key)
	var key_label := Label.new()
	key_label.text = "E"
	key_label.add_theme_font_size_override("font_size", 18)
	key_label.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
	key.add_child(key_label)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	row.add_child(_prompt_label)
	_throw_key = PanelContainer.new()
	var throw_style := StyleBoxFlat.new()
	throw_style.bg_color = Color(0.95, 0.78, 0.22)
	throw_style.set_corner_radius_all(6)
	_throw_key.add_theme_stylebox_override("panel", throw_style)
	row.add_child(_throw_key)
	var g_label := Label.new()
	g_label.text = "G"
	g_label.add_theme_font_size_override("font_size", 18)
	g_label.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
	_throw_key.add_child(g_label)
	_throw_label = Label.new()
	_throw_label.text = "Бросить"
	_throw_label.add_theme_font_size_override("font_size", 18)
	_throw_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	row.add_child(_throw_label)
	_throw_key.visible = false
	_throw_label.visible = false
	_prompt.visible = false

func _physics_process(delta: float) -> void:
	_check_weapon_hits()
	_place_world_prompt()
	if not is_instance_valid(player):
		return
	_update_prompt()
	_update_falling(delta)
	if carrying:
		_hug_arms(true)

## The literal catapult-stone hug, reused for the barrel: upper arms swing in and
## forward, forearms fold around the cargo.
func _find_skeleton() -> void:
	if is_instance_valid(_skeleton) or not is_instance_valid(player):
		return
	var found: Array[Node] = player.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	_skeleton = found[0] as Skeleton3D
	for bone_name: String in ["upperarm_l", "forearm_l", "upperarm_r", "forearm_r"]:
		var bone: int = _skeleton.find_bone(bone_name)
		_arm_bones.append(bone)
		_arm_rest.append(_skeleton.get_bone_pose_rotation(bone) if bone >= 0 else Quaternion())

func _hug_arms(on: bool) -> void:
	_find_skeleton()
	if not is_instance_valid(_skeleton) or (not on and not _arms_hugging):
		return
	_arms_hugging = on
	for index: int in _arm_bones.size():
		var bone: int = _arm_bones[index]
		if bone < 0:
			continue
		var rest: Quaternion = _arm_rest[index]
		if not on:
			_skeleton.set_bone_pose_rotation(bone, rest)
			continue
		var side: float = -1.0 if index < 2 else 1.0
		var swing := Quaternion(Vector3.UP, side * 0.55) * Quaternion(Vector3.FORWARD, side * 0.95)
		var fold := Quaternion(Vector3.RIGHT, -0.95)
		_skeleton.set_bone_pose_rotation(bone, rest * swing if index % 2 == 0 else rest * fold)

func _update_prompt() -> void:
	var text := ""
	if carrying:
		var near_balloon := false
		var balloon_host: Variant = world.get("preview_balloon") if is_instance_valid(world) else null
		if is_instance_valid(balloon_host):
			var balloon: Variant = balloon_host.get("balloon")
			if is_instance_valid(balloon) and is_instance_valid(player):
				near_balloon = player.global_position.distance_to(balloon.global_position) < 3.6
		text = "Поставить в шар" if near_balloon else "Поставить"
	elif _nearest_barrel() != null:
		text = "Поднять бочку"
	var state := 0 if text.is_empty() else (1 if carrying else 2)
	if is_instance_valid(_throw_key):
		_throw_key.visible = carrying
		_throw_label.visible = carrying
	if state != _prompt_state:
		_prompt_state = state
		if text.is_empty():
			_animate_prompt(false)
		else:
			_prompt_label.text = text
			_prompt.visible = true
			_prompt.reset_size()
			_place_world_prompt()
			_animate_prompt(true)

func _animate_prompt(show: bool) -> void:
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.pivot_offset = _prompt.size * 0.5
	if show:
		_prompt.visible = true
		_prompt.modulate.a = 0.0
		_prompt.scale = Vector2(0.86, 0.86)
		_prompt_tween = create_tween().set_parallel(true)
		_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.16)
		_prompt_tween.tween_property(_prompt, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_prompt_tween = create_tween().set_parallel(true)
		_prompt_tween.tween_property(_prompt, "modulate:a", 0.0, 0.12)
		_prompt_tween.tween_property(_prompt, "scale", Vector2(0.92, 0.92), 0.12)
		_prompt_tween.chain().tween_callback(func() -> void: _prompt.visible = false)

func _place_world_prompt() -> void:
	if not is_instance_valid(_prompt) or not _prompt.visible or not is_instance_valid(player):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := player.global_position + Vector3.UP * 1.9
	if not carrying:
		var barrel: Node3D = _nearest_barrel()
		if is_instance_valid(barrel):
			at = barrel.global_position + Vector3.UP * 0.9
	if camera.is_position_behind(at):
		return
	var screen := camera.unproject_position(at)
	var view := get_viewport().get_visible_rect().size
	_prompt.reset_size()
	_prompt.position = Vector2(
		clampf(screen.x - _prompt.size.x * 0.5, 12.0, maxf(12.0, view.x - _prompt.size.x - 12.0)),
		clampf(screen.y - _prompt.size.y - 12.0, 12.0, maxf(12.0, view.y - _prompt.size.y - 12.0)))

func _layout_prompt() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var size := _prompt.size
	if size.x <= 0.0:
		_prompt.reset_size()
		size = _prompt.size
	_prompt.position = Vector2((viewport.get_visible_rect().size.x - size.x) * 0.5, 26.0)

func _nearest_barrel() -> Node3D:
	if not is_instance_valid(player):
		return null
	for barrel: Node3D in barrels:
		if not is_instance_valid(barrel) or not barrel.visible:
			continue
		if player.global_position.distance_to(barrel.global_position) <= PICK_RANGE:
			return barrel
	return null

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_G:
		if carrying and throw_carried():
			get_viewport().set_input_as_handled()
		return
	if code != KEY_E:
		return
	if not bool(player.get("_free_mouse_look")):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if code == KEY_G:
		if carrying and throw_carried():
			get_viewport().set_input_as_handled()
		return
	if carrying:
		place_carried()
		get_viewport().set_input_as_handled()
		return
	var barrel: Node3D = _nearest_barrel()
	if barrel == null:
		return
	if pick_up(barrel):
		get_viewport().set_input_as_handled()

func wants_e() -> bool:
	if carrying:
		return false
	return _nearest_barrel() != null

## ---------------------------------------------------------------- carry
func pick_up(barrel: Node3D) -> bool:
	if carrying or not is_instance_valid(barrel):
		return false
	var visual: Node3D = player.get("_visual") as Node3D
	if not is_instance_valid(visual):
		return false
	barrel.visible = false
	_carried = _barrel_model(visual, true)
	_carried.position = Vector3(0.0, 1.05, 0.42)
	_carried.rotation.y = 0.2
	var weapons: Node = world.get("preview_weapons") if is_instance_valid(world) else null
	if is_instance_valid(weapons) and weapons.has_method("begin_catapult_stone_carry"):
		weapons.call("begin_catapult_stone_carry")
	carrying = true
	_prompt_state = -1
	print("DSH_BARRELS_PICKUP at=", barrel.global_position)
	return true

func _end_carry() -> void:
	if not carrying:
		return
	carrying = false
	if is_instance_valid(_carried):
		_carried.queue_free()
	_carried = null
	var weapons: Node = world.get("preview_weapons") if is_instance_valid(world) else null
	if is_instance_valid(weapons) and weapons.has_method("end_catapult_stone_carry"):
		weapons.call("end_catapult_stone_carry")
	_hug_arms(false)
	_prompt_state = -1

## Called by the balloon when the pilot boards while holding a barrel.
func take_carried() -> bool:
	if not carrying:
		return false
	_end_carry()
	return true

func throw_carried() -> bool:
	if not carrying or not is_instance_valid(player):
		return false
	var heading := float(player.get("_heading"))
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	var at := player.global_position + forward * 1.0 + Vector3.UP * 0.4
	var velocity := forward * 0.5 + Vector3.UP * 0.5
	var barrel: Node3D = _barrel_model(self, false)
	barrel.global_position = at
	_falling.append({"node": barrel, "velocity": velocity, "age": 0.0})
	_end_carry()
	return true

func carry_from_slot(model: Node3D) -> bool:
	if carrying or not is_instance_valid(model) or not is_instance_valid(player):
		return false
	var visual: Node3D = player.get("_visual") as Node3D
	if not is_instance_valid(visual):
		return false
	model.queue_free()
	_carried = _barrel_model(visual, true)
	_carried.position = Vector3(0.0, 1.05, 0.42)
	_carried.rotation.y = 0.2
	var weapons: Node = world.get("preview_weapons") if is_instance_valid(world) else null
	if is_instance_valid(weapons) and weapons.has_method("begin_catapult_stone_carry"):
		weapons.call("begin_catapult_stone_carry")
	carrying = true
	_prompt_state = -1
	print("DSH_BARRELS_PICKUP_FLOOR")
	return true

func place_carried() -> bool:
	if not carrying or not is_instance_valid(world) or not is_instance_valid(player):
		return false
	var balloon_host: Variant = world.get("preview_balloon")
	if is_instance_valid(balloon_host) and balloon_host.has_method("load_barrel"):
		var balloon: Variant = balloon_host.get("balloon")
		if is_instance_valid(balloon) and player.global_position.distance_to(balloon.global_position) < 3.6:
			if bool(balloon_host.call("load_barrel", self)):
				_end_carry()
				print("DSH_BARRELS_PLACE_IN_BALLOON")
				return true
	drop_carried()
	return false

func drop_carried() -> void:
	if not carrying:
		return
	_end_carry()
	var forward := Vector3(-sin(float(player.get("_heading"))), 0.0, -cos(float(player.get("_heading"))))
	var at := player.global_position + forward * 1.1
	at.y = _ground_height(at)
	var barrel: Node3D = _barrel_model(self, false)
	barrel.global_position = at
	barrels.append(barrel)
	print("DSH_BARRELS_DROP at=", at)

func _segment_distance(a: Vector3, b: Vector3, point: Vector3) -> float:
	var ab := b - a
	var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _explode_barrel_at(index: int) -> void:
	if index < 0 or index >= barrels.size():
		return
	var barrel: Node3D = barrels[index]
	if not is_instance_valid(barrel):
		barrels.remove_at(index)
		return
	var at := barrel.global_position + Vector3.UP * 0.45
	barrels.remove_at(index)
	barrel.queue_free()
	explode_at(at)
	print("DSH_BARRELS_WEAPON_HIT at=", at)

## One strong sword blow (both mouse buttons or a double click) or one arrow
## touching a barrel detonates it immediately.
func _check_weapon_hits() -> void:
	if not is_instance_valid(player) or barrels.is_empty():
		return
	var sword: Variant = player.get("_sword_host")
	if is_instance_valid(sword) and sword.has_method("strong_strike31") and bool(sword.call("strong_strike31")) \
			and sword.has_method("blade_segment31"):
		var segment: Array = sword.call("blade_segment31")
		if segment.size() == 2:
			var blade_a: Vector3 = segment[0]
			var blade_b: Vector3 = segment[1]
			for index: int in range(barrels.size() - 1, -1, -1):
				var barrel: Node3D = barrels[index]
				if not is_instance_valid(barrel) or not barrel.visible:
					continue
				if _segment_distance(blade_a, blade_b, barrel.global_position + Vector3.UP * 0.45) <= 0.45:
					_explode_barrel_at(index)
					return
	var bow: Variant = player.get("_bow_host")
	if is_instance_valid(bow):
		var arrows: Variant = bow.get("_arrows")
		if arrows is Array:
			for index: int in range(barrels.size() - 1, -1, -1):
				var barrel: Node3D = barrels[index]
				if not is_instance_valid(barrel) or not barrel.visible:
					continue
				var center := barrel.global_position + Vector3.UP * 0.45
				for entry: Dictionary in arrows:
					var node: Node3D = entry.get("node")
					if is_instance_valid(node) and node.visible and node.global_position.distance_to(center) <= 1.0:
						_explode_barrel_at(index)
						return

## ---------------------------------------------------------------- throw + blast
func throw_barrel(at: Vector3, initial_velocity: Vector3 = Vector3(0.0, -1.5, 0.0)) -> bool:
	var barrel: Node3D = _barrel_model(self, false)
	barrel.global_position = at
	_falling.append({"node": barrel, "velocity": initial_velocity, "age": 0.0})
	return true

func _update_falling(delta: float) -> void:
	for index: int in range(_falling.size() - 1, -1, -1):
		var entry: Dictionary = _falling[index]
		var node: Node3D = entry.get("node")
		if not is_instance_valid(node):
			_falling.remove_at(index)
			continue
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		velocity.y -= 9.8 * delta
		node.global_position += velocity * delta
		var age := float(entry.get("age", 0.0)) + delta
		entry["velocity"] = velocity
		entry["age"] = age
		var ground := _ground_height(node.global_position)
		if age > 12.0 or (velocity.y < 0.0 and node.global_position.y <= ground + 0.15):
			explode_at(Vector3(node.global_position.x, ground + 0.1, node.global_position.z))
			node.queue_free()
			_falling.remove_at(index)
			continue
		_falling[index] = entry

func explode_at(at: Vector3, normal: Vector3 = Vector3.UP) -> Dictionary:
	_events += 1
	var event_id := "powder-barrel:%d" % _events
	var visual: Dictionary = {}
	if is_instance_valid(_fx):
		visual = _fx.call("emit_blast", at, normal, BLAST_POWER, BLAST_RADIUS)
	var balloon_host: Variant = world.get("preview_balloon") if is_instance_valid(world) else null
	if is_instance_valid(balloon_host):
		var balloon: Variant = balloon_host.get("balloon")
		if is_instance_valid(balloon) and (balloon as Node3D).global_position.distance_to(at) < BLAST_RADIUS + 2.5:
			balloon.call("damage_balloon", 1)
	var castle_result: Dictionary = {}
	var castle: Variant = world.get("preview_castle") if is_instance_valid(world) else null
	if is_instance_valid(castle) and castle.has_method("apply_explosion"):
		var result: Variant = castle.call("apply_explosion", {
			"position": at, "radius": BLAST_RADIUS, "power": BLAST_POWER,
			"direction": normal, "event_id": event_id,
		})
		if result is Dictionary:
			castle_result = result
	var dressing_hits := 0
	var battlefield: Variant = world.get("preview_battlefield") if is_instance_valid(world) else null
	if is_instance_valid(battlefield):
		var dressing := (battlefield as Node3D).get_node_or_null("SiegeWallDressing")
		if is_instance_valid(dressing) and dressing.has_method("apply_damage"):
			dressing_hits += int(dressing.call("apply_damage", at, BLAST_RADIUS, BLAST_POWER))
		var camp := (battlefield as Node3D).get_node_or_null("BattlefieldProps")
		if is_instance_valid(camp) and camp.has_method("apply_damage"):
			dressing_hits += int(camp.call("apply_damage", at, BLAST_RADIUS, BLAST_POWER, "c4"))
	last_explosion = {"ok": bool(castle_result.get("ok", false)) or dressing_hits > 0,
		"castle": castle_result, "dressing_groups": dressing_hits, "visual": visual, "at": at}
	print("DSH_BARRELS_EXPLODE ", JSON.stringify(last_explosion))
	return last_explosion

func snapshot() -> Dictionary:
	return {"status": status, "carrying": carrying, "barrels_left": _visible_barrels(),
		"last_explosion": last_explosion, "prompt": _prompt_label.text if is_instance_valid(_prompt) and _prompt.visible else ""}

func _visible_barrels() -> int:
	var count := 0
	for barrel: Node3D in barrels:
		if is_instance_valid(barrel) and barrel.visible:
			count += 1
	return count

func dispose() -> void:
	_end_carry()
	for barrel: Node3D in barrels:
		if is_instance_valid(barrel):
			barrel.queue_free()
	barrels.clear()
	for entry: Dictionary in _falling:
		var node: Node3D = entry.get("node")
		if is_instance_valid(node):
			node.queue_free()
	_falling.clear()
	if is_instance_valid(_fx) and _fx.has_method("dispose"):
		_fx.call("dispose")
	_fx = null
