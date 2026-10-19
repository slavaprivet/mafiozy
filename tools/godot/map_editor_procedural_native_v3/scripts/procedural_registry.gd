extends RefCounted
## Core-compatible JSON records, source-admitted MM/paint editor identity adapter.
const Document = preload("res://scripts/map_editor/map_document.gd")
const TrustedJSON = preload("res://scripts/map_editor/trusted_json.gd")
var _factory: RefCounted
var _owner := Callable()
var _records: Dictionary = {}
var _baseline: Dictionary = {}
var _raw_sources: Dictionary = {}
var _copies: Dictionary = {}
var _bounds: Dictionary = {}
var _admission_id := ""
var _checkpoints: Dictionary = {}
var _journal: Array[Callable] = []
var _document_transaction := false

func configure(factory: RefCounted, trusted_owner: Callable = Callable()) -> Dictionary:
	if is_instance_valid(_factory) or not is_instance_valid(factory) or not factory.errors.is_empty() or factory._parts.is_empty() or factory._paint_ids.is_empty():
		return _fail("Both source geometry systems must be admitted/built")
	_factory = factory
	_owner = trusted_owner
	var all_ids: Array = factory._parts.keys() + factory._paint_ids.keys()
	for id: String in all_ids:
		var descriptor: Dictionary = factory._source_records[id].duplicate(true)
		var row := {"id":id,"kind":str(descriptor.kind),"model":"procedural:" + str(descriptor.kind),"source":{"dataset":"roads" if factory._road_ids.has(id) or factory._paint_ids.has(id) else "exploration","descriptor":descriptor},"transform":encode_transform(factory.object_transform(id))}
		_raw_sources[id] = row.source.duplicate(true)
		row.source = JSON.parse_string(JSON.stringify(row.source,"",true,true))
		_records[id] = row
		_baseline[id] = row.duplicate(true)
		_rebuild_bound(id)
	# Only registry-prepared trusted transactions may write road geometry.
	factory._road_adapter = Callable(self, "_admit_factory")
	return {"ok":true,"objects":_records.size(),"authority":"owner-callable-required"}

func ids() -> Array:
	return _records.keys()

func has_object(id: String) -> bool:
	return _records.has(id)

func is_editable(id: String) -> bool:
	return has_object(id) and _owner.is_valid() and _prepare("is_editable",id,_records[id],true).ok

func get_record(id: String) -> Dictionary:
	return _records[id].duplicate(true) if has_object(id) and not _factory._deleted.get(id, false) else {}

func source_document(map_id: String) -> Dictionary:
	return {"schema_version":1,"map_id":map_id,"metadata":{},"objects":_baseline.values().duplicate(true)}

func current_document(map_id: String) -> Dictionary:
	var rows: Array = []
	for id: String in _records:
		if not _factory._deleted.get(id, false): rows.append(_records[id].duplicate(true))
	return {"schema_version":1,"map_id":map_id,"metadata":{},"objects":rows}

func template_frame(id: String) -> Transform3D:
	var original: String = _copies.get(id, id)
	return _decode(_baseline[original].transform) if _baseline.has(original) else Transform3D.IDENTITY

func world_bounds(id: String) -> Variant:
	return _bounds.get(id) if has_object(id) and not _factory._deleted.get(id, false) else null

func pick(origin: Vector3, direction: Vector3, distance: float = 10000.0) -> String:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(distance) or distance <= 0:
		return ""
	var end := origin + direction.normalized() * distance
	var nearest := distance
	var selected := ""
	for id: String in _bounds:
		if _factory._deleted.get(id, false): continue
		var hit: Variant = (_bounds[id] as AABB).intersects_segment(origin, end)
		if hit is Vector3:
			var length := origin.distance_to(hit)
			if length < nearest:
				nearest = length
				selected = id
	return selected

static func encode_transform(frame: Transform3D) -> Dictionary:
	var rotation := frame.basis.orthonormalized().get_euler()
	var scale := frame.basis.get_scale()
	return {"position":[frame.origin.x,frame.origin.y,frame.origin.z],"rotation":[rotation.x,rotation.y,rotation.z],"scale":[scale.x,scale.y,scale.z]}

