extends RefCounted
## Candidate: exact typed snapshots avoid repeated whole-material serialization.
## Full final/receipt/take validation remains atomic; this is not a sliced authority receipt.

const MAX_SURFACES:=1024
const MAX_VARIANT_DEPTH:=8
const MAX_VARIANT_ITEMS:=32768
const MAX_SIGNATURE_BYTES:=262144

class PreparationToken extends RefCounted:
	var nonce: int
	func _init(value: int) -> void: nonce=value

var _configured:=false
var _disposed:=false
var _consumed:=false
var _invalid_error:=""
var _generation:=0
var _revision:=0
var _cursor:=0
var _sources: Array[StandardMaterial3D]=[]
var _source_snapshots: Array=[]
var _private: Array[StandardMaterial3D]=[]
var _connections: Array=[]
var _token: PreparationToken
var _next_nonce:=1
static var _storage_names: Array[StringName]=[]

func configure(ordered_sources: Array, generation: int, revision: int) -> Dictionary:
	if _disposed: return {"ok":false,"error":"disposed"}
	if _configured: return {"ok":false,"error":"already_configured"}
	var prepared:=_prepare_sources(ordered_sources,generation,revision)
	if not prepared.ok: return prepared
	_install(prepared)
	return _receipt_core()

## Exactly one material shell may be created per call. current_sources is the
## host's current ordered surface binding and is checked by Resource identity.
func prewarm_step(current_sources: Array, expected_generation: int, expected_revision: int, max_count: int=1) -> Dictionary:
	var gate:=_gate(expected_generation,expected_revision)
	if not gate.is_empty(): return {"ok":false,"error":gate}
	if max_count!=1: return {"ok":false,"error":"budget"}
	var binding_error:=_validate_identities(current_sources)
	if not binding_error.is_empty():
		_invalidate(binding_error); return {"ok":false,"error":binding_error}
	if _cursor>=_sources.size(): return _receipt_core()
	var source:=_sources[_cursor]
	var snapshot: Variant=_source_snapshots[_cursor]
	if not _matches_snapshot(source,snapshot):
		_invalidate("source_content_changed"); return {"ok":false,"error":"source_content_changed"}
	# Nested Resources are rejected at admission, so shallow duplication matches
	# the supported stored graph without claiming Three texture-copy parity.
	var copied:=source.duplicate(false) as StandardMaterial3D
	if copied==null or copied==source or copied.get_class()!="StandardMaterial3D":
		_invalidate("duplicate_failed"); return {"ok":false,"error":"duplicate_failed"}
	_detach_variant_containers(source,copied)
	if not _matches_snapshot(copied,snapshot):
		_invalidate("duplicate_mismatch"); return {"ok":false,"error":"duplicate_mismatch"}
	_connect_resource(copied,Callable(self,"_on_private_changed"))
	_private.append(copied); _cursor+=1
	if _cursor==_sources.size():
		var final_error:=_validate_contents()
		if not final_error.is_empty():
			_invalidate(final_error); return {"ok":false,"error":final_error}
	return _receipt_core()

## Detached status only; no mutable Resource references are returned here.
func receipt(current_sources: Array, expected_generation: int, expected_revision: int) -> Dictionary:
	var gate:=_gate(expected_generation,expected_revision)
	if not gate.is_empty(): return {"ok":false,"error":gate,"generation":_generation,"revision":_revision}
	var binding_error:=_validate_identities(current_sources)
	if not binding_error.is_empty():
		_invalidate(binding_error); return {"ok":false,"error":binding_error,"generation":_generation,"revision":_revision}
	var content_error:=_validate_contents()
	if not content_error.is_empty():
		_invalidate(content_error); return {"ok":false,"error":content_error,"generation":_generation,"revision":_revision}
	return _receipt_core()

