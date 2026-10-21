extends RefCounted
## Immutable source dynamic-frame component. No actors or motion authority.
## Schema binding/configuration is being completed against the source exporter.
const Contact = preload("res://scripts/npc_visual/npc_source_contact_predicates.gd")
const CONTACT_SHA = "8ac80a738d0756ccff690bd33c02b3c7785baee5aa9bab67ba47ec13b860fab3"
const SOURCE_SHA = "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const CONTEXT_SHA = "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const WALK_SHA = "e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47"
const LOGICAL_SHA = "996143f37a8f380c16cde9c7ecd4eb42c4af109e4b364dff3ffc0aeca946865d"
const HISTORICAL_SESSION = "godot-preview-new-session-20260927-01"
const PRODUCER_SHA = "a277c9ddb6c10af54551047a55a39c284c2f1b0a070e346dbad6987c2a990d0d"
const PROVIDER_ID = "mafiozi.source-dynamic-point.component-v1"
const PROVIDER_VERSION = "1"
const MAX_BYTES = 16777216
const MAX_RECORDS = 65536
const MAX_BUCKET_REFS = 262144
const LEASE_FIELDS = ["source_world_sha256", "context_sha256", "static_component_context_sha256", "capture_context_sha256", "walk_module_sha256", "producer_code_sha256", "session_id", "phase", "snapshot_id", "revision", "frame_sha256"]
var _ready := false
var _busy := false
var _fault := ""
var _proof: Dictionary = {}
var _lease: Callable
var _rail: Array = []
var _fleet: Array = []
var _logical: Array = []
var _buckets: Dictionary = {}
var _calls := 0
var _test_only := true

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _same_id(a: Variant, b: Variant) -> bool:
	# JS strict equality treats int/float as Number, but never coerces strings.
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	return typeof(a) == typeof(b) and a == b

static func _id(value: Variant) -> bool:
	return value == null or value is String or value is bool or _finite(value)

func invalidate(reason: String = "invalidated") -> void:
	if not Thread.is_main_thread(): return
	_ready = false
	if _fault.is_empty():
		_fault = reason if not reason.is_empty() else "invalidated"

func _unknown(error: String) -> Dictionary:
	return {"known": false, "error": error, "physical_admission": false,
		"registered_frame_known": false, "test_only": _test_only,
		"provenance": _proof.duplicate(true)}

func _configured_error(error: String) -> Dictionary:
	return {"ok": false, "error": error, "physical_admission": false,
		"registered_frame_known": false}

func _lease_owner_live() -> bool:
	if not _lease.is_valid(): return false
	var owner: Object = _lease.get_object()
	if not is_instance_valid(owner): return false
	return not (owner is Node and owner.is_queued_for_deletion())

func _lease_valid() -> bool:
	if not _lease_owner_live():
		invalidate("lease_unavailable")
		return false
	var answer: Variant = _lease.call()
	if not _lease_owner_live():
		invalidate("lease_unavailable")
		return false
	if not _fault.is_empty(): return false
	if not answer is Dictionary:
		invalidate("lease_shape")
		return false
	# Capture once. A producer cannot mutate this returned container afterwards.
	var captured: Dictionary = answer.duplicate(true)
	if not captured.get("known") is bool or not captured.known:
		invalidate("lease_unknown")
		return false
	for key: String in LEASE_FIELDS:
		if not captured.has(key) or typeof(captured[key]) != typeof(_proof[key]) or captured[key] != _proof[key]:
			invalidate("lease_binding:" + str(key))
			return false
	return true

func _contact_record(record: Variant) -> bool:
	if not record is Dictionary or not record.get("contact") is Dictionary:
		return false
	var contact: Dictionary = record.contact
	if not contact.get("source_blockable") is bool or not contact.get("contact_known") is bool or not contact.contact_known: return false
	if not contact.source_blockable: return true
	if not contact.get("visible") is bool: return false
	if not contact.visible: return true
	for key: String in ["x", "y", "z", "yaw", "scale_x", "scale_y", "scale_z", "half_width", "half_length", "bounds_min_y", "bounds_max_y"]:
		if not _finite(contact.get(key)): return false
	return contact.half_width >= 0.0 and contact.half_length >= 0.0

