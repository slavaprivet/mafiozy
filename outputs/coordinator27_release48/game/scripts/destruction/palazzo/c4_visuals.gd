extends RefCounted
## Local C4 presentation only. No collision, placement authority or player edits.
## Call advance from the equipment physics tick AFTER the native player pose.
## Consume pose_applied/held_frame instead of sampling the unmodified socket in
## _process. SkeletonModifier3D automatically restores original bone poses after
## applying its temporary result to the skin. Never clears another owner's IK.
signal pose_applied(frame: Transform3D)

const BONE_NAMES := ["chest","upperarm_r","forearm_r","hand_r","socket_hand_r","upperarm_l","forearm_l","hand_l","socket_hand_l"]
const COLORS := {"olive":"545b41","edge":"343c30","strap":"242821","paper":"d3c5a1","ink":"292c25","metal":"747b78","red":"962d24","wire":"c1a34b","screen":"6a9276","led":"ec633f"}
static var _model_cache: Dictionary={}
static var _materials: Dictionary={}
var _player: WeakRef
var _rig: Skeleton3D
var _modifier: PlacementModifier
var _identity: Variant
var _life: Variant
var _version: int=-1
var _ids: Dictionary={}
var _parents:=PackedInt32Array()
var _local: Array[Transform3D]=[]
var _world: Array[Transform3D]=[]
var _rest_hands: Array[Quaternion]=[]
var _ready:=false
var _disposed:=false
var _holding:=false
var _progress:=0.0
var _target:=Vector3.ZERO
var _normal:=Vector3.BACK
var _request_frame: int=-10
var _request_epoch: int=-1
var _modified_revision: int=-1
var _display_valid:=false
var _display_frame:=Transform3D.IDENTITY
var _tool_basis:=Basis.IDENTITY
var _right_error_m:=INF
var _left_error_m:=INF
var _right_goal:=Vector3.ZERO
var _left_goal:=Vector3.ZERO
var _samples:=0
var _max_usec:=0

class PlacementModifier extends SkeletonModifier3D:
	var presentation: WeakRef
	func _process_modification_with_delta(delta: float) -> void:
		var host: Variant=presentation.get_ref() if presentation!=null else null
		if is_instance_valid(host): host._modify(delta)

func configure(player: CharacterBody3D) -> Dictionary:
	if _ready or _disposed or not Thread.is_main_thread() or not is_instance_valid(player) or not player.is_inside_tree(): return {"ok":false,"reason":"player_lifetime"}
	var rig: Variant=player.get("_pose_skeleton")
	if not rig is Skeleton3D or not player.is_ancestor_of(rig) or not player.has_meta("actor_id") or not player.has_meta("life_generation"): return {"ok":false,"reason":"native_skeleton_required"}
	if rig.get_bone_count()!=28: return {"ok":false,"reason":"native_28_bone_rig_required"}
	for bone_name: String in BONE_NAMES:
		var index: int=rig.find_bone(bone_name)
		if index<0: return {"ok":false,"reason":"missing_bone:"+bone_name}
		_ids[bone_name]=index
	for side: String in ["r","l"]:
		if rig.get_bone_parent(_ids["forearm_"+side])!=_ids["upperarm_"+side] or rig.get_bone_parent(_ids["hand_"+side])!=_ids["forearm_"+side] or rig.get_bone_parent(_ids["socket_hand_"+side])!=_ids["hand_"+side]: return {"ok":false,"reason":"native_arm_chain_required"}
	for child: Node in rig.get_children():
		if child is PlacementModifier: return {"ok":false,"reason":"c4_modifier_already_bound"}
	_player=weakref(player); _rig=rig; _identity=player.get_meta("actor_id"); _life=player.get_meta("life_generation"); _version=rig.get_version()
	_parents.resize(28); _local.resize(28); _world.resize(28)
	for index: int in 28:
		_parents[index]=rig.get_bone_parent(index)
		if _parents[index]>=index: return {"ok":false,"reason":"native_bone_order_required"}
	var visual: Node3D=player.get("_visual")
	if not is_instance_valid(visual): return {"ok":false,"reason":"native_visual_required"}
	for side: String in ["r","l"]:
		var rest: Basis=visual.global_basis.inverse()*rig.global_basis*rig.get_bone_global_rest(_ids["hand_"+side]).basis
		_rest_hands.append(rest.orthonormalized().get_rotation_quaternion())
	_modifier=PlacementModifier.new(); _modifier.name="C4TemporaryPlacementPose"
	_modifier.presentation=weakref(self); _modifier.active=false; _modifier.influence=1.0
	rig.add_child(_modifier)
	rig.skeleton_updated.connect(_capture_displayed)
	_ready=true
	return {"ok":true,"post_pose":"SkeletonModifier3D","native_bone_writer_unchanged":true,"no_bone_stretch":true,"holding_seconds":3.0}

