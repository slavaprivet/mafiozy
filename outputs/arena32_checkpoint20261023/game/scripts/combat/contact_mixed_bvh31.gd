extends RefCounted
## Immutable authored topology, with actor-local lazy exact skinning caches.
## Build uses only arrays; no scene objects or renderer readback on workers.
const Segment = preload("res://scripts/combat/segment_triangle29.gd")
var points := PackedVector3Array()
var bones := PackedInt32Array()
var weights := PackedFloat32Array()
var indices := PackedInt32Array()
var orders := PackedInt32Array()
var left := PackedInt32Array()
var right := PackedInt32Array()
var parent := PackedInt32Array()
var first := PackedInt32Array()
var count := PackedInt32Array()
var sequence := PackedInt32Array()
var influence_bounds: Array[Dictionary] = []
var safe := PackedByteArray()
var sum_error := PackedFloat64Array()
var _centres := PackedVector3Array()
var bind_count := 0
var _binds: Array[Transform3D] = []
var transform := Transform3D.IDENTITY
var _has_pose := false
var _world_points := PackedVector3Array()
var _posed := PackedByteArray()
var _world_boxes: Array[AABB] = []
var _box_ready := PackedByteArray()
var _triangle_boxes: Array[AABB] = []
var _triangle_normals := PackedVector3Array()
var _triangle_ready := PackedByteArray()
var _triangle_finite := PackedByteArray()
# Exact subtree bounds become available lazily, starting at visited leaves.
# Internal nodes merge cached children only; refit never poses extra vertices.
var _leaf_boxes: Array[AABB] = []
var _leaf_ready := PackedByteArray()
var _leaf_finite := PackedByteArray()
var world_bounds := AABB()
var bounds_safe := false
var visits := 0
var candidates := 0
var exact := 0
var posed_vertices := 0

func build(data: Dictionary, group: Dictionary, bindings: int) -> void:
	points=data.points; bones=data.bones; weights=data.weights
	indices=group.indices; orders=group.orders; bind_count=bindings
	var ids: Array[int] = []
	for triangle in orders.size():
		var offset:=triangle*3
		_centres.append((points[indices[offset]]+points[indices[offset+1]]+points[indices[offset+2]])/3.0)
		ids.append(triangle)
	if not ids.is_empty(): _build_node(ids)
	_allocate_pose()

func _allocate_pose() -> void:
	_world_points.resize(points.size()); _posed.resize(points.size())
	_world_boxes.resize(left.size()); _box_ready.resize(left.size())
	_triangle_boxes.resize(orders.size()); _triangle_normals.resize(orders.size())
	_triangle_ready.resize(orders.size()); _triangle_finite.resize(orders.size())
	_leaf_boxes.resize(left.size()); _leaf_ready.resize(left.size()); _leaf_finite.resize(left.size())

func instantiate_pose31() -> RefCounted:
	var pose: RefCounted=get_script().new()
	pose.points=points; pose.bones=bones; pose.weights=weights
	pose.indices=indices; pose.orders=orders; pose.bind_count=bind_count
	pose.left=left; pose.right=right; pose.parent=parent; pose.first=first; pose.count=count
	pose.sequence=sequence; pose.influence_bounds=influence_bounds; pose.safe=safe; pose.sum_error=sum_error
	pose._allocate_pose()
	return pose

