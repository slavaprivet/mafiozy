extends Node
## Real viewport aim/fire -> accepted inventory shot -> native projectile hit ->
## exact health receipt. No synthetic hit dictionary, HP write or NPC relocation.
var _start_ms := 0
var _ready_ms := 0
var _deadline_ms := 0
var _out := ""
var _phase := "bootstrap"
var _failures: Array[String]=[]
var _rows: Array[Dictionary]=[]
var _shots: Array[Dictionary]=[]
var _terminals: Array[Dictionary]=[]
var _old: Dictionary={}
var _routes: Array[RefCounted]=[]
var _dead_baseline: Dictionary={}
var _last_log := 0
var _last_fire := -100000
var _fire_down := false
var _fired := 0
var _stable := 0
var _dead_frames := 0
var _pop: RefCounted
var _life: RefCounted
var _health: RefCounted
var _lifecycle: Node
var _body: CharacterBody3D
var _player: CharacterBody3D
var _weapons: Node
var _camera: Camera3D

func _ready() -> void:
	process_physics_priority=1000
	_start_ms=Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):_out=arg.trim_prefix("--qa-out=")
	if _out.is_empty():_finish("qa_output_required")

func _has_property(object: Object, key: String) -> bool:
	if not is_instance_valid(object):return false
	for item: Dictionary in object.get_property_list():
		if item.name==key:return true
	return false

func _capture_routes(object: RefCounted, depth: int=0, seen: Dictionary={}) -> void:
	if object==null or depth>3 or seen.has(object.get_instance_id()):return
	seen[object.get_instance_id()]=true
	if _has_property(object,"queries"):_routes.append(object)
	for key: String in ["_dsh_simple","_roam51","_restaurant28","_economy28","_ambient28","_ambient29","_driver","_drive","_route","_walk","_detour"]:
		if _has_property(object,key):
			var child: Variant=object.get(key)
			if child is RefCounted:_capture_routes(child,depth+1,seen)

func _route_counts() -> Array:
	var counts: Array=[]
	for route: RefCounted in _routes:counts.append({"object":route.get_instance_id(),"queries":route.get("queries"),"expanded":route.get("expanded") if _has_property(route,"expanded") else 0})
	return counts

func _native_queries() -> int:
	var backend: Variant=_pop.navigation.get("_backend")
	return int(backend.get("_stats").get("queries",0)) if backend!=null else -1

func _active_ids() -> Array:
	var ids: Array=[]
	for id: String in _pop.residents._records:
		if is_instance_valid(_pop.residents._records[id].body):ids.append(id)
	return ids

