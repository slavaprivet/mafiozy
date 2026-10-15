extends Node
const Physical=preload("res://scripts/hospital/npc_physical_route51.gd")
var out:=""
var started:=0
var stage:="bootstrap"
var at:=0
var population: RefCounted
var life: RefCounted
var body: CharacterBody3D
var player: CharacterBody3D
var weapons: Node
var record: Dictionary={}
var checks: Dictionary={}
var samples: Array=[]
var setup: Dictionary={}
var max_visual_turn:=0.0
var initial_visual:=Vector3.ZERO
var alert_frames:=0
var photographs: Array=[]
var photo_pending:=false
var recovery_origin:=Vector3.ZERO
var recovery_at:=0
var recover_seen:=false
var phone_photo:=false
var last_diagnostic:=0
func _ready() -> void:
	started=Time.get_ticks_msec();process_physics_priority=1000
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
func _finish(reason: String) -> void:
	set_physics_process(false)
	var passed:=reason=="complete" and not checks.values().has(false)
	var value: Dictionary={"passed":passed,"reason":reason,"checks":checks,"samples":samples,"setup":setup,"photographs":photographs,"max_visible_turn_radians":max_visual_turn,"npc_position_written":false,"hp_written":false,"threat_events_injected":false,"source_catalogue_preserved":true,"performance_accepted":false}
	var file:=FileAccess.open(out.path_join("VISUAL31.json"),FileAccess.WRITE);file.store_string(JSON.stringify(value,"\t"));file.close();print("VISUAL31 ",JSON.stringify(value));get_tree().quit(0 if passed else 1)
func _photo(name: String) -> void:
	if photo_pending or DisplayServer.get_name()=="headless":return
	photo_pending=true
	var previous: Camera3D=get_viewport().get_camera_3d()
	var view:=Camera3D.new();get_tree().current_scene.add_child(view)
	var toward: Vector3=(player.global_position-body.global_position).slide(Vector3.UP).normalized()
	var side: Vector3=toward.cross(Vector3.UP).normalized()
	view.global_position=body.global_position+toward*4.0+side*3.0+Vector3.UP*1.9
	view.look_at(body.global_position+Vector3.UP*.95,Vector3.UP);view.make_current()
	await RenderingServer.frame_post_draw
	var path: String=out.path_join(name+".png")
	var error: Error=get_viewport().get_texture().get_image().save_png(path)
	photographs.append({"file":name+".png","frame":Engine.get_physics_frames(),"ok":error==OK,"npc":body.global_position,"player":player.global_position,"phase":life._threat30._phase if life._threat30!=null else "IDLE"})
	if is_instance_valid(previous):previous.make_current()
	view.queue_free();photo_pending=false
func _bind() -> bool:
	var scene: Node3D=get_tree().current_scene
	population=scene.get("preview_population")
	if population==null or not population.city_ready or not population.city_stream_complete() or population.daily==null:return false
	player=scene.get("_player");weapons=scene.get("preview_weapons")
	if player==null or weapons==null:return false
	for id: String in population.daily._lives:
		var candidate: RefCounted=population.daily._lives[id]
		if not candidate._roam51_active or candidate._health.should_pause_walk():continue
		var target: CharacterBody3D=candidate._token.body
		if not target.is_on_floor():continue
		# Route ownership may precede its first native step. Wait for actual travel
		# so spawn yaw cannot place the QA player behind the next walking heading.
		if Vector2(target.velocity.x,target.velocity.z).length()<1.0:continue
		var probe=Physical.new()
		if not probe.configure(player):continue
		var forward: Vector3=-target.global_basis.z;forward.y=0;forward=forward.normalized()
		for angle: float in [.80,-.80,.65,-.65]:
			var point: Vector3=target.global_position+forward.rotated(Vector3.UP,angle)*3.5
			var floor: Variant=probe.floor_at(point,target.global_position.y)
			if not floor is Vector3 or not probe.standing(floor):continue
			var ray:=PhysicsRayQueryParameters3D.create(floor+Vector3.UP*1.35,target.global_position+Vector3.UP*1.05,0xffffffff,[player.get_rid()])
			var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or not candidate._health._owns_collider(hit.get("collider")):continue
			life=candidate;body=target;record=population.residents._records[id]
			setup={"id":id,"player_from":player.global_position,"player_to":floor,"initial_resident":body.global_position,"initial_goal":life._goal.duplicate(),"initial_body_yaw":body.rotation.y,"initial_motion_yaw":record.motion.global_rotation.y,"native_floor_capsule_los":true}
			player.set_preview_pose_authority(&"on_foot",true);player.global_position=floor
			player.set_mouse_captured(true);weapons.equip("none")
			checks.original_ten=population.daily._lives.size()==10
			initial_visual=record.motion.global_basis.z.normalized();at=Time.get_ticks_msec();stage="neutral"
			return true
	return false