func _current() -> bool:
	var player: Variant=_player.get_ref() if _player!=null else null
	return _ready and not _disposed and is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion() and is_instance_valid(_rig) and not _rig.is_queued_for_deletion() and player.get("_pose_skeleton")==_rig and player.is_ancestor_of(_rig) and _rig.get_version()==_version and player.get_meta("actor_id",null)==_identity and player.get_meta("life_generation",null)==_life and is_instance_valid(_modifier) and _modifier.get_parent()==_rig

func _pose_allowed() -> bool:
	if not _current(): return false
	var player: CharacterBody3D=_player.get_ref()
	var weapons: Variant=player.get("_weapon_host")
	# Legacy affine melee/weapon overrides have their own native authority. Do
	# not clear or replace them to make this cosmetic installation pose work.
	return player.get("_pose_authority")==&"on_foot" and not player.get("_pose_affine_active") and is_instance_valid(weapons) and weapons.fire_state.get("weaponId","none")=="none"

func advance(dt: float,progress: float,targetpoint: Vector3,normal: Vector3,holding: bool) -> Dictionary:
	if not _current():
		_stop(); return {"ok":false,"reason":"owner_ended"}
	if not holding:
		_stop(); return {"ok":true,"holding":false}
	if not is_finite(dt) or dt<0 or dt>.25 or not is_finite(progress) or progress<0 or progress>1 or not targetpoint.is_finite() or not normal.is_finite() or normal.length_squared()<.000001:
		_stop(); return {"ok":false,"reason":"placement_visual_inputs"}
	if not _pose_allowed():
		_stop(); return {"ok":false,"reason":"native_pose_owned_elsewhere"}
	var player: CharacterBody3D=_player.get_ref()
	_holding=true; _progress=progress; _target=targetpoint; _normal=normal.normalized()
	_request_frame=Engine.get_physics_frames(); _request_epoch=int(player.get("_pose_epoch"))
	_modifier.active=true
	return {"ok":true,"holding":true,"display_sample_available":_display_valid,"right_hand_error_m":_right_error_m,"left_hand_error_m":_left_error_m}

func _stop() -> void:
	_holding=false; _display_valid=false; _modified_revision=-1
	_right_error_m=INF; _left_error_m=INF
	if is_instance_valid(_modifier): _modifier.active=false

static func _smooth(value: float,a: float,b: float) -> float:
	var t: float=clampf((value-a)/(b-a),0,1)
	return t*t*(3.0-2.0*t)

static func surface_basis(normal: Vector3,reference_up: Vector3=Vector3.UP) -> Basis:
	var z: Vector3=normal.normalized()
	var y: Vector3=reference_up-z*reference_up.dot(z)
	if y.length_squared()<.000001: y=Vector3.FORWARD-z*Vector3.FORWARD.dot(z)
	y=y.normalized()
	var x: Vector3=y.cross(z).normalized()
	return Basis(x,z.cross(x).normalized(),z)

