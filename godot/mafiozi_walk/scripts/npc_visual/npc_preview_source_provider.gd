extends RefCounted
## Immutable presentation candidates. Placement and authority belong to the host.
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const SCHEMA := "mafiozi.npc-preview-session/v1"
const MAX_BYTES := 8388608
var _packet: Dictionary = {}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _text_is(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func _number_is(value: Variant, expected: float) -> bool:
	return _finite(value) and float(value) == expected

static func _bool_is(value: Variant, expected: bool) -> bool:
	return value is bool and value == expected

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

static func load_verified(bytes: PackedByteArray, trusted_sha: String, trusted_sources: Dictionary) -> Dictionary:
	if bytes.size() > MAX_BYTES or not Loader._valid_hash(trusted_sha) or Loader._hash(bytes) != trusted_sha:
		return _fail("packet_hash")
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary or not _text_is(parsed.get("schema"), SCHEMA):
		return _fail("schema")
	var packet: Dictionary = parsed
	if not _text_is(packet.get("mode"), "NEW_SESSION_BOOTSTRAP") or not packet.get("session_id") is String or packet.session_id.is_empty():
		return _fail("mode_or_session")
	# Existing saves require their separate authenticated provider, never a birth fallback.
	var receipts: Variant = packet.get("source_receipts")
	if not receipts is Array or trusted_sources.is_empty():
		return _fail("source_receipts")
	var seen := {}
	for receipt in receipts:
		if not receipt is Dictionary or not receipt.get("path") is String or seen.has(receipt.path):
			return _fail("source_receipt_duplicate")
		if not trusted_sources.has(receipt.path) or not Loader._valid_hash(str(receipt.get("sha256", ""))) or not _text_is(trusted_sources[receipt.path], receipt.sha256):
			return _fail("source_receipt_hash")
		seen[receipt.path] = true
	if seen.size() != trusted_sources.size():
		return _fail("source_receipt_missing")
	var bootstrap: Variant = packet.get("bootstrap")
	if not bootstrap is Dictionary or not _text_is(bootstrap.get("scope"), "ordinary_native_init_loop") or not _text_is(bootstrap.get("placement_cutoff"), "BEFORE_NATIVE_RESOLVER"):
		return _fail("bootstrap_phase")
	if not _number_is(bootstrap.get("fresh_serial_start"), 0) or not _number_is(bootstrap.get("init_attempts"), 288):
		return _fail("bootstrap_origin")
	for field in ["factory_birth_count", "failed_attempts", "resident_serial"]:
		if not _integer(bootstrap.get(field), 0, 288):
			return _fail("bootstrap_counts")
	if bootstrap.factory_birth_count + bootstrap.failed_attempts != 288 or bootstrap.resident_serial != bootstrap.factory_birth_count or not _number_is(packet.get("full_roster_count"), bootstrap.factory_birth_count) or not Loader._valid_hash(str(packet.get("full_roster_sha256", ""))):
		return _fail("roster_counts")
	var rng: Variant = packet.get("rng")
	var clock: Variant = packet.get("clock")
	if not rng is Dictionary or not rng.get("algorithm") is String or rng.algorithm.is_empty() or not _integer(rng.get("seed"), 0, 4294967295) or not _integer(rng.get("draw_count"), 0, 1000000):
		return _fail("rng")
	if not clock is Dictionary or not _finite(clock.get("source_now_ms")) or not _finite(clock.get("game_minutes")) or not _text_is(clock.get("source_frame"), "POST_BUILDMAP_BEFORE_NATIVE_RESOLVER"):
		return _fail("clock")
	var world: Variant = packet.get("world")
	if not world is Dictionary or not _number_is(world.get("map_rows"), 200) or not _number_is(world.get("map_cols"), 180) or not Loader._valid_hash(str(world.get("map_sha256", ""))) or not _bool_is(world.get("provider_ready"), false):
		return _fail("world")
	var coordinates: Variant = packet.get("coordinates")
	if not coordinates is Dictionary or not _finite(coordinates.get("scale")) or coordinates.scale != 4.1:
		return _fail("coordinates")
	var origin: Variant = coordinates.get("origin")
	var crop: Variant = coordinates.get("crop")
	if not origin is Array or origin.size() != 3 or not crop is Dictionary or crop.size() < 4 or crop.size() > 5 or (crop.has("bounds") and not _text_is(crop.bounds, "half_open")):
		return _fail("coordinates")
	var expected_origin := [395.65, 0.0, 45.099999999999994]
	for index in 3:
		if not _finite(origin[index]) or float(origin[index]) != expected_origin[index]:
			return _fail("coordinates")
	var expected_crop := {"r_min": 0, "r_max": 31, "c_min": 76, "c_max": 107}
	for field in expected_crop:
		if not _integer(crop.get(field), 0, 180) or int(crop[field]) != expected_crop[field]:
			return _fail("coordinates")
	var rows: Variant = packet.get("rows")
	if not rows is Array or rows.size() > bootstrap.factory_birth_count:
		return _fail("rows")
	var identities := {}
	for row in rows:
		if not row is Dictionary or not row.get("source_id") is String:
			return _fail("row")
		var source_id: String = row.source_id
		var suffix := source_id.trim_prefix("resident_")
		if not source_id.begins_with("resident_") or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() > bootstrap.resident_serial or identities.has(source_id) or not _text_is(row.get("bridge_id"), "npc_" + source_id):
			return _fail("identity")
		identities[source_id] = true
		var raw: Variant = row.get("source_raw")
		var bridge: Variant = row.get("bridge_row")
		if not raw is Dictionary or not _text_is(raw.get("id"), source_id) or not _bool_is(raw.get("_npcInitialPlacementPending"), true) or not bridge is Dictionary or not _text_is(bridge.get("id"), row.bridge_id):
			return _fail("source_row")
		if not _finite(raw.get("r")) or not _finite(raw.get("c")) or raw.r < 0 or raw.r >= 31 or raw.c < 76 or raw.c >= 107:
			return _fail("crop")
		if not _finite(bridge.get("r")) or not _finite(bridge.get("c")) or bridge.r != raw.r or bridge.c != raw.c or not raw.get("look") is Dictionary or not bridge.get("look") is Dictionary or bridge.look != raw.look:
			return _fail("bridge_projection")
		if not row.get("descriptor_json") is String or not Loader._valid_hash(str(row.get("descriptor_sha256", ""))) or Loader._hash(row.descriptor_json.to_utf8_buffer()) != row.descriptor_sha256:
			return _fail("descriptor_hash")
		var descriptor: Variant = JSON.parse_string(row.descriptor_json)
		if not descriptor is Dictionary or not _text_is(descriptor.get("id"), row.bridge_id):
			return _fail("descriptor_identity")
		var placement: Variant = row.get("placement")
		if not placement is Dictionary or not _bool_is(placement.get("pending"), true) or not _bool_is(placement.get("support_known"), false) or placement.has("support_y") or row.has("native_position"):
			return _fail("pending_placement")
	var provider: RefCounted = load("res://scripts/npc_visual/npc_preview_source_provider.gd").new()
	provider._packet = packet.duplicate(true)
	return {"ok": true, "provider": provider, "candidate_count": rows.size(), "admitted_count": 0}

func candidates() -> Array:
	return _packet.get("rows", []).duplicate(true)

func session_receipt() -> Dictionary:
	var result := _packet.duplicate(true)
	result.erase("rows")
	return result

func first_admitted() -> Dictionary:
	return _fail("HOLD_NATIVE_PLACEMENT_REQUIRED")
