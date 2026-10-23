extends SceneTree
## SHIP61 battle probe (agent E / QA).
##
## Boots the castle scene exactly like the game does, takes the ship battle host
## from `preview_ship`, validates the host snapshot contract and walks the public
## gameplay scenario: sails, helm, ammo, gun, wall hit, flooding.
##
## The host belongs to the integrator and may not exist yet: in that case the probe
## prints SHIP61_BATTLE_MISSING_HOST and exits with code 2, which is not a failure.
## Missing optional methods are reported as SKIP; present methods that misbehave
## are reported as FAIL.
##
## Run:
##   & '...\Godot_v4.7.2-stable_win64.exe' --path '...\game' --headless `
##     --script res://scripts/tests/ship61_battle_probe.gd

const LOAD_DEADLINE_MS := 240000
const HOST_WAIT_MS := 20000

var _scene: Node = null
var _castle: Node = null
var _host: Node = null

var _checks := 0
var _passes := 0
var _failures: Array[String] = []
var _skips: Array[String] = []
var _host_api: Array[String] = []

func _initialize() -> void:
	_run()

func _run() -> void:
	print("SHIP61_BATTLE_PROBE_START")
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHIP61_BATTLE_FAIL scene_missing")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + LOAD_DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true:
			break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("SHIP61_BATTLE_FAIL preview_ready_timeout")
		quit(1)
		return
	_castle = _scene.get("preview_castle")
	print("SHIP61_BATTLE_READY castle=", _castle != null)

	# The integrator installs the host next to the other preview owners. A late
	# install is allowed, but the probe must not spin here for minutes.
	var host_deadline := Time.get_ticks_msec() + HOST_WAIT_MS
	while Time.get_ticks_msec() < host_deadline:
		_host = _scene.get("preview_ship")
		if is_instance_valid(_host):
			break
		await process_frame
	if not is_instance_valid(_host):
		print("SHIP61_BATTLE_MISSING_HOST status=", str(_scene.get("ship_status")))
		quit(2)
		return
	print("SHIP61_BATTLE_HOST name=", str(_host.name), " script=", _script_path(_host))
	_collect_api()
	# Integration aid: report the host surface without running the long scenario.
	if OS.get_cmdline_user_args().has("--status-only"):
		var probe_state: Dictionary = _snapshot()
		print("SHIP61_BATTLE_STATUS_ONLY api=", JSON.stringify(_host_api),
			" snapshot_keys=", JSON.stringify(probe_state.keys()))
		quit(0)
		return

	# ---------------------------------------------------------- snapshot keys
	var snapshot: Dictionary = _snapshot()
	_check("snapshot_not_empty", not snapshot.is_empty(), "snapshot()")
	for key: String in ["water", "ship", "cannons", "hud"]:
		_check("snapshot.%s" % key, snapshot.has(key),
			_type_of(snapshot.get(key)))
	var ship: Dictionary = _sub(snapshot, ["ship"])
	if ship.is_empty():
		_check("snapshot.ship.dictionary", false, "ship is not a Dictionary")
	else:
		for key: String in ["speed", "flooding", "integrity", "position"]:
			_check("snapshot.ship.%s" % key, ship.has(key), _type_of(ship.get(key)))
	var cannons_snapshot: Dictionary = _sub(snapshot, ["cannons"])
	if not cannons_snapshot.is_empty():
		print("SHIP61_BATTLE_CANNON_KEYS ", JSON.stringify(cannons_snapshot.keys()))

	# The HUD is ours; prove the host wired it and that it survives a real state.
	_check_hud(snapshot)

	# ---------------------------------------------------------- sails open
	var interacted: Dictionary = _call_on(_host, ["interact"], ["ship_sail"])
	if not interacted.get("ok", false):
		_skip("interact", "host has no interact(owner)")
	else:
		_check("interact.ship_sail.open", bool(interacted.get("result", false)), "returned false")
		await _wait(0.6)
		var open: Variant = _ship_value(["sails_open", "sails"])
		if open == null:
			_skip("sails_open", "boat exposes neither sails_open() nor snapshot field")
		else:
			_check("sails_open", _as_bool(open), str(open))
		await _wait(5.0)
		var speed_open: Variant = _ship_float(["speed"])
		if speed_open == null:
			_skip("speed", "no speed() / snapshot.ship.speed")
		else:
			_check("speed_after_5s_sails_open", float(speed_open) > 1.0, "%.2f m/s" % float(speed_open))
			print("SHIP61_BATTLE_SPEED_OPEN mps=%.2f knots=%.2f" % [float(speed_open), float(speed_open) * 1.944])

		# Steering is only meaningful while the ship has way on: test it before
		# furling the sails, then continue with the contract's stop check.
		var helm: Dictionary = _call_on(_host, ["interact"], ["ship_helm"])
		if not helm.get("ok", false):
			_skip("interact.ship_helm", "host has no interact(owner)")
		else:
			_check("interact.ship_helm", bool(helm.get("result", false)), "returned false")
			var heading_before: Variant = _ship_value(["heading"])
			# The live host reads the helm keys directly, so press D the same way a
			# player would; the direct steer() call below is the headless fallback.
			_press_key(KEY_D, true)
			await _wait(2.6)
			_press_key(KEY_D, false)
			var heading_after: Variant = _ship_value(["heading"])
			if heading_before == null or heading_after == null:
				_skip("heading", "no heading() / snapshot.ship.heading")
			else:
				var delta := _angle_delta(float(heading_after), float(heading_before))
				if absf(delta) <= 0.03:
					# No key state in this headless run: leave the helm and turn the
					# rudder through the public host method instead.
					_call_on(_host, ["interact"], ["ship_helm"])
					_call_on(_host, ["steer"], [1.0])
					await _wait(2.0)
					var heading_fallback: Variant = _ship_value(["heading"])
					if heading_fallback != null:
						delta = _angle_delta(float(heading_fallback), float(heading_before))
					print("SHIP61_NOTE helm_keys_unavailable_direct_steer_used")
				_check("heading_changed", absf(delta) > 0.03, "delta=%.4f" % delta)
			_call_on(_host, ["steer"], [0.0])
			_call_on(_ship_target("boat"), ["steer"], [0.0])
		print("SHIP61_NOTE helm_was_tested_underway")

	# ---------------------------------------------------------- sails closed
	var furled: Dictionary = _call_on(_host, ["interact"], ["ship_sail"])
	if not furled.get("ok", false):
		_skip("interact.ship_sail.close", "host has no interact(owner)")
	else:
		await _wait(0.6)
		var closed: Variant = _ship_value(["sails_open", "sails"])
		if closed == null:
			_skip("sails_closed", "no sails state")
		else:
			_check("sails_closed", not _as_bool(closed), str(closed))
		await _wait(10.0)
		var speed_closed: Variant = _ship_float(["speed"])
		if speed_closed == null:
			_skip("speed_stop", "no speed() / snapshot.ship.speed")
		else:
			_check("speed_after_10s_sails_closed", float(speed_closed) < 0.3, "%.2f m/s" % float(speed_closed))
			print("SHIP61_BATTLE_SPEED_CLOSED mps=%.2f" % float(speed_closed))

	# ---------------------------------------------------------- ammo crate
	var balls_before: Variant = _hud_value(["balls", "cannonballs", "ammo"])
	var ammo_action: Dictionary = _call_on(_host, ["interact"], ["ship_ammo"])
	if not ammo_action.get("ok", false):
		_skip("interact.ship_ammo", "host has no interact(owner)")
	else:
		await _wait(0.5)
		var balls_after: Variant = _hud_value(["balls", "cannonballs", "ammo"])
		if balls_before == null or balls_after == null:
			_skip("ammo_count", "snapshot.hud has no balls/ammo")
		else:
			_check("ammo_plus_one", int(balls_after) == int(balls_before) + 1,
				"%d -> %d" % [int(balls_before), int(balls_after)])

	# ---------------------------------------------------------- man the gun
	var man_action: Dictionary = _call_on(_host, ["interact"], ["ship_cannon"])
	if not man_action.get("ok", false):
		_skip("interact.ship_cannon", "host has no interact(owner)")
	else:
		await _wait(0.5)
		var manning: Variant = _ship_value(["manning"])
		if manning == null:
			manning = _cannon_value(["manning", "manned", "active"])
		if manning == null:
			_skip("manning", "no manning() / snapshot.cannons.manning")
		else:
			_check("cannon_manning", _as_bool(manning), str(manning))

		var loaded_before: Variant = _cannon_value(["loaded"])
		if loaded_before == null:
			loaded_before = _ship_value(["loaded"])
		# The current host loads through _load_manning_cannon(): it spends one ball
		# from the stores and starts the gun's 1.2 s loading animation.
		var load_call: Dictionary = _call_on(_host, ["_load_manning_cannon"], [])
		if not load_call.get("ok", false):
			load_call = _cannon_call(["load_ball", "load", "reload", "charg"], [])
		if not load_call.get("ok", false):
			_skip("load", "no load_ball/load on host, cannons or boat")
		else:
			var load_deadline := Time.get_ticks_msec() + 3000
			var loaded_after: Variant = _cannon_value(["loaded"])
			while Time.get_ticks_msec() < load_deadline:
				loaded_after = _cannon_value(["loaded"])
				if loaded_after != null and _as_bool(loaded_after):
					break
				await process_frame
			if loaded_after == null:
				_skip("loaded_state", "no loaded() / snapshot.cannons.loaded")
			else:
				_check("cannon_loaded", _as_bool(loaded_after), str(loaded_after))
			var shots_before: Variant = _cannon_value(["shots"])
			var fired: Dictionary = _call_on(_host, ["_fire_manning_cannon"], [])
			if not fired.get("ok", false):
				fired = _cannon_call(["fire", "shoot"], [])
			if not fired.get("ok", false):
				_skip("fire", "no fire()/shoot() on host, cannons or boat")
			else:
				var result: Variant = fired.get("result")
				var fire_ok := true
				if result is Dictionary:
					fire_ok = bool(result.get("ok", true))
				elif result is bool:
					fire_ok = bool(result)
				_check("cannon_fire", fire_ok, str(result))
				await _wait(0.6)
				var loaded_after_fire: Variant = _cannon_value(["loaded"])
				if loaded_after_fire != null:
					_check("cannon_unloaded_after_fire", not _as_bool(loaded_after_fire), str(loaded_after_fire))
				var shots_after: Variant = _cannon_value(["shots"])
				if shots_before != null and shots_after != null:
					_check("cannon_shot_counted", int(shots_after) > int(shots_before),
						"%d -> %d" % [int(shots_before), int(shots_after)])

	# ---------------------------------------------------------- wall damage
	await _wall_scenario()

	# ---------------------------------------------------------- flooding
	if _host.has_method("debug_hit_ship"):
		var flood_before: Variant = _ship_value(["flooding"])
		if flood_before == null:
			flood_before = _snapshot_ship_value("flooding")
		_host.call("debug_hit_ship", 3)
		await _wait(2.0)
		var flood_after: Variant = _ship_value(["flooding"])
		if flood_after == null:
			flood_after = _snapshot_ship_value("flooding")
		if flood_before == null or flood_after == null:
			_skip("flooding", "no flooding() / snapshot.ship.flooding")
		else:
			_check("flooding_rises", float(flood_after) > float(flood_before),
				"%.3f -> %.3f" % [float(flood_before), float(flood_after)])
			print("SHIP61_BATTLE_FLOODING before=%.3f after=%.3f" % [float(flood_before), float(flood_after)])
	else:
		_skip("debug_hit_ship", "host has no debug_hit_ship(count)")

	# ---------------------------------------------------------- summary
	var final_snapshot: Dictionary = _snapshot()
	print("SHIP61_BATTLE_FINAL ", JSON.stringify(_short_snapshot(final_snapshot)))
	print("SHIP61_BATTLE_API ", JSON.stringify(_host_api))
	if not _skips.is_empty():
		print("SHIP61_BATTLE_SKIPPED ", JSON.stringify(_skips))
	if not _failures.is_empty():
		print("SHIP61_BATTLE_FAILED_CHECKS ", JSON.stringify(_failures))
		print("SHIP61_BATTLE_FAIL checks=%d passed=%d failed=%d skipped=%d" %
			[_checks, _passes, _failures.size(), _skips.size()])
		quit(1)
		return
	print("SHIP61_BATTLE_OK checks=%d skipped=%d" % [_checks, _skips.size()])
	quit(0)

