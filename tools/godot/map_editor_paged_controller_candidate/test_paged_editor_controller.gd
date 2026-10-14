extends SceneTree
const Adapter = preload("res://paged_editor_controller.gd")
const Original = preload("res://scripts/map_editor/editor_controller.gd")
const Factory = preload("res://scripts/map_editor/catalog_factory.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const CatalogUI = preload("res://scripts/map_editor/catalog_ui.gd")
const Workspace = preload("res://scripts/map_editor/editor_workspace.gd")
const GroundPanel = preload("res://ground_panel.gd")
const TrustedJSON = preload("res://scripts/map_editor/trusted_json.gd")
class Probe extends "res://paged_editor_controller.gd":
	var action_calls := 0
	func handle_action(action: String,payload: Dictionary = {}) -> Dictionary:
		action_calls += 1
		return super.handle_action(action,payload)
class BrushFixture extends RefCounted:
	signal status_changed(message: String)
	signal committed(result: Dictionary)
	var active := false
	func set_active(value: bool) -> void: active = value
	func handle_input(_event: InputEvent,_camera: Camera3D,_guard: Callable) -> bool: return false
	func cancel_preview() -> void: pass
	func focus_lost() -> void: pass
class RendererFixture extends Node:
	func finalize(_committed: bool) -> Dictionary: return {"ok":true}
var checks := 0
var failures := []
var enters := 0
var exits := 0
var persistence_calls := []
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func begin() -> Dictionary:
	enters += 1
	return {"ok":true}
func end(_doc: Dictionary) -> Dictionary:
	exits += 1
	return {"ok":true}
func persist(action: String,_payload: Dictionary) -> Dictionary:
	persistence_calls.append(action)
	return {"ok":true}
func ready_gate() -> bool: return true
func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
func press(panel: CanvasLayer,label: String) -> bool:
	for button in panel._root.find_children("*","Button",true,false):
		if button.text==label:
			button.pressed.emit()
			return true
	return false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var factory := Factory.new()
	check(factory.configure(catalog),"actual source factory admission")
	var registry := Registry.new()
	var house: Node3D
	var house_id := "buildings:REBUILD-VISUAL-old_town_narrow_townhouse_v1-001"
	var bank_id := "buildings:REBUILD-bank:large"
	var protected_count := 0
	for item: Dictionary in catalog.objects:
		if not item.has("resourceId"): continue
		var built: Dictionary = factory.spawn_key(item.key,{"exterior_collisions":true})
		check(built.ok,"actual original GLB source placement")
		world.add_child(built.root)
		check(registry.register_object(item.key,built.root,{"kind":item.dataset,"model":item.resourceId,"source":item.sourceRecord.duplicate(true)},[],built.pending.is_empty()).ok,"real registry source authority")
		if not built.pending.is_empty(): protected_count += 1
		if item.key==house_id: house = built.root
	check(registry.ids().size()==242 and factory.loads==33 and is_instance_valid(house),"actual242 objects/33 models")
	var ui: Dictionary = CatalogUI.build(catalog,registry)
	check(ui.ok and ui.total==9901 and ui.admitted==242-protected_count,"actual native availability, no synthetic source index")
	var source: Dictionary = registry.source_document("paged-adapter-native")
	var rejected := Adapter.new()
	world.add_child(rejected)
	check(not rejected.setup(null,source,camera,begin,end,ui.items).ok,"inherited invalid registry refusal")
	check(rejected.panel==null and rejected.camera==null and rejected.outline==null and rejected.get_child_count()==0,"refusal creates no owned UI/camera")
	var invalid_source := source.duplicate(true)
	invalid_source.schema_version = -1
	check(not rejected.setup(registry,invalid_source,camera,begin,end,ui.items).ok,"inherited document admission")
	check(rejected.registry==null and rejected.panel==null,"bad source does not partially swap UI")
	rejected.free()
	var detached := Adapter.new()
	check(detached.setup(registry,source,camera,begin,end,ui.items).ok and detached.panel.get_child_count()==0,"original pre-tree setup remains supported")
	world.add_child(detached)
	check(press(detached.panel,"Выбрать на карте"),"pre-tree owned panel decorates once on ready")
	detached.free()
	var original := Original.new()
	world.add_child(original)
	check(original.setup(registry,source,camera,begin,end,ui.items).ok,"reference original setup")
	var editor := Probe.new()
	world.add_child(editor)
	check(editor.setup(registry,source,camera,begin,end,ui.items).ok,"opt-in inherited setup + only owned panel substitution")
	check(TrustedJSON.equal(editor.document.to_dictionary(),original.document.to_dictionary()) and TrustedJSON.equal(editor._baseline,original._baseline),"document and immutable baseline exact original setup")
	check(editor.registry==original.registry and editor.game_camera==camera and not editor.active and not editor.is_processing(),"registry/game camera/inactive state preserved")
	check(editor.camera.get_script()==original.camera.get_script() and editor.outline.get_script()==original.outline.get_script(),"original camera and outline classes preserved")
	check(editor.get_child_count()==3 and editor.panel.get_parent()==editor and editor.panel.get_script()==preload("res://paged_editor_panel.gd"),"owned base freed, exactly camera/pagedpanel/outline")
	check(editor.panel.action_requested.get_connections().size()==1 and editor.panel.action_requested.is_connected(editor.handle_action),"one inherited action handler before workspace")
	check(editor.panel.mode_requested.get_connections().is_empty(),"no external mode handler during setup")
	var exact_hint := false
	for label: Node in editor.panel._root.find_children("*","Label",true,false):
		if "Каталог → Выбрать на карте" in label.text:
			exact_hint = "ЛКМ — выбрать / разместить" not in label.text and "создать копию перед камерой" in label.text and "ПКМ коротко" in label.text
	check(exact_hint,"owned hint describes actual selection/add, preserves other controls")
	check(editor.panel._catalog.size()==9901 and editor.panel._page_count==62,"full actual catalog in paged panel")
	check(not editor.select_existing(house_id).ok and editor.selected_id=="","inactive selection cannot mutate editor")
	for i in editor.panel._visible_items.size():
		var row: Dictionary = editor.panel._visible_items[i]
		check(row.available==(registry.has_object(row.id) and registry.is_editable(row.id)),"panel preserves actual registry availability")
	var owned_panel := editor.panel
	var owned_camera := editor.camera
	check(not editor.setup(registry,source,camera,begin,end,ui.items).ok and editor.panel==owned_panel and editor.camera==owned_camera,"second setup cannot replace inactive owned session")
	original.free()
	check(editor.handle_input(key(KEY_K)) and editor.active and enters==1,"inherited K enters owner-gated session once")
	editor.selected_id = house_id
	var base_position := house.global_position
	var count := editor.action_calls
	check(press(editor.panel,"X+"),"actual inherited move button")
	check(editor.action_calls==count+1 and house.global_position==base_position+Vector3.RIGHT,"inherited panel action single real house move")
	check(editor.handle_action("undo",{}).ok and house.global_position==base_position,"real undo after panel move")
	editor.panel._search.text = bank_id
	editor.panel._refresh()
	check(editor.panel._visible_items.size()==1 and editor.panel._catalog_list.is_item_disabled(0),"protected actual bank remains disabled")
	editor.panel._catalog_selected(0)
	check(editor.panel._selected_id=="","disabled native bank cannot select for add")
	editor.panel._search.text = house_id
	editor.panel._refresh()
	editor.panel._catalog_selected(0)
	count = editor.action_calls
	check(press(editor.panel,"Добавить выбранный объект") and editor.action_calls==count+1,"actual house template add single handler")
	var clone_id: String = editor.selected_id
	check(clone_id.begins_with("editor:") and registry.has_object(clone_id) and registry.ids().size()==243,"actual resource-sharing native clone via inherited add")
	check(editor.handle_action("undo",{}).ok and not editor.document.has_record(clone_id),"native clone undo")
	check(editor.handle_action("redo",{}).ok and editor.document.has_record(clone_id),"native clone redo")
	var terrain_panel := GroundPanel.new()
	world.add_child(terrain_panel)
	var brush := BrushFixture.new()
	var renderer := RendererFixture.new()
	world.add_child(renderer)
	var workspace := Workspace.new()
	world.add_child(workspace)
	check(workspace.setup(editor,brush,terrain_panel,renderer,persist,ready_gate).ok,"original workspace can bind substituted panel")
	check(editor.panel.action_requested.get_connections().size()==1 and not editor.panel.action_requested.is_connected(editor.handle_action) and editor.panel.action_requested.is_connected(workspace.handle_action),"workspace replaces inherited handler, no duplicate")
	check(editor.panel.mode_requested.get_connections().size()==1 and editor.panel.mode_requested.is_connected(workspace.set_mode),"workspace one mode handler")
	editor.selected_id = house_id
	base_position = house.global_position
	count = editor.action_calls
	check(press(editor.panel,"X+") and editor.action_calls==count+1 and house.global_position==base_position+Vector3.RIGHT,"workspace forwards move exactly once to real object")
	check(press(editor.panel,"Сохранить") and persistence_calls==["save"],"save dispatch exactly once to workspace persistence owner")
	check(press(editor.panel,"Вид сверху") and editor.camera.mode=="top","inherited camera top action through workspace")
	check(press(editor.panel,"Полёт") and editor.camera.mode=="fly","inherited camera fly action through workspace")
	check(press(editor.panel,"Земля и дороги") and workspace.mode=="ground" and not editor.panel._active and terrain_panel._active,"existing mode signal wiring unchanged")
	check(workspace.set_mode("objects").ok and editor.panel._active,"original workspace returns to objects")
	# All labels duplicate; choose a real original object on page2 by source ID.
	var duplicates: Array = ui.items.duplicate(true)
	for row: Dictionary in duplicates: row.label = "Одинаковый объект"
	editor.panel.set_catalog(duplicates)
	editor.panel._search.text = ""
	editor.panel._refresh()
	editor.panel.set_page(1)
	var native_id := "decor:PARK-southside-PLANTER"
	var native_index := -1
	for i in editor.panel._visible_items.size():
		if editor.panel._visible_items[i].id==native_id: native_index = i
	check(native_index>=0 and editor.panel._page==1,"duplicate-label original object reachable on second page")
	editor.panel._catalog_selected(native_index)
	count = editor.action_calls
	var old_camera_frame := editor.camera.global_transform
	check(press(editor.panel,"Выбрать на карте") and editor.action_calls==count+1 and editor.selected_id==native_id,"explicit catalog selection single workspace handler, no ray geometry changes")
	var native_root: Node3D = registry._entries[native_id].root.get_ref()
	var native_frame := native_root.global_transform
	check(editor.outline.visible and editor.camera.global_transform==old_camera_frame,"real bounds outline without camera teleport")
	check(press(editor.panel,"X+") and native_root.global_position==native_frame.origin+Vector3.RIGHT,"explicitly selected actual object moves once")
	check(press(editor.panel,"Отменить") and native_root.global_transform==native_frame,"existing selected native object undo exact")
	var protected_before: String = editor.selected_id
	check(not editor.select_existing(bank_id).ok and editor.selected_id==protected_before,"protected source selection refusal leaves previous selection")
	check(not editor.select_existing("generated:absent").ok and editor.selected_id==protected_before,"absent source selection refusal leaves previous selection")
	check(not editor.handle_action("select_existing",{"catalog_id":42}).ok and editor.selected_id==protected_before,"nonstring ID admission leaves selection")
	editor.atomic_install_active = true
	check(not editor.select_existing(house_id).ok and editor.selected_id==protected_before,"atomic install selection guard")
	editor.atomic_install_active = false
	check(editor.select_existing(clone_id).ok and editor.handle_action("delete",{}).ok,"actual clone deletion for missing-record guard")
	check(editor.select_existing(native_id).ok,"return selection to actual existing source")
	check(not editor.select_existing(clone_id).ok and editor.selected_id==native_id,"deleted clone selection refused without previous selection mutation")
	editor.panel._search.text = bank_id
	editor.panel._refresh()
	editor.panel._catalog_selected(0)
	check(press(editor.panel,"Выбрать на карте") and editor.selected_id==native_id,"disabled catalog item cannot select previous/unrelated object")
	await process_frame
	editor.panel._search.grab_focus()
	check(editor.panel.is_text_focused() and not workspace.handle_input(key(KEY_K)) and editor.active,"K typing guard preserved")
	editor.panel._search.release_focus()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = editor.panel._root.get_global_rect().get_center()
	var selection_before: String = editor.selected_id
	check(not workspace.handle_input(mouse) and editor.selected_id==selection_before,"panel pointer does not pick through UI")
	check(not editor.setup(registry,source,camera,begin,end,ui.items).ok and editor.panel==owned_panel and editor.panel.action_requested.is_connected(workspace.handle_action),"active workspace setup refuses replacement without disconnecting owner")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(editor.document.to_dictionary(),"",true,true))
	var prepared: Dictionary = editor.prepare_install_document(saved)
	check(prepared.ok,"inherited saved document/provenance admission unchanged: "+str(prepared.get("error","")))
	check(workspace.handle_input(key(KEY_K)) and not editor.active and exits==1,"inherited K exits via owner once")
	check(not editor.panel.is_text_focused() and not editor.panel._active,"exit hides paged panel")
	world.free()
	print("PAGED_CONTROLLER "+JSON.stringify({"checks":checks,"failures":failures,"actualSourceObjects":242,"catalogObjects":9901,"realAvailable":ui.admitted,"GPU":false,"groundOwner":"explicit test fixture; native authored registry/factory are actual"}))
	quit(0 if failures.is_empty() else 1)
