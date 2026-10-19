extends MeshInstance3D
## Editor-only hint. Original materials/geometries are never touched.
func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.78, 0.15)
	material.no_depth_test = true
	material_override = material
	visible = false

func show_bounds(box: Variant) -> void:
	if not box is AABB:
		visible = false
		return
	var wire := ImmediateMesh.new()
	wire.surface_begin(Mesh.PRIMITIVE_LINES)
	# AABB corners use bit-coded X/Y/Z so each edge is emitted once.
	for corner in range(8):
		var a: Vector3 = box.position + Vector3(box.size.x if corner & 1 else 0.0, box.size.y if corner & 2 else 0.0, box.size.z if corner & 4 else 0.0)
		for bit in [1, 2, 4]:
			if corner & bit: continue
			var next: int = corner | bit
			var b: Vector3 = box.position + Vector3(box.size.x if next & 1 else 0.0, box.size.y if next & 2 else 0.0, box.size.z if next & 4 else 0.0)
			wire.surface_add_vertex(a)
			wire.surface_add_vertex(b)
	wire.surface_end()
	mesh = wire
	visible = true

