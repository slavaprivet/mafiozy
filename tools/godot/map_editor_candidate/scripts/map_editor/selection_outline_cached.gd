extends MeshInstance3D
## One shared unit wireframe per outline; bounds edits only change transform.
var geometry_builds := 0
func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.78, 0.15)
	material.no_depth_test = true
	material_override = material
	var wire := ImmediateMesh.new()
	wire.surface_begin(Mesh.PRIMITIVE_LINES)
	for corner in range(8):
		var a := Vector3(1 if corner & 1 else 0, 1 if corner & 2 else 0, 1 if corner & 4 else 0)
		for bit in [1, 2, 4]:
			if corner & bit: continue
			var next: int = corner | bit
			wire.surface_add_vertex(a)
			wire.surface_add_vertex(Vector3(1 if next & 1 else 0, 1 if next & 2 else 0, 1 if next & 4 else 0))
	wire.surface_end()
	mesh = wire
	geometry_builds += 1
	visible = false
func show_bounds(box: Variant) -> void:
	if not box is AABB:
		visible = false
		return
	transform = Transform3D(Basis.IDENTITY.scaled(box.size), box.position)
	visible = true
