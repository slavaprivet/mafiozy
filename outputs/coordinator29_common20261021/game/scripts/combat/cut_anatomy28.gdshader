shader_type spatial;
render_mode cull_disabled;

uniform int bone_count = 0;
uniform vec4 bone_start[32];
uniform vec4 bone_end[32];
uniform bool skull_enabled = false;
uniform vec3 skull_center;
uniform vec3 skull_axis_x;
uniform vec3 skull_axis_y;
uniform vec3 skull_axis_z;
uniform vec3 skull_radii = vec3(0.115, 0.165, 0.12);
uniform bool layer_rim = false;
uniform vec3 layer_color : source_color = vec3(0.23, 0.14, 0.07);
uniform int edge_count = 0;
uniform vec4 boundary_edges[128];
uniform int organ_count = 0;
uniform vec4 organ_centers[4];
uniform vec4 organ_radii[4];
uniform int puncture_count29 = 0;
uniform vec4 channel_origin29[8];
uniform vec4 channel_u29[8];
uniform vec4 channel_v29[8];
uniform vec4 channel_n29[8];

// Continuous bands avoid lattice-shaped islands in the tissue color.
float noise21(vec2 p) {
 return 0.5+0.22*sin(dot(p,vec2(0.71,0.93)))
  +0.16*sin(dot(p,vec2(-1.47,0.63))+1.3)
  +0.10*sin(dot(p,vec2(2.13,1.82))+2.5);
}
float segment_distance(vec3 p, vec3 a, vec3 b) {
	vec3 d = b-a;
	float t = clamp(dot(p-a,d)/max(dot(d,d),0.0000001),0.0,1.0);
	return length(p-a-d*t);
}

