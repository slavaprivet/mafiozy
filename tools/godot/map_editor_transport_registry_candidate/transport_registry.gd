extends RefCounted
const Document = preload("res://scripts/map_editor/map_document.gd")
const JSONTrust = preload("res://scripts/map_editor/trusted_json.gd")
const Frames = preload("res://scripts/frames.gd")
var _factory: RefCounted
var _owner := Callable()
var _records := {}
var _baseline := {}
var _raw := {}
var _copies := {}
var _bounds := {}
var _tokens := {}
var _admission := ""
var _prepared := {}
var _journal: Array[Callable] = []
var _transaction := false

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func configure(factory: RefCounted, owner: Callable = Callable()) -> Dictionary:
	if is_instance_valid(_factory) or not is_instance_valid(factory) or factory._records.size() != 265 or not factory._roots.has("parking"): return _fail("All source receipts and parking geometry required")
	_factory = factory
	_owner = owner
	for id: String in factory._records:
		var receipt: Dictionary = factory.source_record(id)
		var row := {"id":id,"kind":str(receipt.sourceRecord.kind),"model":"transport-decor:"+str(receipt.dataset),"source":{"descriptor":receipt},"transform":Frames.encode_transform(factory.current_state(id).frame)}
		_raw[id] = row.source.duplicate(true)
		row.source = JSONTrust.transport(row.source)
		_records[id] = row
		_baseline[id] = row.duplicate(true)
		_bound(id)
	# Authority is transient and admitted by the registry owner, not JSON flags.
	factory._hooks.edit_lease = func() -> bool: return _admission != ""
	factory._hooks.edit_adapter = func(request: Dictionary) -> Dictionary:
		if request.key != _admission: return {"ok":false}
		return {"ok":true,"commit":_prepared.commit,"rollback":_prepared.rollback}
	return {"ok":true,"objects":_records.size(),"nativeParking":233,"railway":"HOLD-original-textures-and-owner"}

func ids() -> Array: return _records.keys()
func has_object(id: String) -> bool: return _records.has(id)
func get_record(id: String) -> Dictionary:
	return _records[id].duplicate(true) if has_object(id) and not _factory._current[id].deleted else {}
func source_document(map_id: String) -> Dictionary:
	return {"schema_version":1,"map_id":map_id,"metadata":{},"objects":_baseline.values().duplicate(true)}
func current_document(map_id: String) -> Dictionary:
	var rows := []
	for id: String in _records:
		if not _factory._current[id].deleted: rows.append(_records[id].duplicate(true))
	return {"schema_version":1,"map_id":map_id,"metadata":{},"objects":rows}
func template_frame(id: String) -> Transform3D:
	var template: String = _copies.get(id,id)
	return Frames.decode_transform(_baseline[template].transform) if _baseline.has(template) else Transform3D.IDENTITY
static func decode_transform(data: Dictionary) -> Variant: return Frames.decode_transform(data)
static func encode_transform(frame: Transform3D) -> Dictionary: return Frames.encode_transform(frame)
func world_bounds(id: String) -> Variant:
	return _bounds.get(id) if has_object(id) and not _factory._current[id].deleted else null
func pick(origin: Vector3, direction: Vector3, distance: float = 10000) -> String:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(distance) or distance <= 0: return ""
	var nearest := distance
	var found := ""
	for id: String in _bounds:
		if _factory._current[id].deleted or not _factory._parts.has(id): continue
		var hit: Variant = (_bounds[id] as AABB).intersects_segment(origin,origin+direction.normalized()*distance)
		if hit is Vector3 and origin.distance_to(hit) < nearest:
			nearest = origin.distance_to(hit)
			found = id
	return found
func _prepare(operation: String,id: String,record: Variant,dry_run: bool) -> Dictionary:
	var template: String = _copies.get(id,id)
	if record is Dictionary: template = record.get("template_id",template)
	if not _owner.is_valid() or not _factory._parts.has(template): return _fail("Original geometry/runtime owner HOLD")
	var response: Variant = _owner.call({"operation":operation,"sourceId":id,"record":record,"sourceRecord":_baseline.get(template,{}).duplicate(true),"source_manifest_sha256":_factory._source_sha,"dryRun":dry_run,"geometryOnly":true})
	if not response is Dictionary or response.get("approved",false) != true: return _fail("Owner refused")
	if not dry_run and (not response.get("commit") is Callable or not response.commit.is_valid() or not response.get("rollback") is Callable or not response.rollback.is_valid()): return _fail("Owner transaction absent")
	return {"ok":true,"admission":response}
