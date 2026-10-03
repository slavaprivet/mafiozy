extends RefCounted
## Pure port of hero_artist14_melee.mjs. Host owns admission, clocks, contacts,
## movement and the sole bone writer. IK's authored stretch/shear is retained.
const SkinData = preload("res://scripts/vehicle_visual/vehicle_exit_pose.gd")
const DURATIONS := {"punch":.34,"kick":.62,"heavy":.50,"backfist":.50,"dropkick":1.25}
var _skin: RefCounted
var _rest: Array[Transform3D] = []
var _poses: Array[Transform3D] = []
var _parents := PackedInt32Array()
var _names := {}
var _world: Array[Transform3D] = []
var _records := {}
var _actor := Transform3D.IDENTITY
var _source_offset := Vector3.ZERO
var _unit := 1.0
var _ready := false
var _busy := false
var _phase := 0.0
var _gait := 0.0
var _prone := 0.0
var _skin_bones:=PackedInt32Array()
var _skin_points:=PackedVector3Array()
var _skin_weights:=PackedFloat32Array()
var _skin_ends:=PackedInt32Array()
var _skin_axes:=PackedVector3Array()
var _skin_y:=PackedFloat64Array()

func configure(skeleton: Skeleton3D, motion: Node3D, canonical_rest: Array[Transform3D], source_scale: float, hero_root: Node3D) -> bool:
	if _busy or _ready or not Thread.is_main_thread() or canonical_rest.size()!=28:return false
	_skin=SkinData.new()
	if not _skin.configure(skeleton,motion,canonical_rest,source_scale,hero_root):return false
	_unit=source_scale;_rest=canonical_rest.duplicate();_parents=_skin._parents.duplicate();_names=_skin._names.duplicate()
	_skin_bones=_skin._bones;_skin_points=_skin._points;_skin_weights=_skin._weights;_skin_ends=_skin._ends
	_skin_axes.resize(28);_skin_y.resize(28)
	_actor=Transform3D(_skin._to_motion.basis.scaled(Vector3.ONE/_unit),Vector3.ZERO)
	_source_offset=_skin._to_motion.origin/_unit
	if not _actor.basis.is_equal_approx(_actor.basis.orthonormalized()):return false
	for name:String in ["root","pelvis","chest","upperarm_l","forearm_l","hand_l","socket_hand_l","upperarm_r","forearm_r","hand_r","socket_hand_r","thigh_l","shin_l","foot_l","thigh_r","shin_r","foot_r"]:
		if not _names.has(name):return false
	_world.resize(28);_poses=_rest.duplicate();_update_world()
	for name:String in _names:
		var f:Transform3D=_world[_names[name]]
		_records[name]={"p":f.origin,"q":f.basis.get_rotation_quaternion()}
	for side:String in ["l","r"]:
		for pair:Array in [["upperarm_","forearm_"],["forearm_","hand_"],["thigh_","shin_"],["shin_","foot_"]]:
			var name:String=pair[0]+side;var direction:Vector3=_records[pair[1]+side].p-_records[name].p
			if direction.length()<1e-6:return false
			_records[name].length=direction.length();_records[name].dir=direction.normalized()
	_ready=true;return true

static func _smooth(value:float,a:float,b:float)->float:
	var t:=clampf((value-a)/(b-a),0,1);return t*t*(3-2*t)
static func _finite(value:Variant)->bool:return (value is float or value is int) and is_finite(float(value))
static func _truthy(value:Variant)->bool:
	if value==null:return false
	if value is bool:return value
	if value is float or value is int:return value!=0 and not is_nan(float(value))
	if value is String:return not value.is_empty()
	return true
static func _xyz(x:float,y:float,z:float)->Quaternion:
	return Basis.from_euler(Vector3(x,y,z),EULER_ORDER_XYZ).get_rotation_quaternion()
func _update_world()->void:
	for i in 28:_world[i]=(_actor if _parents[i]<0 else _world[_parents[i]])*_poses[i]
