extends RefCounted
## Pure compound source-node staging. Each closed child owns its real strength.
## Unselected/held triangles survive in ONE replacement mesh. Host owns commit.
const Child=preload("../../modules/component_dispatch.gd")
const Panels=preload("../../panels/source_planar_panels.gd")
const Strength=preload("../../material_strength.gd")
const Render=preload("../compound_render/compound_render.gd")
const CELL:=.65
const MAX_COMPONENTS:=512
const MAX_EVENT_COMPONENTS:=32
const MAX_DAMAGE_CELLS:=8192

class Admission extends RefCounted:
	var source: Dictionary={}
	var profile: Dictionary={}
	var frame:=Transform3D.IDENTITY
	var panels: Dictionary={}
	var render_binding: Variant=null
	var children: Dictionary={}
	var initial_lookup: Dictionary={}
	var owned_materials: Array=[]
	var diagnostics: Dictionary={}

class Preparation extends RefCounted:
	var admission: Admission
	var previous: Dictionary={}
	var event: Dictionary={}
	var ids: Array=[]
	var index:=0
	var stage:="damage"
	var damage: Dictionary={}
	var states: Dictionary={}
	var replacements: Dictionary={}
	var world_faces: Dictionary={}
	var pieces: Array=[]
	var active: Variant=null
	var brushes: Array[AABB]=[]
	var keys: Array[String]=[]
	var changed_components: Array[int]=[]
	var render_job: Variant=null
	var render_result: Dictionary={}
	var new_volume:=0.0
	var cut_bounds:=AABB()
	var result: Dictionary={}
	var diagnostics: Dictionary={"calls":0,"max_advance_usec":0,"total_active_usec":0,"loaded_scene_fps_verified":false}

static func is_compound(profile: Dictionary) -> bool: return profile.get("geometry_mode","")=="compound_source_node"

static func inspect(source: Dictionary,frame: Transform3D,profile: Dictionary) -> Dictionary:
	if not is_compound(profile): return Child.inspect(source,frame,profile)
	if profile.get("provenance","")!="USER_AUTHORIZED_NEW_GAMEPLAY_TEMPLATE" or str(profile.get("profile_id","")).is_empty(): return _no("explicit_compound_design_required")
	if not profile.get("components") is Array or profile.components.is_empty() or profile.components.size()>MAX_COMPONENTS: return _no("bounded_explicit_component_profiles_required")
	var started:=Time.get_ticks_usec()
	var panels: Dictionary={}
	if profile.get("generated_partition") is Dictionary:
		panels=profile.generated_partition
		if panels.get("provenance","")!="GENERATED_CLOSED_BOX_MODULES_V1": return _no("generated_partition_provenance")
		var validation:=Panels.validate_result(panels,source,frame)
		if not validation.ok: return validation
	else:
		var begin:=Panels.begin(source,frame)
		if not begin.ok: return begin
		for i: int in 100000:
			var step:=Panels.advance(begin.preparation,128,1000)
			if not step.ok: return step
			if step.done: panels=step.result; break
		if panels.is_empty(): Panels.cancel(begin.preparation); return _no("panel_preparation_budget")
	var held: Array=profile.get("owner_held_component_ids",[])
	# Opaque compound nodes own their entire render resource. Mutable glass,
	# doors and external owners must remain separate nodes until an explicit
	# owner-replacement/provenance merge API exists.
	if not held.is_empty() or not profile.get("external_mutable_component_ids",[]).is_empty(): return _no("external_owners_require_separate_render_nodes")
	for material: Material in panels.source_snapshot.materials:
		if material==null or Strength.classify("",material,"",true)=="glass" or float(material.get_meta("transmission",0.0))>0: return _no("glass_requires_separate_render_node")
	var binding: Dictionary=Render.capture_binding(source,panels,held)
	if not binding.ok: return binding
	var admission:=Admission.new(); admission.source=source.duplicate(true); admission.profile=profile.duplicate(true)
	admission.frame=frame; admission.panels=panels; admission.render_binding=binding
	for entry: Variant in profile.components:
		if not entry is Dictionary or not entry.get("component_id") is int or not entry.get("profile") is Dictionary: return _no("component_profile_contract")
		var id: int=entry.component_id
		if id<0 or id>=panels.source_components.size() or admission.children.has(id) or held.has(id): return _no("component_identity_duplicate_or_owner_hold")
		var component: Dictionary=panels.source_components[id]
		if not component.closed_manifold: return _no("closed_authored_component_required")
		# An explicit selector is mandatory: numeric enumeration is not authority.
		if not entry.get("source_faces") is Array or entry.source_faces!=component.source_faces: return _no("exact_component_face_selector_required")
		var subset:=Panels.component_mesh(panels,id,128)
		if not subset.ok: return subset
		var child_source: Dictionary={"mesh":subset.mesh,"source_id":source.source_id,"source_part_id":str(source.source_part_id)+"#component:"+str(id),"label":source.get("label","")}
		var inspected:=Child.inspect(child_source,frame,entry.profile)
		if not inspected.ok: return {"ok":false,"reason":"component_"+str(id)+":"+str(inspected.reason),"scene_mutated":false}
		var map: Dictionary={}
		for face: Dictionary in subset.face_provenance: map[Vector2i(face.output_surface,face.output_triangle)]=Vector2i(face.source_surface,face.source_triangle)
		var world_faces:=PackedVector3Array()
		for point: Vector3 in subset.mesh.get_faces(): world_faces.append(frame*point)
		admission.children[id]={"source":child_source,"profile":entry.profile.duplicate(true),"admission":inspected.admission,"thickness_m":inspected.thickness_m,"source_faces":component.source_faces.duplicate(),"bounds":component.bounds,"provenance":map,"world_faces":world_faces}
		for surface: int in subset.mesh.get_surface_count():
			var entry_material: Dictionary={"material":subset.mesh.surface_get_material(surface),"label":str(child_source.label),"family":str(entry.profile.material_class),"mixed":subset.mesh.get_surface_count()>1}
			if not admission.owned_materials.has(entry_material): admission.owned_materials.append(entry_material)
	for component: Dictionary in panels.source_components:
		for face: Vector2i in component.source_faces: admission.initial_lookup[face]=component.component_id
	admission.diagnostics={"cold_admission_usec":Time.get_ticks_usec()-started,"source_components":panels.source_components.size(),"damage_components":admission.children.size(),"source_triangles":panels.coverage.source_triangles,"cold_loading_only":true}
	return {"ok":true,"admission":admission,"thickness_m":.2,"thickness_placeholder_not_used_for_damage":true,"physical_strength_per_component":true,"cold_loading_only":true,"scene_mutated":false,"diagnostics":admission.diagnostics}

