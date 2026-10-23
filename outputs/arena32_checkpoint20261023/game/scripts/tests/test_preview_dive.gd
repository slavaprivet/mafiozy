extends SceneTree
const Dive = preload("res://scripts/preview_dive.gd")
const Player = preload("res://scripts/preview_player.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
func quat(a: Array) -> Quaternion:
	return Quaternion(a[0], a[1], a[2], a[3])
func run() -> void:
	var oracle_path := "res://scripts/tests/fixtures/preview_dive_oracle.json"
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(FileAccess.get_sha256("res://assets/hero.glb") == oracle.asset.sha256, "actual imported hero matches source oracle asset hash")
	for source: String in oracle.receipts:
		check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/" + source) == oracle.receipts[source].sha256, "oracle exact source receipt " + source)
	var player = Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	var motion: Node3D = player.get_node("VisualHeading/LocomotionOffset")
	var hero: Node3D = motion.get_child(0).get_child(0)
	var rig: Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0]
	var rest: Array[Transform3D] = []
	for i in range(rig.get_bone_count()):
		rest.append(rig.get_bone_pose(i))
	var body_before: Transform3D = player.transform
	var sampler = Dive.new()
	var bind_start := Time.get_ticks_usec()
	check(sampler.bind(hero, motion), "canonical actual rig binds")
	print("DIVE_BIND_CPU_US ", Time.get_ticks_usec() - bind_start)
	var costs: Array[int] = []
	var max_q_error := 0.0
	var max_offset_error := 0.0
	for expected: Dictionary in oracle.poses:
		var start := Time.get_ticks_usec()
		var actual: Dictionary = sampler.sample(expected.p, expected.blend, expected.rootYaw, expected.aimYaw, expected.aimPitch, expected.travelYaw, &"on_foot", 1)
		costs.append(Time.get_ticks_usec() - start)
		check(actual.valid and actual.active, "oracle pose sampled")
		if not actual.get("valid", false):
			continue
		for name: String in expected.rotations:
			var id := rig.find_bone(name)
			var rotation: Quaternion = actual.poses[id].basis.get_rotation_quaternion()
			var error := 1.0 - absf(rotation.dot(quat(expected.rotations[name])))
			max_q_error = maxf(max_q_error, error)
			check(error < 0.000002, "source local bone rotation " + name)
			check(actual.poses[id].origin.is_equal_approx(rest[id].origin) and actual.poses[id].basis.get_scale().is_equal_approx(rest[id].basis.get_scale()), "source lengths/scales retained")
		var rotation_error := 1.0 - absf(actual.visual_rotation.dot(quat(expected.visualRotation)))
		max_q_error = maxf(max_q_error, rotation_error)
		check(rotation_error < 0.000002, "directional source visual quaternion")
		var offset_error := absf(actual.visual_offset.y - float(expected.visualOffset[1]))
		max_offset_error = maxf(max_offset_error, offset_error)
		check(offset_error < 0.0001, "source full-skin support plane " + str(expected.p) + "/" + str(expected.blend))
	for i in range(rig.get_bone_count()):
		check(rig.get_bone_pose(i).is_equal_approx(rest[i]), "sample never writes live skeleton")
	check(motion.transform == Transform3D.IDENTITY and player.transform == body_before, "sample never moves/tilts physical or visual node")
	check(not sampler.sample(.3, 1.0, 0.0, 0.0, 0.0, 0.0, &"vehicle", 1).active and sampler.get_status().authority_epoch == -1, "vehicle authority clears sampler lifetime")
	check(sampler.sample(.3, 1.0, 0.0, 0.0, 0.0, 0.0, &"on_foot", 8).authority_epoch == 8, "new epoch accepted without old transition state")
	check(not sampler.sample(NAN, 1.0, 0.0, 0.0, 0.0, 0.0, &"on_foot", 8).valid and sampler.get_status().authority_epoch == -1, "non-finite sample clears state")
	for trace: Dictionary in oracle.traces:
		var state := {"elapsed": float(trace.upgradeElapsed), "mode": "normal", "startedAt": 0.0}
		state = Dive.upgrade(state, Vector2(1, 0), float(trace.upgradeElapsed) * 1000.0)
		var distance := float(trace.upgradeElapsed) * Dive.NORMAL_SPEED
		for expected: Dictionary in trace.steps:
			var actual: Dictionary = Dive.proposal(state, expected.dt)
			for key: String in ["elapsed", "progress", "diveBlend", "travel"]:
				check(absf(actual[key] - expected[key]) < 0.00001, "actual source trajectory " + key)
			check(absf(actual.arc_y - expected.y) < 0.00001 and actual.done == expected.done, "actual source arc and lifetime")
			distance += actual.travel
			state.elapsed = actual.elapsed
		check(distance <= 3.36001, "compact range never exceeds3.36m")
	var normal := {"elapsed": 0.2, "mode": "normal", "startedAt": 100.0}
	check(Dive.upgrade(normal, Vector2(1, 1), 600.0).mode == "dive", "inclusive500ms directional upgrade")
	check(Dive.upgrade(normal, Vector2(1, 1), 600.01).mode == "normal", "past500ms denied")
	check(Dive.upgrade(normal, Vector2.ZERO, 200.0).mode == "normal", "zero direction denied")
	for reason: String in ["done", "falling", "ceilingHit"]:
		var denied := normal.duplicate()
		denied[reason] = true
		check(Dive.upgrade(denied, Vector2(1, 0), 200.0).mode == "normal", reason + " blocks upgrade")
	var dive: Dictionary = Dive.upgrade(normal, Vector2(1, 0), 200.0)
	check(Dive.upgrade(dive, Vector2(0, 1), 250.0) == dive, "third press never changes direction or adds impulse")
	check(dive.elapsed == normal.elapsed and dive.startedAt == normal.startedAt, "upgrade preserves trajectory elapsed/start")
	check(not Dive.proposal(normal, NAN).valid, "invalid proposal delta denied")
	check(not Dive.proposal({"elapsed": NAN}, .04).valid, "invalid trajectory state denied")
	for dt in [0.0, -0.1, NAN, INF, 1.01, 2.0]:
		check(Dive.frame_steps(dt).is_empty(), "invalid/long gap freezes without debt")
	check(Dive.frame_steps(.1, false).is_empty(), "hidden frame freezes")
	for dt in [.26, 1.0/3.0, .5, 1.0]:
		var steps: PackedFloat64Array = Dive.frame_steps(dt)
		var total := 0.0
		for step: float in steps:
			total += step
			check(step <= .040001 and step > 0.0, "bounded physical substep")
		check(steps.size() <= 7 and absf(total - .25) < .000001, "slow visible frame consumes250ms, no full freeze")
	# Optional isolated kernel profile: clocks remain outside production sampler.
	var total_costs: Array[int] = []
	var support_costs: Array[int] = []
	for i in range(140):
		var start := Time.get_ticks_usec()
		var result: Dictionary = sampler.sample(.32, 1.0, -.67, 1.13, .24, 2.7, &"on_foot", 9)
		var total := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		sampler._minimum_skin(result.visual_rotation)
		var support := Time.get_ticks_usec() - start
		if i >= 12:
			total_costs.append(total)
			support_costs.append(support)
	total_costs.sort()
	support_costs.sort()
	print("DIVE_KERNEL_PROFILE ", JSON.stringify({"samples": 128, "total_p50_us": total_costs[63], "total_p95_us": total_costs[121], "support_p50_us": support_costs[63], "support_p95_us": support_costs[121], "qualification": "isolated same-pose warmed CPU; timings outside sampler, not LIVE/FPS"}))
	await test_host_sweeps()
	costs.sort()
	print("PREVIEW_DIVE_TEST ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures.slice(0, 12), "failure_count": failures.size(), "oracle_poses": oracle.poses.size(), "source_trajectory_traces": oracle.traces.size(), "max_quaternion_dot_error": max_q_error, "max_visual_offset_error_m": max_offset_error, "sampler_cpu_p50_us": costs[costs.size()/2], "sampler_cpu_p95_us": costs[int(costs.size()*.95)], "binding": sampler.get_status(), "runtime_integrated": false, "live": false}))
	player.free()
	quit(0 if failures.is_empty() else 1)

func test_host_sweeps() -> void:
	# Contract probe only, not a gameplay controller: requested motion is passed
	# through real Godot continuous body sweeps, never assigned to body.position.
	var world := Node3D.new()
	root.add_child(world)
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .30
	capsule.height = 1.9
	collider.shape = capsule
	collider.position.y = .95
	body.add_child(collider)
	world.add_child(body)
	var wall := static_box(world, Vector3(1.0, 1.0, 0), Vector3(.02, 3.0, 8.0))
	body.position = Vector3(0, .02, 0) # Test fixture spawn only.
	await physics_frame
	await physics_frame
	var collision := body.move_and_collide(Vector3(3.36, 0, 0))
	check(collision != null and body.position.x < .691, "actual capsule sweep cannot tunnel through2cm wall on3.36m request")
	wall.free()
	var ceiling := static_box(world, Vector3(0, 2.02, 0), Vector3(8.0, .02, 8.0))
	body.position = Vector3(0, .02, 0)
	await physics_frame
	await physics_frame
	collision = body.move_and_collide(Vector3(0, .42, 0))
	check(collision != null and collision.get_normal().y < -.9 and body.position.y < .111, "actual upward capsule sweep detects ceiling before arc target")
	ceiling.free()
	static_box(world, Vector3(0, -.1, 0), Vector3(8.0, .2, 8.0))
	body.position = Vector3(0, 2.0, 0)
	await physics_frame
	await physics_frame
	collision = body.move_and_collide(Vector3(0, -3.0, 0))
	check(collision != null and collision.get_normal().y > .9 and absf(body.position.y) < .01, "actual downward sweep confirms support within1cm physics margin: " + str(body.position.y))
	world.free()

func static_box(world: Node3D, position_value: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	body.position = position_value
	world.add_child(body)
	return body
