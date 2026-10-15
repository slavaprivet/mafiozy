extends RefCounted
## Pure preparation of CLOSED rubble from one removed coplanar surface patch.
## No scene, physics-body, source-mesh or authority mutation occurs here.
## Caller supplies effective materials on removed surfaces and commits only
## after reserving every returned piece. Corners/opposed slab faces are HOLD.
const MAX_INPUT_TRIANGLES := 256
const MAX_SURFACES := 32
const MAX_CELL_VISITS := 2048
const MAX_POLYGONS := 512
const MAX_BUCKET_POLYGONS := 64
const MAX_OUTPUT_VERTICES := 24576
const EPS := 0.000001
const PLANE_EPS := 0.0001
const MIN_AREA := 0.00000001
const MAX_LOCAL_METRES := 100000.0
const COLLISION_SCALE := 0.98 # The accepted showcase leaves a 2% collider gap.

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"pieces":[]}

static func prepare(removed: ArrayMesh, world_frame: Transform3D, thickness_m: float, cell_size_m: float = 0.5, max_pieces: int = 64) -> Dictionary:
	if removed==null or removed.get_surface_count()==0 or removed.get_surface_count()>MAX_SURFACES or removed.get_blend_shape_count()!=0: return _fail("surface_or_blend_shape_contract")
	if not world_frame.is_finite() or not is_finite(world_frame.basis.determinant()) or world_frame.basis.determinant()<=0.00000001: return _fail("reflected_or_singular_transform")
	if not is_finite(thickness_m) or thickness_m<0.01 or thickness_m>2.0 or not is_finite(cell_size_m) or cell_size_m<0.05 or cell_size_m>1.0 or max_pieces<1 or max_pieces>256: return _fail("size_or_piece_budget")
	var triangles:=0
	for surface: int in removed.get_surface_count():
		if removed.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _fail("non_triangle_surface")
		var count: int=removed.surface_get_array_index_len(surface)
		if count==0: count=removed.surface_get_array_len(surface)
		if count%3!=0: return _fail("triangle_count")
		triangles+=count/3
		if triangles>MAX_INPUT_TRIANGLES: return _fail("input_triangle_budget")
		if _glass(removed.surface_get_material(surface)): return _fail("glass_belongs_to_separate_owner")
	var normal_matrix: Basis=world_frame.basis.inverse().transposed()
	var plane: Dictionary={}
	var buckets: Dictionary={}
	var occupied_cells: Dictionary={}
	var visits:=0
	var polygons:=0
	var total_area:=0.0
	for surface: int in removed.get_surface_count():
		var arrays: Array=removed.surface_get_arrays(surface)
		for slot: int in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
			if arrays[slot]!=null and not arrays[slot].is_empty(): return _fail("unsupported_vertex_channels")
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
		var uv2: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
		for channel: Variant in [normals,uv,uv2,colors]:
			if not channel.is_empty() and channel.size()!=vertices.size(): return _fail("vertex_channel_length")
		var count: int=indices.size() if not indices.is_empty() else vertices.size()
		for start: int in range(0,count,3):
			var poly: Array=[]
			var supplied_normal:=Vector3.ZERO
			for corner: int in 3:
				var index: int=indices[start+corner] if not indices.is_empty() else start+corner
				if index<0 or index>=vertices.size() or not vertices[index].is_finite(): return _fail("vertex_index_or_position")
				var tex: Vector2=uv[index] if not uv.is_empty() else Vector2.ZERO
				var tex2: Vector2=uv2[index] if not uv2.is_empty() else Vector2.ZERO
				var tint: Color=colors[index] if not colors.is_empty() else Color.WHITE
				if not tex.is_finite() or not tex2.is_finite() or not _color_finite(tint): return _fail("vertex_attributes")
				if not normals.is_empty():
					if not normals[index].is_finite(): return _fail("vertex_normal")
					supplied_normal+=normal_matrix*normals[index]
				# Keep intermediate geometry relative to the instance origin. Adding
				# a distant city translation before clipping loses float precision.
				var point: Vector3=world_frame.basis*vertices[index]
				if not point.is_finite() or maxf(absf(point.x),maxf(absf(point.y),absf(point.z)))>MAX_LOCAL_METRES: return _fail("world_scaled_coordinate_budget")
				poly.append({"p":point,"q":Vector2.ZERO,"uv":tex,"uv2":tex2,"color":tint})
			var cross: Vector3=(poly[1].p-poly[0].p).cross(poly[2].p-poly[0].p)
			if cross.length_squared()<0.0000000000000001: continue # Only truly degenerate input faces.
			var triangle_normal: Vector3=cross.normalized()
			# Godot front winding is clockwise. Explicit source normals resolve
			# imported winding; absent normals use the native front-face convention.
			if supplied_normal.length_squared()>EPS*EPS:
				if absf(triangle_normal.dot(supplied_normal.normalized()))<0.999: return _fail("nonplanar_source_normals")
				if triangle_normal.dot(supplied_normal)<0: triangle_normal=-triangle_normal
			else: triangle_normal=-triangle_normal
			if plane.is_empty():
				var reference:=Vector3.UP if absf(triangle_normal.y)<0.9 else Vector3.RIGHT
				var u: Vector3=reference.cross(triangle_normal).normalized()
				plane={"normal":triangle_normal,"u":u,"v":triangle_normal.cross(u).normalized(),"point":poly[0].p,"origin":world_frame.origin}
			if triangle_normal.dot(plane.normal)<0.99999: return _fail("noncoplanar_or_opposed_faces_require_slab_adapter")
			for vertex: Dictionary in poly:
				if absf((vertex.p-plane.point).dot(plane.normal))>PLANE_EPS: return _fail("noncoplanar_or_opposed_faces_require_slab_adapter")
				vertex.q=Vector2(vertex.p.dot(plane.u),vertex.p.dot(plane.v))
			if _area(poly)<0: poly.reverse()
			var area: float=absf(_area(poly))
			if area<MIN_AREA: return _fail("positive_area_sliver")
			total_area+=area
			var bounds: Rect2=_bounds(poly)
			var low:=Vector2i(floori(bounds.position.x/cell_size_m),floori(bounds.position.y/cell_size_m))
			var high:=Vector2i(floori((bounds.end.x-EPS)/cell_size_m),floori((bounds.end.y-EPS)/cell_size_m))
			high.x=maxi(high.x,low.x); high.y=maxi(high.y,low.y)
			var needed: int=(high.x-low.x+1)*(high.y-low.y+1)
			if needed<=0 or needed>MAX_CELL_VISITS-visits: return _fail("cell_visit_budget")
			visits+=needed
			for x: int in range(low.x,high.x+1):
				for y: int in range(low.y,high.y+1):
					var clipped: Array=_clip_cell(poly,Vector2(x,y)*cell_size_m,cell_size_m)
					if clipped.size()<3: continue
					clipped=_clean(clipped)
					if clipped.size()<3: continue
					var clipped_area: float=absf(_area(clipped))
					if clipped_area<MIN_AREA: return _fail("cell_boundary_sliver")
					var key: String=str(surface)+":"+str(x)+":"+str(y)
					var cell_key: String=str(x)+":"+str(y)
					if not buckets.has(key): buckets[key]={"surface":surface,"cell":Vector2i(x,y),"polygons":[]}
					if not occupied_cells.has(cell_key): occupied_cells[cell_key]=[]
					var existing: Array=buckets[key].polygons
					var occupied: Array=occupied_cells[cell_key]
					if occupied.size()>=MAX_BUCKET_POLYGONS or polygons>=MAX_POLYGONS: return _fail("polygon_budget")
					# Separate material surfaces may also overlap; never emit stacked
					# colliders just because the materials differ.
					for other: Array in occupied:
						if _intersection_area(clipped,other)>maxf(MIN_AREA,minf(clipped_area,absf(_area(other)))*0.00001): return _fail("overlapping_source_faces")
					existing.append(clipped)
					occupied.append(clipped)
					polygons+=1
	if plane.is_empty() or buckets.is_empty(): return _fail("empty_removed_patch")
	var depth_count: int=ceili(thickness_m/cell_size_m)
	var depth: float=thickness_m/depth_count
	var plans: Array=[]
	var output_vertices:=0
	var covered_area:=0.0
	for bucket: Dictionary in buckets.values():
		var merged: Array=_merge_convex(bucket.polygons)
		for poly: Array in merged:
			covered_area+=absf(_area(poly))
			for layer: int in depth_count:
				if plans.size()>=max_pieces: return _fail("piece_budget")
				output_vertices+=(4*poly.size()-4)*3
				if output_vertices>MAX_OUTPUT_VERTICES: return _fail("output_vertex_budget")
				plans.append({"polygon":poly,"surface":bucket.surface,"cell":bucket.cell,"depth_index":layer,"depth_count":depth_count,"offset":layer*depth,"depth":depth})
	if absf(covered_area-total_area)>maxf(0.00001,total_area*0.0001): return _fail("surface_coverage_mismatch")
	# ArrayMesh resources are allocated only after complete area/piece admission.
	var pieces: Array=[]
	var volume:=0.0
	for plan: Dictionary in plans:
		var piece: Dictionary=_prism(plan,plane,removed.surface_get_material(plan.surface),cell_size_m)
		pieces.append(piece)
		volume+=piece.volume_m3
	return {"ok":true,"pieces":pieces,"piece_count":pieces.size(),"front_area_m2":covered_area,"volume_m3":volume,"thickness_m":thickness_m,"cell_size_m":cell_size_m,"input_triangles":triangles,"visited_cells":visits,"output_vertices":output_vertices,"scope":"coplanar_closed_patch_fragments","prototype_parity":false}

