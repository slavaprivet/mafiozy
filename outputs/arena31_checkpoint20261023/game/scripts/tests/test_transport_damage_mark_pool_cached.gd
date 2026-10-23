extends SceneTree
const Base=preload("res://scripts/transport/transport_damage_mark_pool.gd")
const Cached=preload("res://scripts/transport/candidates/transport_damage_mark_pool_cached.gd")
const Plan=preload("res://scripts/transport/transport_damage_mark_plan.gd")
const SAMPLES:=24
const CALLS_PER_SAMPLE:=25
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var baseline_setup:=_setup("baseline"); var cached_setup:=_setup("cached")
	root.add_child(baseline_setup.world); root.add_child(cached_setup.world)
	var baseline:=Base.new(); var candidate:=Cached.new()
	check(baseline.configure(baseline_setup.vehicle,baseline_setup.world,{"a":baseline_setup.target_a,"b":baseline_setup.target_b},1).ok,"baseline configured")
	check(candidate.configure(cached_setup.vehicle,cached_setup.world,{"a":cached_setup.target_a,"b":cached_setup.target_b},1).ok,"cached candidate configured")
	_fill_all_slots(baseline,baseline_setup); _fill_all_slots(candidate,cached_setup)
	check(baseline.snapshot().active==32 and candidate.snapshot().active==32,"full 32 active marks retained")
	check(_same_pool_state(baseline,candidate),"initial exact node/resource/source-pose state")
	var base_static:=baseline.reconcile_targets(1); var cached_static:=candidate.reconcile_targets(1)
	check(base_static.ok and cached_static.ok and cached_static.visible==32 and cached_static.unique_targets==2,"static reconcile checks full pool and caches two targets")
	check(cached_static.transform_writes==0 and cached_static.exact_transform_skips==32,"static exact transforms skip all native writes")
	check(_same_pool_state(baseline,candidate),"static candidate state exactly equals baseline")
	# Visibility remains source driven and is evaluated once per bound target.
	baseline_setup.target_a.visible=false; cached_setup.target_a.visible=false
	var hidden_base:=baseline.reconcile_targets(1); var hidden_cached:=candidate.reconcile_targets(1)
	check(hidden_base.visible==16 and hidden_cached.visible==16 and hidden_cached.changed==16,"hidden source hides its exact 16 marks")
	check(_same_pool_state(baseline,candidate),"hidden-source state exactly equals baseline")
	baseline_setup.target_a.visible=true; cached_setup.target_a.visible=true; baseline.reconcile_targets(1); candidate.reconcile_targets(1)
	# Every active target moves: exact desired transforms must still be written.
	_move_targets(baseline_setup,1); _move_targets(cached_setup,1)
	var moving_base:=baseline.reconcile_targets(1); var moving_cached:=candidate.reconcile_targets(1)
	check(moving_base.ok and moving_cached.ok and moving_cached.transform_writes==32 and moving_cached.exact_transform_skips==0,"all 32 moving marks receive native writes")
	check(_same_pool_state(baseline,candidate),"moving state exactly equals baseline")
	# A late nonfinite target must fail before any mark mutation.
	var before_base:=_capture(baseline); var before_cached:=_capture(candidate)
	baseline_setup.target_b.position.x=NAN; cached_setup.target_b.position.x=NAN
	check(baseline.reconcile_targets(1).error=="target_transform" and candidate.reconcile_targets(1).error=="target_transform","nonfinite cached target rejected")
	check(_captured_equal(before_base,_capture(baseline)) and _captured_equal(before_cached,_capture(candidate)),"failure leaves all 32 nodes atomic")
	baseline_setup.target_b.position.x=0; cached_setup.target_b.position.x=0; baseline.reconcile_targets(1); candidate.reconcile_targets(1)
	# Warm before sequential timings.
	for i in 200: baseline.reconcile_targets(1)
	for i in 200: candidate.reconcile_targets(1)
	var static_samples:=_benchmark_static_pair(baseline,candidate)
	var base_a: Transform3D=baseline_setup.target_a.transform; var base_b: Transform3D=baseline_setup.target_b.transform
	var cached_a: Transform3D=cached_setup.target_a.transform; var cached_b: Transform3D=cached_setup.target_b.transform
	var moving_samples:=_benchmark_moving_pair(baseline,baseline_setup,candidate,cached_setup)
	baseline_setup.target_a.transform=base_a; baseline_setup.target_b.transform=base_b; cached_setup.target_a.transform=cached_a; cached_setup.target_b.transform=cached_b
	baseline.reconcile_targets(1); candidate.reconcile_targets(1)
	check(_same_pool_state(baseline,candidate),"benchmark preserves exact final state after restore")
	# Worst bounded distribution: every physical mark has a distinct target.
	var many_base_setup:=_setup_many("many_base"); var many_cached_setup:=_setup_many("many_cached"); root.add_child(many_base_setup.world); root.add_child(many_cached_setup.world)
	var many_base:=Base.new(); var many_cached:=Cached.new()
	check(many_base.configure(many_base_setup.vehicle,many_base_setup.world,many_base_setup.bindings,1).ok and many_cached.configure(many_cached_setup.vehicle,many_cached_setup.world,many_cached_setup.bindings,1).ok,"32-distinct-target pools configured")
	_fill_distinct(many_base,many_base_setup); _fill_distinct(many_cached,many_cached_setup)
	var many_static:=many_cached.reconcile_targets(1)
	check(many_static.ok and many_static.unique_targets==32 and many_static.exact_transform_skips==32,"32 distinct static targets preserve exact-write skip")
	var many_static_samples:=_benchmark_static_pair(many_base,many_cached)
	var many_moving_samples:=_benchmark_many_moving_pair(many_base,many_base_setup,many_cached,many_cached_setup)
	check(_same_pool_state(many_base,many_cached),"32 distinct moving targets exactly match baseline")
	many_base.dispose(); many_cached.dispose(); many_base_setup.world.free(); many_cached_setup.world.free()
	var original_parent: Node=cached_setup.target_a.get_parent(); cached_setup.target_a.reparent(cached_setup.world,true)
	check(candidate.reconcile_targets(1).visible==16,"reparented multi-mark target hides only its 16 marks")
	cached_setup.target_a.reparent(original_parent,true); check(candidate.reconcile_targets(1).visible==32,"restored multi-mark target restores its marks")
	cached_setup.target_a.free(); check(candidate.reconcile_targets(1).visible==16,"freed weak target hides only its marks safely")
	check(candidate.reset(2).ok and candidate.reconcile_targets(2).visible==0 and candidate.reconcile_targets(2).checked==32,"reset clears and still checks full 32 slots")
	check(candidate.reconcile_targets(1).error=="generation","reset invalidates stale reconcile generation")
	# Candidate retains frozen resource fences and disposal cleanup.
	var candidate_effects_id: int=candidate.snapshot().effects_root.get_instance_id()
	candidate.get_slot_node(0).material_override=StandardMaterial3D.new()
	check(candidate.reconcile_targets(2).error=="slot_state","cheap slot override validation retained")
	candidate.get_slot_node(0).material_override=null
	var material:=candidate.get_slot_node(0).mesh.surface_get_material(0) as StandardMaterial3D
	check(material.changed.is_connected(Callable(candidate,"_on_prepared_resource_changed")),"prepared resource signal remains connected")
	material.emit_changed()
	check(candidate._resources_dirty,"prepared resource change signal reaches cached subclass")
	check(candidate.reconcile_targets(2).get("error","")=="slot_state","prepared resource signal fence retained")
	candidate.dispose()
	check(not is_instance_id_valid(candidate_effects_id) and candidate.snapshot().error=="lifetime","dispose disconnects and frees candidate pool")
	baseline.dispose(); baseline_setup.world.free(); cached_setup.world.free()
	finish({"samples":SAMPLES,"calls_per_sample":CALLS_PER_SAMPLE,"two_targets_32marks_static":{"baseline_p50_us":_percentile(static_samples.baseline,.50),"baseline_p95_us":_percentile(static_samples.baseline,.95),"candidate_p50_us":_percentile(static_samples.candidate,.50),"candidate_p95_us":_percentile(static_samples.candidate,.95)},"two_targets_32marks_moving":{"baseline_p50_us":_percentile(moving_samples.baseline,.50),"baseline_p95_us":_percentile(moving_samples.baseline,.95),"candidate_p50_us":_percentile(moving_samples.candidate,.50),"candidate_p95_us":_percentile(moving_samples.candidate,.95)},"distinct_32targets_static":{"baseline_p50_us":_percentile(many_static_samples.baseline,.50),"baseline_p95_us":_percentile(many_static_samples.baseline,.95),"candidate_p50_us":_percentile(many_static_samples.candidate,.50),"candidate_p95_us":_percentile(many_static_samples.candidate,.95)},"distinct_32targets_moving":{"baseline_p50_us":_percentile(many_moving_samples.baseline,.50),"baseline_p95_us":_percentile(many_moving_samples.baseline,.95),"candidate_p50_us":_percentile(many_moving_samples.candidate,.50),"candidate_p95_us":_percentile(many_moving_samples.candidate,.95)}})

