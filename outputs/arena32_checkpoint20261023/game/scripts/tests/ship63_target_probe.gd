extends SceneTree
## SHIP63 / agent T headless probe for `ship_target.gd`.
##
## Two ways to get a target, in this order:
##   1. the real castle map (the integrator's host installs the target at boot);
##   2. a minimal probe world with the real `ShipWaterBasin`, so the probe still
##      verifies the berth, the real model and the real `ShipBoat` even when the
##      host file is being edited in parallel.
##
## Then the contract scenario runs on the real ship: one 55-damage cannonball hit
## (the number `ship_cannonball.gd` delivers), reset, six QA strikes (mast felled,
## holes, flooding), a synchronous flood-to-sink, the post-sink control lockout and
## a final reset.
##
## Run:
##   & 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe' `
##     --path 'D:\MafioziCombat31\ship_battle64\game' --headless `
##     --script res://scripts/tests/ship63_target_probe.gd
##
## Exit code 0 = PASS, 1 = FAIL.

const ShipTargetScr := preload("res://scripts/ship/ship_target.gd")
const ShipWaterBasin := preload("res://scripts/ship/ship_water_basin.gd")

const TARGET_POS := Vector3(160.0, -0.55, 975.0)
const CANNONBALL_DAMAGE := 55.0
const LOAD_DEADLINE_MS := 180000
const HOST_WAIT_MS := 20000
const SINK_SIM_SECONDS := 45.0

var _world: Node3D = null
var _scene: Node = null
var _host: Node = null
var _target: Node3D = null
var _boat: Node3D = null
var _basin: Object = null
var _main_boat: Node3D = null
var _player: CharacterBody3D = null
var _mode := ""
var _install_info: Dictionary = {}

