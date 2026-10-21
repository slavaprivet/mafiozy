extends RefCounted
## Contact-joint motion. CharacterBody sweep or native rigid-body force owns travel.
const LIVE_MASS := 65.0
const MAX_FORCE := 300.0
const MAX_SPEED := 2.0
var _channel: Dictionary = {}
var _rig_ref: WeakRef
var _generation := -1
var _request_frame := -100
var _step_frame := -1
var _requested := Vector3.ZERO
var _desired_velocity := Vector3.ZERO
var _velocity := Vector3.ZERO
var _body_previous := Vector3.ZERO
var _anchor_previous := Vector3.ZERO
var _body_id := -1
var _report: Dictionary = {"accepted":false,"actual_delta":Vector3.ZERO,"anchor_delta":Vector3.ZERO,"requested_delta":Vector3.ZERO,"force":Vector3.ZERO,"blocked":false}
var max_force := 0.0
var max_speed := 0.0
var moves := 0

func _anchor(channel: Dictionary) -> Vector3:
 var ref: WeakRef=channel.get("rig_ref")
 var rig: Skeleton3D=ref.get_ref() if ref!=null else null
 var bone:=int(channel.get("bone",-1))
 if not is_instance_valid(rig) or bone<0 or bone>=rig.get_bone_count():return Vector3.INF
 return rig.global_transform*rig.get_bone_global_pose(bone)*Vector3(channel.get("entry_local",Vector3.ZERO))

func _valid(host: Node, channel: Dictionary) -> bool:
 if channel.is_empty() or not channel.get("actual_hit",false) or not channel.get("valid",false) or channel.get("withdrawn",false):return false
 if not channel.get("active",false) or str(channel.get("weapon",""))!="spear":return false
 if bool(host.get("_lab_reset_pending")):return false
 if int(channel.get("generation",-1))!=int(host.get("lab_resets")):return false
 var ref: WeakRef=channel.get("rig_ref")
 var rig: Skeleton3D=ref.get_ref() if ref!=null else null
 if not is_instance_valid(rig) or rig!=host.get("_npc_rig") or not _anchor(channel).is_finite():return false
 var weapon: Node=host.get("_sword")
 if not is_instance_valid(weapon) or weapon.get_instance_id()!=int(channel.get("weapon_instance_id",-1)):return false
 if str(host.get("_weapon_id"))!="spear" or host.get("_sword_grounded") or host.get("_unarmed") or not host.get("_selected"):return false
 if host.has_method("_shield_guard_active29") and host.call("_shield_guard_active29"):return false
 var severed: Dictionary=host.get("_npc_severed")
 var bone:=int(channel.bone)
 while bone>=0:
  if severed.has(rig.get_bone_name(bone)):return false
  bone=rig.get_bone_parent(bone)
 return is_instance_valid(host.get("_npc_body"))

func request(host: Node, channel: Dictionary, requested_delta: Vector3, delta: float) -> Dictionary:
 if not requested_delta.is_finite() or not is_finite(delta) or delta<=0.0 or delta>.1 or not _valid(host,channel):
  _request_frame=-100;_desired_velocity=Vector3.ZERO
  return {"accepted":false,"actual_delta":Vector3.ZERO,"anchor_delta":Vector3.ZERO,"requested_delta":requested_delta,"force":Vector3.ZERO,"blocked":true}
 # A heartbeat without traction must not unpin a stationary laboratory actor
 # into gravity before the holder has actually requested joint movement.
 if _channel.is_empty() and Vector3(requested_delta.x,0,requested_delta.z).is_zero_approx():
  return {"accepted":true,"actual_delta":Vector3.ZERO,"anchor_delta":Vector3.ZERO,"requested_delta":Vector3.ZERO,"force":Vector3.ZERO,"blocked":false,"frame":-1}
 var rig: Skeleton3D=host.get("_npc_rig")
 var body: Node3D=host.get("_npc_body")
 if not is_same(_channel,channel) or _rig_ref==null or _rig_ref.get_ref()!=rig or _generation!=int(host.get("lab_resets")) or _body_id!=body.get_instance_id():
  _velocity=Vector3.ZERO;_body_previous=body.global_position;_anchor_previous=_anchor(channel)
  _report={"accepted":true,"actual_delta":Vector3.ZERO,"anchor_delta":Vector3.ZERO,"requested_delta":Vector3.ZERO,"force":Vector3.ZERO,"blocked":false}
  _body_id=body.get_instance_id();_rig_ref=weakref(rig);_generation=int(host.get("lab_resets"));_step_frame=-1
 _channel=channel;_request_frame=Engine.get_physics_frames()
 _requested=Vector3(requested_delta.x,0,requested_delta.z).limit_length(MAX_SPEED*delta)
 _desired_velocity=_requested/delta
 var result:=_report.duplicate()
 result["accepted"]=true
 return result

