extends SceneTree
## Resource/source contract checks, not a GPU shader or visual acceptance test.

const Materials = preload("res://scripts/preview_surface_materials.gd")
var _failures: Array[String] = []
var _checks: int = 0


func _initialize() -> void:
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	var surface: Dictionary = block.surface
	var source_decor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../assets/maps/city_rebuild_v1/decor_placement.v1.json"))
	var source_environment: String = FileAccess.get_file_as_string("res://../../assets/maps/city_rebuild_v1/environment_surface_materials.mjs")
	var source_visuals: String = FileAccess.get_file_as_string("res://../../assets/maps/city_rebuild_v1/environment_visuals.mjs")
	_check(not source_environment.is_empty() and source_visuals.contains("surfaces.prepareMesh(mesh,{kind:mesh.userData.nativeTerrainKind,depthAt})"), "actual Walk replaces native material with environment layer")
	var descriptor: Dictionary = source_decor.surfaces[0].materialDescriptor
	_check(str(descriptor.id) == Materials.ASPHALT_DESCRIPTOR_ID, "actual terrain input selects clean asphalt descriptor")
	var road: StandardMaterial3D = Materials.create_base_material(surface, 0)
	var linear: Color = road.albedo_color.srgb_to_linear()
	var source_factor: Array = descriptor.baseColorFactor
	_check(_color_close(linear, Color(source_factor[0], source_factor[1], source_factor[2], source_factor[3])), "actual exported asphalt retains linear glTF factors through Godot property roundtrip")
	_check(absf(road.roughness - float(descriptor.roughnessFactor)) < 0.00001, "actual asphalt roughness retained")
	_check(absf(road.metallic - float(descriptor.metallicFactor)) < 0.00001, "actual asphalt metallic retained")
	var fallback: Dictionary = surface.duplicate(true)
	fallback.materialDescriptors = []
	_check(_color_close(Materials.create_base_material(fallback, 0).albedo_color, Color("#525a5a")), "missing descriptor uses original native palette without double conversion")
	var origins: Array[Vector3] = [Vector3.ZERO, Vector3(395.65, 0.0, 45.1), Vector3(-30.0, 7.0, -45.0)]
	for tile: int in [0, 8, 9, 14, 19]:
		var material: ShaderMaterial = Materials.create_material(surface, tile, origins[1]) as ShaderMaterial
		var kind: String = Materials.surface_kind(tile)
		var preset: Dictionary = Materials.PRESETS[kind]
		var expected_source: String = "%s:{color:'%s',roughness:%s" % [kind, preset.color, str(preset.roughness).trim_prefix("0")]
		_check(source_environment.contains(expected_source), "actual Walk preset matches port: " + kind)
		_check(_color_close(material.get_shader_parameter("walk_albedo"), Color(str(preset.color))), "source colour uniform preserved: " + kind)
		_check(absf(float(material.get_shader_parameter("source_roughness")) - float(preset.roughness)) < 0.00001, "source roughness uniform preserved: " + kind)
		_check(material.get_shader_parameter("source_origin_m").is_equal_approx(origins[1]), "source pattern coordinates retain recenter offset: " + kind)
		_check(material.get_meta("source_base_material") is StandardMaterial3D, "intermediate source material retained for provenance: " + kind)
	var road_final: ShaderMaterial = Materials.create_material(surface, 0, origins[0]) as ShaderMaterial
	var paving: ShaderMaterial = Materials.create_material(surface, 9, origins[0]) as ShaderMaterial
	_check(road_final.shader == paving.shader, "dry surfaces share one shader resource")
	var uniform_names: Array[String] = []
	for uniform: Dictionary in road_final.shader.get_shader_uniform_list():
		uniform_names.append(str(uniform.name))
	_check(uniform_names.has("walk_albedo") and uniform_names.has("surface_mode") and uniform_names.has("source_origin_m"), "Godot shader parser exposes required source uniforms")
	_check(int(road_final.get_shader_parameter("surface_mode")) == 2 and int(paving.get_shader_parameter("surface_mode")) == 3, "paving and asphalt select distinct original procedural modes")
	var second_road: ShaderMaterial = Materials.create_material(surface, 0, origins[2]) as ShaderMaterial
	second_road.set_shader_parameter("source_origin_m", Vector3.ONE)
	_check(road_final.get_shader_parameter("source_origin_m") == Vector3.ZERO, "material instance parameters do not leak between scene instances")
	var protected_road: ShaderMaterial = Materials.create_material(surface, 0, origins[0], true) as ShaderMaterial
	_check(protected_road.get_meta("source_kind") == "paving", "protected native key becomes paving in source and port")
	var protected_base: StandardMaterial3D = Materials.create_base_material(surface, 0, true)
	_check(_color_close(protected_base.albedo_color, Color("#9a9990")) and not protected_base.has_meta("source_descriptor_id"), "protected base bypasses road descriptor exactly as source")
	var bridge: StandardMaterial3D = Materials.create_base_material(surface, 19)
	_check(_color_close(bridge.albedo_color, Color("#858e89")) and not bridge.has_meta("source_descriptor_id"), "bridge base retains actual tile 19 palette")
	var water: StandardMaterial3D = Materials.create_material(surface, 16) as StandardMaterial3D
	_check(water != null and water.has_meta("migration_limit"), "unported depth/ripple water is explicitly marked")
	_check(absf(water.roughness - 0.22) < 0.00001 and absf(water.metallic - 0.14) < 0.00001, "water retains original base values")
	_check(Materials.create_base_material(surface, 99) == null, "unknown source tile fails instead of inventing terrain")
	_check(Materials.DRY_SHADER.contains("+source_origin_m") and Materials.DRY_SHADER.contains("dFdx(VERTEX)"), "world coordinates and original derivative bump retained")
	_check(not Materials.DRY_SHADER.contains("sampler2D") and not Materials.DRY_SHADER.contains("texture("), "dry surface port adds no texture sampling")
	if _failures.is_empty():
		print("PASS preview_surface_materials: %d checks; actual sources, linear colour, mode and coordinate contract. GPU compilation and LIVE still required." % _checks)
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _color_close(a: Color, b: Color) -> bool:
	return absf(a.r-b.r) < 0.00001 and absf(a.g-b.g) < 0.00001 and absf(a.b-b.b) < 0.00001 and absf(a.a-b.a) < 0.00001


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
