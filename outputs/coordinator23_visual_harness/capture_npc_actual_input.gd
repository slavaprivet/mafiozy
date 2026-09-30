extends "../artist23_combat_next/test_combined_eyes_input.gd"
## Root GPU window only. Inherits ALL original native shot, ammo, HP, blood,
## medical-survival, physical-fall and final-eye checks without replacing them.
## Appearance observer + detached aim camera are explicit QA fixtures, not player
## camera parity, locomotion/performance or a demonstration of normal targeting.
var wall_started:=0
var host_hashes:Dictionary={}
func _initialize()->void:
	wall_started=Time.get_ticks_msec()
	root.unfocusable=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	if not out.is_absolute_path():push_error("Absolute --qa-out required");quit(2);return
	if DisplayServer.get_name()=="headless":push_error("Root-controlled real GPU required");quit(2);return
	for path:String in ["res://data/preview_updates.json","res://scenes/main.tscn","res://scripts/npc/resident_hit_owner.gd"]:
		host_hashes[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "compiled_or_missing"
	super._initialize()
func _process(delta:float)->bool:
	if not done and Time.get_ticks_msec()-wall_started>45000:
		check(false,"45_second_wall_clock_timeout");finish();return false
	return super._process(delta)
func capture(label:String)->void:
	if done:return
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	observer.global_position=target_point()+Vector3(4.2,2.0,4.2)
	observer.look_at(target_point(),Vector3.UP);observer.make_current()
	var before:=draws
	# Actual GPU output after completed draws. No synchronous physics-body freeze.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	check(draws>=before+2,"rendered:"+label)
	if done:return
	var png:=root.get_texture().get_image()
	var result:int=png.save_png(out.path_join(label+".png"))
	check(result==OK,"capture:"+label)
	if result==OK:images.append(label+".png")
	var evidence:Dictionary={"label":label,"size":str(png.get_size()),"source":"actual root GPU viewport after two frame_post_draw events","observer_only":true,"native_camera_parity":false,"observer_position":str(observer.global_position),"actor":str(owner._token.source_id),"hp":owner.snapshot().row.hp,"blood_revision":owner.blood._last_revision if owner.blood!=null else -1,"accepted_damage_revision":owner.last_result.get("revision",-1),"window_position":str(DisplayServer.window_get_position())}
	FileAccess.open(out.path_join(label+".json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
func finish()->void:
	if done:return
	super.finish()
	if out.is_empty() or not FileAccess.file_exists(out.path_join("RESULT.json")):return
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("RESULT.json")))
	report.root_capture={"NO_FOCUS":true,"offscreen":true,"performance_valid":false,"native_camera_parity":false,"appearance_observer_only":true,"stationary_NPC_fixture":true,"deterministic_source_survival_choice":true,"original_checks_preserved":true,"base_harness_sha256":FileAccess.get_sha256(get_script().resource_path.get_base_dir()+"/../artist23_combat_next/test_combined_eyes_input.gd"),"frozen_pack_resources":host_hashes,"wall_elapsed_ms":Time.get_ticks_msec()-wall_started}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
