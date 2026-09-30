extends "point_native_base.gd"
const UniformOwner=preload("uniform_owner.gd")
var point_rows: Array=[]
var point_samples: Array=[]
var point_ticks:=0
var point_owner: RefCounted
func advance_physics(n: int) -> void:
	for i in n:
		await physics_frame;weapons.effects.advance(1.0/60.0);host.step(1.0/60.0)
		if tracked!=null and tracked.mode=="ACTIVE":
			point_ticks+=1
			var p: Dictionary=tracked._body.snapshot()
			tracked_metrics.distance=maxf(tracked_metrics.distance,Vector2(p.anchor_world.x-tracked_metrics.start.x,p.anchor_world.z-tracked_metrics.start.z).length())
			tracked_metrics.joint=maxf(tracked_metrics.joint,p.max_joint_anchor_error_m)
			var sample: Dictionary={"tick":point_ticks,"segments":{}}
			for name: String in tracked._body._bodies:
				var rb: RigidBody3D=tracked._body._bodies[name]
				var cap: CapsuleShape3D=rb.get_child(0).shape;var off:=rb.global_basis.y*(cap.height*.5-cap.radius)
				tracked_metrics.floor=minf(tracked_metrics.floor,minf((rb.global_position-off).y,(rb.global_position+off).y)-cap.radius)
				if point_ticks in [1,2,3,6,10,30]:
					var a:=rb.angular_velocity;var q:=rb.global_basis.get_rotation_quaternion()
					sample.segments[name]={"angular":[a.x,a.y,a.z],"rotation":[q.x,q.y,q.z,q.w]}
			if point_ticks in [1,2,3,6,10,30]:point_samples.append(sample)
		await process_frame

func point_case(index: int,height: float,direction: Vector3,medical: bool,candidate: bool) -> void:
	await setup_actors()
	var owner: RefCounted=hit_owners[index]
	var physical: RefCounted=host._ragdolls[owner._token.source_id]
	var rng:=RandomNumberGenerator.new()
	for seed_value in 200:
		rng.seed=seed_value
		if rng.randf()>=.12 and (rng.randf()<.72 if medical else rng.randf()>=.72):owner._rng.seed=seed_value;break
	var body: CharacterBody3D=owner._token.body
	var target:=body.global_position+Vector3.UP*height
	var origin:=target-direction*.8
	tracked=physical;tracked_metrics={"start":body.global_position,"distance":0.0,"joint":0.0,"floor":INF}
	point_samples=[];point_ticks=0;point_owner=owner
	var shot:=shot_for("shotgun")
	check(weapons.effects.shoot(shot,{"origin":origin},target),"real point shot")
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,direction)
	await advance_physics(60)
	check(physical.mode=="ACTIVE" and physical.status().final_dead==(not medical),"point physical/HP state")
	var impulse: Dictionary=owner.last_impulse.duplicate(true)
	check(absf(impulse.impulse_ns.length()-(75 if medical else 225))<.01,"unchanged total impulse budget")
	if candidate:
		check(impulse.point_result.get("ok",false) and impulse.point_ns.length()>0 and impulse.point_ns.length()<=2.501,"native point applied bounded")
		check((impulse.uniform_ns+impulse.point_ns).distance_to(impulse.requested_total_ns)<.00001,"point share subtracted, no extra J")
		check(impulse.point==owner.last_contact.point and owner._point_consumed.size()==1,"actual native contact once")
		check(physical._body.apply_impulse(body.global_position+Vector3.UP*100,Vector3.RIGHT*2.5,"gap_negative").get("error")=="outside_body","point gap greater than .75m rejects native impulse")
	for terminal: Dictionary in terminals:
		if terminal.shotId==shot.shotId:owner._on_projectile_resolved(terminal)
	for hit: Dictionary in hits:
		if hit.shotId==shot.shotId:owner._on_native_impact(hit)
	check(owner.last_impulse==impulse,"native receipt replay cannot double point J")
	await advance_physics(180)
	check(tracked_metrics.joint<.20,"point joint bound")
	# First-frame baseline floor intrusion remains visible in report/comparison.
	point_rows.append({"actor":owner._token.source_id,"height":height,"direction":[direction.x,direction.y,direction.z],"medical":medical,"candidate":candidate,"hit_transaction_us":owner._last_hit_us,"impulse":impulse,"metrics":tracked_metrics.duplicate(true),"samples":point_samples.duplicate(true)})
	tracked=null;point_owner=null;await cleanup_actors()

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
	var directions: Array[Vector3]=[Vector3.LEFT]
	var extra:=OS.get_environment("NPC_POINT_DIRECTIONS")
	if extra=="remaining":directions=[Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]
	if extra=="all_head":directions=[Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]
	for candidate: bool in [false,true]:
		owner_script=HitOwner if candidate else UniformOwner
		for index in 3:
			for direction: Vector3 in directions:
				for height: float in ([1.1,1.7] if extra=="" else [1.7]):
					for medical: bool in [false,true]:await point_case(index,height,direction,medical,candidate)
	owner_script=HitOwner
	await native_case(0,"shotgun",.8,false,true)
	weapons.effects.dispose();scene.queue_free();await process_frame
	print("HIT_IMPULSE_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"rows":point_rows,"protected":measured,"scope":"actual native original3rig split point+uniform vs identical total uniform control; no LIVE"}))
	quit(0 if errors.is_empty() else 1)
