extends "frozen_actual_input.gd"
## Root-only GPU QA observer. Normal population, collisions, materials and physics.
var pack_sha:=""
var started:=0
var aim_head:=false
var head_bias:=0.0
var observe_mode:=""
var picture_proofs:Array[Dictionary]=[]
var raw_hits:Array[Dictionary]=[]

func _initialize()->void:
	started=Time.get_ticks_msec();root.unfocusable=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-pack-sha="):pack_sha=arg.trim_prefix("--qa-pack-sha=")
	if not out.is_absolute_path() or pack_sha.length()!=64 or DisplayServer.get_name()=="headless":quit(2);return
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
func place_observer(label:String)->void:
	var point:Vector3;var normal:Vector3;var distance:=.65
	if label in ["01_clothing_wound","02_head_skin_wound"]:
		var geometry:=mark_geometry(label=="01_clothing_wound")
		if geometry.is_empty():return
		point=geometry.point;normal=geometry.normal
	else:
		var frame:=head_frame();point=frame*((owner._head_zone._head_min+owner._head_zone._head_max)*.5)
		normal=frame.basis.z.normalized()*(1.0 if label=="03_final_eyes_side_a" else -1.0);distance=.8
	observer.global_position=point+normal*distance+Vector3.UP*.10
	var viewing:Vector3=(point-observer.global_position).normalized()
	observer.look_at(point,Vector3.FORWARD if absf(viewing.dot(Vector3.UP))>.95 else Vector3.UP);observer.make_current()
func capture(label:String)->void:
	if done:return
	observe_mode=label;place_observer(label)
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	if done:return
	var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	var geometry:Dictionary=mark_geometry(label=="01_clothing_wound") if label in ["01_clothing_wound","02_head_skin_wound"] else {}
	if label in ["01_clothing_wound","02_head_skin_wound"]:check(not geometry.is_empty(),"real_bound_surface_mark:"+label)
	var im:=root.get_texture().get_image();var saved:=im.save_png(out.path_join(label+".png"))
	check(saved==OK,"capture:"+label)
	if saved==OK:images.append(label+".png")
	var row:Dictionary={"label":label,"actor":owner._token.source_id,"hp":owner._row.hp,"dead":owner._row.get("dead",false),"eyes_closed":physical._eyes.closed,"head_proof":owner.last_head_zone.duplicate(true),"contact":owner.last_contact.duplicate(true),"marks":owner.marks.renderer._marks.size(),"geometry":geometry,"camera":observer.global_transform,"camera_fov":observer.fov,"draws":draws,"observer_only":true,"original_materials_unchanged":true}
	picture_proofs.append(row);FileAccess.open(out.path_join(label+".json"),FileAccess.WRITE).store_string(JSON.stringify(row,"\t"));observe_mode=""
func finishing_sight()->bool:
	var camera:Camera3D=player.get_preview_camera();var muzzle:Dictionary=weapons.presentation.current_muzzle()
	if not muzzle.get("ok",false):return false
	var hit:Dictionary=weapons._projectile_ray({"origin":camera.global_position,"direction":-camera.global_basis.z,"range":100.0})
	if not own_collider(hit.get("collider")):return false
	var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	var excluded:Array[RID]=[owner._token.body.get_rid(),player.get_rid()];excluded.append_array(physical._body.body_rids())
	return not owner._head_zone.classify(muzzle.origin,(hit.point-muzzle.origin).normalized(),100,physical,scene,excluded).is_empty()
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
	check(scene.PREVIEW_RUNTIME_REVISION=="s01-20260930-quality23f","exact23f_runtime")
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
	aim_head=true;found=false
	for bias:float in [0.0,.03,.06,.10,.14,.18,.22,-.03,-.06]:
		head_bias=bias;aim();await sync(3)
		if real_sight().ok and finishing_sight():found=true;break
	check(found,"real_muzzle_ray_reaches_anatomical_head")
	if not found:finish();return
	await fire_once("TT_anatomical_head")
	check(owner._row.hp==0 and owner.last_head_zone.get("zone")=="head","actual_input_anatomical_final")
	await sync(90)
	await capture("02_head_skin_wound")
	await capture("03_final_eyes_side_a")
	await capture("04_final_eyes_side_b")
	finish()
func finish()->void:
	if done:return
	var report:Dictionary={"pack_sha256":pack_sha,"checks":checks,"errors":failures,"elapsed_ms":Time.get_ticks_msec()-started,"draws":draws,"images":images,"proofs":picture_proofs,"raw_native_impacts":raw_hits,"shots":shots,"scope":"actual equip/input/ammo/projectiles/HP, original normal moving population and collisions; detached QA aim and close observer; no materials/physics/body writes; RNG chosen noncritical for first shot; not normal camera or perf proof"}
	if not out.is_empty():FileAccess.open(out.path_join("VISUAL_RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	super.finish()
