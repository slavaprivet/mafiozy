extends SceneTree
## Source-only loaded-scene benchmark. Root owns the sole GPU/run slot.
## Use unchanged for baseline and candidate, with these USER arguments:
## --qa45-out=<directory> --qa45-variant=baseline|candidate
## --qa45-manifest=<absolute ASSEMBLY.json or PREPARED.json>
## Optional --qa45-revision=<expected revision> --qa45-baseline-report=<performance45.json>
## Same setup helpers as door_perf43.gd, SHA318695f918fb63a9be088f43a18c6e787bb45110a33472e503327cb74e1039cb.
## Shot provenance: SOURCE_WITNESS.json SHA906d6beb3a01a7b28df1596991bfec49963546cdc0dd371b955514099b3da360.
## Fixture placement changes only the player/camera before warmup. No NPC/content
## relocation, collision bypass, forced release, freeze or reduced population.
## site.explode is a declared performance workload, NOT native weapon admission.
## V2 records authored geometry on the site's ready signal before ANY physics
## advance. Intact support may legitimately release an existing unsupported part;
## record its exact identity/geometry and require the SAME candidate release set.
const WARMUP_FRAMES := 120
const IDLE_FRAMES := 240
const DAMAGE_FRAMES := 600
const DEADLINE_MS := 30000
const FIELDS := ["frame_ms", "process_ms", "physics_ms", "draw_calls", "render_primitives", "static_bytes", "static_peak_bytes", "video_bytes", "object_count", "node_count", "resource_count", "orphan_node_count", "physics_active_objects", "physics_collision_pairs", "physics_islands"]
const SHOTS := [
	{"frame":0,"tile":Vector2i(0,2),"role":"core","point":Vector3(.25025,-1.048,.17),"removed":[Vector2i(0,2),Vector2i(0,1),Vector2i(0,3),Vector2i(1,2)]},
	{"frame":120,"tile":Vector2i(0,0),"role":"sill","point":Vector3(-.61025,-.803,.43),"removed":[Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(2,0)]},
	{"frame":240,"tile":Vector2i(3,2),"role":"mullion","point":Vector3(.01125,.524,.2925),"removed":[Vector2i(3,2),Vector2i(3,1),Vector2i(2,2),Vector2i(4,2)]}
]
var output := "user://performance45"
var variant := ""
var manifest_path := ""
var expected_revision := ""
var baseline_path := ""
var manifest: Dictionary = {}
var baseline: Dictionary = {}
var game: Node3D
var player: CharacterBody3D
var camera: Camera3D
var host: Node
var panel: RigidBody3D
var started := 0
var done := false
var phase_name := "startup"
var errors: Array[String] = []
var phases: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var evidence: Dictionary = {}
var input_saved := false
var player_input_before := false
var game_input_before := false
var capture_before := false
var initial_bodies := 0
var initial_shapes := 0
var authored_geometry: Dictionary = {}
var authored_site_id := 0
var stable_body_keys: Dictionary = {}
var authored_body_rows: Dictionary = {}

