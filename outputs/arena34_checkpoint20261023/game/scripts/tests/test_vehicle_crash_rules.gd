extends SceneTree

const Rules = preload("res://scripts/vehicle_physics/vehicle_crash_rules.gd")
const TRANSPORT := "res://data/transport/vehicle_descriptors.v1.json"
const TRANSPORT_SHA := "99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func close(actual: float, expected: float, tolerance := 0.000001) -> bool:
	return absf(actual - expected) <= tolerance * maxf(1.0, absf(expected))

func run() -> void:
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs") == "3faeed3b6bea790396c7676958100bd5520105d452a61a14c45977d38095a166", "crash mechanics source receipt")
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/vehicle_damage.mjs") == "e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92", "damage source receipt")
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/vehicle_occupant_crash_pulse_event.mjs") == "755fde5d4cad9e90bba1f108b2e96aa2cef785c71c9886ac707e78af6b632edd", "occupant pulse source receipt")
	check(FileAccess.get_sha256(TRANSPORT) == TRANSPORT_SHA, "frozen transport descriptor receipt")
	var unique_part_ids := {}
	for part_id: String in Rules.PART_IDS:
		unique_part_ids[part_id] = true
	check(Rules.PART_IDS == ["hood", "trunk", "door_front_left", "door_front_right", "door_rear_left", "door_rear_right", "bumper_front", "bumper_rear", "wheel_front_left", "wheel_front_right", "wheel_rear_left", "wheel_rear_right"] and unique_part_ids.size() == 12, "exact bounded structural part ids")
	check(Rules.WHEEL_IDS == ["front_left", "front_right", "rear_left", "rear_right"], "exact source wheel ids")
	check(Rules.EXPLOSION_DEBRIS_CAP == 10 and Rules.STRUCTURAL_DEBRIS_CAP == 12, "source debris caps")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRANSPORT))
	var sedan: Dictionary = {}
	for candidate: Dictionary in document.profiles:
		if candidate.profile_id == "compact_sedan": sedan = candidate; break
	var limits := Rules.crush_limits(sedan)
	check(limits.is_equal_approx(Vector3(1.3, 0.7470694, 1.65)), "source compact runtime crush ellipsoid")
	var expected := {
		2.5:{"energy":4125.0,"severity":0.0,"radius":0.6225,"depth":0.0,"damage":1},
		4.1:{"energy":11094.6,"severity":0.05557894736842105,"radius":0.6881,"depth":0.030177409712929218,"damage":1},
		8.0:{"energy":42240.0,"severity":0.31115204678362574,"radius":0.848,"depth":0.16987432577622752,"damage":5},
		17.0:{"energy":190740.0,"severity":1.9549985380116959,"radius":1.217,"depth":1.0844124910116288,"damage":24},
		30.0:{"energy":594000.0,"severity":6.209210526315789,"radius":1.75,"depth":1.65,"damage":75},
	}
	var subthreshold: Dictionary = Rules.impact_envelope(sedan, Vector3(0, 0, 1), 2.49)
	check(not subthreshold.applied and subthreshold.collision_damage_proposal == 1, "structural threshold remains separate from local collision damage proposal")
	for speed: float in expected:
		var actual: Dictionary = Rules.impact_envelope(sedan, Vector3(0, 0, 1), speed)
		var oracle: Dictionary = expected[speed]
		check(actual.valid and actual.applied and actual.proposal_only, "source envelope admitted " + str(speed))
		check(close(actual.energy_j, oracle.energy), "source impact energy " + str(speed))
		check(close(actual.severity, oracle.severity), "source impact severity " + str(speed))
		check(close(actual.radius_m, oracle.radius), "source impact radius " + str(speed))
		check(close(actual.depth_m, oracle.depth), "source impact depth " + str(speed))
		check(actual.collision_damage_proposal == oracle.damage, "source collision damage proposal " + str(speed))
	var local_hp := Rules.local_collision_hp_proposal(20, 90.0)
	check(local_hp.valid and local_hp.proposal_only and local_hp.hp_after == 1 and not local_hp.may_start_fire and not local_hp.may_start_explosion, "local collision proposal preserves nonlethal adapter policy")
	check(not Rules.local_collision_hp_proposal(0, 20.0).valid, "local collision proposal never resurrects a wreck")
	check(not Rules.impact_envelope({"mass_kg":1320,"body_half_extents_m":{"x":0,"y":1,"z":2}}, Vector3.FORWARD, 10).valid, "zero extent fails closed")
	check(not Rules.impact_envelope({"mass_kg":1320,"body_half_extents_m":{"x":"wide","y":1,"z":2}}, Vector3.FORWARD, 10).valid, "malformed extent fails closed")
	check(not Rules.impact_envelope(sedan, Vector3.ZERO, 10).valid, "zero normal fails closed")
	var clamped: Dictionary = Rules.impact_envelope(sedan, Vector3.FORWARD, 120.0)
	check(clamped.valid and clamped.impact_mps == 90.0 and clamped.collision_damage_proposal == Rules.COLLISION_DAMAGE_CAP, "impact speed and damage cap stay bounded")
	var thresholds := Rules.damage_thresholds(240)
	check(thresholds.valid and thresholds.smoke_hp == 132 and thresholds.fire_hp == 57, "sedan smoke/fire thresholds")
	check(close(thresholds.destruction_delay_s, 1.55) and thresholds.collision_hp_floor == 1, "delayed weapon destruction and collision floor remain separate")
	print("NATIVE_VEHICLE_CRASH_RULES_TEST ", JSON.stringify({"passed":failures.is_empty(), "checks":checks,
		"failures":failures, "scope":"source crash/deformation proposal rules only; no HP, explosion, debris node, occupant death, GPU or LIVE authority"}))
	quit(0 if failures.is_empty() else 1)
