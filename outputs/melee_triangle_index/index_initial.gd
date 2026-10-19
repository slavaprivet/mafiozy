extends RefCounted
## Current-pose broadphase only. No mesh extraction, occlusion or HP authority.
## Source triangle/limb order decides exact score ties regardless of BVH order.
const Kernel = preload("res://scripts/combat/melee_triangle_contact.gd")
const MAX_VERTICES := 65536
const MAX_TRIANGLES := 131072
const LEAF_SIZE := 4
var _indices := PackedInt32Array()
var _vertices := PackedVector3Array()
var _order := PackedInt32Array()
var _left := PackedInt32Array()
var _right := PackedInt32Array()
var _first := PackedInt32Array()
var _count := PackedInt32Array()
var _minimum := PackedVector3Array()
var _maximum := PackedVector3Array()
var _centers := PackedVector3Array()
var _ready := false
var _configured := false
var _disposed := false
var _busy := false
var _reentered := false
var _revision := -1
var _serial := 0
var _query_id := -1
var _contacts: Array[Dictionary] = []
var _filter: Callable
var _heap_nodes := PackedInt32Array()
var _heap_contacts := PackedInt32Array()
var _heap_bounds := PackedFloat64Array()
var _leaf_node := -1
var _leaf_contact := -1
var _leaf_cursor := 0
var _winner := {}
var _winner_triangle := -1
var _winner_contact := -1
var _best := INF
var _stats := {}

func _error(reason: String) -> Dictionary: return {"status":"ERROR","error":reason,"hit":false}
func _enter() -> bool:
	if _busy: _reentered = true; return false
	if not Thread.is_main_thread() or _disposed: return false
	_busy = true; _reentered = false; return true
func _leave(result: Dictionary) -> Dictionary:
	_busy = false
	return result
static func _finite_point(p: Vector3) -> bool:
	return p.is_finite() and maxf(absf(p.x),maxf(absf(p.y),absf(p.z))) <= 10000000.0

func configure(indices: PackedInt32Array, vertices: PackedVector3Array, pose_revision: int) -> Dictionary:
	if not _enter(): return _error("unavailable_or_reentry")
	if _configured: return _leave(_error("already_configured"))
	if indices.is_empty() or indices.size()%3 != 0 or indices.size()/3 > MAX_TRIANGLES or vertices.is_empty() or vertices.size() > MAX_VERTICES or pose_revision < 0: return _leave(_error("topology"))
	for index: int in indices:
		if index < 0 or index >= vertices.size(): return _leave(_error("vertex_index"))
	for point: Vector3 in vertices:
		if not _finite_point(point): return _leave(_error("vertex"))
	_indices = indices.duplicate(); _vertices = vertices.duplicate()
	var ids: Array[int] = []
	for i in indices.size()/3:
		ids.append(i)
		_centers.append((_vertices[_indices[i*3]]+_vertices[_indices[i*3+1]]+_vertices[_indices[i*3+2]])/3.0)
	_build(ids)
	_centers.clear()
	_refit_bounds()
	_revision = pose_revision; _ready = true; _configured = true
	return _leave({"status":"READY","pose_revision":_revision,"triangles":ids.size(),"nodes":_left.size()})

func _build(ids: Array[int]) -> int:
	var node := _left.size()
	_left.append(-1); _right.append(-1); _first.append(-1); _count.append(0)
	_minimum.append(Vector3.ZERO); _maximum.append(Vector3.ZERO)
	if ids.size() <= LEAF_SIZE:
		_first[node] = _order.size(); _count[node] = ids.size()
		for id: int in ids: _order.append(id)
		return node
	var low := _centers[ids[0]]; var high := low
	for id: int in ids:
		low = low.min(_centers[id]); high = high.max(_centers[id])
	var extent := high-low
	var axis := 0 if extent.x >= extent.y and extent.x >= extent.z else 1 if extent.y >= extent.z else 2
	ids.sort_custom(func(a: int,b: int) -> bool: return _centers[a][axis] < _centers[b][axis] if _centers[a][axis] != _centers[b][axis] else a < b)
	var middle := ids.size()/2
	_left[node] = _build(ids.slice(0,middle))
	_right[node] = _build(ids.slice(middle))
	return node

