extends "npc_postmortem_bullet_marks.gd"
## Reuses the original skinning/cache, one mesh and existing 24-mark budget.
## Melee has a separate broad bruise / narrow frayed abrasion silhouette.
## Cloth marks are cosmetic frayed tears, not topology cuts or cloth simulation.
var _melee_surface := -1
var _melee_shape := false

func contact_anchor_from_ray(point: Vector3, incoming: Vector3, depth: float) -> Dictionary:
	if not _valid() or _batch_active or not point.is_finite() or not incoming.is_finite() or incoming.length_squared()<.5 or not is_finite(depth) or depth<=0: return {}
	_query_cache.clear(); _query_bones=_bone_poses(); _prepare_query_frames()
	var query: Dictionary=_query(point,-incoming.normalized(),depth)
	var anchor: Dictionary=_probe(query,point,-incoming.normalized())
	_query_cache.clear()
	if anchor.is_empty(): return {}
	return {"surface_index":anchor.s,"face_indices":anchor.ids,"barycentric":anchor.weights,"point":anchor.world_point,"normal":anchor.world_normal}

func sample_surface_anchor(anchor: Dictionary) -> Dictionary:
	if not _valid() or not anchor.get("surface_index") is int or not anchor.get("face_indices") is Vector3i or not anchor.get("barycentric") is Vector3: return {}
	var index: int=anchor.surface_index
	if index<0 or index>=_surfaces.size(): return {}
	var s: Dictionary=_surfaces[index]; var ids: Vector3i=anchor.face_indices; var w: Vector3=anchor.barycentric
	if not w.is_finite() or w.x<-.0001 or w.y<-.0001 or w.z<-.0001 or absf(w.x+w.y+w.z-1)>.0001: return {}
	for vertex: int in [ids.x,ids.y,ids.z]:
		if vertex<0 or vertex>=s.vertices.size(): return {}
	var matrices: Array[Transform3D]=_matrices(s)
	var a: Vector3=_vertex(s,ids.x,matrices); var b: Vector3=_vertex(s,ids.y,matrices); var c: Vector3=_vertex(s,ids.z,matrices)
	var point: Vector3=a*w.x+b*w.y+c*w.z
	return {"point":point} if point.is_finite() else {}

func accept_melee(event_id: String, point: Vector3, normal: Vector3, surface: int) -> bool:
	if _melee_shape or surface<0 or surface>=_surfaces.size(): return false
	_melee_surface=surface; _melee_shape=true
	var accepted: bool=super.accept(event_id,point,normal)
	_melee_shape=false; _melee_surface=-1
	if accepted: _marks.back()["kind"]="bruise_and_abrasion" if _surfaces[surface].skin_material else "frayed_cloth_tear"
	return accepted

func _query(point: Vector3, normal: Vector3, coarse_depth: float=0.0) -> Dictionary:
	var result: Dictionary=super._query(point,normal,coarse_depth)
	if _melee_surface>=0:
		var local: Array[Dictionary]=[]
		for triangle: Dictionary in result.triangles:
			if triangle.s==_melee_surface: local.append(triangle)
		result.triangles=local
	return result

func _shape(event_id: String, clothing: bool) -> Array[Dictionary]:
	if not _melee_shape: return super._shape(event_id,clothing)
	var triangles: Array[Dictionary]=[]
	if clothing:
		# An asymmetric split with pale raised ragged lips. No circular puncture.
		var a:=Vector2(-.100,-.013)*_unit; var b:=Vector2(.110,.010)*_unit
		var c:=Vector2(.015,.028)*_unit; var d:=Vector2(-.018,-.026)*_unit
		triangles.append({"points":[a,b,c],"material":0,"offset":.006*_unit})
		triangles.append({"points":[a,d,b],"material":0,"offset":.006*_unit})
		for i in 5:
			var t:=float(i)/5.0; var p:=a.lerp(b,t); var q:=a.lerp(b,t+.16)
			var edge:=Vector2(.006,.022 if i%2==0 else -.021)*_unit
			triangles.append({"points":[p,q,p+edge],"material":1,"offset":.012*_unit})
	else:
		# Broad mottled bruise, followed by a short red abrasion. No bullet hole.
		for i in 12:
			var angle:=float(i)/12.0*TAU; var next:=float(i+1)/12.0*TAU
			var p:=Vector2(cos(angle)*.095,sin(angle)*.064)*_unit
			var q:=Vector2(cos(next)*.095,sin(next)*.064)*_unit
			triangles.append({"points":[Vector2.ZERO,p,q],"material":4 if i%3!=0 else 2,"offset":.006*_unit})
		var a:=Vector2(-.044,-.003)*_unit; var b:=Vector2(.035,.009)*_unit
		triangles.append({"points":[a,b,Vector2(.002,.016)*_unit],"material":3,"offset":.009*_unit})
	return triangles