func _position(name:String)->Vector3:return _world[_names[name]].origin
func _rotation(name:String)->Quaternion:return _world[_names[name]].basis.get_rotation_quaternion()
func _set_world(name:String,start:Vector3,orientation:Quaternion,stretch:float=1.0)->void:
	var i:int=_names[name];var parent:Transform3D=_actor if _parents[i]<0 else _world[_parents[i]]
	_poses[i]=parent.affine_inverse()*Transform3D(Basis(orientation)*Basis.from_scale(Vector3(1,stretch,1)),start)
	_update_world()
func _segment(name:String,start:Vector3,end:Vector3)->void:
	var r:Dictionary=_records[name];var direction:=end-start
	var q:Quaternion=Quaternion(r.dir,direction.normalized())*r.q
	_set_world(name,start,q,direction.length()/float(r.length))
func _rotate_add(name:String,x:float,y:float,z:float)->void:
	var i:int=_names[name]
	_poses[i]=Transform3D(Basis(_poses[i].basis.get_rotation_quaternion()*_xyz(x,y,z))*Basis.from_scale(_rest[i].basis.get_scale()),_rest[i].origin)
	_update_world()
func _arm(side:String,target:Vector3,tilt:float)->void:
	var upper:="upperarm_"+side;var fore:="forearm_"+side;var hand:="hand_"+side
	var r:Dictionary=_records[hand]
	var wrist:Vector3=target-Quaternion(Vector3.RIGHT,tilt)*(_records["socket_hand_"+side].p-r.p)
	var shoulder:=_position(upper);var direction:=wrist-shoulder;var distance:=direction.length();direction=direction.normalized()
	var l1:float=_records[upper].length;var l2:float=_records[fore].length;var stretch:=maxf(1,distance/(l1+l2-.015))
	var along:float=(l1*l1*stretch*stretch-l2*l2*stretch*stretch+distance*distance)/(2*maxf(.01,distance))
	var height:=sqrt(maxf(.005,l1*l1*stretch*stretch-along*along))
	var sign_side:= -1.0 if side=="l" else 1.0
	var crawl:=_prone*_gait*sin(_phase)*sign_side
	var pole:=Vector3(sign_side*(lerpf(1,.5,_prone)+crawl*.25),lerpf(-.55,-1,_prone),lerpf(-.08,-.6,_prone)+crawl*.25)
	pole=(pole-direction*pole.dot(direction)).normalized()
	var elbow:=shoulder+direction*along+pole*height
	_segment(upper,shoulder,elbow);_segment(fore,elbow,wrist);_set_world(hand,wrist,Quaternion(Vector3.RIGHT,tilt)*r.q)
func _kick(side:String,sign_side:float,lift:float,extend:float,blend:float,drop:bool=false,high:bool=false)->void:
	var thigh:="thigh_"+side;var shin:="shin_"+side;var foot:="foot_"+side
	var shoulder:=_position(thigh);var palm:=_position(foot);var gait_q:=_rotation(foot)
	var wrist:=Vector3(sign_side*.35,.27+lift*(1.05-extend*.95 if drop else .68+extend*.45),lift*(.20+extend*.92)).lerp(palm,1-blend)
	if high:
		var sweep:=.90*(1-2*extend)
		wrist=Vector3(sign_side*(.35+sin(sweep)*1.08*lift),.27+lift*1.65,cos(sweep)*1.08*lift).lerp(palm,1-blend)
	var leg_scale:=1+.20*lift*blend if high else 1.0
	if high:wrist=(wrist-shoulder)*leg_scale+shoulder
	var direction:=wrist-shoulder;var l1:float=_records[thigh].length*leg_scale;var l2:float=_records[shin].length*leg_scale
	var distance:=clampf(direction.length(),absf(l1-l2)+.000001,l1+l2);direction=direction.normalized();wrist=shoulder+direction*distance
	var along:float=(l1*l1-l2*l2+distance*distance)/(2*distance);var height:=sqrt(maxf(0,l1*l1-along*along))
	var pole:=Vector3(sign_side*.45 if high else 0,-.12 if high else 1,1 if high else .5)
	pole=(pole-direction*pole.dot(direction)).normalized()
	var elbow:=shoulder+direction*along+pole*height
	_segment(thigh,shoulder,elbow);_segment(shin,elbow,wrist)
	var kick_q:Quaternion=Quaternion(Vector3.RIGHT,-lift*(.15 if high else .20))*_records[foot].q
	_set_world(foot,wrist,gait_q.slerp(kick_q,blend))
