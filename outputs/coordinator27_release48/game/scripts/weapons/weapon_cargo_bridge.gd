extends RefCounted
## Local ownership transaction only. Host supplies actual aim/access evidence,
## exact scaled model bounds and a prepared renderer operation. No input/UI/HP.
const Inventory=preload("res://scripts/weapons/weapon_inventory.gd")
const Cargo=preload("res://scripts/transport/trunk/transport_trunk_cargo_store.gd")
const Sizes=preload("res://scripts/weapons/weapon_cargo_sizes.gd")
const OMITTED=Inventory.OMITTED
const CAPACITY:=Sizes.CAPACITY
## Latest user requirement: all14 together use100; larger model volume costs more.
const COSTS=Sizes.COSTS
var _inventory:RefCounted
var _cargo:RefCounted
var _generation:=0
var _vehicle_id:=""
var _evidence:Callable
var _prepare:Callable
var _cancel_placement:Callable
var _ready:=false
var _busy:=false
var _interrupted:=false

static func capacity_metadata()->Dictionary:
	return Sizes.metadata()
static func _error(reason:String)->Dictionary:return {"ok":false,"reason":reason}
static func _ok(value:Variant)->bool:return value is Dictionary and value.get("ok") is bool and value.ok

func configure(inventory:RefCounted,cargo:RefCounted,generation:int,evidence:Callable,prepare_placement:Callable,cancel_placement:Callable)->Dictionary:
	if not Thread.is_main_thread():return _error("lifetime")
	if _busy:_interrupted=true;return _error("reentry")
	if _ready:return _error("lifetime")
	# Commit behavior is owned by these reviewed concrete scripts, never arbitrary
	# callback ports or subclasses. External work ends before both commit calls.
	if inventory==null or cargo==null or inventory.get_script()!=Inventory or cargo.get_script()!=Cargo:return _error("components")
	if generation<1 or not evidence.is_valid() or evidence.get_argument_count()!=0 or not prepare_placement.is_valid() or prepare_placement.get_argument_count()!=1 or not cancel_placement.is_valid() or cancel_placement.get_argument_count()!=1:return _error("ports")
	var snapshot:Dictionary=cargo.snapshot(generation)
	if not _ok(snapshot) or snapshot.capacity_units!=CAPACITY:return _error("cargo_identity")
	_inventory=inventory;_cargo=cargo;_generation=generation;_vehicle_id=snapshot.vehicle_id
	_evidence=evidence;_prepare=prepare_placement;_cancel_placement=cancel_placement;_ready=true
	return {"ok":true}

func dispose()->void:
	if not Thread.is_main_thread():return
	_ready=false;_interrupted=true
	if not _busy:_clear_ports()
func _clear_ports()->void:
	_inventory=null;_cargo=null;_evidence=Callable();_prepare=Callable();_cancel_placement=Callable()
func _start()->bool:
	if not Thread.is_main_thread():return false
	if _busy:_interrupted=true;return false
	if not _ready:return false
	_busy=true;_interrupted=false;return true
func _live()->bool:return _ready and not _interrupted and _evidence.is_valid() and _prepare.is_valid() and _cancel_placement.is_valid()
func _finish(result:Dictionary)->Dictionary:
	_busy=false
	if not _ready:_clear_ports()
	return result
func _abort(reason:String,inventory_token:Variant=null,cargo_token:Variant=null,placement_token:Variant=null)->Dictionary:
	if cargo_token!=null:_cargo.cancel(cargo_token)
	if inventory_token!=null:_inventory.cancel_cargo_transfer(inventory_token)
	# Both data reservations are released before this externally owned cleanup.
	if placement_token is RefCounted and _cancel_placement.is_valid():_cancel_placement.call(placement_token)
	return _finish(_error(reason))
func _sample()->Dictionary:
	if not _live():return {}
	var result:Variant=_evidence.call()
	if not _live() or not result is Dictionary:return {}
	if not result.get("revision") is int or result.revision<1 or not result.get("sample") is Dictionary or not result.get("interaction_allowed") is bool or not result.get("target_open") is bool or not result.get("aimed_trunk") is bool or not result.get("aimed_item_uid") is String:return {}
	return result.duplicate(true)
static func _open(evidence:Dictionary)->bool:
	if evidence.is_empty() or not evidence.interaction_allowed or not evidence.target_open:return false
	var sample:Dictionary=evidence.sample
	var amount:Variant=sample.get("amount")
	return sample.get("available")==true and sample.get("has_floor")==true and (amount is float or amount is int) and is_finite(float(amount)) and float(amount)>=.85
