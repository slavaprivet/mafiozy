extends RefCounted
## Immutable startup geometry: soft intestinal folds and two lobed viscera.
## No scene, physics or per-frame mesh work.
static func _mesh(vertices:PackedVector3Array,normals:PackedVector3Array,colors:PackedColorArray,indices:PackedInt32Array)->ArrayMesh:
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

static func bowel()->ArrayMesh:
 # Four unequal hairpin folds. They are one continuous tube, not a helix.
 var controls:Array[Vector3]=[
  Vector3(-.062,-.025,-.024),Vector3(-.068,.017,-.021),Vector3(-.050,.039,-.015),
  Vector3(-.036,.014,-.009),Vector3(-.039,-.031,-.003),Vector3(-.018,-.043,.004),
  Vector3(-.010,-.009,.011),Vector3(-.014,.034,.013),Vector3(.008,.044,.010),
  Vector3(.020,.011,.004),Vector3(.015,-.025,-.004),Vector3(.035,-.037,-.010),
  Vector3(.050,-.010,-.012),Vector3(.048,.023,-.006),Vector3(.066,.031,.006)]
 var path:=PackedVector3Array()
 for i in range(controls.size()-1):
  var a:Vector3=controls[maxi(0,i-1)];var b:Vector3=controls[i]
  var c:Vector3=controls[i+1];var d:Vector3=controls[mini(controls.size()-1,i+2)]
  for step in 8:
   var t:=float(step)/8.0
   path.append(.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t*t+(-a+3.0*b-3.0*c+d)*t*t*t))
 path.append(controls.back())
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
 var colors:=PackedColorArray();var indices:=PackedInt32Array()
 const SIDES:=16
 var previous:=Vector3.FORWARD
 for i in path.size():
  var tangent:Vector3=(path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized()
  var u:Vector3=(previous-tangent*previous.dot(tangent)).normalized()
  if u.length_squared()<.5:u=tangent.cross(Vector3.UP).normalized()
  var v:=tangent.cross(u).normalized();previous=u
  var t:=float(i)/float(path.size()-1)
  var radius:=.010*(.94+.08*sin(t*23.0)+.035*sin(t*135.0))
  var tint:=.84+.12*sin(t*15.0+.7)+.035*sin(t*137.0)
  for side in SIDES:
   var angle:=TAU*float(side)/SIDES
   var n:=u*cos(angle)+v*sin(angle)
   vertices.append(path[i]+n*radius);normals.append(n)
   colors.append(Color(tint,tint*(.87+.08*sin(t*21.0)),tint*(.9+.06*sin(t*17.0+.4))))
   if i<path.size()-1:
    var a:=i*SIDES+side;var b:=i*SIDES+(side+1)%SIDES
    indices.append_array(PackedInt32Array([a,b,b+SIDES,a,b+SIDES,a+SIDES]))
 for end in 2:
  var row:=0 if end==0 else path.size()-1
  var direction:Vector3=(path[1]-path[0]).normalized()*-1.0 if end==0 else (path[-1]-path[-2]).normalized()
  var center:=vertices.size();vertices.append(path[row]);normals.append(direction);colors.append(Color(.53,.40,.40))
  for side in SIDES:
   var a:=row*SIDES+side;var b:=row*SIDES+(side+1)%SIDES
   indices.append_array(PackedInt32Array([center,b,a] if end==0 else [center,a,b]))
 # Tube construction uses the mathematical outward orientation. Godot's
 # clockwise front faces require reversing it; normals remain outward.
 for i in range(0,indices.size(),3):
  var saved:=indices[i+1];indices[i+1]=indices[i+2];indices[i+2]=saved
 return _mesh(vertices,normals,colors,indices)

static func organ(kind:int)->ArrayMesh:
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
 var colors:=PackedColorArray();var indices:=PackedInt32Array()
 const ROWS:=20
 const SIDES:=32
 for row in range(ROWS+1):
  var phi:=PI*float(row)/ROWS
  for side in range(SIDES+1):
   var theta:=TAU*float(side)/SIDES
   var n:=Vector3(sin(phi)*cos(theta),cos(phi),sin(phi)*sin(theta))
   var p:=_organ_point(n,kind)
   vertices.append(p);normals.append(Vector3.ZERO)
   var variation:=.92+.055*sin(theta*3.0+phi*2.0)+.02*sin(phi*11.0)
   colors.append(Color(variation,variation*.94,variation*.96))
   if row<ROWS and side<SIDES:
    var a:=row*(SIDES+1)+side;var b:=a+1;var c:=a+SIDES+1;var d:=c+1
    if row>0:indices.append_array(PackedInt32Array([a,c,b]))
    if row<ROWS-1:indices.append_array(PackedInt32Array([b,c,d]))
 # Area-weighted normals, welded across the UV seam and spherical poles.
 var sums:Dictionary={}
 for i in range(0,indices.size(),3):
  var a:=indices[i];var b:=indices[i+1];var c:=indices[i+2]
  var n:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
  # Godot front faces use clockwise winding; normals point opposite its cross product.
  for j:int in [a,b,c]:
   var key:=Vector3i((vertices[j]*1000000.0).round())
   sums[key]=Vector3(sums.get(key,Vector3.ZERO))+n
 for i in vertices.size():normals[i]=-Vector3(sums.get(Vector3i((vertices[i]*1000000.0).round()),Vector3.UP)).normalized()
 return _mesh(vertices,normals,colors,indices)

static func _organ_point(n:Vector3,kind:int)->Vector3:
 if kind==0:
  # Flattened, asymmetric liver lobes with a shallow inter-lobe cleft.
  var cleft:=exp(-pow((n.x+.18)/.13,2.0))*maxf(0.0,-n.y)*.20
  var size:=1.0-cleft
  return Vector3(n.x*.068,n.y*.036*size,n.z*.026*size)*(1.0+.10*n.x)+Vector3(0,.007*n.x,0)
 # Curved kidney silhouette: a real medial indentation, not an ellipse decal.
 var hollow:=.010*exp(-pow((n.y-.05)/.45,2.0))*maxf(0.0,-n.x)
 return Vector3(n.x*.030+hollow,n.y*.047,n.z*.023)*(1.0+.07*n.y)
