extends "../injury30/observer_death28.gd"
## QA selects one production purchase agenda once. Every route, service claim,
## payment and exit afterwards belongs to production. No NPC position/HP writes.
const Registry30=preload("res://scripts/venues/npc_venue_registry29.gd")
var kind30:="shop"
var world30:RefCounted
var registry30:RefCounted
var economy30:RefCounted
var interrupted_route30:RefCounted
var checks30:Dictionary={}
var setup30:Dictionary={}
var service30:Dictionary={}
var interruption30:Dictionary={}
var payment30:Dictionary={}
var route_key30:=""
var venue30:=""
var phase_at30:=0
var quiet30:=0.0
var flee_origin30:=Vector3.ZERO
var flee_distance30:=0.0
var max_speed30:=0.0
var previous30:=Vector3.ZERO
var max_step30:=0.0
var total_m30:=0.0
var previous_service30:=false
var last_receipts30:=0
var cash30:=0
var price30:=0
var walks30:=0
var player_repositions30:=0
var release_seen30:=false
var flee_seen30:=false
var quiet_seen30:=false
var threat_was_inside30:=false
var violations30:Array[String]=[]
var shot_direction30:=Vector3.ZERO

func _bind(scene:Node3D)->bool:
	_pop=scene.get("preview_population")
	if _pop==null or not _pop.city_ready or _pop.daily==null:return false
	if _pop.hit_owners.size()!=1:_finish("single_resident_required");return false
	_life=_pop.daily._lives.get("resident_1");_health=_pop.daily._health.get("resident_1")
	if _life==null or _health==null:_finish("resident_missing");return false
	_body=_life._token.body;_player=scene.get("_player");_weapons=scene.get("preview_weapons");_camera=_player.get_preview_camera()
	world30=scene.get_meta("npc_threat_world30") if scene.has_meta("npc_threat_world30") else null
	if world30==null:_finish("threat_world_missing");return false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-service-kind="):kind30=arg.trim_prefix("--qa-service-kind=")
	if kind30 not in ["shop","restaurant"]:_finish("unsupported_case");return false
	_weapons.shot_emitted.connect(_shot);_weapons.effects.projectile_resolved.connect(_terminal);_player.set_mouse_captured(true);_weapons.equip("none")
	registry30=Registry30.for_scene(scene)
	if not _life._economy28_prepare():_finish("economy_setup_refused");return false
	economy30=_life._economy28
	if economy30.active():_finish("initial_economy_already_active");return false
	# The only agenda setup: request a normal production purchase, do not grant a
	# venue, arrival, money receipt or service permission. Prices use production RNG.
	economy30._choose_purchase(kind30,true)
	price30=economy30.required_cash();cash30=int(_life._account.snapshot().account.cash)
	setup30={"api":"economy._choose_purchase(kind,true); life._economy28_try_begin(row)","kind":kind30,"price":price30,"cash":cash30,"body_id":_body.get_instance_id(),"generation":_life._token.life_generation,"position":_body.global_position,"hp":_health._row.hp}
	if not _life._economy28_try_begin(_life._life()) or not economy30.active():_finish("production_agenda_begin_refused");return false
	checks30.initial_full_health=float(_health._row.hp)==float(_health._row.max_hp)
	checks30.initial_affordable_purchase=cash30>=price30 and price30>=5 and price30<=50
	previous30=_body.global_position;_ready_ms=Time.get_ticks_msec();_deadline_ms=_ready_ms+210000;_phase="approach";phase_at30=_ready_ms
	_look30(Vector3(0,.7,-1).normalized())
	return true

func _look30(direction:Vector3)->bool:
	var yaw:float=atan2(-direction.x,-direction.z);var pitch:float=asin(clampf(direction.y,-.8,.8))
	var motion:=InputEventMouseMotion.new();motion.position=get_viewport().get_visible_rect().size*.5;motion.global_position=motion.position
	motion.relative=Vector2(-wrapf(yaw-_player._camera_yaw,-PI,PI)*.35/_player.mouse_sensitivity,-(pitch-_player._camera_pitch)*.35/_player.mouse_sensitivity)
	get_viewport().push_input(motion,true)
	return (-_camera.global_basis.z).angle_to(direction)<.009

