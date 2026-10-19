extends RefCounted
## Drop-in PURE component preparation for the private, inherited runtime host.
## Old solid pieces retain the pinned adapter; new hollow skins require a recipe.
const Solid=preload("../vendor/blocks/convex_component_adapter.gd")
const Rubble=preload("../vendor/rubble/rubble_manager.gd")
const Hollow=preload("hollow_shell.gd")
const Assembly=preload("mesh_assembler.gd")
const G=preload("geometry.gd")
const Strength=preload("../material_strength.gd")
const Measured=preload("measured_solid.gd")

class Admission extends RefCounted:
	var initial: Dictionary={}
	var source: Dictionary={}
	var profile: Dictionary={}
	var frame:=Transform3D.IDENTITY

class Preparation extends RefCounted:
	var admission: Admission
	var state: Dictionary={}
	var previous: Dictionary={}
	var brushes: Array[AABB]=[]
	var cursor:=0
	var active: Variant=null
	var removed: Array=[]
	var fragment_queue: Array=[]
	var pieces: Array=[]
	var descriptors: Array=[]
	var assembly: Variant=null
	var mesh_result: Dictionary={}
	var new_volume:=0.0
	var stage:="cuts"
	var result: Dictionary={}
	var diagnostics: Dictionary={"max_step_usec":0,"steps":0,"initialization_usec":0}

static func inspect(source: Dictionary, frame: Transform3D, profile: Dictionary) -> Dictionary:
	var mode:=str(profile.get("geometry_mode",""))
	if mode not in ["hollow_convex_shell","measured_convex_solid"]: return Solid.inspect(source,frame,profile)
	# The inherited damage ledger has one strength value per source/cell. A
	# model-scaled geometry recipe needs a future per-plane strength ledger.
	if mode=="hollow_convex_shell" and profile.get("thickness_space","world_metres")!="world_metres": return _no("world_gameplay_strength_profile_required")
	var started:=Time.get_ticks_usec()
	# Cold loading admission only. Live cuts reuse this immutable core state.
	var state: Dictionary={}
	if mode=="measured_convex_solid":
		var measured:=Measured.prepare(source,frame,profile)
		if not measured.ok: return measured
		state=measured.state
	else:
		var begin:=Hollow.begin(source,frame,profile)
		if not begin.ok: return begin
		for i: int in 1024:
			var step:=Hollow.advance(begin.preparation,4,2000)
			if not step.ok: return step.get("result",step)
			if step.done: state=step.result; break
	if state.is_empty(): return _no("hollow_admission_budget")
	var admission:=Admission.new(); admission.initial=state; admission.profile=profile.duplicate(true)
	admission.source=source.duplicate(true); admission.frame=frame
	return {"ok":true,"admission":admission,"thickness_m":state.recipe.wall_thickness_m,"true_volume_m3":state.wall_volume_m3,"outer_volume_m3":state.outer_volume_m3,"inner_air_m3":state.inner_air_m3,"triangles":state.parsed.triangle_count,"source_unchanged":true,"parse_usec":Time.get_ticks_usec()-started,"cold_loading_only":true,"scene_mutated":false}

static func validate_admission(source: Dictionary, frame: Transform3D, profile: Dictionary, admission: Variant) -> Dictionary:
	if not admission is Admission: return Solid.validate_admission(source,frame,profile,admission)
	if frame!=admission.frame or profile!=admission.profile or source.get("mesh")!=admission.source.mesh or source.get("source_id")!=admission.source.source_id or source.get("source_part_id")!=admission.source.source_part_id or source.get("label","")!=admission.source.get("label",""): return _no("stale_hollow_admission")
	if source.get("breakable_glass",false): return _no("glass_has_separate_owner")
	var materials: Variant=source.get("materials",[])
	if not materials is Array or (not materials.is_empty() and materials.size()!=admission.initial.parsed.materials.size()): return _no("material_count")
	for surface: int in admission.initial.parsed.materials.size():
		var material: Material=source.mesh.surface_get_material(surface) if materials.is_empty() else materials[surface]
		if material!=admission.initial.parsed.materials[surface] or material==null: return _no("source_material_changed")
		if Strength.classify(str(source.get("label","")),material,profile.material_class,source.mesh.get_surface_count()>1)=="glass" or float(material.get_meta("transmission",0.0))>0.0: return _no("glass_has_separate_owner")
	return Hollow.validate_source(admission.initial)

