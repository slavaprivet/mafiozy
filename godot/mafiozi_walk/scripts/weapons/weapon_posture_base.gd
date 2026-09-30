extends "res://scripts/weapons/weapon_pose.gd"
## Exact hero_walk posturePose on supplied locomotion; no live bone writes.
## Host owns stance collision admission, movement speed and source phase/gait.
var _floor_ready:=false
var _floor_to_motion:=Transform3D.IDENTITY
var _floor_parents:=PackedInt32Array()
var _floor_globals:Array[Transform3D]=[]
var _floor_rigid_bones:=PackedInt32Array()
var _floor_rigid_points:Array[PackedVector3Array]=[]
var _floor_mixed_bones:=PackedInt32Array()
var _floor_mixed_points:=PackedVector3Array()
var _floor_mixed_weights:=PackedFloat32Array()
var _floor_mixed_ends:=PackedInt32Array()
var _floor_axes:=PackedVector3Array()
var _floor_origins:=PackedFloat32Array()
var _rest_normalized:=Transform3D.IDENTITY
var _rest_rig:=Transform3D.IDENTITY
var _bound_height:=0.0
var _bound_source_height:=0.0
var _floor_source_vertices:=0
var _floor_unique_vertices:=0
var _floor_bindings:Array[Dictionary]=[]
var _floor_resources:Array[Resource]=[]
var _floor_rig:WeakRef
var _floor_motion:WeakRef
var _floor_rig_version:=-1
var _posture_target:="stand"
var _posture_value:=0.0
var _posture_blocked:=false
var _posture_busy:=false
var _floor_last_poses:Array[Transform3D]=[]
var _floor_last_rotation:=Quaternion.IDENTITY
var _floor_last_minimum:=NAN
var _floor_cache_hits:=0
var _gait_phase:=0.0
var _gait_weight:=0.0

static func view(value:float,running:bool=false,slow_walking:bool=false)->Dictionary:
	if not is_finite(value) or value<0 or value>2:return {}
	var p:=Visual._smooth(value,1,2);var c:=Visual._smooth(value,0,1)*(1-p)
	var standing:=1.65 if slow_walking else 7.8 if running else 4.6
	var speed:=lerpf(lerpf(standing,1.55,c),.8,p)
	return {"value":value,"crouch":c,"prone":p,"height":lerpf(lerpf(1.9,1.69,c),.62,p),"eyeHeight":lerpf(lerpf(1.64,1.4,c),.43,p),"maxSpeed":speed,"speedMultiplier":speed/standing,"crawl":p>.5}

func posture_state(running:bool=false,slow_walking:bool=false)->Dictionary:
	var result:=view(_posture_value,running,slow_walking)
	result.target=_posture_target;result.blocked=_posture_blocked;return result

func request_posture(target:String,can_occupy_height:Callable=Callable())->bool:
	if _posture_busy or not Thread.is_main_thread() or target not in ["stand","crouch","prone"]:return false
	var desired:float={"stand":1.9,"crouch":1.69,"prone":.62}[target]
	if desired>view(_posture_value).height and can_occupy_height.is_valid():
		_posture_busy=true;var allowed:Variant=can_occupy_height.call(desired,target);_posture_busy=false
		if allowed!=true:_posture_blocked=true;return false
	_posture_target=target;_posture_blocked=false;return true

func step_posture(delta:float,can_occupy_height:Callable=Callable(),running:bool=false,slow_walking:bool=false)->Dictionary:
	if _posture_busy or not Thread.is_main_thread() or not is_finite(delta) or delta<0:return _fail("posture_delta")
	var target:float={"stand":0.0,"crouch":1.0,"prone":2.0}[_posture_target]
	var next:=_posture_value+clampf(target-_posture_value,-delta*2.1,delta*2.1);var blocked:=false
	if next<_posture_value and can_occupy_height.is_valid():
		_posture_busy=true;var allowed:Variant=can_occupy_height.call(view(next).height,_posture_target);_posture_busy=false
		if allowed!=true:next=_posture_value;blocked=true
	_posture_value=clampf(next,0,2);_posture_blocked=blocked;return posture_state(running,slow_walking)

