extends Node3D
## Sally port: a small postern through the left gatehouse pier, beside the main gate.
##
## It is a real passage through the wall, not a painted panel. The door is barred from
## the inside with a sliding oak beam; the animation is bar first, then leaf, and the
## reverse on closing. Everything is merged into a handful of meshes.

const Art = preload("res://scripts/siege/gate_defense_art.gd")

const CENTRE_X := -8.20
const OPEN_HALF := 1.00          ## the brick opening is 2.0 m wide, y 0..2.7
const OPEN_HEIGHT := 2.70
const DOOR_HALF := 0.65
const DOOR_HEIGHT := 2.30
const WALL_Z := 68.00
const WALL_DEPTH := 1.76
const DOOR_Z := 68.72
const HINGE_X := CENTRE_X - DOOR_HALF
const BAR_Z := 67.15
const BAR_Y := 1.06
const BAR_SLIDE := 1.50

var _castle: Node3D
var _player: CharacterBody3D
var _world: Node3D

var _door: AnimatableBody3D
var _bar: Node3D
var _bar_base_x := 0.0
var _open := false
var _bar_value := 0.0
var _door_value := 0.0

var _sfx_bar: AudioStreamWAV
var _sfx_creak: AudioStreamWAV
var _stats := {}


func install(castle: Node3D, player: CharacterBody3D, world: Node3D) -> Dictionary:
	_castle = castle
	_player = player
	_world = world
	name = "SallyPort"
	_sfx_bar = Art.sfx(0.35, 96.0, 0.55, 14.0, -0.4, 41)
	_sfx_creak = Art.sfx(0.80, 180.0, 0.35, 5.0, 0.65, 42)
	_build_stone_frame()
	_build_door()
	_build_bar()
	_build_threshold()
	_build_lanterns()
	_stats = {"open": false, "bar": 0.0, "door": 0.0}
	return {"ok": true, "stats": _stats}


func get_stats() -> Dictionary:
	var result := _stats.duplicate(true)
	result["open"] = _open
	result["bar"] = _bar_value
	result["door_angle"] = 1.72 * smoothstep(0.0, 1.0, _door_value)
	result["door_value"] = _door_value
	result["passable"] = _door_value > 0.85
	return result


func interaction_action() -> Dictionary:
	if not is_instance_valid(_player):
		return {}
	var at := global_position + Vector3(CENTRE_X, 1.15, WALL_Z)
	if _player.global_position.distance_to(at) > 2.45:
		return {}
	var label := "Открыть калитку" if not _open else "Закрыть калитку"
	if not _open and _bar_value > 0.05:
		label = "Открыть калитку (засов)"
	return {"owner": "castle_sally", "key": "F", "label": label,
		"world": global_position + Vector3(CENTRE_X, 2.95, WALL_Z + 0.95)}


func interact() -> bool:
	if not is_instance_valid(_player):
		return false
	var at := global_position + Vector3(CENTRE_X, 1.15, WALL_Z)
	if _player.global_position.distance_to(at) > 2.45:
		return false
	if _animating():
		return false
	_open = not _open
	_play_bar_sound()
	Art.play_3d(self, _sfx_creak, global_position + Vector3(CENTRE_X, 1.3, WALL_Z),
		-3.0, 0.95 if _open else 1.1, 30.0)
	return true


func _animating() -> bool:
	if _open:
		return _bar_value < 0.99 or _door_value < 0.99
	return _door_value > 0.01 or _bar_value > 0.01


## ------------------------------------------------------------------ build

