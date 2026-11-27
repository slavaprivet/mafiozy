extends RefCounted

const MIN_CONTACT_SPEED:=0.9

static func damage(weapon: String,contact_speed: float,prepared: float)->float:
	if weapon not in ["sword","axe","hatchet"] or contact_speed<=MIN_CONTACT_SPEED: return 0.0
	var drive:=clampf((contact_speed-MIN_CONTACT_SPEED)/5.2,0.32,1.25)
	var base:=38.0 if weapon=="axe" else (23.0 if weapon=="hatchet" else 11.0)
	return base*drive*clampf(prepared,0.72,1.18)
