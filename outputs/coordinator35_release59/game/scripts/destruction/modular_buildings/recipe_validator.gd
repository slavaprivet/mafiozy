extends RefCounted
## Pure preflight before the first node/resource/physics mutation. No native
## admission receipt is produced. Validate every field read by the site/host.
const MAX_PARTS := 768
const ROLES := ["EntranceModular","EntranceLintel","FacadeModule","CorniceModule","FoundationChunk","BasementWall","FloorSlab","RoofSlab","StairFlight","StairLanding","InteriorPartition","InteriorDoorLintel","InteriorDoor","BusinessSign","EntranceCanopy"]

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and float(value)==floorf(float(value))

static func _positive(value: Variant) -> bool:
	return _number(value) and float(value)>0.001

static func _vector(value: Variant, count: int, positive: bool = false) -> bool:
	if not value is Array or value.size()!=count: return false
	for item: Variant in value:
		if not _number(item) or absf(float(item))>1000.0 or (positive and float(item)<=0.001): return false
	return true

static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length()<=200

static func _text(value: Variant) -> bool:
	return value is String and value.length()<=5000

static func _color(value: Variant) -> bool:
	return value is String and Color.html_is_valid(value)

static func _rect(value: Variant) -> bool:
	return _vector(value,4) and float(value[2])-float(value[0])>0.001 and float(value[3])-float(value[1])>0.001

static func _json(value: Variant, depth: int = 0) -> bool:
	if depth>20: return false
	if value==null or value is bool: return true
	if value is String: return value.length()<=5000
	if value is int or value is float: return is_finite(float(value))
	if value is Array:
		if value.size()>4096: return false
		for item: Variant in value:
			if not _json(item,depth+1): return false
		return true
	if value is Dictionary:
		if value.size()>4096: return false
		for key: Variant in value:
			if not key is String or key.length()>300 or not _json(value[key],depth+1): return false
		return true
	return false

