extends "palazzo_live_site.gd"
## Candidate facade finishing on the accepted light-body Palazzo backend.
## The host stages this file beside palazzo_live_site.gd and rewrites the extends.
const WindowShell = preload("window_shell.gd")
const Glazing = preload("palazzo_glazing.gd")
var _glazing: Node3D
var _structure: RefCounted
var _finished_meshes: Dictionary={}
var _finished_errors: Array[String]=[]
var _finished_initial_sections: int=0
var _finished_omitted_cells: int=0

func _ready() -> void:
	super._ready()
	if not _finished_errors.is_empty():
		site_error="finished_facade:"+_finished_errors[0]
		site_ready=false
		set_process(false); set_physics_process(false)
		if is_instance_valid(_glazing): _glazing.dispose()
		_glazing=null

func _build_building() -> void:
	_finished_errors.clear(); _finished_omitted_cells=0
	super._build_building()
	_finished_initial_sections=pieces.size()
	if not rebuilding: _prepare_glazing()

func piece(label: String,size: Vector3,at: Vector3,color: Color,rotation_y: float=0.0) -> RigidBody3D:
	var actual: Vector3=size
	if label in ["Facade","Side","Floor"]: actual.x=2.002
	elif label=="Roof": actual.x=2.002; actual.z=2.002
	elif label=="Entrance" and is_equal_approx(size.x,1.90): actual.x=2.002
	var body: RigidBody3D=super.piece(label,actual,at,color,rotation_y)
	for child in body.get_children():
		if child is MeshInstance3D and child.position==Vector3.ZERO:
			child.mesh=_finished_flat_mesh(actual)
			child.set_meta("finished_primary",true)
			child.set_meta("finished_physical",true)
		elif child is CollisionShape3D and child.shape is BoxShape3D:
			# Source uses .98 for loose foam; an intact wall must have no crack.
			child.shape.size=actual
			child.set_meta("finished_primary",true)
			child.set_meta("finished_intact_size",actual)
	return body

func _finished_flat_mesh(size: Vector3) -> ArrayMesh:
	var key: String=str(size)
	if _finished_meshes.has(key): return _finished_meshes[key]
	var box:=BoxMesh.new(); box.size=size
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
	_finished_meshes[key]=mesh
	return mesh

func _finished_remove_primary(body: RigidBody3D) -> void:
	for child in body.get_children():
		if child.get_meta("finished_primary",false):
			body.remove_child(child)
			child.free()

func _finished_box(body: RigidBody3D,size: Vector3,at: Vector3,color: Color,metallic: float,physical: bool,role: String="detail") -> MeshInstance3D:
	var mesh: MeshInstance3D=visual(body,size,at,color,metallic)
	mesh.mesh=_finished_flat_mesh(size)
	mesh.set_meta("finished_physical",physical)
	mesh.set_meta("finished_role",role)
	if physical:
		var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new()
		shape.size=size; collision.shape=shape; collision.position=at
		collision.set_meta("finished_intact_size",size)
		collision.set_meta("finished_role",role)
		body.add_child(collision)
	return mesh

func window_on(node: Node3D,center: Vector3,width: float=1.10,height: float=1.5) -> void:
	var body:=node as RigidBody3D
	if not center.is_finite() or not owns_collider(body) or body.has_meta("finished_window"):
		_finished_errors.append("window_owner_or_duplicate"); return
	var size: Vector3=body.get_meta("section_size")
	var shell: Dictionary=WindowShell.ring(size,Vector2(center.x,center.y),width,height)
	if not shell.ok:
		_finished_errors.append(str(shell.reason)); return
	_finished_remove_primary(body)
	var color: Color=body.get_meta("section_color")
	for rect: Dictionary in shell.boxes:
		_finished_box(body,rect.size,rect.at,color,0.0,true,"core")
	# Four real frame bars surround the opening. No dark/opaque backing plate.
	var rim: float=.075
	var face_z: float=size.z*.5+.025
	for side in [-1.0,1.0]:
		_finished_box(body,Vector3(rim,height+rim*2,.10),Vector3(center.x+side*(width+rim)*.5,center.y,face_z),DARK,0.0,true,"frame")
		_finished_box(body,Vector3(width,rim,.10),Vector3(center.x,center.y+side*(height+rim)*.5,face_z),DARK,0.0,true,"frame")
	# The visible brass cross is also a thin real box, never an implicit pane hull.
	_finished_box(body,Vector3(.045,height,.045),Vector3(center.x,center.y,face_z+.075),BRASS,.5,true,"mullion")
	_finished_box(body,Vector3(width,.045,.045),Vector3(center.x,center.y-.23,face_z+.075),BRASS,.5,true,"mullion")
	# Timber replacements have a tighter reviewed footprint than the free plaza.
	var sill_depth: float=.30 if body.get_meta("material_class","")=="wood" else .40
	_finished_box(body,Vector3(width+.34,.14,sill_depth),Vector3(center.x,center.y-height*.5-.10,face_z+.035),TRIM,0.0,true,"sill")
	body.set_meta("finished_window",{"center":Vector3(center.x,center.y,0),"width":width,"height":height,"opening":shell.opening,"core_boxes":shell.boxes.duplicate(true),"solid_core_volume_m3":shell.solid_volume_m3,"glass_owner":"palazzo_glazing"})

