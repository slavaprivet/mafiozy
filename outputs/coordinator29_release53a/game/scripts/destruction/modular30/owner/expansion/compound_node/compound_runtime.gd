extends Node3D
## Opt-in rollout candidate. Production owner must admit replacement geometry.
const Cut=preload("../../vendor/surface_cut.gd")
const Strength=preload("../../vendor/material_strength.gd")
const Rubble=preload("../../compatibility/rubble_manager_1025.gd")
const Groups=preload("../../vendor/collision_groups.gd")
const Chunks=preload("../../vendor/chunks/closed_patch_fragments.gd")
const WalkGlass=preload("../../vendor/glass/walk_glass_breakage.gd")
const Blocks=preload("compound_dispatch.gd")
const Contact=preload("compound_contact.gd")
const CELL=.65
const DEBRIS_LAYER=512
const MAX_ACTIVE=64
const MAX_EVENTS=8192
var _world:Node3D
var buildings:Dictionary={}
var _jobs:Array=[]
var _seen:Dictionary={}
var _rubble:Node3D
var _outcomes:Dictionary={}
var _ray=PhysicsRayQueryParameters3D.new()
var last_job_usec=0
var max_job_usec=0
var phase_max_usec:Dictionary={}
var _disposed=false
var blocked_reason=""
var _mesh_groups:Dictionary={}
var _body_groups:Dictionary={}

func configure(world:Node3D) -> Dictionary:
	if _world!=null or not is_instance_valid(world) or not world.is_inside_tree(): return {"ok":false,"reason":"world"}
	if not global_transform.is_equal_approx(Transform3D.IDENTITY): return {"ok":false,"reason":"runtime_requires_world_identity"}
	_world=world
	_rubble=Rubble.new(); add_child(_rubble)
	var configured:Dictionary=_rubble.configure(world)
	if not configured.ok: _rubble.queue_free(); _world=null; return configured
	_ray.collision_mask=1
	return {"ok":true,"scope":"local_preview_candidate","debris_layer":DEBRIS_LAYER}

func _collect(node:Node,meshes:Array) -> bool:
	if node is Node3D and not node.is_visible_in_tree(): return true
	if node is MultiMeshInstance3D: return false # Explicit instance descriptors required.
	if node is MeshInstance3D and node.mesh!=null: meshes.append(node)
	for child:Node in node.get_children():
		if not _collect(child,meshes): return false
	return true

func _faces(mesh:Mesh,frame:Transform3D) -> PackedVector3Array:
	var source:PackedVector3Array=mesh.get_faces(); var result=PackedVector3Array()
	for i:int in range(0,source.size(),3):
		var a:Vector3=frame*source[i]; var b:Vector3=frame*source[i+1]; var c:Vector3=frame*source[i+2]
		if (b-a).cross(c-a).length_squared()<.0000000001: continue
		result.append(a); result.append(b); result.append(c)
	return result

func _shape(mesh:Mesh,frame:Transform3D) -> ConcavePolygonShape3D:
	var shape=ConcavePolygonShape3D.new(); shape.backface_collision=true
	shape.set_faces(_faces(mesh,frame)); return shape

