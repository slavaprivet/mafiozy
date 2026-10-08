extends SceneTree
const Minimap = preload("res://addons/walk_minimap/minimap_control.gd")
const Catalog = preload("res://addons/walk_minimap/map_catalog.gd")
const ObjectIndex = preload("res://addons/walk_minimap/map_object_index.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FILTER CHECK FAILED: ", label)

func run() -> void:
	await create_timer(2.0).timeout
	var objects: Array = [
		{"id": "bank1", "name": "Банк", "kind": "bank", "x": -20.0, "z": 0.0, "polygon": [[-30, -10], [-10, -10], [-10, 10], [-30, 10]]},
		{"id": "bank2", "name": "Банк", "kind": "bank", "x": 20.0, "z": 0.0},
		{"id": "station", "name": "Станция", "kind": "station", "x": 0.0, "z": 20.0},
		{"id": "tree", "name": "Дерево", "kind": "tree", "x": 50.0, "z": 50.0},
		{"id": "unknown", "name": "Неизвестный декор", "kind": "custom-kind", "poi": true, "x": -50.0, "z": 50.0},
	]
	check(Catalog.KINDS.size() == 27 and Catalog.BUILDING_MAP_KINDS.size() == 13, "actual source category count")
	var pois: Array = Catalog.select_pois(objects + [objects[2].duplicate(true)])
	check(pois.size() == 4 and pois[0].id == "station", "POI dedup and station priority")
	check(pois.filter(func(object): return object.name == "Банк").size() == 2, "distinct same-name banks remain")
	check(Catalog.kind_color("hospital") == Color("d9ece1"), "source hospital color")
	check(Catalog.kind_color("custom-kind") == Color("baaa8b"), "unknown source object color")
	var index = ObjectIndex.new()
	index.configure(objects)
	objects[0].x = 999
	check(index.all_objects()[0].x == -20, "dataset snapshot isolated")
	for kind: String in Catalog.KINDS:
		check(index.is_kind_enabled(kind), "category all on: " + kind)
	var query := {"minX": -40, "maxX": 60, "minZ": -20, "maxZ": 60}
	var geographic_count: int = index.query(query).size()
	check(index.set_kind_enabled("bank", false), "filter changes")
	check(index.visible_objects().size() == 3, "both banks hidden")
	check(index.query(query).size() == geographic_count, "unfiltered geography preserved")
	var filter_stats: Dictionary = index.stats()
	for i in range(100):
		index.set_kind_enabled("bank", false)
		index.query(query, true)
	check(index.stats().filter_rebuilds == filter_stats.filter_rebuilds and index.stats().index_rebuilds == filter_stats.index_rebuilds, "no-op filter/query rebuild nothing")
	var map = Minimap.new()
	root.add_child(map)
	map.set_process(false)
	map.set_world({"bounds": {"minX": -100, "maxX": 100, "minZ": -100, "maxZ": 100}, "objects": index.all_objects()})
	map.set_waypoint(index.all_objects()[0])
	var selected: Variant = map.get_waypoint()
	var bank_point: Vector2 = map.get_projection().to_screen(Vector2(-20, 0))
	check(map.object_at(bank_point).id == "bank1", "visible marker hit")
	check(map.set_kind_enabled("bank", false), "Control filter changes")
	check(map.visible_pois().filter(func(object): return object.kind == "bank").is_empty(), "POI filters agree")
	check(map.object_at(bank_point) == null, "hidden object not hittable")
	check(map.get_waypoint() == selected, "selected waypoint persists")
	var stats: Dictionary = map.draw_stats()
	var started := Time.get_ticks_usec()
	for i in range(1000):
		map.set_kind_enabled("bank", false)
	var filter_noop_cpu_us := Time.get_ticks_usec() - started
	check(map.draw_stats().requests == stats.requests and map.draw_stats().poi_rebuilds == stats.poi_rebuilds and map.draw_stats().atlas_rebuilds == stats.atlas_rebuilds, "1000 equal filter settings no UI/atlas rebuild")
	var idle_start := Time.get_ticks_usec()
	for i in range(1000):
		map.update_state({"position": {"x": 0.0, "z": 0.0}, "actors": [], "vehicles": [], "trains": []}, stats.last_ms + i + 80)
	var idle_cpu_us := Time.get_ticks_usec() - idle_start
	check(map.draw_stats().requests == stats.requests and map.draw_stats().poi_rebuilds == stats.poi_rebuilds and map.draw_stats().atlas_rebuilds == stats.atlas_rebuilds, "fresh idle arrays no extra draw/index/list work")
	check(map.set_kind_enabled("object", false), "unknown category grouped into object")
	check(not map.is_kind_enabled("custom-kind"), "unknown object filter follows object")
	check(map.reset_filters() and map.is_kind_enabled("bank"), "reset restores all source categories")
	map.set_world({"bounds": {"minX": -100, "maxX": 100, "minZ": -100, "maxZ": 100}, "objects": []})
	check(map.object_at(bank_point) == null and map.visible_pois().is_empty(), "replacement dataset has no stale hits/list")
	check(map.get_waypoint() == selected, "dataset replacement does not erase selected marker")
	await process_frame
	map.queue_free()
	await process_frame
	await process_frame
	var result := {"schema": "mafiozi.minimap.filters/v1", "checks": checks, "failures": failures, "passed": failures.is_empty(), "cost_scope": {"equal_filter_calls": 1000, "cpu_us": filter_noop_cpu_us, "idle_snapshots": 1000, "idle_cpu_us": idle_cpu_us, "no_extra_redraw_or_ui_index_rebuilds": failures.is_empty()}, "full_city_performance": "NOT_RUN"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="):
			var file := FileAccess.open(arg.trim_prefix("--receipt="), FileAccess.WRITE)
			file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
