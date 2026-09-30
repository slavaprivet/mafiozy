extends RefCounted
## QA only. Nearest rendered building triangles; never changes real impact admission.
var parts:Array=[]
func configure(building:Node3D)->void:
	parts.clear()
	for node:Node in building.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null or not node.is_visible_in_tree():continue
		parts.append({"node":node,"inverse":node.global_transform.affine_inverse(),"bounds":node.mesh.get_aabb(),"triangle":node.mesh.generate_triangle_mesh()})
func nearest(origin:Vector3,endpoint:Vector3)->Dictionary:
	var nearest_distance:=INF;var result:Dictionary={}
	for part:Dictionary in parts:
		var a:Vector3=part.inverse*origin;var b:Vector3=part.inverse*endpoint
		if not part.bounds.intersects_segment(a,b):continue
		var hit:Dictionary=part.triangle.intersect_segment(a,b)
		if hit.is_empty():continue
		var point:Vector3=part.node.global_transform*hit.position
		var distance:=origin.distance_to(point)
		if distance<nearest_distance:
			nearest_distance=distance;result={"point":point,"distance":distance,"node":str(part.node.get_path())}
	return result
func patch(point:Vector3,normal:Vector3,radius:float=.13)->Dictionary:
	var tangent:=normal.cross(Vector3.UP).normalized();var rows:Array=[]
	for offset:Vector2 in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius),Vector2(radius,radius),Vector2(-radius,radius),Vector2(radius,-radius),Vector2(-radius,-radius)]:
		var sample:=point+tangent*offset.x+Vector3.UP*offset.y
		var hit:=nearest(sample+normal*1.5,sample-normal*1.5)
		if hit.is_empty():return {"ok":false,"reason":"no_visible_mesh","sample":sample,"rows":rows}
		hit.gap=(hit.point-sample).dot(normal);rows.append(hit)
		# The admitted source mark is +4mm. Any nearer trim/wall hides it.
		# Reject a floating mark more than 2cm ahead of the actual support as well.
		if hit.gap>.003 or hit.gap<-.02:return {"ok":false,"reason":"envelope_not_visible_surface","rows":rows}
	return {"ok":true,"rows":rows,"radius":radius}
func visible_from(origin:Vector3,point:Vector3)->Dictionary:
	var hit:=nearest(origin,point)
	return {"ok":hit.is_empty() or origin.distance_to(point)-float(hit.distance)<.003,"obstruction":hit}