func reset_posture(target:String="stand")->bool:
	if _posture_busy or not Thread.is_main_thread() or target not in ["stand","crouch","prone"]:return false
	_posture_target=target;_posture_value={"stand":0.0,"crouch":1.0,"prone":2.0}[target];_posture_blocked=false;return true

func seed_gait(phase:float,gait:float)->bool:
	if not is_finite(phase) or not is_finite(gait) or gait<0 or gait>1:return false
	_gait_phase=phase;_gait_weight=gait;return true

func sample_ground(base:Dictionary,motion:Dictionary,aim_yaw:float,epoch:int)->Dictionary:
	# Call on every grounded on-foot tick; standing remains the existing sampler.
	# Nonstanding gait is rebuilt from canonical rest at its ORIGINAL source
	# clock, so slow crawling never gets a mismatched standing-phase skeleton.
	if not _ready or not Thread.is_main_thread() or not _floor_live() or not base.get("valid",false):return _fail("ground_binding")
	for key:String in ["delta","speed","actor_yaw","standing_phase","standing_gait"]:
		if not _number(motion.get(key)):return _fail("ground_motion")
	if motion.delta<0 or motion.speed<0 or motion.standing_gait<0 or motion.standing_gait>1 or not motion.get("moving") is bool or not _frame(motion.get("actor_world")) or not is_finite(aim_yaw):return _fail("ground_motion")
	if not motion.get("running",false) is bool or not motion.get("slow_walking",false) is bool:return _fail("ground_speed_mode")
	var distance:Variant=motion.get("distance",NAN)
	if not (distance is float or distance is int) or is_inf(distance) or (is_finite(distance) and distance<0):return _fail("ground_distance")
	if _posture_value==0.0 and _posture_target=="stand":
		seed_gait(motion.standing_phase,motion.standing_gait);return base
	var dt:=minf(.1,motion.delta);var moving:bool=motion.moving;var posture:=posture_state(motion.get("running",false),motion.get("slow_walking",false))
	_gait_weight+=((1.0 if moving else 0.0)-_gait_weight)*(1-exp(-10*dt))
	if not moving and _gait_weight<.0001:_gait_weight=0
	var radians:float=3.8/posture.maxSpeed if posture.prone>.5 else 2.3
	_gait_phase+=float(distance)*radians if moving and is_finite(distance) else dt*(motion.speed*radians if moving else 3.0)
	var prepared:=base.duplicate();var poses:Array[Transform3D]=_rest.duplicate()
	if _gait_weight>0:
		_gait_rotate(poses,"chest",0,0,sin(_gait_phase)*_gait_weight*.018)
		for side:String in ["l","r"]:
			var stride:=sin(_gait_phase)*(1 if side=="l" else -1)*_gait_weight
			_gait_rotate(poses,"thigh_"+side,stride*.56);_gait_rotate(poses,"shin_"+side,maxf(0,-stride)*.52);_gait_rotate(poses,"foot_"+side,-stride*.22)
			_gait_rotate(poses,"upperarm_"+side,-stride*.38);_gait_rotate(poses,"forearm_"+side,-maxf(0,stride)*.12)
	prepared.poses=poses
	var result:=sample_locomotion(prepared,_posture_value,_gait_phase,_gait_weight,motion.actor_world,motion.actor_yaw,aim_yaw,epoch)
	if result.get("valid",false):result.weapon_posture.phase=_gait_phase;result.weapon_posture.gait=_gait_weight
	return result

func _gait_rotate(poses:Array[Transform3D],name:String,x:float=0,y:float=0,z:float=0)->void:
	var i:int=_names[name];poses[i]=_compose(_q(_rest[i])*_xyz(x,y,z),_rest[i].basis.get_scale(),_rest[i].origin)

