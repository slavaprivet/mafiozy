extends RefCounted
## Lab-only cutting load. Input, aim torque, grip and IK remain in the base sword.
## Tissue occupancy uses existing part boxes; bone radii match the visible anatomy.
const Anatomy = preload("res://scripts/combat/cut_anatomy28.gd")
const TISSUE_RATE := 4.0
const DEEP_RATE := 7.0
const BONE_RATE := 15.0
var contact: Dictionary = {}
var last: Dictionary = {}
var exiting: Dictionary = {}
var last_steer29: Dictionary = {}
var weak_corrections29 := 0

func clear(reason: String = "clear") -> void:
	# A ray starting inside a box still reports a hit while the blade is being
	# withdrawn. Keep that original contact disarmed until a genuine new entry.
	exiting = contact.duplicate() if reason=="withdrawal" else {}
	contact.clear()
	last = {"active":false,"reason":reason}

func resolved(_host: Node, _success: bool) -> void:
	# The already spent angular momentum is not restored after a cut or cancel.
	var withdrawal := exiting.duplicate()
	clear("resolved")
	exiting = withdrawal

func _armed(host: Node) -> bool:
	return bool(host.get("_held")) or (host.has_method("_clay_passive_contact28") and bool(host.call("_clay_passive_contact28")))

func _identity(host: Node) -> bool:
	return not contact.is_empty() and int(host.get("lab_resets"))==int(contact.generation) and str(host.get("_weapon_id"))==str(contact.weapon) and _armed(host)

func _shape(collider: Node) -> CollisionShape3D:
	for child in collider.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape is BoxShape3D:return child
	return null

# Exact intersection interval with the existing oriented part box.
func _interval(shape: CollisionShape3D, a: Vector3, b: Vector3) -> Vector2:
	var x:=shape.to_local(a)
	var d:=shape.to_local(b)-x
	var half: Vector3=shape.shape.size*0.5
	var low:=0.0
	var high:=1.0
	for axis in 3:
		if absf(d[axis])<1.0e-9:
			if absf(x[axis])>half[axis]:return Vector2(-1,-1)
		else:
			var p:=(-half[axis]-x[axis])/d[axis]
			var q:=(half[axis]-x[axis])/d[axis]
			low=maxf(low,minf(p,q));high=minf(high,maxf(p,q))
			if high<low:return Vector2(-1,-1)
	return Vector2(low,high)

func _depth(shape: CollisionShape3D, point: Vector3) -> float:
	var half: Vector3=shape.shape.size*0.5
	var p:=shape.to_local(point).abs()
	return clampf(minf((half.x-p.x)/maxf(half.x,0.001),minf((half.y-p.y)/maxf(half.y,0.001),(half.z-p.z)/maxf(half.z,0.001))),0.0,1.0)

func _bone(host: Node, point: Vector3) -> float:
	var rig: Skeleton3D=host.get("_npc_rig")
	if not is_instance_valid(rig):return 0.0
	var frame:={"origin":point,"u":Vector3.RIGHT,"v":Vector3.UP,"n":Vector3.BACK}
	var anatomy:=Anatomy._anatomy(rig,frame)
	var near:=0.0
	for i in anatomy.starts.size():
		var row: Vector4=anatomy.starts[i]
		var end: Vector4=anatomy.ends[i]
		var a:=Vector3(row.x,row.y,row.z)
		var b:=Vector3(end.x,end.y,end.z)
		var ab:=b-a
		var q:=a+ab*clampf(-a.dot(ab)/maxf(ab.length_squared(),1.0e-9),0.0,1.0)
		near=maxf(near,1.0-smoothstep(row.w,row.w+0.012,q.length()))
	if anatomy.skull_enabled:
		var offset: Vector3=-Vector3(anatomy.skull_center)
		var radii: Vector3=anatomy.skull_radii
		var ellipsoid:=Vector3(offset.dot(anatomy.skull_axis_x)/radii.x,offset.dot(anatomy.skull_axis_y)/radii.y,offset.dot(anatomy.skull_axis_z)/radii.z)
		# Only the shell is hard; the skull interior is not a solid bone sphere.
		near=maxf(near,1.0-smoothstep(0.035,0.12,absf(ellipsoid.length()-1.0)))
	return near

func _load(host: Node, shape: CollisionShape3D, point: Vector3, speed: float) -> Dictionary:
	var depth:=_depth(shape,point)
	var bone:=_bone(host,point)
	var rate:=TISSUE_RATE+DEEP_RATE*depth+BONE_RATE*bone+minf(speed,12.0)*0.25
	# Sword-only compliant contact: fast cuts retain their actual momentum.
	# Other weapons keep their established material response.
	if str(host.get("_weapon_id"))=="sword":
		rate=(1.5+2.0*depth+4.0*bone)*sword_load_factor29(speed)
		if bool(contact.get("soft_tissue35",false)):
			rate=(.65+.8*depth+2.0*bone)*(1.0-smoothstep(.6,2.6,maxf(0.0,speed)))
	return {"depth":depth,"bone":bone,"rate":rate}

static func sword_load_factor29(speed: float) -> float:
	return 1.0-smoothstep(1.0,3.2,maxf(0.0,speed))

