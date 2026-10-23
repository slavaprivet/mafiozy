extends SceneTree
const Dent=preload("res://scripts/transport/candidates/transport_local_dent_cost_candidate.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Cache=preload("res://scripts/transport/transport_deformation_blueprint_cache.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Solver=preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const ORACLE_PATH="res://data/transport/local_dent_oracle.json"
const ORACLE_SHA="790b7d5e93ddd2cc50db20010012fa786df65ad5dbef5df02910b44f35041059"
const SOURCE_SHA="e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92"
const ITERATIONS:=10000
var checks:=0
var failures: Array[String]=[]
var first_mismatch: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var bytes:=FileAccess.get_file_as_bytes(ORACLE_PATH); var fixture: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(_sha(bytes)==ORACLE_SHA,"pinned actual-source dent oracle")
	check(fixture is Dictionary and fixture.schema=="mafiozi.transport-local-dent-oracle.v1" and fixture.source.vehicle_damage.sha256==SOURCE_SHA and fixture.source.three_revision=="180","instrumented source receipt")
	check(fixture.scope.begins_with("position-buffer core only"),"oracle explicitly excludes preparation/normals/bounds integration")
	if not fixture is Dictionary: finish({}); return
	var provider:=Dent.new(); var generation:=1; var initial:=_f32(fixture.mesh.initial_positions)
	check(provider.configure(initial,generation).ok,"configure pure Float32 core")
	var prior_snapshot:=provider.snapshot()
	for step: Dictionary in fixture.steps:
		var before:=_f32(step.before)
		if step.label=="bullet_after_geometry_replacement":
			generation+=1; var reset:=provider.reset(before,generation,false)
			check(reset.ok and is_equal_approx(float(reset.max_depth),.40),"geometry replacement clears buffers but preserves collision cap")
		if step.label=="source_zero_normal":
			var zero_result:=provider.apply(before,_f64(step.local_point),_f64(step.local_normal),float(step.damage),{},generation)
			check(zero_result.error=="normal" and provider.snapshot()==prior_snapshot,"provider deliberately rejects source zero-normal presentation no-op")
			continue
		var collision: Dictionary={} if step.collision==null else {"impactSpeed":float(step.collision.impactSpeed)}
		var result:=provider.apply(before,_f64(step.local_point),_f64(step.local_normal),float(step.damage),collision,generation)
		check(result.ok,"apply "+step.label)
		if not result.ok: continue
		if first_mismatch.is_empty() and not _exact_f32(result.positions,step.after):
			first_mismatch={"label":step.label,"positions_actual":Array(result.positions).slice(0,9),"positions_expected":step.after.slice(0,9),"base_actual":Array(result.base).slice(0,9),"base_expected":step.state.base.slice(0,9),"offset_actual":Array(result.offset).slice(0,9),"offset_expected":step.state.offset.slice(0,9),"point":step.local_point,"normal":step.local_normal}
		check(_exact_f32(result.positions,step.after),"exact Float32 positions "+step.label)
		check(_exact_f32(result.base,step.state.base),"exact Float32 rebased base "+step.label)
		check(_exact_f32(result.offset,step.state.offset),"exact separately-rounded offset "+step.label)
		check(is_equal_approx(float(result.max_depth),float(step.state.max_depth)),"persistent max depth "+step.label)
		check(result.requires_geometry_refresh and int(result.affected)>=int(result.changed),"explicit host geometry refresh "+step.label)
		check(_finite_bounds(step.bounds),"actual source normals/bounds dependency receipt "+step.label)
		check(provider.commit(result.stage_token).ok,"commit after host buffer acceptance "+step.label)
		prior_snapshot=provider.snapshot()
	check(is_equal_approx(float(prior_snapshot.max_depth),.40),"collision cap remains after later bullet")
	var native_replay:=_native_axis_replay(fixture)
	check(native_replay.ok,"mapped native -X/-Z buffer replay exact")
	if not native_replay.ok and first_mismatch.is_empty(): first_mismatch=native_replay
	var full_reset:=provider.reset(initial,generation+1,true)
	check(full_reset.ok and is_zero_approx(float(full_reset.max_depth)) and _all_zero(provider.snapshot().offset),"full vehicle reset clears cap and offset")
	# Rejections are atomic and authority/lifecycle inputs cannot mutate buffers.
	var rejection_snapshot:=provider.snapshot()
	check(provider.reset(initial,generation,false).error=="generation","reset generation must advance monotonically")
	check(provider.apply(initial,_f64([0,0,0]),_f64([0,0,1]),24.0,{"impactSpeed":1.0,"extra":1},generation+1).error=="collision","collision dictionary is exact")
	check(provider.apply(initial,_f64([0,0,0]),_f64([0,0,2]),24.0,{},generation+1).error=="normal","non-unit normal rejected")
	check(provider.apply(initial,_f64([0,0,0]),_f64([0,0,1]),24.0,{},generation).error=="generation","stale generation rejected")
	check(provider.snapshot()==rejection_snapshot,"all rejected applies atomic")
	_transaction_checks(initial,generation+1)
	var benchmark:=Dent.new(); benchmark.configure(initial,7); var current:=initial; var sample: Dictionary=fixture.steps[0]; var begin:=Time.get_ticks_usec(); var checksum:=0
	for i in ITERATIONS:
		var applied:=benchmark.apply(current,_f64(sample.local_point),_f64(sample.local_normal),float(sample.damage),{},7)
		current=applied.positions; benchmark.commit(applied.stage_token); checksum+=int(applied.changed)
	var benchmark_us:=Time.get_ticks_usec()-begin
	check(checksum>=0,"10k cumulative benchmark consumed")
	var actual_metrics:=_actual_mesh_benchmark()
	check(actual_metrics.ok,"actual GLB mesh buffer benchmark")
	var cost_metrics:=_candidate_cost_metrics()
	check(cost_metrics.get("ok",false),"prepared actual and bounded maximum cost benchmark")
	provider.dispose(); benchmark.dispose()
	finish({"steps":fixture.steps.size(),"small_vertices":initial.size()/3,"iterations":ITERATIONS,"benchmark_us":benchmark_us,"us_per_apply":float(benchmark_us)/ITERATIONS,"actual_mesh":actual_metrics,"cost":cost_metrics,"first_mismatch":first_mismatch})

func _candidate_cost_metrics() -> Dictionary:
	var world:=Node3D.new(); root.add_child(world)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json"); var loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	if not loaded.ok: world.free(); return {"ok":false,"error":"visual"}
	var visual=loaded.visual; world.add_child(visual.root); var source_row: Dictionary={}
	for row: Dictionary in Bindings.load_oracle().rows:
		if row.profile_id=="compact_sedan": source_row=row; break
	var bound:=Bindings.bind(visual,source_row); if not bound.ok: visual.dispose(); world.free(); return bound
	var cache:=Cache.new(); var prepared:=cache.acquire(visual,world,bound.crash_profile_source,{"source_sha256":"cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44","visual_manifest_sha256":Solver.VISUAL_MANIFEST_SHA256,"asset_generation":"dent-cost-candidate-v1"})
	if not prepared.ok: cache.dispose(); visual.dispose(); world.free(); return prepared
	var largest:=PackedVector3Array(); var label:=""
	for row: Dictionary in prepared.rows:
		for surface: Dictionary in row.surfaces:
			var vertices: PackedVector3Array=surface.base
			if vertices.size()>largest.size(): largest=vertices; label=row.label
	var positions:=PackedFloat32Array(); positions.resize(largest.size()*3); var bounds:=AABB(largest[0],Vector3.ZERO)
	for i in largest.size(): positions[i*3]=largest[i].x; positions[i*3+1]=largest[i].y; positions[i*3+2]=largest[i].z; bounds=bounds.expand(largest[i])
	var centre:=bounds.get_center(); var actual:=_measure_cost(positions,PackedFloat64Array([centre.x,centre.y,centre.z]))
	var ceiling:=PackedFloat32Array(); ceiling.resize(Dent.MAX_POSITION_VALUES); ceiling.fill(0.0)
	var maximum:=_measure_cost(ceiling,PackedFloat64Array([0.0,0.0,0.0]))
	cache.dispose(); visual.dispose(); world.free()
	return {"ok":actual.ok and maximum.ok,"actual_panel":label,"actual":actual,"bounded_90k_all_inside_synthetic":maximum,"scope":"candidate pure position stage+commit only"}

func _measure_cost(initial: PackedFloat32Array,point: PackedFloat64Array) -> Dictionary:
	var dent:=Dent.new(); var configured:=dent.configure(initial,1); if not configured.ok: return configured
	var current:=initial.duplicate(); var samples: Array[int]=[]; var affected:=0
	for i in 40:
		var begin:=Time.get_ticks_usec(); var result:=dent.apply(current,point,PackedFloat64Array([0.0,1.0,0.0]),0.0,{"impactSpeed":14.0},1)
		if not result.ok: dent.dispose(); return result
		var committed:=dent.commit(result.stage_token); if not committed.ok: dent.dispose(); return committed
		var elapsed:=Time.get_ticks_usec()-begin; current=result.positions; affected=result.affected
		if i>=8: samples.append(elapsed)
	samples.sort(); dent.dispose()
	return {"ok":true,"vertices":int(initial.size()/3),"samples":samples.size(),"p50_us":samples[15],"p95_us":samples[30],"max_us":samples[-1],"affected_last":affected}
func _actual_mesh_benchmark() -> Dictionary:
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json"); var loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	if not loaded.ok: return {"ok":false,"error":"visual"}
	var visual=loaded.visual; var selected: MeshInstance3D; var selected_count:=0
	for node in visual.nodes.values():
		if not node is MeshInstance3D or not node.mesh is ArrayMesh: continue
		var count:=0
		for surface in node.mesh.get_surface_count(): count+=node.mesh.surface_get_array_len(surface)
		if count>selected_count and count<=Dent.MAX_VERTICES: selected=node; selected_count=count
	if selected==null: visual.dispose(); return {"ok":false,"error":"mesh"}
	var values:=PackedFloat32Array()
	for surface in selected.mesh.get_surface_count():
		var vertices: PackedVector3Array=selected.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices: values.append(vertex.x); values.append(vertex.y); values.append(vertex.z)
	var provider:=Dent.new(); var configured:=provider.configure(values,1)
	if not configured.ok: visual.dispose(); return configured
	var point:=PackedFloat64Array([values[0],values[1],values[2]]); var normal:=PackedFloat64Array([0.0,0.0,1.0]); var begin:=Time.get_ticks_usec(); var applied:=provider.apply(values,point,normal,24.0,{},1); var elapsed:=Time.get_ticks_usec()-begin
	if applied.ok:
		provider.commit(applied.stage_token)
		elapsed=Time.get_ticks_usec()-begin
	var result={"ok":applied.ok,"profile":"compact_sedan","mesh":String(selected.name),"vertices":selected_count,"apply_us":elapsed,"affected":applied.get("affected",0),"changed":applied.get("changed",0)}
	provider.dispose(); visual.dispose(); return result
func _native_axis_replay(fixture: Dictionary) -> Dictionary:
	var provider:=Dent.new(); var generation:=11; var initial:=_native_positions(fixture.mesh.initial_positions)
	if not provider.configure(initial,generation).ok: return {"ok":false,"stage":"configure"}
	for step: Dictionary in fixture.steps:
		var before:=_native_positions(step.before)
		if step.label=="bullet_after_geometry_replacement":
			generation+=1
			if not provider.reset(before,generation,false).ok: return {"ok":false,"stage":"reset","label":step.label}
		if step.label=="source_zero_normal": continue
		var collision: Dictionary={} if step.collision==null else {"impactSpeed":float(step.collision.impactSpeed)}
		var result:=provider.apply(before,_native_vec(step.local_point),_native_vec(step.local_normal),float(step.damage),collision,generation)
		if not result.ok: return {"ok":false,"stage":"apply","label":step.label,"error":result.get("error","")}
		for field in ["positions","base","offset"]:
			var expected_values: Array=_native_values(step.after if field=="positions" else step.state[field],field=="offset")
			var actual_values: PackedFloat32Array=result[field]
			if not _exact_f32(actual_values,expected_values):
				var packed_expected:=_f32(expected_values)
				for i in actual_values.size():
					if _f32_bits(actual_values[i])!=_f32_bits(packed_expected[i]): return {"ok":false,"stage":field,"label":step.label,"index":i,"actual":actual_values[i],"expected":packed_expected[i],"actual_bits":_f32_bits(actual_values[i]),"expected_bits":_f32_bits(packed_expected[i]),"delta":actual_values[i]-packed_expected[i]}
		if not provider.commit(result.stage_token).ok: return {"ok":false,"stage":"commit","label":step.label}
	provider.dispose(); return {"ok":true}

func _transaction_checks(initial: PackedFloat32Array,generation: int) -> void:
	var provider:=Dent.new(); check(provider.configure(initial,generation).ok,"transaction configure")
	var point:=PackedFloat64Array([initial[0],initial[1],initial[2]])
	var normal:=PackedFloat64Array([0.0,0.0,1.0])
	var before:=provider.snapshot(); var staged:=provider.apply(initial,point,normal,24.0,{},generation)
	var pending_snapshot:=provider.snapshot()
	check(staged.ok and pending_snapshot.pending and _same_committed_state(pending_snapshot,before),"staging does not advance committed private state")
	check(provider.apply(initial,point,normal,24.0,{},generation).error=="pending_commit","one pending transaction only")
	var staged_positions: PackedFloat32Array=staged.positions.duplicate(); var staged_base: PackedFloat32Array=staged.base.duplicate(); var staged_offset: PackedFloat32Array=staged.offset.duplicate()
	check(provider.abort(staged.stage_token).ok and provider.snapshot()==before,"abort leaves state untouched")
	var replay:=provider.apply(initial,point,normal,24.0,{},generation)
	check(replay.ok and replay.positions.to_byte_array()==staged_positions.to_byte_array() and replay.base.to_byte_array()==staged_base.to_byte_array() and replay.offset.to_byte_array()==staged_offset.to_byte_array(),"abort replay is bit-identical")
	check(provider.abort(replay.stage_token).ok,"abort replay cleanup")
	var mutation:=provider.apply(initial,point,normal,24.0,{},generation); var expected_base: PackedFloat32Array=mutation.base.duplicate(); var expected_offset: PackedFloat32Array=mutation.offset.duplicate()
	mutation.base[0]=12345.0; mutation.offset[0]=-12345.0; mutation.positions[0]=9999.0
	check(provider.commit(mutation.stage_token).ok,"mutated returned buffers cannot invalidate commit token")
	var committed:=provider.snapshot()
	check(committed.base.to_byte_array()==expected_base.to_byte_array() and committed.offset.to_byte_array()==expected_offset.to_byte_array(),"returned buffers cannot mutate private staged state")
	check(provider.commit(mutation.stage_token).error=="stale_stage","used stage token rejected")
	check(provider.reset(initial,generation+1,true).ok,"transaction reset")
	var own:=provider.apply(initial,point,normal,24.0,{},generation+1); var foreign:=Dent.new(); foreign.configure(initial,99); var foreign_stage:=foreign.apply(initial,point,normal,24.0,{},99)
	check(provider.commit(foreign_stage.stage_token).error=="stale_stage","foreign stage token rejected")
	check(provider.abort(own.stage_token).ok,"foreign token rejection preserves own pending stage")
	check(foreign.abort(foreign_stage.stage_token).ok,"foreign provider cleanup")
	var reset_stage:=provider.apply(initial,point,normal,24.0,{},generation+1)
	check(reset_stage.ok and provider.reset(initial,generation+2,true).ok and provider.commit(reset_stage.stage_token).error=="stale_stage","reset invalidates pending stage token")
	var disposed:=Dent.new(); disposed.configure(initial,5); var disposed_stage:=disposed.apply(initial,point,normal,24.0,{},5); disposed.dispose()
	check(disposed.commit(disposed_stage.stage_token).error=="lifetime","dispose invalidates pending stage token")
	provider.dispose(); foreign.dispose()
func _native_positions(values: Array) -> PackedFloat32Array:
	return _f32(_native_values(values))
func _native_values(values: Array,canonical_zero: bool=false) -> Array:
	var result: Array=[]; result.resize(values.size())
	for i in range(0,values.size(),3):
		result[i]=-float(values[i]); result[i+1]=float(values[i+1]); result[i+2]=-float(values[i+2])
		if canonical_zero:
			if result[i]==0.0: result[i]=0.0
			if result[i+1]==0.0: result[i+1]=0.0
			if result[i+2]==0.0: result[i+2]=0.0
	return result
func _native_vec(values: Array) -> PackedFloat64Array:
	return PackedFloat64Array([-float(values[0]),float(values[1]),-float(values[2])])
func _f32(values: Array) -> PackedFloat32Array:
	var result:=PackedFloat32Array(); result.resize(values.size())
	for i in values.size(): result[i]=float(values[i])
	return result
func _f64(values: Array) -> PackedFloat64Array:
	return PackedFloat64Array([float(values[0]),float(values[1]),float(values[2])])
func _exact_f32(actual: PackedFloat32Array,wanted: Array) -> bool:
	return actual.to_byte_array()==_f32(wanted).to_byte_array()
func _same_committed_state(left: Dictionary,right: Dictionary) -> bool:
	return left.generation==right.generation and left.max_depth==right.max_depth and left.base.to_byte_array()==right.base.to_byte_array() and left.offset.to_byte_array()==right.offset.to_byte_array()
func _f32_bits(value: float) -> String:
	return PackedFloat32Array([value]).to_byte_array().hex_encode()
func _all_zero(values: PackedFloat32Array) -> bool:
	for value in values:
		if value!=0.0: return false
	return true
func _finite_bounds(bounds: Dictionary) -> bool:
	for value in bounds.min:
		if not is_finite(float(value)): return false
	for value in bounds.max:
		if not is_finite(float(value)): return false
	for value in bounds.sphere.center:
		if not is_finite(float(value)): return false
	return is_finite(float(bounds.sphere.radius))
func _sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_LOCAL_DENT_COST_CANDIDATE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"oracle_sha":ORACLE_SHA,"source_sha":SOURCE_SHA,"scope":"pure position-buffer dent core; preparation/normals/bounds/rendering/authority excluded"}))
	quit(0 if failures.is_empty() else 1)
