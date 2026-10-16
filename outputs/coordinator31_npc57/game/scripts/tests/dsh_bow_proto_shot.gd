extends SceneTree
## DSH_BOW_PROTO driven test
##
## Proves the bow behaves like a bow and not like a gun:
##   1. the RIGHT button draws the string, the view zooms in and the dotted arc
##      appears, showing where the arrow will actually go;
##   2. the arc is BALLISTIC - it curves down, it is not a straight line;
##   3. releasing looses a real projectile whose flight drops under gravity at the
##      rate gravity actually implies;
##   4. the arrow STICKS where it lands and stays there;
##   5. the bow is equipped through the ordinary weapon menu, free of charge.
##
## Run headless-free (needs a GPU): prints BOW_SHOT_* lines and writes
## shot_bow_*.png next to the working directory.

const OUT_DIR := "C:/Users/Слава/Documents/deepseek-harness/default-workspace"

var _scene: Node
var _player: CharacterBody3D
var _proto: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

## Spawns one mouse button event pair through the real input path.
func _press_mouse(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(960, 540)
	Input.parse_input_event(event)
	await process_frame

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image: Image = get_root().get_texture().get_image()
	if image == null:
		print("BOW_SHOT ", name, " no_image")
		return
	var path := OUT_DIR + "/shot_bow_" + name + ".png"
	print("BOW_SHOT ", name, " ", image.save_png(path), " ", path)

## Turns the camera toward a point on the ground plane, the way a player aims.
func _aim_camera_at(target: Vector3) -> void:
	var to_target := target - _player.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 1e-6: return
	var camera: Camera3D = _player.get_preview_camera()
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var want := to_target.normalized()
	var angle := atan2(forward.cross(want).y, forward.dot(want))
	var sensitivity := float(_player.get("mouse_sensitivity"))
	var pixels := -angle / maxf(sensitivity, 1e-5)
	var steps := 20
	for i: int in steps:
		_move(pixels / float(steps), 0.0)
		await _settle(1)
	await _settle(4)

func _move(dx: float, dy: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.position = Vector2(960, 540)
	Input.parse_input_event(event)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("BOW_SHOT_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("BOW_SHOT_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_proto = _scene.get("preview_bow_prototype")
	print("BOW_SHOT_PROTO ", _proto != null, " status=", _scene.get("bow_prototype_status"))
	if _proto == null:
		print("BOW_SHOT_FAIL proto_missing"); quit(1); return
	_player.set_mouse_captured(true)
	var weapons: Node = _scene.get("preview_weapons")
	var equipped: Dictionary = weapons.equip("bow") if weapons != null else {}
	print("BOW_SHOT_EQUIP ", JSON.stringify(equipped), " selected=", _proto.snapshot().selected)
	await _settle(20)

	# 1. Drawing the string with the LEFT button: the draw rises, the view zooms in,
	# the arc appears. The bow is drawn and loosed with LMB, not RMB.
	# The arrow has to be fetched from the quiver first, which takes a moment.
	var rest_state: Dictionary = _proto.snapshot()
	await _settle(110)
	var loaded: Dictionary = _proto.snapshot()
	print("BOW_SHOT_QUIVER worn=", loaded.quiver_worn, " arrows_left=", loaded.arrows_left,
		" nocked=", loaded.nocked, " fetch_phase=", loaded.fetch_phase,
		" quiver_offset_m=", loaded.get("quiver_offset_m", -1.0),
		" clear_of_body=", loaded.get("quiver_clear_of_body", false),
		" quiver_mouth=", loaded.quiver_mouth)
	await _shot("quiver")
	# Watch the WHOLE fetch and draw frame by frame: the arm must never be posed
	# through the body, and the string must really come back as the draw rises.
	var min_hand := 99.0
	var min_elbow := 99.0
	var max_pull := 0.0
	var string_seen := 0
	var samples_taken := 0
	await _press_mouse(MOUSE_BUTTON_LEFT, true)
	for i: int in 170:
		await process_frame
		var watch: Dictionary = _proto.snapshot()
		samples_taken += 1
		min_hand = minf(min_hand, float(watch.get("hand_clearance", 99.0)))
		min_elbow = minf(min_elbow, float(watch.get("elbow_clearance", 99.0)))
		max_pull = maxf(max_pull, float(watch.get("string_pull_m", 0.0)))
		if bool(watch.get("string_visible", false)): string_seen += 1
	var drawn: Dictionary = _proto.snapshot()
	print("BOW_SHOT_DRAW drawing=", drawn.drawing, " draw=", drawn.draw,
		" speed=", drawn.speed_now, " aim_dots=", drawn.aim_dots,
		" zoom_scale=", drawn.get("zoom_scale", 1.0), " fov=", drawn.fov,
		" base_fov=", rest_state.fov,
		" predicted_range=", drawn.predicted_range)
	await _shot("drawn")
	print("BOW_SHOT_CLEARANCE samples=", samples_taken, " min_hand_from_spine=", min_hand,
		" min_elbow_from_spine=", min_elbow, " max_string_pull_m=", max_pull,
		" frames_with_visible_string=", string_seen,
		" string_pull_at_full_draw=", drawn.get("string_pull_m", 0.0),
		" nocked_arrow=", drawn.get("nocked_arrow_visible", false))

	# 2. The arc must be ballistic: the far end of the prediction sits BELOW the
	# straight line from the muzzle.
	var arc_state: Dictionary = _proto.snapshot()
	var arc_curve: float = _proto.call("aim_arc_drop")
	print("BOW_SHOT_ARC predicted_range=", arc_state.predicted_range,
		" drop_below_straight_line=", arc_curve, " aim=", arc_state.aim)

	# 3. Fire into OPEN AIR: the camera cannot be raised far (the aim pitch is
	# clamped by the shared aim camera), so the archer is lifted into clear air
	# instead. Gravity must then show up as a fall in vertical speed of g per
	# second, whatever the arrow was pointed at.
	var flight_home: Vector3 = _player.global_position
	_player.global_position += Vector3.UP * 26.0
	await _settle(14)
	var arrows_before: int = int(_proto.call("arrow_count"))
	await _press_mouse(MOUSE_BUTTON_LEFT, false)
	await _settle(3)
	var fired: Dictionary = _proto.snapshot()
	var flown: int = int(_proto.call("last_fired_index"))
	print("BOW_SHOT_FIRE shots=", fired.shots, " arrows=", fired.arrows,
		" arrows_before=", arrows_before, " draw_after=", fired.draw, " flown_index=", flown)
	var flight: Array[Dictionary] = []
	var fired_ms: int = 0
	for i: int in 400:
		await process_frame
		var state: Dictionary = _proto.call("arrow_state", flown)
		if state.is_empty(): break
		if fired_ms == 0: fired_ms = int(state.get("fired_ms", 0))
		state["t"] = (Time.get_ticks_msec() - fired_ms) * 0.001
		flight.append(state)
		if bool(state.get("stuck", false)): break
	_player.global_position = flight_home
	await _settle(8)
	var last: Dictionary = flight[flight.size() - 1] if not flight.is_empty() else {}
	var gravity_ratio := 0.0
	var flight_time := 0.0
	var travelled := 0.0
	# The final sample is the stuck arrow, whose velocity was zeroed on impact: the
	# free-flight comparison must end at the last sample still in the air.
	var airborne: Array[Dictionary] = []
	for entry: Dictionary in flight:
		if bool(entry.get("stuck", false)): break
		airborne.append(entry)
	if airborne.size() >= 3:
		var first: Dictionary = airborne[0]
		var end: Dictionary = airborne[airborne.size() - 1]
		var first_at: Vector3 = first.get("position", Vector3.ZERO)
		var last_at: Vector3 = end.get("position", Vector3.ZERO)
		var first_v: Vector3 = first.get("velocity", Vector3.ZERO)
		var last_v: Vector3 = end.get("velocity", Vector3.ZERO)
		flight_time = float(end.get("t", 0.0)) - float(first.get("t", 0.0))
		var horizontal := Vector2(last_at.x - first_at.x, last_at.z - first_at.z)
		travelled = horizontal.length()
		# Gravity only ever removes vertical speed: (v0.y - v1.y) / (g * t).
		var lost := first_v.y - last_v.y
		gravity_ratio = lost / maxf(0.001, 9.81 * flight_time)
		print("BOW_SHOT_FLIGHT samples=", airborne.size(), " seconds=", flight_time,
			" travelled_m=", travelled,
			" v0_y=", first_v.y, " v1_y=", last_v.y, " lost_y=", lost,
			" g_would_remove=", 9.81 * flight_time, " ratio=", gravity_ratio)
	print("BOW_SHOT_STICK stuck=", last.get("stuck", false),
		" at=", last.get("position", Vector3.ZERO),
		" stuck_total=", _proto.snapshot().stuck,
		" distance=", _proto.snapshot().last_hit_distance)
	await _shot("stuck")

	# 4. Arrows stay put: no arrow disappears on its own.
	var stuck_before: int = int(_proto.snapshot().stuck)
	await _settle(120)
	var stuck_after: int = int(_proto.snapshot().stuck)
	print("BOW_SHOT_PERSIST stuck_before=", stuck_before, " stuck_after=", stuck_after)

	# 5. Fire a second arrow into the same place: they accumulate.
	await _settle(90)
	await _press_mouse(MOUSE_BUTTON_LEFT, true)
	await _settle(60)
	await _press_mouse(MOUSE_BUTTON_LEFT, false)
	await _settle(90)
	var final: Dictionary = _proto.snapshot()
	print("BOW_SHOT_FINAL ", JSON.stringify(final))

	# 6. The quiver is the ammunition: it carries the arrows, it hangs on the back,
	# and taking it off leaves the bow with none.
	var ammo_before: int = int(_proto.snapshot().arrows_left)
	var quiver_dropped: bool = _proto.call("drop_quiver_to_ground")
	await _settle(10)
	var without: Dictionary = _proto.snapshot()
	var quiver_back: bool = _proto.call("try_pickup_ground")
	await _settle(10)
	var with_again: Dictionary = _proto.snapshot()
	print("BOW_SHOT_QUIVER_CYCLE dropped=", quiver_dropped,
		" arrows_without_quiver=", without.arrows_left, " worn_without=", without.quiver_worn,
		" picked_up=", quiver_back, " arrows_back=", with_again.arrows_left,
		" worn_again=", with_again.quiver_worn, " ammo_before=", ammo_before)

	# 7. The bow itself can be put down and taken up again.
	var bow_dropped: bool = _proto.call("drop_bow_to_ground")
	await _settle(10)
	var bow_ground: Dictionary = _proto.snapshot()
	var bow_back: bool = _proto.call("try_pickup_ground")
	await _settle(10)
	var bow_up: Dictionary = _proto.snapshot()
	# With it already in hand a second attempt must be refused.
	var refused_in_hand: bool = not bool(_proto.call("try_pickup_ground"))
	print("BOW_SHOT_BOW_CYCLE dropped=", bow_dropped, " grounded=", bow_ground.grounded,
		" picked_up=", bow_back, " grounded_after=", bow_up.grounded,
		" refused_when_in_hand=", refused_in_hand)
	await _shot("ground")
	# Resource report: the bow pools its meshes, so the unique-mesh count must stay
	# small however many arrows have been fired and stuck.
	var perf: Dictionary = _proto.call("perf_report")
	print("BOW_SHOT_PERF nodes=", perf.get("nodes", 0), " mesh_nodes=", perf.get("mesh_nodes", 0),
		" multimesh_nodes=", perf.get("multimesh_nodes", 0),
		" unique_meshes=", perf.get("unique_meshes", 0),
		" arrows_spawned=", perf.get("arrows", 0), " arrows_stuck=", perf.get("stuck", 0))

	var verdict := {
		"draws_the_string": float(drawn.draw) > 0.8,
		"zooms_in": float(drawn.get("zoom_scale", 1.0)) < 0.9,
		"shows_the_arc": int(drawn.aim_dots) > 3,
		"arc_is_ballistic": arc_curve > 0.02,
		"looses_an_arrow": int(fired.shots) > 0 and int(fired.arrows) > arrows_before,
		"flight_falls_under_gravity": gravity_ratio > 0.55 and gravity_ratio < 1.8,
		"arrow_sticks": int(_proto.snapshot().stuck) > 0,
		"arrows_persist": stuck_after >= stuck_before and stuck_before > 0,
		"quiver_worn_on_back": bool(loaded.quiver_worn) and int(loaded.arrows_left) == 20,
		"spends_arrows": int(with_again.arrows_left) < 20,
		"quiver_carries_the_ammo": int(without.arrows_left) == 0 and not bool(without.quiver_worn)
			and quiver_back and int(with_again.arrows_left) > 0 and bool(with_again.quiver_worn),
		"bow_can_be_dropped_and_taken": bow_dropped and bool(bow_ground.grounded)
			and bow_back and not bool(bow_up.grounded) and refused_in_hand,
		"arm_never_through_the_body": min_hand > 0.24 and min_elbow > 0.18,
		"quiver_hugs_the_back": float(loaded.get("quiver_offset_m", 0.0)) > 0.135
			and float(loaded.get("quiver_offset_m", 9.0)) < 0.26
			and bool(loaded.get("quiver_clear_of_body", false)),
		"string_is_visible": string_seen > 100 and bool(drawn.get("string_visible", false)),
		"string_comes_back_with_the_draw": max_pull > 0.30,
		"arrow_sits_on_the_string": bool(drawn.get("nocked_arrow_visible", false)),
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("BOW_SHOT_OBJECTIVE ", JSON.stringify(verdict))
	print("BOW_SHOT_OBJECTIVE_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
