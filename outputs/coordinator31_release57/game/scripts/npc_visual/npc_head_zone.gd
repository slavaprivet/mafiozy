extends RefCounted
## Read-only exact skin refinement AFTER an admitted native owned-collider hit.
## No head-by-height, proximity, capsule or critical-chance classification.
var _rig: WeakRef
var _surfaces: Array[Dictionary]=[]
var _head_bone:=-1
var ready:=false
var last_us:=0
var _head_min:=Vector3(INF,INF,INF)
var _head_max:=Vector3(-INF,-INF,-INF)
var _head_triangles:=PackedVector3Array()
var _head_tree: Dictionary={}

static var _tree_cache: Dictionary={}
const TREE_CACHE_LIMIT:=256
static var _surface_cache: Dictionary={}
const SURFACE_CACHE_LIMIT:=512

func configure(rig: Skeleton3D) -> bool:
	if ready or not is_instance_valid(rig):return false
	_head_bone=rig.find_bone("head")
	if _head_bone<0:return false
	_rig=weakref(rig)
	var total:=0;var head_faces:=0
	for node: Node in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D
		if mesh.mesh==null or mesh.skin==null:continue
		var binds: Array[Transform3D]=[];var names: Array[String]=[]
		for b in mesh.skin.get_bind_count():
			var name:=str(mesh.skin.get_bind_name(b))
			if name.is_empty():
				var bone:=mesh.skin.get_bind_bone(b)
				if bone<0 or bone>=rig.get_bone_count():return false
				name=str(rig.get_bone_name(bone))
			if rig.find_bone(name)<0:return false
			binds.append(mesh.skin.get_bind_pose(b));names.append(name)
		var is_head_bind:=PackedByteArray();is_head_bind.resize(names.size())
		for b2 in names.size():is_head_bind[b2]=1 if names[b2]=="head" else 0
		var anatomical_skin: bool="SKIN" in str(mesh.name).to_upper()
		for surface in mesh.mesh.get_surface_count():
			if mesh.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:return false
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				indices.resize(vertices.size())
				for i in indices.size():indices[i]=i
			if bones.size()!=vertices.size()*4 or weights.size()!=bones.size() or indices.size()%3!=0:return false
			total+=vertices.size()
			if total>20000:return false
			# The whole analysis below depends only on geometry, bind poses, counts and
			# bind names, which are identical for every resident that shares this prepared
			# surface. Cache it once per surface content and reuse it, instead of paying
			# it once per resident. The key is a content hash; every hit is re-verified by
			# comparing the arrays, so a hash collision can never return a wrong zone.
			var sig:=_surface_signature(vertices,bones,weights,indices,binds,is_head_bind,anatomical_skin)
			var cached: Variant=_surface_cache.get(sig)
			if cached != null:
				var hit: Dictionary=cached
				if hit.vertices==vertices and hit.bones==bones and hit.weights==weights and hit.indices==indices and hit.binds==binds and hit.is_head_bind==is_head_bind and hit.anatomical_skin==anatomical_skin:
					_surfaces.append({"node":weakref(mesh),"resource":mesh.mesh,"skin":mesh.skin,"vertices":hit.vertices,"bones":hit.bones,"weights":hit.weights,"indices":hit.indices,"head_indices":hit.head_indices,"heads":hit.heads,"binds":binds,"names":names,"dynamic_head_indices":hit.dynamic_head_indices,"clusters":hit.clusters})
					head_faces+=int(hit.head_faces)
					_head_min=_head_min.min(hit.head_min);_head_max=_head_max.max(hit.head_max)
					_head_triangles.append_array(hit.head_triangles)
					continue
			var heads:=PackedByteArray();heads.resize(vertices.size())
			for v in vertices.size():
				var head_weight:=0.0
				for k in 4:
					var j:=v*4+k
					if weights[j]<=0:continue
					if bones[j]<0 or bones[j]>=names.size():return false
					if is_head_bind[bones[j]]==1:head_weight+=weights[j]
				heads[v]=1 if head_weight>.999 else 0
			var head_indices:=PackedInt32Array()
			var local_min:=Vector3(INF,INF,INF);var local_max:=Vector3(-INF,-INF,-INF)
			var surface_faces:=0
			for i in range(0,indices.size(),3):
				for n in 3:
					if indices[i+n]<0 or indices[i+n]>=vertices.size():return false
				if anatomical_skin and heads[indices[i]]==1 and heads[indices[i+1]]==1 and heads[indices[i+2]]==1:
					head_indices.append_array(indices.slice(i,i+3));surface_faces+=1
			for v in head_indices:
				var local:=Vector3.ZERO
				for k in 4:
					var j:=v*4+k
					if weights[j]>0:local+=binds[bones[j]]*vertices[v]*weights[j]
				local_min=local_min.min(local);local_max=local_max.max(local)
			var dynamic_head:=PackedInt32Array()
			var surface_triangles:=PackedVector3Array()
			for i in range(0,head_indices.size(),3):
				var triangle:=PackedVector3Array();var rigid:=true
				for n in 3:
					var v: int=head_indices[i+n];var p:=Vector3.ZERO;var total_weight:=0.0
					for k in 4:
						var j:=v*4+k
						if weights[j]<=0:continue
						if is_head_bind[bones[j]]==0:rigid=false
						p+=binds[bones[j]]*vertices[v]*weights[j];total_weight+=weights[j]
					if total_weight!=1.0:rigid=false
					triangle.append(p)
				if rigid:surface_triangles.append_array(triangle)
				else:dynamic_head.append_array(head_indices.slice(i,i+3))
			var entry: Dictionary={"node":weakref(mesh),"resource":mesh.mesh,"skin":mesh.skin,"vertices":vertices,"bones":bones,"weights":weights,"indices":indices,"head_indices":head_indices,"heads":heads,"binds":binds,"names":names,"dynamic_head_indices":dynamic_head}
			entry["clusters"]=_clusters(entry)
			if _surface_cache.size()>=SURFACE_CACHE_LIMIT:_surface_cache.clear()
			_surface_cache[sig]={"head_indices":head_indices,"heads":heads,"dynamic_head_indices":dynamic_head,"clusters":entry.clusters,"vertices":vertices,"bones":bones,"weights":weights,"indices":indices,"binds":binds,"is_head_bind":is_head_bind,"anatomical_skin":anatomical_skin,"head_faces":surface_faces,"head_min":local_min,"head_max":local_max,"head_triangles":surface_triangles}
			_surfaces.append(entry)
			head_faces+=surface_faces
			_head_min=_head_min.min(local_min);_head_max=_head_max.max(local_max)
			_head_triangles.append_array(surface_triangles)
	var triangle_ids:=PackedInt32Array()
	for i in range(0,_head_triangles.size(),3):triangle_ids.append(i)
	# The BVH depends only on _head_triangles, and nothing mutates it after configure.
	# Residents that share a prepared body produce byte-identical triangles, so build
	# the tree once per distinct triangle set. The key is a content hash, but every
	# hit is re-verified by comparing the arrays: a hash collision can never return a
	# tree built for different geometry.
	if not triangle_ids.is_empty():
		var tree_key: int = hash(_head_triangles)
		var cached_tree: Variant = _tree_cache.get(tree_key)
		if cached_tree != null and cached_tree.triangles == _head_triangles:
			_head_tree = cached_tree.tree
		else:
			_head_tree = _build_head_tree(triangle_ids)
			if _tree_cache.size() >= TREE_CACHE_LIMIT: _tree_cache.clear()
			_tree_cache[tree_key] = {"triangles":_head_triangles,"tree":_head_tree}
	ready=head_faces>0
	return ready

