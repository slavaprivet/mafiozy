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

// Derivative relief follows the real cap surface and its existing skinning.
// This changes lighting only; the wound stays on the exact committed plane.
vec3 tissue_normal(vec3 base, vec3 position, float height) {
 vec3 dx=dFdx(position);
 vec3 dy=dFdy(position);
 vec3 r1=cross(dy,base);
 vec3 r2=cross(base,dx);
 float determinant=dot(dx,r1);
 if (abs(determinant)<0.000000000001) { return base; }
 vec3 gradient=sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2);
 return normalize(abs(determinant)*base-gradient);
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
		// The garment's clipped exterior already owns its real edge. A filled
		// cap with a thin boundary mask invents contour lines across the open
		// tissue (including triangulation bridges and disconnected trim).
		// Keep its geometry/weights for cut ownership, but do not draw that
		// synthetic outline over the actual anatomical cross-section.
		discard;
	} else {
		// Broad continuous muscle bundles, with low-contrast longitudinal fibres.
		// No cellular tessellation: its hard cell colours read as polygon mosaic.
		float bend=sin(uv.y*18.0)*0.008+sin(uv.y*7.0+1.2)*0.012;
		float bundle=noise21(vec2((uv.x+bend)*41.0,uv.y*6.0)+warp*0.6);
		float strand=0.5+0.5*sin((uv.x+bend)*1150.0+sin(uv.y*41.0)*1.8);
		float broad=noise21(uv*11.0+warp*0.25);
		vec3 color=mix(vec3(0.018,0.001,0.0025),vec3(0.062,0.005,0.009),broad);
		color*=0.94+0.08*bundle+0.018*strand;
		float septum=pow(1.0-bundle,18.0);
		color=mix(color,vec3(0.15,0.060,0.052),septum*0.12);
		float relief=0.00035*bundle+0.000003*strand;
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
			vec3 soft_color = mix(vec3(0.07,0.013,0.021),vec3(0.13,0.035,0.041),fine);
			if (type>0.5) { soft_color = mix(vec3(0.032,0.002,0.008),vec3(0.09,0.008,0.018),tissue); }
			if (type>1.5) { soft_color = mix(vec3(0.045,0.005,0.004),vec3(0.10,0.017,0.012),tissue); }
			float vessel = pow(0.5+0.5*sin(q.y*29.0+sin(q.x*17.0)*2.1),18.0);
			soft_color *= 1.0-vessel*0.20;
			float capsule = smoothstep(0.93,0.98,radius)*(1.0-smoothstep(0.98,1.0,radius));
			soft_color = mix(soft_color,vec3(0.16,0.065,0.06),capsule*0.22);
			// A shaded recess separates the retained interior from muscle edges.
			float recess=clamp(1.0-radius*radius,0.0,1.0);
			soft_color*=mix(0.55,1.0,smoothstep(0.0,0.8,radius));
			relief=mix(relief,-0.006*recess+0.0003*sin(q.x*12.0+sin(q.y*9.0)),inside);
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
		color = mix(color,mix(vec3(0.065,0.020,0.009),vec3(0.20,0.085,0.025),fine),marrow);
		vec3 ivory = vec3(0.22,0.188,0.135)*(0.94+fine*0.06);
		color = mix(color,ivory,cortex);
		relief=mix(relief,0.0012,cortex);
		NORMAL=tissue_normal(normalize(NORMAL),VERTEX,relief);
		ALBEDO = color;
		ROUGHNESS = mix(mix(0.61,0.39,organ_mask),0.76,cortex);
		SPECULAR = mix(0.19,0.13,cortex);
	}
}