func register_building(source_id:String,visual_root:Node3D,collider_roots:Array,record:Dictionary) -> Dictionary:
	if _disposed or _world==null or buildings.has(source_id) or source_id.is_empty() or record.get("id","")!=source_id: return {"ok":false,"reason":"identity"}
	if record.get("collision_replacement_approved",false)!=true: return {"ok":false,"reason":"owner_geometry_admission_required"}
	if record.get("assetId","")=="print_shop" and record.get("modular_geometry_provenance","")!="GENERATED_CLOSED_BOX_MODULES_V1": return {"ok":false,"reason":"printshop_per_part_mapping_required"}
	if not is_instance_valid(visual_root) or not visual_root.is_inside_tree() or collider_roots.is_empty(): return {"ok":false,"reason":"missing_originals"}
	var meshes:Array=[]
	if not _collect(visual_root,meshes): return {"ok":false,"reason":"instance_descriptors_required"}
	for extra:Node3D in record.get("runtime_extra_roots",[]):
		if not _collect(extra,meshes): return {"ok":false,"reason":"instance_descriptors_required"}
	var prepared:Array=[]; var eligible_count=0
	var component_profiles:Variant=record.get("component_profiles",{})
	if not component_profiles is Dictionary: return {"ok":false,"reason":"component_profiles_dictionary"}
	var consumed_profiles:Dictionary={}
	for body in collider_roots:
		if not is_instance_valid(body) or not body is StaticBody3D or body.get_meta("source_id","")!=source_id or body.has_meta("interior_kind"): return {"ok":false,"reason":"collider_ownership"}
	for mesh:MeshInstance3D in meshes:
		if not mesh.global_transform.is_finite() or mesh.global_basis.determinant()<=.00001: return {"ok":false,"reason":"transform"}
		var eligible:Dictionary={}; var excluded:Dictionary={}
		for s:int in mesh.mesh.get_surface_count():
			var profiles:Dictionary=record.get("material_profiles",{})
			var override:String=str(profiles.get(str(mesh.name)+":"+str(s),""))
			var mixed:bool=mesh.mesh.get_surface_count()>1
			var material:Material=mesh.get_active_material(s)
			var family:String="glass" if WalkGlass.is_breakable_glass(mesh,material,mixed) else Strength.classify(str(mesh.name),material,override,mixed)
			if family not in ["glass","unknown"] and Cut.supported(mesh.mesh): eligible[s]=family; eligible_count+=1
			else: excluded[s]=family
		var geometry:Dictionary=Groups.source_faces(mesh.mesh,mesh.global_transform)
		if not geometry.ok: return geometry
		if geometry.faces.is_empty(): continue
		var thickness:float=float(record.get("wall_thickness_m",.2))
		if not is_finite(thickness) or thickness<.05 or thickness>2.0: return {"ok":false,"reason":"wall_thickness"}
		var component:Dictionary={}
		var part_path:String=str(visual_root.get_path_to(mesh))
		if component_profiles.has(part_path):
			if not component_profiles[part_path] is Dictionary: return {"ok":false,"reason":"component_profile_dictionary","part":part_path}
			var profile:Dictionary=component_profiles[part_path].duplicate(true)
			var materials:Array=[]
			for surface:int in mesh.mesh.get_surface_count(): materials.append(mesh.get_active_material(surface))
			var source:Dictionary={"mesh":mesh.mesh,"current_mesh":mesh.mesh,"materials":materials,"source_id":source_id,"source_part_id":part_path,"label":str(mesh.name)}
			var inspected:Dictionary=Blocks.inspect(source,mesh.global_transform,profile)
			if not inspected.ok: return {"ok":false,"reason":"component_profile:"+str(inspected.reason),"part":part_path}
			# One physical solid has one damage ledger, even if its source skins
			# use several visual materials. Its profile is explicitly owner supplied.
			eligible_count-=eligible.size(); eligible={0:str(profile.material_class).to_lower()}; eligible_count+=1
			excluded.clear(); thickness=float(inspected.thickness_m)
			var overrides:Dictionary={}
			for surface:int in mesh.get_surface_override_material_count():
				if mesh.get_surface_override_material(surface)!=null: overrides[surface]=mesh.get_surface_override_material(surface)
			component={"source":source,"profile":profile,"inspection":inspected,"material_override":mesh.material_override,"surface_overrides":overrides}
			consumed_profiles[part_path]=true
		prepared.append({"node":mesh,"original":mesh.mesh,"frame":mesh.global_transform,"bounds":mesh.global_transform*mesh.get_aabb(),"eligible":eligible,"excluded":excluded,"geometry":geometry,"damage":{},"damage_revision":0,"body":null,"collision":null,"thickness":thickness,"component":component,"component_state":{}})
	for part_path:Variant in component_profiles:
		if not consumed_profiles.has(part_path): return {"ok":false,"reason":"component_profile_source_missing","part":str(part_path)}
	if eligible_count==0 or prepared.is_empty(): return {"ok":false,"reason":"no_admitted_materials"}
	var collision_plan:Dictionary=Groups.prepare(prepared)
	if not collision_plan.ok: return collision_plan
	# Commit only after every original, mesh and collider has passed preflight.
	var originals:Array=[]
	for body:StaticBody3D in collider_roots:
		originals.append({"body":body,"layer":body.collision_layer,"mask":body.collision_mask})
	for group:Dictionary in collision_plan.groups:
		var body=StaticBody3D.new(); body.set_meta("source_id",source_id)
		if group.parts.size()==1: body.set_meta("source_mesh",group.parts[0].node)
		body.set_meta("destruction_surface_body",true); body.collision_layer=1; body.collision_mask=1
		var collision=CollisionShape3D.new(); collision.shape=group.shape; body.add_child(collision); add_child(body)
		group.body=body; group.collision=collision; group.generation=1
		_body_groups[body.get_instance_id()]=group
		for part:Dictionary in group.parts:
			part.body=body; part.collision=collision; _mesh_groups[part.node.get_instance_id()]=group
	for saved:Dictionary in originals: saved.body.collision_layer=0; saved.body.collision_mask=0
	buildings[source_id]={"root":visual_root,"parts":prepared,"groups":collision_plan.groups,"original_colliders":originals,"generation":1}
	return {"ok":true,"parts":prepared.size(),"collision_groups":collision_plan.groups.size(),"eligible_surfaces":eligible_count,"original_hulls_retired":originals.size(),"glass":"separate_owner_required"}

