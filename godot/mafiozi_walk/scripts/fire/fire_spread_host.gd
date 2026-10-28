extends Node3D
## Fire that SPREADS. Anything flammable registers itself as a fuel point; a burning
## point heats its neighbours and lights them one by one, and a point that has burnt
## through turns to charcoal and stops burning.
##
## The flames themselves are the existing molotov field pool (six prewarmed shader
## fields, two shared lights), so this host adds the propagation and the damage, not
## another particle system.

const FirePool = preload("res://scripts/fire/fire_field_pool.gd")

## A burning point reaches the things within this radius of its own edge.
const SPREAD_RADIUS := 3.4
## Seconds between spread attempts, so fire crawls instead of flashing over.
const SPREAD_INTERVAL := 0.55
## Chance a neighbour in reach catches on one attempt: wet oak resists, dry planks do not.
const SPREAD_CHANCE := 0.55
## How long a fuel point stays alight before it is burnt through.
const BURN_TIME := 9.0
## The pool has six fields; more burning points than this would share flames.
const MAX_ALIVE := 6

var _pool: Node3D = null
var _world: Node3D = null
var _fuel: Array[Dictionary] = []
var _spread_t := 0.0
var _ignitions := 0
var _charred := 0
var _time := 0.0
var _char_material: StandardMaterial3D


func configure(world: Node3D) -> bool:
	if not is_instance_valid(world) or _world != null:
		return false
	_world = world
	_char_material = StandardMaterial3D.new()
	_char_material.albedo_color = Color(0.055, 0.048, 0.045)
	_char_material.roughness = 1.0
	_char_material.metallic = 0.0
	return true


## The field pool is built on the first ignition, not at boot: eight fields and two
## lights that are never used on a calm map still cost the renderer every frame.
func _ensure_pool() -> void:
	if _pool != null or not is_instance_valid(_world):
		return
	_pool = FirePool.new()
	if not bool(_pool.call("configure", _world)):
		_pool.queue_free()
		_pool = null


## A thing that can burn: its node, the radius of its own body, and how much heat it
## takes. Boards and planks use a small radius; a whole tower uses a large one.
func register(node: Node3D, radius: float = 1.0) -> void:
	if not is_instance_valid(node):
		return
	for item: Dictionary in _fuel:
		if item.get("node") == node:
			return
	_fuel.append({"node": node, "radius": radius, "burning": false, "charred": false,
		"age": 0.0, "slot": -1})


func registered() -> int:
	return _fuel.size()


## Lights every fuel point whose body the blast reaches. Returns how many caught.
func ignite_at(at: Vector3, radius: float) -> int:
	var lit := 0
	for item: Dictionary in _fuel:
		if bool(item.get("burning", false)) or bool(item.get("charred", false)):
			continue
		var node: Node3D = item.get("node")
		if not is_instance_valid(node):
			continue
		var reach: float = radius + float(item.get("radius", 1.0))
		if node.global_position.distance_to(at) <= reach:
			if _light(item):
				lit += 1
	return lit


func burning_count() -> int:
	var count := 0
	for item: Dictionary in _fuel:
		if bool(item.get("burning", false)):
			count += 1
	return count


func snapshot() -> Dictionary:
	return {"registered": _fuel.size(), "burning": burning_count(),
		"ignitions": _ignitions, "charred": _charred, "pool": _pool != null}


func _light(item: Dictionary) -> bool:
	if burning_count() >= MAX_ALIVE:
		return false
	var node: Node3D = item.get("node")
	if not is_instance_valid(node):
		return false
	item["burning"] = true
	item["age"] = 0.0
	_ensure_pool()
	_ignitions += 1
	if _pool != null:
		# The field is as wide as the thing that burns: a gate leaf gets a 2.5 m fire,
		# a siege tower a seven-metre one. It is placed at the CENTRE of the object's
		# meshes, not at its origin: a gate leaf's origin is its hinge, and fire there
		# hides behind the door.
		var width: float = clampf(float(item.get("radius", 1.0)) * 2.0, 1.4, 7.5)
		item["slot"] = int(_pool.call("ignite", _fuel_centre(node), width))
	print("DSH_FIRE_IGNITE at=", node.global_position, " burning=", burning_count())
	return true


