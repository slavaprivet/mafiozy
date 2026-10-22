extends SceneTree
const Host = preload("res://scripts/npc_visual/npc_ragdoll_host.gd")
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const NativeCar = preload("res://scripts/vehicle_physics/vehicle_native_body.gd")
const ContactReceipt = preload("res://scripts/vehicle_physics/vehicle_npc_contact_receipt.gd")
class OnsetCar extends NativeCar:
	var target: CollisionObject3D
	var onset: Dictionary = {}
	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super._integrate_forces(state)
		if not is_instance_valid(target) or not onset.is_empty(): return
		for i in state.get_contact_count():
			var row: Dictionary = ContactReceipt.observe(state,self,i,target)
			if row.get("valid",false): onset = row; break
const DIR := "res://assets/npc_visual/session/"
const PREPARED := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
var checks := 0
var errors: Array[String] = []
var rows: Array = []
var advances: Array[int] = []
var baseline_snapshots: Array[int] = []
var current := true
var token: Dictionary = {}
var event: Dictionary = {}
var malformed := ""
var active_host: RefCounted
var reenter := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and errors.size() < 50: errors.append(message)
func valid(binding: Dictionary) -> bool:
	for key: String in Host.IDENTITY_FIELDS:
		if binding.get(key) != token.get(key): return false
	return current
func confirmed(request: Dictionary) -> Dictionary:
	if reenter == "retire": active_host.retire("provider_retired")
	if reenter == "activate": check(not active_host.activate("recursive").ok,"reentrant activation rejected")
	var binding: Dictionary = request.binding.duplicate()
	if malformed == "binding": binding.life_generation += 1
	var copy := event.duplicate(true)
	if malformed == "unconfirmed": copy.confirmed = false
	if malformed == "damage": copy.kind = "damage"; copy.damage = 100000
	if malformed == "nonfinite": copy.impulse_ns = Vector3(INF,0,0)
	if malformed == "overspeed": copy.linear_velocity = Vector3(81,0,0)
	if malformed == "no_contact": copy.contact_verified = false
	if malformed == "no_death_key": copy.erase("death_key")
	if malformed == "double_impulse": copy.already_solved_by_godot = true; copy.apply_again = true
	if malformed == "missing_impulse_state": copy.erase("already_solved_by_godot")
	return {"known":true,"accepted":true,"completed":true,"binding":binding,"event":copy}
func admit(kind := "vehicle_knockdown", impulse := Vector3(40,0,0)) -> void:
	event = {"id":"fixture_event", "confirmed":true,"kind":kind,"death_key":"source_fixture_death_1","vehicle_id":"fixture_car","contact_verified":true,"linear_velocity":Vector3.ZERO,"angular_velocity":Vector3.ZERO,"reference_point":Vector3.ZERO,"impulse_ns":impulse,"already_solved_by_godot":false,"apply_again":true}
func floor_body(world: Node3D) -> StaticBody3D:
	var b := StaticBody3D.new(); var s := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(1000,.2,1000); s.shape = box; b.add_child(s); b.position.y = -.1; b.set_meta("vehicle_surface_id","dry_asphalt"); world.add_child(b); return b
func car_body(world: Node3D, x: float) -> RigidBody3D:
	var car := RigidBody3D.new(); car.mass = 1200; car.continuous_cd = true
	car.collision_layer = 1; car.collision_mask = 257; car.contact_monitor = true; car.max_contacts_reported = 32
	car.linear_damp = .02; car.angular_damp = 1.5
	var material := PhysicsMaterial.new(); material.friction = .05; material.bounce = 0; car.physics_material_override = material
	var box := BoxShape3D.new(); box.size = Vector3(1.7,.25,3.2)
	var chassis := CollisionShape3D.new(); chassis.shape = box; chassis.position.y = .20; car.add_child(chassis)
	for dx in [-.64,.64]:
		for dz in [-1.05,1.05]:
			var wheel := CollisionShape3D.new(); var cylinder := CylinderShape3D.new(); cylinder.radius = .34; cylinder.height = .25
			wheel.shape = cylinder; wheel.rotation.z = PI/2; wheel.position = Vector3(dx,-.26,dz); car.add_child(wheel)
	car.position = Vector3(x,.60,-5); car.linear_velocity = Vector3(0,0,4.5); car.constant_force = Vector3(0,0,1600); world.add_child(car); return car
