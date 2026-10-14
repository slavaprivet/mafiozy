extends RefCounted
## Shadow-bake owner for a single actual-source building edit. Root still owns
## the global scene+population pause and ordinary building transaction.
const Geometry = preload("res://scripts/map_editor/nav_geometry_receipt.gd")
const Backend = preload("res://scripts/navigation/atomic_backend.gd")
var _geometry := Geometry.new()
var _main: WeakRef
var _population: RefCounted
var _navigation: RefCounted
var _old_backend: RefCounted
var _shadow: RefCounted
var _proposal: Dictionary = {}
var _paused_population_receipt: Dictionary = {}
var _old_version := -1
var _old_revision := -1
var _old_publications := -1
var _old_triangles := -1
var _phase := "NEW"
var _ticket := 0

func begin(main: Node3D, proposal: Dictionary, population_receipt: Dictionary = {}) -> Dictionary:
	if _phase != "NEW" or not Thread.is_main_thread() or not is_instance_valid(main): return _no("INVALID_PREPARE_LIFETIME")
	if not proposal.get("ok", false) or not proposal.get("read_only", false) or proposal.get("owner_lease", true): return _no("UNTRUSTED_GEOMETRY_PROPOSAL")
	var source_id: String = str(proposal.get("source_id", ""))
	var action: String = str(proposal.get("action", ""))
	var fresh: Dictionary = _geometry.inspect(main, source_id, action, proposal.get("requested_value"))
	if not fresh.get("ok", false) or fresh.old_geometry != proposal.old_geometry or fresh.proposed_geometry != proposal.proposed_geometry: return _no("SOURCE_GEOMETRY_CHANGED_BEFORE_BAKE")
	var population: RefCounted = main.get("preview_population")
	var nav: RefCounted = population.navigation
	if main.get_tree().paused:
		if population_receipt.is_empty() or not population.verify_editor_pause(population_receipt): return _no("PAUSED_TREE_REQUIRES_REAL_RESIDENT_LEASE")
	elif not population_receipt.is_empty(): return _no("UNPAUSED_TREE_CANNOT_USE_PAUSE_RECEIPT")
	var old: RefCounted = nav._backend
	if nav.state() != "READY" or old.state() != "READY" or nav._records.size() != 0 or old._jobs.size() != 0 or old._baking_token != 0 or not old._waiting.is_empty() or old._atomic_flush_pending or not old._held_completions.is_empty(): return _no("OLD_NAV_MAP_NOT_QUIESCENT_READY")
	if main.get_tree().paused and (not nav._editor_pause_active or not population._editor_pause_active): return _no("INCOMPLETE_PAUSED_OWNER_COHORT")
	if not main.get_tree().paused and (nav._editor_pause_active or population._editor_pause_active): return _no("OWNER_PAUSE_ALREADY_ACTIVE")
	var shadow: RefCounted = Backend.new(nav._queue, Callable(nav, "_space"))
	if not shadow.publish_source(fresh.proposed_geometry, nav._authority, nav._generation, nav._geometry_version + 1):
		shadow.dispose()
		return _no("SHADOW_BAKE_SUBMISSION_REFUSED")
	_main = weakref(main); _population = population; _navigation = nav
	_old_backend = old; _shadow = shadow; _proposal = fresh.duplicate(true)
	_paused_population_receipt = population_receipt.duplicate(true)
	_old_version = nav._geometry_version; _old_revision = nav._revision
	_old_publications = int(nav._stats.publications); _old_triangles = int(nav._stats.triangles)
	_ticket += 1; _phase = "BAKING"
	return {"ok": true, "ticket": _ticket, "phase": _phase, "owner_lease": false, "map_ready": false}

func poll_ready(ticket: int) -> Dictionary:
	if ticket != _ticket or _phase not in ["BAKING", "READY"]: return _no("STALE_SHADOW_TICKET")
	if not _old_owner_current(): return _hold("OLD_NAV_OR_SOURCE_DRIFT_DURING_BAKE")
	var state: String = _shadow.state()
	if state == "READY" and _shadow._baking_token == 0 and _shadow._waiting.is_empty() and _shadow._jobs.is_empty() and _shadow.map_rid().is_valid():
		_phase = "READY"
		return {"ok": true, "ticket": ticket, "phase": _phase, "map_ready": true,
			"iteration": NavigationServer3D.map_get_iteration_id(_shadow.map_rid()), "owner_lease": false}
	if state not in ["BAKING", "SYNCING"]: return _hold("SHADOW_MAP_FAILED:" + state)
	return {"ok": true, "ticket": ticket, "phase": "BAKING", "map_ready": false, "owner_lease": false}

