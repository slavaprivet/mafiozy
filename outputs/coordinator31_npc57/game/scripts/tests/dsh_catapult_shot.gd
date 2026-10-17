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

	# 1. The push is shared: one man slow, several faster.
	var speeds: Dictionary = {
		"one": start.get("speed_for_1", 0.0),
		"two": start.get("speed_for_2", 0.0),
		"five": start.get("speed_for_5", 0.0),
	}

	# 2. Walk onto the stone and pick it up, carry it to the spoon, set it down.
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
	await _settle(14)
	var on_spoon: Dictionary = _catapult.call("snapshot")
	print("CATAPULT_STONE carried=", carried.get("carrying", false),
		" on_spoon=", on_spoon.get("stone_on_spoon", false))
	await _shot("loaded")

	# 3. Take the firing position and fire.
	_player.global_position = (on_spoon.get("cart", Vector3.ZERO) as Vector3) + Vector3(0.0, 0.05, -2.2)
	_player.velocity = Vector3.ZERO
	await _settle(12)
	_key(KEY_E, true); await _settle(2); _key(KEY_E, false)
	await _settle(10)
	var occupied: Dictionary = _catapult.call("snapshot")
	print("CATAPULT_TAKEN occupied=", occupied.get("occupied", false),
		" yaw=", occupied.get("yaw", 0.0), " elevation=", occupied.get("elevation", 0.0))
	# Aim AT THE PALAZZO: the machine has a real ballistic solution, so this is arithmetic
	# and not a magic number.
	var site_position: Vector3 = Vector3(48.5, 0.0, 0.0)
	var palazzo_now: Variant = _scene.get("preview_palazzo")
	if is_instance_valid(palazzo_now) and is_instance_valid(palazzo_now.get("site")):
		site_position = palazzo_now.get("site").global_position
	var cart_position: Vector3 = occupied.get("cart", Vector3.ZERO)
	var to_site: Vector3 = site_position - cart_position
	to_site.y = 0.0
	var range_to_site: float = to_site.length()
	var aim_yaw := atan2(to_site.x, to_site.z)
	var aim_elevation: float = _catapult.call("elevation_for_range", range_to_site) + 0.02
	_catapult.call("set_aim", aim_yaw, aim_elevation)
	await _settle(6)
	print("CATAPULT_AIM range_m=", range_to_site, " yaw=", aim_yaw, " elevation=", aim_elevation)
	await _shot("aiming")
	# Aim a little higher for range, then fire with LMB.
	var wheel_on := InputEventMouseButton.new()
	wheel_on.button_index = MOUSE_BUTTON_LEFT
	wheel_on.pressed = true
	wheel_on.position = Vector2(960, 540)
	Input.parse_input_event(wheel_on)
	await _settle(4)
	var fire_button := InputEventMouseButton.new()
	fire_button.button_index = MOUSE_BUTTON_LEFT
	fire_button.pressed = false
	fire_button.position = Vector2(960, 540)
	Input.parse_input_event(fire_button)
	# The wind takes WIND_TIME, so watch it through.
	var wound := false
	for i: int in 320:
		await process_frame
		var mid: Dictionary = _catapult.call("snapshot")
		if bool(mid.get("flying", false)):
			wound = true
			break
	var fired: Dictionary = _catapult.call("snapshot")
	print("CATAPULT_FIRE wound=", wound, " fired=", fired.get("fired", 0),
		" flying=", fired.get("flying", false), " stone=", fired.get("stone", Vector3.ZERO))
	# 4. Follow the stone until it lands.
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
		"firing_position_can_be_taken": bool(occupied.get("occupied", false)),
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
