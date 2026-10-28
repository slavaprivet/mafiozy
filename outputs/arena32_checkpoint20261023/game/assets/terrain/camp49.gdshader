shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 surface_position;
varying vec3 surface_normal;
varying float family;
varying float grain_axis;
void vertex() {
 surface_position=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 surface_normal=NORMAL;
 family=INSTANCE_CUSTOM.r;
 grain_axis=INSTANCE_CUSTOM.g;
}
void fragment() {
 vec3 n=abs(surface_normal);
 vec2 plane=n.x>n.y && n.x>n.z?surface_position.zy:(n.y>n.z?surface_position.xz:surface_position.xy);
 vec2 wood_uv=grain_axis<0.25?vec2(plane.y,plane.x):plane;
 vec4 detail=texture(detail_map,wood_uv*vec2(2.8,0.75));
 float variation=1.0;
 METALLIC=0.0;
 ROUGHNESS=.9;
 if(family<.16) {
   variation=mix(.64,1.15,detail.r)*mix(.9,1.04,detail.b);
   ROUGHNESS=.88;
 } else if(family<.5) {
   vec4 weave=texture(detail_map,plane*1.25);
   variation=mix(.83,1.10,weave.g)*mix(.84,1.08,weave.b);
   ROUGHNESS=1.0;
 } else if(family<.84) {
   variation=mix(.75,1.12,detail.b);
   METALLIC=.66;
   ROUGHNESS=mix(.48,.75,detail.r);
 } else {
   variation=mix(.78,1.10,detail.b);
   ROUGHNESS=.96;
 }
 ALBEDO=COLOR.rgb*variation;
}
