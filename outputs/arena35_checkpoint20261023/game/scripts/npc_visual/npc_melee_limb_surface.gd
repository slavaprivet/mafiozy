extends RefCounted
## Visible original hand/boot triangles, not guessed bone spheres. Read-only.
## Continuous bounds refer to LINEAR interpolation between observed poses only.
const Triangle = preload("res://scripts/npc_visual/npc_melee_triangle_contact.gd")
const CONTACT_M := .002
const BOUND_EPS_M := .00005
const MAX_FACES_PER_LIMB := 1024
const MAX_DISTANCE_EVALUATIONS := 1024
const MAX_FRAME_DISTANCE_EVALUATIONS := 2048
const MAX_FRAME_FACE_PREFILTERS := 8192
const MAX_FRAME_CHUNK_PREFILTERS := 32768
const FACES_PER_CHUNK := 8
const MAX_DEPTH := 14
const MAX_VERTEX_TRAVEL_M := .75
var _cache: WeakRef
var _limbs: Dictionary = {}
var _signature := 0
var distance_evaluations := 0
var candidate_faces := 0
var _budget_frame := -1
var _frame_distance_evaluations := 0
var _frame_face_prefilters := 0
var _frame_chunk_prefilters := 0
var preparation_counts: Dictionary = {}

func configure(cache: RefCounted) -> Dictionary:
	if _cache != null or cache == null or not cache._valid(): return {"valid":false,"reason":"geometry_cache"}
	var limbs: Dictionary = {}
	for key: String in ["hand_l","hand_r","foot_l","foot_r"]:
		var entries: Array[Dictionary] = []
		limbs[key] = entries
	var rig: Skeleton3D = cache._rig
	var rest_poses: Array[Transform3D] = cache._bone_poses()
	for sid: int in cache._surfaces.size():
		var surface: Dictionary = cache._surfaces[sid]
		if surface.skin == null: continue
		var matrices: Array[Transform3D] = cache._matrices(surface,rest_poses)
		var dominant := PackedInt32Array()
		dominant.resize(surface.vertices.size())
		for vertex: int in dominant.size():
			var bone := -1
			var largest := 0.0
			for influence: int in 4:
				var at := vertex * 4 + influence
				var weight: float = surface.weights[at]
				var bind: int = surface.bones[at]
				if bind < 0 or bind >= surface.bindings.size() or not is_finite(weight): return {"valid":false,"reason":"skin_binding"}
				if weight > largest: largest = weight; bone = surface.bindings[bind]
			dominant[vertex] = bone
		for offset: int in range(0,surface.indices.size(),3):
			var a: int = surface.indices[offset]
			var b: int = surface.indices[offset+1]
			var c: int = surface.indices[offset+2]
			if a < 0 or b < 0 or c < 0 or maxi(a,maxi(b,c)) >= dominant.size(): return {"valid":false,"reason":"indices"}
			var bone: int = dominant[a]
			if bone < 0 or dominant[b] != bone or dominant[c] != bone: continue
			var name: String = str(rig.get_bone_name(bone))
			if not limbs.has(name): continue
			if limbs[name].size() >= MAX_FACES_PER_LIMB: return {"valid":false,"reason":"limb_topology_budget","limb":name}
			var center: Vector3 = (cache._vertex(surface,a,matrices)+cache._vertex(surface,b,matrices)+cache._vertex(surface,c,matrices))/3.0
			limbs[name].append({"surface":sid,"face":Vector3i(a,b,c),"center":center})
	for key: String in limbs:
		if limbs[key].is_empty(): return {"valid":false,"reason":"no_fully_limb_bound_triangles","limb":key}
		limbs[key] = _spatial_order(limbs[key])
		for row: Dictionary in limbs[key]: row.make_read_only()
		limbs[key].make_read_only()
	_cache = weakref(cache)
	_limbs = limbs
	_signature = cache.get_instance_id()
	return {"valid":true,"scope":"dominant_bound_original_limb_triangles","hand_l":limbs.hand_l.size(),"hand_r":limbs.hand_r.size(),"foot_l":limbs.foot_l.size(),"foot_r":limbs.foot_r.size()}

static func _spatial_order(entries: Array[Dictionary]) -> Array[Dictionary]:
	# Balanced spatial split on the longest local centroid axis, recursively.
	# Split at8-face boundaries so actual chunks stay compact on ALL axes.
	# This is ordering only: every original face survives exactly once.
	if entries.size()<=FACES_PER_CHUNK:return entries
	var centers := PackedVector3Array()
	for row: Dictionary in entries:centers.append(row.center)
	var axis: int = _box(centers).size.max_axis_index()
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.center[axis]<b.center[axis])
	var chunks: int = (entries.size()+FACES_PER_CHUNK-1)/FACES_PER_CHUNK
	var split: int = (chunks/2)*FACES_PER_CHUNK
	var ordered: Array[Dictionary] = _spatial_order(entries.slice(0,split))
	ordered.append_array(_spatial_order(entries.slice(split)))
	return ordered

