extends SceneTree
const Tx = preload("res://scripts/map_editor/ordinary_building_tx.gd")
const Inventory = preload("res://scripts/map_editor/native_building_inventory.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
const PRINTSHOP := "REBUILD-VISUAL-print_shop-001"
class FixtureToken extends RefCounted:
	var checks := 0
	var commits := 0
	var rollbacks := 0
	var refuse_commit := false
	func verify() -> Dictionary:
		checks += 1
		return {"ok": true, "ready": true, "pending": false}
	func commit(_new_state: Dictionary) -> Dictionary:
		commits += 1
		return {"ok": not refuse_commit, "ready": not refuse_commit, "pending": false}
	func rollback() -> Dictionary:
		rollbacks += 1
		return {"ok": true, "ready": true, "pending": false}
var checks := 0
var failures: Array[String] = []
var issued: Array[FixtureToken] = []
var deny_traffic_commit := false
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func lease(request: Dictionary, domain: String) -> Dictionary:
	if not request.has("source_id") or request.source_id != HOUSE: return {"ok": false}
	var token := FixtureToken.new()
	token.refuse_commit = deny_traffic_commit and domain == "traffic"
	issued.append(token)
	return {"ok": true, "token": token}
func grants() -> Dictionary:
	return {"pause": Callable(self,"lease").bind("pause"), "terrain": Callable(self,"lease").bind("terrain"), "navigation": Callable(self,"lease").bind("navigation"), "traffic": Callable(self,"lease").bind("traffic")}
func run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	for _frame in 120:
		if bool(main.get("preview_ready")): break
		await physics_frame
	check(bool(main.get("preview_ready")),"actual checkpoint main ready")
	var tx := Tx.new()
	check(not tx.select(main,PRINTSHOP).get("ok",false),"Printshop protected")
	tx = Tx.new()
	var selected: Dictionary = tx.select(main,HOUSE)
	check(selected.get("ok",false) and selected.get("sibling_bodies",0)==2,"actual house plus two sibling bodies selected")
	var inspector := Inventory.new()
	paused = true
	await process_frame
	var original := inspector.fingerprint(main)
	var unleased: Dictionary = tx.move(Vector3(1,0,0))
	check(not unleased.get("ok",false) and unleased.get("error","")=="missing-owner-lease:pause","missing leases refuse before mutation")
	check(inspector.fingerprint(main)==original,"missing lease leaves entire main unchanged")
	var house: Node3D = tx._row.visual
	var bodies: Array = tx._row.native_sibling_bodies
	var initial_root := house.global_transform
	var initial_bodies: Array = bodies.map(func(body: StaticBody3D): return body.global_transform)
	var moved: Dictionary = tx.move(Vector3(1.25,0,-0.5),grants())
	check(moved.get("ok",false),"synthetic four-lease move exercises native transaction")
	check(house.global_transform.origin==initial_root.origin+Vector3(1.25,0,-0.5),"root moved exact delta")
	for index in bodies.size(): check(bodies[index].global_transform.origin==initial_bodies[index].origin+Vector3(1.25,0,-0.5),"sibling moved exact delta "+str(index))
	var before_rotate_root := house.global_transform
	var before_rotate_bodies: Array = bodies.map(func(body: StaticBody3D): return body.global_transform)
	var rotation := Basis(Vector3.UP,deg_to_rad(30.0))
	var delta := Transform3D(rotation,before_rotate_root.origin-rotation*before_rotate_root.origin)
	check(tx.rotate(deg_to_rad(30.0),grants()).get("ok",false),"synthetic four-lease rotate")
	check(house.global_transform==delta*before_rotate_root,"root rotated around exact pivot")
	for index in bodies.size(): check(bodies[index].global_transform==delta*before_rotate_bodies[index],"sibling rotated exact delta "+str(index))
	var before_delete := inspector.fingerprint(main)
	check(tx.delete(grants()).get("ok",false),"synthetic four-lease delete")
	check(not house.visible,"source root hidden without free")
	for body: StaticBody3D in bodies: check(body.collision_layer==0 and body.collision_mask==0,"sibling collision disabled")
	check(tx.undo(grants()).get("ok",false),"synthetic four-lease undo")
	check(inspector.fingerprint(main)==before_delete,"undo restores exact root+sibling subtree")
	check(tx.redo(grants()).get("ok",false),"synthetic four-lease redo")
	check(not house.visible,"redo restores deleted visual state")
	for body: StaticBody3D in bodies: check(body.collision_layer==0 and body.collision_mask==0,"redo restores deleted sibling collision state")
	check(tx.undo(grants()).get("ok",false),"second undo restores after redo")
	check(inspector.fingerprint(main)==before_delete,"redo/undo round trip preserves full native scene fingerprint")
	check(str(house.get_meta("source_id", ""))==HOUSE,"root source ID preserved")
	for body: StaticBody3D in bodies: check(str(body.get_meta("source_id", ""))==HOUSE,"sibling source ID preserved")
	var before_fail := inspector.fingerprint(main)
	deny_traffic_commit = true
	var denied: Dictionary = tx.move(Vector3(0.5,0,0),grants())
	check(not denied.get("ok",false) and denied.get("rolled_back",false),"traffic commit failure rolls back")
	check(inspector.fingerprint(main)==before_fail,"failed commit exact scene rollback")
	deny_traffic_commit = false
	check(tx.move(Vector3(0.25,0,0),grants()).get("ok",false),"new move after undo succeeds")
	check(tx.redo(grants()).get("error","")=="empty-redo","new branch invalidates redo")
	paused = false
	main.free()
	var report := {"checks":checks,"failures":failures,"fixtureLeaseTokens":issued.size(),"actualOwnerLeaseAdmitted":false,"productionModified":false,"gpu":false}
	print(JSON.stringify(report))
	if not failures.is_empty():
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
