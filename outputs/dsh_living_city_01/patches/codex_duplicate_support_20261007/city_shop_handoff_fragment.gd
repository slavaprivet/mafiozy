extends SceneTree
const Policy = preload("res://scripts/city/runtime/npc_city_world_policy.gd")
const Interior = preload("res://scripts/preview_printshop_interior.gd")
const Ground = preload("res://scripts/destruction/palazzo/palazzo_ground.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
class SourceScene:
	extends Node3D
	var _surface_materials := {"8":StandardMaterial3D.new()}
	var _block := {}
	var _origin := Vector3(395.65,0,45.1)
	var block_data_path := "res://data/city_block.json"
class Host:
	extends RefCounted
	var _admit := Callable()
	var token := {}
	var owner: RefCounted
	func _local_walker_current(value: Dictionary) -> bool: return value==token and is_instance_valid(token.body)
	func physical_life_current(value: Dictionary) -> bool: return _local_walker_current(value)
	func daily_activity_status(_id: String) -> Dictionary: return {"current":true,"life_generation":1,"owner":owner}

var _scene: Node3D
var _static_count := 0
func _initialize() -> void: call_deferred("_run")
func _floor(size: Vector3, position: Vector3) -> void:
	var body:=StaticBody3D.new(); body.collision_layer=1
	var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=size; shape.shape=box
	body.add_child(shape); body.position=position; _scene.add_child(body)
func _solid(data: Dictionary) -> void:
	var points:=PackedVector3Array()
	for pair: Array in data.polygonXZ:
		points.append(Vector3(pair[0],data.minY,pair[1])); points.append(Vector3(pair[0],data.maxY,pair[1]))
	var body:=StaticBody3D.new(); body.collision_layer=1
	var shape:=CollisionShape3D.new(); var convex:=ConvexPolygonShape3D.new(); convex.points=points; shape.shape=convex
	body.add_child(shape); _scene.add_child(body); _static_count+=1
func _run() -> void:
	_scene=SourceScene.new(); root.add_child(_scene)
	var block: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/city_block.json"))
	_scene._block=block
	var surface: Dictionary=block.surface
	var floor_count:=0
	for r in int(surface.rows):
		var c:=0
		while c<int(surface.cols):
			var tile:=str(int(surface.grid[r][c])); var palette: Dictionary=surface.palette[tile]
			if not palette.solid: c+=1; continue
			var first:=c
			while c<int(surface.cols) and str(int(surface.grid[r][c]))==tile: c+=1
			_floor(Vector3((c-first)*4.1,.16,4.1),Vector3((int(surface.startCol)+(first+c)*.5)*4.1-Policy.ORIGIN.x,float(palette.heightM)-.08,(int(surface.startRow)+r+.5)*4.1-Policy.ORIGIN.z))
			floor_count+=1
	var ground_install := Ground.install(_scene)
	# Exact authored collision recipe from main.gd; only solids intersecting the
	# source fragment bounding rectangle are instantiated. No render assets.
	var fragment:=Rect2(Vector2(7,3),Vector2(5,6))
	for record: Dictionary in block.buildings+block.decor:
		if record.id==Interior.SOURCE_ID: continue # main replaces these three bodies with the actual interior
		for data: Dictionary in record.get("collisionBodiesM",[]):
			var bounds:=Rect2(); var first:=true
			for pair: Array in data.polygonXZ:
				var point:=Vector2(pair[0],pair[1]); bounds=Rect2(point,Vector2.ZERO) if first else bounds.expand(point); first=false
			if bounds.intersects(fragment): _solid(data)
	var attached:=false
	var interior:=Interior.new(); interior.name="PrintshopInterior"; _scene.add_child(interior)
	for record: Dictionary in block.buildings:
		if record.id!=Interior.SOURCE_ID: continue
		var asset:=load(str(record.path)) as PackedScene
		var parent:=Node3D.new(); parent.name=str(record.id); parent.set_meta("source_id",record.id)
		var placement: Dictionary=record.transform
		parent.position=Vector3(record.positionLocalM[0],record.positionLocalM[1],record.positionLocalM[2]); parent.rotation.y=deg_to_rad(float(placement.yawDegrees))
		var uniform:=float(placement.uniformScale); parent.scale=Vector3(uniform*float(placement.horizontalScale[0]),uniform,uniform*float(placement.horizontalScale[1]))
		var visual:=asset.instantiate() as Node3D; visual.position=Vector3(placement.modelLocalOffsetM[0],placement.modelLocalOffsetM[1],placement.modelLocalOffsetM[2])
		parent.add_child(visual); _scene.add_child(parent)
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
		attached=interior.attach_existing(visual,record,data)
	var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_city/session_packet.json"))
	var owners: Dictionary={}
	for row: Dictionary in packet.rows: owners[row.source_id]=Queue.Owner.new(row.source_id,1)
	var policy:=Policy.new()
	var config: Dictionary=policy.configure(_scene,packet.rows,owners,{"accepted":true,"packet_sha256":Policy.CITY_PACKET_SHA,"block_sha256":Policy.CITY_BLOCK_SHA,"session_id":Policy.SESSION,"packet_path":"res://assets/npc_city/session_packet.json"},{"version":1,"states":{"resident_253":"ordinary_outdoor"}})
	var body:=CharacterBody3D.new(); body.collision_layer=2; body.collision_mask=1; _scene.add_child(body)
	var host:=Host.new(); host.owner=RefCounted.new(); host._admit=policy.source_admit
	host.token={"source_id":"resident_253","life_generation":1,"body":body}
	var bound:=policy.bind_host(host)
	for i in range(4): await physics_frame
	var samples: Array[Dictionary]=[
		{"request":1792,"name":"actual_last_body","point":Vector3(9.388154,.000784,6.515806)},
		{"request":1792,"name":"prospective_actual_step","point":Vector3(9.367289,.000784,6.494252)},
		{"request":1792,"name":"host_path_next","point":Vector3(9.288435,.1,6.412779)},
		{"request":1792,"name":"backend_path_next","point":Vector3(9.120001,.1,6.238759)},
		{"request":1792,"name":"handoff","point":Vector3(8.5,0,5.598197)},
	]

	var results: Array[Dictionary]=[]
	var negatives: Array[Dictionary]=[]
	var ray_proof: Array[Dictionary]=[]
	if config.get("ok",false) and bound:
		for sample: Dictionary in samples:
			var point: Vector3=sample.point
			ray_proof.append({"name":sample.name,"rays":_rays(policy,host.token,point)})
			var static_ok: bool=policy._source_segment(point,point,true)
			var static_reason: String=policy._last_reason
			var floor_ok: bool=policy._native_floor_square(host.token,point)
			var floor_reason: String=policy._last_reason
			var square_ok: bool=policy._native_segment(host.token,point,point,false)
			results.append({"request":sample.request,"name":sample.name,"point":point,"source_static_ok":static_ok,"source_reason":static_reason,"floor_ok":floor_ok,"floor_reason":floor_reason,"native_square_ok":square_ok,"native_reason":policy._last_reason})
		var probe:=Vector3(12,0,8)
		var pinned_shape: CollisionShape3D
		for floor_record: Dictionary in policy._floors.values():
			var position: Vector3=floor_record.frame.origin; var size: Vector3=floor_record.size
			if absf(probe.x-position.x)<size.x*.5 and absf(probe.z-position.z)<size.z*.5:
				pinned_shape=floor_record.shape.get_ref(); break
		if pinned_shape!=null:
			pinned_shape.disabled=true; await physics_frame
			var lost: bool=policy._native_floor_square(host.token,probe)
			negatives.append({"name":"lost_actual_source_floor_rejected","ok":not lost,"reason":policy._last_reason})
			pinned_shape.disabled=false; await physics_frame
			negatives.append({"name":"restored_source_floor_admitted","ok":policy._native_floor_square(host.token,probe)})
		var blocker:=StaticBody3D.new(); blocker.collision_layer=256
		var blocker_shape:=CollisionShape3D.new(); var blocker_box:=BoxShape3D.new(); blocker_box.size=Vector3(.2,1.5,.2)
		blocker_shape.shape=blocker_box; blocker.add_child(blocker_shape); blocker.position=probe+Vector3(.1,.8,0); _scene.add_child(blocker)
		await physics_frame
		var occupied: bool=policy._native_segment(host.token,probe,probe,false)
		negatives.append({"name":"current_dynamic_square_overlap_rejected","ok":not occupied,"reason":policy._last_reason})
		blocker.queue_free(); await process_frame; await physics_frame
		negatives.append({"name":"cleared_current_square_admitted","ok":policy._native_segment(host.token,probe,probe,false)})
		policy.update_access(2,{"resident_253":"deny"})
		negatives.append({"name":"actual_policy_access_revoked","ok":not policy.source_admit(probe,"resident_253",1,.738,"placement")})
	var negative_ok:=negatives.size()==5
	for negative: Dictionary in negatives: negative_ok=negative_ok and bool(negative.ok)
	var result:={"ground_install":{"ok":ground_install.get("ok",false)},"actual_printshop_attached":attached,"printshop_errors":interior.errors,"ray_proof":ray_proof,"configured":config,"host_bound":bound,"floor_count":floor_count,"static_fragment_count":_static_count,"samples":results,"negative_checks":negatives,"negative_ok":negative_ok,"scope":"Exact current source floors plus actual one-building GLB/PrintshopInterior.attach_existing; fixture owner and no past live other NPC/vehicle state. Static seam diagnosis, not full-city performance or arrival"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):
			var out:=arg.trim_prefix("--qa-out="); DirAccess.make_dir_recursive_absolute(out)
			var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("SOURCE_FRAGMENT ",JSON.stringify(result))
	policy.dispose(); _scene.queue_free()
	await create_timer(2.0).timeout
	quit(0 if config.get("ok",false) and bound and negative_ok and attached else 1)

func _rays(policy: RefCounted, token: Dictionary, point: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var ray:=PhysicsRayQueryParameters3D.new(); ray.collision_mask=1; ray.exclude=[token.body.get_rid()]
	var space:=_scene.get_world_3d().direct_space_state
	for offset: Vector2 in Policy.OFFSETS:
		var at:=point+Vector3(offset.x,0,offset.y)
		var y: float=policy._terrain_height(float(at.x)+395.65,float(at.z)+45.099999999999994)
		ray.from=Vector3(at.x,y+.3,at.z); ray.to=Vector3(at.x,y-.3,at.z)
		var hit:=space.intersect_ray(ray)
		var row:={"offset":offset,"from":ray.from,"to":ray.to,"mask":ray.collision_mask,"exclusions":[str(token.body.get_rid())],"expected_y":y,"empty":hit.is_empty()}
		if not hit.is_empty():
			row.merge({"rid":str(hit.rid),"is_pinned_floor":policy._floors.has(hit.rid),"normal":hit.normal,"position":hit.position,"height_delta":hit.position.y-y,"collider_path":str(hit.collider.get_path()),"collider_class":hit.collider.get_class(),"shape_index":hit.shape})
			var collider: CollisionObject3D=hit.collider
			var shape_node: Node=collider.shape_owner_get_owner(collider.shape_find_owner(hit.shape))
			if shape_node is CollisionShape3D:
				row.merge({"shape_type":shape_node.shape.get_class(),"shape_frame":shape_node.global_transform,"shape_disabled":shape_node.disabled})
				if shape_node.shape is BoxShape3D: row["shape_size"]=shape_node.shape.size
		result.append(row)
	return result
