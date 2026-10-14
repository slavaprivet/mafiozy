extends CanvasLayer
## Russian map-editor UI; actions are handled by the host, never by this panel.
signal action_requested(action: String, payload: Dictionary)
signal mode_requested(mode: String)

var _root: PanelContainer
var _catalog_list: ItemList
var _search: LineEdit
var _category: OptionButton
var _selection: Label
var _status: Label
var _result_count: Label
var _move_step: SpinBox
var _catalog: Array = []
var _visible_items: Array = []
var _active := false
var _selected_id := ""
var _labels_by_id: Dictionary = {}

func _ready() -> void:
	_build()
	set_active(_active)

func _build() -> void:
	if is_instance_valid(_root):
		return
	_root = PanelContainer.new()
	_root.position = Vector2(12, 12)
	_root.custom_minimum_size = Vector2(330, 0)
	add_child(_root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "Редактор карты · K — выйти"
	box.add_child(title)
	var modes := HBoxContainer.new()
	box.add_child(modes)
	for mode: String in ["objects", "ground"]:
		var button := Button.new()
		button.text = "Объекты" if mode == "objects" else "Земля и дороги"
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): mode_requested.emit(mode))
		modes.add_child(button)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row, "Сохранить", "save", {})
	_button(row, "Загрузить", "load", {})
	row = HBoxContainer.new()
	box.add_child(row)
	_button(row, "Экспорт JSON", "export", {})
	_button(row, "Импорт JSON", "import", {})
	_button(box, "Завершить / восстановить обновление", "retry_pending", {})
	row = HBoxContainer.new()
	box.add_child(row)
	_button(row, "Отменить", "undo", {})
	_button(row, "Повторить", "redo", {})
	row = HBoxContainer.new()
	box.add_child(row)
	_button(row, "Вид сверху", "camera_top", {})
	_button(row, "Полёт", "camera_fly", {})
	_search = LineEdit.new()
	_search.placeholder_text = "Найти объект…"
	_search.text_changed.connect(func(_text: String) -> void: _refresh())
	box.add_child(_search)
	_category = OptionButton.new()
	_category.item_selected.connect(func(_index: int) -> void: _refresh())
	box.add_child(_category)
	_result_count = Label.new()
	box.add_child(_result_count)
	_catalog_list = ItemList.new()
	_catalog_list.custom_minimum_size = Vector2(300, 180)
	_catalog_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_list.item_selected.connect(_catalog_selected)
	box.add_child(_catalog_list)
	_button(box, "Добавить выбранный объект", "add", {})
	_selection = Label.new()
	_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_selection)
	row = HBoxContainer.new()
	box.add_child(row)
	var step_label := Label.new()
	step_label.text = "Шаг перемещения:"
	row.add_child(step_label)
	_move_step = SpinBox.new()
	_move_step.min_value = 0.1
	_move_step.max_value = 100.0
	_move_step.step = 0.1
	_move_step.value = 1.0
	_move_step.suffix = "м"
	row.add_child(_move_step)
	row = HBoxContainer.new()
	box.add_child(row)
	_move_button(row, "X−", Vector3.LEFT)
	_move_button(row, "X+", Vector3.RIGHT)
	_move_button(row, "Z−", Vector3.FORWARD)
	_move_button(row, "Z+", Vector3.BACK)
	_move_button(row, "Y−", Vector3.DOWN)
	_move_button(row, "Y+", Vector3.UP)
	row = HBoxContainer.new()
	box.add_child(row)
	_button(row, "↶ 15°", "rotate", {"degrees": -15.0})
	_button(row, "↷ 15°", "rotate", {"degrees": 15.0})
	_button(row, "Удалить", "delete", {})
	var hint := Label.new()
	hint.text = "ЛКМ — выбрать / разместить\nWASD — полёт / движение сверху\nQ / E — ниже / выше · Shift — быстрее\nПКМ коротко — удалить объект\nПКМ + движение — обзор в полёте\nКолесо — масштаб сверху / скорость полёта"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	set_selection({})
	set_catalog(_catalog)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()

func _fit_viewport() -> void:
	if is_instance_valid(_root):
		_root.size = Vector2(330.0, maxf(100.0, get_viewport().get_visible_rect().size.y - 24.0))

func _move_button(parent: Node, label: String, direction: Vector3) -> void:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		var delta := direction * float(_move_step.value)
		action_requested.emit("move", {"delta": [delta.x, delta.y, delta.z]}))
	parent.add_child(button)

func _button(parent: Node, label: String, action: String, payload: Dictionary) -> void:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		var data := payload.duplicate()
		if action == "add":
			if _selected_id.is_empty():
				set_status("Выберите доступный объект в каталоге.")
				return
			data["catalog_id"] = _selected_id
		action_requested.emit(action, data))
	parent.add_child(button)

func set_active(value: bool) -> void:
	_active = value
	if is_instance_valid(_root):
		_root.visible = value
		if not value and is_instance_valid(_search):
			_search.release_focus()

func set_catalog(items: Array) -> void:
	_catalog = items.duplicate(true)
	_labels_by_id.clear()
	for item: Dictionary in _catalog:
		_labels_by_id[str(item.get("id", ""))] = str(item.get("label", item.get("id", "Объект")))
	if not is_instance_valid(_category):
		return
	_category.clear()
	_category.add_item("Все категории")
	var categories: Array[String] = []
	for item in _catalog:
		var category := str(item.get("category", "Другое"))
		if category not in categories:
			categories.append(category)
	categories.sort()
	for category in categories:
		_category.add_item(category)
	_selected_id = ""
	_refresh()

func _refresh() -> void:
	_catalog_list.clear()
	_visible_items.clear()
	var previous_selected := _selected_id
	_selected_id = ""
	var results := 0
	var query := _search.text.strip_edges().to_lower()
	var category := _category.get_item_text(_category.selected) if _category.selected > 0 else ""
	for item in _catalog:
		var label := str(item.get("label", item.get("id", "Объект")))
		if not query.is_empty() and query not in label.to_lower():
			continue
		if not category.is_empty() and str(item.get("category", "Другое")) != category:
			continue
		results += 1
		if _visible_items.size() >= 160:
			continue
		var available := bool(item.get("available", true))
		_catalog_list.add_item(label + ("" if available else " · " + str(item.get("reason", "ещё не перенесён"))))
		_catalog_list.set_item_disabled(_catalog_list.item_count - 1, not available)
		_visible_items.append(item)
		if available and str(item.get("id", "")) == previous_selected:
			_selected_id = previous_selected
			_catalog_list.select(_catalog_list.item_count - 1)
	_result_count.text = "Найдено: %d · показано: %d" % [results, _visible_items.size()]
	if results > 160:
		_result_count.text += "\nУточните поиск или категорию."

func _catalog_selected(index: int) -> void:
	if index >= 0 and index < _visible_items.size():
		_selected_id = str(_visible_items[index].get("id", ""))

func set_selection(item: Dictionary) -> void:
	if is_instance_valid(_selection):
		_selection.text = "Выбрано: " + str(item.get("label", _labels_by_id.get(str(item.get("id", "")), item.get("id", "")))) if not item.is_empty() else "Объект не выбран. Нажмите ЛКМ на карте."

func set_status(message: String) -> void:
	if is_instance_valid(_status):
		_status.text = message

func is_pointer_over_panel(position: Vector2) -> bool:
	return _active and is_instance_valid(_root) and _root.get_global_rect().has_point(position)

func is_text_focused() -> bool:
	return _active and ((is_instance_valid(_search) and _search.has_focus()) or (is_instance_valid(_move_step) and _move_step.get_line_edit().has_focus()))
