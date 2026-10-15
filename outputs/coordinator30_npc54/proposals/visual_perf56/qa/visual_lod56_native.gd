extends SceneTree
const Host56 = preload("res://scripts/npc_visual/preview_resident_host.gd")
const Host55 = preload("res://qa/host55_reference.gd")
const Gait56 = preload("res://qa/count_gait56.gd")
const Motion = preload("res://scripts/hospital/npc_motion_visual51.gd")
const Ambient = preload("res://scripts/npc_ambient/ambient_pose28.gd")
var failures: Array[String] = []
var checks: Array[String] = []
var evidence: Dictionary = {}
var output := ""

class SourceOwner extends RefCounted:
    var dead := false
    var source_id := ""
    var life_generation := 1

class Navigation extends RefCounted:
    func step(_request: int, _delta: float, _speed: float, _gravity: float) -> Dictionary:
        return {"status":"ARRIVED"}
    func cancel(_request: int) -> void: pass

class AmbientOwner extends RefCounted:
    var body: CharacterBody3D
    var active := true
    var committed := 0
    var suppressed := 0
    var cancelled := ""
    func sample_current(value: Dictionary) -> bool:
        return active and value.body_id==body.get_instance_id() and value.frame==Engine.get_physics_frames()
    func pose_suppressed() -> void: suppressed += 1
    func pose_committed(_rig: Skeleton3D, value: Dictionary) -> void:
        if sample_current(value): committed += 1
    func cancel(reason: String) -> void:
        active=false; cancelled=reason
        if is_instance_valid(body):body.remove_meta(Ambient.META)

class HitPose extends RefCounted:
    var calls := 0
    func hit_pose_active() -> bool: return true
    func compose_hit_pose(pose: Dictionary) -> Dictionary:
        calls += 1
        var bones: Array[Transform3D]=pose.poses
        bones[0].basis=Basis(Vector3.UP,.17)*bones[0].basis
        return pose

class Driver extends Node:
    signal finished
    var actors: Array[Dictionary] = []
    var hosts: Array[RefCounted] = []
    var remaining := 0
    var moving := false
    var action := ""
    var frame_index := 0
    var maximum_far_commits := 0
    var travel: Dictionary = {}
    func run_frames(count: int, move: bool, selected_action: String="") -> void:
        remaining=count; moving=move; action=selected_action; frame_index=0
        set_physics_process(true)
    func _physics_process(delta: float) -> void:
        if remaining<=0:return
        var old_far := 0
        for actor: Dictionary in actors:
            if actor.group=="candidate_far":old_far+=actor.gait.commits56
            if actor.record.get("single_dead28",false):continue
            var body: CharacterBody3D=actor.body
            var first: Vector3=body.global_position
            body.velocity=Vector3(0,-9.8*delta,1.8 if moving else 0.0)
            body.move_and_slide()
            var finish: Vector3=body.global_position
            travel[actor.id]=float(travel.get(actor.id,0.0))+Vector2(finish.x-first.x,finish.z-first.z).length()
            body.set_meta(Motion.META,{"frame":Engine.get_physics_frames(),"body_id":body.get_instance_id(),"delta":delta,"from":first,"to":finish})
            if actor.has("ambient_owner") and action=="ambient":
                body.set_meta(Ambient.META,{"active":true,"kind":"phone","frame":Engine.get_physics_frames(),"body_id":body.get_instance_id(),"delta":delta,"owner":weakref(actor.ambient_owner),"elapsed_s":1.0+frame_index*delta,"duration_s":5.0})
            if actor.group=="candidate_far" and actor.id=="far56" and action=="treatment":
                body.set_meta(Motion.TREATMENT_META,{"active":true,"kind":"hospital","frame":Engine.get_physics_frames(),"body_id":body.get_instance_id(),"delta":delta,"elapsed_s":1.0,"duration_s":1.5})
        for host: RefCounted in hosts:host.step(delta)
        var new_far := 0
        for actor: Dictionary in actors:
            if actor.group=="candidate_far":new_far+=actor.gait.commits56
        maximum_far_commits=maxi(maximum_far_commits,new_far-old_far)
        frame_index+=1;remaining-=1
        if remaining==0:set_physics_process(false);finished.emit()

func check(value: bool, message: String) -> void:
    checks.append(message)
    if not value:failures.append(message);printerr("CHECK_FAIL ",message)

func _initialize() -> void: call_deferred("run")

