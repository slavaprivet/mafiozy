extends RefCounted
## Walk revision 6 water formulas, with explicit source-world time/depth.
## No nodes, geometry displacement, physics, per-frame scene scans or I/O.
const RIPPLE_CAPACITY := 8
const RIPPLE_MAX_AGE := 4.5
const DEPTH_FLAGS := Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
const WATER_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert, specular_schlick_ggx;
uniform vec3 source_origin_m = vec3(0.0);
uniform bool use_vertex_depth = false;
uniform float default_depth = 2.5;

varying vec3 vEnvironmentWorld;
uniform float environmentTime;
float environmentHash(vec2 p) {
 vec3 p3=fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
 p3+=dot(p3,p3.yzx+33.33);
 return fract((p3.x+p3.y)*p3.z);
}
float environmentNoise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(environmentHash(i),environmentHash(i+vec2(1.,0.)),f.x),mix(environmentHash(i+vec2(0.,1.)),environmentHash(i+vec2(1.,1.)),f.x),f.y);
}

varying float vEnvironmentDepth;
uniform vec4 environmentShallow : source_color;
uniform vec4 environmentDeep : source_color;
uniform vec4 environmentShore : source_color;
uniform vec4 environmentRipples[8];
float environmentWaveFilter(float phase) {
 // Phase radians per pixel; disappear before the pi-radian Nyquist limit.
 return 1.0-smoothstep(.55,2.40,fwidth(phase));
}
vec3 environmentWaterWarpTerm(vec2 point,vec2 direction,float phase,float amplitude) {
 // Height-independent domain warp and its exact spatial derivatives.
 float angle=dot(point,direction)+phase;
 return vec3(sin(angle)*amplitude,cos(angle)*amplitude*direction);
}
float environmentWaterCoverage(float depth,float shoreNoise,float depthAA) {
 // Actual terrain-clipped boundary has depth zero. Fresnel/foam must never
 // restore opacity there. Noise only varies transition width inside the lake.
 float feather=.14+.09*shoreNoise+clamp(depthAA,0.0,.06);
 return smoothstep(0.0,feather,depth);
}
vec3 environmentRippleAt(vec4 event,vec2 point,float footprint) {
 if(event.w<=0.0 || event.z<0.0 || event.z>4.5) return vec3(0.0);
 vec2 delta=point-event.xy;
 float radius=.08+event.z*1.35,width=.24+event.z*.10;
 float distanceSquared=dot(delta,delta),outer=radius+width*2.6,inner=max(0.0,radius-width*2.6);
 // Cull pixels outside the thin expanding annulus before sqrt/trigonometry.
 if(distanceSquared>outer*outer || distanceSquared<inner*inner) return vec3(0.0);
 float distanceToEvent=sqrt(max(distanceSquared,.000001)),travel=distanceToEvent-radius;
 float envelope=(1.0-smoothstep(width,width*2.6,abs(travel)))*(1.0-smoothstep(.15,4.5,event.z))/(1.0+distanceToEvent*.45);
 float filtered=1.0-smoothstep(.55,2.40,footprint*12.0);
 float phase=travel*12.0,amplitude=envelope*event.w*filtered;
 return vec3(delta/max(distanceToEvent,.001)*cos(phase)*amplitude*.065,(.5+.5*sin(phase))*amplitude*.026);
}

