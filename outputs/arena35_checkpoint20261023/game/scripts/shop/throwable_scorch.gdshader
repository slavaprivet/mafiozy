shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age_seconds = 10.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ragged = 0.04 * sin(atan(p.y,p.x) * 17.0) + 0.025 * sin(atan(p.y,p.x) * 29.0);
	float pool = 1.0 - smoothstep(0.68 + ragged, 1.0 + ragged, r);
	float core = 1.0 - smoothstep(0.04, 0.63, r);
	float ending = 1.0 - smoothstep(5.1, 6.0, age_seconds);
	ALBEDO = vec3(0.14, 0.035, 0.012);
	EMISSION = vec3(0.95, 0.16, 0.015) * core * ending * (0.8 + 0.2 * sin(TIME * 8.0));
	ALPHA = pool * (0.28 + core * 0.30) * ending;
}
