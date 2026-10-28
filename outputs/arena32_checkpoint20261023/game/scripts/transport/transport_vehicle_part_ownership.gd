extends RefCounted
## Pure arbitration for authored vehicle part nodes. The caller alone performs
## detach/copy/reparent/visibility/physics work and commits only after success.

const MAX_DISTINCT_NODES:=12
const MAX_ALIASES:=64
const MAX_RESERVE_ALIASES:=12
const META_VEHICLE_ID:=&"vehicle_id"
const META_LIFE_GENERATION:=&"life_generation"

var _configured:=false
var _disposed:=false
var _vehicle_id: String=""
var _life_generation:=0
var _root_ref: WeakRef
var _bindings: Dictionary={}
var _claims: Dictionary={}
var _leases: Dictionary={}
var _epoch:=1
var _next_lease:=1

func configure(vehicle_id_value: Variant,life_generation_value: Variant,vehicle_root: Node3D,bindings_value: Variant) -> Dictionary:
	if _configured or _disposed: return _error("lifetime")
	if not vehicle_id_value is String or (vehicle_id_value as String).is_empty() or (vehicle_id_value as String).length()>256 or not life_generation_value is int or int(life_generation_value)<1: return _error("identity")
	if not is_instance_valid(vehicle_root) or not vehicle_root.is_inside_tree() or not bindings_value is Dictionary or bindings_value.is_empty() or bindings_value.size()>MAX_ALIASES: return _error("bindings")
	if not vehicle_root.has_meta(META_VEHICLE_ID) or not vehicle_root.has_meta(META_LIFE_GENERATION) or vehicle_root.get_meta(META_VEHICLE_ID)!=vehicle_id_value or vehicle_root.get_meta(META_LIFE_GENERATION)!=life_generation_value: return _error("root_identity")
	var bindings: Dictionary=bindings_value
	var admitted: Dictionary={}; var distinct: Dictionary={}
	for alias_value: Variant in bindings:
		if not alias_value is String or (alias_value as String).is_empty() or (alias_value as String).length()>128: return _error("alias")
		var alias: String=alias_value; var node_value: Variant=bindings[alias]
		if node_value==null:
			admitted[alias]={"missing":true}
			continue
		if not node_value is Node3D or not is_instance_valid(node_value) or node_value==vehicle_root or not vehicle_root.is_ancestor_of(node_value): return _error("node_boundary")
		var node: Node3D=node_value; var node_id:=node.get_instance_id()
		distinct[node_id]=true
		if distinct.size()>MAX_DISTINCT_NODES: return _error("node_limit")
		admitted[alias]={"missing":false,"node_id":node_id,"node_ref":weakref(node)}
	_vehicle_id=vehicle_id_value; _life_generation=life_generation_value; _root_ref=weakref(vehicle_root); _bindings=admitted; _configured=true
	return {"ok":true,"aliases":_bindings.size(),"distinct_nodes":distinct.size(),"missing_aliases":_missing_count()}

func reserve(vehicle_id_value: Variant,life_generation_value: Variant,channel_value: Variant,aliases_value: Variant) -> Dictionary:
	var boundary:=_boundary(vehicle_id_value,life_generation_value)
	if not boundary.ok: return boundary
	if not channel_value is String or (channel_value as String).is_empty() or (channel_value as String).length()>128 or not aliases_value is Array or aliases_value.is_empty() or aliases_value.size()>MAX_RESERVE_ALIASES: return _error("request")
	var aliases: Array=aliases_value; var seen_aliases: Dictionary={}; var nodes: Dictionary={}; var node_order: Array[int]=[]
	for alias_value: Variant in aliases:
		if not alias_value is String or not _bindings.has(alias_value) or seen_aliases.has(alias_value): return _error("alias")
		seen_aliases[alias_value]=true
		var binding: Dictionary=_bindings[alias_value]
		if binding.missing: return _error("authored_missing")
		var live:=_live_binding(binding,true)
		if not live.ok: return live
		var node_id: int=binding.node_id
		if _claims.has(node_id): return _error("owned")
		if not nodes.has(node_id): nodes[node_id]=live.node; node_order.append(node_id)
	# No claim changes occur until every alias and physical node passes.
	var token: String="part-lease:%d:%d"%[_epoch,_next_lease]; _next_lease+=1
	var node_refs: Array=[]; var canonical_nodes: Array[Node3D]=[]
	for node_id in node_order:
		var node: Node3D=nodes[node_id]; canonical_nodes.append(node); node_refs.append({"node_id":node_id,"node_ref":weakref(node)})
		_claims[node_id]={"token":token,"channel":channel_value,"state":"RESERVED"}
	_leases[token]={"state":"RESERVED","epoch":_epoch,"channel":channel_value,"aliases":aliases.duplicate(),"nodes":node_refs}
	return {"ok":true,"lease_token":token,"channel":channel_value,"aliases":aliases.duplicate(),"nodes":canonical_nodes,"node_count":node_order.size(),"vehicle_id":_vehicle_id,"life_generation":_life_generation}

## Call only after every physical detach covered by the lease succeeded.
func commit_detach_success(vehicle_id_value: Variant,life_generation_value: Variant,lease_token_value: Variant) -> Dictionary:
	var lease_result:=_open_lease(vehicle_id_value,life_generation_value,lease_token_value)
	if not lease_result.ok: return lease_result
	var token: String=lease_token_value; var lease: Dictionary=lease_result.lease
	for node_record: Dictionary in lease.nodes:
		var live:=_live_record(node_record)
		if not live.ok: return live
		var claim: Dictionary=_claims.get(node_record.node_id,{})
		if claim.get("token")!=token or claim.get("state")!="RESERVED": return _error("stale_lease")
	for node_record: Dictionary in lease.nodes: _claims[node_record.node_id].state="COMMITTED"
	lease.state="COMMITTED"; _leases.erase(token)
	return {"ok":true,"lease_token":token,"channel":lease.channel,"node_count":lease.nodes.size(),"state":"COMMITTED"}

