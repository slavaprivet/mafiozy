extends Node3D
## SHIP104: a small water-side fort battery.  Three guns on the east wall of
## the castle fire at a hostile ship that comes within range.  They reuse the
## ship cannonball script and heavy-ball ballistics, so damage/range match the
## ship guns.

const Cannonball = preload("res://scripts/ship/ship_cannonball.gd")
const BALL_SPEED := 40.0
const GRAVITY := 15.0
const RANGE := 85.0
const COOLDOWN := 5.0
const PITCH_MAX := deg_to_rad(24.0)

var world: Node3D
var castle: Node3D
var basin: Node3D
var boat: Node3D
var _guns: Array[Dictionary] = []
var _time := 0.0
var _wood: StandardMaterial3D
var _iron: StandardMaterial3D
var _stone: StandardMaterial3D

func install(world_in: Node3D, castle_in: Node3D, ship_host: Node3D) -> Dictionary:
	world = world_in
	castle = castle_in
	basin = ship_host.get("preview_basin")
	var ship: Variant = ship_host.get("boat")
	if is_instance_valid(ship):
		boat = ship
	_materials()
	# East wall of the castle (local +X), facing the water where the ship berths.
	for i: int in 3:
		var local_z := 20.0 + float(i) * 20.0
		var base := castle.to_global(Vector3(69.0, 0.0, local_z))
		var gun := _build_gun(base, i)
		_guns.append(gun)
	return {"ok": true, "guns": _guns.size()}

func _materials() -> void:
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color(0.34, 0.23, 0.13)
	_wood.roughness = 0.9
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.12, 0.12, 0.14)
	_iron.metallic = 0.7
	_iron.roughness = 0.35
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.42, 0.40, 0.36)
	_stone.roughness = 0.96

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_gun(base: Vector3, index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "FortGun%d" % index
	add_child(root)
	root.global_position = base
	# Stone bastion under the gun.
	_root_box(root, Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 2.6), _stone)
	_root_box(root, Vector3(0, 0.95, 0), Vector3(2.0, 0.12, 2.0), _stone)
	# Wooden carriage.
	_root_box(root, Vector3(0, 1.25, 0), Vector3(1.3, 0.5, 1.5), _wood)
	for side: float in [-1.0, 1.0]:
		_root_box(root, Vector3(side * 0.52, 1.15, 0), Vector3(0.18, 0.42, 1.3), _wood)
	# Barrel points east (+X), the water side.
	var pivot := Node3D.new()
	pivot.position = Vector3(0.15, 1.55, 0)
	root.add_child(pivot)
	var barrel := Node3D.new()
	pivot.add_child(barrel)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.12
	tube.bottom_radius = 0.19
	tube.height = 2.3
	tube.radial_segments = 12
	var tm := MeshInstance3D.new()
	tm.mesh = tube
	tm.material_override = _iron
	tm.rotation.z = -PI * 0.5
	tm.position = Vector3(0.95, 0, 0)
	barrel.add_child(tm)
	var muzzle := Node3D.new()
	muzzle.position = Vector3(2.1, 0, 0)
	barrel.add_child(muzzle)
	var flash := _box(root, Vector3.ZERO, Vector3(0.22, 0.22, 0.22), _iron)
	flash.visible = false
	return {"root": root, "pivot": pivot, "barrel": barrel, "muzzle": muzzle,
		"flash": flash, "cooldown": 1.2 + float(index) * 0.7, "flash_t": 0.0}

func _root_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	_box(parent, pos, size, mat)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boat) or not is_instance_valid(basin):
		return
	_time += delta
	var target: Vector3 = boat.global_position + Vector3.UP * 1.4
	for gun: Dictionary in _guns:
		var cooldown := float(gun.get("cooldown", 0.0)) - delta
		gun["cooldown"] = cooldown
		var flash: MeshInstance3D = gun.get("flash")
		var flash_t := maxf(0.0, float(gun.get("flash_t", 0.0)) - delta)
		gun["flash_t"] = flash_t
		if is_instance_valid(flash):
			flash.visible = flash_t > 0.0
		if cooldown > 0.0:
			continue
		var muzzle: Node3D = gun.get("muzzle")
		if not is_instance_valid(muzzle):
			continue
		var from := muzzle.global_position
		var flat := target - from
		flat.y = 0.0
		var distance := flat.length()
		if distance < 6.0 or distance > RANGE:
			continue
		var pitch := _pitch_for(distance, target.y - from.y)
		var dir := flat.normalized()
		dir = dir.rotated(Vector3.UP.cross(dir).normalized(), pitch)
		var ball: Node3D = Cannonball.new()
		add_child(ball)
		ball.call("launch", from, dir, BALL_SPEED, null, castle, basin, 9000 + _guns.find(gun))
		gun["cooldown"] = COOLDOWN + randf_range(-0.6, 0.6)
		gun["flash_t"] = 0.09
		if is_instance_valid(flash):
			flash.global_position = from
			flash.visible = true

func _pitch_for(horizontal: float, height: float) -> float:
	var v2 := BALL_SPEED * BALL_SPEED
	var disc := v2 * v2 - GRAVITY * (GRAVITY * horizontal * horizontal + 2.0 * height * v2)
	if disc < 0.0:
		return deg_to_rad(8.0)
	var angle := atan2(v2 - sqrt(disc), GRAVITY * horizontal)
	return clampf(angle, deg_to_rad(-4.0), PITCH_MAX)