func actual_car_body(world: Node3D, x: float, onset_target: CollisionObject3D = null) -> RigidBody3D:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var descriptor := {}
	for row: Dictionary in profiles.profiles:
		if row.profile_id == "compact_sedan": descriptor = row.duplicate(true); break
	descriptor["vehicle_id"] = "TEST_ONLY_actual_native_car"; descriptor["life_generation"] = 1; descriptor["source_clock"] = 1
	var car: NativeVehicleBody = NativeCar.new() if onset_target == null else OnsetCar.new()
	if onset_target != null: car.target = onset_target
	check(car.configure(descriptor),"actual source sedan profile")
	car.position = Vector3(x,0,-5); car.rotation.y = PI; world.add_child(car)
	check(car.collision_layer == 1 and car.collision_mask == 1,"current native car filters unchanged")
	check(car.get_shape_owners().size() == 1 and car._wheel_rays.size() == 4,"actual chassis only + four suspension rays")
	check(car.submit_control(.55,0,0,false,1),"actual powered native throttle")
	car.linear_velocity = Vector3(0,0,4.5)
	return car
func create_actor(world: Node3D, entry: Dictionary) -> Dictionary:
	var prepared := FileAccess.get_file_as_bytes(DIR+"prepared/manifest.json")
	var admitted := Cache.load_verified(prepared,PREPARED,entry.bridge_id,entry.descriptor_sha256,DIR+"prepared")
	check(admitted.ok,"verified cached NPC "+entry.bridge_id)
	if not admitted.ok: return {}
	var appearance: Dictionary = admitted.cache.instantiate_actor(); admitted.cache.dispose()
	check(appearance.ok,"actual instantiated NPC "+entry.bridge_id)
	if not appearance.ok: return {}
	var actor := CharacterBody3D.new(); actor.collision_layer = 1; actor.collision_mask = 1
	var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = 1.8; shape.shape = capsule; shape.position.y = .9; actor.add_child(shape)
	var motion := Node3D.new(); motion.rotation.y = PI; actor.add_child(motion); motion.add_child(appearance.visual); world.add_child(actor); actor.position = Vector3(0,.6,0)
	var rig: Skeleton3D = appearance.skeleton
	# A genuine outgoing non-rest pose; captured verbatim, no reference death clip.
	var arm := rig.find_bone("upperarm_l"); rig.set_bone_pose_rotation(arm,Quaternion(Vector3.FORWARD,.12)*rig.get_bone_pose_rotation(arm))
	token = {"ok":true,"source_authority":false,"session_id":"TEST_ONLY_NPC_PHYSICS","source_id":entry.bridge_id,"render_id":entry.bridge_id,"bridge_id":entry.bridge_id,"descriptor_sha256":entry.descriptor_sha256,"body_rid":actor.get_rid(),"life_generation":1,"rig_epoch":rig.get_instance_id(),"body_instance_id":actor.get_instance_id(),"rig_instance_id":rig.get_instance_id(),"body":actor,"rig":rig}
	token["placement_mode"] = "TEST_ONLY"
	current = true; malformed = ""; reenter = ""
	return {"actor":actor,"rig":rig}
func pose_error(rig: Skeleton3D, frames: Dictionary) -> float:
	var maximum := 0.0
	for i in 28:
		var displayed := rig.global_transform*rig.get_bone_global_pose(i)
		var wanted: Transform3D = frames[str(rig.get_bone_name(i))]
		maximum = maxf(maximum,displayed.origin.distance_to(wanted.origin))
		maximum = maxf(maximum,(displayed.basis.x-wanted.basis.x).length())
		maximum = maxf(maximum,(displayed.basis.y-wanted.basis.y).length())
		maximum = maxf(maximum,(displayed.basis.z-wanted.basis.z).length())
	return maximum
