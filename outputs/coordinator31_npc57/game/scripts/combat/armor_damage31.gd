extends RefCounted
## Deterministic contact armour model. Input point is in the struck hitbox's
## local frame, divided by its half extents; no random "critical hit" roll.

const SLOT_FOR_PART := {
	"head": "head", "chest": "torso", "pelvis": "legs",
	"upperarm": "torso", "forearm": "hands", "hand": "hands",
	"thigh": "legs", "shin": "legs", "foot": "feet",
}
const PROTECTION := {
	"light": {"slice": 0.68, "stab": 0.82, "blunt": 0.86},
	"medium": {"slice": 0.38, "stab": 0.62, "blunt": 0.75},
	"heavy": {"slice": 0.11, "stab": 0.28, "blunt": 0.63},
}
const SLOT_WEIGHT := {"head": 0.13, "torso": 0.39, "hands": 0.12, "legs": 0.24, "feet": 0.12}
const TIER_MOBILITY := {"light": 1.06, "medium": 1.0, "heavy": 0.78}

static func slot_for_part(part: String) -> String:
	var base := part
	if base.ends_with("_l") or base.ends_with("_r"):
		base = base.substr(0, base.length() - 2)
	return str(SLOT_FOR_PART.get(base, ""))

static func tier_of(item_id: String, slot: String) -> String:
	if item_id.ends_with("_" + slot):
		var tier := item_id.trim_suffix("_" + slot)
		if PROTECTION.has(tier): return tier
	return ""

## Returns the exact remaining wound multiplier and the surface hit.
## normalized_point is clamped only to tolerate ray/shape numerical error.
static func resolve(equipment: Dictionary, part: String, kind: String,
		incoming: float, normalized_point: Vector3, incidence: float = 1.0) -> Dictionary:
	var slot := slot_for_part(part)
	var tier := tier_of(str(equipment.get(slot, "")), slot)
	var result := {"slot": slot, "tier": tier, "region": "skin", "factor": 1.0,
		"damage": maxf(0.0, incoming)}
	if tier == "" or incoming <= 0.0: return result
	var p := Vector3(clampf(normalized_point.x, -1.0, 1.0),
		clampf(normalized_point.y, -1.0, 1.0), clampf(normalized_point.z, -1.0, 1.0))
	var base := part
	if base.ends_with("_l") or base.ends_with("_r"):
		base = base.substr(0, base.length() - 2)
	# Two real visor apertures, neck, inner elbow, armpit, groin, rear knee,
	# ankle and wrist remain
	# physical openings. The contact coordinate, not an RNG roll, selects them.
	var seam := false
	var skin := false
	match base:
		"head":
			skin = p.y < -0.77
			# Heavy helmet has a solid central nose; each eye opening lies to
			# either side, above it, on the bone-local +Z face.
			seam = p.z > 0.70 and absf(p.x) > 0.40 and absf(p.x) < 0.96 \
				and p.y > 0.43 and p.y < 0.78
		"chest":
			seam = absf(p.x) > 0.78 or p.y < -0.75 or p.y > 0.83
		"pelvis":
			skin = absf(p.x) < 0.25 and p.y < -0.50
			seam = absf(p.x) > 0.75
		"upperarm", "forearm":
			seam = absf(p.y) > 0.73 or p.z > 0.68
		"hand":
			# Closed gloves cover the fist and fingers on +Y. The forearm
			# lies toward -Y in hand-local coordinates; that cuff is a joint.
			seam = absf(p.x) > 0.80 or p.y < -0.72
		"thigh", "shin":
			seam = absf(p.y) > 0.76 or p.z > 0.72
		"foot":
			# Foot-local +Y points toward the toe, which the boot covers.
			# The actual ankle is above/outside this foot box and is tested
			# through the lower shin joint instead.
			seam = absf(p.x) > 0.86
	if skin:
		result.region = "skin"
		return result
	var attack := kind if kind in ["slice", "stab", "blunt"] else "blunt"
	var factor := float(PROTECTION[tier][attack])
	if seam:
		result.region = "joint"
		# Mail or cloth fills some gaps, but a point can still find its links.
		factor = maxf(factor, 0.78 if attack == "slice" else 0.90)
	else:
		result.region = "plate" if tier == "heavy" else ("mail" if tier == "medium" else "cloth")
		# A grazing thrust transfers less energy than a square hit. The blade's
		# speed, mass and preparation have already set the incoming damage.
		if attack == "stab":
			factor *= 0.65 + 0.35 * clampf(incidence, 0.0, 1.0)
		factor += clampf((incoming - 35.0) / 135.0, 0.0, 0.25)
	result.factor = clampf(factor, 0.05, 1.0)
	result.damage = incoming * result.factor
	return result

static func movement_multiplier(equipment: Dictionary) -> float:
	var value := 1.0
	for slot: String in SLOT_WEIGHT:
		var tier := tier_of(str(equipment.get(slot, "")), slot)
		if tier != "": value += float(SLOT_WEIGHT[slot]) * (float(TIER_MOBILITY[tier]) - 1.0)
	return clampf(value, 0.76, 1.06)

## Residual trauma still reduces health when steel turns the edge. Blood and
## severing need tissue penetration. 14 damage is a decisive point; a broad
## edge needs twice that residual energy to break a plate seam or rivet.
static func tissue_penetrates(region: String, kind: String, residual_damage: float) -> bool:
	if region in ["skin", "joint", "cloth", "mail"]: return true
	if region != "plate": return false
	if kind == "stab": return residual_damage >= 14.0
	if kind == "slice": return residual_damage >= 28.0
	return false