static func _glass(material: Material) -> bool:
	if material==null: return false
	if material.has_meta("breakableGlass") and material.get_meta("breakableGlass")==true: return true
	var label: String=material.resource_name.to_lower()
	for token: String in ["glass","glazing","windshield","windscreen"]:
		if token in label: return true
	return material.has_meta("transmission") and float(material.get_meta("transmission"))>0.0

static func _color_finite(color: Color) -> bool:
	return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)

static func _area(poly: Array) -> float:
	if poly.size()<3: return 0.0
	var origin: Vector2=poly[0].q
	var sum:=0.0
	for index: int in range(1,poly.size()-1): sum+=(poly[index].q-origin).cross(poly[index+1].q-origin)
	return sum*.5

static func _bounds(poly: Array) -> Rect2:
	var result:=Rect2(poly[0].q,Vector2.ZERO)
	for vertex: Dictionary in poly: result=result.expand(vertex.q)
	return result

static func _lerp_vertex(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
	return {"p":a.p.lerp(b.p,t),"q":a.q.lerp(b.q,t),"uv":a.uv.lerp(b.uv,t),"uv2":a.uv2.lerp(b.uv2,t),"color":a.color.lerp(b.color,t)}

static func _clip_axis(poly: Array,axis: int,value: float,keep_less: bool) -> Array:
	var result: Array=[]
	if poly.is_empty(): return result
	var previous: Dictionary=poly.back()
	var pd: float=previous.q[axis]-value
	var previous_inside: bool=pd<=EPS if keep_less else pd>=-EPS
	for current: Dictionary in poly:
		var cd: float=current.q[axis]-value
		var current_inside: bool=cd<=EPS if keep_less else cd>=-EPS
		if current_inside!=previous_inside: result.append(_lerp_vertex(previous,current,clampf(pd/(pd-cd),0.0,1.0)))
		if current_inside: result.append(current)
		previous=current; pd=cd; previous_inside=current_inside
	return result

static func _clip_cell(poly: Array,origin: Vector2,size: float) -> Array:
	var result: Array=poly
	for axis: int in 2:
		result=_clip_axis(result,axis,origin[axis],false)
		result=_clip_axis(result,axis,origin[axis]+size,true)
	return result

static func _clean(poly: Array) -> Array:
	var result: Array=[]
	for vertex: Dictionary in poly:
		if result.is_empty() or vertex.q.distance_squared_to(result.back().q)>EPS*EPS: result.append(vertex)
	if result.size()>1 and result[0].q.distance_squared_to(result.back().q)<=EPS*EPS: result.pop_back()
	var changed:=true
	while changed and result.size()>3:
		changed=false
		for index: int in result.size():
			var before: Vector2=result[(index+result.size()-1)%result.size()].q
			var point: Vector2=result[index].q
			var after: Vector2=result[(index+1)%result.size()].q
			if absf((point-before).cross(after-point))<EPS*EPS and (point-before).dot(after-point)>=0:
				result.remove_at(index); changed=true; break
	return result

static func _intersection_area(a: Array,b: Array) -> float:
	if not _bounds(a).grow(EPS).intersects(_bounds(b)): return 0.0
	var points: Array=[]
	for vertex: Dictionary in a: points.append(vertex.q)
	for index: int in b.size():
		if points.size()<3: return 0.0
		var begin: Vector2=b[index].q
		var edge: Vector2=b[(index+1)%b.size()].q-begin
		var next: Array=[]
		var previous: Vector2=points.back()
		var pd: float=edge.cross(previous-begin)
		for point: Vector2 in points:
			var distance: float=edge.cross(point-begin)
			if (distance>=0)!=(pd>=0): next.append(previous.lerp(point,clampf(pd/(pd-distance),0.0,1.0)))
			if distance>=0: next.append(point)
			previous=point; pd=distance
		points=next
	if points.size()<3: return 0.0
	var area:=0.0
	for index: int in range(1,points.size()-1): area+=(points[index]-points[0]).cross(points[index+1]-points[0])
	return absf(area)*.5

static func _same_vertex(a: Dictionary,b: Dictionary) -> bool:
	return a.q.distance_squared_to(b.q)<=EPS*EPS and a.p.distance_squared_to(b.p)<=EPS*EPS and a.uv.distance_squared_to(b.uv)<=EPS*EPS and a.uv2.distance_squared_to(b.uv2)<=EPS*EPS and a.color.is_equal_approx(b.color)

static func _same_affine_attributes(a: Array,b: Array) -> bool:
	# Removing the shared diagonal is valid only if one affine UV/color field
	# describes both polygons. Otherwise preserve the original triangle seam.
	var origin: Dictionary=a[0]
	var one: Dictionary=a[1]
	var two: Dictionary={}
	var determinant:=0.0
	for index: int in range(2,a.size()):
		two=a[index]
		determinant=(one.q-origin.q).cross(two.q-origin.q)
		if absf(determinant)>MIN_AREA: break
	if absf(determinant)<=MIN_AREA: return false
	for vertex: Dictionary in a+b:
		var delta: Vector2=vertex.q-origin.q
		var weight_one: float=delta.cross(two.q-origin.q)/determinant
		var weight_two: float=(one.q-origin.q).cross(delta)/determinant
		var uv: Vector2=origin.uv+(one.uv-origin.uv)*weight_one+(two.uv-origin.uv)*weight_two
		var uv2: Vector2=origin.uv2+(one.uv2-origin.uv2)*weight_one+(two.uv2-origin.uv2)*weight_two
		var color: Color=origin.color+(one.color-origin.color)*weight_one+(two.color-origin.color)*weight_two
		if uv.distance_squared_to(vertex.uv)>EPS*EPS or uv2.distance_squared_to(vertex.uv2)>EPS*EPS or not color.is_equal_approx(vertex.color): return false
	return true

static func _try_merge(a: Array,b: Array) -> Array:
	if not _same_affine_attributes(a,b): return []
	var shared:=false
	for i: int in a.size():
		for j: int in b.size():
			if _same_vertex(a[i],b[(j+1)%b.size()]) and _same_vertex(a[(i+1)%a.size()],b[j]): shared=true
	if not shared: return []
	var points:=PackedVector2Array()
	for vertex: Dictionary in a+b: points.append(vertex.q)
	var hull: PackedVector2Array=Geometry2D.convex_hull(points)
	if hull.size()>1 and hull[0].distance_squared_to(hull[-1])<=EPS*EPS: hull.resize(hull.size()-1)
	if hull.size()<3: return []
	var result: Array=[]
	for point: Vector2 in hull:
		var candidate: Dictionary={}
		for vertex: Dictionary in a+b:
			if vertex.q.distance_squared_to(point)>EPS*EPS: continue
			if not candidate.is_empty() and not _same_vertex(candidate,vertex): return []
			candidate=vertex
		if candidate.is_empty(): return []
		result.append(candidate)
	if _area(result)<0: result.reverse()
	if absf(absf(_area(result))-absf(_area(a))-absf(_area(b)))>maxf(MIN_AREA,(absf(_area(a))+absf(_area(b)))*0.00001): return []
	return _clean(result)

static func _merge_convex(polygons: Array) -> Array:
	var result: Array=polygons.duplicate()
	var changed:=true
	while changed:
		changed=false
		for i: int in result.size():
			for j: int in range(i+1,result.size()):
				var merged: Array=_try_merge(result[i],result[j])
				if merged.is_empty(): continue
				result[i]=merged; result.remove_at(j); changed=true; break
			if changed: break
	return result

static func _sink() -> Dictionary:
	return {"v":PackedVector3Array(),"n":PackedVector3Array(),"uv":PackedVector2Array(),"uv2":PackedVector2Array(),"color":PackedColorArray(),"tangent":PackedFloat32Array(),"max_tangent_dot":0.0,"max_unit_error":0.0}

static func _triangle(sink: Dictionary,points: Array,normal: Vector3) -> void:
	var ordered: Array=points.duplicate()
	# Clockwise front winding, matching the accepted showcase mesh builder.
	if (ordered[1].p-ordered[0].p).cross(ordered[2].p-ordered[0].p).dot(normal)>0:
		var swap: Dictionary=ordered[1]; ordered[1]=ordered[2]; ordered[2]=swap
	var tangent: Vector3=(Vector3.UP if absf(normal.y)<.9 else Vector3.RIGHT).cross(normal).normalized()
	var handedness:=1.0
	var edge_one: Vector3=ordered[1].p-ordered[0].p
	var edge_two: Vector3=ordered[2].p-ordered[0].p
	var uv_one: Vector2=ordered[1].uv-ordered[0].uv
	var uv_two: Vector2=ordered[2].uv-ordered[0].uv
	var determinant: float=uv_one.cross(uv_two)
	if absf(determinant)>EPS*EPS:
		var derivative_u: Vector3=(edge_one*uv_two.y-edge_two*uv_one.y)/determinant
		var derivative_v: Vector3=(edge_two*uv_one.x-edge_one*uv_two.x)/determinant
		tangent=(derivative_u-normal*normal.dot(derivative_u)).normalized()
		handedness=-1.0 if normal.cross(tangent).dot(derivative_v)<0 else 1.0
	# Track raw generation separately from the renderer's packed-mesh readback.
	sink.max_tangent_dot=maxf(sink.max_tangent_dot,absf(tangent.dot(normal)))
	sink.max_unit_error=maxf(sink.max_unit_error,maxf(absf(tangent.length()-1.0),absf(normal.length()-1.0)))
	for vertex: Dictionary in ordered:
		sink.v.append(vertex.p); sink.n.append(normal); sink.uv.append(vertex.uv); sink.uv2.append(vertex.uv2); sink.color.append(vertex.color)
		sink.tangent.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,handedness]))

