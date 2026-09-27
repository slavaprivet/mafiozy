extends SceneTree
const Policy = preload("res://scripts/character_physics/character_impact_policy.gd")
# Explicit TEST tuning, never a production default or a calibre/damage model.
const PROFILE := {"mass_kg":80.0,"max_impulse_ns":10000.0,"stance_thresholds_mps":{"standing":1.2,"crouched":1.6,"prone":2.0,"airborne":.8,"seated":2.4}}
var checks := 0
var failures: Array[String] = []
var worker_policy: RefCounted
var worker_result := {}
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func event(id: String, impulse: Vector3 = Vector3(4,0,0), kind: String = "bullet") -> Dictionary:
	return {"actor_id":"resident_72","life_generation":1,"session_id":"test-session-a","event_id":id,"kind":kind,"world_point":Vector3(3,1.5,-2),"impulse_ns":impulse,"stance":"standing"}
func worker() -> void: worker_result = worker_policy.consume(event("worker"))
func run() -> void:
	var policy := Policy.new()
	check(not policy.consume(event("unbound")).ok, "unconfigured input refused")
	check(not policy.configure("",1,"test-session-a",PROFILE).ok, "empty actor refused")
	check(not policy.configure("resident_72",0,"test-session-a",PROFILE).ok, "invalid generation refused")
	for invalid: Variant in [0.0,-1.0,NAN,INF,"80",true]:
		var profile := PROFILE.duplicate(true); profile.mass_kg = invalid
		check(not policy.configure("resident_72",1,"test-session-a",profile).ok, "invalid body mass " + str(invalid))
	var profile := PROFILE.duplicate(true); profile.stance_thresholds_mps.standing = NAN
	check(not policy.configure("resident_72",1,"test-session-a",profile).ok, "nonfinite balance threshold refused")
	profile = PROFILE.duplicate(true); profile.stance_thresholds_mps.drunk = 1.0
	check(not policy.configure("resident_72",1,"test-session-a",profile).ok, "unknown stance refused")
	profile = PROFILE.duplicate(true); profile.max_impulse_ns = INF
	check(not policy.configure("resident_72",1,"test-session-a",profile).ok, "unbounded impulse refused")
	profile = PROFILE.duplicate(true)
	check(policy.configure("resident_72",1,"test-session-a",profile).ok, "configured explicit physical profile")
	profile.mass_kg = 1; profile.stance_thresholds_mps.standing = .00001
	check(not policy.configure("resident_72",1,"test-session-a",PROFILE).ok, "cannot silently reconfigure current life")
	var bullet := event("bullet-small")
	var result: Dictionary = policy.consume(bullet)
	check(result.ok and result.reaction == "local" and not result.request_physical_knockdown, "small bullet localized stable standing")
	check(result.mass_kg == 80 and result.threshold_mps == 1.2, "profile copied not caller mutable")
	check(result.world_point == bullet.world_point and result.impulse_ns == bullet.impulse_ns, "localized point and impulse unchanged")
	check(result.delta_velocity_mps.is_equal_approx(Vector3(.05,0,0)), "delta velocity is physical J divided by mass")
	check(not result.has("hp") and not result.has("damage") and result.proposal_only, "no health result or authority write")
	check(policy.consume(bullet).error == "duplicate_event", "exact duplicate refused")
	bullet.impulse_ns = Vector3(400,0,0)
	check(policy.consume(bullet).error == "duplicate_event", "same event cannot upgrade its impulse")
	result.impulse_ns = Vector3.ZERO
	check(policy.consume(bullet).error == "duplicate_event", "result mutation cannot clear history")
	for field: String in ["actor_id","session_id","life_generation"]:
		var stale := event("stale-"+field)
		stale[field] = 2 if field == "life_generation" else "other"
		check(policy.consume(stale).error == "stale_target", "stale " + field)
	var invalid_event := event("invalid-then-fixed"); invalid_event.impulse_ns = Vector3(NAN,0,0)
	check(policy.consume(invalid_event).error == "impulse", "nonfinite impulse refused")
	invalid_event.impulse_ns = Vector3(1,0,0)
	check(policy.consume(invalid_event).ok, "invalid event did not poison dedup")
	for bad: Variant in [true,1.0,"yes",null]:
		var wrong := event("generation-type-"+str(bad)); wrong.life_generation = bad
		check(not policy.consume(wrong).ok, "generation must be integer")
	for bad: Variant in [1,"true",null]:
		var wrong := event("flag-"+str(bad)); wrong.authoritative_knockdown = bad
		check(policy.consume(wrong).error == "authority_flag", "authority flag strict bool")
	invalid_event = event("infinite-point"); invalid_event.world_point = Vector3(INF,0,0)
	check(policy.consume(invalid_event).error == "world_point", "nonfinite contact point refused")
	invalid_event = event("huge-point"); invalid_event.world_point = Vector3(20000000,0,0)
	check(policy.consume(invalid_event).error == "world_point", "excess contact coordinate refused")
	invalid_event = event("huge", Vector3(1e30,1e30,1e30))
	check(policy.consume(invalid_event).error == "excess_impulse", "huge finite vector cannot overflow magnitude")
	check(policy.consume(event("norm-bound",Vector3(8000,8000,0))).error == "excess_impulse", "vector norm not only per-component bound")
	invalid_event = event("bad-stance"); invalid_event.stance = "unknown"
	check(policy.consume(invalid_event).error == "stance", "unknown stance fail closed")
	invalid_event = event("bad-kind"); invalid_event.kind = "magic"
	check(policy.consume(invalid_event).error == "kind", "unknown kind refused")
	invalid_event = event("raw-damage"); invalid_event.damage = 100
	check(policy.consume(invalid_event).error == "event_schema", "raw combat event must be explicitly adapted")
	invalid_event = event("")
	check(policy.consume(invalid_event).error == "event_identity", "empty event id refused")
	check(policy.consume(event("x".repeat(257))).error == "event_identity", "bounded event id")
	check(policy.consume(event("below",Vector3(95.9,0,0))).reaction == "local", "below standing threshold localized")
	check(policy.consume(event("equal",Vector3(96,0,0))).reaction == "knockdown", "exact standing threshold requests physical owner")
	var crouch := event("crouch",Vector3(96,0,0)); crouch.stance = "crouched"
	check(policy.consume(crouch).reaction == "local", "caller stance changes balance threshold")
	var airborne := event("air",Vector3(70,0,0)); airborne.stance = "airborne"
	check(policy.consume(airborne).reaction == "knockdown", "airborne uses explicit threshold")
	var force := event("authoritative-fall",Vector3.ZERO,"fall"); force.authoritative_knockdown = true
	result = policy.consume(force)
	check(result.reaction == "knockdown" and result.impulse_ns == Vector3.ZERO, "authoritative falling adds no invented launch impulse")
	force = event("dead",Vector3.ZERO,"contact"); force.dead = true
	check(policy.consume(force).reason == "authoritative_dead", "authoritative dead request with no HP inference")
	var blocked_blast := event("blast-occluded",Vector3.ZERO,"blast")
	result = policy.consume(blocked_blast)
	check(result.reaction == "none" and result.impulse_ns == Vector3.ZERO, "caller blocked blast has no invented LOS or impulse")
	blocked_blast.impulse_ns = Vector3(1000,0,0)
	check(policy.consume(blocked_blast).error == "duplicate_event", "blocked blast cannot replay as positive")
	for kind: String in Policy.KINDS:
		result = policy.consume(event("strong-"+kind,Vector3(40,120,-20),kind))
		check(result.reaction == "knockdown" and result.impulse_ns == Vector3(40,120,-20), "same physical rule for " + kind)
	var melee := event("melee-local",Vector3(12,2,-4),"melee")
	melee.world_point = Vector3(-3.2,1.2,5.5)
	result = policy.consume(melee)
	check(result.reaction == "local" and result.world_point == melee.world_point and result.impulse_ns == melee.impulse_ns, "small melee localized at actual caller contact")
	var rotation := Basis(Vector3.UP,.73)
	var rotated := event("melee-rotated",rotation * melee.impulse_ns,"melee")
	rotated.world_point = rotation * melee.world_point
	var rotated_result: Dictionary = policy.consume(rotated)
	check(rotated_result.reaction == result.reaction and absf(rotated_result.delta_speed_mps-result.delta_speed_mps) < .000001, "world orientation does not invent force or random outcome")
	for actor: String in ["player:local","cop_42","resident_999"]:
		var shared := Policy.new(); shared.configure(actor,1,"test-session-a",PROFILE)
		var hit := event("same-event-name-per-target"); hit.actor_id = actor
		var reaction: Dictionary = shared.consume(hit)
		check(reaction.ok and reaction.actor_id == actor and reaction.reaction == "local", "same framework per owned character " + actor)
		shared.dispose()
	var heavy := Policy.new(); profile = PROFILE.duplicate(true); profile.mass_kg = 160
	heavy.configure("resident_72",1,"test-session-a",profile)
	check(heavy.consume(event("mass-test",Vector3(96,0,0))).reaction == "local", "body mass affects balance without calibre assumptions")
	heavy.dispose()
	var sum := Vector3.ZERO
	for i in 12:
		result = policy.consume(event("multi-"+str(i),Vector3(2,-1,.5)))
		check(result.reaction == "local", "multiple small hits remain local without invented accumulator")
		sum += result.delta_velocity_mps
	check((sum * 80).distance_to(Vector3(24,-12,6)) < .00001, "multiple accepted impulses conserve vector momentum")
	var bounded := Policy.new(); bounded.configure("resident_72",1,"test-session-a",PROFILE)
	for i in 65: check(bounded.consume(event("bounded-"+str(i))).ok, "bounded event " + str(i))
	check(bounded.state().remembered_events == 64, "history exactly bounded64")
	check(bounded.consume(event("bounded-1")).error == "duplicate_event", "oldest retained event refused")
	check(bounded.consume(event("bounded-0")).ok, "evicted event allowed documented bounded horizon")
	check(not bounded.reset_life("resident_72",1,"test-session-a",PROFILE).ok, "same life cannot clear history")
	check(not bounded.reset_life("other",2,"test-session-a",PROFILE).ok, "same session cannot alias actor")
	profile = PROFILE.duplicate(true); profile.mass_kg = 0
	check(not bounded.reset_life("resident_72",2,"test-session-a",profile).ok, "invalid new profile cannot reset dedup")
	check(bounded.consume(event("bounded-64")).error == "duplicate_event", "failed reset preserved history")
	check(bounded.reset_life("resident_72",2,"test-session-a",PROFILE).ok and bounded.state().remembered_events == 0, "new life clears bounded history")
	check(bounded.consume(event("bounded-64")).error == "stale_target", "old actor life refused after reset")
	var renewed := event("bounded-64"); renewed.life_generation = 2
	check(bounded.consume(renewed).ok, "same event name may exist in new life")
	check(bounded.reset_life("resident_72",1,"test-session-b",PROFILE).ok, "explicit new session begins new binding")
	check(not bounded.consume(renewed).ok, "old session callback refused")
	worker_policy = policy
	var thread := Thread.new(); thread.start(worker); thread.wait_to_finish()
	check(not worker_result.ok, "worker cannot race dedup")
	# Real engine momentum check: one body, no contacts/gravity/damping. This is
	# only the physical sink contract, not an actor ragdoll or combat integration.
	var physical: Dictionary = await physical_sink()
	var timings: Array[int] = []
	for i in 2000:
		var sample := event("cost-"+str(i),Vector3(3,2,-1))
		var at := Time.get_ticks_usec(); policy.consume(sample); timings.append(Time.get_ticks_usec()-at)
	timings.sort()
	policy.dispose(); policy.dispose()
	check(not policy.consume(event("after-dispose")).ok and policy.state().remembered_events == 0, "dispose rejects and clears bounded references")
	print(JSON.stringify({"checks":checks,"failures":failures,"physical_sink":physical,"consume_us":{"p50":timings[1000],"p95":timings[1900],"max":timings[-1]},"scope":"headless policy and one native body; no full-scene FPS/combat/ragdoll integration"}))
	quit(0 if failures.is_empty() else 1)

