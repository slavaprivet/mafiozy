shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float burst_age = 10.0;
uniform float burst_scale = 1.0;
void vertex() {
	VERTEX *= (0.18 + burst_age * 9.5) * burst_scale;
}
void fragment() {
	float fade = (1.0 - smoothstep(0.08, 0.48, burst_age));
	if (fade <= 0.0) { discard; }
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 4.0);
	ALBEDO = vec3(0.65, 0.45, 0.21);
	EMISSION = vec3(0.8, 0.43, 0.14) * fade;
	ALPHA = edge * fade * 0.075;
}
