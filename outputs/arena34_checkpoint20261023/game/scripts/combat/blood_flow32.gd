extends Node3D
## One bounded world-space cosmetic pool. No health/geometry/weapon authority.
const CAPACITY := 256
const SOURCE_LIMIT := 24
const HOST_SOURCES := 4
const SOURCE_PARTICLES := 24
const FRAME_SPAWNS := 48
const HEARTBEAT := 0.18
const LIFE := 0.48
var sources: Dictionary = {}
var visual: MultiMeshInstance3D
var _position := PackedVector3Array()
var _velocity := PackedVector3Array()
var _age := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _newer := PackedInt32Array()
var _owners: Array[String] = []
var _buffer := PackedFloat32Array()
var _cursor := 0
var _round := 0
var _clock := 0.0
var _spawned := 0
var _ray_budget := 0
var emitted := 0
var active := 0
var peak_active := 0
var max_frame_spawns := 0
var max_frame_rays := 0
var last_update_usec := 0
var max_update_usec := 0
var quality_enabled := true

static func prepare(host: Node) -> Node:
 if not is_instance_valid(host) or not host.is_inside_tree(): return null
 var root: Node = host.get_tree().root
 var found: Node = root.get_node_or_null("BloodFlow32")
 if is_instance_valid(found): return found
 var pool: Node = load("res://scripts/combat/blood_flow32.gd").new()
 pool.name = "BloodFlow32"
 root.add_child(pool)
 return pool

static func touch(host: Node, key: String, point: Vector3, normal: Vector3, strength: float, generation: int, anchor: Node) -> bool:
 if not is_instance_valid(host) or not is_instance_valid(anchor) or not point.is_finite() or not normal.is_finite() or normal.length_squared()<0.01 or not is_finite(strength): return false
 var pool: Node = prepare(host)
 return bool(pool._touch(host,key,point,normal.normalized(),clampf(strength,0.0,1.0),generation,anchor)) if is_instance_valid(pool) else false

static func track_skin(host: Node, key: String, node: MeshInstance3D, rig: Skeleton3D, arrays: Array, triangle: Vector3i, bary: Vector3, strength: float, duration: float) -> bool:
 if not is_instance_valid(node) or not is_instance_valid(rig) or node.skin==null: return false
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var corners: Array=[]
 for index: int in [triangle.x,triangle.y,triangle.z]:
  if index<0 or index>=vertices.size() or index*4+3>=bones.size() or index*4+3>=weights.size(): return false
  var influences: Array=[]
  for slot in 4:
   var weight: float=weights[index*4+slot]
   var bind: int=bones[index*4+slot]
   if weight<=0.0: continue
   if bind<0 or bind>=node.skin.get_bind_count(): return false
   var name: StringName=node.skin.get_bind_name(bind)
   var bone: int=rig.find_bone(name) if name!=&"" else node.skin.get_bind_bone(bind)
   if bone<0 or bone>=rig.get_bone_count(): return false
   influences.append({"bone":bone,"point":node.skin.get_bind_pose(bind)*vertices[index],"weight":weight})
  corners.append(influences)
 var source_normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var edge_normal := (vertices[triangle.y]-vertices[triangle.x]).cross(vertices[triangle.z]-vertices[triangle.x])
 var normal_sign := 1.0
 if source_normals.size()==vertices.size():
  var authored := source_normals[triangle.x]*bary.x+source_normals[triangle.y]*bary.y+source_normals[triangle.z]*bary.z
  normal_sign=-1.0 if edge_normal.dot(authored)<0.0 else 1.0
 var skin := {"normal_sign":normal_sign,"rig":weakref(rig),"node":weakref(node),"mesh":weakref(node.mesh),"corners":corners,"bary":bary}
 var sample := _skin_sample(skin)
 if sample.is_empty(): return false
 var pool: Node=prepare(host)
 if not bool(pool._touch(host,key,sample.point,sample.normal,strength,0,node)): return false
 var id := str(host.get_instance_id())+":"+key
 if not pool.sources.has(id): return true
 pool.sources[id].skin=skin
 pool.sources[id].until=pool._clock+clampf(duration,0.1,12.0)
 return true

