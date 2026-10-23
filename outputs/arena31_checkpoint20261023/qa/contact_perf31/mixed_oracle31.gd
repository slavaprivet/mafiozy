extends SceneTree
const Exact=preload("res://scripts/combat/segment_triangle29.gd")
const Mixed=preload("res://scripts/combat/contact_mixed_bvh31.gd")
var out:String
var checks:Dictionary={}
var cases:Array=[]
var errors:Array=[]
var ray_count:=0
var hit_count:=0
var max_point_error:=0.0
var max_normal_error:=0.0
var whole_triangles:=0
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 create_timer(120).timeout.connect(func():quit(2))
 run.call_deferred()
# Independent exhaustive skinning. No mixed helper, BVH bounds, cached posed
# vertices, topology partition or solid query is used to compute expected hits.
func vertices(data:Dictionary,binds:Array[Transform3D],matrix:Transform3D)->PackedVector3Array:
 var result:=PackedVector3Array()
 for i in data.points.size():
  var p:=Vector3.ZERO;var total:=0.0
  for slot in 4:
   var k:int=i*4+slot
   if k>=data.weights.size() or k>=data.bones.size():continue
   var weight:float=data.weights[k];var bone:int=data.bones[k]
   if weight<=0.0 or bone<0 or bone>=binds.size():continue
   p+=(binds[bone]*Vector3(data.points[i]))*weight;total+=weight
  result.append(matrix*(p if total>0.0 else Vector3(data.points[i])))
 return result
func expected(points:PackedVector3Array,group:Dictionary,a:Vector3,b:Vector3)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var length_squared:=a.distance_squared_to(b)
 if length_squared<=0.:return result
 for triangle in group.orders.size():
  var x:=points[group.indices[triangle*3]];var y:=points[group.indices[triangle*3+1]];var z:=points[group.indices[triangle*3+2]]
  var point:Variant=Exact.intersect(a,b,x,y,z)
  if point==null:continue
  var normal:Vector3=(y-x).cross(z-x).normalized()
  if normal.length_squared()<.5:continue
  if normal.dot(b-a)>0:normal=-normal
  result.append({"position":point,"normal":normal,"fraction":sqrt(a.distance_squared_to(point)/length_squared),"order":group.orders[triangle],"face":group.orders[triangle]})
 return result
func sorted_hits(values:Array[Dictionary])->Array[Dictionary]:
 values.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.fraction<b.fraction if a.fraction!=b.fraction else int(a.order)<int(b.order))
 return values
func fail(label:String,ray:Array,a:Variant,b:Variant,reason:String):
 if errors.size()<40:errors.append({"case":label,"ray":ray,"expected":a,"actual":b,"reason":reason})
func compare(label:String,tree:RefCounted,points:PackedVector3Array,group:Dictionary,ray:Array):
 ray_count+=1
 var a:=sorted_hits(expected(points,group,ray[0],ray[1]))
 var b:=sorted_hits(tree.intersections(ray[0],ray[1],true))
 if a.size()!=b.size():fail(label,ray,a,b,"all_count");return
 for i in a.size():
  hit_count+=1
  var pe:float=Vector3(a[i].position).distance_to(b[i].position)
  var ne:float=Vector3(a[i].normal).distance_to(b[i].normal)
  max_point_error=maxf(max_point_error,pe);max_normal_error=maxf(max_normal_error,ne)
  if pe>.000002 or ne>.00001 or a[i].order!=b[i].order or a[i].face!=b[i].face:fail(label,ray,a[i],b[i],"all_primitive")
 var nearest:Array[Dictionary]=tree.intersections(ray[0],ray[1],false)
 if a.is_empty()!=nearest.is_empty():fail(label,ray,a,nearest,"nearest_count")
 elif not a.is_empty() and (nearest[0].order!=a[0].order or Vector3(nearest[0].position).distance_to(a[0].position)>.000002):fail(label,ray,a[0],nearest[0],"nearest_order")
func rays_for(points:PackedVector3Array,group:Dictionary,limit:int=4)->Array:
 var rays:Array=[]
 for triangle in range(0,group.orders.size(),maxi(1,group.orders.size()/limit)):
  var a:=points[group.indices[triangle*3]];var b:=points[group.indices[triangle*3+1]];var c:=points[group.indices[triangle*3+2]]
  var normal:Vector3=(b-a).cross(c-a).normalized()
  if normal.length_squared()<.5:continue
  var centre:Vector3=(a+b+c)/3.
  rays.append([centre-normal*.05,centre+normal*.05])
  rays.append([centre-normal*.00001,centre+normal*.00001])
  rays.append([a-normal*.001,a+normal*.001])
  rays.append([(a+b)*.5-normal*.001,(a+b)*.5+normal*.001])
  if rays.size()>=limit*4:break
 rays.append([Vector3(91,82,73),Vector3(91.1,82.1,73.1)])
 return rays
