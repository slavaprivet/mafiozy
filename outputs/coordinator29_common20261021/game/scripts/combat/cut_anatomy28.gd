extends RefCounted
## Anatomical appearance is attached only to real cap triangles. Geometry,
## normals, skin weights, exterior surfaces and cut decisions are preserved.
const CUT_SHADER = preload("res://scripts/combat/cut_anatomy28.gdshader")

class BodyCap extends MeshInstance3D:
	var owner_host: WeakRef
	var generation := 0
	func _process(_delta: float) -> void:
		var host: Node = owner_host.get_ref()
		if not is_instance_valid(host) or int(host.get("lab_resets"))!=generation: queue_free()

static func decorate(host: Node, plane: Plane, first_debris: int) -> Dictionary:
	var start := Time.get_ticks_usec()
	var rig: Skeleton3D = host.get("_npc_rig")
	if not is_instance_valid(rig): return {"ok":false,"reason":"no_skeleton"}
	var n := plane.normal.normalized()
	var u := n.cross(Vector3.UP if absf(n.y)<0.9 else Vector3.RIGHT).normalized()
	var v := n.cross(u).normalized()
	var origin := n*plane.d
	var frame := {"u":u,"v":v,"n":n,"origin":origin}
	var anatomy := _anatomy(rig,frame)
	var flesh: Material = host.call("_flesh")
	var groups: Array[Array] = [[],[]]
	for node: MeshInstance3D in host.call("_npc_skinned_meshes"):
		_collect(host,node,true,flesh,frame,groups[0])
	var debris: Array = host.get("_npc_debris")
	for index in range(first_debris,debris.size()):
		var body: Node = debris[index].get("node")
		if not is_instance_valid(body): continue
		for node: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
			_collect(host,node,false,flesh,frame,groups[1])
	var cap_count := 0
	var tissue_count := 0
	var rim_count := 0
	var vertices := 0
	var body_overlays := 0
	var details: Array[Dictionary] = []
	for group: Array in groups:
		for cap: Dictionary in group:
			var main := _is_main_volume(cap,group)
			var material := _material(anatomy,cap,not main)
			_replace_cap(cap,material)
			if main and cap.retained and not cap.visible:
				_show_hidden_body_cap(host,cap,material)
				body_overlays += 1
			cap_count += 1
			if main: tissue_count += 1
			else: rim_count += 1
			vertices += cap.uv.size()
			details.append({"source":cap.source,"tissue":main,"retained":cap.retained,"vertices":cap.uv.size()})
	return {"ok":cap_count>0,"caps":cap_count,"tissue_caps":tissue_count,"garment_rims":rim_count,"body_cap_overlays":body_overlays,"cap_vertices":vertices,"bone_sections":anatomy.starts.size(),"skull":anatomy.skull_enabled,"usec":Time.get_ticks_usec()-start,"details":details}

static func _collect(host: Node, node: MeshInstance3D, retained: bool, flesh: Material, frame: Dictionary, out: Array) -> void:
	if not node.mesh is ArrayMesh: return
	var mesh: ArrayMesh = node.mesh
	var binds: Array[Transform3D] = []
	if retained: binds = host.call("_cut_skin_transforms39",node)
	for surface in mesh.get_surface_count():
		if mesh.surface_get_material(surface) != flesh: continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		var posed: Array = host.call("_cut_skin_arrays39",arrays,binds,false) if retained else arrays
		var points: PackedVector3Array = posed[Mesh.ARRAY_VERTEX]
		var uv := PackedVector2Array()
		var near_plane := true
		for point: Vector3 in points:
			var p := node.to_global(point)-Vector3(frame.origin)
			if absf(p.dot(frame.n))>0.008: near_plane = false
			uv.append(Vector2(p.dot(frame.u),p.dot(frame.v)))
		# An earlier cap may still use flesh; only this exact cut plane is decorated.
		if not near_plane or uv.is_empty(): continue
		var source := str(node.name) if retained else str(node.get_meta("cut_source_mesh28",""))
		var visible := node.is_visible_in_tree() if retained else bool(node.get_meta("cut_source_visible28",true))
		var bounds := Rect2(uv[0],Vector2.ZERO)
		for point: Vector2 in uv: bounds = bounds.expand(point)
		out.append({"node":node,"surface":surface,"arrays":arrays,"uv":uv,"source":source,"visible":visible,"retained":retained,"bounds":bounds})

static func _is_main_volume(cap: Dictionary, group: Array) -> bool:
	var name: String = cap.source
	if "_SKIN" in name: return true
	if "_FABRIC" in name: return true
	if "_HAIR" in name or "_TRIM" in name: return false
	var own_rank := _rank(cap)
	for other: Dictionary in group:
		if other == cap or _rank(other)>=own_rank: continue
		if not other.visible and not "_FABRIC" in str(other.source): continue
		var overlap: Rect2 = Rect2(cap.bounds).intersection(other.bounds)
		if overlap.has_area() and overlap.get_area()>Rect2(cap.bounds).get_area()*0.45: return false
	# In this resident the clothed body is a combined garment/body volume.
	# When the underlying FABRIC is hidden by equipment, its visible tailored
	# replacement owns the tissue interior. Other layers retain only their rim.
	return not name.is_empty()