static func validate_admission(source: Dictionary,frame: Transform3D,profile: Dictionary,admission: Variant) -> Dictionary:
	if not admission is Admission: return Child.validate_admission(source,frame,profile,admission)
	if frame!=admission.frame or profile!=admission.profile or source.get("mesh")!=admission.source.mesh or source.get("source_id")!=admission.source.source_id or source.get("source_part_id")!=admission.source.source_part_id: return _no("stale_compound_binding")
	var result:=Panels.validate_result(admission.panels,source,frame)
	if not result.ok: return result
	return _validate_materials(admission)

static func _validate_materials(admission: Admission) -> Dictionary:
	var binding: Dictionary=admission.render_binding
	for guard: Dictionary in binding.material_guards:
		if Render._material_snapshot(guard.material)!=guard.snapshot: return _no("compound_material_properties_changed")
	for row: Dictionary in admission.owned_materials:
		if row.material.get_meta("breakableGlass",false)==true or float(row.material.get_meta("transmission",0.0))>0 or Strength.classify(row.label,row.material,row.family,row.mixed)=="glass": return _no("compound_damage_material_became_glass")
	return {"ok":true}

static func component_for_face(admission: Admission,previous: Dictionary,surface: int,triangle: int) -> int:
	if admission==null: return -1
	var lookup: Dictionary=previous.get("face_lookup",admission.initial_lookup)
	return int(lookup.get(Vector2i(surface,triangle),-1))

static func candidates(admission: Admission,at: Vector3,radius: float) -> Array[int]:
	var result: Array[int]=[]
	for id: int in admission.children:
		if admission.children[id].bounds.grow(radius).has_point(at): result.append(id)
	return result

