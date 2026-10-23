extends RefCounted
## Presentation only. The caller supplies current admitted source frames; no reports,
## life writes, clock advancement, movement or police dispatch are performed here.

var _identity: Dictionary = {}
var _guard: Callable
var _busy := false
var _last_frame := -1
var _last_clock := -1.0
var _last_payload: Dictionary = {}
var _phase := "idle"
var _phase_time := 0.0
var _active := false
var _entry := 0.0
var _raise := 0.0
var _stow_entry := 1.0
var _stow_raise := 1.0
var _shown := false
var _wave := 0.0

func bind(identity: Dictionary, admission_guard: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _busy or not _identity.is_empty():
		return _error("ALREADY_BOUND_OR_BUSY")
	for key in ["session_id", "actor_id", "bridge_id", "source_receipt_sha256"]:
		if not identity.get(key) is String or identity[key].is_empty():
			return _error("INVALID_IDENTITY")
	var actor: String = identity.actor_id
	var suffix := actor.trim_prefix("resident_")
	if not actor.begins_with("resident_") or not suffix.is_valid_int() or str(int(suffix)) != suffix or int(suffix) < 0:
		return _error("INVALID_ACTOR_ID")
	if identity.bridge_id != "npc_" + actor:
		return _error("INVALID_BRIDGE_ID")
	var sha: String = identity.source_receipt_sha256
	if sha.length() != 64:
		return _error("INVALID_RECEIPT")
	for character in sha:
		if not character in "0123456789abcdef":
			return _error("INVALID_RECEIPT")
	if sha == "384f1f2d2b673bde13a49cfdff2f88b4e84469801b1f572624c53259a472901d":
		return _error("REJECTED_SOURCE_RECEIPT")
	if not identity.get("life_generation") is int or identity.life_generation < 1 or not admission_guard.is_valid():
		return _error("INVALID_GENERATION_OR_GUARD")
	_identity = identity.duplicate(true)
	_guard = admission_guard
	return {"ok": true}

func update(frame: Dictionary, delta: float, render_time: float) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _identity.is_empty():
		return _error("UNBOUND_OR_REENTRY")
	_busy = true
	var result := _update(frame, delta, render_time)
	if not result.ok:
		_reset()
	_busy = false
	return result

func _update(frame: Dictionary, delta: float, render_time: float) -> Dictionary:
	for key in ["session_id", "actor_id", "bridge_id", "life_generation", "source_receipt_sha256"]:
		if typeof(frame.get(key)) != typeof(_identity[key]) or frame[key] != _identity[key]:
			_reset()
			return _error("IDENTITY_MISMATCH")
	if not frame.get("event_id") is String or frame.event_id.is_empty() or not frame.get("source_frame") is int or frame.source_frame < 0:
		return _error("INVALID_EVENT_FRAME")
	if not _number(frame.get("source_now_ms")) or frame.source_now_ms < 0 or not frame.get("raw") is Dictionary:
		return _error("INVALID_SOURCE_CLOCK_OR_RAW")
	var raw: Dictionary = frame.raw
	if not raw.get("id") is String or raw.id != _identity.actor_id or not raw.get("_npcInitialPlacementPending") is bool or raw._npcInitialPlacementPending:
		_reset()
		return _error("SOURCE_NOT_ADMITTED")
	for key in ["visible", "phone_blocked"]:
		if not frame.get(key) is bool:
			return _error("INVALID_PRESENTATION_PRIORITY")
	for key in ["dead", "snitching"]:
		if raw.has(key) and not raw[key] is bool:
			return _error("INVALID_SOURCE_BOOLEAN")
	if raw.has("_witnessStage") and not raw._witnessStage is String:
		return _error("INVALID_WITNESS_STAGE")
	if raw.has("_witnessCallUntil") and (not _number(raw._witnessCallUntil) or raw._witnessCallUntil < 0):
		return _error("INVALID_CALL_DEADLINE")
	if raw.has("_corpsePhoneCall") and raw._corpsePhoneCall != null:
		if not raw._corpsePhoneCall is Dictionary or not _number(raw._corpsePhoneCall.get("until")) or raw._corpsePhoneCall.until < 0:
			return _error("INVALID_EMS_DEADLINE")
	var current: Variant = _guard.call(_identity.duplicate(true), frame.duplicate(true))
	if not current is bool or not current:
		_reset()
		return _error("CURRENT_ADMISSION_LOST")
	if frame.source_frame < _last_frame or float(frame.source_now_ms) < _last_clock:
		return _error("STALE_SOURCE_FRAME")
	if frame.source_frame == _last_frame:
		if frame != _last_payload:
			return _error("CONFLICTING_SOURCE_FRAME")
		return {"ok": true, "duplicate": true, "presentation": snapshot()}
	var now := float(frame.source_now_ms)
	var witness: bool = raw.get("snitching", false) and raw.get("_witnessStage", "") == "calling" and now < float(raw.get("_witnessCallUntil", 0.0))
	var corpse: bool = raw.get("_corpsePhoneCall") is Dictionary and now < float(raw._corpsePhoneCall.until)
	var wants: bool = not raw.get("dead", false) and (witness or corpse)
	var dt := clampf(delta, 0.0, 0.1) if is_finite(delta) else 0.0
	if not frame.visible or frame.phone_blocked or raw.get("dead", false):
		_reset()
	else:
		_advance(wants, dt)
		if _shown:
			_pose(render_time if is_finite(render_time) else _phase_time)
	current = _guard.call(_identity.duplicate(true), frame.duplicate(true))
	if not current is bool or not current:
		_reset()
		return _error("CURRENT_ADMISSION_LOST")
	_last_frame = frame.source_frame
	_last_clock = now
	_last_payload = frame.duplicate(true)
	return {"ok": true, "duplicate": false, "presentation": snapshot()}

func snapshot() -> Dictionary:
	var left_weight := _entry * _smooth(0.48, 0.92, _raise) * (1.0 - _smooth(0.04, 0.32, _phase_time) if _phase == "stow" else 1.0)
	return {"visible": _shown, "phase": _phase, "phase_time": _phase_time,
		"entry": _entry, "raise": _raise,
		"left_weight": left_weight,
		"chest_rotation_add": Vector3(0.025 * _entry, -0.045 * _entry, 0.012 * _wave * left_weight),
		"head_rotation_add": Vector3(-0.018 * _entry, -0.10 * _entry, 0.018 * _entry),
		"authority_written": false}

func _advance(wants: bool, dt: float) -> void:
	if wants:
		if not _active:
			_active = true
			_phase_time = 0.0
		_phase_time += dt
		_phase = "draw" if _phase_time < 0.28 else ("raise" if _phase_time < 0.78 else "hold")
		_shown = true
		return
	if _active:
		_active = false
		_stow_raise = _raise
		_stow_entry = _entry
		_phase = "stow"
		_phase_time = 0.0
	_phase_time += dt
	_shown = _phase == "stow" and _phase_time < 0.56
	if not _shown:
		_phase = "idle"
		_phase_time = 0.0

func _pose(time: float) -> void:
	_wave = sin(time * 3.6)
	_entry = _stow_entry * (1.0 - _smooth(0.38, 0.56, _phase_time)) if _phase == "stow" else _smooth(0.0, 0.2, _phase_time)
	match _phase:
		"draw": _raise = 0.0
		"raise": _raise = _smooth(0.28, 0.78, _phase_time)
		"hold": _raise = 1.0
		"stow": _raise = _stow_raise * (1.0 - _smooth(0.04, 0.46, _phase_time))

func _reset() -> void:
	_active = false
	_shown = false
	_phase = "idle"
	_phase_time = 0.0
	_entry = 0.0
	_raise = 0.0

static func _smooth(a: float, b: float, value: float) -> float:
	var t := clampf((value - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _error(code: String) -> Dictionary:
	return {"ok": false, "error": code}