func lowest(host: RefCounted) -> float:
	var value := INF
	for b: RigidBody3D in host.owned_bodies():
		var cap: CapsuleShape3D = b.get_child(0).shape
		var offset := b.global_basis.y*(cap.height*.5-cap.radius)
		value = minf(value,minf((b.global_position-offset).y,(b.global_position+offset).y)-cap.radius)
	return value
func skin_points(rig: Skeleton3D) -> Array:
	var points: Array = []
	for mesh: MeshInstance3D in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or mesh.skin == null: continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			check(ids.size() == vertices.size()*4 and weights.size() == ids.size(),"actual skin four influences")
			for v in vertices.size():
				var row: Array = []
				for j in 4:
					var weight := weights[v*4+j]
					if weight <= 0: continue
					var bind := ids[v*4+j]
					var name := str(mesh.skin.get_bind_name(bind))
					if name.is_empty(): name = str(rig.get_bone_name(mesh.skin.get_bind_bone(bind)))
					row.append([name,mesh.skin.get_bind_pose(bind)*vertices[v],weight])
				points.append(row)
	return points
func skin_minimum(points: Array, frames: Dictionary) -> float:
	var minimum := INF
	for row: Array in points:
		var point := Vector3.ZERO
		for influence: Array in row: point += (frames[influence[0]] as Transform3D)*influence[1]*influence[2]
		minimum = minf(minimum,point.y)
	return minimum
func tick() -> void:
	await physics_frame; await process_frame

func guard_tests(entry: Dictionary) -> void:
	var world := Node3D.new(); root.add_child(world); floor_body(world)
	var pair := create_actor(world,entry); if pair.is_empty(): world.free(); return
	var host := Host.new(); active_host = host
	check(host.configure(token,world,valid,confirmed).ok,"guard configure")
	check(host.owned_bodies().size() == 16,"preallocated sixteen bodies")
	var original_pose: Transform3D = pair.rig.get_bone_global_pose(0)
	for bad in ["binding","unconfirmed","damage","nonfinite","overspeed","no_contact","double_impulse","missing_impulse_state"]:
		admit(); malformed = bad
		check(not host.activate("fixture_event").ok,"reject "+bad)
		check(host.mode == "IDLE" and pair.actor.collision_layer == 1 and pair.actor.collision_mask == 1,"failure atomic capsule "+bad)
		check(pair.rig.get_bone_global_pose(0) == original_pose,"failure atomic pose "+bad)
		for b: RigidBody3D in host.owned_bodies(): check(b.freeze and b.collision_layer == 0,"failure pool inactive "+bad)
	admit("final_death"); malformed = "no_death_key"
	check(not host.activate("fixture_event").ok,"missing death lifecycle key rejects")
	malformed = ""; admit(); reenter = "activate"
	check(host.activate("fixture_event").ok,"confirmed knockdown starts once")
	check(pair.actor.collision_layer == 0 and pair.actor.collision_mask == 0,"successful handoff disables capsule")
	check(not host.activate("fixture_event").ok,"replayed event cannot restart")
	reenter = ""; admit("final_death",Vector3(900,0,0))
	var prior: Transform3D = host.owned_bodies()[0].global_transform
	var prior_v: Vector3 = host.owned_bodies()[0].linear_velocity
	check(host.confirm_final_death("fixture_event").ok,"later confirmed death")
	check(host.owned_bodies()[0].global_transform == prior and host.owned_bodies()[0].linear_velocity == prior_v,"later death no restart/extra impulse/teleport")
	check(host.status().final_dead,"death explicitly separate")
	current = false
	check(not host.advance().ok and host.mode == "RETIRED","stale life retires without write")
	check(host.owned_bodies().is_empty() and pair.actor.collision_layer == 0,"retirement no stale/dead capsule revival")
	host.dispose(); host.dispose(); world.free()
	# Callback retirement must abort before committing any actor mutation.
	world = Node3D.new(); root.add_child(world); pair = create_actor(world,entry)
	host = Host.new(); active_host = host; check(host.configure(token,world,valid,confirmed).ok,"reentrant retire configure")
	admit(); reenter = "retire"; check(not host.activate("fixture_event").ok,"provider retirement aborts")
	check(pair.actor.collision_layer == 1 and host.owned_bodies().is_empty(),"provider retirement atomic")
	world.free(); active_host = null
	world = Node3D.new(); root.add_child(world); pair = create_actor(world,entry)
	host = Host.new(); check(host.configure(token,world,valid,confirmed).ok,"already solved configure")
	admit("vehicle_knockdown",Vector3(700,0,0)); event.already_solved_by_godot = true; event.apply_again = false; event.linear_velocity = Vector3(1,0,0)
	check(host.activate("fixture_event").ok,"already solved native receipt accepted")
	for b: RigidBody3D in host.owned_bodies(): check(b.linear_velocity.distance_to(Vector3(1,0,0))<.00001,"already solved J never applied twice")
	host.dispose(); world.free()
	# Deleted rig and same-instance changed rig metadata stop before pose writes.
	for invalid in ["rig_deleted","life_generation","descriptor_sha256","body_rid","rig_epoch"]:
		world = Node3D.new(); root.add_child(world); pair = create_actor(world,entry)
		host = Host.new(); check(host.configure(token,world,valid,confirmed).ok,"lifetime configure "+invalid)
		admit(); check(host.activate("fixture_event").ok,"lifetime activate "+invalid)
		if invalid == "rig_deleted": pair.rig.free()
		elif invalid == "body_rid": token.body_rid = RID()
		elif invalid == "descriptor_sha256": token.descriptor_sha256 = "a".repeat(64)
		else: token[invalid] += 1
		check(not host.advance().ok and host.mode == "RETIRED","retire stale "+invalid)
		check(pair.actor.collision_layer == 0 and host.owned_bodies().is_empty(),"no stale reanimation "+invalid)
		host.dispose(); world.free()

