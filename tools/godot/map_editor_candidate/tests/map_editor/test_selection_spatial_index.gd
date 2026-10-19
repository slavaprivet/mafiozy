extends SceneTree
const Index = preload("res://scripts/map_editor/selection_spatial_index.gd")
const OldOutline = preload("res://scripts/map_editor/selection_outline.gd")
const CachedOutline = preload("res://scripts/map_editor/selection_outline_cached.gd")
class BoundsOwner extends RefCounted:
	var boxes := {}
	var revision := 0
	var bounds_calls := 0
	var changed_ids: Array = []
	func ids() -> Array: return boxes.keys()
	func has_object(id: String) -> bool: return boxes.has(id)
	func world_bounds(id: String) -> Variant:
		bounds_calls += 1
		return boxes.get(id)
	func admit_revision(from_revision: int) -> Dictionary: return {"ok": true, "revision": revision, "from_revision": from_revision, "changed_ids": changed_ids}
	func pick(origin: Vector3, direction: Vector3, distance: float = 10000.0) -> String:
		var nearest := distance
		var selected := ""
		var end := origin + direction.normalized() * distance
		for id: String in boxes:
			var box: Variant = world_bounds(id)
			if not box is AABB: continue
			var hit: Variant = box.intersects_segment(origin, end)
			if hit is Vector3:
				var length := origin.distance_to(hit)
				if length < nearest:
					nearest = length
					selected = id
		return selected
var checks := 0
var failed := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
static func quantile(values: Array, fraction: float) -> int:
	values.sort()
	return values[int((values.size() - 1) * fraction)]
