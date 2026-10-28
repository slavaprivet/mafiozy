extends RefCounted
## Selects an existing real bench as a walking purpose. Task58: the seat is RESERVED
## here, by the same main-thread call that decides to walk there, because two residents
## that both see the same bench free must not both be sent to it. The reservation
## survives the walk, is kept alive by renew(), and is adopted by the ambient action
## that finally reaches the bench. The ordinary physical driver owns the route and motion.
const Registry = preload("res://scripts/npc_ambient/ambient_bench_registry29.gd")
const Benches = preload("res://scripts/npc_ambient/ambient_benches28.gd")
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
## DSH_ONEGOAL58: the radius is not a shrunken guess. Measured: with a 120 m cap four of the
## ten homes had no bench inside it at all, so those residents never left their spawn point
## and only performed in-place gestures for the whole run. A resident must be able to reach a
## real place, so the cap now covers the whole prepared walking district.
const MAX_DISTANCE := 320.0
const MAX_GOAL_CANDIDATES := 2
const MAX_RESERVE_CANDIDATES := 6
var _registry: Node
var _benches: RefCounted
var _probe: RefCounted
var _target: Dictionary = {}
var _slot: Dictionary = {}
var _previous_id := 0
var _action_serial := 0
var _reason := ""
# DSH_ONEGOAL58: the nearest real bench and why it was not usable, so a resident that has
# nowhere to go says so with a number instead of standing still without explanation.
var _nearest_m := -1.0

func configure(scene: Node3D, body: CharacterBody3D) -> bool:
	if not is_instance_valid(scene) or not is_instance_valid(body): return false
	_registry=Registry.for_scene(scene)
	_benches=Benches.new(); _benches.configure(scene)
	_probe=Physical.new()
	return _probe.configure(body)

## One goal. Returns the plan the caller walks to, including the reserved seat.
## `avoid` carries the places that were already refused for THIS decision, so a refused
## goal is replaced by another real place instead of being tried again.
func select(body: CharacterBody3D, unit: float, avoid: Array = []) -> Dictionary:
	_target.clear(); _reason="no_real_bench_destination"
	if not is_instance_valid(_registry): return {}
	var candidates: Array=[]
	_nearest_m=-1.0
	for row: Dictionary in _registry.rows():
		if not _registry.current(row): continue
		var bench: Node3D=row.bench.get_ref()
		var approach: Vector3=bench.to_global(Vector3(0,0,.72))
		var distance: float=Vector2(approach.x-body.global_position.x,approach.z-body.global_position.z).length()
		if _nearest_m < 0.0 or distance < _nearest_m: _nearest_m=distance
		if not _registry.available(int(row.bench_id)): continue
		if int(row.bench_id) in avoid: continue
		if distance<2.0 or distance>MAX_DISTANCE or int(row.bench_id)==_previous_id: continue
		candidates.append({"row":row,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a.distance)<float(b.distance))
	# At most two supported candidates among the four nearest real benches.
	# These goal checks do not imply that the route itself is reachable.
	var count: int=mini(candidates.size(),4)
	if count==0: return {}
	var first: int=mini(count-1,int(clampf(unit,0.0,1.0)*count))
	var unsupported := 0
	var held := 0
	for attempt: int in mini(MAX_RESERVE_CANDIDATES,count):
		var row: Dictionary=candidates[(first+attempt)%count].row
		var bench: Node3D=row.bench.get_ref()
		var approach: Vector3=bench.to_global(Vector3(0,0,.72))
		var floor: Variant=_probe.floor_at(approach,bench.global_position.y)
		if not floor is Vector3 or not _probe.standing(floor): unsupported+=1; continue
		var seat: Vector3=bench.to_global(Vector3(0,.48,.18))
		if seat.y-floor.y<.35 or seat.y-floor.y>.65: unsupported+=1; continue
		var target: Dictionary=row.duplicate()
		target["approach"]=floor;target["seat"]=seat;target["right"]=bench.global_basis.x.normalized()
		if not _benches.supported(target,body): unsupported+=1; continue
		# THE SEAT IS TAKEN HERE, not after arrival: the next resident that looks at
		# this bench already sees it as not available.
		_action_serial+=1
		var lease: Dictionary=_registry.reserve(target,self,body,_action_serial,floor,seat,target["right"])
		if lease.is_empty(): held+=1; continue
		_target=target;_slot=lease;_previous_id=int(row.bench_id);_reason=""
		return {"point":floor,"bench_id":row.bench_id,"bench_path":str(bench.get_path()),"purpose":"visit_real_bench","reserved_seat":lease.duplicate()}
	if unsupported>0: _reason="bench_approach_unsupported"
	elif held>0: _reason="bench_reserved_by_another_resident"
	return {}

## Keeps the walk-time reservation alive. Called once per physics frame by the life.
func renew(body: CharacterBody3D) -> bool:
	if _slot.is_empty() or not is_instance_valid(_registry): return false
	return _registry.renew_reservation(_slot,self,body)

func reserved_slot() -> Dictionary: return _slot.duplicate()
func reserved_bench_id() -> int: return int(_slot.get("bench_id",0))

## True while this selection still owns its seat.
func current() -> bool:
	return not _target.is_empty() and not _slot.is_empty() and is_instance_valid(_registry) and _registry.current(_target)

## Drops both the goal and its reservation. Called when the walk ends or is interrupted.
## The bench is freed in the same call, so an interrupted walk never holds a seat.
func clear(body: CharacterBody3D = null) -> void:
	if not _slot.is_empty() and is_instance_valid(_registry):
		_registry.release_reservation(_slot,self,body,"cleared")
	_target.clear(); _slot={}

func snapshot() -> Dictionary:
	return {"purpose":"visit_real_bench","bench_id":_target.get("bench_id",0),"reason":_reason,
		"seat_reserved":not _slot.is_empty(),"reserved":_registry.reservations() if is_instance_valid(_registry) else -1,
		"nearest_bench_m":_nearest_m,"max_distance_m":MAX_DISTANCE,"max_goal_candidates":MAX_GOAL_CANDIDATES}
