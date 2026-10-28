extends RefCounted
## Ship ladder presentation. Returns local matrices to the player's existing writer.
## Rung targets use the visible ship_model ladder's exact base/top/twelve rungs.
var rest: Array[Transform3D] = []
var poses: Array[Transform3D] = []
var world: Array[Transform3D] = []
var names: Dictionary = {}
var parents: PackedInt32Array = []
var actor := Transform3D.IDENTITY
var records: Dictionary = {}
var last_pose: Dictionary = {}
var release_time := 0.0
func globals() -> void:
	for i: int in poses.size(): world[i] = (actor if parents[i]<0 else world[parents[i]]) * poses[i]
func set_world(name: String, at: Vector3, basis: Basis) -> void:
	var i: int = names[name]
	var parent: Transform3D = actor if parents[i]<0 else world[parents[i]]
	poses[i] = parent.affine_inverse() * Transform3D(basis,at)
	globals()
func segment(name: String, at: Vector3, end: Vector3) -> void:
	var r: Dictionary = records[name]
	var direction := (end-at).normalized()
	var q := Quaternion(r.direction,direction) * (r.basis as Basis).get_rotation_quaternion()
	set_world(name,at,Basis(q)*Basis.from_scale((r.basis as Basis).get_scale()))
func arm(side: String, target: Vector3, ship_right: Vector3) -> void:
	var upper := "upperarm_"+side
	var fore := "forearm_"+side
	var hand := "hand_"+side
	var shoulder: Vector3 = world[names[upper]].origin
	var offset: Vector3 = world[names["socket_hand_"+side]].origin-world[names[hand]].origin
	var wrist := target-offset
	var direction := wrist-shoulder
	var distance := maxf(.001,direction.length())
	direction /= distance
	var l1: float = records[upper].length
	var l2: float = records[fore].length
	distance = clampf(distance,absf(l1-l2)+.001,l1+l2-.001)
	wrist = shoulder + direction*distance
	var along := (l1*l1-l2*l2+distance*distance)/(2.0*distance)
	var height := sqrt(maxf(0.0,l1*l1-along*along))
	var pole := ship_right * (-1.0 if side=="l" else 1.0) + Vector3.DOWN*.6
	pole = (pole-direction*pole.dot(direction)).normalized()
	var elbow := shoulder+direction*along+pole*height
	segment(upper,shoulder,elbow)
	segment(fore,elbow,wrist)
	set_world(hand,wrist,records[hand].basis)
func sample(player: CharacterBody3D, state: Dictionary) -> Dictionary:
	var ship: Node3D = state.get("ship")
	var skeleton: Skeleton3D = player.get("_pose_skeleton")
	if not is_instance_valid(ship) or not is_instance_valid(skeleton): return {"valid":false}
	var local: Vector3 = state.local
	# Face the ladder while mouse look remains independent.
	var visual: Node3D = player.get("_visual")
	visual.global_rotation.y = ship.global_rotation.y + PI
	var locomotion: RefCounted = player.get("_locomotion")
	rest.assign(locomotion.get("_rest_poses"))
	poses = rest.duplicate()
	world.resize(poses.size())
	names.clear(); parents.clear()
	for i: int in poses.size():
		names[skeleton.get_bone_name(i)] = i
		parents.append(skeleton.get_bone_parent(i))
	var top_out := clampf((local.y-4.25)/.95,0.0,1.0)
	var crouch := sin(top_out*PI*.72)*.48
	var offset := Vector3(0,-crouch,0)
	var motion: Node3D = player.get("_pose_motion")
	actor = skeleton.global_transform
	actor.origin += motion.get_parent().global_basis * (offset-motion.position)
	for bone_name: String in ["chest","neck"]:
		var i: int = names[bone_name]
		var tr: Transform3D = rest[i]
		var lean := .32*sin(top_out*PI) if bone_name=="chest" else -.12*sin(top_out*PI)
		poses[i] = Transform3D(Basis(tr.basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,lean))*Basis.from_scale(tr.basis.get_scale()),tr.origin)
	globals()
	records.clear()
	for side: String in ["l","r"]:
		for pair: Array in [["upperarm_"+side,"forearm_"+side],["forearm_"+side,"hand_"+side]]:
			var a: Transform3D = world[names[pair[0]]]
			var b: Transform3D = world[names[pair[1]]]
			records[pair[0]]={"basis":a.basis,"length":a.origin.distance_to(b.origin),"direction":(b.origin-a.origin).normalized()}
		records["hand_"+side]={"basis":world[names["hand_"+side]].basis}
	var contacts: Dictionary = {}
	var base := Vector3(0,1.77,2.34)
	var top := Vector3(0,5.21,1.86)
	var spacing := (top.y-base.y)/12.0
	for side: String in ["l","r"]:
		var shoulder: Vector3 = ship.to_local(world[names["upperarm_"+side]].origin)
		var phase := (local.y-base.y)/spacing + (0.0 if side=="l" else .5)
		var rung := clampi(roundi((shoulder.y+.12-base.y)/spacing-.5),0,11)
		var t := (float(rung)+.5)/12.0
		var target := base.lerp(top,t)+Vector3(clampf(shoulder.x,-.30,.30),0,0)
		var contact_kind := "rung"
		if local.y>4.25:
			target = Vector3(clampf(shoulder.x,-.30,.30),5.22,1.77)
			contact_kind = "platform_lip"
		# Each hand releases on the opposite half cycle and reaches the next rung.
		var swing := sin(phase*PI)*.035
		target.y += maxf(0.0,swing) if contact_kind=="rung" else 0.0
		var target_world := ship.to_global(target)
		arm(side,target_world,ship.global_basis.x.normalized())
		var actual: Vector3 = world[names["socket_hand_"+side]].origin
		contacts[side]={"target":target_world,"actual":actual,"error_m":actual.distance_to(target_world),"rung":rung,"loaded":(swing<=.005 if contact_kind=="rung" else local.y<5.02),"kind":contact_kind}
	# Alternating feet clear the rungs. Bone translations and scale stay canonical.
	for side: String in ["l","r"]:
		var cycle := sin((local.y-base.y)/spacing*PI)*(1.0 if side=="l" else -1.0)
		for item: Array in [["thigh_",-.35+cycle*.22-crouch*1.3],["shin_",.62-cycle*.24+crouch*2.0],["foot_",-.14]]:
			var i: int = names[item[0]+side]
			var tr: Transform3D = rest[i]
			poses[i] = Transform3D(Basis(tr.basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,float(item[1])))*Basis.from_scale(tr.basis.get_scale()),tr.origin)
	last_pose = {"valid":true,"poses":poses.duplicate(),"visual_offset":offset,"visual_rotation":Quaternion.IDENTITY,"ship_climb":{"provider":"SHIP_CLIMB7","contacts":contacts,"frame":Engine.get_physics_frames(),"local":local,"top_out":top_out,"crouch_m":crouch,"weapon_policy":"temporary_stow"}}

	return last_pose

func start_release() -> void:
	release_time = .20

func blend_release(selected: Dictionary, delta: float) -> Dictionary:
	if release_time<=0.0 or last_pose.is_empty(): return selected
	release_time = maxf(0.0,release_time-maxf(0.0,delta))
	var weight := release_time/.20
	var output := selected.duplicate(true)
	var target: Array = output.poses
	for i: int in target.size(): target[i] = (target[i] as Transform3D).interpolate_with(last_pose.poses[i],weight)
	output.visual_offset = (output.visual_offset as Vector3).lerp(last_pose.visual_offset,weight)
	return output
