extends SceneTree
const Traffic = preload("res://scripts/map_editor/linked_stationary_bay_owner.gd")
const Building = preload("res://scripts/map_editor/ordinary_building_tx.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-004"
class StubToken extends RefCounted:
	func verify() -> Dictionary: return {"ok":true,"ready":true,"pending":false}
	func commit(_row: Dictionary) -> Dictionary: return {"ok":true,"ready":true,"pending":false}
	func rollback() -> Dictionary: return {"ok":true,"ready":true,"pending":false}
var checks := 0
var failures: Array[String] = []
var traffic: RefCounted
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func stub(_request: Dictionary) -> Dictionary: return {"ok":true,"token":StubToken.new()}
func traffic_lease(request: Dictionary) -> Dictionary: return traffic.lease(request)
func grants() -> Dictionary:
	return {"pause":Callable(self,"stub"),"terrain":Callable(self,"stub"),"navigation":Callable(self,"stub"),"traffic":Callable(self,"traffic_lease")}
func run() -> void:
	var main: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for frame in 120:
		if bool(main.get("preview_ready")): break
		await physics_frame
	check(bool(main.get("preview_ready")),"actual main ready")
	traffic = Traffic.new()
	check(traffic.configure(main).get("ok",false),"real parked-car route owner configured")
	var tx := Building.new()
	var selection: Dictionary = tx.select(main,HOUSE)
	check(selection.get("ok",false) and selection.get("sibling_bodies",0)==2,"actual ordinary building source+siblings selected")
	var car: RigidBody3D = main.preview_transport.body
	var initial_car := car.global_transform
	var initial_record: Dictionary = main.preview_transport.runtime.host.vehicle_record(main.preview_transport._vehicle_ref)
	var initial_route: Dictionary = traffic.route_plan()
	var original := tx._row.visual.global_transform
	paused = true
	await process_frame
	var moved: Dictionary = tx.move(Vector3(.25,0,0),grants())
	check(moved.get("ok",false),"actual building tx + real traffic token fixed move")
	check(tx._row.visual.global_transform == original.translated(Vector3(.25,0,0)),"building moved exact delta")
	check(traffic.route_plan() != initial_route,"walking route publication changed")
	check(car.global_transform == initial_car and main.preview_transport.runtime.host.vehicle_record(main.preview_transport._vehicle_ref) == initial_record,"parked native/logical car unchanged")
	var undone: Dictionary = tx.undo(grants())
	check(undone.get("ok",false) and tx._row.visual.global_transform == original and traffic.route_plan() == initial_route,"building and route undo together")
	var redone: Dictionary = tx.redo(grants())
	check(redone.get("ok",false) and tx._row.visual.global_transform == original.translated(Vector3(.25,0,0)) and traffic.route_plan() != initial_route,"building and route redo together")
	var again: Dictionary = tx.undo(grants())
	check(again.get("ok",false) and tx._row.visual.global_transform == original and traffic.route_plan() == initial_route,"second undo restores baseline")
	check(car.global_transform == initial_car and main.preview_transport.runtime.host.vehicle_record(main.preview_transport._vehicle_ref) == initial_record,"car preserved across full transaction history")
	check(traffic.dispose(),"route-owner lifecycle cleanup")
	paused = false
	main.queue_free()
	await process_frame
	print("MAP_EDITOR_LINKED_ORDINARY_TX ",JSON.stringify({"checks":checks,"failures":failures,"gpu":false,"synthetic_domains":["pause","terrain","navigation"],"real_domain":"traffic"}))
	quit(0 if failures.is_empty() else 1)
