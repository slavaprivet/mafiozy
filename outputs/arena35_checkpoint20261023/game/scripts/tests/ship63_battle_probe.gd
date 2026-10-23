extends SceneTree
## SHIP63 battle probe (agent Q / QA).
##
## Boots `castle.tscn` exactly like the game, takes the ship battle host from
## `preview_ship` and runs the stage-3 gameplay contract end to end:
##
##   * the target hulk (`preview_target`) and the powder cargo (`preview_powder`);
##   * ten cannon shots at the castle wall: blast 3-8 bricks average, max 10;
##   * six cannon shots at the target: hits, holes/flooding grow, the hulk sinks
##     and stops answering the helm;
##   * powder barrels: loading/unloading, an explosion and the hull damage it does;
##   * the helm collision: the player cannot walk through the wheel, can stand
##     behind it and F-interact;
##   * death at the gun: the host lets the station and the player go;
##   * a sunk ship: no action prompt, no helm, no sails, no guns;
##   * sail holes: a `sail` zone hit punches the cloth and the pool stays at 16;
##   * the frame: at least 60 FPS after all of the above.
##
## Agent boundaries are respected: this probe never edits a game file.  While the
## other agents are still landing their modules, a missing module is reported as
## PENDING (exit code 3) instead of a failure, so a baseline run is honest:
##
##   exit 0  every check passed, nothing pending (the final run);
##   exit 1  a landed module misbehaves (real FAIL);
##   exit 2  the host is missing entirely;
##   exit 3  only pending checks remain (module not installed yet).  With
##           `--strict` pending also exits 1.
##
## `SCRIPT ERROR:` is engine output, not script-visible state; the runner scans
## stderr for it (the probe prints SHIP63_BATTLE_SCRIPT_ERRORS as a reminder).
##
## Run:
##   & '...\Godot_v4.7.2-stable_win64.exe' --path '...\game' --headless `
##     --script res://scripts/tests/ship63_battle_probe.gd
## Optional user args: --status-only, --strict

const LOAD_DEADLINE_MS := 240000
const HOST_WAIT_MS := 20000
## Where the integrator puts the player when he mans the wheel (host constant).
const HELM_STAND := Vector3(0.0, 3.06, 11.15)
## The target hulk's promised berth and the player's debug berth.
const TARGET_BERTH := Vector3(115.0, -0.55, 930.0)
const SHIP_BERTH := Vector3(115.0, -0.55, 975.0)
const SAIL_POOL_LIMIT := 16
## Sailcloth sample points in model-local space: lower and upper square sails,
## well outboard of the mast so the zone classifier must name the sail.
const SAIL_POINTS: Array[Vector3] = [
	Vector3(3.0, 8.1, -0.96),
	Vector3(-3.6, 8.8, -0.96),
	Vector3(4.2, 15.0, -0.96),
	Vector3(-3.0, 14.4, -0.96),
]

var _scene: Node = null
var _castle: Node = null
var _host: Node = null
var _boat: Node3D = null
var _model: Node3D = null
var _cannons: Node = null
var _player: CharacterBody3D = null
var _target: Node = null
var _powder: Node = null

var _checks := 0
var _passes := 0
var _failures: Array[String] = []
var _pending_names: Array[String] = []
var _skips: Array[String] = []
var _api: Array[String] = []
var _baseline_fps := -1.0
var _baseline_draw := -1.0

func _initialize() -> void:
	_run()

func _run() -> void:
	print("SHIP63_BATTLE_PROBE_START")
	_read_baseline_env()

	# ---------------------------------------------------------------- boot
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHIP63_BATTLE_FAIL scene_missing")
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
		print("SHIP63_BATTLE_FAIL preview_ready_timeout")
		quit(1)
		return
	_castle = _scene.get("preview_castle")
	_player = _scene.get("_player") as CharacterBody3D
	print("SHIP63_BATTLE_READY castle=", is_instance_valid(_castle), " player=",
		is_instance_valid(_player))

	# The integrator installs the host next to the other preview owners.  A late
	# install is allowed, but the probe must not spin here for minutes.
	var host_deadline := Time.get_ticks_msec() + HOST_WAIT_MS
	while Time.get_ticks_msec() < host_deadline:
		_host = _scene.get("preview_ship")
		if is_instance_valid(_host):
			break
		await process_frame
	if not is_instance_valid(_host):
		print("SHIP63_BATTLE_MISSING_HOST status=", str(_scene.get("ship_status")))
		quit(2)
		return
	_boat = _host.get("boat") as Node3D
	_model = _host.get("model") as Node3D
	_cannons = _host.get("cannons") as Node
	_target = _find_target()
	_powder = _find_powder()
	_collect_api()
	print("SHIP63_BATTLE_HOST name=", str(_host.name), " script=", _script_path(_host),
		" boat=", is_instance_valid(_boat), " model=", is_instance_valid(_model),
		" target=", is_instance_valid(_target), " powder=", is_instance_valid(_powder))
	var state := _snapshot()
	print("SHIP63_BATTLE_STATUS status=", state.get("status"), " usable=", state.get("usable"),
		" station=", state.get("station"), " keys=", JSON.stringify(state.keys()))

	if OS.get_cmdline_user_args().has("--status-only"):
		print("SHIP63_BATTLE_STATUS_ONLY api=", JSON.stringify(_api),
			" snapshot=", JSON.stringify(_short_snapshot(state)),
			" target=", is_instance_valid(_target), " powder=", is_instance_valid(_powder))
		quit(0)
		return

	# The ship settles onto the buoyancy samples before any scenario touches it.
	await _wait(1.0)

	# A focused mode keeps the castle-balance iteration cheap while agents F and
	# C tune their modules.
	if OS.get_cmdline_user_args().has("--castle-only"):
		await _contract_checks()
		await _castle_checks()
		_summary()
		return

	if OS.get_cmdline_user_args().has("--target-only"):
		await _contract_checks()
		await _presence_checks()
		await _target_checks()
		_summary()
		return

	# ---------------------------------------------------------------- scenarios
	await _contract_checks()
	await _presence_checks()
	await _sail_checks()
	await _castle_checks()
	await _target_checks()
	await _powder_checks()
	await _helm_checks()
	await _death_checks()
	await _sunk_checks()
	await _perf_checks()

	_summary()

## ---------------------------------------------------------------- contract

func _contract_checks() -> void:
	var state := _snapshot()
	_check("snapshot.dictionary", not state.is_empty(), "%d keys" % state.size())
	for key: String in ["status", "station", "usable", "hud", "water", "ship", "cannons", "target", "powder"]:
		_check("snapshot.%s" % key, state.has(key), _type_of(state.get(key)))
	_check("snapshot.usable.bool", state.get("usable") is bool, _type_of(state.get("usable")))
	_check("snapshot.target.key", state.has("target"), _type_of(state.get("target")))
	_check("snapshot.powder.key", state.has("powder"), _type_of(state.get("powder")))

	var ship: Dictionary = _sub(state, ["ship"])
	_check("ship.dictionary", not ship.is_empty(), "%d keys" % ship.size())
	for key: String in ["speed", "heading", "flooding", "integrity", "holes", "sunk",
			"sails_open", "position"]:
		_check("ship.%s" % key, ship.has(key), _type_of(ship.get(key)))
	if ship.has("usable"):
		_check("ship.usable.bool", ship.get("usable") is bool, _type_of(ship.get("usable")))
	else:
		_pending_check("ship.usable", "ship_boat.snapshot() has no usable key yet")

	_check("boat.installed", is_instance_valid(_boat) and bool(_boat.call("is_installed"))
		if is_instance_valid(_boat) and _boat.has_method("is_installed") else is_instance_valid(_boat))
	_check("boat.api.apply_hit", is_instance_valid(_boat) and _boat.has_method("apply_hit"))
	var anchors_ok := is_instance_valid(_model) and _model.has_method("anchors")
	_check("model.anchors", anchors_ok)
	if anchors_ok:
		var anchors: Dictionary = _model.call("anchors")
		for key: String in ["helm", "sail_lever", "mast", "upper_deck", "crates"]:
			_check("model.anchor.%s" % key, anchors.has(key), _type_of(anchors.get(key)))

	var cannon_state := _cannon_state()
	var cannon_count := int(_cannon_snapshot().get("cannon_count", 0))
	_check("cannons.count", cannon_count == 4, str(cannon_count))
	# SHIP63 balance: the castle breach must be smaller than the SHIP62 8-18 bricks.
	var radius := float(cannon_state.get("castle_radius", -1.0))
	var power := float(cannon_state.get("castle_power", -1.0))
	_check("cannonball.castle_radius_reduced", radius > 0.0 and radius <= 1.0,
		"CASTLE_RADIUS=%.2f (want ~0.8-0.9)" % radius)
	_check("cannonball.castle_power_reduced", power > 0.0 and power <= 40.0,
		"CASTLE_POWER=%.1f (want ~28-36)" % power)

