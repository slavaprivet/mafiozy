extends "res://scripts/combat/preview_melee.gd"
## Local accepted-session bridge. The inherited source still owns input/timing.
## Damage only follows a displayed-fist sweep against original posed triangles.
const SurfaceQuery=preload("res://scripts/npc_visual/npc_melee_surface_query.gd")
const GeometryCache=preload("res://scripts/npc_visual/npc_melee_geometry_cache.gd")
const LimbSurface=preload("res://scripts/npc_visual/npc_melee_limb_surface.gd")
const PlayerHealth=preload("res://scripts/npc_visual/npc_melee_player_health.gd")
const DAMAGE={"punch":12,"kick":21,"heavy":18,"dropkick":18}
const MAX_STEP_SECONDS:=.05
var _population: RefCounted
var _query:=SurfaceQuery.new()
var _player_limb: RefCounted
var _npc_limbs: Dictionary={}
var _player_skin: RefCounted
var _health: RefCounted
var _swing: Dictionary={}
var _sampled_attack_pose: Dictionary={}
var _npc_samples: Dictionary={}
var _npc_frame_samples: Dictionary={}
var _target_poses: Dictionary={}
var _controllers: Dictionary={}
var _reaction_restore: Dictionary={}
var _proof: Dictionary={}
var _proof_owner: Object
var _proof_spent:=true
var _sphere:=SphereShape3D.new()
var _shape_query:=PhysicsShapeQueryParameters3D.new()
var _ray_query:=PhysicsRayQueryParameters3D.new()
var combat_ready:=false
var combat_error:=""
var combat_error_detail: Dictionary={}
var contact_checks:=0
var confirmed_hits:=0
var npc_query_hits:=0
var npc_query_misses:=0
var npc_health_accepts:=0
var npc_contact_trace: Array[Dictionary]=[]
var player_contact_sequences: Dictionary={}
var rejected_walls:=0
var sampling_counts: Dictionary={"npc_limb_samples":0,"npc_same_frame_reuses":0,"npc_prime_frames":0,"npc_skipped_frames":0,"player_target_palettes":0,"npc_target_palettes":0,"previous_sequence_rejects":0}

func bind_combat(population: RefCounted) -> Dictionary:
	if combat_ready or not _live() or population==null or population.status!="ready":return {"ok":false,"reason":"population"}
	_population=population
	_player_skin=GeometryCache.new()
	if not _player_skin.configure_geometry(_player._visual,_player._pose_skeleton,_player._model_scale):return _binding_failed("player_geometry")
	_player_limb=LimbSurface.new()
	if not _player_limb.configure(_player_skin).get("valid",false):return _binding_failed("player_limb_geometry")
	_health=PlayerHealth.new()
	if not _health.configure(_scene,_player,self):return _binding_failed("player_health_pose_owner")
	for owner: RefCounted in population.hit_owners:
		if not owner.bind_melee_producer(self):return _binding_failed("npc_contact_owner")
		var controller: RefCounted=population.residents.attach_contact_retaliation(owner._token,Callable(self,"retaliation_current"),Callable(owner,"confirmed_player_damage"))
		if controller==null:return _binding_failed("npc_retaliation")
		_controllers[owner._token.source_id]=controller
		var limb: RefCounted=LimbSurface.new()
		if not limb.configure(owner.marks.renderer).get("valid",false):return _binding_failed("npc_limb_geometry")
		_npc_limbs[owner._token.source_id]=limb
		var record: Dictionary=population.residents._records[owner._token.source_id]
		_reaction_restore[owner._token.source_id]={"record":record,"had":record.has("contact_hit_reaction"),"value":record.get("contact_hit_reaction"),"assigned":owner.bullet_reaction}
		record["contact_hit_reaction"]=owner.bullet_reaction
	_shape_query.shape=_sphere;_shape_query.collision_mask=0xffffffff;_shape_query.collide_with_areas=false
	_ray_query.collision_mask=0xffffffff;_ray_query.collide_with_areas=false
	# Both original pose writers run at the normal physics priority. This observer
	# only reads the poses after them; it does not install a second bone writer.
	process_physics_priority=1000;combat_ready=true
	return {"ok":true,"scope":"local_new_session_contact_melee","targets":population.hit_owners.size()}

func _binding_failed(reason: String) -> Dictionary:
	_release_combat_binding()
	return {"ok":false,"reason":reason}