func apply_explosion(receipt:Dictionary) -> Dictionary:
	if _disposed or receipt.get("admitted")!=true or receipt.get("authority")!="local_preview": return {"ok":false,"reason":"authority"}
	var id:String=str(receipt.get("event_id","")); var source_id:String=str(receipt.get("source_id",""))
	var now=Time.get_ticks_msec()
	for old_id in _seen.keys():
		if now-int(_seen[old_id])>30000: _seen.erase(old_id); _outcomes.erase(old_id) # Owner bridge consumes terminal shots within15s.
	if id.is_empty() or id.length()>200 or _seen.has(id) or _seen.size()>=MAX_EVENTS: return {"ok":false,"reason":"duplicate_or_event_budget"}
	if not buildings.has(source_id): return {"ok":false,"reason":"unregistered_building"}
	if not receipt.get("position") is Vector3 or not receipt.get("direction") is Vector3: return {"ok":false,"reason":"coordinates"}
	var at:Vector3=receipt.position; var direction:Vector3=receipt.direction
	var power:float=float(receipt.get("power",0)); var radius:float=float(receipt.get("radius",0))
	if not at.is_finite() or not direction.is_finite() or not is_finite(power) or not is_finite(radius) or power<=0 or power>10000 or radius<=0 or radius>.9: return {"ok":false,"reason":"blast_limits"}
	if _jobs.size()>=32: return {"ok":false,"reason":"queue_full_retry"}
	var parts:Array=[]
	for part:Dictionary in buildings[source_id].parts:
		if not part.eligible.is_empty() and part.bounds.grow(radius).has_point(at): parts.append(part)
	if parts.size()>32: return {"ok":false,"reason":"candidate_part_budget"}
	_seen[id]=now
	_jobs.append({"receipt":receipt.duplicate(),"source_id":source_id,"generation":buildings[source_id].generation,"parts":parts,"index":0,"failures":[],"committed_parts":0})
	_outcomes[id]={"state":"queued","committed_parts":0,"failures":[]}
	return {"ok":true,"queued":true,"event_id":id}

func _component_materials(part:Dictionary,node:MeshInstance3D) -> Dictionary:
	if part.component.is_empty(): return {"ok":true}
	var component:Dictionary=part.component
	var overrides:Dictionary={}
	if part.get("component_overrides_baked",false):
		if node.material_override!=null or node.mesh.get_surface_count()!=part.generated_materials.size(): return {"ok":false,"reason":"baked_component_material_changed"}
		for surface:int in node.get_surface_override_material_count():
			if node.get_surface_override_material(surface)!=null: return {"ok":false,"reason":"baked_component_material_changed"}
		for surface:int in node.mesh.get_surface_count():
			if node.mesh.surface_get_material(surface)!=part.generated_materials[surface]: return {"ok":false,"reason":"baked_component_material_changed"}
		overrides=component.surface_overrides
	else:
		if node.material_override!=component.material_override: return {"ok":false,"reason":"component_effective_material_changed"}
		for surface:int in node.get_surface_override_material_count():
			if node.get_surface_override_material(surface)!=null: overrides[surface]=node.get_surface_override_material(surface)
		if overrides!=component.surface_overrides: return {"ok":false,"reason":"component_effective_material_changed"}
	var materials:Array=[]
	# Output surface numbers may change when a source skin is fully removed.
	# Validate original material bindings, not newly generated reveal surfaces.
	for surface:int in part.original.get_surface_count():
		var material:Material=component.material_override if component.material_override!=null else overrides.get(surface,part.original.surface_get_material(surface))
		if material!=component.source.materials[surface] or material==null or (not Blocks.is_compound(component.profile) and (material.get_meta("breakableGlass",false)==true or float(material.get_meta("transmission",0.0))>0.0)):
			return {"ok":false,"reason":"component_effective_material_changed"}
		materials.append(material)
	return {"ok":true,"materials":materials}

