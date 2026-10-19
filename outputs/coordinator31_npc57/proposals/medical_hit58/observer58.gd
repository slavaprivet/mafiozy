extends "observer_injury_base58.gd"
## Merged build only. Real purchased TT, viewport trigger, exact native hit and
## authoritative treatment receipt. No resident position/health/route writes.
const Physical58=preload("res://scripts/hospital/npc_physical_route51.gd")
var _purchase58:Dictionary={}
var _player_setup58:Dictionary={}
var _healing58:Dictionary={}
var _entered58:Dictionary={}
var _outside58:Dictionary={}
var _identity58:Dictionary={}
var _last_position58:=Vector3.ZERO
var _max_step58:=0.0
var _travel58:=0.0
var _low_attention58:=0
var _holstered58:=false
var _route_owner58:RefCounted
func _bind(scene:Node3D)->bool:
	_pop=scene.get("preview_population")
	if _pop==null or not _pop.city_ready or not _pop.city_stream_complete() or _pop.daily==null:return false
	if _pop.hit_owners.size()!=10 or _pop.daily._lives.size()!=10:_finish("ten_residents_required");return false
	_life=_pop.daily._lives.get("resident_1");_health=_pop.daily._health.get("resident_1")
	if _life==null or _health==null:_finish("target_missing");return false
	_body=_health._token.body;_player=scene.get("_player");_weapons=scene.get("preview_weapons")
	if not is_instance_valid(_body) or not is_instance_valid(_player) or not is_instance_valid(_weapons):_finish("bindings_missing");return false
	_checks["initial_native_60_of_60"]=float(_health._row.hp)==60.0 and float(_health._row.max_hp)==60.0
	var shop:Node=scene.get("player_shop")
	if not is_instance_valid(shop) or not shop.ready_for_use:_finish("player_shop_missing");return false
	var cash:int=shop.wallet.cash();var owned_before:Array=_weapons.inventory.get_owned_ids().duplicate()
	shop._open_goods();shop._goods.select("tt_pistol");shop._goods.activate_selected()
	_purchase58={"answer":shop._last_result.duplicate(true),"receipt":shop._last_receipt.duplicate(true),"cash_before":cash,"cash_after":shop.wallet.cash(),"owned_before":owned_before,"owned_after":_weapons.inventory.get_owned_ids().duplicate(),"fixture_control":"real modal goods activation with current cashier; physical player walk-in/E is outside this fixture"}
	_checks["tt_bought_once_through_real_transaction"]=not "tt_pistol" in owned_before and shop._last_result.get("ok",false) and shop.wallet.cash()==cash-shop.catalog.price("tt_pistol") and "tt_pistol" in _weapons.inventory.get_owned_ids()
	shop.close_all()
	if not _checks.initial_native_60_of_60 or not _checks.tt_bought_once_through_real_transaction:_finish("initial_health_or_purchase_failed");return false
	_camera=_player.get_preview_camera();_player.set_mouse_captured(true)
	if not _place_player58():_finish("supported_player_los_unavailable");return false
	_weapons.shot_emitted.connect(_shot);_weapons.effects.projectile_resolved.connect(_terminal)
	_button(MOUSE_BUTTON_RIGHT,false)
	if not _weapons.equip("tt_pistol").get("ok",false):_finish("tt_equip_refused");return false
	_identity58={"body_id":_body.get_instance_id(),"health_id":_health.get_instance_id(),"life_id":_life.get_instance_id(),"generation":_life._token.life_generation,"max_hp":_health._row.max_hp}
	_last_position58=_body.global_position;_completed_before=int(_life._completed.hospital)
	_ready_ms=Time.get_ticks_msec();_deadline_ms=_ready_ms+240000;_phase="aim_exact_tt_hit"
	return true
