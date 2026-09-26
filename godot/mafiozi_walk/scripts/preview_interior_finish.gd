extends RefCounted
## Interior finish v2: static world-metre patterns from actual Walk factory.
## No geometry/UV mutation, textures, per-frame updates, light or collision edits.
const SOURCE_MODE := {"brick":1,"wood":2,"wallpaper":3,"concrete":4,"tile":5,"plaster":0,"stone":5,"parquet":2,"panels":2}
const MAX_MATERIALS := 128
const FORMULAS := {
	1: "vec2 brick=ip/vec2(.42,.20);brick.x+=mod(floor(brick.y),2.0)*.5;vec2 joint=abs(fract(brick)-.5);float mortar=smoothstep(.455,.48,max(joint.x,joint.y));surfaceTone=mix(.89+sin(floor(brick.x)*3.1+floor(brick.y)*7.3)*.045,1.16,mortar);",
	2: "vec2 board=ip/vec2(.20,1.8);float seam=smoothstep(.475,.499,abs(fract(board.x)-.5));surfaceTone=.94+.035*sin(ip.y*14.0+sin(ip.x*31.0)*1.4)-.14*seam;",
	3: "vec2 motif=fract(ip/vec2(.32,.42))-.5;float diamond=abs(motif.x)+abs(motif.y);float ornament=1.0-smoothstep(.015,.045,abs(diamond-.28));float dotMark=1.0-smoothstep(.025,.07,length(motif));surfaceTone=1.0-.14*ornament-.1*dotMark;",
	4: "surfaceTone=.97+.025*sin(ip.x*3.2+sin(ip.y*5.0))+.013*sin(ip.y*32.0+ip.x*27.0);",
	5: "vec2 joint=abs(fract(ip/.55)-.5);surfaceTone=mix(1.0,.78,smoothstep(.477,.499,max(joint.x,joint.y)));",
}
const SHADER_HEADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
uniform vec3 source_origin_m = vec3(0.0);
uniform vec3 source_albedo_linear = vec3(1.0);
uniform float source_roughness = .82;
varying vec3 vInteriorMetric;
void vertex() {
 vInteriorMetric=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+source_origin_m;
}
void fragment() {
 vec3 interiorNormal=abs(cross(dFdx(vInteriorMetric),dFdy(vInteriorMetric)));
"""
static var _shaders: Dictionary = {}
var _materials: Dictionary = {}
var _disposed := false

static func shader_code(finish: String, floor_surface: bool) -> String:
	var mode: int = SOURCE_MODE.get(finish,0)
	var code := SHADER_HEADER
	code += " vec2 ip=" + ("vInteriorMetric.xz" if floor_surface else "interiorNormal.x>interiorNormal.z?vInteriorMetric.zy:vInteriorMetric.xy") + ";\n float surfaceTone=1.0;\n"
	code += str(FORMULAS.get(mode,"")) + "\n"
	if not floor_surface:
		code += "if(interiorNormal.y>max(interiorNormal.x,interiorNormal.z))surfaceTone=1.0;\n"
	code += "ALBEDO=source_albedo_linear*surfaceTone;\nROUGHNESS=source_roughness;\nMETALLIC=0.0;\n}\n"
	return code

static func shared_shader(finish: String, floor_surface: bool) -> Shader:
	var key := "%d|%s" % [SOURCE_MODE.get(finish,0),floor_surface]
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = shader_code(finish,floor_surface)
		_shaders[key] = shader
	return _shaders[key]

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func _linear_rgb(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for channel in value:
		if not _number(channel,0,1):
			return false
	return true

## Recognizes only source factory opaque, double-sided, untextured factors.
## Unsupported/malformed records return null so caller keeps existing fallback.
## floor_surface is proven by source generator, NOT guessed from material name.
func material_for(source: Variant, floor_surface: bool, source_origin_m: Vector3 = Vector3.ZERO) -> ShaderMaterial:
	if _disposed or not source is Dictionary or not source_origin_m.is_finite():
		return null
	var name_value: Variant = source.get("name")
	if not name_value is String or not name_value.begins_with("InteriorFinish_") or name_value.length() > 80 or source.get("sourceProceduralShader") != true:
		return null
	if not _linear_rgb(source.get("colorLinear")) or not _number(source.get("roughness"),0,1):
		return null
	# The actual createInteriorFinish helper fixes these properties. Reject
	# unsupported overrides instead of silently losing them in this port.
	if source.get("metalness") != 0 or source.get("opacity") != 1 or source.get("transparent") != false or source.get("doubleSided") != true or source.get("vertexColors") != false:
		return null
	if source.get("emissiveIntensity") != 1:
		return null
	if not _linear_rgb(source.get("emissiveLinear")) or source.emissiveLinear[0] != 0 or source.emissiveLinear[1] != 0 or source.emissiveLinear[2] != 0:
		return null
	var finish: String = name_value.trim_prefix("InteriorFinish_")
	var expected_roughness := .48 if finish == "tile" else .82
	if absf(float(source.roughness)-expected_roughness) > .000001:
		return null
	var linear := Vector3(source.colorLinear[0],source.colorLinear[1],source.colorLinear[2])
	var key := var_to_str([finish,floor_surface,linear,source_origin_m,source.roughness])
	if _materials.has(key):
		return _materials[key]
	if _materials.size() >= MAX_MATERIALS:
		return null
	var material := ShaderMaterial.new()
	material.shader = shared_shader(finish,floor_surface)
	material.resource_name = name_value
	material.set_shader_parameter("source_origin_m",source_origin_m)
	# Numeric already-linear RGB is intentionally NOT annotated source_color.
	material.set_shader_parameter("source_albedo_linear",linear)
	material.set_shader_parameter("source_roughness",float(source.roughness))
	material.set_meta("source_program_key", "interior-finish-v2-%d-%s" % [SOURCE_MODE.get(finish,0),str(floor_surface).to_lower()])
	material.set_meta("source_projection", "world xz" if floor_surface else "world zy or xy; horizontal faces tone1")
	material.set_meta("live_shader_visual_gpu", "OPEN")
	_materials[key] = material
	return material

func dispose() -> void:
	_materials.clear()
	_disposed = true
