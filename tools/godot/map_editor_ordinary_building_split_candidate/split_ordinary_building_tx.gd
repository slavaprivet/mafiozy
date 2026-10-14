extends "res://scripts/map_editor/ordinary_building_tx.gd"
## Tools-only two-phase ordinary-building transaction. The root workspace owns
## population/vehicle pause and must keep SceneTree paused until swap succeeds.
const Geometry = preload("res://scripts/map_editor/nav_geometry_receipt.gd")
const Shadow = preload("res://scripts/map_editor/shadow_navigation_owner.gd")

var _split_phase := "IDLE"
var _split_action := ""
var _split_value: Variant
var _split_population: RefCounted
var _split_population_receipt: Dictionary = {}
var _split_shadow: RefCounted
var _split_ticket := -1
var _split_before: Dictionary = {}
var _split_tokens: Array[Dictionary] = []
var _split_staged_fingerprint: Array = []

func begin_split(action: String, value: Variant, population_receipt: Dictionary) -> Dictionary:
	if _split_phase != "IDLE" or _state != "SELECTED_READONLY" or action not in ["move", "delete"]:
		return _split_no("unsupported-or-busy")
	if not is_instance_valid(_main) or not _main.is_inside_tree() or not _main.get_tree().paused or Engine.is_in_physics_frame():
		return _split_no("paused-main-required")
	if _deleted or not _participants_valid() or _capture_fingerprint() != _fingerprint:
		return _split_no("building-owner-drift")
	if action == "move" and (not value is Vector3 or not value.is_finite() or value.length_squared() < 0.00000001):
		return _split_no("invalid-move")
	if not population_receipt.get("population_id") is int:
		return _split_no("population-receipt-required")
	var population: RefCounted = _main.get("preview_population")
	if population == null or not population.has_method("verify_editor_pause") or not population.verify_editor_pause(population_receipt):
		return _split_no("population-pause-not-current")
	var geometry := Geometry.new()
	var proposal: Dictionary = geometry.inspect(_main, str(_source.id), action, value)
	if not proposal.get("ok", false) or not proposal.get("read_only", false):
		return _split_no("navigation-geometry-refused:" + str(proposal.get("error", "")))
	var shadow := Shadow.new()
	var opened: Dictionary = shadow.begin(_main, proposal, population_receipt)
	if not opened.get("ok", false) or not opened.get("ticket") is int:
		return _split_no("navigation-shadow-refused:" + str(opened.get("error", "")))
	_split_phase = "BAKING"
	_split_action = action
	_split_value = value
	_split_population = population
	_split_population_receipt = population_receipt.duplicate(true)
	_split_shadow = shadow
	_split_ticket = int(opened.ticket)
	_state = "SPLIT_PENDING"
	return {"ok": true, "phase": _split_phase, "map_ready": false, "source_id": _source.id}

func poll_split_ready() -> Dictionary:
	if _split_phase not in ["BAKING", "READY"] or not _split_owner_current():
		return _split_hold("population-or-building-drift-during-bake")
	var result: Dictionary = _split_shadow.poll_ready(_split_ticket)
	if not result.get("ok", false):
		return _split_hold("navigation-bake-refused:" + str(result.get("error", "")))
	if result.get("map_ready", false):
		_split_phase = "READY"
	return {"ok": true, "phase": _split_phase, "map_ready": _split_phase == "READY"}