func _component_mesh_snapshot(mesh:Mesh) -> Array:
	var result:Array=[]
	for surface:int in mesh.get_surface_count(): result.append(mesh.surface_get_arrays(surface).duplicate(true))
	return result

func _component_mesh_matches(mesh:Mesh,snapshot:Array) -> bool:
	if mesh.get_surface_count()!=snapshot.size(): return false
	for surface:int in mesh.get_surface_count():
		if mesh.surface_get_arrays(surface)!=snapshot[surface]: return false
	return true

func _cut_part(part:Dictionary,event:Dictionary,source_id:String,job:Dictionary) -> void:
	var node:MeshInstance3D=part.node
	if not is_instance_valid(node) or not node.global_transform.is_equal_approx(part.frame) or part.eligible.is_empty(): return
	var material_guard:Dictionary=_component_materials(part,node)
	if not material_guard.ok: _stage_failed(job,material_guard.reason); return
	if not part.component.is_empty() and Blocks.is_compound(part.component.profile):
		_cut_compound_part(part,event,source_id,job); return
	var at:Vector3=event.position; var radius:float=event.radius
	if not (node.global_transform*node.get_aabb()).grow(radius).has_point(at): return
	# A directly admitted hit may damage its own surface. Other parts need a
	# clear path from the blast, so a solid facade shields nearby inner walls.
	var contact:Dictionary=resolve_collision_contact(event.get("collider"),at,event.direction)
	var hit_mesh:Variant=contact.get("object")
	if hit_mesh!=node:
		var nearest:Vector3=part.bounds.position.clamp(part.bounds.position,part.bounds.end)
		nearest=at.clamp(part.bounds.position,part.bounds.end)
		_ray.from=at-event.direction.normalized()*.04; _ray.to=nearest
		var obstruction:Dictionary=get_world_3d().direct_space_state.intersect_ray(_ray)
		if not obstruction.is_empty():
			if obstruction.collider!=part.body: return
			var front:Dictionary=resolve_collision_contact(obstruction.collider,obstruction.position,nearest-_ray.from)
			if front.get("object")!=node: return
	var centre=Vector3i(floori(at.x/CELL),floori(at.y/CELL),floori(at.z/CELL))
	var brushes:Dictionary={}; var changed_keys:Array=[]
	var staged_damage:Dictionary=part.damage.duplicate()
	for s in part.eligible:
		for dx:int in range(-1,2):
			for dy:int in range(-1,2):
				for dz:int in range(-1,2):
					var cell:Vector3i=centre+Vector3i(dx,dy,dz)
					var cell_box=AABB(Vector3(cell)*CELL,Vector3.ONE*CELL)
					if not part.bounds.grow(.0001).intersects(cell_box): continue
					var amount=Strength.cell_damage(event.power,at,cell_box,radius)
					if amount<=0: continue
					var key=str(s)+":"+str(cell)
					var previous:float=part.damage.get(key,0.0)
					if previous<0: continue
					var health:float=Strength.threshold(part.eligible[s],part.thickness)
					staged_damage[key]=previous+amount
					if staged_damage[key]<health: continue
					if not brushes.has(s): brushes[s]=[]
					brushes[s].append(cell_box); changed_keys.append(key)
	if brushes.is_empty(): part.damage=staged_damage; part.damage_revision+=1; return
	var cut_bounds:AABB=brushes.values()[0][0]
	for cells:Array in brushes.values():
		for brush:AABB in cells: cut_bounds=cut_bounds.merge(brush)
	if not part.component.is_empty():
		var world_brushes:Array[AABB]=[]
		for cells:Array in brushes.values():
			for brush:AABB in cells:
				if not world_brushes.has(brush): world_brushes.append(brush)
		var source:Dictionary=part.component.source.duplicate()
		source.current_mesh=node.mesh
		source.materials=material_guard.materials
		var beginning:Dictionary=Blocks.begin_prepare(source,part.frame,world_brushes,part.component.profile,part.component_state,part.component.inspection.get("admission"))
		if not beginning.ok: _stage_failed(job,"component_begin:"+str(beginning.reason)); return
		job.prepared={"part":part,"source_mesh":node.mesh,"source_arrays":_component_mesh_snapshot(node.mesh),"damage_revision":part.damage_revision,"component_preparation":beginning.preparation,"damage":staged_damage,"keys":changed_keys,"bounds":cut_bounds,"phase":"convex_cells"}
		return
	var result:Dictionary=Cut.cut(node.mesh,part.frame,brushes)
	if not result.ok: _stage_failed(job,result.get("reason","surface_cut")); return
	if result.removed_triangles==0: part.damage=staged_damage; part.damage_revision+=1; return
	for index:int in result.removed_surfaces.size(): result.removed.surface_set_material(index,node.get_active_material(result.removed_surfaces[index]))
	# Expensive preparation is spread over physics ticks. Neither the wall nor
	# accumulated damage changes until the final collision/visual commit.
	job.prepared={"part":part,"source_mesh":node.mesh,"damage_revision":part.damage_revision,"result":result,"damage":staged_damage,"keys":changed_keys,"bounds":cut_bounds,"phase":"fragments"}

