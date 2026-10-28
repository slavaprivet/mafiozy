extends SceneTree
## Exact CPU oracle for blast_response.mjs vehicle exposure lines 58-62.

const Proposals = preload("res://scripts/vehicle_physics/vehicle_blast_proposals.gd")
const SOURCE := "res://../../assets/maps/city_rebuild_v1/blast_response.mjs"
const SOURCE_SHA256 := "c21ab9ed18c9e2ec4a4cd1502f4b327b5d32f9f676d528051359bf6dfccd0a15"
const NODE_ORACLE := """
const cases=[
 {id:'light',blast:[0,.8,0],sample:[5,.8,0],power:1,radius:10,mass:1500,yaw:0,cover:1},
 {id:'heavy',blast:[0,.8,0],sample:[5,.8,0],power:1,radius:10,mass:9800,yaw:0,cover:1},
 {id:'coincident',blast:[0,.8,0],sample:[0,.8,0],power:4,radius:10,mass:1500,yaw:1.2,cover:1},
 {id:'covered',blast:[0,.8,0],sample:[5,.8,0],power:1,radius:10,mass:1500,yaw:0,cover:0},
 {id:'source',blast:[0,.8,0],sample:[5,.8,0],power:1,radius:10,mass:1500,yaw:0,cover:1,sourceExact:true},
 {id:'source-less',blast:[0,.8,0],sample:[5,.8,0],power:1,radius:10,mass:1500,yaw:0,cover:1,sourceKind:'none'},
 {id:'external',blast:[0,.8,0],sample:[5,.8,0],power:1,radius:10,mass:1500,yaw:0,cover:1,sourceKind:'external'},
 {id:'respawn-same-id',blast:[0,.8,0],sample:[5,.8,0],power:1,radius:10,mass:1500,yaw:0,cover:1,respawn:true},
 {id:'wreck',blast:[0,.8,0],sample:[5,.8,0],power:1,radius:10,mass:1500,yaw:0,cover:1,wreck:true},
 {id:'outside',blast:[0,.8,0],sample:[10,.8,0],power:1,radius:10,mass:1500,yaw:0,cover:1},
 {id:'vertical3d',blast:[0,0,0],sample:[6,8,0],power:.05,radius:24,mass:399,yaw:-.4,cover:1},
];
function exact(c){
 if(c.sourceExact||c.wreck||!c.cover)return null;
 const dx3=c.sample[0]-c.blast[0],dy3=c.sample[1]-c.blast[1],dz3=c.sample[2]-c.blast[2];
 const distance=Math.hypot(dx3,dy3,dz3),falloff=Math.max(0,1-distance/c.radius);if(!falloff)return null;
 const dx=dx3,dz=dz3,length=Math.hypot(dx,dz)||1;
 return {distance,falloff,damage:420*c.power*falloff*falloff,normal:[-dx/length,0,-dz/length],impactSpeed:12*Math.sqrt(c.power)*falloff*1500/Math.max(400,c.mass),slideSpeed:0,yaw:c.yaw};
}
console.log(JSON.stringify(cases.map(c=>({id:c.id,input:c,expected:exact(c)}))));
"""

var checks := 0
var failures: Array[String] = []
var oracle_sha256 := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _close(a: float, b: float, tolerance := 0.000001) -> bool:
	return absf(a - b) <= tolerance

func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()

func _oracle() -> Array:
	var output: Array = []
	var exit_code := OS.execute("node", PackedStringArray([
		"--input-type=module", "--eval", NODE_ORACLE,
	]), output, true)
	_check(exit_code == 0 and output.size() == 1, "Node exact resolver stub executes")
	if exit_code != 0 or output.is_empty():
		return []
	var raw := str(output[0]).strip_edges()
	oracle_sha256 = _sha256_text(raw)
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array, "Node resolver returns scenario rows")
	return parsed if parsed is Array else []

