extends "head_base.gd"
const Impulse=preload("res://scripts/npc_visual/npc_hit_impulse.gd")
var measured: Array=[]
var impulse_enabled:=true
var tracked: RefCounted
var tracked_metrics: Dictionary={}
func advance_physics(n: int) -> void:
	for i in n:
		await physics_frame;weapons.effects.advance(1.0/60.0);host.step(1.0/60.0)
		if tracked!=null and tracked.mode=="ACTIVE":
			var p: Dictionary=tracked._body.snapshot()
			tracked_metrics.distance=maxf(tracked_metrics.distance,Vector2(p.anchor_world.x-tracked_metrics.start.x,p.anchor_world.z-tracked_metrics.start.z).length())
			tracked_metrics.joint=maxf(tracked_metrics.joint,p.max_joint_anchor_error_m)
			for rb: RigidBody3D in tracked.owned_bodies():
				var cap: CapsuleShape3D=rb.get_child(0).shape;var off:=rb.global_basis.y*(cap.height*.5-cap.radius)
				tracked_metrics.floor=minf(tracked_metrics.floor,minf((rb.global_position-off).y,(rb.global_position+off).y)-cap.radius)
		await process_frame
func fire_distance(owner: RefCounted,id: String,distance: float,lethal: bool) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	for seed_value in 200:
		rng.seed=seed_value
		if rng.randf()>=.12 and (rng.randf()>=.72 if lethal else rng.randf()<.72):owner._rng.seed=seed_value;break
	var body: CharacterBody3D=owner._token.body
	var target:=body.global_position+Vector3.UP*1.1
	var origin:=target+Vector3.RIGHT*distance
	var shot:=shot_for(id)
	check(weapons.effects.shoot(shot,{"origin":origin},target),"actual native shot "+id)
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,(target-origin).normalized())
	return shot
func native_case(index: int,id: String,distance: float,lethal: bool,protected: bool=false) -> void:
	await setup_actors()
	var owner: RefCounted=hit_owners[index]
	if protected:owner._row._invulnerable=true # explicit protected-role negative; real native ray still executes.
	var body: CharacterBody3D=owner._token.body
	var start: Vector3=body.global_position
	var floor_query:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*2,start-Vector3.UP*2,1,[body.get_rid()])
	var floor_hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(floor_query)
	check(not floor_hit.is_empty(),"native support ray at shot location")
	var support_y: float=floor_hit.position.y if not floor_hit.is_empty() else NAN
	var physical: RefCounted=host._ragdolls[owner._token.source_id]
	tracked=physical;tracked_metrics={"start":start,"distance":0.0,"joint":0.0,"floor":INF}
	var shot:=fire_distance(owner,id,distance,lethal)
	await advance_physics(60) # Allow every native pellet, including misses, to terminate.
	# At longer range actual shotgun spread can land fewer pellets. Repeated
	# real accepted source shots (not fixture HP writes) can reach medical down.
	if distance>1.5 and not protected:
		for attempt in 4:
			if physical.mode!="IDLE" or owner.last_result.is_empty():break
			shot=fire_distance(owner,id,distance,lethal)
			await advance_physics(60)
	var impulse: Vector3=owner.last_impulse.get("impulse_ns",Vector3.ZERO) if impulse_enabled else Vector3.ZERO
	if protected or id=="tt_pistol":
		check(impulse==Vector3.ZERO and physical.mode=="IDLE","protected/nonlethal cannot invent knockdown")
		if protected:check(owner._row.hp==60 and owner.last_result.get("reason")=="invulnerable","native invulnerable no HP or impulse")
	else:
		check(physical.mode=="ACTIVE" and (impulse.length()>0 if impulse_enabled else impulse==Vector3.ZERO),"accepted physical transition "+id+" "+str(owner.last_result))
		check(physical.status().final_dead==lethal,"medical vs final preserved")
	var first_impulse: Dictionary=owner.last_impulse.duplicate(true) if impulse_enabled else {}
	for receipt: Dictionary in terminals:
		if receipt.shotId==shot.shotId:owner._on_projectile_resolved(receipt)
	for hit: Dictionary in hits:
		if hit.shotId==shot.shotId:owner._on_native_impact(hit)
	if impulse_enabled:check(owner.last_impulse==first_impulse,"replayed native receipts no second impulse")
	var peak_distance:=0.0;var joint:=0.0;var floor_min:=INF
	for i in 180:
		await advance_physics(1)
		if physical.mode=="ACTIVE":
			var p: Dictionary=physical._body.snapshot()
			peak_distance=maxf(peak_distance,Vector2(p.anchor_world.x-start.x,p.anchor_world.z-start.z).length())
			joint=maxf(joint,p.max_joint_anchor_error_m)
			for rb: RigidBody3D in physical.owned_bodies():
				var cap: CapsuleShape3D=rb.get_child(0).shape;var off:=rb.global_basis.y*(cap.height*.5-cap.radius)
				floor_min=minf(floor_min,minf((rb.global_position-off).y,(rb.global_position+off).y)-cap.radius)
	peak_distance=maxf(peak_distance,tracked_metrics.distance);joint=maxf(joint,tracked_metrics.joint);floor_min=minf(floor_min,tracked_metrics.floor)
	check(joint<.20,"actual scene impulse joint bound")
	if not protected and id!="tt_pistol":check(peak_distance>.15,"actual body displacement measured")
	measured.append({"actor":owner._token.source_id,"weapon":id,"distance_m":distance,"lethal":lethal,"protected":protected,"impulse_ns":str(impulse),"magnitude_ns":impulse.length(),"peak_horizontal_distance_m":peak_distance,"peak_joint_m":joint,"native_support_y":support_y,"capsule_min_relative_support_m":floor_min-support_y if is_finite(floor_min) else null,"capsule_min_y":floor_min if is_finite(floor_min) else null,"result":owner.last_result.get("reason"),"physical":physical.mode,"hit_us":owner._last_hit_us})
	tracked=null;tracked_metrics={};await cleanup_actors()
