extends RefCounted
## Selects an existing real bench as a walking purpose, without reserving a seat
## while still far away. The ordinary physical driver owns the route and motion.
const Registry = preload("res://scripts/npc_ambient/ambient_bench_registry29.gd")
const Benches = preload("res://scripts/npc_ambient/ambient_benches28.gd")
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
const MAX_DISTANCE := 120.0
var _registry: Node
var _benches: RefCounted
var _probe: RefCounted
var _target: Dictionary = {}
var _previous_id := 0
var _reason := ""

func configure(scene: Node3D, body: CharacterBody3D) -> bool:
	if not is_instance_valid(scene) or not is_instance_valid(body): return false
	_registry=Registry.for_scene(scene)
	_benches=Benches.new(); _benches.configure(scene)
	_probe=Physical.new()
	return _probe.configure(body)

func select(body: CharacterBody3D, unit: float) -> Dictionary:
	_target.clear(); _reason="no_real_bench_destination"
	if not is_instance_valid(_registry): return {}
	var candidates: Array=[]
	for row: Dictionary in _registry.rows():
		if not _registry.current(row) or not _registry.available(int(row.bench_id)): continue
		var bench: Node3D=row.bench.get_ref()
		var approach: Vector3=bench.to_global(Vector3(0,0,.72))
		var distance: float=Vector2(approach.x-body.global_position.x,approach.z-body.global_position.z).length()
		if distance<2.0 or distance>MAX_DISTANCE or int(row.bench_id)==_previous_id: continue
		candidates.append({"row":row,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a.distance)<float(b.distance))
	# At most two supported candidates among the four nearest real benches.
	# These goal checks do not imply that the route itself is reachable.
	var count: int=mini(candidates.size(),4)
	if count==0: return {}
	var first: int=mini(count-1,int(clampf(unit,0.0,1.0)*count))
	for attempt: int in mini(2,count):
		var row: Dictionary=candidates[(first+attempt)%count].row
		var bench: Node3D=row.bench.get_ref()
		var approach: Vector3=bench.to_global(Vector3(0,0,.72))
		var floor: Variant=_probe.floor_at(approach,bench.global_position.y)
		if not floor is Vector3 or not _probe.standing(floor): continue
		var seat: Vector3=bench.to_global(Vector3(0,.48,.18))
		if seat.y-floor.y<.35 or seat.y-floor.y>.65: continue
		var target: Dictionary=row.duplicate()
		target["approach"]=floor;target["seat"]=seat;target["right"]=bench.global_basis.x.normalized()
		if not _benches.supported(target,body): continue
		_target=target;_previous_id=int(row.bench_id);_reason=""
		return {"point":floor,"bench_id":row.bench_id,"bench_path":str(bench.get_path()),"purpose":"visit_real_bench"}
	_reason="bench_approach_unsupported"
	return {}

func current() -> bool:
	return not _target.is_empty() and is_instance_valid(_registry) and _registry.current(_target)

func clear() -> void: _target.clear()

func snapshot() -> Dictionary:
	return {"purpose":"visit_real_bench","bench_id":_target.get("bench_id",0),"reason":_reason,"seat_reserved":false,"max_goal_candidates":2}
