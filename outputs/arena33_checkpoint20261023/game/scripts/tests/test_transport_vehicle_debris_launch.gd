extends SceneTree
const Launch = preload("res://scripts/transport/transport_vehicle_debris_launch.gd")
func _initialize() -> void:
	var failures: Array[String] = []
	var checks := 0
	for i in range(10):
		var result: Dictionary = Launch.explosion(i,Vector3(1,0,0),10,0,[.5,.5,.5,.5,.5,.5,.5])
		checks+=1
		if not result.ok or not result.linear_velocity_mps.is_equal_approx(Vector3(3.5+i%3*.65,4,-10)) or result.angular_velocity_rad_s!=Vector3.ZERO: failures.append("exact median launch "+str(i))
	for invalid in [[.5], [.5,.5,.5,.5,.5,.5,1], [.5,.5,.5,.5,.5,.5,NAN]]:
		checks+=1
		if Launch.explosion(0,Vector3.ZERO,0,0,invalid).ok: failures.append("invalid draws")
	var fallback: Dictionary = Launch.explosion(0,Vector3.ZERO,-100,PI/2,[.5,.5,0,0,0,.5,1-.000001])
	checks+=1
	if not fallback.linear_velocity_mps.is_equal_approx(Vector3(31.5,2.8,0)) or not fallback.angular_velocity_rad_s.is_equal_approx(Vector3(3,0,-2.999994)): failures.append("fallback native parity reverse cap")
	var mixed: Dictionary=Launch.explosion(4,Vector3(-2,9,3),-50,.7,[.8,.2,.9,.25,.1,.75,.6])
	checks+=1
	if mixed.linear_velocity_mps.distance_to(Vector3(21.806572248726113,4.96,29.96312836493927))>.00001 or mixed.angular_velocity_rad_s.distance_to(Vector3(2.4,1.5,-.6))>.000001 or not is_equal_approx(mixed.source_landing_yaw,PI/2): failures.append("independent mixed JS oracle")
	print("TRANSPORT_DEBRIS_LAUNCH ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
