extends Node
## DSH_OBSERVE58: in-game resident badges and an optional camera tour.
##
##   --city-observe-npcs=1  numbers above every resident (no camera change)
##   --city-observe-npcs=2  badges + manual tour: O toggles the view, [ and ] switch
##   --city-observe-npcs=3  badges + automatic tour every AUTO_SECONDS
##
## The badge number is taken from the resident id, so "7" always means resident_7 even
## when the catalogue skips a number. Resident trees are never touched (no child node is
## added to a body or a rig) - the badges are projected onto one 2D layer, and the player
## body is never moved, so every resident keeps behaving exactly as in normal play.
## Nothing here writes a resident, its HP, its route, its claims or its time.
const META := "npc_observe58"
const AUTO_SECONDS := 4.0
const CAMERA_BACK_M := 4.6
const CAMERA_UP_M := 2.4
const LOOK_UP_M := 1.1
const BADGE_HEIGHT_M := 2.15
const BADGE_MAX_M := 140.0
const STILL_STEP_M := 0.10
const STILL_WARN_S := 6.0
const STILL_BAD_S := 12.0
const FONT_SIZE := 19
const LABEL_LAYER := 19
var _scene: Node3D
var _player: Node
var _population: RefCounted
var _camera: Camera3D
var _layer: CanvasLayer
var _badges: Node2D
var _label: Label
var _ids: Array[String] = []
var _index := 0
var _enabled := false
var _badges_on := true
var _auto := false
var _auto_at := 0.0
var _switches := 0
var _tick := 0
var _last_count := -1
var _still: Dictionary = {}
var _worst := {"id": "", "still_s": 0.0}


func configure(scene: Node3D, player: Node, population: RefCounted, mode: int) -> bool:
	if _scene != null or not is_instance_valid(scene) or not is_instance_valid(player):
		return false
	_scene = scene
	_player = player
	_population = population
	_badges_on = mode >= 1
	_auto = mode >= 3
	_layer = CanvasLayer.new()
	_layer.name = "NpcObserve58Layer"
	_layer.layer = LABEL_LAYER
	_scene.add_child(_layer)
	_badges = Node2D.new()
	_badges.name = "NpcObserve58Badges"
	_layer.add_child(_badges)
	_camera = Camera3D.new()
	_camera.name = "NpcObserve58Camera"
	_camera.fov = 55.0
	_camera.near = 0.08
	_camera.far = 1200.0
	_camera.current = false
	_scene.add_child(_camera)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 5)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 74.0
	_label.visible = false
	_layer.add_child(_label)
	_scene.set_meta(META, self)
	_refresh_ids()
	if _auto:
		_set_enabled(true)
	print("DSH_OBSERVE58 stage=ready mode=", mode, " badges=", _badges_on,
		" auto=", _auto, " residents=", _ids.size(), " ids=", ",".join(_ids))
	return true


func dispose() -> void:
	_set_enabled(false)
	if is_instance_valid(_layer):
		_layer.queue_free()
	if is_instance_valid(_camera):
		_camera.queue_free()
	_layer = null
	_badges = null
	_camera = null
	_label = null
	_scene = null
	_player = null
	_population = null


func _exit_tree() -> void:
	if _scene != null and is_instance_valid(_scene) and _scene.get_meta(META, null) == self:
		_scene.remove_meta(META)
	_scene = null


func report() -> Dictionary:
	return {"badges": _badges_on, "auto": _auto, "camera_tour": _enabled, "residents": _ids.size(),
		"index": _index, "switches": _switches, "worst_still": _worst.duplicate(),
		"player_moved": false, "resident_trees_touched": false}


func still_report() -> Dictionary:
	return _worst.duplicate()


func _population_with_lives() -> RefCounted:
	# The city population is owned by the scene's CityBootstrap node when the preview
	# population path is disabled, so the owner is resolved lazily instead of assumed.
	# The scene holds tens of thousands of nodes, so this fallback search is throttled
	# hard: it must never run per frame and never per resident.
	if _population != null and is_instance_valid(_population) and _population.get("daily") != null:
		return _population
	if _scene == null or not is_instance_valid(_scene):
		return null
	if _tick % 120 != 0:
		return _population
	for node: Node in _scene.find_children("*", "", true, false):
		var candidate: Variant = node.get("population")
		if candidate is RefCounted and candidate.get("daily") != null:
			_population = candidate
			print("DSH_OBSERVE58 stage=owner node=", node.name, " daily=true")
			return candidate
	return _population


