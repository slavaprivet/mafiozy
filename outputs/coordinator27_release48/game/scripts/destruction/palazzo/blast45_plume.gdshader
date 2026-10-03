shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

// Fixed prewarmed instances, analytic trajectories: no per-particle CPU update.
uniform sampler2D plume_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float burst_age = 10.0;
uniform float burst_scale = 1.0;
uniform float burst_seed = 0.0;
uniform vec3 blast_normal = vec3(0.0, 1.0, 0.0);
varying float kind;
varying float phase;
varying float live;
varying float seed;
varying float view_depth;
varying vec3 fire_center_view;
varying float fire_radius;

void vertex() {
	kind = INSTANCE_CUSTOM.g;
	seed = fract(INSTANCE_CUSTOM.r + burst_seed);
	float variant = INSTANCE_CUSTOM.a;
	float delay = INSTANCE_CUSTOM.b;
	float t = max(0.0, burst_age - delay);
	float angle = seed * TAU;
	vec3 radial = vec3(cos(angle), 0.0, sin(angle));
	vec3 offset = vec3(0.0);
	vec2 size = vec2(1.0);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	float duration = 1.0;
	if (kind < 0.5) { // Compact 3D combustion lobes, early expansion then cooling.
        duration = 0.68 + variant * 0.42;
        phase = clamp(t / duration, 0.0, 1.0);
        float push = 1.0 - exp(-t * 11.0);
        offset = radial * push * (0.26 + variant * 1.08) + blast_normal * push * 0.24;
        offset.x += sin(seed * 17.0) * push * 0.16;
        offset.y += 0.12 + push * (0.16 + seed * 0.23) + t * (0.45 + variant * 0.82);
        size = vec2(0.32 + push * (1.50 + variant * 0.55));
	} else if (kind < 1.5) { // Dark billowing smoke remains after the fire.
		duration = 3.25 + variant * 1.05;
		phase = clamp(t / duration, 0.0, 1.0);
		float cluster = floor(variant * 3.0);
		float push = 1.0 - exp(-t * 3.0);
		offset = radial * (0.18 + push * (0.35 + seed * 0.95) + t * (0.10 + variant * 0.11));
		offset += blast_normal * min(t, 0.8) * 0.30;
		offset.x += t * (0.12 + seed * 0.18);
		offset.y += 0.14 + seed * 0.34 + t * (0.48 + variant * 0.62 + cluster * 0.14);
		size = vec2(0.38 + sqrt(t) * (0.70 + variant * 0.59));
		size.y *= 0.94 + seed * 0.78;
		float tilt = (seed - 0.5) * 1.1;
		vec3 tilted_right = right * cos(tilt) + up * sin(tilt);
		up = up * cos(tilt) - right * sin(tilt); right = tilted_right;
		offset *= 1.30; size *= 1.30;
	} else if (kind < 2.5) { // Low outward pressure/dust, separate from smoke.
		duration = 1.55 + variant * 0.75;
		phase = clamp(t / duration, 0.0, 1.0);
		float push = 1.0 - exp(-t * 2.5);
		offset = radial * push * (1.75 + variant * 1.0);
		offset.y = t * (0.11 + variant * 0.20);
		size = vec2(0.35 + push * 1.8, 0.28 + push * 0.78);
	} else if (kind < 3.5) { // Ballistic ember ribbons, bounded by 2.0 seconds.
		duration = 0.75 + variant * 1.15;
		phase = clamp(t / duration, 0.0, 1.0);
		vec3 velocity = radial * (2.1 + variant * 2.7) + vec3(0.0, 2.0 + variant * 3.1, 0.0) + blast_normal * 0.8;
		offset = velocity * t + vec3(0.0, -2.8 * t * t, 0.0);
		vec3 tangent = velocity + vec3(0.0, -5.6 * t, 0.0);
		vec2 screen_velocity = vec2(dot(tangent, right), dot(tangent, up));
		vec2 along = normalize(screen_velocity + vec2(0.0001));
		vec3 ribbon_up = right * along.x + up * along.y;
		right = right * along.y - up * along.x;
		up = ribbon_up;
		size = vec2(0.016 + variant * 0.025, 0.075 + length(tangent) * 0.035);
	} else { // Very brief white-hot pressure flash, no lingering bright sphere.
		duration = 0.10;
		phase = clamp(t / duration, 0.0, 1.0);
		offset = blast_normal * 0.10;
		size = vec2(0.34 + pow(phase, 0.36) * 2.4);
	}
	live = step(delay, burst_age) * (1.0 - step(duration, t));
	vec3 center = MODEL_MATRIX[3].xyz + offset * burst_scale;
	vec3 world = center + (right * VERTEX.x * size.x + up * VERTEX.y * size.y) * burst_scale;
    fire_center_view = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
    fire_radius = size.x * burst_scale * 0.5;
    VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
    if (kind < 0.5) {
        // Exact tangent bounds avoid shrinking or sliding a sphere off-axis.
        // The proxy stays before its volume; rays clip to actual scene depth.
        float d = -fire_center_view.z;
        vec4 near_point = INV_PROJECTION_MATRIX * vec4(0.0, 0.0, 1.0, 1.0);
        float near_distance = max(0.001, -near_point.z / near_point.w);
        if (d > fire_radius + near_distance) {
            float denominator = d * d - fire_radius * fire_radius;
            vec2 middle = fire_center_view.xy * d / denominator;
            vec2 extent = fire_radius * sqrt(max(vec2(0.0), fire_center_view.xy * fire_center_view.xy + vec2(denominator))) / denominator;
            float proxy_depth = max(near_distance * 1.01, d - fire_radius);
            VERTEX = vec3((middle + vec2(UV.x - 0.5, 0.5 - UV.y) * extent * 2.0) * proxy_depth, -proxy_depth);
        } else {
            // Camera intersects the lobe: a bounded full-screen proxy avoids
            // exploding projection or a near-plane hole; the sphere test clips.
            vec4 near_corner = INV_PROJECTION_MATRIX * vec4(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0, 1.0, 1.0);
            VERTEX = near_corner.xyz / near_corner.w * 1.01;
        }
    }
	NORMAL = vec3(0.0, 0.0, 1.0);
	view_depth = -VERTEX.z;
}


