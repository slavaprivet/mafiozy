extends SceneTree
## Actual Node-oracle parity for proposal-only impact and deformation sampling.

const Solver = preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const SOURCE := "res://../../assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs"
const SOURCE_SHA256 := "3faeed3b6bea790396c7676958100bd5520105d452a61a14c45977d38095a166"
const MANIFEST := "res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const PROFILE_ID := "compact_sedan"
const VEHICLE_ID := "solver-oracle-compact"
const LIFE := 11
const NODE_ORACLE := """
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
const [sourcePath,manifestPath]=process.argv.slice(1);
const {createCrashMechanicsState,applyCrashMechanicsImpact,stepCrashMechanics,sampleCrashDeformation}=await import(pathToFileURL(sourcePath).href);
const manifest=JSON.parse(readFileSync(manifestPath,'utf8'));
const entry=manifest.entries.find(row=>row.profile_id==='compact_sedan');
const profileNode=entry.nodes.find(node=>node?.source_metadata?.vehicleProfile);
const profile=profileNode.source_metadata.vehicleProfile;
const state=createCrashMechanicsState(profile);
const contacts=[
 {eventId:'front-22',point:{x:0,y:.8,z:profile.halfLength},normal:{x:0,y:0,z:1},impactSpeed:22},
 {eventId:'left-17',point:{x:profile.halfWidth,y:.9,z:.35},normal:{x:1,y:0,z:0},impactSpeed:17},
 {eventId:'wheel-28',point:{...profile.wheelPositions.front_left},normal:{x:1,y:0,z:0},impactSpeed:28},
];
const samplePoints=[{x:0,y:.95,z:profile.halfLength*.94},{x:profile.halfWidth*.55,y:profile.height*.57,z:.2},{x:-profile.halfWidth*.4,y:.3,z:-profile.halfLength*.65}];
const snap=()=>({nodes:state.nodes,beams:state.beams,parts:state.parts,wheels:state.wheels,engine:state.engine,radiator:state.radiator,steering:state.steering,brakes:state.brakes,temperature:state.temperature,detachedParts:state.detachedParts,recentEvents:state.recentEvents,impacts:state.impacts,totalEnergyJ:state.totalEnergyJ,absorbedEnergyJ:state.absorbedEnergyJ,revision:state.revision,active:state.active,accumulator:state.accumulator,simulationTime:state.simulationTime,maxCrush:state.maxCrush});
const stages=[];
for(const contact of contacts){const result=applyCrashMechanicsImpact(state,contact);stages.push({contact,result,state:structuredClone(snap()),samples:samplePoints.map(point=>({point,value:sampleCrashDeformation(state,point)}))});}
const beforeDuplicate=JSON.stringify(snap()),duplicate=applyCrashMechanicsImpact(state,contacts[0]);
const stepProfiles=[];
for(const id of ['compact_sedan','city_hatchback','city_bus']){
 const e=manifest.entries.find(row=>row.profile_id===id),p=e.nodes.find(node=>node?.source_metadata?.vehicleProfile).source_metadata.vehicleProfile,s=createCrashMechanicsState(p);
 const sign=Math.sign(p.componentPoints.engine.z||1),hits=[
  {eventId:id+'-component',point:{x:0,y:.8,z:sign*p.halfLength},normal:{x:0,y:0,z:sign},impactSpeed:32},
  {eventId:id+'-side',point:{x:p.halfWidth,y:.9,z:0},normal:{x:1,y:0,z:0},impactSpeed:17},
  {eventId:id+'-wheel',point:{...p.wheelPositions.front_left},normal:{x:1,y:0,z:0},impactSpeed:28},
 ];
 const impactResults=hits.map(hit=>applyCrashMechanicsImpact(s,hit));
 const operations=[{dt:0,speed:0,throttle:0},{dt:.001,speed:0,throttle:1},{dt:1/60,speed:4,throttle:.7},{dt:.08,speed:0,throttle:1},{dt:.25,speed:0,throttle:1}];
 for(let i=0;i<180;i++)operations.push({dt:.1,speed:i%2?0:8,throttle:1});
 const stepResults=[],checkpoints=[];
 for(let i=0;i<operations.length;i++){
  const op=operations[i],before=s.simulationTime,changed=stepCrashMechanics(s,op.dt,{speed:op.speed,throttle:op.throttle});
  stepResults.push({changed,substeps:Math.round((s.simulationTime-before)*240),revision:s.revision,active:s.active});
  if([0,1,2,4,operations.length-1].includes(i))checkpoints.push({operationIndex:i,state:structuredClone((()=>({nodes:s.nodes,beams:s.beams,parts:s.parts,wheels:s.wheels,engine:s.engine,radiator:s.radiator,steering:s.steering,brakes:s.brakes,temperature:s.temperature,detachedParts:s.detachedParts,recentEvents:s.recentEvents,impacts:s.impacts,totalEnergyJ:s.totalEnergyJ,absorbedEnergyJ:s.absorbedEnergyJ,revision:s.revision,active:s.active,accumulator:s.accumulator,simulationTime:s.simulationTime,maxCrush:s.maxCrush}))()),samples:samplePoints.map(point=>({point,value:sampleCrashDeformation(s,point)}))});
 }
 stepProfiles.push({id,profile:p,hits,impactResults,operations,stepResults,checkpoints});
}
const configureProfiles=manifest.entries.map(entry=>{
 const p=entry.nodes.find(node=>node?.source_metadata?.vehicleProfile).source_metadata.vehicleProfile;
 const s=createCrashMechanicsState(p);
 return {id:entry.profile_id,profile:p,missingRear:['door_rear_left','door_rear_right'].filter(id=>!p.partPoints[id]),rearParts:{door_rear_left:s.parts.door_rear_left,door_rear_right:s.parts.door_rear_right}};
});
console.log(JSON.stringify({profilePath:'entries[profile_id].nodes[*].source_metadata.vehicleProfile',profile,stages,duplicate,duplicateStateUnchanged:beforeDuplicate===JSON.stringify(snap()),stepProfiles,configureProfiles}));
"""