static func _rank(cap: Dictionary) -> int:
	var name: String = cap.source
	if "_SKIN" in name: return 0
	if "_FABRIC" in name: return 1
	if "Torso" in name or "Sleeve" in name or "Leg" in name or "LowerGarment" in name: return 2
	if "Glove" in name or "Boot" in name: return 3
	return 9

static func _replace_cap(cap: Dictionary, material: Material) -> void:
	var node: MeshInstance3D = cap.node
	var old: ArrayMesh = node.mesh
	var result := ArrayMesh.new()
	for surface in old.get_surface_count():
		var arrays: Array = cap.arrays.duplicate() if surface==cap.surface else old.surface_get_arrays(surface)
		if surface==cap.surface: arrays[Mesh.ARRAY_TEX_UV2] = cap.uv
		result.add_surface_from_arrays(old.surface_get_primitive_type(surface),arrays)
		result.surface_set_material(surface,material if surface==cap.surface else old.surface_get_material(surface))
	node.mesh = result
	node.set_meta("cut_anatomy28",true)

static func _show_hidden_body_cap(host: Node, cap: Dictionary, material: Material) -> void:
	var source: MeshInstance3D = cap.node
	var overlay := BodyCap.new()
	overlay.name = "CutAnatomyBodyCap28"
	overlay.owner_host = weakref(host)
	overlay.generation = int(host.get("lab_resets"))
	var arrays: Array = cap.arrays.duplicate()
	arrays[Mesh.ARRAY_TEX_UV2] = cap.uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	overlay.mesh = mesh
	overlay.skin = source.skin
	# The original hidden garment's exterior stays hidden. Its existing cap alone
	# is shown, with identical bone weights, outside the cutter's visual subtree.
	var body: Node3D = host.get("_npc_body")
	body.add_child(overlay)
	overlay.global_transform = source.global_transform
	overlay.skeleton = overlay.get_path_to(host.get("_npc_rig"))
	overlay.set_meta("cut_anatomy28",true)