// Two filtered samples interpolate a stationary 3D field from the existing
// prewarmed periodic texture. World-oriented coordinates prevent camera-facing
// flame wallpaper. Exactly six integration steps, no unbounded raymarch.
float volume_noise(vec3 q) {
    float slice = floor(q.z);
    float blend = fract(q.z);
    blend = blend * blend * (3.0 - 2.0 * blend);
    vec2 uv0 = q.xy * 0.23 + vec2(slice * 0.173, slice * 0.317);
    vec2 uv1 = q.xy * 0.23 + vec2((slice + 1.0) * 0.173, (slice + 1.0) * 0.317);
    return mix(texture(plume_noise, uv0).r, texture(plume_noise, uv1).r, blend);
}

vec4 integrated_fire(vec3 ray, float opaque_distance, float jitter, mat3 world_from_view) {
    float projection = dot(ray, fire_center_view);
    float discriminant = projection * projection - dot(fire_center_view, fire_center_view) + fire_radius * fire_radius;
    if (discriminant <= 0.0) { return vec4(0.0); }
    float root = sqrt(discriminant);
    float begin = max(0.005, projection - root);
    float end = min(projection + root, opaque_distance);
    if (end <= begin) { return vec4(0.0); }
    float step_length = (end - begin) / 6.0;
    float opacity = 0.0;
    vec3 radiance = vec3(0.0);
    float ignition = smoothstep(0.0, 0.045, phase);
    float cooling = smoothstep(0.23, 0.98, phase);
    float dying = 1.0 - smoothstep(0.67, 1.0, phase);
    for (int sample_index = 0; sample_index < 6; sample_index++) {
        float distance_along_ray = begin + (float(sample_index) + 0.25 + jitter * 0.5) * step_length;
        vec3 local = world_from_view * (ray * distance_along_ray - fire_center_view) / fire_radius;
        vec3 flow = local * 2.65 + vec3(seed * 13.7, -burst_age * (1.7 + seed), seed * 7.9);
        // Curl-like analytic domain deformation; no additional texture or loop.
        flow.xz += vec2(sin(local.y * 2.4 + phase * 3.1 + seed * 9.0), cos(local.y * 2.1 - phase * 2.7 + seed * 7.0)) * 0.34;
        float noise_value = volume_noise(flow);
        float shell = 1.0 - dot(local, local);
        float density = smoothstep(0.03, 0.58, shell + (noise_value - 0.5) * 1.85) * ignition * dying;
        float temperature = clamp(shell * 0.38 + noise_value * 1.20 - 0.18 - cooling * 0.43, 0.0, 1.0);
        vec3 c = mix(vec3(0.075, 0.024, 0.012), vec3(0.64, 0.075, 0.006), smoothstep(0.13, 0.46, temperature));
        c = mix(c, vec3(1.0, 0.34, 0.025), smoothstep(0.44, 0.77, temperature));
        c = mix(c, vec3(1.0, 0.76, 0.25), smoothstep(0.76, 1.0, temperature));
        // Only the first flash can approach white; later cores retain detail.
        c = mix(c, vec3(1.0, 0.94, 0.73), smoothstep(0.90, 1.0, temperature) * (1.0 - smoothstep(0.04, 0.13, burst_age)));
        float shaded = 0.72 + 0.28 * clamp(dot(normalize(local + vec3(0.001)), normalize(vec3(-0.4, 0.8, 0.3))) * 0.5 + 0.5, 0.0, 1.0);
        c *= shaded * (0.62 + temperature * 0.80);
        c = mix(c, vec3(0.045, 0.034, 0.026) * shaded, cooling * (1.0 - temperature) * 0.55);
        float sample_alpha = (1.0 - exp(-density * step_length / fire_radius * 2.65));
        // Soften intersections in volume space, never turn depth testing off.
        sample_alpha *= clamp((opaque_distance - distance_along_ray) / 0.18, 0.0, 1.0);
        radiance += (1.0 - opacity) * sample_alpha * c;
        opacity += (1.0 - opacity) * sample_alpha;
    }
    return vec4(radiance / max(opacity, 0.0001), opacity);
}

