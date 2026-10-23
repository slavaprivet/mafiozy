extends RefCounted
## Finite hand compliance after actual sword skin entry or a swept tissue hit.
## Free steering stays unchanged. The rendered blade follows the re-solved palm;
## inward walking is loaded only through native velocity during tissue overlap.
## A refused IK pose restores every bone; no player transform is assigned.
const Puncture = preload("res://scripts/combat/puncture29.gd")
const Resistance = preload("res://scripts/combat/blade_resistance28.gd")
const MAX_LAG := 0.035
const SLOW_FRACTION := 0.20
const GUIDE_LIMIT29 := 0.025
const GUIDE_RATE29 := 0.35
var _guide_correction29 := Vector3.ZERO
var lag := 0.0
var last: Dictionary = {}
var _identity := ""
var _frame := -1
var _requested_tip := Vector3.INF
var _requested_origin := Vector3.INF
var _entry := Vector3.ZERO
var _axis := Vector3.ZERO
var _applied_origin := Vector3.INF
var last_walk29: Dictionary = {}
var _walk_identity := ""
var _walk_entry := Vector3.ZERO
var _walk_frame := -1
var _walk_target_velocity := Vector3.ZERO
var _regrab_identity31 := ""
var _regrab_depth31 := 0.0
var _regrab_player31 := Vector3.ZERO
var _regrab_entry31 := Vector3.ZERO

func adopt_regrab31(host: Node) -> bool:
	var data:=_channel(host)
	if data.is_empty() or not bool(data.row.get("active",false)):return false
	var depth:float=(Puncture.tip_world(host)-Vector3(data.entry)).dot(Vector3(data.axis))
	if depth<=0.0:return false
	clear("regrab_same_wound")
	_identity=data.identity;_regrab_identity31=data.identity;_regrab_depth31=depth
	_regrab_player31=host.get("_player").global_position;_regrab_entry31=data.entry
	_requested_tip=Puncture.tip_world(host);_requested_origin=host.get("_sword_origin")
	_entry=data.entry;_axis=data.axis;_frame=Engine.get_physics_frames()
	return true

func clear(reason: String = "clear") -> void:
	_regrab_identity31=""
	_guide_correction29=Vector3.ZERO
	lag=0.0;_identity="";_frame=-1;_requested_tip=Vector3.INF
	_requested_origin=Vector3.INF
	_applied_origin=Vector3.INF;_axis=Vector3.ZERO
	_walk_identity="";_walk_frame=-1;_walk_target_velocity=Vector3.ZERO
	last_walk29={"active":false,"reason":reason}
	last={"active":false,"reason":reason}

# Forward travel increases elastic deflection. Withdrawal carries the existing
# deflection out freely; removing it inside the skin would jump the tip forward.
# Once the requested tip is outside, restoring the hand cannot re-enter skin.
static func next_lag29(current: float, advance: float, speed: float, outside: bool, delta: float = 1.0/60.0) -> float:
	if outside:return move_toward(current,0.0,0.4*maxf(0.0,delta))
	if advance<=0.0:return current
	var factor:=Resistance.sword_load_factor29(speed)
	if factor<=0.0:return maxf(0.0,current-advance)
	return minf(MAX_LAG,current+advance*SLOW_FRACTION*factor)

func _eligible29(host: Node) -> bool:
	if not bool(host.get("_ready")) or not bool(host.get("_selected")):return false
	var world:Node=host.get("_world")
	if not is_instance_valid(world) or bool(world.get("preview_dead")):return false
	var player:Node=host.get("_player")
	if not is_instance_valid(player) or player.get("_mount_mode") or player.get("_swimming") or player.get("_vehicle_hold"):return false
	if host.has_method("_shield_guard_active29") and bool(host.call("_shield_guard_active29")):return false
	return true