func physical_sink() -> Dictionary:
	var world := Node3D.new(); root.add_child(world)
	var body := RigidBody3D.new(); body.mass = 80; body.gravity_scale = 0; body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE; body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0; body.angular_damp = 0; body.collision_layer = 0; body.collision_mask = 0
	var collision := CollisionShape3D.new(); var shape := SphereShape3D.new(); shape.radius = .5; collision.shape = shape
	body.add_child(collision); world.add_child(body)
	await physics_frame; await physics_frame
	var policy := Policy.new(); policy.configure("resident_72",1,"test-session-a",PROFILE)
	var expected := Vector3.ZERO
	for i in 3:
		var impulse := Vector3(2+i,1,-.5)
		var input := event("physical-"+str(i),impulse,"contact")
		input.world_point = body.global_position + Vector3(.3,0,0)
		var receipt: Dictionary = policy.consume(input)
		# This fixture impulse has NOT already been applied by a contact solver.
		body.apply_impulse(receipt.impulse_ns, receipt.world_point - body.global_position); expected += impulse / body.mass
		await physics_frame; await physics_frame
	check(body.linear_velocity.distance_to(expected) < .00001, "actual native off-centre impulse conserves linear momentum")
	check(body.angular_velocity.length() > 0, "actual local point produces rotation without extra torque application")
	var before := body.linear_velocity
	check(not policy.consume(event("physical-2",Vector3(4,1,-.5),"contact")).ok, "duplicate never reaches sink")
	await physics_frame; await physics_frame
	check(body.linear_velocity.distance_to(before) < .00001, "duplicate causes no second physical impulse")
	var report := {"expected_velocity":expected,"actual_velocity":body.linear_velocity,"momentum_error_ns":(body.linear_velocity-expected).length()*body.mass,"angular_speed":body.angular_velocity.length()}
	policy.dispose(); world.free(); return report

func _initialize() -> void: call_deferred("run")
