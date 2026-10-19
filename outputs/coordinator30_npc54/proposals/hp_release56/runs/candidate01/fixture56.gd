extends SceneTree
const Diag = preload("res://scripts/npc_visual/npc_resident_diag.gd")
const Focus = preload("res://scripts/npc_visual/npc_resident_focus29.gd")
const Life = preload("res://scripts/npc_daily_life.gd")
var out := ""
var checks: Array[String]=[]
var failures: Array[String]=[]
var evidence: Dictionary={}
class FixtureScene extends Node3D:
	var _player: Node3D
class FixtureLife extends RefCounted:
	var _token: Dictionary
	var row: Dictionary
	var reads := 0
	var live := true
	func _life() -> Dictionary:reads+=1;return row if live else {}
class TrapWalk extends RefCounted:
	var snapshots := 0
	func snapshot() -> Dictionary:snapshots+=1;return {}
func check(value: bool,label: String) -> void:
	checks.append(label)
	if not value:failures.append(label)
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var marker := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-ready="):marker=arg.trim_prefix("--qa-ready=")
	var deadline: int=Time.get_ticks_msec()+30000
	while not marker.is_empty() and not FileAccess.file_exists(marker):
		if Time.get_ticks_msec()>deadline:quit(2);return
		await create_timer(.05).timeout
	create_timer(25.0).timeout.connect(func():check(false,"bounded component deadline");finish())
	await fixture()
	finish()
func aim(scene: Node3D,camera: Camera3D,body: Node3D) -> void:
	var player: Node3D=scene.get("_player")
	player.global_position=body.global_position+Vector3(0,0,-1.1)
	camera.global_position=body.global_position+Vector3(0,1.0,-1.5);camera.look_at(body.global_position+Vector3.UP)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await physics_frame;await process_frame
	Focus._frame=-1
	if DisplayServer.get_name()=="headless":
		# Dummy display has no captured cursor: issue the same centre ray natively.
		var q:=PhysicsRayQueryParameters3D.create(camera.global_position,body.global_position+Vector3.UP)
		if player is CollisionObject3D:q.exclude=[player.get_rid()]
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(q)
		Focus._frame=Engine.get_physics_frames();Focus._scene_id=scene.get_instance_id();Focus._player_position=player.global_position;Focus._hit=weakref(hit.collider) if hit.get("collider") is Node else null
		evidence.headless_native_center_ray_adapter=true
