extends SceneTree

const Packed = preload("res://scripts/vehicle_physics/vehicle_contact_packed_observation.gd")
const Onset = preload("res://scripts/vehicle_physics/vehicle_contact_onset_proposal.gd")

var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func observation(tick: int, closing: float, life: int = 1, peer_life: int = 1, vehicle_peer: bool = false) -> RefCounted:
	var o = Packed.new()
	o.valid = true
	o.complete = true
	o.collection_gap = false
	o.global_physics_tick = tick
	o.raw_state_contact_count = 1
	o.retained_contact_count = 1
	o.self_identity = {"valid": true, "kind": "vehicle", "vehicle_id": "self", "life_generation": life}
	o.target_root_frame_world = Transform3D(Basis(Vector3.UP, 0.4), Vector3(3, 2, 1))
	o.raw_indices[0] = 0
	o.counterpart_runtime_ids[0] = 101
	o.peer_identities[0] = {"valid": true, "kind": "vehicle", "vehicle_id": "other", "life_generation": peer_life, "counterpart_runtime_id": 101} if vehicle_peer else {"valid": true, "kind": "static", "source_id": "wall", "source_index": 1, "counterpart_runtime_id": 101}
	o.points_self_world[0] = o.target_root_frame_world * Vector3(1, 0, 0)
	o.normals_on_self_world[0] = Vector3.RIGHT
	o.velocities_self_world[0] = Vector3.LEFT * closing
	o.velocities_counterpart_world[0] = Vector3.ZERO
	o.relative_velocities_world[0] = o.velocities_self_world[0]
	o.closing_speeds_mps[0] = closing
	o.impulses_on_self_world_ns[0] = Vector3.ZERO
	o.row_valid[0] = 1
	return o

func _initialize() -> void:
	var latch = Onset.new()
	var initial: Variant = latch.scan(observation(1, 2.1), Onset.BRANCH_ACTIVE_STATIC)
	check(initial != null and initial.closing_speed_along_normal_mps == 2.1, "current 2.1 onset is emitted")
	var later: Variant = latch.scan(observation(2, 3.0), Onset.BRANCH_ACTIVE_STATIC)
	check(later != null, "continuous 3.0 static impact must remain observable after sub-crush 2.1")
	check(latch.scan(observation(3, 0.0), Onset.BRANCH_ACTIVE_STATIC) == null, "low closing rearms without emitting")
	check(latch.scan(observation(4, 3.0), Onset.BRANCH_ACTIVE_STATIC) != null, "rearmed 3.0 onset emits")
	var peer_latch = Onset.new()
	check(peer_latch.scan(observation(1, 3.0, 1, 1, true), Onset.BRANCH_PEER) != null, "peer first episode emits")
	check(peer_latch.scan(observation(2, 3.0, 1, 2, true), Onset.BRANCH_PEER) != null, "new peer life is a new episode")
	check(peer_latch.scan(observation(3, 3.0, 2, 2, true), Onset.BRANCH_PEER) != null, "new target life is a new episode")
	var empty = observation(5, 0.0)
	empty.raw_state_contact_count = 0
	empty.retained_contact_count = 0
	check(latch.scan(empty, Onset.BRANCH_ACTIVE_STATIC) == null, "empty callback does not read stale slot")
	check(latch.scan(observation(6, 3.0), Onset.BRANCH_ACTIVE_STATIC) != null, "return after empty callback emits")
	print("CONTACT_ONSET_INDEPENDENT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