func momentum_tests(entry: Dictionary) -> void:
	var speeds: Array[float] = []
	for parameters in [[600.0,2.0],[1800.0,2.0],[600.0,5.0],[1800.0,5.0]]:
		var world := Node3D.new(); root.add_child(world); var pair := create_actor(world,entry)
		var host := Host.new(); check(host.configure(token,world,valid,confirmed).ok,"mass/speed fixture configure")
		# TEST_ONLY external contact provider, not production damage/J policy.
		var accepted_j: float = 75.0*parameters[0]/(75.0+parameters[0])*parameters[1]
		admit("vehicle_knockdown",Vector3(accepted_j,0,0)); event.linear_velocity = Vector3(.2,.1,0); event.angular_velocity = Vector3(0,.3,0); event.reference_point = pair.actor.global_position
		check(host.activate("fixture_event").ok,"accepted externally computed impulse")
		var momentum := Vector3.ZERO; var com := Vector3.ZERO
		for b: RigidBody3D in host.owned_bodies(): momentum += b.mass*b.linear_velocity; com += b.mass*b.global_position
		com /= 75.0
		var expected: Vector3 = 75.0*(event.linear_velocity+event.angular_velocity.cross(com-event.reference_point))+event.impulse_ns
		check(momentum.distance_to(expected) < .001,"actual native summed momentum equals accepted point velocity + J")
		speeds.append(accepted_j/75.0)
		rows.append({"scenario":"accepted_impulse_only","vehicle_mass_fixture":parameters[0],"speed_fixture":parameters[1],"accepted_j":accepted_j,"native_momentum_error":momentum.distance_to(expected),"production_J_policy":false})
		host.dispose(); world.free()
	check(speeds[1]>speeds[0] and speeds[2]>speeds[0] and speeds[3]>speeds[1] and speeds[3]>speeds[2],"external fixture mass/speed impulse effect monotonic")

