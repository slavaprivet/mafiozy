extends "observer_single30.gd"
## Real accepted inventory fire -> owned native projectile -> health receipt.
## Only the player is positioned as test setup; residents never relocate.
var checks30:Dictionary={}
var initial30:Dictionary={}
var deaths30:Dictionary={}
var births30:Array[Dictionary]=[]
var snapshots30:Array[Dictionary]=[]
var targets30:Array[String]=["resident_1","resident_2","resident_1","resident_2"]
var target_index30:=0
var manager30:Node
var blocker30:StaticBody3D
var blocker_cleared30:=false
var occupied_observed30:=false
var third_previous30:=Vector3.ZERO
var third_moved30:=0.0
var third_while_dead30:=0.0
var third_frames30:=0
var player_repositions30:=0
var generation_start30:Dictionary={}
var resumed_ms30:=0
var _target_dead30:=false
var final_counts30:Dictionary={}

func _bind(scene:Node3D)->bool:
	_pop=scene.get("preview_population")
	if _pop==null or not _pop.city_ready or _pop.daily==null:return false
	manager30=_pop.get("_multi_lifecycle30")
	if not is_instance_valid(manager30) or _pop.hit_owners.size()!=3 or _pop.daily._lives.size()!=3:_finish("three_real_residents_required");return false
	_player=scene.get("_player");_weapons=scene.get("preview_weapons");_camera=_player.get_preview_camera()
	_weapons.shot_emitted.connect(_shot);_weapons.effects.projectile_resolved.connect(_terminal);_player.set_mouse_captured(true)
	for id:String in ["resident_1","resident_2","resident_3"]:
		var life:RefCounted=_pop.daily._lives[id];var token:Dictionary=life._token
		initial30[id]={"body_id":token.body.get_instance_id(),"life_id":life.get_instance_id(),"generation":token.life_generation,"descriptor":token.descriptor_sha256,"bridge":token.bridge_id,"position":token.body.global_position,"hp":life._life().hp}
	third_previous30=_pop.daily._lives.resident_3._token.body.global_position
	checks30.initial_three_controllers=manager30._controllers.size()==3
	checks30.catalogue_preserved=_pop.residents._records.size()==287
	checks30.admitted_positions_preserved=true
	for id:String in initial30:
		var origin:Vector3=_pop.residents._records[id].origin;var position:Vector3=initial30[id].position
		if Vector2(origin.x-position.x,origin.z-position.z).length()>.2:checks30.admitted_positions_preserved=false
	_ready_ms=Time.get_ticks_msec();_deadline_ms=_ready_ms+150000;_phase="warm"
	# Looking high into the sky is input setup; it avoids holding the warm walkers.
	var motion:=InputEventMouseMotion.new();motion.relative=Vector2(600,-600);get_viewport().push_input(motion,true)
	return true

func place_player30(body:CharacterBody3D)->bool:
	var shape:CollisionShape3D
	for child:Node in _player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:shape=child;break
	if shape==null:return false
	var space:PhysicsDirectSpaceState3D=_player.get_world_3d().direct_space_state
	for radius:float in [4.0,5.5,7.0]:
		for index:int in 8:
			var angle:float=TAU*float(index)/8.0;var point:Vector3=body.global_position+Vector3(sin(angle)*radius,0,cos(angle)*radius)
			var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.7,point-Vector3.UP*.7,1);ray.exclude=[_player.get_rid(),body.get_rid()]
			var floor_hit:Dictionary=space.intersect_ray(ray)
			if floor_hit.is_empty() or (floor_hit.normal as Vector3).y<.7:continue
			point.y=float(floor_hit.position.y)+.01
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=Transform3D(Basis.IDENTITY,point)*shape.transform;query.collision_mask=_player.collision_mask;query.exclude=[_player.get_rid()];query.margin=.001
			if not space.intersect_shape(query,1).is_empty():continue
			var sight:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.5,body.global_position+Vector3.UP*1.4,1);sight.exclude=[_player.get_rid()]
			var hit:Dictionary=space.intersect_ray(sight)
			if hit.get("collider")!=body:continue
			_player.global_position=point;_player.velocity=Vector3.ZERO;player_repositions30+=1
			return true
	return false

