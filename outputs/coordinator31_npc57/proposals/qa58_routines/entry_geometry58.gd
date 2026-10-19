extends SceneTree
var out_path := ""
var checks: Array[Dictionary] = []
var evidence: Dictionary = {"samples":[], "scope":"VFS housing geometry and native support stability; no sleep or C4 detonation acceptance"}

func _initialize() -> void: _start.call_deferred()
func check(ok: bool, name: String, detail: Variant = null) -> bool:
	checks.append({"ok":ok,"name":name,"detail":detail})
	return ok
func finish() -> void:
	evidence.checks=checks; evidence.passed=true
	for row: Dictionary in checks:
		if not row.ok: evidence.passed=false
	var file:=FileAccess.open(out_path.path_join("GEOMETRY58.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"));file.close()
	quit(0 if evidence.passed else 1)
func sample(scene: Node3D, elapsed: float) -> Dictionary:
	var homes: Node=scene.preview_homes58
	var rows: Array=[]
	for house: Node3D in homes.current_sites():
		var released: Array=[]
		var owned:=0; var physical:=0
		for body: RigidBody3D in house.pieces:
			if house.owns_collider(body):owned+=1
			var shapes:=0
			for child: Node in body.get_children():
				if child is CollisionShape3D and child.shape!=null and not child.disabled:shapes+=1
			if shapes>0:physical+=1
			if not body.freeze or body.get_meta("detached",false):released.append(str(body.name))
		var beds: Array=[]
		for bed: Dictionary in house.beds58:
			var slot: Dictionary=homes.registry58.assigned(str(bed.source_id))
			beds.append({"id":bed.bed_id,"resident":bed.source_id,"current":not slot.is_empty() and homes.registry58.current(slot),"mattress_intact":house.intact58(bed.bed_node.get_ref()),"support_intact":house.intact58(bed.bed_support.get_ref())})
		rows.append({"id":house.source_id,"pieces":house.pieces.size(),"owned":owned,"physical":physical,"released":released,"habitable":house.habitable58(),"beds":beds,"support":house._structure.diagnostics(),"initial_floor_global":house.initial_transforms[house.floors58[0].get_instance_id()]==house.floors58[0].global_transform})
	return {"elapsed_s":elapsed,"physics_frame":Engine.get_physics_frames(),"homes":rows,"registry":homes.registry58.snapshot()}

func _start() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out_path=arg.trim_prefix("--qa-out=")
	if out_path.is_empty():quit(2);return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out_path.path_join("OVERLAY.json")))
	if not check(ProjectSettings.load_resource_pack(out_path.path_join("OVERLAY.zip"),true),"load exact VFS overlay"):finish();return
	for rel: String in manifest:
		if not check(FileAccess.get_sha256("res://"+rel)==manifest[rel],"loaded overlay bytes "+rel):finish();return
	var scene: Node3D=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	var deadline: int=Time.get_ticks_msec()+90000
	while not scene.preview_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not check(scene.preview_ready,"full city ready"):finish();return
	var homes: Node=scene.preview_homes58
	if not check(is_instance_valid(homes) and homes.report.get("ok",false),"four homes prepared",homes.report if is_instance_valid(homes) else {}):finish();return
	evidence.preparation=homes.report
	check(homes.current_sites().size()==4,"four physical houses")
	var inventory: Dictionary=homes.registry58.snapshot()
	check(inventory.homes==4 and inventory.beds==10 and inventory.available_beds==10,"ten assigned live beds",inventory)
	var ids: Array=[]
	for site: Node3D in scene._c4_sites():ids.append(str(site.source_id))
	for house: Node3D in homes.current_sites():
		check(ids.has(str(house.source_id)),"C4 provider includes "+str(house.source_id))
		check(house.get_node_or_null("OriginalFoundation")==null and house.get_node_or_null("OriginalPlaza")==null,"no ghost static foundation "+str(house.source_id))
		for body: RigidBody3D in house.pieces:
			if str(body.name).begins_with("HomeEntranceRamp"):
				check(house.initial_transforms[body.get_instance_id()]==body.global_transform,"rotated ramp global frame "+str(house.source_id))
	var begin: int=Time.get_ticks_usec();var begin_frame: int=Engine.get_physics_frames()
	var next_sample:=0.0
	while float(Time.get_ticks_usec()-begin)/1000000.0<30.0:
		await physics_frame
		var elapsed: float=float(Time.get_ticks_usec()-begin)/1000000.0
		if elapsed>=next_sample:
			evidence.samples.append(sample(scene,elapsed));next_sample+=1.0
	evidence.native_elapsed_s=float(Time.get_ticks_usec()-begin)/1000000.0
	evidence.native_ticks=Engine.get_physics_frames()-begin_frame
	evidence.final=sample(scene,evidence.native_elapsed_s)
	for row: Dictionary in evidence.final.homes:
		check(row.owned==row.pieces and row.physical==row.pieces,"all sections are owned physical bodies "+str(row.id),row)
		check(row.released.is_empty() and row.habitable,"native structure stable 30s "+str(row.id),row.released)
		check(row.support.get("ok",false) and row.support.get("state","")=="stable","support graph stable "+str(row.id),row.support)
	for observed: Dictionary in evidence.samples:
		check(observed.registry.available_beds==10,"ten beds stayed current at "+str(observed.elapsed_s),observed.registry)
	check(evidence.native_ticks>=1790,"actual physics advanced for thirty seconds",evidence.native_ticks)
	finish()
