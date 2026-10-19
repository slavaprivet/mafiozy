shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D macro_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D soil_detail : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 ground_xz;
void vertex() { ground_xz = VERTEX.xz; }
void fragment() {
 vec4 detail = texture(soil_detail, ground_xz / 3.8);
 float patch = texture(soil_detail, ground_xz / 17.3).a;
 vec3 macro = texture(macro_map, UV).rgb;
 float relief = mix(0.48, 1.48, detail.r);
 float distance_fade = 1.0-smoothstep(24.0,85.0,length(VERTEX));
 relief = mix(0.96,relief,distance_fade);
 ALBEDO = COLOR.rgb * 0.60 * macro * relief * mix(0.82,1.12,patch);
 vec2 slope = (detail.gb*2.0-1.0) * 0.55 * distance_fade;
 NORMAL = normalize(NORMAL + (VIEW_MATRIX*vec4(slope.x,0.0,slope.y,0.0)).xyz);
 ROUGHNESS = 0.96;
}
