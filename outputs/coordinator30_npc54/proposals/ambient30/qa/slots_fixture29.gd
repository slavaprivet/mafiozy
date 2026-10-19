extends Node3D
## Registry contract fixture. Two plain physical capsules, zero resident lives/rigs.
## Deadline fields are expired explicitly for deterministic branch coverage, not timing.
const Registry = preload("res://scripts/npc_ambient/ambient_bench_registry29.gd")
class Claimant extends RefCounted:
	var alive := true
	var lease: Dictionary = {}
	var registry: Node
	var body: CharacterBody3D
	var cancelled := ""
	func bench_slot_living29(serial: int) -> bool:
		return alive and int(lease.get("serial",-1)) == serial
	func cancel(reason: String) -> void:
		cancelled = reason
		registry.release(lease,self,body)
		lease = {}
var _registry: Node
var _a: CharacterBody3D
var _b: CharacterBody3D
var _owner_a: Claimant
var _owner_b: Claimant
var _bench: Node3D
var _checks: Array = []
var _frame := 0
var _out := ""
var _stage := 0

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): _out = arg.trim_prefix("--qa-out=")
	var floor := StaticBody3D.new(); add_child(floor)
	var floor_shape := CollisionShape3D.new(); var floor_box := BoxShape3D.new(); floor_box.size = Vector3(20,.2,20); floor_shape.shape = floor_box; floor_shape.position.y = -.1; floor.add_child(floor_shape)
	_bench = _make_bench(Vector3.ZERO)
	_registry = Registry.for_scene(self)
	_a = _capsule(Vector3(0,.003,.72)); _b = _capsule(Vector3(3,.003,2))
	_owner_a = Claimant.new(); _owner_a.registry = _registry; _owner_a.body = _a
	_owner_b = Claimant.new(); _owner_b.registry = _registry; _owner_b.body = _b

func _make_bench(at: Vector3) -> Node3D:
	var bench := Node3D.new(); bench.name = "OriginalBenchFixture"; bench.position = at; bench.set_meta("palazzo_bench",true); add_child(bench)
	var boxes: Array = []
	for z: float in [-.16,.04,.24]: boxes.append([Vector3(1.7,.1,.15),Vector3(0,.43,z)])
	for x: float in [-.64,.64]: boxes.append([Vector3(.09,.47,.48),Vector3(x,.22,.02)])
	boxes.append([Vector3(1.7,.34,.1),Vector3(0,.83,-.22)])
	for pair: Array in boxes:
		var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = pair[0]; mesh.mesh = box; mesh.position = pair[1]; mesh.set_meta("box_size",pair[0]); bench.add_child(mesh)
	return bench

