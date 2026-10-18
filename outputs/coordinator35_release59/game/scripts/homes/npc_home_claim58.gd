extends RefCounted
## Scene-local bed claims. Geometry assignments remain owned by HomeRegistry58.
const META := "npc_home_claims58"
var _scene: WeakRef

func configure(scene: Node3D) -> void:
	_scene = weakref(scene)
	if not scene.has_meta(META): scene.set_meta(META,{"serial":0,"claims":{}})

func _state() -> Dictionary:
	var scene: Variant = _scene.get_ref() if _scene != null else null
	return scene.get_meta(META,{}) if is_instance_valid(scene) else {}

func _key(slot: Dictionary) -> String:
	return str(slot.get("home_id",""))+":"+str(slot.get("bed_id",""))

func claim(slot: Dictionary, token: Dictionary, owner: RefCounted) -> Dictionary:
	var state: Dictionary = _state()
	if state.is_empty() or not is_instance_valid(owner) or not is_instance_valid(token.get("body")): return {}
	var key: String = _key(slot)
	var previous: Dictionary = state.claims.get(key,{})
	if not previous.is_empty():
		var previous_owner: Variant = previous.owner.get_ref()
		if is_instance_valid(previous_owner) and previous_owner.claim_alive58(int(previous.serial)): return {}
		state.claims.erase(key)
	state.serial = int(state.serial)+1
	var body: CharacterBody3D = token.body
	var lease: Dictionary = {"key":key,"serial":int(state.serial),"source_id":str(token.source_id),"session_id":str(token.get("session_id","")),"generation":int(token.get("life_generation",-1)),"body_id":body.get_instance_id()}
	state.claims[key] = {"serial":lease.serial,"owner":weakref(owner),"body":weakref(body),"lease":lease.duplicate()}
	return lease

func matches(lease: Dictionary, owner: RefCounted, body: CharacterBody3D) -> bool:
	if lease.is_empty() or not is_instance_valid(body): return false
	var state: Dictionary = _state()
	var row: Dictionary = state.get("claims",{}).get(str(lease.get("key","")),{})
	return not row.is_empty() and row.lease == lease and row.owner.get_ref() == owner and row.body.get_ref() == body and body.get_instance_id() == int(lease.body_id)

func release(lease: Dictionary, owner: RefCounted) -> void:
	var state: Dictionary = _state()
	var row: Dictionary = state.get("claims",{}).get(str(lease.get("key","")),{})
	if row.is_empty() or row.lease != lease or row.owner.get_ref() != owner: return
	state.claims.erase(str(lease.key))