## ---------------------------------------------------------------- scenarios

func _wall_scenario() -> void:
	if not is_instance_valid(_castle) or not _castle.has_method("get_stats"):
		_skip("wall_damage", "castle.get_stats() unavailable")
		return
	# The steering test leaves the ship on an arbitrary course; the damage
	# scenario needs the port battery bearing on the south wall again.
	if _host.has_method("debug_reset_ship"):
		_host.call("debug_reset_ship")
		await _wait(0.6)
	var stats_before: Variant = _castle.call("get_stats")
	var detached_before := 0
	if stats_before is Dictionary:
		detached_before = int((stats_before as Dictionary).get("detached", 0))
	var target := _wall_target()
	var used := ""
	var fired := false
	if _host.has_method("debug_fire_at"):
		used = "debug_fire_at"
		var result: Variant = _host.call("debug_fire_at", target)
		fired = result == null or (result is bool and bool(result)) or (result is Dictionary and bool((result as Dictionary).get("ok", true)))
	else:
		_skip("debug_fire_at", "host has no debug_fire_at(world_point)")
		# Fallback: try the public gun API, aimed straight off the port beam.
		var man: Dictionary = _cannon_call(["man"], [0])
		if not man.get("ok", false):
			_skip("wall_damage", "no debug_fire_at and no cannon man(index)")
			return
		_cannon_call(["aim"], [0.0, 0.0])
		var load: Dictionary = _cannon_call(["load_ball", "load"], [])
		if not load.get("ok", false):
			_skip("wall_damage", "no load_ball for the fallback shot")
			return
		var shot: Dictionary = _cannon_call(["fire"], [])
		fired = bool(shot.get("ok", false))
		used = "cannon_fire_fallback"
	if not fired:
		_skip("wall_damage", "%s reported no shot" % used)
		return
	print("SHIP61_BATTLE_WALL_SHOT via=", used, " target=", target)
	var deadline := Time.get_ticks_msec() + 9000
	var detached_after := detached_before
	while Time.get_ticks_msec() < deadline:
		var stats: Variant = _castle.call("get_stats")
		if stats is Dictionary:
			detached_after = int((stats as Dictionary).get("detached", detached_before))
			if detached_after > detached_before:
				break
		await process_frame
	_check("castle_wall_detached", detached_after > detached_before,
		"%d -> %d" % [detached_before, detached_after])
	print("SHIP61_BATTLE_WALL_DETACHED before=%d after=%d" % [detached_before, detached_after])

