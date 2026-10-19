extends RefCounted
## New reusable gameplay wall cores behind exact authored convex outer skins.
## A pure staged geometry component; scene, doors, glass and host commits are external.
const Source = preload("convex_source.gd")
const G = preload("geometry.gd")
const EPS := .00001
const MAX_SOLIDS := 2048
const MAX_BRUSHES := 32

class Job extends RefCounted:
	var parsed: Dictionary = {}
	var recipe: Dictionary = {}
	var planes: Array[Dictionary] = []
	var cursor := 0
	var remainder: Array[Dictionary] = []
	var walls: Array = []
	var stage := "hollow"
	var diagnostics := {"steps":0,"max_step_usec":0,"parse_usec":0}
	var result: Dictionary = {}
	var parent: Dictionary = {}
	var brush := AABB()
	var cut_index := 0
	var removed: Array = []
	var candidates: Array = []
	var history: Array[AABB] = []

static func begin(source: Dictionary, frame: Transform3D, recipe: Dictionary) -> Dictionary:
	if recipe.get("provenance","")!="USER_AUTHORIZED_NEW_GAMEPLAY_TEMPLATE": return _no("explicit_new_core_recipe_required")
	var thickness: Variant=recipe.get("wall_thickness_m")
	if not G._number(thickness) or float(thickness)<.08 or float(thickness)>.60: return _no("wall_thickness_limits")
	var profile: Dictionary=recipe.duplicate(true); profile.geometry_mode="hollow_convex_shell"
	var thickness_space:=str(recipe.get("thickness_space","world_metres"))
	var model_basis: Variant=recipe.get("world_from_model_basis",Basis.IDENTITY)
	if thickness_space not in ["world_metres","model_after_node"] or not model_basis is Basis or not model_basis.is_finite() or model_basis.determinant()<=.0000001: return _no("thickness_frame_contract")
	var started:=Time.get_ticks_usec()
	var parsed: Dictionary=Source._parse(source,frame,profile)
	if not parsed.ok: return parsed
	var job:=Job.new(); job.parsed=parsed; job.recipe=recipe.duplicate(true)
	job.parsed["original_mesh_materials"]=[]
	for surface: int in parsed.mesh.get_surface_count(): job.parsed.original_mesh_materials.append(parsed.mesh.surface_get_material(surface))
	job.diagnostics.parse_usec=Time.get_ticks_usec()-started
	job.remainder=parsed.faces
	var normal_matrix:=frame.basis.inverse().transposed()
	for face: Dictionary in parsed.faces:
		var world_normal: Vector3=(normal_matrix*face.normal).normalized()
		var normal: Vector3=frame.basis.transposed()*world_normal
		var anchor: Vector3=face.polygon[0]
		var duplicate:=false
		for plane: Dictionary in job.planes:
			if world_normal.dot(plane.world_normal)>.999999 and absf(normal.dot(anchor-plane.anchor))<EPS: duplicate=true; break
		var actual_thickness:=float(thickness)
		if thickness_space=="model_after_node": actual_thickness*= (model_basis.transposed()*world_normal).length()
		if not duplicate: job.planes.append({"normal":normal,"world_normal":world_normal,"anchor":anchor,"offset":-actual_thickness})
	return {"ok":true,"preparation":job,"planes":job.planes.size(),"scene_mutated":false}

static func advance(job: Job, max_steps: int=1, budget_usec: int=2000) -> Dictionary:
	if job==null or max_steps<1 or max_steps>8 or budget_usec<100 or budget_usec>10000: return _no("bounded_step_required")
	if job.stage=="cancelled": return _no("cancelled")
	if job.stage=="done": return {"ok":job.result.ok,"done":true,"result":job.result}
	var started:=Time.get_ticks_usec(); var count:=0
	while count<max_steps and job.stage!="done":
		var one:=Time.get_ticks_usec()
		var step: Dictionary=_hollow_step(job) if job.stage=="hollow" else _cut_step(job)
		job.diagnostics.max_step_usec=maxi(job.diagnostics.max_step_usec,Time.get_ticks_usec()-one)
		job.diagnostics.steps+=1; count+=1
		if not step.ok: job.result=step; job.stage="done"
		if Time.get_ticks_usec()-started>=budget_usec: break
	if job.stage=="done":
		job.result.diagnostics=job.diagnostics.duplicate()
		return {"ok":job.result.ok,"done":true,"result":job.result}
	return {"ok":true,"done":false,"stage":job.stage,"processed":job.cursor,"scene_mutated":false}

static func cancel(job: Job) -> void:
	if job==null or job.stage=="done": return
	job.parsed={}; job.walls=[]; job.remainder=[]; job.candidates=[]; job.removed=[]; job.stage="cancelled"