func _refit_bounds() -> void:
	for node in range(_left.size()-1,-1,-1):
		if _left[node] >= 0:
			_minimum[node] = _minimum[_left[node]].min(_minimum[_right[node]])
			_maximum[node] = _maximum[_left[node]].max(_maximum[_right[node]])
		else:
			var low := _vertices[_indices[_order[_first[node]]*3]]; var high := low
			for item in range(_first[node],_first[node]+_count[node]):
				var triangle := _order[item]*3
				for corner in 3:
					var point := _vertices[_indices[triangle+corner]]
					low = low.min(point); high = high.max(point)
			_minimum[node] = low; _maximum[node] = high

func refit(vertices: PackedVector3Array, pose_revision: int) -> Dictionary:
	if not _enter(): return _error("unavailable_or_reentry")
	_clear_query(); _ready = false
	if not _configured or vertices.size() != _vertices.size() or pose_revision <= _revision: return _leave(_error("pose_revision_or_topology"))
	for point: Vector3 in vertices:
		if not _finite_point(point): return _leave(_error("vertex"))
	_vertices = vertices.duplicate(); _refit_bounds(); _revision = pose_revision; _ready = true
	return _leave({"status":"READY","pose_revision":_revision})

func _clear_query() -> void:
	_query_id = -1; _contacts.clear(); _filter = Callable()
	_heap_nodes.clear(); _heap_contacts.clear(); _heap_bounds.clear()
	_leaf_node = -1; _winner.clear(); _best = INF; _winner_triangle = -1; _winner_contact = -1

func begin_query(contacts: Array, pose_revision: int, accept_candidate: Callable = Callable()) -> Dictionary:
	if not _enter(): return _error("unavailable_or_reentry")
	_clear_query()
	if not _ready or pose_revision != _revision or contacts.is_empty() or contacts.size() > 4: return _leave(_error("pose_or_contacts"))
	if not accept_candidate.is_null() and not accept_candidate.is_valid(): return _leave(_error("filter_lifetime"))
	for row: Variant in contacts:
		if not row is Dictionary or not row.get("from") is Vector3 or not row.get("to") is Vector3 or not (row.get("radius") is float or row.get("radius") is int): return _leave(_error("contact"))
		var from: Vector3 = row.from; var to: Vector3 = row.to; var radius := float(row.radius)
		if not _finite_point(from) or not _finite_point(to) or not is_finite(radius) or radius <= 0 or radius > .5: return _leave(_error("contact"))
		var delta := PackedFloat64Array([float(to.x)-float(from.x),float(to.y)-float(from.y),float(to.z)-float(from.z)])
		var length2 := delta[0]*delta[0]+delta[1]*delta[1]+delta[2]*delta[2]
		# Source permits a ray intersection up to length²+1e-10. Its selected
		# line point may lie just beyond the segment end: include that interval.
		var end := sqrt((length2+1e-10)/length2) if length2 > 1e-20 else 1.0
		var scale := maxf(maxf(from.length_squared(),to.length_squared()),1.0)
		_contacts.append({"from":from,"to":to,"radius":radius,"delta":delta,"length2":length2,"end":end,"slack":1e-11*scale})
	_filter = accept_candidate
	_serial += 1; _query_id = _serial
	_stats = {"nodes":0,"kernel_calls":0,"candidate_rejections":0,"filter_calls":0,"slices":0}
	for contact in _contacts.size():
		var bound := _bound(0,_contacts[contact])
		if is_finite(bound): _push(0,contact,bound)
	return _leave({"status":"PENDING","query_id":_query_id,"pose_revision":_revision})

