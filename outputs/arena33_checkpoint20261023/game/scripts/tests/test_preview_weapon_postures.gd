extends SceneTree
## Independent actual-main integration test. No runtime source writes or GPU.
var checks:=0
var failures:Array[String]=[]
var samples:Array[Dictionary]=[]
var fire_attempts:Array[Dictionary]=[]
var _skin:Array[Dictionary]=[]
var _scene:Node3D
var _player:CharacterBody3D
var _weapons:Node
var _minimum_clearance:=INF
var _maximum_floor_gap:=0.0
var _done:=false
func check(value:bool,label:String)->void:
	checks+=1
	if not value and failures.size()<40:failures.append(label)
func key(code:Key)->InputEventKey:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;return event
func mouse(pressed:bool)->InputEventMouseButton:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;return event
func sync(count:int=1)->void:
	for i:int in count:await physics_frame;await process_frame
func _initialize()->void:run.call_deferred()
func _collect_skin()->void:
	var rig:Skeleton3D=_player._pose_skeleton
	var vertices:=0
	for mesh:MeshInstance3D in _player._pose_motion.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var ids:=PackedInt32Array();var binds:Array[Transform3D]=[]
		for at:int in mesh.skin.get_bind_count():ids.append(rig.find_bone(mesh.skin.get_bind_name(at)));binds.append(mesh.skin.get_bind_pose(at))
		for surface:int in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface);vertices+=arrays[Mesh.ARRAY_VERTEX].size()
			_skin.append({"ids":ids,"binds":binds,"positions":arrays[Mesh.ARRAY_VERTEX],"bones":arrays[Mesh.ARRAY_BONES],"weights":arrays[Mesh.ARRAY_WEIGHTS]})
	check(vertices==8338,"actual full8338 hero skin collected")
func _geometry(label:String)->void:
	var rig:Skeleton3D=_player._pose_skeleton
	var globals:Array[Transform3D]=[];var finite:=_player.global_transform.is_finite()
	for i:int in rig.get_bone_count():
		var frame:Transform3D=rig.global_transform*rig.get_bone_global_pose(i);globals.append(frame);finite=finite and frame.is_finite()
	var low:=INF;var high:=-INF
	for part:Dictionary in _skin:
		var transforms:Array[Transform3D]=[]
		for i:int in part.ids.size():transforms.append(globals[part.ids[i]]*part.binds[i])
		for i:int in part.positions.size():
			var point:=Vector3.ZERO
			for j:int in 4:
				var at:=i*4+j;point+=(transforms[part.bones[at]]*part.positions[i])*part.weights[at]
			finite=finite and point.is_finite();low=minf(low,point.y);high=maxf(high,point.y)
	var query:=PhysicsRayQueryParameters3D.create(_player.global_position+Vector3.UP*.15,_player.global_position-Vector3.UP*2,1,[_player.get_rid()])
	var floor_hit:=_scene.get_world_3d().direct_space_state.intersect_ray(query)
	check(finite,label+" every displayed bone and actual skin vertex finite")
	check(not floor_hit.is_empty(),label+" real authored floor found")
	if not floor_hit.is_empty():
		var clearance:float=low-floor_hit.position.y;_minimum_clearance=minf(_minimum_clearance,clearance);_maximum_floor_gap=maxf(_maximum_floor_gap,clearance)
		check(clearance>=-.004,label+" no displayed skin below actual floor: "+str(clearance))
		if float(_weapons._posture_view.value)>1.95:check(clearance<.025,label+" prone rests at floor")
		samples.append({"label":label,"body_y":_player.global_position.y,"actual_floor_y":floor_hit.position.y,"skin_min_y":low,"skin_max_y":high,"clearance_m":clearance})
func _fire(id:String,label:String)->void:
	# Re-equipped source inventory preserves its cooldown. Wait for the real
	# controller; never zero cooldown or refill ammo to make a firing test pass.
	var initial_cooldown:float=_weapons.fire_state.cooldown;var waited:=0
	for i:int in 180:
		if float(_weapons.fire_state.cooldown)<=0.0 and float(_weapons.fire_state.reloadRemaining)<=0.0:break
		waited+=1;await sync()
	check(float(_weapons.fire_state.cooldown)<=0 and float(_weapons.fire_state.reloadRemaining)<=0,label+" source fire timer ready")
	var before_mag:int=_weapons.fire_state.magazine;var before_shots:int=_weapons.shots_count
	_player._unhandled_input(mouse(true));await sync(2);_player._unhandled_input(mouse(false));await sync(2)
	var emitted:int=_weapons.shots_count-before_shots;var spent:int=before_mag-int(_weapons.fire_state.magazine)
	fire_attempts.append({"label":label,"initial_preserved_cooldown":initial_cooldown,"waited_physics_frames":waited,"magazine_before":before_mag,"magazine_after":_weapons.fire_state.magazine,"emitted":emitted})
	if id=="rpg":check(emitted==0 and spent==0,label+" unsupported RPG stays denied without ammo use")
	else:
		check(emitted>0,label+" actual weapon fires")
		check(spent==emitted,label+" finite ammo equals emitted shots")
	check(_weapons.fire_state.magazine>=0 and _weapons.fire_state.reserveAmmo>=0,label+" finite nonnegative ammo")
func _stance(code:Key,target:String,value:float,height:float)->void:
	_player._unhandled_input(key(code));await sync(72)
	check(_weapons.posture.posture_state().target==target and absf(_weapons._posture_view.value-value)<.0001,target+" actual key/controller settled")
	var capsule:CollisionShape3D=_player.get_node("PlayerCapsule")
	check(absf(capsule.shape.height-height)<.00001,target+" actual collision capsule height")
	check(absf(capsule.position.y-height*.5)<.00001,target+" actual capsule foot plane retained")
