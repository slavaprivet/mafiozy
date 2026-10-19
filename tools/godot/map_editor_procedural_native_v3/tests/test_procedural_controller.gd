extends SceneTree
const Factory = preload("res://scripts/procedural_factory.gd")
const Registry = preload("res://scripts/procedural_registry.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
const SHA := "82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"
var checks := 0
var failures: Array[String] = []
var lease := false
var _viewport: SubViewport

func _initialize() -> void:
	get_root().size = Vector2i(1280,720)
	call_deferred("_run")

func _scene() -> Dictionary:
	var factory := Factory.new()
	_expect(factory.configure(SHA), "source factory admitted")
	var a: Dictionary = factory.build_exploration()
	var b: Dictionary = factory.build_roads()
	_viewport.add_child(a.root)
	_viewport.add_child(b.root)
	var registry := Registry.new()
	_expect(registry.configure(factory,Callable(self,"_admit")).ok, "native registry admitted")
	return {"factory":factory,"registry":registry,"a":a.root,"b":b.root}

func _run() -> void:
	# Headless main Window is permanently64x64. A real native SubViewport has
	# explicit logical dimensions without creating another GPU/window instance.
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280,720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_root().add_child(_viewport)
	var scene := _scene()
	var registry: RefCounted = scene.registry
	var source: Dictionary = registry.source_document("procedural-controller-qa")
	var camera := Camera3D.new()
	_viewport.add_child(camera)
	var editor := Controller.new()
	_viewport.add_child(editor)
	_expect(editor.setup(registry,source,camera,Callable(self,"_begin"),Callable(self,"_end")).ok, "actual core controller configured")
	editor._save_path = "user://maps/procedural_controller_v3_qa.json"
	var key := InputEventKey.new()
	key.keycode = KEY_K
	key.physical_keycode = KEY_K
	key.pressed = true
	_expect(editor.handle_input(key) and editor.active and lease, "actual K opens and acquires owner lease")
	await process_frame
	await process_frame
	var id := "explore-pine-707"
	var box: AABB = registry.world_bounds(id)
	var center := box.get_center()
	editor.camera.global_position = center + Vector3(0,50,0)
	editor.camera.look_at(center,Vector3.FORWARD)
	var point: Vector2 = editor.camera.unproject_position(center)
	_expect(not editor.panel.is_pointer_over_panel(point), "native logical viewport ray lies outside UI panel")
	var picked: String = editor.select_at(point)
	_expect(not picked.is_empty() and registry.get_record(picked).kind in ["pine","spruce","cedar","birch","oak","willow","cypress"], "actual camera ray selects original tree")
	id = picked
	if id.is_empty():
		print("CONTROLLER_PICK_FAILED")
		quit(1)
		return
	var original: Dictionary = registry.get_record(id)
	_expect(editor.handle_action("move",{"delta":[2,0,0]}).ok, "actual controller move")
	_expect(editor.document.get_record(id).transform.position[0] == original.transform.position[0] + 2, "document/native tree moved together")
	_expect(editor.handle_action("undo").ok and Registry._equal(registry.get_record(id),original), "actual controller tree move undo")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.position = point
	right.pressed = true
	_expect(editor.handle_input(right), "actual right press consumed")
	right.pressed = false
	_expect(editor.handle_input(right) and not editor.document.has_record(id) and registry.world_bounds(id) == null, "actual RMB short-click deletes original tree")
	_expect(editor.handle_action("undo").ok and editor.document.has_record(id) and registry.world_bounds(id) is AABB, "actual RMB deletion undo")
	_expect(editor.handle_action("camera_top").ok and editor.camera.mode == "top", "actual top view")
	_expect(editor.handle_action("camera_fly").ok and editor.camera.mode == "fly", "actual flight view")
	_expect(editor.handle_action("add",{"catalog_id":id}).ok, "actual palette adds source tree template")
	var copy_id: String = editor.selected_id
	_expect(copy_id.begins_with("editor:") and registry.has_object(copy_id), "palette assigns new stable editor ID")
	_expect(editor.handle_action("undo").ok and not editor.document.has_record(copy_id), "palette addition undo")
	_expect(editor.handle_action("redo").ok and editor.document.has_record(copy_id), "palette addition redo")
	_expect(editor.handle_action("save").ok, "actual core MapStore saves file")
	var loaded: Dictionary = Store.load_document(editor._save_path)
	_expect(loaded.ok and loaded.document.objects.size() == 9395, "actual saved file reload contains tree copy")
	var fresh := _scene()
	var fresh_camera := Camera3D.new()
	_viewport.add_child(fresh_camera)
	var fresh_editor := Controller.new()
	_viewport.add_child(fresh_editor)
	_expect(fresh_editor.setup(fresh.registry,fresh.registry.source_document(source.map_id),fresh_camera,Callable(self,"_begin"),Callable(self,"_end")).ok, "fresh actual controller source admitted")
	_expect(fresh_editor.enter_editor().ok and fresh_editor.install_document(loaded.document).ok, "actual core freshload recreates new template copy")
	_expect(fresh.registry.has_object(copy_id) and fresh_editor.document.has_record(copy_id), "fresh scene and MapDoc copy IDs agree")
	_expect(editor.handle_input(key) and not editor.active, "K exit invokes gameplay owner rebuild lease")
	print("PROCEDURAL_CONTROLLER_QA ",JSON.stringify({"checks":checks,"failures":failures,"originalTreeSelected":id,"copiedId":copy_id,"savedObjects":loaded.document.objects.size(),"savePath":ProjectSettings.globalize_path(editor._save_path),"scope":"actual native headless Controller input/MapDoc/MapStore, owner gates mocked; GPU visuals and real collider rebuild pending"}))
	editor.free()
	fresh_editor.free()
	camera.free()
	fresh_camera.free()
	scene.a.free()
	scene.b.free()
	fresh.a.free()
	fresh.b.free()
	quit(0 if failures.is_empty() else 1)

func _begin() -> Dictionary:
	lease = true
	return {"ok":true}

func _end(_document: Dictionary) -> Dictionary:
	lease = false
	return {"ok":true}

func _admit(request: Dictionary) -> Dictionary:
	if request.dryRun: return {"approved":true}
	return {"approved":true,"commit":Callable(self,"_accept"),"rollback":Callable(self,"_noop")}

func _accept() -> bool: return true
func _noop() -> void: pass

func _expect(condition: bool,message: String) -> void:
	checks += 1
	if not condition and failures.size() < 40: failures.append(message)