func _place_player58()->bool:
	var probe:=Physical58.new()
	if not probe.configure(_player):return false
	var before:Vector3=_player.global_position
	var forward:Vector3=-_body.global_basis.z;forward.y=0.0;forward=forward.normalized()
	for radius:float in [6.0,8.0,10.0]:
		for angle:float in [0.0,.3,-.3,.6,-.6,.9,-.9]:
			var at:Vector3=_body.global_position+forward.rotated(Vector3.UP,angle)*radius
			var floor:Variant=probe.floor_at(at,_body.global_position.y)
			if not floor is Vector3 or not probe.standing(floor):continue
			var ray:=PhysicsRayQueryParameters3D.create(floor+Vector3.UP*1.45,_body.global_position+Vector3.UP*1.05,0xffffffff,[_player.get_rid()])
			var hit:Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or not _health._owns_collider(hit.get("collider")):continue
			_player.set_preview_pose_authority(&"on_foot",true);_player.global_position=floor
			_player_setup58={"before":before,"after":floor,"native_floor_capsule_los":true,"resident_moved":false,"frame":Engine.get_physics_frames()};return true
	return false
func _physics_process(_delta:float)->void:
	var now:int=Time.get_ticks_msec();var frame:int=Engine.get_physics_frames()
	if _phase=="bootstrap":
		if now-_start_ms>90000:_finish("bootstrap_timeout");return
		_bind(get_tree().current_scene as Node3D);return
	if _phase=="finished":return
	if _fire_down:_button(MOUSE_BUTTON_LEFT,false);_fire_down=false
	if now>_deadline_ms:_finish("timeout:"+_phase);return
	if not _life._host.target_current(_life._token) or _body.get_instance_id()!=_identity58.body_id or _life._token.life_generation!=_identity58.generation:_finish("identity_changed");return
	var hp:float=float(_health._row.hp)
	if _health._row.get("dead",false) or _health._row.get("_medicalDowned",false) or hp<=0:_finish("nonfatal_case_became_fatal");return
	var step:float=_body.global_position.distance_to(_last_position58);_travel58+=step;_max_step58=maxf(_max_step58,step);_last_position58=_body.global_position
	var receipt:Dictionary=_health.last_result
	if int(receipt.get("revision",-1))>_last_revision:
		_last_revision=int(receipt.get("revision",-1))
		if receipt.get("applied",false) and not receipt.get("hit",{}).is_empty():_hit_receipts.append(receipt.duplicate(true))
		if receipt.get("applied",false) and receipt.has("hospital"):_healing58=receipt.duplicate(true)
	if _phase=="aim_exact_tt_hit":
		if hp<60.0:
			if hp!=30.0:_finish("wrong_native_boundary_hp:"+str(hp));return
			_low_hp=hp;_injury_ms=now;_injury_position=_body.global_position;_injury_frame=frame;_phase="medical_entry_treatment_exit"
			_weapons.cancel_inputs();_button(MOUSE_BUTTON_RIGHT,false)
			_holstered58=bool(_weapons.equip("none").get("ok",false))
		else:
			_stable=_stable+1 if _torso_aim() else 0
			if _fired==0 and _stable>=5:
				_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired=1;_last_fire=now
			if now-_ready_ms>25000:_finish("one_native_tt_hit_not_emitted");return
	if _phase=="medical_entry_treatment_exit":
		if hp==30.0 and _life._attention29.active:_low_attention58+=1
		if not _holstered58:_holstered58=bool(_weapons.equip("none").get("ok",false))
		# Gaze is read by the real attention owner; at 50% it must not pause care.
		_torso_aim()
		if _life._goal.get("kind","")=="hospital":_hospital_seen=true;_route_owner58=_life._dsh_simple
		if _life._hospital_stage=="TREATING":
			_treating_seen=true
			if _entered58.is_empty():_entered58={"ms":now,"position":_body.global_position,"inside":_life._hospital51_inside(),"route":_life._dsh_simple.snapshot()}
		if not _healing58.is_empty() and hp==60.0:_healed_seen=true
		if int(_life._completed.hospital)>_completed_before:
			_outside58={"ms":now,"position":_body.global_position,"outside":_route_owner58.is_outside() if _route_owner58!=null else false,"active_hospital":_life._dsh_simple_goal_active(),"completed":_life._completed.hospital}
			_complete58();return
	var budget:Dictionary=Budget30.diagnostics();_max_jobs=maxi(_max_jobs,int(budget.jobs));_max_nodes=maxi(_max_nodes,int(budget.nodes))
	if now-_last_log>=500:
		_last_log=now
		_rows.append({"frame":frame,"ms":now,"phase":_phase,"hp":hp,"life":_life._phase,"goal":_life._goal.get("kind",""),"hospital":_life._hospital_stage,"position":_body.global_position,"attention":_life._attention29.active,"health_pause":_health.should_pause_walk(),"threshold":_life._hospital51_below_threshold(_health._row),"route":_life._dsh_simple.snapshot() if _life._dsh_simple!=null else {},"budget":budget})
