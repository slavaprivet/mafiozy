extends RefCounted
## Gameplay tuning, NOT structural engineering. Glass belongs to the Walk port.
const DEFAULTS = {"wood":40.0,"plaster":60.0,"brick":90.0,"stone":115.0,"concrete":150.0,"metal":240.0}
const ALIASES = {"wood":["wood","timber","plank","plywood"],"plaster":["plaster","stucco"],"brick":["brick","terracotta"],"stone":["stone","marble","limestone"],"concrete":["concrete","cement"],"metal":["metal","steel","iron","brass"]}

static func classify(mesh_name:String, material:Material, explicit:String="", mixed:bool=false) -> String:
	# A mixed-material building named GlassTower is not made entirely of glass.
	# Match Walk: mesh labels are only a fallback for single-material geometry.
	var label = (("" if mixed else mesh_name)+" "+(material.resource_name if material else "")).to_lower()
	# An explicit glass flag always wins, including opaque authored glass materials.
	if material != null and material.has_meta("breakableGlass") and material.get_meta("breakableGlass") == true:
		return "glass"
	for token in ["glass","glazing","windshield","windscreen"]:
		if token in label: return "glass"
	# Authored uncertainty is a hard hold, not permission to infer strength from
	# an interior finish name (for example plaster painted to look like brick).
	if explicit.to_lower()=="unknown": return "unknown"
	if explicit in DEFAULTS: return explicit
	for family in ALIASES:
		for token in ALIASES[family]:
			if token in label: return family
	return "unknown"

static func threshold(material:String, thickness_m:float=.2) -> float:
	if not DEFAULTS.has(material) or not is_finite(thickness_m) or thickness_m <= 0.0: return INF
	return DEFAULTS[material]*clampf(thickness_m/.2,.3,4.0)

static func damage(power:float,distance_m:float,radius_m:float) -> float:
	if not is_finite(power) or not is_finite(distance_m) or not is_finite(radius_m) or power<=0.0 or radius_m<=0.0 or distance_m<0.0: return 0.0
	return power*maxf(0.0,1.0-distance_m/radius_m)

static func cell_damage(power:float,impact:Vector3,cell:AABB,radius_m:float) -> float:
	# A direct impact damages its cell regardless of arbitrary world-grid phase.
	# Centre-only falloff made a concrete wall immune at cell corners even when
	# the rocket's admitted power exceeded that material's local threshold.
	if not impact.is_finite() or not cell.position.is_finite() or not cell.size.is_finite(): return 0.0
	return damage(power,impact.distance_to(impact.clamp(cell.position,cell.end)),radius_m)