func start_target30()->bool:
	var id:String=targets30[target_index30]
	if not _pop.daily._lives.has(id):return false
	_life=_pop.daily._lives[id];_health=_pop.daily._health[id];_body=_health._token.body;_lifecycle=manager30._controllers[id]
	if not place_player30(_body):_finish("player_native_setup_unavailable:"+id);return false
	var equipped:Dictionary=_weapons.equip("sniper")
	if not equipped.get("ok",false):_finish("sniper_equip_refused");return false
	if int(_weapons.fire_state.magazine)<=0:
		var key:=InputEventKey.new();key.physical_keycode=KEY_R;key.keycode=KEY_R;key.pressed=true;get_viewport().push_input(key,true)
		key=InputEventKey.new();key.physical_keycode=KEY_R;key.keycode=KEY_R;key.pressed=false;get_viewport().push_input(key,true)
	_old={"id":id,"generation":_health._token.life_generation,"body_id":_body.get_instance_id(),"health_id":_health.get_instance_id(),"life_id":_life.get_instance_id(),"account_id":_pop.daily._accounts[id].get_instance_id(),"owner_id":_pop.owners[id].get_instance_id(),"health":_health,"token":_health._token.duplicate(),"controller":_lifecycle}
	_button(MOUSE_BUTTON_RIGHT,true);_stable=0;_fired=0;_last_fire=-100000;_target_dead30=false;resumed_ms30=Time.get_ticks_msec();_phase="aim"
	return true

func occupy_spawn30()->void:
	var point:Vector3=manager30._controllers.resident_1._spawn
	blocker30=StaticBody3D.new();blocker30.name="QAOccupiedRespawn30";blocker30.collision_layer=1;blocker30.collision_mask=1
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,3,8);collision.shape=box;blocker30.add_child(collision)
	get_tree().current_scene.add_child(blocker30);blocker30.global_position=point+Vector3.UP*1.5

func inspect_death30()->void:
	var id:String=_old.id;var state:Dictionary=_lifecycle.snapshot();var event:String=str(_health.last_result.get("event_id",""))
	var before:int=int(state.death_count);var time_left:float=_lifecycle._timer.time_left
	checks30["duplicate_death_rejected_"+str(target_index30)]=not _lifecycle.confirmed_death(_health,event) and int(_lifecycle.snapshot().death_count)==before and _lifecycle._timer.time_left<=time_left
	checks30["retired_exact_daily_"+str(target_index30)]=not _pop.daily._lives.has(id) and not _pop.daily._accounts.has(id) and not _pop.daily._health.has(id) and not _pop.hit_owners.has(_health) and not _pop.daily._physical_lives30.has(id)
	var shot_id:String=str(_health.last_contact.get("shot_id",""))
	checks30["native_hit_chain_"+str(target_index30)]=not shot_id.is_empty() and _shots.any(func(s:Dictionary)->bool:return s.shot_id==shot_id) and _terminals.any(func(t:Dictionary)->bool:return t.shot_id==shot_id and t.status=="hit" and t.owned) and _health.last_result.get("reason") in ["final_death","bleedout"]
	var key:String=id+":"+str(_old.generation);deaths30[key]=_old.duplicate();deaths30[key].event=event;deaths30[key].health_steps=_health._step_calls28
	if target_index30==0:occupy_spawn30()
	_button(MOUSE_BUTTON_RIGHT,false);_target_dead30=true
	if target_index30==0:
		target_index30=1;start_target30()
	else:_phase="wait_births"