void vertex() {
 vEnvironmentWorld=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+source_origin_m;
 vEnvironmentDepth=max(0.0,use_vertex_depth ? CUSTOM0.x : default_depth);
}
void fragment() {
   float environmentDepth=max(0.0,vEnvironmentDepth);
   float environmentAbsorption=1.0-exp(-environmentDepth*.56);
   vec2 environmentWaterXZ=vEnvironmentWorld.xz;
   vec2 environmentFlow=vec2(environmentTime*.065,-environmentTime*.044);
   vec3 environmentWarpA=environmentWaterWarpTerm(environmentWaterXZ,vec2(.13,.08),environmentTime*.11,1.6);
   vec3 environmentWarpB=environmentWaterWarpTerm(environmentWaterXZ,vec2(-.07,.19),-environmentTime*.09,.65);
   vec3 environmentWarpC=environmentWaterWarpTerm(environmentWaterXZ,vec2(-.09,.115),-environmentTime*.08,1.3);
   vec3 environmentWarpD=environmentWaterWarpTerm(environmentWaterXZ,vec2(.17,.035),environmentTime*.12,.55);
   vec2 environmentWaterDomain=environmentWaterXZ+vec2(environmentWarpA.x+environmentWarpB.x,environmentWarpC.x+environmentWarpD.x);
   vec2 environmentDomainDx=vec2(1.0+environmentWarpA.y+environmentWarpB.y,environmentWarpC.y+environmentWarpD.y);
   vec2 environmentDomainDz=vec2(environmentWarpA.z+environmentWarpB.z,1.0+environmentWarpC.z+environmentWarpD.z);
   float environmentWaveA=dot(environmentWaterDomain,vec2(.8,.6))*.72+environmentTime*.61;
   float environmentWaveB=dot(environmentWaterDomain,vec2(-.42,.907))*1.31-environmentTime*.87;
   float environmentWaveC=dot(environmentWaterDomain,vec2(.96,-.28))*3.70+environmentTime*1.29;
   float environmentWaveD=dot(environmentWaterDomain,vec2(.28,.96))*6.25-environmentTime*1.71;
   float environmentWaveE=dot(environmentWaterDomain,vec2(-.91,.415))*10.5+environmentTime*2.08;
   float environmentWaveF=dot(environmentWaterDomain,vec2(.65,.76))*17.2-environmentTime*2.76;
   float environmentFootprint=max(length(dFdx(environmentWaterXZ)),length(dFdy(environmentWaterXZ)));
   float environmentFilterA=environmentWaveFilter(environmentWaveA),environmentFilterB=environmentWaveFilter(environmentWaveB);
   float environmentFilterC=environmentWaveFilter(environmentWaveC),environmentFilterD=environmentWaveFilter(environmentWaveD);
   float environmentFilterE=environmentWaveFilter(environmentWaveE),environmentFilterF=environmentWaveFilter(environmentWaveF);
   vec2 environmentDomainSlope=vec2(.8,.6)*cos(environmentWaveA)*.039*environmentFilterA
    +vec2(-.42,.907)*cos(environmentWaveB)*.036*environmentFilterB
    +vec2(.96,-.28)*cos(environmentWaveC)*.037*environmentFilterC
    +vec2(.28,.96)*cos(environmentWaveD)*.022*environmentFilterD
    +vec2(-.91,.415)*cos(environmentWaveE)*.011*environmentFilterE
    +vec2(.65,.76)*cos(environmentWaveF)*.006*environmentFilterF;
   // Chain rule: changing phase coordinates must also bend the shading normals.
   vec2 environmentWaveSlope=vec2(dot(environmentDomainDx,environmentDomainSlope),dot(environmentDomainDz,environmentDomainSlope));
   vec3 environmentDisturbance=vec3(0.0);
   environmentDisturbance+=environmentRippleAt(environmentRipples[0],environmentWaterXZ,environmentFootprint);
environmentDisturbance+=environmentRippleAt(environmentRipples[1],environmentWaterXZ,environmentFootprint);
environmentDisturbance+=environmentRippleAt(environmentRipples[2],environmentWaterXZ,environmentFootprint);
environmentDisturbance+=environmentRippleAt(environmentRipples[3],environmentWaterXZ,environmentFootprint);
environmentDisturbance+=environmentRippleAt(environmentRipples[4],environmentWaterXZ,environmentFootprint);
environmentDisturbance+=environmentRippleAt(environmentRipples[5],environmentWaterXZ,environmentFootprint);
environmentDisturbance+=environmentRippleAt(environmentRipples[6],environmentWaterXZ,environmentFootprint);
environmentDisturbance+=environmentRippleAt(environmentRipples[7],environmentWaterXZ,environmentFootprint);
   environmentWaveSlope=(environmentWaveSlope+environmentDisturbance.xy)*mix(.38,1.0,smoothstep(0.0,.70,environmentDepth));
   // World-oriented analytic sky tint: standard scene lighting still controls
   // all radiance. This is not a screen-space reflection or an emissive layer.
   vec3 environmentWaterNormal=normalize(vec3(-environmentWaveSlope.x,1.0,-environmentWaveSlope.y));
   vec3 environmentEye=normalize(CAMERA_POSITION_WORLD+source_origin_m-vEnvironmentWorld);
   float environmentFacing=clamp(dot(environmentWaterNormal,environmentEye),0.0,1.0);
   float environmentFresnel=.0204+.9796*pow(1.0-environmentFacing,5.0);
   vec3 environmentReflection=reflect(-environmentEye,environmentWaterNormal);
   vec3 environmentSkyTint=mix(vec3(.18,.28,.30),vec3(.10,.21,.29),smoothstep(0.0,.85,environmentReflection.y));
   float environmentShoreNoiseFade=1.0-smoothstep(.12,.45,environmentFootprint*.82);
   float environmentShoreNoise=mix(.5,environmentNoise(environmentWaterXZ*.82+environmentFlow),environmentShoreNoiseFade);
   float environmentShoreAA=max(fwidth(environmentDepth)*1.25,.006);
   float environmentCoverage=environmentWaterCoverage(environmentDepth,environmentShoreNoise,environmentShoreAA);
   float environmentShoreFront=.045+.035*environmentShoreNoise+.008*sin(environmentWaveA)*environmentFilterA;
   float environmentShoreBand=1.0-smoothstep(.012,.036+min(environmentShoreAA,.028),abs(environmentDepth-environmentShoreFront));
   float environmentFoam=environmentShoreBand*smoothstep(.60,.86,environmentShoreNoise+.05*sin(environmentWaveB)*environmentFilterB)*(1.0-smoothstep(.12,.28,environmentDepth))*.16;
   float environmentWetEdge=1.0-smoothstep(.025,.20,environmentDepth);
   // Sparse, softly broken shallow glints, not zero-contours of crossing waves.
   vec2 environmentCausticCoord=environmentWaterDomain*.68+environmentFlow*.4+vec2(37.2,-19.4);
   vec2 environmentCausticBreakCoord=environmentWaterDomain*1.49-environmentFlow*.55+vec2(-8.3,42.7);
   float environmentCausticField=environmentNoise(environmentCausticCoord);
   float environmentCausticBreak=environmentNoise(environmentCausticBreakCoord);
   float environmentCausticAA=max(fwidth(environmentCausticField),.025);
   float environmentCausticBreakAA=max(fwidth(environmentCausticBreak),.025);
   float environmentCausticFootprint=max(max(fwidth(environmentCausticCoord.x),fwidth(environmentCausticCoord.y)),max(fwidth(environmentCausticBreakCoord.x),fwidth(environmentCausticBreakCoord.y)));
   float environmentCausticFade=1.0-smoothstep(.12,.45,environmentCausticFootprint);
   float environmentCaustic=smoothstep(.67-environmentCausticAA,.87+environmentCausticAA,environmentCausticField)*smoothstep(.60-environmentCausticBreakAA,.84+environmentCausticBreakAA,environmentCausticBreak);
   environmentCaustic*=environmentCausticFade*smoothstep(.04,.20,environmentDepth)*(1.0-smoothstep(.40,1.15,environmentDepth))*smoothstep(.18,.55,environmentFacing)*.026;
   ALBEDO=mix(environmentShallow.rgb,environmentDeep.rgb,environmentAbsorption);
   ALBEDO=mix(ALBEDO,environmentSkyTint,environmentFresnel*.36);
   // The first translucent centimetres show dark wet sediment, not a white rim.
   // This stays inside the existing water surface; dry bank/physics are untouched.
   vec3 environmentWetSediment=mix(environmentShallow.rgb*.28,environmentShore.rgb*.16,.75);
   ALBEDO=mix(ALBEDO,environmentWetSediment,environmentWetEdge*.76);
   ALBEDO+=environmentShore.rgb*(environmentCaustic+environmentDisturbance.z);
   ALBEDO=mix(ALBEDO,environmentShore.rgb,environmentFoam);
   ALPHA=.92*environmentCoverage*clamp(mix(.82,1.0,environmentAbsorption)+environmentFoam*.10+environmentFresnel*.12,0.0,1.0);
  
ROUGHNESS=clamp(.23+.038*(1.0-environmentAbsorption)+.017*sin(environmentWaveB)*environmentFilterB+environmentFoam*.24,.18,.39);
 METALLIC=.02;
 NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX)*vec3(-environmentWaveSlope.x,0.0,-environmentWaveSlope.y));
}
"""
static var _shared_shader: Shader
var _materials: Dictionary = {}
var _live_materials: Array[ShaderMaterial] = []
var _ripples := PackedVector4Array()
var _epoch := NAN
var _time := 0.0
var _disposed := false

func _init() -> void:
	_ripples.resize(RIPPLE_CAPACITY)
	_ripples.fill(Vector4(0, 0, -1, 0))

static func shared_shader() -> Shader:
	if _shared_shader == null:
		_shared_shader = Shader.new()
		_shared_shader.code = WATER_SHADER
	return _shared_shader

func material_for(source_origin_m: Vector3 = Vector3.ZERO, vertex_depth: bool = false) -> ShaderMaterial:
	if _disposed or not source_origin_m.is_finite():
		return null
	var key := "%s|%s" % [var_to_str(source_origin_m), vertex_depth]
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = shared_shader()
	material.resource_name = "Environment surface water revision 6"
	material.set_shader_parameter("source_origin_m", source_origin_m)
	material.set_shader_parameter("use_vertex_depth", vertex_depth)
	material.set_shader_parameter("default_depth", 2.5)
	material.set_shader_parameter("environmentShallow", Color("#428c82"))
	material.set_shader_parameter("environmentDeep", Color("#124d5e"))
	material.set_shader_parameter("environmentShore", Color("#bbcbb7"))
	material.set_shader_parameter("environmentTime", _time)
	material.set_shader_parameter("environmentRipples", _ripples)
	material.set_meta("source_revision", 6)
	material.set_meta("live_shader_visual_gpu", "OPEN")
	_materials[key] = material
	_live_materials.append(material)
	return material

func update(time_seconds: float) -> bool:
	if _disposed or not is_finite(time_seconds):
		return false
	if is_nan(_epoch):
		_epoch = time_seconds
	_time = maxf(0.0, time_seconds - _epoch)
	for material in _live_materials:
		material.set_shader_parameter("environmentTime", _time)
	return true

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func set_water_ripples(events: Variant) -> int:
	if _disposed:
		return 0
	var count := 0
	for i in range(RIPPLE_CAPACITY):
		var event: Variant = events[i] if events is Array and i < events.size() else null
		var valid := event is Dictionary
		if valid:
			for field in ["x", "z", "age", "strength"]:
				if not _finite_number(event.get(field)):
					valid = false
		if valid and event.age >= 0 and event.age <= RIPPLE_MAX_AGE and event.strength > 0:
			_ripples[i] = Vector4(event.x, event.z, event.age, minf(event.strength, 2.0))
			count += 1
		else:
			_ripples[i] = Vector4(0, 0, -1, 0)
	for material in _live_materials:
		material.set_shader_parameter("environmentRipples", _ripples)
	return count

## Call once while assembling a mesh; reserves CUSTOM0 as Float32 depth.
## Caller supplies source-world transform (including preview recentering).
## Returns independent arrays + flags, never creates floor/collision geometry.
static func prepare_depth_arrays(arrays: Array, source_transform: Transform3D = Transform3D.IDENTITY, depth_at: Callable = Callable()) -> Dictionary:
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return {"ok": false, "error": "VERTEX_ARRAY_REQUIRED"}
	if arrays[Mesh.ARRAY_CUSTOM0] != null:
		return {"ok": false, "error": "CUSTOM0_ALREADY_OWNED"}
	if not source_transform.origin.is_finite() or not source_transform.basis.x.is_finite() or not source_transform.basis.y.is_finite() or not source_transform.basis.z.is_finite():
		return {"ok": false, "error": "NONFINITE_TRANSFORM"}
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if positions.is_empty():
		return {"ok": false, "error": "EMPTY_VERTICES"}
	var depths := PackedFloat32Array()
	depths.resize(positions.size())
	for i in range(positions.size()):
		if not positions[i].is_finite():
			return {"ok": false, "error": "NONFINITE_VERTEX"}
		var world := source_transform * positions[i]
		if not world.is_finite():
			return {"ok": false, "error": "NONFINITE_WORLD_VERTEX"}
		var value: Variant = depth_at.call(world.x, world.z, world.y) if depth_at.is_valid() else 2.5
		if value is Dictionary:
			value = value.get("depth", 0)
		depths[i] = clampf(float(value), 0, 50) if _finite_number(value) else 0.0
	var prepared := arrays.duplicate(true)
	prepared[Mesh.ARRAY_CUSTOM0] = depths
	return {"ok": true, "arrays": prepared, "flags": DEPTH_FLAGS}

func dispose() -> void:
	_materials.clear()
	_live_materials.clear()
	_disposed = true
