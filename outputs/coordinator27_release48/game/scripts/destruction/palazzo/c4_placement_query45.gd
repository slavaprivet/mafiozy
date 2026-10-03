extends RefCounted
## Two native rays only. The camera selects; the actor confirms the SAME contact.
## Never search behind an unsupported first hit or invent a surface normal.
const MASK := 0xffffffff # All physical-body layers; areas remain ignored.
const REACH_M := 2.5 # Preserve accepted43 local placement radius; no hand-contact claim.
const HORIZONTAL_REACH_M := 2.0 # Ordinary camera can target nearby ground comfortably.
const CONTACT_SLOP_M := 0.025
const CONTACT_INSET_M := 0.01
const MAX_COUNT := 2147483647
const REASONS := ["ready", "inactive", "camera_missing", "invalid_query", "no_surface", "unsupported_surface", "invalid_contact", "camera_inside_surface", "too_far", "actor_los_empty", "actor_los_blocked", "actor_inside_surface", "different_surface_contact", "accepted"]
var _counts: Dictionary = {}
var _last: Dictionary = {"reason":"ready", "ray_count":0}
var _queries := 0

func _init() -> void:
	for reason: String in REASONS: _counts[reason] = 0

func reject(reason: String) -> Dictionary:
	return _finish(reason, 0)

func _finish(reason: String, rays: int, body: Variant = null, distance_m: float = -1.0, reticle_error_m: float = -1.0) -> Dictionary:
	# Fixed keys and scalar values: no history, Node references or per-frame logs.
	if not _counts.has(reason): reason = "invalid_query"
	_counts[reason] = mini(MAX_COUNT, int(_counts[reason]) + 1)
	_queries = mini(MAX_COUNT, _queries + 1)
	_last = {"reason":reason, "ray_count":rays, "collider_id":body.get_instance_id() if is_instance_valid(body) else 0, "distance_m":distance_m, "reticle_error_m":reticle_error_m}
	return {}

func snapshot() -> Dictionary:
	return {"queries":_queries, "last":_last.duplicate(), "counts":_counts.duplicate(), "maximum_rays_per_query":2, "maximum_history_entries":0, "reach_m":REACH_M, "horizontal_reach_m":HORIZONTAL_REACH_M}

func query(space: PhysicsDirectSpaceState3D, camera_from: Vector3, camera_direction: Vector3, actor_from: Vector3, excluded: Array[RID], owner_for: Callable) -> Dictionary:
	if space == null or not owner_for.is_valid() or not camera_from.is_finite() or not camera_direction.is_finite() or not actor_from.is_finite() or camera_direction.length_squared() < 0.99 or camera_direction.length_squared() > 1.01:
		return _finish("invalid_query", 0)
	var direction: Vector3 = camera_direction.normalized()
	var camera_query := PhysicsRayQueryParameters3D.create(camera_from, camera_from + direction * 30.0, MASK, excluded)
	camera_query.hit_from_inside = true
	var aimed: Dictionary = space.intersect_ray(camera_query)
	if aimed.is_empty(): return _finish("no_surface", 1)
	var body: Variant = aimed.get("collider")
	var owner: Variant = owner_for.call(body)
	if not owner is Node3D or not is_instance_valid(owner): return _finish("unsupported_surface", 1, body)
	if not aimed.get("position") is Vector3 or not aimed.get("normal") is Vector3: return _finish("invalid_contact", 1, body)
	var point: Vector3 = aimed.position
	var normal: Vector3 = aimed.normal
	if not point.is_finite() or not normal.is_finite(): return _finish("invalid_contact", 1, body)
	# Godot reports a zero normal for a ray beginning inside a collider. Such a
	# hit cannot prove a visible face. Report it; do not skip the enclosing body.
	if normal.length_squared() < 0.000001: return _finish("camera_inside_surface", 1, body)
	if normal.length_squared() < 0.9: return _finish("invalid_contact", 1, body)
	normal = normal.normalized()
	var distance_m: float = actor_from.distance_to(point)
	if distance_m > REACH_M or Vector2(point.x - actor_from.x, point.z - actor_from.z).length() > HORIZONTAL_REACH_M:
		return _finish("too_far", 1, body, distance_m)
	# End just INSIDE the camera-selected face so a successful actor LOS must
	# return actual collision evidence. The former outside endpoint accepted an
	# empty query and any early hit belonging to the same multi-shape body.
	var actor_query := PhysicsRayQueryParameters3D.create(actor_from, point - normal * CONTACT_INSET_M, MASK, excluded)
	actor_query.hit_from_inside = true
	var reached: Dictionary = space.intersect_ray(actor_query)
	if reached.is_empty(): return _finish("actor_los_empty", 2, body, distance_m)
	if reached.get("collider") != body: return _finish("actor_los_blocked", 2, body, distance_m)
	if not reached.get("position") is Vector3 or not reached.get("normal") is Vector3: return _finish("invalid_contact", 2, body, distance_m)
	var contact: Vector3 = reached.position
	var actor_normal: Vector3 = reached.normal
	if not contact.is_finite() or not actor_normal.is_finite(): return _finish("invalid_contact", 2, body, distance_m)
	if actor_normal.length_squared() < 0.000001: return _finish("actor_inside_surface", 2, body, distance_m)
	var along: float = (contact - camera_from).dot(direction)
	var reticle_error_m: float = (contact - camera_from - direction * along).length()
	if actor_normal.length_squared() < 0.9 or actor_normal.normalized().dot(normal) < 0.98 or contact.distance_to(point) > CONTACT_SLOP_M or reticle_error_m > CONTACT_SLOP_M or along < 0.0 or (actor_from - contact).dot(actor_normal) <= 0.0:
		return _finish("different_surface_contact", 2, body, distance_m, reticle_error_m)
	_finish("accepted", 2, body, distance_m, reticle_error_m)
	# Preserve the exact camera contact for the aim drift/lifetime contract. The
	# nearby ray is corroboration, not permission to move to a different surface.
	return {"body":body, "owner":owner, "point":point, "normal":normal, "actor_contact":contact, "actor_contact_normal":actor_normal.normalized(), "ray_count":2,"shape_index":int(aimed.get("shape",-1))}
