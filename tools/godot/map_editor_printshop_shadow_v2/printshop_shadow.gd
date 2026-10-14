extends RefCounted
## Source submission witness, not renderer storage readback or scene authority.
const Original = preload("res://scripts/preview_printshop_interior.gd")
const Exact = preload("res://trusted_json.gd")
const SOURCE_PATH := "res://data/printshop_interior.json"
const SOURCE_SHA := "958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b"
var _source: Dictionary = {}
var _initial: Dictionary = {}
var _rows: Dictionary = {}
var _factory: Node3D
var _epoch := 0
var _poisoned := false
var _disposed := false
var _writing := false
var _callback_busy := false
var _owner: WeakRef
var _receipt: RefCounted
var _validate: Callable
var _receipt_epoch := -1
var _watched: Dictionary = {}
var _expected_multi_id := 0

func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key in value: _freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze(child)
		value.make_read_only()

func build(source: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _disposed or _factory != null: return {"ok":false,"error":"Main-thread fresh build required"}
	if FileAccess.get_sha256(SOURCE_PATH) != SOURCE_SHA: return {"ok":false,"error":"Trusted source descriptor changed"}
	var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))
	if not original is Dictionary or not Exact.equal(source,original): return {"ok":false,"error":"Input is not exact native-parsed trusted descriptor"}
	if source.get("schema") != "mafiozi-printshop-interior-v1" or source.get("sourceId") != Original.SOURCE_ID or source.get("assetSha256") != Original.ASSET_SHA: return {"ok":false,"error":"Exact source binding required"}
	_factory = Original.new()
	_factory._validate_package(source)
	if not _factory.errors.is_empty():
		_factory.free(); _factory = null
		return {"ok":false,"error":"Invalid original descriptor"}
	_source = source.duplicate(true); _freeze(_source)
	_factory._data = _source
	var total := 0
	var colored := 0
	for index in _source.meshes.size():
		var spec: Dictionary = _source.meshes[index]
		if not spec.has("instances"): continue
		var mesh: ArrayMesh = _factory._mesh(spec)
		if mesh.get_surface_count() == 0: return _failed_build()
		var transforms: Array = []
		var colors: Array = []
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = spec.has("instanceColorsLinear")
		mm.mesh = mesh
		mm.instance_count = spec.instances.size()
		for i in mm.instance_count:
			var frame: Transform3D = _factory._matrix(spec.instances[i])
			transforms.append(frame); mm.set_instance_transform(i,frame)
			if mm.use_colors:
				var color: Color = _factory._linear_color(spec.instanceColorsLinear[i])
				colors.append(color); mm.set_instance_color(i,color)
		var node := MultiMeshInstance3D.new()
		node.name = str(spec.name) if not str(spec.name).is_empty() else "SourceGeneratedPart"
		node.transform = _factory._matrix(spec.transform)
		node.multimesh = mm
		var material_refs: Array = []
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			material_refs.append(weakref(material)); _watch(material)
		_watch(mesh); _watch(mm)
		var row := {"node":weakref(node),"multi":weakref(mm),"mesh":weakref(mesh),"materials":material_refs,
			"transforms":transforms,"colors":colors,"count":mm.instance_count,"visible":-1,
			"aabb":AABB(),"frame":node.transform,"motion":spec.motion,"colors_enabled":mm.use_colors,"uniforms":{}}
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material is ShaderMaterial:
				row.uniforms[surface] = {}
				for parameter in ["source_origin_m","source_albedo_linear","source_roughness"]:
					row.uniforms[surface][parameter] = var_to_bytes(material.get_shader_parameter(parameter))
		_rows[index] = row
		_initial[index] = {"transforms":transforms.duplicate(),"colors":colors.duplicate(),"frame":node.transform,"motion":spec.motion,"count":mm.instance_count}
		# Factory owns unpublished nodes until a genuine host adopts/reparents them.
		_factory.add_child(node)
		total += mm.instance_count; colored += colors.size()
	if _rows.size() != 15 or total != 280 or colored != 215: return _failed_build()
	_freeze(_initial)
	return {"ok":true,"batches":15,"instances":total,"colored":colored,"admitted":false,"renderer_storage_proven":false}

