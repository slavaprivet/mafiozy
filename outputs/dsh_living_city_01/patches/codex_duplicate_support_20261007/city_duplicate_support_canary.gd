extends SceneTree
const Policy = preload("res://scripts/city/runtime/npc_city_world_policy.gd")
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
	var fragment:=Rect2(Vector2(53,52),Vector2(64,43))
	for record: Dictionary in block.buildings+block.decor:
		for data: Dictionary in record.get("collisionBodiesM",[]):
			var bounds:=Rect2(); var first:=true
			for pair: Array in data.polygonXZ:
				var point:=Vector2(pair[0],pair[1]); bounds=Rect2(point,Vector2.ZERO) if first else bounds.expand(point); first=false
			if bounds.intersects(fragment): _solid(data)
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
		{"request":558,"name":"initial_a","point":Vector3(114.8,0,92.25)},
		{"request":558,"name":"initial_b","point":Vector3(114.8,.1,92.24999)},
		{"request":1085,"name":"sample1_a","point":Vector3(60.422593,.1,59.24272)},
		{"request":1085,"name":"sample1_b","point":Vector3(60.099886,.1,58.90931)},
		{"request":2801,"name":"sample0_a","point":Vector3(55.46417,.1,54.11986)},
		{"request":2801,"name":"sample0_b","point":Vector3(55.36105,.1,54.01332)},
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
		for sample: Dictionary in results:
			negatives.append({"name":"exact_endpoint_"+str(sample.name),"ok":sample.source_static_ok and sample.floor_ok and sample.native_square_ok})
		var inner_probe: Vector3=samples[5].point
		var slab: StaticBody3D=ground_install.ground
		var slab_shape: CollisionShape3D=slab.get_child(0)
		var original_shape: Shape3D=slab_shape.shape
		var original_frame:=slab.transform
		negatives.append({"name":"exact_duplicate_captured","ok":policy._current_duplicate_support(_scene)==slab.get_rid()})
		slab.position.y+=.02; await physics_frame
		negatives.append({"name":"raised_slab_not_excluded_and_rejected","ok":not policy._current_duplicate_support(_scene).is_valid() and not policy._native_floor_square(host.token,inner_probe)})
		slab.transform=original_frame; await physics_frame
		slab.rotation.z=.025; await physics_frame
		negatives.append({"name":"tilted_slab_not_excluded_and_rejected","ok":not policy._current_duplicate_support(_scene).is_valid() and not policy._native_floor_square(host.token,inner_probe)})
		slab.transform=original_frame; await physics_frame
		var original_size: Vector3=original_shape.size
		original_shape.size.y+=.04; await physics_frame
		negatives.append({"name":"resized_slab_not_excluded_and_rejected","ok":not policy._current_duplicate_support(_scene).is_valid() and not policy._native_floor_square(host.token,inner_probe)})
		original_shape.size=original_size; await physics_frame
		slab_shape.shape=original_shape.duplicate(); await physics_frame
		negatives.append({"name":"replaced_shape_identity_not_excluded","ok":not policy._current_duplicate_support(_scene).is_valid()})
		slab_shape.shape=original_shape; await physics_frame
		var holder:=Node3D.new(); _scene.add_child(holder)
		slab.reparent(holder); await physics_frame
		negatives.append({"name":"changed_body_owner_not_excluded","ok":not policy._current_duplicate_support(_scene).is_valid()})
		slab.reparent(ground_install.root); await physics_frame
		ground_install.root.set_meta("navigation_policy","other")
		negatives.append({"name":"changed_root_scope_not_excluded","ok":not policy._current_duplicate_support(_scene).is_valid()})
		ground_install.root.set_meta("navigation_policy","outside_unchanged_source_crop_no_npc_entry")
		negatives.append({"name":"restored_exact_duplicate_admitted","ok":policy._native_floor_square(host.token,inner_probe)})
		# Unknown support and actual occupancy never inherit the duplicate exclusion.
		for layer in [1,256]:
			var wall: PhysicsBody3D=StaticBody3D.new() if layer==1 else CharacterBody3D.new()
			wall.collision_layer=layer
			var wall_shape:=CollisionShape3D.new(); var wall_box:=BoxShape3D.new(); wall_box.size=Vector3(.2,1.5,.2); wall_shape.shape=wall_box
			wall.add_child(wall_shape); wall.position=inner_probe+Vector3(.1,.8,0); _scene.add_child(wall); await physics_frame
			negatives.append({"name":"current_wall_or_npc_layer_"+str(layer),"ok":not policy._native_segment(host.token,inner_probe,inner_probe,false),"reason":policy._last_reason})
			wall.queue_free(); await process_frame; await physics_frame
			negatives.append({"name":"wall_or_npc_removed_layer_"+str(layer),"ok":policy._native_segment(host.token,inner_probe,inner_probe,false)})
		var step_body:=StaticBody3D.new(); step_body.collision_layer=1
		var step_shape:=CollisionShape3D.new(); var step_box:=BoxShape3D.new(); step_box.size=Vector3(2,.1,2); step_shape.shape=step_box
		step_body.add_child(step_shape); step_body.position=inner_probe+Vector3(0,-.03,0); _scene.add_child(step_body); await physics_frame
		negatives.append({"name":"real_raised_step_still_rejected","ok":not policy._native_floor_square(host.token,inner_probe),"reason":policy._last_reason})
		step_body.rotation.z=.25; await physics_frame
		negatives.append({"name":"real_changed_slope_still_rejected","ok":not policy._native_floor_square(host.token,inner_probe),"reason":policy._last_reason})
		step_body.queue_free(); await process_frame; await physics_frame
		negatives.append({"name":"removed_step_restores_original_support","ok":policy._native_floor_square(host.token,inner_probe)})
		var stale_token: Dictionary=host.token.duplicate(); stale_token.life_generation=2
		negatives.append({"name":"stale_life_token_rejected","ok":not policy.native_clear_segment(stale_token,inner_probe,inner_probe)})
		var probe: Vector3=samples[3].point
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
	var negative_ok:=negatives.size()==27
	for negative: Dictionary in negatives: negative_ok=negative_ok and bool(negative.ok)
	var result:={"ground_install":{"ok":ground_install.get("ok",false)},"ray_proof":ray_proof,"configured":config,"host_bound":bound,"floor_count":floor_count,"static_fragment_count":_static_count,"samples":results,"negative_checks":negatives,"negative_ok":negative_ok,"scope":"Production policy/source floors/Ground.install, with fixture current owner; exact endpoints and mutation guards; backend map/life/mover guards are a separate canary"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):
			var out:=arg.trim_prefix("--qa-out="); DirAccess.make_dir_recursive_absolute(out)
			var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("SOURCE_FRAGMENT ",JSON.stringify(result))
	policy.dispose(); _scene.queue_free()
	await create_timer(2.0).timeout
	quit(0 if config.get("ok",false) and bound and negative_ok else 1)

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