static func height_query(height:float,floor_y:float,ceiling_y:float,horizontal_body_intervals:Array[Vector2]=[],radius:float=.30)->Dictionary:
	# Pure original source vertical test. Intervals must already overlap the
	# queried horizontal point. Actual capsule/shape overlap is ROOT-owned.
	if not is_finite(height) or height<=0 or not is_finite(floor_y) or is_nan(ceiling_y) or not is_finite(radius) or radius<=0 or height<2*radius:return {"valid":false,"query_required":true}
	var clear:=ceiling_y>=floor_y+height-.03
	for interval:Vector2 in horizontal_body_intervals:
		if not interval.is_finite() or interval.x>interval.y:return {"valid":false,"query_required":true}
		if interval.y<floor_y+.05 or interval.x>floor_y+height:continue
		clear=false
	return {"valid":true,"source_vertical_clear":clear,"query_required":true,"height":height,"radius":radius,"center_from_feet":Vector3(0,height*.5,0),"foot_y":floor_y}

func configure_player(player:Node3D)->bool:
	if not Thread.is_main_thread() or not is_instance_valid(player) or not player.is_inside_tree():return false
	var rig:=player.get("_pose_skeleton") as Skeleton3D;var motion:=player.get("_pose_motion") as Node3D
	if rig==null or motion==null:return false
	var normalized:=motion.get_node_or_null("UniformModelScale") as Node3D
	if normalized==null:return false
	var names:=PackedStringArray();var parents:=PackedInt32Array();var rest:Array[Transform3D]=[]
	for i:int in rig.get_bone_count():names.append(rig.get_bone_name(i));parents.append(rig.get_bone_parent(i));rest.append(rig.get_bone_rest(i))
	_rest_rig=motion.global_transform.affine_inverse()*rig.global_transform
	_rest_normalized=motion.global_transform.affine_inverse()*normalized.global_transform
	if not configure(names,parents,rest,_rest_rig):return false
	_bound_height=player.get("model_target_height");_bound_source_height=player.get("_source_height")
	if not configure_exact_floor(rig,motion):dispose();return false
	return true

func configure_exact_floor(rig:Skeleton3D,motion:Node3D)->bool:
	# Reconstructed physics hull vertices can shift an extreme by ~26 micrometres.
	# Retain original source support coordinates; dedup only identical full skin
	# contributions at bind time. The hot path is packed scalar Y projections.
	if not _ready or _floor_ready or rig==null or motion==null:return false
	_floor_to_motion=motion.global_transform.affine_inverse()*rig.global_transform;_floor_parents=_parents.duplicate()
	var unique:Dictionary={};var rigid:Dictionary={}
	for mesh:MeshInstance3D in motion.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue # attached weapon geometry is not source hero skin
		if mesh.mesh==null or mesh.get_node_or_null(mesh.skeleton)!=rig:return false
		_floor_bindings.append({"node":weakref(mesh),"mesh":mesh.mesh,"skin":mesh.skin,"skeleton":mesh.skeleton})
		for resource:Resource in [mesh.mesh,mesh.skin]:
			if resource not in _floor_resources:_floor_resources.append(resource);resource.changed.connect(_invalidate_floor)
		var ids:=PackedInt32Array();var binds:Array[Transform3D]=[]
		for b:int in mesh.skin.get_bind_count():
			var id:=rig.find_bone(mesh.skin.get_bind_name(b))
			if id<0:return false
			ids.append(id);binds.append(mesh.skin.get_bind_pose(b))
		for surface:int in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var joints:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			if joints.size()!=vertices.size()*4 or weights.size()!=joints.size():return false
			_floor_source_vertices+=vertices.size()
			for i:int in vertices.size():
				var key:Array=[]
				for j:int in 4:
					var at:=i*4+j
					if weights[at]>0:key.append(ids[joints[at]]);key.append(binds[joints[at]]*vertices[i]);key.append(weights[at])
				if unique.has(key):continue
				unique[key]=true;_floor_unique_vertices+=1
				if key.size()==3 and key[2]==1.0:
					if not rigid.has(key[0]):rigid[key[0]]=PackedVector3Array()
					rigid[key[0]].append(key[1])
				else:
					for at:int in range(0,key.size(),3):
						_floor_mixed_bones.append(key[at]);_floor_mixed_points.append(key[at+1]*key[at+2]);_floor_mixed_weights.append(key[at+2])
					_floor_mixed_ends.append(_floor_mixed_bones.size())
	for id:int in rigid:_floor_rigid_bones.append(id);_floor_rigid_points.append(rigid[id])
	_floor_globals.resize(COUNT);_floor_axes.resize(COUNT);_floor_origins.resize(COUNT)
	_floor_rig=weakref(rig);_floor_motion=weakref(motion);_floor_rig_version=rig.get_version()
	_floor_ready=_floor_source_vertices==8338
	return _floor_ready