func _build_stone_frame() -> void:
	var stone: Material = _castle.call("shared_material", "stone")
	var cold: Material = _castle.call("shared_material", "cold")
	var dark: Material = _castle.call("shared_material", "dark")
	# Dressed jambs and lintel fill the part of the 2 m brick opening the leaf does not.
	var parts: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		parts.append(Art.box(Vector3(CENTRE_X + side * (OPEN_HALF - 0.175), OPEN_HEIGHT * 0.5,
			WALL_Z), Vector3(0.35, OPEN_HEIGHT, WALL_DEPTH), Color(0.60, 0.58, 0.52)))
		parts.append(Art.box(Vector3(CENTRE_X + side * (DOOR_HALF + 0.20), 1.30,
			WALL_Z + WALL_DEPTH * 0.5 + 0.03), Vector3(0.18, 2.45, 0.18),
			Color(0.56, 0.54, 0.49)))
	parts.append(Art.box(Vector3(CENTRE_X, OPEN_HEIGHT - 0.20, WALL_Z),
		Vector3(OPEN_HALF * 2.0, 0.40, WALL_DEPTH), Color(0.58, 0.56, 0.50)))
	# A shallow segmental arch of seven voussoirs in front of the lintel.
	for i: int in 7:
		var angle: float = deg_to_rad(20.0 + float(i) * 23.5)
		parts.append(Art.box(Vector3(CENTRE_X + cos(angle) * 1.06,
			2.06 + sin(angle) * 0.56, WALL_Z + WALL_DEPTH * 0.5 + 0.04),
			Vector3(0.27, 0.24, 0.15), Color(0.57, 0.55, 0.50),
			Vector3(0.0, 0.0, angle - PI * 0.5)))
	parts.append(Art.box(Vector3(CENTRE_X, 2.64, WALL_Z + WALL_DEPTH * 0.5 + 0.10),
		Vector3(0.38, 0.36, 0.26), Color(0.68, 0.64, 0.54)))
	var frame := Art.box_batch(parts, stone)
	frame.name = "SallyStoneFrame"
	add_child(frame)
	_build_frame_collision()
	var threshold := Art.box(Vector3(CENTRE_X, 0.035, WALL_Z + 0.2),
		Vector3(1.7, 0.07, 2.25), Color(0.42, 0.40, 0.36))
	var threshold_mesh := Art.box_batch([threshold], cold)
	threshold_mesh.name = "SallyThreshold"
	add_child(threshold_mesh)
	# A dark pocket for the bar to disappear into, on the wall beside the doorway.
	var pocket := Art.box(Vector3(CENTRE_X - 1.42, BAR_Y, BAR_Z + 0.10),
		Vector3(0.46, 0.34, 0.10), Color(0.035, 0.033, 0.030))
	var pocket_mesh := Art.box_batch([pocket], dark)
	pocket_mesh.name = "SallyBarPocket"
	add_child(pocket_mesh)


func _build_frame_collision() -> void:
	# The castle's wall collision is split around a 2 m opening; the dressed jambs and
	# lintel narrow it to the 1.3 m leaf. Without this the player would walk through the
	# stone frame that is visibly in the way.
	var body := StaticBody3D.new()
	body.name = "SallyFrameCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	_add_solid(body, Vector3(CENTRE_X - (OPEN_HALF + DOOR_HALF) * 0.5,
		OPEN_HEIGHT * 0.5, WALL_Z), Vector3(OPEN_HALF - DOOR_HALF, OPEN_HEIGHT, WALL_DEPTH))
	_add_solid(body, Vector3(CENTRE_X + (OPEN_HALF + DOOR_HALF) * 0.5,
		OPEN_HEIGHT * 0.5, WALL_Z), Vector3(OPEN_HALF - DOOR_HALF, OPEN_HEIGHT, WALL_DEPTH))
	_add_solid(body, Vector3(CENTRE_X, OPEN_HEIGHT - 0.20, WALL_Z),
		Vector3(OPEN_HALF * 2.0, 0.40, WALL_DEPTH))


