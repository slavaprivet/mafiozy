extends RefCounted
## New user-requested LOCAL walk-in treatment; never a source-save import.
## Reads and commits the exact current native hit owner's mutable HP row.
## Movement/door/preview scheduling remain with the single native route owner.
const HOSPITAL_ID := "REBUILD-VISUAL-hospital-001"
const HOSPITAL_DATA_SHA := "7b15906501f07624159f1d00ecd86944ea875ec2eb9e4cbb2b00ee0cc7143935"
const TREATMENT_MS := 4000.0
const MAX_SAMPLE_GAP_MS := 100.0
var _owner: WeakRef
var _hospital: WeakRef
var _host: RefCounted
var _binding: Dictionary = {}
var _token: Dictionary = {}
var _row: Dictionary = {}
var _lifecycle: RefCounted
var _local_session := ""
var _phase := "UNBOUND"
var _reason := ""
var _serial := 0
var _active := -1
var _request_id := -1
var _navigation: RefCounted
var _nav_lease: Variant
var _last_now := -1.0
var _last_frame := -1
var _elapsed_ms := 0.0
var _hp_before := 0.0
var _max_hp := 0.0
var _revision_before := -1
var _results: Dictionary = {}
var _busy := false
var _disposed := false

func configure(hit_owner: RefCounted, hospital: Node3D, local_session: String) -> Dictionary:
	if not Thread.is_main_thread() or _phase != "UNBOUND" or _disposed: return {"ok":false,"reason":"lifetime"}
	if local_session.is_empty() or local_session.length()>160 or not is_instance_valid(hit_owner) or not hit_owner.has_method("_current") or not hit_owner.has_method("_now"): return {"ok":false,"reason":"actual_hit_owner"}
	if not is_instance_valid(hospital) or not hospital.is_inside_tree() or hospital.is_queued_for_deletion() or not hospital.has_method("targets") or not hospital.has_method("contains_service") or not hospital.has_method("floor_height"): return {"ok":false,"reason":"actual_hospital"}
	var targets: Dictionary = hospital.targets()
	if targets.get("source_id") != HOSPITAL_ID or targets.get("data_sha256")!=HOSPITAL_DATA_SHA or not targets.get("service") is Vector3 or not targets.service.is_finite(): return {"ok":false,"reason":"authored_hospital_targets"}
	var binding: Variant = hit_owner.get("_binding")
	var token: Variant = hit_owner.get("_token")
	if not binding is Dictionary or not token is Dictionary or binding.get("owner_instance_id") != hit_owner.get_instance_id() or binding.get("scope") != "local_walk_ordinary": return {"ok":false,"reason":"owner_binding"}
	var reply: Dictionary = hit_owner._current(binding)
	if reply.is_empty() or not reply.get("row") is Dictionary or not is_same(reply.row,hit_owner._row): return {"ok":false,"reason":"same_mutable_row"}
	var lifecycle: Variant = hit_owner.get("_adapter")
	if not is_instance_valid(lifecycle) or not lifecycle.has_method("_fresh") or lifecycle._binding != binding or lifecycle._current.get_object() != hit_owner or not lifecycle._fresh() or not is_same(lifecycle._row,reply.row): return {"ok":false,"reason":"same_lifecycle_owner"}
	_owner=weakref(hit_owner); _hospital=weakref(hospital); _host=hit_owner._host
	_binding=binding.duplicate(true); _token=token.duplicate(); _row=reply.row; _lifecycle=lifecycle; _local_session=local_session
	if not _current(): dispose(); return {"ok":false,"reason":"current_life_and_loaded_hospital"}
	_phase="READY"
	return {"ok":true,"scope":"new_local_session_walk_in_treatment","source_id":_token.source_id,"life_generation":_token.life_generation,"server_authority":false}

