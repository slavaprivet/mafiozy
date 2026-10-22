extends SceneTree
const Ownership=preload("res://scripts/transport/transport_vehicle_part_ownership.gd")
var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var vehicle:=Node3D.new(); world.add_child(vehicle)
	vehicle.set_meta("vehicle_id","car-1"); vehicle.set_meta("life_generation",7)
	var nodes: Array[Node3D]=[]
	for i in 12:
		var node:=Node3D.new(); node.name="part_"+str(i); vehicle.add_child(node); nodes.append(node)
	var bindings={"hood":nodes[0],"blast_hood":nodes[0],"trunk":nodes[1],"trunk_special":nodes[1],"blast_trunk":nodes[1],"door_left":nodes[2],"blast_door_left":nodes[2],"bumper":nodes[3],"authored_missing":null}
	var owner:=Ownership.new(); var configured:=owner.configure("car-1",7,vehicle,bindings)
	check(configured.ok and configured.distinct_nodes==4 and configured.missing_aliases==1,"configure exact node aliases/missing")
	check(not owner.configure("car-1",7,vehicle,bindings).ok,"configure once")
	var alias_lease:=owner.reserve("car-1",7,"structural",["hood","blast_hood"])
	check(alias_lease.ok and alias_lease.node_count==1 and alias_lease.nodes.size()==1 and alias_lease.nodes[0]==nodes[0],"same-node aliases return one canonical node")
	check(owner.owner("car-1",7,"blast_hood").state=="RESERVED","alias observes same physical claim")
	var conflict:=owner.reserve("car-1",7,"blast",["door_left","blast_hood"])
	check(conflict.get("error")=="owned" and owner.owner("car-1",7,"door_left").state=="AVAILABLE","failed multi-reserve is atomic")
	var door:=owner.reserve("car-1",7,"blast",["door_left"])
	check(door.ok,"second channel independent node")
	check(owner.rollback_detach_failure("car-1",7,door.lease_token).state=="ROLLED_BACK","detach failure rollback")
	check(owner.commit_detach_success("car-1",7,door.lease_token).get("error")=="stale_lease","rolled-back lease stale")
	check(owner.reserve("car-1",7,"trunk",["trunk_special"]).ok,"trunk special reserves actual trunk node")
	check(owner.reserve("car-1",7,"blast",["blast_trunk"]).get("error")=="owned","blast alias cannot duplicate trunk physical owner")
	check(owner.commit_detach_success("car-1",8,alias_lease.lease_token).get("error")=="identity","wrong life commit rejected")
	var committed:=owner.commit_detach_success("car-1",7,alias_lease.lease_token)
	check(committed.ok and committed.node_count==1 and owner.owner("car-1",7,"hood").state=="COMMITTED","commit after detach success")
	check(owner.reserve("car-1",7,"blast",["blast_hood"]).get("error")=="owned","committed node cannot copy twice")
	check(owner.reserve("car-1",7,"blast",["authored_missing"]).get("error")=="authored_missing","authored missing stays missing")
	check(owner.reserve("car-1",8,"blast",["bumper"]).get("error")=="identity","wrong life reserve rejected")
	var reset_lease:=owner.reserve("car-1",7,"blast",["bumper"])
	check(reset_lease.ok and owner.reset("car-1",7).ok,"reset clears ownership")
	check(owner.commit_detach_success("car-1",7,reset_lease.lease_token).get("error")=="stale_lease","pre-reset lease stale")
	check(owner.owner("car-1",7,"hood").state=="AVAILABLE","reset reopens committed authored node")
	var multi:=owner.reserve("car-1",7,"structural",["hood","trunk","blast_hood"])
	check(multi.ok and multi.node_count==2 and multi.nodes==[nodes[0],nodes[1]],"atomic multi-reserve returns distinct nodes in first-alias order")
	check(owner.rollback_detach_failure("car-1",7,multi.lease_token).ok,"atomic multi-reserve rolls back as one lease")
	var tokens: Dictionary={}; var started:=Time.get_ticks_usec()
	for i in 10000:
		var lease:=owner.reserve("car-1",7,"cycle",["bumper"])
		if not lease.ok or tokens.has(lease.lease_token) or not owner.rollback_detach_failure("car-1",7,lease.lease_token).ok:
			failures.append("cycle "+str(i)); break
		tokens[lease.lease_token]=true
	var cycle_us:=Time.get_ticks_usec()-started
	checks+=10000
	check(owner.stats("car-1",7).reserved_nodes==0 and owner.stats("car-1",7).open_leases==0,"cycles leave no claims")
	var deleted_lease:=owner.reserve("car-1",7,"structural",["door_left"]); check(deleted_lease.ok,"deleted-node fixture reserved")
	nodes[2].free()
	check(owner.commit_detach_success("car-1",7,deleted_lease.lease_token).get("error")=="deleted_node","deleted leased node rejected")
	check(owner.reset("car-1",7).ok and owner.reserve("car-1",7,"structural",["door_left"]).get("error")=="deleted_node","deleted bound node stays closed")
	var foreign_root:=Node3D.new(); world.add_child(foreign_root); var foreign:=Node3D.new(); foreign_root.add_child(foreign)
	var bad:=Ownership.new(); check(bad.configure("car-1",7,vehicle,{"foreign":foreign}).get("error")=="node_boundary","foreign vehicle node rejected")
	var exact_limit: Dictionary={}
	for i in 12:
		var limit_node:=Node3D.new(); vehicle.add_child(limit_node); exact_limit["p"+str(i)]=limit_node
	var limit_owner:=Ownership.new(); check(limit_owner.configure("car-1",7,vehicle,exact_limit).ok,"twelve distinct nodes accepted")
	var too_many:=exact_limit.duplicate()
	var thirteenth:=Node3D.new(); vehicle.add_child(thirteenth); too_many["p12"]=thirteenth
	var limited:=Ownership.new(); check(limited.configure("car-1",7,vehicle,too_many).get("error")=="node_limit","maximum twelve distinct nodes")
	var unstamped:=Node3D.new(); world.add_child(unstamped); var unstamped_part:=Node3D.new(); unstamped.add_child(unstamped_part)
	check(Ownership.new().configure("unstamped",1,unstamped,{"part":unstamped_part}).get("error")=="root_identity","unstamped root rejected at configure")
	var incarnation_root:=Node3D.new(); world.add_child(incarnation_root)
	incarnation_root.set_meta("vehicle_id","incarnation-car"); incarnation_root.set_meta("life_generation",11)
	var incarnation_part:=Node3D.new(); incarnation_root.add_child(incarnation_part)
	var incarnation_owner:=Ownership.new(); check(incarnation_owner.configure("incarnation-car",11,incarnation_root,{"part":incarnation_part}).ok,"incarnation fixture configured")
	var incarnation_lease:=incarnation_owner.reserve("incarnation-car",11,"blast",["part"]); check(incarnation_lease.ok,"incarnation fixture reserved")
	incarnation_root.set_meta("life_generation",12)
	check(incarnation_owner.commit_detach_success("incarnation-car",11,incarnation_lease.lease_token).get("error")=="stale_incarnation","same root reused by new life rejects old lease")
	incarnation_root.set_meta("life_generation",11); incarnation_root.remove_meta("vehicle_id")
	check(incarnation_owner.rollback_detach_failure("incarnation-car",11,incarnation_lease.lease_token).get("error")=="stale_incarnation","root metadata disappearance rejects old lease")
	incarnation_root.set_meta("vehicle_id","incarnation-car"); world.remove_child(incarnation_root)
	check(incarnation_owner.commit_detach_success("incarnation-car",11,incarnation_lease.lease_token).get("error")=="root_outside_tree","root removal from tree rejects old lease")
	world.add_child(incarnation_root); check(incarnation_owner.rollback_detach_failure("incarnation-car",11,incarnation_lease.lease_token).ok,"lease remains atomic after rejected boundary checks")
	var outside_lease:=incarnation_owner.reserve("incarnation-car",11,"structural",["part"])
	incarnation_root.remove_child(incarnation_part); world.add_child(incarnation_part)
	check(incarnation_owner.owner("incarnation-car",11,"part").get("error")=="node_outside_vehicle","reserved node outside vehicle is not reported owned/available")
	check(incarnation_owner.commit_detach_success("incarnation-car",11,outside_lease.lease_token).ok and incarnation_owner.owner("incarnation-car",11,"part").state=="COMMITTED","committed detached node remains a valid closed claim")
	var visible_before:=nodes[0].visible; var parent_before:=nodes[0].get_parent(); owner.dispose()
	check(nodes[0].visible==visible_before and nodes[0].get_parent()==parent_before,"arbiter never mutates visual nodes")
	check(owner.reserve("car-1",7,"x",["hood"]).get("error")=="lifetime","disposed host closed")
	world.free()
	print("TRANSPORT_VEHICLE_PART_OWNERSHIP ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"cycles":10000,"cycle_total_us":cycle_us,"cycle_avg_us":float(cycle_us)/10000.0,"scope":"pure part-node arbitration; no visual/physics/HP/event mutation"}))
	quit(0 if failures.is_empty() else 1)
