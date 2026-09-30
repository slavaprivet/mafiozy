extends RefCounted
## Cosmetic original-surface anchors. Admission belongs to npc_hit_marks_adapter.
## No HP, source RNG, body, Skin, animation, or collider writes.
const MAX_MARKS := 24
const MAX_RECEIPTS := 512
const COLORS := [Color("1d1215"), Color("4f3c3a"), Color("40151d"), Color("5d1a24"), Color("49303b")]
var _root: Node3D
var _rig: Skeleton3D
var _unit := 1.0
var _surfaces: Array[Dictionary] = []
var _marks: Array[Dictionary] = []
var _receipts: Array[String] = []
var _mesh_node: MeshInstance3D
var _mesh: ArrayMesh
var _material: ShaderMaterial
var _anchors: Array[Dictionary] = []
var _unique_anchors: Array[Dictionary] = []
var _anchor_indices := PackedInt32Array()
var _sample_surfaces := PackedInt32Array()
var _sample_vertices := PackedInt32Array()
var _sample_triangles: Array[Vector3i] = []
var _anchor_triangles := PackedInt32Array()
var _anchor_weights := PackedVector3Array()
var _anchor_offsets := PackedFloat32Array()
var _used_bones := PackedInt32Array()
var _influence_start := PackedInt32Array()
var _influence_bones := PackedInt32Array()
var _influence_points := PackedVector3Array()
var _influence_weights := PackedFloat32Array()
var _pose_key: Array = []
var _seed := 0
var last_cost: Dictionary = {}
var prepare_us:=0
var prepare_memory_delta_bytes:=0
var _query_cache: Dictionary = {}
var _query_bones: Array[Transform3D] = []

func configure(actor: Node3D, rig: Skeleton3D, unit: float) -> bool:
	if _root != null or not is_instance_valid(actor) or not is_instance_valid(rig) or not actor.is_ancestor_of(rig) or not is_finite(unit) or unit <= 0: return false
	var prepare_start:=Time.get_ticks_usec()
	var prepare_memory:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	_root = actor; _rig = rig; _unit = unit
	for node: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if not node.mesh is ArrayMesh or node.get_meta("npc_bullet_mark", false): continue
		var bindings: Array[int] = []
		if node.skin != null:
			for bind in node.skin.get_bind_count():
				var name: String = str(node.skin.get_bind_name(bind))
				var bone: int = rig.find_bone(name) if not name.is_empty() else node.skin.get_bind_bone(bind)
				if bone < 0 or bone >= rig.get_bone_count(): dispose(); return false
				bindings.append(bone)
		for s in node.mesh.get_surface_count():
			if node.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES: continue
			var a: Array = node.mesh.surface_get_arrays(s)
			if a[Mesh.ARRAY_VERTEX] == null: continue
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i in vertices.size(): indices.append(i)
			if indices.size() % 3 != 0: dispose(); return false
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES] if a[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS] if a[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			if node.skin != null and (bones.size() != vertices.size() * 4 or weights.size() != bones.size()): dispose(); return false
			var material: Material = node.get_active_material(s)
			var entry:Dictionary={"node":weakref(node), "original":node.mesh, "skin":node.skin, "surface":s, "vertices":vertices, "indices":indices, "bones":bones, "weights":weights, "bindings":bindings, "skin_material":material != null and "SKIN" in material.resource_name.to_upper()}
			entry.clusters=_clusters(entry)
			_surfaces.append(entry)
	if _surfaces.is_empty(): dispose(); return false
	_mesh_node = MeshInstance3D.new(); _mesh_node.name = "PersistentNpcBulletMarks"
	_mesh_node.set_meta("npc_bullet_mark", true)
	_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_mesh_node)
	# One batched draw per actor. Fragment normals follow the actual moving wound
	# triangles; positions alone are streamed. No full ArrayMesh rebuild per frame.
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled, depth_draw_never; void fragment(){vec3 n=normalize(cross(dFdx(VERTEX),dFdy(VERTEX))); NORMAL=faceforward(n,VERTEX,n); ALBEDO=COLOR.rgb; ROUGHNESS=1.0;}"
	_material = ShaderMaterial.new(); _material.shader = shader
	# Prepare the exact indexed/color/dynamic material pipeline before any hit.
	# Degenerate geometry covers no pixels, does not admit a wound or HP receipt.
	# Keep a finite bound so render-list preparation can see the surface.
	_mesh = ArrayMesh.new()
	var warm_arrays: Array = []; warm_arrays.resize(Mesh.ARRAY_MAX)
	warm_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
	warm_arrays[Mesh.ARRAY_COLOR] = PackedColorArray([COLORS[0].srgb_to_linear(),COLORS[0].srgb_to_linear(),COLORS[0].srgb_to_linear()])
	warm_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2])
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,warm_arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	_mesh.surface_set_material(0,_material)
	_mesh.custom_aabb = AABB(Vector3(-.05,0,-.05),Vector3(.1,.1,.1))
	_mesh_node.mesh = _mesh
	prepare_us=Time.get_ticks_usec()-prepare_start
	prepare_memory_delta_bytes=int(Performance.get_monitor(Performance.MEMORY_STATIC))-prepare_memory
	return true