## One-shot ownership transfer. The returned array contains the exact private
## Resources, one per ordered input surface. After transfer this pool disconnects
## all watchers and never judges legitimate writer mutations.
func take_prepared(current_sources: Array, expected_generation: int, expected_revision: int, expected_token: RefCounted) -> Dictionary:
	if _consumed: return {"ok":false,"error":"consumed","generation":_generation,"revision":_revision,"consumed":true}
	if expected_token==null or expected_token!=_token: return {"ok":false,"error":"preparation_token","generation":_generation,"revision":_revision}
	var checked:=receipt(current_sources,expected_generation,expected_revision)
	if not checked.get("ok",false): return checked
	if not checked.get("ready",false): return {"ok":false,"error":"PREWARM_PENDING","generation":_generation,"revision":_revision}
	var transferred: Array[StandardMaterial3D]=_private.duplicate()
	_disconnect_all(); _sources.clear(); _source_snapshots.clear(); _private.clear(); _cursor=0; _token=null
	_consumed=true
	return {"ok":true,"generation":_generation,"revision":_revision,"count":transferred.size(),"materials":transferred,"consumed":true}

## Atomically installs a strictly newer vehicle lifetime. Transferred Resources
## from an earlier generation are caller-owned and are never freed by reset.
func reset(ordered_sources: Array, new_generation: int, new_revision: int) -> Dictionary:
	if _disposed: return {"ok":false,"error":"disposed"}
	if not _configured: return {"ok":false,"error":"not_configured"}
	if new_generation<=_generation: return {"ok":false,"error":"stale_generation"}
	var prepared:=_prepare_sources(ordered_sources,new_generation,new_revision)
	if not prepared.ok: return prepared
	_disconnect_all(); _clear_owned(); _install(prepared)
	return _receipt_core()

func dispose() -> void:
	if _disposed: return
	_disconnect_all(); _clear_owned(); _configured=false; _consumed=false; _invalid_error=""; _generation=0; _revision=0; _token=null; _disposed=true

func _prepare_sources(values: Array, generation: int, revision: int) -> Dictionary:
	if generation<=0: return {"ok":false,"error":"generation"}
	if revision<0: return {"ok":false,"error":"revision"}
	if values.is_empty() or values.size()>MAX_SURFACES: return {"ok":false,"error":"surfaces"}
	var sources: Array[StandardMaterial3D]=[]
	var snapshots: Array=[]
	for value: Variant in values:
		var material:=value as StandardMaterial3D
		if material==null or not is_instance_valid(material) or material.get_class()!="StandardMaterial3D": return {"ok":false,"error":"material_type"}
		var nested_error:=_nested_resource_error(material)
		if not nested_error.is_empty(): return {"ok":false,"error":nested_error}
		var snapshot:=_snapshot(material)
		if not snapshot.get("ok",false): return {"ok":false,"error":"material_content"}
		sources.append(material); snapshots.append(snapshot)
	return {"ok":true,"generation":generation,"revision":revision,"sources":sources,"snapshots":snapshots}

func _install(prepared: Dictionary) -> void:
	_configured=true; _consumed=false; _invalid_error=""; _generation=int(prepared.generation); _revision=int(prepared.revision); _cursor=0
	_sources=prepared.sources; _source_snapshots=prepared.snapshots; _private=[]
	_token=PreparationToken.new(_next_nonce); _next_nonce+=1
	for source: StandardMaterial3D in _sources: _connect_resource(source,Callable(self,"_on_source_changed"))

func _gate(expected_generation: int, expected_revision: int) -> String:
	if _disposed: return "disposed"
	if not _configured: return "not_configured"
	if expected_generation!=_generation: return "stale_generation"
	if expected_revision!=_revision: return "stale_revision"
	if _consumed: return "consumed"
	if not _invalid_error.is_empty(): return _invalid_error
	return ""

func _validate_identities(values: Array) -> String:
	if values.size()!=_sources.size(): return "source_layout_changed"
	for i in _sources.size():
		if values[i]!=_sources[i]: return "source_identity_changed"
	return ""

func _validate_contents() -> String:
	if _invalid_error!="": return _invalid_error
	for i in _sources.size():
		if not is_instance_valid(_sources[i]): return "source_freed"
		if not _matches_snapshot(_sources[i],_source_snapshots[i]): return "source_content_changed"
	if _private.size()!=_cursor: return "private_layout_changed"
	for i in _private.size():
		if not is_instance_valid(_private[i]): return "private_freed"
		if not _matches_snapshot(_private[i],_source_snapshots[i]): return "private_content_changed"
	return ""