## Call after detach failure; it releases the complete atomic subset.
func rollback_detach_failure(vehicle_id_value: Variant,life_generation_value: Variant,lease_token_value: Variant) -> Dictionary:
	var lease_result:=_open_lease(vehicle_id_value,life_generation_value,lease_token_value)
	if not lease_result.ok: return lease_result
	var token: String=lease_token_value; var lease: Dictionary=lease_result.lease
	for node_record: Dictionary in lease.nodes:
		var live:=_live_record(node_record)
		if not live.ok: return live
		var claim: Dictionary=_claims.get(node_record.node_id,{})
		if claim.get("token")!=token or claim.get("state")!="RESERVED": return _error("stale_lease")
	for node_record: Dictionary in lease.nodes: _claims.erase(node_record.node_id)
	_leases.erase(token)
	return {"ok":true,"lease_token":token,"channel":lease.channel,"node_count":lease.nodes.size(),"state":"ROLLED_BACK"}

func owner(vehicle_id_value: Variant,life_generation_value: Variant,alias_value: Variant) -> Dictionary:
	var boundary:=_boundary(vehicle_id_value,life_generation_value)
	if not boundary.ok: return boundary
	if not alias_value is String or not _bindings.has(alias_value): return _error("alias")
	var binding: Dictionary=_bindings[alias_value]
	if binding.missing: return {"ok":true,"state":"MISSING","channel":null,"lease_token":null}
	var live:=_live_binding(binding,false)
	if not live.ok: return live
	var claim: Dictionary=_claims.get(binding.node_id,{})
	var state: String=claim.get("state","AVAILABLE")
	var root: Node3D=_root_ref.get_ref()
	if state!="COMMITTED" and not root.is_ancestor_of(live.node): return _error("node_outside_vehicle")
	return {"ok":true,"state":state,"channel":claim.get("channel"),"lease_token":claim.get("token")}

func reset(vehicle_id_value: Variant,life_generation_value: Variant) -> Dictionary:
	var boundary:=_boundary(vehicle_id_value,life_generation_value)
	if not boundary.ok: return boundary
	_claims.clear(); _leases.clear(); _epoch+=1
	return {"ok":true,"epoch":_epoch}

func stats(vehicle_id_value: Variant,life_generation_value: Variant) -> Dictionary:
	var boundary:=_boundary(vehicle_id_value,life_generation_value)
	if not boundary.ok: return boundary
	var reserved:=0; var committed:=0
	for claim: Dictionary in _claims.values():
		if claim.state=="RESERVED": reserved+=1
		elif claim.state=="COMMITTED": committed+=1
	return {"ok":true,"reserved_nodes":reserved,"committed_nodes":committed,"open_leases":_leases.size(),"epoch":_epoch}

func dispose() -> void:
	if _disposed: return
	_claims.clear(); _leases.clear(); _bindings.clear(); _root_ref=null; _disposed=true

func _boundary(vehicle_id_value: Variant,life_generation_value: Variant) -> Dictionary:
	if not _configured or _disposed: return _error("lifetime")
	if vehicle_id_value!=_vehicle_id or life_generation_value!=_life_generation: return _error("identity")
	if _root_ref==null or not is_instance_valid(_root_ref.get_ref()) or not _root_ref.get_ref() is Node3D: return _error("deleted_root")
	var root: Node3D=_root_ref.get_ref()
	if not root.is_inside_tree(): return _error("root_outside_tree")
	if not root.has_meta(META_VEHICLE_ID) or not root.has_meta(META_LIFE_GENERATION) or root.get_meta(META_VEHICLE_ID)!=_vehicle_id or root.get_meta(META_LIFE_GENERATION)!=_life_generation: return _error("stale_incarnation")
	return {"ok":true}

func _open_lease(vehicle_id_value: Variant,life_generation_value: Variant,token_value: Variant) -> Dictionary:
	var boundary:=_boundary(vehicle_id_value,life_generation_value)
	if not boundary.ok: return boundary
	if not token_value is String or not _leases.has(token_value): return _error("stale_lease")
	var lease: Dictionary=_leases[token_value]
	if lease.get("state")!="RESERVED" or lease.get("epoch")!=_epoch: return _error("stale_lease")
	return {"ok":true,"lease":lease}

func _live_binding(binding: Dictionary,require_vehicle_parent: bool) -> Dictionary:
	var live:=_live_record(binding)
	if not live.ok: return live
	var root: Node3D=_root_ref.get_ref()
	if require_vehicle_parent and not root.is_ancestor_of(live.node): return _error("node_outside_vehicle")
	return live

static func _live_record(record: Dictionary) -> Dictionary:
	var node_ref: Variant=record.get("node_ref")
	if not node_ref is WeakRef: return _error("deleted_node")
	var node: Variant=(node_ref as WeakRef).get_ref()
	if not node is Node3D or not is_instance_valid(node) or node.get_instance_id()!=record.get("node_id"): return _error("deleted_node")
	return {"ok":true,"node":node}

func _missing_count() -> int:
	var count:=0
	for binding: Dictionary in _bindings.values():
		if binding.missing: count+=1
	return count

static func _error(code: String) -> Dictionary: return {"ok":false,"error":code}