func _vehicle(record: Dictionary, x: float, z: float, y: float, height: float) -> Dictionary:
	if not record.contact.source_blockable: return {"known": true, "blocked": false}
	return Contact.vehicle_blocks(record.contact, x, z, y, height)

static func _integer(value: Variant, limit: int = 2147483647) -> bool:
	return _finite(value) and value >= 0 and value <= limit and float(value) == floor(float(value))

static func _overlay(data: Dictionary, overlays: Variant) -> bool:
	if not overlays is Array or overlays.size() > 262144: return false
	var seen: Dictionary = {}
	for item: Variant in overlays:
		if not item is Dictionary or not item.get("path") is Array or item.path.is_empty() or not item.get("bytes_le") is Array or item.bytes_le.size() != 8: return false
		var path: Array = item.path
		var path_key := JSON.stringify(path)
		if seen.has(path_key): return false
		seen[path_key] = true
		var dest: Variant = data
		for i in path.size():
			var part: Variant = path[i]
			if dest is Array:
				if not _integer(part, dest.size() - 1): return false
				part = int(part)
			elif dest is Dictionary:
				if not part is String or not dest.has(part): return false
			else: return false
			if i < path.size() - 1:
				dest = dest[part]
			else:
				var raw := PackedByteArray()
				for byte: Variant in item.bytes_le:
					if not _integer(byte, 255): return false
					raw.append(int(byte))
				dest[part] = raw.decode_double(0)
	return true