func _initialize() -> void:
	started=Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa45-out="): output=arg.trim_prefix("--qa45-out=")
		elif arg.begins_with("--qa45-variant="): variant=arg.trim_prefix("--qa45-variant=")
		elif arg.begins_with("--qa45-manifest="): manifest_path=arg.trim_prefix("--qa45-manifest=")
		elif arg.begins_with("--qa45-revision="): expected_revision=arg.trim_prefix("--qa45-revision=")
		elif arg.begins_with("--qa45-baseline-report="): baseline_path=arg.trim_prefix("--qa45-baseline-report=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if FileAccess.file_exists(output.path_join("performance45.json")):
		push_error("performance45 requires a fresh output directory; previous report preserved")
		quit(2); return
	_marker(); _run.call_deferred()

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec()-started>=DEADLINE_MS:
		errors.append("30_second_deadline_in_"+phase_name); _finish()
	return false

func _require(ok: bool, reason: String) -> bool:
	if not ok: errors.append(reason)
	return ok

func _write(name: String, data: Dictionary) -> void:
	var file:=FileAccess.open(output.path_join(name),FileAccess.WRITE)
	if file==null: errors.append("write_failed:"+name); return
	file.store_string(JSON.stringify(data,"\t")); file.close()

func _marker() -> void:
	_write("performance45_active.json",{"pid":OS.get_process_id(),"phase":phase_name,"variant":variant,"finished":done,"unix_seconds":Time.get_unix_time_from_system(),"ticks_ms":Time.get_ticks_msec()})

func _v(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _transform(value: Transform3D) -> Dictionary:
	return {"origin":_v(value.origin),"basis_x":_v(value.basis.x),"basis_y":_v(value.basis.y),"basis_z":_v(value.basis.z)}

func _path(value: String) -> String:
	return ProjectSettings.globalize_path(value).replace("\\","/").simplify_path().trim_suffix("/").to_lower()

func _near_array(a: Variant, b: Variant, tolerance: float) -> bool:
	if not a is Array or not b is Array or a.size()!=b.size(): return false
	for index in a.size():
		if not is_finite(float(a[index])) or not is_finite(float(b[index])) or absf(float(a[index])-float(b[index]))>tolerance: return false
	return true

func _same_camera(a: Dictionary, b: Dictionary) -> bool:
	if not b.has("transform"): return false
	for key: String in ["fov","near","far","yaw","pitch"]:
		if not b.has(key) or absf(float(a[key])-float(b[key]))>.00001: return false
	if not _near_array(a.actor_local_after_warmup,b.get("actor_local_after_warmup",[]),.001): return false
	for key: String in ["origin","basis_x","basis_y","basis_z"]:
		if not _near_array(a.transform[key],b.transform.get(key,[]),.00001 if key!="origin" else .001): return false
	return true

func _provenance() -> bool:
	if not _require(variant in ["baseline","candidate"] and not manifest_path.is_empty(),"explicit_variant_and_manifest_required"): return false
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not _require(parsed is Dictionary,"readable_manifest_required"): return false
	manifest=parsed
	var pins: Variant=manifest.get("source_pins",manifest.get("expected_source_pins",{}))
	if not _require(pins is Dictionary and not pins.is_empty(),"manifest_source_pins_required"): return false
	if not _require(_path(str(manifest.get("game","")))==_path("res://"),"manifest_project_path_mismatch"): return false
	if expected_revision.is_empty(): expected_revision=str(manifest.get("revision",""))
	if not _require(not expected_revision.is_empty() and expected_revision==str(manifest.get("revision","")),"manifest_revision_mismatch"): return false
	var mismatches: Array[String]=[]
	for relative: String in pins:
		if relative.is_absolute_path() or relative.contains("..") or relative.contains(":"):
			mismatches.append(relative); continue
		if FileAccess.get_sha256("res://".path_join(relative))!=pins[relative]: mismatches.append(relative)
	evidence.provenance={"manifest":manifest_path,"manifest_sha256":FileAccess.get_sha256(manifest_path),"verified_source_count":pins.size(),"source_pin_mismatches":mismatches,"fixture_path":get_script().resource_path,"fixture_sha256":FileAccess.get_sha256(get_script().resource_path),"setup_source":"outputs/coordinator26_palazzo_only43/qa/door_perf43.gd","setup_source_sha256":"318695f918fb63a9be088f43a18c6e787bb45110a33472e503327cb74e1039cb","witness_source":"outputs/buildings3_frames44/evidence/SOURCE_WITNESS.json","witness_sha256":"906d6beb3a01a7b28df1596991bfec49963546cdc0dd371b955514099b3da360"}
	if not _require(mismatches.is_empty(),"loaded_sources_do_not_match_manifest"): return false
	if not baseline_path.is_empty():
		var prior: Variant=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		if not _require(prior is Dictionary,"baseline_report_unreadable"): return false
		baseline=prior
		if not _require(baseline.get("status")=="MEASUREMENT_COMPLETE_COMPARE_REQUIRED" and baseline.get("variant")=="baseline" and baseline.get("failures",["missing"]).is_empty(),"baseline_measurement_incomplete"): return false
	return true

func _settings() -> Dictionary:
	var result: Dictionary={}
	for item: Dictionary in ProjectSettings.get_property_list():
		var setting: String=str(item.name)
		if setting.begins_with("rendering/") or setting.begins_with("display/window/") or setting.begins_with("physics/") or setting.begins_with("application/run/"):
			result[setting]=ProjectSettings.get_setting(setting)
	result.actual_renderer=RenderingServer.get_current_rendering_method()
	result.actual_vsync=DisplayServer.window_get_vsync_mode()
	result.actual_window_size=str(DisplayServer.window_get_size())
	result.actual_viewport_size=str(root.get_visible_rect().size)
	result.actual_max_fps=Engine.max_fps; result.actual_time_scale=Engine.time_scale
	result.actual_physics_ticks_per_second=Engine.physics_ticks_per_second
	return result

func _content() -> Dictionary:
	var population: RefCounted=game.get("preview_population")
	var rows: Array=[]; var hp_count:=0; var live_hp:=0
	if population!=null:
		if population.get("residents")!=null: rows=population.residents.snapshot().get("rows",[])
		var owners: Array=population.get("hit_owners"); hp_count=owners.size()
		for owner: RefCounted in owners:
			if not owner._current(owner.get("_binding")).is_empty(): live_hp+=1
	var ids: Array[String]=[]; var actors: Array[Dictionary]=[]
	for row: Dictionary in rows:
		ids.append(str(row.source_id))
		actors.append({"id":row.source_id,"position":_v(row.position) if row.position is Vector3 else null,"generation":row.life_generation,"status":row.status})
	ids.sort()
	var block: Dictionary=game.get("_block")
	var ok: bool=ids.size()==3 and ids.has("resident_72") and ids.has("resident_169") and ids.has("resident_252") and hp_count==3 and live_hp==3 and block.buildings.is_empty() and block.decor.size()==8
	return {"ok":ok,"npc_ids":ids,"actors":actors,"hp_owners":hp_count,"live_hp_owners":live_hp,"legacy_buildings":block.buildings.size(),"decor":block.decor.size(),"palazzo":host.snapshot(),"water_status":game.get("water_status")}

func _lighting() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for node: Node in game.get_children():
		if node is DirectionalLight3D:
			result.append({"name":str(node.name),"transform":_transform(node.global_transform),"color":str(node.light_color),"energy":node.light_energy,"shadows":node.shadow_enabled})
	return result

func _observe_added_node(node: Node) -> void:
	var script: Script=node.get_script() as Script
	if script==null or script.resource_path!="res://scripts/destruction/palazzo/palazzo_structural_site.gd": return
	# A read-only signal observer catches the real site after configure() and
	# before the main scene can yield to its first physics frame. No owner pause.
	node.ready.connect(_capture_authored_geometry.bind(node),CONNECT_ONE_SHOT)

func _capture_authored_geometry(site: Node3D) -> void:
	if not _require(authored_site_id==0,"multiple_authored_sites"): return
	authored_site_id=site.get_instance_id()
	var support: Dictionary=site._structure.diagnostics()
	_require(int(support.get("advance_calls",-1))==0 and int(support.get("released_total",-1))==0,"authored_geometry_must_precede_first_support_advance")
	authored_geometry=_geometry(site)
	authored_geometry["capture_route"]="actual_site.ready before first support advance or physics; observer only"
	authored_geometry["physics_frame"]=Engine.get_physics_frames()

func _body_shapes(body: RigidBody3D) -> Array[Dictionary]:
	var shapes: Array[Dictionary]=[]
	for child: Node in body.get_children():
		if not child is CollisionShape3D or child.shape==null: continue
		if not _require(child.shape is BoxShape3D,"original_non_box_shape"): return []
		shapes.append({"transform":_transform(child.transform),"size":_v(child.shape.size),"disabled":child.disabled,"role":str(child.get_meta("finished_role","source_box"))})
	return shapes

func _geometry(site: Node3D) -> Dictionary:
	var bodies: Array[Dictionary]=[]
	for ref: WeakRef in site._owned_bodies.values():
		var body: RigidBody3D=ref.get_ref()
		if not _require(is_instance_valid(body),"initial_owned_body_missing"): return {}
		var key: String="owned_%04d"%bodies.size()
		stable_body_keys[body.get_instance_id()]=key
		var wall: Variant=body.get_meta("wall_panel") if body.has_meta("wall_panel") else null
		var row: Dictionary={"key":key,"name":str(body.name),"wall_name":str(wall.name) if is_instance_valid(wall) else "","pose":_transform(body.transform),"section_size":_v(body.get_meta("section_size")),"shapes":_body_shapes(body),"layer":body.collision_layer,"mask":body.collision_mask,"frozen":body.freeze,"detached":body.get_meta("detached",false)}
		bodies.append(row); authored_body_rows[key]=row
	var native_stats: Dictionary=site.get_stats()
	initial_bodies=int(native_stats.native_body_count); initial_shapes=int(native_stats.native_shape_count)
	_require(native_stats.pieces==97 and native_stats.pool==560 and initial_bodies==657,"original_97_sections_560_pool_required")
	var data: Dictionary={"owned_bodies":bodies,"site_transform":_transform(site.global_transform),"foundation":_transform(site.get_node("OriginalFoundation").global_transform),"plaza":_transform(site.get_node("OriginalPlaza").global_transform)}
	# Keep native names in evidence. Auto-generated pooled-node names are not a
	# cross-process identity: stable owner order plus exact geometry provides it.
	var comparable: Array[Dictionary]=[]
	for row: Dictionary in bodies:
		var item: Dictionary=row.duplicate(); item.erase("name"); item.erase("wall_name"); comparable.append(item)
	var hash_data: Dictionary=data.duplicate(); hash_data.owned_bodies=comparable
	return {"ordered_geometry_sha256":JSON.stringify(hash_data).sha256_text(),"owned_body_count":initial_bodies,"collision_shape_count":initial_shapes,"pieces":native_stats.pieces,"pool":native_stats.pool,"support":site._structure.diagnostics(),"geometry_data":data,"native_names_in_geometry_hash":false}

func _initial_physics_state() -> Dictionary:
	var released: Array[Dictionary]=[]; var released_keys: Array[String]=[]; var release_signature: Array[Dictionary]=[]
	var frozen_geometry: Array[Dictionary]=[]
	var active:=0; var sleeping:=0; var unfrozen:=0; var frozen:=0; var support_released:=0; var detached:=0; var parked:=0
	for ref: WeakRef in host.site._owned_bodies.values():
		var body: RigidBody3D=ref.get_ref()
		if not _require(is_instance_valid(body) and stable_body_keys.has(body.get_instance_id()),"pre_damage_authored_body_identity_missing"): return {}
		var key: String=stable_body_keys[body.get_instance_id()]
		var released_by_support: bool=body.get_meta("support_released",false)
		var is_detached: bool=body.get_meta("detached",false)
		if body.freeze: frozen+=1
		else:
			unfrozen+=1
			if body.sleeping: sleeping+=1
			else: active+=1
		if released_by_support: support_released+=1
		if is_detached: detached+=1
		if body.get_meta("parked",false): parked+=1
		var state: Dictionary={"key":key,"name":str(body.name),"shapes":_body_shapes(body),"layer":body.collision_layer,"mask":body.collision_mask,"detached":is_detached,"support_released":released_by_support}
		if released_by_support or is_detached or not body.freeze:
			released_keys.append(key); release_signature.append(state)
			released.append({"identity":state,"authored_geometry":authored_body_rows[key],"current_pose":_transform(body.transform),"linear_velocity":_v(body.linear_velocity),"angular_velocity":_v(body.angular_velocity),"frozen":body.freeze,"sleeping":body.sleeping,"parked":body.get_meta("parked",false)})
		else:
			state.erase("name"); state["pose"]=_transform(body.transform); frozen_geometry.append(state)
	released_keys.sort()
	var support: Dictionary=host.site._structure.diagnostics()
	_require(support.get("ok",false) and not support.get("busy",true),"initial_intact_support_must_be_stable")
	_require(support_released==int(support.get("released_total",-1)) and released_keys.size()==support_released,"initial_release_observation_matches_owner_count")
	return {"released_keys":released_keys,"released_bodies":released,"release_geometry_sha256":JSON.stringify(release_signature).sha256_text(),"remaining_frozen_geometry_sha256":JSON.stringify(frozen_geometry).sha256_text(),"support_released_count":support_released,"detached_count":detached,"unfrozen_count":unfrozen,"active_awake_owned_count":active,"sleeping_unfrozen_owned_count":sleeping,"frozen_owned_count":frozen,"parked_count":parked,"native_physics_active_objects":Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),"support":support,"dynamic_pose_in_comparison_hash":false}

func _run() -> void:
	if not _require(DisplayServer.get_name()!="headless","gpu_required_no_headless_perf_acceptance") or not _provenance(): _finish(); return
	evidence.engine=Engine.get_version_info(); evidence.project=ProjectSettings.globalize_path("res://")
	evidence.settings=_settings()
	var packed: PackedScene=load("res://scenes/main.tscn") as PackedScene
	if not _require(packed!=null,"main_scene_load"): _finish(); return
	node_added.connect(_observe_added_node)
	game=packed.instantiate() as Node3D; root.add_child(game); current_scene=game
	for frame in 1200:
		if done: return
		if bool(game.get("preview_ready")): break
		await process_frame
	if not _require(bool(game.get("preview_ready")),"main_not_ready"): _finish(); return
	player=game.get("_player"); host=game.get("preview_palazzo")
	if not _require(is_instance_valid(player) and is_instance_valid(host) and host.get("status")=="ready","player_palazzo_not_ready"): _finish(); return
	if node_added.is_connected(_observe_added_node): node_added.disconnect(_observe_added_node)
	if not _require(authored_site_id==host.site.get_instance_id() and not authored_geometry.is_empty(),"actual_authored_site_capture_required"): _finish(); return
	evidence.initial_geometry=authored_geometry
	camera=player.get_preview_camera()
	if not _require(camera==root.get_camera_3d(),"real_player_camera_required"): _finish(); return
	evidence.revision=game.get_script().get_script_constant_map().get("PREVIEW_RUNTIME_REVISION","")
	if not _require(evidence.revision==expected_revision,"runtime_revision_mismatch"): _finish(); return
	evidence.lighting=_lighting(); evidence.startup_content=_content()
	if not _require(evidence.startup_content.ok,"startup_content_mismatch"): _finish(); return
	player_input_before=player.is_processing_unhandled_input(); game_input_before=game.is_processing_unhandled_input(); capture_before=player._free_mouse_look; input_saved=true
	player.set_process_unhandled_input(false); game.set_process_unhandled_input(false)
	player.set_mouse_captured(true)
	for action: StringName in InputMap.get_actions(): Input.action_release(action)
	# Placement is setup only; gameplay, NPCs, collision and animation keep running.
	player.global_position=host.site.to_global(Vector3(-3,.31,6.5)); player.velocity=Vector3.ZERO
	player._camera_yaw=host.site.global_rotation.y; player._camera_pitch=-.12; player._heading=player._camera_yaw
	player._visual.rotation.y=player._heading+PI-player.global_rotation.y; player._update_camera_rotation()
	phase_name="warmup"; _marker()
	for frame in WARMUP_FRAMES:
		await process_frame
		if done: return
	evidence.initial_physics=_initial_physics_state()
	evidence.camera={"transform":_transform(camera.global_transform),"fov":camera.fov,"near":camera.near,"far":camera.far,"requested_actor_local":[-3,.31,6.5],"actor_local_after_warmup":_v(host.site.to_local(player.global_position)),"yaw":player._camera_yaw,"pitch":player._camera_pitch}
	if not baseline.is_empty():
		for field: String in ["settings","lighting"]:
			_require(JSON.parse_string(JSON.stringify(evidence[field]))==baseline.get(field,{}),"baseline_"+field+"_mismatch")
		_require(_same_camera(evidence.camera,baseline.get("camera",{})),"baseline_camera_mismatch")
		_require(str(evidence.engine.get("hash",""))==str(baseline.get("engine",{}).get("hash","missing")) and str(evidence.engine.get("string",""))==str(baseline.get("engine",{}).get("string","missing")),"baseline_engine_mismatch")
		_require(evidence.initial_geometry.get("ordered_geometry_sha256","")==baseline.get("initial_geometry",{}).get("ordered_geometry_sha256","missing"),"baseline_initial_geometry_mismatch")
		var prior_physics: Dictionary=baseline.get("initial_physics",{})
		_require(JSON.stringify(evidence.initial_physics.get("released_keys",[]))==JSON.stringify(prior_physics.get("released_keys",["missing"])),"baseline_initial_release_identity_mismatch")
		for key: String in ["release_geometry_sha256","remaining_frozen_geometry_sha256","support_released_count","detached_count","unfrozen_count","frozen_owned_count"]:
			_require(evidence.initial_physics.get(key)!=null and evidence.initial_physics.get(key)==prior_physics.get(key),"baseline_initial_physics_"+key+"_mismatch")
		_require(evidence.provenance.fixture_sha256==baseline.get("provenance",{}).get("fixture_sha256",""),"baseline_fixture_sha_mismatch")
	for wall: RigidBody3D in host.site.wall_panels:
		if str(wall.name).begins_with("Facade") and wall.position.is_equal_approx(Vector3(-3,1.57,3)): panel=wall
	_require(is_instance_valid(panel) and panel.get_meta("pooled_fragments",[]).size()==20,"actual_witness_panel_required")
	if not errors.is_empty(): _finish(); return
	await _sample("idle",IDLE_FRAMES,false)
	if done: return
	if not errors.is_empty(): _finish(); return
	await _sample("damage_and_recovery",DAMAGE_FRAMES,true)
	if not done: _finish()

func _grid(body: RigidBody3D) -> Vector2i:
	var center: Vector3=body.get_meta("panel_center"); var size: Vector3=panel.get_meta("section_size")
	return Vector2i(roundi((center.y+size.y*.5)/(size.y/5.0)-.5),roundi((center.x+size.x*.5)/(size.x/4.0)-.5))

func _shot(index: int, sample_frame: int) -> bool:
	var begin:=Time.get_ticks_usec(); var shot: Dictionary=SHOTS[index]
	var target: RigidBody3D=panel if index==0 else null
	if index>0:
		for body: RigidBody3D in panel.get_meta("pooled_fragments"):
			if _grid(body)==shot.tile: target=body; break
	if not _require(is_instance_valid(target) and target.freeze and (target.collision_layer&1)!=0 and not target.get_meta("detached",false),"shot_target_not_current_"+str(index)): return false
	var at: Vector3=panel.to_global(shot.point); var normal: Vector3=panel.global_basis.z
	var ray:=PhysicsRayQueryParameters3D.create(at+normal*.025,at-normal*.025,1)
	var hit: Dictionary=host.site.get_world_3d().direct_space_state.intersect_ray(ray)
	if not _require(hit.get("collider")==target,"shot_native_surface_mismatch_"+str(index)): return false
	var before: Dictionary={}
	for body: RigidBody3D in panel.get_meta("pooled_fragments"): before[body.get_instance_id()]=bool(body.get_meta("detached",false))
	var serial: int=host.site.blast_serial
	var owner_begin:=Time.get_ticks_usec()
	host.site.explode(hit.position,.8,target,false)
	var owner_usec: int=Time.get_ticks_usec()-owner_begin
	var removed: Array[String]=[]; var planned: Array[String]=[]
	for body: RigidBody3D in panel.get_meta("pooled_fragments"):
		if body.get_meta("detached",false) and not before[body.get_instance_id()]: removed.append(str(_grid(body)))
	for grid: Vector2i in shot.removed: planned.append(str(grid))
	removed.sort(); planned.sort()
	var result: Dictionary=host.site.last_explosion.duplicate()
	_require(host.site.blast_serial==serial+1 and result.get("committed",false) and result.get("detached")==4 and removed==planned,"shot_selector_or_commit_mismatch_"+str(index))
	actions.append({"shot":index+1,"sample_frame":sample_frame,"physics_frame":Engine.get_physics_frames(),"ticks_ms":Time.get_ticks_msec(),"native_surface_point":_v(hit.position),"role":shot.role,"removed":removed,"expected":planned,"owner_explode_usec":owner_usec,"complete_workload_dispatch_usec":Time.get_ticks_usec()-begin,"result":result,"component_API":"site.explode","native_weapon_admission":false})
	return errors.is_empty()

func _sample(label: String, count: int, damage: bool) -> void:
	var samples: Dictionary={}
	for field: String in FIELDS:
		var values:=PackedFloat64Array(); values.resize(count); samples[field]=values
	var diagnostics: Array[Dictionary]=[]
	var start_player:=player.global_position; var start_camera:=camera.global_transform
	var record: Dictionary={"name":label,"requested_samples":count,"actual_samples":0,"samples":samples,"support_samples":diagnostics,"content_before":_content(),"player_start":_v(start_player),"camera_start":_transform(start_camera),"physics_frame_start":Engine.get_physics_frames(),"ticks_start_ms":Time.get_ticks_msec()}
	phases.append(record); phase_name=label; _marker()
	var last:=Time.get_ticks_usec(); var actor_drift:=0.0; var camera_drift:=0.0; var camera_rotation:=0.0
	for index in count:
		# The scheduled dispatch occurs after the preceding frame timestamp, so the
		# next wall-frame interval includes the full synchronous damage workload.
		if damage:
			for shot in SHOTS.size():
				if index==int(SHOTS[shot].frame) and not _shot(shot,index): return
		await process_frame
		if done: return
		var now:=Time.get_ticks_usec()
		samples.frame_ms[index]=float(now-last)/1000.0; last=now
		samples.process_ms[index]=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		samples.physics_ms[index]=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		samples.draw_calls[index]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		samples.render_primitives[index]=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		samples.static_bytes[index]=Performance.get_monitor(Performance.MEMORY_STATIC)
		samples.static_peak_bytes[index]=Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
		samples.video_bytes[index]=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		samples.object_count[index]=Performance.get_monitor(Performance.OBJECT_COUNT)
		samples.node_count[index]=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		samples.resource_count[index]=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		samples.orphan_node_count[index]=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		samples.physics_active_objects[index]=Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		samples.physics_collision_pairs[index]=Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
		samples.physics_islands[index]=Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)
		var support: Dictionary=host.site._structure.diagnostics()
		diagnostics.append({"frame":index,"physics_frame":Engine.get_physics_frames(),"busy":support.get("busy",true),"phase":support.get("phase",""),"ok":support.get("ok",false),"error":support.get("error",""),"pending":support.get("pending",0),"released_total":support.get("released_total",0),"graphs":support.get("graphs",0),"advance_calls":support.get("advance_calls",0),"last_advance_usec":support.get("last_advance_usec",0),"last_released":support.get("last_released",0),"shape_pair_checks":support.get("shape_pair_checks",0)})
		record.actual_samples=index+1
		actor_drift=maxf(actor_drift,player.global_position.distance_to(start_player)); camera_drift=maxf(camera_drift,camera.global_position.distance_to(start_camera.origin))
		camera_rotation=maxf(camera_rotation,camera.global_basis.get_rotation_quaternion().angle_to(start_camera.basis.get_rotation_quaternion()))
	phase_name=label+":finalizing"; _marker()
	var content: Dictionary=_content(); var final_stats: Dictionary=host.site.get_stats(); var support: Dictionary=host.site._structure.diagnostics()
	record.content_after=content; record.native_site_after=final_stats; record.support_after=support
	record.player_end=_v(player.global_position); record.camera_end=_transform(camera.global_transform)
	record.max_actor_drift_m=actor_drift; record.max_camera_drift_m=camera_drift; record.max_camera_rotation_rad=camera_rotation
	record.physics_frame_end=Engine.get_physics_frames(); record.ticks_end_ms=Time.get_ticks_msec()
	record.summary=_summary(samples,int(record.actual_samples))
	_require(record.content_before.ok and content.ok,label+":same_three_live_NPCs_and_content")
	_require(final_stats.native_body_count==initial_bodies and final_stats.native_shape_count==initial_shapes,label+":native_inventory_preserved")
	_require(support.get("ok",false) and not support.get("busy",true),label+":support_completed_within_sample_window")
	_require(camera==root.get_camera_3d() and actor_drift<.01 and camera_drift<.01 and camera_rotation<.001,label+":fixed_actor_camera")
	_require(float(record.summary.frame_ms.p50)>0 and float(record.summary.draw_calls.p50)>0,label+":nonzero_GPU_and_frame_samples")
	print("PERFORMANCE45_PHASE ",label," ",JSON.stringify(record.summary))

