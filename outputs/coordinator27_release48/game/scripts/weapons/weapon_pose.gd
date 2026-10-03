extends RefCounted
## Pure original hero_walk weaponPose / applyReloadPose / lookAlongAim.
## No Skeleton3D writes, geometry reads, clocks, admission, ammo or HP.
const COUNT := 28
const IDS := ["nagan","tt_pistol","revolver","deagle","golden_colt","sawn_off","shotgun","uzi","golden_uzi","ak74","m16","tommy_gun","sniper","rpg"]
const Visual = preload("res://scripts/weapon_visual/weapon_visual.gd")
var _ready := false
var _busy := false
var _names: Dictionary = {}
var _parents := PackedInt32Array()
var _rest: Array[Transform3D] = []
var _poses: Array[Transform3D] = []
var _world: Array[Transform3D] = []
var _hand_rest: Dictionary = {}
var _head_rest := Quaternion.IDENTITY
var _rig_frame := Transform3D.IDENTITY
var _actor_q := Quaternion.IDENTITY
var _prop_scale := 1.0

static func _frame(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and is_finite(value.basis.determinant()) and value.basis.determinant() > 1e-9
static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
static func _fail(reason: String) -> Dictionary: return {"valid":false,"error":reason}
static func _q(frame: Transform3D) -> Quaternion:
	# Three Matrix4.decompose normalizes each column independently, then applies
	# Quaternion.setFromRotationMatrix WITHOUT orthonormalizing an affine input.
	# Godot Basis.get_rotation_quaternion would silently replace that shear.
	var x:=frame.basis.x.normalized();var y:=frame.basis.y.normalized();var z:=frame.basis.z.normalized()
	var trace:=x.x+y.y+z.z
	if trace>0:
		var s:=.5/sqrt(trace+1.0)
		return Quaternion((y.z-z.y)*s,(z.x-x.z)*s,(x.y-y.x)*s,.25/s)
	if x.x>y.y and x.x>z.z:
		var s:=2.0*sqrt(1.0+x.x-y.y-z.z)
		return Quaternion(.25*s,(y.x+x.y)/s,(z.x+x.z)/s,(y.z-z.y)/s)
	if y.y>z.z:
		var s:=2.0*sqrt(1.0+y.y-x.x-z.z)
		return Quaternion((y.x+x.y)/s,.25*s,(z.y+y.z)/s,(z.x-x.z)/s)
	var s:=2.0*sqrt(1.0+z.z-x.x-y.y)
	return Quaternion((z.x+x.z)/s,(z.y+y.z)/s,.25*s,(x.y-y.x)/s)
static func _inverse(q: Quaternion) -> Quaternion: return Quaternion(-q.x,-q.y,-q.z,q.w)
static func _rotate(q: Quaternion,v: Vector3) -> Vector3:
	var axis:=Vector3(q.x,q.y,q.z);var t:=axis.cross(v)*2.0
	return v+t*q.w+axis.cross(t)
static func _compose(q: Quaternion,scale: Vector3,origin: Vector3) -> Transform3D:
	# Match Three compose even when its affine decomposition produced a nonunit q.
	var xx:=q.x*q.x*2;var yy:=q.y*q.y*2;var zz:=q.z*q.z*2
	var xy:=q.x*q.y*2;var xz:=q.x*q.z*2;var yz:=q.y*q.z*2
	var wx:=q.w*q.x*2;var wy:=q.w*q.y*2;var wz:=q.w*q.z*2
	return Transform3D(Basis(Vector3(1-yy-zz,xy+wz,xz-wy)*scale.x,Vector3(xy-wz,1-xx-zz,yz+wx)*scale.y,Vector3(xz+wy,yz-wx,1-xx-yy)*scale.z),origin)
static func _slerp(a: Quaternion,b: Quaternion,t: float) -> Quaternion:
	if t==0:return a
	if t==1:return b
	var cosine:=a.dot(b)
	if cosine<0:b=-b;cosine=-cosine
	if cosine>=1:return a
	var sine_squared:=1.0-cosine*cosine
	if sine_squared<=2.220446049250313e-16:return Quaternion(lerpf(a.x,b.x,t),lerpf(a.y,b.y,t),lerpf(a.z,b.z,t),lerpf(a.w,b.w,t)).normalized()
	var sine:=sqrt(sine_squared);var angle:=atan2(sine,cosine)
	var left:=sin((1-t)*angle)/sine;var right:=sin(t*angle)/sine
	return Quaternion(a.x*left+b.x*right,a.y*left+b.y*right,a.z*left+b.z*right,a.w*left+b.w*right)
static func _xyz(x: float,y: float,z: float) -> Quaternion:
	return Basis.from_euler(Vector3(x,y,z),EULER_ORDER_XYZ).get_rotation_quaternion()
static func _vector(value: Variant) -> Variant:
	if value is Vector3: return value if value.is_finite() else null
	if value is Array and value.size()==3 and _number(value[0]) and _number(value[1]) and _number(value[2]): return Vector3(value[0],value[1],value[2])
	return null

static func make_frame(actor_world: Transform3D,actor_yaw: float,base: Dictionary,rig_to_motion_rest: Transform3D,normalized_to_motion_rest: Transform3D,target_height: float,source_height: float) -> Dictionary:
	# Godot folds source visualPivot + scaled.position into one motion node.
	# Build from the selected pose, never the previous frame's live skeleton.
	var rotation: Variant=base.get("visual_rotation",Quaternion.IDENTITY)
	var offset: Variant=base.get("visual_offset")
	var scaled: Variant=base.get("scaled_offset",Vector3.ZERO)
	if not rotation is Quaternion or not rotation.is_finite() or not rotation.is_normalized() or not offset is Vector3 or not offset.is_finite() or not scaled is Vector3 or not scaled.is_finite(): return {}
	var basis:=Basis(rotation)
	var motion:=actor_world*Transform3D(basis,offset)
	return {"actor_world":actor_world,"actor_yaw":actor_yaw,
		"visual_pivot_world":actor_world*Transform3D(basis,offset-basis*scaled),
		"skeleton_world":motion*rig_to_motion_rest,"offset_world":motion*normalized_to_motion_rest,
		"scaled_y":scaled.y,"target_height":target_height,"source_height":source_height}

func configure(names: PackedStringArray, parents: PackedInt32Array, rest: Array[Transform3D], rest_rig_to_actor: Transform3D) -> bool:
	if not Thread.is_main_thread() or _ready or _busy or names.size()!=COUNT or parents.size()!=COUNT or rest.size()!=COUNT or not _frame(rest_rig_to_actor): return false
	var mapped: Dictionary = {}
	for i: int in COUNT:
		if names[i].is_empty() or mapped.has(names[i]) or parents[i]>=i or parents[i]<-1 or not _frame(rest[i]): return false
		mapped[names[i]]=i
	for name: String in ["chest","neck","head","socket_weapon","upperarm_l","forearm_l","hand_l","socket_hand_l","upperarm_r","forearm_r","hand_r","socket_hand_r"]:
		if not mapped.has(name): return false
	for side: String in ["l","r"]:
		if parents[mapped["forearm_"+side]]!=mapped["upperarm_"+side] or parents[mapped["hand_"+side]]!=mapped["forearm_"+side] or parents[mapped["socket_hand_"+side]]!=mapped["hand_"+side]: return false
	_names=mapped;_parents=parents.duplicate();_rest=rest.duplicate();_poses=rest.duplicate();_world.resize(COUNT);_rig_frame=rest_rig_to_actor;_update_world()
	for side: String in ["l","r"]: _hand_rest[side]=_rotation("hand_"+side)
	_head_rest=_rotation("head");_ready=true
	return true

func _update_world() -> void:
	for i: int in COUNT: _world[i]=(_rig_frame if _parents[i]<0 else _world[_parents[i]])*_poses[i]
func _position(name: String) -> Vector3: return _world[_names[name]].origin
func _rotation(name: String) -> Quaternion: return _q(_world[_names[name]])
func _rotate_add(name: String,x: float,y: float,z: float) -> void:
	var i: int=_names[name]
	_poses[i]=_compose(_q(_poses[i])*_xyz(x,y,z),_rest[i].basis.get_scale(),_rest[i].origin)
	_update_world()
func _world_rotation(name: String,desired: Quaternion) -> void:
	var i: int=_names[name]
	var parent: Transform3D=_rig_frame if _parents[i]<0 else _world[_parents[i]]
	_poses[i]=_compose(_inverse(_q(parent))*desired,_rest[i].basis.get_scale(),_rest[i].origin)
	_update_world()
static func _unit_vectors(from: Vector3,to: Vector3) -> Quaternion:
	var r:=from.dot(to)+1.0
	var cross: Vector3
	if r<1e-16: r=0;cross=Vector3(-from.y,from.x,0) if absf(from.x)>absf(from.z) else Vector3(0,-from.z,from.y)
	else: cross=from.cross(to)
	return Quaternion(cross.x,cross.y,cross.z,r).normalized()
func _point_bone(name: String,end: String,target: Vector3) -> void:
	var origin:=_position(name)
	var swing:=_unit_vectors((_position(end)-origin).normalized(),(target-origin).normalized())
	_world_rotation(name,swing*_rotation(name))
func _reach(side: String,target: Vector3,hand_q: Quaternion) -> void:
	var upper:="upperarm_"+side;var fore:="forearm_"+side;var hand:="hand_"+side
	var wrist:=target-_rotate(hand_q,_rest[_names["socket_hand_"+side]].origin*_prop_scale)
	var shoulder:=_position(upper)
	var a:=shoulder.distance_to(_position(fore));var b:=_position(fore).distance_to(_position(hand))
	var line:=wrist-shoulder
	var distance:=minf(a+b-1e-6,maxf(absf(a-b)+1e-6,line.length()));line=line.normalized()
	var bend:=_rotate(_actor_q,Vector3(.35 if side=="r" else -.35,-1,-.15))
	bend=(bend-line*bend.dot(line)).normalized()
	var along:=(a*a-b*b+distance*distance)/(2*distance)
	var height:=sqrt(maxf(0,a*a-along*along))
	var elbow:=shoulder+line*along+bend*height
	_point_bone(upper,fore,elbow);_point_bone(fore,hand,wrist);_world_rotation(hand,hand_q)

## frame supplies exact current source hierarchy transforms, BEFORE this decoration:
## actor_world/actor_yaw, visual_pivot_world, skeleton_world, offset_world,
## scaled_y, target_height/source_height. Base poses are absolute local bone matrices.
func sample(base: Dictionary,weapon: Dictionary,frame: Dictionary,aim: Dictionary={},posture: Dictionary={},phase: float=0.0,gait: float=0.0,epoch: int=0) -> Dictionary:
	if not _ready or _busy or not Thread.is_main_thread(): return _fail("binding_or_reentry")
	if weapon.get("id")=="none": return base
	if weapon.get("id") not in IDS or not weapon.get("two_handed") is bool or not weapon.get("source_metadata") is Dictionary: return _fail("weapon")
	if weapon.source_metadata.get("weaponId")!=weapon.id or weapon.source_metadata.get("twoHanded")!=weapon.two_handed: return _fail("weapon_identity")
	if base.get("valid")!=true or not base.get("valid") is bool or not base.get("poses") is Array or base.poses.size()!=COUNT or epoch<0 or base.get("authority_epoch",epoch)!=epoch: return _fail("base_or_epoch")
	if base.has("weapon"): return _fail("already_decorated")
	for key: String in ["actor_world","visual_pivot_world","skeleton_world","offset_world"]:
		if not _frame(frame.get(key)): return _fail("frame_"+key)
	for key: String in ["actor_yaw","scaled_y","target_height","source_height"]:
		if not _number(frame.get(key)): return _fail("frame_"+key)
	if frame.target_height<1 or frame.target_height>3 or frame.source_height<=0 or not is_finite(phase) or not is_finite(gait): return _fail("dimensions_or_gait")
	for key: String in ["crouch","prone"]:
		if not _number(posture.get(key,0.0)) or posture.get(key,0.0)<0 or posture.get(key,0.0)>1: return _fail("posture")
	if not aim.get("airborne",false) is bool: return _fail("airborne")
	for key: String in ["airBlend","landingAirBlend"]:
		var value: Variant=aim.get(key,1.0 if key=="airBlend" else 0.0)
		if not _number(value) or value<0 or value>1: return _fail("air_blend")
	if not (aim.get("reloadProgress",0.0) is float or aim.get("reloadProgress",0.0) is int): return _fail("reload")
	var data: Dictionary=weapon.source_metadata
	var long: bool=weapon.two_handed
	var mount: Variant=_vector(data.get("mountOffset",[.15,1.1,.18] if long else [.24,1.07,.26]))
	var support: Variant=_vector(data.get("supportGrip"))
	if data.get("supportGrip")!=null and support==null: return _fail("support")
	if support==null: support={"uzi":Vector3(0,-.01,.5),"golden_uzi":Vector3(0,-.01,.5),"tommy_gun":Vector3(0,-.1,.62),"sawn_off":Vector3(0,.1,.42),"rpg":Vector3(0,.09,.62)}.get(weapon.id,Vector3(0,.1,.62))
	var magazine: Variant=_vector(weapon.get("reload_magazine_local"))
	if weapon.get("reload_magazine_local")!=null and magazine==null: return _fail("magazine")
	if weapon.id in ["uzi","golden_uzi","ak74","m16","tommy_gun"] and magazine==null: return _fail("magazine_required")
	if mount==null: return _fail("mount")
	for pose: Variant in base.poses:
		if not _frame(pose): return _fail("bone")
	_poses.assign(base.poses);_rig_frame=frame.skeleton_world;_actor_q=_q(frame.actor_world);_prop_scale=frame.target_height/frame.source_height;_update_world()
	for side: String in ["l","r"]:
		if _position("upperarm_"+side).distance_to(_position("forearm_"+side))<1e-6 or _position("forearm_"+side).distance_to(_position("hand_"+side))<1e-6: return _fail("degenerate_arm")
	_busy=true
	var result:=_sample(weapon,frame,aim,posture,phase,gait,long,mount,support,magazine)
	_busy=false
	for pose: Transform3D in _poses:
		if not _frame(pose): return _fail("result_bone")
	if not _frame(result.local_to_socket) or not _frame(result.world_before_ground): return _fail("result_weapon")
	var output:=base.duplicate()
	output.poses=_poses.duplicate();output.authority_epoch=epoch;output.weapon=result
	return output

func dispose() -> void:
	if not Thread.is_main_thread() or _busy: return
	_ready=false;_names.clear();_parents.clear();_rest.clear();_poses.clear();_world.clear();_hand_rest.clear()

func _sample(weapon: Dictionary,frame: Dictionary,aim: Dictionary,posture: Dictionary,phase: float,gait: float,long: bool,mount: Vector3,support: Vector3,magazine: Variant) -> Dictionary:
	var unit: float=frame.target_height/1.9
	var pitch:=clampf(float(aim.aimPitch),-1.28,1.28) if _number(aim.get("aimPitch")) else 0.0
	var kick:=clampf(float(aim.recoil),0,1) if _number(aim.get("recoil")) else 0.0
	var side:=clampf(float(aim.recoilYaw),-1,1) if _number(aim.get("recoilYaw")) else 0.0
	var airborne: bool=aim.get("airborne",false)
	var air_blend: float=aim.get("airBlend",1.0)
	var landing: float=aim.get("landingAirBlend",0.0)
	var body_kick:=kick if airborne else kick*(1-landing)
	var body_side:=side if airborne else side*(1-landing)
	_rotate_add("chest",-body_kick*(.055 if long else .035),body_side*.035,body_side*(.018 if long else .028))
	_rotate_add("neck",body_kick*.022,-body_side*.018,0);_rotate_add("head",body_kick*.014,-body_side*.012,0)
	var prone: float=posture.get("prone",0.0);var crouch: float=posture.get("crouch",0.0)
	if long and not airborne:
		var turn:=.25*(1-prone)*(1-landing)
		_rotate_add("chest",0,turn,0);_rotate_add("neck",0,-turn,0)
	var reload_progress: float=aim.get("reloadProgress",0.0)
	var reload:=Visual.sample_reload(reload_progress)
	var aim_q:=_xyz(-pitch-kick*(.13 if long else .105)-reload.lower*.16,side*.025,side*.012)
	var root_q:=_actor_q*Quaternion(Vector3.UP,float(aim.aimYaw)-float(frame.actor_yaw) if _number(aim.get("aimYaw")) else 0.0)
	var weapon_q:=root_q*aim_q
	var origin:=mount*unit
	if long: origin.z+=(.14 if weapon.id=="rpg" else .13 if weapon.id=="sawn_off" else .11)*unit
	origin.y+=frame.scaled_y-crouch*.24*unit-prone*.43+kick*(.018 if long else .028)*unit
	origin.z+=crouch*.10*unit+prone*.45-kick*(.07 if long else .045)*unit
	var origin_world: Vector3=frame.visual_pivot_world*origin
	if prone>.001:
		var prone_mount:=Vector3(.36 if long else .43,.70,2.35 if long else 2.45)
		prone_mount+=Vector3(sin(phase)*gait*.045,(1+cos(phase*2))*gait*.015,cos(phase*2)*gait*.10)
		origin_world=origin_world.lerp(frame.offset_world*prone_mount,prone)
	if airborne or landing>0:
		var air_origin:=(_position("upperarm_r")+_position("upperarm_l"))*.5+_rotate(root_q,Vector3(.03,-.06,.10)*unit) if long else _position("upperarm_r")+_rotate(root_q,Vector3(-.07,-.11,.25)*unit)
		origin_world=origin_world.lerp(air_origin,clampf(air_blend if airborne else landing,0,1))
	origin_world.y-=reload.lower*.03*unit
	var palm_right: Quaternion=root_q*aim_q*Quaternion(Vector3.RIGHT,-PI/2)*_hand_rest.r
	var palm_left: Quaternion=root_q*aim_q*Quaternion(Vector3.RIGHT,-PI/2)*_hand_rest.l
	if long or prone>.001:
		var centers: Array[Vector3]=[];var radii: Array[float]=[]
		for hand: String in (["r","l"] if long else ["r"]):
			var point:=Vector3(0,-.13,-.02) if hand=="r" else support
			var shoulder:=_position("upperarm_"+hand)
			radii.append(shoulder.distance_to(_position("forearm_"+hand))+_position("forearm_"+hand).distance_to(_position("hand_"+hand))-.004*unit)
			centers.append(shoulder-_rotate(weapon_q,point*_prop_scale)+_rotate(palm_right if hand=="r" else palm_left,_rest[_names["socket_hand_"+hand]].origin*_prop_scale))
		for iteration: int in 16:
			for i: int in centers.size():
				var d:=origin_world-centers[i]
				if d.length()>radii[i]: origin_world=centers[i]+d.normalized()*radii[i]
	_reach("r",_rotate(weapon_q,Vector3(0,-.13,-.02)*_prop_scale)+origin_world,palm_right)
	var reload_target:=_rotate(weapon_q,Vector3(-.08,-.34,.12)*_prop_scale)+origin_world
	if long or reload.grab>.001:
		var target: Vector3=_rotate(weapon_q,support*_prop_scale)+origin_world if long else _position("socket_hand_l")
		_reach("l",target.lerp(reload_target,reload.grab),palm_left)
	if not long and reload.grab<.001 and prone>.001 and landing<1:
		var crawl:=gait*sin(phase);var weight:=1-landing
		var free_support: Vector3=frame.offset_world*Vector3(-.78,.30+maxf(0,-crawl)*.08,2.12-crawl*.23)
		var before: Array[Quaternion]=[]
		for name: String in ["upperarm_l","forearm_l","hand_l"]: before.append(_q(_poses[_names[name]]))
		_reach("l",free_support,root_q*_hand_rest.l)
		if landing>0:
			var i:=0
			for name: String in ["upperarm_l","forearm_l","hand_l"]:
				var index: int=_names[name];var current:=_poses[index]
				_poses[index]=_compose(_slerp(before[i],_q(current),weight),current.basis.get_scale(),current.origin);i+=1
			_update_world()
	var socket: Transform3D=_world[_names.socket_weapon]
	var weapon_local:=_compose(_inverse(_q(socket))*weapon_q,Vector3.ONE,socket.affine_inverse()*origin_world)
	var weapon_world:=socket*weapon_local
	if is_finite(reload_progress) and reload.grab>.001 and magazine!=null:
		var magazine_pose: Vector3=magazine+Vector3(-reload.pull*.25*prone,-reload.pull*.62*(1-prone),0)
		var grip:=weapon_world*magazine_pose;grip.y-=.025*unit
		_reach("l",_position("socket_hand_l").lerp(grip,reload.grab),_rotation("hand_l"))
	if _number(aim.get("aimYaw")):
		_world_rotation("head",root_q*Quaternion(Vector3.RIGHT,-pitch)*_head_rest)
	return {"id":weapon.id,"local_to_socket":weapon_local,"world_before_ground":weapon_world,"reload":reload,
		"requires_post_weapon_ground_pose":prone>.001 or landing>0,"airborne_post_ground_owned_by_host":airborne,
		"scope":"Original supplied-base weapon/reload/head presentation; host must apply any subsequent full-skin ground correction to rig and attached gun together"}
