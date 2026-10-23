class_name NativeVehicleBlastProposals
extends RefCounted
## Pure proposal port of blast_response.mjs:58-62 for an already-authoritative
## vehicle exposure receipt. The caller owns explosion identity, source exclusion,
## the source-equivalent world sample/cover query and target lifecycle authority.
## This component never creates an event, applies HP, moves a RigidBody3D, handles
## hero motion or mutates rollover state.

const SOURCE_SHA256 := "c21ab9ed18c9e2ec4a4cd1502f4b327b5d32f9f676d528051359bf6dfccd0a15"
const SOURCE_SAMPLE_LOCAL_M := Vector3(0.0, 0.8, 0.0)
const MIN_POWER := 0.05
const MAX_POWER := 4.0
const MIN_RADIUS_M := 1.0
const MAX_RADIUS_M := 24.0
const MAX_ID_LENGTH := 256
const MAX_SOURCE_EVENT_ID_LENGTH := 250
const SOURCE_KINDS := ["none", "external", "vehicle"]

static func propose(receipt_value: Variant) -> Dictionary:
	var rejected := {"accepted": false, "reason": "invalid", "damage_proposal": null,
		"roll_contact_proposal": null}
	if not receipt_value is Dictionary:
		return rejected
	var receipt: Dictionary = receipt_value
	if receipt.get("confirmed") != true or not receipt.get("source_event") is Dictionary \
			or not _valid_id(receipt.get("target_vehicle_id")) \
			or not receipt.get("target_life_generation") is int \
			or int(receipt.target_life_generation) < 1 \
			or not receipt.get("target_wrecked") is bool \
			or not receipt.get("target_destroying") is bool:
		return rejected
	var event: Dictionary = receipt.source_event
	if event.get("confirmed") != true or not _valid_source_event_id(event.get("event_id")) \
			or not _valid_id(event.get("damage_event_id")) \
			or event.get("damage_event_id") != "blast:" + str(event.get("event_id")) \
			or not event.get("source_kind") is String \
			or not SOURCE_KINDS.has(event.get("source_kind")) \
			or not event.get("blast_point_world_m") is Vector3 \
			or not _finite_number(event.get("power")) \
			or not _finite_number(event.get("radius_m")):
		return rejected
	var blast_point: Vector3 = event.blast_point_world_m
	var power := float(event.power)
	var radius := float(event.radius_m)
	# enqueue() owns clamping in the source. This downstream component accepts
	# only its normalized domain and fails closed instead of silently re-clamping.
	if not blast_point.is_finite() or power < MIN_POWER or power > MAX_POWER \
			or radius < MIN_RADIUS_M or radius > MAX_RADIUS_M:
		return rejected
	var source_kind: String = event.source_kind
	if source_kind == "vehicle":
		if not _valid_id(event.get("source_vehicle_id")) \
				or not event.get("source_life_generation") is int \
				or int(event.source_life_generation) < 1:
			return rejected
	elif event.has("source_vehicle_id") or event.has("source_life_generation"):
		return rejected
	if not receipt.get("target_is_source") is bool:
		return rejected
	if receipt.target_is_source and source_kind != "vehicle":
		return rejected
	var exact_source_pair: bool = source_kind == "vehicle" \
		and event.source_vehicle_id == receipt.target_vehicle_id \
		and event.source_life_generation == receipt.target_life_generation
	if receipt.target_is_source or exact_source_pair:
		rejected.reason = "source-vehicle"
		return rejected
	if receipt.target_wrecked or receipt.target_destroying:
		rejected.reason = "disabled-target"
		return rejected
	if not receipt.get("target_sample_world_m") is Vector3 \
			or not receipt.get("target_sample_local_m") is Vector3 \
			or not _finite_number(receipt.get("mass_kg")) \
			or not _finite_number(receipt.get("yaw_rad")) \
			or not _binary_cover(receipt.get("cover_transmission")):
		return rejected
	var sample_world: Vector3 = receipt.target_sample_world_m
	var sample_local: Vector3 = receipt.target_sample_local_m
	var mass_kg := float(receipt.mass_kg)
	var yaw_rad := float(receipt.yaw_rad)
	if not sample_world.is_finite() or not sample_local.is_finite() \
			or sample_local != SOURCE_SAMPLE_LOCAL_M or mass_kg <= 0.0:
		return rejected
	if float(receipt.cover_transmission) == 0.0:
		rejected.reason = "covered"
		return rejected
	var distance_m := sample_world.distance_to(blast_point)
	var falloff := maxf(0.0, 1.0 - distance_m / radius)
	if falloff == 0.0:
		rejected.reason = "outside-radius"
		return rejected
	var dx := sample_world.x - blast_point.x
	var dz := sample_world.z - blast_point.z
	var horizontal_length := sqrt(dx * dx + dz * dz)
	if horizontal_length == 0.0:
		horizontal_length = 1.0
	var normal_toward_blast := Vector3(-dx / horizontal_length, 0.0, -dz / horizontal_length)
	var roll_speed := 12.0 * sqrt(power) * falloff * 1500.0 / maxf(400.0, mass_kg)
	var identity := {"source_event_id": event.event_id,
		"source_kind": source_kind,
		"target_vehicle_id": receipt.target_vehicle_id,
		"target_life_generation": receipt.target_life_generation,
		"proposal_only": true, "server_admissible": false,
		"caller_dedupe_required": true,
		"replay_key": {"source_event_id": event.event_id,
			"target_vehicle_id": receipt.target_vehicle_id,
			"target_life_generation": receipt.target_life_generation}}
	if source_kind == "vehicle":
		identity.source_vehicle_id = event.source_vehicle_id
		identity.source_life_generation = event.source_life_generation
	var damage_proposal := identity.duplicate(true)
	damage_proposal.merge({"damage_event_id": event.damage_event_id,
		"kind": "blast", "raw_damage": 420.0 * power * falloff * falloff})
	var roll_proposal := identity.duplicate(true)
	roll_proposal.merge({"point_world_m": sample_world,
		"normal_world_toward_blast": normal_toward_blast,
		"impact_speed_mps": roll_speed, "slide_speed_mps": 0.0,
		"yaw_rad": yaw_rad})
	return {"accepted": true, "reason": "", "distance_m": distance_m,
		"falloff": falloff, "damage_proposal": damage_proposal,
		"roll_contact_proposal": roll_proposal}

static func _valid_id(value: Variant) -> bool:
	return value is String and not (value as String).is_empty() \
		and (value as String).length() <= MAX_ID_LENGTH

static func _valid_source_event_id(value: Variant) -> bool:
	return value is String and not (value as String).is_empty() \
		and (value as String).length() <= MAX_SOURCE_EVENT_ID_LENGTH

static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _binary_cover(value: Variant) -> bool:
	return _finite_number(value) and (float(value) == 0.0 or float(value) == 1.0)