func _bound(node: int, contact: Dictionary) -> float:
	var from: Vector3 = contact.from; var delta: PackedFloat64Array = contact.delta
	var low := _minimum[node]; var high := _maximum[node]
	var start := 0.0; var end := float(contact.end)
	# Conservative sphere/AABB enclosure, including kernel distance epsilon.
	var radius := float(contact.radius)+.00001
	for axis in 3:
		var origin := float(from[axis]); var d := delta[axis]
		if d == 0:
			if origin < float(low[axis])-radius or origin > float(high[axis])+radius: return INF
		else:
			var a := (float(low[axis])-radius-origin)/d; var b := (float(high[axis])+radius-origin)/d
			start = maxf(start,minf(a,b)); end = minf(end,maxf(a,b))
			if start > end: return INF
	# Exact piecewise-quadratic minimum of |from-L(t)|² + dist(L(t),box)².
	# Any source candidate has P in this box and L in the enclosed interval;
	# this bound never assumes closest-point orthogonality or a nonparallel edge.
	var cuts := PackedFloat64Array([start,end])
	for axis in 3:
		if delta[axis] == 0: continue
		for boundary: float in [low[axis],high[axis]]:
			var t := (boundary-float(from[axis]))/delta[axis]
			if t > start and t < end: cuts.append(t)
	cuts.sort()
	var best := INF
	for interval in cuts.size()-1:
		var a := float(contact.length2); var b := 0.0; var c := 0.0
		var middle := (cuts[interval]+cuts[interval+1])*.5
		for axis in 3:
			var position := float(from[axis])+delta[axis]*middle
			var offset := 0.0
			if position < low[axis]: offset = float(from[axis])-float(low[axis])
			elif position > high[axis]: offset = float(from[axis])-float(high[axis])
			else: continue
			a += delta[axis]*delta[axis]; b += delta[axis]*offset; c += offset*offset
		var t := clampf(-b/a,cuts[interval],cuts[interval+1]) if a > 0 else cuts[interval]
		best = minf(best,a*t*t+2*b*t+c)
	return maxf(0.0,best-float(contact.slack))

func _push(node: int, contact: int, bound: float) -> void:
	var at := _heap_nodes.size()
	_heap_nodes.append(node); _heap_contacts.append(contact); _heap_bounds.append(bound)
	while at > 0:
		var parent := (at-1)/2
		if _heap_bounds[parent] <= bound: break
		_heap_nodes[at] = _heap_nodes[parent]; _heap_contacts[at] = _heap_contacts[parent]; _heap_bounds[at] = _heap_bounds[parent]; at = parent
	_heap_nodes[at] = node; _heap_contacts[at] = contact; _heap_bounds[at] = bound

func _pop() -> Vector2i:
	var result := Vector2i(_heap_nodes[0],_heap_contacts[0])
	var last := _heap_nodes.size()-1
	var node := _heap_nodes[last]; var contact := _heap_contacts[last]; var bound := _heap_bounds[last]
	_heap_nodes.resize(last); _heap_contacts.resize(last); _heap_bounds.resize(last)
	if last == 0: return result
	var at := 0
	while at*2+1 < last:
		var child := at*2+1
		if child+1 < last and _heap_bounds[child+1] < _heap_bounds[child]: child += 1
		if bound <= _heap_bounds[child]: break
		_heap_nodes[at] = _heap_nodes[child]; _heap_contacts[at] = _heap_contacts[child]; _heap_bounds[at] = _heap_bounds[child]; at = child
	_heap_nodes[at] = node; _heap_contacts[at] = contact; _heap_bounds[at] = bound
	return result

static func _overlap(a: Vector3,b: Vector3,c: Vector3,contact: Dictionary) -> bool:
	var low := a.min(b).min(c); var high := a.max(b).max(c)
	var from: Vector3 = contact.from; var to: Vector3 = contact.to; var radius: float = contact.radius
	for axis in 3:
		if float(high[axis]) < minf(from[axis],to[axis])-radius or float(low[axis]) > maxf(from[axis],to[axis])+radius: return false
	return true