static func begin_event(source: Dictionary,frame: Transform3D,profile: Dictionary,previous: Dictionary,admission: Admission,event: Dictionary,visible_ids: Array) -> Dictionary:
	var valid:=validate_admission(source,frame,profile,admission)
	if not valid.ok: return valid
	if not previous.is_empty() and (previous.get("schema","")!="mafiozi.compound-node-state/v1" or previous.get("admission")!=admission): return _no("previous_compound_binding")
	if source.get("current_mesh",source.mesh)!=previous.get("wall_mesh",source.mesh): return _no("current_compound_mesh_mismatch")
	if event.get("admitted")!=true or event.get("authority","")!="local_preview" or event.get("source_id")!=source.source_id or str(event.get("event_id","")).is_empty(): return _no("admitted_event_required")
	if not event.get("position") is Vector3 or not event.position.is_finite() or not event.get("direction") is Vector3 or not event.direction.is_finite() or event.direction.length_squared()<.000001: return _no("finite_event_geometry")
	var power: float=float(event.get("power",0)); var radius: float=float(event.get("radius",0))
	if not is_finite(power) or power<=0 or power>10000 or not is_finite(radius) or radius<=0 or radius>.9 or visible_ids.size()>MAX_EVENT_COMPONENTS: return _no("event_budget")
	var job:=Preparation.new(); job.admission=admission; job.previous=previous; job.event=event.duplicate()
	job.damage=previous.get("damage",{}).duplicate(); job.states=previous.get("components",{}).duplicate(); job.replacements=previous.get("replacements",{}).duplicate()
	job.world_faces=previous.get("world_faces",{}).duplicate()
	for id: Variant in visible_ids:
		if not id is int or not admission.children.has(id) or job.ids.has(id) or not admission.children[id].bounds.grow(radius).has_point(event.position): return _no("validated_visible_component_required")
		job.ids.append(id)
	return {"ok":true,"preparation":job,"scene_mutated":false}

static func begin_prepare(source: Dictionary,frame: Transform3D,brushes: Array[AABB],profile: Dictionary,previous: Dictionary={},admission: Variant=null) -> Dictionary:
	if is_compound(profile): return _no("compound_requires_per_component_damage_and_visibility")
	return Child.begin_prepare(source,frame,brushes,profile,previous,admission)

static func advance(job: Variant,max_items: int=1,budget_usec: int=1000) -> Dictionary:
	if not job is Preparation: return Child.advance(job,max_items,budget_usec)
	if max_items<1 or max_items>8 or budget_usec<100 or budget_usec>1000: return _no("bounded_compound_step_required")
	if job.stage=="cancelled": return _no("cancelled")
	if job.stage=="done": return {"ok":job.result.ok,"done":true,"result":job.result}
	var started:=Time.get_ticks_usec()
	var step:=_step(job,budget_usec)
	if not step.ok: job.result=step; job.stage="done"
	var elapsed:=Time.get_ticks_usec()-started
	job.diagnostics.calls+=1; job.diagnostics.total_active_usec+=elapsed; job.diagnostics.max_advance_usec=maxi(job.diagnostics.max_advance_usec,elapsed)
	if job.stage=="done": job.result.diagnostics=job.diagnostics.duplicate(); return {"ok":job.result.ok,"done":true,"result":job.result,"reason":job.result.get("reason","")}
	return {"ok":true,"done":false,"stage":job.stage}

