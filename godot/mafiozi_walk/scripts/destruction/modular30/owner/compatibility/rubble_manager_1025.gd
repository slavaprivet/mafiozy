extends Node3D
## Candidate bounded dynamic pool + material/region-batched parked rubble.
## Local geometry/lifecycle only; admission and source-wall commit remain caller-owned.
const Body=preload("../vendor/rubble/pooled_fragment.gd")
const Batch=preload("../vendor/rubble/parked_batch.gd")
const LAYER:=512
const LEASE:="closed_rubble_manager_owner"
const DEFAULTS: Dictionary={"active":64,"records":2048,"regions":128,"region_size":8.0,"region_records":128,"region_vertices":49152,"region_materials":32,"transition_regions":16,"parks_per_tick":2}
var _world: Node3D
var _limits: Dictionary={}
var _slots: Array=[]
var _slot_tokens: Dictionary={}
var _records: Dictionary={}
var _regions: Dictionary={}
var _reservations: Dictionary={}
var _prepared_plans: Dictionary={}
var _plan_tokens: Dictionary={}
var _record_locks: Dictionary={}
var _region_locks: Dictionary={}
var _dependents: Dictionary={}
var _park_queue: Array=[]
var _impacts: Array=[]
var _last_actor: Dictionary={}
var _epoch:=1
var _serial:=0
var _new_reserved:=0
var _disposed:=false
var _last_tick: int=-1
var _last_prepare_usec:=0
var _max_prepare_usec:=0
var blocked_reason: String=""

func _fail(reason: String,retryable: bool=false,required: int=0,available: int=0) -> Dictionary:
	return {"ok":false,"reason":reason,"retryable":retryable,"required":required,"available":available}

func configure(world: Node3D,limits: Dictionary={}) -> Dictionary:
	if _disposed or _world!=null or not is_inside_tree() or not is_instance_valid(world) or not world.is_inside_tree() or not global_transform.is_equal_approx(Transform3D.IDENTITY): return _fail("world_or_manager_transform")
	if world.has_meta(LEASE):
		var existing: Variant=world.get_meta(LEASE)
		if existing is WeakRef and is_instance_valid(existing.get_ref()): return _fail("world_already_owned")
		if not existing is WeakRef: return _fail("world_lease_contract")
	var selected: Dictionary=DEFAULTS.duplicate()
	for key: Variant in limits:
		if not selected.has(key): return _fail("unknown_limit")
		selected[key]=limits[key]
	for key: String in ["active","records","regions","region_records","region_vertices","region_materials","transition_regions","parks_per_tick"]:
		if not selected[key] is int or selected[key]<1: return _fail("limit_type_or_range")
	if selected.active>64 or selected.records>4096 or selected.regions>128 or selected.region_records>128 or selected.region_vertices>49152 or selected.region_materials>32 or selected.transition_regions>16 or selected.parks_per_tick>4: return _fail("hard_limit")
	if not (selected.region_size is float or selected.region_size is int) or not is_finite(float(selected.region_size)) or selected.region_size<2.0 or selected.region_size>32.0: return _fail("region_size")
	_world=world; _limits=selected
	for i: int in _limits.active:
		var body: RigidBody3D=Body.new()
		body.name="ReusableRubbleSlot_"+str(i)
		body.manager=weakref(self); body.pool_index=i
		body.freeze=true; body.collision_layer=0; body.collision_mask=0
		body.can_sleep=false; body.continuous_cd=true; body.max_contacts_reported=8
		var collision:=CollisionShape3D.new(); collision.disabled=true; body.add_child(collision)
		var visual:=MeshInstance3D.new(); visual.visible=false; body.add_child(visual)
		add_child(body); _slots.append(body)
	world.set_meta(LEASE,weakref(self))
	return {"ok":true,"dynamic_slots":_slots.size(),"layer":LAYER,"limits":_limits.duplicate(),"accepted_parity":false}

func _free_slots() -> Array:
	var result: Array=[]
	for i: int in _slots.size():
		if _slots[i].record_id.is_empty() and not _slot_tokens.has(i): result.append(i)
	return result

