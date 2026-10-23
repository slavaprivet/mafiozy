extends SceneTree
## SHIP61 (agent C) headless probe for `ship_boat.gd`.
##
## The real basin / model are owned by other agents and may not exist yet, so this probe
## uses local test doubles (FakeBasin / FakeModel) shaped exactly like the contract.
## Motion, damage, flooding, repair and the ladder are driven synchronously through
## `simulate_step()`; the moving-platform test uses real CharacterBody3D physics frames.

const ShipBoat := preload("res://scripts/ship/ship_boat.gd")
const DELTA := 1.0 / 60.0
const START := Vector3(62.0, -0.55, 988.0)

var _failures: Array[String] = []
var _checks := 0


## ------------------------------------------------------------------ test doubles

class FakeBasin extends RefCounted:
	var navigable := true
	var level := -0.55
	var ripples := 0

	func water_level() -> float:
		return level

	func water_height_at(x: float, z: float) -> float:
		return level + sin(x * 0.31 + z * 0.17) * 0.06

	func is_navigable(_x: float, _z: float, _draft: float = 1.8) -> bool:
		return navigable

	func depth_at(_x: float, _z: float) -> float:
		return 7.0 if navigable else 0.4

	func add_ripple(_at: Vector3, _strength: float = 1.0) -> void:
		ripples += 1


class FakeModel extends Node3D:
	var holes: Array = []
	var broken: Array[String] = []
	var repaired: Array = []
	var shakes := 0
	var sail_amount := 0.0
	var lever := false
	var mast_broken := false
	var wheel_angle := 0.0

	func _marker(at: Vector3) -> Node3D:
		var node := Node3D.new()
		node.position = at
		add_child(node)
		return node

	func _cannons() -> Array:
		var result: Array = []
		var mounts := [
			Vector3(-3.55, 1.75, -4.2),
			Vector3(3.55, 1.75, -4.2),
			Vector3(-3.55, 1.75, 3.4),
			Vector3(3.55, 1.75, 3.4),
		]
		for index in mounts.size():
			result.append({
				"index": index,
				"side": "port" if index % 2 == 0 else "starboard",
				"node": _marker(mounts[index]),
				"mount": mounts[index],
				"pivot": _marker(mounts[index]),
				"barrel": _marker(mounts[index] + Vector3(0.0, 0.55, 0.0)),
				"muzzle": mounts[index] + Vector3(-1.35, 0.55, 0.0),
			})
		return result

	func build() -> Dictionary:
		return {
			"ok": true,
			"length": 26.0,
			"beam": 8.8,
			"deck_y": 1.75,
			"helm": {"node": _marker(Vector3(0.0, 3.05, 10.4)), "position": Vector3(0.0, 3.05, 10.4)},
			"sail_lever": {"node": _marker(Vector3(1.0, 2.2, 0.2)), "position": Vector3(1.0, 2.2, 0.2)},
			"mast": {"node": _marker(Vector3(0.0, 1.75, -1.0)), "base": Vector3(0.0, 1.75, -1.0), "top": Vector3(0.0, 17.7, -1.0)},
			"sails": {"node": _marker(Vector3(0.0, 4.0, 0.0))},
			"upper_deck": {
				"node": _marker(Vector3(0.0, 5.2, -1.2)),
				"position": Vector3(0.0, 5.2, -1.2),
				"ladder_base": Vector3(0.0, 1.75, 2.3),
			},
			"bow": {"position": Vector3(0.0, 2.15, -13.0)},
			"cannons": _cannons(),
			"crates": {
				"ammo": {"node": _marker(Vector3(-2.0, 0.95, 10.2)), "position": Vector3(-2.0, 0.95, 10.2)},
				"boards": {"node": _marker(Vector3(2.0, 0.95, 10.2)), "position": Vector3(2.0, 0.95, 10.2)},
			},
			"collision": [
				{"position": Vector3(0.0, 1.55, 0.0), "size": Vector3(8.6, 0.4, 25.6), "rotation_y": 0.0},
				{"position": Vector3(0.0, -1.2, 0.0), "size": Vector3(8.6, 2.9, 24.6), "rotation_y": 0.0},
				{"position": Vector3(0.0, 2.85, 9.2), "size": Vector3(8.4, 0.3, 6.4), "rotation_y": 0.0},
				{"position": Vector3(0.0, 5.05, -1.2), "size": Vector3(6.4, 0.3, 6.0), "rotation_y": 0.0},
				{"position": Vector3(0.0, 2.05, -12.7), "size": Vector3(6.0, 0.2, 1.7), "rotation_y": 0.0},
			],
			"parts": [
				{"id": "mast", "hp": 220.0, "node": null},
				{"id": "helm", "hp": 120.0, "node": null},
				{"id": "rail", "hp": 120.0, "node": null},
				{"id": "crate_ammo", "hp": 90.0, "node": null},
				{"id": "crate_boards", "hp": 90.0, "node": null},
				{"id": "cannon_0", "hp": 160.0, "node": null},
				{"id": "cannon_1", "hp": 160.0, "node": null},
				{"id": "cannon_2", "hp": 160.0, "node": null},
				{"id": "cannon_3", "hp": 160.0, "node": null},
				{"id": "transom", "hp": 180.0, "node": null},
				{"id": "bowsprit", "hp": 100.0, "node": null},
				{"id": "upper_deck", "hp": 260.0, "node": null},
			],
		}

	func set_sail_amount(amount: float) -> void:
		sail_amount = amount

	func set_lever(on: bool) -> void:
		lever = on

	func set_wheel_angle(radians: float) -> void:
		wheel_angle = radians

	func set_mast_broken(value: bool) -> void:
		mast_broken = value

	func break_part(id: String) -> bool:
		broken.append(id)
		return true

	func punch_hole(local_position: Vector3, radius: float) -> void:
		holes.append({"position": local_position, "radius": radius})

	func repair_hole(local_position: Vector3, radius: float) -> void:
		repaired.append({"position": local_position, "radius": radius})

	func part_health(_id: String) -> float:
		return 100.0

	func parts() -> Array:
		return []

	func anchors() -> Dictionary:
		return {}

	func shake(_amount: float) -> void:
		shakes += 1


