extends RefCounted
## Explicit owner callbacks only. Never finds actors/nav/water by node names,
## toggles SceneTree.paused, or overrides game authority/source receipts.
const Document = preload("res://scripts/map_editor/map_document.gd")
var _owner: WeakRef
var _workspace: WeakRef
var _callbacks: Dictionary = {}
var _receipt: Dictionary = {}
var _request: Dictionary = {}
var _busy := false
var _fault := false
var _sequence := 0

static func _ok(value: Variant) -> bool:
	return (value is bool and value) or (value is Dictionary and value.get("ok", false) == true)

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func mount(existing_main: Node, callbacks: Dictionary) -> Dictionary:
	if _owner != null or not is_instance_valid(existing_main) or not existing_main.is_inside_tree(): return _failure("Нужна текущая игровая сцена")
	for name: String in ["pause_gameplay", "cancel_pause", "verify_pause", "resume_gameplay", "transaction_ready", "ground_patch"]:
		if not callbacks.get(name) is Callable or not callbacks[name].is_valid(): return _failure("Нет обработчика владельца: " + name)
	_owner = weakref(existing_main)
	_callbacks = callbacks.duplicate()
	return {"ok": true, "enter_gate": enter, "leave_gate": leave, "transaction_ready": transaction_ready}

func _main() -> Node:
	var node: Variant = _owner.get_ref() if _owner != null else null
	return node if is_instance_valid(node) and node.is_inside_tree() else null

func is_mounted_owner(owner: Node) -> bool:
	return is_instance_valid(owner) and _main() == owner

func bind_workspace(workspace: Node) -> Dictionary:
	var owner := _main()
	if owner == null or _workspace != null or not is_instance_valid(workspace) or not owner.is_ancestor_of(workspace) or not workspace.has_method("handle_input"):
		return _failure("Редактор должен принадлежать текущей игровой сцене")
	_workspace = weakref(workspace)
	return {"ok": true}

func _lease_valid() -> bool:
	var owner := _main()
	if owner == null or _receipt.is_empty() or _receipt.get("owner_id") != owner.get_instance_id(): return false
	return _ok(_callbacks.verify_pause.call(_receipt.duplicate(true)))

func transaction_ready() -> bool:
	return not _busy and not _fault and _lease_valid() and _ok(_callbacks.transaction_ready.call(_receipt.duplicate(true)))

func enter() -> Dictionary:
	var owner := _main()
	if owner == null or _busy or _fault: return _failure("Игровая сессия недоступна или требует восстановления")
	if not _receipt.is_empty(): return {"ok": true} if _lease_valid() else _failure("Владелец остановленной сессии изменился")
	_busy = true
	_sequence += 1
	_request = {"owner_id": owner.get_instance_id(), "request_id": "%s:%s:%s" % [get_instance_id(), _sequence, Time.get_ticks_usec()]}
	var result: Variant = _callbacks.pause_gameplay.call(_request.duplicate(true))
	var candidate: Variant = result.get("receipt") if result is Dictionary else null
	if result is Dictionary and result.get("ok", false) and candidate is Dictionary and candidate.get("owner_id") == _request.owner_id and candidate.get("request_id") == _request.request_id and candidate.get("token") is String and not candidate.token.is_empty():
		_receipt = candidate.duplicate(true)
		if _lease_valid():
			_busy = false
			return {"ok": true}
	# Owner must undo even partially completed pause; never guess previous flags.
	var cancelled: Variant = _callbacks.cancel_pause.call(_request.duplicate(true))
	_fault = not _ok(cancelled)
	if not _fault:
		_receipt.clear()
		_request.clear()
	_busy = false
	return _failure("Остановка игры не подтверждена" if not _fault else "Остановка и её откат не подтверждены; требуется восстановление владельцем")

func leave(objects: Dictionary) -> Dictionary:
	if not transaction_ready(): return _failure("Игра остаётся остановленной: транзакция или игровой владелец не готовы")
	var checked := Document.validate_document(objects)
	if not checked.ok: return checked
	_busy = true
	var ground: Variant = _callbacks.ground_patch.call()
	if not ground is Dictionary or not Document._json_safe(ground):
		_busy = false
		return _failure("Нет проверенного документа земли")
	# This owner callback rebuilds all dependent geometry/nav/water receipts and
	# restores only its captured input/physics state. It must refuse atomically.
	var result: Variant = _callbacks.resume_gameplay.call(_receipt.duplicate(true), checked.document, ground.duplicate(true))
	var owner := _main()
	if result is Dictionary and result.get("ok", false) and owner != null and result.get("owner_id") == owner.get_instance_id() and result.get("request_id") == _request.get("request_id"):
		_receipt.clear()
		_request.clear()
		_busy = false
		return {"ok": true}
	_fault = not _lease_valid()
	_busy = false
	return _failure("Владелец не подтвердил восстановление игры")

func gameplay_blocked() -> bool:
	if _busy or _fault or not _request.is_empty() or not _receipt.is_empty(): return true
	var workspace: Variant = _workspace.get_ref() if _workspace != null else null
	return is_instance_valid(workspace) and is_instance_valid(workspace.editor) and workspace.editor.active

func handle_input(event: InputEvent) -> bool:
	var workspace: Variant = _workspace.get_ref() if _workspace != null else null
	if _main() == null or not is_instance_valid(workspace): return false
	if _busy or _fault: return true
	if not _receipt.is_empty() and not _lease_valid():
		_fault = true
		return true
	return workspace.handle_input(event)

func state() -> Dictionary:
	return {"mounted": _main() != null, "leased": not _receipt.is_empty(), "busy": _busy, "fault": _fault, "gameplay_blocked": gameplay_blocked()}