func _clusters(s:Dictionary)->Array[Dictionary]:
	# Conservative bound per dominant-bone triangle group. Every contributing
	# bone keeps its own original-point AABB, so blends remain inside their union.
	var groups:Dictionary={};var ids:PackedInt32Array=s.indices
	var cell_size:=.45/_unit
	for i in range(0,ids.size(),3):
		var scores:Dictionary={};var dominant:=-1;var best:=-1.0
		if s.skin!=null:
			for index:int in [ids[i],ids[i+1],ids[i+2]]:
				for j in 4:
					var k:=index*4+j;var weight:float=s.weights[k];var bone:int=s.bones[k]
					if weight>0:scores[bone]=float(scores.get(bone,0.0))+weight
			for bone:int in scores:
				if scores[bone]>best:best=scores[bone];dominant=bone
		var centroid:Vector3=(s.vertices[ids[i]]+s.vertices[ids[i+1]]+s.vertices[ids[i+2]])/3.0
		var cell:=Vector3i(floori(centroid.x/cell_size),floori(centroid.y/cell_size),floori(centroid.z/cell_size))
		var group_key:=str(dominant)+":"+str(cell)
		if not groups.has(group_key):groups[group_key]={"indices":PackedInt32Array(),"bounds":{},"seen":{}}
		var group:Dictionary=groups[group_key]
		for index:int in [ids[i],ids[i+1],ids[i+2]]:
			group.indices.append(index)
			if group.seen.has(index):continue
			group.seen[index]=true
			var p:Vector3=s.vertices[index]
			if s.skin==null:
				group.bounds[-1]=group.bounds[-1].expand(p) if group.bounds.has(-1) else AABB(p,Vector3.ZERO)
			else:
				for j in 4:
					var k:=index*4+j;var bone:int=s.bones[k]
					if s.weights[k]<=0:continue
					group.bounds[bone]=group.bounds[bone].expand(p) if group.bounds.has(bone) else AABB(p,Vector3.ZERO)
	var result:Array[Dictionary]=[]
	for group:Dictionary in groups.values():result.append(group)
	return result

func _adopt_vertices(s:Dictionary,vertices:PackedVector3Array)->void:
	# Same topology + bind arrays: keep cluster membership and only expand old
	# conservative bounds for changed source vertices (closed eyes alter550).
	for i in vertices.size():
		if vertices[i]==s.vertices[i]:continue
		for group:Dictionary in s.clusters:
			if not group.seen.has(i):continue
			if s.skin==null:group.bounds[-1]=group.bounds[-1].expand(vertices[i])
			else:
				for j in 4:
					var k:=i*4+j
					if s.weights[k]>0:group.bounds[s.bones[k]]=group.bounds[s.bones[k]].expand(vertices[i])
	s.vertices=vertices

func _valid() -> bool:
	if not is_instance_valid(_root) or not is_instance_valid(_rig) or not is_instance_valid(_mesh_node) or _root.is_queued_for_deletion(): return false
	var changed:=false
	for s: Dictionary in _surfaces:
		var node: MeshInstance3D = s.node.get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not _root.is_ancestor_of(node) or node.skin != s.skin: return false
		if node.mesh != s.original:
			# Final-death eyelids replace two meshes with topology-identical original
			# variants. Follow their actual vertices, but reject any remapped surface.
			if not node.mesh is ArrayMesh or node.mesh.get_surface_count()!=s.original.get_surface_count(): return false
			var arrays: Array = node.mesh.surface_get_arrays(s.surface)
			if arrays[Mesh.ARRAY_VERTEX].size()!=s.vertices.size() or arrays[Mesh.ARRAY_INDEX]!=s.indices: return false
			if s.skin!=null and (arrays[Mesh.ARRAY_BONES]!=s.bones or arrays[Mesh.ARRAY_WEIGHTS]!=s.weights): return false
			s.original=node.mesh; _adopt_vertices(s,arrays[Mesh.ARRAY_VERTEX])
			_pose_key.clear()
			changed=true
	if changed:_bind_samples()
	return true

