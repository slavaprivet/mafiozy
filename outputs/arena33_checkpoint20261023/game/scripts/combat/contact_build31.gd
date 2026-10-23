extends RefCounted
## Pure-array contact preparation. Workers own all data until main-thread cache publication.
const BindBVH=preload("res://scripts/combat/contact_bvh31.gd")
const MixedBVH=preload("res://scripts/combat/contact_mixed_bvh31.gd")

static func _family(bone: String) -> String:
	if bone in ["chest","pelvis","spine"]:return "torso"
	if bone in ["head","neck"]:return "head"
	for prefix in ["upperarm","forearm","hand","thigh","shin","foot"]:
		if bone.begins_with(prefix):return ("arm" if prefix in ["upperarm","forearm","hand"] else "leg")+bone.right(2)
	return bone

static func surfaces(inputs:Array,bind_bones:PackedInt32Array,bone_names:PackedStringArray)->Array:
	var surfaces:Array=[]
	for arrays:Array in inputs:
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
			if not groups.has(bone):groups[bone]={"bone":bone,"family":_family(bone_names[bone]) if bone>=0 else "","indices":PackedInt32Array(),"source_orders33":PackedInt32Array(),"vertices":{},"bounds":{},"safe_bounds":true}
			var group:Dictionary=groups[bone]
			group.source_orders33.append(i/3)
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
	return surfaces

static func _entry_topology31(data:Dictionary)->void:
	# Pure-array immutable adjacency follows partition face order. Rebuilt cut
	# topology prepares this in the same worker as the BVH, not during commit.
	if data.has("entry_faces31"):
		if not data.has("hatchet_volume32"):data.hatchet_volume32=preload("res://scripts/weapons/hatchet_volume32.gd").build_topology(data)
		return
	var faces:Array[Vector3i]=[];var neighbors:Array=[];var edges:Dictionary={}
	var source_orders33:=PackedInt32Array()
	var source_orders_valid33:=true
	for group:Dictionary in data.groups.values():
		for i in range(0,group.indices.size(),3):
			var face:=Vector3i(group.indices[i],group.indices[i+1],group.indices[i+2])
			var index:=faces.size();faces.append(face);neighbors.append([])
			if group.has("source_orders33") and group.source_orders33.size()==group.indices.size()/3:
				source_orders33.append(group.source_orders33[i/3])
			else:source_orders_valid33=false
			for pair:Vector2i in [Vector2i(face.x,face.y),Vector2i(face.y,face.z),Vector2i(face.z,face.x)]:
				var key:=Vector2i(mini(pair.x,pair.y),maxi(pair.x,pair.y))
				for old:int in edges.get(key,[]):neighbors[index].append(old);neighbors[old].append(index)
				if not edges.has(key):edges[key]=[]
				edges[key].append(index)
	data.entry_faces31=faces;data.entry_neighbors31=neighbors
	if source_orders_valid33:data.entry_source_orders33=source_orders33
	data.hatchet_volume32=preload("res://scripts/weapons/hatchet_volume32.gd").build_topology(data)

static func partition(data:Dictionary,bind_count:int)->Dictionary:
	_entry_topology31(data)
	if data.has("solid_bind31") and int(data.solid_bind31.bind_count)==bind_count:return data.solid_bind31
	var influences:=PackedInt32Array();influences.resize(data.points.size());influences.fill(-2)
	for vertex:int in data.points.size():
		var influence:=-1;var count:=0;var weight:=0.0
		for slot in 4:
			var k:=vertex*4+slot
			if k>=data.weights.size() or data.weights[k]<=0 or data.bones[k]<0 or data.bones[k]>=bind_count:continue
			count+=1;influence=data.bones[k];weight=data.weights[k]
		if count==0:influences[vertex]=-1
		elif count==1 and weight==1.0:influences[vertex]=influence
	var rigid:Dictionary={};var mixed:Array[Dictionary]=[];var order:=0
	for group:Dictionary in data.groups.values():
		var remainder:Dictionary={"bone":group.bone,"family":group.family,"indices":PackedInt32Array(),"orders":PackedInt32Array(),"vertices":{},"bounds":group.bounds,"safe_bounds":group.safe_bounds}
		for i in range(0,group.indices.size(),3):
			var a:int=group.indices[i];var b:int=group.indices[i+1];var c:int=group.indices[i+2]
			var bind:=influences[a]
			if bind>=-1 and influences[b]==bind and influences[c]==bind:
				var key:=Vector2i(bind,group.bone)
				if not rigid.has(key):rigid[key]={"bind":bind,"bone":group.bone,"points":PackedVector3Array(),"orders":PackedInt32Array()}
				var item:Dictionary=rigid[key]
				item.points.append(data.points[a]);item.points.append(data.points[b]);item.points.append(data.points[c]);item.orders.append(order)
			else:
				remainder.indices.append(a);remainder.indices.append(b);remainder.indices.append(c);remainder.orders.append(order)
				remainder.vertices[a]=true;remainder.vertices[b]=true;remainder.vertices[c]=true
			order+=1
		if not remainder.indices.is_empty():
			var mixed_tree:=MixedBVH.new()
			mixed_tree.build(data,remainder,bind_count)
			remainder.mixed_tree31=mixed_tree
			mixed.append(remainder)
	var views:Array[Dictionary]=[]
	for item:Dictionary in rigid.values():
		var tree:=BindBVH.new();tree.build(item.points,item.orders)
		views.append({"bind":item.bind,"bone":item.bone,"tree":tree})
	var result:Dictionary={"bind_count":bind_count,"rigid":views,"mixed":mixed,"triangles":order}
	data.solid_bind31=result
	return result

