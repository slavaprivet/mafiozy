extends SceneTree
const Solid=preload("res://scripts/combat/weapon_solid_contact29.gd")
var checks:Dictionary={}
func _initialize():run.call_deferred()
func run():
 var out:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 var solid=Solid.new()
 var points:=PackedVector3Array([Vector3(-.05,-.04,.019527),Vector3(.05,-.04,.019527),Vector3(.05,.04,.019527),Vector3(-.05,-.04,.019527),Vector3(.05,-.04,.019527),Vector3(.05,.04,.019527)])
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var node:=MeshInstance3D.new();node.mesh=mesh;root.add_child(node)
 var data:Dictionary={"points":points,"bones":PackedInt32Array(),"weights":PackedFloat32Array(),"entry_faces31":[Vector3i(0,1,2),Vector3i(3,4,5)]}
 var source:Dictionary={"node":weakref(node),"mesh_id":mesh.get_instance_id(),"skin_id":0,"data":data,"binds":[],"transform":Transform3D.IDENTITY}
 solid._surface_sources31={"test_surface":source}
 var collar:Dictionary={"source_key":"test_surface","mesh_id":mesh.get_instance_id(),"skin_id":0,"patch":{0:true},"normal_sign":1.,"generation":7,"weapon_instance_id":12}
 var channel:Dictionary={"entry_collar31":collar,"weapon":"spear","actual_hit":true,"cut_depth":.20,"generation":7,"weapon_instance_id":12}
 var point:=Vector3(.036557,.007182,.019527)
 var hit:Dictionary={"source_key":"test_surface","face":0}
 checks.actual_posed_entry_triangle=solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,hit)
 checks.nearby_disconnected_triangle_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,{"source_key":"test_surface","face":1})
 checks.unrelated_mesh_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,{"source_key":"other_surface","face":0})
 channel.cut_depth=0.
 checks.verified_tip_preview_admits_actual_entry_triangle=solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,hit)
 channel.actual_hit=false
 checks.unverified_preview_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,hit)
 channel.actual_hit=true;channel.cut_depth=.20
 checks.front_exterior_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point+Vector3(0,0,.001),point,hit)
 checks.non_surface_point_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point+Vector3(0,0,.001),point+Vector3(0,0,.001),hit)
 checks.bounded_collar_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point+Vector3(0,0,.006),point+Vector3(0,0,.006),hit)
 channel.generation=8;checks.stale_generation_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,hit);channel.generation=7
 collar.normal_sign=-1.;checks.opposite_entry_face_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,hit);collar.normal_sign=1.
 node.mesh=mesh.duplicate();checks.replaced_mesh_rejected=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,hit)
 channel.weapon="sword"
 node.mesh=mesh
 checks.sword_collar_limit_unchanged=not solid._entry_surface_collar31(channel,Transform3D.IDENTITY,point,point,hit)
 var passed:bool=not checks.values().has(false)
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Focused exact posed ArrayMesh collar geometry/property oracle. No native wound/input claim; strict600 real input is separate."},"  "))
 node.queue_free();await process_frame;quit(0 if passed else 1)
