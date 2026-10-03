extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("SCHEDULER_NATIVE_READY")
	await create_timer(20.0).timeout
	print("SCHEDULER_NATIVE_DONE")
	quit(0)
