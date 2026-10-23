extends SceneTree

const Descriptor = preload("res://scripts/traversal/ladder_descriptor.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var source := {"id":"descriptor", "lower":Vector3(0,0,1), "upper":Vector3(0,5,-.9), "outward":Vector3(0,0,1)}
	var result: Dictionary = Descriptor.normalize(source)
	check(result.valid, "valid source descriptor accepted")
	check(result.path.size() == 4 and result.path[1] == Vector3(0,5.12,1) and result.path[2] == Vector3(0,5.12,-.9), "crest and landing preserve source route")
	check(result.step_off_point == Vector3(0,5,-1.65), "exact .75m inward roof endpoint")
	check(is_equal_approx(float(result.width),.8) and is_equal_approx(float(result.rung_spacing),.28), "source defaults retained")
	check(is_equal_approx(float(result.aperture_width_m),1.1), "source aperture width retained")
	check(result.normal == Vector3(0,0,1) and result.right == Vector3(1,0,0) and is_equal_approx(absf(float(result.yaw_rad)),PI), "normal right and yaw retained")
	for bad: Dictionary in [
		{"lower":Vector3.ZERO,"upper":Vector3(0,1,0),"outward":Vector3.FORWARD},
		{"lower":Vector3.ZERO,"upper":Vector3(0,3,0),"outward":Vector3.ZERO},
		{"lower":Vector3(0,0,0),"upper":Vector3(0,3,.1),"outward":Vector3(0,0,1)},
		{"lower":Vector3.ZERO,"upper":Vector3(0,3,-1),"outward":Vector3(0,0,1),"width":.5},
		{"lower":Vector3.ZERO,"upper":Vector3(0,3,-1),"outward":Vector3(0,0,1),"rung_spacing":.5},
	]:
		check(not Descriptor.normalize(bad).valid, "invalid descriptor rejected: "+JSON.stringify(bad))
	print("LADDER_DESCRIPTOR_TEST ", JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
