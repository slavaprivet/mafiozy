extends CanvasLayer
## Visible Russian controls; signals only, no game/model mutation.
signal action_requested(action: String, payload: Dictionary)
signal mode_requested(mode: String)
const BRUSHES := [
	{"label": "Асфальт", "tile": 0}, {"label": "Трава", "tile": 8},
	{"label": "Тротуар", "tile": 9}, {"label": "Песок", "tile": 14},
	{"label": "Вода", "tile": 16}, {"label": "Просёлочная дорога · отдельный слой", "layer": "dirt"},
	{"label": "Земля · отдельный слой", "layer": "earth"}, {"label": "Убрать отдельный слой", "layer": ""}
]
var _root: PanelContainer
var _brush: OptionButton
var _radius: SpinBox
var _status: Label
var _active := false

func _ready() -> void:
	_build()
	set_active(_active)

func _build() -> void:
	if is_instance_valid(_root): return
	_root = PanelContainer.new()
	_root.position = Vector2(12, 12)
	_root.custom_minimum_size = Vector2(330, 0)
	add_child(_root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "Земля и дороги · K — выйти"
	box.add_child(title)
	var modes := HBoxContainer.new()
	box.add_child(modes)
	for mode: String in ["objects", "ground"]:
		var button := Button.new()
		button.text = "Объекты" if mode == "objects" else "Земля и дороги"
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): mode_requested.emit(mode))
		modes.add_child(button)
	for pairs in [[["Сохранить карту", "save"], ["Загрузить карту", "load"]], [["Экспорт JSON", "export"], ["Импорт JSON", "import"]], [["Завершить / восстановить обновление", "retry_pending"]], [["Вид сверху", "camera_top"], ["Полёт", "camera_fly"]]]:
		var buttons := HBoxContainer.new()
		box.add_child(buttons)
		for pair in pairs:
			var button := Button.new()
			button.text = pair[0]
			button.focus_mode = Control.FOCUS_NONE
			var action: String = pair[1]
			button.pressed.connect(func(): action_requested.emit(action, {}))
			buttons.add_child(button)
	_brush = OptionButton.new()
	for brush in BRUSHES: _brush.add_item(brush.label)
	_brush.item_selected.connect(_brush_selected)
	box.add_child(_brush)
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = "Размер кисти:"
	row.add_child(label)
	_radius = SpinBox.new()
	_radius.min_value = 1
	_radius.max_value = 8
	_radius.step = 1
	_radius.value = 1
	_radius.suffix = "клеток"
	_radius.value_changed.connect(func(value: float): action_requested.emit("ground_radius", {"radius": int(value)}))
	row.add_child(_radius)
	row = HBoxContainer.new()
	box.add_child(row)
	for pair in [["Отменить мазок", "ground_undo"], ["Повторить", "ground_redo"]]:
		var button := Button.new()
		button.text = pair[0]
		button.focus_mode = Control.FOCUS_NONE
		var action: String = pair[1]
		button.pressed.connect(func(): action_requested.emit(action, {}))
		row.add_child(button)
	var hint := Label.new()
	hint.text = "Выберите покрытие → зажмите ЛКМ на земле → ведите мышью → отпустите ЛКМ.\nРазмер 1 — одна клетка; каждая клетка — 4,1 м.\nУход на панель, потеря фокуса или выход отменяют незаконченный мазок.\nПолиция, мосты и защищённые участки не закрашиваются.\nПросёлок и земля — отдельные слои; песок и вода сохраняют свои типы."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()

func _brush_selected(index: int) -> void:
	if index < 0 or index >= BRUSHES.size(): return
	var brush: Dictionary = BRUSHES[index]
	if brush.has("layer"): action_requested.emit("ground_layer", {"layer": brush.layer})
	else: action_requested.emit("ground_tile", {"tile": brush.tile})

func _fit_viewport() -> void:
	if is_instance_valid(_root): _root.size = Vector2(330, maxf(100, get_viewport().get_visible_rect().size.y - 24))

func set_active(value: bool) -> void:
	_active = value
	if is_instance_valid(_root): _root.visible = value

func set_status(message: String) -> void:
	if is_instance_valid(_status): _status.text = message

func input_guard(event: InputEvent) -> Dictionary:
	var over := false
	if _active and is_instance_valid(_root) and event is InputEventMouse: over = _root.get_global_rect().has_point(event.position)
	return {"text_focused": is_text_focused(), "pointer_over_panel": over}

func is_text_focused() -> bool:
	if not is_instance_valid(_root) or not _active: return false
	var focus := get_viewport().gui_get_focus_owner()
	return is_instance_valid(focus) and _root.is_ancestor_of(focus) and (focus is LineEdit or focus is TextEdit)
