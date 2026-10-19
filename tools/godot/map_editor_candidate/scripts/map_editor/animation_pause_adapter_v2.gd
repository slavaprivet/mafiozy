extends "res://scripts/map_editor/animation_pause_adapter.gd"
## Compound-only fork; no play/stop/seek/advance and no clock/resource rewriting.
var _issued: RefCounted
var _applied := false
func prepare_pause() -> Dictionary:
	var result := pause()
	if not _capsules.is_empty() and _issued == null: _issued = RefCounted.new()
	if _issued != null: result.capsule = _issued
	return result
func _owns(handle: Variant) -> bool:
	return Thread.is_main_thread() and handle != null and handle == _issued and not _capsules.is_empty()
func hold(handle: Variant) -> Dictionary:
	if not _owns(handle) or _busy: return failure("Foreign/reentrant animation capsule")
	for saved: Dictionary in _capsules:
		if _live(saved.spec): saved.spec.mixer.get_ref().active = false
	_applied = false
	return {"ok": verify()}
func preflight_restore(handle: Variant) -> Dictionary:
	if not _owns(handle) or _busy or _applied or not verify(): return failure("Animation phase/resource/pose/parent/lifetime changed; owner reconciliation required")
	return {"ok": true}
func apply_restore(handle: Variant) -> Dictionary:
	if not preflight_restore(handle).ok: return failure("Animation final preflight refused")
	_busy = true
	for saved: Dictionary in _capsules: saved.spec.mixer.get_ref().active = saved.active
	_busy = false
	_applied = true
	return {"ok": postflight_restore(handle)}
func postflight_restore(handle: Variant) -> bool:
	if not _owns(handle) or _busy or not _applied or _dirty: return false
	for saved: Dictionary in _capsules:
		if not _live(saved.spec): return false
		var mixer: AnimationMixer = saved.spec.mixer.get_ref()
		if mixer.active != saved.active or _state(mixer) != saved.state: return false
		for pose: Dictionary in saved.poses:
			for property: String in pose.values:
				if pose.target.node.get_ref().get(property) != pose.values[property]: return false
	return true
func finish_restore(handle: Variant) -> void:
	assert(postflight_restore(handle))
	_disconnect_resources()
	_capsules.clear()
	_fault = false
	_issued = null
	_applied = false
