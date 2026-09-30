extends "frozen_actual_input.gd"
## Root-only GPU QA observer. Normal population, collisions, materials and physics.
var pack_sha:=""
var started:=0
var aim_head:=false
var head_bias:=0.0
var observe_mode:=""
var picture_proofs:Array[Dictionary]=[]
var raw_hits:Array[Dictionary]=[]
var head_local_target:=Vector3.ZERO
var head_target_selected:=false
var fixtures:Array[Dictionary]=[]
var headless_qa:=false
var extra_delay_frames:=0
var observer_proof:Dictionary={}
var eye_samples:Array[Dictionary]=[]

func _initialize()->void:
	started=Time.get_ticks_msec();root.unfocusable=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-pack-sha="):pack_sha=arg.trim_prefix("--qa-pack-sha=")
		if arg=="--qa-headless":headless_qa=true
		if arg.begins_with("--qa-delay-frames="):extra_delay_frames=int(arg.trim_prefix("--qa-delay-frames="))
	if not out.is_absolute_path() or pack_sha.length()!=64 or (DisplayServer.get_name()=="headless" and not headless_qa):quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()
func _process(dt:float)->bool:
	if not done and Time.get_ticks_msec()-started>23000:
		check(false,"23_second_wall_timeout");finish();return false
	var result:=super._process(dt)
	if not observe_mode.is_empty() and is_instance_valid(observer):place_observer(observe_mode)
	return result
func head_frame()->Transform3D:
	var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	if physical.mode=="ACTIVE":return physical._body.snapshot().bone_world_frames.head
	var rig:Skeleton3D=owner._token.rig
	return rig.global_transform*rig.get_bone_global_pose(rig.find_bone("head"))
func target_point()->Vector3:
	if aim_head:
		if head_target_selected:return head_frame()*head_local_target
		return head_frame()*((owner._head_zone._head_min+owner._head_zone._head_max)*.5)+Vector3.UP*head_bias
	return owner._token.body.global_position+Vector3.UP*1.1
func mark_geometry(clothing:bool)->Dictionary:
	if owner.marks==null or owner.marks.renderer==null:return {}
	var renderer:RefCounted=owner.marks.renderer
	for mark:Dictionary in renderer._marks:
		if mark.clothing!=clothing or mark.triangles.is_empty():continue
		var anchor:Dictionary=mark.triangles[0].anchors[0]
		var surface:Dictionary=renderer._surfaces[anchor.s]
		var matrices:Array[Transform3D]=renderer._matrices(surface)
		var a:Vector3=renderer._vertex(surface,anchor.ids[0],matrices)
		var b:Vector3=renderer._vertex(surface,anchor.ids[1],matrices)
		var c:Vector3=renderer._vertex(surface,anchor.ids[2],matrices)
		return {"event_id":mark.id,"clothing":clothing,"point":a*anchor.weights.x+b*anchor.weights.y+c*anchor.weights.z,"normal":(b-a).cross(c-a).normalized()*float(anchor.sign),"triangles":mark.triangles.size(),"surface":str(surface.node.get_ref().name),"original_material":true}
	return {}
func eyes_geometry()->Dictionary:
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

func capture(label:String)->void:
	if done:return
	if headless_qa:
		place_observer(label)
		check(observer_proof.get("ok",false),"clear_observer:"+label)
		var geometry:=mark_geometry(label=="01_clothing_wound")
		if label in ["01_clothing_wound","02_head_skin_wound"]:check(not geometry.is_empty(),"real_bound_surface_mark:"+label)
		var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
		picture_proofs.append({"label":label,"hp":owner._row.hp,"geometry":geometry,"eyes_closed":physical._eyes.closed,"head_proof":owner.last_head_zone.duplicate(true),"observer_visibility":observer_proof.duplicate(true)})
		return
	observe_mode=label;place_observer(label)
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	if done:return
	check(observer_proof.get("ok",false),"clear_observer:"+label)
	var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	var geometry:Dictionary=mark_geometry(label=="01_clothing_wound") if label in ["01_clothing_wound","02_head_skin_wound"] else {}
	if label in ["01_clothing_wound","02_head_skin_wound"]:check(not geometry.is_empty(),"real_bound_surface_mark:"+label)
	var im:=root.get_texture().get_image();var saved:=im.save_png(out.path_join(label+".png"))
	check(saved==OK,"capture:"+label)
	if saved==OK:images.append(label+".png")
	var row:Dictionary={"label":label,"actor":owner._token.source_id,"hp":owner._row.hp,"dead":owner._row.get("dead",false),"eyes_closed":physical._eyes.closed,"head_proof":owner.last_head_zone.duplicate(true),"contact":owner.last_contact.duplicate(true),"marks":owner.marks.renderer._marks.size(),"geometry":geometry,"camera":observer.global_transform,"camera_fov":observer.fov,"draws":draws,"observer_only":true,"original_materials_unchanged":true,"observer_visibility":observer_proof.duplicate(true)}
	picture_proofs.append(row);FileAccess.open(out.path_join(label+".json"),FileAccess.WRITE).store_string(JSON.stringify(row,"\t"));observe_mode=""
