extends RefCounted
## A puncture channel is authored by actual posed-skin contact, never a world ray.
var _host:WeakRef
var _channel:Dictionary={}
var _player_previous:=Vector3.ZERO
var _entry_previous:=Vector3.ZERO
var _depth:=0.0
var _axis:=Vector3.FORWARD
var _entry:=Vector3.ZERO
var _tip_offset:=1.84
var _shaft_axis_local:=Vector3.FORWARD
var _entry_offset_local:=Vector3.ZERO
var _upper_pose:Dictionary={}
var _brace_origin_y:=0.0
var max_foot_error_m:=0.0
var max_crouch_m:=0.0
var _thrust_extension:=0.0
var _thrust_pending:=0.0
var _thrust_player:=Vector3.ZERO
var _drag_frame:=-1
var _drag_actual:=Vector3.ZERO
var _frame:=-1
var last_reason:=""
var begins:=0
var ends:=0
var rejected_lateral_m:=0.0
var max_grip_error_m:=0.0
var max_support_error_m:=0.0
var self_clear:=true
var world_clear:=true

func _owner()->Node:
	return _host.get_ref() if _host!=null else null

func _anchor(channel:Dictionary)->Transform3D:
	var ref:WeakRef=channel.get("rig_ref")
	var rig:Skeleton3D=ref.get_ref() if ref!=null else null
	var bone:int=int(channel.get("bone",-1))
	if not is_instance_valid(rig) or bone<0 or bone>=rig.get_bone_count():return Transform3D(Basis.IDENTITY,Vector3.INF)
	return rig.global_transform*rig.get_bone_global_pose(bone)

func end(reason:String)->void:
	if _channel.is_empty():return
	_channel["active"]=false
	_channel["withdrawn"]=true
	_channel["release_reason"]=reason
	_channel={};last_reason=reason;ends+=1
	var host:=_owner()
	if is_instance_valid(host):
		host.set("_prev_points",PackedVector3Array())
		host.set("_omega",Vector3.ZERO)
		host.set("_sword_coast_until_ms31",0)
		if host.has_method("_clay_invalidate_motion28"):host.call("_clay_invalidate_motion28")

func sync(host:Node)->bool:
	_host=weakref(host)
	var player:Node3D=host.get("_player")
	if not is_instance_valid(player):end("player_gone");return false
	player.set_meta("embedded_weapon29",self)
	var weapon:Node3D=host.get("_sword")
	var world:Node=host.get("_world")
	if str(host.get("_weapon_id"))!="spear" or host.get("_sword_grounded") or host.get("_unarmed") or not host.get("_selected") or not is_instance_valid(weapon):
		end("equipment");return false
	if is_instance_valid(world) and bool(world.get("preview_dead")):
		end("player_death");return false
	if player.get("_mount_mode") or player.get("_swimming") or player.get("_vehicle_hold"):
		end("movement_owner");return false
	if _channel.is_empty():
		var incoming:Dictionary=host.get_meta("puncture29_channel",{})
		if incoming.is_empty() or not incoming.get("actual_hit",false) or not incoming.get("valid",false) or incoming.get("withdrawn",false):return false
		if str(incoming.get("weapon",""))!="spear" or int(incoming.get("weapon_instance_id",-1))!=weapon.get_instance_id():return false
		var anchor:=_anchor(incoming)
		if not anchor.origin.is_finite():return false
		_entry=anchor*Vector3(incoming.entry_local)
		# Keep the steel's actual orientation at contact. The historical tip-path
		# tangent is not necessarily its current shaft direction; snapping to it
		# can swing the rear haft into the holder before any new input happens.
		_axis=weapon.global_basis.x.normalized()
		_shaft_axis_local=anchor.basis.inverse()*_axis
		if _axis.length_squared()<0.9:return false
		_tip_offset=float(incoming.get("tip_offset",1.84))
		var tip:Vector3=weapon.global_position+_axis*_tip_offset
		_depth=maxf(0.001,(tip-_entry).dot(_axis))
		_entry_offset_local=anchor.basis.inverse()*(tip-_entry-_axis*_depth)
		_upper_pose.clear()
		_brace_origin_y=weapon.global_position.y-player.global_position.y
		var holder_rig:Skeleton3D=host.get("_rig")
		for name:String in ["_bone_pelvis","_bone_spine","_bone_chest","_bone_head"]:
			var index:int=host.get(name)
			if index>=0:_upper_pose[index]=player.global_transform.affine_inverse()*holder_rig.global_transform*holder_rig.get_bone_global_pose(index)
		_channel=incoming;_channel["active"]=true
		_drag_frame=-1;_drag_actual=Vector3.ZERO
		_thrust_extension=0.0;_thrust_pending=0.0;_thrust_player=player.global_position
		_player_previous=player.global_position;_entry_previous=_entry;_frame=-1;begins+=1
	if not _channel.get("valid",false) or int(_channel.get("weapon_instance_id",-1))!=weapon.get_instance_id() or int(_channel.get("generation",host.get("lab_resets")))!=int(host.get("lab_resets")):
		end("channel_invalid");return false
	var anchor:=_anchor(_channel)
	if not anchor.origin.is_finite():end("target_gone");return false
	var current_entry:Vector3=anchor*Vector3(_channel.entry_local)
	var current_axis:Vector3=(anchor.basis*_shaft_axis_local).normalized()
	if current_entry.distance_to(_entry_previous)>0.75:
		end("target_discontinuity");return false
	# Account for actual swept player displacement, not intended velocity or mouse.
	var displacement:Vector3=player.global_position-_player_previous
	var target_displacement:Vector3=current_entry-_entry_previous
	_depth+=(displacement-target_displacement).dot(current_axis)
	_depth=minf(_depth,maxf(0.02,float(_channel.get("max_depth",0.5))))
	_player_previous=player.global_position;_entry_previous=current_entry
	_entry=current_entry;_axis=current_axis
	_channel["current_depth"]=_depth;_channel["tip_depth"]=_depth
	_channel["entry_world"]=_entry;_channel["held_axis_world"]=_axis
	if _depth<=-0.015:end("withdrawn_backward");return false
	return true