func _wall_target() -> Vector3:
	var base := Vector3(0.0, 0.0, 900.0)
	var half := 68.0
	if is_instance_valid(_castle):
		if _castle.has_method("wall_half"):
			half = float(_castle.call("wall_half"))
		if _castle is Node3D:
			base = (_castle as Node3D).global_position
	# The south wall is the closest face to the ship's berth in the bay.
	return base + Vector3(34.0, 8.0, half)

## ---------------------------------------------------------------- HUD

func _check_hud(snapshot: Dictionary) -> void:
	var hud: Variant = _host.get("hud")
	if not is_instance_valid(hud):
		# A host may report the HUD as a plain dictionary in the snapshot instead.
		if snapshot.get("hud") is Dictionary and (_host.has_method("install_hud") or _host.has_method("update_hud")):
			_skip("hud_node", "host reports hud state only, not a ShipHud node")
		else:
			_check("hud_node", false, "preview_ship.hud is null")
		return
	if not (hud as Node).has_method("update_state"):
		_check("hud.update_state", false, "hud node has no update_state")
		return
	_check("hud.update_state", true, "update_state()")
	hud.call("update_state", snapshot)
	if (hud as Node).has_method("message"):
		hud.call("message", "Проверка HUD", 1.0)
		var count: Variant = hud.call("message_count") if (hud as Node).has_method("message_count") else null
		_check("hud.message", count == null or int(count) > 0, str(count))
	if (hud as Node).has_method("set_cannon"):
		hud.call("set_cannon", {"manning": true, "index": 1, "side": "port", "loaded": true, "pitch": 12.0})
		var shown: Variant = hud.call("cannon_visible") if (hud as Node).has_method("cannon_visible") else null
		if shown != null:
			_check("hud.cannon_overlay", bool(shown), str(shown))
		hud.call("set_cannon", {})
		var hidden: Variant = hud.call("cannon_visible") if (hud as Node).has_method("cannon_visible") else null
		if hidden != null:
			_check("hud.cannon_overlay_hides", not bool(hidden), str(hidden))