class ProbePlayer extends CharacterBody3D:
	func _physics_process(delta: float) -> void:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
		move_and_slide()


## ------------------------------------------------------------------ harness

func _initialize() -> void:
	_run()


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("SHIP61_BOAT_CHECK ok ", label, " ", detail)
	else:
		_failures.append(label)
		print("SHIP61_BOAT_CHECK FAIL ", label, " ", detail)


func _snapshot_position(boat) -> Vector3:
	var snap: Dictionary = boat.snapshot()
	var value: Variant = snap.get("position", Vector3.ZERO)
	return value as Vector3 if value is Vector3 else Vector3.ZERO


func _new_boat(world: Node3D, basin, player, model):
	var boat = ShipBoat.new()
	boat.name = "ShipBoatProbe"
	world.add_child(boat)
	var result: Dictionary = boat.install(world, basin, player, model)
	boat.set_autopilot(false)
	return [boat, result]


func _free_boat(world: Node3D, boat) -> void:
	if boat == null:
		return
	var debris = boat.get("_debris_container")
	if debris != null and is_instance_valid(debris):
		debris.queue_free()
	if is_instance_valid(boat):
		world.remove_child(boat)
		boat.free()


func _sim(boat, seconds: float) -> void:
	var steps := int(round(seconds / DELTA))
	for _i in steps:
		boat.simulate_step(DELTA)


func _run() -> void:
	var world := Node3D.new()
	world.name = "Ship61ProbeWorld"
	root.add_child(world)
	await process_frame

	await _phase_sailing(world)
	_phase_flooding_and_repair(world)
	_phase_sinking(world)
	_phase_mast_and_parts(world)
	await _phase_climb_and_platform(world)

	var summary := "%d checks, %d failures" % [_checks, _failures.size()]
	if _failures.is_empty():
		print("SHIP61_BOAT_OK ", summary)
		quit(0)
	else:
		print("SHIP61_BOAT_FAIL ", summary, " failed=", _failures)
		quit(1)


## ------------------------------------------------------------------ 1: install + sailing

