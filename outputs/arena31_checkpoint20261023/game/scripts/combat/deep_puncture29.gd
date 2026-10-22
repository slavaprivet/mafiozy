extends RefCounted
## A gameplay collapse threshold measured in the actual local skin channel.
const Eyes = preload("res://scripts/npc_visual/npc_death_eyes.gd")
const Geometry = preload("res://scripts/combat/puncture29.gd")
const Ragdoll = preload("res://scripts/combat/npc_ragdoll31.gd")
const VITAL_DEPTH_RATIO := 0.90
var generation := -1
var actor_id := -1
var last: Dictionary = {}
var ragdoll: Node
var eye_plans: Array[Dictionary] = []
var prepared_actor := -1
var prepare_status: Dictionary = {}

func prepare(host: Node) -> void:
	var actor: Node=host.get("_npc_body")
	if not is_instance_valid(actor) or prepared_actor==actor.get_instance_id():return
	var started:=Time.get_ticks_usec()
	prepared_actor=actor.get_instance_id()
	eye_plans.clear()
	ragdoll=Ragdoll.new();ragdoll.name="NpcRagdoll31"
	actor.add_child(ragdoll);ragdoll.prepare(host)
	_prepare_eyes(host)
	prepare_status={"total_usec":Time.get_ticks_usec()-started,"eyes":eye_plans.size(),"rigid":ragdoll.status}

func start_corpse(host: Node,life_id: int,point: Vector3,direction: Vector3,speed: float) -> void:
	if not is_instance_valid(ragdoll):
		host.set("_npc_corpse_pending31",false)
		return
	var started:=Time.get_ticks_usec()
	var eyes:=_close_eyes(host)
	last.eyes=eyes
	var accepted:bool=ragdoll.start(life_id,point,direction,speed)
	last.corpse={"accepted":accepted,"total_usec":Time.get_ticks_usec()-started,"eyes":eyes,"rigid":ragdoll.status}

func triggered_for(host: Node) -> bool:
	var rig: Skeleton3D = host.get("_npc_rig")
	return is_instance_valid(rig) and generation == int(host.get("lab_resets")) and actor_id == rig.get_instance_id()

func _prepare_eyes(host: Node) -> void:
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
			plans.append({"node":node,"source":node.mesh,"mesh":replacement})
		if plans.size()!=2: continue
		eye_plans=plans
		return

func _close_eyes(_host: Node) -> Dictionary:
	var started:=Time.get_ticks_usec()
	if eye_plans.size()!=2:return {"closed":false,"reason":"not_prepared","usec":Time.get_ticks_usec()-started}
	for plan:Dictionary in eye_plans:
		if not is_instance_valid(plan.node) or (plan.node.mesh!=plan.source and plan.node.mesh!=plan.mesh):return {"closed":false,"reason":"changed_mesh","usec":Time.get_ticks_usec()-started}
	for plan:Dictionary in eye_plans:plan.node.mesh=plan.mesh
	return {"closed":true,"meshes":eye_plans.size(),"usec":Time.get_ticks_usec()-started}

func observe(host: Node, wound: Dictionary, channel: Dictionary, depth: float) -> void:
	if triggered_for(host) or bool(host.get("_npc_dead")): return
	if not channel.get("valid",false) or not channel.get("actual_hit",false) or channel.get("withdrawn",false): return
	if str(wound.get("weapon","")) not in ["sword","spear"] or not wound.get("puncture",false): return
	var rig: Skeleton3D = host.get("_npc_rig")
	if not is_instance_valid(rig) or int(channel.get("generation",-1)) != int(host.get("lab_resets")): return
	if channel.get("rig_ref",null) == null or channel.rig_ref.get_ref() != rig: return
	if channel.get("node_ref",null) == null or channel.node_ref.get_ref() != wound.get("node"): return
	var family := Geometry._family(str(wound.get("part","")))
	if str(wound.get("part","")).begins_with("spine"): family="torso"
	if family not in ["head","torso"]: return
	var thickness := float(wound.get("skin_depth",0.0))
	if thickness < 0.008 or depth/thickness < VITAL_DEPTH_RATIO: return
	generation=int(host.get("lab_resets"));actor_id=rig.get_instance_id()
	last={"generation":generation,"part":wound.part,"family":family,"depth":depth,"thickness":thickness,"ratio":depth/thickness,"frame":Engine.get_physics_frames(),"hp_before":host.get("_npc_hp")}
	last.eyes=_close_eyes(host)
	# Existing death-state gate stops AI; HP is deliberately retained. The actual
	# rigid-body transition reuses the live actor, skinned mesh, wounds and armour.
	host.call("_npc_die_from_vital_wound31",Vector3(channel.entry_world),Vector3(channel.axis_world),float(wound.get("accepted_speed31",0.0)),false)
	last["hp_after"]=host.get("_npc_hp")

func topple(host: Node, direction: Vector3) -> void:
	# Compatibility hook: articulated gravity and measured impact now own fall.
	if is_instance_valid(host) and direction.is_finite():return
