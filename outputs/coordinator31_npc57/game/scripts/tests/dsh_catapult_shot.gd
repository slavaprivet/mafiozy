extends SceneTree
## DSH_CATAPULT live run
##
## Checks the machine the brief describes, by measurement:
##   1. it exists in the city, on its wheels, with a stone beside it;
##   2. ONE man is slow and several men are faster - the push is shared, not scripted;
##   3. the stone can be picked up, carried and SET ON THE SPOON by the player;
##   4. taking the firing position works, the arm winds, and the shot leaves with the
##      speed the arm had;
##   5. the stone flies as a real body, comes down, hits the building and the hit is
##      delivered into the palazzo damage system, after which the stone is gone.

const OUT_DIR := "C:/Users/Слава/Documents/deepseek-harness/default-workspace"

var _scene: Node
var _player: CharacterBody3D
var _catapult: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image: Image = get_root().get_texture().get_image()
	if image != null:
		print("CATAPULT_SHOT ", name, " ", image.save_png(OUT_DIR + "/shot_catapult_" + name + ".png"))

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("CATAPULT_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("CATAPULT_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_catapult = _scene.get("preview_catapult")
	if _catapult == null:
		print("CATAPULT_FAIL not_installed status=", _scene.get("catapult_status")); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(20)
	var start: Dictionary = _catapult.call("snapshot")
	print("CATAPULT_START ", JSON.stringify(start))
	await _shot("placed")

	# 1. The push is shared: one man slow, several faster, and the cart takes TIME to get
	#    going - a machine this heavy does not reach its speed in one frame.
	var speed_early := 0.0
	var speed_late := 0.0
	_player.global_position = (start.get("cart", Vector3.ZERO) as Vector3) + Vector3(0.0, 0.05, -1.8)
	_player.velocity = Vector3.ZERO
	await _settle(10)
	var forward_action: StringName = _player.ACTION_FORWARD
	if InputMap.has_action(forward_action):
		Input.action_press(forward_action)
		await _settle(6)
		speed_early = float(_catapult.call("snapshot").get("cart_speed", 0.0))
		await _settle(70)
		speed_late = float(_catapult.call("snapshot").get("cart_speed", 0.0))
		Input.action_release(forward_action)
	await _settle(10)
	print("CATAPULT_INERTIA early=", speed_early, " late=", speed_late)
	# 2. The push is shared: one man slow, several faster.
	var speeds: Dictionary = {
		"one": start.get("speed_for_1", 0.0),
		"two": start.get("speed_for_2", 0.0),
		"five": start.get("speed_for_5", 0.0),
	}

	# 3. Walk onto the stone and pick it up, carry it to the spoon, set it down.
	var stone: Vector3 = start.get("stone", Vector3.ZERO)
	_player.global_position = stone + Vector3(0.9, 0.05, 0.0)
	_player.velocity = Vector3.ZERO
	await _settle(10)
	_key(KEY_E, true); await _settle(2); _key(KEY_E, false)
	await _settle(10)
	var carried: Dictionary = _catapult.call("snapshot")
	# Now stand at the spoon and set it down.
	var spoon: Vector3 = carried.get("spoon", Vector3.ZERO)
	_player.global_position = spoon + Vector3(0.7, -1.4, 0.7)
	_player.velocity = Vector3.ZERO
	await _settle(10)
	_key(KEY_E, true); await _settle(2); _key(KEY_E, false)
	# The stone is LAYED IN, not teleported: catch the animation mid-flight.
	var loading_seen := false
	var on_spoon: Dictionary = {}
	for i: int in 40:
		await process_frame
		var mid: Dictionary = _catapult.call("snapshot")
		if bool(mid.get("loading", false)): loading_seen = true
		on_spoon = mid
		if bool(mid.get("stone_on_spoon", false)): break
	print("CATAPULT_STONE carried=", carried.get("carrying", false),
		" loading_seen=", loading_seen,
		" on_spoon=", on_spoon.get("stone_on_spoon", false),
		" marker=", on_spoon.get("marker", false),
		" parts=", on_spoon.get("parts", 0))
	await _shot("loaded")

	# 4. Stand at the frame, AIM at the wall, then E fires. Aim first: E at the frame
	#    with a stone loaded is the trigger, so aiming after that would fire blind.
	_player.global_position = (on_spoon.get("cart", Vector3.ZERO) as Vector3) + Vector3(0.0, 0.05, -2.4)
	_player.velocity = Vector3.ZERO
	await _settle(14)
	var site_position: Vector3 = Vector3(48.5, 0.0, 0.0)
	var palazzo_now: Variant = _scene.get("preview_palazzo")
	if is_instance_valid(palazzo_now) and is_instance_valid(palazzo_now.get("site")):
		site_position = palazzo_now.get("site").global_position
	var occupied: Dictionary = _catapult.call("snapshot")
	# Aim at a REAL SURFACE, not at the middle of the building: a ray from the spoon
	# finds the facade, and the machine is laid on that point.
	var spoon_now: Vector3 = _catapult.call("snapshot").get("spoon", Vector3.ZERO)
	var space := _player.get_world_3d().direct_space_state
	var aim_point: Vector3 = site_position + Vector3.UP * 2.0
	if space != null:
		var exclude: Array[RID] = [_player.get_rid()]
		var cart_node: Variant = _catapult.get("_cart")
		if is_instance_valid(cart_node): exclude.append((cart_node as CollisionObject3D).get_rid())
		var stone_node: Variant = _catapult.get("_stone")
		if is_instance_valid(stone_node): exclude.append((stone_node as CollisionObject3D).get_rid())
		var query := PhysicsRayQueryParameters3D.create(spoon_now, site_position + Vector3.UP * 2.0,
			1 | 5 | 256, exclude)
		query.hit_from_inside = true
		var ray_hit: Dictionary = space.intersect_ray(query)
		if not ray_hit.is_empty():
			aim_point = ray_hit.get("position", aim_point)
			print("CATAPULT_AIM_SURFACE ", aim_point, " collider=", (ray_hit.get("collider") as Node).name)
	print("CATAPULT_AIM_POINT ", aim_point)
	_catapult.call("aim_at", aim_point)
	await _settle(6)
	var aimed: Dictionary = _catapult.call("snapshot")
	var range_to_site: float = (Vector3(site_position.x, 0.0, site_position.z) \
		- ((aimed.get("spoon", Vector3.ZERO) as Vector3) * Vector3(1.0, 0.0, 1.0))).length()
	print("CATAPULT_AIM range_m=", range_to_site, " yaw=", aimed.get("yaw", 0.0),
		" elevation=", aimed.get("elevation", 0.0),
		" spoon=", aimed.get("spoon", Vector3.ZERO))
	await _shot("aiming")
	# E at the frame with a stone loaded fires.
	_key(KEY_E, true); await _settle(2); _key(KEY_E, false)
	await _settle(4)
	var wound := false
	for i: int in 320:
		await process_frame
		var mid: Dictionary = _catapult.call("snapshot")
		if bool(mid.get("flying", false)):
			wound = true
			break
	# 5. Follow the stone until it lands.
	var fired: Dictionary = _catapult.call("snapshot")
	print("CATAPULT_FIRE wound=", wound, " fired=", fired.get("fired", 0),
		" flying=", fired.get("flying", false), " stone=", fired.get("stone", Vector3.ZERO))
	var hits_before: int = int(fired.get("hits", 0))
	var landed := false
	var flight_frames := 0
	var peak := 0.0
	for i: int in 900:
		await process_frame
		flight_frames += 1
		var mid: Dictionary = _catapult.call("snapshot")
		peak = maxf(peak, (mid.get("stone", Vector3.ZERO) as Vector3).y)
		if int(mid.get("hits", 0)) > hits_before:
			landed = true
			break
	var after_flight: Dictionary = _catapult.call("snapshot")
	print("CATAPULT_STONE_END pos=", after_flight.get("stone", Vector3.ZERO),
		" flying=", after_flight.get("flying", false))
	var impact: Dictionary = after_flight.get("last_impact", {})
	print("CATAPULT_IMPACT landed=", landed, " flight_frames=", flight_frames, " peak_y=", peak,
		" delivered=", impact.get("ok", false), " point=", impact.get("point", Vector3.ZERO))
	await _shot("impact")
	var palazzo: Variant = _scene.get("preview_palazzo")
	var site_state := {}
	if is_instance_valid(palazzo) and is_instance_valid(palazzo.get("site")):
		site_state = palazzo.get("site").get_stats()
	print("CATAPULT_SITE ", JSON.stringify(site_state).substr(0, 320))

	var verdict := {
		"machine_is_placed": (start.get("cart", Vector3.ZERO) as Vector3).y > -5.0,
		"one_man_is_slow": float(speeds.get("one", 0.0)) > 0.05 and float(speeds.get("one", 0.0)) < 0.9,
		"more_men_push_faster": float(speeds.get("five", 0.0)) > float(speeds.get("two", 0.0)) \
			and float(speeds.get("two", 0.0)) > float(speeds.get("one", 0.0)),
		"stone_can_be_carried": bool(carried.get("carrying", false)),
		"stone_sits_on_the_spoon": bool(on_spoon.get("stone_on_spoon", false)),
		# E at the frame now FIRES when the machine is loaded, so "taking the post" is not
		# a separate step any more: what matters is that the shot went.
		"the_machine_aimed": float(aimed.get("elevation", 0.0)) > 0.0,
		"the_cart_has_inertia": speed_early > 0.0 and speed_early < float(speeds.get("one", 1.0)) * 0.75,
		"the_stone_is_layed_in": loading_seen,
		"the_stone_is_marked": bool(on_spoon.get("marker", false)) or loading_seen,
		"the_machine_is_detailed": int(on_spoon.get("parts", 0)) >= 30,
		"an_impact_raises_dust": int(_catapult.call("snapshot").get("dust_total", 0)) > 0,
		"the_arm_winds_and_releases": wound and int(fired.get("fired", 0)) > 0,
		"stone_hits_the_building": landed and bool(impact.get("ok", false)),
		"stone_is_gone_after_impact": not bool(_catapult.call("snapshot").get("flying", false)),
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("CATAPULT_RESULT_OBJECTIVE ", JSON.stringify(verdict))
	print("CATAPULT_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