func _process(delta: float) -> void:
	if _fuel.is_empty():
		return
	_time += delta
	_spread_t += delta
	var camera_at := _camera_position()
	for item: Dictionary in _fuel:
		if not bool(item.get("burning", false)):
			continue
		item["age"] = float(item.get("age", 0.0)) + delta
		var slot: int = int(item.get("slot", -1))
		if _pool != null and slot >= 0:
			# Fade the fire as the fuel is eaten, so a burning gate dims before it chars.
			var left: float = clampf(1.0 - float(item["age"]) / BURN_TIME, 0.0, 1.0)
			_pool.call("update_field", slot, float(item["age"]), 0.35 + 0.65 * left, camera_at)
		if float(item["age"]) >= BURN_TIME:
			_char(item)
	if _spread_t >= SPREAD_INTERVAL:
		_spread_t = 0.0
		_spread()


## Each burning point tries to light what is next to it, closest first, so a fire
## runs along a row of planks instead of jumping over the courtyard.
func _spread() -> void:
	if burning_count() >= MAX_ALIVE:
		return
	var sources: Array[Dictionary] = []
	for item: Dictionary in _fuel:
		if bool(item.get("burning", false)) and not bool(item.get("charred", false)):
			sources.append(item)
	for source: Dictionary in sources:
		var source_node: Node3D = source.get("node")
		if not is_instance_valid(source_node):
			continue
		var best: Dictionary = {}
		var best_distance := INF
		for item: Dictionary in _fuel:
			if bool(item.get("burning", false)) or bool(item.get("charred", false)):
				continue
			var node: Node3D = item.get("node")
			if not is_instance_valid(node):
				continue
			var reach: float = SPREAD_RADIUS + float(item.get("radius", 1.0))
			var distance := source_node.global_position.distance_to(node.global_position)
			if distance <= reach and distance < best_distance:
				best = item
				best_distance = distance
		if best.is_empty():
			continue
		# Dry, close planks catch at once; the further away it is, the longer it takes.
		var heat: float = 1.0 - clampf(best_distance / maxf(0.5, SPREAD_RADIUS), 0.0, 1.0)
		if randf() < SPREAD_CHANCE * (0.45 + heat):
			_light(best)


## Where the fire actually sits: the centre of the object's meshes, so a hinge-origin
## leaf burns at its middle and a hull burns at its deck line.
func _fuel_centre(node: Node3D) -> Vector3:
	var merged := AABB()
	var found := false
	# Both MeshInstance3D and MultiMeshInstance3D: the gate leaves draw their boards
	# through a MultiMesh, and looking only for MeshInstance3D put every gate fire at
	# the hinge, hidden behind the door frame.
	for child: Node in node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if not is_instance_valid(visual):
			continue
		var box: AABB = visual.global_transform * visual.get_aabb()
		if box.size.length_squared() <= 0.0:
			continue
		if not found:
			merged = box
			found = true
		else:
			merged = merged.merge(box)
	if not found:
		return node.global_position + Vector3.UP * 0.5
	var centre := merged.get_center()
	# Never start the flames underground on a wall-anchored prop.
	return Vector3(centre.x, maxf(centre.y, node.global_position.y + 0.4), centre.z)


func _char(item: Dictionary) -> void:
	var node: Node3D = item.get("node")
	item["burning"] = false
	item["charred"] = true
	var slot: int = int(item.get("slot", -1))
	if _pool != null and slot >= 0:
		_pool.call("stop_field", slot)
	item["slot"] = -1
	_charred += 1
	if not is_instance_valid(node):
		return
	# Charred timber: the silhouette stays, the surface goes black. Structural pieces
	# are not deleted, so the castle and the ship keep their shape after the fire.
	if _char_material == null:
		_char_material = StandardMaterial3D.new()
		_char_material.albedo_color = Color(0.055, 0.048, 0.045)
		_char_material.roughness = 1.0
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if is_instance_valid(mesh_instance):
			mesh_instance.material_override = _char_material
	if node.has_method("burn_down"):
		node.call("burn_down")
	print("DSH_FIRE_CHARRED at=", node.global_position if is_instance_valid(node) else Vector3.ZERO,
		" charred=", _charred)


func _camera_position() -> Vector3:
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_3d()
		if is_instance_valid(camera):
			return camera.global_position
	return Vector3.INF
