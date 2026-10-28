extends RefCounted
## Actor-owned surface wounds; no extra draw geometry and no shared-mesh mutation.
const ShaderSource=preload("res://scripts/character/hero_wound31.gdshader")
const LIMIT:=8
var surfaces:Dictionary={}
var hits:int=0
var last:Dictionary={}

func prepare(node:MeshInstance3D)->void:
 if not is_instance_valid(node) or node.mesh==null:return
 var source:Array=node.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=source[Mesh.ARRAY_VERTEX]
 var uv:=PackedVector2Array();var uv2:=PackedVector2Array()
 for position:Vector3 in vertices:uv.append(Vector2(position.x,position.y));uv2.append(Vector2(position.z,0))
 source[Mesh.ARRAY_TEX_UV]=uv;source[Mesh.ARRAY_TEX_UV2]=uv2
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source)
 node.mesh=mesh
 var material:=ShaderMaterial.new();material.shader=ShaderSource
 mesh.surface_set_material(0,material)
 surfaces[node.get_instance_id()]={"node":weakref(node),"mesh":mesh,"arrays":source,"material":material,"centers":PackedVector4Array(),"axes":PackedVector4Array(),"normals":PackedVector4Array(),"groups":_groups(source,node)}

func apply(host:Node,node:MeshInstance3D,point:Vector3,motion:Vector3,kind:String,amount:float,part:String)->bool:
 var started:int=Time.get_ticks_usec()
 if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():return false
 var row:Dictionary=surfaces.get(node.get_instance_id(),{})
 if row.is_empty():return false
 # A genuine cut owns a new mesh; read it once on the next accepted hit.
 if row.mesh!=node.mesh:
  var kept:Dictionary=node.get_meta("hero_wound_arrays31",{})
  if kept.get("mesh")!=node.mesh:return false
  row.mesh=node.mesh;row.arrays=kept.arrays;row.groups=_groups(row.arrays,node)
 var arrays:Array=row.arrays
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var binds:Array=host._cut_skin_transforms39(node,host._rig)
 if binds.is_empty():return false
 var group:Dictionary=row.groups.get(_part_group(part),{})
 if group.is_empty():return false
 var posed:Dictionary={}
 for i:int in group.vertices:
  var p:=Vector3.ZERO
  for k in 4:
   var weight:float=weights[i*4+k]
   if weight>0.0:p+=(binds[bones[i*4+k]]*vertices[i])*weight
  posed[i]=node.global_transform*p
 var best:float=INF;var tri:=Vector3i();var bary:=Vector3.ZERO
 for i:int in group.triangles:
  var a:int=indices[i];var b:int=indices[i+1];var c:int=indices[i+2]
  var bc:=_closest_bary(point,posed[a],posed[b],posed[c])
  var near:Vector3=posed[a]*bc.x+posed[b]*bc.y+posed[c]*bc.z
  var distance:float=near.distance_squared_to(point)
  if distance<best:best=distance;tri=Vector3i(a,b,c);bary=bc
 # Hitboxes can sit outside the garment, but do not paint a remote body part.
 if best>.18*.18:return false
 var center:Vector3=vertices[tri.x]*bary.x+vertices[tri.y]*bary.y+vertices[tri.z]*bary.z
 var source_normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var local_normal:Vector3=(source_normals[tri.x]*bary.x+source_normals[tri.y]*bary.y+source_normals[tri.z]*bary.z).normalized()
 var rest_u:Vector3=vertices[tri.y]-vertices[tri.x]
 var rest_v:Vector3=vertices[tri.z]-vertices[tri.x]
 var world_u:Vector3=posed[tri.y]-posed[tri.x]
 var world_v:Vector3=posed[tri.z]-posed[tri.x]
 var aa:float=world_u.dot(world_u);var ab:float=world_u.dot(world_v);var bb:float=world_v.dot(world_v)
 var determinant:float=aa*bb-ab*ab
 var t:Vector3=rest_u.normalized()
 if determinant>1e-14:
  var u:float=(motion.dot(world_u)*bb-motion.dot(world_v)*ab)/determinant
  var v:float=(motion.dot(world_v)*aa-motion.dot(world_u)*ab)/determinant
  var projected:Vector3=rest_u*u+rest_v*v
  if projected.length_squared()>1e-10:t=projected.normalized()
 if local_normal.length_squared()<.5:return false
 var scale:float=maxf(node.global_basis.get_scale().x,.01)
 var radius:float=clampf(.018+sqrt(amount)*.002,.018,.045)/scale
 var centers:PackedVector4Array=row.centers;var axes:PackedVector4Array=row.axes;var normals:PackedVector4Array=row.normals
 if centers.size()==LIMIT:centers.remove_at(0);axes.remove_at(0);normals.remove_at(0)
 centers.append(Vector4(center.x,center.y,center.z,radius))
 axes.append(Vector4(t.x,t.y,t.z,radius*(.5 if kind=="stab" else .20)))
 normals.append(Vector4(local_normal.x,local_normal.y,local_normal.z,.025/scale))
 row.centers=centers;row.axes=axes;row.normals=normals
 var padded_c:=centers.duplicate();var padded_a:=axes.duplicate();var padded_n:=normals.duplicate()
 padded_c.resize(LIMIT);padded_a.resize(LIMIT);padded_n.resize(LIMIT)
 row.material.set_shader_parameter("wound_center",padded_c)
 row.material.set_shader_parameter("wound_axis",padded_a)
 row.material.set_shader_parameter("wound_normal",padded_n)
 row.material.set_shader_parameter("wound_count",centers.size())
 hits+=1;last={"node":str(node.name),"kind":kind,"distance":sqrt(best),"triangle":tri,"count":centers.size(),"point":point,"motion":motion,"candidate_vertices":group.vertices.size(),"candidate_triangles":group.triangles.size(),"elapsed_usec":Time.get_ticks_usec()-started}
 return true