func _receipt(row: Dictionary) -> Dictionary:
	var input: Dictionary = row.input
	var source_id := "vehicle-source"
	var source_kind: String = input.get("sourceKind", "vehicle")
	var target_id := source_id if input.get("sourceExact", false) \
		or input.get("respawn", false) else "vehicle-target"
	var source_life := 6 if input.get("respawn", false) else 7
	var source_event := {"confirmed": true, "event_id": "authoritative:" + row.id,
		"damage_event_id": "blast:authoritative:" + row.id,
		"source_kind": source_kind,
		"blast_point_world_m": Vector3(input.blast[0], input.blast[1], input.blast[2]),
		"power": input.power, "radius_m": input.radius}
	if source_kind == "vehicle":
		source_event.source_vehicle_id = source_id
		source_event.source_life_generation = source_life
	return {"confirmed": true, "source_event": source_event,
		"target_vehicle_id": target_id, "target_life_generation": 7,
		"target_is_source": input.get("sourceExact", false),
		"target_wrecked": input.get("wreck", false), "target_destroying": false,
		"target_sample_world_m": Vector3(input.sample[0], input.sample[1], input.sample[2]),
		"target_sample_local_m": Vector3(0.0, 0.8, 0.0),
		"cover_transmission": input.cover, "mass_kg": input.mass, "yaw_rad": input.yaw}

