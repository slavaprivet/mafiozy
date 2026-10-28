extends RefCounted
## Immutable bind-space broadphase; the final intersection always uses the exact
## current WORLD-space triangle and the shared scale-aware segment primitive.
const Segment = preload("res://scripts/combat/segment_triangle29.gd")
var points := PackedVector3Array()
var orders := PackedInt32Array()
var bounds: Array[AABB] = []
var left := PackedInt32Array()
var right := PackedInt32Array()
var first := PackedInt32Array()
var count := PackedInt32Array()
var sequence := PackedInt32Array()
var _triangle_bounds: Array[AABB] = []
var _centres := PackedVector3Array()
var _world_points := PackedVector3Array()
var _posed := PackedByteArray()
var transform := Transform3D.IDENTITY
var inverse := Transform3D.IDENTITY
var world_bounds := AABB()
var _has_transform := false
var visits := 0
var candidates := 0
var exact := 0
var posed_triangles := 0

func instantiate_pose31() -> RefCounted:
	# Arrays above are immutable once built. Share them; only world-space points,
	# transform, pose flags and counters belong to each independently moving actor.
	var pose: RefCounted = get_script().new()
	pose.points = points; pose.orders = orders
	pose.bounds = bounds; pose.left = left; pose.right = right
	pose.first = first; pose.count = count; pose.sequence = sequence
	pose._triangle_bounds = _triangle_bounds; pose._centres = _centres
	pose._world_points.resize(points.size())
	pose._posed.resize(orders.size())
	return pose

func build(vertices: PackedVector3Array, triangle_orders: PackedInt32Array) -> void:
	points = vertices
	orders = triangle_orders
	var ids: Array[int] = []
	for triangle in orders.size():
		var a := points[triangle * 3]
		var b := points[triangle * 3 + 1]
		var c := points[triangle * 3 + 2]
		# This is conservative broadphase padding, never a collision margin.
		var box := AABB(a, Vector3.ZERO).expand(b).expand(c).grow(.001)
		_triangle_bounds.append(box)
		_centres.append((a + b + c) / 3.0)
		ids.append(triangle)
	if not ids.is_empty(): _build_node(ids)
	_world_points.resize(points.size())
	_posed.resize(orders.size())

func _build_node(ids: Array[int]) -> int:
	var index := bounds.size()
	var box := _triangle_bounds[ids[0]]
	var centre_min := _centres[ids[0]]
	var centre_max := centre_min
	for triangle: int in ids:
		box = box.merge(_triangle_bounds[triangle])
		centre_min = centre_min.min(_centres[triangle])
		centre_max = centre_max.max(_centres[triangle])
	bounds.append(box)
	left.append(-1); right.append(-1); first.append(-1); count.append(0)
	if ids.size() <= 8:
		first[index] = sequence.size(); count[index] = ids.size()
		sequence.append_array(PackedInt32Array(ids))
		return index
	# A linear spatial partition avoids thousands of script comparator calls at
	# every recursive level after a new cut/death mesh. Bounds remain exhaustive.
	var axis := (centre_max - centre_min).max_axis_index()
	var middle := (centre_min[axis] + centre_max[axis]) * .5
	var first_half: Array[int] = []
	var second_half: Array[int] = []
	for triangle: int in ids:
		if _centres[triangle][axis] < middle: first_half.append(triangle)
		else: second_half.append(triangle)
	if first_half.is_empty() or second_half.is_empty():
		var half := ids.size() / 2
		first_half.assign(ids.slice(0, half)); second_half.assign(ids.slice(half))
	left[index] = _build_node(first_half)
	right[index] = _build_node(second_half)
	return index

func set_transform(value: Transform3D) -> void:
	if _has_transform and transform == value: return
	transform = value
	inverse = transform.affine_inverse()
	world_bounds = transform * bounds[0] if not bounds.is_empty() else AABB()
	_posed.fill(0)
	_has_transform = true

func intersections(from: Vector3, to: Vector3, all_hits: bool = false) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if bounds.is_empty() or not world_bounds.intersects_segment(from, to): return hits
	var local_from := inverse * from
	var local_to := inverse * to
	var stack: Array[int] = [0]
	var squared_length := from.distance_squared_to(to)
	var closest := INF
	while not stack.is_empty():
		var node: int = stack.pop_back()
		visits += 1
		if not bounds[node].intersects_segment(local_from, local_to): continue
		if left[node] >= 0:
			stack.append(right[node]); stack.append(left[node])
			continue
		for cursor in range(first[node], first[node] + count[node]):
			var triangle := sequence[cursor]
			candidates += 1
			if not _triangle_bounds[triangle].intersects_segment(local_from, local_to): continue
			var offset := triangle * 3
			if _posed[triangle] == 0:
				_world_points[offset] = transform * points[offset]
				_world_points[offset + 1] = transform * points[offset + 1]
				_world_points[offset + 2] = transform * points[offset + 2]
				_posed[triangle] = 1; posed_triangles += 1
			var a := _world_points[offset]
			var b := _world_points[offset + 1]
			var c := _world_points[offset + 2]
			exact += 1
			var point: Variant = Segment.intersect(from, to, a, b, c)
			if point == null: continue
			var fraction := sqrt(from.distance_squared_to(point) / squared_length)
			if not all_hits and fraction >= closest: continue
			var normal := (b - a).cross(c - a).normalized()
			if normal.length_squared() < .5: continue
			if normal.dot(to - from) > 0: normal = -normal
			if not all_hits: hits.clear(); closest = fraction
			hits.append({"position": point, "normal": normal, "fraction": fraction, "order": orders[triangle]})
	return hits
