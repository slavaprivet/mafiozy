extends RefCounted
## Living on-foot injuries only. Native body sweeps own every hop; no transform
## animation moves the CharacterBody through the floor or walls.

const ARM_SPEED := 0.88
const LEAN_ANGLE := 0.13962634 # Eight degrees toward the missing arm.
const HOP_SPEED := 1.55
const JUMP_SPEED := 2.6
const LANDING_TIME := 0.12

var legs := Vector2i.ZERO
var arms := Vector2i.ZERO
var active := false
var hop_count := 0
var jump_count := 0
var _landing := 0.0
var _launched := false
var _jump_requested := false
var _capsule: CollisionShape3D
var _upper: CollisionShape3D
var _original_transform := Transform3D.IDENTITY
var _original_height := 1.9
var _original_radius := 0.3
var _split := false
var _modified := false
var _player_ref: WeakRef
var _original_snap := 0.25
var _support_offset := 0.0
var _support_cut := -1
var _scan_cut := -1
var _collect: Array = []
var _collect_row := 0
var _collect_surface := 0
var _scan_bones: Array[Transform3D] = []
var _scan_bone_names := {}
var _scan: Array = []
var _scan_row := 0
var _scan_vertex := 0
var _scan_min := INF
var _scan_frame := -1
var _scan_vertices := 0
var _scan_max_usec := 0
var _scan_total_usec := 0
var _rest: Array[Transform3D] = []
var _globals: Array[Transform3D] = []
var _parents := PackedInt32Array()
var _bones := {}
var _rig_id := 0
var last := {}

func refresh(player: CharacterBody3D) -> void:
	var host: Node = player._sword_host
	var lost: Dictionary = host.get("_player_severed") if is_instance_valid(host) else {}
	if lost == null: lost = {}
	legs = Vector2i(int(_lost(lost,"thigh","l") or _lost(lost,"shin","l") or _lost(lost,"foot","l")),int(_lost(lost,"thigh","r") or _lost(lost,"shin","r") or _lost(lost,"foot","r")))
	arms = Vector2i(int(_lost(lost,"upperarm","l") or _lost(lost,"forearm","l") or _lost(lost,"hand","l")),int(_lost(lost,"upperarm","r") or _lost(lost,"forearm","r") or _lost(lost,"hand","r")))
	var dead: bool = is_instance_valid(host) and is_instance_valid(host._world) and bool(host._world.get("preview_dead"))
	active = not dead and player._pose_authority==&"on_foot" and not player._mount_mode and not player._vehicle_hold and not player._swimming
	if not active or legs.x+legs.y!=1:
		_landing=0.0;_launched=false;_jump_requested=false
	if legs.x+legs.y!=2:
		_support_offset=0.0;_support_cut=-1;_scan_cut=-1;_scan.clear();_collect.clear();_scan_bones.clear();_scan_bone_names.clear()
	if not active or (arms.x==arms.y and legs.x+legs.y!=2): _restore_collision()

func _lost(lost: Dictionary, part: String, side: String) -> bool:
	return lost.has(part+"_"+side)

func speed_scale() -> float:
	return ARM_SPEED if active and arms.x+arms.y>0 else 1.0

func request_jump(player: CharacterBody3D) -> bool:
	refresh(player)
	if not active or legs.x+legs.y!=1 or not player.is_on_floor() or _launched or _jump_requested:
		return false
	_jump_requested=true
	return true

func drive(player: CharacterBody3D, direction: Vector3, delta: float) -> float:
	if not active: return 1.0
	if legs.x+legs.y==2:
		player.velocity.x=0.0;player.velocity.z=0.0
		if _support_offset>0.0 and player.is_on_floor():
			# A stationary shortened body still needs a native downward support
			# sweep. Grounded velocity is cleared by collision; airborne gravity
			# remains the existing controller's single acceleration step.
			player.velocity.y-=player._gravity*maxf(0.0,delta)
		return 0.0
	if legs.x+legs.y!=1: return 1.0
	if not player.is_on_floor():
		_landing=0.0
		_launched=false
		return 1.0
	_landing+=maxf(0.0,delta)
	if not _launched and (_jump_requested or (direction.length_squared()>.001 and _landing>=LANDING_TIME)):
		player.velocity.y=JUMP_SPEED if _jump_requested else HOP_SPEED
		hop_count+=1
		if _jump_requested: jump_count+=1
		_jump_requested=false;_launched=true;_landing=0.0
		return 1.0
	# A planted support foot is a brief stance, not an ordinary two-foot slide.
	return 0.12

