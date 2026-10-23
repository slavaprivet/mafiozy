extends RefCounted
const Drop31=preload("res://scripts/combat/embedded_drop31.gd")
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
var _steel_edge_local:=Vector3.UP
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
var _corpse_brace_id:=-1
var _corpse_brace_frame:=-1
var _corpse_brace_entry:=Vector3.ZERO
var _corpse_brace_axis:=Vector3.FORWARD
var _corpse_brace_player:=Vector3.ZERO
var corpse_brace:Dictionary={}
var _holder_reaction_frame:=-1
var holder_reaction_m:=0.0
var max_holder_reaction_step_m:=0.0
var last_airborne35:Dictionary={}
var floor_probe35:Dictionary={}
var supported_settles35:=0

func _floor_support35(player:CharacterBody3D)->bool:
	if player.is_on_floor():return true
	var result:=KinematicCollision3D.new()
	# Native floor contact can be temporarily false during sub-millimetre
	# settling. Four millimetres cover that margin, not a step or a jump.
	if not player.test_move(player.global_transform,Vector3.DOWN*.004,result):return false
	floor_probe35={"travel":result.get_travel(),"normal":result.get_normal(),"velocity":player.velocity}
	for i in result.get_collision_count():
		if result.get_normal(i).dot(player.up_direction)>=cos(player.floor_max_angle):return true
	return false

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
	_corpse_brace_id=-1;_corpse_brace_frame=-1;corpse_brace={}
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
		# A prospective axial lane lets the solid solver validate entry. It is
		# not an embedded spear until the final accepted tip has opened tissue.
		if float(incoming.get("cut_depth",0.0))<=0.0001:return false
		var anchor:=_anchor(incoming)
		if not anchor.origin.is_finite():return false
		_entry=anchor*Vector3(incoming.entry_local)
		# Keep the steel's actual orientation at contact. The historical tip-path
		# tangent is not necessarily its current shaft direction; snapping to it
		# can swing the rear haft into the holder before any new input happens.
		_axis=weapon.global_basis.x.normalized()
		_shaft_axis_local=anchor.basis.inverse()*_axis
		_steel_edge_local=anchor.basis.inverse()*weapon.global_basis.y.normalized()
		if _axis.length_squared()<0.9:return false
		_tip_offset=float(incoming.get("tip_offset",1.84))
		var tip:Vector3=weapon.global_position+_axis*_tip_offset
		_depth=(tip-_entry).dot(_axis)
		if _depth<=0.0001:return false
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
	_brace_corpse31(host,current_entry,current_axis)
	if current_entry.distance_to(_entry_previous)>0.75:
		end("target_discontinuity");return false
	# Account for actual swept player displacement, not intended velocity or mouse.
	var displacement:Vector3=player.global_position-_player_previous
	var target_displacement:Vector3=current_entry-_entry_previous
	# Vertical settling carries the anchored hands with the target; it must not
	# spend insertion depth and masquerade as a backward withdrawal. Walking
	# advances/extracts along the horizontal shaft projection. The solid solver
	# still measures the accepted tip in the full current bone-local channel.
	var relative_walk:Vector3=displacement-target_displacement
	relative_walk.y=0.0
	_depth+=relative_walk.dot(current_axis)
	_depth=minf(_depth,maxf(0.02,float(_channel.get("max_depth",0.5))))
	_player_previous=player.global_position;_entry_previous=current_entry
	_entry=current_entry;_axis=current_axis
	_channel["current_depth"]=_depth;_channel["tip_depth"]=_depth
	_channel["entry_world"]=_entry;_channel["held_axis_world"]=_axis
	if _depth<=-0.015:end("withdrawn_backward");return false
	return true

func active(host:Node)->bool:return sync(host)

func make_drop31(host:Node)->Node:
	if not Drop31.candidate(host):return null
	var attachment:=Drop31.new()
	attachment.name="EmbeddedAttachment31";host.get("_world").add_child(attachment)
	if not attachment.start(host):attachment.queue_free();return null
	# The attachment owns an independent copy; releasing hands is not withdrawal.
	_channel={};last_reason="released_hands_embedded"
	_corpse_brace_id=-1;_corpse_brace_frame=-1;corpse_brace={}
	var held_channel:Dictionary=host.get_meta("puncture29_channel",{})
	held_channel.active=false;held_channel.held=false
	return attachment