func _bone_poses(required:PackedInt32Array=PackedInt32Array())->Array[Transform3D]:
	var out:Array[Transform3D]=[]
	var rig_world:=_rig.global_transform
	for bone in _rig.get_bone_count():out.append(Transform3D.IDENTITY)
	if required.is_empty():
		for bone in _rig.get_bone_count():out[bone]=rig_world*_rig.get_bone_global_pose(bone)
	else:
		for bone:int in required:out[bone]=rig_world*_rig.get_bone_global_pose(bone)
	return out

func _matrices(s: Dictionary, poses:Array[Transform3D]=[]) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if s.skin == null: return out
	if poses.is_empty():poses=_bone_poses()
	for b in s.bindings.size(): out.append(poses[s.bindings[b]] * s.skin.get_bind_pose(b))
	return out

func _vertex(s: Dictionary, index: int, matrices: Array[Transform3D]) -> Vector3:
	var p: Vector3 = s.vertices[index]
	if s.skin == null: return s.node.get_ref().global_transform * p
	var result := Vector3.ZERO
	for j in 4:
		var k := index * 4 + j
		var w: float = s.weights[k]
		if w > 0: result += matrices[s.bones[k]] * p * w
	return result

func _query(point: Vector3, normal: Vector3, coarse_depth:float=0.0) -> Dictionary:
	var result: Array[Dictionary] = []
	var u := (Vector3.UP if absf(normal.y)<.9 else Vector3.RIGHT).cross(normal).normalized()
	var v := normal.cross(u)
	# Largest source fray probe is .105*1.20*1.24=.15624 units; bruises
	# reach .075*1.20*1.45=.1305. Accepted axial depth is exactly .20.
	var extent := (u.abs()*.16+v.abs()*.16+normal.abs()*.20)*_unit+Vector3.ONE*.00001
	var box := AABB(point - extent, extent * 2.0)
	for sid in _surfaces.size():
		var s: Dictionary = _surfaces[sid]
		var matrices := _matrices(s,_query_bones)
		if not _query_cache.has(sid):_query_cache[sid]={}
		var posed:Dictionary=_query_cache[sid]
		var ids:=PackedInt32Array()
		for group:Dictionary in s.clusters:
			var bounds:=AABB();var first:=true
			for bind:int in group.bounds:
				var transform:Transform3D=s.node.get_ref().global_transform if bind<0 else matrices[bind]
				var b:AABB=transform*group.bounds[bind]
				bounds=b if first else bounds.merge(b);first=false
			bounds=bounds.grow(.00001)
			if coarse_depth>0:
				if bounds.intersects_segment(point,point-normal*coarse_depth)==null:continue
			elif not box.intersects(bounds):continue
			ids.append_array(group.indices)
		for index:int in ids:
			if not posed.has(index):posed[index]=_vertex(s,index,matrices)
		for i in range(0, ids.size(), 3):
			var a:Vector3=posed[ids[i]]; var b:Vector3=posed[ids[i+1]]; var c:Vector3=posed[ids[i+2]]
			var lo := a.min(b).min(c); var hi := a.max(b).max(c)
			if coarse_depth>0 and AABB(lo-Vector3.ONE*.00001,(hi-lo)+Vector3.ONE*.00002).intersects_segment(point,point-normal*coarse_depth)==null: continue
			if coarse_depth<=0 and not box.intersects(AABB(lo, (hi-lo)+Vector3.ONE*.000001)): continue
			var pa := Vector3(u.dot(a-point),v.dot(a-point),normal.dot(a-point))
			var pb := Vector3(u.dot(b-point),v.dot(b-point),normal.dot(b-point))
			var pc := Vector3(u.dot(c-point),v.dot(c-point),normal.dot(c-point))
			var e1 := pb-pa; var e2 := pc-pa
			var determinant := e1.x*e2.y-e1.y*e2.x
			var minx:=minf(pa.x,minf(pb.x,pc.x));var maxx:=maxf(pa.x,maxf(pb.x,pc.x))
			var miny:=minf(pa.y,minf(pb.y,pc.y));var maxy:=maxf(pa.y,maxf(pb.y,pc.y))
			var lateral:=0.0 if coarse_depth>0 else .16*_unit
			if minx>lateral or maxx < -lateral or miny>lateral or maxy < -lateral:continue
			var near_z:=.001 if coarse_depth>0 else .20*_unit
			var far_z:=-coarse_depth if coarse_depth>0 else -.20*_unit
			if absf(determinant)<1e-12 or minf(pa.z,minf(pb.z,pc.z))>=near_z or maxf(pa.z,maxf(pb.z,pc.z))<=far_z: continue
			# Parallel source probes share this inverse ray/triangle projection.
			# Compute it once rather than repeating 3D cross products for every rim.
			result.append({"s":sid, "ids":Vector3i(ids[i],ids[i+1],ids[i+2]), "a":pa, "e1z":e1.z, "e2z":e2.z,
				"ux":e2.y/determinant,"uy":-e2.x/determinant,"vx":-e1.y/determinant,"vy":e1.x/determinant,
				"minx":minx,"maxx":maxx,"miny":miny,"maxy":maxy,"sign":-1.0 if determinant<0 else 1.0,"normal":(b-a).cross(c-a).normalized()})
	return {"triangles":result,"point":point,"u":u,"v":v,"normal":normal,"depth":coarse_depth}

