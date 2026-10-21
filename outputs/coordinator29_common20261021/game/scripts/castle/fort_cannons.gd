extends Node3D
## SHIP104/105: castle water-side battery.  Three heavy guns face the water;
## the player can walk to a gun, man it with F, aim with A/D + W/S, load with E
## and fire with LMB.  A destructible stone room protects the crews.

const Cannonball = preload("res://scripts/ship/ship_cannonball.gd")
const StructuralBlockHost = preload("res://scripts/destruction/structural_block_host.gd")
const BALL_SPEED := 40.0
const GRAVITY := 15.0
const RANGE := 85.0
const COOLDOWN := 5.0
const PITCH_MIN := deg_to_rad(-4.0)
const PITCH_MAX := deg_to_rad(24.0)
const YAW_LIMIT := deg_to_rad(12.0)
const REACH := 3.0

var world: Node3D
var castle: Node3D
var basin: Node3D
var boat: Node3D
var player: CharacterBody3D
var ship_host: Node3D
var _guns: Array[Dictionary] = []
var _wall_blocks: Array[Dictionary] = []
var _man := -1
var _door_outside := Vector3.ZERO
var _door_inside := Vector3.ZERO
var _debris_budget := 24
var _loaded: Array[bool] = [false, false, false]
var _balls := 6
var _load_t := 0.0
var _time := 0.0
var _wood: StandardMaterial3D
var _iron: StandardMaterial3D
var _stone: StandardMaterial3D
var _brick: ShaderMaterial
var _structural: Node3D
var _falling_panels: Array[Node3D] = []

func install(world_in: Node3D, castle_in: Node3D, ship_host_in: Node3D) -> Dictionary:
	world = world_in
	castle = castle_in
	ship_host = ship_host_in
	basin = ship_host_in.get("preview_basin")
	player = ship_host_in.get("player")
	var ship: Variant = ship_host_in.get("boat")
	if is_instance_valid(ship):
		boat = ship
	_materials()
	_structural = StructuralBlockHost.new()
	_structural.name = "FortStructure"
	add_child(_structural)
	_structural.call("configure", self)
	_door_outside = castle.to_global(Vector3(64.8, 1.2, 74.0))
	_door_inside = castle.to_global(Vector3(67.0, 1.2, 74.0))
	_build_room()
	for i: int in 3:
		var base := castle.to_global(Vector3(69.2, 0.0, 20.0 + float(i) * 20.0))
		_guns.append(_build_gun(base, i))
	return {"ok": true, "guns": _guns.size(), "blocks": _wall_blocks.size()}

func _materials() -> void:
	_wood = StandardMaterial3D.new(); _wood.albedo_color = Color(0.34, 0.23, 0.13); _wood.roughness = 0.9
	_iron = StandardMaterial3D.new(); _iron.albedo_color = Color(0.12, 0.12, 0.14); _iron.metallic = 0.7; _iron.roughness = 0.35
	_stone = StandardMaterial3D.new(); _stone.albedo_color = Color(0.42, 0.40, 0.36); _stone.roughness = 0.96
	# Mortared brick courses in the shader: one draw call per panel, but the
	# wall reads as castle masonry rather than a flat grey slab.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec3 brick_color = vec3(0.46, 0.28, 0.17);