func _lowest(rotation:Quaternion,offset:Vector3)->float:
	var frame:Transform3D=Transform3D(Basis(rotation),offset)*_skin._to_motion*_actor.affine_inverse()
	var low:=INF
	var matrices:Array[Transform3D]=[]
	for i in 28:
		var m:Transform3D=frame*_world[i];matrices.append(m)
		_skin_axes[i]=Vector3(m.basis.x.y,m.basis.y.y,m.basis.z.y);_skin_y[i]=m.origin.y
	# Exact affine minY over all actual rigid vertices, bulk native transforms.
	var swap:=Basis(Vector3(0,1,0),Vector3(1,0,0),Vector3(0,0,1))
	for bone:int in _skin._rigid:
		var transformed:PackedVector3Array=Transform3D(swap,Vector3.ZERO)*matrices[bone]*(_skin._rigid[bone] as PackedVector3Array)
		low=minf(low,(Array(transformed).min() as Vector3).x)
	var first:=0
	for end:int in _skin_ends:
		var y:=0.0
		for at in range(first,end):
			var bone:=_skin_bones[at]
			y+=_skin_axes[bone].dot(_skin_points[at])+_skin_y[bone]*_skin_weights[at]
		low=minf(low,y);first=end
	return low

func _binding_live()->bool:
	if _skin==null or not is_instance_valid(_skin._rig.get_ref()) or not is_instance_valid(_skin._motion.get_ref()):return false
	# queue_free retires an owner immediately, before the actual end-frame free.
	# Check ancestors too: a queued player/visual need not mark its rig queued.
	var node:Node=_skin._rig.get_ref()
	while node!=null:
		if node.is_queued_for_deletion():return false
		node=node.get_parent()
	return not (_skin._motion.get_ref() as Node).is_queued_for_deletion()