func _descriptor(input: Dictionary) -> Dictionary:
	if input.get("closed")!=true or not input.get("mesh") is ArrayMesh or not input.get("world_transform") is Transform3D or not input.get("shape_points") is PackedVector3Array or not input.get("bounds") is AABB: return _fail("closed_descriptor_contract")
	var mesh: ArrayMesh=input.mesh
	var frame: Transform3D=input.world_transform
	var bounds: AABB=input.bounds
	if not frame.is_finite() or not frame.basis.is_equal_approx(frame.basis.orthonormalized()) or absf(frame.basis.determinant()-1.0)>.0001 or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<=0 or bounds.size.y<=0 or bounds.size.z<=0 or bounds.size.length()>1.733: return _fail("descriptor_metre_transform")
	if mesh.get_surface_count()<1 or mesh.get_surface_count()>8 or mesh.get_blend_shape_count()!=0: return _fail("descriptor_mesh_contract")
	var cached_surfaces: Array=[]
	var total_vertices:=0
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _fail("descriptor_mesh_contract")
		var arrays: Array=mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty(): return _fail("descriptor_requires_unindexed_chunk")
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		total_vertices+=vertices.size()
		if vertices.size()<3 or total_vertices>384 or vertices.size()%3!=0: return _fail("descriptor_vertex_budget")
		for slot: int in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
			if arrays[slot]==null or arrays[slot].size()!=vertices.size(): return _fail("descriptor_attributes")
		if arrays[Mesh.ARRAY_TANGENT]==null or arrays[Mesh.ARRAY_TANGENT].size()!=vertices.size()*4: return _fail("descriptor_tangent")
		for point: Vector3 in vertices:
			if not point.is_finite() or not bounds.grow(.0001).has_point(point): return _fail("descriptor_bounds")
		# Slab output keeps zero-area placeholder surfaces for source indices.
		# Preserve the active source mesh but never add these to static collision.
		var filtered: Array=_nondegenerate_arrays(arrays)
		if not filtered[Mesh.ARRAY_VERTEX].is_empty(): cached_surfaces.append({"arrays":filtered,"material":mesh.surface_get_material(surface),"source_surface":surface})
	if total_vertices<12 or cached_surfaces.is_empty(): return _fail("descriptor_empty_volume")
	var points: PackedVector3Array=input.shape_points
	if points.size()<4 or points.size()>64: return _fail("descriptor_convex_budget")
	for point: Vector3 in points:
		if not point.is_finite() or not bounds.grow(.0001).has_point(point): return _fail("descriptor_convex_points")
	for key: String in ["mass","friction","bounce","linear_damp","angular_damp","collision_margin_m","collision_shape_scale"]:
		if not (input.get(key) is float or input.get(key) is int) or not is_finite(float(input[key])): return _fail("descriptor_physics_fields")
	if input.mass<.12 or input.mass>3.0 or input.friction<0 or input.friction>1 or input.bounce<0 or input.bounce>1 or input.linear_damp<0 or input.angular_damp<0 or input.collision_margin_m<=0 or input.collision_margin_m>.002 or not is_equal_approx(input.collision_shape_scale,.98): return _fail("descriptor_physics_range")
	var shape:=ConvexPolygonShape3D.new(); shape.points=points; shape.margin=input.collision_margin_m
	var material:=PhysicsMaterial.new(); material.friction=input.friction; material.bounce=input.bounce
	var result: Dictionary=input.duplicate(true)
	result.surfaces=cached_surfaces; result.shape=shape; result.physics_material=material
	return {"ok":true,"descriptor":result}

static func _nondegenerate_arrays(arrays: Array) -> Array:
	var output: Array=[]; output.resize(Mesh.ARRAY_MAX)
	output[Mesh.ARRAY_VERTEX]=PackedVector3Array(); output[Mesh.ARRAY_NORMAL]=PackedVector3Array()
	output[Mesh.ARRAY_TEX_UV]=PackedVector2Array(); output[Mesh.ARRAY_TEX_UV2]=PackedVector2Array()
	output[Mesh.ARRAY_COLOR]=PackedColorArray(); output[Mesh.ARRAY_TANGENT]=PackedFloat32Array()
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for start: int in range(0,vertices.size(),3):
		if (vertices[start+1]-vertices[start]).cross(vertices[start+2]-vertices[start]).length_squared()<=.00000000000001: continue
		for index: int in range(start,start+3):
			for slot: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]: output[slot].append(arrays[slot][index])
			for component: int in 4: output[Mesh.ARRAY_TANGENT].append(arrays[Mesh.ARRAY_TANGENT][index*4+component])
	return output

static func adapt_slab_descriptor(piece: Dictionary) -> Dictionary:
	if piece.get("ok")!=true or piece.get("closed")!=true or piece.get("synthetic_back")!=false or not piece.get("mesh") is ArrayMesh or not piece.get("frame") is Transform3D or not piece.get("convex_points") is PackedVector3Array: return {"ok":false,"reason":"authored_slab_descriptor_required"}
	if not (piece.get("volume_m3") is float or piece.get("volume_m3") is int) or not is_finite(float(piece.volume_m3)) or piece.volume_m3<=0: return {"ok":false,"reason":"slab_volume"}
	var source: PackedVector3Array=piece.convex_points
	if source.size()<4 or source.size()>64: return {"ok":false,"reason":"slab_convex_budget"}
	var bounds:=AABB(source[0],Vector3.ZERO)
	var inset:=PackedVector3Array()
	for point: Vector3 in source:
		if not point.is_finite(): return {"ok":false,"reason":"slab_convex_points"}
		bounds=bounds.expand(point); inset.append(point*.98)
	var clearance:=INF
	var mesh: ArrayMesh=piece.mesh
	if mesh.get_surface_count()<1 or mesh.get_surface_count()>8: return {"ok":false,"reason":"slab_surface_budget"}
	var vertex_count:=0
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return {"ok":false,"reason":"slab_triangle_surface"}
		var arrays: Array=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		vertex_count+=vertices.size()
		if vertex_count>384 or vertices.size()%3!=0 or (arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty()): return {"ok":false,"reason":"slab_vertex_contract"}
		for start: int in range(0,vertices.size(),3):
			var cross: Vector3=(vertices[start+1]-vertices[start]).cross(vertices[start+2]-vertices[start])
			if cross.length_squared()<=.00000000000001: continue
			clearance=minf(clearance,absf(cross.normalized().dot(vertices[start])))
	if not is_finite(clearance) or clearance<=0: return {"ok":false,"reason":"slab_origin_clearance"}
	var descriptor: Dictionary=piece.duplicate(true)
	descriptor.world_transform=piece.frame; descriptor.shape_points=inset; descriptor.bounds=bounds; descriptor.section_size=bounds.size
	descriptor.mass=clampf(piece.volume_m3*.7,.12,3.0); descriptor.friction=.32; descriptor.bounce=0.0
	descriptor.linear_damp=.45; descriptor.angular_damp=1.8; descriptor.collision_margin_m=minf(.002,clearance*.005); descriptor.collision_shape_scale=.98
	return {"ok":true,"descriptor":descriptor}

