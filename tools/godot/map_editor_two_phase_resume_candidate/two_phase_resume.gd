extends RefCounted
## Source-only exit gate for an editor lease on the actual main thread.
## This does NOT adapt the old end_editor_pause methods: they can release one
## owner and then fail on another. The composite owner must implement v2.

const CONTRACT_VERSION := 2
var _prepared := false
var _finished := false
var _root: WeakRef
var _workspace: WeakRef
var _population: WeakRef
var _main_receipt: Dictionary = {}
var _population_receipt: Dictionary = {}
var _document: Dictionary = {}
var _ground: Dictionary = {}
var _ticket: Dictionary = {}
var _owner_id := 0

func prepare(root: Node, workspace: Node, population: Object, main_receipt: Dictionary, population_receipt: Dictionary, document: Dictionary, ground: Dictionary) -> Dictionary:
	if _prepared or _finished or not Thread.is_main_thread(): return {"ok":false,"reason":"transaction_busy_or_thread"}
	if not is_instance_valid(root) or root.is_queued_for_deletion() or not root.is_inside_tree(): return {"ok":false,"reason":"root_lifetime"}
	if not is_instance_valid(workspace) or not is_instance_valid(population): return {"ok":false,"reason":"owner_lifetime"}
	if not root.get_tree().paused: return {"ok":false,"reason":"tree_not_paused"}
	if not workspace.has_method("_verify_pause") or not workspace.has_method("_transaction_ready") or not population.has_method("verify_editor_pause"):
		return {"ok":false,"reason":"current_receipt_api_missing"}
	if not workspace._verify_pause(main_receipt) or not workspace._transaction_ready(main_receipt) or not population.verify_editor_pause(population_receipt):
		return {"ok":false,"reason":"receipt_or_input_changed"}
	# All currently available APIs stop here. Do not call can_end_editor_pause:
	# it requires the tree unpaused and cannot reserve a rollback-safe release.
	if not workspace.has_method("editor_resume_contract_version") or not workspace.has_method("prepare_editor_resume_atomic") or not workspace.has_method("abort_editor_resume_atomic") or not workspace.has_method("commit_editor_resume_atomic") or not workspace.has_method("editor_resume_postcondition"):
		return {"ok":false,"reason":"atomic_owner_api_missing"}
	if workspace.editor_resume_contract_version() != CONTRACT_VERSION:
		return {"ok":false,"reason":"atomic_owner_version"}
	var ticket: Variant = workspace.prepare_editor_resume_atomic(main_receipt, population, population_receipt, document, ground)
	if not (ticket is Dictionary) or not ticket.get("ok", false) or not ticket.has("token"):
		return {"ok":false,"reason":"atomic_prepare_refused"}
	_root = weakref(root); _workspace = weakref(workspace); _population = weakref(population)
	_main_receipt = main_receipt.duplicate(true); _population_receipt = population_receipt.duplicate(true)
	_document = document.duplicate(true); _ground = ground.duplicate(true); _ticket = ticket.duplicate(true)
	_owner_id = root.get_instance_id(); _prepared = true
	return {"ok":true,"ticket":_ticket.duplicate(true)}

func commit(ticket: Dictionary) -> Dictionary:
	if not _prepared or _finished or not Thread.is_main_thread() or ticket != _ticket:
		return {"ok":false,"reason":"stale_or_foreign_ticket"}
	var root: Node = _root.get_ref() if _root != null else null
	var workspace: Node = _workspace.get_ref() if _workspace != null else null
	var population: Object = _population.get_ref() if _population != null else null
	if not is_instance_valid(root) or not is_instance_valid(workspace) or not is_instance_valid(population) or root.is_queued_for_deletion() or not root.is_inside_tree() or root.get_instance_id() != _owner_id:
		return _hold(root, "owner_lifetime")
	if not root.get_tree().paused or not workspace._verify_pause(_main_receipt) or not workspace._transaction_ready(_main_receipt) or not population.verify_editor_pause(_population_receipt):
		return _hold(root, "late_receipt_or_input")
	# v2 owner must commit EVERY lease (clock, residents, policy, nav queue,
	# backend, water and root) as a single no-fail operation. It must neither
	# replay callbacks nor run a physics tick until all owners are committed.
	var result: Variant = workspace.commit_editor_resume_atomic(_ticket.duplicate(true), _main_receipt.duplicate(true), _population_receipt.duplicate(true), _document.duplicate(true), _ground.duplicate(true))
	if not (result is Dictionary) or not result.get("ok", false):
		return _hold(root, "atomic_commit_refused_or_ambiguous")
	if not workspace.editor_resume_postcondition(_ticket) or root.get_tree().paused:
		return _hold(root, "atomic_postcondition_failed")
	_finished = true; _prepared = false
	return {"ok":true,"owner_id":_owner_id}

func abort(ticket: Dictionary) -> Dictionary:
	if not _prepared or _finished or not Thread.is_main_thread() or ticket != _ticket:
		return {"ok":false,"reason":"stale_or_foreign_ticket"}
	var root: Node = _root.get_ref() if _root != null else null
	var workspace: Node = _workspace.get_ref() if _workspace != null else null
	var population: Object = _population.get_ref() if _population != null else null
	if not is_instance_valid(root) or not is_instance_valid(workspace) or not is_instance_valid(population) or not root.is_inside_tree() or not root.get_tree().paused:
		return _hold(root, "abort_owner_lifetime")
	if not workspace._verify_pause(_main_receipt) or not population.verify_editor_pause(_population_receipt):
		return _hold(root, "abort_receipt_changed")
	var result: Variant = workspace.abort_editor_resume_atomic(_ticket.duplicate(true))
	if not (result is Dictionary) or not result.get("ok", false):
		return _hold(root, "abort_refused_or_ambiguous")
	_finished = true; _prepared = false
	return {"ok":true,"editor_still_paused":true}

func _hold(root: Node, reason: String) -> Dictionary:
	# Never advance gameplay after an ambiguous partial release. This is a
	# terminal lease: only the actual owner may diagnose/recover or tear down.
	if is_instance_valid(root) and root.is_inside_tree(): root.get_tree().paused = true
	_finished = true; _prepared = false
	return {"ok":false,"reason":reason,"terminal_hold":true}