func _receipt_core() -> Dictionary:
	var source_ids: Array=[]; var private_ids: Array=[]
	for source: StandardMaterial3D in _sources: source_ids.append(source.get_instance_id())
	for material: StandardMaterial3D in _private: private_ids.append(material.get_instance_id())
	return {"ok":_invalid_error.is_empty(),"error":_invalid_error,"generation":_generation,"revision":_revision,"preparation_token":_token,"total":_sources.size(),"prepared":_private.size(),"ready":not _consumed and _invalid_error.is_empty() and not _sources.is_empty() and _private.size()==_sources.size(),"consumed":_consumed,"source_instance_ids":source_ids,"private_instance_ids":private_ids}

func _invalidate(error: String) -> void:
	if _invalid_error.is_empty(): _invalid_error=error

func _on_source_changed() -> void: _invalidate("source_content_changed")
func _on_private_changed() -> void: _invalidate("private_content_changed")

func _connect_resource(resource: Resource, callback: Callable) -> void:
	if resource.changed.is_connected(callback): return
	resource.changed.connect(callback); _connections.append({"resource":resource,"callable":callback})

func _disconnect_all() -> void:
	for row: Dictionary in _connections:
		var resource:=row.get("resource") as Resource; var callback: Callable=row.get("callable",Callable())
		if is_instance_valid(resource) and callback.is_valid() and resource.changed.is_connected(callback): resource.changed.disconnect(callback)
	_connections.clear()

func _clear_owned() -> void:
	_sources.clear(); _source_snapshots.clear(); _private.clear(); _cursor=0; _invalid_error=""; _consumed=false; _token=null

static func _nested_resource_error(material: StandardMaterial3D) -> String:
	for name: StringName in _storage_property_names(material):
		var value: Variant=material.get(name)
		if value is Resource: return "unsupported_nested_resource"
	return ""

static func _detach_variant_containers(source: StandardMaterial3D, copied: StandardMaterial3D) -> void:
	# Resource.duplicate(false) deliberately preserves nested Resource identity.
	# Plain Array/Dictionary metadata and stored containers must still be private,
	# matching source material-shell/userData independence.
	for name: StringName in _storage_property_names(source):
		var value: Variant=source.get(name)
		if value is Array or value is Dictionary: copied.set(name,value.duplicate(true))
	for name: StringName in source.get_meta_list():
		var value: Variant=source.get_meta(name)
		if value is Array or value is Dictionary: copied.set_meta(name,value.duplicate(true))
		else: copied.set_meta(name,value)

static func _snapshot(material: StandardMaterial3D) -> Dictionary:
	var collected:=_material_rows(material,true)
	if not collected.get("ok",false): return {"ok":false}
	# Keep the frozen admission byte ceiling. Serialization happens once while
	# preparing the snapshot, never during final/receipt/take validation.
	var encoded:=var_to_bytes(collected.rows)
	if encoded.size()>MAX_SIGNATURE_BYTES: return {"ok":false}
	return {"ok":true,"rows":collected.rows}

static func _matches_snapshot(material: StandardMaterial3D, snapshot: Variant) -> bool:
	if not snapshot is Dictionary or not snapshot.get("ok",false) or not snapshot.get("rows") is Array: return false
	var collected:=_material_rows(material,false)
	return collected.get("ok",false) and _exact_value_equal(collected.rows,snapshot.rows)

static func _material_rows(material: StandardMaterial3D, detach: bool) -> Dictionary:
	if material==null or not is_instance_valid(material) or material.get_class()!="StandardMaterial3D": return {"ok":false}
	var values: Array=[]; var seen: Array=[]; var counter:={"count":0}
	for name: StringName in _storage_property_names(material):
		var value: Variant=material.get(name)
		counter.count=int(counter.count)+String(name).to_utf8_buffer().size()
		var safe:=_variant_safe_bounded(value,seen,0,counter)
		if int(counter.count)>MAX_VARIANT_ITEMS or value is Resource or not safe: return {"ok":false}
		values.append([String(name),typeof(value),_snapshot_value(value) if detach else value])
	var meta_names:=material.get_meta_list(); meta_names.sort()
	for name: StringName in meta_names:
		var value: Variant=material.get_meta(name)
		counter.count=int(counter.count)+String(name).to_utf8_buffer().size()
		var safe:=_variant_safe_bounded(value,seen,0,counter)
		if int(counter.count)>MAX_VARIANT_ITEMS or value is Object or not safe: return {"ok":false}
		values.append(["@meta/"+String(name),typeof(value),_snapshot_value(value) if detach else value])
	return {"ok":true,"rows":values}

