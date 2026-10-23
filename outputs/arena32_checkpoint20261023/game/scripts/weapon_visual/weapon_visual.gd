extends Node3D
## Original source geometry, source +Z and unscaled rig units.
## The host owns attachment, body/hand IK, aim, events, ammo and damage.
var _slots_bound := false
var _slots: Array[Node3D] = []

func profile() -> Dictionary:
	return get_meta("weapon_profile", {}).duplicate(true)

func local_bounds() -> AABB:
	# Exact native REST vertex bounds in unscaled source units (cargo stays at rest).
	# The original factory's conservative transformed-mesh AABB is kept separately.
	var bounds: Variant = get_meta("weapon_profile", {}).get("bounds_native")
	if not bounds is Dictionary: return AABB()
	var low := Vector3(bounds.min[0], bounds.min[1], bounds.min[2])
	var high := Vector3(bounds.max[0], bounds.max[1], bounds.max[2])
	return AABB(low, high-low)

func geometry_nodes() -> Array[MeshInstance3D]:
	# Borrowed rendering nodes for host picking; never mutate shared Mesh/Material.
	var result: Array[MeshInstance3D] = []
	for child: Node in get_children():
		if child is MeshInstance3D: result.append(child)
	return result

static func _smooth(value: float, low: float, high: float) -> float:
	var t := clampf((value - low) / (high - low), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func sample_reload(progress: float) -> Dictionary:
	var p := clampf(progress if is_finite(progress) else 0.0, 0.0, 1.0)
	return {"progress": p, "active": p > 0.0 and p < 1.0,
		"lower": _smooth(p, 0.0, 0.15) * (1.0 - _smooth(p, 0.84, 1.0)),
		"grab": _smooth(p, 0.0, 0.18) * (1.0 - _smooth(p, 0.79, 0.96)),
		"pull": _smooth(p, 0.20, 0.40) * (1.0 - _smooth(p, 0.60, 0.78)),
		"bolt": _smooth(p, 0.79, 0.83) * (1.0 - _smooth(p, 0.85, 0.89))}

func apply_reload(progress: float, prone: float = 0.0) -> Dictionary:
	if not is_finite(prone) or prone < 0.0 or prone > 1.0:
		return {"ok": false, "error": "prone"}
	var sample := sample_reload(progress)
	if not _slots_bound:
		for child: Node in get_children():
			if child is Node3D and child.has_meta("weapon_animation_slot"): _slots.append(child)
		_slots_bound = true
	for node: Node3D in _slots:
		var rest: Transform3D = node.get_meta("weapon_rest")
		node.transform = rest
		# Source restores rest first, then ignores non-finite progress.
		if not is_finite(progress):
			continue
		if node.get_meta("weapon_animation_slot") == "magazine":
			node.position.y -= sample.pull * 0.62 * (1.0 - prone)
			node.position.x -= sample.pull * 0.25 * prone
		else:
			node.position.z -= sample.bolt * 0.12
	return {"ok": true, "sample": sample}

func anchor_world(anchor: StringName) -> Dictionary:
	var node := get_node_or_null(NodePath(String(anchor))) as Node3D
	if node == null or not node.has_meta("weapon_anchor") or not is_inside_tree():
		return {"ok": false, "error": "anchor_missing_or_detached"}
	return {"ok": true, "position": node.global_position} if node.global_position.is_finite() else {"ok": false, "error": "anchor_nonfinite"}

func shot_transform() -> Dictionary:
	var muzzle := anchor_world(&"Muzzle")
	if not muzzle.ok:
		return muzzle
	var direction := global_basis * Vector3.BACK
	if not direction.is_finite() or direction.length_squared() < 1.0e-12:
		return {"ok": false, "error": "basis"}
	var ejection := anchor_world(&"EjectionPort")
	return {"ok": true, "origin": muzzle.position,
		"ejection_origin": ejection.position if ejection.ok else muzzle.position,
		"direction": direction.normalized()}