func _update_world() -> void:
	for index: int in 28:
		_world[index]=(_rig.global_transform if _parents[index]<0 else _world[_parents[index]])*_local[index]

func _set_world_basis(index: int,basis: Basis) -> void:
	var pose: Transform3D=_world[index]
	pose.basis=basis
	var parent: Transform3D=_rig.global_transform if _parents[index]<0 else _world[_parents[index]]
	_local[index]=parent.affine_inverse()*pose
	_update_world()

func _point_bone(index: int,end: int,target: Vector3) -> void:
	var before: Vector3=_world[end].origin-_world[index].origin
	var after: Vector3=target-_world[index].origin
	if before.length_squared()<.000001 or after.length_squared()<.000001: return
	_set_world_basis(index,Basis(Quaternion(before.normalized(),after.normalized()))*_world[index].basis)

func _reach(side: String,grip: Vector3,hand_basis: Basis,blend: float) -> float:
	var upper: int=_ids["upperarm_"+side]; var fore: int=_ids["forearm_"+side]
	var hand: int=_ids["hand_"+side]; var socket: int=_ids["socket_hand_"+side]
	var original_upper: Basis=_local[upper].basis
	var original_fore: Basis=_local[fore].basis
	var original_hand: Basis=_local[hand].basis
	var desired_hand: Basis=hand_basis*Basis.from_scale(_world[hand].basis.get_scale())
	var wrist: Vector3=grip-desired_hand*_local[socket].origin
	var shoulder: Vector3=_world[upper].origin
	var a: float=shoulder.distance_to(_world[fore].origin)
	var b: float=_world[fore].origin.distance_to(_world[hand].origin)
	var line: Vector3=wrist-shoulder
	if a<.001 or b<.001 or line.length_squared()<.000001: return INF
	var length: float=clampf(line.length(),absf(a-b)+.0001,a+b-.0001)
	line=line.normalized()
	var pole: Vector3=(_tool_basis.x*(.6 if side=="r" else -.6)+Vector3.DOWN*.8+_normal*.15)
	pole-=line*pole.dot(line)
	if pole.length_squared()<.000001: pole=_tool_basis.y-line*_tool_basis.y.dot(line)
	pole=pole.normalized()
	var along: float=(a*a-b*b+length*length)/(2.0*length)
	var elbow: Vector3=shoulder+line*along+pole*sqrt(maxf(0,a*a-along*along))
	wrist=shoulder+line*length
	_point_bone(upper,fore,elbow); _point_bone(fore,hand,wrist)
	_set_world_basis(hand,desired_hand)
	# Independent arm envelopes preserve the native base pose at entry. Origins
	# and scales are untouched; unreachable surfaces never lengthen the limbs.
	_local[upper].basis=Basis(original_upper.get_rotation_quaternion().slerp(_local[upper].basis.get_rotation_quaternion(),blend))*Basis.from_scale(original_upper.get_scale())
	_local[fore].basis=Basis(original_fore.get_rotation_quaternion().slerp(_local[fore].basis.get_rotation_quaternion(),blend))*Basis.from_scale(original_fore.get_scale())
	_local[hand].basis=Basis(original_hand.get_rotation_quaternion().slerp(_local[hand].basis.get_rotation_quaternion(),blend))*Basis.from_scale(original_hand.get_scale())
	_update_world()
	return _world[socket].origin.distance_to(grip)

