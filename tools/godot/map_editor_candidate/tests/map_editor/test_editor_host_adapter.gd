extends SceneTree
const Host = preload("res://scripts/map_editor/editor_host_adapter.gd")
var failures: Array[String] = []
var checks := 0
var session_stopped := false
var ready := true
var allow_resume := true
var allow_cancel := true
var valid_receipt := true
var reentrant_rejected := false
var adapter: RefCounted
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func pause(request: Dictionary) -> Dictionary:
	reentrant_rejected = not adapter.enter().ok
	session_stopped = true
	return {"ok": true, "receipt": {"owner_id": request.owner_id, "request_id": request.request_id, "token": "owner-issued"}}
func cancel(_request: Dictionary) -> bool:
	if allow_cancel: session_stopped = false
	return allow_cancel
func verify(_receipt: Dictionary) -> bool:
	return session_stopped and valid_receipt
func resume(receipt: Dictionary, _objects: Dictionary, _ground: Dictionary) -> Dictionary:
	if not allow_resume: return {"ok": false}
	session_stopped = false
	return {"ok": true, "owner_id": receipt.owner_id, "request_id": receipt.request_id}
func run() -> void:
	var main := Node.new()
	root.add_child(main)
	adapter = Host.new()
	var callbacks := {"pause_gameplay": pause, "cancel_pause": cancel, "verify_pause": verify, "resume_gameplay": resume, "transaction_ready": func(_receipt: Dictionary) -> bool: return ready, "ground_patch": func() -> Dictionary: return {"schema": 1}}
	check(not adapter.mount(main, {}).ok, "missing owner callbacks refused")
	check(adapter.mount(main, callbacks).ok, "explicit owner mounted")
	check(not adapter.mount(main, callbacks).ok, "second mount refused")
	check(not adapter.gameplay_blocked() and not adapter.transaction_ready(), "idle host unblocked without fabricated lease")
	check(adapter.enter().ok and session_stopped and adapter.gameplay_blocked() and adapter.transaction_ready(), "owner pause verified")
	check(reentrant_rejected, "pause callback cannot recursively acquire lease")
	var document := {"schema_version": 1, "map_id": "host", "metadata": {}, "objects": []}
	ready = false
	check(not adapter.leave(document).ok and session_stopped, "unfinished atomic transaction blocks resume")
	ready = true
	check(not adapter.leave({}).ok and session_stopped, "invalid object document blocks resume")
	allow_resume = false
	check(not adapter.leave(document).ok and session_stopped and adapter.gameplay_blocked(), "owner refusal retains stopped session")
	allow_resume = true
	check(adapter.leave(document).ok and not session_stopped and not adapter.gameplay_blocked(), "only exact owner restores session")
	valid_receipt = false
	check(not adapter.enter().ok and not session_stopped and not adapter.gameplay_blocked(), "invalid pause receipt rolled back by owner")
	allow_cancel = false
	check(not adapter.enter().ok and adapter.gameplay_blocked() and adapter.state().fault, "failed pause rollback remains blocked")
	main.free()
	check(not adapter.state().mounted and not adapter.enter().ok and adapter.gameplay_blocked(), "expired main lifetime cannot resume unrelated owner")
	for failure: String in failures: push_error(failure)
	print("editor host adapter: ", checks, " checks, failures=", failures.size(), "; explicit callback lease only, no main/LIVE acceptance")
	quit(0 if failures.is_empty() else 1)
