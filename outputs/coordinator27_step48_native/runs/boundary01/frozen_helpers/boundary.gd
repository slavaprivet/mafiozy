extends SceneTree
## Original32 four lanes plus protected-body/height and receipt regressions.
## Fixtures and player placements are explicit. No production geometry changes.
var player: CharacterBody3D
var world: Node3D
var out := ""
var fixed := true
var errors: Array[String] = []
var rows: Array[Dictionary] = []
var checks := 0
var done := false
var templates: Array[Dictionary] = [
	{"kind":"106mm_static_lip", "height":0.106, "type":"static", "pass_fixed":true},
	{"kind":"120mm_exact_boundary", "height":0.120, "type":"static", "pass_fixed":true},
	{"kind":"210mm_palazzo_height_component", "height":0.210, "type":"static", "pass_fixed":false},
	{"kind":"400mm_wall", "height":0.4, "type":"static", "pass_fixed":false},
	{"kind":"106mm_lip_under_1950mm_ceiling", "height":0.106, "type":"static", "ceiling":true, "pass_fixed":false},
	{"kind":"121mm_step_over_limit", "height":0.121, "type":"static", "pass_fixed":false},
	{"kind":"106mm_rigid_world_layer", "height":0.106, "type":"rigid", "layer":1, "pass_fixed":false},
	{"kind":"106mm_animatable_world_layer", "height":0.106, "type":"animatable", "pass_fixed":false},
	{"kind":"106mm_moving_static_surface", "height":0.106, "type":"conveyor", "pass_fixed":false},
	{"kind":"flat_ordinary_walk", "height":0.0, "type":"none", "pass_fixed":true},
	{"kind":"106mm_controls_disabled", "height":0.106, "type":"static", "controls":false, "pass_fixed":false},
	{"kind":"106mm_external_authority", "height":0.106, "type":"static", "authority":"seat", "pass_fixed":false},
]
var specs: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
		print("FAIL ", label)
func tick(count: int = 1) -> void:
	for index: int in count:
		await physics_frame
		await process_frame
func key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func box(at: Vector3, size: Vector3, kind: String = "static", layer: int = 1) -> PhysicsBody3D:
	var body: PhysicsBody3D
	if kind == "rigid":
		body = RigidBody3D.new()
		body.freeze = true
	elif kind == "animatable":
		body = AnimatableBody3D.new()
	else:
		body = StaticBody3D.new()
		if kind == "conveyor": body.constant_linear_velocity = Vector3(0.1, 0.0, 0.0)
	body.collision_layer = layer
	body.collision_mask = 257 if kind == "rigid" else 1
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.shape = shape
	body.add_child(node)
	world.add_child(body)
	body.global_position = at
	return body
