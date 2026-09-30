extends RefCounted
## Local surface subtraction. Does NOT voxelize the filled building envelope.
## Each brush is a world-metre AABB; all other material surfaces keep their index.
const EPS = .00001
const MAX_INPUT_TRIANGLES=8192
const MAX_OUTPUT_VERTICES=98304

static func _mix(a:Array,b:Array,t:float) -> Array:
	var tangent:Vector4=a[4].lerp(b[4],t)
	var direction=Vector3(tangent.x,tangent.y,tangent.z).normalized()
	return [a[0].lerp(b[0],t),a[1].lerp(b[1],t).normalized(),a[2].lerp(b[2],t),a[3].lerp(b[3],t),Vector4(direction.x,direction.y,direction.z,a[4].w),a[5].lerp(b[5],t)]

static func _clip(poly:Array,axis:int,value:float,keep_less:bool,frame:Transform3D,strict:bool=false) -> Array:
	var out:Array=[]
	if poly.is_empty(): return out
	var previous:Array=poly.back()
	var pd:float=(frame*previous[0])[axis]-value
	var pin:bool=(pd < -EPS if keep_less else pd > EPS) if strict else (pd<=EPS if keep_less else pd>=-EPS)
	for current:Array in poly:
		var cd:float=(frame*current[0])[axis]-value
		var cin:bool=(cd < -EPS if keep_less else cd > EPS) if strict else (cd<=EPS if keep_less else cd>=-EPS)
		if cin != pin:
			out.append(_mix(previous,current,clampf(pd/(pd-cd),0.0,1.0)))
		if cin: out.append(current)
		previous=current; pd=cd; pin=cin
	return out

static func _subtract(poly:Array,box:AABB,frame:Transform3D) -> Dictionary:
	var bounds=AABB(frame*poly[0][0],Vector3.ZERO)
	for vertex:Array in poly: bounds=bounds.expand(frame*vertex[0])
	if not bounds.grow(EPS).intersects(box): return {"outside":[poly],"inside":[]}
	var inside:Array=poly
	var outside:Array=[]
	for axis:int in 3:
		for upper:bool in [false,true]:
			var value:float=box.end[axis] if upper else box.position[axis]
			var rejected:Array=_clip(inside,axis,value,not upper,frame,true)
			if rejected.size()>=3: outside.append(rejected)
			inside=_clip(inside,axis,value,upper,frame)
			if inside.size()<3: return {"outside":outside,"inside":[]}
	return {"outside":outside,"inside":inside}

static func _sink() -> Dictionary:
	return {"v":PackedVector3Array(),"n":PackedVector3Array(),"uv":PackedVector2Array(),"c":PackedColorArray(),"t":PackedFloat32Array(),"uv2":PackedVector2Array()}

static func _fan(sink:Dictionary,poly:Array) -> void:
	for i:int in range(1,poly.size()-1):
		var a:Vector3=poly[0][0]; var b:Vector3=poly[i][0]; var c:Vector3=poly[i+1][0]
		if (b-a).cross(c-a).length_squared()<.0000000001: continue
		for vertex:Array in [poly[0],poly[i],poly[i+1]]:
			sink.v.append(vertex[0]); sink.n.append(vertex[1]); sink.uv.append(vertex[2]); sink.c.append(vertex[3])
			for component:float in [vertex[4].x,vertex[4].y,vertex[4].z,vertex[4].w]: sink.t.append(component)
			sink.uv2.append(vertex[5])

static func _arrays(sink:Dictionary,has_uv:bool,has_color:bool,has_tangent:bool,has_uv2:bool) -> Array:
	var result:Array=[]; result.resize(Mesh.ARRAY_MAX)
	# Keep a degenerate surface if fully removed: glass surface indices stay stable.
	if sink.v.is_empty():
		for i:int in 3:
			sink.v.append(Vector3.ZERO); sink.n.append(Vector3.UP); sink.uv.append(Vector2.ZERO); sink.c.append(Color.WHITE)
			sink.t.append_array(PackedFloat32Array([1,0,0,1])); sink.uv2.append(Vector2.ZERO)
	result[Mesh.ARRAY_VERTEX]=sink.v; result[Mesh.ARRAY_NORMAL]=sink.n
	if has_uv: result[Mesh.ARRAY_TEX_UV]=sink.uv
	if has_color: result[Mesh.ARRAY_COLOR]=sink.c
	if has_tangent: result[Mesh.ARRAY_TANGENT]=sink.t
	if has_uv2: result[Mesh.ARRAY_TEX_UV2]=sink.uv2
	return result