var _checks := 0
var _passes := 0
var _failures: Array[String] = []
var _skips: Array[String] = []
var _numbers: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("SHIP63_TARGET_PROBE_START")
	if OS.get_cmdline_user_args().has("--fallback"):
		print("SHIP63_TARGET_PROBE_SCENE skipped_by_flag")
		_boot_fallback()
	elif not await _boot_scene():
		_boot_fallback()
	_ensure_target()
	if _target == null or not bool(_target.call("is_installed")):
		print("SHIP63_TARGET_PROBE_FAIL no_target mode=", _mode)
		quit(1)
		return
	_boat = _target.get("boat") as Node3D
	print("SHIP63_TARGET_PROBE_MODE ", _mode, " world=", _world.name,
		" boat=", _boat != null, " host=", is_instance_valid(_host),
		" main_boat=", is_instance_valid(_main_boat), " basin=", _basin != null)
	await physics_frame
	await physics_frame

	# ---------------------------------------------------------------- install / berth
	_install_info = _dict(_target.get("_install_result"))
	_check("install.ok", bool(_install_info.get("ok", false)), str(_install_info.get("reason", "")))
	_check("install.name", str(_install_info.get("name", "")) == "TargetShip",
		str(_install_info.get("name", "")))
	_check("install.model_built", bool(_install_info.get("model_built", false)), "")
	_check("boat.valid", is_instance_valid(_boat))
	if is_instance_valid(_boat):
		_check("boat.name", str(_boat.name) == "TargetShip", str(_boat.name))
		_check("boat.class", _boat is AnimatableBody3D, _boat.get_class())
		_check("boat.collisions", int(_install_info.get("collision_shapes", 0)) > 40,
			"%d shapes" % int(_install_info.get("collision_shapes", 0)))
	var position: Vector3 = _boat.global_position if is_instance_valid(_boat) else Vector3.ZERO
	var berth: Vector3 = _install_info.get("berth", TARGET_POS) as Vector3
	_numbers["berth"] = berth
	_check("berth.matches_request",
		Vector2(position.x, position.z).distance_to(Vector2(berth.x, berth.z)) < 1.5,
		"boat=%s requested=%s" % [str(position), str(berth)])
	_check("berth.position_y", absf(position.y - _water_level()) < 1.0,
		"y=%.3f water=%.3f" % [position.y, _water_level()])
	var yaw: float = _boat.global_rotation.y if is_instance_valid(_boat) else 9.0
	_check("berth.yaw_deg_0", absf(wrapf(yaw, -PI, PI)) < 0.02, "%.4f rad" % yaw)
	if is_instance_valid(_main_boat):
		var gap := Vector2(position.x - _main_boat.global_position.x,
			position.z - _main_boat.global_position.z).length()
		_check("berth.45m_from_player_ship", absf(gap - 45.0) < 1.0, "%.2f m" % gap)
		_numbers["gap_player_ship"] = gap
	if Vector2(berth.x, berth.z).distance_to(Vector2(TARGET_POS.x, TARGET_POS.z)) > 1.0:
		print("SHIP63_TARGET_PROBE_NOTE host_berth=", berth, " brief_berth=", TARGET_POS)

	var report: Dictionary = _dict(_target.call("berth_report"))
	var depth_center := float(report.get("depth_center", 0.0))
	var min_depth := float(report.get("min_depth", 0.0))
	_check("berth.depth_center_7m", depth_center >= 6.9, "%.2f m" % depth_center)
	_check("berth.min_depth", min_depth >= 6.0, "%.2f m" % min_depth)
	_check("berth.navigable", bool(report.get("navigable", false)), "")
	_check("berth.no_collisions", int(report.get("overlaps", -1)) == 0,
		"%d overlaps %s" % [int(report.get("overlaps", -1)), str(report.get("overlap_names", []))])
	_numbers["depth_center"] = depth_center
	_numbers["min_depth"] = min_depth
	_numbers["depth_bow"] = float(report.get("depth_bow", 0.0))
	_numbers["overlaps"] = int(report.get("overlaps", -1))

	# The contract berth (host and default agree): it must be deep and clear in its
	# own right, not just wherever the boat happens to stand.
	var default_depth := _depth_at(TARGET_POS.x, TARGET_POS.z)
	var default_overlaps := _berth_overlaps(TARGET_POS)
	_check("contract_berth.depth_7m", default_depth >= 6.9, "%.2f m at %s" % [default_depth, str(TARGET_POS)])
	_check("contract_berth.clear", default_overlaps == 0, "%d overlaps" % default_overlaps)
	_check("contract_berth.match", Vector2(berth.x, berth.z).distance_to(
		Vector2(TARGET_POS.x, TARGET_POS.z)) < 1.5,
		"installed=%s contract=%s" % [str(berth), str(TARGET_POS)])
	_numbers["default_depth"] = default_depth
	_numbers["default_overlaps"] = default_overlaps

	# ---------------------------------------------------------------- identity with the player ship
	if is_instance_valid(_main_boat):
		# Direct children only: the hull shapes are built by the boat itself, while the
		# player ship later collects powder-barrel props whose own shapes are nested.
		var main_shapes := _count_direct_type(_main_boat, "CollisionShape3D")
		var target_shapes := _count_direct_type(_boat, "CollisionShape3D")
		_check("identical.collision_shapes", main_shapes == target_shapes,
			"main=%d target=%d" % [main_shapes, target_shapes])
		# The player's hull carries extra runtime props (gun rammers, powder barrels),
		# so the authored model is compared through its anchors and rig counts.
		var main_model := _main_boat.get("_model") as Node3D
		var target_model := _target.get("model") as Node3D
		var anchor_delta := _anchor_delta(main_model, target_model)
		_check("identical.model_anchors", anchor_delta == 0, "%d anchors differ" % anchor_delta)
		var rig_delta := _rig_delta(main_model, target_model)
		_check("identical.rigging", rig_delta == 0, "%d rig counters differ" % rig_delta)
		var main_length := float(_main_boat.get("_length"))
		var main_beam := float(_main_boat.get("_beam"))
		_check("identical.length_beam",
			absf(main_length - float(_install_info.get("length", 0.0))) < 0.001
			and absf(main_beam - float(_install_info.get("beam", 0.0))) < 0.001,
			"main=%.2fx%.2f target=%.2fx%.2f" % [main_length, main_beam,
				float(_install_info.get("length", 0.0)), float(_install_info.get("beam", 0.0))])
		_numbers["collision_shapes"] = target_shapes
	else:
		_skip("identical", "no player ship in this run")

	var clean := _snapshot()
	_check("clean.no_holes", int(clean.get("holes", -1)) == 0, str(clean.get("holes", -1)))
	_check("clean.integrity", absf(float(clean.get("integrity", 0.0)) - 1.0) < 0.001,
		"%.3f" % float(clean.get("integrity", 0.0)))
	_check("clean.usable", bool(clean.get("usable", false)), "")
	_check("clean.sunk", not bool(clean.get("sunk", true)), "")
	_check("clean.sails_closed", not bool(clean.get("sails_open", true)), "")
	_check("clean.stationary", absf(float(clean.get("speed", 9.0))) < 0.05,
		"%.3f m/s" % float(clean.get("speed", 9.0)))
	_check("controls.no_player", not _target.has_method("interact")
		and not _target.has_method("action"), "target has no player station API")

	# ---------------------------------------------------------------- live cannonball
	# Diagnostic only: depends on agent F's ball code and the player's gun arc. The
	# target's own apply_hit path is proven below without it.
	var live: Dictionary = await _live_cannon_probe()
	if bool(live.get("ran", false)):
		_numbers["live_cannon_holes"] = int(live.get("holes_after", 0))
		_numbers["live_cannon_hit"] = bool(live.get("ok", false))
		_target.call("reset")
		_boat = _target.get("boat") as Node3D
		await physics_frame
		await physics_frame

	# ---------------------------------------------------------------- one real cannonball
	var hit_local := Vector3(-(_hull_half_width(-8.0, 1.2) - 0.03), 1.2, -8.0)
	var hit_point: Vector3 = _boat.call("world_deck", hit_local)
	var hit: Dictionary = _dict(_boat.call("apply_hit", hit_point, CANNONBALL_DAMAGE,
		Vector3(-1.0, 0.0, 0.0) * 8.0, "cannonball"))
	_check("cannonball.ok", bool(hit.get("ok", false)), str(hit.get("reason", "")))
	_check("cannonball.zone_hull", str(hit.get("zone", "")) == "hull", str(hit.get("zone", "")))
	_check("cannonball.hole", bool(hit.get("hole", false)), "")
	_check("cannonball.hole_visible", _visible_holes() >= 1, "%d decals" % _visible_holes())
	_target.call("sink_test", 0, 3.0)
	var after_hit := _snapshot()
	var flood_1 := float(after_hit.get("flooding", 0.0))
	_numbers["flooding_after_1_hit_3s"] = flood_1
	_numbers["flood_rate_after_1_hit"] = float(after_hit.get("flood_rate", 0.0))
	_check("cannonball.flooding_started", flood_1 > 0.01, "%.4f" % flood_1)
	_check("cannonball.integrity_dropped", float(after_hit.get("integrity", 1.0)) < 1.0,
		"%.4f" % float(after_hit.get("integrity", 1.0)))
	_check("cannonball.not_sunk_yet", not bool(after_hit.get("sunk", true)), "")

	# ---------------------------------------------------------------- reset
	var reset_one: Dictionary = _dict(_target.call("reset"))
	_check("reset.ok", bool(reset_one.get("ok", false)), str(reset_one.get("reason", "")))
	_boat = _target.get("boat") as Node3D
	_check("reset.boat_valid", is_instance_valid(_boat), "")
	var reset_state := _snapshot()
	_check("reset.no_holes", int(reset_state.get("holes", -1)) == 0, str(reset_state.get("holes", -1)))
	_check("reset.no_flooding", absf(float(reset_state.get("flooding", 1.0))) < 0.001,
		"%.4f" % float(reset_state.get("flooding", 1.0)))
	_check("reset.usable", bool(reset_state.get("usable", false)), "")
	_check("reset.position", Vector2(_boat.global_position.x - berth.x,
		_boat.global_position.z - berth.z).length() < 1.5,
		"%.2f m from %s" % [Vector2(_boat.global_position.x - berth.x,
			_boat.global_position.z - berth.z).length(), str(berth)])
	_check("reset.mast_restored", absf(float(reset_state.get("mast_hp", 0.0)) - 220.0) < 1.0,
		"%.1f" % float(reset_state.get("mast_hp", 0.0)))
	_check("reset.one_boat_node", _count_named(_target, "TargetShip") == 1,
		str(_count_named(_target, "TargetShip")))

	# ---------------------------------------------------------------- six QA strikes
	var sink: Dictionary = _dict(_target.call("sink_test", 6, 0.0))
	var holes := int(sink.get("holes", 0))
	_numbers["holes_after_6"] = holes
	_numbers["flood_rate_after_6"] = float(sink.get("flood_rate", 0.0))
	_numbers["integrity_after_6"] = float(sink.get("integrity", 0.0))
	_numbers["seconds_to_sink_estimate"] = float(sink.get("seconds_to_sink", -1.0))
	_numbers["zones_after_6"] = _zone_histogram(sink)
	_check("sink_test.holes", holes >= 4 and holes <= 6, "%d holes" % holes)
	_check("sink_test.mast_fell", bool(sink.get("mast_broken", false)), "")
	_check("sink_test.mast_hp_zero", float(sink.get("mast_hp", 1.0)) <= 0.5,
		"%.1f" % float(sink.get("mast_hp", 0.0)))
	_check("sink_test.flood_rate", float(sink.get("flood_rate", 0.0)) > 0.02,
		"%.4f/s" % float(sink.get("flood_rate", 0.0)))
	_check("sink_test.leaking_not_sunk", float(sink.get("flooding", 1.0)) < 0.2,
		"%.4f" % float(sink.get("flooding", 0.0)))
	_check("sink_test.usable_before_sinking", bool(sink.get("usable", false)), "")
	_print_shot_plan(sink)

	# ---------------------------------------------------------------- flood to sinking
	var sink_started := Time.get_ticks_msec()
	var sunk_state: Dictionary = _dict(_target.call("sink_test", 0, SINK_SIM_SECONDS))
	_numbers["sink_sim_ms"] = Time.get_ticks_msec() - sink_started
	_numbers["flooding_sunk"] = float(sunk_state.get("flooding", 0.0))
	_numbers["sink_t"] = float(sunk_state.get("sink_t", 0.0))
	_numbers["position_y_sunk"] = (sunk_state.get("position", Vector3.ZERO) as Vector3).y
	_check("sink.sunk", bool(sunk_state.get("sunk", false)), "")
	_check("sink.usable_false", not bool(sunk_state.get("usable", true)), "")
	_check("sink.flooding_full", float(sunk_state.get("flooding", 0.0)) >= 0.999,
		"%.4f" % float(sunk_state.get("flooding", 0.0)))
	_check("sink.sink_t", float(sunk_state.get("sink_t", 0.0)) >= 1.0,
		"%.2f s" % float(sunk_state.get("sink_t", 0.0)))
	_check("sink.hull_lowered", float((sunk_state.get("position", Vector3.ZERO) as Vector3).y)
		< _water_level() - 1.0,
		"y=%.2f" % float((sunk_state.get("position", Vector3.ZERO) as Vector3).y))

	# ---------------------------------------------------------------- controls locked after sinking
	var sails_applied := bool(_target.call("set_sails", true))
	_check("sunk.sails_refused", not sails_applied, "set_sails returned true")
	_check("sunk.sails_stay_closed", not bool(_snapshot().get("sails_open", true)), "")
	var steer_applied := bool(_target.call("steer", 1.0))
	_check("sunk.rudder_refused", not steer_applied, "steer returned true")
	var rudder_before := float(_snapshot().get("rudder_target", 0.0))
	_target.call("sink_test", 0, 1.0)
	var locked := _snapshot()
	_check("sunk.rudder_unchanged", absf(float(locked.get("rudder_target", 0.0)) - rudder_before) < 0.01,
		"%.4f -> %.4f" % [rudder_before, float(locked.get("rudder_target", 0.0))])
	_check("sunk.speed_zero", absf(float(locked.get("speed", 9.0))) < 0.05,
		"%.3f m/s" % float(locked.get("speed", 9.0)))
	# The boat must refuse canvas on its own too (SHIP63 task C.4); either layer may
	# say no, but the ship must not grow canvas while it is under.
	if is_instance_valid(_boat):
		_boat.call("set_sails", true)
	_check("sunk.boat_own_sails_refused", not bool(_boat.call("sails_open")), "")
	if is_instance_valid(_main_boat):
		_check("main_ship_unaffected", not bool(_main_boat.call("is_sunk")), "")

	# ---------------------------------------------------------------- reset after sinking
	var debris_before := _count_debris_roots()
	var reset_two: Dictionary = _dict(_target.call("reset"))
	_check("reset_after_sink.ok", bool(reset_two.get("ok", false)),
		str(reset_two.get("reason", "")))
	_boat = _target.get("boat") as Node3D
	var revived := _snapshot()
	_check("reset_after_sink.usable", bool(revived.get("usable", false)), "")
	_check("reset_after_sink.not_sunk", not bool(revived.get("sunk", true)), "")
	_check("reset_after_sink.no_holes", int(revived.get("holes", -1)) == 0,
		str(revived.get("holes", -1)))
	_check("reset_after_sink.mast_up", not bool(revived.get("mast_broken", true)), "")
	_check("reset_after_sink.position", Vector2(_boat.global_position.x - berth.x,
		_boat.global_position.z - berth.z).length() < 1.5,
		"%.2f m from %s" % [Vector2(_boat.global_position.x - berth.x,
			_boat.global_position.z - berth.z).length(), str(berth)])
	_check("reset_after_sink.debris_roots", _count_debris_roots() == debris_before,
		"%d -> %d" % [debris_before, _count_debris_roots()])
	_check("reset_after_sink.one_boat_node", _count_named(_target, "TargetShip") == 1,
		str(_count_named(_target, "TargetShip")))
	var reusable: Dictionary = _dict(_target.call("sink_test", 2, 0.0))
	_check("reset_after_sink.damage_works_again", int(reusable.get("holes", 0)) == 2,
		"%d holes" % int(reusable.get("holes", 0)))

	# ---------------------------------------------------------------- one-call QA sink
	# The default `sink_test(shots)` must be enough for a QA probe that only knows
	# the single-argument contract: it floods the hull until it is under.
	_target.call("reset")
	_boat = _target.get("boat") as Node3D
	await physics_frame
	await physics_frame
	var auto: Dictionary = _dict(_target.call("sink_test", 6))
	_numbers["auto_sink_seconds"] = float(auto.get("simulated_seconds", 0.0))
	_check("auto_sink.sunk", bool(auto.get("sunk", false)), "")
	_check("auto_sink.usable_false", not bool(auto.get("usable", true)), "")
	_check("auto_sink.holes", int(auto.get("holes", 0)) == 4, "%d holes" % int(auto.get("holes", 0)))
	_check("auto_sink.mast_fell", bool(auto.get("mast_broken", false)), "")
	_check("auto_sink.simulated", float(auto.get("simulated_seconds", 0.0)) > 30.0,
		"%.1f s" % float(auto.get("simulated_seconds", 0.0)))
	_target.call("reset")
	_boat = _target.get("boat") as Node3D
	await physics_frame
	await physics_frame
	_check("auto_sink.reset_clean", bool(_snapshot().get("usable", false))
		and not bool(_snapshot().get("sunk", true)),
		JSON.stringify({"usable": _snapshot().get("usable"), "sunk": _snapshot().get("sunk")}))

	# ---------------------------------------------------------------- summary
	print("SHIP63_TARGET_PROBE_NUMBERS ", JSON.stringify(_numbers))
	var verdict := "PASS" if _failures.is_empty() else "FAIL"
	print("SHIP63_TARGET_PROBE_RESULT ", verdict, " checks=", _checks,
		" passes=", _passes, " failures=", _failures.size(), " skips=", _skips.size(),
		" mode=", _mode)
	for failure: String in _failures:
		print("SHIP63_TARGET_PROBE_FAILED ", failure)
	for skip: String in _skips:
		print("SHIP63_TARGET_PROBE_SKIPPED ", skip)
	quit(0 if _failures.is_empty() else 1)