func _capsule(at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new(); body.position = at; body.collision_layer = 1; body.collision_mask = 1; body.floor_snap_length = .25
	var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = 1.9; shape.shape = capsule; shape.position.y = .95; body.add_child(shape); add_child(body)
	return body

func _check(label: String, passed: bool) -> void:
	_checks.append({"case":label,"pass":passed})
	print("BENCH_SLOTS29 ",label," ",passed)

func _physics_process(delta: float) -> void:
	_frame += 1
	for body: CharacterBody3D in [_a,_b]:
		body.velocity = Vector3(0,-2,0); body.move_and_slide()
	if _frame > 300: _check("bounded",false); _finish(); return
	if _frame < 8: return
	if _stage == 0:
		_check("both_full_capsules_on_real_floor",_a.is_on_floor() and _b.is_on_floor())
		var shared := true
		for caller: int in 286: shared = shared and Registry.for_scene(self) == _registry
		_check("286_logical_lookups_one_inventory_scan",shared and int(_registry.snapshot().scene_scans) == 1)
		_check("one_support_six_shapes",_bench.get_node("AmbientBenchSupport28").get_child_count() == 6 and _registry.rows().size() == 1)
		var row: Dictionary = _registry.rows()[0]
		_owner_a.lease = _registry.claim(row,_owner_a,_a,1)
		_check("first_claim",not _owner_a.lease.is_empty())
		_check("second_owner_refused",_registry.claim(row,_owner_b,_b,1).is_empty())
		_registry.release(_owner_a.lease,_owner_b,_b)
		_check("foreign_release_refused",_registry.matches(_owner_a.lease,_owner_a,_a))
		var old: Dictionary = _owner_a.lease.duplicate()
		_registry.get("_claims")[int(row.bench_id)].heartbeat_deadline = Time.get_ticks_msec()-1
		_owner_b.lease = _registry.claim(row,_owner_b,_b,1)
		_check("expired_approach_cancelled_then_claimed",_owner_a.cancelled == "bench_approach_lease_expired" and not _owner_b.lease.is_empty())
		_registry.release(old,_owner_a,_a)
		_check("stale_serial_cannot_release_successor",_registry.matches(_owner_b.lease,_owner_b,_b))
		_owner_b.cancel("fixture_release")
		_owner_a.cancelled = ""; _owner_a.lease = _registry.claim(row,_owner_a,_a,2)
		_check("occupy_at_actual_supported_dock",_registry.occupy(_owner_a.lease,_owner_a,_a,_a.global_position))
		_registry.get("_claims")[int(row.bench_id)].heartbeat_deadline = Time.get_ticks_msec()-100000
		_registry.get("_claims")[int(row.bench_id)].approach_deadline = Time.get_ticks_msec()-100000
		_check("occupied_live_actor_ignores_time_expiry",_registry.claim(row,_owner_b,_b,2).is_empty() and _registry.renew(_owner_a.lease,_owner_a,_a))
		_owner_a.alive = false
		_owner_b.lease = _registry.claim(row,_owner_b,_b,2)
		_check("stale_life_cancelled_immediately",_owner_a.cancelled == "bench_life_stale" and not _owner_b.lease.is_empty())
		# A slot is never physical permission: the previous capsule still blocks this point.
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = (_b.get_child(0) as CollisionShape3D).shape; query.transform = Transform3D(Basis.IDENTITY,_a.global_position+Vector3.UP*.975); query.exclude = [_b.get_rid()]; query.collision_mask = 1
		var blocked := false
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query):
			if hit.get("collider") == _a: blocked = true
		_check("lease_does_not_bypass_other_capsule",blocked)
		_bench.queue_free(); _stage = 1
	elif _stage == 1:
		if is_instance_valid(_bench): return
		# Godot may emit the support child's tree_exiting before its parent.
		# Both events must cancel the same claim synchronously and empty inventory.
		_checks.append({"observation":"bench_removal_reason","reason":_owner_b.cancelled,"claims":int(_registry.snapshot().claims),"rows":_registry.rows().size()})
		_check("bench_removal_cancels_owner_and_claim",_owner_b.cancelled in ["bench_removed","support_removed"] and int(_registry.snapshot().claims) == 0 and _registry.rows().is_empty())
		_bench = _make_bench(Vector3(-4,0,0)); _stage = 2
	elif _stage == 2:
		if _registry.rows().is_empty(): return
		_check("new_bench_added_without_rescan",_registry.rows().size() == 1 and int(_registry.snapshot().scene_scans) == 1)
		_owner_b.lease = _registry.claim(_registry.rows()[0],_owner_b,_b,3)
		_bench.get_node("AmbientBenchSupport28").queue_free(); _stage = 3
	elif _stage == 3:
		if int(_registry.snapshot().claims) > 0: return
		_check("support_removal_cancels_owner",_owner_b.cancelled == "support_removed")
		_finish()

func _finish() -> void:
	set_physics_process(false)
	var passed := true
	for check: Dictionary in _checks:
		if check.has("pass"): passed = passed and bool(check["pass"])
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
		var file := FileAccess.open(_out.path_join("BENCH_SLOTS29.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify({"fixture_only":true,"resident_lives":0,"plain_capsule_bodies":2,"logical_inventory_lookups":286,"forced_deadline_branch_tests":true,"native_clock_performance_claim":false,"pass":passed,"checks":_checks},"\t")); file.close()
	get_tree().quit(0 if passed else 1)
