extends RefCounted
## DSH_RESDIAG / DSH_MEDCHAIN: one resident's read-only head-up display and the
## cross-stage chain of the owner's hospital scenario.
##
## --city-resident-diag=1 (default 0) adds a Label3D over the resident's head with
## state, goal, distance, progress, per-step cost, the reason the resident stopped and
## the top-3 stop reasons of the run, plus HP percent and cash. --city-resident-hp=0
## keeps only the HP line. Everything is READ from the existing walk/life snapshots:
## this file owns no state of the simulation, builds no physics, grants no admission
## and writes no source row.
##
## --city-medical-threshold is what arms the chain lines: one line per stage of
##   hp < 50 % -> hospital goal -> walking -> door requested -> door open -> arrived.
const Focus29 = preload("res://scripts/npc_visual/npc_resident_focus29.gd")
const WALK_RADIUS := .738
const LABEL_HEIGHT := 2.35
const LOG_INTERVAL_MS := 2000
const SIMPLE_NAME28 := "Житель"
const SIMPLE_ACCENT28 := Color("7ee7a5") # Legacy 3D civilian identity, three_preview.js:3156.
const SIMPLE_AMBER28 := Color("ffc857")  # Source palette, new HP use at 25% < HP <= 50%.
const SIMPLE_RED28 := Color("ff5367")    # Source palette, new HP use at HP <= 25%.

static var _diag_flag: int = -1
static var _hp_flag: int = -1
static var _simple_vitals_flag: int = -1
static var _seen: Dictionary = {}       # source_id -> {frame, log_ms, travel_from, reasons, last_reason}
static var _lives: Dictionary = {}      # source_id -> WeakRef(the resident's life scheduler)

## DSH_MEDPRIORITY: the life scheduler of one resident, registered by the life itself at
## configuration time. The hit owner uses it to run the medical threshold check in the same
## frame as the hit (see npc_daily_life.dsh_notice_damage) instead of waiting for the daily
## poll slice. A miss simply means the immediate check does not run; the slice still does.
static func register_life(id: String, life: RefCounted) -> void:
	if id.is_empty() or not is_instance_valid(life): return
	_lives[id] = weakref(life)

static func life_of(id: String) -> RefCounted:
	if not _lives.has(id): return null
	var held: Variant = _lives[id]
	var current: Variant = (held as WeakRef).get_ref() if held is WeakRef else null
	if is_instance_valid(current): return current
	_lives.erase(id)
	return null
static var _labels: Dictionary = {}     # source_id -> WeakRef(Label3D)
static var _stages: Dictionary = {}     # source_id -> {stage, goal_id, hp_pct_at_damage}

