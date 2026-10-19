extends Node
## Opt-in scene child. The normal main owns every movement/transport/weapon tick.
const CityPopulation = preload("res://scripts/npc_city_population.gd")
const Hospital = preload("res://scripts/hospital/npc_hospital_geometry.gd")
const Bank = preload("res://scripts/bank_geometry/npc_bank_geometry.gd")
const OWNER_META := &"native_city_bootstrap_owner"
const WAIT_FRAMES := 1200

var status := "waiting"
var error := ""
var sites: Array[Node3D] = []
var population: RefCounted
var _scene: Node3D
var _label: Label
var _stopped := false

func _ready() -> void:
	_attach.call_deferred()

func _current() -> bool:
	if _stopped or not is_inside_tree() or not is_instance_valid(_scene) or get_parent()!=_scene:
		return false
	var claim: Variant = _scene.get_meta(OWNER_META, null)
	return claim is WeakRef and claim.get_ref()==self

func _attach() -> void:
	_scene=get_parent() as Node3D
	if not is_instance_valid(_scene):
		status="failed"; error="scene_parent"; return
	var previous: Variant = _scene.get_meta(OWNER_META, null)
	if previous is WeakRef and is_instance_valid(previous.get_ref()):
		status="failed"; error="existing_bootstrap"; return
	_scene.set_meta(OWNER_META, weakref(self))
	for frame in WAIT_FRAMES:
		if not _current(): return
		if _scene.get("preview_ready")==true: break
		await get_tree().process_frame
	if not _current(): return
	if _scene.get("preview_ready")!=true:
		_fail("normal_scene_not_ready"); return
	_create_status_label()
	if _scene.preview_population!=null:
		_fail("existing_population"); return
	if _scene.preview_residents_enabled or _scene.preview_final_dead_contact_enabled:
		_fail("legacy_startup_enabled"); return
	if FileAccess.get_sha256(_scene.block_data_path)!=CityPopulation.CITY_BLOCK or _scene._block.get("buildings",[]).size()!=75:
		_fail("current_city_block_pin"); return
	_set_status("loading_city", "Жители: подготовка города")
	var hospital:=_attach_site(Hospital,"res://data/hospital_interior.json")
	if hospital==null: return
	sites.append(hospital)
	var bank:=_attach_site(Bank,"res://data/bank_interior.json")
	if bank==null: return
	sites.append(bank)
	# Exactly the same registration boundary as the actual city fixture.
	await get_tree().physics_frame
	if not _current(): return
	await get_tree().physics_frame
	if not _current(): return
	if _scene.preview_population!=null:
		_fail("population_replaced_before_setup"); return
	population=CityPopulation.new()
	_scene.preview_population=population
	# Main's existing population.step now pumps this async startup and all later AI.
	var admitted: bool=await population.setup_city(_scene,sites,false)
	if not _current(): return
	if _scene.preview_population!=population:
		population.dispose()
		_fail("population_replaced_during_setup"); return
	if not admitted:
		_fail("population:"+str(population.error)); return
	var admitted_count: int=population.hit_owners.size()
	_set_status(str(population.status),"Жители: %d" % admitted_count)
	# Source final_dead_contact_port is bounded to 128 records. Root may bind only
	# after its separately reviewed 512-record port merge; this hook does not opt in.
	_scene.final_dead_contact_status="city_disabled_until_reviewed_512_port"
	print("CITY_BOOTSTRAP_READY ",JSON.stringify({"status":status,"admitted":admitted_count,"sites":sites.size(),"final_dead_contact":_scene.final_dead_contact_status}))

func _attach_site(script: Script, path: String) -> Node3D:
	if not _current(): return null
	var identity: String=script.SOURCE_ID
	var building: Dictionary={}
	for row: Dictionary in _scene._block.buildings:
		if row.id!=identity: continue
		if not building.is_empty():
			_fail(identity+":duplicate_building"); return null
		building=row
	if building.is_empty():
		_fail(identity+":missing_building"); return null
	var visual: Node3D
	var envelopes: Array[Node]=[]
	var indices: Dictionary={}
	for node: Node in _scene.get_children():
		if node.get_meta("source_id","")!=identity: continue
		if node is StaticBody3D:
			var index: int=int(node.get_meta("source_index",-1))
			if index<0 or indices.has(index):
				_fail(identity+":source_envelope_identity"); return null
			indices[index]=true; envelopes.append(node)
		elif node is Node3D and node.get_child_count()==1:
			if is_instance_valid(visual):
				_fail(identity+":duplicate_original_visual"); return null
			visual=node.get_child(0) as Node3D
	if not is_instance_valid(visual) or envelopes.size()!=building.collisionBodiesM.size():
		_fail(identity+":original_placement"); return null
	for body: Dictionary in building.collisionBodiesM:
		if not indices.has(int(body.sourceIndex)):
			_fail(identity+":source_envelope_index"); return null
	var site: Node3D=script.new()
	_scene.add_child(site)
	if not site.attach_existing(visual,building,FileAccess.get_file_as_bytes(path)) or not site.ready_for_use:
		var details: String=str(site.errors)
		site.restore_original(); site.free()
		_fail(identity+":source_interior:"+details); return null
	# Only this exact source building's validated old envelopes are replaced.
	# Failed attachment above keeps every original envelope in the scene.
	for node: Node in envelopes: node.free()
	return site

func _create_status_label() -> void:
	var stats: Variant=_scene.get("_stats")
	if not stats is Label or not is_instance_valid(stats.get_parent()): return
	_label=Label.new()
	_label.name="CityPopulationStatus"
	_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size",12)
	stats.get_parent().add_child(_label)

func _set_status(value: String, visible_text: String) -> void:
	status=value
	if _current() and (_scene.preview_population==null or _scene.preview_population==population):
		_scene.population_status=value
	if is_instance_valid(_label): _label.text=visible_text

func _fail(reason: String) -> void:
	error=reason
	_set_status("city_failed:"+reason,"Жители: запуск не завершён")
	print("CITY_BOOTSTRAP_FAILED ",reason)

func snapshot() -> Dictionary:
	return {"status":status,"error":error,"sites":sites.size(),"population_bound":is_instance_valid(_scene) and population!=null and _scene.preview_population==population,"final_dead_contact_enabled":false}

func _exit_tree() -> void:
	_stopped=true
	if is_instance_valid(_scene):
		var claim: Variant=_scene.get_meta(OWNER_META,null)
		if claim is WeakRef and claim.get_ref()==self: _scene.remove_meta(OWNER_META)
	# The original main._exit_tree remains the population disposal owner.
	if is_instance_valid(_label): _label.queue_free()