func _prepare_wall_fragments(body: RigidBody3D) -> void:
	if not body.has_meta("finished_window"):
		super._prepare_wall_fragments(body); return
	var parts: Array[Dictionary]=[]
	for child in body.get_children():
		if not child is MeshInstance3D: continue
		if not child.has_meta("box_size") or not child.transform.basis.is_equal_approx(Basis.IDENTITY):
			_finished_errors.append("window_decor_requires_local_box"); return
		parts.append({"size":child.get_meta("box_size"),"at":child.position,"color":child.get_meta("box_color"),"metallic":child.get_meta("box_metallic"),"physical":child.get_meta("finished_physical",false),"role":child.get_meta("finished_role","decor")})
	var prepared: Dictionary=WindowShell.tiles(body.get_meta("section_size"),parts)
	if not prepared.ok:
		_finished_errors.append(str(prepared.reason)); return
	for tile: Dictionary in prepared.tiles:
		for part: Dictionary in tile.parts: _finished_flat_mesh(part.size)
	body.set_meta("fracture_tiles",prepared.tiles)
	body.set_meta("finished_compound_pool",true)
	body.set_meta("finished_omitted_air_cells",prepared.omitted_air_cells)
	_finished_omitted_cells+=int(prepared.omitted_air_cells)

func _pool_wall_fragments(body: RigidBody3D) -> void:
	if not body.get_meta("finished_compound_pool",false):
		if body.has_meta("fracture_tiles"): super._pool_wall_fragments(body)
		else: body.set_meta("pooled_fragments",[])
		return
	var fragments: Array[RigidBody3D]=[]
	for tile: Dictionary in body.get_meta("fracture_tiles"):
		var chunk: RigidBody3D=piece("WallFragment",tile.size,Vector3.ZERO,body.get_meta("section_color"))
		# piece supplies the accepted body/ownership. Remove its temporary full box.
		_finished_remove_primary(chunk)
		for part: Dictionary in tile.parts:
			_finished_box(chunk,part.size,part.at,part.color,part.metallic,part.physical,part.role)
		chunk.transform=body.transform*Transform3D(Basis.IDENTITY,tile.center)
		initial_transforms[chunk.get_instance_id()]=chunk.global_transform
		pieces.erase(chunk); chunk.hide(); chunk.collision_layer=0; chunk.collision_mask=0
		chunk.set_meta("panel_center",tile.center); chunk.set_meta("wall_panel",body)
		chunk.set_meta("finished_compound",true)
		pooled_fragments.append(chunk); fragments.append(chunk)
	body.set_meta("pooled_fragments",fragments)

func _prepare_glazing() -> void:
	if rebuilding or not is_inside_tree() or is_instance_valid(_glazing): return
	var helper: Node3D=Glazing.new()
	if not helper.configure(self):
		helper.free(); _finished_errors.append("glazing_configure"); return
	_glazing=helper
	for wall in wall_panels:
		if not wall.has_meta("finished_window"): continue
		var window: Dictionary=wall.get_meta("finished_window")
		var added: Dictionary=_glazing.add_pane(wall,Transform3D(Basis.IDENTITY,window.center),Vector2(window.width,window.height),wall)
		if not added.get("ok",false): _finished_errors.append("glazing_pane:"+str(added.get("reason","unknown")))
	# Reflection belongs to the real transparent Walk pane; no painted wall plate.
	if not _finished_errors.is_empty(): site_error="finished_facade:"+_finished_errors[0]