func _discard_prepared(job:Dictionary) -> void:
	if not job.has("prepared"): return
	var staged:Dictionary=job.prepared
	if staged.has("plan"): _rubble.discard_plan(staged.plan)
	if staged.has("component_preparation"): Blocks.cancel(staged.component_preparation)
	job.erase("prepared")

func _stage_failed(job:Dictionary,reason:String) -> bool:
	blocked_reason=reason
	var part:Dictionary=job.parts[job.index]
	job.failures.append({"part":job.index,"reason":reason,"source_id":job.source_id,"source_part_id":str(buildings[job.source_id].root.get_path_to(part.node)) if is_instance_valid(part.node) else "retired_node"})
	_discard_prepared(job); return true

func _capacity_retry(job:Dictionary,result:Dictionary) -> bool:
	if not result.get("retryable",false): return _stage_failed(job,str(result.reason))
	var now:int=Time.get_ticks_msec()
	if not job.has("waiting_since"): job.waiting_since=now
	if now-int(job.waiting_since)>3000: return _stage_failed(job,"capacity_timeout:"+str(result.reason))
	job.ready_tick=Engine.get_physics_frames()+6
	_outcomes[str(job.receipt.event_id)]={"state":"waiting_for_rubble_slots","committed_parts":job.committed_parts,"required":result.get("required",0),"available":result.get("available",0),"failures":job.failures.duplicate(true)}
	return false

