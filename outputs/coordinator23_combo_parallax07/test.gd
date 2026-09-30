extends "base.gd"
var rows:Array=[]
func tick(n:int)->void:
	for i in n:
		await physics_frame
		weapons.effects.advance(1.0/60.0)
		host.step(1.0/60.0)
		await process_frame
func case_run(index:int,corrected:bool)->void:
	owner_script=HitOwner
	await setup_actors()
	var owner:RefCounted=hit_owners[index]
	var rng:=RandomNumberGenerator.new()
	for seed_value in 200:
		rng.seed=seed_value
		if rng.randf()>=.12 and rng.randf()>=.72:owner._rng.seed=seed_value;break
	var body:CharacterBody3D=owner._token.body
	var target:Vector3=body.global_position+Vector3.UP*1.1
	var muzzle:Vector3=target+Vector3.RIGHT*.8
	# Same .75m lateral separation as source aim shoulder: camera and muzzle
	# target the same collider but have different near-range ray directions.
	var camera_origin:Vector3=muzzle+Vector3.BACK*.75
	var camera_direction:Vector3=(target-camera_origin).normalized()
	var shot:Dictionary=shot_for("shotgun")
	check(weapons.effects.shoot(shot,{"origin":muzzle},target),"native parallax source launch")
	weapons.shot_emitted.emit(shot,{"origin":muzzle},camera_origin,camera_direction)
	await tick(60)
	var accepted:Dictionary={}
	var terminal_count:=0
	for terminal:Dictionary in terminals:
		if terminal.shotId!=shot.shotId:continue
		terminal_count+=1
		if accepted.is_empty() and terminal.status=="hit" and terminal.collider==body:accepted=terminal
	check(terminal_count==7 and not accepted.is_empty(),"all real pellet terminals, real owned first contact")
	check(owner.last_result.get("reason")=="final_death","same actual completed final HP transaction")
	var impulse:Dictionary=owner.last_impulse.duplicate(true)
	check(impulse.get("point_result",{}).get("ok",false),"point impulse applied at native contact")
	var physical_direction:Vector3=Vector3(accepted.direction.x,0,accepted.direction.z).normalized()
	var actual_direction:Vector3=impulse.impulse_ns.normalized()
	var error_degrees:=rad_to_deg(actual_direction.angle_to(physical_direction))
	check(error_degrees<.01 if corrected else error_degrees>20,"corrected physical ray / original reproducible parallax mismatch")
	check(impulse.point==accepted.point,"point paired with same accepted terminal")
	check((impulse.uniform_ns+impulse.point_ns).distance_to(impulse.requested_total_ns)<.00001 and impulse.point_ns.length()<=2.501,"no extra total J or limb budget increase")
	check(owner.last_contact.get("incoming_direction",Vector3.ZERO).distance_to(accepted.direction.normalized())<.000001,"wound ray paired with the exact same accepted terminal")
	check(owner.last_contact.point==accepted.point and owner.last_contact.normal==accepted.normal,"wound point normal direction remain one terminal tuple")
	check(owner._serial==1 and owner._row.hp==0,"one completed source HP transaction per target")
	check(owner.blood._last_revision==owner.last_result.revision and owner.blood.renderer.emitted==20,"one source-normal blood burst per completed transaction")
	check(owner.marks._last_revision==owner.last_result.revision and owner.marks.renderer._marks.size()==1,"one genuine original-surface persistent mark")
	var mark_hash:String=JSON.stringify(owner.marks.renderer._marks).sha256_text()
	var blood_count:int=owner.blood.renderer.emitted
	var before_result:Dictionary=owner.last_result.duplicate(true)
	for terminal:Dictionary in terminals:
		if terminal.shotId==shot.shotId:owner._on_projectile_resolved(terminal)
	check(owner.last_impulse==impulse and owner._point_consumed.size()==1,"replay cannot duplicate point impulse")
	check(owner._serial==1 and owner.last_result==before_result and owner._row.hp==0,"terminal replay cannot repeat HP")
	check(owner.blood.renderer.emitted==blood_count and not owner.blood.receive(owner.last_contact.event_id,accepted.point,accepted.normal),"replay cannot duplicate admitted blood")
	check(JSON.stringify(owner.marks.renderer._marks).sha256_text()==mark_hash and not owner.marks.receive(owner.last_contact.event_id,accepted.point,accepted.normal),"replay cannot duplicate or alter persistent wound")

	rows.append({"actor":owner._token.source_id,"corrected":corrected,"wound_direction":owner.last_contact.incoming_direction,"marks":owner.marks.renderer._marks.size(),"mark_hash":mark_hash,"blood_particles":blood_count,"hp_commits":owner._serial,"degrees_from_actual_terminal":error_degrees,"camera_direction":camera_direction,"terminal_direction":accepted.direction,"physical_direction":actual_direction,"point":accepted.point,"selected_bone":impulse.point_result.bone,"total_ns":impulse.impulse_ns.length(),"point_ns":impulse.point_ns.length(),"hp":owner._row.hp,"reason":owner.last_result.reason})
	await cleanup_actors()
func run()->void:
	create_timer(35).timeout.connect(func(): print("FAIL bounded timeout"); quit(2))
	scene=load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled=true;scene.preview_start_at_vehicle=false;scene.preview_residents_enabled=false;root.add_child(scene)
	await physics_frame;await physics_frame
	check(scene.preview_ready,"actual candidate07 main")
	if is_instance_valid(scene.preview_transport):scene.preview_transport.body.collision_layer=0;scene.preview_transport.body.collision_mask=0
	weapons=scene.preview_weapons;weapons.set_physics_process(false);weapons.effects.dispose();weapons.effects=Effects.new();weapons.player.set_physics_process(false)
	check(weapons.effects.configure(scene,Callable(weapons,"_projectile_ray")).ok,"actual native projectile producer")
	weapons.effects.projectile_resolved.connect(record_terminal);weapons.effects.cosmetic_impact.connect(record_hit)
	packet=FileAccess.get_file_as_bytes(DIR+PACKET+".json");parsed=JSON.parse_string(packet.get_string_from_utf8())
	var sources:={}
	for row:Dictionary in parsed.source_receipts:sources[row.path]=row.sha256
	trust={"accepted":true,"packet_sha256":PACKET,"sources":sources,"session_id":parsed.session_id,"prepared_sha256":MANIFEST,"block_sha256":BLOCK}
	for corrected:bool in [true]:
		for index in 3:await case_run(index,corrected)
	weapons.effects.dispose();scene.queue_free();await process_frame
	print("POINT_PARALLAX_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"rows":rows,"owner_sha256":FileAccess.get_sha256("res://scripts/npc_visual/npc_local_preview_hit_owner.gd"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"actual candidate07 main native source fire/ammo and ray; isolated .75m camera/muzzle fixture; no UI/GPU"}))
	quit(0 if errors.is_empty() else 1)