func _bind(player: CharacterBody3D) -> bool:
	var rig: Skeleton3D = player._pose_skeleton
	if not is_instance_valid(rig) or player._locomotion==null: return false
	if _rig_id==rig.get_instance_id(): return true
	_rig_id=rig.get_instance_id()
	_rest.assign(player._locomotion._rest_poses)
	_globals.resize(_rest.size())
	_parents.clear();_bones.clear()
	for i in _rest.size():
		_parents.append(rig.get_bone_parent(i))
		_bones[String(rig.get_bone_name(i))]=i
		_globals[i]=_rest[i] if _parents[i]<0 else _globals[_parents[i]]*_rest[i]
	return true

func decorate(player: CharacterBody3D, selected: Dictionary) -> Dictionary:
	if not active or (legs==Vector2i.ZERO and arms==Vector2i.ZERO) or not selected.get("valid",false) or not _bind(player): return selected
	var poses: Array[Transform3D] = []
	poses.assign(selected.poses)
	if legs.x+legs.y>0:
		# Retire the alternating gait. Only the retained leg compresses in flight.
		for name in ["thigh_l","shin_l","foot_l","thigh_r","shin_r","foot_r"]:
			var index: int = _bones.get(name,-1)
			if index>=0: poses[index]=_rest[index]
		if legs.x+legs.y==1:
			var suffix := "r" if legs.x==1 else "l"
			var airborne: bool = not player.is_on_floor() or player.velocity.y>.1
			var fold := clampf(absf(player.velocity.y)/JUMP_SPEED,0.0,1.0) if airborne else 0.0
			_rotate(poses,"thigh_"+suffix,Vector3.RIGHT,-.16*fold)
			_rotate(poses,"shin_"+suffix,Vector3.RIGHT,.42*fold)
			_rotate(poses,"foot_"+suffix,Vector3.RIGHT,-.20*fold)
			var gait = player._locomotion
			var minimum := INF
			var side := 1 if legs.x==1 else 0
			var foot: int = gait._foot_bones[side]
			_build_globals(poses)
			var frame: Transform3D = gait._skeleton_in_parent*_globals[foot]
			for point: Vector3 in gait._foot_points[side]: minimum=minf(minimum,(frame*point).y)
			var offset: Vector3 = gait._motion_rest
			# In flight retain the natural knee lift. Ground stance uses the actual
			# remaining boot hull, never the removed boot's support minimum.
			if not airborne and is_finite(minimum): offset.y-=minimum
			selected.visual_offset=offset
	if arms.x!=arms.y:
		var missing := "upperarm_l" if arms.x==1 else "upperarm_r"
		_build_globals(_rest)
		var arm: int = _bones.get(missing,-1)
		var chest: int = _bones.get("chest",-1)
		if arm>=0 and chest>=0:
			var side: Vector3 = _globals[arm].origin-_globals[chest].origin
			side.y=0.0
			var axis: Vector3 = Vector3.UP.cross(side.normalized())
			var spine: Array[int] = []
			for name in ["spine_01","spine_02","spine01","spine02","chest"]:
				if _bones.has(name): spine.append(_bones[name])
			for bone in spine:
				var parent: int = _parents[bone]
				var local_axis: Vector3 = _globals[parent].basis.inverse()*axis if parent>=0 else axis
				poses[bone].basis=Basis(local_axis.normalized(),LEAN_ANGLE/maxi(1,spine.size()))*poses[bone].basis
	selected.poses=poses
	selected["injury32"]={"legs":legs,"arms":arms,"hops":hop_count}
	return selected

func _rotate(poses: Array[Transform3D], name: String, axis: Vector3, angle: float) -> void:
	var bone: int = _bones.get(name,-1)
	if bone>=0: poses[bone].basis=_rest[bone].basis*Basis(axis,angle)

func _build_globals(poses: Array[Transform3D]) -> void:
	for i in poses.size(): _globals[i]=poses[i] if _parents[i]<0 else _globals[_parents[i]]*poses[i]

