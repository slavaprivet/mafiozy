extends "res://test_full_paged_editor.gd"
const Incremental = preload("res://incremental_prepare.gd")
var _identity_state := {}
var _reentry_cursor: RefCounted
var _reenter_once := false
var _mutating_candidate := {}
var _mutate_once := false
var _begin_reentry_cursor: RefCounted
var _begin_reentry_controller: Node
var _begin_reentry_candidate := {}
var _begin_reentry_sha := ""
var _begin_reenter_once := false

func identity() -> Dictionary:
	return _identity_state.duplicate(true)

func reentrant_identity() -> Dictionary:
	if _reenter_once:
		_reenter_once = false
		_reentry_cursor.step(1, 100)
	return identity()

func mutating_identity() -> Dictionary:
	if _mutate_once:
		_mutate_once = false
		_mutating_candidate.objects[0].kind = "mutated-during-callback"
		_identity_state.candidate_generation += 1
	return identity()

func beginning_identity() -> Dictionary:
	if _begin_reenter_once:
		_begin_reenter_once = false
		_begin_reentry_cursor.begin(_begin_reentry_controller, _begin_reentry_candidate, Callable(self, "beginning_identity"), _begin_reentry_sha)
	return identity()

func _advance(cursor: RefCounted, state: Dictionary) -> Dictionary:
	var batches := 0
	while state.get("ok", false) and not state.has("document") and not state.get("complete", false):
		state = cursor.step(96, 4000)
		batches += 1
		if batches > 4000: return {"ok": false, "error": "Fixture cursor did not converge", "phase": cursor.status().phase, "processed": cursor.status().processed, "batches": batches, "status": cursor.status()}
		if not state.has("document") and state.get("ok", false): await process_frame
	state["batches"] = batches
	return state

func _drive(controller: Node, candidate: Dictionary, expected_hash: String) -> Dictionary:
	var cursor := Incremental.new()
	var state: Dictionary = cursor.begin(controller, candidate, Callable(self, "identity"), expected_hash)
	return await _advance(cursor, state)