func _fill_all_slots(pool,setup: Dictionary) -> void:
	var point:=PackedFloat64Array([.12,.03,-.08]); var normal:=PackedFloat64Array([0,0,1])
	for slot in 32:
		var target: MeshInstance3D=setup.target_a if slot%2==0 else setup.target_b
		var source: StringName=&"a" if slot%2==0 else &"b"
		var receipt:=Plan.plan_collision_round(pool.snapshot().cursor,point,normal)
		var committed: Dictionary=pool.commit(target,source,receipt,1)
		check(committed.ok and committed.slot==slot,"source cursor fills physical slot %d"%slot)

func _fill_distinct(pool,setup: Dictionary) -> void:
	var point:=PackedFloat64Array([.12,.03,-.08]); var normal:=PackedFloat64Array([0,0,1])
	for slot in 32:
		var receipt:=Plan.plan_collision_round(pool.snapshot().cursor,point,normal)
		var committed: Dictionary=pool.commit(setup.targets[slot],StringName("t%02d"%slot),receipt,1)
		check(committed.ok and committed.slot==slot,"distinct source fills physical slot %d"%slot)

func _benchmark_static_pair(baseline,candidate) -> Dictionary:
	var baseline_samples: Array[float]=[]; var candidate_samples: Array[float]=[]
	for sample in SAMPLES:
		var baseline_us:=0; var candidate_us:=0; var checksum:=0
		for call in CALLS_PER_SAMPLE:
			if sample%2==0:
				var begin:=Time.get_ticks_usec(); checksum+=int(baseline.reconcile_targets(1).visible); baseline_us+=Time.get_ticks_usec()-begin
				begin=Time.get_ticks_usec(); checksum+=int(candidate.reconcile_targets(1).visible); candidate_us+=Time.get_ticks_usec()-begin
			else:
				var begin:=Time.get_ticks_usec(); checksum+=int(candidate.reconcile_targets(1).visible); candidate_us+=Time.get_ticks_usec()-begin
				begin=Time.get_ticks_usec(); checksum+=int(baseline.reconcile_targets(1).visible); baseline_us+=Time.get_ticks_usec()-begin
		if checksum!=CALLS_PER_SAMPLE*64: failures.append("static benchmark checksum")
		baseline_samples.append(float(baseline_us)/CALLS_PER_SAMPLE); candidate_samples.append(float(candidate_us)/CALLS_PER_SAMPLE)
	return {"baseline":baseline_samples,"candidate":candidate_samples}

