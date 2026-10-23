extends SceneTree
# Focused lifecycle unit fixture: synthetic channel, no claim of native entry.
class AcceptedHost:
	extends Node3D
	var _sword:Node3D
	var _weapon_id:String="sword"
	var committed:bool=true
	func _solid_tip_committed29()->bool:return committed
var out:String
var checks:Dictionary={}
var observations:Array=[]
var script_path:String="D:/MafioziCombat31/c33_coordination/agents/contact_perf31/pending_lifecycle31/scripts/combat/local_wound28.gd"
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg=="--integrated":script_path="res://scripts/combat/local_wound28.gd"
	run.call_deferred()
func case(label:String,weapon:String,injury:float,tip_depth:float,committed:bool=true,stale:bool=false):
	var host:=AcceptedHost.new();root.add_child(host)
	host._weapon_id=weapon;host.committed=committed
	host._sword=Node3D.new();host.add_child(host._sword)
	var rig:=Skeleton3D.new();host.add_child(rig);rig.add_bone("chest");rig.force_update_all_bone_transforms()
	var controller=load(script_path).new();controller.host=host;controller.rig=rig;controller.generation=7
	host.add_child(controller);controller.set_process(false)
	var wound_node:=Node3D.new();controller.add_child(wound_node)
	var wound:Dictionary={"node":wound_node,"bone":0,"local":Transform3D.IDENTITY,"puncture":true,"depth":injury,"skin_depth":0.3,"length":0.005}
	controller.wounds.append(wound)
	var channel:Dictionary={"valid":true,"active":true,"actual_hit":true,"withdrawn":false,"generation":6 if stale else 7,"rig_ref":weakref(rig),"node_ref":weakref(wound_node),"weapon_instance_id":host._sword.get_instance_id(),"weapon":weapon,"cut_depth":injury,"current_depth":injury}
	host.set_meta("puncture29_channel",channel)
	controller._advance_puncture29(wound,Vector3(0,0,-tip_depth))
	var outside:bool=tip_depth < -0.0001
	var cancelled:bool=committed and not stale and injury<=0.0001 and outside
	checks[label+"_cancellation"]=bool(channel.get("cancelled31",false))==cancelled
	checks[label+"_injury_unchanged"]=float(wound.depth)==injury and float(channel.cut_depth)==injury
	if cancelled:
		checks[label+"_inactive_not_withdrawn"]=not channel.valid and not channel.active and not channel.withdrawn and channel.release_reason=="pending_tip_outside"
		controller._retire_pending29()
		checks[label+"_pending_removed"]=controller.wounds.is_empty() and wound_node.is_queued_for_deletion()
	elif committed and not stale and injury>0.0001 and outside and weapon=="sword":
		checks[label+"_visible_sword_withdrawal_preserved"]=channel.withdrawn and not channel.valid and not channel.active
		controller._retire_pending29()
		checks[label+"_injury_retained"]=controller.wounds.size()==1 and not wound_node.is_queued_for_deletion()
	else:
		checks[label+"_not_cancelled_or_withdrawn"]=channel.valid and channel.active and not channel.withdrawn
	observations.append({"label":label,"cancelled":channel.get("cancelled31",false),"valid":channel.valid,"active":channel.active,"withdrawn":channel.withdrawn,"depth":channel.current_depth,"injury":wound.depth})
	controller.wounds.clear();host.queue_free()
	await process_frame
func run():
	await case("sword_empty_exit","sword",0.0,-0.02)
	await case("spear_empty_exit","spear",0.0,-0.02)
	await case("subvisible_exit","sword",0.00005,-0.02)
	await case("pending_contact_boundary","sword",0.0,-0.00005)
	await case("uncommitted_probe","sword",0.0,-0.02,false)
	await case("stale_generation","sword",0.0,-0.02,true,true)
	await case("visible_sword_exit","sword",0.02,-0.02)
	await case("visible_spear_owner_unchanged","spear",0.02,-0.02)
	var passed:bool=checks.values().all(func(v):return v)
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"observations":observations,"script":script_path},"\t"))
	await process_frame
	quit()