func active(host:Node)->bool:return sync(host)

func _release_grip(host:Node,reason:String)->void:
	end(reason)
	if not host.get("_sword_grounded"):host.call("drop_sword_to_ground")

func _self_margin(host:Node,origin:Vector3)->float:
	var rig:Skeleton3D=host.get("_rig")
	var chest:Vector3=rig.global_transform*rig.get_bone_global_pose(int(host.get("_bone_chest"))).origin
	var pelvis:Vector3=rig.global_transform*rig.get_bone_global_pose(int(host.get("_bone_pelvis"))).origin
	var head:Vector3=rig.global_transform*rig.get_bone_global_pose(int(host.get("_bone_head"))).origin
	var rear:Vector3=origin-_axis*float(host.call("weapon_rear_extent"))
	var tip:=origin+_axis*_tip_offset
	return minf(float(host.call("_segment_distance",rear,tip,chest,pelvis))-.20,float(host.call("_segment_distance",rear,tip,head,head))-.18)

func constrain_velocity(value:Vector3,delta:float)->Vector3:
	var host:=_owner()
	if not is_instance_valid(host) or not sync(host):return value
	pose(host)
	if _channel.is_empty():return value
	var player:CharacterBody3D=host.get("_player")
	# Native body collision may stop the torso before the hands exhaust reach.
	# Only the unfulfilled forward request advances the grip along the bore.
	if _thrust_pending>0.0 and host.get("_held"):
		var actual:=maxf(0.0,(player.global_position-_thrust_player).dot(_axis))
		var extra:=minf(maxf(0.0,_thrust_pending-actual),maxf(0.0,0.03-_thrust_extension))
		extra=minf(extra,maxf(0.0,float(_channel.get("max_depth",0.5))-_depth))
		_thrust_extension+=extra;_depth+=extra
	_thrust_pending=0.0
	if not player.is_on_floor() and absf(value.y)>0.25:
		_release_grip(host,"airborne_grip_release")
		return value
	# Gravity and jump velocity belong to the native body solver, not the shaft.
	_apply_brace(host)
	var horizontal_axis:=Vector3(_axis.x,0,_axis.z).normalized()
	var horizontal:=Vector3(value.x,0,value.z)
	var allowed:=horizontal_axis*horizontal.dot(horizontal_axis)
	# The target owns its collision sweep and finite force. Follow only motion
	# it actually achieved; the shaft remains in the same bone-local bore.
	var lateral:=horizontal-allowed
	var requested_drag:=lateral*maxf(0.0,delta)
	if _depth>=float(_channel.get("max_depth",0.5))-0.005:
		requested_drag+=allowed*maxf(0.0,delta) if allowed.dot(_axis)>0.0 else Vector3.ZERO
	if host.has_method("_embedded_drag29") and (requested_drag.length_squared()>0.00000001 or _drag_frame>=0):
		var report:Dictionary=host.call("_embedded_drag29",_channel,requested_drag,delta)
		var report_frame:=int(report.get("frame",-1))
		if report.get("accepted",false) and report_frame!=_drag_frame:
			_drag_frame=report_frame
			_drag_actual=Vector3(report.get("actual_delta",Vector3.ZERO))
			allowed+=(_drag_actual-horizontal_axis*_drag_actual.dot(horizontal_axis))/maxf(.001,delta)
	# When the tip reaches the deepest authored tissue point, forward travel stops.
	var room:=maxf(0.0,float(_channel.get("max_depth",0.5))-_depth)
	if allowed.dot(_axis)>0.0:
		allowed*=minf(1.0,room/maxf(0.000001,allowed.dot(_axis)*maxf(0.001,delta)))
	# Do not walk the holder into the fixed shaft. Predict the relative shaft/body
	# displacement before the native sweep and stop at the existing self proxy.
	var origin:=_entry+_anchor(_channel).basis*_entry_offset_local+_axis*(_depth-_tip_offset)
	var step:=allowed*maxf(0.0,delta)
	var required_margin:=minf(0.005,maxf(0.0,_self_margin(host,origin)))
	if _self_margin(host,origin+_axis*step.dot(_axis)-step)<required_margin:
		var low:=0.0;var high:=1.0
		for iteration in 12:
			var middle:float=(low+high)*0.5
			var trial:=step*middle
			if _self_margin(host,origin+_axis*trial.dot(_axis)-trial)>=required_margin:low=middle
			else:high=middle
		allowed*=low
	_thrust_pending=maxf(0.0,horizontal.dot(_axis))*maxf(0.0,delta)
	_thrust_player=player.global_position
	rejected_lateral_m+=(horizontal-allowed).length()*maxf(0.0,delta)
	allowed.y=value.y
	return allowed