func _run() -> void:
	_check(FileAccess.get_sha256(SOURCE) == SOURCE_SHA256, "exact blast source receipt")
	var source_text := FileAccess.get_file_as_string(SOURCE)
	_check(source_text.contains("const p=v.car.object.localToWorld(new T.Vector3(0,.8,0))")
		and source_text.contains("damage:420*event.power*falloff*falloff")
		and source_text.contains("impactSpeed:12*Math.sqrt(event.power)*falloff*1500/mass"),
		"oracle formulas remain visibly pinned to actual source")
	var rows := _oracle()
	_check(rows.size() == 11,
		"light heavy coincident covered source source-less external respawn wreck outside vertical cases")
	for row_value: Variant in rows:
		var row: Dictionary = row_value
		var result := Proposals.propose(_receipt(row))
		if row.expected == null:
			_check(not result.accepted and result.damage_proposal == null
				and result.roll_contact_proposal == null, row.id + " emits no proposal")
			continue
		var expected: Dictionary = row.expected
		_check(result.accepted and _close(result.distance_m, expected.distance)
			and _close(result.falloff, expected.falloff), row.id + " exact 3D falloff")
		_check(_close(result.damage_proposal.raw_damage, expected.damage)
			and result.damage_proposal.damage_event_id == "blast:authoritative:" + row.id
			and result.damage_proposal.target_vehicle_id == _receipt(row).target_vehicle_id
			and result.damage_proposal.target_life_generation == 7,
			row.id + " raw HP proposal and authoritative identity")
		_check(result.damage_proposal.proposal_only
			and result.damage_proposal.server_admissible == false
			and result.damage_proposal.caller_dedupe_required
			and result.roll_contact_proposal.proposal_only
			and result.roll_contact_proposal.server_admissible == false
			and result.roll_contact_proposal.caller_dedupe_required
			and result.damage_proposal.replay_key == result.roll_contact_proposal.replay_key,
			row.id + " explicit proposal-only caller replay boundary")
		var normal: Vector3 = result.roll_contact_proposal.normal_world_toward_blast
		_check(normal.distance_to(Vector3(expected.normal[0], expected.normal[1], expected.normal[2]))
			<= 0.000001 and _close(result.roll_contact_proposal.impact_speed_mps,
			expected.impactSpeed) and result.roll_contact_proposal.slide_speed_mps == 0.0
			and _close(result.roll_contact_proposal.yaw_rad, expected.yaw),
			row.id + " exact rollover contact proposal")
	var valid := _receipt(rows[0])
	for mutation in [
		{"path": "confirmed", "value": false},
		{"path": "power", "value": 0.049},
		{"path": "power", "value": 4.001},
		{"path": "radius", "value": 0.99},
		{"path": "radius", "value": 24.01},
		{"path": "cover", "value": 0.5},
		{"path": "mass", "value": 0.0},
		{"path": "local", "value": Vector3(0.0, 0.81, 0.0)},
		{"path": "source_kind", "value": "invented"},
		{"path": "source_event_id", "value": "x".repeat(251)},
	]:
		var malformed := valid.duplicate(true)
		match mutation.path:
			"confirmed": malformed.confirmed = mutation.value
			"power": malformed.source_event.power = mutation.value
			"radius": malformed.source_event.radius_m = mutation.value
			"cover": malformed.cover_transmission = mutation.value
			"mass": malformed.mass_kg = mutation.value
			"local": malformed.target_sample_local_m = mutation.value
			"source_kind": malformed.source_event.source_kind = mutation.value
			"source_event_id":
				malformed.source_event.event_id = mutation.value
				malformed.source_event.damage_event_id = "blast:" + mutation.value
		_check(not Proposals.propose(malformed).accepted,
			"invalid receipt fails closed: " + mutation.path + "=" + str(mutation.value))
	var result_a := Proposals.propose(valid)
	var result_b := Proposals.propose(valid)
	result_a.damage_proposal.raw_damage = -1.0
	_check(result_b.damage_proposal.raw_damage > 0.0,
		"pure proposals share no mutable result state")
	_check(result_a.damage_proposal.replay_key.source_event_id
		== result_b.damage_proposal.replay_key.source_event_id,
		"repeated pure proposal exposes the same caller dedupe tuple without a local ledger")
	var sibling_result := Proposals.propose(valid)
	var preserved_roll_key: Dictionary = sibling_result.roll_contact_proposal.replay_key.duplicate(true)
	sibling_result.damage_proposal.replay_key.target_vehicle_id = "mutated-sibling"
	_check(sibling_result.roll_contact_proposal.replay_key == preserved_roll_key,
		"damage and rollover sibling replay dictionaries are mutation-isolated")
	var receipt_isolation_input := valid.duplicate(true)
	var receipt_isolation_result := Proposals.propose(receipt_isolation_input)
	receipt_isolation_input.source_event.event_id = "mutated-after-proposal"
	receipt_isolation_input.source_event.damage_event_id = "blast:mutated-after-proposal"
	receipt_isolation_input.target_vehicle_id = "mutated-after-proposal"
	_check(receipt_isolation_result.damage_proposal.source_event_id != "mutated-after-proposal"
		and receipt_isolation_result.damage_proposal.target_vehicle_id != "mutated-after-proposal"
		and receipt_isolation_result.roll_contact_proposal.replay_key.source_event_id
		!= "mutated-after-proposal", "returned proposals do not alias the caller receipt")
	var same_pair_unflagged := _receipt(rows[4])
	same_pair_unflagged.target_is_source = false
	_check(Proposals.propose(same_pair_unflagged).reason == "source-vehicle",
		"exact vehicle id plus life pair excludes even without trusted alias flag")
	var trusted_alias := valid.duplicate(true)
	trusted_alias.target_is_source = true
	_check(Proposals.propose(trusted_alias).reason == "source-vehicle",
		"trusted target-is-source alias excludes a remapped vehicle identity")
	var invalid_external_alias := _receipt(rows[6])
	invalid_external_alias.target_is_source = true
	_check(Proposals.propose(invalid_external_alias).reason == "invalid",
		"external source cannot claim a vehicle-source alias")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"source_sha256": FileAccess.get_sha256(SOURCE), "node_oracle_sha256": oracle_sha256,
		"component_sha256": FileAccess.get_sha256(
			"res://scripts/vehicle_physics/vehicle_blast_proposals.gd"),
		"cases": rows.size(),
		"scope": "pure authoritative vehicle exposure to raw HP and rollover proposals; no event HP rigid body hero main GPU LIVE"}
	print("NATIVE_VEHICLE_BLAST_PROPOSALS_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
