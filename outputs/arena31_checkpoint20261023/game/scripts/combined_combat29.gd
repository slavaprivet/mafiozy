extends "res://scripts/clay_target.gd"
## Production actor laws own health and armour; clay owns only permitted geometry.
var _common_routing29 := false
var _common_damage29: Dictionary = {}
var _common_damage_frames29: Dictionary = {}
var _common_axis29 := Vector3.FORWARD
var common_last_contact29: Dictionary = {}

func _init() -> void:
 lab_fixed=false
 lab_regrow=false
 lab_armored=false

func _dress_knight() -> void:
 if not is_instance_valid(_npc_rig):return
 var result:=set_npc_armor31(ENEMY_KNIGHT_ARMOR)
 if not result.get("ok",false):push_error("Enemy knight armor binding failed: "+str(result))
 _enemy_armor_tier="medium"

func _update_city_npc(delta: float) -> void:
 # Laboratory actors are spawned externally; production must let the base AI
 # create its actor before the laboratory subclass's null-rig early return.
 if not is_instance_valid(_npc_rig):
  _production_update_city_npc29(delta)
  return
 super._update_city_npc(delta)

func _spawn_resident_knight(at: Vector3) -> bool:
 var previous: Skeleton3D=_npc_rig
 var ok:=super._spawn_resident_knight(at)
 if ok and previous!=_npc_rig:
  lab_resets+=1
  _common_damage29.clear();_common_damage_frames29.clear()
  _async_cut28.cancel("production_actor_changed")
  _clay_invalidate_motion28()
  _async_cut28.warm(self)
  _deep_collapse29.prepare(self)
 return ok

func _common_hit_body29(part: String) -> CollisionObject3D:
 if not is_instance_valid(_npc_rig):return null
 for node: Node in _npc_rig.find_children("*","CollisionObject3D",true,false):
  if str(node.get_meta("sword_npc_part",""))==part:return node as CollisionObject3D
 return null

func _common_permission29(part: String, point: Vector3, motion: Vector3, normal: Vector3, kind: String) -> Dictionary:
 if not motion.is_finite() or motion.length_squared()<1.0e-8:return {"penetrates":false}
 var body:=_common_hit_body29(part)
 if body==null:return {"penetrates":false}
 var incoming:=_impact_damage31(motion.length()*.6,_strength_now(),kind)
 var incidence:=clampf(-motion.normalized().dot(normal.normalized()),0.0,1.0) if normal.length_squared()>.5 else 0.0
 var protection:=ArmorDamage31.resolve(_npc_armor_loadout31,part,kind,incoming,_armor_point31(_npc_rig,part,point,body),incidence)
 var factor:=float(protection.factor)
 if _weapon_id=="sword" and kind=="flat":factor*=.12
 if _half_sword:
  if kind=="stab" and protection.region=="joint":factor=maxf(factor,HALF_SWORD_THRUST)
  elif kind!="stab":factor*=HALF_SWORD_CUT
 var damage:=incoming*factor
 return {"part":part,"penetrates":ArmorDamage31.tissue_penetrates(str(protection.region),kind,damage),"region":protection.region,"kind":kind,"residual":damage,"incoming":incoming,"incidence":incidence,"sever_contact":false}

func _common_route_damage29(hit: Dictionary, points: PackedVector3Array, now: int, touched: Dictionary) -> void:
 _common_damage29={}
 var collider: Object=hit.get("collider")
 var id:=collider.get_instance_id() if is_instance_valid(collider) else -1
 if int(_common_damage_frames29.get(id,-1))==Engine.get_physics_frames():return
 # Preserve the accepted free-blade/contact solver around the inherited HP law.
 var direction:=_dir;var omega:=_omega;var block_push:=_block_push;var body_push:=_body_push
 _common_axis29=direction
 _common_routing29=true
 _production_resolve_contact29(hit,points,now,touched)
 _common_routing29=false
 _dir=direction;_omega=omega;_block_push=block_push;_body_push=body_push
 if not _common_damage29.is_empty():_common_damage_frames29[id]=Engine.get_physics_frames()

