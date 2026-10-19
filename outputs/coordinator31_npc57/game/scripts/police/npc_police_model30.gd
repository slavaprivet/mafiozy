extends RefCounted
## Two presentation-only service models. Explicit factory only: no world/AI/HP owner.
const Cache30 = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const MANIFEST30 := "res://assets/npc_visual/session/prepared/manifest.json"
const DIRECTORY30 := "res://assets/npc_visual/session/prepared"
const MANIFEST_SHA30 := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
const SOURCES30 := [
 {"bridge":"npc_resident_72","descriptor":"fb812a2fc447726dd30548edb34805295ac28e6970c2ca55a6abb18a5a4c39bd","service_id":"police_service_model_a30"},
 {"bridge":"npc_resident_252","descriptor":"63013b43b2210fd997d9a57fd8b1fa315312bd2ff3e1387e115f667e6db75b55","service_id":"police_service_model_b30"}
]
const NAVY30 := Color(.018,.045,.10)
const GOLD30 := Color(.68,.44,.085)
const DARK30 := Color(.012,.017,.025)

static func create_model30(variant: int) -> Dictionary:
	if variant<0 or variant>=SOURCES30.size():return {"ok":false,"reason":"police_model_variant"}
	var source: Dictionary=SOURCES30[variant]
	var admission: Dictionary=Cache30.load_verified(FileAccess.get_file_as_bytes(MANIFEST30),MANIFEST_SHA30,source.bridge,source.descriptor,DIRECTORY30)
	if not admission.get("ok",false):return admission
	var appearance: Dictionary=admission.cache.instantiate_actor();admission.cache.dispose()
	if not appearance.get("ok",false):return appearance
	var model:=Node3D.new();model.name="PoliceModelA30" if variant==0 else "PoliceModelB30"
	var motion:=Node3D.new();motion.name="CanonicalMotion30";model.add_child(motion)
	motion.add_child(appearance.visual);motion.rotation.y=PI
	# The old bridge id describes the reused mesh source, never a resident authority.
	model.set_meta("police_service_model_id30",source.service_id)
	model.set_meta("presentation_only30",true)
	var receipt: Dictionary=dress30(appearance.skeleton,variant)
	if not receipt.get("ok",false):model.free();return receipt
	return {"ok":true,"model":model,"motion":motion,"appearance":appearance,"receipt":receipt,"service_id":source.service_id,"source_bridge_id":source.bridge}

