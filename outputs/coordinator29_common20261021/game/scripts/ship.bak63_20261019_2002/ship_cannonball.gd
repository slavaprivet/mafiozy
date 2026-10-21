extends Node3D
## SHIP61 agent D — one ship cannonball.
##
## A KINEMATIC projectile, deliberately not a RigidBody3D: the flight is integrated by
## hand at a fixed 1/60 s substep and every segment is swept with a physics ray, so a
## 62 m/s ball cannot tunnel through a thin wall between two physics ticks.  The pool is
## owned by `ship_cannons.gd`; this script only knows how to fly, what it struck and how
## to hand the strike to the castle / boat / water.
##
## Public API (contract):
##   launch(from, direction, speed, owner_boat, castle, basin[, shot_id])
##   advance(delta) -> Dictionary   (last impact, or {} while still flying)
##   deactivate()
##
## No `class_name` on purpose: the project loads scripts through preload().

const GRAVITY := 9.81
const LIFE_S := 8.0
const BALL_RADIUS := 0.14
## A ray between two centres can slip past a thin wall when the ball's own radius is
## ignored.  The sweep is extended by the radius, exactly like the catapult stone.
const SWEEP_PAD := 0.22

## Payload promised by SHIP61_CONTRACT.md, section D.
## SHIP62 balance: a ship ball is deliberately much lighter than the catapult stone
## (radius 0.85 / power 240), so one strike opens a small breach instead of collapsing
## a whole section.  The radius still reaches door boards, gate planks and furniture.
const CASTLE_RADIUS := 1.1
const CASTLE_POWER := 54.0
## The small, fast ship ball opens a surface patch, not a mine crater.  On plain curtain
## masonry the burst is centred outside the face so a single hit stays a local breach; a
## gate leaf or a piece of furniture is a thin wooden target and is hit dead on, so those
## still break as the briefing requires.
const CASTLE_SURFACE_OFFSET := 0.55
const CASTLE_WOOD_OFFSET := 0.0
const SHIP_DAMAGE := 55.0
const SHIP_IMPULSE := 8.0
const OWN_GRACE_S := 0.25

var active := false
var velocity := Vector3.ZERO
var age := 0.0
var shot_id := 0
var owner_boat: Node3D = null
var castle: Node3D = null
var basin: Node = null
var last_impact: Dictionary = {}

var _own_rids: Array[RID] = []
var _mesh: MeshInstance3D = null
var _spin_axis := Vector3.RIGHT
var _spin_rate := 7.0

## The iron of a real ball is never uniform: a mottled procedural map makes the spin
## readable without adding a second draw call for a seam ring.
static var _iron_material: StandardMaterial3D = null
static var _iron_texture: ImageTexture = null


func _ready() -> void:
	_ensure_mesh()
	visible = false


## Called by ShipCannons when the ball leaves the muzzle.  `event_index` is the running
## shot number used in the castle event id ("ship-cannon:<n>").
func launch(from: Vector3, direction: Vector3, speed: float, boat: Node3D,
		castle_node: Node3D, basin_node: Node, event_index: int = 0) -> void:
	_ensure_mesh()
	global_position = from
	var dir: Vector3 = direction
	if dir.length_squared() < 1.0e-8:
		dir = Vector3.FORWARD
	velocity = dir.normalized() * maxf(1.0, speed)
	age = 0.0
	shot_id = event_index
	owner_boat = boat if is_instance_valid(boat) else null
	castle = castle_node if is_instance_valid(castle_node) else null
	basin = basin_node if is_instance_valid(basin_node) else null
	last_impact = {}
	_collect_own_rids()
	# The ball rolls over its own flight axis; the axis is perpendicular to the bore so
	# the mottled surface clearly turns during the flight.
	_spin_axis = velocity.normalized().cross(Vector3.UP)
	if _spin_axis.length_squared() < 1.0e-5:
		_spin_axis = velocity.normalized().cross(Vector3.RIGHT)
	_spin_axis = _spin_axis.normalized() if _spin_axis.length_squared() > 1.0e-8 else Vector3.RIGHT
	_spin_rate = randf_range(5.5, 9.5)
	active = true
	visible = true