func dropped_attachment31(model:Node)->Node:return Drop31.attachment(model)

func restore_regrab31(host:Node)->bool:
	if not host.has_meta("embedded_regrab31"):return false
	var attachment:Node=host.get_meta("embedded_regrab31",null)
	return bool(attachment.restore(host)) if is_instance_valid(attachment) else false

func _brace_corpse31(host:Node,current_entry:Vector3,current_axis:Vector3)->void:
	# The held shaft supplies a finite point/rotation reaction to the actual
	# wounded rigid segment. No body/weapon transform or velocity is assigned.
	# Axial translation stays free for insertion and resisted native withdrawal.
	var corpse:RigidBody3D=host.get("_npc_corpse31")
	if not bool(host.get("_npc_dead")) or not is_instance_valid(corpse) or not corpse.has_meta("ragdoll31"):return
	var segment:RigidBody3D=corpse.get_meta("ragdoll31").body_for_bone(int(_channel.bone))
	if not is_instance_valid(segment):return
	var player:Node3D=host.get("_player")
	if _corpse_brace_id!=segment.get_instance_id():
		_corpse_brace_id=segment.get_instance_id();_corpse_brace_entry=_entry_previous
		_corpse_brace_axis=_axis;_corpse_brace_player=player.global_position
		_corpse_brace_frame=-1
	var frame:=Engine.get_physics_frames()
	if frame==_corpse_brace_frame:return
	var elapsed_frames:int=maxi(1,frame-_corpse_brace_frame) if _corpse_brace_frame>=0 else 1
	var elapsed:float=float(elapsed_frames)/float(Engine.physics_ticks_per_second)
	_corpse_brace_frame=frame
	var axis:=_corpse_brace_axis.normalized()
	var holder_step:Vector3=player.global_position-_corpse_brace_player
	# This sample follows actual swept motion. Holder accommodation adjusts the
	# saved position separately, and cannot drive axial tissue friction. The
	# player velocity property here may still contain the pre-constraint request.
	var holder_velocity:Vector3=holder_step/elapsed
	_corpse_brace_entry+=holder_step-axis*holder_step.dot(axis)
	_corpse_brace_player=player.global_position
	var error:=_corpse_brace_entry-current_entry
	error-=axis*error.dot(axis)
	var lever:=current_entry-segment.global_position
	var point_velocity:=segment.linear_velocity+segment.angular_velocity.cross(lever)
	var velocity:=point_velocity
	velocity-=axis*velocity.dot(axis)
	var gravity:=Vector3.UP*float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8))*segment.gravity_scale
	gravity-=axis*gravity.dot(axis)
	var force:Vector3=((error*1600.0-velocity*55.0+gravity)*segment.mass).limit_length(minf(900.0,segment.mass*60.0))
	# Finite axial tissue friction acts on relative native motion; it never
	# holds depth at a prescribed value or treats gravity settling as extraction.
	var relative_axial:float=(point_velocity-holder_velocity).dot(axis)
	var axial_force:float=-clampf(relative_axial*segment.mass*10.0,-segment.mass*300.0/70.0,segment.mass*300.0/70.0)
	force+=axis*axial_force
	var angular:=segment.angular_velocity-axis*segment.angular_velocity.dot(axis)
	# Angular damping uses the actual inertia tensor, not linear mass (which
	# would over-damp a thin segment into alternating impulses at 60 Hz).
	var inverse_inertia:=segment.get_inverse_inertia_tensor()
	var inertia:=inverse_inertia.inverse() if absf(inverse_inertia.determinant())>1e-12 else Basis.IDENTITY
	var torque:Vector3=(inertia*(current_axis.cross(axis)*400.0-angular*30.0)-lever.cross(force)).limit_length(minf(240.0,segment.mass*16.0))
	segment.apply_force(force,lever);segment.apply_torque(torque)
	corpse_brace={"body":segment.get_instance_id(),"frame":frame,"force":force,"torque":torque,"error_m":error.length(),"axis_error_rad":current_axis.angle_to(axis),"mass":segment.mass,"holder_velocity":holder_velocity,"requested_velocity":player.get("velocity"),"point_velocity":point_velocity,"relative_axial":relative_axial,"axial_force":axial_force,"axial_power":axial_force*relative_axial}

