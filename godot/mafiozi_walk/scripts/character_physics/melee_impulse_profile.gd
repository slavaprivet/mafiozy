extends RefCounted
## Pure authored game-force proposal. Caller owns real contact admission,
## source identity/HP/replay, stance policy and the single physical application.
## Point velocities MUST include actual striking-limb motion. No speed is added.
const STANCES := ["standing", "crouched", "prone", "airborne", "seated"]
const ATTACKS := ["punch", "shove", "kick"]
const MAX_POINT_M := 10000000.0
const MAX_SPEED_MPS := 100.0
const MAX_MASS_KG := 1000.0
const MAX_IMPULSE_NS := 1000.0

static func authored_profile(attack: String) -> Dictionary:
	# Initial authored tuning, not measured biomechanics or approved balance.
	var values: Array
	match attack:
		"punch": values = [3.0, .05, 6.0, 45.0]
		"shove": values = [20.0, 0.0, 3.0, 80.0]
		"kick": values = [8.0, .10, 8.0, 100.0]
		_: return {}
	return {"id":"authored_melee_"+attack+"_v1", "attack":attack,
		"effective_striking_mass_kg":values[0], "restitution":values[1],
		"strike_speed_limit_mps":values[2], "impulse_limit_ns":values[3]}

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum

static func _vector(value: Variant, limit: float) -> bool:
	return value is Vector3 and value.is_finite() and maxf(absf(value.x),maxf(absf(value.y),absf(value.z))) <= limit

static func _unit(value: Variant) -> bool:
	return _vector(value,1.0001) and absf(value.length_squared()-1.0) <= .0001

static func propose(contact: Dictionary, calibration: Dictionary) -> Dictionary:
	if not contact.get("admitted") is bool or not contact.admitted:
		return {"ok":false,"error":"contact_not_admitted"}
	if not _vector(contact.get("world_point"),MAX_POINT_M): return {"ok":false,"error":"world_point"}
	if not _unit(contact.get("outward_normal")) or not _unit(contact.get("attack_direction")):
		return {"ok":false,"error":"contact_direction"}
	for key: String in ["attacker_point_velocity_mps","defender_point_velocity_mps"]:
		if not _vector(contact.get(key),MAX_SPEED_MPS) or contact[key].length() > MAX_SPEED_MPS:
			return {"ok":false,"error":"point_velocity"}
	for key: String in ["attacker_mass_kg","defender_mass_kg"]:
		if not _number(contact.get(key),1.0,MAX_MASS_KG): return {"ok":false,"error":"body_mass"}
	if not contact.get("stance") is String or contact.stance not in STANCES: return {"ok":false,"error":"stance"}
	if calibration.size()!=6 or not calibration.get("attack") is String or calibration.attack not in ATTACKS or calibration.get("id") != "authored_melee_"+calibration.attack+"_v1":
		return {"ok":false,"error":"profile_identity"}
	if not _number(calibration.get("effective_striking_mass_kg"),.01,float(contact.attacker_mass_kg)) or not _number(calibration.get("restitution"),0.0,1.0) or not _number(calibration.get("strike_speed_limit_mps"),.01,MAX_SPEED_MPS) or not _number(calibration.get("impulse_limit_ns"),.001,MAX_IMPULSE_NS):
		return {"ok":false,"error":"profile_coefficients"}
	# Source normal points OUT of the defender toward the striking limb.
	# A frictionless compressive impulse on the defender points inward.
	var direction: Vector3 = -(contact.outward_normal as Vector3).normalized()
	var relative: Vector3 = contact.attacker_point_velocity_mps-contact.defender_point_velocity_mps
	var closing := relative.dot(direction)
	var alignment: float = (contact.attack_direction as Vector3).dot(direction)
	var reason := "approaching_contact"
	var used_speed := minf(maxf(0.0,closing),float(calibration.strike_speed_limit_mps))
	if alignment <= 0.0: reason="attack_points_away";used_speed=0.0
	elif closing <= 0.0: reason="separating_or_stationary";used_speed=0.0
	var striking_mass := float(calibration.effective_striking_mass_kg)
	var defender_mass := float(contact.defender_mass_kg)
	var reduced_mass := 1.0/(1.0/striking_mass+1.0/defender_mass)
	var uncapped := (1.0+float(calibration.restitution))*reduced_mass*used_speed
	var magnitude := minf(uncapped,float(calibration.impulse_limit_ns))
	return {"ok":true,"proposal_only":true,"reason":reason,"impulse_ns":direction*magnitude,
		"magnitude_ns":magnitude,"uncapped_magnitude_ns":uncapped,"world_point":contact.world_point,
		"stance":contact.stance,"force_profile_id":calibration.id,
		"measured":{"attacker_point_velocity_mps":contact.attacker_point_velocity_mps,
			"defender_point_velocity_mps":contact.defender_point_velocity_mps,"closing_normal_speed_mps":closing,
			"attack_normal_alignment":alignment,"outward_normal":contact.outward_normal},
		"model":{"attacker_mass_kg":contact.attacker_mass_kg,"defender_mass_kg":defender_mass,
			"reduced_mass_kg":reduced_mass,"used_closing_speed_mps":used_speed,
			"speed_limited":closing>float(calibration.strike_speed_limit_mps),"impulse_limited":uncapped>magnitude},
		"authored":calibration.duplicate(),
		"provenance":"authored_gameforce_translational_reduced_mass_v1",
		"application":"one_impulse_at_world_point_no_extra_torque",
		"balance_approved":false}