func actor(scene: Node3D, host: RefCounted, packed: PackedScene, id: String, at: Vector3, group: String) -> Dictionary:
    var body:=CharacterBody3D.new();body.name=id;scene.add_child(body);body.position=at
    body.collision_layer=1;body.collision_mask=1;body.floor_snap_length=.3
    var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.36;capsule.height=1.9;shape.shape=capsule;shape.position.y=.95;body.add_child(shape)
    var motion:=Node3D.new();body.add_child(motion)
    var visual: Node3D=packed.instantiate();motion.add_child(visual)
    var gait:=Gait56.new();check(gait.bind(visual,motion),"canonical gait bind "+id)
    var owner:=SourceOwner.new();owner.source_id=id
    var record: Dictionary={"owner":owner,"row":{"source_id":id,"bridge_id":id,"descriptor_sha256":"fixture"},"generation":1,"body":body,"motion":motion,"gait":gait,"activity":null,"status":"ARRIVED","request":42 if group=="candidate_far" else -1,"speed":1.8,"turn_from":0.0,"turn_to":0.0,"turn_elapsed":.1,"display_yaw":0.0}
    host._records[id]=record;host._active_track30(record)
    return {"id":id,"body":body,"gait":gait,"record":record,"group":group}

func shadow_all(a: Dictionary, expected: int) -> bool:
    for mesh: MeshInstance3D in a.body.find_children("*","MeshInstance3D",true,false):
        if mesh.cast_shadow!=expected:return false
    return true

func bones_committed(a: Dictionary) -> bool:
    if not a.gait.last_sample56.get("valid",false):return false
    var poses: Array[Transform3D]=a.gait.last_sample56.poses
    var rig: Skeleton3D=a.gait._skeleton
    if poses.size()!=28 or rig.get_bone_count()!=28:return false
    for bone: int in poses.size():
        if not rig.get_bone_pose(bone).is_equal_approx(poses[bone]):return false
    return true

