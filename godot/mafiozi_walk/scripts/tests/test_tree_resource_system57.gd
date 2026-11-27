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
	var inventory:=Inventory.new(); world.add_child(inventory)
	check(bool(inventory.install().get("ok",false)),"B resource inventory installed")
	check(props.bind_resource_inventory(inventory),"logs bound to resource owner")
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
	var final:Dictionary=props.apply_melee_hit(tree_id,props.to_global(Vector3(tree.center)),"axe",999.0)
	check(final.get("fell",false) and bool(tree.destroyed),"zero HP starts one fall")
	check((props.get("_falling_trees") as Array).size()==1,"one active falling tree")
	var repeated:Dictionary=props.apply_melee_hit(tree_id,props.to_global(Vector3(tree.center)),"axe",999.0)
	check(not repeated.get("accepted",false),"fall cannot duplicate")
	props.call("_process",1.5)
	var logs:Array=props.get("_tree_logs")
	check(logs.size()==int(tree.tree_yield) and logs.size()>=3 and logs.size()<=5,"size yield becomes 3-5 physical logs")
	var first_log:RigidBody3D=(logs[0] as WeakRef).get_ref() as RigidBody3D
	check(is_instance_valid(first_log) and first_log is RigidBody3D,"log is a physical body")
	var prompt:Dictionary=props.tree_log_action(first_log.global_position)
	check(prompt.get("key","")=="E" and prompt.get("owner","")=="tree_log","E pickup prompt")
	check(props.pickup_tree_log(first_log.global_position),"E transaction picks one log")
	check(inventory.count("wood")==1,"picked log increments wood once")
	check(not is_instance_valid(first_log) or first_log.is_queued_for_deletion(),"picked physical log consumed")
	check(bool(first_log.get_meta("pickup_claimed",false)),"picked log is atomically claimed")
	var key:=InputEventKey.new(); key.pressed=true; key.physical_keycode=KEY_B
	inventory._unhandled_input(key)
	check(inventory.is_open(),"B opens resource inventory")
	inventory._unhandled_input(key)
	check(not inventory.is_open() and inventory.count("wood")==1,"B closes without losing count")
	var expected_remaining:=int(tree.tree_yield)-1
	for id:Variant in groups.keys():
		var other:Dictionary=groups[id]
		if str(id).begins_with("tree_") and not bool(other.destroyed):
			expected_remaining+=int(other.tree_yield)
			props.apply_melee_hit(str(id),props.to_global(Vector3(other.center)),"axe",999.0)
	props.call("_process",1.5)
	var live_logs:Array=props.get("_tree_logs")
	var represented:=0
	for reference:WeakRef in live_logs:
		var body:=reference.get_ref() as RigidBody3D
		if is_instance_valid(body): represented+=int(body.get_meta("wood_units",1))
	check(live_logs.size()<=32,"mass felling keeps physical log cap")
	check(represented==expected_remaining,"log cap preserves complete wood yield %d/%d"%[represented,expected_remaining])
	print("TREE_RESOURCE57_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"stats":stats}))
	quit(0 if failures.is_empty() else 1)