func _aimed(evidence:Dictionary,action:String,uid:String="")->bool:
	if not _open(evidence):return false
	# Explicit near-open/modal selection is user intent, not a forged model ray.
	var mode:String=str(evidence.get("selection_mode","aim"))
	if mode=="trunk_window":
		if evidence.get("window_open")!=true or not evidence.get("window_epoch") is int or evidence.window_epoch<1:return false
		return action=="store" or (not uid.is_empty() and evidence.get("selected_item_uid")==uid)
	if mode=="near_open_trunk":return action=="store"
	return mode=="aim" and (evidence.aimed_trunk if action=="store" else not uid.is_empty() and evidence.aimed_item_uid==uid)
func _unchanged(before:Dictionary,action:String,uid:String="")->bool:
	var after:=_sample()
	return _aimed(after,action,uid) and after==before
func _placement(request:Dictionary)->Dictionary:
	if not _live():return {}
	var response:Variant=_prepare.call(request.duplicate(true))
	# Keep an issued token even on invalidation so abort can release its resources.
	return response if response is Dictionary else {}
static func _placement_ok(value:Dictionary)->bool:
	return _ok(value) and value.get("token") is RefCounted
static func _reason(value:Dictionary,fallback:String)->String:
	return str(value.get("reason",value.get("error",fallback)))

func actions()->Dictionary:
	if not _start():return _error("lifetime_or_reentry")
	var evidence:=_sample()
	var state:Dictionary=_cargo.snapshot(_generation)
	if not _live() or not _ok(state):return _finish(_error("lifetime"))
	var result:={"ok":true,"actions":[],"used_units":state.used_units,"capacity_units":CAPACITY,"selected_cost":0}
	if not _open(evidence) or state.destroyed or state.pending or _inventory.cargo_transfer_pending():return _finish(result)
	var held:Variant=_inventory.get_fire_state()
	if held is Dictionary and COSTS.has(held.get("weaponId")):
		result.selected_cost=COSTS[held.weaponId]
		if evidence.aimed_trunk:result.actions.append({"key":"G","label":"Погрузить","action":"store"})
	if not evidence.aimed_item_uid.is_empty():
		for entry:Dictionary in state.items:
			if entry.item.uid==evidence.aimed_item_uid and entry.item.kind=="weapon":result.actions.append({"key":"E","label":"Взять","action":"take","uid":entry.item.uid});break
	return _finish(result if _live() else _error("owner_changed"))

func store(model_aabb:AABB,current_state:Variant=OMITTED)->Dictionary:
	if not _start():return _error("lifetime_or_reentry")
	var evidence:=_sample()
	if not _aimed(evidence,"store"):return _abort("access")
	var snapshot:Dictionary=_cargo.snapshot(_generation)
	if not _ok(snapshot):return _abort(_reason(snapshot,"cargo"))
	var exported:Dictionary=_inventory.begin_cargo_export(current_state)
	if not _ok(exported):return _abort(_reason(exported,"inventory"))
	var it:Variant=exported.token
	if not _live() or not COSTS.has(exported.item.weaponId):return _abort("weapon_or_lifetime",it)
	var reserved:Dictionary=_cargo.prepare_store(exported.item,COSTS[exported.item.weaponId],model_aabb,evidence.revision,_generation,snapshot.revision)
	if not _ok(reserved):return _abort(_reason(reserved,"cargo"),it)
	var ct:Variant=reserved.token
	var placement:=_placement({"action":"store","vehicle_id":_vehicle_id,"generation":_generation,"entry":reserved.entry})
	var pt:Variant=placement.get("token")
	if not _live() or not _placement_ok(placement):return _abort("placement",it,ct,pt)
	if not _unchanged(evidence,"store"):return _abort("access_changed",it,ct,pt)
	var validated:Dictionary=_cargo.validate_pending(ct,"store",_generation,snapshot.revision,evidence.revision)
	if not _ok(validated) or not _live() or not _inventory.validate_cargo_transfer(it,"export"):return _abort("reservation_changed",it,ct,pt)
	# No external callbacks, signal emission or await between these two mutations.
	var stored:Dictionary=_cargo.commit_store(ct,validated.validation,_generation,snapshot.revision,evidence.revision)
	if not _ok(stored):return _abort(_reason(stored,"cargo_commit"),it,ct,pt)
	var removed:Dictionary=_inventory.commit_cargo_export(it)
	assert(_ok(removed),"Validated concrete inventory commit must not fail")
	return _finish({"ok":true,"action":"store","inventory":removed,"cargo":stored,"placement_token":pt})