func _modify(_dt: float) -> void:
	_modified_revision=-1; _display_valid=false
	if not _holding or not _pose_allowed() or Engine.get_physics_frames()-_request_frame>1: return
	var player: CharacterBody3D=_player.get_ref()
	if int(player.get("_pose_epoch"))!=_request_epoch: return
	var started: int=Time.get_ticks_usec()
	for index: int in 28: _local[index]=_rig.get_bone_pose(index)
	_update_world()
	_tool_basis=surface_basis(_normal)
	var reach: float=_smooth(_progress,0,.18)
	var chest: int=_ids.chest
	var toward: Vector3=_target-_world[chest].origin
	var horizontal:=Vector3(toward.x,0,toward.z)
	if horizontal.length_squared()>.000001:
		var axis: Vector3=Vector3.UP.cross(horizontal.normalized()).normalized()
		var lean: float=clampf(-toward.y*.22+horizontal.length()*.065,.025,.28)*reach
		_set_world_basis(chest,Basis(Quaternion(axis,lean))*_world[chest].basis)
	# Lift the package, hold it against the surface, then use the right fingers
	# for two small securing movements while the left hand keeps it steady.
	var secure: float=_smooth(_progress,.38,.50)*(1.0-_smooth(_progress,.82,.94))
	var touch: float=sin(clampf((_progress-.40)/.46,0,1)*TAU*2.0)*.009*secure
	var center: Vector3=_target+_normal*(.082+(.16*(1.0-reach)))
	var right_grip: Vector3=center+_tool_basis.x*.065+_tool_basis.y*(touch+.022*secure)
	var left_grip: Vector3=center-_tool_basis.x*.085-_tool_basis.y*.018
	_right_goal=right_grip; _left_goal=left_grip
	var hand_orientation: Basis=_tool_basis*Basis(Vector3.UP,PI)*Basis(Vector3.RIGHT,-PI*.5)
	_right_error_m=_reach("r",right_grip,hand_orientation*Basis(_rest_hands[0]),reach)
	_left_error_m=_reach("l",left_grip,hand_orientation*Basis(_rest_hands[1]),_smooth(_progress,.04,.24))
	for bone_name: String in BONE_NAMES:
		if bone_name.begins_with("socket_"): continue
		var index: int=_ids[bone_name]
		if not _local[index].is_finite(): return
	for bone_name: String in BONE_NAMES:
		if not bone_name.begins_with("socket_"): _rig.set_bone_pose(_ids[bone_name],_local[_ids[bone_name]])
	_modified_revision=int(player.get("_pose_revision")); _samples+=1
	_max_usec=maxi(_max_usec,Time.get_ticks_usec()-started)

func _capture_displayed() -> void:
	if not _holding or not _pose_allowed() or _modified_revision<0: return
	var player: CharacterBody3D=_player.get_ref()
	if int(player.get("_pose_revision"))!=_modified_revision or int(player.get("_pose_epoch"))!=_request_epoch: return
	var palm: Transform3D=_rig.global_transform*_rig.get_bone_global_pose(_ids.socket_hand_r)
	var left: Transform3D=_rig.global_transform*_rig.get_bone_global_pose(_ids.socket_hand_l)
	# Report the actual engine pose, including its local matrix decomposition.
	_right_error_m=palm.origin.distance_to(_right_goal)
	_left_error_m=left.origin.distance_to(_left_goal)
	_display_frame=Transform3D(_tool_basis,palm.origin-_tool_basis.x*.065)
	_display_valid=_display_frame.is_finite()
	if _display_valid: pose_applied.emit(_display_frame)

func held_frame() -> Dictionary:
	if not _display_valid or not _holding or not _pose_allowed(): return {"ok":false}
	var player: CharacterBody3D=_player.get_ref()
	if int(player.get("_pose_revision"))!=_modified_revision or int(player.get("_pose_epoch"))!=_request_epoch or Engine.get_physics_frames()-_request_frame>1: return {"ok":false}
	return {"ok":true,"frame":_display_frame,"right_hand_error_m":_right_error_m,"left_hand_error_m":_left_error_m,"pose_revision":_modified_revision,"pose_epoch":_request_epoch}

func snapshot() -> Dictionary:
	return {"ready":_current(),"holding":_holding,"samples":_samples,"max_modifier_usec":_max_usec,"right_hand_error_m":_right_error_m,"left_hand_error_m":_left_error_m,"resource_allocations_during_advance":0,"loaded_scene_performance":"unverified"}