func advance_query(query_id: int, max_nodes: int = 64, max_kernel_calls: int = 16, budget_usec: int = 1000) -> Dictionary:
	if not _enter(): return _error("unavailable_or_reentry")
	if not _ready or query_id != _query_id or query_id < 0: return _leave(_error("stale_query"))
	if max_nodes < 1 or max_nodes > 1000000 or max_kernel_calls < 1 or max_kernel_calls > MAX_TRIANGLES*4 or budget_usec < 1 or budget_usec > 1000000: return _leave(_error("budget"))
	var began := Time.get_ticks_usec(); var nodes := 0; var calls := 0
	_stats.slices += 1
	while _leaf_node >= 0 or not _heap_nodes.is_empty():
		if nodes >= max_nodes or calls >= max_kernel_calls or Time.get_ticks_usec()-began >= budget_usec:
			return _leave({"status":"PENDING","query_id":_query_id,"pose_revision":_revision,"stats":_stats.duplicate()})
		if _leaf_node < 0:
			if _heap_bounds[0] > _best: break
			var item := _pop(); var node := item.x; var contact := item.y
			nodes += 1; _stats.nodes += 1
			if _left[node] >= 0:
				for child: int in [_left[node],_right[node]]:
					var bound := _bound(child,_contacts[contact])
					if bound <= _best and is_finite(bound): _push(child,contact,bound)
				continue
			_leaf_node = node; _leaf_contact = contact; _leaf_cursor = _first[node]
		var triangle := _order[_leaf_cursor]; _leaf_cursor += 1
		if _leaf_cursor >= _first[_leaf_node]+_count[_leaf_node]: _leaf_node = -1
		var contact: Dictionary = _contacts[_leaf_contact]
		var a := _vertices[_indices[triangle*3]]; var b := _vertices[_indices[triangle*3+1]]; var c := _vertices[_indices[triangle*3+2]]
		if not _overlap(a,b,c,contact): _stats.candidate_rejections += 1; continue
		calls += 1; _stats.kernel_calls += 1
		var result := Kernel.sample(contact.from,contact.to,contact.radius,a,b,c)
		if not result.get("valid",false): _clear_query(); return _leave(_error("kernel:"+str(result.get("error"))))
		if not result.hit: continue
		var score := float(result.score)
		if score > _best or score == _best and (_winner_triangle < triangle or _winner_triangle == triangle and _winner_contact <= _leaf_contact): continue
		if not _filter.is_null():
			if not _filter.is_valid(): _clear_query(); return _leave(_error("filter_lifetime"))
			_stats.filter_calls += 1
			var allowed: Variant = _filter.call({"triangle_index":triangle,"contact_index":_leaf_contact,"candidate":result.duplicate(true),"pose_revision":_revision})
			if _reentered or not _filter.is_valid(): _clear_query(); return _leave(_error("filter_reentry_or_lifetime"))
			if not allowed is bool: _clear_query(); return _leave(_error("filter_reply"))
			if not allowed: continue
		_best = score; _winner = result; _winner_triangle = triangle; _winner_contact = _leaf_contact
	var answer := {"status":"COMPLETE","hit":not _winner.is_empty(),"pose_revision":_revision,"query_id":_query_id,"triangle_index":_winner_triangle,"contact_index":_winner_contact,"candidate":_winner.duplicate(true),"stats":_stats.duplicate(),"filter_applied":not _filter.is_null()}
	_clear_query()
	return _leave(answer)

func cancel_query(query_id: int) -> Dictionary:
	if not _enter(): return _error("unavailable_or_reentry")
	if query_id != _query_id: return _leave(_error("stale_query"))
	_clear_query(); return _leave({"status":"CANCELLED"})

func dispose() -> Dictionary:
	if not _enter(): return _error("unavailable_or_reentry")
	_clear_query(); _ready = false; _disposed = true
	_indices.clear(); _vertices.clear(); _order.clear(); _left.clear(); _right.clear(); _first.clear(); _count.clear(); _minimum.clear(); _maximum.clear()
	return _leave({"status":"DISPOSED"})
