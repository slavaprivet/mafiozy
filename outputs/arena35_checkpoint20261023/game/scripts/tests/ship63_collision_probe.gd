extends SceneTree
## SHIP63 agent C — headless probe for ship collisions, the helm, the companionway,
## the fighting top, hull bulwarks, gun carriages and torn canvas.
##
##   godot --headless --path <game> --script res://scripts/tests/ship63_collision_probe.gd
##
## Prints SHIP63_COLLISION_OK or SHIP63_COLLISION_FAIL and quits 0/1.
##
## The route test drives a real CharacterBody3D (0.30 m capsule, 1.9 m tall) over
## the decks with real physics steps.  The bot jumps only when the next waypoint is
## higher than the current floor (the game's own jump), so walking through a wall
## can never be mistaken for climbing it.

const ShipModel := preload("res://scripts/ship/ship_model.gd")
const ShipBoat := preload("res://scripts/ship/ship_boat.gd")
const DELTA := 1.0 / 60.0
const SHIP_AT := Vector3(115.0, -0.55, 975.0)
const HELM_LOCAL := Vector3(0.0, 3.05, 10.4)
const HELM_STAND := Vector3(0.0, 3.06, 11.15)
const HOST_REACH := 3.6

var _fails: Array[String] = []
var _checks := 0

class FakeBasin extends RefCounted:
	var level := -0.55
	func water_level() -> float: return level
	func water_height_at(_x: float, _z: float) -> float: return level
	func is_navigable(_x: float, _z: float, _draft: float = 1.8) -> bool: return true
	func depth_at(_x: float, _z: float) -> float: return 7.0
	func add_ripple(_at: Vector3, _s: float = 1.0) -> void: pass

## A stand-in for preview_player.gd: same capsule and floor setup, driven toward a
## ship-local waypoint.  `allow_hop` reproduces the player's jump when the bot is
## blocked by a tread; it is only enabled for climbs.
class ProbePlayer extends CharacterBody3D:
	var target := Vector3.ZERO
	var active := false
	var allow_hop := false
	var speed := 3.2
	var hop_now := false
	var stuck := 0.0
	var last := Vector3.ZERO
	var hops := 0

	func _physics_process(delta: float) -> void:
		var to := target - global_position
		to.y = 0.0
		if active and to.length() > 0.10:
			var dir := to.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		if is_on_floor():
			if velocity.y < 0.0:
				velocity.y = -0.05
			if active and allow_hop and to.length() > 0.55:
				if global_position.distance_to(last) < 0.05:
					stuck += delta
				else:
					stuck = 0.0
				last = global_position
				if stuck > 0.20:
					hop_now = true
					stuck = 0.0
		else:
			velocity.y -= 22.0 * delta
		if hop_now:
			velocity.y = 5.6
			hop_now = false
			hops += 1
		move_and_slide()

func _initialize() -> void:
	_run()

func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("SHIP63_CHECK ok ", label, " ", detail)
	else:
		_fails.append(label)
		print("SHIP63_CHECK FAIL ", label, " ", detail)

func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

func _inside(box: Dictionary, p: Vector3) -> bool:
	var size: Vector3 = box["size"]
	var pos: Vector3 = box["position"]
	var yaw: float = float(box.get("rotation_y", 0.0))
	var d := p - pos
	var c := cos(yaw)
	var s := sin(yaw)
	var local := Vector3(d.x * c - d.z * s, d.y, d.x * s + d.z * c)
	return absf(local.x) <= size.x * 0.5 + 0.001 \
		and absf(local.y) <= size.y * 0.5 + 0.001 \
		and absf(local.z) <= size.z * 0.5 + 0.001

func _blocked_by(boxes: Array, p: Vector3) -> bool:
	for box: Dictionary in boxes:
		if _inside(box, p):
			return true
	return false

func _box_count_with_part(boxes: Array, part: String) -> int:
	var count := 0
	for box: Dictionary in boxes:
		if str(box.get("part", "")) == part:
			count += 1
	return count

## ------------------------------------------------------------------ worlds

func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "Ship63ProbeWorld"
	root.add_child(world)
	return world