## Called in the same root main-thread stack after ordinary scene commit and
## population atomic finalization+flush, while the root keeps SceneTree paused.
func commit_after_released_pause(ticket: int) -> Dictionary:
	if ticket != _ticket or _phase != "READY" or not Thread.is_main_thread(): return _no("SHADOW_NOT_READY")
	var main: Node3D = _main.get_ref() if _main != null else null
	if not is_instance_valid(main) or not main.get_tree().paused: return _no("ROOT_PAUSE_REQUIRED_FOR_SWAP")
	if _population._editor_pause_active or _navigation._editor_pause_active or _old_backend._editor_paused or _old_backend._atomic_flush_pending or not _old_backend._held_completions.is_empty(): return _no("RESIDENT_NAV_PAUSE_NOT_FULLY_RELEASED")
	if _navigation._backend != _old_backend or _navigation._static != _proposal.old_geometry or _navigation._geometry_version != _old_version or _navigation._revision != _old_revision: return _hold("OLD_NAV_OWNER_DRIFT_AT_SWAP")
	if _navigation._records.size() != 0 or _old_backend._jobs.size() != 0 or _old_backend._baking_token != 0 or not _old_backend._waiting.is_empty(): return _hold("OLD_NAV_CALLBACK_OR_JOB_STILL_ACTIVE")
	var current: Dictionary = _geometry.current_stream(main, _proposal.source_id)
	if not current.get("ok", false) or current.faces != _proposal.proposed_geometry: return _no("SCENE_COLLIDERS_DO_NOT_MATCH_READY_SHADOW_MAP")
	if _shadow.state() != "READY" or not _shadow.map_rid().is_valid() or _shadow._baking_token != 0 or not _shadow._waiting.is_empty() or not _shadow._jobs.is_empty(): return _hold("SHADOW_MAP_LOST_READY_BEFORE_SWAP")
	_navigation._backend = _shadow
	_navigation._static = _proposal.proposed_geometry.duplicate()
	_navigation._geometry_version = _old_version + 1
	_navigation._revision = _old_revision + 1
	_navigation._stats.publications = _old_publications + 1
	_navigation._stats.triangles = int(_proposal.new_faces)
	_phase = "SWAPPED"
	return {"ok": true, "ticket": ticket, "phase": _phase, "map_ready": true, "navigation_swap_committed": true, "ordinary_tx_token": false}

func rollback_after_scene_restore(ticket: int) -> Dictionary:
	if ticket != _ticket or _phase != "SWAPPED": return _no("NO_REVERSIBLE_SWAP")
	var main: Node3D = _main.get_ref() if _main != null else null
	if not is_instance_valid(main) or not main.get_tree().paused: return _hold("ROOT_PAUSE_LOST_DURING_ROLLBACK")
	var current: Dictionary = _geometry.current_stream(main, _proposal.source_id)
	if not current.get("ok", false) or current.faces != _proposal.old_geometry: return _no("ORIGINAL_SCENE_COLLIDERS_NOT_RESTORED")
	if _navigation._backend != _shadow or _navigation._static != _proposal.proposed_geometry or _navigation._geometry_version != _old_version + 1 or _navigation._revision != _old_revision + 1: return _hold("SWAPPED_NAV_OWNER_DRIFT")
	_navigation._backend = _old_backend
	_navigation._static = _proposal.old_geometry.duplicate()
	_navigation._geometry_version = _old_version; _navigation._revision = _old_revision
	_navigation._stats.publications = _old_publications; _navigation._stats.triangles = _old_triangles
	_shadow.dispose(); _shadow = null
	_phase = "ROLLED_BACK"
	return {"ok": true, "ticket": ticket, "phase": _phase, "map_ready": true, "owner_lease": false}

func finalize(ticket: int) -> Dictionary:
	if ticket != _ticket or _phase != "SWAPPED": return _no("NO_COMMITTED_SWAP")
	var main: Node3D = _main.get_ref() if _main != null else null
	if not is_instance_valid(main) or main.get_tree().paused: return _no("ROOT_RESUME_REQUIRED")
	var current: Dictionary = _geometry.current_stream(main, _proposal.source_id)
	if not current.get("ok", false) or current.faces != _proposal.proposed_geometry or _navigation._backend != _shadow or _shadow.state() != "READY": return _hold("NEW_NAV_OR_SCENE_DRIFT_AFTER_RESUME")
	_old_backend.dispose(); _old_backend = null
	_phase = "COMMITTED"
	return {"ok": true, "ticket": ticket, "phase": _phase, "map_ready": true, "owner_lease": false}

func abort(ticket: int) -> Dictionary:
	if ticket != _ticket or _phase not in ["BAKING", "READY"]: return _no("SHADOW_ABORT_NOT_ALLOWED")
	if _shadow != null: _shadow.dispose(); _shadow = null
	_phase = "ABORTED"
	return {"ok": true, "ticket": ticket, "phase": _phase, "owner_lease": false}

func _old_owner_current() -> bool:
	var main: Node3D = _main.get_ref() if _main != null else null
	if not is_instance_valid(main) or not main.is_inside_tree() or _navigation == null or _navigation._backend != _old_backend or _navigation._static != _proposal.old_geometry or _navigation._geometry_version != _old_version or _navigation._revision != _old_revision: return false
	if _paused_population_receipt.is_empty():
		if main.get_tree().paused or _population._editor_pause_active or _navigation._editor_pause_active: return false
	elif not main.get_tree().paused or not _population.verify_editor_pause(_paused_population_receipt): return false
	if _navigation._records.size() != 0 or _old_backend._jobs.size() != 0 or _old_backend._baking_token != 0 or not _old_backend._waiting.is_empty(): return false
	var current: Dictionary = _geometry.current_stream(main, _proposal.source_id)
	return current.get("ok", false) and current.faces == _proposal.old_geometry

func _no(reason: String) -> Dictionary:
	return {"ok": false, "phase": _phase, "error": reason, "owner_lease": false}

func _hold(reason: String) -> Dictionary:
	_phase = "HOLD"
	return _no(reason)
