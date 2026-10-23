extends SceneTree

const Surface = preload("res://scripts/transport/transport_water_exit_surface.gd")
var failures: Array[String] = []
var checks := 0
var scene: Node3D

class Providers extends RefCounted:
	var space: PhysicsDirectSpaceState3D
	var water_level := 2.0
	var floor_y := -3.0
	var calls := 0
	var malformed_floor := false
	func water_at(_x: float, _z: float) -> Variant: return {"depth": 5.0, "level": water_level}
	func dry_at(_x: float, _z: float) -> Variant: return null
	func ground(_x: float, _z: float, _current_y: float) -> Variant: return NAN if malformed_floor else floor_y
	func clear(_position: Vector3, _height: float) -> bool: calls += 1; return true
	func occupy(position: Vector3, height: float) -> bool:
		calls += 1
		var shape := CapsuleShape3D.new(); shape.radius = .36; shape.height = height
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * height * .5)
		return space.intersect_shape(query, 1).is_empty()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func body_at(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position = position; body.collision_layer = 1; body.collision_mask = 0
	var collision := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; collision.shape = box
	body.add_child(collision); scene.add_child(body); return body

func run() -> void:
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/vehicle_water_exit.mjs") == Surface.SOURCE_SHA256, "water exit source SHA is pinned")
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/walk_preview.mjs") == Surface.WALK_SOURCE_SHA256, "walk lifecycle source SHA is pinned")
	scene = Node3D.new(); root.add_child(scene)
	body_at(Vector3(0, -3.1, 0), Vector3(20, .2, 20))
	await physics_frame; await physics_frame
	var providers := Providers.new(); providers.space = scene.get_world_3d().direct_space_state
	var surface := Surface.new()
	check(not surface.update(0, 0, .1).ok, "update before configure fails closed")
	var configured := surface.configure(Vector3(0, -2.0, 0), providers.ground, providers.water_at, providers.occupy)
	check(configured.ok and is_equal_approx(float(configured.state.y), -2.0), "configure preserves exact submerged start")
	var before := surface.state()
	var bad := surface.update(0, 0, -1.0)
	check(not bad.ok and surface.state() == before, "invalid update is transactional")
	var first := surface.update(0, 0, 1.0)
	check(first.ok and is_equal_approx(float(first.state.y), -1.91), "dt is capped at .1 and rise at .09m")
	check(first.vertical_steps == 2 and first.horizontal_steps == 1, "source horizontal and vertical step counts are exact")
	check(float(first.state.y) >= float(before.y) and float(first.state.velocity_y) > 0.0, "valid submerged update never moves down")
	var zero_before := surface.state(); var zero := surface.update(0, 0, 0.0)
	check(zero.ok and is_equal_approx(float(zero.state.y), float(zero_before.y)) and is_zero_approx(float(zero.state.velocity_y)), "dt zero does not teleport")
	providers.malformed_floor = true; var invalid_floor := surface.update(.2, 0, .1); providers.malformed_floor = false
	check(not invalid_floor.ok and surface.state() == zero.state, "malformed floor rolls back horizontal staging")
	var ascent_counter := Providers.new(); ascent_counter.water_level = 0.0
	var ascends := Surface.can_ascend_from_vehicle(Vector3(0, -5, 0), ascent_counter.water_at, ascent_counter.clear)
	check(ascends and ascent_counter.calls == 43, "ascent admission uses inclusive .12m occupancy probes")
	var infinite_depth := func(_x: float, _z: float) -> Dictionary: return {"depth": INF, "level": 0.0}
	check(Surface.can_ascend_from_vehicle(Vector3(0, -.05, 0), infinite_depth, ascent_counter.clear), "source-compatible positive infinite depth is accepted with finite level")
	var nan_depth := func(_x: float, _z: float) -> Dictionary: return {"depth": NAN, "level": 0.0}
	check(not Surface.can_ascend_from_vehicle(Vector3(0, -.05, 0), nan_depth, ascent_counter.clear), "source-compatible NaN depth is rejected by exact depth > 0 predicate")
	var ceiling := body_at(Vector3(0, -.75, 0), Vector3(2, .1, 2)); await physics_frame; await physics_frame
	check(not Surface.can_ascend_from_vehicle(Vector3(0, -2, 0), providers.water_at, providers.occupy), "actual Godot capsule occupancy rejects blocked ascent")
	var blocked := surface.update(0, 0, .1)
	check(blocked.ok and blocked.state.blocked and float(blocked.state.y) >= float(zero.state.y), "blocked rise neither penetrates nor moves down")
	ceiling.queue_free(); await physics_frame; await physics_frame
	var wall := body_at(Vector3(.65, -1.35, 0), Vector3(.1, 1.1, 2)); await physics_frame; await physics_frame
	var prior_x := float(surface.state().x); var swept := surface.update(1.2, 0, .1)
	check(swept.ok and swept.state.blocked and float(swept.state.x) < 1.2 and float(swept.state.x) >= prior_x, "actual capsule sweep stops at first blocked .12m horizontal sample")
	wall.queue_free(); await physics_frame
	var dry := Surface.new(); dry.configure(Vector3(0, -2.0, 0), providers.ground, providers.dry_at, providers.clear)
	var dry_step := dry.update(0, 0, .1)
	check(dry_step.ok and float(dry_step.state.y) < -2.0 and is_equal_approx(float(dry_step.state.y), -2.09), "dry continuation targets finite floor with source descent")
	var grounded := Surface.new(); grounded.configure(Vector3(0, 1.95, 0), providers.ground, providers.water_at, providers.clear)
	var settled := grounded.update(0, 0, .1)
	check(settled.state.grounded and not settled.state.blocked, "finish-ready state is grounded and unblocked")
	grounded.dispose(); check(grounded.state().is_empty() and not grounded.update(0, 0, .1).ok, "dispose invalidates lifecycle")
	# Bounded cost: real PhysicsDirectSpaceState3D capsule query on every occupancy step.
	var cost_surface := Surface.new(); cost_surface.configure(Vector3(4, -2, 0), providers.ground, providers.water_at, providers.occupy)
	for warm in range(500):
		var warm_state: Dictionary = cost_surface.update(4, 0, .016)
		if warm_state.ok and warm_state.state.grounded and not warm_state.state.blocked: break
	check(cost_surface.state().grounded and not cost_surface.state().blocked, "settled benchmark reaches surface before sampling")
	var settled_samples := PackedFloat64Array()
	for block in range(20):
		var started := Time.get_ticks_usec()
		for iteration in range(100): cost_surface.update(4, 0, .016)
		settled_samples.append(float(Time.get_ticks_usec() - started) / 100.0)
	settled_samples.sort()
	var active_samples := PackedFloat64Array()
	for block in range(20):
		cost_surface.configure(Vector3(4, -2, 0), providers.ground, providers.water_at, providers.occupy)
		var started := Time.get_ticks_usec()
		for iteration in range(100): cost_surface.update(4, 0, .016)
		active_samples.append(float(Time.get_ticks_usec() - started) / 100.0)
	active_samples.sort()
	var cost := {"calls_per_scenario": 2000, "settled_block_mean_us_p50": (settled_samples[9] + settled_samples[10]) * .5, "settled_block_mean_us_p95": settled_samples[18], "active_ascent_block_mean_us_p50": (active_samples[9] + active_samples[10]) * .5, "active_ascent_block_mean_us_p95": active_samples[18]}
	check(active_samples[18] < 1000.0, "bounded active-ascent test-predicate update remains below 1ms p95 block mean")
	scene.queue_free(); await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "cost": cost, "scope": "source math plus actual Godot capsule occupancy; no Root/swim adoption"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