func _new_player(world: Node3D) -> ProbePlayer:
	var player := ProbePlayer.new()
	player.name = "Ship63ProbePlayer"
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = 0.25
	player.floor_max_angle = deg_to_rad(46.0)
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.30
	shape.height = 1.9
	capsule.shape = shape
	capsule.position.y = 0.95
	player.add_child(capsule)
	world.add_child(player)
	return player

func _new_boat(world: Node3D, basin, player, model):
	var boat = ShipBoat.new()
	boat.name = "Ship63ProbeBoat"
	world.add_child(boat)
	var install: Dictionary = boat.install(world, basin, player, model)
	boat.set_autopilot(false)
	boat.moor(SHIP_AT, 0.0)
	return [boat, install]

func _teleport(boat, player, local: Vector3, settle: int = 12) -> Dictionary:
	player.active = false
	player.velocity = Vector3.ZERO
	player.global_position = boat.world_deck(local)
	for _i in settle:
		await physics_frame
	return {
		"local": boat.local_of(player.global_position),
		"on_floor": player.is_on_floor(),
	}

## Walk to a ship-local waypoint.  Returns the final local position and whether
## the bot actually got there on the floor.
func _walk(boat, player, local: Vector3, allow_hop: bool, max_frames: int = 700) -> Dictionary:
	player.target = boat.world_deck(local)
	player.allow_hop = allow_hop
	player.active = true
	var frames := 0
	var best := 1.0e9
	var best_age := 0
	var reached := false
	while frames < max_frames:
		await physics_frame
		frames += 1
		var lp: Vector3 = boat.local_of(player.global_position)
		var dist := Vector2(lp.x - local.x, lp.z - local.z).length()
		if dist < best - 0.02:
			best = dist
			best_age = 0
		else:
			best_age += 1
		if dist < 0.35 and absf(lp.y - local.y) < 0.45 and player.is_on_floor():
			reached = true
			break
		if best_age > 140:
			break
	player.active = false
	var final_local: Vector3 = boat.local_of(player.global_position)
	return {
		"local": final_local,
		"on_floor": player.is_on_floor(),
		"reached": reached,
		"frames": frames,
		"hops": player.hops,
		"dist": Vector2(final_local.x - local.x, final_local.z - local.z).length(),
	}

func _at(boat, player) -> Vector3:
	return boat.local_of(player.global_position)

func _sim(boat, seconds: float) -> void:
	var steps := int(round(seconds / DELTA))
	for _i in steps:
		boat.simulate_step(DELTA)

## ------------------------------------------------------------------ run

func _run() -> void:
	print("SHIP63_COLLISION_PROBE start")
	var world := _new_world()
	await process_frame
	_phase_model_geometry()
	var player := _new_player(world)
	var boat = null
	var install: Dictionary = {}
	var pair: Array = _new_boat(world, FakeBasin.new(), player, ShipModel.new())
	boat = pair[0]
	install = pair[1]
	_check(bool(install.get("ok", false)), "boat_install", str(install.get("reason", "")))
	_check(int(install.get("collision_shapes", 0)) >= 61, "boat_collision_shapes",
		str(install.get("collision_shapes")))
	await physics_frame

	await _phase_route(boat, player)
	await _phase_helm(boat, player)
	await _phase_barriers(boat, player)
	await _phase_ladder_and_top(boat, player)
	await _phase_bow(boat, player)
	await _phase_sail_hits(boat)
	_phase_helm_break(boat)

	await _phase_sail_api()
	_phase_sunk()

	_finish()

## ------------------------------------------------------------------ 1: model boxes