static func validate(recipe: Dictionary) -> Dictionary:
	if not _json(recipe): return _fail("finite_json_only")
	if recipe.get("schema")!="modular_structure_v1" or not _id(recipe.get("source_id")) or not _id(recipe.get("profile_id")): return _fail("recipe_identity")
	if not _text(recipe.get("type")) or not _text(recipe.get("skin_id")): return _fail("recipe_type_or_skin")
	if not _integer(recipe.get("storeys")) or int(recipe.storeys) not in [2,3] or not _positive(recipe.get("storey_height")) or not _vector(recipe.get("dimensions"),2,true): return _fail("recipe_dimensions")
	if not recipe.get("parts") is Array or recipe.parts.is_empty() or recipe.parts.size()>MAX_PARTS: return _fail("part_budget")
	var ids: Dictionary = {}
	var door_ids: Dictionary = {}
	var main_doors := 0
	var foundations := 0
	var panes := 0
	var shapes := 0
	var room_sign_count := 0
	var expected_sign_links: Array[Dictionary] = []
	for row: Variant in recipe.parts:
		if not row is Dictionary or not _id(row.get("id")) or ids.has(row.id): return _fail("part_identity")
		ids[row.id] = true
		var prefix: String = "part:"+row.id+":"
		if not row.get("role") is String or row.role not in ROLES: return _fail(prefix+"role")
		if not _vector(row.get("size"),3,true) or not _vector(row.get("at"),3) or not _vector(row.get("rotation"),3) or not _color(row.get("color")): return _fail(prefix+"geometry_or_color")
		if row.has("door") and not row.door is bool: return _fail(prefix+"door_bool")
		if row.get("door",false):
			if row.role!="EntranceModular" or row.has("interior_door"): return _fail(prefix+"main_door_role")
			main_doors += 1
		elif row.role=="EntranceModular": return _fail(prefix+"entrance_requires_main_door")
		if row.role=="FoundationChunk": foundations += 1
		if row.has("window"):
			var window: Variant = row.window
			if not window is Dictionary or not _vector(window.get("center"),3) or not _positive(window.get("width")) or not _positive(window.get("height")): return _fail(prefix+"window_fields")
			if absf(float(window.center[2]))>.000001 or absf(float(window.center[0]))+float(window.width)*.5>=float(row.size[0])*.5 or absf(float(window.center[1]))+float(window.height)*.5>=float(row.size[1])*.5: return _fail(prefix+"window_outside_shell")
			if float(window.width)<.05 or float(window.height)<.05 or float(window.width)>8.0 or float(window.height)>8.0: return _fail(prefix+"native_pane_dimensions")
			panes += 1; shapes += 11
		else: shapes += 1
		if row.has("interior_door"):
			var door: Variant = row.interior_door
			if not door is Dictionary or not _id(door.get("id")) or door.id=="main" or door_ids.has(door.id) or not _text(door.get("room_id")): return _fail(prefix+"interior_door_identity")
			if row.role!="InteriorDoor" or row.has("window"): return _fail(prefix+"interior_door_adapter_requires_solid_leaf")
			door_ids[door.id] = true
		elif row.role=="InteriorDoor": return _fail(prefix+"interior_door_missing_controller")
		if not row.get("details",[]) is Array or row.get("details",[]).size()>128: return _fail(prefix+"detail_budget")
		for detail: Variant in row.get("details",[]):
			if not detail is Dictionary or not _vector(detail.get("size"),3,true) or not _vector(detail.get("at"),3) or not _vector(detail.get("rotation"),3) or not _color(detail.get("color")): return _fail(prefix+"detail_fields")
			if detail.has("physical") and not detail.physical is bool: return _fail(prefix+"detail_physical_bool")
			if detail.get("physical",false): shapes += 1
		if row.has("text") and (not _text(row.text) or not _color(row.get("text_color","ead5a4"))): return _fail(prefix+"sign_text_or_color")
		if not row.get("room_signs",[]) is Array or row.get("room_signs",[]).size()>4: return _fail(prefix+"room_sign_budget")
		for sign: Variant in row.get("room_signs",[]):
			if not sign is Dictionary or not _id(sign.get("name_ru")) or not _id(sign.get("door_id")) or not _text(sign.get("room_id")) or not _integer(sign.get("side")) or int(sign.side) not in [-1,1]: return _fail(prefix+"room_sign_fields")
			if row.role!="InteriorDoorLintel" or float(row.size[0])<=.061: return _fail(prefix+"room_sign_requires_real_lintel")
			expected_sign_links.append(sign); room_sign_count += 1
	if main_doors!=1 or foundations==0 or panes>256: return _fail("main_door_foundation_or_pane_count")
	for sign: Dictionary in expected_sign_links:
		if not door_ids.has(sign.door_id): return _fail("room_sign_orphan_door")
	for field: String in ["foundation","external_soil_required"]:
		var body: Variant = recipe.get(field)
		if not body is Dictionary or not _vector(body.get("size"),3,true) or not _vector(body.get("at"),3): return _fail(field+"_fields")
	if recipe.external_soil_required.get("ownership")!="terrain_host_not_building": return _fail("external_soil_ownership")
	var bounds: Variant = recipe.get("bounds")
	if not bounds is Dictionary or not _vector(bounds.get("minimum"),3) or not _vector(bounds.get("maximum"),3): return _fail("bounds_fields")
	for axis in range(3):
		if float(bounds.maximum[axis])<=float(bounds.minimum[axis]): return _fail("bounds_order")
	var cuts: Variant = recipe.get("terrain_cutouts")
	if not cuts is Array or cuts.size()>8: return _fail("terrain_cutouts_array")
	var cut_ids: Dictionary = {}
	for cut: Variant in cuts:
		if not cut is Dictionary or not _id(cut.get("id")) or cut_ids.has(cut.id) or not _rect(cut.get("rect")) or not _number(cut.get("bottom")) or not _number(cut.get("top")) or float(cut.top)<=float(cut.bottom): return _fail("terrain_cutout_fields")
		if cut.get("requires_native_clearance")!=true: return _fail("terrain_cutout_clearance_required")
		cut_ids[cut.id] = true
	if not recipe.get("rooms") is Array or not recipe.get("room_graph",{}) is Dictionary: return _fail("room_metadata")
	for room: Variant in recipe.rooms:
		if not room is Dictionary or not _id(room.get("id")) or not _integer(room.get("level")): return _fail("room_identity")
	if not recipe.get("stair_routes") is Array or recipe.stair_routes.size()>3: return _fail("stair_routes_array")
	for route: Variant in recipe.stair_routes:
		if not route is Dictionary or not _integer(route.get("level_from")) or not _integer(route.get("level_to")) or not _positive(route.get("width")) or not _positive(route.get("riser")) or not _integer(route.get("step_count")): return _fail("stair_route_fields")
		if not route.get("points") is Array or route.points.size()!=4: return _fail("stair_route_waypoints")
		for point: Variant in route.points:
			if not _vector(point,3): return _fail("stair_route_point")
	if not recipe.get("floor_openings") is Array: return _fail("floor_openings_array")
	for opening: Variant in recipe.floor_openings:
		if not opening is Dictionary or not _integer(opening.get("level")): return _fail("floor_opening_identity")
		if opening.get("kind")=="stairs":
			if not _rect(opening.get("rect")) or not _number(opening.get("y")) or not _positive(opening.get("clear_height")): return _fail("stair_opening_fields")
		elif opening.get("kind")=="door":
			if opening.get("axis") not in ["x","z"] or not _number(opening.get("at")) or not _number(opening.get("from")) or not _number(opening.get("to")) or float(opening.to)<=float(opening.from) or not _number(opening.get("bottom")) or not _positive(opening.get("height")): return _fail("door_opening_fields")
		else: return _fail("floor_opening_kind")
	var palette: Variant = recipe.get("palette",{})
	if not palette is Dictionary: return _fail("palette_dictionary")
	for value: Variant in palette.values():
		if not _color(value): return _fail("palette_color")
	var properties: Variant = recipe.get("material_properties",{})
	if not properties is Dictionary: return _fail("material_properties_dictionary")
	for material: Variant in properties.values():
		if not material is Dictionary: return _fail("material_dictionary")
		if material.has("base_color") and not _color(material.base_color): return _fail("material_base_color")
		for field: String in ["roughness","metallic"]:
			if material.has(field) and (not _number(material[field]) or float(material[field])<0.0 or float(material[field])>1.0): return _fail("material_"+field)
	var budget: Variant = recipe.get("budget")
	if not budget is Dictionary: return _fail("budget_dictionary")
	var exact: Dictionary = {"rigid_bodies":recipe.parts.size(),"hidden_fragment_bodies":0,"static_bodies":panes,"collision_shapes":shapes+panes,"interior_door_leaves":door_ids.size(),"glass_panes":panes,"glass_helpers":1,"room_sign_labels":room_sign_count}
	for field: String in exact:
		if not _integer(budget.get(field)) or int(budget[field])!=exact[field]: return _fail("budget_"+field)
	if not recipe.get("destructive_coverage") is Dictionary: return _fail("destructive_coverage_dictionary")
	return {"ok":true,"parts":recipe.parts.size(),"panes":panes,"interior_doors":door_ids.size(),"shapes":shapes+panes,"room_signs":room_sign_count,"native_engine_admission":false}
