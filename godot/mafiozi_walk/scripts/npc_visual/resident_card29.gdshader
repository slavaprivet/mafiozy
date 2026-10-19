shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform float health : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// Camera-facing card, like the two Label3D lines it contains.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	// Walk gang card: broad rectangle, substantial accent border and divider.
	vec2 pixel = UV * vec2(768.0, 192.0);
	float inset = min(min(pixel.x - 8.0, 760.0 - pixel.x), min(pixel.y - 8.0, 184.0 - pixel.y));
	float coverage = smoothstep(0.0, 1.0, inset);
	float border = 1.0 - smoothstep(9.0, 10.0, inset);
	// Health occupies the dark LEFT side, lost health lightens the right side.
	// Soft spatial edge and smoothly updated health keep the transition continuous.
	float missing = smoothstep(health - .045, health + .045, UV.x);
	missing *= 1.0 - smoothstep(.997, 1.0, health);
	missing = mix(1.0, missing, smoothstep(0.0, .003, health));
	vec3 dark = mix(vec3(.018, .037, .053), vec3(.035, .068, .076), UV.y);
	vec3 light = mix(vec3(.19, .29, .29), vec3(.28, .38, .36), UV.y);
	vec3 fill = mix(dark, light, missing);
	float divider = (1.0 - smoothstep(2.0, 3.0, abs(pixel.y - 96.0))) * step(30.0, pixel.x) * step(pixel.x, 738.0);
	ALBEDO = mix(fill, vec3(.36, .72, .54), max(border * .95, divider * .7));
	ALPHA = coverage * .96;
}
