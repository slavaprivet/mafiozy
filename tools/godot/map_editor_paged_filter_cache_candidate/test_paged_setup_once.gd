extends "res://test_full_paged_editor.gd"
## Independent opt-in setup test. Filtering remains the frozen paged panel.
const BaselineController = preload("res://paged_editor_controller.gd")
const OnceController = preload("res://paged_setup_once_controller.gd")

func controller_class() -> Script: return OnceController

func _setup_case(controller_script: Script, session: Dictionary, source: Dictionary, catalogue: Array, capture_state: bool = false) -> Dictionary:
	var controller: Node = controller_script.new()
	session.world.add_child(controller)
	var start := Time.get_ticks_usec()
	var result: Dictionary = controller.setup(session.composite, source, session.controller.game_camera, Callable(self, "enter"), Callable(self, "leave"), catalogue)
	var elapsed := Time.get_ticks_usec() - start
	if not result.get("ok", false):
		controller.free()
		return {"ok": false, "error": result.get("error", "setup failed")}
	var state := {"catalog_count": controller.panel._catalog.size(), "page_count": controller.panel._page_count, "panel_script": controller.panel.get_script().resource_path}
	if capture_state:
		var visible: Array = []
		for item: Dictionary in controller.panel._visible_items:
			visible.append([item.get("id"), item.get("label"), item.get("available"), item.get("reason")])
		var categories: Array[String] = []
		for index in controller.panel._category.item_count:
			categories.append(controller.panel._category.get_item_text(index))
		state["document"] = controller.document.to_dictionary()
		state["catalog"] = controller.panel._catalog.duplicate(true)
		state["visible"] = visible
		state["categories"] = categories
		state["selected_id"] = controller.selected_id
	controller.free()
	return {"ok": true, "us": elapsed, "state": state}

func exercise_editor_actions(session: Dictionary, templates: Array) -> void:
	super.exercise_editor_actions(session, templates)
	var source: Dictionary = session.composite.source_document("unified-map-qa")
	var catalogue: Array = session.controller.panel._catalog.duplicate(true)
	check(catalogue.size() == 9901, "same genuine full source setup catalogue")
	var first_base := _setup_case(BaselineController, session, source, catalogue, true)
	var first_once := _setup_case(OnceController, session, source, catalogue, true)
	check(first_base.ok and first_once.ok, "both full controllers setup")
	if not first_base.ok or not first_once.ok: return
	check(first_base.state == first_once.state, "once setup preserves full document/catalogue/panel")
	var base_us: Array[int] = []
	var once_us: Array[int] = []
	for pair in 4:
		var base: Dictionary
		var once: Dictionary
		if pair % 2 == 0:
			base = _setup_case(BaselineController, session, source, catalogue)
			once = _setup_case(OnceController, session, source, catalogue)
		else:
			once = _setup_case(OnceController, session, source, catalogue)
			base = _setup_case(BaselineController, session, source, catalogue)
		check(base.ok and once.ok, "paired full setup " + str(pair))
		if not base.ok or not once.ok: continue
		check(base.state == once.state, "paired final setup parity " + str(pair))
		if pair > 0:
			base_us.append(base.us)
			once_us.append(once.us)
	print("PAGED_SETUP_CPU_BENCHMARK ", JSON.stringify({"source_ids": catalogue.size(), "baseline_setup_us": base_us, "once_setup_us": once_us, "warmup_pairs": 1, "gpu": false, "production_wired": false}))