## ------------------------------------------------------------------ boot

func _boot_scene() -> bool:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHIP63_TARGET_PROBE_SCENE scene_missing")
		return false
	_scene = packed.instantiate()
	if _scene == null:
		print("SHIP63_TARGET_PROBE_SCENE instantiate_failed")
		return false
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + LOAD_DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true:
			break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("SHIP63_TARGET_PROBE_SCENE preview_ready_timeout")
		return false
	var host_deadline := Time.get_ticks_msec() + HOST_WAIT_MS
	while Time.get_ticks_msec() < host_deadline:
		_host = _scene.get("preview_ship") as Node
		if is_instance_valid(_host):
			break
		await process_frame
	_world = _scene as Node3D
	_player = _scene.get("_player") as CharacterBody3D
	if is_instance_valid(_host):
		_mode = "scene"
		_basin = _host.get("basin")
		_main_boat = _host.get("boat") as Node3D
		_target = _host.get("target") as Node3D
		print("SHIP63_TARGET_PROBE_SCENE host=ready target=", _target != null,
			" basin=", _basin != null)
		return true
	print("SHIP63_TARGET_PROBE_SCENE host_missing status=", str(_scene.get("ship_status")))
	# The map exists, so keep it as the world (real water may still be installed by
	# hand below) but do not require the host.
	_mode = "scene_no_host"
	return true


