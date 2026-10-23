extends SceneTree
## Candidate-only source oracle equality for immutable crash-cage geometry.
## No impacts, HP, debris, visuals, body/provider/main hook, GPU or LIVE.

const Cage = preload("res://scripts/vehicle_physics/vehicle_crash_cage.gd")
const SOURCE := "res://../../assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs"
const SOURCE_SHA256 := "3faeed3b6bea790396c7676958100bd5520105d452a61a14c45977d38095a166"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const DESCRIPTORS_SHA256 := "99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a"
const PROFILE_IDS := ["compact_sedan", "city_hatchback", "city_bus"]
const NODE_ORACLE := """
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
const [sourcePath,descriptorPath]=process.argv.slice(1);
const {createCrashMechanicsState,sampleCrashDeformation}=await import(pathToFileURL(sourcePath).href);
const descriptors=JSON.parse(readFileSync(descriptorPath,'utf8'));
const ids=['compact_sedan','city_hatchback','city_bus'],profiles=[];
for(const id of ids){
 const descriptor=descriptors.profiles.find(row=>row.profile_id===id);
 const profile={halfWidth:descriptor.body_half_extents_m.x,halfLength:descriptor.body_half_extents_m.z,height:descriptor.body_half_extents_m.y*2};
 const state=createCrashMechanicsState(profile);
 const nodes=state.nodes.map(node=>[node.rest.x,node.rest.y,node.rest.z]);
 const beams=state.beams.map(beam=>[beam.a,beam.b,beam.originalLength,beam.restLength]);
 for(let i=0;i<state.nodes.length;i++){
  const node=state.nodes[i],x=i%3,y=Math.floor(i/3)%3,z=Math.floor(i/9);
  node.position={x:node.rest.x+(x-1)*.031,y:node.rest.y+(y-1)*.017,z:node.rest.z+(z-2)*.023};
 }
 const cornerPoint={...state.nodes[44].rest};
 const interiorPoint={x:profile.halfWidth*.37,y:profile.height*.63,z:-profile.halfLength*.22};
 profiles.push({id,profile,nodes,beams,positions:state.nodes.map(node=>[node.position.x,node.position.y,node.position.z]),
  cornerPoint,cornerSample:sampleCrashDeformation(state,cornerPoint),interiorPoint,interiorSample:sampleCrashDeformation(state,interiorPoint)});
}
console.log(JSON.stringify({source:'createCrashMechanicsState/sampleCrashDeformation',profiles}));
"""

var checks := 0
var failures: Array[String] = []
var node_oracle_sha256 := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _close(a: float, b: float, tolerance := 0.000001) -> bool:
	return absf(a - b) <= tolerance

func _vector_close(a: Vector3, b: Vector3, tolerance := 0.000001) -> bool:
	return a.distance_to(b) <= tolerance

func _vector_from_row(row: Array) -> Vector3:
	return Vector3(float(row[0]), float(row[1]), float(row[2]))

func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()

func _read_descriptors() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	return parsed if parsed is Dictionary else {}

func _descriptor_by_id(document: Dictionary, profile_id: String) -> Dictionary:
	for value: Variant in document.get("profiles", []):
		if value is Dictionary and value.get("profile_id") == profile_id:
			return value
	return {}

func _node_oracle() -> Dictionary:
	var output: Array = []
	var source_path := ProjectSettings.globalize_path(SOURCE)
	var descriptor_path := ProjectSettings.globalize_path(DESCRIPTORS)
	var exit_code := OS.execute("node", PackedStringArray([
		"--input-type=module", "--eval", NODE_ORACLE, source_path, descriptor_path,
	]), output, true)
	_check(exit_code == 0 and output.size() == 1, "actual Node source oracle executes once")
	if exit_code != 0 or output.is_empty():
		return {}
	var raw_json := str(output[0]).strip_edges()
	node_oracle_sha256 = _sha256_text(raw_json)
	var parsed: Variant = JSON.parse_string(raw_json)
	_check(parsed is Dictionary, "actual Node source oracle returns JSON")
	return parsed if parsed is Dictionary else {}