var checks := 0
var failures: Array[String] = []
var oracle_sha256 := ""
var benchmark_rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _close(a: float, b: float, tolerance := 0.00002) -> bool:
	return absf(a - b) <= tolerance

func _vector_close(actual: Dictionary, expected: Dictionary, tolerance := 0.00002) -> bool:
	return _close(actual.x, expected.x, tolerance) and _close(actual.y, expected.y, tolerance) \
		and _close(actual.z, expected.z, tolerance)

func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()

func _load_manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed if parsed is Dictionary else {}

func _profile_from_manifest(document: Dictionary, profile_id := PROFILE_ID) -> Dictionary:
	for entry_value: Variant in document.get("entries", []):
		if not entry_value is Dictionary or entry_value.get("profile_id") != profile_id:
			continue
		for node_value: Variant in entry_value.get("nodes", []):
			if node_value is Dictionary and node_value.get("source_metadata") is Dictionary:
				var metadata: Dictionary = node_value.source_metadata
				if metadata.get("vehicleProfile") is Dictionary:
					return metadata.vehicleProfile
	return {}

func _oracle() -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute("node", PackedStringArray([
		"--input-type=module", "--eval", NODE_ORACLE,
		ProjectSettings.globalize_path(SOURCE), ProjectSettings.globalize_path(MANIFEST),
	]), output, true)
	_check(exit_code == 0 and output.size() == 1, "actual Node impact oracle executes")
	if exit_code != 0 or output.is_empty():
		return {}
	var raw := str(output[0]).strip_edges()
	oracle_sha256 = _sha256_text(raw)
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Dictionary, "actual Node impact oracle returns JSON")
	return parsed if parsed is Dictionary else {}

func _native_row(source_contact: Dictionary, tick: int, sequence: int,
		vehicle_id := VEHICLE_ID, life := LIFE) -> Dictionary:
	var source_point := Vector3(source_contact.point.x, source_contact.point.y, source_contact.point.z)
	var source_normal := Vector3(source_contact.normal.x, source_contact.normal.y, source_contact.normal.z)
	return {"vehicle_id": vehicle_id, "life_generation": life, "physics_tick": tick,
		"impact_sequence": sequence,
		"event_id": source_contact.eventId,
		"point_native_m": Solver.source_local_to_native(source_point),
		"normal_native": Solver.source_local_to_native(source_normal),
		"impact_speed_mps": source_contact.impactSpeed}

