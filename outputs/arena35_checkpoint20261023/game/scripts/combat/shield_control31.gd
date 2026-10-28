extends RefCounted
var pitch := 0.0
var _yaw := NAN
var _guarding := false
var _bounds := AABB()
var _identity := 0
var last: Dictionary = {}

func input(host: Node, event: InputEvent) -> void:
	if not event is InputEventMouseMotion or not host._shield_guard_active29() or not host._active(): return
	var motion := event as InputEventMouseMotion
	if absf(motion.relative.x)+absf(motion.relative.y)<1.5:return
	var player:Node3D=host.get("_player")
	if not is_finite(_yaw):_yaw=player._visual.global_rotation.y
	_yaw-=motion.relative.x*float(player.mouse_sensitivity)
	pitch=clampf(pitch-motion.relative.y*.004,-.70,.75)

func face(host:Node,delta:float)->void:
	var guarding:bool=host._shield_guard_active29()
	var player:Node3D=host.get("_player")
	if not is_instance_valid(player):return
	if guarding:
		if not is_finite(_yaw):_yaw=player._visual.global_rotation.y
		var difference:=wrapf(_yaw-player._visual.global_rotation.y,-PI,PI)
		var step:=clampf(difference,-6.0*delta,6.0*delta)
		player._visual.global_rotation.y+=step
		player._heading=player._visual.rotation.y-deg_to_rad(player.visual_yaw_degrees)
		player._camera_yaw+=step
		player._update_camera_rotation()
	else:
		_yaw=NAN
		pitch=move_toward(pitch,0.0,delta*2.0)
	_guarding=guarding

func _cache(shield:Node3D)->void:
	if _identity==shield.get_instance_id():return
	_identity=shield.get_instance_id()
	var first:=true
	for child:MeshInstance3D in shield.find_children("*","MeshInstance3D",true,false):
		if child.mesh==null:continue
		var transform:Transform3D=shield.global_transform.affine_inverse()*child.global_transform
		var bound:AABB=transform*child.mesh.get_aabb()
		_bounds=bound if first else _bounds.merge(bound)
		first=false

func clearance(host:Node,frame:Transform3D)->float:
	var rig:Skeleton3D=host.get("_rig")
	var centres:Array[Vector3]=[]
	var radii:Array[float]=[]
	for row:Array in [["head",.18],["chest",.215],["spine",.20]]:
		var index:=rig.find_bone(row[0])
		if index<0:continue
		centres.append(rig.global_transform*rig.get_bone_global_pose(index).origin)
		radii.append(float(row[1]))
	var inverse:=frame.affine_inverse()
	var gap:=INF
	for i in centres.size():
		var p:Vector3=inverse*centres[i]
		var q:=p.clamp(_bounds.position,_bounds.end)
		gap=minf(gap,(frame*q).distance_to(centres[i])-radii[i])
	return gap

func place(host:Node)->bool:
	if not host.get("_shield_worn"):return true
	var shield:Node3D=host.get("_shield")
	if not is_instance_valid(shield):
		shield=host._build_shield_model(host.get("_world"));host.set("_shield",shield)
	var rig:Skeleton3D=host.get("_rig")
	if not is_instance_valid(shield) or not is_instance_valid(rig):return false
	shield.visible=not bool(host.get("_shield_broken"))
	if not shield.visible:return true
	_cache(shield)
	var arm:Dictionary=host._arm_set(host._shield_side())
	if int(arm.hand)<0 or int(arm.upper)<0 or int(arm.fore)<0:shield.visible=false;return true
	var player:Node3D=host.get("_player")
	var body:Basis=player._visual.global_basis.orthonormalized()
	var shoulder:Vector3=rig.global_transform*(Transform3D(host._chain_global(arm.clav))*Transform3D(arm.rest_upper)).origin
	var originals:Array[Transform3D]=[]
	var bones:Array[int]=[int(arm.clav),int(arm.upper),int(arm.fore),int(arm.hand)]
	for bone in bones:originals.append(rig.get_bone_pose(bone))
	var raised:=clampf(float(host.get("_shield_raise")),0,1)
	var actual_pitch:=pitch*raised
	var grip_local:Vector3=host.SHIELD_GRIP_LOCAL29
	var accepted:=false
	var best_gap:=-INF
	for attempt in 6:
		for i in bones.size():rig.set_bone_pose(bones[i],originals[i])
		rig.force_update_all_bone_transforms()
		var angle:=actual_pitch if attempt<3 else actual_pitch*.35
		var frame_basis:Basis=body*Basis(Vector3.RIGHT,-angle)
		var front:Vector3=frame_basis.z.normalized()
		var up:Vector3=frame_basis.y.normalized()
		var right:Vector3=frame_basis.x.normalized()
		var distance:=lerpf(.29,.37,raised)+float(attempt%3)*.055
		var desired:Vector3=shoulder+body.z*distance+body.y*lerpf(-.32,-.08,raised)
		var grip_axis:Vector3=(rig.global_basis.inverse()*right).normalized()
		host._pose_arm_ik(arm.clav,arm.upper,arm.fore,arm.hand,arm.rest_upper,arm.rest_fore,arm.rest_hand,arm.offset,rig.global_transform.affine_inverse()*desired,grip_axis,1.0,true,arm.pole)
		rig.force_update_all_bone_transforms()
		var palm_world:=Basis(front,up,-right).orthonormalized()
		var fore_global:Transform3D=host._chain_global(arm.fore)
		var palm_rig:Basis=rig.global_basis.inverse()*palm_world
		rig.set_bone_pose(arm.hand,Transform3D((fore_global.basis.inverse()*palm_rig).orthonormalized(),arm.rest_hand.origin))
		rig.force_update_all_bone_transforms()
		var palm:Vector3=host._palm_position(host._shield_side())
		var candidate:=Transform3D(frame_basis,palm-frame_basis*grip_local)
		var gap:=clearance(host,candidate)
		best_gap=maxf(best_gap,gap)
		if gap>=.008:
			shield.global_transform=candidate
			last={"clearance_m":gap,"attempt":attempt,"pitch":angle,"grip_error":(shield.to_global(grip_local)-palm).length(),"guarding":host._shield_guard_active29()}
			accepted=true
			break
	if not accepted:
		# Keep the actual attached solution observable; never silently hide a failing shield.
		var palm:Vector3=host._palm_position(host._shield_side())
		shield.global_transform=Transform3D(body,palm-body*grip_local)
		last={"clearance_m":clearance(host,shield.global_transform),"unresolved":true,"best_gap":best_gap}
	return true
