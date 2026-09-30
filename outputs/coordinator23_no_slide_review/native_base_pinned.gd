extends SceneTree
const Host = preload("res://scripts/npc_visual/preview_resident_host.gd")
const Policy = preload("res://scripts/npc_visual/preview_resident_world_policy.gd")
const Navigation = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const PACKET := "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"
const MANIFEST := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
const BLOCK := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const DIR := "res://assets/npc_visual/session/"
const HitOwner=preload("res://scripts/npc_visual/npc_local_preview_hit_owner.gd")
const Effects=preload("res://scripts/weapons/weapon_projectiles.gd")
const Rules=preload("res://scripts/weapons/weapon_hit_rules.gd")
const Fire=preload("res://scripts/weapons/weapon_fire.gd")
var owner_script: Script=HitOwner
var errors: Array[String]=[]
var checks:=0
var scene: Node3D
var weapons: Node
var packet: PackedByteArray
var parsed: Dictionary
var trust: Dictionary
var policy: RefCounted
var host: RefCounted
var nav: RefCounted
var hit_owners: Array=[]
var serial:=0
var terminals: Array[Dictionary]=[]
var hits: Array[Dictionary]=[]
var costs: Array[int]=[]
var evidence: Array[Dictionary]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: errors.append(label); print("FAIL "+label)

func setup_actors() -> void:
	var owners:={}; var states:={}
	for row: Dictionary in parsed.rows:
		owners[row.source_id]=Queue.Owner.new(row.source_id,1); states[row.source_id]="ordinary_outdoor"
	policy=Policy.new()
	check(policy.configure(scene,parsed.rows,owners,trust,{"version":1,"states":states}).ok,"actual policy")
	nav=Navigation.new()
	check(nav.attach_existing(scene,scene.get("_printshop"),scene.get("_block"),scene.get("_printshop_data"),Queue.new(),parsed.session_id,1,1),"actual navigation")
	host=Host.new()
	check(host.configure(scene,nav,packet,trust,FileAccess.get_file_as_bytes(DIR+"prepared/manifest.json"),DIR+"prepared",owners,Callable(policy,"source_admit"),Callable(policy,"support_height")).ok,"actual host")
	var choices:=[{"r":7.73170787532155,"c":105.310391309785},{"r":9.56097616800448,"c":105.310391309785},{"r":6.26829324117521,"c":104.944537651248}]
	for i in 3:
		var row: Dictionary=parsed.rows[i]
		check(host.admit_preview_stage(row.source_id,choices[i].r,choices[i].c).status=="IDLE","actual stage "+row.source_id)
		var owner: RefCounted=owner_script.new()
		var body: CharacterBody3D=scene.get_node("npc_"+row.source_id)
		check(owner.configure(host,host.target_from_collider(body),packet,trust,weapons,{"marksman":5.0,"scope":"local_new_session","session_id":parsed.session_id}).ok,"HP configure "+row.source_id)
		hit_owners.append(owner)
	await physics_frame; await physics_frame
	host.step(1.0/60.0) # adopted f6e95 floor recovery before source sweep

func cleanup_actors() -> void:
	for owner: RefCounted in hit_owners: owner.dispose()
	hit_owners.clear(); host.dispose(); nav.dispose()
	await process_frame; await physics_frame

func shot_for(id: String) -> Dictionary:
	var state:=Fire.create_state(id)
	serial+=1; state.sequence=serial*10
	var fired:=Fire.step(state,{"triggerPressed":true,"triggerHeld":true},0.0)
	check(fired.shots.size()==1 and fired.state.magazine==state.magazine-1,"source fire/ammo "+id)
	return fired.shots[0]

func seed_survival(owner: RefCounted) -> void:
	var rng:=RandomNumberGenerator.new()
	for n in 100:
		rng.seed=n
		if rng.randf()>=.12 and rng.randf()<.72: owner._rng.seed=n; return