func _release_combat_binding() -> void:
	combat_ready=false
	if _population!=null:
		var records: Dictionary={} if _population.residents==null else _population.residents._records
		for owner: RefCounted in _population.hit_owners:
			if owner._melee_producer!=null and owner._melee_producer.get_ref()==self:owner._melee_producer=null
			var id: String=owner._token.source_id
			var controller: RefCounted=_controllers.get(id)
			var record: Dictionary=records.get(id,{})
			if controller!=null:
				if record.get("melee_retaliation")==controller:record.erase("melee_retaliation")
	for saved: Dictionary in _reaction_restore.values():
		if saved.record.get("contact_hit_reaction")==saved.assigned:
			if saved.had:saved.record["contact_hit_reaction"]=saved.value
			else:saved.record.erase("contact_hit_reaction")
	_reaction_restore.clear()
	for controller: RefCounted in _controllers.values():controller.dispose()
	if _player_skin!=null:_player_skin.dispose()
	if _health!=null:_health.dispose()
	_player_skin=null;_player_limb=null;_health=null;_population=null
	_proof={};_proof_owner=null;_proof_spent=true
	_controllers.clear();_npc_samples.clear();_npc_frame_samples.clear();_npc_limbs.clear();_swing.clear();_target_poses.clear()

func _allowed() -> bool:
	return _live() and last_error.is_empty() and not _scene.preview_dead and not _scene.preview_physics_fault and _player._pose_authority==&"on_foot" and _player._free_mouse_look and not _player._text_control_focused() and (not is_instance_valid(_player._weapon_host) or (not _player._weapon_host.armed() and not _player._weapon_host.controls_blocked()))

func _options() -> Dictionary:
	var yaw: float=_player._visual.global_rotation.y
	return {"allowed":_allowed(),"armed":is_instance_valid(_player._weapon_host) and _player._weapon_host.armed(),"airborne":not _player._jump.is_empty(),"yaw":_assisted_yaw(yaw),"airHeight":maxf(0.0,_player.global_position.y-float(_player._jump.get("base_y",_player.global_position.y))),"time":clock_ms()/1000.0,"buttons":1 if _left_held else 0}

func _assisted_yaw(yaw: float) -> float:
	# Aim assistance only rotates the real displayed attack. It cannot admit HP.
	if not combat_ready or (_state.get("start") is Dictionary) or (not _left_held and _input._pressed_at==null):return yaw
	var best:=INF;var guided:=yaw
	for owner: RefCounted in _population.hit_owners:
		if not _population.residents.physical_life_current(owner._token) or owner._row.get("dead",false) or owner._row.get("_medicalDowned",false):continue
		var offset: Vector3=owner._token.body.global_position-_player.global_position
		var distance:=Vector2(offset.x,offset.z).length()
		if distance<.25 or distance>2.2 or absf(offset.y)>.6:continue
		var wanted:=atan2(offset.x,offset.z)
		var angle:=angle_difference(yaw,wanted)
		if absf(angle)>deg_to_rad(30):continue
		var ray:=PhysicsRayQueryParameters3D.create(_player.global_position+Vector3.UP*1.2,owner._token.body.global_position+Vector3.UP*1.2)
		ray.exclude=[_player.get_rid(),owner._token.body.get_rid()]
		if not _player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		var score:=absf(angle)+distance*.1
		if score<best:best=score;guided=yaw+angle
	return guided

func advance(delta: float) -> void:
	if not _live():return
	if _epoch!=_player._pose_epoch:
		cancel("pose_owner_changed");_epoch=_player._pose_epoch
		_swing.clear();_npc_samples.clear();_target_poses.clear()
	var allowed:=_allowed()
	if not allowed and (_allowed_last or _left_held or _right_held):cancel("control_locked");_swing.clear()
	_allowed_last=allowed
	_check(_source.advance())
	if allowed:
		_state=_input.step(_options());_check(_state)
		var start: Variant=_state.get("start")
		if start is Dictionary and start.type=="dropkick":
			if not _player.has_method("_request_contact_dropkick"):cancel("dropkick_motion_unavailable")
			elif _player.contact_dropkick_sequence()!=int(start.seq) and not _player._request_contact_dropkick(start):cancel("dropkick_motion_rejected")
	# Resolve misses only after the late observer clips and tests the final span.
	_camera_kick*=pow(.001,maxf(0,delta))
	if absf(_camera_kick.x)<.05:_camera_kick.x=0
	if absf(_camera_kick.y)<.05:_camera_kick.y=0
	if is_instance_valid(_player._camera):
		_player._camera.h_offset=_camera_home.x+_camera_kick.x*.008
		_player._camera.v_offset=_camera_home.y+_camera_kick.y*.008