static func _closest_bary(p:Vector3,a:Vector3,b:Vector3,c:Vector3)->Vector3:
 var ab:=b-a;var ac:=c-a;var ap:=p-a
 var d1:=ab.dot(ap);var d2:=ac.dot(ap)
 if d1<=0.0 and d2<=0.0:return Vector3(1,0,0)
 var bp:=p-b;var d3:=ab.dot(bp);var d4:=ac.dot(bp)
 if d3>=0.0 and d4<=d3:return Vector3(0,1,0)
 var vc:=d1*d4-d3*d2
 if vc<=0.0 and d1>=0.0 and d3<=0.0:
  var v:=d1/(d1-d3);return Vector3(1-v,v,0)
 var cp:=p-c;var d5:=ab.dot(cp);var d6:=ac.dot(cp)
 if d6>=0.0 and d5<=d6:return Vector3(0,0,1)
 var vb:=d5*d2-d1*d6
 if vb<=0.0 and d2>=0.0 and d6<=0.0:
  var w:=d2/(d2-d6);return Vector3(1-w,0,w)
 var va:=d3*d6-d5*d4
 if va<=0.0 and d4-d3>=0.0 and d5-d6>=0.0:
  var w:=(d4-d3)/((d4-d3)+(d5-d6));return Vector3(0,1-w,w)
 var denominator:float=va+vb+vc
 if absf(denominator)<1e-16:return Vector3(1,0,0)
 return Vector3(va,vb,vc)/denominator

static func _part_group(part:String)->String:
 if part in ["chest","spine_01","spine_02"]:return "chest"
 if part in ["head","neck"]:return "head"
 return part

static func _groups(arrays:Array,node:MeshInstance3D)->Dictionary:
 var groups:Dictionary={}
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var names:Array[String]=[]
 var rig:Skeleton3D=node.get_node(node.skeleton)
 for i in node.skin.get_bind_count():
  var name:String=str(node.skin.get_bind_name(i))
  if name.is_empty():name=rig.get_bone_name(node.skin.get_bind_bone(i))
  names.append(_part_group(name))
 for i in range(0,indices.size(),3):
  var touched:Dictionary={}
  for corner in 3:
   var index:int=indices[i+corner]
   for k in 4:
    if weights[index*4+k]>.05:touched[names[bones[index*4+k]]]=true
  for name:String in touched:
   if not groups.has(name):groups[name]={"triangles":PackedInt32Array(),"vertices":{}}
   groups[name].triangles.append(i)
   for corner in 3:groups[name].vertices[indices[i+corner]]=true
 return groups
