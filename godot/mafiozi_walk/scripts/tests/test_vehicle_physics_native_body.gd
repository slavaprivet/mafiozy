extends SceneTree

const Body = preload("res://scripts/vehicle_physics/vehicle_native_body.gd")
const Profile = preload("res://scripts/vehicle_physics/vehicle_profile.gd")
const ContactBuffer = preload("res://scripts/vehicle_physics/vehicle_contact_buffer.gd")
const ContactLedger = preload("res://scripts/vehicle_physics/vehicle_contact_ledger.gd")
const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const FIXTURE := "res://scripts/vehicle_physics/fixtures/source_vehicle_profiles.v1.json"
const TRANSPORT := "res://data/transport/vehicle_descriptors.v1.json"
const TRANSPORT_SHA := "99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a"
const SCENE := "res://scenes/vehicle_physics/native_vehicle_headless_fixture.tscn"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema == "mafiozi.native-vehicle-physics-source-fixture/v1", "fixture schema")
	check(fixture.profiles.size() == 4, "representative source families")
	var source_path := "res://../../assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs"
	check("sha256:" + FileAccess.get_sha256(source_path) == fixture.source_receipt, "source profile receipt")
	check(FileAccess.get_sha256(TRANSPORT) == TRANSPORT_SHA, "frozen transport descriptor receipt")
	var transport: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRANSPORT))
	check(transport.schema == "mafiozi.transport.descriptors.v1" and transport.profiles.size() == 12, "all transport source profiles available")
	for expected: Dictionary in fixture.profiles:
		var actual: Dictionary = {}
		for candidate: Dictionary in transport.profiles:
			if candidate.profile_id == expected.profile_id: actual = candidate; break
		check(not actual.is_empty(), "representative profile present " + str(expected.profile_id))
		for key: String in ["mass_kg", "wheelbase_m", "wheel_radius_m", "engine_accel_mps2", "max_forward_speed_mps", "max_reverse_speed_mps"]:
			check(is_equal_approx(float(actual.get(key)), float(expected.get(key))), "exact source field " + str(expected.profile_id) + ":" + key)
	for candidate: Dictionary in transport.profiles:
		var admission := candidate.duplicate(true)
		admission.vehicle_id = "admission-" + str(candidate.profile_id)
		admission.source_id = str(candidate.profile_id)
		admission.life_generation = 1
		admission.source_clock = 1
		var admitted_profile = Profile.from_dictionary(admission)
		check(admitted_profile != null and admitted_profile.is_valid(), "all-source admission " + str(candidate.profile_id))
		check(admitted_profile.native_default_fields.size() == 5, "all-source native defaults explicit " + str(candidate.profile_id))
	var rows: Array[Dictionary] = []
	for wanted: String in ["compact_sedan", "sport_coupe", "city_bus", "fire_engine"]:
		var row: Dictionary = {}
		for candidate: Dictionary in transport.profiles:
			if candidate.profile_id == wanted:
				row = candidate.duplicate(true)
				break
		row.vehicle_id = "fixture-" + wanted
		row.source_id = wanted
		row.life_generation = 1
		row.source_clock = 100
		row.source_receipt = TRANSPORT_SHA
		rows.append(row)
		var profile = Profile.from_dictionary(row)
		check(profile != null and profile.is_valid(), "valid source profile " + str(row.profile_id))
		check(is_equal_approx(profile.wheelbase_m, float(row.wheelbase_m)), "exact wheelbase " + str(row.profile_id))
		check(profile.wheel_local_positions().size() == 4, "four contact anchors " + str(row.profile_id))
		check(profile.native_default_fields.size() == 5, "five unavailable source fields stay explicit native defaults " + str(row.profile_id))
	check(Profile.from_dictionary({"vehicle_id":"bad", "profile_id":"bad", "mass_kg":NAN}) == null, "invalid profile fails closed")
	var malformed := rows[0].duplicate(true)
	malformed.center_of_mass_local_m = Vector3(NAN, 0, 0)
	check(Profile.from_dictionary(malformed) == null, "non-finite explicit COM fails closed")
	malformed = rows[0].duplicate(true)
	malformed.body_half_extents_m = "not geometry"
	check(Profile.from_dictionary(malformed) == null, "malformed explicit geometry fails closed")
	malformed = rows[0].duplicate(true)
	malformed.engine_accel_mps2 = -500.0
	check(Profile.from_dictionary(malformed) == null, "negative propulsion fails closed")
	check(Body.force_substeps(1.0 / 30.0) == 4 and Body.force_substeps(1.0 / 60.0) == 2 and Body.force_substeps(1.0 / 120.0) == 1 and Body.force_substeps(0.2) == 12, "exact bounded 120Hz force partition")
	var factory := Factory.new()
	var spawned := factory.spawn_from_descriptor({"vehicle_id":"factory-car", "life_generation":2,
		"profile_id":"compact_sedan", "active":true, "position_m":{"x":1,"y":0,"z":2},
		"yaw_rad":0.25, "source_clock":101}, rows[0])
	check(spawned != null and spawned.position == Vector3(1, 0, 2) and is_equal_approx(spawned.rotation.y, 0.25), "bootstrap factory preserves source-ground pose")
	check(spawned.snapshot_state().position_m == Vector3(1, 0, 2), "initial snapshot reports admitted pose before first physics tick")
	check(spawned.profile.life_generation == 2 and spawned.profile.source_clock == 101, "bootstrap factory binds stable life identity")
	spawned.linear_velocity = Vector3(3, 4, 5)
	spawned.angular_velocity = Vector3(0, 0, 2)
	check(spawned.velocity_at_local_anchor(spawned.profile.center_of_mass_local_m).is_equal_approx(spawned.linear_velocity), "anchor velocity is relative to actual COM")
	check(spawned.submit_authoritative_control(0.5, 0.0, 0.0, false, 1, "factory-car", 2, 101), "matching life control accepted")
	check(not spawned.submit_authoritative_control(0.5, 0.0, 0.0, false, 2, "factory-car", 1, 102), "stale life control rejected")
	check(not spawned.submit_authoritative_control(0.5, 0.0, 0.0, false, 2, "factory-car", 2, 100), "stale source clock rejected")
	var next_life := rows[0].duplicate(true)
	next_life.vehicle_id = "factory-car"
	next_life.life_generation = 3
	next_life.source_clock = 200
	check(spawned.configure(next_life) and spawned.snapshot_state().control_sequence == -1, "new life resets control sequence")
	check(spawned.get_meta("life_generation") == 3 and spawned.profile.life_generation == 3, "new life metadata stays synchronized")
	spawned.free()
	check(factory.spawn_from_descriptor({"vehicle_id":"bad", "life_generation":1, "profile_id":"wrong", "position_m":Vector3.ZERO, "yaw_rad":0.0, "source_clock":1}, rows[0]) == null and factory.last_error == "profile_identity_mismatch", "bootstrap profile mismatch fails closed")
	var ring := ContactBuffer.new(4)
	for i in 9: ring.push_contact("car", 1, i, i, "wall", Vector3.ZERO, Vector3.UP, Vector3.ZERO, float(i))
	check(ring.has_gap(), "contact ring exposes unread GAP")
	var drained := ring.drain()
	check(drained.size() == 4 and drained[0].contact_sequence == 0 and drained[-1].contact_sequence == 3, "contact ring preserves unread critical order")
	check(ring.overflow_total == 5 and ring.size() == 0, "contact ring explicit fail-closed overflow")
	var ledger := ContactLedger.new(8)
	var accepted := 0
	for tick in range(1, 11):
		ledger.begin_tick(tick)
		if ledger.accept("same-wall", tick): accepted += 1
	check(accepted == 1 and ledger.status().suppressed_total == 9, "persistent manifold emits one impact onset")
	for tick in range(11, 14): ledger.begin_tick(tick)
	check(ledger.accept("same-wall", 14), "separation rearms counterpart impact")
	var reuse_ledger := ContactLedger.new(8)
	for i in 8:
		reuse_ledger.begin_tick(i * 4)
		reuse_ledger.accept("old-" + str(i), i * 4)
	reuse_ledger.begin_tick(40)
	check(reuse_ledger.accept("new-counterpart", 40), "inactive counterpart slots are reusable")
	var world: Node3D = load(SCENE).instantiate()
	root.add_child(world)
	var car := Body.new()
	check(car.configure(rows[0]), "body accepts immutable descriptor")
	car.position = Vector3(0, 1.15, 0)
	world.add_child(car)
	for i in 180:
		await physics_frame
	var settled := car.snapshot_state()
	check(settled.get("physics_tick", 0) >= 170, "real rigid body integration advanced")
	check(int(settled.get("grounded_wheel_mask", 0)) != 0, "real wheel probes grounded")
	check(str(settled.surface_ids[0]) == "dry_asphalt", "surface identity from actual collider")
	check(absf(car.rotation.x) < 0.15 and absf(car.rotation.z) < 0.15, "four-point suspension settles upright")
	check(car.submit_control(1.0, 0.0, 0.0, false, 1), "fresh control accepted")
	check(not car.submit_control(1.0, 0.0, 0.0, false, 1), "stale control rejected")
	check(not car.submit_control(NAN, 0.0, 0.0, false, 2), "non-finite control rejected")
	var start_z := car.position.z
	for i in 240:
		await physics_frame
	var driven := car.snapshot_state()
	check(car.position.z < start_z - 3.0, "throttle moves Godot body along -Z actual=" + str(car.position.z - start_z))
	check(absf(car.linear_velocity.z) <= float(rows[0].max_forward_speed_mps) + 1.0, "source speed cap")
	check(driven.vehicle_id == "fixture-compact_sedan" and driven.life_generation == 1 and driven.source_clock == 100, "stable identity in state")
	check(car.submit_control(0.0, 0.0, 1.0, false, 3), "brake accepted")
	var speed_before := car.linear_velocity.length()
	for i in 90:
		await physics_frame
	check(car.linear_velocity.length() < speed_before, "service brake reduces speed")
	var sweep := car.body_sweep(Transform3D(car.global_basis, Vector3(0, car.position.y, -26)))
	check(sweep.valid and sweep.safe_fraction < 1.0, "actual Godot body sweep sees authored wall")
	var rotated_sweep := car.body_sweep(Transform3D(Basis(Vector3.UP, PI * 0.5), car.global_position))
	check(not rotated_sweep.valid and rotated_sweep.reason == "rotation_sweep_unsupported", "rotation-only sweep fails closed")
	car.position = Vector3(0, 1.0, -19.5)
	car.linear_velocity = Vector3(0, 0, -14)
	car.clear_control(4)
	for i in 90:
		await physics_frame
	var receipts := car.drain_contact_receipts()
	var wall_contact := false
	for receipt: Dictionary in receipts:
		check(receipt.proposal_only == true, "contact is proposal only")
		check(receipt.vehicle_id == "fixture-compact_sedan" and receipt.life_generation == 1, "contact stable life identity")
		if receipt.counterpart_id == "fixture-wall": wall_contact = true
	check(wall_contact, "real wall impact publishes contact")
	check(receipts.size() <= car.contact_buffer_status().capacity, "contact output bounded")
	var drift := factory.spawn_from_descriptor({"vehicle_id":"drift-car", "life_generation":1,
		"profile_id":"compact_sedan", "active":true, "position_m":{"x":-4,"y":0,"z":15},
		"yaw_rad":0.0, "source_clock":102}, rows[0])
	world.add_child(drift)
	for i in 120: await physics_frame
	drift.submit_control(1.0, 0.0, 0.0, false, 1)
	for i in 120: await physics_frame
	drift.submit_control(0.65, 0.85, 0.0, true, 2)
	for i in 90: await physics_frame
	var drift_lateral := absf(drift.linear_velocity.dot(drift.global_basis.x))
	var drift_state: Dictionary = drift.snapshot_state()
	check(absf(drift.rotation.y) > 0.08, "steering creates real chassis yaw")
	check(drift_lateral > 0.15, "rear handbrake releases grip and creates lateral motion")
	check(float(drift_state.wheel_slip[2]) >= 0.60 and float(drift_state.wheel_slip[3]) >= 0.60, "rear skid signal available for tyre marks and smoke")
	check(drift.wheel_visual_state(0).valid and not drift.wheel_visual_state(9).valid, "bounded wheel presentation API")
	drift.free()
	var costs: Array[int] = []
	for i in 256:
		var started := Time.get_ticks_usec()
		car.snapshot_state()
		costs.append(Time.get_ticks_usec() - started)
	costs.sort()
	print("NATIVE_VEHICLE_CPU_PROFILE ", JSON.stringify({"samples": costs.size(), "snapshot_p50_us": costs[127], "snapshot_p95_us": costs[242], "qualification": "isolated warmed CPU API cost; not LIVE and not FPS"}))
	print("NATIVE_VEHICLE_PHYSICS_TEST ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures.slice(0, 20), "failure_count": failures.size(), "physics_tick": car.snapshot_state().get("physics_tick", 0), "contacts": receipts.size(), "position": car.position, "velocity": car.linear_velocity, "runtime_integrated": false, "live": false}))
	world.free()
	quit(0 if failures.is_empty() else 1)