## ---------------------------------------------------------------- host calls

func _collect_api() -> void:
	for name: String in ["install", "action", "interact", "snapshot", "steer", "debug_fire_at", "debug_hit_ship", "load_ball", "fire"]:
		if _host.has_method(name):
			_host_api.append(name)
	for field: String in ["boat", "basin", "cannons", "hud"]:
		if _host.get(field) != null or _host.get(field) is Object:
			_host_api.append("field:" + field)

func _snapshot() -> Dictionary:
	if is_instance_valid(_host) and _host.has_method("snapshot"):
		var state: Variant = _host.call("snapshot")
		if state is Dictionary:
			return state
	var boat := _ship_target("boat")
	if is_instance_valid(boat) and boat.has_method("snapshot"):
		var boat_state: Variant = boat.call("snapshot")
		if boat_state is Dictionary:
			return {"ship": boat_state}
	return {}

func _ship_target(field: String) -> Node:
	if not is_instance_valid(_host):
		return null
	var target: Variant = _host.get(field)
	if is_instance_valid(target):
		return target as Node
	return null

func _ship_value(keys: Array) -> Variant:
	var ship: Dictionary = _sub(_snapshot(), ["ship", "boat"])
	for key: String in keys:
		if ship.has(key) and ship[key] != null:
			return ship[key]
	# Methods on host or boat win when there is no snapshot field.
	var call: Dictionary = _call_on(_host, keys, [])
	if call.get("ok", false):
		return call.get("result")
	call = _call_on(_ship_target("boat"), keys, [])
	if call.get("ok", false):
		return call.get("result")
	return null

