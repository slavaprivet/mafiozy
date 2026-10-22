extends SceneTree
const Factory = preload("res://scripts/npc_visual/npc_float_color_material.gd")
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func base() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.albedo_color = Color(0.7, 0.8, 0.9, 1.0)
	material.roughness = 0.76
	material.metallic = 0.55
	material.metallic_specular = 0.5
	return material
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var source := base()
	var original_color := source.albedo_color
	for cull in [BaseMaterial3D.CULL_BACK, BaseMaterial3D.CULL_FRONT, BaseMaterial3D.CULL_DISABLED]:
		source.cull_mode = cull
		var result := Factory.make_candidate(source)
		check(result.ok, "opaque candidate")
		if result.ok:
			check(not result.shader_active and result.material_fidelity == "HOLD", "candidate default off and unaccepted")
			check(result.candidate.get_shader_parameter("npc_albedo_factor") == source.albedo_color, "factor retained")
			for pair in [["npc_roughness", source.roughness], ["npc_metallic", source.metallic], ["npc_specular", source.metallic_specular]]:
				check(result.candidate.get_shader_parameter(pair[0]) == pair[1], "native parameter retained")
			check("CUSTOM0" in result.candidate.shader.code and not "clamp(" in result.candidate.shader.code, "float source path no clamp")
	check(source.albedo_color == original_color, "source unchanged")
	check(not Factory.make_candidate(null).ok, "missing material")
	for pair in [["transparency", 1], ["shading_mode", BaseMaterial3D.SHADING_MODE_UNSHADED], ["diffuse_mode", 1], ["specular_mode", 1], ["billboard_mode", 1]]:
		var bad := base()
		bad.set(pair[0], pair[1])
		check(not Factory.make_candidate(bad).ok, "unsupported %s" % pair[0])
	var bad := base()
	bad.vertex_color_use_as_albedo = false
	check(not Factory.make_candidate(bad).ok, "color source missing")
	bad = base()
	bad.next_pass = StandardMaterial3D.new()
	check(not Factory.make_candidate(bad).ok, "next pass")
	bad = base()
	bad.grow = true
	check(not Factory.make_candidate(bad).ok, "growth")
	bad = base()
	bad.emission_enabled = true
	check(not Factory.make_candidate(bad).ok, "emission feature")
	bad = base()
	bad.albedo_texture = GradientTexture1D.new()
	check(not Factory.make_candidate(bad).ok, "texture")
	bad = base()
	bad.albedo_color.a = 0.5
	check(not Factory.make_candidate(bad).ok, "alpha")
	for property in ["depth_draw_mode", "distance_fade_mode", "vertex_color_is_srgb"]:
		bad = base()
		bad.set(property, 1)
		check(not Factory.make_candidate(bad).ok, "unsupported %s" % property)
	for flag in [BaseMaterial3D.FLAG_FIXED_SIZE, BaseMaterial3D.FLAG_PARTICLE_TRAILS_MODE, BaseMaterial3D.FLAG_USE_FOV_OVERRIDE]:
		bad = base()
		bad.set_flag(flag, true)
		check(not Factory.make_candidate(bad).ok, "unsupported flag")
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, source)
	var candidate := Factory.make_candidate(source)
	check(candidate.ok and mesh.surface_get_material(0) == source, "factory never installs shader")
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
		for entry in manifest.entries:
			var loaded := Loader.load_file(entry, entry.bridge_id, arguments[0].get_base_dir())
			check(loaded.ok, "source appearance available")
			if not loaded.ok:
				continue
			var colored_surfaces := 0
			for instance: MeshInstance3D in loaded.meshes:
				for surface in instance.mesh.get_surface_count():
					if not instance.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
						continue
					colored_surfaces += 1
					var original: StandardMaterial3D = instance.mesh.surface_get_material(surface) as StandardMaterial3D
					var native_candidate := Factory.make_candidate(original)
					check(native_candidate.ok, "actual core material policy")
					check(instance.mesh.surface_get_material(surface) == original and original is StandardMaterial3D, "actual candidate not bound")
			check(colored_surfaces == 4, "actual four source colored core surfaces")
			loaded.visual.free()
	print("NPC_FLOAT_MATERIAL checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