func _invalidate_floor()->void:_floor_ready=false;_floor_last_poses.clear();_floor_last_minimum=NAN
func _floor_live()->bool:
	var valid:=_floor_binding_current()
	if not valid:_invalidate_floor()
	return valid
func _floor_binding_current()->bool:
	if not _floor_ready or _floor_rig==null or _floor_motion==null:return false
	var rig:=_floor_rig.get_ref() as Skeleton3D;var motion:=_floor_motion.get_ref() as Node3D
	if not is_instance_valid(rig) or not is_instance_valid(motion) or rig.get_version()!=_floor_rig_version or not motion.is_ancestor_of(rig):return false
	if not (motion.global_transform.affine_inverse()*rig.global_transform).is_equal_approx(_floor_to_motion):return false
	for item:Dictionary in _floor_bindings:
		var mesh:=item.node.get_ref() as MeshInstance3D
		if not is_instance_valid(mesh) or not mesh.is_inside_tree() or mesh.mesh!=item.mesh or mesh.skin!=item.skin or mesh.skeleton!=item.skeleton or mesh.get_node_or_null(mesh.skeleton)!=rig:return false
		var node:Node=mesh
		while node!=null:
			if node.is_queued_for_deletion():return false
			node=node.get_parent()
	return true

func sample_locomotion(base:Dictionary,value:float,phase:float,gait:float,actor_world:Transform3D,actor_yaw:float,aim_yaw:float,epoch:int)->Dictionary:
	var posture:=view(value)
	if posture.is_empty() or not _number(phase) or not _number(gait) or gait<0 or gait>1 or not _number(actor_yaw) or not _number(aim_yaw):return _fail("posture_inputs")
	if not _floor_live():return _fail("not_player_bound")
	# Source update resets the visual pivot, applies aim heading, then source bob.
	# Native standing locomotion has a different boot-floor offset; do not pretend
	# it is source bob or retain that standing correction in a prone pose.
	var prepared:=base.duplicate();var bob:float=absf(sin(phase))*gait*.026*(1-posture.prone)
	prepared.visual_rotation=Quaternion(Vector3.UP,aim_yaw-actor_yaw)
	prepared.visual_offset=Vector3(0,bob,0);prepared.scaled_offset=Vector3(0,bob,0)
	var frame:=make_frame(actor_world,actor_yaw,prepared,_rest_rig,_rest_normalized,_bound_height,_bound_source_height)
	return sample_posture(prepared,frame,posture,phase,gait,epoch,true)