func _world_blocked(host:Node,origin:Vector3)->bool:
	var player:CharacterBody3D=host.get("_player")
	var capsule:=CapsuleShape3D.new();capsule.radius=0.03;capsule.height=_tip_offset
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule
	query.transform=host.call("_blade_shape_transform",_axis,origin+_axis*_tip_offset*0.5)
	query.collision_mask=1;query.exclude=[player.get_rid()]
	var ref:WeakRef=_channel.get("rig_ref")
	var target:Node=ref.get_ref() if ref!=null else null
	var target_body:CollisionObject3D=host.get("_npc_body")
	if is_instance_valid(target_body) and target==host.get("_npc_rig"):
		query.exclude=[player.get_rid(),target_body.get_rid()]
		var target_corpse:CollisionObject3D=host.get("_npc_corpse31")
		if is_instance_valid(target_corpse) and target_corpse.is_ancestor_of(target_body):
			var excluded:=query.exclude
			excluded.append(target_corpse.get_rid())
			query.exclude=excluded
	for hit:Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query,32):
		var collider:Node=hit.get("collider")
		if is_instance_valid(target) and is_instance_valid(collider) and (collider==target or target.is_ancestor_of(collider)):continue
		return true
	return false

func pose(host:Node)->bool:
	if not sync(host):return false
	_apply_brace(host)
	var rig:Skeleton3D=host.get("_rig")
	var origin:=_entry+_anchor(_channel).basis*_entry_offset_local+_axis*(_depth-_tip_offset)
	var grip:Vector3=origin-_axis*float(host.call("_grip_origin_offset"))
	var blade_rig:Vector3=(rig.global_basis.inverse()*_axis).normalized()
	var grip_rig:Vector3=rig.global_transform.affine_inverse()*grip
	host.set("_dir",_axis)
	var arm:Dictionary=host.call("_arm_set",&"right")
	host.call("_pose_arm_ik",arm.clav,arm.upper,arm.fore,arm.hand,arm.rest_upper,arm.rest_fore,arm.rest_hand,arm.offset,grip_rig,blade_rig,1.0,true,arm.pole)
	host.call("_pose_support",&"left",grip_rig-blade_rig*float(host.get("_two_hand_offset_rig")))
	rig.force_update_all_bone_transforms()
	var grip_error:float=Vector3(host.call("_palm_position",&"right")).distance_to(grip)
	var support_world:Vector3=rig.global_transform*(grip_rig-blade_rig*float(host.get("_two_hand_offset_rig")))
	var support_error:float=Vector3(host.call("_palm_position",&"left")).distance_to(support_world)
	max_grip_error_m=maxf(max_grip_error_m,grip_error);max_support_error_m=maxf(max_support_error_m,support_error)
	self_clear=host.call("_self_blade_clear_at51",_axis,origin)
	world_clear=not _world_blocked(host,origin)
	if grip_error>0.04 or support_error>0.04 or not self_clear or not world_clear:
		_release_grip(host,"unreachable_grip" if grip_error>0.04 or support_error>0.04 else "self_or_world_obstruction")
		return true
	host.set("_dir",_axis);host.set("_sword_origin",origin);host.set("_omega",Vector3.ZERO)
	host.set("_sword_coast_until_ms31",0);host.set("_prev_points",PackedVector3Array())
	host.call("_place_sword",origin,_axis)
	preload("res://scripts/combat/local_wound28.gd").advance_active29(host,preload("res://scripts/combat/puncture29.gd").tip_world(host))
	_channel["grip_error_m"]=grip_error
	_channel["support_error_m"]=support_error
	return true