func take(uid:String,current_state:Variant=OMITTED)->Dictionary:
	if not _start():return _error("lifetime_or_reentry")
	var evidence:=_sample()
	if not _aimed(evidence,"take",uid):return _abort("access")
	var snapshot:Dictionary=_cargo.snapshot(_generation)
	if not _ok(snapshot):return _abort(_reason(snapshot,"cargo"))
	var reserved:Dictionary=_cargo.prepare_take(uid,evidence.revision,_generation,snapshot.revision)
	if not _ok(reserved):return _abort(_reason(reserved,"cargo"))
	var ct:Variant=reserved.token
	var imported:Dictionary=_inventory.begin_cargo_import(reserved.entry.item,current_state)
	if not _ok(imported):return _abort(_reason(imported,"inventory"),null,ct)
	var it:Variant=imported.token
	var placement:=_placement({"action":"take","vehicle_id":_vehicle_id,"generation":_generation,"entry":reserved.entry})
	var pt:Variant=placement.get("token")
	if not _live() or not _placement_ok(placement):return _abort("placement",it,ct,pt)
	if not _unchanged(evidence,"take",uid):return _abort("access_changed",it,ct,pt)
	var validated:Dictionary=_cargo.validate_pending(ct,"take",_generation,snapshot.revision,evidence.revision)
	if not _ok(validated) or not _live() or not _inventory.validate_cargo_transfer(it,"import"):return _abort("reservation_changed",it,ct,pt)
	var removed:Dictionary=_cargo.commit_take(ct,validated.validation,_generation,snapshot.revision,evidence.revision)
	if not _ok(removed):return _abort(_reason(removed,"cargo_commit"),it,ct,pt)
	var accepted:Dictionary=_inventory.commit_cargo_import(it)
	assert(_ok(accepted),"Validated concrete inventory commit must not fail")
	return _finish({"ok":true,"action":"take","inventory":accepted,"cargo":removed,"placement_token":pt})

func destroy(event_uid:String,placements:Array)->Dictionary:
	if not _start():return _error("lifetime_or_reentry")
	if event_uid.is_empty() or event_uid.length()>256:return _abort("event_uid")
	# Ground admission invokes the inventory clock. Its callback must not replace
	# the transforms subsequently presented to the renderer's preflight.
	var ground_placements:Array=placements.duplicate(true)
	var snapshot:Dictionary=_cargo.snapshot(_generation)
	if not _ok(snapshot):return _abort(_reason(snapshot,"cargo"))
	var reserved:Dictionary=_cargo.prepare_destroy(event_uid,_generation,snapshot.revision)
	if not _ok(reserved):return _abort(_reason(reserved,"cargo"))
	if reserved.get("committed")==true:return _finish({"ok":true,"duplicate":true,"receipt":reserved.receipt})
	var ct:Variant=reserved.token
	var items:Array=[]
	for entry:Dictionary in reserved.items:items.append(entry.item.duplicate(true))
	var it:Variant=null
	var receipt:=JSON.stringify([_vehicle_id,_generation,event_uid])
	if not items.is_empty():
		var imported:Dictionary=_inventory.begin_cargo_ground_import_at_positions(items,ground_placements,receipt)
		if not _ok(imported):return _abort(_reason(imported,"ground"),null,ct)
		it=imported.token
	elif not ground_placements.is_empty():return _abort("placement_count",null,ct)
	var placement:=_placement({"action":"destroy","vehicle_id":_vehicle_id,"generation":_generation,"entries":reserved.items,"placements":ground_placements,"receipt":receipt})
	var pt:Variant=placement.get("token")
	if not _live() or not _placement_ok(placement):return _abort("placement",it,ct,pt)
	var validated:Dictionary=_cargo.validate_pending(ct,"destroy",_generation,snapshot.revision,-1)
	if not _ok(validated) or not _live() or (it!=null and not _inventory.validate_cargo_transfer(it,"ground")):return _abort("reservation_changed",it,ct,pt)
	# Ground batch has already reserved capacity and every renderer placement.
	var destroyed:Dictionary=_cargo.commit_destroy(ct,validated.validation,_generation,snapshot.revision)
	if not _ok(destroyed):return _abort(_reason(destroyed,"cargo_commit"),it,ct,pt)
	var released:Dictionary={"ok":true,"dropped":[]}
	if it!=null:released=_inventory.commit_cargo_ground_import(it)
	assert(_ok(released),"Validated concrete inventory ground commit must not fail")
	return _finish({"ok":true,"action":"destroy","duplicate":false,"cargo":destroyed,"inventory":released,"placement_token":pt})
