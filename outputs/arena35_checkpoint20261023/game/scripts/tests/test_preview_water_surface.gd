extends SceneTree
const Surface = preload("res://scripts/preview_water_surface.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
func fixture() -> Dictionary:
	return {"schema": Surface.SCHEMA, "originM": [395.65,0,45.1], "metresPerCell": 4.1, "native":{"surfaceYM":-.18,"vertexOrder":Surface.SOURCE_ORDER.duplicate(true), "cells":[{"r":2,"c":80,"depths":[0,.01,.1,0,.01,2.22]}]}}
func _initialize() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var surface = Surface.new()
	var data := fixture()
	var result: Dictionary = surface.build(data, parent)
	check(result.ok and result.mesh_instances == 1 and result.triangles == 2, "single water batch")
	check(parent.get_child_count() == 1, "exactly one node no floor/collision")
	var instance := parent.get_child(0) as MeshInstance3D
	check(instance != null and instance.get_child_count() == 0, "no physics children")
	check(instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "cast shadow off")
	check(not instance.is_processing() and not instance.is_physics_processing(), "no automatic update")
	var mesh := instance.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	check(mesh.get_surface_count() == 1, "one surface")
	var normal_error := 0.0
	for normal in arrays[Mesh.ARRAY_NORMAL]:
		normal_error = maxf(normal_error, normal.distance_to(Vector3.UP))
	check(normal_error < .0001, "up normals engine compressed tolerance")
	check(arrays[Mesh.ARRAY_TEX_UV] == null or arrays[Mesh.ARRAY_TEX_UV].is_empty(), "no invented source UV")
	check(arrays[Mesh.ARRAY_CUSTOM0] == PackedFloat32Array(data.native.cells[0].depths), "exact pervertex depth order")
	check(arrays[Mesh.ARRAY_INDEX] == PackedInt32Array([0,2,1,3,5,4]), "Godot clockwise adaptation")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var expected := Vector3(80*4.1,-.18,2*4.1)-Vector3(395.65,0,45.1)
	check(vertices[0].is_equal_approx(expected), "Float32 source before origin subtraction")
	check((vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y < 0, "top side clockwise indices")
	var material := mesh.surface_get_material(0) as ShaderMaterial
	check(material != null and material.render_priority == 1, "transparent source sort order")
	check(material.get_shader_parameter("use_vertex_depth") == true, "actual depth enabled")
	check(surface.advance(100) and material.get_shader_parameter("environmentTime") == 0, "host advances explicit epoch")
	var events := [{"x":328.0,"z":8.2,"age":1,"strength":1}]
	check(surface.advance(101, events) and material.get_shader_parameter("environmentTime") == 1, "host one clock advances material")
	var ripples: PackedVector4Array = material.get_shader_parameter("environmentRipples")
	check(ripples[0] == Vector4(328,8.2,1,1), "host source ripple coordinates")
	check(not surface.build(data,parent).ok and parent.get_child_count()==1, "double build rejected no growth")
	var start := Time.get_ticks_usec()
	for i in range(10000):
		surface.advance(101+i*.016)
	print("WATER_SURFACE_CPU advance mean_us onebatch=",float(Time.get_ticks_usec()-start)/10000,"; NOT LIVE/GPU/frame metrics")
	ripples = material.get_shader_parameter("environmentRipples")
	check(ripples[0] == Vector4(0,0,-1,0), "null after active clears once")
	check(mesh == instance.mesh and material == mesh.surface_get_material(0), "advance no replacement resources")
	surface.dispose()
	check(parent.get_child_count() == 0 and not is_instance_valid(instance), "dispose removes only owned water")
	check(not surface.advance(200), "disposed no updates")
	check(surface.build(data,parent).ok, "host reusable after dispose")
	surface.dispose()
	var empty := fixture()
	empty.native.cells = []
	check(surface.build(empty,parent).ok and parent.get_child_count() == 0, "dry empty input no nodes")
	surface.dispose()
	var bad_inputs: Array = [null, {}, {"schema":"wrong"}]
	for bad in bad_inputs:
		check(not surface.build(bad,parent).ok and parent.get_child_count() == 0, "malformed no partial scene")
	var bad := fixture()
	bad.native.cells[0].depths[0] = NAN
	check(not surface.build(bad,parent).ok, "nonfinite depth rejects before nodes")
	bad = fixture()
	bad.native.cells.append(bad.native.cells[0].duplicate(true))
	check(not surface.build(bad,parent).ok, "duplicate cell rejects")
	bad = fixture()
	bad.native.cells[0].depths = [2.5]
	check(not surface.build(bad,parent).ok, "uniform coast substitute rejected")
	bad = fixture()
	bad.native.cells[0].r = .5
	check(not surface.build(bad,parent).ok, "fractional tile rejects")
	bad = fixture()
	bad.originM[0] = INF
	check(not surface.build(bad,parent).ok, "nonfinite origin rejects")
	bad = fixture()
	bad.native.vertexOrder = []
	check(not surface.build(bad,parent).ok, "incorrect source order rejects")
	bad = fixture()
	bad.native.cells.resize(Surface.MAX_CELLS+1)
	check(not surface.build(bad,parent).ok, "oversize payload rejected before mesh")
	bad = fixture()
	bad.native.cells[0].depths[0] = 50.001
	check(not surface.build(bad,parent).ok, "out of source depth range rejected")
	bad = fixture()
	bad.native.surfaceYM = 0
	check(not surface.build(bad,parent).ok, "wrong water level rejected")
	parent.position.x = 1
	check(not surface.build(fixture(),parent).ok, "transformed world parent rejects")
	parent.position.x = 0
	check(not surface.build(fixture(),null).ok, "missing parent rejects")
	var real: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_water.json")) if FileAccess.file_exists("res://data/preview_water.json") else null
	if real != null:
		check(Surface.validate(real).is_empty(), "real exported data admitted")
		start = Time.get_ticks_usec()
		result = surface.build(real,parent)
		print("WATER_SURFACE_CPU real build_us=",Time.get_ticks_usec()-start," summary=",result)
		check(result.ok and result.cells == 303 and result.vertices == 1818 and result.triangles == 606, "all current-quarter source water included")
		check(parent.get_child_count() == 1, "303 source tiles one mesh node")
		var real_arrays: Array = (parent.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0)
		var real_depths: PackedFloat32Array = real_arrays[Mesh.ARRAY_CUSTOM0]
		var wet := 0
		var dry := 0
		var paired := true
		var real_origin := Vector3(real.originM[0],real.originM[1],real.originM[2])
		for i in range(real.native.cells.size()):
			var record: Dictionary = real.native.cells[i]
			for j in range(6):
				var k := i*6+j
				wet += int(real_depths[k] > 0)
				dry += int(real_depths[k] == 0)
				var source := Vector3((record.c+Surface.SOURCE_ORDER[j][0])*real.metresPerCell,real.native.surfaceYM,(record.r+Surface.SOURCE_ORDER[j][1])*real.metresPerCell)
				paired = paired and real_depths[k] == record.depths[j] and real_arrays[Mesh.ARRAY_VERTEX][k].distance_to(source-real_origin) < .0001
		check(wet == 1587 and dry == 231, "actual wet and depth-zero shoreline retained")
		check(paired, "all1818 Float32 depth and vertex pairs match exported source")
		check(real_arrays[Mesh.ARRAY_INDEX].size() == 1818, "all606 triangles retained")
		surface.dispose()
	else:
		check(false,"real exported data required before acceptance")
	parent.free()
	print("WATER_SURFACE_CPU checks=%d failures=%s; GPU/scene update root-owned OPEN" % [checks,failures])
	quit(0 if failures.is_empty() else 1)