func commit_split_scene(leases: Dictionary) -> Dictionary:
	if _split_phase != "READY" or not _split_owner_current():
		return _split_no("shadow-or-population-not-ready")
	var before: Dictionary = _capture_state()
	var tokens: Array[Dictionary] = []
	for domain: String in ["pause", "terrain", "traffic"]:
		if not leases.has(domain) or not leases[domain] is Callable or not leases[domain].is_valid():
			return _rollback_prepared(tokens, "missing-owner-lease:" + domain)
		var answer: Variant = leases[domain].call({"source_id": _source.id, "action": _split_action,
			"old_frame": _row.visual.global_transform, "body_count": _row.native_sibling_bodies.size(),
			"owner_instance_id": _main.get_instance_id()})
		if not answer is Dictionary or not answer.get("ok", false) or not answer.get("token") is RefCounted:
			return _rollback_prepared(tokens, "owner-lease-refused:" + domain)
		var token: RefCounted = answer.token
		if not token.has_method("verify") or not token.has_method("commit") or not token.has_method("rollback"):
			return _rollback_prepared(tokens, "invalid-owner-token:" + domain)
		tokens.append({"domain": domain, "token": token})
	for entry: Dictionary in tokens:
		if not _token_ok(entry.token.verify()): return _rollback_prepared(tokens, "owner-lease-drift:" + entry.domain)
	if not _split_owner_current(): return _rollback_prepared(tokens, "building-drift-before-scene-mutation")
	var changed: Dictionary = _mutate(_split_action, _split_value)
	if not changed.get("ok", false): return _rollback_after_mutation(before, tokens, str(changed.get("error", "mutation-refused")))
	if not _participants_valid(): return _rollback_after_mutation(before, tokens, "participant-drift-after-scene-mutation")
	var staged: Array = _capture_fingerprint()
	for entry: Dictionary in tokens:
		if not _token_ok(entry.token.verify()): return _rollback_after_mutation(before, tokens, "owner-lease-drift-after-mutation:" + entry.domain)
	for entry: Dictionary in tokens:
		if not _token_ok(entry.token.commit({"source_id": _source.id, "action": _split_action,
			"new_frame": _row.visual.global_transform, "deleted": _split_action == "delete"})):
			return _rollback_after_mutation(before, tokens, "owner-commit-refused:" + entry.domain)
	if not _main.get_tree().paused or _capture_fingerprint() != staged:
		return _rollback_after_mutation(before, tokens, "pause-or-scene-drift-after-owner-commit")
	_split_before = before
	_split_tokens = tokens
	_split_staged_fingerprint = staged
	_split_phase = "SCENE_COMMITTED"
	return {"ok": true, "phase": _split_phase, "navigation_swap_committed": false,
		"population_release_required": true}

## Root must atomically release population/nav, flush held callbacks, then
## re-pause in the same call stack. This method never releases that owner itself.
func publish_split_after_population_release() -> Dictionary:
	if _split_phase != "SCENE_COMMITTED" or not is_instance_valid(_main) or not _main.get_tree().paused:
		return _split_no("scene-not-ready-for-navigation-swap")
	if _split_population._editor_pause_active:
		return _split_no("population-release-required")
	if _capture_fingerprint() != _split_staged_fingerprint:
		return _split_hold("scene-drift-before-navigation-swap")
	var swapped: Dictionary = _split_shadow.commit_after_released_pause(_split_ticket)
	if not swapped.get("ok", false) or not swapped.get("navigation_swap_committed", false):
		return _split_hold("navigation-swap-refused:" + str(swapped.get("error", "")))
	_split_phase = "SWAPPED"
	return {"ok": true, "phase": _split_phase, "navigation_swap_committed": true}

func finish_split_after_resume() -> Dictionary:
	if _split_phase != "SWAPPED" or not is_instance_valid(_main) or _main.get_tree().paused:
		return _split_no("resume-required")
	var finished: Dictionary = _split_shadow.finalize(_split_ticket)
	if not finished.get("ok", false): return _split_hold("navigation-finalize-refused:" + str(finished.get("error", "")))
	for entry: Dictionary in _split_tokens:
		if entry.token.has_method("finalize") and not _token_ok(entry.token.finalize()):
			return _split_hold("owner-finalize-refused:" + entry.domain)
	_history.append({"action": _split_action, "before": _split_before})
	_redo.clear()
	_deleted = _split_action == "delete"
	_fingerprint = _capture_fingerprint()
	_state = "SELECTED_READONLY"
	_split_phase = "IDLE"
	_split_tokens.clear()
	_split_before.clear()
	_split_staged_fingerprint.clear()
	_split_population_receipt.clear()
	_split_population = null
	_split_shadow = null
	_split_ticket = -1
	return {"ok": true, "phase": "COMMITTED", "source_id": _source.id, "history": _history.size()}

func abort_split_before_scene_commit() -> Dictionary:
	if _split_phase not in ["BAKING", "READY"] or not _split_owner_current():
		return _split_no("abort-not-available")
	var aborted: Dictionary = _split_shadow.abort(_split_ticket)
	if not aborted.get("ok", false): return _split_hold("shadow-abort-refused")
	_split_phase = "IDLE"
	_state = "SELECTED_READONLY"
	_split_population_receipt.clear()
	return {"ok": true, "phase": "ABORTED"}

func _split_owner_current() -> bool:
	if not is_instance_valid(_main) or not _main.is_inside_tree() or not _main.get_tree().paused:
		return false
	if _split_population == null or _split_population != _main.get("preview_population"):
		return false
	return _split_population.verify_editor_pause(_split_population_receipt) and _participants_valid() and _capture_fingerprint() == _fingerprint

func _split_no(reason: String) -> Dictionary:
	return {"ok": false, "phase": _split_phase, "error": reason}

func _split_hold(reason: String) -> Dictionary:
	_split_phase = "HOLD"
	_state = "HOLD_SPLIT_OWNER"
	return _split_no(reason)