func _damp(omega: Vector3, direction: Vector3, incoming: Vector3, rate: float, duration: float) -> Vector3:
	# Only the component advancing the sampled blade into the contacted tissue.
	var gradient:=direction.cross(incoming)
	if gradient.length_squared()<1.0e-8:return omega
	gradient=gradient.normalized()
	var advancing:=omega.dot(gradient)
	if advancing<=0.0:return omega
	return omega-gradient*advancing*(1.0-exp(-rate*maxf(duration,0.0)))

func observe(host: Node, hit: Dictionary, points: PackedVector3Array, _now: int) -> void:
	var collider: Node=hit.get("collider")
	var sample:=int(hit.get("_index",-1))
	var previous: PackedVector3Array=host.get("_prev_points")
	var velocity: Vector3=hit.get("_velocity",Vector3.ZERO)
	if not is_instance_valid(collider) or sample<0 or sample>=points.size() or sample>=previous.size() or velocity.length_squared()<1.0e-8:return
	var shape:=_shape(collider)
	if shape==null or not _armed(host):return
	var span:=_interval(shape,previous[sample],points[sample])
	if span.x<0:return
	if not exiting.is_empty():
		var same_exit: bool=exiting.collider.get_ref()==collider and int(exiting.generation)==int(host.get("lab_resets")) and str(exiting.weapon)==str(host.get("_weapon_id"))
		var half: Vector3=shape.shape.size*0.5
		var from_local:=shape.to_local(previous[sample]).abs()
		if same_exit and from_local.x<=half.x and from_local.y<=half.y and from_local.z<=half.z:return
		exiting.clear()
	if _identity(host) and contact.collider.get_ref()==collider and velocity.dot(Vector3(contact.incoming))<=0.0:
		clear("withdrawal")
		return
	var was_same: bool=_identity(host) and contact.collider.get_ref()==collider and velocity.dot(Vector3(contact.incoming))>0.0
	var incoming:=Vector3(contact.incoming) if was_same else velocity.normalized()
	var direction: Vector3=host.get("_dir")
	var lever:=maxf(0.06,(points[sample]-Vector3(host.get("_sword_origin"))).dot(direction))
	contact={"collider":weakref(collider),"shape":weakref(shape),"incoming":incoming,"lever":lever,"generation":host.get("lab_resets"),"weapon":host.get("_weapon_id"),"speed":velocity.length()}
	contact["soft_tissue35"]=bool(hit.get("_soft_tissue35",false))
	var position:=previous[sample].lerp(points[sample],(span.x+span.y)*0.5)
	last=_load(host,shape,position,velocity.length())
	last["active"]=true
	if not was_same:
		var duration:=previous[sample].distance_to(points[sample])/velocity.length()*(span.y-span.x)
		host.set("_omega",_damp(host.get("_omega"),direction,incoming,last.rate,duration))

func steer(host: Node, delta: float, prior_dir: Vector3, _prior_omega: Vector3) -> void:
	if contact.is_empty():return
	if not _identity(host):clear("identity");return
	var collider: CollisionObject3D=contact.collider.get_ref()
	var shape: CollisionShape3D=contact.shape.get_ref()
	if not is_instance_valid(collider) or not is_instance_valid(shape) or shape.disabled or collider.collision_layer==0:clear("removed");return
	var direction: Vector3=host.get("_dir")
	var origin: Vector3=host.get("_sword_origin")
	var a:=origin+prior_dir*float(contact.lever)
	var b:=origin+direction*float(contact.lever)
	var movement:=b-a
	var advance:=movement.dot(Vector3(contact.incoming))
	if advance < -1.0e-8:clear("withdrawal");return
	if advance <= 0.0:return
	var span:=_interval(shape,a,b)
	if span.x<0:clear("exit");return
	var speed:=movement.length()/maxf(delta,0.001)
	if str(host.get("_weapon_id"))=="sword":speed=maxf(speed,float(contact.get("speed",0.0)))
	var info:=_load(host,shape,a.lerp(b,(span.x+span.y)*0.5),speed)
	var omega: Vector3=host.get("_omega")
	var resisted:=_damp(omega,direction,contact.incoming,info.rate,delta*(span.y-span.x))
	if resisted!=omega:
		host.set("_omega",resisted)
		# Base steer just integrated this omega. Replace only that integration;
		# the input target, torque, constraints and subsequent IK stay unchanged.
		if omega.length()>1.0e-6 and resisted.length()>1.0e-6:
			var unrotated:=Quaternion(omega.normalized(),-omega.length()*delta)*direction
			host.set("_dir",(Quaternion(resisted.normalized(),resisted.length()*delta)*unrotated).normalized())
	last=info
	last["active"]=true
	last["omega_before"]=omega.length()
	last["omega_after"]=resisted.length()
	last["direction_before"]=direction
	last["direction_after"]=host.get("_dir")
	last["angular_correction"]=direction.angle_to(Vector3(host.get("_dir")))
	last["physics_frame"]=Engine.get_physics_frames()
	last_steer29=last.duplicate()
	if float(last.angular_correction)>0.000001:weak_corrections29+=1
