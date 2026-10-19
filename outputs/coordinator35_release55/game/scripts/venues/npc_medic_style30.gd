extends RefCounted
## Medic-only presentation. No skeleton pose, physics, service or resident writes.
const COAT30 := Color(.89,.92,.91)
const EDGE30 := Color(.67,.74,.75)
const RED30 := Color(.65,.025,.035)

static func dress30(rig: Skeleton3D) -> Dictionary:
	var fabric: MeshInstance3D
	for node: Node in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if str(node.name)=="player_male_DEMO_core_FABRIC": fabric=node
	if fabric==null or not fabric.mesh is ArrayMesh: return {"ok":false,"reason":"medic_fabric_identity"}
	var old: ArrayMesh=fabric.mesh
	if old.get_surface_count()!=1:return {"ok":false,"reason":"medic_fabric_surface"}
	var arrays: Array=old.surface_get_arrays(0)
	var stored: Array=old.get("_surfaces")
	var copy: Array=stored.duplicate(true)
	var count: int=stored[0].vertex_count;var format: int=stored[0].format
	if count!=2229 or (format & Mesh.ARRAY_FORMAT_CUSTOM0)!=0:return {"ok":false,"reason":"medic_fabric_format"}
	var palette: Dictionary={}
	for shade: float in [1.0,.9,.6,.78,.67,.72,.68]:
		var color:=Color(.03310477,.06480327,.08228271)*shade
		# Native ARRAY_COLOR quantization truncates uint8; verified against the
		# admitted staff72 histogram (six keys,1648 vertices). No sRGB conversion.
		palette[Vector3i(int(color.r*255),int(color.g*255),int(color.b*255))]=shade
	var offset: int=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_COLOR)
	var stride: int=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var bytes: PackedByteArray=copy[0].attribute_data;var changed:=0
	for index: int in count:
		var at: int=index*stride+offset
		var key:=Vector3i(bytes[at],bytes[at+1],bytes[at+2])
		if not palette.has(key):continue
		var color: Color=COAT30*float(palette[key])
		bytes[at]=roundi(color.r*255);bytes[at+1]=roundi(color.g*255);bytes[at+2]=roundi(color.b*255);changed+=1
	if changed!=1648:return {"ok":false,"reason":"medic_palette_count","changed":changed}
	copy[0].attribute_data=bytes
	var replacement:=ArrayMesh.new();replacement.set("_surfaces",copy)
	replacement.custom_aabb=old.custom_aabb;replacement.shadow_mesh=old.shadow_mesh
	var reread: Array=replacement.surface_get_arrays(0)
	for attribute: int in Mesh.ARRAY_MAX:
		if attribute!=Mesh.ARRAY_COLOR and arrays[attribute]!=reread[attribute]:return {"ok":false,"reason":"medic_attribute_changed","attribute":attribute}
	fabric.mesh=replacement
	# These five additional hairstyle meshes are covered by the medical cap.
	# Brows and the canonical HAIR mesh (including shoes) remain intact.
	var hidden:=0
	for node: Node in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if str(node.name)=="npc_hair_cap" or str(node.name).begins_with("npc_combed_lock"):
			node.hide();hidden+=1
	var tails: Array=[]
	for sign30: float in [-1.0,1.0]:
		_box30(tails,Vector3(.54,.86,.07),Vector3(sign30*.295,1.39,.38),COAT30)
		_box30(tails,Vector3(.07,.86,.64),Vector3(sign30*.59,1.39,.04),COAT30*.88)
		_box30(tails,Vector3(.32,.28,.035),Vector3(sign30*.33,1.77,.43),COAT30*.95)
		_box30(tails,Vector3(.33,.028,.045),Vector3(sign30*.33,1.91,.435),EDGE30)
	_box30(tails,Vector3(1.20,.86,.07),Vector3(0,1.39,-.29),COAT30*.82)
	_box30(tails,Vector3(.022,.75,.018),Vector3(0,1.43,-.334),EDGE30)
	_attach30(rig,"pelvis","MedicCoatSkirt30",tails)
	var chest: Array=[]
	for side: float in [-1.0,1.0]:
		_prism30(chest,PackedVector2Array([Vector2(side*.10,3.26),Vector2(side*.43,3.10),Vector2(side*.25,2.60),Vector2(side*.055,2.87)]),.445,.035,COAT30)
	_box30(chest,Vector3(.20,.15,.025),Vector3(-.36,2.66,.46),Color(.75,.82,.83))
	_box30(chest,Vector3(.10,.027,.018),Vector3(-.36,2.69,.48),RED30)
	_box30(chest,Vector3(.027,.10,.018),Vector3(-.36,2.69,.481),RED30)
	for y: float in [2.05,2.30,2.52]:_box30(chest,Vector3(.035,.035,.02),Vector3(.055,y,.47),EDGE30)
	_attach30(rig,"chest","MedicCoatDetails30",chest)
	var cap: Array=[]
	_cylinder30(cap,.66,.66,.07,Vector3(0,4.57,0),Vector3(1,1,.90),EDGE30)
	_cylinder30(cap,.64,.56,.27,Vector3(0,4.74,0),Vector3(1,1,.90),COAT30)
	_box30(cap,Vector3(.21,.045,.024),Vector3(0,4.72,.572),RED30)
	_box30(cap,Vector3(.05,.17,.024),Vector3(0,4.72,.573),RED30)
	_attach30(rig,"head","MedicCap30",cap)
	return {"ok":true,"recolored_vertices":changed,"native_vertex_buffers_preserved":true,"hidden_hair_meshes":hidden,"new_render_meshes":3,"new_bone_attachments":3,"new_colliders":0}

