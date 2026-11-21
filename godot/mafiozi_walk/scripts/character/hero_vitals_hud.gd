extends CanvasLayer
## Compact, event-driven hero vitals. The combat owner supplies the state; this
## layer only presents it and never changes health or wounds.

class BodyDiagram extends Control:
	var segments: Dictionary = {}
	var armor: Dictionary = {}
	var body_split := false
	const SLOT_FOR_SEGMENT := {"head":"head", "chest":"torso", "pelvis":"torso",
		"upperarm_l":"torso", "upperarm_r":"torso", "forearm_l":"hands", "forearm_r":"hands",
		"hand_l":"hands", "hand_r":"hands", "thigh_l":"legs", "thigh_r":"legs",
		"shin_l":"legs", "shin_r":"legs", "foot_l":"feet", "foot_r":"feet"}
	const KEYS := ["head", "chest", "pelvis", "upperarm_l", "forearm_l", "hand_l",
		"upperarm_r", "forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l",
		"thigh_r", "shin_r", "foot_r"]

	func _init() -> void:
		custom_minimum_size = Vector2(72.0, 104.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(next_segments: Dictionary, next_split: bool, next_armor: Dictionary = {}) -> void:
		if segments == next_segments and body_split == next_split and armor == next_armor:
			return
		segments = next_segments.duplicate(true)
		body_split = next_split
		armor = next_armor.duplicate()
		queue_redraw()

	func _part_status(key: String) -> String:
		# An intact distal segment cannot float after its parent was cut away.
		var parent := ""
		if key.begins_with("forearm"): parent = key.replace("forearm", "upperarm")
		elif key.begins_with("hand"): parent = key.replace("hand", "forearm")
		elif key.begins_with("shin"): parent = key.replace("shin", "thigh")
		elif key.begins_with("foot"): parent = key.replace("foot", "shin")
		if parent != "" and _part_status(parent) == "severed": return "severed"
		var value: Variant = segments.get(key, "healthy")
		if value is Dictionary:
			if bool(value.get("severed", false)):
				return "severed"
			var health := clampf(float(value.get("health", 1.0)), 0.0, 1.0)
			if health <= 0.3:
				return "critical"
			if health < 0.85:
				return "injured"
			if bool(value.get("disabled", false)):
				return "disabled"
			return "healthy"
		return str(value)

	func _color(key: String) -> Color:
		match _part_status(key):
			"severed": return Color(0.35, 0.34, 0.32)
			"disabled": return Color(0.47, 0.50, 0.55)
			"critical": return Color(0.69, 0.17, 0.15)
			"injured": return Color(0.77, 0.47, 0.23)
			_: return Color(0.68, 0.72, 0.62)

	func armor_tier_for_segment(key: String) -> String:
		if _part_status(key) == "severed": return ""
		return str(armor.get(SLOT_FOR_SEGMENT.get(key, ""), ""))

	func _shape(points: PackedVector2Array, key: String) -> void:
		# A severed segment is physically absent. Its stump is drawn at the
		# surviving parent below, rather than filling the missing shape gray.
		if _part_status(key) == "severed": return
		draw_colored_polygon(points, _color(key))
		var outline := points.duplicate()
		outline.append(points[0])
		var status := _part_status(key)
		var tier := armor_tier_for_segment(key)
		if tier in ["light", "medium", "heavy"]:
			var centre := Vector2.ZERO
			var low := Vector2(INF, INF)
			var high := Vector2(-INF, -INF)
			for point: Vector2 in points:
				centre += point
				low = low.min(point)
				high = high.max(point)
			centre /= float(points.size())
			var inset := PackedVector2Array()
			for point: Vector2 in points: inset.append(centre + (point - centre) * 0.92)
			var plate := Color(0.46, 0.27, 0.13) if tier == "light" else \
				Color(0.36, 0.46, 0.50) if tier == "medium" else Color(0.16, 0.22, 0.27)
			draw_colored_polygon(inset, plate)
			var edge := Color(0.70, 0.48, 0.25) if tier == "light" else \
				Color(0.68, 0.73, 0.72) if tier == "medium" else Color(0.88, 0.69, 0.34)
			if tier == "light":
				draw_line(Vector2(low.x + 2, centre.y), Vector2(high.x - 2, centre.y), edge, 1.0, true)
			elif tier == "medium":
				for offset: float in [-2.0, 2.0]:
					draw_line(Vector2(low.x + 2, centre.y + offset), Vector2(high.x - 2, centre.y + offset), edge, 1.0, true)
			else:
				inset.append(inset[0])
				draw_polyline(inset, edge, 1.4, true)
				draw_circle(centre, 1.4, edge)
			if status in ["critical", "injured"]:
				var wound := Color(0.95, 0.18, 0.12) if status == "critical" else Color(0.94, 0.47, 0.18)
				draw_colored_polygon(inset.slice(0, points.size()), Color(wound.r, wound.g, wound.b, 0.32))
				draw_line(centre + Vector2(-3, -2), centre + Vector2(3, 2), wound, 2.0, true)
		# Fine seams keep neighbouring parts readable without black joint holes.
		draw_polyline(outline, Color(0.88, 0.20, 0.15) if status == "critical" else Color(0.27, 0.30, 0.28, 0.38), 0.65, true)

	func _mark_severed(key: String, at: Vector2) -> void:
		if _part_status(key) != "severed":
			return
		var parent := ""
		if key.begins_with("forearm"): parent = key.replace("forearm", "upperarm")
		elif key.begins_with("hand"): parent = key.replace("hand", "forearm")
		elif key.begins_with("shin"): parent = key.replace("shin", "thigh")
		elif key.begins_with("foot"): parent = key.replace("foot", "shin")
		if parent != "" and _part_status(parent) == "severed": return
		match key:
			"head": at = Vector2(36, 26)
			"upperarm_l": at = Vector2(21, 32)
			"upperarm_r": at = Vector2(51, 32)
			"forearm_l": at = Vector2(15, 45)
			"forearm_r": at = Vector2(57, 45)
			"hand_l": at = Vector2(13, 58)
			"hand_r": at = Vector2(59, 58)
			"thigh_l": at = Vector2(30, 64)
			"thigh_r": at = Vector2(42, 64)
			"shin_l": at = Vector2(29, 78)
			"shin_r": at = Vector2(43, 78)
			"foot_l": at = Vector2(28, 92)
			"foot_r": at = Vector2(44, 92)
		var red := Color(0.88, 0.28, 0.22)
		draw_line(at + Vector2(-3.0, 0.0), at + Vector2(3.0, 0.0), red, 2.0, true)
		draw_circle(at, 1.3, Color(0.98, 0.68, 0.52))

	func _draw() -> void:
		# The frame stays transparent so an amputated part is truly absent.
		draw_rect(Rect2(2, 2, 68, 100), Color(0.57, 0.46, 0.30, 0.42), false, 1.0)
		# Adjacent polygons overlap slightly. Their former one-pixel gaps were
		# especially visible at the wrists, waist, knees and ankles at HUD scale.
		if _part_status("chest") != "severed":
			draw_rect(Rect2(32, 25, 8, 5), _color("chest"))
		_shape(PackedVector2Array([Vector2(23, 29), Vector2(49, 29), Vector2(48, 53), Vector2(24, 53)]), "chest")
		_shape(PackedVector2Array([Vector2(24, 52), Vector2(48, 52), Vector2(47, 64), Vector2(25, 64)]), "pelvis")
		_shape(PackedVector2Array([Vector2(23, 29), Vector2(15, 34), Vector2(13, 45), Vector2(21, 47), Vector2(29, 38)]), "upperarm_l")
		_shape(PackedVector2Array([Vector2(13, 44), Vector2(21, 46), Vector2(17, 59), Vector2(10, 58)]), "forearm_l")
		_shape(PackedVector2Array([Vector2(10, 57), Vector2(17, 58), Vector2(16, 66), Vector2(9, 66)]), "hand_l")
		_shape(PackedVector2Array([Vector2(49, 29), Vector2(57, 34), Vector2(59, 45), Vector2(51, 47), Vector2(43, 38)]), "upperarm_r")
		_shape(PackedVector2Array([Vector2(59, 44), Vector2(51, 46), Vector2(55, 59), Vector2(62, 58)]), "forearm_r")
		_shape(PackedVector2Array([Vector2(62, 57), Vector2(55, 58), Vector2(56, 66), Vector2(63, 66)]), "hand_r")
		_shape(PackedVector2Array([Vector2(25, 63), Vector2(36, 63), Vector2(34, 78), Vector2(24, 78)]), "thigh_l")
		_shape(PackedVector2Array([Vector2(24, 77), Vector2(34, 77), Vector2(33, 92), Vector2(23, 92)]), "shin_l")
		_shape(PackedVector2Array([Vector2(23, 91), Vector2(33, 91), Vector2(34, 98), Vector2(20, 98)]), "foot_l")
		_shape(PackedVector2Array([Vector2(36, 63), Vector2(47, 63), Vector2(48, 78), Vector2(38, 78)]), "thigh_r")
		_shape(PackedVector2Array([Vector2(38, 77), Vector2(48, 77), Vector2(49, 92), Vector2(39, 92)]), "shin_r")
		_shape(PackedVector2Array([Vector2(39, 91), Vector2(49, 91), Vector2(52, 98), Vector2(38, 98)]), "foot_r")
		if _part_status("head") != "severed":
			draw_circle(Vector2(36, 17), 10.5, _color("head"))
		var head_tier := armor_tier_for_segment("head")
		if head_tier in ["light", "medium", "heavy"]:
			var helmet := Color(0.46, 0.27, 0.13) if head_tier == "light" else \
				Color(0.36, 0.46, 0.50) if head_tier == "medium" else Color(0.16, 0.22, 0.27)
			draw_arc(Vector2(36, 17), 8.0, PI, TAU, 12, helmet, 4.0, true)
		if _part_status("head") != "severed":
			draw_arc(Vector2(36, 17), 10.5, 0.0, TAU, 20, Color(0.14, 0.16, 0.16), 1.5, true)
		if body_split:
			draw_line(Vector2(22, 52), Vector2(50, 52), Color(0.95, 0.24, 0.18), 2.0, true)
		for key: String in KEYS:
			_mark_severed(key, _position(key))
			var part: Dictionary = segments.get(key, {})
			if _part_status(key) == "severed" or not bool(part.get("bleeding", false)):
				continue
			var at := _position(key)
			at.x += 5.0 if key in ["head", "chest", "pelvis", "thigh_l", "shin_l", "foot_l"] else -5.0
			draw_circle(at, 2.5, Color(0.96, 0.23, 0.18))
			draw_arc(at, 2.5, 0.0, TAU, 12, Color(0.98, 0.78, 0.55), 1.0, true)

	func _position(key: String) -> Vector2:
		match key:
			"head": return Vector2(36, 17)
			"chest": return Vector2(36, 40)
			"pelvis": return Vector2(36, 58)
			"upperarm_l": return Vector2(20, 38)
			"forearm_l": return Vector2(15, 52)
			"hand_l": return Vector2(13, 62)
			"upperarm_r": return Vector2(52, 38)
			"forearm_r": return Vector2(57, 52)
			"hand_r": return Vector2(59, 62)
			"thigh_l": return Vector2(29, 70)
			"shin_l": return Vector2(29, 84)
			"foot_l": return Vector2(27, 95)
			"thigh_r": return Vector2(43, 70)
			"shin_r": return Vector2(43, 84)
			_: return Vector2(45, 95)

class HealthTrack extends Control:
	var ratio := 1.0
	func _init() -> void:
		custom_minimum_size = Vector2(153.0, 12.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_ratio(next: float) -> void:
		next = clampf(next, 0.0, 1.0)
		if is_equal_approx(ratio, next): return
		ratio = next
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(0, 0, w, 12), Color(0.40, 0.30, 0.20))
		draw_rect(Rect2(1, 1, w - 2, 10), Color(0.07, 0.07, 0.07))
		var fill := (w - 4) * ratio
		if fill > 0.0:
			var main := Color(0.70, 0.16, 0.13) if ratio > 0.3 else Color(0.88, 0.37, 0.10)
			draw_rect(Rect2(2, 2, fill, 8), main)
			draw_rect(Rect2(2, 2, fill, 2), main.lightened(0.32))
		for fraction: float in [0.25, 0.5, 0.75]:
			var x := 2.0 + (w - 4.0) * fraction
			draw_line(Vector2(x, 3), Vector2(x, 9), Color(0.08, 0.07, 0.07, 0.67), 1.0)

class WeaponGlyph extends Control:
	## Small HUD silhouettes are drawn at their final size. Scaling the detailed
	## inventory thumbnails down made the weapons disappear on screen.
	var weapon_id := "none"
	const METAL := Color(0.80, 0.83, 0.82)
	const BRIGHT := Color(0.92, 0.94, 0.91)
	const SHAFT := Color(0.57, 0.62, 0.61)
	const EDGE := Color(0.32, 0.37, 0.38)

	func _init() -> void:
		custom_minimum_size = Vector2(32, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_weapon(id: String) -> void:
		if weapon_id == id: return
		weapon_id = id
		queue_redraw()

	func glyph_kind(id: String) -> String:
		if id in ["none", "hatchet", "sword", "mace", "axe", "sledge", "spear", "shield", "bow"]:
			return id
		if id in ["nagan", "tt_pistol", "revolver", "deagle", "golden_colt"]:
			return "pistol"
		if id in ["sawn_off", "shotgun", "uzi", "golden_uzi", "ak74", "m16", "tommy_gun", "sniper"]:
			return "longgun"
		if id == "rpg": return "launcher"
		return "none"

	func _poly(points: Array[Vector2], colour: Color = METAL) -> void:
		draw_colored_polygon(PackedVector2Array(points), colour)

	func _shaft(a: Vector2, b: Vector2, width: float = 2.5) -> void:
		draw_line(a, b, EDGE, width + 1.5, true)
		draw_line(a, b, SHAFT, width, true)

	func _draw() -> void:
		draw_rect(Rect2(0.5, 0.5, 31, 31), Color(0.10, 0.13, 0.14, 0.72))
		draw_rect(Rect2(0.5, 0.5, 31, 31), Color(0.37, 0.40, 0.38, 0.65), false, 1.0)
		match glyph_kind(weapon_id):
			"sword":
				_poly([Vector2(14, 17), Vector2(18, 8), Vector2(25, 3), Vector2(22, 11), Vector2(17, 18)], BRIGHT)
				_shaft(Vector2(8, 25), Vector2(15, 18), 2.5)
				draw_line(Vector2(10, 16), Vector2(18, 23), METAL, 2.2, true)
				draw_circle(Vector2(7, 26), 2.2, METAL)
			"spear":
				_shaft(Vector2(6, 27), Vector2(23, 7), 2.2)
				_poly([Vector2(20, 10), Vector2(27, 2), Vector2(25, 13)], BRIGHT)
			"axe", "hatchet":
				_shaft(Vector2(9, 27), Vector2(20, 6) if weapon_id == "axe" else Vector2(19, 10), 3.0)
				_poly([Vector2(17, 6), Vector2(24, 5), Vector2(28, 8), Vector2(25, 15), Vector2(18, 13), Vector2(20, 10)], METAL)
				if weapon_id == "axe":
					_poly([Vector2(15, 6), Vector2(11, 3), Vector2(9, 7), Vector2(14, 13), Vector2(18, 11)], SHAFT)
			"sledge":
				_shaft(Vector2(7, 27), Vector2(20, 10), 3.2)
				_poly([Vector2(13, 4), Vector2(27, 4), Vector2(28, 11), Vector2(14, 11)], METAL)
				draw_line(Vector2(15, 5), Vector2(25, 5), BRIGHT, 1.3, true)
			"mace":
				_shaft(Vector2(7, 27), Vector2(21, 10), 3.0)
				draw_circle(Vector2(23, 8), 5.0, METAL)
				for offset: Vector2 in [Vector2(0, -8), Vector2(7, -3), Vector2(6, 5), Vector2(-5, -6)]:
					draw_line(Vector2(23, 8), Vector2(23, 8) + offset, BRIGHT, 2.2, true)
			"bow":
				draw_arc(Vector2(16, 16), 11.0, -PI * 0.5, PI * 0.5, 24, METAL, 3.0, true)
				draw_line(Vector2(16, 5), Vector2(16, 27), SHAFT, 1.4, true)
				draw_line(Vector2(7, 16), Vector2(27, 16), BRIGHT, 1.6, true)
				_poly([Vector2(27, 16), Vector2(22, 13), Vector2(22, 19)], BRIGHT)
			"shield":
				_poly([Vector2(16, 3), Vector2(27, 7), Vector2(25, 22), Vector2(16, 29), Vector2(7, 22), Vector2(5, 7)], METAL)
				draw_line(Vector2(16, 6), Vector2(16, 25), EDGE, 1.5, true)
				draw_line(Vector2(10, 14), Vector2(22, 14), EDGE, 1.5, true)
			"pistol":
				_poly([Vector2(5, 12), Vector2(23, 12), Vector2(27, 15), Vector2(27, 18), Vector2(15, 18), Vector2(12, 27), Vector2(7, 27), Vector2(9, 18), Vector2(5, 17)], METAL)
				_draw_trigger()
			"longgun":
				_poly([Vector2(3, 14), Vector2(24, 14), Vector2(29, 16), Vector2(29, 18), Vector2(12, 18), Vector2(7, 24), Vector2(3, 22)], METAL)
				draw_line(Vector2(18, 18), Vector2(16, 25), SHAFT, 2.0, true)
			"launcher":
				_shaft(Vector2(3, 19), Vector2(27, 11), 5.0)
				_poly([Vector2(24, 9), Vector2(30, 11), Vector2(25, 16)], BRIGHT)
			"none":
				# Four knuckles, tucked thumb and wrist read as a fist at HUD scale.
				_poly([Vector2(8, 14), Vector2(23, 13), Vector2(26, 17), Vector2(23, 24),
					Vector2(19, 27), Vector2(11, 26), Vector2(7, 21)], METAL)
				for x: float in [10.0, 14.0, 18.0, 22.0]:
					draw_circle(Vector2(x, 12), 2.7, BRIGHT)
				draw_line(Vector2(11, 15), Vector2(11, 18), EDGE, 1.0, true)
				draw_line(Vector2(15, 14), Vector2(15, 18), EDGE, 1.0, true)
				draw_line(Vector2(19, 14), Vector2(19, 18), EDGE, 1.0, true)
				_poly([Vector2(7, 16), Vector2(5, 13), Vector2(7, 10), Vector2(11, 17)], SHAFT)
				_poly([Vector2(11, 25), Vector2(20, 25), Vector2(20, 29), Vector2(12, 29)], SHAFT)

	func _draw_trigger() -> void:
		draw_arc(Vector2(15, 19), 3.0, 0.0, PI, 8, EDGE, 1.2, true)

var _panel: PanelContainer
var _scene: Node
var _weapon_label: Label
var _weapon_icon: WeaponGlyph
var _weapon_timer := 0.0
var _armor_owner: Node
var _armor_slots: Dictionary = {}
var _hp_label: Label
var _hp_track: HealthTrack
var _status_label: Label
var _lost_label: Label
var _burn_label: Label
var _diagram: BodyDiagram
var _last_state: Dictionary = {}
const BAR_WIDTH := 153.0

func configure(scene: Node) -> void:
	if is_instance_valid(_panel) or not is_instance_valid(scene):
		return
	_scene = scene
	layer = 14
	name = "HeroVitalsHud"
	scene.add_child(self)
	_panel = PanelContainer.new()
	_panel.name = "VitalsPanel"
	_panel.position = Vector2(16.0, 86.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.067, 0.073, 0.91)
	style.border_color = Color(0.57, 0.43, 0.25, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 5
	style.content_margin_left = 9
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	_panel.add_child(row)
	_diagram = BodyDiagram.new()
	row.add_child(_diagram)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	var weapon_row := HBoxContainer.new()
	weapon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_row.add_theme_constant_override("separation", 4)
	column.add_child(weapon_row)
	_weapon_icon = WeaponGlyph.new()
	weapon_row.add_child(_weapon_icon)
	_weapon_label = _label(weapon_row, "Без оружия", 12, Color("ead7ad"))
	_weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_label.custom_minimum_size.x = BAR_WIDTH - 36.0
	_hp_label = _label(column, "Здоровье 100 / 100", 12, Color("ead7ad"))
	_hp_track = HealthTrack.new()
	column.add_child(_hp_track)
	_status_label = _label(column, "", 12, Color("d9c7a9"))
	_status_label.visible = false
	_lost_label = _label(column, "", 11, Color("ec6850"))
	_lost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_burn_label = _label(column, "", 11, Color("f3aa55"))
	render_state({"hp": 100.0, "max_hp": 100.0, "parts": {}, "bleed_percent": 0.0,
		"segments": {}, "severed_labels": [], "body_split": false, "burning": false,
		"bleed_hp_per_second": 0.0, "bleed_sites": []})

func _process(delta: float) -> void:
	_weapon_timer -= delta
	if _weapon_timer > 0.0 or not is_instance_valid(_scene): return
	_weapon_timer = 0.2
	sync_weapon()

func bind_armor(owner: Node) -> void:
	if not is_instance_valid(owner) or not owner.has_method("equipped_snapshot"): return
	if is_instance_valid(_armor_owner) and _armor_owner.equipped_changed.is_connected(_on_armor_changed):
		_armor_owner.equipped_changed.disconnect(_on_armor_changed)
	_armor_owner = owner
	_armor_owner.equipped_changed.connect(_on_armor_changed)
	_refresh_armor()

func _on_armor_changed(_slot: String, _old_id: String, _new_id: String) -> void:
	_refresh_armor()

func _refresh_armor() -> void:
	if not is_instance_valid(_armor_owner): return
	var equipped: Dictionary = _armor_owner.equipped_snapshot()
	var next: Dictionary = {}
	for slot: String in ["head", "torso", "hands", "legs", "feet"]:
		var id := str(equipped.get(slot, ""))
		for tier: String in ["light", "medium", "heavy"]:
			if id.begins_with(tier + "_"):
				next[slot] = tier
				break
	if next == _armor_slots: return
	_armor_slots = next
	_diagram.set_state(_last_state.get("segments", {}), bool(_last_state.get("body_split", false)), _armor_slots)

func sync_weapon() -> void:
	if not is_instance_valid(_scene) or not is_instance_valid(_weapon_label): return
	var id := "none"
	var host: Node = _scene.get("preview_weapons")
	if is_instance_valid(host) and host.has_method("arsenal_display_id29"):
		id = str(host.arsenal_display_id29())
		var melee: Node = _scene.get("preview_sword_prototype")
		if id in ["hatchet", "sword", "mace", "axe", "sledge", "spear"] and is_instance_valid(melee) \
				and (bool(melee.get("_sword_grounded")) or bool(melee.get("_unarmed")) \
				or bool(melee.get("_player_disarmed")) or not bool(melee.get("_selected")) \
				or not is_instance_valid(melee.get("_sword"))):
			id = "none"
		if id == "hatchet" and is_instance_valid(melee):
			var hatchets: Node = melee.get("_hatchet32")
			if is_instance_valid(hatchets) and int(hatchets.call("count")) == 0: id = "none"
		if id == "bow":
			var bow: Node = _scene.get("preview_bow_prototype")
			if is_instance_valid(bow) and bool(bow.get("_grounded")): id = "none"
		if id == "none" and is_instance_valid(melee) and bool(melee.get("_shield_only31")) \
				and bool(melee.get("_shield_worn")): id = "shield"
		if id == "shield" and is_instance_valid(melee) and not bool(melee.get("_shield_worn")):
			id = "none"
	var name := "Без оружия"
	if is_instance_valid(host): name = str(host.LABELS.get(id, "Без оружия"))
	name = name.replace(" (прототип)", "")
	if _weapon_label.text != name: _weapon_label.text = name
	_weapon_icon.set_weapon(id)

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func render_state(state: Dictionary) -> void:
	if not is_instance_valid(_panel) or state == _last_state:
		return
	_last_state = state.duplicate(true)
	var maximum := maxf(1.0, float(state.get("max_hp", 100.0)))
	var hp := clampf(float(state.get("hp", maximum)), 0.0, maximum)
	var percent := clampf(float(state.get("bleed_percent", 0.0)), 0.0, 100.0)
	_hp_label.text = "Здоровье %d / %d" % [int(ceil(hp)), int(ceil(maximum))]
	_hp_track.set_ratio(hp / maximum)
	var lost: Array = state.get("severed_labels", [])
	var burning := bool(state.get("burning", false))
	var split := bool(state.get("body_split", false))
	var segments: Dictionary = state.get("segments", {})
	var injured := false
	for segment: Dictionary in segments.values():
		if float(segment.get("health", 1.0)) < 0.98:
			injured = true
			break
	if hp <= 0.0:
		_status_label.text = "Погиб"
	elif percent > 0.0:
		_status_label.text = "●  Кровотечение %d%%" % int(round(percent))
	elif injured or not lost.is_empty() or split:
		_status_label.text = "Ранен"
	else:
		_status_label.text = ""
	_status_label.visible = not _status_label.text.is_empty()
	_status_label.add_theme_color_override("font_color", Color("ec6850") if percent > 0.0 else Color("d9c7a9"))
	var lost_text := ", ".join(lost)
	if split:
		lost_text = "разделён корпус" if lost_text.is_empty() else lost_text + ", разделён корпус"
	_lost_label.text = "Отсечено: " + lost_text if not lost_text.is_empty() else ""
	_burn_label.text = "●  Ожог / горение" if burning else ""
	_diagram.set_state(segments, split, _armor_slots)

func snapshot() -> Dictionary:
	return _last_state.duplicate(true)
