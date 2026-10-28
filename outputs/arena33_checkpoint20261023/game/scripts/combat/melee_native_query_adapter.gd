extends RefCounted
## One trusted skin provider / one actor life / one privately owned native context.
## No extension loading, actor admission, HP, scheduling or obstacle authority.
const MAX_REVISION := 9007199254740991
const MAX_VERTICES := 65536
const MAX_TRIANGLES := 131072
const PAGE_SIZE := 256
const WIDTH := 16
const SkinProvider = preload("res://scripts/combat/melee_skin_provider.gd")
var _provider: WeakRef
var _provider_binding: WeakRef
var _native: Object
var _identity: Dictionary = {}
var _captured: Dictionary = {}
var _bound := false
var _disposed := false
var _busy := false
var _interrupted := false

static func _fail(reason: String) -> Dictionary: return {"ok":false,"valid":false,"complete":false,"error":reason}
func configure(provider: RefCounted) -> Dictionary:
	if _busy: _interrupted=true; return _fail("reentry")
	if not Thread.is_main_thread() or _bound or _disposed or not is_instance_valid(provider) or not provider is SkinProvider or not provider._actor is WeakRef: return _fail("binding")
	if not ClassDB.class_exists("MeleeNativeGeometry"): return _fail("native_unavailable")
	# This actual provider creates a new WeakRef on every configure, even when
	# source IDs repeat. Keep its binding object identity, not only source strings.
	_provider=weakref(provider);_provider_binding=provider._actor;_bound=true
	return {"ok":true}
func _live() -> bool:
	return _bound and not _disposed and not _interrupted and _provider!=null and is_instance_valid(_provider.get_ref()) and _provider.get_ref()._actor==_provider_binding
func _drop() -> void:
	_captured.clear()
	if is_instance_valid(_native): _native.free()
	_native=null
func _reject(reason: String) -> Dictionary:
	_drop()
	return _fail(reason)
func _current(receipt: Dictionary) -> bool:
	if not _live() or receipt.is_empty(): return false
	var value: Variant=_provider.get_ref().call("current",receipt.duplicate(true))
	return _live() and value is bool and value
func _enter() -> bool:
	if not Thread.is_main_thread(): return false
	if _busy: _interrupted=true;return false
	_busy=true;_interrupted=false
	return true
func _finish(result: Dictionary) -> Dictionary:
	if not _live():result=_reject("owner_changed_or_reentry")
	_busy=false
	return result
func update(expected_pose_revision: int) -> Dictionary:
	if not _enter():return _fail("thread_or_reentry")
	return _finish(_update(expected_pose_revision))
func _update(revision: int) -> Dictionary:
	if not _live() or revision<1 or revision>MAX_REVISION:return _reject("lifetime_or_revision")
	if not _captured.is_empty() and _captured.pose_revision==revision and _current(_captured.owner_receipt):return {"ok":true,"cached":true,"pose_revision":revision}
	# A failed current callback may have disposed, rebound or reentered us.
	# Do not dereference its former provider or issue another capture afterward.
	if not _live():return _reject("owner_changed_before_capture")
	# Retire old captured data before calling a provider that might fail/reenter.
	var previous: Dictionary=_captured
	_captured={}
	var value: Variant=_provider.get_ref().call("capture",revision)
	if not _live() or not value is Dictionary or value.get("ok")!=true:return _reject("capture_failed")
	var capture: Dictionary=value
	if not capture.get("vertices") is PackedVector3Array or not capture.get("indices") is PackedInt32Array or not capture.get("parts") is Array or not capture.get("identity") is Dictionary or not capture.get("owner_receipt") is Dictionary or not capture.get("actor_root_world") is Transform3D:return _reject("capture_schema")
	var identity: Dictionary=capture.identity;var receipt: Dictionary=capture.owner_receipt
	if identity.size()!=2 or not identity.get("actor_id") is String or identity.actor_id.is_empty() or not identity.get("life_generation") is int or identity.life_generation<1:return _reject("identity")
	if receipt.get("actor_id")!=identity.actor_id or receipt.get("life_generation")!=identity.life_generation or receipt.get("pose_revision")!=revision or capture.get("pose_revision")!=revision:return _reject("receipt")
	if not _identity.is_empty() and identity!=_identity:return _reject("actor_life_changed")
	var vertices: PackedVector3Array=capture.vertices;var indices: PackedInt32Array=capture.indices
	if vertices.is_empty() or vertices.size()>MAX_VERTICES or indices.is_empty() or indices.size()%3!=0 or indices.size()>MAX_TRIANGLES*3 or not capture.actor_root_world.is_finite():return _reject("topology")
	if not _current(receipt):return _reject("stale_capture")
	if is_instance_valid(_native) and not previous.is_empty():
		if revision<=int(previous.pose_revision) or indices!=previous.indices or vertices.size()!=previous.vertices.size():return _reject("revision_or_topology_changed")
		# PackedVector3Array goes directly into C; no per-vertex float64 repack.
		var refit: Variant=_native.call("refit_vertices",vertices,revision)
		if not refit is PackedFloat64Array or refit.size()!=3 or refit[0]!=1 or refit[1]!=revision:return _reject("native_refit")
	else:
		_drop()
		_native=ClassDB.instantiate("MeleeNativeGeometry")
		if not is_instance_valid(_native):return _reject("native_create")
		var payload:=PackedFloat64Array();payload.resize(4+vertices.size()*3+indices.size())
		payload[0]=1;payload[1]=revision;payload[2]=vertices.size();payload[3]=indices.size()/3
		for index in vertices.size():
			var point: Vector3=vertices[index];var at:=4+index*3
			payload[at]=point.x;payload[at+1]=point.y;payload[at+2]=point.z
		for index in indices.size():payload[4+vertices.size()*3+index]=indices[index]
		var configured: Variant=_native.call("run",payload)
		if not configured is PackedFloat64Array or configured!=PackedFloat64Array([1,vertices.size(),indices.size()/3]):return _reject("native_configure")
	if not _current(receipt):return _reject("capture_changed")
	_identity=identity.duplicate(true);_captured=capture
	return {"ok":true,"cached":false,"pose_revision":revision,"vertices":vertices.size(),"triangles":indices.size()/3}
