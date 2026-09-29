extends SceneTree
const Host = preload("res://scripts/npc_visual/preview_resident_host.gd")
const Policy = preload("res://scripts/npc_visual/preview_resident_world_policy.gd")
const Navigation = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const PACKET := "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"
const MANIFEST := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
const BLOCK := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const DIR := "res://assets/npc_visual/session/"
var errors: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)

func run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled = false; scene.preview_start_at_vehicle = false
	scene.preview_residents_enabled = false
	root.add_child(scene)
	await physics_frame; await physics_frame
	check(scene.preview_ready, "main ready")
	var packet := FileAccess.get_file_as_bytes(DIR + PACKET + ".json")
	check(FileAccess.get_sha256(DIR + PACKET + ".json") == PACKET, "packet pinned")
	check(FileAccess.get_sha256(DIR + "prepared/manifest.json") == MANIFEST, "appearance pinned")
	var parsed: Dictionary = JSON.parse_string(packet.get_string_from_utf8())
	var sources := {}; var owners := {}; var states := {}
	for receipt: Dictionary in parsed.source_receipts: sources[receipt.path] = receipt.sha256
	for row: Dictionary in parsed.rows:
		owners[row.source_id] = Queue.Owner.new(row.source_id, 1)
		states[row.source_id] = "ordinary_outdoor"
	var trust := {"accepted":true, "packet_sha256":PACKET, "sources":sources, "session_id":parsed.session_id, "prepared_sha256":MANIFEST, "block_sha256":BLOCK}
	var policy: RefCounted = Policy.new()
	var p: Dictionary = policy.configure(scene, parsed.rows, owners, trust, {"version":1, "states":states})
	check(p.get("ok", false), "source policy:" + str(p))
	var queue: RefCounted = Queue.new(); var nav: RefCounted = Navigation.new()
	check(nav.attach_existing(scene, scene.get("_printshop"), scene.get("_block"), scene.get("_printshop_data"), queue, parsed.session_id, 1, 1), "navigation attached")
	var host: RefCounted = Host.new()
	var h: Dictionary = host.configure(scene, nav, packet, trust, FileAccess.get_file_as_bytes(DIR + "prepared/manifest.json"), DIR + "prepared", owners, Callable(policy, "source_admit"), Callable(policy, "support_height"))
	check(h.get("ok", false), "host configured:" + str(h))
	# Root's separate physical/source policy probe selected these exact local
	# preview stages near the vehicle. They are not the raw source birth cells.
	var choices: Array[Dictionary] = [
		{"r":7.73170787532155, "c":105.310391309785},
		{"r":9.56097616800448, "c":105.310391309785},
		{"r":6.26829324117521, "c":104.944537651248},
	]
	var selected: Array[Dictionary] = []
	for row: Dictionary in parsed.rows:
		var found := false
		for candidate: Dictionary in [choices[selected.size()]]:
			var point := Vector3(candidate.c * 4.1 - 395.65, 0, candidate.r * 4.1 - 45.1)
			var result: Dictionary = host.admit_preview_stage(row.source_id, candidate.r, candidate.c)
			if result.status == "IDLE":
				selected.append({"id":row.source_id, "r":candidate.r, "c":candidate.c,
					"position":result.position})
				found = true
				break
		check(found, "source+physical staging " + row.source_id)
	check(selected.size() == 3, "three physical source IDs")
	check(host.enable_walk_preview(), "walking preview enabled")
	var started := Time.get_ticks_msec()
	while nav.state() != "READY" and Time.get_ticks_msec() - started < 15000:
		await physics_frame; nav.pump(Engine.get_physics_frames())
	check(nav.state() == "READY", "engine navigation ready")
	var origin := {}; var displacement := {}; var statuses := {}
	for record: Dictionary in host.snapshot().rows: origin[record.source_id] = record.position; displacement[record.source_id] = 0.0
	var timings: Array[int] = []
	var previous_body_yaw := {}; var previous_visual_yaw := {}
	var largest_body_turn := 0.0; var largest_visual_turn := 0.0; var sharp_body_turns := 0
	for row: Dictionary in selected:
		var body: CharacterBody3D = scene.get_node("npc_" + row.id)
		var motion: Node3D = body.get_node("ResidentVisualMotion")
		previous_body_yaw[row.id] = body.rotation.y
		previous_visual_yaw[row.id] = body.rotation.y + motion.rotation.y
	for frame in 600:
		await physics_frame
		nav.pump(Engine.get_physics_frames())
		var t := Time.get_ticks_usec()
		host.step(1.0 / 60.0); host.preview_walk_step(1.0 / 60.0)
		timings.append(Time.get_ticks_usec() - t)
		for record: Dictionary in host.snapshot().rows:
			if record.position is Vector3:
				displacement[record.source_id] = maxf(displacement[record.source_id], record.position.distance_to(origin[record.source_id]))
			statuses[record.source_id] = record.status
		for row: Dictionary in selected:
			var body: CharacterBody3D = scene.get_node("npc_" + row.id)
			var motion: Node3D = body.get_node("ResidentVisualMotion")
			var visual_yaw: float = body.rotation.y + motion.rotation.y
			var body_turn := absf(atan2(sin(body.rotation.y - previous_body_yaw[row.id]), cos(body.rotation.y - previous_body_yaw[row.id])))
			var visual_turn := absf(atan2(sin(visual_yaw - previous_visual_yaw[row.id]), cos(visual_yaw - previous_visual_yaw[row.id])))
			largest_body_turn = maxf(largest_body_turn, body_turn)
			largest_visual_turn = maxf(largest_visual_turn, visual_turn)
			if body_turn > 1.0:
				sharp_body_turns += 1
				check(visual_turn < body_turn * .7, "render turn damped while physics heading changes")
			previous_body_yaw[row.id] = body.rotation.y
			previous_visual_yaw[row.id] = visual_yaw
	for id: String in displacement: check(displacement[id] > .5, "actual movement " + id)
	check(sharp_body_turns > 0 and largest_visual_turn < 1.0, "shortest visual yaw tween bounds abrupt turn")
	# A denied current source role cannot be reopened by the autonomous QA
	# exercise. Once restored, it must create a new current-version route.
	var denied: Dictionary = states.duplicate()
	denied["resident_169"] = "deny"
	check(policy.update_access(2, denied), "deny source access")
	check(nav.update_access_version(2), "invalidate old navigation receipts")
	var denied_position: Vector3 = host.snapshot().rows[1].position
	for frame in 180:
		await physics_frame; nav.pump(Engine.get_physics_frames())
		host.step(1.0 / 60.0); host.preview_walk_step(1.0 / 60.0)
	check(host.snapshot().rows[1].position.distance_to(denied_position) < .03, "denied owner stays stopped")
	check(policy.update_access(3, states), "restore source role")
	check(nav.update_access_version(3), "new access revision")
	var resumed := false
	for frame in 540:
		await physics_frame; nav.pump(Engine.get_physics_frames())
		host.step(1.0 / 60.0); host.preview_walk_step(1.0 / 60.0)
		if host.snapshot().rows[1].position.distance_to(denied_position) > .20: resumed = true
	check(resumed, "new guarded route resumes after permission restored")
	for body: Dictionary in selected:
		var node: Node = scene.get_node("npc_" + body.id)
		check(node is CharacterBody3D and node.get_meta("placement_mode", "") == "PREVIEW_STAGE", "honest staging meta " + body.id)
	timings.sort()
	print(JSON.stringify({"errors":errors, "selected":selected, "max_displacement_m":displacement, "status":statuses,
		"turns":{"sharp_body_turns":sharp_body_turns,"largest_body_rad":largest_body_turn,"largest_visual_rad":largest_visual_turn},
		"step_us_p50":timings[timings.size()/2], "step_us_p95":timings[int(timings.size()*.95)],
		"scope":"headless actual main, preview staged QA, not source full placement or LIVE FPS"}))
	host.dispose(); nav.dispose(); policy.dispose(); queue.dispose(); scene.free()
	quit(0 if errors.is_empty() else 1)

func _initialize() -> void: call_deferred("run")
