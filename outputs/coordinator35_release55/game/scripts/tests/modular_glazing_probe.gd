extends SceneTree
## DSH_CITYTOWN diagnostic (read-only): why is the ported restaurant's
## `OwnedWindowGlazing` not live after `modular_building_site.prepare()`?
##
## The instantiator adds the site to the world and only THEN assigns its final
## global frame. `palazzo_glazing.configure()` captures `_site_frame` at
## configure time, and `_current()` requires `site.global_transform == _site_frame`
## forever after. This probe prints the captured frame, the real frame, the
## site's own `_finished_errors`/`site_error` and the pane counts, so the
## hypothesis is verified instead of assumed.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <game> \
##     --script res://scripts/tests/modular_glazing_probe.gd
## Nothing in main.gd, palazzo/** or modular30/** is touched.

const Restaurant = preload("res://scripts/destruction/restaurant/restaurant_site.gd")
const Hospital = preload("res://scripts/destruction/hospital_site/hospital_site.gd")
const SETTLE_FRAMES := 12

var _world: Node3D
var _rows: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	_world = Node3D.new()
	_world.name = "GlazingProbeWorld"
	root.add_child(_world)
	_place("restaurant_pizza", Restaurant.new(), Vector3.ZERO, 0.0)
	_place("hospital_structural01", Hospital.new(), Vector3(40, 0, 0), 0.0)
	for row: Dictionary in _rows:
		var site: RefCounted = row.site
		var node: Node3D = row.node
		var stats: Dictionary = site.stats() if site != null else {}
		print("GLAZING_PREPARE ", row.label, " ", JSON.stringify({
			"ok":row.ok, "status":row.status, "prepare_ms":row.prepare_ms,
			"site_error":str(node.get("site_error")) if is_instance_valid(node) else "",
			"finished_errors":stats.get("finished_errors", []),
			"stats_glazing":stats.get("glazing", {}),
			"window_panels":_window_panels(node),
			"wall_panels":(node.get("wall_panels") as Array).size() if is_instance_valid(node) else -1}))

func _place(label: String, site: RefCounted, origin: Vector3, yaw: float) -> void:
	var prepared: Dictionary = site.prepare(_world, origin, yaw)
	_rows.append({"label":label,"site":site,"node":prepared.get("node"),"ok":bool(prepared.get("ok", false)),"status":str(prepared.get("status", "")),"prepare_ms":float(prepared.get("prepare_ms", 0.0))})

func _window_panels(node: Node3D) -> int:
	if not is_instance_valid(node): return -1
	var count := 0
	for body: Variant in node.get("wall_panels"):
		if is_instance_valid(body) and body.has_meta("finished_window"): count += 1
	return count

func _process(_delta: float) -> bool:
	if Engine.get_process_frames() < SETTLE_FRAMES: return false
	for row: Dictionary in _rows:
		var node: Node3D = row.node
		var glazing: Variant = node.get("_glazing") if is_instance_valid(node) else null
		var stats: Dictionary = (row.site as RefCounted).stats() if row.site != null else {}
		var glazing_stats: Dictionary = {}
		if is_instance_valid(glazing) and glazing.has_method("stats"): glazing_stats = glazing.call("stats")
		var frame_text := ""
		if is_instance_valid(glazing):
			frame_text = str((glazing.get("_site_frame") as Transform3D).origin) + " vs " + str(node.global_transform.origin)
		print("GLAZING_AFTER ", row.label, " ", JSON.stringify({
			"frames":Engine.get_process_frames(),
			"glazing_valid":is_instance_valid(glazing),
			"glazing":glazing_stats,
			"frame_captured_vs_real":frame_text,
			"site_ready":node.get("site_ready") if is_instance_valid(node) else null,
			"site_status":str(node.get("site_status")) if is_instance_valid(node) else "",
			"site_error":str(node.get("site_error")) if is_instance_valid(node) else "",
			"stats_glazing":stats.get("glazing", {})}))
	quit(0)
	return true