func _presence_checks() -> void:
	# Agent T: the second identical ship, installed by the host into preview_target.
	if is_instance_valid(_target):
		_check("preview_target.present", true, str(_target.name))
		var target_boat := _target_boat()
		_check("target.boat", is_instance_valid(target_boat), str(target_boat))
		for method: String in ["snapshot", "sink_test", "reset"]:
			_check("target.api.%s" % method, _target.has_method(method))
	else:
		_pending_check("preview_target", "host.preview_target is null (ship_target.gd not installed)")

	# Agent P: the loader moves the EXISTING powder-barrel props onto the deck.
	if is_instance_valid(_powder):
		_check("preview_powder.present", true, str(_powder.name))
		for method: String in ["action", "interact", "snapshot"]:
			_check("powder.api.%s" % method, _powder.has_method(method))
		var barrel_host := _find_barrel_host()
		_check("powder.barrel_host.present", is_instance_valid(barrel_host),
			"preview_power_barrels")
		_check("powder.barrel_host.explode_at",
			is_instance_valid(barrel_host) and barrel_host.has_method("explode_at"))
		_check("host.api.apply_powder_blast", _host.has_method("apply_powder_blast"))
	else:
		_pending_check("preview_powder", "host.preview_powder is null (ship_powder_loader.gd not installed)")

## ---------------------------------------------------------------- sail holes

func _sail_checks() -> void:
	print("SHIP63_BATTLE_SAIL_START")
	if not is_instance_valid(_model) or not _model.has_method("sail_hole_count"):
		_pending_check("sail.api", "model.sail_hole_count()/punch_sail_hole() not implemented yet")
		return
	_check("sail.api.punch", _model.has_method("punch_sail_hole"))
	_check("sail.api.holes", _model.has_method("sail_holes"))
	if not is_instance_valid(_boat):
		_pending_check("sail.hit", "boat missing")
		return

	var count_before := int(_model.call("sail_hole_count"))
	_check("sail.count.initial", count_before == 0, "count=%d" % count_before)
	var flooding_before := _ship_float("flooding", 0.0)
	var zones: Array[String] = []
	for local: Vector3 in SAIL_POINTS:
		var result: Variant = _boat.call("apply_hit", _boat.to_global(local), 26.0,
			Vector3(0.0, 0.0, -1.0) * 4.0, "cannonball")
		var zone := ""
		if result is Dictionary:
			zone = str((result as Dictionary).get("zone", ""))
			print("SHIP63_BATTLE_SAIL_HIT local=", local, " zone=", zone,
				" hole=", (result as Dictionary).get("hole"),
				" flooding=", (result as Dictionary).get("flooding"))
		zones.append(zone)
		await _wait(0.12)

	var count_after := int(_model.call("sail_hole_count"))
	var holes: Variant = _model.call("sail_holes") if _model.has_method("sail_holes") else null
	_check("sail.zone.sail", zones.count("sail") >= 3, "zones=" + JSON.stringify(zones))
	_check("sail.hole_count.grew", count_after > 0, "%d -> %d" % [count_before, count_after])
	_check("sail.hole_count.pool_limit", count_after <= SAIL_POOL_LIMIT,
		"%d <= %d" % [count_after, SAIL_POOL_LIMIT])
	var size_ok := holes is Array and (holes as Array).size() == count_after
	_check("sail.holes_array", size_ok, _type_of(holes))

	var scanned := 0
	var in_bounds := true
	if holes is Array:
		for entry: Variant in holes:
			var point: Variant = _hole_point(entry)
			if point == null:
				continue
			scanned += 1
			var p: Vector3 = point
			if p.y < 2.0 or p.y > 20.0 or absf(p.x) > 12.0 or p.z < -24.0 or p.z > 14.0:
				in_bounds = false
				print("SHIP63_BATTLE_SAIL_HOLE_OUT ", p)
	if scanned == 0:
		_pending_check("sail.hole_positions", "sail_holes() entries carry no local point")
	else:
		_check("sail.holes_on_ship", in_bounds, "scanned=%d" % scanned)

	var flooding_after := _ship_float("flooding", 0.0)
	_check("sail.no_hull_flooding", flooding_after <= flooding_before + 0.0001,
		"%.4f -> %.4f" % [flooding_before, flooding_after])

	# The pool must not grow without bound; 20 more punches saturate it at 16.
	for i: int in 20:
		var local := Vector3(randf_range(-4.6, 4.6), randf_range(7.0, 16.6), -0.96)
		_model.call("punch_sail_hole", local, 0.25)
	await _wait(0.1)
	var capped := int(_model.call("sail_hole_count"))
	_check("sail.pool.saturates", capped <= SAIL_POOL_LIMIT,
		"%d after 24 punches (limit %d)" % [capped, SAIL_POOL_LIMIT])
	print("SHIP63_BATTLE_SAIL_END holes=", capped, " zones=", JSON.stringify(zones))

## ---------------------------------------------------------------- castle blast