static func _snapshot_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY,TYPE_DICTIONARY: return value.duplicate(true)
		TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY,TYPE_PACKED_STRING_ARRAY,TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_VECTOR4_ARRAY,TYPE_PACKED_COLOR_ARRAY: return value.duplicate()
		_: return value

static func _float_exact(a: float,b: float) -> bool:
	if a!=b: return false
	if a!=0.0: return true
	return PackedFloat64Array([a]).to_byte_array()==PackedFloat64Array([b]).to_byte_array()

static func _exact_value_equal(a: Variant,b: Variant) -> bool:
	var kind:=typeof(a)
	if kind!=typeof(b): return false
	match kind:
		TYPE_NIL: return true
		TYPE_BOOL,TYPE_INT,TYPE_STRING,TYPE_STRING_NAME,TYPE_NODE_PATH,TYPE_VECTOR2I,TYPE_VECTOR3I,TYPE_VECTOR4I,TYPE_RECT2I: return a==b
		TYPE_FLOAT: return _float_exact(a,b)
		TYPE_VECTOR2: return _float_exact(a.x,b.x) and _float_exact(a.y,b.y)
		TYPE_VECTOR3: return _float_exact(a.x,b.x) and _float_exact(a.y,b.y) and _float_exact(a.z,b.z)
		TYPE_VECTOR4: return _float_exact(a.x,b.x) and _float_exact(a.y,b.y) and _float_exact(a.z,b.z) and _float_exact(a.w,b.w)
		TYPE_RECT2: return _exact_value_equal(a.position,b.position) and _exact_value_equal(a.size,b.size)
		TYPE_PLANE: return _exact_value_equal(a.normal,b.normal) and _float_exact(a.d,b.d)
		TYPE_QUATERNION: return _float_exact(a.x,b.x) and _float_exact(a.y,b.y) and _float_exact(a.z,b.z) and _float_exact(a.w,b.w)
		TYPE_COLOR: return _float_exact(a.r,b.r) and _float_exact(a.g,b.g) and _float_exact(a.b,b.b) and _float_exact(a.a,b.a)
		TYPE_AABB: return _exact_value_equal(a.position,b.position) and _exact_value_equal(a.size,b.size)
		TYPE_BASIS: return _exact_value_equal(a.x,b.x) and _exact_value_equal(a.y,b.y) and _exact_value_equal(a.z,b.z)
		TYPE_TRANSFORM2D: return _exact_value_equal(a[0],b[0]) and _exact_value_equal(a[1],b[1]) and _exact_value_equal(a[2],b[2])
		TYPE_TRANSFORM3D: return _exact_value_equal(a.basis,b.basis) and _exact_value_equal(a.origin,b.origin)
		TYPE_PROJECTION:
			for column in 4:
				if not _exact_value_equal(a[column],b[column]): return false
			return true
		TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,TYPE_PACKED_STRING_ARRAY: return a==b
		TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY: return a.to_byte_array()==b.to_byte_array()
		TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_VECTOR4_ARRAY,TYPE_PACKED_COLOR_ARRAY:
			if a.size()!=b.size(): return false
			for i in a.size():
				if not _exact_value_equal(a[i],b[i]): return false
			return true
		TYPE_ARRAY:
			if a.size()!=b.size(): return false
			for i in a.size():
				if not _exact_value_equal(a[i],b[i]): return false
			return true
		TYPE_DICTIONARY:
			if a.size()!=b.size(): return false
			var a_keys: Array=a.keys()
			var b_keys: Array=b.keys()
			for i in a_keys.size():
				if not _exact_value_equal(a_keys[i],b_keys[i]) or not _exact_value_equal(a[a_keys[i]],b[b_keys[i]]): return false
			return true
		TYPE_OBJECT: return a==null and b==null
		_: return false

