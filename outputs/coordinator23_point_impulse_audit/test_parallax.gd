extends "../artist23_hit_impulse/ready_base.gd"
const MergedOwner=preload("merged_owner.gd")
const CorrectedOwner=preload("corrected_owner.gd")
var rows:Array=[]
func tick(n:int)->void:
	for i in n:
		await physics_frame
		weapons.effects.advance(1.0/60.0)
		host.step(1.0/60.0)
		await process_frame
func case_run(index:int,corrected:bool)->void:
	owner_script=CorrectedOwner if corrected else MergedOwner
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
	for terminal:Dictionary in terminals:
		if terminal.shotId==shot.shotId:owner._on_projectile_resolved(terminal)
	check(owner.last_impulse==impulse and owner._point_consumed.size()==1,"replay cannot duplicate point impulse")
	rows.append({"actor":owner._token.source_id,"corrected":corrected,"degrees_from_actual_terminal":error_degrees,"camera_direction":camera_direction,"terminal_direction":accepted.direction,"physical_direction":actual_direction,"point":accepted.point,"selected_bone":impulse.point_result.bone,"total_ns":impulse.impulse_ns.length(),"point_ns":impulse.point_ns.length(),"hp":owner._row.hp,"reason":owner.last_result.reason})
	await cleanup_actors()
func run()->void:
	scene=load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled=true;scene.preview_start_at_vehicle=false;scene.preview_residents_enabled=false;root.add_child(scene)
	await physics_frame;await physics_frame
	check(scene.preview_ready,"actual candidate05 main")
	if is_instance_valid(scene.preview_transport):scene.preview_transport.body.collision_layer=0;scene.preview_transport.body.collision_mask=0
	weapons=scene.preview_weapons;weapons.set_physics_process(false);weapons.effects.dispose();weapons.effects=Effects.new();weapons.player.set_physics_process(false)
	check(weapons.effects.configure(scene,Callable(weapons,"_projectile_ray")).ok,"actual native projectile producer")
	weapons.effects.projectile_resolved.connect(record_terminal);weapons.effects.cosmetic_impact.connect(record_hit)
	packet=FileAccess.get_file_as_bytes(DIR+PACKET+".json");parsed=JSON.parse_string(packet.get_string_from_utf8())
	var sources:={}
	for row:Dictionary in parsed.source_receipts:sources[row.path]=row.sha256
	trust={"accepted":true,"packet_sha256":PACKET,"sources":sources,"session_id":parsed.session_id,"prepared_sha256":MANIFEST,"block_sha256":BLOCK}
	for corrected:bool in [false,true]:
		for index in 3:await case_run(index,corrected)
	weapons.effects.dispose();scene.queue_free();await process_frame
	print("POINT_PARALLAX_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"rows":rows,"scope":"actual candidate05 main native source fire/ammo and ray; isolated .75m camera/muzzle fixture; no UI/GPU"}))
	quit(0 if errors.is_empty() else 1)
