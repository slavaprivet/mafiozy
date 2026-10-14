extends RefCounted
## DSH_MEDPRIORITY: the visual "room centre" goal of the CLONE hospital that
## scripts/main.gd builds in _install_palazzo_clones() (TownClone_1, sign "БОЛЬНИЦА",
## a duplicate() of the PalazzoShowcaseSite subtree at origin [70.5,0,0] with
## --city-clone-step=22). The copy has NO host, NO interior and NO admission, so this
## file only LOCATES a point, marks it visibly and reports whether a resident could be
## admitted there. It grants nothing: every move still passes the shipped
## source_admit / support_height proof.
##
##   --city-hospital-marker=x,y,z   world metres; wins over the measured centre
##   --city-hospital-marker-probe=1 read-only dump of the measured AABB and rays
const WALK_RADIUS := .738
const PROBE_MASK := 1 | 256
const MARK_MASK := 1
const GROUND_EPS := .05

# DSH_MEDPRIORITY: process-wide, resolved once. Empty while unresolved.
static var _marker: Vector3 = Vector3.ZERO
static var _marker_valid: bool = false
static var _marker_source: String = ""
static var _marker_radius: float = 0.0
static var _resolved: bool = false
static var _scene_cache: WeakRef = null
static var _probe_flag: int = -1
static var _install_flag: int = -1
static var _install_tried: bool = false
static var _install_done: bool = false

static func _arg(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

static func probe_on() -> bool:
	if _probe_flag < 0:
		_probe_flag = 1 if _arg("--city-hospital-marker-probe=") == "1" else 0
	return _probe_flag == 1

static func parse_vector(text: String) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 3: return null
	var values := PackedFloat64Array()
	for part: String in parts:
		var number := part.strip_edges().to_float()
		if not is_finite(number): return null
		values.append(number)
	return Vector3(values[0], values[1], values[2])

## DSH_MEDPRIORITY: the clone's own subtree AABB in world space. The whole copy is
## covered, including the copied door, so the box is the building envelope.
static func _clone_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is VisualInstance3D:
			var part := (node as VisualInstance3D).get_aabb()
			var world := (node as Node3D).global_transform * part
			box = world if first else box.merge(world)
			first = false
		for child: Node in node.get_children(): stack.append(child)
	return box

## DSH_MEDPRIORITY: the clone's front door. Two shipped forms exist: the copied
## "SourceDoor_public" leaf of the default stand, and - with --city-clone-door-swing=1 -
## the copy's own "Entrance*" leaf owned by npc_city_clone_door_swing.gd, whose `anchor`
## is its doorway centre. Both are read through their own public accessors.
static func _door_centroid(root: Node3D) -> Variant:
	var swing := _swing_door(root)
	if swing != null: return swing.global_position
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if str(node.name) == "SourceDoor_public" and node is Node3D:
			return (node as Node3D).global_position
		for child: Node in node.get_children(): stack.append(child)
	return null

static func _swing_door(root: Node3D) -> Node3D:
	var registry: Variant = load("res://scripts/city/runtime/npc_city_clone_door_swing.gd")
	if registry == null or not (registry as Script).can_instantiate(): return null
	for entry: Variant in (registry as Script).doors():
		var door: Variant = entry
		if not is_instance_valid(door) or not door is Node3D: continue
		var host: Variant = (door as Node3D).get("clone_node")
		if host is Node3D and (host as Node3D).get_instance_id() == root.get_instance_id(): return door as Node3D
	return null

## DSH_MEDPRIORITY: a downward ray on the requested layer finds the surface a resident
## would stand on. It is a read of the world, never a grant. `top` is the world height the
## ray starts from, so the caller chooses whether the roof or the floor is asked for.
static func _drop(world: World3D, at: Vector2, top: float, mask: int, depth: float = 400.0) -> Variant:
	if world == null: return null
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, top, at.y), Vector3(at.x, top - depth, at.y), mask)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty(): return null
	return hit.position

