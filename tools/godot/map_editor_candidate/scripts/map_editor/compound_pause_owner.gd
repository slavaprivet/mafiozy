extends RefCounted
## Trusted explicit owner inventory only. Final restore is synchronous, no awaits
## or owner Callables between all-owner preflight and all-owner postflight.
var _scene: RefCounted
var _animation: RefCounted
var _external: Callable
var _request := {}
var _receipt := {}
var _scene_handle: RefCounted
var _animation_handle: RefCounted
var _scene_receipt := {}
var _busy := false
var _fault := false
var _sequence := 0
static func failure(message: String) -> Dictionary: return {"ok": false, "error": message}
static func accepted(value: Variant) -> bool: return (value is bool and value) or (value is Dictionary and value.get("ok", false) == true)
func configure(scene: RefCounted, animation: RefCounted, external_inventory_gate: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _scene != null or not is_instance_valid(scene) or not is_instance_valid(animation) or not external_inventory_gate.is_valid(): return failure("Explicit scene, animation and mandatory NPC/nav/other-owner gate required")
	for child in [scene, animation]:
		for method in ["prepare_pause", "hold", "preflight_restore", "apply_restore", "postflight_restore", "finish_restore"]:
			if not child.has_method(method): return failure("Missing issued-capsule child contract: " + method)
	_scene = scene
	_animation = animation
	_external = external_inventory_gate
	return {"ok": true}
func _gate(phase: String, details: Dictionary) -> bool:
	return accepted(_external.call(phase, details.duplicate(true)))
func pause_gameplay(request: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _scene == null or _busy or not _request.is_empty(): return failure("Compound owner busy or retained repair required")
	_busy = true
	if not _gate("pause", {"request": request}):
		_busy = false
		return failure("Mandatory external NPC/nav/source inventory admission refused")
	var scene_result: Dictionary = _scene.prepare_pause(request)
	if not scene_result.has("capsule"):
		_busy = false
		return scene_result
	_request = request.duplicate(true)
	_scene_handle = scene_result.capsule
	_scene_receipt = scene_result.receipt
	_scene.hold(_scene_handle) # Finish holding explicit inventory after partial pause.
	var animation_result: Dictionary = _animation.prepare_pause()
	if animation_result.has("capsule"): _animation_handle = animation_result.capsule
	_sequence += 1
	_receipt = {"owner_id": request.owner_id, "request_id": request.request_id, "token": "%s:%s" % [get_instance_id(), _sequence]}
	_busy = false
	if not scene_result.ok or not animation_result.ok:
		_fault = true
		var cleanup := cancel_pause(request)
		return {"ok": false, "error": "Partial pause refused", "retained": not cleanup.ok, "cleanup": cleanup}
	if not verify_pause(_receipt):
		_fault = true
		return failure("Compound pause did not hold; owner repair required")
	return {"ok": true, "receipt": _receipt.duplicate(true)}
func _matching(receipt: Dictionary) -> bool: return not _receipt.is_empty() and receipt == _receipt
func verify_pause(receipt: Dictionary) -> bool:
	return Thread.is_main_thread() and not _busy and _matching(receipt) and _scene_handle != null and _animation_handle != null and _scene.preflight_restore(_scene_handle).ok and _animation.preflight_restore(_animation_handle).ok
func transaction_ready(receipt: Dictionary) -> bool:
	if _fault or not verify_pause(receipt): return false
	_busy = true
	var ready: bool = _scene.transaction_ready(_scene_receipt) and _gate("ready", {"receipt": receipt})
	_busy = false
	var still_held := verify_pause(receipt)
	if not still_held: _hold_all()
	return ready and still_held
func ground_patch() -> Variant:
	if not Thread.is_main_thread() or _busy or _scene == null: return null
	_busy = true
	var result: Variant = _scene.ground_patch()
	_busy = false
	return result
func _hold_all() -> void:
	if _scene_handle != null: _scene.hold(_scene_handle)
	if _animation_handle != null: _animation.hold(_animation_handle)
	_fault = true
func _restore_all() -> Dictionary:
	# All read-only prerequisites FIRST. No child restored on second-owner refusal.
	if _scene_handle == null or not _scene.preflight_restore(_scene_handle).ok:
		_hold_all()
		return failure("Scene owner final restoration preflight refused; all owned participants held")
	if _animation_handle != null and not _animation.preflight_restore(_animation_handle).ok:
		_hold_all()
		return failure("Animation owner final restoration preflight refused; all owned participants held")
	var scene_result: Dictionary = _scene.apply_restore(_scene_handle)
	var animation_result: Dictionary = {"ok": true}
	if scene_result.ok and _animation_handle != null: animation_result = _animation.apply_restore(_animation_handle)
	if not scene_result.ok or not animation_result.ok or not _scene.postflight_restore(_scene_handle) or (_animation_handle != null and not _animation.postflight_restore(_animation_handle)):
		_hold_all()
		return failure("Final restoration postflight refused; retained joint repair capsule")
	_scene.finish_restore(_scene_handle)
	if _animation_handle != null: _animation.finish_restore(_animation_handle)
	var result := {"ok": true, "owner_id": _receipt.owner_id, "request_id": _receipt.request_id}
	_request.clear()
	_receipt.clear()
	_scene_receipt.clear()
	_scene_handle = null
	_animation_handle = null
	_fault = false
	return result
func cancel_pause(request: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy: return failure("Reentrant/off-thread joint cancellation refused")
	if _request.is_empty(): return {"ok": true, "unchanged": true}
	if request != _request: return failure("Foreign cancellation refused")
	_busy = true
	if not _gate("cancel", {"request": request, "receipt": _receipt}):
		_hold_all()
		_busy = false
		return failure("Owner-authorized cancellation admission refused")
	var result := _restore_all()
	_busy = false
	return result
func resume_gameplay(receipt: Dictionary, objects: Dictionary, ground: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or not transaction_ready(receipt): return failure("Joint freeze barrier/external owner admission not ready")
	_busy = true
	if not _gate("resume", {"receipt": receipt, "objects": objects, "ground": ground}) or not _scene.admit_resume(_scene_handle, objects, ground).ok:
		_hold_all()
		_busy = false
		return failure("Real source support/nav/water/authority admission refused")
	var result := _restore_all()
	_busy = false
	return result
func callbacks() -> Dictionary:
	return {"pause_gameplay": pause_gameplay, "cancel_pause": cancel_pause, "verify_pause": verify_pause, "resume_gameplay": resume_gameplay, "transaction_ready": transaction_ready, "ground_patch": ground_patch}
func state() -> Dictionary: return {"leased": not _request.is_empty(), "fault": _fault, "busy": _busy, "production_wired": false}