func _advance_prepared(job:Dictionary) -> bool:
	var staged:Dictionary=job.prepared; var part:Dictionary=staged.part
	var node:MeshInstance3D=part.node
	if not is_instance_valid(node) or not node.global_transform.is_equal_approx(part.frame):
		return _stage_failed(job,"staged_source_moved")
	var material_guard:Dictionary=_component_materials(part,node)
	if not material_guard.ok: return _stage_failed(job,material_guard.reason)
	if node.mesh!=staged.source_mesh or part.damage_revision!=staged.damage_revision:
		# Glass can fracture during the intervening tick. Recompute against the
		# current mesh so its hole is never filled by an older opaque-wall result.
		# A second queued subthreshold hit can also update damage without changing
		# geometry. Rebase instead of overwriting that newer accumulated damage.
		_discard_prepared(job); job.retries=int(job.get("retries",0))+1
		if job.retries>4: return _stage_failed(job,"staged_source_changed_retry_limit")
		return false
	if not part.component.is_empty() and staged.phase in ["resources","commit"]:
		if not _component_mesh_matches(node.mesh,staged.source_arrays): return _stage_failed(job,"staged_component_arrays_changed")
		var source:Dictionary=part.component.source.duplicate(); source.current_mesh=node.mesh; source.materials=material_guard.materials
		var validation:Dictionary=Blocks.validate_admission(source,part.frame,part.component.profile,part.component.inspection.get("admission"))
		if not validation.ok: return _stage_failed(job,"staged_component_admission:"+str(validation.reason))
	if staged.phase=="convex_cells":
		var advanced:Dictionary=Blocks.advance(staged.component_preparation,1,1000)
		if not advanced.ok: return _stage_failed(job,"component_prepare:"+str(advanced.get("reason","failed")))
		if not advanced.done: return false
		var component_result:Dictionary=advanced.result
		if not component_result.changed:
			if component_result.has("next_state"): part.component_state=component_result.next_state
			part.damage=staged.damage; part.damage_revision+=1; _discard_prepared(job); return true
		staged.result={"mesh":component_result.wall_mesh}
		staged.component_state=component_result.next_state
		if component_result.has("cut_bounds"): staged.bounds=component_result.cut_bounds
		staged.pieces=component_result.debris_descriptors
		staged.phase="resources"; return false
	if staged.phase=="fragments":
		var fragments:Dictionary=Chunks.prepare(staged.result.removed,part.frame,part.thickness,.5,MAX_ACTIVE)
		if not fragments.ok: return _stage_failed(job,"fragment_preflight:"+str(fragments.reason))
		staged.pieces=fragments.pieces; staged.phase="resources"; return false
	if staged.phase=="resources":
		var launch={"linear_velocity":(-job.receipt.direction.normalized()+Vector3.UP*.25)*2.3,"angular_velocity":Vector3(.7,.5,.8)}
		var plan:Dictionary=_rubble.prepare(job.source_id,str(node.get_instance_id()),staged.pieces,launch)
		if not plan.ok: return _capacity_retry(job,plan)
		staged.plan=plan; staged.phase="commit"; return false
	# Both new fragments and already parked dependents need actual pool slots
	# BEFORE removing their support. Failure leaves source geometry untouched.
	var support:Dictionary=_rubble.prepare_support_removal(staged.bounds)
	if not support.ok: return _capacity_retry(job,support)
	var ticket:Dictionary=_rubble.reserve(staged.plan)
	if not ticket.ok:
		_rubble.cancel(support.token)
		if ticket.reason in ["expired_or_reserved_plan","foreign_or_stale_plan"]:
			_rubble.discard_plan(staged.plan); staged.erase("plan"); staged.phase="resources"; return false
		return _capacity_retry(job,ticket)
	# Same-turn mesh/collision commit. Glass surfaces are copied from CURRENT mesh.
	var group:Dictionary=_mesh_groups[node.get_instance_id()]
	var replacement:Dictionary=Groups.rebuild(group,node,staged.result.mesh)
	if not replacement.ok:
		_rubble.cancel(ticket.token); _rubble.cancel(support.token)
		return _stage_failed(job,replacement.reason)
	var released:Dictionary=_rubble.commit_transaction([support.token,ticket.token])
	if not released.ok:
		_rubble.cancel(ticket.token); _rubble.cancel(support.token); return _stage_failed(job,released.reason)
	node.mesh=staged.result.mesh; _bake_component_overrides(part); Groups.commit(group,replacement)
	if staged.has("component_state"): part.component_state=staged.component_state
	part.damage=staged.damage
	part.damage_revision+=1
	for key:String in staged.keys: part.damage[key]=-1.0
	job.committed_parts+=1
	job.erase("prepared"); return true

func push_from_actor(actor:CharacterBody3D,capsule:CollisionShape3D,delta:float) -> void:
	if not _disposed and is_instance_valid(_rubble): _rubble.push_from_actor(actor,capsule,delta)

func refresh_glass_collision(mesh:MeshInstance3D) -> bool:
	if _disposed or not is_instance_valid(mesh) or not _mesh_groups.has(mesh.get_instance_id()): return false
	var group:Dictionary=_mesh_groups[mesh.get_instance_id()]
	var replacement:Dictionary=Groups.rebuild(group)
	if not replacement.ok: return false
	Groups.commit(group,replacement); return true

