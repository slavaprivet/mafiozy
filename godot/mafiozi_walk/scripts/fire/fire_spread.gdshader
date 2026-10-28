shader_type spatial;
// Fire that belongs to a burning THING, not to a puddle: the field is scaled to the
// object it is stuck to, so a gate leaf and a siege tower get flames that match their
// size. One MultiMesh per field, no CPU particles, no per-frame allocations.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform float age_seconds = 0.0;
uniform float lifetime_seconds = 12.0;
// 1.0 at ignition, 0.0 when the fuel is gone: the flames shrink and dim with it.
uniform float intensity = 1.0;
// Metres of flame field width. Set per ignition from the object's radius.
uniform float field_scale = 2.4;
uniform vec2 wind = vec2(0.35, 0.12);

varying float kind;      // 0 flame, 1 smoke, 2 ember
varying float seed;
varying float variant;
varying float age;

float hash(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void vertex() {
	kind = INSTANCE_CUSTOM.g;
	seed = INSTANCE_CUSTOM.r;
	variant = INSTANCE_CUSTOM.b;
	age = age_seconds;

	float angle = seed * TAU;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	float fade = clamp(1.0 - age_seconds / lifetime_seconds, 0.0, 1.0);
	float scale = field_scale * (0.55 + 0.45 * intensity);

	vec2 size;
	if (kind < 0.5) {
		// Flames: a tight hot core near the base, tall tongues above it. Two sines of
		// different speed give the flicker that a single sine never does.
		float sway = sin(TIME * (5.5 + variant * 4.0) + angle * 3.0) * 0.10
			+ sin(TIME * 13.0 + seed * 40.0) * 0.035;
		center.xz += vec2(cos(angle), sin(angle)) * (sway * scale + wind * age_seconds * 0.25);
		float reach = 0.85 + variant * 0.80;
		size = vec2((0.26 + variant * 0.22) * scale, reach * scale * (0.78 + 0.22 * intensity));
		center.y += size.y * 0.25 * (0.6 + 0.4 * sin(TIME * 7.0 + seed * 19.0));
	} else if (kind < 1.5) {
		// Smoke: rises slower than the flames, spreads as it goes, drifts downwind.
		float lift = age_seconds * (0.20 + variant * 0.16) * scale;
		center += vec3(wind.x, 1.0, wind.y) * lift;
		center.xz += vec2(cos(angle), sin(angle)) * (0.10 + age_seconds * 0.05) * scale;
		size = vec2((0.55 + age_seconds * 0.10) * scale, (0.60 + age_seconds * 0.16) * scale);
	} else {
		// Embers: thrown out, pulled down, gone in half a second.
		float flight = min(age_seconds, 0.62);
		center += vec3(cos(angle) * (1.4 + variant), 1.4 + variant * 1.6, sin(angle) * (1.4 + variant))
			* flight * scale * 0.55;
		center.y -= 3.4 * flight * flight * scale * 0.4;
		size = vec2(0.022, 0.075 + variant * 0.055);
	}

	float lift_uv = kind < 0.5 ? UV.y * 0.12 * scale : 0.0;
	vec3 world = center + right * VERTEX.x * size.x + up * (VERTEX.y * size.y + lift_uv);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Soft shoulders instead of a hard rectangle, and a wider skirt at the root so the
	// tongues overlap into one body of fire instead of reading as separate cards.
	float waist = 1.0 + (1.0 - UV.y) * 0.55;
	float radial = clamp(1.0 - abs(p.x) * (0.85 + UV.y * 0.85) / waist, 0.0, 1.0);
	radial *= radial;
	float tip = 1.0 - smoothstep(0.35, 1.0, UV.y);
	float base = smoothstep(0.0, 0.14, UV.y);
	float breakup = 0.72 + 0.28 * sin(UV.y * 21.0 + TIME * 9.0 + seed * 31.0)
		* (0.6 + 0.4 * sin(UV.y * 7.0 - TIME * 4.0));
	float fade = clamp(1.0 - age_seconds / lifetime_seconds, 0.0, 1.0);

	if (kind < 0.5) {
		// Teardrop: wide at the root, narrowing to a point, with a torn edge that
		// flickers at its own rate. The old soft blob read as a glowing jelly.
		float h = UV.y;
		float halfw = 0.46 * pow(1.0 - h, 0.62) + 0.05;
		float x = abs(UV.x * 2.0 - 1.0);
		float body = smoothstep(halfw, halfw * 0.35, x);
		float top = smoothstep(1.0, 0.62, h);
		float root_fade = smoothstep(0.0, 0.08, h);
		float lick = 0.68 + 0.32 * sin(h * 17.0 + TIME * 12.0 + seed * 23.0)
			* (0.55 + 0.45 * sin(h * 6.0 - TIME * 5.0 + seed * 9.0));
		// Black-body ladder: soot red at the root, orange body, white-yellow core.
		vec3 deep = vec3(0.46, 0.055, 0.012);
		vec3 body_col = vec3(1.00, 0.42, 0.055);
		vec3 core_col = vec3(1.00, 0.90, 0.60);
		float heat = (1.0 - h) * (0.55 + 0.45 * body);
		vec3 colour = mix(deep, body_col, smoothstep(0.0, 0.55, heat));
		colour = mix(colour, core_col, smoothstep(0.62, 1.0, heat));
		ALBEDO = colour;
		EMISSION = colour * (1.9 + heat * 2.6) * (0.6 + 0.4 * intensity);
		ALPHA = body * top * root_fade * lick * fade * (0.92 + 0.08 * intensity);
	} else if (kind < 1.5) {
		// Smoke is lit from below by its own fire at the start and greys out as it rises.
		float warm = smoothstep(0.7, 0.0, age_seconds / max(0.1, lifetime_seconds));
		ALBEDO = mix(vec3(0.10, 0.095, 0.090), vec3(0.22, 0.13, 0.08), warm * 0.6);
		EMISSION = vec3(0.030, 0.018, 0.010) * warm;
		ALPHA = radial * tip * base * smoothstep(0.0, 0.9, age_seconds) * 0.30 * fade;
	} else {
		ALBEDO = mix(vec3(1.00, 0.55, 0.12), vec3(1.00, 0.86, 0.55), step(0.6, seed));
		EMISSION = ALBEDO * 2.6;
		ALPHA = radial * (1.0 - smoothstep(0.10, 0.62, age_seconds));
	}
}
