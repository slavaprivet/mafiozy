extends RefCounted
## Exact astar-visit search from npc_native_directed_route_source.js.
## Source-cell scalar doubles only. Host owns actors, route application and providers.
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Sweep = preload("res://scripts/navigation/npc_swept_footprint.gd")
const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]]
const MAX_VISITED := 65536 # Explicit host limit; source can overshoot by <=3 nodes.
static var _running: RefCounted = null

class Body extends RefCounted:
	var polygon_cr: Array
	var min_y: float
	var max_y: float
	func _init(polygon: Array, bottom: float = NAN, top: float = NAN) -> void:
		polygon_cr = polygon
		min_y = bottom
		max_y = top

## Exact createWalkCollisionIndex bucket construction / row-major queries.
## Host extension: atomic immutable snapshots, bounded references, version fence.
class SpatialIndex extends RefCounted:
	const MAX_REFERENCES := 262144
	var cell_size: float
	var _rows: Dictionary = {}
	var _empty: Array = []
	var _valid := false
	var _authority := ""
	var _generation := 0
	var _version := -1
	var revision := 0
	var _body_count := 0
	var _references := 0
	var last_error := ""
	func _init(size: float = 4.0) -> void:
		cell_size = size
		_empty.make_read_only()
	func valid() -> bool: return _valid
	func stats() -> Dictionary:
		return {"revision": revision, "authority": _authority, "generation": _generation, "version": _version, "bodies": _body_count, "bucket_references": _references}
	func publish(collections: Array, authority: String, generation: int, version: int) -> bool:
		if not Thread.is_main_thread(): return false
		if not is_finite(cell_size) or cell_size < 1e-6 or cell_size > 1e6 or authority.is_empty() or generation < 1 or version < 0: return false
		if _authority != "" and (authority != _authority or generation < _generation or (generation == _generation and version <= _version)): return false
		# Only complete validated replacement becomes visible. Consumers fail closed
		# after malformed fresh input; stale version submissions leave accepted state.
		_valid = false
		var rows: Dictionary = {}; var clones: Dictionary = {}; var count := 0; var references := 0
		for collection: Variant in collections:
			if not collection is Array: return false
			for source: Variant in collection:
				count += 1
				if count > 65536 or not source is Body or source.polygon_cr.size() > 4096: return false
				var polygon: Array = source.polygon_cr
				if polygon.is_empty(): continue
				var min_c := INF; var min_r := INF; var max_c := -INF; var max_r := -INF
				for point: Variant in polygon:
					if not point is Array or point.size() != 2: return false
					for scalar: Variant in point:
						if not (scalar is float or scalar is int) or not is_finite(float(scalar)) or absf(float(scalar)) > 1e6: return false
					min_c = minf(min_c, point[0]); max_c = maxf(max_c, point[0]); min_r = minf(min_r, point[1]); max_r = maxf(max_r, point[1])
				var r0 := int(floor(min_r / cell_size)); var r1 := int(floor(max_r / cell_size))
				var c0 := int(floor(min_c / cell_size)); var c1 := int(floor(max_c / cell_size))
				var width := c1 - c0 + 1; var depth := r1 - r0 + 1
				if width > MAX_REFERENCES or depth > MAX_REFERENCES or width > MAX_REFERENCES / depth: return false
				var extra := depth * width
				if extra > MAX_REFERENCES - references: return false
				references += extra
				if not clones.has(source):
					var frozen := polygon.duplicate(true)
					for point: Array in frozen: point.make_read_only()
					frozen.make_read_only()
					clones[source] = Body.new(frozen, source.min_y, source.max_y)
				var body: RefCounted = clones[source]
				for r in range(r0, r1 + 1):
					if not rows.has(r): rows[r] = {}
					var row: Dictionary = rows[r]
					for c in range(c0, c1 + 1):
						if not row.has(c): row[c] = []
						row[c].append(body)
		for row: Dictionary in rows.values():
			for bucket: Array in row.values(): bucket.make_read_only()
		_rows = rows; _authority = authority; _generation = generation; _version = version
		_body_count = count; _references = references; revision += 1; _valid = true
		return true
	func query(c: float, r: float) -> Array:
		if not Thread.is_main_thread(): return _empty
		last_error = ""
		if not _valid or not is_finite(c) or not is_finite(r) or absf(c) > 1e6 or absf(r) > 1e6:
			last_error = "invalid-point-or-snapshot"; return _empty
		var row: Dictionary = _rows.get(int(floor(r / cell_size)), {})
		return row.get(int(floor(c / cell_size)), _empty)
	func query_bounds(min_c: float, min_r: float, max_c: float, max_r: float) -> Array:
		if not Thread.is_main_thread(): return _empty
		last_error = ""
		if not _valid or not is_finite(min_c) or not is_finite(min_r) or not is_finite(max_c) or not is_finite(max_r) or min_c > max_c or min_r > max_r or maxf(absf(min_c), absf(max_c)) > 1e6 or maxf(absf(min_r), absf(max_r)) > 1e6:
			last_error = "invalid-bounds-or-snapshot"; return _empty
		var result: Array = []
		var r0 := int(floor(min_r / cell_size)); var r1 := int(floor(max_r / cell_size))
		var c0 := int(floor(min_c / cell_size)); var c1 := int(floor(max_c / cell_size))
		var width := c1 - c0 + 1; var depth := r1 - r0 + 1
		if width > MAX_REFERENCES or depth > MAX_REFERENCES or width > MAX_REFERENCES / depth:
			last_error = "query-bucket-limit"; return _empty
		for r in range(r0, r1 + 1):
			var row: Dictionary = _rows.get(r, {})
			for c in range(c0, c1 + 1):
				if row.has(c): result.append_array(row[c])
		return result

