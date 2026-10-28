extends SceneTree
const Cargo = preload("res://scripts/transport/transport_cargo_admission.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicle_visual/compartments.json"))
	for id in data.profiles:
		var source: Dictionary = data.profiles[id].cargo_bounds
		var lo := Vector3(-source.max[0],source.min[1],-source.max[2]); var hi := Vector3(-source.min[0],source.max[1],-source.min[2])
		var bounds := AABB(lo,hi-lo); var center := (lo+hi)*.5; var half := (hi-lo)*.1
		var cover := AABB(Vector3(lo.x,hi.y+.1,lo.z-2),Vector3(hi.x-lo.x,.1,.1))
		for mode in ["trunk","hatch","tailgate"]:
			check(Cargo.accepts(bounds,center,half,1,true,true,mode,true,cover), "detached lid with floor permits contained item "+id)
			check(not Cargo.accepts(bounds,center,half,.84,false,true,mode,true,cover), "closed lid rejects placement")
			check(not Cargo.accepts(bounds,center,half,1,true,false,mode,true,cover), "missing real cargo floor rejects")
			check(not Cargo.accepts(bounds,center,bounds.size,1,true,true,mode,true,cover), "oversized item rejects")
			check(not Cargo.accepts(bounds,center,Vector3(-1,0,0),1,true,true,mode,true,cover), "negative item extent rejects")
		var blocked := AABB(lo,bounds.size)
		var trunk_open := AABB(Vector3(lo.x,hi.y,lo.z-1),Vector3(bounds.size.x,.1,.1))
		var hatch_open := AABB(Vector3(lo.x,hi.y+.1,lo.z),Vector3(bounds.size.x,.1,bounds.size.z))
		var tailgate_open := AABB(Vector3(lo.x,lo.y-.2,lo.z),Vector3(bounds.size.x,.1,bounds.size.z))
		check(Cargo.accepts(bounds,center,half,.85,false,true,"trunk",true,trunk_open), "source .85 trunk opening admits small item")
		check(Cargo.accepts(bounds,center,half,.85,false,true,"hatch",true,hatch_open), "raised hatch admits small item")
		check(Cargo.accepts(bounds,center,half,.85,false,true,"tailgate",true,tailgate_open), "lowered tailgate admits small item")
		check(not Cargo.accepts(bounds,center,half,1,false,true,"trunk",true,blocked), "closed physical trunk opening rejects")
		check(not Cargo.accepts(bounds,center,half,1,false,true,"hatch",true,blocked), "hatch vertical opening rejects")
		check(not Cargo.accepts(bounds,center,half,1,false,true,"tailgate",true,blocked), "tailgate opening rejects")
		for angle in [0.0,.6,1.4]:
			var transform := Transform3D(Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,.2),Vector3(3,-2,7))
			var point := Cargo.world_item_local_bounds(transform,transform*center,Vector3.ZERO)
			check(not point.is_empty() and point.center.distance_to(center)<.00001, "world placement preserves local position after movement/roll")
	check(Cargo.world_item_local_bounds(Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO),Vector3.ZERO,Vector3.ONE).is_empty(), "singular vehicle transform rejects")
	var perf_bounds := AABB(Vector3.ZERO,Vector3.ONE)
	check(not Cargo.accepts(perf_bounds,Vector3(.5,.5,.5),Vector3.ZERO,1,true,true,"trunk",false,perf_bounds,false), "disposed or unavailable provider rejects")
	check(not Cargo.accepts(perf_bounds,Vector3(.5,.5,.5),Vector3.ZERO,1,true,true,"unknown",false,perf_bounds), "unknown panel mode rejects")
	var rotated := Cargo.world_item_local_bounds(Transform3D(Basis(Vector3.UP,PI*.5)*Basis(Vector3.FORWARD,PI*.25),Vector3.ZERO),Vector3.ZERO,Vector3(1,2,3))
	# Analytic oracle: yaw90 swaps X/Z; subsequent inverse roll45 combines
	# absolute X/Y contributions, so asymmetric world half(1,2,3) ->
	# local half(5/sqrt2,5/sqrt2,1). This is independent of corner enumeration.
	check(rotated.half.distance_to(Vector3(5.0/sqrt(2.0),5.0/sqrt(2.0),1))<.00001, "nonzero asymmetric AABB expands correctly under yaw and roll")
	check(Cargo.accepts(perf_bounds,Vector3(.5,.5,.5),Vector3(.1,.1,.1),1,false,true,"hatch",false,perf_bounds), "invisible lid skips aperture only")
	check(Cargo.accepts(perf_bounds,Vector3(-.00000005,.5,.5),Vector3.ZERO,1,true,true,"trunk",true,perf_bounds), "source containment tolerance admits 5e-8 margin")
	check(not Cargo.accepts(perf_bounds,Vector3(-.0000002,.5,.5),Vector3.ZERO,1,true,true,"trunk",true,perf_bounds), "outside containment tolerance rejects")
	var start := Time.get_ticks_usec()
	for i in 10000: Cargo.accepts(perf_bounds,Vector3(.5,.5,.5),Vector3(.1,.1,.1),1,true,true,"trunk",false,perf_bounds)
	print(JSON.stringify({"checks":checks,"failures":failures,"profiles":data.profiles.size(),"ten_thousand_queries_us":Time.get_ticks_usec()-start,"scope":"source placement geometry only; no storage/item identity or inventory mutation"}))
	quit(0 if failures.is_empty() else 1)
