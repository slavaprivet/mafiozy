extends RefCounted
## Exact current authored weapon surfaces. No invisible guard capsule or timer.
const Segment=preload("res://scripts/combat/segment_triangle29.gd")
const LEAF_SIZE:=8
static func eligible(host:Node)->bool:
 var weapon:Node3D=host.get("_sword")
 return str(host.get("_weapon_id")) in ["sword","spear","mace","axe","sledge"] and bool(host.get("_selected")) and not bool(host.get("_unarmed")) and not bool(host.get("_sword_grounded")) and not bool(host.get("_throwing")) and is_instance_valid(weapon) and weapon.is_visible_in_tree()
static func _parts(weapon:Node3D)->Array:
 var cached:Dictionary=weapon.get_meta("interception_parts31",{})
 if cached.get("children",-1)==weapon.get_child_count():return cached.rows
 var rows:Array=[]
 if weapon is MeshInstance3D:rows.append(weakref(weapon))
 for child in weapon.find_children("*","MeshInstance3D",true,false):rows.append(weakref(child))
 weapon.set_meta("interception_parts31",{"children":weapon.get_child_count(),"rows":rows})
 return rows
static func _mesh_data(mesh:Mesh)->Dictionary:
 var cached:Dictionary=mesh.get_meta("interception_geometry31",{})
 if not cached.is_empty():return cached
 var data:Dictionary={"triangles":[],"nodes":[],"points":PackedVector3Array(),"edges":PackedVector3Array()}
 var unique:Dictionary={};var edge_unique:Dictionary={}
 for surface in mesh.get_surface_count():
  var arrays:Array=mesh.surface_get_arrays(surface)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
  if indices.is_empty():
   for i in points.size():indices.append(i)
  for i in range(0,indices.size()-2,3):
   var a:Vector3=points[indices[i]];var b:Vector3=points[indices[i+1]];var c:Vector3=points[indices[i+2]]
   var normal:Vector3=(b-a).cross(c-a)
   if normal.length_squared()<=1e-20:continue
   var bounds:=AABB(a,Vector3.ZERO).expand(b).expand(c)
   var triangle:Dictionary={"a":a,"b":b,"c":c,"normal":normal.normalized(),"bounds":bounds,"surface":surface,"edge_ids":[]}
   data.triangles.append(triangle)
   for v:Vector3 in [a,b,c]:unique[v]=true
   for edge:Array in [[a,b],[b,c],[c,a]]:
    var key:Array=edge if edge[0]<edge[1] else [edge[1],edge[0]]
    if not edge_unique.has(key):edge_unique[key]=edge_unique.size()
    triangle.edge_ids.append(edge_unique[key])
 for v:Vector3 in unique:data.points.append(v)
 for edge:Array in edge_unique:data.edges.append(edge[0]);data.edges.append(edge[1])
 var ids:Array=[]
 for i in data.triangles.size():ids.append(i)
 if not ids.is_empty():_build_node(data,ids)
 mesh.set_meta("interception_geometry31",data)
 return data
static func _build_node(data:Dictionary,ids:Array)->int:
 var bounds:AABB=data.triangles[ids[0]].bounds
 for id:int in ids:bounds=bounds.merge(data.triangles[id].bounds)
 var index:int=data.nodes.size();data.nodes.append({"bounds":bounds,"left":-1,"right":-1,"ids":[]})
 if ids.size()<=LEAF_SIZE:data.nodes[index].ids=ids;return index
 var axis:int=bounds.get_longest_axis_index()
 ids.sort_custom(func(a:int,b:int)->bool:return data.triangles[a].bounds.get_center()[axis]<data.triangles[b].bounds.get_center()[axis])
 var middle:int=ids.size()/2
 data.nodes[index].left=_build_node(data,ids.slice(0,middle))
 data.nodes[index].right=_build_node(data,ids.slice(middle))
 return index