func _compare_stage(actual: Dictionary, expected: Dictionary, stage_index: int) -> void:
	var prefix := "stage " + str(stage_index) + " "
	var expected_nodes: Array = expected.nodes
	var actual_nodes: Array = actual.nodes
	_check(actual_nodes.size() == 45, prefix + "45 nodes")
	for index in 45:
		var a: Dictionary = actual_nodes[index]
		var e: Dictionary = expected_nodes[index]
		_check(_vector_close(a.rest, e.rest) and _vector_close(a.plastic, e.plastic)
			and _vector_close(a.position, e.position) and _vector_close(a.velocity, e.velocity),
			prefix + "node state " + str(index))
	var expected_beams: Array = expected.beams
	var actual_beams: Array = actual.beams
	_check(actual_beams.size() == 232, prefix + "232 beams")
	for index in 232:
		var a: Dictionary = actual_beams[index]
		var e: Dictionary = expected_beams[index]
		_check(a.a == e.a and a.b == e.b and _close(a.originalLength, e.originalLength)
			and _close(a.restLength, e.restLength) and a.broken == e.broken
			and _close(a.plasticStrain, e.plasticStrain), prefix + "beam state " + str(index))
	var expected_parts: Dictionary = expected.parts
	var actual_parts: Dictionary = actual.parts
	_check(actual_parts.size() == 12, prefix + "12 source parts")
	for part_id: String in Solver.PART_IDS:
		var a: Dictionary = actual_parts[part_id]
		var e: Dictionary = expected_parts[part_id]
		_check(_vector_close(a.point, e.point) and _close(a.radius, e.radius)
			and _close(a.strength, e.strength) and _close(a.health, e.health)
			and a.detached == e.detached, prefix + "part " + part_id)
	var expected_wheels: Dictionary = expected.wheels
	var actual_wheels: Dictionary = actual.wheels
	for wheel_id: String in Solver.WHEEL_IDS:
		var a: Dictionary = actual_wheels[wheel_id]
		var e: Dictionary = expected_wheels[wheel_id]
		_check(_close(a.health, e.health) and _close(a.toe, e.toe)
			and _close(a.camber, e.camber) and _close(a.sag, e.sag)
			and a.detached == e.detached, prefix + "wheel " + wheel_id)
	for scalar in ["engine", "radiator", "steering", "brakes", "temperature",
			"totalEnergyJ", "absorbedEnergyJ", "accumulator", "simulationTime", "maxCrush"]:
		_check(_close(actual[scalar], expected[scalar]), prefix + scalar)
	_check(actual.detachedParts == expected.detachedParts and actual.recentEvents == expected.recentEvents
		and actual.impacts == expected.impacts and actual.revision == expected.revision
		and actual.active == expected.active, prefix + "discrete bookkeeping")

func _compare_samples(solver: RefCounted, samples: Array, label: String) -> void:
	for sample_index in samples.size():
		var sample: Dictionary = samples[sample_index]
		var source_point := Vector3(sample.point.x, sample.point.y, sample.point.z)
		var source_expected := Vector3(sample.value.x, sample.value.y, sample.value.z)
		var actual_native: Vector3 = solver.sample_deformation_native(
			Solver.source_local_to_native(source_point))
		var expected_native := Solver.source_local_to_native(source_expected)
		_check(actual_native.distance_to(expected_native) <= 0.00002,
			label + " sample " + str(sample_index))