func _lives() -> Dictionary:
	var owner: RefCounted = _population_with_lives()
	if owner == null:
		return {}
	var daily: Variant = owner.get("daily")
	if daily == null:
		return {}
	var lives: Variant = daily.get("_lives")
	return lives if lives is Dictionary else {}


func _refresh_ids() -> void:
	var lives: Dictionary = _lives()
	_last_count = lives.size()
	var next: Array[String] = []
	for id: String in lives:
		next.append(id)
	next.sort()
	if next != _ids:
		var appeared: bool = _ids.is_empty() and not next.is_empty()
		_ids = next
		if _index >= _ids.size():
			_index = 0
		if appeared:
			print("DSH_OBSERVE58 stage=cohort residents=", _ids.size(), " ids=", ",".join(_ids))


func _target_id() -> String:
	if _ids.is_empty():
		return ""
	return _ids[clampi(_index, 0, _ids.size() - 1)]


func _body_of(id: String) -> CharacterBody3D:
	var lives: Dictionary = _lives()
	if not lives.has(id):
		return null
	var life: RefCounted = lives[id]
	if life == null or not is_instance_valid(life) or bool(life.get("_disposed")):
		return null
	var body: Variant = life._token.get("body")
	return body if is_instance_valid(body) and body is CharacterBody3D else null


func _set_enabled(value: bool) -> void:
	if _enabled == value:
		return
	_enabled = value
	if _label != null:
		_label.visible = value
	if value:
		_refresh_ids()
		if _ids.is_empty() or not is_instance_valid(_camera):
			_enabled = false
			if _label != null:
				_label.visible = false
			return
		_camera.make_current()
		_auto_at = 0.0
		_advance(0)
	else:
		if is_instance_valid(_player) and _player.has_method("get_preview_camera"):
			var preview: Variant = _player.get_preview_camera()
			if is_instance_valid(preview):
				preview.make_current()
		print("DSH_OBSERVE58 stage=camera_off switches=", _switches)


func _advance(step: int) -> void:
	_refresh_ids()
	if _ids.is_empty():
		return
	_index = posmod(_index + step, _ids.size())
	_switches += 1
	var id: String = _target_id()
	print("DSH_OBSERVE58 stage=switch index=", _index, " target=", id, " label=", _badge_text(id))


func _badge_text(id: String) -> String:
	return id.trim_prefix("resident_")


func _status_of(id: String) -> Dictionary:
	var lives: Dictionary = _lives()
	if not lives.has(id):
		return {}
	var life: RefCounted = lives[id]
	if life == null or not is_instance_valid(life):
		return {}
	var out := {"phase": str(life.get("_phase")), "goal": "", "hp": -1, "top": -1, "dead": false,
		"downed": false, "sleeping": false, "home": ""}
	var goal: Variant = life.get("_goal")
	if goal is Dictionary:
		out.goal = str(goal.get("kind", ""))
	var health: Variant = life.get("_health")
	if health != null and is_instance_valid(health):
		var row: Variant = health.get("_row")
		if row is Dictionary:
			out.hp = int(row.get("hp", -1))
			out.top = int(row.get("max_hp", -1))
			out.dead = bool(row.get("dead", false))
			out.downed = bool(row.get("_medicalDowned", false))
	var home: Variant = life.get("_home58")
	if home != null and is_instance_valid(home) and home.has_method("snapshot"):
		var snap: Dictionary = home.call("snapshot")
		if bool(snap.get("active", false)):
			out.home = str(snap.get("phase", ""))
			out.sleeping = bool(snap.get("sleeping", false))
	return out


func _track_still(delta: float) -> void:
	var lives: Dictionary = _lives()
	for id: String in lives:
		var body: CharacterBody3D = _body_of(id)
		if body == null:
			continue
		var status: Dictionary = _status_of(id)
		var here: Vector3 = body.global_position
		var row: Dictionary = _still.get(id, {})
		if row.is_empty():
			_still[id] = {"pos": here, "still_s": 0.0}
			continue
		var moved: float = here.distance_to(row.pos)
		var proven_rest: bool = bool(status.get("sleeping", false)) or not str(status.get("home", "")).is_empty()
		if moved >= STILL_STEP_M:
			row.pos = here
			row.still_s = 0.0
		elif not proven_rest and str(status.get("phase", "")) in ["IDLE", "RESTING", "AMBIENT", "WALKING"]:
			row.still_s = float(row.still_s) + delta
			if float(row.still_s) > float(_worst.get("still_s", 0.0)):
				_worst = {"id": id, "still_s": row.still_s}
		_still[id] = row


