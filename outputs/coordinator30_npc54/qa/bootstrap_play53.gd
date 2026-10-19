extends SceneTree
var _out := ""
var _revision := "s01-20261015-residents53a"
var _title := "15.10 · Жители и заведения · версия53a"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt-dir="): _out=arg.trim_prefix("--receipt-dir=")
		if arg.begins_with("--qa-out="): _out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--release-revision="): _revision=arg.trim_prefix("--release-revision=")
		if arg.begins_with("--release-title="): _title=arg.trim_prefix("--release-title=")
	_start.call_deferred()
func _report(result: Dictionary) -> void:
	print("CURRENT_GAME_READY ",JSON.stringify(result))
	if not _out.is_empty():
		var file:=FileAccess.open(_out.path_join("CURRENT_READY.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t")); file.close()
	if OS.get_cmdline_user_args().has("--city-play-check=1"): quit(0 if result.get("ok",false) else 1)
func _start() -> void:
	var scene: Node3D=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene); current_scene=scene; root.title="Мафиози — "+_title
	var deadline: int=Time.get_ticks_msec()+90000
	var pop: RefCounted
	while Time.get_ticks_msec()<deadline:
		pop=scene.get("preview_population")
		if scene.get("preview_ready")==true and pop!=null and pop.get("city_ready")==true and pop.get("daily")!=null: break
		await process_frame
	if pop==null or not pop.get("city_ready") or pop.get("daily")==null:
		_report({"ok":false,"reason":"resident_not_ready","revision":_revision}); return
	var actual: String=str(scene.get_script().get_script_constant_map().get("PREVIEW_RUNTIME_REVISION",""))
	if actual!=_revision or pop.hit_owners.size()!=1:
		_report({"ok":false,"reason":"revision_or_population","actual":actual,"revision":_revision}); return
	var weapons: Node=scene.get("preview_weapons")
	weapons.equip("none"); scene._player.set_mouse_captured(true)
	for _frame in 20: await physics_frame
	var sites: Node=scene.get("preview_service_sites29")
	var site_count: int=sites.current_sites().size() if is_instance_valid(sites) else 0
	if DisplayServer.get_name()!="headless" and not _out.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("opened.png"))
	_report({"ok":site_count==8,"revision":_revision,"title":_title,"interactive":true,"resident_count":pop.hit_owners.size(),"new_venues":site_count,"player_position":str(scene._player.global_position),"population_ready":true})
