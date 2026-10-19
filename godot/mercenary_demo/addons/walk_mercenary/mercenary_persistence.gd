extends RefCounted
## Pure source-envelope adapter. Never writes storage, mutates live core/actors,
## allocates NPCs, transfers equipment, or rebases canonical core deadlines.
const MAX_BYTES := 4194304
const ROW_FIELDS := ["id", "sourceBotId", "name", "look", "r", "c", "hp", "max_hp", "weapon", "faction", "gangName"]

static func _fail(reason: String, restore := false) -> Dictionary:
	return {"ok": false, "error": reason, "preserved": true, "block_autosave": restore}

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _truth(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return is_finite(float(value)) and value != 0
	if value is String: return not value.is_empty()
	return true

static func _number(value: Variant) -> float:
	if _finite(value): return float(value)
	if value is bool: return 1.0 if value else 0.0
	if value is String and value.is_valid_float(): return float(value)
	return 0.0

static func _json_error(value: Variant, ancestors: Array = [], depth := 0) -> String:
	if depth > 64: return "json_nesting_limit"
	if value == null or value is String or value is StringName or value is bool or value is int: return ""
	if value is float: return "" if is_finite(value) else "nonfinite_json_number"
	if not value is Dictionary and not value is Array: return "non_json_value"
	for prior in ancestors:
		if is_same(prior, value): return "cyclic_json_value"
	ancestors.append(value)
	if value is Dictionary:
		for key in value:
			if not key is String and not key is StringName:
				ancestors.pop_back()
				return "non_string_json_key"
			var error := _json_error(value[key], ancestors, depth + 1)
			if not error.is_empty():
				ancestors.pop_back()
				return error
	else:
		for child in value:
			var error := _json_error(child, ancestors, depth + 1)
			if not error.is_empty():
				ancestors.pop_back()
				return error
	ancestors.pop_back()
	return ""

static func _header(core: Variant) -> bool:
	return core is Dictionary and _finite(core.get("version")) and core.version == 1 and core.get("members") is Array

static func _member_rows(core: Dictionary, rows: Array) -> Dictionary:
	var by_id := {}
	for row in rows:
		if not row is Dictionary or not row.get("id") is String or row.id.is_empty(): return _fail("invalid_row_identity")
		if by_id.has(row.id): return _fail("duplicate_row_identity")
		by_id[row.id] = row
	var selected: Array = []
	var ids: Array = []
	var identities := {}
	var seen_sources := {}
	for member in core.members:
		if not member is Dictionary or not member.get("id") is String or member.id.is_empty(): return _fail("invalid_core_identity")
		if member.id in ids: return _fail("duplicate_core_identity")
		if not by_id.has(member.id): return _fail("missing_or_invalid_member_row")
		var row: Dictionary = by_id[member.id]
		for field in ["r", "c", "hp", "max_hp"]:
			if not _finite(row.get(field)): return _fail("missing_or_invalid_member_row")
		var source_id: Variant = row.get("sourceBotId")
		if source_id != null:
			if not source_id is String and not _finite(source_id): return _fail("invalid_source_identity")
			var key := str(source_id)
			if key.is_empty() or seen_sources.has(key): return _fail("duplicate_or_empty_source_identity")
			seen_sources[key] = true
			identities[member.id] = key
		ids.append(member.id)
		selected.append(row)
	return {"ok": true, "rows": selected, "expected_ids": ids, "identities": identities}

static func encode(core_snapshot: Variant, host_rows: Variant, now_s: float, qa_enabled := false) -> Dictionary:
	if not _header(core_snapshot) or not host_rows is Array or not is_finite(now_s): return _fail("unsupported_or_incomplete_save")
	var error := _json_error(core_snapshot)
	if not error.is_empty(): return _fail(error)
	var selection := _member_rows(core_snapshot, host_rows)
	if not selection.ok: return selection
	var rows: Array = []
	for source in selection.rows:
		var row := {}
		for field in ROW_FIELDS:
			if source.has(field): row[field] = source[field]
		if source.has("baseHp"): row.baseHp = source.baseHp
		elif source.has("_mercenaryBaseHp"): row.baseHp = source._mercenaryBaseHp
		var generation: Variant = source.get("_mercenaryLifeGeneration", 0)
		row._mercenaryLifeGeneration = generation if _finite(generation) and generation >= 0 and floorf(float(generation)) == generation else 0
		if source.get("_mercenaryVehicleExplosionFatal") == true:
			row.merge({"_mercenaryVehicleExplosionFatal": true, "dead": true, "deathConfirmed": true, "deadAt": _number(source.get("deadAt")), "_lifeState": "dead"}, true)
		row._mercenaryOrder = source.get("_mercenaryOrder") if _truth(source.get("_mercenaryOrder")) else "follow"
		row._mercenaryRally = source.get("_mercenaryRally") if _truth(source.get("_mercenaryRally")) else null
		var rescue: Variant = source.get("_mercenaryQaRescueUntil")
		if qa_enabled and _finite(rescue) and rescue > now_s: row._mercenaryQaRescueUntil = minf(now_s + 600, float(rescue))
		error = _json_error(row)
		if not error.is_empty(): return _fail(error)
		rows.append(row)
	var text := JSON.stringify({"core": core_snapshot, "rows": rows}, "", true, true)
	var byte_count := text.to_utf8_buffer().size()
	if byte_count > MAX_BYTES: return _fail("save_size_limit")
	return {"ok": true, "text": text, "ids": selection.expected_ids, "bytes": byte_count}

static func _skip_json_space(text: String, cursor: int) -> int:
	while cursor < text.length() and text[cursor] in [" ", "\t", "\r", "\n"]: cursor += 1
	return cursor

static func _json_string_end(text: String, cursor: int) -> int:
	if cursor >= text.length() or text[cursor] != '"': return -1
	cursor += 1
	while cursor < text.length():
		if text[cursor] == '"': return cursor + 1
		if text[cursor] == "\\": cursor += 1
		cursor += 1
	return -1

static func _utf16_units(text: String) -> int:
	var count := 0
	for index in text.length(): count += 2 if text.unicode_at(index) > 0xffff else 1
	return count

## Locate tokens without changing the source. The native parser still validates
## the entire private buffer afterwards. Only direct core.members[i].name paths
## are candidates; ambiguous duplicate JSON keys are rejected in this fallback.
static func _scan_compat(text: String, cursor: int, path: Array, patches: Array, depth := 0) -> int:
	if depth > 64: return -1
	cursor = _skip_json_space(text, cursor)
	if cursor >= text.length(): return -1
	var first := text[cursor]
	if first == '"':
		var end := _json_string_end(text, cursor)
		if end < 0: return -1
		if path.size() == 4 and path[0] == "core" and path[1] == "members" and path[2] is int and path[3] == "name":
			var token := text.substr(cursor, end - cursor)
			if token.length() >= 8 and token.substr(token.length() - 7, 2) == "\\u":
				var hex := token.substr(token.length() - 5, 4)
				if hex.is_valid_hex_number(false):
					var unit := hex.hex_to_int()
					if unit >= 0xd800 and unit <= 0xdbff:
						var prefix_parser := JSON.new()
						var prefix_token := token.substr(0, token.length() - 7) + '"'
						if prefix_parser.parse(prefix_token) == OK and prefix_parser.data is String and _utf16_units(prefix_parser.data) == 99:
							patches.append({"start": end - 7, "member_index": path[2], "unit": unit, "prefix": prefix_parser.data})
		return end
	if first == "{" or first == "[":
		var object := first == "{"
		var closing := "}" if object else "]"
		var keys := {}
		var index := 0
		cursor = _skip_json_space(text, cursor + 1)
		if cursor < text.length() and text[cursor] == closing: return cursor + 1
		while cursor < text.length():
			var key: Variant = index
			if object:
				var key_end := _json_string_end(text, cursor)
				if key_end < 0: return -1
				var key_parser := JSON.new()
				if key_parser.parse(text.substr(cursor, key_end - cursor)) != OK or not key_parser.data is String: return -1
				key = key_parser.data
				if keys.has(key): return -1
				keys[key] = true
				cursor = _skip_json_space(text, key_end)
				if cursor >= text.length() or text[cursor] != ":": return -1
				cursor += 1
			var child_path := path.duplicate()
			child_path.append(key)
			cursor = _scan_compat(text, cursor, child_path, patches, depth + 1)
			if cursor < 0: return -1
			cursor = _skip_json_space(text, cursor)
			if cursor >= text.length(): return -1
			if text[cursor] == closing: return cursor + 1
			if text[cursor] != ",": return -1
			cursor = _skip_json_space(text, cursor + 1)
			index += 1
		return -1
	var start := cursor
	while cursor < text.length() and not text[cursor] in [",", "]", "}", " ", "\t", "\r", "\n"]: cursor += 1
	return cursor if cursor > start else -1

static func _legacy_name_buffer(text: String) -> Dictionary:
	var patches: Array = []
	var end := _scan_compat(text, 0, [], patches)
	if end < 0 or _skip_json_space(text, end) != text.length() or patches.is_empty(): return {}
	var parts := PackedStringArray()
	var cursor := 0
	for patch in patches:
		parts.append(text.substr(cursor, patch.start - cursor))
		parts.append("\\ufffd")
		cursor = patch.start + 6
	parts.append(text.substr(cursor))
	return {"text": "".join(parts), "patches": patches}

static func _verify_legacy_names(core: Dictionary, rows: Array, patches: Array) -> bool:
	for patch in patches:
		if patch.member_index >= core.members.size(): return false
		var member: Dictionary = core.members[patch.member_index]
		var full: Variant = null
		for row in rows:
			if row.id == member.id:
				if row.get("sourceBotId") == null or member.id != "merc_" + str(row.sourceBotId): return false
				full = row.get("name")
				break
		if not full is String or member.get("name") != patch.prefix + String.chr(0xfffd): return false
		var count := 0
		var prefix := ""
		var matched := false
		for index in full.length():
			var point: int = full.unicode_at(index)
			var units := 2 if point > 0xffff else 1
			if count + units > 100:
				matched = count == 99 and prefix == patch.prefix and (0xd800 + ((point - 0x10000) >> 10)) == patch.unit
				break
			count += units
			prefix += full[index]
		if not matched: return false
	return true

static func prepare_restore(text: Variant) -> Dictionary:
	if text == null: return {"ok": true, "missing": true, "expected_ids": [], "preserved": true}
	if not text is String or text.to_utf8_buffer().size() > MAX_BYTES: return _fail("save_size_or_type", true)
	var parser := JSON.new()
	var patches: Array = []
	if parser.parse(text) != OK:
		var compatibility := _legacy_name_buffer(text)
		if compatibility.is_empty() or parser.parse(compatibility.text) != OK: return _fail("invalid_json", true)
		patches = compatibility.patches
	var save: Variant = parser.data
	if not save is Dictionary or not _header(save.get("core")) or not save.get("rows") is Array: return _fail("unsupported_or_incomplete_save", true)
	var error := _json_error(save)
	if not error.is_empty(): return _fail(error, true)
	var selection := _member_rows(save.core, save.rows)
	if not selection.ok: return _fail(selection.error, true)
	for row in selection.rows:
		if row.has("body"): return _fail("runtime_body_field_in_save", true)
	if not patches.is_empty() and not _verify_legacy_names(save.core, selection.rows, patches): return _fail("uncorrelated_legacy_core_name", true)
	# JSON.parse created this graph exclusively for this call. No second deep
	# copy is needed, and no object from the caller's live state is referenced.
	var plan := {"ok": true, "missing": false, "core": save.core, "rows": selection.rows, "expected_ids": selection.expected_ids, "identities": selection.identities, "preserved": true}
	if not patches.is_empty():
		var ids: Array = []
		for patch in patches: ids.append(save.core.members[patch.member_index].id)
		plan.compatibility = {"kind": "source_core_name_terminal_utf16", "member_ids": ids, "replacement": "U+FFFD", "original_text_preserved": true}
	return plan

static func normalize_host_row(row: Dictionary, canonical_record: Dictionary, now_s: float, qa_enabled := false) -> Dictionary:
	# Called AFTER canonical core.restore succeeds in a staging core. No live bind.
	var result := row.duplicate(true)
	var weapon: Variant = canonical_record.get("weapon")
	var weapon_id: Variant = weapon.get("id") if weapon is Dictionary else null
	result.weapon = weapon_id if _truth(weapon_id) else row.get("weapon") if _truth(row.get("weapon")) else "pistol"
	result.id = row.id
	result.walkPhase = 0
	result.ang = 0
	result._nextShootAt = 0
	result._threatUntil = 0
	result._mercenaryBaseHp = row.get("baseHp") if _truth(row.get("baseHp")) else 80
	result._mercenaryHospital = canonical_record.get("status") == "hospital"
	var rescue: Variant = row.get("_mercenaryQaRescueUntil")
	result._mercenaryQaRescueUntil = minf(now_s + 600, maxf(0, float(rescue))) if qa_enabled and _finite(rescue) else 0.0
	var generation: Variant = row.get("_mercenaryLifeGeneration", 0)
	result._mercenaryLifeGeneration = generation if _finite(generation) and generation >= 0 and floorf(float(generation)) == generation else 0
	if row.get("_mercenaryVehicleExplosionFatal") == true:
		result.merge({"hp": 0, "dead": true, "deathConfirmed": true, "deadAt": _number(row.get("deadAt")), "_lifeState": "dead", "_mercenaryVehicleExplosionFatal": true}, true)
	return result
