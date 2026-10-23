extends SceneTree
## Diagnostic-only bridge study for real PhysicsDirectBodyState3D contacts.
## The production NativeVehicleBody is subclassed without modifying its bytes.

const Identity = preload("res://scripts/vehicle_physics/vehicle_contact_identity.gd")
const Manifold = preload("res://scripts/vehicle_physics/vehicle_contact_manifold.gd")
const PRODUCTION_BODY := "res://scripts/vehicle_physics/vehicle_native_body.gd"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const IDENTITY_SHA256 := "eb6ad8ba8b5bf1a14fb1a1a75cbbee8b25f09145909dd448f2ba97a2e6bec256"
const MANIFOLD_SHA256 := "dfe706e678fd64a6ac2d67f27bd659733287ff9aba6e62c6b9343889ba3ed9dd"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const PROFILE_ID := "compact_sedan"
const FIXED_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 4
const MEASURE_TICKS := 120
const MAX_RAW_POINTS := 8
const START_SPEED_MPS := 12.0
const WALL_SOURCE_ID := "building-original-42"
const WALL_SOURCE_INDEX := 14

class ContactProbeBody:
	extends NativeVehicleBody
	var callback_tick := 0
	var wall_runtime_id := 0
	var wall_contact_ticks := 0
	var max_wall_points_per_tick := 0
	var overflow_tick_count := 0
	var raw_wall_point_total := 0
	var summed_impulse_ns := Vector3.ZERO
	var first_contact_tick := -1
	var first_point_self_world := Vector3.ZERO
	var first_point_other_world := Vector3.ZERO
	var first_normal_raw := Vector3.ZERO
	var first_impulse_ns := Vector3.ZERO
	var first_relative_velocity_mps := Vector3.ZERO
	var first_body_linear_velocity_mps := Vector3.ZERO
	var first_body_angular_velocity_radps := Vector3.ZERO
	var first_closing_speed_mps := 0.0
	var first_world_point_error_m := INF
	var first_local_hypothesis_error_m := INF
	var first_normal_world_score := -INF
	var first_normal_local_hypothesis_score := -INF
	var first_nonzero_impulse_tick := -1
	var first_nonzero_impulse_ns := Vector3.ZERO
	var first_nonzero_normal := Vector3.ZERO
	var first_nonzero_relative_velocity_mps := Vector3.ZERO
	var first_nonzero_closing_speed_mps := 0.0
	var peak_impulse_ns := Vector3.ZERO
	var peak_impulse_tick := -1
	var minimum_impulse_normal_dot := INF
	var negative_impulse_normal_count := 0
	var most_negative_impulse_ns := Vector3.ZERO
	var most_negative_normal := Vector3.ZERO
	var maximum_point_pair_separation_m := 0.0
	var collider_object_mismatch_count := 0
	var collider_runtime_mismatch_count := 0
	var nonfinite_count := 0
	var expected_normal_world := Vector3.ZERO
	var strict_manifold = Manifold.new(8)
	var strict_manifold_accepted_points := 0
	var strict_manifold_rejected_points := 0
	var strict_manifold_max_tick_clipped_normal_ns := 0.0

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		callback_tick += 1
		strict_manifold.begin_tick(callback_tick)
		var wall_points := 0
		var count := state.get_contact_count()
		if count > MAX_RAW_POINTS:
			overflow_tick_count += 1
		for index in mini(count, MAX_RAW_POINTS):
			var collider := state.get_contact_collider_object(index)
			if not is_instance_valid(collider) or collider.get_instance_id() != wall_runtime_id:
				continue
			wall_points += 1
			raw_wall_point_total += 1
			if collider.get_instance_id() != state.get_contact_collider_id(index):
				collider_runtime_mismatch_count += 1
			if not collider is StaticBody3D:
				collider_object_mismatch_count += 1
			var point_self := state.get_contact_local_position(index)
			var point_other := state.get_contact_collider_position(index)
			var normal := state.get_contact_local_normal(index)
			var impulse := state.get_contact_impulse(index)
			var velocity_self := state.get_contact_local_velocity_at_position(index)
			var velocity_other := state.get_contact_collider_velocity_at_position(index)
			var relative := velocity_self - velocity_other
			if not point_self.is_finite() or not point_other.is_finite() or not normal.is_finite() \
					or not impulse.is_finite() or not relative.is_finite():
				nonfinite_count += 1
				continue
			var pair_separation := point_self.distance_to(point_other)
			maximum_point_pair_separation_m = maxf(maximum_point_pair_separation_m, pair_separation)
			summed_impulse_ns += impulse
			if normal.length_squared() > 0.000001:
				var impulse_normal_dot := impulse.dot(normal.normalized())
				if impulse_normal_dot < minimum_impulse_normal_dot:
					minimum_impulse_normal_dot = impulse_normal_dot
					most_negative_impulse_ns = impulse
					most_negative_normal = normal
				if impulse_normal_dot < 0.0:
					negative_impulse_normal_count += 1
			var closing := maxf(0.0, -relative.dot(normal.normalized())) if normal.length_squared() > 0.000001 else 0.0
			var com_world := state.transform * state.center_of_mass_local
			if strict_manifold.observe(wall_runtime_id, point_self, point_other, normal, impulse,
					velocity_self, velocity_other, com_world):
				strict_manifold_accepted_points += 1
			else:
				strict_manifold_rejected_points += 1
			if first_contact_tick < 0:
				first_contact_tick = callback_tick
				first_point_self_world = point_self
				first_point_other_world = point_other
				first_normal_raw = normal
				first_impulse_ns = impulse
				first_relative_velocity_mps = relative
				first_body_linear_velocity_mps = state.linear_velocity
				first_body_angular_velocity_radps = state.angular_velocity
				first_closing_speed_mps = closing
				first_world_point_error_m = pair_separation
				first_local_hypothesis_error_m = (state.transform * point_self).distance_to(point_other)
				first_normal_world_score = normal.normalized().dot(expected_normal_world)
				first_normal_local_hypothesis_score = (state.transform.basis * normal).normalized().dot(expected_normal_world)
			if first_nonzero_impulse_tick < 0 and impulse.length() > 0.000001:
				first_nonzero_impulse_tick = callback_tick
				first_nonzero_impulse_ns = impulse
				first_nonzero_normal = normal
				first_nonzero_relative_velocity_mps = relative
				first_nonzero_closing_speed_mps = closing
			if impulse.length_squared() > peak_impulse_ns.length_squared():
				peak_impulse_ns = impulse
				peak_impulse_tick = callback_tick
		if wall_points > 0:
			wall_contact_ticks += 1
			max_wall_points_per_tick = maxi(max_wall_points_per_tick, wall_points)
			strict_manifold_max_tick_clipped_normal_ns = maxf(
				strict_manifold_max_tick_clipped_normal_ns, strict_manifold.clipped_normal_ns)

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	Engine.physics_ticks_per_second = FIXED_TICKS_PER_SECOND
	call_deferred("run")