func _failed_build() -> Dictionary:
	dispose()
	return {"ok":false,"error":"Source inventory/resource mismatch"}

func _watch(resource: Resource) -> void:
	if resource == null or _watched.has(resource.get_instance_id()): return
	var id := resource.get_instance_id()
	var callback := _resource_changed.bind(id)
	_watched[id] = {"reference":weakref(resource),"callback":callback}
	resource.changed.connect(callback)
	if resource is ShaderMaterial: _watch(resource.shader)

func _resource_changed(resource_id: int) -> void:
	# Only current managed MM's signal is expected. Nested resources always poison.
	if not _writing or resource_id != _expected_multi_id: _poisoned = true; _invalidate()

func _invalidate() -> void:
	_receipt = null; _receipt_epoch = -1

func _mutated() -> void:
	_epoch += 1; _invalidate()

func generation() -> int: return _epoch
func initial_snapshot() -> Dictionary: return _initial.duplicate(true)
func shadow() -> Dictionary:
	var result := {}
	for index in _rows:
		var row: Dictionary = _rows[index]
		result[index] = {"transforms":row.transforms.duplicate(),"colors":row.colors.duplicate(),"count":row.count,"visible":row.visible,"aabb":row.aabb,"frame":row.frame,"motion":row.motion}
	return result
func batch_nodes() -> Array:
	var result := []
	for index in _rows: result.append(_rows[index].node.get_ref())
	return result

func guard() -> bool:
	if not Thread.is_main_thread() or _disposed or _poisoned or _factory == null or not is_instance_valid(_factory): return false
	for index in _rows:
		var row: Dictionary = _rows[index]
		var node: Variant = row.node.get_ref()
		var mm: Variant = row.multi.get_ref()
		var mesh: Variant = row.mesh.get_ref()
		if node == null or mm == null or mesh == null or node.multimesh != mm or mm.mesh != mesh: return _guard_failed()
		if mm.instance_count != row.count or mm.visible_instance_count != row.visible or mm.transform_format != MultiMesh.TRANSFORM_3D or mm.use_colors != row.colors_enabled or mm.use_custom_data or mm.custom_aabb != row.aabb or node.transform != row.frame: return _guard_failed()
		if mesh.get_surface_count() != row.materials.size(): return _guard_failed()
		for surface in row.materials.size():
			var material: Variant = row.materials[surface].get_ref()
			if material == null or mesh.surface_get_material(surface) != material: return _guard_failed()
			if row.uniforms.has(surface):
				for parameter in row.uniforms[surface]:
					if var_to_bytes(material.get_shader_parameter(parameter)) != row.uniforms[surface][parameter]: return _guard_failed()
	return true

func _guard_failed() -> bool:
	_poisoned = true; _invalidate(); return false

func write_instances(index: int, changes: Dictionary) -> bool:
	if _writing or _callback_busy or not guard() or not _rows.has(index) or changes.is_empty(): return false
	var row: Dictionary = _rows[index]
	for slot in changes:
		if not slot is int or slot < 0 or slot >= row.count or not changes[slot] is Dictionary: return false
		var change: Dictionary = changes[slot]
		if change.is_empty(): return false
		for key in change:
			if key == "transform":
				if not change[key] is Transform3D or not change[key].is_finite(): return false
			elif key == "color":
				if not row.colors_enabled or not change[key] is Color or not _finite_color(change[key]): return false
			else: return false
	var mm: MultiMesh = row.multi.get_ref()
	_expected_multi_id = mm.get_instance_id(); _writing = true
	for slot in changes:
		if changes[slot].has("transform"):
			row.transforms[slot] = changes[slot].transform; mm.set_instance_transform(slot,row.transforms[slot])
		if changes[slot].has("color"):
			row.colors[slot] = changes[slot].color; mm.set_instance_color(slot,row.colors[slot])
	_writing = false; _expected_multi_id = 0; _mutated()
	return guard()