func fire_at(owner: RefCounted,id: String) -> Dictionary:
	seed_survival(owner)
	if id=="nagan": HitOwner._registries[owner._registry_key].nagan_last_at_ms=owner._now()
	var body: CharacterBody3D=owner._token.body
	var point:=body.global_position+Vector3.UP*1.1
	var origin:=point+Vector3(0,0,.8)
	var shot:=shot_for(id)
	if id=="tt_pistol":
		var to:=body.global_position+Vector3(0,0,-.09*4.1)
		var collision:=body.move_and_collide(to-body.global_position,true)
		var excluded: Array[RID]=[body.get_rid()]
		print("PATH_DIAG ",owner._token.source_id," body=",body.global_position," source=",host._source_admits(to,host._records[owner._token.source_id],"route")," physical=",host._physical_clear(to,excluded)," owned=",host._owned_clear(to,owner._token.source_id)," testmove=",body.test_move(body.global_transform,to-body.global_position)," collision=",collision.get_normal() if collision!=null else Vector3.ZERO," travel=",collision.get_travel() if collision!=null else Vector3.ZERO," floor=",body.is_on_floor())
	check(weapons.effects.shoot(shot,{"origin":origin},point),"actual spawn "+id)
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,(point-origin).normalized())
	return shot

func advance_frames(n: int) -> void:
	for i in n:
		await physics_frame
		weapons.effects.advance(1.0/60.0)

func record_terminal(r: Dictionary) -> void: terminals.append(r.duplicate())
func record_hit(r: Dictionary) -> void: hits.append(r.duplicate())

func run() -> void:
	scene=load("res://scenes/main.tscn").instantiate()
	# Root23c binds the player identity through the actual transport setup.
	scene.preview_transport_enabled=true; scene.preview_start_at_vehicle=false; scene.preview_residents_enabled=false
	root.add_child(scene)
	await physics_frame; await physics_frame
	check(scene.preview_ready,"actual loaded scene")
	# Preserve the production identity handoff and live transport references,
	# while restoring the original unobstructed NPC ray matrix in this fixture.
	if is_instance_valid(scene.preview_transport):
		scene.preview_transport.body.collision_layer=0
		scene.preview_transport.body.collision_mask=0
	weapons=scene.preview_weapons
	weapons.set_physics_process(false)
	weapons.effects.dispose()
	weapons.effects=Effects.new()
	check(weapons.effects.configure(scene,Callable(weapons,"_projectile_ray")).ok,"candidate producer native unchanged production ray")
	weapons.effects.projectile_resolved.connect(record_terminal)
	weapons.effects.cosmetic_impact.connect(record_hit)
	packet=FileAccess.get_file_as_bytes(DIR+PACKET+".json")
	parsed=JSON.parse_string(packet.get_string_from_utf8())
	var sources:={}
	for r: Dictionary in parsed.source_receipts: sources[r.path]=r.sha256
	trust={"accepted":true,"packet_sha256":PACKET,"sources":sources,"session_id":parsed.session_id,"prepared_sha256":MANIFEST,"block_sha256":BLOCK}
	# Fixed HP60 bootstraps per case, marksman5; deterministic noncritical and
	# first-lethal survival seeds. No damage/contact/HP fixture writes.
	var expected:={"tt_pistol":30,"deagle":90,"golden_colt":60,"revolver":108,"uzi":19,"golden_uzi":19,"tommy_gun":30,"nagan":32,"ak74":42,"m16":42,"sniper":132,"shotgun":95,"sawn_off":95}
	for id: String in expected:
		await setup_actors()
		for owner: RefCounted in hit_owners:
			var before: Vector3=owner._token.body.global_position
			var shot:=fire_at(owner,id)
			await advance_frames(12)
			var snap: Dictionary=owner.snapshot()
			var actual_damage: int=snap.last_result.get("hit",{}).get("damage",-1)
			check(actual_damage==expected[id],"source scalar "+id+" "+owner._token.source_id+" got "+str(actual_damage))
			check(owner._serial==1,"one source hit per shot/target "+id)
			check(snap.row.hp==(1 if expected[id]>=60 else 60-expected[id]),"source HP "+id)
			check(not snap.row.get("dead",false),"same salvo never medical then death "+id)
			check(absf((snap.row.c*4.1-395.65)-owner._token.body.global_position.x)<.0001 and absf((snap.row.r*4.1-45.1)-owner._token.body.global_position.z)<.0001,"source/native coordinates match "+id)
			var travel: Vector3=owner._token.body.global_position-before
			check(absf(travel.length()-(.09*4.1*(1.65 if id=="nagan" else 1.0)))<.002,"source sweep actual displacement "+id+" "+str(travel))
			var count:=0
			for r: Dictionary in terminals:
				if r.shotId==shot.shotId: count+=1
			check(count==(7 if id in HitOwner.PELLET_HIT else 1),"all native terminal receipts "+id+" got "+str(count))
			var actual_contact: Dictionary={}
			for receipt: Dictionary in terminals:
				if receipt.shotId==shot.shotId and receipt.status=="hit": actual_contact=receipt; break
			check(not actual_contact.is_empty() and owner.last_contact.get("point")==actual_contact.get("point") and owner.last_contact.get("normal")==actual_contact.get("normal"),"blood seam retains first actual native point+normal "+id)
			costs.append(snap.last_hit_us)
			evidence.append({"weapon":id,"source_id":owner._token.source_id,"damage":actual_damage,"hp":snap.row.hp,"terminals":count,"travel":str(travel),"hit_us":snap.last_hit_us})
		await cleanup_actors()
	await context_case()
	await native_terminal_guards()
	await multiple_target_case()
	await path_guards()
	await negative_cases()
	weapons.effects.dispose(); scene.queue_free()
	await process_frame
	costs.sort()
	var result:={"checks":checks,"errors":errors,"native_matrix":evidence,"hit_transaction_us":{"p50":costs[costs.size()/2],"p95":costs[int(costs.size()*.95)],"max":costs[-1]},"scope":"native production ray and emitter against original 3 rigs; source Fire/ammo with fixture muzzle and RNG, not UI or LIVE"}
	print(JSON.stringify(result)); quit(0 if errors.is_empty() else 1)

