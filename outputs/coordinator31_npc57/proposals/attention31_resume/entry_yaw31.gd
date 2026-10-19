extends SceneTree
class World extends Node3D:
	var _origin:=Vector3.ZERO
	var _block: Dictionary={"surface":{"grid":[[1,1],[1,1]],"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":0,"startRow":0}}
var out:=""
var candidate:=false
var scripts: Array=[]
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg=="--candidate31=1":candidate=true
	var here: String=get_script().resource_path.get_base_dir()
	if candidate:
		var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(here.path_join("patch_yaw31/scripts/city/runtime/npc_threat_life30.gd"));script.take_over_path("res://scripts/city/runtime/npc_threat_life30.gd")
		assert(script.reload()==OK);scripts.append(script)
	var Threat: Script=load("res://scripts/city/runtime/npc_threat_life30.gd")
	var Physical: Script=load("res://scripts/hospital/npc_physical_route51.gd")
	var scene:=World.new();root.add_child(scene);current_scene=scene
	var rows: Array=[];var checks: Dictionary={}
	var failures:=0
	for angle: float in [-1.570342,.731,2.1]:
		var body:=CharacterBody3D.new();var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.9;capsule.radius=.36;shape.shape=capsule;shape.position.y=.95;body.add_child(shape);scene.add_child(body)
		# The real presentation host writes a travel basis before stationary facing.
		body.basis=Basis(Vector3.UP,angle+.13)
		var probe: RefCounted=Physical.new()
		checks["initial_capsule_"+str(angle)]=probe.configure(body)
		var controller: RefCounted=Threat.new();controller._event={"source_identified":true,"escape_from":Vector3(-sin(angle),0,-cos(angle))*20.0}
		var first_failure:=-1
		for frame: int in 6000:
			# Reproduce host transform readback (the body scale is NOT written).
			var readback: Transform3D=body.global_transform
			if frame%35==0:body.basis=Basis(Vector3.UP,angle+.13)
			controller._face_known_threat31(body,1.0/60.0)
			if first_failure<0 and not probe.configure(body):first_failure=frame
		var configured: bool=probe.configure(body)
		if not configured:failures+=1
		rows.append({"target_angle":angle,"body_yaw":body.rotation.y,"scale":body.scale,"shape_scale":shape.global_basis.get_scale(),"upright":shape.global_basis.y,"first_failure_frame":first_failure,"final_route_configured":configured})
		checks["candidate_keeps_unit_capsule_"+str(angle)]=configured if candidate else true
	checks["baseline_scale_drift_reproduced_or_candidate_fixed"]=(failures==0) if candidate else (failures>0)
	var passed:=not checks.values().has(false)
	var result: Dictionary={"candidate":candidate,"passed":passed,"checks":checks,"rows":rows,"scope":"Actual threat facing helper repeated on native capsules; actual physical-route Surface admission after each call"}
	var file:=FileAccess.open(out.path_join("NATIVE31.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("YAW31 ",JSON.stringify(result));quit(0 if passed else 1)