func _boot_fallback() -> void:
	_mode = "fallback"
	var probe_world := Node3D.new()
	probe_world.name = "TargetProbeWorld"
	root.add_child(probe_world)
	_world = probe_world
	var castle := Node3D.new()
	castle.name = "ProbeCastle"
	probe_world.add_child(castle)
	_player = CharacterBody3D.new()
	_player.name = "ProbePlayer"
	probe_world.add_child(_player)
	var water := ShipWaterBasin.new()
	water.name = "ShipWaterBasin"
	probe_world.add_child(water)
	var installed: Dictionary = _dict(water.call("install", probe_world, castle))
	_basin = water
	print("SHIP63_TARGET_PROBE_WORLD fallback water_ok=", installed.get("ok", false),
		" depth_berth=", water.call("depth_at", TARGET_POS.x, TARGET_POS.z))


func _ensure_target() -> void:
	if _target != null and bool(_target.call("is_installed")):
		return
	if _basin == null:
		# The scene booted but the ship host did not: install the real basin so the
		# berth check is still against the real water, not a fake.
		var castle: Node = null
		if is_instance_valid(_scene):
			castle = _scene.get("preview_castle") as Node
		if castle == null:
			castle = Node3D.new()
			castle.name = "ProbeCastle"
			_world.add_child(castle)
		var water := ShipWaterBasin.new()
		water.name = "ShipWaterBasin"
		_world.add_child(water)
		var installed: Dictionary = _dict(water.call("install", _world, castle))
		_basin = water
		print("SHIP63_TARGET_PROBE_WORLD basin_installed ok=", installed.get("ok", false))
	_target = ShipTargetScr.new()
	_target.name = "ShipTargetProbe"
	_world.add_child(_target)
	var result: Dictionary = _dict(_target.call("install", _world, _basin, _player, TARGET_POS + Vector3(0.0, 0.0, 0.0), 0.0))
	print("SHIP63_TARGET_PROBE_WORLD target_install ok=", result.get("ok", false),
		" depth=", result.get("depth", 0.0), " overlaps=", result.get("overlaps", -1))