func physical_scenario(entry: Dictionary, actual_car := false) -> void:
	var world := Node3D.new(); root.add_child(world); var floor := floor_body(world)
	var pair := create_actor(world,entry); if pair.is_empty(): world.free(); return
	var host := Host.new(); var before := Time.get_ticks_usec()
	var configured: Dictionary = host.configure(token,world,valid,confirmed)
	var configure_us := Time.get_ticks_usec()-before
	check(configured.ok,"actual rig physical configure "+entry.bridge_id)
	if not configured.ok: world.free(); return
	await tick(); await tick()
	var outgoing := {}
	for i in 28: outgoing[str(pair.rig.get_bone_name(i))] = pair.rig.global_transform*pair.rig.get_bone_global_pose(i)
	admit("final_death",Vector3(45,0,0)); before = Time.get_ticks_usec()
	check(host.activate("fixture_event").ok,"actual rig final-death handoff")
	var activation_us := Time.get_ticks_usec()-before
	var initial: Dictionary = host.advance()
	check(initial.ok,"initial actual displayed pose")
	check(pose_error(pair.rig,outgoing)<.0001,"no outgoing pose snap")
	var skin := skin_points(pair.rig); check(not skin.is_empty(),"actual cached skinned vertices")
	var sampled_skin_min := INF
	var max_pose := 0.0; var max_joint := 0.0; var min_floor := INF; var max_contacts := 0; var settled := false
	var last: Dictionary = initial.physical
	for i in 420:
		await tick()
		# Same rig/pose/physics step; before = reused native snapshot only, after =
		# snapshot + current-life validation + actual28bone writer. No scene FPS.
		before = Time.get_ticks_usec(); host._body.snapshot(); baseline_snapshots.append(Time.get_ticks_usec()-before)
		before = Time.get_ticks_usec(); var sample: Dictionary = host.advance(); advances.append(Time.get_ticks_usec()-before)
		check(sample.ok,"finite active NPC floor physics")
		if not sample.ok: break
		last = sample.physical; max_joint = maxf(max_joint,last.max_joint_anchor_error_m); max_contacts = maxi(max_contacts,last.contact_count); min_floor = minf(min_floor,lowest(host))
		if i%5 == 0: max_pose = maxf(max_pose,pose_error(pair.rig,last.bone_world_frames))
		if i%60 == 0: sampled_skin_min = minf(sampled_skin_min,skin_minimum(skin,last.bone_world_frames))
		if last.settled and i > 120: settled = true; break
	check(settled,"actual NPC settles on native floor "+entry.bridge_id)
	check(max_contacts>0 and min_floor>-.09,"actual NPC floor contact bounded penetration")
	check(max_pose<.0002,"all28 displayed frames follow actual physics")
	check(max_joint<.10,"floor joints bounded")
	var settled_skin_min := skin_minimum(skin,last.bone_world_frames)
	check(settled_skin_min>-.025,"actual skin settled floor bounded solver tolerance")
	var rest_anchor: Vector3 = last.anchor_world
	# A real rigid car with chassis + four cylinder wheel colliders; no movement
	# callback, raycast-wheel fiction, ragdoll/car exception or forced body pose.
	var car := actual_car_body(world,rest_anchor.x) if actual_car else car_body(world,rest_anchor.x-.64)
	var wheel_contacts := 0; var chassis_contacts := 0; var max_step := 0.0; var prior_anchor := rest_anchor
	var car_min_speed := INF; var overrun_min_floor := INF; var overrun_joint := 0.0
	var final_contacts := 0
	var contact_ticks := 0; var longest_contact_run := 0; var contact_run := 0; var max_contact_depth := 0.0; var ticks := 0; var max_speed := 0.0; var unexpected_step := 0.0
	for i in 480:
		ticks = i+1
		await tick(); var sample: Dictionary = host.advance()
		check(sample.ok,"finite actual wheel-overrun physics")
		if not sample.ok: break
		last = sample.physical; max_pose = maxf(max_pose,pose_error(pair.rig,last.bone_world_frames))
		var step: float = prior_anchor.distance_to(last.anchor_world)
		max_step = maxf(max_step,step); prior_anchor = last.anchor_world
		unexpected_step = maxf(unexpected_step,step-maxf(max_speed,last.max_linear_speed)/60.0)
		max_speed = maxf(max_speed,last.max_linear_speed)
		overrun_min_floor = minf(overrun_min_floor,lowest(host)); overrun_joint = maxf(overrun_joint,last.max_joint_anchor_error_m)
		car_min_speed = minf(car_min_speed,car.linear_velocity.z)
		final_contacts = 0
		for b: RigidBody3D in host.owned_bodies():
			check(not car in b.get_collision_exceptions() and not floor in b.get_collision_exceptions(),"car/floor collision never bypassed")
			var state := PhysicsServer3D.body_get_direct_state(b.get_rid())
			if state == null: continue
			for j in state.get_contact_count():
				if state.get_contact_collider_object(j) == car:
					final_contacts += 1
					var delta: Vector3 = state.get_contact_local_position(j)-state.get_contact_collider_position(j)
					max_contact_depth = maxf(max_contact_depth,absf(delta.dot(state.get_contact_local_normal(j))))
					if state.get_contact_collider_shape(j)>0: wheel_contacts += 1
					else: chassis_contacts += 1
		if final_contacts>0:
			contact_ticks += 1; contact_run += 1; longest_contact_run = maxi(longest_contact_run,contact_run)
		else: contact_run = 0
		if car.global_position.z>8 and final_contacts == 0 and car.global_position.distance_to(last.anchor_world)>4: break
	if actual_car: check(chassis_contacts>0 and wheel_contacts == 0,"actual current car chassis contact, no fake wheel proof "+entry.bridge_id)
	else: check(wheel_contacts>0,"synthetic wheel shape contacts NPC "+entry.bridge_id)
	check(car.global_position.z>3.0,"car passes corpse without persistent snag "+entry.bridge_id)
	check(car.global_position.distance_to(last.anchor_world)>3.0,"corpse not glued to departed car")
	check(final_contacts == 0,"car/NPC native contacts separated after traversal")
	check(unexpected_step<.20 and max_pose<.0002,"no displacement beyond sampled native speed/contact correction; exact displayed pose")
	check(overrun_min_floor>-.16 and overrun_joint<.20,"bounded overrun capsule penetration/joint error")
	rows.append({"scenario":"actual_native_vehicle_chassis" if actual_car else "synthetic_wheel_fixture","actor":entry.bridge_id,"configure_us":configure_us,"activation_us":activation_us,"floor_settled":settled,"floor_min_capsule_m":min_floor,"floor_max_joint_error_m":max_joint,"max_displayed_frame_error":max_pose,"wheel_contacts":wheel_contacts,"chassis_contacts":chassis_contacts,"wheel_collision_proved":not actual_car and wheel_contacts>0,"final_car_contacts":final_contacts,"car_final_z":car.global_position.z,"car_min_forward_speed":car_min_speed,"car_constant_force_n":0 if actual_car else 1600,"actual_native_throttle":.55 if actual_car else 0,"overrun_min_capsule_m":overrun_min_floor,"overrun_max_joint_error_m":overrun_joint,"max_anchor_step_m":max_step,"max_native_speed_mps":max_speed,"unexpected_step_m":unexpected_step,"capsules_not_skin":true,"car_corpse_final_distance_m":car.global_position.distance_to(last.anchor_world),"measured_contact_point_separation_m":max_contact_depth,"simulated_ticks":ticks,"contact_ticks":contact_ticks,"longest_contact_run_s":float(longest_contact_run)/60.0})
	rows[-1]["skin_vertices"] = skin.size(); rows[-1]["settled_skin_min_y"] = settled_skin_min; rows[-1]["sampled_fall_skin_min_y"] = sampled_skin_min; rows[-1]["final_after_vehicle_skin_min_y"] = skin_minimum(skin,last.bone_world_frames)
	host.dispose(); check(pair.actor.collision_layer == 0,"final dead teardown never resurrects walking capsule")
	world.free(); await process_frame

