extends SceneTree
const Host = preload("res://host_adapter_v2.gd")
class Workspace extends Node:
	var editor: Node
	var forwarded := 0
	var queue_on_input := false
	func handle_input(_event: InputEvent) -> bool:
		forwarded += 1
		if queue_on_input: queue_free()
		return false
class Editor extends Node:
	var active := true
var owner: Node
var workspace: Workspace
var host: RefCounted
var stopped := false
var queue_in_verify := false
var queue_in_ground := false
var resumes := 0
var document := {"schema_version":1,"map_id":"review2","metadata":{},"objects":[]}
func _initialize() -> void: run.call_deferred()
func pause(request: Dictionary) -> Dictionary:
	stopped = true
	return {"ok":true,"receipt":{"owner_id":request.owner_id,"request_id":request.request_id,"token":"fixture"}}
func cancel(_request: Dictionary) -> bool: stopped = false; return true
func verify(_receipt: Dictionary) -> bool:
	if queue_in_verify: workspace.queue_free()
	return stopped
func ready(_receipt: Dictionary) -> bool: return true
func ground() -> Dictionary:
	if queue_in_ground: owner.queue_free()
	return {}
func resume(receipt: Dictionary, _objects: Dictionary, _ground: Dictionary) -> Dictionary:
	resumes += 1
	stopped = false
	return {"ok":true,"owner_id":receipt.owner_id,"request_id":receipt.request_id}
func setup() -> void:
	owner = Node.new(); root.add_child(owner)
	workspace = Workspace.new(); owner.add_child(workspace)
	workspace.editor = Editor.new(); workspace.add_child(workspace.editor)
	host = Host.new()
	assert(host.mount(owner,{"pause_gameplay":pause,"cancel_pause":cancel,"verify_pause":verify,"transaction_ready":ready,"ground_patch":ground,"resume_gameplay":resume}).ok)
	assert(host.bind_workspace(workspace).ok)
	assert(host.enter().ok)
func run() -> void:
	setup()
	queue_in_verify = true
	var first_consumed: bool = host.handle_input(InputEventKey.new())
	var verify_case := {"queued":workspace.is_queued_for_deletion(),"forwarded":workspace.forwarded,"consumed":first_consumed,"leased":host.state().leased,"blocked":host.gameplay_blocked()}
	owner.free()
	queue_in_verify = false
	setup()
	queue_in_ground = true
	var reply: Dictionary = host.leave(document)
	var ground_case := {"refused":not reply.ok,"owner_queued":owner.is_queued_for_deletion(),"resumes":resumes,"leased":host.state().leased,"fault":host.state().fault}
	owner.free()
	queue_in_ground = false
	setup()
	workspace.queue_on_input = true
	var third_consumed: bool = host.handle_input(InputEventKey.new())
	var input_case := {"queued":workspace.is_queued_for_deletion(),"forwarded":workspace.forwarded,"consumed":third_consumed,"leased":host.state().leased,"blocked":host.gameplay_blocked()}
	owner.free()
	var old_reproduced: bool = not (verify_case.queued and verify_case.forwarded == 0 and verify_case.consumed and verify_case.leased and verify_case.blocked and ground_case.refused and ground_case.owner_queued and ground_case.resumes == 0 and ground_case.leased and ground_case.fault)
	var new_hole_reproduced: bool = input_case.queued and input_case.forwarded == 1 and not input_case.consumed and input_case.leased and input_case.blocked
	print(JSON.stringify({"suite":"independent-v2-review2-negative","old_reproduced":old_reproduced,"new_hole_reproduced":new_hole_reproduced,"verify_case":verify_case,"ground_case":ground_case,"input_case":input_case,"fixtureOnly":true,"actualMainAdmission":false,"gpu":false}))
	quit(0 if not old_reproduced and new_hole_reproduced else 1)
