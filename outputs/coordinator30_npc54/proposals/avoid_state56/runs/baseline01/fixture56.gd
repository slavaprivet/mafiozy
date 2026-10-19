extends SceneTree
const Core=preload("res://scripts/navigation/npc_local_avoidance29.gd")
const Simple=preload("res://scripts/hospital/npc_simple_hospital.gd")
class FixtureScene extends Node3D:
	var _origin:=Vector3(128,0,128)
	var _block: Dictionary={}
	var _player: Node3D
var out:=""
var baseline:=false
var checks: Dictionary={}
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg=="--qa-baseline":baseline=true
	var scene:=FixtureScene.new();root.add_child(scene);current_scene=scene
	var grid: Array=[]
	for r: int in 32:
		var row: Array=[];row.resize(32);row.fill(0);grid.append(row)
	scene._block={"surface":{"cellSize":8.0,"startCol":0,"startRow":0,"grid":grid,"palette":{"0":{"kind":"grass","solid":true,"heightM":0.0}}}}
	var floor_body:=StaticBody3D.new();var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(256,1,256);floor_shape.shape=box;floor_body.add_child(floor_shape);scene.add_child(floor_body);floor_body.position.y=-.5
	var body:=CharacterBody3D.new();var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7;shape.shape=capsule;shape.position.y=.85;body.add_child(shape);scene.add_child(body);body.position=Vector3(0,.003,0)
	await physics_frame
	var drive:=Simple.new();checks.native_first_begin=drive.begin(Vector3(10,.003,0),body,RID(),"fixture","roam")
	var core:=Core.new();var inputs: Array=[]
	for i: int in 287:
		var input:=Core.FrameInput.new();input.key="fixture_"+str(i);input.position=Vector3(i*4,0,0);input.velocity=Vector3.ZERO;inputs.append(input)
	checks.all287_core_members=core.snapshot(inputs,1,1000) and core._rows.size()==287
	# This is the exact production assignment, retaining the core-owned Dictionary.
	drive._avoidance29_state=core.steer("fixture_0",Vector3.RIGHT,1.8)
	var shared: Dictionary=drive._avoidance29_state
	checks.first_output_complete=shared.has_all(["direction","ratio","waiting","reason","replan"])
	checks.native_repeated_begin=drive.begin(Vector3(12,.003,0),body,RID(),"fixture","roam")
	checks.begin_reproduces_or_preserves_core_output=shared.is_empty() if baseline else shared.has_all(["direction","ratio","waiting","reason","replan"])
	# Exercise the actual cached path; no decision recomputes the missing fields.
	var cached: Dictionary=core.steer("fixture_0",Vector3.RIGHT,1.8)
	checks.cached_path_reproduces_or_preserves_contract=(not cached.has("waiting") and not cached.has("ratio")) if baseline else cached.has_all(["direction","ratio","waiting","reason","replan"])
	checks.core_output_remains_shared=is_same(cached,shared)
	if not baseline:
		checks.caller_owns_new_empty_value=drive._avoidance29_state.is_empty() and not is_same(drive._avoidance29_state,shared)
		checks.no_decision_or_budget_change=core.diagnostics().decisions==1 and core.diagnostics().max_decisions==16
	drive.cancel();scene.queue_free();await process_frame;await process_frame
	var passed:=true
	for value: bool in checks.values():passed=passed and value
	var result: Dictionary={"passed":passed,"baseline_bug_reproduction":baseline,"checks":checks,"scope":"native Simple repeated begin plus actual Core 287-member cached output contract; not a city performance test","performance_accepted":false}
	var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("AVOID_STATE56 ",JSON.stringify(result));quit(0 if passed else 1)