func _surface_signature(vertices: PackedVector3Array,bones: PackedInt32Array,weights: PackedFloat32Array,indices: PackedInt32Array,binds: Array[Transform3D],is_head_bind: PackedByteArray,anatomical_skin: bool) -> int:
	var h:=hash(vertices)
	h=h*31+hash(bones);h=h*31+hash(weights);h=h*31+hash(indices);h=h*31+hash(binds);h=h*31+hash(is_head_bind)
	h=h*31+(1 if anatomical_skin else 0)
	return h
func _build_head_tree(ids: PackedInt32Array) -> Dictionary:
	var bounds:=AABB(_head_triangles[ids[0]],Vector3.ZERO)
	for id in ids:
		for n in 3:bounds=bounds.expand(_head_triangles[id+n])
	if ids.size()<=8:return {"bounds":bounds.grow(.000001),"ids":ids}
	# Sort triangle ids by centre on the split axis using parallel numeric arrays.
	# The original built one Dictionary per triangle and sorted through a Dictionary
	# lambda; that allocation dominated every configure call, including cache hits.
	# Tree shape does not change _trace_head_tree's result: it keeps the nearest hit
	# over every visited leaf and the bounds test is conservative.
	var axis:=bounds.size.max_axis_index()
	var count:=ids.size()
	# Native sort instead of sort_custom on a script lambda. The lambda ran once per
	# comparison at every BVH node, about 240k script calls for a 2000-triangle head
	# and ~86% of configure. Quantise the centre into the high bits and carry the
	# original index in the low 20 bits, so one native integer sort orders both.
	# Quantisation and ties only choose a different valid split: _trace_head_tree
	# always visits both children and keeps the global nearest hit, so the tree shape
	# cannot change the result.
	var packed:=PackedInt64Array();packed.resize(count)
	for i in count:
		var id:=ids[i]
		var centre: float=(_head_triangles[id]+_head_triangles[id+1]+_head_triangles[id+2])[axis]
		var q: int=int(round(centre*4096.0)) & 0x7FFFFF
		packed[i]=(q<<20) | (i & 0xFFFFF)
	packed.sort()
	var left:=PackedInt32Array();var right:=PackedInt32Array()
	for i in count:
		var idx: int=packed[i] & 0xFFFFF
		if i<count/2:left.append(ids[idx])
		else:right.append(ids[idx])
	return {"bounds":bounds.grow(.000001),"left":_build_head_tree(left),"right":_build_head_tree(right)}