func _current() -> bool:
	if not Thread.is_main_thread() or _disposed or _owner==null or _hospital==null or not is_instance_valid(_host): return false
	var owner: Variant = _owner.get_ref(); var hospital: Variant = _hospital.get_ref()
	if not is_instance_valid(owner) or not is_instance_valid(hospital) or not hospital.is_inside_tree() or hospital.is_queued_for_deletion() or not hospital.get("ready_for_use"): return false
	if owner._host != _host or owner._adapter != _lifecycle or owner._binding != _binding or owner._token != _token or not is_same(owner._row,_row): return false
	var registry: Dictionary=owner._registries.get(owner._registry_key,{})
	var owner_ref: Variant=registry.get("owners",{}).get(_token.source_id)
	if not owner_ref is WeakRef or owner_ref.get_ref()!=owner: return false
	if hospital.targets().get("data_sha256")!=HOSPITAL_DATA_SHA: return false
	if not _host.physical_life_current(_token) or hospital.get_world_3d() != _token.body.get_world_3d(): return false
	var reply: Dictionary = owner._current(_binding)
	if reply.is_empty() or not is_same(reply.get("row"),_row) or reply.get("owner_instance_id") != owner.get_instance_id(): return false
	if _lifecycle._retired or _lifecycle._busy or _lifecycle._binding != _binding or _lifecycle._current.get_object() != owner: return false
	if not _lifecycle._fresh() or not is_same(_lifecycle._row,_row): return false
	return _row.get("source_id")==_token.source_id and _row.get("life_generation")==_token.life_generation and _finite(_row.get("hp")) and _finite(_row.get("max_hp")) and _row.max_hp>0

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _can_walk() -> bool:
	if _row.get("dead",false) or _row.get("alive",true)==false or _row.hp<=0 or _row.get("_medicalDowned",false) or _row.get("_forcedCrawl",false): return false
	for key: String in ["_inVehicle","_ambulanceInTransit","_carriedByAmbulance","_evacuated"]:
		if _row.get(key,false): return false
	if not _host.target_current(_token) or _host._records[_token.source_id].get("physical_failed",false): return false
	if _host._ragdolls.has(_token.source_id) and _host._ragdolls[_token.source_id].status().mode != "IDLE": return false
	return not _host._records[_token.source_id].owner.dead

func snapshot() -> Dictionary:
	if not _current(): return {"ok":false,"can_walk":false,"phase":_phase,"reason":"stale_owner_or_hospital"}
	return {"ok":true,"hp":_row.hp,"max_hp":_row.max_hp,"can_walk":_can_walk(),"dead":bool(_row.get("dead",false)),"medical_downed":bool(_row.get("_medicalDowned",false)),"source_id":_token.source_id,"life_generation":_token.life_generation,"session_id":_token.session_id,"phase":_phase,"revision":_lifecycle._revision,"server_authority":false}

func targets() -> Dictionary:
	if not _current(): return {}
	return _hospital.get_ref().targets()

## The executor passes its actual current native navigation request ID after
## ARRIVED. A caller-supplied completion dictionary/callback cannot grant HP.
func begin(goal_request_id: int) -> Dictionary:
	if _busy or not _current() or not _can_walk() or _phase not in ["READY","COMPLETE","CANCELLED"] or _row.hp>=_row.max_hp or goal_request_id<0: return {"ok":false,"reason":"walk_in_treatment_unavailable"}
	_busy=true
	_request_id=goal_request_id; _navigation=_host._navigation
	_nav_lease=_host._records[_token.source_id].get("local_route_owner")
	if not _arrival_current(): _busy=false; return {"ok":false,"reason":"actual_current_service_arrival_required"}
	var now: float = _owner.get_ref()._now()
	if not is_finite(now) or now<0: _busy=false; return {"ok":false,"reason":"owner_clock"}
	_serial+=1; _active=_serial; _phase="TREATING"; _reason=""
	_last_now=now; _last_frame=Engine.get_physics_frames(); _elapsed_ms=0.0
	_hp_before=float(_row.hp); _max_hp=float(_row.max_hp); _revision_before=int(_lifecycle._revision)
	_busy=false
	return {"ok":true,"treatment_id":_active,"duration_ms":TREATMENT_MS,"hospital_id":HOSPITAL_ID}

func _arrival_current() -> bool:
	if not _current() or not _can_walk() or not is_instance_valid(_navigation) or _host._navigation!=_navigation: return false
	var record: Dictionary=_host._records[_token.source_id]
	if record.request!=_request_id or record.get("local_route_owner")!=_nav_lease: return false
	if _nav_lease is WeakRef and not is_instance_valid(_nav_lease.get_ref()): return false
	var body: CharacterBody3D=_token.body
	var hospital: Node3D=_hospital.get_ref()
	if not body.is_on_floor() or not hospital.contains_service(body.global_position) or Vector2(body.velocity.x,body.velocity.z).length()>.03 or body.velocity.y>.05: return false
	var result: Variant=_navigation.poll(_request_id)
	if not result is Dictionary or result.get("status")!="ARRIVED": return false
	if result.has("source_id") and (result.source_id!=_token.source_id or result.get("life_generation")!=_token.life_generation): return false
	# Native polling may run authority callbacks. Recheck exact objects and goal.
	return _current() and _can_walk() and _host._navigation==_navigation and record.request==_request_id and record.get("local_route_owner")==_nav_lease and body.is_on_floor() and hospital.contains_service(body.global_position)

