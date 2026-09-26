extends SceneTree
const Interior = preload("res://scripts/preview_printshop_interior.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool,label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
func vec(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])
func mesh_material(node: Node3D) -> Material:
	if node is MultiMeshInstance3D:
		return node.multimesh.mesh.surface_get_material(0)
	if node is MeshInstance3D:
		return node.mesh.surface_get_material(0)
	return null
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var record: Dictionary
	for item in block.buildings:
		if item.id==Interior.SOURCE_ID:
			record=item
	var world := Node3D.new()
	root.add_child(world)
	var placement := Node3D.new()
	placement.position=vec(record.positionLocalM)
	placement.rotation.y=deg_to_rad(float(record.transform.yawDegrees))
	placement.scale=Vector3(record.transform.horizontalScale[0],1,record.transform.horizontalScale[1])*record.transform.uniformScale
	world.add_child(placement)
	var visual: Node3D = load(record.path).instantiate()
	visual.position=vec(record.transform.modelLocalOffsetM)
	placement.add_child(visual)
	var originals: Dictionary = {}
	for node in visual.find_children("*","MeshInstance3D",true,false):
		originals[node.get_instance_id()]={"node":node,"mesh":node.mesh}
	var adapter = Interior.new()
	world.add_child(adapter)
	var corrupt := data.duplicate(true)
	corrupt.originM[0]+=1
	check(not adapter.attach_existing(visual,record,corrupt),"origin admission unchanged")
	check(adapter.get_child_count()==0 and adapter._finish_factory==null,"reject creates no finish resources or nodes")
	var started := Time.get_ticks_usec()
	check(adapter.attach_existing(visual,record,data),"real source GLB attach")
	print("INTERIOR_FINISH_HOOK_CPU attach_us=",Time.get_ticks_usec()-started,"; not frame/GPU metric")
	var floor_material = adapter._material(15,false)
	var wall_material = adapter._material(16,false)
	check(floor_material is ShaderMaterial and wall_material is ShaderMaterial,"two source finishes activated")
	check(floor_material.get_meta("source_program_key")=="interior-finish-v2-4-true","concrete source floor role")
	check(wall_material.get_meta("source_program_key")=="interior-finish-v2-1-false","brick source wall role")
	check(wall_material.get_shader_parameter("source_origin_m")==vec(data.originM),"source world origin restoration")
	check(wall_material.get_shader_parameter("source_albedo_linear")==vec(data.materials[16].colorLinear),"wall linear base color unchanged")
	check(not floor_material.get_meta("source_procedural_shader_pending") and not wall_material.get_meta("source_procedural_shader_pending"),"applied CPU formula stage metadata")
	check(adapter._material(15,false)==floor_material and adapter._material(16,false)==wall_material,"adapter material cache stable")
	var source_floor: Node3D = adapter.find_child("Entry_Interior_Floor",true,false)
	var source_walls: Node3D = adapter.find_child("Storey_Walls_And_Ceilings",true,false)
	check(source_floor!=null and mesh_material(source_floor)==floor_material,"actual source floor mesh assignment")
	check(source_walls!=null and mesh_material(source_walls)==wall_material,"actual wall mesh stays wall despite floorCollision")
	var instance_color_batches := 0
	for node in adapter.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh.use_colors:
			instance_color_batches+=1
			var material: Material=node.multimesh.mesh.surface_get_material(0)
			check(material is StandardMaterial3D and material.vertex_color_use_as_albedo,"instance color StandardMaterial preserved")
	check(instance_color_batches>=8,"furniture color batches retained")
	var colored = adapter._material(16,true)
	check(colored is StandardMaterial3D and colored.vertex_color_use_as_albedo,"explicit colored finish uses existing fallback")
	check(colored.albedo_color.srgb_to_linear().is_equal_approx(Color(data.materials[16].colorLinear[0],data.materials[16].colorLinear[1],data.materials[16].colorLinear[2])),"fallback color conversion intact")
	check(colored.get_meta("source_procedural_shader_pending"),"unsupported variant pending remains explicit")
	var ordinary=adapter._material(0,false)
	check(ordinary is StandardMaterial3D,"ordinary material fallback unchanged")
	var node_count := adapter.get_child_count()
	check(not adapter.attach_existing(visual,record,data) and adapter.get_child_count()==node_count,"repeat attach no resource or node growth")
	adapter.restore_original()
	check(adapter._finish_factory==null and adapter._material_cache.is_empty(),"restore releases finish cache")
	check(adapter.get_child_count()==0 and not visual.has_meta("printshop_interior_attached"),"restore removes only owned geometry")
	var originals_restored := true
	for saved in originals.values():
		originals_restored=originals_restored and saved.node.mesh==saved.mesh
	check(originals_restored,"original imported mesh resource identities restored")
	check(adapter.attach_existing(visual,record,data),"fresh factory after restore allows reattach")
	adapter.restore_original()
	var probe=Interior.new()
	world.add_child(probe)
	for field in ["name","metalness","roughness","sourceProceduralShader"]:
		probe._data=data.duplicate(true)
		if field=="name":
			probe._data.materials[15][field]="InteriorFinish_brick"
		elif field=="sourceProceduralShader":
			probe._data.materials[15][field]=false
		else:
			probe._data.materials[15][field]=.2
		var fallback=probe._material(15,false)
		check(fallback is StandardMaterial3D,"changed source identity/factor fallback "+field)
		probe.restore_original()
	world.free()
	print("INTERIOR_FINISH_HOOK checks=%d failures=%s; GPU compile/visual/whole-scene FPS OPEN"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