func aim()->void:
	if not is_instance_valid(player) or owner==null:return
	if not head_target_selected:super.aim();return
	var camera:Camera3D=player.get_preview_camera()
	camera.top_level=true
	camera.global_position=player.global_position+Vector3.UP*1.65
	camera.look_at(target_point(),Vector3.UP)

func original_face_candidates()->Array[Dictionary]:
	# QA read-only original rigid head triangles. No semantic height damage rule:
	# these positions merely propose views, native receipt still proves the hit.
	var zone:RefCounted=owner._head_zone
	var center:Vector3=(zone._head_min+zone._head_max)*.5
	var height:float=zone._head_max.y-zone._head_min.y
	var sectors:Dictionary={}
	var vertices:PackedVector3Array=zone._head_triangles
	for i in range(0,vertices.size(),3):
		var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
		var point:Vector3=(a+b+c)/3.0
		var fraction:float=(point.y-zone._head_min.y)/height
		if fraction<.24 or fraction>.64:continue
		var cross:Vector3=(b-a).cross(c-a)
		if cross.length_squared()<1e-12:continue
		var normal:=cross.normalized()
		if normal.dot(point-center)<0:normal=-normal
		if absf(normal.y)>.6:continue
		var sector:=posmod(roundi(atan2(normal.x,normal.z)/TAU*8.0),8)
		var band:=0 if fraction<.44 else 1
		var key:=Vector2i(sector,band)
		var score:=cross.length()/(.25+absf(fraction-.43))
		if not sectors.has(key) or score>float(sectors[key].score):sectors[key]={"local_point":point,"local_normal":normal,"score":score,"triangle":i/3,"fraction":fraction}
	var result:Array[Dictionary]=[]
	for row:Dictionary in sectors.values():result.append(row)
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.score>b.score)
	return result

func place_for_exposed_face()->bool:
	var candidates:=original_face_candidates()
	var capsule:CollisionShape3D=player.get_node("PlayerCapsule")
	var space:=scene.get_world_3d().direct_space_state
	for candidate:Dictionary in candidates:
		if done:return false
		var frame:=head_frame();var point:Vector3=frame*candidate.local_point
		var normal:Vector3=(frame.basis.inverse().transposed()*candidate.local_normal).normalized()
		var outward:=Vector3(normal.x,0,normal.z).normalized()
		var position:Vector3=point+outward*2.8
		var floor:=space.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*2,position-Vector3.UP*4,1,[player.get_rid()]))
		if floor.is_empty() or floor.normal.y<.8 or not floor.collider is StaticBody3D:continue
		position.y=floor.position.y+.004
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule.shape
		query.transform=Transform3D(capsule.global_basis,position+capsule.global_position-player.global_position)
		query.collision_mask=261;query.exclude=[player.get_rid()];query.margin=.001
		if not space.intersect_shape(query,1).is_empty():continue
		head_local_target=candidate.local_point;head_target_selected=true
		player.global_position=position;player.velocity=Vector3.ZERO;aim()
		await sync(8)
		var reachable:bool=player.is_on_floor() and real_sight().ok and finishing_sight()
		fixtures.append({"player_position":player.global_position,"floor":floor.position,"original_head_triangle":candidate.triangle,"local_target":head_local_target,"outward":outward,"reachable_exposed_skin":reachable,"normal_scheduled_physics":player.is_physics_processing(),"only_player_placed":true})
		if reachable:return true
	return false