## Exact query adapter from npc_native_navigation.mjs. Call begin_frame after
## every provider snapshot change; bodies use object identity, never polygon equality.
class Geometry extends RefCounted:
	const Footprint = preload("res://scripts/navigation/npc_swept_footprint.gd")
	var providers: Dictionary
	var world_scale := 4.1
	var height := 1.9
	var _cache: Dictionary = {}
	var _ignored: Dictionary = {}
	var _sweep_cache: Dictionary = {}
	var _cache_size := 0
	var _footprint := Footprint.new()
	var _active: RefCounted
	var _busy := false
	var _fault := false
	var _configured := false
	var _index: RefCounted
	var _index_revision := -1
	var _dynamic_context := {"y": 0.0, "height": 1.9}
	var counts := {"queries": 0, "solid": 0, "water": 0, "cacheHits": 0, "sweepQueries": 0, "sweepCandidates": 0, "sweepBlocked": 0}
	func _init(callbacks: Dictionary, scale: float = 4.1, body_height: float = 1.9) -> void:
		providers = callbacks.duplicate()
		world_scale = scale; height = body_height
		_dynamic_context.height = body_height
		_configured = providers.get("contains_body") is Callable and providers.contains_body.is_valid() and is_finite(scale) and scale > 0.0 and is_finite(body_height) and body_height > 0.0
	func attach_index(index: RefCounted) -> bool:
		if not Thread.is_main_thread(): return false
		if _busy: _fault = true; return false
		if not index is SpatialIndex or not index.valid(): return false
		_index = index; _index_revision = index.revision
		providers.bodies_at = index.query; providers.bodies_in_bounds = index.query_bounds
		begin_frame()
		return true
	func begin_frame() -> bool:
		if not Thread.is_main_thread(): return false
		if _busy:
			_fault = true
			return false
		_cache.clear(); _ignored.clear(); _sweep_cache.clear(); _cache_size = 0
		return true
	func diagnostics() -> Dictionary:
		var value := counts.duplicate()
		value["cached_points"] = _cache_size; value["cached_sweeps"] = _sweep_cache.size()
		return value
	func _call(name: String, args: Array, fallback: Variant) -> Variant:
		if not providers.has(name): return fallback
		var callback: Variant = providers[name]
		if not callback is Callable or not callback.is_valid():
			_fault = true
			return fallback
		return callback.callv(args)
	func _finite(value: Variant) -> bool:
		return (value is int or value is float) and is_finite(float(value))
	func _solid_at_contact(c: float, r: float) -> bool:
		var floor_y: Variant = _call("ground_height", [c * world_scale, r * world_scale], 0.0)
		return not _finite(floor_y) or not ((is_finite(_active.max_y) and _active.max_y <= floor_y + 0.05) or (is_finite(_active.min_y) and _active.min_y >= floor_y + height))
	func query(request: Dictionary = {}) -> Dictionary:
		if not Thread.is_main_thread(): return {"blocked": true, "depth": 0.0, "swept": true}
		if not _configured: return {"blocked": true, "depth": 0.0, "swept": true}
		if _busy:
			_fault = true
			return {"blocked": true, "depth": 0.0, "swept": true}
		if _index != null:
			if not _index.valid(): return {"blocked": true, "depth": 0.0, "swept": true}
			if _index_revision != _index.revision:
				begin_frame(); _index_revision = _index.revision
			_index.last_error = ""
		_busy = true; _fault = false
		var result := _sweep(request) if request.get("mode") == "sweep" else _point(request)
		if _index != null and (not _index.valid() or _index_revision != _index.revision or not _index.last_error.is_empty()): _fault = true
		if _fault: result = {"blocked": true, "depth": 0.0, "swept": true}
		_active = null; _busy = false
		return result.duplicate() # Source result is cache-owned; native callers get a copy.
	func _sweep(request: Dictionary) -> Dictionary:
		if not providers.has("bodies_in_bounds"): return {"swept": false}
		var from_rc: Variant = request.get("from"); var to_rc: Variant = request.get("to")
		var radius: Variant = request.get("radius", 0.18)
		if not from_rc is Dictionary or not to_rc is Dictionary or not _finite(radius) or radius <= 0.0: return {"swept": true, "blocked": true}
		if not _finite(from_rc.get("r")) or not _finite(from_rc.get("c")) or not _finite(to_rc.get("r")) or not _finite(to_rc.get("c")): return {"swept": true, "blocked": true}
		var key := [from_rc.r, from_rc.c, to_rc.r, to_rc.c, radius]
		if _sweep_cache.has(key):
			counts.cacheHits += 1
			return _sweep_cache[key]
		if not _footprint.set_segment(from_rc, to_rc, radius): return {"swept": true, "blocked": true}
		counts.sweepQueries += 1
		var bounds := _footprint.bounds()
		var bodies: Variant = _call("bodies_in_bounds", [bounds.minC, bounds.minR, bounds.maxC, bounds.maxR], [])
		if bodies == null: bodies = []
		if not bodies is Array or bodies.size() > 65536:
			_fault = true
			return {"swept": true, "blocked": true}
		var seen: Dictionary = {}; var blocked := false
		for body: Variant in bodies:
			if not body is Body:
				_fault = true; blocked = true; break
			if seen.has(body): continue
			seen[body] = true; counts.sweepCandidates += 1; _active = body
			if _footprint.overlaps(body.polygon_cr, _solid_at_contact):
				blocked = true
				break
		_active = null
		if blocked: counts.sweepBlocked += 1
		var result := {"swept": true, "blocked": blocked}
		if _sweep_cache.size() < 4000 and not _fault: _sweep_cache[key] = result
		return result
	func _point(request: Dictionary) -> Dictionary:
		var r: Variant = request.get("r"); var c: Variant = request.get("c")
		if not _finite(r) or not _finite(c): return {"blocked": true, "depth": 0.0}
		# Production source IDs are strings. Arbitrary JS coercions are outside host API.
		var ignore: Variant = request.get("ignoreVehicleId")
		if ignore != null and not ignore is String: _fault = true; return {"blocked": true, "depth": 0.0}
		var id: Variant = ignore if ignore != "" else null
		var points: Dictionary = _cache if id == null else _ignored.get(id, {})
		var row: Dictionary = points.get(r, {})
		if row.has(c):
			counts.cacheHits += 1
			return row[c]
		var x: float = c * world_scale; var z: float = r * world_scale
		var floor_y: Variant = _call("ground_height", [x, z], 0.0)
		if not (floor_y is float or floor_y is int): _fault = true; floor_y = NAN
		var water: Variant = _call("water_at", [x, z], null)
		if water != null and not water is Dictionary: _fault = true; water = null
		var depth := 0.0
		if water != null:
			if water.has("level") and water.level != null and not (water.level is float or water.level is int): _fault = true
			if _finite(water.get("level")):
				var difference := float(water.level) - float(floor_y)
				depth = NAN if is_nan(difference) else maxf(0.0, difference)
			elif water.get("depth") != null:
				if water.depth is float or water.depth is int:
					depth = 0.0 if is_nan(float(water.depth)) else maxf(0.0, float(water.depth))
				else: _fault = true
		var blocked: bool = not _finite(floor_y)
		if not blocked:
			var allowed: Variant = _call("terrain_allows", [x, z], true)
			if not allowed is bool: _fault = true
			blocked = not bool(allowed)
		if not blocked:
			var bodies: Variant = _call("bodies_at", [c, r], [])
			if bodies == null: bodies = []
			if not bodies is Array or bodies.size() > 65536: _fault = true; bodies = []
			for body: Variant in bodies:
				if not body is Body: _fault = true; break
				if is_finite(body.max_y) and body.max_y <= floor_y + 0.05: continue
				if is_finite(body.min_y) and body.min_y >= floor_y + height: continue
				if not providers.has("contains_body"): _fault = true; break
				var contained: Variant = _call("contains_body", [body, r, c], true)
				if not contained is bool: _fault = true
				if contained: blocked = true; break
		if not blocked:
			_dynamic_context.y = floor_y; _dynamic_context.ignoreId = ignore
			var dynamic_hit: Variant = _call("blocks_dynamic", [x, z, _dynamic_context], false)
			if not dynamic_hit is bool: _fault = true
			blocked = bool(dynamic_hit)
		counts.queries += 1
		if blocked: counts.solid += 1
		if depth > 0.025: counts.water += 1
		var result := {"blocked": blocked, "depth": depth}
		var surface: Variant = _call("surface_at", [x, z, r, c], null)
		if surface == "land" or surface == "road": result.surface = surface
		if _cache_size < 30000 and not _fault:
			if id != null and not _ignored.has(id): _ignored[id] = points
			if not points.has(r): points[r] = row
			row[c] = result; _cache_size += 1
		return result