func inspect_births30()->void:
	for key:String in deaths30:
		var old:Dictionary=deaths30[key]
		checks30["dead_health_dispatch_stopped_"+key]=int(old.health._step_calls28)==int(old.health_steps)
		if old.get("verified",false):continue
		var controller:Node=old.controller;var state:Dictionary=controller.snapshot()
		if int(state.generation)<=int(old.generation) or state.phase!="alive" or int(state.respawn_count)<1:continue
		var birth:Dictionary=state.birth
		checks30["fresh_objects_"+key]=int(birth.generation)==int(old.generation)+1 and int(birth.body_id)!=int(old.body_id) and int(birth.health_id)!=int(old.health_id) and int(birth.life_id)!=int(old.life_id) and int(birth.account_id)!=int(old.account_id) and int(birth.queue_owner_id)!=int(old.owner_id)
		checks30["full_reset_"+key]=float(birth.hp)==float(birth.max_hp) and float(birth.energy)==100.0 and int(birth.cash)==1000 and birth.pending.is_empty() and not birth.search_pending and birth.continuation_empty
		var birth_position:Vector3=birth.position;var spawn_position:Vector3=controller._spawn
		checks30["validated_spawn_not_overwritten_"+key]=Vector2(birth_position.x-spawn_position.x,birth_position.z-spawn_position.z).length()<=2.01 and birth_position.distance_to(_player.global_position)>1.0
		var token:Dictionary=_pop.daily._health[old.id]._token
		checks30["same_source_appearance_"+key]=token.source_id==old.id and token.descriptor_sha256==initial30[old.id].descriptor and token.bridge_id==initial30[old.id].bridge
		checks30["stale_receipt_refused_"+key]=not controller.confirmed_death(old.health,old.event) and not _pop.residents.target_current(old.token) and not _pop.policy._owner_allowed(old.id,int(old.generation)) and _pop.policy._owner_allowed(old.id,int(birth.generation))
		checks30["old_health_disposed_"+key]=old.health._host==null
		births30.append({"id":old.id,"birth":birth.duplicate(true),"frame":state.respawn_frame});old.verified=true