static func _decode(data: Dictionary) -> Variant:
	var vectors: Array[Vector3] = []
	for key in ["position","rotation","scale"]:
		var array: Variant = data.get(key)
		if not array is Array or array.size() != 3: return null
		for number in array:
			if not typeof(number) in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)): return null
		vectors.append(Vector3(array[0],array[1],array[2]))
	if vectors[2].x < 0.0001 or vectors[2].y < 0.0001 or vectors[2].z < 0.0001: return null
	return Transform3D(Basis.from_euler(vectors[1]).scaled_local(vectors[2]),vectors[0])

static func decode_transform(data: Dictionary) -> Variant:
	return _decode(data)

static func _equal(a: Variant, b: Variant) -> bool:
	return TrustedJSON.equal(a,b)

func _check(id: String, record: Variant, trusted: Dictionary = {}) -> Dictionary:
	if trusted.is_empty():
		if not has_object(id): return _fail("Unknown procedural identity")
		trusted = _records[id]
	if record == null: return {"ok":true,"record":null,"frame":null}
	var checked := Document.validate_record(record)
	if not checked.ok: return checked
	if checked.record.id != id: return _fail("Identity mismatch")
	var supplied: Dictionary = checked.record.duplicate(true)
	var immutable := trusted.duplicate(true)
	supplied.erase("transform")
	immutable.erase("transform")
	var raw_variant := immutable.duplicate(true)
	var baseline_id: String = trusted.get("template_id",id)
	if _raw_sources.has(baseline_id): raw_variant.source = _raw_sources[baseline_id].duplicate(true)
	if not _equal(supplied,immutable) and not _equal(supplied,raw_variant): return _fail("Trusted source/model/template cannot change: " + id)
	# Do not normalize the caller during validation. Only the exact admitted raw
	# or once-canonical trusted source is accepted. Issue canonical trusted data.
	checked.record.source = trusted.source.duplicate(true)
	var extras: Dictionary = checked.record.transform.duplicate(true)
	var trusted_extras: Dictionary = trusted.transform.duplicate(true)
	for key in ["position","rotation","scale"]:
		extras.erase(key)
		trusted_extras.erase(key)
	if not _equal(extras, trusted_extras): return _fail("Unknown transform metadata cannot change")
	var frame: Variant = _decode(checked.record.transform)
	if frame == null or not frame.is_finite() or frame.basis.determinant() <= 0.000001: return _fail("Invalid frame")
	if _factory._paint_ids.has(id) or _factory._paint_ids.has(trusted.get("template_id","")):
		if not frame.basis.y.normalized().is_equal_approx(Vector3.UP): return _fail("Road paint must stay upright")
	return {"ok":true,"record":checked.record,"frame":frame}

func _prepare(operation: String, id: String, record: Variant, dry_run: bool) -> Dictionary:
	if not _owner.is_valid(): return _fail("Gameplay/collider/navigation owner adapter required")
	var prepared: Variant = _owner.call({"operation":operation,"sourceId":id,"record":record.duplicate(true) if record is Dictionary else null,"sourceRecord":_records.get(id, {}).duplicate(true),"dryRun":dry_run,"geometryOnly":true})
	if not prepared is Dictionary or prepared.get("approved",false) != true: return _fail("Owner refused action")
	if not dry_run and (not prepared.get("commit") is Callable or not prepared.commit.is_valid() or not prepared.get("rollback") is Callable or not prepared.rollback.is_valid()): return _fail("Owner transaction callbacks missing")
	return {"ok":true,"admission":prepared}