static func _step(job: Preparation,budget: int) -> Dictionary:
	if job.stage=="damage":
		if job.index>=job.ids.size():
			if job.changed_components.is_empty(): job.result=_finish(job,{}); job.stage="done"; return {"ok":true}
			job.render_job=Render.begin(job.admission.render_binding,job.replacements.values()); job.stage="render"; return {"ok":true}
		var id: int=job.ids[job.index]; var child: Dictionary=job.admission.children[id]
		var at: Vector3=job.event.position; var centre:=Vector3i((at/CELL).floor())
		job.brushes=[]; job.keys=[]
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				for dz: int in range(-1,2):
					var cell:=centre+Vector3i(dx,dy,dz); var box:=AABB(Vector3(cell)*CELL,Vector3.ONE*CELL)
					if not child.bounds.grow(.0001).intersects(box): continue
					var amount:=Strength.cell_damage(job.event.power,at,box,job.event.radius)
					if amount<=0: continue
					var key:=str(id)+":"+str(cell); var before: float=job.damage.get(key,0.0)
					if before<0: continue
					job.damage[key]=before+amount
					if job.damage.size()>MAX_DAMAGE_CELLS: return _no("compound_damage_memory_budget")
					if job.damage[key]>=Strength.threshold(child.profile.material_class,child.thickness_m): job.brushes.append(box); job.keys.append(key)
		if job.brushes.is_empty(): job.index+=1; return {"ok":true}
		var previous: Dictionary=job.states.get(id,{})
		var source: Dictionary=child.source.duplicate(); source.current_mesh=previous.get("wall_mesh",source.mesh)
		var beginning:=Child.begin_prepare(source,job.admission.frame,job.brushes,child.profile,previous,child.admission)
		if not beginning.ok: return beginning
		job.active=beginning.preparation; job.stage="child"; return {"ok":true}
	if job.stage=="child":
		var step:=Child.advance(job.active,1,budget)
		if not step.ok: return step.get("result",step)
		if not step.done: return {"ok":true}
		var result: Dictionary=step.result; var id: int=job.ids[job.index]
		if result.changed:
			if job.pieces.size()+result.debris_descriptors.size()>64: return _no("compound_rubble_pool_budget")
			var mapped:=_replacement(job.admission,id,result)
			if not mapped.ok: return mapped
			job.replacements[id]=mapped.replacement; job.states[id]=result.next_state
			job.world_faces[id]=result.wall_collision_faces_world
			job.pieces.append_array(result.debris_descriptors); job.new_volume+=result.new_removed_volume_m3; job.changed_components.append(id)
			for box: AABB in job.brushes: job.cut_bounds=box if job.cut_bounds.size==Vector3.ZERO else job.cut_bounds.merge(box)
		for key: String in job.keys: job.damage[key]=-1.0
		job.active=null; job.index+=1; job.stage="damage"; return {"ok":true}
	if job.stage=="render":
		var step: Dictionary=Render.advance(job.render_job,128,budget)
		if not step.ok: return step.get("result",step)
		if step.done: job.render_result=step.result; job.result=_finish(job,step.result); job.stage="done"
		return {"ok":true}
	return _no("compound_stage")

static func _replacement(admission: Admission,id: int,result: Dictionary) -> Dictionary:
	var child: Dictionary=admission.children[id]; var provenance: Array=[]
	for row: Dictionary in result.wall_face_provenance:
		var copied: Dictionary=row.duplicate(true)
		if row.generated_reveal: copied.source_surface=-1; copied.source_triangles=[]
		else:
			var ids: Array[int]=[]; var original_surface:=-1
			for local_id: int in row.source_triangles:
				var key:=Vector2i(row.source_surface,local_id)
				if not child.provenance.has(key): return _no("child_source_face_mapping")
				var original: Vector2i=child.provenance[key]
				if original_surface>=0 and original_surface!=original.x: return _no("child_cross_surface_mapping")
				original_surface=original.x; ids.append(original.y)
			copied.source_surface=original_surface; copied.source_triangles=ids
		provenance.append(copied)
	return {"ok":true,"replacement":{"component_id":id,"source_faces":child.source_faces,"mesh":result.wall_mesh,"provenance":provenance}}

static func _finish(job: Preparation,rendered: Dictionary) -> Dictionary:
	var material_guard:=_validate_materials(job.admission)
	if not material_guard.ok: return material_guard
	var changed:=not job.changed_components.is_empty()
	var mesh: ArrayMesh=rendered.mesh if changed else job.previous.get("wall_mesh",job.admission.source.mesh)
	var lookup: Dictionary=job.previous.get("face_lookup",job.admission.initial_lookup)
	if changed:
		lookup={}
		for row: Dictionary in rendered.provenance: lookup[Vector2i(row.output_surface,row.output_triangle)]=row.component_id
	var state: Dictionary={"schema":"mafiozi.compound-node-state/v1","admission":job.admission,"components":job.states,"damage":job.damage,"replacements":job.replacements,"wall_mesh":mesh,"face_lookup":lookup,"world_faces":job.world_faces}
	return {"ok":true,"changed":changed,"wall_mesh":mesh,"next_state":state,"debris_descriptors":job.pieces,"new_removed_volume_m3":job.new_volume,"changed_components":job.changed_components,"cut_bounds":job.cut_bounds,"scene_mutated":false,"render_diagnostics":rendered.get("diagnostics",{}),"physical_strength_per_component":true}

static func cancel(job: Variant) -> void:
	if not job is Preparation: Child.cancel(job); return
	if job.active!=null: Child.cancel(job.active)
	if job.render_job!=null: Render.cancel(job.render_job)
	job.stage="cancelled"; job.active=null; job.render_job=null; job.pieces=[]; job.replacements={}; job.states={}; job.damage={}

static func _no(reason: String) -> Dictionary: return {"ok":false,"reason":reason,"scene_mutated":false}