func decorate(selected: Dictionary,delta: float) -> Dictionary:
	_sampled_attack_pose.clear()
	if _pose.has_method("set_contact_aim"):_pose.set_contact_aim(_nearby_punch_aim())
	var result: Dictionary=super.decorate(selected,delta)
	if _pose.has_method("set_contact_aim"):_pose.set_contact_aim(Vector3.INF)
	var start: Variant=_state.get("start")
	var melee: Variant=result.get("melee")
	if not result.get("valid",false) or not start is Dictionary or not melee is Dictionary or not melee.get("active",false) or melee.get("type")!=start.get("type"):return result
	var pose_age: Variant=melee.get("age")
	if not (pose_age is float or pose_age is int) or not is_finite(float(pose_age)) or pose_age<0:return result
	if not is_instance_valid(_player._pose_skeleton):return result
	# This is only a proposal stamp until the player's sole final writer
	# publishes exactly revision+1 for the same life and pose epoch.
	_sampled_attack_pose={"seq":start.seq,"kind":start.type,"age_ms":float(pose_age)*1000.0,"frame":Engine.get_physics_frames(),"epoch":_player._pose_epoch,"revision":_player._pose_revision+1,"rig_id":_player._pose_skeleton.get_instance_id(),"rig_version":_player._pose_skeleton.get_version(),"actor_id":_player.get_meta("actor_id",""),"life_generation":_player.get_meta("life_generation",0)}
	_sampled_attack_pose["pose_side"]=melee.get("side",0)
	_sampled_attack_pose["aim_world"]=melee.get("contact_aim_world",Vector3.INF)
	return result

func _nearby_punch_aim() -> Vector3:
	var start: Variant=_state.get("start")
	if not combat_ready or not _allowed() or not start is Dictionary or start.get("type")!="punch":return Vector3.INF
	var yaw: float=_player._visual.global_rotation.y
	var best:=INF;var aim:=Vector3.INF
	for owner: RefCounted in _population.hit_owners:
		if not _population.residents.physical_life_current(owner._token) or owner._row.get("dead",false) or owner._row.get("_medicalDowned",false):continue
		var offset: Vector3=owner._token.body.global_position-_player.global_position
		var distance:=Vector2(offset.x,offset.z).length()
		if distance<.25 or distance>1.45 or absf(offset.y)>.6:continue
		var angle:=absf(angle_difference(yaw,atan2(offset.x,offset.z)))
		if angle>deg_to_rad(30):continue
		var rig: Skeleton3D=owner._token.rig
		var chest:=rig.find_bone("chest");var neck:=rig.find_bone("neck")
		if mini(chest,neck)<0:continue
		var point: Vector3=rig.global_transform*rig.get_bone_global_pose(chest).origin.lerp(rig.get_bone_global_pose(neck).origin,.60)
		var ray:=PhysicsRayQueryParameters3D.create(_player.global_position+Vector3.UP*1.2,point)
		ray.exclude=[_player.get_rid(),owner._token.body.get_rid()]
		if not _player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		var score:=distance+angle
		if score<best:best=score;aim=point
	return aim

static func pose_stamp_matches(stamp: Dictionary,receipt: Dictionary,current: Dictionary) -> bool:
	if stamp.is_empty() or receipt.get("pose_owner")!="on_foot":return false
	if not stamp.get("age_ms") is float and not stamp.get("age_ms") is int:return false
	if not is_finite(float(stamp.age_ms)) or stamp.age_ms<0:return false
	if not stamp.get("actor_id") is String or stamp.actor_id.is_empty() or not stamp.get("life_generation") is int or stamp.life_generation<1:return false
	for key: String in ["seq","kind","frame","epoch","revision","rig_id","rig_version","actor_id","life_generation"]:
		if not stamp.has(key) or stamp[key]!=current.get(key):return false
	return receipt.get("pose_epoch")==stamp.epoch and receipt.get("pose_revision")==stamp.revision and receipt.get("actor_id")==stamp.actor_id and receipt.get("life_generation")==stamp.life_generation

