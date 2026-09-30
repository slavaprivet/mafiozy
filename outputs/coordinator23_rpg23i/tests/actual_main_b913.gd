extends SceneTree
# Actual original main/owners/inventory/pose/Flight. Camera/player placement is a QA fixture.
var scene:Node3D
var p:CharacterBody3D
var w:Node
var gate:RefCounted
var owners:Array=[]
var aim_point:=Vector3.ZERO
var camera:Camera3D
var tracked:=false
var saved_impact:Callable
var saved_context:Callable
var case_name:="floor"
var out:=""
var started:int
var done:=false
var shots:Array=[]
var impacts:Array=[]
var cosmetic:Array=[]
var cancel_token:=false
var retire_during_context:=false
var report:Dictionary={"checks":0,"errors":[],"scope":"Actual full main with3 original moving NPC, original8buildings/collisions; real input/equip/ammo/pose/native Flight. Detached SAME aim camera and QA player placement. Headless behavior, not visual/performance acceptance. No HP injection or positive synthetic target tickets."}
func _initialize()->void:
	started=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):case_name=arg.trim_prefix("--case=")
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	run.call_deferred()
func _process(_dt:float)->bool:
	if done:return false
	if Time.get_ticks_msec()-started>25000:check(false,"25second bounded deadline");finish();return false
	if tracked and is_instance_valid(p):
		p._free_mouse_look=true
		camera.global_position=p.global_position+Vector3.UP*2.2
		camera.look_at(aim_point,Vector3.RIGHT if absf((aim_point-camera.global_position).normalized().dot(Vector3.UP))>.99 else Vector3.UP)
	return false
func check(ok:bool,label:String)->void:
	report.checks+=1
	if not ok:report.errors.append(label);print("FAIL ",label)
func sync(count:int=1)->void:
	for i in count:
		if done:return
		await physics_frame;await process_frame
func state()->Dictionary:
	var result:Dictionary={}
	for owner:RefCounted in owners:
		var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
		var ids:Array=[];var joints:Array=[]
		for rb:RigidBody3D in physical.owned_bodies():ids.append(rb.get_instance_id())
		for joint:Dictionary in physical._body._joints:joints.append(joint.node.get_instance_id())
		result[owner._token.source_id]={"hp":owner._row.hp,"dead":owner._row.get("dead",false),"medical":owner._row.get("_medicalDowned",false),"serial":owner._serial,"mode":physical.mode,"final_dead":physical.status().get("final_dead",false),"eyes_closed":physical._eyes.closed,"bodies":ids,"joints":joints,"last_result":owner.last_result.duplicate(true)}
	return result
func positions()->Dictionary:
	var result:Dictionary={}
	for owner:RefCounted in owners:
		var live:Dictionary=gate._target_current(owner)
		if not live.is_empty():result[owner._token.source_id]=live.position
	return result
func context_callback()->Dictionary:
	var value:Dictionary=saved_context.call()
	if retire_during_context:gate.dispose()
	return value
func impact_callback(receipt:Dictionary)->void:
	var flight:RefCounted=w.rpg_effects._flight
	var before:=state();var targets:=positions();var context:Dictionary=saved_context.call()
	var row:Dictionary={"receipt":receipt.duplicate(true),"before":before,"targets":targets,"context":context,"flight_busy":flight._busy,"retired_before_callback":gate._slot(receipt.token).is_empty(),"impacts_before":w.rpg_effects._impacts}
	# Forward the unchanged receipt ONCE into the existing authentic effect/gate callback.
	saved_impact.call(receipt)
	row.after=state();row.gate_result=gate.last_result.duplicate(true);row.impacts_after=w.rpg_effects._impacts
	impacts.append(row)
