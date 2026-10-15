extends SceneTree
var _out:=""
var _revision:="s01-20261015-residents55"
var _title:="15.10 · Большой город и реакции жителей · версия55"
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
	if pop==null or not pop.get("city_ready") or pop.get("daily")==null:
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
	var ready: bool=actual==_revision and count>=200 and current==count and site_count==8 and staff_count==12 and titles.size()==18 and avoidance and threat and lifecycle
	if DisplayServer.get_name()!="headless" and not _out.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("opened.png"))
	_report({"ok":ready,"revision":_revision,"actual_revision":actual,"title":_title,"interactive":true,"resident_count":count,"current_resident_count":current,"requested_residents":287,"exact_roster_complete":count==287,"new_venues":site_count,"staff_count":staff_count,"ambient_actions":titles.size(),"avoidance":avoidance,"threat_reactions":threat,"independent_lifecycle":lifecycle,"physical_dispatch":pop.daily.physical_dispatch_state30(),"player_position":str(scene._player.global_position),"population_ready":true,"user_requested_trial_before_performance_acceptance":true,"performance_accepted":false})
