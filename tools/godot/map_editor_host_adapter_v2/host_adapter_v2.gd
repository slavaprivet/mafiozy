extends "res://scripts/map_editor/editor_host_adapter.gd"
## Tools-only boundary hardening. Actual gameplay callbacks still required.
## No physics, clocks, input polling, navigation or terrain owner is invented.
var _verifying := false
var _querying := false

func _workspace_node() -> Node:
	var node: Variant = _workspace.get_ref() if _workspace != null else null
	var owner := _main()
	return node if is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion() and owner != null and owner.is_ancestor_of(node) else null

func _workspace_same(node: Variant, parent: Variant) -> bool:
	if _workspace == null: return node == null
	return node != null and is_instance_valid(node) and _workspace_node() == node and node.get_parent() == parent

func _main() -> Node:
	var node := super._main()
	return node if node != null and not node.is_queued_for_deletion() else null

func mount(existing_main: Node, callbacks: Dictionary) -> Dictionary:
	if _verifying or _querying or not is_instance_valid(existing_main) or existing_main.is_queued_for_deletion():
		return _failure("Игровая сцена завершает работу")
	return super.mount(existing_main, callbacks)

func bind_workspace(workspace: Node) -> Dictionary:
	if _verifying or _querying or not is_instance_valid(workspace) or workspace.is_queued_for_deletion():
		return _failure("Редактор завершает работу")
	return super.bind_workspace(workspace)

func _lease_valid() -> bool:
	if _verifying: return false
	var owner := _main()
	if owner == null or _receipt.is_empty() or _receipt.get("owner_id") != owner.get_instance_id(): return false
	var receipt := _receipt.duplicate(true)
	var request := _request.duplicate(true)
	var workspace := _workspace_node()
	var parent := workspace.get_parent() if workspace != null else null
	if not _workspace_same(workspace, parent): return false
	var verify_callback: Callable = _callbacks.verify_pause
	if not verify_callback.is_valid(): return false
	_verifying = true
	var result: Variant = verify_callback.call(receipt.duplicate(true))
	_verifying = false
	# Readiness cannot outlive callback-induced owner/lease transitions.
	return _ok(result) and _main() == owner and _receipt == receipt and _request == request and _workspace_same(workspace, parent)

func transaction_ready() -> bool:
	if _querying or _verifying or _busy or _fault: return false
	var owner := _main()
	var receipt := _receipt.duplicate(true)
	var request := _request.duplicate(true)
	var workspace := _workspace_node()
	var parent := workspace.get_parent() if workspace != null else null
	_querying = true
	var ready_callback: Callable = _callbacks.transaction_ready if _callbacks.has("transaction_ready") else Callable()
	var result: bool = _lease_valid() and ready_callback.is_valid() and _ok(ready_callback.call(receipt.duplicate(true)))
	_querying = false
	return result and owner != null and _main() == owner and _receipt == receipt and _request == request and not _receipt.is_empty() and _workspace_same(workspace, parent)

func enter() -> Dictionary:
	if _verifying or _querying: return _failure("Проверка владельца уже выполняется")
	return super.enter()

func leave(objects: Dictionary) -> Dictionary:
	if _verifying or _querying: return _failure("Проверка владельца уже выполняется")
	if not transaction_ready(): return _failure("Игра остаётся остановленной: владелец или редактор не готовы")
	var checked := Document.validate_document(objects)
	if not checked.ok: return checked
	var owner := _main()
	var receipt := _receipt.duplicate(true)
	var request := _request.duplicate(true)
	var workspace := _workspace_node()
	var parent := workspace.get_parent() if workspace != null else null
	_busy = true
	var ground_callback: Callable = _callbacks.ground_patch
	var ground: Variant = ground_callback.call() if ground_callback.is_valid() else null
	# Ground extraction is another owner callback, not a pure local read.
	# Never restore physics after it invalidates the session/workspace/lease.
	if _main() != owner or owner == null or _receipt != receipt or _request != request or not _workspace_same(workspace, parent) or not _lease_valid():
		_fault = true
		_busy = false
		return _failure("Владелец изменился при получении карты; игра остаётся остановленной")
	if not ground is Dictionary or not Document._json_safe(ground):
		_busy = false
		return _failure("Нет проверенного документа земли")
	var resume_callback: Callable = _callbacks.resume_gameplay
	var result: Variant = resume_callback.call(receipt.duplicate(true), checked.document, ground.duplicate(true)) if resume_callback.is_valid() else null
	if result is Dictionary and result.get("ok", false) and _main() == owner and _workspace_same(workspace, parent) and _receipt == receipt and _request == request and result.get("owner_id") == owner.get_instance_id() and result.get("request_id") == request.get("request_id"):
		_receipt.clear()
		_request.clear()
		_busy = false
		return {"ok": true}
	_fault = not _lease_valid()
	_busy = false
	return _failure("Владелец не подтвердил восстановление игры")

func handle_input(event: InputEvent) -> bool:
	if _verifying or _querying: return true
	if _main() == null: return gameplay_blocked()
	var owner := _main()
	var workspace := _workspace_node()
	if workspace == null: return gameplay_blocked()
	var parent := workspace.get_parent()
	if _busy or _fault: return true
	if not _receipt.is_empty() and not _lease_valid():
		_fault = true
		return true
	if _main() != owner or not _workspace_same(workspace, parent):
		_fault = not _receipt.is_empty() or not _request.is_empty()
		return true
	var request := _request.duplicate(true)
	var receipt := _receipt.duplicate(true)
	var handled: Variant = workspace.handle_input(event)
	# The workspace callback itself can close/reparent/free editor or owner.
	# A false result never forwards an event across that transition.
	if _main() != owner or not _workspace_same(workspace, parent) or _request != request or _receipt != receipt or _busy or _fault:
		if (not _request.is_empty() or not _receipt.is_empty()) and (_main() != owner or not _workspace_same(workspace, parent)):
			_fault = true
		return true
	if not handled is bool:
		_fault = not _receipt.is_empty()
		return gameplay_blocked()
	# Even a stable editor callback may decline an unrelated key. While the
	# workspace/lease owns gameplay input, decline must not reach game listeners.
	return handled or gameplay_blocked()