func _committed_attack_pose(start: Dictionary) -> Dictionary:
	if not is_instance_valid(_player) or not is_instance_valid(_player._pose_skeleton) or _player._pose_authority!=&"on_foot":return {}
	var receipt: Variant=_player.get_meta(&"melee_skin_pose",{})
	if not receipt is Dictionary:return {}
	var current: Dictionary={"seq":start.get("seq"),"kind":start.get("type"),"frame":Engine.get_physics_frames(),"epoch":_player._pose_epoch,"revision":_player._pose_revision,"rig_id":_player._pose_skeleton.get_instance_id(),"rig_version":_player._pose_skeleton.get_version(),"actor_id":_player.get_meta("actor_id",""),"life_generation":_player.get_meta("life_generation",0)}
	return _sampled_attack_pose if pose_stamp_matches(_sampled_attack_pose,receipt,current) else {}

static func missed_pose_window(pose: Dictionary,window_end_ms: float,source_age_ms: float) -> bool:
	# Wall clock is only a bounded delivery expiry. It cannot advance the
	# displayed pose or close its last interval before the pose is sampled.
	return (not pose.is_empty() and float(pose.age_ms)>=window_end_ms) or source_age_ms>window_end_ms+250.0

func _close_missed_window() -> void:
	var start: Variant=_state.get("start")
	if not start is Dictionary or int(start.seq)==_resolved_seq:return
	var source_age:=clock_ms()-float(start.sourceStartAt)
	if missed_pose_window(_committed_attack_pose(start),float(start.contactWindow[1]),source_age):
		_source.resolveWalkMelee({"seq":start.seq,"contact":null});_resolved_seq=int(start.seq)

func source_state() -> Dictionary:
	var state: Dictionary=super.source_state()
	if not state.is_empty():state.armed=is_instance_valid(_player._weapon_host) and _player._weapon_host.armed()
	return state

func retaliation_current(token: Dictionary,target: Node3D) -> bool:
	if not combat_ready or not _live() or target!=_player or _scene.preview_dead or _scene.preview_physics_fault:return false
	if _player._pose_authority!=&"on_foot" or not _player.is_on_floor() or not _player._free_mouse_look:return false
	if is_instance_valid(_player._weapon_host) and _player._weapon_host.controls_blocked():return false
	if not _population.residents.physical_life_current(token):return false
	for owner: RefCounted in _population.hit_owners:
		if owner._token.source_id==token.source_id:
			return not owner._row.get("dead",false) and not owner._row.get("_medicalDowned",false) and not owner._row.get("_forcedCrawl",false) and float(owner._row.get("hp",0))>0
	return false

func _limb_bounds(sample: Dictionary) -> Dictionary:
	if not sample.get("valid",false):return {}
	var box: AABB=LimbSurface._box(sample.triangles)
	return {"box":box,"center":box.get_center(),"radius":box.size.length()*.5+LimbSurface.CONTACT_M}

func _physics_process(delta: float) -> void:
	if not combat_ready:return
	if not _live():set_physics_process(false);return
	# At most one current-pose sample per NPC/hand. Prior-frame sweep endpoints
	# remain in _npc_samples until all current contact queries have completed.
	_npc_frame_samples.clear()
	_health.step(delta)
	if not is_finite(delta) or delta<=0 or delta>MAX_STEP_SECONDS:
		_swing.clear();_npc_samples.clear();_target_poses.clear();_close_missed_window();return
	_player_contact()
	_close_missed_window()
	_npc_contact()
	_remember_npc_fists()
	_remember_target_poses()