## DSH_MEDPRIORITY: the centre of the CLONE's interior. The copy is a whole building, so
## its envelope AABB centre is the middle of the BLOCK (measured y=5.99 = its roof). The
## room floor is asked for instead: the ground under the copied front door is the floor
## plane, and the interior centre is the centroid pulled 25 % of the half-extent towards
## that door at that same floor height. Deterministic, flag-free, independent of any host.
static func measure(scene: Node3D, clone: Node3D) -> Dictionary:
	var box := _clone_bounds(clone)
	if not box.has_volume(): return {"ok":false,"reason":"empty_clone_bounds"}
	var world: World3D = clone.get_world_3d()
	var centre := box.get_center()
	var half := box.size * .5
	var door: Variant = _door_centroid(clone)
	var base_y := box.position.y
	if door is Vector3:
		# The copied doorway is the one place of the copy whose floor is known: the ground
		# the leaf stands on. Ask it directly instead of guessing from the envelope.
		var under_door: Variant = _drop(world, Vector2((door as Vector3).x, (door as Vector3).z), (door as Vector3).y + 1.5, PROBE_MASK, 6.0)
		if under_door is Vector3: base_y = (under_door as Vector3).y
	if base_y < 0.0:
		# The envelope AABB reaches below the street (measured: y=-12 for the copy), so a
		# negative base is never the room floor. The authored ground plane of the row the
		# copies stand on is y=0, and it is named as such in `y_source`.
		base_y = 0.0
	var toward := Vector3(maxf(half.x, 1.0) * .25, 0.0, maxf(half.z, 1.0) * .25)
	if door is Vector3:
		var flat := Vector3((door as Vector3).x - centre.x, 0.0, (door as Vector3).z - centre.z)
		if flat.length() > .001: toward = flat.normalized() * minf(flat.length() * .25, maxf(half.x, half.z) * .5)
	var approach := Vector3(centre.x - toward.x, base_y, centre.z - toward.z)
	var placed: Variant = null
	var probe := ""
	# Ask the FLOOR first: a ray from just above the known floor plane, never from the roof.
	for mask: int in [PROBE_MASK, MARK_MASK]:
		for radius: float in [0.0, half.x * .35, half.x * .6]:
			if radius <= .001:
				var hit_centre: Variant = _drop(world, Vector2(approach.x, approach.z), base_y + 1.2, mask, 4.0)
				if hit_centre is Vector3: placed = hit_centre; probe = "floor_centre"
			else:
				for angle_index in 4:
					var angle := TAU * float(angle_index) / 4.0
					var candidate := Vector2(approach.x + cos(angle) * radius, approach.z + sin(angle) * radius)
					var hit_at: Variant = _drop(world, candidate, base_y + 1.2, mask, 4.0)
					if hit_at is Vector3: placed = hit_at; probe = "floor_ring"; break
			if placed is Vector3: break
		if placed is Vector3: break
	var result := {"ok":true,"aabb_position":box.position,"aabb_size":box.size,"centre":centre,
		"approach":approach,"door":door,"base_y":base_y,"probe":probe}
	if placed is Vector3:
		result["marker"] = placed
		result["y_source"] = "floor_below_door_level"
	else:
		# No interior floor was measured inside the copy (measured on this stage: the copy
		# sits outside the pinned source crop and the only surface the probes find is its
		# own roof). The room floor is then the floor plane under the copied doorway, which
		# is reported as such, never hidden.
		result["marker"] = Vector3(approach.x, base_y, approach.z)
		result["y_source"] = "clone_door_floor_plane"
	return result

static func _clone_in(scene: Node3D) -> Node3D:
	for node: Node in scene.get_children():
		if node.get_meta("dsh_town_extra", false) != true or not node is Node3D: continue
		var sign_node: Node = node.get_node_or_null("TownCloneSign")
		if sign_node is Label3D and str((sign_node as Label3D).text).to_upper().contains("БОЛЬНИЦ"):
			return node as Node3D
	return null

