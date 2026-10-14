extends SceneTree
const Owner = preload("res://scripts/map_editor/linked_stationary_bay_owner.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-004"
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func find(main: Node3D) -> Dictionary:
	var visual: Node3D
	var bodies: Array[StaticBody3D] = []
	for child: Node in main.get_children():
		if str(child.get_meta("source_id","")) != HOUSE: continue
		if child is StaticBody3D: bodies.append(child)
		elif child is Node3D: visual=child
	return {"visual":visual,"bodies":bodies}
func run() -> void:
	var main: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for frame in 120:
		if bool(main.get("preview_ready")): break
		await physics_frame
	check(bool(main.get("preview_ready")),"actual main with parked car ready")
	paused = true
	await process_frame
	var owner := Owner.new()
	var configured: Dictionary = owner.configure(main)
	print("LINKED_SETUP ",configured)
	check(configured.get("ok",false),"linked source packet and actual bay configured")
	var row := find(main)
	check(row.visual != null and row.bodies.size() == 2,"actual linked building and two collision siblings")
	var before_root: Transform3D = row.visual.global_transform
	var before_bodies: Array = row.bodies.map(func(b: StaticBody3D): return b.global_transform)
	var transport: Node3D = main.get("preview_transport")
	var car: RigidBody3D = transport.get("body")
	var before_car := car.global_transform
	var before_record: Dictionary = transport.runtime.host.vehicle_record(transport.get("_vehicle_ref"))
	var baseline := owner.route_plan()
	var denied: Dictionary = owner.lease({"source_id":HOUSE,"action":"delete","old_frame":before_root,"body_count":2,"owner_instance_id":main.get_instance_id()})
	check(not denied.get("ok",false),"delete with active parked bay refused")
	var issued: Dictionary = owner.lease({"source_id":HOUSE,"action":"move","old_frame":before_root,"body_count":2,"owner_instance_id":main.get_instance_id()})
	check(issued.get("ok",false),"stationary-bay fixed-delta token admitted")
	if issued.get("ok",false):
		var token: RefCounted = issued.token
		check(token.verify().get("ok",false),"paused car and building receipt current")
		var delta := Vector3(.25,0,0)
		row.visual.global_transform = before_root.translated(delta)
		for i in row.bodies.size(): row.bodies[i].global_transform = before_bodies[i].translated(delta)
		var result: Dictionary = token.commit({"source_id":HOUSE,"action":"move","new_frame":row.visual.global_transform,"deleted":false})
		check(result.get("ok",false) and result.get("parked_car_moved",true) == false,"replanned walking-route metadata published without car relocation")
		check(owner.route_plan() != baseline and owner._revision == 1,"route revision changed")
		check(car.global_transform == before_car and transport.runtime.host.vehicle_record(transport.get("_vehicle_ref")) == before_record,"live native and logical car unchanged")
		check(token.verify().get("ok",false),"published receipt remains current")
		check(token.rollback().get("ok",false) and owner.route_plan() == baseline and owner._revision == 0,"route metadata rollback exact")
		row.visual.global_transform = before_root
		for i in row.bodies.size(): row.bodies[i].global_transform = before_bodies[i]
		var again: Dictionary = owner.lease({"source_id":HOUSE,"action":"move","old_frame":before_root,"body_count":2,"owner_instance_id":main.get_instance_id()})
		check(again.get("ok",false),"fresh token after rollback")
		if again.get("ok",false):
			transport.set("phase","SEATED")
			check(not again.token.verify().get("ok",false),"seat/phase drift refuses publication")
			transport.set("phase","ON_FOOT")
			check(again.token.rollback().get("ok",false),"uncommitted drift token cancelled")
		var move_token: Dictionary = owner.lease({"source_id":HOUSE,"action":"move","old_frame":before_root,"body_count":2,"owner_instance_id":main.get_instance_id()})
		check(move_token.get("ok",false),"durable move token admitted")
		if move_token.get("ok",false):
			var redo_delta := Vector3(.25,0,0)
			row.visual.global_transform = before_root.translated(redo_delta)
			for i in row.bodies.size(): row.bodies[i].global_transform = before_bodies[i].translated(redo_delta)
			check(move_token.token.commit({"source_id":HOUSE,"action":"move","new_frame":row.visual.global_transform,"deleted":false}).get("ok",false),"durable route move published")
			var undo_token: Dictionary = owner.lease({"source_id":HOUSE,"action":"undo","old_frame":row.visual.global_transform,"body_count":2,"owner_instance_id":main.get_instance_id()})
			check(undo_token.get("ok",false),"undo token admitted on revised plan")
			if undo_token.get("ok",false):
				row.visual.global_transform = before_root
				for i in row.bodies.size(): row.bodies[i].global_transform = before_bodies[i]
				check(undo_token.token.commit({"source_id":HOUSE,"action":"undo","new_frame":before_root,"deleted":false}).get("ok",false) and owner.route_plan() == baseline,"undo restores baseline routes")
				var redo_token: Dictionary = owner.lease({"source_id":HOUSE,"action":"redo","old_frame":before_root,"body_count":2,"owner_instance_id":main.get_instance_id()})
				check(redo_token.get("ok",false),"redo token admitted")
				if redo_token.get("ok",false):
					row.visual.global_transform = before_root.translated(redo_delta)
					for i in row.bodies.size(): row.bodies[i].global_transform = before_bodies[i].translated(redo_delta)
					check(redo_token.token.commit({"source_id":HOUSE,"action":"redo","new_frame":row.visual.global_transform,"deleted":false}).get("ok",false) and owner.route_plan() != baseline,"redo restores revised routes")
					check(car.global_transform == before_car and transport.runtime.host.vehicle_record(transport.get("_vehicle_ref")) == before_record,"car authority unchanged through move/undo/redo")
					check(redo_token.token.rollback().get("ok",false) and owner.route_plan() == baseline,"last committed route receipt reversible")
					row.visual.global_transform = before_root
					for i in row.bodies.size(): row.bodies[i].global_transform = before_bodies[i]
	paused = false
	main.queue_free()
	await process_frame
	print("MAP_EDITOR_LINKED_BAY ",JSON.stringify({"checks":checks,"failures":failures,"gpu":false,"claim":"fixed-delta route-owner prototype only"}))
	quit(0 if failures.is_empty() else 1)
