extends RefCounted
## Exact top-level broadphase over actor-local contact views.
## No vertex, bone, scene or renderer access. Unsafe views are always returned.
var _keys: Array = []
var _view_boxes: Array[AABB] = []
var _view_safe := PackedByteArray()
var _unsafe := PackedInt32Array()
var _left := PackedInt32Array()
var _right := PackedInt32Array()
var _first := PackedInt32Array()
var _count := PackedInt32Array()
var _sequence := PackedInt32Array()
var _boxes: Array[AABB] = []
var _has_safe := PackedByteArray()
var builds := 0
var refits := 0
var visits := 0
var view_tests := 0
var returned := 0

func update(keys: Array, boxes: Array[AABB], safe_flags: PackedByteArray) -> void:
	assert(keys.size()==boxes.size() and boxes.size()==safe_flags.size())
	var changed_topology: bool=_keys!=keys
	if not changed_topology and _view_boxes==boxes and _view_safe==safe_flags: return
	_keys=keys.duplicate(); _view_boxes.assign(boxes); _view_safe=safe_flags.duplicate()
	if changed_topology:
		_left.clear(); _right.clear(); _first.clear(); _count.clear()
		_sequence.clear(); _boxes.clear(); _has_safe.clear()
		var ids: Array[int]=[]
		for index in boxes.size(): ids.append(index)
		if not ids.is_empty(): _build(ids)
		builds+=1
	_unsafe.clear()
	for index in _view_safe.size():
		if _view_safe[index]==0: _unsafe.append(index)
	# Children have larger indices than their parent. Every merge is exact and
	# bounded by the number of views, independent of mesh triangle counts.
	for node in range(_left.size()-1,-1,-1):
		var box:=AABB(); var populated:=false
		if _left[node]>=0:
			for child: int in [_left[node],_right[node]]:
				if _has_safe[child]==0: continue
				box=box.merge(_boxes[child]) if populated else _boxes[child]
				populated=true
		else:
			for cursor in range(_first[node],_first[node]+_count[node]):
				var view:=_sequence[cursor]
				if _view_safe[view]==0: continue
				box=box.merge(_view_boxes[view]) if populated else _view_boxes[view]
				populated=true
		_boxes[node]=box; _has_safe[node]=1 if populated else 0
	refits+=1

func _centre(view: int) -> Vector3:
	var box:=_view_boxes[view]
	return box.get_center() if box.position.is_finite() and box.end.is_finite() else Vector3.ZERO

func _build(ids: Array[int]) -> int:
	var node:=_left.size()
	_left.append(-1); _right.append(-1); _first.append(-1); _count.append(0)
	_boxes.append(AABB()); _has_safe.append(0)
	if ids.size()<=4:
		_first[node]=_sequence.size(); _count[node]=ids.size()
		_sequence.append_array(PackedInt32Array(ids))
		return node
	var low:=_centre(ids[0]); var high:=low
	for view: int in ids:
		var centre:=_centre(view)
		low=low.min(centre); high=high.max(centre)
	var axis: int=(high-low).max_axis_index(); var middle: float=(high[axis]+low[axis])*.5
	var a: Array[int]=[]; var b: Array[int]=[]
	for view: int in ids:
		if _centre(view)[axis]<middle: a.append(view)
		else: b.append(view)
	if a.is_empty() or b.is_empty():
		var half: int=ids.size()/2
		a.assign(ids.slice(0,half)); b.assign(ids.slice(half))
	_left[node]=_build(a); _right[node]=_build(b)
	return node

func candidates(from: Vector3, to: Vector3) -> PackedInt32Array:
	# Returned indices address the current ordered view list. Traversal order
	# is not hit order: caller preserves its existing authored-face tie rule.
	var result:=_unsafe.duplicate()
	if _left.is_empty():
		returned+=result.size()
		return result
	var stack: Array[int]=[0]
	while not stack.is_empty():
		var node: int=stack.pop_back(); visits+=1
		if _has_safe[node]==0 or not _boxes[node].intersects_segment(from,to): continue
		if _left[node]>=0:
			stack.append(_right[node]); stack.append(_left[node]); continue
		for cursor in range(_first[node],_first[node]+_count[node]):
			var view:=_sequence[cursor]
			if _view_safe[view]==0: continue
			view_tests+=1
			if _view_boxes[view].intersects_segment(from,to): result.append(view)
	returned+=result.size()
	return result
