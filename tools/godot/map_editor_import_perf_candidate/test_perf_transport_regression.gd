extends SceneTree
const Factory = preload("res://transport_decor_factory.gd")
const Registry = preload("res://transport_registry_perf.gd")
var failures: Array[String] = []
var checks := 0
var fail_commit := false
var fail_at := -1
var commits := 0
var rollbacks := 0
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func owner(request: Dictionary) -> Dictionary:
	return {"approved":true,"commit":func() -> bool:
		commits += 1
		return not fail_commit and commits != fail_at,"rollback":func() -> bool:
		rollbacks += 1
		return true}
func build() -> Dictionary:
	var factory := Factory.new()
	var admitted: Dictionary = factory.configure("res://transport_source","69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b")
	check(admitted.ok,"admit")
	var parking: Dictionary = factory.build_parking()
	check(parking.ok,"parking")
	root.add_child(parking.root)
	var registry := Registry.new()
	check(registry.configure(factory,Callable(self,"owner")).ok,"registry configure")
	return {"factory":factory,"registry":registry}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var first := build()
	var factory: RefCounted = first.factory
	var registry: RefCounted = first.registry
	check(registry.ids().size()==265,"all265 IDs")
	var editable := 0
	for id: String in registry.ids():
		check(registry.has_object(id),"ID indexed")
		check(not registry.get_record(id).is_empty(),"baseline JSON")
		check(Registry.Document.validate_record(registry.get_record(id)).ok,"core record")
		if registry.is_editable(id): editable += 1
	check(editable==233,"parking233 editable, rail32 held")
	var id: String = ""
	for candidate: String in registry.ids():
		if candidate.begins_with("parking-bays:"):
			id = candidate
			break
	var baseline: Dictionary = registry.get_record(id)
	var frames: Array = []
	var resources := []
	for part: Dictionary in factory._parts[id]:
		var batch: Dictionary = factory._batches[part.batch]
		frames.append(batch.cpu_transforms[part.index])
		resources.append(batch.multimesh.mesh)
	var moved := baseline.duplicate(true)
	moved.transform.position[0] += 12.0
	check(registry.apply_record(id,moved,true).ok,"dryrun")
	check(registry.get_record(id)==baseline,"dryrun read-only")
	check(registry.apply_record(id,moved).ok,"move")
	check(registry.apply_record(id,null).ok,"delete")
	check(registry.get_record(id).is_empty(),"deleted presence")
	check(registry.apply_record(id,baseline).ok,"record undo")
	for index in frames.size():
		var part: Dictionary = factory._parts[id][index]
		check(factory.cpu_instance(part.batch,part.index)==frames[index],"original part transform EXACT restored")
		check(factory._batches[part.batch].multimesh.mesh==resources[index],"resource identity restored")
	var cp: Dictionary = registry.capture_install_checkpoint()
	check(cp.ok,"checkpoint")
	var clone: Dictionary = registry.create_copy(id,"editor:parking-qa-copy",Registry.decode_transform(moved.transform))
	check(clone.ok,"native shared clone")
	check(registry.get_record("editor:parking-qa-copy").source==baseline.source,"clone template exact")
	for index in frames.size():
		var part: Dictionary = factory._parts["editor:parking-qa-copy"][index]
		check(factory._batches[part.batch].multimesh.mesh==resources[index],"clone shared mesh")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(registry.current_document("transport-qa"),"",true,true))
	check(saved.objects.size()==266,"save266")
	var second := build()
	check(second.registry.apply_document(saved,true).ok,"fresh preflight")
	check(second.registry.apply_document(saved).ok,"fresh apply")
	check(second.registry.has_object("editor:parking-qa-copy"),"fresh clone identity")
	check(second.registry.get_record("editor:parking-qa-copy").source==baseline.source,"fresh trusted source")
	for cycle in 3:
		saved = JSON.parse_string(JSON.stringify(second.registry.current_document("transport-qa"),"",true,true))
		check(second.registry.apply_document(saved).ok,"multiple cycle")
	check(registry.restore_install_checkpoint(cp).ok,"restore clone checkpoint")
	check(not registry.has_object("editor:parking-qa-copy"),"checkpoint removes copy")
	check(not registry.restore_install_checkpoint({"ok":true,"registry":weakref(registry),"token":RefCounted.new()}).ok,"checkpoint forgery refused")
	var first_part: Dictionary = factory._parts[id][0]
	var first_batch: Dictionary = factory._batches[first_part.batch]
	var material: Material = first_batch.node.material_override
	first_batch.node.material_override = StandardMaterial3D.new()
	check(not registry.restore_install_checkpoint(cp).ok,"replaced material dependency refuses checkpoint")
	first_batch.node.material_override = material
	fail_commit = true
	check(not registry.apply_record(id,moved).ok,"owner failure")
	check(registry.get_record(id)==baseline,"failure record restored")
	check(rollbacks>0,"owner rollback")
	fail_commit = false
	var two_changes: Dictionary = registry.current_document("transport-qa")
	var changed_ids: Array[String] = []
	for row: Dictionary in two_changes.objects:
		if row.id.begins_with("parking-bays:"):
			changed_ids.append(row.id)
			row.transform.position[0] += 4.0
			if changed_ids.size()==2: break
	var before_rollbacks := rollbacks
	fail_at = commits+2
	check(not registry.apply_document(two_changes).ok,"second owner failure aborts document")
	fail_at = -1
	for changed_id: String in changed_ids:
		check(registry.get_record(changed_id)==registry._baseline[changed_id],"whole failure restores earlier record")
	check(rollbacks>=before_rollbacks+2,"failed and earlier owner commits reversed")
	fail_commit = true
	check(not registry.create_copy(id,"editor:failed-copy",registry.template_frame(id)).ok,"failed clone commit")
	check(not registry.has_object("editor:failed-copy"),"failed clone leaves no identity")
	fail_commit = false
	var forged := baseline.duplicate(true)
	forged.source.descriptor.sourceRecord.yaw += 0.00000001
	check(not registry.apply_record(id,forged,true).ok,"source tampering refused")
	var adjacent := baseline.duplicate(true)
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0,float(adjacent.source.descriptor.sourceRecord.proxy.x))
	bytes.encode_u64(0,bytes.decode_u64(0)+1)
	adjacent.source.descriptor.sourceRecord.proxy.x = bytes.decode_double(0)
	check(not registry.apply_record(id,adjacent,true).ok,"adjacent ULP source refused, caller not normalized")
	var rail: String = ""
	for candidate: String in registry.ids():
		if candidate.begins_with("railway-"):
			rail = candidate
			break
	check(not registry.is_editable(rail),"rail absent visual remains locked")
	check(not registry.create_copy(rail,"editor:rail-qa",registry.template_frame(rail)).ok,"rail clone held")
	# Failed whole-document install reverses all successful external commits.
	var install: Dictionary = registry.current_document("transport-qa")
	install.objects[0].transform.position[0] += 2.0
	var bad: Dictionary = install.duplicate(true)
	bad.objects[-1].source.descriptor.id = "attacker"
	var before_commits := commits
	check(not registry.apply_document(bad).ok,"whole document source tampering refused")
	check(commits==before_commits,"preflight never partially commits")
	var root_node: Node = factory._roots.parking
	var parent: Node = root_node.get_parent()
	parent.remove_child(root_node)
	check(not registry.restore_install_checkpoint(cp).ok,"detached dependency refuses checkpoint")
	parent.add_child(root_node)
	print("TRANSPORT_REGISTRY_QA "+JSON.stringify({"checks":checks,"failures":failures,"baseline":265,"parkingEditableMockOwner":editable,"railHeld":32,"scope":"native shared resource clone/freshload; runtime authority mock, no GPU"}))
	second.registry.dispose()
	registry.dispose()
	second.factory.dispose()
	factory.dispose()
	quit(0 if failures.is_empty() else 1)
