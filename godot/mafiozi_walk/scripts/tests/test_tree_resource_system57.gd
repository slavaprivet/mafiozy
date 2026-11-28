extends SceneTree

const Props=preload("res://scripts/city/battlefield_props.gd")
const Inventory=preload("res://scripts/inventory/resource_inventory.gd")
const TreeDamage=preload("res://scripts/environment/tree_damage_rules57.gd")

var checks:=0
var failures:Array[String]=[]

func check(value: bool,label: String)->void:
	checks+=1
	if not value: failures.append(label); push_error("TREE57 "+label)

func _init()->void:
	call_deferred("run")

func run()->void:
	var world:=Node3D.new(); root.add_child(world)
	var castle:=Node3D.new(); world.add_child(castle)
	var props:=Props.new(); world.add_child(props)
	var stats:Dictionary=props.install(castle)
	check(int(stats.get("trees",0))>=10,"batched forest built")
	check(int(stats.get("mesh_instances",0))<80,"bounded battlefield draw batches")
	var meshes:Dictionary=props.get("_meshes")
	var trunk_vertices:PackedVector3Array=(meshes["tree_trunk"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var crown_vertices:PackedVector3Array=(meshes["tree_crown"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(trunk_vertices.size()==270,"shared irregular six-ring trunk mesh stays bounded")
	check(crown_vertices.size()==660,"shared eleven-cluster crown adds silhouette without per-tree nodes")
	var player:=CharacterBody3D.new(); player.collision_layer=2; player.collision_mask=1; world.add_child(player)
	var inventory:=Inventory.new(); world.add_child(inventory)
	check(bool(inventory.install(player).get("ok",false)),"B resource inventory installed")
	check(props.bind_resource_inventory(inventory),"logs bound to resource owner")
	check(props.bind_player(player),"player bound for controlled log kicks")
	check(inventory.bind_drop_handler(Callable(props,"drop_inventory_resource")),"inventory drop is bound atomically to world")
	var groups:Dictionary=props.get("_groups")
	var tree_id:=""
	for id:Variant in groups.keys():
		if str(id).begins_with("tree_"): tree_id=str(id); break
	check(not tree_id.is_empty(),"tree damage group exists")
	var tree:Dictionary=groups[tree_id]
	var collider:StaticBody3D=tree.collider
	check(is_instance_valid(collider) and collider.get_meta("surface","")=="wood","tree collider reports wood")
	check(TreeDamage.damage("axe",5.0,1.0)>TreeDamage.damage("sword",5.0,1.0)*3.0,"axe fells much faster than sword")
	check(TreeDamage.damage("sword",0.2,1.0)==0.0,"resting blade cannot damage tree")
	var before:=float(tree.health)
	var first:Dictionary=props.apply_melee_hit(tree_id,props.to_global(Vector3(tree.center)),"sword",11.0)
	check(first.get("accepted",false) and is_equal_approx(float(first.health),before-11.0),"sword contact removes persistent HP")
	check((props.get("_tree_hp_label") as Label3D).visible,"one shared HP label shown")
	check(str((props.get("_tree_hp_label") as Label3D).text).contains("109 / 120") and not str((props.get("_tree_hp_label") as Label3D).text).contains("УДАРА"),"HP label shows only exact remaining health")
	check((props.get("_tree_damage_label") as Label3D).visible and str((props.get("_tree_damage_label") as Label3D).text)=="−11 HP","red damage popup reports exact dealt HP")
	check((tree.get("tree_mark_slots",[]) as Array).size()==1,"contact creates one bounded cut mark")
	var mark_aabb: AABB=(props.get("_tree_mark_multi") as MultiMesh).mesh.get_aabb()
	check(mark_aabb.position.z+mark_aabb.size.z<=0.001,"cut scar is inset into bark instead of protruding as a black block")
	var stable_damage_anchor:Vector3=(props.get("_tree_damage_label") as Label3D).position
	props.apply_melee_hit(tree_id,props.to_global(Vector3(tree.center)+Vector3(0.35,2.8,-0.25)),"sword",0.1)
	check((props.get("_tree_damage_label") as Label3D).position.is_equal_approx(stable_damage_anchor) and is_equal_approx((props.get("_tree_damage_label") as Label3D).modulate.a,1.0),"rapid hits restart at one stable fully opaque anchor without jumping")
	await create_timer(1.05).timeout
	check(not (props.get("_tree_damage_label") as Label3D).visible,"damage popup fades completely in about one second")
	for repeated_mark in 6: props.apply_melee_hit(tree_id,props.to_global(Vector3(tree.center)+Vector3.UP*(0.8+0.08*repeated_mark)),"sword",0.1)
	check((tree.get("tree_mark_slots",[]) as Array).size()==4,"one tree retains only four newest cut marks")
	for mark_id:Variant in groups.keys():
		if not str(mark_id).begins_with("tree_") or str(mark_id)==tree_id: continue
		var mark_tree:Dictionary=groups[mark_id]
		for mark_index in 4: props.apply_melee_hit(str(mark_id),props.to_global(Vector3(mark_tree.center)+Vector3.UP*(0.75+0.1*mark_index)),"sword",0.1)
	var occupied_marks:=0
	for owner:String in props.get("_tree_mark_owner"):
		if not owner.is_empty(): occupied_marks+=1
	check(occupied_marks==48,"global cut-mark pool evicts safely at forty-eight slots")
	var final:Dictionary=props.apply_melee_hit(tree_id,props.to_global(Vector3(tree.center)),"axe",999.0)
	check(final.get("fell",false) and bool(tree.destroyed),"zero HP starts one fall")
	check(str((props.get("_tree_hp_label") as Label3D).text)=="Срублено  0 / 120","fatal hit keeps zero HP feedback")
	check((tree.get("tree_mark_slots",[]) as Array).is_empty(),"fall clears cut marks")
	check((props.get("_falling_trees") as Array).size()==1,"one active falling tree")
	var falling_root:=props.find_child("Falling_%s"%tree_id,true,false) as Node3D
	var falling_wood:=falling_root.get_child(0) as MultiMeshInstance3D
	var falling_crown:=falling_root.get_child(1) as MeshInstance3D
	check(falling_wood.multimesh.instance_count==6 and falling_wood.multimesh.mesh.get_surface_count()==1,"fall reuses one detailed trunk-and-branch batch")
	check(falling_crown.scale.is_equal_approx(Vector3(tree.tree_crown_scale)),"fall preserves the live crown silhouette")
	var repeated:Dictionary=props.apply_melee_hit(tree_id,props.to_global(Vector3(tree.center)),"axe",999.0)
	check(not repeated.get("accepted",false),"fall cannot duplicate")
	props.call("_process",1.05)
	check(props.find_child("TreeStump",true,false)==null,"fallen tree leaves no stump pile")
	var logs:Array=props.get("_tree_logs")
	check(logs.size()==int(tree.tree_yield) and logs.size()>=3 and logs.size()<=5,"size yield becomes 3-5 physical logs")
	var first_log:RigidBody3D=(logs[0] as WeakRef).get_ref() as RigidBody3D
	check(is_instance_valid(first_log) and first_log is RigidBody3D,"log is a physical body")
	check((first_log.get_child(0) as MeshInstance3D).mesh==props.get("_meshes").get("pickup_log"),"fallen log reuses detailed bark and end-grain mesh")
	var log_shape:=first_log.get_child(first_log.get_child_count()-1) as CollisionShape3D
	check(log_shape.shape is BoxShape3D and first_log.mass<0.5 and first_log.linear_damp>=5.0,"log uses light stable damped box physics")
	check((player.collision_mask&first_log.collision_layer)==0,"log cannot become a slope under player capsule")
	first_log.linear_velocity=Vector3.ZERO; first_log.angular_velocity=Vector3.ZERO
	player.global_position=first_log.global_position-Vector3.FORWARD*0.62; player.velocity=Vector3.FORWARD*3.0
	props.call("_advance_tree_logs")
	check(first_log.linear_velocity.dot(Vector3.FORWARD)>0.0 and absf(first_log.linear_velocity.y)<0.001,"walking direction gives bounded horizontal kick")
	first_log.linear_velocity=Vector3(0.01,0.0,0.01); first_log.angular_velocity=Vector3(0.02,0.0,0.0); player.velocity=Vector3.ZERO
	props.call("_advance_tree_logs")
	check(Vector3(first_log.linear_velocity.x,0.0,first_log.linear_velocity.z).is_zero_approx() and first_log.angular_velocity.is_zero_approx(),"unopposed log settles horizontally without forced airborne sleep")
	var prompt:Dictionary=props.tree_log_action(first_log.global_position)
	check(prompt.get("key","")=="E" and prompt.get("owner","")=="tree_log","E pickup prompt")
	check(props.pickup_tree_log(first_log.global_position),"E transaction picks one log")
	check(inventory.count("wood")==1,"picked log increments wood once")
	var toast := inventory.get("_toast_panel") as PanelContainer
	var toast_label := inventory.get("_toast_label") as Label
	check(toast.visible and toast_label.text == "+1 Древесина" and toast_label.get_theme_font_size("font_size") == 12,"pickup shows compact gain toast")
	check(not is_instance_valid(first_log) or first_log.is_queued_for_deletion(),"picked physical log consumed")
	check(bool(first_log.get_meta("pickup_claimed",false)),"picked log is atomically claimed")
	check(inventory.open_window(),"B opens resource inventory")
	check(inventory.is_open(),"B opens resource inventory")
	check(str(inventory.get("_detail_description").text).contains("каждое поднятое полено"),"selected card shows item description")
	inventory.close_window(false)
	check(not inventory.is_open() and inventory.count("wood")==1,"B closes without losing count")
	player.global_position=props.to_global(Vector3(40,0,110)); inventory.open_window(); inventory.call("_drop_resource","wood",1); inventory.close_window(false)
	check(inventory.count("wood")==0,"dragging one unit outside decrements inventory only after world accepts it")
	var single_drop:=props.call("_nearest_tree_log",player.global_position+Vector3.FORWARD*1.45) as RigidBody3D
	check(is_instance_valid(single_drop) and int(single_drop.get_meta("wood_units",0))==1 and not bool(single_drop.get_meta("inventory_stack",false)),"one dropped item is one physical log")
	check(props.pickup_tree_log(single_drop.global_position) and inventory.count("wood")==1,"single dropped log can be recovered")
	inventory.add_resource("wood",6); inventory.open_window(); inventory.call("_drop_resource","wood",7); inventory.close_window(false)
	check(inventory.count("wood")==0,"multi-item drag commits one exact inventory transaction")
	var stack_log:RigidBody3D
	for reference:WeakRef in props.get("_tree_logs"):
		var candidate:=reference.get_ref() as RigidBody3D
		if is_instance_valid(candidate) and bool(candidate.get_meta("inventory_stack",false)): stack_log=candidate
	check(is_instance_valid(stack_log) and int(stack_log.get_meta("wood_units",0))==7,"large drop is one physical stack with exact units")
	check(stack_log.get_child(0) is MultiMeshInstance3D and (stack_log.get_child(0) as MultiMeshInstance3D).multimesh.instance_count==6,"dropped stack batches detailed visible logs in one draw")
	var wood_before_stack:=inventory.count("wood")
	check(props.pickup_tree_log(stack_log.global_position),"dropped stack can be recovered")
	check(inventory.count("wood")==wood_before_stack+7,"stack restores exact resource count")
	var expected_remaining:=int(tree.tree_yield)-1
	for id:Variant in groups.keys():
		var other:Dictionary=groups[id]
		if str(id).begins_with("tree_") and not bool(other.destroyed):
			expected_remaining+=int(other.tree_yield)
			props.apply_melee_hit(str(id),props.to_global(Vector3(other.center)),"axe",999.0)
	props.call("_process",1.05)
	var live_logs:Array=props.get("_tree_logs")
	var pending_logs:Array=props.get("_pending_tree_logs")
	var represented:=live_logs.size()+pending_logs.size()
	check(live_logs.size()<=32,"mass felling keeps physical log cap")
	check(represented==expected_remaining,"log cap preserves complete wood yield %d/%d"%[represented,expected_remaining])
	var picked_before:=inventory.count("wood")
	var one_reference:WeakRef=live_logs[0]
	var one_body:=one_reference.get_ref() as RigidBody3D
	check(props.pickup_tree_log(one_body.global_position),"mass pickup accepts one visible log")
	check(inventory.count("wood")==picked_before+1,"every E adds exactly one wood")
	props.call("_drain_pending_tree_logs")
	check((props.get("_tree_logs") as Array).size()<=32,"overflow refill remains within physical cap")
	print("TREE_RESOURCE57_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"stats":stats}))
	quit(0 if failures.is_empty() else 1)