func _run() -> void:
	_check(FileAccess.get_sha256(SOURCE) == SOURCE_SHA256, "exact crash mechanics source receipt")
	_check(FileAccess.get_sha256(DESCRIPTORS) == DESCRIPTORS_SHA256, "exact immutable descriptor receipt")
	var descriptors := _read_descriptors()
	_check(not descriptors.is_empty(), "descriptor authority parses")
	var oracle := _node_oracle()
	_check(oracle.get("profiles", []).size() == PROFILE_IDS.size(), "oracle covers compact hatch and bus")
	var oracle_profiles: Array = oracle.get("profiles", [])
	var oracle_corner_receipts: Array = []
	for profile_index in PROFILE_IDS.size():
		var profile_id: String = PROFILE_IDS[profile_index]
		var descriptor := _descriptor_by_id(descriptors, profile_id)
		var actual := Cage.new()
		_check(actual.configure_from_descriptor(descriptor), profile_id + " actual descriptor configures")
		_check(not actual.configure_from_descriptor(descriptor), profile_id + " cannot reconfigure")
		var oracle_profile: Dictionary = oracle_profiles[profile_index]
		_check(oracle_profile.id == profile_id, profile_id + " oracle order")
		var expected_profile: Dictionary = oracle_profile.profile
		var summary := actual.summary()
		_check(_close(summary.half_width_m, expected_profile.halfWidth)
			and _close(summary.half_length_m, expected_profile.halfLength)
			and _close(summary.height_m, expected_profile.height),
			profile_id + " descriptor-derived dimensions")
		_check(summary.nodes == Cage.NODE_COUNT and summary.beams == Cage.BEAM_COUNT
			and actual._rest_native.size() == 45 and actual._plastic_native.size() == 45
			and actual._positions_native.size() == 45
			and actual._velocities_native.size() == 45
			and actual._beam_a.size() == 232 and actual._beam_b.size() == 232
			and actual._beam_original_length_m.size() == 232,
			profile_id + " fixed preallocated storage")
		_check(actual._plastic_native == actual._rest_native
			and actual._positions_native == actual._rest_native,
			profile_id + " pristine plastic and position layers equal immutable rest")
		var oracle_nodes: Array = oracle_profile.nodes
		for node_index in Cage.NODE_COUNT:
			var expected_source := _vector_from_row(oracle_nodes[node_index])
			var expected_native: Vector3 = Cage.source_local_to_native(expected_source)
			_check(_vector_close(actual.rest_node_source(node_index), expected_source, 0.0000005)
				and _vector_close(actual.rest_node_native(node_index), expected_native, 0.0000005),
				profile_id + " node order/rest " + str(node_index))
		var oracle_beams: Array = oracle_profile.beams
		for beam_index in Cage.BEAM_COUNT:
			var expected_beam: Array = oracle_beams[beam_index]
			var beam := actual.beam(beam_index)
			_check(beam.a == int(expected_beam[0]) and beam.b == int(expected_beam[1])
				and _close(beam.original_length_m, float(expected_beam[2]), 0.0000005)
				and _close(beam.rest_length_m, float(expected_beam[3]), 0.0000005)
				and not beam.broken and beam.plastic_strain == 0.0,
				profile_id + " beam order/rest " + str(beam_index))
		var oracle_positions: Array = oracle_profile.positions
		for node_index in Cage.NODE_COUNT:
			actual._positions_native[node_index] = Cage.source_local_to_native(
				_vector_from_row(oracle_positions[node_index]))
		var corner_point_native: Vector3 = Cage.source_local_to_native(Vector3(
			oracle_profile.cornerPoint.x, oracle_profile.cornerPoint.y, oracle_profile.cornerPoint.z))
		var corner_expected_native: Vector3 = Cage.source_local_to_native(Vector3(
			oracle_profile.cornerSample.x, oracle_profile.cornerSample.y, oracle_profile.cornerSample.z))
		var interior_point_native: Vector3 = Cage.source_local_to_native(Vector3(
			oracle_profile.interiorPoint.x, oracle_profile.interiorPoint.y, oracle_profile.interiorPoint.z))
		var interior_expected_native: Vector3 = Cage.source_local_to_native(Vector3(
			oracle_profile.interiorSample.x, oracle_profile.interiorSample.y, oracle_profile.interiorSample.z))
		_check(_vector_close(actual.sample_deformation_native(corner_point_native),
			corner_expected_native, 0.000001), profile_id + " exact source corner sample")
		_check(_vector_close(actual.sample_deformation_native(interior_point_native),
			interior_expected_native, 0.000001), profile_id + " exact trilinear interior sample")
		oracle_corner_receipts.append({"profile_id": profile_id,
			"point_source": oracle_profile.cornerPoint,
			"sample_source": oracle_profile.cornerSample})
		var rest_snapshot: Vector3 = actual.rest_node_native(0)
		var external_copy: Vector3 = actual.rest_node_native(0)
		external_copy.x += 100.0
		_check(actual.rest_node_native(0) == rest_snapshot,
			profile_id + " rest geometry is not externally mutable")
		_check(actual.sample_deformation_native(Vector3(NAN, 0, 0)) == null,
			profile_id + " nonfinite sample fails closed")
	var malformed := _descriptor_by_id(descriptors, "compact_sedan").duplicate(true)
	malformed.body_half_extents_m.x = 100.0
	var rejected := Cage.new()
	_check(not rejected.configure_from_descriptor(malformed), "out-of-range descriptor is rejected, not clamped")
	malformed = _descriptor_by_id(descriptors, "compact_sedan").duplicate(true)
	malformed.body_half_extents_m.y = NAN
	_check(not rejected.configure_from_descriptor(malformed), "nonfinite descriptor is rejected")
	malformed = _descriptor_by_id(descriptors, "compact_sedan").duplicate(true)
	malformed.godot_forward_axis = "+Z"
	_check(not rejected.configure_from_descriptor(malformed), "axis contract mismatch is rejected")
	_check(Cage.source_local_to_native(Vector3(2, 3, 4)) == Vector3(-2, 3, -4)
		and Cage.native_local_to_source(Vector3(-2, 3, -4)) == Vector3(2, 3, 4),
		"source/native -X/-Z conversion is centralized and involutive")
	_check(Cage.source_local_to_native(Vector3(INF, 0, 0)) == null,
		"axis conversion rejects nonfinite vectors")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"source_sha256": FileAccess.get_sha256(SOURCE),
		"descriptor_sha256": FileAccess.get_sha256(DESCRIPTORS),
		"node_oracle_sha256": node_oracle_sha256,
		"node_oracle_corner_samples": oracle_corner_receipts,
		"component_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_crash_cage.gd"),
		"profiles": PROFILE_IDS, "nodes_per_profile": Cage.NODE_COUNT,
		"beams_per_profile": Cage.BEAM_COUNT,
		"scope": "proposal-only immutable cage/sample state; no impact HP debris runtime visual body main GPU LIVE"}
	print("NATIVE_VEHICLE_CRASH_CAGE_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