var _busy := false
var _fault := false
var _s: Dictionary = {}
var _rows: Dictionary = {}
var _points := 0
var _pass: Callable
var _resolver: Callable
var _queue: RefCounted
var _r := 0.0
var _c := 0.0
var _gr := 0.0
var _gc := 0.0
var _radius := 0.0
var _cols := 180
var _restarts := 0
var _expanded := 0
var _visited := 0

func _number(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and absf(float(v)) <= 1e6

func cancel(queue: RefCounted, owner: RefCounted) -> bool:
	if not Thread.is_main_thread(): return false
	if _running != null:
		_running._fault = true
		return false
	if not queue is Queue or not owner is Queue.Owner: return false
	queue.cancel(owner)
	return true

## One admitted synchronous slice. A READY result contains the source path,
## before _setNpcRoute mutates gameplay NPC fields. PENDING never means NO_PATH.
## Provider Callables must be stable across slices and not retain query objects.
func plan(frame_id: int, queue: RefCounted, owner: RefCounted, start: Dictionary, goal: Dictionary, pass_fn: Callable, resolver: Callable, goal_radius: float = 0.8, max_visited: int = 18000, kind: String = "building_entry", map_cols: int = 180) -> Dictionary:
	if not Thread.is_main_thread(): return {"status": "INVALID"}
	if _running != null:
		_running._fault = true
		return {"status": "INVALID"}
	if not queue is Queue or not owner is Queue.Owner or not _number(start.get("r")) or not _number(start.get("c")) or not _number(goal.get("r")) or not _number(goal.get("c")) or not _number(goal_radius) or goal_radius < 0.0 or max_visited < 1 or max_visited > MAX_VISITED or map_cols < 1 or map_cols > 65536 or not pass_fn.is_valid() or not resolver.is_valid():
		return {"status": "INVALID"}
	if owner.dead:
		queue.cancel(owner)
		return {"status": "CANCELLED"}
	_busy = true
	_running = self
	_fault = false
	if not queue.reserve(frame_id, owner):
		owner.search_pending = true
		_busy = false
		_running = null
		return {"status": "PENDING", "admitted": false}
	_r = start.r; _c = start.c; _gr = goal.r; _gc = goal.c
	_radius = goal_radius; _cols = map_cols
	_pass = pass_fn; _resolver = resolver; _queue = queue
	_rows.clear(); _points = 0
	var previous: Variant = owner.continuation
	_s = previous if previous is Dictionary else {}
	_restarts = int(_s.get("host_restarts", 0))
	_expanded = 0; _visited = 0
	owner.search_pending = false
	var result := _run(max_visited, kind)
	if owner.dead:
		result = {"status": "CANCELLED"}
		queue.cancel(owner)
	elif _fault:
		result = {"status": "INVALID"}
		queue.cancel(owner)
	else:
		owner.continuation = _s if result.status == "PENDING" else null
		owner.search_pending = result.status == "PENDING"
	result["admitted"] = true
	result["source_id"] = owner.source_id
	result["life_generation"] = owner.life_generation
	result["frame_id"] = frame_id
	result["restarts"] = _restarts
	result["expanded"] = _expanded
	result["visited"] = _visited
	result["retained_nodes"] = _s.get("nodes", {}).size() if result.status == "PENDING" else 0
	queue.finish()
	# Do not retain actor, provider, search, or queue references after the slice.
	_s = {}; _rows.clear(); _pass = Callable(); _resolver = Callable(); _queue = null
	_busy = false
	_running = null
	return result

func _expired() -> bool:
	return _fault or _queue.expired()

func _row(r: int) -> float:
	return _r + r * 0.25 if _s.get("fine", false) else r + 0.5

func _column(c: int) -> float:
	return _c + c * 0.25 if _s.get("fine", false) else c + 0.5

func _hypot(a: float, b: float) -> float:
	# Inputs bounded above: no overflow/underflow in world-domain lengths.
	return sqrt(a * a + b * b)

func _heuristic(r: int, c: int) -> float:
	if not _s.get("fine", false) and not _s.get("anchors", {}).is_empty():
		var best := INF
		for a: Dictionary in _s.anchors.values(): best = minf(best, absf(_row(r) - a.r) + absf(_column(c) - a.c))
		return best
	var dr := absf(_row(r) - _gr)
	var dc := absf(_column(c) - _gc)
	return maxf(0.0, maxf(dr - _radius, maxf(dc - _radius, dr + dc - sqrt(2.0) * _radius)))

func _less(a: Dictionary, b: Dictionary) -> bool:
	return a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.node.key < b.node.key)))