static func dress30(rig: Skeleton3D,variant: int) -> Dictionary:
	if variant<0 or variant>=2 or rig==null or rig.get_bone_count()!=28:return {"ok":false,"reason":"police_canonical_rig"}
	if rig.has_meta("police_style30"):return rig.get_meta("police_style30").duplicate(true)
	var fabric: MeshInstance3D
	for node: Node in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if str(node.name)=="player_male_DEMO_core_FABRIC":fabric=node
	if fabric==null or not fabric.mesh is ArrayMesh or fabric.mesh.get_surface_count()!=1:return {"ok":false,"reason":"police_fabric_identity"}
	var old: ArrayMesh=fabric.mesh;var arrays: Array=old.surface_get_arrays(0)
	var stored: Array=old.get("_surfaces");var copy: Array=stored.duplicate(true)
	var count: int=stored[0].vertex_count;var format: int=stored[0].format
	if count!=2229 or (format & Mesh.ARRAY_FORMAT_CUSTOM0)!=0:return {"ok":false,"reason":"police_fabric_format"}
	var palette: Dictionary={}
	for shade: float in [1.0,.9,.6,.78,.67,.72,.68]:
		var color:=Color(.03310477,.06480327,.08228271)*shade
		palette[Vector3i(int(color.r*255),int(color.g*255),int(color.b*255))]=shade
	var offset: int=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_COLOR)
	var stride: int=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var bytes: PackedByteArray=copy[0].attribute_data;var changed:=0
	var uniform: Color=NAVY30 if variant==0 else Color(.026,.06,.12)
	for index: int in count:
		var at: int=index*stride+offset;var key:=Vector3i(bytes[at],bytes[at+1],bytes[at+2])
		if not palette.has(key):continue
		var color: Color=uniform*float(palette[key])
		bytes[at]=roundi(color.r*255);bytes[at+1]=roundi(color.g*255);bytes[at+2]=roundi(color.b*255);changed+=1
	if changed!=1648:return {"ok":false,"reason":"police_palette_count","changed":changed}
	copy[0].attribute_data=bytes
	var replacement:=ArrayMesh.new();replacement.set("_surfaces",copy)
	replacement.custom_aabb=old.custom_aabb;replacement.shadow_mesh=old.shadow_mesh
	var reread: Array=replacement.surface_get_arrays(0)
	for attribute: int in Mesh.ARRAY_MAX:
		if attribute!=Mesh.ARRAY_COLOR and arrays[attribute]!=reread[attribute]:return {"ok":false,"reason":"police_attribute_changed","attribute":attribute}
	fabric.mesh=replacement
	var hidden: Array[String]=[]
	for node: Node in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if str(node.name).begins_with("npc_hair") or str(node.name).begins_with("npc_combed_lock") or str(node.name).begins_with("npc_crew_top"):
			node.hide();hidden.append(str(node.name))
	var chest: Array=[]
	# Formal uniform collar, tie, metallic chest shield, name strip and shoulder boards.
	for side: float in [-1.0,1.0]:
		_box30(chest,Vector3(.25,.065,.33),Vector3(side*.60,3.12,.02),DARK30)
		_box30(chest,Vector3(.14,.018,.22),Vector3(side*.60,3.16,.02),GOLD30)
		_box30(chest,Vector3(.27,.18,.028),Vector3(side*.34,2.70,.455),uniform*1.2)
		_box30(chest,Vector3(.29,.035,.035),Vector3(side*.34,2.81,.46),uniform*.8)
	_box30(chest,Vector3(.12,.29,.028),Vector3(0,2.99,.47),DARK30)
	_box30(chest,Vector3(.23,.055,.03),Vector3(.34,2.98,.47),GOLD30)
	_prism30(chest,PackedVector2Array([Vector2(-.47,3.08),Vector2(-.24,3.08),Vector2(-.26,2.88),Vector2(-.355,2.82)]),.47,.035,GOLD30)
	_box30(chest,Vector3(.055,.09,.016),Vector3(-.355,2.97,.493),Color(.075,.11,.16))
	for y: float in [2.23,2.45,2.66]:_box30(chest,Vector3(.032,.032,.024),Vector3(.025,y,.46),GOLD30)
	_attach30(rig,"chest","PoliceUniform30",chest)
	var belt: Array=[]
	_box30(belt,Vector3(1.13,.105,.075),Vector3(0,1.96,.35),DARK30)
	_box30(belt,Vector3(1.13,.105,.075),Vector3(0,1.96,-.30),DARK30)
	for side: float in [-1.0,1.0]:_box30(belt,Vector3(.08,.105,.65),Vector3(side*.575,1.96,.025),DARK30)
	_box30(belt,Vector3(.17,.11,.025),Vector3(0,1.96,.403),GOLD30)
	_box30(belt,Vector3(.095,.06,.012),Vector3(0,1.96,.421),DARK30)
	_box30(belt,Vector3(.14,.23,.12),Vector3(.48,1.87,.38),DARK30)
	_attach30(rig,"pelvis","PoliceBelt30",belt)
	var cap: Array=[]
	_cylinder30(cap,.62,.63,.12,Vector3(0,4.55,0),Vector3(1,1,.90),DARK30)
	_cylinder30(cap,.66,.72,.29,Vector3(0,4.755,-.025),Vector3(1,1,.90),uniform)
	_cylinder30(cap,.72,.67,.045,Vector3(0,4.922,-.025),Vector3(1,1,.90),uniform*1.12)
	# Low-poly tapered visor projects forward from the black cap band.
	_box30(cap,Vector3(.91,.045,.46),Vector3(0,4.50,.61),DARK30)
	_box30(cap,Vector3(.74,.044,.11),Vector3(0,4.50,.86),DARK30)
	_box30(cap,Vector3(.60,.022,.023),Vector3(0,4.58,.573),GOLD30)
	_box30(cap,Vector3(.13,.16,.03),Vector3(0,4.71,.624),GOLD30)
	_box30(cap,Vector3(.055,.065,.015),Vector3(0,4.71,.647),Color(.075,.11,.16))
	_attach30(rig,"head","PoliceCap30",cap)
	var receipt: Dictionary={"ok":true,"variant":variant,"recolored_vertices":changed,"native_vertex_buffers_preserved":true,"hidden_hair_meshes":hidden,"new_render_meshes":3,"new_bone_attachments":3,"new_colliders":0,"new_behaviour":false}
	rig.set_meta("police_style30",receipt.duplicate(true));return receipt

static func _attach30(rig: Skeleton3D,bone: String,label: String,parts: Array) -> void:
	var index: int=rig.find_bone(bone)
	var attachment:=BoneAttachment3D.new();attachment.name=label+"Anchor";attachment.bone_name=bone;rig.add_child(attachment)
	var mesh: MeshInstance3D=_batch30(parts);mesh.name=label;attachment.add_child(mesh)
	mesh.transform=rig.get_bone_global_pose(index).affine_inverse()
	mesh.set_meta("police_uniform30",true)

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