func _make_plan_room(required: int) -> bool:
	while true:
		var total:=0
		for plan: Dictionary in _prepared_plans.values(): total+=plan.descriptors.size()
		if _prepared_plans.size()<32 and total+required<=_limits.active*2: return true
		var removable: String=""
		for id: String in _prepared_plans:
			if not _plan_tokens.has(id): removable=id; break
		if removable.is_empty(): return false
		_prepared_plans.erase(removable)
	return false

func discard_plan(prepared: Dictionary) -> Dictionary:
	if prepared.get("manager_id")!=get_instance_id(): return _fail("foreign_plan")
	var plan_id: String=str(prepared.get("plan_id",""))
	if plan_id.is_empty(): return _fail("missing_plan")
	if _plan_tokens.has(plan_id): return _fail("reserved_plan_cannot_discard",true)
	var existed: bool=_prepared_plans.has(plan_id)
	_prepared_plans.erase(plan_id)
	return {"ok":true,"discarded":existed}

func prepare(building_id: String,source_id: String,descriptors: Array,launch: Dictionary={}) -> Dictionary:
	var begin: int=Time.get_ticks_usec()
	if _disposed or _world==null: return _fail("not_configured")
	if building_id.is_empty() or source_id.is_empty() or building_id.length()>200 or source_id.length()>200 or descriptors.is_empty() or descriptors.size()>_limits.active: return _fail("identity_or_piece_count")
	var free: int=_free_slots().size()
	if descriptors.size()>free: return _fail("active_capacity",true,descriptors.size(),free)
	var remaining: int=_limits.records-_records.size()-_new_reserved
	if descriptors.size()>remaining: return _fail("record_capacity",true,descriptors.size(),remaining)
	if not _make_plan_room(descriptors.size()): return _fail("prepared_plan_capacity",true,descriptors.size(),0)
	var velocity: Variant=launch.get("linear_velocity",Vector3.ZERO)
	var angular: Variant=launch.get("angular_velocity",Vector3.ZERO)
	if not velocity is Vector3 or not angular is Vector3 or not velocity.is_finite() or not angular.is_finite() or velocity.length()>4.0 or angular.length()>3.0: return _fail("launch_limits")
	var prepared: Array=[]
	for descriptor: Variant in descriptors:
		if not descriptor is Dictionary: return _fail("descriptor_type")
		var checked: Dictionary=_descriptor(descriptor)
		if not checked.ok: return checked
		prepared.append(checked.descriptor)
	_last_prepare_usec=Time.get_ticks_usec()-begin; _max_prepare_usec=maxi(_max_prepare_usec,_last_prepare_usec)
	var plan_id: String=_token()
	_prepared_plans[plan_id]={"epoch":_epoch,"building_id":building_id,"source_id":source_id,"descriptors":prepared,"launch":{"linear_velocity":velocity,"angular_velocity":angular},"cook_usec":_last_prepare_usec}
	return {"ok":true,"manager_id":get_instance_id(),"epoch":_epoch,"plan_id":plan_id,"required":prepared.size(),"cook_usec":_last_prepare_usec}