static func register_player_cap(host: Node, retained: MeshInstance3D, piece: MeshInstance3D, gone_cap: Array) -> void:
 # Called only after a committed player MeshSever, with its actual cap arrays.
 if gone_cap.is_empty() or not is_instance_valid(retained) or retained.mesh==null or not is_instance_valid(piece): return
 var kept: Array=retained.mesh.surface_get_arrays(retained.mesh.get_surface_count()-1)
 var kept_triangle := _largest_triangle(kept)
 if kept_triangle.x>=0:
  track_skin(host,"player_cap_keep_"+str(retained.get_instance_id()),retained,host.get("_rig"),kept,kept_triangle,Vector3.ONE/3.0,1.0,12.0)
 var gone_triangle := _largest_triangle(gone_cap)
 if gone_triangle.x<0: return
 var vertices: PackedVector3Array=gone_cap[Mesh.ARRAY_VERTEX]
 var point := (vertices[gone_triangle.x]+vertices[gone_triangle.y]+vertices[gone_triangle.z])/3.0
 var normals: PackedVector3Array=gone_cap[Mesh.ARRAY_NORMAL]
 var normal := (normals[gone_triangle.x]+normals[gone_triangle.y]+normals[gone_triangle.z]).normalized()
 var key := "player_cap_piece_"+str(piece.get_instance_id())
 if not touch(host,key,piece.to_global(point),(piece.global_basis.inverse().transposed()*normal).normalized(),0.65,0,piece): return
 var pool: Node=prepare(host)
 var id := str(host.get_instance_id())+":"+key
 if pool.sources.has(id):
  pool.sources[id].rigid={"node":weakref(piece),"mesh":weakref(piece.mesh),"point":point,"normal":normal}
  pool.sources[id].until=pool._clock+3.0

static func _largest_triangle(arrays: Array) -> Vector3i:
 if arrays.size()!=Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX]==null or arrays[Mesh.ARRAY_INDEX]==null: return Vector3i(-1,-1,-1)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var largest := 0.0
 var result := Vector3i(-1,-1,-1)
 for offset in range(0,indices.size()-2,3):
  var a: int=indices[offset];var b: int=indices[offset+1];var c: int=indices[offset+2]
  if a<0 or b<0 or c<0 or a>=vertices.size() or b>=vertices.size() or c>=vertices.size(): continue
  var area := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared()
  if area>largest:largest=area;result=Vector3i(a,b,c)
 return result

static func _skin_sample(skin: Dictionary) -> Dictionary:
 var rig: Skeleton3D=skin.rig.get_ref()
 var node: MeshInstance3D=skin.node.get_ref()
 if not is_instance_valid(rig) or not is_instance_valid(node) or not rig.is_inside_tree() or not node.is_inside_tree() or rig.is_queued_for_deletion() or node.is_queued_for_deletion() or not node.is_visible_in_tree() or node.mesh!=skin.mesh.get_ref(): return {}
 var points: Array[Vector3]=[]
 for corner: Array in skin.corners:
  var point := Vector3.ZERO
  for influence: Dictionary in corner:
   point+=(rig.get_bone_global_pose(int(influence.bone))*Vector3(influence.point))*float(influence.weight)
  points.append(rig.global_transform*point)
 var normal := (points[1]-points[0]).cross(points[2]-points[0]).normalized()*float(skin.get("normal_sign",1.0))
 if normal.length_squared()<0.5: return {}
 var bary: Vector3=skin.bary
 return {"point":points[0]*bary.x+points[1]*bary.y+points[2]*bary.z,"normal":normal}

static func clear_host(host: Node) -> void:
 if not is_instance_valid(host) or not host.is_inside_tree(): return
 var pool: Node = host.get_tree().root.get_node_or_null("BloodFlow32")
 if is_instance_valid(pool): pool._clear_host(host.get_instance_id())

func _ready() -> void:
 _position.resize(CAPACITY); _velocity.resize(CAPACITY); _age.resize(CAPACITY)
 _radius.resize(CAPACITY); _newer.resize(CAPACITY); _newer.fill(-1)
 _owners.resize(CAPACITY); _owners.fill(""); _buffer.resize(CAPACITY*12)
 var shape := CylinderMesh.new()
 shape.top_radius=0.43; shape.bottom_radius=0.5; shape.height=1.0
 shape.radial_segments=6; shape.rings=1
 var material := StandardMaterial3D.new()
 material.albedo_color=Color(0.38,0.008,0.015); material.roughness=0.23
 material.metallic_specular=0.4; material.cull_mode=BaseMaterial3D.CULL_DISABLED
 shape.material=material
 var batch := MultiMesh.new()
 batch.transform_format=MultiMesh.TRANSFORM_3D; batch.mesh=shape
 batch.instance_count=CAPACITY; batch.visible_instance_count=0
 visual=MultiMeshInstance3D.new(); visual.name="ActualWoundStreams32"
 visual.multimesh=batch; visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(visual); visual.top_level=true; visual.global_transform=Transform3D.IDENTITY
 material.get_rid()