func context_case() -> void:
	await setup_actors()
	var owner: RefCounted=hit_owners[0]
	var origin: Vector3=owner._token.body.global_position+Vector3.UP
	check(owner.current_damage_context().is_empty(),"no invented initial critical context")
	var rng:=RandomNumberGenerator.new()
	for n in 1000:
		rng.seed=n
		if rng.randf()<.12 and rng.randf()>=.12: owner._rng.seed=n; break
	var shot:=shot_for("rpg")
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	check(owner.current_damage_context().get("critical",false) and owner._shots[shot.shotId].used,"accepted RPG global critical context only")
	var rng_after: int=owner._rng.state
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	check(owner._rng.state==rng_after,"shared duplicate RPG does not reroll")
	shot=shot_for("tt_pistol"); weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	check(not owner.current_damage_context().get("critical",true) and owner.current_damage_context().marksman==5.0,"later accepted gun changes current blast context")
	var registry: Dictionary=HitOwner._registries[owner._registry_key]
	registry.nagan_last_at_ms=owner._now()-2000.0; registry.nagan_chain=3
	rng_after=owner._rng.state
	shot=shot_for("nagan"); weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	check(owner._rng.state==rng_after and registry.nagan_chain==1,"Nagan source duel short circuit consumes no RNG and resets chain once")
	check(owner.current_damage_context().critical_multiplier==1.8,"Nagan current duel multiplier")
	await cleanup_actors()
	check(owner.current_damage_context().is_empty(),"retired damage context fails closed")

