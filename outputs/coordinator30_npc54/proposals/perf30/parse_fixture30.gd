extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var script: Script=load(get_script().resource_path.get_base_dir().path_join("observer_perf30.gd"))
	var valid: bool=script!=null and script.can_instantiate()
	# The bounded lifetime lets the shared scheduler register the direct child.
	await create_timer(4.0).timeout
	print("PERF30_PARSE ",valid)
	quit(0 if valid else 1)