func _phase_sailing(world: Node3D) -> void:
	print("SHIP61_BOAT_PHASE sailing")
	var basin := FakeBasin.new()
	var model := FakeModel.new()
	var boat = ShipBoat.new()
	boat.name = "ShipBoatSailing"
	world.add_child(boat)
	var install: Dictionary = boat.install(world, basin, null, model)
	boat.set_autopilot(false)
	_check(bool(install.get("ok", false)), "install_ok", str(install.get("reason", "")))
	var start_pos := _snapshot_position(boat)
	_check(start_pos.distance_to(START) < 0.01, "install_start_position", str(start_pos))
	# The host places the player with `boat.to_global(HELM_STAND)` right after install,
	# so the node transform must be readable immediately (not one physics step later).
	_check(boat.global_position.distance_to(start_pos) < 0.05, "node_transform_immediate", str(boat.global_position))
	_check(boat.to_global(Vector3.ZERO).distance_to(start_pos) < 0.05, "to_global_immediate",
		str(boat.to_global(Vector3.ZERO)))
	var snap0: Dictionary = boat.snapshot()
	_check(absf(float(snap0.get("heading_deg", 0.0)) + 65.0) < 0.05, "install_yaw_minus_65", str(snap0.get("heading_deg")))
	_check(int(install.get("collision_shapes", 0)) >= 7, "collision_shapes", str(install.get("collision_shapes")))
	_check(absf(start_pos.y - basin.water_level()) < 0.01, "origin_on_waterline", str(start_pos.y))
	_check(boat.local_of(boat.world_helm()).distance_to(Vector3(0.0, 3.05, 10.4)) < 0.01, "anchor_helm",
		str(boat.local_of(boat.world_helm())))
	_check(boat.local_of(boat.world_sail_lever()).distance_to(Vector3(1.0, 2.2, 0.2)) < 0.01, "anchor_sail_lever")
	_check(boat.local_of(boat.world_crate("ammo")).distance_to(Vector3(-2.0, 0.95, 10.2)) < 0.01, "anchor_crate_ammo")
	_check(boat.local_of(boat.world_crate("boards")).distance_to(Vector3(2.0, 0.95, 10.2)) < 0.01, "anchor_crate_boards")
	_check(boat.local_of(boat.world_deck(Vector3(0.0, 1.75, 0.0))).distance_to(Vector3(0.0, 1.75, 0.0)) < 0.01,
		"world_deck_roundtrip")
	_check(boat.install(world, basin, null, model).get("ok") == false, "install_twice_rejected")

	boat.set_sails(true)
	_check(boat.sails_open(), "sails_open")
	_check(absf(model.sail_amount - 1.0) < 0.001 and model.lever, "sails_model_visual")
	_sim(boat, 5.0)
	var speed_5: float = boat.speed()
	_sim(boat, 10.0)
	var speed_15: float = boat.speed()
	_check(speed_15 > 6.2 and speed_15 <= 6.51, "accel_15s", "s5=%.3f s15=%.3f" % [speed_5, speed_15])
	_check(speed_5 > 2.3 and speed_5 < 3.2, "accel_5s", "s5=%.3f" % speed_5)
	_check(absf(_snapshot_position(boat).y - basin.water_level()) < 0.35, "buoyancy_heave",
		"y=%.3f" % _snapshot_position(boat).y)

	boat.set_sails(false)
	_check(not boat.sails_open(), "sails_closed")
	_check(absf(model.sail_amount) < 0.001 and not model.lever, "sails_model_visual_closed")
	_sim(boat, 1.0)
	var speed_brake: float = boat.speed()
	_check(speed_brake < speed_15 - 0.4 and speed_brake > 4.5, "brake_is_gradual", "s=%.3f" % speed_brake)
	_sim(boat, 9.0)
	_check(boat.speed() < 0.15, "brake_to_zero", "s=%.3f" % boat.speed())

	boat.set_sails(true)
	_sim(boat, 12.0)
	var heading_before: float = boat.heading()
	boat.steer(1.0)
	_sim(boat, 3.0)
	var heading_delta := absf(wrapf(boat.heading() - heading_before, -PI, PI))
	_check(heading_delta > 0.25, "turn_changes_heading", "dh=%.3f" % heading_delta)
	_check(heading_delta <= deg_to_rad(18.0) * 3.2, "turn_rate_capped", "dh=%.3f" % heading_delta)
	_check(absf(float(boat.snapshot().get("rudder", 0.0))) > 0.85, "rudder_reaches_target")
	boat.steer(0.0)
	_sim(boat, 1.5)
	_check(absf(float(boat.snapshot().get("rudder", 1.0))) < 0.15, "rudder_recentres")

	boat.set_sails(false)
	_sim(boat, 10.0)
	_check(boat.speed() < 0.05, "speed_zero_before_turn_test", "s=%.3f" % boat.speed())
	var rest_heading: float = boat.heading()
	boat.steer(1.0)
	_sim(boat, 3.0)
	var rest_delta := absf(wrapf(boat.heading() - rest_heading, -PI, PI))
	_check(rest_delta < 0.001, "no_turn_at_rest", "dh=%.5f" % rest_delta)
	boat.steer(0.0)

	boat.set_sails(true)
	_sim(boat, 12.0)
	var fast_speed: float = boat.speed()
	basin.navigable = false
	_sim(boat, 1.0)
	var shallow_speed: float = boat.speed()
	_check(shallow_speed > fast_speed - 1.2 and shallow_speed > 4.0, "shallow_stop_gradual",
		"fast=%.3f after1s=%.3f" % [fast_speed, shallow_speed])
	_sim(boat, 14.0)
	_check(boat.speed() < 0.05, "shallow_stop", "s=%.3f" % boat.speed())
	_check(bool(boat.snapshot().get("blocked_water", false)), "shallow_blocked_flag")
	basin.navigable = true

	# Obstacle rays: a wall straight ahead of the bows.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(40.0, 12.0, 1.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world.add_child(wall)
	var forward := Vector3(-sin(boat.heading()), 0.0, -cos(boat.heading()))
	wall.global_position = _snapshot_position(boat) + forward * 24.0 + Vector3(0.0, 4.0, 0.0)
	wall.rotation.y = boat.heading()
	await physics_frame
	boat.set_sails(true)
	_sim(boat, 3.0)
	_check(bool(boat.snapshot().get("blocked_obstacle", false)), "obstacle_ray_blocks",
		str(boat.snapshot().get("blocked_obstacle")))
	_sim(boat, 14.0)
	_check(boat.speed() < 0.1, "obstacle_stops_ship", "s=%.3f" % boat.speed())
	world.remove_child(wall)
	wall.free()

	_check(_snapshot_position(boat).is_finite(), "position_finite_after_sailing", str(_snapshot_position(boat)))
	_free_boat(world, boat)


