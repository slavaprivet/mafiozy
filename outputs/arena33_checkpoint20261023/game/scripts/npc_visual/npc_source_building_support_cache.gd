extends "res://scripts/npc_visual/npc_source_building_support.gd"
## Predecoded immutable source cache; exact source recipes/data remain archived.
## Same inherited query implementation. No current dynamic or admission proof.
const CACHE_SHA := "b024890f87a7713246aaaace5ba5a903dfb3bff2626fc525e776d354cf9885f3"
const SOURCE_HELPER_SHA := "25fbaa80e9465f907e0768c68efe792867cbc72e48f1cb40dae5a7a2958f11c5"

func configure_cached(cache_bytes: PackedByteArray) -> Dictionary:
	if _configured: return {"ok": false, "error": "already_configured"}
	if cache_bytes.size() > 8388608 or _hash(cache_bytes) != CACHE_SHA: return {"ok": false, "error": "cache_bytes"}
	if _hash(FileAccess.get_file_as_bytes("res://scripts/npc_visual/npc_source_building_support.gd")) != SOURCE_HELPER_SHA: return {"ok": false, "error": "source_helper_changed"}
	# Native deserialization cannot construct Objects. Whole bytes are hardbound
	# to the separately checked 358406-value Float64/type-preserving roundtrip.
	var payload: Variant = bytes_to_var(cache_bytes)
	if not payload is Dictionary or payload.get("schema") != "mafiozi.npc-source-building-native-cache/v1" or payload.get("data_sha256") != DATA_SHA or payload.get("values_sha256") != VALUES_SHA or payload.get("source_helper_sha256") != SOURCE_HELPER_SHA or payload.get("phase") != PHASE or payload.get("engine") != Engine.get_version_info().string or not payload.get("entries") is Array or payload.entries.size() != 78 or not payload.get("sample_rows") is Dictionary: return {"ok": false, "error": "cache_binding"}
	_entries = payload.entries; _sample_rows = payload.sample_rows; _configured = true
	return {"ok": true, "entries": 78, "cache_sha256": CACHE_SHA, "source_data_sha256": DATA_SHA, "source_values_sha256": VALUES_SHA, "phase": PHASE, "combined_ground": false, "physical_admission": false}