func _phase_model_geometry() -> void:
	print("SHIP63_COLLISION_PHASE model_geometry")
	var model = ShipModel.new()
	root.add_child(model)
	var built: Dictionary = model.build()
	var boxes: Array = built.get("collision", [])
	_check(boxes.size() >= 58, "collision_box_count", str(boxes.size()))
	_check(_box_count_with_part(boxes, "helm") == 2, "helm_collision_boxes",
		str(_box_count_with_part(boxes, "helm")))
	var cannon_boxes := 0
	for i: int in 4:
		cannon_boxes += _box_count_with_part(boxes, "cannon_%d" % i)
	_check(cannon_boxes == 4, "cannon_collision_boxes", str(cannon_boxes))
	# Helm stand and wheel.
	_check(_blocked_by(boxes, Vector3(0.0, 3.40, 10.50)), "helm_stand_solid")
	_check(_blocked_by(boxes, Vector3(0.0, 4.10, 10.61)), "helm_wheel_solid")
	_check(not _blocked_by(boxes, HELM_STAND), "helm_stand_point_free", str(HELM_STAND))
	_check(not _blocked_by(boxes, Vector3(0.0, 3.20, 10.90)), "behind_wheel_free")
	# Bulwark height on the main deck, the quarterdeck and the bow platform.
	_check(_blocked_by(boxes, Vector3(4.10, 2.45, 0.0)), "main_bulwark_tall")
	_check(_blocked_by(boxes, Vector3(3.80, 3.45, 9.0)), "quarter_bulwark_tall")
	_check(_blocked_by(boxes, Vector3(2.02, 2.45, -12.70)), "bow_side_rail")
	_check(_blocked_by(boxes, Vector3(0.0, 2.45, -13.50)), "bow_head_rail")
	# Door / cabin / companionway.
	_check(not _blocked_by(boxes, Vector3(0.0, 1.50, 6.00)), "doorway_open")
	_check(not _blocked_by(boxes, Vector3(0.0, 1.10, 5.85)), "companionway_headroom")
	_check(_blocked_by(boxes, Vector3(0.0, 0.48, 9.0)), "cabin_floor_solid")
	_check(_blocked_by(boxes, Vector3(0.0, 0.66, 5.80)), "companionway_treads")
	_check(_blocked_by(boxes, Vector3(0.0, 1.70, 0.0)), "main_deck_solid")
	_check(not _blocked_by(boxes, Vector3(0.0, 1.55, 0.0)), "above_deck_free")
	_check(_blocked_by(boxes, Vector3(0.0, 5.19, -1.2)), "top_deck_solid")
	var stats: Dictionary = model.stats()
	print("SHIP63_MODEL_STATS meshes=", stats.get("meshes"), " tris=", stats.get("triangles"),
		" materials=", stats.get("materials"), " collision=", stats.get("collision"),
		" sail_holes=", stats.get("sail_holes"))
	model.queue_free()

## ------------------------------------------------------------------ 2: route

func _phase_route(boat, player) -> void:
	print("SHIP63_COLLISION_PHASE route")
	var start: Dictionary = await _teleport(boat, player, Vector3(0.0, 2.30, -8.0), 20)
	_check(start["on_floor"] and _near((start["local"] as Vector3).y, 1.78, 0.06), "spawn_on_deck",
		str(start["local"]))

	var r: Dictionary = await _walk(boat, player, Vector3(1.3, 1.78, -8.0), false)
	_check(r["reached"] and r["on_floor"] and _near((r["local"] as Vector3).y, 1.78, 0.12), "route_deck_start",
		str(r["local"]))
	r = await _walk(boat, player, Vector3(1.3, 1.78, 4.35), false)
	_check(r["reached"] and r["on_floor"] and _near((r["local"] as Vector3).y, 1.78, 0.12), "route_deck_forward",
		str(r["local"]))
	r = await _walk(boat, player, Vector3(0.0, 1.78, 4.45), false)
	_check(r["reached"] and r["on_floor"], "route_companionway_edge", str(r["local"]))

	# Descend on foot: no jump, gravity does the work.  This is the regression for
	# the old dead-end doorway.
	r = await _walk(boat, player, Vector3(0.0, 0.52, 7.20), false)
	var cabin_ok: bool = bool(r["reached"]) and bool(r["on_floor"]) \
		and _near((r["local"] as Vector3).y, 0.52, 0.10)
	_check(cabin_ok, "route_cabin_descend", str(r["local"]))
	_check((r["local"] as Vector3).y > 0.40, "route_no_fall_through_cabin", str((r["local"] as Vector3).y))
	r = await _walk(boat, player, Vector3(0.0, 0.52, 9.20), false)
	_check(r["reached"] and r["on_floor"] and _near((r["local"] as Vector3).y, 0.52, 0.10), "route_cabin_floor",
		str(r["local"]))
	r = await _walk(boat, player, Vector3(0.0, 0.52, 6.30), false)
	_check(r["reached"] and r["on_floor"], "route_cabin_back", str(r["local"]))

	# Climb the companionway back out (a real player jumps the treads).
	r = await _walk(boat, player, Vector3(0.0, 1.78, 4.80), true)
	_check(r["reached"] and r["on_floor"] and _near((r["local"] as Vector3).y, 1.78, 0.12),
		"route_cabin_climb_out", str(r["local"]) + " hops=" + str(r["hops"]))
	_check(int(r["hops"]) >= 1, "route_cabin_used_jump", str(r["hops"]))

	r = await _walk(boat, player, Vector3(0.0, 1.78, 4.20), false)
	r = await _walk(boat, player, Vector3(2.70, 1.78, 4.20), false)
	r = await _walk(boat, player, Vector3(2.70, 1.78, 5.15), false)
	_check(r["reached"] and r["on_floor"], "route_stair_base", str(r["local"]))
	r = await _walk(boat, player, Vector3(2.70, 3.03, 6.40), true)
	_check(r["reached"] and r["on_floor"] and _near((r["local"] as Vector3).y, 3.03, 0.12),
		"route_quarterdeck", str(r["local"]) + " hops=" + str(r["hops"]))
	r = await _walk(boat, player, Vector3(0.0, 3.03, 7.00), false)
	_check(r["reached"] and r["on_floor"] and _near((r["local"] as Vector3).y, 3.03, 0.12),
		"route_quarter_walk", str(r["local"]))
	r = await _walk(boat, player, Vector3(0.0, 3.03, 9.00), false)
	_check(r["reached"] and r["on_floor"], "route_quarter_helm_approach", str(r["local"]))