func _probe(query: Dictionary, point: Vector3, _normal: Vector3) -> Dictionary:
	var delta: Vector3=point-query.point
	var x: float=query.u.dot(delta); var y: float=query.v.dot(delta)
	var nearest := -INF; var anchor: Dictionary = {}
	for t: Dictionary in query.triangles:
		if x<t.minx or x>t.maxx or y<t.miny or y>t.maxy: continue
		var dx: float=x-t.a.x; var dy: float=y-t.a.y
		var u: float=dx*t.ux+dy*t.uy; var v: float=dx*t.vx+dy*t.vy
		if u<0 or v<0 or u+v>1: continue
		var z: float=t.a.z+u*t.e1z+v*t.e2z
		if z<=nearest:continue
		if query.depth>0:
			if z>.001 or z < -float(query.depth):continue
		elif absf(z)>=.20*_unit:continue
		nearest=z
		anchor={"s":t.s,"ids":t.ids,"weights":Vector3(1-u-v,u,v),"sign":t.sign,"world_point":query.point+query.u*x+query.v*y+query.normal*z,"world_normal":t.normal*t.sign}
	return anchor

func _random() -> float:
	_seed = (_seed * 1664525 + 1013904223) & 0xffffffff
	return float(_seed)/4294967296.0

func _shape(event_id: String, clothing: bool) -> Array[Dictionary]:
	_seed = 2166136261
	for character in event_id:
		_seed = ((_seed ^ character.unicode_at(0)) * 16777619) & 0xffffffff
	var edge: Array[Vector2] = []; var radius := (.105 if clothing else .075)*_unit
	for i in 11:
		var a := float(i)/11.0*TAU
		edge.append(Vector2(cos(a)*radius*(.65+_random()*.55),sin(a)*radius*(.65+_random()*.55)))
	var triangles: Array[Dictionary] = []
	for i in 11:
		var p := edge[i]; var q := edge[(i+1)%11]
		triangles.append({"points":[Vector2.ZERO,p,q],"material":0 if clothing else 2,"offset":.010*_unit})
		if clothing:
			triangles.append({"points":[p,p*1.24,q],"material":1,"offset":.012*_unit})
			if i%2 == 0: triangles.append({"points":[p*1.24,q*1.10,q],"material":1,"offset":.012*_unit})
		elif i%3 != 0:
			# Explicit user-requested bruise presentation, not an extra HP event.
			# Broken outer fragments share actual skin anchors; no face decal plane.
			triangles.append({"points":[p,p*1.45,q],"material":4,"offset":.008*_unit})
	# One contiguous, off-centre seven-sided blood pool, not alternating radial
	# wedges. Same seven triangles and original maximum footprint/caps.
	var blood_center:=Vector2(.08,-.10)*radius
	var blood_edge:Array[Vector2]=[]
	for i in 7:
		var angle:=float(i)/7.0*TAU
		blood_edge.append(blood_center+Vector2(cos(angle),sin(angle))*radius*(.38+_random()*.16))
	for i in 7:
		triangles.append({"points":[blood_center,blood_edge[i],blood_edge[(i+1)%7]],"material":3,"offset":.014*_unit})
	return triangles