vec2 cell_hash(vec2 p) {
	return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

// Irregular fascicles with thin connective septa, instead of parallel stripes
// over the complete cap. Coordinates are continuous across triangle seams.
vec3 fascicles(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float first = 8.0;
	float second = 8.0;
	float seed = 0.0;
	for (int y=-1; y<=1; y++) {
		for (int x=-1; x<=1; x++) {
			vec2 offset = vec2(float(x),float(y));
			vec2 rnd = cell_hash(cell+offset);
			vec2 d = offset+vec2(0.15)+rnd*0.7-local;
			float distance2 = dot(d,d);
			if (distance2<first) { second=first;first=distance2;seed=rnd.x; }
			else if (distance2<second) { second=distance2; }
		}
	}
	return vec3(sqrt(first),sqrt(second)-sqrt(first),seed);
}

void fragment() {
	vec3 channel_world29 = (INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
	for (int i=0;i<8;i++) {
		if (i>=puncture_count29) { break; }
		vec3 d=channel_world29-channel_origin29[i].xyz;
		float z=dot(d,channel_n29[i].xyz);
		vec2 q=vec2(dot(d,channel_u29[i].xyz)/channel_u29[i].w,dot(d,channel_v29[i].xyz)/channel_v29[i].w);
		if (z<0.006 && z>-channel_n29[i].w-0.002 && dot(q,q)<1.0) { discard; }
	}
	vec2 uv = UV2;
	vec2 warp = vec2(noise21(uv*23.0),noise21(uv*19.0+vec2(7.0,3.0)));
	float tissue = noise21(uv*17.0+warp*0.8);
	float fine = noise21(uv*370.0+warp);
	if (layer_rim) {
		float distance_to_edge = 1000.0;
		for (int i=0; i<128; i++) {
			if (i>=edge_count) { break; }
			vec4 edge = boundary_edges[i];
			distance_to_edge = min(distance_to_edge,segment_distance(vec3(uv,0),vec3(edge.xy,0),vec3(edge.zw,0)));
		}
		if (distance_to_edge>0.0028) { discard; }
		ALBEDO = layer_color*(0.65+0.35*fine);
		ROUGHNESS = 0.85;
	} else {
		vec3 cells = fascicles(uv*vec2(62.0,43.0)+(warp-0.5)*0.48);
		float angle = cells.z*1.7+warp.x*0.3;
		vec2 fibre_axis = vec2(cos(angle),sin(angle));
		float fibre = 0.5+0.5*sin(dot(uv,fibre_axis)*1950.0+warp.y*8.0);
		vec3 color = mix(vec3(0.055,0.0035,0.008),vec3(0.21,0.022,0.034),tissue*0.55+cells.z*0.45);
		color *= 0.90+fibre*0.10+fine*0.04;
		float fascia = 1.0-smoothstep(0.012,0.047,cells.y);
		color = mix(color,vec3(0.33,0.18,0.14),fascia*0.16);
		float fat = smoothstep(0.78,0.95,tissue)*smoothstep(0.53,0.76,noise21(uv*109.0+warp*2.0));
		color = mix(color,vec3(0.46,0.29,0.12),fat*0.65);
		float cortex = 0.0;
		float marrow = 0.0;
		vec3 p = vec3(uv,0);
		float organ_mask = 0.0;
		for (int i=0; i<4; i++) {
			if (i>=organ_count) { break; }
			vec3 d = p-organ_centers[i].xyz;
			vec3 q = vec3(dot(d,skull_axis_x),dot(d,skull_axis_y),dot(d,skull_axis_z))/organ_radii[i].xyz;
			float radius = length(q);
			float inside = 1.0-smoothstep(0.97,1.0,radius);
			float type = organ_centers[i].w;
			vec3 soft_color = mix(vec3(0.14,0.034,0.040),vec3(0.27,0.075,0.079),fine);
			if (type>0.5) { soft_color = mix(vec3(0.055,0.003,0.011),vec3(0.17,0.014,0.022),tissue); }
			if (type>1.5) { soft_color = mix(vec3(0.075,0.008,0.006),vec3(0.16,0.021,0.014),tissue); }
			float vessel = pow(0.5+0.5*sin(q.y*29.0+sin(q.x*17.0)*2.1),18.0);
			soft_color *= 1.0-vessel*0.20;
			float capsule = smoothstep(0.93,0.98,radius)*(1.0-smoothstep(0.98,1.0,radius));
			soft_color = mix(soft_color,vec3(0.27,0.12,0.10),capsule*0.5);
			color = mix(color,soft_color,inside);
			organ_mask = max(organ_mask,inside);
		}
		for (int i=0; i<32; i++) {
			if (i>=bone_count) { break; }
			float radius = bone_start[i].w;
			float d = segment_distance(p,bone_start[i].xyz,bone_end[i].xyz);
			float outer = 1.0-smoothstep(radius-0.0007,radius+0.0007,d);
			float inner = 1.0-smoothstep(radius*0.50,radius*0.60,d);
			cortex = max(cortex,outer-inner);
			marrow = max(marrow,inner);
		}
		if (skull_enabled) {
			vec3 d = p-skull_center;
			vec3 q = vec3(dot(d,skull_axis_x),dot(d,skull_axis_y),dot(d,skull_axis_z))/skull_radii;
			float r = length(q);
			float skull = smoothstep(0.92,0.945,r)*(1.0-smoothstep(0.995,1.01,r));
			cortex = max(cortex,skull);
			float brain = 1.0-smoothstep(0.88,0.92,r);
			float fold = 0.5+0.5*sin(uv.x*140.0+sin(uv.y*110.0+warp.x*3.0)*2.2);
			color = mix(color,mix(vec3(0.20,0.095,0.10),vec3(0.36,0.19,0.18),fold*0.7+fine*0.15),brain);
		}
		color = mix(color,mix(vec3(0.17,0.045,0.012),vec3(0.40,0.19,0.035),fine),marrow);
		vec3 ivory = vec3(0.59,0.565,0.48)*(0.92+fine*0.08);
		color = mix(color,ivory,cortex);
		ALBEDO = color;
		ROUGHNESS = mix(mix(0.43,0.30,organ_mask),0.72,cortex);
		SPECULAR = mix(0.38,0.22,cortex);
	}
}
