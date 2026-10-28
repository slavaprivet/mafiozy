extends RefCounted
## Creates an opt-in NPC candidate only. Never installs it on a mesh.
## Native Standard/KHR BRDF and rendered HDR acceptance remain root GPU gates.
const VERTEX_FRAGMENT := """
shader_type spatial;
render_mode %s, diffuse_burley, specular_schlick_ggx;
uniform vec4 npc_albedo_factor : source_color = vec4(1.0);
uniform float npc_roughness : hint_range(0.0, 1.0) = 1.0;
uniform float npc_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float npc_specular : hint_range(0.0, 1.0) = 0.5;
varying vec4 npc_linear_color;
void vertex() {
	npc_linear_color = CUSTOM0;
}
void fragment() {
	ALBEDO = npc_linear_color.rgb * npc_albedo_factor.rgb;
	ROUGHNESS = npc_roughness;
	METALLIC = npc_metallic;
	SPECULAR = npc_specular;
}
"""

static func _hold(reason: String) -> Dictionary:
	return {"ok": false, "hold": true, "error": reason, "material_fidelity": "HOLD", "shader_active": false}

static func make_candidate(source: StandardMaterial3D) -> Dictionary:
	if source == null:
		return _hold("material_missing")
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or source.blend_mode != BaseMaterial3D.BLEND_MODE_MIX or source.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		return _hold("opaque_per_pixel_only")
	if source.diffuse_mode != BaseMaterial3D.DIFFUSE_BURLEY or source.specular_mode != BaseMaterial3D.SPECULAR_SCHLICK_GGX:
		return _hold("unsupported_native_lighting_mode")
	if source.depth_draw_mode != BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY or source.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED or source.vertex_color_is_srgb:
		return _hold("unsupported_depth_fade_or_color_space")
	if not source.vertex_color_use_as_albedo or source.next_pass != null or source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or source.grow:
		return _hold("unsupported_material_path")
	for feature in BaseMaterial3D.FEATURE_MAX:
		if source.get_feature(feature):
			return _hold("unsupported_feature_%s" % feature)
	for texture_parameter in BaseMaterial3D.TEXTURE_MAX:
		if source.get_texture(texture_parameter) != null:
			return _hold("unsupported_texture_%s" % texture_parameter)
	for flag in [BaseMaterial3D.FLAG_DONT_RECEIVE_SHADOWS, BaseMaterial3D.FLAG_DISABLE_AMBIENT_LIGHT, BaseMaterial3D.FLAG_DISABLE_FOG, BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST, BaseMaterial3D.FLAG_USE_SHADOW_TO_OPACITY, BaseMaterial3D.FLAG_FIXED_SIZE, BaseMaterial3D.FLAG_USE_POINT_SIZE, BaseMaterial3D.FLAG_PARTICLE_TRAILS_MODE, BaseMaterial3D.FLAG_USE_Z_CLIP_SCALE, BaseMaterial3D.FLAG_USE_FOV_OVERRIDE]:
		if source.get_flag(flag):
			return _hold("unsupported_render_flag_%s" % flag)
	var color := source.albedo_color
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or color.a != 1.0:
		return _hold("opaque_factor")
	for value in [source.roughness, source.metallic, source.metallic_specular]:
		if not is_finite(value) or value < 0.0 or value > 1.0:
			return _hold("pbr_factor")
	var cull_modes := {BaseMaterial3D.CULL_BACK: "cull_back", BaseMaterial3D.CULL_FRONT: "cull_front", BaseMaterial3D.CULL_DISABLED: "cull_disabled"}
	if not cull_modes.has(source.cull_mode):
		return _hold("cull_mode")
	var shader := Shader.new()
	shader.code = VERTEX_FRAGMENT % cull_modes[source.cull_mode]
	var candidate := ShaderMaterial.new()
	candidate.shader = shader
	candidate.render_priority = source.render_priority
	candidate.set_shader_parameter("npc_albedo_factor", color)
	candidate.set_shader_parameter("npc_roughness", source.roughness)
	candidate.set_shader_parameter("npc_metallic", source.metallic)
	candidate.set_shader_parameter("npc_specular", source.metallic_specular)
	candidate.set_meta("npc_float_color_candidate", true)
	candidate.set_meta("npc_material_fidelity", "HOLD")
	candidate.set_meta("npc_requires_root_gpu_admission", true)
	return {"ok": true, "candidate": candidate, "shader_active": false, "material_fidelity": "HOLD", "color_input": "CUSTOM0_RGBA_FLOAT linear; opaque alpha=1 required", "limits": "PBR parameters copied as an explicit native candidate, not proved StandardMaterial/KHR BRDF equivalence; no default installation or GPU acceptance."}
