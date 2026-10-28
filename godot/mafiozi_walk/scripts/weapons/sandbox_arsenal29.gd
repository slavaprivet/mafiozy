extends RefCounted
## The polygon arsenal returns its same physical item from ground ownership.
## This is opt-in scene policy. Castle inventory and nearby E pickup keep theirs.
const Finish=preload("res://scripts/weapons/weapon_model_finish31.gd")

static func reclaim_melee(host:Node)->bool:
	if not bool(host.get("_sword_grounded")):return true
	return bool(host.call("cancel_ground_drop31"))

static func reclaim_bow(host:Node)->bool:
	if not bool(host.get("_grounded")):return true
	var model:Node3D=host.get("_bow")
	var items:Array=host.get("_ground_items")
	for entry:Dictionary in items:
		if entry.get("kind")=="bow" and entry.get("node")==model and is_instance_valid(model):
			Finish.recover_ground_drop28(model,host.get("_world"))
			items.erase(entry)
			host.set("_grounded",false)
			model.visible=true
			host.call("_update_hint")
			return true
	return false

static func reclaim_shield(host:Node)->bool:
	var body:RigidBody3D=host.get("_shield_drop_body31")
	if not is_instance_valid(body):return true
	if bool(host.get("_shield_broken")) or bool(host.call("_hand_lost31",&"right")):return false
	var model:Node3D
	for child:Node in body.get_children():
		if child is Node3D and not child is CollisionShape3D:
			model=child;break
	if not is_instance_valid(model):return false
	Finish.recover_ground_drop28(model,host.get("_world"))
	host.set("_shield",model)
	host.set("_shield_drop_body31",null)
	return true
