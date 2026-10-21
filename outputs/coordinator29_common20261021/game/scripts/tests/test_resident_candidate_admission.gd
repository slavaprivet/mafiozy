extends "res://scripts/tests/test_preview_resident_host.gd"
## TEST_ONLY full-placement lease: proves native consumer, not source solving.
var lease_valid := true
var lease_calls := 0
var revoke_at := 0
var mutate_callback := false
var candidate_reentry := false
var expected_candidate := {}
var source_calls := 0
var revoke_after_source := false

func source_admit(point: Vector3, id: String, generation: int, footprint: float, purpose: String) -> bool:
	source_calls += 1
	var accepted := super.source_admit(point, id, generation, footprint, purpose)
	if revoke_after_source and source_calls == 2: lease_valid = false
	return accepted

func current_candidate(candidate: Dictionary, identity: String, generation: int) -> bool:
	lease_calls += 1
	var valid: bool = lease_valid and candidate == expected_candidate and identity == candidate.raw_id and generation == 1
	if revoke_at > 0 and lease_calls >= revoke_at: valid = false
	if mutate_callback:
		candidate.c = -123.0
		candidate.provider.id = "mutated private copy"
		candidate_reentry = host.admit_candidate(expected_candidate, 1).status == "UNAVAILABLE"
	return valid

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled = false; scene.preview_start_at_vehicle = false
	root.add_child(scene)
	await physics_frame; await physics_frame
	queue = Queue.new(); navigation = Navigation.new()
	check(navigation.attach_existing(scene, scene._printshop, scene._block, scene._printshop_data, queue, "test:candidate", 1, 1), "actual main geometry")
	packet = FileAccess.get_file_as_bytes(DIRECTORY + PACKET + ".json")
	manifest = FileAccess.get_file_as_bytes(DIRECTORY + "prepared/manifest.json")
	var parsed: Dictionary = JSON.parse_string(packet.get_string_from_utf8())
	var sources := {}
	for receipt: Dictionary in parsed.source_receipts: sources[receipt.path] = receipt.sha256
	trust = {"accepted":true,"packet_sha256":PACKET,"sources":sources,"session_id":parsed.session_id,"prepared_sha256":MANIFEST}
	for row: Dictionary in parsed.rows: owners[row.source_id] = Queue.Owner.new(row.source_id, 1)
	host = Host.new()
	check(configured(host, trust, owners).ok, "existing immutable session")
	var receipt := {"context_sha256":Host.PLACEMENT_CONTEXT,"source_world_sha256":Host.PLACEMENT_SOURCE,"phase":Host.PLACEMENT_PHASE,"session_id":parsed.session_id,
		"provider":{"id":"TEST_ONLY_full_placement","version":"1","semantics":"ROLE_BODY_PASS","sha256":"a".repeat(64)}}
	check(not host.bind_placement_source(receipt, Callable()).ok, "missing current lease rejected")
	check(host.bind_placement_source(receipt, current_candidate).ok, "bound once")
	check(not host.bind_placement_source(receipt, current_candidate).ok, "cannot replace source")
	check(host.admit_next().get("reason") == "candidate_required", "no raw-birth bypass")
	var row: Dictionary = parsed.rows[0]
	var immutable: Dictionary = row.source_raw.duplicate(true)
	expected_candidate = receipt.duplicate(true)
	expected_candidate.merge({"raw_id":row.source_id,"object_key":"TEST_ONLY_alias","kind":"resident","status":"relocated","r":float(immutable.r),"c":float(immutable.c)+.025,"physical_admission":false,"commands":[]})
	var forged: Dictionary = expected_candidate.duplicate(true); forged.raw_id = "new_actor"
	check(host.admit_candidate(forged, 1).get("reason") == "candidate_identity", "cannot create identities")
	for key in ["context_sha256","source_world_sha256","phase","session_id"]:
		forged = expected_candidate.duplicate(true); forged[key] = "stale"
		check(host.admit_candidate(forged, 1).get("reason") == "candidate_provenance", "reject stale " + key)
	forged = expected_candidate.duplicate(true); forged.physical_admission = true
	check(host.admit_candidate(forged, 1).get("reason") == "candidate_schema", "source cannot pregrant physical admission")
	forged = expected_candidate.duplicate(true); forged.c = NAN
	check(host.admit_candidate(forged, 1).get("reason") == "candidate_position", "nonfinite source coordinates")
	check(host.admit_candidate(expected_candidate, 2).get("reason") == "owner_invalid", "wrong life")
	lease_valid = false
	check(host.admit_candidate(expected_candidate, 1).get("reason") == "placement_lease_changed", "stale full-source lease")
	check(host.occupants().is_empty(), "stale never instantiates")
	lease_valid = true; lease_calls = 0; revoke_at = 2
	check(host.admit_candidate(expected_candidate, 1).get("reason") == "placement_changed_before_spawn", "lease rechecked after native support and asset preparation")
	check(host.occupants().is_empty(), "revoked admission frees prepared visual")
	lease_calls = 0; revoke_at = 0; source_calls = 0; revoke_after_source = true
	check(host.admit_candidate(expected_candidate, 1).get("reason") == "placement_changed_before_spawn", "source callback cannot revoke final lease then spawn")
	check(host.occupants().is_empty(), "late source revocation leaves no actor")
	revoke_after_source = false; lease_valid = true
	lease_calls = 0; revoke_at = 0; mutate_callback = true
	var admitted: Dictionary = host.admit_candidate(expected_candidate, 1)
	check(admitted.status == "IDLE", "real candidate admission " + str(admitted))
	check(candidate_reentry, "callback cannot reenter admission")
	check(expected_candidate.c > 0 and expected_candidate.provider.id == "TEST_ONLY_full_placement", "callback cannot alter caller event")
	check(host._records[row.source_id].row.source_raw == immutable, "immutable birth fields retained")
	if admitted.status == "IDLE":
		check(absf(admitted.position.x - (expected_candidate.c*4.1-395.65)) < .00001, "native body uses candidate not birth")
		check(absf(admitted.position.x - (immutable.c*4.1-395.65)) > .1, "observable distinct placement")
		check(host.admit_candidate(expected_candidate, 1).get("reason") == "already_admitted", "no duplicate or relocation of live actor")
	check(host.occupants().size() == 1, "one exact source actor")
	host.dispose(); navigation.dispose(); queue.dispose(); scene.free()
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"TEST_ONLY source lease, actual main native admission"}))
	quit(0 if failures.is_empty() else 1)
