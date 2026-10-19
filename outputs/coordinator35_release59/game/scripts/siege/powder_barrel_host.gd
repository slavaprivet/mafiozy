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
func _barrel_model(parent: Node3D, carried: bool) -> Node3D:
	var root := Node3D.new()
	var scale := 0.62 if carried else 1.0
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.22, 0.11)
	wood.roughness = 0.92
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.28, 0.28, 0.26)
	metal.metallic = 0.65
	metal.roughness = 0.45
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.30
	body_mesh.bottom_radius = 0.34
	body_mesh.height = 0.66
	body_mesh.radial_segments = 14
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = wood
	body.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(body)
	for y: float in [0.14, 0.56]:
		var band_mesh := CylinderMesh.new()
		band_mesh.top_radius = 0.345
		band_mesh.bottom_radius = 0.345
		band_mesh.height = 0.055
		band_mesh.radial_segments = 14
		var band := MeshInstance3D.new()
		band.mesh = band_mesh
		band.material_override = metal
		band.position = Vector3(0.0, y, 0.0)
		root.add_child(band)
	var lid_mesh := CylinderMesh.new()
	lid_mesh.top_radius = 0.27
	lid_mesh.bottom_radius = 0.30
	lid_mesh.height = 0.06
	var lid := MeshInstance3D.new()
	lid.mesh = lid_mesh
	lid.material_override = metal
	lid.position = Vector3(0.0, 0.70, 0.0)
	root.add_child(lid)
	var fuse_mesh := CylinderMesh.new()
	fuse_mesh.top_radius = 0.018
	fuse_mesh.bottom_radius = 0.022
	fuse_mesh.height = 0.16
	var fuse := MeshInstance3D.new()
	fuse.mesh = fuse_mesh
	fuse.material_override = metal
	fuse.position = Vector3(0.0, 0.80, 0.0)
	root.add_child(fuse)
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.035
	spark_mesh.height = 0.07
	var spark := MeshInstance3D.new()
	spark.mesh = spark_mesh
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = Color(1.0, 0.55, 0.12)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.40, 0.08)
	spark_mat.emission_energy_multiplier = 3.0
	spark.material_override = spark_mat
	spark.position = Vector3(0.0, 0.89, 0.0)
	root.add_child(spark)
	root.scale = Vector3.ONE * scale
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
		text = "Поставить"
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
			_layout_prompt()
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
		drop_carried()
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