static func _prism(plan: Dictionary,plane: Dictionary,material: Material,cell_size_m: float) -> Dictionary:
	var polygon: Array=plan.polygon
	var centre:=Vector3.ZERO
	for vertex: Dictionary in polygon: centre+=vertex.p
	centre=centre/polygon.size()-plane.normal*(plan.offset+plan.depth*.5)
	var basis:=Basis(plane.u,plane.v,plane.normal)
	var inverse: Basis=basis.transposed()
	var front: Array=[]
	var back: Array=[]
	var points:=PackedVector3Array()
	for vertex: Dictionary in polygon:
		var a: Dictionary=vertex.duplicate()
		a.p=inverse*(vertex.p-plane.normal*plan.offset-centre)
		var b: Dictionary=a.duplicate()
		b.p=a.p-Vector3.BACK*plan.depth
		front.append(a); back.append(b)
		points.append(a.p); points.append(b.p)
	var sink: Dictionary=_sink()
	var minimum_clearance: float=plan.depth*.5
	for index: int in range(1,polygon.size()-1):
		_triangle(sink,[front[0],front[index],front[index+1]],Vector3.BACK)
		_triangle(sink,[back[0],back[index],back[index+1]],Vector3.FORWARD)
	for index: int in polygon.size():
		var next: int=(index+1)%polygon.size()
		var edge: Vector3=front[next].p-front[index].p
		var normal:=Vector3(edge.y,-edge.x,0).normalized()
		minimum_clearance=minf(minimum_clearance,absf(normal.dot(front[index].p)))
		var a: Dictionary=front[index].duplicate(); var b: Dictionary=front[next].duplicate(); var c: Dictionary=back[next].duplicate(); var d: Dictionary=back[index].duplicate()
		a.uv=Vector2(0,0); b.uv=Vector2(edge.length(),0); c.uv=Vector2(edge.length(),plan.depth); d.uv=Vector2(0,plan.depth)
		_triangle(sink,[a,b,c],normal); _triangle(sink,[a,c,d],normal)
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=sink.v; arrays[Mesh.ARRAY_NORMAL]=sink.n; arrays[Mesh.ARRAY_TEX_UV]=sink.uv; arrays[Mesh.ARRAY_TEX_UV2]=sink.uv2; arrays[Mesh.ARRAY_COLOR]=sink.color; arrays[Mesh.ARRAY_TANGENT]=sink.tangent
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.surface_set_material(0,material)
	var bounds:=AABB(points[0],Vector3.ZERO)
	var collision_points:=PackedVector3Array()
	for point: Vector3 in points: bounds=bounds.expand(point); collision_points.append(point*COLLISION_SCALE)
	var area: float=absf(_area(polygon))
	var volume: float=area*float(plan.depth)
	return {"mesh":mesh,"shape_points":collision_points,"world_transform":Transform3D(basis,centre+plane.origin),"bounds":bounds,"section_size":bounds.size,"volume_m3":volume,"front_area_m2":area if plan.depth_index==0 else 0.0,"mass":clampf(volume*.7,.12,3.0),"source_surface":plan.surface,"cell":plan.cell,"depth_index":plan.depth_index,"depth_count":plan.depth_count,"thickness_m":plan.depth,"cell_size_m":cell_size_m,"collision_margin_m":minf(.002,minimum_clearance*.005),"minimum_center_clearance_m":minimum_clearance,"friction":.32,"bounce":0.0,"linear_damp":.45,"angular_damp":1.8,"collision_shape_scale":COLLISION_SCALE,"prepack_max_tangent_dot":sink.max_tangent_dot,"prepack_max_unit_error":sink.max_unit_error,"closed":true}