func _push(entry: Dictionary) -> void:
	var heap: Array = _s.heap
	var i := heap.size()
	heap.append(entry)
	while i > 0:
		var p := (i - 1) >> 1
		if not _less(entry, heap[p]): break
		heap[i] = heap[p]; i = p
	heap[i] = entry

func _pop() -> Dictionary:
	var heap: Array = _s.heap
	var result: Dictionary = heap[0]
	var last: Dictionary = heap.pop_back()
	if not heap.is_empty():
		var i := 0
		while i * 2 + 1 < heap.size():
			var child := i * 2 + 1
			if child + 1 < heap.size() and _less(heap[child + 1], heap[child]): child += 1
			if not _less(heap[child], last): break
			heap[i] = heap[child]; i = child
		heap[i] = last
	return result

func _slice_pass(r: float, c: float) -> bool:
	if _fault: return false
	var samples: Dictionary = _rows.get(r, {})
	if samples.has(c): return samples[c]
	var value: Variant = _pass.call(r, c)
	if not value is bool:
		_fault = true
		return false
	if _points < 8192:
		if not _rows.has(r): _rows[r] = samples
		samples[c] = value; _points += 1
	return value and not _fault

func _sweep(fr: float, fc: float, r: float, c: float) -> Dictionary:
	if _fault: return {"swept": true, "blocked": true}
	var result: Variant = _resolver.call({"mode": "sweep", "from": {"r": fr, "c": fc}, "to": {"r": r, "c": c}, "radius": 0.18})
	if result == null: return {}
	if not result is Dictionary:
		_fault = true
		return {"swept": true, "blocked": true}
	if (result.has("swept") and not result.swept is bool) or (result.has("blocked") and not result.blocked is bool):
		_fault = true
		return {"swept": true, "blocked": true}
	return result

