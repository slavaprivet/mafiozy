extends Node3D
## SEPARATE QA fixture: one resident_1 appearance, real full capsule/ground/bench/glass.
## Does not load the city or claim city life, economy, combat, death or crowd acceptance.
const Ambient = preload("res://scripts/npc_ambient/ambient_controller28.gd")
const Pose = preload("res://scripts/npc_ambient/ambient_pose28.gd")
const Gait = preload("res://scripts/preview_locomotion.gd")
const Motion = preload("res://scripts/hospital/npc_motion_visual51.gd")
const Driver = preload("res://scripts/hospital/npc_simple_hospital.gd")
const Route = preload("res://scripts/hospital/npc_physical_route51.gd")
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const PREPARED := "res://assets/npc_city/prepared/9651313960a2650e440c95cf5052680e7de7078e03d6e27cea295994c688e710.scn"
const PREPARED_SHA := "9651313960a2650e440c95cf5052680e7de7078e03d6e27cea295994c688e710"
const MANIFEST_SHA := "929a5083842a5325ba5d4d823b1ac63c8b56b459ac19b414057ce6190f35f288"
const DESCRIPTOR_SHA := "6f67f9d655bc66e512ec3c3eb206f5fefd3523256f075d15750a8e4af22a747e"
class FixtureIdentity extends RefCounted:
	var body: CharacterBody3D
	var rig: Skeleton3D
	var living := true
	func target_current(token: Dictionary) -> bool:
		return living and is_instance_valid(body) and body.is_inside_tree() and token.get("source_id") == "resident_1" and token.get("life_generation") == 1 and token.get("body") == body and token.get("rig") == rig

var _block: Dictionary = {}
var _origin := Vector3(40,0,40)
var _body: CharacterBody3D
var _shape: CollisionShape3D
var _motion: Node3D
var _rig: Skeleton3D
var _ambient: RefCounted
var _gait: RefCounted
var _pose: RefCounted
var _route: RefCounted
var _driver: RefCounted
var _identity: FixtureIdentity
var _camera: Camera3D
var _out := ""
var _started := 0
var _stage := "BOOT"
var _index := -1
var _age := 0.0
var _captures := {}
var _rows: Array = []
var _failures: Array = []
var _last_sample := 0
var _capture_busy := false
var _cancel_phase := ""
var _cancel_kind := "book"
var _cancelled := false
var _stale_life30 := false
var _checks: Dictionary = {}
var _walk_start := Vector3.ZERO
var _requested_kinds30: Array = []
var _max_foot_error30 := 0.0
var _max_body_step30 := 0.0
var _rig_report30: Dictionary = {}
var _max_bench_contact_error30 := 0.0
var _max_dock_error30 := 0.0

