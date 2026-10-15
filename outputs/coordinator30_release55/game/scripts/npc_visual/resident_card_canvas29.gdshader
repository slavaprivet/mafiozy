shader_type canvas_item;
uniform float health : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec2 pixel = UV * vec2(768.0, 192.0);
	float inset = min(min(pixel.x - 8.0, 760.0 - pixel.x), min(pixel.y - 8.0, 184.0 - pixel.y));
	float coverage = smoothstep(0.0, 1.0, inset);
	float border = 1.0 - smoothstep(9.0, 10.0, inset);
	float missing = smoothstep(health - .045, health + .045, UV.x);
	missing *= 1.0 - smoothstep(.997, 1.0, health);
	missing = mix(1.0, missing, smoothstep(0.0, .003, health));
	vec3 dark = mix(vec3(.018, .037, .053), vec3(.035, .068, .076), UV.y);
	vec3 light = mix(vec3(.19, .29, .29), vec3(.28, .38, .36), UV.y);
	float divider = (1.0 - smoothstep(2.0, 3.0, abs(pixel.y - 96.0))) * step(30.0, pixel.x) * step(pixel.x, 738.0);
	COLOR = vec4(mix(mix(dark, light, missing), vec3(.36, .72, .54), max(border * .95, divider * .7)), coverage * .97);
}