func _physics_process(_delta: float) -> void:
	var now: int=Time.get_ticks_msec()
	if now-started>110000:_finish("startup_or_observation_timeout");return
	if stage=="bootstrap":_bind();return
	if stage=="neutral":
		if photographs.is_empty() and not photo_pending:_photo.call_deferred("01_neutral")
		if (not photographs.is_empty() or DisplayServer.get_name()=="headless") and not photo_pending:
			player.set_mouse_captured(true);setup.equip_result=weapons.equip("golden_colt");checks.weapon_equipped=weapons.armed() and weapons.fire_state.get("weaponId")=="golden_colt";stage="observe";at=now
		return
	if stage=="finished_photos":
		if not photo_pending:_finish("complete")
		return
	var threat: RefCounted=life._threat30
	if now-last_diagnostic>=500:
		last_diagnostic=now
		var observation: Dictionary=life._health.incident_witness_snapshot()
		var world: RefCounted=get_tree().current_scene.get_meta("npc_threat_world30",null)
		samples.append({"stage":stage,"ms":now,"phase":threat._phase if threat!=null else "null","player":player.global_position,"npc":body.global_position,"forward":-body.global_basis.z,"witness_eligible":observation.get("eligible",false),"in_fov":world.in_fov(observation,player.global_position) if world!=null and not observation.is_empty() else false,"world":world.snapshot() if world!=null else {},"weapon":weapons.fire_state.get("weaponId"),"owner_current":weapons._owner_current(),"pose_authority":str(player._pose_authority),"visual_visible":weapons.presentation._visual.is_visible_in_tree() if is_instance_valid(weapons.presentation._visual) else false,"free_mouse":player._free_mouse_look,"attention":life._attention29.active,"life":life._phase})
	if threat==null or not threat.active():
		if now-at>15000:_finish("native_visible_weapon_not_observed")
		return
	if stage=="recover_wait":
		if threat._phase=="PHONE" and not phone_photo and not photo_pending:
			phone_photo=true;_photo.call_deferred("03_phone")
		if threat._phase=="RECOVER" and not recover_seen:
			recover_seen=true;recovery_origin=body.global_position;recovery_at=now
		if recover_seen and threat._phase=="RECOVER" and now-recovery_at>650 and not photo_pending and not photographs.any(func(p: Dictionary)->bool:return p.file=="04_recover_facing.png"):_photo.call_deferred("04_recover_facing")
		if recover_seen and threat._phase=="FLEE" and body.global_position.distance_to(recovery_origin)>.20:
			checks.native_recover_returned_to_motion=true;checks.recover_retry_within5s=now-recovery_at<5000
			if not photo_pending:_photo.call_deferred("05_recover_return");stage="finished_photos"
		elif now-at>25000:_finish("native_recover_retry_not_observed")
		return
	if threat._phase=="ALERT":
		alert_frames+=1
		var toward: Vector3=Vector3(threat._event.escape_from)-body.global_position;toward.y=0;toward=toward.normalized()
		var visible: Vector3=record.motion.global_basis.z;visible.y=0;visible=visible.normalized()
		var skeleton: Vector3=record.gait._skeleton.global_basis.z;skeleton.y=0;skeleton=skeleton.normalized()
		var physical: Vector3=-body.global_basis.z;physical.y=0;physical=physical.normalized()
		max_visual_turn=maxf(max_visual_turn,initial_visual.angle_to(visible))
		samples.append({"frame":Engine.get_physics_frames(),"phase":threat._phase,"age":threat._age,"body_error":physical.angle_to(toward),"visual_error":visible.angle_to(toward),"skeleton_error":skeleton.angle_to(toward),"position":body.global_position,"health":life._health._row.hp})
		if threat._age>.65:
			checks.actual_visible_weapon=threat._event.kind=="visible_weapon" and threat._event.weapon_id=="golden_colt"
			checks.body_faces_known_threat=physical.angle_to(toward)<.08
			checks.presentation_faces_known_threat=visible.angle_to(toward)<.12
			checks.skeleton_faces_known_threat=skeleton.angle_to(toward)<.12
			checks.actual_visible_turn=max_visual_turn>.30
			checks.health_untouched=life._health._row.hp==60.0
			checks.no_attention_movement_hold=not life._attention29.active
			stage="recover_wait";at=now;_photo.call_deferred("02_alert_facing")
	elif alert_frames>0:_finish("alert_ended_before_visual_acceptance")
	elif now-at>15000:_finish("alert_not_reached")
