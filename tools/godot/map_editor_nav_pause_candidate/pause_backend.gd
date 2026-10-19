extends "res://scripts/navigation/preview_engine_navigation.gd"
## Source-only candidate. This protects the engine backend, NOT the population,
## navigation-host door, or resident movement owners. Never admit K from this alone.

const MAX_HELD_COMPLETIONS := 256
var _editor_owner: WeakRef
var _editor_receipt: Dictionary = {}
var _editor_serial := 0
var _editor_paused := false
var _editor_fault := false
var _held_completions: Array[Dictionary] = []
var _editor_map := RID()
var _editor_region := RID()
var _editor_iteration := -1
var _editor_state := ""
var _editor_next_job := 0
var _editor_job_count := 0
var _editor_baking_token := 0
var _editor_waiting_count := 0

func begin_editor_pause(owner: Node) -> Dictionary:
	if not Thread.is_main_thread() or _editor_paused or _disposed or _busy or not _version_ok or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_tree().paused:
		return {}
	if _authority.is_empty() or _generation < 1 or _version < 0:
		return {}
	# Jobs carry mutable status/path/admit references. Until their exact content
	# has an owner receipt, accept only a quiescent job ledger.
	if not _jobs.is_empty() or not _by_owner.is_empty(): return {}
	_editor_serial += 1
	_editor_owner = weakref(owner)
	_editor_map = _map; _editor_region = _region
	_editor_iteration = NavigationServer3D.map_get_iteration_id(_map) if _map.is_valid() else -1
	_editor_state = _state; _editor_next_job = _next_job; _editor_job_count = _jobs.size()
	_editor_baking_token = _baking_token; _editor_waiting_count = _waiting.size()
	_editor_receipt = {"serial":_editor_serial,"owner_id":owner.get_instance_id(),"backend_id":get_instance_id(),"authority":_authority,"generation":_generation,"version":_version,"epoch":_epoch,"map_iteration":_editor_iteration}
	_editor_fault = false
	_held_completions.clear()
	_editor_paused = true
	return _editor_receipt.duplicate(true)

func _receipt_current(receipt: Dictionary) -> bool:
	if not Thread.is_main_thread() or not _editor_paused or _editor_fault or _disposed or receipt != _editor_receipt or _editor_owner == null:
		return false
	var owner: Node = _editor_owner.get_ref()
	if not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or owner.get_instance_id() != int(receipt.get("owner_id", -1)):
		return false
	return _authority == receipt.authority and _generation == receipt.generation and _version == receipt.version and _epoch == receipt.epoch and _map == _editor_map and _region == _editor_region and _state == _editor_state and _next_job == _editor_next_job and _jobs.size() == _editor_job_count and _baking_token == _editor_baking_token and _waiting.size() == _editor_waiting_count and (NavigationServer3D.map_get_iteration_id(_map) if _map.is_valid() else -1) == _editor_iteration

func verify_editor_pause(receipt: Dictionary) -> bool:
	if not _receipt_current(receipt): return false
	var owner: Node = _editor_owner.get_ref()
	return owner.get_tree().paused

## Read-only unpaused preflight. Never clears the lease or replays callbacks.
func can_end_editor_pause(receipt: Dictionary) -> bool:
	if not _receipt_current(receipt): return false
	var owner: Node = _editor_owner.get_ref()
	return not owner.get_tree().paused

## Call after the tree is unpaused, before allowing another physics tick.
## A real main integration needs its own atomic two-phase owner handoff here.
func end_editor_pause(receipt: Dictionary) -> bool:
	if not can_end_editor_pause(receipt): return false
	_editor_paused = false
	_editor_receipt.clear(); _editor_owner = null
	var completions := _held_completions.duplicate()
	_held_completions.clear()
	for completion: Dictionary in completions:
		if completion.kind == "bake":
			super._finish_bake(completion.token, completion.mesh, completion.geometry, completion.started)
		else:
			super._finish_query(completion.id, completion.epoch, completion.iteration, completion.result)
	return true

func _hold_completion(completion: Dictionary) -> void:
	if _held_completions.size() >= MAX_HELD_COMPLETIONS:
		_editor_fault = true
		return # No unsafe replay; a faulted owner must remain HOLD until teardown.
	_held_completions.append(completion)

func _baked_callback(token: int, mesh: NavigationMesh, geometry: NavigationMeshSourceGeometryData3D, started: int) -> void:
	_finish_bake.call_deferred(token, mesh, geometry, started)

func _finish_bake(token: int, mesh: NavigationMesh, geometry: NavigationMeshSourceGeometryData3D, started: int) -> void:
	if _editor_paused:
		_hold_completion({"kind":"bake","token":token,"mesh":mesh,"geometry":geometry,"started":started})
		return
	super._finish_bake(token, mesh, geometry, started)

func _query_callback(id: int, epoch: int, iteration: int, result: NavigationPathQueryResult3D) -> void:
	_finish_query.call_deferred(id, epoch, iteration, result)

func _finish_query(id: int, epoch: int, iteration: int, result: NavigationPathQueryResult3D) -> void:
	if _editor_paused:
		_hold_completion({"kind":"query","id":id,"epoch":epoch,"iteration":iteration,"result":result})
		return
	super._finish_query(id, epoch, iteration, result)

func _reject_editor_write() -> bool:
	if not _editor_paused: return false
	_editor_fault = true
	return true

func publish_source(faces: PackedVector3Array, authority: String, generation: int, version: int) -> bool:
	if _reject_editor_write(): return false
	return super.publish_source(faces, authority, generation, version)

func request_path(owner: RefCounted, start: Vector3, target: Vector3, admit: Callable, exclude: Array[RID] = []) -> int:
	if _reject_editor_write(): return -1
	return super.request_path(owner, start, target, admit, exclude)

func pump(frame_id: int) -> void:
	if _reject_editor_write(): return
	super.pump(frame_id)

func admit_motion(id: int, from: Vector3, to: Vector3) -> bool:
	if _reject_editor_write(): return false
	return super.admit_motion(id, from, to)

func cancel(id: int) -> void:
	if _reject_editor_write(): return
	super.cancel(id)

func poll(id: int) -> Dictionary:
	if _reject_editor_write(): return {"status":"EDITOR_PAUSED"}
	return super.poll(id)

func state() -> String:
	return _editor_state if _editor_paused else super.state()

func dispose() -> void:
	if _editor_paused:
		_editor_paused = false
		_editor_fault = true
		_editor_receipt.clear(); _editor_owner = null; _held_completions.clear()
	super.dispose()
