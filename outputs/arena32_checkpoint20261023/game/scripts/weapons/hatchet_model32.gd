extends RefCounted
const HEAD_EDGE:=Vector3(.34,.17,0)
const HEAD_BACK:=Vector3(.34,.025,0)
const HEAD_DEPTH:=.145
const MASS:=.72
static func build(host:Node,parent:Node3D)->Node3D:
	host._weapon_materials()
	var model:=Node3D.new();model.name="ThrowingHatchet32";parent.add_child(model)
	var wood:StandardMaterial3D=host._mat_wood.duplicate();wood.albedo_color=Color(.34,.16,.065);wood.roughness=.86
	host._add_haft(model,-.14,.36,.018,.015,wood)
	host._add_grip(model,-.13,.04,.022)
	var socket:=MeshInstance3D.new();socket.name="IronSocket"
	var box:=BoxMesh.new();box.size=Vector3(.105,.07,.04)
	socket.mesh=box;socket.material_override=host._mat_iron;socket.position=Vector3(.34,.02,0);model.add_child(socket)
	var mesh:=ArrayMesh.new()
	var verts:=PackedVector3Array([Vector3(.285,.035,-.019),Vector3(.395,.035,-.019),Vector3(.455,.17,-.0015),Vector3(.225,.17,-.0015),Vector3(.285,.035,.019),Vector3(.395,.035,.019),Vector3(.455,.17,.0015),Vector3(.225,.17,.0015)])
	var inds:=PackedInt32Array([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5])
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in inds:
		var polish:=smoothstep(.09,.17,verts[index].y)
		surface.set_color(Color(.36,.39,.43).lerp(Color(.88,.91,.94),polish));surface.add_vertex(verts[index])
	surface.generate_normals();surface.index();mesh=surface.commit()
	var head:=MeshInstance3D.new();head.name="ForgedCuttingBit";head.mesh=mesh
	var steel:StandardMaterial3D=host._mat_edge.duplicate();steel.set_meta("combat_sharp29",true);steel.roughness=.55;steel.albedo_color=Color.WHITE;steel.vertex_color_use_as_albedo=true
	head.material_override=steel;model.add_child(head)
	model.set_meta("hatchet32",true);model.set_meta("weapon_id","hatchet")
	return model