func actual_onset_scenario(entry: Dictionary) -> void:
	var world := Node3D.new(); root.add_child(world); floor_body(world)
	var pair := create_actor(world,entry); pair.actor.position.y = 0
	var host := Host.new(); check(host.configure(token,world,valid,confirmed).ok,"onset actual rig prewarm")
	var car: OnsetCar = actual_car_body(world,0,pair.actor)
	for i in 180:
		await tick()
		if not car.onset.is_empty(): break
	check(not car.onset.is_empty(),"same-tick actual car/chassis -> walking capsule receipt")
	if not car.onset.is_empty():
		var receipt := car.onset
		admit("vehicle_knockdown",receipt.impulse_on_npc_ns)
		event.already_solved_by_godot = true; event.apply_again = false
		event.linear_velocity = receipt.npc_point_velocity_world_mps; event.reference_point = receipt.point_on_npc_world_m
		check(host.activate("fixture_event").ok,"verified native onset transitions standing capsule to articulated body")
		check(not host.status().final_dead,"vehicle onset never invents death/HP")
		var contact_count := 0; var frame_error := 0.0; var lowest_anchor := INF
		for i in 180:
			await tick(); var sample: Dictionary = host.advance(); check(sample.ok,"onset physics remains current")
			if not sample.ok: break
			contact_count = maxi(contact_count,sample.physical.contact_count); lowest_anchor = minf(lowest_anchor,sample.physical.anchor_world.y)
			frame_error = maxf(frame_error,pose_error(pair.rig,sample.physical.bone_world_frames))
		check(contact_count>0 and lowest_anchor<.6 and frame_error<.0002,"actual vehicle-triggered physical fall/display")
		rows.append({"scenario":"actual_native_chassis_onset","actor":entry.bridge_id,"receipt_already_solved":receipt.already_solved_by_godot,"receipt_apply_again":receipt.apply_again,"measured_J_ns":receipt.impulse_on_npc_ns.length(),"J_reapplied_ns":0,"wheel_collision_proved":receipt.wheel_collision_proved,"confirmed_final_death":false,"max_contacts":contact_count,"minimum_anchor_y":lowest_anchor,"display_error":frame_error,"authority":"TEST_ONLY external verified-contact provider"})
	host.dispose(); world.free(); await process_frame

