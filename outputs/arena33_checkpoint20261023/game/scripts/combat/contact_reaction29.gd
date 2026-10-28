extends RefCounted
## Local contact springs. Never changes the actor root, weapon response or damage.
const PART_PREFIXES := ["head", "upperarm", "forearm", "hand", "thigh", "shin", "foot"]
var _rig_ref: WeakRef
var _generation := -1
var _fixed := true
var _states: Dictionary = {}
var _step_frame := -1
var contacts := 0
var max_translation_m := 0.0
var max_rotation_rad := 0.0

func _restore() -> void:
 var rig: Skeleton3D = _rig_ref.get_ref() if _rig_ref != null else null
 if not is_instance_valid(rig): return
 for row: Dictionary in _states.values():
  if row.has("applied") and row.bone < rig.get_bone_count() and rig.get_bone_pose(row.bone).is_equal_approx(row.applied):
   rig.set_bone_pose(row.bone,row.base)
  row.erase("applied")
 rig.force_update_all_bone_transforms()

func _bind(host: Node) -> Skeleton3D:
 var rig: Skeleton3D = host.get("_npc_rig")
 var old: Skeleton3D = _rig_ref.get_ref() if _rig_ref != null else null
 var generation: int = host.get("lab_resets")
 var fixed: bool = host.get("lab_fixed")
 if old != rig or generation != _generation or fixed != _fixed:
  _restore(); _states.clear(); _step_frame=-1
  _rig_ref=weakref(rig) if is_instance_valid(rig) else null
  _generation=generation; _fixed=fixed
 return rig

func _removed(host: Node, rig: Skeleton3D, bone: int) -> bool:
 var severed: Dictionary = host.get("_npc_severed")
 var at := bone
 while at >= 0:
  if severed.has(rig.get_bone_name(at)): return true
  at=rig.get_bone_parent(at)
 return false

func observe(host: Node, hit: Dictionary) -> void:
 if host.get("_npc_dead") or host.get("_lab_reset_pending"): return
 if host.has_method("_shield_guard_active29") and host.call("_shield_guard_active29"): return
 if not host.get("_held") and not host.get("_clay_idle_sweep28"): return
 var collider: Object = hit.get("collider")
 if not is_instance_valid(collider) or not collider.has_meta("sword_npc_part"): return
 var part := str(collider.get_meta("sword_npc_part"))
 if part.trim_suffix("_l").trim_suffix("_r") not in PART_PREFIXES: return
 var velocity: Vector3 = hit.get("_velocity",Vector3.ZERO)
 if not velocity.is_finite() or velocity.length_squared()<0.0025: return
 var rig := _bind(host)
 if not is_instance_valid(rig): return
 var bone := rig.find_bone(part)
 if bone<0 or _removed(host,rig,bone): return
 var frame := Engine.get_physics_frames()
 var row: Dictionary = _states.get(part,{"bone":bone,"position":Vector3.ZERO,"velocity":Vector3.ZERO,"angle":Vector3.ZERO,"angular_velocity":Vector3.ZERO,"last_contact":-100})
 if frame-int(row.last_contact)<3: return
 row.last_contact=frame
 var parent := rig.get_bone_parent(bone)
 var parent_basis := rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
 var local_to_world := rig.global_basis * parent_basis * rig.get_bone_rest(bone).basis
 var world_origin := rig.global_transform * rig.get_bone_global_pose(bone).origin
 var lever: Vector3 = Vector3(hit.get("position",world_origin))-world_origin
 var torque := lever.cross(velocity)
 row.velocity += local_to_world.inverse() * velocity.limit_length(8.0) * 0.10
 if torque.length_squared()>0.000001:
  row.angular_velocity += (local_to_world.inverse()*torque.normalized()).normalized()*minf(velocity.length()*0.40,2.4)
 row.velocity=Vector3(row.velocity).limit_length(1.5)
 row.angular_velocity=Vector3(row.angular_velocity).limit_length(3.0)
 _states[part]=row; contacts+=1

func before_pose(host: Node) -> void:
 _bind(host)
 _restore()

func after_pose(host: Node, delta: float) -> void:
 var rig := _bind(host)
 if not is_instance_valid(rig): return
 if host.get("_npc_dead") or host.get("_lab_reset_pending"):
  _states.clear(); return
 var frame := Engine.get_physics_frames()
 var integrate := frame != _step_frame
 _step_frame=frame
 var dt := clampf(delta,0.0,0.1)
 var steps := maxi(1,ceili(dt/0.016667))
 var h := dt/steps
 for part: String in _states.keys():
  var row: Dictionary=_states[part]
  if _removed(host,rig,row.bone): _states.erase(part); continue
  if integrate:
   for i in steps:
    row.velocity += (-160.0*Vector3(row.position)-26.0*Vector3(row.velocity))*h
    row.position += Vector3(row.velocity)*h
    row.angular_velocity += (-110.0*Vector3(row.angle)-21.0*Vector3(row.angular_velocity))*h
    row.angle += Vector3(row.angular_velocity)*h
  var parent := rig.get_bone_parent(row.bone)
  var parent_basis := rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
  var local_to_world := rig.global_basis*parent_basis*rig.get_bone_rest(row.bone).basis
  var travel := (local_to_world*Vector3(row.position)).length()
  var limit_m := 0.018 if part=="head" else 0.025
  if travel>limit_m:
   row.position *= limit_m/travel
   row.velocity=Vector3.ZERO
  var limit_angle := deg_to_rad(8.0 if part=="head" or part.begins_with("thigh") or part.begins_with("shin") else 12.0)
  row.angle=Vector3(row.angle).limit_length(limit_angle)
  max_translation_m=maxf(max_translation_m,(local_to_world*Vector3(row.position)).length())
  max_rotation_rad=maxf(max_rotation_rad,Vector3(row.angle).length())
  var base := rig.get_bone_pose(row.bone)
  var pose := base
  pose.origin += Vector3(row.position)
  var angle: Vector3=row.angle
  if angle.length_squared()>0.00000001:pose.basis=Basis(angle.normalized(),angle.length())*base.basis
  row.base=base; row.applied=pose
  rig.set_bone_pose(row.bone,pose)
 rig.force_update_all_bone_transforms()

func stats() -> Dictionary:
 var displacement:=0.0;var rotation:=0.0
 for row: Dictionary in _states.values():
  displacement=maxf(displacement,Vector3(row.position).length())
  rotation=maxf(rotation,Vector3(row.angle).length())
 return {"contacts":contacts,"active_parts":_states.size(),"local_displacement":displacement,"rotation_rad":rotation,"max_translation_m":max_translation_m,"max_rotation_rad":max_rotation_rad,"generation":_generation}