func _touch(host: Node, key: String, point: Vector3, normal: Vector3, strength: float, generation: int, anchor: Node) -> bool:
 var id := str(host.get_instance_id())+":"+key
 if strength<=0.0:
  _remove_source(id); return false
 if sources.has(id):
  var old: Dictionary=sources[id]
  if int(old.generation)!=generation or old.anchor.get_ref()!=anchor or Vector3(old.point).distance_to(point)>0.45:
   _remove_source(id)
 if not sources.has(id):
  # Coincident clothing/cap layers share one flow, rather than four stacked jets.
  for existing: Dictionary in sources.values():
   if int(existing.host_id)==host.get_instance_id() and int(existing.generation)==generation and Vector3(existing.point).distance_to(point)<0.025 and Vector3(existing.normal).dot(normal)>0.7:
    existing.seen=_clock; existing.strength=maxf(float(existing.strength),strength)
    return true
  var count := 0
  var weakest := ""
  var minimum := INF
  for existing_key: String in sources:
   var entry: Dictionary=sources[existing_key]
   if int(entry.host_id)!=host.get_instance_id(): continue
   count+=1
   if float(entry.strength)<minimum:minimum=float(entry.strength);weakest=existing_key
  if count>=HOST_SOURCES:
   if weakest.is_empty() or strength<=minimum+0.05: return false
   _remove_source(weakest)
  if sources.size()>=SOURCE_LIMIT: return false
  sources[id]={"host":weakref(host),"host_id":host.get_instance_id(),"anchor":weakref(anchor),"generation":generation,"point":point,"previous":point,"normal":normal,"strength":strength,"seen":_clock,"carry":0.0,"head":-1,"live":0,"floor":-INF,"reach":0.8,"probe":-1.0,"birth":_clock}
 var source: Dictionary=sources[id]
 source.point=point; source.normal=normal; source.strength=strength; source.seen=_clock
 return true

func _clear_host(id: int) -> void:
 for key: String in sources.keys():
  if int(sources[key].host_id)==id: _remove_source(key)
 _publish()

func _remove_source(key: String) -> void:
 for i in CAPACITY:
  if _owners[i]==key: _owners[i]=""; _newer[i]=-1
 sources.erase(key)

func _probe(source: Dictionary) -> void:
 if _ray_budget<2 or _clock<float(source.probe): return
 var host: Node=source.host.get_ref()
 if not is_instance_valid(host) or not host is Node3D: return
 var point: Vector3=source.point
 var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.015,point+Vector3.DOWN*2.5,1)
 query.collide_with_areas=false
 var exclusions: Array[RID]=[]
 var ancestor: Node=source.anchor.get_ref()
 while is_instance_valid(ancestor):
  if ancestor is CollisionObject3D: exclusions.append(ancestor.get_rid())
  ancestor=ancestor.get_parent()
 query.exclude=exclusions
 var space: PhysicsDirectSpaceState3D=host.get_world_3d().direct_space_state
 var hit: Dictionary=space.intersect_ray(query)
 source.floor=float(hit.position.y)+0.006 if not hit.is_empty() and Vector3(hit.normal).y>0.5 else -INF
 query.from=point+Vector3(source.normal)*0.004
 query.to=query.from+Vector3(source.normal)*0.65+Vector3.DOWN*0.35
 hit=space.intersect_ray(query)
 source.reach=point.distance_to(Vector3(hit.position)) if not hit.is_empty() else 0.8
 source.probe=_clock+0.20; _ray_budget-=2

func _spawn(key: String, source: Dictionary, inherited: Vector3) -> bool:
 if _spawned>=FRAME_SPAWNS or int(source.live)>=SOURCE_PARTICLES: return false
 var slot := -1
 for offset in CAPACITY:
  var index := (_cursor+offset)%CAPACITY
  if _owners[index].is_empty(): slot=index; break
 if slot<0: return false
 _cursor=(slot+1)%CAPACITY
 var strength: float=source.strength
 var point: Vector3=source.point
 var normal: Vector3=source.normal
 var speed := lerpf(0.16,0.72,strength)
 var pulse := 0.94+0.06*sin(_clock*7.0+float(source.host_id%17))
 _position[slot]=point+normal*0.001
 _velocity[slot]=normal*speed*pulse+Vector3.DOWN*0.12+inherited.limit_length(1.8)
 var strong_weight := smoothstep(0.35,1.0,strength)
 var side := normal.cross(Vector3.UP if absf(normal.y)<0.9 else Vector3.RIGHT).normalized()
 _velocity[slot]+=side*(sin(_clock*5.0+float(key.hash()%97)*.231)*0.015*strong_weight)
 _radius[slot]=lerpf(0.0015,0.0048,strength)+0.002*strong_weight
 _age[slot]=0.0; _owners[slot]=key; _newer[slot]=-1
 var head: int=source.head
 if head>=0 and _owners[head]==key: _newer[head]=slot
 source.head=slot; source.live=int(source.live)+1
 _spawned+=1; emitted+=1
 return true