func start() -> void:
	_started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): _out = arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-cancel-phase="): _cancel_phase = arg.trim_prefix("--qa-cancel-phase=")
		if arg.begins_with("--qa-kind="): _cancel_kind = arg.trim_prefix("--qa-kind=")
		if arg.begins_with("--qa-kinds="): _requested_kinds30 = Array(arg.trim_prefix("--qa-kinds=").split(","))
		if arg == "--qa-stale-life": _stale_life30 = true
	if _out.is_empty(): _finish("qa_out_required"); return
	DirAccess.make_dir_recursive_absolute(_out)
	var grid: Array = []
	for row: int in 20:
		var cells: Array = []; cells.resize(20); cells.fill(0); grid.append(cells)
	_block = {"surface":{"grid":grid,"palette":{"0":{"kind":"land","solid":true,"heightM":0},"1":{"kind":"water","solid":false,"heightM":-2}},"cellSize":4.0,"startCol":0,"startRow":0}}
	_box(self,Vector3(60,.2,60),Vector3(0,-.1,0),Color("c4c0b1"),true)
	var bench := Node3D.new(); bench.name = "OriginalBenchFixture"; bench.set_meta("palazzo_bench",true); add_child(bench)
	for z: float in [-.16,.04,.24]: _box(bench,Vector3(1.7,.10,.15),Vector3(0,.43,z),Color("80634b"),false)
	for x: float in [-.64,.64]: _box(bench,Vector3(.09,.47,.48),Vector3(x,.22,.02),Color("3b3935"),false)
	_box(bench,Vector3(1.7,.34,.10),Vector3(0,.83,-.22),Color("80634b"),false)
	var glazing := Node3D.new(); glazing.name = "OwnedWindowGlazing"; add_child(glazing)
	var glass: Node3D = _box(glazing,Vector3(2.8,1.8,.10),Vector3(0,1.55,-4),Color("85b5c8"),true)
	glass.set_meta("material_class","glass")
	if FileAccess.get_sha256(PREPARED) != PREPARED_SHA: _finish("resident_appearance_pin_failed"); return
	var loaded: Dictionary = Cache.load_verified(FileAccess.get_file_as_bytes("res://assets/npc_city/prepared/manifest.json"),MANIFEST_SHA,"npc_resident_1",DESCRIPTOR_SHA,"res://assets/npc_city/prepared")
	if not loaded.get("ok",false): _finish("resident_verified_load_failed"); return
	var appearance: Dictionary = loaded.cache.instantiate_actor(); loaded.cache.dispose()
	if not appearance.get("ok",false): _finish("resident_appearance_instantiate_failed"); return
	var visual: Node3D = appearance.visual
	_body = CharacterBody3D.new(); _body.name = "resident_1"; _body.collision_layer = 1; _body.collision_mask = 1; _body.floor_snap_length = .25
	_shape = CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = 1.9; _shape.shape = capsule; _shape.position.y = .95; _body.add_child(_shape)
	_motion = Node3D.new(); _motion.name = "ResidentVisualMotion"; _motion.rotation.y = PI; _body.add_child(_motion); _motion.add_child(visual)
	# Sole initial placement, before entering physics or starting any activity.
	_body.position = Vector3(0,.003,1.8); add_child(_body)
	_gait = Gait.new()
	if not _gait.bind(visual,_motion,true): _finish("canonical_gait_bind_failed"); return
	_rig = _gait._skeleton
	_pose = Pose.new()
	if not _pose.bind(_rig,_gait._rest_poses): _finish("ambient_pose_bind_failed"); return
	for bone: int in _rig.get_bone_count():
		_rig_report30[_rig.get_bone_name(bone)] = {"parent":_rig.get_bone_parent(bone),"local":str(_gait._rest_poses[bone]),"global":str(_pose._global[bone]),"global_position":_rig.to_global(_pose._global[bone].origin)}
	_rig_report30["reach"] = _pose._reach
	_rig_report30["rig_global"] = str(_rig.global_transform)
	_identity = FixtureIdentity.new(); _identity.body = _body; _identity.rig = _rig
	var token := {"source_id":"resident_1","life_generation":1,"body":_body,"rig":_rig}
	_ambient = Ambient.new()
	if not _ambient.configure(_identity,token,self,RID()): _finish("ambient_bind_failed"); return
	_route = Route.new()
	if not _route.configure(_body): _finish("physical_route_bind_failed"); return
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-42,-25,0); sun.light_energy = 1.1; add_child(sun)
	var world := WorldEnvironment.new(); var environment := Environment.new(); environment.background_mode = Environment.BG_COLOR; environment.background_color = Color("8797a0"); environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color = Color.WHITE; environment.ambient_light_energy = .65; world.environment = environment; add_child(world)
	_camera = Camera3D.new(); _camera.fov = 48; add_child(_camera); _camera.current = true; _camera_view("full")
	_stage = "SETTLE"

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, physical: bool) -> Node3D:
	var owner: Node3D = StaticBody3D.new() if physical else MeshInstance3D.new()
	owner.position = at; parent.add_child(owner)
	var mesh: MeshInstance3D = MeshInstance3D.new() if physical else owner as MeshInstance3D
	var box := BoxMesh.new(); box.size = size
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = .8; box.material = mat; mesh.mesh = box
	if physical:
		owner.add_child(mesh); var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collider.shape = shape; owner.add_child(collider)
	else: owner.set_meta("box_size",size)
	return owner

func _seed_for_first(kind: String) -> int:
	var choices: Array = Pose.KINDS.duplicate(); choices.erase(_ambient.get("_previous"))
	var random := RandomNumberGenerator.new()
	for seed_value: int in 4096:
		random.seed = seed_value
		if choices[random.randi_range(0,choices.size()-1)] == kind: return seed_value
	return -1

func _begin_next() -> void:
	_index += 1
	var kinds: Array = (Pose.KINDS if _requested_kinds30.is_empty() else _requested_kinds30) if _cancel_phase.is_empty() else [_cancel_kind]
	if _index >= kinds.size(): _finish("bounded_fixture_complete"); return
	var kind: String = kinds[_index]
	if kind not in Pose.KINDS: _finish("unknown_fixture_kind"); return
	var seed_value: int = _seed_for_first(kind)
	if seed_value < 0: _finish("no_seed_for_requested_kind"); return
	_ambient.get("_rng").seed = seed_value
	if not _ambient.try_begin() or _ambient.snapshot().kind != kind:
		_failures.append({"kind":kind,"reason":"real_condition_unavailable","snapshot":_ambient.snapshot()}); _finish("condition_failed"); return
	_rows.append({"event":"begin","kind":kind,"fixture_seed":seed_value,"snapshot":_ambient.snapshot()})
	_captures.clear(); _stage = "ACTION"; _age = 0