func native_terminal_guards() -> void:
	await setup_actors()
	var owner: RefCounted=hit_owners[0]
	var target: Vector3=owner._token.body.global_position+Vector3.UP*1.1
	var origin:=target+Vector3(0,0,2)
	var wall:=StaticBody3D.new(); wall.collision_layer=1
	var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(3,3,.2); shape.shape=box
	wall.add_child(shape); scene.add_child(wall); wall.global_position=target+Vector3(0,0,1)
	await physics_frame
	var shot:=shot_for("shotgun")
	check(weapons.effects.shoot(shot,{"origin":origin},target),"wall salvo admitted")
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	await advance_frames(25)
	check(owner._row.hp==60 and owner._shots[shot.shotId].used and owner._shots[shot.shotId].terminals.size()==7,"actual native wall blocks all pellet HP")
	wall.queue_free(); await physics_frame; await physics_frame
	shot=shot_for("shotgun")
	check(weapons.effects.shoot(shot,{"origin":origin},origin+Vector3.UP*30),"native miss salvo admitted")
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.UP)
	await advance_frames(45)
	check(owner._row.hp==60 and owner._shots[shot.shotId].used and owner._shots[shot.shotId].terminals.values().count("miss")==7,"native range completion misses no HP")
	# One native pellet arrives before the pool is saturated and epoch invalidates
	# its incomplete aggregate. Flight-speed changes are fault fixture inputs.
	shot=shot_for("shotgun")
	for i in range(1,7): shot.projectiles[i].speed=.1
	check(weapons.effects.shoot(shot,{"origin":origin},target),"partial native salvo admitted")
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	await advance_frames(2)
	check(owner._row.hp==60 and owner._shots[shot.shotId].terminals.size()==1,"native partial arrival never commits HP")
	var old_epoch: int=weapons.effects.resolution_epoch()
	var filler:=shot_for("shotgun")
	for p: Dictionary in filler.projectiles: p.speed=.1
	for i in 60:
		filler.shotId="overflow-fixture:"+str(i)
		weapons.effects.shoot(filler,{"origin":origin},origin+Vector3.UP*30)
	check(weapons.effects.resolution_epoch()>old_epoch,"actual bounded native pool queue overflow invalidates epoch")
	await advance_frames(1)
	HitOwner._registries[owner._registry_key].cleanup_at_ms=0.0; owner.step()
	check(owner._row.hp==60 and (not owner._shots.has(shot.shotId) or owner._shots[shot.shotId].used),"epoch invalidation drops real partial salvo no HP")
	await cleanup_actors()

func multiple_target_case() -> void:
	await setup_actors()
	var owner: RefCounted=hit_owners[0]
	seed_survival(owner)
	var target: Vector3=owner._token.body.global_position+Vector3.UP*1.1
	var origin:=target+Vector3(4,0,0)
	var base: Vector3=(target-origin).normalized()
	var shot:=shot_for("shotgun")
	# Aim-only fault fixture splits seven accepted native projectile rays 3/2/2.
	# This is NOT the normal Fire spread; contacts themselves use actual physics.
	for i in 7:
		var other: RefCounted=hit_owners[0 if i<3 else (1 if i<5 else 2)]
		var direction: Vector3=(other._token.body.global_position+Vector3.UP*1.1-origin).normalized()
		shot.projectiles[i].yawOffset=base.signed_angle_to(direction,Vector3.UP)
		shot.projectiles[i].pitchOffset=0.0
	check(weapons.effects.shoot(shot,{"origin":origin},target),"split native projectile accepted")
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,base)
	await advance_frames(30)
	var expected:=[41,27,27]
	for i in 3:
		var snap: Dictionary=hit_owners[i].snapshot()
		check(snap.last_result.get("hit",{}).get("damage",-1)==expected[i],"native 3/2/2 pellet aggregate exact scalar rig "+str(i)+" "+str(snap.last_result))
		check(hit_owners[i]._serial==1 and snap.row.hp==60-expected[i],"one HP commit per native grouped target "+str(i))
	check(owner._shots[shot.shotId].terminals.size()==7,"split all native terminals")
	# Replaying authentic terminal receipts cannot apply another source hit.
	for receipt: Dictionary in terminals:
		if receipt.shotId==shot.shotId: owner._on_projectile_resolved(receipt)
	for current: RefCounted in hit_owners: check(current._serial==1,"completed native receipt replay ignored")
	await cleanup_actors()

