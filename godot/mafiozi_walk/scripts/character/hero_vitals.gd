extends RefCounted
## Session-local health and blood loss. Only accepted damage producers call this;
## the cosmetic blood pool never creates damage or wounds.

const MAX_HP := 100.0
## The cosmetic blood pool also keeps at most four active sources per host.
const MAX_WOUNDS := 4
const BLEED_TICK := 0.1
const MAX_BLEED_HP_PER_SECOND := 6.0
const GROUPS := ["head", "chest", "pelvis", "arm_l", "arm_r", "leg_l", "leg_r"]
const SEGMENTS := ["head", "chest", "pelvis", "upperarm_l", "upperarm_r",
	"forearm_l", "forearm_r", "hand_l", "hand_r", "thigh_l", "thigh_r",
	"shin_l", "shin_r", "foot_l", "foot_r"]
const LABELS := {"head": "голова", "chest": "грудь", "pelvis": "живот",
	"arm_l": "левая рука", "arm_r": "правая рука",
	"leg_l": "левая нога", "leg_r": "правая нога"}
const SEGMENT_LABELS := {"head": "голова", "chest": "грудь", "pelvis": "таз",
	"upperarm_l": "левая рука от плеча", "upperarm_r": "правая рука от плеча",
	"forearm_l": "левое предплечье", "forearm_r": "правое предплечье",
	"hand_l": "левая кисть", "hand_r": "правая кисть",
	"thigh_l": "левая нога от бедра", "thigh_r": "правая нога от бедра",
	"shin_l": "левая голень", "shin_r": "правая голень",
	"foot_l": "левая стопа", "foot_r": "правая стопа"}

var hp := MAX_HP
var _scene: Node
var _hud: CanvasLayer
var _wounds: Array[Dictionary] = []
var _parts: Dictionary = {}
var _segments: Dictionary = {}
var _severed: Dictionary = {}
var _disabled: Dictionary = {}
var _body_split := false
var _clock := 0.0
var _burn_until := 0.0
var _tick_accum := 0.0
var _bleed_rate := 0.0
var _revision := 0

func configure(scene: Node, hud: CanvasLayer) -> void:
	_scene = scene
	_hud = hud
	reset()

func reset() -> void:
	hp = MAX_HP
	_wounds.clear()
	_severed.clear()
	_disabled.clear()
	_parts.clear()
	_segments.clear()
	for group: String in GROUPS:
		_parts[group] = {"health": 1.0, "severed": false, "bleeding": false}
	for segment: String in SEGMENTS:
		_segments[segment] = {"health": 1.0, "severed": false,
			"disabled": false, "bleeding": false}
	_body_split = false
	_clock = 0.0
	_burn_until = 0.0
	_tick_accum = 0.0
	_bleed_rate = 0.0
	_revision += 1
	_refresh()

func mark_dead() -> void:
	if hp <= 0.0: return
	hp = 0.0
	_burn_until = 0.0
	_revision += 1
	_sync_legacy_health()
	_refresh()

func _segment(part: String) -> String:
	if part in ["head", "neck"]: return "head"
	if part in ["chest", "spine_01", "spine_02"]: return "chest"
	if part == "pelvis": return "pelvis"
	var base := part.trim_suffix("_l").trim_suffix("_r")
	if base not in ["upperarm", "forearm", "hand", "thigh", "shin", "foot"]:
		return "chest"
	# Imported player bones are mirrored relative to the visible body.
	var side := "_r" if part.ends_with("_l") else "_l" if part.ends_with("_r") else ""
	return base + side if side != "" else "chest"

func _group(part: String) -> String:
	if part in GROUPS: return part
	var segment := _segment(part)
	if segment.begins_with("upperarm") or segment.begins_with("forearm") or segment.begins_with("hand"):
		return "arm" + segment.substr(segment.length() - 2)
	if segment.begins_with("thigh") or segment.begins_with("shin") or segment.begins_with("foot"):
		return "leg" + segment.substr(segment.length() - 2)
	return segment