func run() -> void:
	scene=load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled=true;scene.preview_start_at_vehicle=false;scene.preview_residents_enabled=false;root.add_child(scene)
	await physics_frame;await physics_frame
	check(scene.preview_ready,"frozen Root23c main loaded")
	# Identical isolated ray corridor to the parent's accepted native-hit matrix.
	if is_instance_valid(scene.preview_transport):scene.preview_transport.body.collision_layer=0;scene.preview_transport.body.collision_mask=0
	weapons=scene.preview_weapons;weapons.set_physics_process(false);weapons.effects.dispose();weapons.effects=Effects.new()
	weapons.player.set_physics_process(false) # This fixture is the sole effects.advance owner.
	check(weapons.effects.configure(scene,Callable(weapons,"_projectile_ray")).ok,"actual native producer")
	weapons.effects.projectile_resolved.connect(record_terminal);weapons.effects.cosmetic_impact.connect(record_hit)
	packet=FileAccess.get_file_as_bytes(DIR+PACKET+".json");parsed=JSON.parse_string(packet.get_string_from_utf8())
	var sources:={}
	for row: Dictionary in parsed.source_receipts:sources[row.path]=row.sha256
	trust={"accepted":true,"packet_sha256":PACKET,"sources":sources,"session_id":parsed.session_id,"prepared_sha256":MANIFEST,"block_sha256":BLOCK}
	for index in 3:
		if not impulse_enabled:
			await native_case(index,"shotgun",.8,false)
			continue
		for id: String in ["deagle","shotgun"]:
			await native_case(index,id,.8,false)
			await native_case(index,id,4.0,false)
		await native_case(index,"shotgun",.8,true)
	await native_case(0,"shotgun",.8,false,true)
	await native_case(0,"tt_pistol",.8,false)
	if impulse_enabled:await negative_cases()
	for id: String in Impulse.NEAR_NS:
		var a:=Impulse.bullet(id,.8,1000,Vector3.LEFT);var b:=Impulse.bullet(id,12,1000,Vector3.LEFT)
		check(a.ok and b.ok and a.impulse_ns.length()>b.impulse_ns.length(),"all-weapon near/far monotonic "+id)
	check(not Impulse.bullet("rpg",0,160,Vector3.LEFT).ok,"RPG must use separate native blast gate")
	check(not Impulse.bullet("shotgun",NAN,76,Vector3.LEFT).ok,"nonfinite no impulse")
	weapons.effects.dispose();scene.queue_free();await process_frame
	print("HIT_IMPULSE_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"rows":measured,"scope":"real native emitter/rays, original3rigs, existing HP lifecycle; fixture source shots/muzzles and survival RNG; not UI/LIVE"}))
	quit(0 if errors.is_empty() else 1)
