extends SceneTree
const Host = preload("res://scripts/npc_visual/preview_resident_host.gd")
const Navigation = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const PACKET := "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"
const MANIFEST := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
const DIRECTORY := "res://assets/npc_visual/session/"
var scene: Node3D
var navigation: RefCounted
var host: RefCounted
var queue: RefCounted
var owners := {}
var trust := {}
var packet: PackedByteArray
var manifest: PackedByteArray
var checks := 0
var failures: Array[String] = []
var denied := ""
var no_support := false
var check_reentry := false
var reentry_seen := false

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

# Explicit test authority limited to the three independently accepted source
# candidates. This callback is NOT embedded in the production host.
func source_admit(point: Vector3, id: String, generation: int, footprint: float, _purpose: String) -> bool:
	if check_reentry:
		reentry_seen = host.request_walk(id, point) == -1
	if not owners.has(id) or id == denied or generation != 1 or absf(footprint - .738) > .000001: return false
	for offset: Vector2 in [Vector2.ZERO, Vector2(-footprint, -footprint), Vector2(-footprint, footprint), Vector2(footprint, -footprint), Vector2(footprint, footprint)]:
		if not scene._jump_surface_point_contains(Vector2(point.x + 395.65 + offset.x, point.z + 45.1 + offset.y)): return false
	return true

func support(point: Vector3, _id: String, _generation: int) -> float:
	if no_support: return NAN
	var block: Dictionary = scene.get("_block")
	var surface: Dictionary = block.surface
	var col := int(floor((point.x + block.originM[0]) / surface.cellSize)) - int(surface.startCol)
	var row := int(floor((point.z + block.originM[2]) / surface.cellSize)) - int(surface.startRow)
	if row < 0 or row >= surface.grid.size() or col < 0 or col >= surface.grid[row].size(): return NAN
	var tile: Dictionary = surface.palette[str(int(surface.grid[row][col]))]
	if not tile.solid: return NAN
	var y: float = tile.heightM
	var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x, y + .3, point.z), Vector3(point.x, y - .3, point.z), 1)
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
	return float(hit.position.y) if not hit.is_empty() and hit.normal.y > .7 else NAN

