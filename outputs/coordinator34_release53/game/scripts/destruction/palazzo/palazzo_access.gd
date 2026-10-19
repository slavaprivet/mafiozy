extends RefCounted
## Real stone access over the original foundation/cornice; no player override.
static func install(site: Node3D) -> void:
	var entrance:=Node3D.new()
	entrance.name="StoneEntrance"
	site.add_child(entrance)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("c8c4af")
	material.roughness=.9
	_wedge(entrance,"OuterRamp",5.3,.09,3.34,.46,material)
	_wedge(entrance,"Threshold",3.34,.46,2.70,.46,material)
	_wedge(entrance,"InnerRamp",2.70,.46,1.85,.30,material)

static func _wedge(parent: Node3D,label: String,z_front: float,y_front: float,z_back: float,y_back: float,material: Material) -> void:
	var points:=PackedVector3Array([
		Vector3(0,0,z_front),Vector3(2,0,z_front),Vector3(2,0,z_back),Vector3(0,0,z_back),
		Vector3(0,y_front,z_front),Vector3(2,y_front,z_front),Vector3(2,y_back,z_back),Vector3(0,y_back,z_back)])
	var indices: Array[int]=[4,5,6,4,6,7,0,2,1,0,3,2,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5]
	var builder:=SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: int in range(0,indices.size(),3):
		for corner: int in [0,2,1]: builder.add_vertex(points[indices[triangle+corner]])
	builder.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=builder.commit()
	mesh.material_override=material
	var body:=StaticBody3D.new()
	body.name=label
	body.collision_layer=1
	body.collision_mask=0
	var shape:=ConvexPolygonShape3D.new()
	shape.points=points
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	body.add_child(mesh)
	parent.add_child(body)