func write_transform(index: int, slot: int, frame: Transform3D) -> bool: return write_instances(index,{slot:{"transform":frame}})
func write_color(index: int, slot: int, color: Color) -> bool: return write_instances(index,{slot:{"color":color}})
func _finite_color(color: Color) -> bool: return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)

func set_visible_count(index: int, count: int) -> bool:
	if _writing or _callback_busy or not guard() or not _rows.has(index) or count < -1 or count > _rows[index].count: return false
	_expected_multi_id = _rows[index].multi.get_ref().get_instance_id(); _writing = true
	_rows[index].multi.get_ref().visible_instance_count = count; _rows[index].visible = count
	_writing = false; _expected_multi_id = 0; _mutated(); return guard()

func set_batch_frame(index: int, frame: Transform3D) -> bool:
	if _writing or _callback_busy or not guard() or not _rows.has(index) or not frame.is_finite(): return false
	_rows[index].node.get_ref().transform = frame; _rows[index].frame = frame; _mutated(); return guard()

func set_bounds(index: int, bounds: AABB) -> bool:
	if _writing or _callback_busy or not guard() or not _rows.has(index) or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x < 0 or bounds.size.y < 0 or bounds.size.z < 0: return false
	_expected_multi_id = _rows[index].multi.get_ref().get_instance_id(); _writing = true
	_rows[index].multi.get_ref().custom_aabb = bounds; _rows[index].aabb = bounds
	_writing = false; _expected_multi_id = 0; _mutated(); return guard()

## The callback must genuinely seal all writers/lifecycle; data booleans are not accepted.
## Same opaque receipt is revalidated by bound actual owner, never from an imported file.
func request_owner_receipt(owner: Node, seal: Callable, validate: Callable) -> bool:
	if _writing or _callback_busy or not guard() or owner == null or not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion() or not seal.is_valid() or not validate.is_valid() or seal.get_object() != owner or validate.get_object() != owner: return false
	var epoch := _epoch
	_callback_busy = true
	var candidate: Variant = seal.call(self,epoch)
	_callback_busy = false
	if not candidate is RefCounted or _epoch != epoch or not guard() or not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion() or not seal.is_valid() or not validate.is_valid() or seal.get_object() != owner or validate.get_object() != owner: return false
	_owner = weakref(owner); _validate = validate; _receipt = candidate; _receipt_epoch = epoch
	return owner_receipt_valid()

func owner_receipt_valid() -> bool:
	if not Thread.is_main_thread(): return false
	if _writing or _callback_busy or _receipt == null or _owner == null or _owner.get_ref() == null or not _owner.get_ref().is_inside_tree() or _receipt_epoch != _epoch or not guard() or not _validate.is_valid() or _validate.get_object() != _owner.get_ref(): return false
	var epoch := _epoch
	var receipt := _receipt
	var owner_id: int = _owner.get_ref().get_instance_id()
	_callback_busy = true
	var checked: Variant = _validate.call(self,epoch,receipt)
	_callback_busy = false
	var owner: Variant = _owner.get_ref() if _owner != null else null
	return owner != null and is_instance_valid(owner) and owner.get_instance_id() == owner_id and owner.is_inside_tree() and not owner.is_queued_for_deletion() and _validate.is_valid() and _validate.get_object() == owner and checked is RefCounted and is_same(checked,receipt) and _epoch == epoch and is_same(_receipt,receipt) and guard()

func dispose() -> void:
	if not Thread.is_main_thread() or _writing or _callback_busy: return
	_invalidate(); _disposed = true
	for watched in _watched.values():
		var resource: Variant = watched.reference.get_ref()
		if resource != null and resource.changed.is_connected(watched.callback): resource.changed.disconnect(watched.callback)
	_watched.clear()
	if _factory != null and is_instance_valid(_factory):
		_factory.restore_original(); _factory.free()
	_factory = null; _rows.clear()