static func _chunk_tree(chunks: Array[AABB]) -> Array[AABB]:
	var result: Array[AABB] = []
	if chunks.is_empty():return result
	var width := 1
	while width<chunks.size():width*=2
	result.resize(width*2-1)
	# Padded leaves repeat last bounds; traversal explicitly skips those leaves.
	# Thus all internal unions stay finite without a fake origin/world box.
	for leaf: int in width:result[width-1+leaf]=chunks[mini(leaf,chunks.size()-1)]
	for node: int in range(width-2,-1,-1):result[node]=result[node*2+1].merge(result[node*2+2])
	return result

static func _clipped_bounds(first: AABB,last: AABB,lo: float,hi: float) -> AABB:
	# For every linearly moving vertex p(t), interpolated endpoint minima<=p(t)
	# and maxima>=p(t). Union at clip endpoints therefore encloses whole window.
	if lo==0.0 and hi==1.0:return first.merge(last)
	var low: Vector3=first.position.lerp(last.position,lo).min(first.position.lerp(last.position,hi))
	var high: Vector3=first.end.lerp(last.end,lo).max(first.end.lerp(last.end,hi))
	return AABB(low,high-low)

func sample(kind: String, side: String) -> Dictionary:
	var cache: RefCounted = _cache.get_ref() if _cache != null else null
	if cache == null or not cache._valid() or side not in ["l","r"] or kind not in ["punch","heavy","kick","dropkick"]: return {"valid":false,"reason":"limb_or_lifetime"}
	var key: String = ("foot_" if kind in ["kick","dropkick"] else "hand_") + side
	var poses: Array[Transform3D] = cache._bone_poses()
	var by_surface: Dictionary = {}
	var triangles := PackedVector3Array()
	var faces: Array[Dictionary] = []
	for row: Dictionary in _limbs[key]:
		var surface: Dictionary = cache._surfaces[row.surface]
		var mesh: MeshInstance3D = surface.node.get_ref()
		if not mesh.is_visible_in_tree(): continue
		if not by_surface.has(row.surface): by_surface[row.surface] = {"matrices":cache._matrices(surface,poses),"vertices":{}}
		var entry: Dictionary = by_surface[row.surface]
		for index: int in [row.face.x,row.face.y,row.face.z]:
			if not entry.vertices.has(index): entry.vertices[index] = cache._vertex(surface,index,entry.matrices)
			var point: Vector3 = entry.vertices[index]
			if not point.is_finite(): return {"valid":false,"reason":"nonfinite_posed_vertex"}
			triangles.append(point)
		faces.append(row)
	if triangles.is_empty() or not cache._valid(): return {"valid":false,"reason":"invisible_or_changed"}
	# Full visible topology is immutable and canonical. Adjacent pose samples
	# share its identity, avoiding hundreds of repeated Dictionary comparisons
	# for every candidate target face. Partial visibility retains exact arrays.
	if faces.size() == _limbs[key].size(): faces = _limbs[key]
	var face_bounds: Array[AABB] = []
	for start: int in range(0,triangles.size(),3):
		var low: Vector3 = triangles[start].min(triangles[start+1]).min(triangles[start+2])
		var high: Vector3 = triangles[start].max(triangles[start+1]).max(triangles[start+2])
		face_bounds.append(AABB(low,high-low))
	var chunks: Array[AABB] = []
	for start: int in range(0,face_bounds.size(),FACES_PER_CHUNK):
		var bounds: AABB = face_bounds[start]
		for index: int in range(start+1,mini(start+FACES_PER_CHUNK,face_bounds.size())): bounds = bounds.merge(face_bounds[index])
		chunks.append(bounds)
	return {"valid":true,"cache_id":_signature,"rig_id":cache._rig.get_instance_id(),"limb":key,"physics_frame":Engine.get_physics_frames(),"triangles":triangles,"faces":faces,"chunk_bounds":chunks,"face_bounds":face_bounds,"tree_bounds":_chunk_tree(chunks)}

static func target_triangle(cache: RefCounted, result: Dictionary) -> Dictionary:
	if cache == null or not cache._valid() or not result.get("hit",false) or not result.get("face_indices") is Vector3i or not result.get("surface_index") is int: return {"valid":false,"reason":"target_receipt"}
	var sid: int = result.surface_index
	if sid < 0 or sid >= cache._surfaces.size(): return {"valid":false,"reason":"target_surface"}
	var surface: Dictionary = cache._surfaces[sid]
	var mesh: MeshInstance3D = surface.node.get_ref()
	if not mesh.is_visible_in_tree(): return {"valid":false,"reason":"target_hidden"}
	var matrices: Array[Transform3D] = cache._matrices(surface,cache._bone_poses())
	var points := PackedVector3Array()
	for index: int in [result.face_indices.x,result.face_indices.y,result.face_indices.z]:
		if index < 0 or index >= surface.vertices.size(): return {"valid":false,"reason":"target_index"}
		var point: Vector3 = cache._vertex(surface,index,matrices)
		if not point.is_finite(): return {"valid":false,"reason":"target_vertex"}
		points.append(point)
	var output := result.duplicate()
	output.vertices = points
	output.physics_frame = Engine.get_physics_frames()
	output.target_cache_id = cache.get_instance_id()
	return output