func _run_step_profile(manifest: Dictionary, oracle_profile: Dictionary) -> void:
	var profile_id: String = oracle_profile.id
	var profile := _profile_from_manifest(manifest, profile_id)
	var vehicle_id := "step-oracle-" + profile_id
	var solver := Solver.new()
	_check(solver.configure(vehicle_id, 1, profile_id, MANIFEST_SHA256, profile),
		profile_id + " exact step profile configures")
	var contract := solver.runtime_contract()
	_check(contract.nodes == 45 and contract.beams == 232
		and contract.force_scratch_scalars == 135 and contract.force_scratch_bytes == 1080,
		profile_id + " fixed 1080-byte structural scratch")
	var hits: Array = oracle_profile.hits
	var expected_impacts: Array = oracle_profile.impactResults
	for impact_index in hits.size():
		var tick := 1 if impact_index < 2 else 2
		var result := solver.apply_impact_native(_native_row(hits[impact_index], tick,
			impact_index, vehicle_id, 1))
		_check(result.applied == expected_impacts[impact_index].applied
			and _close(result.energy_j, expected_impacts[impact_index].energyJ)
			and result.deformed_nodes == expected_impacts[impact_index].deformedNodes
			and result.detach_part_ids_proposal == expected_impacts[impact_index].detached,
			profile_id + " source impact " + str(impact_index))
	var operations: Array = oracle_profile.operations
	var expected_steps: Array = oracle_profile.stepResults
	var checkpoints_by_index := {}
	for checkpoint: Dictionary in oracle_profile.checkpoints:
		checkpoints_by_index[int(checkpoint.operationIndex)] = checkpoint
	for operation_index in operations.size():
		var operation: Dictionary = operations[operation_index]
		var expected: Dictionary = expected_steps[operation_index]
		var result := solver.step(operation.dt, operation.speed, operation.throttle,
			operation_index + 1)
		_check(result.accepted and result.changed == expected.changed
			and result.substeps == expected.substeps and result.revision == expected.revision
			and result.active == expected.active,
			profile_id + " exact step result " + str(operation_index))
		if checkpoints_by_index.has(operation_index):
			var checkpoint: Dictionary = checkpoints_by_index[operation_index]
			_compare_stage(solver.snapshot_source(), checkpoint.state,
				1000 + operation_index)
			_compare_samples(solver, checkpoint.samples,
				profile_id + " operation " + str(operation_index))
	var snapshot_before := solver.snapshot_source()
	var isolated := solver.snapshot_source()
	isolated.nodes[0].position.x += 100.0
	isolated.parts.hood.health = -1.0
	isolated.wheels.front_left.toe = 100.0
	_check(solver.snapshot_source() == snapshot_before,
		profile_id + " snapshot is mutation-isolated")
	var stale_tick: int = solver.runtime_contract().last_step_physics_tick
	var before_rejected := JSON.stringify(solver.snapshot_source())
	_check(not solver.step(0.1, 0.0, 0.0, stale_tick).accepted
		and JSON.stringify(solver.snapshot_source()) == before_rejected,
		profile_id + " repeated step tick is state-identically rejected")
	_check(not solver.step(NAN, 0.0, 0.0, stale_tick + 1).accepted
		and not solver.step(0.1, INF, 0.0, stale_tick + 2).accepted,
		profile_id + " nonfinite step inputs fail closed")

