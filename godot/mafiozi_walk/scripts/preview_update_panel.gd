extends PanelContainer
## Local notes only. No network, per-frame callbacks, or arbitrary rich text.
const MAX_BYTES := 16 * 1024
const POLL_SECONDS := 2.0
const RESTART_TEXT := "Готово обновление игры — перезапустите сцену"
var _path := ""
var _running_revision := ""
var _timer: Timer
var _title: Label
var _notice: Label
var _items: Array[Label] = []
var _last_valid: Dictionary = {}
var _signature := ""
var _polling := false
var _restart_required := false
var _read_count := 0
var _stat_count := 0

func setup(path: String, running_revision: String) -> void:
	if _timer == null:
		_build()
	_timer.stop()
	_path = path
	_running_revision = running_revision
	_signature = ""
	_last_valid.clear()
	_restart_required = false
	_read_count = 0
	_stat_count = 0
	_render()
	# Godot 4 uses "template", not the obsolete Godot 3 "standalone" tag.
	# The physical-path check also covers editor binaries loading --main-pack.
	var packed_resource := path.begins_with("res://") and (OS.has_feature("template") or (FileAccess.file_exists(path) and not FileAccess.file_exists(ProjectSettings.globalize_path(path))))
	_polling = not packed_resource
	_poll_file(true, packed_resource)
	if _polling and is_inside_tree():
		_timer.start()

func _ready() -> void:
	if _polling and _timer != null:
		_timer.start()

func _build() -> void:
	name = "PreviewUpdates"
	custom_minimum_size.x = 280
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -296
	offset_right = -16
	offset_top = 16
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.07, 0.90)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_width_top = 2
	style.border_color = Color("ad956c")
	add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	var heading := _label(stack, 13, Color("bca681"))
	heading.text = "НОВОЕ · ПОПРОБУЙ"
	_title = _label(stack, 11, Color("aabec8"))
	for i in range(5):
		_items.append(_label(stack, 12, Color("e0e7ec")))
	_notice = _label(stack, 12, Color("bca681"))
	_notice.text = RESTART_TEXT
	_timer = Timer.new()
	_timer.name = "NotesPoll"
	_timer.wait_time = POLL_SECONDS
	_timer.ignore_time_scale = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(_poll_file)
	add_child(_timer)

func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _poll_file(force: bool = false, packed_resource: bool = false) -> void:
	_stat_count += 1
	if not FileAccess.file_exists(_path):
		_signature = "missing"
		return
	var size := FileAccess.get_size(_path)
	# Packed files have no filesystem mtime; never ask for it or poll them.
	var modified := 0 if packed_resource else FileAccess.get_modified_time(_path)
	var signature := "%d:%d" % [modified, size]
	if not force and signature == _signature:
		return
	_signature = signature
	if size < 2 or size > MAX_BYTES:
		return
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return
	# Recheck the opened file: a writer may replace it between stat and open.
	var length := file.get_length()
	if length != size or length > MAX_BYTES:
		file.close()
		_signature = "retry"
		return
	_read_count += 1
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		_signature = "retry"
		return
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return # Instance parse returns an error without printing parse_string spam.
	var data: Variant = parser.data
	if not data is Dictionary or not data.get("title") is String or not data.get("items") is Array:
		return
	if data.has("runtime_revision") and not data.runtime_revision is String:
		return
	if data.has("updated_at") and not data.updated_at is String:
		return
	var items: Array[String] = []
	for item: Variant in data.items:
		if not item is String:
			return
		if items.size() < 5 and not item.strip_edges().is_empty():
			items.append(item.strip_edges().left(240))
	if data.has("runtime_revision") and data.runtime_revision != _running_revision:
		_restart_required = true
		_render()
		return
	_last_valid = {"title": data.title.left(80), "items": items}
	_restart_required = false
	_render()

func _render() -> void:
	visible = not _last_valid.is_empty() or _restart_required
	_title.visible = not _last_valid.is_empty()
	_title.text = str(_last_valid.get("title", ""))
	var items: Array = _last_valid.get("items", [])
	for i in range(_items.size()):
		_items[i].visible = i < items.size()
		_items[i].text = "%d. %s" % [i + 1, items[i]] if i < items.size() else ""
	_notice.visible = _restart_required
	reset_size()
	offset_left = -296
	offset_right = -16
	# Let wrapped labels settle at the final width, then discard stale height.
	reset_size.call_deferred()

func get_status() -> Dictionary:
	return {"notes": _last_valid.duplicate(true), "restart_required": _restart_required,
		"polling": _polling, "read_count": _read_count, "stat_count": _stat_count}