func exercise(label:String,data:Dictionary,group:Dictionary,poses:Array,matrices:Array,limit:int=4):
 var prototype:=Mixed.new();prototype.build(data,group,poses[0].size())
 var actor_a:RefCounted=prototype.instantiate_pose31();var actor_b:RefCounted=prototype.instantiate_pose31()
 var before:=errors.size();var start:=ray_count
 for state in poses.size():
  var binds:Array[Transform3D]=[];binds.assign(poses[state])
  var matrix:Transform3D=matrices[state]
  actor_a.set_pose(binds,matrix)
  var posed:=vertices(data,binds,matrix);var rays:=rays_for(posed,group,limit)
  for ray:Array in rays:compare(label+":"+str(state),actor_a,posed,group,ray)
  var cached:int=actor_a.posed_vertices
  actor_a.set_pose(binds,matrix)
  for ray:Array in rays:compare(label+":repeat",actor_a,posed,group,ray)
  if int(actor_a.posed_vertices)!=cached:fail(label,[],cached,actor_a.posed_vertices,"same_pose_reskinned")
  var other_matrix:=Transform3D(Basis(Vector3.UP,.37),Vector3(3.2,.4,-1.)) * matrix
  actor_b.set_pose(binds,other_matrix)
  var other:=vertices(data,binds,other_matrix)
  for ray:Array in rays_for(other,group,1):compare(label+":actorB",actor_b,other,group,ray)
  for ray:Array in rays.slice(0,2):compare(label+":actorA_afterB",actor_a,posed,group,ray)
 cases.append({"label":label,"triangles":group.orders.size(),"rays":ray_count-start,"new_errors":errors.size()-before,"a_posed_vertices":actor_a.posed_vertices,"b_posed_vertices":actor_b.posed_vertices})
 whole_triangles+=group.orders.size()
func synthetic():
 var data:Dictionary={"points":PackedVector3Array(),"bones":PackedInt32Array(),"weights":PackedFloat32Array()}
 var group:Dictionary={"indices":PackedInt32Array(),"orders":PackedInt32Array()}
 for triangle in 20:
  var centre:=Vector3(float(triangle%5)*.12,float(triangle/5)*.14,0.)
  for corner:Vector3 in [Vector3(-.05,-.05,0),Vector3(.05,-.05,0),Vector3(0,.05,0)]:
   var vertex:int=data.points.size();data.points.append(centre+corner)
   data.bones.append_array(PackedInt32Array([0,1,9,-1]))
   var weights:=PackedFloat32Array([.3,.7,0.,0.])
   match triangle%5:
    1:weights=PackedFloat32Array([.2,.4,.8,-.2]) # Non-normalized valid weights, invalid influences.
    2:weights=PackedFloat32Array([0.,0.,1.,0.]) # Entirely unbound after invalid-bind filtering.
    3:weights=PackedFloat32Array([1.2,.2,0.,0.])
    4:weights=PackedFloat32Array([1.,0.,0.,0.])
   if triangle==17:weights=PackedFloat32Array([.3,.69999,0.,0.])
   if triangle==18:weights=PackedFloat32Array([.3,.70001,0.,0.])
   if triangle==19:weights=PackedFloat32Array([NAN,.5,0.,0.])
   data.weights.append_array(weights);group.indices.append(vertex)
  group.orders.append(triangle)
 # Coincident distinct primitives exercise deterministic legacy traversal ties.
 group.indices.append_array(PackedInt32Array([0,1,2]));group.orders.append(20)
 var a:Array[Transform3D]=[Transform3D.IDENTITY,Transform3D.IDENTITY]
 var b:Array[Transform3D]=[Transform3D(Basis(Vector3.RIGHT,.17),Vector3(.02,0,.03)),Transform3D(Basis(Vector3.UP,-.27),Vector3(-.02,.03,-.01))]
 var c:Array[Transform3D]=[Transform3D(Basis(Vector3.FORWARD,.1),Vector3(.1,.1,0))] # Changed bindcount exact fallback.
 var far:Array[Transform3D]=[Transform3D(Basis.IDENTITY,Vector3(-5000,3000,2000)),Transform3D(Basis.IDENTITY,Vector3(-5000,3000,2000))]
 var shear:=Transform3D(Basis(Vector3(1,.1,0),Vector3(.2,1,0),Vector3(0,.15,1)),Vector3(.2,.1,.3))
 exercise("synthetic_mixed_abnormal_unbound_duplicates",data,group,[a,b,c,far,b],[Transform3D.IDENTITY,Transform3D(Basis.from_scale(Vector3(1.2,.8,1.1)),Vector3(.4,.2,-.3)),Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3(5000,-3000,-2000)),shear],8)