func _complete58()->void:
	var linked:bool=_hit_receipts.size()==1 and _shots.size()==1
	for hit:Dictionary in _hit_receipts:
		var matched:=false
		for terminal:Dictionary in _terminals:
			if terminal.weapon=="tt_pistol" and terminal.status=="hit" and terminal.owned and not str(terminal.shot_id).is_empty() and str(hit.get("event_id","")).ends_with(":"+str(terminal.shot_id)) and _shots.any(func(shot:Dictionary)->bool:return shot.shot_id==terminal.shot_id and shot.weapon=="tt_pistol"):matched=true
		linked=linked and matched
	_checks["one_authenticated_tt_hit_60_to_30"]=linked and _low_hp==30.0 and _fired==1
	_checks["hospital_need_at_exact_half"]= _hospital_seen and _low_hp==30.0
	_checks["medical_priority_not_attention_held"]=_low_attention58==0
	_checks["actual_physical_interior"]=_entered58.get("inside",false)
	_checks["actual_treatment_receipt"]=_treating_seen and _healed_seen and _healing58.get("hospital",{}).get("hp_before",-1)==30.0 and _healing58.hospital.hp_after==60.0 and _healing58.hospital.treatment_ms>=1500.0
	_checks["physical_exit_after_heal"]=_outside58.get("outside",false) and not _outside58.get("active_hospital",true)
	_checks["one_completed_hospital"]=_life._completed.hospital==_completed_before+1
	_checks["no_npc_teleport"]=_max_step58<=.25
	_checks["route_budget_bounded"]=_max_jobs<=2 and _max_nodes<=65536
	_checks["ten_residents_twelve_staff_preserved"]=_pop.daily._lives.size()==10 and get_tree().current_scene.preview_venue_staff29._rows.size()==12
	_finish("complete")
func _finish(reason:String)->void:
	if _phase=="finished":return
	_phase="finished";set_physics_process(false)
	if is_instance_valid(_weapons):_weapons.cancel_inputs()
	var result:Dictionary={"passed":reason=="complete" and not _checks.values().has(false),"reason":reason,"checks":_checks,"purchase":_purchase58,"player_setup":_player_setup58,"identity":_identity58,"hp_after_native_hit":_low_hp,"shots":_shots,"terminals":_terminals,"health_receipts":_hit_receipts,"entered":_entered58,"healing":_healing58,"outside":_outside58,"travel_m":_travel58,"max_native_step_m":_max_step58,"samples":_rows,"npc_relocated":false,"synthetic_damage":false,"source_row_written_by_fixture":false,"scope":"Merged build physical inclusive-half-health care; controlled player setup only, real shop transaction and viewport TT shot."}
	var file=FileAccess.open(_out.path_join("MEDICAL_HIT58.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("MEDICAL_HIT58 ",JSON.stringify({"passed":result.passed,"reason":reason,"checks":_checks}))
	get_tree().quit(0 if result.passed else 2)