func _run_all_profile_admission(manifest: Dictionary, rows: Array) -> void:
	_check(rows.size() == 13, "all 13 pinned manifest profiles reach the oracle")
	var observed_fallback_ids: Array[String] = []
	for row_value: Variant in rows:
		_check(row_value is Dictionary, "configure oracle row is a dictionary")
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		var profile_id: String = row.id
		var profile := _profile_from_manifest(manifest, profile_id)
		var solver := Solver.new()
		_check(not profile.is_empty() and solver.configure("all-profile-" + profile_id, 1,
			profile_id, MANIFEST_SHA256, profile), profile_id + " exact manifest profile configures")
		var snapshot := solver.snapshot_source()
		var native_snapshot := solver.deformation_snapshot_native()
		_check(native_snapshot.vehicle_id == "all-profile-" + profile_id
			and native_snapshot.life_generation == 1
			and native_snapshot.profile_id == profile_id
			and native_snapshot.revision == snapshot.revision,
			profile_id + " native snapshot exact identity")
		_check(native_snapshot.positions_native is PackedVector3Array
			and native_snapshot.rest_native is PackedVector3Array
			and native_snapshot.positions_native.size() == 45
			and native_snapshot.rest_native.size() == 45,
			profile_id + " native snapshot has two bounded 45-node arrays")
		for index in 45:
			var source_node: Dictionary = snapshot.nodes[index]
			var expected_position := Solver.source_local_to_native(Vector3(
				source_node.position.x, source_node.position.y, source_node.position.z))
			var expected_rest := Solver.source_local_to_native(Vector3(
				source_node.rest.x, source_node.rest.y, source_node.rest.z))
			_check(native_snapshot.positions_native[index].distance_to(expected_position) <= 0.00002
				and native_snapshot.rest_native[index].distance_to(expected_rest) <= 0.00002,
				profile_id + " native snapshot node " + str(index))
		var preserved_native := solver.deformation_snapshot_native()
		native_snapshot.positions_native[0] += Vector3(100.0, 100.0, 100.0)
		native_snapshot.rest_native[0] -= Vector3(100.0, 100.0, 100.0)
		_check(solver.deformation_snapshot_native() == preserved_native,
			profile_id + " returned packed arrays are mutation-isolated")
		var mechanical := solver.mechanical_snapshot()
		_check(mechanical.vehicle_id == "all-profile-" + profile_id
			and mechanical.life_generation == 1 and mechanical.profile_id == profile_id
			and mechanical.revision == snapshot.revision
			and _close(mechanical.engine, snapshot.engine)
			and _close(mechanical.radiator, snapshot.radiator)
			and _close(mechanical.steering, snapshot.steering)
			and _close(mechanical.brakes, snapshot.brakes)
			and _close(mechanical.temperature, snapshot.temperature),
			profile_id + " lightweight mechanical snapshot")
		var preserved_mechanical := solver.mechanical_snapshot()
		mechanical.wheels.front_left.health = -100.0
		_check(solver.mechanical_snapshot() == preserved_mechanical,
			profile_id + " mechanical wheel snapshot is mutation-isolated")
		for rear_id in ["door_rear_left", "door_rear_right"]:
			var actual: Dictionary = snapshot.parts[rear_id]
			var expected: Dictionary = row.rearParts[rear_id]
			_check(_vector_close(actual.point, expected.point),
				profile_id + " " + rear_id + " exact source point")
		var missing_rear: Array = row.missingRear
		if not missing_rear.is_empty():
			observed_fallback_ids.append(profile_id)
		var missing_hood := profile.duplicate(true)
		missing_hood.partPoints.erase("hood")
		_check(not Solver.new().configure("missing-hood-" + profile_id, 1, profile_id,
			MANIFEST_SHA256, missing_hood), profile_id + " missing hood fails closed")
		var missing_front := profile.duplicate(true)
		missing_front.partPoints.erase("door_front_left")
		_check(not Solver.new().configure("missing-front-" + profile_id, 1, profile_id,
			MANIFEST_SHA256, missing_front), profile_id + " missing front door fails closed")
	var expected_fallback_ids: Array[String] = []
	for profile_id: String in Solver.LOGICAL_REAR_FALLBACK_PROFILE_IDS:
		expected_fallback_ids.append(profile_id)
	observed_fallback_ids.sort()
	expected_fallback_ids.sort()
	_check(observed_fallback_ids == expected_fallback_ids,
		"rear logical fallback allowlist exactly matches pinned manifest omissions")

func _percentile_usec(samples: Array[int], fraction: float) -> int:
	var ordered := samples.duplicate()
	ordered.sort()
	return ordered[mini(ordered.size() - 1, int(ceil(fraction * ordered.size())) - 1)]