func sync_collision(player: CharacterBody3D) -> void:
	if not active or (arms.x==arms.y and legs.x+legs.y!=2):
		_restore_collision()
		return
	if not _bind(player): return
	if not is_instance_valid(_capsule):
		_capsule=player.get_node_or_null("PlayerCapsule")
		if not is_instance_valid(_capsule) or not _capsule.shape is CapsuleShape3D: return
		_original_transform=_capsule.transform
		_original_height=_capsule.shape.height
		_original_radius=_capsule.shape.radius
		_original_snap=player.floor_snap_length
		_player_ref=weakref(player)
	if legs.x+legs.y==2: _advance_support(player)
	if arms.x==arms.y:
		if is_instance_valid(_upper): _upper.disabled=true
		_split=false
		if _support_offset>0.0:
			_capsule.shape.height=maxf(_original_radius*2,_original_height-_support_offset)
			_capsule.position=Vector3(0,_support_offset+_capsule.shape.height*.5,0)
			_modified=true
			player.floor_snap_length=0.0
		last={"active":true,"legs":legs,"arms":arms,"support_offset":_support_offset,"support_cut":_support_cut,"scan_vertices":_scan_vertices,"scan_max_usec":_scan_max_usec,"scan_total_usec":_scan_total_usec}
		return
	if not is_instance_valid(_upper):
		_upper=CollisionShape3D.new()
		_upper.name="InjuryTorsoCapsule32"
		_upper.disabled=true
		_upper.shape=CapsuleShape3D.new()
		_upper.shape.radius=_original_radius
		player.add_child(_upper)
	var rig: Skeleton3D = player._pose_skeleton
	# This imported rig's named pelvis is at its root near the feet. Its actual
	# hip/waist articulation is spine_01; using pelvis enclosed empty air down
	# through the floor. Do not substitute the root as an anatomical anchor.
	var pelvis: int = _bones.get("spine_01",_bones.get("spine01",-1))
	var head: int = _bones.get("head",-1)
	if pelvis<0 or head<0: return
	rig.force_update_all_bone_transforms()
	var low: Vector3 = player.to_local(rig.global_transform*rig.get_bone_global_pose(pelvis).origin)
	var high: Vector3 = player.to_local(rig.global_transform*rig.get_bone_global_pose(head).origin)+Vector3.UP*.10
	# The torso sphere may not retain support below the actual remaining stump.
	low.y=maxf(low.y,_support_offset+_original_radius)
	var length := low.distance_to(high)
	if not low.is_finite() or not high.is_finite() or length<.2 or length>1.7: return
	# Lower support retains the original foot plane. The upper capsule encloses
	# the posed pelvis-to-head chain; their radii overlap at the pelvis.
	var lower_height := clampf(low.y+.15-_support_offset,_original_radius*2,_original_height)
	_capsule.shape.height=lower_height
	_capsule.position=Vector3(0,_support_offset+lower_height*.5,0)
	_upper.disabled=false
	_upper.shape.height=maxf(_original_radius*2,length+_original_radius*2)
	_upper.transform=Transform3D(Basis(Quaternion(Vector3.UP,(high-low).normalized())),(low+high)*.5)
	_split=true
	_modified=true
	if _support_offset>0.0: player.floor_snap_length=0.0
	last={"active":true,"legs":legs,"arms":arms,"hop_count":hop_count,"jump_count":jump_count,"lower_height":lower_height,"upper_transform":_upper.transform,"upper_height":_upper.shape.height,"support_overlap":_support_offset+lower_height-(low.y-_original_radius),"support_offset":_support_offset,"scan_max_usec":_scan_max_usec}

