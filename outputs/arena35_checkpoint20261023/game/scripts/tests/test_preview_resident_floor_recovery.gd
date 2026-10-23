extends SceneTree
const Host = preload("res://scripts/npc_visual/preview_resident_host.gd")
const Policy = preload("res://scripts/npc_visual/preview_resident_world_policy.gd")
const Nav = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Population = preload("res://scripts/preview_population.gd")
const PACKET := "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"
const PREPARED := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
const BLOCK := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const DIR := "res://assets/npc_visual/session/"
const GOALS := [Vector3(23,0,-18.185243078735144),Vector3(26.946139561350435,0,-28.6),Vector3(24.6,0,-4.8),Vector3(6.4,0,5.6494467601998295)]
const ANCHORS := ["REBUILD-VISUAL-old_town_narrow_townhouse_v1-005","REBUILD-VISUAL-old_town_narrow_townhouse_v1-004","LAMP-9-102","REBUILD-VISUAL-print_shop-001"]
var output := ""
var errors: Array = []
var reports: Array = []
var times: Array = []
var scene: Node3D
var host: RefCounted
var nav: RefCounted
var policy: RefCounted
var queue: RefCounted
var started := 0
func v(p: Vector3) -> Array: return [p.x,p.y,p.z]
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	run.call_deferred()
func setup() -> bool:
	var bytes := FileAccess.get_file_as_bytes(DIR+PACKET+".json")
	var packet: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	var owners := {}; var states := {}; var sources := {}
	for r: Dictionary in packet.rows: owners[r.source_id] = Queue.Owner.new(r.source_id,1); states[r.source_id] = "ordinary_outdoor"
	for r: Dictionary in packet.source_receipts: sources[r.path] = r.sha256
	var trust := {"accepted":true,"packet_sha256":PACKET,"prepared_sha256":PREPARED,"block_sha256":BLOCK,"session_id":packet.session_id,"sources":sources}
	policy = Policy.new(); queue = Queue.new(); nav = Nav.new(); host = Host.new()
	var p: Dictionary=policy.configure(scene,packet.rows,owners,trust,{"version":1,"states":states})
	if not p.get("ok",false): print("POLICY ",p); return false
	if not nav.attach_existing(scene,scene.get("_printshop"),scene.get("_block"),scene.get("_printshop_data"),queue,packet.session_id,1,1): print("NAV ",nav.diagnostics()); return false
	var h: Dictionary=host.configure(scene,nav,bytes,trust,FileAccess.get_file_as_bytes(DIR+"prepared/manifest.json"),DIR+"prepared",owners,Callable(policy,"source_admit"),Callable(policy,"support_height"))
	if not h.get("ok",false): print("HOST ",h); return false
	for id: String in Population.PREVIEW_STAGES:
		var stage: Vector2 = Population.PREVIEW_STAGES[id]
		var a: Dictionary=host.admit_preview_stage(id,stage.y,stage.x)
		if a.status != "IDLE": print("STAGE ",id," ",a); return false
	return true

