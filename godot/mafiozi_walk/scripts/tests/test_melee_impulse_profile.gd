extends SceneTree
const Profile=preload("res://scripts/character_physics/melee_impulse_profile.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func contact()->Dictionary:
	return {"admitted":true,"world_point":Vector3(1,1.2,-3),"outward_normal":Vector3.LEFT,"attack_direction":Vector3.RIGHT,"attacker_point_velocity_mps":Vector3(5,0,0),"defender_point_velocity_mps":Vector3.ZERO,"attacker_mass_kg":75.0,"defender_mass_kg":80.0,"stance":"standing"}
func run()->void:
	var input:=contact();var tuning:=Profile.authored_profile("punch");var original:=input.duplicate(true)
	var output:=Profile.propose(input,tuning)
	var expected:=1.05*3.0*80.0/83.0*5.0
	check(output.ok and absf(output.magnitude_ns-expected)<.00001,"analytic reduced mass")
	check((output.impulse_ns as Vector3).distance_to(Vector3(expected,0,0))<.00001,"signed inward impulse")
	check(input==original and output.world_point==input.world_point,"input and offcentre worldpoint preserved")
	check(not output.has("torque") and not output.has("damage") and not output.has("hp") and output.proposal_only and not output.balance_approved,"no torque/damage authority or approved balance")
	check(output.authored==tuning and output.measured.attacker_point_velocity_mps==input.attacker_point_velocity_mps,"authored and actual measurements separate")
	# Normal elastic/restitution identity for this scalar translational model.
	var striker_after: float=5.0-output.magnitude_ns/3.0
	var defender_after: float=output.magnitude_ns/80.0
	check(absf((striker_after-defender_after)+.05*5.0)<.00001,"restitution relative velocity")
	check(absf(3.0*striker_after+80.0*defender_after-15.0)<.00001,"equal-opposite scalar momentum model")
	for attack: String in ["punch","shove","kick"]:
		var config:=Profile.authored_profile(attack)
		var c:=contact();var previous: float=-1
		for speed in 21:
			c.attacker_point_velocity_mps=Vector3(speed,0,0)
			var result:=Profile.propose(c,config)
			check(result.ok and result.magnitude_ns>=previous and result.magnitude_ns<=config.impulse_limit_ns,"monotone bounded "+attack+str(speed))
			check(result.model.used_closing_speed_mps<=config.strike_speed_limit_mps,"profile never adds speed")
			previous=result.magnitude_ns
	for stance: String in Profile.STANCES:
		var c:=contact();c.stance=stance
		var result:=Profile.propose(c,tuning)
		check(result.ok and result.stance==stance and result.impulse_ns==output.impulse_ns,"stance goes to reaction policy without second force multiplier")
	for velocity: Vector3 in [Vector3.ZERO,Vector3.LEFT*3,Vector3.UP*4]:
		var c:=contact();c.attacker_point_velocity_mps=velocity
		var result:=Profile.propose(c,tuning)
		check(result.ok and result.magnitude_ns==0 and result.reason=="separating_or_stationary","separating/stationary/tangent suppressed")
	var away:=contact();away.attack_direction=Vector3.LEFT
	check(Profile.propose(away,tuning).magnitude_ns==0,"backface attack suppressed")
	var moving:=contact();moving.defender_point_velocity_mps=Vector3(7,0,0)
	check(Profile.propose(moving,tuning).magnitude_ns==0,"faster departing defender suppressed")
	# Shared carrier velocity must not change relative contact momentum.
	moving=contact();moving.attacker_point_velocity_mps+=Vector3(4,3,-2);moving.defender_point_velocity_mps+=Vector3(4,3,-2)
	check(Profile.propose(moving,tuning).impulse_ns==output.impulse_ns,"Galilean invariance")
	for angle: float in [.4,1.2,2.7]:
		var basis:=Basis(Quaternion(Vector3(1,.2,.3).normalized(),angle));var c:=contact()
		for field: String in ["outward_normal","attack_direction","attacker_point_velocity_mps","defender_point_velocity_mps"]:c[field]=basis*c[field]
		var result:=Profile.propose(c,tuning)
		check(result.ok and (result.impulse_ns as Vector3).distance_to(basis*output.impulse_ns)<.00001,"world rotation covariance")
	var capped:=tuning.duplicate();capped.impulse_limit_ns=2.0
	check(Profile.propose(input,capped).magnitude_ns==2.0 and Profile.propose(input,capped).model.impulse_limited,"explicit authored impulse cap")
	var source:=contact();source.damage=999999;source.npcId="source169";source.attack_id="same-authoritative-id"
	check(Profile.propose(source,tuning).impulse_ns==output.impulse_ns and source.npcId=="source169","HP/IDs do not create force or get rewritten")
	for bad: Dictionary in [{"admitted":false},{"admitted":1},{"world_point":Vector3(NAN,0,0)},{"outward_normal":Vector3.ZERO},{"outward_normal":Vector3(2,0,0)},{"attack_direction":Vector3(INF,0,0)},{"attacker_point_velocity_mps":Vector3(1e30,0,0)},{"defender_point_velocity_mps":Vector3(NAN,0,0)},{"attacker_mass_kg":0.0},{"defender_mass_kg":INF},{"stance":"unknown"}]:
		var c:=contact();c.merge(bad,true);check(not Profile.propose(c,tuning).ok,"malformed contact "+str(bad.keys()))
	var incomplete:=contact();incomplete.erase("attacker_point_velocity_mps");check(not Profile.propose(incomplete,tuning).ok,"missing measured limb speed rejected")
	for bad: Dictionary in [{"effective_striking_mass_kg":76.0},{"effective_striking_mass_kg":-1.0},{"restitution":1.01},{"strike_speed_limit_mps":0.0},{"impulse_limit_ns":1001.0},{"id":"fake_source_impulse"},{"attack":"dropkick"}]:
		var config:=tuning.duplicate();config.merge(bad,true);check(not Profile.propose(input,config).ok,"malformed tuning "+str(bad.keys()))
	check(Profile.authored_profile("dropkick").is_empty(),"no invented source animation mapping")
	var timings: Array[int]=[]
	for batch in 100:
		var began:=Time.get_ticks_usec()
		for i in 100:Profile.propose(input,tuning)
		timings.append(Time.get_ticks_usec()-began)
	timings.sort()
	var report: Dictionary={"checks":checks,"failures":failures,"punch_example_ns":expected,"cpu_per_call_us":{"p50":float(timings[50])/100,"p95":float(timings[95])/100},"qualification":"Pure CPU calibration proposal; no contact admission provider/HP mutation/physical application/standing gait or FPS acceptance."}
	var file:=FileAccess.open("res://../../outputs/coordinator21_vehicle_liveqa/melee_impulse_profile_test.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MELEE_IMPULSE_PROFILE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func _initialize()->void:run.call_deferred()
