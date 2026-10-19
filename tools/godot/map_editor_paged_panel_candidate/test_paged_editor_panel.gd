extends SceneTree
const PagedPanel = preload("res://paged_editor_panel.gd")
const OldPanel = preload("res://scripts/map_editor/editor_panel.gd")
const CatalogUI = preload("res://scripts/map_editor/catalog_ui.gd")
class SourceIndex extends RefCounted:
	func has_object(_id: String) -> bool: return true
	func is_editable(_id: String) -> bool: return true
var checks := 0
var failures := []
var actions := []
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func find_button(node: Node,text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found := find_button(child,text)
		if found!=null: return found
	return null
func ids(panel: CanvasLayer) -> Array:
	return panel._visible_items.map(func(item): return item.get("id",""))
func category(panel: CanvasLayer,label: String) -> void:
	for i in panel._category.item_count:
		if panel._category.get_item_text(i)==label:
			panel._category.select(i)
			panel._refresh()
			return
	check(false,"category exists: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var panel := PagedPanel.new()
	# Before-tree catalog set must survive inherited build.
	panel.set_catalog([{"id":"pre-ready","label":"До открытия"}])
	root.add_child(panel)
	check(ids(panel)==["pre-ready"],"before ready cache/build")
	panel.action_requested.connect(func(a,p): actions.append({"action":a,"payload":p.duplicate(true)}))
	var old := OldPanel.new()
	root.add_child(old)
	var synthetic := []
	for i in 321:
		synthetic.append({"id":"duplicate-id-%03d"%i,"label":"Одинаковый дом","category":"Дома","available":i!=320,"reason":"защищён владельцем"})
	synthetic.append({"id":"tree-unique","label":"Лесная сосна","category":"Декор"})
	panel.set_catalog(synthetic)
	old.set_catalog(synthetic)
	check(panel._page_count==3 and panel._match_count==322,"duplicate-label pagination")
	check(ids(panel)==ids(old),"page0 original matching order")
	check(panel._previous_page.disabled and not panel._next_page.disabled,"first page controls")
	panel._catalog_selected(159)
	find_button(panel,"Добавить выбранный объект").pressed.emit()
	check(actions.back()=={"action":"add","payload":{"catalog_id":"duplicate-id-159"}},"original add signal and ID")
	panel._next_page.pressed.emit()
	check(panel._page==1 and panel._catalog_list.item_count==160 and ids(panel)[0]=="duplicate-id-160","next actual button")
	check(panel._selected_id=="","offpage selection clears, cannot accidentally add wrong item")
	panel._next_page.pressed.emit()
	check(panel._page==2 and panel._catalog_list.item_count==2 and panel._next_page.disabled,"last actual button")
	check(panel._catalog_list.is_item_disabled(0) and panel._catalog_list.get_item_text(0).ends_with("защищён владельцем"),"availability/refusal reason preserved")
	panel._catalog_selected(0)
	check(panel._selected_id=="","programmatic disabled selection cannot add")
	panel._catalog_selected(1)
	panel._refresh()
	check(panel._selected_id=="tree-unique","same page selection retained")
	panel._catalog[321].available = false
	panel._catalog[321].reason = "новый запрет"
	panel._refresh()
	check(panel._selected_id=="" and panel._catalog_list.is_item_disabled(1) and panel._catalog_list.get_item_text(1).ends_with("новый запрет"),"availability not cached")
	panel._search.text = " DUPLICATE-ID-300 "
	panel._refresh()
	check(panel._page==0 and ids(panel)==["duplicate-id-300"],"case-insensitive stripped ID search reaches beyond160")
	check("ID: duplicate-id-300" in panel._catalog_list.get_item_tooltip(0),"ID tooltip distinguishes duplicate labels")
	panel._catalog_selected(0)
	find_button(panel,"Добавить выбранный объект").pressed.emit()
	check(actions.back().payload.catalog_id=="duplicate-id-300","late-page actual ID add signal")
	for query in ["", "ДОМ", "сосна", "not-present"]:
		panel._search.text = query
		old._search.text = query
		panel._refresh()
		old._refresh()
		check(ids(panel)==ids(old),"old label semantics: "+query)
	panel._search.text = ""
	old._search.text = ""
	category(panel,"Декор")
	category(old,"Декор")
	check(ids(panel)==ids(old),"original category semantics")
	panel.set_catalog([])
	check(panel._page_count==1 and panel._catalog_list.item_count==0 and "0–0" in panel._result_count.text,"empty result bounds")
	panel.set_page(100000)
	check(panel._page==0,"empty/out-of-range clamps")
	panel._search.text = ""
	var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var built: Dictionary = CatalogUI.build(actual,SourceIndex.new())
	check(built.ok and built.total==9901,"actual9901 source catalog inventory")
	var supplied: Array = built.items.duplicate(true)
	panel.set_catalog(supplied)
	supplied[0].available = false
	check(panel._catalog[0].available,"set_catalog deep detach retains old host semantics")
	var seen := {}
	var total := 0
	var before := Time.get_ticks_usec()
	for page in panel._page_count:
		panel.set_page(page)
		check(panel._catalog_list.item_count<=160,"bounded actual ItemList")
		for item in panel._visible_items:
			check(not seen.has(item.id),"actual source ID appears once")
			seen[item.id] = true
			total += 1
	check(total==9901 and seen.size()==9901 and panel._page_count==62,"all9901 source IDs reachable across62 pages")
	var traversal_usec := Time.get_ticks_usec()-before
	panel.set_page(100000)
	check(panel._page==61 and panel._catalog_list.item_count==141,"actual final page clamps and last141 objects")
	panel.set_page(-100000)
	check(panel._page==0 and panel._catalog_list.item_count==160,"negative page clamps")
	var last_id := str(built.items.back().id)
	panel._search.text = last_id
	panel._refresh()
	check(ids(panel).has(last_id),"actual last original ID searchable")
	panel.set_catalog([{"id":"replacement","label":"Новый каталог","category":"Другое"}])
	panel._search.text = "replacement"
	panel._refresh()
	check(ids(panel)==["replacement"],"set_catalog search cache invalidation")
	panel.set_active(true)
	await process_frame
	panel._search.grab_focus()
	check(panel.is_text_focused(),"inherited text focus guard")
	check(panel.is_pointer_over_panel(panel._root.get_global_rect().get_center()),"inherited pointer guard")
	panel.set_active(false)
	check(not panel.is_text_focused() and not panel.is_pointer_over_panel(panel._root.get_global_rect().get_center()),"inactive focus/pointer guards")
	check(panel._previous_page.focus_mode==Control.FOCUS_NONE and panel._next_page.focus_mode==Control.FOCUS_NONE,"page buttons do not capture game keyboard")
	panel.free()
	old.free()
	print("PAGED_PANEL "+JSON.stringify({"checks":checks,"failures":failures,"actualObjects":total,"pages":62,"fullTraversalUsec":traversal_usec,"GPU":false}))
	quit(0 if failures.is_empty() else 1)