func run() -> void:
    var marker := ""
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
        elif arg.begins_with("--qa-ready="):marker=arg.trim_prefix("--qa-ready=")
    var deadline:=Time.get_ticks_msec()+30000
    while not marker.is_empty() and not FileAccess.file_exists(marker):
        if Time.get_ticks_msec()>deadline:quit(2);return
        await create_timer(.05).timeout
    var scene:=Node3D.new();root.add_child(scene);current_scene=scene
    var floor56:=StaticBody3D.new();scene.add_child(floor56)
    var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(220,1,50);floor_shape.shape=box;floor_shape.position=Vector3(45,-.5,10);floor56.add_child(floor_shape)
    var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,2,-5);camera.current=true
    var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_city/prepared/manifest.json"))
    var packed: PackedScene=load("res://assets/npc_city/prepared/"+str(manifest.entries[0].prepared_file))
    var old:=Host55.new();var changed:=Host56.new()
    for host: RefCounted in [old,changed]:
        host._scene=weakref(scene);host._navigation=Navigation.new();host._session="visual56_fixture"
        host._resident_detail_flag=0;host._dsh_timing=0
    # A deliberately lower cap tests the hard bound with only two distant bodies.
    changed._dsh_pose_far_cap=1
    var near_old:=actor(scene,old,packed,"near55",Vector3(-2,.01,0),"baseline_near")
    var far_old:=actor(scene,old,packed,"far55",Vector3(78,.01,0),"baseline_far")
    var near_new:=actor(scene,changed,packed,"near56",Vector3(2,.01,0),"candidate_near")
    var far_new:=actor(scene,changed,packed,"far56",Vector3(82,.01,0),"candidate_far")
    var far_b:=actor(scene,changed,packed,"far56b",Vector3(86,.01,0),"candidate_far")
    var driver:=Driver.new();scene.add_child(driver);driver.actors=[near_old,far_old,near_new,far_new,far_b];driver.hosts=[]
    driver.run_frames(5,false);await driver.finished
    for a: Dictionary in driver.actors:check(a.body.is_on_floor(),"real native floor "+a.id)
    driver.hosts=[old,changed]
    driver.run_frames(120,true);await driver.finished
    check(near_new.gait.samples56==120 and near_old.gait.samples56==120,"near refresh identical every physics tick")
    check(shadow_all(near_new,GeometryInstance3D.SHADOW_CASTING_SETTING_ON),"near full shadows retained")
    check(bones_committed(near_new) and bones_committed(far_new),"near and distant canonical bones match their actual last pose commit")
    check(shadow_all(far_new,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"physical far actor shadows disabled")
    check(far_old.gait.samples56==120,"baseline reproduces forced full far pose")
    check(far_new.gait.samples56>0 and far_new.gait.samples56<40 and far_b.gait.samples56>0,"both far actors receive bounded poses")
    check(driver.maximum_far_commits<=1,"far pose cap respected with native physical bodies")
    check(absf(angle_difference(far_new.gait._phase,far_old.gait._phase))<.001,"actual physical distance advances identical gait phase across host nav skips")
    check(absf(float(driver.travel.far56)-float(driver.travel.far55))<.0001 and float(driver.travel.far56)>3.0,"visual LOD leaves actual move_and_slide distance unchanged")
    evidence.walk={"near_samples":near_new.gait.samples56,"far_old_samples":far_old.gait.samples56,"far_new_samples":far_new.gait.samples56,"far_second_samples":far_b.gait.samples56,"far_phase":far_new.gait._phase,"old_phase":far_old.gait._phase,"max_far_commits":driver.maximum_far_commits,"far_native_travel_m":driver.travel.far56}
    driver.run_frames(140,false);await driver.finished
    check(far_new.gait.settled() and far_b.gait.settled(),"stopped distant actors both settle without frozen walking pose")
    var before_near: int=far_new.gait.samples56
    camera.position=far_new.body.position+Vector3(0,2,-5)
    driver.run_frames(20,false);await driver.finished
    check(far_new.gait.samples56-before_near==20,"approaching camera restores full-rate presentation immediately")
    check(shadow_all(far_new,GeometryInstance3D.SHADOW_CASTING_SETTING_ON),"approaching camera restores all original shadows")
    camera.position=Vector3(0,2,-5)
    var ambient_owner:=AmbientOwner.new();ambient_owner.body=far_new.body;far_new.ambient_owner=ambient_owner
    var before_ambient: int=far_new.gait.samples56
    driver.run_frames(30,false,"ambient");await driver.finished
    check(ambient_owner.committed==30 and far_new.gait.samples56-before_ambient==30,"distant phone retains real per-frame pose commits")
    check(bones_committed(far_new),"all28 distant phone bones match composed result")
    check(shadow_all(far_new,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"distant ambient action does not re-enable shadows")
    Ambient.cancel_body(far_new.body,"fixture_cancel")
    var before_cancel: int=far_new.gait.samples56
    driver.run_frames(1,false);await driver.finished
    check(ambient_owner.cancelled=="fixture_cancel" and not bool(far_new.record.ambient_pose_active28),"ambient cancellation reaches current owner and clears action")
    check(far_new.gait.samples56-before_cancel==1,"cancelled distant actor receives canonical stand-up pose")
    check(bones_committed(far_new),"all28 cancellation bones match canonical return result")
    var before_treatment: int=far_new.gait.samples56
    driver.run_frames(20,false,"treatment");await driver.finished
    check(far_new.gait.samples56-before_treatment==20 and far_new.record.get("treatment_pose28")!=null,"real treatment composer remains full-rate at distance")
    check(bones_committed(far_new),"all28 treatment bones are actually committed")
    check(shadow_all(far_new,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"treatment does not re-enable distant shadows")
    far_new.body.remove_meta(Motion.TREATMENT_META)
    var hit:=HitPose.new();far_new.record.contact_hit_reaction=hit
    var before_hit: int=far_new.gait.samples56
    driver.run_frames(20,false);await driver.finished
    check(hit.calls==20 and far_new.gait.samples56-before_hit==20,"hit composition and commit retain full cadence at distance")
    check(bones_committed(far_new),"all28 hit-result bones are actually committed")
    check(shadow_all(far_new,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"hit response does not re-enable distant shadows")
    far_new.record.contact_hit_reaction=null
    Ambient.cancel_body(far_new.body,"death")
    far_new.record.single_dead28=true
    var before_death: int=far_new.gait.samples56
    var dead_position: Vector3=far_new.body.position
    driver.run_frames(20,false);await driver.finished
    check(far_new.gait.samples56==before_death and far_new.body.position==dead_position,"dead-owner branch does not animate or move the body")
    check(failures.is_empty(),"complete fixture has no failed invariants")
    var result: Dictionary={"ok":failures.is_empty(),"checks":checks,"failures":failures,"evidence":evidence,"scope":"presentation dispatch plus actual native movement/rig; health transactions and city performance remain root QA","performance_accepted":false}
    var f:=FileAccess.open(output.path_join("VISUAL_LOD56.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
    print("VISUAL_LOD56 ",result.ok," checks=",checks.size());quit(0 if result.ok else 1)
