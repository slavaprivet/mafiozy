extends "res://scripts/map_editor/editor_controller.gd"
## Opt-in setup-only panel substitution. No active editor/workspace replacement.
const PagedPanel = preload("res://paged_editor_panel.gd")

func setup(index: RefCounted, source: Dictionary, player_camera: Camera3D, begin_edit: Callable, end_edit: Callable, catalogue: Array = []) -> Dictionary:
	# This adapter is initial construction only, before workspace/host handlers.
	if active or atomic_install_active or registry!=null or panel!=null or camera!=null or outline!=null:
		return {"ok":false,"error":"Постраничная панель подключается только при первоначальном создании редактора"}
	var result: Dictionary = super.setup(index,source,player_camera,begin_edit,end_edit,catalogue)
	if not result.get("ok",false): return result
	# The synchronous inherited setup owns this exact newly constructed panel.
	# No await/callback or host-facing successful return occurs before replacement.
	var owned_base: CanvasLayer = panel
	owned_base.action_requested.disconnect(handle_action)
	remove_child(owned_base)
	owned_base.free()
	panel = PagedPanel.new()
	# Preserve original pre-tree setup compatibility: decorate only after this
	# exact owned panel builds, without deferring the panel substitution itself.
	panel.ready.connect(_finish_owned_panel,CONNECT_ONE_SHOT)
	add_child(panel)
	panel.set_catalog(catalogue)
	panel.action_requested.connect(handle_action)
	return result

func _finish_owned_panel() -> void:
	var select_button := Button.new()
	select_button.text = "Выбрать на карте"
	select_button.focus_mode = Control.FOCUS_NONE
	select_button.pressed.connect(func():
		panel.action_requested.emit("select_existing",{"catalog_id":panel._selected_id}))
	var box: Node = panel._catalog_list.get_parent()
	box.add_child(select_button)
	box.move_child(select_button,panel._catalog_list.get_index()+2)
	for label: Node in panel._root.find_children("*","Label",true,false):
		if "ЛКМ — выбрать / разместить" in label.text:
			label.text = label.text.replace("ЛКМ — выбрать / разместить","ЛКМ — выбрать объект на карте\nКаталог → Выбрать на карте — выбрать существующий\nДобавить выбранный объект — создать копию перед камерой")

func select_existing(id: String) -> Dictionary:
	if not active or atomic_install_active:
		return {"ok":false,"error":"Выбор требует открытого редактора без текущей загрузки карты"}
	if id.is_empty() or not document.has_record(id) or not registry.has_object(id):
		return {"ok":false,"error":"Этот объект отсутствует на карте. Выберите существующий объект."}
	if not registry.is_editable(id):
		return {"ok":false,"error":"Объект защищён: нужен игровой адаптер владельца"}
	var bounds: Variant = registry.world_bounds(id)
	if not bounds is AABB:
		return {"ok":false,"error":"Исходный объект недоступен в сцене"}
	selected_id = id
	panel.set_selection(document.get_record(id))
	outline.show_bounds(bounds)
	return {"ok":true,"id":id}

func handle_action(action: String,payload: Dictionary = {}) -> Dictionary:
	if action!="select_existing": return super.handle_action(action,payload)
	var id: Variant = payload.get("catalog_id","")
	var result: Dictionary = select_existing(id) if id is String else {"ok":false,"error":"Неверный ID объекта"}
	if not result.ok and is_instance_valid(panel): panel.set_status(str(result.error))
	return result
