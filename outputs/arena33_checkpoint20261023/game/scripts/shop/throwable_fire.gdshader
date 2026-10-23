shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform float age_seconds = 10.0;
uniform float lifetime_seconds = 6.0;
varying float particle_kind;
varying float particle_seed;
varying float particle_age;

void vertex() {
	particle_kind = INSTANCE_CUSTOM.g;
	particle_seed = INSTANCE_CUSTOM.r;
	particle_age = age_seconds;
	float variant = INSTANCE_CUSTOM.b;
	float angle = particle_seed * TAU;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	float life = clamp(1.0 - age_seconds / lifetime_seconds, 0.0, 1.0);
	vec2 size = vec2(0.38 + variant * 0.30, 0.65 + variant * 0.80);
	if (particle_kind < 0.5) {
		// Rising tongues bend and pulse, but the whole pool needs no CPU particles.
		float sway = sin(TIME * (6.0 + variant * 3.0) + angle) * 0.13;
		center.xz += vec2(cos(angle), sin(angle)) * sway;
		size *= 0.82 + 0.18 * sin(TIME * 9.0 + angle);
	} else if (particle_kind < 1.5) {
		float drift = age_seconds * (0.13 + variant * 0.11);
		center += vec3(drift, age_seconds * (0.23 + variant * 0.14), -drift * 0.45);
		size = vec2(0.55 + age_seconds * 0.11, 0.65 + age_seconds * 0.19);
	} else {
		float flight = min(age_seconds, 0.58);
		center += vec3(cos(angle), 0.8 + variant, sin(angle)) * flight * (2.0 + variant * 2.0);
		center.y -= 2.3 * flight * flight;
		size = vec2(0.025, 0.09 + variant * 0.07);
	}
	float lift = particle_kind < 0.5 ? UV.y * (0.16 + 0.10 * sin(TIME * 7.0 + angle)) : 0.0;
	vec3 world = center + right * VERTEX.x * size.x + up * (VERTEX.y * size.y + lift);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radial = clamp(1.0 - abs(p.x) * (0.95 + UV.y * 0.95), 0.0, 1.0);
	float tip = 1.0 - smoothstep(0.44, 1.0, UV.y);
	float base = smoothstep(0.0, 0.16, UV.y);
	float breakup = 0.80 + 0.20 * sin(UV.y * 19.0 + TIME * 8.0 + particle_seed * 30.0);
	float end_fade = 1.0 - smoothstep(lifetime_seconds - 0.9, lifetime_seconds, particle_age);
	if (particle_kind < 0.5) {
		float hot = 1.0 - UV.y;
		ALBEDO = mix(vec3(0.48, 0.035, 0.005), vec3(1.0, 0.75, 0.16), pow(hot, 1.35));
		EMISSION = ALBEDO * (1.4 + hot * 1.7);
		ALPHA = radial * tip * base * breakup * end_fade * 0.79;
	} else if (particle_kind < 1.5) {
		ALBEDO = vec3(0.12, 0.115, 0.105);
		EMISSION = vec3(0.025, 0.017, 0.010);
		ALPHA = radial * tip * base * end_fade * smoothstep(0.1, 1.0, particle_age) * 0.23;
	} else {
		// Pale glints read as bottle fragments; warm trails are burning drops.
		ALBEDO = mix(vec3(0.88, 0.81, 0.67), vec3(1.0, 0.44, 0.08), step(0.5, particle_seed));
		EMISSION = ALBEDO * (1.3 + 1.4 * step(0.5, particle_seed));
		ALPHA = radial * tip * base * (1.0 - smoothstep(0.12, 0.58, particle_age));
	}
}
