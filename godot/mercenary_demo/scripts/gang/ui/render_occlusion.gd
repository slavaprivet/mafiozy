extends RefCounted
## Actual visible render triangles; collider proxies do not define visibility.
## Scene owner supplies roots or bounded indexed segment candidates.
var _roots:Array=[]
var _cache:Dictionary={}
var candidate_provider:Callable
var queries:int=0
var triangle_tests:int=0
var unknown_shader_materials:int=0

func set_roots(roots:Array)->void:
	_roots.clear();_cache.clear()
	for root:Node3D in roots:
		if is_instance_valid(root):_roots.append(weakref(root))

func _ignored(node:Node3D,actors:Array)->bool:
	var p:Node=node
	while p!=null:
		if p is Node3D and (not p.visible or p.get_meta("mercenaryPickIgnore",false) or p.get_meta("isHero",false)):return true
		if p in actors:return true
		p=p.get_parent()
	return not node.is_inside_tree()

func _material_blocks(material:Material,node:MeshInstance3D)->bool:
	if material==null:return false
	if material is BaseMaterial3D:
		return material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED or material.albedo_color.a>=.8
	if material is ShaderMaterial:
		# Custom shaders require an explicit owner visibility/opacity descriptor.
		if not node.has_meta("walk_render_opacity"):unknown_shader_materials+=1;return true
		return float(node.get_meta("walk_render_opacity"))>=.8
	return true

func _triangles(node:MeshInstance3D)->Array:
	var id:int=node.get_instance_id()
	if _cache.has(id) and _cache[id].node.get_ref()==node and _cache[id].mesh==node.mesh:return _cache[id].surfaces
	var surfaces:Array=[]
	for surface:int in node.mesh.get_surface_count():
		if node.mesh is ArrayMesh and node.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:continue
		var arrays:Array=node.mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:Variant=arrays[Mesh.ARRAY_INDEX]
		var faces=PackedVector3Array()
		if indices!=null and indices.size()>0:
			for index:int in indices:faces.append(vertices[index])
		else:faces=vertices
		surfaces.append({"surface":surface,"faces":faces})
	_cache[id]={"node":weakref(node),"mesh":node.mesh,"surfaces":surfaces};return surfaces

func _mesh_blocks(node:MeshInstance3D,origin:Vector3,end:Vector3,actors:Array)->bool:
	if node.mesh==null or _ignored(node,actors):return false
	var frame:Transform3D=node.global_transform
	if absf(frame.basis.determinant())<.0000001:return false
	var inverse:Transform3D=frame.affine_inverse();var a:Vector3=inverse*origin;var b:Vector3=inverse*end
	if not node.get_aabb().intersects_segment(a,b):return false
	for surface:Dictionary in _triangles(node):
		if not _material_blocks(node.get_active_material(surface.surface),node):continue
		var faces:PackedVector3Array=surface.faces
		for i:int in range(0,faces.size(),3):
			triangle_tests+=1
			if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2])!=null:return true
	return false

func _root_blocks(root:Node3D,origin:Vector3,end:Vector3,actors:Array)->bool:
	if _ignored(root,actors):return false
	if root is MeshInstance3D and _mesh_blocks(root,origin,end,actors):return true
	for child:Node in root.get_children():
		if child is Node3D and _root_blocks(child,origin,end,actors):return true
	return false

func occluded(origin:Vector3,head:Vector3,actors:Array)->bool:
	queries+=1;var delta:Vector3=head-origin;var distance:float=delta.length()
	if distance<=.15:return false
	var direction:Vector3=delta/distance;var end:Vector3=origin+direction*(distance-.15)
	var roots:Array=[]
	if candidate_provider.is_valid():roots=candidate_provider.call(origin,direction,distance-.15)
	else:
		for ref:WeakRef in _roots:
			var root:Variant=ref.get_ref()
			if is_instance_valid(root):roots.append(root)
	for root:Node3D in roots:
		if is_instance_valid(root) and _root_blocks(root,origin,end,actors):return true
	return false

func dispose()->void:
	_roots.clear();_cache.clear();candidate_provider=Callable()