static func begin_prepare(source: Dictionary, frame: Transform3D, brushes_world: Array[AABB], profile: Dictionary, previous: Dictionary={}, admission: Variant=null) -> Dictionary:
	if profile.get("geometry_mode","") not in ["hollow_convex_shell","measured_convex_solid"]: return Solid.begin_prepare(source,frame,brushes_world,profile,previous,admission)
	if not admission is Admission: return _no("cached_hollow_admission_required")
	var valid:=validate_admission(source,frame,profile,admission)
	if not valid.ok: return valid
	if not previous.is_empty() and (previous.get("schema","")!="mafiozi.hollow-component-runtime-state/v1" or previous.get("admission")!=admission): return _no("previous_binding")
	if source.get("current_mesh",source.mesh)!=previous.get("wall_mesh",source.mesh): return _no("current_mesh_mismatch")
	var job:=Preparation.new(); job.admission=admission; job.previous=previous
	job.state=admission.initial if previous.is_empty() else previous.hollow_state
	for brush: AABB in brushes_world:
		if not G._valid_brush(brush): return _no("invalid_brush")
		if not job.brushes.has(brush) and not job.state.brushes.has(brush): job.brushes.append(brush)
	if job.brushes.size()>Hollow.MAX_BRUSHES: return _no("event_brush_budget")
	return {"ok":true,"preparation":job,"scene_mutated":false}

static func advance(job: Variant, max_items: int=1, budget_usec: int=1000) -> Dictionary:
	if not job is Preparation: return Solid.advance(job,max_items,budget_usec)
	if max_items<1 or max_items>8 or budget_usec<100 or budget_usec>10000: return _no("bounded_step_required")
	if job.stage=="cancelled": return _no("cancelled")
	if job.stage=="done": return {"ok":job.result.ok,"done":true,"result":job.result}
	var started:=Time.get_ticks_usec()
	# One old runtime cell allows several cheap clipping planes. Continue work
	# within the same measured tick budget instead of adding one frame per plane.
	for operation: int in 32:
		var remaining:=maxi(100,budget_usec-int(Time.get_ticks_usec()-started))
		var work:=_step(job,mini(8,max_items*8),remaining)
		job.diagnostics.steps+=1
		if not work.ok: job.stage="done"; job.result=work
		if job.stage=="done" or Time.get_ticks_usec()-started>=budget_usec: break
	job.diagnostics.max_step_usec=maxi(job.diagnostics.max_step_usec,Time.get_ticks_usec()-started)
	if job.stage=="done":
		job.result.diagnostics=job.diagnostics.duplicate()
		return {"ok":job.result.ok,"done":true,"result":job.result,"reason":job.result.get("reason","")}
	return {"ok":true,"done":false,"stage":job.stage}

