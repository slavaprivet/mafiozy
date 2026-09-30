extends RefCounted
## Candidate: bounded screen-space assist, each accepted ray touches real mesh.
## Caller keeps proximity, open-lid, ownership and actor-control admission.
const RADIUS_AT_720:=12.0
var _renderer:RefCounted
var _parts:Array=[]
var _options:Dictionary={}
var _external_clear:Callable
var last_stats:Dictionary={}
func configure(renderer:RefCounted,vehicle_visual:Node3D,options:Dictionary,external_clear:Callable)->void:
	_renderer=renderer;_options=options.duplicate(true);_external_clear=external_clear
	# Per-vehicle cache, built once. Dynamic lid transforms read on each query.
	for node:Node in vehicle_visual.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null or node.get_meta("source_name","").is_empty():continue
		_parts.append({"node":weakref(node),"mesh":null,"bounds":node.mesh.get_aabb()})
func car_clear(origin:Vector3,point:Vector3)->bool:
	var end:=point+(origin-point).normalized()*.004
	for part:Dictionary in _parts:
		var node:MeshInstance3D=part.node.get_ref()
		if not is_instance_valid(node) or not node.is_visible_in_tree() or node.mesh==null:continue
		if not node.global_transform.is_finite() or absf(node.global_basis.determinant())<1.0e-10:return false
		var inverse:=node.global_transform.affine_inverse()
		var a:=inverse*origin;var b:=inverse*end
		last_stats.car_aabb_tests+=1
		# get_aabb is allocation-free metadata; observes mesh replacement/shape edits.
		part.bounds=node.mesh.get_aabb()
		if not part.bounds.intersects_segment(a,b):continue
		# Mesh owns its lazily generated acceleration data and invalidates it on
		# geometry changes. Never clone get_faces into a second full BVH.
		var triangle:TriangleMesh=node.mesh.generate_triangle_mesh()
		if triangle==null:continue
		part.mesh=triangle
		last_stats.car_triangle_tests+=1
		if not triangle.intersect_segment(a,b).is_empty():return false
	return true
func pick(camera:Camera3D)->Dictionary:
	if not _renderer._start(true):return {"ok":false,"reason":"state"}
	var result:=_pick(camera)
	return _renderer._finish(result)
func _surface_pick(origin:Vector3,direction:Vector3,candidates:Array)->Dictionary:
	var endpoint:=origin+direction.normalized()*12.0
	var nearest:=INF;var best:Dictionary={"ok":true,"hit":false}
	for candidate:Dictionary in candidates:
		var row:Dictionary=candidate.row
		var begin:Vector3=candidate.inverse*origin;var end:Vector3=candidate.inverse*endpoint
		if not row.bounds.intersects_segment(begin,end):continue
		var hit:Dictionary=candidate.mesh.intersect_segment(begin,end)
		if hit.is_empty():continue
		var point:Vector3=row.visual.global_transform*hit.position
		var distance:=origin.distance_to(point)
		if distance>=nearest:continue
		nearest=distance
		best={"ok":true,"hit":true,"item_uid":row.uid,"weaponId":row.weapon_id,"scope":"trunk","distance":distance,"point":point,"vehicle_id":_options.vehicle_id,"generation":_options.generation}
	return best
func _pick(camera:Camera3D)->Dictionary:
	last_stats={"rays":0,"car_aabb_tests":0,"car_triangle_tests":0}
	if _options.get("enabled")!=true or _options.get("scope")!="trunk" or _options.get("trunk_open")!=true:return {"ok":true,"hit":false}
	if not is_instance_valid(camera) or not _external_clear.is_valid():return {}
	var size:=camera.get_viewport().get_visible_rect().size
	var center:=size*.5;var unit:=size.y/720.0
	# Project model bounds once, so the empty rays never traverse every model.
	# These rectangles are only broad phase; every accepted pick is a triangle.
	var rectangles:Array[Rect2]=[]
	var candidates:Array=[]
	var binding:Dictionary=_renderer._binding(_options.vehicle_id,_options.generation)
	if binding.is_empty():return {"ok":true,"hit":false}
	for row:Dictionary in binding.items.values():
		if not _renderer._row_live(row) or not row.visual.is_visible_in_tree():continue
		var rectangle:=Rect2();var initialized:=false
		for corner:int in 8:
			var world:Vector3=row.visual.global_transform*row.bounds.get_endpoint(corner)
			if camera.is_position_behind(world):continue
			var projected:=camera.unproject_position(world)
			if not initialized:rectangle=Rect2(projected,Vector2.ZERO);initialized=true
			else:rectangle=rectangle.expand(projected)
		if initialized and rectangle.grow(RADIUS_AT_720*unit).has_point(center):
			if not _renderer._model_current(row):return {"ok":false,"reason":"model_changed"}
			var mesh:TriangleMesh=_renderer._triangle_mesh(row)
			if mesh==null:return {"ok":false,"reason":"geometry"}
			rectangles.append(rectangle.grow(.01))
			candidates.append({"row":row,"mesh":mesh,"inverse":row.visual.global_transform.affine_inverse()})
	if rectangles.is_empty():return {"ok":true,"hit":false}
	# Direct aim wins. Rings improve the tiny mini-model target without selecting
	# empty AABBs. Query order is deterministic: closest screen ring first.
	for radius:float in [0.0,4.0,8.0,RADIUS_AT_720]:
		var count:=1 if radius==0 else 8
		for index:int in count:
			var angle:=TAU*float(index)/float(count)
			var pixel:=center+Vector2(cos(angle),sin(angle))*radius*unit
			var possible:=false
			for rectangle:Rect2 in rectangles:
				if rectangle.has_point(pixel):possible=true;break
			if not possible:continue
			last_stats.rays+=1
			var hit:Dictionary=_surface_pick(camera.global_position,camera.project_ray_normal(pixel),candidates)
			if not hit.get("hit",false):continue
			if not car_clear(camera.global_position,hit.point):continue
			if not _external_clear.call(camera.global_position,hit.point):continue
			hit.screen_assist_pixels=radius*unit
			return hit
	return {"ok":true,"hit":false}