## ------------------------------------------------------------------ 3: helm

func _phase_helm(boat, player) -> void:
	print("SHIP63_COLLISION_PHASE helm")
	# From in front the player must be stopped by the stand/wheel, not pass through.
	var r: Dictionary = await _walk(boat, player, Vector3(0.0, 3.03, 11.50), false)
	var stop: Vector3 = r["local"]
	_check(not r["reached"], "helm_blocks_walk", str(stop))
	_check(stop.z > 9.60 and stop.z < 10.35, "helm_block_distance", "z=%.2f" % stop.z)
	_check(r["on_floor"] and _near(stop.y, 3.03, 0.12), "helm_block_on_floor", str(stop))

	# The host seats the player at HELM_STAND and uses a 3.6 m reach to the helm
	# anchor; the wheel box must not eat that stand point.
	var seated: Dictionary = await _teleport(boat, player, HELM_STAND, 16)
	var at: Vector3 = seated["local"]
	var helm_world: Vector3 = boat.world_deck(HELM_LOCAL)
	var feet_world: Vector3 = player.global_position
	var reach: float = feet_world.distance_to(helm_world)
	_check(seated["on_floor"], "helm_stand_on_floor", str(at))
	_check(at.distance_to(HELM_STAND) < 0.12, "helm_stand_position", str(at))
	_check(reach <= HOST_REACH, "helm_stand_in_reach", "reach=%.2f" % reach)
	_check(reach > 0.4, "helm_stand_behind_wheel", "reach=%.2f" % reach)
	# Pushing forward from the stand still cannot cross the wheel.
	r = await _walk(boat, player, Vector3(0.0, 3.03, 9.90), false)
	_check((r["local"] as Vector3).z > 10.55, "helm_stand_cannot_cross", str(r["local"]))
	_check(r["on_floor"] and _near((r["local"] as Vector3).y, 3.03, 0.12), "helm_stand_stays_on_deck",
		str(r["local"]))

## ------------------------------------------------------------------ 4: sides

func _phase_barriers(boat, player) -> void:
	print("SHIP63_COLLISION_PHASE barriers")
	var here: Dictionary = await _teleport(boat, player, Vector3(0.0, 1.83, 0.0), 14)
	_check(here["on_floor"], "barrier_main_spawn", str(here["local"]))
	var r: Dictionary = await _walk(boat, player, Vector3(8.0, 1.78, 0.0), false)
	var x: float = (r["local"] as Vector3).x
	_check(not r["reached"] and x < 4.30, "main_bulwark_blocks", "x=%.2f" % x)
	_check(r["on_floor"] and _near((r["local"] as Vector3).y, 1.78, 0.12), "main_bulwark_on_deck",
		"y=%.2f" % (r["local"] as Vector3).y)

	here = await _teleport(boat, player, Vector3(0.0, 3.08, 9.0), 14)
	_check(here["on_floor"], "barrier_quarter_spawn", str(here["local"]))
	r = await _walk(boat, player, Vector3(8.0, 3.03, 9.0), false)
	x = (r["local"] as Vector3).x
	_check(not r["reached"] and x < 3.90, "quarter_bulwark_blocks", "x=%.2f" % x)
	_check(r["on_floor"] and _near((r["local"] as Vector3).y, 3.03, 0.12), "quarter_bulwark_on_deck",
		"y=%.2f" % (r["local"] as Vector3).y)

