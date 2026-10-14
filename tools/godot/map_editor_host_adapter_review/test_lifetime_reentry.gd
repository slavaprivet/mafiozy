extends SceneTree
## Negative boundary fixture only. Not actual-main gameplay admission.
const Host = preload("res://scripts/map_editor/editor_host_adapter.gd")
var checks := 0
var failures: Array[String] = []
var host: RefCounted
var owner: Node
var stopped := false
var recurse_next_verify := false
var nested_leave_ok := false
var document := {"schema_version": 1, "map_id": "boundary", "metadata": {}, "objects": []}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func pause(request: Dictionary) -> Dictionary:
	stopped = true
	return {"ok": true, "receipt": {"owner_id": request.owner_id, "request_id": request.request_id, "token": "fixture-only"}}

func cancel(_request: Dictionary) -> bool:
	stopped = false
	return true

func verify(_receipt: Dictionary) -> bool:
	if recurse_next_verify:
		recurse_next_verify = false
		nested_leave_ok = host.leave(document).ok
	# Deliberately callback-controlled boundary fixture: not a game owner.
	return true

func resume(receipt: Dictionary, _objects: Dictionary, _ground: Dictionary) -> Dictionary:
	stopped = false
	return {"ok": true, "owner_id": receipt.get("owner_id"), "request_id": receipt.get("request_id")}

func callbacks() -> Dictionary:
	return {"pause_gameplay": pause, "cancel_pause": cancel, "verify_pause": verify, "resume_gameplay": resume, "transaction_ready": func(_receipt: Dictionary) -> bool: return true, "ground_patch": func() -> Dictionary: return {}}

func run() -> void:
	owner = Node.new()
	root.add_child(owner)
	host = Host.new()
	check(host.mount(owner, callbacks()).ok, "fixture owner mounted")
	owner.queue_free()
	check(owner.is_queued_for_deletion() and owner.is_inside_tree(), "real queued owner still in tree before deletion")
	var queued_enter: Dictionary = host.enter()
	check(queued_enter.ok and host.state().leased, "negative reproduced: queued owner still admits lease")
	await process_frame
	check(not is_instance_valid(owner) and host.state().gameplay_blocked, "lease orphaned after real deferred deletion")

	owner = Node.new()
	root.add_child(owner)
	host = Host.new()
	check(host.mount(owner, callbacks()).ok and host.enter().ok, "fresh fixture lease")
	recurse_next_verify = true
	var ready: bool = host.transaction_ready()
	check(nested_leave_ok, "negative reproduced: verification callback can reenter leave")
	check(ready and not host.state().leased and not stopped, "negative reproduced: ready returned after reentrant lease release")
	owner.free()
	for failure in failures: push_error(failure)
	print(JSON.stringify({"suite": "editor-host-original-negative-lifetime-reentry", "checks": checks, "failures": failures, "queuedOwnerAdmissionReproduced": queued_enter.ok, "verificationReentryReproduced": nested_leave_ok, "readyAfterLeaseReleaseReproduced": ready, "fixtureOnly": true, "actualMainAdmission": false, "productionInstalled": false, "gpu": false}))
	quit(0 if failures.is_empty() else 1)