func apply_record(id: String, record: Variant, dry_run: bool = false) -> Dictionary:
	var checked := _check(id, record)
	if not checked.ok: return checked
	if record != null and not _factory._deleted.get(id,false) and checked.frame == _decode(_records[id].transform): return {"ok":true,"id":id}
	var prepared := _prepare("delete" if record == null else "transform",id,record,dry_run)
	if not prepared.ok or dry_run: return prepared
	var previous_history: Array = _factory._history.duplicate(true)
	var previous_redo: Array = _factory._redo.duplicate(true)
	var visual: Dictionary = _factory._road_visual_capture.call() if (_factory._road_ids.has(id) or _factory._paint_ids.has(id)) and _factory._road_visual_capture.is_valid() else {}
	var inverse := false
	_admission_id = id
	var applied: bool
	if not _factory._history.is_empty() and _matches_command(_factory._history.back(),id,checked,false):
		inverse = true
		applied = _factory.undo()
	elif not _factory._redo.is_empty() and _matches_command(_factory._redo.back(),id,checked,true):
		applied = _factory.redo()
	elif record == null:
		applied = _factory.delete_object(id)
	elif _baseline.has(id) and _equal(checked.record.transform,_baseline[id].transform) and not _factory._paint_ids.has(id):
		var original_parts: Array[Transform3D] = []
		for part: Dictionary in _factory._parts[id]: original_parts.append(part.original)
		var source: Transform3D = _factory._source_frames[id]
		source.origin -= _factory._origin
		applied = _factory._commit(id,original_parts,false,source)
	else:
		applied = _factory.set_object_transform(id,checked.frame)
	_admission_id = ""
	if not applied: return _fail("Geometry adapter refused")
	if prepared.admission.commit.call() != true:
		var command: Dictionary = previous_history.back() if inverse else _factory._history.back()
		_factory._apply_command(command,inverse)
		_factory._current_frames[id] = command.frameAfter if inverse else command.frameBefore
		_factory._deleted[id] = command.deletedAfter if inverse else command.deletedBefore
		_factory._history.assign(previous_history)
		_factory._redo.assign(previous_redo)
		if visual.get("ok",false): _factory._road_visual_restore.call(visual)
		prepared.admission.rollback.call()
		return _fail("Owner commit failed; geometry rolled back")
	if record != null: _records[id] = checked.record.duplicate(true)
	_rebuild_bound(id)
	if _document_transaction: _journal.append(prepared.admission.rollback)
	return {"ok":true,"id":id}

func _matches_command(command: Dictionary, id: String, checked: Dictionary, forward: bool) -> bool:
	if command.id != id: return false
	var deleted: bool = command.deletedAfter if forward else command.deletedBefore
	if checked.record == null: return deleted
	if deleted: return false
	var frame: Transform3D = command.frameAfter if forward else command.frameBefore
	return checked.frame.is_equal_approx(frame)

func _admit_factory(request: Dictionary) -> Dictionary:
	if _admission_id != str(request.sourceId): return {"approved":false}
	return {"approved":true,"commit":Callable(self,"_accept"),"rollback":Callable(self,"_noop")}

func _accept() -> bool: return true
func _noop() -> void: pass

func create_copy(template_id: String, id: String, frame: Transform3D) -> Dictionary:
	var baseline_id: String = _copies.get(template_id,template_id)
	if not _baseline.has(baseline_id) or not id.begins_with("editor:") or id.length() > 512 or has_object(id) or not frame.is_finite() or frame.basis.determinant() <= 0.000001: return _fail("Invalid admitted template/copy identity/frame")
	var record: Dictionary = _baseline[baseline_id].duplicate(true)
	record.id = id
	record.template_id = baseline_id
	record.transform = encode_transform(frame)
	var checked := _check(id,record,record)
	if not checked.ok: return checked
	var prepared := _prepare("create_copy",id,record,false)
	if not prepared.ok: return prepared
	var capsule := capture_install_checkpoint()
	if not capsule.ok: return capsule
	_factory._source_frames[id] = _factory._source_frames[baseline_id]
	_factory._current_frames[id] = frame
	_factory._source_records[id] = _factory._source_records[baseline_id].duplicate(true)
	_factory._source_records[id].id = id
	var delta := Transform3D(frame.basis,frame.origin + _factory._origin) * (_factory._source_frames[baseline_id] as Transform3D).affine_inverse()
	if _factory._paint_ids.has(baseline_id):
		_clone_paint(baseline_id,id,delta)
	else:
		_clone_parts(baseline_id,id,delta)
	_records[id] = record.duplicate(true)
	_copies[id] = baseline_id
	_rebuild_bound(id)
	if prepared.admission.commit.call() != true:
		restore_install_checkpoint(capsule)
		prepared.admission.rollback.call()
		return _fail("Owner clone commit failed; exact checkpoint restored")
	if _factory._road_visual_dirty.is_valid() and (_factory._road_ids.has(id) or _factory._paint_ids.has(id)): _factory._road_visual_dirty.call(id)
	if _document_transaction: _journal.append(prepared.admission.rollback)
	return {"ok":true,"record":record.duplicate(true)}

