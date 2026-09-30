extends "native_base_pinned.gd"
var rows:Array=[]
func run()->void:
	var expect_old:=OS.get_cmdline_user_args().has("--expect-old-slide")
	scene=load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled=true;scene.preview_start_at_vehicle=false;scene.preview_residents_enabled=false
	root.add_child(scene);await physics_frame;await physics_frame
	check(scene.preview_ready,"actual main ready")
	if is_instance_valid(scene.preview_transport):scene.preview_transport.body.collision_layer=0;scene.preview_transport.body.collision_mask=0
	weapons=scene.preview_weapons;check(is_instance_valid(weapons),"weapon host ready")
	if not is_instance_valid(weapons):finish();return
	weapons.set_physics_process(false);weapons.player.set_physics_process(false)
	weapons.effects.dispose();weapons.effects=Effects.new()
	check(weapons.effects.configure(scene,Callable(weapons,"_projectile_ray")).ok,"native projectiles")
	weapons.effects.projectile_resolved.connect(record_terminal);weapons.effects.cosmetic_impact.connect(record_hit)
	packet=FileAccess.get_file_as_bytes(DIR+PACKET+".json");parsed=JSON.parse_string(packet.get_string_from_utf8())
	var sources:={}
	for row:Dictionary in parsed.source_receipts:sources[row.path]=row.sha256
	trust={"accepted":true,"packet_sha256":PACKET,"sources":sources,"session_id":parsed.session_id,"prepared_sha256":MANIFEST,"block_sha256":BLOCK}
	for index in 3:
		await setup_actors()
		var owner:RefCounted=hit_owners[index]
		var rng:=RandomNumberGenerator.new()
		for seed_value in 200:
			rng.seed=seed_value
			if rng.randf()>=.12:owner._rng.seed=seed_value;break
		var body:CharacterBody3D=owner._token.body
		var before:Vector3=body.global_position
		var target:=before+Vector3.UP*1.1;var origin:=target+Vector3.RIGHT*.8
		var shot:Dictionary=shot_for("tt_pistol")
		check(weapons.effects.shoot(shot,{"origin":origin},target),"real TT projectile admitted")
		weapons.shot_emitted.emit(shot,{"origin":origin},origin,(target-origin).normalized())
		var peak:=0.0
		for tick in 60:
			await physics_frame
			weapons.effects.advance(1.0/60.0)
			# Read the STANDING CharacterBody, even while ragdoll mode is IDLE.
			peak=maxf(peak,Vector2(body.global_position.x-before.x,body.global_position.z-before.z).length())
			host.step(1.0/60.0)
		check(owner.last_result.get("reason")=="hit" and owner._row.hp==30,"accepted nonlethal HP30")
		check(host._ragdolls[owner._token.source_id].mode=="IDLE","survivor remains standing")
		check(absf(peak-.369)<.001 if expect_old else peak<.0001,"expected measured standing displacement")
		var recorded:Dictionary={}
		if not expect_old:
			recorded=owner.last_source_path_request
			check(not recorded.is_empty(),"source path request retained")
		rows.append({"source_id":owner._token.source_id,"standing_capsule_peak_m":peak,"hp":owner._row.hp,"physical":"IDLE","source_path_request":recorded})
		await cleanup_actors()
	finish()
func finish()->void:
	print("NO_SLIDE_STANDING ",JSON.stringify({"checks":checks,"errors":errors,"rows":rows,"scope":"actual native TT hit and standing capsule displacement; deterministic source RNG, isolated native corridor; headless only"}))
	if is_instance_valid(weapons):weapons.effects.dispose()
	if is_instance_valid(scene):scene.queue_free()
	await process_frame;quit(0 if errors.is_empty() else 1)