static func _box_hit(box:AABB,from:Vector3,to:Vector3,limit:float)->bool:
 var lo:=0.0;var hi:=limit
 var difference:=to-from
 for axis in 3:
  var a:float=box.position[axis];var b:float=box.end[axis]
  if absf(difference[axis])<1e-15:
   if from[axis]<a-1e-8 or from[axis]>b+1e-8:return false
  else:
   var first:float=(a-from[axis])/difference[axis];var second:float=(b-from[axis])/difference[axis]
   lo=maxf(lo,minf(first,second));hi=minf(hi,maxf(first,second))
   if lo>hi+1e-8:return false
 return true
static func segment(weapon:Node3D,from:Vector3,to:Vector3)->Dictionary:
 if not is_instance_valid(weapon) or not weapon.is_visible_in_tree() or from.distance_squared_to(to)<=1e-20:return {}
 return _segment_prepared(_prepared(weapon),from,to)
static func _prepared(weapon:Node3D)->Array:
 var prepared:Array=[]
 for reference:WeakRef in _parts(weapon):
  var node:MeshInstance3D=reference.get_ref()
  if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():continue
  var data:=_mesh_data(node.mesh)
  if data.nodes.is_empty():continue
  prepared.append({"node":node,"data":data,"inverse":node.global_transform.affine_inverse(),"normal_basis":node.global_basis.inverse().transposed(),"axis":weapon.global_basis.x.normalized()})
 return prepared
static func _segment_prepared(prepared:Array,from:Vector3,to:Vector3)->Dictionary:
 var best:Dictionary={};var fraction:=1.0
 for part:Dictionary in prepared:
  var node:MeshInstance3D=part.node
  var data:Dictionary=part.data
  var inverse:Transform3D=part.inverse
  var local_from:=inverse*from;var local_to:=inverse*to
  var direction:=local_to-local_from;var length_squared:=direction.length_squared()
  if length_squared<=1e-20:continue
  var stack:Array[int]=[0]
  while not stack.is_empty():
   var branch:Dictionary=data.nodes[stack.pop_back()]
   if not _box_hit(branch.bounds,local_from,local_to,fraction):continue
   if int(branch.left)>=0:stack.append(branch.left);stack.append(branch.right);continue
   for id:int in branch.ids:
    var triangle:Dictionary=data.triangles[id]
    var point:Variant=Segment.intersect(local_from,local_to,triangle.a,triangle.b,triangle.c)
    if point==null:continue
    var t:float=clampf((Vector3(point)-local_from).dot(direction)/length_squared,0.,1.)
    if not best.is_empty() and t>=fraction:continue
    fraction=t
    var normal:Vector3=(Basis(part.normal_basis)*Vector3(triangle.normal)).normalized()
    if normal.dot(to-from)>0.:normal=-normal
    var material:Material=node.get_active_material(triangle.surface)
    var kind:="metal" if material is StandardMaterial3D and material.metallic>.5 else "wood"
    best={"point":from.lerp(to,t),"normal":normal,"fraction":t,"axis":part.axis,"material":kind,"mesh_instance":node.get_instance_id(),"surface":triangle.surface}
 return best
static func player_segment(host:Node,from:Vector3,to:Vector3)->Dictionary:
 if not eligible(host):return {}
 var hit:=segment(host.get("_sword"),from,to)
 if not hit.is_empty():host.set_meta("interception_contact31",{"point":hit.point,"material":hit.material,"frame":Engine.get_physics_frames()})
 return hit
static func warm(weapon:Node3D)->void:
 if not is_instance_valid(weapon):return
 for reference:WeakRef in _parts(weapon):
  var node:MeshInstance3D=reference.get_ref()
  if is_instance_valid(node) and node.mesh!=null:_mesh_data(node.mesh)
static func _bounds_at(weapon:Node3D,transform:Transform3D)->AABB:
 var result:=AABB();var first:=true
 var inverse:=weapon.global_transform.affine_inverse()
 for reference:WeakRef in _parts(weapon):
  var node:MeshInstance3D=reference.get_ref()
  if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():continue
  var box:AABB=(transform*inverse*node.global_transform)*node.mesh.get_aabb()
  result=box if first else result.merge(box);first=false
 return result