func _process(delta: float) -> void:
 var started := Time.get_ticks_usec()
 if sources.is_empty() and active==0: return
 var dt := clampf(delta,0.0,0.05)
 _clock+=maxf(delta,0.0); _spawned=0; _ray_budget=8
 for key: String in sources.keys():
  var source: Dictionary=sources[key]
  var anchor: Node=source.anchor.get_ref()
  if source.has("skin"):
   var sample := _skin_sample(source.skin)
   if sample.is_empty() or _clock>=float(source.until) or Vector3(source.point).distance_to(Vector3(sample.get("point",source.point)))>0.45:
    _remove_source(key); continue
   source.point=sample.point; source.normal=sample.normal; source.seen=_clock
  if source.has("rigid"):
   var node: MeshInstance3D=source.rigid.node.get_ref()
   if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() or node.mesh!=source.rigid.mesh.get_ref() or _clock>=float(source.until):
    _remove_source(key); continue
   source.point=node.to_global(source.rigid.point)
   source.normal=(node.global_basis.inverse().transposed()*Vector3(source.rigid.normal)).normalized();source.seen=_clock
  if source.host.get_ref()==null or not source.host.get_ref().is_inside_tree() or not is_instance_valid(anchor) or not anchor.is_inside_tree() or anchor.is_queued_for_deletion() or _clock-float(source.seen)>HEARTBEAT:
   _remove_source(key)
 var keys: Array=sources.keys()
 for offset in keys.size():
  var key: String=keys[(_round+offset)%keys.size()]
  var source: Dictionary=sources[key]
  _probe(source)
  var inherited := (Vector3(source.point)-Vector3(source.previous))/maxf(dt,0.0001)
  source.previous=source.point
  if quality_enabled:
   source.carry=minf(3.0,float(source.carry)+dt*lerpf(28.0,60.0,float(source.strength)))
   var due := mini(2,int(source.carry))
   source.carry=float(source.carry)-float(due)
   for unused in due:
    if not _spawn(key,source,inherited): break
 _round+=1
 for i in CAPACITY:
  if _owners[i].is_empty(): continue
  var source: Dictionary=sources[_owners[i]]
  _age[i]+=dt
  _velocity[i]+=Vector3.DOWN*9.8*dt
  _position[i]+=_velocity[i]*dt
  if _age[i]>=LIFE or _position[i].y<float(source.floor) or _position[i].distance_to(Vector3(source.point))>float(source.reach):
   source.live=maxi(0,int(source.live)-1); _owners[i]=""; _newer[i]=-1
 _publish()
 max_frame_spawns=maxi(max_frame_spawns,_spawned); max_frame_rays=maxi(max_frame_rays,8-_ray_budget)
 last_update_usec=Time.get_ticks_usec()-started; max_update_usec=maxi(max_update_usec,last_update_usec)

func _publish() -> void:
 if not is_instance_valid(visual): return
 active=0
 for i in CAPACITY:
  if _owners[i].is_empty(): continue
  var start: Vector3=_position[i]
  var finish: Vector3=start-_velocity[i].normalized()*0.012
  var source: Dictionary=sources[_owners[i]]
  var next: int=_newer[i]
  var young := _age[i]<0.24 and float(source.strength)>=0.25
  if young and next>=0 and _owners[next]==_owners[i] and _age[next]<_age[i]:
   finish=_position[next]
  elif young and int(source.head)==i:
   finish=source.point
  if start.distance_to(finish)>0.13: finish=start-_velocity[i].normalized()*0.014
  var direction := finish-start
  var length := maxf(0.003,direction.length())
  var y := direction.normalized() if direction.length_squared()>1e-10 else Vector3.UP
  var x := y.cross(Vector3.RIGHT if absf(y.y)>0.9 else Vector3.UP).normalized()
  var z := x.cross(y).normalized()
  var width := _radius[i]*2.0*lerpf(1.0,0.38,clampf(_age[i]/LIFE,0.0,1.0))
  var center := (start+finish)*0.5
  x*=width; y*=length+width*0.4; z*=width
  var at := active*12
  _buffer[at]=x.x;_buffer[at+1]=y.x;_buffer[at+2]=z.x;_buffer[at+3]=center.x
  _buffer[at+4]=x.y;_buffer[at+5]=y.y;_buffer[at+6]=z.y;_buffer[at+7]=center.y
  _buffer[at+8]=x.z;_buffer[at+9]=y.z;_buffer[at+10]=z.z;_buffer[at+11]=center.z
  active+=1
 if active>0: visual.multimesh.buffer=_buffer
 visual.multimesh.visible_instance_count=active
 peak_active=maxi(peak_active,active)

func status() -> Dictionary:
 return {"sources":sources.size(),"active":active,"emitted":emitted,"peak_active":peak_active,"capacity":CAPACITY,"source_limit":SOURCE_LIMIT,"max_frame_spawns":max_frame_spawns,"spawn_limit":FRAME_SPAWNS,"max_frame_rays":max_frame_rays,"max_update_usec":max_update_usec,"last_update_usec":last_update_usec}