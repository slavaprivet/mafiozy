extends RefCounted
var last:Dictionary={}
# Pure array work: called by existing startup/worker topology preparation.
# Shared Mesh topology owns one immutable result for every actor using it.
static func build_topology(data:Dictionary)->Dictionary:
	var faces:Array=data.entry_faces31
	var labels:=PackedInt32Array();labels.resize(faces.size());labels.fill(-1)
	var welded_ids:=PackedInt32Array();welded_ids.resize(data.points.size())
	var exact_vertices:Dictionary={}
	for vertex in data.points.size():
		var key:Array=[data.points[vertex]]
		for slot in 4:
			var k:int=vertex*4+slot
			if k<data.weights.size() and data.weights[k]>0.:key.append(data.bones[k]);key.append(data.weights[k])
		# Intern the complete exact signature once. Edge lookups then hash two
		# integers instead of repeatedly hashing both nested influence arrays.
		if not exact_vertices.has(key):exact_vertices[key]=exact_vertices.size()
		welded_ids[vertex]=int(exact_vertices[key])
	var edges:Dictionary={};var neighbors:Array=[]
	for i in faces.size():neighbors.append([])
	for i in faces.size():
		var tri:Vector3i=faces[i]
		for pair:Vector2i in [Vector2i(tri.x,tri.y),Vector2i(tri.y,tri.z),Vector2i(tri.z,tri.x)]:
			# Both endpoint directions resolve to the same edge. Exact bind
			# positions and influences weld normal/UV seams without a tolerance.
			var a:int=welded_ids[pair.x];var b:int=welded_ids[pair.y]
			var key:=Vector2i(mini(a,b),maxi(a,b))
			for other:int in edges.get(key,[]):neighbors[i].append(other);neighbors[other].append(i)
			if not edges.has(key):edges[key]=[]
			edges[key].append(i)
	var serial:=0
	for first in faces.size():
		if labels[first]>=0:continue
		var queue:Array[int]=[first];labels[first]=serial;var cursor:=0
		while cursor<queue.size():
			var current:int=queue[cursor];cursor+=1
			for neighbor:int in neighbors[current]:
				if labels[neighbor]<0:labels[neighbor]=serial;queue.append(neighbor)
		serial+=1
	var closed:=PackedByteArray();closed.resize(serial);closed.fill(1)
	for incident:Array in edges.values():
		if incident.size()!=2:
			for triangle:int in incident:closed[labels[triangle]]=0
	var volumes:=PackedFloat64Array();volumes.resize(serial)
	for index in faces.size():
		var tri:Vector3i=faces[index]
		volumes[labels[index]]+=Vector3(data.points[tri.x]).dot(Vector3(data.points[tri.y]).cross(data.points[tri.z]))/6.
	var main:=-1;var largest:=0.
	for group in serial:
		if closed[group]!=0 and absf(volumes[group])>largest:main=group;largest=absf(volumes[group])
	return {"labels":labels,"closed":closed,"main_component32":main}

func component(_source_key:String,data:Dictionary,face:int)->int:
	var prepared:Dictionary=data.get("hatchet_volume32",{})
	if prepared.is_empty():return -1
	var labels:PackedInt32Array=prepared.labels
	if face<0 or face>=labels.size():return -1
	var group:int=labels[face]
	return group if prepared.closed[group]!=0 else -1
func coherent_exit(entry:Dictionary,hits:Array[Dictionary],direction:Vector3)->float:
	var key:String=entry.source_key
	var group:=component(key,entry.source.data,int(entry.face))
	var entrance_dot:float=Vector3(entry.raw_normal).dot(direction)
	if group<0 or absf(entrance_dot)<.000001:return 0.
	for hit:Dictionary in hits:
		var distance:float=(Vector3(hit.point)-Vector3(entry.point)).dot(direction)
		if distance<=.002 or str(hit.source_key)!=key:continue
		if component(key,hit.source.data,int(hit.face))!=group:continue
		if Vector3(hit.raw_normal).dot(direction)*entrance_dot<-.000001:return distance
	return 0.
