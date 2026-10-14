extends RefCounted
## DSH_CATALOG: THE SINGLE PLACE WHERE A DESTINATION IS ADDED.
##
## Owner's rule (MAFIOZY_NEXT_BEHAVIOR.md §4): a new place is ONE record -
## condition -> goal -> priority - and no other file has to change. Every record below is
## declared as data, never as a branch in the life:
##
##   id        the task/place name; it is also the goal kind the life starts
##   priority  lower wins; the queue is built in this order, so health always outranks food
##   condition what makes this place wanted (see `_matches`)
##   mode      "direct" = the stand's own walk to a point (see npc_simple_hospital.gd),
##             "visit"  = one of the shipped physical visits created by the visit factory
##   target    for "direct": the source key of the point (clone room centre, ...)
##   flag      the command-line flag that arms this record; absent flag = the record is inert,
##             so a run without flags behaves exactly as the shipped life
##   enabled   per-record data switch for records that are already always-on (default true)
##
## Conditions are data expressions, not callables, so a record stays one line:
##   {"hp_below_max_fraction": .5}   hp < max_hp * fraction   (STRICTLY less: equals never)
##   {"energy_below": .2}            energy < fraction * 100
##   {"cash_below": 6}               cash < value
##   {"bank_at_least": 15}           bank >= value
const RECORDS: Array = [
	{
		"id": "hospital", "priority": 0, "mode": "direct", "target": "clone_room_centre",
		"condition": {"hp_below_max_fraction": .5},
		"flag": "--city-medical-threshold", "enabled": true,
		"note": "owner's step 3: below half of its own bar the resident takes the hospital first",
	},
	{
		"id": "restaurant", "priority": 1, "mode": "direct", "target": "clone_restaurant_centre",
		"condition": {"energy_below": .2},
		"flag": "--city-energy-drain-per-m", "enabled": true,
		"note": "energy is only a goal trigger: it never slows or stops the walk",
	},
	{
		"id": "bank", "priority": 2, "mode": "visit", "target": "",
		"condition": {"cash_below": 6, "bank_at_least": 15},
		"flag": "--city-needs", "enabled": false,
		"note": "declared, not armed: the shipped life already banks; arming this moves it here",
	},
]

# DSH_CATALOG: one process-wide parse of the command line, shared by every life.
static var _flags: Dictionary = {}
static var _flags_parsed: bool = false

static func _flag_on(name: String) -> bool:
	if name.is_empty(): return true
	if not _flags_parsed:
		_flags_parsed = true
		for argument: String in OS.get_cmdline_user_args():
			var text: String = argument.trim_prefix("--")
			var key: String = text
			var value: String = "1"
			var cut: int = text.find("=")
			if cut >= 0:
				key = text.substr(0, cut)
				value = text.substr(cut + 1)
			_flags[key] = value
	return _flags.has(name.trim_prefix("--").strip_edges())

## DSH_CATALOG: every armed record whose condition the resident currently meets, in
## priority order. The life only walks this list; it holds no place of its own.
static func order(row: Dictionary, energy: float, energy_on: bool) -> Array:
	var ready: Array = []
	for record: Dictionary in RECORDS:
		if not bool(record.get("enabled", true)): continue
		if not _flag_on(str(record.get("flag", ""))): continue
		if _matches(record.get("condition", {}), row, energy, energy_on): ready.append(record)
	ready.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.priority) < int(b.priority))
	return ready

static func find(id: String) -> Dictionary:
	for record: Dictionary in RECORDS:
		if str(record.get("id", "")) == id: return record
	return {}

static func _matches(condition: Dictionary, row: Dictionary, energy: float, energy_on: bool) -> bool:
	if condition.has("energy_below"):
		if not energy_on: return false
		if energy >= float(condition["energy_below"]) * 100.0: return false
	if condition.has("hp_below_max_fraction"):
		var maximum: float = float(row.get("max_hp", 0))
		if maximum <= 0.0: return false
		# STRICTLY less, by the owner's rule: exactly the threshold never triggers.
		if not (float(row.get("hp", 0)) < maximum * float(condition["hp_below_max_fraction"])): return false
	if condition.has("cash_below"):
		if int(row.get("cash", 0)) >= int(condition["cash_below"]): return false
	if condition.has("bank_at_least"):
		if int(row.get("bank", 0)) < int(condition["bank_at_least"]): return false
	return true

## DSH_CATALOG: the queue the life will work through, for telemetry.
static func ids(records: Array) -> Array:
	var out: Array = []
	for record: Dictionary in records: out.append(str(record.get("id", "")))
	return out

## DSH_CATALOG: the district radius of the owner's rule - "the resident goes to the nearest
## building of his district". Inside this radius the nearest site of the wanted kind wins; if
## nothing of that kind is that close, the nearest one overall is taken and telemetry says
## `within_district=false`, so the choice is never hidden.
const DISTRICT_RADIUS_M := 70.0