func reserve(prepared: Dictionary) -> Dictionary:
	if _reservations.size()>=64: return _fail("reservation_capacity",true,1,0)
	if prepared.get("ok")!=true or prepared.get("manager_id")!=get_instance_id() or prepared.get("epoch")!=_epoch: return _fail("foreign_or_stale_plan")
	var plan_id: String=str(prepared.get("plan_id",""))
	if not _prepared_plans.has(plan_id) or _plan_tokens.has(plan_id): return _fail("expired_or_reserved_plan")
	# Own the validated resources privately. Public plans carry only opaque IDs;
	# recheck capacity, not mesh validation/convex cooking, at reservation time.
	var checked: Dictionary=_prepared_plans[plan_id]
	var available: int=_free_slots().size()
	if checked.descriptors.size()>available: return _fail("active_capacity",true,checked.descriptors.size(),available)
	var record_space: int=_limits.records-_records.size()-_new_reserved
	if checked.descriptors.size()>record_space: return _fail("record_capacity",true,checked.descriptors.size(),record_space)
	var token: String=_token()
	_plan_tokens[plan_id]=token
	var free: Array=_free_slots()
	var entries: Array=[]
	var ids: Array=[]
	for i: int in checked.descriptors.size():
		_serial+=1
		var id: String="rubble:"+str(get_instance_id())+":"+str(_serial)
		var descriptor: Dictionary=checked.descriptors[i]
		entries.append({"id":id,"building_id":checked.building_id,"source_id":checked.source_id,"descriptor":descriptor,"frame":descriptor.world_transform,"phase":"reserved","slot":free[i],"region":"","supports":[],"support_points":[],"quiet":0.0,"anchor":descriptor.world_transform.origin,"pending":false,"retry_tick":0})
		ids.append(id); _slot_tokens[free[i]]=token
	_new_reserved+=entries.size()
	_reservations[token]={"kind":"new","entries":entries,"launch":checked.launch,"plan_id":plan_id,"epoch":_epoch,"regions":{},"wake":[],"remove":[]}
	return {"ok":true,"token":token,"piece_ids":ids,"required":entries.size(),"cook_usec":checked.cook_usec}

func _token() -> String:
	_serial+=1
	return "rubble-ticket:"+str(get_instance_id())+":"+str(_serial)

func _activate(record: Dictionary,slot: int,velocity: Vector3,angular: Vector3) -> void:
	var body: RigidBody3D=_slots[slot]
	var descriptor: Dictionary=record.descriptor
	body.generation+=1; body.record_id=record.id; body.previous_velocity=velocity
	body.set_meta("building_id",record.building_id); body.set_meta("source_id",record.source_id); body.set_meta("rubble_record_id",record.id)
	body.mass=descriptor.mass; body.linear_damp=descriptor.linear_damp; body.angular_damp=descriptor.angular_damp
	body.physics_material_override=descriptor.physics_material
	var collision: CollisionShape3D=body.get_child(0); collision.shape=descriptor.shape; collision.disabled=false
	var visual: MeshInstance3D=body.get_child(1); visual.mesh=descriptor.mesh; visual.visible=true
	body.global_transform=record.frame; body.collision_layer=LAYER; body.collision_mask=1|LAYER
	body.linear_velocity=velocity; body.angular_velocity=angular; body.freeze=false; body.sleeping=false
	record.phase="active"; record.slot=slot; record.region=""; record.quiet=0.0; record.anchor=record.frame.origin; record.pending=false; record.retry_tick=0; record.sample={}
	_records[record.id]=record

func _release_slot(index: int) -> void:
	var body: RigidBody3D=_slots[index]
	body.generation+=1; body.record_id=""; body.freeze=true; body.collision_layer=0; body.collision_mask=0
	body.linear_velocity=Vector3.ZERO; body.angular_velocity=Vector3.ZERO; body.previous_velocity=Vector3.ZERO
	var collision: CollisionShape3D=body.get_child(0); collision.disabled=true; collision.shape=null
	var visual: MeshInstance3D=body.get_child(1); visual.visible=false; visual.mesh=null
	for key: String in ["building_id","source_id","rubble_record_id","pushed_by_actor"]:
		if body.has_meta(key): body.remove_meta(key)

func commit(token: String) -> Dictionary:
	var checked:Dictionary=check_transaction([token])
	if not checked.ok: return checked
	return _commit_reserved(token)

func check_transaction(tokens:Array) -> Dictionary:
	if _disposed or tokens.is_empty() or tokens.size()>64: return _fail("transaction_contract")
	var unique:Dictionary={}
	for token:Variant in tokens:
		if not token is String or unique.has(token) or not _reservations.has(token): return _fail("unknown_or_duplicate_reservation")
		unique[token]=true
		var reservation:Dictionary=_reservations[token]
		if reservation.epoch!=_epoch: return _fail("stale_reservation")
		for key:String in reservation.regions:
			if not _regions.has(key) or _regions[key].revision!=reservation.regions[key].revision or _region_locks.get(key,"")!=token: return _fail("stale_region_reservation")
		for entry:Dictionary in reservation.entries:
			if _slot_tokens.get(entry.slot,"")!=token or not _slots[entry.slot].record_id.is_empty(): return _fail("stale_slot_reservation")
		for id:String in reservation.wake+reservation.remove:
			if not _records.has(id) or _record_locks.get(id,"")!=token: return _fail("stale_record_reservation")
	return {"ok":true,"reservations":tokens.size()}

func commit_transaction(tokens:Array) -> Dictionary:
	# All resources and disjoint region/record/slot locks are validated first.
	# No external callbacks or deferred work occur between these commits.
	var checked:Dictionary=check_transaction(tokens)
	if not checked.ok: return checked
	var results:Array=[]
	for token:String in tokens: results.append(_commit_reserved(token))
	return {"ok":true,"committed":true,"results":results}

