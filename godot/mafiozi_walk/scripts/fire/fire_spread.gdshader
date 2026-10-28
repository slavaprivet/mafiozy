shader_type spatial;
// The walk-build fire: a baked flame sprite on additive billboards. The web
// prototype drew this exact 128x192 flame on a canvas for burning cars, and the
// sprite reads as fire far better than procedural gradients ever did.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform sampler2D flame_texture : source_color, filter_linear, repeat_disable;
uniform float age_seconds = 0.0;
uniform float lifetime_seconds = 12.0;
uniform float intensity = 1.0;
uniform float field_scale = 2.4;
uniform vec2 wind = vec2(0.30, 0.10);

varying float kind;
varying float seed;
varying float variant;
varying float age;

void vertex() {
	kind = INSTANCE_CUSTOM.g;
	seed = INSTANCE_CUSTOM.r;
	variant = INSTANCE_CUSTOM.b;
	age = age_seconds;

	float angle = seed * TAU;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	float scale = field_scale * (0.55 + 0.45 * intensity);

	if (kind < 0.5) {
		// A tongue of fire: the sprite is tall and narrow, and each one leans and
		// breathes at its own rate so the field never pulses as one sheet.
		float tall = pow(variant, 1.5);
		float reach = 0.70 + tall * 0.85;
		float lean = sin(TIME * (4.0 + variant * 3.5) + angle * 2.0) * 0.10;
		center.xz += vec2(cos(angle), sin(angle)) * 0.55 * variant * scale;
		center.y += variant * 0.45 * scale;
		center.xz += vec2(lean, lean * 0.4) * scale + wind * age_seconds * 0.18;
		float wobble = 0.85 + 0.15 * sin(TIME * 8.0 + seed * 23.0);
		vec2 size = vec2((0.34 + variant * 0.22) * scale * wobble, reach * scale * wobble);
		vec3 world = center + right * VERTEX.x * size.x + up * (VERTEX.y + 0.5) * size.y;
		VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	} else {
		// Embers: small hot specks thrown out of the fire and pulled down.
		float flight = min(age_seconds, 0.7);
		center += vec3(cos(angle) * (1.6 + variant), 1.6 + variant * 1.8, sin(angle) * (1.6 + variant))
			* flight * scale * 0.5;
		center.y -= 3.2 * flight * flight * scale * 0.4;
		vec2 size = vec2(0.05, 0.05);
		vec3 world = center + right * VERTEX.x * size.x + up * VERTEX.y * size.y;
		VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float fade = clamp(1.0 - age_seconds / lifetime_seconds, 0.0, 1.0);
	if (kind < 0.5) {
		// The canvas texture is drawn top-down; the quad's UV starts at the bottom.
		vec2 uv = vec2(UV.x, 1.0 - UV.y);
		vec4 tex = texture(flame_texture, uv);
		// Warmer cores on some tongues, deeper red on others: one sprite, many fires.
		vec3 tint = mix(vec3(1.0, 0.86, 0.62), vec3(1.0, 0.62, 0.28), variant);
		ALBEDO = tex.rgb * tint;
		EMISSION = tex.rgb * tint * 1.35;
		ALPHA = tex.a * fade * (0.55 + 0.45 * intensity);
	} else {
		ALBEDO = mix(vec3(1.00, 0.52, 0.10), vec3(1.00, 0.88, 0.55), step(0.55, seed));
		EMISSION = ALBEDO * 1.6;
		ALPHA = 1.0 - smoothstep(0.15, 0.70, age_seconds);
	}
}