func deactivate() -> void:
	active = false
	velocity = Vector3.ZERO
	visible = false


## Advance by an arbitrary frame delta, internally split into 1/60 s sweeps.
## Returns the impact dictionary on the tick that ended the flight, otherwise {}.
func advance(delta: float) -> Dictionary:
	if not active:
		return {}
	var remaining: float = maxf(0.0, delta)
	# A huge frame spike must not teleport the ball through the world.
	var guard := 0
	while remaining > 1.0e-6 and active and guard < 24:
		guard += 1
		var step: float = minf(remaining, 1.0 / 60.0)
		remaining -= step
		var result: Dictionary = _step(step)
		if not result.is_empty():
			return result
	return {}


func _step(step: float) -> Dictionary:
	age += step
	var previous: Vector3 = global_position
	# Semi-implicit Euler: gravity first, then the swept segment.
	velocity += Vector3.DOWN * GRAVITY * step
	var next: Vector3 = previous + velocity * step
	# Water is not a physics body in this project.  Catch the surface crossing before
	# the ray query, otherwise a ball would fly through the sea and only stop on the
	# heightfield seven metres below.
	var water := _water_crossing(previous, next)
	if not water.is_empty():
		return water
	var space: PhysicsDirectSpaceState3D = null
	if is_inside_tree():
		space = get_world_3d().direct_space_state
	if space != null:
		var exclude: Array[RID] = []
		# The first quarter second may still overlap the firing ship; the ball must not
		# explode against its own gunwale.
		if age < OWN_GRACE_S:
			exclude = _own_rids
		var motion: Vector3 = next - previous
		var dir: Vector3 = motion.normalized() if motion.length_squared() > 1.0e-9 else velocity.normalized()
		var query := PhysicsRayQueryParameters3D.create(previous,
			next + dir * SWEEP_PAD, 1, exclude)
		query.hit_from_inside = true
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var result: Dictionary = _react(hit)
			if bool(result.get("ignored", false)):
				# Own ship during the grace window: keep flying.
				global_position = next
				return {}
			return result
	global_position = next
	if is_instance_valid(_mesh):
		_mesh.rotate(_spin_axis, _spin_rate * step)
	if age >= LIFE_S or next.y < -80.0:
		deactivate()
		var expired := {"type": "expire", "position": next,
			"direction": velocity.normalized(), "event_id": "ship-cannon:%d" % shot_id}
		last_impact = expired
		return expired
	return {}


func _react(hit: Dictionary) -> Dictionary:
	var point: Vector3 = hit.get("position", global_position)
	var collider: Variant = hit.get("collider")
	var direction: Vector3 = velocity.normalized()
	global_position = point
	# 1. the firing ship itself (only after the grace window)
	if is_instance_valid(owner_boat) and _is_under(collider, owner_boat):
		if age < OWN_GRACE_S:
			return {"ignored": true}
		var ship_result: Dictionary = {"ok": false}
		if owner_boat.has_method("apply_hit"):
			ship_result = owner_boat.call("apply_hit", point, SHIP_DAMAGE,
				direction * SHIP_IMPULSE, "cannonball")
		return _finish({"type": "ship", "position": point, "direction": direction,
			"collider": _collider_name(collider), "result": ship_result,
			"event_id": "ship-cannon:%d" % shot_id})
	# 2. the castle: either a collider that belongs to it or a point inside its footprint
	if _is_castle(point, collider):
		var normal: Vector3 = hit.get("normal", -direction)
		if normal.length_squared() < 1.0e-6:
			normal = -direction
		var offset: float = CASTLE_WOOD_OFFSET if _is_wooden_target(collider) \
			else CASTLE_SURFACE_OFFSET
		var blast_point: Vector3 = _castle_blast_point(point, normal, offset)
		var event := {
			"position": blast_point,
			"radius": CASTLE_RADIUS,
			"power": CASTLE_POWER,
			"direction": direction,
			"event_id": "ship-cannon:%d" % shot_id,
		}
		var castle_result: Dictionary = {"ok": false}
		if castle.has_method("apply_explosion"):
			castle_result = castle.call("apply_explosion", event)
		var detached: int = int(castle_result.get("detached", 0))
		return _finish({"type": "castle", "position": point, "direction": direction,
			"collider": _collider_name(collider), "event": event, "result": castle_result,
			"detached": detached, "event_id": "ship-cannon:%d" % shot_id})
	# 3. water (a bank / quay collider under the surface still counts as a splash)
	if _is_water_point(point):
		return _finish_water(point, direction)
	# 4. dry land / masonry that is not the castle
	return _finish({"type": "land", "position": point, "direction": direction,
		"normal": hit.get("normal", Vector3.UP), "collider": _collider_name(collider),
		"event_id": "ship-cannon:%d" % shot_id})