## ------------------------------------------------------------------ 2: holes + flooding + repair

func _phase_flooding_and_repair(world: Node3D) -> void:
	print("SHIP61_BOAT_PHASE flooding_repair")
	var basin := FakeBasin.new()
	var model := FakeModel.new()
	var pair: Array = _new_boat(world, basin, null, model)
	var boat = pair[0]
	var install: Dictionary = pair[1]
	_check(bool(install.get("ok", false)), "flood_install_ok")
	boat.set_sails(false)
	var hit_a: Dictionary = boat.apply_hit(boat.world_deck(Vector3(-3.9, 0.4, -2.0)), 55.0, Vector3.ZERO, "cannonball")
	var hit_b: Dictionary = boat.apply_hit(boat.world_deck(Vector3(3.9, 0.4, 1.0)), 55.0, Vector3.ZERO, "cannonball")
	_check(bool(hit_a.get("ok", false)) and str(hit_a.get("zone")) == "hull", "hull_zone_a", str(hit_a.get("zone")))
	_check(bool(hit_b.get("ok", false)) and str(hit_b.get("zone")) == "hull", "hull_zone_b", str(hit_b.get("zone")))
	_check(bool(hit_a.get("hole", false)) and bool(hit_b.get("hole", false)), "hull_hole_created")
	_check((hit_a.get("hole_world", Vector3.ZERO) as Vector3).distance_to(boat.world_deck(Vector3(-3.9, 0.4, -2.0))) < 0.01,
		"hit_hole_world")
	_check(model.holes.size() == 2, "model_punch_hole_calls", str(model.holes.size()))
	_check(int(boat.snapshot().get("holes", 0)) == 2, "snapshot_holes")
	_check(float(boat.hull_integrity()) < 1.0, "integrity_drops", str(boat.hull_integrity()))
	_check(basin.ripples >= 2, "basin_ripples", str(basin.ripples))

	_sim(boat, 5.0)
	var flood_before: float = boat.flooding()
	_check(flood_before > 0.02, "flooding_grows", "f=%.4f" % flood_before)
	_check(absf(float(boat.snapshot().get("flood_rate", 0.0)) - 0.01) < 0.003, "flood_rate_two_holes",
		str(boat.snapshot().get("flood_rate")))

	var hole_world: Vector3 = hit_b.get("hole_world", Vector3.ZERO)
	var near: Vector3 = boat.nearest_hole_world(hole_world, 3.0)
	# The hole itself travels with the ship (heave/pitch/roll), so compare it with the
	# holes the boat currently reports rather than with the hit-time point.
	var current_holes: Array = boat.snapshot().get("hole_worlds", [])
	var nearest_to_existing := 999.0
	for entry: Variant in current_holes:
		if entry is Vector3:
			nearest_to_existing = minf(nearest_to_existing, near.distance_to(entry as Vector3))
	_check(nearest_to_existing < 0.01, "nearest_hole_world", "near=%s holes=%s" % [str(near), str(current_holes)])
	_check(boat.nearest_hole_world(hole_world + Vector3(60.0, 0.0, 0.0), 3.0) == Vector3.ZERO, "nearest_hole_reach")
	_check(not boat.repair_at(hole_world + Vector3(60.0, 0.0, 0.0)), "repair_needs_hole")

	var repaired: bool = boat.repair_at(hole_world)
	_check(repaired, "repair_ok")
	_check(boat.hole_count() == 1, "repair_removed_hole", str(boat.hole_count()))
	_check(model.repaired.size() == 1, "model_repair_called")
	_sim(boat, 5.0)
	_check(boat.flooding() < flood_before, "repair_reduces_leak", "before=%.4f after=%.4f" % [flood_before, boat.flooding()])
	_check(boat.flooding() > 0.0, "flooding_keeps_rising_slower", str(boat.flooding()))
	_free_boat(world, boat)


