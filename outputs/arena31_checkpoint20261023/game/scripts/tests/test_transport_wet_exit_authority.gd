extends SceneTree

const Candidate = preload("res://scripts/transport/candidates/transport_wet_exit_authority.gd")
const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const WaterPose = preload("res://scripts/transport/transport_water_doorway_pose.gd")
const Surface = preload("res://scripts/transport/transport_water_exit_surface.gd")

var failures: Array[String] = []
var checks := 0
var world: Node3D

class Providers extends RefCounted:
	var wet := true
	var allow_planar := true
	var allow_vehicle := true
	var water_level := .1
	var floor_y := -1.0
	var speed := 0.0
	var yaw := 0.0
	var travel_yaw := 0.0
	var travel_null := false
	var source_clock_offset := 0
	func water_at(_x: float, _z: float) -> Variant:
		return {"depth": 2.0, "level": water_level} if wet else null
	func ground(_x: float, _z: float, _current_y: float) -> Variant: return floor_y
	func planar(_x: float, _z: float) -> bool: return allow_planar
	func own_vehicle(_vehicle: CollisionObject3D, _point: Vector3, _radius: float) -> bool: return allow_vehicle
	func source_motion(vehicle: CollisionObject3D, source_clock: int) -> Dictionary:
		return {"vehicle_id": String(vehicle.get_meta("vehicle_id", "")), "life_generation": int(vehicle.get_meta("life_generation", 0)),
			"source_clock": source_clock + source_clock_offset, "speed": speed, "yaw": yaw,
			"travel_yaw": null if travel_null else travel_yaw}

class ActualAdapter extends RefCounted:
	var actor: CharacterBody3D
	var capsule: CollisionShape3D
	var vehicle: CollisionObject3D
	var surface: RefCounted
	var shape: CapsuleShape3D
	var local := Transform3D.IDENTITY
	var height := 0.0
	var mask := 0
	var actor_id := ""
	var generation := 0
	var crossing := false
	var disposed := false
	var malformed_bind := false
	var malformed_advance := false
	func bind(body: CharacterBody3D, own_vehicle: CollisionObject3D, is_crossing: bool) -> Dictionary:
		if malformed_bind: return {"ok": "truthy", "height": 1.9}
		if disposed or body == null or not body.is_inside_tree() or body.collision_mask == 0: return {"ok": false}
		var found := body.get_node_or_null("PlayerCapsule") as CollisionShape3D
		if found == null or found.disabled or not found.shape is CapsuleShape3D: return {"ok": false}
		if own_vehicle == null or not own_vehicle.is_inside_tree() or own_vehicle.get_world_3d() != body.get_world_3d(): return {"ok": false}
		actor = body; capsule = found; vehicle = own_vehicle; crossing = is_crossing
		shape = found.shape; local = found.transform; height = shape.height; mask = body.collision_mask
		actor_id = String(body.get_meta("actor_id", "")); generation = int(body.get_meta("life_generation", 0))
		return {"ok": true, "height": height, "radius": shape.radius}
	func valid() -> bool:
		return not disposed and is_instance_valid(actor) and actor.is_inside_tree() and is_instance_valid(capsule) and not capsule.disabled and capsule.shape == shape and is_equal_approx(shape.height, height) and capsule.transform.is_equal_approx(local) and actor.collision_mask == mask and String(actor.get_meta("actor_id", "")) == actor_id and int(actor.get_meta("life_generation", 0)) == generation and (not crossing or (is_instance_valid(vehicle) and vehicle.is_inside_tree()))
	func can_occupy(feet: Vector3, requested_height: float) -> bool:
		if not valid() or not feet.is_finite() or not is_equal_approx(requested_height, height): return false
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.margin = 0.0; query.collision_mask = mask
		query.collide_with_bodies = true; query.collide_with_areas = false
		var transform := actor.global_transform; transform.origin = feet; query.transform = transform * local
		var excluded: Array[RID] = [actor.get_rid()]
		if crossing: excluded.append(vehicle.get_rid())
		query.exclude = excluded
		return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	func begin(ground_height: Callable, water_at: Callable) -> Dictionary:
		if not valid() or not Surface.can_ascend_from_vehicle(actor.global_position, water_at, can_occupy, height): return {"ok": false}
		var next := Surface.new(); var configured: Dictionary = next.configure(actor.global_position, ground_height, water_at, can_occupy, Surface.DEFAULT_RISE_SPEED, height)
		if not configured.ok: return configured
		surface = next; return {"ok": true, "state": surface.state()}
	func advance(x: float, z: float, dt: float, body_done: bool) -> Dictionary:
		if malformed_advance: return {"ok": true, "state": [], "finish_ready": "truthy", "next_owner_required": "admin"}
		if not valid() or surface == null: return {"ok": false}
		var before_state: Dictionary = surface.state()
		if actor.global_position.distance_to(Vector3(before_state.x, before_state.y, before_state.z)) > .002: return {"ok": false}
		var updated: Dictionary = surface.update(x, z, dt)
		if not updated.ok: return updated
		var row: Dictionary = updated.state; var goal := Vector3(row.x, row.y, row.z)
		var horizontal := (goal - actor.global_position).slide(Vector3.UP)
		if horizontal.length_squared() > 1e-12: actor.move_and_collide(horizontal)
		var vertical := Vector3.UP * (goal.y - actor.global_position.y)
		if vertical.length_squared() > 1e-12: actor.move_and_collide(vertical)
		if actor.global_position.distance_to(goal) > .002: return {"ok": false}
		return {"ok": true, "state": row, "finish_ready": body_done and bool(row.grounded) and not bool(row.blocked), "next_owner_required": "swim" if row.water != null else "on_foot"}
	func dispose() -> void:
		if surface != null: surface.dispose()
		surface = null; disposed = true; actor = null; capsule = null; vehicle = null

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func make_actor(id: String = "actor-1") -> CharacterBody3D:
	var actor := CharacterBody3D.new(); actor.name = id; actor.collision_layer = 2; actor.collision_mask = 1
	actor.set_meta("actor_id", id); actor.set_meta("life_generation", 1)
	var collision := CollisionShape3D.new(); collision.name = "PlayerCapsule"; collision.position.y = .95
	var shape := CapsuleShape3D.new(); shape.radius = .36; shape.height = 1.9; collision.shape = shape
	actor.add_child(collision); world.add_child(actor); return actor