func _trace_head_tree(node: Dictionary,origin: Vector3,direction: Vector3,maximum: float) -> Dictionary:
	if node.is_empty() or node.bounds.intersects_segment(origin,origin+direction*maximum)==null:return {}
	var nearest: Dictionary={};var distance:=maximum
	if node.has("ids"):
		for id: int in node.ids:
			var a: Vector3=_head_triangles[id];var b: Vector3=_head_triangles[id+1];var c: Vector3=_head_triangles[id+2]
			var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,a,b,c)
			if hit is Vector3:
				var t: float=(hit-origin).dot(direction)
				var normal: Vector3=(b-a).cross(c-a)
				if t>=0 and t<distance and normal.length_squared()>1e-16:
					nearest={"point":hit,"normal":normal.normalized()};distance=t
	else:
		for child: Dictionary in [node.left,node.right]:
			var hit: Dictionary=_trace_head_tree(child,origin,direction,distance)
			if not hit.is_empty():nearest=hit;distance=(hit.point-origin).dot(direction)
	return nearest

func _clusters(s: Dictionary) -> Array[Dictionary]:
	# Optimised: array accumulator instead of a per-triangle Dictionary, and no
	# per-triangle Array literal allocations. Same arithmetic and the same tie
	# order (insertion order of positively weighted binds).
	var groups: Dictionary={}
	var accum:=PackedFloat32Array();accum.resize(s.names.size())
	var touched:=PackedInt32Array()
	var indices: PackedInt32Array=s.indices
	var bones: PackedInt32Array=s.bones
	var weights: PackedFloat32Array=s.weights
	var heads: PackedByteArray=s.heads
	var verts: PackedVector3Array=s.vertices
	for i in range(0,indices.size(),3):
		var i0: int=indices[i];var i1: int=indices[i+1];var i2: int=indices[i+2]
		var dominant:=-1;var best:=-1.0
		for index: int in [i0,i1,i2]:
			var b0: int=index*4
			for k in 4:
				var j: int=b0+k
				var weight: float=weights[j]
				if weight<=0:continue
				var bnd: int=bones[j]
				if accum[bnd]==0.0:touched.append(bnd)
				accum[bnd]=accum[bnd]+weight
		for item: int in touched:
			var score: float=accum[item]
			if score>best:dominant=item;best=score
			accum[item]=0.0
		touched.clear()
		if not groups.has(dominant):groups[dominant]={"indices":PackedInt32Array(),"bounds":{},"seen":{},"head_only":true}
		var group: Dictionary=groups[dominant]
		for index: int in [i0,i1,i2]:
			group.indices.append(index)
			if heads[index]!=1:group.head_only=false
			if group.seen.has(index):continue
			group.seen[index]=true
			var b1: int=index*4
			for k in 4:
				var j: int=b1+k
				if weights[j]<=0:continue
				var bnd: int=bones[j]
				group.bounds[bnd]=group.bounds[bnd].expand(verts[index]) if group.bounds.has(bnd) else AABB(verts[index],Vector3.ZERO)
	var result: Array[Dictionary]=[]
	for group: Dictionary in groups.values():group.erase("seen");result.append(group)
	return result

