extends SceneTree
## PREPARED ONLY. Root-controlled rendered window; never forces OS focus.
## This tests the actual player setter/backend, NOT cargo's focused return branch.
var scene:Node3D
var out:=""
var started:=0
var done:=false
func _initialize()->void:
	started=Time.get_ticks_msec();root.unfocusable=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	if out.is_empty() or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);run.call_deferred()
func _process(_dt:float)->bool:
	if not done and Time.get_ticks_msec()-started>15000:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;done=true;quit(3)
	return false
func run()->void:
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 180:
		await physics_frame;await process_frame
		if scene.preview_ready:break
	if not scene.preview_ready:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;done=true;quit(4);return
	var player:CharacterBody3D=scene._player
	player.set_mouse_captured(false)
	var record:Dictionary={"display":DisplayServer.get_name(),"actual_main":true,"window_has_focus":root.has_focus(),"no_focus_flag":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"scope":"Backend/player setter only. Does not prove cargo focused Take path; no forced focus or logical-state override."}
	record.pointer_before=DisplayServer.mouse_get_position()
	# Deliberately synchronous: there is NO await, callback or physics frame
	# while captured. Always release before evaluating assertions/serializing.
	player.set_mouse_captured(true)
	record.mode_captured=Input.mouse_mode;record.logical_captured=player._free_mouse_look
	player.set_mouse_captured(false)
	record.mode_released=Input.mouse_mode;record.logical_released=player._free_mouse_look
	record.pointer_after=DisplayServer.mouse_get_position()
	record.ok=record.mode_captured==Input.MOUSE_MODE_CAPTURED and record.logical_captured and record.mode_released==Input.MOUSE_MODE_VISIBLE and not record.logical_released and not record.window_has_focus
	record.elapsed_ms=Time.get_ticks_msec()-started
	var file:=FileAccess.open(out.path_join("BACKEND_CAPTURE_RESULT.json"),FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(record,"\t"));file.close()
	print("BACKEND_CAPTURE_RESULT ",JSON.stringify(record))
	done=true;quit(0 if record.ok else 1)
