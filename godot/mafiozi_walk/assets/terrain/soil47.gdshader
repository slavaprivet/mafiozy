shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D macro_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D soil_detail : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 ground_xz;
void vertex() { ground_xz = VERTEX.xz; }
void fragment() {
 vec4 macro = texture(macro_map, UV);
 vec4 detail = texture(soil_detail, ground_xz / 3.8);
 // Rotated second scale breaks the repeating pebble/stem pattern, using the
 // same three texture fetches as the previous soil material.
 vec2 rotated = vec2(ground_xz.y,-ground_xz.x) / 6.3 + vec2(0.17,0.41);
 vec4 broad = texture(soil_detail, rotated);
 float distance_fade = 1.0-smoothstep(24.0,85.0,length(VERTEX));
 float relief = mix(0.42,1.52,detail.r) * mix(0.86,1.12,broad.r);
 relief = mix(0.96,relief,distance_fade);
 // The baked map is almost grey. Keep its ruts and scars, but make the packed
 // centre earthy and the brighter shoulders green in clear daylight. This
 // uses the existing map sample, with no new texture or draw call.
 float soil_light = dot(macro.rgb, vec3(0.2126, 0.7152, 0.0722));
 float meadow = smoothstep(5.0, 15.0, abs(ground_xz.x))
     * smoothstep(0.055, 0.17, soil_light);
 vec3 packed_soil = macro.rgb * vec3(1.28, 1.10, 0.72);
 vec3 green_shoulder = macro.rgb * vec3(0.82, 1.28, 0.68);
 ALBEDO = mix(packed_soil, green_shoulder, meadow) * relief;
 vec2 fine_slope = detail.gb*2.0-1.0;
 vec2 broad_slope = broad.gb*2.0-1.0;
 broad_slope = vec2(-broad_slope.y,broad_slope.x);
 vec2 slope = (fine_slope*0.57+broad_slope*0.16) * distance_fade;
 NORMAL = normalize(NORMAL + (VIEW_MATRIX*vec4(slope.x,0.0,slope.y,0.0)).xyz);
 ROUGHNESS = mix(0.98,0.84,macro.a);
}