func _channel(host: Node) -> Dictionary:
	if not _eligible29(host):return {}
	if str(host.get("_weapon_id"))!="sword" or bool(host.get("_unarmed")) or bool(host.get("_sword_grounded")):return {}
	var weapon:Node3D=host.get("_sword")
	if not is_instance_valid(weapon) or not weapon.visible:return {}
	var row:Dictionary=host.get_meta("puncture29_channel",{})
	if not row.get("valid",false) or not row.get("actual_hit",false) or row.get("withdrawn",false):return {}
	if str(row.get("weapon",""))!="sword" or int(row.get("weapon_instance_id",-1))!=weapon.get_instance_id() or int(row.get("generation",-1))!=int(host.get("lab_resets")):return {}
	var ref:WeakRef=row.get("rig_ref")
	var rig:Skeleton3D=ref.get_ref() if ref!=null else null
	var bone:=int(row.get("bone",-1))
	if not is_instance_valid(rig) or bone<0 or bone>=rig.get_bone_count():return {}
	var wound_ref:WeakRef=row.get("node_ref")
	var wound:Node=wound_ref.get_ref() if wound_ref!=null else null
	if not is_instance_valid(wound):return {}
	var anchor:Transform3D=rig.global_transform*rig.get_bone_global_pose(bone)
	var entry:Vector3=anchor*Vector3(row.entry_local)
	var axis:Vector3=(anchor.basis*Vector3(row.axis_local)).normalized()
	return {"row":row,"entry":entry,"axis":axis,"kind":"puncture","identity":"%s:%s:%s:%s"%[row.weapon_instance_id,row.generation,rig.get_instance_id(),wound.get_instance_id()]}

func _cut_contact(host: Node) -> Dictionary:
	if not _eligible29(host):return {}
	if str(host.get("_weapon_id"))!="sword" or bool(host.get("_unarmed")) or bool(host.get("_sword_grounded")):return {}
	var resistance:RefCounted=host.get("_resistance28")
	if resistance==null or not bool(resistance.call("_identity",host)):return {}
	var contact:Dictionary=resistance.contact
	var collider:CollisionObject3D=contact.collider.get_ref()
	var shape:CollisionShape3D=contact.shape.get_ref()
	if not is_instance_valid(collider) or not is_instance_valid(shape) or shape.disabled or collider.collision_layer==0:return {}
	var origin:Vector3=host.get("_sword_origin")
	var direction:Vector3=host.get("_dir")
	var interval:Vector2=resistance.call("_interval",shape,origin+direction*0.06,origin+direction*(0.06+float(host.get("_weapon_length"))))
	if interval.x<0.0:return {}
	return {"kind":"cut","shape":shape,"entry":shape.global_position,"axis":Vector3(contact.incoming).normalized(),"speed":float(contact.get("speed",0.0)),"identity":"cut:%s:%s:%s"%[host.get("lab_resets"),host.get("_sword").get_instance_id(),collider.get_instance_id()]}

func _world_blocked(host: Node, data: Dictionary, direction: Vector3, origin: Vector3) -> bool:
	var player:CharacterBody3D=host.get("_player")
	if not is_instance_valid(player):return true
	var target:Skeleton3D=host.get("_npc_rig")
	if data.kind=="puncture":target=data.row.rig_ref.get_ref()
	var length:float=0.06+float(host.get("_weapon_length"))
	var capsule:=CapsuleShape3D.new();capsule.radius=0.03;capsule.height=length
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule
	query.transform=host.call("_blade_shape_transform",direction,origin+direction*length*0.5)
	query.collision_mask=1;query.exclude=[player.get_rid()]
	var target_body:CollisionObject3D=host.get("_npc_body")
	var target_corpse:CollisionObject3D=host.get("_npc_corpse31")
	var owned_rids:Array[RID]=[]
	if is_instance_valid(target_corpse) and target_corpse.has_meta("ragdoll31"):
		owned_rids=target_corpse.get_meta("ragdoll31").physical.body_rids()
	for hit:Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query,32):
		var collider:Node=hit.get("collider")
		if collider is CollisionObject3D and owned_rids.has(collider.get_rid()):continue
		if collider==target_body or collider==target_corpse or (is_instance_valid(target) and is_instance_valid(collider) and (collider==target or target.is_ancestor_of(collider))):continue
		return true
	return false