func _benchmark_moving_pair(baseline,baseline_setup: Dictionary,candidate,candidate_setup: Dictionary) -> Dictionary:
	var baseline_samples: Array[float]=[]; var candidate_samples: Array[float]=[]
	for sample in SAMPLES:
		var baseline_us:=0; var candidate_us:=0; var checksum:=0
		for call in CALLS_PER_SAMPLE:
			var index:=sample*CALLS_PER_SAMPLE+call+2; _move_targets(baseline_setup,index); _move_targets(candidate_setup,index)
			if sample%2==0:
				var begin:=Time.get_ticks_usec(); checksum+=int(baseline.reconcile_targets(1).visible); baseline_us+=Time.get_ticks_usec()-begin
				begin=Time.get_ticks_usec(); checksum+=int(candidate.reconcile_targets(1).visible); candidate_us+=Time.get_ticks_usec()-begin
			else:
				var begin:=Time.get_ticks_usec(); checksum+=int(candidate.reconcile_targets(1).visible); candidate_us+=Time.get_ticks_usec()-begin
				begin=Time.get_ticks_usec(); checksum+=int(baseline.reconcile_targets(1).visible); baseline_us+=Time.get_ticks_usec()-begin
		if checksum!=CALLS_PER_SAMPLE*64: failures.append("moving benchmark checksum")
		baseline_samples.append(float(baseline_us)/CALLS_PER_SAMPLE); candidate_samples.append(float(candidate_us)/CALLS_PER_SAMPLE)
	return {"baseline":baseline_samples,"candidate":candidate_samples}

func _benchmark_many_moving_pair(baseline,baseline_setup: Dictionary,candidate,candidate_setup: Dictionary) -> Dictionary:
	var baseline_samples: Array[float]=[]; var candidate_samples: Array[float]=[]
	for sample in SAMPLES:
		var baseline_us:=0; var candidate_us:=0; var checksum:=0
		for call in CALLS_PER_SAMPLE:
			var index:=sample*CALLS_PER_SAMPLE+call+2; _move_many(baseline_setup,index); _move_many(candidate_setup,index)
			if sample%2==0:
				var begin:=Time.get_ticks_usec(); checksum+=int(baseline.reconcile_targets(1).visible); baseline_us+=Time.get_ticks_usec()-begin
				begin=Time.get_ticks_usec(); checksum+=int(candidate.reconcile_targets(1).visible); candidate_us+=Time.get_ticks_usec()-begin
			else:
				var begin:=Time.get_ticks_usec(); checksum+=int(candidate.reconcile_targets(1).visible); candidate_us+=Time.get_ticks_usec()-begin
				begin=Time.get_ticks_usec(); checksum+=int(baseline.reconcile_targets(1).visible); baseline_us+=Time.get_ticks_usec()-begin
		if checksum!=CALLS_PER_SAMPLE*64: failures.append("many-moving benchmark checksum")
		baseline_samples.append(float(baseline_us)/CALLS_PER_SAMPLE); candidate_samples.append(float(candidate_us)/CALLS_PER_SAMPLE)
	return {"baseline":baseline_samples,"candidate":candidate_samples}