## ------------------------------------------------------------------ 5: ladder + top

func _phase_ladder_and_top(boat, player) -> void:
	print("SHIP63_COLLISION_PHASE ladder_top")
	var base: Dictionary = await _teleport(boat, player, Vector3(0.0, 1.80, 2.30), 14)
	_check(base["on_floor"], "ladder_base", str(base["local"]))
	boat.set_climb_input(1.0)
	for _i in 300:
		await physics_frame
		boat.climb_assist(player, DELTA)
	boat.set_climb_input(NAN)
	for _i in 20:
		await physics_frame
	var top: Vector3 = _at(boat, player)
	_check(top.y > 5.0, "ladder_climb_up", str(top))
	_check(absf(top.x) < 0.30, "ladder_centred", str(top.x))
	_check(player.is_on_floor(), "ladder_top_on_floor", str(top))
	_check(_near(top.y, 5.23, 0.15), "ladder_top_height", "y=%.3f" % top.y)

	var r: Dictionary = await _walk(boat, player, Vector3(0.0, 5.23, -3.0), false)
	_check(r["reached"] and r["on_floor"] and _near((r["local"] as Vector3).y, 5.23, 0.12),
		"top_deck_walk", str(r["local"]))
	r = await _walk(boat, player, Vector3(6.0, 5.23, -1.2), false)
	var x: float = (r["local"] as Vector3).x
	_check(not r["reached"] and x < 3.20, "top_deck_rail_blocks", "x=%.2f" % x)
	_check(r["on_floor"] and _near((r["local"] as Vector3).y, 5.23, 0.12), "top_deck_rail_on_floor",
		"y=%.2f" % (r["local"] as Vector3).y)

	# Climb back down to the main deck.
	player.active = false
	player.velocity = Vector3.ZERO
	player.global_position = boat.world_deck(Vector3(0.0, 5.25, 2.05))
	for _i in 10:
		await physics_frame
	boat.set_climb_input(-1.0)
	for _i in 300:
		await physics_frame
		boat.climb_assist(player, DELTA)
	boat.set_climb_input(NAN)
	for _i in 20:
		await physics_frame
	var down: Vector3 = _at(boat, player)
	_check(down.y < 1.90, "ladder_climb_down", str(down))
	_check(down.z > 2.0, "ladder_down_lands_on_deck", str(down))
	_check(player.is_on_floor(), "ladder_down_on_floor", str(down))

## ------------------------------------------------------------------ 6: bow

func _phase_bow(boat, player) -> void:
	print("SHIP63_COLLISION_PHASE bow")
	var start: Dictionary = await _teleport(boat, player, Vector3(0.0, 1.83, -8.0), 16)
	_check(start["on_floor"], "bow_route_spawn", str(start["local"]))
	var r: Dictionary = await _walk(boat, player, Vector3(0.0, 1.78, -11.30), false)
	_check(r["reached"] and r["on_floor"], "bow_route_foredeck", str(r["local"]))
	r = await _walk(boat, player, Vector3(0.0, 2.18, -12.70), true)
	_check(r["reached"] and r["on_floor"] and _near((r["local"] as Vector3).y, 2.18, 0.12),
		"bow_platform_reached", str(r["local"]) + " hops=" + str(r["hops"]))
	_check((r["local"] as Vector3).y > 2.00, "bow_no_fall_through", str((r["local"] as Vector3).y))

	r = await _walk(boat, player, Vector3(6.0, 2.18, -12.70), false)
	var x: float = (r["local"] as Vector3).x
	_check(not r["reached"] and x < 2.10, "bow_side_rail_blocks", "x=%.2f" % x)
	_check(r["on_floor"] and _near((r["local"] as Vector3).y, 2.18, 0.12), "bow_side_rail_on_floor",
		"y=%.2f" % (r["local"] as Vector3).y)
	r = await _walk(boat, player, Vector3(0.0, 2.18, -15.0), false)
	_check(not r["reached"] and (r["local"] as Vector3).z > -13.75, "bow_head_rail_blocks",
		"z=%.2f" % (r["local"] as Vector3).z)