static func _polynomial_roots(c0:float,c1:float,c2:float)->Array[float]:
 var result:Array[float]=[]
 var scale:=maxf(1e-20,maxf(absf(c0),maxf(absf(c1),absf(c2))))
 if absf(c2)<scale*1e-10:
  if absf(c1)>scale*1e-10:result.append(-c0/c1)
  return result
 var discriminant:=c1*c1-4.*c2*c0
 if discriminant<0.:return result
 var root:=sqrt(maxf(0.,discriminant))
 # Avoid cancellation for very unequal roots.
 var q:float=-.5*(c1+(root if c1>=0. else -root))
 if absf(q)>1e-20:result.append(q/c2);result.append(c0/q)
 else:result.append(-c1/(2.*c2))
 return result
static func _edge_at(a:Vector3,b:Vector3,c:Vector3,d:Vector3)->Dictionary:
 var e:=b-a;var f:=d-c;var cross:=e.cross(f)
 var e2:=e.length_squared();var f2:=f.length_squared()
 if f2<1e-20:return {}
 if e2<1e-20:
  var v:float=(a-c).dot(f)/f2
  if v>=0. and v<=1. and a.distance_squared_to(c+f*v)<=1e-10:return {"point":a}
  return {}
 var denominator:=cross.length_squared();var offset:=c-a
 if denominator<=e2*f2*1e-12:
  if offset.cross(e).length_squared()/e2>1e-10:return {}
  var first:float=offset.dot(e)/e2;var second:float=(d-a).dot(e)/e2
  var low:float=maxf(0.,minf(first,second));var high:float=minf(1.,maxf(first,second))
  if low>high+1e-6:return {}
  return {"point":a+e*clampf(low,0.,1.)}
 var u:float=offset.cross(f).dot(cross)/denominator
 var v:float=offset.cross(e).dot(cross)/denominator
 if u < -1e-6 or u > 1.000001 or v < -1e-6 or v > 1.000001:return {}
 var point:=a+e*clampf(u,0.,1.)
 if point.distance_squared_to(c+f*clampf(v,0.,1.))>1e-10:return {}
 return {"point":point}
static func _coplanar_edge_time(a0:Vector3,b0:Vector3,a1:Vector3,b1:Vector3,c:Vector3,d:Vector3,limit:float)->Dictionary:
 var va:=a1-a0;var vb:=b1-b0;var e0:=b0-a0;var ve:=(b1-a1)-e0;var f:=d-c
 var normal:=Vector3.ZERO
 for candidate:Vector3 in [e0.cross(f),(b1-a1).cross(f),va.cross(f),vb.cross(f)]:
  if candidate.length_squared()>normal.length_squared():normal=candidate
 var times:Array[float]=[0.]
 if normal.length_squared()>1e-20:
  normal=normal.normalized()
  # A moving endpoint reaches the fixed segment's supporting line.
  for pair:Array in [[a0,va],[b0,vb]]:
   var p:Vector3=pair[0];var velocity:Vector3=pair[1]
   times.append_array(_polynomial_roots((p-c).cross(f).dot(normal),velocity.cross(f).dot(normal),0.))
  # A fixed endpoint reaches the moving segment's supporting line.
  for p:Vector3 in [c,d]:
   var offset:=p-a0
   times.append_array(_polynomial_roots(offset.cross(e0).dot(normal),(offset.cross(ve)-va.cross(e0)).dot(normal),-va.cross(ve).dot(normal)))
 # Collinear interval entry occurs at an endpoint equality. Also includes
 # the degenerate parallel boundary of the 2D cases above.
 var axis:=f.normalized()
 for pair:Array in [[a0,va],[b0,vb]]:
  var p:Vector3=pair[0];var velocity:Vector3=pair[1]
  var rate:float=velocity.dot(axis)
  if absf(rate)<1e-15:continue
  for q:Vector3 in [c,d]:times.append((q-p).dot(axis)/rate)
 times.sort()
 for t:float in times:
  if t < -1e-7 or t > limit+1e-7:continue
  t=clampf(t,0.,limit)
  var hit:=_edge_at(a0.lerp(a1,t),b0.lerp(b1,t),c,d)
  if not hit.is_empty():hit.fraction=t;return hit
 return {}