func accept(event_id: String, point: Vector3, normal: Vector3, incoming:Vector3=Vector3.ZERO, ray_depth:float=0.0) -> bool:
	if not _valid() or event_id.is_empty() or event_id in _receipts or not point.is_finite() or not normal.is_finite() or normal.length_squared()<.5: return false
	var start := Time.get_ticks_usec(); var n := normal.normalized()
	var coarse_us:=0
	_query_cache.clear()
	_query_bones=_bone_poses()
	if ray_depth>0:
		if not incoming.is_finite() or incoming.length_squared()<.5:return false
		var visual_query:=_query(point,-incoming.normalized(),ray_depth)
		var visual:=_probe(visual_query,point,-incoming.normalized())
		if visual.is_empty():_query_cache.clear();return false
		point=visual.world_point;n=visual.world_normal
		coarse_us=Time.get_ticks_usec()-start
	var query_start:=Time.get_ticks_usec()
	var query := _query(point,n); var center := _probe(query,point,n)
	var query_us:=Time.get_ticks_usec()-query_start
	_query_cache.clear()
	if center.is_empty(): return false
	var clothing: bool = not _surfaces[center.s].skin_material
	var u := (Vector3.UP if absf(n.y)<.9 else Vector3.RIGHT).cross(n).normalized(); var v := n.cross(u)
	var cache: Dictionary = {Vector2.ZERO:center}; var triangles: Array[Dictionary] = []
	var probes_start:=Time.get_ticks_usec()
	for template: Dictionary in _shape(event_id,clothing):
		var anchors: Array[Dictionary] = []; var good := true
		for xy: Vector2 in template.points:
			if not cache.has(xy): cache[xy] = _probe(query,point+u*xy.x+v*xy.y,n)
			if cache[xy].is_empty(): good = false; break
			var a: Dictionary = cache[xy].duplicate(); a.offset = template.offset; a.probe=xy; anchors.append(a)
		if good: triangles.append({"anchors":anchors,"color":COLORS[template.material].srgb_to_linear()})
	if triangles.is_empty() or not _valid(): return false
	var probes_us:=Time.get_ticks_usec()-probes_start
	_marks.append({"id":event_id,"triangles":triangles,"clothing":clothing})
	_receipts.append(event_id)
	if _marks.size()>MAX_MARKS: _marks.pop_front()
	if _receipts.size()>MAX_RECEIPTS: _receipts.pop_front()
	var rebuild_start:=Time.get_ticks_usec();_rebuild()
	last_cost = {"accept_us":Time.get_ticks_usec()-start,"coarse_us":coarse_us,"query_us":query_us,"probes_us":probes_us,"rebuild_us":Time.get_ticks_usec()-rebuild_start,"candidate_triangles":query.triangles.size(),"probes":cache.size(),"marks":_marks.size(),"vertices":_anchors.size(),"update_us":last_cost.get("update_us",0)}
	return true

func _build_sample_tables()->void:
	_sample_surfaces.clear();_sample_vertices.clear();_sample_triangles.clear()
	_anchor_triangles.clear();_anchor_weights.clear();_anchor_offsets.clear()
	_used_bones.clear()
	var sample_map:Dictionary={};var triangle_map:Dictionary={}
	for a:Dictionary in _unique_anchors:
		var triangle:=Vector3i()
		for corner in 3:
			var key:=Vector2i(a.s,a.ids[corner])
			if not sample_map.has(key):
				sample_map[key]=_sample_vertices.size();_sample_surfaces.append(key.x);_sample_vertices.append(key.y)
			triangle[corner]=sample_map[key]
		if not triangle_map.has(triangle):triangle_map[triangle]=_sample_triangles.size();_sample_triangles.append(triangle)
		_anchor_triangles.append(triangle_map[triangle]);_anchor_weights.append(a.weights);_anchor_offsets.append(float(a.offset)*float(a.sign))
	_bind_samples()

func _bind_samples()->void:
	_used_bones.clear();_influence_start.clear();_influence_bones.clear();_influence_points.clear();_influence_weights.clear()
	var used:Dictionary={}
	for i in _sample_vertices.size():
		_influence_start.append(_influence_bones.size())
		var s:Dictionary=_surfaces[_sample_surfaces[i]]
		if s.skin==null:continue
		var index:=_sample_vertices[i]
		for j in 4:
			var k:=index*4+j;var weight:float=s.weights[k]
			if weight<=0:continue
			var bone:int=s.bindings[s.bones[k]]
			used[bone]=true;_influence_bones.append(bone)
			_influence_points.append(s.skin.get_bind_pose(s.bones[k])*s.vertices[index])
			_influence_weights.append(weight)
	_influence_start.append(_influence_bones.size())
	for bone:int in used:_used_bones.append(bone)