func constrain_target_velocity(host:Node,value:Vector3)->Vector3:
	# The living target can withdraw under its own native movement, with the same
	# tissue drag as the holder. This is called before move_and_slide, never by
	# assigning a position afterwards. Corpses keep their finite-force owner.
	if not sync(host) or bool(host.get("_npc_dead")):return value
	var horizontal_axis:=Vector3(_axis.x,0,_axis.z).normalized()
	var escape:=maxf(0.0,value.dot(horizontal_axis))
	return value-horizontal_axis*escape*0.62

func _release_grip(host:Node,reason:String)->void:
	# Losing a reachable hand does not remove steel from its real wound.
	# Let the same model's physical attachment take over before invalidating it.
	if Drop31.candidate(host) and not host.get("_sword_grounded"):
		if bool(host.call("drop_sword_to_ground")):
			last_reason="released_hands_"+reason
			return
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
		var supported:=value.y<0.0 and _floor_support35(player)
		last_airborne35={"position":player.global_position,"velocity":value,"supported":supported,"probe":floor_probe35.duplicate(),"frame":Engine.get_physics_frames()}
		if not supported:
			_release_grip(host,"airborne_grip_release")
			return value
		supported_settles35+=1
	# Gravity and jump velocity belong to the native body solver, not the shaft.
	_apply_brace(host)
	var horizontal_axis:=Vector3(_axis.x,0,_axis.z).normalized()
	var horizontal:=Vector3(value.x,0,value.z)
	# The explicit two-button extraction request is real native backward travel,
	# not a timer spending depth. Manual S is never added twice; aim stays off.
	if bool(host.get("_hold_left")) and bool(host.get("_hold_right")):
		var backwards:=horizontal.dot(horizontal_axis)
		if backwards>-.6:horizontal+=horizontal_axis*(-.6-backwards)
	var allowed:=horizontal_axis*horizontal.dot(horizontal_axis)
	var lateral:=horizontal-allowed
	# Withdrawal remains native, swept player displacement. Tissue resists the
	# backward request; time, mouse motion and sideways input never reduce depth.
	# Target motion is accounted independently by sync's relative displacement.
	if allowed.dot(_axis)<0.0:
		allowed*=0.38
	# The target owns its collision sweep and finite force. Follow only motion
	# it actually achieved; the shaft remains in the same bone-local bore.
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
			if target_corpse.has_meta("ragdoll31"):
				for rid:RID in target_corpse.get_meta("ragdoll31").physical.body_rids():
					if not excluded.has(rid):excluded.append(rid)
			query.exclude=excluded
	for hit:Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query,32):
		var collider:Node=hit.get("collider")
		if is_instance_valid(target) and is_instance_valid(collider) and (collider==target or target.is_ancestor_of(collider)):continue
		return true
	return false

func _holder_reaction31(host:Node,origin:Vector3,grip_delta:Vector3=Vector3.INF)->bool:
	if not bool(host.get("_npc_dead")) or not is_instance_valid(host.get("_npc_corpse31")):return false
	if _holder_reaction_frame==Engine.get_physics_frames():return false
	var margin:=_self_margin(host,origin)
	var reaching:=grip_delta.is_finite()
	if not reaching and margin>=.012:return false
	var epsilon:=.003
	var gradient:=Vector3(
		_self_margin(host,origin-Vector3.RIGHT*epsilon)-_self_margin(host,origin+Vector3.RIGHT*epsilon),0,
		_self_margin(host,origin-Vector3.BACK*epsilon)-_self_margin(host,origin+Vector3.BACK*epsilon))
	var directions:Array[Vector3]=[]
	if reaching:
		var toward:=Vector3(grip_delta.x,0,grip_delta.z)
		if toward.length_squared()>1e-12:directions.append(toward.normalized())
	if gradient.length_squared()>1e-12:directions.append(gradient.normalized())
	var horizontal:=Vector3(_axis.x,0,_axis.z).normalized()
	directions.append(horizontal);directions.append(-horizontal)
	directions.append(Vector3(-horizontal.z,0,horizontal.x));directions.append(Vector3(horizontal.z,0,-horizontal.x))
	var player:CharacterBody3D=host.get("_player")
	for distance:float in [.01,.02,.03,.04]:
		for direction:Vector3 in directions:
			var step:=direction*distance
			if reaching and (grip_delta-step).length_squared()>=grip_delta.length_squared()-.000025:continue
			if _self_margin(host,origin-step)<.012:continue
			if player.test_move(player.global_transform,step):continue
			var before:=player.global_position
			player.move_and_collide(step)
			var actual:=player.global_position-before
			_holder_reaction_frame=Engine.get_physics_frames()
			# Hands remain on the same actual shaft. Native body separation is
			# arm accommodation, not a commanded pull of the weapon along its bore.
			_player_previous+=actual;_thrust_player+=actual;_corpse_brace_player+=actual
			holder_reaction_m+=actual.length();max_holder_reaction_step_m=maxf(max_holder_reaction_step_m,actual.length())
			return actual.length_squared()>1e-12
	return false