static func _arg(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

static func diag_on() -> bool:
	if _diag_flag < 0: _diag_flag = 1 if _arg("--city-resident-diag=") == "1" else 0
	return _diag_flag == 1

static func hp_label_on() -> bool:
	if simple_vitals_on(): return true
	# The HP line is what the owner asked for first: it is on with the diagnostics and
	# can also stand alone. --city-resident-hp=0 removes it in both cases.
	if _hp_flag < 0:
		_hp_flag = 1
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-resident-hp="):
				_hp_flag = 1 if int(argument.trim_prefix("--city-resident-hp=")) != 0 else 0
	return _hp_flag == 1

static func simple_vitals_on() -> bool:
	if _simple_vitals_flag < 0:
		_simple_vitals_flag = 1 if int(_arg("--city-simple-hospital=")) != 0 else 0
	return _simple_vitals_flag == 1

## One compact 5-line label. Missing values are shown as "-", never invented.
## DSH_RESDIAG: the caption belongs to the resident the owner named, exactly like the name
## label: without --city-resident-name there is no caption at all, and no resident the owner
## did not pick gets one.
static func caption_allowed(body: Node3D) -> bool:
	if not is_instance_valid(body): return false
	if simple_vitals_on() and str(body.get_meta("source_id", "")) == "resident_1": return true
	if body.has_meta("dsh_test_resident_name"): return true
	var parent: Node = body.get_parent()
	return parent != null and parent is Node3D and (parent as Node3D).has_meta("dsh_test_resident_name")

## DSH_RESDIAG: refresh the caption of one resident from the values it already published.
## The hit owner calls this the moment a shot changes `hp`, so the label does not wait for
## that resident's turn in the daily poll slice (measured poll period ~1.6 s).
static func refresh_after_hit(body: Node3D, name: String, row: Dictionary) -> void:
	if not hp_label_on() and not diag_on(): return
	if not is_instance_valid(body) or not caption_allowed(body): return
	var label := _label_for(body, true)
	if label == null: return
	if simple_vitals_on():
		var current: Dictionary = _simple_current_row28(body, row)
		_paint_simple_vitals(label, current)
		Focus29.update_visibility(body, label, current)
		print("DSH_LABEL id=", str(current.get("source_id", "?")), " node=", label.name, " text=Житель hp=", current.get("hp", -1), "/", current.get("max_hp", -1), " reason=hit")
		return
	var maximum := float(row.get("max_hp", 0))
	var pct := 0.0
	if maximum > 0.0: pct = clampf(float(row.get("hp", 0)) / maximum * 100.0, 0.0, 100.0)
	label.text = "%s\nHP %.0f%%" % [name, pct]
	print("DSH_LABEL id=", str(row.get("source_id", "?")), " node=", label.name, " text=\"", label.text.replace("\n", " | "), "\" reason=hit")

## DSH_RESDIAG: `name` on its own line and `HP NN%  ⚡ NN%` under it, exactly as the owner
## asked. `⚡` becomes `EN` when the font may not carry the emoji: --city-energy-glyph=EN.
static func _vitals_line(row: Dictionary, life_state: Dictionary) -> String:
	var maximum := float(row.get("max_hp", 0))
	var pct := 0.0
	if maximum > 0.0: pct = clampf(float(row.get("hp", 0)) / maximum * 100.0, 0.0, 100.0)
	var text := "HP %.0f%%" % pct
	if life_state.get("energy_on", false):
		text += "  %s %.0f%%" % [_energy_glyph(), clampf(float(life_state.get("energy", 0.0)), 0.0, 100.0)]
	return text

static func _energy_glyph() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--city-energy-glyph="): return argument.trim_prefix("--city-energy-glyph=")
	return "⚡"

static func label_text(name: String, row: Dictionary, life_state: Dictionary, walk: Dictionary, reasons: String, stopped: String, travelled: float) -> String:
	if simple_vitals_on(): return "Житель"
	var maximum := float(row.get("max_hp", 0))
	var pct := 0.0
	if maximum > 0.0: pct = clampf(float(row.get("hp", 0)) / maximum * 100.0, 0.0, 100.0)
	var cash := int(row.get("cash", 0))
	var bank := int(row.get("bank", 0))
	var phase := str(life_state.get("phase", "-"))
	var goal := str(life_state.get("goal_kind", "-"))
	var distance := float(life_state.get("distance_m", -1.0))
	var seconds := float(life_state.get("state_seconds", -1.0))
	var lines: Array[String] = []
	lines.append(name)
	lines.append(_vitals_line(row, life_state))
	if not diag_on(): return "\n".join(lines)
	lines.append("%s→%s · %.0fм · %.1fс · %dр (банк %d)" % [phase, goal, distance, seconds, cash, bank])
	lines.append("leg %d/%d · шаг %dмкс · пересчётов %d · прошёл %.0fм" % [
		int(walk.get("leg", 0)) + 1, maxi(1, int(walk.get("legs", 1))),
		int(walk.get("native_query_wall_us", 0)), int(walk.get("fresh_replans", 0)), travelled])
	if life_state.get("energy_on", false): lines.append("очередь %s" % str(life_state.get("queue", [])))
	lines.append("СТОП: %s" % ("-" if stopped.is_empty() else stopped))
	lines.append("обходы %d/%d · ждёт путь %.1fс · %s" % [
		int(walk.get("detour_count", 0)), int(walk.get("detour_limit", 0)),
		float(walk.get("admission_wait_s", 0.0)), reasons])
	return "\n".join(lines)

static func _label_for(body: Node3D, create: bool) -> Label3D:
	if simple_vitals_on(): return _simple_label_for(body, create)
	var id := str(body.get_instance_id())
	if _labels.has(id):
		var held: Variant = _labels[id]
		var current: Variant = (held as WeakRef).get_ref() if held is WeakRef else null
		if is_instance_valid(current): return current
	# The name label DSH_TESTRESIDENT adds is a child of the resident's visual motion
	# node, and the body's own parent is that same motion node. When it exists it IS the
	# head-up caption: the name, HP and energy are written into that one node.
	var parent: Node = body.get_parent()
	if parent == null or not parent is Node3D:
		if not create: return null
		parent = body
	var named: Node = parent.get_node_or_null("DshResidentName")
	if named is Label3D:
		_labels[id] = weakref(named)
		return named as Label3D
	if not create: return null
	var label := Label3D.new()
	label.name = "DshResidentDiag"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.no_depth_test = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.pixel_size = .0032
	label.font_size = 48
	label.modulate = Color(1, 1, 1, 1)
	label.outline_modulate = Color(0, 0, 0, 1)
	label.outline_size = 12
	label.position = Vector3(0, LABEL_HEIGHT, 0)
	(parent as Node3D).add_child(label)
	_labels[id] = weakref(label)
	return label

## The actual host hierarchy is body/ResidentVisualMotion/DshResidentName.
## Keep the label on this actor and retire the old label script's 0.25s writer.
static func _simple_label_for(body: Node3D, create: bool) -> Label3D:
	if not is_instance_valid(body) or not caption_allowed(body): return null
	var id := str(body.get_instance_id())
	if _labels.has(id):
		var held: Variant = _labels[id]
		var current: Variant = held.get_ref() if held is WeakRef else null
		if is_instance_valid(current) and current is Label3D and body.is_ancestor_of(current): return current
		if is_instance_valid(current) and current is Label3D: current.visible = false
		_labels.erase(id)
	var named: Node = body.get_node_or_null("ResidentVisualMotion/DshResidentName")
	if named == null: named = body.find_child("DshResidentName", true, false)
	var label: Label3D = named as Label3D
	if label == null:
		if not create: return null
		label = Label3D.new()
		label.name = "DshResidentName"
		body.add_child(label)
		label.position = Vector3(0, LABEL_HEIGHT, 0)
	# npc_test_resident_bar.gd previously overwrote this same Label3D every0.25s.
	# The current health owner already calls this module on damage and every frame.
	label.set_process(false)
	label.set_physics_process(false)
	label.text = "Житель"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.no_depth_test = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.pixel_size = .0045
	label.font_size = 48
	label.modulate = SIMPLE_ACCENT28
	label.outline_modulate = Color.BLACK
	label.outline_size = 8
	label.render_priority = 0
	label.visible = false
	label.set_meta("npc_vitals28_owner", "current_health_row")
	body.set_meta("dsh_test_resident_name", "Житель")
	_labels[id] = weakref(label)
	return label

## Read the current owner row, not a saved injury override or UI snapshot. The
## matching body token prevents a registered previous generation from painting
## this actor. Both the hit callback and ordinary/heal update enter this path.
static func _simple_current_row28(body: Node3D, fallback: Dictionary) -> Dictionary:
	var id: String = str(body.get_meta("source_id", fallback.get("source_id", "")))
	var life: RefCounted = life_of(id)
	if is_instance_valid(life) and life.has_method("_life"):
		var token: Variant = life.get("_token")
		if token is Dictionary and token.get("body") == body:
			var current: Variant = life.call("_life")
			if current is Dictionary and not current.is_empty(): return current
	return fallback

static func _paint_simple_vitals(label: Label3D, row: Dictionary) -> void:
	label.text = SIMPLE_NAME28
	# Reassert the single caption owner even when a cached label is reused.
	label.set_process(false)
	label.set_physics_process(false)
	# Defensive cleanup also handles a live caption created by the older proposal.
	var retired_bar: Node = label.get_node_or_null("WalkHpBar28")
	if is_instance_valid(retired_bar):
		if retired_bar is Node3D: retired_bar.visible = false
		if not retired_bar.is_queued_for_deletion(): retired_bar.queue_free()
	var maximum: float = float(row.get("max_hp", 0.0))
	var raw_hp: float = float(row.get("hp", 0.0))
	var known: bool = is_finite(maximum) and maximum > 0.0 and is_finite(raw_hp)
	var hp: float = clampf(raw_hp, 0.0, maximum) if known else 0.0
	var ratio: float = clampf(hp / maximum, 0.0, 1.0) if known else 0.0
	if bool(row.get("dead", false)): ratio = 0.0
	var colour: Color = SIMPLE_ACCENT28 if ratio > .5 else (SIMPLE_AMBER28 if ratio > .25 else SIMPLE_RED28)
	if not known: colour = Color.WHITE
	# Never gate the actual paint on a key/frame: treatment changes HP in this same
	# physics step, and the refreshed row must restore green before the exit starts.
	label.modulate = colour
	Focus29.paint(label, hp, maximum, known, ratio)
	var key: String = "legacy3d_name:%s:%s:%s:%s" % [str(hp), str(maximum), str(known), str(row.get("dead", false))]
	if str(label.get_meta("npc_vitals28_key", "")) != key:
		label.set_meta("npc_vitals28_key", key)
		print("NPC_VITALS28 id=", str(row.get("source_id", "?")), " hp=", hp, "/", maximum,
			" ratio=", ratio, " colour=", colour.to_html(false), " frame=", Engine.get_physics_frames())
	label.set_meta("hp", hp)
	label.set_meta("max_hp", maximum)
	label.set_meta("hp_ratio", ratio)
	label.set_meta("hp_known", known)
	label.set_meta("npc_vitals28_style", "legacy3d_card_hp_name_colour_no_bars")

## The single entry point, called from the life's own step() so it adds no node, no
## timer and no keep-alive of its own.
static func update(id: String, body: Variant, row: Dictionary, life_state: Dictionary, walk: Dictionary, name: String) -> void:
	if not diag_on() and not hp_label_on(): return
	if not is_instance_valid(body) or not body is Node3D: return
	var now_frame := Engine.get_physics_frames()
	var record: Dictionary = _seen.get(id, {})
	# DSH_RESDIAG (owner's rule): the caption is repainted on EVERY call - no frame gate, no
	# throttle, no cache. Writing a Label3D text is cheap, and any gate here shows up as a
	# visible lag between the shot and the number over the head. The only thing still
	# rate-limited is the log line below (a log must not cost frames), while the on-hit
	# repaint in refresh_after_hit() prints its own DSH_LABEL in the very hit frame.
	var now_ms := Time.get_ticks_msec()
	var travelled := 0.0
	var here: Vector3 = (body as Node3D).global_position
	if not record.is_empty():
		var from: Variant = record.get("travel_from")
		if from is Vector3: travelled = Vector2(here.x - (from as Vector3).x, here.z - (from as Vector3).z).length()
	if travelled <= 0.0 and not record.is_empty() and record.has("start_pos"):
		var start: Variant = record.get("start_pos")
		if start is Vector3: travelled = Vector2(here.x - (start as Vector3).x, here.z - (start as Vector3).z).length()
	var label := _label_for(body as Node3D, true)
	if label != null and not caption_allowed(body as Node3D):
		# DSH_RESDIAG: before the owner's own name label exists (or for a resident he did not
		# name), this module keeps its label out of the way instead of putting a second,
		# floating caption over every resident.
		label.visible = false
	if label != null and simple_vitals_on():
		Focus29.update_visibility(body as Node3D, label, _simple_current_row28(body as Node3D, row))
	var shown_label := label != null and label.visible
	if shown_label:
		# DSH_RESDIAG: the name label and this one are the SAME text node. `_label_for`
		# prefers the Label3D named DshResidentName that preview_resident_host.gd already
		# attaches to the visual motion node, so there is exactly one head-up caption and
		# no second, floating label.
		if simple_vitals_on(): _paint_simple_vitals(label, _simple_current_row28(body as Node3D, row))
		else: label.text = label_text(name, row, life_state, walk, _top_reasons(record), str(record.get("last_reason", "")), travelled)
	record["frame"] = now_frame
	record["start_pos"] = record.get("start_pos", here)
	if int(record.get("log_ms", 0)) == 0 or now_ms - int(record.get("log_ms", 0)) >= LOG_INTERVAL_MS:
		record["log_ms"] = now_ms
		# DSH_LABEL: the exact text the owner sees over the head, one line per interval,
		# with the node it was written into. The caption is the name label already hanging
		# on the resident's visual node when one exists, and only otherwise a new Label3D.
		var where := "none"
		if label != null:
			var label_parent: Node = label.get_parent()
			where = label.name + "@" + (str(label_parent.get_path()) if label_parent != null else "-") + "/" + str(label_parent.get_parent().name if label_parent != null and label_parent.get_parent() != null else "-") + ":y=%.2f:in_tree=%s" % [label.position.y, str(label.is_inside_tree())]
		print("DSH_LABEL id=", id, " node=", where, " text=\"", label_text(name, row, life_state, walk, _top_reasons(record), str(record.get("last_reason", "")), travelled).replace("\n", " | "), "\"")
		if diag_on():
			print("DSH_RESDIAG id=", id, " name=\"", name, "\" hp=", int(row.get("hp", -1)), "/", int(row.get("max_hp", -1)),
				" energy=", "%.0f" % float(life_state.get("energy", -1.0)),
				" phase=", str(life_state.get("phase", "-")), " goal=", str(life_state.get("goal_kind", "-")),
				" dist_m=", "%.1f" % float(life_state.get("distance_m", -1.0)), " walked_m=", "%.1f" % travelled,
				" leg=", int(walk.get("leg", 0)) + 1, "/", maxi(1, int(walk.get("legs", 1))),
				" native_us=", int(walk.get("native_query_wall_us", 0)), " replans=", int(walk.get("fresh_replans", 0)),
				" path_adm=", str(walk.get("path_admission", "-")), " wait_s=", "%.2f" % float(walk.get("admission_wait_s", 0.0)),
				" stop=", str(record.get("last_reason", "-")), " top=", _top_reasons(record))
	_seen[id] = record

static func _top_reasons(record: Dictionary) -> String:
	var counts: Dictionary = record.get("reasons", {})
	if counts.is_empty(): return "нет"
	var pairs: Array = []
	for key: Variant in counts: pairs.append([str(key), int(counts[key])])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var text := ""
	for index in mini(3, pairs.size()):
		if index > 0: text += ", "
		text += "%s ×%d" % [str(pairs[index][0]), int(pairs[index][1])]
	return text

## The stopped reason of the walk is counted once per change, so the label can show the
## top-3 reasons of the whole run without any per-frame bookkeeping.
static func count_reason(id: String, reason: String) -> void:
	if reason.is_empty(): return
	var record: Dictionary = _seen.get(id, {})
	if str(record.get("last_reason", "")) == reason: return
	var counts: Dictionary = record.get("reasons", {})
	counts[reason] = int(counts.get(reason, 0)) + 1
	record["reasons"] = counts
	record["last_reason"] = reason
	_seen[id] = record

# --------------------------------------------------------------------------- #
# DSH_MEDCHAIN: one line per stage of the owner's scenario. It reuses the shipped
# markers (the goal, the visit status, the door claim of the site, the marker point)
# and prints a change only when one of them moves.
# --------------------------------------------------------------------------- #
static func chain_on() -> bool:
	return true  # the caller already gated this on --city-medical-threshold

static func chain(id: String, stage: String, row: Dictionary, marker: Variant, body: Variant, detail: String, effective_pct: float = -1.0) -> void:
	var state: Dictionary = _stages.get(id, {})
	if str(state.get("stage", "")) == stage: return
	state["stage"] = stage
	_stages[id] = state
	var maximum := float(row.get("max_hp", 0))
	var pct := -1.0
	if maximum > 0.0: pct = float(row.get("hp", 0)) / maximum * 100.0
	var text := "DSH_MEDCHAIN id=" + id + " hp_pct=%.1f" % pct
	# DSH_MEDCHAIN: hp_pct is the row's own value, hp_effective_pct is what the medical
	# decision used. They differ only while --city-hp is the source of the wound.
	if effective_pct >= 0.0: text += " hp_effective_pct=%.1f" % effective_pct
	text += " stage=" + stage
	if marker is Vector3:
		var at: Vector3 = marker
		text += " marker=(%.2f,%.2f,%.2f)" % [at.x, at.y, at.z]
		if is_instance_valid(body) and body is Node3D:
			var here: Vector3 = (body as Node3D).global_position
			text += " dist_m=%.1f" % Vector2(here.x - at.x, here.z - at.z).length()
	text += " frame=" + str(Engine.get_physics_frames())
	if not detail.is_empty(): text += " detail=" + detail
	print(text)

## DSH_MEDCHAIN: the stage a visit status means. Read-only mapping, no new state.
static func visit_stage(status: String, door_owned: bool, door_fraction: float) -> String:
	match status:
		"WALKING_TO_STREET": return "walking"
		"WALKING_ONTO_APPROACH", "WALKING_TO_DOOR": return "walking_to_door"
		"OPENING", "CANCEL_OPENING": return "door_requested"
		"WALKING_TO_THRESHOLD": return "door_open" if door_fraction >= 1.0 else "walking_through_door"
		"WALKING_INSIDE", "WALKING_TO_SERVICE": return "inside"
		"TREATING": return "arrived"
		"EXITING_TO_THRESHOLD", "EXITING_TO_DOOR", "RETURNING_TO_STREET", "RETURNING_TO_HANDOFF": return "leaving"
		"COMPLETE": return "complete"
		"CANCELLED", "BLOCKED", "HOLD", "FAILED", "STALE": return "blocked:" + status
	return ""
