class_name NativeLadderLifetimeGuard
extends RefCounted
## Caller-owned synchronous lifecycle observer. No process, root, rig or HP writes.
## Connect interrupted to the central owner's physical recovery branch.
signal interrupted(reason: String, receipt: Dictionary)
const PROVIDER:="GODOT_LADDER_LIFETIME_GUARD_V1"
const Executor=preload("res://scripts/traversal/ladder_physical_executor.gd")
var _executor: RefCounted
var _links: Array[Dictionary]=[]
var _epoch:=0
var _armed:=false
var _last: Dictionary={}

func arm(executor: RefCounted) -> Dictionary:
	disarm()
	if not is_instance_valid(executor) or not executor is Executor:
		return {"provider":PROVIDER,"valid":false,"reason":"executor_unavailable"}
	var authority: Dictionary=executor.lifetime_authority()
	if not authority.valid:
		return {"provider":PROVIDER,"valid":false,"reason":authority.reason}
	_executor=executor
	_armed=true
	_last.clear()
	var epoch:=_epoch
	_attach(authority.actor,&"actor_tree_exiting",epoch)
	for source: Dictionary in authority.sources:
		_attach(source.body,&"source_tree_exiting",epoch)
	return {"provider":PROVIDER,"valid":true,"reason":"armed","epoch":epoch,"connections":_links.size()}

func armed() -> bool: return _armed
func last_interruption() -> Dictionary: return _last.duplicate(true)

func disarm() -> void:
	_epoch+=1
	_armed=false
	for link: Dictionary in _links:
		if is_instance_valid(link.node) and link.node.tree_exiting.is_connected(link.callback):
			link.node.tree_exiting.disconnect(link.callback)
	_links.clear()
	_executor=null

func dispose() -> void:
	disarm()
	_last.clear()

func _attach(node: Node,reason: StringName,epoch: int) -> void:
	var callback:=_on_exit.bind(reason,epoch)
	node.tree_exiting.connect(callback)
	_links.append({"node":node,"callback":callback})

func _on_exit(reason: StringName,epoch: int) -> void:
	if not _armed or epoch!=_epoch: return
	var executor: RefCounted=_executor
	# Disconnect and revoke BEFORE external recovery callbacks can re-arm/dispose.
	disarm()
	if not is_instance_valid(executor) or not executor.busy(): return
	var receipt: Dictionary=executor.abort(str(reason))
	_last={"provider":PROVIDER,"reason":str(reason),"receipt":receipt.duplicate(true)}
	interrupted.emit(str(reason),receipt.duplicate(true))