func apply_damage(amount: float, part: String, kind: String = "blunt", penetrates: bool = false) -> Dictionary:
	if not is_finite(amount) or amount <= 0.0 or hp <= 0.0:
		return {"applied": false, "hp": hp}
	var before := hp
	hp = maxf(0.0, hp - amount)
	var group := _group(part)
	var segment := _segment(part)
	var segment_row: Dictionary = _segments[segment]
	segment_row.health = maxf(0.0, float(segment_row.health) - amount / MAX_HP)
	_segments[segment] = segment_row
	if kind in ["slice", "stab"] and penetrates and amount >= 2.0:
		_add_wound(group, segment, amount, kind)
	else:
		var row: Dictionary = _parts[group]
		row.health = maxf(0.0, float(row.health) - amount / MAX_HP)
		_parts[group] = row
	_revision += 1
	_sync_legacy_health()
	_refresh()
	return {"applied": true, "before": before, "hp": hp, "group": group}

func _add_wound(group: String, segment: String, amount: float, kind: String) -> void:
	# The skin drip lasts eight seconds; severe cuts bleed faster throughout it.
	var severity := clampf(amount / 30.0, 0.08, 1.0)
	var rate := (0.12 + severity * 1.0) * (0.72 if kind == "stab" else 1.0)
	if _wounds.size() >= MAX_WOUNDS:
		var weakest := 0
		for index: int in range(1, _wounds.size()):
			if float(_wounds[index].severity) < float(_wounds[weakest].severity): weakest = index
		if severity <= float(_wounds[weakest].severity) + 0.05: return
		_wounds.remove_at(weakest)
	_wounds.append({"group": group, "segment": segment, "rate": rate, "remaining": 8.0,
		"severity": severity})
	_recompute_bleed()

func sync_body(part_hp: Dictionary, severed: Dictionary, maxima: Dictionary,
		disabled: Dictionary = {}, mesh_cuts: Dictionary = {}) -> void:
	var changed := false
	for key: Variant in part_hp:
		var part := str(key)
		var group := _group(part)
		var segment := _segment(part)
		var base := part.trim_suffix("_l").trim_suffix("_r")
		var maximum := float(maxima.get(base, 1.0))
		var ratio := clampf(float(part_hp[key]) / maxf(1.0, maximum), 0.0, 1.0)
		var segment_row: Dictionary = _segments[segment]
		if ratio < float(segment_row.health):
			segment_row.health = ratio
			_segments[segment] = segment_row
			changed = true
		var row: Dictionary = _parts[group]
		if ratio < float(row.health):
			row.health = ratio
			_parts[group] = row
			changed = true
	for key: Variant in severed:
		var part := str(key)
		if _severed.has(part): continue
		_severed[part] = true
		var group := _group(part)
		var segment := _segment(part)
		var base := part.trim_suffix("_l").trim_suffix("_r")
		var affected := [segment]
		var side := segment.substr(segment.length() - 2) if segment.ends_with("_l") or segment.ends_with("_r") else ""
		if base == "upperarm": affected.append_array(["forearm" + side, "hand" + side])
		elif base == "forearm": affected.append("hand" + side)
		elif base == "thigh": affected.append_array(["shin" + side, "foot" + side])
		elif base == "shin": affected.append("foot" + side)
		for missing: String in affected:
			var missing_row: Dictionary = _segments[missing]
			missing_row.severed = true
			missing_row.health = 0.0
			_segments[missing] = missing_row
		var row: Dictionary = _parts[group]
		if base in ["head", "upperarm", "thigh"]: row.severed = true
		row.health = minf(float(row.health), 0.15)
		_parts[group] = row
		# A committed stump has its own finite blood source.
		if group != "head":
			if _wounds.size() >= MAX_WOUNDS:
				var weakest := 0
				for index: int in range(1, _wounds.size()):
					if float(_wounds[index].severity) < float(_wounds[weakest].severity): weakest = index
				_wounds.remove_at(weakest)
			_wounds.append({"group": group, "segment": segment, "rate": 1.45, "remaining": 12.0,
				"severity": 1.0})
		changed = true
	for key: Variant in disabled:
		var part := str(key)
		if _disabled.has(part): continue
		_disabled[part] = true
		var segment := _segment(part)
		var segment_row: Dictionary = _segments[segment]
		segment_row.disabled = true
		_segments[segment] = segment_row
		changed = true
	if not _body_split and ((severed.has("chest") and bool(mesh_cuts.get("chest", false))) \
			or (severed.has("pelvis") and bool(mesh_cuts.get("pelvis", false)))):
		_body_split = true
		changed = true
	if changed:
		_recompute_bleed()
		_revision += 1
		_refresh()

