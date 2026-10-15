extends "res://scripts/hospital/npc_restaurant_visit28.gd"
## Reuse the physical door route with exactly one assigned home/bed admission.
## This adapter never registers a shop, service transaction, staff or payment.
class Portal:
	extends RefCounted
	var requests: Dictionary = {}
	var adapter: WeakRef
	func touch(_key: String, _now: int, _entered: bool = false) -> void: pass
	func portal_request(key: String, venue: String) -> bool:
		var owner: Variant = adapter.get_ref()
		return is_instance_valid(owner) and owner.portal_current(key,venue)
	func portal_release(_key: String, _venue: String) -> void: pass

class AssignedRegistry:
	extends RefCounted
	var ledger: RefCounted = Portal.new()
	var controller: WeakRef
	var route_owner: WeakRef
	var slot: Dictionary = {}
	var key := ""
	var venue := ""
	func configure(home: RefCounted, route: RefCounted, assigned: Dictionary, life_key: String) -> void:
		controller=weakref(home);route_owner=weakref(route);slot=assigned;key=life_key;venue=str(slot.home_id)
		ledger.adapter=weakref(self)
		ledger.requests[key]={"state":"reserved","venue":venue,"kind":"home"}
	func owns(id: String, owner: RefCounted) -> bool:
		var home: Variant=controller.get_ref()
		return id==key and route_owner.get_ref()==owner and is_instance_valid(home) and home.claim_current58()
	func refresh(_body: CharacterBody3D, _now: int) -> void: pass
	func entry(id: String) -> Dictionary:
		var home: Variant=controller.get_ref()
		if id!=venue or not is_instance_valid(home) or not home.route_geometry_current58(): return {}
		return {"owner":slot.door_owner,"clone":slot.house,"door":slot.door,"normal":slot.normal,"outside":slot.outside,"inner":slot.inner,"rooms":[slot.bed_approach]}
	func portal_current(id: String, site: String) -> bool:
		return id==key and site==venue and owns(id,route_owner.get_ref()) and not entry(site).is_empty()
	func reject_path(_key: String, _venue: String, _now: int, _owner: RefCounted) -> void: pass
	func staffed29(_venue: String) -> bool: return false
	func service_owner29(_key: String, _venue: String, _owner: RefCounted) -> bool: return false
	func release(id: String, _now: int, reason: String, owner: RefCounted) -> void:
		if id==key and route_owner.get_ref()==owner: ledger.requests.erase(id)
	func snapshot() -> Dictionary:
		return {"home_id":venue,"assigned_bed":slot.get("bed_id",""),"claims":ledger.requests.size(),"trading":false}

var _home58: WeakRef

func begin_home58(controller: RefCounted, slot: Dictionary, scene: Node3D, body: CharacterBody3D, map: RID, id: String) -> bool:
	if _registry!=null or not is_instance_valid(controller) or not is_instance_valid(body): return false
	_home58=weakref(controller);_body=body;_scene=scene;_map=map;_id=id;_kind="home";_sign_text="ДОМ"
	_key=id+":body:"+str(body.get_instance_id());_support=Route.new()
	if not _support.configure(body): return _fail("home_current_capsule_required58")
	_registry=AssignedRegistry.new();_registry.configure(controller,self,slot,_key)
	return _accept({"venue":str(slot.home_id),"slot":0})

func _start_leg() -> bool:
	if not super._start_leg(): return false
	# The assigned dock must be physically reached before any bed pose is offered.
	if _phase=="INBOUND" and _leg==_legs.size()-1:
		return _drive.set_service_arrival56(.025)
	return true

func needs_exit() -> bool:
	if _phase in ["OUTSIDE","CANCELLED"] or not is_instance_valid(_body): return false
	# A removed house cannot make a still-interior resident magically outside.
	return _entered or (depth_inside()>-.8 and _inside_envelope30())

func _emergency_allowed29() -> bool:
	var home: Variant=_home58.get_ref() if _home58!=null else null
	return is_instance_valid(home) and home.claim_current58() and not home.route_geometry_current58()
