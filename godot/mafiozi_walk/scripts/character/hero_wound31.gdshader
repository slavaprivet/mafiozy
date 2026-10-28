shader_type spatial;
render_mode cull_disabled;
uniform int wound_count = 0;
uniform vec4 wound_center[8];
uniform vec4 wound_axis[8];
uniform vec4 wound_normal[8];
varying vec3 bind_position;

void vertex() { bind_position = vec3(UV,UV2.x); }
void fragment() {
 ALBEDO = COLOR.rgb;
 ROUGHNESS = 0.88;
 for (int i=0; i<8; i++) {
  if (i >= wound_count) { break; }
  vec3 d = bind_position - wound_center[i].xyz;
  vec3 n = wound_normal[i].xyz;
  vec3 t = wound_axis[i].xyz;
  vec3 b = normalize(cross(n,t));
  float x = dot(d,t) / wound_center[i].w;
  float y = dot(d,b) / wound_axis[i].w;
  float r = length(vec2(x,y));
  float depth = abs(dot(d,n)) / max(wound_normal[i].w,0.001);
  float facing = smoothstep(0.2,0.6,abs(dot(normalize(cross(dFdx(bind_position),dFdy(bind_position))),n)));
  float stain = facing*(1.0-smoothstep(0.65,1.0,r))*(1.0-smoothstep(0.5,1.0,depth));
  float slit = (1.0-smoothstep(0.12,0.3,abs(y)))*(1.0-smoothstep(0.65,0.86,abs(x)))*stain;
  ALBEDO = mix(ALBEDO,vec3(0.23,0.025,0.027),stain*0.86);
  ALBEDO = mix(ALBEDO,vec3(0.075,0.008,0.012),slit);
  ROUGHNESS = mix(ROUGHNESS,0.46,stain);
 }
}
