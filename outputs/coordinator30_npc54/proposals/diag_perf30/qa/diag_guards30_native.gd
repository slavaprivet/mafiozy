extends SceneTree
const Host = preload("res://scripts/npc_visual/preview_resident_host.gd")
const Old = preload("res://qa/old_target_current30.gd")
const Hits = preload("res://scripts/npc_visual/npc_local_preview_hit_owner.gd")
class Owner extends RefCounted:
	var dead := false
	var source_id := "guard_resident"
	var life_generation := 1
var out := ""
var checks: Array[String]=[]
var failures: Array[String]=[]
var evidence: Dictionary={}
var old: RefCounted
var changed: RefCounted
func check(value: bool,label: String) -> void:
	checks.append(label)
	if not value:failures.append(label)
func compare(token: Dictionary,label: String,expected: bool) -> void:
	var a: bool=old.target_current(token);var b: bool=changed.target_current(token)
	check(a==b and b==expected,label)
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
	var scene:=Node3D.new();root.add_child(scene);current_scene=scene
	var body:=CharacterBody3D.new();scene.add_child(body);body.collision_layer=1;body.collision_mask=1
	body.set_meta("source_id","guard_resident");body.set_meta("session_id","session");body.set_meta("descriptor_sha256","sha")
	var shape:=CollisionShape3D.new();shape.shape=CapsuleShape3D.new();shape.shape.radius=.36;shape.shape.height=1.9;shape.position.y=.95;body.add_child(shape)
	var motion:=Node3D.new();body.add_child(motion);var rig:=Skeleton3D.new();motion.add_child(rig)
	var owner:=Owner.new();var record: Dictionary={"owner":owner,"row":{"source_id":"guard_resident","bridge_id":"bridge","descriptor_sha256":"sha"},"generation":1,"body":body,"motion":motion,"placement_mode":"IDLE"}
	old=Old.new();changed=Host.new()
	for host: RefCounted in [old,changed]:host._scene=weakref(scene);host._session="session";host._records={"guard_resident":record}
	var token: Dictionary=old.target_from_collider(body)
	compare(token,"live canonical token equal",true)
	for key: String in ["ok","source_authority","session_id","source_id","bridge_id","render_id","life_generation","descriptor_sha256","placement_mode","body_instance_id","body_rid","rig","rig_instance_id","rig_epoch"]:
		var bad: Dictionary=token.duplicate();bad[key]=null;compare(bad,"changed token field "+key,false)
	for flag: int in [0,1]:
		old._dsh_target_fast_cache=flag;changed._dsh_target_fast_cache=flag;compare(token,"same lookup mode "+str(flag),true)
		body.set_meta("source_id","foreign");compare(token,"foreign source metadata mode "+str(flag),false);body.set_meta("source_id","guard_resident")
	for key: String in ["session_id","descriptor_sha256"]:
		var value: Variant=body.get_meta(key);body.set_meta(key,"foreign");compare(token,"changed body "+key,false);body.set_meta(key,value)
	body.collision_mask=2;compare(token,"changed mask",false);body.collision_mask=1
	body.collision_layer=2;compare(token,"changed layer",false);body.collision_layer=1
	shape.disabled=true;compare(token,"disabled collider",false);shape.disabled=false
	var capsule: Shape3D=shape.shape;shape.shape=BoxShape3D.new();compare(token,"wrong shape replacement",false)
	shape.shape=CapsuleShape3D.new();shape.shape.radius=.36;shape.shape.height=1.9;compare(token,"same geometric capsule replacement retains prior semantics",true);shape.shape=capsule
	shape.shape.radius=.2;compare(token,"changed capsule radius",false);shape.shape.radius=.36
	shape.shape.height=2.0;compare(token,"changed capsule height",false);shape.shape.height=1.9
	owner.dead=true;compare(token,"same-frame dead owner",false);owner.dead=false
	record.generation=2;compare(token,"same-frame stale generation",false);record.generation=1
	owner.life_generation=2;compare(token,"owner generation mismatch",false);owner.life_generation=1
	owner.source_id="foreign";compare(token,"owner source mismatch",false);owner.source_id="guard_resident"
	for key: String in ["_busy","_disposed","_dispose_requested"]:
		old.set(key,true);changed.set(key,true);compare(token,"host guard "+key,false);old.set(key,false);changed.set(key,false)
	var other:=Node3D.new();scene.add_child(other);body.reparent(other);compare(token,"body parent changed",false);body.reparent(scene)
	motion.remove_child(rig);compare(token,"rig removed",false)
	var replacement:=Skeleton3D.new();motion.add_child(replacement);compare(token,"same-frame rig replaced",false);replacement.free();motion.add_child(rig)
	var second:=Skeleton3D.new();motion.add_child(second);compare(token,"second rig introduced",false);second.free()
	compare(token,"restored rig accepted same frame",true)
	var freed:=CharacterBody3D.new();var stale: Dictionary=token.duplicate();stale.body=freed;freed.free();compare(stale,"freed body rejected before type test",false)
	var timings: Array=[]
	for round30: int in 3:
		var line: Dictionary={}
		for pair: Array in [["old",old],["new",changed]]:
			var started: int=Time.get_ticks_usec()
			for i: int in 5000:pair[1].target_current(token)
			line[pair[0]]=Time.get_ticks_usec()-started
		timings.append(line)
	evidence.guard_5000_calls_us=timings
	var health:=Hits.new();health._ready=true;health._token={"body":body}
	# No named metadata: enabled probe stops before any shot/authority callback.
	for i: int in 100:health._dsh_damage_probe()
	var expected: int=1 if OS.get_cmdline_user_args().has("--city-damage-probe=1") else 0
	check(Hits._damage_probe_flag30==expected,"immutable damage probe flag correctly cached")
	check(not health._dsh_probe_fired,"fixture probe does not grant or apply a shot")
	evidence.probe_cached=Hits._damage_probe_flag30;health._ready=false
	old._disconnect_rig_tree();changed._disconnect_rig_tree();old=null;changed=null
	var result: Dictionary={"ok":failures.is_empty(),"checks":checks,"failures":failures,"evidence":evidence,"performance_accepted":false}
	var f:=FileAccess.open(out.path_join("DIAG_GUARDS30.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close();print("DIAG_GUARDS30 ",result.ok," checks=",checks.size());quit(0 if result.ok else 1)