uniform vec3 mortar_color = vec3(0.23, 0.19, 0.16);
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	float row_h = 0.29;
	float col_w = 0.62;
	float row = floor(local_pos.y / row_h);
	float shifted = local_pos.z + mod(row, 2.0) * col_w * 0.5;
	float bx = fract(shifted / col_w);
	float by = fract(local_pos.y / row_h);
	float mortar = step(bx, 0.055) + step(0.945, bx) + step(by, 0.09) + step(0.91, by);
	vec3 c = mix(brick_color, mortar_color, clamp(mortar, 0.0, 1.0));
	float shade = 0.88 + 0.12 * fract(sin(dot(floor(vec2(shifted / col_w, row)), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = c * shade;
	ROUGHNESS = 0.94;
}
"""
	_brick = ShaderMaterial.new()
	_brick.shader = shader

func _mesh_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = pos
	if mat == _brick:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi

func _solid_box(pos: Vector3, size: Vector3, mat: Material, hp: float = 90.0,
		is_base: bool = true) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = castle.to_global(pos)
	var mi := _mesh_box(root, Vector3.ZERO, size, mat)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = size; shape.shape = box
	body.add_child(shape)
	body.set_meta("fort_wall", true)
	root.add_child(body)
	_wall_blocks.append({"node": root, "mesh": mi, "body": body, "hp": hp, "size": size})
	if is_instance_valid(_structural):
		_structural.call("add_block", root, body, size, hp, is_base)

func _build_room() -> void:
	# Destructible water-side battlements with real embrasures.  The old extra
	# side wing has been removed; the wall now only spans the gun front.
	for seg: Array in [[12.0, 17.6], [22.4, 28.4], [31.6, 37.6], [42.4, 48.4],
			[51.6, 57.6], [62.4, 68.4]]:
		var z0: float = seg[0]
		var z1: float = seg[1]
		var length: float = z1 - z0
		# Two stacked courses: the upper course is only held up by the lower one,
		# so shooting the lower block out drops the upper block physically.
		_solid_box(Vector3(70.6, 0.72, (z0 + z1) * 0.5), Vector3(0.8, 1.44, length),
			_brick, 30.0, true)
		_solid_box(Vector3(70.6, 2.16, (z0 + z1) * 0.5), Vector3(0.8, 1.44, length),
			_brick, 30.0, false)
	for gap_z: float in [20.0, 40.0, 60.0]:
		_solid_box(Vector3(70.6, 0.65, gap_z), Vector3(0.8, 0.9, 4.8), _brick, 25.0, true)
		_solid_box(Vector3(70.6, 2.85, gap_z), Vector3(0.8, 1.1, 4.8), _brick, 25.0, true)

func _build_gun(base: Vector3, index: int) -> Dictionary:
	var root := Node3D.new(); root.name = "FortGun%d" % index; add_child(root); root.global_position = base
	_mesh_box(root, Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 2.6), _stone)
	_mesh_box(root, Vector3(0, 0.95, 0), Vector3(2.0, 0.12, 2.0), _stone)
	_mesh_box(root, Vector3(0, 1.25, 0), Vector3(1.3, 0.5, 1.5), _wood)
	for side: float in [-1.0, 1.0]:
		_mesh_box(root, Vector3(side * 0.52, 1.15, 0), Vector3(0.18, 0.42, 1.3), _wood)
	var pivot := Node3D.new(); pivot.position = Vector3(0.15, 1.55, 0); root.add_child(pivot)
	var barrel := Node3D.new(); pivot.add_child(barrel)
	var tube := CylinderMesh.new(); tube.top_radius = 0.12; tube.bottom_radius = 0.19; tube.height = 2.3; tube.radial_segments = 12
	var tm := MeshInstance3D.new(); tm.mesh = tube; tm.material_override = _iron; tm.rotation.z = -PI * 0.5; tm.position = Vector3(0.95, 0, 0); barrel.add_child(tm)
	var muzzle := Node3D.new(); muzzle.position = Vector3(2.1, 0, 0); barrel.add_child(muzzle)
	var station := base + Vector3(-1.5, 0.05, 0)
	var flash := _mesh_box(root, Vector3.ZERO, Vector3(0.22, 0.22, 0.22), _iron); flash.visible = false
	return {"root": root, "pivot": pivot, "barrel": barrel, "muzzle": muzzle,
		"flash": flash, "station": station, "cooldown": 1.2 + float(index) * 0.7,
		"flash_t": 0.0, "yaw": 0.0, "pitch": 0.0, "recoil": 0.0}

func action() -> Dictionary:
	if not is_instance_valid(player):
		return {}
	if _man >= 0:
		return {"owner": "fort", "kind": "fort_leave", "label": "Покинуть пушку",
			"world": _guns[_man].get("station") + Vector3.UP * 1.2}
	var best := -1
	var best_d := REACH
	for i: int in _guns.size():
		var station: Vector3 = _guns[i].get("station")
		var d: float = player.global_position.distance_to(station)
		if d < best_d:
			best = i; best_d = d
	if best < 0:
		return {}
	return {"owner": "fort", "kind": "fort_man", "index": best,
		"label": "Встать за пушку", "world": _guns[best].get("station") + Vector3.UP * 1.2}

func interact(action_data: Variant) -> bool:
	if not action_data is Dictionary:
		return false
	var kind := str(action_data.get("kind", ""))
	if kind == "fort_leave":
		_stop_manning()
		return true
	if kind == "fort_man":
		var index := int(action_data.get("index", 0))
		if index < 0 or index >= _guns.size():
			return false
		_man = index
		var station: Vector3 = _guns[index].get("station")
		player.global_position = station
		player.velocity = Vector3.ZERO
		if player.has_method("set_vehicle_hold"):
			player.call("set_vehicle_hold", true)
		if player.has_method("set_station_hold"):
			player.call("set_station_hold", true)
		player.set("_camera_yaw", -PI * 0.5)
		return true
	return false

func _stop_manning() -> void:
	if _man < 0:
		return
	_man = -1
	if is_instance_valid(player):
		if player.has_method("set_vehicle_hold"):
			player.call("set_vehicle_hold", false)
		if player.has_method("set_station_hold"):
			player.call("set_station_hold", false)

func _unhandled_input(event: InputEvent) -> void:
	if _man < 0 or not event is InputEventKey or not event.pressed or event.echo:
		if _man >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_fire(_man)
			get_viewport().set_input_as_handled()
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_E and not _loaded[_man] and _balls > 0 and _load_t <= 0.0:
		_loaded[_man] = true
		_load_t = 0.7
		_balls -= 1
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_time += delta
	_load_t = maxf(0.0, _load_t - delta)
	var aim_yaw := 0.0
	var aim_pitch := 0.0
	if _man >= 0 and is_instance_valid(player):
		player.global_position = _guns[_man].get("station")
		player.velocity = Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): aim_yaw -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): aim_yaw += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): aim_pitch += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): aim_pitch -= 1.0
		var gun: Dictionary = _guns[_man]
		gun["yaw"] = clampf(float(gun.get("yaw", 0.0)) + aim_yaw * delta * 0.8, -YAW_LIMIT, YAW_LIMIT)
		gun["pitch"] = clampf(float(gun.get("pitch", 0.0)) + aim_pitch * delta * 0.5, PITCH_MIN, PITCH_MAX)
		var pivot: Node3D = gun.get("pivot")
		var barrel: Node3D = gun.get("barrel")
		if is_instance_valid(pivot): pivot.rotation.y = -float(gun["yaw"])
		if is_instance_valid(barrel): barrel.rotation.z = float(gun["pitch"])
	_update_fort_fire(delta)

func _update_fort_fire(delta: float) -> void:
	if not is_instance_valid(boat) or not is_instance_valid(basin):
		return
	for i: int in _guns.size():
		var gun: Dictionary = _guns[i]
		var flash: MeshInstance3D = gun.get("flash")
		gun["flash_t"] = maxf(0.0, float(gun.get("flash_t", 0.0)) - delta)
		if is_instance_valid(flash): flash.visible = float(gun["flash_t"]) > 0.0
		if i == _man:
			continue
		gun["cooldown"] = float(gun.get("cooldown", 0.0)) - delta
		if float(gun["cooldown"]) > 0.0:
			continue
		var muzzle: Node3D = gun.get("muzzle")
		if not is_instance_valid(muzzle): continue
		var from: Vector3 = muzzle.global_position
		var target: Vector3 = boat.global_position + Vector3.UP * 1.4
		var flat := target - from; flat.y = 0.0
		var dist := flat.length()
		if dist < 6.0 or dist > RANGE: continue
		var dir := flat.normalized()
		var pitch := _pitch_for(dist, target.y - from.y)
		dir = dir.rotated(Vector3.UP.cross(dir).normalized(), pitch)
		_spawn_ball(from, dir, 9000 + i)
		gun["cooldown"] = COOLDOWN + randf_range(-0.6, 0.6)
		gun["flash_t"] = 0.09
		if is_instance_valid(flash): flash.global_position = from; flash.visible = true

func _fire(index: int) -> void:
	if index < 0 or index >= _guns.size() or not _loaded[index]:
		return
	var gun: Dictionary = _guns[index]
	var muzzle: Node3D = gun.get("muzzle")
	if not is_instance_valid(muzzle): return
	var from: Vector3 = muzzle.global_position
	var dir := Vector3.RIGHT.rotated(Vector3.UP, -float(gun.get("yaw", 0.0)))
	dir = dir.rotated(Vector3.UP.cross(dir).normalized(), float(gun.get("pitch", 0.0)))
	_spawn_ball(from, dir, 9100 + index)
	_loaded[index] = false
	gun["flash_t"] = 0.09
	var flash: MeshInstance3D = gun.get("flash")
	if is_instance_valid(flash): flash.global_position = from; flash.visible = true

func _spawn_ball(from: Vector3, dir: Vector3, shot: int) -> void:
	var ball: Node3D = Cannonball.new()
	add_child(ball)
	ball.call("launch", from, dir, BALL_SPEED, null, castle, basin, shot)

func apply_hit(world_point: Vector3, damage: float, _impulse: Vector3, _kind: String) -> Dictionary:
	if is_instance_valid(_structural):
		var result: Dictionary = _structural.call("apply_hit", world_point, damage)
		if bool(result.get("ok", false)):
			if bool(result.get("destroyed", false)):
				_debris(world_point)
			return result
	return {"ok": false, "reason": "no_wall"}


func _spawn_falling_panel(xform: Transform3D, size: Variant) -> void:
	if not size is Vector3:
		return
	var panel_size: Vector3 = size
	# Cap simultaneous full-size falling panels: the wall may lose many blocks in
	# one blast, but only the newest eight stay physical.
	while _falling_panels.size() >= 8:
		var oldest: Node3D = _falling_panels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var body := RigidBody3D.new()
	body.name = "FallingMasonry"
	body.mass = maxf(4.0, panel_size.x * panel_size.y * panel_size.z * 900.0)
	var mesh := BoxMesh.new()
	mesh.size = panel_size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _brick
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = panel_size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_transform = xform
	body.apply_central_impulse(Vector3(randf_range(-1.0, 1.0), 0.4,
		randf_range(-1.0, 1.0)) * body.mass * 0.8)
	_falling_panels.append(body)
	body.tree_exiting.connect(func() -> void:
		_falling_panels.erase(body))
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.queue_free())
	_debris(xform.origin)

func _debris(at: Vector3) -> void:
	if _debris_budget <= 0:
		return
	var count := mini(3, _debris_budget)
	_debris_budget -= count
	for i: int in count:
		var body := RigidBody3D.new()
		body.mass = 0.35
		var mesh := BoxMesh.new()
		mesh.size = Vector3(randf_range(0.16, 0.32), randf_range(0.12, 0.22), randf_range(0.16, 0.32))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var brick_mat := StandardMaterial3D.new()
		brick_mat.albedo_color = Color(0.40, 0.24, 0.15)
		mi.material_override = brick_mat
		body.add_child(mi)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		body.global_position = at + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
		body.apply_central_impulse(Vector3(randf_range(-1.4, 1.4), randf_range(0.6, 2.0), randf_range(-1.4, 1.4)))
		get_tree().create_timer(4.0).timeout.connect(body.queue_free)


func _pitch_for(horizontal: float, height: float) -> float:
	var v2 := BALL_SPEED * BALL_SPEED
	var disc := v2 * v2 - GRAVITY * (GRAVITY * horizontal * horizontal + 2.0 * height * v2)
	if disc < 0.0: return deg_to_rad(8.0)
	return clampf(atan2(v2 - sqrt(disc), GRAVITY * horizontal), PITCH_MIN, PITCH_MAX)