func _commit_reserved(token:String) -> Dictionary:
	var reservation: Dictionary=_reservations[token]
	if reservation.kind=="new":
		for entry: Dictionary in reservation.entries: _activate(entry,entry.slot,reservation.launch.linear_velocity,reservation.launch.angular_velocity)
		_new_reserved-=reservation.entries.size()
		_prepared_plans.erase(reservation.plan_id)
	else:
		for key: String in reservation.regions: _commit_region(key,reservation.regions[key].ids,reservation.regions[key].batch)
		for id: String in reservation.remove:
			var record: Dictionary=_records[id]
			_unlink_supports(record)
			if record.phase=="active": _release_slot(record.slot)
			_records.erase(id); _dependents.erase(id)
		for entry: Dictionary in reservation.entries:
			var record: Dictionary=_records[entry.id]
			_unlink_supports(record)
			record.supports=[]; record.support_points=[]
			_activate(record,entry.slot,reservation.velocity,Vector3.ZERO)
	_finish_reservation(token)
	return {"ok":true,"committed":true,"kind":reservation.kind,"active_created":reservation.entries.size(),"removed":reservation.remove.size()}

func _finish_reservation(token: String) -> void:
	for id: String in _plan_tokens.keys():
		if _plan_tokens[id]==token: _plan_tokens.erase(id)
	for slot: Variant in _slot_tokens.keys():
		if _slot_tokens[slot]==token: _slot_tokens.erase(slot)
	for id: Variant in _record_locks.keys():
		if _record_locks[id]==token: _record_locks.erase(id)
	for key: Variant in _region_locks.keys():
		if _region_locks[key]==token: _region_locks.erase(key)
	_reservations.erase(token)

func cancel(token: String) -> Dictionary:
	if not _reservations.has(token): return _fail("unknown_reservation")
	if _reservations[token].kind=="new": _new_reserved-=_reservations[token].entries.size()
	_finish_reservation(token)
	return {"ok":true,"cancelled":true}

func _region_key(point: Vector3) -> String:
	return "%d:%d:%d"%[floori(point.x/_limits.region_size),floori(point.y/_limits.region_size),floori(point.z/_limits.region_size)]

func _region_origin(point: Vector3) -> Vector3:
	return (Vector3(floorf(point.x/_limits.region_size),floorf(point.y/_limits.region_size),floorf(point.z/_limits.region_size))+Vector3.ONE*.5)*_limits.region_size

func _commit_region(key: String,ids: Array,batch: Dictionary,origin: Vector3=Vector3.ZERO) -> void:
	if ids.is_empty():
		if _regions.has(key):
			var region: Dictionary=_regions[key]
			region.body.collision_layer=0; region.body.collision_mask=0; region.node.visible=false; region.node.queue_free(); _regions.erase(key)
		return
	if not _regions.has(key):
		var node:=Node3D.new(); node.name="ParkedRubbleRegion_"+key.replace(":","_"); node.position=origin
		var body:=StaticBody3D.new(); body.collision_layer=LAYER; body.collision_mask=1|LAYER
		body.set_meta("rubble_region",key); body.set_meta("rubble_manager_id",get_instance_id())
		var collision:=CollisionShape3D.new(); body.add_child(collision); node.add_child(body)
		var visual:=MeshInstance3D.new(); node.add_child(visual); add_child(node)
		_regions[key]={"node":node,"body":body,"collision":collision,"visual":visual,"origin":origin,"ids":[],"revision":0,"vertices":0,"surfaces":0}
	var region: Dictionary=_regions[key]
	region.visual.mesh=batch.mesh; region.collision.shape=batch.shape; region.ids=ids.duplicate(); region.revision+=1
	region.vertices=batch.vertices; region.surfaces=batch.surfaces

func observe_physics(slot: int,generation: int,id: String,sample: Dictionary) -> void:
	if _disposed or slot<0 or slot>=_slots.size() or _slots[slot].generation!=generation or _slots[slot].record_id!=id or not _records.has(id): return
	var record: Dictionary=_records[id]
	if record.phase!="active": return
	record.sample=sample
	var grounded: bool=not sample.supports.is_empty()
	var quiet: bool=grounded and sample.linear.length_squared()<.0625 and sample.angular.length_squared()<.49
	if sample.frame.origin.distance_squared_to(record.anchor)>.000625:
		record.anchor=sample.frame.origin; record.quiet=0.0
	elif quiet: record.quiet+=sample.step
	else: record.quiet=0.0
	if record.quiet>=.65 and not record.pending and Engine.get_physics_frames()>=record.retry_tick:
		record.pending=true; _park_queue.append(id)
	for impact: Dictionary in sample.impacts:
		if _impacts.size()<32:
			impact.tick=sample.tick; _impacts.append(impact)

func _support_data(sample: Dictionary) -> Dictionary:
	var ids: Dictionary={}; var points: Array=[]
	for contact: Dictionary in sample.supports:
		var collider: Object=contact.collider
		if not is_instance_valid(collider): continue
		points.append(contact.point)
		if not collider.has_meta("rubble_region") or collider.get_meta("rubble_manager_id",0)!=get_instance_id(): continue
		var key: String=str(collider.get_meta("rubble_region"))
		if not _regions.has(key): continue
		var found:=false
		for id: String in _regions[key].ids:
			var record: Dictionary=_records[id]
			if (record.frame*record.descriptor.bounds).grow(.04).has_point(contact.point): ids[id]=true; found=true
		# A contact on an edge must not silently lose its dependency.
		if not found:
			for id: String in _regions[key].ids: ids[id]=true
	return {"ids":ids.keys(),"points":points}