func _benchmark_native_step(profile: Dictionary) -> void:
	for hz in [120, 60, 30]:
		var active := Solver.new()
		var active_vehicle := "benchmark-active-" + str(hz)
		_check(active.configure(active_vehicle, 1, PROFILE_ID, MANIFEST_SHA256, profile),
			"benchmark active " + str(hz) + "Hz configures")
		var source_contact := {"eventId": "benchmark-impact-" + str(hz),
			"point": {"x": 0.0, "y": 0.8, "z": float(profile.halfLength)},
			"normal": {"x": 0.0, "y": 0.0, "z": 1.0}, "impactSpeed": 60.0}
		_check(active.apply_impact_native(_native_row(source_contact, 0, 0,
			active_vehicle, 1)).applied, "benchmark active " + str(hz) + "Hz impact")
		active.step(1.0 / hz, 8.0, 1.0, 1)
		var active_samples: Array[int] = []
		var active_substeps := 0
		for sample_index in 16:
			var started := Time.get_ticks_usec()
			var result := active.step(1.0 / hz, 8.0, 1.0, sample_index + 2)
			active_samples.append(Time.get_ticks_usec() - started)
			active_substeps += int(result.substeps)
			_check(result.accepted and result.substeps == 240 / hz,
				"benchmark active " + str(hz) + "Hz exact substeps " + str(sample_index))
		var idle := Solver.new()
		var idle_vehicle := "benchmark-idle-" + str(hz)
		_check(idle.configure(idle_vehicle, 1, PROFILE_ID, MANIFEST_SHA256, profile),
			"benchmark idle " + str(hz) + "Hz configures")
		idle.step(1.0 / hz, 0.0, 0.0, 1)
		var idle_samples: Array[int] = []
		for sample_index in 16:
			var started := Time.get_ticks_usec()
			var result := idle.step(1.0 / hz, 0.0, 0.0, sample_index + 2)
			idle_samples.append(Time.get_ticks_usec() - started)
			_check(result.accepted and result.substeps == 0,
				"benchmark idle " + str(hz) + "Hz has zero structural work " + str(sample_index))
		benchmark_rows.append({"hz": hz, "samples": 16,
			"active_substeps": active_substeps,
			"active_p50_usec": _percentile_usec(active_samples, 0.50),
			"active_p95_usec": _percentile_usec(active_samples, 0.95),
			"idle_p50_usec": _percentile_usec(idle_samples, 0.50),
			"idle_p95_usec": _percentile_usec(idle_samples, 0.95)})