func sample_posture(base:Dictionary,frame:Dictionary,posture:Dictionary,phase:float,gait:float,epoch:int,weapon_mounted:bool=true)->Dictionary:
	if not _ready or _busy or not Thread.is_main_thread() or not base.get("valid",false) or not base.get("poses") is Array or base.poses.size()!=COUNT or base.has("weapon") or base.has("weapon_posture"):return _fail("base_or_order")
	if epoch<0 or base.get("authority_epoch",epoch)!=epoch or not _number(phase) or not _number(gait) or gait<0 or gait>1:return _fail("epoch_or_gait")
	for key:String in ["crouch","prone"]:
		if not _number(posture.get(key)) or posture[key]<0 or posture[key]>1:return _fail("posture")
	for key:String in ["actor_world","visual_pivot_world","skeleton_world","offset_world"]:
		if not _frame(frame.get(key)):return _fail("frame")
	if not _number(frame.get("target_height")) or not _number(frame.get("source_height")) or frame.source_height<=0 or frame.target_height<=0:return _fail("dimensions")
	for pose:Variant in base.poses:
		if not _frame(pose):return _fail("bone")
	_poses.assign(base.poses);_rig_frame=frame.skeleton_world;_actor_q=_q(frame.actor_world);_prop_scale=frame.target_height/frame.source_height;_update_world()
	var c:float=posture.crouch;var p:float=posture.prone
	if c>=1e-5 or p>=1e-5:
		var feet:Dictionary={}
		for side:String in ["l","r"]:feet[side]={"p":_position("foot_"+side),"q":_rotation("foot_"+side)}
		var cycle:=sin(phase);var bob:=cos(phase*2);var crawl:=p*gait
		var index:int=_names.pelvis;var pivot:=Vector3(0,1.46,0);var turn:=_xyz(p*PI/2,0,0)
		var position:=_rotate(turn,_rest[index].origin-pivot)+pivot;position.y-=c*.24*(frame.source_height/1.9)+p*.60
		_poses[index]=_compose(_q(_rest[index])*turn,_rest[index].basis.get_scale(),position);_update_world()
		_rotate_add("chest",c*.32-p*.12+crawl*bob*.02,crawl*cycle*.04,crawl*cycle*.035)
		_rotate_add("neck",-c*.14-p*.40,0,0);_rotate_add("head",-c*.18-p*.55,0,0)
		var root_q:=_q(frame.visual_pivot_world)
		for side:String in ["l","r"]:
			var sign_side:float=-1 if side=="l" else 1;var stride:=cycle*sign_side*gait
			var prone_foot:=_position("thigh_"+side)+_rotate(root_q,Vector3(sign_side*(.05+maxf(0,stride)*.12),-.18,-1.16+maxf(0,stride)*.20)*_prop_scale)
			var target:Vector3=feet[side].p.lerp(prone_foot,p)
			var foot_q:=Quaternion(_rotate(root_q,Vector3.RIGHT),p*.95)*(feet[side].q as Quaternion)
			_reach_foot(side,target,foot_q,p,root_q)
			if p>.001 and not weapon_mounted:
				var support:Vector3=frame.offset_world*Vector3(sign_side*.78,.30+maxf(0,stride)*.08,2.12+stride*.23)
				_reach(side,_position("socket_hand_"+side).lerp(support,p),root_q*_hand_rest[side])
	for pose:Transform3D in _poses:
		if not _frame(pose):return _fail("result")
	var result:=base.duplicate();result.poses=_poses.duplicate();result.authority_epoch=epoch
	result.weapon_posture=posture.duplicate();return result

func _reach_foot(side:String,target:Vector3,foot_q:Quaternion,prone:float,root_q:Quaternion)->void:
	var upper:="thigh_"+side;var lower:="shin_"+side;var foot:="foot_"+side;var hip:=_position(upper)
	var a:=hip.distance_to(_position(lower));var b:=_position(lower).distance_to(_position(foot));var line:=target-hip
	var distance:=minf(a+b-1e-6,maxf(absf(a-b)+1e-6,line.length()));line=line.normalized()
	var bend:=_rotate(root_q,Vector3((1 if side=="r" else -1)*prone*.15,-prone,1-prone*1.12))
	bend=(bend-line*bend.dot(line)).normalized();var along:=(a*a-b*b+distance*distance)/(2*distance);var height:=sqrt(maxf(0,a*a-along*along))
	_point_bone(upper,lower,hip+line*along+bend*height);_point_bone(lower,foot,target);_world_rotation(foot,foot_q)

