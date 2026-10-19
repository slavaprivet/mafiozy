extends RefCounted
## Shared inventory, one weak centre-seat claim; live physics remains per use.
const Registry = preload("res://scripts/npc_ambient/ambient_bench_registry29.gd")
var _registry: Node

func configure(scene: Node3D) -> void:
	if is_instance_valid(scene): _registry = Registry.for_scene(scene)

func _current(row: Dictionary) -> bool:
	return is_instance_valid(_registry) and _registry.current(row)

func reserve_nearest(body: CharacterBody3D, route: RefCounted, owner: RefCounted, action_serial: int, maximum_distance: float = 8.0) -> Dictionary:
	if not is_instance_valid(_registry): return {}
	var best := {}
	var best_distance := maximum_distance
	for row: Dictionary in _registry.rows():
		if not _current(row) or not _registry.available(int(row.bench_id)): continue
		var bench: Node3D = row.bench.get_ref()
		# Pose and physical approach remain at the original central seat.
		var approach: Vector3 = bench.to_global(Vector3(0,0,.72))
		var distance: float = Vector2(approach.x-body.global_position.x,approach.z-body.global_position.z).length()
		if distance >= best_distance: continue
		var floor: Variant = route.floor_at(approach,bench.global_position.y)
		if not floor is Vector3 or not route.standing(floor): continue
		var seat: Vector3 = bench.to_global(Vector3(0,.48,.18))
		var height: float = seat.y-floor.y
		if height < .35 or height > .65: continue
		var candidate: Dictionary = row.duplicate(); candidate["approach"] = floor; candidate["seat"] = seat
		candidate["face"] = bench.global_basis.z.normalized(); candidate["right"] = bench.global_basis.x.normalized()
		candidate["bench_path"] = str(bench.get_path()); candidate["support_path"] = str(row.support.get_ref().get_path())
		if not supported(candidate,body): continue
		best = candidate; best_distance = distance
	if best.is_empty(): return {}
	# Selection and acquisition are synchronous on the main thread; no await gap.
	var lease: Dictionary = _registry.claim(best,owner,body,action_serial)
	if lease.is_empty(): return {}
	best["slot"] = lease
	return best

func renew(row: Dictionary, owner: RefCounted, body: CharacterBody3D) -> bool:
	return is_instance_valid(_registry) and _registry.renew(row.get("slot",{}),owner,body)

func occupy(row: Dictionary, owner: RefCounted, body: CharacterBody3D) -> bool:
	return is_instance_valid(_registry) and not row.is_empty() and _registry.occupy(row.get("slot",{}),owner,body,row.approach)

func matches(row: Dictionary, owner: RefCounted, body: CharacterBody3D) -> bool:
	# Safe in the host busy section: weak identity/serial check only, no target_current.
	return is_instance_valid(_registry) and _registry.matches(row.get("slot",{}),owner,body)

func release(row: Dictionary, owner: RefCounted, body: CharacterBody3D) -> void:
	if is_instance_valid(_registry): _registry.release(row.get("slot",{}),owner,body)

func supported(row: Dictionary, body: CharacterBody3D) -> bool:
	if row.is_empty() or not _current(row): return false
	var support: StaticBody3D = row.support.get_ref()
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	for offset: float in [-.18,0.0,.18]:
		var at: Vector3 = row.seat+row.right*offset
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.12,at-Vector3.UP*.12,body.collision_mask,[body.get_rid()])
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or hit.get("collider") != support or Vector3(hit.normal).y < .98 or absf(float(hit.position.y)-at.y) > .015: return false
	return true

func count() -> int:
	return int(_registry.snapshot().benches) if is_instance_valid(_registry) else 0

func snapshot() -> Dictionary:
	return _registry.snapshot() if is_instance_valid(_registry) else {}