## ------------------------------------------------------------------ 3: four holes sink the ship

func _phase_sinking(world: Node3D) -> void:
	print("SHIP61_BOAT_PHASE sinking")
	var basin := FakeBasin.new()
	var model := FakeModel.new()
	var pair: Array = _new_boat(world, basin, null, model)
	var boat = pair[0]
	boat.set_sails(false)
	var points := [
		Vector3(-3.9, 0.3, -8.0),
		Vector3(3.9, 0.3, -6.0),
		Vector3(-3.9, 0.3, 8.0),
		Vector3(3.9, 0.3, 0.0),
	]
	var zones: Array[String] = []
	for point: Vector3 in points:
		var hit: Dictionary = boat.apply_hit(boat.world_deck(point), 55.0, Vector3.ZERO, "cannonball")
		zones.append(str(hit.get("zone")))
	_check(zones == ["hull", "hull", "hull", "hull"], "four_hull_hits", str(zones))
	_check(boat.hole_count() == 4, "four_holes", str(boat.hole_count()))
	_sim(boat, 2.0)
	_check(boat.flooding() > 0.0, "flooding_after_hits", str(boat.flooding()))
	_check(not boat.is_sunk(), "not_sunk_immediately")
	_sim(boat, 58.0)
	var snap: Dictionary = boat.snapshot()
	_check(bool(snap.get("sunk", false)) and boat.is_sunk(), "sunk_after_60s", "t=60")
	_check(float(snap.get("flooding", 0.0)) >= 0.999, "flooding_full", str(snap.get("flooding")))
	var pos: Vector3 = snap.get("position", Vector3.ZERO)
	_check(pos.y < basin.water_level() - 2.0, "hull_settles_below_water", "y=%.3f" % pos.y)
	_check(bool(snap.get("collision_disabled", false)), "deck_stops_being_a_floor", str(snap.get("collision_disabled")))
	_check(absf(float(snap.get("heading_deg", 0.0))) <= 180.0, "heading_deg_range")
	_check(not boat.sails_open() or not boat.is_sunk(), "sails_shut_when_sunk")
	_free_boat(world, boat)