## ------------------------------------------------------------------ helpers

func _snapshot() -> Dictionary:
	if _target == null:
		return {}
	return _dict(_target.call("snapshot"))


func _water_level() -> float:
	if _basin != null and _basin.has_method("water_level"):
		return float(_basin.call("water_level"))
	return -0.55


func _zone_histogram(state: Dictionary) -> Dictionary:
	var histogram: Dictionary = {}
	var hits: Variant = state.get("hits", [])
	if hits is Array:
		for entry: Variant in (hits as Array):
			if entry is Dictionary:
				var zone := str((entry as Dictionary).get("zone", ""))
				histogram[zone] = int(histogram.get(zone, 0)) + 1
	return histogram


func _print_shot_plan(state: Dictionary) -> void:
	var hits: Variant = state.get("hits", [])
	if hits is Array:
		for index in (hits as Array).size():
			var entry: Variant = (hits as Array)[index]
			if entry is Dictionary:
				var hit := entry as Dictionary
				print("SHIP63_TARGET_SHOT ", index, " zone=", hit.get("zone", ""),
					" hole=", hit.get("hole", false), " part=", hit.get("part", ""),
					" local=", hit.get("local", Vector3.ZERO))


func _mesh_name_counts(root: Node) -> Dictionary:
	var counts: Dictionary = {}
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			var key := str(child.name)
			counts[key] = int(counts.get(key, 0)) + 1
		var nested := _mesh_name_counts(child)
		for key: Variant in nested.keys():
			counts[key] = int(counts.get(key, 0)) + int(nested[key])
	return counts


