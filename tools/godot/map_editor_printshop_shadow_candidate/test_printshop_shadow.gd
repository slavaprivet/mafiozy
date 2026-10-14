extends SceneTree
const Shadow = preload("res://printshop_shadow.gd")
const Original = preload("res://scripts/preview_printshop_interior.gd")
var checks := 0
var failures: Array = []
class Owner extends Node:
	var token := RefCounted.new()
	var returns_bool := false
	var reenter := false
	var held := true
	var poison_resource: Resource
	func seal(builder: RefCounted, _epoch: int) -> Variant:
		if reenter: builder.write_transform(35,0,Transform3D.IDENTITY)
		if poison_resource != null: poison_resource.emit_changed()
		return true if returns_bool else token
	func validate(_builder: RefCounted, _epoch: int, receipt: RefCounted) -> Variant: return receipt if held else null
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var source_hash := FileAccess.get_sha256("res://data/printshop_interior.json")
	check(source_hash == "958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b","Exact source descriptor SHA")
	var oracle := Original.new()
	var rejected := Shadow.new()
	var forged := data.duplicate(true)
	forged.meshes[24].instances[0][12] += 10
	check(not rejected.build(forged).ok,"Same-ID forged source matrix rejected")
	rejected.dispose()
	var builder := Shadow.new()
	check(builder.build(data).get("ok",false),"Build actual 15 batches")
	check(builder.guard(),"Initial lifetime/resource guards")
	check(not builder.owner_receipt_valid(),"No default owner admission")
	var snapshot: Dictionary = builder.initial_snapshot()
	var total := 0
	var colors := 0
	for index in snapshot:
		var spec: Dictionary = data.meshes[index]
		for slot in spec.instances.size():
			check(snapshot[index].transforms[slot] == oracle._matrix(spec.instances[slot]),"Exact original matrix %s/%s" % [index,slot])
			total += 1
		for slot in spec.get("instanceColorsLinear",[]).size():
			check(snapshot[index].colors[slot] == oracle._linear_color(spec.instanceColorsLinear[slot]),"Exact original linear color")
			colors += 1
	check(snapshot.size() == 15 and total == 280 and colors == 215,"All original batched content retained")
	snapshot[24].transforms[0] = Transform3D.IDENTITY
	check(builder.initial_snapshot()[24].transforms[0] == oracle._matrix(data.meshes[24].instances[0]),"Returned snapshot cannot alias initial")
	var epoch: int = builder.generation()
	check(not builder.write_instances(35,{0:{"transform":Transform3D.IDENTITY},99:{"transform":Transform3D.IDENTITY}}),"Atomic range validation")
	check(builder.generation() == epoch,"Rejected write doesn't bump epoch")
	var frame := Transform3D(Basis(Vector3.UP,.4),Vector3(2,3,4))
	check(builder.write_transform(35,0,frame),"Door instance shadow can mutate through owner path")
	check(builder.shadow()[35].transforms[0] == frame and builder.generation() == epoch + 1,"Exact submitted CPU shadow and epoch")
	check(builder.initial_snapshot()[35].transforms[0] == oracle._matrix(data.meshes[35].instances[0]),"Initial immutable generation retained")
	check(builder.write_color(31,0,Color(.1,.2,.3,1)),"Linear color managed write")
	check(builder.shadow()[31].colors[0] == Color(.1,.2,.3,1),"Color shadow exact, no gamma reconversion")
	check(not builder.write_color(35,0,Color.WHITE),"Cannot enable absent source instance colors")
	check(builder.write_instances(31,{1:{"transform":frame,"color":Color(.4,.5,.6,1)},2:{"transform":frame}}),"Atomic multi-instance writer")
	check(builder.shadow()[31].transforms[2] == frame and builder.shadow()[31].colors[1] == Color(.4,.5,.6,1),"Both batched write payloads retained exact")
	check(not builder.write_instances(31,{0:{"buffer":PackedFloat32Array()}}),"Raw buffer bypass rejected")
	check(builder.set_visible_count(35,2) and builder.shadow()[35].visible == 2,"Visibility write shadow")
	check(builder.set_bounds(35,AABB(Vector3(-1,-1,-1),Vector3(10,10,10))),"Bounds writer")
	check(builder.set_batch_frame(35,frame),"Batch frame writer")
	check(builder.guard(),"Own writes do not poison resources")
	var owner := Owner.new(); root.add_child(owner)
	owner.returns_bool = true
	check(not builder.request_owner_receipt(owner,owner.seal,owner.validate),"Boolean fake admission rejected")
	owner.returns_bool = false; owner.reenter = true
	epoch = builder.generation()
	check(builder.request_owner_receipt(owner,owner.seal,owner.validate) and builder.generation() == epoch,"Bound callback receipt, reentrant writes refused")
	check(builder.owner_receipt_valid(),"Same opaque owner receipt revalidation")
	owner.held = false
	check(not builder.owner_receipt_valid(),"Owner paused lifecycle expiry")
	owner.held = true
	check(builder.write_transform(35,1,frame) and not builder.owner_receipt_valid(),"Managed mutation invalidates generation receipt")
	var nodes: Array = builder.batch_nodes()
	var shader_batch: MultiMeshInstance3D = nodes[3]
	var material: ShaderMaterial = shader_batch.multimesh.mesh.surface_get_material(0)
	material.set_shader_parameter("source_roughness",.123)
	check(not builder.guard(),"Silent shader uniform mutation rejected")
	material.set_shader_parameter("source_roughness",.82)
	check(not builder.guard(),"Observed silent uniform mutation remains poisoned after restore")
	builder.dispose()
	builder = Shadow.new(); check(builder.build(data).ok,"Fresh source rebuild after poison")
	nodes = builder.batch_nodes()
	var old_mesh: Mesh = nodes[0].multimesh.mesh
	nodes[0].multimesh.mesh = BoxMesh.new()
	check(not builder.guard(),"Nested mesh replacement poisons admission")
	nodes[0].multimesh.mesh = old_mesh
	check(not builder.guard(),"Resource mutation restore cannot clear poison")
	builder.dispose(); check(not builder.guard(),"Disposed resource guard")
	var lifetime := Shadow.new(); check(lifetime.build(data).ok,"Fresh generation for lifetime check")
	lifetime.batch_nodes()[0].free()
	check(not lifetime.guard(),"Freed native batch fails weak lifetime guard")
	lifetime.dispose()
	var callback_mutation := Shadow.new(); check(callback_mutation.build(data).ok,"Callback mutation fixture")
	owner.poison_resource = callback_mutation.batch_nodes()[0].multimesh.mesh
	check(not callback_mutation.request_owner_receipt(owner,owner.seal,owner.validate) and not callback_mutation.guard(),"Owner callback resource mutation cannot suppress watcher")
	owner.poison_resource = null; callback_mutation.dispose()
	owner.free(); oracle.free()
	print(JSON.stringify({"suite":"actual-printshop-cpu-shadow","checks":checks,"failures":failures,"batches":15,"instances":280,"colors":215,"gpu":false,"actualSceneAdmitted":false,"nativeStorageReadbackClaim":false}))
	var exit_status := 0 if failures.is_empty() else 1
	print("TEST_EXIT_STATUS ",exit_status)
	quit(exit_status)