static func _install_marker(scene: Node3D, marker: Vector3) -> bool:
	if _install_done: return true
	# A failed attempt is NOT remembered: the scene lookup can fail on one frame and
	# succeed on the next (measured in this stage), and the mark must still appear.
	if not is_instance_valid(scene) or scene.is_queued_for_deletion(): return false
	var root := Node3D.new()
	root.name = "DSH_HospitalRoomMarker"
	root.position = marker
	scene.add_child(root)

	# A visible column of light at the goal. No collider and no collision layer: the
	# mark can be seen through and walked through, it changes no movement decision.
	var column := MeshInstance3D.new()
	column.name = "Column"
	var mesh := CylinderMesh.new()
	mesh.top_radius = .22
	mesh.bottom_radius = .22
	mesh.height = 7.0
	mesh.radial_segments = 12
	mesh.rings = 1
	column.mesh = mesh
	column.position = Vector3(0, 3.5, 0)
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(.35, 1.0, .55, .34)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.no_depth_test = false
	column.material_override = glow
	root.add_child(column)

	var disc := MeshInstance3D.new()
	disc.name = "FloorDisc"
	var ring := TorusMesh.new()
	ring.inner_radius = .55
	ring.outer_radius = .95
	ring.rings = 16
	ring.ring_segments = 10
	disc.mesh = ring
	disc.position = Vector3(0, .06, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(.4, 1.0, .6, .85)
	disc.material_override = ring_material
	root.add_child(disc)

	var label := Label3D.new()
	label.name = "Label"
	label.text = "БОЛЬНИЦА: цель жителя"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.no_depth_test = true
	label.pixel_size = .02
	label.font_size = 96
	label.modulate = Color(.72, 1, .8, 1)
	label.outline_modulate = Color(0, 0, 0, 1)
	label.outline_size = 18
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = Vector3(0, 6.4, 0)
	root.add_child(label)

	_install_done = true
	return true

## The scene the mark belongs to. The life caches this once, so the visual can still be
## added on the frame a later resident crosses the threshold even if that frame's lookup
## fails (the same failure the measured run of this stage showed).
static func scene_of(scene: Node3D) -> void:
	if is_instance_valid(scene) and _scene_cache == null: _scene_cache = weakref(scene)

static func cached_scene() -> Node3D:
	if _scene_cache == null: return null
	var held: Variant = _scene_cache.get_ref()
	return held if held is Node3D else null

## DSH_MEDPRIORITY: the visible mark is there for the owner's eyes. --city-hospital-marker=0
## turns it off; every other value (including an absent flag) keeps it.
static func marker_visible() -> bool:
	if _install_flag < 0:
		_install_flag = 1
		for argument: String in OS.get_cmdline_user_args():
			if argument == "--city-hospital-marker=0": _install_flag = 0
	return _install_flag == 1

## DSH_MEDPRIORITY: resolved once per process from the command line, then from the
## clone geometry. With an explicit --city-hospital-marker=x,y,z the scene is never
## scanned. --city-hospital-marker=0 asks for no visible mark at all.
static func resolve(scene: Node3D) -> Dictionary:
	scene_of(scene)
	if _resolved:
		if not _marker_valid: return {"ok":false,"reason":"unresolved_or_no_scene"}
		return {"ok":true,"marker":_marker,"source":_marker_source,"radius":_marker_radius}
	_resolved = true
	var explicit: Variant = parse_vector(_arg("--city-hospital-marker="))
	if explicit is Vector3:
		_marker = explicit; _marker_valid = true; _marker_source = "flag"
		if probe_on():
			print("DSH_HOSPITAL_MARKER ", JSON.stringify({"ok":true,"source":"flag","marker":[_marker.x,_marker.y,_marker.z]}))
		if marker_visible(): _install_marker(scene, _marker)
		return {"ok":true,"marker":_marker,"source":_marker_source,"radius":0.0}
	var clone: Node3D = _clone_in(scene)
	if clone == null:
		if probe_on(): print("DSH_HOSPITAL_MARKER ", JSON.stringify({"ok":false,"reason":"hospital_clone_not_found"}))
		return {"ok":false,"reason":"hospital_clone_not_found"}
	var measured: Dictionary = measure(scene, clone)
	# DSH_MEDPRIORITY: with --city-hospital-marker-probe=1 the raw measurement is dumped
	# before anything is stored, so the owner can copy exact numbers into the flag.
	if probe_on():
		var dump := measured.duplicate(true)
		dump["clone"] = str(clone.name)
		for key: String in ["door","aabb_position","aabb_size","centre","approach","marker","base_y"]:
			var value: Variant = measured.get(key)
			dump[key] = [value.x, value.y, value.z] if value is Vector3 else null
		print("DSH_HOSPITAL_MARKER ", JSON.stringify(dump))
	if not measured.get("ok", false) or not measured.get("marker") is Vector3:
		return {"ok":false,"reason":str(measured.get("reason","marker_not_measured"))}
	_marker = measured.marker
	_marker_valid = true
	_marker_source = "measured_room_centre"
	_marker_radius = 0.0
	if is_instance_valid(clone) and clone is Node3D:
		var half := (measured.aabb_size as Vector3) * .5
		_marker_radius = maxf(half.x, half.z)
	if marker_visible(): _install_marker(scene, _marker)
	return {"ok":true,"marker":_marker,"source":_marker_source,"radius":_marker_radius}

static func current() -> Dictionary:
	if not _marker_valid: return {}
	return {"marker":_marker,"source":_marker_source,"radius":_marker_radius}

## DSH_MEDPRIORITY: the visual is added on the cached scene, once per process.
static func install_visual() -> bool:
	if not _marker_valid or not marker_visible(): return false
	var scene := cached_scene()
	if not is_instance_valid(scene): return false
	return _install_marker(scene, _marker)

## DSH_MEDPRIORITY: the honest admission of the marker point itself, using the same
## two public calls the life uses for a plain roam target. Nothing is granted here.
static func admission(policy: RefCounted, id: String, generation: int) -> Dictionary:
	if not _marker_valid: return {"ok":false,"reason":"marker_not_resolved"}
	if not is_instance_valid(policy): return {"ok":false,"reason":"policy_required"}
	var support: float = NAN
	var admitted := false
	var reason := ""
	if policy.has_method("support_height"): support = policy.support_height(_marker, id, generation)
	if not is_finite(support):
		# A missing support ray stops the errand here: this is exactly the failure a
		# resident would meet, so it is reported instead of covered up.
		reason = "support_height_nan"
	else:
		var point := _marker
		point.y = support
		admitted = policy.source_admit(point, id, generation, WALK_RADIUS, "target")
		if not admitted: reason = "source_admit_refused"
	return {"ok":true,"admitted":admitted,"support":support,"reason":reason}