func _add_solid(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


func _build_door() -> void:
	var wood := Art.tinted(Color(0.82, 0.70, 0.56), 0.95, 0.0, true)
	var iron: Material = _castle.call("shared_material", "iron")
	var dark: Material = _castle.call("shared_material", "dark")
	_door = AnimatableBody3D.new()
	_door.name = "SallyDoor"
	_door.sync_to_physics = true
	_door.collision_layer = 1
	_door.collision_mask = 1
	_door.position = Vector3(HINGE_X, 0.02, DOOR_Z)
	add_child(_door)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DOOR_HALF * 2.0, DOOR_HEIGHT, 0.16)
	shape.shape = box
	shape.position = Vector3(DOOR_HALF, DOOR_HEIGHT * 0.5, 0.0)
	_door.add_child(shape)
	var planks: Array[Dictionary] = []
	for i: int in 5:
		var x: float = 0.13 + float(i) * 0.26
		planks.append(Art.box(Vector3(x, DOOR_HEIGHT * 0.5, 0.0),
			Vector3(0.255, DOOR_HEIGHT - 0.06, 0.12),
			Color(0.44, 0.295, 0.17).lightened(0.016 * float(i % 3))))
	# A small barred window, so the postern reads before it opens.
	planks.append(Art.box(Vector3(0.66, 1.72, 0.075), Vector3(0.40, 0.44, 0.02),
		Color(0.04, 0.035, 0.03)))
	for i: int in 3:
		planks.append(Art.box(Vector3(0.54 + float(i) * 0.12, 1.72, 0.09),
			Vector3(0.03, 0.44, 0.03), Color(0.24, 0.25, 0.27)))
	var door_planks := Art.box_batch(planks, wood)
	door_planks.name = "SallyDoorPlanks"
	_door.add_child(door_planks)
	var fittings: Array[Dictionary] = []
	for y: float in [0.42, 1.15, 1.95]:
		fittings.append(Art.box(Vector3(DOOR_HALF, y, 0.085),
			Vector3(DOOR_HALF * 2.0 - 0.06, 0.16, 0.035), Color(0.25, 0.265, 0.29)))
		for stud: int in 5:
			fittings.append(Art.box(Vector3(0.18 + float(stud) * 0.24, y, 0.115),
				Vector3(0.055, 0.055, 0.035), Color(0.31, 0.32, 0.34)))
	for y: float in [0.30, 1.15, 2.00]:
		fittings.append(Art.box(Vector3(0.03, y, 0.11),
			Vector3(0.10, 0.16, 0.08), Color(0.23, 0.245, 0.27)))
		fittings.append(Art.box(Vector3(0.34, y, 0.105),
			Vector3(0.56, 0.10, 0.05), Color(0.24, 0.255, 0.28)))
	# Ring handle on both faces.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.085
	ring.outer_radius = 0.135
	ring.rings = 8
	ring.ring_segments = 16
	fittings.append({"mesh": ring, "xf": Transform3D(
		Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(1.12, 1.10, 0.16))})
	fittings.append({"mesh": ring, "xf": Transform3D(
		Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(1.12, 1.10, -0.16))})
	var iron_mesh := Art.merge_meshes(fittings, iron)
	iron_mesh.name = "SallyDoorIron"
	_door.add_child(iron_mesh)
	# A darker inset behind the window grille.
	var inset := Art.box(Vector3(0.66, 1.72, 0.055), Vector3(0.38, 0.42, 0.01),
		Color(0.03, 0.03, 0.035))
	var inset_mesh := Art.box_batch([inset], dark)
	inset_mesh.name = "SallyWindowDark"
	_door.add_child(inset_mesh)
	# Name plates on both faces.
	var outside := Label3D.new()
	outside.text = "КАЛИТКА"
	outside.font_size = 44
	outside.pixel_size = 0.003
	outside.modulate = Color(0.86, 0.80, 0.64)
	outside.outline_size = 8
	outside.outline_modulate = Color(0.10, 0.075, 0.045)
	outside.position = Vector3(CENTRE_X, 2.98, WALL_Z + 0.95)
	add_child(outside)
	var inside := Label3D.new()
	inside.text = "КАЛИТКА"
	inside.font_size = 44
	inside.pixel_size = 0.003
	inside.modulate = Color(0.86, 0.80, 0.64)
	inside.outline_size = 8
	inside.outline_modulate = Color(0.10, 0.075, 0.045)
	inside.position = Vector3(CENTRE_X, 2.98, WALL_Z - 1.00)
	inside.rotation.y = PI
	add_child(inside)


func _build_bar() -> void:
	var wood := Art.tinted(Color(0.82, 0.70, 0.56), 0.94, 0.0, true)
	var iron: Material = _castle.call("shared_material", "iron")
	_bar = Node3D.new()
	_bar.name = "SallyBar"
	_bar.position = Vector3(HINGE_X, BAR_Y, BAR_Z)
	add_child(_bar)
	_bar_base_x = HINGE_X
	var parts: Array[Dictionary] = []
	parts.append(Art.box(Vector3(0.76, 0.0, 0.0), Vector3(1.52, 0.17, 0.15),
		Color(0.31, 0.20, 0.115)))
	for side: float in [-1.0, 1.0]:
		parts.append(Art.box(Vector3(0.76 + side * 0.70, 0.0, 0.0),
			Vector3(0.13, 0.21, 0.19), Color(0.24, 0.255, 0.28)))
	var bar_mesh := Art.box_batch(parts, wood)
	bar_mesh.name = "SallyBarTimber"
	_bar.add_child(bar_mesh)
	var brackets: Array[Dictionary] = []
	for x: float in [0.16, 1.34]:
		brackets.append(Art.box(Vector3(x, -0.10, -0.01), Vector3(0.14, 0.07, 0.30),
			Color(0.25, 0.265, 0.29)))
		brackets.append(Art.box(Vector3(x, 0.13, 0.10), Vector3(0.14, 0.36, 0.07),
			Color(0.24, 0.255, 0.28)))
	var bracket_mesh := Art.box_batch(brackets, iron)
	bracket_mesh.name = "SallyBarBrackets"
	_bar.add_child(bracket_mesh)