func _physics_process(_delta:float)->void:
	var now:int=Time.get_ticks_msec()
	if _phase=="bootstrap":
		if now-_start_ms>90000:_finish("bootstrap_timeout");return
		_bind(get_tree().current_scene as Node3D);return
	if _phase=="finished":return
	if _fire_down:_button(MOUSE_BUTTON_LEFT,false);_fire_down=false
	if now>_deadline_ms:_finish("timeout:"+_phase);return
	for controller:Node in manager30._controllers.values():
		if controller._phase=="blocked":_finish("lifecycle_blocked:"+controller.source_id30+":"+controller._reason);return
	var third:RefCounted=_pop.daily._lives.get("resident_3")
	if third==null or third.get_instance_id()!=initial30.resident_3.life_id:_finish("living_neighbour_replaced");return
	var third_body:CharacterBody3D=third._token.body;var distance:float=Vector2(third_body.global_position.x-third_previous30.x,third_body.global_position.z-third_previous30.z).length();third_previous30=third_body.global_position;third_moved30+=distance;third_frames30+=1
	if absf(third_body.global_position.y)>20.0:_finish("living_neighbour_left_physical_ground");return
	if manager30.snapshot30().phases.get("corpse",0)>0 or manager30.snapshot30().phases.get("spawning",0)>0:third_while_dead30+=distance
	if _phase=="warm":
		if now-_ready_ms>9000:start_target30()
		return
	if _phase=="aim":
		if bool(_health._row.get("dead",false)):inspect_death30()
		else:
			_stable=_stable+1 if _aim() else 0
			if _stable>=5 and now-_last_fire>1600 and _fired<4:_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired+=1;_last_fire=now;_stable=0
			if now-resumed_ms30>25000:_finish("native_kill_timeout:"+str(_old.id));return
	var first:Node=manager30._controllers.resident_1
	if not blocker_cleared30 and first._phase=="spawning" and first._attempts>=2:
		occupied_observed30=true
		checks30.occupied_spawn_stays_cold=not is_instance_valid(_pop.residents._records.resident_1.body) and not _pop.daily._lives.has("resident_1") and not _pop.residents._ragdolls.has("resident_1") and first._reason.begins_with("spawn_wait:")
		blocker30.queue_free();blocker_cleared30=true
	inspect_births30()
	if _phase=="wait_births":
		var required:int=2 if target_index30==1 else target_index30+1
		if births30.size()>=required:
			if target_index30<3:target_index30+=1;start_target30()
			else:
				checks30.two_cycles_each=manager30._controllers.resident_1._death_count==2 and manager30._controllers.resident_2._death_count==2 and manager30._controllers.resident_1._respawn_count==2 and manager30._controllers.resident_2._respawn_count==2
				checks30.birth_admission_one_per_frame=true
				var frames:Dictionary={}
				for birth:Dictionary in births30:
					if frames.has(birth.frame):checks30.birth_admission_one_per_frame=false
					frames[birth.frame]=true
				checks30.third_identity_health_unchanged=third._token.body.get_instance_id()==initial30.resident_3.body_id and third._token.life_generation==initial30.resident_3.generation and third._life().hp==initial30.resident_3.hp
				checks30.third_continues_native_motion=third_while_dead30>.5 and third_moved30>2.0 and third_frames30>120
				var rag_modes:Dictionary={};var active_rags:=0
				for id:String in _pop.residents._ragdolls:
					var mode:String=str(_pop.residents._ragdolls[id].mode);rag_modes[id]=mode
					if mode in ["ACTIVE","RECOVERING","RECOVERY_HOLD"]:active_rags+=1
				final_counts30={"health":_pop.hit_owners.size(),"lives":_pop.daily._lives.size(),"accounts":_pop.daily._accounts.size(),"controllers":manager30._controllers.size(),"work_index":_pop.residents.active_records30().size(),"bodies":_active_ids().size(),"rag_modes":rag_modes}
				checks30.no_population_accumulation=_pop.hit_owners.size()==3 and _pop.daily._lives.size()==3 and _pop.daily._accounts.size()==3 and manager30._controllers.size()==3 and _pop.residents.active_records30().size()==3 and _active_ids().size()==3 and active_rags==0 and rag_modes.size()<=3
				checks30.occupied_spawn_retry_observed=occupied_observed30 and blocker_cleared30
				_finish("complete");return
	if now-_last_log>1000:
		_last_log=now;var row:Dictionary={"ms":now-_ready_ms,"phase":_phase,"target":target_index30,"manager":manager30.snapshot30(),"third_moved_m":third_moved30,"third_while_dead_m":third_while_dead30,"work_index":_pop.residents.active_index_state30(),"physical":_pop.daily.physical_dispatch_state30(),"health_count":_pop.hit_owners.size(),"bodies":_active_ids().size(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
		snapshots30.append(row);print("MULTILIFE30_SAMPLE ",JSON.stringify(row))

func _finish(reason:String)->void:
	if _phase=="finished":return
	_phase="finished";set_physics_process(false)
	if is_instance_valid(_weapons):_weapons.cancel_inputs()
	if is_instance_valid(blocker30):blocker30.queue_free()
	var passed:bool=reason=="complete" and not checks30.values().has(false)
	var report:Dictionary={"passed":passed,"reason":reason,"checks":checks30,"births":births30,"initial":initial30,"shots":_shots,"terminals":_terminals,"samples":snapshots30,"final_counts":final_counts30,"third_moved_m":third_moved30,"third_while_dead_m":third_while_dead30,"npc_relocations":0,"player_fixture_repositions":player_repositions30,"fixture_spawn_obstacle":true,"synthetic_hits":false,"synthetic_damage":false,"performance_accepted":false}
	if not _out.is_empty():
		var file:=FileAccess.open(_out.path_join("MULTILIFE30.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MULTILIFE30_FINISH ",JSON.stringify({"passed":passed,"reason":reason,"checks":checks30}));get_tree().quit(0 if passed else 1)