func _hull_half_width(z: float, y: float) -> float:
	var model_node: Node3D = null
	if _target != null:
		model_node = _target.get("model") as Node3D
	if model_node != null and model_node.has_method("_hull_x_at"):
		return float(model_node.call("_hull_x_at", z, y))
	return 4.4


func _visible_holes() -> int:
	var model_node: Node3D = null
	if _target != null:
		model_node = _target.get("model") as Node3D
	if model_node == null:
		return 0
	var total := 0
	var stack: Array[Node] = [model_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and str(node.name).begins_with("Hole") \
				and (node as MeshInstance3D).visible:
			total += 1
	return total


func _live_cannon_probe() -> Dictionary:
	## Diagnostic: fire the player ship's real starboard gun at the target and see if
	## the ball lands on her hull (agent F's other-ship path). Never a FAIL of this
	## probe: the target's own apply_hit contract is proved independently.
	var result := {"ran": false, "ok": false, "reason": ""}
	if not is_instance_valid(_host):
		return result
	var cannons: Node = _host.get("cannons")
	if cannons == null or not cannons.has_method("debug_fire_at"):
		return result
	var aim: Vector3 = _boat.call("world_deck",
		Vector3(-(_hull_half_width(-7.0, 1.3) - 0.05), 1.3, -7.0))
	var holes_before := int(_snapshot().get("holes", 0))
	var fired: Dictionary = _dict(cannons.call("debug_fire_at", aim))
	result["ran"] = true
	result["fired"] = bool(fired.get("ok", false))
	result["gun"] = int(fired.get("index", -1))
	result["aim"] = aim
	if not bool(fired.get("ok", false)):
		result["reason"] = "fire_refused:" + str(fired.get("reason", ""))
		print("SHIP63_TARGET_LIVE_CANNON ", JSON.stringify(result))
		return result
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if int(_snapshot().get("holes", 0)) > holes_before:
			break
	var state: Dictionary = _dict(cannons.call("state"))
	result["impact"] = _dict(state.get("last_impact", {}))
	result["holes_before"] = holes_before
	result["holes_after"] = int(_snapshot().get("holes", 0))
	result["ok"] = int(result["holes_after"]) > holes_before
	print("SHIP63_TARGET_LIVE_CANNON ", JSON.stringify(result))
	return result


func _depth_at(x: float, z: float) -> float:
	if _basin != null and _basin.has_method("depth_at"):
		return float(_basin.call("depth_at", x, z))
	return -1.0


func _berth_overlaps(at: Vector3) -> int:
	if not is_instance_valid(_world):
		return -1
	var space := _world.get_world_3d().direct_space_state
	if space == null:
		return -1
	var box := BoxShape3D.new()
	box.size = Vector3(9.8, 4.6, 27.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, 1.35, at.z))
	query.collision_mask = 1
	query.collide_with_areas = false
	var exclude: Array[RID] = []
	if is_instance_valid(_boat) and _boat is CollisionObject3D:
		exclude.append((_boat as CollisionObject3D).get_rid())
	query.exclude = exclude
	return space.intersect_shape(query, 32).size()


