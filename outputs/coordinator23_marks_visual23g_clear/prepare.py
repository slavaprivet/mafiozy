from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
SRC=ROOT/'outputs/coordinator23_marks_visual23g'
for name in ['frozen_actual_input.gd','run_capture.py']:(OUT/name).write_bytes((SRC/name).read_bytes())
s=(SRC/'capture.gd').read_text()
s=s.replace('var extra_delay_frames:=0','''var extra_delay_frames:=0
var observer_proof:Dictionary={}
var eye_samples:Array[Dictionary]=[]''')
start=s.index('func place_observer(');end=s.index('func capture(',start)
s=s[:start]+'''func eyes_geometry()->Dictionary:
	var renderer:RefCounted=owner.marks.renderer
	if not renderer._valid():return {}
	var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	if not physical._eyes.closed:return {}
	if eye_samples.is_empty():
		for plan:Dictionary in physical._eyes._meshes:
			var node:MeshInstance3D=plan.node.get_ref()
			if not "SKIN" in str(node.name).to_upper():continue
			for sid in renderer._surfaces.size():
				var surface:Dictionary=renderer._surfaces[sid]
				if surface.node.get_ref()!=node:continue
				var before:PackedVector3Array=plan.original.surface_get_arrays(surface.surface)[Mesh.ARRAY_VERTEX]
				var after:PackedVector3Array=plan.closed.surface_get_arrays(surface.surface)[Mesh.ARRAY_VERTEX]
				for i in before.size():
					if before[i]!=after[i]:eye_samples.append({"surface":sid,"index":i})
	if eye_samples.is_empty():return {}
	var point:=Vector3.ZERO
	var matrices:Dictionary={}
	for sample:Dictionary in eye_samples:
		var surface:Dictionary=renderer._surfaces[sample.surface]
		if not matrices.has(sample.surface):matrices[sample.surface]=renderer._matrices(surface)
		point+=renderer._vertex(surface,sample.index,matrices[sample.surface])
	point/=float(eye_samples.size())
	var frame:=head_frame()
	var head_center:Vector3=(owner._head_zone._head_min+owner._head_zone._head_max)*.5
	var outward:Vector3=frame.affine_inverse()*point-head_center;outward.y=0
	if outward.length_squared()<.000001:return {}
	return {"point":point,"normal":(frame.basis*outward).normalized(),"up":frame.basis.y.normalized(),"original_closed_vertices":eye_samples.size()}

func place_observer(label:String)->void:
	observer_proof={"ok":false,"label":label}
	var wound:bool=label in ["01_clothing_wound","02_head_skin_wound"]
	var geometry:Dictionary=mark_geometry(label=="01_clothing_wound") if wound else eyes_geometry()
	if geometry.is_empty():return
	var point:Vector3=geometry.point;var normal:Vector3=geometry.normal
	var up:Vector3=Vector3.UP if wound else geometry.up
	var tangent:Vector3=normal.cross(up).normalized()
	if tangent.length_squared()<.5:tangent=normal.cross(Vector3.RIGHT).normalized()
	var preferred_side:=0.0 if wound else (-.22 if label=="03_final_eyes_side_a" else .22)
	var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	var excluded:Array[RID]=[owner._token.body.get_rid()]
	excluded.append_array(physical._body.body_rids())
	var space:=scene.get_world_3d().direct_space_state
	for adjust:float in [0.0,.18,-.18,.35,-.35]:
		var direction:Vector3=(normal+tangent*(preferred_side+adjust)+up*.08).normalized()
		var position:Vector3=point+direction*(.65 if wound else .85)
		var floor:=space.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*2,position-Vector3.UP*4,1,excluded))
		if floor.is_empty() or floor.normal.y<.7:continue
		position.y=maxf(position.y,float(floor.position.y)+.18)
		var blocker:=space.intersect_ray(PhysicsRayQueryParameters3D.create(position,point,263,excluded))
		if not blocker.is_empty() and blocker.position.distance_to(point)>.035:continue
		# A clear world ray is insufficient: also reject a back-of-head or hair
		# view by tracing the actor's original rendered triangles from observer.
		var renderer:RefCounted=owner.marks.renderer
		renderer._query_cache.clear();renderer._query_bones=renderer._bone_poses()
		var ray:Vector3=(point-position).normalized()
		var query:Dictionary=renderer._query(position,-ray,position.distance_to(point)+.04)
		var outer:Dictionary=renderer._probe(query,position,-ray)
		renderer._query_cache.clear()
		if outer.is_empty():continue
		if not (renderer._surfaces[outer.s].skin_material or label=="01_clothing_wound"):continue
		if outer.world_point.distance_to(point)>(.045 if wound else .16):continue
		observer.global_position=position
		var viewing:Vector3=(point-position).normalized()
		observer.look_at(point,Vector3.FORWARD if absf(viewing.dot(Vector3.UP))>.95 else Vector3.UP);observer.make_current()
		observer_proof={"ok":true,"position":position,"target":point,"floor_y":floor.position.y,"camera_above_floor":position.y-floor.position.y,"world_line_clear":true,"frontmost_surface":str(renderer._surfaces[outer.s].node.get_ref().name),"frontmost_gap_m":outer.world_point.distance_to(point),"closed_eye_vertices":geometry.get("original_closed_vertices",0),"during_natural_fall":true}
		return

func fire_once(label:String)->void:
	if label!="TT_anatomical_head":await super.fire_once(label);return
	for i in 180:
		if float(weapons.fire_state.cooldown)<=0 and float(weapons.fire_state.reloadRemaining)<=0:break
		await sync()
	var sight:=real_sight();check(sight.ok,label+":actual_muzzle_reach_actor")
	if not sight.ok:return
	var ammo:int=weapons.fire_state.magazine;var emitted:int=weapons.shots_count;var before_impacts:=impacts.size()
	player._unhandled_input(mouse(true));await sync(2)
	player._unhandled_input(mouse(false))
	for i in 24:
		if impacts.size()>before_impacts and owner._row.get("dead",false):break
		await sync()
	check(weapons.shots_count==emitted+1,label+":one_actual_input_shot")
	check(weapons.fire_state.magazine==ammo-1,label+":one_inventory_round_spent")
	check(impacts.size()>before_impacts,label+":actual_native_impact")
	phase(label)

'''+s[end:]
s=s.replace('\tawait sync(90)\n\tawait capture("02_head_skin_wound")','\tawait capture("02_head_skin_wound")')
s=s.replace('if headless_qa:\n\t\tvar geometry', 'if headless_qa:\n\t\tplace_observer(label)\n\t\tcheck(observer_proof.get("ok",false),"clear_observer:"+label)\n\t\tvar geometry')
s=s.replace('"head_proof":owner.last_head_zone.duplicate(true)})','"head_proof":owner.last_head_zone.duplicate(true),"observer_visibility":observer_proof.duplicate(true)})')
s=s.replace('if done:return\n\tvar physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]\n\tvar geometry', 'if done:return\n\tcheck(observer_proof.get("ok",false),"clear_observer:"+label)\n\tvar physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]\n\tvar geometry')
s=s.replace('"observer_only":true,"original_materials_unchanged":true}', '"observer_only":true,"original_materials_unchanged":true,"observer_visibility":observer_proof.duplicate(true)}')
(OUT/'capture.gd').write_text(s,encoding='utf8')
(OUT/'HARNESS_PINS.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'capture.gd',OUT/'frozen_actual_input.gd']},indent=2),encoding='utf8')
print('Prepared observer-only new closure.')
