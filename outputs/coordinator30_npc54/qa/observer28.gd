extends Node
var _last := 0
var _started := 0
var _ready_ms := 0
var _duration := 100
var _out := ""
var _rows: Array = []
var _inventory: Array = []
var _visual: Node
var _door_observer: Node
var _follow := false
var _camera: Camera3D
var _follow_body: CharacterBody3D
var _hospital_state := ""
var _captured: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 1000
	_started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-duration="): _duration = int(arg.trim_prefix("--qa-duration="))
		if arg.begins_with("--qa-out="): _out = arg.trim_prefix("--qa-out=")
		if arg == "--qa-follow-camera=1": _follow = true
	var path: String = get_script().resource_path.get_base_dir().path_join("visual_observer.gd")
	_visual = load(path).new()
	_visual.output_path = _out.path_join("visual.json")
	add_child(_visual)
	var door_script: String = get_script().resource_path.get_base_dir().get_base_dir().path_join("proposals/doors/qa/clone_door52_observer.gd")
	_door_observer = load(door_script).new()
	add_child(_door_observer)
	_door_observer.configure(get_tree().current_scene, _out.path_join("door.json"), "TownClone_1")
	if _follow:
		_camera=Camera3D.new()
		_camera.fov=65.0
		add_child(_camera)
		_camera.current=true

func _process(_delta: float) -> void:
	if not _follow or not is_instance_valid(_follow_body):return
	var offset:=Vector3(2.0,1.8,1.2) if _hospital_state=="TREATING" else Vector3(-3.0,2.8,4.0)
	_camera.global_position=_follow_body.global_position+offset
	_camera.look_at(_follow_body.global_position+Vector3.UP*1.15)

func _physics_process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last < 1000: return
	_last = now
	var scene: Node3D = get_tree().current_scene
	var pop: Variant = scene.get("preview_population")
	if pop == null or not bool(pop.get("city_ready")):
		if now - _started > 90000: _finish("bootstrap_timeout")
		return
	if _ready_ms == 0: _ready_ms = now; _collect(scene)
	var daily: Variant = pop.get("daily")
	if daily == null: return
	var life: Variant = daily.get("_lives").get("resident_1")
	if life == null: return
	var body: CharacterBody3D = life.get("_token").get("body")
	_follow_body=body
	_hospital_state=str(life.get("_hospital_stage"))
	var row: Dictionary = {"ms":now,"ready_ms":now-_ready_ms,"position":body.global_position,"on_floor":body.is_on_floor(),"velocity":body.velocity,"hp":life._life().get("hp"),"max_hp":life._life().get("max_hp"),"energy":life.get("_energy"),"phase":life.get("_phase"),"hospital":life.get("_hospital_stage"),"queue":life.get("_dsh_task_queue"),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
	var mover: Variant = life.get("_dsh_simple")
	row["restaurant"]=life.get("_restaurant28_stage")
	row["treatment_pose"]=body.get_meta("npc_treatment28",{})
	var restaurant: Variant=life.get("_restaurant28")
	if restaurant!=null:row["restaurant_route"]=restaurant.snapshot()
	var economy: Variant=life.get("_economy28")
	if economy!=null:row["economy"]=economy.snapshot()
	var ambient: Variant=life.get("_ambient29")
	if ambient!=null:row["ambient"]=ambient.snapshot()
	row["account"]=life.get("_account").snapshot()
	if mover != null and not mover.has_method("active"):
		row["hospital_route29"] = mover.snapshot()
		mover = mover.get("_drive")
	if mover == null or not mover.active(): mover = life.get("_roam51")
	if mover != null:
		var route: Variant = mover.get("_route")
		row["nav"] = {"phase":mover.phase(),"target":mover.target(),"reason":mover.last_reason(),"leg":mover.get("_leg"),"legs":mover.get("_legs"),"door":mover.get("_door"),"inside_normal":mover.get("_inside_normal"),"moved_m":mover.moved_m()}
		if route != null:
			row.nav["route"] = {"status":route.get("status"),"expanded":route.get("expanded"),"queries":route.get("queries"),"open":route.get("_open").size(),"goal":route.get("goal")}
	_rows.append(row.duplicate(true))
	if _follow:
		var capture_key: String=_hospital_state if not _hospital_state.is_empty() else str(life.get("_restaurant28_stage"))
		if capture_key.is_empty():capture_key=str(life.get("_phase"))
		if not _captured.has(capture_key):
			_captured[capture_key]=true
			_capture.call_deferred(capture_key)
	print("QA28 ",JSON.stringify(row))
	if now-_ready_ms >= _duration*1000: _finish("bounded_observation_complete")

func _collect(scene: Node) -> void:
	for clone: Node in scene.get_children():
		if not str(clone.name).begins_with("TownClone_"): continue
		var stack: Array[Node] = [clone]
		var entrances: Array = []
		var count := 0
		while not stack.is_empty():
			var part: Node = stack.pop_back()
			count += 1
			if str(part.name).begins_with("Entrance") and part is CollisionObject3D:
				entrances.append({"path":str(part.get_path()),"position":part.global_position,"layer":part.collision_layer,"basis":str(part.global_basis),"shape_count":part.get_child_count()})
			for child: Node in part.get_children(): stack.append(child)
		_inventory.append({"clone":str(clone.name),"nodes":count,"entrances":entrances,"children":clone.get_children().map(func(n: Node): return str(n.name))})
	print("QA28_INVENTORY ",JSON.stringify(_inventory))

func _capture(label: String) -> void:
	await _visual.capture_png(_out.path_join(label+".png"))

func _finish(reason: String) -> void:
	set_physics_process(false)
	_visual.save()
	_door_observer.save()
	var file := FileAccess.open(_out.path_join("OBSERVATION.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"reason":reason,"inventory":_inventory,"samples":_rows},"\t"));file.close()
	print("QA28_FINISH ",reason)
	get_tree().quit()
