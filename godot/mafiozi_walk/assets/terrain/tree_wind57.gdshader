shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform float wind_strength = 0.085;

void vertex() {
	float phase = INSTANCE_CUSTOM.b * 6.2831853;
	float tree_wind = wind_strength * mix(0.72, 1.05, INSTANCE_CUSTOM.a);
	float crown = smoothstep(-0.8, 1.9, VERTEX.y);
	float broad = sin(TIME * 1.12 + phase + VERTEX.y * 0.63);
	float detail = sin(TIME * 2.03 + phase * 1.71 + VERTEX.x * 0.51);
	VERTEX.x += (broad + detail * 0.28) * tree_wind * crown;
	VERTEX.z += sin(TIME * 0.84 + phase + VERTEX.z * 0.57) * tree_wind * 0.58 * crown;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.88;
	AO = 0.84;
}