func _button(button: MouseButton, pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=button;event.pressed=pressed
	event.position=get_viewport().get_visible_rect().size*.5;event.global_position=event.position
	get_viewport().push_input(event,true)

func _shot(shot: Dictionary, muzzle: Dictionary, _origin: Vector3, _direction: Vector3) -> void:
	_shots.append({"shot_id":str(shot.get("shotId",str(shot.get("weaponId"))+":"+str(shot.get("sequence")))),"weapon":shot.get("weaponId"),"frame":Engine.get_physics_frames(),"muzzle":muzzle.get("origin")})

func _terminal(receipt: Dictionary) -> void:
	var collider: Variant=receipt.get("collider")
	_terminals.append({"shot_id":str(receipt.get("shotId","")),"status":receipt.get("status"),"weapon":receipt.get("weaponId"),"frame":Engine.get_physics_frames(),"owned":is_instance_valid(_health) and _health.get("_host")!=null and _health._owns_collider(collider),"collider_id":collider.get_instance_id() if is_instance_valid(collider) else 0,"point":receipt.get("point")})

func _bind(scene: Node3D) -> bool:
	_pop=scene.get("preview_population")
	if _pop==null or not _pop.get("city_ready") or _pop.get("daily")==null:return false
	_lifecycle=_pop.get("_single_lifecycle28")
	if not is_instance_valid(_lifecycle):_finish("production_lifecycle_missing");return false
	if _pop.hit_owners.size()!=1:_finish("one_resident_contract");return false
	var staff: Node=scene.get("preview_venue_staff29")
	var sites: Node=scene.get("preview_service_sites29")
	if not is_instance_valid(staff) or staff._rows.size()!=12 or not is_instance_valid(sites) or sites.current_sites().size()!=8:_finish("final_staff_sites_missing");return false
	_life=_pop.daily._lives.get("resident_1");_health=_pop.hit_owners[0]
	if _life==null or _health.get("_token").get("source_id")!="resident_1":_finish("wrong_resident");return false
	_body=_health.get("_token").body;_player=scene.get("_player");_weapons=scene.get("preview_weapons")
	if not is_instance_valid(_player) or not is_instance_valid(_weapons):_finish("player_weapon_owner_missing");return false
	_camera=_player.get_preview_camera()
	_old={"generation":int(_health.get("_token").life_generation),"body_id":_body.get_instance_id(),"health_id":_health.get_instance_id(),"life_id":_life.get_instance_id(),"account_id":_pop.daily._accounts["resident_1"].get_instance_id(),"position":_body.global_position,"initial_hp":_health.get("_row").hp,"initial_energy":_life.get("_energy")}
	_old["queue_owner_id"]=_pop.owners["resident_1"].get_instance_id()
	_weapons.shot_emitted.connect(_shot)
	_weapons.effects.projectile_resolved.connect(_terminal)
	_player.set_mouse_captured(true)
	var equipped: Dictionary=_weapons.equip("sniper")
	if not equipped.get("ok",false):_finish("native_sniper_equip_refused");return false
	if int(_weapons.fire_state.magazine)<=0:
		var key:=InputEventKey.new();key.physical_keycode=KEY_R;key.keycode=KEY_R;key.pressed=true
		get_viewport().push_input(key,true)
		key=InputEventKey.new();key.physical_keycode=KEY_R;key.keycode=KEY_R;key.pressed=false
		get_viewport().push_input(key,true)
	_button(MOUSE_BUTTON_RIGHT,true)
	_ready_ms=Time.get_ticks_msec();_deadline_ms=_ready_ms+45000;_phase="aim_and_fire"
	return true

func _aim() -> bool:
	var rig: Skeleton3D=_health.get("_token").rig
	var head: int=rig.find_bone("head")
	if head<0:return false
	var target: Vector3=rig.global_transform*(rig.get_bone_global_pose(head).origin+Vector3(0,.18,0))
	var direction: Vector3=(target-_camera.global_position).normalized()
	var yaw: float=atan2(-direction.x,-direction.z)
	var pitch: float=asin(clampf(direction.y,-.98,.98))
	var motion:=InputEventMouseMotion.new()
	motion.position=get_viewport().get_visible_rect().size*.5;motion.global_position=motion.position
	motion.button_mask=Input.get_mouse_button_mask()
	motion.relative=Vector2(-clampf(wrapf(yaw-_player._camera_yaw,-PI,PI)*.35,-.045,.045)/_player.mouse_sensitivity,-clampf((pitch-_player._camera_pitch)*.35,-.045,.045)/_player.mouse_sensitivity)
	get_viewport().push_input(motion,true)
	var camera_hit: Dictionary=_weapons._projectile_ray({"origin":_camera.global_position,"direction":-_camera.global_basis.z,"range":100.0})
	var muzzle: Dictionary=_weapons.presentation.current_muzzle()
	if not muzzle.get("ok",false) or not camera_hit.has("point") or not _health._owns_collider(camera_hit.get("collider")):return false
	var along: Vector3=(camera_hit.point-muzzle.origin).normalized()
	var muzzle_hit: Dictionary=_weapons._projectile_ray({"origin":muzzle.origin,"direction":along,"range":muzzle.origin.distance_to(camera_hit.point)+.03})
	return _health._owns_collider(muzzle_hit.get("collider")) and (-_camera.global_basis.z).angle_to(direction)<.006 and float(_weapons.fire_state.cooldown)<=0 and float(_weapons.fire_state.reloadRemaining)<=0 and int(_weapons.fire_state.magazine)>0

func _physics_process(_delta: float) -> void:
	var now: int=Time.get_ticks_msec()
	if _phase=="bootstrap":
		if now-_start_ms>90000:_finish("bootstrap_timeout");return
		_bind(get_tree().current_scene as Node3D)
		return
	if _phase=="finished":return
	if _fire_down:_button(MOUSE_BUTTON_LEFT,false);_fire_down=false
	var state: Dictionary=_lifecycle.snapshot()
	if state.phase=="blocked":_finish("lifecycle_blocked:"+str(state.reason));return
	var active_ids: Array=_active_ids()
	if active_ids.size()>1 or (not active_ids.is_empty() and active_ids[0]!="resident_1"):_finish("disabled_population_activated");return
	if _phase=="aim_and_fire":
		if bool(_health.get("_row").get("dead",false)):
			_capture_routes(_life)
			# _end_life may already have released them, so routes are also captured
			# before every trigger below, while no death has happened yet.
			_dead_baseline={"daily":_pop.daily.get("_step_calls28"),"health":_health.get("_step_calls28"),"routes":_route_counts(),"navigation":_pop.navigation.get("_stats").get("steps",0),"native_queries":_native_queries()}
			_old["death_receipt"]=_health.get("last_result").duplicate(true)
			_old["last_contact"]=_health.get("last_contact").duplicate(true)
			_phase="dead_wait";_button(MOUSE_BUTTON_RIGHT,false)
		elif now>_deadline_ms or (_fired>=4 and now-_last_fire>3000):_finish("native_kill_not_completed");return
		else:
			_stable=_stable+1 if _aim() else 0
			if _fired<4 and _stable>=5 and now-_last_fire>1600:
				if _routes.is_empty():_capture_routes(_life)
				_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired+=1;_last_fire=now;_stable=0
	if _phase=="dead_wait":
		if state.phase in ["corpse","spawning"]:
			_dead_frames+=1
			var registry: RefCounted=get_tree().current_scene.get_meta("npc_venue_registry29",null)
			if registry==null:_finish("venue_registry_missing");return
			if registry._actors.size()!=0 or registry.ledger.requests.size()!=0 or registry._service29.keys.size()!=0:_finish("dead_service_claim_retained");return
			if not _pop.daily._lives.is_empty() or not _pop.daily._accounts.is_empty() or not _pop.daily._health.is_empty():_failures.append("dead_daily_owner_retained");_finish("dead_activity_detected");return
			if _pop.hit_owners.size()!=0 or _pop.daily.get("_step_calls28")!=_dead_baseline.daily or _health.get("_step_calls28")!=_dead_baseline.health or _route_counts()!=_dead_baseline.routes or _pop.navigation.get("_stats").get("steps",0)!=_dead_baseline.navigation or _native_queries()!=_dead_baseline.native_queries:_finish("dead_dispatch_or_route_work");return
		elif int(state.respawn_count)>0:
			var birth: Dictionary=state.birth
			if int(state.death_count)!=1 or int(state.respawn_count)!=1:_failures.append("death_event_not_deduplicated")
			if _dead_frames<10:_failures.append("insufficient_dead_observation")
			if int(birth.generation)!=int(_old.generation)+1 or int(birth.body_id)==int(_old.body_id) or int(birth.health_id)==int(_old.health_id) or int(birth.life_id)==int(_old.life_id) or int(birth.account_id)==int(_old.account_id):_failures.append("new_life_identity_failed")
			if float(birth.hp)!=float(birth.max_hp) or float(birth.energy)!=100 or int(birth.cash)!=1000 or not birth.pending.is_empty():_failures.append("respawn_reset_failed")
			if int(birth.queue_owner_id)==int(_old.queue_owner_id) or birth.search_pending or not birth.continuation_empty:_failures.append("fresh_queue_failed")
			if _pop.hit_owners.size()!=1 or _pop.daily._lives.size()!=1:_failures.append("respawn_population_failed")
			var shot_id: String=str(_old.last_contact.get("shot_id",""))
			if shot_id.is_empty() or not _shots.any(func(s:Dictionary)->bool:return s.shot_id==shot_id) or not _terminals.any(func(t:Dictionary)->bool:return t.shot_id==shot_id and t.status=="hit" and t.owned):_failures.append("authenticated_native_hit_chain_missing")
			_finish("complete");return
		if now-_ready_ms>65000:_finish("respawn_timeout");return
	if now-_last_log>=1000:
		_last_log=now
		var row: Dictionary={"frame":Engine.get_physics_frames(),"ms":now,"qa_phase":_phase,"lifecycle":state,"daily_calls":_pop.daily.get("_step_calls28"),"health_calls":_health.get("_step_calls28"),"route_counts":_route_counts(),"active_health":_pop.hit_owners.size(),"lives":_pop.daily._lives.size(),"shots":_shots.size(),"terminals":_terminals.size()}
		_rows.append(row);print("QA_DEATH28 ",JSON.stringify(row))

func _finish(reason: String) -> void:
	if _phase=="finished":return
	_phase="finished";set_physics_process(false)
	if is_instance_valid(_weapons):_weapons.cancel_inputs()
	if reason!="complete":_failures.append(reason)
	var result: Dictionary={"reason":reason,"passed":_failures.is_empty(),"failures":_failures,"shots":_shots,"terminals":_terminals,"old_life":_old,"dead_baseline":_dead_baseline,"dead_frames":_dead_frames,"samples":_rows,"final":_lifecycle.snapshot() if is_instance_valid(_lifecycle) else {},"synthetic_damage":false,"npc_relocated":false}
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
		var file:=FileAccess.open(_out.path_join("DEATH28.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("QA_DEATH28_FINISH ",JSON.stringify({"reason":reason,"passed":_failures.is_empty(),"failures":_failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)
