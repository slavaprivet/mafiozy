extends Node
## Player-only wardrobe. The imported rig, binds, source mesh templates and
## normalized model transform remain untouched. All geometry is prepared once.
static var _cache:Dictionary={}
var player:Node3D
var rig:Skeleton3D
var body:MeshInstance3D
var gambeson:MeshInstance3D
var trousers:MeshInstance3D
var armor:Node3D
var gambeson_enabled:bool=false
var armor_tier:String=""
var report:Dictionary={}
var _source:MeshInstance3D
var _binds:Dictionary={}
var _v:=PackedVector3Array()
var _c:=PackedColorArray()
var _b:=PackedInt32Array()
var _w:=PackedFloat32Array()
var _i:=PackedInt32Array()
const SKIN:=Color(.67954,.3564,.20864)
const CLOTH:=Color(.19,.105,.049)

func configure(actor:Node3D)->Dictionary:
 if is_instance_valid(player):return report
 player=actor
 rig=actor.get("_pose_skeleton") as Skeleton3D
 if not is_instance_valid(rig):return {"ok":false,"reason":"rig"}
 for node:Node in actor.get("_visual").find_children("*","MeshInstance3D",true,false):
  if str(node.name)=="player_male_DEMO_core_FABRIC":_source=node
 if not is_instance_valid(_source) or _source.skin==null:return {"ok":false,"reason":"source_skin"}
 for idx in _source.skin.get_bind_count():
  var bone:int=_source.skin.get_bind_bone(idx)
  var name:String=str(_source.skin.get_bind_name(idx))
  if name.is_empty() and bone>=0:name=rig.get_bone_name(bone)
  _binds[name]=idx
 if not _binds.has("chest"):return {"ok":false,"reason":"bind_names","binds":_binds}
 var key:String=str(_source.mesh.get_instance_id())
 if not _cache.has(key):
  _cache[key]={"body":_build_upper(false),"gambeson":_build_upper(true),"trousers":_build_trousers()}
 var cached:Dictionary=_cache[key]
 body=_instance("HeroBareBody31",cached.body)
 trousers=_instance("HeroBrownTrousers31",cached.trousers)
 gambeson=_instance("HeroGambeson31",cached.gambeson)
 gambeson.visible=false
 _source.visible=false
 for node:Node in actor.get("_visual").find_children("*","MeshInstance3D",true,false):
  if str(node.name) in ["player_male_DEMO_core_TRIM","player_male_DEMO_headwear_FABRIC","player_male_DEMO_headwear_HAIR"]:node.visible=false
 armor=load("res://scripts/combat/castle_armor_visual.gd").new()
 armor.name="HeroArmor31";actor.add_child(armor)
 var armor_result:Dictionary=armor.configure(rig,actor.get("_visual"))
 report={"ok":bool(armor_result.get("ok",false)),"rig_bones":rig.get_bone_count(),"skin_bind_count":_source.skin.get_bind_count(),"source_bounds":_source.mesh.get_aabb(),"body_bounds":body.mesh.get_aabb(),"model_scale":actor.get("_model_scale"),"base_vertices":body.mesh.surface_get_array_len(0),"gambeson_vertices":gambeson.mesh.surface_get_array_len(0),"original_mesh_unchanged":true}
 return report

func set_gambeson(enabled:bool)->void:
 gambeson_enabled=enabled
 if is_instance_valid(gambeson):
  gambeson.visible=enabled or not armor_tier.is_empty()
  if is_instance_valid(body):body.visible=not gambeson.visible

func set_armor_tier(tier:String)->Dictionary:
 if tier not in ["","light","medium","heavy"]:return {"ok":false,"reason":"tier"}
 armor_tier=tier
 for slot:String in ["head","torso","hands","legs","feet"]:
  if tier.is_empty():armor.clear_piece(slot)
  else:armor.set_piece(slot,tier)
 set_gambeson(gambeson_enabled)
 return {"ok":true,"tier":tier}

func equipped_snapshot()->Dictionary:
 var equipped:Dictionary={}
 if not armor_tier.is_empty():
  for slot:String in ["head","torso","hands","legs","feet"]:equipped[slot]=armor_tier+"_"+slot
 return equipped

func speed_multiplier()->float:
 return preload("res://scripts/combat/armor_damage31.gd").movement_multiplier(equipped_snapshot())

func snapshot()->Dictionary:
 return {"ready":report.get("ok",false),"gambeson_requested":gambeson_enabled,"gambeson_visible":is_instance_valid(gambeson) and gambeson.visible,"armor_tier":armor_tier,"body_visible":is_instance_valid(body) and body.visible,"report":report}