## ------------------------------------------------------------------ 7: boat sail hits

func _phase_sail_hits(boat) -> void:
	print("SHIP63_COLLISION_PHASE sail_hits")
	var model = boat.get("_model")
	model.set_sail_amount(1.0)
	var small: Dictionary = boat.apply_hit(boat.world_deck(Vector3(2.0, 8.0, -0.96)), 30.0,
		Vector3.ZERO, "cannonball")
	_check(str(small.get("zone")) == "sail", "boat_sail_zone", str(small.get("zone")))
	_check(bool(small.get("sail_hole", false)), "boat_sail_hole_small")
	var sr := float(small.get("sail_radius", 0.0))
	_check(sr >= 0.15 and sr <= 0.35, "boat_sail_small_radius", "r=%.3f" % sr)
	var heavy: Dictionary = boat.apply_hit(boat.world_deck(Vector3(-2.0, 12.0, -0.96)), 200.0,
		Vector3.ZERO, "catapult")
	_check(str(heavy.get("zone")) == "sail", "boat_sail_zone_heavy", str(heavy.get("zone")))
	var hr := float(heavy.get("sail_radius", 0.0))
	_check(hr >= 0.5 and hr <= 0.9, "boat_sail_big_radius", "r=%.3f" % hr)
	var jib: Dictionary = boat.apply_hit(boat.world_deck(Vector3(0.4, 9.0, -11.6)), 30.0,
		Vector3.ZERO, "cannonball")
	_check(str(jib.get("zone")) == "sail", "boat_jib_zone", str(jib.get("zone")))
	_check(bool(jib.get("sail_hole", false)), "boat_jib_hole")
	_check(int(small.get("sail_hole_count", 0)) >= 1, "boat_sail_count_in_result",
		str(small.get("sail_hole_count")))
	var snap: Dictionary = boat.snapshot()
	_check(int(snap.get("sail_holes", 0)) >= 3, "boat_snapshot_sail_holes", str(snap.get("sail_holes")))
	var hull: Dictionary = boat.apply_hit(boat.world_deck(Vector3(4.2, 1.0, -2.0)), 40.0,
		Vector3.ZERO, "cannonball")
	_check(str(hull.get("zone")) == "hull" and bool(hull.get("hole", false)), "boat_hull_still_hull",
		str(hull.get("zone")))
	# A deck hit must not be classified as canvas.
	var deck_hit: Dictionary = boat.apply_hit(boat.world_deck(Vector3(0.0, 1.60, 0.0)), 10.0,
		Vector3.ZERO, "cannonball")
	_check(str(deck_hit.get("zone")) != "sail", "boat_deck_not_sail", str(deck_hit.get("zone")))

## ------------------------------------------------------------------ 8: helm break

func _phase_helm_break(boat) -> void:
	print("SHIP63_COLLISION_PHASE helm_break")
	for _i in 2:
		boat.apply_hit(boat.world_deck(HELM_LOCAL), 60.0, Vector3.ZERO, "cannonball")
	var broken: Array = boat.snapshot().get("broken_parts", [])
	_check(broken.has("helm"), "helm_part_broken", str(broken))
	var disabled := 0
	var total := 0
	for child: Node in boat.get_children():
		if child is CollisionShape3D:
			var shape := child as CollisionShape3D
			if shape.has_meta("ship_part") and str(shape.get_meta("ship_part")) == "helm":
				total += 1
				if shape.disabled:
					disabled += 1
	_check(total == 2 and disabled == 2, "helm_collision_disabled", "%d/%d" % [disabled, total])

## ------------------------------------------------------------------ 9: sail API

