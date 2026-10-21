extends RefCounted
## Geometry for a finite penetration channel through the actual posed skin.
## Contact classification and the embedded movement constraint are separate.

static func axial_contact(weapon: String, crush: bool, motion: Vector3, axis: Vector3) -> bool:
	return not crush and weapon in ["spear", "sword"] and motion.length_squared() > 0.000001 and motion.normalized().dot(axis.normalized()) > 0.80

static func tip_local(host: Node) -> Vector3:
	var weapon: Node3D = host.get("_sword")
	if weapon.has_meta("puncture_tip30"): return weapon.get_meta("puncture_tip30")
	var vertices: Array[Vector3] = []
	var front := -INF
	var queue: Array[Node] = [weapon]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		for child in node.get_children():queue.append(child)
		if not node is MeshInstance3D or node.mesh == null or not node.is_visible_in_tree():continue
		for surface in node.mesh.get_surface_count():
			var points: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in points:
				var point: Vector3 = weapon.to_local(node.to_global(vertex))
				vertices.append(point);front=maxf(front,point.x)
	var result := Vector3.ZERO;var count := 0
	for point: Vector3 in vertices:
		if point.x>=front-0.000001:result+=point;count+=1
	result=result/float(count) if count>0 else Vector3(.06+float(host.get("_weapon_length")),0,0)
	weapon.set_meta("puncture_tip30",result);weapon.set_meta("puncture_profile30",vertices)
	return result

static func tip_profile(host: Node, depth: float) -> Vector2:
	var tip:=tip_local(host)
	var weapon:Node3D=host.get("_sword")
	var size:=Vector2(.004,.004)
	for point:Vector3 in weapon.get_meta("puncture_profile30",[]):
		if point.x>=tip.x-.35:
			var amount:=clampf(depth/maxf(.0001,tip.x-point.x),0.0,1.0)
			size.x=maxf(size.x,absf(point.y-tip.y)*amount);size.y=maxf(size.y,absf(point.z-tip.z)*amount)
	return size

static func tip_world(host: Node) -> Vector3:
	var weapon: Node3D = host.get("_sword")
	return weapon.to_global(tip_local(host))

static func _family(bone: String) -> String:
	if bone in ["chest","pelvis","spine"]:return "torso"
	if bone in ["head","neck"]:return "head"
	for prefix in ["upperarm","forearm","hand","thigh","shin","foot"]:
		if bone.begins_with(prefix):return ("arm" if prefix in ["upperarm","forearm","hand"] else "leg")+bone.right(2)
	return bone

static func _topology(host:Node,node:MeshInstance3D)->Array:
	var rig:Skeleton3D=host.get("_npc_rig")
	var stamp:="%s:%s:%s"%[node.mesh.get_instance_id(),node.skin.get_instance_id() if node.skin!=null else 0,rig.get_instance_id()]
	var cache:Dictionary=node.get_meta("puncture_topology30",{})
	if cache.get("stamp","")==stamp:return cache.surfaces
	var begun:=Time.get_ticks_usec()
	var binds:Array[Transform3D]=host.call("_cut_skin_transforms39",node)
	var bind_bones:=PackedInt32Array();bind_bones.resize(binds.size());bind_bones.fill(-1)
	for bind in binds.size():
		if node.skin!=null and bind<node.skin.get_bind_count():
			var name:=node.skin.get_bind_name(bind)
			bind_bones[bind]=rig.find_bone(name) if name!=&"" else node.skin.get_bind_bone(bind)
	var surfaces:Array=[]
	for surface in node.mesh.get_surface_count():
		var arrays:=node.mesh.surface_get_arrays(surface)
		var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for i in points.size():indices.append(i)
		var groups:Dictionary={}
		for i in range(0,indices.size(),3):
			var first:int=indices[i];var best:=0.0;var bind:=-1
			for slot in 4:
				var k:=first*4+slot
				if k<weights.size() and weights[k]>best and bones[k]>=0 and bones[k]<bind_bones.size():best=weights[k];bind=bones[k]
			var bone:int=bind_bones[bind] if bind>=0 else -1
			if not groups.has(bone):groups[bone]={"bone":bone,"family":_family(str(rig.get_bone_name(bone))) if bone>=0 else "","indices":PackedInt32Array(),"vertices":{},"bounds":{},"safe_bounds":true}
			var group:Dictionary=groups[bone]
			for corner in 3:
				var vertex:int=indices[i+corner];group.indices.append(vertex)
				if group.vertices.has(vertex):continue
				group.vertices[vertex]=true
				var total:=0.0
				for slot in 4:
					var k:=vertex*4+slot
					if k>=weights.size() or weights[k]<=0.0 or bones[k]<0 or bones[k]>=bind_bones.size():continue
					total+=weights[k];var influence:int=bones[k]
					group.bounds[influence]=group.bounds[influence].expand(points[vertex]) if group.bounds.has(influence) else AABB(points[vertex],Vector3.ZERO)
				if total==0.0:group.bounds[-1]=group.bounds[-1].expand(points[vertex]) if group.bounds.has(-1) else AABB(points[vertex],Vector3.ZERO)
				elif absf(total-1.0)>.0001:group.safe_bounds=false
		surfaces.append({"points":points,"bones":bones,"weights":weights,"groups":groups})
	cache={"stamp":stamp,"surfaces":surfaces,"prepare_usec":Time.get_ticks_usec()-begun}
	node.set_meta("puncture_topology30",cache)
	return surfaces