func _break_glass_for_wall(wall: RigidBody3D) -> void:
	if is_instance_valid(_glazing) and owns_collider(wall): _glazing.break_for_wall(wall)

func _break_all_glass() -> void:
	if is_instance_valid(_glazing): _glazing.break_all()

func _finished_contact_inside(body: RigidBody3D,world_point: Vector3) -> bool:
	if not owns_collider(body) or not world_point.is_finite(): return false
	# The receipt keeps its real native point, including projecting sills. A
	# section bounding box would both miss that point and include window air.
	for child in body.get_children():
		if not child is CollisionShape3D or child.disabled or not child.shape is BoxShape3D: continue
		var size: Vector3=child.shape.size
		if AABB(-size*.5,size).grow(.08).has_point(child.to_local(world_point)): return true
	return false

func _finished_blast_area_target(world_point: Vector3,radius: float) -> Dictionary:
	var closest: Dictionary={}
	var distance_squared: float=radius*radius
	for body: RigidBody3D in pieces:
		if not owns_collider(body) or not body.freeze or (body.collision_layer&1)==0 or body.get_meta("detached",false): continue
		# A pane hit can affect a real nearby wall/frame or one of its remaining
		# tiles, never a retired parent's full box or an arbitrary furniture body.
		if not body.has_meta("fracture_tiles") and not body.has_meta("wall_panel"): continue
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.disabled or not child.shape is BoxShape3D: continue
			var half: Vector3=child.shape.size*.5
			var local: Vector3=child.to_local(world_point).clamp(-half,half)
			var point: Vector3=child.to_global(local)
			var candidate_squared: float=point.distance_squared_to(world_point)
			if candidate_squared<=distance_squared:
				distance_squared=candidate_squared
				closest={"body":body,"point":point,"distance_m":sqrt(candidate_squared)}
	return closest

func apply_explosion(receipt: Dictionary) -> Dictionary:
	if not site_ready or rebuilding or collapsing: return {"ok":false,"reason":"site_not_available"}
	if receipt.get("admitted")!=true or receipt.get("authority")!="local_preview": return {"ok":false,"reason":"authority"}
	if receipt.get("source_id")!=source_id: return {"ok":false,"reason":"source_id"}
	var id: String=str(receipt.get("event_id",""))
	if not _event_available(id): return {"ok":false,"reason":"duplicate_or_event_budget"}
	if receipt.has("generation") and receipt.generation!=rebuild_generation: return {"ok":false,"reason":"stale_generation"}
	var at: Variant=receipt.get("position"); var direction: Variant=receipt.get("direction")
	var power: Variant=receipt.get("power"); var radius: Variant=receipt.get("radius")
	if not at is Vector3 or not direction is Vector3 or not at.is_finite() or not direction.is_finite() or direction.length_squared()<.000001: return {"ok":false,"reason":"coordinates"}
	if not (power is float or power is int) or not (radius is float or radius is int) or not is_finite(float(power)) or not is_finite(float(radius)) or power<=0 or power>10000 or radius<=0 or radius>3.2: return {"ok":false,"reason":"blast_limits"}
	var target: Variant=receipt.get("collider")
	if target==null and receipt.get("contact") is Dictionary: target=receipt.contact.get("collider")
	if is_instance_valid(_glazing) and _glazing.owns_collider(target):
		# The native producer hit glass. Keep that receipt and its position intact;
		# nearby structural material is an area target, not a fabricated direct hit.
		if receipt.get("scope")!="new_local_session_building_damage" or receipt.get("weapon_id")!="rpg" or receipt.get("explosive")!=true or receipt.get("server_authority",false)!=false: return {"ok":false,"reason":"native_pane_blast_contract"}
		var contact: Dictionary=_glazing.validate_pane_contact(target,at)
		if not contact.get("ok",false): return contact
		var area: Dictionary=_finished_blast_area_target(at,float(radius))
		# The native bridge has already queued its independent 11 m glass blast.
		# This unchanged receipt also covers an isolated admitted contact path;
		# pending flags prevent duplicate pane jobs or shards.
		var glass_result: Dictionary=_glazing.apply_blast(receipt)
		if not glass_result.get("ok",false): return glass_result
		if area.is_empty():
			last_explosion={"ok":true,"committed":true,"structural_committed":false,"detached":0,"state":"glass_only"}
		else:
			explode(at,float(radius),area.body,bool(receipt.get("passage",false)))
		var pane_result: Dictionary=last_explosion.duplicate()
		pane_result.event_id=id; pane_result.generation=rebuild_generation
		pane_result.contact_collider_id=target.get_instance_id()
		pane_result.area_target_id=area.body.get_instance_id() if not area.is_empty() else 0
		pane_result.area_distance_m=area.get("distance_m",-1.0)
		pane_result.original_position=at; pane_result.original_radius=float(radius)
		pane_result.glass=glass_result
		_events[id]=pane_result.duplicate()
		return pane_result
	if not owns_collider(target) or (target.collision_layer&1)==0 or target.get_meta("detached",false): return {"ok":false,"reason":"owned_intact_collider_required"}
	if not _finished_contact_inside(target,at): return {"ok":false,"reason":"contact_outside_collider"}
	explode(at,float(radius),target,bool(receipt.get("passage",false)))
	var result: Dictionary=last_explosion.duplicate()
	result.event_id=id; result.generation=rebuild_generation
	_events[id]=result.duplicate()
	return result