func _summary(samples: Dictionary, count: int) -> Dictionary:
	var result: Dictionary={}
	if count<=0: return result
	for field: String in FIELDS:
		var values: PackedFloat64Array=samples[field].slice(0,count); values.sort()
		result[field]={"p50":values[maxi(0,ceili(count*.50)-1)],"p95":values[maxi(0,ceili(count*.95)-1)],"max":values[count-1]}
	var over:=0
	for index in count:
		if float(samples.frame_ms[index])>16.667: over+=1
	result.frame_ms["over_16_667_count"]=over; result.frame_ms["over_16_667_percent"]=100.0*float(over)/float(count)
	return result

func _finish() -> void:
	if done: return
	done=true
	phase_name="finalizing"; _marker()
	if input_saved and is_instance_valid(player) and is_instance_valid(game):
		player.set_process_unhandled_input(player_input_before); game.set_process_unhandled_input(game_input_before); player.set_mouse_captured(capture_before)
	var complete: bool=phases.size()==2 and actions.size()==3
	for record: Dictionary in phases:
		var count: int=int(record.actual_samples); complete=complete and count==int(record.requested_samples)
		record.summary=_summary(record.samples,count)
		for field: String in FIELDS: record.samples[field]=record.samples[field].slice(0,count)
	if not complete: errors.append("incomplete_240_idle_600_damage_three_shots")
	evidence.status="MEASUREMENT_COMPLETE_COMPARE_REQUIRED" if errors.is_empty() else "UNVERIFIED"
	evidence.variant=variant; evidence.expected_revision=expected_revision; evidence.failures=errors
	evidence.pid=OS.get_process_id(); evidence.elapsed_ms=Time.get_ticks_msec()-started
	evidence.phases=phases; evidence.actions=actions; evidence.warmup_frames=WARMUP_FRAMES
	evidence.baseline_report=baseline_path; evidence.performance_accepted=false
	evidence.rss="EXTERNAL_SIDECAR_REQUIRED; match pid and phase markers"
	evidence.metrics={"frame_ms":"monotonic wall-clock process-frame intervals, including dispatch and ordinary scene work","render_primitives":"native renderer primitive count; triangle workload proxy, not an independent triangle-only counter","static_bytes":"engine static allocation bytes, not process RSS or malloc-call count","object_count":"native allocated-object count; not memory allocation calls","static_monitor_debug_build":OS.is_debug_build(),"support_samples":"one diagnostics read per rendered frame; repeated physics_frame IDs must not be summed as distinct support updates"}
	evidence.initial_geometry_method="Captured at actual site.ready before first support advance. After warmup compare exact release keys/names/authored+current collision geometry and all remaining frozen geometry. Dynamic transforms and sleep/awake counts are reported explicitly, not hashed as authored geometry."
	evidence.scope="Whole loaded Palazzo scene, actual player camera, original three NPCs and physics. Identical 120-frame warmup, 240 idle frames, 600 damaged frames; three source-selected natural site.explode operations at damage frames0/120/240. No direct release, collider/freeze change, NPC relocation or content removal. This is performance workload provenance, not weapon/gameplay acceptance."
	_write("performance45.json",evidence); phase_name="finished"; _marker()
	print("PERFORMANCE45_FINISHED ",evidence.status," ",ProjectSettings.globalize_path(output.path_join("performance45.json")))
	quit(0 if errors.is_empty() else 1)