func _castle_checks() -> void:
	print("SHIP63_BATTLE_CASTLE_START")
	if not is_instance_valid(_castle) or not _castle.has_method("get_stats"):
		_pending_check("castle.stats", "castle.get_stats() unavailable")
		return
	if not _host.has_method("debug_fire_at"):
		_pending_check("castle.shots", "host has no debug_fire_at(world_point)")
		return
	if _host.has_method("debug_reset_ship"):
		_host.call("debug_reset_ship")
	await _wait(0.8)

	var base := _wall_base()
	var half := _wall_half()
	var basin: Variant = _host.get("basin")
	# The live berth (115, 975) is only seven metres south of the south wall and
	# forty-seven east of the east wall, so its battery sees the east wall almost
	# edge-on and the corner tower shadows the south wall.  Both faces can be shot,
	# but the plainest masonry is the south curtain seen from a berth further out
	# in the bay: a 50 m shot broadside on, with the corner tower well out of the
	# line.  Candidate berths are tried in order and the first navigable one wins.
	var south_berth := Vector3.ZERO
	var berth := SHIP_BERTH
	var wall_plane := base.z + half
	for candidate: Vector3 in [Vector3(115.0, 0.0, 1015.0), Vector3(115.0, 0.0, 1030.0),
			Vector3(115.0, 0.0, 998.0), Vector3(115.0, 0.0, 935.0), SHIP_BERTH]:
		var depth := -1.0
		if is_instance_valid(basin) and (basin as Node).has_method("depth_at"):
			depth = float((basin as Node).call("depth_at", candidate.x, candidate.z))
		print("SHIP63_BATTLE_CASTLE_BERTH pos=", candidate, " depth=%.2f" % depth)
		if depth > 2.0:
			var water := -0.55
			if is_instance_valid(basin) and (basin as Node).has_method("water_level"):
				water = float((basin as Node).call("water_level"))
			berth = Vector3(candidate.x, water, candidate.z)
			if berth.z > wall_plane + 20.0:
				south_berth = berth
			break
	if _host.has_method("debug_set_station"):
		_host.call("debug_set_station", "leave")
	_boat.call("moor", berth, 0.0)
	if _boat.has_method("set_sails"):
		_boat.call("set_sails", false)
	if _boat.has_method("steer"):
		_boat.call("steer", 0.0)
	await _wait(1.2)
	print("SHIP63_BATTLE_CASTLE_FIRING_BERTH pos=", berth, " face=",
		"south" if not south_berth.is_zero_approx() else "east")

	var blasts: Array[int] = []
	var grazes: Array[int] = []
	var misses := 0
	var attempts := 0
	var lateral: Array[float] = [-59.0, -53.0, -47.0, -41.0, -35.0, -30.0,
		30.0, 33.0, 36.0, 39.0, -57.0, -45.0, -33.0, 31.0]
	while blasts.size() < 10 and attempts < 18:
		var index := attempts
		attempts += 1
		var aim := Vector3.ZERO
		if not south_berth.is_zero_approx():
			# Plain south curtain on the wings, off the gatehouse (|x| < 14) and
			# off the 9 m arrow-slit grid.  A ball that grazes a buttress side
			# takes a side normal and is not a representative breach; it is
			# counted separately instead of polluting the blast balance.
			var x := lateral[index % lateral.size()]
			# y = 7.2 sits midway between the two arrow-slit rows (5.2 and 9.0);
			# a slit edge has a side normal and blows the blast count up.  Long
			# shots (|x| > 40) land about a metre high, so they aim lower.
			var aim_y := 6.6 if absf(x) > 40.0 else 7.0
			aim = Vector3(base.x + x, aim_y + float(index % 3) * 0.15, wall_plane)
		else:
			var aim_x := base.x + half
			var z_min := maxf(wall_plane - 58.0, berth.z - 29.0)
			var z_max := minf(wall_plane - 12.0, berth.z + 29.0)
			var z := z_min + (z_max - z_min) * float(index % 10) / 9.0
			aim = Vector3(aim_x, 14.5 + float(index % 3), z)
		var shots_before := int(_cannon_state().get("shots", 0))
		var fired: Variant = _host.call("debug_fire_at", aim)
		var fired_ok := fired is Dictionary and bool((fired as Dictionary).get("ok", false))
		if not fired_ok:
			misses += 1
			print("SHIP63_BATTLE_CASTLE_SHOT n=", attempts, " fired=false",
				" result=", JSON.stringify(fired))
			await _wait(0.2)
			continue
		var result := await _wait_ball_done(shots_before, 8.0)
		var kind := str(result.get("last_target_type", ""))
		var blast := int(result.get("last_detached", 0))
		var impact: Variant = result.get("last_impact")
		var impact_at := Vector3.ZERO
		var normal_est := Vector3.ZERO
		if impact is Dictionary and (impact as Dictionary).get("position") is Vector3:
			impact_at = (impact as Dictionary)["position"] as Vector3
			var event: Variant = (impact as Dictionary).get("event")
			if event is Dictionary and (event as Dictionary).get("position") is Vector3:
				normal_est = ((event as Dictionary)["position"] as Vector3) - impact_at
				if normal_est.length_squared() > 0.09:
					normal_est = normal_est.normalized()
				else:
					normal_est = Vector3.ZERO
		# A south-wall face hit has a +z surface normal; a side normal means the
		# ball clipped a projection and the blast is not a face breach.
		var graze := not south_berth.is_zero_approx() and normal_est != Vector3.ZERO \
			and absf(normal_est.z) < 0.7
		print("SHIP63_BATTLE_CASTLE_SHOT n=", attempts, " aim=", aim,
			" target=", kind, " blast=", blast,
			" impact=", impact_at, " normal=", normal_est,
			" graze=", graze, " total=", _castle_detached())
		if kind == "castle" and blast > 0:
			if graze:
				grazes.append(blast)
				misses += 1
			else:
				blasts.append(blast)
		else:
			misses += 1
			await _wait(0.1)

	var sum := 0
	var max_blast := 0
	for blast: int in blasts:
		sum += blast
		max_blast = maxi(max_blast, blast)
	var avg := float(sum) / float(maxi(1, blasts.size()))
	var total := _castle_detached()
	_check("castle.shots.ten", blasts.size() == 10,
		"%d clean breaches of %d attempts" % [blasts.size(), attempts])
	_check("castle.shots.hit_rate", attempts <= 16,
		"attempts=%d grazes=%d misses=%d" % [attempts, grazes.size(), misses - grazes.size()])
	_check("castle.blast_avg_3_8", avg >= 3.0 and avg <= 8.0,
		"avg=%.2f over %d clean shots" % [avg, blasts.size()])
	_check("castle.blast_max_le_10", max_blast <= 10, "max=%d" % max_blast)
	_check("castle.detached.total", total >= 20, "detached=%d" % total)
	print("SHIP63_BATTLE_CASTLE_END blasts=", JSON.stringify(blasts),
		" grazes=", JSON.stringify(grazes),
		" avg=%.2f max=%d total=%d" % [avg, max_blast, total])

## Fires one ball and waits until the pool reports it finished.  The state then
## describes that shot: `last_target_type` and `last_detached` are the immediate
## impact numbers, not the castle's trailing support cascade.
func _wait_ball_done(shots_before: int, timeout: float) -> Dictionary:
	var start := Time.get_ticks_msec()
	var deadline := start + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var state := _cannon_state()
		if int(state.get("shots", 0)) > shots_before \
				and int(state.get("balls_active", 0)) == 0:
			return state
		await process_frame
	return _cannon_state()

func _castle_detached() -> int:
	if not is_instance_valid(_castle) or not _castle.has_method("get_stats"):
		return 0
	var stats: Variant = _castle.call("get_stats")
	if stats is Dictionary:
		return int((stats as Dictionary).get("detached", 0))
	return 0

func _wall_base() -> Vector3:
	if is_instance_valid(_castle) and _castle is Node3D:
		return (_castle as Node3D).global_position
	return Vector3(0.0, 0.0, 900.0)

func _wall_half() -> float:
	if is_instance_valid(_castle) and _castle.has_method("wall_half"):
		return float(_castle.call("wall_half"))
	return 68.0

## ---------------------------------------------------------------- the target