static func _hollow_step(job: Job) -> Dictionary:
	if job.cursor<job.planes.size():
		var p: Dictionary=job.planes[job.cursor]
		var outside:=_clip(job.remainder,p.normal,p.anchor,p.offset,false)
		job.remainder=_clip(job.remainder,p.normal,p.anchor,p.offset,true)
		if not outside.is_empty() and G._volume(outside,job.parsed.frame)>.0000001: job.walls.append(outside)
		job.cursor+=1
		if job.remainder.is_empty(): return _no("wall_core_fills_source_interior")
		return {"ok":true}
	var air_volume: float=G._volume(job.remainder,job.parsed.frame)
	var wall_volume:=_volumes(job.walls,job.parsed.frame)
	if air_volume<=.001: return _no("positive_interior_air_required")
	if absf(air_volume+wall_volume-job.parsed.original_volume)>maxf(.0001,job.parsed.original_volume*.000005): return _no("hollow_volume_conservation")
	job.result={"ok":true,"schema":"mafiozi.hollow-wall-state/v1","parsed":job.parsed,"recipe":job.recipe,"solids":job.walls,"inner_air":job.remainder,"outer_volume_m3":job.parsed.original_volume,"inner_air_m3":air_volume,"wall_volume_m3":wall_volume,"removed_volume_m3":0.0,"brushes":[],"scene_mutated":false,"source_unchanged":true,"whole_source_is_not_solid":true}
	job.stage="done"
	return {"ok":true}

static func begin_cut(state: Dictionary, brush_world: AABB) -> Dictionary:
	if state.get("schema","")!="mafiozi.hollow-wall-state/v1" or not state.get("ok",false): return _no("hollow_state_required")
	if not G._valid_brush(brush_world): return _no("finite_positive_brush_required")
	var guard:=validate_source(state)
	if not guard.ok: return guard
	var job:=Job.new(); job.stage="cut"; job.parent=state; job.parsed=state.parsed; job.recipe=state.recipe
	job.brush=brush_world; job.candidates=state.solids
	for previous: AABB in state.brushes: job.history.append(previous)
	# Geometry is cumulative; this bounded history is only a recent-duplicate cache.
	# Older impacts never have to be replayed and do not limit the number of shots.
	if job.history.size()>=MAX_BRUSHES: job.history.pop_front()
	job.history.append(brush_world)
	for axis: int in 3:
		var world_normal:=Vector3.ZERO; world_normal[axis]=1
		var normal: Vector3=job.parsed.frame.basis.transposed()*world_normal
		var anchor: Vector3=job.parsed.frame.affine_inverse()*brush_world.position
		job.planes.append({"normal":normal,"anchor":anchor,"offset":0.0,"less":false})
		job.planes.append({"normal":normal,"anchor":anchor,"offset":brush_world.size[axis],"less":true})
	return {"ok":true,"preparation":job,"scene_mutated":false}

static func _cut_step(job: Job) -> Dictionary:
	if job.cursor>=job.candidates.size():
		var removed:=_volumes(job.removed,job.parsed.frame)
		var kept:=_volumes(job.walls,job.parsed.frame)
		if absf(kept+removed-float(job.parent.wall_volume_m3))>maxf(.0001,float(job.parent.wall_volume_m3)*.00002): return _no("cut_volume_conservation")
		var state: Dictionary=job.parent.duplicate(); state.solids=job.walls; state.wall_volume_m3=kept
		state.removed_volume_m3=float(job.parent.removed_volume_m3)+removed; state.brushes=job.history
		job.result={"ok":true,"changed":removed>.0000001,"next_state":state,"removed_solids":job.removed,"new_removed_m3":removed,"kept_m3":kept,"scene_mutated":false}
		job.stage="done"; return {"ok":true}
	if job.remainder.is_empty():
		job.remainder=job.candidates[job.cursor]; job.cut_index=0
		if not _bounds(job.remainder,job.parsed.frame).intersects(job.brush):
			job.walls.append(job.remainder); job.remainder=[]; job.cursor+=1
			return {"ok":true}
	var plane: Dictionary=job.planes[job.cut_index]
	var outside:=_clip(job.remainder,plane.normal,plane.anchor,plane.offset,not plane.less)
	if not outside.is_empty() and G._volume(outside,job.parsed.frame)>.0000001: job.walls.append(outside)
	job.remainder=_clip(job.remainder,plane.normal,plane.anchor,plane.offset,plane.less)
	job.cut_index+=1
	if job.remainder.is_empty() or job.cut_index==6:
		if not job.remainder.is_empty() and G._volume(job.remainder,job.parsed.frame)>.0000001: job.removed.append(job.remainder)
		job.remainder=[]; job.cursor+=1
	if job.walls.size()+job.removed.size()>MAX_SOLIDS: return _no("solid_budget")
	return {"ok":true}

static func validate_source(state: Dictionary) -> Dictionary:
	var p: Dictionary=state.parsed; var mesh: ArrayMesh=p.mesh
	if mesh.get_surface_count()!=p.binding.arrays.size(): return _no("source_mutated")
	for i: int in mesh.get_surface_count():
		if mesh.surface_get_arrays(i)!=p.binding.arrays[i] or mesh.surface_get_material(i)!=p.original_mesh_materials[i]: return _no("source_mutated")
	return {"ok":true}