func _physics_process(delta: float) -> void:
	if _stage == "BOOT" or _stage == "DONE": return
	if Time.get_ticks_msec()-_started > 300000: _finish("bounded_timeout"); return
	if delta <= 0 or delta > .05: return
	_age += delta
	if _shape.disabled or _body.collision_layer != 1 or _body.collision_mask != 1 or not is_equal_approx(_shape.shape.radius,.36) or not is_equal_approx(_shape.shape.height,1.9): _finish("capsule_changed"); return
	var before: Vector3 = _body.global_position
	if _stage == "SETTLE":
		_route.hold(delta)
		if _age >= .3 and _body.is_on_floor(): _begin_next()
	elif _stage == "ACTION":
		var state: Dictionary = _ambient.snapshot()
		if not _cancel_phase.is_empty() and not _cancelled and state.phase == _cancel_phase and (_cancel_phase != "ACTING" or state.elapsed_s >= 1.5):
			if _stale_life30:
				_identity.living = false
				_checks["life_cancels_before_invalid_delta"] = _ambient.step(0.0) == "blocked"
			else: Pose.cancel_body(_body,"fixture_interruption")
			_cancelled = true
			_checks["synchronous_cancel"] = not _ambient.active() and not _body.has_meta(Pose.META) and _visible_props() == 0
			_checks["bench_slot_released"] = int(_ambient.snapshot().bench_inventory.get("claims",0)) == 0
		var result: String = _ambient.step(delta)
		if result != "active":
			_rows.append({"event":"ended","result":result,"snapshot":_ambient.snapshot(),"metadata_cleared":not _body.has_meta(Pose.META),"visible_props":_visible_props()})
			if result == "blocked": _failures.append({"kind":state.kind,"reason":_ambient.snapshot().reason})
			_driver = Driver.new(); _walk_start = _body.global_position
			var target: Vector3 = _walk_start + Vector3(1.0,0,1.0)
			if not _driver.begin(target,_body,RID(),"resident_1","roam"): _finish("resume_walk_begin_failed"); return
			_stage = "WALK"; _age = 0
	elif _stage == "WALK":
		var result: String = _driver.step(delta)
		if result == "blocked" or _age > 20: _finish("resume_walk_failed"); return
		if result == "arrived":
			var moved: float = _body.global_position.distance_to(_walk_start)
			_rows.append({"event":"walk_resumed","moved_m":moved,"visible_props":_visible_props()})
			if moved < .8 or _visible_props() != 0: _failures.append({"reason":"walk_or_props_after_action"})
			_driver.cancel(); _driver = null; _begin_next()
	var physical: Dictionary = Motion.consume(_body,delta)
	var measured: Vector3 = _body.global_position-before
	var value: Dictionary = Pose.sample(_body,delta,physical)
	Pose.suppress(_body)
	var selected: Dictionary = _gait.sample(delta,Vector3(measured.x,0,measured.z)/delta,_body.is_on_floor())
	var foot_targets30: Dictionary = {}
	if not value.is_empty() and value.get("kind") == "bench":
		_pose._working = selected.poses.duplicate(); _pose._compose_globals()
		for side30: String in ["l","r"]: foot_targets30[side30] = _rig.to_global(_pose._point("foot_"+side30))
	if not value.is_empty(): selected = _pose.compose(selected,value)
	# Sole fixture skeleton commit, identical composition order to the production host.
	if selected.get("valid",false):
		for bone: int in selected.poses.size(): _rig.set_bone_pose(bone,selected.poses[bone])
		_motion.position = selected.visual_offset
		if not value.is_empty(): Pose.committed(_rig,value)
	for side30: String in foot_targets30:
		var actual30: Vector3 = _rig.to_global(_rig.get_bone_global_pose(_rig.find_bone("foot_"+side30)).origin)
		_max_foot_error30 = maxf(_max_foot_error30,actual30.distance_to(foot_targets30[side30]))
		if _pose.get("_bench_feet30") is Dictionary:
			var start30: Transform3D = _pose._bench_start30[side30]
			var expected30: Vector3 = _rig.to_global(start30.origin.lerp(_pose._bench_feet30[side30],float(value.get("pose_weight",0))))
			_max_bench_contact_error30 = maxf(_max_bench_contact_error30,actual30.distance_to(expected30))
		if float(value.get("pose_weight",0)) > .999 and value.get("seat") is Vector3:
			var hips30: Vector3 = _rig.to_global((_rig.get_bone_global_pose(_rig.find_bone("thigh_l")).origin+_rig.get_bone_global_pose(_rig.find_bone("thigh_r")).origin)*.5)
			_max_dock_error30 = maxf(_max_dock_error30,hips30.distance_to(Vector3(value.seat)+Vector3.UP*.10))
	_max_body_step30 = maxf(_max_body_step30,measured.length())
	var state: Dictionary = _ambient.snapshot()
	if state.phase == "ACTING" and int(state.pose_frames) >= 8:
		for view: String in (["front","side","hands","screen"] if state.kind == "phone" else ["front","side","hands"]):
			var at: float = {"front":1.2,"side":2.2,"hands":3.2,"screen":3.6}[view]
			if float(state.elapsed_s) >= at and not _captures.has(view) and not _capture_busy:
				_captures[view] = true; _capture_busy = true; _camera_view(view); _capture.call_deferred(state.kind,view,state.duplicate(true)); break
	if Time.get_ticks_msec()-_last_sample >= 250:
		_last_sample = Time.get_ticks_msec()
		_rows.append({"event":"sample","stage":_stage,"position":_body.global_position,"floor":_body.is_on_floor(),"ambient":state,"pose_weight":value.get("pose_weight",0),"visible_props":_visible_props()})