func status()->Dictionary:
	return {"max_foot_error_m":max_foot_error_m,"max_crouch_m":max_crouch_m,"active":not _channel.is_empty(),"depth":_depth,"axis":_axis,"entry":_entry,"begins":begins,"ends":ends,"last_reason":last_reason,"rejected_lateral_m":rejected_lateral_m,"max_grip_error_m":max_grip_error_m,"max_support_error_m":max_support_error_m,"self_clear":self_clear,"world_clear":world_clear}

func _apply_brace(host:Node)->void:
	var rig:Skeleton3D=host.get("_rig")
	# Keep the accepted brace relative to the physical holder, compensating visual
	# gait bob before it can push the pelvis into the fixed rear haft. Leg joint
	# animation remains owned by locomotion; no player transform is assigned.
	var player:Node3D=host.get("_player")
	var feet:Dictionary={}
	for side:String in ["l","r"]:
		var foot:=rig.find_bone("foot_"+side)
		if foot>=0:feet[side]=rig.get_bone_global_pose(foot)
	var origin:=_entry+_anchor(_channel).basis*_entry_offset_local+_axis*(_depth-_tip_offset)
	var lower:=clampf(origin.y-player.global_position.y-_brace_origin_y,-0.06,0.0)
	max_crouch_m=maxf(max_crouch_m,-lower)
	for index:int in _upper_pose:
		var parent:=rig.get_bone_parent(index)
		var parent_pose:Transform3D=host.call("_chain_global",parent) if parent>=0 else Transform3D.IDENTITY
		var wanted:Transform3D=rig.global_transform.affine_inverse()*player.global_transform*Transform3D(_upper_pose[index])
		wanted.origin+=rig.global_basis.inverse()*Vector3(0,lower,0)
		rig.set_bone_pose(index,parent_pose.affine_inverse()*wanted)
	for side:String in feet:
		_reach_foot(host,side,feet[side])
	rig.force_update_all_bone_transforms()

func _point_bone(host:Node,bone:int,child:int,target:Vector3)->void:
	var rig:Skeleton3D=host.get("_rig")
	var frame:Transform3D=host.call("_chain_global",bone)
	var end:Vector3=Transform3D(host.call("_chain_global",child)).origin
	var a:Vector3=(end-frame.origin).normalized()
	var b:Vector3=(target-frame.origin).normalized()
	if a.length_squared()<.9 or b.length_squared()<.9:return
	frame.basis=Basis(Quaternion(a,b))*frame.basis
	var parent:=rig.get_bone_parent(bone)
	var parent_frame:Transform3D=host.call("_chain_global",parent) if parent>=0 else Transform3D.IDENTITY
	rig.set_bone_pose(bone,parent_frame.affine_inverse()*frame)

func _reach_foot(host:Node,side:String,target:Transform3D)->void:
	var rig:Skeleton3D=host.get("_rig")
	var thigh:=rig.find_bone("thigh_"+side);var shin:=rig.find_bone("shin_"+side);var foot:=rig.find_bone("foot_"+side)
	if mini(thigh,mini(shin,foot))<0:return
	var hip:Vector3=Transform3D(host.call("_chain_global",thigh)).origin
	var knee:Vector3=Transform3D(host.call("_chain_global",shin)).origin
	var ankle:Vector3=Transform3D(host.call("_chain_global",foot)).origin
	var a:=hip.distance_to(knee);var b:=knee.distance_to(ankle)
	var line:Vector3=target.origin-hip
	var distance:=clampf(line.length(),absf(a-b)+.000001,a+b-.000001)
	line=line.normalized()
	var bend:=knee-hip-line*(knee-hip).dot(line)
	if bend.length_squared()<.000001:bend=Vector3.FORWARD-line*Vector3.FORWARD.dot(line)
	bend=bend.normalized()
	var along:float=(a*a-b*b+distance*distance)/(2.0*distance)
	var height:=sqrt(maxf(0.0,a*a-along*along))
	_point_bone(host,thigh,shin,hip+line*along+bend*height)
	_point_bone(host,shin,foot,target.origin)
	var frame:Transform3D=host.call("_chain_global",foot)
	frame.basis=target.basis
	var parent:Transform3D=host.call("_chain_global",rig.get_bone_parent(foot))
	rig.set_bone_pose(foot,parent.affine_inverse()*frame)
	max_foot_error_m=maxf(max_foot_error_m,(rig.global_basis*(frame.origin-target.origin)).length())
