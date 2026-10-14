extends SceneTree
## Original frozen router negative: source is not edited. Fixture pause only.
const Router = preload("res://scripts/map_editor/editor_input_router.gd")
class Host extends RefCounted:
	var owner: Node
	var calls := 0
	func is_mounted_owner(node: Node) -> bool: return node == owner
	func handle_input(event: InputEvent) -> bool:
		if event is InputEventKey and event.physical_keycode == KEY_K and event.pressed:
			calls += 1
			owner.get_tree().paused = calls == 1
			return true
		return false
var failures: Array[String] = []
var checks := 0
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func k() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_K
	event.pressed = true
	return event
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var owner := Node3D.new()
	root.add_child(owner)
	var host := Host.new(); host.owner = owner
	var router := Router.new(); owner.add_child(router)
	check(router.configure(owner,host).ok,"frozen source router configured")
	check(router.process_mode == Node.PROCESS_MODE_INHERIT,"frozen router inherits pausable game parent")
	root.push_input(k())
	check(paused and host.calls == 1,"initial K enters fixture pause")
	root.push_input(k())
	check(paused and host.calls == 1,"negative reproduced: original router cannot receive K during tree pause")
	paused = false
	owner.free()
	for failure in failures: push_error(failure)
	print(JSON.stringify({"suite":"frozen-original-router-pause-negative","checks":checks,"failures":failures,"negativeReproduced":failures.is_empty(),"fixtureOnly":true,"productionInstalled":false,"gpu":false}))
	quit(0 if failures.is_empty() else 1)