func is_editable(id: String) -> bool:
	return has_object(id) and _prepare("is_editable",id,_records[id],true).ok
func _check(id: String,record: Variant,trusted: Dictionary = {}) -> Dictionary:
	if trusted.is_empty():
		if not has_object(id): return _fail("Unknown source ID")
		trusted = _records[id]
	if record == null: return {"ok":true,"record":null}
	var validation := Document.validate_record(record)
	if not validation.ok: return validation
	if validation.record.id != id: return _fail("Identity mismatch")
	var supplied: Dictionary = validation.record.duplicate(true)
	var immutable := trusted.duplicate(true)
	supplied.erase("transform")
	immutable.erase("transform")
	var original := immutable.duplicate(true)
	original.source = _raw[trusted.get("template_id",id)].duplicate(true)
	if not JSONTrust.equal(supplied,immutable) and not JSONTrust.equal(supplied,original): return _fail("Trusted template descriptor changed")
	var frame: Variant = Frames.decode_transform(validation.record.transform)
	if frame == null or not frame.is_finite() or frame.basis.determinant() <= 0.000001: return _fail("Invalid transform")
	var extras: Dictionary = validation.record.transform.duplicate(true)
	var original_extras: Dictionary = trusted.transform.duplicate(true)
	for key in ["position","rotation","scale"]:
		extras.erase(key)
		original_extras.erase(key)
	if not JSONTrust.equal(extras,original_extras): return _fail("Transform metadata changed")
	validation.record.source = trusted.source.duplicate(true)
	return {"ok":true,"record":validation.record,"frame":frame}
func apply_record(id: String,record: Variant,dry_run: bool = false) -> Dictionary:
	var checked := _check(id,record)
	if not checked.ok: return checked
	if record != null and not _factory._current[id].deleted and checked.frame == Frames.decode_transform(_records[id].transform): return {"ok":true}
	var prepared := _prepare("delete" if record == null else "transform",id,record,dry_run)
	if not prepared.ok or dry_run: return prepared
	_prepared = prepared.admission
	_admission = id
	var result: Dictionary = _factory.delete_object(id) if record == null else _factory.transform_object(id,checked.frame)
	_admission = ""
	_prepared = {}
	if not result.ok: return result
	if record != null:
		_records[id] = checked.record.duplicate(true)
		if _baseline.has(id) and JSONTrust.equal(checked.record.transform,_baseline[id].transform):
			# Exact original part arrays, not Euler inverse/forward arithmetic.
			for part: Dictionary in _factory._parts[id]:
				var batch: Dictionary = _factory._batches[part.batch]
				if batch.has("multimesh"):
					batch.cpu_transforms[part.index] = batch.originals[part.index]
					batch.multimesh.set_instance_transform(part.index,batch.originals[part.index])
				else:
					batch.node.transform = batch.parent
					batch.cpu_transforms[part.index] = batch.parent
	_bound(id)
	if _transaction: _journal.append(prepared.admission.rollback)
	return {"ok":true,"id":id}
func _bound(id: String) -> void:
	var bounds: Variant = null
	for part: Dictionary in _factory._parts.get(id,[]):
		var batch: Dictionary = _factory._batches[part.batch]
		if not batch.source.has("geometry"): continue
		var frame: Transform3D = batch.parent * batch.cpu_transforms[part.index] if batch.has("multimesh") else batch.node.transform
		frame.origin -= _factory._origin
		var box: AABB = frame * _factory._meshes[batch.source.geometry].get_aabb()
		bounds = box if bounds == null else bounds.merge(box)
	if bounds != null: _bounds[id] = bounds
func _upload(batch: Dictionary) -> void:
	var mm: MultiMesh = batch.multimesh
	var stride := 16 if mm.use_colors else 12
	var buffer := PackedFloat32Array()
	buffer.resize(batch.cpu_transforms.size()*stride)
	for index in batch.cpu_transforms.size():
		var frame: Transform3D = batch.cpu_transforms[index]
		for row in 3:
			buffer[index*stride+row*4] = frame.basis.x[row]
			buffer[index*stride+row*4+1] = frame.basis.y[row]
			buffer[index*stride+row*4+2] = frame.basis.z[row]
			buffer[index*stride+row*4+3] = frame.origin[row]
		if mm.use_colors:
			for channel in 4: buffer[index*stride+12+channel] = batch.cpu_colors[index][channel]
	mm.instance_count = batch.cpu_transforms.size()
	mm.buffer = buffer