## base.visual_offset includes any folded source scaled_offset (default zero).
## scaled_offset is source scaled.position in metres, BEFORE visual rotation.
func sample(base:Dictionary,action:Variant=null,posture:Dictionary={},phase:float=0.0,gait:float=0.0,epoch:int=0)->Dictionary:
	if not _ready or _busy or not Thread.is_main_thread() or not _binding_live():return {"valid":false,"error":"binding"}
	if action==null:return base
	if not action is Dictionary:return {"valid":false,"error":"action"}
	if _truthy(action.get("armed")) or _truthy(action.get("weaponId")) and action.weaponId!="none":return base
	var type:String=str(action.get("type","none")) if _truthy(action.get("type")) else "none"
	if type=="backfist":type="heavy"
	if type!="none" and not DURATIONS.has(type):return {"valid":false,"error":"unknown_action"}
	var progress:=clampf(float(action.progress),0,1) if _finite(action.get("progress")) else 0.0
	var active:=type!="none" and progress<1
	var opener:=active and type in ["punch","kick"]
	var charge:=clampf(float(action.charge),0,1) if not opener and _finite(action.get("charge")) else 0.0
	var blocking:=_truthy(action.get("blocking"));var charging:=charge>0
	if not active and not blocking and not charging:return base
	if not _finite(posture.get("crouch",0.0)) or not _finite(posture.get("prone",0.0)):return {"valid":false,"error":"posture"}
	var crouch:float=posture.get("crouch",0.0);_prone=posture.get("prone",0.0)
	if crouch>.01 or _prone>.01:return base
	if not is_finite(phase) or not is_finite(gait) or not is_finite(crouch) or not is_finite(_prone) or epoch<0:return {"valid":false,"error":"inputs"}
	if not base.get("valid",false) or not base.get("poses") is Array or base.poses.size()!=28 or not base.get("visual_offset") is Vector3:return {"valid":false,"error":"base"}
	var rotation:Variant=base.get("visual_rotation",Quaternion.IDENTITY);var offset:Vector3=base.visual_offset;var scaled:Variant=base.get("scaled_offset",Vector3.ZERO)
	if not rotation is Quaternion or not rotation.is_finite() or absf(rotation.length_squared()-1)>.0001 or not offset.is_finite() or not scaled is Vector3 or not scaled.is_finite():return {"valid":false,"error":"visual"}
	_poses.clear()
	for pose:Variant in base.poses:
		if not pose is Transform3D or not pose.is_finite() or pose.basis.determinant()<=.0000001:return {"valid":false,"error":"bone"}
		_poses.append(pose)
	_busy=true;_phase=phase;_gait=gait;_update_world()
	var attack:="heavy" if type=="dropkick" else type;var double_kick:=type=="dropkick";var side:= -1.0 if _finite(action.get("side")) and float(action.side)<0 else 1.0
	var duration:float=DURATIONS.get(type,1.0);var time:=progress*duration;var age:=time;var p:=progress if active else 0.0
	var peak:=.10 if attack=="heavy" else .09
	var pulse:float=(sin(PI*p) if attack=="kick" else _smooth(age,0,peak)*(1-_smooth(age,peak,duration-.07))) if active else 0.0
	var blend:float=_smooth(age,0,.14 if attack=="kick" else .055)*(1-_smooth(age,duration-.14,duration)) if active else 0.0
	var drop:=active and double_kick;var heavy:=active and attack=="heavy" and not drop;var kick:=active and attack=="kick"
	var guard:=maxf(maxf(1.0 if blocking else 0.0,charge),maxf(blend,1-_smooth(p,.68,1) if heavy else 0.0))
	var wind:=1-_smooth(age,0,.08) if heavy else 0.0;var sweep:=_smooth(age,0,.16) if heavy else 0.0;var recover:=_smooth(age,.19,.50) if heavy else 0.0
	_rotate_add("chest",sin(time*2)*.012-(.25*sin(PI*p) if drop else 0)+( .06 if blocking else 0)+charge*.06+(wind*.06+pulse*.08 if heavy else 0),-side*charge*.20 if charging else side*(.20-1.05*sweep)*(1-recover) if heavy else 0,side*pulse*.22 if kick else 0)
	for s:String in ["l","r"]:
		var sign_side:= -1.0 if s=="l" else 1.0;var striking:=sign_side==side
		var px:=sign_side*(.46 if blocking else .38);var py:=3.72 if blocking else 3.38;var pz:=.80 if blocking else .5
		if charging and sign_side==-side:px=sign_side*(.38-charge*.98);py=3.38+charge*.22;pz=.5+charge*.25
		if active and not kick and not drop:
			px=sign_side*(.38-pulse*.10+(wind*.43 if heavy and striking else 0));py=3.38-pulse*.1-(wind*.13 if heavy and striking else 0);pz=.5+(pulse*(1.35 if heavy else 1.1)-(wind*.55 if heavy else 0) if striking else 0)
		if heavy and striking:px=sign_side*lerpf(-.60+1.80*sweep,.38,recover);py=lerpf(3.60,3.38,recover);pz=lerpf(.75+.80*sin(PI*sweep),.50,recover)
		var arm_blend:=guard*.16 if active and attack=="punch" and not striking and not blocking and not charging else guard
		var palm:=Vector3(lerpf(sign_side*1.1,px,arm_blend),lerpf(1.77,py,arm_blend)-crouch*.60,lerpf(sign_side*sin(phase)*gait*.43,pz,arm_blend))
		palm=palm.lerp(Vector3(sign_side*.78,.30+maxf(0,sign_side*sin(phase))*gait*.08,2.12+sign_side*sin(phase)*gait*.23),_prone)
		if heavy and striking:
			var shoulder:=_position("upperarm_"+s);var reach:float=_records["upperarm_"+s].length+_records["forearm_"+s].length
			var wrist_offset:Vector3=_records["socket_hand_"+s].p-_records["hand_"+s].p
			var target:=shoulder+(_rotation("chest")*Vector3(sign_side,.025,.20).normalized())*(reach*.98)+wrist_offset
			palm=palm.lerp(target,_smooth(age,.025,.12)*(1-_smooth(age,.30,.49)))
			palm=shoulder+(palm-wrist_offset-shoulder).limit_length(reach-.02)+wrist_offset
		_arm(s,palm,_prone*1.2)
		if heavy and striking:_set_world("hand_"+s,_position("hand_"+s),_xyz(0,-sign_side*PI/2*(1-recover),0)*_records["hand_"+s].q)
	if drop and blend>0:
		var lift:=_smooth(age,0,.10)*(1-_smooth(age,.58,1.20));var extend:=_smooth(age,.16,.25)*(1-_smooth(age,.36,.62))
		for s:String in ["l","r"]:_kick(s,-1 if s=="l" else 1,lift,extend*.95,blend,true)
	if kick and blend>0:_kick("l" if side<0 else "r",side,_smooth(age,0,.13)*(1-_smooth(age,.36,.58)),_smooth(age,.13,.32),blend,false,true)
	var body_q:=Quaternion.IDENTITY;var lift:=0.0;var travel:=0.0
	if active and attack=="kick":lift=1.95*_smooth(age,0,.18)*(1-_smooth(age,.34,.60))
	if heavy:body_q=Quaternion(Vector3.UP,-side*TAU*_smooth(age,0,.50))
	var pivot:Vector3=offset-rotation*scaled
	if drop:
		var tilt:float=(1.20*_smooth(age,.02,.22)+.16*_smooth(age,.38,.64))*(1-_smooth(age,.72,1.25))
		var rise:=.90*_smooth(age,0,.18)*(1-_smooth(age,.28,.65));var fall:=-.32*_smooth(age,.40,.70)*(1-_smooth(age,.78,1.25))
		var bank:=side*.65*_smooth(age,.03,.16)*(1-_smooth(age,.46,.72))
		body_q=Quaternion(Vector3.BACK,bank)*Quaternion(Vector3.RIGHT,-tilt)
		var hip:Vector3=(Vector3(0,1.46,0)+_source_offset)*_unit
		var displacement:=hip-body_q*hip;displacement.y+=(rise+fall)*_unit;pivot+=rotation*displacement
		travel=(2.8*_smooth(age,0,.34)+.35*_smooth(age,.34,.58))*_unit
	rotation=rotation*body_q;pivot.y+=lift*_unit;offset=pivot+rotation*scaled
	if drop:offset.y+=maxf(0,-_lowest(rotation,offset))
	var window:Array=[.16,.38] if double_kick else [.18,.34] if attack=="kick" else [.07,.36] if attack=="heavy" else [.035,.19]
	var result:=base.duplicate();result.poses=_poses.duplicate();result.visual_offset=offset;result.visual_rotation=rotation;result.authority_epoch=epoch
	result.melee={"type":type,"active":active,"side":side,"age":age,"duration":duration,"contactActive":active and age>=window[0] and age<=window[1],"contactSides":["l","r"] if double_kick else ["l" if side<0 else "r"],"contactKind":"foot" if double_kick or attack=="kick" else "fist","desiredForwardDistance":travel,"locksMovement":double_kick and active,"visualLift":lift*_unit}
	_busy=false;return result

func diagnostics()->Dictionary:return {"ready":_ready,"source_scale":_unit,"source_offset":_source_offset,"bones":_rest.size(),"skin":_skin.diagnostics() if _skin!=null else {}}
