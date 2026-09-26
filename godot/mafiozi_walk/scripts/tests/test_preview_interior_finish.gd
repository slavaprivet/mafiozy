extends SceneTree
const Finish = preload("res://scripts/preview_interior_finish.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool,label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
func compact(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\s+")
	return regex.sub(value,"",true)
func spec(finish: String) -> Dictionary:
	return {"name":"InteriorFinish_"+finish,"colorLinear":[.2,.3,.4],"roughness":.48 if finish=="tile" else .82,"metalness":0,"emissiveLinear":[0,0,0],"emissiveIntensity":1,"opacity":1,"transparent":false,"doubleSided":true,"vertexColors":false,"sourceProceduralShader":true}
func _initialize() -> void:
	var factory = Finish.new()
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	check(source is Dictionary,"actual exported source readable")
	var origin := Vector3(source.originM[0],source.originM[1],source.originM[2])
	var concrete: Dictionary = source.materials[15]
	var brick: Dictionary = source.materials[16]
	check(concrete.name=="InteriorFinish_concrete" and brick.name=="InteriorFinish_brick","actual finish identities")
	var wall = factory.material_for(brick,false,origin)
	var floor_mat = factory.material_for(concrete,true,origin)
	check(wall!=null and floor_mat!=null,"actual two finishes accepted")
	check(wall==factory.material_for(brick,false,origin),"material resource reused")
	check(wall.shader != floor_mat.shader,"actual two source shader variants")
	check(wall.get_shader_parameter("source_albedo_linear")==Vector3(brick.colorLinear[0],brick.colorLinear[1],brick.colorLinear[2]),"linear wall color no second conversion")
	check(floor_mat.get_shader_parameter("source_roughness")==.82,"actual concrete roughness")
	check(wall.get_shader_parameter("source_origin_m")==origin,"original source metre origin")
	check(wall.shader.code.contains("interiorNormal.x>interiorNormal.z?vInteriorMetric.zy:vInteriorMetric.xy"),"wall dominant normal projection")
	check(wall.shader.code.contains("if(interiorNormal.y>max(interiorNormal.x,interiorNormal.z))surfaceTone=1.0;"),"wall ceiling faces unpatterned")
	check(floor_mat.shader.code.contains("vec2 ip=vInteriorMetric.xz"),"floor world xz projection")
	check(not floor_mat.shader.code.contains("surfaceTone=1.0;\nALBEDO"),"floor has no horizontal suppression")
	check(wall.shader.code.contains("cull_disabled") and wall.shader.code.contains("diffuse_lambert"),"source DoubleSide and Lambert")
	check(not wall.shader.code.contains("texture(") and not wall.shader.code.contains("TIME") and not wall.shader.code.contains("VERTEX +="),"static texture-free no displacement")
	check(not wall.shader.code.contains("source_color"),"already-linear color uniform")
	var text := FileAccess.get_file_as_string("res://../../assets/maps/city_rebuild_v1/interior_finishes.mjs").replace("\r","")
	var regex := RegEx.new()
	regex.compile("mode===(\\d)\\?`([^`]*)`:''")
	var hits := regex.search_all(text)
	check(hits.size()==5,"all exact source pattern formulas located")
	for hit in hits:
		var mode := int(hit.get_string(1))
		check(compact(str(Finish.FORMULAS[mode]))==compact(hit.get_string(2)),"exact source formula mode %d"%mode)
	check(Finish.shared_shader("wood",false)==Finish.shared_shader("panels",false),"same source mode aliases share shader")
	check(Finish.shared_shader("stone",true)==Finish.shared_shader("tile",true),"tile stone shader shared")
	var tile = factory.material_for(spec("tile"),true)
	var stone = factory.material_for(spec("stone"),true)
	check(tile.get_shader_parameter("source_roughness")==.48 and stone.get_shader_parameter("source_roughness")==.82,"source tile versus stone roughness distinction")
	var fallback = factory.material_for(spec("unknown_source_style"),false)
	check(fallback != null and fallback.shader==Finish.shared_shader("plaster",false),"source unknown style plaster mode fallback")
	check(factory.material_for(null,false)==null,"malformed source rejected")
	check(factory.material_for(brick,false,Vector3(NAN,0,0))==null,"nonfinite origin rejected")
	for key in ["sourceProceduralShader","doubleSided"]:
		var bad := brick.duplicate(true)
		bad[key]=false
		check(factory.material_for(bad,false)==null,"unsupported source flag "+key)
	for key in ["metalness","opacity","roughness"]:
		var bad := brick.duplicate(true)
		bad[key]=.2
		check(factory.material_for(bad,false)==null,"unsupported altered factor "+key)
	var bad := brick.duplicate(true)
	bad.transparent=true
	check(factory.material_for(bad,false)==null,"unsupported transparent override rejected")
	bad=brick.duplicate(true)
	bad.vertexColors=true
	check(factory.material_for(bad,false)==null,"unported vertex color override rejected")
	bad=brick.duplicate(true)
	bad.colorLinear[0]=NAN
	check(factory.material_for(bad,false)==null,"nonfinite color rejected")
	bad=brick.duplicate(true)
	bad.emissiveLinear=[1,0,0]
	check(factory.material_for(bad,false)==null,"emissive override not silently lost")
	bad=brick.duplicate(true)
	bad.emissiveIntensity=NAN
	check(factory.material_for(bad,false)==null,"nonfinite emission intensity rejected")
	var patches: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/interior_finish_patches.json"))
	check(patches is Dictionary and patches.patched.size()==2,"actual generator callback fixtures present")
	for patch in patches.patched:
		var floor_role: bool = patch.descriptor.sourceProgramKey.ends_with("-true")
		var actual_material = factory.material_for(patch.descriptor,floor_role,origin)
		check(actual_material != null,"actual callback descriptor admitted")
		check(actual_material.get_meta("source_program_key")==patch.descriptor.sourceProgramKey,"source cache key exact role")
		var expected_fragment: String = patch.fragmentPatch.replace("diffuseColor.rgb*=surfaceTone;","ALBEDO=source_albedo_linear*surfaceTone;")
		check(compact(actual_material.shader.code).contains(compact(expected_fragment)),"actual full callback fragment matched")
		check(patch.uniformNames.is_empty(),"source no dynamic uniforms")
	var roles_correct := true
	for mesh in source.meshes:
		if 15.0 in mesh.materials:
			roles_correct = roles_correct and mesh.name=="Entry_Interior_Floor"
		if mesh.name=="Storey_Walls_And_Ceilings":
			check(mesh.floorCollision==true and 16.0 in mesh.materials,"physics floorCollision must not infer material floor-role")
	check(roles_correct,"actual concrete assigned only source floor")
	var started := Time.get_ticks_usec()
	for i in range(10000):
		factory.material_for(brick,false,origin)
	print("INTERIOR_FINISH_CPU cache lookup mean_us=",float(Time.get_ticks_usec()-started)/10000,"; construction only, no per-frame hook/GPU metric")
	var bounded = Finish.new()
	for i in range(Finish.MAX_MATERIALS):
		check(bounded.material_for(brick,false,Vector3(i,0,0))!=null,"bounded accepted variant")
	check(bounded.material_for(brick,false,Vector3(Finish.MAX_MATERIALS,0,0))==null,"resource capacity fail closed")
	check(bounded.material_for(brick,false,Vector3.ZERO)!=null,"existing cached resource available at capacity")
	bounded.dispose()
	factory.dispose()
	check(factory.material_for(brick,false,origin)==null,"disposed factory inert")
	print("INTERIOR_FINISH_CPU checks=%d failures=%s; root hook/GPU/visual/whole-scene FPS OPEN"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
