extends SceneTree
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Panels = preload("res://scripts/vehicle_visual/vehicle_compartments.gd")
const Evidence = preload("res://scripts/transport/transport_cargo_evidence.gd")
const Admission = preload("res://scripts/transport/transport_cargo_admission.gd")
var checks := 0
var failures: Array[String] = []
var sample_us: Array[int] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var catalog := Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	for id in catalog.entries:
		var loaded := Visual.instantiate_visual(catalog.entries[id],catalog.base_path)
		check(loaded.get("ok",false), "actual visual admitted "+id)
		if not loaded.get("ok",false): continue
		var visual = loaded.visual; root.add_child(visual.root)
		var panels := Panels.new(); check(panels.configure(visual).ok, "actual panels configured")
		var evidence := Evidence.new(); check(evidence.configure(visual,panels).ok, "exact lid geometry bound")
		var mismatched := Evidence.new(); check(not mismatched.configure(visual,Panels.new()).ok, "unbound compartments instance rejected")
		var closed := evidence.sample()
		check(not closed.is_empty() and closed.has_floor and closed.amount == 0.0, "actual visible cargo floor found")
		check(closed.lid_bounds.get_center().z > 0.0, "rear lid source coordinates converted to native positive Z " + id + " root=" + String(visual.root.name) + " basis=" + str(visual.root.basis) + " lid=" + str(closed.lid_bounds))
		var center: Vector3 = closed.bounds.get_center(); var half: Vector3 = closed.bounds.size*.05
		check(not Admission.accepts(closed.bounds,center,half,closed.amount,false,closed.has_floor,closed.mode,closed.lid_visible,closed.lid_bounds), "closed actual lid denies placement")
		panels.set_open("trunk",true)
		for i in 90: panels.step(1.0/60.0)
		var started := Time.get_ticks_usec(); var opened := evidence.sample(); sample_us.append(Time.get_ticks_usec()-started)
		check(opened.amount == 1.0 and opened.lid_bounds != closed.lid_bounds, "actual animated lid sampled")
		check(Admission.accepts(opened.bounds,center,half,opened.amount,false,opened.has_floor,opened.mode,opened.lid_visible,opened.lid_bounds), "actual raised lid admits small cargo "+id)
		visual.root.transform = Transform3D(Basis(Vector3.UP,.6)*Basis(Vector3.RIGHT,.3),Vector3(20,4,-8))
		var rolled := evidence.sample()
		check(rolled.lid_bounds.position.distance_to(opened.lid_bounds.position)<.00001 and rolled.lid_bounds.size.distance_to(opened.lid_bounds.size)<.00001, "moving/rolled car preserves native-local lid evidence")
		visual.root.visible = false
		check(evidence.sample().has_floor, "render hiding preserves source construction-time floor proof")
		visual.root.visible = true
		evidence.invalidate_geometry(); check(evidence.sample().is_empty(), "damage geometry invalidation fails closed")
		panels.dispose(); visual.dispose()
	sample_us.sort()
	print(JSON.stringify({"checks":checks,"failures":failures,"profiles":catalog.entries.size(),"sample_p50_us":sample_us[sample_us.size()/2],"sample_max_us":sample_us.back(),"scope":"actual GLB/panel cargo evidence; no inventory transfer or GPU"}))
	quit(0 if failures.is_empty() else 1)
