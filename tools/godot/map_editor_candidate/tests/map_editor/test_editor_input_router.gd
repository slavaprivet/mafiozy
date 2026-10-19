extends SceneTree
const Router = preload("res://scripts/map_editor/editor_input_router.gd")
const Host = preload("res://scripts/map_editor/editor_host_adapter.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
class Workspace extends Node:
	var editor: Node
	func handle_input(event: InputEvent) -> bool: return editor.handle_input(event)
var checks := 0
var failures: Array[String] = []
var owner: Node3D
var held := false
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func key(code: Key, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	return event
func pause(request: Dictionary) -> Dictionary:
	held = true
	owner.set_process_input(false)
	owner.set_process_unhandled_input(false)
	owner.set_process(false)
	owner.set_physics_process(false)
	return {"ok": true, "receipt": {"owner_id": request.owner_id, "request_id": request.request_id, "token": "input-routing-fixture"}}
func resume(receipt: Dictionary, _objects: Dictionary, _ground: Dictionary) -> Dictionary:
	held = false
	return {"ok": true, "owner_id": receipt.owner_id, "request_id": receipt.request_id}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	owner = Node3D.new()
	root.add_child(owner)
	var workspace := Workspace.new()
	owner.add_child(workspace)
	var game := Camera3D.new()
	owner.add_child(game)
	game.make_current()
	var host := Host.new()
	var callbacks := {"pause_gameplay": pause, "cancel_pause": func(_r: Dictionary) -> bool: held=false; return true, "verify_pause": func(_r: Dictionary) -> bool: return held, "resume_gameplay": resume, "transaction_ready": func(_r: Dictionary) -> bool: return held, "ground_patch": func() -> Dictionary: return {}}
	check(host.mount(owner,callbacks).ok, "explicit host mounted")
	var editor := Controller.new()
	workspace.editor = editor
	workspace.add_child(editor)
	var registry := Registry.new()
	check(editor.setup(registry,registry.source_document("input-router-qa"),game,host.enter,host.leave).ok, "actual controller mounted")
	check(host.bind_workspace(workspace).ok, "workspace explicitly bound")
	var router := Router.new()
	owner.add_child(router)
	check(router.configure(owner,host).ok and router.is_processing_input(), "independent early router enabled")
	check(not router.configure(owner,host).ok, "duplicate router configuration refused")
	var foreign := Node3D.new()
	root.add_child(foreign)
	var alien := Router.new()
	foreign.add_child(alien)
	check(not alien.configure(foreign,host).ok, "foreign host owner rejected")
	await process_frame
	root.push_input(key(KEY_K))
	check(editor.active and held and host.gameplay_blocked(), "actual viewport K enters and holds gameplay")
	check(not owner.is_processing_input() and not owner.is_processing_unhandled_input() and not owner.is_processing() and not owner.is_physics_processing() and router.is_processing_input(), "router survives stopped owner flags")
	root.push_input(key(KEY_K,true))
	check(editor.active and held, "key repeat does not exit editor")
	root.push_input(key(KEY_K))
	check(not editor.active and not held and not host.gameplay_blocked(), "actual viewport K exits while main input disabled")
	check(not router.route(key(KEY_W)), "ordinary gameplay input remains untouched outside editor")
	owner.remove_child(router)
	foreign.add_child(router)
	check(not router.route(key(KEY_K)) and not editor.active, "reparented router cannot control old owner")
	foreign.remove_child(router)
	owner.add_child(router)
	check(router.route(key(KEY_K)) and editor.active, "original exact parent restored")
	check(router.route(key(KEY_K)) and not editor.active, "original owner exits normally")
	owner.free()
	foreign.free()
	for failure in failures: push_error(failure)
	print(JSON.stringify({"suite": "editor-early-input-router", "checks": checks, "failures": failures, "productionWired": false, "lease": "test fixture", "input": "native viewport push_input"}))
	quit(0 if failures.is_empty() else 1)
