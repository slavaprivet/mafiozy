extends SceneTree
const Water = preload("res://scripts/preview_water_material.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
func compact(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\s+")
	return regex.sub(value, "", true)
func _initialize() -> void:
	var factory = Water.new()
	var a = factory.material_for()
	check(a != null, "material created")
	check(a == factory.material_for(), "material reused")
	var b = factory.material_for(Vector3(410, 0, 820), true)
	check(a != b and a.shader == b.shader, "shared shader different origin/depth")
	check(factory.material_for(Vector3(NAN, 0, 0)) == null, "reject invalid origin")
	check(a.get_shader_parameter("environmentShallow") == Color("#428c82"), "shallow source color")
	check(a.get_meta("source_revision") == 6, "source revision")
	check(a.get_shader_parameter("default_depth") == 2.5, "missing depth default")
	check(not factory.update(NAN), "invalid time ignored")
	check(factory.update(120.0) and a.get_shader_parameter("environmentTime") == 0, "first update epoch")
	factory.update(122.25)
	check(a.get_shader_parameter("environmentTime") == 2.25 and b.get_shader_parameter("environmentTime") == 2.25, "all materials receive time")
	factory.update(119)
	check(a.get_shader_parameter("environmentTime") == 0, "negative relative time clamped")
	factory.update(INF)
	check(a.get_shader_parameter("environmentTime") == 0, "infinity ignored")
	var events: Array = []
	for i in range(9):
		events.append({"x": i, "z": -i, "age": 4.5, "strength": 3})
	events[1] = {"x": NAN, "z": 0, "age": 0, "strength": 1}
	check(factory.set_water_ripples(events) == 7, "only first eight slots invalid not compacted")
	var packed: PackedVector4Array = a.get_shader_parameter("environmentRipples")
	check(packed.size() == 8 and packed[1] == Vector4(0,0,-1,0), "invalid slot sentinel")
	check(packed[7] == Vector4(7,-7,4.5,2), "coordinates preserved strength capped")
	check(factory.set_water_ripples([{"x":0,"z":0,"age":4.50001,"strength":1}]) == 0, "old ripple rejected")
	check(factory.set_water_ripples([{"x":0,"z":0,"age":-1,"strength":1}]) == 0, "future ripple rejected")
	check(factory.set_water_ripples([{"x":0,"z":0,"age":0,"strength":0}]) == 0, "zero strength rejected")
	check(factory.set_water_ripples([{"x":"0","z":0,"age":0,"strength":1}]) == 0, "string rejected")
	check(factory.set_water_ripples(null) == 0, "nonarray clears")
	packed = b.get_shader_parameter("environmentRipples")
	check(packed[0] == Vector4(0,0,-1,0), "all materials cleared")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(1,0,0), Vector3(0,0,1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var prepared: Dictionary = Water.prepare_depth_arrays(arrays)
	check(prepared.ok and prepared.arrays[Mesh.ARRAY_CUSTOM0] == PackedFloat32Array([2.5,2.5,2.5]), "Float32 fallback depth")
	check(arrays[Mesh.ARRAY_CUSTOM0] == null, "input arrays not modified")
	check(prepared.arrays[Mesh.ARRAY_VERTEX] == arrays[Mesh.ARRAY_VERTEX], "geometry not displaced")
	var visited: Array = []
	prepared = Water.prepare_depth_arrays(arrays, Transform3D(Basis.IDENTITY, Vector3(410,5,820)), func(x,z,y):
		visited.append(Vector3(x,y,z))
		return {"depth": 70 if x > 410 else -1})
	check(visited == [Vector3(410,5,820),Vector3(411,5,820),Vector3(410,5,821)], "sampler receives source world x,z,y")
	check(prepared.arrays[Mesh.ARRAY_CUSTOM0] == PackedFloat32Array([0,50,0]), "depth clamp 0..50")
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, prepared.arrays, [], {}, prepared.flags)
	check(mesh.get_surface_count() == 1, "actual ArrayMesh accepts custom R_FLOAT")
	check((mesh.surface_get_format(0) >> Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK == Mesh.ARRAY_CUSTOM_R_FLOAT, "custom channel retains float format")
	check(not Water.prepare_depth_arrays(prepared.arrays).ok, "existing CUSTOM0 ownership rejected")
	check(not Water.prepare_depth_arrays([]).ok, "bad arrays rejected")
	var invalid: Dictionary = Water.prepare_depth_arrays(arrays, Transform3D(Basis.IDENTITY, Vector3(NAN,0,0)))
	check(not invalid.ok, "bad transform rejected")
	prepared = Water.prepare_depth_arrays(arrays, Transform3D.IDENTITY, func(_x,_z,_y): return NAN)
	check(prepared.arrays[Mesh.ARRAY_CUSTOM0] == PackedFloat32Array([0,0,0]), "nonfinite depths zero")
	var overflow_arrays := arrays.duplicate(true)
	overflow_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(3e38,0,0)])
	check(not Water.prepare_depth_arrays(overflow_arrays, Transform3D(Basis.from_scale(Vector3(3e38,1,1)),Vector3.ZERO)).ok, "finite transform multiplication overflow rejected")
	var empty_arrays := arrays.duplicate(true)
	empty_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	check(not Water.prepare_depth_arrays(empty_arrays).ok, "empty vertices rejected")
	empty_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(INF,0,0)])
	check(not Water.prepare_depth_arrays(empty_arrays).ok, "nonfinite vertex rejected")
	# Independent source oracle validates stable domain/Jacobian values. Shader
	# comparison below checks actual source operations; headless is NOT GPU compile.
	var source := FileAccess.get_file_as_string("res://../../assets/maps/city_rebuild_v1/environment_surface_materials.mjs").replace("\r", "")
	check(not source.is_empty(), "actual source readable")
	var common := source.split("const COMMON=`")[1].split("`;")[0]
	check(compact(Water.WATER_SHADER).contains(compact(common)), "exact hash/noise source")
	var color_body := source.split("if(water){")[1].split("#include <color_fragment>\n")[1].split("`);")[0]
	var replacement := ""
	for i in range(8):
		replacement += ("\n" if i > 0 else "") + "environmentDisturbance+=environmentRippleAt(environmentRipples[%d],environmentWaterXZ,environmentFootprint);" % i
	var interpolation := "${Array.from({length:WATER_RIPPLE_CAPACITY},(_,i)=>`environmentDisturbance+=environmentRippleAt(environmentRipples[${i}],environmentWaterXZ,environmentFootprint);`).join('\\n   ')}"
	check(color_body.contains(interpolation), "source ripple interpolation located")
	color_body = color_body.replace(interpolation, replacement).replace("cameraPosition-vEnvironmentWorld", "CAMERA_POSITION_WORLD+source_origin_m-vEnvironmentWorld")
	for color in ["environmentShallow", "environmentDeep", "environmentShore"]:
		var color_regex := RegEx.new()
		color_regex.compile("\\b" + color + "\\b")
		color_body = color_regex.sub(color_body, color + ".rgb", true)
	color_body = color_body.replace("diffuseColor.rgb", "ALBEDO").replace("diffuseColor.a*=", "ALPHA=.92*")
	check(compact(Water.WATER_SHADER).contains(compact(color_body)), "full water fragment operations match active source")
	var water_common := source.split("const WATER_COMMON=`")[1].split("`;")[0]
	for color in ["environmentShallow", "environmentDeep", "environmentShore"]:
		water_common = water_common.replace("uniform vec3 " + color + ";", "uniform vec4 " + color + " : source_color;")
	check(compact(Water.WATER_SHADER).contains(compact(water_common)), "exact ripple annulus/filter/coverage functions")
	var roughness := source.split("roughnessFactor=clamp(")[1].split(";")[0]
	check(compact(Water.WATER_SHADER).contains(compact("ROUGHNESS=clamp(" + roughness.replace("roughnessFactor+", ".23+") + ";")), "exact roughness expression")
	check(Water.WATER_SHADER.contains("NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX)*vec3(-environmentWaveSlope.x,0.0,-environmentWaveSlope.y))"), "source normal mapped into view space")
	check(Water.WATER_SHADER.contains("diffuse_lambert"), "source Lambert diffuse lighting")
	var linear: Color = Color("#428c82").srgb_to_linear()
	check(absf(linear.r-.054480276435339814)<.000001 and absf(linear.g-.26225065751888765)<.000001 and absf(linear.b-.22322795730611386)<.000001, "linear shallow matches Three oracle")
	var started := Time.get_ticks_usec()
	for i in range(10000):
		factory.update(200.0 + i * .016)
	print("WATER_CPU update mean_us two reused materials=", float(Time.get_ticks_usec()-started)/10000.0, "; NOT LIVE/frame/GPU cost")
	check(not Water.WATER_SHADER.contains("VERTEX +=") and not Water.WATER_SHADER.contains("TIME"), "no displacement or engine TIME")
	check(Water.WATER_SHADER.contains("depth_draw_never") and Water.WATER_SHADER.contains("METALLIC=.02"), "source render contract")
	factory.dispose()
	check(factory.material_for() == null and not factory.update(5) and factory.set_water_ripples(events) == 0, "disposed factory inert")
	print("WATER_CPU checks=%d failures=%s; GPU compile/visual/fullscene FPS OPEN" % [checks, failures])
	quit(0 if failures.is_empty() else 1)