## ------------------------------------------------------------------ 4: mast + parts + debris

func _phase_mast_and_parts(world: Node3D) -> void:
	print("SHIP61_BOAT_PHASE mast_parts")
	var basin := FakeBasin.new()
	var model := FakeModel.new()
	var pair: Array = _new_boat(world, basin, null, model)
	var boat = pair[0]
	boat.set_sails(true)
	_sim(boat, 5.0)
	_check(boat.speed() > 2.0, "ship_under_way_before_mast_hit", str(boat.speed()))
	for _i in 4:
		boat.apply_hit(boat.world_deck(Vector3(0.3, 4.0, -1.0)), 60.0, Vector3.ZERO, "cannonball")
	var snap: Dictionary = boat.snapshot()
	_check(bool(model.mast_broken), "mast_model_broken")
	_check(float(snap.get("mast_hp", 1.0)) <= 0.0, "mast_hp_zero", str(snap.get("mast_hp")))
	_check(bool(snap.get("mast_broken", false)), "snapshot_mast_broken")
	_check((snap.get("broken_parts", []) as Array).has("mast"), "mast_in_broken_parts")
	_sim(boat, 10.0)
	_check(boat.speed() < 0.1, "mast_stops_ship", "s=%.3f" % boat.speed())

	for _i in 2:
		boat.apply_hit(boat.world_deck(Vector3(-2.0, 1.15, 10.2)), 60.0, Vector3.ZERO, "melee")
	_check(model.broken.has("crate_ammo"), "crate_ammo_breaks", str(model.broken))
	for _i in 3:
		boat.apply_hit(boat.world_deck(Vector3(4.2, 2.35, 0.0)), 55.0, Vector3.ZERO, "cannonball")
	_check(model.broken.has("rail"), "rail_breaks", str(model.broken))
	for _i in 3:
		boat.apply_hit(boat.world_deck(Vector3(-3.55, 1.9, -4.2)), 60.0, Vector3.ZERO, "cannonball")
	_check(model.broken.has("cannon_0"), "cannon_breaks", str(model.broken))
	_check(boat.debris_count() > 0, "debris_spawned", str(boat.debris_count()))
	_check(boat.debris_count() <= 40, "debris_pool_capped", str(boat.debris_count()))
	_check(model.shakes > 0, "model_shake_called")

	var snapshot: Dictionary = boat.snapshot()
	var required := ["speed", "heading_deg", "sails_open", "flooding", "integrity", "holes", "mast_hp", "sunk", "position", "rudder"]
	var missing: Array[String] = []
	for key: String in required:
		if not snapshot.has(key):
			missing.append(key)
	_check(missing.is_empty(), "snapshot_required_fields", str(missing))
	_check(snapshot.get("position", Vector3.ZERO) is Vector3, "snapshot_position_type")
	_check_snapshot_sane(snapshot)
	_free_boat(world, boat)


func _check_snapshot_sane(snap: Dictionary) -> void:
	_check(float(snap.get("speed", -1.0)) >= 0.0 and float(snap.get("speed", -1.0)) <= 6.51, "snapshot_speed_range")
	_check(float(snap.get("flooding", -1.0)) >= 0.0 and float(snap.get("flooding", 2.0)) <= 1.0, "snapshot_flooding_range")
	_check(float(snap.get("integrity", -1.0)) >= 0.0 and float(snap.get("integrity", 2.0)) <= 1.0, "snapshot_integrity_range")
	_check(float(snap.get("rudder", -2.0)) >= -1.0 and float(snap.get("rudder", 2.0)) <= 1.0, "snapshot_rudder_range")


## ------------------------------------------------------------------ 5: ladder + moving platform

