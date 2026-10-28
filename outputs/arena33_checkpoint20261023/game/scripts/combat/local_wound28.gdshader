shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color;
uniform bool has_texture = false;
uniform float base_roughness = 0.8;
uniform float base_metallic = 0.0;
uniform bool use_vertex_color = false;
uniform bool vertex_color_is_srgb = false;
uniform vec2 base_uv_scale = vec2(1.0);
uniform vec2 base_uv_offset = vec2(0.0);
uniform int wound_count = 0;
uniform vec4 wound_origin[8];
uniform vec4 wound_u[8];
uniform vec4 wound_v[8];
uniform vec4 wound_n[8];
// Same twelve linear edge spans as the volume mesh; the ends meet at a point.
vec2 lens_sample(float x) {
	float width=(1.0-x*x)*(1.0-0.055*abs(sin(x*8.0)));
	float shift=0.035*sin(x*9.0)*(1.0-x*x);
	return clamp(vec2(-width*(1.0-0.03*sin(x*13.0))+shift,width*(1.0+0.03*sin(x*11.0))+shift),vec2(-1.0),vec2(1.0));
}
vec2 lens_edges(float x) {
	float segment=clamp((x+1.0)*6.0,0.0,12.0);
	float lower=floor(segment);
	return mix(lens_sample(lower/6.0-1.0),lens_sample(min(lower+1.0,12.0)/6.0-1.0),fract(segment));
}
void vertex() {
	// Match StandardMaterial3D's vertex-color conversion, including the
	// compatibility renderer's OUTPUT_IS_SRGB branch.
	if (vertex_color_is_srgb && !OUTPUT_IS_SRGB) {
		COLOR.rgb=mix(pow((COLOR.rgb+vec3(0.055))/1.055,vec3(2.4)),COLOR.rgb/12.92,lessThan(COLOR.rgb,vec3(0.04045)));
	}
	UV=UV*base_uv_scale+base_uv_offset;
}
void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	for (int i=0;i<8;i++) {
		if (i>=wound_count) { break; }
		vec3 d = world-wound_origin[i].xyz;
		float x = dot(d,wound_u[i].xyz);
		float y = dot(d,wound_v[i].xyz);
		float z = dot(d,wound_n[i].xyz);
		if (abs(x)<wound_u[i].w && z<0.006 && z>-wound_n[i].w-0.002) {
			if (wound_origin[i].w>0.5) {
				vec2 ellipse=vec2(x/wound_u[i].w,y/wound_v[i].w);
				if (dot(ellipse,ellipse)<1.0) { discard; }
				continue;
			}
			vec2 edge=lens_edges(x/wound_u[i].w)*wound_v[i].w;
			if (y>edge.x && y<edge.y) { discard; }
		}
	}
	vec4 color=base_color;
	if (has_texture) { color*=texture(base_texture,UV); }
	if (use_vertex_color) { color*=COLOR; }
	ALBEDO=color.rgb;
	ROUGHNESS=base_roughness;
	METALLIC=base_metallic;
}