# This hook runs before the player's ordinary move_and_slide. Only the inward
# horizontal component is loaded: no transforms, gravity, tangential movement,
# withdrawal, fast impact or free locomotion are changed. Unlike finite hand
# compliance this remains effective throughout a continuous tissue contact.
func constrain_walk_velocity(host: Node, value: Vector3, delta: float) -> Vector3:
	var player:CharacterBody3D=host.get("_player")
	if not is_instance_valid(player) or not player.is_on_floor() or delta<=0.0:
		last_walk29={"active":false,"reason":"not_grounded"};return value
	var data:=_channel(host)
	if not data.is_empty():
		var axis:Vector3=data.axis
		var relative_tip:=Puncture.tip_world(host)-Vector3(data.entry)
		var depth:=relative_tip.dot(axis)
		var radial:float=(relative_tip-axis*depth).length()
		var skin_length:float=maxf(0.0,float(data.row.get("max_depth",0.5))-0.04)
		var tip_offset:float=float(data.row.get("tip_offset",1.0))
		if Vector3(host.get("_dir")).dot(axis)<0.8 or radial>maxf(0.03,float(data.row.get("radius",0.01))+0.02) or depth<=0.0 or depth-tip_offset>=skin_length:data={}
	if data.is_empty():data=_cut_contact(host)
	if data.is_empty():
		_walk_identity="";_walk_frame=-1
		last_walk29={"active":false,"reason":"no_overlap"};return value
	var frame:=Engine.get_physics_frames()
	if str(data.identity)!=_walk_identity:
		_walk_identity=data.identity;_walk_frame=frame;_walk_entry=data.entry;_walk_target_velocity=Vector3.ZERO
	elif frame!=_walk_frame:
		var step:Vector3=Vector3(data.entry)-_walk_entry
		var frames:=frame-_walk_frame
		if frames<1 or frames>3 or step.length()>0.40:
			_walk_identity="";_walk_frame=-1
			last_walk29={"active":false,"reason":"target_discontinuity"};return value
		_walk_target_velocity=step/(maxf(delta,0.001)*float(frames))
		_walk_entry=data.entry;_walk_frame=frame
	var incoming:Vector3=data.axis
	var normal:=Vector3(incoming.x,0.0,incoming.z).normalized()
	var forward:=value.dot(normal)
	var relative:=value-_walk_target_velocity
	var advancing:=relative.dot(normal)
	if normal.length_squared()<0.5 or forward<=0.0 or advancing<=0.0:
		last_walk29={"active":false,"reason":"withdrawal_or_tangent"};return value
	var speed:=Vector3(relative.x,0.0,relative.z).length()
	if data.kind=="cut":speed=maxf(speed,float(data.get("speed",0.0)))
	var fraction:=SLOW_FRACTION*Resistance.sword_load_factor29(speed)
	var resisted:=minf(forward,advancing)*fraction
	var result:=value-normal*resisted
	result.y=value.y
	last_walk29={"active":resisted>0.0,"kind":data.kind,"fraction":fraction,"requested":value,"allowed":result,"normal":normal,"target_velocity":_walk_target_velocity,"speed":speed,"removed":resisted,"frame":frame}
	return result