func _instance(label:String,mesh:ArrayMesh)->MeshInstance3D:
 var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.skin=_source.skin
 _source.get_parent().add_child(node);node.transform=_source.transform;node.skeleton=node.get_path_to(rig)
 node.set_meta("hero_medieval31",true)
 return node

func _reset_arrays()->void:
 _v=PackedVector3Array();_c=PackedColorArray();_b=PackedInt32Array();_w=PackedFloat32Array();_i=PackedInt32Array()

func _vertex(at:Vector3,color:Color,bones:PackedInt32Array,weights:PackedFloat32Array)->int:
 var idx:int=_v.size();_v.append(at);_c.append(color)
 for k in 4:_b.append(bones[k]);_w.append(weights[k])
 return idx

func _torso_weights(y:float)->Dictionary:
 var t:float=smoothstep(1.75,2.65,y)
 return {"bones":PackedInt32Array([_binds.spine_01,_binds.chest,0,0]),"weights":PackedFloat32Array([1.0-t,t,0,0])}

func _shape(y:float,theta:float,cloth:bool,body_detail:bool=true)->Vector3:
 var t:float=clampf((y-1.67)/1.75,0,1)
 var width:float=.42+.21*sin(t*PI*.85)
 var depth:float=.275+.08*sin(t*PI*.8)
 # Natural shoulder-to-neck slope; no jacket collar silhouette.
 if t>.90:
  var k:float=smoothstep(.90,1.0,t)
  width=lerpf(width,.22,k);depth=lerpf(depth,.19,k)
 var x:float=sin(theta)*width
 var z:float=cos(theta)*depth
 var front:float=maxf(0.0,cos(theta))
 if not cloth:
  var pec:float=exp(-pow((absf(x)-.29)/.20,2)-pow((y-2.98)/.20,2))*(.118 if body_detail else .092)
  var abs_value:float=0.0
  for row:float in [2.05,2.30,2.55]:abs_value+=exp(-pow((absf(x)-.155)/.13,2)-pow((y-row)/.105,2))*(.052 if body_detail else .040)
  var groove:float=exp(-pow(x/.055,2)-pow((y-2.65)/.60,2))*.006
  z+=(pec+abs_value-groove)*pow(front,1.2)
  if body_detail:
   var navel:float=.009*exp(-pow(x/.045,2)-pow((y-1.98)/.045,2))
   var clavicle:float=.012*exp(-pow((absf(x)-.28)/.24,2)-pow((y-(3.245-.055*absf(x)))/.045,2))
   z+=(clavicle-navel)*pow(front,1.5)
  if z<0:z-=.018*exp(-pow((absf(x)-.27)/.24,2)-pow((y-2.95)/.33,2))
 else:
  var underlying:Vector3=_shape(y,theta,false,false)
  x=underlying.x*1.06;z=underlying.z+signf(underlying.z)*.030
  # Shallow real quilt channels, not a painted normal-map substitute.
  z+=signf(z)*.0055*cos(x*32.0+y*22.0)*cos(x*32.0-y*22.0)*sin(t*PI)
 return Vector3(x,y,z)

func _build_upper(cloth:bool)->ArrayMesh:
 _reset_arrays()
 var around:int=64;var rows:int=36
 for row in rows+1:
  var y:float=lerpf(1.67,3.42,float(row)/rows)
  if cloth and row==0:y=1.60
  var weights:Dictionary=_torso_weights(y)
  for col in around:
   var theta:float=TAU*float(col)/around
   var point:Vector3=_shape(y,theta,cloth)
   var color:Color=CLOTH if cloth else SKIN
   if cloth:
    var seam:float=(pow(maxf(0.0,cos(point.x*32.0+y*22.0)),12.0)+pow(maxf(0.0,cos(point.x*32.0-y*22.0)),12.0))*.09
    color=color.darkened(seam)
    if absf(point.x)<.022 and point.z>0:color=color.darkened(.3)
   else:
    color=color.lightened(.025*maxf(0.0,cos(theta)))
   _vertex(point,color,weights.bones,weights.weights)
 for row in rows:
  for col in around:
   if row>=24 and row<32 and ((col>=10 and col<22) or (col>=42 and col<54)):continue
   var a:int=row*around+col;var b:int=row*around+(col+1)%around;var c:int=a+around;var d:int=b+around
   _i.append_array(PackedInt32Array([a,c,b,b,c,d]))
 for side:int in [-1,1]:_joined_arm(side,cloth)
 if not cloth:
  for side:int in [-1,1]:_nipple(side)
 else:
  _laces()
  _collar()
 _smooth_shoulders()
 return _commit()