func _positions(poses:Array[Transform3D]=[]) -> PackedVector3Array:
	# Table construction is receipt-time only. Animated updates traverse flat
	# samples/triangles/weights; no per-anchor dictionaries or small Array creation.
	if poses.is_empty():poses=_bone_poses(_used_bones)
	var posed:=PackedVector3Array();posed.resize(_sample_vertices.size())
	var local_points:=PackedVector3Array();local_points.resize(_sample_vertices.size())
	var inverse:=_mesh_node.global_transform.affine_inverse()
	for i in _sample_vertices.size():
		var p:=Vector3.ZERO
		var begin:=_influence_start[i];var end:=_influence_start[i+1]
		if begin==end:
			var s:Dictionary=_surfaces[_sample_surfaces[i]]
			p=s.node.get_ref().global_transform*s.vertices[_sample_vertices[i]]
		else:
			for j in range(begin,end):p+=poses[_influence_bones[j]]*_influence_points[j]*_influence_weights[j]
		posed[i]=p
		local_points[i]=inverse*posed[i]
	var normals:=PackedVector3Array();normals.resize(_sample_triangles.size())
	for i in _sample_triangles.size():
		var t:=_sample_triangles[i]
		normals[i]=inverse.basis*(posed[t.y]-posed[t.x]).cross(posed[t.z]-posed[t.x]).normalized()
	var unique:=PackedVector3Array();unique.resize(_anchor_triangles.size())
	for i in _anchor_triangles.size():
		var ti:=_anchor_triangles[i];var t:=_sample_triangles[ti];var w:=_anchor_weights[i]
		unique[i]=local_points[t.x]*w.x+local_points[t.y]*w.y+local_points[t.z]*w.z+normals[ti]*_anchor_offsets[i]
	return unique

func _rebuild() -> void:
	_anchors.clear();_unique_anchors.clear();_anchor_indices.clear(); var colors := PackedColorArray()
	for mark: Dictionary in _marks:
		var seen:Dictionary={}
		for triangle: Dictionary in mark.triangles:
			for a: Dictionary in triangle.anchors:
				var key:=Vector3(a.probe.x,a.probe.y,a.offset)
				if not seen.has(key):seen[key]={}
				var color_keys:Dictionary=seen[key]
				if not color_keys.has(triangle.color):
					color_keys[triangle.color]=_unique_anchors.size();_unique_anchors.append(a);colors.append(triangle.color)
				_anchor_indices.append(color_keys[triangle.color]);_anchors.append(a)
	_build_sample_tables()
	_mesh = ArrayMesh.new()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions(); arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX]=_anchor_indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	_mesh.surface_set_material(0,_material); _mesh_node.mesh = _mesh
	_pose_key.clear()

func step() -> bool:
	if not _valid(): dispose(); return false
	if _anchors.is_empty(): return true
	var poses:=_bone_poses(_used_bones)
	var key: Array = [_rig.global_transform,_root.global_transform]
	key.append_array(poses)
	for s: Dictionary in _surfaces:
		if s.skin == null: key.append(s.node.get_ref().global_transform)
	if key == _pose_key: return true
	_pose_key = key
	var start := Time.get_ticks_usec(); var positions := _positions(poses)
	_mesh.surface_update_vertex_region(0,0,positions.to_byte_array())
	var bounds := AABB(positions[0],Vector3.ZERO)
	for p: Vector3 in positions: bounds = bounds.expand(p)
	_mesh.custom_aabb = bounds.grow(.02*_unit)
	last_cost["update_us"] = Time.get_ticks_usec()-start
	return true

func dispose() -> void:
	if is_instance_valid(_mesh_node): _mesh_node.visible = false; _mesh_node.queue_free()
	_root = null; _rig = null; _mesh_node = null; _mesh = null
	_surfaces.clear(); _marks.clear(); _receipts.clear(); _anchors.clear(); _pose_key.clear()
	_unique_anchors.clear();_anchor_indices.clear()
	_sample_surfaces.clear();_sample_vertices.clear();_sample_triangles.clear()
	_anchor_triangles.clear();_anchor_weights.clear();_anchor_offsets.clear()
	_used_bones.clear()
	_influence_start.clear();_influence_bones.clear();_influence_points.clear();_influence_weights.clear()
	_query_cache.clear()
	_query_bones.clear()