func surface_data(node:MeshInstance3D,surface:int,rig:Skeleton3D)->Dictionary:
 var arrays:Array=node.mesh.surface_get_arrays(surface)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
 if indices.is_empty():
  for i in points.size():indices.append(i)
 var groups:Dictionary={}
 for offset in range(0,indices.size(),3):
  var winner:=-1;var best:=0.;var vertex:int=indices[offset]
  for slot in 4:
   var k:int=vertex*4+slot
   if k<weights.size() and k<bones.size() and weights[k]>best and bones[k]>=0 and bones[k]<node.skin.get_bind_count():
    best=weights[k];winner=node.skin.get_bind_bone(bones[k])
    if winner<0:winner=rig.find_bone(node.skin.get_bind_name(bones[k]))
  if not groups.has(winner):groups[winner]=PackedInt32Array()
  groups[winner].append_array(indices.slice(offset,offset+3))
 var group:Dictionary={"indices":PackedInt32Array(),"orders":PackedInt32Array()}
 for list:PackedInt32Array in groups.values():
  group.indices.append_array(list)
 for i in int(group.indices.size()/3):group.orders.append(i)
 return {"data":{"points":points,"bones":bones,"weights":weights},"group":group}
func actual_surfaces(host:Node,label:String):
 var rig:Skeleton3D=host._npc_rig
 var nodes:Array=host._solid_weapon29._skin_nodes(host)
 var saved:Array[Transform3D]=[]
 for bone in rig.get_bone_count():saved.append(rig.get_bone_pose(bone))
 var inspected:=0
 for node:MeshInstance3D in nodes:
  if not node.is_visible_in_tree() or node.skin==null:continue
  for surface in node.mesh.get_surface_count():
   if (node.mesh.surface_get_format(surface)&Mesh.ARRAY_FORMAT_BONES)==0:continue
   var input:=surface_data(node,surface,rig)
   if input.group.orders.is_empty():continue
   var first:Array[Transform3D]=host._cut_skin_transforms39(node)
   for name:String in ["chest","upperarm_l","thigh_r"]:
    var index:=rig.find_bone(name)
    if index>=0:rig.set_bone_pose_rotation(index,Quaternion(Vector3.UP,.23)*saved[index].basis.get_rotation_quaternion())
   rig.force_update_all_bone_transforms()
   var second:Array[Transform3D]=host._cut_skin_transforms39(node)
   for bone in saved.size():rig.set_bone_pose(bone,saved[bone])
   rig.force_update_all_bone_transforms()
   var changed:=Transform3D(Basis(Vector3.FORWARD,.12).scaled(Vector3(.9,1.1,1.05)),Vector3(.11,-.07,.09))*node.global_transform
   exercise(label+":"+str(node.name)+":"+str(surface),input.data,input.group,[first,second,first],[node.global_transform,node.global_transform,changed],3)
   inspected+=1
 checks[label+"_actual_surfaces"]=inspected>0
 cases.append({"label":label,"surfaces":inspected})
func run():
 root.size=Vector2i(1280,720)
 synthetic()
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 for i in 600:
  await process_frame
  if scene.get("lab_ready")==true:break
 checks.startup=scene.get("lab_ready")==true
 if checks.startup:
  var host:Node=scene.lab;host.lab_regrow=false
  scene.process_mode=Node.PROCESS_MODE_DISABLED
  actual_surfaces(host,"actual_uncut")
  scene.process_mode=Node.PROCESS_MODE_INHERIT;scene._lab_equip(0)
  for i in 5:await physics_frame
  var rig:Skeleton3D=host._npc_rig
  var at:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin-Vector3.UP*.12
  var before:int=host.clay_cuts
  checks.actual_cut_queued=host._clay_queue_slice28("chest",at,Vector3.RIGHT*6.,6.)
  for i in 600:
   await physics_frame;await create_timer(0).timeout
   if host.clay_cuts>before:break
  checks.actual_cut_committed=host.clay_cuts==before+1
  scene.process_mode=Node.PROCESS_MODE_DISABLED
  actual_surfaces(host,"actual_postcut")
 checks.exhaustive_all_hit_count_position_normal_face_order=errors.is_empty()
 checks.nontrivial_ray_coverage=ray_count>500 and hit_count>100
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rays":ray_count,"hits":hit_count,"surface_triangles":whole_triangles,"max_point_error_m":max_point_error,"max_normal_error":max_normal_error,"errors":errors,"cases":cases,"scope":"Independent exhaustive exact weighted vertices and triangle traversal; same final robust Segment primitive; no optimized bounds or posed cache used as expected results. Real skinned surfaces before/after actual API cut, real bone pose changes, node matrices, seams, misses, abnormal/unbound weights, duplicate order and two independent actor pose objects."},"  "))
 current_scene=null;scene.queue_free()
 for i in 4:await process_frame
 quit(0 if not checks.values().has(false) else 1)