func probe(length: float) -> Dictionary:
	# Read-only32 branch evidence: normals are capsule contact normals at edges.
	var motion := Vector3(0.0, 0.0, -length)
	var hit := KinematicCollision3D.new()
	var frame := player.global_transform
	var result: Dictionary = {"length":length, "horizontal":player.test_move(frame, motion, hit, 0.001, false, 4), "contacts":[]}
	for index: int in hit.get_collision_count():
		result.contacts.append({"normal":hit.get_normal(index), "collider":str(hit.get_collider(index)), "class":hit.get_collider(index).get_class()})
	result.up = player.test_move(frame, Vector3.UP * 0.12, null, 0.001)
	frame.origin.y += 0.12
	result.forward = player.test_move(frame, motion, null, 0.001)
	frame.origin += motion
	var down := KinematicCollision3D.new()
	result.down = player.test_move(frame, Vector3.DOWN * 0.12, down, 0.001, false, 4)
	result.travel = down.get_travel()
	result.down_contacts = []
	for index: int in down.get_collision_count():
		result.down_contacts.append({"normal":down.get_normal(index), "collider":str(down.get_collider(index))})
	return result
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg == "--fixed": fixed = true
	if out.is_empty(): quit(2); return
	create_timer(100).timeout.connect(func():
		if not done:
			check(false,"timeout")
			finish())
	for sprint: bool in [false, true]:
		for template: Dictionary in templates:
			var spec := template.duplicate(true)
			spec["sprint"] = sprint
			specs.append(spec)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	for lane: int in specs.size():
		var spec: Dictionary = specs[lane]
		var x := float(lane) * 6.0
		box(Vector3(x, -0.25, -2.0), Vector3(5.0, 0.5, 15.0))
		var height: float = spec.height
		if height > 0.0:
			box(Vector3(x, height * 0.5, -2.5), Vector3(2.0, height, 5.0), spec.type, int(spec.get("layer", 1)))
		if spec.get("ceiling", false): box(Vector3(x, 2.05, -2.5), Vector3(2.0, 0.2, 5.0))
	player = load("res://scripts/preview_player.gd").new()
	world.add_child(player)
	var ignored := box(Vector3(-10.0, 0.5, 0.0), Vector3.ONE)
	player.add_collision_exception_with(ignored)
	var capsule: CollisionShape3D = player.get_node("PlayerCapsule")
	var shape: CapsuleShape3D = capsule.shape
	var shape_id := shape.get_instance_id()
	var local_frame := capsule.transform
	var floor_angle := player.floor_max_angle
	var snap := player.floor_snap_length
	var margin := player.safe_margin
	var floor_layers := player.platform_floor_layers
	var wall_layers := player.platform_wall_layers
	check(player.collision_mask == 1 and player.collision_layer == 2, "actual48 ordinary capsule filters")
	check(is_equal_approx(shape.height, 1.9) and is_equal_approx(shape.radius, 0.3), "actual accepted capsule dimensions")
	for lane: int in specs.size():
		var spec: Dictionary = specs[lane]
		key(false)
		Input.action_release(player.ACTION_RUN)
		player._pose_authority = &"on_foot"
		player.global_position = Vector3(float(lane) * 6.0, 0.03, 1.2)
		player.velocity = Vector3.ZERO
		player._free_mouse_look = true
		player._camera_yaw = 0.0
		await tick(20)
		check(player.is_on_floor(), "lane grounded " + str(lane))
		var start := player.global_position
		if spec.sprint: Input.action_press(player.ACTION_RUN)
		player._free_mouse_look = spec.get("controls", true)
		player._pose_authority = StringName(spec.get("authority", "on_foot"))
		var immobile: bool = not spec.get("controls", true) or spec.has("authority")
		var start_serial: int = player._ground_move_serial
		var samples: Array[Dictionary] = []
		var tick_rows: Array[Dictionary] = []
		var helper_positive := 0
		var previous_position := player.global_position
		var previous_serial: int = player._ground_move_serial
		var single_native := true
		var filters_stable := true
		var excessive_motion_rejected := true
		var max_y := start.y
		var receipt_equal := true
		key(true)
		for index: int in 90:
			await tick()
			max_y = maxf(max_y, player.global_position.y)
			var actual_delta := player.global_position - previous_position
			if not spec.has("authority"):
				single_native = single_native and player._ground_move_serial == previous_serial + 1 and actual_delta.is_equal_approx(player.get_position_delta())
			else: single_native = single_native and player._ground_move_serial == previous_serial and actual_delta.is_zero_approx()
			filters_stable = filters_stable and capsule.shape.get_instance_id() == shape_id and capsule.transform == local_frame and player.collision_mask == 1 and player.collision_layer == 2 and player.platform_floor_layers == floor_layers and player.platform_wall_layers == wall_layers
			var rise: float = player._small_static_step_rise(Vector3(0,0,-(player.run_speed if spec.sprint else player.walk_speed)/60.0))
			if rise > 0.0: helper_positive += 1
			excessive_motion_rejected = excessive_motion_rejected and player._small_static_step_rise(Vector3(0,0,-0.12001)) == 0.0
			tick_rows.append({"frame":Engine.get_physics_frames(),"x":player.position.x,"y":player.position.y,"z":player.position.z,"delta":actual_delta,"native_delta":player.get_position_delta(),"serial":player._ground_move_serial,"helper_rise":rise,"slide_count":player.get_slide_collision_count()})
			previous_position = player.global_position
			previous_serial = player._ground_move_serial
			receipt_equal = receipt_equal and player.get_position_delta().is_equal_approx(player._ground_move_end - player._ground_move_start)
			if index % 10 == 0:
				samples.append({"tick":index, "position":player.global_position, "floor":player.is_on_floor(), "velocity":player.velocity})
		key(false)
		await tick(15)
		var end := player.global_position
		var should_pass: bool = spec.type == "none" or (fixed and spec.pass_fixed)
		check(start.distance_to(end) < 0.002 if immobile else start.z - end.z > 0.7, "ordinary native W reaches obstacle " + str(lane))
		check(end.z < -1.0 if should_pass else end.z > 0.05, "passage and protected blocker " + str(lane))
		check(player._jump.is_empty() and not Input.is_action_pressed(player.ACTION_JUMP), "no jump " + str(lane))
		check(capsule.shape.get_instance_id() == shape_id and capsule.transform == local_frame and player.collision_mask == 1 and player.collision_layer == 2, "original capsule and filter retained " + str(lane))
		check(player.floor_max_angle == floor_angle and player.floor_snap_length == snap and player.safe_margin == margin and player.get_collision_exceptions().has(ignored), "floor policy and exceptions retained " + str(lane))
		check(receipt_equal if not spec.has("authority") else single_native, "single native displacement equals complete movement receipt " + str(lane))
		check(max_y - start.y <= 0.123, "bounded vertical rise " + str(lane))
		check(single_native, "per-tick serial and native displacement " + str(lane))
		check(filters_stable, "per-tick filter and shape invariants " + str(lane))
		check(excessive_motion_rejected, "motion greater than120mm rejected " + str(lane))
		rows.append({"speed":5.8 if spec.sprint else 3.2, "start_serial":start_serial,"end_serial":player._ground_move_serial,"helper_positive":helper_positive,"start_z":start.z,"end_z":end.z,"height":spec.height,"native_ticks":tick_rows,"lane":lane, "kind":spec.kind, "start":start, "end":end, "max_y":max_y, "samples":samples, "probes":[probe(0.005),probe(0.06),probe(0.12)] if lane == 0 else []})
	finish()
func finish() -> void:
	if done: return
	done = true
	key(false)
	Input.action_release(player.ACTION_RUN)
	var result: Dictionary = {"passed":errors.is_empty(), "checks":checks, "errors":errors, "fixed":fixed, "cases":rows, "fixture":"Accepted48 exact486 source copy with sole exact historical step33 player patch. Isolated artificial lane component; actual preview_player, original default capsule/layer2/mask1/platform policy, native W events, both speeds. One explicit setup placement per lane. Not Palazzo passage, corpse owner, Q menu, graphical or performance acceptance.", "performance_acceptance":false}
	FileAccess.open(out.path_join("RESULT.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("LIP_RESULT ", JSON.stringify(result))
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
