extends SceneTree
const MAIN = preload("res://scenes/main.tscn")
const SOURCE_ID := "REBUILD-VISUAL-print_shop-001"
var checks := 0
var failures: Array[String] = []
var world: Node3D
var player: CharacterBody3D
var interior: Node3D
var data: Dictionary
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL: " + label)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
func input_e(pressed: bool = true, echo: bool = false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = pressed
	key.echo = echo
	root.push_input(key)
func exterior_signature(scene: Node3D, include_printshop: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in scene.get_children():
		if not node is StaticBody3D or not node.has_meta("source_id"):
			continue
		if not include_printshop and node.get_meta("source_id") == SOURCE_ID:
			continue
		var key := str(node.get_meta("source_id")) + ":" + str(node.get_meta("source_index"))
		var shape: ConvexPolygonShape3D = node.get_child(0).shape
		result[key] = {"points": shape.points, "transform": node.global_transform, "layer": node.collision_layer, "mask": node.collision_mask}
	return result
func blocked(from: Vector3, to: Vector3) -> bool:
	var collider: CollisionShape3D = player.get_node("PlayerCapsule")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3(0, collider.shape.height * 0.5 + 0.015, 0))
	query.motion = to - from
	query.margin = 0.005
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return world.get_world_3d().direct_space_state.cast_motion(query)[0] < 0.999
func run() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var fixture := "user://printshop_corrupt_%d.json" % OS.get_process_id()
	var file := FileAccess.open(fixture, FileAccess.WRITE)
	file.store_string("{\"schema\":\"malformed\"}")
	file.close()
	var baseline: Dictionary = {}
	for path: String in ["user://absent_printshop_hook.json", fixture]:
		var fallback: Node3D = MAIN.instantiate()
		fallback.printshop_data_path = path
		root.add_child(fallback)
		await frames(2)
		check(fallback.preview_ready and fallback.printshop_status == "exterior_fallback" and fallback._printshop == null, "failed optional package preserves exterior READY without interior READY")
		check(fallback.printshop_errors.size() == 1 and fallback.validation_errors.is_empty(), "package failure reported separately from scene admission")
		check(exterior_signature(fallback, true).size() == 27, "failed package keeps all27 original colliders")
		check(fallback.get_node_or_null("PrintshopInterior") == null, "failed package leaves no generated node")
		var visual: Node3D = fallback.get_node(SOURCE_ID).get_child(0)
		check(not visual.has_meta("printshop_interior_attached"), "failed package leaves original visual unmodified")
		baseline = exterior_signature(fallback)
		fallback.free()
		await frames(2)
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture)) == OK, "owned corrupt fixture removed")
	# Correct package but rejected placement: exercise attach's failure branch,
	# including restore/free and all three original envelope bodies.
	var block_fixture := "user://printshop_placement_%d.json" % OS.get_process_id()
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	for building: Dictionary in block.buildings:
		if building.id == SOURCE_ID:
			building.transform.modelLocalOffsetM[0] += 0.1
	file = FileAccess.open(block_fixture, FileAccess.WRITE)
	file.store_string(JSON.stringify(block))
	file.close()
	var rejected: Node3D = MAIN.instantiate()
	rejected.block_data_path = block_fixture
	root.add_child(rejected)
	await frames(2)
	check(rejected.preview_ready and rejected.printshop_status == "exterior_fallback" and rejected._printshop == null and rejected.get_node_or_null("PrintshopInterior") == null, "attach rejection removes complete generated adapter and retains exterior ready")
	check(rejected.printshop_errors.has("Source placement mismatch") and exterior_signature(rejected, true).size() == 27, "attach rejection keeps27 original bodies and reports placement mismatch")
	check(exterior_signature(rejected) == baseline and not rejected.get_node(SOURCE_ID).get_child(0).has_meta("printshop_interior_attached"), "attach rejection preserves24 others and original printshop visual")
	rejected.free()
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(block_fixture)) == OK, "owned placement fixture removed")
	world = MAIN.instantiate()
	var crlf_fixture := "user://printshop_crlf_%d.json" % OS.get_process_id()
	file = FileAccess.open(crlf_fixture, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://data/printshop_interior.json").replace("\r\n", "\n").replace("\n", "\r\n"))
	file.close()
	world.printshop_data_path = crlf_fixture
	root.add_child(world)
	await frames(5)
	player = world._player
	interior = world._printshop
	check(world.preview_ready and interior != null and world.printshop_status == "ready", "actual main attaches interior")
	check(world.printshop_errors.is_empty(), "canonical package no errors")
	check(player.position.distance_to(interior.anchor("publicApproach")) < 0.1, "requested next-preview spawn is at actual public approach")
	check(not interior.nearest_action(player.global_position).is_empty(), "initial position already offers public door E")
	var entrance_direction: Vector3 = interior.anchor("publicInside") - interior.anchor("publicApproach")
	entrance_direction.y = 0.0
	var camera_direction := Basis(Vector3.UP, float(player.get("_camera_yaw"))) * Vector3.FORWARD
	check(camera_direction.dot(entrance_direction.normalized()) > .999, "initial camera faces the real printshop entrance")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(crlf_fixture)) == OK, "CRLF-equivalent package admitted and owned fixture removed")
	check(exterior_signature(world) == baseline and baseline.size() == 24, "all24 non-printshop source shapes/transforms/layers/masks byte-equivalent to fallback")
	check(exterior_signature(world, true).size() == 24, "only three printshop envelopes absent")
	check(not world.preview_perf_enabled and not world.preview_perf.is_capturing() and not world.preview_perf.is_processing(), "perf default OFF preserved")
	world._capture_path = "user://forbidden_during_perf.png"
	check(not world.begin_preview_perf_capture(), "PNG capture still rejects perf")
	world._capture_path = ""
	player.set_physics_process(false)
	var previous_epoch: int = player.get_preview_status().pose_epoch
	player.position.y = -13.0
	world._process(0.0)
	check(player.position.is_equal_approx(world._spawn) and player.get_preview_status().pose_epoch == previous_epoch + 1, "out-of-world preview fallback resets pose lifetime after teleport")
	var actual: Dictionary = world._current_door_occupants()[0]
	var shape: CapsuleShape3D = player.get_node("PlayerCapsule").shape
	check(is_equal_approx(actual.radius, shape.radius) and is_equal_approx(actual.height, shape.height) and actual.position.is_equal_approx(player.global_position), "occupant takes exact actual capsule radius/height/feet")
	var anchor := vec(data.doors.public.anchor)
	var direction: Vector3 = interior.anchor("publicApproach") - interior.anchor("publicInside")
	direction.y = 0.0
	direction = direction.normalized()
	var outside := anchor + direction * 1.4
	var inside := anchor - direction * 1.4
	player.global_position = outside
	await frames(2)
	check(world._door_hint.text == "Открыть дверь" and world._door_hint_key.visible, "public approach offers separate E key and open label")
	var text_edit := LineEdit.new()
	world.add_child(text_edit)
	text_edit.grab_focus()
	input_e()
	check(not interior.nearest_action(outside).opening, "typing in focused text control does not activate door")
	text_edit.release_focus()
	text_edit.free()
	check(blocked(outside, inside), "closed actualmain public door blocks actual player capsule")
	input_e(false)
	input_e(true, true)
	check(not interior.nearest_action(outside).opening, "release and key echo do not toggle")
	input_e()
	check(interior.nearest_action(outside).opening and world._door_hint.text == "Закрыть дверь", "single real input E chooses open target")
	input_e()
	check(not interior.nearest_action(outside).opening, "rapid E reverses desired target before fraction changes")
	input_e()
	await frames(50)
	check(is_equal_approx(interior.door_fraction("public"), 1.0), "main physics advances door to full open")
	check(not blocked(outside, inside), "open actualmain public door permits capsule cast")
	# Move the actual CharacterBody3D through the opening and back, with normal
	# gravity/floor snap and real move_and_slide via controller input.
	player.global_position = interior.anchor("publicApproach")
	player.velocity = Vector3.ZERO
	player.set("_camera_yaw", atan2(direction.x, direction.z))
	player.call("_update_camera_rotation")
	player.set_physics_process(true)
	Input.action_press(player.ACTION_FORWARD)
	await frames(90)
	Input.action_release(player.ACTION_FORWARD)
	await frames(8)
	check(player.global_position.x < anchor.x - 0.7 and player.is_on_floor(), "actual player walks from street through door to interior floor")
	Input.action_press(player.ACTION_BACK)
	await frames(90)
	Input.action_release(player.ACTION_BACK)
	await frames(8)
	check(player.global_position.x > anchor.x + 0.7 and player.is_on_floor(), "actual player returns through public opening to street")
	player.set_physics_process(false)
	player.global_position = anchor
	input_e()
	check(interior.nearest_action(anchor).opening, "occupied close request leaves target open")
	check(world._door_hint.text == "Отойдите от створки двери", "occupied action explains refusal")
	await frames(5)
	check(world._door_hint.text == "Отойдите от створки двери", "occupied feedback remains readable across physics ticks")
	player.global_position = outside
	input_e()
	check(not interior.nearest_action(outside).opening, "clear close request accepted")
	player.global_position = anchor
	await frames(50)
	check(interior.door_fraction("public") > 0.0, "actual occupant entering sweep prevents fully closed leaf")
	player.global_position = outside
	await frames(50)
	check(is_equal_approx(interior.door_fraction("public"), 0.0) and blocked(outside, inside), "removing actual occupant permits solid closed door")
	player.global_position = interior.anchor("doorInside")
	await frames(2)
	check(world._current_door_action().is_empty() and world._door_hint.text.is_empty(), "service staff anchor offers no public E")
	input_e()
	check(is_equal_approx(interior.door_fraction("service"), 0.0), "public input never opens service door")
	if OS.get_cmdline_user_args().has("--benchmark"):
		player.global_position = outside
		benchmark_hook(outside)
	world.free()
	print("PRINTSHOP_MAIN_HOOK_TEST ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "live": false, "fps": false}))
	quit(0 if failures.is_empty() else 1)

func benchmark_hook(outside: Vector3) -> void:
	var result: Dictionary = {"qualification": "64 batches x100 calls; CPU batch-mean microseconds, not frame percentiles or LIVE/FPS; same loaded headless main/player/camera, player physics disabled"}
	for mode: String in ["off", "idle", "moving"]:
		world._printshop = null if mode == "off" else interior
		for i in range(200):
			world._physics_process(0.00001)
		var costs: Array[float] = []
		for batch in range(64):
			if mode == "moving":
				interior.request_door("public", batch % 2 == 0, outside, world._current_door_occupants())
			var started := Time.get_ticks_usec()
			for i in range(100):
				world._physics_process(0.00001)
			costs.append(float(Time.get_ticks_usec() - started) / 100.0)
		costs.sort()
		result[mode] = {"batch_mean_us_p50": costs[31], "batch_mean_us_p95": costs[60]}
	world._printshop = interior
	print("PRINTSHOP_HOOK_CPU ", JSON.stringify(result))
