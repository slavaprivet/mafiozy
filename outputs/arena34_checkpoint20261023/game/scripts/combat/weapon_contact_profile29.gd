extends RefCounted
## Samples come from the authored weapon surfaces, including an offset axe or
## hammer head. Decorative material merging does not change their coordinates.
const STEP := 0.030

static func _axe_ridge31(vertices:PackedVector3Array,transform:Transform3D)->PackedVector3Array:
	# The authored bit is a triangular prism: its apex extrudes across Z. Both
	# ends of that real wedge ridge are sharp; the broad caps and rear base are not.
	# Derive the ridge from merged mesh vertices, not a central thickness band.
	var top:=-INF
	for vertex:Vector3 in vertices:top=maxf(top,(transform*vertex).y)
	var ridge:=PackedVector3Array()
	for vertex:Vector3 in vertices:
		var point:=transform*vertex
		if absf(point.y-top)>0.000001:continue
		if ridge.is_empty():ridge.append(point);ridge.append(point)
		if point.z<ridge[0].z:ridge[0]=point
		if point.z>ridge[1].z:ridge[1]=point
	return ridge
static func build_edges(host:Node)->Array[Dictionary]:
	# Keep exact authored endpoints independently of the quantized sweep samples.
	# Array keys compare Vector3 values exactly; no rounding can erase short edges.
	var weapon:Node3D=host.get("_sword")
	var unique:Dictionary={}
	for node:MeshInstance3D in weapon.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null or not node.visible:continue
		var transform:=weapon.global_transform.affine_inverse()*node.global_transform
		var sharp:bool=node.material_override==host.get("_mat_edge") or (node.material_override!=null and bool(node.material_override.get_meta("combat_sharp29",false)))
		for surface in node.mesh.get_surface_count():
			var arrays:=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var local:=PackedVector3Array();local.resize(vertices.size())
			for vertex in vertices.size():local[vertex]=transform*vertices[vertex]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for vertex in vertices.size():indices.append(vertex)
			for triangle in range(0,indices.size(),3):
				for edge in 3:
					var a:Vector3=local[indices[triangle+edge]]
					var b:Vector3=local[indices[triangle+(edge+1)%3]]
					var key:Array=[a,b] if a<b else [b,a]
					if not unique.has(key):unique[key]={"edge_from":key[0],"edge_to":key[1],"material_sharp":sharp}
					elif sharp:unique[key].material_sharp=true
	var result:Array[Dictionary]=[]
	for row:Dictionary in unique.values():result.append(row)
	return result

static func build(host: Node) -> Array[Dictionary]:
	var weapon: Node3D=host.get("_sword")
	var id:=str(host.get("_weapon_id"))
	var points:Dictionary={}
	for node:MeshInstance3D in weapon.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null or not node.visible:continue
		var transform:=weapon.global_transform.affine_inverse()*node.global_transform
		var sharp_material:bool=node.material_override==host.get("_mat_edge") or (node.material_override!=null and bool(node.material_override.get_meta("combat_sharp29",false)))
		for surface in node.mesh.get_surface_count():
			var a:=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var axe_ridge:=_axe_ridge31(vertices,transform) if id=="axe" and sharp_material else PackedVector3Array()
			var hatchet_top:=-INF
			if id=="hatchet" and sharp_material:
				for vertex:Vector3 in vertices:hatchet_top=maxf(hatchet_top,(transform*vertex).y)
			var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for i in vertices.size():indices.append(i)
			for i in range(0,indices.size(),3):
				for edge in 3:
					var start:Vector3=transform*vertices[indices[i+edge]]
					var end:Vector3=transform*vertices[indices[i+(edge+1)%3]]
					var count:=maxi(1,int(ceil(start.distance_to(end)/STEP)))
					for step in count+1:
						var p:=start.lerp(end,float(step)/count)
						var key:=Vector3i(roundi(p.x/.030),roundi(p.y/.030),roundi(p.z/.030))
						var edge_point:=false
						if id=="sword":edge_point=p.x>=.155 and absf(p.z)<.002 and absf(p.y)>.002
						elif id=="hatchet":edge_point=sharp_material and absf(p.y-hatchet_top)<.000001
						elif id=="axe" and axe_ridge.size()==2:
							var ridge_delta:=axe_ridge[1]-axe_ridge[0]
							var nearest:=axe_ridge[0]+ridge_delta*clampf((p-axe_ridge[0]).dot(ridge_delta)/maxf(ridge_delta.length_squared(),1e-12),0,1)
							edge_point=p.distance_squared_to(nearest)<1e-10
						elif id=="spear":edge_point=sharp_material and absf(p.z)<.012
						if not points.has(key) or edge_point:
							points[key]={"local":p,"sharp":edge_point,"material_sharp":sharp_material,"edge_from":start,"edge_to":end,"edge_key":hash([start,end])}
	var result:Array[Dictionary]=[]
	for row:Dictionary in points.values():result.append(row)
	return result

static func kind(id:String,row:Dictionary,motion:Vector3,basis:Basis)->String:
	if id in ["mace","sledge"]:return "blunt"
	if not row.sharp:return "blunt"
	var direction:=motion.normalized()
	if absf(direction.dot(basis.y.normalized()))<.55:return "blunt"
	# Axe material is a finite bit; the wooden handle never inherits sharpness.
	return "edge"