func advance(host: Node, delta: float) -> bool:
 if not is_finite(delta) or delta<=0.0 or delta>.1:return false
 var body: CharacterBody3D=host.get("_npc_body")
 var rig: Skeleton3D=host.get("_npc_rig")
 if bool(host.get("_lab_reset_pending")) or not is_instance_valid(body) or _rig_ref==null or _rig_ref.get_ref()!=rig or _generation!=int(host.get("lab_resets")) or _body_id!=body.get_instance_id():
  _channel={};_velocity=Vector3.ZERO;return false
 var current:=_valid(host,_channel) and Engine.get_physics_frames()-_request_frame<=2
 var corpse: RigidBody3D=host.get("_npc_corpse31")
 if bool(host.get("_npc_dead")) and not is_instance_valid(corpse):return false
 if not current and (is_instance_valid(corpse) or _velocity.length()<.015):
  _channel={};_velocity=Vector3.ZERO;return false
 if _step_frame==Engine.get_physics_frames():return true
 _step_frame=Engine.get_physics_frames()
 var desired:=_desired_velocity if current else Vector3.ZERO
 var anchor:=_anchor(_channel)
 if not anchor.is_finite():_channel={};_velocity=Vector3.ZERO;return false
 var before:=body.global_position
 var actual:=before-_body_previous
 var anchor_delta:=anchor-_anchor_previous
 var force:=Vector3.ZERO
 var collided:=false
 if is_instance_valid(corpse):
  var point_velocity:=corpse.linear_velocity+corpse.angular_velocity.cross(anchor-corpse.global_position)
  point_velocity.y=0.0
  force=((desired-point_velocity)*corpse.mass*10.0).limit_length(minf(MAX_FORCE,corpse.mass*MAX_FORCE/LIVE_MASS))
  corpse.apply_force(force,anchor-corpse.global_position)
  _velocity=Vector3(corpse.linear_velocity.x,0,corpse.linear_velocity.z)
 else:
  # Single movement owner while the joint or finite release braking is active.
  force=((desired-_velocity)*LIVE_MASS*10.0).limit_length(MAX_FORCE)
  _velocity=(_velocity+force/LIVE_MASS*delta).limit_length(MAX_SPEED)
  var vertical:=body.velocity.y
  body.velocity=_velocity
  body.velocity.y=-.5 if body.is_on_floor() else vertical-9.8*delta
  body.move_and_slide()
  actual=body.global_position-before
  collided=body.get_slide_collision_count()>0 and Vector3(actual.x,0,actual.z).length()+.0001<_velocity.length()*delta
  _velocity=Vector3(body.velocity.x,0,body.velocity.z)
  anchor_delta=_anchor(_channel)-anchor
 _body_previous=body.global_position;_anchor_previous=_anchor(_channel)
 _report={"accepted":current,"actual_delta":Vector3(actual.x,0,actual.z),"anchor_delta":anchor_delta,"requested_delta":_requested,"force":force,"blocked":collided,"rigid":is_instance_valid(corpse),"frame":_step_frame}
 max_force=maxf(max_force,force.length());max_speed=maxf(max_speed,_velocity.length());moves+=1
 # Reuse the bounded local contact spring at the actual retained entry bone.
 if current and force.length()>1.0 and not host.get("_npc_dead"):
  var part:=str(rig.get_bone_name(int(_channel.bone)))
  var reaction: RefCounted=host.get("_contact_reaction29")
  if reaction!=null:
   for hit: Node in rig.find_children("*","AnimatableBody3D",true,false):
    if str(hit.get_meta("sword_npc_part",""))==part:
     reaction.call("observe",host,{"collider":hit,"position":anchor,"_velocity":force/LIVE_MASS*delta*8.0})
     break
 return true

func status() -> Dictionary:
 var result:=_report.duplicate()
 result["max_force"]=max_force;result["max_speed"]=max_speed;result["moves"]=moves
 return result
