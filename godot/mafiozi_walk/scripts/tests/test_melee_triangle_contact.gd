extends SceneTree
const Contact = preload("res://scripts/combat/melee_triangle_contact.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func vec(values: Array) -> Vector3: return Vector3(values[0],values[1],values[2])
func _initialize() -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_triangle_oracle.json"))
	var greatest := 0.0
	for i in oracle.rows.size():
		var row: Dictionary = oracle.rows[i]
		var result := Contact.sample(vec(row.from),vec(row.to),row.radius,vec(row.triangle[0]),vec(row.triangle[1]),vec(row.triangle[2]))
		check(result.get("valid",false),"valid fixture "+str(i))
		check(result.get("hit",false) == (row.expected != null),"hit/miss "+str(i))
		if row.expected != null and result.get("hit",false):
			var difference: float = result.point.distance_to(vec(row.expected.point)); greatest=maxf(greatest,difference)
			check(difference < .00003,"source surface point "+str(i))
			check(result.normal.distance_to(vec(row.expected.normal)) < .00003,"source outward normal "+str(i))
			check(result.weights.distance_to(vec(row.expected.weights)) < .00005,"source barycentric anchor "+str(i))
			check(absf(sqrt(result.score)-float(row.expected.distance)) < .00003,"source winner score "+str(i))
	for bad in [NAN,INF,-1.0,0.0,.500001]:
		check(not Contact.sample(Vector3.ZERO,Vector3.ONE,bad,Vector3.ZERO,Vector3.RIGHT,Vector3.UP).valid,"invalid radius")
	check(not Contact.sample(Vector3(NAN,0,0),Vector3.ONE,.1,Vector3.ZERO,Vector3.RIGHT,Vector3.UP).valid,"nonfinite sweep")
	# Regressions confirmed against the original full Three/SkinnedMesh contact path.
	# A float32 determinant used to return incorrect/NaN anchors on these real-scale faces.
	for width: float in [.01,.001,.0003,.0001,.00001]:
		var thin := Contact.sample(Vector3(.5,width*.25,1),Vector3(.5,width*.25,-1),.1,Vector3.ZERO,Vector3.RIGHT,Vector3(1,width,0))
		check(thin.get("valid",false) and thin.get("hit",false),"thin triangle contact "+str(width))
		check(thin.get("weights",Vector3.INF).distance_to(Vector3(.5,.25,.25)) < .0001,"thin triangle anchor "+str(width))
		check(thin.get("point",Vector3.INF).distance_to(Vector3(.5,width*.25,0)) < .00003,"thin triangle surface "+str(width))
	# Preserve source strict tie ordering: the first closest edge endpoint wins.
	var parallel := Contact.sample(Vector3(-.2,-.05,0),Vector3(1.2,-.05,0),.1,Vector3.ZERO,Vector3.RIGHT,Vector3.UP)
	check(parallel.get("valid",false) and parallel.get("hit",false),"parallel edge contact")
	check(parallel.get("point",Vector3.INF).distance_to(Vector3.ZERO) < .00003,"parallel edge source winner")
	check(parallel.get("weights",Vector3.INF).distance_to(Vector3(1,0,0)) < .0001,"parallel edge source anchor")
	for triangle: Array in [[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO],[Vector3.ZERO,Vector3.RIGHT,Vector3.RIGHT*2]]:
		var degenerate := Contact.sample(Vector3(0,0,1),Vector3.ZERO,.1,triangle[0],triangle[1],triangle[2])
		check(degenerate.get("valid",false) and not degenerate.get("hit",true),"degenerate face is a source miss")
	print(JSON.stringify({"checks":checks,"failures":failures,"max_source_point_error_m":greatest,"scope":"pure triangle kernel; no actor/occlusion/HP claim"}))
	quit(0 if failures.is_empty() else 1)