static func case30(owner: RigidBody3D,frame: Transform3D) -> void:
	var parts: Array=[];var shell:=Color(.82,.89,.88);var rim:=Color(.28,.39,.42);var metal:=Color(.48,.57,.58);var dark:=Color(.035,.055,.06)
	_box30(parts,Vector3(.46,.23,.28),Vector3(0,.025,0),shell)
	_box30(parts,Vector3(.465,.032,.285),Vector3(0,.155,0),COAT30)
	_box30(parts,Vector3(.47,.012,.29),Vector3(0,.137,0),rim)
	for x: float in [-.227,.227]:_box30(parts,Vector3(.012,.015,.29),Vector3(x,.177,0),rim)
	for z: float in [-.14,.14]:_box30(parts,Vector3(.46,.015,.012),Vector3(0,.177,z),rim)
	for x: float in [-.14,.14]:
		_box30(parts,Vector3(.045,.07,.014),Vector3(x,.125,.151),metal)
		_box30(parts,Vector3(.022,.012,.006),Vector3(x,.106,.160),dark)
		_box30(parts,Vector3(.07,.035,.018),Vector3(x,.14,-.151),metal)
	for x: float in [-.07,.07]:_box30(parts,Vector3(.025,.09,.035),Vector3(x,.215,0),dark)
	_box30(parts,Vector3(.165,.025,.035),Vector3(0,.26,0),dark)
	for x: float in [-.216,.216]:
		for z: float in [-.126,.126]:
			_box30(parts,Vector3(.035,.03,.035),Vector3(x,-.083,z),rim)
	_box30(parts,Vector3(.14,.032,.008),Vector3(0,.028,.145),RED30)
	_box30(parts,Vector3(.036,.13,.008),Vector3(0,.028,.146),RED30)
	var mesh: MeshInstance3D=_batch30(parts);mesh.name="MedicCase30";owner.add_child(mesh);mesh.global_transform=frame
	mesh.set_meta("medic_case30",true)

static func _attach30(rig: Skeleton3D,bone: String,label: String,parts: Array) -> void:
	var index: int=rig.find_bone(bone)
	var attachment:=BoneAttachment3D.new();attachment.name=label+"Anchor";attachment.bone_name=bone;rig.add_child(attachment)
	var mesh: MeshInstance3D=_batch30(parts);mesh.name=label;attachment.add_child(mesh)
	mesh.transform=rig.get_bone_global_pose(index).affine_inverse()
	mesh.set_meta("medic_clothing30",true)

static func _box30(parts: Array,size: Vector3,point: Vector3,color: Color) -> void:
	var primitive:=BoxMesh.new();primitive.size=size;parts.append({"arrays":primitive.surface_get_arrays(0),"frame":Transform3D(Basis.IDENTITY,point),"color":color})

static func _cylinder30(parts: Array,bottom: float,top: float,height: float,point: Vector3,scale30: Vector3,color: Color) -> void:
	var primitive:=CylinderMesh.new();primitive.bottom_radius=bottom;primitive.top_radius=top;primitive.height=height;primitive.radial_segments=16;primitive.rings=1
	parts.append({"arrays":primitive.surface_get_arrays(0),"frame":Transform3D(Basis.from_scale(scale30),point),"color":color})

static func _prism30(parts: Array,outline: PackedVector2Array,z: float,depth: float,color: Color) -> void:
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array();var normals:=PackedVector3Array()
	for side: float in [-1.0,1.0]:
		for p: Vector2 in outline:vertices.append(Vector3(p.x,p.y,z+side*depth*.5));normals.append(Vector3(0,0,side))
	indices.append_array(PackedInt32Array([0,2,1,0,3,2,4,5,6,4,6,7]))
	for edge: int in 4:
		var next: int=(edge+1)%4;indices.append_array(PackedInt32Array([edge,next,next+4,edge,next+4,edge+4]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	parts.append({"arrays":arrays,"frame":Transform3D.IDENTITY,"color":color})

static func _batch30(parts: Array) -> MeshInstance3D:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	for part: Dictionary in parts:
		var arrays: Array=part.arrays;var base: int=vertices.size();var frame: Transform3D=part.frame
		for index: int in arrays[Mesh.ARRAY_VERTEX].size():
			vertices.append(frame*arrays[Mesh.ARRAY_VERTEX][index]);normals.append((frame.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][index]).normalized());colors.append(part.color)
		for index: int in arrays[Mesh.ARRAY_INDEX]:indices.append(base+index)
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=false;mat.roughness=.78;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.surface_set_material(0,mat)
	var result:=MeshInstance3D.new();result.mesh=mesh;return result