## DSH_CATALOG: kind -> [{id, pos}] of every suitable site known in the scene. Scanned once
## per process, so a per-decision choice is a distance loop over a handful of entries.
static var _sites: Dictionary = {}
static var _sites_scanned: bool = false
static var _sites_scene_id: int = 0

## DSH_CATALOG: the site kind of one name/source id. Data, not code: a new place adds its
## keyword here only.
static func kind_of(text: String) -> String:
	var low: String = text.to_lower()
	if low.contains("больниц") or low.contains("hospital"): return "hospital"
	if low.contains("ресторан") or low.contains("restaurant") or low.contains("pizza"): return "restaurant"
	if low.contains("банк") or low.contains("bank"): return "bank"
	if low.contains("магазин") or low.contains("shop") or low.contains("print"): return "shop"
	return ""

## DSH_CATALOG: build "kind -> [positions]" from what the city already owns:
##  * the palazzo copies of the stand (meta `dsh_town_extra` + their `TownCloneSign` label),
##  * every node carrying the city's own `source_id` meta (the sites `_attach_site` adds),
##  * a bounded name fallback for a site that carries neither marker.
static func scan(scene: Node3D, force: bool = false) -> void:
	if not is_instance_valid(scene): return
	if _sites_scanned and not force and _sites_scene_id == scene.get_instance_id(): return
	_sites = {}
	_sites_scanned = true
	_sites_scene_id = scene.get_instance_id()
	var stack: Array[Node] = [scene]
	var visited := 0
	while not stack.is_empty() and visited < 4096:
		var node: Node = stack.pop_back()
		visited += 1
		for child: Node in node.get_children(): stack.append(child)
		if not node is Node3D or node == scene: continue
		var text := ""
		if node.get_meta("dsh_town_extra", false) == true:
			var sign_node: Node = node.get_node_or_null("TownCloneSign")
			if sign_node is Label3D: text = (sign_node as Label3D).text
		if text.is_empty(): text = str(node.get_meta("source_id", ""))
		if text.is_empty(): text = str(node.name)
		var kind := kind_of(text)
		if kind.is_empty(): continue
		var node_3d: Node3D = node as Node3D
		if not node_3d.global_position.is_finite(): continue
		var site_id: String = str(node.get_meta("source_id", ""))
		if site_id.is_empty(): site_id = str(node.name)
		if not _sites.has(kind): _sites[kind] = []
		(_sites[kind] as Array).append({"id": site_id, "pos": node_3d.global_position})

## DSH_CATALOG: the nearest site of `kind` to `from`, by the owner's district rule. The result
## is telemetry-ready and never fabricates a site: with none of that kind in the scene `ok` is
## false and the caller keeps its previous behaviour.
static func nearest(kind: String, from: Vector3, district_m: float = DISTRICT_RADIUS_M) -> Dictionary:
	if kind.is_empty() or not from.is_finite(): return {"ok": false, "reason": "no_kind_or_point"}
	var list: Array = _sites.get(kind, [])
	if list.is_empty(): return {"ok": false, "reason": "no_site_of_kind", "candidates": 0}
	var best: Dictionary = {}
	var best_distance: float = INF
	for entry: Dictionary in list:
		var pos: Vector3 = entry.pos
		var distance: float = Vector2(from.x - pos.x, from.z - pos.z).length()
		if distance < best_distance:
			best_distance = distance
			best = {"ok": true, "site_id": str(entry.id), "site_pos": pos, "site_dist_m": distance,
				"within_district": distance <= district_m, "candidates": list.size(), "kind": kind}
	if best.is_empty(): return {"ok": false, "reason": "no_candidate", "candidates": list.size()}
	return best

static func site_count(kind: String) -> int:
	return (_sites.get(kind, []) as Array).size()

## DSH_CATALOG: the site fields appended to the owner's telemetry lines.
static func site_telemetry(choice: Dictionary) -> String:
	if choice.is_empty() or not bool(choice.get("ok", false)):
		return "site_id=- site_pos=- site_dist_m=- site_reason=" + str(choice.get("reason", "none"))
	var pos: Vector3 = choice.site_pos
	return "site_id=" + str(choice.get("site_id", "-")) \
		+ " site_pos=(%.2f,%.2f,%.2f)" % [pos.x, pos.y, pos.z] \
		+ " site_dist_m=%.1f" % float(choice.get("site_dist_m", -1.0)) \
		+ " site_kind=" + str(choice.get("kind", "-")) \
		+ " site_candidates=" + str(int(choice.get("candidates", 0))) \
		+ " site_in_district=" + str(bool(choice.get("within_district", false)))

