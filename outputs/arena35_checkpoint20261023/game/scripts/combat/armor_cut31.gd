extends RefCounted
## Rigid fittings share the actual cut and the body's single debris lifecycle.
const Sever=preload("res://scripts/weapons/mesh_sever.gd")
var surfaces:Dictionary={}
var originals:Dictionary={}

func warm(owner:Node)->void:
	for key in surfaces.keys():
		if surfaces[key].ref.get_ref()==null:surfaces.erase(key)
	for anchors:Array in owner._roots.values():
		for anchor:Node in anchors:
			for node:Node in anchor.find_children("*","MeshInstance3D",true,false):
				if node.skin==null and node.mesh!=null:_arrays(node.mesh)

func _arrays(mesh:Mesh)->Array:
	var id:=mesh.get_instance_id()
	if surfaces.has(id) and surfaces[id].ref.get_ref()==mesh:return surfaces[id].arrays
	var arrays:Array=[]
	for i in mesh.get_surface_count():arrays.append(mesh.surface_get_arrays(i))
	surfaces[id]={"ref":weakref(mesh),"arrays":arrays}
	return arrays

func snapshot(owner:Node,context:Dictionary,branches:Dictionary)->Dictionary:
	var inputs:Array=[];var metadata:Array=[]
	var plane:Plane=context.plane
	for anchors:Array in owner._roots.values():
		for anchor:Node in anchors:
			var bone:=str(anchor.get_meta("armor_bone",""))
			var mode:=""
			if context.scope=="_clay_torso":
				var branch_match:=false
				for branch:String in branches:
					if bone==branch or owner._is_descendant(bone,branch):
						branch_match=true
						if branches[branch]:mode="whole"
						break
				if not branch_match:mode="clip"
			elif bone==context.scope or owner._is_descendant(bone,context.scope):mode="whole" if context.head_gone else "clip"
			if mode.is_empty():continue
			for node:MeshInstance3D in anchor.find_children("*","MeshInstance3D",true,false):
				if node.mesh==null or node.skin!=null or not node.is_visible_in_tree():continue
				var t:=node.global_transform
				var local_n:Vector3=(t.basis.transposed()*plane.normal).normalized()
				var local_point:Vector3=t.affine_inverse()*(plane.normal*plane.d)
				var local_plane:=Plane(local_n,local_n.dot(local_point))
				var mats:Array=[]
				for i in node.mesh.get_surface_count():mats.append(node.get_active_material(i))
				metadata.append({"node":weakref(node),"source":node.mesh,"materials":mats,"transform":t})
				inputs.append({"index":metadata.size()-1,"surfaces":_arrays(node.mesh),"plane":local_plane,"keep_front":plane.distance_to(context.keep)>=0.,"whole":mode=="whole"})
	return {"inputs":inputs,"metadata":metadata}

static func build(inputs:Array)->Array:
	var result:Array=[]
	for input:Dictionary in inputs:
		var kept:Array=[];var gone:Array=[];var ki:Array=[];var gi:Array=[]
		if input.whole:
			gone=input.surfaces
			for i in gone.size():gi.append(i)
		else:
			var cut=Sever.cut_surfaces28(input.surfaces,input.plane)
			kept=cut.front_arrays if input.keep_front else cut.back_arrays
			gone=cut.back_arrays if input.keep_front else cut.front_arrays
			ki=cut.front_surface_indices if input.keep_front else cut.back_surface_indices
			gi=cut.back_surface_indices if input.keep_front else cut.front_surface_indices
			if gone.is_empty():continue
			var kept_cap:Array=cut.front_cap_arrays if input.keep_front else cut.back_cap_arrays
			var gone_cap:Array=cut.back_cap_arrays if input.keep_front else cut.front_cap_arrays
			if not kept_cap.is_empty():kept.append(kept_cap);ki.append(0)
			if not gone_cap.is_empty():gone.append(gone_cap);gi.append(0)
		result.append({"index":input.index,"kept":kept,"gone":gone,"kept_indices":ki,"gone_indices":gi})
	return result

static func stage(layers:Array,metadata:Array,operations:Array)->void:
	for layer:Dictionary in layers:
		for side:String in ["kept","gone"]:
			layer[side+"_mesh"]=ArrayMesh.new()
			for i in layer[side].size():operations.append({"mesh":layer[side+"_mesh"],"arrays":layer[side][i],"material":metadata[layer.index].materials[layer[side+"_indices"][i]]})

static func valid(metadata:Array)->bool:
	for row:Dictionary in metadata:
		var node:MeshInstance3D=row.node.get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or node.mesh!=row.source or node.skin!=null:return false
	return true

func commit(layers:Array,metadata:Array,body:Node3D)->Dictionary:
	var moved:=0;var split:=0
	for layer:Dictionary in layers:
		var row:Dictionary=metadata[layer.index]
		var node:MeshInstance3D=row.node.get_ref()
		var id:=node.get_instance_id()
		if not originals.has(id):originals[id]={"node":weakref(node),"mesh":node.mesh,"visible":node.visible,"override":node.material_override}
		var gone:=MeshInstance3D.new();gone.name="DetachedArmorFitting31";gone.mesh=layer.gone_mesh
		gone.cast_shadow=node.cast_shadow;body.add_child(gone);gone.global_transform=node.global_transform
		gone.set_meta("armor_cut_source31",str(node.name))
		gone.set_meta("armor_cut_source_id31",id)
		node.material_override=null
		for i in node.mesh.get_surface_count():node.set_surface_override_material(i,null)
		node.mesh=null if layer.kept.is_empty() else layer.kept_mesh
		node.visible=not layer.kept.is_empty()
		node.set_meta("armor_cut_processed31",true)
		if node.mesh!=null:node.set_meta("armor_cut_retained31",node.mesh.get_instance_id())
		if not layer.kept.is_empty():split+=1
		moved+=1
	return {"detached":moved,"split":split}

func restore()->void:
	for row:Dictionary in originals.values():
		var node:MeshInstance3D=row.node.get_ref()
		if not is_instance_valid(node):continue
		node.mesh=row.mesh;node.visible=row.visible;node.material_override=row.override
		node.remove_meta("armor_cut_processed31")
		if node.has_meta("armor_cut_retained31"):node.remove_meta("armor_cut_retained31")
	originals.clear()

func synchronous(owner:Node,context:Dictionary,branches:Dictionary,body:Node3D)->Dictionary:
	var data:=snapshot(owner,context,branches)
	var layers:=build(data.inputs);var operations:Array=[]
	stage(layers,data.metadata,operations)
	for op:Dictionary in operations:
		op.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,op.arrays)
		op.mesh.surface_set_material(op.mesh.get_surface_count()-1,op.material)
	return commit(layers,data.metadata,body) if valid(data.metadata) else {"failure":"source_changed"}