func _clone_parts(template_id: String, id: String, delta: Transform3D) -> void:
	_factory._parts[id] = []
	var touched: Dictionary = {}
	for original: Dictionary in _factory._parts[template_id]:
		var batch: Dictionary = _factory._batches[original.batch]
		if not touched.has(original.batch): batch.source = batch.source.duplicate(true)
		var index: int = batch.transforms.size()
		batch.transforms.append(delta * original.original)
		batch.colors.append(original.color)
		batch.source.objectIds.append(id)
		batch.source.count = batch.transforms.size()
		var part := original.duplicate(true)
		part.index = index
		part.template_index = original.index
		part.template_id = template_id
		_factory._parts[id].append(part)
		touched[original.batch] = true
	if _factory._road_ids.has(template_id): _factory._road_ids[id] = true
	for key in touched:
		_upload(key)
		var chunk: String = _factory._batches[key].chunk
		if chunk.is_empty(): _factory._recompute_road_bounds(key)
		else: _factory._recompute_bounds(chunk)

func _upload(key: String) -> void:
	var batch: Dictionary = _factory._batches[key]
	var mm: MultiMesh = batch.mesh
	var stride := 16 if mm.use_colors else 12
	var buffer := PackedFloat32Array()
	buffer.resize(batch.transforms.size() * stride)
	for index in batch.transforms.size():
		var frame: Transform3D = batch.transforms[index]
		for row in 3:
			buffer[index * stride + row * 4] = frame.basis.x[row]
			buffer[index * stride + row * 4 + 1] = frame.basis.y[row]
			buffer[index * stride + row * 4 + 2] = frame.basis.z[row]
			buffer[index * stride + row * 4 + 3] = frame.origin[row]
		if mm.use_colors:
			var tint: Color = batch.colors[index]
			for channel in 4: buffer[index * stride + 12 + channel] = tint[channel]
	mm.instance_count = batch.transforms.size()
	mm.buffer = buffer
	batch.current_native_buffer = buffer

func _clone_paint(template_id: String, id: String, delta: Transform3D) -> void:
	var original: Dictionary = _factory._paint_ids[template_id]
	var batch: Dictionary = _factory._paint_batches[original.batch]
	batch.source = batch.source.duplicate(true)
	batch.arrays = batch.arrays.duplicate(true)
	var first: int = batch.current.size()
	var baseline: PackedVector3Array = batch.base.duplicate()
	var current: PackedVector3Array = batch.current.duplicate()
	var normals: PackedVector3Array = batch.arrays[Mesh.ARRAY_NORMAL].duplicate()
	for vertex in range(int(original.first),int(original.first)+6):
		baseline.append(batch.base[vertex])
		current.append(delta * batch.base[vertex])
		normals.append(batch.arrays[Mesh.ARRAY_NORMAL][vertex])
	var indices: PackedInt32Array = batch.arrays[Mesh.ARRAY_INDEX].duplicate()
	for offset in [0,2,1,3,5,4]: indices.append(first + offset)
	batch.base = baseline
	batch.current = current
	batch.arrays[Mesh.ARRAY_VERTEX] = current
	batch.arrays[Mesh.ARRAY_NORMAL] = normals
	batch.arrays[Mesh.ARRAY_INDEX] = indices
	var replacement := ArrayMesh.new()
	replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,batch.arrays)
	replacement.set_meta("source_geometry",_factory._meshes[batch.source.geometry].get_meta("source_geometry"))
	batch.node.mesh = replacement
	batch.source.objectIds.append(id)
	batch.source.count = batch.source.objectIds.size()
	_factory._paint_ids[id] = {"batch":original.batch,"first":first,"count":6}