var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: errors.append(label);print("FAIL ",label)
func test_case(kind: String) -> void:
	if not setup():errors.append("setup:"+kind);return
	await physics_frame;await physics_frame
	var record: Dictionary=host._records.resident_169
	var body: CharacterBody3D=record.body
	var origin:=body.global_position
	# Explicit adversarial fixture starts slightly intersecting existing floor.
	# Production correction never sets position and never disables a collider.
	body.global_position=origin+Vector3.DOWN*(.07 if kind=="deep" else .02)
	var blocker: StaticBody3D
	if kind=="wall":
		blocker=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(.3,3,1);shape.shape=box;blocker.add_child(shape);scene.add_child(blocker)
		blocker.global_position=origin+Vector3(.30,1.0,0)
	if kind=="deny":check(policy.update_access(2,{"resident_169":"deny"}),"deny access applied")
	if kind=="dead_owner": record.owner.dead=true
	if kind=="failed_physics": record.physical_failed=true
	if kind=="ascending":body.velocity=Vector3.UP
	if kind=="filter_changed":body.collision_mask=0
	if kind=="occupied":host._records.resident_72.body.global_position=origin+Vector3(.9,0,0)
	if kind.begins_with("callback_"):
		host._admit=func(_p,_id,_gen,_footprint,_purpose):
			if kind=="callback_upward": body.velocity=Vector3.UP
			if kind=="callback_margin": body.safe_margin=.1
			if kind=="callback_snap": body.floor_snap_length=100
			if kind=="callback_filter": body.collision_mask=0
			if kind=="callback_failed": record.physical_failed=true
			if kind=="callback_queued": body.queue_free()
			if kind=="callback_dead": record.owner.dead=true
			return true
	await physics_frame
	var before:=body.global_transform
	var begin:=Time.get_ticks_usec()
	var applied: bool=host._recover_floor_contact(record)
	var cost:=Time.get_ticks_usec()-begin
	if kind=="clear":
		check(applied,"clear applies native recovery")
		check(body.global_position.y>=origin.y-.001 and body.global_position.y<origin.y+.005,"floor recovered within margin")
		check(Vector2(body.global_position.x-origin.x,body.global_position.z-origin.z).length()<.0001,"no horizontal move")
		var excluded: Array[RID]=[body.get_rid()]
		check(host._physical_clear(body.global_position,excluded),"unchanged full footprint clear")
	else:
		check(not applied,kind+" refuses")
		check(body.global_transform==before,kind+" leaves pose untouched")
	print("CASE ",JSON.stringify({"kind":kind,"applied":applied,"before":str(before.origin),"after":str(body.global_position),"cost_us":cost}))
	if blocker!=null:blocker.free()
	host.dispose();nav.dispose();policy.dispose();queue.dispose();await physics_frame;await physics_frame
func test_step_callback(kind: String) -> void:
	if not setup(): errors.append("setup:"+kind); return
	await physics_frame; await physics_frame
	var record: Dictionary=host._records.resident_169
	var body: CharacterBody3D=record.body
	body.global_position+=Vector3.DOWN*.02
	await physics_frame
	var before:=body.global_transform
	var body_ref: WeakRef=weakref(body)
	host._admit=func(_p,id,_gen,_footprint,_purpose):
		if id!="resident_169": return true
		var target: CharacterBody3D=body_ref.get_ref()
		if kind=="step_free": target.free()
		if kind=="step_queued": target.queue_free()
		if kind=="step_dead": record.owner.dead=true
		if kind=="step_dispose": host.dispose()
		return true
	host.step(1.0/60.0)
	if kind=="step_free": check(not is_instance_valid(body),"step callback freed body safely")
	if kind=="step_queued": check(body.is_queued_for_deletion() and body.global_transform==before,"step callback queued body untouched")
	if kind=="step_dead": check(record.owner.dead and body.global_transform==before,"step callback dead body untouched")
	if kind=="step_dispose": check(host._disposed,"step callback deferred disposal completed")
	host.dispose();nav.dispose();policy.dispose();queue.dispose();await physics_frame;await physics_frame

func run() -> void:
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_transport_enabled=false;scene.preview_start_at_vehicle=false;scene.preview_residents_enabled=false
	root.add_child(scene);await physics_frame;await physics_frame
	scene.set_process(false);scene.set_physics_process(false);scene._player.set_physics_process(false)
	for kind: String in ["clear","deep","wall","deny","dead_owner","failed_physics","ascending","filter_changed","occupied","callback_filter","callback_failed","callback_queued","callback_dead","callback_upward","callback_margin","callback_snap"]:await test_case(kind)
	for kind: String in ["step_free","step_queued","step_dead","step_dispose"]: await test_step_callback(kind)
	print(JSON.stringify({"checks":checks,"errors":errors,"scope":"actual source-policy/rig/floor with explicit adversarial pose fixtures; not LIVE"}))
	scene.free();quit(0 if errors.is_empty() else 1)