func actor() -> Dictionary:
	if not _enter():return {}
	var result: Dictionary={}
	if not _captured.is_empty() and _current(_captured.owner_receipt):
		var visible:=false
		for part: Dictionary in _captured.parts:visible=visible or part.get("visible",false)
		# Duplicate the view once at publication, not on every page/query.
		result={"actor_id":_identity.actor_id,"root_position":_captured.actor_root_world.origin,"visible":visible,"receipt":_captured.owner_receipt.duplicate(true),"parts":_captured.parts.duplicate(true)}
	else:_drop()
	if not _live():_drop();result={}
	_busy=false
	return result
func current(actor_row: Dictionary) -> bool:
	if not _enter():return false
	var valid:=_actor_current(actor_row)
	if not valid or not _live():_drop();valid=false
	_busy=false
	return valid
func _actor_current(actor_row: Dictionary) -> bool:
	return not _captured.is_empty() and actor_row.get("actor_id")==_identity.get("actor_id") and actor_row.get("receipt")==_captured.owner_receipt and _current(_captured.owner_receipt)
func query(actor_row: Dictionary, request: Dictionary) -> Dictionary:
	if not _enter():return _fail("thread_or_reentry")
	return _finish(_query(actor_row,request))
func _query(actor_row: Dictionary, request: Dictionary) -> Dictionary:
	if not _actor_current(actor_row) or not is_instance_valid(_native):return _reject("stale_actor")
	if not request.get("key") is String or request.key.is_empty() or request.get("receipt")!=_captured.owner_receipt or not request.get("contacts") is Array or request.contacts.is_empty() or request.contacts.size()>4:return _reject("request")
	var revision: int=_captured.pose_revision
	var payload:=PackedFloat64Array([3,revision,request.contacts.size(),PAGE_SIZE])
	for sweep: Variant in request.contacts:
		if not sweep is Dictionary or not sweep.get("from") is Vector3 or not sweep.get("to") is Vector3 or not (sweep.get("radius") is float or sweep.get("radius") is int):return _reject("sweep")
		payload.append_array(PackedFloat64Array([sweep.from.x,sweep.from.y,sweep.from.z,sweep.to.x,sweep.to.y,sweep.to.z,sweep.radius]))
	var page: Variant=_native.call("run",payload)
	var rows:=PackedFloat64Array();var total:=-1;var offset:=0;var query_id:=-1;var pages:=0
	while true:
		if not page is PackedFloat64Array or page.size()<7 or page[0]!=1 or page[1]!=revision or page[6]!=WIDTH:return _reject("native_query_or_page")
		if pages==0:
			if not is_finite(page[3]) or page[3]!=floor(page[3]) or page[3]<0 or page[3]>int(_captured.indices.size()/3)*request.contacts.size() or not is_finite(page[2]) or page[2]!=floor(page[2]) or page[2]<0:return _reject("page_capacity")
			total=int(page[3]);query_id=int(page[2])
		var count:=mini(PAGE_SIZE,total-offset)
		if page[2]!=query_id or page[3]!=total or page[4]!=offset or page[5]!=count or page.size()!=7+count*WIDTH:return _reject("page_sequence")
		# Bulk engine copy, no GDScript per-candidate/per-coordinate repacking.
		rows.append_array(page.slice(7))
		offset+=count;pages+=1
		if offset==total:break
		page=_native.call("run",PackedFloat64Array([4,revision,query_id,PAGE_SIZE]))
	if not _actor_current(actor_row):return _reject("query_owner_changed")
	return {"ok":true,"valid":true,"complete":true,"key":request.key,"receipt":_captured.owner_receipt.duplicate(true),"rows":rows,"pages":pages}
func dispose() -> void:
	if not Thread.is_main_thread():return
	_disposed=true;_bound=false;_interrupted=true
	_drop();_provider=null;_provider_binding=null
func _notification(what: int) -> void:
	# RefCounted may already be considered an invalid self during PREDELETE;
	# do not call another instance method from that notification.
	if what==NOTIFICATION_PREDELETE and Thread.is_main_thread() and is_instance_valid(_native):
		_native.free()
		_native=null
