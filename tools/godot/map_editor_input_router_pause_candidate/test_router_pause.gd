extends SceneTree
## Engine input/processing semantics fixture, NOT an actual-main editor lease.
const Router = preload("res://router_v2.gd")
class Game extends Node3D:
	var process_ticks := 0
	var input_ticks := 0
	func _process(_delta: float) -> void: process_ticks += 1
	func _unhandled_input(_event: InputEvent) -> void: input_ticks += 1
class RouteHost extends RefCounted:
	var game: Game
	var deliveries := 0
	var lease := false
	func is_mounted_owner(node: Node) -> bool:
		return is_instance_valid(game) and node == game and not game.is_queued_for_deletion()
	func handle_input(event: InputEvent) -> bool:
		if not event is InputEventKey or event.physical_keycode != KEY_K or not event.pressed or event.echo: return false
		deliveries += 1
		lease = not lease
		game.get_tree().paused = lease
		return true
var failures: Array[String] = []
var checks := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game := Game.new()
	root.add_child(game)
	var host := RouteHost.new()
	host.game = game
	var router := Router.new()
	game.add_child(router)
	check(router.configure(game,host).ok,"actual original router contract configured")
	check(router.process_mode == Node.PROCESS_MODE_ALWAYS and game.process_mode != Node.PROCESS_MODE_ALWAYS,"only router explicitly ALWAYS")
	await process_frame
	root.push_input(key(KEY_K))
	check(paused and host.lease and host.deliveries == 1,"K enters engine pause")
	var ticks := game.process_ticks
	var inputs := game.input_ticks
	for i in 4: await create_timer(.03,true).timeout
	check(game.process_ticks == ticks,"game parent callbacks stopped by real SceneTree pause")
	root.push_input(key(KEY_W))
	check(game.input_ticks == inputs and host.deliveries == 1,"ordinary game unhandled input not delivered while paused")
	root.push_input(key(KEY_K))
	check(not paused and not host.lease and host.deliveries == 2,"same router receives K and exits while parent was paused")
	game.queue_free()
	check(not router.route(key(KEY_K)) and host.deliveries == 2,"queued owner rejects stale K")
	paused = false
	for failure in failures: push_error(failure)
	print(JSON.stringify({"suite":"editor-router-scene-pause-boundary","checks":checks,"failures":failures,"fixtureOnly":true,"actualMainLease":false,"productionInstalled":false,"gpu":false}))
	quit(0 if failures.is_empty() else 1)