func configured(candidate: RefCounted, receipt: Dictionary, owner_records: Dictionary, admit: Callable = source_admit) -> Dictionary:
	return candidate.configure(scene, navigation, packet, receipt, manifest, DIRECTORY + "prepared", owner_records, admit, support)

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled = false; scene.preview_start_at_vehicle = false
	scene.preview_residents_enabled = false
	root.add_child(scene)
	await physics_frame; await physics_frame
	check(scene.preview_ready, "actual scene ready")
	queue = Queue.new(); navigation = Navigation.new()
	check(navigation.attach_existing(scene, scene.get("_printshop"), scene.get("_block"), scene.get("_printshop_data"), queue, "test:resident-session-authority", 1, 1), "actual geometry attached")
	packet = FileAccess.get_file_as_bytes(DIRECTORY + PACKET + ".json")
	manifest = FileAccess.get_file_as_bytes(DIRECTORY + "prepared/manifest.json")
	# The independently pinned packet is the test trust root, not arbitrary JSON.
	check(FileAccess.get_sha256(DIRECTORY + PACKET + ".json") == PACKET, "corrected packet exact bytes")
	check(FileAccess.get_sha256(DIRECTORY + "prepared/manifest.json") == MANIFEST, "final precision corrected cache")
	var parsed: Dictionary = JSON.parse_string(packet.get_string_from_utf8())
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/resident_speed_oracle.json"))
	var sources := {}
	for receipt: Dictionary in parsed.source_receipts: sources[receipt.path] = receipt.sha256
	trust = {"accepted": true, "packet_sha256": PACKET, "sources": sources, "session_id": parsed.session_id, "prepared_sha256": MANIFEST}
	for row: Dictionary in parsed.rows: owners[row.source_id] = Queue.Owner.new(row.source_id, 1)
	var rejected := Host.new()
	var altered: Dictionary = trust.duplicate(true); altered.accepted = false
	check(not configured(rejected, altered, owners).ok, "missing root acceptance fails")
	altered = trust.duplicate(true); altered.packet_sha256 = Host.REJECTED_PACKET
	check(not configured(rejected, altered, owners).ok, "historical packet forbidden")
	check(not configured(rejected, trust, {}).ok, "owners mandatory")
	check(not configured(rejected, trust, owners, Callable()).ok, "source access callback mandatory")
	var bad_owners := owners.duplicate(); bad_owners.resident_72 = Queue.Owner.new("resident_72", 2)
	check(not configured(rejected, trust, bad_owners).ok, "cannot invent new lifetime")
	host = Host.new()
	check(configured(host, trust, owners).ok, "corrected three candidates configured")
	check(host.occupants().is_empty(), "configuration creates no actors")
	# Negative floor and permission do not relocate or instantiate a placeholder.
	no_support = true
	check(host.admit_next().reason == "support_unknown", "missing floor remains pending")
	no_support = false; denied = "resident_169"
	check(host.admit_next().reason == "current_placement_blocked", "denied source stays pending")
	denied = ""
	# Real physics obstacle outside the .36 capsule but inside source square.
	var blocker := StaticBody3D.new(); blocker.collision_layer = 1
	var blocking_shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(.10, 1.0, .10); blocking_shape.shape = box; blocker.add_child(blocking_shape)
	scene.add_child(blocker); blocker.position = Vector3(32.8 + .60, .65, 6.15 + .60)
	await physics_frame
	check(host.admit_next().reason == "current_placement_blocked", "source square corner blocks beyond .36 capsule")
	blocker.position = Vector3(32.8, 1.75, 6.15); box.size = Vector3(1.0, .10, 1.0)
	await physics_frame
	check(host.retry_pending("resident_252"), "retry ceiling test")
	check(host.admit_next().reason == "current_placement_blocked", "actual ceiling refuses full height")
	blocker.free(); await physics_frame
	check(host.retry_pending("resident_252"), "retry after actual obstruction removed")
	var admission_results: Array = [host.admit_next()]
	check(host.retry_pending("resident_72") and host.retry_pending("resident_169"), "explicit pending retry")
	check_reentry = true
	admission_results.append(host.admit_next()); admission_results.append(host.admit_next())
	check_reentry = false
	check(reentry_seen, "source callback reentry rejected")
	check(host.occupants().size() == 3, "all actual candidates physically supported: " + str(admission_results))
	if host.occupants().size() != 3:
		print(JSON.stringify({"checks": checks, "failures": failures, "snapshot": host.snapshot()})); host.dispose(); navigation.dispose(); scene.free(); queue.dispose(); quit(1); return
	for record: Dictionary in host.snapshot().rows:
		for row: Dictionary in oracle.rows:
			if row.id == record.source_id: check(absf(row.speed_mps - record.speed_mps) < .0000000001, "actual JS effective-speed parity " + row.id)
		var expected: Dictionary
		for row: Dictionary in parsed.rows:
			if row.source_id == record.source_id: expected = row
		check(record.descriptor_sha256 == expected.descriptor_sha256, "source descriptor retained " + record.source_id)
		check(absf(record.position.x - (expected.source_raw.c * 4.1 - 395.65)) < .00001 and absf(record.position.z - (expected.source_raw.r * 4.1 - 45.1)) < .00001, "exact source XZ " + record.source_id)
		var body: CharacterBody3D = scene.get_node(record.bridge_id)
		check(body.get_meta("source_id") == record.source_id and body.get_meta("session_id") == parsed.session_id, "identity bound to physical node")
		check(body.get_node("ResidentVisualMotion").get_child(0).get_meta("npc_descriptor_sha256") == record.descriptor_sha256, "actual cached appearance")
		check(body.get_node("ResidentVisualMotion").global_basis.z.is_equal_approx(Vector3.RIGHT), "source initial ang zero faces east once")
		check(host.request_walk(record.source_id, record.position + Vector3.RIGHT * 9) == -1, "bounded nearby target")
	check(host.admit_next().status == "COMPLETE", "no duplicate births")
	var duplicate := Host.new()
	check(configured(duplicate, trust, owners).ok, "second host can inspect same trusted session")
	check(duplicate.admit_next().reason == "duplicate_source_body", "duplicate physical identity refused")
	duplicate.dispose()
	var until := Time.get_ticks_msec() + 15000
	while navigation.state() != "READY" and Time.get_ticks_msec() < until:
		await physics_frame; navigation.pump(Engine.get_physics_frames())
	check(navigation.state() == "READY", "actual Recast map ready")
	var targets := {}; var origins := {}
	for record: Dictionary in host.snapshot().rows:
		origins[record.source_id] = record.position
		# Explicit bounded QA instruction: choose one nearby physically clear target;
		# no generated agenda and no bypass of the engine route or source gate.
		for direction: Vector3 in [Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]:
			var target: Vector3 = record.position + direction * 2.0
			target.y = support(target, record.source_id, 1)
			if target.is_finite() and host.request_walk(record.source_id, target) >= 0: targets[record.source_id] = target; break
		check(targets.has(record.source_id), "safe nearby target " + record.source_id)
	denied = "resident_169"
	until = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		await physics_frame; navigation.pump(Engine.get_physics_frames()); host.step(1.0 / 60)
		var rows: Array = host.snapshot().rows
		if rows[1].status == "NO_PATH": break
	check(host.snapshot().rows[1].status == "NO_PATH", "current source access checked by delayed callback")
	check(host.snapshot().rows[1].position.distance_to(origins.resident_169) < .00001, "revoked route never moves")
	denied = ""
	check(host.request_walk("resident_169", targets.resident_169) >= 0, "only explicit new request resumes")
	var timings: Array[int] = []; var max_travel := 0.0; var moving_bones := false
	for frame in 360:
		await physics_frame; navigation.pump(Engine.get_physics_frames())
		var before: Array[Dictionary] = host.occupants()
		var started := Time.get_ticks_usec(); host.step(1.0 / 60); timings.append(Time.get_ticks_usec() - started)
		var after: Array[Dictionary] = host.occupants()
		for i in after.size(): max_travel = maxf(max_travel, before[i].position.distance_to(after[i].position))
		var rows: Array = host.snapshot().rows
		if frame == 30:
			var body: CharacterBody3D = scene.get_node("npc_resident_72")
			var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
			var bone := skeleton.find_bone("thigh_l")
			moving_bones = not skeleton.get_bone_pose_rotation(bone).is_equal_approx(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
		var arrived := 0
		for row: Dictionary in rows:
			if row.status == "ARRIVED": arrived += 1
		if arrived == 3 and frame > 60: break
	check(max_travel < .10, "physical substeps no teleport")
	check(moving_bones, "actual native skeleton walking")
	for record: Dictionary in host.snapshot().rows:
		check(record.status == "ARRIVED", "physically arrived " + record.source_id + ":" + record.status)
		check(record.position.distance_to(origins[record.source_id]) > 1.7, "real displacement " + record.source_id)
	# Current access invalidation must stop admitted residents, with no auto replan.
	check(navigation.update_access_version(2), "access changes invalidate receipt")
	host.step(1.0 / 60)
	for record: Dictionary in host.snapshot().rows: check(record.status == "STALE", "no stale movement " + record.source_id)
	for record: Dictionary in host.snapshot().rows: check(host.request_walk(record.source_id, origins[record.source_id]) >= 0, "new current-version return request")
	var interior: Node3D = scene.get("_printshop")
	var door_anchor: Array = scene.get("_printshop_data").doors.public.anchor
	# Test command at the actual authored door anchor; no actor is teleported.
	var opening: Dictionary = interior.request_door("public", true, Vector3(door_anchor[0], door_anchor[1], door_anchor[2]), host.occupants())
	check(opening.accepted and navigation.door_transition_started("public", 1.0), "door invalidates before first turn")
	host.step(1.0 / 60)
	for record: Dictionary in host.snapshot().rows: check(record.status == "STALE", "door transition preserves stale versus no path")
	owners.resident_72.dead = true; host.step(1.0 / 60)
	check(host.occupants().size() == 2, "owner death removes physical visual without rebirth")
	var final_state: Dictionary = host.snapshot()
	host.dispose(); host.dispose(); await physics_frame
	check(not scene.has_node("npc_resident_169") and not scene.has_node("npc_resident_252"), "dispose removes only owned bodies")
	check(is_instance_valid(scene.get("_player")), "existing player preserved")
	timings.sort()
	print(JSON.stringify({"checks": checks, "failures": failures, "actual_source_ids": owners.keys(), "timings_us_three_residents": {"p50": timings[timings.size() / 2], "p95": timings[int(timings.size() * .95)], "max": timings[-1]}, "max_physical_step": max_travel, "snapshot": final_state, "scope": "headless CPU actual main; no LIVE/full-scene FPS claim"}))
	navigation.dispose(); scene.free(); queue.dispose(); quit(0 if failures.is_empty() else 1)

func _initialize() -> void: call_deferred("run")
