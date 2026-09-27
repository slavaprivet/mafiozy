extends SceneTree
const Ragdoll = preload("res://scripts/character_physics/exit_ragdoll_body.gd")
const Player = preload("res://scripts/preview_player.gd")
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const DIR := "res://assets/npc_visual/session/"
const PREPARED := "3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0"
var checks := 0
var errors: Array[String] = []
var rows: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)

func dimensions(rag: RefCounted) -> Dictionary:
	return {"dimensions":rag._dimensions.duplicate(true),"frames":rag._rest_body.duplicate(true)}

func schemes(skeleton: Skeleton3D, world: Node3D, label: String) -> void:
	var meshes: Array[MeshInstance3D] = []
	var skins: Array[Skin] = []
	for node: Node in skeleton.get_parent().find_children("*","MeshInstance3D",true,false):
		if node.skin != null:
			meshes.append(node); skins.append(node.skin)
	check(not meshes.is_empty(),label+" actual skins present")
	var baseline := Ragdoll.new()
	var first := baseline.configure(skeleton,world)
	check(first.ok,label+" native actual original scheme admitted "+str(first))
	if not first.ok: baseline.dispose(); return
	var expected := dimensions(baseline)
	var frames := baseline.capture_world_frames()
	check(frames.size() == 28,label+" captures28")
	check(baseline.start(frames,Vector3.ZERO).ok,label+" actual rig can activate")
	baseline.reset(); baseline.dispose()
	for scheme: String in ["named","indexed","mixed"]:
		for m in meshes.size():
			var skin := Skin.new()
			for b in skins[m].get_bind_count():
				var name := str(skins[m].get_bind_name(b))
				var bone := skeleton.find_bone(name) if not name.is_empty() else skins[m].get_bind_bone(b)
				check(bone >= 0 and bone < 28,label+" actual valid mapping")
				if scheme == "named" or (scheme == "mixed" and b%2 == 0):
					skin.add_named_bind(skeleton.get_bone_name(bone),skins[m].get_bind_pose(b))
					# Named binding takes precedence over an unrelated numeric slot.
					skin.set_bind_bone(b,(bone+7)%28)
				else: skin.add_bind(bone,skins[m].get_bind_pose(b))
			meshes[m].skin = skin
		var rag := Ragdoll.new()
		var result := rag.configure(skeleton,world)
		check(result.ok,label+" "+scheme+" accepted")
		if result.ok:
			check(dimensions(rag) == expected,label+" "+scheme+" exact identical fitted skin geometry")
			check(rag.capture_world_frames() == frames,label+" "+scheme+" preserves actual rig poses")
		rag.dispose()
	# These invalid binds never reach a renderer tick: restored synchronously.
	for invalid in ["missing_name","negative_index","upper_index"]:
		var bad: Skin = meshes[0].skin.duplicate()
		if invalid == "missing_name":
			bad.set_bind_name(0,"nonexistent_bone"); bad.set_bind_bone(0,0)
		else:
			bad.set_bind_name(0,""); bad.set_bind_bone(0,-1 if invalid == "negative_index" else 28)
		var previous := meshes[0].skin
		meshes[0].skin = bad
		var rag := Ragdoll.new()
		check(not rag.configure(skeleton,world).ok,label+" "+invalid+" rejects without bone0 guess")
		check(world.find_children("PhysicalCharacterBody","Node3D",true,false).is_empty(),label+" rejection creates no partial pool")
		meshes[0].skin = previous
		check(rag.configure(skeleton,world).ok,label+" configure retry after rejection stays atomic")
		rag.dispose()
	for m in meshes.size(): meshes[m].skin = skins[m]
	rows.append({"actor":label,"meshes":meshes.size(),"schemes":["original","named","indexed","mixed"]})

func run() -> void:
	var before := FileAccess.get_sha256("res://scripts/character_physics/exit_ragdoll_body.gd")
	var world := Node3D.new()
	root.add_child(world)
	var player := Player.new()
	world.add_child(player)
	player.set_physics_process(false)
	schemes(player._pose_skeleton,world,"hero")
	player.free()
	var prepared := FileAccess.get_file_as_bytes(DIR+"prepared/manifest.json")
	check(Loader._hash(prepared) == PREPARED,"genuine NPC prepared manifest pinned")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"visual_manifest.json"))
	check(manifest.entries.size() == 3,"three genuine NPC rows")
	for entry: Dictionary in manifest.entries:
		var admitted := Cache.load_verified(prepared,PREPARED,entry.bridge_id,entry.descriptor_sha256,DIR+"prepared")
		check(admitted.ok,"actual cache source receipt "+entry.bridge_id)
		if not admitted.ok: continue
		var actor: Dictionary = admitted.cache.instantiate_actor()
		check(actor.ok,"actual cache actor "+entry.bridge_id)
		if actor.ok:
			world.add_child(actor.visual)
			schemes(actor.skeleton,world,entry.bridge_id)
			actor.visual.free()
		admitted.cache.dispose()
	world.free()
	check(FileAccess.get_sha256("res://scripts/character_physics/exit_ragdoll_body.gd") == before,"unchanged module hash throughout")
	var report := {"checks":checks,"passed":errors.is_empty(),"errors":errors,"module_sha256":before,"rows":rows,"limits":"Actual cached rigs and source receipts; configure/start/reset only, no NPC physical floor admission or LIVE performance claim"}
	var out := FileAccess.open("../../outputs/exit_ragdoll_skin_bindings.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t")+"\n"); out.close()
	print("EXIT_RAGDOLL_SKIN_BINDINGS ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