func shot_callback(shot:Dictionary,muzzle:Dictionary,origin:Vector3,direction:Vector3)->void:
	var flight:Dictionary=w.rpg_effects._flight.snapshot()
	var row:Dictionary={}
	for active:Dictionary in flight.rows:
		if active.shot_id==shot.shotId:row=active.duplicate(true);break
	var hit:Dictionary=w._projectile_ray({"origin":origin,"direction":direction,"range":100.0})
	var target:Vector3=hit.get("point",origin+direction*100.0)
	var expected:Vector3=(target-muzzle.origin).normalized()
	var projectile:Dictionary=shot.projectiles[0]
	expected=expected.rotated(Vector3.UP,float(projectile.yawOffset))
	var right:=expected.cross(Vector3.UP)
	if right.length_squared()>1e-8:expected=expected.rotated(right.normalized(),float(projectile.pitchOffset))
	shots.append({"shot":shot.duplicate(true),"muzzle":muzzle.duplicate(true),"flight":row,"expected_direction":expected.normalized(),"ammo":w.fire_state.duplicate(true),"real_velocity":p.get_real_velocity()})
	check(not row.is_empty(),"actual accepted shot already owns one native Flight slot")
	if not row.is_empty():
		check(row.item_uid==w.inventory.get_item_uid("rpg"),"flight binds actual inventory UID")
		check(row.direction.distance_to(expected.normalized())<.00001,"source-generated yaw/pitch spread applied exactly once")
		if cancel_token:check(w.rpg_effects._flight.retire_token(row.token),"actual accepted slot canceled by exact live token")