# Earliest nonparallel edge/edge contact for linearly moving edge endpoints.
# Coplanarity is quadratic in time; solve it before testing both segment ranges.
static func _edge_time(a0:Vector3,b0:Vector3,a1:Vector3,b1:Vector3,c:Vector3,d:Vector3,limit:float)->Dictionary:
 var va:=a1-a0;var e0:=b0-a0;var ve:=(b1-a1)-e0;var f:=d-c;var r:=c-a0
 var ef:=e0.cross(f);var vf:=ve.cross(f)
 var q0:float=r.dot(ef);var q1:float=r.dot(vf)-va.dot(ef);var q2:float=-va.dot(vf)
 var plane_tolerance:float=1e-8*maxf(1e-12,e0.length()*f.length())*maxf(1.,maxf(r.length(),maxf(va.length(),ve.length())))
 if maxf(absf(q0),maxf(absf(q1),absf(q2)))<=plane_tolerance:
  return _coplanar_edge_time(a0,b0,a1,b1,c,d,limit)
 var roots:=_polynomial_roots(q0,q1,q2)
 roots.sort()
 for t:float in roots:
  if t < -1e-7 or t > limit+1e-7:continue
  t=clampf(t,0.,limit)
  var hit:=_edge_at(a0.lerp(a1,t),b0.lerp(b1,t),c,d)
  if not hit.is_empty():hit.fraction=t;return hit
 return {}
static func _swept_edge(prepared:Array,a0:Vector3,b0:Vector3,a1:Vector3,b1:Vector3,limit:float)->Dictionary:
 var best:Dictionary={}
 for part:Dictionary in prepared:
  var inverse:Transform3D=part.inverse
  var la0:Vector3=inverse*a0;var lb0:Vector3=inverse*b0;var la1:Vector3=inverse*a1;var lb1:Vector3=inverse*b1
  var bounds:=AABB(la0,Vector3.ZERO).expand(lb0).expand(la0.lerp(la1,limit)).expand(lb0.lerp(lb1,limit)).grow(1e-7)
  var data:Dictionary=part.data;var stack:Array[int]=[0];var visited_edges:Dictionary={}
  while not stack.is_empty():
   var branch:Dictionary=data.nodes[stack.pop_back()]
   if not bounds.intersects(branch.bounds.grow(1e-7)):continue
   if int(branch.left)>=0:stack.append(branch.left);stack.append(branch.right);continue
   for id:int in branch.ids:
    var triangle:Dictionary=data.triangles[id]
    if not bounds.intersects(triangle.bounds.grow(1e-7)):continue
    for edge_id:int in triangle.edge_ids:
     if visited_edges.has(edge_id):continue
     visited_edges[edge_id]=true
     var hit:=_edge_time(la0,lb0,la1,lb1,data.edges[edge_id*2],data.edges[edge_id*2+1],limit)
     if hit.is_empty():continue
     limit=hit.fraction
     var node:MeshInstance3D=part.node
     var normal:Vector3=(Basis(part.normal_basis)*Vector3(triangle.normal)).normalized()
     if normal.dot((a1+b1)-(a0+b0))>0.:normal=-normal
     var material:Material=node.get_active_material(triangle.surface)
     best={"fraction":limit,"point":node.to_global(hit.point),"normal":normal,"axis":part.axis,"material":"metal" if material is StandardMaterial3D and material.metallic>.5 else "wood","mesh_instance":node.get_instance_id(),"surface":triangle.surface,"feature":"edge_edge"}
 return best