func make_vehicle(id: String = "vehicle-1", profile_id: String = "compact_sedan") -> RigidBody3D:
	var vehicle := RigidBody3D.new(); vehicle.name = id; vehicle.freeze = true; vehicle.collision_layer = 1; vehicle.collision_mask = 1
	vehicle.set_meta("vehicle_id", id); vehicle.set_meta("life_generation", 1); vehicle.set_meta("profile_id", profile_id)
	world.add_child(vehicle); return vehicle

func add_blocker(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position = position; body.collision_layer = 1; body.collision_mask = 0
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape
	body.add_child(collision); world.add_child(body); return body

func refs(actor_id := "actor-1", vehicle_id := "vehicle-1") -> Dictionary:
	return {"actor": {"actor_id": actor_id, "life_generation": 1}, "vehicle": {"vehicle_id": vehicle_id, "life_generation": 1}}

func place_at_seat(actor: CharacterBody3D, vehicle: CollisionObject3D, catalog: RefCounted, profile_id := "compact_sedan", seat_id := "front_left") -> void:
	var seat: Dictionary = catalog.call("seat", profile_id, seat_id)
	actor.global_position = WaterPose.water_seat_point(vehicle.global_transform, seat).world_position_m

func run() -> void:
	check(FileAccess.get_sha256("res://scripts/transport/transport_water_doorway_pose.gd") == "fb61223de23c81c4317e2cf934815d9d45182aa2fc0b41d1f8ff5a2d133b03c3", "final WaterPose dependency is pinned")
	check(FileAccess.get_sha256("res://scripts/transport/transport_water_exit_surface.gd") == "cc72286766429bfa9942961bd85f1f26457342a2981d087bbe1af93265c0f200", "frozen Surface dependency is pinned")
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/car_exit.mjs") == Candidate.CAR_EXIT_SOURCE_SHA256, "source body launch and pedestrian step are pinned")
	var catalog := Catalog.new(); check(catalog.load_file(), "actual descriptor catalog loads")
	world = Node3D.new(); root.add_child(world)
	var actor := make_actor(); var vehicle := make_vehicle(); actor.add_collision_exception_with(vehicle)
	place_at_seat(actor, vehicle, catalog); await physics_frame; await physics_frame
	var providers := Providers.new(); var candidate := Candidate.new()
	check(candidate.configure(catalog, 1, providers.water_at, providers.ground, providers.planar, providers.own_vehicle, providers.source_motion).code == "OK", "candidate configures only with explicit callbacks")
	var identity := refs(); var adapter := ActualAdapter.new()
	vehicle.rotation.y = .3; place_at_seat(actor, vehicle, catalog)
	var begun: Dictionary = candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 100000, actor, vehicle, adapter, true, 1)
	check(begun.code == "HOLDING" and begun.distance_m == 1.9, "wet physical doorway starts exact source hold at first distance")
	check(candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 100001, actor, vehicle, ActualAdapter.new(), true, 1).code == "ACTOR_BUSY", "same actor cannot own two wet leases")
	check(candidate.advance_hold(begun.token, 1, true, true, 200000).code == "HOLDING", "hold remains pending before 300ms")
	check(candidate.advance_hold(begun.token, 1, true, true, 300000).code == "HOLDING", "hold boundary below duration remains pending")
	check(candidate.advance_hold(begun.token, 1, true, true, 400000).code == "TRANSITION_REQUIRED", "continuous exact 300ms hold admits physical transition")
	check(candidate.begin_transition(begun.token, 1, 401000).code == "ACTIVE", "pre-existing seated collision exception and exact seat pose admit release")
	providers.speed = -4.0; providers.yaw = .3; providers.travel_yaw = 1.1
	var release_done: Dictionary = candidate.advance(begun.token, 1, .55, 501000)
	var source_vx := sin(1.1) * (-4.0 * .45) + cos(.3) * .8
	var source_vz := cos(1.1) * (-4.0 * .45) - sin(.3) * .8
	check(release_done.code == "ACTIVE" and release_done.phase == "BODY" and (candidate.state(begun.token, 1).body_velocity_mps as Vector3).distance_to(Vector3(-source_vx, 0, -source_vz)) < .000001,
		"signed reverse speed and distinct travel yaw use exact source launch formula with one native axis mapping")
	providers.speed = 0.0; providers.yaw = 0.0; providers.travel_yaw = 0.0
	var clock := 501000; var latest: Dictionary = {}
	for index in range(20):
		clock += 100000; latest = candidate.advance(begun.token, 1, .1, clock)
		if latest.code == "WET_AUTHORITY_PENDING": break
	check(latest.code == "WET_AUTHORITY_PENDING" and latest.authority_pending and not latest.host_seat_mutated and latest.lease_consumed, "physical release emits one-shot WET_AUTHORITY_PENDING without Host mutation")
	check(latest.next_owner_required == "swim" and latest.surface_target_reached, "real water surface decides the pending next owner")
	check(candidate.advance(begun.token, 1, 0.0, clock).code == "TOKEN", "one-shot terminal receipt cannot be replayed or polled")
	check(not adapter.valid(), "one-shot terminal receipt disposes physical adapter and retains Host ownership")
	vehicle.rotation.y = 0.0

	# Release and continuity cancel without creating a seat mutation.
	place_at_seat(actor, vehicle, catalog); var release_adapter := ActualAdapter.new()
	var released := candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1200000, actor, vehicle, release_adapter, true, 1)
	check(candidate.advance_hold(released.token, 1, false, true, 1300000).code == "RELEASED" and not release_adapter.valid(), "released key cancels and disposes lease")
	place_at_seat(actor, vehicle, catalog); var gap := candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1400000, actor, vehicle, ActualAdapter.new(), true, 1)
	check(candidate.advance_hold(gap.token, 1, true, true, 1520001).code == "CONTINUITY_LOST", "hold gap above 120ms fails closed")

	# Unknown identities and two-seat rosters fail before any physical mutation.
	check(candidate.begin_hold(identity.actor, identity.vehicle, "missing", "front_left", 1600000, actor, vehicle, ActualAdapter.new(), true, 1).code == "PROFILE_IDENTITY", "unknown profile cannot bind to foreign vehicle metadata")
	vehicle.set_meta("profile_id", "sport_coupe")
	check(candidate.begin_hold(identity.actor, identity.vehicle, "sport_coupe", "rear_left", 1600001, actor, vehicle, ActualAdapter.new(), true, 1).code == "SEAT_IDENTITY", "two-seat profile rejects absent rear seat")
	vehicle.set_meta("profile_id", "compact_sedan")

	# Dry, blocked, door and own-vehicle callbacks are mandatory, with actual Jolt capsule blocking.
	providers.wet = false; place_at_seat(actor, vehicle, catalog)
	check(candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1600002, actor, vehicle, ActualAdapter.new(), true, 1).code == "NOT_WET", "dry endpoint never receives a wet lease")
	providers.wet = true
	check(candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1600003, actor, vehicle, ActualAdapter.new(), false, 1).code == "ADMISSION", "closed door fails before adapter binding")
	var malformed_bind_adapter := ActualAdapter.new(); malformed_bind_adapter.malformed_bind = true
	check(candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1600004, actor, vehicle, malformed_bind_adapter, true, 1).code == "CAPSULE_BINDING" and malformed_bind_adapter.disposed, "truthy non-boolean bind receipt fails closed and disposes partial adapter")
	providers.allow_vehicle = false
	check(candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1600005, actor, vehicle, ActualAdapter.new(), true, 1).code == "WET_BLOCKED", "real own-vehicle clearance callback cannot default clear")
	providers.allow_vehicle = true
	var blocker := add_blocker(Vector3(-1.1, .95, -.66), Vector3(.3, 2.0, 1.0)); await physics_frame; await physics_frame
	check(candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1600006, actor, vehicle, ActualAdapter.new(), true, 1).code == "WET_BLOCKED", "actual Godot capsule overlap blocks wet doorway")
	blocker.queue_free(); await physics_frame; await physics_frame
	place_at_seat(actor, vehicle, catalog); var late_release_adapter := ActualAdapter.new()
	var release_blocked := candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1700000, actor, vehicle, late_release_adapter, true, 1)
	candidate.advance_hold(release_blocked.token, 1, true, true, 1800000)
	candidate.advance_hold(release_blocked.token, 1, true, true, 1900000)
	candidate.advance_hold(release_blocked.token, 1, true, true, 2000000)
	check(candidate.begin_transition(release_blocked.token, 1, 2000001).code == "ACTIVE", "admitted route can begin before a later obstacle appears")
	var late_blocker := add_blocker(Vector3(-1.1, .95, -.66), Vector3(.3, 2.0, 1.0)); await physics_frame; await physics_frame
	var blocked_release: Dictionary = {}; var blocked_clock := 2000001
	for index in range(6):
		blocked_clock += 100000; blocked_release = candidate.advance(release_blocked.token, 1, .1, blocked_clock)
		if blocked_release.code == "BLOCKED": break
	check(blocked_release.code == "BLOCKED" and blocked_release.retain_vehicle_owner and not late_release_adapter.valid(), "release obstacle cancels lease instead of advancing a partially moved timeline")
	check(candidate.advance(release_blocked.token, 1, .1, blocked_clock + 1).code == "TOKEN", "cancelled blocked release cannot re-enter with stale token")
	late_blocker.queue_free(); await physics_frame; await physics_frame
	place_at_seat(actor, vehicle, catalog); var stale_motion_adapter := ActualAdapter.new()
	var stale_motion := candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 2700000, actor, vehicle, stale_motion_adapter, true, 1)
	candidate.advance_hold(stale_motion.token, 1, true, true, 2800000)
	candidate.advance_hold(stale_motion.token, 1, true, true, 2900000)
	candidate.advance_hold(stale_motion.token, 1, true, true, 3000000)
	candidate.begin_transition(stale_motion.token, 1, 3000001)
	providers.source_clock_offset = 1
	check(candidate.advance(stale_motion.token, 1, .55, 3100001).code == "SOURCE_MOTION_IDENTITY" and not stale_motion_adapter.valid(), "stale source-motion receipt fails closed and cancels lease")
	providers.source_clock_offset = 0
	check(candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 3000000, actor, vehicle, ActualAdapter.new(), true, 1).code == "STALE_CLOCK", "cancelled actor cannot re-enter with a replayed source clock")
	place_at_seat(actor, vehicle, catalog); var malformed_advance_adapter := ActualAdapter.new(); malformed_advance_adapter.malformed_advance = true
	var malformed_advance := candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 3200000, actor, vehicle, malformed_advance_adapter, true, 1)
	candidate.advance_hold(malformed_advance.token, 1, true, true, 3300000)
	candidate.advance_hold(malformed_advance.token, 1, true, true, 3400000)
	candidate.advance_hold(malformed_advance.token, 1, true, true, 3500000)
	candidate.begin_transition(malformed_advance.token, 1, 3500001)
	providers.travel_null = true
	var malformed_result := candidate.advance(malformed_advance.token, 1, .65, 3600001)
	providers.travel_null = false
	check(malformed_result.code == "CAPSULE_RESULT" and not malformed_advance_adapter.valid(), "null travel yaw uses source yaw fallback before malformed adapter row fails closed")

	# Epoch, lifetime and foreign-vehicle changes invalidate existing leases.
	place_at_seat(actor, vehicle, catalog); var old_adapter := ActualAdapter.new()
	var old := candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 3700000, actor, vehicle, old_adapter, true, 1)
	check(candidate.reset(2).code == "OK" and not old_adapter.valid(), "strict newer epoch cancels and disposes every active lease")
	check(candidate.advance_hold(old.token, 1, true, true, 1500000).code == "STALE_EPOCH", "old epoch receipt cannot revive")
	check(candidate.reset(2).code == "STALE_EPOCH", "equal epoch reset is rejected")
	place_at_seat(actor, vehicle, catalog); var foreign := candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1600000, actor, vehicle, ActualAdapter.new(), true, 2)
	vehicle.set_meta("profile_id", "city_taxi")
	check(candidate.advance_hold(foreign.token, 2, true, true, 1700000).code == "FOREIGN_VEHICLE", "profile replacement cancels foreign vehicle lease")
	vehicle.set_meta("profile_id", "compact_sedan")
	place_at_seat(actor, vehicle, catalog); var lifetime := candidate.begin_hold(identity.actor, identity.vehicle, "compact_sedan", "front_left", 1800000, actor, vehicle, ActualAdapter.new(), true, 2)
	vehicle.set_meta("life_generation", 2)
	check(candidate.advance_hold(lifetime.token, 2, true, true, 1900000).code == "LIFETIME_ENDED", "vehicle incarnation change invalidates lease")
	vehicle.set_meta("life_generation", 1)
	check(candidate.advance_hold(RefCounted.new(), 2, true, true, 2000000).code == "TOKEN", "foreign opaque token is rejected")

	check(FileAccess.get_sha256("res://scripts/transport/transport_runtime.gd") == "d493809fc33415ca9f0ad2204ad4fb2f458391cdcc80771311d1979f5dc9c04c", "dry runtime remains byte-identical")
	check(FileAccess.get_sha256("res://scripts/transport/transport_logical_host.gd") == "5371b8561507d23334b83765d25d2d655033d3bb6f493568ff00868b779ea5ad", "dry logical Host remains byte-identical")
	check(FileAccess.get_sha256("res://scripts/transport/transport_access_provider.gd") == "325be57c92fca3b83aa884d47577c7e7014553850ee1806166fa67419f5cf830", "dry access provider remains byte-identical")
	check(FileAccess.get_sha256("res://scripts/transport/transport_actor_transition.gd") == "c9ed1ad7205c74d1131cfda0588f8c862fb1ae6cf64d7b42c83b25f1b0df4c6f", "dry actor transition remains byte-identical")
	candidate.dispose(); check(candidate.state(RefCounted.new(), 2).code == "DISPOSED", "dispose seals candidate")
	world.queue_free(); await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "engine": Engine.get_version_info().string,
		"scope": "proof-only wet lease + actual Godot capsule and movement; terminal WET_AUTHORITY_PENDING; no Host seat mutation"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