func authored_body_exit32(entry:Dictionary,hits:Array[Dictionary],direction:Vector3,requested:float)->Dictionary:
	# This asset has separate closed tie/shirt solids in front of its closed
	# torso. The exception is authored identity, never a generic cloth/material rule.
	var source:Dictionary=entry.source
	var ref:WeakRef=source.get("node")
	var node:Node=ref.get_ref() if ref!=null else null
	if not is_instance_valid(node) or str(node.name)!="player_male_DEMO_core_FABRIC":return {}
	var prepared:Dictionary=source.data.get("hatchet_volume32",{})
	var main:int=prepared.get("main_component32",-1)
	var original_group:=component(entry.source_key,source.data,int(entry.face))
	if main<0 or original_group==main:return {}
	var first_thickness:=coherent_exit(entry,hits,direction)
	if first_thickness<=.002 or first_thickness>.01:return {}
	for row:Dictionary in hits:
		var gap:float=(Vector3(row.point)-Vector3(entry.point)).dot(direction)
		if gap<=.002:continue
		if gap>preload("res://scripts/weapons/hatchet_model32.gd").HEAD_DEPTH:break
		if str(row.source_key)!=str(entry.source_key):return {"accessory_only32":true}
		var group:=component(row.source_key,row.source.data,int(row.face))
		if group<0:return {"accessory_only32":true}
		if group!=main:
			if Vector3(row.raw_normal).dot(direction)*Vector3(entry.raw_normal).dot(direction)>0.:
				var layer_thickness:=coherent_exit(row,hits,direction)
				if layer_thickness<=.002 or layer_thickness>.01:return {"accessory_only32":true}
			continue
		if Vector3(row.raw_normal).dot(direction)*Vector3(entry.raw_normal).dot(direction)<=0.:return {"accessory_only32":true}
		var body_thickness:=coherent_exit(row,hits,direction)
		if body_thickness<=.002:return {"accessory_only32":true}
		return {"thickness":gap+body_thickness if requested>gap+.002 else first_thickness,"body_entry_gap32":gap,"body_entry32":row.point,"body_bone32":row.bone,"body_face32":row.face,"body_component32":main,"accessory_only32":requested<=gap+.002}
	return {"accessory_only32":true}
func depth(host:Node,hit:Dictionary,direction:Vector3,requested:float,excluded:Array[RID])->float:
	var point:Vector3=hit.position
	var solid:RefCounted=host._solid_weapon29
	var rows:Array[Dictionary]=solid.skin_hits_detailed32(host,point-direction*.003,point+direction*.8,str(hit.part31))
	var entry:Dictionary={};var error:=.004
	for row:Dictionary in rows:
		var distance:float=Vector3(row.point).distance_to(point)
		if distance<error:error=distance;entry=row
	if entry.is_empty():last={"reason":"no_exact_entry"};return 0.
	var thickness:=coherent_exit(entry,rows,direction)
	var authored:=authored_body_exit32(entry,rows,direction,requested)
	if authored.has("thickness"):thickness=float(authored.thickness)
	if thickness<=.002:last={"reason":"no_connected_exit","source":entry.source_key,"face":entry.face};return 0.
	var result:=minf(requested,thickness-.002)
	var space:PhysicsDirectSpaceState3D=host._world.get_world_3d().direct_space_state
	var query:=PhysicsRayQueryParameters3D.create(point+direction*.0001,point+direction*result,1,excluded);query.hit_from_inside=true
	var barrier:=space.intersect_ray(query)
	if not barrier.is_empty():result=minf(result,maxf(0.,point.distance_to(barrier.position)-.002))
	last={"reason":"connected_exit","source":entry.source_key,"face":entry.face,"thickness":thickness,"world_blocked":not barrier.is_empty(),"requested":requested,"depth":result}
	last.merge(authored)
	return result
