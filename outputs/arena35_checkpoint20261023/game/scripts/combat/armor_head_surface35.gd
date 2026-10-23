extends RefCounted
## A finite incoming coverage segment ends at actual skin, never at the far cap.
var _faces:Dictionary={}
var last:Dictionary={}

func coverage(host:Node,point:Vector3,velocity:Vector3,normal:Vector3)->Dictionary:
	var visual:Node=host.get("_npc_armor_visual31")
	if not is_instance_valid(visual):return {"known":false}
	var roots:Dictionary=visual.get("_roots")
	if not roots.has("head"):return {"known":true,"covered":false}
	var direction:=velocity.normalized() if velocity.length_squared()>1e-12 else -normal.normalized()
	if direction.length_squared()<.5:return {"known":false}
	var from:=point-direction*.45
	var to:=point+direction*.0001
	var stack:Array[Node]=[]
	for anchor:Node in roots.head:
		if is_instance_valid(anchor):stack.append(anchor)
	var candidates:=0
	while not stack.is_empty():
		var node:Node=stack.pop_back()
		for child:Node in node.get_children():stack.append(child)
		if not node is MeshInstance3D or node.mesh==null or not node.is_visible_in_tree():continue
		var a:Vector3=node.to_local(from);var b:Vector3=node.to_local(to)
		if node.mesh.get_aabb().grow(.00001).intersects_segment(a,b)==null:continue
		var id:int=node.mesh.get_instance_id()
		if not _faces.has(id):
			if _faces.size()>96:_faces.clear()
			_faces[id]={"mesh":node.mesh,"faces":node.mesh.get_faces()}
		var triangles:PackedVector3Array=_faces[id].faces
		for i in range(0,triangles.size(),3):
			candidates+=1
			if Geometry3D.segment_intersects_triangle(a,b,triangles[i],triangles[i+1],triangles[i+2])!=null:
				last={"known":true,"covered":true,"mesh":str(node.name),"triangles":candidates};return last
	last={"known":true,"covered":false,"triangles":candidates};return last