func discard_copy(id: String) -> void:
	if not _copies.has(id): return
	if not apply_record(id,null).ok: return
	if _factory._paint_ids.has(id):
		var part: Dictionary = _factory._paint_ids[id]
		var batch: Dictionary = _factory._paint_batches[part.batch]
		batch.source = batch.source.duplicate(true)
		batch.source.objectIds[floori(float(part.first) / 6.0)] = ""
		_factory._paint_ids.erase(id)
	else:
		for part: Dictionary in _factory._parts[id]:
			var batch: Dictionary = _factory._batches[part.batch]
			batch.source = batch.source.duplicate(true)
			batch.source.objectIds[part.index] = ""
		_factory._parts.erase(id)
	_factory._road_ids.erase(id)
	_factory._history.assign(_factory._history.filter(func(command: Dictionary) -> bool: return command.id != id))
	_factory._redo.assign(_factory._redo.filter(func(command: Dictionary) -> bool: return command.id != id))
	for name in ["_source_frames","_current_frames","_source_records","_deleted"]: _factory.get(name).erase(id)
	_records.erase(id)
	_copies.erase(id)
	_bounds.erase(id)

func _rebuild_bound(id: String) -> void:
	var box: Variant = null
	if _factory._paint_ids.has(id):
		var part: Dictionary = _factory._paint_ids[id]
		var vertices: PackedVector3Array = _factory._paint_batches[part.batch].current
		for index in range(int(part.first),int(part.first)+6):
			var point: Vector3 = vertices[index] - _factory._origin
			box = AABB(point,Vector3.ZERO) if box == null else box.expand(point)
		box = box.grow(0.01)
	else:
		for part: Dictionary in _factory._parts[id]:
			var batch: Dictionary = _factory._batches[part.batch]
			var frame: Transform3D = batch.transforms[part.index]
			frame.origin -= _factory._origin
			var part_box: AABB = frame * _factory._meshes[batch.source.geometry].get_aabb()
			box = part_box if box == null else box.merge(part_box)
	_bounds[id] = box

func capture_install_checkpoint() -> Dictionary:
	for key in _checkpoints.keys():
		if not is_instance_valid(_checkpoints[key].token.get_ref()): _checkpoints.erase(key)
	var token := RefCounted.new()
	var state := {"records":_records.duplicate(true),"copies":_copies.duplicate(true),"bounds":_bounds.duplicate(true),"factory":{},"render":{},"paint":{},"dependencies":[]}
	if _factory._road_visual_capture.is_valid():
		state.visual = _factory._road_visual_capture.call()
		if not state.visual.get("ok",false): return _fail("Visual checkpoint refused")
	for name in ["_parts","_batches","_chunks","_source_frames","_current_frames","_source_records","_deleted","_history","_redo","_road_ids","_paint_ids","_paint_batches"]:
		state.factory[name] = _factory.get(name).duplicate(true)
	for key in _factory._batches:
		var batch: Dictionary = _factory._batches[key]
		state.render[key] = {"mesh":batch.mesh.mesh,"aabb":batch.mesh.custom_aabb,"visible":batch.node.visible}
	for key in _factory._paint_batches:
		state.paint[key] = {"mesh":_factory._paint_batches[key].node.mesh,"visible":_factory._paint_batches[key].node.visible}
	var nodes: Array = [_factory._root,_factory._roads_root]
	for chunk: Dictionary in _factory._chunks.values(): nodes.append(chunk.node)
	for batch: Dictionary in _factory._batches.values(): nodes.append(batch.node)
	for batch: Dictionary in _factory._paint_batches.values(): nodes.append(batch.node)
	for node: Node in nodes:
		if not is_instance_valid(node) or not node.is_inside_tree() or not is_instance_valid(node.get_parent()): return _fail("Checkpoint requires original live owned parents")
		state.dependencies.append({"node":weakref(node),"parent":weakref(node.get_parent())})
	_checkpoints[token.get_instance_id()] = {"token":weakref(token),"state":state}
	return {"ok":true,"registry":weakref(self),"token":token,"geometryOnly":true}