func owns_collision_mesh(body:Variant,mesh:Variant) -> bool:
	return not _disposed and is_instance_valid(body) and is_instance_valid(mesh) and _mesh_groups.has(mesh.get_instance_id()) and _mesh_groups[mesh.get_instance_id()].body==body

func collider_for_mesh(mesh:Variant) -> StaticBody3D:
	if _disposed or not is_instance_valid(mesh) or not _mesh_groups.has(mesh.get_instance_id()): return null
	return _mesh_groups[mesh.get_instance_id()].body

func resolve_collision_contact(body:Variant,point:Vector3,direction:Vector3) -> Dictionary:
	if _disposed or not is_instance_valid(body) or not _body_groups.has(body.get_instance_id()): return {"ok":false,"reason":"unregistered_collider"}
	return Groups.resolve(_body_groups[body.get_instance_id()],point,direction)

func _physics_process(delta:float) -> void:
	if _disposed: return
	if is_instance_valid(_rubble): _rubble.advance(delta)
	if not _jobs.is_empty():
		var job:Dictionary=_jobs.pop_front()
		if not buildings.has(job.source_id) or buildings[job.source_id].generation!=job.generation:
			_discard_prepared(job); _outcomes[str(job.receipt.event_id)]={"state":"cancelled_generation","committed_parts":job.committed_parts,"failures":job.failures}
		elif job.index>=job.parts.size():
			_outcomes[str(job.receipt.event_id)]={"state":"completed" if job.failures.is_empty() else "partial_or_failed","committed_parts":job.committed_parts,"failures":job.failures}
		elif Engine.get_physics_frames()<int(job.get("ready_tick",0)): _jobs.append(job)
		else:
			var begin:int=Time.get_ticks_usec()
			var phase:String=str(job.prepared.phase) if job.has("prepared") else "cut"
			if job.has("prepared"):
				if _advance_prepared(job): job.index+=1; job.retries=0; job.erase("waiting_since")
			else:
				_cut_part(job.parts[job.index],job.receipt,job.source_id,job)
				if not job.has("prepared"): job.index+=1; job.retries=0
			last_job_usec=Time.get_ticks_usec()-begin; max_job_usec=maxi(max_job_usec,last_job_usec)
			phase_max_usec[phase]=maxi(int(phase_max_usec.get(phase,0)),last_job_usec)
			_jobs.append(job)

func reset_building(source_id:String) -> Dictionary:
	if not buildings.has(source_id): return {"ok":false}
	var building:Dictionary=buildings[source_id]
	var restored:Array=[]
	for group:Dictionary in building.groups:
		var prepared:Dictionary=Groups.rebuild(group,null,null,true)
		if not prepared.ok: return prepared
		restored.append(prepared)
	var cleared:Dictionary=_rubble.reset_building(source_id)
	if not cleared.ok: return cleared
	building.generation+=1
	for part:Dictionary in building.parts:
		if is_instance_valid(part.node): part.node.mesh=part.original; _restore_component_overrides(part); part.damage.clear(); part.damage_revision+=1; part.component_state.clear()
	for i:int in building.groups.size(): Groups.commit(building.groups[i],restored[i])
	return {"ok":true,"glass_reset_required":true}

func event_status(event_id:String) -> Dictionary:
	return _outcomes.get(event_id,{"state":"unknown_or_expired"}).duplicate(true)

func stats() -> Dictionary:
	var rubble:Dictionary=_rubble.stats() if is_instance_valid(_rubble) else {}
	return {"registered":buildings.size(),"collision_groups":_body_groups.size(),"source_parts":_mesh_groups.size(),"queued":_jobs.size(),"debris":rubble.get("logical_records",0),"rubble":rubble,"max_job_usec":max_job_usec,"phase_max_usec":phase_max_usec.duplicate(),"blocked_reason":blocked_reason,"mass_rollout_accepted":false}