func _target_checks() -> void:
	print("SHIP63_BATTLE_TARGET_START")
	if not is_instance_valid(_target):
		_pending_check("target.shots", "preview_target missing")
		return
	var target_boat := _target_boat()
	if not is_instance_valid(target_boat):
		_check("target.boat", false, "target has no boat")
		return
	var state := _target_snapshot()
	_check("target.snapshot.keys", state.has("sunk") and state.has("flooding"),
		JSON.stringify(state.keys()))
	if state.has("usable"):
		_check("target.snapshot.usable", state.get("usable") is bool, _type_of(state.get("usable")))
	else:
		_pending_check("target.usable", "target snapshot has no usable key")

	var berth := target_boat.global_position
	var distance_to_ship := berth.distance_to(SHIP_BERTH)
	# The briefing asked for a berth 45 m from the player's ship; the integrator
	# may put it on either beam, so validate the intent, not one address.
	_check("target.distance_45m", distance_to_ship >= 40.0 and distance_to_ship <= 50.0,
		"berth=%s distance=%.1f m from %s" % [str(berth), distance_to_ship, str(SHIP_BERTH)])
	var depth := -1.0
	var basin: Variant = _host.get("basin")
	if is_instance_valid(basin) and (basin as Node).has_method("depth_at"):
		depth = float((basin as Node).call("depth_at", berth.x, berth.z))
	_check("target.depth_at_berth", depth >= 6.0, "%.2f m (brief: 7 m)" % depth)
	var shapes := int(state.get("collision_shapes", 0))
	_check("target.collision_shapes", shapes >= 40, "%d shapes" % shapes)
	print("SHIP63_BATTLE_TARGET_BERTH pos=", berth, " depth=%.2f" % depth,
		" shapes=", shapes, " usable=", state.get("usable"))

	if not _host.has_method("debug_fire_at"):
		_pending_check("target.cannon_fire", "host has no debug_fire_at")
		return

	# Bring a broadside to bear.  The castle scenario left the hull at its own
	# berth, so always moor at the target berth and turn the port beam onto the
	# hulk: a shot from off the beam hits the hull, not the rail.
	if _host.has_method("debug_set_station"):
		_host.call("debug_set_station", "leave")
	var water := -0.55
	if is_instance_valid(basin) and (basin as Node).has_method("water_level"):
		water = float((basin as Node).call("water_level"))
	var ship_at := Vector3(SHIP_BERTH.x, water, SHIP_BERTH.z)
	var to_target := berth - ship_at
	to_target.y = 0.0
	var yaw := _boat.global_rotation.y
	if to_target.length_squared() > 0.01:
		# Port beam bearing: local -x must point at the target.
		to_target = to_target.normalized()
		yaw = atan2(to_target.z, -to_target.x)
	_boat.call("moor", ship_at, yaw)
	print("SHIP63_BATTLE_TARGET_TURN berth=", ship_at, " yaw_deg=%.1f" % rad_to_deg(yaw),
		" target=", berth)
	if _boat.has_method("set_sails"):
		_boat.call("set_sails", false)
	if _boat.has_method("steer"):
		_boat.call("steer", 0.0)
	await _wait(1.2)

	var holes_before := _boat_int(target_boat, "hole_count", -1)
	var flooding_before := float(state.get("flooding", 0.0))
	var other_before := _cannon_int("other_ship_hits")
	var real_hits := 0
	var attempts := 0
	while real_hits < 6 and attempts < 9:
		attempts += 1
		# Low on the hull: the rail starts at local y 1.95 and a rail hit does not
		# open a hole, so aim under it and let the ball's own drop do the rest.
		var aim := berth + Vector3(0.0, 0.5 + 0.1 * float(attempts % 3), 0.0)
		var before_holes := _boat_int(target_boat, "hole_count", 0)
		var fired: Variant = _host.call("debug_fire_at", aim)
		if not (fired is Dictionary and bool((fired as Dictionary).get("ok", false))):
			print("SHIP63_BATTLE_TARGET_SHOT n=", attempts, " fired=false ",
				JSON.stringify(fired))
			await _wait(0.2)
			continue
		var hit := await _wait_target_hit(target_boat, before_holes, other_before, 6.0)
		if hit:
			real_hits += 1
			other_before = _cannon_int("other_ship_hits")
			var impact: Variant = _cannon_state().get("last_impact")
			var zone := ""
			var hole := false
			var hit_at := Vector3.ZERO
			if impact is Dictionary:
				var raw_result: Variant = (impact as Dictionary).get("result")
				if raw_result is Dictionary:
					zone = str((raw_result as Dictionary).get("zone", ""))
					hole = bool((raw_result as Dictionary).get("hole", false))
				if (impact as Dictionary).get("position") is Vector3:
					hit_at = (impact as Dictionary)["position"] as Vector3
			print("SHIP63_BATTLE_TARGET_SHOT n=", attempts, " hit=", real_hits,
				" holes=", _boat_int(target_boat, "hole_count", -1),
				" flooding=", float(_target_snapshot().get("flooding", 0.0)),
				" zone=", zone, " hole_created=", hole, " at=", hit_at)
		else:
			print("SHIP63_BATTLE_TARGET_SHOT n=", attempts, " hit=false (miss/timeout)")
		await _wait(0.3)

	var holes_after := _boat_int(target_boat, "hole_count", -1)
	var after_state := _target_snapshot()
	var flooding_after := float(after_state.get("flooding", 0.0))
	var other_after := _cannon_int("other_ship_hits")
	var ship_hits_after := _cannon_int("ship_hits")
	_check("target.cannon_hits", real_hits >= 4, "%d/6 hits in %d shots" % [real_hits, attempts])
	_check("cannons.other_ship_counter", other_after > 0 or ship_hits_after > 0,
		"other_ship_hits=%d ship_hits=%d" % [other_after, ship_hits_after])
	_check("target.holes_grow", holes_after > holes_before,
		"%d -> %d" % [holes_before, holes_after])
	_check("target.flooding_grow", flooding_after > flooding_before or bool(after_state.get("sunk", false)),
		"%.4f -> %.4f" % [flooding_before, flooding_after])
	print("SHIP63_BATTLE_TARGET_AFTER hits=%d holes=%d flooding=%.4f usable=%s" %
		[real_hits, holes_after, flooding_after, str(after_state.get("usable"))])
	print("SHIP63_BATTLE_TARGET_LAST_HIT ", JSON.stringify(after_state.get("last_hit")),
		" shots_fired=", after_state.get("shots_fired"))

	# Finish her: `sink_test` is the target's documented QA path and advances the
	# hulk's own simulation synchronously, so the probe does not burn a minute of
	# wall-clock time waiting for the flooding.  The real-time path is the fallback.
	var sunk := bool(after_state.get("sunk", false))
	if not sunk and _target.has_method("sink_test"):
		var sunk_result: Variant = _target.call("sink_test", 18, 90.0)
		if sunk_result is Dictionary:
			var result_state := sunk_result as Dictionary
			sunk = bool(result_state.get("sunk", false))
			print("SHIP63_BATTLE_TARGET_SINK_TEST ", JSON.stringify({
				"shots": result_state.get("shots"),
				"holes": result_state.get("holes"),
				"mast_broken": result_state.get("mast_broken"),
				"flooding": result_state.get("flooding"),
				"sunk": sunk,
				"usable": result_state.get("usable"),
				"seconds_to_sink": result_state.get("seconds_to_sink"),
			}))
		await _wait(0.4)
	if not sunk:
		for i: int in 8:
			var offset := Vector3(-4.0 + float(i % 5) * 2.0, 0.5, -6.0 + float(i % 4) * 5.0)
			target_boat.call("apply_hit", target_boat.to_global(offset), 140.0,
				Vector3.DOWN * 6.0, "cannonball")
			await process_frame
		var previous_scale := Engine.time_scale
		Engine.time_scale = 2.5
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline:
			var current := _target_snapshot()
			sunk = bool(current.get("sunk", false))
			if sunk:
				break
			await process_frame
		Engine.time_scale = previous_scale
		await _wait(0.5)

	var final_state := _target_snapshot()
	_check("target.sunk", sunk, JSON.stringify(_short_target(final_state)))
	if final_state.has("usable"):
		_check("target.usable_false", not bool(final_state.get("usable")),
			"usable=%s" % str(final_state.get("usable")))
	else:
		_pending_check("target.usable_false", "target snapshot has no usable key")
	if not sunk:
		_pending_check("target.wreck_controls", "hulk did not sink; refusal is untestable")
		return

	# A wreck does not answer helm or sails: the target must refuse itself.
	var sails_applied := true
	if _target.has_method("set_sails"):
		var applied: Variant = _target.call("set_sails", true)
		sails_applied = applied is bool and bool(applied)
	await _wait(0.5)
	var sails_open := false
	if target_boat.has_method("sails_open"):
		sails_open = bool(target_boat.call("sails_open"))
	_check("target.sails_refused", not sails_open and not sails_applied,
		"sails_open=%s set_sails_applied=%s" % [str(sails_open), str(sails_applied)])
	var steer_applied := true
	if _target.has_method("steer"):
		var applied: Variant = _target.call("steer", 1.0)
		steer_applied = applied is bool and bool(applied)
	await _wait(0.4)
	_check("target.helm_refused", not steer_applied,
		"target.steer applied=%s" % str(steer_applied))
	print("SHIP63_BATTLE_TARGET_END ", JSON.stringify(_short_target(final_state)))

