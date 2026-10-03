extends RefCounted
## Pure source selection policy, independent of inventory/renderer/authority.
## ground_weapons.mjs nearestWeaponDrop; walk_preview.mjs dropCurrentWeapon.
const RANGE := 1.65
const MAX_HEIGHT := .65
const PATH_STEP := .12
const DROP_DISTANCES := [.8,.55,.3,0.0]

static func path_clear(origin: Vector3, target: Vector3, reachable: Callable) -> bool:
	if not origin.is_finite() or not target.is_finite() or not reachable.is_valid(): return false
	var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
	if distance>RANGE or absf(target.y-origin.y)>MAX_HEIGHT: return false
	var steps := maxi(1,int(ceil(distance/PATH_STEP)))
	for index: int in range(1,steps+1):
		var t := float(index)/steps
		if not reachable.call(Vector3(lerpf(origin.x,target.x,t),origin.y,lerpf(origin.z,target.z,t))): return false
	return true

static func nearest(drops: Array, origin: Vector3, reachable: Callable) -> Dictionary:
	if not origin.is_finite(): return {}
	var candidates: Array=[]; var ordinal:=0
	for drop: Dictionary in drops:
		var p: Dictionary=drop.position
		var point:=Vector3(p.x,p.y,p.z)
		var distance:=Vector2(point.x-origin.x,point.z-origin.z).length()
		if distance>RANGE or absf(point.y-origin.y)>MAX_HEIGHT: continue
		candidates.append({"drop":drop,"distance":distance,"point":point,"ordinal":ordinal}); ordinal+=1
	# Same source result and insertion-order ties, but nearest-first avoids
	# probing a farther path only to replace it with the next closer drop.
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.ordinal<b.ordinal if a.distance==b.distance else a.distance<b.distance)
	for candidate: Dictionary in candidates:
		if path_clear(origin,candidate.point,reachable):
			candidate.erase("ordinal"); return candidate
	return {}

static func drop_points(origin: Vector3, hero_source_yaw: float) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if not origin.is_finite() or not is_finite(hero_source_yaw): return result
	var forward:=Vector3(sin(hero_source_yaw),0,cos(hero_source_yaw))
	for distance: float in DROP_DISTANCES: result.append(origin+forward*distance)
	return result