func _visible_props() -> int:
	var total := 0
	for node: Node in _rig.get_children():
		if node is BoneAttachment3D and node.get_meta("ambient_prop28",false) and node.is_visible_in_tree(): total += 1
	return total

func _camera_view(view: String) -> void:
	var forward: Vector3 = -_body.global_basis.z
	var side: Vector3 = _body.global_basis.x
	var offset: Vector3 = forward*3.8 + side*1.8 + Vector3.UP*2.1
	var target: Vector3 = _body.global_position + Vector3.UP*.95
	if view == "front": offset = forward*3.4 + Vector3.UP*1.5
	if view == "side": offset = side*3.6 + Vector3.UP*1.6
	if view == "hands": offset = forward*1.8 + side*.6 + Vector3.UP*1.65; target = _body.global_position + Vector3.UP*1.35
	if view == "screen": offset = -forward*.65+side*.65+Vector3.UP*1.9; target = _body.global_position+Vector3.UP*1.0+forward*.3
	_camera.global_position = _body.global_position+offset; _camera.look_at(target)

func _capture(kind: String, view: String, observed: Dictionary) -> void:
	if DisplayServer.get_name() == "headless": _capture_busy = false; return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result: int = image.save_png(_out.path_join("%02d_%s_%s.png" % [_index,kind,view]))
	_rows.append({"event":"capture","kind":kind,"view":view,"write_error":result,"observed":observed,"visual_acceptance":"PENDING_REVIEW"})
	_capture_busy = false

func _finish(reason: String) -> void:
	_stage = "DONE"; set_physics_process(false)
	if _ambient != null: _ambient.cancel("fixture_end")
	if _max_bench_contact_error30 > .01: _failures.append({"reason":"bench_foot_target_error","metres":_max_bench_contact_error30})
	if _max_dock_error30 > .01: _failures.append({"reason":"bench_hip_dock_error","metres":_max_dock_error30})
	for check30: String in _checks:
		if not _checks[check30]: _failures.append({"reason":check30})
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
		var file := FileAccess.open(_out.path_join("AMBIENT_FIXTURE29.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify({"reason":reason,"fixture_only":true,"city_acceptance":false,"visual_acceptance":"PENDING_REVIEW","rig_report30":_rig_report30,"max_bench_contact_error30":_max_bench_contact_error30,"max_dock_error30":_max_dock_error30,"max_foot_error30":_max_foot_error30,"max_body_step30":_max_body_step30,"requested_kinds30":_requested_kinds30,"checks":_checks,"cancel_phase":_cancel_phase,"cancelled":_cancelled,"failures":_failures,"rows":_rows},"\t")); file.close()
	print("AMBIENT_FIXTURE29_FINISH ",reason," failures=",_failures.size())
	get_tree().quit(0 if reason == "bounded_fixture_complete" and _failures.is_empty() and (_cancel_phase.is_empty() or _cancelled) else 1)
