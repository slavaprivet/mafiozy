extends RefCounted
## Render geometry only. Existing skinned vertex channels/topology stay intact.
static func rounded_box(size:Vector3)->ArrayMesh:
 var half:=size*.5
 var radius:=minf(half.x,minf(half.y,half.z))*.48
 var core:=half-Vector3.ONE*radius
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face in 3:
  var u:=(face+1)%3;var v:=(face+2)%3
  var us:Array[float]=[-half[u],-core[u]-radius*.45,-core[u],core[u],core[u]+radius*.45,half[u]]
  var vs:Array[float]=[-half[v],-core[v]-radius*.45,-core[v],core[v],core[v]+radius*.45,half[v]]
  for sign_value:float in [-1.,1.]:
   for row in vs.size()-1:
    for col in us.size()-1:
     var points:Array[Vector3]=[];var normals:Array[Vector3]=[]
     for pair:Vector2i in [Vector2i(col,row),Vector2i(col+1,row),Vector2i(col,row+1),Vector2i(col+1,row+1)]:
      var point:=Vector3.ZERO;point[face]=half[face]*sign_value;point[u]=us[pair.x];point[v]=vs[pair.y]
      var inside:=point.clamp(-core,core);var normal:Vector3=(point-inside).normalized()
      points.append(inside+normal*radius);normals.append(normal)
     var order:Array=[0,2,1,1,2,3] if sign_value>0 else [0,1,2,1,3,2]
     for index:int in order:surface.set_normal(normals[index]);surface.add_vertex(points[index])
 surface.index()
 return surface.commit()

static func smooth_normals(points:PackedVector3Array,indices:PackedInt32Array)->PackedVector3Array:
 var sums:Dictionary={}
 for tri in range(0,indices.size(),3):
  var a:=points[indices[tri]];var b:=points[indices[tri+1]];var c:=points[indices[tri+2]]
  var normal:Vector3=(c-a).cross(b-a)
  if normal.length_squared()<1e-16:continue
  for corner in 3:
   var key:=points[indices[tri+corner]].snapped(Vector3.ONE*.0001)
   sums[key]=Vector3(sums.get(key,Vector3.ZERO))+normal
 var result:=PackedVector3Array()
 for point:Vector3 in points:
  var normal:Vector3=sums.get(point.snapped(Vector3.ONE*.0001),Vector3.UP)
  result.append(normal.normalized() if normal.length_squared()>1e-16 else Vector3.UP)
 return result

static func rolled_boundary(mesh:ArrayMesh,radius:float)->ArrayMesh:
 var arrays:Array=mesh.surface_get_arrays(0)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var edges:Dictionary={}
 for ti in range(0,indices.size(),3):
  for corner in 3:
   var ia:=indices[ti+corner];var ib:=indices[ti+(corner+1)%3]
   var a:=points[ia].snapped(Vector3.ONE*.00001);var b:=points[ib].snapped(Vector3.ONE*.00001)
   var key:Array=[a,b] if a<b else [b,a]
   if edges.has(key):edges[key].count+=1
   else:edges[key]={"a":ia,"b":ib,"count":1}
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for edge:Dictionary in edges.values():
  if int(edge.count)!=1:continue
  var a:=points[edge.a];var b:=points[edge.b];var axis:Vector3=(b-a).normalized()
  if a.distance_squared_to(b)<1e-10:continue
  var face_normal:Vector3=(normals[edge.a]+normals[edge.b]).normalized()
  var side:Vector3=axis.cross(face_normal).normalized()
  for segment in 8:
   var theta0:=TAU*float(segment)/8.;var theta1:=TAU*float(segment+1)/8.
   var n0:Vector3=face_normal*cos(theta0)+side*sin(theta0);var n1:Vector3=face_normal*cos(theta1)+side*sin(theta1)
   for pair:Vector2i in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
    var normal:Vector3=n0 if pair.y==0 else n1
    surface.set_normal(normal);surface.add_vertex((a if pair.x==0 else b)+normal*radius)
 surface.index();return surface.commit()