func configure(bytes: PackedByteArray, trust: Dictionary, current_lease: Callable) -> Dictionary:
	if _busy: invalidate("reentrant"); return _configured_error(_fault)
	if not Thread.is_main_thread() or _ready or not _fault.is_empty(): return _configured_error("state_or_thread")
	if bytes.is_empty() or bytes.size() > MAX_BYTES: return _configured_error("frame_bytes")
	for key: String in ["data_sha256", "producer_code_sha256", "source_world_sha256", "context_sha256", "static_component_context_sha256", "walk_module_sha256", "session_id", "phase", "snapshot_id"]:
		if not trust.get(key) is String or trust[key].is_empty(): return _configured_error("trust:" + key)
	if not trust.get("revision") is int or trust.revision < 0: return _configured_error("revision")
	if trust.data_sha256 != _hash(bytes) or trust.producer_code_sha256 != PRODUCER_SHA or trust.source_world_sha256 != SOURCE_SHA or trust.context_sha256 != CONTEXT_SHA or trust.static_component_context_sha256 != CONTEXT_SHA or trust.walk_module_sha256 != WALK_SHA: return _configured_error("binding")
	if not trust.has("capture_context_sha256"): return _configured_error("capture_context_missing")
	if _hash(FileAccess.get_file_as_bytes("res://scripts/npc_visual/npc_source_contact_predicates.gd")) != CONTACT_SHA: return _configured_error("contact_code_binding")
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary: return _configured_error("json")
	var packet: Dictionary = parser.data
	if packet.get("schema") != "mafiozi.npc-source-dynamic-frame/v1" or packet.get("status") != "SOURCE_COMPONENT_REPLAY" or not packet.get("known") is bool or not packet.known: return _configured_error("frame_unknown")
	for key: String in ["producer_code_sha256", "source_world_sha256", "context_sha256", "static_component_context_sha256", "walk_module_sha256", "session_id", "phase", "snapshot_id"]:
		if not packet.get(key) is String or packet[key] != trust[key]: return _configured_error("packet_binding:" + key)
	if not _integer(packet.get("revision")) or int(packet.revision) != trust.revision: return _configured_error("packet_revision")
	if not packet.get("kind") is String or packet.kind not in ["SOURCE_CAPTURE", "TEST_ONLY_PARAMETERIZED_ORIGINAL_CONSTRUCTORS"]: return _configured_error("capture_kind")
	if packet.get("capture_context_sha256") != trust.capture_context_sha256: return _configured_error("capture_context_binding")
	if packet.kind == "SOURCE_CAPTURE":
		var capture: Variant = trust.capture_context_sha256
		if not capture is String or capture.length() != 64 or capture == CONTEXT_SHA or trust.session_id == HISTORICAL_SESSION: return _configured_error("fresh_capture_binding")
		for code: int in capture.to_utf8_buffer():
			if not (code >= 48 and code <= 57 or code >= 97 and code <= 102): return _configured_error("capture_context_hash")
	elif trust.capture_context_sha256 != null:
		return _configured_error("test_capture_context")
	if not packet.get("registered_frame") is bool or packet.registered_frame or not packet.get("physical_admission") is bool or packet.physical_admission or not packet.get("requires_host_capture_validation") is bool or not packet.requires_host_capture_validation: return _configured_error("admission_flags")
	if not packet.get("proof_receipts") is Array or packet.proof_receipts.is_empty() or not packet.get("source_function_receipts") is Array: return _configured_error("capture_receipts")
	var receipts: Dictionary = {}
	for receipt: Variant in packet.source_function_receipts:
		if not receipt is Dictionary or not receipt.get("name") is String or not receipt.get("sha256") is String or receipts.has(receipt.name): return _configured_error("source_receipt_shape")
		receipts[receipt.name] = receipt.sha256
	for pair: Array in [["assets/maps/city_rebuild_v1/walk_preview.mjs", WALK_SHA], ["assets/maps/city_rebuild_v1/npc_logical_vehicle_binding.mjs", LOGICAL_SHA], ["assets/maps/city_rebuild_v1/world_traffic_presentation.mjs", "be373d5b10474f94480e3f79fcae21c76ea3e7b5bac0a5fa2b82bf48bdfb5d51"], ["assets/maps/city_rebuild_v1/exploration_railway_plan.mjs", "3c02adf82c7a798174912a2d637e61bc7050ac531a0450427f56aecf9aba743b"]]:
		if receipts.get(pair[0]) != pair[1]: return _configured_error("source_receipt_binding")
	if not packet.get("data") is Dictionary: return _configured_error("data")
	var data: Dictionary = packet.data
	if not _overlay(data, packet.get("data_float64")): return _configured_error("float64_transport")
	if not _finite(data.get("source_frame")): return _configured_error("source_clock")
	for group: String in ["rail", "fleet", "logical"]:
		if not data.get(group) is Dictionary or not data[group].get("known") is bool or not data[group].known: return _configured_error("missing_group:" + group)
	var rail: Dictionary = data.rail; var fleet: Dictionary = data.fleet; var logical: Dictionary = data.logical
	if not rail.get("present") is bool or not rail.get("current_cars") is Array or rail.current_cars.size() > MAX_RECORDS: return _configured_error("rail_shape")
	if not rail.present and not rail.current_cars.is_empty(): return _configured_error("rail_absence")
	if not Contact.train_blocks(rail.current_cars, 0.0, 0.0).known: return _configured_error("rail_records")
	if not fleet.get("present") is bool or not fleet.get("records") is Array or fleet.records.size() > MAX_RECORDS: return _configured_error("fleet_shape")
	if not fleet.present and not fleet.records.is_empty(): return _configured_error("fleet_absence")
	for record: Variant in fleet.records:
		if not _contact_record(record) or not record.has("id") or not _id(record.id) or not record.get("ignore_key") is String: return _configured_error("fleet_record")
	if not logical.get("initialized") is bool or not logical.initialized or not _integer(logical.get("getter_calls")) or logical.getter_calls < 1 or not logical.get("records") is Array or logical.records.size() > MAX_RECORDS: return _configured_error("logical_shape")
	var record_index := 0
	for record: Variant in logical.records:
		if not _contact_record(record) or not record.has("id") or not _id(record.id) or not _integer(record.get("actor_alias_ordinal"), logical.records.size() - 1): return _configured_error("logical_record")
		var alias_index := int(record.actor_alias_ordinal)
		if alias_index > record_index: return _configured_error("logical_forward_alias")
		var original: Dictionary = logical.records[alias_index]
		if not _same_id(record.id, original.id) or int(original.actor_alias_ordinal) != alias_index or record.contact != original.contact: return _configured_error("logical_alias_binding")
		record_index += 1
	if not logical.get("grid") is Dictionary or logical.grid.get("cell_size") != 24.0 or not logical.grid.get("buckets") is Array: return _configured_error("logical_grid")
	var buckets: Dictionary = {}; var refs := 0
	for bucket: Variant in logical.grid.buckets:
		if not bucket is Dictionary or not bucket.get("key") is String or buckets.has(bucket.key) or not bucket.get("record_ordinals") is Array: return _configured_error("bucket_shape")
		var pieces: PackedStringArray = bucket.key.split(",")
		if pieces.size() != 2: return _configured_error("bucket_key")
		for piece: String in pieces:
			if not piece.is_valid_int() or str(int(piece)) != piece: return _configured_error("bucket_key")
		var ordinals: Array = []
		for ordinal: Variant in bucket.record_ordinals:
			if not _integer(ordinal, logical.records.size() - 1): return _configured_error("bucket_ordinal")
			ordinals.append(int(ordinal)); refs += 1
			if refs > MAX_BUCKET_REFS: return _configured_error("bucket_budget")
		buckets[bucket.key] = ordinals
	_proof = {}
	for key: String in LEASE_FIELDS:
		_proof[key] = trust[key] if key != "frame_sha256" else trust.data_sha256
	_proof.provider_id = PROVIDER_ID; _proof.provider_version = PROVIDER_VERSION; _proof.kind = packet.kind
	_test_only = packet.kind != "SOURCE_CAPTURE"
	_lease = current_lease; _busy = true
	var valid := _lease_valid()
	_busy = false
	if not valid: return _configured_error(_fault)
	_rail = rail.current_cars; _fleet = fleet.records; _logical = logical.records; _buckets = buckets
	_ready = true
	return {"ok": true, "physical_admission": false, "registered_frame_known": false, "test_only": _test_only, "provenance": _proof.duplicate(true)}