func _joined_arm(side:int,cloth:bool)->void:
 # The first ring is the actual torso-hole boundary, shared indices/normals.
 # There are no overlapping shoulder balls or duplicated seam vertices.
 var lo:int=42 if side<0 else 10;var hi:int=lo+12
 var boundary:=PackedInt32Array()
 for row in range(32,24,-1):boundary.append(row*64+lo)
 for col in range(lo,hi):boundary.append(24*64+col)
 for row in range(24,32):boundary.append(row*64+hi)
 for col in range(hi,lo,-1):boundary.append(32*64+col)
 var shoulder:=Vector3(side*.62,3.03,0);var elbow:=Vector3(side*1.08,2.58,0);var wrist:=Vector3(side*1.12,1.91,.055)
 var upper:int=_binds["upperarm_l" if side<0 else "upperarm_r"]
 var lower:int=_binds["forearm_l" if side<0 else "forearm_r"]
 var hand:int=_binds["hand_l" if side<0 else "hand_r"]
 var around:int=boundary.size();var rows:int=20
 var initial_axis:=Vector3(float(side),0,0)
 var initial_u:Vector3=Vector3.FORWARD.cross(initial_axis).normalized();var initial_v:Vector3=initial_axis.cross(initial_u).normalized()
 var angles:=PackedFloat32Array()
 for index in boundary:
  var radial:Vector3=_v[index]-shoulder
  angles.append(atan2(radial.dot(initial_v),radial.dot(initial_u)))
 var previous:PackedInt32Array=boundary
 for row in range(1,rows+1):
  var t:float=float(row)/rows
  var center:Vector3=shoulder.lerp(elbow,t*2.0) if t<=.5 else elbow.lerp(wrist,(t-.5)*2.0)
  var axis:Vector3=initial_axis.lerp((elbow-shoulder).normalized(),smoothstep(0.0,.28,t)).normalized().lerp((wrist-elbow).normalized(),smoothstep(.38,.62,t)).normalized()
  var u:Vector3=Vector3.FORWARD.cross(axis).normalized();var v:Vector3=axis.cross(u).normalized()
  var radius:float=lerpf(.225,.145,t*2.0)+.025*sin(t*2.0*PI) if t<=.5 else lerpf(.145,.137,(t-.5)*2.0)+.024*sin((t-.5)*2.0*PI)
  if cloth:radius+=.018
  var blend:float=smoothstep(.40,.60,t);var hand_mix:float=smoothstep(.80,1.0,t)
  var join:float=smoothstep(0.0,.20,t)
  var bones:=PackedInt32Array([_binds.chest,upper,lower,hand])
  var weights:=PackedFloat32Array([1.0-join,join*(1.0-blend),join*blend*(1.0-hand_mix),join*blend*hand_mix])
  var current:=PackedInt32Array()
  for col in around:
   var angle:float=angles[col]
   var at:Vector3=center+(u*cos(angle)+v*sin(angle))*radius
   at=_v[boundary[col]].lerp(at,join)
   var color:Color=CLOTH if cloth else SKIN
   if cloth:color=color.darkened(.08*pow(maxf(0.0,cos(t*38.0+angle*3.0)),12.0))
   current.append(_vertex(at,color,bones,weights))
  for col in around:
   var next:int=(col+1)%around
   _i.append_array(PackedInt32Array([previous[col],current[col],previous[next],previous[next],current[col],current[next]]))
  previous=current

func _nipple(side:int)->void:
 var x:float=float(side)*.30;var y:float=2.96
 var theta:float=asin(x/(.42+.21*sin(clampf((y-1.67)/1.75,0,1)*PI*.85)))
 var center:Vector3=_shape(y,theta,false)
 var weights:Dictionary=_torso_weights(y);var start:int=_v.size();var rings:int=4;var radial:int=24
 for ring in rings+1:
  var radius:float=float(ring)/rings
  for col in radial:
   var angle:float=TAU*float(col)/radial
   var offset:=Vector3(cos(angle)*.052*radius,sin(angle)*.040*radius,.002+.010*pow(1.0-radius,2))
   var point:Vector3=center+offset
   var width:float=.42+.21*sin(clampf((point.y-1.67)/1.75,0,1)*PI*.85)
   point.z=_shape(point.y,asin(clampf(point.x/width,-1.0,1.0)),false).z+offset.z
   _vertex(point,SKIN.darkened(.19).lerp(SKIN,radius*.45),weights.bones,weights.weights)
 for ring in rings:
  for col in radial:
   var a:int=start+ring*radial+col;var b:int=start+ring*radial+(col+1)%radial;var c:int=a+radial;var d:int=b+radial
   _i.append_array(PackedInt32Array([a,b,c,b,d,c]))