func run()->void:
	create_timer(45.0).timeout.connect(func():
		if not _done:push_error("WEAPON_POSTURES_TEST_TIMEOUT");quit(3))
	var pinned:Dictionary={}
	for path:String in ["res://scripts/weapons/preview_weapons.gd","res://scripts/preview_player.gd","res://scripts/weapons/weapon_posture_base.gd"]:pinned[path]=FileAccess.get_sha256(path)
	_scene=load("res://scenes/main.tscn").instantiate();_scene.preview_residents_enabled=false;_scene.preview_weapons_enabled=true
	root.add_child(_scene)
	for i:int in 240:
		if _scene.preview_ready:break
		await sync()
	check(_scene.preview_ready,"actual main ready")
	_player=_scene._player;_weapons=_scene.preview_weapons
	check(is_instance_valid(_weapons),"actual main installed weapon host")
	if not is_instance_valid(_weapons):_finish(pinned);return
	await sync(20);_collect_skin()
	_player._unhandled_input(mouse(true));_player._unhandled_input(mouse(false));await sync(2)
	check(_player._free_mouse_look,"real click capture")
	check(_weapons.equip("ak74").ok,"actual finite inventory equip")
	var initial_foot:Vector3=_player.global_position
	await _stance(KEY_C,"crouch",1.0,1.69)
	# Test-only physical ceiling in the actual scene; not a fake cover state.
	var ceiling:=StaticBody3D.new();ceiling.name="WeaponPostureTestCeiling";ceiling.collision_layer=1;ceiling.collision_mask=0
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,.12,4);collider.shape=box;ceiling.add_child(collider)
	ceiling.position=_player.global_position+Vector3.UP*1.82;_scene.add_child(ceiling);await sync(3)
	check(not _weapons._can_occupy_posture(1.9,"stand"),"real low ceiling overlap denies standing capsule")
	_player._unhandled_input(key(KEY_C));await sync(10)
	check(_weapons.posture.posture_state().target=="crouch" and absf(_weapons._posture_view.value-1)<.0001,"C cannot stand through actual low ceiling")
	_geometry("crouch below ceiling")
	ceiling.queue_free();await sync(3)
	check(_weapons._can_occupy_posture(1.9,"stand"),"removing test ceiling restores real clearance")
	var ids:Array=_weapons.Fire.ids()
	for stance:String in ["crouch","prone"]:
		if stance=="prone":await _stance(KEY_Z,"prone",2.0,.62)
		for id:String in ids:
			check(_weapons.equip(id).ok,stance+" original equip "+id);await sync(4)
			var receipt:Dictionary=_weapons.presentation.current_muzzle()
			check(receipt.get("ok",false),stance+" fresh mounted muzzle "+id)
			if receipt.get("ok",false):
				check(receipt.weapon_id==id and receipt.pose_revision==_player._pose_revision,stance+" muzzle same accepted pose "+id)
				check(receipt.origin.is_finite() and receipt.direction.is_finite(),stance+" muzzle finite "+id)
			_geometry(stance+" "+id)
			await _fire(id,stance+" "+id)
		check(_weapons.equip("ak74").ok,stance+" AK reload equip");await sync(4)
		var total:int=_weapons.fire_state.magazine+_weapons.fire_state.reserveAmmo
		_player._unhandled_input(key(KEY_R));await sync(20)
		check(float(_weapons.fire_state.reloadRemaining)>0,stance+" reload starts")
		check(_weapons.presentation.current_muzzle().get("ok",false),stance+" reload current muzzle")
		_geometry(stance+" reload")
		await sync(210)
		check(float(_weapons.fire_state.reloadRemaining)==0,stance+" reload finishes")
		check(int(_weapons.fire_state.magazine+_weapons.fire_state.reserveAmmo)==total,stance+" reload conserves finite ammo")
	check(_player.global_position.distance_to(initial_foot)<.08,"posture never teleports actual actor")
	var before_mag:int=_weapons.fire_state.magazine;var before_shots:int=_weapons.shots_count
	_player.set_preview_pose_authority(&"vehicle",true);await sync(3)
	_player._unhandled_input(mouse(true));await sync(5);_player._unhandled_input(mouse(false))
	check(not _weapons.presentation.current_muzzle().get("ok",false),"vehicle authority denies onfoot muzzle")
	check(_weapons.shots_count==before_shots and _weapons.fire_state.magazine==before_mag,"vehicle denied fire keeps finite ammo")
	_player.set_preview_pose_authority(&"on_foot",true);await sync(5)
	check(_weapons.presentation.current_muzzle().get("ok",false),"return from vehicle has new current muzzle")
	await _stance(KEY_Z,"stand",0.0,1.9)
	_geometry("returned standing")
	for path:String in pinned:check(FileAccess.get_sha256(path)==pinned[path],"runtime source unchanged during test "+path)
	_finish(pinned)
func _finish(pinned:Dictionary)->void:
	_done=true
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"actual main, real hero and world physics, residents disabled, headless; test physical low ceiling is not cover", "runtime_sha256":pinned,"minimum_displayed_skin_floor_clearance_m":_minimum_clearance,"maximum_floor_gap_m":_maximum_floor_gap,"samples":samples,"fire_attempts":fire_attempts,"cover_supported":false,"passenger_firing_supported":false,"vehicle_scope":"authority deny/reentry only; original actual seat base separately tested by preceding package"}
	var args:=OS.get_cmdline_user_args()
	for arg:String in args:
		if arg.begins_with("--posture-report="):FileAccess.open(arg.trim_prefix("--posture-report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PREVIEW_WEAPON_POSTURES ",JSON.stringify(report))
	if is_instance_valid(_scene):_scene.free()
	quit(0 if failures.is_empty() else 1)