func fixture() -> void:
	var scene:=FixtureScene.new();root.add_child(scene);current_scene=scene
	scene._player=Node3D.new();scene.add_child(scene._player)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var bodies: Array[CharacterBody3D]=[];var lives: Array[FixtureLife]=[]
	for i: int in 287:
		var body:=CharacterBody3D.new();scene.add_child(body);body.position=Vector3(i*3.5,0,0);body.set_meta("source_id","fixture_"+str(i));body.collision_layer=1
		var shape:=CollisionShape3D.new();shape.shape=CapsuleShape3D.new();shape.shape.radius=.36;shape.shape.height=1.9;shape.position.y=.95;body.add_child(shape)
		var life:=FixtureLife.new();life._token={"body":body,"source_id":"fixture_"+str(i),"life_generation":1,"session_id":"fixture"};life.row={"source_id":"fixture_"+str(i),"life_generation":1,"hp":60.0,"max_hp":60.0,"dead":false}
		Diag.register_life(life._token.source_id,life);bodies.append(body);lives.append(life)
	await aim(scene,camera,bodies[286])
	check(Focus.focused(bodies[286]),"real native ray focuses final member of287")
	var pre: Dictionary=Diag.hp_fast_state30();var since: int=Time.get_ticks_usec()
	for i: int in 286:Diag.repaint_focus30(bodies[i])
	evidence.hidden286_us=Time.get_ticks_usec()-since
	check(Diag.hp_fast_state30().current_reads==pre.current_reads,"286 hidden bodies perform no authority reads")
	check(Diag._labels.is_empty() and not scene.has_meta(Focus.CanvasCard.META),"hidden bodies create no label or canvas")
	var actual_life:=Life.new();actual_life._token={"body":bodies[0]};var trap:=TrapWalk.new();actual_life._walk=trap
	actual_life._dsh_resdiag_step(lives[0].row);actual_life.dsh_repaint_caption()
	check(trap.snapshots==0,"hidden production life path performs zero walk snapshots")
	actual_life._walk=null
	Diag.repaint_focus30(bodies[286]);var label: Label3D=Diag._cached_label30(bodies[286])
	check(label!=null and label.visible and label.get_meta("card30_source_id")=="fixture_286","original final identity gets its own focused card")
	if label==null:return
	check(label.get_meta("hp")==60.0,"current full health painted")
	lives[286].row.hp=19.0;Diag.refresh_after_hit(bodies[286],"",{})
	check(label.get_meta("hp")==19.0 and label.get_meta("card29_health_text")=="Здоровье  19 / 60","same-frame hit paints exact current HP")
	lives[286].row.hp=60.0;Diag.repaint_focus30(bodies[286])
	check(label.get_meta("hp")==60.0 and label.modulate==Diag.SIMPLE_ACCENT28,"same-frame healing restores number and green")
	lives[286].row.life_generation=2;Diag.repaint_focus30(bodies[286]);check(not label.visible,"same-frame generation mismatch hides old card")
	lives[286].row.life_generation=1;Diag.repaint_focus30(bodies[286]);lives[286].live=false;Diag.repaint_focus30(bodies[286]);check(not label.visible,"authority failure hides card without stale fallback")
	lives[286].live=true;Diag.repaint_focus30(bodies[286]);lives[286].row.dead=true;Diag.repaint_focus30(bodies[286]);check(not label.visible,"same-frame death hides card")
	lives[286].row.dead=false;Diag.repaint_focus30(bodies[286])
	await aim(scene,camera,bodies[1]);Diag.repaint_focus30(bodies[1]);check(not label.visible,"new focus releases old card immediately")
	var label1: Label3D=Diag._cached_label30(bodies[1]);check(label1!=null and label1.visible,"second original identity gets card")
	Diag.unregister_life30("fixture_1",lives[1]);check(not label1.visible and Diag.life_of("fixture_1")==null,"dispose removes registration and releases visible canvas")
	# Look-away must release the tracked ordinary card in the same call.
	await aim(scene,camera,bodies[286]);Diag.repaint_focus30(bodies[286])
	await aim(scene,camera,bodies[2]);Diag.repaint_focus30(bodies[286])
	check(not label.visible and Diag._focused_body30==null,"ordinary look-away releases tracked card immediately")
	# Diagnostic update is a separate legacy writer and does not own _focused_body30.
	Diag._diag_flag=1
	Diag.update("fixture_2",bodies[2],lives[2].row,{}, {},"Resident")
	var legacy: Label3D=Diag._cached_label30(bodies[2])
	check(legacy!=null and legacy.visible and Diag._focused_body30==null,"legacy diagnostic update creates an untracked visible card")
	await aim(scene,camera,bodies[3]);Diag.repaint_focus30(bodies[2])
	check(legacy!=null and not legacy.visible,"diagnostic look-away still releases untracked card")
	Diag._diag_flag=0
	# Retirement cleanup must not depend on the ordinary focus pointer.
	await aim(scene,camera,bodies[4]);Diag._diag_flag=1
	Diag.update("fixture_4",bodies[4],lives[4].row,{}, {},"Resident")
	var queued_label: Label3D=Diag._cached_label30(bodies[4]);Diag._diag_flag=0
	bodies[4].queue_free();Diag.repaint_focus30(bodies[4])
	check(queued_label!=null and not queued_label.visible,"queued untracked body releases its label before deletion")
	Diag.unregister_life30("fixture_4",lives[4])
	check(not Diag._labels.has(str(bodies[4].get_instance_id())),"unregister removes retired unfocused cache")
	await aim(scene,camera,bodies[5]);Diag._diag_flag=1
	Diag.update("fixture_5",bodies[5],lives[5].row,{}, {},"Resident")
	var detached_label: Label3D=Diag._cached_label30(bodies[5]);Diag._diag_flag=0
	scene.remove_child(bodies[5]);Diag.repaint_focus30(bodies[5])
	check(detached_label!=null and not detached_label.visible,"detached untracked body releases its label")
	scene.add_child(bodies[5])
	var successor:=FixtureLife.new();successor._token=lives[286]._token.duplicate();successor._token.body=bodies[2];successor.row=lives[286].row.duplicate()
	Diag.register_life("fixture_286",successor);Diag.unregister_life30("fixture_286",lives[286]);check(Diag.life_of("fixture_286")==successor,"late old-life cleanup cannot erase successor")
	Diag.unregister_life30("fixture_286",successor)
	for i: int in 287:Diag.unregister_life30(str(lives[i]._token.source_id),lives[i])
	bodies[1].queue_free();await process_frame;Diag.repaint_focus30(bodies[1]);check(true,"freed body call is harmless")
	scene.queue_free();await process_frame;await process_frame
	check(Diag._labels.is_empty() and Diag._lives.is_empty(),"all287 registrations/label caches released")
	evidence.fixture=Diag.hp_fast_state30()
func finish() -> void:
	var result: Dictionary={"ok":failures.is_empty(),"checks":checks,"failures":failures,"evidence":evidence,"performance_accepted":false,"scope":"native focus/label lifecycle; HP rows controlled by fixture, no combat/city claim"}
	var f:=FileAccess.open(out.path_join("HP_RELEASE56.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close();print("HP_RELEASE56 ",result.ok," checks=",checks.size());quit(0 if result.ok else 1)
