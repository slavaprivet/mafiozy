extends SceneTree
const Fixture = preload("res://rail_fixture.gd")
const Registry = preload("res://transport_registry_v2.gd")
var checks := 0
var failures: Array[String] = []
var owner_admits := true
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func owner(_request: Dictionary) -> Dictionary:
	return {"approved":owner_admits,"commit":func() -> bool: return true,"rollback":func() -> bool: return true}
func build() -> Dictionary:
	var fixture := Fixture.new()
	check(fixture.configure().ok,"exact source receipt admission")
	check(not fixture.factory.build_railway().ok,"default visual owner HOLD")
	check(not fixture.factory._roots.has("railway"),"HOLD leaves no native fake rail")
	fixture.visual_approved = true
	var rail: Dictionary = fixture.factory.build_railway()
	check(rail.ok,"trusted native fixture exact textures/train build")
	check(fixture.verified_native_glb and fixture.native_car_nodes==27,"actual GLB3 car roots +27 original merged meshes")
	var parking: Dictionary = fixture.factory.build_parking()
	root.add_child(parking.root)
	root.add_child(rail.root)
	var registry := Registry.new()
	check(registry.configure(fixture.factory,Callable(self,"owner")).ok,"all265 native links admitted")
	return {"fixture":fixture,"factory":fixture.factory,"registry":registry}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene := build()
	var registry: RefCounted = scene.registry
	var factory: RefCounted = scene.factory
	var rail_count := 0
	for id: String in registry.ids():
		check(registry.world_bounds(id) is AABB,"all265 actual native bounds")
		check(registry.is_editable(id),"owner explicitly admits actual native record")
		if not id.begins_with("railway-"): continue
		rail_count += 1
		var original: Dictionary = registry.get_record(id)
		var moved := original.duplicate(true)
		moved.transform.position[0] += 3.0
		var bounds: AABB = registry.world_bounds(id)
		var checkpoint: Dictionary = registry.capture_install_checkpoint()
		check(checkpoint.ok,"rail checkpoint")
		check(registry.apply_record(id,moved).ok,"rail move original part linkage")
		check((registry.world_bounds(id) as AABB).get_center().is_equal_approx(bounds.get_center()+Vector3(3,0,0)),"all rail bounds translate")
		check(registry.apply_record(id,null).ok,"rail delete")
		check(registry.get_record(id).is_empty(),"rail deleted presence")
		check(registry.apply_record(id,original).ok,"rail record undo")
		check(registry.restore_install_checkpoint(checkpoint).ok,"rail shared resources exact checkpoint restoration")
	check(rail_count==32,"all32 semantic rail IDs linked")
	for descriptor: Dictionary in factory._manifest.materials:
		if descriptor.textureBindings.is_empty(): continue
		var material: StandardMaterial3D = factory._materials[descriptor.id]
		check(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and not material.texture_repeat,"source station sampler trilinear/clamp")
		check(material.albedo_texture.get_image().has_mipmaps() and material.albedo_texture.get_image().get_mipmap_count()==10,"all11 original hierarchy mip levels")
		check(material.albedo_texture.get_meta("gpu_parity")=="HOLD-original-driver-mipmap/sampler-review","CPU labels do not claim GPU acceptance")
	var resource_checkpoint: Dictionary = registry.capture_install_checkpoint()
	var train_child: MeshInstance3D = factory._train_roots[0].get_child(0)
	var original_mesh: Mesh = train_child.mesh
	train_child.mesh = ArrayMesh.new()
	check(not registry.restore_install_checkpoint(resource_checkpoint).ok,"substituted actual train mesh refuses checkpoint")
	train_child.mesh = original_mesh
	check(registry.restore_install_checkpoint(resource_checkpoint).ok,"real train mesh restored to owner")
	var alignment := ""
	for id: String in registry.ids():
		if id.begins_with("railway-alignment:"): alignment = id
	var changed: Dictionary = registry.get_record(alignment)
	changed.transform.position[0] += 18.0
	var car_frames := []
	for car: Node3D in factory._train_roots: car_frames.append(car.transform)
	check(registry.apply_record(alignment,changed).ok,"alignment move")
	for index in 3: check(factory._train_roots[index].position.is_equal_approx(car_frames[index].origin+Vector3(18,0,0)),"alignment moves actual car roots")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(registry.current_document("rail-qa"),"",true,true))
	var fresh := build()
	check(fresh.registry.apply_document(saved).ok,"all265 source save fresh factory")
	for index in 3: check(fresh.factory._train_roots[index].transform.is_equal_approx(factory._train_roots[index].transform),"fresh actual car placement")
	for cycle in 3:
		saved = JSON.parse_string(JSON.stringify(fresh.registry.current_document("rail-qa"),"",true,true))
		check(fresh.registry.apply_document(saved).ok,"rail stable multiple cycle")
	owner_admits = false
	check(not registry.is_editable(alignment) and not registry.apply_record(alignment,null).ok,"runtime owner refusal HOLD despite admitted geometry")
	owner_admits = true
	check(not registry.create_copy(alignment,"editor:rail-not-authorized",registry.template_frame(alignment)).ok,"never clone canonical route/train authority")
	check(not factory.update_railway(0.1).ok,"motion authority remains disconnected")
	print("RAIL_REGISTRY_QA "+JSON.stringify({"checks":checks,"failures":failures,"nativeSourceIds":265,"railIds":rail_count,"actualTrainParts":scene.fixture.native_car_nodes,"scope":"original CPU capture sampler candidate + native actual train import/32 link edits, trusted owner fixtures; GPU and actual gameplay HOLD"}))
	fresh.registry.dispose()
	scene.registry.dispose()
	fresh.fixture.dispose()
	scene.fixture.dispose()
	quit(0 if failures.is_empty() else 1)