func _edge(fr: float, fc: float, r: float, c: float) -> bool:
	var segments := maxi(1, int(ceil(_hypot(r - fr, c - fc) / 0.14)))
	for step in range(1, segments + 1):
		if not _slice_pass(fr + (r - fr) * step / segments, fc + (c - fc) * step / segments): return false
	var swept := _sweep(fr, fc, r, c)
	return not (swept.get("swept") == true and swept.get("blocked", false))

func _pending() -> Dictionary:
	_s.host_restarts = _restarts
	return {"status": "PENDING"}

func _ready(path: Array, kind: String) -> Dictionary:
	return {"status": "READY", "path": path, "kind": kind}

func _near_done(discovery: Dictionary) -> bool:
	var i: int = discovery.index
	return i < discovery.candidates.size() and discovery.candidates[i].d > _radius and not discovery.anchors.is_empty() and i > 0 and discovery.candidates[i - 1].d <= _radius

func _same_callable(a: Variant, b: Callable) -> bool:
	# Godot method Callable equality may ignore bound-argument differences.
	return a is Callable and a == b and a.get_bound_arguments() == b.get_bound_arguments() and a.get_unbound_arguments_count() == b.get_unbound_arguments_count()

func _run(max_visited: int, kind: String) -> Dictionary:
	var sr := int(floor(_r)); var sc := int(floor(_c))
	var start_key := sr * _cols + sc
	var key := [_r, _c, _gr, _gc, _radius, max_visited, kind, _cols]
	if _s.is_empty() or _s.get("algorithm") != "astar-visit" or _s.get("key") != key or not _same_callable(_s.get("pass"), _pass) or not _same_callable(_s.get("resolver"), _resolver):
		if not _s.is_empty(): _restarts += 1
		var first := {"r": sr, "c": sc, "key": start_key, "g": 0.0, "closed": false}
		_s = {"algorithm": "astar-visit", "key": key, "pass": _pass, "resolver": _resolver, "heap": [], "nodes": {start_key: first}, "qi": 0, "best": first, "bestD": _hypot(sr + 0.5 - _gr, sc + 0.5 - _gc), "startKey": start_key, "limit": max_visited}
		var length := _hypot(_gr - _r, _gc - _c)
		_s.direct = {"sample": 0, "count": maxi(1, int(ceil(length / 0.14))), "swept": false} if length > 0.0 and length <= 8.0 else null
		var h := _heuristic(sr, sc)
		_push({"node": first, "g": 0.0, "h": h, "f": h})
	if _s.direct != null:
		var direct: Dictionary = _s.direct
		if not direct.swept and not _expired():
			var swept := _sweep(_r, _c, _gr, _gc)
			if swept.get("swept") != true or swept.get("blocked", false): _s.direct = null
			else: direct.swept = true
		while _s.direct != null and direct.swept and direct.sample < direct.count and not _expired():
			var t: float = float(direct.sample + 1) / direct.count
			if not _slice_pass(_r + (_gr - _r) * t, _c + (_gc - _c) * t):
				_s.direct = null
				break
			direct.sample += 1
		if _s.direct != null:
			if direct.swept and direct.sample == direct.count:
				var swept := _sweep(_r, _c, _gr, _gc)
				if swept.get("swept") == true and not swept.get("blocked", false):
					_expanded = 0; _visited = 1
					return _ready([{"r": _gr, "c": _gc}], kind)
				_s.direct = null
			if _s.direct != null: return _pending()
	if not _s.has("anchors"):
		if _s.get("discovery") == null:
			var candidates: Array = []
			for r in range(int(floor(_gr - 2.25)), int(floor(_gr + 2.25)) + 1):
				for c in range(int(floor(_gc - 2.25)), int(floor(_gc + 2.25)) + 1):
					var rr := r + 0.5; var cc := c + 0.5
					var d := _hypot(rr - _gr, cc - _gc)
					if d <= 2.25: candidates.append({"r": rr, "c": cc, "key": r * _cols + c, "d": d})
			candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d < b.d or (a.d == b.d and a.key < b.key))
			_s.discovery = {"candidates": candidates, "index": 0, "anchors": {}}
		var discovery: Dictionary = _s.discovery
		while discovery.index < discovery.candidates.size() and not _expired():
			var a: Dictionary = discovery.candidates[discovery.index]
			if _near_done(discovery): break
			discovery.index += 1
			if _slice_pass(a.r, a.c) and _edge(a.r, a.c, _gr, _gc): discovery.anchors[a.key] = a
		if discovery.index < discovery.candidates.size() and not _near_done(discovery): return _pending()
		_s.anchors = discovery.anchors; _s.discovery = null
	if _s.anchors.is_empty() and not _s.get("fine", false) and not _s.get("isolated", false):
		if not _s.has("probe"): _s.probe = {"index": 0, "free": false}
		var probe: Dictionary = _s.probe
		while probe.index < DIRS.size() and not _expired():
			var step: Array = DIRS[probe.index]; probe.index += 1
			var r: float = sr + step[0] + 0.5; var c: float = sc + step[1] + 0.5
			if _slice_pass(r, c) and _edge(_r, _c, r, c):
				probe.free = true
				break
		if probe.free:
			_expanded = 0; _visited = 1
			return {"status": "NO_PATH"}
		if probe.index < DIRS.size(): return _pending()
		_s.isolated = true
	while true:
		var goal: Variant = null
		var nodes: Dictionary = _s.nodes
		while not _s.heap.is_empty() and nodes.size() < _s.limit and not _expired():
			var entry := _pop(); var cur: Dictionary = entry.node
			if cur.closed or entry.g != cur.g: continue
			cur.closed = true; _s.qi += 1
			var cr := _row(cur.r); var cc := _column(cur.c)
			var dist := _hypot(cr - _gr, cc - _gc)
			if dist < _s.bestD: _s.bestD = dist; _s.best = cur
			var terminal: bool = dist <= _radius if _s.get("fine", false) else _s.anchors.has(cur.key)
			var fr: float = _r if cur.key == _s.startKey else cr
			var fc: float = _c if cur.key == _s.startKey else cc
			if terminal:
				if _slice_pass(fr, fc) and _edge(fr, fc, _gr, _gc):
					goal = cur
					break
				if not _s.get("fine", false):
					_s.anchors.erase(cur.key)
					if _s.anchors.is_empty():
						_expanded = _s.qi; _visited = nodes.size()
						return {"status": "NO_PATH"}
			for step: Array in DIRS:
				var r: int = cur.r + step[0]; var c: int = cur.c + step[1]
				var node_key: Variant = str(r) + "," + str(c) if _s.get("fine", false) else r * _cols + c
				var existing: Variant = nodes.get(node_key)
				if existing != null and existing.closed: continue
				var rr := _row(r); var rc := _column(c)
				var length := _hypot(rr - fr, rc - fc); var g: float = cur.g + length
				if (existing != null and g >= existing.g) or not _slice_pass(rr, rc) or not _edge(fr, fc, rr, rc): continue
				var node: Dictionary = existing if existing != null else {"r": r, "c": c, "key": node_key, "closed": false}
				node.g = g; node.parent = cur.key
				if existing == null: nodes[node_key] = node
				var h := _heuristic(r, c)
				_push({"node": node, "g": g, "h": h, "f": g + h})
		if goal == null and not _s.heap.is_empty() and nodes.size() < _s.limit: return _pending()
		if goal == null and not _s.get("fine", false) and _s.qi == 1 and nodes.size() == 1 and max_visited > 2:
			var first := {"r": 0, "c": 0, "key": "0,0", "g": 0.0, "closed": false}
			_s.merge({"fine": true, "startKey": first.key, "heap": [], "nodes": {first.key: first}, "qi": 0, "coarseExpanded": 1, "best": first, "bestD": _hypot(_r - _gr, _c - _gc), "limit": max_visited - 1}, true)
			var h := _heuristic(0, 0)
			_push({"node": first, "g": 0.0, "h": h, "f": h})
			continue
		_expanded = _s.qi + _s.get("coarseExpanded", 0)
		_visited = nodes.size() + _s.get("coarseExpanded", 0)
		if goal == null: return {"status": "NO_PATH"}
		var path: Array = [{"r": _gr, "c": _gc}]
		while goal != null and goal.key != _s.startKey:
			path.append({"r": _row(goal.r), "c": _column(goal.c)})
			goal = nodes.get(goal.parent)
		path.reverse()
		return _ready(path, kind)
	return {"status": "NO_PATH"}