func dispose() -> void:
	if _disposed: return
	_stop(); _disposed=true
	if is_instance_valid(_rig) and _rig.skeleton_updated.is_connected(_capture_displayed): _rig.skeleton_updated.disconnect(_capture_displayed)
	if is_instance_valid(_modifier): _modifier.presentation=null; _modifier.queue_free()
	_modifier=null; _rig=null; _player=null; _ready=false

static func _material(key: String) -> Material:
	if _materials.has(key): return _materials[key]
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color.WHITE if key=="opaque" else Color(COLORS[key]); material.roughness=.67
	material.vertex_color_use_as_albedo=key=="opaque"
	if key=="metal": material.metallic=.72; material.roughness=.35
	if key in ["screen","led"]:
		material.emission_enabled=true; material.emission=material.albedo_color; material.emission_energy_multiplier=.55 if key=="screen" else 1.05
	_materials[key]=material
	return material

static func _append(groups: Dictionary,mesh: PrimitiveMesh,frame: Transform3D,key: String) -> void:
	# All cloth, straps, wires and lettering share one vertex-colour surface.
	# Only metal, screen and indicator need different material parameters.
	var surface: String=key if key in ["metal","screen","led"] else "opaque"
	if not groups.has(surface): groups[surface]={"v":[],"n":[],"uv":[],"c":[],"i":[]}
	var row: Dictionary=groups[surface]
	var color: Color=Color(COLORS[key]) if surface=="opaque" else Color.WHITE
	var arrays: Array=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var offset: int=row.v.size()
	for index: int in vertices.size():
		row.v.append(frame*vertices[index]); row.n.append((frame.basis*normals[index]).normalized())
		row.uv.append(uvs[index] if index<uvs.size() else Vector2.ZERO)
		row.c.append(color)
	if indices.is_empty():
		for index: int in vertices.size(): row.i.append(offset+index)
	else:
		for index: int in indices: row.i.append(offset+index)

static func _box(groups: Dictionary,size: Vector3,at: Vector3,key: String) -> void:
	var mesh:=BoxMesh.new(); mesh.size=size
	_append(groups,mesh,Transform3D(Basis.IDENTITY,at),key)

static func _wire(groups: Dictionary,points: PackedVector3Array,radius: float,key: String) -> void:
	for index: int in points.size()-1:
		var delta: Vector3=points[index+1]-points[index]
		if delta.length_squared()<.000001: continue
		var mesh:=CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=delta.length(); mesh.radial_segments=6; mesh.rings=1
		_append(groups,mesh,Transform3D(Basis(Quaternion(Vector3.UP,delta.normalized())),(points[index+1]+points[index])*.5),key)

static func _text(groups: Dictionary,text: String,at: Vector3,height: float,key: String) -> void:
	var mesh:=TextMesh.new(); mesh.font=ThemeDB.fallback_font; mesh.text=text
	mesh.font_size=48; mesh.pixel_size=height/48.0; mesh.depth=.0004
	_append(groups,mesh,Transform3D(Basis.IDENTITY,at),key)

