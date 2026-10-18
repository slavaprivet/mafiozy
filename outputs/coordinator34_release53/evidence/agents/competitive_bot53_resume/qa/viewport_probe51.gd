extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 print("VP0 ",root.size," scale ",root.content_scale_size)
 root.size=Vector2i(1280,720)
 await process_frame
 print("VP1 ",root.size," scale ",root.content_scale_size)
 await process_frame
 print("VP2 ",root.size," scale ",root.content_scale_size)
 quit()