func _link_supports(record: Dictionary) -> void:
	for id: String in record.supports:
		if not _dependents.has(id): _dependents[id]={}
		_dependents[id][record.id]=true

func _unlink_supports(record: Dictionary) -> void:
	for id: String in record.supports:
		if _dependents.has(id):
			_dependents[id].erase(record.id)
			if _dependents[id].is_empty(): _dependents.erase(id)

func _try_park(id: String) -> Dictionary:
	if not _records.has(id): return _fail("expired_record")
	var record: Dictionary=_records[id]
	record.pending=false
	if record.phase!="active" or _record_locks.has(id): return _fail("record_not_active")
	var body: RigidBody3D=_slots[record.slot]
	var sample: Dictionary=record.get("sample",{})
	if sample.is_empty() or sample.supports.is_empty() or Engine.get_physics_frames()-sample.tick>2 or record.quiet<.65 or body.linear_velocity.length_squared()>=.0625 or body.angular_velocity.length_squared()>=.49: return _fail("not_stably_supported")
	var frame: Transform3D=body.global_transform
	var key: String=_region_key(frame.origin)
	if _region_locks.has(key): return _fail("region_reserved",true)
	if not _regions.has(key) and _regions.size()>=_limits.regions: return _fail("region_capacity",true,_regions.size()+1,_limits.regions)
	var ids: Array=_regions[key].ids.duplicate() if _regions.has(key) else []
	var origin: Vector3=_regions[key].origin if _regions.has(key) else _region_origin(frame.origin)
	var next: Dictionary=record.duplicate(); next.frame=frame
	var source: Array=[]
	for previous: String in ids: source.append(_records[previous])
	source.append(next); ids.append(id)
	var begin: int=Time.get_ticks_usec()
	var batch: Dictionary=Batch.prepare(source,origin,_limits)
	_last_prepare_usec=Time.get_ticks_usec()-begin; _max_prepare_usec=maxi(_max_prepare_usec,_last_prepare_usec)
	if not batch.ok: return batch
	var support: Dictionary=_support_data(sample)
	if support.points.is_empty(): return _fail("support_expired")
	# Batch resources exist before the live body is disabled. No frame has a hole.
	_commit_region(key,ids,batch,origin)
	_release_slot(record.slot)
	record.frame=frame; record.phase="parked"; record.slot=-1; record.region=key; record.supports=support.ids; record.support_points=support.points; record.sample={}
	_link_supports(record)
	return {"ok":true,"parked":id,"cook_usec":_last_prepare_usec}

func _closure(initial: Array) -> Array:
	var selected: Dictionary={}; var queue: Array=initial.duplicate(); var cursor:=0
	while cursor<queue.size():
		var id: String=queue[cursor]; cursor+=1
		if selected.has(id) or not _records.has(id): continue
		selected[id]=true
		if _dependents.has(id):
			for child: String in _dependents[id]: queue.append(child)
	return selected.keys()

func _reserve_transition(wake: Array,remove: Array,velocity: Vector3,kind: String) -> Dictionary:
	if _disposed or _world==null: return _fail("not_configured")
	if _reservations.size()>=64: return _fail("reservation_capacity",true,1,0)
	var free: Array=_free_slots()
	if wake.size()>free.size(): return _fail("dependent_active_capacity",true,wake.size(),free.size())
	var selected: Dictionary={}; var affected: Dictionary={}
	for id: String in wake+remove:
		if not _records.has(id) or _record_locks.has(id): return _fail("record_reserved_or_missing",true)
		selected[id]=true
		var record: Dictionary=_records[id]
		if id in wake and record.phase!="parked": return _fail("wake_requires_parked")
		if record.phase=="parked": affected[record.region]=true
	if affected.size()>_limits.transition_regions: return _fail("transition_region_budget",false,affected.size(),_limits.transition_regions)
	var region_plans: Dictionary={}
	var begin: int=Time.get_ticks_usec()
	for key: String in affected:
		if _region_locks.has(key): return _fail("region_reserved",true)
		var region: Dictionary=_regions[key]
		var ids: Array=[]; var source: Array=[]
		for id: String in region.ids:
			if not selected.has(id): ids.append(id); source.append(_records[id])
		var batch: Dictionary=Batch.prepare(source,region.origin,_limits)
		if not batch.ok: return batch
		region_plans[key]={"ids":ids,"batch":batch,"revision":region.revision}
	var token: String=_token(); var entries: Array=[]
	for i: int in wake.size(): entries.append({"id":wake[i],"slot":free[i]}); _slot_tokens[free[i]]=token
	for id: String in selected: _record_locks[id]=token
	for key: String in affected: _region_locks[key]=token
	_reservations[token]={"kind":kind,"entries":entries,"epoch":_epoch,"regions":region_plans,"wake":wake.duplicate(),"remove":remove.duplicate(),"velocity":velocity.limit_length(4.0)}
	_last_prepare_usec=Time.get_ticks_usec()-begin; _max_prepare_usec=maxi(_max_prepare_usec,_last_prepare_usec)
	return {"ok":true,"token":token,"required":wake.size(),"affected_regions":affected.size(),"cook_usec":_last_prepare_usec}