func mouse(down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=root.get_visible_rect().get_center();e.global_position=e.position
	Input.parse_input_event(e);Input.flush_buffered_events();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func key(code:int)->void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func ray(a:Vector3,b:Vector3,mask:int=5)->Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(a,b,mask,[p.get_rid()])
	return scene.get_world_3d().direct_space_state.intersect_ray(query)
func choose_fixture()->bool:
	var center:=Vector3.ZERO
	for owner:RefCounted in owners:center+=owner._token.body.global_position
	center/=owners.size()
	var floor_hit:=ray(center+Vector3.UP*3,center-Vector3.UP*6,1)
	if floor_hit.is_empty():return false
	aim_point=floor_hit.position
	var approaches:Array[Vector3]=[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
	if case_name=="wall":
		var found:Dictionary={}
		for dir:Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3(1,0,1).normalized(),Vector3(-1,0,1).normalized()]:
			var hit:=ray(center+Vector3.UP*1.2,center+Vector3.UP*1.2+dir*24)
			if not hit.is_empty() and absf(hit.normal.y)<.2:
				if found.is_empty() or hit.position.distance_to(center)<found.position.distance_to(center):found=hit
		if found.is_empty():return false
		aim_point=found.position;approaches=[found.normal]
	for dir:Vector3 in approaches:
		var proposed:=aim_point+dir*7
		var ground:=ray(Vector3(proposed.x,center.y+4,proposed.z),Vector3(proposed.x,center.y-6,proposed.z),1)
		if ground.is_empty():continue
		proposed=ground.position+Vector3.UP*.01
		var toward:=ray(proposed+Vector3.UP*2.2,aim_point)
		if not toward.is_empty() and toward.position.distance_to(aim_point)>.25:continue
		p.global_position=proposed
		if case_name=="range_end":aim_point=proposed+Vector3(.01,100,0)
		var look:Vector3=aim_point-proposed;p._camera_yaw=atan2(-look.x,-look.z);p._update_camera_rotation()
		return true
	return false
func verify_impact(row:Dictionary)->void:
	var receipt:Dictionary=row.receipt
	check(row.flight_busy and row.retired_before_callback,"authentic impact invoked while Flight busy AFTER retirement")
	check(row.impacts_after==row.impacts_before+1,"one original explosion for one native terminal receipt")
	check(receipt.native_rpg_impact and receipt.damage==160,"native source RPG terminal contract")
	check(receipt.range_end==(case_name=="range_end"),"requested native impact/range-end branch")
	if receipt.range_end:check(absf(receipt.distance_world-61.5)<.00001,"real61.5m range retirement")
	else:
		check(receipt.hit.hit and is_instance_valid(receipt.hit.collider),"actual native physics collider")
		check(receipt.hit.collider.get_world_3d()==scene.get_world_3d(),"actual hit belongs to loaded main physics world")
		check(receipt.hit.collider is StaticBody3D,"floor/wall hit is original static world geometry, not an NPC/car proxy")
		check(absf(receipt.normal.y)>.75 if case_name!="wall" else absf(receipt.normal.y)<.25,"actual floor/wall surface normal")
	var admitted:Dictionary=row.gate_result
	check(admitted.get("ok",false),"native gate accepted actual ammo/Flight impact")
	var expected_hits:=0
	for id:String in row.targets:
		var point:Vector3=row.targets[id];var distance:=Vector2(point.x-receipt.point.x,point.z-receipt.point.z).length()/4.1
		if distance>2.7:continue
		expected_hits+=1
		var base:=maxi(8,int(floor(160*(1-.72*distance/2.7)+.5)))
		var context:Dictionary=row.context
		var expected:=maxi(1,int(floor(base*(1+.05*clampf(context.marksman,0,5))*(context.critical_multiplier if context.critical else 1.0)+.5)))
		var matched:Dictionary={}
		for hit:Dictionary in admitted.get("hits",[]):
			if hit.source_id==id:matched=hit;break
		check(not matched.is_empty(),"original radius member receives real per-owner call "+id)
		if matched.is_empty():continue
		check(matched.damage==expected,"source two-stage rounded radial/critical damage "+id)
		check(matched.result.get("ok",false),"original HP owner accepted native blast "+id)
		check(row.after[id].hp<row.before[id].hp,"actual original HP decreases "+id)
		check(row.after[id].bodies==row.before[id].bodies and row.after[id].joints==row.before[id].joints,"same16original bodies/15joints retained "+id)
		if row.after[id].hp<=1:
			check(row.after[id].mode=="ACTIVE","lethal/medical blast activates original ragdoll "+id)
			check(row.after[id].eyes_closed==row.after[id].final_dead,"eyes follow actual final-death policy "+id)
	check(expected_hits>0 and admitted.get("hits",[]).size()==expected_hits,"all and only actual in-radius original NPC recipients")
	var current:=state();var effect_impacts:int=w.rpg_effects._impacts
	check(not gate.native_impact(w.rpg_effects,receipt).get("ok",false),"replay of genuine retired receipt denied")
	var forged:Dictionary=receipt.duplicate(true);forged.point+=Vector3.RIGHT
	check(not gate.native_impact(w.rpg_effects,forged).get("ok",false),"copied modified receipt denied outside callback")
	for owner:RefCounted in owners:check(not gate.take_target(owner,RefCounted.new()).get("ok",false),"unissued opaque target ticket denied")
	check(state()==current and w.rpg_effects._impacts==effect_impacts,"replay/forgery causes no additional HP/physical/explosion")
func finish()->void:
	if done:return
	done=true;tracked=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(p):
		for action in [p.ACTION_FORWARD,p.ACTION_BACK,p.ACTION_LEFT,p.ACTION_RIGHT,p.ACTION_RUN]:Input.action_release(action)
	report.case=case_name;report.shots=shots;report.impacts=impacts;report.cosmetic=cosmetic;report.seconds=(Time.get_ticks_msec()-started)/1000.0;report.valid=report.errors.is_empty()
	if not out.is_empty():FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RPG_ACTUAL_MAIN_RESULT ",JSON.stringify({"case":case_name,"checks":report.checks,"errors":report.errors,"seconds":report.seconds}))
	cleanup.call_deferred()
func cleanup()->void:
	if is_instance_valid(scene):scene.free()
	await process_frame
	quit(0 if report.valid else 2)
func run()->void:
	if not out.is_absolute_path():quit(3);return
	DirAccess.make_dir_recursive_absolute(out)
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 600:
		await sync()
		if done:return
		if scene.preview_ready and scene.preview_population!=null and scene.preview_population.hit_owners.size()==3:break
	check(scene.preview_ready and scene.preview_population.hit_owners.size()==3,"actual full main3 original NPC ready")
	if not scene.preview_ready or scene.preview_population.hit_owners.size()!=3:finish();return
	p=scene._player;w=scene.preview_weapons;owners=scene.preview_population.hit_owners.duplicate();gate=w.get("npc_rpg_gate")
	check(gate!=null and gate._live(),"production native RPG gate bound to current3owners")
	if gate==null or not gate._live():finish();return
	check(scene._block.counts.buildings==8,"original8buildings retained")
	report.original_collision_count=scene.find_children("*","CollisionObject3D",true,false).size()
	check(report.original_collision_count==377,"original377collision bodies retained")
	await sync(60)
	if done:return
	camera=p.get_preview_camera();camera.reparent(scene,true);tracked=true;p._free_mouse_look=true
	check(w.equip("rpg").get("ok",false),"real inventory equips RPG")
	check(choose_fixture(),"existing main floor/wall aim fixture without added collider")
	if not report.errors.is_empty():finish();return
	await sync(20)
	if done:return
	report.initial=state();report.aim_fixture={"player":p.global_position,"target":aim_point,"camera":camera.global_transform}
	saved_impact=w.rpg_effects._flight._impact_port;w.rpg_effects._flight._impact_port=Callable(self,"impact_callback")
	saved_context=gate._damage_context
	retire_during_context=case_name=="context_dispose"
	if retire_during_context:gate._damage_context=Callable(self,"context_callback")
	cancel_token=case_name=="cancel"
	w.shot_emitted.connect(shot_callback)
	w.rpg_effects.cosmetic_impact.connect(func(hit:Dictionary):cosmetic.append(hit.duplicate(true)))
	if case_name=="spread":Input.action_press(p.ACTION_RIGHT);Input.action_press(p.ACTION_RUN);await sync(10)
	if done:return
	var before_ammo:Dictionary=w.inventory.get_fire_state("rpg").duplicate(true);var before_shots:int=w.shots_count
	mouse(true);await sync(2);mouse(false)
	if done:return
	Input.action_release(p.ACTION_RIGHT);Input.action_release(p.ACTION_RUN)
	for i in 100:
		await sync()
		if done:return
		if w.rpg_effects._flight._active==0 and shots.size()==1:break
	check(shots.size()==1 and w.shots_count==before_shots+1,"one actual LMB source launch")
	check(w.fire_state.magazine==before_ammo.magazine-1 and w.fire_state.reserveAmmo==before_ammo.reserveAmmo,"one actual round spent, finite reserve unchanged")
	check(w.rpg_effects._flight._active==0,"native projectile retired")
	if case_name=="spread" and not shots.is_empty():check(absf(shots[0].shot.projectiles[0].yawOffset)+absf(shots[0].shot.projectiles[0].pitchOffset)>.00001,"actual running source handling generated nonzero launch offsets")
	if cancel_token:
		check(impacts.is_empty() and cosmetic.is_empty() and state()==report.initial,"exact-token cancel causes no native impact or NPC mutation")
	elif retire_during_context:
		check(impacts.size()==1 and gate._disposed,"actual impact current-context callback disposed gate")
		check(state()==report.initial and gate._targets.is_empty(),"callback disposal leaves original HP/physical state unchanged and no tickets")
	else:
		check(impacts.size()==1,"one native terminal callback from actual Flight")
		if impacts.size()==1:verify_impact(impacts[0])
	var reserve_before:int=w.fire_state.reserveAmmo
	key(KEY_R);await sync(120)
	if done:return
	check(w.fire_state.magazine==1 and w.fire_state.reserveAmmo==reserve_before-1,"actual R reload restores1round from finite source reserve")
	report.final=state();report.effects=w.rpg_effects.stats()
	finish()