func create_copy(template_id: String,id: String,frame: Transform3D) -> Dictionary:
	template_id = _copies.get(template_id,template_id)
	if not _baseline.has(template_id) or not id.begins_with("editor:") or has_object(id): return _fail("Invalid trusted template/new ID")
	# Rail duplication requires a separate route/train/canvas owner factory; never
	# substitute static primitives or silently duplicate one dynamic car.
	if not str(_baseline[template_id].source.descriptor.dataset).begins_with("parking-"): return _fail("Rail clone HOLD trusted owner factory")
	var row: Dictionary = _baseline[template_id].duplicate(true)
	row.id = id
	row.template_id = template_id
	row.transform = encode_transform(frame)
	var checked := _check(id,row,row)
	if not checked.ok: return checked
	var prepared := _prepare("create_copy",id,row,false)
	if not prepared.ok: return prepared
	var checkpoint := capture_install_checkpoint()
	if not checkpoint.ok: return checkpoint
	_factory._records[id] = _factory._records[template_id].duplicate(true)
	_factory._source_frames[id] = _factory._source_frames[template_id]
	_factory._current[id] = {"frame":frame,"deleted":false}
	_factory._parts[id] = []
	var source_target := Transform3D(frame.basis,frame.origin+_factory._origin)
	var delta: Transform3D = source_target * _factory._source_frames[template_id].affine_inverse()
	for part: Dictionary in _factory._parts[template_id]:
		var batch: Dictionary = _factory._batches[part.batch]
		if not batch.has("multimesh"):
			restore_install_checkpoint(checkpoint)
			return _fail("Clone needs original instanced source")
		batch.source = batch.source.duplicate(true)
		var index: int = batch.cpu_transforms.size()
		var original: Transform3D = batch.originals[part.index]
		batch.originals.append(original)
		batch.cpu_transforms.append(batch.parent.affine_inverse()*delta*batch.parent*original)
		batch.cpu_colors.append(batch.cpu_colors[part.index])
		batch.source.objectKeys.append(id)
		batch.source.count = batch.cpu_transforms.size()
		_factory._parts[id].append({"batch":part.batch,"index":index})
		_upload(batch)
	_records[id] = row
	_copies[id] = template_id
	_factory._apply_state(id,_factory._current[id]) # Refresh conservative MM AABB.
	_bound(id)
	if prepared.admission.commit.call() != true:
		restore_install_checkpoint(checkpoint)
		if prepared.admission.rollback.call() != true: _factory._broken_transaction = true
		return _fail("Clone owner commit failed")
	if _transaction: _journal.append(prepared.admission.rollback)
	return {"ok":true,"record":row.duplicate(true)}
func discard_copy(id: String) -> void:
	if not _copies.has(id) or not apply_record(id,null).ok: return
	for part: Dictionary in _factory._parts[id]: _factory._batches[part.batch].source.objectKeys[part.index] = ""
	for name in ["_records","_parts","_source_frames","_current"]: _factory.get(name).erase(id)
	_factory._history.assign(_factory._history.filter(func(command: Dictionary) -> bool: return command.key != id))
	_factory._redo.assign(_factory._redo.filter(func(command: Dictionary) -> bool: return command.key != id))
	_records.erase(id)
	_copies.erase(id)
	_bounds.erase(id)
func capture_install_checkpoint() -> Dictionary:
	for key in _tokens.keys():
		if not is_instance_valid(_tokens[key].token.get_ref()): _tokens.erase(key)
	var state := {"factory":{},"records":_records.duplicate(true),"copies":_copies.duplicate(true),"bounds":_bounds.duplicate(true),"nodes":[],"render":{}}
	for name in ["_records","_source_frames","_current","_parts","_batches","_history","_redo"]: state.factory[name] = _factory.get(name).duplicate(true)
	for node: Node in _factory._roots.values():
		if not is_instance_valid(node) or not node.is_inside_tree(): return _fail("Owned live root required")
		state.nodes.append({"node":weakref(node),"parent":weakref(node.get_parent())})
	for key: String in _factory._batches:
		var batch: Dictionary = _factory._batches[key]
		if not is_instance_valid(batch.node) or not batch.node.is_inside_tree(): return _fail("Owned live batch required")
		state.nodes.append({"node":weakref(batch.node),"parent":weakref(batch.node.get_parent())})
		state.render[key] = {"frame":batch.node.transform,"visible":batch.node.visible}
		if batch.has("multimesh"): state.render[key].merge({"mm":batch.multimesh,"mesh":batch.multimesh.mesh,"bounds":batch.multimesh.custom_aabb,"material":batch.node.material_override})
	var token := RefCounted.new()
	_tokens[token.get_instance_id()] = {"token":weakref(token),"state":state}
	return {"ok":true,"registry":weakref(self),"token":token}