static func _step(job: Preparation, max_items: int, budget_usec: int) -> Dictionary:
	if job.stage=="cuts":
		if job.cursor>=job.brushes.size():
			if job.new_volume<=.0000001:
				job.result={"ok":true,"changed":false,"debris_descriptors":[],"scene_mutated":false}; job.stage="done"; return {"ok":true}
			job.stage="assembly"; job.assembly=Assembly.begin(job.state)
			return {"ok":true}
		if job.active==null:
			var begin:=Hollow.begin_cut(job.state,job.brushes[job.cursor])
			if not begin.ok: return begin
			job.active=begin.preparation
		var step:=Hollow.advance(job.active,max_items,budget_usec)
		if not step.ok: return step.get("result",step)
		if step.done:
			job.state=step.result.next_state; job.removed.append_array(step.result.removed_solids)
			job.new_volume+=step.result.new_removed_m3; job.active=null; job.cursor+=1
		return {"ok":true}
	if job.stage=="assembly":
		var step: Dictionary=Assembly.advance(job.assembly,128,mini(1000,budget_usec))
		if not step.ok: return step.get("result",step)
		if step.done:
			job.mesh_result=step.result; job.stage="subdivide"; job.fragment_queue=job.removed.duplicate(); job.removed=[]; job.cursor=0
		return {"ok":true}
	if job.stage=="subdivide":
		if job.fragment_queue.is_empty(): job.stage="fragments"; job.cursor=0; return {"ok":true}
		if job.fragment_queue.size()+job.removed.size()>64: return _no("rubble_pool_budget")
		var faces: Array[Dictionary]=job.fragment_queue.pop_back()
		var frame: Transform3D=job.state.parsed.frame
		var bounds:=Hollow._bounds(faces,frame); var axis:=bounds.size.max_axis_index()
		var chunk: float=float(job.admission.profile.get("chunk_size_m",.65))
		if bounds.size[axis]<=chunk+.0001 and G._volume(faces,frame)<=.75:
			job.removed.append(faces); return {"ok":true}
		var world_normal:=Vector3.ZERO; world_normal[axis]=1
		var normal: Vector3=frame.basis.transposed()*world_normal
		var anchor: Vector3=frame.affine_inverse()*bounds.get_center()
		for less: bool in [true,false]:
			var piece:=Hollow._clip(faces,normal,anchor,0.0,less)
			if not piece.is_empty() and G._volume(piece,frame)>.0000001: job.fragment_queue.append(piece)
		return {"ok":true}
	if job.stage=="fragments":
		if job.cursor>=job.removed.size(): job.stage="done"; job.result=_finish(job); return {"ok":true}
		if job.removed.size()>64: return _no("rubble_pool_budget")
		var faces: Array[Dictionary]=job.removed[job.cursor]
		var parsed: Dictionary=job.state.parsed.duplicate(); parsed.profile=job.state.recipe.duplicate()
		parsed.profile.thickness_m=job.state.recipe.wall_thickness_m
		var volume: float=G._volume(faces,parsed.frame)
		if volume>.75: return _no("fragment_subdivision_invariant")
		var piece:=G._debris(faces,parsed,volume,Hollow._bounds(faces,parsed.frame))
		if not piece.ok: return piece
		var adapted:=Rubble.adapt_slab_descriptor(piece)
		if not adapted.ok: return adapted
		job.pieces.append(piece); job.descriptors.append(adapted.descriptor); job.cursor+=1
		return {"ok":true}
	return _no("unknown_stage")

static func _finish(job: Preparation) -> Dictionary:
	var state: Dictionary={"schema":"mafiozi.hollow-component-runtime-state/v1","admission":job.admission,"hollow_state":job.state,"wall_mesh":job.mesh_result.mesh}
	return {"ok":true,"changed":true,"wall_mesh":job.mesh_result.mesh,"wall_frame":job.admission.frame,"wall_collision_faces_world":job.mesh_result.collision_faces_world,"wall_face_provenance":job.mesh_result.provenance,"debris":job.pieces,"debris_descriptors":job.descriptors,"next_state":state,"original_volume_m3":job.admission.initial.wall_volume_m3,"remaining_volume_m3":job.state.wall_volume_m3,"total_removed_volume_m3":job.state.removed_volume_m3,"new_removed_volume_m3":job.new_volume,"geometry_kind":job.state.get("core_geometry","source_skin_with_explicit_hollow_core"),"scene_mutated":false}

static func cancel(job: Variant) -> void:
	if not job is Preparation: Solid.cancel(job); return
	if job.active!=null: Hollow.cancel(job.active)
	if job.assembly!=null: Assembly.cancel(job.assembly)
	job.active=null; job.assembly=null; job.removed=[]; job.stage="cancelled"

static func _no(reason: String) -> Dictionary: return {"ok":false,"reason":reason,"scene_mutated":false}
