extends SceneTree
## Functional probe for the three gate defences: postern, stone hatch and oil cauldron.
## Headless. It drives the same castle action path the player uses and then steps the
## physics directly, so it proves state and geometry rather than screenshots.

const Layout = preload("res://scripts/siege/gate_defense_layout.gd")

var _game: Node
var _castle: Node3D
var _player: CharacterBody3D
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(name: String, value: bool, detail: Variant = "") -> void:
	_checks.append({"name": name, "value": value, "detail": str(detail)})
	if not value:
		_failures.append(name + " " + str(detail))


func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("GATE_DEFENSES_FAIL scene")
		quit(1)
		return
	_game = packed.instantiate()
	root.add_child(_game)
	current_scene = _game
	var deadline: int = Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline and _game.get("preview_ready") != true:
		await process_frame
	_castle = _game.get("preview_castle") as Node3D
	_player = _game.get("_player") as CharacterBody3D
	if _castle == null or _player == null:
		print("GATE_DEFENSES_FAIL scene_parts")
		quit(1)
		return
	var gallery: Node3D = _castle.get("_gate_gallery") as Node3D
	var hatch: Node3D = _castle.get("_stone_hatch") as Node3D
	var cauldron: Node3D = _castle.get("_gate_cauldron") as Node3D
	var sally: Node3D = _castle.get("_sally_port") as Node3D
	_check("gallery_exists", gallery != null)
	_check("hatch_exists", hatch != null)
	_check("cauldron_exists", cauldron != null)
	_check("sally_exists", sally != null)
	if gallery == null or hatch == null or cauldron == null or sally == null:
		_report()
		return
	var hatch_stats: Dictionary = hatch.call("get_stats")
	_check("hatch_stones", int(hatch_stats.get("stones", 0)) == 10, hatch_stats)
	_check("hatch_closed", not bool(hatch_stats.get("open", true)), hatch_stats)
	var cauldron_stats: Dictionary = cauldron.call("get_stats")
	_check("cauldron_start", absf(float(cauldron_stats.get("z", 0.0)) - Layout.CAULDRON_START.z) < 0.02,
		cauldron_stats)
	var sally_stats: Dictionary = sally.call("get_stats")
	_check("sally_closed", not bool(sally_stats.get("open", true)), sally_stats)

	# --- the postern: open it through the castle action, then walk it closed again.
	_player.global_position = _castle.to_global(Vector3(-8.20, 0.25, 67.00))
	await physics_frame
	var sally_action: Dictionary = _castle.call("interaction_action")
	_check("sally_prompt", str(sally_action.get("owner", "")) == "castle_sally", sally_action)
	_check("sally_interact", bool(_castle.call("interact_castle", sally_action)), sally_action)
	for i: int in 150:
		await physics_frame
	var sally_open: Dictionary = sally.call("get_stats")
	_check("sally_opened", bool(sally_open.get("open", false)), sally_open)
	_check("sally_door_angle", float(sally_open.get("door_angle", 0.0)) > 1.55, sally_open)
	_check("sally_passable", bool(sally_open.get("passable", false)), sally_open)
	_player.global_position = _castle.to_global(Vector3(-8.20, 0.25, 67.00))
	await physics_frame
	var sally_close: Dictionary = _castle.call("interaction_action")
	_check("sally_close_prompt", str(sally_close.get("owner", "")) == "castle_sally", sally_close)
	_check("sally_close_interact", bool(_castle.call("interact_castle", sally_close)), sally_close)
	for i: int in 150:
		await physics_frame
	var sally_closed: Dictionary = sally.call("get_stats")
	_check("sally_closed_again", float(sally_closed.get("door_angle", 1.0)) < 0.05, sally_closed)
	_check("sally_barred", float(sally_closed.get("bar", 1.0)) < 0.05, sally_closed)

	# --- the hatch: pull the lever, then let the stones fall.
	_player.global_position = _castle.to_global(Layout.LEVER_POS + Vector3(0.0, 0.25, 0.0))
	await physics_frame
	var hatch_action: Dictionary = _castle.call("interaction_action")
	_check("hatch_prompt", str(hatch_action.get("owner", "")) == "castle_hatch", hatch_action)
	_check("hatch_interact", bool(_castle.call("interact_castle", hatch_action)), hatch_action)
	for i: int in 30:
		await physics_frame
	var hatch_open: Dictionary = hatch.call("get_stats")
	_check("hatch_released", bool(hatch_open.get("released", false)), hatch_open)
	for i: int in 180:
		await physics_frame
	var hatch_fall: Dictionary = hatch.call("get_stats")
	_check("hatch_stones_fell", float(hatch_fall.get("lowest_stone_y", 99.0)) < 12.0, hatch_fall)
	_check("hatch_stones_settled", int(hatch_fall.get("awake_stones", 99)) <= 12, hatch_fall)

	# --- the cauldron: push it to the edge with the player body, then let it tip.
	var z := float(cauldron_stats.get("z", Layout.CAULDRON_START.z))
	for i: int in 90:
		_player.global_position = _castle.to_global(Vector3(Layout.CAULDRON_START.x,
			Layout.FLOOR_Y + 0.25, z - 0.86))
		_player.velocity = Vector3(0.0, 0.0, 2.0)
		cauldron.call("_physics_process", 0.05)
		z = float(cauldron.call("get_stats").get("z", z))
	var pushed: Dictionary = cauldron.call("get_stats")
	_check("cauldron_pushed", float(pushed.get("z", 0.0)) > Layout.CAULDRON_START.z + 0.7, pushed)
	_check("cauldron_tipping", float(pushed.get("tip", 0.0)) > 0.01, pushed)
	for i: int in 160:
		await physics_frame
	var poured: Dictionary = cauldron.call("get_stats")
	_check("cauldron_pouring", bool(poured.get("pouring", false)), poured)
	_check("cauldron_oil_left", float(poured.get("oil", 1.0)) < 0.9, poured)
	_check("cauldron_puddle", float(poured.get("puddle_radius", 0.0)) > 0.2, poured)
	_check("cauldron_burning", bool(poured.get("burning", false)), poured)

	_report()


func _report() -> void:
	var passed: bool = _failures.is_empty()
	print("GATE_DEFENSES ", JSON.stringify({
		"pass": passed,
		"checks": _checks.size(),
		"failures": _failures,
		"castle_stats": _castle.call("gate_defenses_snapshot") if _castle != null else {},
	}))
	current_scene = null
	if _game != null:
		_game.queue_free()
	quit(0 if passed else 1)