func _player_contact() -> void:
	var start: Variant=_state.get("start")
	if not _allowed() or not start is Dictionary or int(start.seq)==_resolved_seq:
		_swing.clear();return
	var committed: Dictionary=_committed_attack_pose(start)
	if committed.is_empty():_swing.clear();return
	var kind:=str(start.type);var side:="l" if int(start.side)<0 else "r"
	var sides: Array[String]=[]
	if kind=="dropkick":sides.append_array(["l","r"])
	else:sides.append(side)
	var samples: Array[Dictionary]=[]
	for limb: String in sides:
		var sample: Dictionary=_player_limb.sample(kind,limb)
		if not sample.get("valid",false):combat_error="player_limb_sample";_swing.clear();return
		samples.append(sample)
	var age: float=committed.age_ms
	if _swing.get("seq")!=start.seq or _swing.get("epoch")!=_player._pose_epoch or _swing.get("frame",-2)!=Engine.get_physics_frames()-1 or _swing.get("revision",-2)!=int(committed.revision)-1:
		_swing={"seq":start.seq,"epoch":_player._pose_epoch,"samples":samples,"age":age,"frame":committed.frame,"revision":committed.revision};return
	var old_samples: Array=_swing.samples;var previous_age: float=_swing.age
	_swing.samples=samples;_swing.age=age;_swing.frame=committed.frame;_swing.revision=committed.revision
	var window: Array=start.contactWindow
	if age<float(window[0]) or previous_age>float(window[1]) or age<=previous_age:return
	var lo:=clampf((float(window[0])-previous_age)/(age-previous_age),0,1)
	var hi:=clampf((float(window[1])-previous_age)/(age-previous_age),0,1)
	var best: Dictionary={};var victim: RefCounted
	var query_uncertainties: Array[Dictionary]=[]
	var from:=Vector3.ZERO;var to:=Vector3.ZERO
	for limb in samples.size():
		var previous: Dictionary=old_samples[limb];var sample: Dictionary=samples[limb]
		var old_bounds:=_limb_bounds(previous);var bounds:=_limb_bounds(sample)
		if old_bounds.is_empty() or bounds.is_empty():continue
		var radius: float=maxf(old_bounds.radius,bounds.radius)
		if radius>.5 or bounds.center.distance_to(old_bounds.center)>.6:continue
		var sweep_from: Vector3=old_bounds.center.lerp(bounds.center,lo)
		var sweep_to: Vector3=old_bounds.center.lerp(bounds.center,hi)
		var confirmation: Callable = _player_limb.query_confirmation(previous,sample,lo,hi)
		for owner: RefCounted in _population.hit_owners:
			# Player may be airborne for dropkick; only the NPC needs a current living life.
			if not _population.residents.physical_life_current(owner._token) or owner._row.get("dead",false) or owner._token.body.global_position.distance_to(_player.global_position)>3.0:continue
			if owner.marks==null or owner.marks.renderer==null:continue
			var previous_target: Dictionary=_target_poses.get(owner.marks.renderer.get_instance_id(),{})
			if previous_target.get("frame",-2)!=Engine.get_physics_frames()-1:continue
			contact_checks+=1
			var query_started_usec:=Time.get_ticks_usec()
			var result: Dictionary=_query.sweep(owner.marks.renderer,sweep_from,sweep_to,radius,confirmation,previous_target,old_bounds.box.merge(bounds.box))
			var query_usec: int=Time.get_ticks_usec()-query_started_usec
			_record_player_contact_trace(start,owner,sample,bounds,previous_age,age,lo,hi,query_usec,result)
			if not result.get("valid",false):
				combat_error=str(result.get("reason","geometry_query"));combat_error_detail=result.duplicate(true)
				if best.is_empty() or not SurfaceQuery.recoverable_uncertainty(result):return
				query_uncertainties.append({"source_id":owner._token.source_id,"limb":sample.limb,"uncertainty":result.duplicate(true)})
				continue
			if result.get("query_incomplete",false):
				query_uncertainties.append({"source_id":owner._token.source_id,"limb":sample.limb,"uncertainty":result.get("query_uncertainty",{}).duplicate(true)})
			if result.get("hit",false) and (best.is_empty() or result.score<best.score):
				best=result;victim=owner;from=sweep_from;to=sweep_to
	if best.is_empty():return
	# Revalidate the chosen proof after visiting other NPCs/feet. A budget refusal
	# elsewhere cannot erase it, but pose ownership or life changes always can.
	if not _allowed() or _committed_attack_pose(start).is_empty() or _player_skin==null or not _player_skin._valid() or victim==null or not _population.residents.physical_life_current(victim._token) or victim._row.get("dead",false) or victim._row.get("_medicalDowned",false) or victim.marks==null or victim.marks.renderer==null or not victim.marks.renderer._valid():
		combat_error="selected_contact_lifetime_changed";combat_error_detail={"valid":false,"reason":combat_error};return
	best.query_incomplete=not query_uncertainties.is_empty()
	best.query_uncertainties=query_uncertainties
	var origin: Vector3=_player.global_position+Vector3.UP*1.25
	if not _clear_path(_player,victim._token.body,origin,best.limb_path_from,best.limb_path_to,best.point,LimbSurface.CONTACT_M):rejected_walls+=1;return
	var direction: Vector3=(to-from).normalized()
	if direction.length_squared()<.5:direction=(best.point-origin).normalized()
	var contact: Dictionary={"event_id":"melee:"+str(get_instance_id())+":"+str(start.seq),"attack_id":str(start.seq),"attack_type":kind,"source_id":victim._token.source_id,"life_generation":victim._token.life_generation,"attacker_instance_id":_player.get_instance_id(),"collider":victim._token.body,"point":best.point,"normal":best.normal,"direction":direction,"attack_origin":origin,"damage":DAMAGE.get(kind,12),"surface_index":best.surface_index,"face_indices":best.face_indices,"barycentric":best.barycentric}
	contact.query_incomplete=best.query_incomplete
	contact.query_uncertainties=query_uncertainties.duplicate(true)
	_proof=contact.duplicate(true);_proof_owner=victim;_proof_spent=false
	var contact_age: float=lerpf(previous_age,age,float(best.alpha))
	var result: Dictionary=_source.resolveWalkMelee({"seq":start.seq,"contact":contact,"contactAge":contact_age})
	_proof_spent=true;_proof={};_proof_owner=null
	_resolved_seq=int(start.seq)
	if result.get("confirmed",false):
		confirmed_hits+=1
		_controllers[victim._token.source_id].notify_confirmed_player_damage(contact.event_id,_player)