func run() -> void:
	var acceptance := "--vehicle-acceptance" in OS.get_cmdline_user_args()
	var dependency_sha := FileAccess.get_sha256("res://scripts/character_physics/exit_ragdoll_body.gd")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"visual_manifest.json"))
	check(manifest.entries.size() == 3,"three actual cached resident rigs")
	if not acceptance:
		await guard_tests(manifest.entries[0]); await momentum_tests(manifest.entries[0])
	for entry: Dictionary in manifest.entries: await physical_scenario(entry,acceptance)
	if acceptance: await actual_onset_scenario(manifest.entries[0])
	check(FileAccess.get_sha256("res://scripts/character_physics/exit_ragdoll_body.gd") == dependency_sha,"existing ragdoll dependency unchanged")
	advances.sort(); baseline_snapshots.sort()
	var report := {"checks":checks,"passed":errors.is_empty(),"errors":errors,"rows":rows,"host_sha256":FileAccess.get_sha256("res://scripts/npc_visual/npc_ragdoll_host.gd"),"body_sha256":dependency_sha,"vehicle_body_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),"vehicle_profiles_sha256":FileAccess.get_sha256("res://data/transport/vehicle_descriptors.v1.json"),"advance_samples":advances.size(),"advance_us_p50":advances[advances.size()/2] if not advances.is_empty() else -1,"advance_us_p95":advances[int(advances.size()*.95)] if not advances.is_empty() else -1,"native_snapshot_us_p50":baseline_snapshots[baseline_snapshots.size()/2] if not baseline_snapshots.is_empty() else -1,"native_snapshot_us_p95":baseline_snapshots[int(baseline_snapshots.size()*.95)] if not baseline_snapshots.is_empty() else -1,"gpu_used":false,"actual_scene_fps":"NOT_RUN","authority":"TEST_ONLY external receipt provider; no source death decision or vehicle J policy accepted"}
	DirAccess.make_dir_recursive_absolute("../../outputs/artist22_npc_ragdoll")
	report["suite"] = "CURRENT_VEHICLE_ACCEPTANCE" if acceptance else "CORE_HOST_AND_SYNTHETIC_WHEELS"
	var file := FileAccess.open("../../outputs/artist22_npc_ragdoll/"+("VEHICLE_ACCEPTANCE_RESULT.json" if acceptance else "CORE_RESULT.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NPC_RAGDOLL_HOST ",JSON.stringify(report)); quit(0 if errors.is_empty() else 1)
