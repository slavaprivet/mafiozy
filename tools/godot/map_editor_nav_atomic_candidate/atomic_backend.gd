extends "res://scripts/navigation/pause_backend.gd"
## Two-phase source candidate. Lease release occurs while the tree is paused;
## callback replay is a separate post-global-release operation.
var _atomic_ticket: Dictionary = {}
var _atomic_serial := 0
var _atomic_committed := false
var _atomic_flush_pending := false
var _atomic_flushing := false
var _atomic_replayed := 0
var _atomic_owner: WeakRef

func begin_editor_pause(owner: Node) -> Dictionary:
	if _atomic_flush_pending or _atomic_flushing: return {}
	return super.begin_editor_pause(owner)

func prepare_editor_resume_atomic(receipt: Dictionary) -> Dictionary:
	if not _receipt_current(receipt) or _atomic_committed or _atomic_flush_pending: return {}
	var owner: Node = _editor_owner.get_ref()
	if not owner.get_tree().paused: return {}
	_atomic_serial += 1
	_atomic_ticket = {"serial":_atomic_serial,"backend_id":get_instance_id(),"receipt":receipt.duplicate(true)}
	_atomic_owner = weakref(owner)
	return _atomic_ticket.duplicate(true)

func commit_editor_resume_atomic(ticket: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_ticket or _atomic_committed or _atomic_flush_pending: return {}
	if not _receipt_current(_atomic_ticket.receipt): return {}
	var owner: Node = _editor_owner.get_ref()
	if not owner.get_tree().paused: return {}
	_atomic_committed = true # No callback replay and no lease release here.
	return ticket.duplicate(true)

func abort_editor_resume_atomic(ticket: Dictionary) -> bool:
	if not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_ticket or not _editor_paused or _atomic_flush_pending: return false
	_atomic_committed = false
	_atomic_ticket.clear()
	_atomic_owner = null
	return true

func finalize_editor_resume_atomic(ticket: Dictionary) -> bool:
	if not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_ticket or not _atomic_committed or not _editor_paused or _editor_owner == null: return false
	var owner: Node = _editor_owner.get_ref()
	if not is_instance_valid(owner) or not owner.get_tree().paused: return false
	_editor_paused = false
	_editor_receipt.clear(); _editor_owner = null
	_atomic_committed = false; _atomic_flush_pending = true
	return true

func flush_editor_resume_atomic(ticket: Dictionary) -> bool:
	if not Thread.is_main_thread() or ticket.is_empty() or ticket != _atomic_ticket or not _atomic_flush_pending or _atomic_flushing or _editor_fault or _disposed: return false
	if not _atomic_flush_owner_current(ticket):
		_editor_fault = true
		return false
	_atomic_flushing = true
	# Pop before invocation: an effectful callback is never replayed a second time.
	# Keep the lease guard through reentrant callbacks and cap the total batch.
	while not _held_completions.is_empty():
		if _atomic_replayed >= MAX_HELD_COMPLETIONS or not _atomic_flush_owner_current(ticket) or _editor_fault or _disposed:
			_editor_fault = true
			_atomic_flushing = false
			return false
		var completion: Dictionary = _held_completions.pop_front()
		_atomic_replayed += 1
		match completion.get("kind", ""):
			"bake":
				super._finish_bake(completion.token, completion.mesh, completion.geometry, completion.started)
			"query":
				super._finish_query(completion.id, completion.epoch, completion.iteration, completion.result)
			_:
				_editor_fault = true
		if _editor_fault or _disposed or ticket != _atomic_ticket or not _atomic_flush_owner_current(ticket):
			_editor_fault = true
			_atomic_flushing = false
			return false
	_atomic_flushing = false
	_atomic_flush_pending = false; _atomic_ticket.clear(); _atomic_owner = null
	_atomic_replayed = 0
	return true

func _atomic_flush_owner_current(ticket: Dictionary) -> bool:
	var owner: Node = _atomic_owner.get_ref() if _atomic_owner != null else null
	return is_instance_valid(owner) and not owner.is_queued_for_deletion() and owner.is_inside_tree() and owner.get_instance_id() == int(ticket.receipt.get("owner_id", -1)) and not owner.get_tree().paused

func can_cancel_editor_pause(receipt: Dictionary) -> bool:
	return _atomic_ticket.is_empty() and _held_completions.is_empty() and can_end_editor_pause(receipt)

func cancel_editor_pause(receipt: Dictionary) -> bool:
	if not can_cancel_editor_pause(receipt): return false
	return super.end_editor_pause(receipt)

func _finish_bake(token: int, mesh: NavigationMesh, geometry: NavigationMeshSourceGeometryData3D, started: int) -> void:
	if _atomic_flush_pending:
		_hold_completion({"kind":"bake","token":token,"mesh":mesh,"geometry":geometry,"started":started})
		return
	super._finish_bake(token, mesh, geometry, started)

func _finish_query(id: int, epoch: int, iteration: int, result: NavigationPathQueryResult3D) -> void:
	if _atomic_flush_pending:
		_hold_completion({"kind":"query","id":id,"epoch":epoch,"iteration":iteration,"result":result})
		return
	super._finish_query(id, epoch, iteration, result)

func _reject_editor_write() -> bool:
	if _atomic_flush_pending or _atomic_flushing:
		_editor_fault = true
		return true
	return super._reject_editor_write()

func state() -> String:
	return _editor_state if _atomic_flush_pending else super.state()

## The old one-shot release must not bypass the global commit protocol.
func end_editor_pause(_receipt: Dictionary) -> bool:
	return false

func dispose() -> void:
	_atomic_ticket.clear(); _atomic_committed = false; _atomic_flush_pending = false; _atomic_flushing = false; _atomic_replayed = 0; _atomic_owner = null
	super.dispose()
