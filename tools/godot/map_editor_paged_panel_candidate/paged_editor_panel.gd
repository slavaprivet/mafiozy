extends "res://scripts/map_editor/editor_panel.gd"
## Opt-in UI only. Catalog availability is supplied by the trusted host.
const PAGE_SIZE := 160
var _page := 0
var _page_count := 1
var _match_count := 0
var _normalized_labels: Array[String] = []
var _normalized_ids: Array[String] = []
var _last_query := ""
var _last_category := ""
var _previous_page: Button
var _next_page: Button
var _page_label: Label

func _build() -> void:
	if is_instance_valid(_root): return
	super._build()
	_search.placeholder_text = "Найти по названию или ID…"
	var row := HBoxContainer.new()
	var parent := _catalog_list.get_parent()
	parent.add_child(row)
	parent.move_child(row,_catalog_list.get_index())
	_previous_page = Button.new()
	_previous_page.text = "← Назад"
	_previous_page.focus_mode = Control.FOCUS_NONE
	_previous_page.pressed.connect(func(): set_page(_page-1))
	row.add_child(_previous_page)
	_page_label = Label.new()
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_page_label)
	_next_page = Button.new()
	_next_page.text = "Далее →"
	_next_page.focus_mode = Control.FOCUS_NONE
	_next_page.pressed.connect(func(): set_page(_page+1))
	row.add_child(_next_page)
	_refresh()

func set_catalog(items: Array) -> void:
	_normalized_labels.clear()
	_normalized_ids.clear()
	for item: Dictionary in items:
		_normalized_labels.append(str(item.get("label",item.get("id","Объект"))).to_lower())
		_normalized_ids.append(str(item.get("id","")).to_lower())
	_page = 0
	_last_query = ""
	_last_category = ""
	super.set_catalog(items)

func set_page(value: int) -> void:
	_page = clampi(value,0,_page_count-1)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_catalog_list): return
	var query := _search.text.strip_edges().to_lower()
	var category := _category.get_item_text(_category.selected) if _category.selected>0 else ""
	if query!=_last_query or category!=_last_category:
		_page = 0
	_last_query = query
	_last_category = category
	var matches: Array[int] = []
	for index in _catalog.size():
		var item: Dictionary = _catalog[index]
		if not query.is_empty() and query not in _normalized_labels[index] and query not in _normalized_ids[index]: continue
		if not category.is_empty() and str(item.get("category","Другое"))!=category: continue
		matches.append(index)
	_match_count = matches.size()
	_page_count = maxi(1,ceili(float(_match_count)/PAGE_SIZE))
	_page = clampi(_page,0,_page_count-1)
	var previous_selected := _selected_id
	_selected_id = ""
	_catalog_list.clear()
	_visible_items.clear()
	var first := _page*PAGE_SIZE
	var last := mini(first+PAGE_SIZE,_match_count)
	for position in range(first,last):
		var item: Dictionary = _catalog[matches[position]]
		var id := str(item.get("id",""))
		var label := str(item.get("label",item.get("id","Объект")))
		# Never memoize authority flags or refusal reasons in the search cache.
		var available := bool(item.get("available",true))
		_catalog_list.add_item(label+("" if available else " · "+str(item.get("reason","ещё не перенесён"))))
		var index := _catalog_list.item_count-1
		_catalog_list.set_item_disabled(index,not available)
		_catalog_list.set_item_tooltip(index,label+"\nID: "+id)
		_visible_items.append(item)
		if available and id==previous_selected:
			_selected_id = id
			_catalog_list.select(index)
	_result_count.text = "Найдено: %d · показано: %d–%d" % [_match_count,first+1 if _match_count>0 else 0,last]
	if is_instance_valid(_page_label):
		_page_label.text = "Стр. %d / %d" % [_page+1,_page_count]
		_previous_page.disabled = _page==0
		_next_page.disabled = _page==_page_count-1

func _catalog_selected(index: int) -> void:
	if index>=0 and index<_visible_items.size() and bool(_visible_items[index].get("available",true)):
		_selected_id = str(_visible_items[index].get("id",""))
