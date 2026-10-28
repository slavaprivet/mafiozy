extends SceneTree

const Settle = preload("res://scripts/traversal/ladder_landing_settle_probe.gd")

var checks := 0
var failures: Array[String] = []
var world: Node3D
var profile := {}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world = Node3D.new(); root.add_child(world)
	_test_unconfigured_and_invalid()
	await _test_missing_support()
	await _test_moving_support()
	await _test_replaced_support_and_stale_receipt()
	await _test_nonflat_support()
	await _test_obstacle_and_ceiling()
	await _test_mask_rid_and_source_preservation()
	print("LADDER_LANDING_SETTLE_INDEPENDENT_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"profile":profile,"scope":"independent actual Godot headless physics; helper/source untouched"}))
	world.free(); quit(0 if failures.is_empty() else 1)


func _test_unconfigured_and_invalid() -> void:
	var settle := Settle.new()
	check(settle.inspect(Vector3.ZERO).reason == "space_unavailable", "unconfigured probe fails closed")
	settle.configure(world.get_world_3d().direct_space_state,0)
	check(settle.inspect(Vector3.ZERO).reason == "space_unavailable", "zero collision mask fails closed")
	settle.configure(world.get_world_3d().direct_space_state,1)
	for request: Dictionary in [
		{"feet":Vector3(NAN,0,0),"drop":.2}, {"feet":Vector3.ZERO,"drop":NAN},
		{"feet":Vector3.ZERO,"drop":-.01}, {"feet":Vector3.ZERO,"drop":.281},
	]:
		check(settle.inspect(request.feet,request.drop).reason == "invalid_request", "invalid feet/drop request rejected")


func _test_missing_support() -> void:
	var scene := Node3D.new(); world.add_child(scene); await _sync()
	var settle := _configured(1)
	check(settle.inspect(Vector3(0,.2,0)).reason == "support_missing", "missing five-point support rejected")
	scene.queue_free(); await _sync()


func _test_moving_support() -> void:
	var scene := Node3D.new(); world.add_child(scene)
	var moving := AnimatableBody3D.new(); moving.collision_layer=1; moving.collision_mask=1; scene.add_child(moving)
	_box_shape(moving,Vector3(0,-.1,0),Vector3(3,.2,3)); await _sync()
	var result: Dictionary = _configured(1).inspect(Vector3(0,.2,0))
	check(not result.valid and result.reason == "support_not_static", "moving/animatable landing support rejected: "+str(result.reason))
	scene.queue_free(); await _sync()
	var conveyor_scene := Node3D.new(); world.add_child(conveyor_scene)
	var conveyor := _floor(conveyor_scene,"conveyor",1,"conveyor"); await _sync()
	conveyor.constant_linear_velocity=Vector3(.0001,0,0); await _sync()
	var linear: Dictionary=_configured(1).inspect(Vector3(0,.2,0))
	check(not linear.valid and linear.reason=="support_not_static", "nonzero static-body linear conveyor velocity rejected")
	conveyor.constant_linear_velocity=Vector3.ZERO; conveyor.constant_angular_velocity=Vector3(0,.0001,0); await _sync()
	var angular: Dictionary=_configured(1).inspect(Vector3(0,.2,0))
	check(not angular.valid and angular.reason=="support_not_static", "nonzero static-body angular conveyor velocity rejected")
	conveyor.constant_angular_velocity=Vector3.ZERO; await _sync()
	check(_configured(1).inspect(Vector3(0,.2,0)).valid, "exact zero support velocities remain admissible")
	conveyor_scene.queue_free(); await _sync()


func _test_replaced_support_and_stale_receipt() -> void:
	var scene := Node3D.new(); world.add_child(scene)
	var original := _floor(scene,"replace-floor",1,"same-source"); await _sync()
	var settle := _configured(1)
	var receipt: Dictionary = settle.inspect(Vector3(0,.2,0))
	check(receipt.valid, "static support produces receipt before replacement")
	original.position.y = -.02; await _sync()
	check(settle.revalidate(receipt).reason == "support_changed", "moved static support invalidates exact receipt")
	original.position.y = 0.0; await _sync(); receipt = settle.inspect(Vector3(0,.2,0))
	var collider: CollisionShape3D = original.get_child(0)
	var replacement_shape := BoxShape3D.new(); replacement_shape.size=Vector3(3,.2,3); collider.shape=replacement_shape; await _sync()
	check(settle.revalidate(receipt).reason == "support_changed", "same-body shape replacement invalidates shape RID receipt")
	receipt = settle.inspect(Vector3(0,.2,0))
	var old_rid: RID = original.get_rid(); original.queue_free(); await _sync()
	var replacement := _floor(scene,"replace-floor",1,"same-source"); await _sync()
	var replaced: Dictionary = settle.revalidate(receipt)
	check(replacement.get_rid() != old_rid and not replaced.valid and replaced.reason == "support_changed", "identical-looking replacement is rejected by RID/instance receipt")
	var current_receipt: Dictionary = settle.inspect(Vector3(0,.2,0))
	var forged: Dictionary = current_receipt.duplicate(true); forged.grounded_feet += Vector3.UP*.01
	check(settle.revalidate(forged).reason == "support_changed", "stale grounded-root receipt is rejected")
	var invalid: Dictionary = current_receipt.duplicate(true); invalid.provider = "OLD_PROVIDER"
	check(settle.revalidate(invalid).reason == "invalid_receipt", "wrong-provider stale receipt rejected")
	for bad_bound: Variant in [null,"0.2",true,NAN,-.01,.281]:
		var forged_bound: Dictionary=current_receipt.duplicate(true); forged_bound.max_drop_m=bad_bound
		check(not bool(settle.revalidate(forged_bound).valid), "non-numeric/out-of-range receipt bound rejected: "+str(bad_bound))
	scene.queue_free(); await _sync()


func _test_nonflat_support() -> void:
	var scene := Node3D.new(); world.add_child(scene)
	var slope := StaticBody3D.new(); slope.collision_layer=1; slope.collision_mask=1; slope.rotation.x=deg_to_rad(50.0); scene.add_child(slope)
	_box_shape(slope,Vector3(0,-.1,0),Vector3(3,.2,3)); await _sync()
	var result: Dictionary = _configured(1).inspect(Vector3(0,.2,0))
	check(not result.valid and result.reason in ["support_not_walkable","support_outside_drop","support_height_spread"], "steep/non-flat support rejected")
	scene.queue_free(); await _sync()


func _test_obstacle_and_ceiling() -> void:
	var obstacle_scene := Node3D.new(); world.add_child(obstacle_scene)
	_floor(obstacle_scene,"floor",1,"floor")
	var obstacle := StaticBody3D.new(); obstacle.collision_layer=1; obstacle.collision_mask=1; obstacle_scene.add_child(obstacle)
	_box_shape(obstacle,Vector3(.31,.85,0),Vector3(.08,1.3,.08)); await _sync()
	var blocked: Dictionary = _configured(1).inspect(Vector3(0,.2,0))
	check(not blocked.valid and blocked.reason == "settle_blocked", "side obstacle intersecting capsule settle path rejected")
	obstacle_scene.queue_free(); await _sync()

	var ceiling_scene := Node3D.new(); world.add_child(ceiling_scene)
	_floor(ceiling_scene,"floor",1,"floor")
	var ceiling := StaticBody3D.new(); ceiling.collision_layer=1; ceiling.collision_mask=1; ceiling_scene.add_child(ceiling)
	_box_shape(ceiling,Vector3(0,1.9,0),Vector3(1.2,.12,1.2)); await _sync()
	var ceiling_result: Dictionary = _configured(1).inspect(Vector3(0,.2,0))
	check(not ceiling_result.valid and ceiling_result.reason == "settle_blocked", "low ceiling intersecting standing capsule rejected")
	ceiling_scene.queue_free(); await _sync()


func _test_mask_rid_and_source_preservation() -> void:
	var scene := Node3D.new(); world.add_child(scene)
	var floor := _floor(scene,"source-floor",2,"source-floor")
	var actor := CharacterBody3D.new(); actor.position=Vector3(0,.2,0); actor.collision_layer=2; actor.collision_mask=6; scene.add_child(actor)
	var actor_shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius=.3; capsule.height=1.9
	actor_shape.shape=capsule; actor_shape.position.y=.962; actor.add_child(actor_shape); await _sync()
	var wrong_mask: Dictionary = _configured(1,actor.get_rid()).inspect(actor.position)
	check(not wrong_mask.valid and wrong_mask.reason == "support_missing", "configured mask cannot see support on another layer")
	var settle := _configured(2,actor.get_rid())
	var source := {"lower":Vector3(3,0,4),"upper":actor.position,"collision_mask":2,
		"route_exclude_rids":[floor.get_rid()],"filters":{"areas":false,"bodies":true}}
	var source_before: Dictionary = source.duplicate(true)
	var actor_before := actor.position; var actor_layer := actor.collision_layer; var actor_mask := actor.collision_mask
	var floor_transform := floor.global_transform; var floor_layer := floor.collision_layer; var floor_mask := floor.collision_mask
	var receipt: Dictionary = settle.inspect(source.upper)
	check(receipt.valid and receipt.collision_mask == 2 and receipt.actor_rid == actor.get_rid(), "configured mask and actor RID are preserved in receipt authority")
	check(actor.position == actor_before and actor.collision_layer == actor_layer and actor.collision_mask == actor_mask, "inspect never moves actor root or changes actor filters")
	check(floor.global_transform == floor_transform and floor.collision_layer == floor_layer and floor.collision_mask == floor_mask and floor.get_meta("source_id") == "source-floor", "inspect never changes support transform, filters or source identity")
	check(source == source_before and source.lower == Vector3(3,0,4) and source.upper == actor_before, "source endpoints and filter dictionary remain byte-semantic values")
	check(receipt.authored_feet == actor_before and receipt.grounded_feet.distance_to(Vector3(actor_before.x,0,actor_before.z)) <= .00001
		and receipt.ordered_roots.front() == actor_before and receipt.ordered_roots.back().distance_to(receipt.grounded_feet) <= .000001,
		"ordered roots preserve authored endpoint and exact grounded endpoint: authored="+str(receipt.authored_feet)+" first="+str(receipt.ordered_roots.front())+" grounded="+str(receipt.grounded_feet)+" last="+str(receipt.ordered_roots.back()))
	var max_step := 0.0; var monotonic := true
	for index in range(1,receipt.ordered_roots.size()):
		var previous: Vector3=receipt.ordered_roots[index-1]; var current: Vector3=receipt.ordered_roots[index]
		max_step=maxf(max_step,previous.distance_to(current)); monotonic=monotonic and current.y<=previous.y+.000001
	check(max_step <= .040001 and monotonic and is_equal_approx(float(receipt.drop_m),.2), "settle roots are ordered, downward and bounded to four centimetres")
	check(receipt.supports.size()==5 and receipt.supports.all(func(item: Dictionary)->bool:return item.source_id=="source-floor" and item.rid==floor.get_rid()), "all five support identities retain source metadata")
	var test_only_clear := true
	for root_position: Vector3 in receipt.ordered_roots:
		if actor.move_and_collide(root_position-actor.position,true) != null:
			test_only_clear=false; break
	check(test_only_clear and actor.position==actor_before, "real CharacterBody TEST_ONLY accepts every ordered root without mutating actor root")
	var costs: Array[int] = []
	for index in 272:
		var started:=Time.get_ticks_usec(); var current: Dictionary=settle.inspect(actor_before)
		if current.valid: settle.revalidate(current)
		if index>=16: costs.append(Time.get_ticks_usec()-started)
	costs.sort(); profile={"samples":costs.size(),"inspect_plus_revalidate_p50_us":costs[127],"inspect_plus_revalidate_p95_us":costs[242]}
	settle.configure(world.get_world_3d().direct_space_state,1,actor.get_rid())
	check(settle.revalidate(receipt).reason == "query_authority_changed", "mask change invalidates prior receipt before physics reuse")
	settle.configure(world.get_world_3d().direct_space_state,2,RID())
	check(settle.revalidate(receipt).reason == "query_authority_changed", "actor RID change invalidates prior receipt")
	settle.dispose()
	check(settle.inspect(actor_before).reason=="space_unavailable" and settle.revalidate(receipt).reason=="query_authority_changed", "dispose clears query authority and rejects stale receipt")
	scene.queue_free(); await _sync()


func _configured(mask: int, actor_rid: RID = RID()) -> RefCounted:
	var settle:=Settle.new(); settle.configure(world.get_world_3d().direct_space_state,mask,actor_rid); return settle


func _floor(parent: Node3D, node_name: String, layer: int, source_id: String) -> StaticBody3D:
	var body:=StaticBody3D.new(); body.name=node_name; body.collision_layer=layer; body.collision_mask=layer; body.set_meta("source_id",source_id); parent.add_child(body)
	_box_shape(body,Vector3(0,-.1,0),Vector3(3,.2,3)); return body


func _box_shape(parent: PhysicsBody3D, center: Vector3, size: Vector3) -> void:
	var collider:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collider.shape=shape; collider.position=center; parent.add_child(collider)


func _sync() -> void:
	await physics_frame; await physics_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
