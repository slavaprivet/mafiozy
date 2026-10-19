extends RefCounted
## Explicitly selected thin authored solids. No inferred box or hollow recipe.
## Cold source admission is synchronous and capped by convex_source's budgets.
const Source = preload("convex_source.gd")
const MAX_THICKNESS_M := 1.0
const GEOMETRY_PROVENANCE := "RETAIN_AUTHORED_CLOSED_THIN_SOLID"
const ROLES := ["exterior_wall", "floor_or_roof_slab", "interior_partition", "bounded_authored_component"]
const LIMIT_KEYS := ["max_long_axis_m","max_middle_axis_m","max_short_axis_m","max_bounds_volume_m3","max_true_volume_m3","max_source_triangles","max_welded_positions","existing_work_and_fragment_caps_unchanged"]

static func inspect(source: Dictionary, frame: Transform3D, profile: Dictionary) -> Dictionary:
	return prepare(source,frame,profile)

static func prepare(source: Dictionary, frame: Transform3D, profile: Dictionary) -> Dictionary:
	if profile.get("geometry_mode","")!="measured_convex_solid": return _no("explicit_measured_solid_mode_required")
	if profile.get("provenance","")!="USER_AUTHORIZED_NEW_GAMEPLAY_TEMPLATE" or profile.get("geometry_provenance","")!=GEOMETRY_PROVENANCE:
		return _no("explicit_measured_solid_provenance_required")
	if str(profile.get("source_role","")) not in ROLES: return _no("explicit_measured_solid_source_role_required")
	var limits: Variant=profile.get("source_limits",{})
	if not limits is Dictionary: return _no("source_limits_dictionary_required")
	for key: Variant in limits:
		if key not in LIMIT_KEYS: return _no("unknown_source_limit")
		var value: Variant=limits[key]
		if key=="existing_work_and_fragment_caps_unchanged":
			if value!=true: return _no("existing_work_caps_must_remain_unchanged")
			continue
		if (not value is float and not value is int) or not is_finite(float(value)) or float(value)<=0: return _no("finite_positive_source_limit_required")
		if key in ["max_source_triangles","max_welded_positions"]:
			var hard_cap: int=Source.MAX_SOURCE_TRIANGLES if key=="max_source_triangles" else Source.MAX_SOURCE_POINTS
			if float(value)!=floorf(float(value)) or float(value)>hard_cap: return _no("source_work_cap_cannot_be_raised")
	# Source._parse only admits exact, closed, outward convex source geometry.
	# Its private mode is a geometry parser contract, not a hollow/solid decision.
	var geometry_profile: Dictionary=profile.duplicate(true)
	geometry_profile.geometry_mode="hollow_convex_shell"
	var started:=Time.get_ticks_usec()
	var parsed:=Source._parse(source,frame,geometry_profile)
	if not parsed.get("ok",false): return parsed
	var sizes: Vector3=parsed.box.size*Vector3(frame.basis.x.length(),frame.basis.y.length(),frame.basis.z.length())
	var axes: Array[float]=[sizes.x,sizes.y,sizes.z]; axes.sort()
	var measurements: Dictionary={"max_long_axis_m":axes[2],"max_middle_axis_m":axes[1],"max_short_axis_m":axes[0],"max_bounds_volume_m3":parsed.box.get_volume()*frame.basis.determinant(),"max_true_volume_m3":parsed.original_volume,"max_source_triangles":parsed.triangle_count,"max_welded_positions":parsed.points.size()}
	for key: String in measurements:
		if not limits.has(key): continue
		var epsilon:=0.0 if key in ["max_source_triangles","max_welded_positions"] else .00001
		if float(measurements[key])>float(limits[key])+epsilon:
			var failed:=_no("source_limit_exceeded:"+key)
			failed["measured"]=measurements[key]; failed["limit"]=limits[key]
			return failed
	var actual: float=parsed.thickness
	# Minimum separation between an authored outward support plane and its
	# farthest source point, measured AFTER the node/placement transform. A
	# diagonal world AABB is not a physical wall gauge.
	if not is_finite(actual) or actual>MAX_THICKNESS_M+.00001: return _no("authored_solid_exceeds_one_metre_gauge")
	var recipe: Dictionary=profile.duplicate(true)
	recipe.thickness_m=actual; recipe.wall_thickness_m=actual
	recipe.thickness_space="world_metres"
	recipe.thickness_provenance="MEASURED_AUTHORED_SUPPORT_PLANE_SEPARATION"
	recipe.erase("world_from_model_basis")
	parsed.profile=recipe.duplicate(true); parsed.binding.profile=recipe.duplicate(true)
	parsed["original_mesh_materials"]=[]
	for surface: int in parsed.mesh.get_surface_count(): parsed.original_mesh_materials.append(parsed.mesh.surface_get_material(surface))
	var volume: float=parsed.original_volume
	var state: Dictionary={
		"ok":true,"schema":"mafiozi.hollow-wall-state/v1",
		"core_geometry":"measured_authored_convex_solid","parsed":parsed,"recipe":recipe,
		"solids":[parsed.faces],"inner_air":[],"outer_volume_m3":volume,
		"inner_air_m3":0.0,"wall_volume_m3":volume,"removed_volume_m3":0.0,"brushes":[],
		"source_unchanged":true,"whole_source_is_not_solid":false,"scene_mutated":false,
		"diagnostics":{"parse_usec":Time.get_ticks_usec()-started,"source_triangles":parsed.triangle_count,"cold_loading_only":true}
	}
	return {"ok":true,"state":state,"thickness_m":actual,"true_volume_m3":volume,
		"outer_volume_m3":volume,"inner_air_m3":0.0,"triangles":parsed.triangle_count,
		"source_role":recipe.source_role,"geometry_provenance":GEOMETRY_PROVENANCE,"source_measurements":measurements,
		"source_unchanged":true,"scene_mutated":false,"cold_loading_only":true,"parse_usec":state.diagnostics.parse_usec}

static func _no(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"scene_mutated":false,"source_unchanged":true}