func _place_player_outside30(route:RefCounted)->bool:
	var shape:CollisionShape3D
	for child:Node in _player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:shape=child;break
	if shape==null:return false
	var space:PhysicsDirectSpaceState3D=_player.get_world_3d().direct_space_state
	var outward:Vector3=-route._inward;outward.y=0;outward=outward.normalized()
	var lateral:Vector3=outward.cross(Vector3.UP)
	for side:float in [0.0,2.0,-2.0,4.0,-4.0]:
		var point:Vector3=route._outside+outward*3.0+lateral*side
		var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.7,point-Vector3.UP*.7,1);ray.exclude=[_player.get_rid(),_body.get_rid()]
		var floor:Dictionary=space.intersect_ray(ray)
		if floor.is_empty() or (floor.normal as Vector3).y<.7:continue
		point.y=float(floor.position.y)+.01
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=Transform3D(Basis.IDENTITY,point)*shape.transform;query.collision_mask=_player.collision_mask;query.exclude=[_player.get_rid()];query.margin=.001
		if not space.intersect_shape(query,1).is_empty() or point.distance_to(_body.global_position)>17.0:continue
		_player.global_position=point;_player.velocity=Vector3.ZERO;player_repositions30+=1
		shot_direction30=(outward+Vector3.UP*.6).normalized();return true
	return false

func _receipts30()->Array:
	return _life._account.snapshot().account.receipts.filter(func(r:Dictionary)->bool:return r.kind in ["local_shop_purchase28","local_restaurant_purchase28"])

func _service_current30()->bool:
	var route:RefCounted=economy30._route
	return route!=null and route.is_inside() and registry30.service_owner29(route._key,route._venue,route)

func _physics_process(delta:float)->void:
	var now:int=Time.get_ticks_msec()
	if _phase=="bootstrap":
		if now-_start_ms>90000:_finish("bootstrap_timeout");return
		_bind(get_tree().current_scene as Node3D);return
	if _phase=="finished":return
	if _fire_down:_button(MOUSE_BUTTON_LEFT,false);_fire_down=false
	if now>_deadline_ms:_finish("timeout:"+_phase);return
	if _body.get_instance_id()!=setup30.body_id or int(_life._token.life_generation)!=int(setup30.generation):_finish("unexpected_generation_change");return
	var step_m:float=Vector2(_body.global_position.x-previous30.x,_body.global_position.z-previous30.z).length()
	total_m30+=step_m;max_step30=maxf(max_step30,step_m);previous30=_body.global_position
	if step_m>1.0:violations30.append("nonphysical_position_jump")
	if float(_health._row.hp)!=float(setup30.hp):violations30.append("miss_shot_changed_health")
	var service:bool=_service_current30();var receipts:Array=_receipts30()
	if receipts.size()>last_receipts30:
		if not (service or previous_service30):violations30.append("payment_without_staff_service")
		payment30={"receipt":receipts.back().duplicate(true),"cash":_life._account.snapshot().account.cash,"energy":_life._energy,"frame":Engine.get_physics_frames(),"service":service or previous_service30}
	last_receipts30=receipts.size();previous_service30=service
	var threat:RefCounted=_life._threat30;var state:Dictionary=threat.snapshot() if threat!=null else {}
	if threat!=null and threat.active():
		quiet30=maxf(quiet30,float(state.quiet_until))
		if _phase in ["fire","release"] and not release_seen30 and interrupted_route30!=null and interrupted_route30.needs_exit():threat_was_inside30=true
		if state.phase=="FLEE":
			if not flee_seen30:flee_seen30=true;flee_origin30=_body.global_position
			flee_distance30+=step_m;max_speed30=maxf(max_speed30,step_m/delta)
	if _phase=="approach":
		_look30(Vector3(0,.7,-1).normalized())
		if economy30._phase=="DWELL" and service:
			interrupted_route30=economy30._route;route_key30=interrupted_route30._key;venue30=interrupted_route30._venue
			var entry:Dictionary=registry30.entry(venue30);var staff:Node=get_tree().current_scene.preview_venue_staff29
			if not staff._rows.has(venue30) or not staff._rows[venue30].actor.serving29:return
			service30={"position":_body.global_position,"point":entry.service_point29,"distance":_body.global_position.distance_to(entry.service_point29),"on_floor":_body.is_on_floor(),"venue":venue30,"phase":interrupted_route30._phase,"capacity_owned":registry30.owns(route_key30,interrupted_route30),"service_owned":service,"staff_serving":staff._rows.has(venue30) and staff._rows[venue30].actor.serving29}
			checks30.native_service_inside=service30.distance<=.42 and service30.on_floor and service30.capacity_owned and service30.staff_serving
			if not _place_player_outside30(interrupted_route30):_finish("player_outside_setup_unavailable");return
			var result:Dictionary=_weapons.equip("tt_pistol")
			if not result.get("ok",false):_finish("equip_refused");return
			_phase="fire";phase_at30=now;_stable=0
	elif _phase=="fire":
		_stable=_stable+1 if _look30(shot_direction30) else 0
		if _fired==0 and _stable>=5 and _weapons.presentation.current_muzzle().get("ok",false):_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired=1
		if not _shots.is_empty():_weapons.equip("none");_phase="release";phase_at30=now
		elif now-phase_at30>5000:_finish("native_shot_not_emitted");return
	elif _phase=="release":
		if threat!=null and threat.active() and str(state.kind)=="near_shot":checks30.authentic_native_shot=world30.authentic(_life,threat._event) and str(threat._event.event_id)=="shot:"+str(_shots[0].shot_id)
		if economy30.active() and not registry30.owns(route_key30,interrupted_route30) and not interrupted_route30.is_outside():violations30.append("capacity_released_before_physical_exit")
		if not economy30.active():
			release_seen30=true
			interruption30={"position":_body.global_position,"depth":interrupted_route30.depth_inside(),"outside_distance":_body.global_position.distance_to(interrupted_route30._outside),"capacity_released":not registry30.ledger.requests.has(route_key30),"service_released":not registry30._service29.keys.has(route_key30),"pending":economy30._pending.duplicate(true),"cash":_life._account.snapshot().account.cash,"receipts":receipts.size(),"phase":state.get("phase","")}
			checks30.physical_exit=interrupted_route30.is_outside() and interruption30.depth< -1.1
			checks30.claims_released=interruption30.capacity_released and interruption30.service_released
			checks30.interrupted_purchase_preserved=economy30._pending.get("kind")==kind30 and int(economy30._pending.get("price",-1))==price30 and receipts.is_empty() and int(interruption30.cash)==cash30
			checks30.threat_during_service=threat_was_inside30
			_phase="quiet";phase_at30=now
		elif now-phase_at30>30000:_finish("service_exit_stuck");return
	elif _phase=="quiet":
		if threat!=null and not threat.active():
			quiet_seen30=true;checks30.quiet_releases_at_15s=world30._now>=quiet30 and threat._reason=="quiet_15_seconds"
			checks30.real_flee=flee_seen30 and flee_distance30>=2.0 and max_speed30>1.8 and max_speed30<2.1
			_phase="resumed_purchase";phase_at30=now
	elif _phase=="resumed_purchase":
		if not payment30.is_empty() and not economy30.active():
			checks30.real_payment_once=receipts.size()==1 and int(payment30.receipt.amount)==price30 and int(payment30.cash)==cash30-price30 and payment30.service
			checks30.actual_energy_restored=float(payment30.energy)>=99.5
			checks30.resumed_purchase_completed=int(_life._completed.get(kind30,0))>=1 and registry30.ledger.requests.is_empty() and registry30._service29.keys.is_empty()
			checks30.conserved_account=_life._account.snapshot().get("conserved",false)
			walks30=int(_life._completed.walk);_phase="normal_walk";phase_at30=now
	elif _phase=="normal_walk":
		if int(_life._completed.walk)>walks30:
			checks30.normal_native_walk_completed=true;_finish("complete");return
	if now-_last_log>=500:
		_last_log=now;_rows.append({"ms":now-_ready_ms,"phase":_phase,"position":_body.global_position,"hp":_health._row.hp,"energy":_life._energy,"cash":_life._account.snapshot().account.cash,"economy":economy30.snapshot(),"threat":state,"service":service,"receipts":receipts.size()})