func poll(treatment_id: int) -> Dictionary:
	if _results.has(treatment_id): return _results[treatment_id].duplicate(true)
	if _busy or _disposed or treatment_id<0 or treatment_id!=_active or _phase!="TREATING": return {"status":"CANCELLED","reason":"not_current_treatment"}
	_busy=true
	if not _arrival_current(): return _cancel_active("arrival_owner_or_goal_changed")
	if _lifecycle._revision!=_revision_before or float(_row.hp)!=_hp_before or float(_row.max_hp)!=_max_hp: return _cancel_active("health_changed_during_treatment")
	var frame := Engine.get_physics_frames()
	if frame==_last_frame: _busy=false; return {"status":"PENDING","treatment_id":_active,"elapsed_ms":_elapsed_ms}
	var now: float=_owner.get_ref()._now()
	var elapsed := now-_last_now
	if not is_finite(now) or elapsed<0 or elapsed>MAX_SAMPLE_GAP_MS or frame!=_last_frame+1: return _cancel_active("continuous_physics_presence_required")
	_elapsed_ms+=elapsed; _last_now=now; _last_frame=frame
	if _elapsed_ms<TREATMENT_MS: _busy=false; return {"status":"PENDING","treatment_id":_active,"elapsed_ms":_elapsed_ms}
	return _commit()

func _commit() -> Dictionary:
	if not _arrival_current() or not _lifecycle._fresh() or not is_same(_lifecycle._row,_row) or _lifecycle._busy or _lifecycle._revision!=_revision_before or _lifecycle._seen.size()>=4096: return _cancel_active("lifecycle_commit_lease")
	if _row.get("dead",false) or _row.get("_medicalDowned",false) or float(_row.hp)!=_hp_before or float(_row.max_hp)!=_max_hp or _row.hp<=0 or _row.hp>=_row.max_hp: return _cancel_active("health_commit_lease")
	var event_id := "local_hospital:"+_local_session+":"+str(get_instance_id())+":"+str(_active)
	if _lifecycle._seen.has(event_id): return _cancel_active("duplicate_treatment")
	# No external callback, clock input or visual mirror participates here. The
	# same lifecycle is held busy for its one synchronous HP/revision transition.
	_lifecycle._busy=true
	_lifecycle._seen[event_id]=true
	_row.hp=_row.max_hp
	_lifecycle._revision+=1
	_lifecycle._last_now=maxf(float(_lifecycle._last_now),_last_now)
	var receipt: Dictionary=_lifecycle._done(event_id,true,"hospital_walk_in_treatment",{})
	receipt["hospital"]={"source_id":HOSPITAL_ID,"goal_request_id":_request_id,"treatment_ms":_elapsed_ms,"hp_before":_hp_before,"hp_after":_row.hp,"local_session":_local_session,"policy":"user_requested_native_walk_in_treatment_v1"}
	_lifecycle._events[event_id]=receipt.duplicate(true)
	_owner.get_ref().last_result=receipt.duplicate(true)
	_phase="COMPLETE"; _busy=false
	var result := {"status":"COMPLETE","treatment_id":_active,"receipt":receipt}
	_store_result(result)
	return result.duplicate(true)

func _store_result(result: Dictionary) -> void:
	if _results.size()>=16: _results.erase(_results.keys()[0])
	_results[_active]=result.duplicate(true)

func _cancel_active(reason: String) -> Dictionary:
	_phase="CANCELLED"; _reason=reason; _busy=false
	var result := {"status":"CANCELLED","treatment_id":_active,"reason":reason,"hp_applied":false}
	_store_result(result)
	return result.duplicate(true)

## Cancellation is treatment-only. It never cancels or rewrites navigation,
## revives a capsule, touches death hooks, or removes a newer actor's request.
func cancel(treatment_id: int) -> Dictionary:
	if _results.has(treatment_id): return _results[treatment_id].duplicate(true)
	if _busy or treatment_id!=_active or _phase!="TREATING": return {"status":"CANCELLED","reason":"not_current_treatment"}
	return _cancel_active("cancelled")

func dispose() -> void:
	if _disposed: return
	if _phase=="TREATING": _cancel_active("disposed")
	_disposed=true; _phase="DISPOSED"; _owner=null; _hospital=null; _host=null; _lifecycle=null; _navigation=null; _nav_lease=null; _row={}