func descriptor_for(rows: Array) -> Dictionary:
	for candidate: Dictionary in rows:
		if str(candidate.get("profile_id", "")) != PROFILE_ID:
			continue
		var descriptor := candidate.duplicate(true)
		descriptor.vehicle_id = "static-contact-probe"
		descriptor.source_id = PROFILE_ID
		descriptor.life_generation = 1
		descriptor.source_clock = 1
		return descriptor
	return {}

func add_building_wall(world: Node3D, wall_transform: Transform3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "RuntimeNameMustNotBecomeWireIdentity"
	wall.transform = wall_transform
	wall.set_meta("source_id", WALL_SOURCE_ID)
	wall.set_meta("source_index", WALL_SOURCE_INDEX)
	wall.set_meta("vehicle_surface_id", "building_wall")
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 20.0, 0.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall

func run() -> void:
	check(FileAccess.get_sha256(PRODUCTION_BODY) == PRODUCTION_BODY_SHA256, "exact frozen production body receipt")
	check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_identity.gd") == IDENTITY_SHA256,
		"exact strict identity adapter receipt")
	check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_manifold.gd") == MANIFOLD_SHA256,
		"exact directed manifold receipt")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	check(parsed is Dictionary, "transport descriptors parse")
	if not parsed is Dictionary:
		print_result({}, {})
		return
	var descriptor := descriptor_for((parsed as Dictionary).get("profiles", []))
	check(not descriptor.is_empty(), "compact sedan descriptor available")

	var yaw := 0.61
	var basis := Basis(Vector3.UP, yaw)
	var wall_origin := Vector3(25.0, 5.0, -18.0)
	var expected_normal_world := (basis * Vector3.BACK).normalized()
	var approach_forward_world := -expected_normal_world
	var world := Node3D.new()
	root.add_child(world)
	var wall := add_building_wall(world, Transform3D(basis, wall_origin))
	var identity: Dictionary = Identity.describe(wall)
	check(identity.valid and identity.kind == "static", "building-tagged StaticBody admitted by strict identity adapter")
	check(identity.source_id == WALL_SOURCE_ID and identity.source_index == WALL_SOURCE_INDEX,
		"wire source identity remains authored source id plus source index")
	check(identity.counterpart_runtime_id == wall.get_instance_id(), "runtime lookup id is exact")
	var wire_identity := {"kind": identity.kind, "source_id": identity.source_id, "source_index": identity.source_index}
	check(not wire_identity.has("counterpart_runtime_id") and not wire_identity.has("runtime_id"),
		"wire identity excludes runtime object id")

	var body := ContactProbeBody.new()
	check(body.configure(descriptor), "actual NativeVehicleBody subclass configures")
	body.transform = Transform3D(basis, wall_origin - approach_forward_world * 8.0)
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.wall_runtime_id = wall.get_instance_id()
	body.expected_normal_world = expected_normal_world
	world.add_child(body)
	for _tick in SETTLE_TICKS:
		await physics_frame
	body.linear_velocity = approach_forward_world * START_SPEED_MPS
	body.angular_velocity = Vector3.ZERO
	var initial_velocity := body.linear_velocity
	for _tick in MEASURE_TICKS:
		await physics_frame
	var final_velocity := body.linear_velocity
	var mass_kg: float = body.mass
	var momentum_delta_ns := (final_velocity - initial_velocity) * mass_kg
	var reported_window_momentum_delta_ns := (final_velocity - body.first_body_linear_velocity_mps) * mass_kg
	var impulse_error_same_sign_ns := (body.summed_impulse_ns - momentum_delta_ns).length()
	var impulse_error_opposite_sign_ns := (-body.summed_impulse_ns - momentum_delta_ns).length()
	var reference_impulse_ns := maxf(1.0, momentum_delta_ns.length())
	var same_sign_relative_error := impulse_error_same_sign_ns / reference_impulse_ns
	var opposite_sign_relative_error := impulse_error_opposite_sign_ns / reference_impulse_ns
	var reported_window_error_ns := (body.summed_impulse_ns - reported_window_momentum_delta_ns).length()
	var reported_window_relative_error := reported_window_error_ns / maxf(1.0, reported_window_momentum_delta_ns.length())
	var native_receipts: Array[Dictionary] = body.drain_contact_receipts()

	check(body.first_contact_tick >= 0 and body.raw_wall_point_total > 0, "real wall contact observed in direct body state")
	check(body.max_wall_points_per_tick > 0 and body.max_wall_points_per_tick <= MAX_RAW_POINTS,
		"raw wall manifold remains bounded to eight reported points")
	check(body.overflow_tick_count == 0, "engine report never exceeds configured eight-point bound")
	check(body.collider_object_mismatch_count == 0 and body.collider_runtime_mismatch_count == 0,
		"contact collider object and runtime id agree")
	check(body.nonfinite_count == 0, "all captured contact fields are finite")
	check(body.first_world_point_error_m < 0.10, "local-position API value reciprocates collider point in world coordinates")
	check(body.first_world_point_error_m * 10.0 < body.first_local_hypothesis_error_m,
		"applying body transform again is rejected as a false local-position interpretation")
	check(body.first_normal_world_score > 0.95, "local-normal API value is normal-on-self in world orientation")
	check(body.first_normal_world_score > body.first_normal_local_hypothesis_score + 0.05,
		"applying body basis again is rejected as a false local-normal interpretation")
	check(body.first_impulse_ns.length() <= 0.000001 and body.first_closing_speed_mps > 5.0,
		"first contact callback is zero-impulse onset with closing velocity")
	check(body.first_nonzero_impulse_tick > body.first_contact_tick,
		"nonzero solver impulse is reported on a later callback")
	check(body.first_body_linear_velocity_mps.length() < 0.10 and body.first_closing_speed_mps > 5.0,
		"onset state velocity is post-solve while contact-point velocity still reports closing")
	check(body.first_nonzero_closing_speed_mps < 0.10,
		"later nonzero impulse is paired with post-solver contact velocity")
	check(body.first_nonzero_impulse_ns.dot(body.first_nonzero_normal.normalized()) >= 0.0,
		"reported impulse points with normal-on-self")
	check(body.summed_impulse_ns.dot(expected_normal_world) > 0.0,
		"aggregate reported impulse points along normal-on-self")
	check(body.negative_impulse_normal_count > 0 and body.minimum_impulse_normal_dot > -0.001,
		"real resting manifold exposes a tiny negative normal impulse rejected by strict zero tolerance")
	check(body.strict_manifold_accepted_points == body.raw_wall_point_total
		and body.strict_manifold_rejected_points == 0 and body.strict_manifold.invalid_total == 0,
		"tolerant directed manifold admits every real raw wall point without invalid gap")
	check(body.strict_manifold.clipped_normal_total == body.negative_impulse_normal_count
		and body.strict_manifold.clipped_normal_total == 1
		and is_equal_approx(body.strict_manifold_max_tick_clipped_normal_ns,
			-body.minimum_impulse_normal_dot),
		"actual negative-jitter point is clipped once with exact correction magnitude")
	check(body.strict_manifold.overflow_total == 0,
		"eight-slot directed manifold does not overflow one building counterpart")
	check(reported_window_relative_error > 10.0,
		"reported impulse and callback body velocity do not share a conserving temporal window")
	check(same_sign_relative_error > 0.10 and same_sign_relative_error < opposite_sign_relative_error,
		"zero-impulse onset leaves full-impact J over m unrecoverable from reported impulses")
	check(native_receipts.is_empty(), "current production collector drops building contact without vehicle id")

	var evidence := {
		"wall_contact_ticks": body.wall_contact_ticks,
		"raw_wall_point_total": body.raw_wall_point_total,
		"max_wall_points_per_tick": body.max_wall_points_per_tick,
		"first_contact_tick": body.first_contact_tick,
		"first_nonzero_impulse_tick": body.first_nonzero_impulse_tick,
		"first_point_self_api": body.first_point_self_world,
		"first_point_other_world": body.first_point_other_world,
		"first_world_point_error_m": body.first_world_point_error_m,
		"first_local_hypothesis_error_m": body.first_local_hypothesis_error_m,
		"first_normal_api": body.first_normal_raw,
		"expected_normal_on_self_world": expected_normal_world,
		"first_normal_world_score": body.first_normal_world_score,
		"first_normal_local_hypothesis_score": body.first_normal_local_hypothesis_score,
		"first_impulse_ns": body.first_impulse_ns,
		"first_relative_velocity_mps": body.first_relative_velocity_mps,
		"first_body_linear_velocity_mps": body.first_body_linear_velocity_mps,
		"first_body_angular_velocity_radps": body.first_body_angular_velocity_radps,
		"first_closing_speed_mps": body.first_closing_speed_mps,
		"first_nonzero_impulse_ns": body.first_nonzero_impulse_ns,
		"first_nonzero_normal": body.first_nonzero_normal,
		"first_nonzero_relative_velocity_mps": body.first_nonzero_relative_velocity_mps,
		"first_nonzero_closing_speed_mps": body.first_nonzero_closing_speed_mps,
		"summed_impulse_on_self_ns": body.summed_impulse_ns,
		"mass_times_delta_velocity_ns": momentum_delta_ns,
		"reported_window_mass_times_delta_velocity_ns": reported_window_momentum_delta_ns,
		"j_over_m_same_sign_relative_error": same_sign_relative_error,
		"j_over_m_opposite_sign_relative_error": opposite_sign_relative_error,
		"reported_window_j_over_m_relative_error": reported_window_relative_error,
		"minimum_raw_impulse_normal_dot_ns": body.minimum_impulse_normal_dot,
		"negative_raw_impulse_normal_count": body.negative_impulse_normal_count,
		"most_negative_raw_impulse_ns": body.most_negative_impulse_ns,
		"most_negative_raw_normal": body.most_negative_normal,
		"strict_manifold_accepted_points": body.strict_manifold_accepted_points,
		"strict_manifold_rejected_points": body.strict_manifold_rejected_points,
		"strict_manifold_invalid_total": body.strict_manifold.invalid_total,
		"strict_manifold_overflow_total": body.strict_manifold.overflow_total,
		"strict_manifold_clipped_normal_total": body.strict_manifold.clipped_normal_total,
		"strict_manifold_max_tick_clipped_normal_ns": body.strict_manifold_max_tick_clipped_normal_ns,
		"initial_velocity_mps": initial_velocity,
		"final_velocity_mps": final_velocity,
		"maximum_point_pair_separation_m": body.maximum_point_pair_separation_m,
		"native_building_receipt_count": native_receipts.size(),
	}
	body.free()
	wall.free()
	world.free()
	print_result(evidence, {"runtime_id": identity.counterpart_runtime_id, "wire_id": wire_identity})

func print_result(evidence: Dictionary, identities: Dictionary) -> void:
	print("NATIVE_VEHICLE_STATIC_CONTACT_BRIDGE_DIAGNOSTIC ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failure_count": failures.size(),
		"failures": failures,
		"production_sha256": FileAccess.get_sha256(PRODUCTION_BODY),
		"identity_adapter_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_identity.gd"),
		"manifold_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_manifold.gd"),
		"raw_point_capacity": MAX_RAW_POINTS,
		"identities": identities,
		"evidence": evidence,
		"runtime_wired": false,
		"qualification": "diagnostic-only actual PhysicsDirectBodyState3D building wall contact; no production, main, GPU, LIVE or Git mutation",
	}))
	quit(0 if failures.is_empty() else 1)
