extends "head_native_base.gd"
var head_instrument_owner: RefCounted
var head_hit_path_us: Array[int]=[]
func place_arm_triangle(owner: RefCounted,center: Vector3,direction: Vector3) -> Dictionary:
	var rig: Skeleton3D=owner._token.rig
	for s: Dictionary in owner._head_zone._surfaces:
		var matrices: Array[Transform3D]=[]
		for b in s.names.size():matrices.append(rig.global_transform*rig.get_bone_global_pose(rig.find_bone(s.names[b]))*s.binds[b])
		for i in range(0,s.indices.size(),3):
			var points:=PackedVector3Array();var pure:=true
			for n in 3:
				var v: int=s.indices[i+n];var p:=Vector3.ZERO
				for k in 4:
					var j:=v*4+k
					if s.weights[j]<=0:continue
					if s.names[s.bones[j]]!="forearm_l":pure=false
					p+=matrices[s.bones[j]]*s.vertices[v]*s.weights[j]
				points.append(p)
			if not pure:continue
			var normal: Vector3=(points[1]-points[0]).cross(points[2]-points[0])
			if normal.length_squared()<1e-10 or absf(normal.normalized().dot(direction))<.2:continue
			var arm_index:=rig.find_bone("forearm_l")
			var arm_world: Transform3D=rig.global_transform*rig.get_bone_global_pose(arm_index)
			arm_world.origin+=(center-direction*.25)-(points[0]+points[1]+points[2])/3.0
			var desired: Transform3D=rig.global_transform.affine_inverse()*arm_world
			var parent_pose: Transform3D=rig.get_bone_global_pose(rig.get_bone_parent(arm_index))
			# set_bone_pose takes the complete parent-local pose in Godot 4.7.
			# The rest transform is already represented by that pose.
			rig.set_bone_pose(arm_index,parent_pose.affine_inverse()*desired)
			if rig.has_method("force_update_all_bone_transforms"):rig.call("force_update_all_bone_transforms")
			return {"surface":s,"indices":s.indices.slice(i,i+3),"target":center-direction*.25}
	return {}

func arm_triangle_witness(owner: RefCounted,record: Dictionary,origin: Vector3,direction: Vector3) -> Dictionary:
	if record.is_empty():return {}
	var rig: Skeleton3D=owner._token.rig;var s: Dictionary=record.surface
	var points:=PackedVector3Array()
	for v: int in record.indices:
		var p:=Vector3.ZERO
		for k in 4:
			var j:=v*4+k
			if s.weights[j]>0:p+=rig.global_transform*rig.get_bone_global_pose(rig.find_bone(s.names[s.bones[j]]))*s.binds[s.bones[j]]*s.vertices[v]*s.weights[j]
		points.append(p)
	var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,points[0],points[1],points[2])
	return {"hit":hit,"distance":origin.distance_to(hit) if hit is Vector3 else -1.0,"center_error":((points[0]+points[1]+points[2])/3.0).distance_to(record.target)}

func advance_physics(n: int) -> void:
	for i in n:
		await physics_frame
		var serial_before: int=head_instrument_owner._serial if head_instrument_owner!=null else -1
		var started:=Time.get_ticks_usec()
		weapons.effects.advance(1.0/60.0);host.step(1.0/60.0)
		if head_instrument_owner!=null and head_instrument_owner._serial>serial_before:head_hit_path_us.append(Time.get_ticks_usec()-started)
		if tracked!=null and tracked.mode=="ACTIVE":
			var p: Dictionary=tracked._body.snapshot()
			tracked_metrics.distance=maxf(tracked_metrics.distance,Vector2(p.anchor_world.x-tracked_metrics.start.x,p.anchor_world.z-tracked_metrics.start.z).length())
			tracked_metrics.joint=maxf(tracked_metrics.joint,p.max_joint_anchor_error_m)
			for rb: RigidBody3D in tracked.owned_bodies():
				var cap: CapsuleShape3D=rb.get_child(0).shape;var off:=rb.global_basis.y*(cap.height*.5-cap.radius)
				tracked_metrics.floor=minf(tracked_metrics.floor,minf((rb.global_position-off).y,(rb.global_position+off).y)-cap.radius)
		await process_frame

