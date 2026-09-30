extends SceneTree
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func run()->void:
	var scene:Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for tick in 600:
		await physics_frame
		if scene.preview_ready:break
	if not scene.preview_ready:failures.append("main_not_ready")
	var weapons:Node=scene.preview_weapons
	if not is_instance_valid(weapons):failures.append("weapons_missing")
	if scene.weapons_status!="local_arsenal":failures.append("arsenal_status")
	if scene.population_status!="ready":failures.append("population_not_ready")
	if scene.transport_status!="ready":failures.append("transport_not_ready")
	var texture:Texture2D=load("res://scripts/weapons/scope_optic.svg")
	if texture==null or texture.get_width()==0:failures.append("scope_import_missing")
	var owners:int=scene.preview_population.hit_owners.size() if scene.preview_population!=null else 0
	if owners!=3:failures.append("three_native_hit_owners_missing")
	var arsenal:int=weapons.inventory.get_owned_ids().size() if is_instance_valid(weapons) else 0
	if arsenal!=14:failures.append("fourteen_weapons_missing")
	for tick in 90:await physics_frame
	print("SHARED_STARTUP ",JSON.stringify({"pass":failures.is_empty(),"failures":failures,"runtime_revision":scene.PREVIEW_RUNTIME_REVISION,"arsenal":arsenal,"npc_hit_owners":owners,"population":scene.population_status,"transport":scene.transport_status,"scope_texture_width":texture.get_width() if texture!=null else 0,"scope":"ordinary shared main without fixture flags; headless startup only, not rendered acceptance"}))
	scene.free();await process_frame;quit(0 if failures.is_empty() else 1)