func _snapshot_ship_value(key: String) -> Variant:
	var ship: Dictionary = _sub(_snapshot(), ["ship", "boat"])
	return ship.get(key) if ship.has(key) else null

func _ship_float(keys: Array) -> Variant:
	var value: Variant = _ship_value(keys)
	if value == null:
		return null
	if value is float or value is int:
		return float(value)
	if value is String and str(value).is_valid_float():
		return str(value).to_float()
	return null

func _hud_value(keys: Array) -> Variant:
	var snapshot: Dictionary = _snapshot()
	var hud: Dictionary = _sub(snapshot, ["hud", "cargo", "inventory"])
	for key: String in keys:
		if hud.has(key) and hud[key] != null:
			return hud[key]
	# Some hosts put the inventory on the boat snapshot instead.
	var ship: Dictionary = _sub(snapshot, ["ship", "boat"])
	for key: String in keys:
		if ship.has(key) and ship[key] != null:
			return ship[key]
	return null

func _cannon_value(keys: Array) -> Variant:
	var cannons: Dictionary = _sub(_snapshot(), ["cannons", "cannon", "guns"])
	for key: String in keys:
		if cannons.has(key) and cannons[key] != null:
			return cannons[key]
	var call: Dictionary = _call_on(_ship_target("cannons"), keys, [])
	if call.get("ok", false):
		return call.get("result")
	return null

