extends SceneTree
const Dent=preload("res://scripts/transport/transport_local_dent.gd")
const Candidate=preload("res://scripts/transport/candidates/transport_local_dent_cost_candidate.gd")
const Cache=preload("res://scripts/transport/transport_deformation_blueprint_cache.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Solver=preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	if not loaded.ok: failures.append("visual"); _finish({}); return
	var visual=loaded.visual; world.add_child(visual.root)
	var source_row: Dictionary={}
	for row: Dictionary in Bindings.load_oracle().rows:
		if row.profile_id=="compact_sedan": source_row=row; break
	var bound:=Bindings.bind(visual,source_row)
	if not bound.ok: failures.append("bindings"); _finish({}); return
	var cache:=Cache.new()
	var prepared:=cache.acquire(visual,world,bound.crash_profile_source,{"source_sha256":"cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44","visual_manifest_sha256":Solver.VISUAL_MANIFEST_SHA256,"asset_generation":"dent-cost-source-v1"})
	if not prepared.ok: failures.append("prepare"); _finish({}); return
	var largest:=PackedVector3Array(); var label:=""
	for row: Dictionary in prepared.rows:
		for surface: Dictionary in row.surfaces:
			var vertices: PackedVector3Array=surface.base
			if vertices.size()>largest.size(): largest=vertices; label=row.label
	var positions:=PackedFloat32Array(); positions.resize(largest.size()*3)
	var bounds:=AABB(largest[0],Vector3.ZERO)
	for i in largest.size():
		positions[i*3]=largest[i].x; positions[i*3+1]=largest[i].y; positions[i*3+2]=largest[i].z
		bounds=bounds.expand(largest[i])
	var centre:=bounds.get_center()
	var point:=PackedFloat64Array([centre.x,centre.y,centre.z])
	var baseline:=measure(Dent,positions,point)
	var actual:=measure(Candidate,positions,point)
	var ceiling:=PackedFloat32Array(); ceiling.resize(Dent.MAX_POSITION_VALUES); ceiling.fill(0.0)
	var max_baseline:=measure(Dent,ceiling,PackedFloat64Array([0.0,0.0,0.0]))
	var maximum:=measure(Candidate,ceiling,PackedFloat64Array([0.0,0.0,0.0]))
	if not baseline.ok or not actual.ok or not max_baseline.ok or not maximum.ok: failures.append("measurement")
	var result={"actual_panel":label,"baseline":baseline,"candidate":actual,"bounded_90k_baseline":max_baseline,"bounded_90k_candidate":maximum,"scope":"same prepared geometry sequential baseline/candidate position core only; no normals/bounds/mesh upload/hulls/full scene; preparation excluded"}
	cache.dispose(); visual.dispose(); world.free(); _finish(result)
func measure(kernel: GDScript,initial: PackedFloat32Array,point: PackedFloat64Array) -> Dictionary:
	var dent=kernel.new(); var configured: Dictionary=dent.configure(initial,1)
	if not configured.ok: return configured
	var current:=initial.duplicate(); var samples: Array[int]=[]; var affected:=0
	for i in 40:
		var begin:=Time.get_ticks_usec()
		var result: Dictionary=dent.apply(current,point,PackedFloat64Array([0.0,1.0,0.0]),0.0,{"impactSpeed":14.0},1)
		if result.ok:
			var committed: Dictionary=dent.commit(result.stage_token)
			if not committed.ok: dent.dispose(); return committed
		var elapsed:=Time.get_ticks_usec()-begin
		if not result.ok: dent.dispose(); return result
		current=result.positions; affected=result.affected
		if i>=8: samples.append(elapsed)
	samples.sort(); dent.dispose()
	return {"ok":true,"vertices":initial.size()/3,"samples":samples.size(),"p50_us":samples[15],"p95_us":samples[30],"max_us":samples[-1],"affected_last":affected}
func _finish(metrics: Dictionary) -> void:
	print("TRANSPORT_LOCAL_DENT_COST_COMPARISON ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