func _process(delta: float) -> void:
	_tick += 1
	if _tick == 1:
		print("DSH_OBSERVE58 stage=tick1 processed=true population=", _population != null,
			" scene=", _scene != null, " inside=", is_inside_tree())
	# The daily lives appear only after the population finishes admitting residents, so the
	# cohort is refreshed whenever its size changes instead of once at install time.
	if _lives().size() != _last_count:
		_refresh_ids()
		if _auto and not _enabled and not _ids.is_empty():
			_set_enabled(true)
	_track_still(delta)
	if _badges_on and is_instance_valid(_badges):
		_badges.queue_redraw()
	if not _enabled or not is_instance_valid(_camera):
		return
	if _auto:
		_auto_at += delta
		if _auto_at >= AUTO_SECONDS:
			_auto_at = 0.0
			_advance(1)
	var body: CharacterBody3D = _body_of(_target_id())
	if body == null:
		_tick += 1
		if _ids.size() > 1 and _tick % 120 == 0:
			_advance(1)
		return
	var forward: Vector3 = -body.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > .0001 else Vector3.BACK
	_camera.global_position = body.global_position + forward * CAMERA_BACK_M + Vector3.UP * CAMERA_UP_M
	_camera.look_at(body.global_position + Vector3.UP * LOOK_UP_M, Vector3.UP)
	if _label != null:
		_label.text = _caption(_target_id())


func _caption(id: String) -> String:
	var status: Dictionary = _status_of(id)
	var parts: Array[String] = ["№%s  (%d/%d)" % [_badge_text(id), _index + 1, _ids.size()]]
	parts.append("фаза: " + str(status.get("phase", "")))
	if not str(status.get("goal", "")).is_empty():
		parts.append("цель: " + str(status.get("goal")))
	if int(status.get("hp", -1)) >= 0:
		parts.append("HP %d/%d" % [int(status.hp), int(status.top)])
	if bool(status.get("dead", false)):
		parts.append("МЁРТВ")
	elif bool(status.get("downed", false)):
		parts.append("ранен")
	if not str(status.get("home", "")).is_empty():
		parts.append("дом: %s%s" % [str(status.home), " (спит)" if bool(status.get("sleeping", false)) else ""])
	parts.append("O — выйти" if not _auto else "автообход")
	return "   ".join(parts)


func _draw() -> void:
	if not _badges_on or _scene == null or not is_instance_valid(_scene):
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var origin: Vector3 = camera.global_position
	for id: String in _ids:
		var body: CharacterBody3D = _body_of(id)
		if body == null:
			continue
		var at: Vector3 = body.global_position + Vector3.UP * BADGE_HEIGHT_M
		if origin.distance_to(at) > BADGE_MAX_M or camera.is_position_behind(at):
			continue
		var screen: Vector2 = camera.unproject_position(at)
		var still_s: float = float((_still.get(id, {}) as Dictionary).get("still_s", 0.0))
		var color := Color(1, 1, 1, .92)
		var suffix := ""
		if still_s >= STILL_BAD_S:
			color = Color(1, .30, .26)
			suffix = "  %.0fс стоит" % still_s
		elif still_s >= STILL_WARN_S:
			color = Color(1, .78, .25)
			suffix = "  %.0fс" % still_s
		var status: Dictionary = _status_of(id)
		if bool(status.get("dead", false)) or bool(status.get("downed", false)):
			color = Color(1, .35, .35)
			suffix = "  мёртв" if bool(status.get("dead", false)) else "  ранен"
		elif bool(status.get("sleeping", false)):
			color = Color(.55, .85, 1, .95)
			suffix = "  спит"
		var text: String = _badge_text(id) + suffix
		var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var at_px := Vector2(screen.x - size.x * .5, screen.y)
		_badges.draw_string_outline(font, at_px, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, Color(0, 0, 0, .9))
		_badges.draw_string(font, at_px, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _unhandled_input(event: InputEvent) -> void:
	if _auto or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_O:
		_set_enabled(not _enabled)
		get_viewport().set_input_as_handled()
	elif _enabled and key == KEY_BRACKETRIGHT:
		_advance(1)
		get_viewport().set_input_as_handled()
	elif _enabled and key == KEY_BRACKETLEFT:
		_advance(-1)
		get_viewport().set_input_as_handled()