func blocks_dynamic(x: float, z: float, body: Dictionary = {}) -> Dictionary:
	if _busy: invalidate("reentrant"); return _unknown(_fault)
	if not Thread.is_main_thread() or not _ready or not _fault.is_empty(): return _unknown(_fault if not _fault.is_empty() else "not_ready_or_thread")
	if not is_finite(x) or not is_finite(z) or not _finite(body.get("y")) or (body.has("height") and not _finite(body.height)) or (body.has("ignoreId") and not _id(body.ignoreId)): return _unknown("query_shape")
	body = body.duplicate(true)
	# Cell keys are exact scalar integer strings, not Vector2/Vector3 values.
	if absf(x / 24.0) > 2147483647.0 or absf(z / 24.0) > 2147483647.0: return _unknown("query_coverage")
	_busy = true
	if not _lease_valid(): _busy = false; return _unknown(_fault)
	var result := Contact.train_blocks(_rail, x, z)
	var stage := "rail"
	var height: float = body.get("height", 1.9); var y: float = body.y
	if result.known and not result.blocked:
		stage = "fleet"
		for record: Dictionary in _fleet:
			if body.has("ignoreId") and _same_id(body.ignoreId, record.ignore_key): continue
			result = _vehicle(record, x, z, y, height)
			if not result.known or result.blocked: break
	if result.known and not result.blocked:
		stage = "logical"
		var key := str(int(floor(x / 24.0))) + "," + str(int(floor(z / 24.0)))
		for ordinal: int in _buckets.get(key, []):
			var record: Dictionary = _logical[ordinal]
			if body.has("ignoreId") and _same_id(body.ignoreId, record.id): continue
			result = _vehicle(record, x, z, y, height)
			if not result.known or result.blocked: break
	_calls += 1
	var valid := _lease_valid()
	_busy = false
	if not valid: return _unknown(_fault)
	if not result.known: return _unknown(result.get("error", "predicate_unknown"))
	return {"known": true, "blocked": result.blocked, "stage": stage, "physical_admission": false,
		"registered_frame_known": false, "test_only": _test_only, "provenance": _proof.duplicate(true)}

func snapshot() -> Dictionary:
	return {"ready": _ready, "fault": _fault, "calls": _calls,
		"rail_cars": _rail.size(), "fleet_records": _fleet.size(),
		"logical_records": _logical.size(), "logical_buckets": _buckets.size(),
		"provenance": _proof.duplicate(true), "test_only": _test_only,
		"physical_admission": false, "registered_frame_known": false}