func ground_after_weapon(selected:Dictionary)->Dictionary:
	if not _ready or not Thread.is_main_thread() or not _floor_live() or not selected.get("valid",false) or not selected.get("poses") is Array or selected.poses.size()!=COUNT:return _fail("floor_binding_or_pose")
	var rotation:Variant=selected.get("visual_rotation",Quaternion.IDENTITY);var offset:Variant=selected.get("visual_offset")
	if not rotation is Quaternion or not rotation.is_normalized() or not offset is Vector3 or not offset.is_finite():return _fail("floor_frame")
	if is_finite(_floor_last_minimum) and selected.poses==_floor_last_poses and rotation==_floor_last_rotation:
		_floor_cache_hits+=1
		return _floor_result(selected,offset,_floor_last_minimum)
	for i:int in COUNT:
		if not _frame(selected.poses[i]):return _fail("floor_bone")
		_floor_globals[i]=selected.poses[i] if _floor_parents[i]<0 else _floor_globals[_floor_parents[i]]*selected.poses[i]
	var prefix:=Transform3D(Basis(rotation),Vector3.ZERO)*_floor_to_motion
	for i:int in COUNT:
		var transform:=prefix*_floor_globals[i]
		_floor_axes[i]=Vector3(transform.basis.x.y,transform.basis.y.y,transform.basis.z.y);_floor_origins[i]=transform.origin.y
	var minimum:=INF
	for group:int in _floor_rigid_bones.size():
		var bone:=_floor_rigid_bones[group]
		for point:Vector3 in _floor_rigid_points[group]:minimum=minf(minimum,_floor_axes[bone].dot(point)+_floor_origins[bone])
	var first:=0
	for end:int in _floor_mixed_ends:
		var y:=0.0
		for at:int in range(first,end):
			var bone:=_floor_mixed_bones[at];y+=_floor_axes[bone].dot(_floor_mixed_points[at])+_floor_origins[bone]*_floor_mixed_weights[at]
		minimum=minf(minimum,y);first=end
	if not is_finite(minimum):return _fail("floor_support")
	_floor_last_poses.assign(selected.poses);_floor_last_rotation=rotation;_floor_last_minimum=minimum
	return _floor_result(selected,offset,minimum)

func _floor_result(selected:Dictionary,offset:Vector3,minimum:float)->Dictionary:
	var result:=selected.duplicate();result.visual_offset=Vector3(offset.x,-minimum,offset.z)
	result.weapon_floor={"source_vertices":8338,"lowest_before":minimum+offset.y,"correction":-minimum-offset.y,"scope":"source actor-local skin Y plane; host retains physical collision/support authority"}
	return result

func finish_ground(selected:Dictionary)->Dictionary:
	# Call after weapon AND hit decorators, before the sole writer. No-op for
	# ordinary stand/crouch, whose original update does not call groundPose.
	var posture:Dictionary=selected.get("weapon_posture",{})
	var weapon:Dictionary=selected.get("weapon",{})
	return ground_after_weapon(selected) if float(posture.get("prone",0.0))>.001 or weapon.get("requires_post_weapon_ground_pose",false) else selected

func dispose()->void:
	if not Thread.is_main_thread():return
	for resource:Resource in _floor_resources:
		if is_instance_valid(resource) and resource.changed.is_connected(_invalidate_floor):resource.changed.disconnect(_invalidate_floor)
	_floor_resources.clear();_floor_bindings.clear();_floor_rig=null;_floor_motion=null;_floor_rig_version=-1
	_floor_last_poses.clear();_floor_last_minimum=NAN;_floor_cache_hits=0
	reset_posture()
	_gait_phase=0;_gait_weight=0
	super.dispose();_floor_ready=false;_floor_source_vertices=0;_floor_unique_vertices=0;_floor_parents.clear();_floor_globals.clear();_floor_rigid_bones.clear();_floor_rigid_points.clear()
	_floor_mixed_bones.clear();_floor_mixed_points.clear();_floor_mixed_weights.clear();_floor_mixed_ends.clear();_floor_axes.clear();_floor_origins.clear()
