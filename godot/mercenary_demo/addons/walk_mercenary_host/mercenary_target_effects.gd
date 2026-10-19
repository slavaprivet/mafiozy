extends RefCounted
## Source mercenary_targets.mjs:105-134 receipt bridge; physical callbacks own effects.
const EFFECTS := {"plant_bomb":"blast","explode":"blast","explosion":"blast","vehicle_blast":"blast","breach_door":"breach","unlock_safe":"unlock","unlock_door":"unlock","unlock":"unlock","cut_fence":"cut","cut":"cut","disable_power":"disablePower","intimidate":"intimidate"}
var _get_target: Callable
var _callbacks: Dictionary
var _pending_factory: Callable
var _requests: Dictionary = {}
var _done: Dictionary = {}
var _pending: Dictionary = {}
var _disposed := false

func _init(get_target: Callable, callbacks: Dictionary = {}, pending_factory: Callable = Callable()) -> void:
	_get_target = get_target
	_callbacks = callbacks.duplicate()
	_pending_factory = pending_factory

func _failure(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}

func _target(id: Variant) -> Variant:
	return _get_target.call(id) if not _disposed and _get_target.is_valid() else null

func perform_effect(effect: Dictionary) -> Variant:
	if _disposed: return _failure("disposed")
	var raw_key: Variant = effect.get("actionId",effect.get("id",effect.get("effectId")))
	var key := "" if raw_key == null else str(raw_key)
	var action := str(effect.get("kind",effect.get("type","")))
	var signature := action+"@"+str(effect.get("targetId"))
	if key != "" and _requests.has(key) and _requests[key] != signature: return _failure("request_conflict")
	if key != "" and _done.has(key): return {"ok":true,"duplicate":true}
	if key != "" and _pending.has(key): return _pending[key]
	var target: Variant = _target(effect.get("targetId"))
	if not target is Dictionary or target.get("valid",true) != true: return _failure("target_unavailable")
	var kind: String = EFFECTS.get(action,"")
	var callback_name := ""
	if kind == "blast" and target.kind == "vehicle": callback_name = "onVehicleBlast"
	elif kind == "blast" and target.kind == "door":
		if target.get("opened",false) or not target.get("locked",false) or target.get("bombable") != true: return _failure("door_not_bombable")
		callback_name = "onDoorBlast"
	elif kind == "breach" and target.kind == "door":
		if target.get("opened",false) or not target.get("locked",false) or target.get("breachable") != true: return _failure("door_not_breachable")
		callback_name = "onDoorBreach"
	elif kind == "unlock" and target.kind in ["safe","door","vehicle"]:
		if target.get("opened",false) or not target.get("locked",false): return _failure("not_locked")
		callback_name = "onUnlock"
	elif kind == "cut" and target.kind == "fence":
		if target.get("cut",false): return _failure("already_cut")
		callback_name = "onFenceCut"
	elif kind == "disablePower" and target.kind == "power_panel":
		if target.get("powered") != true or target.get("disabled",false): return _failure("power_already_off")
		callback_name = "onDisablePower"
	elif kind == "intimidate" and target.kind == "npc": callback_name = "onIntimidate"
	var callback: Callable = _callbacks.get(callback_name,Callable())
	if not callback.is_valid(): return _failure("effect_not_connected")
	if key != "": _requests[key] = signature
	var result: Variant = callback.call(target,effect)
	if result is Object and result.has_method("subscribe"):
		if not _pending_factory.is_valid(): return _failure("pending_not_connected")
		var receipt: RefCounted = _pending_factory.call()
		if receipt == null or not receipt.has_method("settle"): return _failure("pending_not_connected")
		if key != "": _pending[key] = receipt
		# A Promise-equivalent authority confirms before any presentation flags change.
		result.subscribe(func(value):
			var confirmed := _confirmed(value,target,kind,key)
			if key != "": _pending.erase(key)
			receipt.settle(confirmed))
		return receipt
	return _confirmed(result,target,kind,key)

func _confirmed(result: Variant, target: Dictionary, kind: String, key: String) -> Dictionary:
	var accepted: bool = result is bool and result
	if result is Dictionary: accepted = result.get("ok") is bool and result.ok
	if not accepted:
		return _failure(str(result.get("reason","effect_rejected")) if result is Dictionary else "effect_rejected")
	var live: Variant = _target(target.id)
	var original_object: Variant = target.get("object")
	var same: bool = live is Dictionary and live.get("valid",true) == true and is_instance_valid(original_object) and live.get("object") == original_object
	if same:
		if kind in ["unlock","breach"] or (kind == "blast" and target.kind == "door"):
			original_object.set_meta("locked",false)
			original_object.set_meta("mercenaryOpened",true)
		if kind == "cut": original_object.set_meta("mercenaryCut",true)
		if kind == "disablePower":
			original_object.set_meta("mercenaryPowered",false)
			original_object.set_meta("mercenaryDisabled",true)
	if key != "" and not _disposed: _done[key] = true
	var receipt := {"ok":true,"targetId":target.id}
	if not same: receipt.presentationUnavailable = true
	return receipt

func stats() -> Dictionary:
	return {"requests":_requests.size(),"confirmed":_done.size(),"pending":_pending.size(),"disposed":_disposed}

func dispose() -> void:
	_disposed = true
	_get_target = Callable()
	_pending_factory = Callable()
	_callbacks.clear()
	_requests.clear()
	_done.clear()
	_pending.clear()