static func outgoing(host:Node,delta:float)->Dictionary:
 var weapon:Node3D=host.get("_sword")
 if not eligible(host) or delta<=0.:return {}
 var current:=weapon.global_transform
 var prior:Dictionary=weapon.get_meta("interception_sweep31",{})
 var frame:=Engine.get_physics_frames()
 var generation:int=host.get("lab_resets") if host.get("lab_resets")!=null else 0
 weapon.set_meta("interception_sweep31",{"transform":current,"frame":frame,"generation":generation})
 var opponent:Node3D=host.get("_npc_sword")
 if prior.is_empty() or prior.get("generation",-1)!=generation or frame-int(prior.frame)>2 or frame<int(prior.frame) or host.get("_prev_points").is_empty():return {}
 if not is_instance_valid(opponent) or not opponent.is_visible_in_tree():return {}
 var before:Transform3D=prior.transform
 if before.origin.distance_to(current.origin)>.4:return {}
 if before.is_equal_approx(current):return {}
 # Every tested vertex follows its endpoint segment; this union conservatively
 # encloses those paths, including every end-pose edge tested below.
 var swept_bounds:=_bounds_at(weapon,before).merge(_bounds_at(weapon,current)).grow(1e-7)
 if not swept_bounds.intersects(_bounds_at(opponent,opponent.global_transform).grow(1e-7)):return {}
 var result:Dictionary={}
 var opponent_prepared:=_prepared(opponent)
 var weapon_prepared:=_prepared(weapon)
 var inverse:=current.affine_inverse()
 for reference:WeakRef in _parts(weapon):
  var node:MeshInstance3D=reference.get_ref()
  if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():continue
  var local_transform:=inverse*node.global_transform
  var data:=_mesh_data(node.mesh)
  for point:Vector3 in data.points:
   var local:Vector3=local_transform*point
   var hit:=_segment_prepared(opponent_prepared,before*local,current*local)
   if not hit.is_empty() and (result.is_empty() or float(hit.fraction)<float(result.fraction)):result=hit
 # Reverse relative motion catches the opponent crossing a broad head face
 # even when none of that head's corners crosses the thinner opponent steel.
 var before_inverse:=before.affine_inverse()
 for reference:WeakRef in _parts(opponent):
  var node:MeshInstance3D=reference.get_ref()
  if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():continue
  var data:=_mesh_data(node.mesh)
  for point:Vector3 in data.points:
   var world_point:Vector3=node.to_global(point)
   var mapped_from:Vector3=current*(before_inverse*world_point)
   var hit:=_segment_prepared(weapon_prepared,mapped_from,world_point)
   if not hit.is_empty() and (result.is_empty() or float(hit.fraction)<float(result.fraction)):
    hit.point=world_point;result=hit
 # Two thin blades can cross in their middles and separate within one tick,
 # with neither set of mesh vertices touching. Query swept authored edges
 # against only the overlapping opponent BVH triangles.
 var edge_started:=Time.get_ticks_usec()
 for reference:WeakRef in _parts(weapon):
  var node:MeshInstance3D=reference.get_ref()
  if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():continue
  var local_transform:=inverse*node.global_transform;var data:=_mesh_data(node.mesh)
  for index in range(0,data.edges.size(),2):
   var a:Vector3=local_transform*data.edges[index];var b:Vector3=local_transform*data.edges[index+1]
   var hit:=_swept_edge(opponent_prepared,before*a,before*b,current*a,current*b,float(result.get("fraction",1.)))
   if not hit.is_empty() and (result.is_empty() or float(hit.fraction)<float(result.fraction)):result=hit
 weapon.set_meta("interception_edge_usec31",Time.get_ticks_usec()-edge_started)
 # End-pose edge/face crossings cover a broad head whose corners passed on
 # either side. Refine only a newly entered edge; stationary overlap is silent.
 if result.is_empty():
  for reference:WeakRef in _parts(weapon):
   var node:MeshInstance3D=reference.get_ref()
   if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():continue
   var local_transform:=inverse*node.global_transform
   var data:=_mesh_data(node.mesh)
   for index in range(0,data.edges.size(),2):
    var a:Vector3=local_transform*data.edges[index];var b:Vector3=local_transform*data.edges[index+1]
    var a0:=before*a;var b0:=before*b;var a1:=current*a;var b1:=current*b
    var hit:=_segment_prepared(opponent_prepared,a1,b1)
    if hit.is_empty() or not _segment_prepared(opponent_prepared,a0,b0).is_empty():continue
    var low:=0.;var high:=1.
    for iteration in 10:
     var middle:float=(low+high)*.5
     var middle_hit:=_segment_prepared(opponent_prepared,a0.lerp(a1,middle),b0.lerp(b1,middle))
     if middle_hit.is_empty():low=middle
     else:high=middle;hit=middle_hit
    hit.fraction=high
    if result.is_empty() or high<float(result.fraction):result=hit
 if not result.is_empty():host.set_meta("interception_contact31",{"point":result.point,"material":result.material,"frame":Engine.get_physics_frames()})
 return result
