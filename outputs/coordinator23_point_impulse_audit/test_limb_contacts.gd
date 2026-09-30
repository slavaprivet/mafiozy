extends "frozen/point_base.gd"
const UniformOwner=preload("frozen/uniform_owner.gd")
var limb_rows:Array=[]
var active_physical:RefCounted
var metrics:Dictionary={}
func closest_segment(physical:RefCounted,point:Vector3,frames:Dictionary)->Dictionary:
	var best:=INF;var selected:="";var lever:=Vector3.ZERO
	for name:String in physical._body.BODY_NAMES:
		var transform:Transform3D=frames[name]*physical._body._bone_to_body[name]
		var dims:Dictionary=physical._body._dimensions[name]
		var half:=maxf(0,float(dims.height)*.5-float(dims.radius))
		var local:Vector3=transform.affine_inverse()*point
		var distance:=maxf(0,local.distance_to(Vector3(0,clampf(local.y,-half,half),0))-float(dims.radius))
		if distance<best:best=distance;selected=name;lever=point-transform.origin
	return {"bone":selected,"distance":best,"lever":lever}
func find_contact(owner:RefCounted,wanted:String)->Dictionary:
	var body:CharacterBody3D=owner._token.body
	var physical:RefCounted=host._ragdolls[owner._token.source_id]
	var frames:Dictionary=physical._body.capture_world_frames()
	var best:Dictionary={};var score:=-INF;var best_gap:=INF
	for height_index in range(1,43):
		var target:Vector3=body.global_position+Vector3.UP*(float(height_index)*.04)
		for angle_index in 24:
			var angle:=TAU*float(angle_index)/24
			var direction:=Vector3(cos(angle),0,sin(angle))
			var origin:Vector3=target-direction*1.2
			var hit:Dictionary=weapons._projectile_ray({"origin":origin,"direction":direction,"range":2.4})
			if hit.is_empty() or hit.collider!=body:continue
			var nearest:=closest_segment(physical,hit.point,frames)
			if nearest.bone!=wanted or nearest.distance>.75:continue
			var torque_lever:float=nearest.lever.cross(direction).length()
			if nearest.distance<best_gap-.000001 or (absf(nearest.distance-best_gap)<=.000001 and torque_lever>score):
				best_gap=nearest.distance;score=torque_lever;best={"origin":origin,"target":target,"direction":direction,"point":hit.point,"preflight_bone":nearest.bone,"preflight_distance_m":nearest.distance,"lever_m":nearest.lever,"lever_per_ns":score}
	return best
func tick(n:int)->void:
	for i in n:
		await physics_frame;weapons.effects.advance(1.0/60.0);host.step(1.0/60.0)
		if active_physical!=null and active_physical.mode=="ACTIVE":
			var snap:Dictionary=active_physical._body.snapshot()
			metrics.joint=maxf(metrics.joint,snap.max_joint_anchor_error_m)
			metrics.distance=maxf(metrics.distance,Vector2(snap.anchor_world.x-metrics.start.x,snap.anchor_world.z-metrics.start.z).length())
			for rb:RigidBody3D in active_physical.owned_bodies():
				check(rb.linear_velocity.is_finite() and rb.angular_velocity.is_finite(),"finite native limb velocities")
				metrics.linear=maxf(metrics.linear,rb.linear_velocity.length());metrics.angular=maxf(metrics.angular,rb.angular_velocity.length())
				var capsule:CapsuleShape3D=rb.get_child(0).shape
				var off:Vector3=rb.global_basis.y*(capsule.height*.5-capsule.radius)
				metrics.floor=minf(metrics.floor,minf((rb.global_position-off).y,(rb.global_position+off).y)-capsule.radius)
		await process_frame
