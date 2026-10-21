extends RefCounted
## A gameplay collapse threshold measured in the actual local skin channel.
const Eyes = preload("res://scripts/npc_visual/npc_death_eyes.gd")
var generation := -1
var actor_id := -1
var last: Dictionary = {}

func triggered_for(host: Node) -> bool:
	var rig: Skeleton3D = host.get("_npc_rig")
	return is_instance_valid(rig) and generation == int(host.get("lab_resets")) and actor_id == rig.get_instance_id()

func _close_eyes(host: Node) -> Dictionary:
	var actor: Node = host.get("_npc_body")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Eyes.ASSET_DIR+"assets_manifest.json"))
	for key: String in data.actors:
		var plans: Array[Dictionary] = []
		for spec: Dictionary in data.actors[key].meshes:
			var nodes := actor.find_children(spec.node,"MeshInstance3D",true,false)
			if nodes.size()!=1: break
			var node: MeshInstance3D = nodes[0]
			if not node.mesh is ArrayMesh or Eyes.mesh_digest(node.mesh)!=spec.source_digest: break
			if FileAccess.get_sha256(Eyes.ASSET_DIR+spec.resource)!=spec.resource_sha256: break
			var replacement: ArrayMesh = load(Eyes.ASSET_DIR+spec.resource).duplicate()
			for surface in node.mesh.get_surface_count(): replacement.surface_set_material(surface,node.mesh.surface_get_material(surface))
			plans.append({"node":node,"mesh":replacement})
		if plans.size()!=2: continue
		for plan: Dictionary in plans: plan.node.mesh=plan.mesh
		return {"closed":true,"actor":key,"meshes":plans.size()}
	return {"closed":false,"reason":"unsupported_original_mesh"}

func observe(host: Node, wound: Dictionary, channel: Dictionary, depth: float) -> void:
	if triggered_for(host) or bool(host.get("_npc_dead")): return
	if not channel.get("valid",false) or not channel.get("actual_hit",false) or channel.get("withdrawn",false): return
	if str(wound.get("weapon","")) not in ["sword","spear"] or not wound.get("puncture",false): return
	var thickness := float(wound.get("skin_depth",0.0))
	if thickness < 0.008 or depth/thickness < 0.70: return
	var rig: Skeleton3D = host.get("_npc_rig")
	if not is_instance_valid(rig): return
	generation=int(host.get("lab_resets"));actor_id=rig.get_instance_id()
	last={"generation":generation,"depth":depth,"thickness":thickness,"ratio":depth/thickness,"frame":Engine.get_physics_frames(),"hp_before":host.get("_npc_hp"),"eyes":_close_eyes(host)}
	# Existing death-state gate stops AI; HP is deliberately retained. The actual
	# rigid-body transition reuses the live actor, skinned mesh, wounds and armour.
	host.call("_npc_die_from_vital_wound31",Vector3(channel.entry_world),Vector3(channel.axis_world),1.0,false)
	host.call_deferred("_deep_topple29",Vector3(channel.axis_world))
	last["hp_after"]=host.get("_npc_hp")

func topple(host: Node, direction: Vector3) -> void:
	if not triggered_for(host): return
	var corpse: RigidBody3D=host.get("_npc_corpse31")
	if not is_instance_valid(corpse): return
	var horizontal:=Vector3(direction.x,0,direction.z).normalized()
	# The supported standing hull is otherwise statically balanced. Loss of
	# support is represented by finite initial angular momentum, then gravity
	# and the native body solver own the entire fall; no transform is animated.
	corpse.angular_velocity += Vector3.UP.cross(horizontal)*2.0
	corpse.sleeping=false