func step(delta: float) -> void:
	if hp <= 0.0 or not is_finite(delta) or delta <= 0.0:
		return
	_clock += delta
	if _burn_until > 0.0 and _clock >= _burn_until:
		_burn_until = 0.0
		_revision += 1
		_refresh()
	if _wounds.is_empty(): return
	_tick_accum += minf(delta, 0.25)
	if _tick_accum < BLEED_TICK: return
	var elapsed := _tick_accum
	_tick_accum = 0.0
	for index: int in range(_wounds.size() - 1, -1, -1):
		_wounds[index].remaining = float(_wounds[index].remaining) - elapsed
		if float(_wounds[index].remaining) <= 0.0:
			_wounds.remove_at(index)
	_recompute_bleed()
	if _bleed_rate > 0.0:
		hp = maxf(0.0, hp - _bleed_rate * elapsed)
	_sync_legacy_health()
	_revision += 1
	_refresh()
	if hp <= 0.0 and is_instance_valid(_scene) and _scene.has_method("hero_bleedout"):
		_scene.call("hero_bleedout")

func _recompute_bleed() -> void:
	_bleed_rate = 0.0
	for wound: Dictionary in _wounds:
		_bleed_rate += float(wound.rate)
	_bleed_rate = minf(MAX_BLEED_HP_PER_SECOND, _bleed_rate)
	for group: String in GROUPS:
		var row: Dictionary = _parts[group]
		row.bleeding = false
		_parts[group] = row
	for segment: String in SEGMENTS:
		var segment_row: Dictionary = _segments[segment]
		segment_row.bleeding = false
		_segments[segment] = segment_row
	for wound: Dictionary in _wounds:
		var row: Dictionary = _parts[str(wound.group)]
		row.bleeding = true
		_parts[str(wound.group)] = row
		var segment: String = str(wound.segment)
		var segment_row: Dictionary = _segments[segment]
		segment_row.bleeding = true
		_segments[segment] = segment_row

func note_burning(seconds: float) -> void:
	if hp <= 0.0 or not is_finite(seconds) or seconds <= 0.0: return
	var was_burning := _burn_until > _clock
	_burn_until = maxf(_burn_until, _clock + minf(seconds, 2.0))
	if not was_burning:
		_revision += 1
		_refresh()

func _severed_labels() -> Array[String]:
	var result: Array[String] = []
	if _severed.has("head"): result.append("голова")
	for side: String in ["_l", "_r"]:
		var raw_side := "_r" if side == "_l" else "_l"
		for base: String in ["upperarm", "forearm", "hand"]:
			if _severed.has(base + raw_side):
				result.append(str(SEGMENT_LABELS[base + side]))
				break
		for base: String in ["thigh", "shin", "foot"]:
			if _severed.has(base + raw_side):
				result.append(str(SEGMENT_LABELS[base + side]))
				break
	return result

func snapshot() -> Dictionary:
	var sites: Array[String] = []
	for group: String in GROUPS:
		if bool((_parts[group] as Dictionary).bleeding):
			sites.append(str(LABELS[group]))
	return {"hp": hp, "max_hp": MAX_HP, "parts": _parts.duplicate(true),
		"segments": _segments.duplicate(true), "severed_labels": _severed_labels(),
		"body_split": _body_split, "burning": _burn_until > _clock,
		"bleed_percent": roundi(_bleed_rate / MAX_BLEED_HP_PER_SECOND * 100.0),
		"bleed_hp_per_second": _bleed_rate, "bleed_sites": sites,
		"wound_count": _wounds.size(), "severed": _severed.keys(), "revision": _revision}

func _sync_legacy_health() -> void:
	if not is_instance_valid(_scene): return
	var sword: Object = _scene.get("preview_sword_prototype")
	if is_instance_valid(sword): sword.set("_sparring_hp", hp)
	var player: Node = _scene.get("_player")
	if is_instance_valid(player) and player.has_meta("local_contact_health_owner"):
		var owner: Object = instance_from_id(int(player.get_meta("local_contact_health_owner")))
		if is_instance_valid(owner):
			owner.set("_hp", ceili(hp))
			owner.call("_refresh")
	var balloon: Object = _scene.get("preview_balloon")
	if is_instance_valid(balloon): balloon.set("player_hp", ceili(hp))

func _refresh() -> void:
	if is_instance_valid(_hud):
		_hud.call("render_state", snapshot())