func prepare_support_removal(bounds: AABB) -> Dictionary:
	if _disposed or _world==null or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<0 or bounds.size.y<0 or bounds.size.z<0: return _fail("support_bounds")
	var initial: Array=[]
	var search: AABB=bounds.grow(.12)
	for id: String in _records:
		var record: Dictionary=_records[id]
		if record.phase!="parked": continue
		var selected: bool=(record.frame*record.descriptor.bounds).intersects(search)
		for point: Vector3 in record.support_points:
			if search.has_point(point): selected=true
		if selected: initial.append(id)
	return _reserve_transition(_closure(initial),[],Vector3.ZERO,"support_removal")

func commit_support_removal(token: String) -> Dictionary:
	if not _reservations.has(token) or _reservations[token].kind!="support_removal": return _fail("not_support_reservation")
	return commit(token)

func impulse(bounds: AABB,velocity: Vector3) -> Dictionary:
	if _disposed or _world==null or not velocity.is_finite() or velocity.length()>4.0 or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<0 or bounds.size.y<0 or bounds.size.z<0: return _fail("impulse_limits")
	var initial: Array=[]; var active: Array=[]
	for id: String in _records:
		var record: Dictionary=_records[id]
		var frame: Transform3D=_slots[record.slot].global_transform if record.phase=="active" else record.frame
		if not (frame*record.descriptor.bounds).intersects(bounds): continue
		if record.phase=="parked": initial.append(id)
		else: active.append(id)
	var prepared: Dictionary=_reserve_transition(_closure(initial),[],velocity,"impulse")
	if not prepared.ok: return prepared
	var committed: Dictionary=commit(prepared.token)
	if not committed.ok: cancel(prepared.token); return committed
	for id: String in active:
		var body: RigidBody3D=_slots[_records[id].slot]
		body.sleeping=false; body.apply_central_impulse((velocity-body.linear_velocity).limit_length(3.2)*body.mass)
	return {"ok":true,"woken":prepared.required,"active_impulsed":active.size()}

func _region_impact(impact: Dictionary) -> void:
	if not _regions.has(impact.region) or Engine.get_physics_frames()-int(impact.get("tick",0))>3: return
	var initial: Array=[]
	for id: String in _regions[impact.region].ids:
		var record: Dictionary=_records[id]
		if (record.frame*record.descriptor.bounds).grow(.04).has_point(impact.point): initial.append(id)
	if initial.is_empty(): return
	var prepared: Dictionary=_reserve_transition(_closure(initial),[],impact.velocity,"contact_impulse")
	if prepared.ok: commit(prepared.token)
	else: blocked_reason=prepared.reason

func advance(delta: float) -> void:
	if _disposed or _world==null or not is_finite(delta) or delta<=0 or delta>.2: return
	var tick: int=Engine.get_physics_frames()
	if _last_tick==tick: return
	_last_tick=tick
	for i: int in mini(_limits.parks_per_tick,_park_queue.size()):
		var id: String=_park_queue.pop_front()
		var parked: Dictionary=_try_park(id)
		if not parked.ok and _records.has(id):
			_records[id].retry_tick=tick+30; blocked_reason=parked.reason
	for i: int in mini(2,_impacts.size()): _region_impact(_impacts.pop_front())

