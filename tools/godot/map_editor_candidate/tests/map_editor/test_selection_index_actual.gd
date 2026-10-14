extends SceneTree
## Run with --path outputs/map_editor_procedural_native_v3 (frozen source stage).
## No frozen files overwritten. Selection candidate loaded relative to THIS test.
const Factory = preload("res://scripts/procedural_factory.gd")
const Registry = preload("res://scripts/procedural_registry.gd")
const SHA := "82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"
var checks := 0
var failed := 0
var revision := 0
var owner_state := {}
var changed_ids: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func admit_revision(from_revision: int) -> Dictionary: return {"ok": true, "revision": revision, "from_revision": from_revision, "changed_ids": changed_ids}
func admit_geometry(request: Dictionary) -> Dictionary:
	# Isolated CPU geometry fixture owner only; NOT gameplay/server/nav admission.
	if request.dryRun: return {"approved": true}
	var previous: Variant = owner_state.get(request.sourceId)
	return {"approved": true, "commit": commit_geometry.bind(request), "rollback": rollback_geometry.bind(request.sourceId, previous)}
func commit_geometry(request: Dictionary) -> bool:
	owner_state[request.sourceId] = request.record
	return true
func rollback_geometry(id: String, previous: Variant) -> void:
	if previous == null: owner_state.erase(id)
	else: owner_state[id] = previous
static func quantile(values: Array, fraction: float) -> int:
	values.sort()
	return values[int((values.size() - 1) * fraction)]
func run() -> void:
	var Index: GDScript = load(get_script().resource_path.get_base_dir().path_join("../../scripts/map_editor/selection_spatial_index.gd"))
	var factory := Factory.new()
	check(factory.configure(SHA), "Actual procedural source SHA")
	var exploration: Dictionary = factory.build_exploration()
	var roads: Dictionary = factory.build_roads()
	root.add_child(exploration.root)
	root.add_child(roads.root)
	var registry := Registry.new()
	check(registry.configure(factory, admit_geometry).ok and registry.ids().size() == 9394, "Actual9394 source geometry registry")
	var index: RefCounted = Index.new()
	var begin := Time.get_ticks_usec()
	check(index.configure(registry, admit_revision).ok, "Actual9394 source bounds index")
	var build_us := Time.get_ticks_usec() - begin
	var rays: Array = []
	var ids: Array = registry.ids()
	for i in 180:
		var box: AABB = registry.world_bounds(ids[(i * 51) % ids.size()])
		var center := box.get_center()
		var origin := center + Vector3(0, 50, 0)
		rays.append([origin, Vector3.DOWN])
		check(index.pick(origin, Vector3.DOWN) == registry.pick(origin, Vector3.DOWN), "Actual source exact nearest ID parity")
	var baseline: Array = []
	var optimized: Array = []
	var visits: Array = []
	for ray: Array in rays:
		begin = Time.get_ticks_usec()
		registry.pick(ray[0], ray[1])
		baseline.append(Time.get_ticks_usec() - begin)
		begin = Time.get_ticks_usec()
		index.pick(ray[0], ray[1])
		optimized.append(Time.get_ticks_usec() - begin)
		visits.append(index.last_bounds_tests)
	var id: String = "explore-pine-239"
	var original: Dictionary = registry.get_record(id)
	var moved := original.duplicate(true)
	moved.transform.position[0] += 13
	check(registry.apply_record(id, moved).ok, "Actual source admitted tree move")
	changed_ids = [id]
	revision += 1
	check(not index.pick_result(Vector3.ZERO, Vector3.DOWN).ok, "Actual mutation requires new revision admission")
	begin = Time.get_ticks_usec()
	check(index.refresh_ids([id]).ok, "Actual moved tree targeted refit")
	var refit_us := Time.get_ticks_usec() - begin
	var box: AABB = registry.world_bounds(id)
	check(index.pick(box.get_center() + Vector3(0, 30, 0), Vector3.DOWN) == registry.pick(box.get_center() + Vector3(0, 30, 0), Vector3.DOWN), "Moved actual geometry exact currentbounds")
	check(registry.apply_record(id, null).ok, "Actual tree deletion")
	revision += 1
	check(index.refresh_ids([id]).ok and index.pick(box.get_center() + Vector3(0, 30, 0), Vector3.DOWN) == registry.pick(box.get_center() + Vector3(0, 30, 0), Vector3.DOWN), "Deleted actual tree parity")
	check(registry.apply_record(id, original).ok, "Actual geometry undo")
	revision += 1
	check(index.refresh_ids([id]).ok, "Undo currentbounds refit")
	var frame: Transform3D = registry.template_frame(id)
	frame.origin += Vector3(10, 2, 7)
	var clone: Dictionary = registry.create_copy(id, "editor:selection-perf", frame)
	check(clone.ok, "Actual original-resource tree clone")
	changed_ids = ["editor:selection-perf"]
	revision += 1
	begin = Time.get_ticks_usec()
	check(index.refresh_ids(["editor:selection-perf"]).ok, "Clone dynamically inserted without rebuilding9394")
	var insert_us := Time.get_ticks_usec() - begin
	box = registry.world_bounds("editor:selection-perf")
	check(index.pick(box.get_center() + Vector3(0, 30, 0), Vector3.DOWN) == registry.pick(box.get_center() + Vector3(0, 30, 0), Vector3.DOWN), "Actual clone nearest currentbounds parity")
	registry.discard_copy("editor:selection-perf")
	revision += 1
	check(index.refresh_ids(["editor:selection-perf"]).ok and index.pick(box.get_center() + Vector3(0, 30, 0), Vector3.DOWN) == registry.pick(box.get_center() + Vector3(0, 30, 0), Vector3.DOWN), "Discard actual clone parity")
	exploration.root.free()
	roads.root.free()
	print(JSON.stringify({"suite":"selection-actual9394", "checks":checks, "failures":failed, "build_us":build_us,"refit_us":refit_us,"insert_us":insert_us,"linear_p50_us":quantile(baseline,0.5),"linear_p95_us":quantile(baseline,0.95),"index_p50_us":quantile(optimized,0.5),"index_p95_us":quantile(optimized,0.95),"bounds_p50":quantile(visits,0.5),"bounds_p95":quantile(visits,0.95),"gpu":false,"production_wired":false,"source_ids":9394}))
	quit(0 if failed == 0 else 1)