func _advance_support(player: CharacterBody3D) -> void:
	var host: Node=player._sword_host
	var cut: int=host.get("_player_cut_total50")
	if cut==_support_cut or _scan_frame==Engine.get_physics_frames():return
	_scan_frame=Engine.get_physics_frames()
	var started:=Time.get_ticks_usec()
	if cut!=_scan_cut:
		_scan.clear();_scan_row=0;_scan_vertex=0;_scan_min=INF;_scan_vertices=0
		_collect.clear();_collect_row=0;_collect_surface=0
		_scan_bones.clear();_scan_bone_names.clear()
		_scan_cut=cut
		var rig: Skeleton3D=player._pose_skeleton
		rig.force_update_all_bone_transforms()
		# Freeze one coherent pose. Surface readbacks happen later, but every
		# surface uses these same captured bones and mesh/actor transforms.
		for bone in rig.get_bone_count():
			_scan_bones.append(rig.global_transform*rig.get_bone_global_pose(bone))
			_scan_bone_names[rig.get_bone_name(bone)]=bone
		var actor_inverse:=player.global_transform.affine_inverse()
		for mesh_node: MeshInstance3D in host._npc_skinned_meshes(rig):
			if not mesh_node.is_visible_in_tree() or mesh_node.mesh==null:continue
			_collect.append({"node":weakref(mesh_node),"mesh_id":mesh_node.mesh.get_instance_id(),"skin":mesh_node.skin,"mesh_world":mesh_node.global_transform,"frame":actor_inverse*mesh_node.global_transform,"binds":[],"bound":false})
	# Validate the whole pending snapshot, including surfaces not read yet.
	for row: Dictionary in _collect:
		var node: MeshInstance3D=row.node.get_ref()
		if not is_instance_valid(node) or not node.is_visible_in_tree() or node.mesh==null or node.mesh.get_instance_id()!=int(row.mesh_id) or node.skin!=row.skin:
			_scan_cut=-1;_scan.clear();_collect.clear();_scan_bones.clear();_scan_bone_names.clear();return
	if _collect_row<_collect.size():
		var row: Dictionary=_collect[_collect_row]
		var node: MeshInstance3D=row.node.get_ref()
		if not row.bound:
			var binds: Array[Transform3D]=[]
			var skin: Skin=row.skin
			if skin!=null:
				var to_mesh: Transform3D=row.mesh_world.affine_inverse()
				for bind in skin.get_bind_count():
					var name:=skin.get_bind_name(bind)
					var bone: int=_scan_bone_names.get(name,-1) if name!=&"" else skin.get_bind_bone(bind)
					if bone<0 or bone>=_scan_bones.size():binds.clear();break
					binds.append(to_mesh*_scan_bones[bone]*skin.get_bind_pose(bind))
			row.binds=binds;row.bound=true
		if _collect_surface<node.mesh.get_surface_count():
			# One surface readback per physics step. Never collect the complete
			# wardrobe's GPU arrays in the same first-injury frame.
			var arrays: Array=node.mesh.surface_get_arrays(_collect_surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			if not points.is_empty():
				_scan.append({"points":points,"joints":arrays[Mesh.ARRAY_BONES],"weights":arrays[Mesh.ARRAY_WEIGHTS],"binds":row.binds,"frame":row.frame})
			_collect_surface+=1
		if _collect_surface>=node.mesh.get_surface_count():_collect_row+=1;_collect_surface=0
		_record_scan_time(started)
		return
	var budget:=256
	while budget>0 and _scan_row<_scan.size():
		var row: Dictionary=_scan[_scan_row]
		var points: PackedVector3Array=row.points
		var joints: Variant=row.joints
		var weights: Variant=row.weights
		var stride: int=joints.size()/points.size() if joints!=null else 0
		while budget>0 and _scan_vertex<points.size():
			var point:=points[_scan_vertex]
			if stride in [4,8] and weights!=null and weights.size()==joints.size():
				var posed:=Vector3.ZERO
				var total:=0.0
				for influence in stride:
					var at:=_scan_vertex*stride+influence
					var weight: float=weights[at]
					var bind: int=joints[at]
					if weight>0 and bind>=0 and bind<row.binds.size():
						posed+=(row.binds[bind]*point)*weight;total+=weight
				if total>.000001:point=posed
			var actor_point: Vector3=row.frame*point
			if actor_point.is_finite():_scan_min=minf(_scan_min,actor_point.y)
			_scan_vertex+=1;_scan_vertices+=1;budget-=1
		if _scan_vertex>=points.size():_scan_row+=1;_scan_vertex=0
	if _scan_row>=_scan.size() and not _scan.is_empty() and is_finite(_scan_min):
		_support_offset=clampf(_scan_min,0.0,_original_height-_original_radius*2)
		_support_cut=cut
		_scan.clear();_collect.clear();_scan_bones.clear();_scan_bone_names.clear()
	_record_scan_time(started)

func _record_scan_time(started: int) -> void:
	var elapsed:=Time.get_ticks_usec()-started
	_scan_max_usec=maxi(_scan_max_usec,elapsed);_scan_total_usec+=elapsed

func _restore_collision() -> void:
	if not _modified: return
	if is_instance_valid(_capsule):
		_capsule.transform=_original_transform
		_capsule.shape.height=_original_height
		_capsule.shape.radius=_original_radius
	if is_instance_valid(_upper): _upper.disabled=true
	if _player_ref!=null and is_instance_valid(_player_ref.get_ref()):_player_ref.get_ref().floor_snap_length=_original_snap
	_split=false
	_modified=false

func snapshot() -> Dictionary:
	return {"active":active,"legs":legs,"arms":arms,"hop_count":hop_count,"jump_count":jump_count,"split_collision":_split,"last":last.duplicate()}