func pose(host:Node)->bool:
	if not sync(host):return false
	_apply_brace(host)
	var rig:Skeleton3D=host.get("_rig")
	var origin:=_entry+_anchor(_channel).basis*_entry_offset_local+_axis*(_depth-_tip_offset)
	if _holder_reaction31(host,origin):_apply_brace(host)
	var grip:Vector3=origin-_axis*float(host.call("_grip_origin_offset"))
	var blade_rig:Vector3=(rig.global_basis.inverse()*_axis).normalized()
	var grip_rig:Vector3=rig.global_transform.affine_inverse()*grip
	host.set("_dir",_axis)
	# A finite flat spear point retains its roll inside the existing slit, too.
	# Following only the shaft direction leaves a turned corner outside the bore.
	host.set("_edge_direction",(_anchor(_channel).basis*_steel_edge_local).normalized())
	var arm:Dictionary=host.call("_arm_set",&"right")
	host.call("_pose_arm_ik",arm.clav,arm.upper,arm.fore,arm.hand,arm.rest_upper,arm.rest_fore,arm.rest_hand,arm.offset,grip_rig,blade_rig,1.0,true,arm.pole)
	host.call("_pose_support",&"left",grip_rig-blade_rig*float(host.get("_two_hand_offset_rig")))
	rig.force_update_all_bone_transforms()
	var grip_error:float=Vector3(host.call("_palm_position",&"right")).distance_to(grip)
	var support_world:Vector3=rig.global_transform*(grip_rig-blade_rig*float(host.get("_two_hand_offset_rig")))
	var support_error:float=Vector3(host.call("_palm_position",&"left")).distance_to(support_world)
	if maxf(grip_error,support_error)>.015:
		var reaction:=grip-Vector3(host.call("_palm_position",&"right")) if grip_error>=support_error else support_world-Vector3(host.call("_palm_position",&"left"))
		if _holder_reaction31(host,origin,reaction):return pose(host)
	max_grip_error_m=maxf(max_grip_error_m,grip_error);max_support_error_m=maxf(max_support_error_m,support_error)
	self_clear=host.call("_self_blade_clear_at51",_axis,origin)
	world_clear=not _world_blocked(host,origin)
	if grip_error>0.04 or support_error>0.04 or not self_clear or not world_clear:
		_release_grip(host,"unreachable_grip" if grip_error>0.04 or support_error>0.04 else "self_or_world_obstruction")
		return true
	host.set("_dir",_axis);host.set("_sword_origin",origin);host.set("_omega",Vector3.ZERO)
	host.set("_sword_coast_until_ms31",0);host.set("_prev_points",PackedVector3Array())
	host.call("_place_sword",origin,_axis)
	# The polygon validates the complete held geometry after this intermediate
	# arm pose. Only its final accepted tip may deepen a wound or trigger death.
	var solid = host.get("_solid_weapon29") if "_solid_weapon29" in host else null
	if solid == null or not solid.owns_body_contacts(host):
		preload("res://scripts/combat/local_wound28.gd").advance_active29(host,preload("res://scripts/combat/puncture29.gd").tip_world(host))
	_channel["grip_error_m"]=grip_error
	_channel["support_error_m"]=support_error
	return true

func status()->Dictionary:
	return {"holder_reaction_m":holder_reaction_m,"max_holder_reaction_step_m":max_holder_reaction_step_m,"corpse_brace":corpse_brace,"max_foot_error_m":max_foot_error_m,"max_crouch_m":max_crouch_m,"active":not _channel.is_empty(),"depth":_depth,"axis":_axis,"entry":_entry,"begins":begins,"ends":ends,"last_reason":last_reason,"rejected_lateral_m":rejected_lateral_m,"max_grip_error_m":max_grip_error_m,"max_support_error_m":max_support_error_m,"self_clear":self_clear,"world_clear":world_clear}

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