func _anchor_points(model_node: Node3D) -> Dictionary:
	var points: Dictionary = {}
	if model_node == null or not model_node.has_method("anchors"):
		return points
	var anchors := _dict(model_node.call("anchors"))
	for key: String in ["helm", "sail_lever", "bow", "upper_deck"]:
		var entry: Variant = anchors.get(key, null)
		if entry is Dictionary:
			var pos: Variant = (entry as Dictionary).get("position", null)
			if pos is Vector3:
				points[key] = pos
	var mast: Variant = anchors.get("mast", null)
	if mast is Dictionary:
		var mast_dict := mast as Dictionary
		for key: String in ["base", "top"]:
			var pos: Variant = mast_dict.get(key, null)
			if pos is Vector3:
				points["mast_" + key] = pos
	var cannons: Variant = anchors.get("cannons", null)
	if cannons is Array:
		var index := 0
		for entry: Variant in (cannons as Array):
			if entry is Dictionary:
				var mount: Variant = (entry as Dictionary).get("mount", null)
				if mount is Vector3:
					points["cannon_%d" % index] = mount
			index += 1
	return points


func _anchor_delta(main_model: Node3D, target_model: Node3D) -> int:
	var a := _anchor_points(main_model)
	var b := _anchor_points(target_model)
	if a.is_empty() or b.is_empty():
		return 1
	if a.size() != b.size():
		return absi(a.size() - b.size())
	var delta := 0
	for key: Variant in a.keys():
		if not b.has(key):
			delta += 1
			continue
		var av: Vector3 = a[key]
		var bv: Vector3 = b[key]
		if av.distance_to(bv) > 0.001:
			delta += 1
	return delta