static func materialize(state: Dictionary) -> Dictionary:
	var checked:=validate_source(state)
	if not checked.ok: return checked
	var faces: Array[Dictionary]=[]
	for solid: Array in state.solids: faces.append_array(solid)
	if faces.is_empty(): return {"ok":true,"mesh":ArrayMesh.new(),"collision_faces_world":PackedVector3Array(),"scene_mutated":false}
	var started:=Time.get_ticks_usec()
	var built:=G._mesh(faces,state.parsed,Transform3D.IDENTITY)
	if not built.ok: return built
	var collisions:=PackedVector3Array()
	for surface: int in built.mesh.get_surface_count():
		var arrays: Array=built.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for i: int in range(0,points.size(),3):
			if (points[i+1]-points[i]).cross(points[i+2]-points[i]).length_squared()<1e-14: continue
			for j: int in 3: collisions.append(state.parsed.frame*points[i+j])
	built.collision_faces_world=collisions; built.scene_mutated=false; built.materialize_usec=Time.get_ticks_usec()-started
	return built

static func fragments(cut_result: Dictionary, max_volume_m3: float=.75) -> Dictionary:
	# No duplicated exterior/back skins: each descriptor is one closed removed solid.
	var state: Dictionary=cut_result.next_state
	var parsed: Dictionary=state.parsed.duplicate()
	parsed.profile=state.recipe.duplicate(); parsed.profile.thickness_m=state.recipe.wall_thickness_m
	var result: Array=[]
	for solid: Array[Dictionary] in cut_result.removed_solids:
		var volume: float=G._volume(solid,parsed.frame)
		if volume>max_volume_m3: return _no("fragment_subdivision_required")
		var fragment:=G._debris(solid,parsed,volume,_bounds(solid,parsed.frame))
		if not fragment.ok: return fragment
		result.append(fragment)
	return {"ok":true,"fragments":result,"scene_mutated":false}

static func _clip(input: Array[Dictionary], normal: Vector3, anchor: Vector3, offset: float, less: bool) -> Array[Dictionary]:
	if input.is_empty(): return []
	var signum:=1.0 if less else -1.0; var inside:=0; var outside:=0
	for face: Dictionary in input:
		for p: Vector3 in face.polygon:
			if (normal.dot(p-anchor)-offset)*signum>EPS: outside+=1
			else: inside+=1
	if outside==0: return input
	if inside==0: return []
	var result: Array[Dictionary]=[]; var cap: Array[Vector3]=[]
	for face: Dictionary in input:
		var polygon: Array[Vector3]=[]; var last: Vector3=face.polygon.back()
		var last_distance: float=(normal.dot(last-anchor)-offset)*signum
		for p: Vector3 in face.polygon:
			var distance: float=(normal.dot(p-anchor)-offset)*signum
			if (distance<=EPS)!=(last_distance<=EPS):
				var crossing:=last.lerp(p,clampf(last_distance/(last_distance-distance),0,1))
				_unique(polygon,crossing); _unique(cap,crossing)
			if distance<=EPS:
				_unique(polygon,p)
				if absf(distance)<=EPS: _unique(cap,p)
			last=p; last_distance=distance
		if polygon.size()>=3:
			var clipped: Dictionary=face.duplicate(); clipped.polygon=polygon; result.append(clipped)
	if cap.size()<3: return []
	var centre:=Vector3.ZERO
	for p: Vector3 in cap: centre+=p
	centre/=cap.size()
	var outward: Vector3=normal.normalized()*signum
	var seed:=Vector3.RIGHT if absf(outward.x)<.8 else Vector3.UP
	var u: Vector3=(seed-outward*seed.dot(outward)).normalized(); var v:=outward.cross(u)
	cap.sort_custom(func(a: Vector3,b: Vector3) -> bool: return atan2((a-centre).dot(v),(a-centre).dot(u))<atan2((b-centre).dot(v),(b-centre).dot(u)))
	result.append({"polygon":cap,"normal":outward,"source_face":-1,"surface":-1,"grid_axis":-1,"grid_plane":-1})
	return result

static func _unique(points: Array[Vector3], point: Vector3) -> void:
	for p: Vector3 in points:
		if p.distance_squared_to(point)<1e-12: return
	points.append(point)

static func _volumes(solids: Array, frame: Transform3D) -> float:
	var sum:=0.0
	for faces: Array[Dictionary] in solids: sum+=G._volume(faces,frame)
	return sum

static func _bounds(faces: Array[Dictionary], frame: Transform3D) -> AABB:
	var result:=AABB(frame*faces[0].polygon[0],Vector3.ZERO)
	for face: Dictionary in faces:
		for p: Vector3 in face.polygon: result=result.expand(frame*p)
	return result

static func _no(reason: String) -> Dictionary: return {"ok":false,"reason":reason,"scene_mutated":false}
