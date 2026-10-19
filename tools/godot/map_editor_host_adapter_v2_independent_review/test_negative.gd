extends SceneTree
const Host = preload("res://host_adapter_v2.gd")
class Workspace extends Node:
	var editor: Node
	var forwarded := 0
	func handle_input(_event: InputEvent) -> bool:
		forwarded += 1
		return false
class Editor extends Node:
	var active := true
var owner: Node
var workspace: Workspace
var host: RefCounted
var stopped := false
var queue_workspace := false
var queue_owner_in_ground := false
var resumed_queued_owner := false
var resumes := 0
var results := {}
var document := {"schema_version":1,"map_id":"negative","metadata":{},"objects":[]}
func _initialize() -> void: run.call_deferred()
func pause(request: Dictionary) -> Dictionary:
	stopped = true
	return {"ok":true,"receipt":{"owner_id":request.owner_id,"request_id":request.request_id,"token":"fixture-not-actual-owner"}}
func cancel(_request: Dictionary) -> bool: stopped = false; return true
func verify(_receipt: Dictionary) -> bool:
	if queue_workspace: workspace.queue_free()
	return stopped
func ready(_receipt: Dictionary) -> bool: return true
func ground() -> Dictionary:
	if queue_owner_in_ground: owner.queue_free()
	return {}
func resume(receipt: Dictionary, _objects: Dictionary, _ground: Dictionary) -> Dictionary:
	resumes += 1
	resumed_queued_owner = owner.is_queued_for_deletion()
	return {"ok":true,"owner_id":receipt.owner_id,"request_id":receipt.request_id}
func setup_fixture() -> void:
	owner = Node.new(); root.add_child(owner)
	workspace = Workspace.new(); owner.add_child(workspace)
	workspace.editor = Editor.new(); workspace.add_child(workspace.editor)
	host = Host.new()
	assert(host.mount(owner,{"pause_gameplay":pause,"cancel_pause":cancel,"verify_pause":verify,"transaction_ready":ready,"ground_patch":ground,"resume_gameplay":resume}).ok)
	assert(host.bind_workspace(workspace).ok)
	assert(host.enter().ok)
func run() -> void:
	setup_fixture()
	queue_workspace = true
	var consumed: bool = host.handle_input(InputEventKey.new())
	results.workspace_queued_during_verify = {"queued":workspace.is_queued_for_deletion(),"forwarded":workspace.forwarded,"consumed":consumed,"gameplay_blocked":host.gameplay_blocked()}
	queue_workspace = false
	owner.free()
	setup_fixture()
	queue_owner_in_ground = true
	var reply: Dictionary = host.leave(document)
	results.owner_queued_during_ground_patch = {"reply":reply,"resume_calls":resumes,"resume_received_queued_owner":resumed_queued_owner,"lease_retained":host.state().leased}
	owner.free()
	var reproduced: bool = results.workspace_queued_during_verify.forwarded == 1 and not consumed and resumed_queued_owner and resumes == 1
	print(JSON.stringify({"suite":"independent-v2-negative-review","reproduced":reproduced,"results":results,"actualMainAdmission":false,"gpu":false}))
	quit(0 if reproduced else 1)