func dispose() -> void:
	if _disposed: return
	_disposed=true
	for job:Dictionary in _jobs: _discard_prepared(job)
	_jobs.clear()
	if is_instance_valid(_rubble): _rubble.dispose(); _rubble.queue_free()
	for building:Dictionary in buildings.values():
		for part:Dictionary in building.parts:
			if is_instance_valid(part.node): part.node.mesh=part.original; _restore_component_overrides(part)
		for group:Dictionary in building.groups:
			if is_instance_valid(group.body): group.body.queue_free()
		for saved:Dictionary in building.original_colliders:
			if is_instance_valid(saved.body): saved.body.collision_layer=saved.layer; saved.body.collision_mask=saved.mask
	buildings.clear(); _mesh_groups.clear(); _body_groups.clear(); _outcomes.clear()

func _exit_tree() -> void:
	dispose()

func _bake_component_overrides(part:Dictionary) -> void:
	if part.component.is_empty() or (part.component.material_override==null and part.component.surface_overrides.is_empty()): return
	var node:MeshInstance3D=part.node
	node.material_override=null
	for surface:int in node.get_surface_override_material_count(): node.set_surface_override_material(surface,null)
	part.component_overrides_baked=true; part.generated_materials=[]
	for surface:int in node.mesh.get_surface_count(): part.generated_materials.append(node.mesh.surface_get_material(surface))

func _restore_component_overrides(part:Dictionary) -> void:
	if not part.get("component_overrides_baked",false): return
	var node:MeshInstance3D=part.node
	node.material_override=part.component.material_override
	for surface:int in node.get_surface_override_material_count(): node.set_surface_override_material(surface,null)
	for surface:int in part.component.surface_overrides: node.set_surface_override_material(surface,part.component.surface_overrides[surface])
	part.component_overrides_baked=false; part.generated_materials=[]


func _cut_compound_part(part:Dictionary,event:Dictionary,source_id:String,job:Dictionary) -> void:
	# Same admitted host receipt, but one physical strength ledger per child.
	# Render and collider still commit once, through the inherited transaction.
	var node:MeshInstance3D=part.node
	var admission:Variant=part.component.inspection.admission
	var at:Vector3=event.position; var radius:float=event.radius
	var candidates:Array=Blocks.candidates(admission,at,radius)
	if candidates.size()>32: _stage_failed(job,"compound_candidate_budget"); return
	var contact:Dictionary=resolve_collision_contact(event.get("collider"),at,event.direction)
	var direct_id:int=-1
	if contact.get("object")==node:
		direct_id=Blocks.component_for_face(admission,part.component_state,contact.surface_index,contact.face_index)
	var visible:Array=[]
	for id:int in candidates:
		if id==direct_id: visible.append(id); continue
		var faces:PackedVector3Array=part.component_state.get("world_faces",{}).get(id,admission.children[id].world_faces)
		var actual:Dictionary=Contact.closest_point(faces,at)
		if not actual.ok: continue
		var nearest:Vector3=actual.point
		_ray.from=at-event.direction.normalized()*.04
		_ray.to=nearest+(nearest-_ray.from).normalized()*.003
		if _ray.from.distance_squared_to(_ray.to)<.00000001: continue
		var obstruction:Dictionary=get_world_3d().direct_space_state.intersect_ray(_ray)
		if obstruction.is_empty(): continue
		if obstruction.collider!=part.body: continue
		var resolved:Dictionary=resolve_collision_contact(obstruction.collider,obstruction.position,nearest-_ray.from)
		if resolved.get("object")!=node: continue
		if Blocks.component_for_face(admission,part.component_state,resolved.surface_index,resolved.face_index)==id: visible.append(id)
	var source:Dictionary=part.component.source.duplicate(); source.current_mesh=node.mesh
	var beginning:Dictionary=Blocks.begin_event(source,part.frame,part.component.profile,part.component_state,admission,event,visible)
	if not beginning.ok: _stage_failed(job,"compound_begin:"+str(beginning.reason)); return
	job.prepared={"part":part,"source_mesh":node.mesh,"source_arrays":_component_mesh_snapshot(node.mesh),"damage_revision":part.damage_revision,"component_preparation":beginning.preparation,"damage":part.damage.duplicate(),"keys":[],"bounds":AABB(at-Vector3.ONE*radius,Vector3.ONE*radius*2),"phase":"convex_cells"}
