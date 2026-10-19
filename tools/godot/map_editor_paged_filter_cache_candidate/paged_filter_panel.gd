extends "res://paged_editor_panel.gd"
## Cache only matching row indices. Labels and IDs are normalized by the
## inherited panel; availability, reason and selection are read on every draw.
var _catalog_generation := 0
var _matched_generation := -1
var _matched_query := ""
var _matched_category := ""
var _matching_indices: Array[int] = []
var filter_scans := 0

func set_catalog(items: Array) -> void:
	_catalog_generation += 1
	_matched_generation = -1
	_matching_indices.clear()
	super.set_catalog(items)

func _refresh() -> void:
	if not is_instance_valid(_catalog_list): return
	var query := _search.text.strip_edges().to_lower()
	var category := _category.get_item_text(_category.selected) if _category.selected > 0 else ""
	if query != _last_query or category != _last_category:
		_page = 0
		_last_query = query
		_last_category = category
	if _matched_generation != _catalog_generation or _matched_query != query or _matched_category != category:
		_matching_indices.clear()
		for index in _catalog.size():
			var item: Dictionary = _catalog[index]
			if not query.is_empty() and query not in _normalized_labels[index] and query not in _normalized_ids[index]: continue
			if not category.is_empty() and str(item.get("category", "Другое")) != category: continue
			_matching_indices.append(index)
		_matched_generation = _catalog_generation
		_matched_query = query
		_matched_category = category
		filter_scans += 1
	_match_count = _matching_indices.size()
	_page_count = maxi(1, ceili(float(_match_count) / PAGE_SIZE))
	_page = clampi(_page, 0, _page_count - 1)
	var previous_selected := _selected_id
	_selected_id = ""
	_catalog_list.clear()
	_visible_items.clear()
	var first := _page * PAGE_SIZE
	var last := mini(first + PAGE_SIZE, _match_count)
	for position in range(first, last):
		var item: Dictionary = _catalog[_matching_indices[position]]
		var id := str(item.get("id", ""))
		var label := str(item.get("label", item.get("id", "Объект")))
		var available := bool(item.get("available", true))
		_catalog_list.add_item(label + ("" if available else " · " + str(item.get("reason", "ещё не перенесён"))))
		var index := _catalog_list.item_count - 1
		_catalog_list.set_item_disabled(index, not available)
		_catalog_list.set_item_tooltip(index, label + "\nID: " + id)
		_visible_items.append(item)
		if available and id == previous_selected:
			_selected_id = id
			_catalog_list.select(index)
	_result_count.text = "Найдено: %d · показано: %d–%d" % [_match_count, first + 1 if _match_count > 0 else 0, last]
	if is_instance_valid(_page_label):
		_page_label.text = "Стр. %d / %d" % [_page + 1, _page_count]
		_previous_page.disabled = _page == 0
		_next_page.disabled = _page == _page_count - 1