static func _build_model(remote: bool) -> ArrayMesh:
	var groups: Dictionary={}
	if remote:
		_box(groups,Vector3(.104,.165,.045),Vector3.ZERO,"edge")
		_box(groups,Vector3(.09,.149,.008),Vector3(0,0,.026),"strap")
		for side: float in [-1.0,1.0]:
			for y: float in [-.059,-.039,-.019,.001,.021]: _box(groups,Vector3(.007,.010,.051),Vector3(side*.053,y,0),"ink")
		_box(groups,Vector3(.070,.038,.003),Vector3(0,.043,.032),"metal")
		_box(groups,Vector3(.062,.029,.003),Vector3(0,.043,.034),"screen")
		_text(groups,"LINK",Vector3(-.008,.042,.037),.009,"ink")
		for index: int in 3: _box(groups,Vector3(.003,.004+index*.003,.001),Vector3(.014+index*.005,.043,.037),"ink")
		_box(groups,Vector3(.036,.035,.011),Vector3(0,-.012,.035),"red")
		_box(groups,Vector3(.045,.009,.010),Vector3(0,.011,.040),"metal")
		_text(groups,"FIRE",Vector3(0,-.010,.042),.007,"paper")
		_text(groups,"REMOTE",Vector3(0,-.058,.031),.008,"paper")
		_wire(groups,PackedVector3Array([Vector3(.033,.082,0),Vector3(.033,.15,0),Vector3(.040,.17,0)]),.0045,"ink")
		_box(groups,Vector3(.009,.008,.004),Vector3(-.033,.071,.031),"led")
	else:
		_box(groups,Vector3(.222,.158,.072),Vector3.ZERO,"olive")
		_box(groups,Vector3(.229,.148,.064),Vector3.ZERO,"olive")
		_box(groups,Vector3(.214,.166,.064),Vector3.ZERO,"olive")
		for x: float in [-.078,.078]:
			_box(groups,Vector3(.025,.168,.078),Vector3(x,0,0),"strap")
			_box(groups,Vector3(.034,.030,.009),Vector3(x,-.041,.043),"metal")
			_box(groups,Vector3(.022,.020,.010),Vector3(x,-.041,.049),"ink")
		for x: float in [-.113,.113]:
			for y: float in [-.057,-.035,-.013,.009,.031,.053]: _box(groups,Vector3(.006,.004,.063),Vector3(x,y,0),"edge")
		_box(groups,Vector3(.092,.068,.0015),Vector3(-.005,-.021,.037),"paper")
		_text(groups,"C4",Vector3(-.007,-.010,.039),.026,"ink")
		_text(groups,"M-04",Vector3(-.005,-.041,.039),.008,"ink")
		_box(groups,Vector3(.071,.037,.016),Vector3(.011,.045,.044),"edge")
		_box(groups,Vector3(.041,.014,.002),Vector3(.011,.047,.053),"screen")
		_text(groups,"SAFE",Vector3(.009,.045,.055),.007,"ink")
		_box(groups,Vector3(.008,.009,.005),Vector3(.039,.037,.056),"led")
		_wire(groups,PackedVector3Array([Vector3(-.031,.049,.045),Vector3(-.044,.065,.056),Vector3(-.068,.067,.061),Vector3(-.092,.047,.050),Vector3(-.094,.012,.040)]),.0023,"red")
		_wire(groups,PackedVector3Array([Vector3(.052,.048,.046),Vector3(.061,.068,.057),Vector3(.084,.069,.059),Vector3(.098,.051,.049),Vector3(.099,.021,.040)]),.0023,"wire")
		for x: float in [-.018,.041]: _box(groups,Vector3(.003,.003,.003),Vector3(x,.058,.054),"metal")
	var result:=ArrayMesh.new()
	for key: String in groups:
		var row: Dictionary=groups[key]
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array(row.v); arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array(row.n)
		arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array(row.uv); arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(row.i)
		arrays[Mesh.ARRAY_COLOR]=PackedColorArray(row.c)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(result.get_surface_count()-1,_material(key))
	return result

static func make_device(remote: bool) -> Node3D:
	if not _model_cache.has(remote): _model_cache[remote]=_build_model(remote)
	var root:=Node3D.new(); root.name="C4Remote" if remote else "C4DetailedPackage"
	var model:=MeshInstance3D.new(); model.name="SharedDetailedDevice"; model.mesh=_model_cache[remote]
	model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(model); root.set_meta("virtual_equipment_visual",true)
	root.set_meta("shared_cached_geometry",true); root.set_meta("back_depth_m",.039 if not remote else .026)
	root.set_meta("render_surfaces",model.mesh.get_surface_count())
	return root