func _finish_water(point: Vector3, direction: Vector3) -> Dictionary:
	if is_instance_valid(basin) and basin.has_method("add_ripple"):
		basin.call("add_ripple", point, 1.4)
	return _finish({"type": "water", "position": point, "direction": direction,
		"normal": Vector3.UP, "event_id": "ship-cannon:%d" % shot_id})


func _finish(result: Dictionary) -> Dictionary:
	result["flight_time"] = age
	result["speed"] = velocity.length()
	last_impact = result
	deactivate()
	return result


# ---------------------------------------------------------------- water helpers
func _water_level() -> float:
	if is_instance_valid(basin) and basin.has_method("water_level"):
		return float(basin.call("water_level"))
	return -0.55


func _depth_at(point: Vector3) -> float:
	if is_instance_valid(basin) and basin.has_method("depth_at"):
		return float(basin.call("depth_at", point.x, point.z))
	return 0.0


func _water_crossing(previous: Vector3, next: Vector3) -> Dictionary:
	if not is_instance_valid(basin) or not basin.has_method("depth_at"):
		return {}
	if _depth_at(next) <= 0.05:
		return {}
	var level: float = _water_level()
	if is_instance_valid(basin) and basin.has_method("water_height_at"):
		level = float(basin.call("water_height_at", next.x, next.z))
	if previous.y > level and next.y <= level:
		var denominator: float = maxf(1.0e-6, previous.y - next.y)
		var t: float = clampf((previous.y - level) / denominator, 0.0, 1.0)
		var point: Vector3 = previous.lerp(next, t)
		point.y = level
		return _finish_water(point, velocity.normalized())
	if next.y <= level:
		return _finish_water(previous, velocity.normalized())
	return {}


func _is_water_point(point: Vector3) -> bool:
	if not is_instance_valid(basin) or not basin.has_method("depth_at"):
		return false
	return _depth_at(point) > 0.05 and point.y <= _water_level() + 0.45


# ---------------------------------------------------------------- castle helpers
## The burst is centred a little outside the face.  A ball that strikes a projecting
## buttress first is measured from the PROJECTION, which would push the burst another
## metre away from the wall and barely scratch it; clamp such strikes back to the curtain
## face before applying the offset.  Interior furniture and gate leaves use offset 0.
func _castle_blast_point(point: Vector3, normal: Vector3, offset: float) -> Vector3:
	var direction: Vector3 = normal
	if direction.length_squared() < 1.0e-6:
		direction = Vector3.UP
	direction = direction.normalized()
	if offset <= 0.001 or not is_instance_valid(castle) \
			or not castle.has_method("wall_half"):
		return point + direction * offset
	var half: float = float(castle.call("wall_half"))
	var local: Vector3 = castle.to_local(point)
	var normal_local: Vector3 = castle.global_basis.inverse() * direction
	var plane: float = half + 0.55
	var along_x: bool = absf(normal_local.x) >= absf(normal_local.z)
	var sign_value: float = signf(normal_local.x if along_x else normal_local.z)
	var axis: float = local.x if along_x else local.z
	var depth: float = (axis - sign_value * plane) * sign_value
	if depth >= -0.6 and depth <= 1.8:
		if along_x:
			local.x = sign_value * plane
		else:
			local.z = sign_value * plane
		point = castle.to_global(local)
	return point + direction * offset