func _move_targets(setup: Dictionary,index: int) -> void:
	setup.target_a.position+=Vector3(.000003*(index%3+1),-.000002,.000001)
	setup.target_b.position+=Vector3(-.000002,.000001*(index%5+1),.000003)

func _move_many(setup: Dictionary,index: int) -> void:
	for target_index in 32:
		setup.targets[target_index].position+=Vector3(.000001*(target_index%3+1),.000001*(index%2),-.000001*(target_index%5+1))

func _capture(pool) -> Array:
	var result: Array=[]
	for slot in 32:
		var node: MeshInstance3D=pool.get_slot_node(slot)
		result.append({"transform":node.transform,"visible":node.visible,"mesh":node.mesh.get_instance_id(),"material":node.mesh.surface_get_material(0).get_instance_id()})
	return result

func _same_pool_state(a,b) -> bool:
	var left:=_capture(a); var right:=_capture(b)
	for slot in 32:
		if left[slot].transform!=right[slot].transform or left[slot].visible!=right[slot].visible: return false
		if (slot%3==0)!=(left[slot].mesh==left[0].mesh) or (slot%3==0)!=(right[slot].mesh==right[0].mesh): return false
		if (slot%3==0)!=(left[slot].material==left[0].material) or (slot%3==0)!=(right[slot].material==right[0].material): return false
	return true

func _captured_equal(a: Array,b: Array) -> bool:
	if a.size()!=b.size(): return false
	for i in a.size():
		if a[i]!=b[i]: return false
	return true

func _setup(label: String) -> Dictionary:
	var world:=Node3D.new(); world.name="World_"+label; world.transform=Transform3D(Basis.from_euler(Vector3(.13,-.22,.07)).scaled(Vector3(1.08,.94,1.03)),Vector3(3,.4,-2))
	var vehicle:=Node3D.new(); vehicle.name="Vehicle_"+label; vehicle.transform=Transform3D(Basis.from_euler(Vector3(-.08,.61,.12)).scaled(Vector3(1.12,.91,1.06)),Vector3(1.4,.2,-.9)); world.add_child(vehicle)
	var target_a:=MeshInstance3D.new(); target_a.name="A"; target_a.mesh=BoxMesh.new(); target_a.transform=Transform3D(Basis.from_euler(Vector3(.11,.24,-.18)).scaled(Vector3(1.04,.87,1.09)),Vector3(.13,.08,-.04)); vehicle.add_child(target_a)
	var target_b:=MeshInstance3D.new(); target_b.name="B"; target_b.mesh=BoxMesh.new(); target_b.transform=Transform3D(Basis.from_euler(Vector3(-.05,-.19,.14)).scaled(Vector3(.93,1.07,.89)),Vector3(-.42,.61,.25)); vehicle.add_child(target_b)
	return {"world":world,"vehicle":vehicle,"target_a":target_a,"target_b":target_b}

func _setup_many(label: String) -> Dictionary:
	var world:=Node3D.new(); world.name="World_"+label
	var vehicle:=Node3D.new(); vehicle.name="Vehicle_"+label; world.add_child(vehicle)
	var targets: Array[MeshInstance3D]=[]; var bindings: Dictionary={}
	for index in 32:
		var target:=MeshInstance3D.new(); target.name="Target_%02d"%index; target.mesh=BoxMesh.new(); target.position=Vector3(index*.03,(index%4)*.02,-(index%7)*.01); vehicle.add_child(target)
		targets.append(target); bindings[StringName("t%02d"%index)]=target
	return {"world":world,"vehicle":vehicle,"targets":targets,"bindings":bindings}

func _percentile(values: Array[float],fraction: float) -> float:
	var sorted:=values.duplicate(); sorted.sort(); return sorted[clampi(int(ceil((sorted.size()-1)*fraction)),0,sorted.size()-1)]
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DAMAGE_MARK_POOL_CACHED ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"candidate full32 exact-transform/write cache; no content/authority/GPU"}))
	quit(0 if failures.is_empty() else 1)