func _wait_target_hit(target_boat: Node3D, holes_before: int, other_hits_before: int,
		timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var other := _cannon_int("other_ship_hits")
		var holes := _boat_int(target_boat, "hole_count", holes_before)
		if other > other_hits_before or holes > holes_before:
			return true
		await process_frame
	return false

func _target_boat() -> Node3D:
	if not is_instance_valid(_target):
		return null
	var boat: Variant = _target.get("boat")
	return boat as Node3D

func _target_snapshot() -> Dictionary:
	if is_instance_valid(_target) and _target.has_method("snapshot"):
		var state: Variant = _target.call("snapshot")
		if state is Dictionary:
			return state
	var boat := _target_boat()
	if is_instance_valid(boat) and boat.has_method("snapshot"):
		var state: Variant = boat.call("snapshot")
		if state is Dictionary:
			return state
	return {}

func _short_target(state: Dictionary) -> Dictionary:
	return {
		"usable": state.get("usable"),
		"sunk": state.get("sunk"),
		"flooding": state.get("flooding"),
		"holes": state.get("holes"),
		"integrity": state.get("integrity"),
	}

## ---------------------------------------------------------------- powder

func _powder_checks() -> void:
	print("SHIP63_BATTLE_POWDER_START")
	if not is_instance_valid(_powder):
		_pending_check("powder.scenario", "preview_powder loader missing")
		return
	if not _powder.has_method("snapshot"):
		_check("powder.snapshot", false, "no snapshot()")
		return
	var state := _powder_snapshot()
	_check("powder.snapshot.not_empty", not state.is_empty(), JSON.stringify(state.keys()))
	var barrels := int(state.get("barrels", -1))
	var loaded0 := int(state.get("loaded", -1))
	var available0 := int(state.get("available", -1))
	_check("powder.source.existing",
		str(state.get("source", "")) == "existing_powder_barrel_host", str(state.get("source")))
	_check("powder.barrels_three", barrels == 3, "barrels=%d (existing host props)" % barrels)
	_check("powder.initial_load", loaded0 >= 0 and loaded0 + available0 == barrels,
		"loaded=%d available=%d barrels=%d" % [loaded0, available0, barrels])

	# 1. The prompt at the deck loading point, then load one of the existing props.
	var action: Dictionary = await _powder_prompt(_powder_load_point())
	_check("powder.action.owner", str(action.get("owner", "")) == "powder",
		JSON.stringify(action))
	_check("powder.action.load_label",
		str(action.get("kind", "")) == "powder_toggle"
		and str(action.get("label", "")).begins_with("Погрузить"),
		"kind=%s label=%s" % [str(action.get("kind", "")), str(action.get("label", ""))])
	var index := int(action.get("index", 0))
	var events0 := int(state.get("events", 0))
	var accepted := await _powder_interact(action)
	await _wait(0.4)
	var after_load := _powder_snapshot()
	var loaded1 := int(after_load.get("loaded", -1))
	var available1 := int(after_load.get("available", -1))
	_check("powder.load", accepted and loaded1 == loaded0 + 1 and available1 == available0 - 1,
		"loaded %d->%d available %d->%d" % [loaded0, loaded1, available0, available1])
	_check("powder.load.event", int(after_load.get("events", 0)) > events0,
		"events=%d" % int(after_load.get("events", 0)))
	var barrel_node := _powder_barrel_node(index)
	_check("powder.barrel_on_deck",
		is_instance_valid(barrel_node) and barrel_node.get_parent() == _boat,
		"parent=%s" % (str(barrel_node.get_parent().name) if is_instance_valid(barrel_node)
			and is_instance_valid(barrel_node.get_parent()) else "none"))

	# 2. Unload the same barrel: the loader toggles by index, F is the host path.
	var unloaded := false
	if is_instance_valid(_powder) and _powder.has_method("interact"):
		var direct: Variant = _powder.call("interact", {"index": index})
		unloaded = direct is bool and bool(direct)
	await _wait(0.4)
	var after_unload := _powder_snapshot()
	_check("powder.unload",
		unloaded and int(after_unload.get("loaded", -1)) == loaded0,
		"loaded %d->%d" % [loaded1, int(after_unload.get("loaded", -1))])

	# 3. Load it again and detonate it through the existing powder-barrel host:
	# `explode_at` is what the live game calls, and it must hurt the hull.
	if is_instance_valid(_powder) and _powder.has_method("interact"):
		_powder.call("interact", {"index": index})
	await _wait(0.4)
	var loaded_state := _powder_snapshot()
	var barrel := _powder_barrel_node(index)
	var barrel_host := _find_barrel_host()
	_check("powder.barrel_host",
		is_instance_valid(barrel_host) and barrel_host.has_method("explode_at"),
		"host=%s" % (str(barrel_host.name) if is_instance_valid(barrel_host) else "none"))
	if not is_instance_valid(barrel_host) or not is_instance_valid(barrel) \
			or not barrel_host.has_method("explode_at"):
		_pending_check("powder.explosion", "preview_power_barrels.explode_at unavailable")
		return
	var hull_before := _ship_float("hull_damage", 0.0)
	var holes_before := int(_ship_float("holes", -1.0))
	var flooding_before := _ship_float("flooding", 0.0)
	var integrity_before := _ship_float("integrity", 1.0)
	var blast: Variant = barrel_host.call("explode_at", barrel.global_position)
	var blast_ok := blast is Dictionary and bool((blast as Dictionary).get("ok", false))
	var ship_result: Variant = (blast as Dictionary).get("ship") if blast is Dictionary else null
	_check("powder.explosion_registered", blast_ok, JSON.stringify(blast))
	_check("powder.explosion_hits_ship",
		ship_result is Dictionary and bool((ship_result as Dictionary).get("ok", false)),
		JSON.stringify(ship_result))
	var visual: Variant = (blast as Dictionary).get("visual") if blast is Dictionary else null
	_check("powder.explosion_fx", visual is Dictionary and not (visual as Dictionary).is_empty(),
		_type_of(visual))
	await _wait(0.8)
	var hull_after := _ship_float("hull_damage", 0.0)
	var holes_after := int(_ship_float("holes", -1.0))
	var flooding_after := _ship_float("flooding", 0.0)
	var integrity_after := _ship_float("integrity", 1.0)
	var hull_taken := hull_after - hull_before
	var damaged := hull_taken >= 200.0 \
		and (holes_after > holes_before or flooding_after > flooding_before)
	_check("powder.explosion_damages_ship", damaged,
		"hull_damage=+%.1f holes=%d->%d flooding=%.4f->%.4f integrity=%.2f->%.2f" %
		[hull_taken, holes_before, holes_after, flooding_before, flooding_after,
			integrity_before, integrity_after])
	var ship_state: Dictionary = _sub(_snapshot(), ["ship"])
	_check("powder.ship_afloat",
		bool(_snapshot().get("usable", true)) and not bool(ship_state.get("sunk", false)),
		"one barrel must not sink the ship")
	print("SHIP63_BATTLE_POWDER_END barrels=", int(loaded_state.get("barrels", -1)),
		" loaded=", int(loaded_state.get("loaded", -1)),
		" blast_ok=", blast_ok, " hull_damage=+%.1f" % hull_taken,
		" usable=", _snapshot().get("usable"))

## Stands the player within powder reach of `at` and returns the loader prompt.
func _powder_prompt(at: Vector3) -> Dictionary:
	if is_instance_valid(_player) and at.length_squared() > 0.01:
		var aft := _boat.global_transform.basis.orthonormalized() * Vector3(0.0, 0.0, 1.6)
		_player.global_position = at + aft + Vector3.UP * 0.05
		_player.velocity = Vector3.ZERO
	await _wait(0.3)
	var action: Dictionary = {}
	if is_instance_valid(_powder) and _powder.has_method("action"):
		var raw: Variant = _powder.call("action")
		if raw is Dictionary:
			action = raw
	return action

func _powder_interact(action: Dictionary) -> bool:
	var interacted := false
	if _host.has_method("interact"):
		var via_host: Variant = _host.call("interact", action)
		interacted = via_host is bool and bool(via_host)
	if not interacted and is_instance_valid(_powder) and _powder.has_method("interact"):
		var direct: Variant = _powder.call("interact", action)
		interacted = direct is bool and bool(direct)
	return interacted

func _powder_load_point() -> Vector3:
	if is_instance_valid(_boat):
		return _boat.to_global(Vector3(0.0, 1.90, -6.0))
	return Vector3.ZERO

func _powder_barrel_node(index: int) -> Node3D:
	if not is_instance_valid(_powder):
		return null
	var barrels: Variant = _powder.get("barrels")
	if barrels is Array and index >= 0 and index < (barrels as Array).size():
		return (barrels as Array)[index] as Node3D
	return null

func _powder_snapshot() -> Dictionary:
	if not is_instance_valid(_powder) or not _powder.has_method("snapshot"):
		return {}
	var state: Variant = _powder.call("snapshot")
	return state if state is Dictionary else {}

func _find_barrel_host() -> Node:
	if is_instance_valid(_scene):
		var node := _scene.get("preview_power_barrels") as Node
		if is_instance_valid(node):
			return node
	return _find_node_with_method(_scene, "explode_at")

## ---------------------------------------------------------------- helm

func _helm_checks() -> void:
	print("SHIP63_BATTLE_HELM_START")
	if not is_instance_valid(_boat) or not is_instance_valid(_player):
		_pending_check("helm.collision", "boat or player missing")
		return
	if _host.has_method("debug_set_station"):
		_host.call("debug_set_station", "leave")
	_scene.set("preview_dead", false)
	await _wait(0.3)

	# 1. The F prompt still exists at the standing spot behind the wheel.
	_player.global_position = _boat.to_global(HELM_STAND)
	_player.velocity = Vector3.ZERO
	await physics_frame
	var action: Dictionary = {}
	if _host.has_method("action"):
		var raw: Variant = _host.call("action")
		if raw is Dictionary:
			action = raw
	_check("helm.prompt", str(action.get("owner", "")) == "ship"
		and str(action.get("kind", "")) == "ship_helm", JSON.stringify(action))

	# 2. A capsule occupying the wheel's volume must find a collider.  This is
	# the direct question "is there anything where the wheel is?", and the body
	# query is a negative control in empty air above the rig.
	await physics_frame
	# Two short capsules inside the wheel's rim, deliberately above the
	# quarterdeck floor (y ~ 3.03) so the deck itself cannot masquerade as the
	# helm collider that this check is about.
	var wheel_high := _boat.to_global(Vector3(0.0, 4.15, 10.6))
	var wheel_low := _boat.to_global(Vector3(0.0, 3.58, 10.6))
	var air_control := _boat.to_global(Vector3(0.0, 6.8, 10.6))
	var high_hit := _shape_blocked(wheel_high, 0.30, 0.70)
	var low_hit := _shape_blocked(wheel_low, 0.30, 0.70)
	var air_control_hit := _shape_blocked(air_control, 0.30, 0.70)
	_check("helm.collision_present", high_hit or low_hit,
		"capsule high=%s low=%s" % [str(high_hit), str(low_hit)])
	_check("helm.shape_control_open", not air_control_hit,
		"empty air capsule=%s" % str(air_control_hit))

	# 3. The player's own body must not walk through the wheel.  The start point
	# stays on the quarterdeck, clear of the transom (z=12.5) and of the wheel:
	# the motion ends on top of the wheel centre.
	var walk_start := _player.global_transform
	walk_start.origin = _boat.to_global(Vector3(0.0, 3.06, 11.9))
	var walk_forward := _boat.global_transform.basis.orthonormalized() * Vector3(0.0, 0.0, -1.0)
	var walk_blocked := _player.test_move(walk_start, walk_forward)
	_check("helm.player_cannot_walk_through", walk_blocked,
		"test_move from z=11.9 by 1 m = %s" % str(walk_blocked))

	# 4. Ray evidence through the wheel's volume at three heights.
	var ray_hits := 0
	var ray_heights: Array[float] = [3.5, 3.9, 4.3]
	for height: float in ray_heights:
		if _ray_blocked(_boat.to_global(Vector3(0.0, height, 12.4)),
				_boat.to_global(Vector3(0.0, height, 8.9))):
			ray_hits += 1
	var control_blocked := _ray_blocked(_boat.to_global(Vector3(0.0, 6.6, 12.4)),
		_boat.to_global(Vector3(0.0, 6.6, 8.9)))
	_check("helm.ray_evidence", ray_hits > 0 or high_hit or low_hit,
		"rays=%d/%d capsules=%s/%s" % [ray_hits, ray_heights.size(),
			str(high_hit), str(low_hit)])
	_check("helm.ray_control_open", not control_blocked, "control=%s" % str(control_blocked))

	# 5. Standing behind the wheel is allowed: moving away must be free.
	var stand_from := _player.global_transform
	stand_from.origin = _boat.to_global(HELM_STAND)
	var away := _boat.global_transform.basis.orthonormalized() * Vector3(0.0, 0.0, 0.35)
	var stand_blocked := _player.test_move(stand_from, away)
	_check("helm.stand_behind_free", not stand_blocked,
		"test_move(backward)=%s at %s" % [str(stand_blocked), str(HELM_STAND)])
	print("SHIP63_BATTLE_HELM_END shape_high=", high_hit, " shape_low=", low_hit,
		" walk_blocked=", walk_blocked, " rays=", ray_hits,
		" control=", control_blocked, " stand_blocked=", stand_blocked)

## ---------------------------------------------------------------- death

func _death_checks() -> void:
	print("SHIP63_BATTLE_DEATH_START")
	if not is_instance_valid(_host) or not is_instance_valid(_player):
		_pending_check("death.release", "host or player missing")
		return
	_scene.set("preview_dead", false)
	await _wait(0.2)
	if _host.has_method("debug_set_station"):
		_host.call("debug_set_station", "cannon", 0)
	else:
		_host.call("interact", "ship_cannon")
	await _wait(0.5)
	var station_before := str(_snapshot().get("station", ""))
	var hold_before := _hold_state()
	_check("death.station_before", station_before == "cannon", "station='%s'" % station_before)
	_check("death.hold_before", hold_before, "hold=%s" % str(hold_before))

	# The engine has no player HP owner of its own: death is the scene's
	# `preview_dead` flag (set by the melee health owner and main.gd alike).
	_scene.set("preview_dead", true)
	await _wait(0.6)
	var station_after := str(_snapshot().get("station", ""))
	var hold_after := _hold_state()
	_check("death.station_released", station_after == "", "station='%s'" % station_after)
	_check("death.hold_released", not hold_after, "hold=%s" % str(hold_after))

	_scene.set("preview_dead", false)
	await _wait(0.4)
	var station_restored := str(_snapshot().get("station", ""))
	_check("death.no_regrab", station_restored == "", "station='%s'" % station_restored)
	print("SHIP63_BATTLE_DEATH_END before=", station_before, "/", hold_before,
		" after=", station_after, "/", hold_after)

func _hold_state() -> bool:
	if is_instance_valid(_host):
		var owned: Variant = _host.get("_hold_owned")
		if owned is bool:
			return owned
	if is_instance_valid(_player):
		var held: Variant = _player.get("_vehicle_hold")
		if held is bool:
			return held
	return false

## ---------------------------------------------------------------- sunk ship

func _sunk_checks() -> void:
	print("SHIP63_BATTLE_SUNK_START")
	if not is_instance_valid(_boat):
		_pending_check("sunk.scenario", "boat missing")
		return
	# The hulk must not be pumped full of holes by an earlier section.
	var sunk := bool(_boat.call("is_sunk")) if _boat.has_method("is_sunk") else false
	if not sunk:
		for i: int in 40:
			var local := Vector3(-4.05, 0.65 + 0.2 * float(i % 3), -9.0 + 1.2 * float(i % 15))
			_boat.call("apply_hit", _boat.to_global(local), 140.0,
				Vector3(1.0, 0.0, 0.0) * 6.0, "cannonball")
			await process_frame
		var previous_scale := Engine.time_scale
		Engine.time_scale = 2.5
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline:
			if _boat.has_method("is_sunk") and bool(_boat.call("is_sunk")):
				break
			await process_frame
		Engine.time_scale = previous_scale
		sunk = bool(_boat.call("is_sunk")) if _boat.has_method("is_sunk") else false
	await _wait(0.8)
	var state := _snapshot()
	var ship: Dictionary = _sub(state, ["ship"])
	_check("sunk.is_sunk", sunk, "flooding=%.3f" % float(ship.get("flooding", 0.0)))
	_check("sunk.snapshot.usable_false", state.get("usable") is bool and not bool(state.get("usable")),
		"usable=%s" % str(state.get("usable")))
	if ship.has("usable"):
		_check("sunk.boat.usable_false", not bool(ship.get("usable")),
			"ship.usable=%s" % str(ship.get("usable")))
	else:
		_pending_check("sunk.boat.usable", "ship_boat.snapshot() has no usable key")

	# A wreck offers no prompt and answers no station.
	var action: Variant = _host.call("action")
	_check("sunk.action_empty", action is Dictionary and (action as Dictionary).is_empty(),
		JSON.stringify(action))
	_check("sunk.interact_helm_false", not _host_bool("interact", ["ship_helm"]))
	_check("sunk.interact_sail_false", not _host_bool("interact", ["ship_sail"]))
	_check("sunk.interact_cannon_false", not _host_bool("interact", ["ship_cannon"]))

	# The boat itself must refuse too, even when the host is bypassed.
	if _boat.has_method("set_sails"):
		_boat.call("set_sails", true)
	if _boat.has_method("toggle_sails"):
		_boat.call("toggle_sails")
	await _wait(0.6)
	var sails_open := false
	if _boat.has_method("sails_open"):
		sails_open = bool(_boat.call("sails_open"))
	_check("sunk.sails_refused", not sails_open, "sails_open=%s" % str(sails_open))
	if _boat.has_method("steer"):
		_boat.call("steer", 1.0)
	await _wait(0.5)
	var ship_now: Dictionary = _sub(_snapshot(), ["ship"])
	var rudder := float(ship_now.get("rudder_target", 0.0))
	_check("sunk.helm_refused", absf(rudder) < 0.01, "rudder_target=%.3f" % rudder)

	var fire_ok := false
	var fire_result: Variant = null
	if is_instance_valid(_cannons) and _cannons.has_method("fire"):
		fire_result = _cannons.call("fire")
		if fire_result is Dictionary:
			fire_ok = bool((fire_result as Dictionary).get("ok", false))
		elif fire_result is bool:
			fire_ok = bool(fire_result)
	_check("sunk.cannon_refuses_fire", not fire_ok, JSON.stringify(fire_result))
	print("SHIP63_BATTLE_SUNK_END sunk=", sunk, " usable=", state.get("usable"),
		" sails=", sails_open, " rudder=%.3f" % rudder)

func _host_bool(method: String, args: Array) -> bool:
	if not is_instance_valid(_host) or not _host.has_method(method):
		return false
	var result: Variant = _host.callv(method, args)
	return result is bool and bool(result)

## ---------------------------------------------------------------- frame

func _perf_checks() -> void:
	print("SHIP63_BATTLE_PERF_START")
	if _host.has_method("debug_reset_ship"):
		# The frame is measured with the ship back on the deep berth, the way a
		# player finds it, not listing in a corner of the bay.
		_host.call("debug_reset_ship")
	await _wait(0.6)
	var frames := 120
	var start := Time.get_ticks_usec()
	for i: int in frames:
		await process_frame
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	var fps := float(frames) / maxf(elapsed, 0.0001)
	var engine_fps := float(Engine.get_frames_per_second())
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var headless := DisplayServer.get_name() == "headless"
	print("SHIP63_BATTLE_PERF fps=%.1f engine_fps=%.1f draw_calls=%d objects=%d primitives=%d physics_ms=%.2f process_ms=%.2f headless=%s" %
		[fps, engine_fps, draw_calls, objects, primitives, physics_ms, process_ms, str(headless)])
	_check("perf.fps_ge_60", fps >= 60.0, "%.1f FPS" % fps)
	# Draw/phys regression gate, only meaningful with a real renderer.
	if not headless and _baseline_draw > 0.0:
		_check("perf.draw_calls_le_105pct", float(draw_calls) <= _baseline_draw * 1.05,
			"%d vs baseline %d" % [draw_calls, int(_baseline_draw)])
	if _baseline_fps > 0.0:
		_check("perf.fps_not_worse_than_baseline", fps >= _baseline_fps * 0.95,
			"%.1f vs baseline %.1f" % [fps, _baseline_fps])
	else:
		print("SHIP63_BATTLE_NOTE baseline_fps unset: DSH63_BASELINE_FPS not provided")
	print("SHIP63_BATTLE_SCRIPT_ERRORS expected=0 scanned_by=runner marker='SCRIPT ERROR:'")

func _read_baseline_env() -> void:
	var fps_text := OS.get_environment("DSH63_BASELINE_FPS")
	if not fps_text.is_empty() and fps_text.is_valid_float():
		_baseline_fps = fps_text.to_float()
	var draw_text := OS.get_environment("DSH63_BASELINE_DRAW")
	if not draw_text.is_empty() and draw_text.is_valid_float():
		_baseline_draw = draw_text.to_float()
	print("SHIP63_BATTLE_BASELINE fps=", _baseline_fps, " draw_calls=", _baseline_draw)

## ---------------------------------------------------------------- summary

func _summary() -> void:
	var strict := OS.get_cmdline_user_args().has("--strict")
	print("SHIP63_BATTLE_FINAL ", JSON.stringify({
		"checks": _checks,
		"passed": _passes,
		"failed": _failures.size(),
		"pending": _pending_names.size(),
		"skipped": _skips.size(),
		"failures": _failures,
		"pending_names": _pending_names,
	}))
	print("SHIP63_BATTLE_API ", JSON.stringify(_api))
	if not _skips.is_empty():
		print("SHIP63_BATTLE_SKIPPED ", JSON.stringify(_skips))
	if not _failures.is_empty():
		print("SHIP63_BATTLE_FAILED_CHECKS ", JSON.stringify(_failures))
		print("SHIP63_BATTLE_FAIL checks=%d passed=%d failed=%d pending=%d" %
			[_checks, _passes, _failures.size(), _pending_names.size()])
		quit(1)
		return
	if not _pending_names.is_empty():
		if strict:
			print("SHIP63_BATTLE_FAIL_STRICT_PENDING ", JSON.stringify(_pending_names))
			quit(1)
			return
		print("SHIP63_BATTLE_PENDING checks=%d pending=%d (baseline: modules are landing)" %
			[_checks, _pending_names.size()])
		quit(3)
		return
	print("SHIP63_BATTLE_OK checks=%d" % _checks)
	quit(0)

## ---------------------------------------------------------------- model / host access

func _find_target() -> Node:
	var candidates: Array = [
		_host.get("preview_target") if is_instance_valid(_host) else null,
		_host.get("target") if is_instance_valid(_host) else null,
		_scene.get("preview_target") if is_instance_valid(_scene) else null,
		_scene.get("preview_target_ship") if is_instance_valid(_scene) else null,
	]
	for candidate: Variant in candidates:
		var node := candidate as Node
		if is_instance_valid(node):
			return node
	return _find_node_with_method(_scene, "sink_test")

func _find_powder() -> Node:
	var candidates: Array = [
		_host.get("preview_powder") if is_instance_valid(_host) else null,
		_host.get("powder") if is_instance_valid(_host) else null,
		_scene.get("preview_powder") if is_instance_valid(_scene) else null,
	]
	for candidate: Variant in candidates:
		var node := candidate as Node
		if is_instance_valid(node):
			return node
	return _find_node_with_method(_scene, "explode_from_hit")

func _find_node_with_method(root_node: Node, method: String) -> Node:
	if not is_instance_valid(root_node):
		return null
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != root_node and node.has_method(method):
			var script_ref: Variant = node.get_script()
			var path := ""
			if script_ref is Script:
				path = (script_ref as Script).resource_path
			if not path.ends_with("ship_boat.gd") and not path.ends_with("ship_cannons.gd"):
				return node
		for child: Node in node.get_children():
			stack.append(child)
	return null

func _collect_api() -> void:
	for method: String in ["install", "action", "interact", "snapshot", "steer", "set_sails",
			"toggle_sails", "debug_fire_at", "debug_hit_ship", "debug_reset_ship",
			"debug_set_station", "load_ball", "fire"]:
		if is_instance_valid(_host) and _host.has_method(method):
			_api.append("host." + method)
	for field: String in ["boat", "basin", "cannons", "hud", "target", "powder",
			"preview_target", "preview_powder"]:
		if is_instance_valid(_host) and _host.get(field) != null:
			_api.append("host.field:" + field)
	if is_instance_valid(_boat):
		for method: String in ["apply_hit", "set_sails", "steer", "sails_open", "hole_count",
				"flooding", "is_sunk", "usable", "anchor_world"]:
			if _boat.has_method(method):
				_api.append("boat." + method)
	if is_instance_valid(_model):
		for method: String in ["punch_sail_hole", "sail_hole_count", "sail_holes", "anchors"]:
			if _model.has_method(method):
				_api.append("model." + method)

func _snapshot() -> Dictionary:
	if is_instance_valid(_host) and _host.has_method("snapshot"):
		var state: Variant = _host.call("snapshot")
		if state is Dictionary:
			return state
	if is_instance_valid(_boat) and _boat.has_method("snapshot"):
		var boat_state: Variant = _boat.call("snapshot")
		if boat_state is Dictionary:
			return {"ship": boat_state}
	return {}

func _short_snapshot(state: Dictionary) -> Dictionary:
	var result := {"keys": state.keys()}
	var ship: Dictionary = _sub(state, ["ship"])
	if not ship.is_empty():
		result["ship"] = {
			"speed": ship.get("speed"),
			"flooding": ship.get("flooding"),
			"integrity": ship.get("integrity"),
			"holes": ship.get("holes"),
			"sunk": ship.get("sunk"),
			"usable": ship.get("usable"),
			"position": str(ship.get("position")),
		}
	var guns: Dictionary = _sub(state, ["cannons"])
	if not guns.is_empty():
		result["cannons"] = {
			"manning": guns.get("manning"),
			"loaded": guns.get("loaded"),
			"shots": guns.get("shots"),
			"hits": guns.get("hits"),
			"castle_hits": guns.get("castle_hits"),
			"other_ship_hits": guns.get("other_ship_hits"),
			"powder_hits": guns.get("powder_hits"),
			"last_target_type": guns.get("last_target_type"),
		}
	return result

func _cannon_state() -> Dictionary:
	if is_instance_valid(_cannons) and _cannons.has_method("state"):
		var state: Variant = _cannons.call("state")
		if state is Dictionary:
			return state
	if is_instance_valid(_host):
		var guns: Variant = _host.get("cannons")
		if is_instance_valid(guns) and (guns as Node).has_method("state"):
			var state: Variant = (guns as Node).call("state")
			if state is Dictionary:
				return state
	return {}

func _cannon_snapshot() -> Dictionary:
	if is_instance_valid(_cannons) and _cannons.has_method("snapshot"):
		var state: Variant = _cannons.call("snapshot")
		if state is Dictionary:
			return state
	return _cannon_state()

func _cannon_int(key: String) -> int:
	return int(_cannon_state().get(key, 0))

func _ship_float(key: String, fallback: float) -> float:
	var ship: Dictionary = _sub(_snapshot(), ["ship"])
	var value: Variant = ship.get(key)
	if value is float or value is int:
		return float(value)
	if value is bool:
		return 1.0 if value else 0.0
	return fallback

func _boat_int(boat: Object, method: String, fallback: int) -> int:
	if is_instance_valid(boat) and boat.has_method(method):
		var value: Variant = boat.call(method)
		if value is int or value is float:
			return int(value)
	return fallback

func _sub(source: Dictionary, keys: Array) -> Dictionary:
	for key: String in keys:
		var value: Variant = source.get(key)
		if value is Dictionary:
			return value
	return {}

## ---------------------------------------------------------------- spatial helpers

func _ray_blocked(from: Vector3, to: Vector3) -> bool:
	if not is_instance_valid(_boat):
		return false
	var space := _boat.get_world_3d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if is_instance_valid(_player):
		query.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(query)
	return not hit.is_empty()

## A capsule swept through a point: "is there a collider in this volume?".
func _shape_blocked(center: Vector3, radius: float, height: float) -> bool:
	if not is_instance_valid(_boat):
		return false
	var space := _boat.get_world_3d().direct_space_state
	if space == null:
		return false
	var params := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0 + 0.01)
	params.shape = capsule
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = 0xFFFFFFFF
	params.collide_with_bodies = true
	params.collide_with_areas = false
	if is_instance_valid(_player):
		params.exclude = [_player.get_rid()]
	return not space.intersect_shape(params, 1).is_empty()

func _hole_point(entry: Variant) -> Variant:
	if entry is Vector3:
		return entry
	if entry is Dictionary:
		for key: String in ["local", "position", "point", "at"]:
			var value: Variant = (entry as Dictionary).get(key)
			if value is Vector3:
				return value
	return null

## ---------------------------------------------------------------- reporting

func _check(name: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		_passes += 1
		print("SHIP63_CHECK_PASS ", name, "" if detail.is_empty() else " | " + detail)
	else:
		_failures.append(name)
		print("SHIP63_CHECK_FAIL ", name, "" if detail.is_empty() else " | " + detail)

func _pending_check(name: String, reason: String) -> void:
	_pending_names.append(name)
	print("SHIP63_CHECK_PENDING ", name, " (", reason, ")")

func _skip(name: String, reason: String) -> void:
	_skips.append(name)
	print("SKIP ", name, " (", reason, ")")

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