func _rig_delta(main_model: Node3D, target_model: Node3D) -> int:
	var a := _dict(main_model.call("rigging_snapshot")) if main_model != null else {}
	var b := _dict(target_model.call("rigging_snapshot")) if target_model != null else {}
	var delta := 0
	for key: String in ["ropes", "ropes_live", "segments", "points", "flags", "flags_total"]:
		if int(a.get(key, -1)) != int(b.get(key, -2)):
			delta += 1
	return delta


func _count_direct_type(root: Node, type_name: String) -> int:
	var total := 0
	for child: Node in root.get_children():
		if child.is_class(type_name):
			total += 1
	return total


func _count_named(root: Node, node_name: String) -> int:
	var total := 0
	for child: Node in root.get_children():
		if str(child.name) == node_name:
			total += 1
		total += _count_named(child, node_name)
	return total


func _count_debris_roots() -> int:
	if not is_instance_valid(_world):
		return 0
	var total := 0
	for child: Node in _world.get_children():
		if str(child.name).begins_with("ShipDebris"):
			total += 1
	return total


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		_passes += 1
		print("SHIP63_TARGET_CHECK ", label, " OK", (" " + detail) if not detail.is_empty() else "")
		return
	var line := label
	if not detail.is_empty():
		line += " (" + detail + ")"
	_failures.append(line)
	print("SHIP63_TARGET_CHECK ", label, " FAIL ", detail)


func _skip(label: String, reason: String) -> void:
	_skips.append(label + ": " + reason)
	print("SHIP63_TARGET_CHECK ", label, " SKIP ", reason)


func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}