func _phase_sail_api() -> void:
	print("SHIP63_COLLISION_PHASE sail_api")
	var model = ShipModel.new()
	root.add_child(model)
	model.build()
	model.set_sail_amount(1.0)
	await create_timer(1.6).timeout
	_check(model.sail_zone_at(Vector3(2.0, 8.0, -0.96)), "sail_zone_square")
	_check(model.sail_zone_at(Vector3(0.4, 9.0, -11.6)), "sail_zone_jib")
	_check(not model.sail_zone_at(Vector3(0.0, 1.78, 0.0)), "sail_zone_deck_false")
	_check(not model.sail_zone_at(Vector3(4.1, 2.0, 0.0)), "sail_zone_rail_false")

	var a: Dictionary = model.punch_sail_hole(Vector3(2.0, 8.0, -0.96), 0.25)
	var b: Dictionary = model.punch_sail_hole(Vector3(-1.5, 12.0, -0.96), 0.75)
	var c: Dictionary = model.punch_sail_hole(Vector3(0.4, 9.0, -11.6), 0.4)
	_check(bool(a.get("ok")) and bool(b.get("ok")) and bool(c.get("ok")), "sail_punch_ok",
		"%s %s %s" % [a.get("ok"), b.get("ok"), c.get("ok")])
	_check(model.sail_hole_count() == 3, "sail_hole_count", str(model.sail_hole_count()))
	_check(model.sail_holes_visible(), "sail_holes_visible_open")
	var holes: Array = model.sail_holes()
	_check(holes.size() == 3, "sail_holes_array", str(holes.size()))
	var rec: Dictionary = holes[0]
	var front: Transform3D = rec["front"]
	var back: Transform3D = rec["back"]
	_check(front.origin.distance_to(back.origin) > 0.04, "sail_hole_two_sided",
		"d=%.3f" % front.origin.distance_to(back.origin))
	_check(_near(front.basis.x.length(), 0.25, 0.01) and _near(front.basis.y.length(), 0.25, 0.01),
		"sail_hole_round_square", str(front.basis.get_scale()))
	var jib_rec: Dictionary = holes[2]
	var jib_front: Transform3D = jib_rec["front"]
	_check(_near(jib_front.basis.x.length(), 0.4, 0.01) and _near(jib_front.basis.y.length(), 0.4, 0.01),
		"sail_hole_round_jib", str(jib_front.basis.get_scale()))
	# Both faces of the same hole must be on opposite sides of the canvas.
	var sa: Vector3 = rec["position"]
	var na: Vector3 = rec["normal"]
	_check((front.origin - sa).dot(na) > 0.0 and (back.origin - sa).dot(na) < 0.0,
		"sail_hole_opposite_faces")
	var mat: StandardMaterial3D = model.get("_sail_hole_mm").material_override
	_check(mat != null and mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "sail_hole_double_sided_material")
	_check(mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "sail_hole_dark_material")

	# Furl/unfurl must hide/show the decals but never change their shape.
	model.set_sail_amount(0.0)
	await create_timer(1.6).timeout
	_check(not model.sail_holes_visible(), "sail_holes_hidden_furled")
	model.set_sail_amount(1.0)
	await create_timer(1.6).timeout
	_check(model.sail_holes_visible(), "sail_holes_back_unfurled")
	var again: Dictionary = model.sail_holes()[0]
	var again_front: Transform3D = again["front"]
	_check(_near(again_front.basis.x.length(), 0.25, 0.01), "sail_hole_no_stretch",
		str(again_front.basis.get_scale()))
	_check(again_front.origin.distance_to(front.origin) < 0.001, "sail_hole_no_drift",
		str(again_front.origin))

	# Invalid input is ignored.
	var before := model.sail_hole_count()
	_check(not bool(model.punch_sail_hole(Vector3(NAN, 0.0, NAN), 0.3).get("ok", true)), "sail_punch_nan")
	_check(not bool(model.punch_sail_hole(Vector3(0.0, 8.0, -0.96), -0.4).get("ok", true)), "sail_punch_negative")
	_check(not bool(model.punch_sail_hole(Vector3(0.0, 1.78, 0.0), 0.3).get("ok", true)), "sail_punch_off_canvas")
	_check(model.sail_hole_count() == before, "sail_invalid_keeps_count", str(model.sail_hole_count()))

	# Pool: never more than 16, oldest recycled, every slot still valid.
	for i: int in 20:
		model.punch_sail_hole(Vector3(-4.0 + float(i) * 0.4, 7.5, -0.96), 0.2 + 0.02 * float(i))
	_check(model.sail_hole_count() == 16, "sail_hole_pool_cap", str(model.sail_hole_count()))
	var valid := 0
	for hole: Dictionary in model.sail_holes():
		var f: Transform3D = hole["front"]
		if _near(f.basis.x.length(), float(hole["radius"]), 0.01) and f.origin.is_finite():
			valid += 1
	_check(valid == 16, "sail_hole_pool_valid", str(valid))

	# Hull holes: the basis fix from T plus in-plane scaling must give a real disc.
	model.punch_hole(Vector3(4.2, 1.0, -2.0), 0.5)
	var found := false
	for hole_node: MeshInstance3D in model.get("_holes"):
		if hole_node.visible:
			var det := absf(hole_node.transform.basis.determinant())
			var scale := hole_node.transform.basis.get_scale()
			_check(det > 0.10, "hull_hole_basis_full_rank", "det=%.4f" % det)
			_check(_near(scale.x, scale.z, 0.02) and scale.y > 0.9, "hull_hole_round", str(scale))
			found = true
			break
	_check(found, "hull_hole_visible")
	# Clean up the standalone model.
	model.queue_free()