static func _storage_property_names(material: StandardMaterial3D) -> Array[StringName]:
	if not _storage_names.is_empty(): return _storage_names
	var names: Array[StringName]=[]
	for property: Dictionary in material.get_property_list():
		if (int(property.get("usage",0))&PROPERTY_USAGE_STORAGE)==0: continue
		var name:=StringName(property.get("name",""))
		if name in [&"resource_local_to_scene",&"resource_name",&"resource_path",&"resource_scene_unique_id"]: continue
		if String(name).begins_with("metadata/"): continue
		names.append(name)
	_storage_names=names
	return names

static func _variant_safe(value: Variant) -> bool:
	return _variant_safe_bounded(value,[],0,{"count":0})

static func _variant_safe_bounded(value: Variant, seen: Array, depth: int, counter: Dictionary) -> bool:
	if value==null: return true
	if depth>MAX_VARIANT_DEPTH: return false
	counter.count=int(counter.count)+1
	if int(counter.count)>MAX_VARIANT_ITEMS: return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT: return true
		TYPE_STRING,TYPE_STRING_NAME,TYPE_NODE_PATH:
			counter.count=int(counter.count)+String(value).to_utf8_buffer().size()
			return int(counter.count)<=MAX_VARIANT_ITEMS
		TYPE_FLOAT: return is_finite(float(value))
		TYPE_VECTOR2: return value.is_finite()
		TYPE_VECTOR2I: return true
		TYPE_VECTOR3: return value.is_finite()
		TYPE_VECTOR3I: return true
		TYPE_VECTOR4: return value.is_finite()
		TYPE_VECTOR4I: return true
		TYPE_RECT2: return value.position.is_finite() and value.size.is_finite()
		TYPE_RECT2I: return true
		TYPE_PLANE: return value.normal.is_finite() and is_finite(value.d)
		TYPE_QUATERNION: return value.is_finite()
		TYPE_COLOR: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
		TYPE_AABB: return value.position.is_finite() and value.size.is_finite()
		TYPE_BASIS: return value.is_finite()
		TYPE_TRANSFORM2D: return value.is_finite()
		TYPE_TRANSFORM3D: return value.is_finite()
		TYPE_PROJECTION:
			for column in 4:
				if not value[column].is_finite(): return false
			return true
		TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY:
			counter.count=int(counter.count)+value.size()
			return int(counter.count)<=MAX_VARIANT_ITEMS
		TYPE_PACKED_STRING_ARRAY:
			counter.count=int(counter.count)+value.size()
			if int(counter.count)>MAX_VARIANT_ITEMS: return false
			for item: String in value:
				counter.count=int(counter.count)+item.length()
				if int(counter.count)>MAX_VARIANT_ITEMS: return false
			return true
		TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY:
			counter.count=int(counter.count)+value.size()
			if int(counter.count)>MAX_VARIANT_ITEMS: return false
			for item: float in value:
				if not is_finite(item): return false
			return true
		TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_VECTOR4_ARRAY:
			counter.count=int(counter.count)+value.size()
			if int(counter.count)>MAX_VARIANT_ITEMS: return false
			for item: Variant in value:
				if not item.is_finite(): return false
			return true
		TYPE_PACKED_COLOR_ARRAY:
			counter.count=int(counter.count)+value.size()
			if int(counter.count)>MAX_VARIANT_ITEMS: return false
			for item: Color in value:
				if not is_finite(item.r) or not is_finite(item.g) or not is_finite(item.b) or not is_finite(item.a): return false
			return true
		TYPE_ARRAY:
			if value.is_typed(): return false
			for prior: Variant in seen:
				if is_same(prior,value): return false
			if value.size()>MAX_VARIANT_ITEMS: return false
			seen.append(value)
			for item: Variant in value:
				if item is Object or not _variant_safe_bounded(item,seen,depth+1,counter): return false
			return true
		TYPE_DICTIONARY:
			if value.is_typed(): return false
			for prior: Variant in seen:
				if is_same(prior,value): return false
			if value.size()>MAX_VARIANT_ITEMS: return false
			seen.append(value)
			for key: Variant in value:
				if key is Object or value[key] is Object or not _variant_safe_bounded(key,seen,depth+1,counter) or not _variant_safe_bounded(value[key],seen,depth+1,counter): return false
			return true
		_: return false
