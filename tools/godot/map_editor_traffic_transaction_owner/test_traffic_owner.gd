extends SceneTree
const Owner = preload("res://scripts/map_editor/traffic_owner.gd")
const LINKED := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-004"
const UNLINKED := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-012"
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func find(main: Node3D, id: String) -> Dictionary:
	var visual: Node3D
	var bodies: Array[StaticBody3D] = []
	for child: Node in main.get_children():
		if str(child.get_meta("source_id", "")) != id: continue
		if child is StaticBody3D: bodies.append(child)
		elif child is Node3D: visual = child
	return {"visual":visual,"bodies":bodies}
func request(main: Node3D, row: Dictionary, id: String, action: String) -> Dictionary:
	return {"source_id":id,"action":action,"old_frame":row.visual.global_transform,"body_count":row.bodies.size(),"owner_instance_id":main.get_instance_id()}
func run() -> void:
	var main: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for frame in 120:
		if bool(main.get("preview_ready")): break
		await physics_frame
	check(bool(main.get("preview_ready")),"actual checkpoint main ready")
	paused = true
	await process_frame
	var owner := Owner.new()
	var setup: Dictionary = owner.configure(main)
	check(setup.get("ok",false),"actual source/transport owner configured")
	var linked := find(main,LINKED)
	var denied: Dictionary = owner.lease(request(main,linked,LINKED,"move"))
	check(not denied.get("ok",false) and denied.get("error","") == "PARKING_REPLAN_REQUIRED","parked townhouse needs full plan publication")
	var unlinked := find(main,UNLINKED)
	check(unlinked.visual != null and unlinked.bodies.size() > 0,"unlinked actual townhouse bound")
	var token_answer: Dictionary = owner.lease(request(main,unlinked,UNLINKED,"delete"))
	check(token_answer.get("ok",false),"unlinked building receives real no-impact traffic token")
	if token_answer.get("ok",false):
		var token: RefCounted = token_answer.token
		check(token.verify().get("ok",false),"token verifies paused source and transport")
		var old_frame: Transform3D = unlinked.visual.global_transform
		unlinked.visual.visible = false
		for body: StaticBody3D in unlinked.bodies:
			body.collision_layer = 0; body.collision_mask = 0
			(body.get_child(0) as CollisionShape3D).disabled = true
		var published: Dictionary = token.commit({"source_id":UNLINKED,"action":"delete","new_frame":old_frame,"deleted":true})
		check(published.get("ok",false) and owner._revision == 1,"deletion publishes reversible traffic no-impact revision")
		check(token.verify().get("ok",false),"committed owner receipt remains valid")
		check(token.rollback().get("ok",false) and owner._revision == 0 and owner._published.is_empty(),"rollback restores traffic publication")
		unlinked.visual.visible = true
		for body: StaticBody3D in unlinked.bodies:
			body.collision_layer = 1; body.collision_mask = 1
			(body.get_child(0) as CollisionShape3D).disabled = false
		var second: Dictionary = owner.lease(request(main,unlinked,UNLINKED,"move"))
		check(second.get("ok",false),"fresh token after rollback")
		if second.get("ok",false):
			var moved: Transform3D = old_frame.translated(Vector3(0,0,200))
			unlinked.visual.global_transform = moved
			for body: StaticBody3D in unlinked.bodies: body.global_transform = body.global_transform.translated(Vector3(0,0,200))
			check(not second.token.commit({"source_id":UNLINKED,"action":"move","new_frame":moved,"deleted":false}).get("ok",false),"outside known traffic crop fails closed")
			check(second.token.rollback().get("ok",false),"rejected move token rolls back")
	paused = false
	var result := {"checks":checks,"failures":failures,"owner_revision":owner._revision,"gpu":false,"claim":"isolated native mechanics only"}
	print("MAP_EDITOR_TRAFFIC_OWNER ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
