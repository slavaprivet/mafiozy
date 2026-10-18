shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D trample_map : filter_linear, repeat_disable;
uniform vec3 field_origin = vec3(0.0);
uniform float wind_time = 0.0;
uniform float fade_start = 34.0;
uniform float fade_end = 46.0;
uniform vec3 actor_position = vec3(0.0,10000.0,0.0);
uniform vec3 left_foot = vec3(0.0,10000.0,0.0);
uniform vec3 left_knee = vec3(0.0,10001.0,0.0);
uniform vec3 right_foot = vec3(0.0,10000.0,0.0);
uniform vec3 right_knee = vec3(0.0,10001.0,0.0);
varying float leaf_height;
vec3 avoid_leg(vec3 point,vec3 foot,vec3 knee,float anchor) {
 vec3 axis=knee-foot;
 float t=clamp(dot(point-foot,axis)/max(dot(axis,axis),0.001),0.0,1.0);
 vec3 nearest=foot+axis*t;
 vec2 delta=point.xz-nearest.xz;
 float d=length(delta);
 float height_gate=step(foot.y-0.15,point.y)*step(point.y,knee.y+0.15);
 vec2 direction=d>0.001?delta/d:vec2(1.0,0.0);
 point.xz+=direction*max(0.0,0.28-d)*anchor*height_gate;
 return point;
}
void vertex() {
 vec3 root = MODEL_MATRIX[3].xyz;
 vec2 local = root.xz-field_origin.xz;
 vec2 uv = (local-vec2(-90.0,76.0))/vec2(180.0,176.0);
 vec3 footprint = texture(trample_map,uv).rgb;
 float pressure = footprint.r;
 vec2 direction = footprint.gb*2.0-1.0;
 direction /= max(length(direction),0.1);
 leaf_height = UV.y;
 float tip = UV.y*UV.y;
 vec3 offset = VERTEX-root;
 vec2 away = root.xz-actor_position.xz;
 float actor_distance = length(away);
 float live_pressure = (1.0-smoothstep(0.36,0.92,actor_distance)) * (1.0-smoothstep(0.65,1.35,abs(root.y-actor_position.y)));
 if(live_pressure>pressure) {
   pressure=live_pressure;
   direction=away/max(actor_distance,0.001);
 }
 // Roots stay buried. Tips bow away from the foot and retain a low profile
 // while the recorded footprint decays; no per-blade CPU updates.
 offset.y *= 1.0-pressure*0.94;
 offset.xz += direction * pressure * 0.39 * tip;
 float wave = sin(wind_time*1.6+root.x*0.41+root.z*0.27);
 offset.xz += vec2(wave,cos(wind_time*1.1+root.z*.35))*.027*tip*(1.0-pressure);
 float camera_distance=distance(CAMERA_POSITION_WORLD.xz,root.xz);
 float fade = 1.0-smoothstep(fade_start,fade_end,camera_distance);
 // Only the first quarter of each deterministic tile survives at distance.
 // CPU drops the already invisible instances once the whole tile is beyond it.
 if(INSTANCE_CUSTOM.r>0.25) fade*=1.0-smoothstep(16.0,24.0,camera_distance);
 VERTEX = root+offset*fade;
 if(actor_distance<1.7) {
   float anchor=smoothstep(0.0,0.20,UV.y);
   VERTEX=avoid_leg(VERTEX,left_foot,left_knee,anchor);
   VERTEX=avoid_leg(VERTEX,right_foot,right_knee,anchor);
 }
}
void fragment() {
 ALBEDO = COLOR.rgb * mix(0.43,1.17,leaf_height);
 ROUGHNESS = 0.94;
 BACKLIGHT = ALBEDO*0.18;
}