func _laces()->void:
 for row in 4:
  var y:float=2.76+float(row)*.115
  for side:int in [-1,1]:
   var a:=Vector3(-.065,y,0);var b:=Vector3(.065,y+.08*side,0)
   a.z=_shape(a.y,asin(a.x/.62),true).z+.015;b.z=_shape(b.y,asin(b.x/.62),true).z+.015
   var u:Vector3=(b-a).cross(Vector3.BACK).normalized();var v:Vector3=(b-a).normalized().cross(u)
   var start:int=_v.size()
   for point:Vector3 in [a,b]:
    var weights:Dictionary=_torso_weights(point.y)
    for col in 6:
     var at:Vector3=point+(u*cos(TAU*col/6.0)+v*sin(TAU*col/6.0))*.007
     _vertex(at,Color(.065,.035,.016),weights.bones,weights.weights)
   for col in 6:
    var next:int=(col+1)%6
    _i.append_array(PackedInt32Array([start+col,start+6+col,start+next,start+next,start+6+col,start+6+next]))

func _collar()->void:
 var start:int=_v.size();var count:int=48
 for row in 3:
  for col in count+1:
   var angle:float=lerpf(.12,TAU-.12,float(col)/count)
   var point:=Vector3(sin(angle)*(.237+row*.003),3.405+row*.043,cos(angle)*(.225+row*.003))
   var weights:Dictionary=_torso_weights(point.y)
   _vertex(point,CLOTH.lightened(.018) if row==2 else CLOTH,weights.bones,weights.weights)
 for row in 2:
  for col in count:
   var a:int=start+row*(count+1)+col;var b:int=a+1;var c:int=a+count+1;var d:int=c+1
   _i.append_array(PackedInt32Array([a,c,b,b,c,d]))

func _build_trousers()->ArrayMesh:
 _reset_arrays()
 var lower:Array=[]
 for name:String in ["pelvis","thigh_l","thigh_r","shin_l","shin_r"]:lower.append(_binds[name])
 for surface in _source.mesh.get_surface_count():
  var arrays:Array=_source.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  if indices.is_empty():
   for index in vertices.size():indices.append(index)
  for tri in range(0,indices.size(),3):
   var accept:bool=true
   for corner in 3:
    var id:int=indices[tri+corner];var best:int=0
    for slot in range(1,4):
     if weights[id*4+slot]>weights[id*4+best]:best=slot
    if bones[id*4+best] not in lower:accept=false
   if not accept:continue
   for corner in 3:
    var id:int=indices[tri+corner];var point:Vector3=vertices[id]
    var color:=Color(.105,.054,.025).lightened(.018*maxf(0.0,point.z))
    _i.append(_vertex(point,color,bones.slice(id*4,id*4+4),weights.slice(id*4,id*4+4)))
 return _commit()

func _smooth_shoulders()->void:
 # Bounded local relaxation of the stitched branch; no detached shoulder caps.
 var neighbors:Dictionary={}
 for tri in range(0,_i.size(),3):
  for corner in 3:
   var index:int=_i[tri+corner];var point:Vector3=_v[index]
   if point.y<2.75 or point.y>3.37 or absf(point.x)<.36:continue
   if not neighbors.has(index):neighbors[index]={}
   neighbors[index][_i[tri+(corner+1)%3]]=true
   neighbors[index][_i[tri+(corner+2)%3]]=true
 for iteration in 3:
  var next:PackedVector3Array=_v.duplicate()
  for index:int in neighbors:
   var average:=Vector3.ZERO
   for other:int in neighbors[index]:average+=_v[other]
   average/=float(neighbors[index].size())
   var factor:float=smoothstep(.36,.55,absf(_v[index].x))*.45
   next[index]+=(average-_v[index]).limit_length(.012)*factor
  _v=next

func _commit()->ArrayMesh:
 var normals:=PackedVector3Array();normals.resize(_v.size())
 for tri in range(0,_i.size(),3):
  var a:int=_i[tri];var b:int=_i[tri+1];var c:int=_i[tri+2]
  var normal:Vector3=(_v[c]-_v[a]).cross(_v[b]-_v[a])
  normals[a]+=normal;normals[b]+=normal;normals[c]+=normal
 for idx in normals.size():normals[idx]=normals[idx].normalized()
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=_v;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=_c;arrays[Mesh.ARRAY_BONES]=_b;arrays[Mesh.ARRAY_WEIGHTS]=_w;arrays[Mesh.ARRAY_INDEX]=_i
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=false;material.roughness=.88;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 mesh.surface_set_material(0,material)
 return mesh