func _finish(reason:String)->void:
	if _phase=="finished":return
	_phase="finished";set_physics_process(false)
	if is_instance_valid(_weapons):_weapons.cancel_inputs();_weapons.equip("none")
	var required:Array[String]=["initial_full_health","initial_affordable_purchase","native_service_inside","authentic_native_shot","physical_exit","claims_released","interrupted_purchase_preserved","threat_during_service","quiet_releases_at_15s","real_flee","real_payment_once","actual_energy_restored","resumed_purchase_completed","conserved_account","normal_native_walk_completed"]
	var passed:bool=reason=="complete" and violations30.is_empty()
	for key:String in required:passed=passed and checks30.get(key,false)==true
	var result:Dictionary={"passed":passed,"reason":reason,"kind":kind30,"checks":checks30,"violations":violations30,"setup":setup30,"service":service30,"interruption":interruption30,"payment":payment30,"shots":_shots,"terminals":_terminals,"total_native_m":total_m30,"flee_m":flee_distance30,"max_flee_speed":max_speed30,"max_step_m":max_step30,"samples":_rows,"npc_relocations":0,"player_setup_repositions":player_repositions30,"synthetic_damage":false,"fixture_settlements":0,"fixture_claims":0,"performance_accepted":false}
	if not _out.is_empty():
		var file:=FileAccess.open(_out.path_join("SERVICE_THREAT30.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("SERVICE_THREAT30_FINISH ",JSON.stringify({"passed":passed,"reason":reason,"checks":checks30,"violations":violations30}))
	get_tree().quit(0 if passed else 1)