func _cannon_call(names: Array, args: Array) -> Dictionary:
	var targets: Array = []
	if is_instance_valid(_host):
		targets.append(_host)
	targets.append(_ship_target("cannons"))
	targets.append(_ship_target("boat"))
	return _call_on_first(targets, names, args)

func _call_on(target: Node, names: Array, args: Array) -> Dictionary:
	var targets: Array = []
	if is_instance_valid(target):
		targets.append(target)
	return _call_on_first(targets, names, args)

func _call_on_first(targets: Array, names: Array, args: Array) -> Dictionary:
	for target: Variant in targets:
		if not is_instance_valid(target):
			continue
		for name: String in names:
			if (target as Node).has_method(name):
				var result: Variant = (target as Node).callv(name, args)
				return {"ok": true, "method": name, "target": str((target as Node).name), "result": result}
	return {"ok": false}

## ---------------------------------------------------------------- helpers

func _sub(source: Dictionary, keys: Array) -> Dictionary:
	for key: String in keys:
		var value: Variant = source.get(key)
		if value is Dictionary:
			return value
	return {}

func _check(name: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		_passes += 1
		print("SHIP61_CHECK_PASS ", name, "" if detail.is_empty() else " | " + detail)
	else:
		_failures.append(name)
		print("SHIP61_CHECK_FAIL ", name, "" if detail.is_empty() else " | " + detail)

func _skip(method_name: String, reason: String) -> void:
	_skips.append(method_name)
	print("SKIP ", method_name, " (", reason, ")")

func _as_bool(value: Variant) -> bool:
	if value is bool:
		return value
	if value is float or value is int:
		return float(value) > 0.5
	if value is String:
		return str(value).to_lower() in ["true", "open", "opened", "1"]
	return false

func _angle_delta(after: float, before: float) -> float:
	var delta := after - before
	while delta > PI:
		delta -= TAU
	while delta < -PI:
		delta += TAU
	return delta

func _type_of(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Dictionary:
		return "Dictionary(%d)" % (value as Dictionary).size()
	if value is Array:
		return "Array(%d)" % (value as Array).size()
	if value is Node3D:
		return "Node3D"
	return type_string(typeof(value))

func _script_path(node: Node) -> String:
	var script_ref: Variant = node.get_script()
	if script_ref is Script:
		return (script_ref as Script).resource_path
	return ""

func _wait(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame

## Feed a key to Input the way the live game receives it. On a headless run the
## host's direct Input.is_key_pressed() reads still work if the event updates the
## input state; the probe falls back to steer() when they do not.
func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _short_snapshot(state: Dictionary) -> Dictionary:
	var result := {"keys": state.keys()}
	var ship: Dictionary = _sub(state, ["ship"])
	if not ship.is_empty():
		result["ship"] = {
			"speed": ship.get("speed"),
			"flooding": ship.get("flooding"),
			"integrity": ship.get("integrity"),
			"position": str(ship.get("position")),
		}
	var cans: Dictionary = _sub(state, ["cannons"])
	if not cans.is_empty():
		result["cannons"] = {
			"manning": cans.get("manning"),
			"loaded": cans.get("loaded"),
			"index": cans.get("index"),
		}
	return result