func run() -> void:
	var owner := BoundsOwner.new()
	for i in 9901:
		owner.boxes["object:" + str(i)] = AABB(Vector3((i % 100) * 9, (i % 7) * 0.2, (i / 100) * 9), Vector3(3, 2 + (i % 5), 3))
	var index := Index.new()
	var begin := Time.get_ticks_usec()
	check(index.configure(owner, owner.admit_revision).ok, "Full9901 owner revision index")
	var build_us := Time.get_ticks_usec() - begin
	var random := RandomNumberGenerator.new()
	random.seed = 281204
	var rays: Array = []
	for i in 160:
		var origin := Vector3(random.randf_range(-20, 940), random.randf_range(10, 70), random.randf_range(-20, 940))
		var direction := Vector3(random.randf_range(-0.1, 0.1), -1, random.randf_range(-0.1, 0.1))
		rays.append([origin, direction])
		check(index.pick(origin, direction) == owner.pick(origin, direction), "Exact9901 nearest/tie parity deterministic ray")
	var baseline: Array = []
	var optimized: Array = []
	var visits: Array = []
	for ray: Array in rays:
		begin = Time.get_ticks_usec()
		owner.pick(ray[0], ray[1])
		baseline.append(Time.get_ticks_usec() - begin)
		begin = Time.get_ticks_usec()
		index.pick(ray[0], ray[1])
		optimized.append(Time.get_ticks_usec() - begin)
		visits.append(index.last_bounds_tests)
	var calls_before := owner.bounds_calls
	for ray: Array in rays: index.pick(ray[0], ray[1])
	check(owner.bounds_calls == calls_before, "Warm indexed queries make no per-object world_bounds calls")
	var id := "object:0"
	var original: AABB = owner.boxes[id]
	owner.boxes[id] = AABB(Vector3(4, 0, 4), Vector3(4, 6, 4))
	owner.changed_ids = [id]
	owner.revision += 1
	check(not index.pick_result(Vector3(5, 20, 5), Vector3.DOWN).ok, "Missed mutation notification refuses stale cache")
	check(not index.refresh_ids([]).ok and not index.pick_result(Vector3(5, 20, 5), Vector3.DOWN).ok, "Incomplete owner dirty receipt cannot admit stale unrelated bounds")
	check(index.refresh_ids([id]).ok and index.pick(Vector3(5, 20, 5), Vector3.DOWN) == owner.pick(Vector3(5, 20, 5), Vector3.DOWN), "Moved current bounds targeted refit")
	owner.boxes[id] = null
	owner.revision += 1
	check(index.refresh_ids([id]).ok and index.pick(Vector3(5, 20, 5), Vector3.DOWN) == owner.pick(Vector3(5, 20, 5), Vector3.DOWN), "Deleted object excluded exactly")
	owner.boxes[id] = original
	owner.revision += 1
	check(index.refresh_ids([id]).ok and index.pick(Vector3(1, 20, 1), Vector3.DOWN) == id, "Undo restores current bounds")
	owner.boxes["editor:copy"] = AABB(Vector3(4, 8, 4), Vector3(4, 2, 4))
	owner.changed_ids = ["editor:copy"]
	owner.revision += 1
	check(index.refresh_ids(["editor:copy"]).ok and index.pick(Vector3(5, 20, 5), Vector3.DOWN) == "editor:copy", "New moved clone inserted and exact nearest preserved")
	owner.boxes.erase("editor:copy")
	owner.revision += 1
	check(index.refresh_ids(["editor:copy"]).ok and index.pick(Vector3(5, 20, 5), Vector3.DOWN) == owner.pick(Vector3(5, 20, 5), Vector3.DOWN), "Discard cloned object no stalehit")
	owner.boxes["tie:first"] = AABB(Vector3(-50, 0, -50), Vector3(4, 4, 4))
	owner.boxes["tie:second"] = owner.boxes["tie:first"]
	owner.revision += 1
	check(index.rebuild().ok and index.pick(Vector3(-49, 20, -49), Vector3.DOWN) == "tie:first", "Equalhit keeps registry iteration first ID regardless BVH sort")
	check(index.pick(Vector3(-49, 20, -49), Vector3.DOWN, 16) == "", "Exact endpoint excluded as original strict nearest")
	check(index.pick(Vector3(-49, 2, -49), Vector3.RIGHT, 1) == owner.pick(Vector3(-49, 2, -49), Vector3.RIGHT, 1), "Ray starts inside parent/leaf parity")
	check(index.pick(Vector3.ZERO, Vector3.ZERO) == "" and index.pick(Vector3.INF, Vector3.DOWN) == "", "Invalid rays refused")
	var old := OldOutline.new()
	var cached := CachedOutline.new()
	root.add_child(old)
	root.add_child(cached)
	var mesh_identity: Mesh = cached.mesh
	var outline_before: Array = []
	var outline_after: Array = []
	for i in 160:
		var box := AABB(Vector3(i, 1, 2), Vector3(3, 4, 5))
		begin = Time.get_ticks_usec()
		old.show_bounds(box)
		outline_before.append(Time.get_ticks_usec() - begin)
		begin = Time.get_ticks_usec()
		cached.show_bounds(box)
		outline_after.append(Time.get_ticks_usec() - begin)
		check(cached.mesh == mesh_identity and cached.geometry_builds == 1 and cached.transform * Vector3.ONE == box.end and cached.transform.origin == box.position, "Outline exact corners without new geometry/resource")
	cached.show_bounds(null)
	check(not cached.visible and cached.mesh == mesh_identity, "Hidden/empty selection never reallocates")
	old.free()
	cached.free()
	print(JSON.stringify({"suite":"selection9901-synthetic-owner", "checks":checks, "failures":failed, "build_us":build_us, "linear_p50_us":quantile(baseline,0.5), "linear_p95_us":quantile(baseline,0.95), "index_p50_us":quantile(optimized,0.5), "index_p95_us":quantile(optimized,0.95), "bvh_bounds_p50":quantile(visits,0.5), "bvh_bounds_p95":quantile(visits,0.95), "outline_old_p50_us":quantile(outline_before,0.5), "outline_old_p95_us":quantile(outline_before,0.95), "outline_new_p50_us":quantile(outline_after,0.5), "outline_new_p95_us":quantile(outline_after,0.95), "gpu":false,"production_wired":false}))
	quit(0 if failed == 0 else 1)