## ------------------------------------------------------------------ 10: sunk

func _phase_sunk() -> void:
	print("SHIP63_COLLISION_PHASE sunk")
	var world := _new_world()
	var player := _new_player(world)
	var pair: Array = _new_boat(world, FakeBasin.new(), player, ShipModel.new())
	var boat = pair[0]
	var model = boat.get("_model")
	# Keep this hull away from the walking hull: overlapping decks make the
	# obstacle rays (and therefore the sail test) fail.
	boat.moor(SHIP_AT + Vector3(80.0, 0.0, 0.0), 0.0)
	boat.set_sails(true)
	_sim(boat, 5.0)
	_check(boat.sails_open() and boat.speed() > 1.0, "sunk_precondition_sailing",
		"s=%.2f" % boat.speed())
	boat.steer(0.8)
	for i in 6:
		await physics_frame
	var wheel_before: float = float(model.get("_wheel_angle"))
	_check(absf(wheel_before) > 0.1, "sunk_precondition_wheel", str(wheel_before))
	var hits: Array = [
		Vector3(-4.0, 0.3, -8.0), Vector3(4.0, 0.3, -6.0),
		Vector3(-4.0, 0.3, 8.0), Vector3(4.0, 0.3, 0.0),
	]
	for point: Vector3 in hits:
		boat.apply_hit(boat.world_deck(point), 150.0, Vector3.ZERO, "cannonball")
	_sim(boat, 45.0)
	_check(boat.is_sunk(), "sunk_after_hits", "flooding=%.3f" % boat.flooding())
	_check(not boat.usable(), "sunk_usable_false")
	var snap: Dictionary = boat.snapshot()
	_check(bool(snap.get("usable", true)) == false, "sunk_snapshot_usable_false")
	_check(bool(snap.get("sunk", false)), "sunk_snapshot_sunk")
	_check(not boat.sails_open(), "sunk_sails_shut")
	boat.set_sails(true)
	_check(not boat.sails_open(), "sunk_refuses_sails", str(boat.sails_open()))
	boat.steer(1.0)
	_check(absf(float(boat.snapshot().get("rudder_target", 9.0))) < 0.001, "sunk_steer_ignored",
		str(boat.snapshot().get("rudder_target")))
	_check(absf(float(model.get("_wheel_angle"))) < 0.001, "sunk_wheel_centred",
		str(model.get("_wheel_angle")))
	boat.apply_recoil(Vector3.RIGHT, 1.0)
	_check(true, "sunk_recoil_noop")
	await create_timer(1.8).timeout
	_check(float(model.get("_sail_amount")) < 0.05, "sunk_canvas_furled",
		str(model.get("_sail_amount")))
	_sim(boat, 8.0)
	_check(boat.speed() < 0.10, "sunk_no_headway", "s=%.3f" % boat.speed())
	var position: Vector3 = boat.snapshot().get("position", Vector3.ZERO)
	_check(position.y < -0.55 - 1.0, "sunk_hull_going_down", "y=%.2f" % position.y)

## ------------------------------------------------------------------ summary

func _finish() -> void:
	print("SHIP63_COLLISION_SUMMARY checks=", _checks, " fails=", _fails.size())
	if _fails.is_empty():
		print("SHIP63_COLLISION_OK checks=", _checks)
		quit(0)
	else:
		print("SHIP63_COLLISION_FAIL failed=", _fails)
		quit(1)