func constrain_pose(host: Node, delta: float) -> void:
	var data:=_channel(host)
	var follows_regrab:=not data.is_empty() and str(data.identity)==_regrab_identity31 and Vector3(host.get("_omega")).length()<2.0
	if not follows_regrab:_regrab_identity31=""
	if follows_regrab:
		# Pickup must not turn the old free-hand animation into insertion or
		# extraction. Only real relative holder/target travel changes depth.
		var player_position:Vector3=host.get("_player").global_position
		var relative_step:=player_position-_regrab_player31-(Vector3(data.entry)-_regrab_entry31)
		_regrab_depth31+=relative_step.dot(Vector3(data.axis))
		_regrab_player31=player_position;_regrab_entry31=data.entry
	var follows_corpse:=not data.is_empty() and bool(host.get("_npc_dead")) and is_instance_valid(host.get("_npc_corpse31")) and bool(data.row.get("active",false)) and float(data.row.get("cut_depth",0.0))>0.0 and Vector3(host.get("_omega")).length()<2.0
	# A historical puncture channel must not suppress a later transverse cut.
	if not data.is_empty() and not follows_regrab:
		var check_tip:=Puncture.tip_world(host)
		var check_offset:Vector3=check_tip-Vector3(data.entry)
		var check_depth:=check_offset.dot(Vector3(data.axis))
		var check_radial:float=(check_offset-Vector3(data.axis)*check_depth).length()
		if Vector3(host.get("_dir")).dot(Vector3(data.axis))<0.80 or check_radial>(INF if follows_corpse else maxf(0.03,float(data.row.get("radius",0.01))+0.02)):
			if bool(host.get("_npc_dead")):
				var rejection:={"radial":check_radial,"dot":Vector3(host.get("_dir")).dot(Vector3(data.axis)),"omega":Vector3(host.get("_omega")).length(),"follows":follows_corpse}
				clear("corpse_guide_outside");last.merge(rejection);return
			data={};follows_corpse=false
	if data.is_empty():data=_cut_contact(host)
	if data.is_empty():
		if lag>0.0 or not _identity.is_empty():clear("inactive")
		return
	var tip:=Puncture.tip_world(host)
	var direction:Vector3=host.get("_dir")
	var origin:Vector3=host.get("_sword_origin")
	var axis:Vector3=data.axis
	var entry:Vector3=data.entry
	if follows_regrab:
		direction=axis
		tip=entry+axis*_regrab_depth31
		origin=tip-axis*float(data.row.get("tip_offset",1.0))
	# Repeated attachment must not feed our solved palm back as a new command.
	if not follows_regrab and origin.distance_squared_to(_applied_origin)<1.0e-12 and entry.distance_squared_to(_entry)<1.0e-12 and axis.distance_squared_to(_axis)<1.0e-12:return
	var depth:float=(tip-entry).dot(axis)
	var radial:float=(tip-entry-axis*depth).length()
	if data.kind=="puncture":
		var extent:float=float(data.row.get("max_depth",0.5))+float(data.row.get("tip_offset",1.0))
		if depth>extent:clear("left_channel");return
	var frame:=Engine.get_physics_frames()
	if str(data.identity)!=_identity:
		clear("new_channel");_identity=data.identity;_requested_tip=tip;_requested_origin=origin;_entry=entry;_axis=axis;_frame=frame
		return
	if frame!=_frame:
		var step:=tip-_requested_tip-(entry-_entry)
		if data.kind=="cut":step=origin-_requested_origin-(entry-_entry)
		if frame-_frame>3 or step.length()>0.40 or entry.distance_to(_entry)>0.40:
			var detail:={"frame_delta":frame-_frame,"step_m":step.length(),"entry_step_m":entry.distance_to(_entry),"following":follows_corpse}
			clear("discontinuity");last.merge(detail);return
		var elapsed:=maxf(delta,0.001)*float(frame-_frame)
		var advance:=step.dot(axis)
		var speed:=step.length()/elapsed
		var guide_target:=Vector3.ZERO
		var guide_reason:="outside_or_cut"
		if data.kind=="puncture" and bool(data.row.get("active",false)) and float(data.row.get("cut_depth",0.0))>0.0 and depth>0.0:
			if direction.dot(axis)<0.985 or Vector3(host.get("_omega")).length()>2.0:
				# Deliberate transverse steering keeps the native cutting response.
				_guide_correction29=Vector3.ZERO;guide_reason="transverse"
			elif radial<=GUIDE_LIMIT29:
				guide_target=entry+axis*depth-tip;guide_reason="bone_bore"
			else:
				_guide_correction29=Vector3.ZERO;guide_reason="outside_reach"
		_guide_correction29=_guide_correction29.move_toward(guide_target,GUIDE_RATE29*elapsed)
		if data.kind=="cut":speed=maxf(speed,float(data.speed))
		lag=next_lag29(lag,advance,speed,data.kind=="puncture" and depth<=0.0,elapsed)
		_requested_tip=tip;_requested_origin=origin;_entry=entry;_axis=axis;_frame=frame
		last={"active":lag>0.0,"kind":data.kind,"requested_advance":advance,"speed":speed,"lag":lag,"withdrawing":advance<0.0,"at_limit":lag>=MAX_LAG-0.000001}
		last["guide_correction"]=_guide_correction29;last["guide_radial"]=radial;last["guide_reason"]=guide_reason
	if follows_regrab:
		lag=0.0;_guide_correction29=Vector3.ZERO
		last["regrab_same_wound"]=true;last["regrab_depth"]= _regrab_depth31
	if lag<=0.000001 and _guide_correction29.length_squared()<1.0e-12 and not follows_corpse and not follows_regrab:return
	var rig:Skeleton3D=host.get("_rig")
	if not is_instance_valid(rig):clear("holder_gone");return
	var old_poses:Array[Transform3D]=[]
	for bone in rig.get_bone_count():old_poses.append(rig.get_bone_pose(bone))
	var side:StringName=host.call("_active_side")
	var grip_offset:float=host.call("_grip_origin_offset")
	var desired_origin:=origin-axis*lag+_guide_correction29
	if follows_corpse or follows_regrab:
		# A moving wounded bone carries its bore direction as well as its entry.
		# Keep the same insertion depth; the final exact solid solver still owns
		# passage, and ordinary arm reach/self/world checks remain mandatory.
		direction=axis
		desired_origin=entry+axis*(depth-float(data.row.get("tip_offset",1.0))-lag)
		last["follows_corpse_bore"]=true
	if not bool(host.call("_self_blade_clear_at51",direction,desired_origin)) or _world_blocked(host,data,direction,desired_origin):
		last["pose_rejected"]="self_or_world";return
	var desired_grip:Vector3=desired_origin-direction*grip_offset
	var grip_rig:Vector3=rig.global_transform.affine_inverse()*desired_grip
	var blade_rig:Vector3=(rig.global_basis.inverse()*direction).normalized()
	var arm:Dictionary=host.call("_arm_set",side)

	if follows_corpse and not follows_regrab:
		# A falling target can draw the hilt beyond arm reach. Allow only axial
		# sliding along the existing slit, choosing the nearest reachable wrist.
		# Never offset the steel sideways or stretch the arm to preserve depth.
		var clavicle:Transform3D=host.call("_chain_global",int(arm.clav))
		var shoulder:Vector3=(clavicle*Transform3D(arm.rest_upper)).origin
		var rest_basis:Basis=(clavicle*Transform3D(arm.rest_upper)*Transform3D(arm.rest_fore)*Transform3D(arm.rest_hand)).basis.orthonormalized()
		var palm:Basis=host.call("_palm_basis51",shoulder,grip_rig,blade_rig,rest_basis)
		var wrist:Vector3=grip_rig-palm*Vector3(host.call("_palm_offset",int(arm.hand)))
		var offset:=wrist-shoulder
		var reach:float=(Transform3D(arm.rest_fore).origin.length()+Transform3D(arm.rest_hand).origin.length())*.955
		var along:=offset.dot(blade_rig)
		var discriminant:=reach*reach-offset.length_squared()+along*along
		if offset.length()>reach and discriminant>=0.0:
			var low:float=-along-sqrt(discriminant)
			var high:float=-along+sqrt(discriminant)
			var slip:=clampf(0.0,low,high)
			var slip_world:float=(rig.global_basis*(blade_rig*slip)).length()
			if slip_world>.005:
				# The corpse would force an axial extraction to keep the hand in
				# reach. Keep the pre-IK holder pose; final contact hands this same
				# accepted steel to its wounded bone instead of moving it out.
				last["axial_reach_slip_m"]=slip_world
				last["pose_rejected"]="corpse_axial_reach"
				return
			grip_rig+=blade_rig*slip
			desired_grip=rig.global_transform*grip_rig
			last["axial_reach_slip_m"]=(rig.global_basis*(blade_rig*slip)).length()
	var has_support:bool=side==&"both" or bool(host.get("_half_sword"))
	var support_before:Vector3=Vector3(host.call("_palm_position",&"left"))-Vector3(host.call("_palm_position",side)) if has_support else Vector3.ZERO
	host.call("_pose_arm_ik",arm.clav,arm.upper,arm.fore,arm.hand,arm.rest_upper,arm.rest_fore,arm.rest_hand,arm.offset,grip_rig,blade_rig,1.0,true,arm.pole)
	if has_support:
		host.call("_pose_support",&"left",rig.global_transform.affine_inverse()*(desired_grip+support_before))
	rig.force_update_all_bone_transforms()
	var actual_grip:Vector3=host.call("_palm_position",side)
	var actual_origin:=actual_grip+direction*grip_offset
	var error:=actual_grip.distance_to(desired_grip)
	var support_error:float=Vector3(host.call("_palm_position",&"left")).distance_to(actual_grip+support_before) if has_support else 0.0
	if error>0.005 or support_error>0.005 or not bool(host.call("_self_blade_clear_at51",direction,actual_origin)) or _world_blocked(host,data,direction,actual_origin):
		for bone in old_poses.size():rig.set_bone_pose(bone,old_poses[bone])
		rig.force_update_all_bone_transforms()
		last["pose_rejected"]="unreachable_or_obstructed";last["rejected_grip_error"]=error;last["rejected_self_clear"]=bool(host.call("_self_blade_clear_at51",direction,actual_origin));return
	host.set("_sword_origin",actual_origin)
	if follows_corpse or follows_regrab:
		host.set("_dir",direction)
		# A flat blade cannot twist freely inside its narrow slit. Carry the
		# accepted edge orientation with the same wounded bone, as well as axis.
		var wound:Node3D=data.row.node_ref.get_ref()
		var bore:Transform3D=host.get("_solid_weapon29")._bore_frame(host,wound)
		host.set("_edge_direction",bore.basis.x.normalized())
	host.call("_place_sword",actual_origin,direction)
	host.set("_grip_hand_error",0.0)
	if has_support:host.set("_left_hand_error",support_error)
	if bool(host.get("_half_sword")):host.set("_half_sword_blade_point",actual_grip+support_before)
	_applied_origin=actual_origin
	last["grip_error"]=error;last["support_error"]=support_error;last["actual_lag"]=(origin-actual_origin).dot(axis)
