extends SceneTree
const Nav = preload("res://scripts/navigation/npc_native_navigation.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const ORACLE := "res://scripts/tests/fixtures/npc_navigation_oracle.json"
var checks := 0
var failures: Array[String] = []
var spec: Dictionary
var bodies: Array = []
var body_bounds: Dictionary = {}
var water_area: Variant
var geometry: RefCounted
var now_us := 0
var pass_calls := 0
var sweep_calls := 0
var timings: Array = []
var admitted_timings: Array = []
var actual_printshop_timings: Array = []
var max_nodes := 0
var active_nav: RefCounted
var active_queue: RefCounted
var active_owner: RefCounted
var collision_index: RefCounted
var performance_report: Array = []
var worker_result := ""

func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		if failures.size() < 60: failures.append(name)

func exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$f64le"): return str(value["$f64le"]).hex_decode().decode_double(0)
		var out: Dictionary = {}
		for k: Variant in value: out[k] = exact(value[k])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value: out.append(exact(item))
		return out
	return value

func clock_us() -> int: return now_us

func inside(area: Variant, c: float, r: float) -> bool:
	return area is Array and c >= area[0] and r >= area[1] and c <= area[2] and r <= area[3]

func contains(body: RefCounted, r: float, c: float) -> bool:
	var hit := false
	var p: Array = body.polygon_cr
	var j := p.size() - 1
	for i in p.size():
		var a: Array = p[i]; var b: Array = p[j]
		if (a[1] > r) != (b[1] > r) and c < (b[0] - a[0]) * (r - a[1]) / (b[1] - a[1]) + a[0]: hit = not hit
		j = i
	return hit

func ground(_x: float, z: float) -> float: return spec.floor + float(spec.get("slope", 0.0)) * (z - 1.0)
func water(x: float, z: float) -> Variant:
	return {"level": spec.waterLevel} if inside(water_area, x / spec.scale, z / spec.scale) else null
func terrain(x: float, z: float) -> bool: return not inside(spec.get("terrain"), x / spec.scale, z / spec.scale)
func dynamic(x: float, z: float, context: Dictionary) -> bool: return inside(spec.get("dynamic"), x / spec.scale, z / spec.scale) and context.get("ignoreId") != "own"
func surface(_x: float, _z: float, _r: float, _c: float) -> String: return "land"
func at(c: float, r: float) -> Array: return in_bounds(c, r, c, r)
func in_bounds(c0: float, r0: float, c1: float, r1: float) -> Array:
	var found: Array = []
	for body: RefCounted in bodies:
		var a: Array = body_bounds[body]
		if a[2] >= c0 and a[0] <= c1 and a[3] >= r0 and a[1] <= r1: found.append(body)
	return found
func resolve(request: Dictionary) -> Dictionary:
	sweep_calls += 1; now_us += int(spec.cost)
	return geometry.query(request)
func pass_point(r: float, c: float, _identity: int = 0) -> bool:
	pass_calls += 1; now_us += int(spec.cost)
	if not inside(spec.bounds, c, r): return false
	if spec.has("corridor") and (r < spec.corridor[0] or r > spec.corridor[1]): return false
	var q: Dictionary = geometry.query({"r": r, "c": c})
	return not q.blocked and q.depth <= 0.025
func build_bodies(rows: Array) -> void:
	bodies.clear(); body_bounds.clear()
	for row: Dictionary in rows:
		var body := Nav.Body.new(row.polygonCR, row.get("minYM", NAN), row.get("maxYM", NAN))
		bodies.append(body)
		var box: Array = [INF, INF, -INF, -INF]
		for point: Array in row.polygonCR:
			box[0] = minf(box[0], point[0]); box[1] = minf(box[1], point[1]); box[2] = maxf(box[2], point[0]); box[3] = maxf(box[3], point[1])
		body_bounds[body] = box
	if spec.get("duplicateFirst", false): bodies.append(bodies[0])

func configure(fixture: Dictionary) -> void:
	spec = fixture.duplicate(true); build_bodies(spec.bodies); water_area = spec.get("water")
	var providers := {"contains_body": contains, "ground_height": ground, "water_at": water, "terrain_allows": terrain, "blocks_dynamic": dynamic, "surface_at": surface, "bodies_at": at}
	if not spec.get("noSweep", false): providers.bodies_in_bounds = in_bounds
	geometry = Nav.Geometry.new(providers, spec.scale)
	collision_index = null
	if spec.get("broadphase") == "linear":
		geometry.providers.bodies_at = func(_c: float, _r: float) -> Array: return bodies
		geometry.providers.bodies_in_bounds = func(_a: float, _b: float, _c: float, _d: float) -> Array: return bodies
	elif spec.get("broadphase") == "index":
		collision_index = Nav.SpatialIndex.new(spec.cellSize)
		check(collision_index.publish([bodies], "fixture-printshop-authority", 1, 1), "bounded index published")
		check(geometry.attach_index(collision_index), "versioned index attached")

func same(a: Variant, b: Variant) -> bool:
	if a is float and b is float and is_nan(a) and is_nan(b): return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for k: Variant in a:
			if not b.has(k) or not same(a[k], b[k]): return false
		return true
	return a == b

func geometry_parity(cases: Array) -> void:
	for fixture: Dictionary in cases:
		configure(fixture)
		# Geometry-only oracle deliberately supplies all candidates to exercise
		# adapter identity deduplication as well as exact footprint checks.
		geometry.providers.bodies_at = func(_c: float, _r: float) -> Array: return bodies
		if not spec.get("noSweep", false): geometry.providers.bodies_in_bounds = func(_a: float, _b: float, _c: float, _d: float) -> Array: return bodies
		for i in spec.ops.size():
			var op: Dictionary = spec.ops[i]; var label := str(spec.name) + ":" + str(i)
			if op.has("floor"): spec.floor = op.floor
			if op.has("reset"): geometry.begin_frame()
			if op.has("q"): check(same(geometry.query(op.q), op.expected), label + " geometry exact response")
			if op.has("points"):
				for n in int(op.points): geometry.query({"r": float(n), "c": 0.0})
				check(geometry.diagnostics().cached_points == 30000, "point cache cap")
			if op.has("sweeps"):
				for n in int(op.sweeps): geometry.query({"mode": "sweep", "from": {"r": float(n), "c": 0.0}, "to": {"r": float(n), "c": 1.0}})
				check(geometry.diagnostics().cached_sweeps == 4000, "sweep cache cap")
			var actual: Dictionary = geometry.diagnostics()
			for key: String in op.counts: check(actual[key] == op.counts[key], label + " geometry counter " + key)
		check(geometry.begin_frame() and geometry.diagnostics().cached_points == 0 and geometry.diagnostics().cached_sweeps == 0, "frame reset releases caches")

func parity(cases: Array) -> void:
	for fixture: Dictionary in cases:
		configure(fixture)
		var nav := Nav.new(); var queue := Queue.new(clock_us)
		var owners: Array = []
		for i in int(spec.get("actors", 1)): owners.append(Queue.Owner.new("fixture:" + str(i)))
		var frame := 0; var goal: Dictionary = spec.goal; var predicate := pass_point.bind(0)
		now_us = 0; pass_calls = 0; sweep_calls = 0
		for step: Dictionary in spec.steps:
			var label: String = spec.name + ":" + str(int(step.frame)) + ":" + str(int(step.id))
			if frame != int(step.frame):
				frame = int(step.frame); now_us += 10000; geometry.begin_frame()
				if frame == spec.get("changeFrame"): build_bodies(spec.afterBodies)
				if frame == spec.get("changeGoalFrame"): goal = spec.afterGoal
				if frame == spec.get("changeWaterFrame"): water_area = spec.afterWater
				if frame == spec.get("restartFrame"): predicate = pass_point.bind(1)
			var owner: RefCounted = owners[int(step.id)]
			if step.status == "CANCELLED":
				check(nav.cancel(queue, owner), label + " cancel accepted")
				check(owner.continuation == null and not owner.search_pending, label + " cancelled reference cleared")
				continue
			var before := now_us; var pc := pass_calls; var sw := sweep_calls
			var started := Time.get_ticks_usec()
			var result := nav.plan(frame, queue, owner, spec.start, goal, predicate, resolve, spec.radius, int(spec.limit))
			var elapsed := Time.get_ticks_usec() - started
			timings.append(elapsed)
			if result.get("admitted", false): admitted_timings.append(elapsed)
			if spec.name.begins_with("actual_printshop"): actual_printshop_timings.append(elapsed)
			check(result.status == step.status, label + " status actual=" + str(result.status) + " expected=" + str(step.status))
			check(result.get("admitted") == step.admitted, label + " admission")
			check(now_us - before == int(step.cpuUs), label + " exact injected work cost actual=" + str(now_us - before) + " expected=" + str(step.cpuUs))
			check(pass_calls - pc == int(step.passCalls), label + " point calls")
			check(sweep_calls - sw == int(step.sweepCalls), label + " sweep calls")
			if result.get("admitted", false):
				check(result.expanded == int(step.expanded), label + " expanded")
				check(result.visited == int(step.visited), label + " visited")
				check(result.restarts == int(step.restarts), label + " restarts")
			var retained: int = owner.continuation.nodes.size() if owner.continuation is Dictionary else 0
			max_nodes = maxi(max_nodes, retained)
			check(retained == int(step.retained), label + " retained frontier")
			if step.status == "READY" and result.status == "READY":
				check(result.path == step.path, label + " exact source route coordinates/order")
				var cost := 0.0; var from_rc: Dictionary = spec.start
				for to_rc: Dictionary in result.path:
					cost += nav._hypot(to_rc.r - from_rc.r, to_rc.c - from_rc.c); from_rc = to_rc
				check(absf(cost - step.cost) <= maxf(1.0, step.cost) * 2e-15, label + " geometric route length (double libm allowance)")
		var actual: Dictionary = geometry.diagnostics()
		for key: String in spec.geometryCounts:
			check(actual[key] == spec.geometryCounts[key], spec.name + " geometry counts " + key + " actual=" + str(actual[key]) + " expected=" + str(spec.geometryCounts[key]))
		for owner: RefCounted in owners: nav.cancel(queue, owner)
		queue.dispose()

func reentrant_pass(_r: float, _c: float) -> bool:
	active_nav.cancel(active_queue, active_owner)
	return true

func cross_instance_pass(_r: float, _c: float) -> bool:
	var second := Nav.new()
	second.cancel(active_queue, active_owner)
	return true

func invalid_pass(_r: float, _c: float) -> String: return "truthy-is-not-boolean"
func invalid_resolve(_request: Dictionary) -> String: return "invalid-response"
func kill_during_pass(_r: float, _c: float) -> bool:
	active_owner.dead = true
	return true
func worker_attempt() -> void:
	worker_result = active_nav.plan(903, active_queue, active_owner, {"r": 2.5, "c": 2.5}, {"r": 5.5, "c": 6.5}, pass_point, resolve).status

func statistics(values: Array) -> Dictionary:
	values.sort()
	return {"samples": values.size(), "p50": values[values.size() / 2], "p95": values[int(values.size() * .95)], "max": values[-1]}

func performance_check(cases: Array) -> void:
	# Identical current authored 107 polygons, support, starts, goals and gates.
	# Includes the real linear baseline, the production index, and real-clock slices.
	for fixture: Dictionary in cases:
		if not fixture.name.begins_with("actual_printshop_closed_entry"): continue
		configure(fixture)
		for real_clock: bool in [false, true]:
			if real_clock and spec.broadphase == "linear": continue
			var totals: Array = []; var slices: Array = []; var frame_counts: Array = []; var rebuilds: Array = []
			for trial in range(20):
				var started := Time.get_ticks_usec()
				if collision_index != null:
					check(collision_index.publish([bodies], "fixture-printshop-authority", 1, trial + 2 + (100 if real_clock else 0)), "performance snapshot publication")
					if trial >= 5: rebuilds.append(Time.get_ticks_usec() - started)
				var nav := Nav.new(); var queue := Queue.new(Callable() if real_clock else clock_us); var owner := Queue.Owner.new("benchmark")
				now_us = 0; var total := 0; var frames := 0; var result: Dictionary = {}
				for frame in range(1, 200):
					geometry.begin_frame(); now_us += 10000; started = Time.get_ticks_usec()
					result = nav.plan(frame, queue, owner, spec.start, spec.goal, pass_point, resolve, spec.radius, int(spec.limit))
					var elapsed := Time.get_ticks_usec() - started; total += elapsed; frames += 1
					if trial >= 5: slices.append(elapsed)
					if result.status != "PENDING": break
				check(result.status == spec.steps[-1].status, "CPU benchmark identical final outcome")
				if result.status == "READY": check(result.path == spec.steps[-1].path, "CPU benchmark identical route")
				if trial >= 5: totals.append(total); frame_counts.append(frames)
				nav.cancel(queue, owner); queue.dispose()
			performance_report.append({"name": spec.name, "real_clock": real_clock, "body_count": bodies.size(), "route_total_us": statistics(totals), "slice_us": statistics(slices), "route_slices": statistics(frame_counts), "index_rebuild_us": statistics(rebuilds) if not rebuilds.is_empty() else {}, "index": collision_index.stats() if collision_index != null else {}})

func index_checks(cases: Array) -> void:
	for fixture: Dictionary in cases:
		spec = fixture; build_bodies(spec.bodies)
		var index := Nav.SpatialIndex.new(fixture.cellSize)
		check(index.publish([[bodies[0], bodies[1], bodies[0]], [bodies[2]]], "oracle", 1, 0), "index publish")
		for query: Dictionary in fixture.queries:
			var found: Array = index.query(query.point[0], query.point[1]) if query.has("point") else index.query_bounds(query.bounds[0], query.bounds[1], query.bounds[2], query.bounds[3])
			var ids: Array = []
			for body: RefCounted in found:
				for i in bodies.size():
					if body.polygon_cr == bodies[i].polygon_cr: ids.append(float(i)); break
			check(ids == query.expected, "exact source bucket order / duplicates / boundary")
		check(not index.publish([bodies], "oracle", 1, 0), "reject stale collision version")
		check(not index.publish([bodies], "foreign", 1, 1), "reject foreign authority")
		check(index.publish([bodies], "oracle", 2, 0), "new authority generation")
		check(not index.publish([bodies], "oracle", 1, 20), "reject old generation")
	# Door pose authority replacement in the SAME frame invalidates cached solids.
	var door := Nav.Body.new([[2.0, 2.0], [4.0, 2.0], [4.0, 4.0], [2.0, 4.0]], 0, 3)
	var moved := Nav.Body.new([[12.0, 2.0], [14.0, 2.0], [14.0, 4.0], [12.0, 4.0]], 0, 3)
	var index := Nav.SpatialIndex.new(.5); index.publish([[door]], "door-host", 1, 1)
	var nav := Nav.Geometry.new({"contains_body": contains}, 1.0); nav.attach_index(index)
	check(nav.query({"r": 3.0, "c": 3.0}).blocked, "closed door blocks")
	var sweep_request := {"mode": "sweep", "from": {"r": 3.0, "c": 1.0}, "to": {"r": 3.0, "c": 5.0}}
	check(nav.query(sweep_request).blocked, "closed door sweep cached")
	check(index.publish([[moved]], "door-host", 1, 2), "moved door snapshot")
	check(not nav.query({"r": 3.0, "c": 3.0}).blocked, "same frame old point cache cleared")
	check(not nav.query(sweep_request).blocked, "same frame old sweep cache cleared")
	check(nav.query({"r": 3.0, "c": 13.0}).blocked, "new pose blocks")
	var invalid := Nav.Body.new([[NAN, 0.0]])
	check(not index.publish([[invalid]], "door-host", 1, 3), "nonfinite publication rejected")
	check(nav.query({"r": 3.0, "c": 3.0}).blocked, "invalid authority geometry fails closed")
	check(index.publish([[door]], "door-host", 1, 3), "valid atomic recovery")
	check(nav.query({"r": 3.0, "c": 3.0}).blocked, "recovered geometry authoritative")
	var huge := Nav.Body.new([[-1e6, -1e6], [1e6, 1e6]])
	check(not index.publish([[huge]], "door-host", 1, 4), "bounded index references")
	check(index.publish([[door]], "door-host", 1, 4), "recover after reference limit")
	check(nav.query({"mode": "sweep", "from": {"r": -1e6, "c": -1e6}, "to": {"r": 1e6, "c": 1e6}}).blocked, "oversized broadphase query fails closed")

func negatives() -> void:
	active_nav = Nav.new(); active_queue = Queue.new(clock_us); active_owner = Queue.Owner.new("negative")
	var start := {"r": 2.5, "c": 2.5}; var goal := {"r": 5.5, "c": 6.5}
	for invalid: Variant in [NAN, INF, "2", null, true]:
		check(active_nav.plan(900, active_queue, active_owner, {"r": invalid, "c": 2.5}, goal, pass_point, resolve).status == "INVALID", "reject invalid start")
	check(active_nav.plan(900, active_queue, active_owner, start, goal, pass_point, resolve, .8, 100000).status == "INVALID", "reject unbounded node allowance")
	check(active_nav.plan(900, active_queue, active_owner, start, goal, Callable(), resolve).status == "INVALID", "reject missing predicate")
	active_owner.dead = true
	check(active_nav.plan(900, active_queue, active_owner, start, goal, pass_point, resolve).status == "CANCELLED", "dead generation cancelled")
	active_owner.dead = false
	check(active_nav.plan(901, active_queue, active_owner, start, goal, reentrant_pass, resolve).status == "INVALID", "reentry invalidates outer route")
	check(active_owner.continuation == null, "invalidated search releases providers")
	check(active_nav.plan(902, active_queue, active_owner, start, goal, cross_instance_pass, resolve).status == "INVALID", "cross-instance reentry refused")
	check(active_nav.plan(903, active_queue, active_owner, start, goal, invalid_pass, resolve).status == "INVALID", "invalid point response fails closed")
	check(active_nav.plan(904, active_queue, active_owner, start, goal, pass_point, invalid_resolve).status == "INVALID", "invalid sweep response fails closed")
	check(active_nav.plan(905, active_queue, active_owner, start, goal, kill_during_pass, resolve).status == "CANCELLED", "death during provider cancels result")
	var worker := Thread.new(); worker.start(worker_attempt); worker.wait_to_finish()
	check(worker_result == "INVALID", "worker thread denied")
	active_queue.dispose()
	var weak_owner: WeakRef = weakref(active_owner)
	active_owner = null
	check(weak_owner.get_ref() == null, "dispose releases last owner reference")
	var invalid_geometry := Nav.Geometry.new({})
	check(invalid_geometry.query({"r": 0.0, "c": 0.0}).blocked, "missing required contains provider fails closed")

func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check(parsed is Dictionary, "fixture exists")
	if not parsed is Dictionary: quit(1); return
	var root := ProjectSettings.globalize_path("res://../..")
	for source: Dictionary in parsed.sources:
		check(FileAccess.get_sha256(root.path_join(source.path)) == source.sha256, "current source SHA " + source.path)
	var decoded: Dictionary = exact(parsed)
	parity(decoded.cases)
	geometry_parity(decoded.geometryCases)
	index_checks(decoded.indexCases)
	performance_check(decoded.cases)
	configure(decoded.cases[1])
	negatives()
	timings.sort()
	print(JSON.stringify({"checks": checks, "failures": failures, "cases": decoded.cases.size(), "slices": timings.size(), "retained_nodes_max": max_nodes, "admitted_slice_us": statistics(admitted_timings), "performance": performance_report, "limits": "headless module CPU; not game FPS"}))
	quit(0 if failures.is_empty() else 1)