func restore_install_checkpoint(capsule: Dictionary) -> Dictionary:
	if not capsule.get("registry") is WeakRef or capsule.registry.get_ref() != self or not capsule.get("token") is RefCounted or not _checkpoints.has(capsule.token.get_instance_id()): return _fail("Unadmitted host checkpoint")
	var state: Dictionary = _checkpoints[capsule.token.get_instance_id()].state
	for dependency: Dictionary in state.dependencies:
		var node: Variant = dependency.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.get_parent() != dependency.parent.get_ref(): return _fail("Original dependency moved/destroyed; keep owner paused")
	for batch: Dictionary in state.factory._batches.values():
		if not is_instance_valid(batch.node) or not is_instance_valid(batch.mesh) or batch.node.multimesh != batch.mesh: return _fail("Original instance dependency replaced; keep owner paused")
	for batch: Dictionary in state.factory._paint_batches.values():
		if not is_instance_valid(batch.node): return _fail("Original paint dependency destroyed; keep owner paused")
	for name in state.factory: _factory.set(name,state.factory[name].duplicate(true))
	_records = state.records.duplicate(true)
	_copies = state.copies.duplicate(true)
	_bounds = state.bounds.duplicate(true)
	for key in _factory._batches:
		var saved: Dictionary = state.render[key]
		_factory._batches[key].mesh.mesh = saved.mesh
		_upload(key)
		_factory._batches[key].mesh.custom_aabb = saved.aabb
		_factory._batches[key].node.visible = saved.visible
	for key in _factory._paint_batches:
		_factory._paint_batches[key].node.mesh = state.paint[key].mesh
		_factory._paint_batches[key].node.visible = state.paint[key].visible
	if state.has("visual"):
		if not _factory._road_visual_restore.is_valid(): return _fail("Visual checkpoint owner disappeared")
		var restored: Dictionary = _factory._road_visual_restore.call(state.visual)
		if not restored.ok: return restored
	return {"ok":true,"geometryOnly":true}

func apply_document(document: Dictionary, dry_run: bool = false) -> Dictionary:
	var checked := Document.validate_document(document)
	if not checked.ok: return checked
	var desired: Dictionary = {}
	for row: Dictionary in checked.document.objects:
		if not has_object(row.id):
			if not row.id.begins_with("editor:") or not _baseline.has(row.get("template_id","")): return _fail("Unknown admitted clone template")
			var trusted: Dictionary = _baseline[row.template_id].duplicate(true)
			trusted.id = row.id
			trusted.template_id = row.template_id
			var validation := _check(row.id,row,trusted)
			if not validation.ok: return validation
			var admission := _prepare("create_copy",row.id,row,true)
			if not admission.ok: return admission
		else:
			var validation := apply_record(row.id,row,true)
			if not validation.ok: return validation
		desired[row.id] = row
	for id: String in _records:
		if not desired.has(id) and not _factory._deleted.get(id,false):
			var validation := apply_record(id,null,true)
			if not validation.ok: return validation
	if dry_run: return {"ok":true}
	var capsule := capture_install_checkpoint()
	_document_transaction = true
	_journal.clear()
	var result := {"ok":true}
	for id: String in desired:
		if not has_object(id):
			result = create_copy(desired[id].template_id,id,_decode(desired[id].transform))
		else: result = apply_record(id,desired[id])
		if not result.ok: break
	if result.ok:
		for id: String in _records:
			if not desired.has(id) and not _factory._deleted.get(id,false):
				result = apply_record(id,null)
				if not result.ok: break
	_document_transaction = false
	if not result.ok:
		var restored := restore_install_checkpoint(capsule)
		for index in range(_journal.size()-1,-1,-1): _journal[index].call()
		_journal.clear()
		return result if restored.ok else restored
	_journal.clear()
	return {"ok":true}

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}