func _is_wooden_target(collider: Variant) -> bool:
	if not (collider is Node):
		return false
	var node := collider as Node
	return bool(node.get_meta("castle_gate", false)) \
		or bool(node.get_meta("castle_furnishing", false)) \
		or str(node.get_meta("surface", "")) == "wood"


func _is_castle(point: Vector3, collider: Variant) -> bool:
	if not is_instance_valid(castle):
		return false
	if _is_under(collider, castle):
		return true
	if castle.has_method("wall_half"):
		var half: float = float(castle.call("wall_half"))
		var local_point: Vector3 = castle.to_local(point)
		if absf(local_point.x) <= half + 8.0 and absf(local_point.z) <= half + 8.0 \
				and local_point.y > -2.0 and local_point.y < 45.0:
			return true
	return false


func _collider_name(collider: Variant) -> String:
	if collider is Node:
		return String((collider as Node).name)
	return ""


func _is_under(node: Variant, root: Node) -> bool:
	if not is_instance_valid(root) or not (node is Node):
		return false
	var walk: Node = node
	var guard := 0
	while walk != null and guard < 64:
		if walk == root:
			return true
		walk = walk.get_parent()
		guard += 1
	return false


# ---------------------------------------------------------------- presentation
func _ensure_mesh() -> void:
	if is_instance_valid(_mesh):
		return
	_mesh = MeshInstance3D.new()
	_mesh.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	_mesh.mesh = sphere
	_mesh.material_override = _shared_iron()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## One material and one 32x32 mottled map for the whole pool: the ball turns in flight
## and the blotches travel across it, but there is no extra draw call and no asset file.
static func _shared_iron() -> StandardMaterial3D:
	if _iron_material != null:
		return _iron_material
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = 620031
	var blobs: Array[Vector3] = []
	for i: int in 14:
		blobs.append(Vector3(seed_rng.randf_range(0.0, 32.0), seed_rng.randf_range(0.0, 32.0),
			seed_rng.randf_range(0.07, 0.20)))
	for y: int in 32:
		for x: int in 32:
			var grain: float = seed_rng.randf_range(0.86, 1.06)
			for blob: Vector3 in blobs:
				var d: float = Vector2(float(x) - blob.x, float(y) - blob.y).length()
				grain *= 1.0 - float(blob.z) * exp(-d * d / 18.0)
			var tone: float = clampf(grain, 0.55, 1.12)
			image.set_pixel(x, y, Color(0.14 * tone, 0.15 * tone, 0.17 * tone, 1.0))
	_iron_texture = ImageTexture.create_from_image(image)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.85, 0.87, 0.92)
	iron.albedo_texture = _iron_texture
	iron.metallic = 0.85
	iron.roughness = 0.3
	_iron_material = iron
	return iron


func _collect_own_rids() -> void:
	_own_rids.clear()
	if not is_instance_valid(owner_boat):
		return
	var body := owner_boat as CollisionObject3D
	if body != null:
		_own_rids.append(body.get_rid())
	for found: Node in owner_boat.find_children("*", "CollisionObject3D", true, false):
		var collision_object := found as CollisionObject3D
		if collision_object == null:
			continue
		var rid: RID = collision_object.get_rid()
		if not _own_rids.has(rid):
			_own_rids.append(rid)
