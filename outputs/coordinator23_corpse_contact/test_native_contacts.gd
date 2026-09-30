extends SceneTree
## Native query tests only. Real production player/capsule + sleeping layer256
## RigidBody fixture. Spy owner records commands and explicitly applies NO force.
const Sampler=preload("player_corpse_contact.gd")
var player:CharacterBody3D
var corpse:RigidBody3D
var wall:StaticBody3D
var world:Node3D
var sampler:RefCounted
var ready_to_step:=false
var stage:=0
var settle:=0
var checks:=0
var failures:Array=[]
var commands:Array=[]
var rows:Array=[]
var started:=0
var warmup:=90
var names:=["entering","continued_overlap","moving_away","stationary","wall","vehicle","jump","replay_epoch","expired_frame","same_frame_replay"]
func _initialize()->void:
	started=Time.get_ticks_msec();build.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);print("CONTACT_FAIL ",label)
func ready_contract()->Dictionary:
	return {"ready":true,"schema":"npc_final_dead_contact/v1","epoch":7,"max_impulse_ns":2.0,"impulse_ns_per_mps":.5,"cooldown_ms":80,"max_contact_height_m":.6,"max_relative_speed_mps":8.0}
func spy(request:Dictionary)->Dictionary:
	commands.append(request.duplicate(true))
	return {"ok":false,"reason":"spy_only_no_force_or_NPC_authority"}
func body_box(body:CollisionObject3D,size:Vector3)->void:
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
func build()->void:
	world=Node3D.new();root.add_child(world)
	var floor:=StaticBody3D.new();floor.collision_layer=1;world.add_child(floor);floor.position.y=-.1;body_box(floor,Vector3(10,.2,10))
	corpse=RigidBody3D.new();corpse.collision_layer=256;corpse.collision_mask=1;corpse.mass=75;world.add_child(corpse);body_box(corpse,Vector3(.65,.35,.8));corpse.position=Vector3(.775,.175,0);corpse.sleeping=true
	wall=StaticBody3D.new();wall.collision_layer=1;world.add_child(wall);wall.position=Vector3(3,.5,0);body_box(wall,Vector3(.04,1,2))
	player=load("res://scripts/preview_player.gd").new();world.add_child(player)
	player.set_physics_process(false);player._free_mouse_look=true
	check(player.get_node("PlayerCapsule").shape is CapsuleShape3D,"actual_player_capsule")
	check(player.collision_layer==2 and player.collision_mask==1,"original_player_masks")
	prepare();ready_to_step=true
func prepare()->void:
	var label:String=names[stage]
	player.global_position=Vector3(.13 if label in ["entering","same_frame_replay"] else .18,.002,0)
	player.velocity=Vector3.ZERO;player._pose_authority=&"on_foot";player._jump={};player._free_mouse_look=true
	wall.position.x=.37 if label=="wall" else 3.0
	sampler=Sampler.new();sampler.configure(ready_contract,spy);settle=0
func _physics_process(delta:float)->bool:
	if not ready_to_step:return false
	if Time.get_ticks_msec()-started>5000:check(false,"five_second_deadline");finish();return false
	if warmup>0:
		player.velocity=Vector3(0,-.2,0);player.move_and_slide();warmup-=1
		if warmup==0:prepare()
		return false
	if settle<4:
		player.velocity=Vector3(0,-.2,0);player.move_and_slide();settle+=1;return false
	var label:String=names[stage]
	check(player.is_on_floor(),label+":real_floor")
	check(corpse.sleeping and not corpse.freeze,label+":native_sleeping_not_frozen")
	player.velocity=Vector3(-3.2 if label=="moving_away" else 0.0 if label=="stationary" else 3.2,-.2,0)
	if label=="vehicle":player._pose_authority=&"vehicle"
	if label=="jump":player._jump={"qa_branch_guard":true}
	var start:Dictionary=sampler.begin(player)
	if label=="replay_epoch":player._pose_epoch+=1
	if label=="expired_frame" and not start.is_empty():start.frame-=1
	var before:=commands.size();var body_before:=corpse.global_transform
	player.move_and_slide()
	sampler.finish(player,start,delta)
	if label=="same_frame_replay":sampler.finish(player,start,delta)
	var added:int=commands.size()-before
	var positive:bool=label in ["entering","continued_overlap","same_frame_replay"]
	check(added==(1 if positive else 0),label+":bounded_contact_count")
	if added>0:
		var request:Dictionary=commands.back()
		check(request.collider_rid==corpse.get_rid() and request.collider_instance_id==corpse.get_instance_id(),label+":exact_native_body")
		check(request.shape_index==0 and request.world_point.is_finite() and request.world_normal.is_finite(),label+":real_shape_contact")
		check(request.suggested_impulse_ns.length()<=2.00001 and request.suggested_impulse_ns.y==0,label+":bounded_horizontal_proposal")
		check(request.initial_overlap==(label=="continued_overlap"),label+":correct_contact_route")
	check(sampler.accepted==0 and corpse.global_transform.is_equal_approx(body_before),label+":spy_no_force_acceptance")
	rows.append({"case":label,"commands":added,"on_floor":player.is_on_floor(),"body_unchanged":corpse.global_transform.is_equal_approx(body_before)})
	stage+=1
	if stage>=names.size():finish();return false
	prepare();return false
func finish()->void:
	ready_to_step=false
	var report:Dictionary={"pass":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"elapsed_ms":Time.get_ticks_msec()-started,"scope":"actual native player capsule, sleeping RigidBody3D256, queries and proposal only; spy records/rejects, no NPC lifecycle or impulse acceptance","GPU":false}
	FileAccess.open(get_script().resource_path.get_base_dir()+"/NATIVE_QUERY_RESULT.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("NATIVE_CONTACT_RESULT ",JSON.stringify(report));world.queue_free();quit(0 if failures.is_empty() else 1)
