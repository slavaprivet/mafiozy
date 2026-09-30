extends "tests/native_head_only.gd"
var follow_rows: Array[Dictionary]=[]

func finish_case(index: int) -> void:
	await setup_actors()
	var owner: RefCounted=hit_owners[index]
	var physical: RefCounted=host._ragdolls[owner._token.source_id]
	var body: CharacterBody3D=owner._token.body
	var body_ids: Array[int]=[];var joint_ids: Array[int]=[]
	for rb: RigidBody3D in physical.owned_bodies():body_ids.append(rb.get_instance_id())
	for joint: Dictionary in physical._body._joints:joint_ids.append(joint.node.get_instance_id())
	check(body_ids.size()==16 and joint_ids.size()==15,"original prepared16body15joint")
	var before_head: Vector3=(owner._token.rig.global_transform*owner._token.rig.get_bone_global_pose(owner._token.rig.find_bone("head"))).origin
	var torso: Vector3=body.global_position+Vector3.UP*1.1
	var origin: Vector3=torso+Vector3.RIGHT*.8
	seed_survival(owner)
	var medical_shot:=shot_for("shotgun")
	check(weapons.effects.shoot(medical_shot,{"origin":origin},torso),"actual source shotgun producer for medical")
	weapons.shot_emitted.emit(medical_shot,{"origin":origin},origin,Vector3.LEFT)
	await advance_physics(180)
	check(owner.last_result.get("reason")=="medical_downed" and owner._row.hp==1 and owner._row._medicalDowned,"actual nonhead native source hit enters medical")
	check(physical.mode=="ACTIVE" and not physical.status().final_dead and not physical._eyes.closed,"medical original body active, eyes open")
	var medical_impulse: Dictionary=owner.last_impulse.duplicate(true)
	var physical_before: Dictionary=physical._body.snapshot()
	var frame: Transform3D=physical_before.bone_world_frames.head
	var center: Vector3=frame*((owner._head_zone._head_min+owner._head_zone._head_max)*.5)
	check(frame.origin.distance_to(before_head)>.1,"second shot targets MOVED physical head, not standing head")
	var excluded: Array[RID]=[body.get_rid(),weapons.player.get_rid()]
	excluded.append_array(physical._body.body_rids())
	var chosen: Dictionary={}
	for approach: Vector3 in [Vector3.UP,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		origin=center+approach*.6
		var proof: Dictionary=owner._head_zone.classify(origin,-approach,5,physical,scene,excluded)
		if not proof.is_empty():chosen={"origin":origin,"direction":-approach,"proof":proof};break
	check(not chosen.is_empty(),"current moved skin has unobstructed native head approach")
	if chosen.is_empty():
		await cleanup_actors();return
	var head_shot:=shot_for("tt_pistol")
	check(weapons.effects.shoot(head_shot,{"origin":chosen.origin},center),"actual native TT producer targets current physical skin")
	weapons.shot_emitted.emit(head_shot,{"origin":chosen.origin},chosen.origin,chosen.direction.rotated(Vector3.RIGHT,.4))
	await advance_physics(45)
	check(owner._row.hp==0 and owner._row.dead and not owner._row._medicalDowned,"moved medical head ends HP life")
	check(owner.last_result.get("reason")=="final_death" and physical.status().final_dead and physical.mode=="ACTIVE","same active body becomes confirmed final death")
	check(physical._eyes.closed and physical._eyes._nodes_match(),"original closed-eye resources installed only after final death")
	var after_ids: Array[int]=[];var after_joint_ids: Array[int]=[]
	for rb: RigidBody3D in physical.owned_bodies():after_ids.append(rb.get_instance_id())
	for joint: Dictionary in physical._body._joints:after_joint_ids.append(joint.node.get_instance_id())
	check(after_ids==body_ids and after_joint_ids==joint_ids,"same16body15joint identities through medical to final")
	var zone: Dictionary=owner.last_head_zone
	check(zone.get("zone")=="head" and not zone.is_empty(),"admitted current anatomical proof retained")
	if not zone.is_empty():
		check(owner.last_contact.point.distance_to(zone.point)<.00001 and owner.last_contact.normal.distance_to(zone.normal)<.00001,"final wound point and normal paired to current skin")
		check(owner.last_contact.incoming_direction.distance_to(zone.direction)<.00001 and absf(zone.normal.length()-1)<.00001 and zone.normal.dot(zone.direction)<=.00001,"final contact has native direction and outward skin normal")
		check((zone.point-chosen.origin).cross(zone.direction).length()<.0001,"final contact lies on actual finishing ray")
	check(owner.last_impulse==medical_impulse,"ACTIVE confirm does not reapply initial medical impulse")
	var count: int=owner._serial;var event_count: int=owner._events.size();var death_key: String=physical.status().death_key
	var last: Dictionary=owner.last_result.duplicate(true)
	for receipt: Dictionary in hits:
		if receipt.shotId in [medical_shot.shotId,head_shot.shotId]:owner._on_native_impact(receipt)
	for receipt: Dictionary in terminals:
		if receipt.shotId in [medical_shot.shotId,head_shot.shotId]:owner._on_projectile_resolved(receipt)
	check(owner._serial==count and owner._events.size()==event_count and owner.last_result==last and owner.last_impulse==medical_impulse,"replayed finishing/medical receipts no extra life or force")
	var finished: Dictionary={"actor":owner._token.source_id,"medical_hp":1,"final_hp":owner._row.hp,"final_dead":physical.status().final_dead,"head_movement_m":frame.origin.distance_to(before_head),"body_ids_unchanged":after_ids==body_ids,"joint_ids_unchanged":after_joint_ids==joint_ids,"eyes_closed":physical._eyes.closed,"head_contact":zone.duplicate(true),"max_joint_error":physical._body.snapshot().max_joint_anchor_error_m}
	owner.dispose()
	for receipt: Dictionary in hits:
		if receipt.shotId==head_shot.shotId:owner._on_native_impact(receipt)
	for receipt: Dictionary in terminals:
		if receipt.shotId==head_shot.shotId:owner._on_projectile_resolved(receipt)
	check(owner._serial==count and owner._row.hp==0 and physical.status().death_key==death_key,"retired owner cannot replay against final body")
	follow_rows.append(finished)
	await cleanup_actors()

func run() -> void:
	scene=load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled=true;scene.preview_start_at_vehicle=false;scene.preview_residents_enabled=false;root.add_child(scene)
	await physics_frame;await physics_frame
	check(scene.preview_ready,"exact frozen merged main loaded")
	if is_instance_valid(scene.preview_transport):scene.preview_transport.body.collision_layer=0;scene.preview_transport.body.collision_mask=0
	weapons=scene.preview_weapons;weapons.set_physics_process(false);weapons.effects.dispose();weapons.effects=Effects.new()
	weapons.player.set_physics_process(false)
	check(weapons.effects.configure(scene,Callable(weapons,"_projectile_ray")).ok,"actual native producer")
	weapons.effects.projectile_resolved.connect(record_terminal);weapons.effects.cosmetic_impact.connect(record_hit)
	packet=FileAccess.get_file_as_bytes(DIR+PACKET+".json");parsed=JSON.parse_string(packet.get_string_from_utf8())
	var sources:={}
	for row: Dictionary in parsed.source_receipts:sources[row.path]=row.sha256
	trust={"accepted":true,"packet_sha256":PACKET,"sources":sources,"session_id":parsed.session_id,"prepared_sha256":MANIFEST,"block_sha256":BLOCK}
	for index in 3:await finish_case(index)
	weapons.effects.dispose();scene.queue_free();await process_frame
	print("ACTIVE_HEAD_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"rows":follow_rows,"scope":"actual native medical then moved ACTIVE anatomical head; source Fire shots but fixture muzzle, not UI/GPU"}))
	quit(0 if errors.is_empty() else 1)