func _mark_structure_dirty() -> void:
	if not is_instance_valid(_structure) or not _structure.has_method("mark_dirty"): return
	# Suppress only the support helper's synchronous transfer call. An independent
	# shot during the same physics tick must still invalidate its pending graph.
	if _structure.has_method("is_transferring") and bool(_structure.call("is_transferring")): return
	_structure.call("mark_dirty")

func _breach_wall(body: RigidBody3D,at: Vector3,passage: bool=false) -> int:
	if not owns_collider(body): return 0
	_break_glass_for_wall(body)
	var count: int=super._breach_wall(body,at,passage)
	_mark_structure_dirty()
	return count

func _release(body: RigidBody3D,at: Vector3,power: float,exit_direction: Vector3=Vector3.ZERO) -> void:
	if not owns_collider(body) or body.get_meta("detached",false): return
	_break_glass_for_wall(body)
	if not body.get_meta("finished_loose_shapes",false):
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				child.shape.size=child.get_meta("finished_intact_size",child.shape.size)*.98
		body.set_meta("finished_loose_shapes",true)
	super._release(body,at,power,exit_direction)
	_mark_structure_dirty()

func _door_pose_clear(pose: Transform3D) -> bool:
	if not is_instance_valid(_door) or _door_query==null: return false
	var checked: int=0
	for child in _door.get_children():
		if not child is CollisionShape3D or child.disabled or child.shape==null: continue
		_door_query.shape=child.shape
		_door_query.transform=building.global_transform*pose*child.transform
		if not get_world_3d().direct_space_state.intersect_shape(_door_query,1).is_empty(): return false
		checked+=1
	return checked>0

func _move_door(angle: float) -> void:
	super._move_door(angle)
	if is_instance_valid(_glazing): _glazing.sync_moving_panes()
	_mark_structure_dirty()

func collapse() -> void:
	if not site_ready or rebuilding or collapsing: return
	_break_all_glass()
	super.collapse()

func reset_building() -> void:
	if rebuilding or not site_ready: return
	if is_instance_valid(_glazing): _glazing.dispose()
	_glazing=null
	_finished_errors.clear(); _finished_omitted_cells=0
	await super.reset_building()
	if not is_inside_tree(): return
	_prepare_glazing()
	_mark_structure_dirty()
	if not _finished_errors.is_empty(): site_ready=false; site_error="finished_facade:"+_finished_errors[0]

func get_stats() -> Dictionary:
	var result: Dictionary=super.get_stats()
	var owned_count: int=0
	var shape_count: int=0
	for ref: WeakRef in _owned_bodies.values():
		var body: Variant=ref.get_ref()
		if not is_instance_valid(body): continue
		owned_count+=1
		for child in body.get_children():
			if child is CollisionShape3D and child.shape!=null: shape_count+=1
	result["native_body_cap"]=owned_count
	result["native_body_count"]=owned_count
	result["native_shape_count"]=shape_count
	result["finished_omitted_air_cells"]=_finished_omitted_cells
	result["finished_errors"]=_finished_errors.duplicate()
	result["glazing"]=_glazing.stats() if is_instance_valid(_glazing) else {"ready":false}
	return result