func limb_case(index:int,limb:String,candidate:bool)->void:
	owner_script=HitOwner if candidate else UniformOwner
	await setup_actors()
	var owner:RefCounted=hit_owners[index]
	var contact:=find_contact(owner,limb)
	if contact.is_empty() or float(contact.preflight_distance_m)>.00001:
		limb_rows.append({"actor":owner._token.source_id,"requested":limb,"candidate":candidate,"reachable":false,"reason":"no sampled real standing-capsule contact lies on requested segment capsule within1e-5m","nearest_observed":contact})
		await cleanup_actors();return
	var rng:=RandomNumberGenerator.new()
	for seed_value in 200:
		rng.seed=seed_value
		if rng.randf()>=.12 and rng.randf()>=.72:owner._rng.seed=seed_value;break
	active_physical=host._ragdolls[owner._token.source_id]
	metrics={"joint":0.0,"floor":INF,"linear":0.0,"angular":0.0,"distance":0.0,"start":owner._token.body.global_position}
	var shot:=shot_for("deagle")
	check(weapons.effects.shoot(shot,{"origin":contact.origin},contact.target),"real native limb shot")
	weapons.shot_emitted.emit(shot,{"origin":contact.origin},contact.origin,contact.direction)
	await tick(180)
	check(owner.last_result.get("reason")=="final_death" and active_physical.mode=="ACTIVE","native limb final transaction")
	var impulse:Dictionary=owner.last_impulse.duplicate(true)
	check(owner.last_contact.point.distance_to(contact.point)<.0001,"accepted native point equals actual preflight ray")
	if candidate:
		check(impulse.get("point_result",{}).get("ok",false) and impulse.point_result.bone==limb and impulse.point_result.distance_m<=.00001,"actual native contact is inside requested original segment capsule")
		check(impulse.point_ns.length()<=2.501 and (impulse.point_ns+impulse.uniform_ns).distance_to(impulse.requested_total_ns)<.00001,"limb share bounded and total preserved")
		for receipt:Dictionary in hits:
			if receipt.shotId==shot.shotId:owner._on_native_impact(receipt)
		check(owner.last_impulse==impulse and owner._point_consumed.size()==1,"limb exact event once")
	check(metrics.joint<.20,"unchanged native joint bound")
	check(metrics.linear<80 and metrics.angular<30,"limb response remains within existing start velocity ceilings")
	limb_rows.append({"actor":owner._token.source_id,"requested":limb,"candidate":candidate,"reachable":true,"contact":contact,"impulse":impulse,"metrics":metrics.duplicate(true)})
	active_physical=null;await cleanup_actors()
func run()->void:
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_transport_enabled=true;scene.preview_start_at_vehicle=false;scene.preview_residents_enabled=false;root.add_child(scene)
	await physics_frame;await physics_frame
	check(scene.preview_ready,"candidate05 actual scene")
	if is_instance_valid(scene.preview_transport):scene.preview_transport.body.collision_layer=0;scene.preview_transport.body.collision_mask=0
	weapons=scene.preview_weapons;weapons.set_physics_process(false);weapons.effects.dispose();weapons.effects=Effects.new();weapons.player.set_physics_process(false)
	check(weapons.effects.configure(scene,Callable(weapons,"_projectile_ray")).ok,"real native producer")
	weapons.effects.projectile_resolved.connect(record_terminal);weapons.effects.cosmetic_impact.connect(record_hit)
	packet=FileAccess.get_file_as_bytes(DIR+PACKET+".json");parsed=JSON.parse_string(packet.get_string_from_utf8());var sources:={}
	for row:Dictionary in parsed.source_receipts:sources[row.path]=row.sha256
	trust={"accepted":true,"packet_sha256":PACKET,"sources":sources,"session_id":parsed.session_id,"prepared_sha256":MANIFEST,"block_sha256":BLOCK}
	for candidate:bool in [false,true]:
		for index in 3:
			for limb:String in ["hand_l","hand_r","forearm_l","forearm_r","foot_l","foot_r"]:await limb_case(index,limb,candidate)
	weapons.effects.dispose();scene.queue_free();await process_frame
	print("LIMB_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"rows":limb_rows,"scope":"actual candidate05 native capsule contacts mapped to outgoing original segments; exact frozen e4ec vs uniform control; no collider/HP edits, no GPU"}))
	quit(0 if errors.is_empty() else 1)
