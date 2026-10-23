extends SceneTree
const Launch=preload("res://scripts/transport/transport_vehicle_structural_launch.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func point(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[1]),float(values[2]))
func _initialize() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/structural_launch_oracle.json"))
	check(fixture.get("schema")=="mafiozi.transport-structural-launch-oracle.v1","fixture schema")
	check(fixture.get("source_sha256")=="cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44","actual source SHA")
	var overflow_rows:=0
	for row: Dictionary in fixture.rows:
		var result:=Launch.launch(row.id,int(row.impact_count),point(row.normal_native),float(row.impact_speed_mps),float(row.signed_speed_mps),float(row.travel_yaw_native))
		check(result.ok,"oracle admitted "+row.id)
		check(result.source_seed_u32==int(row.seed_u32),"JS binary64 >>>0 seed "+row.id)
		check(result.linear_velocity_mps.distance_to(point(row.linear_velocity_native))<1e-10,"native velocity "+row.id)
		check(result.angular_velocity_rad_s.distance_to(point(row.angular_velocity_native))<1e-10,"native spin "+row.id)
		check(result.mass_kg==float(row.mass_kg) and result.deterministic_sine_draws==6 and result.shared_rng_draws==0,"mass, six sine evaluations and zero shared RNG "+row.id)
		if row.seed_exceeds_safe_integer: overflow_rows+=1
	check(fixture.rows.size()==12 and overflow_rows>=1,"all part IDs covered with floating seed overflow cases")
	var first_impact_seeds:=[5055518,167898866,3506438144,1073741824,2043674624,3221225472,4010745856,4009048768,2147483648,0,3120562176,2147483648]
	for index in Launch.PART_IDS.size():
		check(Launch.launch(Launch.PART_IDS[index],1,Vector3.ZERO,8.0,0.0,0.0).source_seed_u32==first_impact_seeds[index],"independent first-impact JS seed "+Launch.PART_IDS[index])
	var hood_case:=Launch.launch("hood",1,Vector3(0,0,-1),8.0,10.0,0.0)
	check(hood_case.linear_velocity_mps.distance_to(Vector3(-.564457528674,2.934633032622,-4.66361080116))<1e-9,"independent hood native launch")
	check(hood_case.angular_velocity_rad_s.distance_to(Vector3(-3.372097274336,-1.850327272668,.645758888589))<1e-9,"independent hood native spin")
	var wheel_case:=Launch.launch("wheel_front_right",1,Vector3(.6,0,-.8),24.0,-12.0,.7)
	check(wheel_case.linear_velocity_mps.distance_to(Vector3(2.391740463,4.181831193,8.300477636))<2e-6 and wheel_case.angular_velocity_rad_s.distance_to(Vector3(.596353260,-1.892749121,-3.385197513))<2e-6,"independent wheel native launch")
	for args in [
		["forged",0,Vector3.ZERO,8.0,0.0,0.0],
		["hood",-1,Vector3.ZERO,8.0,0.0,0.0],
		["hood",0,Vector3(NAN,0,0),8.0,0.0,0.0],
		["hood",0,Vector3.ZERO,NAN,0.0,0.0],
		["hood",0,Vector3.ZERO,-1.0,0.0,0.0],
		["hood",0,Vector3.ZERO,8.0,INF,0.0],
		["hood",0,Vector3.ZERO,8.0,0.0,NAN],
		["hood",0,Vector3(3e38,0,0),24.0,0.0,0.0]]:
		check(not Launch.launch(args[0],args[1],args[2],args[3],args[4],args[5]).ok,"malformed input rejected")
	var fallback:=Launch.launch("hood",0,Vector3.ZERO,0.0,1000.0,0.0)
	var explicit:=Launch.launch("hood",0,Vector3.ZERO,8.0,1000.0,0.0)
	check(fallback.linear_velocity_mps.is_equal_approx(explicit.linear_velocity_mps),"source impact zero uses fallback eight")
	check(absf(fallback.linear_velocity_mps.z)>700.0,"signed vehicle speed remains source-unbounded")
	print("TRANSPORT_STRUCTURAL_LAUNCH ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"source_rows":fixture.rows.size(),"scope":"pure original structural launch oracle; no damage authority or physical spawn"}))
	quit(0 if failures.is_empty() else 1)