static func _material(anatomy: Dictionary, cap: Dictionary, rim: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CUT_SHADER
	material.set_shader_parameter("bone_count",anatomy.starts.size())
	var starts: Array[Vector4] = anatomy.starts.duplicate()
	var ends: Array[Vector4] = anatomy.ends.duplicate()
	while starts.size()<32: starts.append(Vector4.ZERO)
	while ends.size()<32: ends.append(Vector4.ZERO)
	material.set_shader_parameter("bone_start",starts)
	material.set_shader_parameter("bone_end",ends)
	material.set_shader_parameter("skull_enabled",anatomy.skull_enabled)
	var organs: Array[Vector4] = anatomy.get("organs",[]).duplicate()
	var organ_sizes: Array[Vector4] = anatomy.get("organ_sizes",[]).duplicate()
	material.set_shader_parameter("organ_count",organs.size())
	while organs.size()<4: organs.append(Vector4.ZERO)
	while organ_sizes.size()<4: organ_sizes.append(Vector4.ONE)
	material.set_shader_parameter("organ_centers",organs)
	material.set_shader_parameter("organ_radii",organ_sizes)
	for key: String in ["skull_center","skull_axis_x","skull_axis_y","skull_axis_z","skull_radii"]:
		material.set_shader_parameter(key,anatomy[key])
	material.set_shader_parameter("layer_rim",rim)
	if rim:
		var edges: Array[Vector4] = cap.boundary.duplicate() if cap.has("boundary") else _boundary(cap.arrays,cap.uv)
		material.set_shader_parameter("edge_count",edges.size())
		while edges.size()<128: edges.append(Vector4.ZERO)
		material.set_shader_parameter("boundary_edges",edges)
	return material

static func _boundary(arrays: Array, uv: PackedVector2Array) -> Array[Vector4]:
	var counts: Dictionary = {}
	var coords: Dictionary = {}
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if indices.is_empty():
		for i in uv.size(): indices.append(i)
	for i in range(0,indices.size(),3):
		for j in 3:
			var a := uv[indices[i+j]]
			var b := uv[indices[i+(j+1)%3]]
			var ka := str(Vector2i((a*100000.0).round()))
			var kb := str(Vector2i((b*100000.0).round()))
			var key := ka+":"+kb if ka<kb else kb+":"+ka
			counts[key] = int(counts.get(key,0))+1
			coords[key] = Vector4(a.x,a.y,b.x,b.y)
	var out: Array[Vector4] = []
	for key: String in counts:
		if counts[key]==1 and out.size()<128: out.append(coords[key])
	return out

static func _point(rig: Skeleton3D, name: String) -> Vector3:
	var index := rig.find_bone(name)
	return rig.global_transform*rig.get_bone_global_pose(index).origin if index>=0 else Vector3.ZERO

static func _project(point: Vector3, frame: Dictionary) -> Vector3:
	var p := point-Vector3(frame.origin)
	return Vector3(p.dot(frame.u),p.dot(frame.v),p.dot(frame.n))

static func _axis(axis: Vector3, frame: Dictionary) -> Vector3:
	return Vector3(axis.dot(frame.u),axis.dot(frame.v),axis.dot(frame.n))

static func _add(anatomy: Dictionary, frame: Dictionary, start: Vector3, end: Vector3, radius: float) -> void:
	if anatomy.starts.size()>=32: return
	var a := _project(start,frame)
	var b := _project(end,frame)
	if minf(a.z,b.z)>radius or maxf(a.z,b.z)<-radius: return
	anatomy.starts.append(Vector4(a.x,a.y,a.z,radius))
	anatomy.ends.append(Vector4(b.x,b.y,b.z,0))

static func _anatomy(rig: Skeleton3D, frame: Dictionary) -> Dictionary:
	var starts: Array[Vector4] = []
	var ends: Array[Vector4] = []
	var head := _point(rig,"head")
	var neck := _point(rig,"neck")
	var spine := _point(rig,"spine_01")
	var chest := _point(rig,"chest")
	var right := (_point(rig,"upperarm_r")-_point(rig,"upperarm_l")).normalized()
	var up := (neck-spine).normalized()
	var forward := right.cross(up).normalized()
	var head_top := _point(rig,"socket_head")
	var skull_center := head.lerp(head_top,0.48)
	var skull_radii := Vector3(0.112,0.169,0.119)
	var skull_local := _project(skull_center,frame)
	var data := {"starts":starts,"ends":ends,"skull_enabled":absf(skull_local.z)<0.19,"skull_center":skull_local,
		"skull_axis_x":_axis(right,frame),"skull_axis_y":_axis(up,frame),"skull_axis_z":_axis(forward,frame),"skull_radii":skull_radii}
	# Analytic soft-tissue volumes stay in the posed torso frame. They decorate
	# existing section triangles only; no floating organs or extra cut geometry.
	var organs: Array[Vector4] = []
	var organ_sizes: Array[Vector4] = []
	var thorax := chest.lerp(neck,0.22)+forward*0.025
	for side: float in [-1.0,1.0]:
		var center := _project(thorax+right*side*0.084,frame)
		organs.append(Vector4(center.x,center.y,center.z,0.0))
		organ_sizes.append(Vector4(0.068,0.105,0.075,0.0))
	var heart := _project(thorax-right*0.025+forward*0.05-up*0.035,frame)
	organs.append(Vector4(heart.x,heart.y,heart.z,1.0))
	organ_sizes.append(Vector4(0.044,0.058,0.043,0.0))
	var liver := _project(chest.lerp(spine,0.45)+right*0.045+forward*0.04,frame)
	organs.append(Vector4(liver.x,liver.y,liver.z,2.0))
	organ_sizes.append(Vector4(0.105,0.05,0.075,0.0))
	data["organs"] = organs
	data["organ_sizes"] = organ_sizes
	_add(data,frame,spine-forward*0.045,chest-forward*0.045,0.026)
	_add(data,frame,chest-forward*0.045,neck-forward*0.018,0.025)
	_add(data,frame,neck-forward*0.018,head,0.021)
	for side: String in ["l","r"]:
		var shoulder := _point(rig,"upperarm_"+side)
		var elbow := _point(rig,"forearm_"+side)
		var wrist := _point(rig,"hand_"+side)
		var hip := _point(rig,"thigh_"+side)
		var knee := _point(rig,"shin_"+side)
		var ankle := _point(rig,"foot_"+side)
		_add(data,frame,shoulder,elbow,0.019)
		_add(data,frame,elbow+forward*0.014,wrist+forward*0.011,0.012)
		_add(data,frame,elbow-forward*0.014,wrist-forward*0.011,0.010)
		_add(data,frame,hip,knee,0.023)
		_add(data,frame,knee,ankle,0.020)
		_add(data,frame,knee+right*0.027,ankle+right*0.023,0.009)
		_add(data,frame,wrist,_point(rig,"socket_hand_"+side),0.011)
		_add(data,frame,ankle,ankle+forward*0.11,0.018)
		_add(data,frame,neck-up*0.025,shoulder,0.011)
	# Four paired ribs use the actual torso frame; their curved segments intersect
	# the plane as bone, instead of placing arbitrary circles on torso wounds.
	for rib in 4:
		var height := chest.lerp(neck,0.12+rib*0.17)
		var width := 0.16-rib*0.012
		for sign_x: float in [-1.0,1.0]:
			var back := height-forward*0.05
			var side := height+right*width*sign_x+forward*0.015-up*0.025
			var front := height+right*width*0.55*sign_x+forward*0.115-up*0.045
			_add(data,frame,back,side,0.008)
			_add(data,frame,side,front,0.008)
	return data
