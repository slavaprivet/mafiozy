extends SceneTree
const Access = preload("res://scripts/transport/transport_service_access.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicle_visual/compartments.json"))
	for id in data.profiles:
		for kind in ["hood", "trunk"]:
			var profile: Dictionary = data.profiles[id].panels[kind].access_profile
			var plane := float(profile.get("accessZ", profile.get("rearZ", 0.0)))
			var side := float(profile.get("accessSide", 0.0)) if kind == "hood" else 0.0
			var outward := (1.0 if profile.get("front", true) else -1.0) if kind == "hood" else -1.0
			for yaw in [0.0, .7, -1.4]:
				var transform := Transform3D(Basis(Vector3.UP,yaw),Vector3(13,2,-17))
				var feet := transform * Vector3(-side,0,-plane-outward*.5)
				var found := Access.query(kind,profile,transform,feet,0)
				check(not found.is_empty() and absf(found.near-.5)<.00001, "actual profile rotated planar reach "+id)
				check(Access.query(kind,profile,transform,feet,-.51).is_empty(), "negative speed gate")
				check(Access.query(kind,profile,transform,feet,0,{"occupied":true}).is_empty(), "occupant cannot open panel")
				var inside := transform * Vector3(-side,0,-plane+outward*.1)
				check(Access.query(kind,profile,transform,inside,0).is_empty(), "wrong side of service plane")
				check(Access.query(kind,profile,transform,feet+Vector3.UP*1.81,0).is_empty(), "vertical reach gate")
				if kind == "hood":
					check(Access.query(kind,profile,transform,feet,.2,{"amount":.9}).get("repair_available",false), "open hood admits repair query")
					check(not Access.query(kind,profile,transform,feet,.21,{"amount":1.0}).get("repair_available",false), "repair speed gate")
					check(Access.query(kind,profile,transform,feet,0,{"detached":true}).get("action","") == "repair", "detached hood repair query")
				else:
					check(Access.query(kind,profile,transform,feet,0,{"detached":true}).is_empty(), "detached trunk unavailable")
	check(Access.query("hood",{},Transform3D.IDENTITY,Vector3.ZERO,0).is_empty(), "missing exact profile fails closed")
	var perf_profile: Dictionary = data.profiles.city_hatchback.panels.hood.access_profile
	var perf_feet := Vector3(0,0,-float(perf_profile.accessZ)-.5)
	var invalid_profile := perf_profile.duplicate(true); invalid_profile.accessSide = "invalid"
	check(Access.query("hood",invalid_profile,Transform3D.IDENTITY,perf_feet,0).is_empty(), "malformed side offset fails closed")
	check(Access.query("hood",perf_profile,Transform3D.IDENTITY,perf_feet,0,{"amount":NAN}).is_empty(), "nonfinite panel amount fails closed")
	check(Access.query("hood",perf_profile,Transform3D.IDENTITY,perf_feet,NAN).is_empty(), "nonfinite speed fails closed")
	check(Access.query("hood",perf_profile,Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO),perf_feet,0).is_empty(), "degenerate basis rejected")
	for roll in [.3, -.7]:
		var basis := Basis(Vector3.UP,.7) * Basis(Vector3.RIGHT,.2) * Basis(Vector3.FORWARD,roll)
		var projected := (-basis.z).slide(Vector3.UP)
		var heading := atan2(-projected.x,-projected.z)
		var tilted := Transform3D(basis,Vector3(2,3,4))
		var feet := tilted.origin + Basis(Vector3.UP,heading) * perf_feet
		var result := Access.query("hood",perf_profile,tilted,feet,0)
		check(not result.is_empty() and absf(result.near-.5)<.00001, "pitched/rolled body uses projected authoritative heading")
	var start := Time.get_ticks_usec()
	for i in 10000: Access.query("hood",perf_profile,Transform3D.IDENTITY,perf_feet,0)
	print(JSON.stringify({"checks":checks,"failures":failures,"profiles":data.profiles.size(),"ten_thousand_queries_us":Time.get_ticks_usec()-start,"scope":"actual exported service profiles; query only, no inventory or repair commit"}))
	quit(0 if failures.is_empty() else 1)
