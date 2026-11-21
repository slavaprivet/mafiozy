extends RefCounted
const HEAD_EDGE:=Vector3(.34,.17,0)
const HEAD_BACK:=Vector3(.34,.025,0)
const HEAD_DEPTH:=.145
const MASS:=.72
static func build(host:Node,parent:Node3D)->Node3D:
	host._weapon_materials()
	var model:=Node3D.new();model.name="ThrowingHatchet32";parent.add_child(model)
	# Keep the original shaft and head envelope: the projectile samples, world
	# convex hulls and hand grip all use these authored local coordinates.
	host._add_haft(model,-.14,.36,.018,.015,host._mat_wood)
	host._add_grip(model,-.13,.04,.022)
	var socket:=MeshInstance3D.new();socket.name="IronSocket"
	var socket_mesh:=BoxMesh.new();socket_mesh.size=Vector3(.105,.07,.04)
	socket.mesh=socket_mesh
	var dark_iron:StandardMaterial3D=host._mat_iron.duplicate();dark_iron.albedo_color=Color(.31,.34,.38);dark_iron.metallic=.84;dark_iron.roughness=.39
	socket.material_override=dark_iron;socket.position=Vector3(.34,.02,0);model.add_child(socket)
	var mesh:=ArrayMesh.new()
	var verts:=PackedVector3Array([Vector3(.285,.035,-.019),Vector3(.395,.035,-.019),Vector3(.455,.17,-.0015),Vector3(.225,.17,-.0015),Vector3(.285,.035,.019),Vector3(.395,.035,.019),Vector3(.455,.17,.0015),Vector3(.225,.17,.0015)])
	# The inset stations lie on the original blade faces. They reveal a narrow
	# polished bevel without changing any edge, vertex or convex contact hull.
	var bevel_t:float=(.135-.035)/(.17-.035)
	for pair in [[0,3],[1,2],[4,7],[5,6]]:
		verts.append(verts[pair[0]].lerp(verts[pair[1]],bevel_t))
	var inds:=PackedInt32Array([0,9,1,0,8,9,8,2,9,8,3,2,4,5,11,4,11,10,10,11,6,10,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5])
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in inds:
		var polish:=smoothstep(.135,.17,verts[index].y)
		surface.set_color(Color(.32,.35,.39).lerp(Color(.58,.63,.68),polish));surface.add_vertex(verts[index])
	surface.generate_normals();surface.index();mesh=surface.commit()
	var head:=MeshInstance3D.new();head.name="ForgedCuttingBit";head.mesh=mesh
	var steel:StandardMaterial3D=host._mat_edge.duplicate();steel.set_meta("combat_sharp29",true);steel.metallic=.58;steel.roughness=.78;steel.albedo_color=Color.WHITE;steel.vertex_color_use_as_albedo=true
	head.material_override=steel;model.add_child(head)
	model.set_meta("hatchet32",true);model.set_meta("weapon_id","hatchet")
	return model