void fragment() {
	if (live < 0.5) { discard; }
    float raw_depth = texture(depth_texture, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
    if (CLIP_SPACE_FAR < -0.5) { ndc.z = raw_depth * 2.0 - 1.0; }
    vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    float scene_depth = -scene.z / scene.w;
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float alpha = 0.0;
	vec3 color = vec3(0.0);
	vec3 emission = vec3(0.0);
    if (kind < 0.5) {
        vec3 ray = normalize(VERTEX);
        float jitter = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233)) + seed * 61.7) * 43758.5453);
        vec4 fire = integrated_fire(ray, scene_depth / max(0.001, -ray.z), jitter, mat3(INV_VIEW_MATRIX));
        alpha = fire.a;
        color = fire.rgb;
        emission = fire.rgb * 0.32;
    } else if (kind > 3.5) {
		alpha = pow(max(0.0, 1.0 - radius), 2.0) * (1.0 - phase) * 0.94;
		color = vec3(1.0, 0.84, 0.48);
		emission = vec3(7.0, 4.6, 1.7) * (1.0 - phase);
	} else if (kind > 2.5) {
		alpha = (1.0 - smoothstep(0.35, 1.0, abs(p.x))) * (1.0 - smoothstep(0.2, 1.0, abs(p.y))) * (1.0 - phase);
		color = vec3(1.0, 0.42, 0.06);
		emission = vec3(3.3, 1.25, 0.12) * (1.0 - phase * 0.8);
	} else {
		vec2 flow = vec2(seed * 5.7, -burst_age * (0.22 + seed * 0.11));
		float large_noise = texture(plume_noise, UV * 1.3 + flow).r;
		float fine_noise = texture(plume_noise, UV * 3.7 - flow * 0.6).r;
		float shape_radius = radius;
		if (kind > 0.5 && kind < 1.5) {
			vec2 off_center = vec2(sin(seed * 19.0), cos(seed * 11.0)) * 0.18;
			shape_radius = length((p - off_center) * vec2(0.81 + seed * 0.36, 1.0));
		}
		float density = (0.96 - shape_radius) + (large_noise - 0.5) * 0.92 + (fine_noise - 0.5) * 0.21;
		float edge = smoothstep(0.02, 0.34, density);
		if (kind < 1.5) {
            float dome = sqrt(max(0.0, 1.0 - dot(p * 0.86, p * 0.86)));
            float shade = clamp(0.20 + large_noise * 0.37 + dome * 0.24 - p.y * 0.14, 0.0, 1.0);
			color = mix(vec3(0.024, 0.023, 0.021), vec3(0.23, 0.215, 0.19), shade);
			emission = vec3(0.28, 0.07, 0.011) * max(0.0, 1.0 - burst_age * 1.5) * edge;
			alpha = edge * smoothstep(0.0, 0.09, phase) * (1.0 - smoothstep(0.46, 1.0, phase)) * 0.62;
		} else {
			color = mix(vec3(0.20, 0.17, 0.13), vec3(0.47, 0.40, 0.29), large_noise);
			alpha = edge * smoothstep(0.0, 0.05, phase) * (1.0 - smoothstep(0.30, 1.0, phase)) * 0.30;
		}
	}
	// Opaque surfaces soften the card intersection. This never disables depth test.
	if (kind > 0.5) { alpha *= clamp((scene_depth - view_depth) / 0.22, 0.0, 1.0); }
	if (alpha < 0.003) { discard; }
	ALBEDO = color;
	EMISSION = emission;
	ALPHA = alpha;
}