static func prepare(host:Node)->void:
	if not is_instance_valid(host.get("_npc_rig")):return
	var begun:=Time.get_ticks_usec()
	for node:MeshInstance3D in host.call("_npc_skinned_meshes"):
		if node.mesh!=null and node.is_visible_in_tree():_topology(host,node)
	host.set_meta("puncture_prepare30_usec",Time.get_ticks_usec()-begun)

static func _triangles(host:Node,from:Vector3,to:Vector3,part:String)->Array:
	var rig:Skeleton3D=host.get("_npc_rig")
	var nodes:Array=host.call("_npc_skinned_meshes")
	var pose:Array=[host.get("lab_resets"),rig.global_transform]
	for index in rig.get_bone_count():pose.append(rig.get_bone_global_pose(index))
	for node:MeshInstance3D in nodes:
		pose.append(node.global_transform);pose.append(node.mesh.get_instance_id() if node.mesh!=null else 0);pose.append(node.is_visible_in_tree())
	var stamp:=str(hash(pose))
	var cache:Dictionary=host.get_meta("puncture_pose30",{})
	if cache.get("stamp","")!=stamp:cache={"stamp":stamp,"groups":{},"build_usec":0,"posed_vertices":0}
	var begun:=Time.get_ticks_usec();var triangles:Array=[];var family:=_family(part)
	for node:MeshInstance3D in nodes:
		if node.mesh==null or not node.is_visible_in_tree():continue
		var binds:Array[Transform3D]=host.call("_cut_skin_transforms39",node)
		var surfaces:=_topology(host,node)
		for surface in surfaces.size():
			var data:Dictionary=surfaces[surface]
			for group:Dictionary in data.groups.values():
				if not part.is_empty() and group.family!=family:continue
				var bounds:=AABB();var first:=true
				for influence:int in group.bounds:
					var transform:Transform3D=node.global_transform*(binds[influence] if influence>=0 else Transform3D.IDENTITY)
					var transformed:AABB=transform*group.bounds[influence]
					bounds=transformed if first else bounds.merge(transformed);first=false
				# Every normalized skinned vertex is a convex combination of these
				# transformed bounds. Unusual non-normalized weights skip broad culling.
				if group.safe_bounds and not bounds.grow(.00001).intersects_segment(from,to):continue
				var key:="%s:%s:%s"%[node.get_instance_id(),surface,group.bone]
				if not cache.groups.has(key):
					var posed:Dictionary={}
					for vertex:int in group.vertices:
						var position:=Vector3.ZERO;var total:=0.0
						for slot in 4:
							var k:=vertex*4+slot
							if k>=data.weights.size() or data.weights[k]<=0.0 or data.bones[k]<0 or data.bones[k]>=binds.size():continue
							position+=(binds[data.bones[k]]*data.points[vertex])*data.weights[k];total+=data.weights[k]
						posed[vertex]=node.to_global(position if total>0.0 else data.points[vertex])
					var made:Array=[]
					for i in range(0,group.indices.size(),3):
						var a:Vector3=posed[group.indices[i]];var b:Vector3=posed[group.indices[i+1]];var c:Vector3=posed[group.indices[i+2]]
						made.append({"a":a,"b":b,"c":c,"bone":group.bone,"family":group.family,"bounds":AABB(a,Vector3.ZERO).expand(b).expand(c)})
					cache.groups[key]=made;cache.posed_vertices+=posed.size()
				triangles.append_array(cache.groups[key])
	cache.build_usec+=Time.get_ticks_usec()-begun
	host.set_meta("puncture_pose30",cache)
	return triangles