func query_confirmation(previous: Dictionary, current: Dictionary, lo: float, hi: float) -> Callable:
	# One holder per synchronous surface sweep, owned only by its Callable.
	# No frame-global pose cache and no O(face count) eager preparation. The
	# instance retains only bounded scalar diagnostics, never the pose holder.
	var counts := {"node_builds":0,"node_reuses":0,"face_builds":0,"face_reuses":0,"triangle_builds":0,"triangle_reuses":0,"invalidations":0}
	preparation_counts = counts
	var preparation := {"previous":previous,"current":current,"frame":Engine.get_physics_frames(),"cache_id":_signature,"rig_id":current.get("rig_id"),"limb":current.get("limb"),"lo":lo,"hi":hi,"usable":true,"nodes":{},"faces":{},"triangles":{},"counts":counts}
	return _confirm_prepared_candidate.bind(previous,current,lo,hi,preparation)

func confirm_candidate(hit: Dictionary, previous: Dictionary, current: Dictionary, lo: float, hi: float) -> Dictionary:
	return _confirm_prepared_candidate(hit,previous,current,lo,hi,{})

func _confirm_prepared_candidate(hit: Dictionary, previous: Dictionary, current: Dictionary, lo: float, hi: float, preparation: Dictionary) -> Dictionary:
	if not hit.get("triangle") is PackedVector3Array or not hit.get("previous_triangle") is PackedVector3Array: return {"valid":false,"reason":"both_observed_target_triangles_required"}
	var target := hit.duplicate()
	target.vertices = hit.triangle
	target.previous_vertices = hit.previous_triangle
	target.physics_frame = Engine.get_physics_frames()
	return _confirm(previous,current,lo,hi,target,preparation)

func confirm(previous: Dictionary, current: Dictionary, lo: float, hi: float, target: Dictionary) -> Dictionary:
	return _confirm(previous,current,lo,hi,target,{})

func _preparation_matches(preparation: Dictionary, previous: Dictionary, current: Dictionary, lo: float, hi: float) -> bool:
	if preparation.is_empty() or not preparation.usable: return false
	if preparation.frame == Engine.get_physics_frames() and preparation.cache_id == _signature and preparation.rig_id == current.get("rig_id") and preparation.limb == current.get("limb") and preparation.lo == lo and preparation.hi == hi and is_same(preparation.previous,previous) and is_same(preparation.current,current): return true
	preparation.usable = false
	preparation.nodes.clear();preparation.faces.clear();preparation.triangles.clear()
	preparation.counts.invalidations += 1
	return false

static func _aabb_interval_endpoints(first: AABB, last: AABB, lo: float, hi: float) -> PackedFloat64Array:
	# Endpoint min/max interpolation encloses every linearly moving vertex.
	# Keep scalar doubles rather than constructing rounded world-space Vector3s.
	var result := PackedFloat64Array()
	result.resize(12)
	var first_end: Vector3 = first.end
	var last_end: Vector3 = last.end
	for axis: int in 3:
		var first_low: float = first.position[axis]
		var last_low: float = last.position[axis]
		# Retain the outer of scalar sum and real_t AABB.end to avoid an inward
		# extra rounding when converting existing original-vertex bounds.
		var first_high: float = maxf(first_low+first.size[axis],first_end[axis])
		var last_high: float = maxf(last_low+last.size[axis],last_end[axis])
		result[axis*4] = lerpf(first_low,last_low,lo)
		result[axis*4+1] = lerpf(first_high,last_high,lo)
		result[axis*4+2] = lerpf(first_low,last_low,hi)
		result[axis*4+3] = lerpf(first_high,last_high,hi)
	return result

static func _triangle_interval_endpoints(first: PackedVector3Array, last: PackedVector3Array, lo: float, hi: float) -> PackedFloat64Array:
	# Prepared once per target face. Bounds at the actual clipped endpoints
	# are tighter than interpolation of full-frame target min/max values.
	var result := PackedFloat64Array()
	result.resize(12)
	for axis: int in 3:
		var low_lo := INF
		var high_lo := -INF
		var low_hi := INF
		var high_hi := -INF
		for vertex: int in 3:
			var at_lo: float = lerpf(first[vertex][axis],last[vertex][axis],lo)
			var at_hi: float = lerpf(first[vertex][axis],last[vertex][axis],hi)
			low_lo=minf(low_lo,at_lo);high_lo=maxf(high_lo,at_lo)
			low_hi=minf(low_hi,at_hi);high_hi=maxf(high_hi,at_hi)
		result[axis*4]=low_lo;result[axis*4+1]=high_lo
		result[axis*4+2]=low_hi;result[axis*4+3]=high_hi
	return result

