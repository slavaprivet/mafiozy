extends SceneTree
func _initialize()->void:
	var before:int=Input.mouse_mode
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var after:int=Input.mouse_mode
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("DIRECT_HEADLESS_CAPTURE_PROBE ",JSON.stringify({"display":DisplayServer.get_name(),"before":before,"requested":Input.MOUSE_MODE_CAPTURED,"after_set":after,"after_release":Input.mouse_mode}))
	quit()