static func supported(mesh:Mesh) -> bool:
	if not mesh is ArrayMesh or mesh.get_surface_count()==0 or mesh.get_blend_shape_count()!=0: return false
	for s:int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s)!=Mesh.PRIMITIVE_TRIANGLES: return false
		var a:Array=mesh.surface_get_arrays(s)
		for slot:int in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
			if a[slot]!=null and not a[slot].is_empty(): return false
	return true

static func cut(mesh:Mesh,frame:Transform3D,brushes_by_surface:Dictionary) -> Dictionary:
	if not supported(mesh) or not frame.is_finite() or absf(frame.basis.determinant())<.000001: return {"ok":false,"reason":"unsupported_geometry"}
	var input_triangles=0
	for s:int in mesh.get_surface_count():
		var a:Array=mesh.surface_get_arrays(s)
		input_triangles+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null and not a[Mesh.ARRAY_INDEX].is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
	if input_triangles>MAX_INPUT_TRIANGLES: return {"ok":false,"reason":"geometry_budget"}
	var output=ArrayMesh.new(); var removed=ArrayMesh.new(); var removed_faces=0; var removed_surfaces:Array=[]
	for s:int in mesh.get_surface_count():
		var a:Array=mesh.surface_get_arrays(s)
		var material:Material=mesh.surface_get_material(s)
		if not brushes_by_surface.has(s):
			output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
			output.surface_set_material(s,material)
			continue
		var kept:Dictionary=_sink(); var lost:Dictionary=_sink()
		var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var n:PackedVector3Array=a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
		var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
		var colors:PackedColorArray=a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
		var tangents:PackedFloat32Array=a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
		var uv2:PackedVector2Array=a[Mesh.ARRAY_TEX_UV2] if a[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
		var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var count:int=ix.size() if not ix.is_empty() else v.size()
		for i:int in range(0,count,3):
			var poly:Array=[]
			for j:int in 3:
				var k:int=ix[i+j] if not ix.is_empty() else i+j
				var tangent=Vector4(tangents[k*4],tangents[k*4+1],tangents[k*4+2],tangents[k*4+3]) if not tangents.is_empty() else Vector4(1,0,0,1)
				poly.append([v[k],n[k] if not n.is_empty() else Vector3.UP,uv[k] if not uv.is_empty() else Vector2.ZERO,colors[k] if not colors.is_empty() else Color.WHITE,tangent,uv2[k] if not uv2.is_empty() else Vector2.ZERO])
			var pieces:Array=[poly]
			for brush:AABB in brushes_by_surface[s]:
				var next:Array=[]
				for piece:Array in pieces:
					var clipped:Dictionary=_subtract(piece,brush,frame)
					next.append_array(clipped.outside)
					if not clipped.inside.is_empty(): _fan(lost,clipped.inside)
				pieces=next
			for piece:Array in pieces: _fan(kept,piece)
			if kept.v.size()+lost.v.size()>MAX_OUTPUT_VERTICES: return {"ok":false,"reason":"output_budget"}
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_arrays(kept,not uv.is_empty(),not colors.is_empty(),not tangents.is_empty(),not uv2.is_empty()))
		output.surface_set_material(s,material)
		if not lost.v.is_empty():
			removed_faces+=lost.v.size()/3
			removed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_arrays(lost,not uv.is_empty(),not colors.is_empty(),not tangents.is_empty(),not uv2.is_empty()))
			removed.surface_set_material(removed.get_surface_count()-1,material)
			removed_surfaces.append(s)
	return {"ok":true,"mesh":output,"removed":removed,"removed_triangles":removed_faces,"removed_surfaces":removed_surfaces}
