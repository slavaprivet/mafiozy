extends RefCounted
## Street furniture uses the existing six-mesh OriginalBench seat contract.
## The bench is not a home, service, money authority, or invented arrival point.
const Registry = preload("res://scripts/npc_ambient/ambient_bench_registry29.gd")
const NAME := "OriginalBenchHome58"

static func install(scene: Node3D, houses: Array) -> Dictionary:
	if not is_instance_valid(scene) or not scene.is_inside_tree() or houses.size()!=4: return {"ok":false,"reason":"four_live_houses_required"}
	var registry: Node=Registry.for_scene(scene)
	var outcomes: Array=[]
	var count:=0
	for value: Variant in houses:
		var house: Node3D=value as Node3D
		var id: String=str(house.get("source_id")) if is_instance_valid(house) else ""
		if not is_instance_valid(house) or not scene.is_ancestor_of(house) or not house.has_method("visual") or not house.global_basis.y.is_equal_approx(Vector3.UP) or not house.global_basis.is_equal_approx(house.global_basis.orthonormalized()):
			outcomes.append({"home_id":id,"ok":false,"reason":"live_upright_house_required"});continue
		var old: Node=house.get_node_or_null(NAME)
		if old!=null:
			var registered: Dictionary=_row(registry,old.get_instance_id())
			var current: bool=not registered.is_empty() and registry.current(registered)
			outcomes.append({"home_id":id,"ok":current,"reused":true});count+=int(current);continue
		var ground: Variant=house.get("native_ground29")
		if not ground is Array or ground.is_empty():outcomes.append({"home_id":id,"ok":false,"reason":"verified_native_ground_required"});continue
		var base: Vector3=house.to_global(Vector3(3.2,0,6.2))
		var space: PhysicsDirectSpaceState3D=scene.get_world_3d().direct_space_state
		var level:=NAN
		var supported:=true
		for offset: Vector3 in [Vector3(-.685,0,-.22),Vector3(.685,0,-.22),Vector3(-.685,0,.26),Vector3(.685,0,.26),Vector3(0,0,.72)]:
			var point: Vector3=base+house.global_basis*offset
			var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP*.5,1))
			if hit.is_empty() or hit.get("collider") not in ground or Vector3(hit.normal).y<.98:
				supported=false;break
			var height: float=Vector3(hit.position).y
			if not is_finite(level):level=height
			elif absf(level-height)>.01:supported=false;break
		if not supported or not is_finite(level):outcomes.append({"home_id":id,"ok":false,"reason":"real_level_leg_and_approach_support_required"});continue
		var frame:=Transform3D(house.global_basis,Vector3(base.x,level+.015,base.z))
		var query:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.8,1.0,.82)
		query.shape=box;query.transform=frame*Transform3D(Basis.IDENTITY,Vector3(0,.55,.02));query.collision_mask=1|2|512
		var excluded: Array[RID]=[]
		for body: StaticBody3D in ground:excluded.append(body.get_rid())
		query.exclude=excluded
		if not space.intersect_shape(query,1).is_empty():outcomes.append({"home_id":id,"ok":false,"reason":"bench_volume_obstructed"});continue
		var bench:=Node3D.new();bench.name=NAME;bench.set_meta("palazzo_bench",true);bench.set_meta("home_street_bench58",id)
		for z: float in [-.16,.04,.24]:house.visual(bench,Vector3(1.7,.10,.15),Vector3(0,.43,z),Color("80634b"))
		for x: float in [-.64,.64]:house.visual(bench,Vector3(.09,.47,.48),Vector3(x,.22,.02),Color("30343a"))
		house.visual(bench,Vector3(1.7,.34,.10),Vector3(0,.83,-.22),Color("80634b"))
		bench.transform=house.global_transform.affine_inverse()*frame
		house.add_child(bench)
		registry._consider(bench)
		var row: Dictionary=_row(registry,bench.get_instance_id())
		var valid: bool=not row.is_empty() and registry.current(row)
		if not valid:bench.queue_free()
		outcomes.append({"home_id":id,"ok":valid,"position":frame.origin,"mesh_count":6,"leg_bottom_y":level,"support":"native_ground29","seat_authority":"AmbientBenchRegistry29"})
		count+=int(valid)
	return {"ok":count==4,"built_or_reused":count,"requested":4,"placements":outcomes,"registry":registry.snapshot(),"native_arrival_and_sit":"PENDING"}

static func _row(registry: Node, id: int) -> Dictionary:
	for row: Dictionary in registry.rows():
		if int(row.bench_id)==id:return row
	return {}