func _vertex(s: Dictionary,index: int,matrices: Array[Transform3D],cache: Dictionary) -> Vector3:
	if cache.has(index):return cache[index]
	var world:=Vector3.ZERO
	for k in 4:
		var j:=index*4+k
		if s.weights[j]<=0:continue
		var bind: int=s.bones[j]
		world+=matrices[bind]*s.vertices[index]*s.weights[j]
	cache[index]=world
	return world

func _head_ray_bounds(origin: Vector3,direction: Vector3,maximum: float,frame: Transform3D) -> bool:
	var local:=frame.affine_inverse()
	var o:=local*origin;var d:=local.basis*direction
	var low:=0.0;var high:=maximum
	for axis in 3:
		if absf(d[axis])<1e-10:
			if o[axis]<_head_min[axis]-.01 or o[axis]>_head_max[axis]+.01:return false
		else:
			var a: float=(_head_min[axis]-.01-o[axis])/d[axis]
			var b: float=(_head_max[axis]+.01-o[axis])/d[axis]
			low=maxf(low,minf(a,b));high=minf(high,maxf(a,b))
			if high<low:return false
	return true

func classify(origin: Vector3,direction: Vector3,maximum: float,physical: RefCounted,scene: Node3D,excluded: Array[RID]) -> Dictionary:
	var began:=Time.get_ticks_usec()
	var answer:=_classify(origin,direction,maximum,physical,scene,excluded)
	last_us=Time.get_ticks_usec()-began
	return answer

