extends "observer_soak31_v3.gd"
## QA presentation only: make the actual3D target resolution explicit before
## city-ready/warmup/camera capture. NPCs, physics and project sources unchanged.
var _render_size31 := Vector2i.ZERO
var _size_started31 := 0
var _size_stable31 := 0
var _size_ready31 := false
var _size_before31: Dictionary = {}
var _size_after31: Dictionary = {}

func _ready() -> void:
	super._ready()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-render-resolution="):
			var parts: PackedStringArray = arg.trim_prefix("--qa-render-resolution=").split("x")
			if parts.size()==2:_render_size31=Vector2i(int(parts[0]),int(parts[1]))
	_size_ready31 = DisplayServer.get_name()=="headless" or _render_size31==Vector2i.ZERO

func _size_state31() -> Dictionary:
	var window: Window = get_window()
	var texture: ViewportTexture = get_viewport().get_texture()
	var native: Vector2i = DisplayServer.window_get_size()
	var visible: Vector2 = get_viewport().get_visible_rect().size
	return {"window_size":[window.size.x,window.size.y],"display_window_size":[native.x,native.y],
		"root_texture":[texture.get_width(),texture.get_height()],"viewport_visible":[visible.x,visible.y],
		"content_scale_size":[window.content_scale_size.x,window.content_scale_size.y],
		"content_scale_factor":window.content_scale_factor,"content_scale_mode":window.content_scale_mode,
		"window_mode":window.mode,"screen_scale":DisplayServer.screen_get_scale()}

func _process(delta: float) -> void:
	if not _size_ready31:
		if _size_started31==0:
			_size_before31=_size_state31()
			var window: Window=get_window()
			window.mode=Window.MODE_WINDOWED
			window.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
			window.content_scale_size=_render_size31
			window.content_scale_factor=1.0
			window.size=_render_size31
			_size_started31=Time.get_ticks_msec();return
		var current: Dictionary=_size_state31()
		var actual_texture: Vector2i=Vector2i(int(current.root_texture[0]),int(current.root_texture[1]))
		var actual_visible: Vector2i=Vector2i(int(current.viewport_visible[0]),int(current.viewport_visible[1]))
		if actual_texture==_render_size31 and actual_visible==_render_size31:_size_stable31+=1
		else:_size_stable31=0
		if _size_stable31>=3:
			_size_after31=current;_size_ready31=true
			print("QA31_WINDOW ",JSON.stringify({"before":_size_before31,"after":_size_after31}))
		elif Time.get_ticks_msec()-_size_started31>10000:_finish("qa_render_size_unavailable");return
		else:return
	super._process(delta)

func _camera_values(camera: Camera3D) -> Dictionary:
	var record: Dictionary=super._camera_values(camera)
	record.window_protocol=_size_state31()
	return record

func _finish(reason: String) -> void:
	if _finished:return
	if not _out.is_empty():
		var file: FileAccess=FileAccess.open(_out.path_join("WINDOW31.json"),FileAccess.WRITE)
		if file!=null:
			file.store_string(JSON.stringify({"schema":"mafiozi.qa31.window/v1","qa_only":true,
				"requested":[_render_size31.x,_render_size31.y],"ready":_size_ready31,
				"before":_size_before31,"after":_size_after31,"final":_size_state31(),
				"npc_or_source_mutations":false,"protocol":"Fixed native root viewport, stable3 frames before warmup and camera capture; paired runs must match full camera/window metadata."}));file.close()
	super._finish(reason)