func finishing_sight()->bool:
	var camera:Camera3D=player.get_preview_camera();var muzzle:Dictionary=weapons.presentation.current_muzzle()
	if not muzzle.get("ok",false):return false
	var hit:Dictionary=weapons._projectile_ray({"origin":camera.global_position,"direction":-camera.global_basis.z,"range":100.0})
	if not own_collider(hit.get("collider")):return false
	var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	var excluded:Array[RID]=[owner._token.body.get_rid(),player.get_rid()];excluded.append_array(physical._body.body_rids())
	var direction:Vector3=(hit.point-muzzle.origin).normalized()
	var anatomical:Dictionary=owner._head_zone.classify(muzzle.origin,direction,100,physical,scene,excluded)
	if anatomical.is_empty():return false
	# QA only: choose exposed original SKIN, not a target behind an outer hair cap.
	# The runtime continues selecting its genuine frontmost cosmetic surface.
	var renderer:RefCounted=owner.marks.renderer
	renderer._query_cache.clear();renderer._query_bones=renderer._bone_poses()
	var query:Dictionary=renderer._query(muzzle.origin,-direction,100.0)
	var outer:Dictionary=renderer._probe(query,muzzle.origin,-direction)
	var exposed:bool=not outer.is_empty() and renderer._surfaces[outer.s].skin_material and outer.world_point.distance_to(anatomical.point)<.01
	if exposed:
		query=renderer._query(outer.world_point,outer.world_normal)
		var local:Dictionary=renderer._probe(query,outer.world_point,outer.world_normal)
		exposed=not local.is_empty() and renderer._surfaces[local.s].skin_material
	renderer._query_cache.clear()
	return exposed
func run()->void:
	for path:String in ["res://scripts/main.gd","res://scripts/npc_visual/npc_local_preview_hit_owner.gd","res://scripts/npc_visual/npc_bullet_marks.gd","res://scripts/npc_visual/npc_head_zone.gd"]:
		var compiled:Script=load(path)
		check(compiled!=null and not compiled.has_source_code(),"compiled_runtime:"+path)
	if not failures.is_empty():finish();return
	RenderingServer.frame_post_draw.connect(func():draws+=1)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 240:
		await sync()
		if scene.preview_ready and scene.preview_population!=null and scene.preview_population.hit_owners.size()==3:break
	check(scene.preview_ready and scene.preview_population.hit_owners.size()==3,"normal_scene3NPC_ready")
	if not scene.preview_ready or scene.preview_population.hit_owners.size()!=3:finish();return
	check(scene.PREVIEW_RUNTIME_REVISION=="s01-20260930-quality23g","exact23g_runtime")
	player=scene._player;weapons=scene.preview_weapons;scripted_controls=true;controls();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	check(weapons.equip("tt_pistol").get("ok",false),"actual_inventory_TT")
	observer=Camera3D.new();scene.add_child(observer);observer.fov=42;observer.near=.03
	weapons.shot_emitted.connect(func(shot:Dictionary,muzzle:Dictionary,_o:Vector3,_d:Vector3):shots.append({"shot_id":shot.shotId,"muzzle":muzzle.duplicate(true),"ammo":weapons.fire_state.magazine}))
	weapons.effects.cosmetic_impact.connect(func(hit:Dictionary):
		raw_hits.append({"shot_id":hit.shotId,"point":hit.point,"normal":hit.normal,"direction":hit.direction,"collider":str(hit.collider.get_path()) if hit.collider is Node else str(hit.collider)})
		impacts.append(raw_hits[-1]))
	var found:=false
	for candidate:RefCounted in scene.preview_population.hit_owners:
		owner=candidate;tracking=true;aim_head=false;aim();await sync(8)
		if real_sight().ok:found=true;break
	check(found,"native_actual_muzzle_reachable")
	if not found:finish();return
	var sample:=RandomNumberGenerator.new()
	for value in 100:
		sample.seed=value
		if sample.randf()>=.12:owner._rng.seed=value;break # source RNG only; no HP/force writes
	await fire_once("TT_clothing")
	check(owner._row.hp>0 and not owner._row.get("dead",false),"first_TT_survives")
	await capture("01_clothing_wound")
	if owner._row.get("dead",false):finish();return
	aim_head=true
	await sync(extra_delay_frames)
	found=await place_for_exposed_face()
	check(found,"real_muzzle_ray_reaches_anatomical_head")
	if not found:finish();return
	await fire_once("TT_anatomical_head")
	check(owner._row.hp==0 and owner.last_head_zone.get("zone")=="head","actual_input_anatomical_final")
	await capture("02_head_skin_wound")
	await capture("03_final_eyes_side_a")
	await capture("04_final_eyes_side_b")
	finish()
func finish()->void:
	if done:return
	var report:Dictionary={"pack_sha256":pack_sha,"checks":checks,"errors":failures,"elapsed_ms":Time.get_ticks_msec()-started,"draws":draws,"images":images,"proofs":picture_proofs,"raw_native_impacts":raw_hits,"shots":shots,"fixtures":fixtures,"scope":"actual equip/input/ammo/projectiles/HP, original normal moving population and collisions; detached QA aim and close observer; no materials/physics/body writes; RNG chosen noncritical for first shot; not normal camera or perf proof"}
	if not out.is_empty():FileAccess.open(out.path_join("VISUAL_RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	super.finish()
