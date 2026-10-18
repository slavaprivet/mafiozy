extends RefCounted
## Pure world-space triangle query. Bounds may shortlist geometry, but cannot
## establish a visible contact. No physics/scene mutation and no AABB fallback.
const MAX_TRIANGLES:=32768

static func closest_point(world_faces: PackedVector3Array,point: Vector3) -> Dictionary:
	if not point.is_finite(): return _no("nonfinite_query")
	if world_faces.is_empty(): return _no("no_geometry")
	if world_faces.size()%3!=0: return _no("incomplete_triangle")
	var count: int=world_faces.size()/3
	if count>MAX_TRIANGLES: return _no("contact_triangle_budget")
	# Validate the complete input even when an early triangle contains the point.
	for vertex: Vector3 in world_faces:
		if not vertex.is_finite(): return _no("nonfinite_geometry")
	var nearest:=Vector3.ZERO; var best:=INF; var triangle:=-1
	for index: int in count:
		var offset: int=index*3
		var candidate:=_triangle(point,world_faces[offset],world_faces[offset+1],world_faces[offset+2])
		if not candidate.is_finite(): return _no("contact_numeric_overflow")
		var distance_squared: float=point.distance_squared_to(candidate)
		if not is_finite(distance_squared): return _no("contact_numeric_overflow")
		# An exact tie belongs to the first original triangle deterministically.
		if distance_squared<best:
			best=distance_squared; nearest=candidate; triangle=index
	if triangle<0: return _no("no_finite_contact")
	return {"ok":true,"point":nearest,"distance":sqrt(best),"triangle":triangle}

static func _triangle(point: Vector3,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
	# The seven Voronoi regions of a triangle (vertices, edges, face interior).
	# Degenerate triangles remain their actual segments/points, never a box.
	var ab:=b-a; var ac:=c-a
	var area_squared: float=ab.cross(ac).length_squared()
	if not is_finite(area_squared): return Vector3(INF,INF,INF)
	if area_squared==0.0: return _degenerate(point,a,b,c)
	var ap:=point-a
	var d1: float=ab.dot(ap); var d2: float=ac.dot(ap)
	if d1<=0.0 and d2<=0.0: return a
	var bp:=point-b
	var d3: float=ab.dot(bp); var d4: float=ac.dot(bp)
	if d3>=0.0 and d4<=d3: return b
	var vc: float=d1*d4-d3*d2
	if vc<=0.0 and d1>=0.0 and d3<=0.0: return a+ab*(d1/(d1-d3))
	var cp:=point-c
	var d5: float=ab.dot(cp); var d6: float=ac.dot(cp)
	if d6>=0.0 and d5<=d6: return c
	var vb: float=d5*d2-d1*d6
	if vb<=0.0 and d2>=0.0 and d6<=0.0: return a+ac*(d2/(d2-d6))
	var va: float=d3*d6-d5*d4
	if va<=0.0 and d4-d3>=0.0 and d5-d6>=0.0: return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)))
	var denominator: float=va+vb+vc
	if not is_finite(denominator) or denominator<=0.0: return Vector3(INF,INF,INF)
	return a+ab*(vb/denominator)+ac*(vc/denominator)

static func _segment(point: Vector3,a: Vector3,b: Vector3) -> Vector3:
	var delta:=b-a; var squared: float=delta.length_squared()
	if not is_finite(squared): return Vector3(INF,INF,INF)
	if squared==0.0: return a
	return a+delta*clampf((point-a).dot(delta)/squared,0.0,1.0)

static func _degenerate(point: Vector3,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
	var nearest:=_segment(point,a,b)
	for candidate: Vector3 in [_segment(point,b,c),_segment(point,c,a)]:
		if not candidate.is_finite(): return candidate
		if point.distance_squared_to(candidate)<point.distance_squared_to(nearest): nearest=candidate
	return nearest

static func _no(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