func _record_player_contact_trace(start: Dictionary,owner: RefCounted,sample: Dictionary,bounds: Dictionary,previous_age: float,age: float,lo: float,hi: float,query_usec: int,result: Dictionary) -> void:
	var key:=str(start.seq)
	if not player_contact_sequences.has(key):
		if player_contact_sequences.size()>=8:player_contact_sequences.erase(player_contact_sequences.keys()[0])
		player_contact_sequences[key]={"seq":start.seq,"kind":start.type,"source_side":start.side,"pose_side":_sampled_attack_pose.get("pose_side",0),"limb":sample.limb,"query_count":0,"hits":0,"failures":0,"nearest_distance_m":INF,"nearest":{},"last":{},"first_error":{},"max_query_usec":0,"total_query_usec":0,"max_span_ms":0.0}
	var record: Dictionary=player_contact_sequences[key]
	var target: Vector3=owner._token.body.global_position+Vector3.UP*1.2
	var rig: Skeleton3D=owner._token.rig
	var chest:=rig.find_bone("chest");var neck:=rig.find_bone("neck")
	if mini(chest,neck)>=0:target=rig.global_transform*rig.get_bone_global_pose(chest).origin.lerp(rig.get_bone_global_pose(neck).origin,.60)
	var distance: float=bounds.center.distance_to(target)
	var trace: Dictionary={"frame":Engine.get_physics_frames(),"age_ms":age,"lo":lo,"hi":hi,"target_id":owner._token.source_id,"target_center":target,"limb_center":bounds.center,"limb_box":str(bounds.box),"center_gap_m":distance,"aim_world":_sampled_attack_pose.get("aim_world",Vector3.INF),"valid":result.get("valid",false),"hit":result.get("hit",false),"reason":result.get("reason",""),"target_triangles":_query.triangles_tested,"target_vertices":_query.vertices_skinned}
	trace.player_body_position=_player.global_position
	trace.target_body_position=owner._token.body.global_position
	trace.body_distance_m=_player.global_position.distance_to(owner._token.body.global_position)
	trace.previous_age_ms=previous_age
	trace.current_age_ms=age
	trace.span_ms=age-previous_age
	trace.query_usec=query_usec
	record.query_count+=1
	record.max_query_usec=maxi(int(record.max_query_usec),query_usec)
	record.total_query_usec+=query_usec
	record.max_span_ms=maxf(float(record.max_span_ms),age-previous_age)
	if result.get("hit",false):record.hits+=1
	if not result.get("valid",false):
		record.failures+=1
		if record.first_error.is_empty():
			record.first_error=trace.duplicate(true)
			record.first_error.detail=result.duplicate(true)
	if distance<float(record.nearest_distance_m):record.nearest_distance_m=distance;record.nearest=trace.duplicate(true)
	record.last=trace

func resolve_contact(_context: Dictionary,request: Dictionary) -> Dictionary:
	if _proof_spent or _proof_owner==null or request.get("contact")!=_proof:return {"accepted":false,"reason":"no_current_contact_proof"}
	var result: Dictionary=_proof_owner.apply_melee_contact(_proof,self)
	var receipt: Dictionary=_proof_owner.confirmed_player_damage(str(_proof.event_id))
	return {"accepted":true,"hit":true,"confirmed":true} if result.get("ok",false) and result.get("applied",false) and not receipt.is_empty() else {"accepted":false,"reason":str(result.get("reason","hp_owner_rejected"))}

func validate_melee_contact(owner: Object,contact: Dictionary) -> bool:
	if _proof_spent or owner!=_proof_owner or contact!=_proof:return false
	_proof_spent=true
	return true