func _classify(origin: Vector3,direction: Vector3,maximum: float,physical: RefCounted,scene: Node3D,excluded: Array[RID]) -> Dictionary:
	if not ready or not origin.is_finite() or not direction.is_finite() or direction.length_squared()<.5 or not is_finite(maximum) or maximum<=0 or not is_instance_valid(scene):return {}
	var rig: Skeleton3D=_rig.get_ref()
	if not is_instance_valid(rig) or not rig.is_inside_tree():return {}
	var frames: Dictionary={}
	if physical.mode=="ACTIVE":
		var snap: Dictionary=physical._body.snapshot()
		if not snap.get("valid",false) or not snap.get("active",false):return {}
		frames=snap.bone_world_frames
	elif physical.mode=="IDLE":
		for i in rig.get_bone_count():frames[str(rig.get_bone_name(i))]=rig.global_transform*rig.get_bone_global_pose(i)
	else:return {}
	var caches: Array[Dictionary]=[];var nearest:=maximum;var point:=Vector3.ZERO;var normal:=Vector3.ZERO;var found:=false
	var transforms: Array=[]
	var ray:=direction.normalized()
	if not _head_ray_bounds(origin,ray,maximum,frames.head):return {}
	# Exactly rigid head-weighted triangles can stay in bind space. BVH bounds
	# only reject; surviving leaves still use the original triangle intersection.
	var inverse: Transform3D=frames.head.affine_inverse()
	var local_ray: Vector3=inverse.basis*ray
	var rigid_hit: Dictionary=_trace_head_tree(_head_tree,inverse*origin,local_ray.normalized(),maximum*local_ray.length())
	if not rigid_hit.is_empty():
		point=frames.head*rigid_hit.point;normal=(inverse.basis.transposed()*rigid_hit.normal).normalized();nearest=(point-origin).dot(ray);found=true
	for s: Dictionary in _surfaces:
		var node: MeshInstance3D=s.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.mesh!=s.resource or node.skin!=s.skin:return {}
		var matrices: Array[Transform3D]=[]
		for bind in s.names.size():matrices.append(frames[s.names[bind]]*s.binds[bind])
		transforms.append(matrices)
		var cache: Dictionary={};caches.append(cache)
		for i in range(0,s.dynamic_head_indices.size(),3):
			var a: Vector3=_vertex(s,s.dynamic_head_indices[i],matrices,cache)
			var b: Vector3=_vertex(s,s.dynamic_head_indices[i+1],matrices,cache)
			var c: Vector3=_vertex(s,s.dynamic_head_indices[i+2],matrices,cache)
			var hit: Variant=Geometry3D.ray_intersects_triangle(origin,ray,a,b,c)
			if hit is Vector3:
				var t: float=(hit-origin).dot(ray)
				var face_normal: Vector3=(b-a).cross(c-a)
				if t>=0 and t<nearest and face_normal.length_squared()>1e-16:
					nearest=t;point=hit;normal=face_normal.normalized();found=true
	if not found:return {}
	# Another body part in front of the skull wins. Hair/hat bound entirely to
	# head cannot promote a miss: an anatomical SKIN triangle already hit above.
	for n in _surfaces.size():
		var s: Dictionary=_surfaces[n];var cache: Dictionary=caches[n]
		var matrices: Array[Transform3D]=transforms[n]
		for group: Dictionary in s.clusters:
			if group.head_only:continue
			var bounds:=AABB();var first:=true
			for bind: int in group.bounds:
				var bound: AABB=matrices[bind]*group.bounds[bind]
				bounds=bound if first else bounds.merge(bound);first=false
			if bounds.grow(.00001).intersects_segment(origin,point)==null:continue
			for i in range(0,group.indices.size(),3):
				var a: int=group.indices[i];var b: int=group.indices[i+1];var c: int=group.indices[i+2]
				if s.heads[a]==1 and s.heads[b]==1 and s.heads[c]==1:continue
				var hit: Variant=Geometry3D.ray_intersects_triangle(origin,ray,_vertex(s,a,matrices,cache),_vertex(s,b,matrices,cache),_vertex(s,c,matrices,cache))
				if hit is Vector3:
					var t: float=(hit-origin).dot(ray)
					if t>=0 and t<nearest-.0001:return {}
	# Refinement past a broad native proxy never shoots through actual scenery,
	# vehicles or another NPC. Existing owned hulls alone are excluded.
	var query:=PhysicsRayQueryParameters3D.create(origin,point,5|256,excluded)
	query.hit_from_inside=true
	var block: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
	if not block.is_empty() and origin.distance_to(block.position)<nearest-.0001:return {}
	if not normal.is_finite() or normal.length_squared()<.5:return {}
	if normal.dot(ray)>0:normal=-normal
	return {"zone":"head","point":point,"normal":normal,"direction":ray,"distance_m":nearest,"proof":"native_owned_hit_then_first_anatomical_skin_triangle","user_rule":true}