func _phase_climb_and_platform(world: Node3D) -> void:
	print("SHIP61_BOAT_PHASE ladder_platform")
	var player := ProbePlayer.new()
	player.name = "Ship61ProbePlayer"
	player.collision_layer = 2
	player.collision_mask = 1
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.35
	capsule_shape.height = 1.8
	capsule.shape = capsule_shape
	capsule.position = Vector3(0.0, 0.9, 0.0)
	player.add_child(capsule)

	var basin := FakeBasin.new()
	var model := FakeModel.new()
	var boat = ShipBoat.new()
	boat.name = "ShipBoatLadder"
	world.add_child(boat)
	var install: Dictionary = boat.install(world, basin, player, model)
	world.add_child(player)
	boat.set_autopilot(false)
	_check(bool(install.get("ok", false)), "ladder_install_ok")

	# --- climb up from the main deck
	player.global_position = boat.world_deck(Vector3(0.0, 1.75, 2.3))
	player.velocity = Vector3.ZERO
	boat.set_climb_input(1.0)
	for _i in 240:
		boat.simulate_step(DELTA)
		boat.climb_assist(player, DELTA)
	var top_local: Vector3 = boat.local_of(player.global_position)
	_check(top_local.y > 5.0, "climb_assist_up", str(top_local))
	_check(absf(top_local.x) < 0.2, "climb_centres_on_ladder", str(top_local.x))

	# --- climb down from the fighting top
	player.global_position = boat.world_deck(Vector3(0.0, 5.2, 2.05))
	player.velocity = Vector3.ZERO
	boat.set_climb_input(-1.0)
	for _i in 240:
		boat.simulate_step(DELTA)
		boat.climb_assist(player, DELTA)
	var down_local: Vector3 = boat.local_of(player.global_position)
	_check(down_local.y < 1.9, "climb_assist_down", str(down_local))
	_check(down_local.z > 2.0, "climb_lands_on_main_deck", str(down_local.z))

	# --- outside the ladder nothing is touched
	boat.set_climb_input(1.0)
	var away: Vector3 = boat.world_deck(Vector3(6.0, 1.75, 0.0))
	player.global_position = away
	player.velocity = Vector3.ZERO
	for _i in 60:
		boat.climb_assist(player, DELTA)
	_check(player.global_position.distance_to(away) < 0.001, "climb_outside_zone_ignored",
		str(player.global_position.distance_to(away)))
	boat.climb_assist(null, DELTA)
	_check(true, "climb_null_tolerated")
	boat.set_climb_input(NAN)

	# --- moving platform: real CharacterBody3D on the deck
	player.global_position = boat.world_deck(Vector3(0.0, 2.6, 0.0))
	player.velocity = Vector3.ZERO
	boat.set_autopilot(true)
	for _i in 40:
		await physics_frame
	_check(player.is_on_floor(), "player_landed_on_deck", str(boat.local_of(player.global_position)))
	var local_before: Vector3 = boat.local_of(player.global_position)
	var boat_before: Vector3 = _snapshot_position(boat)
	var player_before: Vector3 = player.global_position
	boat.set_sails(true)
	for _i in 180:
		await physics_frame
	var boat_moved: float = _snapshot_position(boat).distance_to(boat_before)
	var player_moved: float = player.global_position.distance_to(player_before)
	var local_after: Vector3 = boat.local_of(player.global_position)
	var drift := Vector2(local_after.x - local_before.x, local_after.z - local_before.z).length()
	_check(boat_moved > 2.0, "platform_boat_moved", "d=%.3f" % boat_moved)
	_check(player_moved > 1.5, "platform_player_moved", "d=%.3f" % player_moved)
	_check(drift < 0.9, "platform_player_carried", "drift=%.3f local=%s" % [drift, str(local_after)])
	_check(player.is_on_floor(), "platform_player_still_grounded")
	_check(absf(local_after.y - local_before.y) < 0.6, "platform_player_height_kept",
		"before=%.3f after=%.3f" % [local_before.y, local_after.y])

	_free_boat(world, boat)
	if is_instance_valid(player):
		player.queue_free()
