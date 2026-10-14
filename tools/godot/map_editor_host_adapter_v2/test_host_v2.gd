extends SceneTree
const Host = preload("res://host_adapter_v2.gd")
class Workspace extends Node:
	var editor: Node
	var forwarded := 0
	var transition := ""
	var alternative: Node
	func handle_input(_event: InputEvent) -> bool:
		forwarded += 1
		if transition == "queue": queue_free()
		if transition == "free": free()
		if transition == "reparent": reparent(alternative)
		return false
class Editor extends Node:
	var active := true
var checks := 0
var failures: Array[String] = []
var host: RefCounted
var owner: Node
var stopped := false
var attack_verify := false
var attack_ready := false
var nested_enter_rejected := false
var nested_leave_rejected := false
var nested_ready_rejected := false
var queue_on_verify := false
var workspace: Workspace
var alternate_parent: Node
var workspace_transition := ""
var ground_transition := ""
var ready_transition := false
var resume_calls := 0
var document := {"schema_version":1,"map_id":"boundary","metadata":{},"objects":[]}
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func pause(request: Dictionary) -> Dictionary:
	stopped = true
	return {"ok":true,"receipt":{"owner_id":request.owner_id,"request_id":request.request_id,"token":"fixture-only"}}
func cancel(_request: Dictionary) -> bool:
	stopped = false
	return true
func reentry() -> void:
	nested_enter_rejected = not host.enter().ok
	nested_leave_rejected = not host.leave(document).ok
	nested_ready_rejected = not host.transaction_ready()
func verify(_receipt: Dictionary) -> bool:
	if attack_verify: reentry()
	if queue_on_verify: owner.queue_free()
	var transition := workspace_transition
	workspace_transition = ""
	if transition == "queue": workspace.queue_free()
	if transition == "free": workspace.free()
	if transition == "reparent": workspace.reparent(alternate_parent)
	return stopped
func ready(_receipt: Dictionary) -> bool:
	if attack_ready: reentry()
	if ready_transition:
		ready_transition = false
		workspace.queue_free()
	return true
func ground() -> Dictionary:
	if ground_transition == "queue_owner": owner.queue_free()
	if ground_transition == "queue_workspace": workspace.queue_free()
	if ground_transition == "free_workspace": workspace.free()
	if ground_transition == "invalidate_lease": stopped = false
	return {}
func resume(receipt: Dictionary, _objects: Dictionary, _ground: Dictionary) -> Dictionary:
	resume_calls += 1
	stopped = false
	return {"ok":true,"owner_id":receipt.owner_id,"request_id":receipt.request_id}
func callbacks() -> Dictionary:
	return {"pause_gameplay":pause,"cancel_pause":cancel,"verify_pause":verify,"resume_gameplay":resume,"transaction_ready":ready,"ground_patch":ground}
func setup_workspace() -> void:
	owner = Node.new(); root.add_child(owner)
	workspace = Workspace.new(); owner.add_child(workspace)
	workspace.editor = Editor.new(); workspace.add_child(workspace.editor)
	alternate_parent = Node.new(); root.add_child(alternate_parent)
	host = Host.new()
	check(host.mount(owner, callbacks()).ok and host.bind_workspace(workspace).ok and host.enter().ok,"fresh workspace fixture lease")
func cleanup_workspace() -> void:
	if is_instance_valid(owner): owner.free()
	if is_instance_valid(alternate_parent): alternate_parent.free()
	workspace_transition = ""; ground_transition = ""; ready_transition = false
func run() -> void:
	owner = Node.new(); root.add_child(owner); owner.queue_free()
	host = Host.new()
	check(not host.mount(owner,callbacks()).ok,"queued mount refused")
	await process_frame
	owner = Node.new(); root.add_child(owner); host = Host.new()
	check(host.mount(owner,callbacks()).ok,"live fixture mounted")
	owner.queue_free()
	check(not host.enter().ok and not stopped,"queued enter refused before pause")
	await process_frame
	owner = Node.new(); root.add_child(owner); host = Host.new()
	check(host.mount(owner,callbacks()).ok and host.enter().ok,"fresh genuine lifetime fixture")
	attack_verify = true
	check(host.transaction_ready(),"outer verification preserves existing fixture lease")
	check(nested_enter_rejected and nested_leave_rejected and nested_ready_rejected,"verify reentry refused")
	check(host.state().leased and stopped,"verification cannot release lease")
	attack_verify = false; attack_ready = true
	check(host.transaction_ready(),"ready callback outer gate retained")
	check(nested_enter_rejected and nested_leave_rejected and nested_ready_rejected,"ready callback reentry refused")
	check(host.state().leased and stopped,"ready callback cannot release lease")
	attack_ready = false
	check(host.leave(document).ok and not host.state().leased and not stopped,"normal owner restore works")
	check(host.enter().ok,"normal subsequent acquire works")
	queue_on_verify = true
	check(not host.transaction_ready(),"owner queued during verify invalidates readiness")
	check(host.state().leased and host.gameplay_blocked(),"queued owner's lease retained for recovery")
	check(host.handle_input(InputEventKey.new()),"queued owner's retained lease consumes input without workspace forwarding")
	await process_frame
	check(not host.state().mounted and not host.leave(document).ok and host.gameplay_blocked(),"expired owner never restores unrelated game")
	check(host.handle_input(InputEventKey.new()),"orphan lease remains an input barrier")
	queue_on_verify = false
	for transition: String in ["queue", "free", "reparent"]:
		setup_workspace()
		workspace_transition = transition
		check(host.handle_input(InputEventKey.new()),"callback transition consumes input: " + transition)
		check(not is_instance_valid(workspace) or workspace.forwarded == 0,"callback transition never forwards stale workspace: " + transition)
		check(host.gameplay_blocked() and host.state().leased,"workspace transition retains blocked lease: " + transition)
		cleanup_workspace()
	for transition: String in ["queue_owner", "queue_workspace", "free_workspace", "invalidate_lease"]:
		setup_workspace()
		ground_transition = transition
		var calls_before := resume_calls
		check(not host.leave(document).ok,"post-ground transition refused: " + transition)
		check(resume_calls == calls_before,"post-ground transition never invokes resume: " + transition)
		check(host.gameplay_blocked() and host.state().leased and host.state().fault,"post-ground transition retains actionable fault: " + transition)
		cleanup_workspace()
	setup_workspace()
	ready_transition = true
	check(not host.transaction_ready() and host.state().leased,"readiness callback cannot discard queued workspace barrier")
	cleanup_workspace()
	for transition: String in ["queue", "reparent"]:
		setup_workspace()
		workspace.transition = transition
		workspace.alternative = alternate_parent
		check(host.handle_input(InputEventKey.new()),"workspace callback transition consumes event: " + transition)
		check(host.gameplay_blocked() and host.state().leased and host.state().fault,"workspace callback transition retains fault: " + transition)
		cleanup_workspace()
	setup_workspace()
	check(host.handle_input(InputEventKey.new()) and workspace.forwarded == 1,"stable unhandled editor input is still consumed while leased")
	check(host.leave(document).ok,"normal post-input owner restore")
	workspace.editor.active = false
	check(not host.handle_input(InputEventKey.new()),"idle editor preserves unrelated input forwarding")
	cleanup_workspace()
	for failure in failures: push_error(failure)
	print(JSON.stringify({"suite":"host-v2-lifetime-reentry","checks":checks,"failures":failures,"fixtureOnly":true,"actualMainAdmission":false,"gpu":false,"productionInstalled":false}))
	quit(0 if failures.is_empty() else 1)