func run() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	assets = authored_factory_class().new()
	check(assets.configure(catalog), "actual 196 GLB admission")
	var session: Dictionary = make_session()
	if not session.get("ok", false):
		for error in failures: push_error(error)
		quit(1)
		return
	var controller: Node = session.controller
	var source: Dictionary = controller.document.to_dictionary()
	check(source.objects.size() == 9901, "actual full 9901 source")
	var baseline_sha: String = Incremental.source_digest(controller._baseline)
	_identity_state = {"owner_instance_id": session.composite.get_instance_id(), "source_sha256": baseline_sha, "source_generation": 1, "candidate_generation": 1, "lease_id": "fixture-1", "paused": true}
	check(controller.begin_atomic_install().ok, "atomic edit session retained")
	check(controller.document.begin_install_guard(), "document guard retained")
	var oracle: Dictionary = controller.prepare_install_document(source)
	var started := Time.get_ticks_usec()
	var valid: Dictionary = await _drive(controller, source, baseline_sha)
	var elapsed := Time.get_ticks_usec() - started
	if not oracle.ok or not valid.ok: print("INCREMENTAL_VALID_DIAG " + JSON.stringify({"oracle_error": oracle.get("error", ""), "candidate_error": valid.get("error", ""), "candidate_phase": valid.get("phase", ""), "candidate_processed": valid.get("processed", -1), "batches": valid.get("batches", 0)}))
	check(oracle.ok and valid.ok and valid.has("document"), "full map both preparers admit")
	if oracle.ok and valid.has("document"): check(Trusted.equal(oracle.document, valid.document), "exact full normalized document parity")
	check(valid.get("batches", 0) > 1, "real process-frame cursor boundaries")
	var protected_id := ""
	for id: String in session.composite.ids():
		if not session.composite.is_editable(id):
			protected_id = id
			break
	check(not protected_id.is_empty(), "actual protected ID exists")
	var negative_batches := 0
	for name: String in ["foreign map", "duplicate ID", "opaque source mutation", "late schema error precedes early provenance error", "nonfinite coordinate", "transform extra mutation", "whole-document depth32 boundary", "protected owner copy"]:
		if name == "protected owner copy" and protected_id.is_empty(): continue
		var candidate: Dictionary = source.duplicate(true)
		match name:
			"foreign map": candidate.map_id = "foreign-map"
			"duplicate ID": candidate.objects.append(candidate.objects[0].duplicate(true))
			"opaque source mutation", "late schema error precedes early provenance error": candidate.objects[0].kind = "untrusted-kind"
			"nonfinite coordinate": candidate.objects[0].transform.position[0] = NAN
			"transform extra mutation": candidate.objects[0].transform["untrusted_extra"] = 1
			"whole-document depth32 boundary":
				var nested: Variant = "leaf"
				for i in 30: nested = [nested]
				candidate.objects[0].source["depth_boundary"] = nested
			"protected owner copy":
				for row: Dictionary in candidate.objects:
					if row.id != protected_id: continue
					var copy: Dictionary = row.duplicate(true)
					copy.id = "editor:forbidden-protected"
					copy.template_id = protected_id
					candidate.objects.append(copy)
					break
		if name == "late schema error precedes early provenance error": candidate.objects[candidate.objects.size() - 1].transform.position[0] = NAN
		var original: Dictionary = controller.prepare_install_document(candidate)
		var actual: Dictionary = await _drive(controller, candidate, baseline_sha)
		negative_batches += int(actual.get("batches", 0))
		if original.ok or actual.ok or str(original.get("error", "")) != str(actual.get("error", "")): print("INCREMENTAL_NEGATIVE_DIAG " + JSON.stringify({"name": name, "oracle_error": original.get("error", ""), "candidate_error": actual.get("error", ""), "candidate_phase": actual.get("phase", ""), "candidate_processed": actual.get("processed", -1), "batches": actual.get("batches", 0)}))
		check(not original.ok and not actual.ok and str(original.get("error", "")) == str(actual.get("error", "")), "exact rejection parity: " + name)
	var stale := Incremental.new()
	check(stale.begin(controller, source, Callable(self, "identity"), baseline_sha).ok, "stale-generation cursor begins")
	check(stale.step(16, 2000).ok, "stale-generation cursor does one bounded batch")
	await process_frame
	_identity_state.candidate_generation = 2
	var stale_result: Dictionary = stale.step(16, 2000)
	check(not stale_result.ok and stale.status().failed and not stale_result.has("document"), "candidate generation change fails closed")
	_identity_state.candidate_generation = 1
	var gone := Incremental.new()
	check(gone.begin(controller, source, Callable(self, "identity"), baseline_sha).ok, "owner-lifetime cursor begins")
	_identity_state.owner_instance_id = 0
	check(not gone.step(16, 2000).ok and gone.status().failed, "owner identity change fails closed")
	_identity_state.owner_instance_id = session.composite.get_instance_id()
	_begin_reentry_cursor = Incremental.new()
	_begin_reentry_controller = controller
	_begin_reentry_candidate = source
	_begin_reentry_sha = baseline_sha
	_begin_reenter_once = true
	check(not _begin_reentry_cursor.begin(controller, source, Callable(self, "beginning_identity"), baseline_sha).ok and _begin_reentry_cursor.status().failed, "reentrant begin identity callback fails closed")
	_reentry_cursor = Incremental.new()
	check(_reentry_cursor.begin(controller, source, Callable(self, "reentrant_identity"), baseline_sha).ok, "reentrant cursor begins")
	_reenter_once = true
	check(not _reentry_cursor.step(16, 2000).ok and _reentry_cursor.status().failed, "reentrant identity callback fails closed")
	_mutating_candidate = source.duplicate(true)
	var mutator := Incremental.new()
	check(mutator.begin(controller, _mutating_candidate, Callable(self, "mutating_identity"), baseline_sha).ok, "mutation cursor begins")
	_mutate_once = true
	check(not mutator.step(16, 2000).ok and mutator.status().failed, "callback mutation with generation change fails closed")
	_identity_state.candidate_generation = 1
	var bad_sha := "0".repeat(64)
	_identity_state.source_sha256 = bad_sha
	var hash_cursor := Incremental.new()
	var hash_begin: Dictionary = hash_cursor.begin(controller, source, Callable(self, "identity"), bad_sha)
	check(hash_begin.ok, "wrong source receipt deferred to actual stream hash")
	var hash_result: Dictionary = await _advance(hash_cursor, hash_begin)
	if hash_result.get("error", "") != "Pinned source SHA does not match actual baseline": print("INCREMENTAL_HASH_DIAG " + JSON.stringify({"error": hash_result.get("error", ""), "phase": hash_result.get("phase", hash_cursor.status().phase), "processed": hash_result.get("processed", hash_cursor.status().processed), "batches": hash_result.get("batches", 0)}))
	check(not hash_result.get("ok", false) and hash_cursor.status().failed and hash_result.get("error", "") == "Pinned source SHA does not match actual baseline", "actual baseline hash mismatch fails closed")
	_identity_state.source_sha256 = baseline_sha
	check(Trusted.equal(source, controller.document.to_dictionary()), "preparation never mutates model")
	check(session.composite.ids().size() == 9901, "preparation never mutates registry")
	controller.document.end_install_guard()
	controller.end_atomic_install()
	dispose_extras(session)
	session.world.free()
	for error in failures: push_error(error)
	print(JSON.stringify({"suite": "actual-full-incremental-prepare", "checks": checks, "failures": failures, "sourceObjects": 9901, "validBatches": valid.get("batches", 0), "negativeBatches": negative_batches, "wrongHashBatches": hash_result.get("batches", 0), "validElapsedUsec": elapsed, "gpu": false, "productionWired": false, "ownerCallbacks": "test fixtures", "fullInstallHitchSolved": false}))
	quit(0 if failures.is_empty() else 1)