func restore_install_checkpoint(capsule: Dictionary) -> Dictionary:
	if not is_instance_valid(_factory): return _fail("Factory lifetime ended")
	if not capsule.get("registry") is WeakRef or capsule.registry.get_ref() != self or not capsule.get("token") is RefCounted or not _tokens.has(capsule.token.get_instance_id()): return _fail("Unadmitted checkpoint")
	if _tokens[capsule.token.get_instance_id()].token.get_ref() != capsule.token: return _fail("Checkpoint token lifetime ended")
	var state: Dictionary = _tokens[capsule.token.get_instance_id()].state
	for dependency: Dictionary in state.nodes:
		var node: Variant = dependency.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.get_parent() != dependency.parent.get_ref(): return _fail("Owner dependency lost; retain pause")
	for key: String in state.render:
		var render: Dictionary = state.render[key]
		if render.has("mm") and (_factory._batches[key].node.multimesh != render.mm or render.mm.mesh != render.mesh or _factory._batches[key].node.material_override != render.material): return _fail("MultiMesh/material owner replaced")
	for name in state.factory: _factory.set(name,state.factory[name].duplicate(true))
	_records = state.records.duplicate(true)
	_copies = state.copies.duplicate(true)
	_bounds = state.bounds.duplicate(true)
	for key: String in state.render:
		var batch: Dictionary = _factory._batches[key]
		var render: Dictionary = state.render[key]
		batch.node.transform = render.frame
		batch.node.visible = render.visible
		if render.has("mm"):
			batch.multimesh.mesh = render.mesh
			_upload(batch)
			batch.multimesh.custom_aabb = render.bounds
	return {"ok":true}
func apply_document(document: Dictionary,dry_run: bool = false) -> Dictionary:
	var checked := Document.validate_document(document)
	if not checked.ok: return checked
	var desired := {}
	for row: Dictionary in checked.document.objects:
		if not has_object(row.id):
			if not row.id.begins_with("editor:") or not _baseline.has(row.get("template_id","")): return _fail("Unknown clone template")
			var trusted: Dictionary = _baseline[row.template_id].duplicate(true)
			trusted.id = row.id
			trusted.template_id = row.template_id
			var valid := _check(row.id,row,trusted)
			if not valid.ok: return valid
			var prepared := _prepare("create_copy",row.id,row,true)
			if not prepared.ok: return prepared
			if not str(trusted.source.descriptor.dataset).begins_with("parking-"): return _fail("Rail clone HOLD")
		else:
			var valid := apply_record(row.id,row,true)
			if not valid.ok: return valid
		desired[row.id] = row
	for id: String in _records:
		if not desired.has(id) and not _factory._current[id].deleted:
			var valid := apply_record(id,null,true)
			if not valid.ok: return valid
	if dry_run: return {"ok":true}
	var checkpoint := capture_install_checkpoint()
	if not checkpoint.ok: return checkpoint
	_transaction = true
	_journal.clear()
	var failure := {}
	for id: String in desired:
		if not has_object(id):
			var created := create_copy(desired[id].template_id,id,decode_transform(desired[id].transform))
			if not created.ok:
				failure = created
				break
		var applied := apply_record(id,desired[id])
		if not applied.ok:
			failure = applied
			break
	if failure.is_empty():
		for id: String in _records.keys():
			if not desired.has(id) and not _factory._current[id].deleted:
				var applied := apply_record(id,null)
				if not applied.ok:
					failure = applied
					break
	_transaction = false
	if not failure.is_empty():
		var restored := restore_install_checkpoint(checkpoint)
		var rollback_ok: bool = restored.ok
		for index in range(_journal.size()-1,-1,-1): rollback_ok = (_journal[index].call() == true) and rollback_ok
		failure.rollback_ok = rollback_ok
		if not rollback_ok: _factory._broken_transaction = true
		_journal.clear()
		return failure
	_journal.clear()
	return {"ok":true}

func dispose() -> void:
	if is_instance_valid(_factory):
		_factory._hooks.erase("edit_lease")
		_factory._hooks.erase("edit_adapter")
	_factory = null
	_owner = Callable()
	_tokens.clear()
	_prepared.clear()
	_journal.clear()
