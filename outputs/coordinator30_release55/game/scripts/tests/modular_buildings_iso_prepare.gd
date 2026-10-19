extends SceneTree
## Headless placement probe for the three ported modular destructible boxes.
## SceneTree script (no scene is loaded): it creates its own world node, places
## the restaurant, hospital and small bank through their instantiators, waits
## for real physics frames so the sites can validate their external soil, and
## prints one MODULAR_ISO line per building plus a summary.
##
## Nothing here touches main.gd, city/runtime/**, palazzo/** or modular30/**.
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <game> \
##     --script res://scripts/tests/modular_buildings_iso_prepare.gd

const Restaurant = preload("res://scripts/destruction/restaurant/restaurant_site.gd")
const Hospital = preload("res://scripts/destruction/hospital_site/hospital_site.gd")
const Bank = preload("res://scripts/destruction/bank_site/bank_site.gd")

const SETTLE_FRAMES := 8
const HARD_DEADLINE_MS := 120000

var _world: Node3D
var _results: Array[Dictionary] = []
var _started_ms := 0
var _frames := 0
var _done := false

func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	run.call_deferred()

func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _frames >= SETTLE_FRAMES:
		_finish()
		return true
	if Time.get_ticks_msec() - _started_ms > HARD_DEADLINE_MS:
		print("MODULAR_ISO_ABORT deadline_ms=", Time.get_ticks_msec() - _started_ms)
		_finish()
		return true
	return false

func run() -> void:
	_world = Node3D.new()
	_world.name = "ModularIsoWorld"
	root.add_child(_world)
	# Spacing keeps the three footprints apart: restaurant is 18.28 x 15.28 m,
	# hospital 22.28 x 19.58 m, bank 19.28 x 15.28 m; every one of them is at
	# most 22.28 m wide, so 40 m of separation cannot overlap.
	_place("restaurant_pizza", Restaurant.new(), Vector3(0, 0, 0), 0.0)
	_place("hospital_structural01", Hospital.new(), Vector3(40, 0, 0), 0.0)
	_place("bank_small", Bank.new(), Vector3(80, 0, 0), 0.0)
	print("MODULAR_ISO_STAGE placed=", _results.size(), " frames=", _frames)

func _place(label: String, site: RefCounted, origin: Vector3, yaw_deg: float) -> void:
	var row := {"label": label, "origin": origin}
	if site == null:
		row["ok"] = false
		row["reason"] = "instance_null"
		_results.append(row)
		return
	var prepared: Dictionary = site.prepare(_world, origin, yaw_deg)
	row["ok"] = bool(prepared.get("ok", false))
	row["reason"] = str(prepared.get("reason", ""))
	row["status"] = str(prepared.get("status", ""))
	row["prepare_ms"] = float(prepared.get("prepare_ms", 0.0))
	row["source_id"] = str(prepared.get("source_id", ""))
	row["profile_id"] = str(prepared.get("profile_id", ""))
	row["stats_pre"] = prepared.get("stats", {})
	row["terrain"] = prepared.get("terrain", {})
	row["site"] = site
	row["node"] = prepared.get("node", null)
	_results.append(row)

func _finish() -> void:
	_done = true
	var ok_count := 0
	var total_ms := 0.0
	for row: Dictionary in _results:
		var site: RefCounted = row.get("site")
		var stats: Dictionary = {}
		var aabb_text := "-"
		if site != null and is_instance_valid(site):
			stats = site.stats()
			var aabb: Dictionary = stats.get("aabb", {})
			if not aabb.is_empty():
				var size: Vector3 = aabb.get("size", Vector3.ZERO)
				var pos: Vector3 = aabb.get("position", Vector3.ZERO)
				aabb_text = "%.2f,%.2f,%.2f@%.2f,%.2f,%.2f" % [size.x, size.y, size.z, pos.x, pos.y, pos.z]
		var status := str(stats.get("status", row.get("status", "")))
		var accepted := status == "intact" or status == "awaiting_native_basement_clearance"
		if accepted and bool(row.get("ok", false)):
			ok_count += 1
		total_ms += float(row.get("prepare_ms", 0.0))
		print("MODULAR_ISO label=", row.get("label"),
			" ok=", row.get("ok"),
			" status=", status,
			" reason=", row.get("reason"),
			" prepare_ms=", "%.1f" % float(row.get("prepare_ms", 0.0)),
			" profile=", row.get("profile_id"),
			" source_id=", row.get("source_id"),
			" aabb=", aabb_text,
			" rigid=", stats.get("rigid_bodies", -1),
			" shapes=", stats.get("collision_shapes", -1),
			" meshes=", stats.get("mesh_instances", -1),
			" pieces=", stats.get("pieces", -1),
			" recipe_parts=", stats.get("recipe_parts", -1),
			" rooms=", stats.get("recipe_rooms", -1),
			" stairs=", stats.get("recipe_stair_routes", -1),
			" soil_boxes=", stats.get("soil_boxes", -1),
			" detached=", stats.get("detached", -1),
			" active=", stats.get("active", -1),
			" parked=", stats.get("parked", -1),
			" terrain=", JSON.stringify(row.get("terrain", {})))
	print("MODULAR_ISO_SUMMARY ok=", ok_count, "/", _results.size(),
		" frames=", _frames,
		" total_prepare_ms=", "%.1f" % total_ms,
		" wall_ms=", Time.get_ticks_msec() - _started_ms,
		" engine=", Engine.get_version_info().get("string", "?"))
	quit(0 if ok_count == _results.size() else 1)
