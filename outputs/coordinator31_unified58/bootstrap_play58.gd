extends SceneTree
## Unified play bootstrap for the single common scene (revision residents58).
## It loads the one city scene, waits for the real population, proves the cohort
## and reports CURRENT_GAME_READY for the user launcher. No gameplay is altered.
var _out:=""
var _expected:=10
var _revision:="s01-20261015-residents58"
var _title:="15.10 · Свободный проход жителей · версия58"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt-dir="):_out=arg.trim_prefix("--receipt-dir=")
		if arg.begins_with("--qa-out="):_out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--release-revision="):_revision=arg.trim_prefix("--release-revision=")
		if arg.begins_with("--release-title="):_title=arg.trim_prefix("--release-title=")
	_start.call_deferred()
func _report(value: Dictionary) -> void:
	print("CURRENT_GAME_READY ",JSON.stringify(value))
	if not _out.is_empty():
		var f:=FileAccess.open(_out.path_join("CURRENT_READY.json"),FileAccess.WRITE)
		f.store_string(JSON.stringify(value,"\t"));f.close()
	if OS.get_cmdline_user_args().has("--city-play-check=1"):quit(0 if value.get("ok",false) else 1)
func _start() -> void:
	var scene: Node3D=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene;root.title="Мафиози — "+_title
	var deadline: int=Time.get_ticks_msec()+115000
	var pop: RefCounted
	while Time.get_ticks_msec()<deadline:
		pop=scene.get("preview_population")
		if scene.get("preview_ready")==true and pop!=null and pop.get("city_ready")==true and pop.get("daily")!=null and pop.city_stream_complete():break
		await process_frame
	if pop==null or scene.get("preview_ready")!=true or not pop.get("city_ready") or pop.get("daily")==null or not pop.city_stream_complete():
		_report({"ok":false,"reason":"population_not_ready","revision":_revision});return
	var actual: String=str(scene.get_script().get_script_constant_map().get("PREVIEW_RUNTIME_REVISION",""))
	var staff: Node=scene.get("preview_venue_staff29")
	var sites: Node=scene.get("preview_service_sites29")
	var staff_count: int=staff._rows.size() if is_instance_valid(staff) else 0
	var site_count: int=sites.current_sites().size() if is_instance_valid(sites) else 0
	var titles: Array=load("res://scripts/npc_ambient/ambient_controller28.gd").get_script_constant_map().get("TITLES",[])
	var weapons: Node=scene.get("preview_weapons")
	weapons.equip("none");scene._player.set_mouse_captured(true)
	for tick in 20:await physics_frame
	var count: int=pop.hit_owners.size()
	var current:=0
	for life: RefCounted in pop.daily._lives.values():
		if pop.residents.target_current(life._token):current+=1
	var avoidance: bool=scene.has_meta("npc_local_avoidance29")
	var threat: bool=scene.has_meta("npc_threat_world30")
	var lifecycle: bool=is_instance_valid(pop.get("_multi_lifecycle30"))
	var homes_ok: bool=is_instance_valid(scene.get("preview_homes58"))
	var shop_ok: bool=is_instance_valid(scene.get("player_shop"))
	var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_city/session_packet.json"))
	var expected_ids: Array=[]
	for row: Dictionary in packet.rows:
		if expected_ids.size()>=_expected:break
		expected_ids.append(str(row.source_id))
	expected_ids.sort()
	var actual_ids: Array=pop.daily._lives.keys();actual_ids.sort()
	var exact_ids: bool=actual_ids==expected_ids and packet.rows.size()==287
	# The unified scene is ready when the exact cohort is alive and the new owners
	# (threat perception, independent lifecycle, avoidance) are installed. Site and
	# ambient-catalogue counts are recorded, not gates: the unified build adds the
	# homes and the player shop alongside the eight ordinary service sites.
	var ready: bool=actual==_revision and count==_expected and exact_ids and current==count and staff_count==12 and avoidance and threat and lifecycle
	if DisplayServer.get_name()!="headless" and not _out.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("opened.png"))
	_report({"ok":ready,"revision":_revision,"actual_revision":actual,"title":_title,"interactive":true,"unified_scene":true,"resident_count":count,"current_resident_count":current,"requested_residents":_expected,"actual_ids":actual_ids,"original_catalogue_count":packet.rows.size(),"exact_roster_complete":count==_expected and exact_ids,"new_venues":site_count,"staff_count":staff_count,"ambient_actions":titles.size(),"avoidance":avoidance,"threat_reactions":threat,"independent_lifecycle":lifecycle,"destructible_homes":homes_ok,"player_shop":shop_ok,"physical_dispatch":pop.daily.physical_dispatch_state30(),"player_position":str(scene._player.global_position),"population_ready":true,"batch_size":10,"performance_accepted_for_requested_batch":false,"full_city_performance_accepted":false})