func _build_node(ids: Array[int], parent_index: int=-1) -> int:
	var node:=left.size()
	left.append(-1); right.append(-1); first.append(-1); count.append(0)
	parent.append(parent_index)
	var boxes: Dictionary={}; var seen: Dictionary={}; var safe_node:=true; var error:=0.0
	var low:=_centres[ids[0]]; var high:=low
	for triangle: int in ids:
		low=low.min(_centres[triangle]); high=high.max(_centres[triangle])
		for corner in 3:
			var vertex:=indices[triangle*3+corner]
			if seen.has(vertex): continue
			seen[vertex]=true
			var total:=0.0
			for slot in 4:
				var k:=vertex*4+slot
				if k>=weights.size() or k>=bones.size(): continue
				var weight:=weights[k]; var influence:=bones[k]
				if not is_finite(weight): safe_node=false; continue
				if weight<=0.0 or influence<0 or influence>=bind_count: continue
				total+=weight
				boxes[influence]=AABB(boxes[influence]).expand(points[vertex]) if boxes.has(influence) else AABB(points[vertex],Vector3.ZERO)
			if total==0.0:
				boxes[-1]=AABB(boxes[-1]).expand(points[vertex]) if boxes.has(-1) else AABB(points[vertex],Vector3.ZERO)
			elif absf(total-1.0)>.0001:
				# Non-normalized authored data remains exact, without broadphase culling.
				safe_node=false
			else: error=maxf(error,absf(total-1.0))
			if not points[vertex].is_finite(): safe_node=false
	influence_bounds.append(boxes); safe.append(1 if safe_node else 0); sum_error.append(error)
	if ids.size()<=8:
		first[node]=sequence.size(); count[node]=ids.size()
		sequence.append_array(PackedInt32Array(ids))
		return node
	var axis: int=(high-low).max_axis_index(); var middle: float=(high[axis]+low[axis])*.5
	var a: Array[int]=[]; var b: Array[int]=[]
	for triangle: int in ids:
		if _centres[triangle][axis]<middle: a.append(triangle)
		else: b.append(triangle)
	if a.is_empty() or b.is_empty():
		var half: int=ids.size()/2
		a.assign(ids.slice(0,half)); b.assign(ids.slice(half))
	left[node]=_build_node(a,node); right[node]=_build_node(b,node)
	return node

func set_pose(bindings: Array[Transform3D], node_transform: Transform3D) -> void:
	if _has_pose and transform==node_transform and _binds==bindings: return
	_binds.assign(bindings); transform=node_transform; _has_pose=true
	_posed.fill(0); _box_ready.fill(0)
	_triangle_ready.fill(0); _leaf_ready.fill(0)
	bounds_safe=not safe.is_empty() and safe[0]!=0 and _binds.size()==bind_count
	world_bounds=_bounds(0) if not left.is_empty() else AABB()

func _bounds(node: int) -> AABB:
	if _box_ready[node]!=0: return _world_boxes[node]
	var box:=AABB(); var initial:=true
	for influence: int in influence_bounds[node]:
		var frame:=transform
		if influence>=0 and influence<_binds.size(): frame=transform*_binds[influence]
		var next: AABB=frame*AABB(influence_bounds[node][influence])
		box=next if initial else box.merge(next); initial=false
	# Numerical padding affects broadphase only; the final primitive is unchanged.
	# Float32 weights can sum near, but not exactly, one. The unnormalized
	# point equals total * a convex combination in this world box. Expand by
	# |total-1| times its greatest absolute coordinate, not an assumed epsilon.
	var magnitude: Vector3=(box.position-transform.origin).abs().max((box.end-transform.origin).abs())
	var error: float=sum_error[node]*maxf(magnitude.x,maxf(magnitude.y,magnitude.z))
	_world_boxes[node]=box.grow(.001+error); _box_ready[node]=1
	return _world_boxes[node]

func _vertex(vertex: int) -> Vector3:
	if _posed[vertex]!=0: return _world_points[vertex]
	var position:=Vector3.ZERO; var total:=0.0
	for slot in 4:
		var k:=vertex*4+slot
		if k>=weights.size() or k>=bones.size() or weights[k]<=0.0 or bones[k]<0 or bones[k]>=_binds.size(): continue
		position+=(_binds[bones[k]]*points[vertex])*weights[k]; total+=weights[k]
	_world_points[vertex]=transform*(position if total>0.0 else points[vertex])
	_posed[vertex]=1; posed_vertices+=1
	return _world_points[vertex]