func _npc_contact() -> void:
	for cap: Dictionary in _population.residents.contact_retaliation_capabilities():
		var id: String=cap.attacker.source_id
		if not cap.active_window or cap.physics_frame!=Engine.get_physics_frames() or not retaliation_current(cap.attacker,_player):continue
		var observer: RefCounted=_npc_limbs[id]
		var old: Dictionary=_npc_samples.get(id,{})
		if old.get("frame",-2)!=Engine.get_physics_frames()-1 or not old.has(cap.side):continue
		if old.get("sequence",-1)!=cap.sequence or old.get("life_generation",-1)!=cap.attacker.life_generation:
			sampling_counts.previous_sequence_rejects+=1;continue
		var sample: Dictionary=_sample_npc_fist(id,int(cap.sequence),int(cap.attacker.life_generation),str(cap.side))
		if not sample.get("valid",false):_npc_samples.erase(id);continue
		var previous: Dictionary=old[cap.side]
		var old_bounds:=_limb_bounds(previous);var bounds:=_limb_bounds(sample)
		if old_bounds.is_empty() or bounds.is_empty():continue
		var radius: float=maxf(old_bounds.radius,bounds.radius)
		if radius>.5 or old_bounds.center.distance_to(bounds.center)>.6:continue
		var from: Vector3=old_bounds.center.lerp(bounds.center,float(cap.sweep_alpha_from))
		var to: Vector3=old_bounds.center.lerp(bounds.center,float(cap.sweep_alpha_to))
		var confirmation: Callable = observer.query_confirmation(previous,sample,float(cap.sweep_alpha_from),float(cap.sweep_alpha_to))
		var previous_target: Dictionary=_target_poses.get(_player_skin.get_instance_id(),{})
		if previous_target.get("frame",-2)!=Engine.get_physics_frames()-1:continue
		contact_checks+=1
		var result: Dictionary=_query.sweep(_player_skin,from,to,radius,confirmation,previous_target,old_bounds.box.merge(bounds.box))
		if npc_contact_trace.size()>=24:npc_contact_trace.pop_front()
		npc_contact_trace.append({"source_id":id,"sequence":cap.sequence,"frame":Engine.get_physics_frames(),"age":cap.age,"side":cap.side,"clip_from":cap.sweep_alpha_from,"clip_to":cap.sweep_alpha_to,"body_distance_m":_player.global_position.distance_to(cap.attacker.body.global_position),"limb_center":bounds.center,"valid":result.get("valid",false),"hit":result.get("hit",false),"reason":result.get("reason",""),"triangles_tested":_query.triangles_tested,"vertices_skinned":_query.vertices_skinned})
		if not result.get("valid",false):combat_error="player_skin_query";combat_error_detail=result.duplicate(true);continue
		if not result.get("hit",false):npc_query_misses+=1;continue
		npc_query_hits+=1
		var origin: Vector3=cap.attacker.body.global_position+Vector3.UP*1.25
		if not _clear_path(cap.attacker.body,_player,origin,result.limb_path_from,result.limb_path_to,result.point,LimbSurface.CONTACT_M):rejected_walls+=1;continue
		if not cap.controller.confirm_contact(cap.sequence):continue
		var contact: Dictionary={"event_id":"npc-melee:"+id+":"+str(cap.attacker.life_generation)+":"+str(cap.sequence),"source_id":id,"life_generation":cap.attacker.life_generation,"point":result.point,"normal":result.normal,"damage":12,"direction":(_player.global_position-cap.attacker.body.global_position).normalized(),"attacker_instance_id":cap.attacker.body.get_instance_id()}
		_proof=contact.duplicate(true);_proof_owner=_health;_proof_spent=false
		var health_result: Dictionary=_health.apply_contact(contact,self)
		if health_result.get("applied",false):npc_health_accepts+=1
		npc_contact_trace[-1].health_result=health_result.duplicate(true)
		_proof_spent=true;_proof={};_proof_owner=null

static func npc_pose_prime_needed(phase: String,age: float,held: bool,consumed: bool) -> bool:
	# A future span needs this endpoint only before the .145s clip boundary.
	# The current final clipped span is queried first, even if age crosses it.
	return not held and not consumed and (phase=="WINDUP" or (phase=="ACTIVE" and age<=.145))

func _sample_npc_fist(id: String,sequence: int,generation: int,side: String) -> Dictionary:
	var cached: Dictionary=_npc_frame_samples.get(id,{})
	if cached.get("frame",-1)==Engine.get_physics_frames() and cached.get("sequence",-1)==sequence and cached.get("life_generation",-1)==generation and cached.get("side")==side:
		sampling_counts.npc_same_frame_reuses+=1
		return cached.sample
	var observer: RefCounted=_npc_limbs[id]
	var sample: Dictionary=observer.sample("punch",side)
	sampling_counts.npc_limb_samples+=1
	_npc_frame_samples[id]={"frame":Engine.get_physics_frames(),"sequence":sequence,"life_generation":generation,"side":side,"sample":sample}
	return sample