func _run() -> void:
	_check(FileAccess.get_sha256(SOURCE) == SOURCE_SHA256, "exact impact source receipt")
	_check(FileAccess.get_sha256(MANIFEST) == MANIFEST_SHA256, "exact visual manifest receipt")
	var manifest := _load_manifest()
	var profile := _profile_from_manifest(manifest)
	_check(not profile.is_empty() and profile.id == PROFILE_ID,
		"exact entries[n].nodes source_metadata vehicleProfile resolves")
	var oracle := _oracle()
	_check(oracle.get("profilePath") == "entries[profile_id].nodes[*].source_metadata.vehicleProfile",
		"Node uses the exact manifest profile path")
	var solver := Solver.new()
	_check(solver.configure(VEHICLE_ID, LIFE, PROFILE_ID, MANIFEST_SHA256, profile),
		"exact crash profile and lifecycle configure")
	_check(not solver.configure(VEHICLE_ID, LIFE, PROFILE_ID, MANIFEST_SHA256, profile),
		"solver cannot be reconfigured")
	var stages: Array = oracle.get("stages", [])
	_check(stages.size() == 3, "front side and actual wheel source impacts captured")
	for stage_index in stages.size():
		var stage: Dictionary = stages[stage_index]
		var tick := 1 if stage_index < 2 else 2
		var result := solver.apply_impact_native(_native_row(stage.contact, tick, stage_index))
		_check(result.applied == stage.result.applied and _close(result.energy_j, stage.result.energyJ)
			and result.deformed_nodes == stage.result.deformedNodes
			and result.detach_part_ids_proposal == stage.result.detached,
			"stage " + str(stage_index) + " exact impact proposal")
		var snapshot := solver.snapshot_source()
		_compare_stage(snapshot, stage.state, stage_index)
		_compare_samples(solver, stage.samples, "stage " + str(stage_index))
	_check(solver.runtime_contract().last_impact_physics_tick == 2
		and solver.runtime_contract().last_impact_sequence == 2,
		"distinct ordered impacts in the same physics tick both apply")
	var duplicate_row := _native_row(stages[0].contact, 3, 3)
	var before_duplicate := JSON.stringify(solver.snapshot_source())
	var duplicate_result := solver.apply_impact_native(duplicate_row)
	_check(not duplicate_result.applied and oracle.duplicate.applied == false
		and oracle.duplicateStateUnchanged and JSON.stringify(solver.snapshot_source()) == before_duplicate,
		"event idempotency leaves state unchanged")
	var stale_sequence := _native_row(stages[0].contact, 4, 2)
	stale_sequence.event_id = null
	_check(not solver.apply_impact_native(stale_sequence).applied
		and JSON.stringify(solver.snapshot_source()) == before_duplicate,
		"stale impact sequence is state-identically rejected at a newer tick")
	var older_tick := _native_row(stages[1].contact, 1, 3)
	older_tick.event_id = null
	_check(not solver.apply_impact_native(older_tick).applied
		and JSON.stringify(solver.snapshot_source()) == before_duplicate,
		"higher impact sequence with older tick is rejected")
	var invalid_row := _native_row(stages[0].contact, 4, 3)
	invalid_row.vehicle_id = "wrong"
	_check(not solver.apply_impact_native(invalid_row).applied, "wrong vehicle identity rejected")
	invalid_row = _native_row(stages[0].contact, 4, 3)
	invalid_row.point_native_m = Vector3(NAN, 0, 0)
	_check(not solver.apply_impact_native(invalid_row).applied, "nonfinite contact rejected")
	invalid_row = _native_row(stages[0].contact, 4, 3)
	invalid_row.event_id = "x".repeat(257)
	_check(not solver.apply_impact_native(invalid_row).applied, "oversize event id rejected")
	invalid_row = _native_row(stages[0].contact, -1, 4)
	invalid_row.event_id = null
	_check(not solver.apply_impact_native(invalid_row).applied,
		"negative first-domain physics tick rejects explicitly")
	var next_life := Solver.new()
	_check(next_life.configure(VEHICLE_ID, LIFE + 1, PROFILE_ID, MANIFEST_SHA256, profile),
		"new life configures with fresh sequence domain")
	var new_life_row := _native_row(stages[0].contact, 1, 0, VEHICLE_ID, LIFE + 1)
	_check(next_life.apply_impact_native(new_life_row).applied,
		"new life restarts impact sequence at zero")
	var old_life_row := _native_row(stages[1].contact, 1, 1, VEHICLE_ID, LIFE)
	_check(not next_life.apply_impact_native(old_life_row).applied,
		"old life cannot enter new sequence domain")
	var malformed_profile := profile.duplicate(true)
	malformed_profile.partPoints.erase("hood")
	_check(not Solver.new().configure(VEHICLE_ID, LIFE, PROFILE_ID, MANIFEST_SHA256,
		malformed_profile), "missing actual visual mount rejects without generic fallback")
	_check(not Solver.new().configure(VEHICLE_ID, LIFE, PROFILE_ID, "wrong", profile),
		"wrong manifest receipt rejects")
	var step_profiles: Array = oracle.get("stepProfiles", [])
	_check(step_profiles.size() == 3, "step oracle covers compact hatch and bus")
	for oracle_profile: Dictionary in step_profiles:
		_run_step_profile(manifest, oracle_profile)
	_run_all_profile_admission(manifest, oracle.get("configureProfiles", []))
	_benchmark_native_step(profile)
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"source_sha256": FileAccess.get_sha256(SOURCE),
		"manifest_sha256": FileAccess.get_sha256(MANIFEST),
		"node_oracle_sha256": oracle_sha256,
		"component_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_crash_solver.gd"),
		"profile_id": PROFILE_ID, "stages": stages.size(), "step_profiles": 3,
		"configured_manifest_profiles": 13,
		"native_step_benchmark": benchmark_rows,
		"scope": "proposal-only applyImpact/240Hz step/sample; warmed CPU call cost only, no FPS; no authoritative HP visual debris body main GPU LIVE"}
	print("NATIVE_VEHICLE_CRASH_SOLVER_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