func _production_axis29() -> Vector3:
 return _common_axis29 if _common_routing29 else _dir

func _edge_motion(motion: Vector3) -> float:
 if not _common_routing29 or _weapon_id=="sword":return super._edge_motion(motion)
 var along:=absf(motion.normalized().dot(_common_axis29))
 return sqrt(maxf(0.0,1.0-along*along))

func _npc_take_blade_part(part: String, point: Vector3, speed: float, direction: Vector3, damage: float, sever_contact: bool = false, penetrates: bool = true) -> void:
 if not _common_routing29:
  super._npc_take_blade_part(part,point,speed,direction,damage,sever_contact,penetrates)
  return
 # The parent still applies exact HP, cumulative wounds, death and disarming.
 # Its old synchronous sever is replaced by the guarded clay worker below.
 super._npc_take_blade_part(part,point,speed,direction,damage,false,penetrates)
 _common_damage29={"part":part,"damage":damage,"penetrates":penetrates,"sever_contact":sever_contact,"part_hp":float(_npc_part_hp.get(part,INF))}

func _resolve_contact(hit: Dictionary, points: PackedVector3Array, now: int, touched: Dictionary) -> void:
 if _shield_guard_active29():return
 var collider: Object=hit.get("collider")
 if not is_instance_valid(collider) or not collider.has_meta("sword_npc_part") or _weapon_crush:
  _contact_reaction29.observe(self,hit)
  _production_resolve_contact29(hit,points,now,touched)
  return
 var part:=str(collider.get_meta("sword_npc_part",""))
 var motion: Vector3=hit.get("_velocity",Vector3.ZERO)
 var kind:="stab" if Puncture29.axial_contact(_weapon_id,_weapon_crush,motion,_dir.normalized()) else ("slice" if _edge_motion(motion)>=.72 else "flat")
 var permission:=_common_permission29(part,hit.position,motion,hit.get("normal",Vector3.ZERO),kind)
 _common_route_damage29(hit,points,now,touched)
 if not _common_damage29.is_empty():permission.merge(_common_damage29,true)
 common_last_contact29=permission.duplicate(true)
 permission["frame"]=Engine.get_physics_frames()
 _common_damage29=permission
 if not permission.get("penetrates",false):
  _contact_reaction29.observe(self,hit)
  return
 super._resolve_contact(hit,points,now,touched)

func _clay_queue_slice28(part: String, point: Vector3, motion: Vector3, speed: float) -> bool:
 if int(_common_damage29.get("frame",-1))!=Engine.get_physics_frames() or str(_common_damage29.get("part",""))!=part or not _common_damage29.get("penetrates",false) or not _common_damage29.get("sever_contact",false) or float(_common_damage29.get("part_hp",INF))>0.0:return false
 return super._clay_queue_slice28(part,point,motion,speed)

func _puncture_permission29(part: String, entry: Vector3, axis: Vector3, speed: float, normal: Vector3 = Vector3.ZERO) -> bool:
 if _shield_guard_active29() or _npc_severed.has(part):return false
 var permission:=_common_permission29(part,entry,axis*speed,normal,"stab")
 common_last_contact29=permission.duplicate(true)
 return bool(permission.get("penetrates",false))

func _puncture_accepted29(part: String, entry: Vector3, axis: Vector3, speed: float, normal: Vector3 = Vector3.ZERO) -> void:
 var body:=_common_hit_body29(part)
 if body==null or normal.length_squared()<.5:return
 var hit:={"collider":body,"position":entry,"normal":normal,"rid":body.get_rid(),"_velocity":axis*speed,"_speed":speed,"_index":0}
 _common_route_damage29(hit,PackedVector3Array([entry]),Time.get_ticks_msec(),{})
