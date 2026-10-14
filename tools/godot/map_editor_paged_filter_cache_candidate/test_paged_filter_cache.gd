extends "res://test_full_paged_editor.gd"
## Run later in the staged full source assembly. This reuses its genuine 9901-ID
## registry/catalogue and all inherited object/history/fresh-load assertions.
const BaselinePanel = preload("res://paged_editor_panel.gd")
const CachedPanel = preload("res://paged_filter_panel.gd")

func _panel_state(panel: CanvasLayer) -> Dictionary:
	var rows: Array = []
	for index in panel._catalog_list.item_count:
		rows.append([panel._catalog_list.get_item_text(index), panel._catalog_list.is_item_disabled(index), panel._catalog_list.get_item_tooltip(index), panel._catalog_list.is_selected(index)])
	var visible: Array = []
	for item: Dictionary in panel._visible_items:
		visible.append([item.get("id"), item.get("available"), item.get("reason")])
	return {"page": panel._page, "pages": panel._page_count, "matches": panel._match_count, "selected": panel._selected_id, "visible": visible, "rows": rows, "result": panel._result_count.text, "page_label": panel._page_label.text, "previous_disabled": panel._previous_page.disabled, "next_disabled": panel._next_page.disabled}

func _compare(baseline: CanvasLayer, cached: CanvasLayer, label: String) -> void:
	check(_panel_state(baseline) == _panel_state(cached), label)

func _query(baseline: CanvasLayer, cached: CanvasLayer, value: String, category: String = "") -> void:
	for panel: CanvasLayer in [baseline, cached]:
		panel._search.text = value
		var category_index := 0
		for index in panel._category.item_count:
			if panel._category.get_item_text(index) == category: category_index = index
		panel._category.select(category_index)
		panel._refresh()
	_compare(baseline, cached, "exact query/category result: " + value + "/" + category)

func _sweep(panel: CanvasLayer) -> int:
	var start := Time.get_ticks_usec()
	for page in panel._page_count: panel.set_page(page)
	return Time.get_ticks_usec() - start

func exercise_editor_actions(session: Dictionary, templates: Array) -> void:
	super.exercise_editor_actions(session, templates)
	var catalogue: Array = session.controller.panel._catalog.duplicate(true)
	check(catalogue.size() == 9901, "same genuine full source catalogue")
	var baseline: CanvasLayer = BaselinePanel.new()
	var cached: CanvasLayer = CachedPanel.new()
	session.world.add_child(baseline)
	session.world.add_child(cached)
	baseline.set_catalog(catalogue)
	cached.set_catalog(catalogue)
	_compare(baseline, cached, "initial full catalogue")
	var scans_before_pages: int = cached.filter_scans
	for page in baseline._page_count:
		baseline.set_page(page)
		cached.set_page(page)
		_compare(baseline, cached, "page " + str(page))
	check(cached.filter_scans == scans_before_pages, "page navigation does not rescan 9901 source rows")
	_query(baseline, cached, str(catalogue[0].id))
	_query(baseline, cached, "несуществующий-id-для-поиска")
	_query(baseline, cached, "", "Дома и здания")
	_query(baseline, cached, "")
	# Change displayed permission text without changing the filter key. The cache
	# must never retain availability, reason, selection or rendered row state.
	for panel: CanvasLayer in [baseline, cached]:
		var first: Dictionary = panel._catalog[0]
		first.available = not bool(first.get("available", false))
		first.reason = "Проверка обновления владельца"
		panel._catalog[0] = first
		panel._refresh()
	_compare(baseline, cached, "same-query live availability and reason")
	var replaced := catalogue.duplicate(true)
	replaced[0].label = "UNIQUE-FILTER-CACHE-REPLACEMENT"
	baseline.set_catalog(replaced)
	cached.set_catalog(replaced)
	_query(baseline, cached, "UNIQUE-FILTER-CACHE-REPLACEMENT")
	check(cached._match_count == 1, "set_catalog invalidates old match indices")
	baseline.set_catalog(catalogue)
	cached.set_catalog(catalogue)
	_query(baseline, cached, "")
	check(baseline._page_count == 62 and cached._page_count == 62, "benchmark uses all 62 full-catalogue pages")
	var original_scans: int = cached.filter_scans
	var base_us: Array[int] = []
	var cache_us: Array[int] = []
	for pair in 6:
		var a := 0
		var b := 0
		if pair % 2 == 0:
			a = _sweep(baseline)
			b = _sweep(cached)
		else:
			b = _sweep(cached)
			a = _sweep(baseline)
		if pair > 0:
			base_us.append(a)
			cache_us.append(b)
	check(cached.filter_scans == original_scans, "repeated page sweeps retain only match-index cache")
	_compare(baseline, cached, "post-benchmark catalogue parity")
	print("PAGED_FILTER_CPU_BENCHMARK ", JSON.stringify({"source_ids": catalogue.size(), "pages": baseline._page_count, "baseline_sweep_us": base_us, "cached_sweep_us": cache_us, "warmup_pairs": 1, "gpu": false, "production_wired": false}))
	baseline.free()
	cached.free()