func push_from_actor(actor: CharacterBody3D,capsule: CollisionShape3D,delta: float) -> void:
	if _disposed or _world==null or not is_instance_valid(actor) or not is_instance_valid(capsule) or not actor.is_ancestor_of(capsule) or capsule.disabled or not capsule.shape is CapsuleShape3D or not is_finite(delta) or delta<=0 or delta>.2 or actor.collision_layer!=2 or (actor.collision_mask!=1 and actor.collision_mask!=1025): return
	var id: int=actor.get_instance_id(); var previous: Vector3=_last_actor.get(id,actor.global_position)
	if not _last_actor.has(id) and _last_actor.size()>=8: _last_actor.clear()
	_last_actor[id]=actor.global_position
	var moved: Vector3=actor.global_position-previous; moved.y=0
	if moved.length_squared()<.000001 or moved.length()>2.0: return
	var direction: Vector3=moved.normalized()
	var query:=PhysicsShapeQueryParameters3D.new(); query.collision_mask=2
	var ray:=PhysicsRayQueryParameters3D.new(); ray.collision_mask=1
	var candidates: Array=[]
	var radius: float=capsule.shape.radius
	var height: float=capsule.shape.height
	if radius<=0 or radius>1.0 or height<=0 or height>5.0: return
	var reach: AABB=capsule.global_transform*AABB(Vector3(-radius,-height*.5,-radius),Vector3(radius*2,height,radius*2))
	# Dynamic slots are bounded64; sleeping rubble is indexed by spatial region.
	# Walking beside one pile must not scan/allocate all2048 city rubble records.
	var nearby:Array=[]
	for slot:RigidBody3D in _slots:
		if not slot.record_id.is_empty(): nearby.append(slot.record_id)
	var lo=Vector3i(floori(reach.position.x/_limits.region_size),floori(reach.position.y/_limits.region_size),floori(reach.position.z/_limits.region_size))
	var hi=Vector3i(floori(reach.end.x/_limits.region_size),floori(reach.end.y/_limits.region_size),floori(reach.end.z/_limits.region_size))
	# Regions are keyed by fragment centroid. Include a one-metre border for
	# admitted <=1.733m diagonal pieces crossing a neighbouring region edge.
	lo-=Vector3i.ONE; hi+=Vector3i.ONE
	for x:int in range(lo.x,hi.x+1):
		for y:int in range(lo.y,hi.y+1):
			for z:int in range(lo.z,hi.z+1):
				var key:String="%d:%d:%d"%[x,y,z]
				if _regions.has(key): nearby.append_array(_regions[key].ids)
	for candidate_id:String in nearby:
		var record:Dictionary=_records[candidate_id]
		var frame: Transform3D=_slots[record.slot].global_transform if record.phase=="active" else record.frame
		if not (frame*record.descriptor.bounds).intersects(reach): continue
		query.shape=record.descriptor.shape; query.transform=frame
		var overlaps:=false
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,8):
			if hit.collider==actor: overlaps=true; break
		if not overlaps: continue
		ray.from=capsule.global_position; ray.to=frame.origin
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		candidates.append(record.id)
		if candidates.size()>=16: break
	var parked: Array=[]
	for candidate: String in candidates:
		if _records[candidate].phase=="parked": parked.append(candidate)
	var wake: Dictionary=_reserve_transition(_closure(parked),[],Vector3.ZERO,"actor_push")
	if not wake.ok: blocked_reason=wake.reason; return
	if not commit(wake.token).ok: cancel(wake.token); return
	for candidate: String in candidates:
		var body: RigidBody3D=_slots[_records[candidate].slot]
		var away: Vector3=body.global_position-actor.global_position; away.y=0
		var wanted: Vector3=direction*2.1+away.normalized()*.9
		body.apply_central_impulse((wanted-Vector3(body.linear_velocity.x,0,body.linear_velocity.z)).limit_length(3.2)*body.mass*minf(1.0,delta*12))
		body.set_meta("pushed_by_actor",true)

func reset_building(building_id: String) -> Dictionary:
	if _disposed or _world==null: return _fail("not_configured")
	# Invalidate staged changes before preparing a reset. Nothing committed is lost.
	for token: String in _reservations.keys(): cancel(token)
	var remove: Array=[]
	for id: String in _records:
		if _records[id].building_id==building_id: remove.append(id)
	var foreign: Array=[]
	for id: String in _closure(remove):
		if id not in remove and _records[id].phase=="parked": foreign.append(id)
	var prepared: Dictionary=_reserve_transition(foreign,remove,Vector3.ZERO,"reset")
	if not prepared.ok: return prepared
	var result: Dictionary=commit(prepared.token)
	if result.ok: _epoch+=1; _prepared_plans.clear()
	return result

func stats() -> Dictionary:
	var active:=0; var parked:=0; var surfaces:=0; var vertices:=0
	for record: Dictionary in _records.values():
		if record.phase=="active": active+=1
		elif record.phase=="parked": parked+=1
	for region: Dictionary in _regions.values(): surfaces+=region.surfaces; vertices+=region.vertices
	return {"configured":_world!=null and not _disposed,"dynamic_slots":_slots.size(),"active":active,"parked_records":parked,"logical_records":_records.size(),"free_slots":_free_slots().size(),"reserved_slots":_slot_tokens.size(),"reserved_new_records":_new_reserved,"reservations":_reservations.size(),"prepared_plans":_prepared_plans.size(),"parked_regions":_regions.size(),"parked_render_surfaces":surfaces,"parked_vertices":vertices,"queued_parks":_park_queue.size(),"queued_impacts":_impacts.size(),"last_prepare_usec":_last_prepare_usec,"max_prepare_usec":_max_prepare_usec,"blocked_reason":blocked_reason,"accepted_parity":false}

func dispose() -> void:
	if _disposed: return
	_disposed=true
	for token: String in _reservations.keys(): cancel(token)
	for body: RigidBody3D in _slots:
		body.collision_layer=0; body.collision_mask=0; body.visible=false; body.queue_free()
	for region: Dictionary in _regions.values():
		region.body.collision_layer=0; region.body.collision_mask=0; region.node.visible=false; region.node.queue_free()
	if is_instance_valid(_world) and _world.has_meta(LEASE):
		var owner: Variant=_world.get_meta(LEASE)
		if owner is WeakRef and owner.get_ref()==self: _world.remove_meta(LEASE)
	_slots.clear(); _records.clear(); _regions.clear(); _reservations.clear(); _prepared_plans.clear(); _plan_tokens.clear(); _slot_tokens.clear(); _record_locks.clear(); _region_locks.clear(); _dependents.clear(); _park_queue.clear(); _impacts.clear(); _last_actor.clear(); _new_reserved=0

func _exit_tree() -> void:
	dispose()