static func _interval_bounds_separated(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
	# SAME orientation at BOTH endpoints proves separation throughout: lower
	# bounds are linear underestimates, upper bounds linear overestimates.
	# This removes common-motion false overlap before BVH descent/face visits.
	# Preserve both original broadphase paddings (limb50um + target2050um).
	var clearance: float = CONTACT_M+2.0*BOUND_EPS_M
	for axis: int in 3:
		var at: int = axis*4
		if (a[at]-b[at+1]>clearance and a[at+2]-b[at+3]>clearance) or (b[at]-a[at+1]>clearance and b[at+2]-a[at+3]>clearance): return true
	return false

func _prepared_bounds(preparation: Dictionary, node: bool, index: int, old: AABB, now: AABB, lo: float, hi: float) -> Array:
	var entries: Dictionary = preparation.nodes if node else preparation.faces
	var entry: Array = entries.get(index,[])
	# Re-read source values on every logical visit. In-place source mutations
	# cannot reuse a stale bound even if the Dictionary identity is unchanged.
	if not entry.is_empty() and entry[0] == old and entry[1] == now:
		preparation.counts["node_reuses" if node else "face_reuses"] += 1
		return entry
	if not entry.is_empty(): preparation.counts.invalidations += 1
	var bounds: AABB = _clipped_bounds(old,now,lo,hi).grow(BOUND_EPS_M)
	entry = [old,now,bounds,_aabb_interval_endpoints(old,now,lo,hi)]
	entries[index] = entry
	preparation.counts["node_builds" if node else "face_builds"] += 1
	return entry

func _prepared_triangles(preparation: Dictionary, face: int, old: PackedVector3Array, now: PackedVector3Array) -> Array:
	var entry: Array = preparation.triangles.get(face,[])
	if not entry.is_empty():
		var same := true
		for i: int in 3:
			if entry[0][i] != old[face+i] or entry[1][i] != now[face+i]: same = false;break
		if same:
			preparation.counts.triangle_reuses += 1
			return entry
		preparation.counts.invalidations += 1
	entry = [old.slice(face,face+3),now.slice(face,face+3)]
	preparation.triangles[face] = entry
	preparation.counts.triangle_builds += 1
	return entry

func _confirm(previous: Dictionary, current: Dictionary, lo: float, hi: float, target: Dictionary, preparation: Dictionary) -> Dictionary:
	distance_evaluations = 0
	candidate_faces = 0
	if _budget_frame != Engine.get_physics_frames():
		_budget_frame = Engine.get_physics_frames()
		_frame_distance_evaluations = 0
		_frame_face_prefilters = 0
		_frame_chunk_prefilters = 0
	var cache: RefCounted = _cache.get_ref() if _cache != null else null
	if cache == null or not cache._valid() or not previous.get("valid",false) or not current.get("valid",false) or not target.get("valid",false): return {"valid":false,"reason":"geometry_lifetime"}
	var same_topology: bool = is_same(previous.get("faces"),current.get("faces")) or previous.get("faces") == current.get("faces")
	if previous.get("cache_id") != _signature or current.get("cache_id") != _signature or previous.get("rig_id") != current.get("rig_id") or current.get("rig_id") != cache._rig.get_instance_id() or previous.get("limb") != current.get("limb") or not same_topology: return {"valid":false,"reason":"limb_topology_changed"}
	if current.get("physics_frame") != Engine.get_physics_frames() or previous.get("physics_frame") != current.physics_frame - 1 or target.get("physics_frame") != current.physics_frame: return {"valid":false,"reason":"nonconsecutive_pose_samples"}
	if not previous.get("triangles") is PackedVector3Array or not current.get("triangles") is PackedVector3Array or not target.get("vertices") is PackedVector3Array or not target.get("previous_vertices") is PackedVector3Array: return {"valid":false,"reason":"geometry_shape"}
	var old: PackedVector3Array = previous.triangles
	var now: PackedVector3Array = current.triangles
	if old.size() != now.size() or old.size() % 3 != 0 or old.size() > MAX_FACES_PER_LIMB * 3: return {"valid":false,"reason":"triangle_count"}
	if not is_finite(lo) or not is_finite(hi) or lo < 0.0 or hi > 1.0 or lo > hi or target.vertices.size() != 3 or target.previous_vertices.size() != 3: return {"valid":false,"reason":"clipped_window"}
	if not previous.get("chunk_bounds") is Array or not current.get("chunk_bounds") is Array or previous.chunk_bounds.size() != current.chunk_bounds.size(): return {"valid":false,"reason":"chunk_bounds"}
	var expected_chunks: int = (old.size()/3+FACES_PER_CHUNK-1)/FACES_PER_CHUNK
	if previous.chunk_bounds.size() != expected_chunks: return {"valid":false,"reason":"chunk_count"}
	if not previous.get("face_bounds") is Array or not current.get("face_bounds") is Array or previous.face_bounds.size() != old.size()/3 or current.face_bounds.size() != now.size()/3: return {"valid":false,"reason":"face_bounds"}
	var tree_width := 1
	while tree_width<expected_chunks:tree_width*=2
	if not previous.get("tree_bounds") is Array or not current.get("tree_bounds") is Array or previous.tree_bounds.size()!=tree_width*2-1 or current.tree_bounds.size()!=tree_width*2-1:return {"valid":false,"reason":"tree_bounds"}
	var prepared: bool = _preparation_matches(preparation,previous,current,lo,hi)
	var leaf_base: int = tree_width-1
	var best: Dictionary = {}
	var unresolved := false
	var first_unresolved_reason := ""
	var failing_face := -1
	var failing_chunk := -1
	var target_bounds := _interval_box(target.previous_vertices,target.vertices,lo,hi).grow(CONTACT_M+BOUND_EPS_M)
	var target_endpoints: PackedFloat64Array = _triangle_interval_endpoints(target.previous_vertices,target.vertices,lo,hi)
	var stack: Array[int] = [0]
	while not stack.is_empty():
		var node: int = stack.pop_back()
		var chunk: int = node-leaf_base
		if node>=leaf_base and chunk>=expected_chunks:continue
		if _frame_chunk_prefilters >= MAX_FRAME_CHUNK_PREFILTERS:
			unresolved = true
			if first_unresolved_reason.is_empty():
				first_unresolved_reason = "frame_chunk_budget"
				failing_face = chunk*FACES_PER_CHUNK if node>=leaf_base else -1
				failing_chunk = chunk
			break
		_frame_chunk_prefilters += 1
		var old_bounds: AABB = previous.tree_bounds[node]
		var now_bounds: AABB = current.tree_bounds[node]
		var node_preparation: Array = _prepared_bounds(preparation,true,node,old_bounds,now_bounds,lo,hi) if prepared else [old_bounds,now_bounds,_clipped_bounds(old_bounds,now_bounds,lo,hi).grow(BOUND_EPS_M),_aabb_interval_endpoints(old_bounds,now_bounds,lo,hi)]
		var node_bounds: AABB = node_preparation[2]
		if not node_bounds.intersects(target_bounds): continue
		if _interval_bounds_separated(node_preparation[3],target_endpoints): continue
		if node<leaf_base:
			stack.append(node*2+2);stack.append(node*2+1)
			continue
		for index: int in range(chunk*FACES_PER_CHUNK,mini((chunk+1)*FACES_PER_CHUNK,old.size()/3)):
			if _frame_face_prefilters >= MAX_FRAME_FACE_PREFILTERS:
				unresolved = true
				if first_unresolved_reason.is_empty():
					first_unresolved_reason = "frame_face_budget"
					failing_face = index
					failing_chunk = chunk
				break
			_frame_face_prefilters += 1
			# Cached posed face boxes enclose all linearly interpolated vertices
			# under endpoint union. Reject before slicing/allocating triangle math.
			var old_face: AABB = previous.face_bounds[index]
			var now_face: AABB = current.face_bounds[index]
			var face_preparation: Array = _prepared_bounds(preparation,false,index,old_face,now_face,lo,hi) if prepared else [old_face,now_face,_clipped_bounds(old_face,now_face,lo,hi).grow(BOUND_EPS_M),_aabb_interval_endpoints(old_face,now_face,lo,hi)]
			var face_bounds: AABB = face_preparation[2]
			if not face_bounds.intersects(target_bounds): continue
			if _interval_bounds_separated(face_preparation[3],target_endpoints): continue
			candidate_faces += 1
			var face: int = index*3
			var remaining := mini(MAX_DISTANCE_EVALUATIONS - distance_evaluations,MAX_FRAME_DISTANCE_EVALUATIONS - _frame_distance_evaluations)
			var pair: Array = _prepared_triangles(preparation,face,old,now) if prepared else [old.slice(face,face+3),now.slice(face,face+3)]
			var hit: Dictionary = confirm_linear_triangle(pair[0],pair[1],lo,hi,target.vertices,remaining,target.previous_vertices)
			distance_evaluations += int(hit.get("evaluations",0))
			_frame_distance_evaluations += int(hit.get("evaluations",0))
			if not hit.get("valid",false):
				unresolved = true
				if first_unresolved_reason.is_empty():
					first_unresolved_reason = str(hit.get("reason","unspecified_triangle_failure"))
					if first_unresolved_reason == "distance_budget":
						first_unresolved_reason = "frame_distance_budget" if _frame_distance_evaluations >= MAX_FRAME_DISTANCE_EVALUATIONS else "candidate_distance_budget"
					failing_face = index
					failing_chunk = chunk
				continue
			if hit.get("hit",false):
				best = hit
				best.limb_surface = current.faces[index].surface
				best.limb_face = current.faces[index].face
				best.limb_offset = face
				# One proved contact, followed by final lifetime/barycentric guards.
				break
		if not best.is_empty(): break
		if _frame_face_prefilters >= MAX_FRAME_FACE_PREFILTERS and not stack.is_empty():
			unresolved = true
			if first_unresolved_reason.is_empty():
				first_unresolved_reason = "frame_face_budget"
				failing_face = (chunk+1)*FACES_PER_CHUNK
				failing_chunk = chunk+1
			break
	if not cache._valid(): return {"valid":false,"reason":"geometry_changed"}
	if best.is_empty():
		return {"valid":not unresolved,"hit":false,"reason":"distance_budget_or_unresolved" if unresolved else "separated","first_unresolved_reason":first_unresolved_reason,"evaluations":distance_evaluations,"candidate_faces":candidate_faces,"frame_distance_evaluations":_frame_distance_evaluations,"frame_face_prefilters":_frame_face_prefilters,"frame_chunk_prefilters":_frame_chunk_prefilters,"failing_face":failing_face,"failing_chunk":failing_chunk,"physics_frame":_budget_frame,"limb":str(current.limb)}
	best.surface_index = target.surface_index
	best.face_indices = target.face_indices
	best.barycentric = _barycentric_precise(best.point64,best.impact_target_triangle)
	var impact_limb := PackedVector3Array()
	var from_limb := PackedVector3Array()
	for i: int in 3:
		impact_limb.append(old[best.limb_offset+i].lerp(now[best.limb_offset+i],float(best.alpha)))
		from_limb.append(old[best.limb_offset+i].lerp(now[best.limb_offset+i],lo))
	var limb_weights := _barycentric_precise(best.line_point64,impact_limb)
	if not _valid_weights(best.barycentric) or not _valid_weights(limb_weights): return {"valid":false,"reason":"contact_barycentric"}
	best.limb_barycentric = limb_weights
	best.erase("point64")
	best.erase("line_point64")
	best.limb_path_from = from_limb[0]*limb_weights.x+from_limb[1]*limb_weights.y+from_limb[2]*limb_weights.z
	best.limb_path_to = best.line_point
	best.weights = best.barycentric
	best.normal = (best.impact_target_triangle[1]-best.impact_target_triangle[0]).cross(best.impact_target_triangle[2]-best.impact_target_triangle[0]).normalized()
	best.score = best.alpha
	best.proof = "posed_original_limb_triangle_within_2mm_of_original_target_triangle"
	best.evaluations = distance_evaluations
	return best

static func _box(points: PackedVector3Array) -> AABB:
	var low: Vector3 = points[0]
	var high := low
	for point: Vector3 in points: low = low.min(point); high = high.max(point)
	return AABB(low,high-low)

static func _barycentric(p: Vector3, triangle: PackedVector3Array) -> Vector3:
	return _barycentric_precise(Triangle._p(p),triangle)

static func _barycentric_precise(p: PackedFloat64Array, triangle: PackedVector3Array) -> Vector3:
	var v0 := Triangle._s(Triangle._p(triangle[1]),Triangle._p(triangle[0]))
	var v1 := Triangle._s(Triangle._p(triangle[2]),Triangle._p(triangle[0]))
	var v2 := Triangle._s(p,Triangle._p(triangle[0]))
	var d00: float = Triangle._d(v0,v0)
	var d11: float = Triangle._d(v1,v1)
	var d01: float = Triangle._d(v0,v1)
	var d20: float = Triangle._d(v2,v0)
	var d21: float = Triangle._d(v2,v1)
	var den := d00*d11-d01*d01
	if absf(den) < 1e-14: return Vector3(INF,INF,INF)
	var v := (d11*d20-d01*d21)/den
	var w := (d00*d21-d01*d20)/den
	return Vector3(1.0-v-w,v,w)

static func _valid_weights(value: Vector3) -> bool:
	return value.is_finite() and minf(value.x,minf(value.y,value.z)) >= -.0001 and maxf(value.x,maxf(value.y,value.z)) <= 1.0001 and absf(value.x+value.y+value.z-1.0) <= .0001

static func _distance(a: PackedVector3Array, b: PackedVector3Array) -> Dictionary:
	# Six exact segment/triangle distances cover vertex-face, edge-edge and
	# piercing contacts in both directions, including coplanar containment.
	if (a[1]-a[0]).cross(a[2]-a[0]).length_squared() < 1e-14 or (b[1]-b[0]).cross(b[2]-b[0]).length_squared() < 1e-14: return {"valid":false,"reason":"degenerate_geometry"}
	var aa: Array[PackedFloat64Array] = [Triangle._p(a[0]),Triangle._p(a[1]),Triangle._p(a[2])]
	var bb: Array[PackedFloat64Array] = [Triangle._p(b[0]),Triangle._p(b[1]),Triangle._p(b[2])]
	var best: Dictionary = {}
	for side: int in 2:
		var edge: Array[PackedFloat64Array] = aa if side == 0 else bb
		var face: Array[PackedFloat64Array] = bb if side == 0 else aa
		for i: int in 3:
			var hit: Dictionary = Triangle._sample(edge[i],edge[(i+1)%3],1e8,face[0],face[1],face[2])
			if not hit.get("valid",false): return {"valid":false,"reason":"distance_arithmetic"}
			if not hit.get("hit",false): continue
			if best.is_empty() or hit.distance_squared < best.distance_squared:
				best = {"valid":true,"distance_squared":hit.distance_squared,"point":hit.point if side == 0 else hit.line_point,"line_point":hit.line_point if side == 0 else hit.point,"point64":hit.point64 if side == 0 else hit.line_point64,"line_point64":hit.line_point64 if side == 0 else hit.point64}
			if best.distance_squared <= CONTACT_M*CONTACT_M:
				# An actual pair inside tolerance proves contact; the globally
				# closest pair is unnecessary. Preserve its unrounded witnesses.
				best.segment_tests = side*3+i+1
				return best
	if not best.is_empty(): best.segment_tests = 6
	return {"valid":false,"reason":"degenerate_geometry"} if best.is_empty() else best

static func _interval_box(first: PackedVector3Array, last: PackedVector3Array, lo: float, hi: float) -> AABB:
	var low := first[0].lerp(last[0],lo)
	var high := low
	for i: int in 3:
		var a := first[i].lerp(last[i],lo)
		var b := first[i].lerp(last[i],hi)
		low = low.min(a).min(b)
		high = high.max(a).max(b)
	return AABB(low,high-low)

static func _interval_axis_separated(a0: PackedVector3Array, a1: PackedVector3Array, b0: PackedVector3Array, b1: PackedVector3Array, lo: float, hi: float, axis: Vector3) -> bool:
	# Use the SAME time at both triangles. If every B-A vertex-pair projection
	# exceeds clearance at lo AND hi in the same direction, its linear value
	# exceeds clearance throughout. Mixing extrema from different times loses
	# this proof under common translation and creates expensive false overlap.
	# Scalar double projection avoids Vector3.dot's real_t precision loss.
	var length_squared: float = float(axis.x)*axis.x + float(axis.y)*axis.y + float(axis.z)*axis.z
	if not axis.is_finite() or length_squared < 1e-20: return false
	var low_a_lo := INF
	var high_a_lo := -INF
	var low_b_lo := INF
	var high_b_lo := -INF
	var low_a_hi := INF
	var high_a_hi := -INF
	var low_b_hi := INF
	var high_b_hi := -INF
	var reference := a0[0]
	for i: int in 3:
		var pa0: float = (float(a0[i].x)-reference.x)*axis.x + (float(a0[i].y)-reference.y)*axis.y + (float(a0[i].z)-reference.z)*axis.z
		var pa1: float = (float(a1[i].x)-reference.x)*axis.x + (float(a1[i].y)-reference.y)*axis.y + (float(a1[i].z)-reference.z)*axis.z
		var pb0: float = (float(b0[i].x)-reference.x)*axis.x + (float(b0[i].y)-reference.y)*axis.y + (float(b0[i].z)-reference.z)*axis.z
		var pb1: float = (float(b1[i].x)-reference.x)*axis.x + (float(b1[i].y)-reference.y)*axis.y + (float(b1[i].z)-reference.z)*axis.z
		var alo := lerpf(pa0,pa1,lo)
		var ahi := lerpf(pa0,pa1,hi)
		var blo := lerpf(pb0,pb1,lo)
		var bhi := lerpf(pb0,pb1,hi)
		low_a_lo = minf(low_a_lo,alo); high_a_lo = maxf(high_a_lo,alo)
		low_b_lo = minf(low_b_lo,blo); high_b_lo = maxf(high_b_lo,blo)
		low_a_hi = minf(low_a_hi,ahi); high_a_hi = maxf(high_a_hi,ahi)
		low_b_hi = minf(low_b_hi,bhi); high_b_hi = maxf(high_b_hi,bhi)
	var clearance: float = (CONTACT_M + BOUND_EPS_M) * sqrt(length_squared)
	return (low_a_lo-high_b_lo > clearance and low_a_hi-high_b_hi > clearance) or (low_b_lo-high_a_lo > clearance and low_b_hi-high_a_hi > clearance)

static func _interval_edge_axes_separated(a0: PackedVector3Array, a1: PackedVector3Array, b0: PackedVector3Array, b1: PackedVector3Array, lo: float, hi: float, a: PackedVector3Array, b: PackedVector3Array, normal_a: Vector3, normal_b: Vector3) -> bool:
	# At most15 additional candidate directions; this is not an approximate
	# contact test. Only the double endpoint proof above may reject an interval.
	# Plane normals alone cannot separate coplanar side-by-side triangles with
	# overlapping AABBs. In-plane edge normals cover that important near miss.
	for i: int in 3:
		if _interval_axis_separated(a0,a1,b0,b1,lo,hi,normal_b.cross(b[(i+1)%3]-b[i])): return true
		if _interval_axis_separated(a0,a1,b0,b1,lo,hi,normal_a.cross(a[(i+1)%3]-a[i])): return true
	# Skew edges can separate although neither face-normal direction does.
	# Midpoint edges merely propose a fixed direction: rotating/moving endpoints
	# must still pass the whole-interval proof, so tunnelling stays observable.
	for i: int in 3:
		var edge_a: Vector3 = a[(i+1)%3]-a[i]
		for j: int in 3:
			if _interval_axis_separated(a0,a1,b0,b1,lo,hi,edge_a.cross(b[(j+1)%3]-b[j])): return true
	return false

static func confirm_linear_triangle(previous: PackedVector3Array, current: PackedVector3Array, lo: float, hi: float, target: PackedVector3Array, budget: int = MAX_DISTANCE_EVALUATIONS, previous_target: PackedVector3Array = PackedVector3Array()) -> Dictionary:
	if previous.size() != 3 or current.size() != 3 or target.size() != 3 or not is_finite(lo) or not is_finite(hi) or lo < 0.0 or hi > 1.0 or lo > hi: return {"valid":false,"reason":"shape_or_window"}
	var target_before: PackedVector3Array = target if previous_target.is_empty() else previous_target
	if target_before.size() != 3: return {"valid":false,"reason":"previous_target"}
	var span := PackedVector3Array()
	var target_span := PackedVector3Array()
	var speed := 0.0
	var target_speed := 0.0
	for i: int in 3:
		if not previous[i].is_finite() or not current[i].is_finite() or not target[i].is_finite() or not target_before[i].is_finite(): return {"valid":false,"reason":"nonfinite"}
		speed = maxf(speed,previous[i].distance_to(current[i]))
		target_speed = maxf(target_speed,target_before[i].distance_to(target[i]))
		span.append(previous[i].lerp(current[i],lo))
		span.append(previous[i].lerp(current[i],hi))
		target_span.append(target_before[i].lerp(target[i],lo))
		target_span.append(target_before[i].lerp(target[i],hi))
	if maxf(speed,target_speed) > MAX_VERTEX_TRAVEL_M: return {"valid":false,"reason":"unobserved_large_motion"}
	if not _box(span).grow(CONTACT_M+BOUND_EPS_M).intersects(_box(target_span).grow(BOUND_EPS_M)): return {"valid":true,"hit":false,"evaluations":0}
	# For arbitrary barycentric points the relative velocity is a convex
	# combination of nine vertex-pair relative velocities. Their maximum norm
	# is a valid distance Lipschitz bound and cancels common translation.
	speed = 0.0
	for i: int in 3:
		for j: int in 3:
			var dx: float = (float(current[i].x)-previous[i].x) - (float(target[j].x)-target_before[j].x)
			var dy: float = (float(current[i].y)-previous[i].y) - (float(target[j].y)-target_before[j].y)
			var dz: float = (float(current[i].z)-previous[i].z) - (float(target[j].z)-target_before[j].z)
			speed = maxf(speed,sqrt(dx*dx+dy*dy+dz*dz))
	if budget <= 0: return {"valid":false,"reason":"distance_budget","evaluations":0}
	var stack: Array[Vector3] = [Vector3(lo,hi,0.0)]
	var evaluations := 0
	while not stack.is_empty():
		var interval: Vector3 = stack.pop_back()
		# Subinterval bounds often separate even when full-frame swept boxes do
		# not. This is separation proof only and consumes no distance evaluation.
		if interval.z > 0.0 and not _interval_box(previous,current,interval.x,interval.y).grow(CONTACT_M+BOUND_EPS_M).intersects(_interval_box(target_before,target,interval.x,interval.y).grow(BOUND_EPS_M)): continue
		var mid := (float(interval.x)+float(interval.y))*.5
		var posed := PackedVector3Array([previous[0].lerp(current[0],mid),previous[1].lerp(current[1],mid),previous[2].lerp(current[2],mid)])
		var target_posed := PackedVector3Array([target_before[0].lerp(target[0],mid),target_before[1].lerp(target[1],mid),target_before[2].lerp(target[2],mid)])
		# A midpoint normal is only a candidate FIXED axis. All endpoint
		# projections must prove separation over this whole interval, so moving
		# or rotating triangles cannot be falsely culled by a single pose plane.
		var target_axis := (target_posed[1]-target_posed[0]).cross(target_posed[2]-target_posed[0])
		if _interval_axis_separated(previous,current,target_before,target,interval.x,interval.y,target_axis): continue
		var limb_axis := (posed[1]-posed[0]).cross(posed[2]-posed[0])
		if _interval_axis_separated(previous,current,target_before,target,interval.x,interval.y,limb_axis): continue
		if _interval_edge_axes_separated(previous,current,target_before,target,interval.x,interval.y,posed,target_posed,limb_axis,target_axis): continue
		if evaluations >= budget: return {"valid":false,"reason":"distance_budget","evaluations":evaluations}
		var distance := _distance(posed,target_posed)
		evaluations += 1
		if not distance.get("valid",false): return {"valid":false,"reason":distance.get("reason","distance"),"evaluations":evaluations}
		if distance.distance_squared <= CONTACT_M*CONTACT_M:
			distance.hit = true
			distance.alpha = mid
			distance.evaluations = evaluations
			distance.impact_target_triangle = target_posed
			return distance
		# Fast fixed-plane separation especially rejects tangential motion past
		# a nearby slanted surface without dozens of recursive exact distances.
		if _interval_axis_separated(previous,current,target_before,target,interval.x,interval.y,distance.line_point-distance.point): continue
		# Both linear triangles are evaluated at the SAME fraction.
		if sqrt(float(distance.distance_squared)) > CONTACT_M + speed * (float(interval.y)-float(interval.x))*.5 + BOUND_EPS_M: continue
		if interval.z >= MAX_DEPTH: return {"valid":false,"reason":"unresolved_at_depth","evaluations":evaluations}
		stack.append(Vector3(mid,interval.y,interval.z+1.0))
		stack.append(Vector3(interval.x,mid,interval.z+1.0))
	return {"valid":true,"hit":false,"evaluations":evaluations}