func _prepare_leaf(node: int) -> void:
	if _leaf_ready[node]!=0: return
	var box:=AABB(); var initial:=true; var finite:=true
	for cursor in range(first[node],first[node]+count[node]):
		var triangle:=sequence[cursor]
		if _triangle_ready[triangle]==0:
			var offset:=triangle*3
			var a:=_vertex(indices[offset]); var b:=_vertex(indices[offset+1]); var c:=_vertex(indices[offset+2])
			var valid:=a.is_finite() and b.is_finite() and c.is_finite()
			_triangle_finite[triangle]=1 if valid else 0
			_triangle_boxes[triangle]=AABB(a,Vector3.ZERO).expand(b).expand(c).grow(.001) if valid else AABB()
			_triangle_normals[triangle]=(b-a).cross(c-a).normalized()
			_triangle_ready[triangle]=1
		finite=finite and _triangle_finite[triangle]!=0
		box=_triangle_boxes[triangle] if initial else box.merge(_triangle_boxes[triangle]); initial=false
	_leaf_boxes[node]=box; _leaf_finite[node]=1 if finite else 0; _leaf_ready[node]=1
	var ancestor:=parent[node]
	while ancestor>=0:
		var a:=left[ancestor]; var b:=right[ancestor]
		if _leaf_ready[a]==0 or _leaf_ready[b]==0: break
		# Each parent can become exact only once per pose. A nonfinite subtree
		# remains explicitly uncullable, even when its sibling is finite.
		if _leaf_ready[ancestor]!=0: break
		_leaf_boxes[ancestor]=_leaf_boxes[a].merge(_leaf_boxes[b])
		_leaf_finite[ancestor]=1 if _leaf_finite[a]!=0 and _leaf_finite[b]!=0 else 0
		_leaf_ready[ancestor]=1
		ancestor=parent[ancestor]

func intersections(from: Vector3, to: Vector3, all_hits: bool=false) -> Array[Dictionary]:
	var hits: Array[Dictionary]=[]
	var squared_length:=from.distance_squared_to(to)
	if left.is_empty() or not _has_pose or squared_length<=0.0: return hits
	var stack: Array[int]=[0]; var closest:=INF; var closest_order:=2147483647
	while not stack.is_empty():
		var node: int=stack.pop_back(); visits+=1
		# A changed bind count is malformed for this topology: exact fallback.
		if _leaf_ready[node]!=0:
			if _leaf_finite[node]!=0 and not _leaf_boxes[node].intersects_segment(from,to): continue
		elif safe[node]!=0 and _binds.size()==bind_count and not _bounds(node).intersects_segment(from,to): continue
		if left[node]>=0:
			stack.append(right[node]); stack.append(left[node]); continue
		_prepare_leaf(node)
		if _leaf_finite[node]!=0 and not _leaf_boxes[node].intersects_segment(from,to): continue
		for cursor in range(first[node],first[node]+count[node]):
			var triangle:=sequence[cursor]; candidates+=1
			if _triangle_finite[triangle]!=0 and not _triangle_boxes[triangle].intersects_segment(from,to): continue
			var offset:=triangle*3
			var a:=_world_points[indices[offset]]; var b:=_world_points[indices[offset+1]]; var c:=_world_points[indices[offset+2]]
			exact+=1
			var point: Variant=Segment.intersect(from,to,a,b,c)
			if point==null: continue
			var fraction:=sqrt(from.distance_squared_to(point)/squared_length)
			if not all_hits and (fraction>closest or (fraction==closest and orders[triangle]>=closest_order)): continue
			var normal: Vector3=_triangle_normals[triangle]
			if normal.length_squared()<.5: continue
			if normal.dot(to-from)>0: normal=-normal
			if not all_hits: hits.clear(); closest=fraction; closest_order=orders[triangle]
			hits.append({"position":point,"normal":normal,"fraction":fraction,"order":orders[triangle],"face":orders[triangle]})
	return hits
