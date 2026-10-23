extends RefCounted
## Exact nearest-surface search over immutable startup/worker BVHs.
## Actor-local poses only; this helper never builds topology during an injury.
const Puncture=preload("res://scripts/combat/puncture29.gd")
var _poses:Dictionary={}
var last:Dictionary={}

func clear()->void:_poses.clear()

static func _box_distance_squared(point:Vector3,box:AABB)->float:
 var q:=point.clamp(box.position,box.end)
 return point.distance_squared_to(q)

static func _belongs(data:Dictionary,face:Vector3i,relevant:Dictionary)->bool:
 for vertex in [face.x,face.y,face.z]:
  for slot in 4:
   var k:int=vertex*4+slot
   if k<data.weights.size() and data.weights[k]>.05 and relevant.has(data.bones[k]):return true
 return false

static func _vertex(data:Dictionary,vertex:int,binds:Array[Transform3D],frame:Transform3D,posed:Dictionary)->Vector3:
 if posed.has(vertex):return posed[vertex]
 var position:=Vector3.ZERO;var total:=0.
 for slot in 4:
  var k:int=vertex*4+slot
  if k>=data.weights.size() or data.weights[k]<=0. or data.bones[k]<0 or data.bones[k]>=binds.size():continue
  position+=(binds[data.bones[k]]*data.points[vertex])*data.weights[k];total+=data.weights[k]
 var result:Vector3=frame*(position if total>0. else data.points[vertex])
 posed[vertex]=result
 return result

func nearest(host:Node,nodes:Array[MeshInstance3D],point:Vector3,part:String,closest:Callable)->Dictionary:
 var begun:=Time.get_ticks_usec()
 var best:Dictionary={};var distance:=.075;var live:Dictionary={}
 var visited:=0;var tested:=0;var vertex_count:=0;var source_count:=0
 for node:MeshInstance3D in nodes:
  if node.mesh==null or not node.is_visible_in_tree():continue
  var binds:Array[Transform3D]=host.call("_cut_skin_transforms39",node)
  var relevant:Dictionary=host.call("_npc_limb_bind_ids",node,part)
  if relevant.is_empty():continue
  var surfaces:Array=Puncture._topology(host,node)
  for data:Dictionary in surfaces:
   if not data.has("solid_bind31") or not data.has("entry_source_orders33"):
    last={"fallback":true,"reason":"cold_topology"};return {"fallback33":true}
   var partition:Dictionary=data.solid_bind31
   if int(partition.bind_count)!=binds.size():
    last={"fallback":true,"reason":"bind_count"};return {"fallback33":true}
   var views:Array=[]
   for view:Dictionary in partition.rigid:views.append({"prototype":view.tree,"mixed":false,"bind":view.bind})
   for group:Dictionary in partition.mixed:views.append({"prototype":group.mixed_tree31,"mixed":true})
   var frame:Transform3D=node.global_transform
   var posed:Dictionary={};var candidates:Dictionary={}
   for view:Dictionary in views:
    var prototype:RefCounted=view.prototype
    var key:Array=[node.get_instance_id(),prototype.get_instance_id()]
    live[key]=true
    if not _poses.has(key):_poses[key]=prototype.instantiate_pose31()
    var tree:RefCounted=_poses[key]
    var mixed:bool=view.mixed
    if mixed:tree.set_pose(binds,frame)
    else:tree.set_transform(frame*(binds[view.bind] if view.bind>=0 else Transform3D.IDENTITY))
    if tree.left.is_empty():continue
    var stack:Array[int]=[0]
    while not stack.is_empty():
     var branch:int=stack.pop_back();visited+=1
     if mixed:
      if tree._leaf_ready[branch]!=0:
       if tree._leaf_finite[branch]!=0 and _box_distance_squared(point,tree._leaf_boxes[branch])>distance*distance:continue
      elif tree.safe[branch]!=0 and binds.size()==tree.bind_count and _box_distance_squared(point,tree._bounds(branch))>distance*distance:continue
     elif _box_distance_squared(point,tree.transform*tree.bounds[branch])>distance*distance:continue
     if tree.left[branch]>=0:
      stack.append(tree.right[branch]);stack.append(tree.left[branch]);continue
     if mixed:
      tree._prepare_leaf(branch)
      if tree._leaf_finite[branch]!=0 and _box_distance_squared(point,tree._leaf_boxes[branch])>distance*distance:continue
     for cursor in range(tree.first[branch],tree.first[branch]+tree.count[branch]):
      var tri:int=tree.sequence[cursor]
      if mixed:
       if tree._triangle_finite[tri]!=0 and _box_distance_squared(point,tree._triangle_boxes[tri])>distance*distance:continue
      elif _box_distance_squared(point,tree.transform*tree._triangle_bounds[tri])>distance*distance:continue
      var order:int=tree.orders[tri]
      # Preserve the exact original triangle traversal order even though the
      # shared BVH groups and spatially sorts faces by a different order.
      candidates[int(data.entry_source_orders33[order])]=order
   var ordered:Array=candidates.keys();ordered.sort()
   for original:int in ordered:
    var face:Vector3i=data.entry_faces31[candidates[original]]
    if not _belongs(data,face,relevant):continue
    var a:=_vertex(data,face.x,binds,frame,posed)
    var b:=_vertex(data,face.y,binds,frame,posed)
    var c:=_vertex(data,face.z,binds,frame,posed)
    tested+=1
    var near:Vector3=closest.call(point,a,b,c)
    var d:=near.distance_to(point)
    if d<distance:
     var normal:Vector3=(b-a).cross(c-a).normalized()
     if normal.length_squared()<.5:continue
     distance=d;best={"point":near,"normal":normal,"distance":d}
   vertex_count+=posed.size();source_count+=1
 for key:Array in _poses.keys():
  if not live.has(key):_poses.erase(key)
 last={"fallback":false,"sources":source_count,"visited":visited,"tested":tested,"posed_vertices":vertex_count,"usec":Time.get_ticks_usec()-begun}
 return best
