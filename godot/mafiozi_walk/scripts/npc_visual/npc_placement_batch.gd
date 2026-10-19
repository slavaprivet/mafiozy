extends RefCounted
## Full pinned source solve coordinator. Never creates actors, changes births,
## executes route commands, or substitutes missing BODY/lease proof.
const Solver = preload("res://scripts/npc_visual/npc_initial_placement.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const SOURCE_OBJECTS := 326
var _solver: RefCounted
var _status := "UNCONFIGURED"
var _error := ""
var _busy := false
var _dispose_requested := false
var _trust: Dictionary = {}
var _body_pass: Callable
var _current_lease: Callable
var _clock: Callable
var _owners: Dictionary = {}
var _generations: Dictionary = {}
var _identities: Dictionary = {}
var _by_id: Dictionary = {}
var _events: Array[Dictionary] = []
var _event_by_key: Dictionary = {}
var _expected_events := 0
var _slices := 0
var _stats: Dictionary = {}

func _fail(reason: String) -> Dictionary:
	_error = reason; _status = "FAULT"
	_events.clear(); _event_by_key.clear()
	return {"ok":false,"status":_status,"error":reason,"done":false}

func _enter() -> bool:
	if not Thread.is_main_thread(): return false
	if _busy:
		_fail("reentrancy")
		return false
	if _status in ["FAULT","UNRESOLVED","DISPOSED"]: return false
	_busy = true
	return true

func _leave() -> void:
	_busy = false
	if _dispose_requested: dispose()

func _owners_current() -> bool:
	for id: String in _owners:
		var owner: Variant = _owners[id]
		if not is_instance_valid(owner) or not owner is Queue.Owner or owner.dead or owner.source_id != id or owner.life_generation != _generations[id]: return false
	return true

func _lease_current() -> bool:
	if _dispose_requested or _status in ["FAULT","DISPOSED"] or not _body_pass.is_valid() or not _clock.is_valid() or not _current_lease.is_valid() or not _owners_current(): return false
	var answer: Variant = _current_lease.call(_trust.duplicate(true))
	return answer is bool and answer and not _dispose_requested and _status not in ["FAULT","DISPOSED"] and _current_lease.is_valid() and _body_pass.is_valid() and _clock.is_valid() and _owners_current()

## owners is the actual admission target subset, NOT fabricated full-world
## physical owners. The aggregate lease proves the captured whole context.
func configure(context_bytes: PackedByteArray, trust: Dictionary, source_body_pass: Callable, current_lease: Callable, clock_ms: Callable, owners: Dictionary) -> Dictionary:
	if _status != "UNCONFIGURED" or not _enter(): return {"ok":false,"error":"lifetime"}
	if not source_body_pass.is_valid() or not current_lease.is_valid() or not clock_ms.is_valid() or owners.is_empty() or owners.size() > SOURCE_OBJECTS:
		_fail("ports_or_owners"); _leave(); return state()
	var solver := Solver.new()
	var configured: Dictionary = solver.configure(context_bytes,trust,source_body_pass,clock_ms)
	if not configured.get("ok",false):
		_fail("solver_configure:"+str(configured.get("error","unknown"))); _leave(); return state()
	# Parse only during loading. Retain identity/role/eligibility, not another
	# mutable full population or MAP. The solver owns all spacing coordinates.
	var parsed: Dictionary = JSON.parse_string(context_bytes.get_string_from_utf8())
	var objects: Dictionary = {}
	for item: Dictionary in parsed.context.objects: objects[item.object_key] = item.raw
	var identities: Dictionary = {}; var ids: Dictionary = {}; var eligible := 0
	for pool: String in ["NPCS","cityCops","worldCops"]:
		for key: String in parsed.context.pools[pool]:
			if identities.has(key): continue
			var raw: Dictionary = objects[key]
			var id: Variant = raw.get("id")
			# Verified pinned context has 326 unique String IDs. Never synthesize
			# IDs from aliases or silently normalize another future context.
			if not id is String or id.is_empty() or ids.has(id):
				_fail("source_identity"); _leave(); return state()
			var kind := "resident" if pool == "NPCS" else "police"
			var xy := kind == "police" and Solver._finite_number(raw.get("y")) and Solver._finite_number(raw.get("x"))
			var included := Solver._eligible(raw) and Solver._finite_number(raw.get("y" if xy else "r")) and Solver._finite_number(raw.get("x" if xy else "c"))
			identities[key] = {"raw_id":id,"kind":kind,"eligible":included}
			ids[id] = key
			if included: eligible += 1
	if identities.size() != SOURCE_OBJECTS or eligible + int(configured.stats.skipped) != SOURCE_OBJECTS:
		_fail("incomplete_or_interior_context"); _leave(); return state()
	var generations := {}
	for id: Variant in owners:
		var owner: Variant = owners[id]
		if not id is String or not ids.has(id) or not owner is Queue.Owner or owner.dead or owner.source_id != id or owner.life_generation < 1:
			_fail("owner_identity"); _leave(); return state()
		generations[id] = owner.life_generation
	_trust = trust.duplicate(true); _body_pass = source_body_pass; _current_lease = current_lease; _clock = clock_ms
	_owners = owners.duplicate(); _generations = generations; _identities = identities; _by_id = ids
	_expected_events = eligible; _stats = configured.stats.duplicate(true)
	if not _lease_current():
		_fail("configure_lease"); _leave(); return state()
	_solver = solver; _status = "PENDING"
	_leave()
	return state()

## No events escape this method, including successful partial slices.
func step() -> Dictionary:
	if not _enter(): return state()
	if _status == "UNCONFIGURED": _leave(); return {"ok":false,"error":"unconfigured"}
	if not _lease_current():
		_fail("lease_changed_before_step"); _leave(); return state()
	if _status == "COMPLETE": _leave(); return state()
	var running: RefCounted = _solver
	var result: Dictionary = running.step(128 if _slices == 0 else 96,4.0 if _slices == 0 else 2.0)
	_slices += 1
	# Keep the solver's truthful partial-work diagnostics even when every
	# candidate is suppressed by a fault or lease change in this slice.
	if result.get("stats") is Dictionary: _stats = result.stats.duplicate(true)
	if _status == "FAULT" or _dispose_requested:
		_leave(); return state()
	if not _lease_current():
		_fail("lease_changed_after_step"); _leave(); return state()
	if not result.get("ok",false) or result.get("status") == "FAULT":
		_fail("solver:"+str(result.get("error","unknown"))); _leave(); return state()
	if result.status == "UNRESOLVED":
		_status = "UNRESOLVED"; _error = "source_unresolved"; _events.clear(); _event_by_key.clear()
		_leave(); return state()
	if result.status not in ["PENDING","COMPLETE"]:
		_fail("solver_status"); _leave(); return state()
	for event: Dictionary in result.events:
		var key: String = event.get("object_key","")
		if not _identities.has(key) or _event_by_key.has(key) or _events.size() >= _expected_events:
			_fail("event_identity_or_duplicate"); break
		var identity: Dictionary = _identities[key]
		if not identity.eligible or event.get("raw_id") != identity.raw_id or event.get("kind") != identity.kind or event.get("physical_admission") != false or event.get("status") not in ["original","relocated"] or not Solver._finite_number(event.get("r")) or not Solver._finite_number(event.get("c")):
			_fail("event_contract"); break
		for field: String in ["context_sha256","source_world_sha256","session_id","phase","provider"]:
			if not _same_typed(event.get(field),_trust.get(field)):
				_fail("event_provenance"); break
		if _status == "FAULT": break
		# Solver returns an already independent event tree. It remains local to
		# this coordinator; publication below makes the sole outward deep copy.
		var owned := event
		_events.append(owned); _event_by_key[key] = owned
	if _status != "FAULT" and result.status == "COMPLETE":
		if not result.get("done",false) or int(_stats.get("pending",-1)) != 0 or int(_stats.get("unresolved",-1)) != 0 or int(_stats.get("exhausted",-1)) != 0 or int(_stats.get("checked",-1)) != _expected_events or int(_stats.get("checked",-1))+int(_stats.get("skipped",-1)) != SOURCE_OBJECTS or _events.size() != _expected_events:
			_fail("incomplete_solver_receipt")
		else: _status = "COMPLETE"
	_leave()
	return state()

static func _same_typed(a: Variant,b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same_typed(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _same_typed(a[i],b[i]): return false
		return true
	return a == b

func candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _enter(): return result
	if _status == "COMPLETE":
		if _lease_current():
			result = _events.duplicate(true)
			if not _lease_current(): result.clear(); _fail("publication_lease_changed")
		else: _fail("publication_lease_changed")
	_leave()
	return [] if _status != "COMPLETE" else result

func placement_receipt() -> Dictionary:
	if not _enter(): return {}
	var result := {}
	if _status == "COMPLETE":
		if _lease_current():
			for key: String in ["context_sha256","source_world_sha256","session_id","phase","provider"]: result[key] = _trust[key].duplicate(true) if _trust[key] is Dictionary else _trust[key]
			if not _lease_current(): result.clear(); _fail("publication_lease_changed")
		else: _fail("publication_lease_changed")
	_leave()
	return {} if _status != "COMPLETE" else result

## Direct Callable for preview_resident_host.bind_placement_source. Exact
## delivered event, source alias/id/role and target current life must all agree.
func validate_candidate(candidate: Dictionary, raw_id: String, generation: int) -> bool:
	if not _enter(): return false
	var valid := false
	if _status == "COMPLETE" and _owners.has(raw_id) and generation == _generations[raw_id]:
		if _lease_current():
			var key: String = _by_id[raw_id]
			valid = _event_by_key.has(key) and candidate.get("object_key") == key and candidate.get("raw_id") == raw_id and _same_typed(candidate,_event_by_key[key])
			if not _lease_current(): valid = false; _fail("validation_lease_changed")
		else: _fail("validation_lease_changed")
	elif _status == "COMPLETE" and not _owners_current(): _fail("validation_owner_changed")
	_leave()
	return valid and _status == "COMPLETE"

func state() -> Dictionary:
	return {"ok":_status in ["PENDING","COMPLETE"],"status":_status,"done":_status=="COMPLETE","error":_error,"source_objects":_identities.size(),"target_owners":_owners.size(),"eligible":_expected_events,"slices":_slices,"collected_events":_events.size(),"stats":_stats.duplicate(true),"physical_admission":false}

func dispose() -> void:
	if not Thread.is_main_thread() or _status == "DISPOSED": return
	if _busy: _dispose_requested = true; return
	_status = "DISPOSED"; _dispose_requested = false
	_solver = null; _events.clear(); _event_by_key.clear(); _identities.clear(); _by_id.clear(); _owners.clear(); _generations.clear(); _trust.clear()
	_body_pass = Callable(); _current_lease = Callable(); _clock = Callable()