func head_case(index: int,variant: String,direction: Vector3=Vector3.LEFT) -> void:
	await setup_actors()
	var owner: RefCounted=hit_owners[index]
	head_instrument_owner=owner;head_hit_path_us=[]
	var physical: RefCounted=host._ragdolls[owner._token.source_id]
	var body: CharacterBody3D=owner._token.body
	var before: Transform3D=body.global_transform
	var rig: Skeleton3D=owner._token.rig
	var head_frame: Transform3D=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("head"))
	var center: Vector3=head_frame*((owner._head_zone._head_min+owner._head_zone._head_max)*.5)
	var target:=center
	if variant in ["torso","medical"]:target=body.global_position+Vector3.UP*1.1
	if variant=="arm":target=(rig.global_transform*rig.get_bone_global_pose(rig.find_bone("forearm_l"))).origin
	if variant=="near_miss":
		var local_center: Vector3=(owner._head_zone._head_min+owner._head_zone._head_max)*.5
		local_center.y=owner._head_zone._head_max.y+.03
		target=head_frame*local_center
	if variant=="invulnerable":owner._row._invulnerable=true
	var origin:=target-direction*.8
	var arm_witness: Dictionary={}
	if variant=="arm_cover":
		# Place an actual nonparallel original triangle across the ray, not an
		# assumed capsule centre. Independently verify the resulting skin pose.
		var arm_record:=place_arm_triangle(owner,center,direction)
		await process_frame;await physics_frame
		arm_witness=arm_triangle_witness(owner,arm_record,origin,direction)
		check(arm_witness.get("hit") is Vector3 and arm_witness.get("center_error",INF)<.0001 and arm_witness.get("distance",INF)<.6,"independent exact forearm triangle lies across head ray")
	var wall: StaticBody3D
	if variant=="wall":
		wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=1
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.1,.8,.8);shape.shape=box;wall.add_child(shape);scene.add_child(wall)
		wall.global_position=(origin+target)*.5
		await physics_frame;await physics_frame
	var excluded: Array[RID]=[body.get_rid(),weapons.player.get_rid()]
	excluded.append_array(physical._body.body_rids())
	var proof: Dictionary=owner._head_zone.classify(origin,direction,5,physical,scene,excluded)
	check(proof.is_empty() if variant in ["torso","medical","arm","arm_cover","near_miss","wall"] else proof.get("zone")=="head","exact head skin vs torso/world "+variant)
	# A nearby bone or capsule cannot promote a ray passing above actual skin.
	check(owner._head_zone.classify(center-direction*.8+Vector3.UP*.5,direction,5,physical,scene,excluded).is_empty(),"ray above actual head skin is not headshot")
	seed_survival(owner) # Force original survival branch; head must bypass it explicitly.
	var shot:=shot_for("shotgun" if variant in ["medical","head_shotgun","mixed_head_shotgun"] else "tt_pistol")
	if variant=="mixed_head_shotgun":
		# Adversarial native-producer fixture, not a source shotgun spread claim.
		# Pellet 0 goes to torso, later pellets to anatomical head in same sweep.
		for projectile: Dictionary in shot.projectiles:
			projectile.yawOffset=0.0;projectile.pitchOffset=0.0
		shot.projectiles[0].pitchOffset=atan2((body.global_position+Vector3.UP*1.1-origin).y,.8)
		var body_direction: Vector3=direction.rotated(direction.cross(Vector3.UP).normalized(),shot.projectiles[0].pitchOffset)
		check(owner._head_zone.classify(origin,body_direction,5,physical,scene,excluded).is_empty(),"mixed pellet 0 cannot classify head")
	check(weapons.effects.shoot(shot,{"origin":origin},target),"native head-test shot")
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,direction.rotated(Vector3.UP,.7)) # camera parallax must not rotate physical contact
	tracked=physical;tracked_metrics={"start":before.origin,"distance":0.0,"joint":0.0,"floor":INF}
	await advance_physics(60)
	if variant in ["head","head_shotgun","mixed_head_shotgun"]:
		check(owner.last_result.get("reason")=="final_death" and owner._row.hp==0 and owner._row.dead,"actual TT head kills even survival RNG")
		var actual_damage: int=owner.last_result.get("hit",{}).get("damage",0)
		check((actual_damage>0 and actual_damage<=95) if variant in ["head_shotgun","mixed_head_shotgun"] else actual_damage==30,"head policy does not invent critical damage")
		check(owner.last_head_zone.get("proof")=="native_owned_hit_then_first_anatomical_skin_triangle","native head proof retained")
		check(physical.status().final_dead and physical.mode=="ACTIVE","head death uses unchanged physical host")
		check(owner.last_impulse.impulse_ns.normalized().dot(owner.last_head_zone.direction)>.999,"physical impulse follows selected native head pellet, not camera")
		check(owner.last_contact.point.distance_to(owner.last_head_zone.point)<.00001 and owner.last_contact.normal.distance_to(owner.last_head_zone.normal)<.00001,"blood/marks contact uses refined skin point and normal")
		check(absf(owner.last_contact.normal.length()-1)<.00001 and owner.last_contact.normal.dot(owner.last_head_zone.direction)<=.00001,"skin normal is unit and faces incoming ray")
		check((owner.last_contact.point-origin).cross(owner.last_head_zone.direction).length()<.0001,"selected skin point remains on native pellet ray")
		check(owner.last_contact.incoming_direction.distance_to(owner.last_head_zone.direction)<.00001,"marks incoming direction uses selected head pellet")
		if variant in ["head_shotgun","mixed_head_shotgun"]:
			var selected: Dictionary={}
			for terminal: Dictionary in terminals:
				if terminal.shotId==shot.shotId and terminal.projectileIndex==owner.last_head_zone.projectile_index:selected=terminal
			check(not selected.is_empty() and selected.direction.distance_to(owner.last_head_zone.direction)<.00001,"head tuple binds exact completed pellet index and direction")
		if variant=="mixed_head_shotgun":
			var matching: Array[Dictionary]=[]
			for terminal: Dictionary in terminals:
				if terminal.shotId==shot.shotId and terminal.status=="hit" and owner._owns_collider(terminal.get("collider")):matching.append(terminal)
			check(matching.size()>1 and matching[0].projectileIndex==0 and owner.last_head_zone.projectile_index!=0,"earlier real body pellet does not supply later head contact tuple")
	elif variant=="torso":
		check(owner.last_result.get("reason")=="hit" and owner._row.hp==30 and physical.mode=="IDLE","torso source HP unchanged")
		check(body.global_transform==before,"surviving shot cannot teleport standing body")
	elif variant=="medical":check(owner.last_result.get("reason")=="medical_downed" and owner._row.hp==1 and not physical.status().final_dead,"nonhead lethal preserves source72percent medical")
	elif variant in ["arm","arm_cover","near_miss"]:
		check(owner.last_head_zone.is_empty() and not owner._row.get("dead",false) and physical.mode=="IDLE","arm/near miss cannot promote a headshot")
		check(body.global_transform==before,"arm/near miss no body teleport")
		if variant=="arm_cover":check(owner._serial==1 and owner._row.hp==30,"real owned native contact first exact forearm occludes head")
	elif variant=="invulnerable":check(owner._row.hp==60 and physical.mode=="IDLE" and owner.last_impulse.is_empty(),"protected head no death or impulse")
	elif variant=="wall":check(owner._serial==0 and owner._row.hp==60 and physical.mode=="IDLE","real wall blocks headshot")
	var count: int=owner._serial
	var impulse: Dictionary=owner.last_impulse.duplicate(true)
	for receipt: Dictionary in hits:
		if receipt.shotId==shot.shotId:owner._on_native_impact(receipt)
	check(owner._serial==count and owner.last_impulse==impulse,"head native replay no extra HP/impulse")
	await advance_physics(120)
	check(tracked_metrics.joint<.20,"headshot joint bound unchanged")
	measured.append({"actor":owner._token.source_id,"case":variant,"direction":str(direction),"arm_witness":arm_witness,"head_query_us":owner._head_zone.last_us,"full_native_producer_hp_resident_step_us":head_hit_path_us.duplicate(),"result":owner.last_result.get("reason"),"hp":owner._row.hp,"native_hits":owner._serial,"impulse":impulse,"metrics":tracked_metrics.duplicate(true)})
	tracked=null;tracked_metrics={};head_instrument_owner=null
	if is_instance_valid(wall):wall.queue_free();await physics_frame
	await cleanup_actors()

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
		for direction: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:await head_case(index,"head",direction)
		for variant: String in ["head_shotgun","mixed_head_shotgun","torso","medical","arm","arm_cover","near_miss","invulnerable","wall"]:await head_case(index,variant)
	weapons.effects.dispose();scene.queue_free();await process_frame
	print("HIT_IMPULSE_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"rows":measured,"scope":"actual native head rays+exact original3rig skin; user-requested head final policy; not LIVE/UI"}))
	quit(0 if errors.is_empty() else 1)
