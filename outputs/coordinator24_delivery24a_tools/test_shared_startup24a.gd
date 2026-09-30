extends SceneTree
## Ordinary shared main startup, adapted from Coordinator23's23h smoke check.
## Does not modify flags, actor positions, inventory, input or camera ownership.
var scene:Node3D
var begun:=0
var out:=""
var done:=false
var report:Dictionary={"checks":0,"errors":[],"scope":"Ordinary shared main startup after guarded24a promotion; headless only, not rendered/FPS/OS-input acceptance."}
func _initialize()->void:
	begun=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	run.call_deferred()
func _process(_delta:float)->bool:
	if not done and Time.get_ticks_msec()-begun>25000:
		check(false,"25s startup deadline");finish()
	return false
func check(value:bool,label:String)->void:
	report.checks+=1
	if not value:report.errors.append(label);print("FAIL ",label)
func step(count:int=1)->void:
	for index:int in count:
		if done:return
		await physics_frame;await process_frame
func run()->void:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	check(parsed is Dictionary,"notes JSON parses")
	if not parsed is Dictionary:finish();return
	var notes:Dictionary=parsed
	check(notes.get("runtime_revision")=="s01-20260930-quality24a","notes revision24a")
	check(notes.get("items") is Array and notes.items.size()==5,"exactly five current notes")
	for name:String in ["arrow","hand"]:
		var path:String="res://assets/ui/cursor_"+name+".svg"
		var texture:Texture2D=load(path)
		check(FileAccess.file_exists(path+".import"),"cursor import descriptor "+name)
		check(texture!=null and texture.get_size()==Vector2(36,44),"cursor actual imported36x44 "+name)
	var scope:Texture2D=load("res://scripts/weapons/scope_optic.svg")
	check(scope!=null and scope.get_width()>0,"actual imported scope texture")
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for tick:int in 600:
		await step()
		if done:return
		if scene.preview_ready and scene.population_status=="ready" and scene.transport_status=="ready":break
	check(scene.preview_ready,"ordinary main ready")
	check(scene.PREVIEW_RUNTIME_REVISION=="s01-20260930-quality24a","main runtime revision24a")
	check(scene.PREVIEW_RUNTIME_REVISION==notes.runtime_revision,"main and notes agree")
	check(scene.population_status=="ready","population ready")
	check(scene.transport_status=="ready","transport ready")
	check(scene.weapons_status=="local_arsenal","weapon host local arsenal ready")
	var weapons:Node=scene.preview_weapons
	check(is_instance_valid(weapons),"weapon host exists")
	if not is_instance_valid(weapons):finish();return
	var ids:Array=weapons.inventory.get_owned_ids();ids.sort()
	var expected:Array=load("res://scripts/weapons/weapon_fire.gd").ids();expected.sort()
	check(ids.size()==14 and ids==expected,"all original14weapon IDs present")
	var population:RefCounted=scene.preview_population
	check(is_instance_valid(population) and population.hit_owners.size()==3,"three original hit owners")
	check(is_instance_valid(population) and population.residents!=null and population.residents.occupants().size()==3,"three registered NPC occupants")
	await step(90)
	if done:return
	var bodies:int=scene.find_children("*","CollisionObject3D",true,false).size()
	var shapes:int=scene.find_children("*","CollisionShape3D",true,false).size()
	check(bodies==377 and shapes==377,"all377original collision bodies and shapes")
	check(int(scene._block.counts.buildings)==8,"eight original buildings")
	var panel:Node=scene.find_child("PreviewUpdates",true,false)
	check(is_instance_valid(panel) and panel.has_method("get_status"),"actual update panel exists")
	if is_instance_valid(panel) and panel.has_method("get_status"):
		var status:Dictionary=panel.get_status()
		check(not status.restart_required,"no false restart-required notice")
		check(status.notes.get("items",[]).size()==5,"five notes admitted by runtime panel")
		var shown:int=0
		for item:Label in panel._items:
			if item.visible and not item.text.is_empty():shown+=1
		check(shown==5,"all five numbered labels shown")
		report.notes_panel=status
	report.runtime_revision=scene.PREVIEW_RUNTIME_REVISION
	report.arsenal=ids;report.npc_hit_owners=population.hit_owners.size()
	report.population=scene.population_status;report.transport=scene.transport_status
	report.collision_bodies=bodies;report.collision_shapes=shapes
	report.scope_texture_width=scope.get_width() if scope!=null else 0
	finish()
func finish()->void:
	if done:return
	done=true;report.valid=report.errors.is_empty();report.seconds=(Time.get_ticks_msec()-begun)/1000.0
	if not out.is_empty():
		var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SHARED_STARTUP24A ",JSON.stringify(report))
	if is_instance_valid(scene):scene.queue_free()
	quit.call_deferred(0 if report.valid else 1)