static func _hits(host:Node,part:String,from:Vector3,to:Vector3)->Array[Dictionary]:
	var hits:Array[Dictionary]=[]
	var family:=_family(part)
	for triangle:Dictionary in _triangles(host,from,to,part):
		if not part.is_empty() and triangle.family!=family:continue
		if not triangle.bounds.grow(.00001).intersects_segment(from,to):continue
		var hit:Variant=Geometry3D.segment_intersects_triangle(from,to,triangle.a,triangle.b,triangle.c)
		if hit==null:continue
		var duplicate:=false
		for old:Dictionary in hits:
			if Vector3(old.point).distance_to(hit)<.001:duplicate=true;break
		if not duplicate:
			var normal:Vector3=(triangle.b-triangle.a).cross(triangle.c-triangle.a).normalized()
			if normal.dot(to-from)>0.0:normal=-normal
			hits.append({"point":hit,"bone":triangle.bone,"normal":normal})
	hits.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return from.distance_squared_to(a.point)<from.distance_squared_to(b.point))
	return hits

static func skin_path(host: Node, part: String, point: Vector3, axis: Vector3) -> Dictionary:
	var hits:=_hits(host,part,point-axis*.60,point+axis*.80)
	if hits.size()<2:return {"ok":false,"reason":"no_closed_skin_path","intersections":hits.size()}
	var entry:Vector3=hits.front().point;var exit:Vector3=hits.back().point
	if entry.distance_to(point)>.60 or entry.distance_to(exit)<.008:return {"ok":false,"reason":"invalid_skin_interval"}
	return {"ok":true,"entry":entry,"exit":exit,"length":entry.distance_to(exit),"intersections":hits.size(),"bone":hits.front().bone}

static func entry_path(host:Node,previous_tip:Vector3,tip:Vector3,shaft_axis:Vector3)->Dictionary:
	# Only the foremost point's real, continuous travelled segment can create entry.
	var entered:=_hits(host,"",previous_tip,tip)
	if entered.is_empty():return {"ok":false,"reason":"no_tip_surface_crossing"}
	var entry:Vector3=entered.front().point
	var bone:int=entered.front().bone
	var rig:Skeleton3D=host.get("_npc_rig")
	var part:=str(rig.get_bone_name(bone)) if bone>=0 else ""
	var exits:=_hits(host,part,entry+shaft_axis*.002,entry+shaft_axis*1.4)
	if exits.is_empty():return {"ok":false,"reason":"no_same_part_exit","bone":bone}
	var exit:Vector3=exits.back().point
	return {"ok":true,"entry":entry,"exit":exit,"normal":entered.front().normal,"length":entry.distance_to(exit),"bone":bone,"intersections":entered.size()+exits.size()}

static func ring(half_width: float, half_height: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in 24:
		var angle := TAU*float(i)/24.0
		points.append(Vector3(cos(angle)*half_width,sin(angle)*half_height,0))
	return points

static func channel_mesh(points: Array[Vector3], depth: float, closed: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i+1)%points.size()]
		var c := b-Vector3(0,0,depth)
		var d := a-Vector3(0,0,depth)
		var vertices: Array[Vector3] = [a,b,c,a,c,d]
		if closed: vertices.append_array([Vector3(0,0,-depth),d,c])
		for vertex: Vector3 in vertices: tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()