func _remember_npc_fists() -> void:
	# Recovery/cooldown, held and consumed attacks cannot hit next frame. Keep
	# one exact sequence hand during windup/live priming, never both idle hands.
	for owner: RefCounted in _population.hit_owners:
		var id: String=owner._token.source_id
		var controller: RefCounted=_controllers[id]
		if not _population.residents.physical_life_current(owner._token) or not controller.engaged() or not npc_pose_prime_needed(controller.phase,float(controller.age),bool(controller._held),bool(controller._consumed)):
			sampling_counts.npc_skipped_frames+=1
			_npc_samples.erase(id);continue
		var sequence: int=int(controller.sequence)
		var side: String="r" if sequence%2==1 else "l"
		var sample: Dictionary=_sample_npc_fist(id,sequence,int(owner._token.life_generation),side)
		if not sample.get("valid",false):_npc_samples.erase(id);continue
		var remembered: Dictionary={"frame":Engine.get_physics_frames(),"sequence":sequence,"life_generation":owner._token.life_generation}
		remembered[side]=sample
		_npc_samples[id]=remembered
		sampling_counts.npc_prime_frames+=1

func _remember_target_poses() -> void:
	# Retain only palettes which can pair with a next-frame limb endpoint.
	# Priming is based on the just-published real pose, not engagement duration.
	_target_poses.clear()
	if not _npc_samples.is_empty():
		_target_poses[_player_skin.get_instance_id()]=SurfaceQuery.capture_pose(_player_skin)
		sampling_counts.player_target_palettes+=1
	var start: Variant=_state.get("start")
	if not start is Dictionary or int(start.seq)==_resolved_seq or _swing.get("seq")!=start.seq or _swing.get("frame",-2)!=Engine.get_physics_frames():return
	if float(_swing.get("age",INF))>float(start.contactWindow[1]):return
	for owner: RefCounted in _population.hit_owners:
		if owner.marks!=null and owner.marks.renderer!=null:
			var cache: RefCounted=owner.marks.renderer
			_target_poses[cache.get_instance_id()]=SurfaceQuery.capture_pose(cache)
			sampling_counts.npc_target_palettes+=1

func _clear_path(attacker: CollisionObject3D,target: CollisionObject3D,origin: Vector3,from: Vector3,to: Vector3,point: Vector3,radius: float) -> bool:
	var exclusions: Array[RID]=[attacker.get_rid(),target.get_rid()]
	var space:=attacker.get_world_3d().direct_space_state
	_ray_query.exclude=exclusions;_ray_query.from=origin;_ray_query.to=point
	if not space.intersect_ray(_ray_query).is_empty():return false
	_sphere.radius=radius;_shape_query.exclude=exclusions
	_shape_query.transform=Transform3D(Basis.IDENTITY,from);_shape_query.motion=Vector3.ZERO
	if not space.intersect_shape(_shape_query,1).is_empty():return false
	_shape_query.motion=to-from
	var cast: PackedFloat32Array=space.cast_motion(_shape_query)
	return cast.size()==2 and cast[0]>=.99999

func snapshot() -> Dictionary:
	var result: Dictionary=super.snapshot()
	var retaliation_states: Dictionary={}
	for id: String in _controllers:
		if _controllers[id].has_method("snapshot"):retaliation_states[id]=_controllers[id].snapshot()
	result.retaliation=retaliation_states
	result.player_contact_sequences=player_contact_sequences.duplicate(true)
	result.npc_contact={"query_hits":npc_query_hits,"query_misses":npc_query_misses,"health_accepts":npc_health_accepts,"trace":npc_contact_trace.duplicate(true)}
	result.sampling=sampling_counts.duplicate()
	result.mode="local_contact_melee";result.targets=0 if _population==null else _population.hit_owners.size()
	result.combat_ready=combat_ready;result.combat_error=combat_error;result.contact_checks=contact_checks;result.confirmed_hits=confirmed_hits;result.rejected_walls=rejected_walls
	result.player_health={} if _health==null else _health.snapshot()
	result.combat_error_detail=combat_error_detail.duplicate(true)
	return result

func _exit_tree() -> void:
	_release_combat_binding()
	super._exit_tree()