func _build_threshold() -> void:
	# Interior step and a worn patch: the postern is used far more than the main gate.
	var stone: Material = _castle.call("shared_material", "cold")
	var parts: Array[Dictionary] = [
		Art.box(Vector3(CENTRE_X, 0.05, WALL_Z - WALL_DEPTH * 0.5 - 0.28),
			Vector3(1.55, 0.10, 0.55), Color(0.40, 0.39, 0.36)),
		Art.box(Vector3(CENTRE_X, 0.03, WALL_Z + WALL_DEPTH * 0.5 + 0.22),
			Vector3(1.55, 0.06, 0.42), Color(0.43, 0.41, 0.37))]
	var mesh := Art.box_batch(parts, stone)
	mesh.name = "SallySteps"
	add_child(mesh)


func _build_lanterns() -> void:
	var iron: Material = _castle.call("shared_material", "iron")
	for side: float in [-1.0, 1.0]:
		var x: float = CENTRE_X + side * 1.48
		var bracket := Art.box(Vector3(x, 2.55, WALL_Z + WALL_DEPTH * 0.5 + 0.14),
			Vector3(0.10, 0.10, 0.58), Color(0.26, 0.275, 0.30))
		var hook := Art.box(Vector3(x, 2.42, WALL_Z + WALL_DEPTH * 0.5 + 0.38),
			Vector3(0.06, 0.34, 0.06), Color(0.26, 0.275, 0.30))
		var pieces: Array[Dictionary] = [bracket, hook]
		pieces.append(Art.box(Vector3(x, 2.06, WALL_Z + WALL_DEPTH * 0.5 + 0.40),
			Vector3(0.22, 0.03, 0.22), Color(0.26, 0.275, 0.30)))
		pieces.append(Art.box(Vector3(x, 2.34, WALL_Z + WALL_DEPTH * 0.5 + 0.40),
			Vector3(0.22, 0.03, 0.22), Color(0.26, 0.275, 0.30)))
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				pieces.append(Art.box(Vector3(x + sx * 0.09, 2.20,
					WALL_Z + WALL_DEPTH * 0.5 + 0.40 + sz * 0.09),
					Vector3(0.025, 0.30, 0.025), Color(0.24, 0.255, 0.28)))
		var mesh := Art.box_batch(pieces, iron)
		mesh.name = "SallyLantern"
		add_child(mesh)
		var glass := Art.box(Vector3(x, 2.19, WALL_Z + WALL_DEPTH * 0.5 + 0.40),
			Vector3(0.15, 0.22, 0.15), Color(1.0, 0.74, 0.40))
		var glow_material := StandardMaterial3D.new()
		glow_material.albedo_color = Color(1.0, 0.80, 0.50)
		glow_material.emission_enabled = true
		glow_material.emission = Color(1.0, 0.62, 0.26)
		glow_material.emission_energy_multiplier = 2.2
		var glass_mesh := Art.box_batch([glass], glow_material)
		glass_mesh.name = "SallyLanternGlass"
		add_child(glass_mesh)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.66, 0.34)
		light.light_energy = 1.35
		light.omni_range = 3.6
		light.position = Vector3(x, 2.22, WALL_Z + WALL_DEPTH * 0.5 + 0.55)
		add_child(light)


## ------------------------------------------------------------------ animation

func _physics_process(delta: float) -> void:
	if _open:
		_bar_value = move_toward(_bar_value, 1.0, delta * 3.0)
		if _bar_value > 0.98:
			_door_value = move_toward(_door_value, 1.0, delta * 1.25)
	else:
		_door_value = move_toward(_door_value, 0.0, delta * 1.25)
		if _door_value < 0.02:
			_bar_value = move_toward(_bar_value, 0.0, delta * 3.0)
	if is_instance_valid(_door):
		_door.rotation.y = 1.72 * smoothstep(0.0, 1.0, _door_value)
	if is_instance_valid(_bar):
		_bar.position.x = _bar_base_x - BAR_SLIDE * smoothstep(0.0, 1.0, _bar_value)


func _play_bar_sound() -> void:
	Art.play_3d(self, _sfx_bar, global_position + Vector3(CENTRE_X, BAR_Y, BAR_Z),
		-2.0, 1.0, 26.0)
