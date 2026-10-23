extends Node3D
## One scene-owned fixed pool, shared by every actor. Accepted contacts only.
const LIMIT:=48
var host:Node
var nodes:Array[MeshInstance3D]=[]
var velocities:Array[Vector3]=[]
var remaining:Array[float]=[]
var lifetimes:Array[float]=[]
var _rng:=RandomNumberGenerator.new()
var _last_at:=Vector3.INF
var _last_ms:=-1000
var owners:Array[WeakRef]=[]
var generations:Array[int]=[]
var _last_owner:=0
var _warmed:=false
var _warming:=false
var emitted:=0
var skipped:=0
func _ready():
 _rng.seed=310107
 var mesh:=BoxMesh.new();mesh.size=Vector3(.004,.004,.055)
 var material:StandardMaterial3D=host.get("_spark_material") if is_instance_valid(host) else null
 if material==null:material=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color=Color(1.,.79,.38);material.emission_enabled=true;material.emission=Color(1.,.45,.08);material.emission_energy_multiplier=2.2
 for i in LIMIT:
  var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(node);node.top_level=true;node.visible=false
  nodes.append(node);velocities.append(Vector3.ZERO);remaining.append(0.);lifetimes.append(.2);owners.append(null);generations.append(0)
 host=null
 set_process(false)
func burst(at:Vector3,normal:Vector3,count:int,kind:String="metal",source:Node=null)->int:
 if not is_instance_valid(source) or not at.is_finite() or count<=0 or kind in ["flesh","blunt","slice","stab","sever","swish"]:return 0
 var now:=Time.get_ticks_msec()
 var source_id:=source.get_instance_id()
 if source_id==_last_owner and now-_last_ms<55 and at.distance_squared_to(_last_at)<.0225:return 0
 _last_ms=now;_last_at=at;_last_owner=source_id
 var away:=normal.normalized() if normal.length_squared()>1e-8 else Vector3.UP
 var made:=0
 for i in LIMIT:
  if remaining[i]>0.:continue
  var spread:=Vector3(_rng.randf_range(-1.,1.),_rng.randf_range(.1,1.2),_rng.randf_range(-1.,1.))
  var speed:=_rng.randf_range(.7,2.8) if kind=="wood" else _rng.randf_range(1.7,4.6)
  velocities[i]=(away+spread*.65).normalized()*speed
  remaining[i]=_rng.randf_range(.10,.23) if kind=="wood" else _rng.randf_range(.12,.29)
  lifetimes[i]=remaining[i];owners[i]=weakref(source);generations[i]=_generation_of(source)
  nodes[i].global_position=at+Vector3(_rng.randf_range(-.004,.004),_rng.randf_range(-.004,.004),_rng.randf_range(-.004,.004))
  nodes[i].scale=Vector3(1.6,1.6,.45) if kind=="wood" else Vector3.ONE
  nodes[i].visible=true;_orient(nodes[i],velocities[i])
  made+=1
  if made>=mini(count,16):break
 emitted+=made;skipped+=maxi(0,mini(count,16)-made);set_process(true)
 return made
func _orient(node:Node3D,direction:Vector3):
 if direction.length_squared()<1e-10:return
 var forward:=direction.normalized();var up:=Vector3.UP if absf(forward.dot(Vector3.UP))<.98 else Vector3.RIGHT
 node.look_at(node.global_position+forward,up,true)
func _process(delta:float):
 var active:=false
 for i in LIMIT:
  if remaining[i]<=0.:continue
  var source:Node=owners[i].get_ref() if owners[i]!=null else null
  if not is_instance_valid(source) or _generation_of(source)!=generations[i]:
   remaining[i]=0.;nodes[i].visible=false;owners[i]=null;continue
  remaining[i]-=delta
  if remaining[i]<=0.:nodes[i].visible=false;continue
  velocities[i]+=Vector3.DOWN*8.5*delta
  nodes[i].global_position+=velocities[i]*delta;_orient(nodes[i],velocities[i])
  var fade:=clampf(remaining[i]/lifetimes[i],.06,1.)
  nodes[i].scale=Vector3(.7*fade,.7*fade,maxf(.12,velocities[i].length()/4.)*fade)
  active=true
 if not active:set_process(false)

func _generation_of(source:Node)->int:
 var generation:Variant=source.get("lab_resets")
 return int(generation) if generation!=null else 0

func warm_render()->Dictionary:
 if _warmed:return {"already_warmed":true,"pool":LIMIT}
 if _warming:
  while _warming:await get_tree().process_frame
  return {"already_warmed":true,"pool":LIMIT}
 if DisplayServer.get_name()=="headless":return {"skipped":"headless","pool":LIMIT}
 _warming=true
 var started:=Time.get_ticks_usec()
 var viewport:=SubViewport.new();viewport.size=Vector2i(16,16);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(viewport)
 var camera:=Camera3D.new();camera.position=Vector3(0,0,1);camera.current=true;viewport.add_child(camera)
 var visual:=MeshInstance3D.new();visual.mesh=nodes[0].mesh;visual.material_override=nodes[0].material_override;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 visual.scale=Vector3(10,10,3);viewport.add_child(visual)
 for i in 3:
  await get_tree().process_frame;await RenderingServer.frame_post_draw
 viewport.queue_free();_warmed=true;_warming=false
 return {"rendered_frames":3,"pool":LIMIT,"usec":Time.get_ticks_usec()-started}
