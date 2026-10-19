extends SceneTree
## Detour budget probe: proves the new --city-detour-* levers are inert by default
## and observable when asked for, without needing a live city or a navigation map.
##
## SceneTree script (no scene is loaded). Run twice:
##   ... --script res://scripts/tests/detour_budget_probe.gd
##       -> default path: no DSH_DETOUR line at all, budget == the file constants
##   ... --script res://scripts/tests/detour_budget_probe.gd -- \
##         --city-detour-budget=1 --city-detour-attempts=1920 --city-detour-max-nodes=480 \
##         --city-detour-cell-m=1.0 --city-detour-range-m=12.0
##       -> instrumentation prints, budget reflects the arguments
##
## It never builds a search: it only reads the resolved budget, the byte-identical
## default path, and the telemetry line for an exhausted verdict.

const Detour = preload("res://scripts/city/runtime/npc_native_obstacle_detour.gd")
const DEFAULT_CELL := 1.25
const DEFAULT_RANGE := 8.0
const DEFAULT_NODES := 160
const DEFAULT_CHECKS := 640
const DEFAULT_FRAMES := 240

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var detour: RefCounted = Detour.new()
	if detour == null:
		print("DETOUR_PROBE FAIL instance_null")
		quit(1)
		return
	var budget: Dictionary = Detour.budget()
	var args := OS.get_cmdline_user_args()
	var flagged := args.has("--city-detour-budget=1")
	var ok := true
	# 1. The resolved budget must equal the file's own constants when no argument is given.
	if not flagged:
		ok = ok and is_equal_approx(float(budget["cell_m"]), DEFAULT_CELL)
		ok = ok and is_equal_approx(float(budget["range_m"]), DEFAULT_RANGE)
		ok = ok and int(budget["max_nodes"]) == DEFAULT_NODES
		ok = ok and int(budget["max_checks"]) == DEFAULT_CHECKS
		ok = ok and int(budget["max_frames"]) == DEFAULT_FRAMES
		ok = ok and int(detour.get("_checks")) == 0 and int(detour.get("_nodes").size()) <= 1
		print("DETOUR_PROBE mode=default on=", budget["on"],
			" cell=", budget["cell_m"], " range=", budget["range_m"],
			" nodes=", budget["max_nodes"], " checks=", budget["max_checks"],
			" frames=", budget["max_frames"],
			" fresh_checks=", detour.get("_checks"), " fresh_nodes=", detour.get("_nodes").size(),
			" status=", detour.get("_status"), " ok=", ok)
	else:
		ok = ok and budget["on"] == true
		ok = ok and int(budget["max_checks"]) == int(_arg_int("--city-detour-attempts=", DEFAULT_CHECKS))
		ok = ok and int(budget["max_nodes"]) == int(_arg_int("--city-detour-max-nodes=", DEFAULT_NODES))
		ok = ok and is_equal_approx(float(budget["cell_m"]), float(_arg_float("--city-detour-cell-m=", DEFAULT_CELL)))
		ok = ok and is_equal_approx(float(budget["range_m"]), float(_arg_float("--city-detour-range-m=", DEFAULT_RANGE)))
		print("DETOUR_PROBE mode=flagged on=", budget["on"],
			" cell=", budget["cell_m"], " range=", budget["range_m"],
			" nodes=", budget["max_nodes"], " checks=", budget["max_checks"],
			" frames=", budget["max_frames"], " ok=", ok)
		# 2. Telemetry must appear for an exhausted verdict and must not claim success.
		detour._exhausted = true
		detour._checks = 512
		detour._frames = 180
		var failed: Dictionary = detour._fail("bounded_native_detour_exhausted")
		detour._dsh_report(Engine.get_physics_frames())
		# 3. The neighbour breakdown must render with per-class counters and an explicit
		#    policy state. Synthetic: no map, no policy, no native work happens here.
		detour._nodes = [{"point": Vector3.ZERO, "key": Vector2i.ZERO, "g": 0.0, "parent": -1, "closed": false}]
		detour._active = 0
		detour._goals = [{"point": Vector3(0, 0, 3), "index": 1}]
		detour._first_seen = false
		detour._emit_neigh = true
		detour._rejected = {"outside_range": 1, "off_native_map": 3, "native_clear_refused": 4, "policy:current_square_overlap": 4}
		detour._dsh_report(Engine.get_physics_frames())
		var counters: Dictionary = Detour.counters()
		ok = ok and failed.get("reason") == "bounded_native_detour_exhausted"
		ok = ok and int(counters["searches_exhausted"]) >= 1
		ok = ok and int(counters["searches_ok"]) == 0
		ok = ok and str(counters["neighbour_rejections_text"]).contains("native_clear_refused")
		print("DETOUR_PROBE counters=", JSON.stringify(counters), " ok=", ok)
	print("DETOUR_PROBE_RESULT ok=", ok)
	quit(0 if ok else 1)

func _arg_int(prefix: String, fallback: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return int(argument.trim_prefix(prefix))
	return fallback

func _arg_float(prefix: String, fallback: float) -> float:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return float(argument.trim_prefix(prefix))
	return fallback