func path_guards() -> void:
	await setup_actors()
	var owner: RefCounted=hit_owners[0]
	var body: CharacterBody3D=owner._token.body
	var before:=body.global_position
	var to:=before+Vector3(0,0,-.09*4.1)
	var payload:={"r":(to.z+45.1)/4.1,"c":(to.x+395.65)/4.1}
	# Native static wall intrudes into the requested movement/footprint.
	var wall:=StaticBody3D.new(); wall.collision_layer=1; wall.collision_mask=1
	var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(.1,2,.1); shape.shape=box
	wall.add_child(shape); scene.add_child(wall); wall.global_position=to+Vector3.UP
	await physics_frame
	check(not owner._service(owner._row,payload,"path") and body.global_position==before,"actual wall denies knockback without position write")
	wall.queue_free(); await physics_frame; await physics_frame
	var other: CharacterBody3D=hit_owners[1]._token.body
	var other_before:=other.global_position; other.global_position=to
	await physics_frame
	check(not owner._service(owner._row,payload,"path") and body.global_position==before,"other actual NPC footprint denies knockback")
	other.global_position=other_before; await physics_frame
	var physical: RefCounted=host._ragdolls[owner._token.source_id]
	physical.mode="ACTIVE" # guard-only physical lease fault, no artificial hit
	check(not owner._service(owner._row,payload,"path") and body.global_position==before,"active physical lease denies walking displacement")
	physical.mode="IDLE"
	var admit: Callable=host._admit
	host._admit=func(_p:Vector3,_id:String,_g:int,_radius:float,_purpose:String)->bool:
		body.collision_mask=0
		return true
	check(not owner._service(owner._row,payload,"path") and body.global_position==before,"source callback collider mutation rejected")
	body.collision_mask=1; host._admit=admit
	check(owner._service(owner._row,payload,"path") and body.global_position.distance_to(to)<.0001,"authorized footprint+sweep source move succeeds")
	await cleanup_actors()

func negative_cases() -> void:
	await setup_actors()
	# Unit fault injection below deliberately tests receipt/lease guards, never
	# presented as a native collision or an authenticated source event.
	var owner: RefCounted=hit_owners[0]
	var body: CharacterBody3D=owner._token.body
	var origin:=body.global_position+Vector3(0,1.1,.8)
	var point:=body.global_position+Vector3.UP*1.1
	var shot:=shot_for("shotgun")
	weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	var receipt:={"weaponId":"shotgun","shotId":shot.shotId,"producerEpoch":weapons.effects.resolution_epoch(),"projectileCount":7,"projectileIndex":0,"status":"hit","point":point,"normal":Vector3.BACK,"direction":Vector3.FORWARD,"collider":body}
	for i in 6:
		receipt.projectileIndex=i; owner._on_projectile_resolved(receipt)
		owner._on_projectile_resolved(receipt) # duplicate
	check(owner._row.hp==60 and owner._shots[shot.shotId].terminals.size()==6,"incomplete/duplicate pellets never damage")
	receipt.projectileIndex=6; receipt.status="cancelled"; owner._on_projectile_resolved(receipt)
	check(owner._row.hp==60 and owner._shots[shot.shotId].used,"cancel discards entire salvo")
	shot=shot_for("shotgun"); weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	receipt.shotId=shot.shotId; receipt.status="hit"; receipt.producerEpoch-=1
	owner._on_projectile_resolved(receipt)
	check(owner._row.hp==60 and owner._shots[shot.shotId].used,"epoch mismatch discards salvo")
	shot=shot_for("shotgun"); weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	owner._shots[shot.shotId].at_ms-=15001
	HitOwner._registries[owner._registry_key].cleanup_at_ms=0.0
	owner.step()
	check(not owner._shots.has(shot.shotId) and owner._row.hp==60,"TTL discards without HP")
	for i in 140:
		shot=shot_for("shotgun"); weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	check(owner._shots.size()==128,"shot registry bounded128")
	# Stale target life after early receipts may not mutate the replacement.
	shot=shot_for("shotgun"); weapons.shot_emitted.emit(shot,{"origin":origin},origin,Vector3.FORWARD)
	receipt.shotId=shot.shotId; receipt.producerEpoch=weapons.effects.resolution_epoch(); receipt.status="hit"; receipt.projectileIndex=0
	owner._on_projectile_resolved(receipt)
	host._records[owner._token.source_id].owner._life_generation+=1
	for i in range(1,7): receipt.projectileIndex=i; hit_owners[1]._on_projectile_resolved(receipt)
	check(owner._row.hp==60,"stale grouped target generation denied")
	await cleanup_actors()

func _initialize() -> void: run.call_deferred()
