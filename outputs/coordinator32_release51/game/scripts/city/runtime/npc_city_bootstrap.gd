extends Node
## Opt-in scene child. The normal main owns every movement/transport/weapon tick.
const CityPopulation = preload("res://scripts/npc_city_population.gd")
const Hospital = preload("res://scripts/hospital/npc_hospital_geometry.gd")
const Bank = preload("res://scripts/bank_geometry/npc_bank_geometry.gd")
## DSH_SIMPLEHOSP: --city-simple-hospital=1. The hospital is the palazzo copy; the real
## site stays attached (the daily cycle refuses to build without it) but is switched off.
const SimpleHospital = preload("res://scripts/hospital/npc_simple_hospital.gd")
const OWNER_META := &"native_city_bootstrap_owner"
const WAIT_FRAMES := 1200

var status := "waiting"
var error := ""
var sites: Array[Node3D] = []
var population: RefCounted
var _scene: Node3D
var _label: Label
var _stopped := false
## DSH diagnostic seam (temporary): --city-qa=N admits only the first N packet rows.
## Absent or 0 keeps the complete pinned packet.
var _qa_limit := 0

func _ready() -> void:
	_attach.call_deferred()

func _current() -> bool:
	if _stopped or not is_inside_tree() or not is_instance_valid(_scene) or get_parent()!=_scene:
		return false
	if not _scene.has_meta(OWNER_META): return false
	var claim: Variant = _scene.get_meta(OWNER_META)
	return claim is WeakRef and claim.get_ref()==self

## DSH_STREAMLOAD: after early readiness the population keeps admitting residents inside
## population.step(). This watcher refreshes the visible status when that stream ends, so the
## HUD and population_status finish in exactly the state a fully blocking load produces. It
## costs one boolean test per frame while the stream runs and nothing when streaming is off.
var _stream_watch := false

func _process(_delta: float) -> void:
	if not _stream_watch or not _current(): return
	if population==null or not population.has_method("city_stream_complete"): return
	if not population.city_stream_complete(): return
	_stream_watch=false
	var admitted_count: int=population.hit_owners.size()
	_set_status(str(population.status),"Жители: %d" % admitted_count)
	print("CITY_STREAMLOAD_DONE ",JSON.stringify(population.city_stream_report()))

func _claim_owner() -> bool:
	if _scene.has_meta(OWNER_META):
		var previous: Variant = _scene.get_meta(OWNER_META)
		if not previous is WeakRef:
			status="failed"; error="invalid_bootstrap_owner"; return false
		var previous_owner: Variant = previous.get_ref()
		if is_instance_valid(previous_owner):
			status="failed"; error="already_attached" if previous_owner==self else "existing_bootstrap"; return false
	_scene.set_meta(OWNER_META, weakref(self))
	return true

func _attach() -> void:
	_scene=get_parent() as Node3D
	if not is_instance_valid(_scene):
		status="failed"; error="scene_parent"; return
	if not _claim_owner(): return
	print("CITY_STAGE claimed")
	for frame in WAIT_FRAMES:
		if not _current(): return
		if _scene.get("preview_ready")==true: break
		await get_tree().process_frame
	if not _current(): return
	if _scene.get("preview_ready")!=true:
		_fail("normal_scene_not_ready"); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--city-qa="):
			_qa_limit = maxi(0, int(argument.trim_prefix("--city-qa=")))
	print("CITY_STAGE preview_ready")
	_create_status_label()
	if _scene.preview_population!=null:
		_fail("existing_population"); return
	if _scene.preview_residents_enabled or _scene.preview_final_dead_contact_enabled:
		_fail("legacy_startup_enabled"); return
	# DSH_CITYTOWN: the pinned SHA is still required byte-for-byte. In town mode
	# the scene deliberately leaves some of the 75 rows out, so only the data pin
	# is demanded there; the default path keeps the exact 75-row check.
	var dsh_town: bool = _scene.has_method("city_town_active") and bool(_scene.call("city_town_active"))
	if FileAccess.get_sha256(_scene.block_data_path)!=CityPopulation.CITY_BLOCK or (not dsh_town and _scene._block.get("buildings",[]).size()!=75):
		_fail("current_city_block_pin"); return
	_set_status("loading_city", "Жители: подготовка города")
	print("CITY_STAGE attaching hospital")
	var hospital:=_attach_site(Hospital,"res://data/hospital_interior.json")
	if hospital==null:
		print("CITY_STAGE hospital_null"); return
	sites.append(hospital)
	print("CITY_STAGE hospital_ok")
	if SimpleHospital.enabled():  # DSH_SIMPLEHOSP: the hospital is the palazzo copy now
		SimpleHospital.disable_standing_hospital(_scene, hospital, Hospital.SOURCE_ID)
	var bank:=_attach_site(Bank,"res://data/bank_interior.json")
	if bank==null:
		print("CITY_STAGE bank_null"); return
	sites.append(bank)
	print("CITY_STAGE bank_ok")
	# Exactly the same registration boundary as the actual city fixture.
	await get_tree().physics_frame
	if not _current(): return
	await get_tree().physics_frame
	if not _current(): return
	if _scene.preview_population!=null:
		_fail("population_replaced_before_setup"); return
	print("CITY_STAGE setup_city")
	population=CityPopulation.new()
	_scene.preview_population=population
	# Main's existing population.step now pumps this async startup and all later AI.
	var qa_ids: Array[String] = []
	if _qa_limit > 0:
		var qa_packet: Variant = JSON.parse_string(FileAccess.get_file_as_string(CityPopulation.CITY_DIRECTORY + "session_packet.json"))
		if not qa_packet is Dictionary: _fail("city_qa_packet"); return
		for qa_row: Dictionary in qa_packet.get("rows", []):
			if qa_ids.size() >= _qa_limit: break
			qa_ids.append(str(qa_row.get("source_id", "")))
		print("CITY_QA_COHORT ", qa_ids.size())
	var admitted: bool=await population.setup_city(_scene,sites,false,qa_ids)
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
	print("CITY_BOOTSTRAP_READY ",JSON.stringify({"status":status,"admitted":admitted_count,"sites":sites.size(),"final_dead_contact":_scene.final_dead_contact_status,"city_ready":bool(population.get("city_ready")),"stream_pending":int(population.city_stream_pending()) if population.has_method("city_stream_pending") else 0}))
	# DSH_STREAMLOAD: keep watching the population while the rest of it streams in.
	_stream_watch=population.has_method("city_stream_complete") and not population.city_stream_complete()

func _attach_site(script: Script, path: String) -> Node3D:
	if not _current():
		_fail(script.SOURCE_ID + ":not_current")
		return null
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
	if is_instance_valid(_scene) and _scene.has_meta(OWNER_META):
		var claim: Variant=_scene.get_meta(OWNER_META)
		if claim is WeakRef and claim.get_ref()==self: _scene.remove_meta(OWNER_META)
	# The original main._exit_tree remains the population disposal owner.
	if is_instance_valid(_label): _label.queue_free()
